---
name: launch-strategy
description: "Plan the LAUNCH MOMENT and its T-minus sequence: Product Hunt, waitlist, beta / early-access, GA cutover, feature announcements, and hackathon / web3-app launches. Produces an owner + timing launch checklist, a computed Launch Readiness Score, and DRAFTED (never auto-sent) announcement assets. Use when the user says /launch-strategy, or mentions launch, Product Hunt, go-to-market, GTM plan, beta launch, early access, waitlist, product update, launch checklist, feature announcement, or 'we're about to ship'. For ongoing content after the launch see content-strategy; individual recruiter / hunter / influencer pitches see outreach; the code release itself see ship; the launch copy (headline / tagline / email body / tweet) see copywriting; the pitch/demo site see pitch-deck."
argument-hint: <what you are launching> [--type product|feature|minor|hackathon|web3] [--platform producthunt|x|hn|waitlist|whatsapp] [--date <target launch date>]
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, WebSearch, WebFetch, Skill
metadata:
  version: 2.0.0
---

# /launch-strategy: the launch MOMENT and its T-minus sequence

Turn "we are about to release something" into a **dated, owner-assigned launch plan that survives contact with reality**: the right launch TYPE, the channel inventory it actually has, a T-minus checklist where every item has an owner and a done-when, a computed readiness verdict, and drafted announcement assets Christopher fires himself.

This skill owns **the launch window**: the moment, the sequence around it, and the day-of operations. It does NOT own the ongoing content engine (that is `/content-strategy`), the individual pitch to a named person (that is `/outreach`), the code release itself (that is `/ship`), or the announcement copy (that is `/copywriting`). See the boundary table in §11. Staying in lane is what keeps a launch plan a launch plan instead of a vague marketing blob.

Two failure modes this skill exists to prevent:
1. **The vibe checklist.** A wall of bare checkboxes ("[ ] social posts", "[ ] launch email") with no owner, no time, no done-when. That is a wish list, not a plan. Launches are deadline-bound and multi-actor; an unowned, untimed item silently slips.
2. **AI-slop announcement copy** ("we are thrilled to announce our game-changing product") auto-blasted on the exact public surfaces (launch tweet, PH page, GA email) where reading as machine-generated, or getting shadowbanned for vote-begging, does the most damage. This skill drafts; the human fires every public send.

═══════════════════════════════════════════════════════════════════════════
## 0. PRIME META-RULES (OVERRIDE EVERYTHING BELOW)
═══════════════════════════════════════════════════════════════════════════

### 0.1 No em dash or en dash, ANYWHERE (PRIME RULE)

**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY output this skill produces.** Not in the plan, not in the T-minus checklist, not in a drafted launch tweet / PH tagline / maker comment / announcement email, not in the readiness report, not in this skill's own prose. This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02) and it matches `/frontend-design` and `/case-study` §0.1.

- **Use instead:** a comma, a colon, parentheses, or a line break for a clause break; the word "to" or a plain hyphen for a range ("8 to 10" or "8-10", never the en-dash form); a colon when the second half defines the first.
- **Plain hyphen-minus stays allowed** for compounds and ranges (go-to-market, early-access, 12:01, 8-10). ONLY the two long dashes are banned.
- **Scrub with meaning intact.** "the wait is over (em dash) meet X" becomes "the wait is over: meet X" (then also kill the slop, §10). Never mechanically delete a dash and leave broken grammar.
- A long dash is the single loudest "AI wrote this" tell, on exactly the public launch surfaces where that tell is fatal.

### 0.2 No emoji in Christopher's first-person launch copy

Any asset written in Christopher's / the brand's voice (launch tweet, PH tagline + maker comment, GA email body, WhatsApp announcement) ships **emoji-free**. He adds one himself if he wants. Structural markers inside THIS skill are prose, not shipped copy. The @aura0g brand voice runs the same way (`reference_aura_x_account`).

### 0.3 Verified mechanic, or flag it. NEVER platform folklore as fact

**NEVER present a platform mechanic (a launch time, a ranking rule, a cooldown, a benchmark number, an algorithm signal) as fact unless it is either in this skill's dated verified-mechanics table (§6 / `references/product-hunt-2026.md`) OR you tag it `[unverified, re-check producthunt.com]`.** Platform rules change; a stale mechanic is a failed launch. This cuts both ways: the previous version of this skill went stale by OMISSION (it never mentioned 12:01 AM PT or the vote-ask ban), which is just as damaging as inventing a rule. When a real launch date is set, re-verify the load-bearing mechanics against the current official source before committing the plan.

### 0.4 NEVER ask for upvotes / votes. Anywhere

**NEVER draft or instruct asking anyone to upvote / vote for a product (Product Hunt, a hackathon community vote, any ranked board), in a DM, tweet, maker comment, email, or WhatsApp.** Product Hunt's Community Guidelines explicitly ban it (asking for upvotes, incentivizing, mass-messaging), and it triggers shadowban or removal ([verified 2026-07, producthunt.com/help Community Guidelines]). ALWAYS phrase as "check it out", "we would love your feedback", "we just launched, comments welcome". This is enforced by V5 in the verification block (§10). It also holds for hackathon vote rounds: mobilize people to look and engage, never script "vote for us" (`reference_aura_zerocup_strategy` treats vote-rigging as a DQ vector).

### 0.5 This skill PLANS and DRAFTS. The human fires every public send

