# retro recurrence - dedicated systemd timer + Google Calendar durable fallback

Loaded on demand by `/retro` Step 6. The retro's whole value is **cumulative**
(evaluate next week whether this week's change stuck), so the next run MUST be
armed by a mechanism that **survives a session restart**. This file has the exact
durable mechanisms and the exact reason the old one was broken.

---

## WHY CronCreate is BANNED here (verified no-op)

The old Step 6 armed the weekly evaluation with
`CronCreate(cron="58 9 * * 0", recurring=true, durable=true)`. That is a **verified
no-op for anything beyond the current session**:

- `feedback_time_promise_scheduling` (2026-06-25): "`CronCreate` with `durable:true`
  came back **session-only** ... cron jobs die on session restart regardless of the
  flag ... it FAILS silently for anything days or weeks out."
- `/remindme` MECHANISM TRUTH box: durable "Has no effect ... all jobs are
  session-only, gone when this Claude session ends."
- On-disk proof: `~/claude/notes/retros/` is EMPTY and **no** retro systemd timer
  existed, i.e. the ritual never self-sustained since it shipped 2026-06-11.

The retro reminder is **7 days out**, so the session always restarts before it
fires. `ScheduleWakeup` is also gone (removed from the harness, per remindme HARD
RULE 4) - never reference it. **The only two mechanisms that survive a restart:**
(a) a dedicated systemd timer (the daily-brief pattern), (b) a Google Calendar MCP
event. Use (a) as the real recurrence; (a) is human-gated to install, so the skill
arms (b) as the in-skill bridge meanwhile.

## Ownership (do NOT route through /remindme)

`/remindme` HARD RULE 7: "**NEVER** schedule the daily standup, daily-brief, or
weekly retro through /remindme." Its boundary table: "Weekly Sunday retro | /retro |
Owns its own ritual." So the retro owns its recurrence via its **own** timer. Never
append a retro row to `~/reminders/reminders.jsonl`, never `CronCreate` it.

---

## (a) The dedicated systemd timer (the real, durable recurrence)

Mirrors the verified `daily-brief-morning.{timer,service}` pattern (both live and
firing on this box). It runs `/retro` **headless every Sunday** (durable, catches a
missed tick via `Persistent=true`). The timer RUNS the ritual, it does not merely
remind Toper to run it.

**Install is human-gated + outside the skill dir** - the enhancer cannot write to
`~/.config/systemd/user/`. Ship these to Toper for a one-time install; the skill
only DETECTS the timer (Step 6) and surfaces this if it is absent.

`~/.config/systemd/user/retro.timer`:
```ini
[Unit]
Description=Trigger Weekly Retro at Sunday 20:00 WIB (Asia/Jakarta)

[Timer]
OnCalendar=Sun *-*-* 20:00:00 Asia/Jakarta
Persistent=true
AccuracySec=1min
Unit=retro.service

[Install]
WantedBy=timers.target
```

`~/.config/systemd/user/retro.service`:
```ini
[Unit]
Description=Weekly Retro (Sun 20:00 WIB): evidence review + digest WhatsApp to Christopher
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/home/christopher/claude
Environment=HOME=/home/christopher
Environment=PATH=/home/christopher/.nvm/versions/node/v22.16.0/bin:/home/linuxbrew/.linuxbrew/bin:/home/christopher/.bun/bin:/home/christopher/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=TZ=Asia/Jakarta
Environment=WHATSAPP=1
ExecStart=/home/christopher/.local/bin/claude --dangerously-skip-permissions --dangerously-load-development-channels plugin:whatsapp@TopengDev --dangerously-load-development-channels plugin:attn@s0nderlabs -d channel -p "/retro" --max-turns 60
StandardOutput=append:/home/christopher/.local/share/retro/log/retro-systemd.log
StandardError=append:/home/christopher/.local/share/retro/log/retro-systemd.log
TimeoutStartSec=1800

[Install]
WantedBy=default.target
```

One-time install (Toper runs these once):
```bash
mkdir -p ~/.local/share/retro/log
# (write the two unit files above, then:)
systemctl --user daemon-reload
systemctl --user enable --now retro.timer
systemctl --user list-timers --all | grep -i retro   # verify: next Sun 20:00 WIB
```

Notes on the unit choices (all inherited from the proven daily-brief service):
- `--max-turns 60` + `TimeoutStartSec=1800` (30 min): the retro is a 30-min evidence
  ritual, heavier than daily-brief's `--max-turns 30` / 300s.
- `WHATSAPP=1` is present because the digest goes through the WhatsApp **MCP**
  (same as daily-brief/standup). This is safe here: a scheduled **oneshot that fires
  and exits** is NOT a long-lived concurrent worker (the banned WHATSAPP=1 case is a
  spawned worker that stays alive and splits main's inbound stream). If Toper ever
  wants zero WHATSAPP=1 exposure, the alternative is routing the digest through the
  wa-sender queue instead of the MCP, a larger change, not needed today.
- `OnCalendar=Sun *-*-* 20:00:00 Asia/Jakarta`: Sunday evening closes the week.
  Toper may pick a different hour, edit the one line and `daemon-reload`.

## (b) Google Calendar durable fallback (the in-skill bridge)

Until the timer is installed, the skill arms ONE durable Google Calendar event for
**next Sunday** as the bridge (survives restart, fires a native phone popup nudging
Toper/the loop to run `/retro`). This is the only durable mechanism the skill can
arm itself. Verified tool: `mcp__claude_ai_Google_Calendar__create_event` (required
`summary`,`startTime`,`endTime`; supports `timeZone`,`overrideReminders`,
`description`). Target calendar = default (Toper's primary, `$TOPER_EMAIL`).

**Duplicate guard FIRST** (never double-arm): list next Sunday's events, skip if a
`weekly-retro` event already exists.
```
mcp__claude_ai_Google_Calendar__list_events(
  startTime="<next-Sun>T00:00:00+07:00",
  endTime="<next-Sun>T23:59:59+07:00",
  timeZone="Asia/Jakarta", fullText="weekly-retro")
# -> if any event returned, DO NOT create; report "calendar bridge already armed".
```
Then create (only if none found):
```
mcp__claude_ai_Google_Calendar__create_event(
  summary="weekly-retro: run /retro",
  startTime="<next-Sun>T20:00:00+07:00",
  endTime="<next-Sun>T20:30:00+07:00",
  timeZone="Asia/Jakarta",
  description="Weekly Sunday retro. Run /retro to review the closing week + evaluate whether last week's change stuck.",
  overrideReminders=[{"method":"popup","minutes":0}])
```
Compute `<next-Sun>` off the real clock (never hand-calc):
```bash
# days until the NEXT Sunday (if today is Sunday, jump a full 7 so it is next week)
dow=$(date +%u); add=$(( (7 - dow) % 7 )); [ "$add" -eq 0 ] && add=7
NEXT_SUN=$(date -d "+$add days" +%Y-%m-%d); echo "$NEXT_SUN"
```

**Either/or, never both:** if the systemd timer is present, do NOT arm the calendar
event (the timer runs the retro; a calendar ping on top would double-nudge). Arm the
calendar event ONLY when the timer is absent.

---

## Step 6 decision flow (what the skill does each run)

```
detect: systemctl --user list-timers --all | grep -i retro
  ├─ timer PRESENT  -> report "recurrence armed (retro.timer, next Sun 20:00 WIB)". Done. No calendar.
  └─ timer ABSENT   -> (1) surface the one-time human-gated install (unit content above)
                       (2) arm the Google Calendar bridge for next Sunday (with dup guard)
                       (3) report "timer not installed; calendar bridge armed for <next-Sun>"
dry-run: skip BOTH the detection side effects and the calendar arm; just print what would happen.
```
