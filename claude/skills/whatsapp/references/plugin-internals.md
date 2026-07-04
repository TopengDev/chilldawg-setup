# Plugin Internals

Verified against the installed plugin this session. For the discipline that USES this, see SKILL.md.

## Identity + stack
- Plugin: `whatsapp@TopengDev` version `1.0.0`, MIT, repo `TopengDev/whatsapp-mcp-plugin`.
- Path: `~/.claude/plugins/cache/TopengDev/whatsapp/1.0.0/`.
- Stack: `bun` + Baileys (`@whiskeysockets`), a stdio MCP server (`src/index.ts`, `src/whatsapp.ts`, `src/config.ts`, `src/database.ts`, `src/enrichment.ts`).
- It ships its OWN bundled `skills/whatsapp/SKILL.md` (87 lines, stale `mcp__whatsapp__*` namespace) and `skills/configure/SKILL.md` (35 lines). This user skill is the authoritative overlay: correct namespace + full discipline. Treat the bundled copy as the vendor stub.

## Live namespace
Every tool is `mcp__plugin_whatsapp_whatsapp__<tool>`. The bundled stub's `mcp__whatsapp__*` is stale, do not use it.

## Config
File: `~/.config/whatsapp-mcp/config.json` (auto-created from defaults on first run). Schema (`src/config.ts`):

| Key | Default | Notes |
|---|---|---|
| `authDir` | `~/.config/whatsapp-mcp/auth` | Baileys credentials. READ-ONLY, never modify. |
| `mediaDownloadDir` | `~/Downloads/whatsapp-media` | Where `download_media` saves. Dir exists. |
| `databasePath` | `~/.config/whatsapp-mcp/messages.db` | Chat store. READ-ONLY evidence. |
| `autoReconnect` | `true` | |
| `maxReconnectAttempts` | `10` | |
| `messageHistoryLimit` | `50` | |
| `notificationSound` | `true` | System sound per inbound. |
| `notificationSoundPath` | `/usr/share/sounds/freedesktop/stereo/message-new-instant.oga` | |
| `superuserNumber` | env `SUPERUSER_NUMBER` | Never print the value. |
| `superuserJid` | env `SUPERUSER_JID` | Source of the `[SUPERUSER]` tag. Never print the value. |
| `mutedChats` | `[]` | JIDs/names. Managed by `mute_chat`/`unmute_chat`. |
| `contactModes` | `{}` | contact -> mode. Live values in use: CLOSE_FRIEND, FAMILY. Managed by `set_contact_mode`. |

Do NOT edit config.json, messages.db, messages.db-wal/-shm, or auth/ from this skill. They are live-written by the running bridge and are read-only evidence.

## Architecture (two connections, one link each)
1. **This MCP plugin**: the ONE interactive Baileys link, owned by the main session. Single-session rule applies (SKILL.md section 1).
2. **`wa-sender.service`**: signal-trader's SEPARATE Baileys queue consumer (own auth, queue at `signal-trader/wa-sender/queue/events.jsonl`). LOAD-BEARING, never kill. Not driven by this skill.

Session registry: each claude session that loads the plugin registers a PID under `~/.claude/plugins/cache/TopengDev/whatsapp/1.0.0/.in_use/` (per `reference_wa_behavior_learn_headless.md`); only the session that loaded the plugin can drive the live tools. Headless `claude -p` runs do NOT get the plugin, which is why `/wa-behavior-learn` reads the message store directly instead.

## Launch (main session only)
```
WHATSAPP=1 claude --dangerously-load-development-channels plugin:whatsapp@TopengDev \
  --dangerously-skip-permissions --resume
```
- `WHATSAPP=1` , makes THIS session the WhatsApp-active one (subscribes to inbound). Main only.
- `--dangerously-load-development-channels plugin:whatsapp@TopengDev` , required, the plugin is not on Claude Code's approved channel allowlist.
- Do NOT also dev-load `plugin:attn@s0nderlabs`, attn is already approved and double-loading it breaks WhatsApp channel delivery.
- Every NON-main session launches with `env -u WHATSAPP` to defeat the env leak.

## Inbound delivery (why messages surface inline)
`src/index.ts` sets `resources: { subscribe: true, listChanged: true }` and `tools: { listChanged: true }`, exposes the resource `whatsapp://notifications`, and on each inbound calls `sendResourceUpdated`. The plugin was patched (`reference_whatsapp_plugin_fix.md`) for three delivery bugs: Bun stdout buffering (multi-point `Bun.stdout.flush()`), the `listChanged` capability, and a `tools/list_changed` nudge to kick Claude Code's idle processing loop. It also handles stdin-EOF for clean shutdown (orphan/440 prevention). Do not re-derive these; cite that memory.

## Phone normalization (real behavior, verified)
`normalizePhoneNumber` (`src/whatsapp.ts`): strips non-digits, and `08xxx` becomes `628xxx` (`num.startsWith("08")` -> `"62" + num.slice(1)`), then `resolveJid` appends `@s.whatsapp.net`. So a raw Indonesian `08...` number is accepted and normalized. This does NOT make name-based `to` safe, the Send Gate still applies; normalization only helps when you legitimately have a phone number and confirm via `check_number`.

## Recovery scripts
- `kill-orphans.sh` (in the plugin dir) , scoped cleaner: kills only orphaned bun procs that have `WHATSAPP=1` in their environ, run `src/index.ts`, and whose cwd contains "whatsapp". Requires `WHATSAPP=1` in its own env or it exits 0. Use for the 440 conflict.
- `take_over` tool , forces this session to reclaim the connection (main only).

## Store (read-only)
`messages.db` (~70MB, WAL-active) schema: `messages(id, chat_jid, sender_jid, sender_name, content, message_type, timestamp, is_from_me, quoted_message_id, media_type, media_url, raw_json)`, `contacts(jid, name, notify_name, phone)`. Personal 1:1 chats are often keyed by `@lid` here; the whatsapp-tui `app.db` is phone-JID-keyed and fuller (that is `/wa-behavior-learn`'s concern, not this skill's). Open read-only (`?mode=ro`) if you ever must query; never write.
