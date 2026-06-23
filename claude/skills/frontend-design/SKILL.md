---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt
---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

---

## 0. CRITICAL META-RULE — Working References First

**Working references first.** When implementing a landing / marketing / design-heavy page, check if there's an existing WORKING landing in the user's repo family FIRST. If yes, read it end-to-end, diff its approach vs the new target, and port the proven pattern. Do not reinvent scroll-reveal / motion / hydration strategy from scratch when a proven one exists adjacent. The canonical working reference for the Aenoxa/Pulse codebase family is `~/claude/Git/repositories/orca-design-landing/`.

---

## 0.5 CRITICAL META-RULE — i18n + Multi-Theme Mandatory Baseline

**Every website / web app / landing page / marketing site for the Aenoxa ecosystem MUST ship with i18n + multi-theme support out of the box. Non-negotiable from commit 0. No "MVP first, add later." No exceptions for customer-facing sites.**

### i18n requirements

- **next-intl** for Next.js projects. `[locale]` route segment + middleware. (Other frameworks: equivalent locale-aware routing.)
- **Minimum locales**: `id` (Indonesian, DEFAULT — Aenoxa target market is Indonesia) + `en` (English, secondary).
- **No hardcoded strings** in components. Every user-facing string in `messages/<locale>.json`, accessed via `useTranslations()` (or `getTranslations()` in server components).
- **Auth flows + form errors + toast messages + 404/error pages** all translated. NO English-only error strings.
- **hreflang metadata** on every page for SEO.
- Brief MUST include locales list + default locale upfront.

### Multi-theme requirements

- **next-themes** for Next.js projects.
- **Minimum themes**: `light` + `dark` + `system` (follow OS preference).
- **Both themes designed polished** — not "light is main, dark is afterthought".
- **CSS variables for tokens** in `globals.css` (`--bg`, `--fg`, `--accent`, `--surface`, `--border`, etc) — NOT hardcoded color values in components.
- **Theme switcher visible** in nav or settings. Not buried.
- **Theme persists** via cookie. Matches SSR (no FOUC on load).
- Brief MUST include theme list + default theme upfront.

### Exception

Internal-only admin tools (not customer-facing, used only by dev team) MAY ship English-only single-theme. Still preferred to include if scope permits.

### Verification gate (mandatory before declaring done)

- [ ] `messages/id.json` + `messages/en.json` populated for every section + form/error string
- [ ] `[locale]` routing works (`/id/...` + `/en/...`)
- [ ] `useTranslations` used everywhere — NO hardcoded user-facing English strings
- [ ] Light + dark themes both render polished
- [ ] Theme switcher accessible from nav
- [ ] Theme persists across page refresh
- [ ] No FOUC on theme load

If any gate fails → build NOT done. Fix before reporting complete.

### Why this rule exists (verified failure)

2026-05-24: Pulse landing v2 redesign was built English-only + single-light-theme. Toper rejected the entire output ("just kill the worker, we will not continue it"). Lost ID locale + lost dark mode compounded the rejection beyond just aesthetic — even with iteration, missing these baselines made the work unsalvageable. Indonesian market + premium product = bilingual + dark mode out of the box. Always.

---

## 0.7 CRITICAL META-RULE — Component Libraries (Library-First Default)

**OVERRIDE: By default, build UI from a curated component library, NOT from scratch.** After locking the archetype (§2), use that archetype's **primary** library; pull standard app-UI primitives (forms, inputs, tables, nav) the primary lacks from the **base** library (Origin UI); use **Tremor** for any data-viz/dashboard surface. **Only build a component from scratch when no suitable component exists in the chosen libraries.** This keeps every project's components stylish AND consistent.

### Rules
1. **One PRIMARY library per project.** Pick it from the archetype map below; use it across the whole project for consistency. Never mix two themed/effects libraries in one project.
2. **Base + layers are expected, not a violation:** primary themed library + **Origin UI** (neutral app-UI base) + **Tremor** (data-viz, only if data-heavy) + **Motion Primitives** (optional animation layer). These are functional layers, not competing themes.
3. **Scratch-build is the exception.** Reach for it only after confirming no library covers the component; then follow §3–§13 for the scratch component.
4. **Override slop defaults.** Several libraries default to patterns §8 BANS (purple/blue AI gradients, glow, fonts like Inter). Restyle to comply with §8 — colors are props, swap banned fonts. EXCEPTION: archetypes that legitimately own the effect (e.g. Retro-Future/Synthwave owns neon glow) may keep it.
5. **Install model:** all are copy-paste / shadcn-registry (you own the code) — verify each component's deps before adding (§13). All are FREE for commercial use.
6. **Excluded:** **Aceternity UI** is demoted — its defaults ARE the §8 anti-slop (purple gradients/aurora/glow + ships Inter + no RSC); use Magic UI or React Bits for the same dark archetypes. **Lightswind UI** is excluded as a project standard (solo-maintainer, ~700 stars, ~zero production adoption) — selective single-component use only.

### Archetype → library map

| Archetype | Primary | Base / Layers |
|---|---|---|
| Editorial Luxury | Bespoke | Origin UI (base) · Motion Primitives |
| Soft Structuralism | **Cult UI** | Origin UI |
| Neo-Brutalist | Bespoke (hard-restyled) | Origin UI |
| Japanese Minimal | **Origin UI** (sparse) | — |
| Magazine Editorial | Bespoke | Origin UI · Motion Primitives |
| Warm Craft | Bespoke (warm-restyled) | Origin UI |
| Dark Cinematic | **React Bits** (Magic UI alt) | Motion Primitives · Origin UI |
| Corporate Confident | **Origin UI** + **Tremor** (data) | — |
| Playful Pop | **Kokonut UI** | Origin UI |
| Gen Z Expressive | **Kokonut UI** + **React Bits** (chaos FX) | Origin UI |
| Anti-Design / Experimental | **React Bits** | Motion Primitives · Origin UI |
| Swiss / International Typographic | **Origin UI** (Swiss-restyled) | — |
| Terminal / Monospace | **Origin UI** (mono) | Cult UI / Magic UI terminal+code comps |
| Retro-Future / Synthwave | **Magic UI + React Bits** (co) | Origin UI |
| Opulent Noir | Bespoke | Origin UI · Cult UI (texture) · Motion Primitives |
| Y2K / Frutiger Aero | Bespoke | Origin UI · Cult UI (glass effects) |
| Memphis / Postmodern Maximalist | Bespoke | Origin UI · Kokonut / Magic motion |
| Claymorphism / Soft 3D | **Cult UI** | Origin UI |
| Risograph / Zine Print | Bespoke | Origin UI |

