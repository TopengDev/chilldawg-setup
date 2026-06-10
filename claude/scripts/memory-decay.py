#!/usr/bin/env python3
"""
memory-decay.py — conservatively ARCHIVE (never delete) clearly-stale memories.

The memory store accretes point-in-time snapshots (session-state dumps), merged
duplicates (REDIRECT stubs), and finished-project files. Left in place they bloat
the index and dilute relevance. This tool MOVES high-confidence-stale files into
`~/.claude/memory/archive/` — it never deletes. Archived files:
  * stay version-controlled in the private memory repo (fully recoverable),
  * drop out of the live INDEX automatically (gen-memory-index.py +
    journal-audit.py both glob '*.md' NON-recursively, so archive/ is invisible
    to the loader),
  * can be restored with a single `git mv` / `mv` back to the top level.

CONSERVATISM IS THE WHOLE POINT (per the brief — "when in doubt, KEEP"):
  Only files that match a HIGH-CONFIDENCE-stale signal AND pass every safety
  guard are archived. Everything else is kept.

  Stale signals (a file needs >=1):
    (S1) session-state snapshot  — filename matches project_session_state_*.md.
         These are explicit point-in-time dumps ("pre-restart snapshot"); newer
         ones supersede them.
    (S2) self-declared superseded/merged — the file's OWN body says it is a
         REDIRECT / "merged into" / "superseded by" / "replaced by" another file.

  Safety guards (ALL must hold, else KEEP):
    (G1) NOT referenced by [[wikilinks]] from any OTHER live (non-archived)
         memory file. (A redirect stub that things still point at must stay.)
    (G2) NOT a user_/feedback_ behavioral rule UNLESS it self-declares superseded
         (durable how-to-work rules don't "expire" by age).
    (G3) age: last-updated (frontmatter `updated:`, else file mtime) is at least
         MIN_AGE_DAYS old. (Don't archive something touched this week.)
    (G4) the file actually exists, is a top-level *.md, and is not MEMORY.md /
         journal.md.

Default = DRY-RUN (prints what it WOULD archive, moves nothing). `--apply` moves.
`--apply` still ONLY touches files that pass everything above.

Usage:
  memory-decay.py                 # dry-run: list archive candidates + reasons
  memory-decay.py --apply         # archive the safe candidates (move to archive/)
  memory-decay.py --min-age-days N
  memory-decay.py --json          # machine-readable candidate list (dry-run)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
MEMORY_DIR = HOME / ".claude" / "memory"
ARCHIVE_DIR = MEMORY_DIR / "archive"
DECAY_LOG = MEMORY_DIR / "archive" / "DECAY_LOG.md"

NON_ENTRY = {"MEMORY.md", "MEMORY.md.prev", "MEMORY.md.tmp", "journal.md"}
MIN_AGE_DAYS_DEFAULT = 21

SESSION_STATE_RE = re.compile(r"^project_session_state_.*\.md$")
WIKILINK_RE = re.compile(r"\[\[([A-Za-z0-9_\-]+)\]\]")

# S2 — a file is "self-declared superseded" ONLY when it announces so PROMINENTLY,
# i.e. in its frontmatter `description:` or in a markdown HEADING. We deliberately
# do NOT scan arbitrary body prose: incidental phrases like "...phone JID
# superseded by the LID..." (a JID change) or "OAuth redirect preservation" (a
# technical term) are NOT a file being retired, and a whole-body scan produced
# exactly those false positives. The marker must look like a redirect-stub
# declaration about THIS file.
SUPERSEDED_MARKER_RE = re.compile(
    r"^\s*REDIRECT\b"                                   # "REDIRECT — ..." (start)
    r"|\bmerged into\s+\[\[",                           # "merged into [[other]]"
    re.IGNORECASE,
)
SUPERSEDED_PHRASE_RE = re.compile(
    r"this (?:profile|file|memory|entry) (?:was|is) (?:a )?"
    r"(?:duplicate|deprecated|superseded|obsolete|merged|retired)",
    re.IGNORECASE,
)


def _split_fm(text: str) -> tuple[str, str]:
    if not text.startswith("---"):
        return "", text
    m = re.search(r"\n---\s*\n", text[3:])
    if not m:
        return "", text
    return text[3:3 + m.start()], text[3 + m.end():]


def is_self_superseded(text: str) -> bool:
    """True only if the file PROMINENTLY declares itself superseded/merged —
    in its frontmatter description, in a heading, or via an explicit
    'this profile/file was a duplicate/deprecated/...' phrase. Body-incidental
    mentions of 'superseded'/'redirect' do NOT count."""
    fm, body = _split_fm(text)
    # (a) frontmatter description line
    for raw in fm.splitlines():
        mm = re.match(r"^\s*description\s*:\s*(.+)$", raw)
        if mm and (SUPERSEDED_MARKER_RE.search(mm.group(1))
                   or SUPERSEDED_PHRASE_RE.search(mm.group(1))):
            return True
    # (b) any markdown heading line
    for line in body.splitlines():
        if re.match(r"^#{1,6}\s", line) and (
            SUPERSEDED_MARKER_RE.search(line) or SUPERSEDED_PHRASE_RE.search(line)
        ):
            return True
    # (c) the explicit duplicate/deprecated phrase anywhere (very specific)
    if SUPERSEDED_PHRASE_RE.search(body):
        return True
    return False


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def list_entries() -> list[Path]:
    return [p for p in sorted(MEMORY_DIR.glob("*.md")) if p.name not in NON_ENTRY]


def read_text(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8")
    except OSError:
        return ""


def frontmatter_updated(text: str) -> str | None:
    """Return the `updated:` date string (flat or nested), if any."""
    if not text.startswith("---"):
        return None
    m = re.search(r"\n---\s*\n", text[3:])
    fm = text[3:3 + m.start()] if m else text
    for raw in fm.splitlines():
        mm = re.match(r"^\s*updated\s*:\s*(.+)$", raw)
        if mm:
            return mm.group(1).strip().strip('"').strip("'")
    return None


def age_days(p: Path, text: str) -> float:
    """Days since last update (frontmatter `updated:` preferred, else mtime)."""
    u = frontmatter_updated(text)
    when: dt.datetime | None = None
    if u:
        for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S"):
            try:
                when = dt.datetime.strptime(u, fmt)
                break
            except ValueError:
                continue
    if when is None:
        try:
            when = dt.datetime.fromtimestamp(p.stat().st_mtime)
        except OSError:
            return 0.0
    # normalize to naive local for a simple delta
    if when.tzinfo is not None:
        when = when.astimezone().replace(tzinfo=None)
    return (dt.datetime.now() - when).total_seconds() / 86400.0


def build_inbound_wikilinks(entries: list[Path]) -> dict[str, set[str]]:
    """Map target-stem -> set of OTHER files that [[link]] to it."""
    inbound: dict[str, set[str]] = {}
    for p in entries:
        text = read_text(p)
        for target in WIKILINK_RE.findall(text):
            inbound.setdefault(target, set()).add(p.name)
    # remove self-references
    for target, srcs in inbound.items():
        srcs.discard(f"{target}.md")
    return inbound


# --------------------------------------------------------------------------- #
# candidate evaluation
# --------------------------------------------------------------------------- #
class Decision:
    __slots__ = ("path", "archive", "signals", "reason")

    def __init__(self, path: Path):
        self.path = path
        self.archive = False
        self.signals: list[str] = []
        self.reason = ""


def evaluate(p: Path, inbound: dict[str, set[str]], min_age: float) -> Decision:
    d = Decision(p)
    name = p.name
    stem = name[:-3] if name.endswith(".md") else name
    text = read_text(p)

    # ---- stale signals ---------------------------------------------------- #
    is_session_state = bool(SESSION_STATE_RE.match(name))
    is_superseded = is_self_superseded(text)
    if is_session_state:
        d.signals.append("S1:session-state-snapshot")
    if is_superseded:
        d.signals.append("S2:self-declared-superseded")

    if not d.signals:
        d.reason = "no stale signal — KEEP"
        return d

    # ---- safety guards (any failing -> KEEP) ------------------------------ #
    # G1: inbound wikilinks from other live files
    refs = inbound.get(stem, set())
    if refs:
        d.reason = (f"KEEP — referenced by [[{stem}]] from "
                    + ", ".join(sorted(refs)))
        return d

    # G2: durable behavioral rules don't expire by age; only archive if the file
    # itself declares it's superseded.
    if (name.startswith("user_") or name.startswith("feedback_")) and not is_superseded:
        d.reason = "KEEP — user/feedback rule, not self-declared superseded"
        return d

    # G3: age threshold
    a = age_days(p, text)
    if a < min_age:
        d.reason = f"KEEP — too recent ({a:.0f}d < {min_age:.0f}d threshold)"
        return d

    # all guards passed
    d.archive = True
    d.reason = (f"ARCHIVE — {'+'.join(d.signals)}; no inbound [[links]]; "
                f"{a:.0f}d old")
    return d


# --------------------------------------------------------------------------- #
# apply
# --------------------------------------------------------------------------- #
def do_archive(decisions: list[Decision]) -> list[str]:
    """Move ARCHIVE-flagged files into archive/. Returns log lines."""
    to_move = [d for d in decisions if d.archive]
    if not to_move:
        return ["nothing to archive"]
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    today = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logged: list[str] = []
    for d in to_move:
        dest = ARCHIVE_DIR / d.path.name
        if dest.exists():
            # don't clobber an existing archived copy; suffix with date
            dest = ARCHIVE_DIR / f"{d.path.stem}.{dt.datetime.now():%Y%m%d}.md"
        try:
            shutil.move(str(d.path), str(dest))
            logged.append(f"ARCHIVED {d.path.name} -> archive/{dest.name}  ({d.reason})")
        except OSError as ex:
            logged.append(f"FAILED to archive {d.path.name}: {ex}")
    # append a decay log (audit trail) inside archive/
    try:
        ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
        header = "" if DECAY_LOG.exists() else (
            "# Memory Decay Log\n\n"
            "Files moved here by memory-decay.py. Reversible: `mv archive/<f> ..` "
            "restores a file to the live store (then re-run gen-memory-index.py).\n")
        with DECAY_LOG.open("a", encoding="utf-8") as fh:
            if header:
                fh.write(header)
            fh.write(f"\n## {today}\n")
            for line in logged:
                fh.write(f"- {line}\n")
    except OSError:
        pass
    return logged


def regen_index() -> str:
    import subprocess
    gen = HOME / ".claude" / "scripts" / "gen-memory-index.py"
    if not gen.exists():
        return "gen-memory-index.py not found — index NOT regenerated"
    try:
        proc = subprocess.run([sys.executable, str(gen)],
                              capture_output=True, text=True, timeout=120)
        return (proc.stdout or proc.stderr).strip() or f"exit {proc.returncode}"
    except Exception as ex:  # noqa: BLE001
        return f"reindex error: {ex}"


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Conservatively archive stale memories.")
    ap.add_argument("--apply", action="store_true",
                    help="actually move stale files to archive/ (default: dry-run).")
    ap.add_argument("--min-age-days", type=int, default=MIN_AGE_DAYS_DEFAULT,
                    help=f"minimum age before archiving (default {MIN_AGE_DAYS_DEFAULT}).")
    ap.add_argument("--json", action="store_true",
                    help="emit machine-readable candidate list (implies dry-run).")
    args = ap.parse_args()

    if not MEMORY_DIR.is_dir():
        print(f"FATAL: memory dir not found: {MEMORY_DIR}", file=sys.stderr)
        return 1

    entries = list_entries()
    inbound = build_inbound_wikilinks(entries)
    decisions = [evaluate(p, inbound, float(args.min_age_days)) for p in entries]

    archive = [d for d in decisions if d.archive]
    # also surface "had a stale signal but was KEPT" for transparency
    kept_with_signal = [d for d in decisions if d.signals and not d.archive]

    if args.json:
        print(json.dumps({
            "archive": [{"file": d.path.name, "signals": d.signals,
                         "reason": d.reason} for d in archive],
            "kept_with_signal": [{"file": d.path.name, "signals": d.signals,
                                  "reason": d.reason} for d in kept_with_signal],
        }, indent=2))
        return 0

    mode = "APPLY" if args.apply else "DRY-RUN"
    print("=" * 70)
    print(f"  MEMORY DECAY — {mode}  (min-age={args.min_age_days}d, "
          f"{len(entries)} files scanned)")
    print("=" * 70)

    print(f"\nWOULD ARCHIVE ({len(archive)}):")
    for d in sorted(archive, key=lambda x: x.path.name):
        print(f"  • {d.path.name}\n      {d.reason}")
    if not archive:
        print("  (none — nothing meets the high-confidence-stale bar)")

    print(f"\nHAD STALE SIGNAL BUT KEPT ({len(kept_with_signal)}) — guard saved them:")
    for d in sorted(kept_with_signal, key=lambda x: x.path.name):
        print(f"  • {d.path.name}  [{'+'.join(d.signals)}]\n      {d.reason}")
    if not kept_with_signal:
        print("  (none)")

    if not args.apply:
        print("\nDRY-RUN — nothing moved. Re-run with --apply to archive the "
              "WOULD-ARCHIVE set above.")
        return 0

    # ---- APPLY ------------------------------------------------------------ #
    print("\n--- applying ---")
    for line in do_archive(decisions):
        print(f"  {line}")
    if archive:
        print(f"  index: {regen_index()}")
    print("\nDone. Archived files are recoverable from archive/ (and git history).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
