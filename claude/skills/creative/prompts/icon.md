# Icons / UI Elements — Prompt Template

## Recommended Models

1. **Recraft V4 Vector** (primary) — native SVG, consistent sets via Brand Kit, stroke uniformity
2. **Gemini** (fallback) — decent concepts but raster-only

**Critical:** Icons need to be vectors (SVG) for production use. If Recraft is unavailable, warn the user that raster icons will need manual vectorization.

## Dimensions

Icons are typically generated at a reference size and scaled:
- Generation size: 1024x1024 (gives model room for detail)
- Target sizes: 16px, 20px, 24px, 32px, 48px (must work at all)
- Always generate at 1:1 aspect ratio

## Prompt Pattern

```
[Icon subject — what does this icon represent?].
[Style: outline / filled / duotone / flat / line-art / glyph].
[Stroke weight: thin (1px) / regular (1.5px) / bold (2px)].
[Color: monochrome / single color + background / duotone].
[Shape constraint: fits within circle / square / rounded square].
Simple, clear, recognizable at 16x16 pixels.
Consistent stroke weight throughout. Centered within frame.
No text, no shadows, no gradients, no 3D effects.
Avoid: excessive detail, organic/realistic rendering, photographic elements.
```

## Set Consistency

When generating icon SETS (multiple related icons), consistency is critical:

1. **Same stroke weight** across all icons
2. **Same corner radius** on all geometric shapes
3. **Same visual weight** — icons should look balanced next to each other
4. **Same style** — all outline OR all filled, never mixed
5. **Same color treatment** — identical palette for all

### Recraft Brand Kit for Sets

If generating a set, use Recraft's Brand Kit / style features:
- Set the color palette once, apply to all generations
- Use `create_style` to establish the icon style, then reference it
- Generate all icons in the same session for maximum consistency

### Batch Prompt for Sets

Instead of generating one at a time, prompt for the set concept:
```
A set of 6 matching icons for a dashboard: [list subjects].
All icons: thin outline style, 1.5px consistent stroke weight,
rounded corners (2px radius), single color (#1A1A2E) on transparent background.
Each icon centered in a 24x24 grid with 2px padding.
Uniform visual weight across all icons. Simple, geometric, minimal.
```

## Recraft-Specific Configuration

### Via MCP
```
Tool: generate_image
Parameters:
  - model: "recraftv4_vector"
  - style: "icon"
  - colors: ["#1A1A2E"]  (single color for monochrome)
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

## Gemini Fallback Pattern

When Recraft isn't available:
```
set_aspect_ratio → "1:1"
set_model → "flash" (icons don't need Pro quality)
gemini_generate_image → "[icon description]. Simple flat icon design,
    monochrome, centered on white background, clean vector style,
    uniform stroke weight, minimal detail, suitable for UI."
```

Warn user: "This is a raster PNG icon. For production, it should be vectorized manually in Figma/Illustrator or re-generated with Recraft for native SVG."

## Example Prompts

### Single Icon
```
A simple settings gear icon. Thin outline style, 1.5px stroke weight.
Six teeth evenly spaced around a circle. Small circle in center.
Single color: dark charcoal (#1A1A2E) on transparent background.
Clean geometric construction, no fill, consistent line weight.
Must be recognizable at 16x16 pixels. Centered in frame.
```

### Icon Set
```
A matching set of 4 navigation icons for a web app:
1. Home — simple house outline with door
2. Search — magnifying glass, handle at 45 degrees
3. User — simple person silhouette bust in circle
4. Settings — gear/cog with 6 teeth

All icons: thin outline style, 1.5px consistent stroke weight,
rounded end caps, single color (#2C2C2C) on transparent background.
Same visual weight and complexity across all four. Geometric, minimal.
Each icon should work at 20x20 pixel display size.
```

### App Icon (filled style)
```
App icon for a messaging application. Rounded square shape with 20% corner radius.
Solid teal (#2DDCC7) background fill. White speech bubble symbol centered,
slightly overlapping a smaller white speech bubble. Simple, flat, two-tone only.
No gradients, no shadows, no 3D. Clean silhouette style.
Must be distinctive at 48x48 pixels.
```

## Quality Checklist

- [ ] Recognizable at 16x16 pixels (the true test of icon quality)
- [ ] Consistent stroke weight throughout
- [ ] Centered within the frame
- [ ] No unnecessary detail (less is more for icons)
- [ ] Works in single color (monochrome test)
- [ ] If part of a set — visually consistent with other icons
- [ ] SVG output (if Recraft) — clean paths, no embedded rasters
- [ ] No text in the icon (icons should be language-independent)
- [ ] Clear silhouette — recognizable even as a solid fill
