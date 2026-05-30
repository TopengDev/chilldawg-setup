#!/usr/bin/env python3
"""
journal-audit.py — daily memory-consolidation audit.

Reads the append-only activity log (~/.claude/memory/journal.md), selects the
UN-audited entries (those newer than the high-water mark), asks Claude
(claude-sonnet-4-6) to classify each as state-bearing vs ephemeral and to draft
the canonical memory file(s) to create/update, then APPLIES the promotions
conservatively.

elpabl0's concept, adapted to our memory layout (one-fact-per-file, frontmatter
`type`, MEMORY.md index, [[wikilinks]]). See ~/.claude/memory/reference_auto_dream.md.

SAFETY (non-negotiable — this mutates the memory store):
  * DEFAULT = --dry-run. Live writes require an explicit --apply.
  * dry-run operates on a COPY of the memory dir, writes NOTHING to the real
    store, prints exactly what it WOULD promote, and does NOT advance the
    high-water mark.
  * Conservative: only ADD new files / APPEND-update existing ones. NEVER
    deletes or destructively overwrites existing memory.
  * Reversible: live runs back up the whole memory dir (tar.gz) before any write.
  * Idempotent: a high-water timestamp marks audited entries so they are never
    re-promoted. journal.md is never modified.
  * Fail-safe: any error -> change nothing (or restore from the just-made
    backup), log, exit non-zero.

Usage:
  journal-audit.py                # dry-run (default, safe) -> prints proposed promotions
  journal-audit.py --dry-run      # same, explicit
  journal-audit.py --apply        # LIVE: backup, promote, advance high-water
  journal-audit.py --apply --since 2026-05-01T00:00:00+07:00   # override high-water floor
"""

import argparse
import datetime as dt
import json
import os
import re
import shutil
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
MEMORY_DIR = HOME / ".claude" / "memory"
JOURNAL = MEMORY_DIR / "journal.md"
INDEX = MEMORY_DIR / "MEMORY.md"
STATE_FILE = MEMORY_DIR / ".journal-audit-state.json"
BACKUP_DIR = HOME / ".claude" / "memory-backups"
SECRETS = HOME / ".claude" / "secrets.env"
LOG = HOME / ".local" / "share" / "journal-audit" / "audit.log"

MODEL = "claude-sonnet-4-6"
API_URL = "https://api.anthropic.com/v1/messages"
API_VERSION = "2023-06-01"
MAX_TOKENS = 8000

VALID_TYPES = {"user", "feedback", "project", "reference"}
ENTRY_RE = re.compile(r"^- \[(?P<ts>[^\]]+)\]\s+\((?P<tag>[a-z]+)\)\s*(?P<summary>.*)$")


# --------------------------------------------------------------------------- #
# logging
# --------------------------------------------------------------------------- #
def log(msg: str) -> None:
    stamp = dt.datetime.now().astimezone().isoformat(timespec="seconds")
    line = f"[{stamp}] {msg}"
    print(line, file=sys.stderr)
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def die(msg: str, code: int = 1) -> "NoReturn":  # type: ignore[name-defined]
    log(f"FATAL: {msg}")
    sys.exit(code)


# --------------------------------------------------------------------------- #
# secrets — read API key without ever printing it
# --------------------------------------------------------------------------- #
def load_api_key() -> str:
    key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if key:
        return key
    if not SECRETS.exists():
        die("ANTHROPIC_API_KEY not in env and secrets.env not found")
    for raw in SECRETS.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("#") or "ANTHROPIC_API_KEY" not in line:
            continue
        # forms: `export ANTHROPIC_API_KEY=...` or `ANTHROPIC_API_KEY=...`
        m = re.search(r"ANTHROPIC_API_KEY\s*=\s*(.+)$", line)
        if m:
            val = m.group(1).strip().strip('"').strip("'")
            if val:
                return val
    die("ANTHROPIC_API_KEY not found in secrets.env")


# --------------------------------------------------------------------------- #
# journal parsing
# --------------------------------------------------------------------------- #
def parse_ts(s: str) -> dt.datetime:
    return dt.datetime.fromisoformat(s.strip())


def parse_journal(text: str) -> list[dict]:
    """Return list of {ts(str), dt(datetime), tag, summary, detail}."""
    entries: list[dict] = []
    cur: dict | None = None
    for raw in text.splitlines():
        m = ENTRY_RE.match(raw)
        if m:
            if cur:
                entries.append(cur)
            try:
                when = parse_ts(m.group("ts"))
            except ValueError:
                log(f"WARN: unparseable timestamp, skipping line: {raw[:80]}")
                cur = None
                continue
            cur = {
                "ts": m.group("ts").strip(),
                "dt": when,
                "tag": m.group("tag").strip(),
                "summary": m.group("summary").strip(),
                "detail": "",
            }
        elif cur is not None and raw.startswith("  "):
            cur["detail"] += (("\n" if cur["detail"] else "") + raw.strip())
        # any other line ends the current entry's continuation block
        elif cur is not None and raw.strip() == "":
            entries.append(cur)
            cur = None
    if cur:
        entries.append(cur)
    return entries


