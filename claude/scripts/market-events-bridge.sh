#!/usr/bin/env bash
# market-events-bridge.sh — VPS→local WA notif bridge for market-events.
#
# CLONE of signal-trader-bridge.sh (same verified mechanics, separate state):
# pulls newly-appended lines from market-events' OWN VPS queue file and appends
# them VERBATIM to the LOCAL wa-sender queue (the designed multi-producer
# interface; reminder-check and loop-digest append there too).
#
# Hard invariants (wa-sender is LOAD-BEARING infra):
#   - reads ONLY market-events.jsonl on the VPS (NEVER signal-trader's events.jsonl)
#   - APPEND-ONLY to the local queue. Never truncate/rewrite it.
#   - READ-ONLY on the VPS (single awk pass).
#   - never touches the wa-sender or signal-trader processes.
#   - separate offset/lock/log from signal-trader-bridge (no shared state).
set -uo pipefail

STATE_DIR="$HOME/.claude/state"
OFFSET_FILE="$STATE_DIR/market-events-bridge.offset"
LOG_FILE="$STATE_DIR/market-events-bridge.log"
LOCK_FILE="$STATE_DIR/market-events-bridge.lock"

LOCAL_QUEUE="$HOME/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl"
# Path relative to the remote $HOME (expanded on the VPS side):
VPS_QUEUE_REL="signal-trader/wa-sender/queue/market-events.jsonl"

mkdir -p "$STATE_DIR"

log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "WARN another instance is running — skipping this tick"
  exit 0
fi

if [[ -r "$HOME/.claude/secrets.env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.claude/secrets.env"
fi
if [[ -z "${VPS_HOST:-}" || -z "${VPS_USER:-}" || -z "${VPS_PASSWORD:-}" ]]; then
  log "ERROR missing VPS_HOST/VPS_USER/VPS_PASSWORD — cannot run"
  exit 1
fi

if [[ ! -r "$OFFSET_FILE" ]]; then
  log "ERROR offset file missing ($OFFSET_FILE) — install must seed the baseline first. Refusing to run."
  exit 1
fi
offset=$(cat "$OFFSET_FILE")
if [[ ! "$offset" =~ ^[0-9]+$ ]]; then
  log "ERROR offset not numeric: '$offset' — refusing to run"
  exit 1
fi

# Atomic single-pass read; tolerate the remote file not existing yet (new file).
remote_cmd="if [ -f \"\$HOME/$VPS_QUEUE_REL\" ]; then awk -v off=$offset 'NR>off{print} END{print \"===TOTAL:\"NR\"===\"}' \"\$HOME/$VPS_QUEUE_REL\"; else echo '===TOTAL:0==='; fi"
out=$(sshpass -p "$VPS_PASSWORD" ssh \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=15 \
  -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
  "$VPS_USER@$VPS_HOST" "$remote_cmd" 2>>"$LOG_FILE")
rc=$?
if [[ $rc -ne 0 ]]; then
  log "ERROR ssh/awk failed rc=$rc — retrying next tick (offset unchanged at $offset)"
  exit 0
fi

total=$(printf '%s\n' "$out" | sed -n 's/^===TOTAL:\([0-9]*\)===$/\1/p' | tail -n1)
if [[ -z "$total" ]]; then
  log "ERROR no TOTAL sentinel in remote output — aborting (offset unchanged at $offset)"
  exit 0
fi

if (( total < offset )); then
  log "INFO truncation/rotation detected (total=$total < offset=$offset) — re-baselining to $total, NOT replaying"
  printf '%s\n' "$total" >"$OFFSET_FILE.tmp" && mv "$OFFSET_FILE.tmp" "$OFFSET_FILE"
  exit 0
fi

if (( total == offset )); then
  exit 0
fi

new_lines=$(printf '%s\n' "$out" | grep -v '^===TOTAL:[0-9]*===$' | sed '/^$/d')
expected=$(( total - offset ))
actual=$(printf '%s\n' "$new_lines" | grep -c .)
if (( actual != expected )); then
  log "WARN forwarded-line count mismatch (expected=$expected, got=$actual) — proceeding, advancing offset to $total"
fi

printf '%s\n' "$new_lines" >>"$LOCAL_QUEUE"

printf '%s\n' "$total" >"$OFFSET_FILE.tmp" && mv "$OFFSET_FILE.tmp" "$OFFSET_FILE"
log "OK forwarded $actual line(s); offset $offset → $total"
