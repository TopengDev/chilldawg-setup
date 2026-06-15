#!/usr/bin/env bash
# spawn-supervisor.sh — spawn an OPUS SUPERVISOR in a new tmux window.
#
# Usage: spawn-supervisor.sh <window_name> [<cwd>] [<task_dir>]
#   <task_dir> (or $TASK_DIR env) — the INITIATIVE's task notes dir holding
#   triage.json + STATE.md (the supervisor's orchestration ledger). If omitted,
#   the triage gate resolves it by convention:
#   ~/claude/notes/<window_name>-<YYYY-MM-DD>/triage.json (newest match).
#
# WHAT A SUPERVISOR IS (Wave-7, 2026-06-15):
#   The orchestration model has THREE execution tiers:
#     main (Opus, command center, the ONLY WhatsApp-enabled session)
#       → supervisor (Opus, idle-cheap/event-driven, one per long-running initiative)
#         → workers (Sonnet, execution)
#   A supervisor DELEGATES to Sonnet workers (via spawn-worker.sh + brief-worker.sh),
#   maintains its STATE.md as a resumable orchestration ledger, and reports UP to
#   main via attn ONLY on meaningful checkpoints. It keeps main free to stay Toper's
#   conversation partner. It NEVER DMs Toper and NEVER sets WHATSAPP=1 — main is the
#   sole relay (supervisor → main → Toper).
#
# WHEN TO SPAWN ONE (not every task):
#   Only for a FLEET (multiple workers) or a LONG-RUNNING initiative (any L3, or an
#   L2 with a fleet / multi-hour horizon). A single-shot L1/L2 task → main spawns the
#   worker directly; no supervisor.
#
# This is a DELIBERATE near-parallel of spawn-worker.sh rather than a flag on it:
# keeping the supervisor spawner in its own file means a bug here can never brick
# the load-bearing worker-spawn path. The shared gates (check-triage.sh,
# worker-semaphore.sh) ARE reused.
#
# After this returns 0, MAIN SESSION MUST verify the attn round-trip (peers tool,
# window name appears) BEFORE briefing — then brief with:
#   brief-worker.sh --supervisor <window_name> <brief_file>

set -euo pipefail

WINDOW_NAME="${1:?usage: spawn-supervisor.sh <window_name> [<cwd>] [<task_dir>]}"
CWD="${2:-$HOME/claude}"
TASK_DIR="${3:-${TASK_DIR:-}}"
TMUX_SESSION="${TMUX_SESSION:-0}"
SUP_MODEL="${CHILLDAWG_SUPERVISOR_MODEL:-opus}"   # supervisors are Opus by decision

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TRIAGE GATE (reused, fail-closed) — a supervised initiative is still triaged.
# L3 still requires signoff=true. Same gate the worker path uses.
CHECK_TRIAGE="$SCRIPT_DIR/check-triage.sh"
if [[ -x "$CHECK_TRIAGE" ]]; then
  if ! "$CHECK_TRIAGE" "$WINDOW_NAME" "$TASK_DIR"; then
    echo "" >&2
    echo "REFUSING TO SPAWN SUPERVISOR '$WINDOW_NAME': triage gate failed (see above)." >&2
    echo "A supervised initiative still needs a triage.json (and L3 sign-off)." >&2
    echo "See ~/.claude/scripts/TRIAGE-SCHEMA.md" >&2
    exit 4
  fi
else
  echo "WARNING: triage gate script not found/executable at $CHECK_TRIAGE" >&2
  echo "  Triage gate SKIPPED for supervisor '$WINDOW_NAME'. Repair before relying on it." >&2
fi

# Sanity: tmux session must exist
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "ERROR: tmux session '$TMUX_SESSION' not found" >&2
  exit 1
fi

# Sanity: window name must not already exist
if tmux list-windows -t "$TMUX_SESSION" -F "#{window_name}" 2>/dev/null | grep -qx "$WINDOW_NAME"; then
  echo "ERROR: window '$WINDOW_NAME' already exists in session '$TMUX_SESSION'" >&2
  echo "  Choose a different name OR kill it first: tmux kill-window -t $TMUX_SESSION:$WINDOW_NAME" >&2
  exit 2
fi

