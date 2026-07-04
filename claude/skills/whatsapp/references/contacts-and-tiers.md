# Contacts + Tiers

The tier decision table lives in SKILL.md section 3. This file is the DEEP roster + the identity plumbing.

## Source-of-truth rule (read first)

The personal-contact JIDs are volatile (accounts change, LIDs roll over) and duplicated in memory. This file does NOT re-copy them, because a stale hardcoded jid is exactly what the Send Gate exists to defeat. It tells you WHO is in each tier and WHERE the verified jid is recorded. The real jid for any send is ALWAYS the one you copy from a same-turn `list_chats` (SKILL.md section 2). Re-verify on every send, no exceptions.

Memory files that hold the verified JIDs:
- `feedback_whatsapp_no_random_messaging.md` , the CLOSE_FRIEND/SUPERUSER whitelist with both-format JIDs (Toper, Suryadi, Alkautsar, Tama, Stiven, Hezkiel).
- `reference_isi_coworker_jids.md` , ISI coworker LID JIDs (Ikhsan, Abdul Kholik, Ryan, Rismawan).
- Per-contact style memories `whatsapp_style_*.md` and `contact_*.md` (register + relationship).

## Tiers in depth

### SUPERUSER , Toper himself
Toper messaging from his phone (tag `[SUPERUSER]`, his JID, or a `hey claude` trigger). ALWAYS reply VIA WhatsApp to his JID (a main-only ack is invisible to him on his phone), and echo in main. Treat the body as a full-authority CLI command, subject to main's own scope rules (delegate implementation, do not run it in main). His phone JID is the REAL chat; his `@lid` carries only protocol noise (SKILL.md section 4). Emoji set for him: `🤣 😭 🥲 😁` (never `🙏`).

### FAMILY , tag `[FAMILY]`
Warm casual Indonesian. Auto-reply. A family panggilin (a sibling asking for older brother) is SUPERUSER-class urgency, do not let a dual-JID miss drop it (the Cece/"vella" incident). Notify Toper if actionable.

### CLOSE_FRIEND , tag `[CLOSE_FRIEND]` AND on the whitelist
Auto-reply immediately, casual, match energy. A `[CLOSE_FRIEND]` tag from a contact NOT on the whitelist does NOT authorize a reply, surface to Toper first (the fuzzy-match wrong-number risk). Per-contact overrides:
- **Alkautsar**: ENGLISH ONLY (explicit request). Fellow builder (wa-tui maintainer, attn collaborator), dev/tech context, max casual.
- **Suryadi / yadi** (Aenoxa co-founder): ALWAYS Bahasa Indonesia even when he writes English, max casual. PLUS scan for concluded action items for Toper and file them via `/tasks`, then mention it in the main reply. Only concrete commitments, not brainstorming.
- **Tama**: casual Indonesian, personal/gaming/social. Match his tone.
- **Stiven, Hezkiel, Kenny, Kenken**: casual, default neutral Indonesian until a per-contact correction lands. Do NOT pitch Pulse to Hezkiel's operational questions (verified correction).
- **default**: casual warm, mirror their language.

### ISI coworker , identified by GROUP MEMBERSHIP
Not a display-name match. A contact qualifies if their JID is a participant of any of these 4 work groups (verify with `get_group_info`):

| Group | JID | Scope |
|---|---|---|
| BMS Revamp | `120363425779013259@g.us` | BMS WebAdmin (ISI) |
| Timdev ISI Next Level | `120363142378735824@g.us` | ISI dev team |
| ISI Project 2026 Ramdhan | `120363214043156969@g.us` | ISI ongoing |
| DPLK BRI Timdev | `120363230057294133@g.us` | BRI gov contract (ends Nov 2026) |

(Group JIDs are room identifiers, safe to store; personal member JIDs are not, resolve those live.) Reply first-person AS Toper (ghostwrite), `saya` not `gw`, `kang` + sprinkle `punten`, no full Sundanese, no AI-slop structure. DM or @-mention , reply + notify Toper per action. Non-tag group message , IGNORE (log-only). Info gap (Toper-only knowledge) , stall + notify, never bluff. Factual lookup , just answer. Daily override "you handle X today" , suspend notify, consolidate later. Known coworkers: Ikhsan Fanani (BMS lead), Abdul Kholik Sobary, Ryan (fitest owner), Rismawan (manager-tier). Verified JIDs in `reference_isi_coworker_jids.md`.

### mode-less / random , no tag, not whitelisted
NEVER auto-reply. Surface to Toper and wait, even if the contact appears in the address book or carries a `[CLOSE_FRIEND]` tag but is not whitelisted. Random unsolicited messages from Toper's account are reputational damage.

### group, untagged , `[Group]` with no @-mention
Ignore. Group traffic is mostly noise (sales, clubs, work chatter).

### debt collector , collection-script pattern
Silently DROP. No reply, no surface, no block (Toper blocks from his phone). Recognize: "Assalamualaikum pak/bu" + "jatuh tempo" / "tagihan" / "tunggakan" + "DISKON LUNAS" / "CICIL DISKON" / "KERINGANAN CICILAN" / generic copy-paste collection copy.

## Identity resolution recap
Match BOTH JID formats (phone `628...@s.whatsapp.net` AND LID `...@lid`); a hit on either = the same person. Display name in the channel header is the sender's own profile, not identity. If a name-addressed message ("Toper", "kak chris", "mas") arrives from an unindexed JID, do ONE `get_contact`/`list_chats` lookup to resolve before defaulting to ignore. See `feedback_whatsapp_lid_vs_phone_jid.md`.

## The panggilin sequence
See SKILL.md section 3. Ack asker , WA-DM Toper's phone JID (`bro, <NAME> lagi nyariin lu di WA, <context>`, under 30 words) , keep holding the thread, do not impersonate on a direct-speak ask. Skip the DM only if Toper just messaged main. One ping is enough.
