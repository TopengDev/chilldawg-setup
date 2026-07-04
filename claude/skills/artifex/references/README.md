# /artifex reference library: the reference-image protocol

Curated montages from the ref-study of 12 award-caliber sites (real fonts read from each DOM, captured headless). These ship with the skill so `/artifex` designs **grounded in studied technique, not the model's idea of "engaging" (N8)**.

**THE PROTOCOL (mandatory, enforced by audit check G):**

1. Before building any section, OPEN its named montage with the Read tool (the actual image) DURING THIS SESSION. Model memory of a site is not grounding.
2. Read that montage's STEAL / DO-NOT-COPY row below alongside the image. Several references contain patterns that are BANNED on our builds (mono labels, outline type); the DO-NOT-COPY column is what keeps a study session from re-importing a hard-ban.
3. Log the read in the Variance Map's `Ref read:` cell (SKILL §6 step 2). A map row whose montage was not Read this session FAILS audit check G.

**Full set** (all 12 sites, per-site screenshots, `_analysis-notes.md`, the original variance-playbook): `~/claude/notes/pulse-pitch-deck-2026-06-20/ref-study/`. The six bundled here are the most instructive + reasonably sized.

## The six bundled montages: STEAL THIS / DO NOT COPY

| File | Site | STEAL THIS | DO NOT COPY | Techniques | Tier |
|---|---|---|---|---|---|
| `crescente.png` ★ | Sicilian street food | **Best buildable F&B blueprint.** Flat color-field swaps (orange to cream), the rounded-panel reveal handoff, inline icons set IN the display headline (not beside it), curved sticker/arc type on a path, ONE 3D product moment, the confident two-color discipline | Stacking more than one 3D product moment (N4 caps heavy effects at 1) | T1, T2, T3, T5, T11 | B-heavy |
| `chungiyoo.png` ★ | designer portfolio | **Type-as-hero, the cheapest variance family.** Color-field swaps (cream/yellow/pink), serif/script type VARIETY as the technique, floating + tilted cards, circular arc-text. Mostly CSS/type | The OUTLINE type moments: our builds are filled-only, never outline/stroked (HB-6). Get the variety from serif/script/weight/scale contrast instead | T3, T4, T5, T9 | B-heavy |
| `lusion.png` | creative-dev studio | **The canonical variance signature**: physics hero → red full-bleed showreel cut → editorial work grid → project gallery → kinetic type + hand-drawn ring → framed-3D device. Six skeletons, zero repeat. ONE grotesque + ONE label discipline + ONE color logic as the cohesion system | The Plex Mono eyebrow/label layer: on our builds that layer is body-sans small-caps + oversized index numbers, NEVER mono (DD-1, HB-2). Also the FULL physics hero is Elite tier (T18-full); take only the lite dot-field version, and only as the single H splurge | T1, T3, T4, T7, T14, T15, T18 | mixed (1 H/E hero) |
| `synchronized.png` | digital studio | **Index-numbered case panels on alternating muted color-fields** + circular type-rings used ONCE then retired. Study the retire-the-technique discipline itself: it is N2 in the wild | Letting the muted palette flatten the page into one key: modulate density/mood/type-rhythm per section (DD-2, audit check N). Any mono accents present: reproduce in small-caps sans (DD-1) | T5, T8 | B |
| `mana.png` | yerba-mate brand | **Product-anchored card swap**: the product stays pinned while benefit cards swap around it. Flat-illustration collage layered with one real product. Warm F&B energy | Pinning the product via GSAP `pin:true`: pin with CSS `position:sticky` (SKILL §7 C4, pin-blink) | T21, T22 | B |
| `wix-pantone.png` | Pantone CotY capsule | **Bento texture collage in ONE monochrome family** + editorial hero type + sans x classical-serif contrast. The disciplined single-color story | Letting the gradient band go soft/blurred-radial: keep gradients structured and hard-edged, aurora haze is HB-1 | T3, T7 | B |

## Not bundled (in the notes dir), and why

- `pioneer-resn`: **Elite tier (T19 continuous 3D world morph).** A named WARNING, not a target. Do not attempt, do not fake at 40%.
- `prometheus`: cautionary. A once-legendary WebGL site regressed to generic Elementor + Plus Jakarta Sans (an HB-3 banned font). Mood ref only.
- `noomo-xr`: synthwave grid + VCR-knockout type (T20/T6). DO NOT COPY the VCR mono face: reproduce the knockout look with the display/body faces unless the whole build is the Terminal/Monospace archetype (DD-1). Heaviest montage; pull from the notes dir if building retro-tech.
- `kpr`: cinematic game-trailer pacing (T12/T13/T14). DO NOT COPY its mono accent: body-sans small-caps on our builds (DD-1). Pull from notes for a worldbuilding/web3 brief.
- `awwwards`: the polished baseline (card grid + hover-video, T16), not a wow ref.
- `mammut`: site was down at capture; horizontal mountain-ascent storytelling (T10) as a named precedent only. Don't assert specifics.

**Fastest paths by brief:** warm consumer / F&B → `crescente` + `mana`. Editorial / portfolio / type-led → `chungiyoo` + `synchronized` + `wix-pantone`. Tech / data / dev → `lusion` (+ `noomo-xr`, `kpr` from the notes dir). Always cross-check the Variance Map (SKILL §6) against ≥ 2 refs, and log every read in the map's `Ref read:` cell.

## Shader-engine tie-ins (SKILL §5.1 / N10)

Where a study's technique is shader-class, the engine default applies:

- `lusion.png`: the "lite dot-field" reading of Lusion's hero: if the field is a NON-interactive ambient ground, the engine is Paper Shaders `DotGrid` / `DotOrbit` (N10, SKILL §5.1). Cursor-reactive brand-shape formation is exactly what keeps it a custom r3f carve-out (T18 / hero option D), and the single H splurge.
- `wix-pantone.png`: the DO-NOT-COPY row already bans letting the gradient band go soft/blurred-radial (HB-1). If the band is built as a shader, reach for the STRUCTURED classes (`Dithering` / `HalftoneDots` / `HalftoneCmyk`, SKILL §5.1), never a soft pastel MeshGradient haze; HB-1 is judged on the rendered output, engine irrelevant.
