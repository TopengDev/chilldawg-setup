---
name: zografee
description: Reference-driven generation of high-quality static design content — posters, editorial/magazine covers, social graphics, key visuals. Sources or accepts a reference image, measure-analyzes it precisely, generates with Gemini Pro (Nano Banana Pro), and converges to Christopher's taste via a logged decision ledger. Use when Christopher says /zografee or asks to create/design a poster, cover, graphic, or visual asset from (or in the style of) a reference.
argument-hint: [what to create + theme; attach a reference image if you have one]
---

# zografee — reference-driven static-content generation

(Greek *zographos*, "painter.") Turns a request + a reference into a high-quality static design, finalized at 4K. Evolved from `/creative` — but **reference-fidelity replaces the generic-ban list**. Grounded across 6 posters / 5 distinct styles (illustrated · editorial-light · dark-glow · duotone · gritty-halftone · editorial-collage).

## North star
**Converge to Christopher's TASTE.** His picks/edits/rejections = ground truth; log EVERY one to the ledger (the taste substrate). Engagement metrics, if ever used, are informational only.

## CRAFT LENS (how the loop reaches "great", not just "passable")
Passable static imagery is free now, so it is worthless. The bar is work that makes the viewer ask "how did they make that?" Four operating habits run through every phase below:
- **Notice WHY, keep looking.** Your first read of a reference (or an output) is shallow. Don't stop at "looks strong" / "looks off"; name the specific cause: the white is warm not cool, the dark went muddy-grey instead of a rich shade, the headline is one ratio-step off the subhead so the hierarchy reads flat, the grain is a flat overlay instead of two composited octaves. A vague reaction can't drive a regeneration; a named one can. There is always a next finer flaw.
- **Range before depth, at ideate.** The cheap-flash ideate pass exists to explore structurally different takes on the brief (different compositional stance, different treatment), not three near-identical variants. Breadth is the hedge against narrow taste.
- **Then push to 10.** Generation #1 is a draft to react against, never a candidate to ship. The gap between fine and great is iteration count (refine / re-ideate), not first-prompt luck. Pick the highest-leverage element (usually the headline or the one signature treatment) and push THAT.
- **Less, but better.** Restraint reads as craft. Before adding a layer/color/element, try removing one. A composition with a deliberate stance beats a busy one.

## Engine (scripts live in the repo, NOT in this skill dir)
Base: `~/claude/Git/repositories/zografee/`
- `engine/gemini.py` — image gen/edit (flash + Pro), direct REST, retry-on-transient. Key resolves from `~/.claude.json`.
- `engine/generate.py` — `ideate()` (flash, N cheap variants) · `finalize()` (Pro 4K) · `refine()` (image-edit). `FINALIZE_INSTRUCTION` is the canonical 4K-preserve prompt.
- `engine/analyze_ref.py` — measured palette, tonal field, grain, `typographic_scale()`, `tier_height()`.
- `engine/source_refs.py` — browser reference sourcing (Dribbble/Behance; needs qutebrowser + qb_proxy + agent-browser).
- `engine/imageutil.py` — ImageMagick helpers (duotone, alpha-knockout, dither, upscale).
- `ledger/ledger.py` — `log_decision(...)` (the taste log).
- `lib/presets.py` — platform dimensions.
- `engine/render_satori.mjs` + `engine/fetch_fonts.py` — **templating-only branch** (see Routing). Not the creative path.
Per job: `jobs/<slug>/{refs/, assets/, finals/, analysis.md, decisions.jsonl}`.

## THE FLOW
**0 · Intake.** Medium, platform → dimensions (`lib/presets.py`), theme, copy intent, brand. Triage (L2 default). Create the job dir; `ledger.log_decision(..., phase="brief", ...)`.

**1 · Reference** — one of:
- **User-supplied:** Christopher attaches/links a reference → save to `refs/ref.*` → go to step 2.
- **Auto-source:** `python3 engine/source_refs.py "<precise query>" jobs/<slug>/refs N` → **CURATION GATE** → present a 3–5 board → Christopher PICKS.
- **CURATION GATE — relay a candidate ONLY if ALL hold:** (1) a single self-contained design of the target type — REJECT branding-collateral grids, UI/mockup collages, style guides, diagrams, multi-panel showcases; (2) aesthetically strong; (3) on-brief; (4) unambiguous (one dominant design). **Quality over filling slots. Vet at FULL SIZE — never relay raw thumbnails.** Precise query >> generic.
- Log the `reference_pick` + **why**.

