---
name: pitch-deck
description: Hand it a product → produces an ultra-engaging scrollytelling website pitch deck that makes the target audience want to invest, purchase, or adopt immediately. Runs a 6-stage pipeline (intake → analyze → stories → explore → narrative → cinematic build) with internal self-validation at each stage and ONE final human review gate. Use when Toper says /pitch-deck, asks to build a pitch deck, investor deck, product demo site, or says "make this product compelling."
argument-hint: <product (URL / test account / repo / brief)> [audience: investor|client|recruiter] [ask: what you want them to do]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, WebFetch, WebSearch, Agent
---

# /pitch-deck — product → cinematic scrollytelling pitch

Take a product and produce a **scrollytelling website** that makes the target audience want to invest / purchase / adopt — immediately. This is NOT a slide deck and NOT a marketing landing page. It is a **cinematic, scroll-driven narrative experience** (NYT / The Pudding style): scroll-triggered reveals, pinned sections, progressive build, scroll-linked visuals. Every scroll earns its place.

The skill runs **autonomously end-to-end** — no human interruptions mid-build. There is **ONE human gate at the very end**: Toper reviews the finished deck and approves or iterates. The end-gate is review + refine (cheap iteration on the existing deck), NOT a rebuild from scratch.

**This means: nail the intake, or the whole deck risks missing.** Intake is the linchpin. See Stage 1.

---

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES — READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

Violating any one = failed build. If anything below appears to conflict, the NON-NEGOTIABLE wins.

| # | Rule | Why it exists |
|---|---|---|
| **N1** | **NAMED AUDIENCE BEFORE ANYTHING ELSE.** A deck without a named audience (`investor` / `client` / `recruiter`) = STOP and ask. Audience branches EVERYTHING: story, metrics, tone, CTA. Do not infer. Do not assume. Ask. | Verified: a deck built without a named audience converges on a confused tone that works for nobody. |
| **N2** | **CRYSTAL-CLEAR INTAKE IS THE LINCHPIN.** With ONE final human gate, there is no mid-build correction. The intake (Stage 1) must lock in the exact audience, ask, product access, brand kit, and constraint. If ANY input is missing or ambiguous, ask NOW — not after 2 hours of building. A wrong intake miss = a deck that misses entirely. | The only mid-run correction opportunity is Stage 1. Use it. |
| **N3** | **MAXIMUM IMPACT, NOT MAXIMUM EFFECTS.** Every scroll-triggered section must EARN its scroll with substance. Effects serve the narrative; purposeful + performant, NEVER gimmicky. | Verified failure: art-deco Selaras/Bithour demo rejected "looked SO BAD" — over-designed, under-earned. |
| **N4** | **ZERO FABRICATED METRICS.** NEVER invent traction numbers, user counts, revenue figures, or capability claims. Real numbers + honest framing only. Thin traction = frame as capability + early-stage honestly. Fake numbers kill reputation. | Hard ethical rule — no exceptions. |
| **N5** | **PERFORMANCE BUDGET: ≤ 3s TTI, ≤ 1.2s LCP on 4G.** Lazy-load heavy assets; prefer CSS animations over JS where possible; audit with Lighthouse before shipping. A slow pitch deck is a rejected pitch deck. | First impression dies on load. |
| **N6** | **LIGHT MODE ONLY (pitch decks).** No dark toggle, no `next-themes`. Unless Toper explicitly overrides in the brief. (This overrides the `/frontend-design` light+dark baseline — pitch demos are different from Aenoxa product builds.) | Pitches read cleaner in light; every recruiter/investor context is light by default. |
| **N7** | **SERVER-SIDE SECRETS ONLY** if the deck uses an LLM. Key in container `.env` (chmod 600); never `NEXT_PUBLIC_`; mandatory deterministic fallback so the live demo NEVER fails on API failure. | Per `/oneshot-webapp` hard lessons (Selaras). |
| **N8** | **HONEST INTERNAL SELF-VALIDATION.** At each self-check point (stories, narrative, wow-prototype), validate against CONCRETE criteria in this skill — not vibes, not "this looks great". The self-check is the only safeguard before the final gate. Confabulating "it's fine" is the failure mode that sank the Selaras demo. | No mid-build human to catch a drift. Honest self-check is the only guard. |

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
│ Audience │ Product  │ Exhaust. │ Realtime │ Arc +    │ Cinematic scrollytell │
│ + goal   │ deep-    │ → Hero   │ capture  │ outline  │ → Wow prototype       │
│ + assets │ dive     │ flows    │ + metrics│ (table)  │ → Full build          │
└──────────┴──────────┴────┬─────┴─────┬────┴─────┬────┴───────────┬────────────┘
                            ↓           ↓           ↓               ↓
                       [self-val]  [self-val]  [self-val]      [self-val]
                       hero flows  expl.report narrative      wow section
                       vs criteria  vs flows    vs audience   vs craft rules
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
| **FINAL GATE (the only human gate)** | After full deck is live | Toper | Review → approve (done) OR iterate (refine existing deck, NOT rebuild) |

