#!/usr/bin/env python3
"""
gen-memory-index.py — regenerate ~/.claude/memory/MEMORY.md from frontmatter.

Replaces the hand-maintained MEMORY.md index with an auto-generated one built
from every memory file's YAML frontmatter. Solves two chronic problems:
  * orphans  — memory files that exist on disk but were never added to the index
               (the loader only ever sees indexed files; an orphan is invisible).
  * bloat    — the index outgrowing the loader's size cap so it loads only
               partially (warned in the live MEMORY.md header).

Frontmatter — ALL coexisting formats are parsed:
  (A) FLAT v1:  top-level `type: feedback`, `name:`, `description:`
  (B) NESTED:   `metadata:` block with `type:` / `created:` / `updated:` indented
               under it (Claude Code's older autosave format).
  (C) FLAT v2:  top-level `name:` (= stem slug), `title:` (human title),
               `namespace:` (identity|feedback|project|reference|contact|credential).
               This is the post-migration schema. `title:` is preferred for the
               index display title; `namespace:` drives grouping + sharding.

Grouping is by the `namespace:` field (fallback to legacy `type:`/filename infer).

SHARDING (v2): the MAIN MEMORY.md carries only the high-frequency namespaces
  identity · feedback · project · reference (fits the ~200-line loader cap).
  The bulk, lower-frequency `contact` and `credential` namespaces are written to
  SEPARATE shard indexes under indexes/ (contact.md, credential.md). The
  non-recursive *.md glob means files in indexes/ are NOT treated as entries.

Safety (this REPLACES live, load-bearing files):
  * VERIFY-BEFORE-REPLACE — render to TEMP, then assert across the UNION of
    {MEMORY.md, indexes/contact.md, indexes/credential.md}:
      (a) every memory .md appears in EXACTLY ONE index (0 orphans, 0 dupes),
      (b) 0 dangling links (every link target exists on disk),
      (c) MEMORY.md size < SIZE_CAP bytes (the loader cap),
      (d) each written index is well-formed (header + >=1 entry).
    Only on ALL-PASS are the live files atomically replaced (temp -> os.replace).
  * If the rendered MEMORY.md would EXCEED the cap, per-line hooks are trimmed
    progressively (longest first) until it fits — entries are NEVER dropped.
  * The previous MEMORY.md is backed up to MEMORY.md.prev (gitignored).
  * Read-only by default for everything except the index files it writes.

Usage:
  gen-memory-index.py                 # regenerate + replace MEMORY.md + shards
  gen-memory-index.py --check         # assert-only: render to temp, verify,
                                      #   print PASS/FAIL, write NOTHING
  gen-memory-index.py --print         # print rendered MEMORY.md to stdout
  gen-memory-index.py --cap N         # override the size cap (bytes)
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
from pathlib import Path

# PyYAML is used purely for frontmatter parsing (it ships in this environment and
# correctly handles the nested `metadata:` block the harness re-introduces). If it
# is somehow unavailable we fall back to the hand-rolled line parser below.
try:
    import yaml  # type: ignore

    _HAVE_YAML = True
except Exception:  # pragma: no cover - PyYAML is present in this env
    _HAVE_YAML = False

HOME = Path(os.environ.get("HOME", str(Path.home())))
# MEMORY_DIR overridable via env for testing (defaults to the real dir).
MEMORY_DIR = Path(os.environ.get("MEMORY_DIR_OVERRIDE", str(HOME / ".claude" / "memory")))
INDEX = MEMORY_DIR / "MEMORY.md"
PREV = MEMORY_DIR / "MEMORY.md.prev"
SHARD_DIR = MEMORY_DIR / "indexes"

# The Claude Code memory loader cap. Bytes, not chars.
SIZE_CAP = 24000

# Files in the memory dir that are NOT memory entries (never indexed as such).
NON_ENTRY = {"MEMORY.md", "MEMORY.md.prev", "journal.md"}

# Namespaces that live in the MAIN MEMORY.md (in this fixed order).
MAIN_NAMESPACES = ["identity", "feedback", "project", "reference"]
# Namespaces sharded out to indexes/<ns>.md.
SHARD_NAMESPACES = ["contact", "credential"]
ALL_NAMESPACES = MAIN_NAMESPACES + SHARD_NAMESPACES

SECTION_TITLE = {
    "identity": "Identity",
    "feedback": "Feedback",
    "project": "Projects",
    "reference": "References",
    "contact": "Contacts",
    "credential": "Credentials",
}

# Legacy type -> namespace (for any un-migrated v1 file).
LEGACY_TYPE_TO_NS = {
    "user": "identity",
    "feedback": "feedback",
    "project": "project",
    "reference": "reference",
}
WHATSAPP_PREFIX = "whatsapp_style_"

# Per-entry index line hard ceiling (chars).
MAX_LINE = 180
MIN_HOOK = 24


# --------------------------------------------------------------------------- #
# frontmatter parsing (no PyYAML dependency — handle all formats by hand)
# --------------------------------------------------------------------------- #
def split_frontmatter(text: str) -> tuple[str | None, str]:
    if not text.startswith("---"):
        return None, text
    m = re.search(r"\n---\s*\n", text[3:])
    if not m:
        return None, text
    fm = text[3 : 3 + m.start()]
    body = text[3 + m.end():]
    return fm, body


def _strip_val(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1]
        # un-escape the simple double-quote escapes our migrator emits
        v = v.replace('\\"', '"').replace("\\\\", "\\")
    return v.strip()


def _parse_frontmatter_lines(fm: str) -> dict:
    """Hand-rolled fallback frontmatter parser (used only if PyYAML is missing).
    Handles flat keys AND a nested `metadata:` block. Captures (at least, when
    present): name, description, title, namespace, type — and mirrors the nested
    metadata children up to the top level so field() can find them either way."""
    out: dict[str, object] = {}
    md: dict[str, object] = {}
    in_metadata = False
    for raw in fm.splitlines():
        if not raw.strip():
            continue
        if re.match(r"^metadata:\s*$", raw):
            in_metadata = True
            continue
        indented = raw.startswith("  ") or raw.startswith("\t")
        if in_metadata and indented:
            child = raw.strip()
            mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", child)
            if mm:
                key, val = mm.group(1), _strip_val(mm.group(2))
                if key not in md:
                    md[key] = val
            continue
        if in_metadata and not indented:
            in_metadata = False
        mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", raw)
        if mm:
            key, val = mm.group(1), _strip_val(mm.group(2))
            # top-level always wins for these display/grouping keys
            if key not in out or key in ("name", "description", "title", "namespace", "type"):
                out[key] = val
    if md:
        out["metadata"] = md
    return out


def parse_frontmatter(fm: str) -> dict:
    """Parse the frontmatter. Prefer PyYAML (correctly handles the nested
    `metadata:` block the harness re-introduces); fall back to the line parser.
    Returns the raw parsed dict — read individual fields via field()."""
    if _HAVE_YAML:
        try:
            loaded = yaml.safe_load(fm)
            if isinstance(loaded, dict):
                return loaded
        except Exception:
            pass
    return _parse_frontmatter_lines(fm)


def field(meta: dict, key: str):
    """Read a field TOP-LEVEL first, else from the nested `metadata:` block.
    The harness re-nests Write/Edit-saved memory files under `metadata:`; the
    corpus is mixed (flat v2 + nested), so every display/grouping field resolves
    both ways. Top-level always wins for flat files."""
    if not isinstance(meta, dict):
        return None
    if key in meta and meta[key] is not None:
        return meta[key]
    md = meta.get("metadata")
    if isinstance(md, dict):
        return md.get(key)
    return None


def first_heading_title(body: str) -> str | None:
    for line in body.splitlines():
        m = re.match(r"^#{1,6}\s+(.*)$", line.strip())
        if m:
            return m.group(1).strip()
    return None


# --------------------------------------------------------------------------- #
# entry model
# --------------------------------------------------------------------------- #
class Entry:
    __slots__ = ("filename", "title", "hook", "namespace")

    def __init__(self, filename: str, title: str, hook: str, namespace: str):
        self.filename = filename
        self.title = title
        self.hook = hook
        self.namespace = namespace

    def line(self, max_line: int = MAX_LINE) -> str:
        base = f"- [{self.title}]({self.filename})"
        if not self.hook:
            return base
        full = f"{base} — {self.hook}"
        if len(full) <= max_line:
            return full
        budget = max_line - len(base) - len(" — ") - 1
        if budget < MIN_HOOK:
            budget = MIN_HOOK
        trimmed = self.hook[:budget].rstrip(" ,.;:-")
        return f"{base} — {trimmed}…"


def humanize_stem(filename: str) -> str:
    stem = filename[:-3] if filename.endswith(".md") else filename
    for pref in ("whatsapp_style_", "feedback_", "project_", "reference_", "user_"):
        if stem.startswith(pref):
            stem = stem[len(pref):]
            break
    return stem.replace("_", " ").replace("-", " ").title()


def derive_title(meta: dict, body: str, filename: str) -> str:
    # v2: prefer the explicit human `title:` field (top-level or nested).
    title = str(field(meta, "title") or "").strip()
    if title:
        return title
    # v1 fallback: the old `name:` field IF it's not a bare slug/stem.
    name = str(field(meta, "name") or "").strip()
    stem = filename[:-3] if filename.endswith(".md") else filename
    if name and name != stem and not name.lower().endswith(".md"):
        return name
    h = first_heading_title(body)
    if h:
        return h
    return humanize_stem(filename)


def derive_hook(meta: dict, body: str) -> str:
    desc = str(field(meta, "description") or "").strip()
    if desc:
        return re.sub(r"\s+", " ", desc)
    for line in body.splitlines():
        s = line.strip()
        if s and not s.startswith("#") and not s.startswith("---"):
            return re.sub(r"\s+", " ", s)
    return ""


def infer_namespace(meta: dict, filename: str) -> str:
    # v2: explicit namespace wins (top-level or nested under metadata:).
    ns = str(field(meta, "namespace") or "").strip().lower()
    if ns in ALL_NAMESPACES:
        return ns
    # legacy type -> namespace
    t = str(field(meta, "type") or "").strip().lower()
    if t in LEGACY_TYPE_TO_NS:
        cand = LEGACY_TYPE_TO_NS[t]
        # a whatsapp_style file with legacy type=reference is really a contact
        if filename.startswith(WHATSAPP_PREFIX):
            return "contact"
        return cand
    # filename-prefix inference (last resort)
    if filename.startswith(WHATSAPP_PREFIX):
        return "contact"
    for pref, mapped in (("user_", "identity"), ("feedback_", "feedback"),
                         ("project_", "project"), ("reference_", "reference")):
        if filename.startswith(pref):
            return mapped
    return "reference"  # safe default — nothing dropped


def load_entries() -> tuple[list[Entry], list[str]]:
    entries: list[Entry] = []
    warnings: list[str] = []
    for path in sorted(MEMORY_DIR.glob("*.md")):   # non-recursive: indexes/ excluded
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
        ns = infer_namespace(meta, path.name)
        entries.append(Entry(path.name, title, hook, ns))
    return entries, warnings


# --------------------------------------------------------------------------- #
# render
# --------------------------------------------------------------------------- #
def _auto_header(today: str, extra: str = "") -> list[str]:
    return [
        f"<!-- AUTO-GENERATED by gen-memory-index.py on {today}. "
        "Do not hand-edit; edits are overwritten. "
        f"Source of truth = each memory file's frontmatter.{extra} -->",
        "",
    ]


def render_main(entries: list[Entry], max_line: int = MAX_LINE) -> str:
    """Render MEMORY.md — only the MAIN_NAMESPACES."""
    today = dt.datetime.now().strftime("%Y-%m-%d")
    out: list[str] = ["# Memory Index", ""]
    out += _auto_header(
        today,
        " Contacts + credentials are sharded to indexes/contact.md + indexes/credential.md.",
    )

    by_ns: dict[str, list[Entry]] = {ns: [] for ns in MAIN_NAMESPACES}
    for e in entries:
        if e.namespace in by_ns:
            by_ns[e.namespace].append(e)

    for ns in MAIN_NAMESPACES:
        group = by_ns.get(ns, [])
        if not group:
            continue
        out.append(f"## {SECTION_TITLE[ns]}")
        for e in sorted(group, key=lambda x: x.title.lower()):
            out.append(e.line(max_line))
        out.append("")

    # pointer footer so a reader knows the shards exist
    out.append("## Other indexes")
    out.append("- Contacts → [indexes/contact.md](indexes/contact.md)")
    out.append("- Credentials → [indexes/credential.md](indexes/credential.md)")
    out.append("")
    return "\n".join(out).rstrip() + "\n"


def render_shard(entries: list[Entry], ns: str, max_line: int = MAX_LINE) -> str:
    """Render a single shard index (e.g. indexes/contact.md)."""
    today = dt.datetime.now().strftime("%Y-%m-%d")
    out: list[str] = [f"# Memory Index — {SECTION_TITLE[ns]}", ""]
    out += _auto_header(today)
    group = [e for e in entries if e.namespace == ns]
    out.append(f"## {SECTION_TITLE[ns]}")
    for e in sorted(group, key=lambda x: x.title.lower()):
        out.append(e.line(max_line))
    out.append("")
    return "\n".join(out).rstrip() + "\n"


def render_main_fitting(entries: list[Entry], cap: int) -> tuple[str, int]:
    max_line = MAX_LINE
    text = render_main(entries, max_line)
    while len(text.encode("utf-8")) > cap and max_line > (len("- []() — …") + MIN_HOOK):
        max_line -= 8
        text = render_main(entries, max_line)
    if len(text.encode("utf-8")) > cap:
        raise RuntimeError(
            f"cannot fit MEMORY.md under {cap} bytes even at min line width "
            f"({len(text.encode('utf-8'))} bytes). Entries are never dropped. "
            "Increase --cap or shard more namespaces."
        )
    return text, max_line


# --------------------------------------------------------------------------- #
# verification (UNION across MEMORY.md + the shards)
# --------------------------------------------------------------------------- #
LINK_RE = re.compile(r"\]\((?P<fn>[^)]+\.md)\)")


def _entry_links(text: str) -> list[str]:
    """Only the bare-filename entry links (exclude indexes/… pointers)."""
    out = []
    for fn in LINK_RE.findall(text):
        if "/" in fn:           # skip indexes/contact.md style pointers
            continue
        out.append(fn)
    return out


def verify(main_text: str, shard_texts: dict[str, str],
           entries: list[Entry], cap: int) -> list[str]:
    fails: list[str] = []

    # gather entry links across the union, count occurrences per filename
    occur: dict[str, int] = {}
    for txt in [main_text, *shard_texts.values()]:
        for fn in _entry_links(txt):
            occur[fn] = occur.get(fn, 0) + 1

    expected = {e.filename for e in entries}

    # (a) completeness + exactly-once
    missing = expected - set(occur)
    if missing:
        fails.append(f"(a) {len(missing)} orphan file(s) in NO index: "
                     + ", ".join(sorted(missing)[:10])
                     + (" …" if len(missing) > 10 else ""))
    dupes = sorted(fn for fn, n in occur.items() if n > 1)
    if dupes:
        fails.append(f"(a) {len(dupes)} file(s) appear in >1 index: "
                     + ", ".join(dupes[:10])
                     + (" …" if len(dupes) > 10 else ""))

    # (b) no dangling links: every linked target exists on disk
    dangling = sorted(fn for fn in occur if not (MEMORY_DIR / fn).exists())
    if dangling:
        fails.append(f"(b) {len(dangling)} dangling link(s): "
                     + ", ".join(dangling[:10])
                     + (" …" if len(dangling) > 10 else ""))

    # (c) MEMORY.md size under cap
    size = len(main_text.encode("utf-8"))
    if size >= cap:
        fails.append(f"(c) MEMORY.md size {size} >= cap {cap}")

    # (d) well-formed: each written file has a header + >=1 entry line
    for label, txt in [("MEMORY.md", main_text), *shard_texts.items()]:
        if not txt.lstrip().startswith("# Memory Index"):
            fails.append(f"(d) {label}: missing '# Memory Index' header")
        if not _entry_links(txt):
            fails.append(f"(d) {label}: no entry lines rendered")

    return fails


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Regenerate MEMORY.md + shards from frontmatter.")
    ap.add_argument("--check", action="store_true",
                    help="assert-only: render + verify, write nothing.")
    ap.add_argument("--print", dest="do_print", action="store_true",
                    help="print rendered MEMORY.md to stdout, write nothing.")
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
        print("FATAL: no memory entries found — refusing to write empty indexes.",
              file=sys.stderr)
        return 1

    try:
        main_text, used_max = render_main_fitting(entries, args.cap)
    except RuntimeError as ex:
        print(f"FATAL: {ex}", file=sys.stderr)
        return 1

    shard_texts = {f"indexes/{ns}.md": render_shard(entries, ns)
                   for ns in SHARD_NAMESPACES
                   if any(e.namespace == ns for e in entries)}

    fails = verify(main_text, shard_texts, entries, args.cap)
    size = len(main_text.encode("utf-8"))

    if args.do_print:
        sys.stdout.write(main_text)
        for f in fails:
            print(f"VERIFY-FAIL: {f}", file=sys.stderr)
        return 0 if not fails else 1

    if args.check:
        ns_counts = {}
        for e in entries:
            ns_counts[e.namespace] = ns_counts.get(e.namespace, 0) + 1
        print(f"entries={len(entries)} MEMORY.md={size}B cap={args.cap}B "
              f"line_width={used_max} shards={list(shard_texts)} "
              f"ns={ns_counts} warnings={len(warnings)}")
        if fails:
            for f in fails:
                print(f"FAIL: {f}")
            return 1
        print("PASS: (a) 0 orphans / 0 dupes  (b) 0 dangling  "
              "(c) MEMORY.md under cap  (d) well-formed")
        return 0

    # ---- WRITE PATH: verify-before-replace ------------------------------- #
    if fails:
        print("REFUSING TO REPLACE — verification failed:", file=sys.stderr)
        for f in fails:
            print(f"  FAIL: {f}", file=sys.stderr)
        return 1

    SHARD_DIR.mkdir(parents=True, exist_ok=True)

    # write MEMORY.md atomically (back up prev first)
    tmp = INDEX.with_suffix(".md.tmp")
    tmp.write_text(main_text, encoding="utf-8")
    if INDEX.exists():
        try:
            PREV.write_text(INDEX.read_text(encoding="utf-8"), encoding="utf-8")
        except OSError as ex:
            print(f"WARN: could not write {PREV.name}: {ex}", file=sys.stderr)
    os.replace(tmp, INDEX)

    # write each shard atomically
    for rel, txt in shard_texts.items():
        dst = MEMORY_DIR / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        stmp = dst.with_suffix(".md.tmp")
        stmp.write_text(txt, encoding="utf-8")
        os.replace(stmp, dst)

    print(f"WROTE {INDEX} — entries(main namespaces)={sum(1 for e in entries if e.namespace in MAIN_NAMESPACES)} "
          f"size={size}B (cap {args.cap}B, line_width={used_max}). "
          f"shards: {', '.join(shard_texts)}. 0 orphans, 0 dangling. "
          f"prev backed up to {PREV.name}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
