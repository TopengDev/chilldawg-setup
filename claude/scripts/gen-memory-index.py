#!/usr/bin/env python3
"""
gen-memory-index.py — regenerate ~/.claude/memory/MEMORY.md from frontmatter.

Replaces the hand-maintained MEMORY.md index with an auto-generated one built
from every memory file's YAML frontmatter. Solves two chronic problems:
  * orphans  — memory files that exist on disk but were never added to the index
               (the loader only ever sees indexed files; an orphan is invisible).
  * bloat    — the index outgrowing the loader's size cap so it loads only
               partially (warned in the live MEMORY.md header).

Frontmatter — BOTH coexisting formats are parsed:
  (A) FLAT:    top-level `type: feedback`, `name:`, `description:`
  (B) NESTED:  `metadata:` block with `type:` / `created:` / `updated:` indented
              under it (Claude Code's newer autosave format), `name`+`description`
              still top-level.

Grouping (in this fixed order): User · Feedback · Project · Reference, with the
WhatsApp-style profiles (whatsapp_style_*.md, type=reference) split into their own
"WhatsApp Styles" sub-section at the end so the reference group stays scannable.

Safety (this REPLACES a live, load-bearing file):
  * VERIFY-BEFORE-REPLACE — render to a TEMP file, then assert:
      (a) every memory .md is represented (0 orphans),
      (b) 0 dangling links (every link target exists on disk),
      (c) size < SIZE_CAP bytes (the loader cap),
      (d) the output is well-formed (header + >=1 entry, balanced).
    Only on ALL-PASS is the live file atomically replaced (temp -> os.replace).
  * If the rendered index would EXCEED the cap, per-line hooks are trimmed
    progressively (longest first) until it fits — entries are NEVER dropped.
    If even fully-trimmed it can't fit, the run FAILS rather than truncate.
  * The previous MEMORY.md is backed up to MEMORY.md.prev (the *.prev pattern is
    gitignored; full history also lives in the private memory repo).
  * Read-only by default for everything except MEMORY.md + MEMORY.md.prev.

Usage:
  gen-memory-index.py                 # regenerate + replace MEMORY.md (verified)
  gen-memory-index.py --check         # assert-only: parse + render to temp,
                                      #   run all asserts, print PASS/FAIL,
                                      #   write NOTHING (exit 0 pass / 1 fail)
  gen-memory-index.py --print         # print the rendered index to stdout, no write
  gen-memory-index.py --cap N         # override the size cap (bytes)
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
MEMORY_DIR = HOME / ".claude" / "memory"
INDEX = MEMORY_DIR / "MEMORY.md"
PREV = MEMORY_DIR / "MEMORY.md.prev"

# The Claude Code memory loader cap. The live header warned at 24.4KB; we target
# safely under that. Bytes, not chars.
SIZE_CAP = 24000

# Files in the memory dir that are NOT memory entries (never indexed as such).
NON_ENTRY = {"MEMORY.md", "MEMORY.md.prev", "journal.md"}

# Fixed section order + headings.
SECTION_ORDER = ["user", "feedback", "project", "reference"]
SECTION_TITLE = {
    "user": "User",
    "feedback": "Feedback",
    "project": "Projects",
    "reference": "References",
}
WHATSAPP_PREFIX = "whatsapp_style_"
WHATSAPP_TITLE = "WhatsApp Styles"

# Per-entry index line hard ceiling (chars). The brief asked <=180.
MAX_LINE = 180
# Floor below which we won't trim a hook (keep it meaningful).
MIN_HOOK = 24


# --------------------------------------------------------------------------- #
# frontmatter parsing (no PyYAML dependency — handle both formats by hand)
# --------------------------------------------------------------------------- #
def split_frontmatter(text: str) -> tuple[str | None, str]:
    """Return (frontmatter_block, body). frontmatter is the text between the
    first two '---' fences. None if absent."""
    if not text.startswith("---"):
        return None, text
    # find the closing fence
    m = re.search(r"\n---\s*\n", text[3:])
    if not m:
        return None, text
    fm = text[3 : 3 + m.start()]
    body = text[3 + m.end():]
    return fm, body


def _strip_val(v: str) -> str:
    v = v.strip()
    # strip matching surrounding quotes
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1]
    return v.strip()


def parse_frontmatter(fm: str) -> dict:
    """Parse the (small, well-formed) frontmatter we control. Handles flat keys
    AND a nested `metadata:` block (2-space indented children). Returns a dict
    with at least possibly-present keys: name, description, type."""
    out: dict[str, str] = {}
    in_metadata = False
    for raw in fm.splitlines():
        if not raw.strip():
            continue
        # nested metadata block: a bare `metadata:` line, then indented children
        if re.match(r"^metadata:\s*$", raw):
            in_metadata = True
            continue
        indented = raw.startswith("  ") or raw.startswith("\t")
        if in_metadata and indented:
            child = raw.strip()
            mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", child)
            if mm:
                key, val = mm.group(1), _strip_val(mm.group(2))
                # only lift the keys we care about out of metadata (don't clobber
                # a top-level name/description with a metadata one)
                if key in ("type", "created", "updated", "node_type") and key not in out:
                    out[key] = val
            continue
        # any non-indented line ends the metadata block
        if in_metadata and not indented:
            in_metadata = False
        # top-level key
        mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", raw)
        if mm:
            key, val = mm.group(1), _strip_val(mm.group(2))
            if key not in out or key in ("name", "description"):
                out[key] = val
    return out


def first_heading_title(body: str) -> str | None:
    """Fallback title: first markdown heading text in the body."""
    for line in body.splitlines():
        m = re.match(r"^#{1,6}\s+(.*)$", line.strip())
        if m:
            return m.group(1).strip()
    return None


# --------------------------------------------------------------------------- #
# entry model
# --------------------------------------------------------------------------- #
class Entry:
    __slots__ = ("filename", "title", "hook", "type", "is_whatsapp")

    def __init__(self, filename: str, title: str, hook: str, etype: str):
        self.filename = filename
        self.title = title
        self.hook = hook
        self.type = etype
        self.is_whatsapp = filename.startswith(WHATSAPP_PREFIX)

    def line(self, max_line: int = MAX_LINE) -> str:
        """Render one index line, trimming the hook so the whole line <= max_line."""
        base = f"- [{self.title}]({self.filename})"
        if not self.hook:
            return base
        full = f"{base} — {self.hook}"
        if len(full) <= max_line:
            return full
        # trim the hook (never the link/title)
        budget = max_line - len(base) - len(" — ") - 1  # -1 for ellipsis
        if budget < MIN_HOOK:
            budget = MIN_HOOK
        trimmed = self.hook[:budget].rstrip(" ,.;:-")
        return f"{base} — {trimmed}…"


def derive_title(meta: dict, body: str, filename: str) -> str:
    name = (meta.get("name") or "").strip()
    if name and not name.lower().endswith(".md"):
        return name
    h = first_heading_title(body)
    if h:
        return h
    # last resort: humanize filename
    stem = filename[:-3] if filename.endswith(".md") else filename
    return stem.replace("_", " ")


def derive_hook(meta: dict, body: str) -> str:
    desc = (meta.get("description") or "").strip()
    if desc:
        return re.sub(r"\s+", " ", desc)
    # fallback: first non-empty, non-heading body line
    for line in body.splitlines():
        s = line.strip()
        if s and not s.startswith("#") and not s.startswith("---"):
            return re.sub(r"\s+", " ", s)
    return ""


def infer_type(meta: dict, filename: str) -> str:
    t = (meta.get("type") or "").strip().lower()
    if t in SECTION_TITLE:
        return t
    # infer from filename prefix
    for pref in ("user", "feedback", "project", "reference"):
        if filename.startswith(pref + "_"):
            return pref
    if filename.startswith(WHATSAPP_PREFIX):
        return "reference"
    return "reference"  # safe default — nothing gets dropped


def load_entries() -> tuple[list[Entry], list[str]]:
    """Return (entries, warnings). One Entry per memory .md file."""
    entries: list[Entry] = []
    warnings: list[str] = []
    for path in sorted(MEMORY_DIR.glob("*.md")):
        if path.name in NON_ENTRY:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as ex:
            warnings.append(f"unreadable {path.name}: {ex}")
            continue
        fm, body = split_frontmatter(text)
        meta = parse_frontmatter(fm) if fm else {}
        if not fm:
            warnings.append(f"no frontmatter: {path.name}")
        title = derive_title(meta, body, path.name)
        hook = derive_hook(meta, body)
        etype = infer_type(meta, path.name)
        entries.append(Entry(path.name, title, hook, etype))
    return entries, warnings


# --------------------------------------------------------------------------- #
# render
# --------------------------------------------------------------------------- #
def render(entries: list[Entry], max_line: int = MAX_LINE) -> str:
    today = dt.datetime.now().strftime("%Y-%m-%d")
    out: list[str] = []
    out.append("# Memory Index")
    out.append("")
    out.append(f"<!-- AUTO-GENERATED by gen-memory-index.py on {today}. "
               "Do not hand-edit; edits are overwritten. "
               "Source of truth = each memory file's frontmatter. -->")
    out.append("")

    by_type: dict[str, list[Entry]] = {t: [] for t in SECTION_ORDER}
    whatsapp: list[Entry] = []
    for e in entries:
        if e.is_whatsapp:
            whatsapp.append(e)
        else:
            by_type.setdefault(e.type, []).append(e)

    for t in SECTION_ORDER:
        group = by_type.get(t, [])
        # for the reference section, whatsapp styles are pulled out separately
        if not group and not (t == "reference" and whatsapp):
            continue
        out.append(f"## {SECTION_TITLE[t]}")
        for e in sorted(group, key=lambda x: x.title.lower()):
            out.append(e.line(max_line))
        out.append("")
        if t == "reference" and whatsapp:
            out.append(f"## {WHATSAPP_TITLE}")
            for e in sorted(whatsapp, key=lambda x: x.title.lower()):
                out.append(e.line(max_line))
            out.append("")

    return "\n".join(out).rstrip() + "\n"


def render_fitting(entries: list[Entry], cap: int) -> tuple[str, int]:
    """Render; if over cap, progressively shrink the per-line ceiling until it
    fits. Returns (text, final_max_line). Raises if it can't fit even at MIN."""
    max_line = MAX_LINE
    text = render(entries, max_line)
    while len(text.encode("utf-8")) > cap and max_line > (len("- []() — …") + MIN_HOOK):
        max_line -= 8
        text = render(entries, max_line)
    if len(text.encode("utf-8")) > cap:
        raise RuntimeError(
            f"cannot fit index under {cap} bytes even at min line width "
            f"({len(text.encode('utf-8'))} bytes, {len(entries)} entries). "
            "Hooks are maximally trimmed; entries are never dropped. "
            "Increase --cap or split the memory store."
        )
    return text, max_line


