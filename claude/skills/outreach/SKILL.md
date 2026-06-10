---
name: outreach
description: Structured cold/warm outreach to recruiters and potential clients for Christopher's job-hunt + freelance push. Researches the target (role/company/person), drafts a TAILORED message (never a template blast) leading with a real proof-point, picks the right channel + length, and tracks a follow-up cadence. HARD draft-for-approval gate — NEVER auto-sends. Use when Christopher says /outreach, "reach out to X", "draft a message to this recruiter/client", "follow up with Y", or wants to contact a lead about work.
argument-hint: <target — recruiter/company/person + role or context, or a job post URL> [--channel email|linkedin|whatsapp|threads|x|form] [--type recruiter|agency|client] [--proof <project or /case-study slug>] | follow-up <target> | track
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, WebSearch, WebFetch, Skill
---

# /outreach — research → tailored, proof-led outreach → approval gate → tracked follow-up

Turn "reach out to this recruiter/client" into a **researched, personalized, proof-led message that Christopher approves before anything sends**, plus a follow-up cadence and a tracker so leads don't rot. This is a livelihood tool: freelance outreach is the anchor income path (the survival floor before the BRI contract ends), and the difference between a reply and silence is whether the message proves you bothered to understand the target and can point at real shipped work.

The two failure modes this skill exists to prevent: **(1) generic template-blasts** that scream "I sent this to 200 people" and get ignored or burn the contact, and **(2) auto-sending** something half-baked, mis-targeted, or off-voice that Christopher would never have approved. So the spine is: **research first → personalize hard → lead with a real proof-point → show Christopher the draft → only HE triggers the send.**

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES — READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

Violating any one is a failed outreach, not a stylistic choice.

1. **DRAFT-FOR-APPROVAL — NEVER AUTO-SEND. EVER.** This skill DRAFTS. It does not send. No `send_message`, no email-send, no Threads post, no form-submit, no DM — until Christopher reads the exact final text and explicitly says go ("send it" / "approved" / "yes send"). Present the draft, the channel, the recipient, and WAIT. This is a hard gate even for warm/known contacts, even for a "quick" follow-up, even when he seems to want speed. Outreach in HIS name to a recruiter/client is reputation-bearing and irreversible — a wrong send can't be unsent. If he says "just send it" without having seen the text, show the text first and confirm once. (The send itself, once approved, runs through the normal channel tool — but the approval is the gate, not optional.)

2. **PERSONALIZATION-MANDATORY — ≥3 SPECIFICS OR DON'T SEND.** Every message must contain **at least 3 concrete, target-specific facts** that prove this was written for THEM, not pasted: the person's/company's real name + what they actually do, a specific detail about the role/product/post, something real about why Christopher fits THIS one, a reference to something they shipped/wrote/announced. A message that would work verbatim for a different company FAILS this gate — rewrite it. Generic "I'm a passionate fullstack dev looking for opportunities" with the company name swapped in is a template-blast and is BANNED (rule enforced by the §5 personalization audit). If you can't find 3 real specifics, you haven't researched enough (§2) — go back, or tell Christopher the target is too thin to personalize.

3. **LEAD WITH A PROOF-POINT, NOT A PITCH.** Open (or near-open) with a concrete, relevant *shipped thing* — a real project, a live URL, a case study (pair with `/case-study`), a specific result — that maps to what the target needs. "I built X (live at Y) which is close to what you're doing with Z" beats any amount of "I'm passionate / I'm a hard worker / I'd love the opportunity". Claims of competence are cheap; a link to working software is proof. The proof-point must be REAL and relevant to THIS target (a POS case study for a retail-tech client; the QA automation story for an SDET role) — not a generic "check my portfolio".

4. **CHRISTOPHER'S VOICE — DIRECT, NO CORPORATE EAGERNESS.** Write as Christopher: direct, concise, technically credible, zero corporate-eager mush. BANNED: "I am writing to express my keen interest", "I would be thrilled/honored", "I am passionate about leveraging", "Dear Hiring Manager, I hope this email finds you well", and the rest of §6. He has a specific personal writing style for first-person prose (no emoji; restricted punctuation — line breaks instead of periods/commas/dashes; tech names kept intact — full rule in memory `feedback_toper_writing_style`); APPLY it when the channel + register suit his personal voice (Threads, a casual DM, a personal-brand note), and confirm if unsure. For a formal email to a corporate recruiter, normal clean punctuation is usually right — but still HIS register: short, direct, substance-first, never groveling. Match register to channel; never sound like a cover-letter template.

