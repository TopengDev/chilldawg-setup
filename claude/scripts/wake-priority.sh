#!/usr/bin/env bash
# wake-priority.sh — report the current highest-priority pending wake-reason so the
# autonomous loop can decide, on each wake, HOW URGENTLY to wake next and WHAT to
# do first.
#
# WHY: main self-schedules its next wake (ScheduleWakeup, sentinel
# `<<autonomous-loop-dynamic>>`) with dynamic pacing. Until now the cadence was
# essentially "finish the current wave → continue / sleep a fallback interval".
# This gives the loop a cheap, local PRIORITY MODEL it can consult each tick:
#
#   P0 — act immediately   (a real deadman daemon-death alert; time-critical+irreversible).
#                           A Toper WhatsApp/SUPERUSER msg is ALSO P0 but is delivered
#                           LIVE to main via WHATSAPP=1 — it is not a pollable file, so
#                           this script does not (and need not) detect it. Documented in
#                           docs/AUTONOMOUS-LOOP.md.
#   P1 — handle next       (a fresh/unconsumed worker result.json to ingest; OR we are
#                           inside a known paid-work window, e.g. Ryan/BMS ~morning WIB).
#   P2 — idle tick         (nothing higher pending → pull ONE loop-safe item from the
#                           idle backlog, ~/claude/notes/idle-backlog.md).
#
# SAFETY / CONTRACT (matches the deadman + ops-dashboard house style):
#   * READ-ONLY. Touches no daemon, edits nothing except (optionally) its OWN
#     last-consumed marker, and ONLY when called with `--consume` (the default
#     report run writes NOTHING).
#   * FAIL-OPEN: any ambiguity / error / missing input → report P2/idle (exit 0).
#     A bug here must NEVER falsely escalate (which would burn the loop waking hot)
#     and must NEVER crash the caller.
#   * NEVER prints a secret value. It reads only state filenames, mtimes, and the
#     wall clock — no secrets are ever loaded or echoed.
#   * EXIT CODE ENCODES THE TIER so it is scriptable without parsing stdout:
#         exit 0 → P2 (idle)        exit 1 → P1 (handle-next)        exit 2 → P0 (act-now)
#     (Higher = more urgent; 0 = idle. Mnemonic: exit code == Pn number.)
#
# Usage:
#   wake-priority.sh                 report top pending reason + tier + suggested cadence
#   wake-priority.sh --quiet         one-line machine form: "P<n>\t<reason>\t<cadence-secs-lo>-<hi>"
#   wake-priority.sh --consume       AFTER acting on a P1 result.json, advance the
#                                    last-consumed marker so the same result stops
#                                    re-counting as fresh (idempotent; safe to re-run)
#   wake-priority.sh --json          emit a JSON object (tier/priority/reason/detail/cadence)
#   wake-priority.sh -h|--help
#
# Overridable (for testing — all default to the real paths):
#   WP_DEADMAN_DIR   (deadman alert-state dir)         default ~/.claude/state/deadman
#   WP_NOTES_DIR     (where worker result.json live)   default ~/claude/notes
#   WP_STATE_DIR     (our own marker dir)              default ~/.claude/state
#   WP_NOW_EPOCH     (override "now" for time tests)   default $(date +%s)
#   WP_TZ            (timezone for the paid-work window) default Asia/Jakarta (WIB)
#
set -uo pipefail   # deliberately NO -e: this script must never abort mid-evaluation.

PROG="wake-priority.sh"

# ── paths (all overridable for tests; all default to the real locations) ───────
DEADMAN_DIR="${WP_DEADMAN_DIR:-$HOME/.claude/state/deadman}"
NOTES_DIR="${WP_NOTES_DIR:-$HOME/claude/notes}"
STATE_DIR="${WP_STATE_DIR:-$HOME/.claude/state}"
CONSUMED_MARKER="$STATE_DIR/wake-priority.consumed"   # epoch of the newest result.json we've already acted on
TZ_WIB="${WP_TZ:-Asia/Jakarta}"

# "now" — overridable so the paid-work-window logic is testable without time travel.
now_epoch() { echo "${WP_NOW_EPOCH:-$(date +%s)}"; }

# ── paid-work window (Ryan/BMS thread resumes ~morning WIB) ────────────────────
# Conservative band: 08:00–11:00 WIB on weekdays. Being inside it is only P1
# ("be ready / lean toward responsiveness"), never P0 — it is a soft signal, not
# an alarm. Outside the band (or on weekends) it contributes nothing.
PAIDWORK_START_H=8     # inclusive
PAIDWORK_END_H=11      # exclusive

# ── helpers ────────────────────────────────────────────────────────────────────
# mtime <file> → epoch, or 0 if missing/unreadable (never errors).
mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }

