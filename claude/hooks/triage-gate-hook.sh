#!/usr/bin/env bash
# triage-gate-hook.sh — PreToolUse(Bash) belt-and-suspenders for the triage gate.
#
# Wired in settings.json as a PreToolUse hook with matcher "Bash". Fires on every
# Bash tool call but ONLY acts when the command genuinely INVOKES spawn-worker.sh
# (script in command position) — NOT when a command merely mentions the path
# (e.g. `ls`, `cat`, `grep`, `diff`, `vim` of the script). For real invocations it
# resolves + validates the task's triage.json via check-triage.sh and DENIES the
# tool call when triage is missing / invalid / L3-unsigned.
#
# Why this exists: spawn-worker.sh has the PRIMARY (fail-closed) guard, but a caller
# could invoke it in a way the wrapper's own exit can't stop. This hook catches
# spawn-worker.sh invocations regardless. (It only inspects Bash commands and only
# matches the spawn-worker.sh path in command position — a raw `tmux new-window ...
# claude` that hand-rolls a worker is out of scope; the script wrapper remains the
# canonical spawn path.)
#
# SAFETY — FAIL OPEN on every uncertainty:
#   * Command doesn't INVOKE spawn-worker.sh (mention-only, or non-spawn) -> allow
#   * Can't parse the window name                                          -> allow
#   * check-triage.sh missing / internal error                            -> allow
#   Only a CONFIRMED block (check-triage exit 1) emits a deny decision.
#   This hook must NEVER block a command that merely references the script, and
#   must NEVER brick spawning due to its own bugs. The script guard is canonical.
#
# NOTE: hooks load at session start. Editing this file or settings.json does NOT
# affect already-running sessions — restart Claude Code to pick up changes.

set -uo pipefail

CHECK_TRIAGE="$HOME/.claude/scripts/check-triage.sh"

# Read the tool-call JSON from stdin; extract the Bash command.
input="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"

# Cheap pre-filter: if the string isn't present at all, allow immediately.
printf '%s' "$cmd" | grep -q 'spawn-worker\.sh' || exit 0

ltrim() { printf '%s' "$1" | sed -E 's/^[[:space:]]+//'; }
strip_quotes() { local s="$1"; s="${s%\"}"; s="${s#\"}"; s="${s%\'}"; s="${s#\'}"; printf '%s' "$s"; }

# Split the command into simple-command pieces on separators ; | & and newlines
# (this also splits && and || into pieces, which is fine). For each piece that
# contains spawn-worker.sh, decide whether the script is in COMMAND POSITION.
window=""
task_dir=""
while IFS= read -r piece; do
  printf '%s' "$piece" | grep -q 'spawn-worker\.sh' || continue

  p="$(ltrim "$piece")"

  # Capture an explicit TASK_DIR=... from this piece (before stripping env assigns).
  if printf '%s' "$p" | grep -qE '(^|[[:space:]])TASK_DIR='; then
    task_dir="$(printf '%s' "$p" | sed -nE 's/.*TASK_DIR=([^[:space:]]+).*/\1/p' | head -1)"
  fi

  # Strip leading env-var assignments (VAR=val ...), repeatedly.
  while [[ "$p" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+ ]]; do
    p="$(printf '%s' "$p" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+//')"
  done
  # Strip a leading interpreter/wrapper (bash|sh|exec|env|command ...).
  while [[ "$p" =~ ^(bash|sh|exec|env|command)[[:space:]]+ ]]; do
    p="$(printf '%s' "$p" | sed -E 's/^(bash|sh|exec|env|command)[[:space:]]+//')"
  done

  # First token of the (cleaned) piece.
  first="${p%%[[:space:]]*}"

  # Command position iff the first token IS the spawn-worker.sh script
  # (its path ends with /spawn-worker.sh, or it's exactly spawn-worker.sh).
  if [[ "$first" == *spawn-worker.sh ]]; then
    rest="$(ltrim "${p#"$first"}")"
    window="$(strip_quotes "${rest%%[[:space:]]*}")"
    break   # first real invocation wins
  fi
  # else: mention-only (e.g. `ls spawn-worker.sh`) — keep scanning other pieces.
done < <(printf '%s\n' "$cmd" | tr ';|&\n' '\n\n\n\n')

# No genuine invocation found, or window unparseable -> FAIL OPEN (allow).
[[ -z "$window" ]] && exit 0
[[ -x "$CHECK_TRIAGE" ]] || exit 0

task_dir="$(strip_quotes "$task_dir")"

# Run the shared gate. Capture stderr (reason), discard stdout.
reason="$("$CHECK_TRIAGE" "$window" "$task_dir" 2>&1 >/dev/null)"
rc=$?

if [[ $rc -eq 0 ]]; then
  exit 0                      # allowed
elif [[ $rc -eq 1 ]]; then
  # Confirmed block -> deny the spawn.
  msg="TRIAGE GATE (hook): refusing to spawn worker '$window'. ${reason}  For L3, obtain Toper sign-off then set signoff=true in triage.json. Schema: ~/.claude/scripts/TRIAGE-SCHEMA.md"
  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m}}'
  exit 0
else
  exit 0                      # rc==2 internal/usage error -> FAIL OPEN
fi