**Iteration rule:** a miss at the final gate is always a refinement, never a from-scratch redo. The deck exists — change the section, the CTA, the design direction, the copy. The intake should have made a full rebuild unnecessary.

---

## Stage 1 — INTAKE / audience framing (THE linchpin)

**This stage is the single most important stage. With no mid-build human gates, the intake is the only chance to catch a wrong direction. Do it rigorously.**

### Required inputs — lock ALL before proceeding

| Input | Options / examples | What to do if missing |
|---|---|---|
| **Audience** ← *THE most critical* | `investor` / `client-customer` / `recruiter` | **STOP. Ask.** Do not infer. |
| **ASK** | "invest $500k seed" / "book a demo" / "hire me" | **STOP. Ask.** Without this, the CTA and emotional arc are undefined. |
| **Product access** | Live URL + test account, OR repo link, OR written brief | Required for Stage 4. If missing, ask which of these the user can provide. |
| **Brand kit** | Logo, colors, fonts, brand voice doc | If absent → derive palette from live site (Stage 2). Note the assumption. |
| **Key metrics / traction** (if any) | Real numbers only — revenue, users, NPS, speed benchmarks | If none → honest early-stage framing (N4). Note in narrative. |
| **Deployment constraint** | Target domain, language, deadline | Default: `<slug>.topengdev.com`, English, no deadline. Note any override. |

**Intake completeness check (internal):** before Stage 2, verify:
- [ ] Audience is ONE of: `investor`, `client`, `recruiter` (no ambiguity)
- [ ] ASK is one clear action (not "general awareness" or "show it to people")
- [ ] Product access method is confirmed and tested (URL loads, test account works, or repo readable)
- [ ] Any unknown inputs are noted and a sensible default is applied + recorded in `product-analysis.md`

### Audience → pitch strategy map

| Audience | Core emotion to trigger | Story spine | Key metric | CTA |
|---|---|---|---|---|
| **Investor** | "This is the right bet at the right time" | Market pain → wedge → traction → team → ask | ARR / growth rate / TAM | Schedule a call / Deck PDF |
| **Client / customer** | "This solves MY exact problem" | Pain → "what if" → product live-demo → ROI proof | Time saved / cost saved / outcome | Book a demo / Start free trial |
| **Recruiter** | "I want to work with this person / team" | Challenge → how I built this → live proof → what's next | Scale / stack depth / impact | View my work / Contact me |

---

## Stage 2 — PRODUCT ANALYSIS

**Produce a structured product analysis doc. Not prose — a table-first breakdown.**

### Output: `product-analysis.md`

| Section | Required content |
|---|---|
| Problem statement | The pain (stated in the AUDIENCE's language, not the builder's) |
| Target market | Who hurts, at what scale |
| Solution + differentiation | What it does + how it differs from alternatives |
| Business model | Revenue model (required for investor; optional for others) |
| **THE WEDGE** | The ONE thing that makes this compelling. If you can't name it, stop and find it. |
| Existing assets | Landing, docs, repo, brand kit — what's available for Stage 4/6 |
| Known gaps / honest weaknesses | Surface real weaknesses (important for N4 + honest narrative) |

**The Wedge rule:** the wedge is the narrative hinge. Everything in the deck amplifies the wedge. If there's no clear wedge, the narrative will be diffuse and unconvincing. Find it before proceeding.

---

## Stage 3 — USER STORIES: exhaustive THEN prioritize (internal self-validation)

