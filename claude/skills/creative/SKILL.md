---
name: creative
description: "Generate high-quality design assets FROM SCRATCH (social graphics, illustrations, logos, banners, icons, mockups) via AI image generation with multi-model routing and a hard anti-AI-slop bar. Use when the user asks to create/design/generate a visual asset with no reference to match. For reference-driven or style-match work (a supplied reference image, 'make it look like X'), use /zografee instead."
argument-hint: "[description of the asset to create]"
---

## Overview

Multi-phase design loop that generates professional-quality visual assets FROM SCRATCH. Routes to
the best available AI image model for each asset type, holds a HIGH quality bar (bad or ugly output
is worse than nothing), and enforces a 20-item anti-slop ban list. The verified primary engine is
Gemini (nanobanana) flash-ideate -> Pro-finalize; other lanes are availability-gated options.

**Two files back this skill. Load them at the moments named below, not all up front:**
- `references/models.md` - the full model surface: availability pre-flight, verified Gemini/MCP
  parameter reference, true-4K path, MCP-flaky fallback, the ban-to-phrase table, and the
  UNVERIFIED optional-lane recipes. Read it at Section 2 and at Phase 3.
- `design-theory.md` - 35 design theories across 5 tiers. **Mandatory full read before Phase 2.**

---

## Section 0 - ROUTING GATE + EXECUTION CONTEXT (read FIRST, every invocation)

Before any setup or generation, clear two gates: are you even the right skill, and are you running
in the right place?

### 0.1 Routing gate - is this a /creative job at all?

/creative owns **from-scratch generation** only. Match the request against this table BEFORE Phase 1.
Borderline reference cases round to /zografee.

| The request... | Route to | Why |
|---|---|---|
| supplies a reference image, OR says "match/like/in the style of <ref>" | **/zografee** (formal invocation) | reference fidelity is a different, opposite quality bar - see 0.2 |
| is a poster / editorial cover / key visual driven by a look to hit | **/zografee** | that is exactly zografee's measured-analysis pipeline |
| is web/app UI **code** (components, pages, a real frontend) | **/frontend-design** (safe) or **/artifex** (high-variance) | those emit code, not raster art |
| is a launch/promo **video** | **/lumiere** | video is its own pipeline |
| is a from-scratch **static asset** (social, illustration, logo, banner, icon, mockup) with no reference to match | **/creative** (this skill) | proceed to Phase 1 |

**HARD RULE - route reference-driven work to /zografee.** If the user hands you a reference image
or asks to match a reference/style, STOP and formally invoke `/zografee` (the Skill tool, not
"read its SKILL.md"). Do not run it through /creative's ban list.

### 0.2 The /zografee boundary - the 20 bans do NOT cross it

/creative's 20 hard bans (Section 1 / Phase 4) apply **ONLY to from-scratch generation.** zografee's
bar is the opposite: a strong, pre-vetted reference may legitimately use gradients, glow,
glassmorphism, sparkles - **fidelity, not avoidance, is the bar there.** Never grade
zografee-territory output against /creative's bans. Never fold zografee's machinery (measured
analysis, ledger, shadow judge, curation gate) into /creative - cite it, route to it, do not
rebuild it. (zografee engine + discipline: `~/.claude/skills/zografee/SKILL.md`.)

Brand-kit `references` are the ONE reference input /creative uses (Phase 1): they feed the Gemini
`reference_images[]` param for **style consistency**, never as a fidelity target. Wanting to hit a
reference precisely is zografee's job.

### 0.3 Execution context - you are the WORKER, not main

Per global CLAUDE.md ("Creative Tasks - ALWAYS Delegate"), every /creative invocation runs inside a
**delegated worker session**. Main (the command-center session) does DISCUSSION only and never runs
generation inline.

- **You EXECUTE directly. NEVER re-delegate.** If you received this brief, you are the delegation
  target - do the work here. Do not spawn another worker or invoke /creative again from inside itself.
- **NEVER set `WHATSAPP=1`.** That env is main-session-only (verified failure 2026-04-27). A worker
  with it steals main's inbound messages.
- **Approval gates run through the attn relay, not a direct DM.** When a phase says "present to the
  user / wait for approval" (Phase 2 concept, the Prototype Gate, Phase 4 pick), you send the images
  + your facet reads to **main via attn**; main relays to Christopher and relays his answer back. You
  never message Christopher directly.
- **If Christopher is AFK at a gate (proactive-AFK pattern):** do not stall silently and do not
  guess past a direction-sensitive gate. Park at the gate, checkpoint STATE.md (what is done, which
  variant paths are waiting, the exact question), report the block to main via attn, and hold. A
  1h-idle decision defaults only where the brief pre-authorized a default; aesthetic direction never
  auto-defaults.
- **Report back on completion.** Close the loop to main via attn with evidence: the final file
  paths, model used, dimensions, and the passed delivery-gate checklist (Phase 6).

---

## Section 1 - HARD RULES (NEVER / ALWAYS)

These are rejections and requirements, not suggestions. A violation means the work is not done.

1. **NEVER run /creative in main.** It runs in the delegated worker; the worker EXECUTES and NEVER
   re-delegates. NEVER set `WHATSAPP=1`. (0.3)
2. **ALWAYS route reference-driven / style-match requests to /zografee** (formal invocation). The 20
   bans do NOT apply to reference work; never grade zografee output against them. (0.1 / 0.2)
3. **ALWAYS run the availability pre-flight before routing to a lane** (`references/models.md` §1). A
   lane is usable only if its row passed THIS session. **NEVER reference `$BFL_API_KEY`** - it does
   not exist; the FLUX key is `$FLUX_API_KEY`.
4. **ALWAYS pass an explicit `output_path`** on every `gemini_generate_image` / `gemini_edit_image`
   call, pointing into the per-job dir. Omitting it dumps the file into
   `~/Documents/nanobanana_generated/` and it leaves the workflow.
5. **ALWAYS save deliverables into the persistent per-job directory** (not /tmp-only), and report the
   final paths as evidence in the attn completion report. (Phase 6)
6. **NEVER deliver an ImageMagick/Lanczos-upscaled image as high-res** - interpolation is fake
   resolution. True high-res = a `gemini-3-pro-image` 4K re-render via the zografee direct-REST
   `finalize()` (`references/models.md` §4). Flag that the Pro re-render slightly reinterprets the design.
7. **NEVER fix garbled/misspelled text by editing** - regenerate with the text re-specified in
   quotes. (Appendix C / `references/models.md` §3)
8. **NEVER ship generation #1.** Minimum 2 variants (3 for logos/icons), each critiqued against the
   facets before anything is shown upward.
9. **ALWAYS run the Prototype Gate for direction-sensitive assets** (anything where Christopher's
   aesthetic judgment decides): 2-3 cheap flash variants relayed for direction confirmation BEFORE
   extended refinement. Two verified full-build rejections exist because this was skipped. (Prototype Gate)
10. **ALWAYS prepend the negative block** (all 20 bans + archetype negatives, `references/models.md`
    §6) to every generation prompt, and **scan every output against all 20 bans.** ANY hit = reject +
    regenerate from a revised prompt. Never patch a ban violation by editing.
