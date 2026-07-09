#!/usr/bin/env bash
# spawn-worker.sh — spawn a WORKER as a PANE inside its SUPERVISOR's tmux window.
#
# Usage: spawn-worker.sh <supervisor_window> <worker_name> [<cwd>] [<task_dir>]
#   <supervisor_window>  the tmux window of the owning supervisor (its window name,
#                        = the supervisor's attn name). The worker is split INTO
#                        this window's RIGHT column. Must already exist.
#   <worker_name>        the worker's identity: attn local-peer name, Remote Control
#                        name, pane title, and triage key. Must be unique.
#   <cwd>                worker cwd — the project repo/ (or a worktree). Defaults, in
#                        order, to: ~/claude/projects/<supervisor_window>/repo,
#                        then .../<supervisor_window>, then ~/claude (with a NOTE).
#   <task_dir>           the task dir holding triage.json + STATE.md, project-rooted:
#                        ~/claude/projects/<project>/tasks/<slug>/ . May also be given
#                        via $TASK_DIR. If omitted the triage gate falls back to the
#                        ~/claude/notes/<worker_name>-<date>/ convention.
#
# ── AGENT-ORG MODEL (2026-07-09 refactor, piece 2) ───────────────────────────
# A worker EXECUTES ONE task and reports to ITS MANAGER (the spawning supervisor or
# the VPS manager) — NOT to main. It lives as a PANE in its supervisor's window so
# one glance at that window = the supervisor (left) + all its workers (right column).
#
# TMUX PANE GEOMETRY (exact):
#   * FIRST worker in the window  ->  split -h off the SUPERVISOR pane
#                                     (supervisor becomes LEFT, worker becomes RIGHT)
#   * EACH SUBSEQUENT worker       ->  split -v off the BOTTOM-MOST right-column pane
#                                     (new worker stacks BELOW the previous worker)
#   * after each add: rebalance to "main pane left + rest stacked right" via
#     explicit main-pane-width sizing + `select-layout main-vertical`.
#
# Changes vs the pre-agent-org worker spawner:
#   * Worker is a PANE in the supervisor's window (was: its own new window).
#   * cwd defaults to the project repo/ (was: ~/claude).
#   * The CHILLDAWG_MAX_WORKERS concurrency SEMAPHORE GATE is REMOVED entirely
#     (unlimited concurrency; Christopher manages the box). A non-blocking OOM
#     heads-up hook replaces it.
#   * attn peer / report target = the SUPERVISOR (not main).
# Kept: the fail-closed triage gate, the Sonnet-floor / Opus-carve-out model
# resolution, the attn force-load + dev-channels auto-confirm + boot poll.
#
# After this returns 0, the SUPERVISOR MUST verify the attn round-trip (peers tool
# shows <worker_name>) BEFORE briefing, then brief with the worker preamble:
#   brief-worker.sh <worker_name> <brief_file>        (full 3-tier)
#   brief-worker.sh --quick <worker_name> <brief_file> (L1 fast-path)

set -euo pipefail

SUP_WINDOW="${1:?usage: spawn-worker.sh <supervisor_window> <worker_name> [<cwd>] [<task_dir>]}"
WORKER_NAME="${2:?usage: spawn-worker.sh <supervisor_window> <worker_name> [<cwd>] [<task_dir>]}"
CWD_ARG="${3:-}"
TASK_DIR="${4:-${TASK_DIR:-}}"
TMUX_SESSION="${TMUX_SESSION:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIN="${TMUX_SESSION}:${SUP_WINDOW}"

# ── TRIAGE GATE (3-tier hierarchy enforcement) — PRIMARY, fail-closed ─────────
# Refuse to spawn a worker without a valid triage.json (L3 also needs signoff=true).
# Runs BEFORE any tmux side effect so a blocked spawn leaves no pane behind.
CHECK_TRIAGE="$SCRIPT_DIR/check-triage.sh"
if [[ -x "$CHECK_TRIAGE" ]]; then
  if ! "$CHECK_TRIAGE" "$WORKER_NAME" "$TASK_DIR"; then
    echo "" >&2
    echo "REFUSING TO SPAWN '$WORKER_NAME': triage gate failed (see above)." >&2
    echo "Every worker needs a triage.json (task-complexity-triage + 3-tier)." >&2
    echo "See ~/.claude/scripts/TRIAGE-SCHEMA.md" >&2
    exit 4
  fi
