# daily-brief

Scheduled morning + evening WhatsApp brief for Christopher. Reads tasks +
work-queue + Google Calendar, formats, and delivers **connection-free** via the
load-bearing wa-sender queue (no WhatsApp plugin, no second Baileys socket).

- **Recipient:** Toper phone JID `$TOPER_WA_JID` (the wa-sender transport surface).
- **Schedule:** 06:00 WIB (morning) + 21:00 WIB (evening), via systemd user timers.
- **Data sources:** `~/.claude/tasks/*.md` + `~/claude/state/work-queue.md` + Google Calendar (`list_events`).
- **Delivery:** append one `{to,message,kind:"daily-brief",ts}` line to the wa-sender queue via `scripts/brief-enqueue.sh`; wa-sender's Baileys daemon delivers.

## Files

- `SKILL.md` - the executable contract (what Claude reads and runs).
- `references/delivery-architecture.md` - the wa-sender path, the outage post-mortem, the paste-ready corrected systemd units (Toper-gated apply), the poke-main alternative, the two-JID reconciliation.
- `references/message-format.md` - the exact de-dashed morning/evening templates + worked examples.
- `references/sources-and-calendar.md` - task/work-queue parse rules + the verified `list_events` contract + graceful degradation.
- `scripts/brief-enqueue.sh` - flock-guarded, append-only, pre-flight-gated enqueue helper.
- `~/.config/systemd/user/daily-brief-{morning,evening}.{service,timer}` - the triggers (edited by the human per delivery-architecture.md).
- `~/.local/share/daily-brief/log/{mode}-YYYY-MM-DD.log` - per-run structured logs.
- `~/.local/share/daily-brief/last-run-{morning,evening}` - date-granularity idempotency lock (one send per mode per WIB day).

## Delivery architecture (read this if a brief did not arrive)

The scheduled run is **headless and connection-free**: it must NOT load the WhatsApp plugin and
must NOT set `WHATSAPP=1`. Doing so forks a second Baileys socket that fights main's always-on
WhatsApp (a `conflict, reconnecting in 5s` flap) and silently drops the send. That exact failure
killed 3+ evening briefs and 2 morning briefs across 2026-06-30 .. 2026-07-02. The fix is the
wa-sender queue path. Full post-mortem + the corrected units: `references/delivery-architecture.md`.

## Install / enable timers

```bash
systemctl --user daemon-reload
systemctl --user enable --now daily-brief-morning.timer
systemctl --user enable --now daily-brief-evening.timer
systemctl --user list-timers | grep daily-brief   # verify next-fire times
```

The `.service` units must be the corrected (connection-free) versions in
`references/delivery-architecture.md`, i.e. NO `Environment=WHATSAPP=1` and NO
`plugin:whatsapp@TopengDev`. Editing them is a Toper-gated step.

## Manual test

```bash
# Dry-run: full pipeline EXCEPT the send; prints the formatted message between DRY RUN banners.
claude --dangerously-skip-permissions -p "/daily-brief morning --dry-run"

# Real run (delivers via wa-sender). --force bypasses the date-lock + validity-window guard.
claude --dangerously-skip-permissions -p "/daily-brief evening"
```

Pre-flight before any real send: `wa-sender.service` active, queue writable, recipient JID exact.
If wa-sender is down, the brief reports `DEGRADED:wa-sender` and does NOT claim it was sent.

## Google Calendar

Already authenticated (`$TOPER_EMAIL`, TZ Asia/Jakarta) and bidirectional to Toper's Infinix
phone. The brief reads events via `mcp__claude_ai_Google_Calendar__list_events`. There is no OAuth
step to do; if a headless run ever loses the token the brief degrades to tasks + threads and still
sends. (The old "Christopher hasn't authenticated Google Calendar yet" note was stale and is retired.)

## Disable / pause

```bash
systemctl --user disable --now daily-brief-morning.timer
systemctl --user disable --now daily-brief-evening.timer
```

## Logs

```bash
journalctl --user -u daily-brief-morning.service -n 50
tail ~/.local/share/daily-brief/log/morning-$(TZ=Asia/Jakarta date +%F).log
```

Each run appends one structured line: `tasks_due`, `open_threads`, `events_today`, `sent`,
`calendar_auth`, `delivery_path`. The success lock writes ONLY after a verified enqueue.

## Invariants

- Send-only. Never reads the inbox, never auto-replies.
- Read-only access to `~/.claude/tasks/*.md` and `~/claude/state/work-queue.md`.
- Single hard-coded recipient (phone JID). Append-only to the wa-sender queue; never truncates it.
- Date-granularity idempotency + a validity-window guard (morning 06:00-10:00, evening 21:00-23:59
  WIB) so a `Persistent=true` catch-up never ships a stale "Good morning" at the wrong hour.
- No em/en dashes in any outgoing text (`feedback_no_long_hyphens`).