**NEVER auto-send or auto-post any public launch asset**: no launch tweet, no GA email blast, no PH submission, no waitlist blast, no WhatsApp announcement. Draft it, show Christopher the exact text + channel + recipient, and WAIT for his explicit go. This mirrors `/outreach`'s absolute draft-for-approval gate and the @aura0g rule that brand voice never auto-posts without Christopher's approval (`reference_aura_x_account`). A public launch send is irreversible and reputation-bearing; a wrong one cannot be unsent. (Purely internal planning artifacts, the checklist and the readiness report, are not "sends" and need no gate.)

### 0.6 VERIFICATION BLOCK (mechanical, ALL must return zero before delivery)

Run every one of these against EVERY artifact this run produced (the plan, the checklist, and every drafted asset). Any hit = NOT done; fix and re-run until silent. Full commands in §10; the five checks are: **V1** em/en dash · **V2** emoji in voice copy · **V3** banned launch-slop · **V4** secret/PII patterns · **V5** vote-asking phrasing. They are boolean and mechanical precisely so context pressure cannot erode them.

═══════════════════════════════════════════════════════════════════════════
## NON-NEGOTIABLE RULES (READ FIRST, THESE OVERRIDE THE TACTICS BELOW)
═══════════════════════════════════════════════════════════════════════════

Violating any one is a failed launch plan, not a stylistic choice.

1. **CLASSIFY THE LAUNCH TYPE BEFORE EMITTING ANY TACTIC (§2).** new-product / major-feature / minor-update / hackathon-submission / web3-app. NEVER run the full 5-phase product launch on a minor feature, and never treat a hackathon (jury-then-vote, hard code-lock) like a Product Hunt launch. Emitting tactics before the type is fixed is a gate failure.

2. **MAP TO THE REAL CHANNEL INVENTORY, WITH REAL NUMBERS (§3).** Before any tactic, fill the ORB inventory table with the user's ACTUAL owned / rented / borrowed channels and their real sizes (list count, follower counts, community size). A plan that could belong to any product belongs to none. Placeholder audience numbers ("~some followers") = incomplete; ask before proceeding.

3. **EVERY CHECKLIST ROW HAS AN OWNER, A TIMING, AND A DONE-WHEN (§5).** No exceptions. A checkbox with no owner and no T-minus checkpoint is a vibe, not a plan, and is rejected by the delivery gate. This is the steer's explicit hard gate.

4. **VERIFIED MECHANIC OR FLAGGED (§0.3), and NEVER ask for upvotes (§0.4).** The two platform-integrity rules. Both are enforced by verification (§10) and both can sink a real launch if broken.

5. **PLAN AND DRAFT ONLY, NEVER AUTO-SEND (§0.5).** Christopher fires every public asset. Present the draft and wait.

6. **SCHEDULE EVERY DATED MILESTONE (§5).** Every T-0 and every T-minus checkpoint gets a real reminder via CronCreate / ScheduleWakeup / Google Calendar / `/remindme`, never "remember to". A launch deadline that lives only in prose slips silently (`feedback_time_promise_scheduling`). See §5 for the horizon rule (short = cron/wakeup, weeks-out = Google Calendar, because CronCreate `durable` does not persist across a session restart).

7. **NO FABRICATED OUTCOMES.** Never state a benchmark, a competitor's placement, or "this tactic drove $X" as fact without a dated source (§0.3). Illustrative patterns are fine when tagged `[illustrative]`; a bare number presented as gospel is banned. Lead with the dated verified mechanics and Christopher's own real launch data (@aura0g), not marketing folklore.

> If Christopher asks for something that breaks these (e.g. "just blast everyone to upvote", "auto-post the launch thread", "skip the type, just give me tactics"), do NOT silently comply. Flag it and offer the correct version. The rules are the reason the plan works.

═══════════════════════════════════════════════════════════════════════════
## DELIVERY GATE (satisfy ALL before handing the plan over)
═══════════════════════════════════════════════════════════════════════════

- [ ] **Launch TYPE is classified** (§2) and the scale test was applied (product-full vs feature-lite).
- [ ] **ORB inventory table is filled with REAL numbers** (§3), no placeholders. If a number was unknown, it is flagged as a gap, not invented.
- [ ] **Every launch-checklist row has an Owner + a T-minus Timing + a Done-when** (§5). Zero bare boxes.
- [ ] **Every MANDATORY checklist row is achievable before T-0**, or the plan says NOT-READY and names the blocker.
- [ ] **Launch Readiness Score is computed and reported** as /100 with the sub-scores (§9), and the GO / CONDITIONAL / NOT-READY verdict is stated.
- [ ] **If Product Hunt is in scope**, the §6 PH gate is satisfied (12:01 AM PT scheduled, Featured awareness, supporters primed pre-launch, zero vote-ask copy, maker comment drafted).
- [ ] **Every dated milestone is scheduled** (§5, rule 6), not left in prose.
- [ ] **No public asset was auto-sent** (§0.5); every drafted asset is presented for Christopher to fire.
- [ ] **§0.6 VERIFICATION BLOCK: all five greps return zero** on every produced artifact (§10).
- [ ] **Boundary handoffs are named** (§11): what this plan hands to content-strategy / outreach / ship / copywriting / creative / pitch-deck.

If any box fails, the plan is NOT done. Fix before reporting complete.

---

## 1. OPTIONAL CONTEXT READ + PARSE THE INVOCATION

### 1a. Product-marketing context (optional, shared with content-strategy)

If `.agents/product-marketing-context.md` exists (or `.claude/product-marketing-context.md` in older setups), read it before asking questions and use what it already covers. This is an OPTIONAL context read, not a hard dependency: absence is normal, do not block on it. (The same file is read by `/content-strategy`, so a launch and its ongoing content share one context source.)

