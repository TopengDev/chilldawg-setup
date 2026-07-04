# Channel Send Playbooks (encyclopedic reference for /outreach)

Progressive-disclosure depth for the **Channel Send-Capability Matrix** in SKILL.md. The Matrix is the enforcement summary; this file is the per-channel mechanics + recipient-verification protocol. **Prime rules from SKILL.md still apply here** (no long dash §0.1, no emoji §0.2, draft-for-approval rule 1, no phantom send rule 2). This file is READ-ONLY reference; it documents mechanics, it does not authorize skipping the approval gate.

The one-line truth: **only WhatsApp sends programmatically. Every other channel prepares text for Christopher to send himself.**

---

## Email playbook

### The infra reality (verified 2026-06-29, `reference_email_sending_infra`)
Sending a REAL, reply-able email AS Christopher programmatically is currently **NOT possible**. Per-account status:
- **topengdev@outlook.com** (smtp.office365.com:587 STARTTLS): **BLOCKED.** SMTP basic auth is disabled by Microsoft (`535 5.7.139 Authentication unsuccessful, basic authentication is disabled`). The password is correct; the policy refuses it. Would need OAuth2 / an Azure app registration (not set up). Cannot send via SMTP.
- **no-reply@aenoxa.com** (smtp.hostinger.com:465 TLS): **WORKS** (Hostinger allows basic auth). BUT it is a NO-REPLY address: bad optics for outreach (the recipient cannot naturally reply, reads as automated/spam). Use ONLY for system/notification mail, or with a real `Reply-To:` if Christopher explicitly authorizes it.
- **$TOPER_EMAIL**: no app-password in `secrets.env`; the `mcp__claude_ai_Gmail` MCP is not authenticated in-session. Cannot send autonomously.
- **email-mcp**: built at `~/.claude/email-mcp/dist/`, config at `~/.config/email-mcp/config.json` (accounts `personal`=Outlook, `business`=no-reply@aenoxa.com), but it is NOT connected as MCP tools in a normal session. Do not assume it is callable.

