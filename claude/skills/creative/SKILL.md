---
name: creative
description: Generate high-quality design assets (social graphics, illustrations, logos, banners, icons, mockups) using AI image generation with multi-model routing. Use when the user asks to create, design, or generate visual assets.
argument-hint: [description of the asset to create]
---

## Overview

Multi-phase design loop that generates professional-quality visual assets. Routes to the best AI image model for each asset type. Quality bar is HIGH — bad or ugly output is worse than nothing.

### MANDATORY — Load Design Theory Before Ideation

**Before Phase 2 (Design Concept), READ `~/.claude/skills/creative/design-theory.md` in full.** This file contains 35 design theories across 5 tiers (Visual Fundamentals, Color Theory, Typography, Layout & Composition, Advanced Conceptual). Every design decision must be informed by these principles. Every self-critique must evaluate against them. If a generated output violates Gestalt, hierarchy, contrast, balance, or any core principle — reject and iterate.

### HARD BANS — Auto-Reject if ANY of These Appear

These are NOT suggestions — they are HARD REJECTIONS. If ANY of the following appear in generated output, the output MUST be rejected and regenerated. No exceptions. Prepend these constraints to EVERY generation prompt.

1. **NO gradient backgrounds** of any kind (linear, radial, mesh — all banned)
2. **NO glow/aura/neon effects** behind text or elements
3. **NO drop shadows** on text or elements
4. **NO centered symmetric layouts** — every composition must be asymmetric
5. **NO generic sans-serif** — must specify exact style (condensed/extended/geometric/grotesque/humanist)
6. **NO 3D phone/laptop/device mockups** — no "app in a phone" templates
7. **NO floating UI elements** without spatial context or ground
8. **NO abstract blob shapes** — amorphous gradient blobs are banned
9. **NO isometric illustrations** — generic tech-startup isometric art is banned
10. **NO generic "tech" visuals** — circuits, binary code, particles, digital waves, matrix rain
11. **NO lens flare / light leaks** — photographic artifacts as decoration
12. **NO soft pastel color palettes** — washed-out pastels = generic
13. **NO rounded rectangle "app card" aesthetic** — the Dribbble-card template look
14. **NO glassmorphism/blur cards** — frosted glass overlays as a design crutch
15. **NO geometric pattern fills** — triangles/hexagons/dots as background texture
16. **NO starburst / radial burst** behind text or focal element
17. **NO stock photo compositing** — no pasted-in stock imagery
18. **NO generic icon grids** — grid of 6 identical-style icons with labels
19. **NO "SaaS landing page" template look** — if it looks like a Webflow template, reject
20. **NO decoration that doesn't serve a purpose** — every element must have a reason

**Self-critique checkpoint:** After every generation, scan for ALL 20 bans. If even ONE appears, reject the output entirely and regenerate with an explicitly revised prompt that addresses the specific violation. Do not attempt to fix via editing — regenerate from scratch.

### Hard Bans → Negative Prompt Mapping

Wire the 20 hard bans into model-specific negative prompt formatting. Every generation prompt MUST include the relevant negative phrases.

#### Ban-to-Phrase Lookup Table

