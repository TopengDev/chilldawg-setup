# remindme - failure playbooks

Every diagnostic below is **non-mutating** (status reads, log tails, store parses). Recovery steps that
touch a service or the store are marked and are **Toper-gated** where they affect load-bearing infra. Never
kill/restart `wa-sender.service` on your own (`feedback_wa_sender_load_bearing`).

Quick health probe (run first, any failure):
```bash
systemctl --user is-active reminder-check.timer     # want: active
systemctl --user is-active wa-sender.service         # want: active
test -w ~/reminders/reminders.jsonl && echo store-writable
```

---

## 1. WhatsApp delivery failed / wa-sender down (the silent-loss hazard)

**Symptom:** reminders stop arriving on Toper's phone, but no error surfaces. This is the worst failure
class because rows enqueue "successfully" and vanish.

**Detect (non-mutating):**
```bash
systemctl --user is-active wa-sender.service                 # inactive/failed = the cause
journalctl --user -u wa-sender.service -n 40 --no-pager      # last delivery / crash lines
tail -n 20 ~/reminders/reminder-check.log                    # ENQUEUED lines...
# ...with NO matching wa-sender "delivered kind=reminder" line = enqueued-but-undelivered
wc -l ~/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl  # growing + not draining
```
The tell: `ENQUEUED` lines in `reminder-check.log` (the engine did its job) but no corresponding
`delivered` line from wa-sender, and the queue line-count climbing.

**Recover:**
- Surface to Toper via main (the queued rows are NOT lost - they persist in `events.jsonl`).
- **Do NOT** kill or restart `wa-sender.service` - it is load-bearing for signal-trader too; restart is
  Toper's call. If he authorizes, the recovery procedure is in `feedback_wa_sender_load_bearing`
  (new tmux window in the wa-sender dir, `bun run start`, wait ~30 s for Baileys to stabilize).
- Backlogged queue events are **not replayed** on a wa-sender restart (its offset resets to the queue file
  size at startup). So a reminder enqueued while wa-sender was dead will NOT auto-deliver on restart. For a
  still-relevant missed reminder, re-add it as a fresh one-shot at a new `fire_at` once wa-sender is back.

Precedent: 2026-05-12 wa-sender silently lost ~26 h of events (queue grew to 776 undelivered) after being
killed in a cleanup pass. That is the exact failure this playbook guards.

---

## 2. Timer not firing (nothing fires at all, wa-sender is fine)

**Detect (non-mutating):**
```bash
systemctl --user status reminder-check.timer --no-pager      # want active (waiting) + a future Trigger
systemctl --user list-timers reminder-check.timer --no-pager # LEFT/LAST/NEXT columns
journalctl --user -u reminder-check.service -n 30 --no-pager # per-tick run output / tracebacks
```
Remember: `reminder-check.service` is a **oneshot** and reads `inactive` between ticks - that is healthy.
Diagnose on the **timer**, and on the service's journal (not its active-state).

**Common causes + fix:**
- Timer disabled/stopped -> `systemctl --user enable --now reminder-check.timer` (safe, idempotent).
- A traceback every tick in the service journal -> the store has a structural problem the engine chokes on
  BEFORE the per-line try/except (rare). Validate the store (playbook 5).
- Whole user-manager not running (fresh logged-out boot, `Linger=no`) -> playbook 3.

---

## 3. Missed while logged out (Linger=no)

**Symptom:** a reminder that should have fired overnight/while logged out did not.

**Explain (this is expected, per the engine's design):**
- `Linger=no` -> the timer + wa-sender only start once Christopher logs in.
- `Persistent=true` catches up a **pending one-shot** on next login (fires because `now >= fire_at`).
- A **recurring** match that fell during the logged-out window is **lost** (no cron catch-up, only a
  same-minute dedup guard).

**Options:**
- Accept it (this matches all the other user-timer notif infra - daily-brief, macro-news).
- Toper-gated escape hatch: `loginctl enable-linger christopher` (makes user units run across a logged-out
  boot). This is a machine-wide behavior change - only on Toper's explicit go.
- For a critical one-shot far in the future, the `>7-days-out` rule already adds a Google Calendar event as
  a second layer, which is immune to this.

---

## 4. Duplicate WhatsApp send

**Root cause (essentially the only one):** the same reminder was entered in BOTH `reminders.jsonl` AND a
CronCreate job. The two paths share no store, no channel, and no dedup key, so each fires independently.

**Confirm:**
```bash
~/.claude/skills/remindme/scripts/remindctl list          # is it in the jsonl store?
```
and `CronList()` - is a `[REMINDME id=...]` job for the same thing also live this session?

**Fix:** pick exactly ONE path and remove the other. For a durable reminder, keep the jsonl row and
`CronDelete` the session job. The engine's own `last_fired_minute` guard already prevents a single cron row
from double-firing within a minute, so intra-store duplication is not the cause - cross-path double-entry is.

**Prevent:** never author both for one reminder. This is a hard rule in SKILL.md.

---

## 5. Bad / unparseable row in the store

**Symptom:** a `WARN skipping unparseable store line` in the log, or one reminder silently not firing while
others do.

**Detect (non-mutating - validate every line):**
```bash
/usr/bin/python3 - <<'PY'
import json, os
p = os.path.expanduser("~/reminders/reminders.jsonl")
for i, ln in enumerate(open(p), 1):
    ln = ln.strip()
    if not ln: continue
    try: json.loads(ln)
    except json.JSONDecodeError as e: print(f"line {i}: BAD - {e}")
PY
grep -n "WARN" ~/reminders/reminder-check.log
```

**Fix:**
- The engine skips the bad line and keeps going, so other reminders are unaffected - not urgent.
- `remindctl` PRESERVES bad lines (never drops them), so a `remindctl` mutation will not clean it up. To
  remove a genuinely-corrupt line, do it under the lock, never with a naive editor while the timer runs:
  ```bash
  # Toper-gated store edit - only when a line is confirmed corrupt and unwanted:
  # 1. copy the store, 2. hand-fix the copy, 3. swap it in during an off-tick second with flock held.
  ```
  In practice, prefer `remindctl cancel --id <slug>` if the bad line still has a parseable id; only hand-edit
  a truly malformed line, and confirm with Toper first.

---

## 6. Reminder fired but content/schedule looks wrong

**Detect:**
```bash
~/.claude/skills/remindme/scripts/remindctl get --id <slug> --json
```
Check `content` (verbatim topic) and `schedule_human` (the human phrasing shown on the `Scheduled:` line).
`schedule_human` is cosmetic - it does not affect timing. Timing is `fire_at` (once) or `cron` (recurring).
If timing is wrong, `remindctl cancel --id <slug>` and re-add with the corrected value; the engine will not
retroactively fix an already-fired `done` row.

---

## 7. "It says session-only" when creating via CronCreate

Not a failure - that is CronCreate telling the truth. `durable` is a no-op; all CronCreate jobs are
session-only. If you needed durability you used the wrong path: create a jsonl row via `remindctl` instead.
See `tool-facts.md`.