### Default path (use this)
1. **Compose** the email (§4 email frame, §7 clean punctuation).
2. **Resolve the CV** (rule 4): `ls -t ~/Dropbox/Documents/Christopher/cv/ | grep -i resume | head -1` and take that newest `Resume*.pdf`. NEVER hardcode a filename (the file gets renamed; as of 2026-07-02 the newest is `Resume-2026-updated.pdf`, and an older `Resume 2026.pdf` also survives). NEVER source from `~/Downloads` (it holds OTHER people's CVs + hiremeup `analysis_*` outputs). This mirrors `/case-study`'s CV rule.
3. **Hand Christopher a paste-ready block:** recipient address, subject line, the full body, and the resolved CV path to attach. Tell him plainly: "send this from your desktop Outlook/Gmail (OAuth works there), attach the CV at <path>."
4. **Tracker** (§9): `approved-pending-send` on his approval, then `sent` after he confirms he sent it.

### Only if Christopher EXPLICITLY authorizes an automated SMTP send
- Use `no-reply@aenoxa.com` via `smtp.hostinger.com:465` (TLS). Set a real `Reply-To:` to an address he can receive at, and tell him the recipient will see a no-reply From (bad optics; confirm he accepts it).
- **ALWAYS IMAP-append the sent copy to `INBOX.Sent`** so it shows in his mail client (`feedback_email_append_sent`): after `smtp.sendmail(...)`, do `imap.append("INBOX.Sent", "\\Seen", None, msg.as_bytes())` with the same message object (Hostinger Sent path is `INBOX.Sent`; try `Sent` then `Sent Items` as fallbacks). SMTP delivery does NOT auto-save to Sent; skip this and the sent mail vanishes from his mailbox.
- This path is a rare exception, never the default. Outreach that expects a reply should go out from his real client.

### Recipient verification
Confirm the exact address (from the job post, the profile, or the person). No fuzzy matching. If unsure of the address, say so and ask; do not guess.

---

## WhatsApp playbook (the ONLY programmatic send)

### Hard preconditions
- **MAIN SESSION ONLY.** The WhatsApp MCP send tools work only where `WHATSAPP=1` is set, which is the main command-center session (tmux window 1). NEVER set `WHATSAPP=1` in a worker (the plugin splits inbound messages across sessions and breaks main). If `/outreach` is running in a worker and a WhatsApp send is needed, the worker prepares the text + the target and hands it to main to send.
- WhatsApp outreach fits a **warm/known Indo contact** or **someone who explicitly gave a number** (e.g. a recruiter like Laurel). A cold, unknown number is not a WhatsApp-outreach target by default.

### The JID protocol (`feedback_whatsapp_no_random_messaging`, non-negotiable)
Two verified real incidents drive this: fuzzy name-match sent messages to the wrong person (Alfiki, not Tama, 2026-04-07 and again 2026-04-15), and a hand-typed JID transposition messaged a stranger (2026-04-08). So:
1. Call `mcp__plugin_whatsapp_whatsapp__list_chats` (limit 20+) **immediately before** the send.
2. Find the chat that matches the intended recipient by name + context.
3. **COPY the `jid` field verbatim from THAT `list_chats` response** into the send. Do NOT type it from memory. Do NOT reuse a JID from earlier in the conversation across a context switch. The `list_chats` and `send_message` calls should be back-to-back with no other tool calls between.
4. Send with `mcp__plugin_whatsapp_whatsapp__send_message(to=<JID>, ...)`, NEVER `to=<contact name>` (the name is fuzzy-matched and can resolve to the wrong chat).
5. If the chat is not in the list, increase the limit or use `search_messages`; if still not found, **STOP and ask Christopher**. Never invent or approximate a JID.

### Cold lead (not whitelisted)
A recruiter/client who gave a number but is not a known contact is NOT on the auto-reply whitelist. Path: `mcp__plugin_whatsapp_whatsapp__check_number` to confirm the number is on WhatsApp + is the right person, confirm identity, THEN the `list_chats`+copy-JID send. When in doubt, hand it to Christopher to send from his own phone.

### After send
It actually fired, so set the tracker to `sent` directly (unlike the hand-off channels). Set last-touch + next-action date; offer `/remindme` for the next follow-up.

---

## Threads / X playbook (context-bound, self-send default)

### Do NOT browser-automate the DM send
`feedback_threads_dm_automation_context_bound`: on 2026-05-30 (@itsmasiam outreach) three successive workers all hit the ~90% context input-freeze BEFORE sending a 2-message Threads DM. Root cause: the Threads `/messages/t/...` page is extremely heavy and the composer is a React/Lexical editor; every DOM snapshot dumps a massive tree, and composing needs many interactions. Even an execution-only worker with every method pre-solved froze at 91% in ~3 minutes. Reading the post (recon) automates fine; it is the compose+send on the messages page that is the trap.

### The default (use this)
Hand Christopher the **exact verbatim text(s)** and have him send from his phone app (30 seconds, and more authentic for his own recruiter/outreach DMs anyway). Do not respawn workers against the context wall.

### Real Threads product constraints to honor when drafting
- **1000-char composer cap** (React/Lexical-enforced, no `maxlength`). Long messages must be split.
- A DM to a **non-followed account** is a **message request**: "up to 3 messages before they accept". Splitting into `<= 3` bubbles is fine; keep it to <= 3.
- **No file/PDF attach** in a Threads DM (text + emoji only). The CV cannot be attached: link the proof (a portfolio/case-study URL) or offer it on reply.
- Shift+Enter = soft newline (no send); plain Enter sends.

### Recon of the post (if needed)
Reading the target's post automates fine, but defer ALL browser work to the **`/agent-browser`** skill: its multi-port `/claim` lifecycle, the tab-new-is-broken gotcha, the `qb-shoot "<non-numeric-slug>"` screenshot fallback (agent-browser screenshot times out on the heavy Threads tab; a pure-numeric slug is misread as a tab index), and the DPR trim. NEVER kill the live browser (it holds Christopher's authenticated production sessions). NEVER use Playwright MCP.

### After
Hand-off channel: tracker `approved-pending-send` -> `sent` after he confirms he sent the bubbles.

---

## LinkedIn playbook (no tool, manual)

There is no LinkedIn send tool. The terminal action is always a hand-off:
- **Connection note**: `<= 280 chars`, one proof-hook + one specific + one ask (§4 frame). Output it; he pastes it into the connect dialog.
- **DM / InMail**: 100-130 words, the email frame compressed. Output it; he sends it.
- No attachment: link the proof. Match the exact profile URL (recipient verification): confirm you have the right `linkedin.com/in/<slug>` before naming a target.

---

## Application form playbook (no tool, manual)

A job portal's "message" / cover field is a hand-off:
- Treat the cover field like a tight email (80-150 words, or match the field's limit).
- Personalize + proof-lead (rules 3, 4) exactly as for email.
- Output the final field text; Christopher pastes it into the portal and submits. The skill never submits a form.

---

## Per-channel recipient-verification protocol (recap, do this BEFORE naming a send target)

| Channel | Verify |
|---|---|
| **WhatsApp** | `list_chats` -> copy JID same-turn -> `check_number`/confirm identity. Never a name, never a hand-typed JID. |
| **Email** | Confirm the exact address. Resolve the CV via `ls -t`. |
| **LinkedIn** | Match the exact `linkedin.com/in/<slug>` profile URL. |
| **Threads / X** | Match the exact `@handle`. |
| **Form** | Confirm you are on the right posting/portal. |

If verification fails or is ambiguous, STOP and ask Christopher. A wrong recipient in his name is worse than a delayed send.
