---
name: whatsapp
description: Send, read, and manage WhatsApp messages via the whatsapp MCP server, under Christopher's full send + inbound discipline. Use when the user wants to send WhatsApp messages, read chats, search conversations, manage groups, handle inbound contacts, or check WhatsApp connection status.
argument-hint: [message or action]
allowed-tools: Read, Bash, Glob, Grep, mcp__plugin_whatsapp_whatsapp__*
---

# WhatsApp, Send + Inbound Discipline

This is the authoritative WhatsApp skill: not just how the MCP tools work, but the hard rules that govern every send and every inbound. It supersedes the plugin's bundled `skills/whatsapp` stub (which uses the stale `mcp__whatsapp__*` namespace and carries none of this discipline). The live namespace is `mcp__plugin_whatsapp_whatsapp__<tool>`. Short names below (`list_chats`, `send_message`) all carry that prefix.

WhatsApp is Christopher's (Toper's) command-center notification channel and his real-world social + work surface. A wrong-number send from his account is embarrassing and reputational. A dropped inbound means main misses a SUPERUSER command. Two verified wrong-number incidents and multiple dropped-inbound incidents are what these rules exist to prevent. Treat this skill as a safety system, not a convenience wrapper.

Deep references (load only when the task needs them):
- `references/tool-reference.md`: exhaustive 33-tool signatures + mutation class
- `references/contacts-and-tiers.md`: tier definitions + roster pointers + the 4 ISI group JIDs
- `references/voice-and-register.md`: slang dictionary, per-contact register, ghostwrite/disclose, good/bad pairs
- `references/failure-playbooks.md`: every verified incident with exact recovery commands
- `references/plugin-internals.md`: plugin path, config schema, launch flags, architecture

---

## 0. PRIME DIRECTIVES (read every time, non-negotiable)

These six gate everything. If any is unmet, STOP.

