---
name: daily-brief
description: 'Send Christopher his scheduled daily brief on WhatsApp. Invoked as "/daily-brief morning" or "/daily-brief evening" (optionally "--dry-run" / "--force"). Reads ~/.claude/tasks/*.md + ~/claude/state/work-queue.md + Google Calendar, formats, and delivers CONNECTION-FREE via the wa-sender queue to Toper phone JID $TOPER_WA_JID. Fired by systemd timers at 06:00 + 21:00 WIB.'
argument-hint: morning|evening [--dry-run] [--force]
allowed-tools: Read, Glob, Bash, mcp__claude_ai_Google_Calendar__list_events
---

# Daily Brief - scheduled morning + evening WhatsApp brief

One-shot skill. It compiles tasks + work-queue + calendar into a scannable brief and delivers it to
Toper connection-free, then exits. It runs headless from systemd timers (06:00 + 21:00 WIB) or by
hand. It is the SCHEDULED ritual; `/standup` is the on-demand counterpart + the accountability-body
generator (see Composition + Boundary below).

## MECHANISM TRUTH (read first - the old skill got delivery backwards)

```
+==============================================================================================+
|  DELIVERY = compose headless, then APPEND ONE LINE to the wa-sender queue. NO WhatsApp plugin.|
|  ~/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl                          |
|    {"to":"$TOPER_WA_JID","message":"<brief>","kind":"daily-brief","ts":<epoch>}   |
|  wa-sender.service (always-on Bun+Baileys, ONE linked device) drains it -> WhatsApp -> Toper.  |
|  This is connection-free: it never opens a WhatsApp socket, so it CANNOT conflict with main.   |
|  Drive it ONLY via scripts/brief-enqueue.sh (flock-guarded, append-only, pre-flight + verify). |
|                                                                                                |
|  THE OLD PATH (whatsapp MCP send from a WHATSAPP=1 + plugin:whatsapp systemd unit) IS DEAD.    |
|  It forked a 2nd Baileys that fought main -> "conflict, reconnecting in 5s" -> 3+ nights of    |
|  silently-lost briefs (Jun 30 / Jul 1 / Jul 2). Root cause + corrected units:                  |
|  references/delivery-architecture.md. The whatsapp MCP is valid ONLY inside the live MAIN       |
|  session (the poke-main alternative), NEVER from the headless scheduled run.                    |
+==============================================================================================+
```

Full mechanism + the paste-ready (Toper-gated) systemd fix: `references/delivery-architecture.md`.

---

## HARD RULES (NEVER / ALWAYS)

1. **NEVER** set `WHATSAPP=1` in the daily-brief service or any launch context. It is
   main-session-only: it steals main's inbound WhatsApp feed AND is one half of the second-Baileys
   conflict (`feedback_whatsapp_single_session_rule.md`).
2. **NEVER** load `plugin:whatsapp@TopengDev` (or any WhatsApp MCP) in the scheduled headless run.
   Deliver connection-free through the wa-sender queue. The whatsapp MCP send path is valid ONLY
   when this skill runs inside the live main session (poke-main alternative).
3. **NEVER** kill or restart `wa-sender.service` to "fix" delivery. It is load-bearing for
   signal-trader + reminders; restart is Toper-gated (`feedback_wa_sender_load_bearing.md`).
4. **NEVER** truncate, shrink, or rewrite the wa-sender queue file. APPEND-ONLY. The relay tracks a
   byte offset; a shrink drops the next real notification (`reference_signal_trader_notif_bridge.md`).
5. **ALWAYS** run the pre-flight before promising delivery (wa-sender active + queue writable +
   recipient JID == the constant). `brief-enqueue.sh` enforces all three; if it exits non-zero,
   surface `DEGRADED` and do NOT claim sent, do NOT write the success lock.
6. **ALWAYS** deliver only to the exact phone JID `$TOPER_WA_JID` (the proven wa-sender
   surface). NEVER any other JID; NEVER shove an `@lid` through wa-sender (unverified path).
7. **NEVER** use an em dash `—` or en dash `–` in ANY outgoing brief text
   (`feedback_no_long_hyphens`). Use a hyphen, comma, colon, or middot. Grep the composed body for
   `—`/`–` before enqueue.