11. **NEVER use a non-Gemini curl recipe without a 1-image smoke test first this session.** The
    Recraft / GPT / FLUX payloads are UNVERIFIED; "Don't Hallucinate APIs" applies. (`references/models.md` §7)
12. **NEVER use monospace type outside a mono-identity archetype.** (Section: Vibe Archetypes)

---

## Section 2 - MODEL REALITY (verified engine, then the options)

Full detail lives in `references/models.md`. The load-bearing truth:

**Gemini (nanobanana) is THE engine. flash to ideate, Pro to finalize.** This is the ledger-verified
2026-06-16 architecture decision (17 decisions across 7 jobs): `gemini-3-pro-image` (Nano Banana
Pro) nails bold asymmetric composition, precise editorial type, AND exact supplied copy, in one
shot. The cost-smart pipeline is: **cheap flash for the ideation variants -> Christopher picks ->
Pro for the final** (4K via the zografee finalize path when hi-res is needed).

Everything else is an **availability-gated, explicitly-UNVERIFIED optional lane** - not an
equal-weight peer. Recraft (native SVG for logos/icons), GPT Image (`gpt-image-1`, best text
accuracy but conservative composition), and FLUX (`flux-pro-1.1`, photoreal mockups) are used only
after the availability pre-flight AND a 1-image smoke test pass this session. When unsure, Gemini.

**Availability pre-flight (run before routing - full commands in `references/models.md` §1):**

| Lane | Usable when | State 2026-07-03 |
|---|---|---|
| Gemini (nanobanana MCP) | `gemini_*` tools present | PRESENT (only installed MCP) |
| Recraft | recraft MCP tools present OR `RECRAFT_API_KEY` set | KEY SET; MCP not installed -> curl-only |
| GPT Image (curl) | `OPENAI_API_KEY` set | SET |
| FLUX (curl) | `FLUX_API_KEY` set | SET |

**Verified cost (the only numbers to trust):** flash `gemini-2.5-flash-image` $0.039/img · Pro
`gemini-3-pro-image` $0.134/img at 1K/2K, $0.24/img at 4K. A whole 7-job / ~100-image test phase
billed ~Rp 45.780 ≈ $2.80 (~$0.30-1.00 per finished job). Non-Gemini lane costs are UNVERIFIED.

**The output_path trap + no-4K-on-MCP fact:** the MCP tools default-save to
`~/Documents/nanobanana_generated/` and expose no size/4K parameter. ALWAYS pass `output_path`; for
true 4K use the zografee direct-REST `finalize()` (`references/models.md` §4).

**Verified nanobanana MCP surface (2026-07-03):** tools = `gemini_generate_image`, `gemini_edit_image`,
`set_model`, `set_aspect_ratio`, `gemini_chat`, `get_image_history`, `clear_conversation`.
`set_model` enum: `flash` (= `gemini-3.1-flash-image-preview`) / `pro` (= `gemini-3-pro-image-preview`).
**Valid `aspect_ratio` enum (the ONLY accepted values):** `1:1 · 9:16 · 16:9 · 3:4 · 4:3 · 3:2 · 2:3 ·
5:4 · 4:5 · 21:9`. `gemini_edit_image` accepts `image_path` as a file path, `"last"`, or `"history:N"`,
plus up to 10 `reference_images`. Full param table: `references/models.md` §3.

---

### MANDATORY - Load Design Theory Before Ideation

**Before Phase 2 (Design Concept), READ `~/.claude/skills/creative/design-theory.md` in full.** It
contains 35 design theories across 5 tiers (Visual Fundamentals, Color Theory, Typography, Layout &
Composition, Advanced Conceptual). Every design decision must be informed by these principles, and
every self-critique must evaluate against them. If a generated output violates Gestalt, hierarchy,
contrast, balance, or any core principle - reject and iterate. (design-theory.md is shared with
/zografee; it is an analysis aid, not a ban list.)

### MANDATORY - The Quality Bar (Uncommon Care + Keep Looking)

In the age of AI, passable imagery is free and therefore worthless. The only output worth delivering
makes a viewer ask "how did they make that?" Hold these as the mindset behind every phase below:

- **Uncommon care lives in the details a human would sweat.** What people remember are the touches
  someone did not have to add: the shadow that actually grounds the object, the one accent doing real
  work, type that is kerned and placed instead of dropped in. These are breadcrumbs that a person
  cared. Generic AI output gives up exactly where care would show, that gap is your opening.
- **Keep looking, your first reaction is shallow.** When you critique an output, do not stop at "it
  looks off." Name WHY, specifically: the focal point competes with the background, the dark tone
  went muddy-grey instead of a rich shade, two elements sit on slightly different invisible edges.
  Then keep looking, there is always a next finer flaw. Vague reactions cannot drive a regeneration;
  named ones can.
- **Generation #1 is almost never it.** Treat the first image as a draft to react against, not a
  candidate to ship. The gap between fine and great is how many intentional iterations you put in
  (Phase 5), not the luck of the first prompt.
- **Define the bar before you grade against it (facets).** For each asset, name 3 to 5 SITUATIONAL
  qualities the viewer should FEEL (e.g. a watch banner: "precise / restrained / covetable"; a
  kids-app sticker: "playful / friendly / energetic"). These are specific to this brief, not
  universals like "clean." Carry them into the Phase 4 critique as the sharpest scoring language you
  have.

### HARD BANS - Auto-Reject if ANY of These Appear

These are HARD REJECTIONS, not suggestions. If ANY of the following appear in generated output, the
output MUST be rejected and regenerated. No exceptions. Prepend these constraints to EVERY generation
prompt (the ban-to-phrase lookup + per-model formatting live in `references/models.md` §6).

1. **NO gradient backgrounds** of any kind (linear, radial, mesh - all banned)
2. **NO glow/aura/neon effects** behind text or elements
3. **NO drop shadows** on text or elements
4. **NO centered symmetric layouts** - every composition must be asymmetric
5. **NO generic sans-serif** - must specify exact style (condensed/extended/geometric/grotesque/humanist)
6. **NO 3D phone/laptop/device mockups** - no "app in a phone" templates
7. **NO floating UI elements** without spatial context or ground
8. **NO abstract blob shapes** - amorphous gradient blobs are banned
9. **NO isometric illustrations** - generic tech-startup isometric art is banned
10. **NO generic "tech" visuals** - circuits, binary code, particles, digital waves, matrix rain
11. **NO lens flare / light leaks** - photographic artifacts as decoration
12. **NO soft pastel color palettes** - washed-out pastels = generic
13. **NO rounded rectangle "app card" aesthetic** - the Dribbble-card template look
14. **NO glassmorphism/blur cards** - frosted glass overlays as a design crutch
15. **NO geometric pattern fills** - triangles/hexagons/dots as background texture
16. **NO starburst / radial burst** behind text or focal element
17. **NO stock photo compositing** - no pasted-in stock imagery
18. **NO generic icon grids** - grid of 6 identical-style icons with labels
19. **NO "SaaS landing page" template look** - if it looks like a Webflow template, reject
20. **NO decoration that doesn't serve a purpose** - every element must have a reason

