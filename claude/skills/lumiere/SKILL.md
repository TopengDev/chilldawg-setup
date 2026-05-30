---
name: lumiere
description: Perceive and analyze the contents of a VIDEO file — produces a timeline summary, key moments, and on-screen text by sampling frames and reading them with Claude vision. Use when the user gives a video (clip, screen recording, .mp4/.mov/.webm/.gif) and asks what's in it, what happens, to summarize/describe/transcribe-visually, or to find a moment. Cost-budgeted: quick/standard/deep tiers cap how many frames are read.
argument-hint: <video-path> [quick|standard|deep] [--focus "..."]
allowed-tools: Bash, Read
---

# lumiere — cost-budgeted video perception

> Adapted from **elpabl0** (lumiere.attn / github.com/alkautsarf), with permission, 2026-05-30.
> Provenance note: elpabl0's published `sebat-duls` repo contained **no committed video skill** —
> "lumiere" is his *agent name*. This is an **original implementation** of the video-perception
> concept (frame extraction + cost-budgeted vision tiers) built for our stack. Credit to elpabl0
> for the concept; the code here is ours.

## What this is

We have image *generation* (`/creative`, nanobanana) but had **zero video understanding**.
lumiere closes that gap. There is **no dedicated video model** on this machine — instead lumiere
**samples frames with ffmpeg and reads them with Claude vision** (Anthropic Messages API). Claude
vision over evenly-spaced frames *is* the perception layer.

Pipeline: `ffprobe` (probe duration/fps/res) → `ffmpeg` (extract N evenly-spaced frames, N capped
by tier) → Claude vision (batched, base64) → structured **timeline summary**.

The whole thing lives in one helper: **`~/.claude/scripts/lumiere.py`** (stdlib-only, no pip deps).

## HARD RULES (non-negotiable)

1. **This is VISUAL perception only.** No audio. Never claim to have heard speech, music, or
   sound. If the user needs dialogue/audio, say so — that is out of scope.
2. **The frame cap IS the budget.** Never bypass it to "be thorough" on a long video. If the user
   wants more detail, step up the tier or raise `--max-frames` *explicitly* — never silently.
3. **Never print the API key.** It is read from `$ANTHROPIC_API_KEY` inside the script. Do not
   echo it, log it, or pass it on the command line.
4. **Report what was actually sampled.** Always state the tier, frame count, and that the analysis
   is based on *sampled* frames — not every frame. A 2-hour video read at 40 frames is a sparse
   sample; say so. Do not imply full coverage.
5. **Frames are temp.** The script writes frames to a temp dir and cleans up afterward unless
   `--out`/`--keep-frames` is given. Don't litter the repo or cwd with frame dumps.
6. **Don't fabricate.** If a frame is ambiguous or text is unreadable, the model is instructed to
   say so in `notes`. Surface that uncertainty to the user; do not smooth it over.

## Cost-budgeted watch tiers

The tier picks the sampling rate, the **hard frame cap** (the budget), and the model. Effective
frames = `min(cap, round(duration × rate))`, always ≥ 1. The cap is what stops a long video from
blowing cost — a 1-hour video at `deep` still reads only 40 frames.

| Tier | rate | **cap** | model | use for |
|------|------|--------|-------|---------|
| `quick` | 0.20/s | **6** | sonnet-4-6 | triage / gist — "what is this clip?" |
| `standard` *(default)* | 0.50/s | **16** | sonnet-4-6 | normal summary + timeline |
| `deep` | 1.00/s | **40** | opus-4-8 | dense analysis + per-frame notes |

- Cost driver = **frame count** (each ~768px frame ≈ a few hundred image tokens). The cap bounds it.
- Frames are batched **16 per vision call**; above 16 frames the script chunks calls + adds one
  synthesis call (so `deep`/40 frames ≈ 3 calls; `quick`/`standard` = 1 call).
- **Always offer `--dry-run` first for an unfamiliar/long video** — it prints the plan (frame
  count, call count, est. tokens, timestamps) with **no ffmpeg and no API call**, so you and the
  user can sanity-check cost before spending.

