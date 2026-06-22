---
name: artifex
description: Hand it a website / page / multi-section brief → it produces an ultra-engaging, award-caliber, VARIANCE-FIRST design (cinematic, immersive, distinctive) — the deliberate opposite of generic/monotone/AI-default. The high-variance/immersive counterpart to /frontend-design (NOT a replacement). Use when Toper says /artifex, or asks to make something "award-caliber / cinematic / immersive / ultra-engaging / not basic / not monotone / wow", redesigns a deck/landing that got called "flat / template / same thing repeated", or wants a pitch/demo site that has to stand out.
---

# /artifex — variance-first, award-caliber web design

> **frontend-design picks ONE archetype and applies it cleanly across a page. /artifex sequences DIFFERENT treatments per section.** One is coherence-via-sameness (safe, production). The other is richness-via-variance (immersive, award-bait). This skill encodes the craft that makes the second possible so it can't collapse back into the first.

`/artifex` is `/frontend-design`'s immersive sibling. It **inherits** frontend-design's engineering — typography mechanics (§3), motion mechanics (§5), the anti-slop bans (§8), mobile resilience (§9), the component-library map (§0.7). It does **not** re-document them; read them there. What `/artifex` adds is the layer frontend-design has no mechanism for: **forced design variance, an immersion technique vocabulary, a section-by-section variance method, and a hard audit gate that refuses a monotone build.**

---

## ⛔ NON-NEGOTIABLE RULES — READ FIRST, THESE OVERRIDE EVERYTHING BELOW

| # | Rule | Enforcement |
|---|---|---|
| **N1** | **DISTINCT skeleton per section.** No two sections share a layout skeleton. Repeated content (demo 1 / demo 2 / demo 3) must NOT share a layout. | The Variance Audit (§7) fails the build if any skeleton repeats. |
| **N2** | **DISTINCT signature technique per section, then RETIRE it.** A technique carries exactly ONE section, never the next. | Variance Audit fails if any technique repeats. |
| **N3** | **Scrollytelling counted by DISTINCT technique — each distinct pinned scroll-scrubbed technique appears ≤ 1 time** (a text-illumination scrub and a screenshot scrub are DIFFERENT techniques, so both may coexist). It is never the spine. | Variance Audit (§7 check C) fails if the SAME scrollytelling technique carries two sections. |
| **N4** | **≤ 1 heavy effect (WebGL/canvas/3D) on the entire page.** Build ~90% from the Buildable tier; spend the whole hard budget on exactly ONE signature wow; never touch the Elite tier. | Performance Budget (§9) + Feasibility (§10). Audit fails if heavy-effect count ≥ 2. |
| **N5** | **Distinctive DISPLAY + neutral BODY + oversized index/section markers.** Mono is used confidently/integrated — the timid mono micro-label "eyebrow" tell is hard-banned (§7 A2). BAN the AI-defaults (Instrument Serif, Plus Jakarta Sans, Inter-only, Roboto). | Typography System (§8) + §7 Hard-Ban A2 + inherits frontend-design §8 Banned Fonts. |
| **N6** | **A recurring MOTIF threads ≥ 3 sections.** Variance without a through-line reads as random, not designed. The motif (a brand line, a color callback, a repeated mark) is what licenses the variance. | Variance Audit checks for ≥ 1 motif spanning ≥ 3 sections. |
| **N7** | **Effects are progressive enhancement.** Scroll must hit 60fps with ALL effects OFF. `prefers-reduced-motion` + coarse-pointer / cheap-Android downgrade to static. | Performance Budget (§9). |
| **N8** | **Design from the technique library + studied references — NOT from the model's idea of "engaging."** Carry the reference set; name the technique and the ref before building each section. | Grounding (§11). "I'll make it engaging" with no named technique = a violation. |

### The failure this skill exists to prevent (verified, twice)

A Pulse pitch deck was rejected **twice** as *"MONOTONE / basic."* Root cause, diagnosed:

| What was built | Why it read monotone |
|---|---|
| Sections 1–3 (Hook, Problem, Wedge) all "pinned type reveal" | **same skeleton ×3** |
| Demos 4–6 all "scroll-scrubbed screenshot trail" | **same technique ×3** |
| Net: ONE technique (scrollytelling) × 9 sections | = monotone. Blurred background circles were gloss-on-sameness, not variance. |

The fix was never "more polish." It was **9 different sections.** `frontend-design` produces safe, clean, production output with nothing forcing variance — so on a deck that needs to *dazzle*, it defaults to one good idea repeated. `/artifex` makes that repeat **mechanically impossible** via the audit gate.

> The pitch-deck skill's own Stage-6 "Section architecture template" still hard-codes this bug (`HOOK (pin) / PROBLEM (pin) / SOLUTION (pin)` then `DEMO 1 (scrub) / DEMO 2 (scrub) — "Same pattern, different hero story"`). When `/artifex` drives a pitch deck, it **replaces** that template with the variance method (§6). See COMPOSES WITH (§13).

---

## 1. THE PRINCIPLE

> **Award sites are not "polished" versions of the same page. They are a sequence of DIFFERENT pages.** Richness comes from VARIANCE, not from gloss on sameness.

Three rules every studied award site obeys:

| Rule | What it means | Proof (from the reference set, §12) |
|---|---|---|
| **Distinct skeleton per section** | Every section changes WHERE things sit — full-bleed / split / bento / horizontal rail / centered statement / tilted card. No two adjacent sections share a layout. | Lusion: physics-hero → red full-bleed showreel → editorial card grid → gallery → centered-type → split. Six sections, six skeletons. |
| **One signature technique per section, then retire it** | Each section owns ONE move (a 3D scene, a color-cut, a type-ring, a scrub). It never carries the next section too. | Synchronized: circular text-rings for services, then never again — switches to index-numbered color-field case panels. |
| **Transitions are designed moments** | The handoff between sections is itself an event: a color invert, a mask wipe, a camera morph, a rounded panel sliding up. Not a hard cut to "next screenshot." | Crescente slides a cream rounded panel up over orange. Pioneer morphs ONE 3D world from DNA-helix to seed-sprout as you scroll. |