| # | Ban | Negative Prompt Phrase |
|---|---|---|
| 1 | No gradient backgrounds | "no gradient backgrounds, no color transitions, no gradient overlays, no linear gradient, no radial gradient, no mesh gradient" |
| 2 | No glow/aura/neon effects | "no glow, no neon glow, no luminous edges, no light emission effects, no aura, no outer glow, no bloom" |
| 3 | No drop shadows | "no drop shadow, no floating shadow, no box shadow effects, no shadow beneath text" |
| 4 | No centered symmetric layouts | "no centered layout, no symmetrical composition, no perfectly balanced, no mirror symmetry" |
| 5 | No generic sans-serif | "no generic font, no default typography, no Arial, no Helvetica, no system font" |
| 6 | No 3D device mockups | "no phone mockup, no laptop mockup, no device frame, no app-in-phone template, no 3D device" |
| 7 | No floating elements without context | "no floating elements, no objects without ground, no disconnected elements, no elements in void" |
| 8 | No abstract blob shapes | "no amorphous blobs, no gradient blobs, no abstract organic shapes, no floating blob shapes" |
| 9 | No isometric illustrations | "no isometric, no isometric illustration, no 3D isometric view, no isometric tech art" |
| 10 | No generic tech visuals | "no circuit board, no binary code, no digital particles, no matrix rain, no digital wave, no tech pattern" |
| 11 | No lens flare / light leaks | "no lens flare, no light leak, no photographic artifact, no bokeh overlay, no light streak" |
| 12 | No soft pastel palettes | "no washed out pastel, no soft pastel colors, no muted baby colors, no faded pastel" |
| 13 | No rounded rectangle app cards | "no app card, no rounded rectangle card, no Dribbble card layout, no card-based template" |
| 14 | No glassmorphism blur cards | "no frosted glass overlay, no glassmorphism card, no blur card background, no transparent blur panel" |
| 15 | No geometric pattern fills | "no triangle pattern, no hexagon pattern, no dot grid background, no geometric texture fill" |
| 16 | No starburst / radial burst | "no starburst, no radial burst, no sunburst behind text, no radial lines, no explosion lines" |
| 17 | No stock photo compositing | "no stock photography, no pasted-in photo, no composite stock image, no generic stock people" |
| 18 | No generic icon grids | "no icon grid, no grid of icons with labels, no feature icon layout, no uniform icon set" |
| 19 | No SaaS landing template look | "no website template, no Webflow template, no SaaS landing page, no generic web layout" |
| 20 | No purposeless decoration | "no decorative elements, no unnecessary ornament, no filler decoration, no pointless embellishment" |

#### Model-Specific Formatting

**Gemini (nanobanana MCP):**
Append to the generation prompt as a "Do not include" block:
```
Do not include: [comma-separated list of relevant negative phrases from table above]
```

**Recraft V4:**
If the API supports `negative_prompt` parameter, pass as:
```json
{ "negative_prompt": "[comma-separated negative phrases]" }
```
If not supported, inline in prompt: "Avoid: [phrases]"

**GPT Image (OpenAI API):**
Inline directly in the prompt text as an "Avoid" section:
```
Avoid the following: [comma-separated negative phrases]
```

**FLUX.2 Pro (BFL API):**
Use the `negative_prompt` field:
```json
{ "negative_prompt": "[comma-separated negative phrases]" }
```

#### Usage

1. Start with the archetype's negative keywords (from Vibe Archetypes section)
2. Append ALL 20 hard ban phrases (always included, regardless of archetype)
3. Add any user-specified constraints
4. Format according to the target model's syntax above

### Available Models

| Model | MCP / API | Best For | Cost |
|-------|-----------|----------|------|
| **Gemini NB2/Pro** | nanobanana MCP (installed) | Social graphics, general illustrations, text-heavy | $0.045-0.134/img |
| **Recraft V4** | recraft MCP (install: `npx @recraft-ai/mcp-recraft-server@latest`) | Logos, icons, SVG vectors, brand assets | $0.04-0.30/img |
| **GPT Image 1.5** | `curl` OpenAI API (`$OPENAI_API_KEY`) | Text-heavy banners, iterative editing, highest overall quality | $0.009-0.133/img |
| **FLUX.2 Pro** | `curl` BFL API (`$BFL_API_KEY`) | Photorealistic mockups, product photography | $0.03-0.055/img |

### Model Availability Check

Before routing, verify which models are actually available:
1. **Gemini** — always available (nanobanana MCP installed). Check: `set_model` tool exists.
2. **Recraft** — check if `generate_image` tool from recraft MCP exists. If not, check `$RECRAFT_API_KEY` for curl fallback.
3. **GPT Image 1.5** — check `$OPENAI_API_KEY` in env. Use curl if available.
4. **FLUX.2** — check `$BFL_API_KEY` in env. Use curl if available.

