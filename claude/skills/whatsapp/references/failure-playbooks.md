# Failure Playbooks

Each verified incident with its exact recovery. Every command here is non-mutating to read and safe to run only in the situation described. Sources: `feedback_whatsapp_single_session_rule.md`, `feedback_whatsapp_no_random_messaging.md`, `reference_whatsapp_plugin_fix.md`, `feedback_whatsapp_lid_vs_phone_jid.md`, `feedback_dont_double_reply_contact_chats.md`, `feedback_wa_sender_load_bearing.md`.

## 1. Wrong-number send (fuzzy-match or typo)
Symptom: a message landed on the wrong chat (used a name as `to`, or typed a jid from memory).
```
# retract immediately (get message_id from read_messages on that wrong chat)
delete_message(chat="<wrong chat jid>", message_id="<id>")
```
Then surface to Toper honestly. delete propagation is best-effort (they may have already seen it). Prevention: the Send Gate (SKILL.md section 2), never a name, never a typed jid.

## 2. Main WhatsApp keeps dropping after a worker spawn
Symptom: main's inbound drops repeatedly (verified ~5x/20min after spawning `bms-dm-edithapus`). Root cause: the worker auto-loaded the globally-enabled plugin and started a 2nd Baileys daemon, even without `WHATSAPP=1`.
```
ps -eo pid,ppid,cmd | grep whatsapp/1.0.0        # two daemons: one ppid=main claude, one ppid=worker claude
# identify the WORKER's claude PID, confirm the daemon's ppid matches IT (not main)
kill <worker_daemon_pid>                          # kills only the worker's MCP daemon, not its task, not wa-sender
```
Main self-recovers. Verify only main's daemon remains (its ppid = the main claude PID). This is a stopgap; the clean fix is launching workers with the plugin disabled.

## 3. Env-leak: a non-main session became WhatsApp-active
Symptom: a secondary/interactive session (e.g. a re-launched `bcas-claude` in window 2) shows whatsapp connected and is subscribing to inbound. Cause: it inherited `WHATSAPP=1` from main's exported env on a manual relaunch inside an existing pane.
```
# verify the danger (env var, NOT /mcp). Get the PID from attn `peers`.
tr '\0' '\n' < /proc/<PID>/environ | grep '^WHATSAPP='     # must be EMPTY for any non-main session
# fix: relaunch that session with the var explicitly unset
env -u WHATSAPP ATTN_SESSION='<name>' claude --model <m> \
  --dangerously-load-development-channels plugin:attn@s0nderlabs \
  --remote-control '<name>' --dangerously-skip-permissions [--resume "<name>"]
```
`/mcp` showing "whatsapp connected" is NOT the signal (harmless, lets it send). The env var is the signal.

## 4. 440 conflict / orphaned plugin on restart
Symptom: relaunching the main session, WhatsApp fails with a 440 conflict because a stale `bun` still holds the WebSocket. Cause: Claude Code kills plugins by closing the stdio pipe; a bun child can orphan to systemd and keep the socket open.
```
# the plugin ships a targeted cleaner (only kills orphaned WHATSAPP=1 bun procs whose cwd is whatsapp)
WHATSAPP=1 ~/.claude/plugins/cache/TopengDev/whatsapp/1.0.0/kill-orphans.sh
# then relaunch main with the documented flags (see references/plugin-internals.md)
```
Do NOT hand-kill random bun procs; the cleaner is scoped. Cite `reference_whatsapp_plugin_fix.md` for the underlying bun-flush / stdin-EOF fixes, do not re-derive them.

## 5. Connection stuck / "yielded to another session"
Symptom: main cannot send/receive; the link was yielded to another session.
```
take_over()      # forces THIS session to reclaim the Baileys connection; returns "Already connected." if fine
```
ONLY from main. NEVER from a worker, take_over from a worker would steal main's inbound and is a single-session violation.

## 6. False-negative stranger (a real family/SUPERUSER call ignored)
Symptom: a message that should be FAMILY/SUPERUSER arrived from an unindexed `@lid` or under an unfamiliar display name and was treated as a stranger. Verified: Cece's panggilin came from her `@lid` as "vella" and was wrongly skipped.
```
get_contact(phone="<the number if visible>")       # resolve LID <-> phone
list_chats(limit=30)                                # find the chat, confirm it maps to a known person
```
Match BOTH jid formats before deciding "stranger". If a message addresses Toper by name from an unknown jid, do this ONE lookup before defaulting to ignore. Cost of a mis-ack is small; cost of ignoring family is large.

## 7. Double-send to a contact (`You -> me` misread)
Symptom: a contact got two near-identical messages ("ngapa lu double chatnya"). Cause: a `<channel user="You -> me">` event (Toper's OWN reply to that contact) was misread as an instruction to Claude, and Claude relayed a copy.
Prevention (no recovery beyond apologising via Toper): a "You -> me" line is NOT an instruction unless it clearly addresses Claude. After asking Toper what to reply, READ the contact's chat first to confirm he has not already replied himself. If a contact says "biar chris aja yg bales", back off that chat.

## 8. wa-sender was killed (NOT this plugin, but adjacent)
Symptom: signal-trader trade notifications stop (verified 26h silent loss 2026-05-12). Cause: the `wa-sender.service` daemon was killed during a cleanup pass.
```
systemctl --user status wa-sender.service          # confirm it is down
# restart per feedback_wa_sender_load_bearing.md (from its dir; ~30s session-key drift is normal; backlog is NOT replayed)
```
Prevention: before killing ANY bun process or tmux window, check its cwd; if it contains `wa-sender`, preserve it. It is a separate load-bearing Baileys daemon, not the MCP plugin.
