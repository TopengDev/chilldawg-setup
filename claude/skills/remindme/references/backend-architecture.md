# remindme - durable backend architecture (verified engine contract)

Freshness: verified against the live units + `~/reminders/reminder-check.py` source on 2026-07-03.
Everything here is read from the actual installed files, not inferred.

This is the engine the skill's PRIMARY path drives. It runs with **no Claude session involved**.

```
 remindctl (this skill)                    systemd (autonomous)                    wa-sender (Baileys)
 ───────────────────────                   ────────────────────                    ───────────────────
 append/edit a row  ──flock──►  ~/reminders/reminders.jsonl
                                          │  read every minute
                                          ▼
                              reminder-check.timer  (OnCalendar=*:0/1)
                                          │ triggers
                                          ▼
                              reminder-check.service (oneshot)
                                 /usr/bin/python3 reminder-check.py
                                          │ APPENDS a line
                                          ▼
                    ~/claude/.../signal-trader/wa-sender/queue/events.jsonl
                                          │ drained by
                                          ▼
                              wa-sender.service (bun/Baileys, PID varies)
                                          │
                                          ▼
                                   WhatsApp DM to Toper
```

---

## The units (verified)

**`~/.config/systemd/user/reminder-check.timer`**
- `OnCalendar=*:0/1` - fires every minute on the minute.
- `Persistent=true` - "Catch a missed tick after sleep/suspend/boot so a due one-shot still fires."
- `AccuracySec=1s`.
- State on 2026-07-03: `enabled`, `active (waiting)`, next trigger at the next minute boundary.

**`~/.config/systemd/user/reminder-check.service`**
- `Type=oneshot`. **It is `inactive` between ticks - that is NORMAL, not a failure.** Never treat the
  service being `inactive` as "the pipeline is down"; check the **timer** instead.
- Env (source of the paths/JID/TZ): `REMINDER_TZ=Asia/Jakarta`, `REMINDER_STORE=%h/reminders/reminders.jsonl`,
  `WA_QUEUE=%h/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl`,
  `REMINDER_JID=$TOPER_WA_JID`.
- `ExecStart=/usr/bin/python3 %h/reminders/reminder-check.py` (Python 3.14.5).
- `Wants=wa-sender.service`.

---

## The store: `~/reminders/reminders.jsonl` (one JSON object per line)

`0600` perms. `remindctl`'s atomic rewrite preserves `0600` (mkstemp + fchmod).

**one-shot row**
```json
{"id":"take-bread","kind":"once","fire_at":"2026-07-03T14:30:00+07:00",
 "content":"take the bread out","schedule_human":"today at 2:30pm WIB",
 "target_jid":"$TOPER_WA_JID","status":"pending"}
```
**recurring row**
```json
{"id":"weekly-retro","kind":"cron","cron":"58 6 * * 0","content":"weekly retro",
 "schedule_human":"every Sunday 07:00 WIB","target_jid":"$TOPER_WA_JID","status":"active"}
```

**Keys** (author these): `id`, `kind` (`once`|`cron`), `fire_at` (ISO-8601 WITH `+07:00`, once only),
`cron` (5-field WIB, cron only), `content`, `schedule_human`, `target_jid`, `status`.
**Engine-written** (never author): `fired_at` (once, on fire), `last_fired_minute` (cron dedup guard).

### Status transitions
- `once`: `pending` -> `done` (engine sets `status:done` + `fired_at` after enqueuing).
- `cron`: stays `active`; engine stamps `last_fired_minute="YYYY-MM-DDTHH:MM"` so it cannot double-fire in
  the same minute. Set `status:"paused"` to disable without deleting (`remindctl pause`).

### Firing rules (from the source)
- `once` fires when **`now >= fire_at`** and `status == "pending"`. Because the check is once per minute at
  the tick, set `fire_at` seconds to `:00` so it fires AT the intended minute (a `:30` seconds value fires
  at the NEXT minute tick).