If a model is unavailable, fall back to the next best option. Gemini is always the fallback.

---

## Interactive Setup

Before generating any asset, run this setup sequence. Present it conversationally — don't dump the whole menu.

### Step 1: Mode Selection

| Mode | When to use |
|---|---|
| **New** | Creating from scratch — full creative latitude |
| **Redesign** | Existing asset needs a visual overhaul or style change |
| **Quick Polish** | Existing asset, minor adjustments — color, crop, text fix |
| **Surprise Me** | User trusts you completely — pick archetype, dials, everything |

### Step 2: Archetype Selection

Present the archetypes from the Vibe Archetypes section below, or let the user describe a custom vibe. If "Surprise Me," pick the archetype that best fits their content/domain and commit fully.

### Step 3: Dial Confirmation

Present three dials with archetype defaults. Let the user override or accept.

| Dial | 1–3 | 4–7 | 8–10 |
|---|---|---|---|
| **DESIGN_VARIANCE** | Centered, symmetric, safe compositions | Offset focal points, asymmetric balance, rule-of-thirds | Extreme cropping, broken frames, overlapping elements, experimental |
| **MOTION_INTENSITY** | Static image, no implied movement | Dynamic angles, diagonal lines, implied velocity | Extreme perspective, motion blur, kinetic energy, explosive |
| **VISUAL_DENSITY** | Minimal elements, maximum negative space | Balanced composition, 3-5 elements | Dense, layered, information-rich, collage-like |

Default values by archetype:
- Ethereal Glass → VARIANCE 5, MOTION 7, DENSITY 3
- Editorial Luxury → VARIANCE 6, MOTION 4, DENSITY 4
- Soft Structuralism → VARIANCE 4, MOTION 5, DENSITY 5
- Neo-Brutalist → VARIANCE 8, MOTION 3, DENSITY 6
- Japanese Minimal → VARIANCE 4, MOTION 2, DENSITY 1
- Magazine Editorial → VARIANCE 7, MOTION 5, DENSITY 5
- Warm Craft → VARIANCE 4, MOTION 4, DENSITY 4
- Dark Cinematic → VARIANCE 6, MOTION 6, DENSITY 2
- Corporate Confident → VARIANCE 3, MOTION 3, DENSITY 6
- Playful Pop → VARIANCE 5, MOTION 8, DENSITY 5
- Gen Z Expressive → VARIANCE 9, MOTION 9, DENSITY 8
- Anti-Design / Experimental → VARIANCE 10, MOTION 7, DENSITY 4
- Custom → ask the user or pick based on context

---

## Vibe Archetypes — Image Generation

Each archetype defines a complete visual system for generated images. Select one as the foundation, then tune with dials.

### 1. Ethereal Glass
**Mood**: Futuristic, clean, luminous | **Best for**: AI/tech products, SaaS, developer tools

| Element | Specification |
|---|---|
| **Palette** | Primary: #0A0A0A (near-black) · Secondary: #1A1A2E (deep navy) · Accent: #00D4FF (electric cyan) · BG: #000000 · Text: #E8E8E8 |
| **Typography direction** | Ultra-clean sans-serif, thin weight, wide letter-spacing. Monospace for secondary text. |
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
| **Typography direction** | Monospace primary (raw, mechanical). Grotesque display at extreme weights. Exposed grid structure visible. |
| **Composition** | Deliberately "broken" — overlapping elements, visible grid lines, raw edges. 1:1 or 4:5. High tension, no polish. |
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
| **Typography direction** | Clean sans-serif only. No serif. Medium weight, tight but readable. Professional and invisible — typography should not draw attention. |
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
| **Typography direction** | Clashing fonts — chunky sans (Clash Display, Space Grotesk 700) + pixel fonts (VT323). All-caps. Sizes at 200%. Multiple fonts in one composition. Type collage. |
| **Composition** | Collage/scrapbook — overlapping elements, sticker graphics, layered chaos, zigzag lines. 1:1 or 9:16 (mobile-first). Dense, maximalist, no breathing room. |
| **Positive keywords** | gen z aesthetic, dopamine palette, neon colors, collage layout, sticker graphics, scrapbook texture, overlapping elements, maximalist design, TikTok energy, pixel font, glitch effect, y2k nostalgia, intentional chaos, loud typography, mixed media |
| **Negative keywords** | minimal, restrained, elegant, corporate, muted colors, serif typography, clean grid, negative space, professional, sophisticated, calm, quiet, subtle, balanced |
| **Default dials** | VARIANCE 9, MOTION 9, DENSITY 8 |