5. **ANTI-SPAM DISCIPLINE.** No blasting. No more than the §7 follow-up cadence (and STOP on a no or on silence past the cadence). Verify the channel + recipient identity before drafting a send target (right person, right JID/email/handle — never fuzzy-match a contact; for WhatsApp, the whitelist + `check_number` rule applies). Respect "no". One well-researched message > ten generic ones, and a burned contact is worse than no contact. This skill never enrolls anyone in an automated sequence — every send is individually approved (rule 1).

> If Christopher asks for something that breaks these (e.g. "blast 50 recruiters the same message", "just auto-send the follow-ups"), do NOT silently comply. Flag it: the value is in per-target personalization + his approval. Offer the right version (research + tailor each, draft for approval).

═══════════════════════════════════════════════════════════════════════════
## ✅ GATE — satisfy ALL before showing Christopher the draft (and the draft is the ONLY output until he approves)
═══════════════════════════════════════════════════════════════════════════

- [ ] **Target researched** — you ran the §2 research pass; you can name what they do + ≥3 specifics about THEM.
- [ ] **≥3 personalization specifics are IN the message** (rule 2) — verified via §5 audit, not just gathered.
- [ ] **A real, relevant proof-point leads** (rule 3) — named, and it actually maps to this target's need.
- [ ] **Right channel + right length** for this persona (§3, §4) — and the recipient identity is verified (rule 5).
- [ ] **Voice is Christopher's** — direct, no corporate eagerness; zero §6 banned phrases (grep the draft).
- [ ] **The draft is presented for approval; NOTHING has been sent** (rule 1). The send waits on his explicit go.
- [ ] **A tracker row is prepared** (§8) so the lead + cadence are logged once it sends.

If any box fails → do not present as ready / do not send. Fix first.

---

## 1. PARSE THE INVOCATION

Read `$ARGUMENTS` and classify intent:

| If `$ARGUMENTS`… | Intent |
|---|---|
| starts with `follow-up <target>` | → **FOLLOW-UP** (jump to §7 — draft the next nudge in cadence) |
| starts with `track` | → **TRACKER** (jump to §8 — show/update the outreach log) |
| a job-post URL or "reach out to <X>" or a target description | → **NEW OUTREACH** (run §2 → §6) |
| empty / vague ("reach out to someone") | ask: "Who's the target — a person, company, or job post? Paste a link or name them, and tell me recruiter / agency / direct-client." |

Extract / decide:
- **Who** — person, company, role, or post. (`--type recruiter|agency|client`; infer if obvious, else ask.)
- **Warm or cold** — does Christopher already know them / have they interacted (a Threads reply, a prior chat, a mutual)? Warm changes the opener (reference the prior touch) and softens the cadence.
- **Channel** (`--channel`; §3 picks the default if unset).
- **Proof-point** (`--proof <project|case-study-slug>`; §3a picks the best-fit if unset).

---

## 2. RESEARCH PASS (DO THIS FIRST — personalization is impossible without it)

**No drafting until you've researched.** The ≥3 specifics (rule 2) come from here. Scale effort to the target's importance, but never skip to a blank-slate template.

### 2a. The target-research checklist
Gather as many as apply (you need ≥3 real, usable specifics to clear rule 2):

- **Who they are** — the person's name + role, OR the company + what it actually builds. (Real name, spelled right. "Dear Hiring Manager" is a personalization failure if a name is findable.)
- **What they do / build** — the product, the domain, the stack if discoverable, the market. The more specific, the better the fit-hook.
- **The role / need** — if it's a job post: the actual requirements, the stack, the seniority, what they emphasize. If it's a client: the pain they likely have.
- **A recent signal** — something they shipped, announced, posted, raised, hired for, wrote. This is the strongest opener ("saw you just launched X" / "your post about Y"). The @itsmasiam + dualbyte threads are exactly this kind of signal-driven warm lead — a public post you can reference.
- **The fit angle** — the specific, honest reason Christopher matches THIS one. Not "I'm a great fit" — *why*: a stack overlap, a domain match (POS↔retail-tech, QA-automation↔SDET, bilingual↔Indo-market), a proof-point that maps to their problem.
- **The channel + contact** — where to reach them, and the exact address/handle/JID. Verify it (rule 5).