# SUPERVISOR CONCURRENCY GOVERNOR — separate cap from workers. Fail-open.
SEMAPHORE="$SCRIPT_DIR/worker-semaphore.sh"
if [[ -r "$SEMAPHORE" ]]; then
  # shellcheck source=/dev/null
  source "$SEMAPHORE"
  if declare -F cs_supervisor_has_capacity >/dev/null 2>&1; then
    if ! cs_supervisor_has_capacity; then
      echo "" >&2
      echo "REFUSING TO SPAWN SUPERVISOR '$WINDOW_NAME': supervisor cap reached (CHILLDAWG_MAX_SUPERVISORS=$(_cs_supervisor_max))." >&2
      echo "  Live supervisors: $(cs_live_supervisor_count). Options:" >&2
      echo "    - finish/kill a supervisor, then retry" >&2
      echo "    - raise the cap: CHILLDAWG_MAX_SUPERVISORS=$(( $(_cs_supervisor_max) + 1 )) spawn-supervisor.sh ..." >&2
      echo "    - inspect: fleetview.sh   |   worker-semaphore.sh status" >&2
      exit 5
    fi
  fi
else
  echo "WARNING: worker-semaphore.sh not found/readable at $SEMAPHORE" >&2
  echo "  Supervisor governor SKIPPED for '$WINDOW_NAME' (fail-open). Repair to re-enable." >&2
fi

# Create the window at the next-highest index (never displace main/other windows).
NEXT_INDEX=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_index}' | sort -n | tail -1)
NEXT_INDEX=$((NEXT_INDEX + 1))
tmux new-window -t "${TMUX_SESSION}:${NEXT_INDEX}" -n "$WINDOW_NAME" -c "$CWD"
sleep 0.5

# Register in the SUPERVISOR registry (best-effort; never fails the spawn).
if declare -F cs_register_supervisor >/dev/null 2>&1; then
  cs_register_supervisor "$WINDOW_NAME"
fi

# Launch claude as an Opus supervisor with attn force-loaded + Remote Control on.
# Same launch contract as spawn-worker.sh (ATTN_SESSION unique = window name;
# --remote-control named; --dangerously-skip-permissions), only the model differs.
tmux send-keys -t "${TMUX_SESSION}:${NEXT_INDEX}" \
  "ATTN_SESSION='${WINDOW_NAME}' claude --model '${SUP_MODEL}' --remote-control '${WINDOW_NAME}' --dangerously-skip-permissions" \
  Enter

# Wait for claude to boot + MCP plugins to register (poll the pane, 30s ceiling).
READY_MAX=30
MCP_GRACE=3
BOOT_READY=0
for ((waited = 0; waited < READY_MAX; waited++)); do
  sleep 1
  PANE_BOOT=$(tmux capture-pane -t "${TMUX_SESSION}:${NEXT_INDEX}" -p -S -15 2>/dev/null || true)
  if echo "$PANE_BOOT" | grep -qE -- '-- INSERT --|bypass permissions on|^[[:space:]]*[❯>][[:space:]]'; then
    BOOT_READY=1
    break
  fi
done

if [[ "$BOOT_READY" == "1" ]]; then
  sleep "$MCP_GRACE"
  echo "OK: supervisor claude prompt ready after ~$((waited + 1 + MCP_GRACE))s (polled)."
else
  echo "WARN: supervisor prompt not detected within ${READY_MAX}s — proceeding anyway." >&2
  echo "      (Boot may be slow; the mandatory attn-peers check below is the real gate.)" >&2
fi

echo "OK: supervisor window '$WINDOW_NAME' created, claude launched on '${SUP_MODEL}' with attn."
echo
echo "NEXT (main session MUST do):"
echo "  1. Call mcp__plugin_attn_attn__peers"
echo "  2. Confirm '$WINDOW_NAME' is in local peers"
echo "  3. If NOT visible after 15s: kill window + retry"
echo "     tmux kill-window -t ${TMUX_SESSION}:${WINDOW_NAME}"
echo "  4. Only after peer confirmed: brief with the SUPERVISOR preamble:"
echo "     brief-worker.sh --supervisor ${WINDOW_NAME} <brief_file>"
echo
echo "  5. The supervisor's FIRST attn report to main must be its DIRECTION/partition"
echo "     plan (direction confirmation) BEFORE it spawns its fleet. If it doesn't"
echo "     report within a few minutes, investigate."
