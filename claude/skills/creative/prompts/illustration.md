# Illustration — Prompt Template

## Recommended Models

1. **Gemini Pro** (primary) — good all-rounder, compositional planning, editing support
2. **FLUX.2** (photorealistic illustration) — best for editorial and hyper-detailed scenes
3. **Recraft V4** (vector illustration) — if SVG output needed for scalable illustrations

## Common Dimensions

| Use Case | Size | Aspect |
|----------|------|--------|
| Hero image | 1920x1080 | 16:9 |
| Blog header | 1200x630 | ~1.91:1 |
| Spot illustration | 800x800 | 1:1 |
| Full-page | 1920x1920 | 1:1 |
| Wide banner | 2400x800 | 3:1 |

## Prompt Pattern

```
[Subject description — what is depicted, who, what action].
[Art style: specific style reference (not just "illustration")].
[Color palette: limited palette, specific tones].
[Mood and atmosphere: lighting, time of day, emotional tone].
[Composition: perspective, depth, focal point placement].
[Detail level: minimalist / detailed / hyper-detailed].
[Medium reference: looks like watercolor / oil / digital / vector / ink].
Avoid: photorealistic human faces (unless model excels), cluttered compositions,
multiple competing focal points.
```

## Style References That Work Well

Instead of generic "illustration style," use specific references:

**Flat/modern:**
- "Flat vector illustration with limited color palette, geometric shapes"
- "Modern editorial illustration, bold shapes, strong silhouettes"
- "Scandinavian design-inspired illustration, muted earth tones"

**Detailed/artistic:**
- "Detailed digital painting with atmospheric lighting"
- "Gouache-style illustration with visible texture and warm tones"
- "Isometric technical illustration with clean lines and soft shadows"

**Conceptual:**
- "Abstract conceptual illustration using visual metaphor"
- "Surrealist composition with dreamlike spatial relationships"
- "Deconstructed diagram-style illustration with labeled elements"

## Gemini-Specific Tips

- Use Pro model (`set_model` to pro) for illustration quality
- Gemini handles style descriptions well — be specific about artistic medium
- For series consistency, use the chat tool and reference previous outputs
- "In the style of [medium], not [other medium]" helps constrain output

## FLUX-Specific Tips

- FLUX excels when you describe scenes like a photographer or cinematographer
- Include: camera angle, lens type, lighting direction, depth of field
- Works best for: editorial illustration, concept art, atmospheric scenes
- Avoid: abstract/flat styles (FLUX defaults to photorealism)

## Example Prompts

### Hero Image — SaaS Product
```
Abstract conceptual illustration for a SaaS product. Interconnected geometric nodes
floating in space, connected by thin luminous lines, suggesting a network or system.
Deep indigo (#1E1B4B) background fading to soft purple (#4C1D95) at edges. Nodes are
translucent glass spheres with warm amber (#F59E0B) glow. Flat perspective, centered
composition with nodes spreading outward from center. Digital art style, clean edges,
no photorealism. Minimal, sophisticated, tech-forward mood.
```

### Spot Illustration — Blog Post
```
Small spot illustration of a hand holding a seedling growing from soil. Simple,
warm style — limited to 4 colors: forest green (#2D5F2D), warm brown (#8B6F47),
soft cream (#FFF8E7), and charcoal (#2C2C2C). Thick outlines, minimal detail,
slightly rounded/friendly shapes. White/transparent background. Feels handcrafted,
not computer-generated. Square format.
```

## Quality Checklist

- [ ] Style is consistent throughout (no mixing of realistic and cartoon elements)
- [ ] Color palette is cohesive (3-5 colors max for clean illustration)
- [ ] Composition has a clear focal point
- [ ] No anatomical errors (check hands, faces, proportions)
- [ ] Appropriate level of detail for the use case (hero vs spot)
- [ ] Would work at the intended display size
- [ ] Feels intentionally designed, not randomly generated
