#!/usr/bin/env bash
# fleetview.sh — read-only live dashboard of all active workers.
#
# One-screen view of every pipeline-spawned worker: tmux window, its STATE.md
# status + mtime (stale>10min flagged), last completed checkpoint / resume cursor,
# context% (read from the pane statusline if present), RED/stalled markers, and the
# parent task/initiative. Reuses the concurrency-governor's live-worker set and the
# 5-min-poll discipline (STATE.md mtime).
#
# STRICTLY READ-ONLY. It inspects tmux + reads files. It NEVER sends keys, never
# kills a window, never edits a STATE.md. Safe to run anytime, repeatedly.
#
# Usage:
#   fleetview.sh                 print the dashboard once
#   fleetview.sh --watch [SECS]  refresh every SECS seconds (default 5) until Ctrl-C
#   fleetview.sh --once          explicit single render (default behaviour)
#
# Env:
#   TMUX_SESSION        session to inspect (default 0)
#   NOTES_DIR           task-notes root (default ~/claude/notes)
#   FLEET_STALE_MIN     minutes before a STATE.md is "stale" (default 10)
#
# Worker → STATE.md resolution mirrors check-triage.sh: for window W, the task dir
# is ~/claude/notes/W-<YYYY-MM-DD>/ (newest match), and STATE.md lives there.

set -uo pipefail   # no -e: a read failure on one worker must not abort the whole view

NOTES_DIR="${NOTES_DIR:-$HOME/claude/notes}"
TMUX_SESSION="${TMUX_SESSION:-0}"
STALE_MIN="${FLEET_STALE_MIN:-10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colours (TTY only)
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[90m'; C_GRN=$'\033[38;5;71m'; C_YEL=$'\033[38;5;222m'
  C_RED=$'\033[38;5;167m'; C_BLU=$'\033[38;5;37m'; C_BOLD=$'\033[1m'; C_MAG=$'\033[38;5;141m'
else
  C_RESET=""; C_DIM=""; C_GRN=""; C_YEL=""; C_RED=""; C_BLU=""; C_BOLD=""; C_MAG=""
fi

# --- discover live workers ----------------------------------------------------
# Prefer the concurrency-governor registry (precise: pipeline-spawned only). Fall
# back to "all windows minus main/known-non-workers" if the helper is unavailable.
discover_workers() {
  local sem="$SCRIPT_DIR/worker-semaphore.sh"
  local out=""
  if [[ -r "$sem" ]]; then
    # shellcheck source=/dev/null
    source "$sem"
    out="$(cs_live_workers 2>/dev/null)"
    # cs_live_workers returns the registry∩live set; if registry empty it prints nothing.
    if [[ -n "$out" ]]; then
      printf '%s\n' "$out"
      return 0
    fi
  fi
  # Fallback: list windows, drop obvious non-workers AND any live supervisor window
  # (a supervisor must never be miscounted as a worker). Heuristic used ONLY when the
  # registry is empty/unavailable (e.g. workers spawned before this feature).
  command -v tmux >/dev/null 2>&1 || return 0
  tmux has-session -t "$TMUX_SESSION" 2>/dev/null || return 0
  local sups; sups="$(cs_live_supervisors 2>/dev/null)"
  tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null \
    | grep -vxE 'main|claude|bash|zsh|shell|0' \
    | { if [[ -n "$sups" ]]; then grep -vxF "$sups"; else cat; fi; } || true
}

# --- resolve a worker's task dir + STATE.md ----------------------------------
resolve_state() {
  local win="$1" newest="" m mt=0 d f
  shopt -s nullglob
  for d in "$NOTES_DIR/${win}-"*/; do
    f="${d}STATE.md"
    [[ -f "$f" ]] || continue
    m=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    if (( m >= mt )); then mt=$m; newest="$f"; fi
  done
  shopt -u nullglob
  printf '%s' "$newest"
}

# --- helpers -----------------------------------------------------------------
field_from_state() {  # grep a "**Key:** value" line, print value
  local file="$1" key="$2"
  grep -m1 -iE "^\*\*${key}:\*\*" "$file" 2>/dev/null | sed -E "s/^\*\*${key}:\*\*[[:space:]]*//I" || true
}

# Count matching lines as a CLEAN integer. `grep -c` prints 0 AND exits 1 on no
# match, so a naive `grep -c ... || echo 0` double-prints "0\n0" and breaks (( )).
# This collapses to exactly one integer.
count_matches() {
  local pat="$1" file="$2" n
  n=$(grep -cE "$pat" "$file" 2>/dev/null)
  [[ "$n" =~ ^[0-9]+$ ]] || n=0
  printf '%s' "$n"
}

human_age() {  # seconds -> compact "Nm"/"Nh Mm"
  local s="$1"
  if (( s < 60 )); then echo "${s}s"
  elif (( s < 3600 )); then echo "$(( s / 60 ))m"
  else echo "$(( s / 3600 ))h$(( (s % 3600) / 60 ))m"; fi
}

# pull "N% (Xk)" context-remaining from the worker pane statusline, if visible
pane_context() {
  local win="$1" cap
  cap="$(tmux capture-pane -t "${TMUX_SESSION}:${win}" -p -S -40 2>/dev/null)" || return 0
  # last occurrence of <digits>% (<digits>k)
  printf '%s\n' "$cap" | grep -oE '[0-9]+% \([0-9]+k\)' | tail -1 || true
}

status_colour() {
  case "$(echo "$1" | tr '[:lower:]' '[:upper:]')" in
    *COMPLETE*) printf '%s' "$C_GRN" ;;
    *IN_PROGRESS*) printf '%s' "$C_BLU" ;;
    *BLOCKED*) printf '%s' "$C_RED" ;;
    *STARTING*) printf '%s' "$C_YEL" ;;
    *) printf '%s' "$C_DIM" ;;
  esac
}

