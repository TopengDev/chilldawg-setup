---
name: daily-brief
description: Send Christopher a structured daily brief via WhatsApp. Invoked as "/daily-brief morning" or "/daily-brief evening" (optionally with "--dry-run"). Reads ~/.claude/tasks/*.md + Google Calendar, formats, sends to Toper JID 107838240207070@lid. Used by systemd timers at 06:00 + 21:00 WIB.
argument-hint: morning|evening [--dry-run]
allowed-tools: Read, Glob, Bash, mcp__claude_ai_Google_Calendar__authenticate, mcp__claude_ai_Google_Calendar__complete_authentication, mcp__plugin_whatsapp_whatsapp__send_message
---

# Daily Brief — morning + evening WhatsApp notification

One-shot skill. Reads tasks + calendar, formats a brief, sends WhatsApp to Christopher, exits. Runs from systemd timers or manually.

**Recipient JID:** `107838240207070@lid` (Toper)
**Timezone:** `Asia/Jakarta` (WIB = UTC+7) — do all time math in WIB.

## Argument parsing

`$ARGUMENTS` will be `morning`, `evening`, `morning --dry-run`, or `evening --dry-run`.

- `mode` = first word (`morning` or `evening`). If missing or unrecognized → abort with error message.
- `dry_run` = true if `--dry-run` appears anywhere in args, OR if env var `DAILY_BRIEF_DRY_RUN=1`.

In dry-run mode: run the full pipeline EXCEPT the WhatsApp send. Instead print the final formatted message to stdout under a banner `=== DRY RUN (not sent) ===`.

## Step 1 — idempotency lock

Lock file path: `~/.local/share/daily-brief/last-run-{mode}` (mode = morning or evening).
It contains a single line: `YYYY-MM-DD HH:MM` in WIB.

Use Bash to check:

```bash
NOW_WIB=$(TZ=Asia/Jakarta date +"%Y-%m-%d %H:%M")
LOCK=~/.local/share/daily-brief/last-run-MODE
if [ -f "$LOCK" ] && [ "$(cat "$LOCK")" = "$NOW_WIB" ]; then
  echo "[daily-brief] already ran this minute ($NOW_WIB), skipping"
  exit 0
fi
```

Replace `MODE` with the actual mode. Only write the lock file AFTER a successful send (or after a successful dry-run print). Never write the lock on error paths.

## Step 2 — read tasks

Glob `~/.claude/tasks/*.md` (exclude `INDEX.md` and `archive/`). For each task file:

- Read the frontmatter `project:` name (falls back to filename).
- Parse the `## NOW`, `## NEXT`, `## WAITING`, `## Completed` sections.
- Task line format: `- [ ] description [...] \`YYYY-MM-DD\`` (backtick-wrapped date at end, optional).
- **For morning brief:**
  - `tasks_due_today` = open `[ ]` items whose backtick date == today (WIB) OR items in `## NOW` tier with no date.
  - `now_count` = total open `[ ]` items under `## NOW` across all projects.
  - `waiting` = items under `## WAITING` — extract "who" from phrasing like "waiting on X" / "need X from Y" / "blocked by Z".
- **For evening brief:** tasks are not included (evening brief is events-only per format spec).

Skip `## Completed` items entirely.

## Step 3 — query Google Calendar (graceful)

Use tool `mcp__claude_ai_Google_Calendar__authenticate` FIRST to check auth status. The tool may return either:
- An auth URL (user hasn't authenticated yet) → set `calendar_authed=false`, capture the URL.
- A success/already-authenticated response → set `calendar_authed=true`.

Be defensive — MCP tool return shapes vary. If the response contains a URL starting with `https://accounts.google.com` or similar auth host, treat it as "not authenticated yet." If it contains tokens/user info or a "connected" confirmation, treat it as authenticated.

**If not authenticated:** skip the calendar query. Note `⚠️ Google Calendar not authenticated yet` in the brief. On the FIRST morning brief where this happens, include the OAuth URL + instructions in the WhatsApp message (see OAuth prompt below). Do NOT repeat the OAuth prompt on subsequent runs — track state with a file at `~/.local/share/daily-brief/calendar-oauth-sent` (create it after sending the OAuth prompt once).

**If authenticated:** list events in the relevant window.

There is no generic "list events" tool exposed here — work with whatever Google Calendar MCP tools are present. If only `authenticate` / `complete_authentication` are available and no list/search tools, gracefully degrade: note `📅 calendar queries unavailable in this MCP build` once, skip calendar sections, continue with tasks.

### Time windows (all WIB)

- **Morning (run at 06:00 WIB):**
  - "TODAY" window: now → 21:00 WIB today
  - "NEXT 7 DAYS HIGHLIGHTS" window: 21:00 WIB today → 21:00 WIB (today + 7 days). Summarize as one event per day (the "top" event — prefer marked-important, longest, or earliest work-hours event).
- **Evening (run at 21:00 WIB):**
  - "LATE NIGHT" window: 22:00 WIB today → 23:59 WIB today
  - "EARLY MORNING" window: 00:00 WIB tomorrow → 06:00 WIB tomorrow

Dates should be formatted `DD MMM` (e.g. `15 Apr`) and weekdays as `Mon`, `Tue`, etc. Use WIB throughout.

## Step 4 — format message

### Morning template

```
🌅 *Good morning!* {Weekday}, {DD MMM}

📋 *TODAY* (until 9 PM)
{HH:MM} — {event title} ({calendar})
...
(or "✓ Clear — no events")

✅ *TASKS DUE TODAY* ({N})
• {task description}
...
(omit section if N=0)

📅 *NEXT 7 DAYS HIGHLIGHTS*
• {Weekday DD}: {top event}
...
(omit section if empty)

📌 *STILL OPEN*
• {N} NOW tasks across projects
• {N} waiting on others ({comma-separated names, max 3, then "+K more"})
(omit section if both zero)
```

### Evening template

```
🌙 *Tonight + early morning* {DD}-{DD+1} {MMM}

🌃 *LATE NIGHT* (10 PM – 12 AM)
• {HH:MM} — {event}
...
(omit section if empty; if BOTH sections empty, show "✓ Clear night")

🌌 *EARLY MORNING* (12 AM – 6 AM)
• {HH:MM} — {event}
...

😴 sleep well — {summary line}
```

The `{summary line}` for evening: if both sections empty → `nothing scheduled, rest easy`; if only late night has events → `busy late night, early start clear`; if only early morning → `quiet tonight, early wake tomorrow`; if both → `busy stretch ahead, nap when you can`.

### WhatsApp formatting rules
- WhatsApp uses `*bold*` (single asterisks), `_italic_`, `~strike~`.
- Bullet character: `• ` (Unicode bullet + space). NOT `- `.
- No markdown headers (`#`) — WhatsApp ignores them. Use `*BOLD*` + emoji for section headers as shown.
- Preserve blank lines between sections.
- Keep each event/task on one line (truncate long titles to ~80 chars with `…`).

### OAuth prompt (only once, when calendar first fails)

Append to the END of the morning brief ONE TIME:

```

⚠️ *Calendar not connected yet.* Link Google Calendar once to see events:
1. Open: {auth_url}
2. Approve access
3. Reply "calendar ok" — I'll pick it up from tomorrow.
```

After sending this, touch `~/.local/share/daily-brief/calendar-oauth-sent` so future runs don't repeat the nag.

## Step 5 — send via WhatsApp

If NOT dry-run:
Call `mcp__plugin_whatsapp_whatsapp__send_message` with the recipient JID `107838240207070@lid` and the formatted message body. The exact parameter names may be `jid`/`recipient`/`to` and `message`/`text`/`body` — inspect the tool schema at call-time and use whichever the MCP server expects. If the tool errors, log the error and exit non-zero (systemd will capture it).

If dry-run: print the formatted message between `=== DRY RUN START ===` / `=== DRY RUN END ===` banners to stdout. Do NOT call the WhatsApp tool.

## Step 6 — log + lock

Log file: `~/.local/share/daily-brief/log/{mode}-{YYYY-MM-DD}.log` (WIB date).

Append a line:
```
[YYYY-MM-DD HH:MM:SS WIB] {mode} brief — tasks_due={N} events_today={M} sent={yes|no|dry-run} calendar_auth={yes|no|unavailable}
```

Then update the lock file to the current WIB minute.

## Error handling

- Missing tasks dir → treat as 0 tasks, continue.
- Calendar MCP errors → degrade gracefully, continue with tasks-only.
- WhatsApp send error → log error, exit 1 (systemd records failure; don't update lock).
- Unknown mode → print usage, exit 1.

## Never-do list

- Never read WhatsApp inbox or reply to messages — this skill is send-only.
- Never modify `~/.claude/tasks/*.md` files — read-only.
- Never send to any JID other than `107838240207070@lid`.
- Never re-prompt OAuth if `calendar-oauth-sent` sentinel exists.

## Done

After successful send (or dry-run print), print exactly:
```
DONE — {mode} brief sent to Toper at {HH:MM WIB}
```
(or `DONE — {mode} brief dry-run printed` in dry-run mode).
