---
name: remindme
description: Schedule natural-language reminders that fire as WhatsApp DMs to Toper. Supports one-shot + recurring schedules, snooze-via-reply, list/cancel sub-commands, and a 60-second test mode. Use when the user says /remindme, "remind me to…", "nudge me…", or wants to schedule a reminder/alert/heads-up.
argument-hint: <natural language reminder | list | cancel <slug-or-id> | cancel all | test in 60 seconds <content>>
allowed-tools: Bash, Read, ScheduleWakeup, CronCreate, CronList, CronDelete, mcp__plugin_whatsapp_whatsapp__send_message
---

# /remindme — WhatsApp Reminder Scheduler

Turns a natural-language request into a scheduled job that fires a formatted WhatsApp reminder to Toper. `CronCreate` is the backbone for every real reminder (one-shot + recurring); `ScheduleWakeup` is used only for the 60-second test mode; `CronList`/`CronDelete` power list/cancel.

## Hard facts about the scheduling tools (verified — do not guess)

| Tool | Lifetime | Precision | Listable/Cancellable | Use for |
|---|---|---|---|---|
| `CronCreate` (recurring:false) | auto-deletes after it fires | minute | YES (via CronList/CronDelete) | **every one-shot reminder** (short or long) |
| `CronCreate` (recurring:true) | repeats; **auto-expires after 7 days** | minute | YES | recurring reminders (+ auto-renew) |
| `durable: true` | persists to `.claude/scheduled_tasks.json`, survives restart | — | YES | every reminder (set it always) |
| `ScheduleWakeup` | in-session; clamped to **[60, 3600] s** | seconds | **NO** (no list/cancel API) | **test mode only** (60 s sub-minute fire) |

**Why CronCreate is the backbone (verified):** `CronCreate`'s own spec markets it for *"both recurring schedules and one-shot reminders"* ("remind me to check X tomorrow"). `ScheduleWakeup`'s spec, by contrast, describes resuming *"/loop dynamic mode"* and its `prompt` is "the /loop input to fire on wake-up" — it is loop-pacing, not a general reminder scheduler, it can't be listed or cancelled, and it dies on restart. So **all real reminders use CronCreate** (minute precision is plenty; a one-shot can be pinned to the very next minute for "remind me in a few minutes"). `ScheduleWakeup` is used **only** for the throwaway 60-second test mode, where sub-minute timing matters and listability does not.

Critical mechanics:
1. **Cron is 5-field LOCAL time:** `minute hour day-of-month month day-of-week`. This host runs **WIB (UTC+7)** — Toper's timezone — so write times in WIB directly. No conversion. (Always confirm with `date +%Z` if unsure.)
2. **A fire enqueues a PROMPT, not a message.** When the job fires, *this Claude session executes the prompt*. The prompt is what tells Claude to send the WhatsApp. So the scheduled prompt must be fully self-contained: recipient JID + exact message body + the `[REMINDME …]` marker + (for recurring) the auto-renew instruction.
3. **Jobs fire only while the session is idle and alive.** Create reminders from the long-lived command-center (main) session. Use `durable: true` on cron jobs so they survive a restart. `ScheduleWakeup` jobs are in-memory only — they die on restart and cannot be listed or cancelled.
4. **day-of-week:** `0` or `7` = Sunday, `1` = Monday … `6` = Saturday.

## Constants

- **Toper's WhatsApp JID:** `62817712289@s.whatsapp.net` (pre-verified SUPERUSER number — send directly, no lookup needed).
- **Marker:** every cron job created here gets a prompt beginning with `[REMINDME id=<slug>]`. The slug is a short kebab-case label derived from the reminder content (e.g. `weekly-retro`, `standup`, `call-mom`). This makes `list` and `cancel` work even after auto-renew rotates the underlying job id.

---

## Step 0: Parse the invocation

Read `$ARGUMENTS` and classify intent:

