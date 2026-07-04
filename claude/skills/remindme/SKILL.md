---
name: remindme
description: Schedule natural-language reminders that fire as WhatsApp DMs to Toper via a durable systemd backend. One-shot + recurring, snooze-via-reply, list/cancel/pause sub-commands, and a ~1-minute test mode. Use when the user says /remindme, "remind me to...", "nudge me...", or wants to schedule a reminder/alert/heads-up.
argument-hint: <natural language reminder | list | cancel <slug> | pause <slug> | resume <slug> | test <content>>
allowed-tools: Bash, Read, CronCreate, CronList, CronDelete, mcp__plugin_whatsapp_whatsapp__send_message, mcp__claude_ai_Google_Calendar__create_event
---

# /remindme - durable WhatsApp reminder scheduler

Turns a natural-language request into a reminder that fires a formatted WhatsApp DM to Toper. This skill is
the canonical, correct implementation of `feedback_time_promise_scheduling`: **every durable time-promise
routes to the systemd jsonl store**, which fires with no Claude session required.

## MECHANISM TRUTH (read this first - the old skill got it backwards)

```
╔══════════════════════════════════════════════════════════════════════════════════════╗
║  DURABLE BACKBONE  =  ~/reminders/reminders.jsonl  +  systemd reminder-check.timer     ║
║  Append a row -> a systemd timer fires it every minute into the wa-sender queue -> WA.  ║
║  Survives session restart / compact / exit / reboot. No session needed. NO 7-day cap.  ║
║  You drive it ONLY through scripts/remindctl (flock-guarded). This is the PRIMARY path.║
║                                                                                        ║
║  CronCreate  =  session-only CONVENIENCE, NOT durable.                                  ║
║  Its own live schema: durable "Has no effect ... all jobs are session-only, gone when  ║
║  this Claude session ends." Use it ONLY for a same-session in-session action, NEVER as  ║
║  the sole mechanism for anything that must survive a restart.                           ║
║                                                                                        ║
║  ScheduleWakeup  =  REMOVED from this harness. Does not exist. Never reference it.      ║
╚══════════════════════════════════════════════════════════════════════════════════════╝
```

Why this matters: the old version of this skill declared "CronCreate is the backbone" and told you to
"always set `durable:true`". That is verified-false - `durable` is a no-op, so every reminder built that
way silently evaporated on the next restart (worst for the highest-stakes far-future ones). The durable
engine has been installed and E2E-verified since 2026-05-24. Full engine contract:
`references/backend-architecture.md`. Tool semantics: `references/tool-facts.md`.

---

## HARD RULES (NEVER / ALWAYS)

1. **NEVER** claim `CronCreate durable:true` persists. The live schema says it has NO effect; all
   CronCreate jobs die when the session ends.
2. **NEVER** use CronCreate as the SOLE mechanism for any reminder that must survive a restart (anything
   beyond the current session / more than ~1 hour out). Those MUST be a jsonl row.
3. **ALWAYS** write a durable reminder as a row appended to `~/reminders/reminders.jsonl` via
   `scripts/remindctl`. NEVER hand-roll an unlocked `jq`/editor edit of the store - the timer rewrites it
   every minute under an `flock`, and an unlocked edit can drop or resurrect a row.
4. **NEVER** reference `ScheduleWakeup` and NEVER list it in `allowed-tools` (removed from the harness).
5. **ALWAYS** deliver to the phone-format JID `$TOPER_WA_JID` for the wa-sender path
   (`target_jid` default). NEVER swap in the LID `...@lid` for this transport (that is the MCP-based
   ritual skills' JID, not this one's).
6. **NEVER** enter the same reminder in BOTH `reminders.jsonl` AND a CronCreate job. The two paths share no
   dedup key; double-entry is the only way to manufacture a duplicate WhatsApp send.
7. **NEVER** schedule the daily standup, daily-brief, or weekly retro through /remindme - they own
   dedicated timers and duplicating them double-messages Toper. Route to their skills (see Boundary table).