### 1b. Parse `$ARGUMENTS`

Extract:
- **What** is launching (a product, a feature, a version, a hackathon submission). If unstated, ask.
- **`--type`** product | feature | minor | hackathon | web3 (infer from the description if obvious, else the §2 triage decides).
- **`--platform`** producthunt | x | hn | waitlist | whatsapp (the primary launch surface; may be several).
- **`--date`** the target launch date, if set (drives §5 scheduling and §6 re-verification).

If the invocation is empty or vague ("help me launch"), ask a tight batch: what are you launching, is it a brand-new product or an addition to an existing one, do you have a target date, and where does your audience actually live (the ORB seed for §3).

---

## 2. LAUNCH TYPE TRIAGE (HARD GATE, do this before any tactic, rule 1)

Different launch types have fundamentally different timelines, phase counts, and primary artifacts. Fix the type first, then everything downstream forks from it.

### 2a. The one-line SCALE TEST (product-full vs feature-lite)

Ask: **does this change what the product IS, or just add to it?**
- New value proposition, new pricing, a standalone thing, or a first public release → **full launch** (new-product, runs the phases).
- An addition to something already live, same value prop, same users → **lite** (feature or minor, no phase ramp).

When torn, round DOWN in ceremony: a feature does not need a 5-phase product launch (over-applying heavyweight process to a small change is its own failure mode). But round UP in rigor: even a minor update gets the dash-ban, no-slop, no-auto-send, and scheduled-milestone rules.

### 2b. THE TYPE FORK TABLE