| If `$ARGUMENTS`… | Intent |
|---|---|
| starts with `list` | → **LIST** (jump to "Sub-command: list") |
| starts with `cancel all` | → **CANCEL ALL** |
| starts with `cancel <x>` | → **CANCEL** one |
| starts with `test ` | → **TEST MODE** (short-circuit, ignore stated duration) |
| anything else | → **CREATE** a reminder |
| empty | ask: "What should I remind you about, and when?" |

---

## Step 1 (CREATE): get the current clock

Always anchor to the real clock — never hand-calculate dates. Run:

```bash
date '+now: %Y-%m-%d %H:%M:%S %Z (epoch %s, dow %u)'
```

You'll compute cron fields and delays relative to this.

## Step 2 (CREATE): determine the schedule type + compute fields

Decide the dispatch path from the parsed time expression:

### A. TEST MODE — `/remindme test in 60 seconds <content>`
Short-circuit **all** time parsing. Always schedule exactly 60 seconds out via `ScheduleWakeup`, regardless of any duration the user typed. (The phrase "in 60 seconds" is cosmetic — test mode is always 60 s.) Go to Step 3, path = ScheduleWakeup, delaySeconds = 60. This is the **only** path that uses ScheduleWakeup.

### B/C. Any one-shot (short OR long, OR a pinned date) → `CronCreate` (recurring:false, durable:true)
e.g. "in 30 minutes", "in 2 hours", "tonight at 9pm", "tomorrow at 9am", "on May 30 at noon".
Compute the pinned fields with `date -d` so you never miscalculate a minute/hour/day/month rollover:
```bash
# "in 30 minutes"
date -d "+30 minutes"   +"%-M %-H %-d %-m"      # -> "minute hour dom month"
# "in 2 hours"
date -d "+2 hours"      +"%-M %-H %-d %-m"
# "tomorrow at 9am"  (early-nudge handled below)
date -d "tomorrow"      +"%-d %-m"              # -> "dom month", set minute/hour yourself
# "on May 30"
date -d "2026-05-30"    +"%-d %-m"
```
Assemble cron `M H DOM MON *` with `recurring:false, durable:true`. Go to Step 3.
Minute precision is fine even for "in a few minutes" — pin to the next minute and it fires within ~60 s. Using CronCreate (not ScheduleWakeup) here is deliberate: the reminder then shows up in `/remindme list`, is cancellable, and survives a restart.

### D. Recurring → `CronCreate` (recurring:true, durable:true, + auto-renew)
e.g. "every day at 7am", "every Monday at 7am", "every weekday at 9am", "every hour", "every 15 minutes".
Build the recurring cron expression (examples in the table below). Set `recurring:true, durable:true`. The fire-prompt MUST include the auto-renew clause (Step 4) so the job re-arms past the 7-day cap. Go to Step 3.

### Early-nudge rule (applies to B/C/D when the user names a clock time)
A reminder that arrives late is useless, and the cron tool warns that everyone's "9am" collides on `0 9`. So when the user gives an approximate clock time, fire **1–2 minutes early** on an off-:00/:30 minute:
- "9am" → minute `58`, hour `8` (i.e. 08:58)
- "7am" → minute `58`, hour `6`
- "noon" → minute `58`, hour `11`
- "every hour" → minute `37` (not `0`)
Only land on `:00`/`:30` exactly if the user says "sharp", "exactly", or is coordinating with a specific meeting time.

### Cron quick-reference (WIB)

| Request | cron | recurring | durable |
|---|---|---|---|
| every day at 7am | `58 6 * * *` | true | true |
| every Monday at 7am | `58 6 * * 1` | true | true |
| every weekday at 9am | `58 8 * * 1-5` | true | true |
| every Sat & Sun at 10am | `58 9 * * 0,6` | true | true |
| every hour | `37 * * * *` | true | true |
| every 15 minutes | `*/15 * * * *` | true | true |
| tomorrow at 9am (one-shot) | `58 8 <tom_dom> <tom_mon> *` | false | true |
| on May 30 at noon (one-shot) | `58 11 30 5 *` | false | true |

