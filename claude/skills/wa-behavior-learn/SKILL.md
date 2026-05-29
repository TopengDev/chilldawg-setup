---
name: wa-behavior-learn
description: Analyze WhatsApp chat history from all contacts to learn communication styles and write per-contact memory files. Run daily to keep style profiles fresh.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__plugin_whatsapp_whatsapp__list_contacts, mcp__plugin_whatsapp_whatsapp__read_messages, mcp__plugin_whatsapp_whatsapp__list_chats
---

# WhatsApp Behavior Learning Skill

Reads recent WhatsApp chat history from **all contacts**, analyzes each person's communication style, and writes/updates per-contact memory files so future replies sound natural.

## Procedure

### Step 1: Get Active Contacts

1. Call `mcp__plugin_whatsapp_whatsapp__list_chats` to get recent conversations
2. Call `mcp__plugin_whatsapp_whatsapp__list_contacts` to get the full contact list with names and modes
3. Filter to **individual chats only** (skip groups — JIDs ending in `@g.us`)
4. Prioritize contacts with recent activity (messages in the last 7 days)

### Step 2: Read Chat History

For each active contact:

1. Call `mcp__plugin_whatsapp_whatsapp__read_messages` with `chat: "<contact name or JID>"` and `limit: 50`
2. Separate messages into:
   - **Their messages** (from the contact) — this is what we analyze
   - **Our messages** (from Christopher) — useful for context but not the analysis target

### Step 3: Analyze Communication Style

For each contact's messages, extract these dimensions:

1. **Language** — Primary language (Indonesian, English, mixed). Note code-switching patterns.
2. **Message length** — Average word count. Do they send one-liners or paragraphs? Do they split into many short messages or send one long one?
3. **Tone** — Formal, casual, playful, sarcastic, dry, energetic. How do they greet? How do they sign off?
4. **Slang & abbreviations** — Specific slang they use (e.g., "bgst", "anjir", "gelo", "wkwk", "lol"). List the actual words they use, not generic categories.
5. **Emoji usage** — Which emojis do they use? How often? Do they use stickers?
6. **Common phrases** — Catchphrases, verbal tics, recurring expressions (e.g., always starts with "eh", always says "gas" to agree)
7. **Punctuation style** — Periods? Exclamation marks? No punctuation? Ellipses?
8. **Response patterns** — Do they ask questions? Give short acknowledgments? Send voice notes? React with emojis?
9. **Topics** — What do they usually talk about? (work, gaming, memes, etc.)

### Step 4: Write Memory Files

For each analyzed contact, write a memory file at:
`~/.claude/memory/whatsapp_style_<contact_slug>.md`

Where `<contact_slug>` is the contact name lowercased, spaces replaced with underscores, special chars removed (e.g., "Alkautsar" → `whatsapp_style_alkautsar.md`, "Pak Andi" → `whatsapp_style_pak_andi.md`).

**If the file already exists, UPDATE it** — merge new observations with existing ones. Update the `updated` date.

Use this format:

```markdown
---
name: "WhatsApp Style — <Contact Name>"
description: "Communication style profile for <Contact Name> — used to match their tone in WhatsApp replies"
type: reference
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [whatsapp, style, <contact_slug>]
---

## Summary
<2-3 sentences: who this person is in terms of chat style, primary language, overall vibe>

## Style Profile

### Language
<primary language, code-switching patterns>

### Message Length & Structure
<avg length, splitting behavior, paragraph vs one-liner>

### Tone
<overall tone, how it shifts in different contexts>

### Slang & Abbreviations
<actual slang words they use, listed with meaning if non-obvious>

### Emoji & Reactions
<which emojis, frequency, sticker usage>

### Common Phrases
<catchphrases, verbal tics, greetings, sign-offs>

### Punctuation
<their punctuation style>

### Topics
<what they usually talk about>

## Example Messages
<3-5 representative real messages from them that capture their style>

## How to Reply
<concrete guidance: when replying to this person, do X, avoid Y, match Z>
```

### Step 5: Update MEMORY.md Index

After writing/updating memory files:

1. Read `~/.claude/memory/MEMORY.md`
2. Check if each contact already has an entry under a `## WhatsApp Styles` section
3. If the section doesn't exist, add it at the bottom
4. Add/update entries in the format: `- [WhatsApp Style — <Name>](whatsapp_style_<slug>.md) — <language>, <tone summary>`
5. Keep each line under 150 chars

## Rules

- **Only analyze their messages, not Christopher's** — we're learning how THEY talk
- **Use real examples** — quote actual messages (redact sensitive content like addresses/passwords)
- **Don't fabricate patterns** — if there's not enough data (< 5 messages), note that the profile is thin and skip writing a file
- **Merge, don't overwrite** — when updating existing profiles, keep old observations that still hold and add new ones
- **Keep it practical** — the goal is to make replies sound natural. Focus on actionable style notes, not academic analysis
- **No groups** — only analyze 1:1 chats
- **Rate limit** — add a small delay between read_messages calls to avoid hammering the API