def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            log("WARN: state file unreadable, treating all entries as un-audited")
    return {}


def high_water(state: dict) -> dt.datetime | None:
    val = state.get("last_audited_ts")
    if not val:
        return None
    try:
        return parse_ts(val)
    except ValueError:
        return None


# --------------------------------------------------------------------------- #
# LLM call
# --------------------------------------------------------------------------- #
SYSTEM_PROMPT = """You are the memory-consolidation auditor for Christopher's \
file-based agent memory. The memory store is one-fact-per-file Markdown with \
YAML frontmatter (type: user|feedback|project|reference) plus a MEMORY.md index \
and [[wikilinks]] between files.

You receive (1) today's UN-audited journal entries and (2) the current MEMORY.md \
index. For each entry decide:
  - PROMOTE if it is state-bearing: a durable decision, a preference/feedback \
    about how to work, a durable project fact/constraint, or a reference \
    (person/tool/resource/credential-location). It must be worth recalling in a \
    FUTURE session.
  - SKIP if it is ephemeral: transient status, one-off chatter, in-flight \
    progress, anything not worth recalling later.

For PROMOTE entries, draft the canonical memory file. DEDUPE against the index: \
if an existing entry already covers this fact, return action "update" with that \
existing filename and an UPDATE snippet to APPEND (never a destructive rewrite). \
Only use action "create" for genuinely new facts.

File body format (match the existing store exactly):
---
name: <clear specific name>
description: <one-line, precise — used for relevance matching>
type: <user|feedback|project|reference>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [<relevant-tags>]
---

## Summary
<2-3 sentences>

## Details
<structured: headers/lists/bold>

## Context
<why it matters, what triggered it, [[wikilinks]] to related memories>

Filenames: <type>_<topic>.md, lowercase snake_case. Index lines: \
"- [Title](file.md) — short hook under 150 chars".

Be CONSERVATIVE: when unsure whether something is durable, prefer SKIP. Never \
invent facts not present in the entries. Reply with ONLY a single JSON object, \
no prose, no markdown fences."""

OUTPUT_SCHEMA_HINT = """Return JSON of this exact shape:
{
  "promotions": [
    {
      "action": "create" | "update",
      "filename": "<type>_<topic>.md",
      "type": "user|feedback|project|reference",
      "title": "<index title>",
      "index_line": "- [<title>](<filename>) — <hook>",
      "source_ts": "<the journal entry's timestamp>",
      "reason": "<why state-bearing>",
      "content": "<for create: the FULL file incl frontmatter. for update: ONLY the snippet to append, e.g. a '## Update <date>' section>"
    }
  ],
  "skipped": [
    { "source_ts": "<ts>", "reason": "<why ephemeral>" }
  ]
}"""


def build_user_message(entries: list[dict], index_text: str,
                       existing_files: list[str], today: str) -> str:
    lines = [f"Today is {today}.", "", "## Un-audited journal entries", ""]
    for e in entries:
        block = f"- [{e['ts']}] ({e['tag']}) {e['summary']}"
        if e["detail"]:
            for dl in e["detail"].splitlines():
                block += f"\n    {dl}"
        lines.append(block)
    lines += ["", "## Existing memory filenames (for dedupe)", ""]
    lines.append(", ".join(existing_files) if existing_files else "(none)")
    lines += ["", "## Current MEMORY.md index", "", index_text.strip(), "",
              OUTPUT_SCHEMA_HINT]
    return "\n".join(lines)


def call_llm(api_key: str, user_message: str) -> dict:
    payload = {
        "model": MODEL,
        "max_tokens": MAX_TOKENS,
        "system": SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": user_message}],
    }
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": API_VERSION,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as ex:
        detail = ex.read().decode("utf-8", "replace")[:500]
        die(f"LLM HTTP {ex.code}: {detail}", code=2)
    except urllib.error.URLError as ex:
        die(f"LLM network error: {ex.reason}", code=2)

    parts = body.get("content", [])
    text = "".join(p.get("text", "") for p in parts if p.get("type") == "text").strip()
    if not text:
        die(f"LLM returned no text (stop_reason={body.get('stop_reason')})", code=2)
    # strip accidental code fences
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip())
    try:
        return json.loads(text)
    except json.JSONDecodeError as ex:
        die(f"LLM returned non-JSON: {ex}; head={text[:200]!r}", code=2)