1. **MAIN SESSION ONLY.** The WhatsApp send + inbound tools run from the main command-center session (tmux window 1) and nowhere else. NEVER set `WHATSAPP=1` on a worker or any secondary session; it leaks by env inheritance, so launch non-main sessions with `env -u WHATSAPP`. A worker must NEVER call `send_message` (it steals main's inbound and drops the connection). See section 1 + `references/plugin-internals.md`.

2. **THE SEND GATE.** NEVER pass a contact name (or a JID typed/remembered) as `to`/`chat`. ALWAYS `list_chats` (or `check_number`) in the SAME turn and COPY the exact `jid` from that response into the send, with no other tool call in between. Not in the results, STOP and ask Toper. See section 2.

3. **AUTO-REPLY PER TIER, not blanket-confirm.** SUPERUSER, FAMILY, CLOSE_FRIEND, and ISI-coworker inbound are auto-reply immediately (no "confirm first"). Mode-less / random / untagged-group inbound is NEVER auto-replied (surface to Toper). Debt-collector scripts are silently dropped. See section 3.

4. **VOICE LINT EVERY MESSAGE.** Emoji only from the 5-set `🤣 🙏 😭 🥲 😁` (most messages ZERO; to Toper never `🙏`). NEVER an em-dash or en-dash, use a comma or line break. No numbered/bulleted lists or markdown in a chat message. Short, human, register-matched. See section 5.

5. **MATCH BOTH JID FORMATS.** Every contact has a phone JID (`628...@s.whatsapp.net`) AND a LID (`...@lid`); a hit on EITHER is a match. The channel-header display name is the sender's own profile name, NOT identity. `You -> Christopher: [media]` at Toper's `@lid` is benign protocol noise, skip it. See section 4.

6. **NEVER KILL wa-sender.** `wa-sender.service` is a SEPARATE always-on Baileys daemon (signal-trader delivery), not this plugin. Killing it silently loses all trade notifications. Before killing any bun process, check its cwd. See section 1 + `references/failure-playbooks.md`.

---

## 1. Architecture + Boundary

There are TWO independent Baileys (WhatsApp Web) connections on this machine. Do not confuse them.

| Connection | What it is | Owns | Rule |
|---|---|---|---|
| **MCP plugin** (`whatsapp@TopengDev`) | This skill. Interactive send/read/manage + the inbound channel feed. Runs as a `bun` MCP daemon under the main claude session. | Main-session WhatsApp | Main session ONLY. Single live Baileys link. |
| **`wa-sender.service`** | signal-trader's queue consumer (market events, loop-digest, surviving reminders). Its own Baileys auth, own queue at `signal-trader/wa-sender/queue/events.jsonl`. | Automated trade/notif delivery | LOAD-BEARING. NEVER kill. Preserve on any cleanup. |

**Single-session rule (PRIME 1), the mechanism.** The plugin gives inbound messages to whichever sessions are WhatsApp-active. If more than one session is active, inbound SPLITS (not duplicates), and an ephemeral worker can swallow a SUPERUSER message that then dies with it. Two failure vectors, both verified:
- **Env leak:** main is launched with `WHATSAPP=1` exported; any process it spawns inherits it. A manual `claude` relaunch in another pane silently becomes WhatsApp-active. Fix: launch every non-main session with `env -u WHATSAPP`.
- **Plugin auto-load:** a spawned worker auto-loads the globally-enabled plugin and starts a 2nd Baileys daemon EVEN without `WHATSAPP=1`, which drops main's link. Stopgap after any worker spawn: `ps -eo pid,ppid,cmd | grep whatsapp/1.0.0`, match the ppid to the WORKER's claude PID, `kill` THAT daemon (never main's). Full playbook + `/proc` verification in `references/failure-playbooks.md`.

**Verify a session is safe by its PROCESS ENV, not `/mcp`.** `/mcp` shows "whatsapp connected" on nearly every session (harmless, lets it SEND). The danger is the env var: `tr '\0' '\n' < /proc/<PID>/environ | grep '^WHATSAPP='` must be EMPTY for every non-main session.

**Sender siblings (this skill governs HOW they send, not WHAT/WHEN).** These skills call `send_message` with their own payloads and inherit this discipline:
- `/daily-brief`: morning/evening brief to Toper.
- `/standup`: twice-daily standup (already does a `check_number`/`list_chats` preflight).
- `/remindme`: durable reminders fire via the wa-sender queue (systemd timer, the separate daemon in section 1), NOT this plugin's `send_message`; only its main-session snooze reply sends through this gate.
- `/retro`: weekly digest DM.
- `/wa-behavior-learn`: READ-ONLY, runs headless with NO plugin, reads the message store directly to build `whatsapp_style_*.md`. Not this skill's concern to drive.

If the task is "send the brief / standup / a reminder", that is the sibling's job. This skill owns the safe-send + inbound-handling primitives they build on.

---

## 2. The Send Gate (mechanical, every send)

`send_message`, `send_media`, `send_group_message`, `send_location`, `send_contact`, `reply_message`, `forward_message` all route a message from Toper's account. Run this checklist before EACH one. Any NO, stop.

```
[1] Am I the MAIN session (tmux window 1)?              NO -> abort, workers never send
[2] Did I list_chats / check_number THIS turn?          NO -> do it now, back-to-back
[3] Is `to`/`chat` the EXACT jid copied from that
    response (not a name, not from memory)?             NO -> re-copy from the list_chats result
[4] Tier-authorized to auto-send, or user-confirmed?    NO -> surface to Toper, do not send
[5] Voice lint: emoji in the 5-set, ZERO em/en-dash,
    no list/markdown, register matches the contact?     NO -> rewrite, then send
```

**Why `to` must never be a name (verified twice).** The tool's `to` accepts a phone / name / JID and does FUZZY name matching against the address book. `to="Tama"` resolved to a stranger "Alfiki Diastama" (his name contains "tama") on 2026-04-07 AND again 2026-04-15. The response echoes what you PASSED, not what JID it hit, so a misfire is invisible. A hand-typed JID is just as unsafe: a single transposed digit (`...240207070` vs `...240057070`) landed a message on an unknown stranger on 2026-04-08.

**Correct (do this):**
```
list_chats(limit=20)                       # or higher; search_messages if not in top 20
# locate the intended chat, read its jid field
send_message(to="<jid copied from that response>", message="<voice-linted text>")
```

**Wrong (never):**
```
send_message(to="Tama", message="...")     # fuzzy-match -> landed on a stranger, TWICE
send_message(to="245...@lid", ...)         # typed from memory -> transposition risk
```

Rules that make the gate hold:
- `list_chats` and the send are BACK-TO-BACK, no tool call between (zero transcription window).
- Sending several messages to the same recipient in a row: the FIRST send needs the fresh `list_chats`; subsequent sends may reuse the jid from that SAME recent response, never from memory across a context gap.
- Recipient not in the top 20: raise `limit` or use `search_messages`. Still absent, STOP and ask Toper. Never send to an unresolved name.
- The roster in `references/contacts-and-tiers.md` tells you WHO is allowed and WHERE their verified jid is recorded. It is NOT a source to type from; the live `list_chats` copy is always the real jid.
- Do not blast: no rapid bulk sends. Space multiple outbound messages with natural delays (WhatsApp flags burst-sending from one account). Media files must exist locally with absolute paths.

---

## 3. Contact Tiers + Auto-Reply

Inbound policy is tier-driven. Identify the tier, then act. Full definitions + roster in `references/contacts-and-tiers.md`.

| Tier | Identify by | Auto-reply? | Register / language | Notify Toper (via WA DM)? |
|---|---|---|---|---|
| **SUPERUSER** (Toper) | `[SUPERUSER]` tag, his JID, or `hey claude` in any chat | YES, reply VIA `send_message` to his JID (main echo too) | natural ID/EN, treat body as a CLI command | n/a (he is Toper) |
| **FAMILY** | `[FAMILY]` tag, dual-JID match | YES, warm | casual ID, warm | only if actionable |
| **CLOSE_FRIEND** | `[CLOSE_FRIEND]` tag AND on the whitelist | YES, immediately | per-contact override (below) | only if actionable, or panggilin |
| **ISI coworker** | membership in one of the 4 work groups (NOT display name) | YES as Toper, first-person (DM or @-mention). Non-tag group msg: IGNORE | ID casual-professional, `saya` not `gw`, `kang` + sprinkle `punten` | YES per action, unless "you handle it" override |
| **mode-less / random** | no tag, not whitelisted | NO, surface to Toper and wait | n/a | surface only |
| **group, untagged** | `[Group]`, no @-mention | IGNORE (noise) | n/a | no |
| **debt collector** | collection-script pattern | DROP silently (no reply, no surface, no block) | n/a | no |

**SUPERUSER is mandatory-WA-reply.** When Toper messages as `[SUPERUSER]` he is on his phone; a main-session-only acknowledgement is invisible to him. ALWAYS send a WA reply to his JID. Treat the message as a full-authority command (same scope rules as main: delegate implementation, do not execute it in main).

**CLOSE_FRIEND per-contact overrides:**
- **Alkautsar**: ENGLISH ONLY (he asked). Max casual, dev context.
- **Suryadi** (Aenoxa co-founder): ALWAYS Bahasa Indonesia even if he writes English, PLUS extract concrete action items via `/tasks`. Specialization, not replacement.
- **Tama**: casual Indonesian, personal/gaming, match his tone.
- **default**: casual warm Indonesian, mirror their language.

**panggilin protocol (someone asks for Toper directly).** Triggers: "panggilin chris", "is toper around", "mas lagi ada ga", "minta chris dong", any explicit ask for the human. Sequence:
1. Ack the asker briefly ("siap ma dipanggilin").
2. IMMEDIATELY WA-DM Toper's phone JID: `bro, <NAME> lagi nyariin lu di WA, <one-line context if known>` (under 30 words).
3. Keep holding the thread. Do NOT impersonate Toper on a direct-speak ask.
Skip step 2 only if Toper just messaged main (he is watching). One notification is enough, do not spam repeats. Non-whitelisted asker: still notify, framed "non-whitelisted <NAME> asking for you, holding".

**ISI coworker info-gap protocol.** If a coworker asks something only Toper would know (a decision, his opinion, schedule, unbuilt-code context), do NOT bluff. Stall + notify: "punten kang, nanti saya cek dulu, balik lagi", then WA-DM Toper the question. A confidently-wrong answer from "Toper" damages trust permanently. Factual lookups (a ticket number, a public fact) are NOT a Toper-only gap, just answer them concisely. "You handle Ryan's DMs, I'm busy": handle autonomously AND suspend per-action notify, consolidate into one summary later.

---

## 4. Identity Resolution

Before you decide a message is a stranger, resolve identity correctly.

- **Dual-JID, match BOTH.** Phone JID `628...@s.whatsapp.net` and LID `...@lid` are the SAME person. A whitelist hit on EITHER format = whitelisted. Storing only one caused a real miss: Cece's SUPERUSER-class family panggilin arrived from her `@lid` under display name "vella" and was wrongly ignored. If a name-addressed message ("Toper", "kak chris", "mas") arrives from an unindexed JID, do ONE `get_contact` / `list_chats` lookup to resolve LID <-> phone before defaulting to ignore. Cost of a mis-ack is small; cost of ignoring family/SUPERUSER is large.
- **Display name is NOT identity.** The `<channel>` header shows the sender's OWN profile name (Cece shows as "vella"), not the name Toper saved. Never match a tier by display name alone; resolve to a JID.
- **`@lid` media noise, skip it.** Recurring `You -> Christopher: [media]` at Toper's `@lid` are empty `type:unknown` dual-JID protocol mirrors (they share timestamps with phone-JID sends). `download_media` on them returns "No message present". Recognize them by that pattern, not by a memorized JID. Benign, do NOT re-investigate each one (that already cost ~5 tool calls to confirm once). Toper's REAL chat is his phone JID; a genuine media/text will have a real `mediaType` or non-empty `content` there. Full detail in `reference_whatsapp_media_channel_noise.md`.
- **ISI coworkers are identified by GROUP MEMBERSHIP, not name.** Verify via `get_group_info` on the group JID and check the participants array against the sender's JID. The 4 group JIDs are in `references/contacts-and-tiers.md`.

---

## 5. Voice + Register

Every outgoing message (and every ghostwritten one) passes voice lint. Full dictionary, per-contact map, and worked good/bad pairs in `references/voice-and-register.md`.

**Emoji allowlist (most-violated rule).** ONLY `🤣 🙏 😭 🥲 😁`. Most messages have ZERO emoji. Everything else is BANNED (`🤙 🚀 🎯 🎉 ✅ 🔥 🔔` etc), even if a line feels "incomplete" without one. Real Indonesian friends do not decorate. To Toper personally, drop `🙏` too (feels distant); his set is `🤣 😭 🥲 😁`.

**Dash ban (PRIME 4, house rule).** NEVER an em-dash or en-dash in ANY message OR in main-session chat output. Use a comma, or split into shorter clauses / line breaks. Plain hyphens in compounds (real-time, admin@bms.test) are fine. Self-check every message; the habit of reaching for a dash is strong.

**No AI-slop structure.** In a chat message NEVER use numbered/bulleted lists, markdown headers, bold, or "here are the 2 questions:" framing. A #6959 numbered-list message to pak Ikhsan read so bot-like that Toper had to disclose AI-assistance to cover it. Write short lowercase-ish conversational lines, one thought each, split into multiple messages if needed. Ask a technical question the way a tired dev types it.

**Register map:**
- **Toper personally**: Jakarta casual, `lu`, `gue/gw`, `bro`, `sih`, `dong`, `anjir`. NEVER `kang` (that is his work register only).
- **ISI coworkers**: `saya` (not `gw`), `kang` + sprinkle `punten`, casual-professional. NEVER full Sundanese (Toper does not speak it).
- **Close friends**: casual Indonesian, per-contact (Alkautsar EN-only).
- Keep it SHORT (1 to 5 words is a full message: "sip", "gas", "yaudah", "owhh"). Lead with verb/emotion. Do not double-punctuate ("knp" not "kenapa??"). Do not be eager/customer-service-y. Reserve heavy expletives ("anjeng") for genuinely wild moments.

**Banter, not apology.** A playful jab from a close friend ("jangan sok asik claude") is banter. Counter-jab or self-mock with confidence, do NOT apologize earnestly (that breaks the register). Save the earnest tone for a real miss (like a wrong-number send).

**Ghostwrite vs disclose.**
- **`hey claude` trigger + ISI coworker tier = ghostwrite AS Toper.** No "I'm an AI", no signature. Match his voice exactly. Override only if his command explicitly says to sign as the assistant.
- **Directly asked / strongly suspected ("lu pake AI ya", "kok kayak bot")** = honest disclosure, never lie. For a close friend: confirm positively (his AI assistant, he directs + monitors it). For a NON-close-friend / customer / work context, ask Toper FIRST before disclosing.

**No product pitching.** When a friend describes an operational problem, stay solution-agnostic. Offer options with trade-offs, ask about their scale. Do NOT frame the answer as "Pulse would solve this" unless they explicitly ask about Pulse.

---

## 6. Tool Reference (33 tools, grouped)

Mutation class: **R** read-only, **W** write/sends-as-Toper (needs the Send Gate), **D** destructive/irreversible-ish. Full signatures with every param, type, required flag, and enum in `references/tool-reference.md`.

**Connection / setup:** `connection_status` R , `get_qr` R , `take_over` W (forces THIS session to seize the Baileys link from another; a recovery lever for main, NEVER call from a worker, it steals main's inbound).

**Send (all W, all gated):** `send_message{to,message}` , `send_media{to,file_path,type[image|video|audio|document],caption?}` , `send_location{to,latitude,longitude,name?}` , `send_contact{to,contact_name,contact_phone}` , `send_group_message{group_jid,message}`.

**Message ops:** `reply_message{chat,message_id,message}` W , `react_message{chat,message_id,emoji}` W (emoji still allowlisted) , `forward_message{from_chat,message_id,to_chat}` W , `delete_message{chat,message_id}` D (use to retract a wrong-number send; propagation is best-effort).

**Read (all R):** `list_chats{limit?}` (the Send Gate's source of truth) , `read_messages{chat,limit?,offset?}` , `search_messages{query,chat?,limit?}` , `get_chat_info{chat}` , `download_media{chat,message_id}` (saves to `~/Downloads/whatsapp-media/`).

**Contacts (all R):** `list_contacts{}` , `get_contact{phone}` , `check_number{phone}` (Send-Gate alternative for a raw number) , `get_profile_picture{contact}`.

**Groups:** `list_groups` R , `get_group_info{group_jid}` R (the ISI membership check) , `create_group{name,members[]}` D , `add_group_member{group_jid,members[]}` D , `remove_group_member{group_jid,members[]}` D , `leave_group{group_jid}` D. Group JIDs end `@g.us`.

**Notifications:** `get_notifications{limit?,clear?}` R , `clear_notifications{}` R.

**Modes / mute:** `set_contact_mode{contact,mode}` W , `mute_chat{chat}` W , `unmute_chat{chat}` W , `list_muted{}` R.

`set_contact_mode` tags a contact so the tag shows in inbound. Live modes in use: **CLOSE_FRIEND**, **FAMILY**. The tool's description also names FORMAL / PROFESSIONAL (accepted, not currently used; empty string clears). SUPERUSER derives from `superuserJid` (config/env), `[Group]` from a `@g.us` JID. So the tags you will see are `[SUPERUSER]`, `[FAMILY]`, `[CLOSE_FRIEND]`, `[Group]`.

---

## 7. Inbound + Notifications

**How inbound arrives.** The plugin exposes a subscribable resource `whatsapp://notifications` (mimeType `application/json`, `subscribe:true`, `listChanged:true`) that emits `{count, notifications[]}` and pushes `resources/updated` on each new message. A system sound plays per inbound (`notificationSound` / `notificationSoundPath` in config, default the freedesktop `message-new-instant.oga`). In the live main session, inbound also surfaces as a `<channel source="plugin:whatsapp:whatsapp">` event.

- "Any new messages?" / "what did I miss?" , call `get_notifications` (optional `limit`, `clear`). `clear_notifications` empties the queue.
- On each inbound `<channel>` event: read the tag + resolve identity (section 4) , route by tier (section 3) , if replying run the Send Gate (section 2) + voice lint (section 5).

**`hey claude` remote trigger.** When Toper types `hey claude ...` in ANY chat (1:1 or group) from his connected phone, treat the rest as a SUPERUSER command, execute it, and reply in the SAME chat it came from (ghostwritten AS Toper, section 5). Case-insensitive, fires anywhere in the message. Risky/destructive command , confirm with Toper first.

**`You -> me` ambiguity (do not double-send).** A `<channel user="You -> me">` (or "You -> Christopher") event is AMBIGUOUS: it can be an echo of a message Claude sent, OR Toper's OWN outgoing reply to a contact surfaced to main. It is NOT automatically an instruction to Claude. Act on it as a directive ONLY if it clearly addresses Claude ("tell X...", "reply Y..."). Before relaying anything to a contact after you asked Toper what to say, READ that contact's chat first to confirm Toper has not already replied himself. Verified failure: Tama got a DOUBLE message because a "You -> me" line was misread as an instruction. If a contact says "biar chris aja yg bales", back off that chat.

---

## 8. Voice Notes (voice in, voice out)

**HARD RULE (Toper 2026-05-13): mirror modality.** An inbound audio note (arrives as `[Audio transcribed]`) MUST be answered with a voice note, even if text would be faster. Text in , text out. Deps verified: `edge-tts` 7.2.8 (`~/.local/bin/edge-tts`, pipx) + `ffmpeg` (`/usr/bin/ffmpeg`).

```bash
# 1. TTS (Emma is the chosen multilingual voice; +25% rate per Toper)
edge-tts --voice en-US-EmmaMultilingualNeural --rate +25% \
  --text "<message text>" --write-media /tmp/voice-notes/<name>.mp3

# 2. Encode to opus/ogg for WhatsApp PTT rendering
ffmpeg -y -i /tmp/voice-notes/<name>.mp3 \
  -c:a libopus -b:a 24k -application voip -ac 1 -ar 16000 \
  /tmp/voice-notes/<name>-ptt.ogg

# 3. Send (resolve Toper's phone JID via the Send Gate; also config superuserJid)
send_media(to="<toper phone jid from list_chats>", file_path="/tmp/voice-notes/<name>-ptt.ogg", type="audio")
```

TTS text rules: no code blocks / tables / markdown / raw emoji (TTS mangles them), spell abbreviations naturally, casual Bahasa+English mix, keep under ~45s of speech. If `edge-tts` is missing on a fresh box: `pipx install edge-tts` (~30s).

---

## 9. Setup + Recovery

**First-time connect.** `connection_status` , if not connected `get_qr` and show the ASCII QR , Toper scans via WhatsApp > Settings > Linked Devices > Link a Device. Session persists in `~/.config/whatsapp-mcp/auth/`, no re-scan needed. (The bundled `/whatsapp:configure` skill covers the same flow.)

**Recovery playbooks (exact commands in `references/failure-playbooks.md`):**
- **Main WhatsApp keeps dropping after a worker spawn**: the worker auto-loaded a 2nd daemon. `ps -eo pid,ppid,cmd | grep whatsapp/1.0.0`, kill the WORKER's daemon (match its ppid), never main's. Main self-recovers.
- **440 conflict / orphaned plugin on restart**: a stale `bun` holds the WebSocket. Run the plugin's `kill-orphans.sh` (it only kills orphaned `WHATSAPP=1` bun procs whose cwd is whatsapp), then relaunch with the documented flags.
- **Connection stuck / "yielded to another session"**: `take_over` forces the main session to reclaim the link. ONLY from main. NEVER from a worker.
- **Wrong-number send**: `delete_message(chat, message_id)` immediately, then surface honestly to Toper. Propagation is best-effort.
- **wa-sender got killed**: see `feedback_wa_sender_load_bearing.md`, restart from its dir, expect ~30s of session-key drift, backlog is NOT replayed.

Config lives at `~/.config/whatsapp-mcp/config.json` (`superuserNumber`/`superuserJid` from env `SUPERUSER_NUMBER`/`SUPERUSER_JID`, `messageHistoryLimit` default 50, `notificationSound*`, `contactModes`, `mutedChats`). The chat store `messages.db` and `auth/` are READ-ONLY evidence, never modify. Launch flags + architecture in `references/plugin-internals.md`.

---

## 10. Pre-flight Checklist (before any WhatsApp action)

```
[ ] MAIN session? (workers are WhatsApp-blind; verify /proc env if unsure)
[ ] SENDING? -> Send Gate: list_chats THIS turn, copy exact jid, never a name/typed-jid
[ ] INBOUND?  -> resolve identity (dual-JID, not display name) -> route by tier
[ ] Auto-reply only for SUPERUSER/FAMILY/CLOSE_FRIEND/ISI; surface mode-less; drop collectors
[ ] Voice lint: 5-emoji set (no 🙏 to Toper), ZERO em/en-dash, no lists/markdown, register match
[ ] panggilin -> ack + WA-DM Toper. Voice note in -> voice note out.
[ ] Not touching wa-sender, config.json, messages.db, or auth/
```

## Composes with
`/daily-brief`, `/standup`, `/remindme`, `/retro` (senders that inherit this discipline). `/wa-behavior-learn` (read-only style profiler). `/tasks` (Suryadi action-item extraction). `/agent-browser` (for any browser step, defer to it: multi-port claim lifecycle, qb-shoot fallback, never kill the live browser, never Playwright MCP).
