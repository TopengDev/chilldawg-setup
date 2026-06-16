---
name: zografee
description: Reference-driven generation of high-quality static design content — posters, editorial/magazine covers, social graphics, key visuals. Sources or accepts a reference image, measure-analyzes it precisely, generates with Gemini Pro (Nano Banana Pro), and converges to Christopher's taste via a logged decision ledger. Use when Christopher says /zografee or asks to create/design a poster, cover, graphic, or visual asset from (or in the style of) a reference.
argument-hint: [what to create + theme; attach a reference image if you have one]
---

# zografee — reference-driven static-content generation

(Greek *zographos*, "painter.") Turns a request + a reference into a high-quality static design, finalized at 4K. Evolved from `/creative` — but **reference-fidelity replaces the generic-ban list**. Grounded across 6 posters / 5 distinct styles (illustrated · editorial-light · dark-glow · duotone · gritty-halftone · editorial-collage).

## North star
**Converge to Christopher's TASTE.** His picks/edits/rejections = ground truth; log EVERY one to the ledger (the taste substrate). Engagement metrics, if ever used, are informational only.

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

**4 · PICK gate.** FIRST run the **shadow judge** (predict Christopher's pick BEFORE showing him — see Shadow Judge): `shadow.predict(candidates, facets, brief, ref_path)` → `shadow.log_prediction(...)`. THEN present variants side-by-side vs the reference. Christopher picks (or requests edits → `refine()` or re-ideate). Log `final_pick` + **why** to the ledger, and `shadow.record_human_pick(job, phase, pick)` to score the judge. Do the same at the reference PICK gate.

**5 · Finalize + deliver.** `generate.finalize('assets/<chosen>.png', generate.FINALIZE_INSTRUCTION, 'finals/<slug>-4k.png', aspect=..., size='4K')` → Nano Banana Pro 4K (~3584px long edge, preserves design + exact copy). Verify the copy/colors survived; deliver in the right dimensions.

## ENGINE RULE = Gemini Pro
**`gemini-3-pro-image` (Nano Banana Pro) is THE design engine.** Proven across 6 posters to nail dark-glow, gritty halftone-collage, AND precise editorial (two-tone high-contrast serif + star-in-the-O + bitmap statue) — one shot each, **keeping the exact supplied copy verbatim every time.** Ideate on cheap `gemini-2.5-flash-image`; finalize on Pro 4K. Always prompt the EXACT copy + measured palette/style.

### Satori — NOT the creative path
`render_satori.mjs` is **demoted to programmatic templating only**: stamping the SAME fixed layout N× with swapped data/copy (price-card per product, personalized poster per user, exact brand-spec template). That's *data→layout at scale*. **Mental model: Gemini Pro = the designer · Satori = the print shop.** (The old "Satori for exact type/copy" rule is obsolete — Pro handles both. The one Satori-exact poster cost ~15 grinding rounds for a result Pro reaches in one.)

## MEASURED-ANALYSIS DISCIPLINE (non-negotiable)
Vision perceives semantically + low-res; design is metric → **MEASURE, don't eyeball.**
- **Palette:** exact hex via `analyze_ref.py`. Catch warm-vs-cool whites, off-black vs pure black, subtle tints.
- **Proportion = BLOCK FOOTPRINT + space-fill + structure** — NOT a single per-line cap-height ratio. Measure each text *block's* % of canvas + the tier ratios; replicate structural tricks (e.g. wrapping a long hero word into more lines to dominate). Real scales are often *extreme* (dominant headline, fine-print body) — don't assume a moderate hierarchy.
- **Alignment is measured too:** every element's left-edge x (usually one shared margin); inline marker rows (line/number/label) vertically centered on one axis.
- **NEVER trust a measurement without viewing the trimmed crop** — `-threshold -trim` silently returns the crop-box height or catches 2 lines. Save the crop and read it back.
- **Compare sizes at NATIVE scale:** resize both images to one canvas and montage the crops **without resizing** — the only reliable size comparison.
- **Verify output vs reference** (sample bg/colors, native-scale side-by-side) before declaring done.

## QUALITY BAR = reference fidelity
The chosen reference — pre-vetted strong by the curation gate — **IS** the quality standard. Match it precisely (palette, proportion, composition, treatment); target **~90% fidelity**. `design-theory.md` (in this dir) is an analysis aid. **Do NOT inherit `/creative`'s 20 hard-bans** — a strong reference may legitimately use gradients / glow / glassmorphism / sparkles; fidelity, not avoidance, is the bar here.

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
