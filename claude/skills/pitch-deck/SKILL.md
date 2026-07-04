---
name: pitch-deck
description: Hand it a product → produces an ultra-engaging scrollytelling website pitch deck that makes the target audience want to invest, purchase, or adopt immediately. Runs a 6-stage pipeline (intake → analyze → stories → explore → narrative → cinematic build) with internal self-validation at each stage and ONE final human review gate. Use when Toper says /pitch-deck, asks to build a pitch deck, investor deck, product demo site, or says "make this product compelling."
argument-hint: "<product (URL / test account / repo / brief)> [audience: investor|client|recruiter] [ask: what you want them to do]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, WebFetch, WebSearch, Agent
---

# /pitch-deck: product → cinematic scrollytelling pitch

Take a product and produce a **scrollytelling website** that makes the target audience want to invest / purchase / adopt, immediately. This is NOT a slide deck and NOT a marketing landing page. It is a **cinematic, scroll-driven narrative experience** (NYT / The Pudding style): scroll-triggered reveals, pinned sections, progressive build, scroll-linked visuals. Every scroll earns its place.

The skill runs **autonomously end-to-end**, no human interruptions mid-build, with ONE exception: a **time-boxed WOW direction ping** at the Stage-6 prototype (send + proceed on a 1h default, never an indefinite block, see Stage 6). There is **ONE human gate at the very end**: Toper reviews the finished deck and approves or iterates. The end-gate is review + refine (cheap iteration on the existing deck), NOT a rebuild from scratch.

**This means: nail the intake, or the whole deck risks missing.** Intake is the linchpin. See Stage 1.

**This skill does NOT re-document its neighbours, it CITES them (their facts are ground truth, kept current in ONE place):**

| Concern | Owned by | Never do here |
|---|---|---|
| Section variance, the WOW audit, Paper Shaders, motion/type laws | **`/artifex`** (`~/.claude/skills/artifex/SKILL.md`) | Re-summarize its audit numerically, clear §7 IN FULL |
| All browser mechanics (claim lifecycle, screenshots, teardown) | **`/agent-browser`** (`~/.claude/skills/agent-browser/SKILL.md`) | Improvise CDP; use Playwright MCP (hook-banned); restart qutebrowser |
| Product dossier (real screens + signals, cached) | **`/atlas`** (`~/.claude/skills/atlas/SKILL.md`) | Redo a full live crawl when a fresh dossier exists |
| Deploy sequence to `topengdev.com` | **`/oneshot-webapp`** (`deploy.sh`) | Hand-roll the nginx/certbot/CF steps |
| Design engineering base (type/color/motion/i18n mechanics) | **`/frontend-design`** | Re-derive typography or motion mechanics |

---

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES: READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

Violating any one = failed build. If anything below appears to conflict, the NON-NEGOTIABLE wins.

| # | Rule | Why it exists |
|---|---|---|
| **N1** | **NAMED AUDIENCE BEFORE ANYTHING ELSE.** A deck without a named audience (`investor` / `client` / `recruiter`) = STOP and ask. Audience branches EVERYTHING: story, metrics, tone, CTA. Do not infer. Do not assume. Ask. | Verified: a deck built without a named audience converges on a confused tone that works for nobody. |
| **N2** | **CRYSTAL-CLEAR INTAKE IS THE LINCHPIN.** With ONE final human gate, there is no mid-build correction. The intake (Stage 1) must lock in the exact audience, ask, LANGUAGE, product access, brand kit, metrics, and constraint. If ANY input is missing or ambiguous, ask NOW, not after 2 hours of building. A wrong intake miss = a deck that misses entirely. | The only mid-run correction opportunity is Stage 1. Use it. |
| **N3** | **MAXIMUM IMPACT, NOT MAXIMUM EFFECTS.** Every scroll-triggered section must EARN its scroll with substance. Effects serve the narrative; purposeful + performant, NEVER gimmicky. | Verified failure: art-deco Selaras/Bithour demo rejected "looked SO BAD", over-designed, under-earned. |
| **N4** | **ZERO FABRICATED METRICS.** NEVER invent traction numbers, user counts, revenue figures, or capability claims. Real numbers + honest framing only. Thin traction = frame as capability + early-stage honestly. Fake numbers kill reputation. | Hard ethical rule, no exceptions. |
| **N5** | **PERFORMANCE BUDGET: ≤ 3s TTI, ≤ 1.2s LCP on 4G, CLS ≤ 0.1, JS ≤ 300KB compressed, Lighthouse ≥ 85.** Lazy-load heavy assets; prefer CSS animations over JS where possible; audit with the named Lighthouse runner (Stage 6) before shipping. A slow pitch deck is a rejected pitch deck. | First impression dies on load. **These numbers are load-bearing OUTSIDE this file:** artifex §9 host-precedence cites this table as the winning gate for hosted builds. Do NOT change a number without updating artifex. |
| **N6** | **LIGHT MODE ONLY (pitch decks).** No dark toggle, no `next-themes`. Unless Toper explicitly overrides in the brief. (This deliberately overrides the `/frontend-design` light+dark baseline AND the house i18n/multi-theme website default, pitch demos are different from Aenoxa product builds.) | Pitches read cleaner in light; every recruiter/investor context is light by default. |
| **N7** | **SERVER-SIDE SECRETS ONLY** if the deck uses an LLM. Key in container `.env` (chmod 600); never `NEXT_PUBLIC_`; mandatory deterministic fallback so the live demo NEVER fails on API failure. | Per `/oneshot-webapp` hard lessons (Selaras). |
| **N8** | **HONEST INTERNAL SELF-VALIDATION.** At each self-check point (stories, narrative, wow-prototype), validate against CONCRETE criteria in this skill, not vibes, not "this looks great". The self-check is the only safeguard before the final gate. Confabulating "it's fine" is the failure mode that sank the Selaras demo. | No mid-build human to catch a drift. Honest self-check is the only guard. |
| **N9** | **PIN VIA CSS `position: sticky`, NEVER GSAP `pin: true`.** Every pinned / scroll-scrubbed section pins with CSS `position:sticky` (`top:0` + a tall outer wrapper) + an opaque full-viewport background; ScrollTrigger drives the SCRUB only. FLICK-test every pinned boundary INTO and OUT OF, both directions. `anticipatePin` is NOT a fix. | GSAP `pin:true` swaps to `position:fixed` ~1 frame late on flick scroll → a neighbour sliver flashes. Paid for with **3 fix rounds** on pulse-warmcraft (2026-06-22). artifex §7 **C4**; memory `reference_scrollytelling_pin_css_sticky`. |
| **N10** | **LANGUAGE IS A LOCKED STAGE-1 INPUT, NEVER SILENTLY DEFAULTED.** Indonesian client/investor audience → `id` default; international investor/recruiter → `en`; bilingual only if asked. Ask it, or record the chosen default + rationale in `product-analysis.md`. | The 2026-05-24 Pulse-landing rejection was compounded by English-only output for an Indonesian-market spec; all 3 live Pulse decks shipped in Bahasa. memory `project_pulse_deck_archetypes`. |
| **N11** | **HOUSE TYPOGRAPHY FLOORS + NO-MONO + NO-DASH APPLY TO EVERY DECK.** NEVER render text below `font-weight: 500` or below `12px` (both endpoints of any variable-font `wght` animation included). NEVER use a mono face outside frontend-design **DD-1**'s three carve-outs (Terminal archetype / literal code surface / literal hash-address motif). NEVER emit em/en dashes in deck copy. Pre-ship, run the artifex §15 part-2 binary scans (dash · weight · size · banned-fonts · shader-presets), **all must output NOTHING.** | Christopher's hard taste floors: `feedback_ui_typography_floors`, `feedback_no_monospace_unless_archetype`, `feedback_no_long_hyphens`. Scans cited to artifex §15 (single source; summaries rot). |
| **N12** | **DEMO-VIDEO PRODUCTION ROUTES TO THE lumiere PLUGIN ONLY.** The optional post-gate launch/demo video is produced via the lumiere **PLUGIN** flow (`/lumiere create`), NEVER the deprecated local `~/.claude/skills/lumiere`. | Program decision 2026-07-03: the plugin owns video creation; the local skill lane is cancelled. Gotchas: memory `reference_demo_video_pipeline`. |