### 2b. How to research
```
# job post / company / person — pull the real details
WebFetch <job-post-or-company-or-profile URL>   → requirements, stack, product, tone
WebSearch "<company> <product> / <person> <role> recent"   → recent signal, what they ship
```
- For a **job post**: fetch it, extract the real stack + must-haves + the company's framing. Map Christopher's real experience to their list (honestly — see §2c).
- For a **company/client**: understand the product + the likely pain Christopher could solve. Find a recent signal.
- For a **person** (recruiter/founder): role, what they're hiring for, any public posts. (For a Threads/X lead, the post itself is the signal — read it.)
- **Cross-reference Christopher's real arsenal** in `~/.claude/memory/` (now a private repo): `project_income_diversification_2026` (positioning: premium bilingual fullstack + native mobile + infra + AI — a rare combo; freelance = anchor), `project_aenoxa_pos_web`, the Pulse/fitest/QA project entries, and any existing `/case-study` outputs in `~/claude/notes/case-studies/`. These are the proof-points + the honest skill inventory you draw the fit-hook from.

### 2c. Honesty in the fit (no-yesman applies to selling too)
The fit-hook must be **true**. Don't claim a stack he hasn't touched or oversell the match to land the message — a fabricated fit gets exposed in the first call and burns the lead worse than a pass. If the match is partial, lead with the real overlap and be straight about the rest. (This is the no-sugarcoat rule applied to self-promotion: claim what's real, position it well, don't inflate.) If the target is a genuinely bad fit, tell Christopher — don't manufacture enthusiasm for a role he shouldn't chase.

### 2d. If research comes up thin
If you can't find ≥3 real specifics (obscure company, no public footprint), tell Christopher: "I can only find [X, Y] about this target — that's thin for a personalized message. Options: (a) you give me more context, (b) I draft a shorter, lower-investment touch and we accept a lower hit-rate, (c) skip it." Don't paper over a thin target with generic filler (that violates rule 2).

---

## 3. CHANNEL SELECTION + LENGTH

Pick the channel that fits the target + relationship. Each has a length budget — overshooting it is a spam-tell.

| Channel | Best for | Length budget | Notes |
|---|---|---|---|
| **Email** | Formal recruiter, agency, structured client intro, when an address is known | 90–150 words, a real subject line | Most room for a proof-point + fit. Subject must be specific, not "Job application". |
| **LinkedIn** | Recruiters, hiring managers, professional warm reach | Connection note ≤ 280 chars; InMail/DM 100–130 words | The note is brutal on length — one sharp proof-hook + one ask. |
| **WhatsApp** | A warm/known contact, an Indo lead, someone who gave a number (e.g. a recruiter like Laurel) | 2–5 short lines | Casual register. Whitelist + `check_number` BEFORE any send target (rule 5). Often Bahasa for Indo contacts. |
| **Threads / X** | A public-post lead (the @itsmasiam / dualbyte pattern), founder/dev-community warm reach | Reply: tight; DM: 2–4 lines | Christopher's stylized voice fits here (no-emoji / restricted-punctuation — `feedback_toper_writing_style`). Lead by engaging the actual post. |
| **Application form** | A job portal with a "message"/cover field | Match the field; usually 80–150 words | Treat the cover field like a tight email; still personalize + proof-lead. |

Default if `--channel` unset: email for a formal recruiter/agency with a known address; LinkedIn for a hiring manager; the native platform for a public-post lead (Threads/X); WhatsApp only for an explicitly warm Indo contact who shared a number.

### 3a. Picking the proof-point (rule 3)
Match the proof to the target's need — don't reach for the same one every time:
- Retail / POS / SMB-tech client → the **Pulse POS** case study (multi-tenant, offline-first, native hardware).
- A role/client emphasizing **QA / testing / SDET** → the **fitest QA-automation** story (900+ rows, framework-bug diagnosis).
- A **frontend / design-quality** role → a polished shipped UI (a landing/oneshot build, the design-system work).
- **Infra / fullstack / AI** → the self-hosted stack (VPS + Docker + nginx, the AI integrations, signal-trader).
If a `/case-study` for the right project doesn't exist yet, suggest running `/case-study` first to generate the proof-point, then lead the outreach with its link/blurb. **`/case-study` --for application** emits a ready cover-blurb designed to slot straight in here.

---

## 4. MESSAGE TEMPLATES (per channel × persona — frames, NOT fill-in-the-blank blasts)