**Do NOT skip the exhaustive step to jump to "the 3 best features." The exhaustive list is how you find the REAL hero flows.**

### Step 3a — Enumerate EVERY user story by persona

```
Persona 1 → Story A, Story B, Story C, ...
Persona 2 → Story D, Story E, ...
```

Example (POS system):
- **Cashier:** ring up sale, apply discount, split payment, void item, print receipt, check shift total
- **Manager:** view daily report, adjust pricing, void transaction, add staff
- **Owner:** real-time revenue, compare branches, export to accounting, monthly goals

### Step 3b — Score + produce the User-Story Matrix

**Output: a matrix table (NOT prose)**

| Story | Persona | Pitch value (1-5) | Demo-ability (1-5) | Includes wedge? | Hero candidate? |
|---|---|---|---|---|---|
| Real-time revenue dashboard | Owner | 5 | 5 | Yes | ★ |
| Ring up + split payment | Cashier | 4 | 5 | No (table stakes) | ★ |
| Void + audit trail | Manager | 3 | 3 | Partially | |
| ... | ... | ... | ... | ... | |

### Internal self-check: hero flow selection (before Stage 4)

**Do this check autonomously. Do not wait for human input.**

| Criterion | Check |
|---|---|
| Pitch value ≥ 4 AND demo-ability ≥ 4 | All proposed hero flows must pass |
| Wedge is included | At least one hero flow directly demonstrates the wedge |
| End-to-end in ≤ 90 seconds of scrolling | No hero flow requires more than ~6-8 screenshots to tell |
| Count: 3–5 hero flows | 3 is ideal for investor/recruiter, 4-5 for client |
| All are REAL and VERIFIABLE | Cross-check: can you actually demo each one in Stage 4? |

If any hero flow fails this check → revise selection before Stage 4.

---

## Stage 4 — REALTIME EXPLORATION + CAPTURE

**Navigate and ACTUALLY USE the product following each hero flow. This is the evidence-gathering stage.**

### Tools to use

- `/agent-browser` (qutebrowser) for live navigation — NEVER headless Playwright for visual inspection
- Screenshots at each meaningful state (see capture checklist below)
- Capture real data: load times (network tab), numbers rendered on screen, actual outputs

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
| Step | Screenshot path | Observation | Deck-worthy? |
|---|---|---|---|
| 1. Login | /tmp/screenshots/login.png | Loads in 0.8s | Yes |
| 2. Dashboard | /tmp/screenshots/dash.png | Real-time chart, impressive | YES — WOW |
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
| No invented observations | Only what was ACTUALLY seen in the product |
| The wedge is captured visually | Deck can SHOW the wedge, not just tell |
| All gaps/bugs honestly noted | N4 — no glossing over real limitations |

**If a hero flow failed in exploration** (feature broken, login failed, access blocked): note it honestly. Either swap to an alternate flow from the Stage 3 matrix, OR note the limitation and plan for honest framing in the narrative.

**Multi-agent note:** Stage 4 maps directly to parallel exploration — one agent-browser worker per hero flow, running simultaneously with a shared screenshot output dir, synthesized into the exploration report. Use the workflow library's `fan-out-review` pattern for thorough runs. See the Multi-Agent section at the end of this skill.

---

## Stage 5 — NARRATIVE ARC (internal self-validation)

**The narrative is the deck's spine. Select the arc for the named audience.**

### Audience-specific narrative templates

**INVESTOR:**
```
[HOOK]      The painful truth about [market] — a stat or story that lands hard
[PROBLEM]   The specific gap (scale: $Xbn market, Y% without a real solution)
[SOLUTION]  The wedge: what was built, why now, why this team
[LIVE DEMO] 2-3 hero flows, shown in action (screenshot trail)
[TRACTION]  Real numbers — ARR / users / growth rate / notable customers
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
[SOCIAL PROOF] Honest testimonials or early case study (only if real — N4)
[CTA]       One action: "Book a demo" / "Start free"
```

**RECRUITER:**
```
[HOOK]      The challenge that shaped this work
[PROBLEM]   What I was solving and why it was hard
[BUILD]     How I built it — decisions, stack, key choices (show the thinking)
[PROOF]     The result, working, in real numbers
[NEXT]      Where I'm heading / what I want to build
[CTA]       "View my work" / "Let's talk"
```