| Type | Phases that apply (§4) | Primary artifact | Primary channel | Typical T-minus horizon |
|---|---|---|---|---|
| **new-product** | ALL 5 (Internal to Full) | The landing page + the demo | Owned list + PH (if fit) + a launch thread | 4 to 8 weeks |
| **major-feature** | Beta + Early-Access + a "GA of the feature" moment (skip Internal/Alpha if the product is already live) | An in-product announcement + a short demo GIF | Owned list + in-app + social | 1 to 2 weeks |
| **minor-update** | NONE. This is a changelog moment, not a launch | A changelog / release-notes entry | Changelog + optional in-app toast | Same day |
| **hackathon-submission** | A COMPRESSED build-to-lock ramp, NOT the marketing phases. See `references/web3-hackathon-launch.md` | The demo video (the #1 jury artifact) + a judge-facing evidence package | The submission itself, then the community-vote round later | Bounded by the code-lock date (that date IS the hard T-0) |
| **web3-app** | Alpha/Beta on testnet, then a mainnet "launch" moment | The live app + a launch thread on X | X (crypto-native) + the project community + owned | 2 to 4 weeks; gated by the mainnet-deploy date |

Notes on the type fork:
- **minor-update short-circuits the whole skill.** If the scale test lands here, do NOT build a launch plan. Draft a changelog entry, note the optional in-app toast, and hand ongoing communication to `/content-strategy`. Say so plainly; do not manufacture a launch.
- **hackathon and web3 are NOT Product Hunt shaped.** Their timeline is anchored by a hard external date (code-lock, mainnet deploy), their #1 artifact is a demo video / evidence package, not a PH gallery, and their vote round comes AFTER a merit/jury round. The full playbook is `references/web3-hackathon-launch.md` (cites `reference_aura_zerocup_strategy` + `reference_web3_hackathon_sources`). Christopher's live context (AURA in the 0G Zero Cup) is a hackathon launch, not a SaaS launch; do not force it into the PH mold.
- **A launch can be multi-surface.** A new-product launch might do a waitlist (owned) + a PH launch (rented) + an X thread (rented) on the same T-0. The type sets the SPINE; §3 maps the surfaces.

---

## 3. ORB CHANNEL INVENTORY (HARD GATE, real numbers required, rule 2)

The ORB model (Owned / Rented / Borrowed) is the mental frame; the GATE is a filled inventory table with real numbers. Everything a launch does should ultimately drive attention back into OWNED channels, because that is the audience you keep.

### 3a. The three channel classes

- **Owned** (you control the channel, though not the algorithm-free audience): email list, blog, a branded community (Slack / Discord / WhatsApp group), the website / in-product surface, a podcast. These compound over time and have no pay-to-play. Start with 1 to 2 based on where your audience is.
- **Rented** (visibility you borrow from a platform whose rules shift): X / Twitter, LinkedIn, Instagram, YouTube, Reddit, app stores and marketplaces, and Product Hunt itself. Pick 1 to 2 where the audience actually is; use them to drive traffic INTO owned. Speed, not stability.
- **Borrowed** (someone else's audience, the shortcut to getting noticed): guest content (podcast interviews, newsletter features, guest posts), collaborations (co-marketing, webinars), a reviewer / influencer who covers you, an affiliate / referral loop, a launch-day hunter with reach. Instant credibility, but only works if you convert borrowed attention into owned relationships.

### 3b. THE INVENTORY GATE (fill before any tactic)

| Channel | Own / Rent / Borrow | Current size (REAL number) | Launch-day role |
|---|---|---|---|
| (e.g. Email list) | Own | (e.g. 500 subscribers) | Primary T-0 announce |
| (e.g. X / Twitter) | Rent | (e.g. 2,000 followers) | Launch thread + amplification |
| (e.g. a target subreddit) | Borrow | (community size) | Show-and-tell post, honest |
| ... | ... | ... | ... |

Rules for the gate:
- **Real numbers, not adjectives.** "A small list" fails; "500 subscribers" passes. If a number is genuinely unknown, write `[unknown, ask Christopher]` and flag it as a gap, do NOT invent one.
- **If owned is thin or empty**, that is the single most important finding: the plan's first job is to BUILD an owned surface before the launch (a waitlist, §ref channel-playbooks), because launching into a vacuum is the #1 flop cause (§8). Say this plainly.
- **Every rented / borrowed play must name where it funnels INTO owned** (the tweet links to the waitlist; the podcast mentions the newsletter). A rented play with no owned funnel leaks the attention you paid for.
- Per-channel launch-day do/dont tactics and the waitlist mechanics live in `references/channel-playbooks.md` (kept out of SKILL.md to stay load-fast).

---

## 4. THE LAUNCH PHASES (scale-forked per §2, time-bound)

A full launch is not a one-day event; it is a ramp that builds an audience BEFORE the moment so the moment has somewhere to land. **Which phases run is set by the §2 type** (the table's "Phases that apply"). Do NOT run all 5 for a feature.

| Phase | Goal | Core actions | Runs for |
|---|---|---|---|
| **1. Internal** | Validate core function with friendly users | Recruit early users 1:1 to test free; collect usability + missing-feature feedback; prototype functional enough to demo (not production-ready) | new-product only |
| **2. Alpha** | First external validation + start the waitlist | Landing page with an early-access signup; announce it exists; invite users individually; MVP working in production even if evolving | new-product (web3: on testnet) |
| **3. Beta** | Build buzz + refine with broader feedback | Work the early-access list (some free, some paid); teasers about the problem you solve; recruit friends / investors / a reviewer to try + share; a "coming soon" page; a "Beta" tag in-product; an early-access toggle | new-product + major-feature |
| **4. Early Access** | Validate at scale + prep the full moment | Leak real detail (screenshots, feature GIFs, a demo); gather quantitative usage + qualitative feedback; user research with engaged users (credits as incentive); optional PMF survey to sharpen the message; expand by throttled batches (5 to 10% at a time) OR invite all under an "early access" frame | new-product + major-feature |
| **5. Full (GA)** | Maximum visibility + conversion | Open self-serve signups; start charging (if not already); announce general availability across every mapped channel. Day-of touchpoints: the owned-list email, in-app popup / product tour, a website banner, a "New" tag in-product, a blog post, the social thread, and the rented boards (PH / BetaList / HN) if they fit | every full launch |

Time-bound it: attach each phase to a T-minus band from §2's horizon (e.g. for a 6-week new-product launch: Internal at T-42 to T-28, Alpha T-28 to T-14, Beta T-14 to T-7, Early Access T-7 to T-1, Full at T-0). The exact bands become rows in §5.

> The GA cut itself (the code going live, the version tag) is `/ship`'s job, not this skill's. This skill sequences the marketing moment AROUND the ship; `/ship` moves the code through git + CI + tag. Hand the actual release step to `/ship` and reference it as a dependency in the checklist (§5).

---

## 5. THE OWNER + TIMING LAUNCH CHECKLIST (HARD GATE, rule 3)

This replaces bare checkboxes with a schema where **every row carries an Owner, a Timing (T-minus checkpoint), a Dependency, and a Done-when**. A row missing any of those is rejected.

### 5a. The schema

```
| T-minus | Item | Owner | Depends-on | Done-when | M/O |
```
- **T-minus**: a checkpoint relative to T-0 (T-30, T-14, T-7, T-3, T-1, T-0, T+1, T+7). T-0 is the launch moment. For a hackathon, T-0 is the code-lock date (§2).
- **Owner**: who does it. In Christopher's context this is usually `You` or a delegated skill (`Copywriting`, `Creative`, `Ship`, `Deploy`, `Outreach`). Never blank.
- **Depends-on**: the row(s) that must finish first, or `-`.
- **Done-when**: the concrete, checkable completion signal (a URL resolves, an asset exists at a path, an email is queued, a count is hit). Never "done", always a signal.
- **M/O**: Mandatory or Optional. A MANDATORY row not achievable before T-0 flips the readiness verdict to NOT-READY (§9).

### 5b. Worked recipe: a new-product PH + waitlist launch (adapt the T-bands to the real horizon)

| T-minus | Item | Owner | Depends-on | Done-when | M/O |
|---|---|---|---|---|---|
| T-30 | Stand up the waitlist landing page | You / Deploy | - | Page live, email capture stores a test signup | M |
| T-30 | Draft the positioning one-liner (the ONE new thing + who for) | Copywriting | - | One line passes the §10 specificity test | M |
| T-21 | Start priming supporters (real people who will engage on PH), get them PH-active | You | waitlist live | 30 to 50 named supporters have active PH accounts (not day-0) | M (if PH) |
| T-14 | Produce launch assets (demo video / GIF, PH gallery images at spec, OG image) | Creative | positioning | Assets exist at the required sizes, reviewed | M |
| T-14 | Draft the launch tweet / thread + the PH tagline + maker comment | Copywriting | positioning | Drafts exist, zero slop (§10), zero vote-ask (§0.4) | M (if PH/X) |
| T-7 | Schedule the PH launch for 12:01 AM PT on the chosen day (§6) | You | assets, PH profile aged | PH shows the scheduled launch | M (if PH) |
| T-7 | Draft the GA announcement email to the owned list | Copywriting | positioning | Draft ready, one clear CTA to the product | M |
| T-3 | Freeze the code + hand the GA cut to /ship | Ship | product ready | /ship preflight green, tag ready to push at T-0 | M |
| T-1 | Confirm day-of ops window + who watches comments (PH runs on PT, §6c) | You | - | Named coverage for the first 6h PT window | M (if PH) |
| T-0 | Fire the launch: /ship the release, then Christopher sends the tweet + PH submit + email | You (Christopher fires) | all above | Product live, PH live at 12:01 PT, thread + email sent | M |
| T-0 | Post the maker's first comment on PH (context, not a vote-ask) | You (Christopher) | PH live | Maker comment visible | M (if PH) |
| T+1 | Reply to every PH comment within ~30 min through the PT day | You | PH live | All comments answered | M (if PH) |
| T+1 | Convert launch traffic into owned (waitlist / email capture on-site) | You | product live | Signup path from launch traffic verified | M |
| T+7 | Post-launch retro + hand ongoing content to /content-strategy | You | - | Retro noted, content-strategy briefed | O |

This is a RECIPE, not a fixed list. Prune rows by type (a feature-lite launch drops the phase-ramp and PH rows; a hackathon replaces the PH rows with the demo-video + evidence-package rows from `references/web3-hackathon-launch.md`). But whatever survives, every row keeps its Owner + Timing + Done-when.

### 5c. SCHEDULE the milestones (rule 6, do not skip)

Every dated row is a time-promise, and a time-promise that lives only in this table slips (`feedback_time_promise_scheduling`). For each MANDATORY dated row:
- **Short horizon (hours to same-day):** `ScheduleWakeup` (delay clamped to [60, 3600] s) or a one-shot `CronCreate`.
- **Long horizon (days to weeks out, the usual launch case):** the **Google Calendar MCP** (`mcp__claude_ai_Google_Calendar__create_event` on `$TOPER_EMAIL`, TZ Asia/Jakarta), because CronCreate `durable` is session-only and does NOT survive a restart (verified 2026-06-25). Use a timed event with `overrideReminders:[{"method":"popup","minutes":0}]`, which fires a native phone popup.
- Or hand the whole set to `/remindme` for WhatsApp nudges.
- **The 12:01 AM PT PH slot is the highest-stakes reminder.** Convert PT to WIB (12:01 AM PST is about 15:01 WIB, PDT about 14:01 WIB) and schedule it precisely; missing the window forfeits the 24h race (§6).

---

## 6. PRODUCT HUNT: verified 2026 mechanics + the PH gate (only if PH is in scope)

Product Hunt reaches a tech / early-adopter audience and gives a credibility bump, but it is a competitive 24h race that rewards preparation, not magic. **These mechanics were verified 2026-07 against 10+ current guides + the official Community Guidelines and Featuring Guidelines. Re-verify the load-bearing ones at producthunt.com before a real launch (§0.3).** The full encyclopedia (algorithm detail, weighted-vote math, benchmarks, hunter-vs-self, all sourced + dated) is `references/product-hunt-2026.md`.

### 6a. The mechanics that decide the launch (verified 2026-07, re-check before launch)

| Mechanic | The rule | Why it is load-bearing |
|---|---|---|
| **Fixed 12:01 AM PT start** | Every launch goes live at 12:01 AM Pacific and runs a 24h day to 11:59 PM PT. No later slot. You can schedule up to ~1 month ahead. | Launch at 11 PM PT and you get 1h of the day. This is THE core timing mechanic. |
| **First ~4 hours are hidden + randomized** | Vote counts are hidden and the homepage is sorted randomly for roughly the first 4 hours; counts surface around 4 AM PT. | Early velocity still counts even though you cannot see it; the goal is Top 4-5 as counts surface. |
| **First-hours velocity dominates** | The algorithm rewards a fast, accelerating curve in the first ~6 hours (rough target: 200+ upvotes and 30+ comments in the first 6h). Products at the top early tend to stay there. | A steady wave (12 AM, 7 AM, 2 PM PT) beats one midnight spike; a spike-then-flat curve ranks LOWER. |
| **Featured vs All** | PH manually curates a Featured set. **Only Featured launches appear on the homepage AND in the mobile app.** Not-featured = near-zero organic reach no matter the upvotes. Featuring is NOT guaranteed and decisions are final. | You can do everything right and still get near-zero traffic if not Featured. Design for the featuring criteria (6b). |
| **Weighted votes** | An upvote from an established account (aged, with history, follows you, votes in the first hour) is worth several times a brand-new account's. Accounts created within ~72h are shadow-filtered ("newbie"); vote-once-then-vanish accounts get devalued ("lurker"). | This is WHY you prime real PH-active supporters weeks ahead, not blast a cold list on the day. |
| **Engagement > raw upvotes (2026 shift)** | The 2026 algorithm weights comments, maker replies, thread depth, and bringing NEW users to PH more than raw upvote count. | Reply to every comment; depth beats a vanity number. |
| **Day-of-week tradeoff** | Tue/Wed/Thu = most traffic AND most competition (big players drop then). Fri/Sat/Sun = less traffic but a higher chance of #1-of-the-day. Explicit tradeoff. | Pick by GOAL: Tue for max raw traffic even at rank #5-6, weekend for a #1 badge. |
| **~6-month relaunch cooldown** | Roughly one launch per version (v1/v2/v3), about 6 months apart; an earlier relaunch needs a request explaining a significant change. A guideline, not a hard wall. | You do not get infinite shots; make the launch count, do not burn it on a half-ready product. |
| **Benchmarks VARY (do not quote as gospel)** | 2025 to 2026 guides diverge: top-5 of the day roughly 300 to 900 upvotes (weekday higher), #1 anywhere from ~500 to ~1,800 depending on the day and source. | Treat as a rough range with real variance; never promise a number. Tag any figure you cite `[range, source-dated]`. |

### 6b. The 4 Featured criteria (official, Featuring Guidelines, verified 2026-07)

PH featuring looks for: **Useful** (practical benefit), **Novel** (innovative / unique approach), **High Craft** (well-designed, delightful), **Creative** (fun, engaging, imaginative). A launch does NOT need to score high on all four; often it spikes on one or two. Hard requirements: digital, currently live (no vaporware), and differentiated (not a minimal undifferentiated product built mainly for quick monetization). Featuring is never guaranteed; decisions are final. Design the product page + assets to hit at least one criterion hard.

### 6c. THE PH PRE-LAUNCH GATE (each row is Owner + timing; fold into §5)

- [ ] **Maker/hunter account is aged and credible** (not created days before; established accounts carry weight). Owner: You. By: T-30.
- [ ] **30 to 50 real supporters are lined up AND already PH-active** (they hold aged accounts and engage on PH before the day, so their votes are not newbie-filtered). Owner: You. By: T-14. NEVER script them to "upvote" (§0.4); ask them to check it out + comment.
- [ ] **Assets sized to PH spec** (gallery images, a short demo video, a sharp tagline). Owner: Creative. By: T-14.
- [ ] **Maker's first comment is written ~48h ahead** (the context / story, one clear thing it does + who for; NO vote-ask). Owner: Copywriting. By: T-2.
- [ ] **Launch is scheduled for 12:01 AM PT** on the goal-appropriate day (6a). Owner: You. By: T-7.
- [ ] **Day-of coverage is staffed for the first 6h PT window** (someone replies to every comment within ~30 min). Owner: You. By: T-1. Note the WIB offset (§5c).
- [ ] **Zero vote-asking language** anywhere in the PH copy, the tweet, the email, or the DMs (§0.4). Owner: You. Verified by: V5 (§10).

If PH is in scope and any MANDATORY PH row cannot be met, PH is NOT ready; say so and either fix or drop PH from this launch (an unfeatured, under-prepared PH launch converts near zero, §8).

---

## 7. FEATURE-ANNOUNCEMENT MATRIX (for major-feature / minor-update types, §2)

Not every update deserves a launch. Match the marketing weight to the update size, and never over- or under-invest.

| Update size | What it is | Channels (concrete) | Deserves a mini-PH? |
|---|---|---|---|
| **Major** | A new capability, a product overhaul, a headline feature | Full push: owned-list email + a blog post + in-app announcement + the social thread. Optionally a mini-PH launch IF it clears the featuring bar (6b) on its own. | Maybe. Only if it is genuinely differentiated and PH-worthy standalone; otherwise it dilutes your ~6-month PH shot (§6a). |
| **Medium** | A new integration, a meaningful UI improvement | Targeted: an email to the relevant segment + an in-app banner. No full fanfare. | No. |
| **Minor** | Bug fixes, small tweaks, polish | Changelog / release notes only. Signals active development, builds retention, does not dominate the channels. | No. This is the minor-update short-circuit (§2). |

Decision rule for "mini-PH or just a changelog": if the feature could stand alone as a product a stranger would seek out AND it hits a featuring criterion (6b), a mini-PH is defensible. If it only makes sense to existing users, it is a changelog + in-app moment, not a launch. When unsure, changelog it and save the PH slot.

Announcement discipline (all sizes): space releases out to sustain momentum (do not dump everything at once), reuse tactics that demonstrably worked before, and even a small changelog entry reminds customers the product is alive (retention + word-of-mouth). Ongoing cadence beyond the announcement itself is `/content-strategy`'s job (§11).

---

## 8. FLOP-RECOVERY PLAYBOOK (the launch under-performed, now what)

A launch that missed its target is a diagnosis problem, not a "post more" problem. Work the tree; the branches are ordered by how common the cause is.

### 8a. The MANDATORY first move (before any new tactic)

**Identify which channel produced the signups you DID get, and double down on THAT before adding anything new.** If 40 of 50 signups came from one subreddit, the lesson is "that subreddit works", not "I need TikTok". Do NOT scatter into new channels while the one that worked is under-exploited. This is the single most common recovery mistake.

### 8b. The diagnosis tree

| Branch | The check | The 30-day recovery move |
|---|---|---|
| **Audience not primed pre-launch** | Did you have a real owned audience (a warm waitlist, an engaged list) BEFORE T-0? | Stop re-launching. Spend 30 days building the owned list (waitlist + value content) so the NEXT moment lands on warm ground. This is the #1 cause. |
| **Wrong channel** | Where did the signups you got actually come from vs where you spent effort? | Reallocate to the channel that converted (8a). Kill the ones that produced nothing. |
| **Weak positioning** | Can a stranger say, in one line, what it does and who it is for? | Rewrite the one-liner (hand to `/copywriting`), re-test on 5 real target users, ship the winner across all surfaces. |
| **Wrong ICP** | Are the people who DID sign up the people you built for? | If not, either re-target the launch to who actually showed up, or fix the fit. Do not scale a mismatched launch. |
| **Bad timing** | Did you launch into a competitor's big day, a holiday, or a low-traffic slot (§6a)? | Pick a better window and re-run the moment (respecting the PH cooldown, §6a). |
| **No Featured on PH** | Did you actually get Featured (homepage + mobile), or were you stuck in "All"? | If not featured, PH was never going to convert (§6a). The problem is upstream: differentiation / craft (6b). Fix the product page + the differentiation before spending another PH slot. |

Do / dont:
- DO diagnose before acting. A flop with 50 signups still tells you which channel and which message worked; mine it.
- DONT immediately add three new channels. That hides the signal and burns effort.
- DO leverage the early users you got (testimonials, referrals, feedback) as fuel for the recovery.
- DONT re-launch the identical thing on PH inside the cooldown expecting a different result; it needs a real change (§6a).

---

## 9. LAUNCH READINESS SCORE (compute before delivery, report the verdict)

A weighted 0 to 100 score (modelled on `/content-strategy`'s weighted-factor pattern), scored against the actual plan, so "are we ready" is a number with named gaps, not a feeling.

| Factor | Weight | Score 0 to max on |
|---|---|---|
| **Assets ready** | 25 | Landing/product page live; positioning one-liner sharp; launch copy drafted (slop-free); visual + demo assets at spec |
| **Audience primed pre-launch** | 25 | A real owned surface exists with real numbers (§3); supporters primed (§6c if PH); waitlist warm, not cold |
| **Channel plan mapped to real inventory** | 20 | Every launch play maps to a real channel with a real number and an owned funnel (§3); no placeholder audiences |
| **Day-of ops + owners assigned** | 20 | Every mandatory §5 row has an owner + timing + done-when; day-of coverage staffed; milestones scheduled (§5c) |
| **Risks mitigated** | 10 | The §8 flop causes are pre-empted (audience not cold, positioning tested, timing sane, PH featuring designed for) |

Scoring: award each factor 0 to its weight based on how fully the plan satisfies it. Sum to /100.

**Verdict thresholds:**
- **>= 80 and every MANDATORY §5 row achievable before T-0: GO.**
- **60 to 79, or a fixable mandatory gap: CONDITIONAL.** Name each gap and the row that closes it; T-0 holds only if they close.
- **< 60, or any mandatory row unachievable before T-0: NOT-READY.** Name the blocker and either reschedule T-0 or cut scope (drop PH, delay the full launch to a feature-lite one).

Report the score AS the sub-scores, not just the total, so the weak factor is visible. A high total can never paper over a zeroed factor (a launch with perfect assets but a cold audience is not ready).

---

## 10. ANTI-SLOP GATE + VERIFICATION BLOCK

### 10a. Banned launch-slop (any drafted asset must be free of these)

Announcement copy is where launches read as machine-written. Kill every one; replace with the concrete specific, never a softer cliche:

**Announcement cliches:** "we are excited to announce", "excited to share", "thrilled to", "proud to announce", "the wait is over", "introducing the future of", "meet <X>" as an opener, "say hello to", "reimagine / reimagined", "supercharge", "10x your", "unleash", "revolutionize / revolutionary", "game-changer / game-changing", "next-generation", "one-stop", "seamless / seamlessly", a rocket-emoji opener, a hashtag wall (more than 2 to 3).

**The specificity test (must pass):** does the announcement name **the ONE concrete new thing** and **exactly who it is for**? If the sentence would fit a different product by swapping the name, it is slop; rewrite it with a detail only THIS product has. "We built offline-first order capture for Indonesian retailers on cheap Android hardware" passes; "we are thrilled to introduce a game-changing new experience" fails.

Actual copywriting (the finished headline / hero / email body / tweet) is `/copywriting`'s craft; this gate is the launch-context floor every drafted asset must clear before it reaches Christopher.

### 10b. THE VERIFICATION BLOCK (all five must return zero, §0.6)

Run against EVERY produced artifact (the plan, the checklist, every drafted asset). Replace `<files>` with the real paths.

```bash
# V1: em / en dash (must be silent)
grep -rnP "[\x{2013}\x{2014}]" <files>

# V2: emoji + variation selector in voice copy (must be silent in drafted assets)
grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]" <drafted-assets>

# V3: banned launch-slop (must be silent)
grep -rniE "we('re| are) (excited|thrilled|proud)|excited to (announce|share)|thrilled to|proud to announce|the wait is over|introducing the future|game.?chang(er|ing)|revolutionar(y|ize)|supercharge|unleash|10x your|next.?generation|one.?stop|seamless(ly)?|reimagine" <drafted-assets>

# V4: secret / PII patterns (must be silent; if a hit is real, report file + pattern TYPE only, never the value)
grep -rnE "sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[A-Z0-9]|password=|token=|@s\.whatsapp\.net|(\+?62|0)8[0-9]{7,}" <files>

# V5: vote-asking phrasing (must be silent, §0.4)
grep -rniE "upvote (us|me|it|our|my)|please upvote|give us an upvote|vote for (us|me|our|my)|need your (up)?vote|smash the upvote" <drafted-assets>
```

Notes:
- V3 is the launch-slop floor; the finished-copy ban list is broader in `/copywriting`. Any V3 hit = rewrite before delivery.
- V5 is absolute (§0.4). A single hit means the copy could get the product shadowbanned; fix it, do not ship it.
- V4: if a hit is a real secret in a data/context file, report the file + the pattern TYPE only, never the value.

---

## 11. BOUNDARY / ROUTING TABLE (what this skill owns vs hands off)

This skill owns the **launch moment, its T-minus sequence, day-of ops, the readiness gate, and channel orchestration for the launch window**. Everything else routes out. Naming the handoff is part of the delivery gate.

| Need | Route to | Why not here |
|---|---|---|
| Ongoing content after launch (editorial calendar, comparison pages, topic clusters, the content engine) | **/content-strategy** | This skill is the moment; content-strategy is the sustained program. Shares the `.agents/product-marketing-context.md` read. |
| An individual pitch to a named recruiter / hunter / influencer / partner | **/outreach** | Personalized 1:1 outreach with its own draft-for-approval gate. This skill plans the launch; outreach writes the person-specific ask. |
| The code release itself (git, CI, version tag, the GA cut) | **/ship** | This skill sequences marketing around the ship; /ship moves the code. /ship never SSHes to a server. |
| The launch COPY (headline, hero, PH tagline, email body, tweet text, CTA) | **/copywriting** | This skill drafts asset placeholders + the slop floor; copywriting is the craft + the hard quality gate. |
| The pitch / demo scrollytelling site | **/pitch-deck** | A launch may point at a pitch site; building it is pitch-deck's job. |
| Building the landing page | **/oneshot-webapp** (topengdev pitch demos) or **/frontend-design** + the Aenoxa website i18n/theme defaults | This skill needs the page to exist; it does not build it. |
| Deploying an already-built Aenoxa landing page | **/deploy-landing** | Server-side deploy mechanics (nginx, certbot, DNS). |
| Launch visual assets (OG image, PH gallery, demo GIF, social cards) | **/creative** (from scratch) or **/zografee** (reference-driven) | Creative execution is delegated (house creative-task rule); this skill specs them. |
| The launch / demo video | delegate the build as a creative task | Video production is a delegated creative task, not planned in this skill's prose. |
| A project write-up / proof-point to lead outreach with | **/case-study** | The evidence artifact; outreach + launch both consume it. |
| Scheduling the milestones | **/remindme**, CronCreate / ScheduleWakeup, Google Calendar MCP | The scheduling primitives (§5c). |
| Committing any launch asset into a repo | **/commit** (CLAUDE_COMMIT_SKILL sentinel) | Never raw `git commit`; the seal-guard hook blocks it (`feedback_commit_skill_enforced`). |

### Indonesian-market launch note (Aenoxa / Pulse)

PH and HN are US-centric. 12:01 AM PT lands around 15:01 WIB (PST) / 14:01 WIB (PDT), so a PH launch day runs through the Jakarta night: plan the day-of coverage shift (§5c, §6c). For an Aenoxa / Pulse Indonesia launch, weight **owned + WhatsApp + local-community channels + a bilingual id/en announcement** over a US PH ranking, which may be the wrong primary lever for an Indonesian product. If the launch involves a landing page, the house website default is bilingual id (default) + en (`next-intl`) with light + dark themes (`next-themes`); that BUILD is owned by `/frontend-design` / `/oneshot-webapp`, not this skill (see §11 routing).

---

## 12. TASK-SPECIFIC QUESTIONS (ask the gaps, do not interrogate)

1. What exactly are you launching, and is it a brand-new product or an addition to something already live? (Sets the §2 type + scale test.)
2. Do you have a target launch date, or are we picking one? (Drives §5 scheduling + §6 day choice.)
3. What owned channels exist, with real numbers? (Email list size, community size, blog traffic. The §3 gate.)
4. What is your rented / borrowed reach, with real numbers? (Follower counts, a hunter or reviewer, communities you can honestly post in.)
5. Is Product Hunt in scope, and what is your prep status? (Aged account, supporters, assets, cooldown standing. §6.)
6. Have you launched before? What worked, what flopped, and where did the signups come from? (Feeds §8 pre-emption.)
7. What is the ONE concrete new thing, and exactly who is it for? (The positioning seed + the §10 specificity test.)

---

## EXECUTION FLOW

1. **Read context** (§1a, optional) + **parse** the invocation (§1b). Ask the §12 gaps if the target is unclear.
2. **Classify the launch TYPE** (§2, hard gate): run the scale test, fix the type. If minor-update, short-circuit to a changelog and stop.
3. **Fill the ORB inventory** (§3, hard gate): real numbers, flag unknowns, note if owned is thin.
4. **Fork the phases** (§4) by type; time-bind them to the horizon.
5. **Build the owner + timing checklist** (§5): every row Owner + Timing + Done-when; then SCHEDULE every dated milestone (§5c, rule 6).
6. **If PH is in scope**, apply the §6 mechanics + satisfy the PH gate (12:01 PT, Featured awareness, primed supporters, zero vote-ask). Re-verify the load-bearing mechanics if a real date is set (§0.3).
7. **If feature/minor**, run the §7 matrix instead of the full phases. **If hackathon/web3**, follow `references/web3-hackathon-launch.md`.
8. **Draft the launch assets** (placeholders + the slop floor, §10a); hand finished copy to `/copywriting`. NEVER auto-send (§0.5).
9. **Compute the Launch Readiness Score** (§9); state GO / CONDITIONAL / NOT-READY with sub-scores + named gaps.
10. **Run the VERIFICATION BLOCK** (§10b): all five greps silent on every artifact.
11. **Report** as structured tables (the type + inventory, the T-minus checklist, the readiness score + verdict, the drafted assets awaiting his go, the boundary handoffs). Name what routes to which sibling skill (§11).

## COMPOSES WITH

- **/copywriting** writes the finished launch copy this skill specs + slop-floors.
- **/content-strategy** takes over the ongoing content after T-0 (shares the `.agents/product-marketing-context.md` read).
- **/outreach** drafts the person-specific pitch to a hunter / reviewer / partner the plan names.
- **/ship** executes the GA code cut this skill sequences the marketing around.
- **/case-study** produces the proof-point a launch or its outreach leads with.
- **/creative** + **/zografee** produce the launch visuals this skill specs.
- **/remindme** + the scheduling primitives make the T-minus dates real (§5c).

Remember: the value of a launch plan is that it is dated, owned, and honest. A checklist where every row has a name and a time beats any amount of tactical prose, a verified mechanic beats platform folklore, and a drafted asset Christopher fires himself beats an auto-blast he never approved. Plan the moment, map the real channels, gate the readiness, and let the human pull the trigger.
