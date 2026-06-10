#!/usr/bin/env bash
# deadman.sh — liveness watchdog for the load-bearing notification daemons.
#
# WHY: wa-sender (the Baileys WhatsApp queue consumer) silently died once for 26h,
# dropping every signal-trader / macro-news / reminder notification with no alarm
# (memory: feedback_wa_sender_load_bearing.md). This watchdog catches that class
# of silent death.
#
# ALERT CHANNEL — deliberately OUT-OF-BAND: alerts go by EMAIL (smtplib via
# claude/scripts/lib-email-alert.py, reading ~/.config/email-mcp/config.json).
# We MUST NOT alert through wa-sender, because wa-sender IS the thing most likely
# to be dead — alerting through a dead channel is useless. Email needs no Claude
# session and no wa-sender, so it survives a wa-sender outage.
#
# CORE DESIGN — "liveness-armed transition alerts" (NOT naive presence checks):
#   * A target is only ARMED after we have observed it ALIVE at least once
#     (we write a `<target>.armed` heartbeat each time it's seen alive).
#   * We alert ONLY on an alive->dead TRANSITION: the target was armed (so it was
#     genuinely running before) and is now dead. A target that has simply never
#     started in this watchdog's lifetime is UNARMED and stays SILENT.
#   * This is essential because signal-trader is run manually on the VPS and is
#     frequently NOT running by design (paused). A naive "alert if process
#     missing" would false-fire every tick and wake Toper. With arming:
#       - wa-sender: alive now -> armed -> alerts on the real 26h-style death.
#       - signal-trader: paused -> unarmed -> silent; arms only once Toper starts
#         it, then alerts if it dies unexpectedly afterward.
#   * Alert-once flap guard: a `<target>.alerted` flag suppresses repeat emails
#     every tick while down. On recovery we send ONE "recovered" note and clear
#     both the alerted flag (keeping it armed).
#
# SAFETY: this script READS state only. It NEVER starts/stops/restarts any daemon
# (wa-sender, signal-trader, timers) — recovery is systemd's job (wa-sender has
# Restart=on-failure) or Toper's. Healthy = silent (no email, minimal logging).
#
# Run: as a `systemd --user` oneshot on a timer (deadman.timer, every ~3 min).
#
# Exit: 0 always-ish (a watchdog must not crash-loop the timer). Internal errors
#       are logged; a total email-send failure during an active alert is logged
#       loudly but still exits 0 so the timer keeps probing.
set -uo pipefail

# ── paths ─────────────────────────────────────────────────────────────────────
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPTS_DIR="$(dirname "$SELF")"
EMAIL_LIB="$SCRIPTS_DIR/lib-email-alert.py"

STATE_DIR="$HOME/.claude/state/deadman"
LOG_FILE="$HOME/.claude/state/deadman.log"
LOCK_FILE="$STATE_DIR/.lock"

LOCAL_QUEUE="$HOME/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl"
VPS_QUEUE_REL="signal-trader/wa-sender/queue/events.jsonl"

mkdir -p "$STATE_DIR"

ts()  { date +'%Y-%m-%dT%H:%M:%S%z'; }
log() { printf '%s %s\n' "$(ts)" "$*" >>"$LOG_FILE"; }

# ── single-instance guard (timer serializes same-unit oneshots; this also guards
#    a manual run racing a tick) ───────────────────────────────────────────────
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "WARN another deadman instance is running — skipping this tick"
  exit 0
fi