## Step 3: build the fire-prompt and schedule

The **fire-prompt** is the text the job runs when it fires. Build it from this template:

```
[REMINDME id=<slug>] Send a WhatsApp message via mcp__plugin_whatsapp_whatsapp__send_message
to 62817712289@s.whatsapp.net with EXACTLY this body (preserve the line breaks):

⏰ REMINDER

Topic: <content>
Scheduled: <human-readable original schedule, e.g. "every Monday at 7am" or "today at 9pm">

(reply "snooze <duration>" within 5 min to postpone)
<AUTO_RENEW_CLAUSE>
```

- `<content>` = the thing to be reminded of, verbatim from the user.
- `<slug>` = short kebab-case label (e.g. `weekly-retro`).
- `<human-readable original schedule>` = how the user phrased it, for the "Scheduled:" line (decision A).
- `<AUTO_RENEW_CLAUSE>`:
  - **Recurring jobs only**, append:
    ```
    AFTER sending, immediately call CronCreate again with the IDENTICAL cron, recurring:true,
    durable:true, and this same prompt — this re-arms the 7-day expiry window so the reminder
    never silently dies.
    ```
  - **One-shot jobs**: omit it (leave blank).

Then dispatch on the path chosen in Step 2:
- **ScheduleWakeup** (path A, test mode only): `ScheduleWakeup(delaySeconds=60, reason="[REMINDME] <slug>", prompt=<fire-prompt>)`.
- **CronCreate** (paths B/C one-shot, D recurring): `CronCreate(cron=<expr>, prompt=<fire-prompt>, recurring=<false|true>, durable=true)`. Capture the returned job id.

## Step 4: confirm immediately (decision D)

Right after scheduling succeeds, reply to the user in the session with a confirmation:

```
✅ Reminder set — <slug>
   Topic:     <content>
   Fires:     <human schedule>  (next: <concrete next datetime, computed via `date -d`>)
   Mechanism: <ScheduleWakeup 60s | one-shot cron #<id> | recurring cron #<id>, auto-renew on>
   Cancel:    /remindme cancel <slug>      (test-mode 60 s reminders: not cancellable)
```

Do NOT also WhatsApp Toper at creation time — the WA message is the *reminder itself*, sent only when the job fires.

---

## Sub-command: list

```
CronList()
```
Filter to jobs whose prompt contains `[REMINDME`. For each, show: slug (parsed from `id=<slug>`), the cron expression rendered human-readable, recurring vs one-shot, and the job id. If none match, say "No scheduled reminders." Always append the caveat: *"(Test-mode 60 s reminders run on ScheduleWakeup and aren't listed — they have no query API.)"*

## Sub-command: cancel <slug-or-id>

1. `CronList()`, filter to `[REMINDME` jobs.
2. Match the user's argument against either the `id=<slug>` label **or** the raw job id. Because auto-renew rotates ids, **a slug may map to more than one live job** — cancel ALL matches.
3. `CronDelete(id=…)` for each match.
4. Confirm what was cancelled. If no match: list the available reminder slugs so the user can retry.

## Sub-command: cancel all