else
  echo "WARNING: triage gate script not found/executable at $CHECK_TRIAGE" >&2
  echo "  Triage gate SKIPPED for '$WORKER_NAME' (fail-open). Repair before relying on it." >&2
fi

# Sanity: tmux session must exist.
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "ERROR: tmux session '$TMUX_SESSION' not found" >&2
  exit 1
fi

# Sanity: the SUPERVISOR window must EXIST (we split a pane INTO it).
if ! tmux list-windows -t "$TMUX_SESSION" -F "#{window_name}" 2>/dev/null | grep -qx "$SUP_WINDOW"; then
  echo "ERROR: supervisor window '$SUP_WINDOW' not found in session '$TMUX_SESSION'" >&2
  echo "  Spawn the supervisor first:  spawn-supervisor.sh <project> [$SUP_WINDOW]" >&2
  exit 2
fi

# Sanity: worker_name must be unique across the session's pane titles (avoids an
# attn ATTN_SESSION collision, which would make the new worker's attn silently
# fail). Best-effort (fail-open if titles can't be read).
if EXISTING_TITLES="$(tmux list-panes -s -t "$TMUX_SESSION" -F '#{pane_title}' 2>/dev/null)"; then
  if printf '%s\n' "$EXISTING_TITLES" | grep -qx "$WORKER_NAME"; then
    echo "ERROR: a pane titled '$WORKER_NAME' already exists in session '$TMUX_SESSION'." >&2
    echo "  Worker names must be unique (they are attn session names). Pick another," >&2
    echo "  or kill the stale worker pane first." >&2
    exit 2
  fi
fi

# ── OOM heads-up hook (heads-up, NEVER a block) ──────────────────────────────
# Concurrency is UNLIMITED (the semaphore gate is gone; Christopher manages the
# box). The only obligation on the delegating manager is to FLAG a likely-OOM
# BEFORE spawning. Two non-blocking channels:
#   1. Caller hook (the one-liner): main/supervisor sets CHILLDAWG_OOM_WARN=<msg>
#      (or =1) when its judgment says "e.g. 3rd heavy Opus worker on a 4-vCPU box";
#      we echo it loudly and PROCEED.
#   2. Best-effort auto-heuristic: if available RAM is low, echo a heads-up.
# Neither ever exits non-zero. See memory reference_local_box_oom_heavy_workers.
if [[ -n "${CHILLDAWG_OOM_WARN:-}" ]]; then
  echo "WARNING [OOM heads-up]: ${CHILLDAWG_OOM_WARN}" >&2
  echo "  -> proceeding anyway (heads-up, not a block)." >&2
fi
if command -v free >/dev/null 2>&1; then
  _avail_mb="$(free -m 2>/dev/null | awk '/^Mem:/{print $7}' || true)"
  if [[ "$_avail_mb" =~ ^[0-9]+$ ]] && (( _avail_mb < 1500 )); then
    echo "WARNING [OOM heads-up]: only ${_avail_mb}MB RAM available — another claude may OOM." >&2
    echo "  -> proceeding anyway (heads-up, not a block)." >&2
  fi
fi

# ── Resolve worker cwd (project repo/ or worktree) ───────────────────────────
if [[ -n "$CWD_ARG" ]]; then
  CWD="$CWD_ARG"
elif [[ -d "$HOME/claude/projects/$SUP_WINDOW/repo" ]]; then
  CWD="$HOME/claude/projects/$SUP_WINDOW/repo"
elif [[ -d "$HOME/claude/projects/$SUP_WINDOW" ]]; then
  CWD="$HOME/claude/projects/$SUP_WINDOW"
else
  CWD="$HOME/claude"
  echo "NOTE: no cwd given and no ~/claude/projects/${SUP_WINDOW}[/repo] — defaulting cwd to $CWD." >&2
  echo "      Pass the project repo/ (or a worktree) as arg 3 for a real worker." >&2
fi
if [[ ! -d "$CWD" ]]; then
  echo "ERROR: worker cwd does not exist: $CWD" >&2
  exit 2
fi

