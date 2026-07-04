---
name: outreach
description: "Structured cold/warm outreach to recruiters and potential clients for Christopher's job-hunt + freelance push. Researches the target (role/company/person), drafts a TAILORED message (never a template blast) leading with a real proof-point, picks the right channel + length, and tracks a follow-up cadence. HARD draft-for-approval gate that NEVER auto-sends: it prepares the exact final text, and only WhatsApp sends programmatically (main-session + JID-verified); every other channel hands Christopher a paste-ready block to send himself. Use when Christopher says /outreach, \"reach out to X\", \"draft a message to this recruiter/client\", \"follow up with Y\", or wants to contact a lead about work."
argument-hint: "<target: recruiter/company/person + role or context, or a job post URL> [--channel email|linkedin|whatsapp|threads|x|form] [--type recruiter|agency|client] [--proof <project or /case-study slug>] | follow-up <target> | track"
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, WebSearch, WebFetch, Skill, mcp__plugin_whatsapp_whatsapp__list_chats, mcp__plugin_whatsapp_whatsapp__check_number, mcp__plugin_whatsapp_whatsapp__send_message
---

# /outreach: research to tailored, proof-led outreach, approval gate, prepared send, tracked follow-up

Turn "reach out to this recruiter/client" into a **researched, personalized, proof-led message that Christopher approves before anything leaves his name**, plus a follow-up cadence and a tracker so leads don't rot. This is a livelihood tool: freelance outreach is the anchor income path (the survival floor before the BRI contract ends, `project_income_diversification_2026`), and the difference between a reply and silence is whether the message proves you bothered to understand the target and can point at real shipped work.

**Three failure modes this skill exists to prevent:**
1. **Generic template-blasts** that scream "I sent this to 200 people" and get ignored or burn the contact.
2. **Auto-sending** something half-baked, mis-targeted, or off-voice that Christopher would never have approved.
3. **The false send** (the newest and most dangerous): assuming that on approval a programmatic send fires, when for email / LinkedIn / Threads / X / application-form **no working autonomous send path exists**. Believing otherwise silently fails the send, burns a worker to the context wall (Threads), or fires an un-repliable no-reply email at a recruiter. This skill DRAFTS and PREPARES; on almost every channel the terminal action is to hand Christopher the exact final text for HIM to send.

The spine: **research first, personalize hard, lead with a real proof-point, prepare the exact final text, hand it to Christopher (or, for WhatsApp only, send it main-session + JID-verified after his go).**

This skill pairs with **`/case-study`** (which generates the proof-points and, with `--for application`, emits a paste-ready strict-voice cover blurb that slots straight in here). Boundaries vs `/proposal` and `/copywriting` are drawn in §10.

═══════════════════════════════════════════════════════════════════════════
## §0 PRIME RULES (these override everything below, including the non-negotiables)
═══════════════════════════════════════════════════════════════════════════

Every draft this skill produces is outward-facing text in Christopher's name on the exact surfaces (recruiter DM, application, LinkedIn, email) where reading as AI-generated is most damaging. The two rules below govern the FORMAT of every character of every draft AND of this skill's own prose. They are prime because a single violation is the loudest "a bot wrote this" tell there is.

### §0.1 NEVER emit an em dash or en dash, ANYWHERE (PRIME)
**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY draft, in the tracker, in a report to Christopher, or in this skill's own prose.** This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02: never long dashes in ANY outgoing text) and it mirrors `/case-study` §0.1 and `/frontend-design` §0.4.
- **Use instead:** a comma, a colon, a line break, or restructure into shorter clauses. A title shaped "X (long dash) Y" becomes "X: Y" or "X, Y". Never mechanically delete a dash and leave broken grammar.
- **The plain hyphen stays fine** in compound words and tech names (real-time, draft-for-approval, proof-point, follow-up, multi-tenant, Next.js, admin@client.example). ONLY the two long dashes are banned.
- **Enforced** by the §6 format grep, which is a gate in the §readiness score. The habit of reaching for a dash is strong: self-check before presenting.

### §0.2 NEVER put an emoji in a draft (his to add, not yours)
Drafts ship **emoji-free** (mirrors `/case-study` §0.2). Christopher occasionally adds a single emoji HE chooses (for example the one coffee glyph in his +170k Threads post); the skill never inserts one. Zero emoji in any recruiter DM, application, email, LinkedIn, or Threads draft. The §6 grep checks this too.

> Both §0.1 and §0.2 apply to the strict-symbol voice AND the clean-punctuation voice (§7). They are format rules, not voice rules; no channel or register exempts them.

═══════════════════════════════════════════════════════════════════════════
## NON-NEGOTIABLE RULES (READ ALL, THESE OVERRIDE THE SECTIONS BELOW)
═══════════════════════════════════════════════════════════════════════════

Violating any one is a failed outreach, not a stylistic choice.