---

═══════════════════════════════════════════════════════════════════════════
## THE PIPELINE
═══════════════════════════════════════════════════════════════════════════

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                             /pitch-deck PIPELINE                               │
├──────────┬──────────┬──────────┬──────────┬──────────┬────────────────────────┤
│ STAGE 1  │ STAGE 2  │ STAGE 3  │ STAGE 4  │ STAGE 5  │ STAGE 6               │
│ INTAKE   │ ANALYZE  │ STORIES  │ EXPLORE  │ NARRATIVE│ BUILD                 │
│ Audience │ Product  │ Exhaust. │ Dossier- │ Arc +    │ /artifex variance     │
│ + ASK    │ deep-    │ → Hero   │ first    │ outline  │ → WOW gate (1h ping)  │
│ + LANG   │ dive     │ flows    │ capture  │ (table)  │ → full cinematic build│
│ + assets │ (dossier)│ (seeded) │ + metrics│          │ → deploy              │
└──────────┴──────────┴────┬─────┴─────┬────┴─────┬────┴───────────┬────────────┘
                            ↓           ↓           ↓               ↓
                       [self-val]  [self-val]  [self-val]      [self-val + 1h ping]
                       hero flows  expl.report narrative      merged WOW gate
                       vs criteria  vs flows    vs audience   vs artifex audit
                            │
                            └────────────────────────────────────────── ──────►
                                                                      FINAL GATE
                                                                 Toper reviews
                                                                 → approve OR
                                                                   iterate
