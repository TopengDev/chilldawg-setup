#!/usr/bin/env bash
# Spawn a claude worker in a new tmux window with attn plugin force-loaded.
#
# Usage: spawn-worker.sh <window_name> [<cwd>] [<task_dir>]
#   <task_dir> (or $TASK_DIR env) — task notes dir holding triage.json + STATE.md.
#   If omitted, the triage gate resolves it by convention:
#   ~/claude/notes/<window_name>-<YYYY-MM-DD>/triage.json (newest match).
#
# After this script returns 0, MAIN SESSION MUST verify attn round-trip
# by calling mcp__plugin_attn_attn__peers and confirming <window_name>
# appears in the local peers list before sending the brief.
#
# If peer doesn't appear within 15s after this script returns, KILL the
# window and retry. NO BRIEF until peer is visible.

set -euo pipefail

WINDOW_NAME="${1:?usage: spawn-worker.sh <window_name> [<cwd>] [<task_dir>]}"
CWD="${2:-$HOME/claude}"
TASK_DIR="${3:-${TASK_DIR:-}}"
TMUX_SESSION="${TMUX_SESSION:-0}"

# TRIAGE GATE (3-tier task hierarchy enforcement) — PRIMARY, fail-closed --------
# Refuse to spawn a worker without a valid triage.json. If level=L3, refuse unless
# signoff=true. Mirrors the STATE.md gate in brief-worker.sh. Runs BEFORE any tmux
# side effect so a blocked spawn leaves no window behind. The PreToolUse hook
# (~/.claude/hooks/triage-gate-hook.sh) is the belt-and-suspenders backstop.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_TRIAGE="$SCRIPT_DIR/check-triage.sh"
if [[ -x "$CHECK_TRIAGE" ]]; then
  if ! "$CHECK_TRIAGE" "$WINDOW_NAME" "$TASK_DIR"; then
    echo "" >&2
    echo "REFUSING TO SPAWN '$WINDOW_NAME': triage gate failed (see above)." >&2
    echo "Every worker needs a triage.json (task-complexity-triage + 3-tier)." >&2
    echo "See ~/.claude/scripts/TRIAGE-SCHEMA.md" >&2
    exit 4
  fi
else
  # Infra failure (check script missing) -> fail OPEN to avoid bricking spawning,
  # but loudly warn so the gate gets repaired.
  echo "WARNING: triage gate script not found/executable at $CHECK_TRIAGE" >&2
  echo "  Triage gate SKIPPED for '$WINDOW_NAME'. Repair before relying on enforcement." >&2
fi
# ------------------------------------------------------------------------------

# Sanity: tmux session must exist
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "ERROR: tmux session '$TMUX_SESSION' not found" >&2
  exit 1
fi

# Sanity: window name must not already exist
if tmux list-windows -t "$TMUX_SESSION" -F "#{window_name}" 2>/dev/null | grep -qx "$WINDOW_NAME"; then
  echo "ERROR: window '$WINDOW_NAME' already exists in session '$TMUX_SESSION'" >&2
  echo "  Either choose a different name OR kill the existing window first:" >&2
  echo "  tmux kill-window -t $TMUX_SESSION:$WINDOW_NAME" >&2
  exit 2
fi

# Create the window at the next available HIGHEST index.
# Don't use -a (appends after CURRENT, displaces existing windows including main).
# Compute: max existing index + 1, so new worker always lands at the tail.
NEXT_INDEX=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_index}' | sort -n | tail -1)
NEXT_INDEX=$((NEXT_INDEX + 1))
tmux new-window -t "${TMUX_SESSION}:${NEXT_INDEX}" -n "$WINDOW_NAME" -c "$CWD"
sleep 0.5

# Launch claude with attn.
# CRITICAL: set ATTN_SESSION env var to a unique name BEFORE claude starts.
# Without this, attn's checkDuplicateSession rejects the worker because the
# default session name collides with main (per attn v0.6.2 changelog). Result:
# "plugin:attn:attn · ✘ failed" in /mcp and no peer registration.
# Use the tmux window name as the session name — guaranteed unique within session 0.
#
# Also use --channels (not --dangerously-load-development-channels) to skip the
# interactive "I am using this for local development" confirmation prompt that
# blocks startup.
tmux send-keys -t "${TMUX_SESSION}:${NEXT_INDEX}" \
  "ATTN_SESSION='${WINDOW_NAME}' claude --dangerously-skip-permissions" \
  Enter

# Wait for claude to boot + MCP plugins to register.
# Empirical: claude prompt usually ready in 4-6s. attn registers shortly after.
sleep 8

echo "OK: window '$WINDOW_NAME' created, claude launched with attn plugin."
echo
echo "NEXT (main session MUST do):"
echo "  1. Call mcp__plugin_attn_attn__peers"
echo "  2. Confirm '$WINDOW_NAME' (or your assigned attn session name) is in local peers"
echo "  3. If NOT visible after 15s: kill window + retry script"
echo "     tmux kill-window -t ${TMUX_SESSION}:${WINDOW_NAME}"
echo "  4. Only after peer confirmed: send brief via tmux send-keys"
echo
echo "  5. After brief sent, worker MUST ping main via attn send to 'main'"
echo "     If worker doesn't ping within 60s, attn is not actually working"
echo "     in the worker session — investigate before continuing."