**2 · MEASURED analysis** (the precision that makes it faithful — see Discipline). `python3 engine/analyze_ref.py refs/ref.* ` then high-zoom crops (ImageMagick) then write `analysis.md` recording: **exact palette (hex)**, **typographic-scale spec** (each text block's % of canvas + tier ratios + left-margin alignment), composition, treatment (texture/duotone/dither/grain), mood, route, and the **copy mapping** (theme → every text slot, with engaging copy).

**3 · Ideate.** `generate.ideate(prompt, 'jobs/<slug>/assets', n=2-3, aspect=...)` on cheap flash. The prompt = the measured style (exact palette, composition, treatment, type genre) **+ the exact copy, stated explicitly**.

**4 · PICK gate.** FIRST **self-critique each candidate against the reference + facets** (apply the Craft Lens): name 3-5 SITUATIONAL facets the piece should make the viewer FEEL (e.g. a watch poster: "precise / restrained / covetable") and score each candidate on them, then keep looking and name the single biggest *specific* flaw vs. the reference (muddy dark / flat hierarchy / treatment reads as a flat overlay / stray cool neutral / weak focal order). If a candidate's top flaw is fixable, **fix-target it and `refine()` or re-ideate before showing Christopher**, because generation #1 is a draft, not a candidate. THEN run the **shadow judge** (predict Christopher's pick BEFORE showing him, see Shadow Judge): `shadow.predict(candidates, facets, brief, ref_path)` → `shadow.log_prediction(...)`. THEN present the refined variants side-by-side vs the reference, each with its facet read + the named flaw. Christopher picks (or requests edits → `refine()` or re-ideate). Log `final_pick` + **why** to the ledger (make the `why` specific: the named-flaw language above is exactly the substrate the judge converges against), and `shadow.record_human_pick(job, phase, pick)` to score the judge. Do the same at the reference PICK gate.

**5 · Finalize + deliver.** `generate.finalize('assets/<chosen>.png', generate.FINALIZE_INSTRUCTION, 'finals/<slug>-4k.png', aspect=..., size='4K')` → Nano Banana Pro 4K (~3584px long edge, preserves design + exact copy). Verify the copy/colors survived; deliver in the right dimensions.

## ENGINE RULE = Gemini Pro
**`gemini-3-pro-image` (Nano Banana Pro) is THE design engine.** Proven across 6 posters to nail dark-glow, gritty halftone-collage, AND precise editorial (two-tone high-contrast serif + star-in-the-O + bitmap statue) — one shot each, **keeping the exact supplied copy verbatim every time.** Ideate on cheap `gemini-2.5-flash-image`; finalize on Pro 4K. Always prompt the EXACT copy + measured palette/style.

### Satori — NOT the creative path
`render_satori.mjs` is **demoted to programmatic templating only**: stamping the SAME fixed layout N× with swapped data/copy (price-card per product, personalized poster per user, exact brand-spec template). That's *data→layout at scale*. **Mental model: Gemini Pro = the designer · Satori = the print shop.** (The old "Satori for exact type/copy" rule is obsolete — Pro handles both. The one Satori-exact poster cost ~15 grinding rounds for a result Pro reaches in one.)

## MEASURED-ANALYSIS DISCIPLINE (non-negotiable)
Vision perceives semantically + low-res; design is metric → **MEASURE, don't eyeball.**
- **Palette:** exact hex via `analyze_ref.py`. Catch warm-vs-cool whites, off-black vs pure black, subtle tints.
- **Color DISCIPLINE, not just hex:** read the palette's *logic*, not only its values. (1) **One temperature:** is the whole field warm or cool? The neutrals too? Record it; a stray cool grey in a warm comp is the commonest tell. (2) **Rich vs muddy darks:** a good dark shifts hue + gains chroma as it deepens, it does NOT just fade toward grey. Note which it is. (3) **Restraint:** count the colors actually doing work (often 2-3 + neutrals); excess color variance is a generic tell. (4) **Perceived brightness:** equal-value accents don't read equal-weight (a blue reads darker than a yellow-green); note which accent actually leads the eye (think OKLCH/perceptual lightness, not raw HSL value).
- **Genuine hierarchy is structural, not just "big vs small":** real type hierarchy uses true contrast of **weight AND scale AND family** (a hairline display over a set sans body, not one font at two sizes). Note family pairing + weight jumps + optical-size shifts, plus **measure** (line length) of any body block. Two sizes one ratio-step apart read flat, so capture the actual ratio.
- **Treatment = an ordered LAYER STACK, not a flat filter.** Decompose the surface into composited layers, bottom-up, and name each: base wash / duotone map / halftone (dot or line) / grain (note if it reads as one flat overlay vs. two octaves, coarse + fine) / color wash or spot-color overprint / blend interaction where layers meet (multiply, screen, overlay, color-dodge, plus-lighter). This recipe is what makes riso/editorial/poster work read as crafted rather than a 5%-opacity overlay slapped on top. Record the stack so the prompt can rebuild it.
- **Alignment is measured too:** every element's left-edge x (usually one shared margin); inline marker rows (line/number/label) vertically centered on one axis.
- **NEVER trust a measurement without viewing the trimmed crop** — `-threshold -trim` silently returns the crop-box height or catches 2 lines. Save the crop and read it back.
- **Compare sizes at NATIVE scale:** resize both images to one canvas and montage the crops **without resizing** — the only reliable size comparison.
- **Verify output vs reference** (sample bg/colors, native-scale side-by-side) before declaring done.

## QUALITY BAR = reference fidelity
The chosen reference — pre-vetted strong by the curation gate — **IS** the quality standard. Match it precisely (palette, proportion, composition, treatment); target **~90% fidelity**. `design-theory.md` (in this dir) is an analysis aid. **Do NOT inherit `/creative`'s 20 hard-bans** — a strong reference may legitimately use gradients / glow / glassmorphism / sparkles; fidelity, not avoidance, is the bar here.