**Self-critique checkpoint (the enforcement):** after EVERY generation, run a numbered pass/fail
sweep against ALL 20 bans. If even ONE appears, reject the output entirely and regenerate with an
explicitly revised prompt that names the specific violation. Do NOT attempt to fix via editing -
regenerate from scratch. (Scope reminder: these bans are for from-scratch /creative work only; they
do NOT apply to /zografee reference work - Section 0.2.)

**Building the negative block for a prompt (per `references/models.md` §6):**
1. Start with the archetype's negative keywords (Vibe Archetypes section).
2. Append ALL 20 hard-ban phrases (always, regardless of archetype).
3. Add any user-specified constraints.
4. Format for the target model (Gemini `Do not include:` block · GPT inline `Avoid:` · Recraft/FLUX
   `negative_prompt`).

---

## Interactive Setup

Before generating any asset, run this setup sequence. Present it conversationally - do not dump the
whole menu. (Relay is via main per Section 0.3.)

### Step 1: Mode Selection

| Mode | When to use |
|---|---|
| **New** | Creating from scratch - full creative latitude |
| **Redesign** | Existing asset needs a visual overhaul or style change |
| **Quick Polish** | Existing asset, minor adjustments - color, crop, text fix |
| **Surprise Me** | User trusts you completely - pick archetype, dials, everything |

### Step 2: Archetype Selection

Present the archetypes from the Vibe Archetypes section below, or let the user describe a custom
vibe. If "Surprise Me," pick the archetype that best fits their content/domain and commit fully.

### Step 3: Dial Confirmation

Present three dials with archetype defaults. Let the user override or accept.

| Dial | 1-3 | 4-7 | 8-10 |
|---|---|---|---|
| **DESIGN_VARIANCE** | Centered, symmetric, safe compositions | Offset focal points, asymmetric balance, rule-of-thirds | Extreme cropping, broken frames, overlapping elements, experimental |
| **MOTION_INTENSITY** | Static image, no implied movement | Dynamic angles, diagonal lines, implied velocity | Extreme perspective, motion blur, kinetic energy, explosive |
| **VISUAL_DENSITY** | Minimal elements, maximum negative space | Balanced composition, 3-5 elements | Dense, layered, information-rich, collage-like |

Default values by archetype:
- Ethereal Glass -> VARIANCE 5, MOTION 7, DENSITY 3
- Editorial Luxury -> VARIANCE 6, MOTION 4, DENSITY 4
- Soft Structuralism -> VARIANCE 4, MOTION 5, DENSITY 5
- Neo-Brutalist -> VARIANCE 8, MOTION 3, DENSITY 6
- Japanese Minimal -> VARIANCE 4, MOTION 2, DENSITY 1
- Magazine Editorial -> VARIANCE 7, MOTION 5, DENSITY 5
- Warm Craft -> VARIANCE 4, MOTION 4, DENSITY 4
- Dark Cinematic -> VARIANCE 6, MOTION 6, DENSITY 2
- Corporate Confident -> VARIANCE 3, MOTION 3, DENSITY 6
- Playful Pop -> VARIANCE 5, MOTION 8, DENSITY 5
- Gen Z Expressive -> VARIANCE 9, MOTION 9, DENSITY 8
- Anti-Design / Experimental -> VARIANCE 10, MOTION 7, DENSITY 4
- Custom -> ask the user or pick based on context

---

## Vibe Archetypes - Image Generation

Each archetype defines a complete visual system for generated images. Select one as the foundation,
then tune with dials.

**Monospace rule (hard, house-wide):** use a monospace face ONLY in a mono-IDENTITY archetype where
mono IS the aesthetic. Do not reach for mono as a default labeling/metadata/numeral language. In
every non-mono archetype, secondary text, labels, and figures use the archetype's sans (tracked
uppercase or tabular figures give the "technical" feel without mono). The only mono-identity
archetype below is **Neo-Brutalist** (raw/mechanical identity); Anti-Design MAY use mono only when
its type collage is explicitly mono-led. (Verified rule 2026-06-24.)

### 1. Ethereal Glass
**Mood**: Futuristic, clean, luminous | **Best for**: AI/tech products, SaaS, developer tools

| Element | Specification |
|---|---|
| **Palette** | Primary: #0A0A0A (near-black) · Secondary: #1A1A2E (deep navy) · Accent: #00D4FF (electric cyan) · BG: #000000 · Text: #E8E8E8 |
| **Typography direction** | Ultra-clean sans-serif, thin weight, wide letter-spacing. Light geometric/grotesque sans for secondary text (NOT monospace - this is not a mono-identity archetype). |
| **Composition** | Centered depth with layered planes receding into darkness. 16:9 or 1:1. Generous negative space. |
| **Positive keywords** | dark background, glass morphism, frosted surfaces, refracted light, holographic edges, depth layers, luminous accents, clean geometry, futuristic minimal, ambient glow, floating interface, crystalline, sharp edges, translucent panels, cool blue light |
| **Negative keywords** | warm colors, organic shapes, handwritten text, vintage, rustic, paper texture, wood, fabric, bright background, cluttered, busy pattern, retro, gradient rainbow |
| **Default dials** | VARIANCE 5, MOTION 7, DENSITY 3 |

### 2. Editorial Luxury
**Mood**: Refined, authoritative, timeless | **Best for**: Lifestyle brands, agencies, portfolios, fashion

| Element | Specification |
|---|---|
| **Palette** | Primary: #1A1A1A (near-black) · Secondary: #8B7355 (warm ochre) · Accent: #722F37 (burgundy) · BG: #FAF7F2 (warm cream) · Text: #2D2D2D |
| **Typography direction** | High-contrast serif at large scale, tight tracking. Thin sans-serif for secondary. Mixed weight contrast (hairline + bold). |
| **Composition** | Asymmetric, editorial grid. 2:3 or 4:5 portrait ratio. Strong diagonal or golden-section placement. Image-text overlap. |
| **Positive keywords** | editorial layout, magazine spread, luxury minimal, warm cream paper, serif typography, high contrast, asymmetric composition, golden ratio, negative space, sophisticated, matte finish, premium, understated, refined palette, art direction |
| **Negative keywords** | neon colors, digital effects, glow, gradient, centered layout, playful, cartoon, tech aesthetic, cold blue, geometric pattern, busy, icon grid, stock photo |
| **Default dials** | VARIANCE 6, MOTION 4, DENSITY 4 |

### 3. Soft Structuralism
**Mood**: Approachable, modern, trustworthy | **Best for**: Consumer apps, health/wellness, fintech, modern SaaS

| Element | Specification |
|---|---|
| **Palette** | Primary: #374151 (charcoal) · Secondary: #E5E7EB (silver) · Accent: #6366F1 (indigo) · BG: #F9FAFB (light grey) · Text: #111827 |
| **Typography direction** | Rounded grotesque sans-serif, medium weight. Generous line-height. Friendly but professional. |
| **Composition** | Structured grid with rounded containers. 1:1 or 16:9. Soft shadows define depth. Balanced, approachable density. |
| **Positive keywords** | soft shadows, rounded corners, approachable design, clean interface, muted palette, structured layout, diffused light, modern minimal, comfortable spacing, touchable surfaces, card-based layout, friendly, professional, balanced |
| **Negative keywords** | sharp edges, dark background, harsh contrast, neon, aggressive typography, experimental layout, grunge, distressed, vintage, extreme perspective, chaotic |
| **Default dials** | VARIANCE 4, MOTION 5, DENSITY 5 |