### Output: `narrative-outline.md` (table format)

| Scroll section | Section name | Key message (≤ 15 words) | Visual anchor | Evidence source |
|---|---|---|---|---|
| 1 | Hook | "Most POS systems fail at the moment that matters most" | Full-bleed type | — |
| 2 | Problem | "Lost $Xbn to downtime last year" | Animated counter | Real stat or honest estimate |
| 3 | Solution | "Pulse works offline — your sales never stop" | Split before/after | Screenshots from Stage 4 |
| 4 | Demo flow 1 | "See it handle a split payment in 8 seconds" | Scroll-synced trail | Captured flow 1 |
| 5 | Traction | "500 merchants, ↑240% in 3 months" | Counter animation | Real metrics |
| 6 | CTA | "Schedule a call" | High-contrast, clean | — |

### Internal self-check: narrative quality (before Stage 6)

| Criterion | Check |
|---|---|
| Story matches the named audience template exactly | No investor narrative for a client deck |
| Every "evidence source" column points to REAL Stage 4 capture | No "TBD" or invented stats |
| The wedge appears in ≥ 2 sections | Hook + solution minimum |
| One CTA, not multiple | Decision fatigue kills conversions |
| Key message for each section ≤ 15 words | If longer, cut; if it can't be condensed, the section is unclear |
| No fabricated metrics in the "Evidence source" column | N4 — if thin, honest early-stage framing |

---

## Stage 6 — BUILD: Cinematic Scrollytelling Website

**This stage has an internal self-validation loop: build the WOW prototype first, self-check against concrete craft criteria, then continue to full build. No human stop — but the self-check must be HONEST (N8).**

### Stack recommendation (opinionated defaults)

| Decision | Default | Alternative | When to switch |
|---|---|---|---|
| **Framework** | **Next.js 15 App Router** | Astro | Astro if fully static, no server features needed |
| **Scroll engine** | **GSAP ScrollTrigger** (precise pinning, battle-tested) | Framer Motion | Framer if already in Next.js stack + simpler scenes |
| **Smooth scroll** | **Lenis** (compositor-friendly, silky) | None | Skip if perf testing shows jank on low-end devices |
| **Animation layer** | GSAP timeline + CSS transitions | Motion Primitives | Motion Primitives for React-native component animations |
| **Styling** | Tailwind v4 + CSS custom properties | CSS Modules | CSS Modules for complex multi-state animations |
| **Component base** | Origin UI (neutral base) + bespoke WOW sections | shadcn/ui | Either — compatible |
| **Deploy** | `<slug>.topengdev.com` | Product subdomain | Product subdomain if going live to real users |

**Stack lock-in rule:** choose ONE scroll engine (GSAP or Framer) and stick. Mixing creates conflicting animation lifecycles and performance bugs.

### Design direction

Use `/frontend-design` to set the archetype. Pitch decks map to these safe presets:

| Pitch type | Recommended archetype | Feel |
|---|---|---|
| Investor / seed round | **Editorial Luxury** or **Soft Structuralism** | Premium, confident, restrained |
| SaaS / client demo | **Soft Structuralism** or **Warm Craft** | Trustworthy, approachable, modern |
| Tech / dev tool | **Japanese Minimal** or **Swiss / International Typographic** | Precise, credible, no fluff |
| Recruiter / portfolio | **Editorial Luxury** | Taste, craft, personality |

**Anti-generic discipline (HARD — mirrors `/oneshot-webapp`):**

| BANNED | WHY | INSTEAD |
|---|---|---|
| Centered hero → 3 feature cards → CTA banner → footer | The AI-slop signature | Scroll-pinned hook with progressive reveal, offset sections, layout shifts that surprise |
| Purple/blue gradient hero overlays | Over-used to the point of invisibility | Brand palette + THE WEDGE as the visual anchor |
| Lottie animations for motion's sake | Motion without narrative purpose = gimmick | Scroll-triggered reveals tied to the story beat |
| Feature-list sections (✓ item, ✓ item) | Nobody reads them | Hero FLOWS shown live in context |
| Stock photo heroes | Signals "not a real product" | Real screenshots from Stage 4 capture |
| Plain Inter/Roboto as display face | Default = generic | Distinctive pairing from `/frontend-design` §5 |