### The libraries (quick reference)
- **Origin UI** — 574 neutral, accessible (Radix + React Aria) base app-UI components (forms/inputs/tables/nav). MIT. The universal BASE for ~every archetype. (Rebranding under coss.com; legacy collection stable — reference `coss.com/origin`.)
- **Cult UI** — ~78 tactile/neumorphic/textured, motion-rich shadcn components. MIT. → Soft Structuralism, Claymorphism, Y2K glass, Dark Cinematic.
- **React Bits** — 130+ effects-first (text animations, cursors, WebGL/physics backgrounds); CSS-only RSC-safe variants; no forced font. MIT (Commons-Clause: free to build, can't resell). → Dark Cinematic, Anti-Design, Synthwave, Gen Z chaos. ⚠ slop-risk only via the Aurora+SpotlightCard+BlurText "greatest-hits" combo.
- **Magic UI** — ~70 animated marketing effects (beams, bento, marquee, text). MIT. → Retro-Future/Synthwave, Dark Cinematic (alt). ⚠ purple/blue defaults — override.
- **Kokonut UI** — 46 free motion-flair marketing components (bento, glitch/matrix text, AI UI). MIT free tier. → Playful Pop, Gen Z. ⚠ gradient/glow defaults — override.
- **Tremor** — data-viz (charts/KPIs/tables), Radix-accessible, clean/neutral. Apache/MIT. The DATA layer for any dashboard-heavy project (Corporate Confident).
- **Motion Primitives** — ~33 animation primitives (text/scroll/cursor). MIT. Animation LAYER only — never a sole library. → high-motion archetypes.

### Note
~7 archetypes (Editorial Luxury, Magazine Editorial, Warm Craft, Opulent Noir, Memphis, Neo-Brutalist, Risograph) have **no good themed library** — build bespoke on the Origin UI base (+ the noted accent layers). This is expected, not a gap to paper over.

---

## 0.8 CRITICAL META-RULE - The Quality Bar (how to think, before how to build)

The rest of this skill is mechanics. This section is the operating mindset that decides whether those mechanics produce a 3/10 or a 9/10. In the age of AI, passable output is free and worthless; the only thing that stands out is work that makes someone ask "how did they do that?" Apply these as decisions, not decoration.

### Default, then innovate (the industry bar is the FLOOR, not the goal)
The apps users touch daily (Linear, iOS, Notion, Stripe, Figma) set an invisible bar for "good." Miss it and people silently discount the work as cheap and move on, they will not tell you why. So START from the proven default (the §2 archetype, the §0.7 library, "what would iOS / a clean shadcn+tailwind app do here"), then push PAST it on every surface. Never start from a blank page (harder, lands below the bar). Never stop AT the default (that IS the generic-AI tell). The bar is where you begin, not where you ship.

### Range before depth
Before refining one idea, consider structurally DIFFERENT ones, not variations of the same skeleton. Three hero layouts that are all "centered headline + subhead + CTA" is depth on one concept; a split-editorial vs a full-bleed type-poster vs an interactive-object hero is RANGE. Force range by: removing a constraint ("what if this needed no hero section?"), blending a domain ("what would this look like if Muji built it?"), inverting the problem, or forcing N options. Breadth is the hedge against your own taste, you can only pick from what you have seen.

### Then push it to 10 (depth is where great is won)
Picture a 1 to 10 scale: 1 is the first thing that technically works, 10 is "everything has been considered, tried, edited and improved until it could not be better." Most work ships at 1 to 3, not because that was the ceiling but because stopping is easy. The gap between fine and great is almost never the initial idea, it is how far one idea got pushed. Pick the highest-leverage element on the page (usually the hero, the primary CTA, or the one signature interaction) and push THAT to 10 even if everything else sits at 6. When you do not know what "better" means: zoom in and give one element total attention, remove something, reference a world-class example to reveal the gap, or generate more options to choose from.

### Uncommon care, in the overlooked places
What people remember and tell others about are the moments someone went further than they had to. Care shows up where most builds stop caring: empty states, error states, the loading moment, the 404, the hover that did not have to feel that good, the number that animates instead of snapping. These are breadcrumbs that a human cared. Spend disproportionate attention there, it is exactly where generic AI output gives up and where this skill's §4 interactive-states + §5 motion rules earn their keep.

### Less, but better
Fight the urge to add (more sections, more flourish, more color). It is far easier to design LESS and execute it to a high bar than to redeem a cluttered layout. "Daily decrease, hack away the unessential." Before adding an element, try removing one. The §10 Strategic Omissions list is this rule in checklist form, treat it as first-class, not cleanup.

### Notice WHY, not just that
When something looks off, do not stop at "it feels cheap", name the specific cause: the corner radii disagree, the shadow is one muddy blur instead of two layers, two type sizes are one ratio-step apart so the hierarchy reads flat, the neutral is cool but the accent is warm. Every reaction is data. This naming discipline is what turns the §10 audit and §11 pre-flight from box-ticking into real refinement, and it is the skill the §3 to §6 mechanics exist to serve.

### Facets of quality (define the bar before you grade against it)
For a given brief, name 3 to 5 SITUATIONAL attributes you want a user to perceive (e.g. "trustworthy / calm / precise" for a fintech, "crafted / fidgetable / inventive" for a playful tool). These are not universals like "usable", they are the specific feeling this thing should give. Rate the build against each on a 1 to 5 scale, stack-rank them, and use them as critique language ("this is not inventive enough, it feels like a 2 where we want a 4") instead of vague "needs work." Carry the chosen facets into the §11 pre-flight as the final subjective gate.

---

## 1. INTERACTIVE SETUP

Before writing any code, run this setup sequence with the user. Present it conversationally — don't dump the whole menu.

### Step 1: Mode Selection

Ask the user which mode they want:

| Mode | When to use |
|---|---|
| **New Build** | Starting from scratch — full creative latitude |
| **Redesign** | Existing page/component needs a visual overhaul (run the Redesign Audit in §10) |
| **Quick Polish** | Existing code, just needs refinement — spacing, type, color, motion tweaks |
| **Surprise Me** | User trusts you completely — pick everything yourself and go bold |

### Step 2: Vibe Selection

Present the archetypes from §2 or let the user describe a custom vibe in their own words. If the user says "Surprise me," pick the archetype that best fits their content/domain and lean into it hard.

### Step 3: Intensity Dials

Present three dials. Let the user pick values 1–10, or offer sensible defaults based on the vibe.

| Dial | 1–3 | 4–7 | 8–10 |
|---|---|---|---|
| **DESIGN_VARIANCE** | Symmetric grids, centered heroes, safe layouts | Offset sections, overlapping elements, broken grids | Masonry, asymmetric bento, Z-axis layering, diagonal flow |
| **MOTION_INTENSITY** | Hover states only, no page-load animation | CSS transitions, staggered fade-ins, scroll-triggered reveals | Scroll parallax, spring physics, magnetic hover, morphing shapes |
| **VISUAL_DENSITY** | Art-gallery sparse, maximal whitespace, breathing room | Normal app density, balanced content-to-space ratio | Cockpit-packed, data-dense dashboards, information-rich layouts |

Default values by vibe:
- Editorial Luxury → VARIANCE 7, MOTION 4, DENSITY 4
- Technical Editorial → VARIANCE 5, MOTION 4, DENSITY 4
- Soft Structuralism → VARIANCE 5, MOTION 5, DENSITY 5
- Neo-Brutalist → VARIANCE 9, MOTION 3, DENSITY 6
- Japanese Minimal → VARIANCE 5, MOTION 2, DENSITY 1
- Magazine Editorial → VARIANCE 8, MOTION 5, DENSITY 5
- Warm Craft → VARIANCE 5, MOTION 4, DENSITY 4
- Dark Cinematic → VARIANCE 7, MOTION 6, DENSITY 2
- Corporate Confident → VARIANCE 4, MOTION 3, DENSITY 6
- Playful Pop → VARIANCE 6, MOTION 8, DENSITY 5
- Gen Z Expressive → VARIANCE 10, MOTION 9, DENSITY 8
- Anti-Design / Experimental → VARIANCE 10, MOTION 8, DENSITY 4
- Swiss / International Typographic → VARIANCE 5, MOTION 3, DENSITY 5
- Terminal / Monospace → VARIANCE 6, MOTION 3, DENSITY 7
- Retro-Future / Synthwave → VARIANCE 8, MOTION 8, DENSITY 4
- Opulent Noir → VARIANCE 7, MOTION 5, DENSITY 3
- Y2K / Frutiger Aero → VARIANCE 7, MOTION 7, DENSITY 5
- Memphis / Postmodern Maximalist → VARIANCE 9, MOTION 6, DENSITY 6
- Claymorphism / Soft 3D → VARIANCE 6, MOTION 6, DENSITY 4
- Risograph / Zine Print → VARIANCE 8, MOTION 4, DENSITY 5
- Custom → ask the user or pick based on context

---

## 2. VIBE ARCHETYPES

Each archetype is a starting point, not a cage. Remix, combine, or diverge — but always have a clear aesthetic direction.

### Editorial Luxury
**Best for**: Lifestyle brands, agencies, portfolios, editorial sites
- **Background**: Warm cream (#FAF7F2), parchment, or muted stone; CSS noise overlay (SVG filter) at 2–4% opacity
- **Surfaces**: Minimal borders, generous padding, content-as-decoration philosophy
- **Typography**: Serif display headers (Playfair Display, EB Garamond, Cormorant); clean sans body (DM Sans, General Sans)
- **Color**: Muted earth palette — ochre, burgundy, forest — never neon; max 1 accent
- **Signature**: Magazine-style layouts, oversized type, dramatic whitespace, image-driven storytelling
- **Recommended library:** `Bespoke (Origin UI base + Motion Primitives) — no themed library fits editorial; see §0.7`

### Technical Editorial
**Best for**: Dev tools, crypto/web3, infra/API products, technical SaaS that wants editorial-grade credibility. Premium, restrained, "the page is lit"
- **Background**: Warm cream #f9f8f6 (light) / warm near-black #0e0d0a (dark, NEVER pure black). Signature texture is an oklab ambient gradient field, NOT an SVG noise overlay: four large fixed radial glows in the corners, blended in oklab so there are no muddy sRGB midpoints. A faint paper-grain on top is optional, not the texture. Recipe:
  ```css
  body {
    background:
      radial-gradient(62rem 62rem at 2% -14%, color-mix(in oklab, #7d9fe6 30%, transparent), transparent 60%),
      radial-gradient(54rem 54rem at 110% 16%, color-mix(in oklab, #e89a6b 28%, transparent), transparent 60%),
      radial-gradient(50rem 50rem at 16% 116%, color-mix(in oklab, #5fc294 24%, transparent), transparent 58%),
      radial-gradient(38rem 38rem at 86% 104%, color-mix(in oklab, #b58ad6 20%, transparent), transparent 62%),
      var(--page);
    background-attachment: fixed;
  }
  ```
- **Surfaces**: Restrained editorial composition, generous whitespace, container ~1140px. Rounded cards (22-24px) on warm-TINTED shadows (e.g. `0 30px 80px -40px rgba(70,50,30,0.35)`), never grey shadows. Mono-labeled section headers. Fluid `clamp()` type throughout.
- **Typography**: House defaults per §3.1 (Ethereal Glamour display/serif + Switzer body/sans), PLUS a true monospace (Geist Mono, or the house mono) as the LABELING LANGUAGE. Every eyebrow, tag, step-number, caption, and metadata field is tracked-uppercase mono: `font-mono text-[11px] uppercase tracking-[0.18em]`. The mono-as-labels layer is the defining "technical editorial" signal. **Note:** the arca reference used Playfair Display for a more classic-editorial serif, so reach for Playfair (the on-mood alternative) if Ethereal Glamour's glam character fights the technical restraint; the user picks.
- **Color**: Warm-charcoal inks (ink #0e0d0a / secondary #46443d / muted #8c887e) on the warm cream/near-black page. ONE restrained cool accent: ink-navy #2a3858 (light) / soft periwinkle #93a7d6 (dark). Light + dark + system. No second accent, no neon.
- **Signature**: A faux-OS / live-component hero is the showpiece: a JSX terminal that types in real time, a process-stepper, or a chat that demonstrates the product live (NOT screenshots). Editorial calm with technical precision. **Spec-note: the oklab ambient field deliberately replaces §8's noise-overlay default for this archetype, since the perceptual oklab blend IS the texture here, not slop.** Distinct from Editorial Luxury: this differs by the mono-technical labeling layer, the oklab-gradient ambient (vs noise overlay), a restrained cool/navy accent (vs earth tones), and a dev-tool/crypto framing with a live faux-OS hero (vs image-driven luxury). Reference: arca (`github.com/tamaa13/arca`).
- **Recommended library:** `Bespoke (Origin UI base + Motion Primitives), editorial-restrained + mono-labeled; see §0.7`

### Soft Structuralism
**Best for**: Consumer apps, health/wellness, fintech, modern SaaS
- **Background**: Silver-grey or warm white, subtle gradient washes
- **Surfaces**: Large radius cards (16–24px), diffused multi-layer shadows, no hard borders
- **Typography**: Massive grotesk display type (Instrument Sans, Plus Jakarta Sans, Switzer); body at comfortable 16–18px
- **Color**: Desaturated palette with one punchy accent; saturation < 70% on backgrounds
- **Signature**: Soft depth, rounded everything, approachable density, feels touchable
- **Recommended library:** `Cult UI (+ Origin UI base) — see §0.7`

### Neo-Brutalist
**Best for**: Indie brands, punk/raw creative studios, anti-design agencies
- **Background**: Concrete grey (#D4D0CC) or raw white, visible grid lines as design element
- **Surfaces**: Sharp borders (0px radius), exposed structure, no shadows, raw edges
- **Typography**: Space Mono or JetBrains Mono primary; Bricolage Grotesque for display
- **Color**: Strictly black + white + ONE accent (usually red #FF3333 or electric blue). No gradients.
- **Signature**: Intentionally "broken" layouts, overlapping elements, raw hover states, cursor: crosshair
- **Recommended library:** `Bespoke, hard-restyled on Origin UI base — see §0.7`

### Japanese Minimal
**Best for**: High-end retail, ceramics, tea, luxury goods, artisanal products
- **Background**: Warm off-white (#FAF8F5) or rice paper texture
- **Surfaces**: Hairline 0.5px borders, extreme padding (8rem+), negative space as primary design tool
- **Typography**: Small body text (14px), generous letter-spacing. Cormorant Garamond or Noto Serif JP for display; Inter Tight at 300 weight for body
- **Color**: Charcoal #2B2B2B + one muted accent (indigo #3D4F7C or moss #6B7B5E). Max 3 colors total.
- **Signature**: Ultra-restrained — if it feels like anything was "designed," remove more
- **Recommended library:** `Origin UI (used sparsely) — see §0.7`

### Magazine Editorial
**Best for**: Media, publishing, fashion, lifestyle magazines, content-heavy sites
- **Background**: Pure white or ivory, full-bleed images as backgrounds
- **Surfaces**: No cards — content flows edge-to-edge. Pull quotes as design elements.
- **Typography**: Bold serif display (Playfair Display, Libre Bodoni) at extreme sizes (8rem+). DM Sans body. Mixed weights in same line (thin + black).
- **Color**: Black + white + one editorial accent (burgundy #7A1B35 or gold #B8860B)
- **Signature**: Dramatic scale contrast (120px headline next to 14px body), overlapping text on image, mixed column widths
- **Recommended library:** `Bespoke (Origin UI base + Motion Primitives) — see §0.7`

### Warm Craft
**Best for**: Artisan brands, F&B, bakeries, handmade goods, wellness
- **Background**: Warm linen (#F4EDE4) or kraft paper texture
- **Surfaces**: Rounded cards (20-28px radius), soft shadows (0 4px 24px rgba(0,0,0,0.06)), hand-drawn border accents
- **Typography**: Fraunces or Vollkorn for display (warm serif); Nunito Sans for body (friendly, rounded)
- **Color**: Earthy palette — terracotta #C4704D, forest #3D5A3E, cream #F4EDE4, espresso #3E2723. Warm, never cool.
- **Signature**: Hand-illustrated flourishes, organic blob shapes (SVG, not CSS), visible texture/grain at 5-8% opacity
- **Recommended library:** `Bespoke, warm-restyled on Origin UI base — see §0.7`

### Dark Cinematic
**Best for**: Entertainment, film, music, gaming, nightlife, premium experiences
- **Background**: OLED black #000000 or near-black #0A0A0A, film grain overlay (SVG noise 4-6%)
- **Surfaces**: No visible borders, content emerges from darkness via lighting/gradient reveals
- **Typography**: Instrument Serif or Bodoni Moda for display (high contrast serif); Geist for UI text
- **Color**: Black + cool white #E8E8E8 + one accent (amber #D4A84B or crimson #8B0000). Extremely limited.
- **Signature**: Cinematic letterboxing (horizontal bars), slow reveals (2-3s transitions), dramatic scroll parallax, sparse text with long pauses
- **Recommended library:** `React Bits (Magic UI alt) + Motion Primitives + Origin UI base — see §0.7`

### Corporate Confident
**Best for**: Enterprise, B2B, consulting, fintech, legal, institutional
- **Background**: White #FFFFFF or light grey #F5F5F5, clean and unadorned
- **Surfaces**: Subtle borders (1px #E5E5E5), structured cards (8px radius), consistent 24px gap grid
- **Typography**: Inter Tight or Geist for both display and body. No serif. Clean, professional, invisible.
- **Color**: Navy #1B2A4A + charcoal #374151 + white + one muted accent (teal #0D9488 or blue #2563EB). NO warm colors.
- **Signature**: Data-driven — stat counters, metric grids, progress bars, trust badges. Professional, not creative.
- **Recommended library:** `Origin UI + Tremor (data-viz layer) — see §0.7`

### Playful Pop
**Best for**: Kids/education, consumer social, gaming, creative tools, startup MVPs
- **Background**: Saturated pastel (#FFF0F5 rose, #F0F9FF sky, #ECFDF5 mint) or bright solid blocks
- **Surfaces**: Chunky cards (16-24px radius), thick 3px borders, playful shadows (offset 4px 4px, hard edge)
- **Typography**: Sora or Plus Jakarta Sans at heavy weights for display; Karla for body. Oversized (5rem+).
- **Color**: Maximum saturation — coral #FF6B6B, electric purple #7C3AED, sunny #FBBF24, mint #34D399. 3-4 colors freely mixed.
- **Signature**: Bouncy spring physics (stiffness 200, damping 15), emoji as design elements (sparingly), illustrated characters, confetti on success states
- **Recommended library:** `Kokonut UI (+ Origin UI base) — see §0.7`

### Gen Z Expressive
**Best for**: Gen Z brands, TikTok-adjacent, youth culture, meme brands, social-first companies
- **Background**: Clashing neon blocks — sections alternate bold solids (hot pink #FF1493, electric lime #BFFF00, acid yellow #DFFF11). No single bg color.
- **Surfaces**: Zigzag section breaks (clip-path, not horizontal lines), thick borders everywhere (3-4px, black), sticker/badge UI elements, collage-style overlapping layers, scrapbook textures
- **Typography**: Clash fonts intentionally — mix chunky sans (Clash Display, Space Grotesk 700, Plus Jakarta Sans 800) with pixel fonts (VT323) or monospace. Sizes at 200%. All-caps headers. Type collage with multiple fonts and weights on one layout.
- **Color**: MAXIMUM expression — 5+ colors freely mixed. Hot pink #FF1493, electric lime #BFFF00, acid yellow #DFFF11, electric blue #00BFFF, neon purple #B026FF, black #000000. No restraint. Dopamine palette.
- **Signature**: "TikTok generation energy" — if it feels calm, it's wrong. Micro-interactions on every hover. Cursor trails. Kinetic type animations on scroll. Video loops autoplay. Sticker graphics as UI elements. If grandpa would find it overwhelming, it's right.
- **Recommended library:** `Kokonut UI + React Bits (chaos FX) + Origin UI base — see §0.7`

### Anti-Design / Experimental
**Best for**: Avant-garde creative studios, experimental portfolios, art galleries, design agencies that want to break rules
- **Background**: Anything unconventional — cursor-driven unwind reveals, generative patterns, blank space that only fills as user interacts. Raw HTML aesthetics used ironically.
- **Surfaces**: No traditional cards, no traditional sections. Content appears through interaction only. Maybe one long strip. Maybe a 3D room. Maybe text you have to "dig for." Elements overlap with no clear z-index hierarchy.
- **Typography**: Deliberately uncomfortable — oversized text bleeding off screen edges, rotated baselines, stacked single characters, text that moves away from cursor, mixed typefaces (serif + grotesque + monospace) in same heading. Broken tracking.
- **Color**: Either extreme monochrome (all black or all white) or deliberately clashing neon-on-black. Grain/noise overlays, scan-line effects, deliberate JPEG artifacting as texture. No "safe" palettes.
- **Signature**: Throw away the rule book. Hidden/camouflaged navigation. Full-screen takeover menus with collision-style text. Custom cursor SVGs that lag or distort. Elements that react to mouse proximity (repel/attract). Permanent "loading" states as design elements. If a traditional web designer would say "you can't do that," do exactly that. But it must still be INTENTIONAL, not broken. Reference: Cargo Collective, Hoverstates, Lusion.
- **Recommended library:** `React Bits + Motion Primitives + Origin UI base — see §0.7`

### Swiss / International Typographic
**Best for**: Design studios, type foundries, premium editorial, agencies, architecture firms
- **Background**: Near-white #FCFCFA with faint visible grid columns left as guides (1px rules at 4–6% opacity)
- **Surfaces**: No cards — content sits directly on the grid. Hairline 1px rules (#1A1A1A) as the only dividers.
- **Typography**: Monumental grotesk — Söhne, Suisse Int'l, Archivo, or Space Grotesk (NEVER Helvetica/Inter). Flush-left ragged-right, tight leading (1.05–1.15), oversized folio numbers.
- **Color**: Black #111111 + white + ONE bold accent (International Klein Blue #002FA7 or signal red #E2231A). Nothing else.
- **Signature**: Rigorous visible modular grid, asymmetric balance, type-as-image, baseline-grid alignment, big numerals as compositional anchors
- **Recommended library:** `Origin UI (Swiss-restyled) — see §0.7`

### Terminal / Monospace
**Best for**: Dev tools, crypto/web3, infra/CLI products, technical docs, hacker-brands
- **Background**: Near-black #0B0E0C OR paper #F4F4EC (two modes), optional faint scanlines (repeating-linear-gradient at 2–3% opacity)
- **Surfaces**: ASCII / box-drawing borders, 1px solid, 0–2px radius. No shadows, no blur.
- **Typography**: Monospace everything — JetBrains Mono, IBM Plex Mono, Space Mono, or Geist Mono; optional Space Grotesk for large display headers
- **Color**: Terminal palette — near-black + phosphor green #4AF626 OR amber #FFB000 + muted greys (or light paper + ink + one accent for the paper mode)
- **Signature**: Blinking cursor, typewriter reveals, `>`/`$` prompt motifs, ASCII dividers, tabular mono data, "system status" UI, zero decorative imagery
- **Recommended library:** `Origin UI (mono-restyled) + Cult UI/Magic UI terminal & code-block components — see §0.7`

### Retro-Future / Synthwave
**Best for**: Gaming, music, NFT/crypto launches, nightlife, bold tech launches
- **Background**: Deep indigo→magenta night-sky gradient, neon perspective grid at the horizon, optional starfield
- **Surfaces**: Glowing-edge panels (glow is intentional here), chrome/metallic bevels, semi-transparent dark fills
- **Typography**: Outrun display — Monument Extended, Clash Display, or Orbitron (sparingly); body in Space Grotesk
- **Color**: Deep purple/navy base + magenta #FF2E97 + cyan #2DE2E6 + sunset orange #FF6C11 — a multi-neon system, not a single accent
- **Signature**: Neon glow, perspective grid, sunset gradients, chrome text, CRT/VHS artifacts. **Spec-note: this vibe deliberately overrides §8's no-glow + no-blue/purple-gradient bans — neon glow and the purple→magenta gradient ARE the aesthetic here, not slop.**
- **Recommended library:** `Magic UI + React Bits (co-primary) + Origin UI base — see §0.7`

### Opulent Noir (Couture Dark)
**Best for**: Jewelry, watches, haute fashion, premium spirits, luxury hospitality, high-end product positioning
- **Background**: Obsidian #0A0908 with a subtle vignette darkening the edges
- **Surfaces**: Minimal — 0.5px gold hairline borders, generous negative space, content emerges from the black via light alone
- **Typography**: High-contrast serif display — Cormorant Garamond, Bodoni Moda, or Playfair Display; body in a refined sans (General Sans, Outfit)
- **Color**: Black + matte champagne-gold #C8A86B + ivory #F3EDE3. Restraint is the point — three colors, no more.
- **Signature**: Gold-leaf accents, letterspaced caps, slow elegant reveals, jewelry-box spacing. Distinct from Dark Cinematic — this is couture, not cinema.
- **Recommended library:** `Bespoke (Origin UI base + Cult UI texture + Motion Primitives) — see §0.7`

### Y2K / Frutiger Aero
**Best for**: Consumer apps, nostalgia brands, youth products, glossy playful SaaS
- **Background**: Sky-blue→aqua gradients, glossy bubbles, water/bokeh textures, lush-nature motifs
- **Surfaces**: Glossy aqua-glass buttons with skeuomorphic shine highlights, pill shapes, soft reflections
- **Typography**: Rounded humanist/techno — Hubot Sans, Chillax, or a rounded grotesk (never the banned ones)
- **Color**: Sky blue #4AC4F3 + aqua #7DF9C4 + lush green #5CB85C + glossy-white highlights — an optimistic multi-color system
- **Signature**: Aqua gloss, lens-flare/bokeh, bubble shapes, skeuomorphic shine, optimistic 2000s–2010 nostalgia. Distinct from flat Soft Structuralism and chaotic Gen Z.
- **Recommended library:** `Bespoke + Cult UI (glass effects) + Origin UI base — see §0.7`

### Memphis / Postmodern Maximalist
**Best for**: Creative agencies, kids/education, events, festivals, bold consumer brands
- **Background**: Off-white or pastel block with scattered Memphis confetti — SVG squiggles, dots, zigzags, triangles
- **Surfaces**: Bold 3–4px black-bordered blocks, clashing pattern fills, geometric shape collage, hard offset shadows
- **Typography**: Chunky geometric — Clash Display or Bricolage Grotesque; mixed playful weights on one layout
- **Color**: Black + hot pink #F5408B + cyan #46C9E5 + yellow #FFD23F + coral — an 80s Memphis clash, a deliberate multi-color system
- **Signature**: Memphis-Group squiggles / bean shapes / grids, terrazzo textures, geometric confetti, playful clash. A design-history movement — distinct from Gen-Z internet chaos.
- **Recommended library:** `Bespoke (Origin UI base + Kokonut/Magic motion) — see §0.7`

### Claymorphism / Soft 3D
**Best for**: Kids apps, fintech onboarding, friendly consumer, wellness, edtech
- **Background**: Soft pastel dual-tone wash (e.g. lavender→mint)
- **Surfaces**: Puffy inflated 3D clay shapes — dual soft shadows (light top-left + dark bottom-right), rounded 24–40px radius, 3D-extruded icons
- **Typography**: Rounded friendly — Quicksand, Baloo 2, or Hubot Sans
- **Color**: Soft pastels (lavender, mint, peach) with dual-tone clay shading + one slightly-saturated accent for CTAs
- **Signature**: Inflated 3D clay objects, dual soft shadows, tactile bounce on press, 3D spot illustrations. **Spec-note: keep COLOR contrast (unlike pure neumorphism, where same-color shadows kill legibility) so it stays WCAG-accessible — this is the line that separates it from the banned neumorphism.** 3D-puffy versus Soft Structuralism's flat-soft.
- **Recommended library:** `Cult UI (+ Origin UI base) — see §0.7`

### Risograph / Zine Print
**Best for**: Indie brands, music/events, artisan F&B, editorial, cultural orgs
- **Background**: Cream/newsprint #F2ECDD with heavy grain / paper texture
- **Surfaces**: Spot-color blocks with deliberate misregistration (offset layers), halftone fills, overprint-multiply blends. No smooth gradients.
- **Typography**: Bold condensed/woodtype — Bricolage Grotesque, Anton, or Syne; body in a workhorse grotesk
- **Color**: 2–3 riso spot inks — fluoro pink #FF48B0 + riso blue #0078BF + yellow #FFE800 on cream, overprinting where they overlap
- **Signature**: Visible grain, halftone dots, misregistered color layers, overprint blends, DIY zine collage, photocopy texture. Print-DIY versus Warm Craft's polished digital warmth.
- **Recommended library:** `Bespoke (Origin UI base) — see §0.7`

### Custom Vibe
When the user describes something that doesn't match an archetype, extract:
1. Color temperature (warm / cool / neutral)
2. Density feeling (airy / balanced / packed)
3. Personality (serious / playful / luxe / raw / futuristic / organic)
4. Reference points (any sites, brands, or aesthetics they mention)

Then build a coherent system from those constraints.
- **Recommended library:** `Pick the closest archetype's library from §0.7, or Origin UI base + bespoke`

---

## HYBRID VIBES

Mix two archetypes for nuanced aesthetics. One PRIMARY (70% influence) + one SECONDARY (30% influence).

### How It Works

- **Primary archetype** controls: background, surfaces, overall mood, typography system
- **Secondary archetype** influences: accent patterns, motion style, one signature element borrowed
- Display font comes from primary. Body font stays from primary. Never mix font systems across archetypes.
- Background treatment from primary. Accent color from secondary.
- Motion: blend intensity — primary timing + secondary easing.

### Dial Blending Rule

Hybrid dial values = `primary_default × 0.7 + secondary_default × 0.3`, rounded to nearest integer. User can still override.

Example: Editorial Luxury (V6/M4/D4) + Dark Cinematic (V6/M6/D2) = V6/M5/D3

### Token Merging Rule

| Token | Source |
|---|---|
| Background | Primary |
| Surface treatment | Primary |
| Accent color | Secondary |
| Display font | Primary |
| Body font | Primary |
| Motion intensity | Blended (70/30) |
| Motion easing | Secondary |
| Signature element | Borrow ONE from secondary |

### Compatibility Matrix

#### Compatible Pairings (YES — these enhance each other)

| Primary | Secondary | Result | Why it works |
|---|---|---|---|
| Editorial Luxury | Japanese Minimal | Elegant restraint | Shared refinement, JM adds breathing room |
| Editorial Luxury | Dark Cinematic | Dramatic editorial | Cinematic mood intensifies editorial drama |
| Neo-Brutalist | Playful Pop | Punk energy | Pop color adds vibrancy to raw structure |
| Corporate Confident | Warm Craft | Approachable enterprise | Craft warmth softens corporate rigidity |
| Soft Structuralism | Warm Craft | Friendly organic tech | Craft textures warm up structured surfaces |
| Soft Structuralism | Corporate Confident | Polished SaaS | Corporate structure + soft approachability |
| Magazine Editorial | Dark Cinematic | Cinematic storytelling | Both dramatic, film grain enhances editorial |
| Neo-Brutalist | Anti-Design | Maximum provocation | Both rule-breaking, combined = avant-garde punk |
| Warm Craft | Playful Pop | Friendly fun | Pop energy with artisanal warmth |
| Magazine Editorial | Gen Z Expressive | Loud editorial | Gen Z chaos channels through editorial structure |
| Dark Cinematic | Anti-Design | Experimental noir | Both dark, anti-design adds unpredictability |
| Japanese Minimal | Dark Cinematic | Contemplative noir | Minimal restraint + cinematic atmosphere |
| Opulent Noir | Japanese Minimal | Restrained luxury | Shared discipline — JM's negative space amplifies the couture restraint |
| Opulent Noir | Magazine Editorial | Fashion editorial | Editorial scale-contrast carries the couture-dark mood into a story |
| Terminal | Neo-Brutalist | Raw systems | Both anti-decorative — brutalist structure suits the mono/CLI austerity |
| Retro-Future / Synthwave | Dark Cinematic | Neon noir | Cinematic darkness grounds the neon so the glow reads as mood, not noise |
| Swiss / International Typographic | Corporate Confident | Rigorous enterprise | Swiss grid discipline gives corporate trust a real backbone |
| Memphis / Postmodern Maximalist | Playful Pop | Maximum fun | Pop saturation supercharges the Memphis clash without losing legibility |
| Risograph / Zine Print | Warm Craft | Analog craft | Both tactile and handmade — riso ink texture meets artisanal warmth |
| Claymorphism / Soft 3D | Playful Pop | Friendly 3D | Pop bounce + puffy clay = approachable, tactile consumer energy |
| Y2K / Frutiger Aero | Playful Pop | Glossy fun | Aqua gloss + pop saturation = peak optimistic-consumer shine |

#### Incompatible Pairings (NO — these contradict each other)

| Primary | Secondary | Why it fails |
|---|---|---|
| Playful Pop | Corporate Confident | Bouncy energy vs professional restraint — neither wins |
| Japanese Minimal | Gen Z Expressive | Extreme silence vs extreme noise — irreconcilable |
| Anti-Design | Corporate Confident | Rule-breaking vs rule-following — pure contradiction |
| Warm Craft | Neo-Brutalist | Soft organic vs raw industrial — opposite textures |
| Japanese Minimal | Playful Pop | Restraint vs maximalism — mutual destruction |
| Gen Z Expressive | Editorial Luxury | Chaotic youth vs refined authority — tone mismatch |
| Opulent Noir | Memphis / Postmodern Maximalist | Refined hush vs playful chaos — the gold restraint dies in the clash |
| Terminal | Y2K / Frutiger Aero | Austere CLI vs glossy aqua — opposite surface philosophies |
| Swiss / International Typographic | Memphis / Postmodern Maximalist | Strict order vs anti-order — the grid and the confetti cancel out |
| Claymorphism / Soft 3D | Neo-Brutalist | Soft inflated comfort vs raw hard edges — opposite tactility |

---

## 3. DESIGN ENGINEERING — Typography

Typography is the single highest-leverage design decision. Get this right and the rest follows.

### Font Selection Rules
- Display fonts: `letter-spacing: -0.02em` to `-0.04em` (tracking-tighter or tracking-tight)
- Body text: `max-width: 65ch` for readability
- Always set `-webkit-font-smoothing: antialiased` and `-moz-osx-font-smoothing: grayscale`
- Use `font-variant-numeric: tabular-nums` on any numbers in tables, stats, or counters
- Use `text-wrap: balance` on headlines, `text-wrap: pretty` on body paragraphs (where supported)
- Size scale: use a modular scale (1.2–1.333 ratio) rather than arbitrary sizes
- Line height: display text 1.0–1.15, body text 1.5–1.7

### 3.1 Default Typefaces (House Defaults)

The house default pairing is **Ethereal Glamour (display/serif) + Switzer (body/sans)**. Reach for this baseline unless a specific archetype or brief genuinely demands a different face.

**Ethereal Glamour** (display / heading / serif-accent role):
- Decorative glam display font, **single weight (Regular only)**, self-hosted (not on Google Fonts).
- TTF installed at `~/.local/share/fonts/EtherealGlamour-Regular.ttf`; generated projects self-host it in `public/fonts/`.
- Use ONLY at large display sizes. Never for body text.
- If a heavier weight is needed, faux-bold is acceptable since the face ships Regular only.
- Archetypes with a defining type identity (Terminal/Monospace, Retro-Future) may override display choice where the aesthetic truly requires it, but Ethereal Glamour is the default for all decorative heading roles.

**Switzer** (body / workhorse / sans role):
- Characterful-neutral grotesk from Fontshare (free, open license). Load via `https://api.fontshare.com/v2/css?f[]=switzer@400,500,600,700&display=swap` or self-host.
- Alternative: **General Sans** (Fontshare, similar profile, solid fallback when Switzer is unavailable).
- Never use Arial, Liberation Sans, or any metric-compatible Arial-class substitute as the body default. Liberation Sans is metric-identical to Arial, which §8 bans. Switzer is the intentional replacement.

**Mono** role: unchanged, follow the guidance below (JetBrains Mono, Space Mono, Geist Mono per archetype).

### Font Pairing Strategy
Always pair a distinctive display font with a refined body font. Never use the same font for both unless it's a deliberate monospace aesthetic. The house default pairing is Ethereal Glamour + Switzer. Other strong pairings:
- **Ethereal Glamour + Switzer** (house default: glam display + characterful grotesk body)
- Playfair Display + DM Sans (editorial)
- Instrument Serif + Instrument Sans (modern)
- Fraunces + Outfit (warm tech)
- Space Mono + General Sans (dev/code)
- Cormorant Garamond + Nunito Sans (luxury)
- Bricolage Grotesque + Inter Tight (bold modern — Inter Tight only, never plain Inter)
- Sora + Karla (geometric clean)

Load fonts from Google Fonts or Fontshare. Always specify `display=swap`. Ethereal Glamour is self-hosted (see §3.1 above).

### Serif Constraints
Serif fonts are **BANNED for Dashboard/Software UIs**. Use sans-serif pairings (`Geist` + `Geist Mono`, `Satoshi` + `JetBrains Mono`). Serif is only appropriate for creative/editorial vibes.

### Variable Font Animation Patterns

Variable fonts unlock axis-based animation — weight, width, optical size, and custom axes can be animated smoothly. These transitions are GPU-composited in modern browsers (Chrome 90+, Safari 15+, Firefox 90+).

**Performance note**: `font-variation-settings` transitions are composited similarly to `opacity` — efficient on GPU. Safe to animate. Avoid animating `font-weight` directly (triggers layout); always use `font-variation-settings: "wght"` instead.

#### 1. Hover Weight Shift
Animate the `wght` axis on hover (e.g., 300 → 600). Creates a "thickening" effect on interactive text.

**Use with**: Editorial Luxury, Japanese Minimal, Magazine Editorial, Dark Cinematic
**Anti-pattern**: Don't shift weight on body text — only on display/heading text and nav links. Weight shift on dense paragraphs causes disorienting reflow.

```css
.text-hover-weight {
  font-variation-settings: "wght" 300;
  transition: font-variation-settings 0.4s ease;
}
.text-hover-weight:hover {
  font-variation-settings: "wght" 600;
}
```

#### 2. Scroll-Linked Weight
Heading gets bolder as user scrolls past it. Maps `scrollYProgress` to `wght` axis. Subtle — 100 unit shift max.

**Use with**: Editorial Luxury, Magazine Editorial, Corporate Confident
**Anti-pattern**: Cap the shift at 100 units (e.g., 400→500). Larger shifts cause visible text reflow and CLS.

```tsx
"use client";
import { useScroll, useTransform, motion } from "framer-motion";
import { useRef } from "react";

export function ScrollWeightHeading({ children }: { children: string }) {
  const ref = useRef<HTMLHeadingElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start end", "end start"] });
  const wght = useTransform(scrollYProgress, [0, 1], [300, 500]);

  return (
    <motion.h2 ref={ref} style={{ fontVariationSettings: useTransform(wght, (v) => `"wght" ${v}`) }}>
      {children}
    </motion.h2>
  );
}
```

#### 3. Variable Optical Size
Use the `opsz` axis responsively. Small viewport = higher opsz (optimized for small rendering), large viewport = lower opsz (optimized for display).

**Use with**: All archetypes that use variable fonts with `opsz` axis (Inter Tight, Source Serif 4, Fraunces)
**Anti-pattern**: Not all variable fonts have an `opsz` axis — check before using. Using `opsz` on a font without it is silently ignored.

```css
.heading-responsive-opsz {
  font-variation-settings: "opsz" 48; /* display optimized */
}

@media (max-width: 768px) {
  .heading-responsive-opsz {
    font-variation-settings: "opsz" 14; /* text optimized */
  }
}

/* Or use clamp for fluid opsz: */
.heading-fluid-opsz {
  font-variation-settings: "opsz" clamp(14, 2vw + 10, 48);
}
```

#### 4. Character-Level Weight Stagger
During reveal animation, each character starts at weight 100 and animates to target weight (e.g., 400) with stagger. Creates a "solidifying" / "materializing" effect. Combine with opacity + y animation.

**Use with**: Neo-Brutalist, Gen Z Expressive, Dark Cinematic, Anti-Design / Experimental
**Anti-pattern**: Max 30 characters — beyond that the stagger becomes tedious. Split longer text into word-level stagger instead.

```tsx
"use client";
import { motion } from "framer-motion";

export function StaggerWeightReveal({ text, targetWeight = 400 }: { text: string; targetWeight?: number }) {
  return (
    <span aria-label={text}>
      {text.split("").map((char, i) => (
        <motion.span
          key={i}
          aria-hidden
          initial={{ opacity: 0, y: 8, fontVariationSettings: `"wght" 100` }}
          animate={{ opacity: 1, y: 0, fontVariationSettings: `"wght" ${targetWeight}` }}
          transition={{ delay: i * 0.04, duration: 0.5, ease: [0.34, 1.56, 0.64, 1] }}
          style={{ display: "inline-block" }}
        >
          {char === " " ? "\u00A0" : char}
        </motion.span>
      ))}
    </span>
  );
}
```

#### 5. Italic Axis Animation (Fraunces SOFT Axis)
Fraunces has a `SOFT` axis (0–100). Animate from SOFT 0 (sharp serifs) to SOFT 100 (rounded serifs) on scroll or hover for a "softening" effect. Other fonts with custom axes: Recursive (`CASL` casual axis), Roboto Flex (`GRAD` grade axis).

**Use with**: Editorial Luxury, Warm Craft (any archetype using Fraunces or other multi-axis variable fonts)
**Anti-pattern**: Only works with fonts that expose custom axes. Check the font's axis registry before attempting.

```css
.heading-soften-hover {
  font-family: "Fraunces", serif;
  font-variation-settings: "SOFT" 0, "wght" 400;
  transition: font-variation-settings 0.6s ease;
}
.heading-soften-hover:hover {
  font-variation-settings: "SOFT" 100, "wght" 400;
}
```

### Measure, Leading & Vertical Rhythm

The numbers above (max-width 65ch, line-height) are the floor. These are the relationships that make type feel typeset rather than typed:

- **Measure** (line length): best readability sits at **45 to 75 characters per line** (`max-width: 66ch`). Go shorter for marketing fragments, never wider for body, long lines lose the reader on the return sweep.
- **Leading grows with measure, shrinks with scale.** A wider column wants MORE line-height (1.5 to 1.6); a tight column or small text wants less. Big display type reads as a single unit, so pull it tight (1.0 to 1.1). Do not apply one global line-height to every size.
- **Type scale: cap it at ~5 sizes**, generated as base × ratio (16 × 1.5 → 24 → 36...). A bigger ratio reads editorial/dramatic, a tighter ratio reads utilitarian. Use a GENTLER ratio below the base than above it, so captions and labels do not collapse to unreadable.
- **Vertical rhythm:** pick a base spacing unit tied to the body line-height and make every margin/padding/gap a multiple of it. This is why the 8pt grid exists, staying on the grid is what makes spacing feel composed instead of arbitrary.

### Setting Type (the typeset-vs-typed details)

- **Proper punctuation** is the cheapest tell of care: curly quotes (" "), real apostrophes ('), an en-dash for ranges (8–10), a single Unicode ellipsis (…) not three periods. Especially visible in serifs. (This applies to copy the interface renders, not to this repo's own no-long-dash house rule.)
- **Hanging punctuation:** push an opening quote or bullet into the margin (`hanging-punctuation: first` where supported, or a negative text-indent) so the optical left edge of a block stays straight.
- **Tracking scales inversely with size:** open up small all-caps eyebrows and labels (`letter-spacing: 0.05em` to `0.2em`); tighten large display (the §3 negative-tracking rule). One size does not fit both.
- **Dark mode weight:** light text on a dark background optically "blooms" and reads heavier. With a variable font, drop the body weight a notch in dark mode (e.g. 400 → 360) so it matches the light-mode color.
- **Fitting type:** fluid sizing with `clamp(1.375rem, 6cqi, 2.75rem)` (`cqi` = 1% of container width) beats viewport units for component-scoped type. For overflow, `text-overflow: ellipsis` (1 line) or `-webkit-line-clamp` (n lines); **middle-truncate filenames** so the extension survives (`Final_quarterly…review.pdf`).
- **Text-box-trim:** `text-box: trim-both cap alphabetic` removes a font's built-in leading slack so a label truly optically centers in a button or pill, instead of sitting a hair high.

### OpenType Features (already in the font, easy to miss)

These ship inside good fonts and are off by default. Opting in is a one-line `font-feature-settings` / `font-variant-*` and instantly signals craft:

- **Slashed zero** (`font-feature-settings: "zero"`) for codes, IDs, API keys, anything where 0 vs O matters.
- **Tabular figures** (`font-variant-numeric: tabular-nums`) for ANY number that animates or sits in a column, so digits do not shift width (the §3 rule, restated because it is the most-skipped one). Right-align numbers in tables and pair with tabular figures.
- **Fractions** (`"frac"`), **sup/subscript** (`"sups"`/`"subs"`) for real mc² / H₂O glyphs, not shrunk digits.
- **Small caps** (`font-variant-caps: small-caps` / `"smcp"`) for acronyms set in running prose, real glyphs, not scaled-down caps.
- **Case-sensitive forms** (`"case"`) raise punctuation (parens, hyphens) to align with all-caps text.
- **Stylistic / character sets:** Inter exposes `cv01`–`cv13` and `ss02` (slashed-zero + tailed-l + unambiguous-1 bundle), `ss01` rounded quotes. Use them to make a "banned-by-default" workhorse font feel intentional, or to disambiguate UI text.

---

## 3.5 DESIGN ENGINEERING - Color

Color is where AI output most often gives itself away: mismatched temperature, muddy gradients, flat shades, everything at slightly-wrong perceived weight. The §8 bans say what NOT to do; this section is how to build a palette that reads rich and considered.

### Pick one temperature, use it everywhere
Decide warm or cool and commit, especially for neutrals. A drop of red makes a warm white; a drop of blue makes a cool one. The classic AI tell is cool-grey body copy on a warm cream palette, two temperatures fighting. Instead of declaring a brand-new color for a tint, **use your primary neutral at low opacity** (e.g. `color: hsl(var(--ink) / 0.6)`), so it inherits the underlying tone automatically. Tailwind's families are consistently tinted, pick ~3 neutrals from ONE family (`stone` for warm, `slate`/`zinc` for cool) rather than mixing `gray` with `stone`.

### Equalize PERCEIVED brightness with OKLCH
Equal HSL Lightness does NOT look equally bright, blue reads darker and yellow-green reads brighter at the same `L`. So category tokens, tag colors, or a row of accents built in HSL come out visually uneven even when "mathematically" equal. Define them in **OKLCH** instead (`oklch(0.7 0.15 250)`), where the first value is perceptual lightness, to make a set of colors feel equal-weight, then deviate ONLY where you intend emphasis. (Reference: oklch.fyi.)

### Darken by shifting hue + raising chroma, not by dropping lightness
The secret behind palettes that feel rich and saturated instead of muddy: as a color gets darker, **nudge the hue and INCREASE the chroma**, do not just lower lightness toward grey. A "shadow" swatch of a brand color should be a touch more saturated and slightly hue-rotated, not a desaturated version of the base. This is the difference between a premium ramp and a tint/shade that looks washed.

### Gradients: interpolate in OKLCH, and ease the stops
- **Interpolate in OKLCH:** default CSS gradients interpolate in sRGB, so hues that are far apart pass through a muddy grey midpoint. `linear-gradient(in oklch, var(--a), var(--b))` keeps the midtones rich and dynamic.
- **Ease the opacity stops:** a fade with equally-spaced stops (especially a dark scrim over an image) leaves a visible "horizon line" where the ramp starts. Sample ~10 to 15 stops eased with smoothstep `t*t*(3-2t)` so the transition dissolves with no seam. (Tool: easing-gradients by Andreas Larsen.)

### Blend modes for vibrant foregrounds (not just opacity)
Opacity matches the foreground to the background tone and can look flat; blend modes give richer, more saturated results. `mix-blend-mode: plus-lighter` makes a light foreground (a white title or graphic over a colored card) read bright and vivid where 50%-opacity white looks dull. Pair it with `isolation: isolate` on the component (see §4 Compositing) so the blend composites only against the card, not the whole page behind it. `plus-darker` is the inverse for dark foregrounds (currently WebKit-only, sample the implied values from your design tool for Chromium).

---

## 4. DESIGN ENGINEERING — Surfaces & Layout

### Double-Bezel Card Architecture
The signature card pattern: an outer shell wrapping an inner core, creating depth without drop shadows.

```
outer shell:  bg-zinc-900  rounded-2xl  p-[1px]  (the "bezel")
inner core:   bg-zinc-950  rounded-[15px]  p-6    (content area)
```

Concentric border radius math: inner radius = outer radius − padding. If outer is `rounded-2xl` (16px) and padding is 1px, inner is 15px. If padding is 4px, inner is 12px.

### Optical Alignment
- Icon-only buttons: add 1–2px extra horizontal padding to compensate for optical centering
- Icons next to text: the icon often needs 1px visual nudge to align with the text baseline
- Cards in a grid: when mixing content heights, align to a baseline grid or use `align-items: start`

### Alignment Methods (the "one wrong note" fix)
That nagging "something is off, like a chord with one wrong note" feeling is almost always alignment. There are five ways things align, and the goal is to use as FEW of them per screen as possible:

- **Edge:** to a shared (often invisible) edge. The most common, interfaces mimic documents.
- **Axis / spine:** centers aligned to one horizontal or vertical spine. Use for controls or icons whose shapes/bounding-boxes differ.
- **Baseline:** to the baseline of a key text element.
- **Mathematical:** consistent values/ratios (inside a single button or card).
- **Optical:** adjusted to FEEL balanced, deliberately inconsistent values for a more harmonious result.

Three governing rules: (1) **reduce the number of invisible alignment rules** (edges, axes, baselines) on any one screen, a left edge for text plus a spine for icons beats four competing edges; (2) **optimize for feeling balanced over being mathematically consistent**; (3) **reduce the number of alignment METHODS** mixed on one screen. Concrete fixes: a container title's line-height is taller than its cap-height, so **trim its top padding** so the block looks optically centered; in a content list, give icons a vertical spine and text a left edge, and align trailing accessories to a horizontal spine (not the label baseline) when rows vary in line count; an emphasized row that breaks pure edge alignment gets a background or stroke to re-anchor it.

### Image Outlines
Add a subtle outline to all images for consistent depth against any background:

```css
img { outline: 1px solid rgba(0,0,0,0.06); outline-offset: -1px; }
```

This prevents images from "floating" on similarly-colored backgrounds.

### Layered Tinted Shadows (not borders)
Replace borders with layered shadows that use the element's own color, tinted:

```css
box-shadow:
  0 1px 2px hsl(var(--brand) / 0.08),
  0 4px 12px hsl(var(--brand) / 0.06),
  0 16px 40px hsl(var(--brand) / 0.04);
```

This creates depth that feels organic rather than drawn-on. The principle behind it: a real shadow has a **tight contact edge plus a wide ambient falloff**, so a single `box-shadow` reads fake (the muddy-blur tell). Always stack at least a small/tight layer with a big/soft layer (Tailwind's `shadow-*` classes already do this, do not flatten them to one).

### Borders That Stay Crisp
A solid-color border looks muddy or blurry over a shadow or against a varying background, because it does not pick up what is behind it. Implement borders as a **transparent outline or an inset box-shadow** so they inherit the underlying contrast and stay crisp everywhere:

```css
/* instead of: border: 1px solid #e5e5e5; */
box-shadow: inset 0 0 0 1px rgb(0 0 0 / 0.08);   /* or use a transparent ring */
```

For an image sitting on a near-same-tone background, add a **subtle low-opacity inset border** (the §4 Image Outlines rule) so it does not float.

### Style Consistency (inconsistency reads as a BUG)
The single biggest tell between "considered" and "thrown together" is consistent styling. A user does not consciously notice consistency, but they DO read inconsistency as a glitch:

- **One icon style.** Never mix fill vs outline, or two corner radii, or two stroke widths across icons. Pick one and hold it.
- **Unify radii.** If buttons and cards are generously rounded, a sharp-cornered checkbox or select reads sloppy. Watch overall roundedness, not just concentric-radius math.
- **Do not mix materialities.** A glassy/blurred control next to a flat high-contrast icon in the same toolbar looks like two pasted-together aesthetics. Pick one surface language per cluster.
- **Consistent fills and strokes.** A lone outline button among filled controls jumps out, make it a filled-but-clearly-secondary style. A stray stroke on one avatar in an otherwise flat toolbar reads as a leftover, remove it.
- **Bound controls consistently.** If the `•••` menu sits in a bounded shape, the back icon should too, or neither should. As a rule, bound only primary actions, but apply that rule everywhere.

### Compositing (an interface is a stack of layers)
Painting order matters, and blends/opacity behave in non-obvious ways when layers overlap:

- **`isolation: isolate`** on a component composites its OWN internal layers first, then places the result, so a blend-mode child (a `plus-lighter` title, §3.5) blends against the card and not the page behind it. This is the realism unlock for any blended foreground.
- **Group-then-fade.** To fade several overlapping elements (an avatar stack, a card with layered art) as one, wrap them and fade the GROUP (or a pseudo-element), otherwise you see through the overlaps mid-fade.
- **One border edge in a grid.** Transparent borders that overlap ADD their opacity and look darker on shared edges. In a grid of cells, give each cell a border on only one horizontal and one vertical edge.
- **True cross-fades.** Two images cross-fading at 50% each sum to 75%, not 100%, so the background bleeds through the midpoint. Group both and use `mix-blend-mode: plus-lighter` to sum the layers for a clean 100% dissolve.
- **Richer backdrop materiality.** When using `backdrop-filter: blur()` to lift a nav or toolbar, also bump `saturate(1.4)`, the blur alone washes color out; raising saturation approximates the rich frosted look (a cheap stand-in for the heavier color math native UIs do).
- **Compose graphics in code, not as flat images** when they need to animate, recolor, or adapt, a CSS/SVG/canvas graphic stays maintainable and themeable where a baked PNG does not.

### Masks (hide without cropping)
A mask hides part of an element without destroying it. Two kinds, by edge:

- **`clip-path`** is geometry, so it gives a CRISP edge: `clip-path: circle(50% at 50% 50%)`, or `inset(0 100% 0 0)` animated to `inset(0)` for a left-to-right wipe/reveal.
- **`mask-image`** uses an alpha channel (usually a gradient), so it gives a SOFT edge: fade the edges of a scrolling row with `mask-image: linear-gradient(to right, transparent, #000 12%, #000 88%, transparent)`.
- **Text masks:** `background-clip: text` + `color: transparent` paints a gradient, image, or video through the letterforms (use sparingly, the §8 ban on gradient-filled large display headers still holds).
- **Prefer a mask over a gradient OVERLAY.** An overlay element that someone forgets to invert in dark mode becomes a bug; a mask travels with the element and does not.

### Button-in-Button Trailing Icon
For primary CTAs, embed a visual "inner button" for the trailing arrow/icon:

```jsx
<button className="group inline-flex items-center gap-3 rounded-full bg-white px-6 py-3 text-black">
  <span>Get Started</span>
  <span className="flex h-8 w-8 items-center justify-center rounded-full bg-black text-white transition-transform group-hover:translate-x-0.5">
    →
  </span>
</button>
```

### Scale on Press
Apply `scale(0.96)` on `:active` for tactile button feedback. Use exactly `0.96` — never below `0.95` (feels exaggerated). Pair with `transition-transform duration-150` for snappy response.

### Eyebrow Tags
Precede major headings with microscopic pill badges: `rounded-full px-3 py-1 text-[10px] uppercase tracking-[0.2em] font-medium`. These micro-labels create hierarchy and visual anchoring above display type.

### Layout Archetypes

Choose based on DESIGN_VARIANCE level:

**Variance 1–3: Structured**
- Centered hero with subtext and CTA
- Even-column grids (2-col, 4-col)
- Predictable vertical rhythm

**Variance 4–7: Offset**
- **Asymmetrical Bento**: mixed-size grid cells, 2:1 and 1:1 ratios, intentional gaps
- **Editorial Split**: 60/40 or 70/30 content splits, alternating sides
- Overlapping elements with negative margins or absolute positioning

**Variance 8–10: Expressive**
- **Z-Axis Cascade**: stacked layers at different depths, parallax-separated
- Masonry / Pinterest-style with varied heights
- Diagonal section breaks (clip-path or skew transforms)
- Elements breaking out of their containers

### Grid Rules
- Use CSS Grid over flexbox math for page layout
- `min-h-[100dvh]` not `h-screen` (respects mobile browser chrome)
- Named grid areas for complex layouts improve readability
- `gap` over margin for grid children — always

### Macro-Whitespace
Use `py-24` to `py-40` for section spacing. Follow the spacing scale: `4–8–12–16–24–32–48–64` (Tailwind units). Break the scale intentionally only for deliberate visual tension.

### Mobile Override Rule
For DESIGN_VARIANCE 4–10, any asymmetric layout above `md:` **must** fall back to `w-full`, `px-4`, `py-8` on viewports below `768px`. No exceptions — asymmetry is a desktop luxury.

### Mandatory Interactive UI States
Every component must account for all states — not just the happy path:
- **Loading**: Skeletal loaders matching the layout's exact dimensions and shape (no generic circular spinners). Use shimmer with shifting light reflections.
- **Empty**: Beautifully composed empty states indicating how to populate data.
- **Error**: Clear, inline error reporting. No `window.alert()`.
- **Tactile Feedback**: On `:active`, use `scale-[0.96]` to simulate physical push.

**Map every state before you build, not just the happy path.** For anything with more than two states (an async button: idle → submitting → success → error; a payment row: current / due / overdue / paid / failed, crossed with autopay-on and locked toggles), name ALL of them plus the cross-cutting toggles, and build a throwaway playground that renders them ALL at once behind switches. Designing each state in isolation in your head misses the combinations (locked + overdue, empty + error), which is exactly where the breadcrumbs of uncommon care (§0.8) live. This is also closer to shippable than a dozen static mockups.

---

## 5. MOTION

Motion creates personality. Calibrate to MOTION_INTENSITY.

### Core Principles
- **Only animate `transform` and `opacity`** — never `top`, `left`, `width`, `height`, `margin`, `padding`
- **Never use `transition: all`** — always specify exact properties: `transition: transform 0.3s, opacity 0.3s`
- **Spring physics feel natural**: use `cubic-bezier(0.34, 1.56, 0.64, 1)` for overshoot or Motion/Framer Motion springs
- **Staggered reveals**: use `animation-delay` with increment (e.g., `delay-[${i * 80}ms]`) for list/grid items

### Interruptible Animations [CRITICAL]

| | CSS Transitions | CSS Keyframes |
|---|---|---|
| **Behavior** | Interpolate toward latest state | Run on fixed timeline |
| **Interruptible** | Yes — retargets mid-animation | No — restarts from beginning |
| **Use for** | Interactive state changes (hover, toggle, open/close) | Staged sequences that run once (enter animations, loading) |

**Rule:** ALWAYS prefer CSS transitions for interactive elements. Reserve keyframes for one-shot sequences.

### Motion by Intensity Level

**Level 1–3: Subtle**
- Hover: scale(1.02) or translateY(-2px) with opacity shift
- Focus: ring animation
- No page-load animation

**Level 4–7: Expressive**
- Page load: staggered fade-up with slight blur clearing (`filter: blur(4px)` → `blur(0)`)
- Scroll entry: IntersectionObserver triggers `fade-up` class
- Hover: color shifts, underline animations, icon nudges
- Transitions between states (tabs, accordions) with height animation via grid-rows trick

```css
@keyframes fade-up {
  from { opacity: 0; transform: translateY(12px); filter: blur(4px); }
  to   { opacity: 1; transform: translateY(0);    filter: blur(0); }
}
```

**Exit Animations:** Use a small fixed `translateY(8px)` instead of full height. Duration `150ms`, easing `ease-in`. Exits should always be softer and faster than enters.

**Skip Animation on First Render:** Use `initial={false}` on Framer Motion's `AnimatePresence` to prevent enter animations on page load. Verify it doesn't break intentional entrance animations.

**Level 8–10: Cinematic**
- Scroll-linked parallax (CSS `scroll-timeline` or JS)
- Magnetic hover on buttons: track cursor position with `useMotionValue` (not `useState` — avoids re-renders)
- Morphing shapes, animated gradients, particle effects
- Page transitions with shared layout animations
- Spring physics on drag interactions

### Motion Anti-Patterns
- Don't animate layout properties (triggers reflow)
- Don't use `transition: all` (animates unintended properties, hurts perf)
- Don't animate more than 3 elements simultaneously on scroll (overwhelms)
- Don't use `setTimeout` for sequencing — use `animation-delay` or Motion's stagger

### Contextual Icon Animations
Animate icons with `opacity`, `scale`, and `blur` — not visibility toggling:
- Scale: `0.25` → `1`
- Opacity: `0` → `1`
- Blur: `4px` → `0px`
- Framer Motion: `transition: { type: "spring", duration: 0.3, bounce: 0 }` — bounce **must** be `0`
- CSS fallback: keep both icons in DOM (one absolute-positioned), cross-fade with `cubic-bezier(0.2, 0, 0, 1)` at `200ms`

### Fluid Island Navigation
Build navbars as floating glass pills, not edge-to-edge sticky bars:
- **Closed:** Floating pill detached from top (`mt-6 mx-auto w-max rounded-full`), glass-effect background
- **Hamburger Morph:** Lines rotate and translate to form an 'X' (`rotate-45` and `-rotate-45`) — never just disappear
- **Modal Expansion:** Screen-filling overlay with `backdrop-blur-3xl bg-black/80` or `bg-white/80`
- **Staggered Reveal:** Links fade in and slide up (`translate-y-12 opacity-0` → `translate-y-0 opacity-100`) with staggered delay
- **Active Link Indicator:** Sliding pill behind active nav item using `layoutId` for smooth transitions between pages
- **Scroll-Aware Collapse:** Nav shrinks or changes opacity on scroll — use `IntersectionObserver` or scroll-linked CSS

### Scroll Interpolation
Map scroll position to CSS custom properties for parallax-like effects without scroll hijacking. Use `scroll-timeline` or `IntersectionObserver` with `rootMargin` to drive animations proportionally to scroll progress. Never intercept native scroll behavior.

### Interpolation & mapRange (the modulation primitive)
Most "react this value to that value" motion (scroll-shrinking headers, pointer tilt, load-to-color, rubber-banding) is one function. Keep it in the toolbox:

```js
const mapRange = (value, [fromLow, fromHigh], [toLow, toHigh], clamp = true) => {
  let t = (value - fromLow) / (fromHigh - fromLow);
  if (clamp) t = Math.max(0, Math.min(1, t)); // clamp the FRACTION, not the result
  return toLow + t * (toHigh - toLow);
};
```

- **Ease the input before mapping** to bend the response curve: `easeInOut(t)` then map gives a Mac-dock magnification that ramps by cursor distance instead of linearly.
- **Dynamic header:** `mapRange(scrollY, [0, 128], [32, 16])` to shrink a title from 32 to 16px over the first 128px of scroll (iOS large-title behavior).
- **Pointer tilt:** `rotateY = mapRange(px, [0, 1], [-14, 14])` and `rotateX` inverted, where `px` is the cursor's 0 to 1 position across the card, so the midpoint is zero rotation and the card leans toward the cursor in 3D.
- **Number to color:** lerp per channel (or in OKLCH, §3.5) across stops to drive a load gauge green → amber → red.
- **Rubber-banding** (the iOS over-scroll feel): clamp WITH resistance via an asymptote rather than a hard stop. `t = pull / (pull + resistance); offset = mapRange(t, [0, 1], [0, 64])`, a bigger `resistance` makes a stiffer wall; the offset approaches but never reaches the ceiling, which reads as a soft boundary. Add a small dead zone so a casual over-drag does not trigger it.

### Layout Transitions
Heavily utilize Framer Motion's `layout` and `layoutId` props for smooth re-ordering, resizing, and shared element transitions. Any time elements move, resize, or swap positions, these props create fluid continuity instead of jarring jumps.

### Animation Craft (fast swaps, arcs, meaning)
- **Swap A for B by animating BOTH at once**, not sequentially. In Framer Motion's `AnimatePresence`, set `mode="popLayout"` so the exiting element pops out of layout flow immediately and the incoming one slides into place, the default `sync` mode leaves a gap or a jump. This is what makes a content swap feel seamless instead of staged.
- **Real objects travel in arcs, not straight lines.** When something flies across the screen (a card to a slot, a toast to a tray), move X linearly but bow Y with `y -= Math.sin(t * Math.PI) * peak`, and add a slight scale-up plus a growing shadow at the apex so it reads as lifting OFF the page and setting back down. (Framer Motion ships an `arc()` path helper.)
- **Prefer semantic motion over decorative motion.** Motion should carry meaning: an odometer-style digit roll as a value changes communicates "this number is updating" far better than a fade. Borrow from Disney's 12 principles for richness, but if an animation does not convey information, add delight, or express brand, cut it (the §0.8 less-but-better rule applies to motion too).
- **Stagger repeated elements** by a small per-item offset rather than animating a whole group at once, a radial menu or a list reads as alive instead of mechanical.

### Perpetual Micro-Interactions (MOTION_INTENSITY > 5)
Embed continuous infinite micro-animations in standard components:
- **Pulse**: breathing glow on status indicators
- **Typewriter**: cycling through placeholder text with blinking cursor
- **Float**: subtle vertical oscillation on decorative elements
- **Shimmer**: light-streak moving across surfaces
- **Carousel**: infinite horizontal scroll of logos, metrics, or cards

**Performance:** Any perpetual motion MUST be memoized (`React.memo`) and isolated in its own microscopic Client Component. Never trigger re-renders in the parent.

### Wave-Driven Motion & Generative Graphics
A sine wave `y = sin(2πt)` loops perfectly forever, which makes it a better engine for ANY looping/ambient motion than keyframes (keyframes have a visible seam at each turnaround; a wave is smooth everywhere). Three knobs: **frequency** (cycle speed), **amplitude** (range), **phase** (where the cycle starts).

- **Map a wave (output −1 to 1) onto any property** (scale, opacity, rotation, y-offset) for a float/breathe/pulse, amplitude dials the intensity.
- **Apply one wave across many elements with a per-element phase offset** (`sin(2π(t + i * 0.08))`) instead of a fixed time delay, the offset version reads organically, like breathing or a wind ripple, where staggered delays look mechanical.
- **Generative graphic recipe** (how the ambient hero/card art gets made with almost no code): render a row of bars whose width = a wave sampled across X, add a per-frame counter `t` so the field drifts, duplicate the row down the canvas, then add a per-row phase offset (`+ row * rowOffset`). A handful of mapped parameters plus seeded randomness yields a distinctive, animatable graphic, and because it is code (§4 compose-in-code), it recolors and re-themes for free. Combine waves of different frequencies with a persistence factor for more organic shapes.

### Bento Card Archetypes (Motion-Engine)
When building Bento grids, implement these specific micro-animated card patterns:
1. **The Intelligent List** — Vertical stack with infinite auto-sorting loop. Items swap using `layoutId`, simulating AI prioritization.
2. **The Command Input** — Search/AI bar with multi-step typewriter effect cycling through prompts, blinking cursor, shimmer loading gradient.
3. **The Live Status** — Scheduling interface with "breathing" status indicators. Pop-up notification badge with overshoot spring effect, stays 3s, vanishes.
4. **The Wide Data Stream** — Horizontal infinite carousel of data cards/metrics. Seamless loop (`x: ["0%", "-100%"]`).
5. **The Contextual UI** — Document view with staggered text highlight followed by float-in action toolbar.

### Scroll Entry
Elements should never appear statically on scroll. Use a heavy fade-up: `translate-y-16 blur-md opacity-0` → `translate-y-0 blur-0 opacity-100` over 800ms+. Trigger with `IntersectionObserver` or Framer Motion's `whileInView`. NEVER use `window.addEventListener('scroll')`.

### Mouse Interaction Patterns

Advanced cursor-driven interactions for MOTION_INTENSITY 6+. Each pattern includes when to use, implementation skeleton, and anti-pattern warning.

#### 1. Cursor Follower
A small circle/dot that follows the cursor with spring physics. Different from Magnetic (which moves the ELEMENT) — Cursor Follower moves a SEPARATE indicator.

**Use with**: Dark Cinematic, Retro-Future / Synthwave, Anti-Design / Experimental
**Anti-pattern**: Don't use a cursor follower AND a custom CSS cursor simultaneously — they compete for attention. Pick one.

```tsx
"use client";
import { useMotionValue, useSpring, motion } from "framer-motion";
import { useEffect } from "react";

export function CursorFollower() {
  const cursorX = useMotionValue(0);
  const cursorY = useMotionValue(0);
  const springX = useSpring(cursorX, { stiffness: 300, damping: 28 });
  const springY = useSpring(cursorY, { stiffness: 300, damping: 28 });

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      cursorX.set(e.clientX - 8);
      cursorY.set(e.clientY - 8);
    };
    document.addEventListener("mousemove", handler);
    return () => document.removeEventListener("mousemove", handler);
  }, [cursorX, cursorY]);

  return (
    <motion.div
      className="pointer-events-none fixed top-0 left-0 z-50 h-4 w-4 rounded-full bg-white mix-blend-difference"
      style={{ x: springX, y: springY }}
    />
  );
}
```

#### 2. Hover Image Reveal
Mouse over text link → image appears at cursor position. Common in portfolio/agency sites. Image follows cursor within the link bounds, fades in/out on enter/leave.

**Use with**: Editorial Luxury, Magazine Editorial, Dark Cinematic, Japanese Minimal
**Anti-pattern**: Don't preload ALL reveal images eagerly — lazy-load them. Don't exceed 200KB per reveal image.

```tsx
"use client";
import { motion, useMotionValue } from "framer-motion";
import { useState } from "react";
import Image from "next/image";

export function HoverImageLink({ text, imageSrc }: { text: string; imageSrc: string }) {
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const [hovered, setHovered] = useState(false);

  return (
    <a
      className="relative inline-block"
      onMouseMove={(e) => {
        const rect = e.currentTarget.getBoundingClientRect();
        x.set(e.clientX - rect.left + 16);
        y.set(e.clientY - rect.top + 16);
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {text}
      <motion.div
        className="pointer-events-none absolute z-10"
        style={{ x, y }}
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: hovered ? 1 : 0, scale: hovered ? 1 : 0.9 }}
        transition={{ duration: 0.2 }}
      >
        <Image src={imageSrc} alt="" width={300} height={200} className="rounded-lg" />
      </motion.div>
    </a>
  );
}
```

#### 3. Mouse-Driven Parallax
Background elements shift based on cursor position relative to viewport center. Different from scroll parallax — this responds to WHERE the cursor is on screen.

**Use with**: Retro-Future / Synthwave, Dark Cinematic, Soft Structuralism
**Anti-pattern**: Never apply mouse parallax to text — it makes content unreadable. Only use on decorative background elements. Cap displacement at 20-30px max.

```tsx
"use client";
import { useMotionValue, useSpring, useTransform, motion } from "framer-motion";
import { useEffect } from "react";

export function MouseParallaxLayer({ children, depth = 0.02 }: { children: React.ReactNode; depth?: number }) {
  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);
  const x = useSpring(useTransform(mouseX, (v) => v * depth), { stiffness: 100, damping: 30 });
  const y = useSpring(useTransform(mouseY, (v) => v * depth), { stiffness: 100, damping: 30 });

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      mouseX.set(e.clientX - window.innerWidth / 2);
      mouseY.set(e.clientY - window.innerHeight / 2);
    };
    document.addEventListener("mousemove", handler);
    return () => document.removeEventListener("mousemove", handler);
  }, [mouseX, mouseY]);

  return <motion.div style={{ x, y }}>{children}</motion.div>;
}
```

#### 4. Click-to-Reveal
Content hidden until clicked. Not an accordion — think: a sealed envelope that opens, a curtain that parts, a card that flips. Interaction-gated content that rewards curiosity.

**Use with**: Anti-Design / Experimental, Dark Cinematic, Japanese Minimal
**Anti-pattern**: Never gate critical content (CTAs, pricing, contact info) behind click-to-reveal. Only use for supplementary or experiential content. Provide a visual affordance that something IS clickable.

```tsx
"use client";
import { motion, AnimatePresence } from "framer-motion";
import { useState } from "react";

export function ClickReveal({ trigger, children }: { trigger: React.ReactNode; children: React.ReactNode }) {
  const [open, setOpen] = useState(false);

  return (
    <div className="cursor-pointer" onClick={() => setOpen(!open)}>
      <motion.div
        animate={{ rotateY: open ? 180 : 0 }}
        transition={{ duration: 0.6, ease: [0.34, 1.56, 0.64, 1] }}
      >
        {!open && trigger}
      </motion.div>
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: 12, filter: "blur(8px)" }}
            animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.4 }}
          >
            {children}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
```

#### 5. Scroll-Speed Responsive
Elements change behavior based on HOW FAST the user scrolls. Fast scroll = content blurs or streaks. Slow scroll = content reveals with detail. Uses velocity from `useScroll`.

**Use with**: Magazine Editorial, Dark Cinematic, Gen Z Expressive, Anti-Design / Experimental
**Anti-pattern**: Don't apply blur to text the user needs to read — only to decorative elements or images. Keep the velocity threshold high enough that normal scrolling doesn't trigger effects.

```tsx
"use client";
import { useScroll, useVelocity, useTransform, useSpring, motion } from "framer-motion";

export function ScrollSpeedBlur({ children }: { children: React.ReactNode }) {
  const { scrollY } = useScroll();
  const velocity = useVelocity(scrollY);
  const rawBlur = useTransform(velocity, [-2000, 0, 2000], [8, 0, 8]);
  const blur = useSpring(rawBlur, { stiffness: 200, damping: 40 });

  return (
    <motion.div style={{ filter: useTransform(blur, (v) => `blur(${v}px)`) }}>
      {children}
    </motion.div>
  );
}
```

---

## 5.5 INTERACTIVE 3D & MOTION, The Enforced Default (the Disciplined Ladder)

**OVERRIDE: every frontend this skill produces ships with motion that feels alive, purposeful, and premium, never flat. This is the enforced default, not an opt-in.** It consolidates and ELEVATES the craft already in §4 (depth, layered shadows, compositing), §5 (mapRange, semantic motion, popLayout, wave-driven loops), and §6 (GPU budget, reduced-motion) into one standing bar. Do not duplicate those sections; this section is the policy that puts them on by default.

The principle is RESTRAINT, not "heavy 3D on everything." If everything moves, nothing stands out, and try-hard 3D-on-everything is its own slop (jank, battery drain, broken accessibility). Motion must have a JOB: reveal hierarchy, carry spatial continuity, or give feedback. The default is a HIGH always-on floor plus ONE signature moment, behind hard guardrails. This calibrates ON TOP of the §1 MOTION_INTENSITY dial and the archetype, it does not override them: the dial scales the AMOUNT and intensity, the floor below sets the QUALITY bar that holds even at MOTION 2 (a Japanese Minimal build still earns real depth, real feedback, and interruptible transitions, it just expresses them quietly and skips the signature 3D moment).

### Tier 1, BASELINE MOTION (mandatory on every frontend, all archetypes)

This is the floor. It is present even on the most restrained, low-MOTION archetype (expressed quietly there, never absent).

- **Genuine depth and material.** A real elevation scale (resting / raised / overlay), each level a layered shadow (tight contact edge plus soft ambient falloff) per §4 Layered Tinted Shadows. Never a flat single-border or single-glow panel. Borders are transparent or inset so they stay crisp over the shadow (§4).
- **Purposeful, interpolation-driven motion.** Entrances and transitions are driven by `mapRange` / scroll-linked values (§5), shaped to the content, NOT one canned blur-up fade curve reused on every element. Vary the curve and the trigger by role.
- **Micro-interactions and feedback on EVERY interactive element.** Hover, press (`scale(0.96)` on `:active`, §4), focus-visible, and state changes all get a felt response. This is where §0.8 uncommon care lives.
- **Tasteful pointer-reactivity on a FEW key elements only.** Subtle tilt / magnetic / pointer-parallax on hero objects and primary cards (the §5 pointer-tilt `mapRange` and Mouse-Driven Parallax patterns). Layer-speed differences of roughly 20 to 30 percent for depth. A few hero areas, never the whole page, and never on text the user must read (§5 anti-pattern).
- **Scroll choreography that encodes meaning.** Reveals and parallax express hierarchy and narrative (§5 Scroll Entry, §7), not decoration bolted on.
- **Smooth, interruptible transitions.** CSS transitions for interactive state (they retarget mid-flight, §5), and `AnimatePresence` with `mode="popLayout"` for fast swaps so a content change reads seamless, not staged (§5 Animation Craft).
- **Stack:** CSS 3D transforms FIRST (zero JS, the first reach for UI depth) plus Framer Motion for UI motion, with GSAP + ScrollTrigger reserved for scroll storytelling. Keep GSAP and any R3F scene in their own isolated component trees, never co-mounted with Framer Motion in one tree, per §6 Animation Library Isolation.

### Tier 2, SIGNATURE MOMENT (default aim: about ONE per page or hero)

One genuine interactive 3D or spatial centerpiece that makes someone ask "how did they do that?" (§0.8). ONE, not many: a second competing 3D scene dilutes the first and doubles the cost.

- **Spline** via `@splinetool/react-spline` (the `@splinetool/react-spline/next` import gives an SSR placeholder), for a designer-authored interactive scene with a one-line embed. Fastest path to polished interactive 3D.
- **OR React Three Fiber** (`@react-three/fiber` + `@react-three/drei`) for a code/data-driven scene. MUST be loaded with `next/dynamic` and `ssr: false` (R3F has no SSR).
- **Lazy-load on viewport or interaction** (do not mount it at page load), and always ship a reduced-motion / no-WebGL fallback (a static render, poster image, or the quiet baseline).
- The signature moment is the DEFAULT AIM, not an absolute requirement. It YIELDS for restraint archetypes (Japanese Minimal, Opulent Noir, Swiss) where a heavy scene would fight the vibe, for mobile-primary builds, for LCP/SEO-critical heroes, and for /oneshot-webapp scope (see the yield clause below). When it yields, Tier 1 still holds.

### Tier 3, GUARDRAILS (always, non-negotiable, this is what stops it becoming slop or jank)

- **60fps / 16.7ms frame budget.** Animate ONLY `transform` and `opacity` (never layout props), per §5 and §6 GPU-Safe Animations. This is the line between premium and janky.
- **WebGL discipline (for any R3F / Spline scene):** keep draw calls under 100, share materials across meshes, Draco-compress geometry, and watch texture VRAM (oversized textures are the silent memory killer). Dispose geometries/materials/textures on unmount.
- **`prefers-reduced-motion` is a DIAL, not a kill switch.** Reduce or REPLACE large motion (parallax, scrubbed scenes, big travel) with fades and shortened durations rather than deleting it. Use a tiny non-zero duration (about `0.01ms`, the §6 value) so state-machine and `AnimatePresence` callbacks still fire, never a hard `0` that silently breaks state. Provide a pause control for anything that loops longer than ~5s. This IS the full-respect path §6 ("prefers-reduced-motion: All or Nothing") and §9 demand, the dial is the well-designed static/reduced fallback, NOT a half-measure that leaves some components animating.
- **Lazy-load heavy scenes (`ssr: false`), never block LCP.** A 3D hero must not be the Largest Contentful Paint blocker, gate it behind viewport/interaction and keep a lightweight first paint (see §9.5 for the landing-page reliability architecture).
- **Test on real mid-tier mobile, not just devtools.** WebGL thermally throttles and drains battery on phones (§9 known-quirks apply, Samsung battery saver throttles rAF). If it stutters or cooks the device, dial it down or drop to the baseline.

### When NOT to use 3D (reach for the cheaper layer instead)

Do not add a 3D scene when there is no real purpose for it. Specifically skip it (and stay on CSS 3D transforms, Framer Motion, or Lottie) when: the motion has **no job** (decorative only); the build is **mobile-primary** and the scene is heavy; the surface is an **LCP or SEO-critical hero**; the element is **a single icon** (use CSS or Lottie); it is **pure UI chrome** (use CSS plus Framer Motion); or there is **no WebGL expertise on a tight timeline** (use Spline's authored scenes or skip entirely). Forcing 3D into these cases is exactly the try-hard slop this ladder exists to prevent.

### Tool Roster (when to reach for each)

| Tool | Reach for it when | SSR / bundle / perf notes |
|---|---|---|
| **CSS 3D transforms** | FIRST choice for UI depth, tilt, card flips, parallax layers | Zero JS, GPU-composited (`transform`/`opacity`). No bundle cost. Always try this before a library. |
| **Framer Motion** | React UI motion: enter/exit, layout/`layoutId`, micro-interactions, `AnimatePresence` swaps | Client-only (`"use client"` leaves). The default UI-motion layer. Keep isolated from GSAP/R3F trees (§6). |
| **GSAP + ScrollTrigger** | Scroll storytelling, pinning, scrubbed timelines (§7) | Isolated full-page/canvas use with strict `useEffect` cleanup (§6). Webflow-owned, check the license for the plugin set. On landings, mobile reliability rules in §9.5 still govern. |
| **React Three Fiber + drei** | Code/data-driven interactive 3D, custom scenes, the signature moment | `next/dynamic` + `ssr: false` mandatory. Heaviest bundle, lazy-load it. drei gives loaders, controls, helpers. Obey the WebGL budget above. |
| **Spline** (`@splinetool/react-spline`) | Designer-authored interactive 3D with minimal code, the fastest signature moment | `/next` import gives an SSR placeholder. Scene file weight is the cost, lazy-load on viewport. No WebGL coding required. |
| **Theatre.js** | Declarative, keyframed motion sequencing over R3F or the DOM | Pairs with R3F. Use when a scene needs an authored timeline rather than reactive values. |
| **Rive** | State-driven interactive vector animation (responds to hover/state, real state machine) | ~200KB wasm runtime. Great for interactive icons/illustrations that have states. Lighter than a 3D scene. |
| **Lottie** | Lightweight prebaked vector animation (plays a baked clip, not interactive) | ~60KB runtime. Use for a single animated icon/illustration instead of a 3D scene. Not for stateful interaction. |
| **Raw WebGL / GLSL shaders** | Bespoke shader effects no library covers (custom backgrounds, distortion) | Maximum control, maximum cost and expertise required. Last reach, and only with the WebGL budget enforced. |

### Taxonomy guard, interactive-in-UI vs renders-to-VIDEO

Two layers that are constantly confused. Do not reach for a video tool when the design needs a LIVE scene.

- **Interactive-in-UI (what a signature 3D/motion moment needs):** Spline, React Three Fiber, Theatre.js, GSAP, Framer Motion, Rive, Lottie, CSS 3D transforms. These live and REACT in the running UI.
- **Renders-to-VIDEO (asset production, NOT in-UI 3D):** hyperframes and Remotion produce MP4/MOV/WebM video assets you drop into a `<video>` tag. They are NOT a live 3D canvas (hyperframes "supports Three.js" but rasterizes it to frames, so interactivity is lost). Use them to PRODUCE a promo/explainer clip, never as the interactive layer.

One-liner: if it has to respond to the user, it is interactive-in-UI (this section's stack). If it is a baked clip, it is a video asset (different tooling, out of scope here).

### /oneshot-webapp YIELD clause

When `/oneshot-webapp` is driving (ship-fast pitch/demo, SAFE preset, light mode only), the **signature 3D moment becomes OPTIONAL** and motion **dials down to the cheap baseline**: ship speed and the safe preset win. The Tier 1 baseline FLOOR still applies (real depth, purposeful entrances, per-element feedback, interruptible transitions) because that is cheap and is exactly the polish that separates a pitch demo from generic shadcn. Skip the WebGL scene unless the brief explicitly asks for it and the timeline allows. This yield mirrors the One-Shot Pitch/Demo Webapps non-negotiables.

---

## 6. PERFORMANCE

Ship fast interfaces, not just pretty ones.

### Perceived Performance (the fastest interface is the one that FEELS instant)
Real speed matters, but PERCEIVED speed is what the user judges. The best loading state is one they never see:

- **Mask the wait.** Do unavoidable work in the background behind something worth the user's attention. A short, delightful onboarding or transition animation can buy the seconds needed to fetch/index/sort, so that for most users everything is ready by the time they finish watching, vs staring at a spinner.
- **Optimistic writes.** Do not block the UI on a server round-trip. Assume success and show the result immediately (the "like" fills the instant it is tapped); on a failure callback, revert and show a retry toast WITHOUT losing the user's place. Scales to multi-step flows: let them proceed, reconcile in the background.
- **Optimistic reads.** Cache the last state the user saw locally and render it instantly, then reconcile with the server, so the screen never does the jarring blank → default → real-data flip.

A little more engineering, much better felt-quality. This is §0.8 uncommon care applied to the moments between interactions.

### GPU-Safe Animations
- `transform` and `opacity` are composited on the GPU — stick to these
- Add `will-change: transform` only when animation is imminent, remove after
- `contain: layout` on animated containers to isolate reflows

### Backdrop-blur Budget
- `backdrop-filter: blur()` is expensive — only use on `position: fixed` or `position: sticky` elements (nav, modals, toasts)
- Never on scrolling list items or repeated cards in a grid

### Grain & Noise Overlays
- Apply grain as a `position: fixed; pointer-events: none` element covering the viewport
- Use SVG `<feTurbulence>` filter or a tiny repeating PNG (< 5KB)
- opacity: 0.02–0.05 for subtle texture, never more than 0.08

### Image & Font Loading
- All images: explicit `width` and `height` attributes (or aspect-ratio) to prevent CLS
- Fonts: `font-display: swap`, preload critical fonts
- Icons: inline SVG or icon component — never icon font CDN loads

### Reduced Motion
Always respect `prefers-reduced-motion`:
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Component Performance
- Memoize perpetual-motion components (animated backgrounds, particle effects) with `React.memo`
- Intersection Observer for scroll animations — don't run on every scroll event
- Debounce resize handlers, throttle mousemove trackers

### `will-change` Discipline

| Property | GPU-compositable | Worth `will-change` |
|---|---|---|
| `transform` | Yes | Yes |
| `opacity` | Yes | Yes |
| `filter` | Yes | Sometimes |
| `background-color` | No | No |
| `padding`, `width` | No | No |

Never use `will-change: all`. Only add when you notice first-frame stutter, and remove after.

### Tailwind `transition` Trap
Tailwind's bare `transition` utility maps to `transition-property: color, background-color, border-color, text-decoration-color, fill, stroke, opacity, box-shadow, transform, translate, scale, rotate, filter, backdrop-filter` — effectively `transition: all`. Always use specific utilities: `transition-transform`, `transition-colors`, or bracket syntax `transition-[scale,opacity,filter]`.

### `staggerChildren` Tree Rule
Framer Motion's parent `variants` (with `staggerChildren`) and all children MUST reside in the same Client Component tree. If data is fetched asynchronously, pass data as props into a centralized parent Motion wrapper — never split across component boundaries.

### Animation Library Isolation
Never mix GSAP/ThreeJS with Framer Motion in the same component tree. Default to Framer Motion for UI and Bento interactions. Use GSAP/ThreeJS exclusively for isolated full-page scrolltelling or canvas backgrounds, wrapped in strict `useEffect` cleanup blocks.

### Performance Budget

Hard limits — measure these before shipping:

| Metric | Target | Tool |
|--------|--------|------|
| First-load JS | < 200KB per page | `next build` output, webpack-bundle-analyzer |
| LCP | < 2.5s on 4G | Lighthouse, WebPageTest |
| CLS | < 0.1 | Lighthouse |

#### Image Rules
- `next/image` required for all images in Next.js projects
- `sizes` + `srcset` mandatory — never serve a 2000px image to a 400px container
- Format preference: AVIF > WebP > JPEG (configure in `next.config.js` with `formats: ['image/avif', 'image/webp']`)
- Max file sizes: **200KB per hero image**, **100KB per card image**
- Always specify `width`, `height`, and `alt`

### Animation Robustness Patterns

#### Scroll-Triggered Reveal Hierarchy
Prefer reliability over elegance. The fallback chain for scroll-triggered reveals:
1. **`useOnScreen` (manual scroll listener)** — `scroll` + `resize` events with `getBoundingClientRect()`. Most reliable across all browsers and devices. Use as primary.
2. **`useInView` (IntersectionObserver-based)** — cleaner API, but unreliable on iOS Safari with `once: true` + negative `rootMargin`, and can fail silently on budget Android.
3. **CSS `animation-play-state` (pure CSS fallback)** — zero-JS fallback using `@scroll-timeline` or `:target` selectors. Limited browser support but zero failure surface.

#### Mount-Animation vs Scroll-Animation Decision Tree
- **Hero / above-fold content** → mount-animate (plays on page load, `useEffect` or CSS `@keyframes` on mount)
- **Below-fold content** → scroll-triggered ONLY. NEVER mount-animate below-fold — the user scrolls down and sees static content because animations already completed invisibly.

#### Transition Delay Stacking
Total perceived delay = section delay + local element delay + stagger offset. Always calculate the total:
```
sectionDelay + elementDelay + (index * staggerInterval) = totalDelay
```
**Hard cap: 3 seconds maximum total delay.** Beyond 3s, the user perceives lag, not choreography.

#### prefers-reduced-motion: All or Nothing
Either respect `prefers-reduced-motion` across the ENTIRE application (every component, every animation, well-tested) or don't respect it at all. **Half-measures are worse than no support:**
- Some components respect it, some don't → inconsistent UX, confusing for users who need it
- `useReducedMotion` hook + global CSS `@media (prefers-reduced-motion: reduce)` kill-switch → silent animation death on budget Android devices that report reduced motion by default
- If you choose to respect it, audit EVERY animated component and verify the static fallback is well-designed, not just "animations removed"

---

## 7. SCROLLYTELLING PATTERNS

Scrollytelling turns a page into a narrative. The user's scroll position drives the story. These patterns are additive to §5 Motion — use them when the design calls for editorial / narrative-driven experiences (Apple product pages, Linear homepage, Stripe Sessions, NYT Snowfall, Pudding, Active Theory, Locomotive, Studio Freight, Hello Monday). Respect the performance rules in §6 and the mobile caveats in §9.

### 7.1 Scrollytelling Vocabulary

Use these terms precisely throughout the rest of this section:

- **Pin / Sticky scroll** — section stays fixed while user scrolls past; content morphs in place.
- **Scrub** — animation progress mapped to scroll progress (user can drag back and forth to control it).
- **Trigger** — animation fires once at a scroll point (not scrubable, plays through to completion).
- **Beat / Chapter** — a discrete narrative step within a longer scrolljacked section.
- **Smooth scroll / inertia scroll** — virtual scroll with momentum (Lenis pattern). Native scroll remains the source of truth; Lenis just adds inertia on top.
- **Scroll-jack** — temporarily override native scroll for narrative effect. Controversial — use sparingly; always provide an escape.

### 7.2 The 6 Core Scrollytelling Patterns

Each pattern: when to use, archetypes that fit, code skeleton, anti-pattern warning.

#### Pattern 1: Sticky Hero with Morphing Content

Hero section pins for N viewport heights. As user scrolls within the pin range, headline transforms — text changes, image swaps, layout reflows. Apple iPhone product pages are the canonical example.

```tsx
"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

export function StickyHero() {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end end"] });
  const opacity1 = useTransform(scrollYProgress, [0, 0.33], [1, 0]);
  const opacity2 = useTransform(scrollYProgress, [0.33, 0.66], [0, 1]);
  const opacity3 = useTransform(scrollYProgress, [0.66, 1], [0, 1]);

  return (
    <section ref={ref} className="relative h-[300vh]">
      <div className="sticky top-0 h-screen flex items-center justify-center">
        <motion.h1 style={{ opacity: opacity1 }} className="absolute">First state</motion.h1>
        <motion.h1 style={{ opacity: opacity2 }} className="absolute">Second state</motion.h1>
        <motion.h1 style={{ opacity: opacity3 }} className="absolute">Third state</motion.h1>
      </div>
    </section>
  );
}
```

**Best fits:** Dark Cinematic, Editorial Luxury, Magazine Editorial.
**Anti-pattern:** don't pin for more than 5 viewport heights — user gets lost. Always provide a visual progress indicator (scroll dots, progress bar, chapter count).

#### Pattern 2: Multi-Beat Narrative Within Section

A pinned section with 3–5 narrative beats, each one viewport tall. Content fades between beats. NYT Snowfall is the reference.

```tsx
"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

const BEATS = [
  { title: "Beat 1", body: "..." },
  { title: "Beat 2", body: "..." },
  { title: "Beat 3", body: "..." },
  { title: "Beat 4", body: "..." },
];

export function MultiBeat() {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end end"] });

  return (
    <section ref={ref} className="relative" style={{ height: `${BEATS.length * 100}vh` }}>
      <div className="sticky top-0 h-screen flex items-center justify-center">
        {BEATS.map((beat, i) => {
          const start = i / BEATS.length;
          const end = (i + 1) / BEATS.length;
          const opacity = useTransform(scrollYProgress, [start - 0.05, start, end - 0.05, end], [0, 1, 1, 0]);
          return (
            <motion.div key={i} style={{ opacity }} className="absolute max-w-2xl text-center">
              <h2>{beat.title}</h2>
              <p>{beat.body}</p>
            </motion.div>
          );
        })}
      </div>
    </section>
  );
}
```

**Best fits:** Magazine Editorial, Dark Cinematic, Editorial Luxury, Warm Craft.
**Anti-pattern:** don't stack more than 5 beats in a single pin — fatigue sets in. If the story needs more, split into multiple pinned sections with a breath in between.

#### Pattern 3: Scrubbed Video / Sequence Animation

Video timeline (or PNG sequence frames) controlled by scroll position. Apple iPad Pro launch did this beautifully — the device rotates in 3D as you scroll.

```tsx
"use client";
import { useEffect, useRef } from "react";
import { useScroll } from "framer-motion";

export function ScrubbedVideo({ src }: { src: string }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const { scrollYProgress } = useScroll({ target: containerRef, offset: ["start start", "end end"] });

  useEffect(() => {
    const unsub = scrollYProgress.on("change", (v) => {
      const video = videoRef.current;
      if (video && video.duration) {
        video.currentTime = v * video.duration;
      }
    });
    return () => unsub();
  }, [scrollYProgress]);

  return (
    <section ref={containerRef} className="relative h-[400vh]">
      <div className="sticky top-0 h-screen flex items-center justify-center">
        <video ref={videoRef} src={src} muted playsInline preload="auto" className="w-full h-full object-cover" />
      </div>
    </section>
  );
}
```

**Best fits:** Dark Cinematic, Bold Geometric, Playful Pop.
**Performance note:** video must be encoded with a keyframe at every frame (no GOP optimization) — otherwise scrubbing seeks to wrong frames. Encode with `-x264-params keyint=1:min-keyint=1:scenecut=0` or similar. PNG sequences give better quality per scrubbed frame but the total payload is heavier; lazy-load and decode on the main thread only after the section enters the viewport.
**Anti-pattern:** don't scrub a video taller than 1080p on mobile — the decode cost causes jank. Mobile should always fall back to a static image or simple fade (see §7.6).

#### Pattern 4: Horizontal Scroll Within Vertical

Section pins. As user scrolls vertically, content scrolls horizontally. Common for project portfolio reels, timelines, and chapter galleries in agency sites.

```tsx
"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

export function HorizontalReel({ projects }: { projects: { id: string; src: string; title: string }[] }) {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end end"] });
  const x = useTransform(scrollYProgress, [0, 1], ["0%", "-100%"]);

  return (
    <section ref={ref} className="relative h-[400vh]">
      <div className="sticky top-0 h-screen overflow-hidden">
        <motion.div style={{ x }} className="flex h-full">
          {projects.map((p) => (
            <div key={p.id} className="w-screen flex-shrink-0 flex items-center justify-center">
              {/* project content */}
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
```

**Best fits:** Magazine Editorial, Anti-Design, Editorial Luxury.
**Anti-pattern:** don't combine horizontal-on-vertical with scrub-video in the same pin — the user loses their sense of axis. One narrative device per pinned section.

#### Pattern 5: Scene-Based Section Transitions

One section morphs INTO the next instead of hard cut. Color shifts, layout reflows, text crossfades during the boundary scroll range. The seam between sections becomes part of the choreography.

Implementation tools:
- **Framer Motion `layoutId`** for shared element transitions across sections.
- **Scroll-tied background color** using `useScroll` + `useTransform` on a fixed-position bg layer.
- **Choreographed exit/enter**: outgoing section fades + scales down as incoming section fades + scales up, both driven by the same `scrollYProgress` range covering the boundary.

```tsx
"use client";
import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

export function SceneBoundary() {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start end", "end start"] });
  const bg = useTransform(scrollYProgress, [0, 1], ["#0b0b0f", "#f5f0e6"]);

  return (
    <motion.div ref={ref} style={{ backgroundColor: bg }} className="min-h-[200vh]">
      {/* section A + section B nested inside; bg animates across the seam */}
    </motion.div>
  );
}
```

**Best fits:** Editorial Luxury, Soft Structuralism, Warm Craft.
**Anti-pattern:** don't morph MORE than two sections at a time — chaining three+ continuous scene transitions reads as a single blurry block rather than distinct scenes.

#### Pattern 6: Parallax Depth Layers

3+ layers moving at different speeds creating depth illusion. Foreground fast, mid normal, background slow. Optional counter-direction on the nearest-to-camera layer for extra depth.

```tsx
"use client";
import { motion, useScroll, useTransform } from "framer-motion";

export function ParallaxScene() {
  const { scrollY } = useScroll();
  const yBg = useTransform(scrollY, [0, 1000], [0, 200]);  // slow, far
  const yMid = useTransform(scrollY, [0, 1000], [0, 100]); // normal, mid
  const yFg = useTransform(scrollY, [0, 1000], [0, -50]);  // fast, near (counter-direction)

  return (
    <section className="relative h-screen overflow-hidden">
      <motion.div style={{ y: yBg }} className="absolute inset-0">{/* back layer */}</motion.div>
      <motion.div style={{ y: yMid }} className="absolute inset-0">{/* mid layer */}</motion.div>
      <motion.div style={{ y: yFg }} className="absolute inset-0">{/* front layer */}</motion.div>
    </section>
  );
}
```

**Best fits:** Dark Cinematic, Retro-Future / Synthwave, Warm Craft, Editorial Luxury.
**Anti-pattern:** don't parallax text that the user must read — it makes reading unpleasant. Parallax decorative layers only. Keep depth displacement under 200px on any layer.

### 7.3 Smooth Scroll Integration (Lenis)

Recommended library: **`lenis`** (Studio Freight, MIT). Drop-in smooth scroll with inertia, momentum, and programmatic scroll-to. Auto-syncs with Framer Motion's `useScroll` — no additional integration needed.

**Install:**

```bash
npm install lenis
# or
pnpm add lenis
# or
bun add lenis
```

**Wrap at app root (client component):**

```tsx
// app/providers.tsx
"use client";
import { ReactLenis } from "lenis/react";

export function SmoothScrollProvider({ children }: { children: React.ReactNode }) {
  return (
    <ReactLenis
      root
      options={{
        duration: 1.2,
        easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      }}
    >
      {children}
    </ReactLenis>
  );
}
```

```tsx
// app/layout.tsx
import { SmoothScrollProvider } from "./providers";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SmoothScrollProvider>{children}</SmoothScrollProvider>
      </body>
    </html>
  );
}
```

**Critical:** Lenis syncs with Framer Motion's `useScroll` automatically. Install + wrap is the full integration.

**When NOT to use Lenis:**
- Pages with heavy `position: sticky` usage — Lenis's virtual scroll can fight sticky positioning at section boundaries. Test thoroughly before shipping.
- Mobile (Lenis disables itself by default on touch devices to preserve native momentum scroll — this is the correct default, don't override).
- Archetypes whose vibe contradicts inertia: **Neo-Brutalist** (jarring is the point), **Corporate Confident** (predictable native scroll wins trust).

### 7.4 Scrub vs Trigger — Decision Tree

**Use SCRUB** (scroll progress drives animation progress) when:
- The animation is longer than ~500ms total and the user benefits from pacing it.
- Each scroll position represents a discrete narrative state (beats, chapters).
- The effect is parallax, depth, or video-timeline-like.
- The animation is reversible and should feel reversible (scroll back undoes it).

**Use TRIGGER** (animation fires once at a scroll point) when:
- The animation is short (< 500ms) — an enter reveal, a fade-up, a text appear.
- The motion is one-shot: count-up numbers, brand intro, a single flourish.
- Reversing the animation when scrolling up would feel weird (e.g., a count-up uncounting).

**Anti-pattern:** scrubbing a 200ms animation feels janky — the user's scroll wheel granularity is too coarse for it. Triggering a 3-second animation feels detached — the user expects their scroll to affect it. **Match technique to duration.**

### 7.5 Performance Budget for Scroll

Hard limits for scrollytelling pages — measure before shipping.

- **Max 3 concurrent `useScroll` instances per page.** Each one is a scroll listener; too many compounds jank. Consolidate by sharing one `useScroll` across multiple derived `useTransform` values.
- **Every scroll-tied transform MUST use GPU-composited properties: `transform`, `opacity`, `filter` ONLY.** Never `top`, `left`, `width`, `height`, `margin`, `padding` — these trigger reflow on every scroll frame.
- **`will-change: transform` on scrubbed elements** — but remove it once the section leaves the viewport, otherwise you hold GPU layers for no reason. Use an `IntersectionObserver` to toggle it.
- **For video scrub:** encode with all-keyframes (`-x264-params keyint=1:min-keyint=1:scenecut=0`) or use an image sequence. Otherwise scrubbing seeks to wrong frames.
- **Avoid nested scroll containers.** `overflow-auto` inside another `overflow-auto` fights the pin logic; both containers try to own the scroll.
- **Degrade gracefully on mobile.** Detect with `matchMedia("(min-width: 1024px)")` or `"ontouchstart" in window` and swap heavy scrubbed scrollytelling for simpler scroll-triggered reveals. See §7.6.

### 7.6 Mobile Scrollytelling Considerations

Most scrollytelling patterns are **desktop-first experiences**. Mobile needs a fallback path for each one.

- **Pin-based scrollytelling** can break on iOS Safari (known `position: sticky` bugs at viewport boundaries, especially when URL bar collapses/expands). Test on real iOS devices; don't trust devtools emulation.
- **Scrubbed video** is too heavy on mobile — swap for a static image fade or a tiny 3-frame sequence.
- **Horizontal-on-vertical scroll** confuses mobile users used to native horizontal swipe. Swap for a native horizontal swipe carousel (CSS scroll-snap).
- **Lenis** disables itself on touch by default — don't override this.
- **Multi-beat narrative** can stay, but shorten beats (full-viewport on mobile is cramped) and reduce the total number of beats by ~40%.

**Pattern:** build desktop scrollytelling first, then gate the heaviest patterns behind `@media (hover: hover)` or `@media (min-width: 1024px)`. Mobile gets the simpler fallback path. See §9 (Mobile Animation Resilience) for the broader mobile-reliability rules that apply here.

### 7.7 Archetype × Scrollytelling Recommendation Matrix

| Archetype | Recommended Patterns | Avoid |
|---|---|---|
| Editorial Luxury | sticky hero, scene transitions, multi-beat | scrubbed video, horizontal scroll |
| Soft Structuralism | scene transitions, scroll-triggered reveals | scroll-jack, video scrub |
| Neo-Brutalist | hard scrub jumps, jarring transitions | smooth Lenis (contradicts vibe) |
| Japanese Minimal | parallax depth (subtle), Lenis | any scroll-jack |
| Magazine Editorial | sticky hero, horizontal scroll, scene transitions | none — magazine = scrollytelling native |
| Warm Craft | parallax depth, scene transitions | scroll-jack, scrubbed video |
| Dark Cinematic | scrubbed video, sticky hero, parallax depth | none — cinematic = built for scrollytelling |
| Corporate Confident | scroll-triggered reveals only | sticky hero, scrub, scroll-jack |
| Playful Pop | bouncy scrubs, scene transitions, parallax | static reveals only (boring for vibe) |
| Gen Z Expressive | aggressive scroll-jack, scrubbed video, horizontal scroll | restraint of any kind |
| Anti-Design | unconventional scroll directions, custom scroll behaviors | any "best practice" |
| Swiss / International Typographic | scroll-triggered reveals, sticky hero, grid-aligned snap | scrubbed video, scroll-jack |
| Terminal / Monospace | scroll-triggered reveals, typewriter sequences | smooth Lenis, heavy parallax |
| Retro-Future / Synthwave | scrubbed video, parallax depth, scene transitions | restraint of any kind |
| Opulent Noir | sticky hero, scene transitions, slow reveals | scrubbed video, scroll-jack |
| Y2K / Frutiger Aero | bouncy scrubs, scene transitions, parallax depth | austere static reveals (off-vibe) |
| Memphis / Postmodern Maximalist | scene transitions, bouncy scrubs, horizontal scroll | smooth restraint, slow reveals |
| Claymorphism / Soft 3D | scene transitions, scroll-triggered reveals (bouncy) | scroll-jack, scrubbed video |
| Risograph / Zine Print | scroll-triggered reveals, scene transitions | scrubbed video, smooth parallax |

### 7.8 Implementation Checklist for Scrollytelling Pages

Before declaring a scrollytelling section done, verify every item:

- [ ] Lenis installed + wrapped at root (or documented reason why not, e.g., heavy sticky usage, Neo-Brutalist vibe)
- [ ] All scrubbed properties are `transform` / `opacity` / `filter` (never layout properties)
- [ ] Pin sections have a visible progress indicator (scroll dots, progress bar, chapter count)
- [ ] Mobile fallback path built for every scrollytelling pattern used
- [ ] Tested on a real mobile device, not just desktop devtools mobile mode
- [ ] No more than 3 concurrent `useScroll` instances on the page
- [ ] Scrub animations use `will-change: transform` while in viewport, cleaned up on exit
- [ ] User can still escape a pinned section (no "soft scroll-jack" trapping that requires extreme scroll velocity to break out)
- [ ] `prefers-reduced-motion` respected — scrubs degrade to instant state transitions, not ignored
- [ ] Video scrub assets encoded with keyframe-per-frame (or swapped to image sequence)
- [ ] No nested scroll containers around pinned sections

---

## 8. ANTI-SLOP — Banned Patterns

This section is non-negotiable. These patterns produce generic, recognizable AI output.

### Banned Fonts
**NEVER use**: Inter, Roboto, Arial, Open Sans, Helvetica, Lato, Montserrat, Poppins, Nunito (plain), Source Sans Pro

These are the "default suggestion" fonts. They signal zero design thought. There are hundreds of excellent alternatives — use them.

### Banned Colors
- **Purple/violet AI gradients** (the "AI startup" look) — BANNED
- **Pure #000000 on white** — BANNED (use zinc-950 or a tinted near-black) unless Dark Cinematic vibe
- **More than 1 accent color** — almost always BANNED. One accent, everything else neutral.
- **Saturation > 80%** on any large surface — BANNED. High saturation is for tiny accents only.
- **Blue-to-purple gradients** — BANNED. Find literally any other gradient direction.
- **Teal + coral** as a pair — overused, BANNED
- **Neon/outer glows** — no default `box-shadow` glows. Use inner borders or subtle tinted shadows.
- **Excessive gradient text** — no text-fill gradients on large display headers
- **Custom mouse cursors** — outdated, ruins performance and accessibility

### Banned Layouts
- **3-column equal-width cards** as the default section pattern — BANNED. Use bento, asymmetric, or varied sizes.
- **Centered hero → 3 features → CTA** cookie-cutter structure — BANNED when DESIGN_VARIANCE > 4
- **Perfectly centered everything** — BANNED when DESIGN_VARIANCE > 4. Offset, align-start, break the center.

### Banned Content
- Generic placeholder names: "Acme Corp," "John Doe," "Jane Smith" — BANNED. Use contextually relevant names or ask the user.
- Lorem Ipsum — BANNED. Write real microcopy that fits the context.
- Filler power-words: "Elevate," "Seamless," "Unleash," "Unlock," "Supercharge," "Revolutionary," "Next-gen," "Cutting-edge," "Leverage," "Empower," "Transform your workflow" — ALL BANNED. Write like a human.
- "Trusted by 10,000+ companies" with fake logos — BANNED unless the user provides real data
- Fake round numbers: `99.99%`, `50%`, `10,000` — BANNED. Use organic data: `47.2%`, `8,347`, `+1 (312) 847-1928`
- Startup slop brand names: "Nexus", "SmartFlow", "Synapse", "Pulse" — BANNED. Invent premium, non-generic names.
- Broken Unsplash links — BANNED. Use `https://picsum.photos/seed/{random_string}/800/600` for placeholder images.
- "Oops!" error messages — BANNED. Be direct: "Connection failed." No exclamation marks in success messages.

### Banned Icons
- Thick-stroke Lucide icons as the default — BANNED
- FontAwesome — BANNED (too recognizable, too heavy)
- Heroicons solid — BANNED for UI chrome (acceptable for filled states)
- **Use instead**: Phosphor Icons (Light weight), Radix Icons, or custom SVG
- Cliché icon metaphors — BANNED: no rocketship for "Launch", shield for "Security", lightbulb for "Ideas". Use less obvious icons (bolt, fingerprint, spark, vault).
- Inconsistent stroke widths — standardize to one stroke weight globally

### Banned Components
- Default unstyled `<select>` dropdowns — BANNED, build custom or use Radix
- Browser-default checkboxes and radios — BANNED in polished UIs
- Alert/toast components with no entrance animation — BANNED
- Modals without backdrop blur or dim — BANNED
- **shadcn/ui in default state** — BANNED. MUST customize radii, colors, shadows to match the aesthetic.
- `window.alert()` — BANNED. Use inline feedback or toast components.
- Generic circular spinners — BANNED. Use skeletal loaders matching layout shape.

### Banned: glowing-edge + left-dot pill badges

Do NOT use the following badge pattern in any generated landing / marketing component:

- Rounded pill with gradient / glowing outer edge (ring-offset or box-shadow glow)
- Small colored dot (● / •) on the left side
- Uppercase tracked text

This pattern is instantly recognizable as "AI-generated SaaS landing" aesthetic and has become visually tired. Recent offenders: hero LIVE indicator, section eyebrows like "WHAT PULSE DOES", "A DAY ON PULSE".

**Acceptable badge alternatives:**

1. **Simple tonal pill** — solid single-tone background (e.g., `bg-accent/10`), no dot, no glow, `rounded-md` or `rounded-full`, plain or uppercase text. Clean, functional, timeless.
2. **No-container eyebrow** — text prefixed with em-dash or bullet, no pill. Example: `— Section Title` or `• Live`. Works well when paired with strong h2/h3 typography below.
3. **Thin underline eyebrow** — small tracked text with an accent-colored underline, no container.

For "live" indicators (where the badge is communicating real-time status, not styling), prefer an actual small pulsing dot via CSS `@keyframes` with minimal scale/opacity animation (no filter, no shadow). The animation earns the live-indicator semantic; without animation, the left-dot is decorative noise.

### Banned: Visual Inconsistency (the quiet slop)

Inconsistency is the biggest tell between considered and thrown-together work, and a user reads it as a bug even when they cannot name it. Scan for and eliminate:

- **Mixed icon styles** (fill vs outline, two stroke widths, two corner radii in one set), **disagreeing corner radii** across siblings, **mixed materiality** (a glassy control beside a flat one), and **stray one-off strokes/fills**. Fix per §4 Style Consistency.
- **Mismatched color temperature** (cool-grey text on a warm palette, or two neutral families mixed). One temperature, ~3 neutrals from one family, per §3.5.
- **A single muddy `box-shadow`** instead of a layered tight+ambient pair (§4), and **solid-color borders** that blur over shadows instead of transparent/inset ones (§4).

Treat these as hard violations in the §10 / §11 passes, not "nice to fix."

### Creative Arsenal (High-End Patterns)

Pull from these when the design calls for something elevated:

**Navigation:** Mac OS Dock Magnification, Magnetic Button, Gooey Menu, Dynamic Island, Contextual Radial Menu, Floating Speed Dial, Mega Menu Reveal.

**Layout:** Bento Grid (asymmetric tiles), Masonry Layout, Chroma Grid, Split Screen Scroll, Curtain Reveal.

**Cards:** Parallax Tilt Card, Spotlight Border Card, Glassmorphism Panel, Holographic Foil Card, Tinder Swipe Stack, Morphing Modal.

**Scroll:** Sticky Scroll Stack, Horizontal Scroll Hijack, Locomotive Scroll Sequence, Zoom Parallax, Scroll Progress Path, Liquid Swipe Transition.

**Galleries:** Dome Gallery, Coverflow Carousel, Drag-to-Pan Grid, Accordion Image Slider, Hover Image Trail, Glitch Effect Image.

**Typography:** Kinetic Marquee, Text Mask Reveal, Text Scramble Effect, Circular Text Path, Gradient Stroke Animation, Kinetic Typography Grid.

**Micro-Interactions:** Particle Explosion Button, Liquid Pull-to-Refresh, Directional Hover Aware Button, Ripple Click Effect, Animated SVG Line Drawing, Mesh Gradient Background, Lens Blur Depth.

---

## 9. MOBILE ANIMATION RESILIENCE

Mobile is where animations go to die. Every animation pattern must be validated on real mobile viewports before shipping. For scrollytelling-specific mobile concerns (pin bugs on iOS Safari, scrubbed video fallbacks, horizontal-on-vertical scroll alternatives), see §7.6.

### Rules

- **NEVER rely solely on IntersectionObserver for critical reveals.** Always provide a `useOnScreen` manual scroll+resize+`getBoundingClientRect` fallback. IO is unreliable on iOS Safari (timing issues with `once: true` + negative `rootMargin`) and budget Android Chromium builds.
- **Test with Playwright mobile device presets (Pixel 5 for Android, iPhone 13 Pro for iOS) BEFORE shipping.** Desktop-only testing is not acceptable for any page with scroll-triggered animations.
- **Inject a MobileErrorOverlay during development** — a fixed bottom bar capturing `window.onerror` + `unhandledrejection` + env state (viewport size, user agent, scroll position). Auto-strip before production ship. This catches silent JS failures that kill animations on mobile but pass on desktop.

### Anti-Patterns

- **`useReducedMotion` + global CSS kill-switch = silent animation death.** Budget Android devices (Samsung Galaxy A series, Xiaomi Redmi) may report `prefers-reduced-motion: reduce` by default or via OEM settings. A global kill-switch silently disables all animations for a large chunk of mobile users. Either respect reduced-motion FULLY (all components, well-tested fallback states) or don't respect it at all. Half-measures where some components respect and some don't = guaranteed bug.
- **Mount-animating below-fold content.** User scrolls down and sees static content because animations already completed during page load while the element was off-screen. Below-fold MUST be scroll-triggered, and the scroll trigger MUST work on mobile viewports.

### Known Browser Quirks

| Browser / Environment | Quirk |
|---|---|
| **Brave** | Fingerprint protection can interfere with IntersectionObserver and canvas APIs |
| **Android Chromium vendor builds** | Budget phones ship stale Chromium forks — IO behavior may differ from Chrome stable |
| **iOS Safari** | IO timing is unreliable with `once: true` + negative `rootMargin` — elements may never trigger |
| **Samsung Internet** | Aggressive battery saver can throttle `requestAnimationFrame` and transition timers |

---

## 9.5 LANDING PAGE ARCHITECTURE (Android Chromium Lessons)

Production lessons from a multi-iteration debugging session (pulse-landing, 2026-04) where Framer Motion scroll-reveal animations never fired on Android Chrome / Brave / Firefox. Seven hypothesis-fix cycles failed (whileInView variants, SafetyNet force-reveal, Lenis disable, class-based CSS, rAF backstops, IO threshold tweaks, per-section "use client"). The fix was porting an existing WORKING landing's architecture verbatim. These patterns are now the canonical approach for landing pages in this codebase family.

### 9.5.1 Next.js App Router Landing Architecture

For any Next.js 15+ App Router landing page using Framer Motion or scroll-reveal:

- Wrap the entire landing in `dynamic(() => import("./Landing"), { ssr: false })` via a thin LandingLoader component. Do NOT rely on per-island `"use client"` in an otherwise Server-Component page — hydration boundaries misfire on Android Chrome variants (Chrome, Brave, Samsung Internet, WebView).

`page.tsx` pattern:

```tsx
import LandingLoader from "./LandingLoader";
export default function Page() { return <LandingLoader />; }
```

`LandingLoader.tsx` pattern:

```tsx
"use client";
import dynamic from "next/dynamic";
const Landing = dynamic(() => import("./Landing"), { ssr: false });
export default function LandingLoader() { return <Landing />; }
```

Trade-off: slightly larger client bundle, slight delay before first paint. Acceptable for marketing pages. Not suitable for SEO-critical content pages — but landings with gated auth nav typically trade SSR for reliability.

### 9.5.2 Scroll-Reveal Primitive — Prefer `useOnScreen` over IntersectionObserver

For scroll-triggered reveal animations, prefer a scroll-listener-based hook over IntersectionObserver.

- IntersectionObserver silently misfires on some Android Chromium forks (Chrome 146+ Android, Brave, Samsung Internet). Symptoms: reveal elements stay at `opacity:0` forever on the user's device, and the worker/QA cannot reproduce in Playwright.
- The proven alternative is a manual `useOnScreen` hook. Canonical implementation from orca-design-landing:

```ts
"use client";
import { useEffect, useState, type RefObject } from "react";
export function useOnScreen<T extends HTMLElement>(ref: RefObject<T | null>, threshold = 0.85): boolean {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (visible) return;
    const check = () => {
      const el = ref.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      const trigger = window.innerHeight * threshold;
      if (rect.top < trigger && rect.top + rect.height > 0) setVisible(true);
    };
    check(); // immediate check on mount
    window.addEventListener("scroll", check, { passive: true });
    window.addEventListener("resize", check, { passive: true });
    return () => {
      window.removeEventListener("scroll", check);
      window.removeEventListener("resize", check);
    };
  }, [ref, threshold, visible]);
  return visible;
}
```

Why this wins: scroll events are dispatched universally. Immediate synchronous rect check on mount catches above-fold elements without needing any observer. No browser feature detection required.

### 9.5.3 DO NOT Use Lenis / Virtual-Scroll Libraries

**Do not use Lenis (or other virtual-scroll / smooth-scroll libraries) on landing pages.** Lenis and similar libraries intercept touch events and break scroll-event propagation to IntersectionObserver + native scroll listeners on mobile. They're visually nice on desktop but cause reveal-animation failures + non-responsive touch interactions on mobile. Skip entirely. Native browser scroll + CSS `scroll-snap` / `scroll-margin` are sufficient for modern landing pages.

> This supersedes §7.3 for landing-page contexts. The §7.3 Lenis guidance still applies to bespoke scrollytelling experiences on desktop-only vibes (e.g., long-form editorial, cinematic reels), but for any page that must reliably animate on mobile — especially anything Android Chromium touches — skip Lenis.

---

## 10. REDESIGN AUDIT CHECKLIST

When mode = **Redesign**, run this checklist against the existing code before writing anything. Check every item, note what fails, then fix systematically.

### Fix Priority Order (maximum impact, minimum risk)
When fixing issues found in the audit, follow this order:
1. **Font swap** — biggest instant improvement, lowest risk
2. **Color palette cleanup** — remove clashing or oversaturated colors
3. **Hover and active states** — makes the interface feel alive
4. **Layout and spacing** — proper grid, max-width, consistent padding
5. **Replace generic components** — swap cliché patterns for modern alternatives
6. **Add loading, empty, and error states** — makes it feel finished
7. **Polish typography scale and spacing** — the premium final touch

### Typography (12 items)
- [ ] No banned fonts (see §8)
- [ ] Display font has negative letter-spacing (tracking-tighter or tracking-tight)
- [ ] Body text max-width ≤ 65ch
- [ ] Font smoothing antialiased is set
- [ ] Heading hierarchy is visually clear (size + weight + spacing)
- [ ] Line heights appropriate: display 1.0–1.15, body 1.5–1.7
- [ ] Font sizes use a consistent scale (not arbitrary px values)
- [ ] Numbers in data use tabular-nums
- [ ] Text-wrap: balance on headlines (where supported)
- [ ] No font loaded without display=swap
- [ ] Body font size ≥ 16px
- [ ] Sufficient contrast ratio (WCAG AA minimum: 4.5:1 body, 3:1 large text)

### Color (10 items)
- [ ] No banned color patterns (see §8)
- [ ] Max 1 accent color
- [ ] Saturation < 80% on large surfaces
- [ ] Background is not pure white (#fff) — use a tinted white (e.g., zinc-50, slate-50, stone-50)
- [ ] Dark mode backgrounds are not pure black (unless Dark Cinematic / Opulent Noir / Terminal)
- [ ] Colors defined as CSS variables or Tailwind config, not scattered hex values
- [ ] Accent color has sufficient contrast against its background
- [ ] Hover/active states have visible color shift
- [ ] Disabled states are clearly muted
- [ ] Color alone is not the only indicator of state (accessibility)

### Layout (12 items)
- [ ] No banned layouts (see §8)
- [ ] Uses CSS Grid for page-level layout (not flexbox math)
- [ ] min-h-[100dvh] not h-screen
- [ ] Responsive: tested at 375px, 768px, 1024px, 1440px
- [ ] No horizontal scroll at any viewport
- [ ] Sections have varied rhythm (not all same height/structure)
- [ ] Adequate spacing between sections (80–120px or more)
- [ ] Content doesn't touch viewport edges (min 16px mobile padding)
- [ ] Grid gaps are consistent within sections
- [ ] Visual hierarchy guides the eye (Z or F reading pattern)
- [ ] Above-the-fold content is compelling and complete
- [ ] Footer is designed, not an afterthought

### Interactivity (10 items)
- [ ] All interactive elements have hover states
- [ ] All interactive elements have focus-visible styles
- [ ] Buttons have active/pressed state
- [ ] Links are distinguishable from body text
- [ ] No `transition: all` — specific properties only
- [ ] Animations use transform + opacity only
- [ ] Staggered animations use animation-delay, not setTimeout
- [ ] prefers-reduced-motion is respected
- [ ] Touch targets ≥ 44×44px on mobile
- [ ] Cursor changes appropriately (pointer on clickable, etc.)

### Content (10 items)
- [ ] No Lorem Ipsum
- [ ] No banned filler words (see §8)
- [ ] No generic placeholder names
- [ ] Microcopy is specific to the context
- [ ] CTAs describe the action, not "Click here" or "Learn more"
- [ ] Error states have helpful messages
- [ ] Empty states are designed
- [ ] Loading states exist where needed
- [ ] Numbers/stats use real-looking data
- [ ] Alt text on images

### Components (12 items)
- [ ] No browser-default form elements in polished UI
- [ ] Cards use layered shadows or double-bezel, not flat borders
- [ ] Buttons have consistent sizing system (sm/md/lg)
- [ ] Icons are from an approved set (Phosphor Light, Radix)
- [ ] Icon sizes are consistent within context
- [ ] Modal/dialog has backdrop treatment
- [ ] Toast/notification has entrance animation
- [ ] Tables are styled (not browser default)
- [ ] Scrollbars are styled or hidden where appropriate
- [ ] Dividers/separators use subtle color (not harsh borders)
- [ ] Avatar/image containers have consistent radius
- [ ] Badge/tag components are cohesive with the palette

### Code Quality (10 items)
- [ ] No inline styles (use Tailwind classes or CSS modules)
- [ ] No magic numbers — spacing/sizing from the design system
- [ ] Component structure is composable (not monolithic)
- [ ] Interactive components are client components; static parts are RSC
- [ ] Images have explicit dimensions or aspect-ratio
- [ ] No layout shift on load (CLS)
- [ ] Fonts preloaded or swap strategy set
- [ ] Semantic HTML (nav, main, section, article, aside)
- [ ] Keyboard navigable (tab order, escape to close)
- [ ] No z-index wars (use a z-index scale: 10, 20, 30, 40, 50)

### Strategic Omissions (8 items)
Things to intentionally leave out for a cleaner result:
- [ ] Remove decorative elements that don't serve the hierarchy
- [ ] Remove animations that don't aid comprehension
- [ ] Remove colors that don't have a clear role
- [ ] Remove font weights not actively used
- [ ] Remove sections that repeat the same message
- [ ] Remove icons that are merely decorative noise
- [ ] Remove hover effects on non-interactive elements
- [ ] Remove any element you can't justify in one sentence

---

## 11. PRE-FLIGHT CHECKLIST

Run through these checks before delivering any code. Every item must pass.

### Structure (5)
1. [ ] RSC by default — only leaf interactive components are `"use client"`
2. [ ] Tailwind CSS used — confirmed v3 vs v4 syntax (v4 uses `@import "tailwindcss"`, CSS-first config)
3. [ ] Semantic HTML elements used throughout
4. [ ] Component file structure is clean (one component per file for non-trivial components)
5. [ ] min-h-[100dvh] used, not h-screen

### Visual (7)
6. [ ] No banned fonts, colors, layouts, icons, or content (§8)
7. [ ] Font pairing is intentional and loaded correctly
8. [ ] Color palette has max 1 accent + neutrals
9. [ ] Cards/surfaces use shadows or double-bezel, never flat borders alone
10. [ ] Typography scale is consistent (modular ratio)
11. [ ] Spacing is consistent (8px grid or 4px grid)
12. [ ] Dark/light mode properly implemented (if applicable)

### Motion (4)
13. [ ] Animations only use transform + opacity
14. [ ] No `transition: all`
15. [ ] prefers-reduced-motion respected
16. [ ] Staggered reveals use animation-delay

### Interactive 3D & Motion Default, the disciplined ladder (§5.5, M3D-1..M3D-7)
M3D-1. [ ] Real depth/elevation present, layered tight+ambient shadows, NO flat single-border/glow panels (§4, §5.5 Tier 1)
M3D-2. [ ] Entrance/transition motion is purposeful and interpolation-driven, NOT one canned blur-up curve reused everywhere (§5, §5.5 Tier 1)
M3D-3. [ ] Every interactive element has hover + press + focus-visible + state-change feedback (§4, §5.5 Tier 1)
M3D-4. [ ] At least one signature interactive 3D/spatial moment (Spline or R3F), UNLESS the build is a restraint archetype, mobile-primary, LCP/SEO-critical, or /oneshot-webapp scope (§5.5 Tier 2 + yield)
M3D-5. [ ] prefers-reduced-motion path implemented as a DIAL and tested (reduce/replace, ~0.01ms not 0, pause control for loops >5s), full-respect per §6/§9 (§5.5 Tier 3)
M3D-6. [ ] 60fps verified (transform/opacity only); heavy scenes lazy + `ssr:false`; WebGL budget held (draw calls <100, shared materials, Draco, VRAM); LCP not blocked (§5.5 Tier 3, §6)
M3D-7. [ ] Tested on a real mid-tier mobile device (WebGL throttle/battery), not just devtools (§5.5 Tier 3, §9)

> If any M3D item fails, the frontend is NOT done. Fix before reporting complete.

### Scrollytelling (if §7 patterns used — 5)
S1. [ ] Lenis installed + wrapped at root, OR documented reason why not
S2. [ ] No more than 3 concurrent `useScroll` instances on the page
S3. [ ] All scrubbed properties are transform/opacity/filter (never layout properties)
S4. [ ] Every pinned section has a visible progress indicator
S5. [ ] Mobile fallback path built + tested on a real device (see §7.6, §9)

### Performance (3)
17. [ ] backdrop-blur only on fixed/sticky elements
18. [ ] Images have width/height or aspect-ratio
19. [ ] No layout shift on load

### Accessibility (3)
20. [ ] Focus-visible styles on all interactive elements
21. [ ] Touch targets ≥ 44px
22. [ ] Color contrast meets WCAG AA

### Device Testing (3)
23. [ ] Playwright screenshots captured at 3 viewports: 1440×900 (desktop), 768×1024 (tablet), 390×844 (mobile)
24. [ ] Debug overlay enabled in dev mode (MobileErrorOverlay capturing window.onerror + unhandledrejection + viewport state)
25. [ ] Known browser quirks reviewed: Brave fingerprint protection (IO/canvas), Android Chromium vendor builds (stale IO), iOS Safari IO timing (`once: true` + negative `rootMargin`)

### Color Contrast (3)
26. [ ] Every text/bg combo verified against WCAG AA (4.5:1 normal text, 3:1 large text)
27. [ ] Hover states INCLUDED in contrast verification (not just resting state)
28. [ ] Verification tool used: manual calculation or `npx pa11y <url>`

### Craft Details (Interface Craft pass, C1-C7)
C1. [ ] Neutrals share ONE temperature + one Tailwind family; tints are the primary neutral at low opacity, not new declared colors (§3.5)
C2. [ ] Perceived-brightness-sensitive color sets (category tokens, accent rows) built in OKLCH; gradients use `in oklch`; dark scrims use eased/smoothstep opacity stops with no visible horizon line (§3.5)
C3. [ ] Borders are transparent/inset (crisp over shadows, never solid muddy); every shadow is a layered tight+ambient pair, not one blur (§4)
C4. [ ] Type: ≤5 sizes on a modular scale, measure 45–75ch, tabular-nums on changing numbers, balance/pretty wrapping, proper punctuation in rendered copy, OpenType opted in where relevant (§3, §3.5)
C5. [ ] Blended foregrounds wrapped in `isolation: isolate`; overlapping fades grouped-then-faded; one border edge per grid cell (§4)
C6. [ ] Reactive motion uses mapRange with the FRACTION clamped; looping/ambient motion is wave-driven (no keyframe seams); all component states + cross-cutting toggles were mapped, not imagined (§4, §5)
C7. [ ] Named 3–5 situational facets (§0.8); the highest-leverage element was pushed past the industry-bar default, not left at it; server round-trips use optimistic UI or a masked wait (§0.8, §6)

---

## 12. DEPLOYMENT READINESS CHECKLIST

Separate from code quality (§11). These are production-readiness items that must be verified before any deployment.

### Assets
- [ ] OG image (1200×630) generated and linked in metadata
- [ ] Favicon (multiple sizes) + apple-touch-icon configured
- [ ] 404 page designed and implemented (not browser default)

### Error Boundaries
- [ ] `loading.tsx` exists for async routes
- [ ] `error.tsx` boundary catches runtime errors gracefully
- [ ] Error states show helpful messages, not stack traces

### Rendering & Caching
- [ ] SSR vs CSR decision documented — if `ssr: false` or `"use client"` on page-level, explicitly flag SEO impact
- [ ] Cache headers reviewed: `s-maxage`, `stale-while-revalidate` set appropriately for content type
- [ ] Static vs dynamic rendering verified per route

### SEO & Accessibility
- [ ] `<title>` and `<meta name="description">` set on every page
- [ ] WCAG AA contrast verified for every text/bg combo including hover states
- [ ] Heading hierarchy is sequential (h1 → h2 → h3, no skipping)

### Final Smoke Test
- [ ] Production build (`next build`) completes without warnings
- [ ] All links resolve (no 404s on internal navigation)
- [ ] Forms submit correctly with validation
- [ ] Mobile viewport renders correctly at 390px width

---

## 13. ARCHITECTURE RULES

### Dependency Verification [MANDATORY]
Before importing ANY 3rd-party library, check `package.json` (or equivalent). If missing, output the install command first. Never assume a library exists.

### React / Next.js
- **RSC by default**: pages and layouts are Server Components. Only add `"use client"` to isolated leaf components that need interactivity (dropdowns, modals, animated sections).
- Keep client component boundaries as small as possible — wrap only the interactive part, not the whole section.
- Colocate client components near where they're used.

### Styling
- **Tailwind CSS always**. Before writing any Tailwind, check whether the project uses v3 or v4:
  - v3: `tailwind.config.js`, `@tailwind base/components/utilities` directives
  - v4: `@import "tailwindcss"`, CSS-first config in the CSS file, `@theme` block
- Use Tailwind's design tokens (spacing scale, color palette) — don't invent custom values unless the scale doesn't cover it.
- CSS Grid for page layout, flexbox for component internals.

### Icons
- **Phosphor Icons** (Light weight) — preferred
- **Radix Icons** — acceptable alternative
- Import as React components, not icon fonts
- Consistent sizing: 16px inline with text, 20px in buttons, 24px standalone

### Images
- Next.js `<Image>` component when in Next.js projects
- Always specify dimensions
- Use `priority` on above-the-fold hero images
- Lazy load everything below the fold

---

## EXECUTION FLOW

0. **Frame**: Internalize §0.8, name the 3 to 5 facets this build is graded on, start from the proven default, and decide the ONE highest-leverage element you will push past it
1. **Setup**: Run the interactive setup (§1): mode, vibe, dials
2. **Design**: Lock in typography (§3), color (§3.5), layout archetype based on vibe + dials
3. **If Redesign**: Run the full audit checklist (§10) first, then fix
4. **Build**: Write production code following §3–6 rules (type §3, color §3.5, surfaces/compositing §4, motion §5, the enforced interactive-3D/motion default §5.5, perceived-perf §6), layer in scrollytelling from §7 where the vibe calls for it, verify mobile resilience (§9)
5. **Verify**: Run pre-flight checklist (§11, incl. the C1-C7 craft pass) + deployment readiness (§12). Every item must pass
6. **Deliver**: Present the code with a brief note on the design decisions made

Remember: Claude is capable of extraordinary creative work. Don't hold back — show what can truly be created when thinking outside the box and committing fully to a distinctive vision. Every interface should feel like it was designed by a human with strong opinions, not generated by a machine hedging its bets.