8. **ALWAYS** emit one-shot `fire_at` with an explicit `+07:00` offset and `:00` seconds. NEVER a bare,
   ambiguous local time.
9. **ALWAYS** run the pre-flight pipeline-health check before promising delivery. If `wa-sender.service`
   is down, reminders enqueue but silently never deliver.
10. **ALWAYS** re-read the store after writing (verify-after-write) and show the concrete next fire.
11. For a `>~7-days-out` or high-stakes commitment, **ALSO** create a Google Calendar event (durable,
    phone popup) per `feedback_time_promise_scheduling`.
12. **NEVER** set `WHATSAPP=1` anywhere - the durable path goes through the wa-sender queue, not the Claude
    WA MCP, and `WHATSAPP=1` is main-session-only.
13. **NEVER** kill or restart `wa-sender.service` to "fix" delivery - it is load-bearing; restart is
    Toper-gated (`feedback_wa_sender_load_bearing`).

---

## Constants

- **Toper's WhatsApp JID (wa-sender transport):** `$TOPER_WA_JID` - pre-verified, phone-format,
  the engine's `REMINDER_JID` default. Send directly, no lookup.
- **Store:** `~/reminders/reminders.jsonl` (env `REMINDER_STORE`). Driven only via `scripts/remindctl`.
- **Helper:** `~/.claude/skills/remindme/scripts/remindctl` (flock-guarded CRUD; `--help` for usage).
- **Timezone:** host + engine are WIB (Asia/Jakarta, UTC+7, no DST). Write times in WIB directly, no
  conversion. Confirm with `date +%Z` if ever unsure.
- **day-of-week in cron:** `0` or `7` = Sunday, `1` = Mon ... `6` = Sat (matches the engine).

---

## Step 0: parse the invocation

Read `$ARGUMENTS` and classify:

| If `$ARGUMENTS`... | Intent |
|---|---|
| starts with `list` | -> **LIST** |
| starts with `cancel <slug>` | -> **CANCEL** |
| starts with `pause <slug>` / `resume <slug>` | -> **PAUSE / RESUME** |
| starts with `test ` | -> **TEST MODE** (jsonl one-shot ~70 s out) |
| anything else | -> **CREATE** a reminder |
| empty | ask: "What should I remind you about, and when?" |

---

## Step 1 (CREATE): get the real clock

Never hand-calculate dates. Anchor to the clock:
```bash
date '+now: %Y-%m-%d %H:%M:%S %Z (epoch %s, dow %u)'
```

## Step 2 (CREATE): horizon -> mechanism decision gate

Pick the mechanism from the horizon. **The jsonl store is the primary path in every row below** - CronCreate
appears only as an explicit opt-in convenience, never as the durability guarantee.

| Horizon / shape | Mechanism (primary) | Notes |
|---|---|---|
| **(a)** now -> ~55 min, one-shot | **jsonl one-shot** (`remindctl add-once`) | Default. Durable even if the session dies. Use a CronCreate convenience *in addition* only if you also want an in-session action at fire time. |
| **(b)** hours -> days, or ANY pinned future date/time | **jsonl one-shot**, MANDATORY | The old CronCreate path would silently die before it fired. |
| **(c)** `>~7 days` out OR high-stakes / irreversible | **jsonl one-shot + Google Calendar event** | Belt-and-suspenders per `feedback_time_promise_scheduling`. |
| **(d)** recurring ("every ...") | **jsonl `kind:cron`** (`remindctl add-cron`) | No 7-day cap (unlike CronCreate recurring), no auto-renew needed. |
| **(e)** test / smoke fire | **jsonl one-shot at `now + ~70 s`** | The every-minute timer fires it within the minute. Replaces the dead ScheduleWakeup test mode. |

**Ambiguous time** ("later", "soon", "this evening" with no hour) -> do NOT guess. Ask for a concrete time.
Committing to a vague time is an anti-pattern; one concrete mechanism per reminder.

