#!/usr/bin/env bash
# market-events-relay.sh — LOCAL-side daily relay for the two sources that
# Cloudflare 403s from the VPS DC IP (DefiLlama unlocks page + Farside ETF
# flow tables). Fetches locally via the repo venv, pushes the staged JSON to
# VPS ~/market-events/incoming/ via tar-over-ssh (the VPS has no rsync), where
# market-events-ingest.timer consumes it.
#
# Failure visibility: a non-zero exit here marks the local service failed
# (journal); independently, the VPS ingest path raises a fetch_health 'relay'
# WA alert when no fresh file lands for >36h. Staged files that fail to push
# stay in staging and ride along with the next successful push.
#
# Hard invariants:
#   - credentials come from ~/.claude/secrets.env (sourced, never inlined);
#   - VPS write surface: ~/market-events/incoming/ ONLY.
set -uo pipefail

REPO="$HOME/claude/Git/repositories/market-events"
STATE_DIR="$HOME/.claude/state"
STAGING="$STATE_DIR/market-events-relay/staging"
LOG_FILE="$STATE_DIR/market-events-relay.log"
LOCK_FILE="$STATE_DIR/market-events-relay.lock"

mkdir -p "$STAGING"

log() { printf '%s %s\n' "$(date -Is)" "$*" >>"$LOG_FILE"; }

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "WARN another instance is running — skipping"
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

"$REPO/.venv/bin/market-events" relay-fetch --out "$STAGING" >>"$LOG_FILE" 2>&1
fetch_rc=$?

shopt -s nullglob
files=("$STAGING"/*.json)
if (( ${#files[@]} == 0 )); then
  log "ERROR fetch produced no files (rc=$fetch_rc) — nothing to push"
  exit 1
fi

# tar-over-ssh; extract into a remote tmp dir then mv (atomic on one fs) so
# the VPS ingest never reads a half-written file.
tar -C "$STAGING" -czf - "${files[@]##*/}" | sshpass -p "$VPS_PASSWORD" ssh \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=20 \
  -o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
  "$VPS_USER@$VPS_HOST" \
  'set -e; mkdir -p ~/market-events/incoming/.staging &&
   tar -xzf - -C ~/market-events/incoming/.staging &&
   mv ~/market-events/incoming/.staging/*.json ~/market-events/incoming/ &&
   rmdir ~/market-events/incoming/.staging' 2>>"$LOG_FILE"
push_rc=$?

if (( push_rc == 0 )); then
  rm -f "${files[@]}"
  log "OK pushed ${#files[@]} file(s) (fetch rc=$fetch_rc): ${files[*]##*/}"
else
  log "ERROR push failed rc=$push_rc — files stay staged for the next run"
  exit 1
fi

exit "$fetch_rc"