8. **ALWAYS** use DATE-granularity idempotency (one send per mode per WIB day) AND suppress
   out-of-window catch-up fires (morning valid 06:00-10:00, evening 21:00-23:59 WIB). NEVER let a
   `Persistent=true` catch-up ship a stale "Good morning" at the wrong hour.
9. **ALWAYS** verify-after-write: `brief-enqueue.sh` re-reads the just-appended region and asserts OUR
   exact line landed (matched by kind + JID + ts, robust to interleaved producer rows) before it exits 0.
   Write the success lock + `sent=yes` log line ONLY on that verified exit 0.
10. **NEVER** double-schedule the brief through `/remindme`, `/standup`, or `/retro`. Each owns its
    own timers; route those requests to the owning skill (Boundary table).
11. **ALWAYS** anchor all time math to `TZ=Asia/Jakarta date` (WIB, UTC+7, no DST). NEVER
    hand-calculate a date, weekday, or window bound.
12. **NEVER** modify `~/.claude/tasks/*.md`, `~/claude/state/work-queue.md`, or any other producer's
    line in the wa-sender queue. Read-only except the skill's own single append + its own state files.
13. **ALWAYS** read events via `mcp__claude_ai_Google_Calendar__list_events` (it exists; the calendar
    is authenticated). NEVER repeat the retired "no list-events tool exists" claim. DO degrade
    gracefully (tasks + work-queue only, one note, still send) if a headless run lacks the token.
14. **NEVER** re-fire the legacy OAuth-prompt bootstrap. The calendar is authenticated and the
    `calendar-oauth-sent` sentinel already exists. No OAuth URL / "link calendar" line, ever.
15. **ALWAYS** send even on an empty day (honest "clear day" / "clear night"). Never pad, never
    silently skip (`feedback_no_yesman_sugarcoat`).

---

## Constants

- **Recipient JID (wa-sender transport):** `$TOPER_WA_JID` (phone-format, pre-verified,
  the proven wa-sender surface). Both this and the legacy `$TOPER_WA_LID` reach Toper; the
  connection-free path uses phone JID. Reconciliation: `references/delivery-architecture.md`.
- **wa-sender queue:** `~/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl`
  (append-only; schema `{to,message,kind,ts}`, `ts` numeric epoch).
- **Enqueue helper:** `~/.claude/skills/daily-brief/scripts/brief-enqueue.sh` (flock-guarded CRUD-of-one;
  `--help` for usage). This is the ONLY sanctioned way to write the queue.
- **State dir:** `~/.local/share/daily-brief/` holds `last-run-{morning,evening}` (date lock),
  `log/`, `calendar-oauth-sent` (retired sentinel, leave in place).
- **Timezone:** `Asia/Jakarta` (WIB = UTC+7, no DST). Do ALL time math in WIB.
- **Timers:** `daily-brief-morning.timer` (06:00 WIB) + `daily-brief-evening.timer` (21:00 WIB),
  both `Persistent=true`. Units live at `~/.config/systemd/user/` (edited by the human, not the skill).

---

## Step 0 - parse arguments

`$ARGUMENTS` is `morning`, `evening`, plus optional `--dry-run` and/or `--force`.

- `mode` = first token (`morning` | `evening`). If missing/unrecognized, print
  `usage: /daily-brief morning|evening [--dry-run] [--force]` and **exit 1**. Never guess the mode.
- `dry_run` = true if `--dry-run` appears anywhere, OR env `DAILY_BRIEF_DRY_RUN=1`.
- `force` = true if `--force` appears anywhere. It bypasses the date-lock AND the validity-window
  guard (deliberate manual re-send). It does NOT bypass the delivery pre-flight.