# ──────────────────────────────────────────────────────────────────────────────
# P0 DETECTOR — a REAL deadman alert is outstanding.
# deadman.sh writes `<target>.alerted` ONLY on an armed alive→dead transition
# (i.e. a daemon that was genuinely running has died) and removes it on recovery.
# So the mere PRESENCE of any *.alerted file == an active, un-recovered outage.
# This is exactly the P0 "act immediately" condition.
# Fail-open: if the dir is unreadable we simply find nothing → not P0.
# ──────────────────────────────────────────────────────────────────────────────
detect_p0_deadman() {
  local f
  # -maxdepth 1 keeps it to the alert flags themselves; never recurses.
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    # target name = basename without the .alerted suffix (e.g. "wa-sender")
    local base; base="$(basename "$f")"; base="${base%.alerted}"
    P0_DETAIL="deadman alert OUTSTANDING for '$base' (armed daemon went alive->dead, not yet recovered)"
    return 0
  done < <(find "$DEADMAN_DIR" -maxdepth 1 -type f -name '*.alerted' 2>/dev/null)
  return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# P1 DETECTOR (a) — a FRESH, unconsumed worker result.json exists.
# "Fresh" = its mtime is newer than the last-consumed marker (or the marker is
# absent, meaning we've consumed nothing yet). The loop advances the marker by
# calling `--consume` once it has actually ingested the newest result.
# We report the NEWEST such file (the most recent worker outcome) + how many are
# pending, so main knows there's a queue to drain.
# Fail-open: unreadable notes dir → nothing fresh.
# ──────────────────────────────────────────────────────────────────────────────
NEWEST_RESULT=""        # path of the newest fresh result.json
NEWEST_RESULT_MTIME=0
FRESH_COUNT=0
scan_results() {
  local consumed; consumed="$(cat "$CONSUMED_MARKER" 2>/dev/null || echo 0)"
  [[ "$consumed" =~ ^[0-9]+$ ]] || consumed=0
  local f m
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    m="$(mtime "$f")"
    if (( m > consumed )); then
      FRESH_COUNT=$(( FRESH_COUNT + 1 ))
      if (( m > NEWEST_RESULT_MTIME )); then
        NEWEST_RESULT_MTIME="$m"
        NEWEST_RESULT="$f"
      fi
    fi
  done < <(find "$NOTES_DIR" -maxdepth 2 -type f -name 'result.json' 2>/dev/null)
}

detect_p1_result() {
  scan_results
  if (( FRESH_COUNT > 0 )); then
    # task slug = the parent dir name (the notes/<slug>/ convention)
    local slug; slug="$(basename "$(dirname "$NEWEST_RESULT")")"
    if (( FRESH_COUNT > 1 )); then
      P1_DETAIL="$FRESH_COUNT fresh worker result.json to ingest (newest: $slug) — handle/ingest before idle work"
    else
      P1_DETAIL="fresh worker result.json to ingest: $slug — handle/ingest before idle work"
    fi
    return 0
  fi
  return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# P1 DETECTOR (b) — inside a known paid-work window (Ryan/BMS ~morning WIB).
# Soft "be responsive" signal. Weekdays only, 08:00–11:00 WIB.
# All time math is done in the WIB zone explicitly so it's correct regardless of
# the machine's local TZ, and is fully overridable via WP_NOW_EPOCH/WP_TZ.
# ──────────────────────────────────────────────────────────────────────────────
detect_p1_paidwork() {
  local n h dow
  n="$(now_epoch)"
  # Hour-of-day and day-of-week, evaluated in WIB.
  h="$(TZ="$TZ_WIB" date -d "@$n" +%H 2>/dev/null || echo "")"
  dow="$(TZ="$TZ_WIB" date -d "@$n" +%u 2>/dev/null || echo "")"   # 1=Mon .. 7=Sun
  # Strip a possible leading zero so arithmetic is base-10 safe (08 etc).
  h="${h#0}"; [[ -z "$h" ]] && return 1
  [[ "$dow" =~ ^[1-7]$ ]] || return 1
  (( dow >= 6 )) && return 1                          # weekend → not a paid-work window
  if (( h >= PAIDWORK_START_H && h < PAIDWORK_END_H )); then
    P1_DETAIL="inside paid-work window (${PAIDWORK_START_H}:00-${PAIDWORK_END_H}:00 WIB, weekday) — Ryan/BMS thread may resume; stay responsive"
    return 0
  fi
  return 1
}

# ── --consume: advance the last-consumed marker to the newest result.json mtime ─
# Idempotent: re-running with no newer result is a no-op. This is the ONLY path
# that writes anything, and it writes ONLY our own marker (never a secret, never
# a daemon, never anyone else's state).
do_consume() {
  scan_results
  mkdir -p "$STATE_DIR" 2>/dev/null
  if (( NEWEST_RESULT_MTIME > 0 )); then
    local prev; prev="$(cat "$CONSUMED_MARKER" 2>/dev/null || echo 0)"
    [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
    if (( NEWEST_RESULT_MTIME > prev )); then
      echo "$NEWEST_RESULT_MTIME" > "$CONSUMED_MARKER" 2>/dev/null \
        && echo "$PROG: consumed up to mtime $NEWEST_RESULT_MTIME ($(basename "$(dirname "$NEWEST_RESULT")"))" \
        || echo "$PROG: WARN could not write marker $CONSUMED_MARKER (continuing)"
    else
      echo "$PROG: nothing newer to consume (marker already at $prev)"
    fi
  else
    # No result.json at all → set marker to now so future ones are the baseline.
    echo "$(now_epoch)" > "$CONSUMED_MARKER" 2>/dev/null || true
    echo "$PROG: no result.json found — marker baselined to now"
  fi
  exit 0
}

# ── arg parse ──────────────────────────────────────────────────────────────────
MODE="report"
case "${1:-}" in
  --consume) do_consume ;;                # exits inside
  --quiet)   MODE="quiet" ;;
  --json)    MODE="json" ;;
  -h|--help)
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  "" ) : ;;
  * ) echo "$PROG: unknown arg '${1}'" >&2; echo "usage: $PROG [--quiet|--json|--consume|-h]" >&2; exit 0 ;;  # fail-open: still exit 0