```

### Gate summary

| Gate | When | Who | What happens on miss |
|---|---|---|---|
| **Internal self-checks (×4)** | After stories / exploration / narrative / wow-prototype | Agent (autonomous) | Agent revises and re-checks before proceeding |
| **WOW direction ping** (time-boxed, NOT a block) | At the Stage-6 WOW prototype | Toper via main/attn | Send 2 screenshots; **1h default-proceed** on an honest 5/5 self-score; log the default, re-surface it at the final gate |
| **FINAL GATE (the only full human gate)** | After the full deck is live | Toper | Review → approve (done) OR iterate (refine existing deck, NOT rebuild) |

**Single-final-gate contract (preserved):** the ONLY blocking human gate is the final one. The WOW ping is time-boxed (1h default-proceed) so the pipeline never stalls waiting on a reply, it satisfies artifex's WOW-direction-confirmation intent without breaking pitch-deck's autonomous-mid-build design. Do NOT add other blocking mid-build human gates.

**Iteration rule:** a miss at the final gate is always a refinement, never a from-scratch redo. The deck exists, change the section, the CTA, the design direction, the copy. The intake should have made a full rebuild unnecessary.

---

## Stage 1: INTAKE / audience framing (THE linchpin)

**This stage is the single most important stage. With no mid-build full human gate, the intake is the only chance to catch a wrong direction. Do it rigorously.**

### Intake completeness gate v2: 7 LOCKED inputs (BLOCKING before Stage 2)

Emit these as the header table of `product-analysis.md`. Any row unresolved = STOP or record an explicit default + rationale.

| # | Locked input | Options / rule | If missing |
|---|---|---|---|
| **1** | **Audience** ← *THE most critical (N1)* | ONE of `investor` / `client-customer` / `recruiter` | **STOP. Ask.** Never infer. |
| **2** | **ASK** | ONE action: "invest $500k seed" / "book a demo" / "hire me" | **STOP. Ask.** Without it the CTA + emotional arc are undefined. |
| **3** | **LANGUAGE (N10)** | `id` / `en` / `bilingual`, keyed to audience+market: Indonesian client/investor → `id`; international → `en` | **Ask, or record the default + rationale.** NEVER silent. |
| **4** | **Product access, TESTED** | Live URL + test account, OR repo link, OR written brief, and CONFIRM it loads / creds work / repo readable | **Ask which one** the user can provide; test it before Stage 4. |
| **5** | **Brand kit / palette** | Logo, colors, fonts, voice, OR a derived-palette fallback | If absent → derive palette from live site (Stage 2). **Record the fallback.** |
| **6** | **Real metrics / traction** | Real numbers only, revenue, users, NPS, speed benchmarks | If none → honest early-stage framing (N4). **Record the framing note.** |
| **7** | **Deploy constraint** | Target domain + deadline (language is row 3, not here) | Default: `<slug>.topengdev.com`, no deadline. **Note any override.** A time-promised deadline needs `CronCreate`/`ScheduleWakeup` (house rule). |

**Blocking assertions before Stage 2:**
- [ ] Audience is ONE of `investor` / `client` / `recruiter` (no ambiguity)
- [ ] ASK is one clear action (not "general awareness" or "show it to people")
- [ ] LANGUAGE is explicitly set (never silently English)
- [ ] Product access method is confirmed AND tested (URL loads, test account works, or repo readable)
- [ ] Every unknown input has a sensible default applied + recorded in `product-analysis.md`

### Audience → pitch strategy map

| Audience | Core emotion to trigger | Story spine | Key metric | CTA |
|---|---|---|---|---|
| **Investor** | "This is the right bet at the right time" | Market pain → wedge → traction → team → ask | ARR / growth rate / TAM | Schedule a call / Deck PDF |
| **Client / customer** | "This solves MY exact problem" | Pain → "what if" → product live-demo → ROI proof | Time saved / cost saved / outcome | Book a demo / Start free trial |
| **Recruiter** | "I want to work with this person / team" | Challenge → how I built this → live proof → what's next | Scale / stack depth / impact | View my work / Contact me |

> **Routing check (do this at intake, see the BOUNDARY table at the end):** a recruiter/client **one-shot demo** request (e.g. a Laurel/Bithour build, `reference_laurel_bithour_recruiter`) is `/oneshot-webapp` on frontend-design SAFE presets, NOT a pitch-deck-hosted artifex build. Pitch-deck is for a scrollytelling PITCH of an existing product to a named audience.

---

## Stage 2: PRODUCT ANALYSIS (dossier-first)

**Produce a structured product analysis doc. Not prose, a table-first breakdown. FIRST check for an /atlas dossier, pitch-deck is a named first-class dossier consumer; do not redo hours of live crawl when a fresh one exists.**

### Dossier-first protocol (do this BEFORE any live exploration)

1. **Check** `~/.claude/skills/atlas/dossiers/<slug>/` (a `pulse` dossier already exists here). No dossier → proceed to a normal live Stage 4; optionally seed `/atlas` first for future reuse.
2. **If present, run the freshness verdict**, atlas §11.2, or `~/.claude/skills/atlas/scripts/atlas-freshness.sh <dossier-dir>` → `fresh | aging | stale`. **Quote the verdict** in `exploration-report.md` (Stage 4).
3. **Seed the story matrix** from the dossier signals: `signals.wow_potential` + `visual_richness` (both `rating_0_5`) pre-rank which real screens impress and which flow demos best (atlas §10.3 / §16 consumer table). Record the seeding in Stage 3.

### Dossier decision table

| Freshness | Screenshots | Live re-capture (Stage 4) |
|---|---|---|
| **fresh** | reuse dossier screenshots + signals | none, build on the cached evidence |
| **aging** | reuse + targeted re-capture | re-capture ONLY the hero-flow surfaces |
| **stale** | suspect, do NOT ship as-is | full Stage-4 live capture, OR reuse only with an explicit staleness disclaimer in the evidence trail |
| **absent** | n/a | full Stage-4 live capture (optionally seed `/atlas` for future runs) |

> **HARD RULE:** NEVER ship a STALE dossier's screenshots into the deck without re-capture or an explicit disclaimer (atlas §11.2 freshness duty). A deck built on stale screens can show a UI the product no longer has.

### Output: `product-analysis.md`

| Section | Required content |
|---|---|
| Intake header table | The 7 locked inputs (Stage 1) + dossier freshness verdict |
| Problem statement | The pain (stated in the AUDIENCE's language, not the builder's) |
| Target market | Who hurts, at what scale |
| Solution + differentiation | What it does + how it differs from alternatives |
| Business model | Revenue model (required for investor; optional for others) |
| **THE WEDGE** | The ONE thing that makes this compelling. If you can't name it, stop and find it. |
| Existing assets | Landing, docs, repo, brand kit, **atlas dossier**, what's available for Stage 4/6 |
| Known gaps / honest weaknesses | Surface real weaknesses (important for N4 + honest narrative) |

**The Wedge rule:** the wedge is the narrative hinge. Everything in the deck amplifies the wedge. If there's no clear wedge, the narrative will be diffuse and unconvincing. Find it before proceeding.

---

## Stage 3: USER STORIES, exhaustive THEN prioritize (internal self-validation)

**Do NOT skip the exhaustive step to jump to "the 3 best features." The exhaustive list is how you find the REAL hero flows.**

### Step 3a: Enumerate EVERY user story by persona

```
Persona 1 → Story A, Story B, Story C, ...
Persona 2 → Story D, Story E, ...
```

Example (POS system):
- **Cashier:** ring up sale, apply discount, split payment, void item, print receipt, check shift total
- **Manager:** view daily report, adjust pricing, void transaction, add staff
- **Owner:** real-time revenue, compare branches, export to accounting, monthly goals

### Step 3b: Score + produce the User-Story Matrix

**Output: a matrix table (NOT prose)**

| Story | Persona | Pitch value (1-5) | Demo-ability (1-5) | Includes wedge? | Hero candidate? |
|---|---|---|---|---|---|
| Real-time revenue dashboard | Owner | 5 | 5 | Yes | ★ |
| Ring up + split payment | Cashier | 4 | 5 | No (table stakes) | ★ |
| Void + audit trail | Manager | 3 | 3 | Partially | |
| ... | ... | ... | ... | ... | |

> **Signal-seeding (when a dossier exists):** seed the initial Pitch-value and Demo-ability scores from the dossier's `signals.wow_potential.rating_0_5` and `visual_richness.rating_0_5` for each surface, then adjust from your own judgement. **Record that you seeded from the dossier** (which surfaces, what scores) so the provenance is auditable. No dossier → score from scratch.

### Internal self-check: hero flow selection (before Stage 4)

**Do this check autonomously. Do not wait for human input.**

| Criterion | Check |
|---|---|
| Pitch value ≥ 4 AND demo-ability ≥ 4 | All proposed hero flows must pass |
| Wedge is included | At least one hero flow directly demonstrates the wedge |
| End-to-end in ≤ 90 seconds of scrolling | No hero flow requires more than ~6-8 screenshots to tell |
| Count: 3-5 hero flows | 3 is ideal for investor/recruiter, 4-5 for client |
| All are REAL and VERIFIABLE | Cross-check: can you actually demo each one in Stage 4 (or is it captured in the dossier)? |

If any hero flow fails this check → revise selection before Stage 4.

---

## Stage 4: REALTIME EXPLORATION + CAPTURE

**Navigate and ACTUALLY USE the product following each hero flow. This is the evidence-gathering stage.** If a fresh/aging dossier covers a flow, reuse its screenshots (decision table, Stage 2) and re-capture ONLY what is missing or stale, do not blindly recrawl.

### Browser mechanics: DEFER to the /agent-browser skill (do not improvise CDP)

ALL browser driving obeys the `/agent-browser` skill. The load-bearing facts (cite, do not re-derive):

| Fact | Rule (agent-browser anchor) |
|---|---|
| **Never Playwright MCP** | Hook-banned. Pivot to agent-browser immediately (**HR-1**). |
| **Never restart / kill qutebrowser** | It is Christopher's LIVE browser (**HR-2**). Never `:restart`, never a fresh Chrome. |
| **Open a page** | `/claim?url=<url>` then connect (**R-1**, the canonical recipe). **NEVER `agent-browser tab new`**, field-broken, exit 144 in this env (**HR-9**). |
| **Parallel explorers** | Each worker claims its OWN port with `/claim?from=9223` + a UNIQUE `AGENT_BROWSER_SESSION` (**HR-7**); connect within the 30s claim TTL (**HR-8**). Never share port 9222 (interactive active-tab port). |
| **Blank / black screenshot** on a heavy page (backdrop-filter, giant bg images) | qb-shoot fallback ladder (**PB-4** / §9.3); `~/.config/qutebrowser/scripts/qb-shoot <url-slug> <out.png>`. It switches the live tab, so the agent-browser CDP path is always preferred. |
| **Oversized `--full` shot, content top-left** | HiDPI DPR defect, trim per **PB-5** (`convert in.png -bordercolor white -border 1 -trim +repage out.png`). Never blanket-trim. |
| **Teardown is mandatory** | `agent-browser close` then `curl -s "http://localhost:9222/release?port=$PORT"` (**HR-6** / §12). Release every claimed port. |
| **Never screenshot a credential/token page** into deck evidence | Report `credential at <file>, pattern <type>` only, never the value (mirrors **HR-15**). |

### Stage-4 parallel fan-out PREFLIGHT (BLOCKING before parallel capture)

Before spawning one browser worker per hero flow, run the atlas §12.1 multi-port preflight:

```bash
ss -ltn | grep -cE '127\.0\.0\.1:92(2[3-9]|3[0-6])'   # count of claimable multi-port listeners
```

- **≥ 2** → multi-port proxy LIVE → the parallel fan-out is allowed (each worker claims its own port).
- **< 2** → single-port (or down) → **serialize browser I/O** (one worker at a time through the browser; reasoning/merge can stay concurrent). A parallel fan-out against a single-port proxy collides on one daemon + one pinned tab and CORRUPTS captures.

### Capture-path conventions (deck assets must SURVIVE into the repo)

| Asset | Where | Why |
|---|---|---|
| Raw captures | `<repo>/captures/` (gitignored) | Survives reboot; auditable at the final gate; the live Pulse deck repos use exactly this |
| Processed images | `public/` as WebP/AVIF | The deck ships these; `/tmp` does NOT survive |
| Evidence trail | reference repo-relative paths in `exploration-report.md`; copy key shots into the task notes dir for the STATE.md trail | So the final-gate real-vs-framed table is verifiable |

> **Do NOT leave deck evidence in `/tmp`**, it vanishes before the final gate or an iteration round.

### Per hero-flow capture checklist

| What to capture | Format | Purpose in deck |
|---|---|---|
| Entry state (before) | Screenshot | "Before" in the narrative |
| Key interaction | Screenshot(s) | The "how" |
| The WOW moment | Screenshot + exact metric (time/number/result) | The proof point |
| Result state (after) | Screenshot | The payoff |
| Gaps or bugs found | Note | Honest framing (N4) + product feedback |

### Output: `exploration-report.md` (tables, not prose)

```
## Hero Flow: [Name]
Dossier freshness: fresh|aging|stale|absent (atlas §11.2)
| Step | Screenshot path | Observation | Deck-worthy? |
|---|---|---|---|
| 1. Login | captures/login.png | Loads in 0.8s | Yes |
| 2. Dashboard | captures/dash.png | Real-time chart, impressive | YES, WOW |
| ... | | | |

