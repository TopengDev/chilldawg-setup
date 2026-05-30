#!/usr/bin/env python3
"""
lumiere.py — cost-budgeted video perception via frame sampling + Claude vision.

Adapted from elpabl0 (lumiere.attn / github.com/alkautsarf), with permission, 2026-05-30.
NOTE: elpabl0's published sebat-duls repo contained no committed video skill — "lumiere" is
his agent name. This is an original implementation of the video-perception concept (frame
extraction + cost-budgeted vision tiers) for our stack. Credit to elpabl0 for the concept.

Pipeline:  ffprobe (probe) -> ffmpeg (sample frames, capped by tier) -> Claude vision
           (Anthropic Messages API, batched, base64) -> structured timeline summary.

We have no dedicated video model. Claude vision over evenly-sampled frames IS the perception
layer. This is VISUAL only — no audio transcription.

Stdlib only (subprocess, urllib, base64, json, argparse). No pip deps.
"""

import argparse
import base64
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import urllib.error

API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"

# --- Cost-budgeted watch tiers ----------------------------------------------
# rate = target frames/sec of sampling; cap = HARD ceiling on frames (the budget).
# Effective frames = min(cap, round(duration * rate)), >= 1.  Cap bounds cost on long videos.
# model: eval-tier sonnet for quick/standard, opus for deep synthesis.
TIERS = {
    "quick":    {"rate": 0.20, "cap": 6,  "model": "claude-sonnet-4-6", "per_frame_notes": False},
    "standard": {"rate": 0.50, "cap": 16, "model": "claude-sonnet-4-6", "per_frame_notes": False},
    "deep":     {"rate": 1.00, "cap": 40, "model": "claude-opus-4-8",   "per_frame_notes": True},
}

# Max frames per vision call. Above this, frames are chunked across multiple calls + a synthesis
# call. Bounds per-call image-token load (Anthropic caps ~100 images/request; we stay well under).
FRAMES_PER_CALL = 16
# Long edge to downscale frames to. Anthropic bills images by area (~tokens = w*h/750).
# 768px keeps each frame ~= a few hundred tokens — cheap, still legible for scene/text reading.
FRAME_LONG_EDGE = 768
NETWORK_TIMEOUT = 180


def die(msg, code=1):
    print(f"lumiere: error: {msg}", file=sys.stderr)
    sys.exit(code)


def fmt_ts(seconds):
    s = int(seconds)
    return f"{s // 60:02d}:{s % 60:02d}.{int((seconds - s) * 10)}"


def probe(video):
    """Return dict with duration (s), width, height, fps, codec via ffprobe."""
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-print_format", "json",
             "-show_format", "-show_streams", video],
            capture_output=True, text=True, check=True,
        ).stdout
    except FileNotFoundError:
        die("ffprobe not found on PATH")
    except subprocess.CalledProcessError as e:
        die(f"ffprobe failed: {e.stderr.strip()}")
    data = json.loads(out)
    vstreams = [s for s in data.get("streams", []) if s.get("codec_type") == "video"]
    if not vstreams:
        die("no video stream found in input")
    v = vstreams[0]
    duration = float(data.get("format", {}).get("duration")
                     or v.get("duration") or 0.0)
    if duration <= 0:
        die("could not determine video duration (corrupt or non-video file?)")
    # fps from avg_frame_rate "num/den"
    fps = 0.0
    afr = v.get("avg_frame_rate", "0/0")
    try:
        num, den = afr.split("/")
        fps = float(num) / float(den) if float(den) else 0.0
    except (ValueError, ZeroDivisionError):
        pass
    return {
        "duration": duration,
        "width": int(v.get("width", 0)),
        "height": int(v.get("height", 0)),
        "fps": round(fps, 2),
        "codec": v.get("codec_name", "?"),
    }


def plan_frames(duration, tier):
    cfg = TIERS[tier]
    n = max(1, min(cfg["cap"], round(duration * cfg["rate"])))
    # evenly spaced midpoints — avoids black lead-in / trailing frames
    timestamps = [duration * (i + 0.5) / n for i in range(n)]
    return n, timestamps


def extract_frames(video, timestamps, width, height, outdir):
    """Extract one downscaled JPEG per timestamp. Returns list of (ts, path)."""
    long_edge = max(width, height) or FRAME_LONG_EDGE
    if long_edge > FRAME_LONG_EDGE and width and height:
        if width >= height:
            tw = FRAME_LONG_EDGE
        else:
            tw = max(2, int(width * FRAME_LONG_EDGE / height))
    else:
        tw = width or FRAME_LONG_EDGE
    if tw % 2:
        tw -= 1
    frames = []
    for i, ts in enumerate(timestamps):
        path = os.path.join(outdir, f"frame_{i:03d}.jpg")
        cmd = ["ffmpeg", "-v", "error", "-ss", f"{ts:.3f}", "-i", video,
               "-frames:v", "1", "-vf", f"scale={tw}:-2", "-q:v", "3", "-y", path]
        try:
            subprocess.run(cmd, capture_output=True, text=True, check=True)
        except subprocess.CalledProcessError as e:
            die(f"ffmpeg frame extract failed at {ts:.1f}s: {e.stderr.strip()}")
        if os.path.exists(path) and os.path.getsize(path) > 0:
            frames.append((ts, path))
    if not frames:
        die("no frames could be extracted")
    return frames


