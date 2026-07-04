# daily-brief sources + calendar (parse rules + list_events usage)

The three read-only sources the brief compiles, with the exact parse rules and
the VERIFIED Google Calendar tool contract. All three degrade gracefully: a
missing/unreadable source is treated as empty, never a crash, never a blocked send.

**Read-only invariant:** the skill NEVER writes `~/.claude/tasks/*.md`,
`~/claude/state/work-queue.md`, or any producer's line in the wa-sender queue.
Its only write is its own single queue append + its own state files.

---

## Source A: tasks (`~/.claude/tasks/*.md`)

Glob `~/.claude/tasks/*.md`. **Exclude** `INDEX.md` and anything under `archive/`.

For each task file:
- Read frontmatter `project:` (fallback to the filename stem if absent).
- Parse the tier sections: `## NOW`, `## NEXT`, `## LATER`, `## WAITING`, `## Completed`.
- Task line shape: `- [ ] {description} … \`YYYY-MM-DD\`` (a backtick-wrapped date at the end is
  OPTIONAL). `- [x]` = done.
- **Skip `## Completed` entirely.**

Derived values (morning brief):
- `tasks_due_today` = open `[ ]` items whose backtick date == today (WIB), OR items under `## NOW`
  with no date. Dedupe if an item is both.
- `now_count` = total open `[ ]` items under `## NOW` across all projects.
- `waiting` = items under `## WAITING`. Extract the "who" from phrasing like "waiting on X" /
  "need X from Y" / "blocked by Z". Render up to 3 names, then `+K more`.

Evening brief carries NO tasks (events-forward). Compute tasks only for morning.

Verified structure (2026-07-03): e.g. `~/.claude/tasks/aenoxa-dashboard.md` has `project: Aenoxa
Dashboard` + `## NOW` items with trailing `` `2026-04-01` `` dates. Missing tasks dir -> 0 tasks, continue.

---

## Source B: work-queue (`~/claude/state/work-queue.md`)

The canonical kanban. This is the SAME source `/standup` parses, with the SAME rules; the two
skills must not drift. `/standup` Step 2 (section A, work queue) is the canonical statement of these
rules; this is the single-sourced restatement for the brief's `📋 OPEN THREADS` block.

Parse the markdown tables under these headers (verified header text):
- `## In-flight (worker actively running)` -> `inflight` list. Capture `Name`, `State`, `Last update`.
- `## Paused — awaiting Toper decision` -> `paused_decision` list. Capture `Name`, `What's needed`.
- `## Paused — awaiting external (push, deploy, third-party)` -> `paused_external` list. Capture
  `Name`, `What's blocking`.

**Skip** `## Backlog — nice-to-have` and `## Recently shipped (last 7d)` (they do not surface in the brief).

Per-table hygiene:
- Skip the header row and the `|---|` separator row.
- Skip any row whose first cell is `_(none)_`, empty/whitespace, or a `~~strikethrough~~`-only cell
  (a shipped/retired row, e.g. `~~signal-trader-ocr-hardening~~`).
- Truncate long cell values to ~60 chars with `…` so each bullet stays one phone line.

Counts: `inflight_n`, `paused_decision_n`, `paused_external_n`.
`open_threads_n = inflight_n + paused_decision_n + paused_external_n`.

Missing file -> all three lists empty, `open_threads_n = 0`, continue silently (no nag in the brief).

**Staleness (honesty gate):** `work-queue.md` is main-maintained and can lag badly (its verified mtime is
often weeks old). Do NOT present `open_threads = 0` as "nothing is happening" when the file is simply stale.
If `find ~/claude/state/work-queue.md -mtime +3 -print` emits the path (older than ~3 days), still report the
parsed counts but treat a fully-empty result as "possibly incomplete", not ground truth. `/standup`'s Step 2
staleness gate is the fuller treatment; the brief just avoids over-claiming an empty queue.

> Note: the source headers contain em dashes (e.g. `Paused — awaiting Toper decision`). Those are in
> the FILE you read, not in your output. The brief renders `nunggu lu` / `nunggu eksternal` labels,
> which carry no dashes. Never echo the source header verbatim into the message.

The labels (`jalan` / `nunggu lu` / `nunggu eksternal`) use the standup-template Bahasa register
(`~/claude/templates/standup-template.md`). Applies to BOTH morning and evening.

---

## Source C: Google Calendar (`list_events`)