### Section architecture template

Map the approved narrative outline to scroll sections. Each section is a **scroll-pinned unit** with its own trigger and reveal:

```
┌─────────────────────────────────────────────────────────────────────┐
│  SECTION MAP (adapt to approved narrative — this is the template)   │
├─────────────┬───────────────────────────────────────────────────────┤
│ HOOK (pin)  │ Full-viewport type statement. Scroll-in word-by-word │
│             │ or line-by-line. No hero image needed. Just message. │
├─────────────┼───────────────────────────────────────────────────────┤
│ PROBLEM     │ Scroll-linked counter or stat build. Pain made vivid. │
│ (pin)       │ Before-state screenshot fades in on scroll.           │
├─────────────┼───────────────────────────────────────────────────────┤
│ SOLUTION    │ The wedge reveal. Split-screen or before/after.       │
│ (pin)       │ Product screenshot appears as you scroll down.        │
├─────────────┼───────────────────────────────────────────────────────┤
│ DEMO FLOW 1 │ Scroll-synced screenshot trail. The user story plays  │
│ (scrub)     │ frame-by-frame as user scrolls. Feels like a slow-mo  │
│             │ demo. ~4-6 screenshots, cross-faded on scroll.        │
├─────────────┼───────────────────────────────────────────────────────┤
│ DEMO FLOW 2 │ Same pattern, different hero story.                   │
│ (scrub)     │                                                        │
├─────────────┼───────────────────────────────────────────────────────┤
│ PROOF /     │ Real metrics animated in (counters). Testimonials if  │
│ TRACTION    │ real and available (N4 — no fabrication).             │
├─────────────┼───────────────────────────────────────────────────────┤
│ THE ASK /   │ Clean, minimal. ONE CTA. High contrast. No clutter.   │
│ CTA (pin)   │ The decision point. Make it easy to say yes.          │
└─────────────┴───────────────────────────────────────────────────────┘
```

### Internal self-validation: WOW prototype (MANDATORY before full build)

**Build the HOOK section + one DEMO FLOW section first. Nothing else. Then self-check honestly against ALL criteria below before continuing.**

| Criterion | Pass condition | FAIL action |
|---|---|---|
| Scroll-trigger feels cinematic | Smooth scrub, correct easing, no jank on scroll | Fix the scroll behavior, re-test |
| Typography has personality | Display face is NOT Inter/Roboto/Arial | Change the display face |
| Archetype is correct | Section reads as editorial luxury / soft structuralism / etc. — NOT generic | Revisit color + type + layout |
| Hero message is clear in ≤ 3s | First scroll position delivers the hook clearly | Simplify or reword |
| Performance is fast | No layout shift, no loading jank on first view | Lazy-load, remove heavy pre-loads |
| Does NOT look AI-generated | No purple gradients, no generic 3-card grid, no lorem ipsum | Apply anti-generic discipline |
| Narrative fidelity | Section tells the correct story beat from narrative-outline.md | Revise if drifted from the approved arc |

**ALL criteria must pass before building the remaining sections.** If 2+ criteria fail, the design direction is wrong — revisit the archetype selection before continuing. Do NOT "push through" a failed WOW prototype (that is exactly what produced the Selaras rejection).

### Performance audit (pre-ship, mandatory)

| Metric | Hard threshold | How to check |
|---|---|---|
| Time to Interactive | ≤ 3s on 4G | Lighthouse audit |
| LCP | ≤ 1.2s | Lighthouse audit |
| CLS | ≤ 0.1 | Lighthouse audit |
| JS bundle | ≤ 300KB compressed | `next build` analyzer |
| Images | WebP or AVIF, lazy-loaded | Build output grep |
| GSAP | Loaded via CDN (not bundled) if > one page | Bundle analyzer |

**Lighthouse score < 85 → DO NOT SHIP. Fix performance issues first.**

### Deploy

Follow `/oneshot-webapp` deploy path precisely:
- `<slug>.topengdev.com` → Cloudflare A record (per-subdomain, no wildcard) + nginx + certbot + HTTPS
- `~/apps/<slug>/.env` chmod 600 for any secrets
- Verify: `curl -I https://<slug>.topengdev.com` → HTTP/2 200; eyeball live site, confirm stale-title cleared
- VPS access: `sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$VPS_USER@$VPS_HOST"`
- Do NOT disrupt other VPS services (hiremeup, signal-trader, wa-sender, aenoxa stack)

