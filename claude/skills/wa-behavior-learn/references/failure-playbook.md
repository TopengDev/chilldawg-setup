# Failure Playbook

Every known failure mode for this skill, with a fast diagnosis and an exact
recovery. The rule for all of them: stay READ-ONLY and connection-free. Nothing
here justifies opening a DB read-write or reconnecting WhatsApp.

---

## F1. WhatsApp MCP tools "not found" (EXPECTED, not a bug)

Symptom: `list_chats` / `read_messages` / `list_contacts` unavailable.
Diagnosis: the daily runner is `claude -p /wa-behavior-learn`, which does not load
the WhatsApp plugin; the single Baileys socket is held by the live main session.
Recovery: proceed via sqlite3 on the snapshot. Do NOT try to reconnect WhatsApp,
do NOT patch PATH to summon bun. This is the whole reason the skill is SQLite-only.
Verified: journal.md 2026-05-31 and 2026-06-02.

## F2. app.db stale (the `wa` TUI is not running)

Symptom: the app.db window is empty or its newest message is days old.
Diagnose:
```bash
WAPID=$(cat "$HOME/.local/share/whatsapp-tui/wa.pid" 2>/dev/null); echo "pid=$WAPID"
ps -p "$WAPID" -o pid,cmd 2>/dev/null || echo "wa process DEAD (stale pidfile)"
sqlite3 "$APPS" "SELECT datetime(MAX(timestamp),'unixepoch','+7 hours') FROM messages;"
```
Recovery: the decision table (SKILL.md section 3) handles it automatically:
either switch to the fresher messages.db with the `@lid`->phone merge, or anchor
the window on `appMax-7d` and emit `WARN: data is N days old, relaunch wa to
resync app.db`. Never profile a window that ends days in the past without the
WARN. Verified state 2026-07-03: `wa.pid=369385` dead, appMax 2026-06-30 04:08.

## F3. DB locked / busy

Symptom: `database is locked` / `database is busy`.
Cause: querying a live WAL DB while the writer holds it.
Recovery: you should be on a snapshot copy (F0 in the cookbook), where this cannot
happen. If you hit it, you are reading the live file: re-copy `db + -wal + -shm`
to the scratch dir and query the copy, or open `file:...?mode=ro` with
`.timeout 5000`. NEVER open read-write to break a lock.

## F4. Schema drift (a column or version changed)

Symptom: `no such column: react_emoji` (or similar), or `schema_version <> 3`.
Diagnose:
```bash
sqlite3 "$APPS" "SELECT name FROM pragma_table_info('messages');"
sqlite3 "$APPS" "SELECT * FROM schema_version;"
```
Recovery: adapt to the columns that exist. Degrade gracefully (e.g. drop the
`react_emoji` dimension) rather than aborting the whole run, and note the drift in
the RUN LEDGER. The verified 2026-07-03 schema is in the cookbook; treat it as a
baseline, not a guarantee.

## F5. Empty / media-only history for a contact

Symptom: a contact clears the activity filter but has < 5 text messages (all
images / stickers / calls).
Recovery: mark thin-data, skip the file, list them under GAPS. Do not fabricate a
style from media. The `>= 5` floor is hard.

## F6. LID split (messages.db shows 2 msgs, app.db shows thousands)

Symptom: a person looks inactive in messages.db but is very active in app.db.
Cause: messages.db keeps their history under an `@lid`, app.db under the phone JID.
Recovery: prefer app.db (this is why it is primary). If forced onto the messages.db
fallback, run the `@lid`->phone merge and UNION both key forms before analyzing
(cookbook section 6). Verified: Cece `628118803084` = 2295 msgs in app.db vs 2 in
messages.db.

## F7. Duplicate profile from a display name (the vella -> cece trap)

Symptom: about to create `whatsapp_style_<pushname>.md` for someone who already has
a profile under a different slug.
Cause: slugging by display/push name instead of phone JID. Push names change
(Cece showed as "vella"), minting a duplicate.
Recovery: dedup by phone JID first. Before writing, check existing
`whatsapp_style_*.md` for that phone (in their `entities`/`aliases`/JID). If found,
UPDATE that file. If you already made a duplicate, merge it into the canonical one
and turn the stray into a one-line redirect, never leave two live profiles for one
human.

## F8. Service `failed` with "session limit" (runner-level, outside this skill)

Symptom: `systemctl --user status wa-behavior-learn.service` shows
`Active: failed`, log says "You've hit your session limit".
Diagnose: `tail -n 5 /tmp/wa-behavior-learn.log`.
Cause: the standalone `claude -p` runner consumes Christopher's shared Anthropic
session quota; when the quota is exhausted the run dies before doing anything.
Recovery: this is a launcher problem, not a skill problem. The timer is
`Persistent=true`, so a missed run re-fires. The durable fix is the redesign in
F10. Verified 2026-07-03 03:17: exit status 1, "session limit, resets 5:30am".

## F9. Main's WhatsApp drops after the run (a 2nd Baileys daemon)

Symptom: main session's WhatsApp connection dies around a cron run.
Cause: a headless claude that auto-loads the globally-enabled WhatsApp plugin can
spawn a SECOND Baileys daemon that steals the single socket
(feedback_whatsapp_single_session_rule).
Diagnose: `ps -eo pid,ppid,cmd | grep -i 'whatsapp/1.0.0' | grep -v grep`, look for
a daemon parented to the cron claude (not main, not wa-sender).
Recovery: kill the cron run's daemon only. Keeping THIS skill strictly SQLite-only
(no plugin, no `mcp__plugin_whatsapp_whatsapp__*`) is what prevents the second
daemon from ever being needed. Do not kill main's daemon or the wa-sender daemon.

## F10. Runner redesign (FOLLOWUP, outside this skill dir, do not edit from here)

The current unit (`~/.config/systemd/user/wa-behavior-learn.service`) runs:
```
ExecStart=/home/christopher/.local/bin/claude --dangerously-skip-permissions -p "/wa-behavior-learn" --max-turns 50
Environment=PATH=/home/christopher/.local/bin:/usr/local/bin:/usr/bin:/bin
```
Timer: `~/.config/systemd/user/wa-behavior-learn.timer`, `OnCalendar=*-*-* 03:17:00`,
`Persistent=true`. Two structural weaknesses remain, both LAUNCHER-level (a skill
edit cannot fix them, flag them to Christopher, do not touch the unit from this
task):
1. It spawns a competing `claude` that burns the shared session quota (F8).
2. Its PATH omits `~/.bun/bin` and linuxbrew. Irrelevant now that the skill is
   SQLite-only (`sqlite3` is `/usr/bin/sqlite3`, `python3` is `/usr/bin/python3`,
   both in the unit PATH), but it would bite again if anyone reintroduces a bun/MCP
   dependency.

Preferred durable design (memory-endorsed): the timer POKES the live main session
to run `/wa-behavior-learn` inside the already-authenticated session (tmux
send-keys or an attn trigger), instead of spawning a separate headless claude.
That removes the session-quota burn and any chance of a second Baileys socket.
This lives in the systemd unit + spawn config, NOT in SKILL.md.

---

## Quick health check (read-only, safe to run anytime)

```bash
systemctl --user status wa-behavior-learn.service --no-pager | head -12
tail -n 8 /tmp/wa-behavior-learn.log
ls -la "$HOME/.local/share/whatsapp-tui/app.db"* "$HOME/.config/whatsapp-mcp/messages.db"*
sqlite3 "file:$HOME/.local/share/whatsapp-tui/app.db?mode=ro" \
  "SELECT datetime(MAX(timestamp),'unixepoch','+7 hours') FROM messages;"
```
