#!/usr/bin/env bash
# qb-proxy-doctor — self-healing watchdog for the qutebrowser CDP proxy (qb_proxy.py).
#
# Inspired by elpabl0/sebat-duls (github.com/alkautsarf), with permission, 2026-05-30.
# NOTE: his repo's symlink-doctor.sh is a macOS-Homebrew binary-symlink checker, NOT a
# proxy watchdog. This script is a Linux-native fresh build addressing OUR real gap:
# the CDP proxy had no auto-restart. qb's config.py only starts the proxy when qb
# itself launches; if the proxy wedges or dies while qb stays up, agent-browser/fitest
# silently lose their CDP path. This timer catches that and restarts it.
#
# SAFETY (load-bearing — fitest browses through the live proxy):
#   * Acts ONLY when port 9222 is unreachable AND qutebrowser is running.
#   * If the proxy is healthy → pure no-op (never touches the live process).
#   * If qutebrowser is NOT running → no-op (never spawns an orphan proxy with no browser).
#   * Restart path mirrors config.py exactly (pkill stale qb_proxy.py → python3 relaunch).
#   * Re-checks 3× with backoff before declaring "down" to avoid false-positive restarts.
#
# Exit: 0 healthy/no-op-or-restarted-ok, 1 restart attempted but still down.
set -u

PROXY_PORT=9222
PROXY_PATH="$HOME/.config/qutebrowser/scripts/qb_proxy.py"
CACHE_DIR="$HOME/.cache/qb_proxy"
LOG="$CACHE_DIR/doctor.log"
PROXY_LOG="$CACHE_DIR/proxy.log"

mkdir -p "$CACHE_DIR"
ts() { date +'%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

proxy_alive() {
  curl -sf -m 3 "http://127.0.0.1:${PROXY_PORT}/json/version" >/dev/null 2>&1
}

# 1. Fast path: healthy → silent no-op (don't spam the log every 2 min).
if proxy_alive; then
  exit 0
fi

# 2. Retry to rule out a transient blip before taking any action.
for _ in 1 2 3; do
  sleep 2
  if proxy_alive; then
    log "OK: proxy recovered on retry (transient blip), no action."
    exit 0
  fi
done

# 3. Proxy is genuinely down. Only restart if qutebrowser is actually running —
#    a proxy with no browser behind it (port 2262) is useless, and config.py
#    will start the proxy itself the next time qb launches.
if ! pgrep -f '(^|/)qutebrowser' >/dev/null 2>&1; then
  log "SKIP: proxy down but qutebrowser not running — config.py will start it on next qb launch."
  exit 0
fi

if [ ! -f "$PROXY_PATH" ]; then
  log "ERROR: proxy down + qb up, but $PROXY_PATH missing — cannot restart."
  exit 1
fi

log "DRIFT: port $PROXY_PORT down while qutebrowser is running — restarting proxy (mirrors config.py)."
# Clear any wedged/half-dead qb_proxy.py orphan, exactly as config.py does on qb start.
# Anchored regex: '/qb_proxy\.py' followed by end-of-line or whitespace. This matches
# the real process ("python3 .../scripts/qb_proxy.py") but NOT stray siblings like
# qb_proxy.py.new / qb_proxy.py.bak (a bare 'qb_proxy.py' substring-matches those).
pkill -f '/qb_proxy\.py($|[[:space:]])' 2>/dev/null
sleep 1
{
  echo ""
  echo "=== qb-proxy-doctor restart $(ts) ==="
} >> "$PROXY_LOG"
setsid python3 "$PROXY_PATH" >> "$PROXY_LOG" 2>&1 &
disown 2>/dev/null || true

# Give it a moment to bind, then verify.
sleep 2
if proxy_alive; then
  log "FIXED: proxy restarted and answering on port $PROXY_PORT."
  exit 0
fi
log "FAIL: proxy still down after restart attempt — see $PROXY_LOG."
exit 1