---

## FINAL HUMAN GATE (the only one)

**After the full scrollytelling site is live at `https://<slug>.topengdev.com`:**

Present to Toper:
1. **Live URL** — the full deck, live
2. **Lighthouse score** — perf confirmation
3. **Evidence trail** — which screenshots came from Stage 4 real capture, which metrics are real
4. **Any honest gaps** — what the deck doesn't cover (features not shown, traction thin, etc.)
5. **Iteration handle** — "If X section doesn't land, here's what we'd change and why it's cheap to fix"

**Response paths:**

| Toper response | What to do |
|---|---|
| "Approved" / "looks great" | Done. Close the loop: report.md + result.json. |
| "Change section X" | Revise ONLY that section. Re-deploy. No rebuild. |
| "The narrative is wrong" | Revisit narrative-outline.md → revise the affected sections. Still no full rebuild. |
| "Wrong audience / tone" | This is an intake miss. Revisit Stage 1 with clarified audience, then Stage 5+6 only. |

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
│ 3. WOW BEFORE BULK        Build prototype first, self-check         │
│                            honestly, THEN full build.                │
│ 4. PERFORMANCE = RESPECT  Slow = disrespect for the viewer's time.  │
│ 5. INTEGRITY (N4)         Real numbers, honest framing. Always.     │
│ 6. ONE CLEAR ASK          One CTA. Decision fatigue kills it.       │
│ 7. REAL SCREENSHOTS       Stage 4 capture only. Stock = fake = dead.│
│ 8. HONEST SELF-CHECKS     Validate against criteria, not vibes.     │
│                            "Looks great" is not a pass condition.    │
└──────────────────────────────────────────────────────────────────────┘
```

### Verified failures (learn from these)

| Failure | Root cause | Guardrail that catches it |
|---|---|---|
| Art-deco Selaras/Bithour demo rejected (2026-05-29) | Over-designed, effects without substance | N3 — Impact > Effects; WOW self-check criteria |
| Gruvbox reskin rejected post-full-build | Full build on unvalidated design direction | WOW prototype self-check (all criteria, all pass) |
| Pulse landing v2: wrong assumptions, 1h wasted (2026-05-24) | Wrong intake, wrong audience assumptions | N2 — intake is the linchpin; complete Stage 1 |

---

## INTERMEDIATE DELIVERABLES (per stage)

| Stage | Deliverable | Format required |
|---|---|---|
| Stage 1 | Intake locked + assumptions noted | `product-analysis.md` header table |
| Stage 2 | `product-analysis.md` | Structured tables + Wedge callout |
| Stage 3 | `user-story-matrix.md` | Matrix table (persona × story × pitch-value × demo-ability) |
| Stage 4 | `exploration-report.md` | Table per hero flow + screenshot paths + real metrics |
| Stage 5 | `narrative-outline.md` | Table (section × message × visual anchor × evidence source) |
| Stage 6 partial | WOW prototype self-check | Agent checks all criteria, logs pass/fail results |
| Stage 6 final | Full scrollytelling site at `https://<slug>.topengdev.com` | Live URL + Lighthouse score |

**All docs MUST be visual-first (tables, matrices, ASCII diagrams) — not prose walls.** Christopher reads structured visuals 10× faster than paragraphs.

---

## MULTI-AGENT ORCHESTRATION

This pipeline maps directly to the workflow library for thorough runs:

```
Stage 4 (Explore) → fan-out:
   one agent-browser worker per hero flow, parallel
   → each outputs a per-flow exploration table
   → synthesize into exploration-report.md

Stage 6 (Build) → recon→implement→verify:
   recon worker   → builds WOW prototype, screenshots, internal self-check
   implement worker → full build (all sections)
   verify worker  → Lighthouse audit + live URL smoke test
```

| Run mode | When to use | Approach |
|---|---|---|
| Fast (single worker) | Tight deadline, clear brief, simple product | Sequential 6 stages, single session |
| Thorough (multi-worker) | Multiple hero flows, complex product, high-stakes pitch | `fan-out-review` for Stage 4, `recon→implement→verify` for Stage 6 |