**1. DRAFT-FOR-APPROVAL, NEVER ACT WITHOUT HIS GO. EVER.**
This skill prepares. Nothing leaves Christopher's name until he reads the exact final text and explicitly says go ("send it" / "approved" / "yes send"). No WhatsApp send, no email, no Threads DM, no form-submit, no LinkedIn message, until then. Present the draft, the channel, the recipient, and WAIT. This is a hard gate even for warm/known contacts, even for a "quick" follow-up, even when he seems to want speed. Outreach in HIS name is reputation-bearing and irreversible: a wrong send cannot be unsent. If he says "just send it" without having seen the text, show the text first and confirm once. (Rule 2 governs what "the send" mechanically is per channel; this rule governs that his approval always gates it.)

**2. SEND-CAPABILITY IS REAL, NOT ASSUMED: on almost every channel you PREPARE, you do not SEND.**
There is NO working autonomous send-as-Christopher path for email, LinkedIn, Threads, X, or application forms. Do NOT call a send tool for those channels, even after approval. The terminal action for them is: **output a copy-paste-ready block (recipient + subject-if-email + the full final text + attachment path) and tell Christopher to send it from his own client/app.** The tracker moves to `approved-pending-send`, then to `sent` only after he confirms he sent it. **WhatsApp is the ONLY channel that sends programmatically**, and only from the MAIN session (never set `WHATSAPP=1` in a worker) with the JID-verify protocol (rule 6). This is enforced by the Channel Send-Capability Matrix below. (Why: Outlook SMTP basic-auth is disabled by Microsoft, Gmail MCP is unauthed, no-reply@aenoxa.com sends but reads as spam and cannot be replied to; LinkedIn/forms have no tool; a Threads DM send freezes workers at ~90% context. Full facts: `references/channel-send-playbooks.md`, `reference_email_sending_infra`, `feedback_threads_dm_automation_context_bound`.)

**3. PERSONALIZATION-MANDATORY, >= 3 SPECIFICS OR DON'T SEND.**
Every message must contain **at least 3 concrete, target-specific facts** proving it was written for THEM, not pasted: the person's/company's real name + what they actually do, a specific detail about the role/product/post, a real reason Christopher fits THIS one, a reference to something they shipped/wrote/announced. A message that would work verbatim for a different company FAILS the swap-test and is BANNED (enforced by the §5 specificity index + audit). If you cannot find 3 real specifics, you have not researched enough (§2): go back, or tell Christopher the target is too thin to personalize.

**4. LEAD WITH A REAL PROOF-POINT + ITS EXACT LINK, NOT A PITCH.**
Open (or near-open) with a concrete, relevant *shipped thing*: a real project, a live URL, a `/case-study`, a specific result that maps to what the target needs. "I built X (live at Y), close to what you are doing with Z" beats any amount of "I am passionate / I am a hard worker / I would love the opportunity". **The proof-point must be REAL and cited with its exact canonical link** (LinkedIn, GitHub, a live-product URL, a case study). **NEVER invent a URL or a metric.** Resolve the CV by `ls -t ~/Dropbox/Documents/Christopher/cv/ | grep -i resume | head -1` (NEVER hardcode a filename, NEVER source from `~/Downloads`, mirrors `/case-study` CV rule). The canonical asset registry with exact links is `references/proof-assets.md`.

**5. VOICE IS CHRISTOPHER'S, PER-CHANNEL (strict symbol set vs clean formal).**
Two registers, chosen by channel (full rule + table in §7, canonical source `/case-study` §0.3):
- **Stylized first-person DM** (Threads / X / a casual personal-brand note) = the **STRICT outreach symbol set only**: `@ & + ( ) / * " ' : ; ! ?`, no period, no comma, no hyphen in prose, line breaks separate clauses. This is the DEFAULT for his stylized recruiter DMs (resolved 2026-06-29, `feedback_toper_writing_style`).
- **Formal email / LinkedIn to a corporate recruiter** = clean normal punctuation, still HIS direct register: short, substance-first, never groveling.
- **BOTH** obey §0.1 (dash ban) + §0.2 (emoji ban). BANNED in both: "I am writing to express my keen interest", "I would be thrilled/honored", "I am passionate about leveraging", "Dear Hiring Manager, I hope this email finds you well", and the rest of §6.

**6. ANTI-SPAM + RECIPIENT VERIFICATION (per channel, before you name a send target).**
No blasting. No more than the §8 follow-up cadence (STOP on a no or on silence past the cadence). **Verify the recipient identity BEFORE drafting a send target**, per channel:
- **WhatsApp** (main session only): `list_chats` immediately-before, **COPY-PASTE the JID from that same response** in the same turn, `check_number` / confirm identity, send with the JID, NEVER a contact name (fuzzy-match sends to the wrong person, a repeated real incident), NEVER a hand-typed JID (a transposition messaged a stranger). If the chat is not in the list, STOP and ask. A cold lead is not whitelisted: `check_number` + confirm before anything. (`feedback_whatsapp_no_random_messaging`.)
- **Email**: confirm the exact address + resolve the CV path (rule 4).
- **LinkedIn**: match the exact profile URL. **Threads/X**: match the exact @handle.
One well-researched message beats ten generic ones; a burned or wrong-sent contact is worse than no contact. This skill never enrolls anyone in an automated sequence: every touch is individually approved (rule 1).

