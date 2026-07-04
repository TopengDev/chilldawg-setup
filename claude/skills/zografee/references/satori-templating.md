# zografee Satori templating branch (the "print shop")

Satori is **NOT** the creative path (HR-5). It exists for ONE job: **programmatic templating** - stamping the SAME fixed layout N-times with swapped data/copy. Reference-driven art always goes to Gemini Pro.

## When templating qualifies (ALL must hold)

- The layout is FIXED and known (you are not exploring a design, you are filling a template).
- You need N instances with swapped data: a price-card per product, a personalized poster per user, an exact brand-spec template rendered many times.
- Determinism/exact control matters more than generative flair (every char, every x, every size is specified).

If instead you want one strong on-reference design, that is Gemini Pro (the main flow). One Satori-exact poster once cost ~15 grinding rounds for a result Pro reaches in one shot - do not reach for Satori to make a single artful piece.

## Render (verified)

```bash
node ~/claude/Git/repositories/zografee/engine/render_satori.mjs <layout.json> <out.png>
```

`layout.json` schema (all coords in design px, absolutely positioned; from the renderer source):

```jsonc
{
  "width": 1200, "height": 1697, "scaleWidth": 2400,   // scaleWidth = output width (fitTo); defaults width*2
  "bg": "#000000",
  "bgGradient": "radial-gradient(...)",                 // optional -> CSS backgroundImage
  "fontsDir": "fonts",
  "fonts": [ {"family": "Space Grotesk", "file": "SpaceGrotesk-700.woff", "weight": 700, "style": "normal"} ],
  "elements": [
    {"type": "image", "src": "assets/bg.png", "x": 0, "y": 0, "w": 1200, "h": 1697, "objectFit": "cover", "opacity": 1},
    {"type": "rect",  "x": 80, "y": 300, "w": 1040, "h": 3, "color": "#111", "rotate": 0},   // hairline rule / filled box / rotated diagonal
    {"type": "text",  "x": 0, "y": 540, "w": 1200, "align": "center", "font": "Space Grotesk",
     "weight": 700, "size": 250, "color": "#fff", "lineHeight": 0.88, "letterSpacing": -8,
     "fontStyle": "italic", "shadow": "0 6px 34px rgba(0,0,0,0.55)", "lines": ["AI", "Workshop."]}
  ]
}
```

Renderer capabilities (verified in `render_satori.mjs`): `text` (single `text` or multi-line `lines[]`, auto-stacked via flex-column; `align` left/center/right; `shadow`, `letterSpacing`, `lineHeight`, `fontStyle: "italic"`), `image` (`objectFit`, `opacity`), `rect` (hairline rules, filled boxes, `rotate` for diagonal rules), `bgGradient` (radial/linear). Body paragraphs auto-wrap when you give a wide `w` and a single `text`. `loadSystemFonts` is off, so every face MUST be provided in `fonts`.

## EXACT-SCALE enforcement (the reason Satori exists at all)

Satori is deterministic, so it is the ONLY reliable way to enforce a measured typographic scale: **set each element `size` = measured `pct_of_H` / 100 x canvas H** (from `analyze_ref.typographic_scale()`, see the main SKILL G2). Gemini CANNOT enforce a precise scale - prompted the ratios, it rebalances holistically (a measured 5:2:1 became 11:3:1). So if a job's whole point is a re-measurable exact scale at volume, that is the Satori case. Re-measure the render to confirm the ratios landed.

## Fonts

**Google Fonts -> Satori-compatible WOFF (old-Firefox-UA trick, verified):**
```bash
python3 ~/claude/Git/repositories/zografee/engine/fetch_fonts.py \
  "family=Space+Grotesk:wght@500;700&family=Inter:wght@300;400" jobs/<slug>/fonts
```
The old-FF UA on the CSS2 API returns `.woff` (Satori supports woff, NOT woff2; an MSIE UA returns EOT which Satori cannot use). `fetch_fonts.GENRE_FONTS` has genre -> free-face shortlists (grotesque_display, humanist_sans, mono, handwritten, serif_editorial, rounded).

**Fontshare premium display faces (download the ZIP TTFs, NOT the CSS woff2):**
```bash
curl -sL https://api.fontshare.com/v2/fonts/download/<slug> -o /tmp/f.zip && unzip -o /tmp/f.zip -d jobs/<slug>/fonts
```
Use the unzipped TTFs. Fontshare's CSS serves woff2 which Satori cannot use, so always take the zip. Clash Display is the go-to heavy display grotesque; General Sans is a clean body with a BoldItalic.

## GOTCHAS

- **Satori IGNORES `WebkitTextStroke`** - outline/stroked text renders INVISIBLE (verified). For outline type, composite the words as image elements via ImageMagick: `magick -background none -fill none -stroke '#fff' -strokewidth N -font <ttf> -pointsize P label:'WORD' word.png`, then place it as an `image` element.
- **Object on a light background** - do NOT floodfill-from-corners (it bleeds through highlights and fragments the object). Generate the object on PURE BLACK, luminance-knockout (`imageutil.alpha_knockout`, level ~`4%,30%`), then float it on the light bg (same as SKILL PB-5).
- **Re-measure after render** - the whole reason to use Satori is exactness; verify the tier ratios and left-margin x actually match the analysis spec (SKILL HR-7).