### 12. Anti-Design / Experimental
**Mood**: Provocative, unconventional, challenging | **Best for**: Avant-garde studios, experimental portfolios, art galleries, rule-breaking agencies

| Element | Specification |
|---|---|
| **Palette** | Primary: #000000 (black) · Secondary: #FFFFFF (white) · Accent: #39FF14 (neon green) · BG: #0A0A0A (near-black) · Text: #FFFFFF |
| **Typography direction** | Deliberately uncomfortable — oversized bleeding text, rotated baselines, stacked characters, mixed serif + grotesque + monospace in same heading. Broken tracking. |
| **Composition** | Zero-grid — elements at arbitrary positions, overlapping with no clear hierarchy. Single strip or unconventional scroll direction. Content revealed through interaction. 16:9 or non-standard ratios. |
| **Positive keywords** | anti-design, experimental layout, deconstructed typography, raw HTML aesthetic, scan line effect, grain noise overlay, zero grid, arbitrary placement, provocative composition, cursor-driven reveal, generative pattern, intentional glitch, JPEG artifact, brutalist digital |
| **Negative keywords** | organized, clean, structured grid, rounded corners, soft shadows, comfortable, approachable, professional, balanced layout, traditional nav, card-based, symmetrical, safe, predictable |
| **Default dials** | VARIANCE 10, MOTION 7, DENSITY 4 |

### Custom Vibe
When the user describes something that doesn't match an archetype, extract:
1. Color temperature (warm / cool / neutral)
2. Density feeling (sparse / balanced / dense)
3. Personality (serious / playful / luxe / raw / futuristic / organic)
4. Reference points (any styles, brands, or aesthetics they mention)

Build a complete palette + composition + keyword set from those constraints, following the same structure as the archetypes above.

---

## Phase 1 — Brief Decomposition

Parse the user's request (or `$ARGUMENTS`) into structured parameters. If anything is ambiguous, ask ONE round of clarifying questions — don't guess on critical dimensions.

Extract:

```
ASSET_TYPE:    social | illustration | logo | banner | icon | mockup | general
DIMENSIONS:    width x height (or aspect ratio)
MEDIUM:        digital (default) | print | web-optimized
BRAND:         load brand-kit.json if exists in cwd or project root
MOOD:          professional | playful | minimal | bold | elegant | technical | warm | cool
AUDIENCE:      who sees this (informs tone)
COMPOSITION:   what goes where (text placement, focal point, negative space)
TEXT_CONTENT:   any text that must appear IN the image (headlines, taglines, labels)
REFERENCES:    any reference images or style directions the user provided
```

### Brand Kit Loading

Search for `brand-kit.json` in the current directory and parent directories. If found, load it and apply constraints:

```bash
# Search pattern
find . -maxdepth 3 -name "brand-kit.json" -type f 2>/dev/null | head -1
```

Brand kit fields override defaults:
- `colors.primary` → use as dominant color
- `colors.secondary` → use as accent
- `typography.heading` → specify in prompt
- `tone` → incorporate into style direction
- `avoid` → add to negative constraints
- `references` → load as style references (if model supports reference images)

---

## Phase 2 — Design Concept (Text-First)

Before generating ANY image, write a design brief in prose. This is the creative direction — the prompt comes from this, not from the raw user request.