**7. REPLIES ARE CHRISTOPHER'S. Never auto-reply to a target; surface the AI question.**
This skill drafts first-touches and follow-ups; it does NOT hold a live conversation. Once a target replies, the cadence ends and it becomes Christopher's conversation (§8). **NEVER auto-reply to an outreach target on his behalf.** If a target asks whether the outreach is AI/automated, that is a WORK context: **surface it to Christopher and let him decide**, never auto-lie ("no this is really me") and never auto-disclose without his call (`feedback_disclose_ai_when_asked`: honest default is for close friends; work/customer contexts ask Toper first).

> If Christopher asks for something that breaks these (e.g. "blast 50 recruiters the same message", "just auto-send the follow-ups", "email it for me as me"), do NOT silently comply. Flag it: the value is in per-target personalization + his approval, and (rule 2) there is no as-Christopher email send. Offer the right version.

═══════════════════════════════════════════════════════════════════════════
## CHANNEL SEND-CAPABILITY MATRIX (the enforcement device, memorize this)
═══════════════════════════════════════════════════════════════════════════

This table is what kills the false-send failure mode. Before you name any send target, find its row and obey the **Terminal action** column. Only the WhatsApp row has an autonomous send.

| Channel | Autonomous send? | Tool | Terminal action on approval | Key constraints |
|---|---|---|---|---|
| **Email** | **NO** | none (send-as-Christopher blocked) | Output a paste-ready block: recipient + subject + full final text + CV path (resolved via `ls -t`). Christopher sends from his desktop Outlook/Gmail (OAuth works there). | Outlook SMTP basic-auth disabled (`535 5.7.139`); Gmail MCP unauthed; `no-reply@aenoxa.com` sends but is no-reply (bad optics). Automated SMTP ONLY if he explicitly authorizes it (§ playbook), then IMAP-append to `INBOX.Sent`. |
| **LinkedIn** | **NO** | none | Output the final text; he pastes it into LinkedIn. | Connection note <= 280 chars; DM/InMail 100-130 words. No attachment: link the proof. |
| **WhatsApp** | **YES** | `mcp__plugin_whatsapp_whatsapp__send_message` | MAIN SESSION ONLY: `list_chats` -> copy JID same-turn -> `check_number`/confirm -> `send_message(to=<JID>)`. | `WHATSAPP=1` main-session only, never a worker. JID copy-paste, never a name, never hand-typed. Cold lead: confirm identity first. |
| **Threads / X** | **NO** | none (automation freezes at ~90% ctx) | Output the verbatim text(s); Christopher sends from his phone app (30s, more authentic). | 1000-char composer cap; a DM to a non-followed account is a message-request, split into <= 3 bubbles; NO file/PDF attach (link the proof); plain Enter sends. Post recon defers to `/agent-browser`. |
| **Application form** | **NO** | none | Output the final field text; he pastes it into the portal. | Match the field's length; treat a cover field like a tight email. |

**Reading rule:** "Autonomous send? NO" means you MUST NOT call any send tool for that channel, ever, even after Christopher approves. Approval unlocks the hand-off (or the WhatsApp send), not a phantom tool.

═══════════════════════════════════════════════════════════════════════════
## OUTREACH READINESS SCORE (satisfy ALL 8 gates before showing the draft)
═══════════════════════════════════════════════════════════════════════════

The draft is the ONLY output until Christopher approves. Score it before presenting: **PASS count out of 8, and the floor is 8/8.** Any single fail blocks the draft (fix first, do not present as ready). Print the score line so the reasoning is visible.

| # | Gate | Pass condition |
|---|---|---|
| 1 | **Terminal action correct** | The plan matches this channel's Send-Capability Matrix row (email/LinkedIn/Threads/form = a paste-ready hand-off block; WhatsApp = JID-verified main-session send). No phantom send tool. |
| 2 | **Specificity index >= 3** | >= 3 target-unique facts are IN the message (name + what-they-do counts as <= 2; a recent-signal reference is a strong 3rd) AND the swap-test fails-as-generic (§5). |
| 3 | **Proof is real + mapped** | A real proof-point leads, cited with its exact canonical link (`references/proof-assets.md`), and it maps to THIS target's stated need. No invented URL/metric. |
| 4 | **Single low-friction ask** | Exactly one next step, easy to say yes to. Not three asks, not a CV-dump. |
| 5 | **Length within budget** | Within the §3 channel budget (email 90-150w, LinkedIn note <= 280 chars, WA 2-5 lines, Threads bubble <= 1000 chars). |
| 6 | **Voice-set correct** | The §7 register for this channel (strict symbol set for a stylized DM; clean punctuation for a formal email/LinkedIn). |
| 7 | **Format grep clean** | Zero em/en dashes (§0.1), zero emoji (§0.2), and (if stylized) only the strict symbol set. §6 grep run. |
| 8 | **Recipient verified** | Identity confirmed per channel (rule 6): WA `list_chats`+`check_number`, email address confirmed, LinkedIn exact profile URL, Threads exact @handle. |

If `< 8/8` -> not ready. Research more (§2), rewrite, or re-verify. Only at `8/8` do you present the draft + channel + recipient + (for a hand-off channel) the paste-ready block.

---

## 1. PARSE THE INVOCATION

Read `$ARGUMENTS` and classify intent:

| If `$ARGUMENTS`... | Intent |
|---|---|
| starts with `follow-up <target>` | **FOLLOW-UP** (jump to §8, draft the next nudge in cadence) |
| starts with `track` | **TRACKER** (jump to §9, show/update the outreach log) |
| a job-post URL, or "reach out to <X>", or a target description | **NEW OUTREACH** (run §2 to the readiness score) |
| empty / vague ("reach out to someone") | ask: "Who is the target, a person, company, or job post? Paste a link or name them, and tell me recruiter / agency / direct-client." |

Extract / decide:
- **Who**: person, company, role, or post (`--type recruiter|agency|client`; infer if obvious, else ask).
- **Warm or cold**: does Christopher already know them / have they interacted (a Threads reply, a prior chat, a mutual)? Warm changes the opener (reference the prior touch) and softens the cadence.
- **Channel** (`--channel`; §3 picks the default if unset). Note its Send-Capability Matrix row now.
- **Proof-point** (`--proof <project|case-study-slug>`; §3a picks the best fit if unset).

---

## 2. RESEARCH PASS (DO THIS FIRST, personalization is impossible without it)

**No drafting until you have researched.** The >= 3 specifics (rule 3) come from here. Scale effort to the target's importance, but never skip to a blank-slate template.

### 2a. The target-research checklist
Gather as many as apply (you need >= 3 real, usable specifics to clear rule 3):
- **Who they are**: the person's name + role, OR the company + what it actually builds. Real name, spelled right. "Dear Hiring Manager" is a personalization failure if a name is findable.
- **What they do / build**: the product, the domain, the stack if discoverable, the market. The more specific, the better the fit-hook.
- **The role / need**: for a job post, the actual requirements, stack, seniority, what they emphasize. For a client, the pain they likely have.
- **A recent signal**: something they shipped, announced, posted, raised, hired for, wrote. The strongest opener ("saw you just launched X" / "your post about Y"). The @itsmasiam pattern is exactly this: a public post you can reference.
- **The fit angle**: the specific, honest reason Christopher matches THIS one. Not "I am a great fit", but *why*: a stack overlap, a domain match (POS to retail-tech, QA-automation to SDET, bilingual to Indo-market), a proof-point that maps to their problem.
- **The channel + contact**: where to reach them, and the exact address/handle/JID. Verify it (rule 6).

### 2b. How to research
```
# job post / company / person, pull the real details
WebFetch <job-post-or-company-or-profile URL>   -> requirements, stack, product, tone
WebSearch "<company> <product> / <person> <role> recent"   -> recent signal, what they ship
```
- For a **job post**: fetch it, extract the real stack + must-haves + framing. Map Christopher's real experience to their list (honestly, §2c).
- For a **company/client**: understand the product + the likely pain Christopher could solve. Find a recent signal.
- For a **person** (recruiter/founder): role, what they hire for, public posts. For a Threads/X lead, the post itself is the signal, read it.
- **Draw the proof + fit from the canonical registry**: `references/proof-assets.md` holds the exact identity links, live-product URLs, positioning line, and the proof-to-target map. The strategic frame (positioning, the Laurel-pitch critique lessons) lives in the ACTIVE initiative `~/claude/notes/initiatives/dev-job-outreach.md` (`project_income_diversification_2026`: premium bilingual fullstack + native mobile + infra + AI, a rare combo; freelance = anchor).
- **Check for a ready cover blurb first**: if `/case-study --for application` was already run for a matching project, its paste-ready strict-voice blurb is at `~/claude/notes/applications/<company-or-role>-<slug>.md` (NOT `~/claude/notes/case-studies/`, which holds portfolio/linkedin case studies). Lead the outreach with it.

### 2c. Honesty in the fit (no-yesman applies to selling too)
The fit-hook must be **true**. Do not claim a stack he has not touched or oversell the match to land the message: a fabricated fit gets exposed in the first call and burns the lead worse than a pass. If the match is partial, lead with the real overlap and be straight about the rest. If the target is a genuinely bad fit, tell Christopher, do not manufacture enthusiasm for a role he should not chase.

### 2d. If research comes up thin
If you cannot find >= 3 real specifics (obscure company, no public footprint), tell Christopher: "I can only find [X, Y] about this target, that is thin for a personalized message. Options: (a) you give me more context, (b) I draft a shorter, lower-investment touch and we accept a lower hit-rate, (c) skip it." Do not paper over a thin target with generic filler (violates rule 3).

---

## 3. CHANNEL SELECTION + LENGTH

Pick the channel that fits the target + relationship. Each has a length budget (overshooting is a spam-tell) AND a Send-Capability Matrix row (how it actually goes out).