## PROMPT-CRAFT (turn the measured analysis into crafted pixels)
The measured stack is only useful if it lands in the prompt. Beyond exact palette + exact copy + composition, state these explicitly so the generator rebuilds the craft, not a generic approximation:
- **Take a compositional stance; don't let the model default.** Name the structure (full-bleed type-poster vs. split editorial vs. dominant-headline-over-fine-print) and the focal reading order. A stated stance is what separates a designed comp from "stuff centered on a background".
- **Prompt the treatment as composited LAYERS, with intent.** Don't say "add grain / add a texture". Describe the stack from the analysis: e.g. "duotone-mapped to [hex]+[hex], then a fine halftone dot screen over the midtones, then two grain octaves (coarse + fine) for tooth, spot inks overprinting to a darker multiply where they overlap." Call the blend interaction by name (multiply / screen / overlay / color-dodge / plus-lighter). This is the difference between riso/editorial that reads as printed and a flat 5%-opacity overlay.
- **Color: discipline in words.** Lock ONE temperature across everything incl. neutrals; ask for **rich darks** ("deep [hue] shadows hue-shifted toward [neighbor], gaining saturation, NOT washed-out grey"); keep the working palette restrained (2-3 + neutrals); for gradients ask for **eased, perceptually-even** transitions ("smooth blend, no muddy mid-tone, no visible banding/horizon line"). Make the lead accent intentional by perceived brightness, not accident.
- **Type: ask for GENUINE hierarchy.** Specify real contrast of weight + scale + family (name the genre: "hairline high-contrast serif display over a quiet grotesque body"), the extreme ratio the reference uses, and a sane body **measure**. Never "a bold heading and some text".
- **Depth + light (only when the reference reads as lit/material; flat graphics stay flat).** One consistent light direction; shadows as a tight CONTACT shadow PLUS a soft ambient falloff (a single floating drop shadow reads fake); name the material + its specular ("matte paper sheen" vs. "sharp specular on foil/metal"); prefer natural/worn edges over hard geometric cuts.
- **Micro-detail = the trained-eye finish.** Borders crisp and consistent (no muddy strokes); one icon/glyph style throughout (never mix fill/weight/radius); group related elements by proximity instead of needless dividers/boxes; align everything to the shared margins from the analysis. These are the breadcrumbs that read as human care.

## COPY = engaging, themed, mapped
For themed posters, write **engaging** copy mapped to the reference's text slots (Christopher explicitly wants this). Session examples: gambling → "BROKE" / "One More Hand" / "Know when to fold"; crypto → "Profit From Chaos" / "Volatility is your edge"; hacker → "OVERRIDE" / "Are you really alone?". Keep names/placeholders swappable.

## LEDGER (taste substrate — log everything)
`ledger.log_decision(job, content_type, phase, brief=, facets={content_type,brand,audience,platform,style_tags[]}, candidates=[{id,descriptor}], chosen=, rejected=[], why=, job_dir=)`. Phases: `brief · reference_pick · final_pick · edit · rejection`. **The `why` is the highest-value field — never skip it.** This is what the future autonomous judge converges against.

## SHADOW JUDGE (Step 4 — BUILT, running in shadow)
`judge/` predicts Christopher's pick at each gate, behind the human decision — it never decides, it only guesses + gets scored.
- `judge/profile.json` — his **seeded taste profile** (faceted principles grounded in the ledger *why*s + design memories). Dominant axis = **reference fidelity**; then cleaner composition, strong copy, restrained palette; light/editorial for service brands; anti-high-variance; ties are valid.
- `judge/shadow.py` — `predict(candidates, facets, brief, ref_path)` (Claude Sonnet vision) → `{predicted, tie, confidence, ranking, why}`. `log_prediction()` before the gate, `record_human_pick()` after, `agreement_stats()` for the metric.
- `judge/backtest.py` — replays the judge on historical picks.
- **Usage at every gate:** predict → log_prediction → present to Christopher → he picks → log to ledger + record_human_pick. Pure shadow; the human still decides.
- **Seed baseline (2026-06-16 backtest, 6 events, NOT held-out):** 66.7% top1 / 33% exact. Nailed the single-variant fidelity picks; diverges on subtle density-energy + tie cases.
- **KEY LEARNING:** the judge's self-reported confidence is unreliable (Sonnet anchors ~72% regardless) → the autonomy gate must key off **measured agreement track-record per facet**, NOT self-confidence.

## AUTONOMY ROADMAP (earned, not switched)
Instrument (DONE — ledger) → seed taste profile (DONE — `judge/profile.json`) → **shadow-mode judge** (DONE/BUILT — running behind the gates, accumulating real agreement%) → **graduated** per-content-type autonomy once *measured* agreement clears ~85% (low-agreement facets escalate; hard brand/quality rules auto-reject) → scheduled **"dream"** consolidation regenerating the taste profile + craft playbook from accumulated shadow data (recency-weighted + small exploration budget — taste is a moving target). Until earned, Christopher picks the gates.