### 4. Neo-Brutalist
**Mood**: Raw, punk, unapologetic | **Best for**: Indie brands, punk/raw creative studios, anti-design agencies

| Element | Specification |
|---|---|
| **Palette** | Primary: #000000 (black) · Secondary: #FFFFFF (white) · Accent: #FF3333 (red) · BG: #D4D0CC (concrete grey) · Text: #000000 |
| **Typography direction** | Monospace primary is LEGITIMATE here (raw/mechanical is the identity). Grotesque display at extreme weights. Exposed grid structure visible. |
| **Composition** | Deliberately "broken" - overlapping elements, visible grid lines, raw edges. 1:1 or 4:5. High tension, no polish. |
| **Positive keywords** | brutalist design, raw concrete, exposed grid, monospace type, sharp corners, high contrast black white, intentionally broken layout, overlapping elements, anti-design, punk aesthetic, industrial, no decoration, stark, confrontational, visible structure |
| **Negative keywords** | soft shadows, rounded corners, gradient, glow, pastel, polished, refined, smooth, elegant, luxury, comfortable, warm, organic shapes, decoration |
| **Default dials** | VARIANCE 8, MOTION 3, DENSITY 6 |

### 5. Japanese Minimal
**Mood**: Serene, restrained, contemplative | **Best for**: High-end retail, ceramics, tea, luxury goods, artisanal products

| Element | Specification |
|---|---|
| **Palette** | Primary: #2B2B2B (charcoal) · Secondary: #8C8C8C (mid grey) · Accent: #3D4F7C (muted indigo) · BG: #FAF8F5 (warm off-white) · Text: #2B2B2B |
| **Typography direction** | Small body text (14px feel), extreme letter-spacing. Delicate serif for display. Thin weight throughout. Maximum restraint. |
| **Composition** | Extreme negative space (60%+ empty). Hairline borders. Single focal point. 2:3 portrait or square. Asymmetric but balanced. |
| **Positive keywords** | japanese minimalism, wabi sabi, negative space, rice paper texture, hairline borders, restrained palette, contemplative, serene composition, single focal point, delicate typography, muted earth tones, extreme simplicity, quiet design, artisanal, zen |
| **Negative keywords** | bold colors, large text, busy layout, decoration, gradient, glow, shadow, multiple focal points, bright accent, saturated, playful, energetic, dense, cluttered |
| **Default dials** | VARIANCE 4, MOTION 2, DENSITY 1 |

### 6. Magazine Editorial
**Mood**: Bold, dramatic, story-driven | **Best for**: Media, publishing, fashion, lifestyle magazines, content-heavy sites

| Element | Specification |
|---|---|
| **Palette** | Primary: #000000 (black) · Secondary: #FFFFFF (white) · Accent: #7A1B35 (burgundy) · BG: #FFFFFF · Text: #000000 |
| **Typography direction** | Bold serif display at extreme sizes. Mixed weights in same composition (hairline + black). Sans-serif body at small scale. Dramatic scale contrast. |
| **Composition** | Edge-to-edge imagery. Text overlapping images. Mixed column widths. 16:9 landscape or full-bleed. Pull quotes as design elements. |
| **Positive keywords** | magazine editorial, bold serif typography, dramatic scale contrast, full bleed image, text overlay, mixed column layout, fashion editorial, high contrast, oversized headline, pull quote, cinematic, story-driven layout, art directed, typographic hierarchy |
| **Negative keywords** | cards, rounded corners, soft shadows, icons, small text only, centered layout, muted colors, tech aesthetic, gradient, geometric pattern, uniform grid |
| **Default dials** | VARIANCE 7, MOTION 5, DENSITY 5 |

### 7. Warm Craft
**Mood**: Handmade, organic, inviting | **Best for**: Artisan brands, F&B, bakeries, handmade goods, wellness

| Element | Specification |
|---|---|
| **Palette** | Primary: #3E2723 (espresso) · Secondary: #3D5A3E (forest) · Accent: #C4704D (terracotta) · BG: #F4EDE4 (warm linen) · Text: #3E2723 |
| **Typography direction** | Warm serif for display (rounded terminals, organic curves). Friendly rounded sans body. Nothing sharp or geometric. |
| **Composition** | Rounded containers, organic shapes, hand-drawn accents. 1:1 or 4:5. Visible texture/grain. Warm and inviting density. |
| **Positive keywords** | artisan handmade, warm linen texture, kraft paper, terracotta earth tones, organic shapes, hand drawn illustration, rounded corners, soft shadows, cozy inviting, bakery cafe aesthetic, natural materials, visible grain texture, friendly typography, botanical |
| **Negative keywords** | cold colors, sharp edges, tech aesthetic, dark background, neon, geometric pattern, sterile, corporate, monospace, industrial, minimal stark, digital |
| **Default dials** | VARIANCE 4, MOTION 4, DENSITY 4 |

### 8. Dark Cinematic
**Mood**: Atmospheric, dramatic, immersive | **Best for**: Entertainment, film, music, gaming, nightlife, premium experiences

| Element | Specification |
|---|---|
| **Palette** | Primary: #0A0A0A (near-black) · Secondary: #1A1A1A (dark grey) · Accent: #D4A84B (amber) · BG: #000000 (OLED black) · Text: #E8E8E8 (cool white) |
| **Typography direction** | High-contrast serif for display (thin strokes + thick strokes). Minimal UI text in geometric sans. Sparse, widely spaced. |
| **Composition** | Content emerges from darkness. Cinematic letterboxing (horizontal bars). Single dramatic focal point. 21:9 or 16:9 widescreen. Film grain overlay. |
| **Positive keywords** | cinematic dark, film grain, OLED black, amber accent light, dramatic lighting, atmospheric fog, letterbox framing, slow reveal, high contrast serif, sparse text, moody, noir aesthetic, theatrical, immersive depth, spotlight effect |
| **Negative keywords** | bright background, pastel, playful, cute, rounded corners, soft shadows, busy layout, multiple colors, flat design, white space, clean minimal, corporate |
| **Default dials** | VARIANCE 6, MOTION 6, DENSITY 2 |

### 9. Corporate Confident
**Mood**: Professional, trustworthy, data-driven | **Best for**: Enterprise, B2B, consulting, fintech, legal, institutional

| Element | Specification |
|---|---|
| **Palette** | Primary: #1B2A4A (navy) · Secondary: #374151 (charcoal) · Accent: #0D9488 (teal) · BG: #F5F5F5 (light grey) · Text: #1B2A4A |
| **Typography direction** | Clean sans-serif only. No serif. Medium weight, tight but readable. Professional and invisible - typography should not draw attention. |
| **Composition** | Structured grid, consistent spacing. 16:9 or 1:1. Data visualization elements (charts, metrics, progress indicators). Clean, predictable hierarchy. |
| **Positive keywords** | corporate professional, clean grid layout, navy charcoal palette, data visualization, metric dashboard, structured composition, trust signals, enterprise design, subtle borders, consistent spacing, authoritative, institutional, organized, precise |
| **Negative keywords** | warm colors, organic shapes, handwritten, playful, experimental layout, bright accent, artistic, creative, texture, grain, serif, decorative, casual |
| **Default dials** | VARIANCE 3, MOTION 3, DENSITY 6 |

