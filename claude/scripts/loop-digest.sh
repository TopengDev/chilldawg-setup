#!/usr/bin/env bash
# loop-digest.sh — daily "what happened autonomously" digest.
#
# While Toper sleeps, the autonomous loop (1h-default decisions, worker tasks,
# timer-driven jobs) keeps moving. This script summarizes that overnight activity
# into ONE short WhatsApp message so the morning has a single glance-able recap of
# what the system decided + did on its own.
#
# SOURCES (all read-only):
#   1. ~/claude/state/decisions.log     — 1h-default decisions (the headline content)
#   2. ~/.claude/tasks/*.md             — items completed in the window (`- [x]`)
#   3. ~/claude/notes/<task>/           — worker outcomes (report.md / STATE.md status)
#       recently touched in the window
#
# DELIVERY: appends a single JSON event to the wa-sender queue (the SAME
# session-independent path signal-trader / macro-news / reminders use). The
# wa-sender daemon relays it to WhatsApp. We deliberately do NOT use the
# whatsapp MCP (that needs a live Claude session); the queue is robust and
# matches how every other automated notification is sent. Recipient is Toper.
#
# This is intentionally DISTINCT from /daily-brief (tasks+calendar agenda for the
# day AHEAD). loop-digest reports the night BEHIND — autonomous actions taken.
# Scheduled ~06:30 WIB, just after the 06:00 morning brief, so the two don't
# collide and each stays single-purpose.
#
# If the window is quiet (no decisions / completions / outcomes), the digest says
# so in one line rather than sending an empty or noisy message.
#
# Usage:
#   loop-digest.sh                 # build + enqueue (real send)
#   loop-digest.sh --dry-run       # print the digest to stdout, enqueue NOTHING
#   loop-digest.sh --hours N        # lookback window (default 24)
#   loop-digest.sh --stdout         # print AND enqueue
#
# Exit: 0 on success (including a quiet digest), non-zero only on a real failure
#       to enqueue.
set -uo pipefail

# ── config / args ─────────────────────────────────────────────────────────────
LOOKBACK_HOURS=24
DRY_RUN=0
ALSO_STDOUT=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --stdout)  ALSO_STDOUT=1 ;;
    --hours)   shift 2>/dev/null; ;;   # handled below via positional scan
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
  esac
done
# parse --hours N (kept simple + robust to ordering)
prev=""
for a in "$@"; do
  if [ "$prev" = "--hours" ]; then
    case "$a" in (*[!0-9]*) ;; (*) LOOKBACK_HOURS="$a" ;; esac
  fi
  prev="$a"
done

DECISIONS_LOG="$HOME/claude/state/decisions.log"
TASKS_DIR="$HOME/.claude/tasks"
NOTES_DIR="$HOME/claude/notes"
QUEUE="$HOME/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl"
TOPER_JID="62817712289@s.whatsapp.net"   # = Toper (same person as 107838240207070@lid)
STATE_DIR="$HOME/.claude/state"
LAST_RUN_FILE="$STATE_DIR/loop-digest.lastrun"
LOG_FILE="$STATE_DIR/loop-digest.log"

mkdir -p "$STATE_DIR"
log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"; }

NOW_EPOCH="$(date +%s)"
WINDOW_EPOCH=$(( NOW_EPOCH - LOOKBACK_HOURS * 3600 ))
NOW_WIB="$(TZ=Asia/Jakarta date +'%a %d %b %H:%M' 2>/dev/null || date +'%a %d %b %H:%M')"

