# Social Media Graphics — Prompt Template

## Design Philosophy

Social media graphics must look **intentionally designed**, not AI-generated. The bar is Dribbble/Behance featured work. If it looks like Canva or "AI made this" — it's a failure.

### Core Principles

1. **Asymmetry over symmetry** — centered layouts are lazy. Use rule-of-thirds, golden ratio, or intentional off-center placement. Tension creates interest.
2. **Typography IS the design** — for announcement posts, type hierarchy does 80% of the work. Mix weights (thin + bold), sizes (72pt + 14pt), cases (ALL CAPS + sentence case), and positioning (flush-left + right-aligned detail).
3. **Negative space is intentional** — it's not "emptiness," it's a design element. It directs the eye and creates breathing room. But it must be PLANNED, not just "big empty dark background."
4. **Color is strategic** — one accent color used sparingly has more impact than gradients everywhere. A single teal line or bar says more than a teal glow. Reserve color for what matters.
5. **Grid-based layout** — real designers use grids. Elements should align to invisible lines. Text blocks, images, and decorative elements should share alignment points.
6. **Texture and depth without glow** — use shadows, overlapping elements, subtle noise/grain, perspective transforms, geometric shapes. Never use glowing text or neon aura effects.
7. **Restraint** — the hallmark of good design is knowing what to leave out. One strong idea, executed well.

### AI Slop Indicators (REJECT if any appear)

- Glowing text with halo/aura effect
- Perfect center alignment of everything
- Generic dark gradient background with no texture
- Bold italic sans-serif as the only typographic choice
- Floating elements with no spatial relationship
- Rainbow or multi-color gradients
- Overly saturated neon colors
- Stock-photo-style compositions
- "Tech company" generic aesthetic (abstract nodes, circuits, glowing orbs)
- Every element the same visual weight (no hierarchy)

## Dimensions

| Platform | Size | Aspect Ratio |
|----------|------|--------------|
| Instagram Post | 1080x1080 | 1:1 |
| Instagram Story | 1080x1920 | 9:16 |
| Twitter/X Post | 1600x900 | 16:9 |
| LinkedIn Post | 1200x627 | ~1.91:1 |
| Facebook Post | 1200x630 | ~1.91:1 |
| OG Image | 1200x630 | ~1.91:1 |
| YouTube Thumbnail | 1280x720 | 16:9 |

## Prompt Architecture

DO NOT write prompts that describe "a social media post." Write prompts that describe **a designed composition** — as if art-directing a designer.

### Structure

```
[COMPOSITION: describe the spatial layout — what goes where, aligned to what, proportions]
[TYPOGRAPHY: exact text in quotes, specify weight/size relationships, placement on the grid]
[COLOR APPLICATION: where color appears and where it doesn't — be surgical]
[TEXTURE/DEPTH: what creates visual interest beyond flat color blocks]
[STYLE REFERENCE: name specific design movements, studios, or aesthetic traditions]
[ANTI-PATTERNS: explicitly exclude AI slop patterns]
```

### Gemini-Specific Approach

Gemini responds well to:
- Describing the image as if you're looking at a finished design ("A graphic design composition featuring...")
- Concrete spatial relationships ("text aligned to the left margin, 20% from the top")
- Named design styles ("Swiss/International typographic style", "editorial magazine layout")
- Specific font style descriptions ("condensed grotesque all-caps", "light-weight geometric sans")

Gemini produces slop when:
- Told to make "a social media post" (triggers generic templates)
- Given vague style words ("modern, clean, professional")
- Asked for "glow effects" or "ambient light"
- Prompt is just a list of elements with no spatial relationship described

### GPT Image 1 Approach

GPT Image excels at:
- Structured, detailed layout descriptions
- Text rendering accuracy (best of all models for text)
- Following precise spatial instructions
- Editorial and typographic compositions

Use quality "medium" for iterations, "high" for final output.

### Recraft V4 Approach

Best for:
- Flat graphic design style (posters, social cards)
- Strong geometric compositions
- Brand-consistent output (accepts color arrays)
- Vector output for further editing

Use `digital_illustration` style for social graphics, NOT `realistic_image`.

## Example Prompts (GOOD)

### Announcement Post — Editorial Style
```
A typographic composition on a nearly black (#0C0C0E) background with subtle paper-like noise texture. In the upper-left quadrant, the word "DARK" in an ultra-bold condensed sans-serif, white, occupying about 40% of the frame width. Directly below, "MODE" in the same typeface but thinner weight, creating contrast. A single horizontal teal (#2DDCC7) line, 2px thick, runs from the left edge to about 60% across, separating the headline from a small sans-serif tagline below: "Now available" in light gray (#888888), lowercase, left-aligned. In the bottom-right corner, a small product logo mark. The composition is asymmetric — heavy top-left, light bottom-right. No gradients, no glow, no centered text. Swiss typographic poster aesthetic.
```

### Product Update — Split Composition
```
A square graphic split into two zones. Left 40%: solid deep charcoal (#141416) with white text — large "v2.0" in a geometric sans-serif at the top, and below it three short feature bullet points in small light gray text, left-aligned. Right 60%: a product UI screenshot (dark-themed dashboard with teal accents) shown at a slight 5-degree perspective tilt, casting a subtle shadow on the dark background. A thin teal (#2DDCC7) vertical divider line separates the two zones. Bottom-left: small brand wordmark. The layout follows a clear grid with consistent margins. Editorial product announcement aesthetic, not a generic social template.
```

## Example Prompts (BAD — never do this)

```
# BAD: Generic AI slop prompt
A sleek, professional Instagram post with dark background and glowing teal accents.
Bold text says "DARK MODE IS HERE" centered in the middle. Modern, clean design.

# BAD: Vague style words
Beautiful, stunning social media graphic for a tech product launch.
Professional and modern with amazing visual effects.

# BAD: No spatial relationships
Dark background, white text, teal accent, product logo, dashboard image.
```

## Quality Checklist

- [ ] Text spelled correctly and fully legible
- [ ] Layout is NOT centered-everything (has asymmetry or intentional composition)
- [ ] Typography has hierarchy (different sizes, weights, or styles)
- [ ] Color used strategically (accent, not everywhere)
- [ ] No glow effects, no neon auras, no generic gradients
- [ ] Negative space is intentional, not just "big empty area"
- [ ] Would survive the "Dribbble test" — could you post this without embarrassment?
- [ ] Does NOT look like "AI generated this" at first glance
- [ ] Elements align to a grid (consistent margins, alignment points)
- [ ] Has character/distinctiveness — not interchangeable with any other brand