# --------------------------------------------------------------------------- #
# verification
# --------------------------------------------------------------------------- #
LINK_RE = re.compile(r"\]\((?P<fn>[^)]+\.md)\)")


def verify(text: str, entries: list[Entry], cap: int) -> list[str]:
    """Return a list of failure strings. Empty list == all asserts pass."""
    fails: list[str] = []
    linked = set(LINK_RE.findall(text))

    # (a) completeness: every memory file is represented
    expected = {e.filename for e in entries}
    missing = expected - linked
    if missing:
        fails.append(f"(a) {len(missing)} orphan file(s) not in index: "
                     + ", ".join(sorted(missing)[:10])
                     + (" …" if len(missing) > 10 else ""))

    # (b) no dangling links: every linked target exists on disk
    dangling = sorted(fn for fn in linked if not (MEMORY_DIR / fn).exists())
    if dangling:
        fails.append(f"(b) {len(dangling)} dangling link(s): "
                     + ", ".join(dangling[:10])
                     + (" …" if len(dangling) > 10 else ""))

    # (c) size under cap
    size = len(text.encode("utf-8"))
    if size >= cap:
        fails.append(f"(c) size {size} >= cap {cap}")

    # (d) well-formed: header present + at least one entry line + >=1 section
    if not text.lstrip().startswith("# Memory Index"):
        fails.append("(d) missing '# Memory Index' header")
    if not LINK_RE.search(text):
        fails.append("(d) no entry lines rendered")
    if "## " not in text:
        fails.append("(d) no section headings rendered")

    return fails


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Regenerate MEMORY.md from frontmatter.")
    ap.add_argument("--check", action="store_true",
                    help="assert-only: render + verify, write nothing. "
                         "exit 0 if all asserts pass, 1 otherwise.")
    ap.add_argument("--print", dest="do_print", action="store_true",
                    help="print rendered index to stdout, write nothing.")
    ap.add_argument("--cap", type=int, default=SIZE_CAP,
                    help=f"size cap in bytes (default {SIZE_CAP}).")
    args = ap.parse_args()

    if not MEMORY_DIR.is_dir():
        print(f"FATAL: memory dir not found: {MEMORY_DIR}", file=sys.stderr)
        return 1

    entries, warnings = load_entries()
    for w in warnings:
        print(f"WARN: {w}", file=sys.stderr)
    if not entries:
        print("FATAL: no memory entries found — refusing to write an empty index.",
              file=sys.stderr)
        return 1

    try:
        text, used_max = render_fitting(entries, args.cap)
    except RuntimeError as ex:
        print(f"FATAL: {ex}", file=sys.stderr)
        return 1

    fails = verify(text, entries, args.cap)
    size = len(text.encode("utf-8"))

    if args.do_print:
        sys.stdout.write(text)
        # still surface verification on stderr
        for f in fails:
            print(f"VERIFY-FAIL: {f}", file=sys.stderr)
        return 0 if not fails else 1

    if args.check:
        print(f"entries={len(entries)} size={size}B cap={args.cap}B "
              f"line_width={used_max} warnings={len(warnings)}")
        if fails:
            for f in fails:
                print(f"FAIL: {f}")
            return 1
        print("PASS: (a) 0 orphans  (b) 0 dangling  (c) under cap  (d) well-formed")
        return 0

    # ---- WRITE PATH: verify-before-replace ------------------------------- #
    if fails:
        print("REFUSING TO REPLACE — verification failed:", file=sys.stderr)
        for f in fails:
            print(f"  FAIL: {f}", file=sys.stderr)
        print(f"  (live MEMORY.md left untouched; entries={len(entries)} size={size}B)",
              file=sys.stderr)
        return 1

    # write to temp in the SAME dir (atomic os.replace requires same filesystem)
    tmp = INDEX.with_suffix(".md.tmp")
    tmp.write_text(text, encoding="utf-8")

    # back up the current live index (gitignored *.prev) before replacing
    if INDEX.exists():
        try:
            PREV.write_text(INDEX.read_text(encoding="utf-8"), encoding="utf-8")
        except OSError as ex:
            print(f"WARN: could not write {PREV.name}: {ex}", file=sys.stderr)

    os.replace(tmp, INDEX)
    print(f"WROTE {INDEX} — entries={len(entries)} size={size}B "
          f"(cap {args.cap}B, line_width={used_max}). "
          f"0 orphans, 0 dangling. prev backed up to {PREV.name}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