Real metrics:
- Dashboard load: 0.8s (use this)
- ...

Gaps/honest notes:
- Mobile: slightly cramped on iPhone 13 (acknowledge in narrative if investor)
```

### Internal self-check: exploration quality (before Stage 5)

| Criterion | Check |
|---|---|
| Every approved hero flow has a complete screenshot trail | No flow missing the WOW moment |
| At least one REAL metric captured per flow | Specific number, not "it's fast" |
| No invented observations | Only what was ACTUALLY seen in the product (or a fresh dossier) |
| The wedge is captured visually | Deck can SHOW the wedge, not just tell |
| Dossier freshness verdict recorded | Any reused screenshot from an aging/stale dossier is flagged |
| All gaps/bugs honestly noted | N4, no glossing over real limitations |

**If a hero flow failed in exploration** (feature broken, login failed, access blocked): note it honestly. Either swap to an alternate flow from the Stage 3 matrix, OR note the limitation and plan for honest framing in the narrative. **NEVER fabricate the capture.**

**Multi-agent note:** Stage 4 maps to a parallel `fan-out-review`, one agent-browser worker per hero flow, each on its OWN claimed port, synthesized into the exploration report. Gate it on the §12.1 preflight above and see the Multi-Agent section (OOM + preflight rules) before spawning.

---

## Stage 5: NARRATIVE ARC (internal self-validation)

**The narrative is the deck's spine. Select the arc for the named audience. Write it in the LOCKED language (N10).**

### Audience-specific narrative templates

**INVESTOR:**
```
[HOOK]      The painful truth about [market], a stat or story that lands hard
[PROBLEM]   The specific gap (scale: $Xbn market, Y% without a real solution)
[SOLUTION]  The wedge: what was built, why now, why this team
[LIVE DEMO] 2-3 hero flows, shown in action (screenshot trail)
[TRACTION]  Real numbers, ARR / users / growth rate / notable customers
[MARKET]    TAM/SAM/SOM or the category being created
[TEAM]      Why this team (unfair advantages, relevant experience)
[THE ASK]   Exactly what's being raised, what it funds, round terms
[CTA]       One action: "Schedule a call"
```

**CLIENT / CUSTOMER:**
```
[HOOK]      "You've probably been dealing with [pain]. Here's why that persists."
[PROBLEM]   Their daily friction, made vivid (the before-state)
[PRODUCT]   The solution, live-demo'd with their specific use case
[PROOF]     Real outcomes: X hours saved, Y% cost cut, Z users love it
[HOW]       3-step simplicity (not a feature list)
[SOCIAL PROOF] Honest testimonials or early case study (only if real, N4)
[CTA]       One action: "Book a demo" / "Start free"
```

**RECRUITER:**
```
[HOOK]      The challenge that shaped this work
[PROBLEM]   What I was solving and why it was hard
[BUILD]     How I built it, decisions, stack, key choices (show the thinking)
[PROOF]     The result, working, in real numbers
[NEXT]      Where I'm heading / what I want to build
[CTA]       "View my work" / "Let's talk"
```

### Output: `narrative-outline.md` (table format)

| Scroll section | Section name | Key message (≤ 15 words) | Visual anchor | Evidence source |
|---|---|---|---|---|
| 1 | Hook | "Most POS systems fail at the moment that matters most" | Full-bleed type | n/a |
| 2 | Problem | "Lost $Xbn to downtime last year" | Animated counter | Real stat or honest estimate |
| 3 | Solution | "Pulse works offline, your sales never stop" | Split before/after | Screenshots from Stage 4 |
| 4 | Demo flow 1 | "See it handle a split payment in 8 seconds" | Scroll-synced trail | Captured flow 1 |
| 5 | Traction | "500 merchants, ↑240% in 3 months" | Counter animation | Real metrics |
| 6 | CTA | "Schedule a call" | High-contrast, clean | n/a |

> **Optional copy round-trip (recommended for investor/client decks):** hand the hook + section headlines + CTA through **`/copywriting`** (quick-audit mode), its §10 copy-spec handoff already targets on-deck copy and enforces the same anti-slop + no-dash discipline. Feed the tightened copy back into the outline before Stage 6.

### Internal self-check: narrative quality (before Stage 6)

| Criterion | Check |
|---|---|
| Story matches the named audience template exactly | No investor narrative for a client deck |
| Written in the LOCKED language (N10) | No English outline for an `id`-locked deck |
| Every "evidence source" column points to REAL Stage 4 / dossier capture | No "TBD" or invented stats |
| The wedge appears in ≥ 2 sections | Hook + solution minimum |
| One CTA, not multiple | Decision fatigue kills conversions |
| Key message for each section ≤ 15 words | If longer, cut; if it can't be condensed, the section is unclear |
| No fabricated metrics in the "Evidence source" column | N4, if thin, honest early-stage framing |

---

## Stage 6: BUILD, Cinematic Scrollytelling Website

**This stage has an internal self-validation loop: build the WOW prototype first, run the MERGED WOW gate, then continue to full build. The direction ping is time-boxed (1h default-proceed); the self-check must be HONEST (N8).**

### Stack recommendation (opinionated defaults: aligned with the artifex §14 stack)

| Decision | Default | Alternative | When to switch |
|---|---|---|---|
| **Framework** | **Next.js 15 App Router** | Astro | Astro if fully static, no server features needed |
| **Scroll engine** | **GSAP + ScrollTrigger for SCRUB ONLY** | Framer Motion | Framer if already in Next.js stack + simpler scenes |
| **Pinning** | **CSS `position: sticky`** (top:0 + tall wrapper + opaque full-viewport bg) | n/a | **NEVER GSAP `pin:true`** (N9 / artifex §7 C4), no alternative, this is the law |
| **Smooth scroll** | **Lenis** (compositor-friendly, silky; pair with `useOnScreen`) | None | Skip if perf testing shows jank on low-end devices |
| **Animation layer** | GSAP timeline + Framer Motion + CSS transitions | Motion Primitives | Motion Primitives for React-native component animations |
| **Shader-class visuals** | **Paper Shaders** (`@paper-design/shaders-react`, pin exact `0.0.76`) | hand-rolled GLSL / r3f | Custom ONLY via an artifex §5.1 carve-out (real 3D geometry, cursor-reactive physics, scrubbed scene state). MUST-USE first reach for ambient fields / hero textures / shader backgrounds (**artifex N10 / §5.1**). One mounted canvas max. |
| **Styling** | Tailwind (check v3 vs v4 first) + CSS custom properties | CSS Modules | CSS Modules for complex multi-state animations |
| **Component base** | Origin UI (neutral base) + bespoke WOW sections | shadcn/ui | Either, compatible |
| **Deploy** | `<slug>.topengdev.com` via `/oneshot-webapp` `deploy.sh` | Product subdomain | Product subdomain if going live to real users |

**Stack lock-in rule:** choose ONE scroll engine and stick. Mixing creates conflicting animation lifecycles and performance bugs. Pin GSAP versions via **npm** (do NOT load GSAP from a CDN, GSAP incl. all plugins is fully free on npm post-Webflow; a CDN adds a third-party origin to a perf-gated page and defeats version pinning; artifex §14).

### Design direction

Use `/frontend-design` to set the archetype, it becomes `/artifex`'s BASE palette (type/color/mood held constant across the page). Pitch decks map to these safe presets:

| Pitch type | Recommended archetype | Feel |
|---|---|---|
| Investor / seed round | **Editorial Luxury** or **Soft Structuralism** | Premium, confident, restrained |
| SaaS / client demo | **Soft Structuralism** or **Warm Craft** | Trustworthy, approachable, modern |
| Tech / dev tool | **Japanese Minimal** or **Swiss / International Typographic** | Precise, credible, no fluff |
| Recruiter / portfolio | **Editorial Luxury** | Taste, craft, personality |

**Anti-generic discipline (HARD, mirrors `/oneshot-webapp`):**

| BANNED | WHY | INSTEAD |
|---|---|---|
| Centered hero → 3 feature cards → CTA banner → footer | The AI-slop signature | Scroll-pinned hook with progressive reveal, offset sections, layout shifts that surprise |
| Purple/blue gradient hero overlays, aurora/glow-blobs | Over-used to the point of invisibility (artifex HB-1) | Brand palette + THE WEDGE as the visual anchor; a Paper Shaders field ONLY under the §5.1 anti-slop clauses (locked palette, structured, never pastel haze) |
| Lottie animations for motion's sake | Motion without narrative purpose = gimmick | Scroll-triggered reveals tied to the story beat |
| Feature-list sections (✓ item, ✓ item) | Nobody reads them | Hero FLOWS shown live in context |
| Stock photo heroes, AI-generated photo backgrounds | Signals "not a real product" (artifex HB-4) | Real screenshots from Stage 4 / the dossier. `/creative` + `/zografee` are for illustration / key-visual assets, never photo-real backgrounds |
| Plain Inter/Roboto as display face | Default = generic | Distinctive pairing from `/frontend-design` §3 (Font Pairing Strategy) |

### Section architecture: invoke /artifex (variance-first). Do NOT lay sections from a fixed template.

**A fixed section template is exactly what produced the twice-rejected *"MONOTONE / basic"* verdict** (every section the same skeleton; ONE technique, scrollytelling, repeated ×9). Drive the build with **`/artifex`**, `/frontend-design`'s variance-first counterpart, which exists specifically to kill that failure. There is NO fixed section skeleton in this skill; the variance IS the design.

1. Take the archetype chosen in **Design direction** (above) as `/artifex`'s BASE palette, type / color / mood stay coherent across the page.
2. Feed the **approved Stage-5 narrative beats** into `/artifex`'s **Variance Method (§6)**, assign each beat a DISTINCT skeleton + a DISTINCT signature technique + a designed transition out. (The worked 9-beat Pulse map, the 25-technique B/H/E library, Paper Shaders N10/§5.1, and the hero playbook all live there.)

#### The artifex handshake (write this on pitch-deck's side)

Stage 6 is a hosted `/artifex` invocation. On pitch-deck's side, before building:

- **Write the artifex §7 audit header FIRST, exactly these two lines** (a hosted pitch-deck invocation is the N0 override by definition):
  ```
  Surface:  pitch-deck (hosted by /pitch-deck Stage 6)
  Override: hosted /pitch-deck invocation (an override by definition, N0)
  ```
- **Clear the artifex Variance & Quality Audit (§7) IN FULL**, the binary Anti-Slop Hard-Bans (HB-1..HB-6) + the scored checks A-O (O records `n/a` for a hosted spine-less scroll page). Emit the filled audit block as the FIRST build artifact. **PASS or you do not build.** Do NOT paraphrase the audit into a numeric summary here, the exact metrics live in artifex §7 and drift if copied (e.g. scrollytelling is counted per DISTINCT technique, not a flat cap). Clear it there, in full.

This replaces the old fixed section template, `/artifex` is what makes "9 different sections" mechanical instead of aspirational.

### The MERGED WOW gate (single execution: pitch-deck ⋃ artifex, run ONCE)

**Build the HOOK section + one DEMO FLOW section first. Nothing else** (≤ 20% of the build budget). Then run ONE gate: pitch-deck's 7 criteria UNION artifex's W1-W5 mini-rubric. This is the SAME gate as artifex §15 step 5, run it once with the union of both criteria sets (artifex §13). Every criterion passes, or the DIRECTION is fixed before any further section is built.

**pitch-deck's 7 WOW criteria (honest self-check, N8):**

| # | Criterion | Pass condition | FAIL action |
|---|---|---|---|
| 1 | Scroll-trigger feels cinematic | Smooth scrub, correct easing, no jank | Fix the scroll behavior, re-test |
| 2 | Typography has personality + holds the floors | Display face NOT Inter/Roboto/Arial; **weight ≥ 500, size ≥ 12px, no mono outside DD-1** (N11) | Change the display face; fix any floor/mono violation |
| 3 | Archetype is correct | Reads as the chosen archetype, NOT generic | Revisit color + type + layout |
| 4 | Hero message clear in ≤ 3s | First scroll position delivers the hook | Simplify or reword |
| 5 | Performance is fast | No layout shift, no loading jank on first view | Lazy-load, remove heavy pre-loads |
| 6 | Does NOT look AI-generated | No purple gradients / aurora, no generic 3-card grid, no lorem ipsum | Apply anti-generic discipline |
| 7 | Narrative fidelity | Section tells the correct beat from `narrative-outline.md` | Revise if drifted from the approved arc |

**artifex W1-W5 (all binary, all must pass, artifex §15):** W1 frame-one richness (check K) · W2 architectural type (check H) · W3 zero hard-ban tells (HB-1..HB-6) · W4 motif seeded (N6) · W5 distinctiveness ("could a generic template have produced this frame?" must be NO).

**Evidence + direction ping (the merge that resolves the artifex BLOCKING escalation):**

1. Capture **2 screenshots from the RUNNING prototype**: 1440×900 (desktop) + 390×844 (mobile), via the agent-browser flow (claim your OWN tab; never Christopher's).
2. **Send both screenshots to Toper via main/attn** as a DIRECTION ping (catch drift at minute 20, not hour 2).
3. **1h default-proceed:** if no reply in 1h, proceed on an honest 5/5 (pitch-deck) + 5/5 (artifex) self-score. **Log the default** in STATE.md and **re-surface it at the final gate** ("proceeded on the 1h WOW default; here are the two prototype screenshots").
4. **If ANY criterion fails → fix the DIRECTION** (archetype / palette / hero treatment), NOT the map on paper, then re-prototype. Do NOT "push through" a failed WOW prototype or a failed Variance Audit, that is the named Selaras / Gruvbox / pulse-landing pattern.

This preserves the single-final-human-gate contract: the ping is time-boxed, so the pipeline stays autonomous, while artifex's WOW-direction-confirmation intent is honored via the house 1h-decision-deadline pattern.

### Performance audit (pre-ship, mandatory)

| Metric | Hard threshold | How to check |
|---|---|---|
| Time to Interactive | ≤ 3s on 4G | Lighthouse (named runner below) |
| LCP | ≤ 1.2s | Lighthouse |
| CLS | ≤ 0.1 | Lighthouse |
| JS bundle | ≤ 300KB compressed | `next build` analyzer |
| Images | WebP or AVIF, lazy-loaded | Build output grep |

**Named Lighthouse runner (the CLI is NOT pre-installed on this box; `google-chrome-stable` + `npx`/node are):**

```bash
npx --yes lighthouse "https://<slug>.topengdev.com" \
  --only-categories=performance --chrome-flags='--headless=new' \
  --quiet --output=json --output-path=./lighthouse.json