### Design Brief Template

```
## Design Concept: [working title]

**Asset type:** [social / illustration / logo / banner / icon / mockup]
**Dimensions:** [WxH or aspect ratio]
**Model:** [which model and why]

### Color Palette
- Primary: [hex] — [rationale]
- Secondary: [hex] — [rationale]
- Accent: [hex] — [rationale]
- Background: [hex or description]

### Composition Plan
- [Layout description — where is the focal point, how is space divided]
- [Visual hierarchy — what draws the eye first, second, third]
- [Negative space usage]

### Typography (if text in image)
- Headline: [font style, size relationship, placement]
- Body/tagline: [font style, placement]
- Text content: "[exact text that must render]"

### Style Direction
- [Mood, aesthetic references, artistic approach]
- [What this should feel like — not just look like]

### Constraints
- Must: [non-negotiable requirements]
- Avoid: [things to explicitly stay away from]
```

**Present the concept to the user.** Wait for approval before generating. If they say "go" or "looks good," proceed. If they adjust, revise the concept first.

---

## Phase 3 — Model Selection + Prompt Engineering

### Routing Logic

Select the model based on asset type AND available models:

| Asset Type | Primary Model | Fallback | Notes |
|------------|---------------|----------|-------|
| `social` | **Gemini Pro** (nanobanana) | Recraft V4 | Gemini executes bold compositions best. GPT Image softens everything. |
| `illustration` | Gemini Pro (nanobanana) | FLUX.2 | |
| `logo` | **Recraft V4** (SVG) | Gemini (raster, warn user) | |
| `banner` (text-heavy) | Gemini Pro | GPT Image 1.5 | Gemini renders type hierarchy better than GPT Image for bold layouts. |
| `icon` | **Recraft V4** (SVG) | Gemini (raster, warn user) | |
| `mockup` (photorealistic) | FLUX.2 Pro | Gemini Pro | |
| `general` | Gemini Pro (nanobanana) | GPT Image 1.5 | |

### Model Characteristics (Learned from Testing)

**Gemini Pro** (best for bold design):
- Executes dramatic compositional choices (oversized cropped type, extreme scale contrast)
- Follows asymmetric layout instructions well
- Good at bold/thin typographic weight contrast
- Responds to design-theory language ("Swiss typographic", "brutalist", "Z-pattern")
- Use fresh generation over edit mode — edits introduce artifacts
- Conversation ID reuse maintains style consistency

