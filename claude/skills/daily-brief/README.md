# daily-brief

Morning + evening WhatsApp brief for Christopher.

- **Recipient:** Toper JID `107838240207070@lid`
- **Schedule:** 06:00 WIB (morning) + 21:00 WIB (evening), via systemd user timers
- **Data sources:** `~/.claude/tasks/*.md` + Google Calendar MCP
- **Send tool:** `mcp__plugin_whatsapp_whatsapp__send_message`

## Files

- `SKILL.md` — the skill itself (what Claude reads and executes)
- `~/.config/systemd/user/daily-brief-morning.{service,timer}` — 6 AM trigger
- `~/.config/systemd/user/daily-brief-evening.{service,timer}` — 9 PM trigger
- `~/.local/share/daily-brief/log/{mode}-YYYY-MM-DD.log` — per-run logs
- `~/.local/share/daily-brief/last-run-{morning,evening}` — idempotency lock
- `~/.local/share/daily-brief/calendar-oauth-sent` — OAuth-nag sentinel (created once)

## Install / enable timers

```bash
systemctl --user daemon-reload
systemctl --user enable --now daily-brief-morning.timer
systemctl --user enable --now daily-brief-evening.timer

# Verify
systemctl --user list-timers | grep daily-brief
```

## Manual test

```bash
# Dry-run (no WhatsApp send, prints formatted message)
claude --dangerously-skip-permissions -p "/daily-brief morning --dry-run"
claude --dangerously-skip-permissions -p "/daily-brief evening --dry-run"

# Real run
claude --dangerously-skip-permissions -p "/daily-brief morning"
```

## First-time Google Calendar OAuth

Christopher hasn't authenticated Google Calendar yet.

- First morning brief will send normally with a `⚠️ Calendar not connected yet` line + OAuth URL.
- Open the URL, approve access, then from any Claude session run `mcp__claude_ai_Google_Calendar__complete_authentication` (or reply "calendar ok" — main session handles it).
- After auth: subsequent briefs pull events automatically. The OAuth nag won't repeat.

## Disable / pause

```bash
systemctl --user disable --now daily-brief-morning.timer
systemctl --user disable --now daily-brief-evening.timer
```

## Logs

```bash
# Recent systemd output
journalctl --user -u daily-brief-morning.service -n 50
journalctl --user -u daily-brief-evening.service -n 50

# Skill-level logs
ls -lt ~/.local/share/daily-brief/log/
tail ~/.local/share/daily-brief/log/morning-$(TZ=Asia/Jakarta date +%F).log
```

## Conflict prevention

- Send-only. Never reads inbox, never auto-replies.
- Idempotent: minute-granularity lock prevents double-send if timer fires twice in same minute.
- Read-only access to `~/.claude/tasks/*.md`.
- Hard-coded recipient JID — cannot send to anyone else.