esac

# ── evaluate priority (highest wins; short-circuit) ────────────────────────────
P0_DETAIL=""; P1_DETAIL=""
TIER=2; PRIORITY="P2"
REASON="idle — nothing urgent pending; pull ONE loop-safe item from idle-backlog.md"
DETAIL="no deadman alert, no unconsumed result.json, outside paid-work window"
CADENCE_LO=1200; CADENCE_HI=1800            # P2: relaxed 20–30 min
CADENCE_HINT="1200-1800s (20-30 min) — relaxed idle cadence"

if detect_p0_deadman; then
  TIER=2; PRIORITY="P0"
  REASON="DAEMON-DEATH ALERT — act immediately"
  DETAIL="$P0_DETAIL"
  CADENCE_LO=30; CADENCE_HI=60
  CADENCE_HINT="<=60s — wake hot, investigate the outage NOW (ops-dashboard.sh, systemctl --user status)"
  TIER_EXIT=2
elif detect_p1_result; then
  TIER=1; PRIORITY="P1"
  REASON="fresh worker result to ingest — handle next"
  DETAIL="$P1_DETAIL"
  CADENCE_LO=60; CADENCE_HI=300
  CADENCE_HINT="60-300s (1-5 min) — ingest the result, continue the pipeline"
  TIER_EXIT=1
elif detect_p1_paidwork; then
  TIER=1; PRIORITY="P1"
  REASON="paid-work window — stay responsive"
  DETAIL="$P1_DETAIL"
  CADENCE_LO=300; CADENCE_HI=600
  CADENCE_HINT="300-600s (5-10 min) — tighter cadence while the paid-work thread may resume"
  TIER_EXIT=1
else
  TIER_EXIT=0   # P2 idle
fi

# ── emit ───────────────────────────────────────────────────────────────────────
case "$MODE" in
  quiet)
    printf '%s\t%s\t%s-%s\n' "$PRIORITY" "$REASON" "$CADENCE_LO" "$CADENCE_HI"
    ;;
  json)
    # hand-rolled JSON (no jq dependency for the common path); values are our own
    # static strings + filenames — never a secret. Escape backslashes + quotes.
    esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    printf '{\n'
    printf '  "priority": "%s",\n'   "$(esc "$PRIORITY")"
    printf '  "tier_exit": %s,\n'    "$TIER_EXIT"
    printf '  "reason": "%s",\n'     "$(esc "$REASON")"
    printf '  "detail": "%s",\n'     "$(esc "$DETAIL")"
    printf '  "cadence_lo_secs": %s,\n' "$CADENCE_LO"
    printf '  "cadence_hi_secs": %s,\n' "$CADENCE_HI"
    printf '  "cadence_hint": "%s"\n' "$(esc "$CADENCE_HINT")"
    printf '}\n'
    ;;
  *)
    echo "──────────────────────────────────────────────────────────────"
    echo " wake-priority: ${PRIORITY}"
    echo "──────────────────────────────────────────────────────────────"
    echo " reason : $REASON"
    echo " detail : $DETAIL"
    echo " cadence: $CADENCE_HINT"
    echo "──────────────────────────────────────────────────────────────"
    if [[ "$PRIORITY" == "P2" ]]; then
      echo " next   : read ~/claude/notes/idle-backlog.md → pick the highest-value"
      echo "          LOOP-SAFE item that fits remaining context → execute under"
      echo "          normal triage+3-tier+verify → log + check it off."
    fi
    ;;
esac

exit "$TIER_EXIT"