**The cohesion paradox (why variance doesn't read as chaos):** the studied sites vary the SKELETON + TECHNIQUE + TRANSITION per section, but hold **ONE base system constant** — one type pairing, one color discipline, one recurring motif. Lusion is six different skeletons but ONE grotesque + ONE mono-eyebrow + ONE color logic. **Variance lives in layout & motion; coherence lives in type, color, and the motif.** Vary the wrong axis (brand, palette, font per section) and you get a ransom note. Vary the right axis and you get an award site.

---

## 2. WHEN TO USE /artifex vs /frontend-design

| | **/frontend-design (SAFE mode)** | **/artifex (IMMERSIVE mode)** |
|---|---|---|
| **Method** | Pick ONE archetype, apply consistently across the page | Pick ONE base palette, VARY skeleton + technique + transition per section |
| **Coherence from** | Sameness (one layout language) | A motif + constant type/color, over deliberate variance |
| **Default dials** | VARIANCE 4–7, MOTION 3–6 (per archetype) | **VARIANCE 8–10, MOTION 6–9, floored** — the variance dial is bolted to the top |
| **Best for** | Production apps, dashboards, the Aenoxa product (needs i18n + dark mode), client sites that must be maintainable | Pitch decks, demos, launch/award sites, hero landing moments, "make it not basic" |
| **Risk it fails on** | Looks generic / template when the brief needed to dazzle | Over-engineered / janky / inaccessible if the gates (§7, §9) aren't enforced |
| **Theming** | i18n + light/dark mandatory (Aenoxa ecosystem) | Usually single-theme, single-locale (pitch/demo). Inherit the host skill's theming rule (pitch decks = light-only) |

**Bright-line:** if the deliverable's #1 job is to **make someone feel something and act** (invest / adopt / hire / "wow") → `/artifex`. If its #1 job is to **work reliably and be maintained** (product UI, admin, docs) → `/frontend-design`. When a brief says "award-caliber / cinematic / immersive / ultra-engaging / not basic" → `/artifex`, full stop.

`/artifex` still **uses an archetype** from frontend-design §2 as its BASE (color/type/mood). It just refuses to let that archetype flatten into one repeated skeleton.

---

## 3. THE ENGINEERING YOU INHERIT (do not re-derive)

`/artifex` does not restate frontend-design's mechanics. Open `~/.claude/skills/frontend-design/SKILL.md` and apply:

| Need | Where in frontend-design |
|---|---|
| Archetype palettes (the BASE for your page) | §2 Vibe Archetypes |
| Type mechanics (tracking, modular scale, variable-font axes) | §3 |
| Surface/layout primitives (bezel cards, optical alignment, eyebrows) | §4 |
| Motion mechanics (interruptible vs keyframe, magnetic hover, cursor patterns, scroll entry) | §5 |
| Scrollytelling patterns + Lenis integration (you'll use ONE of these) | §7 |
| **Anti-slop banned fonts/colors/layouts/content/icons** | §8 — fully in force here |
| Mobile animation resilience (`useOnScreen`, IO fallbacks, reduced-motion) | §9 |
| Component-library map (Origin UI base + archetype primary) | §0.7 |
| Architecture rules (RSC boundaries, dep verification, Tailwind v3/v4) | §13 |

If something is covered there, USE it there. The sections below are the layer frontend-design lacks.

---

## 4. NON-NEGOTIABLES (the enforced craft, expanded)

| Rule | Enforcement mechanism | FAIL looks like |
|---|---|---|
| **DESIGN VARIANCE** | The Variance Audit (§7) — a mandatory pre-build gate. List every section's skeleton + technique + transition; assert all skeletons distinct, all techniques distinct, scrollytelling ≤ 1, heavy-effects ≤ 1, ≥ 1 motif over ≥ 3 sections. | Two sections share a layout; one technique carries three sections. |
| **TECHNIQUE PALETTE** | Design only from the 22-technique library (§5), each tagged **B / H / E**. Build ~90% from **B**, spend the entire hard budget on exactly ONE **H**, never touch **E**. | "I'll add a cool particle thing here and another there" (two H, or an E faked at 40%). |
| **PERFORMANCE BUDGET** | §9 — ≤ 1 heavy canvas; lazy-load below-fold; `prefers-reduced-motion` + coarse-pointer downgrade; 60fps with effects OFF. | Two WebGL scenes; scroll janks on a mid Android; effects are load-bearing for legibility. |
| **TYPOGRAPHY-NOT-DEFAULT** | §8 — distinctive DISPLAY + neutral BODY + oversized index/section markers (the timid mono eyebrow is hard-banned, §7 A2); ship a recommended pairing; tight tracking on big type; BAN Instrument Serif / Plus Jakarta Sans / Inter-only / Roboto. | Instrument Serif headline + Plus Jakarta body = the AI-default look = an instant tell. |
| **ANTI-SLOP** | Inherit frontend-design §8 wholesale (centered-hero→3-cards→CTA, purple gradients, stock heroes, glowing-dot pills, lorem ipsum, filler power-words). | Any banned pattern present. |
| **GROUNDING** | §11 — name the technique + the reference for every section BEFORE building. Carry the reference set (§12). | A section justified by "make it engaging" with no named technique/ref. |

---

## 5. THE TECHNIQUE LIBRARY (the design vocabulary — 22 moves)

This is the palette you design FROM. Every section's signature technique is one of these. **Difficulty tags are load-bearing:**

- **B** — Buildable. A strong worker hits ~80% with GSAP/ScrollTrigger + Lenis + Framer Motion + SVG + CSS. **Build ~90% of the page from B.**
- **H** — Hard. Budget as the ONE splurge (react-three-fiber + a simple shader, or a pre-rendered 3D turntable). **Exactly one H per page, or zero.**
- **E** — Elite. Studio-only (creative-dev team + weeks). **Never attempt.** Faking an E at 40% looks worse than a clean B section.

| # | Technique | What it does | Build |
|---|---|---|---|
| T1 | **Full-bleed color-field cut / invert** | Hard cut to a saturated or inverted ground = instant "new chapter" | **B** |
| T2 | **Rounded-panel reveal handoff** | A panel with rounded top slides up over the previous color-field as the transition | **B** |
| T3 | **Oversized editorial display type AS layout** | Type at architectural scale (150–590px) IS the composition. The single biggest "premium" signal | **B** |
| T4 | **Kinetic type reveal** (word-by-word, scramble, mask-up) | Letters/words animate in on enter; never static text | **B** |
| T5 | **Circular text-on-a-path / type rings** | Words wrap a circle and rotate; a distinctive "designed" flourish | **B** (SVG `textPath`) |
| T6 | **Glitch / knockout / offset type** | Doubled-offset glitch or a colored knockout block behind a word | **B** (CSS) → **H** (canvas) |
| T7 | **Bento / masonry mixed-scale collage** | A grid of different-sized cards (image/3D/text/video) = density + rhythm | **B** |
| T8 | **Index-numbered case panels on alternating muted color-fields** | Each item = a new muted ground (sage/lilac/taupe) + asymmetric image + big title + 01/02/03 index | **B** |
| T9 | **Floating / tilted card reveal** | Cards float/rotate into frame on scroll, breaking the flat grid | **B** |
| T10 | **Horizontal-scroll / pinned rail** | A section scrolls sideways while pinned = breaks vertical rhythm hard | **B** → **H** |
| T11 | **3D product render moment** | One hero object rendered in 3D, rotating / lit | **H** (GLB or pre-rendered turntable) |
| T12 | **Atmospheric full-bleed cinematic environment + overlay text** | A full-screen video or 3D backdrop with copy floating over | **B** (video) / **H** (3D) |
| T13 | **Big-number statement (count-up)** | One enormous number counts up on enter = drama from data | **B** |
| T14 | **Split layout** (media one side, copy the other) | 50/50: a visual locked to one side, narrative to the other | **B** |
| T15 | **Custom cursor + momentum (Lenis) smooth scroll** | The whole page feels weighted and bespoke; cursor reacts to targets | **B** |
| T16 | **Hover-reveal video thumbnails** | Project tiles play a muted clip on hover | **B** |
| T17 | **Mono / technical labels — used confidently, NOT as a blanket eyebrow** | Tracked-out mono labels, but never a timid tiny separate eyebrow on every header (that tell is hard-banned, §7 A2). Use sparingly + integrated; default to oversized index markers (B3) for section marking | **B** |
| T18 | **Interactive WebGL physics / particle hero** | A real-time simulation you push with cursor/scroll | **H** (one) / **E** (full) |
| T19 | **Continuous scroll-driven 3D world morph** | ONE 3D scene transforms through the entire scroll | **E** |
| T20 | **Synthwave perspective grid + neon** | A receding grid floor + glow = instant retro-tech mood | **B** |
| T21 | **Product-anchored card swap** | The product stays PINNED to the viewport while benefit cards + illustrations swap around it on scroll | **B** |
| T22 | **Flat-illustration collage + 3D/photo product** | Playful illustrations layered with one real product = warm F&B identity | **B** |

**Reading the table:** T15 (Lenis + cursor) is **connective tissue** — apply it across the whole page; it doesn't count as a section's signature. (T17 mono labels are NOT blanket connective tissue anymore — see §7 A2; use oversized index markers for section marking instead.) Every other technique is a one-section signature. The **B**-heavy rows are your workhorses; T11 / T18 / T6-canvas are your *candidates* for the single H splurge; T19 and T18-full are **E — do not attempt.**

> **Pinning implementation (T10 pinned rail / T21 product-pinned swap / any pinned scroll-scrubbed section):** pin via CSS `position:sticky`, **never GSAP `pin:true`** — GSAP pin's `position:fixed` swap lands ~1 frame late on fast scroll and flashes a neighbour-sliver. Keep ScrollTrigger for the scrub only. Full rule + fix: §7 audit **C4**.

---

## 6. THE METHOD — variance-mapping a multi-section page

This is the core procedure. Do it BEFORE writing any code.

### Step 1 — List the narrative beats
Get the section list (from the brief, or from `/pitch-deck`'s narrative outline). Example: a 9-beat product pitch = Hook / Problem / Wedge / Demo-1 / Demo-2 / Demo-3 / Capability / Why-now / CTA.

### Step 2 — Assign a DISTINCT skeleton + technique + transition per beat
Fill the **Variance Map** table. One row per section. Pull skeletons from the catalog below and techniques from §5. **Each cell value must be unique down its column** (except connective tissue).

**Skeleton catalog** (the "where things sit" layer — vary THIS):
`full-bleed-type` · `full-bleed-dark-scatter` · `centered-device` · `bento-grid` · `split-50/50` · `full-bleed-mosaic` · `horizontal-rail` · `centered-statement` · `tilted-card-float` · `index-color-panels` · `product-pinned-swap` · `editorial-asymmetric`

### Step 3 — Worked example (the Pulse 9-beat deck, the canonical reference)

| # | Beat | SKELETON | SIGNATURE TECHNIQUE | The SURPRISE | TRANSITION OUT | Build |
|---|---|---|---|---|---|---|
| 1 | HOOK | `full-bleed-type` | T3+T4 + a brand ECG line that draws→flatlines→spikes on the key word; an oversized index/section marker (B3) | the flatline-then-spike answering the question visually | line draws down into §2, screen INVERTS to dark | B |
| 2 | PROBLEM | `full-bleed-dark-scatter` | T1 invert + a messy floating collage that drifts and **dissolves** on scroll | light→dark cut; the chaos literally clears | clean wipe back to light, UI rises | B |
| 3 | WEDGE | `centered-device` | device frame rises; real screenshot snaps in; **T13 count-up** Rp0→Rp568.000 | the number counting up live, no "wait for kasir" | soft zoom INTO the dashboard → bento | B |
| 4 | DEMO 1 (analytics) | `bento-grid` | **T7 bento** of live data cards; charts **draw on enter** | the command-center density surfacing the #1 product | bento slides left → split snaps in | B |
| 5 | DEMO 2 (checkout) | `split-50/50` pinned | **the ONE scrollytelling beat** — left taps items, right cart fills → receipt prints | the receipt printing at the end of the scrub | unpin; struk slides up → photo mosaic floods in | B–H |
| 6 | DEMO 3 (menu) | `full-bleed-mosaic` | photo mosaic of real product shots; one card **assembles** then flies into the grid (T9) | the wall of photoreal shots vs spreadsheet POS | mosaic recedes into a rail | B |
| 7 | CAPABILITY | `horizontal-rail` | **T10 sideways rail**, **T8 index-numbered** cards | the lateral motion (breaks vertical rhythm once) | rail ends; camera pulls back to centered statement | B |
| 8 | WHY-NOW | `centered-statement` | **T13 big-number** 64.000.000 counts up + a 3-step path draws | the scale of the number; restraint after busy demos | quiet fade; the §1 line re-enters | B |
| 9 | CTA | `centered-form` | minimal max-contrast; **the §1 ECG line returns as a bookend**, now a steady beat | the callback completing the loop | (end) | B |

### Step 4 — The HERO gets its own playbook (highest-stakes beat)

The hero is beat 1 of the map but earns extra scrutiny — "our hero is too plain" is half of every monotone verdict. **Every studied hero does ONE of: {move in real time · type at architectural scale · cut to a bold color field · frame a live number}.** None is "centered headline + subhead + button on white" — that IS the AI-default hero, banned.

| Option | Direction | Reference DNA | Build |
|---|---|---|---|
| **A ★** | Oversized question/statement type + a **brand line/motif** that draws and reacts | Mana/Chungi type scale + a brand motif | B |
| **B** | A **live number counting up** inside a device frame, framed by huge type | KPR big-number + Wix type (T13) | B |
| **C** | Full-bleed **cinematic product/environment photo** + type overlay + grain, slow push-in | Crescente/KPR (T12) | B |
| **D** | Faint **interactive dot/particle field** that forms a brand shape on mouse move | Lusion-lite (T18) | **H** — only if this is your ONE splurge |
| **E** | Bold flat **color-field** + giant wordmark + inline icons | Crescente (T1+T3) | B |

Pick A/B/C/E for a buildable hero; reserve D for the single H budget (and then spend it nowhere else). Whichever you pick becomes beat 1's row in the map — and the source of the **motif (N6)** that threads later beats.

### Step 5 — Run the Variance Audit (§7). If it fails, fix the map, not the code.

**Connective tissue (applies to ALL sections, doesn't count as a signature):** Lenis momentum scroll + a subtle custom cursor (T15), **oversized index/section markers (B3)** for section marking (NOT timid mono eyebrows — §7 A2), and ONE recurring motif (the ECG line here) threading beats 1 → 3 → 9. **The motif is what makes the variance feel intentional instead of random — N6.**

---

## 7. ★ THE VARIANCE & QUALITY AUDIT — the hard gate (run before building)

**This is the centerpiece. No build starts until this PASSES.** It is the mechanism that makes the monotone failure impossible. Treat it like an L3 sign-off gate: fill the map, score it, and only proceed on a clean PASS. Two layers run here: a binary **Anti-Slop Hard-Ban** scan (any hit = instant fail) and the scored **A–L** checklist.

### ★ Anti-Slop Hard-Bans — instant auto-fail (scan these FIRST)

> Not scored — binary. **ANY hit auto-FAILS the audit** regardless of the A–L scores. Each was paid for by a specific Pulse-deck rejection. Fix before scoring anything else. (These codes A1–A4 are a separate axis from the scored checks A–L below.)

| # | HARD-BAN | The tell it produces | Required instead |
|---|---|---|---|
| **A1** | **Aurora / glow-blobs / blurred-radial gradient orbs / soft gradient haze** as background or hero decor | "immediately looks like AI SLOP" — the hero-v3 aurora was rejected outright | **0** blurred-radial / glow-blob elements. Background richness comes from real photos, structured grids, or geometry — never soft glows. |
| **A2** | **The timid mono micro-label "eyebrow" tell** — small uppercase/mono label-style accent text set as a tiny separate side-label (e.g. "pulse · POS untuk umkm", "tanpa pulse", "pulse jawabannya") | a recurring AI-slop indicator flagged across multiple sections | **0** timid micro-label eyebrows. Accent text is integrated confidently (oversized / italic / color-accented IN the headline) or becomes an oversized index marker — never a small separate label. |
| **A3** | **AI-default fonts** — Instrument Serif, Plus Jakarta Sans (+ the full N5 / frontend-design §8 banned list) | reads as "basic" | Confident pairings only (Fraunces × Switzer × IBM Plex Mono is a proven default). |
| **A4** | **AI-generated photo-realistic backgrounds** | high slop risk | Hero/section photographic backgrounds are REAL + licensed (owned, or CC/Unsplash with attribution) — never AI-generated. |

### The scored checklist

| # | Check | Metric | PASS condition | FAIL action |
|---|---|---|---|---|
| A | **Skeleton uniqueness** | `distinct_skeletons / total_sections` | **= 1.00** (every section a different skeleton) | Two+ sections share a skeleton → redesign the repeats with a different skeleton from the catalog |
| B | **Technique uniqueness** | `distinct_signature_techniques / total_sections` | **= 1.00** (no technique carries two sections) | A technique repeats → swap one section to a different T# |
| C | **Scrollytelling cap (by DISTINCT technique)** | count of pinned scroll-scrubbed sections sharing the SAME technique | **≤ 1 per distinct technique** (a text-line-illumination scrub and a screenshot scrub are DIFFERENT techniques — both may coexist); never the spine | Two sections share the SAME scrollytelling technique → convert the extra to a scroll-*triggered* entrance or a different motion model |
| D | **Heavy-effect cap** | count of WebGL/canvas/3D sections | **≤ 1** | ≥ 2 → keep the strongest as the splurge, rebuild the others from the B tier |
| E | **Designed transitions** | `sections_with_a_designed_transition_out / (total − 1)` | **≥ 0.80** (interior boundaries are events, not cuts) | Hard cuts → design a color-invert / mask-wipe / panel-reveal / camera-push for each |
| F | **Motif through-line** | longest motif chain (sections sharing one recurring motif) | **≥ 3 sections** | No motif spanning ≥ 3 → introduce one (a brand line, a color callback, a repeated mark) and thread it |
| G | **No banned defaults** | frontend-design §8 scan + N5 fonts | **0 violations** | Any banned font/color/layout/badge → replace per frontend-design §8 |
| H | **Type-size variance** (B1) | ratio of largest display type to body | **large + intentional** — giant display words / oversized index markers vs small body; never uniform | Uniform/timid sizing → introduce dramatic, unpredictable scale (architectural display + oversized markers). Refs: crescentesicily.com, chungiyoo.com |
| I | **Confident type moments** (B2/B3) | oversized/abstract/overlapping type per major section + section markers are oversized index numbers | **≥ 1 abstract type moment per major section; markers oversized, not timid labels** | A timid label or no abstract moment → make the accent oversized-in-headline; replace labels with big 01 / 02 / 03 |
| J | **Eased motion, no snap** (C1/C2/C3/C4) | hard-cut/blink transitions · discrete `text-align` flips · un-layered crosses · **pinned sections that flash a neighbour-sliver on fast scroll** | **0 hard cuts; alignment driven by a transform tween (not `text-align`); cross/overlap layers have explicit z-index with image LEADING; pinned sections pinned via CSS `position:sticky` (NOT GSAP `pin:true`), tested on FAST/flick scroll** | Any blink / text-align flip / default paint order / GSAP-pin sliver-flash → ease the slide, tween translateX through center, set intentional z-index, convert GSAP pin → CSS sticky (see C4 addendum) |
| K | **Rich hero from frame one** (D1/D2/D3) | the hero's first ~2s | **layered visual content from frame one** — a real bg + a choreographed multi-beat entrance (focus-pull / Ken-Burns / word-ignite); reduced-motion fallback = the rich static end-state; a photo hero is real+licensed+scrim | A near-empty opening (a lone line on a blank stage reads as "nothing happening", not suspense) → add a real bg + layered elements + a designed entrance |
| L | **Section variance extras** (E1/E2) | scrollytelling counted by distinct technique (see C) + demo/content sections alternate L↔R | **distinct-technique counting honored; L↔R alternation where it fits** | Same-technique scrollytelling repeated → vary or cut; static one-sided demos → alternate image/text sides |
| M | **Display-type containment** (C5) | largest display type (giant count-up numbers, architectural headers) vs its container width across 320–1920px | **0 off-screen overflow — big display type lives in a `w-full text-center` block + the `clamp()` keeps it ≲85% of content width at every breakpoint (fits + centered, never edge-kissing), esp. mobile** | A huge `clamp()` font inside a narrow `max-width` box renders wider than the box → left-anchors + overflows right off-screen → wrap in `w-full text-center` and tighten the `clamp()` max so it fits |

### Motion & type addenda (C4 / C5) — the specific structural rules behind checks J & M

> Two hard-won, easy-to-reintroduce bugs. Both reproduce only at the edges (fast scroll / narrow viewport), so they survive slow-scroll QA — test the edge explicitly.

- **C4 — Pin via CSS `position: sticky`, NEVER GSAP `pin: true`.** GSAP pin swaps the element to `position: fixed` at the boundary; on a FAST/flick scroll (large per-frame delta) that swap lands ~1 frame late, so a ~100–150px sliver of the adjacent section flashes ("blink"). `anticipatePin` only nudges the engage point earlier — it does **NOT** fix the late fixed-swap (shipped as a "v2" and it still blinked). Fix structurally: pin via CSS `position: sticky` (`top:0`, tall outer wrapper for the scroll distance), keep ScrollTrigger for the **scrub only** (no GSAP pin) — CSS sticky is composited every frame so it structurally can't flash. Belt-and-suspenders: give the pinned section an **opaque full-viewport background** so even a 1-frame mismatch can't show the neighbour through. **Always test pinned sections with FAST/flick scroll, both directions — slow scroll hides this.**
- **C5 — Large display type must be CONTAINED + centered, never overflow.** A huge `clamp()` font (e.g. a giant count-up number, an architectural header) placed inside a narrow `max-width` box renders far wider than the box, so it left-anchors and overflows off the right edge — worst on mobile. Rule: put big display type in a `w-full text-center` block and clamp the font so it stays ≲85% of the content width across 320–1920px (fits + centered, never edge-kissing). Verify at 320px, not just desktop.

### The gate

> **PASS = zero Anti-Slop Hard-Ban (A1–A4) hits, AND A and B exactly 1.00, C ≤ 1 per distinct technique, D ≤ 1, E ≥ 0.80, F ≥ 3, G = 0, H–M all satisfied.** Anything else = **NOT cleared to build.** Fix the Variance Map (and any hard-ban hits) and re-run. Do NOT "push through" a failing audit — that is exactly what produced the two Pulse rejections.

### Worked audit (the §6 map above)

```
Hard-bans:    no aurora/glow-blob · no timid mono micro-eyebrow ·
              no AI-default fonts · no AI-generated photo bg                  → 0 hits ✅
Sections: 9
A skeletons:  full-bleed-type · dark-scatter · centered-device · bento · split-pinned ·
              mosaic · horizontal-rail · centered-statement · centered-form  → 9/9 = 1.00 ✅
B techniques: type+line · invert+dissolve · device+countup · bento-charts · scrub-trail ·
              mosaic+assembly · rail+index · big-number · bookend            → 9/9 = 1.00 ✅
C scrollytelling: 1 distinct technique (Beat-5 checkout scrub)               → ≤ 1 ✅
D heavy effects:  ≤ 1 (the Beat-5 scrub OR a hero line splurge, not both)    → ≤ 1 ✅
E transitions:    8/8 interior boundaries designed                          → 1.00 ✅
F motif:          ECG line threads beats 1 → 3 → 9                           → 3 ✅
G banned:         0                                                          → ✅
H size-variance:  architectural display (~300px) vs ~16px body              → large ✅
I type moments:   oversized index markers + ≥1 abstract moment per section   → ✅
J motion:         eased slides; alignment tweened; image leads (z-index);
                  Beat-5 pinned via CSS sticky (not GSAP pin), flick-tested  → 0 snaps ✅
K hero:           rich frame-one (real photo + focus-pull/Ken-Burns/ignite)  → ✅
L extras:         distinct-technique scrollytelling; demos alternate L↔R     → ✅
M type-contain:   Beat-3/Beat-8 count-ups in w-full text-center, clamp fits
                  ≲85% width at 320–1920px → no off-screen overflow          → ✅
VERDICT: PASS — cleared to build.
```

Emit this block (filled for the actual page) as the first build artifact. It is the proof the design is varied before a line of code exists.

---

## 8. TYPOGRAPHY SYSTEM (distinctive, not default)

The single highest-leverage upgrade. Mechanics live in frontend-design §3; the **system shape** is here.

### The formula (always three layers)

1. **One strong DISPLAY face at architectural scale** does the heavy lifting (Mana 334px, Chungi 587px, Wix 158px). Scale + restraint, not decoration. Tight tracking on big type (−1.5 to −3px at display sizes). **Contain it:** architectural-scale type (and giant count-up numbers) goes in a `w-full text-center` block with a `clamp()` whose max keeps it ≲85% of content width at every breakpoint — a huge font in a narrow `max-width` box overflows off-screen (worst on mobile). Audited at §7 check M (C5).
2. **A NEUTRAL workhorse BODY** that stays invisible and legible (the display has personality; the body has none).
3. **An oversized index / section-marker layer** — big "01 / 02 / 03" markers replace timid section labels. The cheap small mono "eyebrow" reads as an AI-slop tell now (§7 A2, hard-banned); a mono label is allowed ONLY when confident and integrated (sized up, color-accented, part of the composition), NEVER as a tiny separate tracked-out eyebrow on every header.
4. Used once, not everywhere: **one script or flourish** for a single human touch (optional).

**Size variance is itself a primary engagement lever (B1):** the ratio between the biggest display type / oversized markers and the small body must be dramatic and unpredictable — never uniform, timid sizing. "the unpredictable font sizing is one of the key to engaging user experience." Refs: crescentesicily.com, chungiyoo.com. The audit scores this (§7 check H).

### BANNED defaults (these ARE the monotone verdict in type form)

| Banned | Why | Use instead |
|---|---|---|
| **Instrument Serif** | THE default "free editorial serif" on every AI landing page | Fraunces, Voyage, a real contrast-serif |
| **Plus Jakarta Sans** | THE generic startup sans (the regressed Prometheus site literally uses it) | Switzer, Satoshi, General Sans, Hanken Grotesk |
| **Inter / Inter-only / Roboto / Arial / Open Sans / Montserrat / Poppins** | frontend-design §8 banned-fonts list, in full force | any pairing below |

### Recommended pairings (open-license, basic-Latin, NOT default)

| # | Display | Body | Marker / mono accent | Personality | Where |
|---|---|---|---|---|---|
| **1 ★ Warm-editorial** | **Fraunces** (variable optical serif) | **Switzer** / Inter Tight | **IBM Plex Mono** | Warm, characterful, premium, best all-rounder | Google / Fontshare |
| **2 Confident-modern** | **Clash Display** (geometric display) | **Satoshi** / General Sans | **JetBrains Mono** | Modern, assured, great for data/analytics | Fontshare (free) |
| **3 Bold F&B poster** | **Gasoek One** / Hatton | **Hanken Grotesk** / Barlow | inline icons + mono | Friendly coffeeshop-poster energy (Crescente) | Google / open |
| **4 Premium-grotesque** | **General Sans** (open Aeonik-alt) | same family | **IBM Plex Mono** | Lusion energy: one grotesque + mono, data-forward | Fontshare (free) |
| **5 Characterful-neutral** | **Bricolage Grotesque** (display weights) | **Geist** / Inter Tight | Geist Mono | Distinctive yet safe; quirk without loudness | Google (free) |

**Default lead:** pairing **1 (Fraunces × Switzer + IBM Plex Mono accents)** for warm/premium, or **2 (Clash Display × Satoshi)** for bolder/modern. **Use the mono face for oversized index markers + confident integrated accents — NOT a timid tracked-out eyebrow on every header (§7 A2).**

---

## 9. PERFORMANCE BUDGET (wow without dying on a cheap Android)

Award sites are desktop-first and **gate their heavy parts.** Mirror that. Mechanics in frontend-design §6/§9; the budget RULES are here.

| Rule | How the refs do it | Apply |
|---|---|---|
| **≤ 1 heavy canvas on the whole page** | every WebGL site ships ONE scene | One splurge effect total (N4). Everything else = CSS + SVG + GSAP/Framer. |
| **Effects = progressive enhancement** | — | **Scroll must hit 60fps with effects OFF.** Build the static page first; layer effects on top. |
| **Preloader masks WebGL warm-up** | Pioneer "93% loading your experience" | If you ship the H effect, hide its init behind a 1–2s branded loader. |
| **Lazy-load below-fold heavy parts** | all WebGL sites defer scenes | Only the hero effect loads eagerly; charts/3D mount on `IntersectionObserver` near-enter. |
| **`prefers-reduced-motion` fallback** | standard on award sites | Serve static images + simple fades; no scrub, no parallax. Respect it FULLY (frontend-design §9 — half-measures = guaranteed bug). |
| **Coarse-pointer / small-viewport downgrade** | heavy canvas is desktop-only | On mobile / cheap Android: swap canvas + scrub for static images + CSS fades. |
| **GPU-cheap motion only** | transforms/opacity, not layout | Animate `transform`/`opacity` only; Lenis for scroll; cap canvas DPR to 1–1.5; pause `rAF` offscreen. |
| **Asset discipline** | — | Real screenshots → WebP/AVIF, responsive `sizes`, lazy. Compress hero photo sets hard. |

**Pre-ship perf gate** (inherit pitch-deck thresholds where it applies): LCP ≤ 1.2s, CLS ≤ 0.1, JS ≤ 300KB compressed, 60fps scroll on a throttled mid-tier Android **with effects off**. Below that → not done.

---

## 10. FEASIBILITY TIERS (aim the build right)

| Tier | Techniques | Verdict |
|---|---|---|
| **Buildable — ~80% caliber** (build ~90% of the page here) | T1, T2, T3, T4, T5, T7, T8, T9, T10, T13, T14, T15, T16, T17, T20, T21, T22 | **YES.** Stack: Next.js + GSAP/ScrollTrigger + Lenis + Framer Motion + SVG. Variance, not WebGL, does the work. |
| **Hard — budget exactly ONE** | T6 glitch-canvas, T11 one 3D product turntable (pre-render or GLB), T18 one particle/dot hero (r3f + simple shader) | Pick ONE as the signature wow. Recommended: a hero particle/line effect OR a richer checkout scrub. **Not both.** |
| **Elite — do NOT attempt** | T19 continuous scroll-driven 3D world morph, T18-full physics hero | **Skip.** Needs a creative-dev team + weeks. Faking at 40% looks worse than a clean buildable section. |

**Targeting rule:** 90% from Buildable, the entire hard budget on ONE hero-grade effect, never the Elite tier.

---

## 11. GROUNDING — design from references, not from "engaging"

**N8 is a hard rule, not a vibe.** Before building each section you must be able to say: *"this section's skeleton is `X`, its signature technique is `T#`, modeled on `<reference site>`."* If you can't name the technique and a reference, you are improvising the model's idea of "engaging" — which is exactly what produces slop.

- **Study the reference sites FIRST (F1)** — open and read them (qutebrowser / `/agent-browser`, or Playwright) BEFORE reworking a design; don't guess from memory. hyperframe / crescente / chungiyoo were studied before the first pass, which is why it landed.
- Carry the reference set (§12 / `references/`). Study the montage for the technique you're about to build.
- When in doubt or the brief is novel, **capture 2–3 fresh references** (Awwwards / Godly / the live site) with `/agent-browser` before designing — don't invent.
- The Variance Map (§6) IS the grounding artifact: every row names a technique + a reference. A row with no named technique fails the audit (check G + N8).

---

## 12. REFERENCE LIBRARY (the 12 studied sites + what each teaches)

Grounded in a ref-study of 12 award-caliber sites (real fonts read from the DOM, screenshots captured headless). Curated montages ship in `references/`; the full set + per-site notes live in `~/claude/notes/pulse-pitch-deck-2026-06-20/ref-study/`.

| Site | Domain | What it teaches | Tier |
|---|---|---|---|
| **Crescente** ★ | Sicilian street food | **The best buildable F&B blueprint.** Flat color-field swaps (orange↔cream), rounded-panel reveals (T2), inline-icon headlines, curved sticker-type (T5), 3D-product moments (T11). Closest analog to a warm consumer brand. | B-heavy |
| **Chungi Yoo** ★ | designer portfolio | **Type-as-hero, cheapest variance family.** Color-field swaps (cream/yellow/pink) + serif/script/outline type variety (T3/T4) + floating & tilted cards (T9) + circular arc-text (T5). Mostly CSS/type. | B-heavy |
| **Lusion** | creative-dev studio | **The canonical variance signature** — physics-hero → color-cut → editorial-grid → gallery → kinetic-type+3D-ribbon → framed-3D. Six skeletons, no repeat. Aeonik + Plex Mono eyebrows. | mixed (1 H/E hero) |
| **Synchronized** | digital studio | **Index-numbered case panels on muted color-fields (T8)** + circular type-rings (T5) retired after one use. The "design-studio editorial" template. | B |
| **Mana** | yerba-mate brand | **Product-anchored card swap (T21)** — product pinned while benefit cards swap around it. Flat-illustration collage + 3D product (T22). Warm F&B. | B |
| **Wix Pantone** | Pantone CotY capsule | **Bento texture collage (T7)** + editorial hero (T3) + gradient band, all in ONE monochrome. Sans×classical-serif contrast. Disciplined color story. | B |
| **KPR** | web3 collectible universe | Cinematic game-trailer pacing: logotype negative-space → key-art split (T14) → 3D env (T12) → big-number "10K" (T13) → avatar strip. Custom display + grotesque + mono. | mixed |
| **Noomo XR** | XR agency | **Synthwave perspective grid (T20)** + VCR-mono knockout type (T6-CSS) + circular type-rings + wireframe illustration. Retro-tech, mostly CSS/SVG. | B |
| **Pioneer / RESN** | seed-science | **What NOT to attempt (Elite tier).** ONE continuous scroll-driven 3D world morph (T19, DNA→network→sprout→kernel) + glitch type. Studio-only — a named warning, not a target. | E |
| **Prometheus** | cleantech | **Cautionary.** A once-legendary WebGL site regressed to a generic Elementor + Plus Jakarta Sans page. Even famous brands regress to default. Use as a mood ref only. | — |
| **Awwwards** | the directory | The "polished baseline" end: clean neutral card-grid + hover-video preview (T16). NOT a wow ref — the variance lives in the sites it lists. | B |
| **Mammut Eiger** | (down at capture) | Named precedent only: horizontal/pinned mountain-ascent storytelling (T10). Don't assert specifics. | — |

**Fastest paths by brief:** warm consumer / F&B → **Crescente + Mana**. Editorial / portfolio / type-led → **Chungi + Synchronized + Wix**. Tech / data / dev → **Lusion + Noomo + KPR**. Always cross-check the Variance Map against at least 2 refs.

---

## 13. COMPOSES WITH

| Skill | How /artifex plugs in |
|---|---|
| **/pitch-deck** | `/artifex` **replaces pitch-deck's Stage-6 "Section architecture template"** (which hard-codes the monotone bug: 3× `(pin)` + "DEMO 2: same pattern"). Run pitch-deck Stages 1–5 (intake → narrative outline) as-is; at Stage 6, feed the narrative beats into the **Variance Method (§6)** and clear the **Variance Audit (§7)** before building. The audit becomes pitch-deck's pre-build gate. |
| **/oneshot-webapp** | oneshot's house rule is **SAFE presets only / light-only** (recruiter demos). `/artifex` is the **explicit-override path**: invoke it only when Toper says "go immersive / award-caliber" in the brief. Otherwise oneshot stays on `/frontend-design` SAFE mode. When invoked, still honor oneshot's light-only + server-side-secrets + deploy rules — `/artifex` changes the *design method*, not the deploy/secrets discipline. |
| **/frontend-design** | The sibling. `/artifex` borrows its archetype as a BASE palette and inherits all its engineering (§3). The difference: frontend-design applies ONE archetype consistently (SAFE); `/artifex` varies skeleton+technique+transition per section (IMMERSIVE) and gates it with the audit. Use frontend-design for product UI; `/artifex` for the dazzle. |

---

## 14. STACK (opinionated defaults)

| Decision | Default | Notes |
|---|---|---|
| Framework | **Next.js 15 App Router** | RSC by default; `"use client"` only on interactive leaves (frontend-design §13) |
| Scroll engine | **GSAP + ScrollTrigger** | battle-tested scrubbing. Pick ONE engine and stick (mixing = lifecycle bugs). **Pin via CSS `position:sticky`, NOT GSAP `pin:true`** — GSAP pin's fixed-swap blinks on fast scroll (§7 C4). Keep ScrollTrigger for the scrub only. |
| Smooth scroll | **Lenis** | compositor-friendly momentum (T15). Skip if perf testing shows jank on low-end |
| Animation layer | **Framer Motion** | for React-component animations / `layoutId` transitions |
| The ONE splurge | **react-three-fiber + a simple shader** | ONLY if you spend the single H budget on a 3D/particle hero. Else omit entirely. |
| Styling | **Tailwind (check v3 vs v4 first)** + CSS custom properties | frontend-design §13 |
| Component base | **Origin UI** (neutral base) + bespoke WOW sections | frontend-design §0.7 |
| Images | **WebP/AVIF**, Next `<Image>`, lazy below-fold | §9 asset discipline |

**Lock-in rule:** one scroll engine, one base palette, ≤ 1 heavy effect. Variance comes from the *method*, not from piling on libraries.

---

## 15. EXECUTION FLOW

1. **Frame** — confirm this is an `/artifex` job (dazzle, not maintain — §2). Lock the section/beat list, the audience, the base archetype + palette, the theming rule (inherit host skill's: pitch = light-only).
2. **Pick the type system** — a §8 pairing (default Fraunces × Switzer + Plex Mono markers/accents). Confirm none of N5's banned fonts; plan oversized index markers, not timid eyebrows (§7 A2).
3. **Variance-map** — fill the §6 Variance Map: distinct skeleton + technique + transition per section, name a reference per row, pick the ONE H splurge (or zero).
4. **★ Run the Variance Audit (§7)** — score A–G. **PASS or fix the map.** Emit the filled audit block as the first artifact. NO CODE until PASS.
5. **Build static-first** — assemble every section's skeleton + content with effects OFF; confirm 60fps scroll and legibility (N7).
6. **Layer motion + the ONE effect** — apply connective tissue (Lenis + cursor + oversized index/section markers + the motif), then each section's signature technique, then the single splurge behind a loader.
7. **Downgrade paths** — `prefers-reduced-motion` + coarse-pointer/cheap-Android static fallbacks (§9).
8. **Verify (live screenshots + honest self-check at each gate — F2)** — capture live screenshots at the WOW-prototype gate and post-build, and self-check honestly against this audit (this caught real bugs last rebuild: count-up separators, invisible bars, pre-hydration flash). Run the perf gate (§9), the frontend-design §8 + §7 Anti-Slop Hard-Ban scan, re-confirm the audit still holds (no skeleton/technique/hard-ban drift crept in during build), test on a throttled mid Android.
9. **Deliver** — present with the filled Variance Audit block + the per-section technique/reference map as the proof of variance.

> Don't hold back. Award-caliber means committing fully to a distinctive vision — but `/artifex`'s discipline is that the distinctiveness is **engineered and audited**, not improvised. Variance you can prove beats "engaging" you can only assert.