### 10. Playful Pop
**Mood**: Energetic, fun, vibrant | **Best for**: Kids/education, consumer social, gaming, creative tools, startup MVPs

| Element | Specification |
|---|---|
| **Palette** | Primary: #7C3AED (electric purple) · Secondary: #FF6B6B (coral) · Accent: #FBBF24 (sunny yellow) · BG: #FFF0F5 (rose pastel) · Text: #1A1A2E |
| **Typography direction** | Heavy weight geometric sans at oversized scale. Rounded terminals. Mixed sizes for playful hierarchy. Bold and unapologetic. |
| **Composition** | Chunky shapes, thick borders, hard-edge offset shadows. 1:1 or 4:5. 3-4 colors freely mixed. Illustrated characters or emoji accents. |
| **Positive keywords** | playful colorful, chunky shapes, thick borders, hard edge shadow, bouncy energetic, oversized typography, geometric bold, illustrated character, confetti, bright saturated palette, fun creative, youthful, dynamic composition, sticker aesthetic, cartoon |
| **Negative keywords** | dark background, muted colors, thin lines, minimal, serious, corporate, elegant, luxury, serif, restrained, monochrome, sparse, atmospheric, sophisticated |
| **Default dials** | VARIANCE 5, MOTION 8, DENSITY 5 |

### 11. Gen Z Expressive
**Mood**: Chaotic, dopamine-fueled, loud | **Best for**: Gen Z brands, TikTok-adjacent, youth culture, meme brands

| Element | Specification |
|---|---|
| **Palette** | Primary: #FF1493 (hot pink) · Secondary: #BFFF00 (electric lime) · Accent: #00BFFF (electric blue) · BG: #DFFF11 (acid yellow) · Text: #000000 |
| **Typography direction** | Clashing fonts - chunky sans (Clash Display, Space Grotesk 700) + display faces. All-caps. Sizes at 200%. Multiple fonts in one composition. Type collage. (Mono only if the collage is explicitly mono-led; otherwise no mono.) |
| **Composition** | Collage/scrapbook - overlapping elements, sticker graphics, layered chaos, zigzag lines. 1:1 or 9:16 (mobile-first). Dense, maximalist, no breathing room. |
| **Positive keywords** | gen z aesthetic, dopamine palette, neon colors, collage layout, sticker graphics, scrapbook texture, overlapping elements, maximalist design, TikTok energy, glitch effect, y2k nostalgia, intentional chaos, loud typography, mixed media |
| **Negative keywords** | minimal, restrained, elegant, corporate, muted colors, serif typography, clean grid, negative space, professional, sophisticated, calm, quiet, subtle, balanced |
| **Default dials** | VARIANCE 9, MOTION 9, DENSITY 8 |

### 12. Anti-Design / Experimental
**Mood**: Provocative, unconventional, challenging | **Best for**: Avant-garde studios, experimental portfolios, art galleries, rule-breaking agencies

| Element | Specification |
|---|---|
| **Palette** | Primary: #000000 (black) · Secondary: #FFFFFF (white) · Accent: #39FF14 (neon green) · BG: #0A0A0A (near-black) · Text: #FFFFFF |
| **Typography direction** | Deliberately uncomfortable - oversized bleeding text, rotated baselines, stacked characters, mixed serif + grotesque in same heading. Broken tracking. Mono is allowed ONLY when the collage is explicitly mono-led. |
| **Composition** | Zero-grid - elements at arbitrary positions, overlapping with no clear hierarchy. Single strip or unconventional scroll direction. Content revealed through interaction. 16:9 or non-standard ratios. |
| **Positive keywords** | anti-design, experimental layout, deconstructed typography, raw HTML aesthetic, scan line effect, grain noise overlay, zero grid, arbitrary placement, provocative composition, cursor-driven reveal, generative pattern, intentional glitch, JPEG artifact, brutalist digital |
| **Negative keywords** | organized, clean, structured grid, rounded corners, soft shadows, comfortable, approachable, professional, balanced layout, traditional nav, card-based, symmetrical, safe, predictable |
| **Default dials** | VARIANCE 10, MOTION 7, DENSITY 4 |

### Custom Vibe
When the user describes something that doesn't match an archetype, extract:
1. Color temperature (warm / cool / neutral)
2. Density feeling (sparse / balanced / dense)
3. Personality (serious / playful / luxe / raw / futuristic / organic)
4. Reference points (any styles, brands, or aesthetics they mention)

Build a complete palette + composition + keyword set from those constraints, following the same
structure as the archetypes above.

---

## Phase 1 - Brief Decomposition

Parse the user's request (or `$ARGUMENTS`) into structured parameters. If anything is ambiguous, ask
ONE round of clarifying questions (relayed via main per 0.3) - don't guess on critical dimensions.

Extract:

```
ASSET_TYPE:    social | illustration | logo | banner | icon | mockup | general
DIMENSIONS:    width x height (or aspect ratio) - must map to a valid Gemini aspect enum (§2)
MEDIUM:        digital (default) | print | web-optimized
BRAND:         load brand-kit.json if exists in cwd or project root
MOOD:          professional | playful | minimal | bold | elegant | technical | warm | cool
AUDIENCE:      who sees this (informs tone)
COMPOSITION:   what goes where (text placement, focal point, negative space)
TEXT_CONTENT:  any text that must appear IN the image (headlines, taglines, labels)
REFERENCES:    brand-kit reference images for CONSISTENCY only - if the user wants to MATCH a
               reference, STOP and route to /zografee (Section 0.1)
```

### Brand Kit Loading

Search for `brand-kit.json` in the current directory and up to 3 parent levels. If found, load it
and apply constraints:

```bash
find . -maxdepth 3 -name "brand-kit.json" -type f 2>/dev/null | head -1
```

Brand kit precedence: **the brand kit overrides the archetype's palette/typography.** Fields:
- `colors.primary` -> dominant color · `colors.secondary` -> accent
- `typography.heading` / `typography.body` -> specify in prompt (respect the mono rule)
- `tone` -> incorporate into style direction
- `avoid` -> add to negative constraints
- `references` -> pass as Gemini `reference_images[]` for style CONSISTENCY only (NOT a fidelity
  target - fidelity is /zografee). Template: `brand-kit-template.json` in this dir.

---

## Phase 2 - Design Concept (Text-First)

Before generating ANY image, write a design brief in prose. This is the creative direction - the
prompt comes from this, not from the raw user request. (Load design-theory.md in full FIRST.)

### Design Brief Template