# ── load secrets for the VPS check (systemd --user does NOT source ~/.bashrc) ──
if [[ -r "$HOME/.claude/secrets.env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.claude/secrets.env"
fi

# ── email alert helper ────────────────────────────────────────────────────────
# send_email <subject> <body> — best-effort, logs result. Never aborts the script.
send_email() {
  local subject="$1" body="$2" out rc
  if [[ ! -x "$EMAIL_LIB" ]] && [[ ! -r "$EMAIL_LIB" ]]; then
    log "ERROR email lib missing at $EMAIL_LIB — CANNOT alert: $subject"
    return 1
  fi
  out=$(printf '%s' "$body" | python3 "$EMAIL_LIB" --subject "$subject" --body - 2>&1)
  rc=$?
  if [[ $rc -eq 0 ]]; then
    log "ALERT-SENT [$subject] :: $out"
  else
    log "ALERT-FAILED rc=$rc [$subject] :: $out"
  fi
  return $rc
}

# ── per-target state helpers ──────────────────────────────────────────────────
# arm <target>            : record that target was seen alive (idempotent)
# is_armed <target>       : 0 if armed
# is_alerted <target>     : 0 if an alert is currently outstanding
# mark_alerted <target>   : set the alerted flag
# clear_alerted <target>  : clear the alerted flag
arm()           { date +%s >"$STATE_DIR/$1.armed"; }
is_armed()      { [[ -f "$STATE_DIR/$1.armed" ]]; }
is_alerted()    { [[ -f "$STATE_DIR/$1.alerted" ]]; }
mark_alerted()  { date +%s >"$STATE_DIR/$1.alerted"; }
clear_alerted() { rm -f "$STATE_DIR/$1.alerted"; }

# portable hostname (the `hostname` binary isn't always on PATH under systemd --user)
HOSTNAME_SHORT="${HOSTNAME:-$(cat /proc/sys/kernel/hostname 2>/dev/null || echo local)}"

# evaluate <target> <human-name> <alive 0|1> <detail>
#   Implements the armed-transition + flap-guard + recovery state machine.
#   - alive=0 (healthy): arm it; if it was previously alerted, send ONE recovery
#     mail and clear the alert flag. Otherwise silent.
#   - alive=1 (DEAD): only act if armed (it was alive before). Send one alert
#     (flap-guarded). If unarmed, stay silent (never-started target).
#   NOTE: the 3rd arg is "DEAD?" (1 = dead) to keep call sites readable below.
evaluate() {
  local target="$1" name="$2" dead="$3" detail="$4"

  if [[ "$dead" -eq 0 ]]; then
    # healthy
    arm "$target"
    if is_alerted "$target"; then
      clear_alerted "$target"
      send_email \
        "[deadman] RECOVERED: $name on $HOSTNAME_SHORT" \
        "$name is back UP as of $(ts).
host: $HOSTNAME_SHORT
detail: $detail

(This is an automated recovery notice from deadman.sh. The earlier outage alert
for $name can be considered cleared.)"
      log "RECOVERED $target — $detail"
    fi
    return 0
  fi

  # dead
  if ! is_armed "$target"; then
    # never observed alive in this watchdog's lifetime → expected-down → silent.
    log "SILENT $target is down but UNARMED (never seen alive yet) — no alert — $detail"
    return 0
  fi
  if is_alerted "$target"; then
    # already alerted, still down → flap guard, stay quiet.
    log "STILL-DOWN $target (already alerted) — $detail"
    return 0
  fi
  mark_alerted "$target"
  send_email \
    "[deadman] DOWN: $name on $HOSTNAME_SHORT" \
    "ALERT: $name appears DOWN as of $(ts).
host: $HOSTNAME_SHORT
detail: $detail

$name was observed alive earlier (armed) and is now unreachable. This is the
silent-death failure mode (cf. the 26h wa-sender outage). Investigate:
  systemctl --user status wa-sender.service
  systemctl --user list-timers
  ~/.claude/scripts/ops-dashboard.sh

(Automated alert from deadman.sh via out-of-band email — sent because the
WhatsApp path itself may be the thing that is down.)"
  log "ALERTED $target DOWN — $detail"
  return 0
}

# ── CHECK 1: wa-sender (local systemd --user service + process) ───────────────
check_wa_sender() {
  local active proc_ok=1 detail
  active="$(systemctl --user is-active wa-sender.service 2>/dev/null || true)"
  # Confirm a real bun process is actually running the daemon (defends against a
  # unit that reports active while the process is wedged/zombie). Match the unit's
  # ExecStart, anchored on the bun BINARY PATH so we never self-match a bash `-c`
  # carrier (or this very script) that merely contains the literal pattern text.
  # The `[b]un` char-class makes the pattern string itself not contain "bun ..."
  # as a literal substring -> pgrep -f can't match its own argv. We match the
  # linuxbrew bun path running this daemon's entrypoint.
  if pgrep -f '/[b]un( run)? src/index\.ts' >/dev/null 2>&1; then
    proc_ok=0
  fi

  if [[ "$active" == "active" && "$proc_ok" -eq 0 ]]; then
    detail="systemd active + bun process present"
    evaluate "wa-sender" "wa-sender (WhatsApp queue daemon)" 0 "$detail"
  else
    detail="systemctl is-active=$active; bun-process-present=$([[ $proc_ok -eq 0 ]] && echo yes || echo no)"
    evaluate "wa-sender" "wa-sender (WhatsApp queue daemon)" 1 "$detail"
  fi
}

# ── CHECK 2: wa-sender queue is DRAINING (not silently backing up) ────────────
# The consumer drains by byte offset and never deletes lines, so "queue size" is
# not a backlog. Real backlog = lines keep getting APPENDED but the daemon is not
# consuming them. We approximate: if the queue file's mtime advanced since last
# tick (new events were enqueued) we record a "pending since" timestamp; we clear
# it whenever wa-sender is confirmed healthy (a healthy daemon drains within its
# 10s poll). If events were enqueued AND wa-sender has been unhealthy for a
# sustained window, that's a genuine drain stall.
#
# In practice CHECK 1 (wa-sender down) is the dominant signal and already alerts.
# This check exists so a "daemon up but not draining" anomaly still surfaces. It
# is armed-gated through the same wa-sender arming to avoid noise.
QUEUE_MTIME_STATE="$STATE_DIR/queue.lastmtime"
QUEUE_STALL_SINCE="$STATE_DIR/queue.stall_since"
QUEUE_STALL_SECS=900   # 15 min of "new events present but wa-sender unhealthy" = stall

check_queue_drain() {
  [[ -f "$LOCAL_QUEUE" ]] || { log "INFO local queue file absent ($LOCAL_QUEUE) — skipping drain check"; return 0; }
  local cur_mtime prev_mtime wa_active now
  cur_mtime="$(stat -c %Y "$LOCAL_QUEUE" 2>/dev/null || echo 0)"
  prev_mtime="$(cat "$QUEUE_MTIME_STATE" 2>/dev/null || echo 0)"
  echo "$cur_mtime" >"$QUEUE_MTIME_STATE"
  wa_active="$(systemctl --user is-active wa-sender.service 2>/dev/null || true)"
  now="$(date +%s)"

  # If wa-sender is healthy, the queue is being drained — clear any stall marker.
  if [[ "$wa_active" == "active" ]] && pgrep -f '/[b]un( run)? src/index\.ts' >/dev/null 2>&1; then
    rm -f "$QUEUE_STALL_SINCE"
    return 0
  fi

  # wa-sender NOT healthy. If new events were appended (mtime advanced), start/keep
  # a stall timer. CHECK 1 already alerts on wa-sender death; we only escalate a
  # SEPARATE drain-stall alert if it persists with pending events — and only if
  # wa-sender was ever armed (real prior life).
  if (( cur_mtime > prev_mtime )); then
    [[ -f "$QUEUE_STALL_SINCE" ]] || echo "$now" >"$QUEUE_STALL_SINCE"
  fi
  if [[ -f "$QUEUE_STALL_SINCE" ]] && is_armed "wa-sender"; then
    local since elapsed
    since="$(cat "$QUEUE_STALL_SINCE" 2>/dev/null || echo "$now")"
    elapsed=$(( now - since ))
    if (( elapsed >= QUEUE_STALL_SECS )); then
      if ! is_alerted "queue-drain"; then
        mark_alerted "queue-drain"
        send_email \
          "[deadman] QUEUE STALL: wa-sender not draining on $HOSTNAME_SHORT" \
          "ALERT: the wa-sender queue has had new events for >= ${QUEUE_STALL_SECS}s while
wa-sender is unhealthy (is-active=$wa_active). Notifications are NOT being delivered.
queue: $LOCAL_QUEUE
host: $HOSTNAME_SHORT
time: $(ts)

(Automated drain-stall alert from deadman.sh, out-of-band email.)"
        log "ALERTED queue-drain stall (elapsed=${elapsed}s)"
      fi
    fi
  else
    # healthy enough / no pending → clear the drain alert if it was set.
    if is_alerted "queue-drain"; then
      clear_alerted "queue-drain"
      log "RECOVERED queue-drain"
    fi
  fi
}

# ── CHECK 3: signal-trader on the VPS (armed-gated; usually paused) ───────────
# signal-trader runs MANUALLY on the VPS (no systemd unit, no cron). It is often
# intentionally not running. We detect liveness by a recent process match on the
# VPS. Because of arming, a paused signal-trader stays silent; only a process that
# was seen alive and then vanished triggers an alert. We bound the SSH so a VPS
# network blip doesn't itself look like a death (treated as "unknown" → no state
# change, logged).
check_signal_trader() {
  if [[ -z "${VPS_HOST:-}" || -z "${VPS_USER:-}" || -z "${VPS_PASSWORD:-}" ]]; then
    log "INFO signal-trader check skipped — VPS creds not loaded"
    return 0
  fi
  local out rc alive_token
  # The [s] char-class prevents pgrep -f from matching the ssh carrier shell whose
  # argv contains this very pattern (a classic pgrep -f self-match false positive
  # that would otherwise report a paused bot as "alive" and wrongly arm it).
  out=$(sshpass -p "$VPS_PASSWORD" ssh \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=15 \
        -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
        "$VPS_USER@$VPS_HOST" \
        'pgrep -f "[s]ignal_trader|[s]ignal-trader" >/dev/null 2>&1 && echo ST_ALIVE || echo ST_DEAD' \
        2>>"$LOG_FILE")
  rc=$?
  if [[ $rc -ne 0 ]]; then
    # SSH itself failed (VPS unreachable / ban / network). We can't conclude the
    # bot died — leave state untouched, just log. (We do NOT alert on VPS-down
    # here; that's outside the daemon-deadman's remit and would be noisy.)
    log "INFO signal-trader check inconclusive — ssh rc=$rc (VPS unreachable?) — state unchanged"
    return 0
  fi
  alive_token="$(printf '%s\n' "$out" | grep -Eo 'ST_ALIVE|ST_DEAD' | tail -n1)"
  if [[ "$alive_token" == "ST_ALIVE" ]]; then
    evaluate "signal-trader" "signal-trader (VPS trading bot)" 0 "VPS pgrep matched signal_trader"
  elif [[ "$alive_token" == "ST_DEAD" ]]; then
    evaluate "signal-trader" "signal-trader (VPS trading bot)" 1 "VPS pgrep found no signal_trader process"
  else
    log "INFO signal-trader check inconclusive — no token in ssh output — state unchanged"
  fi
}

# ── run all checks ────────────────────────────────────────────────────────────
check_wa_sender
check_queue_drain
check_signal_trader

exit 0
