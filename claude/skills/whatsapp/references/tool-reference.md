# Tool Reference , all 33 tools

Live namespace: `mcp__plugin_whatsapp_whatsapp__<tool>`. Signatures verified against plugin source `src/index.ts` (whatsapp@TopengDev 1.0.0). Mutation class: **R** read-only, **W** writes/sends as Toper (needs the Send Gate in SKILL.md section 2), **D** destructive or irreversible-ish.

`{req}` marks a required param. `?` marks optional.

## Connection / setup

| Tool | Params | Class | Notes |
|---|---|---|---|
| `connection_status` | none | R | Is the Baileys link up. |
| `get_qr` | none | R | ASCII QR for first-time linking. |
| `take_over` | none | W | Forces THIS session to grab the WhatsApp connection from whatever session holds it. If already connected, returns "Already connected." Recovery lever for MAIN when the link is stuck / yielded. NEVER from a worker (it steals main's inbound, violates single-session). |

## Send (all W, all pass the Send Gate)

| Tool | Params | Class | Notes |
|---|---|---|---|
| `send_message` | `to{req}`, `message{req}` | W | `to` accepts phone/name/JID but ONLY a jid copied from a same-turn `list_chats` is safe. Name = fuzzy-match hazard. |
| `send_media` | `to{req}`, `file_path{req}`, `type{req}` enum `image\|video\|audio\|document`, `caption?` | W | File must exist locally, absolute path. `type=audio` + an opus/ogg file renders as a WhatsApp voice note (PTT). |
| `send_location` | `to{req}`, `latitude{req}` number, `longitude{req}` number, `name?` | W | GPS pin. |
| `send_contact` | `to{req}`, `contact_name{req}`, `contact_phone{req}` | W | Shares a contact card. |
| `send_group_message` | `group_jid{req}`, `message{req}` | W | `group_jid` ends `@g.us`. Only send to a group when explicitly intended (ISI @-mention reply, or a Toper directive). |

## Message operations

| Tool | Params | Class | Notes |
|---|---|---|---|
| `reply_message` | `chat{req}`, `message_id{req}`, `message{req}` | W | Threaded reply. `message_id` comes from `read_messages`. |
| `react_message` | `chat{req}`, `message_id{req}`, `emoji{req}` | W | Emoji still allowlisted (`🤣 🙏 😭 🥲 😁`). |
| `forward_message` | `from_chat{req}`, `message_id{req}`, `to_chat{req}` | W | Both chats need gate-resolved jids. |
| `delete_message` | `chat{req}`, `message_id{req}` | D | Retract a sent message. Primary wrong-number remedy. Propagation is best-effort (recipient may have seen it). |

## Read (all R)

| Tool | Params | Class | Notes |
|---|---|---|---|
| `list_chats` | `limit?` number | R | THE Send Gate source of truth. Raise `limit` (>=20) if the target is not near the top. |
| `read_messages` | `chat{req}`, `limit?`, `offset?` | R | Message history for one chat, yields the `message_id`s. |
| `search_messages` | `query{req}`, `chat?`, `limit?` | R | Find a chat/message when it is not in the recent list. |
| `get_chat_info` | `chat{req}` | R | Details of a 1:1 or group chat. |
| `download_media` | `chat{req}`, `message_id{req}` | R | Saves media to `~/Downloads/whatsapp-media/`. On an `@lid` protocol-noise blip it returns "No message present" (expected, see SKILL.md section 4). |

## Contacts (all R)

| Tool | Params | Class | Notes |
|---|---|---|---|
| `list_contacts` | none | R | Full address book. |
| `get_contact` | `phone{req}` | R | Resolve a number, and the LID <-> phone pairing. |
| `check_number` | `phone{req}` | R | Is a raw number on WhatsApp; Send-Gate alternative for a phone you were handed. Returns `{exists, jid}`. |
| `get_profile_picture` | `contact{req}` | R | Profile photo URL. |

## Groups

| Tool | Params | Class | Notes |
|---|---|---|---|
| `list_groups` | none | R | All groups + their `@g.us` JIDs. |
| `get_group_info` | `group_jid{req}` | R | Members, admins, description. THE ISI-coworker membership check (participants array vs sender JID). |
| `create_group` | `name{req}`, `members{req}` string[] | D | Creates a group. Confirm with Toper first. |
| `add_group_member` | `group_jid{req}`, `members{req}` string[] | D | Confirm first. |
| `remove_group_member` | `group_jid{req}`, `members{req}` string[] | D | Confirm first. |
| `leave_group` | `group_jid{req}` | D | Irreversible from this side. Confirm first. |

## Notifications

| Tool | Params | Class | Notes |
|---|---|---|---|
| `get_notifications` | `limit?`, `clear?` boolean | R | Recent inbound. "Any new messages?" routes here. |
| `clear_notifications` | none | R | Empties the queue. |

Also a subscribable resource `whatsapp://notifications` (mimeType `application/json`, `subscribe:true`, `listChanged:true`) emits `{count, notifications[]}` and pushes `resources/updated` per inbound.

## Modes / mute

| Tool | Params | Class | Notes |
|---|---|---|---|
| `set_contact_mode` | `contact{req}`, `mode{req}` | W | Tags a contact; the tag shows in inbound. Live modes: **CLOSE_FRIEND**, **FAMILY**. Description also names FORMAL / PROFESSIONAL (accepted, unused). Empty `mode` clears. |
| `mute_chat` | `chat{req}` | W | No notifications unless mentioned. |
| `unmute_chat` | `chat{req}` | W | Unmute. |
| `list_muted` | none | R | Current muted chats (config `mutedChats`). |

## Tags you will see in inbound
`[SUPERUSER]` (derives from config `superuserJid`), `[FAMILY]`, `[CLOSE_FRIEND]` (from `set_contact_mode`), `[Group]` (any `@g.us` sender). Route each per SKILL.md section 3.
