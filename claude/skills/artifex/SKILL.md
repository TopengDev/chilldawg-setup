---
name: artifex
description: Hand it a website / page / multi-section brief → it produces an ultra-engaging, award-caliber, VARIANCE-FIRST design (cinematic, immersive, distinctive), the deliberate opposite of generic/monotone/AI-default. The high-variance/immersive counterpart to /frontend-design (NOT a replacement). Use when Toper says /artifex, or asks to make something "award-caliber / cinematic / immersive / ultra-engaging / not basic / not monotone / wow", redesigns a deck/landing that got called "flat / template / same thing repeated", or wants a pitch/demo site that has to stand out. Do NOT use on a recruiter/client-facing ONE-SHOT pitch demo (/oneshot-webapp territory) unless Toper explicitly overrides ("go immersive" / "award-caliber" / names /artifex), those default to /frontend-design SAFE presets (see N0).
---

# /artifex: variance-first, award-caliber web design

> **frontend-design picks ONE archetype and applies it cleanly across a page. /artifex sequences DIFFERENT treatments per section.** One is coherence-via-sameness (safe, production). The other is richness-via-variance (immersive, award-bait). This skill encodes the craft that makes the second possible so it can't collapse back into the first.

`/artifex` is `/frontend-design`'s immersive sibling. It **inherits** frontend-design's full engineering and craft base: read `~/.claude/skills/frontend-design/SKILL.md` in full and treat all of it as artifex's baseline. Key anchors include typography mechanics (§3), color craft (§3.5), the quality bar and operating mindset (§0.8), motion mechanics and the enforced interactive-3D default (§5, §5.5), the anti-slop bans (§8), mobile resilience (§9), and the component-library map (§0.7). It does **not** re-document them; read them there. What `/artifex` adds is the layer frontend-design has no mechanism for: **forced design variance, an immersion technique vocabulary, a section-by-section variance method, and a hard audit gate that refuses a monotone build.**

---

## ⛔ NON-NEGOTIABLE RULES: READ FIRST, THESE OVERRIDE EVERYTHING BELOW

| # | Rule | Enforcement |
|---|---|---|
| **N0** | **BOUNDARY: NEVER run /artifex on a recruiter/client-facing ONE-SHOT pitch/demo webapp (/oneshot-webapp territory) without Christopher's explicit override.** Those builds are frontend-design SAFE presets, light-only; the house rule BANS VARIANCE ≥ 7 and high-variance directions there, and every artifex build is VARIANCE 8-10 by definition. The ONLY valid overrides: the brief says "go immersive" or "award-caliber", or names `/artifex` explicitly. "Make it impressive for the recruiter" is NOT an override. A `/pitch-deck`-hosted build and Christopher invoking `/artifex` directly (e.g. on his own portfolio) ARE overrides by definition. | §7 audit header: the mandatory `Surface` + `Override` lines. `Surface: one-shot-demo` with `Override: n/a` auto-FAILS the audit with the routing instruction (use /frontend-design SAFE). Named failure: 2026-05-29 Selaras art-deco recruiter demo, rejected as "looked SO BAD". |
| **N1** | **DISTINCT skeleton per section.** No two sections share a layout skeleton. Repeated content (demo 1 / demo 2 / demo 3) must NOT share a layout. | The Variance Audit (§7) fails the build if any skeleton repeats. |
| **N2** | **DISTINCT signature technique per section, then RETIRE it.** A technique carries exactly ONE section, never the next. | Variance Audit fails if any technique repeats. |
| **N3** | **Scrollytelling counted by DISTINCT technique, each distinct pinned scroll-scrubbed technique appears ≤ 1 time** (a text-illumination scrub and a screenshot scrub are DIFFERENT techniques, so both may coexist). It is never the spine. | Variance Audit (§7 check C) fails if the SAME scrollytelling technique carries two sections. |
| **N4** | **≤ 1 heavy effect (WebGL/canvas/3D) on the entire page.** Build ~90% from the Buildable tier; spend the whole hard budget on exactly ONE signature wow; never touch the Elite tier. | Performance Budget (§9) + Feasibility (§10). Audit fails if heavy-effect count ≥ 2. |
| **N5** | **Distinctive DISPLAY + neutral BODY + oversized index/section markers.** Section marking is done with oversized index markers (big 01 / 02 / 03) and tracked-uppercase small-caps in the body sans, NOT a mono face: mono is allowed only in DD-1's three carve-outs (the Terminal/Monospace archetype, a literal code surface, a literal hash/address motif, see §8; frontend-design §3.1 / §11 DD-1), it is NEVER a labeling tool on any other archetype. The timid mono micro-label "eyebrow" tell is additionally hard-banned (§7 HB-2). BAN the AI-defaults (Instrument Serif, Plus Jakarta Sans, Inter-only, Roboto). | Typography System (§8) + §7 Hard-Ban HB-2 + inherits frontend-design §8 Banned Fonts + DD-1. |
| **N6** | **A recurring MOTIF threads ≥ 3 sections.** Variance without a through-line reads as random, not designed. The motif (a brand line, a color callback, a repeated mark) is what licenses the variance. | Variance Audit checks for ≥ 1 motif spanning ≥ 3 sections. |
| **N7** | **Effects are progressive enhancement + reduced-motion is the SAFETY-VALVE, never a full strip.** Scroll must hit 60fps with ALL effects OFF. artifex surfaces are landing-class, so they do NOT auto-reduce the whole show under `prefers-reduced-motion`: apply ONLY the vestibular safety-valve (swap large-travel motion, i.e. parallax / scroll-jack / scrubbed scenes, for quick fades; KEEP stagger, reveals, micro-interactions, and the signature moment), per the frontend-design §6 Reduced Motion surface split + §0.9 + gate LM-6. A global `*` reduce that flattens the landing is a violation (it also silently kills the show for OEM-reduced-motion Androids). The T24 panel-deck gates fully OFF under reduced-motion AND `(pointer: coarse)` (free native scroll); the T23 intro respects reduced-motion by skipping straight to its handoff. SEPARATE rule (device budget, not reduced-motion): coarse-pointer / cheap-Android downgrades the heavy canvas to static. | Performance Budget (§9) + the §15 self-verification gate's reduced-motion pass. |
| **N8** | **Design from the technique library + studied references, NOT from the model's idea of "engaging."** Carry the reference set; name the technique and the ref before building each section, and OPEN the named reference montage with the Read tool (the actual image) during THIS session before building that section. "I remember what lusion looks like" is a violation, model memory of a site is not grounding. | Grounding (§11) + §7 check G (fails any Variance Map row whose montage was not Read this session). "I'll make it engaging" with no named technique = a violation. |
| **N9** | **Immersive builds open with a DESIGNED intro beat**, not a bare spinner or a WebGL-mask-only loader. A FULL-IMMERSIVE build, defined by SHAPE, not the dial (every artifex build runs VARIANCE 8-10, so the dial cannot be the trigger: the Frame step, §15 step 1, declares `Surface: standalone-immersive` OR chooses a T24 panel-deck spine), sets its tone in the first frame: a designed loading panel (a manifesto/headline reveal + a tabular count-up or progress hairline + the page motif) that hands off to the hero with a CHOREOGRAPHED transition, the panel clears AS the hero entrance is released, so they read as one continuous motion. Respects reduced-motion (skip straight to the handoff). The intro is page-chrome, not a variance-map row. | §7 audit check O (conditional, full-immersive only) + §15 execution flow. Engineering primitive in frontend-design §9.5.4. |
| **N10** | **Shader-class visuals default to PAPER SHADERS, the MUST-USE first reach.** When the design calls for a shader-driven background, ambient field, hero texture, generative gradient/texture layer, or a DD-3 scrollytelling background, reach for **`@paper-design/shaders-react`** (§5.1) BEFORE hand-rolled GLSL and BEFORE a three.js/r3f scene. Hand-rolled/r3f earns the slot ONLY via the §5.1 carve-outs (real 3D geometry/depth, cursor-reactive physics/brand-shape formation, scroll-scrubbed scene state). This changes the ENGINE, never the budget: a mounted Paper Shaders canvas IS the page's one heavy canvas under N4, and a default-preset MeshGradient slapped on a hero is still slop: every instance carries the locked archetype palette + a named composition intent (§5.1 anti-slop clauses; HB-1 is judged on the rendered output, engine irrelevant). | §5.1 (engine rule + carve-outs + anti-slop wiring) + §14 stack rows + §7 check D counts the canvas + the §15 part-2 preset scan. |

### The failure this skill exists to prevent (verified, twice)

A Pulse pitch deck was rejected **twice** as *"MONOTONE / basic."* Root cause, diagnosed:

| What was built | Why it read monotone |
|---|---|
| Sections 1-3 (Hook, Problem, Wedge) all "pinned type reveal" | **same skeleton ×3** |
| Demos 4-6 all "scroll-scrubbed screenshot trail" | **same technique ×3** |
| Net: ONE technique (scrollytelling) × 9 sections | = monotone. Blurred background circles were gloss-on-sameness, not variance. |

The fix was never "more polish." It was **9 different sections.** `frontend-design` produces safe, clean, production output with nothing forcing variance, so on a deck that needs to *dazzle*, it defaults to one good idea repeated. `/artifex` makes that repeat **mechanically impossible** via the audit gate.

> Historical note: pitch-deck's Stage 6 originally hard-coded this bug as a fixed "Section architecture template" (`HOOK (pin) / PROBLEM (pin) / SOLUTION (pin)` then `DEMO 1 (scrub) / DEMO 2 (scrub), "Same pattern, different hero story"`). That template is GONE: Stage 6 was rewired and now invokes `/artifex` directly ("Section architecture, invoke /artifex (variance-first)"), feeding the approved Stage-5 beats into the variance method (§6) and clearing the audit (§7) before building. Treat the old template as the named historical failure this skill was built from, NOT as current pitch-deck state. See COMPOSES WITH (§13).

---

## 1. THE PRINCIPLE

> **Award sites are not "polished" versions of the same page. They are a sequence of DIFFERENT pages.** Richness comes from VARIANCE, not from gloss on sameness.

Three rules every studied award site obeys:

| Rule | What it means | Proof (from the reference set, §12) |
|---|---|---|
| **Distinct skeleton per section** | Every section changes WHERE things sit, full-bleed / split / bento / horizontal rail / centered statement / tilted card. No two adjacent sections share a layout. | Lusion: physics-hero → red full-bleed showreel → editorial card grid → gallery → centered-type → split. Six sections, six skeletons. |
| **One signature technique per section, then retire it** | Each section owns ONE move (a 3D scene, a color-cut, a type-ring, a scrub). It never carries the next section too. | Synchronized: circular text-rings for services, then never again, switches to index-numbered color-field case panels. |
| **Transitions are designed moments** | The handoff between sections is itself an event: a color invert, a mask wipe, a camera morph, a rounded panel sliding up. Not a hard cut to "next screenshot." | Crescente slides a cream rounded panel up over orange. Pioneer morphs ONE 3D world from DNA-helix to seed-sprout as you scroll. |