# ── helper: parse a leading timestamp from a decisions.log line into epoch ─────
# Handles both formats seen in the log:
#   "2026-06-10T17:55:00+07:00 | ..."         (ISO 8601)
#   "2026-06-10 17:55 WIB | ..."              (date space HH:MM WIB)
# Returns epoch on stdout, or empty if no parseable leading timestamp.
line_epoch() {
  local line="$1" ts e
  # ISO: up to the first space, if it looks like a date+T time
  ts="${line%% *}"
  if printf '%s' "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}'; then
    e="$(date -d "$ts" +%s 2>/dev/null || true)"
    printf '%s' "$e"; return
  fi
  # "YYYY-MM-DD HH:MM WIB" : take first two space-separated fields
  if printf '%s' "$line" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}'; then
    local d t
    d="$(printf '%s' "$line" | awk '{print $1}')"
    t="$(printf '%s' "$line" | awk '{print $2}')"
    # interpret as WIB
    e="$(TZ=Asia/Jakarta date -d "$d $t" +%s 2>/dev/null || true)"
    printf '%s' "$e"; return
  fi
  printf ''
}

# ── 1. decisions in the window ────────────────────────────────────────────────
DECISIONS=()
if [ -r "$DECISIONS_LOG" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # only structured, pipe-delimited lines with a leading timestamp
    printf '%s' "$line" | grep -qE '^\S.*\|' || continue
    e="$(line_epoch "$line")"
    [ -z "$e" ] && continue
    if [ "$e" -ge "$WINDOW_EPOCH" ] 2>/dev/null; then
      # Build a compact one-liner: <HH:MM> <slug-or-context> — <decision>
      hhmm="$(TZ=Asia/Jakarta date -d "@$e" +'%H:%M' 2>/dev/null || echo '--:--')"
      # field 2 = slug/context, field 3 = the decision/default
      f2="$(printf '%s' "$line" | awk -F'|' '{print $2}' | sed 's/^ *//; s/ *$//')"
      f3="$(printf '%s' "$line" | awk -F'|' '{print $3}' | sed 's/^ *//; s/ *$//')"
      # truncate for phone readability
      f2="$(printf '%s' "$f2" | cut -c1-40)"
      f3="$(printf '%s' "$f3" | cut -c1-70)"
      DECISIONS+=("• ${hhmm} ${f2} — ${f3}")
    fi
  done < "$DECISIONS_LOG"
fi

# ── 2. tasks completed in the window ──────────────────────────────────────────
# A task file's mtime within the window + a `- [x]` line => recently completed.
# We can't know exactly WHEN a given [x] flipped, so we use file mtime as the
# proxy and list [x] items from files touched in the window. Keep it conservative.
COMPLETED=()
if [ -d "$TASKS_DIR" ]; then
  while IFS= read -r f; do
    [ -e "$f" ] || continue
    fm="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    [ "$fm" -ge "$WINDOW_EPOCH" ] 2>/dev/null || continue
    proj="$(basename "$f" .md)"
    # pull [x] lines, strip checkbox + trailing backtick-date, truncate
    while IFS= read -r tl; do
      desc="$(printf '%s' "$tl" | sed -E 's/^\s*- \[x\] *//; s/ *`[0-9-]+` *$//' | cut -c1-70)"
      [ -n "$desc" ] && COMPLETED+=("• [${proj}] ${desc}")
    done < <(grep -E '^\s*- \[x\]' "$f" 2>/dev/null | tail -n 4)
  done < <(find "$TASKS_DIR" -maxdepth 1 -name '*.md' ! -name 'INDEX.md' 2>/dev/null)
fi

# ── 3. worker outcomes touched in the window ──────────────────────────────────
# A notes/<task>/ dir whose report.md or STATE.md was written in the window =
# a worker that finished/updated overnight. Surface its status one-liner.
OUTCOMES=()
if [ -d "$NOTES_DIR" ]; then
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    status=""
    recent=0
    for sf in "$d/report.md" "$d/STATE.md"; do
      [ -e "$sf" ] || continue
      fm="$(stat -c %Y "$sf" 2>/dev/null || echo 0)"
      if [ "$fm" -ge "$WINDOW_EPOCH" ] 2>/dev/null; then recent=1; fi
    done
    [ "$recent" -eq 1 ] || continue
    # prefer the STATE.md **Status:** line if present
    if [ -e "$d/STATE.md" ]; then
      status="$(grep -iE '^\**Status:\**' "$d/STATE.md" 2>/dev/null | head -1 | sed -E 's/^\**Status:\** *//' | cut -c1-80)"
    fi
    [ -z "$status" ] && status="updated"
    OUTCOMES+=("• ${name}: ${status}")
  done < <(find "$NOTES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name 'templates' ! -name 'initiatives' 2>/dev/null)
fi

# ── assemble the digest ───────────────────────────────────────────────────────
n_dec="${#DECISIONS[@]}"; n_done="${#COMPLETED[@]}"; n_out="${#OUTCOMES[@]}"
total=$(( n_dec + n_done + n_out ))

build_message() {
  printf '🌙 Overnight digest — %s\n' "$NOW_WIB"
  printf 'autonomous activity, last %sh\n' "$LOOKBACK_HOURS"
  if [ "$total" -eq 0 ]; then
    printf '\nQuiet night — no logged decisions, task completions, or worker outcomes in the window.\n'
    return
  fi
  if [ "$n_dec" -gt 0 ]; then
    printf '\n⚖️ Decisions (%d):\n' "$n_dec"
    # cap to the 6 most recent to keep the message phone-sized
    printf '%s\n' "${DECISIONS[@]}" | tail -n 6
    [ "$n_dec" -gt 6 ] && printf '…(+%d more)\n' "$(( n_dec - 6 ))"
  fi
  if [ "$n_out" -gt 0 ]; then
    printf '\n🤖 Worker outcomes (%d):\n' "$n_out"
    printf '%s\n' "${OUTCOMES[@]}" | tail -n 6
    [ "$n_out" -gt 6 ] && printf '…(+%d more)\n' "$(( n_out - 6 ))"
  fi
  if [ "$n_done" -gt 0 ]; then
    printf '\n✅ Tasks completed (%d):\n' "$n_done"
    printf '%s\n' "${COMPLETED[@]}" | tail -n 6
    [ "$n_done" -gt 6 ] && printf '…(+%d more)\n' "$(( n_done - 6 ))"
  fi
}

MESSAGE="$(build_message)"

# ── deliver ───────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  printf '=== DRY RUN (not enqueued) ===\n%s\n' "$MESSAGE"
  log "DRY-RUN built digest (dec=$n_dec done=$n_done out=$n_out)"
  exit 0
fi

[ "$ALSO_STDOUT" -eq 1 ] && printf '%s\n' "$MESSAGE"

# idempotency: don't enqueue twice in the same WIB minute (timer + manual race)
NOW_MIN="$(TZ=Asia/Jakarta date +'%Y-%m-%d %H:%M')"
if [ -r "$LAST_RUN_FILE" ] && [ "$(cat "$LAST_RUN_FILE" 2>/dev/null)" = "$NOW_MIN" ]; then
  log "SKIP already enqueued this minute ($NOW_MIN)"
  exit 0
fi

if [ ! -e "$QUEUE" ]; then
  log "ERROR wa-sender queue missing ($QUEUE) — cannot enqueue digest"
  exit 1
fi

# Build the JSON event exactly like the other producers (to/message/kind/ts).
# Use python for safe JSON string escaping of the multi-line message.
JSON="$(MESSAGE="$MESSAGE" JID="$TOPER_JID" python3 -c '
import json, os, time
print(json.dumps({
    "to": os.environ["JID"],
    "message": os.environ["MESSAGE"],
    "kind": "loop_digest",
    "ts": time.time(),
}, ensure_ascii=False))
')"
if [ -z "$JSON" ]; then
  log "ERROR failed to build digest JSON"
  exit 1
fi

printf '%s\n' "$JSON" >>"$QUEUE"
printf '%s' "$NOW_MIN" >"$LAST_RUN_FILE"
log "ENQUEUED digest to wa-sender queue (dec=$n_dec done=$n_done out=$n_out, ${#MESSAGE} chars)"
exit 0