The calendar is AUTHENTICATED (recent runs log `calendar_auth=yes` and delivered real events) and
is a bidirectional channel to Toper's Infinix phone (`reference_calendar_infinix_google_sync.md`,
primary calendar `$TOPER_EMAIL`, TZ Asia/Jakarta). Use `list_events`. There is NO OAuth
bootstrap to run (retired; see bottom).

### Verified tool contract (schema-checked 2026-07-03)

`mcp__claude_ai_Google_Calendar__list_events` parameters (ACTUAL names, not the raw Google API names):

| param | use |
|---|---|
| `startTime` | ISO 8601 lower bound (exclusive). Pass with the `+07:00` offset. |
| `endTime` | ISO 8601 upper bound (exclusive). Must be > `startTime`. |
| `timeZone` | `Asia/Jakarta` (IANA). Resolves timezone-less dates + formats the response. |
| `calendarId` | `$TOPER_EMAIL` (or omit for the user's primary, which is the same). |
| `orderBy` | `startTime` (ascending). |
| `pageSize` | keep small, e.g. `20`. Default is 100; 250 max. |

There is NO `timeMin` / `timeMax` / `singleEvents` param on this MCP wrapper (those are the raw
Google names). Do not pass them. `list_calendars` and `get_event` also exist if ever needed.

Anchor every bound to the real WIB clock, never hand-calculated:
```bash
TZ=Asia/Jakarta date +"%Y-%m-%dT%H:%M:%S+07:00"                 # now
TZ=Asia/Jakarta date -d "today 21:00"      +"%Y-%m-%dT21:00:00+07:00"
TZ=Asia/Jakarta date -d "today 22:00"      +"%Y-%m-%dT22:00:00+07:00"
TZ=Asia/Jakarta date -d "tomorrow 00:00"   +"%Y-%m-%dT00:00:00+07:00"
TZ=Asia/Jakarta date -d "tomorrow 06:00"   +"%Y-%m-%dT06:00:00+07:00"
TZ=Asia/Jakarta date -d "+7 days 21:00"    +"%Y-%m-%dT21:00:00+07:00"
```

### Windows (all WIB)

**Morning (06:00 run):**
- TODAY: `startTime = now`, `endTime = today 21:00`.
- NEXT 7 DAYS HIGHLIGHTS: `startTime = today 21:00`, `endTime = today+7d 21:00`. Summarize as ONE
  event per day (the "top" event): prefer a marked-important event, else the longest, else the
  earliest work-hours (09:00-18:00) event. Render `• {Weekday DD}: {top event}`.

**Evening (21:00 run):**
- LATE NIGHT: `startTime = today 22:00`, `endTime = today 23:59:59`.
- EARLY MORNING: `startTime = tomorrow 00:00`, `endTime = tomorrow 06:00`.

Format event times as `HH:MM` (WIB), dates as `DD MMM` (`03 Jul`), weekdays as `Mon`/`Tue`. Pull
the display time from each event's start; render the title (truncated ~80 chars). If the response
carries a calendar name and it is not the primary, you may append `({calendar})`.

### Graceful degradation (the ONLY calendar failure to handle)

If `list_events` errors specifically because a headless run lacks the calendar token (auth/token
error), degrade: skip the calendar sections, add the one-line note
`_(calendar unavailable this run, showing tasks + threads only)_` to the body ONCE, and STILL
deliver via wa-sender. Do NOT block the send. Do NOT retry-loop. Log `calendar_auth=no`.

Any other calendar error (empty result, transient) is just "no events": render `✓ Clear, no events`
(morning TODAY) or `✓ Clear night` (evening) and continue. Log `calendar_auth=yes`.

---

## Retired: the OAuth-prompt bootstrap (do NOT resurrect)

The original skill claimed "there is no generic list events tool" and shipped a one-time OAuth-URL
nag gated on `~/.local/share/daily-brief/calendar-oauth-sent`. Both are stale:
- `list_events` (+ `list_calendars`, `get_event`) exist and the calendar is authenticated.
- The `calendar-oauth-sent` sentinel already exists (0-byte, created 2026-04-18), so even the old
  guard would never re-fire.

Leave the sentinel in place (harmless), but NEVER compose an OAuth URL, "link your calendar", or
"reply calendar ok" line into the brief again. If the calendar genuinely loses auth, that is the
graceful-degradation path above (a one-line note), not a nag.
