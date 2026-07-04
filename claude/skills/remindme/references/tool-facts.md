# remindme - scheduling tool facts (verified)

Freshness: verified live 2026-07-03 (host TZ WIB / Asia/Jakarta, UTC+7, no DST). Re-verify the
CronCreate `durable` line and ScheduleWakeup-absence before trusting them if this file is >60 days old.

These are the harness scheduling primitives. **None of them is the durable backbone** - that is the
systemd jsonl store (see `backend-architecture.md`). This file exists so the skill never re-hallucinates
a persistence guarantee the tools do not provide.

---

## CronCreate - SESSION-ONLY, durable is a NO-OP

Verified live schema (2026-07-03), quoted from the tool definition:

- `durable` param: **"Has no effect - durable persistence is not available. All jobs are session-only
  (in-memory, gone when this Claude session ends)."**
- "## Session-only - Jobs live only in this Claude session - nothing is written to disk, and the job is
  gone when Claude exits."
- `recurring` defaults **true**. `recurring:false` fires once then auto-deletes.
- **Recurring auto-expires after 7 days** ("they fire one final time, then are deleted").
- Jobs fire **only while the REPL is idle** (not mid-query) and the session is alive.
- Jitter: recurring fires up to 10% of its period late (max 15 min); one-shot landing on `:00`/`:30`
  fires up to 90 s early. Off-`:00`/`:30` minute is the bigger lever.
- A fire **enqueues a PROMPT** that this session then executes. It does NOT send a message by itself -
  the prompt has to tell Claude to send one.
- Returns a job id for CronDelete.

There is **no `~/.claude/scheduled_tasks.json`** on this host (verified absent). The old skill's claim
that `durable:true` "persists to scheduled_tasks.json, survives restart" was false and is retired.

### CronList / CronDelete
- `CronList()` lists **only this session's** in-memory cron jobs. It cannot see durable jsonl reminders.
- `CronDelete(id=...)` removes a job from the **in-memory session store** only.

### Why CronCreate is convenience-only here
Session-only means every CronCreate reminder dies on session restart / compact / exit / reboot - silently,
with no error. For a reminder whose entire job is "fire a WhatsApp message at time T", that is a strictly
worse mechanism than the durable jsonl store, which fires with no session at all. So CronCreate is used
here **only** as an optional same-session convenience when the fire must run an *in-session action*
(re-read a file, run a check, then message) rather than send the static reminder body - and **never** as
the sole mechanism for anything that must survive a restart.

### Optional convenience fire-prompt (only when you deliberately use CronCreate)
If you do use CronCreate for an in-session action, the fire-prompt must be self-contained and carry the
marker so `CronList`/`CronDelete` can find it:

```
[REMINDME id=<slug>] <the in-session action to run at fire time>, then send its result via
mcp__plugin_whatsapp_whatsapp__send_message to $TOPER_WA_JID.
```

The `[REMINDME id=<slug>]` marker is ONLY for these session-convenience jobs. Durable reminders do not use
it - their native identifier is the jsonl `id` field.

---

## ScheduleWakeup - REMOVED from this harness (do NOT use)

Triple-verified absent on 2026-07-03:
1. `ToolSearch select:...,ScheduleWakeup` returned only CronCreate/CronList/CronDelete - no ScheduleWakeup.
2. Keyword search `ScheduleWakeup wakeup delaySeconds` returned CronCreate / Monitor / Google Calendar - no
   ScheduleWakeup.
3. Not present in the session's deferred-tools inventory.

Consequence: the old skill's `test in 60 seconds` mode (which called `ScheduleWakeup(delaySeconds=60)`) is
DEAD. Test mode is rebased onto the jsonl store instead (append a one-shot with `fire_at = now + ~70 s`;
the every-minute timer fires it within the minute). Do not list ScheduleWakeup in `allowed-tools` and do
not reference it anywhere.

> Note: `feedback_time_promise_scheduling` still names "CronCreate OR ScheduleWakeup". That memory predates
> the removal. On THIS host the durable equivalent is the jsonl store; ScheduleWakeup no longer exists.

---

## Google Calendar MCP - the far-future durable belt-and-suspenders

`mcp__claude_ai_Google_Calendar__create_event` (verified available 2026-07-03). Used for a
`>~7-days-out` or high-stakes commitment as a second durable layer on TOP of the jsonl row, per
`feedback_time_promise_scheduling`. It survives host reboots/logouts entirely and fires a native phone popup.

Verified-relevant params:
- `summary` (required), `startTime` (required, ISO-8601), `endTime` (required, ISO-8601)
- `timeZone`: strict IANA name, use `Asia/Jakarta`
- `overrideReminders`: array of `{ "method": "popup"|"email", "minutes": <int> }` - use
  `[{"method":"popup","minutes":0}]` to pop at event start.

Target calendar: `$TOPER_EMAIL` (Toper's primary, TZ Asia/Jakarta) per the memory. This is a
separate durability layer, NOT a replacement for the jsonl row (which is what actually WhatsApps him).

---

## One-line decision reminder

| Need | Mechanism |
|---|---|
| Any reminder that must survive a restart (the default) | **jsonl store** via `remindctl` |
| Recurring reminder (no 7-day cap) | **jsonl `kind:cron`** via `remindctl` |
| >7 days out / high-stakes | **jsonl row + Google Calendar event** |
| In-session action at time T, session certainly alive, disposable | CronCreate convenience (session-only) |
| Sub-minute test fire | jsonl one-shot at `now + ~70 s` |
