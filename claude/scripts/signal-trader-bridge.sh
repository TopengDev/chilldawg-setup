#!/usr/bin/env bash
# signal-trader-bridge.sh — VPS→local signal-trader notif bridge (Task #132)
#
# Pulls newly-appended lines from the VPS wa-sender queue and appends them
# VERBATIM to the LOCAL wa-sender queue (which the existing local relay drains
# and sends to WhatsApp). Restores notif delivery that broke when signal-trader
# was migrated to the VPS but the relay stayed local-only.
#
# Design (Toper-approved Q1-Q3):
#   - Local-pull: a local systemd --user timer runs this once a minute.
#   - Forward-only: offset is seeded to the VPS queue's line count at install.
#     Only lines written AFTER that are forwarded. Backlog is NOT replayed.
#   - Idempotent: offset is a persisted line count; re-runs never double-forward.
#   - Deliver-when-local-up: only runs while this machine is on (matches the
#     exact pre-migration behavior). No VPS relay, no 2nd WA device.
#
# Hard invariants:
#   - APPEND-ONLY to the local queue. Never truncate/rewrite it.
#   - READ-ONLY on the VPS (single awk pass, no writes to the VPS queue).
#   - Never touches the wa-sender or signal-trader processes.
set -uo pipefail

STATE_DIR="$HOME/.claude/state"
OFFSET_FILE="$STATE_DIR/signal-trader-bridge.offset"
LOG_FILE="$STATE_DIR/signal-trader-bridge.log"
LOCK_FILE="$STATE_DIR/signal-trader-bridge.lock"

LOCAL_QUEUE="$HOME/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl"
# Path relative to the remote $HOME (expanded on the VPS side):
VPS_QUEUE_REL="signal-trader/wa-sender/queue/events.jsonl"

mkdir -p "$STATE_DIR"

log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"; }

# ── single-instance guard (systemd already serializes same-unit oneshots; this
#    also protects against a manual run colliding with a timer tick) ───────────
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "WARN another instance is running — skipping this tick"
  exit 0
fi

# ── credentials (systemd --user does not source ~/.bashrc) ────────────────────
if [[ -r "$HOME/.claude/secrets.env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.claude/secrets.env"
fi
if [[ -z "${VPS_HOST:-}" || -z "${VPS_USER:-}" || -z "${VPS_PASSWORD:-}" ]]; then
  log "ERROR missing VPS_HOST/VPS_USER/VPS_PASSWORD — cannot run"
  exit 1
fi

# ── read persisted offset (line count already forwarded; install seeds baseline)
if [[ ! -r "$OFFSET_FILE" ]]; then
  log "ERROR offset file missing ($OFFSET_FILE) — install must seed the baseline first. Refusing to run."
  exit 1
fi
offset=$(cat "$OFFSET_FILE")
if [[ ! "$offset" =~ ^[0-9]+$ ]]; then
  log "ERROR offset not numeric: '$offset' — refusing to run"
  exit 1
fi

# ── atomic single-pass read of the VPS queue ──────────────────────────────────
# awk prints every line with NR>offset (the new ones), then prints the total
# line count as a sentinel in END. One pass = a consistent snapshot: the printed
# lines are exactly lines (offset+1 .. total), immune to concurrent appends.
remote_cmd="awk -v off=$offset 'NR>off{print} END{print \"===TOTAL:\"NR\"===\"}' \"\$HOME/$VPS_QUEUE_REL\""
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

# ── parse the TOTAL sentinel + separate the new lines ─────────────────────────
total=$(printf '%s\n' "$out" | sed -n 's/^===TOTAL:\([0-9]*\)===$/\1/p' | tail -n1)
if [[ -z "$total" ]]; then
  log "ERROR no TOTAL sentinel in remote output — aborting (offset unchanged at $offset)"
  exit 0
fi

# truncation / rotation: VPS file shrank below our offset → re-baseline, no replay
if (( total < offset )); then
  log "INFO truncation/rotation detected (total=$total < offset=$offset) — re-baselining to $total, NOT replaying"
  printf '%s\n' "$total" >"$OFFSET_FILE.tmp" && mv "$OFFSET_FILE.tmp" "$OFFSET_FILE"
  exit 0
fi

# nothing new
if (( total == offset )); then
  exit 0
fi

# everything except the sentinel = the new event lines to forward
new_lines=$(printf '%s\n' "$out" | grep -v '^===TOTAL:[0-9]*===$' | sed '/^$/d')
expected=$(( total - offset ))
actual=$(printf '%s\n' "$new_lines" | grep -c .)
if (( actual != expected )); then
  log "WARN forwarded-line count mismatch (expected=$expected from line-count, got=$actual non-empty lines) — proceeding, advancing offset to $total"
fi

# append VERBATIM to the local queue (append-only)
printf '%s\n' "$new_lines" >>"$LOCAL_QUEUE"

# durably advance the offset (atomic write-then-rename)
printf '%s\n' "$total" >"$OFFSET_FILE.tmp" && mv "$OFFSET_FILE.tmp" "$OFFSET_FILE"
log "OK forwarded $actual line(s); offset $offset → $total"