# confirm exact flags with:  npx --yes lighthouse --help   (CLI not pre-installed here)
# THEN kill any leaked headless chrome:  pkill -f 'chrome.*--headless' || true
```

- **Lighthouse score < 85 → DO NOT SHIP.** Fix performance first. Triage order: (1) image weight → WebP/AVIF + responsive `sizes`; (2) route-critical JS → the heavy scene loads via `next/dynamic ssr:false`, never in the first-paint chunk; (3) lazy-load below-fold (artifex §9).
- **Kill leaked chrome after every run**, leaked headless chromes caused a RAM/swap thrash crisis (`reference_demo_video_pipeline` §5).
- **Host precedence:** these numbers are pitch-deck's, and artifex §9 declares that when pitch-deck hosts, THIS table WINS over artifex's tiers. Keep the numbers stable.

### Pre-ship mechanical block (ALL must be green before shipping)

- [ ] **artifex §15 part-2 binary scans**, dash · weight (≥ 500) · size (≥ 12px) · banned-fonts · shader-presets, every scan outputs **NOTHING** (N11; exact commands in artifex §15, single source)
- [ ] **Flick-test log per pinned section**, flick INTO and OUT OF every pinned boundary, both directions; assert zero neighbour-sliver (N9 / artifex §15 part 3)
- [ ] **Lighthouse** meets the perf table via the named runner; leaked chrome killed
- [ ] **Zero fabricated metrics**, cross-check every on-deck number against `exploration-report.md` (N4)
- [ ] **One CTA** count; no stacked asks
- [ ] **Live URL** returns HTTP/2 200, correct title, stale-title cleared
- [ ] **artifex audit still holds AS BUILT**, no skeleton/technique/hard-ban drift crept in during build

### Deploy: defer to /oneshot-webapp deploy.sh (the deploy sequence source of truth)

`~/.claude/skills/oneshot-webapp/deploy.sh` owns the exact sequence. Verified deploy facts:
- `<slug>.topengdev.com` → per-subdomain Cloudflare A record (no wildcard) → nginx vhost → certbot HTTPS
- `~/apps/<slug>/.env` chmod 600 for any secrets (N7)
- **VPS has NO `rsync`** → the script uses a tar-over-ssh fallback; 33xx loopback port convention
- **Do NOT disrupt protected VPS services:** hiremeup, signal-trader, wa-sender, the aenoxa stack, bithour, sinarsurya, wiraduta
- VPS access: `sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$VPS_USER@$VPS_HOST"`
- Verify: `curl -I https://<slug>.topengdev.com` → HTTP/2 200; eyeball the live site; confirm stale-title cleared