| Channel | Best for | Length budget | Send + verify (see Matrix) |
|---|---|---|---|
| **Email** | Formal recruiter, agency, structured client intro, when an address is known | 90-150 words, a real subject line | Hand-off block, he sends. Confirm address + resolve CV. |
| **LinkedIn** | Recruiters, hiring managers, professional warm reach | Connection note <= 280 chars; InMail/DM 100-130 words | Hand-off, he pastes. Match the exact profile URL. |
| **WhatsApp** | A warm/known contact, an Indo lead, someone who gave a number (e.g. Laurel) | 2-5 short lines | ONLY programmatic channel. Main session, `list_chats`+copy JID+`check_number` (rule 6). Often Bahasa. |
| **Threads / X** | A public-post lead (the @itsmasiam pattern), founder/dev-community warm reach | Reply: tight; DM bubble: <= 1000 chars, <= 3 bubbles | Hand-off, he self-sends from his phone. No attach. Post recon defers to `/agent-browser`. |
| **Application form** | A job portal with a "message"/cover field | Match the field; usually 80-150 words | Hand-off, he pastes into the portal. |

Default if `--channel` unset: email for a formal recruiter/agency with a known address; LinkedIn for a hiring manager; the native platform for a public-post lead (Threads/X); WhatsApp only for an explicitly warm Indo contact who shared a number.

### 3a. Picking the proof-point (rule 4)
Match the proof to the target's need, do not reach for the same one every time. The exact links are in `references/proof-assets.md`; the mapping:
- Retail / POS / SMB-tech client -> the **Pulse POS** case study (multi-tenant, offline-first, native hardware; live `coba-pulse.topengdev.com`).
- A role/client emphasizing **QA / testing / SDET** -> the **fitest QA-automation** story (300+ suites, framework-bug diagnosis).
- A **frontend / design-quality** role -> a polished shipped UI (a landing/oneshot build, the design-system work, `topengdev.com`).
- **Infra / fullstack / AI** -> the self-hosted stack (VPS + Docker + nginx), the AI integrations (`aura.topengdev.com`), signal-trader (live algotrading).

If a `/case-study` for the right project does not exist yet, suggest running it first, then lead with its link/blurb. **`/case-study <project> --for application --role <this role>`** emits a ready cover blurb (already strict-voice) at `~/claude/notes/applications/<company-or-role>-<slug>.md`, designed to slot straight in here.

---

## 4. MESSAGE FRAMES (per channel x persona, frames NOT fill-in-the-blank blasts)

These are **structural frames** showing the shape + the proof-led, personalized discipline. **Every bracket is filled from §2 research for THIS target**, never shipped as-is, never reused across targets (that is the template-blast rule 3 bans). The point of a frame is consistent *structure + voice*, with unique *content* every time. Fuller before/after rewrites: `references/rewrite-gallery.md`.

### Frame: Email to recruiter / hiring manager (clean punctuation, §7 formal)
```
Subject: <specific, role + a hook, e.g. "Fullstack (Next.js + native mobile), built a multi-tenant POS solo">

Hi <Name>,

<Opener: a real signal about them, the role/product/post, proving you researched.
e.g. "Saw the <role> opening at <Company>, the <specific stack/product detail> is right in
what I have been building.">

<Proof-point, leading: a real shipped thing that maps to their need + its exact link.
e.g. "I built Pulse, a multi-tenant offline-first POS, solo, live in production. Short
write-up: <case-study/portfolio link>.">

<The fit, honest + specific: why THIS one. The real overlap, not "I would be a great fit".>

<One clear, low-friction ask: a call, a reply, "worth a chat?". One ask, not three.>

<sign-off, his name>
```
Terminal action: a paste-ready block (subject + recipient + body + CV path). He sends it. Do NOT send.

### Frame: LinkedIn connection note (<= 280 chars, clean punctuation)
```
Hi <Name>, saw <Company> is hiring for <role>. I build <one-line: the relevant thing>,
shipped solo to production (<proof link>). Close to your <specific>. Open to a quick chat?
```
(One proof-hook, one specific, one ask. No room for fluff, that is the point.) He pastes it.

### Frame: WhatsApp to warm Indo contact (Bahasa, casual)
```
Halo <Name>, <context of how you know them / the referral>.

Gue lagi <looking for / open to> <freelance/role>. Baru aja ship <the relevant thing>,
<live link / 1-line proof>.

Kayaknya nyambung sama <their thing>. Boleh ngobrol bentar?
```
(Short, natural, real-friend register. Emoji only from the allowlist if any, but drafts ship emoji-free per §0.2, he adds one if he wants.) Send path: main session, JID-verified (rule 6, Matrix).

### Frame: Threads / X to a public-post lead (STRICT symbol set, §7 stylized)
```
<Engage the actual post first: a real, substantive reaction to what they said, not "great post">

<the relevant proof-point + link, strict symbol set: no period no comma no hyphen in prose
line breaks separate clauses, tech names + URLs intact>

<a light non-needy opener to talk, not a hard pitch into their replies>
```
**Threads caution (inline, load-bearing):** do NOT try to browser-automate the DM send. Three workers froze at ~90% context attempting exactly this (`feedback_threads_dm_automation_context_bound`). Default = hand Christopher the verbatim text(s), he sends from his phone (30s, more authentic). Honor: 1000-char cap, <= 3 message-request bubbles for a non-followed account, no attach (link the proof). Any recon of the post defers to `/agent-browser` (its multi-port `/claim` lifecycle, `qb-shoot` screenshot fallback, DPR trim; never kill the live browser, never Playwright MCP).

