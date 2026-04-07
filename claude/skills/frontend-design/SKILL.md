---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt
---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

---

## 1. INTERACTIVE SETUP

Before writing any code, run this setup sequence with the user. Present it conversationally — don't dump the whole menu.

### Step 1: Mode Selection

Ask the user which mode they want:

| Mode | When to use |
|---|---|
| **New Build** | Starting from scratch — full creative latitude |
| **Redesign** | Existing page/component needs a visual overhaul (run the Redesign Audit in §8) |
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

### Custom Vibe
When the user describes something that doesn't match an archetype, extract:
1. Color temperature (warm / cool / neutral)
2. Density feeling (airy / balanced / packed)
3. Personality (serious / playful / luxe / raw / futuristic / organic)
4. Reference points (any sites, brands, or aesthetics they mention)

Then build a coherent system from those constraints.

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

---

## 7. ANTI-SLOP — Banned Patterns

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

## 8. REDESIGN AUDIT CHECKLIST

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
- [ ] No banned fonts (see §7)
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
- [ ] No banned color patterns (see §7)
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
- [ ] No banned layouts (see §7)
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
- [ ] No banned filler words (see §7)
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

## 9. PRE-FLIGHT CHECKLIST

Run through these 22 checks before delivering any code. Every item must pass.

### Structure (5)
1. [ ] RSC by default — only leaf interactive components are `"use client"`
2. [ ] Tailwind CSS used — confirmed v3 vs v4 syntax (v4 uses `@import "tailwindcss"`, CSS-first config)
3. [ ] Semantic HTML elements used throughout
4. [ ] Component file structure is clean (one component per file for non-trivial components)
5. [ ] min-h-[100dvh] used, not h-screen

### Visual (7)
6. [ ] No banned fonts, colors, layouts, icons, or content (§7)
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

### Performance (3)
17. [ ] backdrop-blur only on fixed/sticky elements
18. [ ] Images have width/height or aspect-ratio
19. [ ] No layout shift on load

### Accessibility (3)
20. [ ] Focus-visible styles on all interactive elements
21. [ ] Touch targets ≥ 44px
22. [ ] Color contrast meets WCAG AA

---

## 10. ARCHITECTURE RULES

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
3. **If Redesign**: Run the full audit checklist (§8) first, then fix
4. **Build**: Write production code following §3–6 rules
5. **Verify**: Run pre-flight checklist (§9) — every item must pass
6. **Deliver**: Present the code with a brief note on the design decisions made

Remember: Claude is capable of extraordinary creative work. Don't hold back — show what can truly be created when thinking outside the box and committing fully to a distinctive vision. Every interface should feel like it was designed by a human with strong opinions, not generated by a machine hedging its bets.