**Past time** ("at 8am" when it is already 09:00) -> assume the next occurrence (tomorrow) and say so.

### Early-nudge (approximate clock times)
When Toper gives an approximate clock time, land it **1-2 minutes early** so it arrives a touch early rather
than late:
- "9am" -> `08:58`  ·  "7am" -> `06:58`  ·  "noon" -> `11:58`  ·  "every hour" -> minute `37`

Use the exact minute (`:00`/`:30`) only when he says "sharp"/"exactly" or is coordinating with a meeting.

> Rationale note: on this LOCAL systemd timer there is no shared-fleet collision (that concern is specific to
> the CronCreate *cloud* path). Here the early-nudge is purely a "better early than late" UX choice - but
> keep it, it is the right default.

## Step 3 (CREATE): write the reminder

Compute the time field with `date -d` (never by hand), then append via `remindctl`. `<slug>` is a short
kebab-case label from the content (`take-bread-out`, `pay-rent`, `call-mom`); it IS the native id used by
list/cancel. If `remindctl` rejects a slug as a live duplicate, retry with a `-2` suffix.

### Recipe A - durable one-shot (paths a / b / c)
```bash
RC=~/.claude/skills/remindme/scripts/remindctl
FIRE_AT=$(date -d "+30 minutes" +"%Y-%m-%dT%H:%M:00+07:00")   # or: date -d "tomorrow 08:58" / "2026-07-30 11:58"
"$RC" add-once --id take-bread-out --fire-at "$FIRE_AT" \
  --content "take the bread out" --schedule-human "today at ~2:30pm WIB"
```
`fire_at` MUST carry the explicit `+07:00` and `:00` seconds. `date -d` with the format string above does
both. The engine fires when `now >= fire_at`, checked at each minute tick.

### Recipe B - durable recurring (path d)
```bash
RC=~/.claude/skills/remindme/scripts/remindctl
"$RC" add-cron --id weekly-planning --cron "58 6 * * 0" \
  --content "weekly planning" --schedule-human "every Sunday 07:00 WIB"
```
5-field WIB cron `M H DOM MON DOW`, off-`:00`/`:30` minute, `dow 0/7 = Sun`. No auto-renew clause - the
engine loops forever with no 7-day cap.

### Recipe C - test fire (path e)
```bash
RC=~/.claude/skills/remindme/scripts/remindctl
FIRE_AT=$(date -d "+70 seconds" +"%Y-%m-%dT%H:%M:00+07:00")
"$RC" add-once --id smoke-test --fire-at "$FIRE_AT" \
  --content "smoke test" --schedule-human "test (~1 min)"
```

### Optional - CronCreate convenience (rare)
Only when you deliberately want an **in-session action** at fire time AND the session is certainly alive AND
losing it on restart is acceptable. Session-only. Recipe + marker in `references/tool-facts.md`. This is
NEVER the durability guarantee, and NEVER used together with a jsonl row for the same reminder (rule 6).

### `>7 days` / high-stakes - also add the calendar event (path c)
```
mcp__claude_ai_Google_Calendar__create_event(
  summary="<content>", startTime="<ISO>", endTime="<ISO +~15min>",
  timeZone="Asia/Jakarta", overrideReminders=[{"method":"popup","minutes":0}])
```
Target `$TOPER_EMAIL`. This is a SECOND durable layer on top of the jsonl row, not a replacement.

## Step 4 (CREATE): pre-flight + verify-after-write

**Pre-flight (all three must pass; else print `DEGRADED:<which>` and warn Toper before confirming):**
```bash
systemctl --user is-active reminder-check.timer   # expect: active   (NOT the oneshot .service - it is inactive between ticks)
systemctl --user is-active wa-sender.service        # expect: active   (down = enqueue-but-never-deliver)
test -w ~/reminders/reminders.jsonl && echo store-writable
```