**Worker model guidance:**

| Worker | Model | Reason |
|---|---|---|
| **ALL pitch-deck workers** (explore / narrative / build) | **Opus** | Toper's standing call (2026-06-20): the ENTIRE pipeline is design-judgment work — seeding realism, hero-flow selection, narrative arc, and the cinematic build all need Opus. The customer-facing design-quality carve-out covers the whole skill, not just Stage 6. Default every pitch-deck worker to Opus. |

---

## QUICK-REFERENCE CHECKLIST (print before starting)

```
STAGE 1 (Intake) — lock ALL before Stage 2:
  [ ] Audience: investor / client / recruiter (no ambiguity)
  [ ] ASK: one clear action
  [ ] Product access confirmed and tested
  [ ] Brand kit collected OR fallback noted (derive from live site)
  [ ] All missing inputs either asked OR defaulted + noted

STAGE 3 (Stories) — internal self-check before Stage 4:
  [ ] Exhaustive story list done (all personas × all stories)
  [ ] Scored matrix produced
  [ ] 3–5 hero flows: all score ≥ 4/4, wedge included, ≤ 90s each
  [ ] Flows are REAL and verifiable in Stage 4

STAGE 4 (Explore) — internal self-check before Stage 5:
  [ ] Every hero flow has complete screenshot trail
  [ ] ≥ 1 real metric per flow
  [ ] All observations are from actual product use (no invention)
  [ ] Wedge captured visually
  [ ] Gaps/bugs honestly noted

STAGE 5 (Narrative) — internal self-check before Stage 6:
  [ ] Correct audience template used
  [ ] Every evidence column → real Stage 4 capture
  [ ] Wedge in ≥ 2 sections
  [ ] One CTA only
  [ ] All key messages ≤ 15 words

STAGE 6 WOW PROTOTYPE — internal self-check (ALL must pass before full build):
  [ ] Scroll-trigger cinematic (smooth, no jank)
  [ ] Display face NOT Inter/Roboto/Arial
  [ ] Archetype reads correctly (not generic)
  [ ] Hook clear in ≤ 3s
  [ ] No loading jank on first view
  [ ] Not AI-looking (anti-generic discipline holding)
  [ ] Story fidelity: matches narrative-outline.md beat

STAGE 6 PRE-SHIP:
  [ ] Lighthouse ≥ 85, TTI ≤ 3s, LCP ≤ 1.2s
  [ ] Zero fabricated metrics anywhere
  [ ] All screenshots from Stage 4 real capture (not stock)
  [ ] One clear CTA
  [ ] Live URL: HTTP/2 200, correct title, stale-title cleared
  [ ] Other VPS services intact (hiremeup, aenoxa stack, etc.)
```

---

## REFERENCES

| Resource | Location | Used in |
|---|---|---|
| Scrollytelling inspiration | NYT Snow Fall · The Pudding · gsap.com/showcase | Stage 6 design direction |
| GSAP ScrollTrigger docs | gsap.com/docs/v3/Plugins/ScrollTrigger | Stage 6 build |
| Lenis smooth scroll | lenis.darkroom.engineering | Stage 6 build |
| Design archetypes + library map | `/frontend-design` (`~/.claude/skills/frontend-design/SKILL.md`) | Stage 6 design |
| Deploy path | `/oneshot-webapp` (`~/.claude/skills/oneshot-webapp/SKILL.md`) | Stage 6 deploy |
| Hero visual generation | `/zografee` (`~/.claude/skills/zografee/SKILL.md`) | Stage 6 key visuals |
| Creative imagery | `/creative` | Stage 6 AI-generated assets |
| Workflow library | `~/.claude/scripts/workflows/` — `fan-out-review`, `recon→implement→verify` | Multi-agent runs |
| Anti-slop discipline | Memory `feedback_frontend_design_safe_templates`, `feedback_skill_authoring_robustness` | Stage 6 design |
| Verified failures | Memory `project_pulse_landing_redesign_v2`, `project_bithour_interview` | All stages |
| Aenoxa brand kit | `~/claude/Git/repositories/orca-design-landing/` or notes | Stage 1, Stage 6 |
| Safe presets | Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism | Stage 6 design |
