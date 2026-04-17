# Logo / Brand Mark — Prompt Template

## Critical Warning

**ALL AI models are mediocre at logos.** AI-generated logos should be treated as rough concepts and starting points, not production-ready assets. Set expectations accordingly.

## Recommended Models

1. **Recraft V4 Vector** (primary) — ONLY model with native SVG output. Use `recraftv4_vector` model.
2. **Gemini** (fallback if Recraft unavailable) — decent concepts but raster-only, warn user.

**DO NOT USE** for logos:
- FLUX (photorealism focus, no vector, text unreliable)
- Midjourney (no API, interpretive not literal)
- Imagen 4 (adds unwanted depth/shadow/texture to flat marks)

## Dimensions

Logos should be generated at the largest reasonable size, then scaled down:
- Primary: 1024x1024 (1:1) — the mark itself
- Horizontal lockup: 2048x512 (4:1) — mark + wordmark side by side
- Favicon: 512x512 (1:1) — simplified icon version

## Prompt Pattern

```
Logo design for [brand name]. [Business type/industry].
[Style: wordmark / lettermark / icon / combination mark / abstract mark].
[Design philosophy: minimal / geometric / organic / technical].
[Color: specify exact colors, or "monochrome" for flexibility].
[Typography direction: if wordmark, specify font character — bold/light/serif/sans].
Clean vector style, flat design, no gradients, no shadows, no 3D effects.
Simple enough to work at 16x16 favicon size. Professional, timeless.
Avoid: clip art, complex illustration, photorealistic elements, busy patterns.
```

## Recraft-Specific Configuration

### Via MCP
```
Tool: generate_image
Parameters:
  - model: "recraftv4_vector" (for SVG output)
  - style: "vector_illustration" or "icon"
  - colors: ["#hex1", "#hex2"] (brand colors)
  - size: "1024x1024"
```

### Via curl
```bash
curl -s -X POST "https://external.api.recraft.ai/v1/images/generations" \
  -H "Authorization: Bearer $RECRAFT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "...",
    "model": "recraftv4_vector",
    "style": "icon",
    "size": "1024x1024",
    "response_format": "url"
  }'
```

### SVG Post-Processing

Recraft SVGs often have excessive anchor points and redundant layers. After generation:
1. Download the SVG
2. Note that it will likely need manual cleanup in Figma/Illustrator for production use
3. Inform the user that this is a concept/starting point, not a final logo

## Gemini Fallback

If Recraft is unavailable, use Gemini with these modifiers:
- "Flat vector logo design, simple geometric shapes"
- "Minimalist brand mark, solid colors only, no gradients"
- "Clean logo that would work as a favicon"
- Warn user: "Generated as raster (PNG). For production use, this should be recreated as vector in Figma/Illustrator, or re-generated with Recraft for native SVG."

## What Makes a Good Logo Prompt

**DO specify:**
- The exact brand name (in quotes if it should appear)
- Industry/context (helps the model make relevant visual associations)
- Style category (wordmark, icon, combination)
- Specific colors (hex values)
- "Flat," "simple," "clean," "geometric," "minimal" — these constraints help

**DO NOT specify:**
- Complex metaphors ("a lion merged with a circuit board holding a globe")
- Multiple elements ("include a mountain, a river, and three stars")
- Specific fonts by name (models can't reliably render named fonts)
- Gradients, shadows, 3D effects (these make logos unusable at small sizes)

## Example Prompts

### Simple Wordmark
```
Minimalist wordmark logo for "AENOXA". Clean, modern sans-serif letterforms.
Letters should be evenly spaced with slight geometric customization. Single color:
teal (#2DDCC7) on white background. No icon, no symbol — pure typography.
Flat vector style, no shadows, no gradients. Professional tech company aesthetic.
```

### Abstract Mark + Name
```
Abstract logo mark for "Beacon" — a simplified geometric lighthouse beam shape,
using two overlapping triangles suggesting a light beam pointing upward. Color:
deep navy (#1A1A2E) for the shape, white background. Below the mark, the word
"BEACON" in clean, light-weight sans-serif uppercase. Minimal, modern, flat design.
No 3D effects, no gradients.
```

### Icon/Favicon Only
```
Simple geometric icon suitable for a favicon. Abstract "A" letterform constructed
from two diagonal lines meeting at a peak, forming a minimal triangle shape.
Single color: teal (#2DDCC7). No text. Must be recognizable at 16x16 pixels.
Flat vector, clean edges, maximum simplicity.
```

## Quality Checklist

- [ ] Works at favicon size (16x16) — still recognizable?
- [ ] Works in single color (monochrome version viable?)
- [ ] No gradients or shadows that break at small sizes
- [ ] Text (if any) is spelled correctly
- [ ] Looks professional, not clip-art-like
- [ ] Simple enough to describe in one sentence
- [ ] Distinct — doesn't look like a generic template
- [ ] SVG output (if Recraft) — paths are clean, no raster elements embedded
- [ ] User informed this is a concept, not a production-ready logo