# ── WORKER MODEL — Sonnet hard floor, Opus carve-out (unchanged policy) ───────
# Precedence: CHILLDAWG_WORKER_MODEL env > triage.json .model > default sonnet.
# Anything that is NOT an 'opus' token clamps to the sonnet FLOOR (never Haiku).
_resolve_triage_file() {
  if [[ -n "${TASK_DIR:-}" ]]; then
    echo "${TASK_DIR%/}/triage.json"; return
  fi
  local newest="" m mt=0 d f
  shopt -s nullglob
  for d in "$HOME/claude/notes/${WORKER_NAME}-"*/; do
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
  *)     WORKER_MODEL="claude-sonnet-5" ;;
esac
echo "OK: worker model = '${WORKER_MODEL}' (sonnet floor; opus = explicit carve-out)."

# ── TMUX PANE GEOMETRY ───────────────────────────────────────────────────────
# Snapshot the target window's panes: "pane_id pane_left pane_top" per line.
# Identify the SUPERVISOR pane (leftmost, tie-break topmost) and the RIGHT column
# (panes to the right of the supervisor). First worker => right column is empty.
mapfile -t PANE_ROWS < <(tmux list-panes -t "$WIN" -F '#{pane_id} #{pane_left} #{pane_top}' 2>/dev/null || true)
if (( ${#PANE_ROWS[@]} == 0 )); then
  echo "ERROR: could not read panes of window '$WIN' (window gone?)." >&2
  exit 2
fi

sup_pane=""; sup_left=0; sup_top=0
for row in "${PANE_ROWS[@]}"; do
  pid="${row%% *}"; rest="${row#* }"; pleft="${rest%% *}"; ptop="${rest##* }"
  [[ "$pid" =~ ^%[0-9]+$ ]] || continue
  if [[ -z "$sup_pane" ]] || (( pleft < sup_left )) || { (( pleft == sup_left )) && (( ptop < sup_top )); }; then
    sup_pane="$pid"; sup_left="$pleft"; sup_top="$ptop"
  fi
done
if [[ -z "$sup_pane" ]]; then
  echo "ERROR: could not identify the supervisor (left) pane in '$WIN'." >&2
  exit 2
fi

bottom_pane=""; bottom_top=-1; right_count=0
for row in "${PANE_ROWS[@]}"; do
  pid="${row%% *}"; rest="${row#* }"; pleft="${rest%% *}"; ptop="${rest##* }"
  [[ "$pid" =~ ^%[0-9]+$ ]] || continue
  [[ "$pid" == "$sup_pane" ]] && continue
  if (( pleft > sup_left )); then                 # a right-column (worker) pane
    right_count=$((right_count + 1))
    if (( ptop > bottom_top )); then bottom_top="$ptop"; bottom_pane="$pid"; fi
  fi
done

if (( right_count == 0 )); then
  # FIRST worker: split the supervisor horizontally -> supervisor LEFT, worker RIGHT.
  echo "geometry: first worker in '$SUP_WINDOW' -> split -h off supervisor pane $sup_pane"
  NEW_PANE="$(tmux split-window -h -t "$sup_pane" -c "$CWD" -P -F '#{pane_id}')"
else
  # SUBSEQUENT worker: split the bottom-most right-column pane vertically -> stack below.
  echo "geometry: worker #$((right_count + 1)) in '$SUP_WINDOW' -> split -v below right-column pane $bottom_pane"
  NEW_PANE="$(tmux split-window -v -t "$bottom_pane" -c "$CWD" -P -F '#{pane_id}')"
fi

if [[ -z "$NEW_PANE" ]]; then
  echo "ERROR: split-window did not return a new pane id." >&2
  exit 2
fi
sleep 0.5

# Title the worker pane (human readability + the session-wide uniqueness guard above).
tmux select-pane -t "$NEW_PANE" -T "$WORKER_NAME" 2>/dev/null || true

# Rebalance to "supervisor main pane on the LEFT + workers stacked on the RIGHT".
# Explicit sizing (half the window width for the main/left pane) + main-vertical.
# Purely cosmetic — wrapped so a layout hiccup can NEVER fail the spawn.
WIN_WIDTH="$(tmux display-message -p -t "$WIN" '#{window_width}' 2>/dev/null || true)"
if [[ "$WIN_WIDTH" =~ ^[0-9]+$ ]] && (( WIN_WIDTH >= 20 )); then
  tmux set-window-option -t "$WIN" main-pane-width "$(( WIN_WIDTH / 2 ))" 2>/dev/null || true
fi
tmux select-layout -t "$WIN" main-vertical 2>/dev/null || true

# ── Launch: model per policy + attn force-loaded + Remote Control, NEVER WhatsApp
# Same launch contract as the manager spawners (unique ATTN_SESSION = worker name;
# force-load ONLY attn via dev-channels; Remote Control named; skip-permissions),
# only the model differs (Sonnet floor / Opus carve-out). NEVER load whatsapp.
tmux send-keys -t "$NEW_PANE" \
  "ATTN_SESSION='${WORKER_NAME}' claude --model '${WORKER_MODEL}' --dangerously-load-development-channels plugin:attn@s0nderlabs --remote-control '${WORKER_NAME}' --dangerously-skip-permissions" \
  Enter

# Auto-confirm the --dangerously-load-development-channels prompt (bare Enter on the
# pre-highlighted option). Poll for it, then confirm.
DEVCH_MAX=20
for ((dc = 0; dc < DEVCH_MAX; dc++)); do
  sleep 1
  PANE_DC=$(tmux capture-pane -t "$NEW_PANE" -p -S -25 2>/dev/null || true)
  if echo "$PANE_DC" | grep -qE -- 'using this for local development|Loading development channels'; then
    tmux send-keys -t "$NEW_PANE" Enter
    echo "OK: auto-confirmed dev-channels prompt (after ~$((dc + 1))s)."
    sleep 2
    break
  fi
  if echo "$PANE_DC" | grep -qE -- '-- INSERT --|bypass permissions on'; then
    break   # input already up — confirm not needed
  fi
done

# Wait for claude to boot + MCP plugins to register (poll the pane, 30s ceiling).
READY_MAX=30
MCP_GRACE=3
BOOT_READY=0
waited=0
for ((waited = 0; waited < READY_MAX; waited++)); do
  sleep 1
  PANE_BOOT=$(tmux capture-pane -t "$NEW_PANE" -p -S -15 2>/dev/null || true)
  if echo "$PANE_BOOT" | grep -qE -- '-- INSERT --|bypass permissions on|^[[:space:]]*[❯>][[:space:]]'; then
    BOOT_READY=1
    break
  fi
done

if [[ "$BOOT_READY" == "1" ]]; then
  sleep "$MCP_GRACE"
  echo "OK: worker prompt ready after ~$((waited + 1 + MCP_GRACE))s (polled)."
else
  echo "WARN: worker prompt not detected within ${READY_MAX}s — proceeding anyway." >&2
  echo "      (Boot may be slow; the attn-peers check below is the real gate.)" >&2
fi

echo "OK: worker '$WORKER_NAME' spawned as pane $NEW_PANE in window '$SUP_WINDOW'."
echo "    model=${WORKER_MODEL}  cwd=${CWD}  WhatsApp=NEVER  RemoteControl=ON  cap=NONE"
echo
echo "NEXT (the SUPERVISOR MUST do — equip-before-brief, then brief):"
echo "  1. Call the attn peers tool; confirm '$WORKER_NAME' is in local peers."
echo "     If NOT visible within 15s: kill the pane + retry"
echo "       tmux kill-pane -t $NEW_PANE"
echo "  2. EQUIP the worker in its brief.md BEFORE briefing (per Equip-Before-Delegating):"
echo "       [ ] Credentials — point to \$SECRETS_FILE by REFERENCE; NEVER paste literals."
echo "           (No project worker SSHes the VPS — request VPS actions from 'vps-manager'.)"
echo "       [ ] Tools — qutebrowser / grpcurl / a running dev server / MCP set up first."
echo "       [ ] Access level — read-only vs read-write, git push, restarts: state it."
echo "       [ ] Context — files, prior findings, the project dir, STATE.md path."
echo "       [ ] Test accounts — logged-in creds for verification, upfront."
echo "       [ ] attn — this worker's peer is YOU, the supervisor. Confirm the round-trip."
echo "  3. Brief (injects the EXECUTE-DIRECTLY worker preamble via brief-worker.sh):"
echo "       brief-worker.sh ${WORKER_NAME} <brief_file>          # full 3-tier"
echo "       brief-worker.sh --quick ${WORKER_NAME} <brief_file>  # L1 fast-path"
echo
echo "  REPORT TARGET: this worker reports to YOU, the supervisor (attn '$SUP_WINDOW'),"
echo "  NOT to main. The brief.md you write MUST say 'report to your manager $SUP_WINDOW"
echo "  via attn' (the generic brief-worker.sh preamble still says 'main' pending a"
echo "  preamble update — your brief body overrides it)."