## Usage

```bash
# 1) ALWAYS sanity-check the plan on anything long/unknown (free — no API call):
python3 ~/.claude/scripts/lumiere.py /path/to/video.mp4 --tier standard --dry-run

# 2) Run perception:
python3 ~/.claude/scripts/lumiere.py /path/to/video.mp4                 # standard (default)
python3 ~/.claude/scripts/lumiere.py /path/to/clip.mov --tier quick     # cheap triage
python3 ~/.claude/scripts/lumiere.py /path/to/demo.webm --tier deep     # dense + per-frame

# Focus the analysis:
python3 ~/.claude/scripts/lumiere.py rec.mp4 --focus "read every line of UI text on screen"

# Verify sampling logic with ZERO vision cost (extracts + keeps frames only):
python3 ~/.claude/scripts/lumiere.py video.mp4 --tier deep --frames-only --out /tmp/frames

# Machine-readable output too:
python3 ~/.claude/scripts/lumiere.py video.mp4 --json
```

### Flags

| Flag | Effect |
|------|--------|
| `--tier quick\|standard\|deep` | watch tier (default `standard`) |
| `--max-frames N` | override the tier's cap — **state this explicitly to the user** |
| `--model <id>` | override vision model |
| `--focus "..."` | extra instruction (e.g. "track the cursor", "read all text") |
| `--dry-run` | print plan only — no ffmpeg, no API call |
| `--frames-only` | extract + keep frames, no vision call (free; tests sampling) |
| `--keep-frames` / `--out DIR` | persist frames + write `lumiere-report.md` |
| `--json` | also emit machine-readable JSON block |

## How to drive it (skill workflow)

1. **Resolve the video path.** If the user dropped a file, confirm the path exists.
2. **Pick a tier by intent** — gist → `quick`; normal "what happens / summarize" → `standard`;
   "analyze in detail / catch everything / per-frame" → `deep`. When unsure, default `standard`.
3. **If the video is long or its length is unknown, run `--dry-run` first**, show the plan
   (frames + est. calls), and proceed once it's clearly within reason.
4. **Run the real pass.** Relay the rendered markdown (summary / timeline / key moments /
   on-screen text / caveats) back to the user.
5. **Be honest about coverage and audio** (see HARD RULES 1 & 4). Recommend a higher tier if the
   sample looks too sparse for what they asked.

## Output shape

The script renders markdown and (with `--json`) a JSON object:
`summary` · `timeline` [{time,event}] · `key_moments` · `on_screen_text` · `notes`
(+ `frame_notes` on `deep`). On a non-JSON model reply it falls back to the raw text under
"Analysis (unstructured)" — still usable, just unstructured.

## Failure modes & guardrails

- **Not a video / corrupt** → ffprobe finds no video stream or zero duration → script dies with a
  clear message. Don't retry blindly; check the file.
- **`ANTHROPIC_API_KEY` unset** → script dies before any spend. (It's sourced from secrets.env in
  normal shells.)
- **API HTTP error** (e.g. 429/529 overload, 400 bad request) → surfaced verbatim (truncated); back
  off and retry on overload, fix the request on 400.
- **Animated GIF / very short clip** → fine; frame count just floors at the available range.
- **Huge / 4K frames** → auto-downscaled to 768px long edge before upload to bound token cost.

## Cost caveats & tuning

- Cost ≈ **frames × per-image-tokens + output**. `deep` (40 frames, opus) is the expensive path —
  reserve it for when the gist isn't enough.
- For long videos, prefer `standard` (or `quick` for triage) and only escalate the section that
  matters, e.g. clip the video with `ffmpeg -ss/-t` first, then `deep` the clip.
- Tune `rate`/`cap`/`model` per tier in the `TIERS` table at the top of `lumiere.py`.
- This is **frame sampling**, not continuous understanding — fast motion *between* sampled frames
  is invisible. Raise the tier (denser sampling) when motion matters.
