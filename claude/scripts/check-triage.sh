#!/usr/bin/env bash
# check-triage.sh — shared triage gate validator for the 3-tier task hierarchy.
#
# Usage: check-triage.sh <window_name> [<task_dir>]
#
# Resolves the task's triage.json, validates it, and enforces:
#   - triage.json MUST exist for the task being spawned
#   - level MUST be one of L1 / L2 / L3
#   - if level == L3, signoff MUST be true (Toper's explicit approval)
#
# triage.json schema (one per task, in the task notes dir beside STATE.md):
#   {
#     "task_slug": "<slug>",
#     "level":     "L1|L2|L3",
#     "scope":     "<one line>",
#     "created":   "<ISO ts>",
#     "signoff":   false        # L3 only: flips true after Toper approves
#   }
#
# Resolution order for finding triage.json:
#   1. Explicit: <task_dir> arg ($2) OR $TASK_DIR env  ->  "<dir>/triage.json"
#   2. Convention/glob: ~/claude/notes/<window_name>-*/triage.json, newest by mtime
#      (the task notes dir is conventionally "<window-name>-<YYYY-MM-DD>")
#
# Exit codes:
#   0  triage valid                  -> spawn ALLOWED
#   1  blocked (missing/invalid/L3-unsigned) -> reason on stderr
#   2  internal/usage error          -> caller decides:
#        - spawn-worker.sh: warns + fails OPEN (don't brick spawning on infra bug)
#        - PreToolUse hook: fails OPEN (never brick a Bash command on our bug)
#
# This is the single source of truth for the gate logic, shared by:
#   - ~/.claude/scripts/spawn-worker.sh        (PRIMARY, fail-closed at spawn)
#   - ~/.claude/hooks/triage-gate-hook.sh      (SECONDARY, PreToolUse belt-and-suspenders)

set -uo pipefail   # deliberately NO -e: we handle every error path explicitly

NOTES_DIR="${NOTES_DIR:-$HOME/claude/notes}"

WINDOW="${1:-}"
TASK_DIR_ARG="${2:-${TASK_DIR:-}}"

if [[ -z "$WINDOW" ]]; then
  echo "check-triage: usage: check-triage.sh <window_name> [<task_dir>]" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "check-triage: jq not found — cannot validate triage.json" >&2
  exit 2
fi

# --- resolve triage.json path ------------------------------------------------
TRIAGE=""
if [[ -n "$TASK_DIR_ARG" ]]; then
  TRIAGE="${TASK_DIR_ARG%/}/triage.json"
else
  newest=""
  newest_mtime=0
  shopt -s nullglob
  for d in "$NOTES_DIR/${WINDOW}-"*/; do
    f="${d}triage.json"
    [[ -f "$f" ]] || continue
    m=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    if (( m >= newest_mtime )); then
      newest_mtime=$m
      newest="$f"
    fi
  done
  shopt -u nullglob
  TRIAGE="$newest"
fi

if [[ -z "$TRIAGE" || ! -f "$TRIAGE" ]]; then
  {
    echo "TRIAGE GATE: no triage.json found for worker '$WINDOW' — spawn refused."
    if [[ -n "$TASK_DIR_ARG" ]]; then
      echo "  Expected: ${TASK_DIR_ARG%/}/triage.json"
    else
      echo "  Expected (convention): $NOTES_DIR/${WINDOW}-<YYYY-MM-DD>/triage.json"
    fi
    echo "  Every spawned worker MUST have a triage record (task-complexity-triage + 3-tier)."
    echo "  Create it, e.g.:"
    echo "    {\"task_slug\":\"$WINDOW\",\"level\":\"L1|L2|L3\",\"scope\":\"...\",\"created\":\"$(date -Iseconds)\",\"signoff\":false}"
    echo "  See ~/.claude/scripts/TRIAGE-SCHEMA.md"
  } >&2
  exit 1
fi

# --- validate JSON + fields --------------------------------------------------
if ! jq -e . "$TRIAGE" >/dev/null 2>&1; then
  echo "TRIAGE GATE: triage.json is not valid JSON: $TRIAGE — spawn refused." >&2
  exit 1
fi

level=$(jq -r '.level // ""' "$TRIAGE")
signoff=$(jq -r '.signoff // false' "$TRIAGE")

case "$level" in
  L1|L2|L3) ;;
  *)
    echo "TRIAGE GATE: invalid/missing 'level' (got '$level'); must be L1, L2, or L3. File: $TRIAGE — spawn refused." >&2
    exit 1
    ;;
esac

if [[ "$level" == "L3" && "$signoff" != "true" ]]; then
  {
    echo "TRIAGE GATE: L3 task '$WINDOW' requires Toper's explicit sign-off before spawn."
    echo "  triage.json has signoff=$signoff. The L3 HARD GATE: min 10 clarifying questions"
    echo "  + prototype validation + written plan + Toper sign-off must complete FIRST."
    echo "  Only then flip signoff -> true. File: $TRIAGE"
  } >&2
  exit 1
fi

echo "TRIAGE GATE: OK — worker '$WINDOW' level=$level signoff=$signoff ($TRIAGE)"
exit 0
