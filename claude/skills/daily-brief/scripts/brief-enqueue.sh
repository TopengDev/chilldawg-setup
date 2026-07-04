#!/usr/bin/env bash
# brief-enqueue.sh - connection-free delivery of ONE daily-brief message.
#
# The ONLY sanctioned delivery path for the SCHEDULED (headless) daily-brief.
# It appends exactly ONE {to,message,kind,ts} line to the load-bearing wa-sender
# queue, which the always-on wa-sender Baileys daemon drains to WhatsApp. NO
# WhatsApp plugin, NO second Baileys socket, NO WHATSAPP=1. This is the fix for
# the 2026-06/07 conflict-reconnect outage (see references/delivery-architecture.md).
#
# Contract (mirrors /remindme's remindctl discipline):
#   * Pre-flight gate: refuses (non-zero) if wa-sender.service is inactive or the
#     queue is not writable, so a caller never claims "sent" when it is not.
#   * APPEND-ONLY: one single-write append. NEVER truncates/rewrites the queue
#     (wa-sender tracks a byte offset; a shrink drops the next real notification).
#   * flock-guarded on the skill's OWN lock file (serializes concurrent briefs).
#   * Phone-JID only: refuses any recipient that is not <digits>@s.whatsapp.net
#     (the proven wa-sender surface; never an unverified @lid over this transport).
#   * Verify-after-write: re-reads the region appended since our write and matches
#     OUR exact line by (kind,to,ts) before exiting 0 (robust to interleaved
#     producer lines; NOT "the last line"). A failed verify means do-not-claim-sent.
#
# Exit codes: 0 ok | 2 usage | 3 wa-sender inactive | 4 queue not writable/IO
#             | 5 verify-after-write failed | 6 bad recipient JID
#
# Usage:
#   brief-enqueue.sh --message-file <path|-> [--to <jid>] [--kind <label>]
#   printf '%s' "$MSG" | brief-enqueue.sh --message-file -
#   brief-enqueue.sh --help
set -euo pipefail

QUEUE="${DAILY_BRIEF_QUEUE:-$HOME/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl}"
LOCK="${DAILY_BRIEF_ENQUEUE_LOCK:-$HOME/.local/share/daily-brief/enqueue.lock}"
# Phone-format JID is the PROVEN wa-sender surface. Both this and the legacy
# @lid reach Toper, but wa-sender only delivers to @s.whatsapp.net in practice.
# Headless (systemd/cron) has no ~/.bashrc, so pull identity vars from secrets.env directly.
[ -r "$HOME/.claude/secrets.env" ] && . "$HOME/.claude/secrets.env"
TO="${DAILY_BRIEF_JID:?DAILY_BRIEF_JID not set (define in ~/.claude/secrets.env)}"
KIND="daily-brief"
MSGFILE=""

usage() { sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --message-file) MSGFILE="${2:-}"; shift 2 ;;
    --message)      MSGFILE="$(mktemp)"; printf '%s' "${2:-}" > "$MSGFILE"; shift 2 ;;
    --to)           TO="${2:-}"; shift 2 ;;
    --kind)         KIND="${2:-}"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "brief-enqueue: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

[ -n "$MSGFILE" ] || { echo "brief-enqueue: --message-file (or --message) is required" >&2; exit 2; }
[ "$MSGFILE" = "-" ] && MSGFILE=/dev/stdin

# Rule 6 (mechanical): phone-JID only over wa-sender. Never a bare @lid here.
case "$TO" in
  *@s.whatsapp.net) : ;;
  *) echo "DEGRADED:bad-jid ($TO is not <digits>@s.whatsapp.net) - refusing to enqueue" >&2; exit 6 ;;
esac

# Pre-flight check 1: wa-sender must be draining the queue, else this enqueues
# a row that silently never delivers (feedback_wa_sender_load_bearing).
if ! systemctl --user is-active --quiet wa-sender.service; then
  echo "DEGRADED:wa-sender-inactive - queue would accept the row but nothing drains it. NOT enqueuing. (Never restart wa-sender: Toper-gated.)" >&2
  exit 3
fi

# Pre-flight check 2: queue must exist + be writable (append target).
[ -f "$QUEUE" ] || { echo "DEGRADED:queue-missing ($QUEUE)" >&2; exit 4; }
[ -w "$QUEUE" ] || { echo "DEGRADED:queue-not-writable ($QUEUE)" >&2; exit 4; }

mkdir -p "$(dirname "$LOCK")"

# Build the line with jq so the (multi-line) message is correctly JSON-escaped.
# --rawfile turns the body's real newlines into \n so the whole event is ONE
# physical line (exactly what wa-sender's newline-split reader requires) and
# preserves UTF-8 (emoji stay real bytes). Schema = the verified live keys:
# {to, message, kind, ts(number)}. ts is informational (wa-sender ignores it) and
# doubles as our verify nonce (one brief per mode per WIB day, so it is unique).
LINE="$(jq -nc --arg to "$TO" --rawfile msg "$MSGFILE" --arg kind "$KIND" \
        '{to:$to, message:$msg, kind:$kind, ts:(now|floor)}')" \
  || { echo "brief-enqueue: jq failed to build the line" >&2; exit 4; }

# Guard: never enqueue an empty message. wa-sender's reader silently SKIPS a row
# whose message is empty (if (!evt.to || !evt.message)), which would look "sent"
# but never arrive. Catch it here as a caller bug (exit 2), before the append.
MSGLEN="$(printf '%s' "$LINE" | jq -r '.message | length')"
[ "${MSGLEN:-0}" -gt 0 ] || { echo "brief-enqueue: refusing to enqueue an empty message" >&2; exit 2; }

# Record the ts we are about to write + the pre-append size, so verify can scan
# ONLY the region we (and any interleaving producer) appended and match OUR exact
# line. NOT "tail -n 1": signal-trader / macro-news / reminders can append a burst
# between our write and our read, so the last line is often not ours.
TS="$(printf '%s' "$LINE" | jq -r '.ts')"
PRE="$(stat -c %s "$QUEUE" 2>/dev/null || echo 0)"

# APPEND-ONLY single atomic O_APPEND write, serialized against concurrent
# /daily-brief runs by an flock on the skill's OWN lock file. `>>` never truncates
# the queue (cross-producer safety comes from the write being a single atomic
# append; the lock only orders our own instances).
exec 9>"$LOCK"
flock 9
printf '%s\n' "$LINE" >> "$QUEUE" || { flock -u 9; echo "brief-enqueue: append failed" >&2; exit 4; }
flock -u 9

# Verify-after-write: our exact line must read back from the appended region,
# matched by (kind, to, ts) with a non-empty message. Robust to interleaved
# producer lines. Only a passing assert authorizes the caller to write its lock.
set +o pipefail
MATCHES="$(tail -c "+$((PRE + 1))" "$QUEUE" 2>/dev/null \
          | jq -c --arg to "$TO" --arg kind "$KIND" --argjson ts "$TS" \
                'select(.to==$to and .kind==$kind and .ts==$ts and (.message|length)>0)' 2>/dev/null \
          | wc -l)"
set -o pipefail
if [ "${MATCHES:-0}" -ge 1 ]; then
  echo "ENQUEUED to=$TO kind=$KIND ts=$TS bytes=$(printf '%s' "$LINE" | wc -c)"
  exit 0
else
  echo "VERIFY-FAILED: appended line did not read back as the expected daily-brief row (scanned from byte $PRE)" >&2
  exit 5
fi