---

## FINAL HUMAN GATE (the only full one)

**After the full scrollytelling site is live at `https://<slug>.topengdev.com`:**

Present to Toper:
1. **Live URL**, the full deck, live
2. **Lighthouse score**, perf confirmation (from the named runner)
3. **Evidence trail**, which screenshots came from Stage 4 real capture / the dossier (+ freshness), which metrics are real vs framed
4. **Any honest gaps**, what the deck doesn't cover (features not shown, traction thin, etc.)
5. **WOW-ping default (if it fired)**, "proceeded on the 1h WOW default; here are the two prototype screenshots", so Toper can retro-veto the direction cheaply
6. **Iteration handle**, "If X section doesn't land, here's what we'd change and why it's cheap to fix"

**Response paths:**

| Toper response | What to do |
|---|---|
| "Approved" / "looks great" | Done. Close the loop: `report.md` + `result.json`. |
| "Change section X" | Revise ONLY that section. Re-deploy. No rebuild. |
| "The narrative is wrong" | Revisit `narrative-outline.md` → revise the affected sections. Still no full rebuild. |
| "Wrong audience / tone" | This is an intake miss. Revisit Stage 1 with clarified audience, then Stage 5+6 only. |
| "Wrong language" | Intake miss on N10. Fix the Stage-1 language row → re-run Stage 5 (outline) + Stage 6 (copy) only. No capture/analysis redo. |

**The final gate is ITERATE, not rebuild.** If an iteration is needed, it targets the specific miss. The build artifact stays.

---

## CRAFT GUARDRAILS

```
┌──────────────────────────────────────────────────────────────────────┐
│                        THE CRAFT PRINCIPLES                          │
├──────────────────────────────────────────────────────────────────────┤
│ 1. IMPACT > EFFECTS       Every visual element serves the narrative.│
│                            Cut effects that don't pull weight.       │
│ 2. SCROLL = STORY         Each pinned section = one story beat.     │
│                            A section that doesn't advance the story  │
│                            gets cut or merged.                       │
│ 3. WOW BEFORE BULK        Build prototype first, run the merged     │
│                            WOW gate, THEN full build.                │
│ 4. PERFORMANCE = RESPECT  Slow = disrespect for the viewer's time.  │
│ 5. INTEGRITY (N4)         Real numbers, honest framing. Always.     │
│ 6. ONE CLEAR ASK          One CTA. Decision fatigue kills it.       │
│ 7. REAL SCREENSHOTS       Stage 4 / dossier capture only.           │
│                            Stock / AI-photo = fake = dead.           │
│ 8. HONEST SELF-CHECKS     Validate against criteria, not vibes.     │
│                            "Looks great" is not a pass condition.    │
│ 9. VARIANCE, NOT GLOSS    9 different sections, not one repeated.   │
│                            The /artifex audit makes it mechanical.   │
└──────────────────────────────────────────────────────────────────────┘
```

### Failure-mode playbook (symptom → root cause → fix → verify)

| Symptom | Root cause | Fix | Verify |
|---|---|---|---|
| **Pin-blink**, ~100-150px neighbour sliver flashes at a pinned boundary on fast/flick scroll (slow scroll hides it) | GSAP `pin:true` swaps to `position:fixed` 1 frame late; `anticipatePin` is NOT a fix | CSS `position:sticky` (top:0 + tall wrapper), ScrollTrigger scrub ONLY, opaque full-viewport bg (N9 / artifex §7 C4) | Scripted flick IN + OUT, both directions (artifex §15 part 3) |
| **Deck reads MONOTONE** | Fixed-template thinking (one skeleton / one technique repeated) | Feed the beats through artifex §6 Variance Method + clear §7 IN FULL | Audit block A = B = 1.00, then as-built re-check |
| **Blank / black screenshot** | CDP render path chokes on a heavy page | qb-shoot fallback ladder (agent-browser §9.3 / PB-4) | Re-shot passes the agent-browser QA gate |
| **Oversized `--full` shot, content top-left** | HiDPI DPR defect | ImageMagick trim (agent-browser PB-5), never blanket-trim | Re-shot is correctly sized |
| **Worker OOM-killed mid-build** | 2+ heavy Opus workers, or the build fleet stacked on a live browser fleet (14Gi box) | Serialize heavy builds; `free -h` before each spawn; killed workers resume from STATE.md checkpoints (`reference_local_box_oom_heavy_workers`) | `free -h` stays healthy; worker resumes from last stage deliverable |
| **Hero flow broken during exploration** | Product bug / access issue | Swap an alternate flow from the Stage-3 matrix, OR an honest-framing note, **never fake the capture** (N4) | The swapped flow captures cleanly; the note is in the evidence trail |
| **Lighthouse < 85** | Heavy images / route-critical JS | Triage: image weight → route-critical JS → lazy-load below-fold (artifex §9) | Re-run the named runner ≥ 85; kill leaked chrome |
| **Wrong language at the final gate** | Intake miss on N10 | Fix the Stage-1 language row → re-run Stage 5 + Stage 6 only | Deck renders in the locked language |

