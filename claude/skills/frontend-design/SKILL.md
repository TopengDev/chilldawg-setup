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

## 2. VIBE ARCHETYPES

Each archetype is a starting point, not a cage. Remix, combine, or diverge — but always have a clear aesthetic direction.

### Ethereal Glass
**Best for**: SaaS, AI products, developer tools, tech landing pages
- **Background**: OLED black (#000000 allowed here only) or deep navy, mesh gradients as ambient light
- **Surfaces**: backdrop-blur cards with 1px border at white/5–10%, layered at multiple depths
- **Typography**: Geist, Satoshi, or Instrument Sans for body; Geist Mono or JetBrains Mono for code
- **Color**: Single vivid accent (electric blue, mint, or violet), everything else monochrome
- **Signature**: Frosted glass depth, glowing edges, ambient gradient orbs behind content

### Editorial Luxury
**Best for**: Lifestyle brands, agencies, portfolios, editorial sites
- **Background**: Warm cream (#FAF7F2), parchment, or muted stone; CSS noise overlay (SVG filter) at 2–4% opacity
- **Surfaces**: Minimal borders, generous padding, content-as-decoration philosophy
- **Typography**: Serif display headers (Playfair Display, EB Garamond, Cormorant); clean sans body (DM Sans, General Sans)
- **Color**: Muted earth palette — ochre, burgundy, forest — never neon; max 1 accent
- **Signature**: Magazine-style layouts, oversized type, dramatic whitespace, image-driven storytelling

### Soft Structuralism
**Best for**: Consumer apps, health/wellness, fintech, modern SaaS
- **Background**: Silver-grey or warm white, subtle gradient washes
- **Surfaces**: Large radius cards (16–24px), diffused multi-layer shadows, no hard borders
- **Typography**: Massive grotesk display type (Instrument Sans, Plus Jakarta Sans, Switzer); body at comfortable 16–18px
- **Color**: Desaturated palette with one punchy accent; saturation < 70% on backgrounds
- **Signature**: Soft depth, rounded everything, approachable density, feels touchable

### Neo-Brutalist
**Best for**: Indie brands, punk/raw creative studios, anti-design agencies
- **Background**: Concrete grey (#D4D0CC) or raw white, visible grid lines as design element
- **Surfaces**: Sharp borders (0px radius), exposed structure, no shadows, raw edges
- **Typography**: Space Mono or JetBrains Mono primary; Bricolage Grotesque for display
- **Color**: Strictly black + white + ONE accent (usually red #FF3333 or electric blue). No gradients.
- **Signature**: Intentionally "broken" layouts, overlapping elements, raw hover states, cursor: crosshair

### Japanese Minimal
**Best for**: High-end retail, ceramics, tea, luxury goods, artisanal products
- **Background**: Warm off-white (#FAF8F5) or rice paper texture
- **Surfaces**: Hairline 0.5px borders, extreme padding (8rem+), negative space as primary design tool
- **Typography**: Small body text (14px), generous letter-spacing. Cormorant Garamond or Noto Serif JP for display; Inter Tight at 300 weight for body
- **Color**: Charcoal #2B2B2B + one muted accent (indigo #3D4F7C or moss #6B7B5E). Max 3 colors total.
- **Signature**: Ultra-restrained — if it feels like anything was "designed," remove more

### Magazine Editorial
**Best for**: Media, publishing, fashion, lifestyle magazines, content-heavy sites
- **Background**: Pure white or ivory, full-bleed images as backgrounds
- **Surfaces**: No cards — content flows edge-to-edge. Pull quotes as design elements.
- **Typography**: Bold serif display (Playfair Display, Libre Bodoni) at extreme sizes (8rem+). DM Sans body. Mixed weights in same line (thin + black).
- **Color**: Black + white + one editorial accent (burgundy #7A1B35 or gold #B8860B)
- **Signature**: Dramatic scale contrast (120px headline next to 14px body), overlapping text on image, mixed column widths

### Warm Craft
**Best for**: Artisan brands, F&B, bakeries, handmade goods, wellness
- **Background**: Warm linen (#F4EDE4) or kraft paper texture
- **Surfaces**: Rounded cards (20-28px radius), soft shadows (0 4px 24px rgba(0,0,0,0.06)), hand-drawn border accents
- **Typography**: Fraunces or Vollkorn for display (warm serif); Nunito Sans for body (friendly, rounded)
- **Color**: Earthy palette — terracotta #C4704D, forest #3D5A3E, cream #F4EDE4, espresso #3E2723. Warm, never cool.
- **Signature**: Hand-illustrated flourishes, organic blob shapes (SVG, not CSS), visible texture/grain at 5-8% opacity

### Dark Cinematic
**Best for**: Entertainment, film, music, gaming, nightlife, premium experiences
- **Background**: OLED black #000000 or near-black #0A0A0A, film grain overlay (SVG noise 4-6%)
- **Surfaces**: No visible borders, content emerges from darkness via lighting/gradient reveals
- **Typography**: Instrument Serif or Bodoni Moda for display (high contrast serif); Geist for UI text
- **Color**: Black + cool white #E8E8E8 + one accent (amber #D4A84B or crimson #8B0000). Extremely limited.
- **Signature**: Cinematic letterboxing (horizontal bars), slow reveals (2-3s transitions), dramatic scroll parallax, sparse text with long pauses

### Corporate Confident
**Best for**: Enterprise, B2B, consulting, fintech, legal, institutional
- **Background**: White #FFFFFF or light grey #F5F5F5, clean and unadorned
- **Surfaces**: Subtle borders (1px #E5E5E5), structured cards (8px radius), consistent 24px gap grid
- **Typography**: Inter Tight or Geist for both display and body. No serif. Clean, professional, invisible.
- **Color**: Navy #1B2A4A + charcoal #374151 + white + one muted accent (teal #0D9488 or blue #2563EB). NO warm colors.
- **Signature**: Data-driven — stat counters, metric grids, progress bars, trust badges. Professional, not creative.

### Playful Pop
**Best for**: Kids/education, consumer social, gaming, creative tools, startup MVPs
- **Background**: Saturated pastel (#FFF0F5 rose, #F0F9FF sky, #ECFDF5 mint) or bright solid blocks
- **Surfaces**: Chunky cards (16-24px radius), thick 3px borders, playful shadows (offset 4px 4px, hard edge)
- **Typography**: Sora or Plus Jakarta Sans at heavy weights for display; Karla for body. Oversized (5rem+).
- **Color**: Maximum saturation — coral #FF6B6B, electric purple #7C3AED, sunny #FBBF24, mint #34D399. 3-4 colors freely mixed.
- **Signature**: Bouncy spring physics (stiffness 200, damping 15), emoji as design elements (sparingly), illustrated characters, confetti on success states

### Gen Z Expressive
**Best for**: Gen Z brands, TikTok-adjacent, youth culture, meme brands, social-first companies
- **Background**: Clashing neon blocks — sections alternate bold solids (hot pink #FF1493, electric lime #BFFF00, acid yellow #DFFF11). No single bg color.
- **Surfaces**: Zigzag section breaks (clip-path, not horizontal lines), thick borders everywhere (3-4px, black), sticker/badge UI elements, collage-style overlapping layers, scrapbook textures
- **Typography**: Clash fonts intentionally — mix chunky sans (Clash Display, Space Grotesk 700, Plus Jakarta Sans 800) with pixel fonts (VT323) or monospace. Sizes at 200%. All-caps headers. Type collage with multiple fonts and weights on one layout.
- **Color**: MAXIMUM expression — 5+ colors freely mixed. Hot pink #FF1493, electric lime #BFFF00, acid yellow #DFFF11, electric blue #00BFFF, neon purple #B026FF, black #000000. No restraint. Dopamine palette.
- **Signature**: "TikTok generation energy" — if it feels calm, it's wrong. Micro-interactions on every hover. Cursor trails. Kinetic type animations on scroll. Video loops autoplay. Sticker graphics as UI elements. If grandpa would find it overwhelming, it's right.

### Anti-Design / Experimental
**Best for**: Avant-garde creative studios, experimental portfolios, art galleries, design agencies that want to break rules
- **Background**: Anything unconventional — cursor-driven unwind reveals, generative patterns, blank space that only fills as user interacts. Raw HTML aesthetics used ironically.
- **Surfaces**: No traditional cards, no traditional sections. Content appears through interaction only. Maybe one long strip. Maybe a 3D room. Maybe text you have to "dig for." Elements overlap with no clear z-index hierarchy.
- **Typography**: Deliberately uncomfortable — oversized text bleeding off screen edges, rotated baselines, stacked single characters, text that moves away from cursor, mixed typefaces (serif + grotesque + monospace) in same heading. Broken tracking.
- **Color**: Either extreme monochrome (all black or all white) or deliberately clashing neon-on-black. Grain/noise overlays, scan-line effects, deliberate JPEG artifacting as texture. No "safe" palettes.
- **Signature**: Throw away the rule book. Hidden/camouflaged navigation. Full-screen takeover menus with collision-style text. Custom cursor SVGs that lag or distort. Elements that react to mouse proximity (repel/attract). Permanent "loading" states as design elements. If a traditional web designer would say "you can't do that," do exactly that. But it must still be INTENTIONAL, not broken. Reference: Cargo Collective, Hoverstates, Lusion.

### Custom Vibe
When the user describes something that doesn't match an archetype, extract:
1. Color temperature (warm / cool / neutral)
2. Density feeling (airy / balanced / packed)
3. Personality (serious / playful / luxe / raw / futuristic / organic)
4. Reference points (any sites, brands, or aesthetics they mention)

Then build a coherent system from those constraints.

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
| Ethereal Glass | Dark Cinematic | Moody tech | Both dark-first, cinematic adds drama to glass |
| Soft Structuralism | Warm Craft | Friendly organic tech | Craft textures warm up structured surfaces |
| Soft Structuralism | Corporate Confident | Polished SaaS | Corporate structure + soft approachability |
| Magazine Editorial | Dark Cinematic | Cinematic storytelling | Both dramatic, film grain enhances editorial |
| Neo-Brutalist | Anti-Design | Maximum provocation | Both rule-breaking, combined = avant-garde punk |
| Warm Craft | Playful Pop | Friendly fun | Pop energy with artisanal warmth |
| Ethereal Glass | Corporate Confident | Premium tech | Glass depth + corporate structure = enterprise SaaS |
| Magazine Editorial | Gen Z Expressive | Loud editorial | Gen Z chaos channels through editorial structure |
| Dark Cinematic | Anti-Design | Experimental noir | Both dark, anti-design adds unpredictability |
| Japanese Minimal | Dark Cinematic | Contemplative noir | Minimal restraint + cinematic atmosphere |

#### Incompatible Pairings (NO — these contradict each other)

| Primary | Secondary | Why it fails |
|---|---|---|
| Playful Pop | Corporate Confident | Bouncy energy vs professional restraint — neither wins |
| Japanese Minimal | Gen Z Expressive | Extreme silence vs extreme noise — irreconcilable |
| Anti-Design | Corporate Confident | Rule-breaking vs rule-following — pure contradiction |
| Warm Craft | Neo-Brutalist | Soft organic vs raw industrial — opposite textures |
| Japanese Minimal | Playful Pop | Restraint vs maximalism — mutual destruction |
| Ethereal Glass | Warm Craft | Cold tech vs warm organic — temperature clash |
| Gen Z Expressive | Editorial Luxury | Chaotic youth vs refined authority — tone mismatch |

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

### Font Pairing Strategy
Always pair a distinctive display font with a refined body font. Never use the same font for both unless it's a deliberate monospace aesthetic. Some strong pairings:
- Playfair Display + DM Sans (editorial)
- Instrument Serif + Instrument Sans (modern)
- Fraunces + Outfit (warm tech)
- Space Mono + General Sans (dev/code)
- Cormorant Garamond + Nunito Sans (luxury)
- Bricolage Grotesque + Inter Tight (bold modern — Inter Tight only, never plain Inter)
- Sora + Karla (geometric clean)

Load fonts from Google Fonts or Fontsource. Always specify `display=swap`.

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

This creates depth that feels organic rather than drawn-on.

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

### Layout Transitions
Heavily utilize Framer Motion's `layout` and `layoutId` props for smooth re-ordering, resizing, and shared element transitions. Any time elements move, resize, or swap positions, these props create fluid continuity instead of jarring jumps.

### Perpetual Micro-Interactions (MOTION_INTENSITY > 5)
Embed continuous infinite micro-animations in standard components:
- **Pulse**: breathing glow on status indicators
- **Typewriter**: cycling through placeholder text with blinking cursor
- **Float**: subtle vertical oscillation on decorative elements
- **Shimmer**: light-streak moving across surfaces
- **Carousel**: infinite horizontal scroll of logos, metrics, or cards

**Performance:** Any perpetual motion MUST be memoized (`React.memo`) and isolated in its own microscopic Client Component. Never trigger re-renders in the parent.

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

**Use with**: Ethereal Glass, Dark Cinematic, Anti-Design / Experimental
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

**Use with**: Ethereal Glass, Dark Cinematic, Soft Structuralism
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

## 6. PERFORMANCE

Ship fast interfaces, not just pretty ones.

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

**Best fits:** Dark Cinematic, Ethereal Glass, Warm Craft, Editorial Luxury.
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
| Ethereal Glass | parallax depth, smooth Lenis, subtle scrub | heavy scroll-jack |
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
- **Pure #000000 on white** — BANNED (use zinc-950 or a tinted near-black) unless Ethereal Glass vibe
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
- [ ] Dark mode backgrounds are not pure black (unless Ethereal Glass)
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

1. **Setup**: Run the interactive setup (§1) — mode, vibe, dials
2. **Design**: Lock in typography, color, layout archetype based on vibe + dials
3. **If Redesign**: Run the full audit checklist (§10) first, then fix
4. **Build**: Write production code following §3–6 rules, layer in scrollytelling from §7 where the vibe calls for it, verify mobile resilience (§9)
5. **Verify**: Run pre-flight checklist (§11) + deployment readiness (§12) — every item must pass
6. **Deliver**: Present the code with a brief note on the design decisions made

Remember: Claude is capable of extraordinary creative work. Don't hold back — show what can truly be created when thinking outside the box and committing fully to a distinctive vision. Every interface should feel like it was designed by a human with strong opinions, not generated by a machine hedging its bets.
