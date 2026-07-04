# daily-brief message format (de-dashed, load-bearing)

The EXACT outgoing templates + formatting rules + worked examples. This spec is
carried forward verbatim from the original skill with ONE change: every em/en
dash in Toper-facing text is removed (`feedback_no_long_hyphens`). Do not lose
any field, window, or omission rule in a rewrite.

**Hard rule (dash ban):** ZERO `—` (em) or `–` (en) in the message body. Use a
middot `·`, a colon `:`, a comma, or a plain hyphen `-`. Self-check the composed
body for `—`/`–` before enqueue (grep it).

---

## WhatsApp formatting rules

- `*bold*` (single asterisks), `_italic_`, `~strike~`. WhatsApp renders these.
- Bullet char is `• ` (Unicode bullet + space), NOT `- `. (This is the one place the
  format deliberately differs from `/standup`, which uses `- `.)
- No markdown headers (`#`) - WhatsApp ignores them. Section headers are `*BOLD*` + emoji.
- Preserve blank lines between sections (they are the visual structure on a phone).
- Keep each event/task on ONE line. Truncate long titles to ~80 chars with `…`.
- Structural emojis are labels, greenlit for this ritual: `🌅 🌙 📋 ✅ 📅 📌 🔄 ⏸️ ⏳ 🌃 🌌 😴 ✓`.
  Do NOT add conversational/reaction emoji to the body.

---

## Secret / PII scrub (pre-enqueue gate)

The brief composes file content (tasks, work-queue) into an outgoing WhatsApp message, so screen every
bullet BEFORE it enters the body. Defense-in-depth: a task note or a work-queue row can carry a token or a
customer identifier (the live work-queue `## Recently shipped` rows carry a customer email; Source B skips
that section, but a task file could still hold a secret). The brief goes to Toper himself, yet a leaked
token over WhatsApp is still a leak.

Block + redact any substring matching:
- JWT / long token: `eyJ[A-Za-z0-9_-]{10,}`, or a `>=24`-char random hex / base64 run.
- assignment prefixes: `(?i)(api[_-]?key|token|password|passwd|secret|bearer)\s*[:=]\s*\S+`.
- customer PII pulled from a row: emails `[\w.+-]+@[\w-]+\.[A-Za-z]{2,}` and bare phone numbers.

On a hit: OMIT the offending substring (replace with `[redacted]` / `customer (email omitted)`) and keep
the rest of the bullet. A hit blocks that BULLET, never the whole brief. Report only the pattern TYPE if you
surface it, never the value. Blocking pre-enqueue self-check on the composed body (MUST print nothing):

```bash
printf '%s' "$BODY" | grep -nEi 'eyJ[A-Za-z0-9_-]{10,}|[0-9a-fA-F]{32,}|(api[_-]?key|token|secret|password|bearer)[[:space:]]*[:=]|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}'
```

---

## Morning template (run 06:00 WIB)

```
🌅 *Good morning!* {Weekday}, {DD MMM}

📋 *TODAY* (until 9 PM)
{HH:MM} · {event title} ({calendar})
...
(or "✓ Clear, no events")

✅ *TASKS DUE TODAY* ({N})
• {task description}
...
(omit this whole section if N = 0)

📅 *NEXT 7 DAYS HIGHLIGHTS*
• {Weekday DD}: {top event}
...
(omit this whole section if empty)

📌 *STILL OPEN*
• {N} NOW tasks across projects
• {N} waiting on others ({comma-separated names, max 3, then "+K more"})
(omit this section if BOTH numbers are zero)

📋 *OPEN THREADS* ({open_threads_n})
🔄 jalan ({inflight_n}):
• {name}: {state}
…
⏸️ nunggu lu ({paused_decision_n}):
• {name}: {what's needed}
…
⏳ nunggu eksternal ({paused_external_n}):
• {name}: {what's blocking}
…

_detail: ~/claude/state/work-queue.md_
```

Omission rules for `📋 OPEN THREADS`:
- Drop the ENTIRE `📋` block (header + all sub-blocks + the `_detail:_` line) if `open_threads_n == 0`.
- Within it, drop any sub-block whose count is 0 (e.g. no `🔄 jalan` line + bullets when `inflight_n == 0`).

---

## Evening template (run 21:00 WIB)

```
🌙 *Tonight + early morning* {DD}-{DD+1} {MMM}

🌃 *LATE NIGHT* (10 PM to 12 AM)
• {HH:MM} · {event}
...

🌌 *EARLY MORNING* (12 AM to 6 AM)
• {HH:MM} · {event}
...

(if BOTH LATE NIGHT and EARLY MORNING are empty, replace both sections with a single line: "✓ Clear night")

📋 *OPEN THREADS* ({open_threads_n})
🔄 jalan ({inflight_n}):
• {name}: {state}
…
⏸️ nunggu lu ({paused_decision_n}):
• {name}: {what's needed}
…
⏳ nunggu eksternal ({paused_external_n}):
• {name}: {what's blocking}
…

_detail: ~/claude/state/work-queue.md_

😴 sleep well, {summary line}
```