These are **structural frames** showing the shape + the proof-led, personalized discipline. **Every bracket is filled from §2 research for THIS target** — never shipped as-is, never reused across targets (that's the template-blast rule 2 bans). The point of a frame is consistent *structure + voice*, with unique *content* every time.

### Frame: Email → recruiter / hiring manager
```
Subject: <specific — role + a hook, e.g. "Fullstack (Next.js + native mobile) — built a multi-tenant POS solo">

Hi <Name>,

<Opener: a real signal about them — the role/product/post — proving you researched.
e.g. "Saw the <role> opening at <Company> — the <specific stack/product detail> is right in
what I've been building.">

<Proof-point, leading: a real shipped thing that maps to their need + a link.
e.g. "I built Pulse, a multi-tenant offline-first POS, solo — live in production. Short
write-up: <case-study/portfolio link>.">

<The fit, honest + specific: why THIS one. The real overlap, not "I'd be a great fit".>

<One clear, low-friction ask: a call, a reply, "worth a chat?". One ask, not three.>

<sign-off — his name>
```

### Frame: LinkedIn connection note (≤ 280 chars)
```
Hi <Name> — saw <Company> is hiring for <role>. I build <one-line: the relevant thing>,
shipped solo to production (<proof link>). Close to your <specific>. Open to a quick chat?
```
(One proof-hook, one specific, one ask. No room for fluff — that's the point.)

### Frame: WhatsApp → warm Indo contact (Bahasa, casual)
```
Halo <Name>, <context of how you know them / the referral>.

Gue lagi <looking for / open to> <freelance/role>. Baru aja ship <the relevant thing> —
<live link / 1-line proof>.

Kayaknya nyambung sama <their thing>. Boleh ngobrol bentar?
```
(Short, natural, real-friend register — not corporate. Emoji only from the allowlist if any.)

### Frame: Threads / X → public-post lead (Christopher's stylized voice)
```
<Engage the actual post first — a real, substantive reaction to what they said, not "great post">

<the relevant proof-point + link, in his style: no emoji, line breaks instead of commas/periods,
tech names intact>

<a light, non-needy opener to talk — not a hard pitch into their replies>
```
(This is the @itsmasiam / dualbyte pattern: the post is the warm-in; lead by adding to the conversation, then surface the proof. Apply `feedback_toper_writing_style` here.)

### Frame: Direct-client (agency or end-client) → email/DM
```
<Name / company> — <a real observation about their product/problem that shows you get it>.

I'm a fullstack engineer (<the rare-combo positioning: bilingual + Next.js + native mobile +
infra + AI>). I shipped <the most relevant proof + link> which overlaps with <their thing>.

<What you could do for them, concretely — tied to a likely pain, not a feature list.>

<Soft ask: "open to a quick call to see if there's a fit?">
```

### Universal structure (every channel)
1. **Hook** = a real signal about THEM (research-proof). 2. **Proof** = a relevant shipped thing + link (rule 3). 3. **Fit** = the honest, specific why-this-one. 4. **Ask** = one clear, low-friction next step. Cut anything that isn't one of these four. No "hope this finds you well", no CV-dump, no three asks.

---

## 5. PERSONALIZATION AUDIT (run before presenting — rule 2 enforcement)

Before showing Christopher the draft, audit it:

- [ ] **Count the target-specific facts.** ≥ 3 concrete details that are TRUE of this target and would NOT fit another company/person. (Name + what-they-do counts as up to 2; a recent-signal reference is a strong 3rd.) < 3 → not ready; research more or rewrite.
- [ ] **The swap test.** Could this message be sent verbatim to a different target by swapping only the name? If yes → it's a template, FAIL. The body must depend on THIS target's specifics.
- [ ] **The proof leads + maps.** A real, relevant proof-point is near the top AND it actually fits this target's need (not a generic "see my portfolio").
- [ ] **The ask is single + low-friction.** One next step, easy to say yes to.
- [ ] **Length within the channel budget** (§3).
- [ ] **Honest fit** (§2c) — no overclaimed stack/match.

Any unchecked box → fix before it reaches Christopher.

---

## 6. BANNED PHRASES (anti-corporate-eager — rule 4)

Grep the draft; kill every one (replace with direct, specific, or cut):

**Corporate-eager / groveling:** "I am writing to express my keen interest", "I would be thrilled/honored/delighted", "I hope this email finds you well", "Dear Hiring Manager / To Whom It May Concern" (when a name is findable), "I am confident that I would be a valuable asset", "I would welcome the opportunity", "Thank you for considering my application", "I look forward to hearing from you at your earliest convenience", "please do not hesitate to".

**Empty self-claims (no proof):** "passionate about", "hard-working", "team player", "fast learner", "results-driven", "detail-oriented", "go-getter", "wear many hats", "think outside the box", "self-starter", "proven track record" (unless you're pointing AT the proof).

**Résumé filler:** "leverage/leveraged", "synergy", "cutting-edge", "robust scalable solution", "seamlessly", "spearheaded", "utilized", "best-in-class", "dynamic environment", "fast-paced environment".

**Needy / low-status tells:** "I know you're busy but", "sorry to bother you", "I'd be so grateful", "even a few minutes would mean a lot", "I'll work for free to prove myself" (undersells), excessive exclamation marks, over-apologizing.

Replacement discipline: every banned phrase cut is replaced by a **concrete specific** (a real detail, a proof link, a direct statement) — not a softer cliché. Direct + specific reads as confident + competent; eager + generic reads as desperate + interchangeable.

---

## 7. FOLLOW-UP CADENCE + SCHEDULE (`follow-up` intent)

A single message rarely lands; a pest never does. The cadence — **polite, value-adding, finite, and STOP on a no or past the end**:

| Touch | Timing (after prior, no reply) | Content |
|---|---|---|
| **1 — initial** | day 0 | the researched, proof-led message (§2–§6) |
| **2 — first follow-up** | +3–4 business days | short bump; ADD value (a new relevant proof, a quick thought on their product) — never just "did you see my message?" |
| **3 — final follow-up** | +7 days after #2 | brief, graceful close-out: "I'll leave it here — if the timing changes, easy to reach me at X." Leaves the door open, no guilt. |
| **STOP** | after #3, or on any "no" / "not now" | Do not contact again about this. (A "not now" → log a far-future optional re-touch, only if they invited it.) |

Rules:
- **Each follow-up is its own draft-for-approval** (rule 1) — never auto-fire a sequence. The skill drafts the next touch; Christopher approves the send.
- **Every follow-up must add something** — a new proof-point, a relevant observation, a useful link. A content-free "just bumping this" is spam.
- **Warm leads** can use a softer/shorter cadence; **a reply** ends the cadence (switch to a real conversation, no more scripted touches).
- **Scheduling the reminder:** to actually remember a follow-up, pair with `/remindme` (e.g. `/remindme in 4 days follow up with <target>`) so it surfaces as a WhatsApp nudge — a tracker row alone is passive and gets forgotten. Offer to set this when a message sends.

`follow-up <target>` flow: read the tracker row (§8) for this target → confirm no reply came → check which touch is next + that the timing is due → draft that touch (adding value) → present for approval → on send, update the tracker + offer the next `/remindme`.

---

## 8. TRACKER (so leads don't rot)

Maintain a simple, greppable log at **`~/claude/notes/outreach/tracker.md`** (create dir/file if absent). One row per target:

```
| Date | Target (person @ company) | Type | Channel | Proof used | Status | Last touch | Next action (date) | Link/notes |
|------|---------------------------|------|---------|-----------|--------|-----------|-------------------|-----------|
| 2026-06-11 | <Name> @ <Company> | recruiter | email | pulse-pos | sent | initial | follow-up 1 (06-15) | <job link> |
```

**Status** values: `drafted` → `sent` → `replied` / `follow-up-1` / `follow-up-2` / `closed-no-reply` / `won` (call booked / advancing) / `passed`.

- On **drafting**: add/refresh the row as `drafted`.
- On **send** (after Christopher's approval): flip to `sent`, set last-touch + next-action date, and offer the `/remindme` for the next-action.
- On **reply**: set `replied`, stop the cadence, note the outcome.
- `track` intent: read the file, show an at-a-glance table (esp. rows with a due/overdue next-action), surface anything that's slipped.
- Keep it PII-aware — it's in his private notes, but still don't dump secrets; a name + company + public link is fine.

---

## 9. WORKED EXAMPLES (input → what the skill does)

### Example 1 — `/outreach https://<jobpost> --type recruiter --channel email`
1. **Research (§2):** WebFetch the post → real stack (e.g. "Next.js + Postgres, B2B SaaS, remote"), seniority, what they emphasize; WebSearch the company → they just shipped feature X. Cross-ref memory → Pulse (Next.js, multi-tenant, production) is the mapping proof.
2. **Pick proof (§3a):** Pulse POS case study (Next.js + multi-tenant + production = direct stack/scale overlap). If no case study exists → suggest `/case-study aenoxa_pos_web --for application --role <this role>` first.
3. **Draft (§4 email frame):** subject names the role + the POS hook; opener references their actual stack + the recent feature; proof-point leads with Pulse + the case-study link; fit is the honest Next.js/multi-tenant/production overlap; one ask ("worth a quick chat?").
4. **Audit (§5 + §6):** ≥3 specifics (company name, the stack detail, the shipped-feature reference) ✓; swap-test fails-as-template? no — it's theirs ✓; zero banned phrases ✓.
5. **Present for approval (rule 1):** show the full email + subject + recipient. **Send nothing.** Wait for "send it".
6. **On approval:** send via the email tool, add tracker row `sent`, offer `/remindme in 4 days follow up`.

### Example 2 — `/outreach @itsmasiam --channel threads` (warm, public-post lead)
1. **Research:** read the actual thread (what masiam posted), their work/context; pull the relevant proof from memory.
2. **Voice:** Threads → Christopher's stylized voice (no emoji, restricted punctuation, tech names intact — `feedback_toper_writing_style`).
3. **Draft (§4 Threads frame):** engage the post substantively first → surface the relevant proof + link in his style → light, non-needy opener to talk.
4. **Audit + present for approval.** Send nothing until he okays the exact text. (This is the real dualbyte/@itsmasiam pattern — a public post as the warm-in.)

### Example 3 — `/outreach follow-up <Name> @ <Company>`
1. Read tracker row → initial sent 4 days ago, no reply, next = follow-up 1.
2. Draft a SHORT bump that **adds value** (a new relevant proof / a quick thought on their product) — not "did you see my message".
3. Present for approval → on send, update tracker to `follow-up-1`, offer `/remindme` for follow-up 2 (+7d).

### Example 4 — `/outreach track`
Read `~/claude/notes/outreach/tracker.md` → render the table, highlight overdue next-actions, flag stale `sent` rows with no follow-up scheduled.

---

## 10. FAILURE MODES (avoid all)

| Failure mode | Smell | Fix |
|---|---|---|
| **Auto-sent without approval** | A message went out Christopher never saw | NEVER. Rule 1 is absolute — draft, present, wait for his go. |
| **Template-blast** | Same message, name swapped; <3 specifics; passes the swap-test as generic | §5 audit; research more (§2); make the body depend on THIS target. |
| **Pitch-led, no proof** | Opens with "I'm passionate / hard-working", no shipped thing | Rule 3 — lead with a real, relevant proof-point + link. |
| **Corporate-eager voice** | "I would be thrilled… I hope this finds you well… valuable asset" | §6 grep; rewrite direct + specific in his register. |
| **Overclaimed fit** | Claims a stack/experience he doesn't have to land it | §2c honesty; lead with the real overlap; flag bad fits. |
| **Wrong/unverified recipient** | Drafted at the wrong JID/email/handle; fuzzy-matched a contact | Rule 5 — verify identity (`check_number`/whitelist for WA) before the send target. |
| **Spammy follow-up** | "Just bumping this" with nothing new; >3 touches; chasing past a no | §7 cadence — finite, value-adding, STOP on no/silence. |
| **Lead rot** | Sent and forgotten; no follow-up ever fires | §8 tracker + `/remindme` pairing so it actually resurfaces. |
| **Leaking secrets/PII** | Internal infra, keys, private names in a public message | Keep his stylized proof public-safe; never expose secrets/private client identities. |

---

## EXECUTION FLOW

1. **Parse** (§1) → intent (new / follow-up / track), target, type, channel, warm-vs-cold. Ask if the target's unclear.
2. **Research** (§2) → the target-research checklist; gather ≥3 real specifics + the best-fit proof-point. Honest fit (§2c). If thin, flag (§2d).
3. **Channel + proof** (§3) → pick channel + length budget + the proof-point that maps to this target.
4. **Draft** (§4) → the right frame, filled from research, in his voice; lead with proof; one ask.
5. **Audit** (§5 personalization + §6 banned-phrase grep) → ≥3 specifics, swap-test passes, zero banned phrases, honest.
6. **Present for approval (rule 1)** → show the exact final text + channel + recipient. **SEND NOTHING.** Wait for Christopher's explicit go.
7. **On his approval** → send via the channel tool, write the §8 tracker row (`sent`), and offer to `/remindme` the next follow-up.
8. **Follow-up / track** intents → §7 / §8 as above; every follow-up is its own approval gate.

Remember: this is Christopher reaching out in his own name about his livelihood. The message represents him to people who might hire him or pay him — so it must be researched enough to prove he cares, proof-led enough to be credible, in his real voice, and NEVER sent without his say-so. One sharp, personal, approved message beats a hundred templated blasts — and a message he didn't approve should never exist.