### Verified failures (learn from these)

| Failure | Root cause | Guardrail that catches it |
|---|---|---|
| Art-deco Selaras/Bithour demo rejected (2026-05-29) | Over-designed, effects without substance; high-variance one-shot with no override | N3, Impact > Effects; WOW self-check; routing (one-shot demo → /oneshot-webapp SAFE) |
| Gruvbox reskin rejected post-full-build | Full build on unvalidated design direction | The WOW prototype gate (all criteria pass BEFORE full build) |
| Pulse landing v2: wrong assumptions + English-only, 1h wasted (2026-05-24) | Wrong intake, wrong audience + language assumptions | N2, intake is the linchpin; N10, language locked at intake |
| Pulse deck rejected TWICE as "MONOTONE / basic" | One skeleton + one technique repeated ×9 (fixed template) | The entire /artifex §6 method + §7 audit (Stage 6) |
| pulse-warmcraft pin-blink, 3 fix rounds (2026-06-22) | GSAP `pin:true`; anticipatePin shipped as v2 still blinked | N9, CSS sticky pin + flick-test both directions |
| Heavy Opus workers OOM-killed the 14Gi box (2026-06-22) | 2 heavy builds + a browser fleet concurrent | Multi-agent OOM serialization rule (below) |

---

## INTERMEDIATE DELIVERABLES + STAGE-BOUNDARY CHECKPOINTS

**Each stage's deliverable doc IS its resumable checkpoint proof.** A pitch-deck run is multi-hour; a killed worker (session limit / OOM, both verified house failure modes) must NOT redo completed stages.

| Stage | Deliverable (= checkpoint proof) | Format required |
|---|---|---|
| Stage 1 | Intake locked + assumptions noted | `product-analysis.md` header table (7 inputs) |
| Stage 2 | `product-analysis.md` + dossier freshness verdict | Structured tables + Wedge callout |
| Stage 3 | `user-story-matrix.md` | Matrix table (persona × story × pitch-value × demo-ability) |
| Stage 4 | `exploration-report.md` | Table per hero flow + repo-relative screenshot paths + real metrics |
| Stage 5 | `narrative-outline.md` | Table (section × message × visual anchor × evidence source) |
| Stage 6 partial | Filled artifex audit block + WOW-gate screenshots | Audit header + HB scan + A-O scores; 2 screenshots (1440×900 + 390×844) |
| Stage 6 final | Full scrollytelling site at `https://<slug>.topengdev.com` | Live URL + Lighthouse score |

**Resume protocol (on every (re)start):** read STATE.md FIRST → `ls` the deliverable docs → skip any stage whose deliverable exists AND passes its own self-check → restart at the first missing deliverable. Mark a stage `[x]` only after its deliverable is written + re-read. The Stage-6 deploy is the one non-idempotent step, guard it (check the live URL before re-deploying).

**All docs MUST be visual-first (tables, matrices, ASCII diagrams), not prose walls.** Christopher reads structured visuals 10× faster than paragraphs (`feedback_visual_structured_docs`).

---

## MULTI-AGENT ORCHESTRATION

This pipeline maps to the workflow library (`~/.claude/scripts/workflows/`) for thorough runs:

```
Stage 4 (Explore) → fan-out-review:
   one agent-browser worker per hero flow, each on its OWN claimed port
   → each outputs a per-flow exploration table
   → synthesize into exploration-report.md

Stage 6 (Build) → recon→implement→verify:
   recon worker   → builds WOW prototype, 2 screenshots, merged WOW gate
   implement worker → full build (all sections)
   verify worker  → Lighthouse audit + flick-tests + live URL smoke test
```

| Run mode | When to use | Approach |
|---|---|---|
| Fast (single worker) | Tight deadline, clear brief, simple product | Sequential 6 stages, single session |
| Thorough (multi-worker) | Multiple hero flows, complex product, high-stakes pitch | `fan-out-review` for Stage 4, `recon→implement→verify` for Stage 6 |

### Fleet safety (HARD: the 14Gi box OOM-kills on stacked heavy work)

| Rule | Why |
|---|---|
| **Gate the Stage-4 parallel fan-out on the atlas §12.1 preflight** (`ss -ltn \| grep -cE '127\.0\.0\.1:92(2[3-9]\|3[0-6])'` ≥ 2) | Below 2, parallel browser workers collide on one daemon/tab and corrupt captures, serialize browser I/O instead |
| **NEVER run 2+ concurrent heavy Opus BUILD workers** | The worker-COUNT semaphore does NOT protect memory; 2 heavy builds OOM the box well under the count cap (verified 2026-06-22) |
| **NEVER stack the Stage-6 build fleet on a live Stage-4 browser fleet** | A Next build + a browser/screenshot fleet + main hit 10Gi and the kernel OOM-killed the newest heavy procs |
| **Check `free -h` before each heavy spawn** | Swap creeping toward full = back off; hold one initiative's heavy phase while another's runs |
| **Killed workers resume from STATE.md checkpoints** | Serialize-then-resume loses little (install-done → lighter on resume). See the checkpoint table above. |

**Worker model guidance:**

| Worker | Model | Reason |
|---|---|---|
| **ALL pitch-deck workers** (explore / narrative / build) | **Opus** | Toper's standing call (2026-06-20): the ENTIRE pipeline is design-judgment work, seeding realism, hero-flow selection, narrative arc, and the cinematic build all need Opus. The customer-facing design-quality carve-out covers the whole skill, not just Stage 6. Default every pitch-deck worker to Opus. **(The OOM serialization rules above sit ALONGSIDE this, Opus stays, but serialize the heavy ones.)** |

---

## BOUNDARY: NOT this skill / composes with

Route the request correctly BEFORE building (misrouting re-creates the Selaras-class mismatch).

| Request shape | Route to | Why (the boundary rationale) |
|---|---|---|
| Recruiter/client **one-shot demo** (e.g. Laurel/Bithour) | **`/oneshot-webapp`** on `/frontend-design` SAFE presets | A one-shot demo is light-only, SAFE-preset, VARIANCE < 7. A pitch-deck-hosted artifex build is VARIANCE 8-10 by definition, legitimate ONLY because hosting counts as the artifex N0 override. A one-shot demo has no such override → SAFE. (`reference_laurel_bithour_recruiter`, `feedback_frontend_design_safe_templates`) |
| A **written portfolio narrative** (README, LinkedIn, CV bullets, job app) | **`/case-study`** | That is prose from a real repo, not a scrollytelling site. |
| Christopher's OWN immersive site / "go award-caliber" on a non-pitch page | **`/artifex` directly** | Direct artifex invocation is an N0 override by definition; no pitch-deck pipeline needed. christopher-portfolio is the immersive-SPINE reference (NOT the deck default). |
| Sharpen the deck's **copy** (hook / headlines / CTA) | **`/copywriting`** round-trip | Its §10 copy-spec handoff already targets on-deck copy + enforces anti-slop/no-dash. Optional but recommended for investor/client decks. |
| **Key visuals / illustration / posters** for a section | **`/zografee`** (reference-driven) or **`/creative`** (AI illustration) | Never photo-real backgrounds (artifex HB-4); these are for illustration/key-visual assets only. |

---

## QUICK-REFERENCE CHECKLIST (print before starting)