# --------------------------------------------------------------------------- #
# apply (operates on a target dir — real store or a copy)
# --------------------------------------------------------------------------- #
def validate_promotion(p: dict) -> str | None:
    for field in ("action", "filename", "type", "content", "index_line"):
        if not p.get(field):
            return f"missing field '{field}'"
    if p["action"] not in ("create", "update"):
        return f"bad action {p['action']!r}"
    if p["type"] not in VALID_TYPES:
        return f"bad type {p['type']!r}"
    fn = p["filename"]
    if "/" in fn or ".." in fn or not fn.endswith(".md"):
        return f"unsafe filename {fn!r}"
    return None


def apply_promotions(target_dir: Path, promotions: list[dict],
                     today: str) -> list[str]:
    """Apply to target_dir. Returns human-readable change log. Conservative:
    create only if absent (else degrade to append); update = append section."""
    changelog: list[str] = []
    index_path = target_dir / "MEMORY.md"
    index_text = index_path.read_text(encoding="utf-8") if index_path.exists() else ""
    index_lines_added: list[str] = []

    for p in promotions:
        err = validate_promotion(p)
        if err:
            changelog.append(f"SKIP-INVALID {p.get('filename','?')}: {err}")
            continue
        fn = p["filename"]
        dest = target_dir / fn
        content = p["content"].rstrip() + "\n"

        if p["action"] == "create" and dest.exists():
            # conservative: never overwrite — degrade to an append
            p = {**p, "action": "update"}
            changelog.append(f"NOTE {fn}: exists -> append instead of create")

        if p["action"] == "create":
            dest.write_text(content, encoding="utf-8")
            changelog.append(f"CREATE {fn}")
        else:  # update = append, never destroy
            existing = dest.read_text(encoding="utf-8") if dest.exists() else ""
            snippet = p["content"].strip()
            if not snippet.startswith("##"):
                snippet = f"## Update {today}\n{snippet}"
            joined = existing.rstrip() + "\n\n" + snippet + "\n"
            dest.write_text(joined, encoding="utf-8")
            changelog.append(f"APPEND {fn}")

        # index line — dedupe by filename
        idx_line = p["index_line"].strip()
        if f"]({fn})" not in index_text and f"]({fn})" not in "\n".join(index_lines_added):
            index_lines_added.append(idx_line)
            changelog.append(f"INDEX += {idx_line}")
        else:
            changelog.append(f"INDEX kept (already references {fn})")

    if index_lines_added:
        addition = "\n".join(index_lines_added)
        if index_text and not index_text.endswith("\n"):
            index_text += "\n"
        index_text += "\n<!-- promoted by journal-audit " + today + " -->\n" + addition + "\n"
        index_path.write_text(index_text, encoding="utf-8")

    return changelog


def backup_memory() -> Path:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    archive = BACKUP_DIR / f"memory-{stamp}.tar.gz"
    with tarfile.open(archive, "w:gz") as tar:
        # MEMORY_DIR is a symlink (-> the chilldawg-setup repo). tarfile lstat's
        # symlinks by default, so add(MEMORY_DIR) would archive only the link
        # (a useless ~260B tar). Resolve to the real dir so the actual memory
        # files are captured and the backup is a genuine restore artifact.
        tar.add(MEMORY_DIR.resolve(), arcname="memory")
    return archive