```
## Design Concept: [working title]

**Asset type:** [social / illustration / logo / banner / icon / mockup]
**Dimensions:** [WxH or aspect ratio]
**Model:** [which lane and why - Gemini default; a non-Gemini lane only if pre-flight + smoke passed]
**Facets:** [the 3-5 situational qualities the viewer should FEEL - the Phase 4 scoring language]

### Color Palette
- Primary: [hex] - [rationale]
- Secondary: [hex] - [rationale]
- Accent: [hex] - [rationale]
- Background: [hex or description]

### Composition Plan
- [Layout - where is the focal point, how is space divided]
- [Visual hierarchy - what draws the eye first, second, third]
- [Negative space usage]

### Typography (if text in image)
- Headline: [font style, size relationship, placement]
- Body/tagline: [font style, placement] (respect the mono rule)
- Text content: "[exact text that must render]"

### Style Direction
- [Mood, aesthetic references, artistic approach - what it should FEEL like, not just look like]

### Constraints
- Must: [non-negotiable requirements]
- Avoid: [things to explicitly stay away from]
```

### Color Craft (apply when choosing the palette)

How to get richness WITHOUT the banned gradients/glow, through the palette itself. These translate
into both the brief rationale and the generation prompt:

- **Commit to ONE temperature**, neutrals included. A warm palette wants warm-leaning greys and
  off-whites; a cool one wants cool. The most common amateur tell is a cool grey sitting in an
  otherwise warm composition. Pick warm or cool and hold it across every swatch. (Builds on
  design-theory #11.)
- **Build rich shades, not muddy ones.** A darker version of a color should shift its hue slightly
  and GAIN saturation, never just fade toward grey. In prompt language: "deep saturated [hue]
  shadows, hue-shifted toward [neighbor], not washed-out grey." This is what separates a
  premium-looking dark from a dead one.
- **Balance PERCEIVED brightness, not nominal value.** Equal-value colors do not read equally bright
  (a blue reads darker than a yellow-green at the same value). When two or more accents must feel
  equal-weight, balance them by how bright they LOOK, or one silently dominates the composition. When
  you want one accent to lead, make that intentional, not an accident of hue.

**Present the concept upward (relay via main per 0.3). Wait for approval before generating.** If they
say "go" or "looks good," proceed to Phase 3. If they adjust, revise the concept first.

---

## Phase 3 - Model Selection + Prompt Engineering

### Routing Logic

Gemini flash->Pro is the VERIFIED default for social / illustration / banner / general. The other
lanes are optional and used only if the availability pre-flight AND a 1-image smoke test pass this
session (`references/models.md` §1, §7). If any optional lane fails, Gemini is the fallback for
every asset type.

| Asset Type | Primary lane | Fallback | Notes |
|---|---|---|---|
| `social` | **Gemini** (flash-ideate -> Pro-final) | Gemini | Gemini executes bold composition best; GPT softens everything |
| `illustration` | **Gemini** (flash -> Pro) | Gemini | |
| `logo` | Recraft V4 (SVG) IF pre-flight+smoke pass | Gemini (raster, warn) | production logos need manual vectorization |
| `banner` (text-heavy) | **Gemini Pro** | GPT `gpt-image-1` IF smoke passes | Gemini renders type hierarchy well AND keeps exact copy |
| `icon` | Recraft V4 (SVG) IF pre-flight+smoke pass | Gemini (raster, warn) | |
| `mockup` (photoreal) | FLUX `flux-pro-1.1` IF pre-flight+smoke pass | Gemini Pro | |
| `general` | **Gemini** (flash -> Pro) | GPT IF smoke passes | |

### Model Temperament (learned from testing - keep)

- **Gemini** (best for bold design): executes dramatic compositional choices (oversized cropped
  type, extreme scale contrast); follows asymmetric layout instructions; good bold/thin weight
  contrast; responds to design-theory language ("Swiss typographic", "brutalist", "Z-pattern"); keeps
  EXACT supplied copy verbatim when prompted explicitly; conversation_id reuse holds style
  consistency. Prefer fresh generation over edit mode for a NEW composition (edits can introduce
  artifacts) - but the refine-the-PICK pass (Phase 5) IS an edit, on purpose.
- **GPT Image (`gpt-image-1`)**: precise but conservative - softens edges, plays it safe with
  composition, won't crop type at frame edges, warm-shifts white toward cream (ignores "pure white").
  Good for structured multi-text layouts where every word must be accurate. UNVERIFIED lane.
- **Recraft V4**: cleanest rendering, no artifacts, native SVG - but typographically flat (weak
  bold/thin contrast). Good for icons and brand-consistent vectors. UNVERIFIED lane; the exact
  style-param behavior is smoke-test-resolved (`references/models.md` §7c).
- **FLUX (`flux-pro-1.1`)**: photoreal, optical realism - but treats text as texture (bad at type).
  UNVERIFIED lane.

### Prompt Construction

Build the generation prompt from the Phase 2 concept. Never pass the raw user request directly.
**Describe a DESIGNED COMPOSITION, not "a social media post."**

**Prompt structure (SPATIAL-FIRST - describe WHERE things go, not just WHAT):**
1. Background treatment (color, texture - specify grain/noise for depth)
2. Hero element with EXACT spatial placement ("upper-left 40% of frame", "cropped by top edge")
3. Secondary elements with size relationships ("25% the visual size of hero")
4. Accent elements with precise coordinates and dimensions ("teal bar, 3px tall, 38% width, from 4% left margin")
5. Brand/info elements with alignment rules ("left-aligned to same 4% margin", "right-aligned bottom-right")
6. Spatial structure description ("Z-pattern reading path", "strong left-axis alignment", "intentional negative space in center")
7. Anti-patterns to avoid (the negative block - `references/models.md` §6)
8. Style references (name specific studios/brands: "Experimental Jetset", "Linear.co", "Spin Studio")

**Key lessons from testing:**
- Describe designs as "poster compositions" not "social media posts" - avoids generic templates.
- Specify precise margins and percentages - models follow spatial instructions.
- Name specific typeface styles ("ultra-bold condensed grotesque", "hairline weight") not just "bold"/"thin".
- The phrase "cropped by the edge of the frame" is understood by Gemini - use it for dramatic oversized type.
- Include design-theory language - Gemini responds to "Gestalt closure", "Z-pattern", "scale contrast".
- End with strong negative constraints - models follow "NO glow" more reliably than "subtle"/"minimal".

### Compositing & Depth (mockups + realistic illustration ONLY)

Think of a composition as an ordered STACK of layers (background plane -> mid -> focal subject ->
highlights) and build depth through the stack, not a single flat scene. For photorealistic mockups
(FLUX) and illustrations meant to read as real lit objects, these are the difference between flat and
believable. **They do NOT override the hard bans for flat graphics, posters, and social, where
decorative glow/gradient/drop-shadow stay banned** - they apply only to imagery that is supposed to
look like a real, lit thing:

- **Shadows = a tight CONTACT shadow plus a soft AMBIENT falloff.** A single floating drop shadow
  reads fake (and is the banned decorative kind); a grounded contact-plus-ambient pair reads real.
  Prompt it: "grounded contact shadow where it meets the surface, soft ambient occlusion, object
  sitting ON the surface, not floating."
- **Specular highlights sell the material.** Metal, glass, ceramic, and gloss each catch light
  differently - name the material AND its highlight: "sharp specular on the polished edge, soft sheen
  across the matte body."
- **One light direction, and everything agrees with it.** Name the key light (direction + warmth) and
  make every shadow and highlight consistent with it. Inconsistent light direction is the number-one
  realism tell.
- **Natural edges beat geometric cuts.** A torn, worn, or scratched edge reads more real than a hard
  clip - describe the edge QUALITY, not just the shape.

**Read the prompt template file** for the selected asset type (each has model-specific patterns +
known-good modifiers + good/bad examples + a quality checklist):
- `~/.claude/skills/creative/prompts/social.md` · `illustration.md` · `logo.md` · `banner.md` · `icon.md` · `mockup.md`

### Gemini adapter (nanobanana MCP - the primary path)

```
1. set_aspect_ratio -> one of the valid enum values (§2 / references/models.md §3)
2. set_model -> "flash" for ideation variants, "pro" for the final
3. gemini_generate_image -> constructed prompt + negative block, ALWAYS with output_path=<job-dir>/variants/<name>.png
4. reference_images -> brand-kit refs for consistency (optional); conversation_id -> reuse across the job
5. Refine the PICK (Phase 5) -> gemini_edit_image (image_path "last" or the file path), ALWAYS with output_path
```

Gemini responds well to descriptive, conversational prompts - include mood and context, not just
visual specs. Full parameter reference + the non-Gemini curl recipes (UNVERIFIED, smoke-test-first):
`references/models.md` §3, §7.

---

## Phase 4 - Generate + Self-Critique

### Generation

1. Create the per-job directory (persistent, NOT /tmp-only). Prefer the user's project dir; else a
   stable workspace path. Convention:
   ```bash
   JOB_DIR="<project-or-workspace>/creative-<slug>-$(date +%Y%m%d)"
   mkdir -p "$JOB_DIR/variants" "$JOB_DIR/finals"
   ```
2. Generate **minimum 2 variations** (3 for logos/icons where consistency matters) with the selected
   lane. On every Gemini call **pass `output_path="$JOB_DIR/variants/<asset>-<variant>.png"`** - never
   rely on the default save dir (Hard Rule 4).
3. Keep provenance: note which prompt produced which file (a one-line log per variant in the job dir).

### Self-Critique (facets FIRST, then the rubric)

After generation, run the 20-ban scan (Section 1 / HARD BANS) - any hit = reject + regenerate. Then
evaluate BRUTALLY. **Be harsh - if you wouldn't post it on Dribbble, it's not an 8.**

**First, grade the FACETS, then the generic criteria.** Re-state the 3 to 5 situational facets you
named for this asset (Phase 2), and score the image against EACH on a 1 to 5 scale. The generic table
below catches slop; the facets catch whether it nails THIS brief specifically ("it is clean, but it
is not COVETABLE, which was the whole point"). Then keep looking: name the single biggest flaw,
fix-target it in the next prompt, and after that flaw name the next one. Stop only when the facets AND
the criteria both clear the bar.

| Criterion | What to check | Common failure |
|---|---|---|
| **AI Slop Test** | Does this look AI-generated? Glow, generic gradients, centered-everything, stock-photo feel? If YES to ANY -> score 1-3. | The #1 failure mode. Most AI output fails here. |
| **Composition** | Intentional layout? Asymmetric or deliberately composed? Grid-aligned? Or "stuff in the middle"? | Centered-everything = max 4/10 |
| **Typography hierarchy** | Multiple sizes/weights/cases? Real hierarchy like a magazine? | Single-weight bold text = max 4/10 |
| **Color strategy** | Color used surgically (accent line, one element) or sprayed everywhere? | Glow effects = max 3/10 |
| **Negative space** | Whitespace/darkspace intentional and structured? | Empty background != good negative space |
| **Distinctiveness** | Could you tell this is for THIS brand without reading the text? | Generic = max 5/10 |
| **Technical quality** | Artifacts, distortion, broken text, weird elements? | |
| **Text accuracy** | Spelled correctly? Legible? Well-placed? | |

**Scoring (CALIBRATED - be honest):**
- 9-10: Portfolio-worthy. A designer would be proud. Extremely rare from AI.
- 7-8: Good design with minor issues. Passes the "would I post this?" test.
- 5-6: Mediocre. Some design thinking but also AI slop patterns.
- 3-4: Bad. Generic AI output with centered text and glow effects.
- 1-2: Embarrassing. Would damage the brand if posted.

**The old output that was scored 8.7/10 was actually a 3/10.** Recalibrate. Most AI image output is
3-5/10 on this scale. A 7+ should be genuinely impressive.

**REJECT THRESHOLDS:** below 6 -> regenerate with a FUNDAMENTALLY different prompt (not tweaks).
Below 4 -> switch models (down the fallback chain, ending at Gemini).

Present the critique + the images upward (relay via main per 0.3). Let Christopher pick which
variation to refine (Prototype Gate below governs WHEN to relay).

---

## Prototype Gate (between Phase 4 and Phase 5 - direction-sensitive assets)

**HARD RULE 9.** For any asset where Christopher's aesthetic judgment is the deciding factor (brand
marks, hero/marketing visuals, a look he'll react to on sight), you MUST confirm DIRECTION on cheap
flash variants BEFORE spending on extended refinement or Pro-quality finals. Two verified full-build
rejections happened because a whole build shipped down a direction he had not endorsed
(`feedback_prototype_first_for_creative_tasks`).

The gate:
1. Produce **2-3 flash ideation variants**, each a genuinely DIFFERENT direction (not three
   near-identical takes) - breadth is the hedge against narrow taste.
2. Relay them to main via attn with your facet reads and the named flaw of each.
3. **Require an explicit direction pick** ("variant B, lighter overall") before any Pro-quality spend
   or a >3-round refine.
4. If Christopher is AFK: park at the gate, checkpoint STATE.md (variant paths + the exact question),
   report blocked to main. Do NOT proceed past the gate on a guess. (proactive-AFK pattern, 0.3.)

**Relax to a single-variant fast path ONLY for internal-only assets for Toper** (non-customer-facing,
where he is not reacting to a look). Even then, NEVER relax the 20-ban scan or the text verification.

---

## Phase 5 - Iterative Refinement

Take the chosen variation and refine it. Maximum 3 refinement cycles.

**The refine move = edit the PICK, don't re-roll it.** Refining a variant Christopher chose means a
targeted edit on THAT PNG so his choice is preserved:
- **Gemini:** `gemini_edit_image` on the chosen file (or `"last"`), edit_prompt "keep composition +
  exact text, polish X", **with `output_path`**. This is the intentional edit pass (distinct from the
  "prefer fresh generation" rule, which is about NEW compositions). Multi-turn chat for complex edits.
- **GPT Image (UNVERIFIED):** `/v1/images/edits` with the image as input; supports a mask for
  targeted edits.
- **Recraft (UNVERIFIED):** no native edit - regenerate with an adjusted prompt (or `image_to_image`
  if the MCP exposes it).
- **FLUX (UNVERIFIED):** regenerate with a refined prompt (Kontext edit endpoint if available).

### What to Refine
Focus on the lowest-scoring facet/criterion:
- Color issues -> adjust palette in prompt, specify hex values
- Composition -> describe spatial relationships more precisely
- Text errors -> **regenerate** with exact spelling re-quoted (NEVER edit garbled text - Hard Rule 7)
- Technical artifacts -> regenerate at higher quality
- Style mismatch -> add/remove style modifiers

### When to Stop
- All criteria score 7+ AND at least 3 criteria score 8+, OR
- The user says they're happy, OR
- You've hit 3 refinement cycles (diminishing returns -> offer to restart with a different approach).

---

## Phase 6 - Quality Gate + Delivery

### Delivery Gate Checklist (every box must pass - any unchecked = NOT done)

- [ ] **Text verified letter-by-letter** (for any asset with text)
- [ ] **20-ban scan clean** on the final output
- [ ] **Facets + 1-10 rubric cleared** (all criteria 7+, at least 3 at 8+)
- [ ] **Files at persistent job-dir paths** (not /tmp-only; every Gemini call used `output_path`)
- [ ] **Dimensions match spec** (and, if hi-res was requested, it is a real Pro 4K re-render, not a
      Lanczos upscale - Hard Rule 6)
- [ ] **attn completion report sent to main** with the evidence paths, model used, dimensions

**Text-measure verification:** if type placement/scale was specified numerically, view the trimmed
crop before trusting any measurement (the `-threshold -trim` silent-miss trap and the native-scale
compare discipline are documented in /zografee's measured-analysis section - cite it, don't duplicate).

### Final Assessment - present this upward

```
## Final Output

**File(s):** [persistent job-dir paths]
**Model used:** [lane + model id]
**Dimensions:** [WxH]  ·  **Format:** [PNG/SVG/JPG]

### Design Rationale
[Why these colors, this composition, this style - the creative decisions]

### Quality Scores
| Criterion | Score |
|---|---|
| Color harmony | X/10 |
| Visual hierarchy | X/10 |
| Composition | X/10 |
| Brand alignment | X/10 |
| Technical quality | X/10 |
| Text accuracy | X/10 (or N/A) |
| Professional polish | X/10 |
| **Overall** | **X/10** |
```

### Output Organization
- `"$JOB_DIR/variants/"` - all ideation + refinement variants (provenance trail)
- `"$JOB_DIR/finals/"` - the delivered asset(s)
- For SVG outputs from Recraft, also provide the raw SVG path.
- The job dir is persistent - do not leave the only copy in /tmp.

### Post-Delivery Options
After delivery, offer (relayed via main):
- "Want me to adjust anything?" -> back to Phase 5
- "Want variations in a different style?" -> back to Phase 2 with a new concept
- "Want this in different sizes?" -> regenerate with adjusted dimensions (valid aspect enum)
- "Want this at true 4K?" -> Pro 4K re-render via the zografee finalize path (`references/models.md` §4)
- "Want to save the brand kit?" -> offer to create/update brand-kit.json

---

## Failure-Mode Playbooks (exact recovery)

**nanobanana MCP flaky.** A tool errors twice in a row on the same call -> switch to direct REST via
`~/claude/Git/repositories/zografee/engine/gemini.py` (`generate()` / `edit()`; retry-on-transient
503/429/5xx with backoff is built in; key resolves automatically, never printed). **Never conclude
"Gemini is down" from a single MCP failure**, and never hand-abort a transient 503 - the engine owns
retries. Detail: `references/models.md` §5.

**Garbled / misspelled text.** Regenerate, never edit. Keep text 1-5 words, in quotes, with placement
stated. For text-critical multi-slot layouts, consider the GPT lane - but ONLY after its smoke test
passes this session (Hard Rule 11).

**Need higher resolution than the MCP gives.** Do NOT Lanczos-upscale and call it hi-res (Hard Rule
6). Pro 4K re-render of the APPROVED variant via the zografee `finalize()` path (image passed as
input + "keep design/text, maximize resolution"). Warn that Pro reinterprets slightly; if
pixel-identical-but-bigger is required, say so honestly - no local upscaler (Real-ESRGAN) is installed.

**A lane is unavailable / smoke test fails.** Fall back down the asset-type chain; every chain ends at
Gemini. Falling back from Recraft on logos/icons -> WARN raster-not-vector and state that production
logos need manual vectorization (keep the warnings in `prompts/logo.md` + `prompts/icon.md`).

**Secrets hygiene.** Keys are only ever referenced as env vars - never echo a key. curl responses may
contain signed URLs; extract the file, never paste the full response into a report. If you ever see a
captured secret in a data/ledger file, report the file + pattern type only, never the value.

---

## Appendix A - Recraft MCP Installation (corrected)

Recraft MCP is NOT installed. The corrected install + smoke test lives in `references/models.md` §7d.
The one-liner: `claude mcp add recraft -- npx @recraft-ai/mcp-recraft-server@latest` (writes to
`~/.claude.json`, requires a Claude Code restart, `RECRAFT_API_KEY` already SET). The old
`~/.claude/settings.json` `mcpServers` variant is DEAD - settings.json has no `mcpServers` key
(verified 2026-07-03); do not write one there. Verify the recraft tools appear after restart, then run
a 1-image smoke generation before routing any real job.

## Appendix B - Quality Anti-Patterns

Things that make AI-generated design assets look bad. Avoid these in prompts:

### Visual Anti-Patterns
- **Over-saturated colors** - dial back saturation, use muted/professional palettes
- **Too many elements** - less is more. Professional design is restraint.
- **Centered-everything syndrome** - asymmetric layouts feel more designed
- **Generic stock photo look** - specify concrete details (real locations, specific objects)
- **Gradient overload** - banned outright here (Ban #1); richness comes from the palette, not gradients
- **Floating elements with no ground** - give elements context and spatial relationships
- **AI hands/fingers** - avoid compositions where hands are prominent
- **Tiny illegible text** - if text must appear, make it large and legible

### Prompt Anti-Patterns
- **"Beautiful, stunning, amazing"** - empty adjectives don't improve output
- **"HD, 4K, 8K, ultra-realistic"** - quality tags are mostly noise for modern models (real 4K is a
  Pro re-render, not a prompt tag - Hard Rule 6)
- **Conflicting styles** - don't ask for "minimalist AND detailed AND busy AND clean"
- **Overly long prompts** - for most models, 50-150 words is the sweet spot
- **Negative prompts as primary direction** - describe what you WANT, then add the negative block

## Appendix C - Text Rendering Tips

Text in AI images is the hardest thing to get right. Follow these rules:

1. **Keep text short** - 1-5 words renders best. Longer text = more errors.
2. **Put text in quotes** in the prompt - `with the text "SALE"` not `with the text SALE`.
3. **Specify placement** - "centered headline text" or "text in the upper third".
4. **Use Gemini Pro (or the GPT lane if smoke-passed) for text-heavy assets** - they understand text
   semantically. Gemini Pro keeps exact supplied copy verbatim when prompted explicitly.
5. **Avoid FLUX for text** - it treats text as visual texture, not characters.
6. **Check every letter** after generation - text errors are the most common AI image failure mode.
7. **For logos with text, use Recraft (if available)** - vector output means text can be edited after.
8. **Regenerate rather than edit for text errors (HARD RULE 7)** - editing rarely fixes misspelled text.