**GPT Image 1** (precise but conservative):
- Too conservative for bold layouts — softens edges, plays it safe with composition
- Better for precise text rendering when ALL text must be accurate
- Warm-shifts white to cream. Doesn't follow "pure white" instructions.
- Struggles with compositional risk (won't crop type at frame edges)
- Good for structured multi-text layouts where every word matters

**Recraft V4** (clean but flat):
- Cleanest rendering quality, no artifacts
- Best for flat graphic styles, vector output
- Lacks typographic drama — can't do bold/thin weight contrast well
- recraftv4 model doesn't support "digital_illustration" style — omit style parameter
- Good for icons and brand-consistent output

If the primary model is unavailable, use the fallback. For social graphics, ALWAYS use Gemini Pro — the bold compositional choices it enables are worth the occasional rendering imperfection.

### Prompt Construction

Build the generation prompt from the Phase 2 concept. Never pass the raw user request directly to the model. **Describe a DESIGNED COMPOSITION, not "a social media post."**

**Prompt structure (SPATIAL-FIRST — describe WHERE things go, not just WHAT):**
1. Background treatment (color, texture — specify grain/noise for depth)
2. Hero element with EXACT spatial placement ("upper-left 40% of frame", "cropped by top edge")
3. Secondary elements with size relationships ("25% the visual size of hero")
4. Accent elements with precise coordinates and dimensions ("teal bar, 3px tall, 38% width, from 4% left margin")
5. Brand/info elements with alignment rules ("left-aligned to same 4% margin", "right-aligned bottom-right")
6. Spatial structure description ("Z-pattern reading path", "strong left-axis alignment", "intentional negative space in center")
7. Anti-patterns to avoid ("NO glow, NO gradient, NO centered, NO decoration")
8. Style references (name specific studios/brands: "Experimental Jetset", "Linear.co", "Spin Studio")

**Key lessons from testing:**
- Describe designs as "poster compositions" not "social media posts" — avoids generic templates
- Specify precise margins and percentages — AI models follow spatial instructions
- Name specific typeface styles ("ultra-bold condensed grotesque", "hairline weight") not just "bold" or "thin"
- The phrase "cropped by the edge of the frame" is understood by Gemini — use it for dramatic oversized type
- Include design theory language — Gemini responds to "Gestalt closure", "Z-pattern", "scale contrast"
- End with strong negative constraints — models follow "NO glow" more reliably than "subtle" or "minimal"

**Read the prompt template file** for the selected asset type:
- `~/.claude/skills/creative/prompts/social.md`
- `~/.claude/skills/creative/prompts/illustration.md`
- `~/.claude/skills/creative/prompts/logo.md`
- `~/.claude/skills/creative/prompts/banner.md`
- `~/.claude/skills/creative/prompts/icon.md`
- `~/.claude/skills/creative/prompts/mockup.md`

Each template has model-specific prompt patterns and known-good modifiers.

### Model-Specific Prompt Adapters

#### Gemini (nanobanana MCP)

```
1. Set aspect ratio: use set_aspect_ratio tool
2. Set model: use set_model tool (flash for speed, pro for quality)
3. Generate: use gemini_generate_image with the constructed prompt
4. Edit: use gemini_edit_image for refinements (supports "last" as image ref)
```

Key: Gemini responds well to descriptive, conversational prompts. Include mood and context, not just visual specs. Use the chat tool for multi-turn refinement.

#### Recraft V4 (MCP or curl)

If Recraft MCP is available, use `generate_image` tool with:
- `style`: realistic_image, digital_illustration, vector_illustration, icon
- `substyle`: as appropriate
- `model`: recraftv4 or recraftv4_vector (for SVG)
- `colors`: array of hex values from brand kit

If MCP unavailable, use curl:
```bash
curl -s -X POST "https://external.api.recraft.ai/v1/images/generations" \
  -H "Authorization: Bearer $RECRAFT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "...",
    "model": "recraftv4_vector",
    "style": "vector_illustration",
    "size": "1024x1024",
    "response_format": "url"
  }' | jq -r '.data[0].url'
```

Download the result:
```bash
curl -s -o "/tmp/creative-output/[name].svg" "[url from above]"
```

#### GPT Image 1.5 (curl)

```bash
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-1",
    "prompt": "...",
    "size": "1024x1024",
    "quality": "medium",
    "n": 1,
    "output_format": "png"
  }'
```

Response contains base64 image data — decode and save:
```bash
echo "$base64_data" | base64 -d > "/tmp/creative-output/[name].png"
```

Key: GPT Image excels with detailed, structured prompts. Be very specific about text placement, font style, and layout. Use "quality": "high" only when final output — use "medium" for iterations.

#### FLUX.2 Pro (curl — async)

```bash
# Submit job
TASK_ID=$(curl -s -X POST "https://api.bfl.ai/v1/flux-pro-1.1" \
  -H "x-key: $BFL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "...",
    "width": 1024,
    "height": 1024
  }' | jq -r '.id')

# Poll for result (wait 5s between polls, max 60s)
for i in $(seq 1 12); do
  RESULT=$(curl -s "https://api.bfl.ai/v1/get_result?id=$TASK_ID" \
    -H "x-key: $BFL_API_KEY")
  STATUS=$(echo "$RESULT" | jq -r '.status')
  if [ "$STATUS" = "Ready" ]; then
    URL=$(echo "$RESULT" | jq -r '.result.sample')
    curl -s -o "/tmp/creative-output/[name].png" "$URL"
    break
  fi
  sleep 5
done
```

Key: FLUX prompts should be photographic in nature — describe the scene as if directing a photographer. Include camera angle, lens type, lighting setup, depth of field. Avoid abstract style descriptors.

---

## Phase 4 — Generate + Self-Critique

### Generation

1. Create output directory: `mkdir -p /tmp/creative-output`
2. Generate 2 variations using the selected model (3 if logos/icons where consistency matters)
3. Save with descriptive names: `/tmp/creative-output/[asset-type]-[variant]-[timestamp].png`

### Self-Critique

After generation, evaluate BRUTALLY against these criteria. Score 1-10. **Be harsh — if you wouldn't post it on Dribbble, it's not an 8.**

| Criterion | What to check | Common failure |
|-----------|---------------|----------------|
| **AI Slop Test** | Does this look AI-generated? Glow effects, generic gradients, centered-everything, stock-photo-feel? If YES to ANY → score 1-3. | This is the #1 failure mode. Most AI output fails here. |
| **Composition** | Is the layout intentional? Asymmetric or deliberately composed? Grid-aligned? Or just "stuff in the middle"? | Centered-everything = max 4/10 |
| **Typography hierarchy** | Multiple sizes/weights/cases? Or one font, one size? Real type hierarchy like a magazine? | Single-weight bold text = max 4/10 |
| **Color strategy** | Is color used surgically (accent line, single element) or sprayed everywhere (gradients, glows, saturation)? | Glow effects = max 3/10 |
| **Negative space** | Is whitespace/darkspace intentional and structured? Or just "big empty background"? | Empty background ≠ good negative space |
| **Distinctiveness** | Could you tell this is for THIS brand without reading the text? Does it have character? | Generic = max 5/10 |
| **Technical quality** | Artifacts, distortion, broken text, weird elements? | |
| **Text accuracy** | Spelled correctly? Legible? Well-placed in the composition? | |

**Scoring (CALIBRATED — be honest):**
- 9-10: Portfolio-worthy. A designer would be proud. Extremely rare from AI.
- 7-8: Good design with minor issues. Passes the "would I post this?" test.
- 5-6: Mediocre. Has some design thinking but also has AI slop patterns.
- 3-4: Bad. Generic AI output with centered text and glow effects.
- 1-2: Embarrassing. Would damage the brand if posted.

**The old output that was scored 8.7/10 was actually a 3/10.** Recalibrate. Most AI image output is 3-5/10 on this scale. A 7+ should be genuinely impressive.

**REJECT THRESHOLD: Below 6 → regenerate with fundamentally different prompt (not just tweaks).** Below 4 → switch models.

Present the critique to the user with the images. Let them pick which variation to refine.

---

## Phase 5 — Iterative Refinement

Take the user's chosen variation and refine it. Maximum 3 refinement cycles.

### Refinement Strategy by Model

- **Gemini**: Use `gemini_edit_image` with natural language instructions. Reference "last" for the previous output. Multi-turn chat for complex edits.
- **Recraft**: Generate a new variation with adjusted prompt (no native edit). Use `image_to_image` if available via MCP.
- **GPT Image 1.5**: Use the `/v1/images/edits` endpoint with the image as input. Supports mask for targeted edits.
- **FLUX.2**: Use Kontext endpoint for instruction-based edits (if available), or regenerate with refined prompt.

### What to Refine

Based on the critique scores, focus refinement on the lowest-scoring criteria:
- Color issues → adjust palette in prompt, specify hex values
- Composition → describe spatial relationships more precisely
- Text errors → re-specify text with emphasis on exact spelling
- Technical artifacts → regenerate with higher quality setting
- Style mismatch → add/remove style modifiers

### When to Stop

Stop refining when:
- All criteria score 7+ AND at least 3 criteria score 8+
- The user says they're happy
- You've hit 3 refinement cycles (diminishing returns — offer to restart with a different approach)

---

## Phase 6 — Quality Gate + Delivery

### Final Assessment

Run the critique one last time on the final output. Present:

```
## Final Output

**File:** /tmp/creative-output/[filename]
**Model used:** [model name]
**Dimensions:** [WxH]
**Format:** [PNG/SVG/JPG]

### Design Rationale
[Brief explanation of the creative decisions — why these colors, this composition, this style]

### Quality Scores
| Criterion | Score |
|-----------|-------|
| Color harmony | X/10 |
| Visual hierarchy | X/10 |
| Composition | X/10 |
| Brand alignment | X/10 |
| Technical quality | X/10 |
| Text accuracy | X/10 (or N/A) |
| Professional polish | X/10 |
| **Overall** | **X/10** |

### Files Delivered
- [list all output files with paths]
```

### Output Organization

Save final outputs to a structured location:
- Working directory: `/tmp/creative-output/` (ephemeral, for iteration)
- If the user wants to keep the asset, copy to their project directory
- For SVG outputs from Recraft, also provide the raw SVG path

### Post-Delivery Options

After delivery, offer:
- "Want me to adjust anything?" → back to Phase 5
- "Want variations in a different style?" → back to Phase 2 with new concept
- "Want this in different sizes?" → regenerate with adjusted dimensions
- "Want to save the brand kit?" → offer to create/update brand-kit.json

---

## Appendix A — Recraft MCP Installation

If Recraft MCP is not installed and user needs vector/logo/icon generation:

```bash
# Install via claude mcp add
claude mcp add recraft -- npx @recraft-ai/mcp-recraft-server@latest

# Requires RECRAFT_API_KEY in environment
# Get API key at: https://www.recraft.ai/docs/api-reference
```

Alternatively, set in `~/.claude/settings.json` under `mcpServers`:
```json
{
  "recraft": {
    "command": "npx",
    "args": ["@recraft-ai/mcp-recraft-server@latest"],
    "env": {
      "RECRAFT_API_KEY": "${RECRAFT_API_KEY}"
    }
  }
}
```

## Appendix B — Quality Anti-Patterns

Things that make AI-generated design assets look bad. Avoid these in prompts:

### Visual Anti-Patterns
- **Over-saturated colors** — dial back saturation, use muted/professional palettes
- **Too many elements** — less is more. Professional design is about restraint.
- **Centered-everything syndrome** — asymmetric layouts feel more designed
- **Generic stock photo look** — specify concrete details (real locations, specific objects)
- **Gradient overload** — one subtle gradient max, not rainbow gradients
- **Floating elements with no ground** — give elements context and spatial relationships
- **AI hands/fingers** — avoid compositions where hands are prominent
- **Tiny illegible text** — if text must appear, make it large and central

### Prompt Anti-Patterns
- **"Beautiful, stunning, amazing"** — empty adjectives don't improve output
- **"HD, 4K, 8K, ultra-realistic"** — quality tags are mostly noise for modern models
- **Conflicting styles** — don't ask for "minimalist AND detailed AND busy AND clean"
- **Overly long prompts** — for most models, 50-150 words is the sweet spot
- **Negative prompts as primary direction** — describe what you WANT, not just what to avoid

## Appendix C — Text Rendering Tips

Text in AI images is the hardest thing to get right. Follow these rules:

1. **Keep text short** — 1-5 words renders best. Longer text = more errors.
2. **Put text in quotes** in the prompt — `with the text "SALE"` not `with the text SALE`
3. **Specify placement** — "centered headline text" or "text in the upper third"
4. **Use GPT Image 1.5 or Gemini Pro for text-heavy assets** — they understand text semantically
5. **Avoid Flux/Midjourney for text** — they treat text as visual texture, not characters
6. **Check every letter** — text errors are the most common AI image failure mode
7. **For logos with text, use Recraft** — vector output means text can be edited after generation
8. **Regenerate rather than edit** for text errors — editing rarely fixes misspelled text