def b64(path):
    with open(path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("ascii")


def vision_call(api_key, model, frames, duration, focus, want_per_frame):
    """One Messages API call over a batch of (ts, path) frames. Returns parsed JSON dict
    (or {'raw': text} if the model didn't emit clean JSON)."""
    content = []
    instruction = (
        f"You are a video-perception analyst. Below are {len(frames)} still frames sampled "
        f"evenly from a video {duration:.1f}s long. Each frame is labeled with its timestamp. "
        "Reason about what happens ACROSS time, not just each frame in isolation.\n\n"
        "Return ONLY a valid JSON object (no markdown fence) with keys:\n"
        '  "summary": string (2-3 sentences, what the video is/shows overall),\n'
        '  "timeline": array of {"time": "MM:SS.s", "event": string} in order,\n'
        '  "key_moments": array of strings (notable beats/transitions),\n'
        '  "on_screen_text": array of strings (any legible text/UI/captions, "" if none),\n'
    )
    if want_per_frame:
        instruction += '  "frame_notes": array of {"time": "MM:SS.s", "note": string},\n'
    instruction += '  "notes": string (caveats, ambiguity, low-confidence reads).\n'
    if focus:
        instruction += f"\nFOCUS: pay special attention to: {focus}\n"
    content.append({"type": "text", "text": instruction})
    for ts, path in frames:
        content.append({"type": "text", "text": f"--- frame at {fmt_ts(ts)} ---"})
        content.append({"type": "image", "source": {
            "type": "base64", "media_type": "image/jpeg", "data": b64(path)}})

    body = json.dumps({
        "model": model,
        "max_tokens": 4096,
        "messages": [{"role": "user", "content": content}],
    }).encode("utf-8")

    req = urllib.request.Request(API_URL, data=body, method="POST", headers={
        "x-api-key": api_key,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=NETWORK_TIMEOUT) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:500]
        die(f"Anthropic API HTTP {e.code}: {detail}")
    except urllib.error.URLError as e:
        die(f"Anthropic API network error: {e.reason}")

    usage = payload.get("usage", {})
    text = "".join(b.get("text", "") for b in payload.get("content", [])
                   if b.get("type") == "text").strip()
    # strip accidental ```json fences
    if text.startswith("```"):
        text = text.split("```", 2)[1].lstrip("json").strip("`\n ")
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = {"raw": text}
    parsed["_usage"] = usage
    return parsed


def synthesize(api_key, model, partials, duration):
    """Merge multiple chunk-level JSON analyses into one final summary (text-only call)."""
    joined = json.dumps([{k: v for k, v in p.items() if k != "_usage"} for p in partials])
    prompt = (
        f"These are partial JSON analyses of consecutive frame-batches from one {duration:.1f}s "
        f"video, in chronological order:\n{joined}\n\n"
        "Merge them into ONE coherent JSON object with the SAME keys "
        '("summary","timeline","key_moments","on_screen_text","notes"). Deduplicate, keep '
        "timeline in chronological order. Return ONLY the JSON object."
    )
    body = json.dumps({
        "model": model, "max_tokens": 4096,
        "messages": [{"role": "user", "content": prompt}],
    }).encode("utf-8")
    req = urllib.request.Request(API_URL, data=body, method="POST", headers={
        "x-api-key": api_key, "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=NETWORK_TIMEOUT) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        die(f"synthesis call failed: {e}")
    text = "".join(b.get("text", "") for b in payload.get("content", [])
                   if b.get("type") == "text").strip()
    if text.startswith("```"):
        text = text.split("```", 2)[1].lstrip("json").strip("`\n ")
    try:
        merged = json.loads(text)
    except json.JSONDecodeError:
        merged = {"raw": text}
    merged["_usage"] = payload.get("usage", {})
    return merged


def render_md(result, meta, tier, model, n_frames, calls):
    L = []
    L.append(f"# 🎬 lumiere — video perception ({tier})\n")
    L.append(f"**Source:** `{meta['path']}`  ")
    L.append(f"**Duration:** {meta['duration']:.1f}s · {meta['width']}x{meta['height']} · "
             f"{meta['fps']}fps · {meta['codec']}  ")
    L.append(f"**Sampled:** {n_frames} frames · **model:** {model} · **vision calls:** {calls}\n")
    if "raw" in result:
        L.append("## Analysis (unstructured)\n")
        L.append(result["raw"])
        return "\n".join(L)
    if result.get("summary"):
        L.append("## Summary\n")
        L.append(result["summary"] + "\n")
    if result.get("timeline"):
        L.append("## Timeline\n")
        for t in result["timeline"]:
            L.append(f"- **{t.get('time','?')}** — {t.get('event','')}")
        L.append("")
    if result.get("key_moments"):
        L.append("## Key moments\n")
        for k in result["key_moments"]:
            L.append(f"- {k}")
        L.append("")
    ost = [t for t in result.get("on_screen_text", []) if t]
    if ost:
        L.append("## On-screen text\n")
        for t in ost:
            L.append(f"- `{t}`")
        L.append("")
    if result.get("frame_notes"):
        L.append("## Per-frame notes\n")
        for fn in result["frame_notes"]:
            L.append(f"- **{fn.get('time','?')}** — {fn.get('note','')}")
        L.append("")
    if result.get("notes"):
        L.append("## Caveats\n")
        L.append(result["notes"])
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser(description="Cost-budgeted video perception via Claude vision.")
    ap.add_argument("video", help="path to video file")
    ap.add_argument("--tier", choices=list(TIERS), default="standard",
                    help="watch tier: quick (sparse/cheap) | standard | deep (dense/opus)")
    ap.add_argument("--model", help="override vision model id")
    ap.add_argument("--max-frames", type=int, help="override the tier's frame cap (budget)")
    ap.add_argument("--focus", help="extra focus instruction (e.g. 'read all UI text')")
    ap.add_argument("--frames-only", action="store_true",
                    help="extract + keep frames, NO vision call (free; tests sampling logic)")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the sampling/cost plan only — no ffmpeg, no API call")
    ap.add_argument("--keep-frames", action="store_true", help="don't delete extracted frames")
    ap.add_argument("--out", help="output dir for frames + report (default: temp dir)")
    ap.add_argument("--json", action="store_true", help="also print machine-readable JSON")
    args = ap.parse_args()

    if not os.path.isfile(args.video):
        die(f"video not found: {args.video}")

    meta = probe(args.video)
    meta["path"] = os.path.abspath(args.video)
    tier_cfg = dict(TIERS[args.tier])
    if args.max_frames:
        tier_cfg["cap"] = args.max_frames
    model = args.model or tier_cfg["model"]

    n, timestamps = plan_frames(meta["duration"], args.tier)
    if args.max_frames:
        n = max(1, min(args.max_frames, round(meta["duration"] * tier_cfg["rate"])))
        n = max(1, min(n, args.max_frames))
        timestamps = [meta["duration"] * (i + 0.5) / n for i in range(n)]
    n_chunks = (n + FRAMES_PER_CALL - 1) // FRAMES_PER_CALL
    est_calls = n_chunks + (1 if n_chunks > 1 else 0)
    # rough image-token estimate: ~ (tw*th)/750 per frame; assume <=768 long edge
    est_img_tokens = n * int((FRAME_LONG_EDGE * FRAME_LONG_EDGE) / 750 / 2)

    if args.dry_run:
        print(f"lumiere plan — tier={args.tier} model={model}")
        print(f"  video: {meta['duration']:.1f}s {meta['width']}x{meta['height']} "
              f"{meta['fps']}fps {meta['codec']}")
        print(f"  frames: {n} (cap {tier_cfg['cap']}, rate {tier_cfg['rate']}/s)")
        print(f"  vision calls: {est_calls} ({n_chunks} analysis"
              + (" + 1 synthesis" if n_chunks > 1 else "") + ")")
        print(f"  est. image tokens: ~{est_img_tokens} (+ prompt + output)")
        print(f"  timestamps: " + ", ".join(fmt_ts(t) for t in timestamps))
        return

    outdir = args.out or tempfile.mkdtemp(prefix="lumiere-")
    os.makedirs(outdir, exist_ok=True)
    frames = extract_frames(args.video, timestamps, meta["width"], meta["height"], outdir)

    if args.frames_only:
        print(f"Extracted {len(frames)} frames to {outdir} (no vision call):")
        for ts, p in frames:
            print(f"  {fmt_ts(ts)}  {p}")
        return

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        die("ANTHROPIC_API_KEY not set in environment")

    # chunked vision: bound per-call image load, synthesize if >1 chunk
    chunks = [frames[i:i + FRAMES_PER_CALL] for i in range(0, len(frames), FRAMES_PER_CALL)]
    partials = []
    for ci, chunk in enumerate(chunks):
        print(f"lumiere: vision call {ci+1}/{len(chunks)} ({len(chunk)} frames, {model})...",
              file=sys.stderr)
        partials.append(vision_call(api_key, model, chunk, meta["duration"],
                                    args.focus, tier_cfg["per_frame_notes"]))
    calls = len(chunks)
    if len(partials) == 1:
        result = partials[0]
    else:
        print("lumiere: synthesis call...", file=sys.stderr)
        result = synthesize(api_key, model, partials, meta["duration"])
        calls += 1

    md = render_md(result, meta, args.tier, model, len(frames), calls)
    report_path = os.path.join(outdir, "lumiere-report.md")
    with open(report_path, "w") as f:
        f.write(md)
    print(md)
    print(f"\n---\n[report: {report_path}]", file=sys.stderr)
    if args.json:
        clean = {k: v for k, v in result.items() if k != "_usage"}
        print("\n```json\n" + json.dumps(clean, indent=2) + "\n```")

    if not args.keep_frames and not args.out:
        shutil.rmtree(outdir, ignore_errors=True)


if __name__ == "__main__":
    main()