**Verify-after-write (mandatory):**
```bash
~/.claude/skills/remindme/scripts/remindctl get --id <slug> --json
```
Assert: the row is present, `status` is `pending`/`active`, and `next_fire` is a concrete future ISO WIB
datetime. If the row is missing or unparseable, ABORT and report (do not confirm success). `remindctl`
already computes `next_fire` using the engine's exact firing rules, so use that as the concrete next fire.

## Step 5 (CREATE): confirm (fixed contract)

Reply in-session with this exact block (do NOT WhatsApp Toper now - the WA message IS the reminder, sent
only when it fires):
```
Reminder set - <slug>
  Topic:     <content>
  Mechanism: durable-jsonl (systemd timer, fires with no session)   [or: + gcal | cron-convenience session-only]
  Next fire: <concrete ISO WIB datetime from remindctl next_fire>
  Pipeline:  timer active, wa-sender active, store writable          [or: DEGRADED:<which> - warn]
  Cancel:    /remindme cancel <slug>
```

---

## Sub-commands (all via remindctl - flock-guarded)

**list**
```bash
~/.claude/skills/remindme/scripts/remindctl list        # add --json for machine output, --all to include done
```
Shows each live reminder (`pending`/`active`/`paused`): slug, kind, status, next fire, schedule. Append the
caveat: *"(Any session-only CronCreate convenience jobs are separate - check `CronList` for those.)"*

**cancel <slug>**
```bash
~/.claude/skills/remindme/scripts/remindctl cancel --id <slug>   # removes all rows with that id (exit 3 if none)
```
On no match, run `remindctl list` and show the available slugs so Toper can retry.

**pause <slug> / resume <slug>**
```bash
~/.claude/skills/remindme/scripts/remindctl pause  --id <slug>   # status -> paused (disable, keep the row)
~/.claude/skills/remindme/scripts/remindctl resume --id <slug>   # cron -> active, once -> pending
```

**snooze (inbound WhatsApp reply)**
The engine's reminder body is byte-fixed (`⏰ REMINDER / Topic: / Scheduled:`) and carries NO snooze line -
snooze is a main-session capability, not something advertised in the message. When Toper replies
**"snooze <duration>"** on WhatsApp shortly after a fire (roughly within 10 min), the reply arrives as a
`<channel source="...whatsapp...">` event in the main session (needs main alive with `WHATSAPP=1`):
1. Parse `<duration>`.
2. Append a FRESH one-shot jsonl row at `now + <duration>` with a `-snooze` slug suffix (Recipe A). Do NOT
   alter a recurring row's cadence - a snooze is one extra delayed fire, not a schedule change.
3. Reply on WhatsApp: `⏰ Snoozed. I will remind you again in <duration>.`

---

## Boundary / routing (do NOT double-schedule)

| Want | Owner | Why not /remindme |
|---|---|---|
| Ad-hoc "remind me to X at T" | **/remindme** (this skill) | - |
| Morning/evening daily brief | **/daily-brief** (own systemd timers) | Duplicating collides with `daily-brief-morning/evening`. |
| Twice-daily standup | **/standup** | Deliberately kept OUT of the reminder store to avoid double-send (see report.md). |
| Weekly Sunday retro | **/retro** | Owns its own ritual. |
| Recurring cloud routine (runs without your machine) | **/schedule** | Cloud cron; different tier. |
| In-session recurring loop | **/loop** | Session-scoped polling. |
| Passive to-do list (no alarm) | **/tasks** | A list entry is not a scheduled fire. |

If Toper asks /remindme to schedule a standup/brief/retro, route him to the owning skill instead of adding a
second timer.

---

## Failure playbooks (condensed - full runbooks in references/failure-playbooks.md)

- **No reminders arriving:** `systemctl --user is-active wa-sender.service`. If inactive, rows enqueue but
  never deliver (silent). Surface to Toper; NEVER kill/restart wa-sender (Toper-gated). Queued rows persist.
