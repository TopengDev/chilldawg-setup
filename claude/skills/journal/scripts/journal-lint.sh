#!/usr/bin/env bash
# journal-lint.sh - format validator for the append-only activity journal.
#
# The daily audit (journal-audit.py) only SEES lines that match its ENTRY_RE:
#   ^- \[<ts>\] \(<tag>\) <summary>
# plus 2-space-indented continuation lines. ANY other non-blank line in the
# entries region is INERT: the parser skips it and it never gets promoted. A
# hand-appended block that violates the format is therefore silently dropped
# (verified failure: the "## 2026-06-23 AURA Phase 4" block in journal.md, whose
# [[project_aura_svg_xss_fix]] target was never created). This linter surfaces
# every such line so you can re-append the fact CORRECTLY via journal-add.sh.
#
# It is READ-ONLY: it never edits the journal. Do not try to "fix" a malformed
# line in place, the journal is append-only.
#
# Usage:   journal-lint.sh [path-to-journal.md]
#   default path: ~/.claude/memory/journal.md
# Exit:    0 = clean, 1 = malformed line(s) found, 2 = journal not found
set -euo pipefail

JOURNAL="${1:-${HOME}/.claude/memory/journal.md}"

if [[ ! -f "$JOURNAL" ]]; then
  echo "journal-lint: journal not found at $JOURNAL" >&2
  echo "  (the appender does NOT create it. See failure-playbooks.md 'journal not found'.)" >&2
  exit 2
fi

# Scope to the entries region (everything after the "## Entries" marker) so the
# format-spec examples in the header block are never false-flagged. If the marker
# is absent (a damaged/rotated journal), scan the whole file and warn.
if grep -qE '^## Entries[[:space:]]*$' "$JOURNAL"; then
  wholefile=0
else
  wholefile=1
  echo "journal-lint: WARN no '## Entries' marker, scanning whole file" >&2
fi

# A line in the entries region is VALID iff it is one of:
#   - blank
#   - a continuation line (starts with 2+ spaces)
#   - an entry head:  - [<ts>] (<tag>) ...   (mirrors journal-audit.py ENTRY_RE)
# Anything else is malformed (a stray "## header", a plain "- bullet", prose).
malformed="$(awk -v wholefile="$wholefile" '
  /^## Entries[[:space:]]*$/ { inreg=1; next }
  (inreg || wholefile) {
    if (NF == 0)                        next   # blank
    if ($0 ~ /^  /)                     next   # continuation (2+ spaces)
    if ($0 ~ /^- \[[^]]+\] \([a-z]+\)/) next   # valid entry head
    printf "%d: %s\n", NR, $0
  }
' "$JOURNAL")"

if [[ -n "$malformed" ]]; then
  echo "journal-lint: MALFORMED line(s) invisible to the audit parser:" >&2
  echo "$malformed" >&2
  echo "" >&2
  echo "Recovery: do NOT hand-fix (append-only). Re-append each fact via" >&2
  echo "  ~/.claude/scripts/journal-add.sh <tag> \"<summary>\" [\"<detail>\"]" >&2
  echo "so it promotes; leave the inert text in place." >&2
  exit 1
fi

echo "journal-lint: OK, every entries-region line conforms ($JOURNAL)"
exit 0