Same `📋 OPEN THREADS` omission rules as morning. Evening carries NO tasks section (events-forward
per the original spec); tasks belong to the morning brief only.

### `{summary line}` selection (evening)

| Condition | summary line |
|---|---|
| both windows empty | `nothing scheduled, rest easy` |
| only LATE NIGHT has events | `busy late night, early start clear` |
| only EARLY MORNING has events | `quiet tonight, early wake tomorrow` |
| both windows have events | `busy stretch ahead, nap when you can` |

---

## Worked example: full morning (events + tasks + 7-day + still-open + one thread)

Now = Fri 2026-07-03 06:00 WIB. Calendar authed; TODAY has the 09:00 AURA reveal; 5 tasks due; 1
paused-decision thread.

```
🌅 *Good morning!* Fri, 03 Jul

📋 *TODAY* (until 9 PM)
09:00 · AURA / 0G Zero Cup Top 16 reveal (topengdev)

✅ *TASKS DUE TODAY* (5)
• BUG: Google OAuth "Access blocked" on Aenoxa Dashboard
• BUG: registration not sending verification email
• fix CM 500 on Berkah+Pustaka
• re-run fitest suite 818
• patch fitest audit report 5.1

📅 *NEXT 7 DAYS HIGHLIGHTS*
• Sat 04: 0G Zero Cup Top 8
• Mon 06: BMS batch 6 review with Ryan

📌 *STILL OPEN*
• 5 NOW tasks across projects
• 1 waiting on others (Ryan)

📋 *OPEN THREADS* (1)
⏸️ nunggu lu (1):
• fitest-batches-6-7: "Go" to spawn batch 6

_detail: ~/claude/state/work-queue.md_
```

(`inflight_n = 0` so the `🔄 jalan` sub-block is dropped; `paused_external_n = 0` so `⏳ nunggu
eksternal` is dropped. Zero em/en dashes.)

## Worked example: full evening (clear night + one thread)

Now = Fri 2026-07-03 21:00 WIB. No late-night or early-morning events; 1 paused-decision thread.

```
🌙 *Tonight + early morning* 03-04 Jul

✓ Clear night

📋 *OPEN THREADS* (1)
⏸️ nunggu lu (1):
• fitest-batches-6-7: "Go" to spawn batch 6

_detail: ~/claude/state/work-queue.md_

😴 sleep well, nothing scheduled, rest easy
```

## Worked example: evening with events both windows

```
🌙 *Tonight + early morning* 03-04 Jul

🌃 *LATE NIGHT* (10 PM to 12 AM)
• 22:30 · 0G Discord AMA

🌌 *EARLY MORNING* (12 AM to 6 AM)
• 02:00 · Top 8 bracket goes live

📋 *OPEN THREADS* (0) is dropped entirely when open_threads_n == 0, so it is absent here.

😴 sleep well, busy stretch ahead, nap when you can
```

(The middle line is a note, not output; when `open_threads_n == 0` the whole `📋` block is omitted.)

## Worked example: empty everything (still send, never pad)

No events, no tasks due, no open threads. Still deliver an honest minimal brief
(`feedback_no_yesman_sugarcoat`: never pad, never silently skip).

```
🌅 *Good morning!* Fri, 03 Jul

📋 *TODAY* (until 9 PM)
✓ Clear, no events

Clear plate, no tasks due and no open threads. Enjoy it.
```

Evening equivalent:

```
🌙 *Tonight + early morning* 03-04 Jul

✓ Clear night

😴 sleep well, nothing scheduled, rest easy
```

## Worked example: calendar degraded (headless token loss)

If `list_events` is unavailable this run (genuine headless token loss, not the retired OAuth nag),
degrade to tasks + work-queue only and note it ONCE. Still deliver.

```
🌅 *Good morning!* Fri, 03 Jul

_(calendar unavailable this run, showing tasks + threads only)_

✅ *TASKS DUE TODAY* (2)
• fix CM 500 on Berkah+Pustaka
• re-run fitest suite 818

📋 *OPEN THREADS* (1)
⏸️ nunggu lu (1):
• fitest-batches-6-7: "Go" to spawn batch 6

_detail: ~/claude/state/work-queue.md_
```

Never resurrect an OAuth URL / "calendar not connected" nag: the calendar is authenticated and the
`calendar-oauth-sent` sentinel already exists (see references/sources-and-calendar.md).