### Frame: Direct-client (agency or end-client) to email/DM
```
<Name / company>, <a real observation about their product/problem that shows you get it>.

I am a fullstack engineer (<the rare-combo positioning: bilingual + Next.js + native mobile +
infra + AI>). I shipped <the most relevant proof + link> which overlaps with <their thing>.

<What you could do for them, concretely, tied to a likely pain, not a feature list.>

<Soft ask: "open to a quick call to see if there is a fit?">
```
Terminal action by channel (Matrix): email/DM hand-off, WhatsApp main-session send.

### Universal structure (every channel)
1. **Hook** = a real signal about THEM (research-proof). 2. **Proof** = a relevant shipped thing + its exact link (rule 4). 3. **Fit** = the honest, specific why-this-one. 4. **Ask** = one clear, low-friction next step. Cut anything that is not one of these four. No "hope this finds you well", no CV-dump, no three asks.

---

## 5. PERSONALIZATION AUDIT + SPECIFICITY INDEX (rule 3 enforcement)

Before scoring readiness, compute the **specificity index** and run the audit:

- **Specificity index (integer, floor 3).** Count the target-specific facts that are TRUE of this target and would NOT fit another company/person. Name + what-they-do counts as up to 2; a recent-signal reference is a strong 3rd. `< 3` -> not ready; research more (§2) or rewrite. Report the number.
- **The swap test (binary).** Could this message be sent verbatim to a different target by swapping only the name? If yes -> it is a template, FAIL. The body must depend on THIS target's specifics.
- **The proof leads + maps.** A real, relevant proof-point is near the top AND it actually fits this target's need (not a generic "see my portfolio"), cited with its exact link.
- **The ask is single + low-friction.** One next step, easy to say yes to.
- **Length within the channel budget** (§3).
- **Honest fit** (§2c), no overclaimed stack/match.

Any failing item -> fix before it reaches the readiness score.

---

## 6. BANNED PHRASES + FORMAT GREP (anti-corporate-eager + anti-AI-tell, rule 5 + §0)

Grep the draft; kill every hit (replace with a concrete specific, or cut). This feeds readiness gate 7.

**Format greps (the AI-tells, §0):**
- **em/en dash**: zero. Replace with comma / colon / line break (§0.1).
- **emoji**: zero (§0.2).
- **strict-symbol check** (stylized DM only, §7): the body uses ONLY `@ & + ( ) / * " ' : ; ! ?`; any period/comma/hyphen in prose (tech names + URLs exempt) is a fail. This is a manual eyeball, line by line (a mechanical period-grep false-positives on URLs and tech names).

**Corporate-eager / groveling:** "I am writing to express my keen interest", "I would be thrilled/honored/delighted", "I hope this email finds you well", "Dear Hiring Manager / To Whom It May Concern" (when a name is findable), "I am confident that I would be a valuable asset", "I would welcome the opportunity", "Thank you for considering my application", "I look forward to hearing from you at your earliest convenience", "please do not hesitate to".

**Empty self-claims (no proof):** "passionate about", "hard-working", "team player", "fast learner", "results-driven", "detail-oriented", "go-getter", "wear many hats", "think outside the box", "self-starter", "proven track record" (unless you are pointing AT the proof).

**Resume filler:** "leverage/leveraged", "synergy", "cutting-edge", "robust scalable solution", "seamlessly", "spearheaded", "utilized", "best-in-class", "dynamic environment", "fast-paced environment".

**Needy / low-status tells:** "I know you are busy but", "sorry to bother you", "I would be so grateful", "even a few minutes would mean a lot", "I will work for free to prove myself" (undersells), excessive exclamation marks, over-apologizing.

Replacement discipline: every banned phrase cut is replaced by a **concrete specific** (a real detail, a proof link, a direct statement), not a softer cliche. Direct + specific reads as confident + competent; eager + generic reads as desperate + interchangeable.

---

## 7. VOICE (per-channel register, canonical source `/case-study` §0.3)

Christopher has two registers. Pick by channel, and both obey §0.1 (no long dash) + §0.2 (no emoji). Do not ask which voice, the channel decides.

| Surface | Register | Rule |
|---|---|---|
| **Threads / X / a stylized personal-brand DM** | **STRICT outreach symbol set** | Only `@ & + ( ) / * " ' : ; ! ?`. NO period, comma, hyphen, or bullet in prose. Line breaks separate sentences/clauses; `:` for labels; `&`/`+` for joining; `!`/`?` for emphasis. Tech names + URLs keep real punctuation (Next.js, topengdev.com, gRPC). **This is the DEFAULT for his stylized recruiter DMs.** |
| **Formal email / LinkedIn to a corporate recruiter** | **Clean normal punctuation** | Periods and commas are correct here. Still HIS register: short, direct, substance-first, never groveling. NEVER apply the strict symbol set to a formal email, it reads as broken. |