**The cohesion paradox (why variance doesn't read as chaos):** the studied sites vary the SKELETON + TECHNIQUE + TRANSITION per section, but hold **ONE base system constant**, one type pairing, one color discipline, one recurring motif. Lusion is six different skeletons but ONE grotesque + ONE consistent label treatment + ONE color logic (Lusion happened to use a mono eyebrow; on our builds that label layer is body-sans small-caps + oversized index numbers, NOT mono, which is Terminal/Monospace-archetype-only per DD-1). **Variance lives in layout & motion; coherence lives in type, color, and the motif.** Vary the wrong axis (brand, palette, font per section) and you get a ransom note. Vary the right axis and you get an award site.

---

## 2. WHEN TO USE /artifex vs /frontend-design

| | **/frontend-design (SAFE mode)** | **/artifex (IMMERSIVE mode)** |
|---|---|---|
| **Method** | Pick ONE archetype, apply consistently across the page | Pick ONE base palette, VARY skeleton + technique + transition per section |
| **Coherence from** | Sameness (one layout language) | A motif + constant type/color, over deliberate variance |
| **Default dials** | VARIANCE 4-10, MOTION 2-9 per archetype (§1 defaults span Corporate Confident V4/M3 up to Gen Z V10/M9), but ONE archetype applied uniformly across the page | **VARIANCE 8-10, MOTION 6-9, floored**, varied per section, the variance dial is bolted to the top. The real difference is METHOD (uniform archetype vs per-section variance), not a cap. NOTE: VARIANCE ≥ 7 is the one-shot-demo ban threshold, so EVERY artifex build is banned on a recruiter one-shot without the explicit override (N0) |
| **Best for** | Production apps, dashboards, the Aenoxa product (needs i18n + dark mode), client sites that must be maintainable | Pitch decks, demos, launch/award sites, hero landing moments, "make it not basic" |
| **Risk it fails on** | Looks generic / template when the brief needed to dazzle | Over-engineered / janky / inaccessible if the gates (§7, §9) aren't enforced |
| **Theming** | i18n + light/dark mandatory (Aenoxa ecosystem) | Decide the regime at Frame time (§15 step 1). STANDALONE artifex build of an Aenoxa-ecosystem property (e.g. a Pulse landing) → id-default + en i18n AND polished light+dark from commit 0 (the CLAUDE.md Website Build Defaults mandate; missing exactly these compounded the 2026-05-24 rejection into "unsalvageable"). Pitch/demo under a host skill → inherit the host rule (pitch decks = light-only) |

**Bright-line:** if the deliverable's #1 job is to **make someone feel something and act** (invest / adopt / "wow") → `/artifex`. If its #1 job is to **work reliably and be maintained** (product UI, admin, docs) → `/frontend-design`. When a brief says "award-caliber / cinematic / immersive / ultra-engaging / not basic" → `/artifex`, full stop. **"Hire"-audience work is the ONE scoped case (N0):** a recruiter/client-facing ONE-SHOT pitch demo routes to `/frontend-design` SAFE unless Christopher's explicit override is on record; Christopher's OWN portfolio on his explicit invocation is legitimate artifex work (it is the second canonical worked example, §6).

`/artifex` still **uses an archetype** from frontend-design §2 as its BASE (color/type/mood). It just refuses to let that archetype flatten into one repeated skeleton.

---

## 3. THE ENGINEERING YOU INHERIT (do not re-derive)

`/artifex` does not restate frontend-design's mechanics. **Read `~/.claude/skills/frontend-design/SKILL.md` IN FULL and treat ALL of it as artifex's engineering and craft base. Apply all of it.** The table below is a guide to where the key pieces live, NOT a boundary on what to inherit. If it is in frontend-design, it applies here.

### PRECEDENCE: artifex hard rules WIN over inherited baseline guidance

**When inherited frontend-design guidance conflicts with an artifex NON-NEGOTIABLE (N0-N10) or a §7 Hard-Ban (HB-1..HB-6), artifex WINS. NEVER source a pattern from the baseline that an artifex ban names**, "the baseline recommends it" is not a defense at the audit. frontend-design is a general-purpose skill; artifex bans several patterns the baseline still recommends. Known live conflicts (keep this table current when either skill changes):

| frontend-design says | artifex says | Winner |
|---|---|---|
| §4 "Eyebrow Tags": small marker labels above major headings | The timid micro-label eyebrow is the HB-2 instant-auto-fail tell; section marking is oversized index numbers + small-caps (T17) | **artifex (HB-2)** |
| §3 Font Pairing Strategy lists "Instrument Serif + Instrument Sans (modern)" | Instrument Serif is hard-banned (HB-3 / N5) | **artifex (HB-3)** |
| §2 archetype specs list Plus Jakarta Sans (Soft Structuralism, Playful Pop, Gen Z rows) | Plus Jakarta Sans is hard-banned (HB-3 / N5) even when the BASE archetype's own spec suggests it; substitute per §8 (Switzer / Satoshi / General Sans / Hanken Grotesk) | **artifex (HB-3)** |

Do NOT invert this clause into re-bans of things frontend-design deliberately allows: **Lenis stays ALLOWED and default** (its old ban was REVERSED; the 2026-04 root cause was the IntersectionObserver dependency, so pair Lenis with `useOnScreen` per frontend-design §9.5.2, never re-ban Lenis), and **reduced-motion stays the SURFACE-SPLIT safety-valve** (N7), never a blanket full-strip.

| Need | Where in frontend-design |
|---|---|
| Archetype palettes (the BASE for your page) | §2 Vibe Archetypes |
| Type mechanics (tracking, modular scale, variable-font axes) | §3 |
| Color craft (temperature, OKLCH, gradients, blend modes) | §3.5 DESIGN ENGINEERING - Color |
| Surface/layout primitives (bezel cards, optical alignment; §4's "Eyebrow Tags" pattern is OVERRIDDEN here, see PRECEDENCE above + HB-2) | §4 |
| Motion mechanics (interruptible vs keyframe, magnetic hover, cursor patterns, scroll entry) | §5 |
| Interactive 3D and motion enforced default, one signature 3D moment, guardrails | §5.5 INTERACTIVE 3D & MOTION, The Enforced Default (the Disciplined Ladder) |
| Scrollytelling patterns + Lenis integration (you'll use ONE of these) | §7 |
| **Anti-slop banned fonts/colors/layouts/content/icons** | §8, fully in force here |
| Mobile animation resilience (`useOnScreen`, IO fallbacks, reduced-motion) | §9 |
| Component-library map (Origin UI base + archetype primary) | §0.7 |
| Quality bar operating mindset (range before depth, push to 10, less but better) | §0.8 CRITICAL META-RULE - The Quality Bar (how to think, before how to build) |
| Architecture rules (RSC boundaries, dep verification, Tailwind v3/v4) | §13 |

If something is covered there, USE it there. The sections below are the layer frontend-design lacks.

frontend-design §5.5 establishes an enforced interactive-3D/motion default with a Tier-1 baseline floor (real depth, purposeful motion, per-element feedback), a Tier-2 signature moment (one interactive 3D centerpiece per page, default aim), and Tier-3 guardrails (60fps budget, reduced-motion as a dial, lazy-load). artifex inherits §5.5 in full as part of its baseline. artifex's own N4 (one heavy effect, one signature wow) and N7 (60fps with effects off, prefers-reduced-motion downgrade) are consistent with and enforce §5.5's guardrails, so they reinforce each other rather than conflict. The §7 Variance Audit check D (heavy-effect cap) is the artifact-level gate for this.

---

## 4. NON-NEGOTIABLES (the enforced craft, expanded)

| Rule | Enforcement mechanism | FAIL looks like |
|---|---|---|
| **DESIGN VARIANCE** | The Variance Audit (§7), a mandatory pre-build gate. List every section's skeleton + technique + transition; assert all skeletons distinct, all techniques distinct, scrollytelling ≤ 1, heavy-effects ≤ 1, ≥ 1 motif over ≥ 3 sections. | Two sections share a layout; one technique carries three sections. |
| **TECHNIQUE PALETTE** | Design only from the 25-technique library (§5), each tagged **B / H / E**. Build ~90% from **B**, spend the entire hard budget on exactly ONE **H**, never touch **E**. | "I'll add a cool particle thing here and another there" (two H, or an E faked at 40%). |
| **PERFORMANCE BUDGET** | §9, ≤ 1 heavy canvas; lazy-load below-fold; `prefers-reduced-motion` + coarse-pointer downgrade; 60fps with effects OFF. | Two WebGL scenes; scroll janks on a mid Android; effects are load-bearing for legibility. |
| **TYPOGRAPHY-NOT-DEFAULT** | §8, distinctive DISPLAY + neutral BODY + oversized index/section markers (the timid mono eyebrow is hard-banned, §7 HB-2); ship a recommended pairing; tight tracking on big type; BAN Instrument Serif / Plus Jakarta Sans / Inter-only / Roboto. | Instrument Serif headline + Plus Jakarta body = the AI-default look = an instant tell. |
| **TYPOGRAPHY FLOORS (Christopher's hard taste rules)** | §8 floors + §7 Hard-Bans HB-5/HB-6 + mechanical scans in the §15 self-verification gate. NEVER render text below `font-weight: 500` anywhere, including BOTH endpoints of a variable-font `wght` animation. NEVER render text below 12px (0.75rem): no `text-[10px]`/`text-[11px]`; delicacy below 12px comes from tracking/spacing/color, never a smaller size. Display numerals FILLED, never outline/stroked. NO decorative circle/status dots anywhere. NO `rounded-full` ALL-CAPS tight-padding badge pills (sharp `rounded-[7px]` small-caps tags instead). | A `font-light` caption; a `text-[10px]` marker; an outlined giant count-up numeral; a glowing "live" dot in the navbar; a pill-badge row under the hero. |
| **ANTI-SLOP** | Inherit frontend-design §8 wholesale (centered-hero→3-cards→CTA, purple gradients, stock heroes, glowing-dot pills, lorem ipsum, filler power-words). | Any banned pattern present. |
| **GROUNDING** | §11, name the technique + the reference for every section BEFORE building. Carry the reference set (§12). | A section justified by "make it engaging" with no named technique/ref. |

---

## 5. THE TECHNIQUE LIBRARY (the design vocabulary: 25 moves)

This is the palette you design FROM. Every section's signature technique is one of these. **Difficulty tags are load-bearing:**

- **B**: Buildable. A strong worker hits ~80% with GSAP/ScrollTrigger + Lenis + Framer Motion + SVG + CSS. **Build ~90% of the page from B.**
- **H**: Hard. Budget as the ONE splurge (react-three-fiber + a simple shader, or a pre-rendered 3D turntable). **Exactly one H per page, or zero.**
- **E**: Elite. Studio-only (creative-dev team + weeks). **Never attempt.** Faking an E at 40% looks worse than a clean B section.

| # | Technique | What it does | Build |
|---|---|---|---|
| T1 | **Full-bleed color-field cut / invert** | Hard cut to a saturated or inverted ground = instant "new chapter" | **B** |
| T2 | **Rounded-panel reveal handoff** | A panel with rounded top slides up over the previous color-field as the transition | **B** |
| T3 | **Oversized editorial display type AS layout** | Type at architectural scale (150-590px) IS the composition. The single biggest "premium" signal | **B** |
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
| T15 | **Momentum (Lenis) smooth scroll** (NO custom cursor) | The whole page feels weighted and bespoke via inertia scroll. NO custom/replaced cursor: frontend-design §8 BANS custom mouse cursors (outdated, ruins performance and accessibility), and that ban WINS. Cursor-reactivity lives in an ELEMENT that reacts to pointer position (for example a hero 3D object, a magnetic button, a proximity-repelled mark per frontend-design §5), never in a replaced system cursor | **B** |
| T16 | **Hover-preview live-site video** | A project tile, once SETTLED in place, lifts a centered + scaled portaled preview after a ~2s hover-INTENT dwell, playing a recorded human-paced walkthrough of the LIVE site (smooth fade-in/out loop); the slot stays the hover hitbox. Thin variant: an in-place muted clip on hover | **B** |
| T17 | **Oversized index markers + small-caps section marking (NO mono)** | Section marking is oversized index numbers (big 01 / 02 / 03, B3) plus tracked-uppercase small-caps in the body sans + tabular figures + hairline rules, NEVER a mono face (mono is Terminal/Monospace-archetype-only, frontend-design §3.1 / §11 DD-1) and NEVER a timid separate eyebrow (that tell is hard-banned, §7 HB-2) | **B** |
| T18 | **Interactive WebGL physics / particle hero** | A real-time simulation you push with cursor/scroll | **H** (one) / **E** (full) |
| T19 | **Continuous scroll-driven 3D world morph** | ONE 3D scene transforms through the entire scroll | **E** |
| T20 | **Synthwave perspective grid + neon** | A receding grid floor + glow = instant retro-tech mood | **B** |
| T21 | **Product-anchored card swap** | The product stays PINNED to the viewport while benefit cards + illustrations swap around it on scroll | **B** |
| T22 | **Flat-illustration collage + 3D/photo product** | Playful illustrations layered with one real product = warm F&B identity | **B** |
| T23 | **Designed intro / loading beat** | A full-bleed branded intro panel (motif + word-by-word headline/manifesto reveal + a tabular count-up or progress hairline) that choreographs its exit INTO the hero entrance (the panel lift and the hero reveal are one motion). Page-chrome, not a section signature. Engineering: frontend-design §9.5.4 handoff primitive | **B** |
| T24 | **Full-viewport panel-deck snap spine** | Every section is `min-h-screen` + a `data-panel` marker; one gesture moves one strongly-eased-out panel; reveals play ON ARRIVAL (not scrub). Page-level connective tissue when chosen, not a section signature. Hard guardrails (gate off on touch + reduced-motion, fail-safe to free scroll, always escapable, keyboard-driven), see the callout below | **B** |
| T25 | **In-panel stepper scrollytelling** | A single 100vh panel that advances INTERNAL state one step per gesture (color dissolve + index crossfade + word re-illumination, or a card-by-card rail) before releasing to the next panel, via a stepper the snap controller delegates to. This is how scrollytelling survives inside T24 | **B** |

**Reading the table:** T15 (Lenis momentum scroll, NO custom cursor) is **connective tissue**, apply it across the whole page; it doesn't count as a section's signature. (T17 is now the oversized-index-marker + small-caps section-marking technique, NO mono, see §7 HB-2 and DD-1; use it for section marking across the page.) T23 (intro beat) is the page's opening and T24 (panel-deck), when chosen, is page-level connective tissue, neither is a per-section signature. Every other technique is a one-section signature. The **B**-heavy rows are your workhorses; T11 / T18 / T6-canvas are your *candidates* for the single H splurge; T19 and T18-full are **E, do not attempt.**

> **Pinning implementation (T10 pinned rail / T21 product-pinned swap / any pinned scroll-scrubbed section):** pin via CSS `position:sticky`, **never GSAP `pin:true`**: GSAP pin's `position:fixed` swap lands ~1 frame late on fast scroll and flashes a neighbour-sliver. Keep ScrollTrigger for the scrub only. Full rule + fix: §7 audit **C4**.

> **Panel-deck guardrails (T24 / T25):** the deck is a controlled scroll-jack, so it inherits frontend-design §7.1's "always provide an escape." Hard requirements: gate it OFF on `(pointer: coarse)` and `prefers-reduced-motion` (free native scroll there), FAIL SAFE to free scroll if it finds fewer than ~3 panels, drive it with arrows / space / pageup-down as well as the wheel, and give every stepper panel a visible progress indicator (dots / rail). Because a 100vh panel has no scrub room, write reveals as on-arrival ENTRANCES (the §9.5.2 useOnScreen primitive or a mount reveal), NEVER as scroll scrubs, a reveal authored as a scrub silently never fires inside a panel. Reference build: the Christopher portfolio panel deck (`SnapScroll.tsx` + `snapBridge.ts`).

---

## 5.1 THE SHADER ENGINE DEFAULT: PAPER SHADERS (MUST-USE first reach, N10)

**When a section's design calls for a shader-class visual (an ambient/animated background field, a hero texture, a generative gradient or texture layer, a DD-3 scrollytelling background), the engine is `@paper-design/shaders-react` (Paper Shaders, shaders.paper.design), BEFORE hand-rolled GLSL and BEFORE a three.js/r3f scene.** A props-driven, design-tool-grade shader beats a hand-rolled one on build cost, review speed, and maintainability every time the catalogue covers the visual. This is an ENGINE rule, not a budget change: with Paper Shaders the shader-class visual becomes BUILD-cheap (any worker can drive props) but stays BUDGET-heavy: the mounted canvas occupies the single N4 heavy-effect slot, animated or static.

### Verified facts (2026-07-02, against npm + the shipped 0.0.76 tarball + github.com/paper-design/shaders)

| Fact | Value |
|---|---|
| Packages | `@paper-design/shaders-react` (peer: `react ^18 \|\| ^19`), wrapping `@paper-design/shaders` (vanilla core, **zero dependencies**; the react package's ONLY dep is the core) |
| Version discipline | `0.0.76` latest. **Pin the exact version**: the repo README warns it "will ship breaking changes under 0.0.x versioning", so pin, never range |
| License | **Fully open source as of 2026-07-02**: the repo LICENSE at main is **Apache-2.0** (the custom PolyForm-Shield no-compete license was dropped; announcement: x.com/stephenhaney/status/2072369858638233843: "now fully open source and FREE... Resell it."). README: usable in commercial end products without visible attribution; preserve LICENSE+NOTICE only when redistributing as a library/tool. NUANCE: the npm 0.0.76 tarball (published 2026-04-15, pre-relicense) still BUNDLES the old PolyForm Shield text; its `license` field points at the GitHub LICENSE, which is now Apache-2.0. Both licenses permit artifex end-product use; check for a post-relicense release when installing |
| Bundle cost | npm `unpackedSize`: react 404 KB + core 814 KB, but that INCLUDES source maps; the real ESM payload is ≈135 KB (react) + ≈250 KB (core) pre-minify/pre-gzip, and `sideEffects: false` + one module per shader means bundlers tree-shake down to only the shaders you import. Fits inside the §9 route-critical caps for a hero field; below-fold instances still lazy-mount per §9 |
| SSR / App Router | The dist ships the `"use client"` directive (verified in `dist/index.js`), so importing into App Router code creates the client boundary automatically; the component SSRs its container div and the canvas paints AFTER hydration; give the wrapper an in-palette CSS background so frame one is never a void (check K, no pre-hydration flash) |
| Runtime | `speed={0}` **stops rAF entirely**: "static shaders have no recurring performance costs" (verified in `shader-mount.js` source); hidden tabs auto-pause (`visibilitychange` handler); resolution knobs: `minPixelRatio` (default 2) and `maxPixelCount` (default 1920×1080×4) |

### The carve-outs: when custom GLSL / r3f is still justified (the ONLY three)

| The visual needs | Then |
|---|---|
| Real 3D geometry / depth: a product turntable (T11), a GLB, camera moves | r3f/three.js earns the N4 slot |
| Cursor-reactive physics or brand-shape particle formation (T18, hero option D) | custom r3f + shader (Paper Shaders exposes NO pointer-interactivity props) |
| Scroll-scrubbed SCENE state (internal visual state driven by scroll progress) | custom, under the §7 C4 pin discipline |

Anything the 29-component catalogue plausibly covers → Paper Shaders. Hand-rolling a mesh gradient "because it's fun" fails N10 at review.

### The catalogue (29 components, verified from the shipped `index.d.ts`) → where each fits

| Class | Components | artifex fit |
|---|---|---|
| **Ambient gradient fields** (HIGHEST HB-1 risk, see anti-slop below) | `MeshGradient`, `GrainGradient`, `StaticMeshGradient`, `StaticRadialGradient` | Hero ambient ground under option A/C type, DD-3 scrolly background, T12 atmospheric ground. Warm-editorial / premium / cinematic moods |
| **Structured texture / print energy** (structurally HB-1-safe: reads as designed geometry, not haze) | `Dithering`, `ImageDithering`, `HalftoneDots`, `HalftoneCmyk`, `PaperTexture` | Editorial / zine / print archetypes; the Wix-Pantone structured-band energy; quiet grounds behind T7 bento or T8 index panels |
| **Dot / grid fields** | `DotGrid`, `DotOrbit` | Tech/data ambience, the NON-interactive Lusion-lite ground; T20-adjacent retro-tech floors. If the brief needs cursor-reactive formation, that is the T18 carve-out, not these |
| **Organic noise / atmosphere** | `NeuroNoise`, `SimplexNoise`, `PerlinNoise`, `Warp`, `Swirl`, `SmokeRing`, `GemSmoke` | Dark cinematic backdrops (T12), moody section grounds, web3/worldbuilding energy |
| **Graphic / geometric** | `Waves` (inherently static: its params carry no motion), `Spiral`, `ColorPanels`, `Voronoi`, `Metaballs`, `PulsingBorder` | Waves/Spiral: static texture layers; ColorPanels: T1 color-field energy; Metaballs: playful/Gen-Z; PulsingBorder: a framed device/CTA accent, mind HB-6 (no glow-dot energy) |
| **Image filters / logo animations** | `FlutedGlass`, `Water`, plus `Heatmap`, `LiquidMetal` (brand-mark moments; T23 intro motif candidates) | Treat REAL licensed imagery or the brand mark; HB-4 still governs the source image |

**Props are verified per-component, never guessed.** Common to all (from the shipped types): color props (`colors` / `colorBack` / `colorFront` per shader), motion (`speed`, `frame`), sizing (`fit: 'none'|'contain'|'cover'`, `scale`, `rotation`, `originX/Y`, `offsetX/Y`, `worldWidth/Height`), resolution (`minPixelRatio`, `maxPixelCount`), plus standard div props (`style`, `className`). Before using ANY component not recipe'd below, read its shipped types (`node_modules/@paper-design/shaders/dist/shaders/<name>.d.ts`); published examples in the wild are STALE (e.g. GrainGradient's real params are `softness`/`intensity`/`noise`/`shape`, not the widely-copied `grain`).

### Recipes (real imports + verified props, pinned 0.0.76)

**R1: hero ambient field (MeshGradient) with the full N7 / check-K wiring**

```tsx
'use client';
import { MeshGradient } from '@paper-design/shaders-react';
import { useReducedMotion } from 'framer-motion'; // already in the §14 stack

export function HeroField() {
  const reduced = useReducedMotion();
  return (
    /* in-palette CSS ground = frame-one richness (check K) + no pre-hydration void */
    <div className="absolute inset-0 -z-10 bg-[#101014]">
      <MeshGradient
        colors={['#101014', '#27214d', '#8a3a1f', '#e8e0d4']} // the build's LOCKED archetype palette, NEVER the shipped presets
        distortion={0.8}
        swirl={0.15}
        speed={reduced ? 0 : 0.5} // speed 0 stops rAF entirely: the rich STATIC end-state (N7 safety-valve + check K), not a strip
        minPixelRatio={1}         // §9 DPR cap; the library default is 2
        style={{ width: '100%', height: '100%' }}
      />
    </div>
  );
}
```

**R2: DD-3 scrollytelling background, structured class (Dithering)**

```tsx
'use client';
import { Dithering } from '@paper-design/shaders-react';

<Dithering
  colorBack="#0b0b0d"
  colorFront="#3d3a34" // archetype neutrals, low contrast: this is a GROUND, not a poster
  shape="warp"         // verified shape keys include: simplex | warp | dots | wave | ripple
  size={2}
  speed={0.2}
  minPixelRatio={1}
  style={{ position: 'absolute', inset: 0, zIndex: -10 }}
/>
```

**R3: organic grain field (GrainGradient), the stale-props trap called out**

```tsx
'use client';
import { GrainGradient } from '@paper-design/shaders-react';

<GrainGradient
  colorBack="#101014"
  colors={['#27214d', '#8a3a1f']} // 2-3 archetype colors MAX; more reads as rainbow slop
  shape="blob"                     // verified: wave | dots | truchet | corners | ripple | blob | sphere
  softness={0.6}
  intensity={0.45}
  noise={0.3}                      // the REAL params; a `grain` prop does not exist in 0.0.76
  speed={0.7}
  minPixelRatio={1}
  style={{ width: '100%', height: '100%' }}
/>
```

Below-fold instances follow §9 lazy-load discipline: `next/dynamic` with `ssr: false` + mount on `IntersectionObserver` near-enter; only a HERO field may load eagerly.

### Anti-slop + budget + motion wiring (into the EXISTING gates, not new ones)

- **HB-1 is judged on the rendered OUTPUT, engine irrelevant (N10 never overrides it).** A default-preset MeshGradient on a hero IS the aurora tell wearing a library badge, instant auto-fail. Every instance must carry: (a) a palette from the build's LOCKED archetype, never the shipped `*Presets` / default colors; (b) a named role in its section's Variance Map row (ambient hero ground / DD-3 background / texture layer); (c) deliberately chosen params. The ambient-gradient class passes HB-1 only when it reads as designed, structured atmosphere (ink-dark or brand-saturated, visible grain/contrast); soft pastel multi-hue haze fails no matter what rendered it. The dithering/halftone/dot classes are the structurally safe reach when in doubt.
- **N4 budget: ONE mounted canvas per page, animated OR static** (a `speed={0}` or `Static*` instance still holds a WebGL context). More sections wanting the shader look get a BUILD-TIME image export of the shader frame (screenshot → WebP per §9 asset discipline), never a second canvas. Audit check D counts Paper Shaders instances.
- **Reduced-motion (N7, exactly as stated there):** the shader is ambient, not large-travel, so do NOT strip it, FREEZE it: `speed={0}` renders the rich static end-state at zero recurring cost (check K's own fallback rule). Stagger, reveals, micro-interactions around it stay per N7.
- **Device budget (the SEPARATE N7 rule):** coarse-pointer / cheap-Android downgrades the heavy canvas to STATIC: prefer the baked image export (no GL context at all) on those devices; at minimum `speed={0}` + a tightened `maxPixelCount`.
- **Perf knobs (§9):** pass `minPixelRatio={1}` (library default 2 exceeds the §9 DPR 1-1.5 cap) and tune `maxPixelCount` down from its 1920×1080×4 default for full-bleed fields; hidden-tab pause is built in (verified).

---

## 6. THE METHOD: variance-mapping a multi-section page

This is the core procedure. Do it BEFORE writing any code.

### Step 1: List the narrative beats
Get the section list (from the brief, or from `/pitch-deck`'s narrative outline). Example: a 9-beat product pitch = Hook / Problem / Wedge / Demo-1 / Demo-2 / Demo-3 / Capability / Why-now / CTA.

### Step 2: Assign a DISTINCT skeleton + technique + transition per beat
Fill the **Variance Map** table. One row per section. Pull skeletons from the catalog below and techniques from §5. **Each cell value must be unique down its column** (except connective tissue). **Every row also carries a `Ref read:` cell** naming the reference montage studied for that row (a file in `references/`, or the notes-dir full set) and confirming it was opened with the Read tool THIS session (N8, §11); audit check G fails any row whose montage was not actually Read.

**Skeleton catalog** (the "where things sit" layer, vary THIS):
`full-bleed-type` · `full-bleed-dark-scatter` · `centered-device` · `bento-grid` · `split-50/50` · `full-bleed-mosaic` · `horizontal-rail` · `centered-statement` · `tilted-card-float` · `index-color-panels` · `product-pinned-swap` · `editorial-asymmetric` · `panel-deck` · `stepped-panel`

### Step 3: Worked example (the Pulse 9-beat deck, the canonical reference)

| # | Beat | SKELETON | SIGNATURE TECHNIQUE | The SURPRISE | TRANSITION OUT | Build |
|---|---|---|---|---|---|---|
| 1 | HOOK | `full-bleed-type` | T3+T4 + a brand ECG line that draws→flatlines→spikes on the key word; an oversized index/section marker (B3) | the flatline-then-spike answering the question visually | line draws down into §2, screen INVERTS to dark | B |
| 2 | PROBLEM | `full-bleed-dark-scatter` | T1 invert + a messy floating collage that drifts and **dissolves** on scroll | light→dark cut; the chaos literally clears | clean wipe back to light, UI rises | B |
| 3 | WEDGE | `centered-device` | device frame rises; real screenshot snaps in; **T13 count-up** Rp0→Rp568.000 | the number counting up live, no "wait for kasir" | soft zoom INTO the dashboard → bento | B |
| 4 | DEMO 1 (analytics) | `bento-grid` | **T7 bento** of live data cards; charts **draw on enter** | the command-center density surfacing the #1 product | bento slides left → split snaps in | B |
| 5 | DEMO 2 (checkout) | `split-50/50` pinned | **the ONE scrollytelling beat**, left taps items, right cart fills → receipt prints | the receipt printing at the end of the scrub | unpin; struk slides up → photo mosaic floods in | B-H |
| 6 | DEMO 3 (menu) | `full-bleed-mosaic` | photo mosaic of real product shots; one card **assembles** then flies into the grid (T9) | the wall of photoreal shots vs spreadsheet POS | mosaic recedes into a rail | B |
| 7 | CAPABILITY | `horizontal-rail` | **T10 sideways rail**, **T8 index-numbered** cards | the lateral motion (breaks vertical rhythm once) | rail ends; camera pulls back to centered statement | B |
| 8 | WHY-NOW | `centered-statement` | **T13 big-number** 64.000.000 counts up + a 3-step path draws | the scale of the number; restraint after busy demos | quiet fade; the §1 line re-enters | B |
| 9 | CTA | `centered-form` | minimal max-contrast; **the §1 ECG line returns as a bookend**, now a steady beat | the callback completing the loop | (end) | B |

> **Second canonical worked example, the immersive-portfolio archetype:** the Christopher Indrawan portfolio (`~/claude/Git/repositories/christopher-portfolio`, live topengdev.com) is the reference build for the COHESIVE-EXPERIENCE shape: an 8-panel deck (T24) opened by a designed intro beat (T23), with re-arming reveals, two in-panel steppers (T25, a work-experience color-dissolve stepper + a more-work card rail), and hover-preview live-site videos (T16). Where the Pulse deck above teaches the variance MAP, the portfolio teaches the immersive SPINE (intro beat + panel deck + reveals that re-perform). Reach for it when a brief is a focused, sequential experience (portfolio, short pitch), and NOT for a long or SEO-critical scroll page.

### Step 4: The HERO gets its own playbook (highest-stakes beat)

The hero is beat 1 of the map but earns extra scrutiny, "our hero is too plain" is half of every monotone verdict. **Every studied hero does ONE of: {move in real time · type at architectural scale · cut to a bold color field · frame a live number}.** None is "centered headline + subhead + button on white", that IS the AI-default hero, banned.

| Option | Direction | Reference DNA | Build |
|---|---|---|---|
| **A ★** | Oversized question/statement type + a **brand line/motif** that draws and reacts | Mana/Chungi type scale + a brand motif | B |
| **B** | A **live number counting up** inside a device frame, framed by huge type | KPR big-number + Wix type (T13) | B |
| **C** | Full-bleed **cinematic product/environment photo** + type overlay + grain, slow push-in | Crescente/KPR (T12) | B |
| **D** | Faint **interactive dot/particle field** that forms a brand shape on mouse move | Lusion-lite (T18) | **H**, only if this is your ONE splurge |
| **E** | Bold flat **color-field** + giant wordmark + inline icons | Crescente (T1+T3) | B |

Pick A/B/C/E for a buildable hero; reserve D for the single H budget (and then spend it nowhere else). Whichever you pick becomes beat 1's row in the map, and the source of the **motif (N6)** that threads later beats.

### Step 5: Run the Variance Audit (§7). If it fails, fix the map, not the code.

**Connective tissue (applies to ALL sections, doesn't count as a signature):** Lenis momentum scroll (T15, NO custom cursor, frontend-design §8 bans replaced cursors), **oversized index/section markers (B3)** for section marking (NOT timid mono eyebrows, §7 HB-2), and ONE recurring motif (the ECG line here) threading beats 1 → 3 → 9. **The motif is what makes the variance feel intentional instead of random, N6.**

---

## 7. ★ THE VARIANCE & QUALITY AUDIT: the hard gate (run before building)

**This is the centerpiece. No build starts until this PASSES.** It is the mechanism that makes the monotone failure impossible. Treat it like an L3 sign-off gate: fill the map, score it, and only proceed on a clean PASS. Two layers run here: a binary **Anti-Slop Hard-Ban** scan (any hit = instant fail) and the scored **A-O** checklist (O is conditional on the FULL-IMMERSIVE build SHAPE, see its row).

### The mandatory audit header (write these two lines FIRST, before any scoring)

```
Surface:  <aenoxa-product | pitch-deck | standalone-immersive | one-shot-demo>
Override: <verbatim quote of Christopher's explicit go-immersive override | n/a>
```

**`Surface: one-shot-demo` + `Override: n/a` → VERDICT auto-FAIL** regardless of every score below, with the routing instruction: use `/frontend-design` SAFE presets (N0). When an override exists, record the VERBATIM phrase ("go immersive", "award-caliber", or the explicit `/artifex` invocation), never a paraphrase; "make it impressive for the recruiter" recorded here is NOT an override and still auto-FAILS. `pitch-deck`-hosted builds and Christopher's direct `/artifex` invocation are overrides by definition, write that in the Override line.

### ★ Anti-Slop Hard-Bans: instant auto-fail (scan these FIRST)

> Not scored, binary. **ANY hit auto-FAILS the audit** regardless of the A-O scores. Each was paid for by a specific rejection. Fix before scoring anything else. (These codes HB-1..HB-6 are a separate axis from the scored checks A-O below; they were renamed from A1-A4 to end the letter collision with the scored checks.)

| # | HARD-BAN | The tell it produces | Required instead |
|---|---|---|---|
| **HB-1** | **Aurora / glow-blobs / blurred-radial gradient orbs / soft gradient haze** as background or hero decor | "immediately looks like AI SLOP", the hero-v3 aurora was rejected outright | **0** blurred-radial / glow-blob elements. Background richness comes from real photos, structured grids, or geometry, never soft glows. Judged on the RENDERED OUTPUT, engine irrelevant: a Paper Shaders gradient field (N10/§5.1) passes only under the §5.1 anti-slop clauses (locked-archetype palette, deliberate composition, structured, never pastel haze); N10 never overrides this ban. |
| **HB-2** | **The timid mono micro-label "eyebrow" tell**, small uppercase/mono label-style accent text set as a tiny separate side-label (e.g. "pulse · POS untuk umkm", "tanpa pulse", "pulse jawabannya") | a recurring AI-slop indicator flagged across multiple sections | **0** timid micro-label eyebrows. Accent text is integrated confidently (oversized / italic / color-accented IN the headline) or becomes an oversized index marker, never a small separate label. |
| **HB-3** | **AI-default fonts**, Instrument Serif, Plus Jakarta Sans (+ the full N5 / frontend-design §8 banned list) | reads as "basic" | Confident pairings only (Fraunces × Switzer is a proven default; mark sections with oversized index numbers + small-caps, NOT a mono accent, mono is Terminal/Monospace-archetype-only per DD-1). |
| **HB-4** | **AI-generated photo-realistic backgrounds** | high slop risk | Hero/section photographic backgrounds are REAL + licensed (owned, or CC/Unsplash with attribution), never AI-generated. |
| **HB-5** | **Typography-floor violations**: any text below `font-weight: 500` (including EITHER endpoint of a variable-font `wght` animation) or any text below 12px (0.75rem) | thin/tiny text reads CHEAP; Christopher's hard floors, surfaced on the AURA reviews (2026-06-22 weight, 2026-07-01 size recalibrated 16px→12px) | **0** hits on the weight + size scans (exact commands live in the §15 self-verification gate, part 2). Lightness comes from size/spacing/color, never sub-500 weight; delicacy below 12px comes from tracking/spacing/color, never a smaller size. A 400→700 weight animation is a violation, animate 500→800 instead. |
| **HB-6** | **Decorative circle/status dots, outline/stroked display numerals, `rounded-full` ALL-CAPS tight-padding badge pills** | Christopher bans decorative dots globally as "ugly" (flagged + killed twice before generalizing); outline numerals and generic pills are AI-slop tells (2026-07-01 AURA repolish) | **0** decorative dots anywhere (eyebrow prefixes, navbar network-dots, status/"live" indicators, all of it); display text/numbers FILLED, never outline/stroked; tags are sharp `rounded-[7px]` small-caps, never rounded-full ALL-CAPS pills. |

### The scored checklist

| # | Check | Metric | PASS condition | FAIL action |
|---|---|---|---|---|
| A | **Skeleton uniqueness** | `distinct_skeletons / total_sections` | **= 1.00** (every section a different skeleton) | Two+ sections share a skeleton → redesign the repeats with a different skeleton from the catalog |
| B | **Technique uniqueness** | `distinct_signature_techniques / total_sections` | **= 1.00** (no technique carries two sections) | A technique repeats → swap one section to a different T# |
| C | **Scrollytelling cap (by DISTINCT technique)** | count of pinned scroll-scrubbed sections sharing the SAME technique | **≤ 1 per distinct technique** (a text-line-illumination scrub and a screenshot scrub are DIFFERENT techniques, both may coexist); never the spine | Two sections share the SAME scrollytelling technique → convert the extra to a scroll-*triggered* entrance or a different motion model |
| D | **Heavy-effect cap** | count of WebGL/canvas/3D sections (a mounted Paper Shaders canvas counts, animated OR static, N10/§5.1) | **≤ 1** | ≥ 2 → keep the strongest as the splurge, rebuild the others from the B tier (extra sections wanting the shader look get build-time image exports of the shader frame, §5.1, never a second canvas) |
| E | **Designed transitions** | `sections_with_a_designed_transition_out / (total − 1)` | **≥ 0.80** (interior boundaries are events, not cuts) | Hard cuts → design a color-invert / mask-wipe / panel-reveal / camera-push for each |
| F | **Motif through-line** | longest motif chain (sections sharing one recurring motif) | **≥ 3 sections** | No motif spanning ≥ 3 → introduce one (a brand line, a color callback, a repeated mark) and thread it |
| G | **No banned defaults + grounded rows** | frontend-design §8 scan + N5 fonts + every Variance Map row's `Ref read:` cell | **0 violations AND every map row names a reference montage that was actually opened with the Read tool THIS session (N8, §11)** | Any banned font/color/layout/badge → replace per frontend-design §8. Any row whose montage was not Read this session → go Read the montage (and its `references/README.md` STEAL / DO-NOT-COPY entry) before that section may be built |
| H | **Type-size variance** (B1) | ratio of largest display type to body | **large + intentional**, giant display words / oversized index markers vs small body; never uniform | Uniform/timid sizing → introduce dramatic, unpredictable scale (architectural display + oversized markers). Refs: crescentesicily.com, chungiyoo.com |
| I | **Confident type moments** (B2/B3) | oversized/abstract/overlapping type per major section + section markers are oversized index numbers | **≥ 1 abstract type moment per major section; markers oversized, not timid labels** | A timid label or no abstract moment → make the accent oversized-in-headline; replace labels with big 01 / 02 / 03 |
| J | **Eased motion, no snap** (C1/C2/C3/C4) | hard-cut/blink transitions · discrete `text-align` flips · un-layered crosses · **pinned sections that flash a neighbour-sliver on fast scroll** | **0 hard cuts; alignment driven by a transform tween (not `text-align`); cross/overlap layers have explicit z-index with image LEADING; pinned sections pinned via CSS `position:sticky` (NOT GSAP `pin:true`), tested on FAST/flick scroll** | Any blink / text-align flip / default paint order / GSAP-pin sliver-flash → ease the slide, tween translateX through center, set intentional z-index, convert GSAP pin → CSS sticky (see C4 addendum) |
| K | **Rich hero from frame one** (D1/D2/D3) | the hero's first ~2s | **layered visual content from frame one**, a real bg + a choreographed multi-beat entrance (focus-pull / Ken-Burns / word-ignite); reduced-motion fallback = the rich static end-state; a photo hero is real+licensed+scrim | A near-empty opening (a lone line on a blank stage reads as "nothing happening", not suspense) → add a real bg + layered elements + a designed entrance |
| L | **Section variance extras** (E1/E2) | scrollytelling counted by distinct technique (see C) + demo/content sections alternate L↔R | **distinct-technique counting honored; L↔R alternation where it fits** | Same-technique scrollytelling repeated → vary or cut; static one-sided demos → alternate image/text sides |
| M | **Display-type containment** (C5) | largest display type (giant count-up numbers, architectural headers) vs its container width across 320-1920px | **0 off-screen overflow, big display type lives in a `w-full text-center` block + the `clamp()` keeps it ≲85% of content width at every breakpoint (fits + centered, never edge-kissing), esp. mobile** | A huge `clamp()` font inside a narrow `max-width` box renders wider than the box → left-anchors + overflows right off-screen → wrap in `w-full text-center` and tighten the `clamp()` max so it fits |
| N | **Inherited frontend-design discipline gates** (the SKELETON is varied, but is the KEY?) | the three frontend-design §11 gates artifex inherits: DD-2 tonal variance, DD-3 scrollytelling background, DD-1 monospace | **All three hold. DD-2 (TONAL variance): across the page, sections differ in DENSITY and MOOD/energy and TYPE-SCALE rhythm and COLOR treatment, not only skeleton, 3+ consecutive sections in the same density+energy+type-rhythm is a MONOTONE fail even at A=B=1.00. DD-3 (BACKGROUND): every scrollytelling section has a real background layer (ambient field / texture / image / parallax), never a bare flat color. DD-1 (MONO): no monospace face outside DD-1's three carve-outs (the Terminal/Monospace archetype, a literal terminal/console/code-block component, or a literal hash/address/ID string used as a motif, see §8), the timid mono-label tell is already banned at HB-2.** | Structurally varied but tonally one-note (same key every section) → vary density/mood/type-rhythm/color per the §0.8 tonal-range principle, do NOT pass it at 9/10. Flat void behind a scrolly section → add a background layer (frontend-design §7.1.1). Stray mono labels → convert to oversized index markers / small-caps. This row is what stops a build that aced A and B (distinct skeletons + techniques) from sliding through while still reading MONOTONE, exactly the FATHOM failure: variance 9/10 structurally, yet one mood / one palette / one density throughout. |
| O | **Immersive completeness** (CONDITIONAL: applies ONLY when the build is FULL-IMMERSIVE by SHAPE: declared `Surface: standalone-immersive` at Frame time (§15 step 1) OR carrying a T24 panel-deck spine. The dial is NOT the trigger: every artifex build is VARIANCE 8-10, so shape decides) | intro beat present + reveal-on-arrival discipline if a panel-deck is used + a re-arming reveal behavior | **An intro beat is present (N9); IF a panel-deck spine (T24) is used, reveals play on arrival (not as dead scrubs) and the deck is touch/reduced-motion-gated + fail-safe + escapable; reveals re-arm so each panel re-performs on return (frontend-design §9.5.2 re-arming variant)** | No intro beat, or a deck whose reveals never fire because they were authored as scrubs, or a non-escapable scroll-jack, or reveals that fire once and leave later panels static → add the intro beat, convert scrub reveals to on-arrival entrances, add the free-scroll fallbacks, switch to the re-arming primitive. Hosted / spine-less scroll pages (e.g. a pitch-deck-hosted build with no T23 intro and no T24 deck) score O as `n/a` with the reason recorded in the audit block. |

### Motion & type addenda (C4 / C5): the specific structural rules behind checks J & M

> Two hard-won, easy-to-reintroduce bugs. Both reproduce only at the edges (fast scroll / narrow viewport), so they survive slow-scroll QA, test the edge explicitly.

- **C4, Pin via CSS `position: sticky`, NEVER GSAP `pin: true`.** GSAP pin swaps the element to `position: fixed` at the boundary; on a FAST/flick scroll (large per-frame delta) that swap lands ~1 frame late, so a ~100-150px sliver of the adjacent section flashes ("blink"). `anticipatePin` only nudges the engage point earlier, it does **NOT** fix the late fixed-swap (shipped as a "v2" and it still blinked). Fix structurally: pin via CSS `position: sticky` (`top:0`, tall outer wrapper for the scroll distance), keep ScrollTrigger for the **scrub only** (no GSAP pin), CSS sticky is composited every frame so it structurally can't flash. Belt-and-suspenders: give the pinned section an **opaque full-viewport background** so even a 1-frame mismatch can't show the neighbour through. **Always test pinned sections with FAST/flick scroll, both directions, slow scroll hides this.**
- **C5, Large display type must be CONTAINED + centered, never overflow.** A huge `clamp()` font (e.g. a giant count-up number, an architectural header) placed inside a narrow `max-width` box renders far wider than the box, so it left-anchors and overflows off the right edge, worst on mobile. Rule: put big display type in a `w-full text-center` block and clamp the font so it stays ≲85% of the content width across 320-1920px (fits + centered, never edge-kissing). Verify at 320px, not just desktop.

### The gate

> **PASS = the audit header holds (N0: no one-shot-demo surface without a recorded verbatim override), zero Anti-Slop Hard-Ban (HB-1..HB-6) hits, AND A and B exactly 1.00, C ≤ 1 per distinct technique, D ≤ 1, E ≥ 0.80, F ≥ 3, G = 0, H-N all satisfied (and O when the build is full-immersive by SHAPE per its row: standalone-immersive surface or a T24 deck spine; hosted / spine-less scroll pages record `O: n/a` + the reason)** (N folds in the inherited frontend-design tonal-variance, scrollytelling-background, and monospace gates, so a structurally-varied but TONALLY-monotone or mono-overusing build FAILS even at A=B=1.00). Anything else = **NOT cleared to build.** Fix the Variance Map (and any hard-ban hits) and re-run. Do NOT "push through" a failing audit, that is exactly what produced the two Pulse rejections (and the FATHOM "varied but still monotone" miss).

### Worked audit (the §6 map above)

```
Surface:  pitch-deck (hosted by /pitch-deck Stage 6)
Override: hosted /pitch-deck invocation (an override by definition, N0)
Hard-bans:    no aurora/glow-blob · no timid mono micro-eyebrow ·
              no AI-default fonts · no AI-generated photo bg ·
              floors hold (no sub-500 weight / sub-12px size) ·
              no dots / outline numerals / pill badges                        → 0 hits ✅
Sections: 9
A skeletons:  full-bleed-type · dark-scatter · centered-device · bento · split-pinned ·
              mosaic · horizontal-rail · centered-statement · centered-form  → 9/9 = 1.00 ✅
B techniques: type+line · invert+dissolve · device+countup · bento-charts · scrub-trail ·
              mosaic+assembly · rail+index · big-number · bookend            → 9/9 = 1.00 ✅
C scrollytelling: 1 distinct technique (Beat-5 checkout scrub)               → ≤ 1 ✅
D heavy effects:  ≤ 1 (the Beat-5 scrub OR a hero line splurge, not both)    → ≤ 1 ✅
E transitions:    8/8 interior boundaries designed                          → 1.00 ✅
F motif:          ECG line threads beats 1 → 3 → 9                           → 3 ✅
G banned+ground:  0 banned · all 9 map rows' montages Read this session      → ✅
H size-variance:  architectural display (~300px) vs ~16px body              → large ✅
I type moments:   oversized index markers + ≥1 abstract moment per section   → ✅
J motion:         eased slides; alignment tweened; image leads (z-index);
                  Beat-5 pinned via CSS sticky (not GSAP pin), flick-tested  → 0 snaps ✅
K hero:           rich frame-one (real photo + focus-pull/Ken-Burns/ignite)  → ✅
L extras:         distinct-technique scrollytelling; demos alternate L↔R     → ✅
M type-contain:   Beat-3/Beat-8 count-ups in w-full text-center, clamp fits
                  ≲85% width at 320-1920px → no off-screen overflow          → ✅
N inherited:      DD-2 tonal: density/mood/type-rhythm/color all MODULATE
                  section to section (not one key); DD-3: every scrolly
                  section has a bg layer; DD-1: no mono outside terminal comp → ✅
O immersive:      n/a, hosted pitch-deck scroll page, no T23 intro / no
                  T24 deck spine (shape trigger not met)                      → n/a ✅
VERDICT: PASS, cleared to build.
```

> **Check O (immersive completeness) applies ONLY to FULL-IMMERSIVE-shaped builds** (declared `standalone-immersive` at Frame time, or carrying a T24 deck spine); the Pulse deck above is a pitch-deck-hosted scroll page with neither, so its audit records `O: n/a` with the reason, as shown. The Christopher portfolio (§12) is the worked example where O is demonstrated: a designed intro beat (T23) hands off to beat 1, an 8-panel deck (T24) plays reveals on arrival, and the reveals re-arm so each panel re-performs on return.

Emit this block (filled for the actual page) as the first build artifact. It is the proof the design is varied before a line of code exists.

---

## 8. TYPOGRAPHY SYSTEM (distinctive, not default)

The single highest-leverage upgrade. Mechanics live in frontend-design §3; the **system shape** is here.

### The formula (always three layers)

1. **One strong DISPLAY face at architectural scale** does the heavy lifting (Mana 334px, Chungi 587px, Wix 158px). Scale + restraint, not decoration. Tight tracking on big type (−1.5 to −3px at display sizes). **Contain it:** architectural-scale type (and giant count-up numbers) goes in a `w-full text-center` block with a `clamp()` whose max keeps it ≲85% of content width at every breakpoint, a huge font in a narrow `max-width` box overflows off-screen (worst on mobile). Audited at §7 check M (C5).
2. **A NEUTRAL workhorse BODY** that stays invisible and legible (the display has personality; the body has none).
3. **An oversized index / section-marker layer**, big "01 / 02 / 03" markers replace timid section labels, set in the display or body sans (sized up, color-accented, part of the composition). For any tracked-uppercase accent text, use the body sans as small-caps + tabular figures + hairline rules, NOT a mono face: mono is reserved for the Terminal/Monospace archetype only (frontend-design §3.1 / §11 DD-1), it is not a general accent tool. The cheap small mono "eyebrow" is doubly out: a tiny separate tracked-out eyebrow on every header is the hard-banned HB-2 tell, AND a mono face does not belong on a non-Terminal build at all.
4. Used once, not everywhere: **one script or flourish** for a single human touch (optional).

### The floors (Christopher's hard rules, non-negotiable in every pairing)

- **Weight floor 500:** no rendered or resting text below `font-weight: 500`, anywhere (body, captions, markers, disabled states, placeholders), INCLUDING both endpoints of any variable-font `wght` animation. A 400→700 "materialize" reveal is a violation; animate 500→800 instead (the effect comes from the jump + opacity + travel, not a frail start). Lightness comes from size/spacing/color, never sub-500 weight. If a face ships only lighter cuts, source a heavier cut or faux-bold to ≥ 500. (frontend-design §0.6.)
- **Size floor 12px (0.75rem):** the smallest labels/markers/captions/counters/fine print sit AT 12px, never below (no `text-[10px]`/`text-[11px]`); body copy stays comfortable (16px+). Want more delicate? Add tracking, spacing, or a lower-contrast color, never a smaller size. (Recalibrated from a blunt 16px floor on 2026-07-01: 16px over-inflated micro-labels; 12px is the floor. frontend-design §0.6.)
- **Filled, never outlined:** display text and numerals are FILLED; no outline/stroked treatments on giant count-ups or architectural headers.
- **No decorative dots, no pill badges:** decorative circle/status dots are globally banned; tags are sharp `rounded-[7px]` small-caps, never `rounded-full` ALL-CAPS tight-padding pills. (HB-6.)

Enforced at §7 HB-5/HB-6 and scanned mechanically in the §15 self-verification gate. This matters MOST here: giant display type next to tiny tracked labels is artifex's signature size-variance move (check H), which is exactly where a sub-12px or sub-500 label sneaks in.

**Size variance is itself a primary engagement lever (B1):** the ratio between the biggest display type / oversized markers and the small body must be dramatic and unpredictable, never uniform, timid sizing. "the unpredictable font sizing is one of the key to engaging user experience." Refs: crescentesicily.com, chungiyoo.com. The audit scores this (§7 check H).

### BANNED defaults (these ARE the monotone verdict in type form)

| Banned | Why | Use instead |
|---|---|---|
| **Instrument Serif** | THE default "free editorial serif" on every AI landing page | Fraunces, Voyage, a real contrast-serif |
| **Plus Jakarta Sans** | THE generic startup sans (the regressed Prometheus site literally uses it) | Switzer, Satoshi, General Sans, Hanken Grotesk |
| **Inter / Inter-only / Roboto / Arial / Open Sans / Montserrat / Poppins** | frontend-design §8 banned-fonts list, in full force | any pairing below |

### Recommended pairings (open-license, basic-Latin, NOT default)

| # | Display | Body | Marker / accent treatment (NO mono) | Personality | Where |
|---|---|---|---|---|---|
| **1 ★ Warm-editorial** | **Fraunces** (variable optical serif) | **Switzer** / Inter Tight | oversized index numbers + body-sans small-caps + tabular figures | Warm, characterful, premium, best all-rounder | Google / Fontshare |
| **2 Confident-modern** | **Clash Display** (geometric display) | **Satoshi** / General Sans | oversized index numbers + body-sans small-caps + tabular figures | Modern, assured, great for data/analytics | Fontshare (free) |
| **3 Bold F&B poster** | **Gasoek One** / Hatton | **Hanken Grotesk** / Barlow | inline icons + oversized index numbers | Friendly coffeeshop-poster energy (Crescente) | Google / open |
| **4 Premium-grotesque** | **General Sans** (open Aeonik-alt) | same family | oversized index numbers + small-caps, tabular figures for data | Lusion energy: one grotesque, data-forward | Fontshare (free) |
| **5 Characterful-neutral** | **Bricolage Grotesque** (display weights) | **Geist** / Inter Tight | oversized index numbers + body-sans small-caps | Distinctive yet safe; quirk without loudness | Google (free) |

> The "accent treatment" column is a TYPOGRAPHIC treatment in the display/body faces (oversized index numbers + tracked-uppercase small-caps + tabular figures + hairline rules), NOT a third mono font. A mono face is allowed ONLY in DD-1's THREE carve-outs (frontend-design §3.1 / §11 DD-1): **(1)** the whole build is the Terminal/Monospace archetype (mono IS the type system); **(2)** text inside a literal terminal/console/code-block COMPONENT (a real code surface); **(3)** a literal hash / address / ID string (e.g. an Ethereum-style `[0x...]` mark) even when used as a RECURRING decorative MOTIF outside a terminal component, because it is a code token, not a labeling language (the christopher-portfolio motif is the worked example). Outside those three, no mono, and the timid mono eyebrow stays instant-auto-fail (HB-2) regardless.

**Default lead:** pairing **1 (Fraunces × Switzer)** for warm/premium, or **2 (Clash Display × Satoshi)** for bolder/modern. **Mark sections with oversized index numbers + body-sans small-caps (tabular figures + hairline rules), NOT a mono face and NOT a timid tracked-out eyebrow on every header (§7 HB-2). Mono is allowed only in DD-1's three carve-outs (Terminal archetype / literal code surface / literal hash-address motif).**

---

## 9. PERFORMANCE BUDGET (wow without dying on a cheap Android)

Award sites are desktop-first and **gate their heavy parts.** Mirror that. Mechanics in frontend-design §6/§9; the budget RULES are here.

| Rule | How the refs do it | Apply |
|---|---|---|
| **≤ 1 heavy canvas on the whole page** | every WebGL site ships ONE scene | One splurge effect total (N4). Everything else = CSS + SVG + GSAP/Framer. A mounted Paper Shaders canvas counts as this one canvas, animated or static (N10/§5.1); further sections wanting the shader look get build-time WebP exports of the frame, never a second canvas. |
| **Effects = progressive enhancement** | (none) | **Scroll must hit 60fps with effects OFF.** Build the static page first; layer effects on top. |
| **Preloader masks WebGL warm-up** | Pioneer "93% loading your experience" | If you ship the H effect, hide its init behind a 1-2s branded loader. On a full-immersive build the T23 designed intro beat IS this loader (never a bare spinner, N9). |
| **Lazy-load below-fold heavy parts** | all WebGL sites defer scenes | Only the hero effect loads eagerly; charts/3D mount on `IntersectionObserver` near-enter. |
| **`prefers-reduced-motion` = the SAFETY-VALVE, not a strip** | award sites keep the show and tame the travel | artifex surfaces are landing-class: do NOT auto-reduce the whole show. Swap ONLY large-travel motion (parallax, scroll-jack, scrubbed scenes) for quick fades; KEEP stagger, reveals, micro-interactions, and the signature moment (frontend-design §6 Reduced Motion split + §0.9 + LM-6; a global `*` reduce also silently kills the show for OEM-reduced-motion Androids). T24 deck gates fully OFF (free scroll); T23 intro skips to its handoff (N7). |
| **Coarse-pointer / small-viewport downgrade** | heavy canvas is desktop-only | On mobile / cheap Android: swap canvas + scrub for static images + CSS fades. |
| **GPU-cheap motion only** | transforms/opacity, not layout | Animate `transform`/`opacity` only; Lenis for scroll; cap canvas DPR to 1-1.5 (Paper Shaders: pass `minPixelRatio={1}` + a tuned `maxPixelCount`, its defaults 2 / 1920×1080×4 exceed this cap, §5.1); pause `rAF` offscreen (Paper Shaders auto-pauses hidden tabs, verified). |
| **Asset discipline** | (none) | Real screenshots → WebP/AVIF, responsive `sizes`, lazy. Compress hero photo sets hard. |

### Pre-ship perf gate (TIERED: pick the row that matches the build)

A single flat number for every artifex build is a dead gate: a zero-splurge deck and an r3f-splurge build have different legitimate weights. CLS is hard EVERYWHERE; the JS caps are route-critical (what blocks first paint), which is why the splurge is carved out as a lazy chunk instead of inflating the cap. (frontend-design deliberately dropped its fixed first-load JS rule for heavy landings; these route-critical caps are how artifex keeps discipline without re-creating an unmeetable gate.)

| Tier | CLS | LCP | Route-critical JS (gz) | The splurge chunk |
|---|---|---|---|---|
| **BASE** (zero H splurge) | **≤ 0.1, hard** | ≤ 1.5s | ≤ 350KB | n/a |
| **SPLURGE** (exactly one H) | **≤ 0.1, hard** | the T23 intro-panel TEXT renders ≤ 1.2s and is the intended LCP element | ≤ 400KB EXCLUDING the lazy scene chunk | the 3D/canvas scene is NEVER in the route-critical chunk: `next/dynamic` with `ssr: false`, loading behind the T23 intro beat; it never blocks first paint |

**The intro-beat / LCP interaction, defined:** on a SPLURGE build the T23 intro panel (its headline text + motif) is the first contentful paint and the intended LCP candidate; it must render ≤ 1.2s while the scene warms up BEHIND it. Never let the lazy scene chunk block the intro panel's paint.

**Host precedence:** when `/pitch-deck` hosts the build, ITS perf table WINS (LCP ≤ 1.2s, CLS ≤ 0.1, JS ≤ 300KB compressed, Lighthouse ≥ 85). The tiers above govern standalone artifex builds.

**On every tier:** 60fps scroll on a throttled mid-tier Android **with effects off** (N7). **Measurement recipe (named, not vibes):** Lighthouse with the mobile preset (DevTools Lighthouse panel or the Lighthouse CLI), plus one pass under DevTools CPU throttling (4x, approximating a mid-tier Android) or on a real device. Below the tier's numbers → not done.

---

## 10. FEASIBILITY TIERS (aim the build right)

| Tier | Techniques | Verdict |
|---|---|---|
| **Buildable, ~80% caliber** (build ~90% of the page here) | T1, T2, T3, T4, T5, T6-CSS, T7, T8, T9, T10, T12-video, T13, T14, T15, T16, T17, T20, T21, T22, T23, T24, T25 | **YES.** Stack: Next.js + GSAP/ScrollTrigger + Lenis + Framer Motion + SVG. Variance, not WebGL, does the work. (This list is generated from the §5 table's B tags; regenerate it whenever a technique's tag changes.) |
| **Hard, budget exactly ONE** | T6 glitch-canvas, T11 one 3D product turntable (pre-render or GLB), T18 one particle/dot hero (r3f + simple shader), T12-3D full-3D environment backdrop | Pick ONE as the signature wow. Recommended: a hero particle/line effect OR a richer checkout scrub. **Not both.** |
| **Elite, do NOT attempt** | T19 continuous scroll-driven 3D world morph, T18-full physics hero | **Skip.** Needs a creative-dev team + weeks. Faking at 40% looks worse than a clean buildable section. |

**Targeting rule:** 90% from Buildable, the entire hard budget on ONE hero-grade effect, never the Elite tier.

---

## 11. GROUNDING: design from references, not from "engaging"

**N8 is a hard rule, not a vibe.** Before building each section you must be able to say: *"this section's skeleton is `X`, its signature technique is `T#`, modeled on `<reference site>`."* If you can't name the technique and a reference, you are improvising the model's idea of "engaging", which is exactly what produces slop.

- **Study the reference sites FIRST (F1)**, open and read them (qutebrowser via `/agent-browser`; NEVER Playwright MCP, it is hook-banned per agent-browser HR-1) BEFORE reworking a design; don't guess from memory. hyperframe / crescente / chungiyoo were studied before the first pass, which is why it landed.
- Carry the reference set (§12 / `references/`). Study the montage for the technique you're about to build.
- When in doubt or the brief is novel, **capture 2-3 fresh references** (Awwwards / Godly / the live site) with `/agent-browser` before designing, don't invent.
- **HARD RULE (the teeth of N8): a section may NOT be built unless its named reference montage was opened with the Read tool DURING THIS SESSION.** Model memory of a site is not grounding; "I remember what lusion looks like" is a violation. Log the read in the Variance Map's `Ref read:` cell; audit check G fails any row whose montage was not Read. Read the montage's STEAL / DO-NOT-COPY entry in `references/README.md` alongside the image, it names exactly which parts of each reference are banned on our builds (mono labels, outline type).
- The Variance Map (§6) IS the grounding artifact: every row names a technique + a reference + a `Ref read:` confirmation. A row with no named technique fails the audit (check G + N8).

---

## 12. REFERENCE LIBRARY (the 12 studied sites + what each teaches)

Grounded in a ref-study of 12 award-caliber sites (real fonts read from the DOM, screenshots captured headless). Curated montages ship in `references/`; the full set + per-site notes live in `~/claude/notes/pulse-pitch-deck-2026-06-20/ref-study/`.

| Site | Domain | What it teaches | Tier |
|---|---|---|---|
| **Crescente** ★ | Sicilian street food | **The best buildable F&B blueprint.** Flat color-field swaps (orange↔cream), rounded-panel reveals (T2), inline-icon headlines, curved sticker-type (T5), 3D-product moments (T11). Closest analog to a warm consumer brand. | B-heavy |
| **Chungi Yoo** ★ | designer portfolio | **Type-as-hero, cheapest variance family.** Color-field swaps (cream/yellow/pink) + serif/script type variety (T3/T4) + floating & tilted cards (T9) + circular arc-text (T5). Mostly CSS/type. (Chungi also uses OUTLINE type moments; on our builds outline/stroked display text is banned, HB-6 filled-only, so reproduce the variety via serif/script/weight/scale contrast instead.) | B-heavy |
| **Lusion** | creative-dev studio | **The canonical variance signature**, physics-hero → color-cut → editorial-grid → gallery → kinetic-type+3D-ribbon → framed-3D. Six skeletons, no repeat. Aeonik grotesque + small-caps section labels (Lusion itself used a mono eyebrow; on our builds that label layer is body-sans small-caps, NOT mono, per DD-1). | mixed (1 H/E hero) |
| **Synchronized** | digital studio | **Index-numbered case panels on muted color-fields (T8)** + circular type-rings (T5) retired after one use. The "design-studio editorial" template. | B |
| **Mana** | yerba-mate brand | **Product-anchored card swap (T21)**, product pinned while benefit cards swap around it. Flat-illustration collage + 3D product (T22). Warm F&B. | B |
| **Wix Pantone** | Pantone CotY capsule | **Bento texture collage (T7)** + editorial hero (T3) + gradient band, all in ONE monochrome. Sans×classical-serif contrast. Disciplined color story. | B |
| **KPR** | web3 collectible universe | Cinematic game-trailer pacing: logotype negative-space → key-art split (T14) → 3D env (T12) → big-number "10K" (T13) → avatar strip. Custom display + grotesque (KPR also used a mono accent; on our builds that is body-sans small-caps, NOT mono, unless the whole build is the Terminal/Monospace archetype, DD-1). | mixed |
| **Noomo XR** | XR agency | **Synthwave perspective grid (T20)** + VCR-knockout type (T6-CSS) + circular type-rings + wireframe illustration. Retro-tech, mostly CSS/SVG. (Noomo used a VCR mono face for that knockout effect; reproduce the look with the display/body faces unless you are building the Terminal/Monospace archetype, DD-1.) | B |
| **Pioneer / RESN** | seed-science | **What NOT to attempt (Elite tier).** ONE continuous scroll-driven 3D world morph (T19, DNA→network→sprout→kernel) + glitch type. Studio-only, a named warning, not a target. | E |
| **Prometheus** | cleantech | **Cautionary.** A once-legendary WebGL site regressed to a generic Elementor + Plus Jakarta Sans page. Even famous brands regress to default. Use as a mood ref only. | (none) |
| **Awwwards** | the directory | The "polished baseline" end: clean neutral card-grid + hover-video preview (T16). NOT a wow ref, the variance lives in the sites it lists. | B |
| **Mammut Eiger** | (down at capture) | Named precedent only: horizontal/pinned mountain-ascent storytelling (T10). Don't assert specifics. | (none) |

**Fastest paths by brief:** warm consumer / F&B → **Crescente + Mana**. Editorial / portfolio / type-led → **Chungi + Synchronized + Wix**. Tech / data / dev → **Lusion + Noomo + KPR**. Always cross-check the Variance Map against at least 2 refs.

---

## 13. COMPOSES WITH

| Skill | How /artifex plugs in |
|---|---|
| **/pitch-deck** | Stage 6 is REWIRED to invoke `/artifex` directly ("Section architecture, invoke /artifex (variance-first)"); the old fixed template that hard-coded the monotone bug (3× `(pin)` + "DEMO 2: same pattern") is DELETED from pitch-deck. Run pitch-deck Stages 1-5 (intake → narrative outline) as-is; at Stage 6, feed the narrative beats into the **Variance Method (§6)** and clear the **Variance Audit (§7)** before building. The audit is pitch-deck's pre-build gate. Pitch-deck's Stage-6 "WOW prototype self-check" and the §15 WOW-prototype gate are the SAME gate: run it ONCE with the union of both criteria sets. Pitch-deck's perf table WINS over §9's tiers (host precedence). A pitch-deck-hosted invocation counts as the N0 override by definition. |
| **/oneshot-webapp** | oneshot's house rule is **SAFE presets only / light-only** (recruiter demos), and N0 makes that boundary self-policing HERE: `/artifex` is the **explicit-override path only**, invoke it only when Toper says "go immersive / award-caliber" or names `/artifex` in the brief, and record the VERBATIM override phrase in the §7 audit header (an audit for a one-shot brief with no recorded override auto-FAILS). Otherwise oneshot stays on `/frontend-design` SAFE mode. When invoked with the override, still honor oneshot's light-only + server-side-secrets + deploy rules, `/artifex` changes the *design method*, not the deploy/secrets discipline. |
| **/frontend-design** | The sibling. `/artifex` reads frontend-design in full as its engineering and craft base (§3). The difference: frontend-design applies ONE archetype consistently (SAFE); `/artifex` varies skeleton+technique+transition per section (IMMERSIVE) and gates it with the audit. Use frontend-design for product UI; `/artifex` for the dazzle. |
| **/atlas** | When the build features a REAL product's screens, read the /atlas dossier instead of inventing placeholder UI: `signals.visual_richness` + `screenshots` say which real screens to feature (atlas §10.3/§16). Run the dossier freshness check first (atlas §11.2); a STALE dossier's screenshots are suspect. /atlas captures neutral facts; the curation (what to show) happens HERE. |

---

## 14. STACK (opinionated defaults)

| Decision | Default | Notes |
|---|---|---|
| Framework | **Next.js 15 App Router** | RSC by default; `"use client"` only on interactive leaves (frontend-design §13) |
| Scroll engine | **GSAP + ScrollTrigger** | battle-tested scrubbing. Pick ONE engine and stick (mixing = lifecycle bugs). **Pin via CSS `position:sticky`, NOT GSAP `pin:true`**: GSAP pin's fixed-swap blinks on fast scroll (§7 C4). Keep ScrollTrigger for the scrub only. |
| Smooth scroll | **Lenis** | compositor-friendly momentum (T15). Skip if perf testing shows jank on low-end |
| Animation layer | **Framer Motion** | for React-component animations / `layoutId` transitions |
| Shader engine | **Paper Shaders** (`@paper-design/shaders-react`, pin exact 0.0.x) | MUST-USE first reach for the shader-class visual (ambient fields / hero textures / shader backgrounds; N10, §5.1). One mounted canvas max (N4). Repo README mandates pinning: breaking changes ship under 0.0.x versioning. |
| The ONE splurge | **react-three-fiber + a simple shader** | ONLY if you spend the single H budget on a 3D/particle hero, and ONLY when a §5.1 carve-out applies (real 3D geometry, cursor-reactive physics, scrubbed scene state); a shader-driven ambient field / texture splurge uses Paper Shaders instead (N10). Else omit entirely. NEVER in the route-critical chunk: load via `next/dynamic` with `ssr: false` behind the T23 intro beat (§9 SPLURGE tier), so the scene never blocks first paint. |
| Styling | **Tailwind (check v3 vs v4 first)** + CSS custom properties | frontend-design §13 |
| Component base | **Origin UI** (neutral base) + bespoke WOW sections | frontend-design §0.7 |
| Images | **WebP/AVIF**, Next `<Image>`, lazy below-fold | §9 asset discipline |

**Lock-in rule:** one scroll engine, one base palette, ≤ 1 heavy effect. Variance comes from the *method*, not from piling on libraries.

---

## 15. EXECUTION FLOW

1. **Frame**: confirm this is an `/artifex` job (dazzle, not maintain, §2) AND that N0 does not bar it: declare the `Surface` (aenoxa-product / pitch-deck / standalone-immersive / one-shot-demo) and, for a one-shot demo, record Christopher's VERBATIM override or STOP and route to `/frontend-design` SAFE. Decide the theming regime NOW: Aenoxa-ecosystem property → id-default + en i18n + polished light+dark from commit 0; hosted pitch/demo → inherit the host rule (pitch = light-only). Lock the section/beat list, the audience, the base archetype + palette. Decide the SPINE: a normal scroll page, or a full-viewport panel deck (T24, only for a focused sequential experience, never a long or SEO-critical page). This Frame step is ALSO where FULL-IMMERSIVE status is DECLARED, by SHAPE (the N9 / check-O trigger): `Surface: standalone-immersive` or a T24 spine chosen → the build is full-immersive, so plan the designed intro beat (T23, N9); a hosted spine-less scroll page is NOT full-immersive and its audit records `O: n/a` + the reason.
2. **Pick the type system**: a §8 pairing (default Fraunces × Switzer). Confirm none of N5's banned fonts; confirm the §8 floors (weight ≥ 500 everywhere incl. animation endpoints, size ≥ 12px); mark sections with oversized index numbers + body-sans small-caps, NOT a mono accent (DD-1's three carve-outs only) and not timid eyebrows (§7 HB-2).
3. **Variance-map**: fill the §6 Variance Map: distinct skeleton + technique + transition per section, name a reference per row, Read each row's montage THIS session and log it in the `Ref read:` cell (N8), pick the ONE H splurge (or zero).
4. **★ Run the Variance Audit (§7)**: header first (Surface + Override), hard-ban scan (HB-1..HB-6), then score A-O (O conditional on the full-immersive SHAPE declared in step 1, §7). **PASS or fix the map.** Emit the filled audit block as the first artifact. NO CODE until PASS.
5. **★ WOW-PROTOTYPE GATE (see below)**: hero + ONE signature section in pixels, ≤ 20% of the build budget, scored against the mini-rubric; BLOCKING direction confirmation from Christopher for customer-facing/L3 work. NO full build until it passes.
6. **Build static-first**: assemble every section's skeleton + content with effects OFF; confirm 60fps scroll and legibility (N7).
7. **Layer motion + the ONE effect**: apply connective tissue (Lenis momentum scroll, NO custom cursor per frontend-design §8, plus oversized index/section markers + the motif, and for a panel-deck build the T24 snap spine with on-arrival re-arming reveals), then each section's signature technique, then the single splurge behind a loader. For a full-immersive build, build the designed intro beat (T23) with its choreographed handoff to the hero (the frontend-design §9.5.4 appReady handoff primitive).
8. **Downgrade paths**: the reduced-motion SAFETY-VALVE (N7: large-travel → fades, keep stagger/reveals/micro/signature, T24 deck off, never a global strip) + coarse-pointer/cheap-Android static fallbacks (§9).
9. **★ SELF-VERIFICATION GATE (F2, see below): evidence, not claims.** Run the full gate (screenshot matrix + binary scans + flick-tests + scored rubric), run the §9 perf gate for your tier, re-confirm the §7 audit still holds AS BUILT (no skeleton/technique/hard-ban drift crept in during build), test on a throttled mid Android. This kind of honest artifact-based self-check caught real bugs last rebuild: count-up separators, invisible bars, pre-hydration flash.
10. **Deliver**: present with the filled Variance Audit block + the WOW-gate screenshots + the filled self-verification block (with file paths) as the proof of variance.

### ★ The WOW-prototype gate (step 5): validate the AESTHETIC in pixels, before the full build

The Variance Audit validates the MAP on paper; it cannot predict whether the direction LOOKS right. Skipping this step is the verified 2x rejection pattern: the Gruvbox reskin (rejected after full implementation; "a 10-minute prototype would have caught it") and the 2026-05-24 pulse-landing (1 hour, 5 commits, 12 sections → "i dont like how it looks, just kill the worker"). Discovery answers sound aligned in TEXT; the resulting aesthetic is impossible to predict from them. 10-20 minutes of prototype beats hours of rejected build, every time.

| Knob | Value |
|---|---|
| Scope | The HERO + exactly ONE signature section (the strongest map row). Nothing else: no auth, no remaining sections, no infra |
| Budget | ≤ 20% of the total build effort |
| Deliverables | 2 screenshots minimum from the RUNNING prototype: 1440x900 (desktop) + 390x844 (mobile) |
| When /pitch-deck hosts | This gate and pitch-deck's Stage-6 "WOW prototype self-check" are the SAME gate: build HOOK + one DEMO section, check BOTH criteria sets, run once |

**Mini-rubric (5 binary rows, ALL must pass):**

| # | Check | Pass condition |
|---|---|---|
| W1 | Frame-one richness | Check K holds IN THE PIXELS: layered visual content from frame one, not a lone line on a blank stage |
| W2 | Architectural type | Check H visible: the display scale reads dramatic in the screenshot, not timid |
| W3 | Zero hard-ban tells | No aurora/glow-blob, timid eyebrow, banned font, sub-floor text, dots, pills, or outline numerals visible in either screenshot (HB-1..HB-6) |
| W4 | Motif seeded | The N6 motif is present in the hero and set up to thread later sections |
| W5 | Distinctiveness | "Could a generic template have produced this frame?" The answer must be NO |

Any row fails → **fix the DIRECTION (archetype / palette / hero treatment), not the map on paper**, then re-prototype. Do NOT push through a failed row (that is the Selaras pattern). **BLOCKING escalation:** for customer-facing or L3 work, send the two screenshots to Christopher and WAIT for explicit direction confirmation before building the remaining sections. For internal / low-stakes work, self-score honestly and proceed on 5/5.

### ★ The self-verification gate (step 9): evidence, not claims

"I verified it works" is a claim; this gate emits ARTIFACTS. All four parts are mandatory. Emit the filled block (with file paths) as the final deliverable alongside the audit block.

**Part 1, screenshot matrix (capture, do not describe).** Target the build's OWN dev server (e.g. `http://localhost:3000`) in a tab YOU opened, never a tab Christopher is using. Flow per the /agent-browser skill (HR-9: `agent-browser tab new` exit-144s in this env, and 9222 stays the interactive active-tab port, HR-7): claim a dedicated tab on its own port (`CLAIM=$(curl -s -G "http://localhost:9222/claim" --data-urlencode "from=9223" --data-urlencode "url=http://localhost:3000")`, parse `port` and check for `"warning":"tab-create-failed"`) → `export AGENT_BROWSER_CDP=$PORT && agent-browser connect $PORT` within the ~30s TTL → verify `curl -s "http://localhost:$PORT/target"` shows your URL → capture → teardown: `agent-browser close` then `curl -s "http://localhost:9222/release?port=$PORT"` (full recipe: agent-browser §6.3 / R-1). If a heavy page (backdrop-filter, giant bg images) returns a blank/black CDP screenshot, fall back to qb-shoot (native Qt render path); probe it first (`ls ~/.config/qutebrowser/scripts/qb-shoot`) and know it operates on the shared live qutebrowser (switches tabs and back), so the agent-browser path is always preferred.

| Shot | How |
|---|---|
| Full page at 320 / 768 / 1440 wide | `agent-browser set viewport <w> <h>`, then `agent-browser screenshot --full <path>`, once per width; trim each `--full` shot per agent-browser PB-5 (HiDPI DPR defect: `convert in.png -bordercolor white -border 1 -trim +repage out.png`) |
| Hero at first paint (~2s in) | reload, screenshot immediately (check K evidence; catches pre-hydration flash) |
| One mid-state shot per section | scroll each section to its mid-state, screenshot |
| Reduced-motion pass | `agent-browser set media light reduced-motion`, re-shoot the hero + one scrolly section: the safety-valve must show (fades instead of parallax/scrub travel; stagger/reveals/micro still present; T24 deck OFF in free scroll) |

**Part 2, binary scans (ALL must pass):**

```bash
# 1. dashes (frontend-design §0.4 prime rule; also scan generated copy)
grep -rnP '[\x{2013}\x{2014}]' src/            # must output NOTHING
# 2. weight floor (HB-5)
grep -rn 'font-thin\|font-extralight\|font-light\|font-normal' src/   # must output NOTHING
#    plus eyeball every font-variation-settings / fontWeight literal: both animation endpoints >= 500
# 3. size floor (HB-5)
grep -rnE 'text-\[(10|11)px\]' src/            # must output NOTHING (12px/text-xs is the floor, allowed)
# 4. banned fonts (HB-3; plain Inter banned, Inter Tight allowed)
grep -rniE 'instrument serif|plus jakarta|roboto|open sans|montserrat|poppins' src/   # must output NOTHING
# 5. shader default-look tells (N10/§5.1; run when @paper-design is a dep)
grep -rnE 'Presets|defaultPreset' src/         # must output NOTHING (importing shipped presets = default palette = slop; colors come from the locked archetype)
```

Plus a VISUAL hard-ban scan over every part-1 screenshot: no aurora/blobs (HB-1), no timid eyebrows (HB-2), no dots / outline numerals / pill badges (HB-6).

**Part 3, flick-test, per pinned/sticky section (C4).** Slow scroll HIDES pin-blink; only a fast flick reproduces it. Method: park the viewport just before the boundary, fire large wheel deltas (`agent-browser mouse wheel 3000` in, `agent-browser mouse wheel -3000` out) INTO and OUT OF each pinned section, BOTH directions, screenshotting at the boundary; assert no neighbour-section sliver in any frame. (Gold standard when available: a high-fps CDP screencast under scripted flick, the method that originally caught the single-frame sliver.) Record method + result per pinned section.

**Part 4, scored rubric (0-10 per row; PASS = every row ≥ 7 AND all part-2 binaries green):**

| Row | What to score |
|---|---|
| Variance held AS BUILT | Compare the part-1 screenshots to the Variance Map ROW BY ROW: did build drift re-merge skeletons/techniques? (Exactly the drift this step exists to catch) |
| Tonal range (DD-2) | Consecutive sections differ in density / mood / type-rhythm / color IN THE PIXELS, not just structurally (the FATHOM miss) |
| 320px containment (check M) | No display-type overflow at 320 wide; count-ups centered, ≲85% content width |
| Frame-one richness (check K) | The first-paint hero screenshot is layered and alive, not a lone line on a blank stage |

Any part fails → fix, re-capture, re-emit. A gate you did not emit artifacts for did not run.

---

## 16. FAILURE-MODE PLAYBOOK (symptom → cause → fix → verify)

Every row is a paid-for failure. When a symptom matches, apply the named fix; do not re-diagnose from scratch.

| Failure | Symptom | Root cause | Fix | Verify |
|---|---|---|---|---|
| **Pin-blink** | ~100-150px sliver of the neighbour section flashes at a pinned boundary on fast/flick scroll (slow scroll hides it, reads "intermittent") | GSAP `pin:true` swaps to `position:fixed` one frame late on large per-frame deltas. `anticipatePin` is NOT a fix (shipped as v2, still blinked) | CSS `position:sticky` (top:0 + tall wrapper), ScrollTrigger scrub ONLY, opaque full-viewport bg on the pinned section (§7 C4) | Scripted flick in + out, both directions (§15 gate part 3) |
| **Dead reveals in a panel deck** | Reveals never fire inside a 100vh panel | Reveal authored as a scroll SCRUB, but a snapped panel has no scrub room | On-arrival entrance via the re-arming `useOnScreen` (frontend-design §9.5.2) | Enter / leave / re-enter each panel: the entrance replays |
| **Permanent scroll-lock** | Page cannot scroll after the intro beat | The intro component renders `null` while staying MOUNTED, so its `[]`-effect cleanup (which removes the scroll lock) never runs | Key the lock effect on the releasing STATE, not on unmount (frontend-design §9.5.4) | Scroll works the instant the intro lifts |
| **Count-up un-counting** | Numbers visibly count DOWN on scroll-back | Reverse scrub on a single-pass page | Single-pass page: fire once, no reverse scrub. Panel-deck / re-arming spine: reset + re-count on re-arrival is INTENDED (frontend-design §7.4 exception) | Scroll past, return: behavior matches the spine type |
| **Reveal breakage on Android Chromium (with Lenis)** | Scroll-reveals dead on Android | The IntersectionObserver dependency, NOT Lenis. Do NOT re-ban Lenis (the old ban was reversed) | Pair Lenis with the `useOnScreen` scroll-listener primitive (frontend-design §9.5.2 / §9.5.3) | Test Android Chromium / Brave / Samsung Internet |
| **Display-type overflow** | Giant number/header left-anchors and runs off-screen, worst on mobile | Huge `clamp()` inside a narrow `max-width` box | `w-full text-center` + clamp max ≲ 85% content width (§7 C5) | The 320px screenshot (§15 gate part 1) |
| **Aurora hero** | Hero decorated with glow-blobs / blurred orbs | The AI-slop default (hero-v3 was rejected outright for exactly this) | Real photo / structured grid / geometry (HB-1) | Visual HB scan on the screenshots |
| **Varied-but-flat (FATHOM)** | Distinct skeletons yet the page still reads monotone | One mood / one palette / one density throughout: structural variance without TONAL variance | Modulate density / mood / type-rhythm / color per section (check N, DD-2); do NOT score N a pass at 9/10 structural | Rubric row "tonal range" on consecutive-section shots |
| **Monotone-by-repetition (Pulse, rejected 2x)** | "MONOTONE / basic" verdict | One skeleton and one technique repeated across sections | The entire §6 method + §7 audit (this is the skill's founding failure) | Audit A = B = 1.00, then the as-built re-check (step 9) |
| **Full build, no prototype (Gruvbox + pulse-landing)** | Hours of build rejected on sight | Direction never validated in pixels; discovery text cannot predict aesthetics | The §15 WOW-prototype gate, BLOCKING for customer-facing/L3 | Two screenshots + confirmation BEFORE the remaining sections |
| **High-variance one-shot demo (Selaras)** | Recruiter demo "looked SO BAD", unpresentable | An execution-sensitive high-variance direction (art-deco) on a time-boxed recruiter build, no override on record | N0: one-shot demos are /frontend-design SAFE; artifex only on Christopher's explicit verbatim override | The §7 audit header Surface + Override lines |

---

> Don't hold back. Award-caliber means committing fully to a distinctive vision, but `/artifex`'s discipline is that the distinctiveness is **engineered and audited**, not improvised. Variance you can prove beats "engaging" you can only assert.