`CronList()` → for every job whose prompt contains `[REMINDME`, call `CronDelete(id=…)`. Report the count removed. (Test-mode 60 s reminders run on ScheduleWakeup and can't be cancelled.)

---

## Handling snooze replies (decision B)

The reminder body invites `reply "snooze <duration>"`. WhatsApp inbound replies surface in the command-center session as `<channel source="...whatsapp...">` events. When you see Toper reply with **"snooze <duration>"** (e.g. "snooze 1h", "snooze 30m", "snooze 2 hours") shortly after a reminder fired:

1. Parse `<duration>` → seconds.
2. Re-schedule the **same content** as a fresh one-shot via `CronCreate(recurring:false, durable:true)` pinned to now + `<duration>` (`date -d "+<duration>" +"%-M %-H %-d %-m"`). Reuse the same `<slug>` with a `-snooze` suffix so it's traceable.
3. Reply on WhatsApp: `⏰ Snoozed — will remind again in <duration>.`

A snooze does **not** cancel a recurring reminder's normal cadence; it just adds one extra delayed fire.

---

## Worked examples (input → dispatch)

Assume "now" = Sun 2026-05-24 05:40 WIB.

1. `/remindme test in 60 seconds smoke test`
   → TEST MODE. `ScheduleWakeup(delaySeconds=60, reason="[REMINDME] smoke-test", prompt="[REMINDME id=smoke-test] Send WA to 62817712289@s.whatsapp.net: ⏰ REMINDER / Topic: smoke test / Scheduled: test (60s) …")`. Confirm "fires in 60s, not listable".

2. `/remindme in 30 minutes take the bread out`
   → one-shot → `date -d "+30 minutes" +"%-M %-H %-d %-m"` → e.g. `10 6 24 5` → `CronCreate(cron="10 6 24 5 *", recurring=false, durable=true, prompt="[REMINDME id=take-bread-out] …")`. Listable + cancellable.

3. `/remindme in 2 hours call the bank`
   → one-shot ≥ 1h → `date -d "+2 hours" +"%-M %-H %-d %-m"` → e.g. `40 7 24 5` → `CronCreate(cron="40 7 24 5 *", recurring=false, durable=true, prompt="[REMINDME id=call-bank] …")`.

4. `/remindme tomorrow at 9am do standup`
   → one-shot, pinned date. `date -d "tomorrow" +"%-d %-m"` → `25 5`; early-nudge 9am→08:58 → `CronCreate(cron="58 8 25 5 *", recurring=false, durable=true, prompt="[REMINDME id=standup] …Scheduled: tomorrow at 9am…")`.

5. `/remindme every Monday at 7am weekly retro`
   → recurring → `CronCreate(cron="58 6 * * 1", recurring=true, durable=true, prompt="[REMINDME id=weekly-retro] …Scheduled: every Monday at 7am… <AUTO_RENEW_CLAUSE>")`.

6. `/remindme every weekday at 9am check the deploy queue`
   → recurring → `cron="58 8 * * 1-5"`, recurring=true, durable=true, auto-renew on.

7. `/remindme every hour drink water`
   → recurring → `cron="37 * * * *"`, recurring=true, durable=true, auto-renew on.

8. `/remindme on May 30 at noon submit the report`
   → one-shot pinned → `cron="58 11 30 5 *"`, recurring=false, durable=true.

9. `/remindme list`
   → CronList → show all `[REMINDME` jobs + the ScheduleWakeup caveat.

10. `/remindme cancel weekly-retro`
    → CronList → match `id=weekly-retro` (all instances) → CronDelete each → confirm.

---

## Edge cases & rules

- **Ambiguous time** ("later", "soon", "this evening" with no hour) → ask for a concrete time rather than guessing.
- **Past time** ("at 5am" when it's already 05:40) → assume the next occurrence (tomorrow) and say so in the confirmation.
- **Empty content** → ask what to be reminded about.
- **Don't double-send.** The WhatsApp message fires only from the scheduled prompt, never at creation.
- **Verify after firing.** When a reminder fires, confirm the WhatsApp `send_message` returned success; if it errored, retry once and surface the failure rather than silently dropping the reminder.
- **Recurring durability.** Always set `durable:true` on cron reminders so a session restart doesn't wipe them; auto-renew handles the 7-day cap while the session lives, durability handles restarts.
- **Stay honest about test-mode limits.** Real reminders (CronCreate) are always listable/cancellable, including short "in a few minutes" ones. Only the 60 s **test-mode** reminder (ScheduleWakeup) cannot be listed or cancelled — never imply otherwise.
