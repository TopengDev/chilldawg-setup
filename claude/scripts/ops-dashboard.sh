#!/usr/bin/env bash
# ops-dashboard.sh — READ-ONLY one-screen health view of the always-on fleet.
#
# Prints PASS / WARN / DOWN per line for: the load-bearing daemons (wa-sender,
# signal-trader), every systemd --user timer, qb_proxy (CDP port 9222), VPS health
# (load / RAM / disk / CPU-steal / key docker containers), and local disk/RAM.
#
# STRICTLY READ-ONLY: this script never starts, stops, restarts, enables, or
# edits anything. Safe to run anytime, any number of times. It only inspects.
#
# Usage:
#   ops-dashboard.sh                 # full dashboard
#   ops-dashboard.sh --no-vps        # skip the (slower) SSH-based VPS section
#   ops-dashboard.sh --no-color      # plain output (also auto-off when piped)
#
# Exit code: 0 always (it's a status view, not a gate — parse the lines, not $?).
#
# Reuses the established patterns: the VPS ssh access pattern from CLAUDE.md and
# the wa-sender queue layout used by signal-trader-bridge.sh / deadman.sh.
set -uo pipefail

# ── args ──────────────────────────────────────────────────────────────────────
USE_COLOR=1; DO_VPS=1
[ -t 1 ] || USE_COLOR=0
for a in "$@"; do
  case "$a" in
    --no-color) USE_COLOR=0 ;;
    --no-vps)   DO_VPS=0 ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a (try --help)" >&2; exit 2 ;;
  esac
done