# --------------------------------------------------------------------------- #
# reporting
# --------------------------------------------------------------------------- #
def print_report(promotions: list[dict], skipped: list[dict],
                 changelog: list[str], dry: bool) -> None:
    mode = "DRY-RUN (no changes to real store)" if dry else "LIVE"
    out = ["", "=" * 70, f"  JOURNAL AUDIT REPORT — {mode}", "=" * 70, ""]
    out.append(f"Promotions proposed: {len(promotions)}   Skipped (ephemeral): {len(skipped)}")
    out.append("")
    for i, p in enumerate(promotions, 1):
        out.append(f"--- promotion {i}: {p.get('action','?').upper()} {p.get('filename','?')} "
                   f"(type={p.get('type','?')}) ---")
        out.append(f"    reason : {p.get('reason','')}")
        out.append(f"    source : {p.get('source_ts','')}")
        out.append(f"    index  : {p.get('index_line','')}")
        out.append("    content:")
        for line in (p.get("content", "")).splitlines():
            out.append("      | " + line)
        out.append("")
    if skipped:
        out.append("--- skipped (ephemeral) ---")
        for s in skipped:
            out.append(f"    [{s.get('source_ts','?')}] {s.get('reason','')}")
        out.append("")
    out.append("--- change log ---")
    out += [f"    {c}" for c in (changelog or ["(none)"])]
    out.append("=" * 70)
    print("\n".join(out))


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Daily journal -> memory audit.")
    ap.add_argument("--apply", action="store_true",
                    help="LIVE mode: backup, promote, advance high-water. "
                         "Default (no flag) is a safe dry-run.")
    ap.add_argument("--dry-run", action="store_true",
                    help="Explicit dry-run (default behaviour).")
    ap.add_argument("--since", metavar="ISO_TS",
                    help="Override the high-water floor (process entries after this).")
    args = ap.parse_args()

    if args.apply and args.dry_run:
        die("--apply and --dry-run are mutually exclusive", code=64)
    dry = not args.apply

    if not JOURNAL.exists():
        die(f"journal not found: {JOURNAL}")

    today = dt.datetime.now().strftime("%Y-%m-%d")
    entries = parse_journal(JOURNAL.read_text(encoding="utf-8"))
    state = load_state()

    floor: dt.datetime | None = None
    if args.since:
        try:
            floor = parse_ts(args.since)
        except ValueError:
            die(f"bad --since timestamp: {args.since}", code=64)
    else:
        floor = high_water(state)

    # un-audited = newer than floor; ephemeral-tagged are pre-filtered to skipped
    unaudited = [e for e in entries if floor is None or e["dt"] > floor]
    pre_skipped = [{"source_ts": e["ts"], "reason": f"pre-filtered: tag={e['tag']}"}
                   for e in unaudited if e["tag"] == "ephemeral"]
    candidates = [e for e in unaudited if e["tag"] != "ephemeral"]

    log(f"{'DRY-RUN' if dry else 'LIVE'}: {len(entries)} total, "
        f"{len(unaudited)} un-audited, {len(candidates)} candidates "
        f"(floor={floor.isoformat() if floor else 'none'})")

    if not candidates:
        print_report([], pre_skipped, ["no candidate entries — nothing to do"], dry)
        # still advance high-water in live mode so ephemerals aren't re-scanned
        if not dry and unaudited:
            newest = max(e["dt"] for e in unaudited)
            STATE_FILE.write_text(json.dumps(
                {"last_audited_ts": newest.isoformat(),
                 "audited_at": dt.datetime.now().astimezone().isoformat(timespec="seconds")},
                indent=2), encoding="utf-8")
        return 0

    api_key = load_api_key()
    index_text = INDEX.read_text(encoding="utf-8") if INDEX.exists() else ""
    existing_files = sorted(f.name for f in MEMORY_DIR.glob("*.md")
                            if f.name not in ("MEMORY.md", "journal.md"))
    user_msg = build_user_message(candidates, index_text, existing_files, today)

    result = call_llm(api_key, user_msg)
    promotions = result.get("promotions", []) or []
    skipped = (result.get("skipped", []) or []) + pre_skipped

    # ---- choose target dir: copy (dry) or real store (live) -------------- #
    if dry:
        tmp = Path(tempfile.mkdtemp(prefix="journal-audit-dry-"))
        copy_dir = tmp / "memory"
        shutil.copytree(MEMORY_DIR, copy_dir)
        try:
            changelog = apply_promotions(copy_dir, promotions, today)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        print_report(promotions, skipped, changelog, dry=True)
        log("dry-run complete — no changes to real store, high-water NOT advanced")
        return 0

    # ---- LIVE ------------------------------------------------------------ #
    archive = backup_memory()
    log(f"backed up memory -> {archive}")
    try:
        changelog = apply_promotions(MEMORY_DIR, promotions, today)
        newest = max(e["dt"] for e in unaudited)
        STATE_FILE.write_text(json.dumps(
            {"last_audited_ts": newest.isoformat(),
             "audited_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
             "last_backup": str(archive)},
            indent=2), encoding="utf-8")
    except Exception as ex:  # fail-safe: restore from backup
        log(f"ERROR during apply: {ex} — restoring from backup")
        try:
            with tarfile.open(archive, "r:gz") as tar:
                tmp = Path(tempfile.mkdtemp(prefix="journal-audit-restore-"))
                tar.extractall(tmp)
                restored = tmp / "memory"
                for item in restored.iterdir():
                    tgt = MEMORY_DIR / item.name
                    if item.is_file():
                        shutil.copy2(item, tgt)
                shutil.rmtree(tmp, ignore_errors=True)
            log("restore complete")
        except Exception as rex:
            log(f"RESTORE FAILED: {rex} — backup intact at {archive}")
        die(f"apply failed: {ex}", code=3)

    print_report(promotions, skipped, changelog, dry=False)
    log(f"LIVE audit complete — high-water -> {STATE_FILE}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as exc:  # ultimate fail-safe
        log(f"UNCAUGHT: {exc}")
        sys.exit(1)
