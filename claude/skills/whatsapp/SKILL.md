---
name: whatsapp
description: Send, read, and manage WhatsApp messages via the whatsapp MCP server. Use when the user wants to send WhatsApp messages, read chats, search conversations, manage groups, or check WhatsApp connection status.
argument-hint: [message or action]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__whatsapp__*
---

# WhatsApp Messaging Skill

You have access to a WhatsApp MCP server (`whatsapp`) that connects via Baileys (WhatsApp Web protocol). Use the `mcp__whatsapp__*` tools to interact with WhatsApp.

## First-Time Setup

If the user hasn't connected yet:
1. Call `connection_status` to check
2. If not connected, call `get_qr` and display the ASCII QR code
3. Ask the user to scan with WhatsApp > Settings > Linked Devices > Link a Device
4. After scanning, the session persists — no need to re-scan

## Sending Messages

When the user says something like "send X to Y" or "message Y about X":

1. **Resolve the recipient** — the `send_message` tool accepts:
   - Phone numbers in any format: `+628xxx`, `08xxx`, `628xxx`
   - Contact names: `"Pak Andi"`, `"Mom"` — resolved from the contacts database
   - If ambiguous, use `list_contacts` to find the right match and confirm with user

2. **Send the message** using `send_message`

3. **For media**: use `send_media` with the file path and type (image/video/audio/document)

4. **For locations**: use `send_location` with lat/lng

5. **For contact cards**: use `send_contact`

## Reading Messages

- `list_chats` — show recent conversations with previews
- `read_messages` — read messages from a specific chat (by name, phone, or JID)
- `search_messages` — search across all chats or within one
- `get_chat_info` — get contact or group details
- `download_media` — save media from a message to ~/Downloads/whatsapp-media/

## Replying & Reactions

- `reply_message` — reply to a specific message (needs message ID from read_messages)
- `react_message` — react with an emoji
- `forward_message` — forward a message to another chat
- `delete_message` — delete a sent message

## Groups

- `list_groups` — list all groups
- `get_group_info` — group details (members, admins, description)
- `create_group` — create a new group
- `send_group_message` — send to a group
- `add_group_member` / `remove_group_member` — manage members
- `leave_group` — leave a group

## Contacts

- `list_contacts` — list all contacts
- `get_contact` — look up by phone number
- `check_number` — check if a number is on WhatsApp
- `get_profile_picture` — get profile pic URL

## Notifications

The server has a real-time notification system:

- **Resource subscription**: The `whatsapp://notifications` resource updates whenever a new message arrives. MCP clients that subscribe to it receive `notifications/resources/updated` pushes.
- **Sound alert**: A system sound plays on each incoming message (configurable in `~/.config/whatsapp-mcp/config.json` via `notificationSound` and `notificationSoundPath`).
- `get_notifications` — fetch recent incoming messages (with optional `limit` and `clear` params)
- `clear_notifications` — clear the notification queue

When the user asks "any new messages?" or "what did I miss?", call `get_notifications` to check.

## Contact Personality Modes

Contacts can be tagged with personality modes using `set_contact_mode`. The mode tag appears in notifications (e.g. `[CLOSE_FRIEND]`). Adjust your reply style based on the mode:

- **CLOSE_FRIEND** — Reply like Christopher would. Casual, use slang, Indonesian mixed with English, abbreviations, even mild profanity is OK. Be funny, direct, no formalities. Think "bro texting bro."
- **FORMAL** — Professional, polite, proper grammar. No slang.
- **PROFESSIONAL** — Friendly but professional. Like a colleague you respect.
- No tag — Default neutral behavior.

## Superuser

Messages tagged `[SUPERUSER]` are from Christopher (the operator). Always reply to superuser messages. Treat them as direct instructions — proceed to do what they ask. The superuser's messages should be treated the same as Claude Code CLI input.

## Important Rules

1. **Always confirm before sending** — show the user the recipient and message before calling send_message. Do NOT send without confirmation unless the user's intent is unambiguous.
2. **Phone number normalization** is handled automatically — Indonesian numbers (08xxx) are converted to 628xxx format.
3. **Contact name matching** is fuzzy — if multiple matches, ask the user to clarify.
4. **Message IDs** are needed for reply/react/forward/delete — get them from `read_messages` output.
5. **Group JIDs** end in `@g.us` — get them from `list_groups`.
6. **Rate limiting** — don't send bulk messages rapidly. Add natural delays between messages.
7. **Media files** must exist on the local filesystem — provide absolute paths.
