#!/usr/bin/env bash
# journal-add.sh — append one tagged entry to the activity journal (append-only).
#
# Usage:  journal-add.sh <tag> "<summary>" ["<optional detail>"]
#   tag = decision | feedback | project | reference | ephemeral
#
# Writes to ~/.claude/memory/journal.md in the exact format the daily audit
# (journal-audit.py) parses. Append-only — never edits or deletes prior entries.
set -euo pipefail

JOURNAL="${HOME}/.claude/memory/journal.md"
VALID="decision feedback project reference ephemeral"

tag="${1:-}"
summary="${2:-}"
detail="${3:-}"

if [[ -z "$tag" || -z "$summary" ]]; then
  echo "usage: journal-add.sh <tag> \"<summary>\" [\"<detail>\"]" >&2
  echo "  tag one of: $VALID" >&2
  exit 64
fi
if ! grep -qw "$tag" <<<"$VALID"; then
  echo "error: invalid tag '$tag' (must be one of: $VALID)" >&2
  exit 64
fi
if [[ ! -f "$JOURNAL" ]]; then
  echo "error: journal not found at $JOURNAL" >&2
  exit 1
fi

ts="$(TZ=Asia/Jakarta date +%Y-%m-%dT%H:%M:%S+07:00)"

{
  printf -- '- [%s] (%s) %s\n' "$ts" "$tag" "$summary"
  if [[ -n "$detail" ]]; then
    # indent each detail line by 2 spaces (continuation lines)
    while IFS= read -r line; do
      printf -- '  %s\n' "$line"
    done <<<"$detail"
  fi
} >> "$JOURNAL"

echo "journaled [$ts] ($tag) $summary"
