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

# CONCURRENCY GOVERNOR (semaphore) — ADDITIONAL gate, ordered AFTER triage ------
# The box is 4 vCPU / ~15GB; nothing else caps how many workers run at once.
# Refuse (or optionally wait+retry) if at/over CHILLDAWG_MAX_WORKERS live workers.
# FAIL-OPEN: if the count can't be determined, the helper allows the spawn — a
# counting bug must never brick the pipeline. Placed AFTER the triage gate (task
# validity first) and the window sanity checks, BEFORE any tmux side effect, so a
# capacity-refused spawn leaves no window behind.
SEMAPHORE="$SCRIPT_DIR/worker-semaphore.sh"
if [[ -r "$SEMAPHORE" ]]; then
  # shellcheck source=/dev/null
  source "$SEMAPHORE"
  SPAWN_WAIT="${CHILLDAWG_SPAWN_WAIT:-0}"
  if ! cs_has_capacity; then
    if [[ "$SPAWN_WAIT" =~ ^[0-9]+$ ]] && (( SPAWN_WAIT > 0 )); then
      echo "[semaphore] at cap — waiting up to ${SPAWN_WAIT}s for a free slot (CHILLDAWG_SPAWN_WAIT)..." >&2
      _got_slot=0
      for ((w = 0; w < SPAWN_WAIT; w++)); do
        sleep 1
        if cs_has_capacity 2>/dev/null; then _got_slot=1; break; fi
      done
      if (( _got_slot == 0 )); then
        echo "" >&2
        echo "REFUSING TO SPAWN '$WINDOW_NAME': worker cap reached (CHILLDAWG_MAX_WORKERS=$(_cs_max_workers)) and no slot freed within ${SPAWN_WAIT}s." >&2
        echo "  Live workers: $(cs_live_count). Kill a finished worker, raise the cap, or retry later." >&2
        echo "  Inspect the fleet: fleetview.sh" >&2
        exit 5
      fi
      echo "[semaphore] slot freed — proceeding." >&2
    else
      echo "" >&2
      echo "REFUSING TO SPAWN '$WINDOW_NAME': worker cap reached (CHILLDAWG_MAX_WORKERS=$(_cs_max_workers))." >&2
      echo "  Live workers: $(cs_live_count). Options:" >&2
      echo "    - finish/kill a worker, then retry" >&2
      echo "    - raise the cap:   CHILLDAWG_MAX_WORKERS=$(( $(_cs_max_workers) + 2 )) spawn-worker.sh ..." >&2
      echo "    - wait for a slot: CHILLDAWG_SPAWN_WAIT=120 spawn-worker.sh ...  (waits up to 120s)" >&2
      echo "    - inspect fleet:   fleetview.sh" >&2
      exit 5
    fi
  fi
else
  echo "WARNING: worker-semaphore.sh not found/readable at $SEMAPHORE" >&2
  echo "  Concurrency governor SKIPPED for '$WINDOW_NAME' (fail-open). Repair to re-enable." >&2
fi
# ------------------------------------------------------------------------------

# Create the window at the next available HIGHEST index.
# Don't use -a (appends after CURRENT, displaces existing windows including main).
# Compute: max existing index + 1, so new worker always lands at the tail.
NEXT_INDEX=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_index}' | sort -n | tail -1)
NEXT_INDEX=$((NEXT_INDEX + 1))
tmux new-window -t "${TMUX_SESSION}:${NEXT_INDEX}" -n "$WINDOW_NAME" -c "$CWD"
sleep 0.5

# Register this worker in the concurrency-governor registry (best-effort; a
# registry write failure never fails the spawn). The live count = registry ∩
# live tmux windows, so this is what makes the cap accurate + self-pruning.
if declare -F cs_register_worker >/dev/null 2>&1; then
  cs_register_worker "$WINDOW_NAME"
fi