if [ "$USE_COLOR" = 1 ]; then
  G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[36m'; D=$'\033[2m'; BOLD=$'\033[1m'; Z=$'\033[0m'
else
  G=''; R=''; Y=''; B=''; D=''; BOLD=''; Z=''
fi

# status helpers — fixed-width tag so columns line up
pass() { printf '  %sPASS%s  %-26s %s\n' "$G" "$Z" "$1" "${2:-}"; }
warn() { printf '  %sWARN%s  %-26s %s\n' "$Y" "$Z" "$1" "${2:-}"; }
down() { printf '  %sDOWN%s  %-26s %s\n' "$R" "$Z" "$1" "${2:-}"; }
info() { printf '  %s····%s  %-26s %s\n' "$D" "$Z" "$1" "${2:-}"; }
sect() { printf '\n%s%s== %s ==%s\n' "$BOLD" "$B" "$1" "$Z"; }

QUEUE="$HOME/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl"

# ── load secrets (for VPS section) without leaking values ──────────────────────
if [ -r "$HOME/.claude/secrets.env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.claude/secrets.env" 2>/dev/null || true
fi

# portable hostname (the `hostname` binary isn't always on PATH under systemd/minimal envs)
HOST="${HOSTNAME:-$(cat /proc/sys/kernel/hostname 2>/dev/null || echo local)}"
printf '%s%sops-dashboard%s  %s%s  host=%s%s\n' "$BOLD" "$B" "$Z" "$D" "$(date '+%Y-%m-%d %H:%M:%S %z')" "$HOST" "$Z"

# ══════════════════════════════════════════════════════════════════════════════
# 1. LOAD-BEARING DAEMONS
# ══════════════════════════════════════════════════════════════════════════════
sect "load-bearing daemons (local)"

# wa-sender
wa_active="$(systemctl --user is-active wa-sender.service 2>/dev/null || true)"
# anchored on the bun binary path (char-class avoids self-match — see deadman.sh)
if pgrep -f '/[b]un( run)? src/index\.ts' >/dev/null 2>&1; then wa_proc="yes"; else wa_proc="no"; fi
if [ "$wa_active" = active ] && [ "$wa_proc" = yes ]; then
  pass "wa-sender" "systemd active + bun process up"
elif [ "$wa_active" = active ] && [ "$wa_proc" = no ]; then
  warn "wa-sender" "unit active but NO bun process (wedged?)"
else
  down "wa-sender" "is-active=$wa_active proc=$wa_proc"
fi

# wa-sender queue depth / lag (informational — queue is append-only; consumer
# tracks a byte offset, so a non-zero size is NOT a backlog by itself).
if [ -f "$QUEUE" ]; then
  q_lines="$(wc -l < "$QUEUE" 2>/dev/null | tr -d ' ')"
  q_age_s=$(( $(date +%s) - $(stat -c %Y "$QUEUE" 2>/dev/null || date +%s) ))
  if   (( q_age_s < 3600 ));  then q_age="$((q_age_s/60))m ago"
  elif (( q_age_s < 86400 )); then q_age="$((q_age_s/3600))h ago"
  else q_age="$((q_age_s/86400))d ago"; fi
  info "wa-sender queue" "$q_lines events total · last write $q_age"
else
  warn "wa-sender queue" "queue file absent: $QUEUE"
fi

# signal-trader — runs MANUALLY on the VPS (no unit). Report its real state via
# the VPS section below; here just note where it lives.
if [ "$DO_VPS" = 1 ]; then
  info "signal-trader" "VPS-resident (manual run) — see VPS section"
else
  info "signal-trader" "VPS-resident — skipped (--no-vps)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. SYSTEMD --user TIMERS
# ══════════════════════════════════════════════════════════════════════════════
sect "systemd --user timers"
TIMERS=(
  deadman
  loop-digest
  journal-audit
  qb-proxy-doctor
  daily-brief-morning
  daily-brief-evening
  signal-trader-bridge
  reminder-check
  macro-news
  memory-autopush
  wa-behavior-learn
)
for t in "${TIMERS[@]}"; do
  # macro-news is a long-running .service (no timer); handle it specially.
  if [ "$t" = macro-news ]; then
    en="$(systemctl --user is-enabled macro-news.service 2>/dev/null || true)"
    ac="$(systemctl --user is-active macro-news.service 2>/dev/null || true)"
    if [ "$ac" = active ]; then pass "macro-news.service" "enabled=$en active"
    elif [ "$ac" = failed ]; then down "macro-news.service" "FAILED"
    else warn "macro-news.service" "enabled=$en active=$ac"; fi
    continue
  fi
  unit="$t.timer"
  en="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
  ac="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
  if [ -z "$en" ] && [ -z "$ac" ]; then
    info "$unit" "not installed"
    continue
  fi
  # last + next run for context
  line="$(systemctl --user list-timers "$unit" --all 2>/dev/null | awk 'NR==2{print}')"
  last="$(printf '%s' "$line" | grep -oE 'LAST.*' >/dev/null 2>&1; systemctl --user show "$unit" -p LastTriggerUSec --value 2>/dev/null)"
  if [ "$en" = enabled ] && [ "$ac" = active ]; then
    pass "$unit" "enabled+active${last:+ · last: $last}"
  else
    down "$unit" "is-enabled=$en is-active=$ac"
  fi
done

# ══════════════════════════════════════════════════════════════════════════════
# 3. qb_proxy (CDP port 9222)
# ══════════════════════════════════════════════════════════════════════════════
sect "qb_proxy (CDP :9222)"
if curl -sf -m 3 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  ver="$(curl -sf -m 3 http://127.0.0.1:9222/json/version 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("Browser",""))' 2>/dev/null || true)"
  pass "qb_proxy :9222" "reachable${ver:+ · $ver}"
else
  # Down is only meaningful if qutebrowser is running (config.py starts the proxy
  # with qb). Distinguish so a closed browser isn't flagged red.
  if pgrep -f '(^|/)qutebrowser' >/dev/null 2>&1; then
    down "qb_proxy :9222" "unreachable WHILE qutebrowser is running (doctor should heal)"
  else
    info "qb_proxy :9222" "down — qutebrowser not running (expected; starts with qb)"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 4. LOCAL HOST (disk / RAM)
# ══════════════════════════════════════════════════════════════════════════════
sect "local host"
# RAM
read -r l_used l_total < <(free -m | awk '/^Mem:/{print $3, $2}')
if [ -n "${l_total:-}" ] && [ "$l_total" -gt 0 ]; then
  l_pct=$(( l_used * 100 / l_total ))
  if   (( l_pct >= 92 )); then down "RAM" "${l_used}/${l_total} MB (${l_pct}%)"
  elif (( l_pct >= 80 )); then warn "RAM" "${l_used}/${l_total} MB (${l_pct}%)"
  else pass "RAM" "${l_used}/${l_total} MB (${l_pct}%)"; fi
fi
# disk /
read -r d_use d_avail d_pct < <(df -h / | awk 'NR==2{gsub("%","",$5); print $3, $4, $5}')
if [ -n "${d_pct:-}" ]; then
  if   (( d_pct >= 90 )); then down "disk /" "${d_use} used · ${d_avail} free (${d_pct}%)"
  elif (( d_pct >= 80 )); then warn "disk /" "${d_use} used · ${d_avail} free (${d_pct}%)"
  else pass "disk /" "${d_use} used · ${d_avail} free (${d_pct}%)"; fi
fi
# load
la="$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || true)"
ncpu="$(nproc 2>/dev/null || echo '?')"
info "load (1/5/15m)" "${la:-?} · ${ncpu} CPUs"

# ══════════════════════════════════════════════════════════════════════════════
# 5. VPS (read-only SSH)
# ══════════════════════════════════════════════════════════════════════════════
if [ "$DO_VPS" = 0 ]; then
  sect "VPS"
  info "VPS" "skipped (--no-vps)"
else
  sect "VPS (read-only ssh)"
  if [ -z "${VPS_HOST:-}" ] || [ -z "${VPS_USER:-}" ] || [ -z "${VPS_PASSWORD:-}" ]; then
    warn "VPS" "creds not loaded (VPS_HOST/USER/PASSWORD) — skipping"
  else
    # One SSH round-trip gathers everything (gentle: single connection). Each
    # block is delimited so we can parse it locally. READ-ONLY remote commands.
    VPS_OUT="$(sshpass -p "$VPS_PASSWORD" ssh \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        "$VPS_USER@$VPS_HOST" '
      echo "===LOAD==="; awk "{print \$1, \$2, \$3}" /proc/loadavg
      echo "===MEM==="; free -m | awk "/^Mem:/{print \$3, \$2}"
      echo "===DISK==="; df -h / | awk "NR==2{gsub(\"%\",\"\",\$5); print \$3, \$4, \$5}"
      echo "===STEAL==="; top -bn1 | awk "/%Cpu/{for(i=1;i<=NF;i++) if(\$i ~ /st\$/) print \$(i-1)}" | head -1
      echo "===RUN==="; df -h /run | awk "NR==2{gsub(\"%\",\"\",\$5); print \$5}"
      echo "===ST==="; pgrep -f "[s]ignal_trader|[s]ignal-trader" >/dev/null 2>&1 && echo ALIVE || echo PAUSED
      echo "===DOCKER==="; docker ps --format "{{.Names}}|{{.Status}}" 2>/dev/null | grep -iE "aenoxa-pos-web|pulse-landing|hiremeup-app|execfi-app|aenoxa-dashboard|pi-remote|landing-page-web|aenoxa-loki|aenoxa-grafana|watchtower" || echo "(docker unavailable)"
      echo "===END==="
    ' 2>/dev/null)"
    if [ -z "$VPS_OUT" ]; then
      down "VPS" "SSH failed / unreachable (portscan ban? network?) — retry shortly"
    else
      # parse blocks
      blk() { printf '%s\n' "$VPS_OUT" | awk -v s="===$1===" -v e="===$2===" 'f&&$0==e{f=0} f; $0==s{f=1}'; }
      v_load="$(blk LOAD MEM)"
      read -r vu vt < <(blk MEM DISK)
      read -r vdu vda vdp < <(blk DISK STEAL)
      v_steal="$(blk STEAL RUN | head -1)"
      v_run="$(blk RUN ST | head -1)"
      v_st="$(blk ST DOCKER | head -1)"

      info "VPS load (1/5/15m)" "${v_load:-?}"
      if [ -n "${vt:-}" ] && [ "$vt" -gt 0 ] 2>/dev/null; then
        vpct=$(( vu * 100 / vt ))
        if (( vpct >= 92 )); then down "VPS RAM" "${vu}/${vt} MB (${vpct}%)"
        elif (( vpct >= 85 )); then warn "VPS RAM" "${vu}/${vt} MB (${vpct}%)"
        else pass "VPS RAM" "${vu}/${vt} MB (${vpct}%)"; fi
      fi
      if [ -n "${vdp:-}" ]; then
        if (( vdp >= 90 )); then down "VPS disk /" "${vdu} used · ${vda} free (${vdp}%)"
        elif (( vdp >= 80 )); then warn "VPS disk /" "${vdu} used · ${vda} free (${vdp}%)"
        else pass "VPS disk /" "${vdu} used · ${vda} free (${vdp}%)"; fi
      fi
      # CPU steal: the Hostinger usage-throttle flag. >20% sustained = the rabbitmq
      # broker spin (memory: VPS infra constraints). Treat numerically.
      if [ -n "${v_steal:-}" ]; then
        steal_int="${v_steal%%.*}"; [ -z "$steal_int" ] && steal_int=0
        if   (( steal_int >= 30 )); then down "VPS CPU-steal" "${v_steal}% (Hostinger throttle — stop the spinning broker)"
        elif (( steal_int >= 10 )); then warn "VPS CPU-steal" "${v_steal}% (watch — broker may be spinning)"
        else pass "VPS CPU-steal" "${v_steal}% (no throttle)"; fi
      fi
      # /run fills from the outbox-relayer .pid leak (memory: VPS infra constraints).
      if [ -n "${v_run:-}" ]; then
        if   (( v_run >= 90 )); then down "VPS /run tmpfs" "${v_run}% (outbox-relayer .pid leak — restart aenoxa-auth-outbox-relayer)"
        elif (( v_run >= 60 )); then warn "VPS /run tmpfs" "${v_run}% (creeping — .pid leak)"
        else pass "VPS /run tmpfs" "${v_run}%"; fi
      fi
      # signal-trader on VPS (PAUSED is normal — it's run manually)
      if [ "$v_st" = ALIVE ]; then pass "VPS signal-trader" "process running"
      else info "VPS signal-trader" "PAUSED (manual bot — not running; normal when idle)"; fi
      # key containers
      printf '%s\n' "$VPS_OUT" | awk '/===DOCKER===/{f=1;next} /===END===/{f=0} f' | while IFS='|' read -r name st; do
        [ -z "$name" ] && continue
        case "$name" in
          *'(docker unavailable)'*) warn "VPS docker" "unavailable (no perm?)"; continue ;;
        esac
        # Order matters: test 'unhealthy' BEFORE the generic 'Up ' so an
        # "Up 6 hours (unhealthy)" container is flagged WARN, not PASS.
        case "$st" in
          *unhealthy*)                  warn "  $name" "$st" ;;
          *healthy*)                    pass "  $name" "$st" ;;
          *Exited*|*Restarting*|*Dead*) down "  $name" "$st" ;;
          *'Up '*)                      pass "  $name" "$st" ;;
          *)                            info "  $name" "$st" ;;
        esac
      done
    fi
  fi
fi

printf '\n%s──────────────────────────────────────────%s\n' "$D" "$Z"
printf '%sread-only snapshot · nothing was modified%s\n' "$D" "$Z"
exit 0
