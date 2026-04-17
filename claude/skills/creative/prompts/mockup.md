# Photorealistic Mockups — Prompt Template

## Recommended Models

1. **FLUX.2 Pro** (primary) — best photorealism, simulates optical physics, product visualization
2. **GPT Image 1.5** (strong alternative) — 87% photorealistic accuracy, iterative editing
3. **Gemini Pro** (fallback) — decent photorealism, editing support

**Avoid:** Recraft (design-focused, not photo), Ideogram (struggles with photorealism)

## Common Dimensions

| Use Case | Size | Aspect |
|----------|------|--------|
| Product hero | 1920x1080 | 16:9 |
| E-commerce listing | 1000x1000 | 1:1 |
| Lifestyle shot | 1200x800 | 3:2 |
| Device mockup | 1600x1200 | 4:3 |
| Magazine/print ad | 1200x1600 | 3:4 |
| Environment shot | 2400x1200 | 2:1 |

## Prompt Pattern

```
[Product/subject description — what is being photographed].
[Environment/setting — where is this, what surface, what context].
[Lighting setup — natural/studio/golden hour/dramatic/soft/directional].
[Camera perspective — eye-level/overhead/45-degree/close-up/wide].
[Depth of field — shallow (blurred bg) / deep (everything sharp)].
[Material/texture detail — matte/glossy/textured/metallic/glass].
[Color temperature — warm/cool/neutral].
Professional product photography, shot with [camera reference].
Avoid: artificial lighting artifacts, floating objects, impossible shadows.
```

## Photography-Style Prompting

Mockups require **photographic language**, not design language. Think like a photographer:

### Lighting Vocabulary
- **Soft diffused** — overcast look, no hard shadows, even exposure
- **Hard directional** — single strong light source, dramatic shadows
- **Rim lighting** — backlit edges, creates separation from background
- **Golden hour** — warm, low-angle, long shadows
- **Studio three-point** — key light + fill light + back light, standard product
- **Natural window light** — side-lit, soft gradients, realistic interior

### Camera Vocabulary
- **50mm lens** — standard, natural perspective, minimal distortion
- **85mm lens** — slight compression, flattering for products
- **35mm lens** — wider, includes more environment context
- **Macro** — extreme close-up, reveals material texture
- **Tilt-shift** — miniature effect, selective focus plane

### Surface/Material Vocabulary
- **Matte concrete** — gray, industrial, textured
- **Light oak wood** — warm, natural grain, Scandinavian feel
- **White marble** — luxury, cool tones, subtle veining
- **Brushed metal** — industrial, reflective, modern
- **Linen fabric** — soft, textured, organic, lifestyle

## FLUX-Specific Pattern

FLUX uses async polling. The prompt should be photographic:

```bash
# Submit
TASK_ID=$(curl -s -X POST "https://api.bfl.ai/v1/flux-pro-1.1" \
  -H "x-key: $BFL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Professional product photograph of [product]. Shot on a [surface] in [setting]. [Lighting description]. [Camera: lens, angle, depth of field]. [Material details]. [Mood/atmosphere]. Commercial product photography quality.",
    "width": 1024,
    "height": 1024
  }' | jq -r '.id')

# Poll (5s intervals, max 60s)
for i in $(seq 1 12); do
  RESULT=$(curl -s "https://api.bfl.ai/v1/get_result?id=$TASK_ID" -H "x-key: $BFL_API_KEY")
  STATUS=$(echo "$RESULT" | jq -r '.status')
  if [ "$STATUS" = "Ready" ]; then
    URL=$(echo "$RESULT" | jq -r '.result.sample')
    curl -s -o "/tmp/creative-output/mockup.png" "$URL"
    echo "Downloaded to /tmp/creative-output/mockup.png"
    break
  fi
  sleep 5
done
```

## GPT Image 1.5 Pattern

Good for mockups that need text on the product (labels, screens, packaging):

```bash
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-1",
    "prompt": "...",
    "size": "1024x1024",
    "quality": "high",
    "n": 1
  }'
```

Use "quality": "high" for final mockups — photorealism benefits from maximum quality.

## Gemini Fallback Pattern

```
set_aspect_ratio → match the target ratio
set_model → "pro" (always use Pro for photorealism)
gemini_generate_image → photographic prompt
gemini_edit_image → refine lighting, color, composition
```

Gemini's advantage: iterative editing. Generate a base mockup, then refine via conversation.

## Example Prompts

### Product on Surface
```
Professional product photograph of a matte black ceramic coffee mug on a light
oak wood table. Soft natural window light from the left, creating gentle shadows.
Shallow depth of field with background softly blurred. Steam rising from the mug.
A small succulent plant slightly out of focus in the background. Warm color
temperature. Shot at eye-level with a 50mm lens. Commercial lifestyle photography
quality. Clean, minimal composition.
```

### Device Mockup
```
A modern laptop (silver, thin bezel) open at 120 degrees on a clean white desk.
The screen displays a dashboard interface with charts and graphs (no specific text
needed). Soft studio lighting, slight reflection on the desk surface. 45-degree
camera angle from above-right. Deep depth of field, everything sharp. Neutral color
temperature. Minimal desk accessories: a small plant and a coffee cup at edges
of frame. Professional tech product photography.
```

### Packaging Mockup
```
Three boxes of premium tea packaging standing upright on a marble surface. Front
box centered and sharp, two behind at slight angles, slightly blurred. Boxes are
matte white with minimal gold foil text. Dried tea leaves scattered artfully on
the marble surface around the boxes. Soft overhead studio lighting with subtle
directional shadow. 85mm lens, shallow depth of field. Luxury product photography,
clean and elegant.
```

### Environment/Lifestyle
```
A cozy home office scene viewed through a doorway. A desk with a monitor showing
colorful artwork, a warm desk lamp glowing, books stacked neatly. Late afternoon
golden light streaming through a window with sheer curtains. Shallow depth of field
— doorframe sharp in foreground, desk scene slightly soft. Warm color temperature,
inviting mood. 35mm lens, natural perspective. Lifestyle editorial photography.
```

## Quality Checklist

- [ ] Lighting is physically plausible (shadows match light source direction)
- [ ] Materials look realistic (reflections, textures, surface detail)
- [ ] Depth of field is consistent (blur matches distance from focal plane)
- [ ] No floating objects or impossible physics
- [ ] Color temperature is consistent across the scene
- [ ] Composition follows photography rules (rule of thirds, leading lines)
- [ ] Product is the clear focal point
- [ ] No AI artifacts (extra fingers, melted text, impossible geometry)
- [ ] Would pass as a real photograph to a casual viewer
- [ ] Appropriate for commercial/marketing use