- **Nothing fires at all:** check the **timer** (`systemctl --user status reminder-check.timer`), not the
  oneshot service (it is `inactive` between ticks by design). `journalctl --user -u reminder-check.service`.
- **Missed while logged out:** `Linger=no` -> units start on login. `Persistent=true` catches up pending
  one-shots; recurring matches during the logged-out window are lost. Escape hatch (Toper-gated):
  `loginctl enable-linger christopher`.
- **Duplicate send:** root cause is double-entry (jsonl AND CronCreate for one reminder). Keep the jsonl row,
  `CronDelete` the session job.
- **Bad row:** the engine skips one unparseable line with a `WARN` and fires the rest; `remindctl` preserves
  it. Validate with the snippet in the failure-playbooks reference.

---

## Worked examples (input -> dispatch)

Assume now = Fri 2026-07-03 08:05 WIB.

1. `/remindme test smoke check`
   -> TEST. `FIRE_AT=$(date -d "+70 seconds" +"%Y-%m-%dT%H:%M:00+07:00")` ->
   `remindctl add-once --id smoke-check --fire-at "$FIRE_AT" --content "smoke check" --schedule-human "test (~1 min)"`.
   Pre-flight, verify, confirm "next fire ~08:06:00, durable-jsonl".

2. `/remindme in 30 minutes take the bread out`
   -> jsonl one-shot (a). `FIRE_AT=$(date -d "+30 minutes" +"%Y-%m-%dT%H:%M:00+07:00")` -> `add-once --id take-bread-out`.

3. `/remindme in 2 hours call the bank`
   -> jsonl one-shot (b). `date -d "+2 hours" +"%Y-%m-%dT%H:%M:00+07:00"` -> `add-once --id call-bank`.

4. `/remindme tomorrow at 9am do the standup prep`
   -> jsonl one-shot (b), early-nudge 08:58. `date -d "tomorrow 08:58" +"%Y-%m-%dT%H:%M:00+07:00"` ->
   `add-once --id standup-prep --schedule-human "tomorrow at 9am"`. (Note: this is prep, NOT the standup
   ritual itself - that stays with /standup.)

5. `/remindme every Monday at 7am weekly planning`
   -> jsonl cron (d). `add-cron --id weekly-planning --cron "58 6 * * 1" --schedule-human "every Monday at 7am"`.

6. `/remindme every weekday at 9am check the deploy queue`
   -> jsonl cron (d). `--cron "58 8 * * 1-5"`.

7. `/remindme every hour drink water`
   -> jsonl cron (d). `--cron "37 * * * *"`.

8. `/remindme on July 30 at noon submit the quarterly report`
   -> jsonl one-shot, 27 days out = high-stakes (c). `date -d "2026-07-30 11:58" +"%Y-%m-%dT%H:%M:00+07:00"`
   -> `add-once --id submit-quarterly-report` **AND** a Google Calendar event (Asia/Jakarta, popup at start).

9. `/remindme list`
   -> `remindctl list` + the CronList caveat.

10. `/remindme cancel weekly-planning`
    -> `remindctl cancel --id weekly-planning` -> confirm the removed count; if none, list available slugs.

---

## Edge cases & rules

- **Empty content** -> ask what to be reminded about.
- **Ambiguous time** -> ask for a concrete time; never emit an untethered guess.
- **Don't double-send / don't double-enter** -> one mechanism per reminder (rule 6); the WA message fires
  only from the timer, never at creation.
- **Verify-after-write is not optional** -> a confirmed reminder must be a re-read, present, parseable row.
- **Slug reuse** -> `remindctl` allows reusing a slug whose only prior instance is `done`; a `cancel` of a
  reused slug removes the historical `done` row too, so prefer a fresh distinct slug.
- **Stay honest about limits** -> durable reminders survive restarts (that is the whole point); a CronCreate
  convenience does not; recurring matches during a logged-out boot are lost. Never imply otherwise.