# --- render one frame --------------------------------------------------------
render() {
  local now; now=$(date +%s)
  echo "${C_BOLD}${C_BLU}╭─ FleetView ─ workers @ session ${TMUX_SESSION} ─ $(date '+%Y-%m-%d %H:%M:%S') ─╮${C_RESET}"

  # capacity line (reuse semaphore)
  local sem="$SCRIPT_DIR/worker-semaphore.sh"
  if [[ -r "$sem" ]]; then
    # shellcheck source=/dev/null
    source "$sem"
    local cnt max; cnt="$(cs_live_count 2>/dev/null)"; max="$(_cs_max_workers 2>/dev/null)"
    if [[ "$cnt" == "-1" ]]; then
      echo "${C_DIM}  capacity: live count undetermined (fail-open)${C_RESET}"
    else
      local capcol="$C_GRN"; (( cnt >= max )) && capcol="$C_RED"
      echo "  capacity: ${capcol}${cnt}/${max}${C_RESET} workers live  (cap=CHILLDAWG_MAX_WORKERS)"
    fi
  fi

  # --- supervisors (Opus orchestration tier) ---------------------------------
  # Read-only: list live supervisors with their orchestration-ledger status. Shown
  # ABOVE workers because they're the higher tier. Absent when none are running.
  if [[ -r "$sem" ]]; then
    local scnt smax; scnt="$(cs_live_supervisor_count 2>/dev/null)"; smax="$(_cs_supervisor_max 2>/dev/null)"
    if [[ "$scnt" =~ ^[0-9]+$ ]] && (( scnt > 0 )); then
      local scapcol="$C_GRN"; [[ "$smax" =~ ^[0-9]+$ ]] && (( scnt >= smax )) && scapcol="$C_RED"
      echo
      echo "  ${C_BOLD}${C_MAG}▰ SUPERVISORS${C_RESET}  ${scapcol}${scnt}/${smax}${C_RESET} ${C_DIM}(cap=CHILLDAWG_MAX_SUPERVISORS)${C_RESET}"
      local sup sstate sstatus smt sage sagecol sflag sdir sdone stodo
      while IFS= read -r sup; do
        [[ -z "$sup" ]] && continue
        echo "    ${C_BOLD}${C_MAG}◆ ${sup}${C_RESET}"
        sstate="$(resolve_state "$sup")"
        if [[ -z "$sstate" ]]; then
          echo "        ${C_YEL}⚠ no STATE.md (ledger) found${C_RESET}"
          continue
        fi
        sstatus="$(field_from_state "$sstate" "Status")"; sstatus="${sstatus:-?}"
        smt=$(stat -c %Y "$sstate" 2>/dev/null || echo "$now"); sage=$(( now - smt ))
        sagecol="$C_DIM"; sflag=""
        if (( sage > STALE_MIN * 60 )); then
          sagecol="$C_RED"
          case "$(echo "$sstatus" | tr '[:lower:]' '[:upper:]')" in
            *COMPLETE*|*BLOCKED*) sflag="" ;;
            *) sflag="  ${C_RED}${C_BOLD}⛔ STALLED${C_RESET}" ;;
          esac
        fi
        echo "        status:  $(status_colour "$sstatus")${sstatus}${C_RESET}${sflag}"
        echo "        updated: ${sagecol}$(human_age "$sage") ago${C_RESET}"
        sdir="$(field_from_state "$sstate" "Direction")"
        [[ -n "$sdir" ]] && echo "        direction: ${sdir}"
        sdone=$(count_matches '^\s*-\s*\[x\]' "$sstate"); stodo=$(count_matches '^\s*-\s*\[ \]' "$sstate")
        (( sdone + stodo > 0 )) && echo "        orchestration: ${C_GRN}${sdone} done${C_RESET} / ${stodo} remaining"
      done <<< "$(cs_live_supervisors 2>/dev/null)"
    fi
  fi

  local workers; workers="$(discover_workers)"
  if [[ -z "$workers" ]]; then
    echo
    echo "  ${C_DIM}no active workers.${C_RESET}"
    echo "${C_BOLD}${C_BLU}╰$(printf '─%.0s' {1..58})╯${C_RESET}"
    return 0
  fi

  local win state status started worker parent ctx mt age agecol cp cursor flag
  while IFS= read -r win; do
    [[ -z "$win" ]] && continue
    echo
    echo "  ${C_BOLD}▸ ${win}${C_RESET}"

    state="$(resolve_state "$win")"
    if [[ -z "$state" ]]; then
      echo "      ${C_YEL}⚠ no STATE.md found${C_RESET} (looked: ${NOTES_DIR}/${win}-*/STATE.md)"
      ctx="$(pane_context "$win")"; [[ -n "$ctx" ]] && echo "      context: ${ctx} ${C_DIM}(remaining)${C_RESET}"
      continue
    fi

    status="$(field_from_state "$state" "Status")"; status="${status:-?}"
    worker="$(field_from_state "$state" "Worker")"
    parent="$(field_from_state "$state" "Parent initiative")"
    # mtime / staleness
    mt=$(stat -c %Y "$state" 2>/dev/null || echo "$now")
    age=$(( now - mt ))
    agecol="$C_DIM"; flag=""
    if (( age > STALE_MIN * 60 )); then
      agecol="$C_RED"
      # only flag stale as "stalled" if still active (not COMPLETE/BLOCKED terminal)
      case "$(echo "$status" | tr '[:lower:]' '[:upper:]')" in
        *COMPLETE*|*BLOCKED*) flag="" ;;
        *) flag="  ${C_RED}${C_BOLD}⛔ STALLED (no update ${STALE_MIN}m+)${C_RESET}" ;;
      esac
    fi

    local scol; scol="$(status_colour "$status")"
    echo "      status:  ${scol}${status}${C_RESET}${flag}"
    echo "      updated: ${agecol}$(human_age "$age") ago${C_RESET}  ${C_DIM}($(date -d "@$mt" '+%H:%M:%S' 2>/dev/null))${C_RESET}"

    # worker model (from triage.json beside STATE.md) — Opus is the expensive
    # carve-out, so flag it loudly; Sonnet (the floor) renders dim.
    local wmodel
    wmodel="$(jq -r '.model // "sonnet"' "$(dirname "$state")/triage.json" 2>/dev/null || echo sonnet)"
    [[ -z "$wmodel" || "$wmodel" == "null" ]] && wmodel="sonnet"
    case "$(echo "$wmodel" | tr '[:upper:]' '[:lower:]')" in
      opus*) echo "      model:   ${C_MAG}${C_BOLD}${wmodel}${C_RESET} ${C_DIM}(opus carve-out)${C_RESET}" ;;
      *)     echo "      model:   ${C_DIM}${wmodel}${C_RESET}" ;;
    esac

    # checkpoint progress + resume cursor
    cursor="$(field_from_state "$state" "Resume cursor")"
    local done todo
    done=$(count_matches '^\s*-\s*\[x\]' "$state")
    todo=$(count_matches '^\s*-\s*\[ \]' "$state")
    if (( done + todo > 0 )); then
      echo "      progress: ${C_GRN}${done} done${C_RESET} / ${todo} remaining"
    fi
    [[ -n "$cursor" ]] && echo "      resume:  ${cursor}"

    # context from pane
    ctx="$(pane_context "$win")"
    if [[ -n "$ctx" ]]; then
      # parse the % to colour (low remaining = warn; per reference: this is REMAINING)
      local pct; pct="$(echo "$ctx" | grep -oE '^[0-9]+')"
      local ccol="$C_GRN"
      if [[ -n "$pct" ]]; then
        (( pct <= 25 )) && ccol="$C_RED"
        (( pct > 25 && pct <= 50 )) && ccol="$C_YEL"
      fi
      echo "      context: ${ccol}${ctx}${C_RESET} ${C_DIM}remaining${C_RESET}"
    fi

    [[ -n "$parent" ]] && echo "      ${C_DIM}initiative: ${parent}${C_RESET}"
    echo "      ${C_DIM}state: ${state}${C_RESET}"
  done <<< "$workers"

  echo "${C_BOLD}${C_BLU}╰$(printf '─%.0s' {1..58})╯${C_RESET}"
}

# --- main --------------------------------------------------------------------
MODE="once"; INTERVAL=5
case "${1:-}" in
  --watch) MODE="watch"; [[ "${2:-}" =~ ^[0-9]+$ ]] && INTERVAL="$2" ;;
  --once|"") MODE="once" ;;
  -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "usage: fleetview.sh [--watch [SECS]|--once]" >&2; exit 2 ;;
esac

if [[ "$MODE" == "watch" ]]; then
  # clear-screen refresh loop; Ctrl-C exits cleanly
  trap 'echo; echo "fleetview: stopped."; exit 0' INT
  while true; do
    clear 2>/dev/null || true
    render
    echo "${C_DIM}  (--watch every ${INTERVAL}s · Ctrl-C to exit · read-only)${C_RESET}"
    sleep "$INTERVAL"
  done
else
  render
fi