```
STAGE 1 (Intake), lock ALL 7 before Stage 2:
  [ ] Audience: investor / client / recruiter (no ambiguity)
  [ ] ASK: one clear action
  [ ] LANGUAGE: id / en / bilingual, explicit, never silent (N10)
  [ ] Product access confirmed AND tested
  [ ] Brand kit collected OR derived-palette fallback recorded
  [ ] Real metrics OR honest-framing note recorded
  [ ] Deploy constraint noted (deadline → CronCreate/ScheduleWakeup)

STAGE 2 (Analyze), dossier-first:
  [ ] Checked ~/.claude/skills/atlas/dossiers/<slug>/
  [ ] Freshness verdict computed + quoted (atlas §11.2) if present
  [ ] Decision table applied (fresh/aging/stale/absent)

STAGE 3 (Stories), internal self-check before Stage 4:
  [ ] Exhaustive story list done (all personas × all stories)
  [ ] Scored matrix produced (seeded from dossier signals if present)
  [ ] 3-5 hero flows: all score ≥ 4/4, wedge included, ≤ 90s each
  [ ] Flows are REAL and verifiable in Stage 4 / the dossier

STAGE 4 (Explore), internal self-check before Stage 5:
  [ ] Parallel fan-out only if §12.1 preflight ≥ 2 (else serialize)
  [ ] Browser via /agent-browser (claim own port; never Playwright MCP; never tab new)
  [ ] Captures in <repo>/captures/ (gitignored), processed WebP in public/, NOT /tmp
  [ ] Every hero flow has a complete screenshot trail + ≥ 1 real metric
  [ ] Wedge captured visually; dossier reuse flagged for freshness
  [ ] Gaps/bugs honestly noted; broken flow swapped or honestly framed (never faked)
  [ ] Teardown: agent-browser close + release every claimed port

STAGE 5 (Narrative), internal self-check before Stage 6:
  [ ] Correct audience template; written in the LOCKED language (N10)
  [ ] Every evidence column → real Stage 4 / dossier capture
  [ ] Wedge in ≥ 2 sections; one CTA only; all key messages ≤ 15 words
  [ ] (optional) copy round-tripped through /copywriting

STAGE 6, artifex handshake + merged WOW gate:
  [ ] Wrote the artifex §7 header (Surface: pitch-deck / Override: N0 by definition)
  [ ] Cleared the artifex §7 audit IN FULL (HB-1..HB-6 + A-O), emitted as first artifact
  [ ] Pinning is CSS sticky, NEVER GSAP pin:true (N9)
  [ ] MERGED WOW gate: pitch-deck 7 ⋃ artifex W1-W5, 2 screenshots (1440×900 + 390×844)
  [ ] Direction ping sent; proceed on 1h default; default logged for the final gate

STAGE 6 PRE-SHIP (mechanical block, all green):
  [ ] artifex §15 part-2 scans (dash/weight/size/fonts/shader-presets) → all output NOTHING
  [ ] Flick-test log per pinned section (both directions, zero neighbour-sliver)
  [ ] Lighthouse ≥ 85, TTI ≤ 3s, LCP ≤ 1.2s, CLS ≤ 0.1, JS ≤ 300KB (named runner); leaked chrome killed
  [ ] Zero fabricated metrics (cross-checked vs exploration-report.md)
  [ ] One clear CTA; live URL HTTP/2 200, correct title
  [ ] artifex audit still holds AS BUILT (no drift)
  [ ] Other VPS services intact (hiremeup, signal-trader, wa-sender, aenoxa stack, ...)
```

---

## REFERENCES

| Resource | Location | Used in |
|---|---|---|
| Scrollytelling inspiration | NYT Snow Fall · The Pudding · gsap.com/showcase | Stage 6 design direction |
| GSAP ScrollTrigger + Lenis docs | gsap.com/docs/v3/Plugins/ScrollTrigger · lenis.darkroom.engineering | Stage 6 build |
| Section variance, WOW audit, Paper Shaders, motion/type laws | **`/artifex`** (`~/.claude/skills/artifex/SKILL.md`), §6 method, §7 audit + C4, §9 host-precedence, §13 handshake, §14 stack, §15 scans, N10 | Stage 6 (the build engine) |
| Pinned-scroll pin law (CSS sticky, never GSAP pin) | Memory `reference_scrollytelling_pin_css_sticky` + artifex §7 C4 | Stage 6 · N9 |
| All browser mechanics (claim R-1, tab-new broken HR-9, qb-shoot PB-4, DPR trim PB-5, teardown HR-6) | **`/agent-browser`** (`~/.claude/skills/agent-browser/SKILL.md`) | Stage 4 capture |
| Product dossier + freshness + parallel preflight | **`/atlas`**, dossier store `~/.claude/skills/atlas/dossiers/<slug>/`; §11.2 freshness (`scripts/atlas-freshness.sh`); §12.1 preflight; §10.3 consumer contract | Stage 2 · Stage 4 |
| Design archetypes + engineering base (Font Pairing = §3, NOT §5) | `/frontend-design` (`~/.claude/skills/frontend-design/SKILL.md`) | Stage 6 design |
| Deploy path (source of truth) | `/oneshot-webapp` (`~/.claude/skills/oneshot-webapp/SKILL.md` + `deploy.sh`) | Stage 6 deploy |
| Deck copy sharpening | `/copywriting` (§10 copy-spec handoff) | Stage 5 (optional) |
| Hero visual / key-visual generation | `/zografee` · `/creative` (illustration only, never photo-real bg) | Stage 6 key visuals |
| Demo/launch video (PLUGIN only) | lumiere **plugin** `/lumiere create`; gotchas `reference_demo_video_pipeline` | Demo-video appendix |
| Workflow library | `~/.claude/scripts/workflows/`, `fan-out-review`, `recon-implement-verify`, `loop-until-green` | Multi-agent runs |
| Fleet OOM constraint | Memory `reference_local_box_oom_heavy_workers` | Multi-agent runs |
| Anti-slop / safe-preset discipline | Memory `feedback_frontend_design_safe_templates`, `feedback_skill_authoring_robustness` | Stage 6 design |
| Typography floors · no-mono · no-dash | Memory `feedback_ui_typography_floors`, `feedback_no_monospace_unless_archetype`, `feedback_no_long_hyphens` | N11 · pre-ship scans |
| Verified failures | Memory `project_pulse_landing_redesign_v2` (intake/language), `feedback_frontend_design_safe_templates` + `reference_laurel_bithour_recruiter` (Selaras one-shot), `project_pulse_deck_archetypes` (monotone + pin-blink) | All stages |
| Live archetype decks (worked examples) | `~/claude/Git/repositories/{coba-pulse, pulse-genz, pulse-warmcraft}` (the 3 live Pulse archetypes) | Stage 6 reference |
| Aenoxa brand kit | `~/claude/Git/repositories/orca-design-landing/` or notes | Stage 1, Stage 6 |
| Safe presets | Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism | Stage 6 design |

---

## APPENDIX: Optional demo/launch video (lumiere PLUGIN only, N12)

**AFTER final-gate approval**, a pitch deck is a natural source of a launch/demo video (the AURA demo was rendered from deck pages). This is OPTIONAL and post-gate, it never blocks the deck.

- **Route:** the lumiere **PLUGIN** flow, `/lumiere create` (storyboard → lock → scenes → render). **NEVER** cite or invoke the deprecated local `~/.claude/skills/lumiere` (program-cancelled 2026-07-03; the plugin owns creation).
- **Paid-for gotchas (memory `reference_demo_video_pipeline`, the source, not restated here):** CDP screencast caps ~31fps, so true-60 needs deterministic per-frame seek-render; **verify image-heavy frames BY EYE** (decode-count lies); the locked encode gate is yuv420p / tv / bt709 / faststart; **kill every Chrome after render**; one writer per output dir; keep the chrome profile on `/tmp` tmpfs (never point `TMPDIR` at `/home`, or Chrome dies instantly).