- `cron` fires when `cron_matches(expr, now)` and `status == "active"` and it has not already fired this
  minute. day-of-week: **`0` or `7` = Sunday**, `1` = Mon ... `6` = Sat (matches `remindctl`'s ported matcher).
- Times are interpreted in `REMINDER_TZ` (Asia/Jakarta), **independent of the host clock** - correct even
  if this ever runs on a UTC VPS.

### Bad-line tolerance
One unparseable JSON line is **skipped with a `WARN`** in the log and does NOT block the other rows
(`reminder-check.py` `json.JSONDecodeError` handler). The engine drops such a line the next time it
rewrites; `remindctl` is stricter and **preserves** unparseable lines verbatim so it never destroys data.

---

## Delivery: the wa-sender queue

On a fire, the engine **APPENDS** one line to `WA_QUEUE`:
```json
{"to":"<jid>","message":"⏰ REMINDER\n\nTopic: <content>\nScheduled: <schedule_human>","kind":"reminder","ts":<epoch>}
```
- **Append-only** - it never rewrites the queue, so it is safe alongside the other producers
  (signal-trader, macro-news) that share that file.
- The message body is **byte-identical** to what the skill promises Toper. There is no snooze line and no
  auto-renew line in it - do not try to make the engine add one.
- `wa-sender.service` (bun/Baileys) is the sole consumer that relays it to WhatsApp. It is **load-bearing**
  (see `feedback_wa_sender_load_bearing`): if it is down, rows enqueue but never deliver, silently. Never
  kill/restart it to "fix" delivery - restart is Toper-gated.

Delivery JID: **`$TOPER_WA_JID`** (phone-format, `REMINDER_JID` default, per-row `target_jid`
overrides). E2E-verified in `~/claude/notes/reminder-infra-vps-2026-05-24/report.md`
(`ENQUEUED ... -> wa-sender delivered kind=reminder`). The LID `...@lid` also reaches Toper but is NOT what
this transport uses - the sibling ritual skills (daily-brief/standup) use the LID via the Claude WA MCP;
this skill uses the phone JID via wa-sender. Do not swap them.

---

## Reboot / linger semantics (honest limits)

- `loginctl show-user christopher -p Linger` = **`Linger=no`**: user units (this timer AND wa-sender) do
  NOT start until Christopher logs in after a logged-out boot.
- `Persistent=true` on the timer catches up a **missed one-shot** on next login (a `pending` `once` whose
  `fire_at` has passed still fires because `now >= fire_at`).
- **Recurring matches during a logged-out window are lost** - the cron path has only the same-minute
  `last_fired_minute` dedup guard, no catch-up. A `weekly-retro` whose Sunday tick happened while logged
  out is simply skipped until the next match.
- Escape hatch (Toper-gated): `loginctl enable-linger christopher` makes user units run across a
  logged-out boot.

---

## Concurrency contract + the one residual micro-race

The engine locks the store with `fcntl.flock(LOCK_EX)` around a read-modify-write and commits via
temp-file + `os.replace()` (atomic rename). `remindctl` uses the **same** lock on the **same** file, so a
mutation and the engine's minute-tick rewrite serialize.

`remindctl` is additionally hardened beyond the engine (which is a singleton and never races itself): after
acquiring the lock it re-checks that its fd's inode is still the live store and retries on the fresh inode
if the store was replaced while it waited. This eliminates lost updates between concurrent `remindctl`
invocations (verified: 50 parallel adds all land, zero corruption).

**Residual (accept + know it):** the engine has no such inode re-check. In the astronomically narrow window
where `remindctl` renames the store in the same sub-second that the engine (a) is mid-tick AND (b) has a
reminder actually firing this minute AND (c) opened its fd before the rename, the engine could commit over
`remindctl`'s change. Mitigation: the skill's verify-after-write gate re-reads the store after every
mutation and re-applies if the row is missing. In practice `remindctl` runs interactively for milliseconds
and the engine only rewrites in a minute where something fires, so the overlap is negligible - but the
verify-after-write step is why it is safe.