In dry-run: run the FULL pipeline EXCEPT the enqueue. Print the composed body between
`=== DRY RUN START ===` / `=== DRY RUN END ===`. Do NOT append to the queue, do NOT write the lock.
(These are the same banners `/standup` prints in its own dry-run: the shared capture contract that
LETS daily-brief borrow the standup body via `/standup {mode} --dry-run` if that seam is ever used. The
scheduled path uses daily-brief's own inline format and does NOT call `/standup`. See Composition.)

---

## Step 1 - anchor the clock, then the date-lock + validity-window guard

Anchor to the real WIB clock (never hand-calculate):

```bash
date '+now: %Y-%m-%d %H:%M %Z (epoch %s, dow %u)'   # dow: 1=Mon .. 7=Sun
NOW_DATE=$(TZ=Asia/Jakarta date +%Y-%m-%d)
HM=$(( 10#$(TZ=Asia/Jakarta date +%H%M) ))          # e.g. 0603 -> 603, 2100 -> 2100
LOCK=~/.local/share/daily-brief/last-run-MODE        # substitute MODE
```

**Date-lock (idempotency, HARD RULE 8).** The lock file holds a single `YYYY-MM-DD` (WIB date) =
the last day this mode was successfully sent. If today is already in it, this mode already went out
today:

```bash
if [ -z "$FORCE" ] && [ -f "$LOCK" ] && [ "$(cat "$LOCK")" = "$NOW_DATE" ]; then
  echo "[daily-brief] MODE already sent today ($NOW_DATE), skipping"; exit 0
fi
```

**Validity-window guard (staleness, HARD RULE 8).** A `Persistent=true` timer catches up a fire
missed while the machine slept, which could fire the morning brief at, say, 15:00. Suppress any
fire outside its window (unless `--force`), so Toper never gets a "Good morning" mid-afternoon:

```bash
# morning valid 0600-1000 ; evening valid 2100-2359 (WIB, as HHMM integers)
if [ -z "$FORCE" ]; then
  if [ "$MODE" = morning ] && { [ "$HM" -lt 600 ]  || [ "$HM" -gt 1000 ]; }; then
    echo "SUPPRESSED: morning fire out of window ($HM WIB)"; exit 0   # log it, do NOT send
  fi
  if [ "$MODE" = evening ] && { [ "$HM" -lt 2100 ] || [ "$HM" -gt 2359 ]; }; then
    echo "SUPPRESSED: evening fire out of window ($HM WIB)"; exit 0
  fi
fi
```

A suppressed fire logs `sent=no (SUPPRESSED: out of window)` (Step 6) and exits 0. The lock is
date-only now (the old minute-granularity `YYYY-MM-DD HH:MM` is retired). Dry-run skips both guards.

---

## Step 2 - read tasks (morning only)

Full parse rules: `references/sources-and-calendar.md` (Source A). In short: Glob
`~/.claude/tasks/*.md` (exclude `INDEX.md` + `archive/`), read frontmatter `project:`, parse
`## NOW / ## NEXT / ## LATER / ## WAITING`, skip `## Completed`. Task line
`- [ ] desc … \`YYYY-MM-DD\`` (trailing backtick date optional).

Derive (morning):
- `tasks_due_today` = open `[ ]` whose backtick date == today (WIB), OR undated `## NOW` items.
- `now_count` = total open `[ ]` under `## NOW` across all projects.
- `waiting` = `## WAITING` items, extract the "who" (max 3 names, then `+K more`).

Evening carries NO tasks section. Missing tasks dir -> 0 tasks, continue.

---

## Step 2.5 - read work-queue (open threads, both modes)

Full parse rules: `references/sources-and-calendar.md` (Source B). This is the SAME source + rules
`/standup` uses; do not drift. In short: read `~/claude/state/work-queue.md`, parse the tables under
`## In-flight (worker actively running)`, `## Paused — awaiting Toper decision`,
`## Paused — awaiting external (push, deploy, third-party)`. Skip `## Backlog` + `## Recently
shipped`. Skip header/separator rows and any `_(none)_` / empty / `~~strikethrough~~`-only row.
Truncate values to ~60 chars.

Counts: `inflight_n`, `paused_decision_n`, `paused_external_n`;
`open_threads_n = inflight_n + paused_decision_n + paused_external_n`. Missing file -> all empty,
`open_threads_n = 0`, continue silently. Never echo a source header (which contains an em dash) into
the body; render the `jalan` / `nunggu lu` / `nunggu eksternal` labels instead.

---

## Step 3 - query Google Calendar (list_events)

Full contract + windows: `references/sources-and-calendar.md` (Source C). The calendar is
authenticated (`$TOPER_EMAIL`, TZ Asia/Jakarta). Use
`mcp__claude_ai_Google_Calendar__list_events` with params `startTime`, `endTime`,
`timeZone="Asia/Jakarta"`, `orderBy="startTime"`, `calendarId="$TOPER_EMAIL"`, `pageSize=20`.
(There is NO `timeMin`/`timeMax`/`singleEvents` on this MCP wrapper. Do not invent params.)

Compute bounds with `TZ=Asia/Jakarta date -d ...` and pass the `+07:00` offset. Windows:
- **Morning TODAY:** now -> today 21:00.
- **Morning NEXT 7 DAYS:** today 21:00 -> today+7d 21:00, ONE highlight per day (prefer
  marked-important, else longest, else earliest work-hours event).
- **Evening LATE NIGHT:** today 22:00 -> today 23:59:59.
- **Evening EARLY MORNING:** tomorrow 00:00 -> tomorrow 06:00.

`events_today` for the log = count of TODAY (morning) or LATE-NIGHT+EARLY-MORNING (evening) events.

**Graceful degradation (only real failure to handle):** if `list_events` errors because a headless
run lacks the token, skip calendar sections, add the one-line note `_(calendar unavailable this run,
showing tasks + threads only)_` ONCE, log `calendar_auth=no`, and STILL deliver. Never block, never
retry-loop, never resurrect the OAuth nag. Any other "no events" is just `✓ Clear` and
`calendar_auth=yes`.

---

## Step 4 - format the message

Compose the body EXACTLY per `references/message-format.md` (the de-dashed morning + evening
templates, the WhatsApp formatting rules, the `{summary line}` logic, and the omission rules for the
`📋 OPEN THREADS` block). Do not invent fields, do not pad.

Before moving on, self-check the composed body for the dash ban (HARD RULE 7):
```bash
printf '%s' "$BODY" | grep -nP '[\x{2014}\x{2013}]' && { echo "ABORT: em/en dash in body"; exit 1; } || true
```
(That grep matches U+2014 em dash and U+2013 en dash; a hit means fix the template before sending.)

Then run the Secret / PII scrub self-check from `references/message-format.md` (screen the composed body
for JWTs / tokens / `key=`-style assignments / customer emails; redact the offending substring, keep the
rest of the brief). A task note or a work-queue row can carry a secret, and the brief is an outgoing
WhatsApp message.

---

## Step 5 - deliver (pre-flight + enqueue + verify, or dry-run print)

**Dry-run:** print the body between `=== DRY RUN START ===` / `=== DRY RUN END ===`. Do NOT enqueue,
do NOT lock. Done.

**Real run:** write the composed body to a temp file, then hand it to the enqueue helper. The helper
IS the pre-flight gate (wa-sender active + queue writable + phone-JID) AND the append AND the
verify-after-write, in one flock-guarded step:

```bash
BODY_FILE=$(mktemp)
printf '%s' "$BODY" > "$BODY_FILE"
~/.claude/skills/daily-brief/scripts/brief-enqueue.sh --message-file "$BODY_FILE"
RC=$?
rm -f "$BODY_FILE"
```

Branch on `$RC`:
- **0** = enqueued + verified (the line read back with the right JID + `kind:"daily-brief"`).
  Proceed to Step 6, write the success lock, log `sent=yes delivery_path=wa-sender`.
- **3** = `DEGRADED:wa-sender-inactive`. The row was NOT enqueued (a row into a dead queue would
  silently never deliver). Do NOT lock. Log `sent=no delivery_path=degraded-wa-sender-down`. Surface
  it to Toper via main (attn ping / poke-main), do NOT retry-loop, do NOT restart wa-sender.
- **4 / 5 / 6** = queue-missing/not-writable / verify-failed / bad-JID. Do NOT lock. Log the exact
  error. These are bugs to fix, not transients to spin on.

NEVER fall back to the whatsapp MCP send here. If wa-sender is down, the correct escalation is
main -> Toper, and a re-enqueue once wa-sender is back (queued rows are NOT auto-replayed on restart).

---

## Step 6 - log + lock

Append ONE structured line to `~/.local/share/daily-brief/log/{mode}-{YYYY-MM-DD}.log` (WIB date;
create the dir if missing):

```
[YYYY-MM-DD HH:MM:SS WIB] {mode} brief - tasks_due={N} open_threads={open_threads_n} events_today={M} sent={yes|no|dry-run} calendar_auth={yes|no} delivery_path={wa-sender|dry-run|degraded-wa-sender-down|error:<code>}
```

Then, ONLY on a verified send (Step 5 `$RC == 0`), write the date lock:

```bash
printf '%s' "$NOW_DATE" > ~/.local/share/daily-brief/last-run-MODE   # date only, e.g. 2026-07-03
```

Never write the lock on a dry-run, a suppressed fire, a DEGRADED result, or any error path
(lock-only-on-verified-success preserves same-day retry after a failure).

---

## Composition with /standup (the contract to preserve)

`/daily-brief` and `/standup` are complementary, NOT duplicates. daily-brief is the SCHEDULED,
calendar-forward brief (TODAY events, NEXT-7-DAYS highlights, tasks-due, open threads). standup is
the on-demand, accountability-forward ritual (yesterday-closed, today-commitments, the
decision-deadline `❓ nunggu lu mutusin` + `⏰ default in 1h` block, blockers, tomorrow-first-thing).

daily-brief renders its OWN `📋 OPEN THREADS` block from work-queue directly (Step 2.5, rules
single-sourced in `references/sources-and-calendar.md`, identical to standup's), and it does NOT call
`/standup` in the scheduled path. `/standup`'s own "Delegation seam" section confirms this: the seam is
delegation-READY, not a live contract. That `--dry-run` seam is nonetheless the sanctioned way to fold in
standup's accountability body WITHOUT re-implementing its decision-deadline logic, IF Toper ever wants one
channel that also carries the standup body:

```
1. Run: /standup {mode} --dry-run
2. Capture the text between the standup's "=== DRY RUN START ===" / "=== DRY RUN END ===" banners.
3. daily-brief OWNS the send: it enqueues (its own JID + wa-sender path). /standup NEVER touches
   WhatsApp in this path (dry-run prints only).
4. NEVER also trigger a standup SEND in the same window (that is the double-send the Boundary
   table + HARD RULE 10 forbid). One message, from daily-brief.
```

**Two-JID reconciliation (for the human, do NOT silently "fix"):** standup's standalone send targets
`$TOPER_WA_JID`; the OLD daily-brief MCP path targeted `$TOPER_WA_LID`. This
rewrite moves daily-brief onto the phone JID (forced by the wa-sender transport), which CONVERGES
both rituals onto one surface, the end-state standup's reconciliation note wanted. Both JIDs are
Toper. If Toper specifically wants the LID surface back, that is a poke-main + MCP decision, not an
unverified `@lid` through wa-sender. Full note: `references/delivery-architecture.md`.

---

## Boundary / routing (do NOT double-schedule or double-send)

| Want | Owner | Why not daily-brief |
|---|---|---|
| Scheduled 06:00 / 21:00 brief | **/daily-brief** (this skill) | - |
| On-demand standup body / decision-deadline block | **/standup** | Different shape + the `1h default` block; daily-brief may borrow it via `--dry-run`. |
| Weekly Sunday retro | **/retro** | Owns its own weekly ritual + digest. |
| Ad-hoc "remind me to X at T" | **/remindme** | Durable jsonl reminder; do not add a daily-brief timer for a one-off. |
| A one-off calendar event / phone popup | **/remindme** (calendar leg) or the Calendar MCP | daily-brief READS the calendar, it does not create events. |

If a request is really one of the right-column rows, route it there; never bolt a second timer or a
second send onto daily-brief.

---

## Failure playbooks (condensed; full mechanism in references/delivery-architecture.md)

- **"conflict, reconnecting in 5s" on send:** this is NOT a transient. Root cause is a second
  Baileys (a `WHATSAPP=1` / `plugin:whatsapp` headless run). FIX = the connection-free wa-sender path
  (this skill already uses it) + the corrected units (Toper-gated). Do NOT retry-loop the MCP send
  (the old 3-attempt loop burned ~40s and still failed). NEVER kill main's WhatsApp daemon.
- **wa-sender down (enqueue-but-silent-loss):** `brief-enqueue.sh` exits 3 and does NOT enqueue.
  Surface DEGRADED to Toper via main. NEVER restart wa-sender (Toper-gated). Once it is back,
  re-enqueue a still-relevant brief (queued rows are NOT auto-replayed on wa-sender restart).
- **calendar unauth / headless token loss:** degrade to tasks + work-queue only, note it once, STILL
  send. Do NOT block, do NOT resurrect the OAuth nag.
- **empty everything:** still send a minimal honest brief ("clear day" / "clear night"). Never pad,
  never silently skip.
- **Persistent=true catch-up after machine sleep:** the Step 1 validity-window guard suppresses an
  out-of-window fire (logs `SUPPRESSED: out of window`, exit 0). Toper never gets a stale brief.
- **manual run right after the timer already sent:** the date-lock suppresses it (same WIB day).
  Use `--force` only for a deliberate re-send.
- **unknown mode:** print usage, exit 1.

---

## Worked examples (input -> dispatch)

Assume now = Fri 2026-07-03.

1. `/daily-brief morning` at 06:00 -> in window, not yet locked today. Read tasks + work-queue +
   `list_events` (TODAY + NEXT-7). Compose per message-format.md, dash-check, enqueue via
   brief-enqueue.sh, RC=0 -> lock `2026-07-03`, log `sent=yes delivery_path=wa-sender`.
2. `/daily-brief evening --dry-run` at 21:00 -> full pipeline, print body between DRY RUN banners,
   no enqueue, no lock. (Also the exact path a caller uses to preview or to borrow the body.)
3. `/daily-brief morning` at 15:00 (Persistent catch-up after sleep) -> `HM=1500` > 1000 ->
   `SUPPRESSED: morning fire out of window`, log `sent=no`, exit 0. No stale "Good morning".
4. `/daily-brief morning` a second time at 06:05 (manual, timer already sent 06:00) -> date-lock
   holds `2026-07-03` -> "already sent today, skipping", exit 0.
5. `/daily-brief morning --force` at 09:30 -> force bypasses lock + window, recompute + re-send.
6. `/daily-brief evening` at 21:00 but wa-sender is down -> brief-enqueue.sh exits 3 (DEGRADED,
   nothing enqueued) -> no lock, log `delivery_path=degraded-wa-sender-down`, escalate main -> Toper.
7. `/daily-brief evening` on a clear night with 1 open thread -> "✓ Clear night" + the `⏸️ nunggu lu`
   block + `😴 sleep well, nothing scheduled, rest easy` (see message-format.md).
8. `/daily-brief lunch` -> unknown mode -> print usage, exit 1.

---

## Never-do list

- Never read the WhatsApp inbox or reply to messages. This skill is send-only.
- Never set `WHATSAPP=1` or load `plugin:whatsapp` in the scheduled run (HARD RULES 1-2).
- Never use the whatsapp MCP send from the headless run; that path is main-session-only.
- Never kill/restart wa-sender; never truncate/shrink the queue (HARD RULES 3-4).
- Never modify `~/.claude/tasks/*.md` or `~/claude/state/work-queue.md`. Read-only.
- Never send to any JID other than `$TOPER_WA_JID`.
- Never use an em/en dash in outgoing text.
- Never write the success lock on dry-run / suppressed / DEGRADED / error.
- Never re-prompt OAuth; never claim "no list-events tool exists".
- Never pad an empty day; never double-schedule or double-send.

---

## Done

After a verified send, print exactly:
```
DONE - {mode} brief delivered to Toper via wa-sender at {HH:MM WIB}
```
Or `DONE - {mode} brief dry-run printed`, or the `SUPPRESSED: ...` line, or
`DEGRADED - {mode} brief NOT sent ({reason}); escalated to main` on a pre-flight failure.