Why the split (do not re-derive, cite): resolved 2026-06-29 (`feedback_toper_writing_style`), the strict symbol-only set is specifically FOR outreach/recruiter DMs (this skill's stylized output); public Threads POSTS use his natural viral-post voice (that is a `/copywriting` or content task, not this skill). He rejected emoji+comma+dash outreach drafts twice (2026-05-30, @itsmasiam) before clarifying the exact set. Drafts never carry emoji (§0.2), he adds his own.

---

## 8. FOLLOW-UP CADENCE + SCHEDULE (`follow-up` intent)

A single message rarely lands; a pest never does. The cadence is polite, value-adding, finite, and STOPS on a no or past the end:

| Touch | Timing (after prior, no reply) | Content |
|---|---|---|
| **1, initial** | day 0 | the researched, proof-led message (§2 to §7) |
| **2, first follow-up** | +3-4 business days | short bump; ADD value (a new relevant proof, a quick thought on their product), never just "did you see my message?" |
| **3, final follow-up** | +7 days after #2 | brief, graceful close-out: "I will leave it here, if the timing changes, easy to reach me at X." Leaves the door open, no guilt. |
| **STOP** | after #3, or on any "no" / "not now" | Do not contact again about this. A "not now" logs a far-future optional re-touch, only if they invited it. |

Rules:
- **Each follow-up is its own readiness-scored draft-for-approval** (rule 1), never auto-fired. The skill drafts the next touch; Christopher approves; the send follows the channel's Matrix row (hand-off for most, WA main-session send for WhatsApp).
- **Every follow-up must add something**: a new proof-point, a relevant observation, a useful link. A content-free "just bumping this" is spam.
- **Warm leads** can use a softer/shorter cadence; **a reply** ends the cadence (it becomes Christopher's conversation, rule 7, no more scripted touches).
- **Scheduling the reminder:** pair with `/remindme` (e.g. `/remindme in 4 days follow up with <target>`) so it surfaces as a WhatsApp nudge (`/remindme` is CronCreate-backed and fires a WhatsApp DM to Toper, satisfying the house time-promise rule). A tracker row alone is passive and gets forgotten. Offer to set this whenever a touch is prepared/sent.

`follow-up <target>` flow: read the tracker row (§9) for this target -> confirm no reply came -> check which touch is next + that the timing is due -> draft that touch (adding value) -> readiness-score + present for approval -> on send, update the tracker + offer the next `/remindme`.

---

## 9. TRACKER (so leads don't rot)

Maintain a simple, greppable log at **`~/claude/notes/outreach/tracker.md`** (create dir/file if absent, neither exists by default; `mkdir -p ~/claude/notes/outreach`). One row per target:

```
| Date | Target (person @ company) | Type | Channel | Proof used | Status | Last touch | Next action (date) | Link/notes |
|------|---------------------------|------|---------|-----------|--------|-----------|-------------------|-----------|
| 2026-07-03 | <Name> @ <Company> | recruiter | email | pulse-pos | approved-pending-send | drafted | send + follow-up 1 (07-07) | <job link> |
```

**Status** values: `drafted` -> `approved-pending-send` (he approved a hand-off channel, waiting for him to send) -> `sent` (he confirmed it went out, OR a WhatsApp send fired) -> `replied` / `follow-up-1` / `follow-up-2` / `closed-no-reply` / `won` (call booked / advancing) / `passed`.

- On **drafting**: add/refresh the row as `drafted`.
- On **approval of a hand-off channel** (email/LinkedIn/Threads/form): set `approved-pending-send`; provide the paste-ready block; move to `sent` only after Christopher confirms he sent it.
- On a **WhatsApp send** (after approval + JID-verify): set `sent` directly (it actually fired), set last-touch + next-action date, offer the `/remindme`.
- On **reply**: set `replied`, stop the cadence, note the outcome (rule 7).
- **Strategic parent**: this per-lead tracker is the tactical log; the strategic parent is the initiative `~/claude/notes/initiatives/dev-job-outreach.md` (standing rules, positioning, the Laurel-pitch critique lessons, child-task history). Cross-link a new lead there when it matters; do not fork a parallel strategy.
- `track` intent: read the file, show an at-a-glance table (esp. rows with a due/overdue next-action or a stale `approved-pending-send` that never went out), surface anything slipped.
- PII-aware: it is in his private notes, but still never dump secrets; a name + company + public link is fine.

---

## 10. BOUNDARY / HAND-OFF (what is this skill, and what is NOT)

- **`/outreach`** = a researched **1:1 first-touch + finite follow-up to a specific person** about work-for-Christopher. This skill.
- They show interest and want scope / pricing / a formal quote -> **`/proposal`** (a technical proposal / SOW / quote / client pitch document; the formal artifact AFTER interest, not a cold first-touch).
- One-to-many marketing / brand copy (a headline, hero, landing, ad, broadcast email, a public Threads POST) -> **`/copywriting`** (`/copy`). That is one-to-many brand voice, NOT a 1:1 personal message. If the task drifts into "write our marketing email" or "a launch post", it is copywriting, not outreach.
- The proof-point artifact itself (turn a repo into a case study, generate the cover blurb) -> **`/case-study`**. Its `--for application` output is the bridge INTO this skill (a ready, strict-voice, paste-ready blurb at `~/claude/notes/applications/`).

If a request is really a proposal or marketing copy, say so and route it, do not draft a SOW or a blast inside `/outreach`.

---

## 11. FAILURE MODES (avoid all)

| Failure mode | Smell | Fix |
|---|---|---|
| **Phantom autonomous send** | Skill "sends" an email / LinkedIn / Threads / form msg on approval as if a tool exists | Rule 2 + the Matrix: those channels have NO send tool. Output a paste-ready block; he sends. Tracker `approved-pending-send` -> `sent` on his confirm. |
| **Un-repliable no-reply email** | An outreach email fired from `no-reply@aenoxa.com` to a recruiter | Never send outreach from no-reply. Email default = hand-off, he sends from his own client (Matrix). |
| **Threads worker freeze** | A worker burns to ~90% context trying to browser-send a Threads DM | `feedback_threads_dm_automation_context_bound`: don't automate the send. Hand Christopher the verbatim text; recon defers to `/agent-browser`. |
| **Wrong / hand-typed WhatsApp recipient** | Sent to a fuzzy name-match or a hand-typed JID; landed on a stranger | Rule 6: `list_chats` -> copy JID same-turn -> `check_number` -> send with the JID. Never a name, never from memory. |
| **Auto-sent without approval** | A message went out Christopher never saw | Rule 1 is absolute: draft, readiness-score, present, wait for his go. |
| **Template-blast** | Same message, name swapped; specificity index < 3; passes the swap-test as generic | §5 index + audit; research more (§2); make the body depend on THIS target. |
| **Pitch-led, no proof** | Opens with "I am passionate / hard-working", no shipped thing | Rule 4: lead with a real, relevant proof-point + its exact link. |
| **Invented URL / metric** | A proof link or number that is not real | Rule 4: cite only `references/proof-assets.md` links + real results; CV via `ls -t`, never hardcode. |
| **Corporate-eager or dash/emoji voice** | "I would be thrilled, I hope this finds you well"; a long dash; an emoji | §6 grep + §0.1/§0.2; rewrite direct + specific in his register (§7). |
| **Overclaimed fit** | Claims a stack/experience he does not have to land it | §2c honesty; lead with the real overlap; flag bad fits. |
| **Auto-replied to a target** | The skill answered a recruiter's reply on its own | Rule 7: replies are Christopher's; surface, don't auto-answer. An "is this AI?" surfaces to him. |
| **Spammy follow-up** | "Just bumping this" with nothing new; > 3 touches; chasing past a no | §8 cadence: finite, value-adding, STOP on no/silence. |
| **Lead rot** | Sent and forgotten; no follow-up ever fires | §9 tracker + `/remindme` pairing so it resurfaces. |
| **Leaking secrets/PII** | Internal infra, keys, private client names in a public message | Keep the proof public-safe; never expose secrets/private client identities. |

---

## EXECUTION FLOW

1. **Parse** (§1) -> intent (new / follow-up / track), target, type, channel, warm-vs-cold. Note the channel's Send-Capability Matrix row. Ask if the target is unclear.
2. **Research** (§2) -> the checklist; gather >= 3 real specifics + the best-fit proof-point (exact link from `references/proof-assets.md`). Honest fit (§2c). If thin, flag (§2d). Check `~/claude/notes/applications/` for a ready cover blurb.
3. **Channel + proof** (§3, §3a) -> pick channel + length budget + the proof that maps to this target.
4. **Draft** (§4) -> the right frame, filled from research, in the §7 register for this channel; lead with proof; one ask.
5. **Audit + score** (§5 specificity index + §6 banned/format grep + §7 voice) -> then the 8-gate **Outreach Readiness Score**. `< 8/8` -> fix, do not present.
6. **Present for approval (rule 1)** -> show the exact final text + channel + recipient. **NOTHING has gone out.** Wait for his explicit go.
7. **On his approval** -> follow the channel's Matrix row: **email/LinkedIn/Threads/form** = output the paste-ready block (recipient + subject + text + CV path), tell him to send it, set the tracker to `approved-pending-send` (-> `sent` after he confirms); **WhatsApp** = main-session `list_chats` + copy JID + `check_number` + `send_message(to=<JID>)`, set `sent`. Then write/refresh the §9 tracker row and offer `/remindme` for the next follow-up.
8. **Follow-up / track** intents -> §8 / §9 as above; every follow-up is its own readiness-scored approval gate.

**Inline before/after (the anti-slop discipline in one shot):**
- BAD (template-blast, corporate-eager, has a long dash, no proof): `Dear Hiring Manager, I am writing to express my keen interest in the Fullstack role (long dash) I am a passionate, results-driven developer and would be a valuable asset to your team.` (the `(long dash)` token stands in for a real em dash so this file stays §0.1 grep-clean; a literal long dash in a draft fails the gate.)
- GOOD (tailored, proof-led, his register, clean punctuation, one ask): `Hi Sarah, saw the Fullstack opening at Acme, the multi-tenant billing piece is exactly what I have been building. I shipped Pulse solo, a multi-tenant offline-first POS live in production (coba-pulse.topengdev.com). Close to your stack (Next.js + Postgres). Worth a quick chat?`

Remember: this is Christopher reaching out in his own name about his livelihood. The message represents him to people who might hire him or pay him, so it must be researched enough to prove he cares, proof-led enough to be credible, in his real voice, and NEVER sent without his say-so, on a channel where the send is actually real. One sharp, personal, approved message beats a hundred templated blasts, and a message he did not approve should never exist.