# WORKER MODEL — Sonnet hard floor, Opus carve-out ----------------------------
# Policy (CLAUDE.md "Worker Model Policy — Sonnet Floor, Opus Carve-Out"):
# workers run on SONNET by default to cut token cost; OPUS is a DELIBERATE
# carve-out (security-critical / customer-facing design / novel root-cause
# debugging) that must be requested explicitly. Resolution precedence:
#   1. CHILLDAWG_WORKER_MODEL env   (explicit per-spawn override)
#   2. .model field in the worker's triage.json
#   3. default: sonnet
# Anything that is NOT an 'opus' token clamps to the sonnet FLOOR (never lower,
# e.g. never Haiku) — "hard floor" per Toper 2026-06-15.
_resolve_triage_file() {
  if [[ -n "${TASK_DIR:-}" ]]; then
    echo "${TASK_DIR%/}/triage.json"; return
  fi
  local newest="" m mt=0 d f
  shopt -s nullglob
  for d in "$HOME/claude/notes/${WINDOW_NAME}-"*/; do
    f="${d}triage.json"
    [[ -f "$f" ]] || continue
    m=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    if (( m >= mt )); then mt=$m; newest="$f"; fi
  done
  shopt -u nullglob
  echo "$newest"
}
_raw_model="${CHILLDAWG_WORKER_MODEL:-}"
if [[ -z "$_raw_model" ]]; then
  _tf="$(_resolve_triage_file)"
  if [[ -n "$_tf" && -f "$_tf" ]] && command -v jq >/dev/null 2>&1; then
    _raw_model="$(jq -r '.model // empty' "$_tf" 2>/dev/null || true)"
  fi
fi
case "$(printf '%s' "$_raw_model" | tr '[:upper:]' '[:lower:]')" in
  opus*) WORKER_MODEL="opus" ;;
  *)     WORKER_MODEL="sonnet" ;;
esac
echo "OK: worker model = '${WORKER_MODEL}' (sonnet floor; opus = explicit carve-out)."
# -----------------------------------------------------------------------------

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
#
# MANDATORY: --remote-control (Toper's rule 2026-05-31) — EVERY new claude
# session/worker must start with Remote Control on. Named per-worker (= window
# name) so RC sessions are identifiable; explicit name also avoids the optional
# [name] arg being misparsed.
tmux send-keys -t "${TMUX_SESSION}:${NEXT_INDEX}" \
  "ATTN_SESSION='${WINDOW_NAME}' claude --model '${WORKER_MODEL}' --remote-control '${WINDOW_NAME}' --dangerously-skip-permissions" \
  Enter

# Wait for claude to boot + MCP plugins to register.
# Empirical: claude prompt usually ready in 4-6s, but a cold start / slow MCP load
# can run longer — a fixed `sleep 8` either wastes time on a fast boot or fires the
# peer check too early on a slow one. Poll the pane for the chat-input readiness
# markers instead (same markers brief-worker.sh keys on), up to a 30s ceiling.
# attn/MCP plugins register a beat AFTER the prompt renders, so add a short grace
# once ready. Main still does the authoritative attn-peers check afterward; this
# poll only removes the brittle fixed wait. Conservative throughout — on timeout we
# fall through (don't abort the spawn) so the existing flow is never broken.
READY_MAX=30          # hard ceiling (seconds) before falling through
MCP_GRACE=3           # extra settle for attn/MCP registration after prompt appears
BOOT_READY=0
for ((waited = 0; waited < READY_MAX; waited++)); do
  sleep 1
  PANE_BOOT=$(tmux capture-pane -t "${TMUX_SESSION}:${NEXT_INDEX}" -p -S -15 2>/dev/null || true)
  # Readiness markers: the INSERT-mode footer, the bypass-permissions banner, or
  # the chat prompt glyph on its own. Any one means the input box is up.
  if echo "$PANE_BOOT" | grep -qE -- '-- INSERT --|bypass permissions on|^[[:space:]]*[❯>][[:space:]]'; then
    BOOT_READY=1
    break
  fi
done

if [[ "$BOOT_READY" == "1" ]]; then
  sleep "$MCP_GRACE"   # let attn/MCP finish registering now that the prompt is up
  echo "OK: claude prompt ready after ~$((waited + 1 + MCP_GRACE))s (polled)."
else
  echo "WARN: claude prompt not detected within ${READY_MAX}s — proceeding anyway." >&2
  echo "      (Boot may be slow; the mandatory attn-peers check below is the real gate.)" >&2
fi

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
