# Banner / Text-Heavy Graphics — Prompt Template

## Recommended Models

1. **GPT Image 1.5** (primary) — best text rendering accuracy, understands layout instructions
2. **Gemini NB2/Pro** (strong alternative) — 87-96% text accuracy, conversational editing
3. **Ideogram V3** (if integrated) — 90-95% text accuracy, purpose-built for typography

**Avoid for text-heavy work:**
- FLUX (text treated as visual texture, multi-word phrases fail)
- Midjourney (71% text accuracy — unusable for banners)

## Common Dimensions

| Use Case | Size | Aspect |
|----------|------|--------|
| OG / Social Share | 1200x630 | ~1.91:1 |
| Email Header | 600x200 | 3:1 |
| Blog Banner | 1200x400 | 3:1 |
| Event Banner | 1920x600 | ~3.2:1 |
| Web Hero | 1920x800 | ~2.4:1 |
| YouTube Thumbnail | 1280x720 | 16:9 |
| Ad Banner (leaderboard) | 728x90 | ~8:1 |
| Ad Banner (rectangle) | 300x250 | ~1.2:1 |

## Prompt Pattern

```
[Banner type and purpose — what is this for?].
Text content: "[HEADLINE TEXT]" in [position: centered/left/upper-third].
[Secondary text if any: "[SUBHEADLINE]" smaller, below headline].
[Background: solid color / gradient / image description].
[Typography style: bold sans-serif / elegant serif / handwritten / technical].
[Color palette: background hex, text hex, accent hex].
[Layout: text-left-image-right / centered-text-over-background / split-layout].
Clean, high-contrast, readable at a glance. Professional marketing quality.
Avoid: text over busy backgrounds without overlay, tiny text, more than 2 text sizes.
```

## Text Rendering Rules

These rules are CRITICAL — text errors in banners are immediately visible:

1. **Put all text in double quotes** in the prompt: `"SALE ENDS FRIDAY"`
2. **Spell out the exact text** — don't paraphrase or abbreviate
3. **Limit to 1-2 text elements** — headline + optional subheadline
4. **Keep headlines under 5 words** for reliable rendering
5. **Specify text color explicitly** — "white text on dark background" or hex
6. **Request high contrast** — text must be readable at thumbnail size
7. **Verify every letter** after generation — regenerate if ANY character is wrong
8. **Don't try to fix text via editing** — regenerate from scratch if text is wrong

## GPT Image 1.5 Pattern

```bash
curl -s -X POST "https://api.openai.com/v1/images/generations" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-image-1",
    "prompt": "A professional banner graphic. Background is solid deep navy (#1A1A2E). Centered, the text \"NOW AVAILABLE\" appears in large, bold, white sans-serif lettering. Below it, smaller text reads \"Starting at $9/month\" in light gray (#A0A0A0). Clean, minimal, corporate. No images, no illustrations — pure typography on solid background. Aspect ratio approximately 1.91:1.",
    "size": "1536x1024",
    "quality": "medium",
    "n": 1
  }'
```

## Gemini Pattern

```
1. set_aspect_ratio → "16:9" (or closest match)
2. set_model → "pro" (better text rendering)
3. gemini_generate_image → prompt with quoted text
4. If text is wrong → gemini_edit_image → "Fix the text to read exactly '[CORRECT TEXT]'"
```

Gemini editing advantage: you can iteratively fix text errors through conversation without regenerating from scratch.

## Example Prompts

### OG Image / Social Share
```
Professional OG image for a blog post. Soft warm gradient background from ivory
(#FAF7F2) to pale peach (#FFE8D6). The headline text "Building Design Systems
That Scale" appears in large, bold, dark charcoal (#1A1A1A) sans-serif type,
left-aligned in the upper two-thirds. Below it, smaller text "A practical guide"
in medium gray (#666666). Right side has a subtle geometric pattern of overlapping
circles in muted gold (#D4A574) at 20% opacity. Clean, editorial, professional.
1200x630 pixels.
```

### Event Banner
```
Wide event banner. Deep black (#0A0A0A) background. Centered text "LAUNCH DAY"
in enormous, ultra-bold white sans-serif type taking up 60% of the banner width.
Below it, "April 15, 2026 — 7PM EST" in smaller, light-weight type, teal (#2DDCC7).
A subtle horizontal line separates headline from details. Cinematic, high-impact,
minimal. No images. 1920x600.
```

### YouTube Thumbnail
```
YouTube thumbnail with split composition. Left half: solid electric blue (#2563EB)
background. Right half: solid white. The text "5 MISTAKES" appears in bold white
type on the blue side. Below it, "developers make" in smaller blue type on the
white side. Text spans both halves. Bold, clean, high-contrast, clickable.
No faces, no photos. 1280x720.
```

## Quality Checklist

- [ ] ALL text is spelled correctly — check every single character
- [ ] Text is readable at 50% zoom (simulates feed/thumbnail view)
- [ ] Sufficient contrast ratio between text and background
- [ ] No text overlapping other text
- [ ] No text cut off at edges
- [ ] Text hierarchy is clear (headline vs subheadline)
- [ ] Colors match brand kit (if loaded)
- [ ] Composition works at the intended aspect ratio
- [ ] Would look professional in a marketing context
