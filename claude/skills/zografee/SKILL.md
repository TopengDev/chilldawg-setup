---
name: zografee
description: Reference-driven generation of high-quality static design content (posters, editorial/magazine covers, social graphics, key visuals). Sources or accepts a reference image, measure-analyzes it precisely, generates with Gemini Pro (Nano Banana Pro), and converges to Christopher's taste via a logged decision ledger. Use when Christopher says /zografee or asks to create/design a poster, cover, graphic, or visual asset from (or in the style of) a reference.
argument-hint: "<what to create + theme> (attach a reference image if you have one)"
---

# zografee - reference-driven static-content generation

(Greek *zographos*, "painter.") Turns a request plus a reference into a high-quality static design, finalized at 4K on Gemini Pro. The taste-converging front-end of a planned autonomous content factory. Grounded across **7 real jobs / 5+ styles** (illustrated, editorial-light, dark-glow, duotone, gritty-halftone, editorial-collage) in the engine repo `jobs/`. Every human decision is logged as labeled data so the loop can eventually predict Christopher's picks.

This is NOT `/creative`. It replaces `/creative`'s generic-avoidance ban list with a single higher bar: **fidelity to a reference Christopher already vetted as strong.** A strong reference may legitimately use gradients, glow, or glassmorphism; here fidelity governs, not avoidance.

---

## 0 - ROUTING (pick the right skill first)

| The request is... | Route to | Why |
|---|---|---|
| Reference-driven STATIC design (a reference exists or should be sourced; you want the taste-ledger convergence flow) - poster, cover, key visual, social graphic, editorial | **/zografee** (here) | reference -> measured analysis -> Gemini Pro -> logged ledger |
| A one-off visual asset with NO reference-fidelity flow - quick logo, icon set, spot illustration, a brand graphic driven by brand tokens not a reference | **/creative** | general multi-model asset generation, no reference-convergence machinery |
| A UI, web page, component, interactive surface, or app | **/frontend-design** (production SAFE) or **/artifex** (high-variance immersive) | code, not a raster image |
| A scrollytelling investor/pitch deck website | **/pitch-deck** | a built site, not a static graphic |
| An exhaustive per-screen product screenshot inventory | **/atlas** | neutral capture, not creative generation |

Borderline poster-vs-/creative: if a reference is in play (supplied or worth sourcing) and Christopher wants the pick-gate + ledger convergence, it is /zografee. A throwaway "just make me an icon" with no reference is /creative.

## EXECUTION CONTEXT (house rule - Creative Tasks ALWAYS Delegate)

Image generation is a creative task. If /zografee is invoked from the **main command-center session**, DELEGATE the job to a spawned worker (brief + attn + reports back) - main only discusses/reviews. A **worker** that receives this brief EXECUTES the gates directly and NEVER re-delegates. This SKILL.md is written for the executing session.

---

## NORTH STAR

**Converge to Christopher's TASTE.** His picks / edits / rejections are ground truth; log EVERY one to the ledger with a specific `why` (the taste substrate). Engagement metrics, if ever used, are informational only and never override his taste. Autonomy is EARNED off measured agreement, never switched on.

## CRAFT LENS (how the loop reaches "great", not just "passable")

Passable static imagery is free now, so it is worthless. The bar is work that makes the viewer ask "how did they make that?" Four habits run through every gate:

- **Notice WHY, keep looking.** Your first read of a reference (or an output) is shallow. Do not stop at "looks strong" / "looks off"; name the specific cause: the white is warm not cool, the dark went muddy-grey instead of a rich shade, the headline is one ratio-step off the subhead so the hierarchy reads flat, the grain is a flat overlay instead of two composited octaves. A vague reaction cannot drive a regeneration; a named one can. There is always a next finer flaw. (`design-theory.md` in this dir is the vocabulary source - read it at G2 and G4.)
- **Range before depth, at ideate.** The cheap-flash ideate pass explores structurally different takes on the brief (different compositional stance, different treatment), not three near-identical variants. Breadth hedges against narrow taste.
- **Then push to 10.** Generation #1 is a draft to react against, never a candidate to ship. The gap between fine and great is iteration count (refine / re-ideate), not first-prompt luck. Pick the highest-leverage element (usually the headline or the one signature treatment) and push THAT.
- **Less, but better.** Restraint reads as craft. Before adding a layer / color / element, try removing one. A composition with a deliberate stance beats a busy one.

---

## HARD RULES (NEVER / ALWAYS - each has a concrete trigger)

- **HR-1 - NEVER run `engine/source_refs.py` as-is.** Its browser interior predates the 2026-06-22 multi-port proxy: `CDP="9222"` hardcoded (that is the user's interactive ACTIVE-TAB port), it calls `agent-browser tab new` (field-broken, exit 144, BANNED per the agent-browser skill), and it `close`s a live tab. Running it hijacks or closes Christopher's browsing tab. ALWAYS source references via the agent-browser `/claim` lifecycle (`references/reference-sourcing.md`).
- **HR-2 - NEVER call `ideate()` before `jobs/<slug>/analysis.md` exists** with all 7 required sections (G2). No analysis.md = no generation. This is the exact regression that got SAB v1 rejected (lazy analysis).
- **HR-3 - NEVER present a pick gate without first (a) self-critiquing each candidate with ONE NAMED specific flaw + 3-5 situational facet scores, and (b) running the shadow sequence `predict -> log_prediction`.** ALWAYS `ledger.log_decision(... why=<non-empty>)` AND `shadow.record_human_pick(...)` immediately after his pick, then VERIFY both with `tail -1` on `decisions.jsonl` and `judge/shadow.jsonl`.
- **HR-4 - NEVER skip the `why`** on any `reference_pick`, `final_pick`, `edit`, or `rejection` row. ALWAYS log a `rejection` row when Christopher rejects a whole board or candidate set (negative examples are training data; historically ZERO were logged - do not repeat that leak).
- **HR-5 - ALWAYS ideate on `gemini-2.5-flash-image` and finalize on `gemini-3-pro-image` at 4K.** NEVER use Satori for reference-driven creative generation (it is templating-only: same fixed layout, swapped data, N copies). NEVER use ImageMagick upscale as the hi-res path (interpolation only, no new detail).
- **HR-6 - ALWAYS state in the generation prompt:** the EXACT copy verbatim, the measured palette hexes, ONE locked color temperature, the layer-stack treatment with blend modes named, the compositional stance, and genuine type hierarchy (weight AND scale AND family). NEVER prompt "add grain" or "a bold heading and some text".
- **HR-7 - NEVER trust a threshold-trim measurement without saving the trimmed crop and viewing it.** `-threshold -trim` silently returns the crop-box height or catches two lines. ALWAYS compare sizes at NATIVE scale (montage crops without resizing).
- **HR-8 - NEVER deliver a final without the G5 verify triplet** vs the picked variant AND the reference: copy read-back verbatim, bg/palette sample diff, native-scale side-by-side. Pro 4K REINTERPRETS the design - check, never assume.
- **HR-9 - NEVER inherit `/creative`'s generic-avoidance ban list.** Reference fidelity (~90%) is the bar here. NEVER route UI/web/interactive work here (/frontend-design or /artifex) or scrollytelling decks (/pitch-deck).
- **HR-10 - NEVER pass aspect `1.91:1` (the `og_image` preset) to Gemini.** It is outside the validated aspect enum (`1:1, 3:4, 4:3, 4:5, 9:16, 16:9, 2:3, 3:2`). Generate at `16:9` then `magick`-crop to 1200x630.
- **HR-11 - ALWAYS run engine code from the repo with the sys.path preamble** (the modules import each other bare - `generate.py` does `import gemini`), or use the `python3 engine/gemini.py` CLI forms. A bare `import generate` from the wrong cwd ImportErrors.
- **HR-12 - NEVER print or echo the Gemini or Anthropic key.** Key order for Gemini: `~/.claude/secrets.env` `GOOGLE_AI_API_KEY` (must start `AIza`) FIRST, then a walk of `~/.claude.json` (secrets.env has been observed to drop the line). `resolve_key()` / `_key()` read it internally - never `cat`/`echo` the value; to check presence use a count only (`grep -c '^GOOGLE_AI_API_KEY=' ~/.claude/secrets.env`).
- **HR-13 - NEVER graduate a facet to autonomy on the judge's self-reported confidence** (Sonnet anchors ~72% regardless of the real margin). ONLY measured per-facet agreement `>=85%` over `>=10` real shadow events graduates a facet.
- **HR-14 - ALWAYS delegate execution to a worker when invoked from main** (Creative Tasks ALWAYS Delegate). A worker receiving the brief executes directly, never re-delegates.
- **HR-15 - ALWAYS vet sourced candidates at FULL SIZE before relaying; NEVER relay raw thumbnails.** Relay a candidate ONLY if ALL 4 curation checks pass (G1). Quality over filling slots.
- **HR-16 - NEVER edit or regenerate existing ledger / shadow / profile / jobs data.** `decisions.jsonl`, `shadow.jsonl`, `profile.json`, and `jobs/` history are append-only evidence. The skill appends forward via the engine APIs only. Profile regeneration belongs to the future dream loop, not manual edits.

---

## ENGINE MAP (scripts live in the repo, NOT in this skill dir)

Repo root: `~/claude/Git/repositories/zografee/` (git-clean, single commit; toolchain verified live: `magick` 7.1.2, `node` v22, `python3`, `jq`).

| File | Role | Use |
|---|---|---|
| `engine/gemini.py` | Gemini image client (gen/edit, key resolve, retry-on-transient) | primary |
| `engine/generate.py` | `ideate()` (flash) / `finalize()` (Pro 4K) / `refine()` (image-edit) + `FINALIZE_INSTRUCTION` | primary |
| `engine/analyze_ref.py` | measured `report()`, `palette()`, `pixel()`, `tier_height()`, `typographic_scale()`, `tonal_field()`, `grain()` | primary (G2) |
| `engine/source_refs.py` | browser sourcing - **INTERIOR STALE/HAZARDOUS (HR-1)**; use the manual recipe instead | do NOT run as-is |
| `engine/imageutil.py` | ImageMagick helpers: `upscale`, `alpha_knockout`, `composite_over` | support |
| `engine/fetch_fonts.py`, `engine/render_satori.mjs` | **templating-only branch** (see `references/satori-templating.md`) | NOT the creative path |
| `ledger/ledger.py` | `log_decision(...)` + `stats()` - the taste substrate | primary (every gate) |
| `judge/shadow.py` | shadow taste judge: `predict/log_prediction/record_human_pick/agreement_stats` | primary (G1, G4) |
| `judge/profile.json` | seeded faceted taste profile (P1 = reference fidelity dominant) | read-only |
| `lib/presets.py` | `DIMENSIONS` presets + aspect enum + `ENGINE`/`MODELS` routing | G0 |

Per job: `jobs/<slug>/{refs/, assets/, finals/, analysis.md, decisions.jsonl}`.

### INVOCATION RECIPES (all verified - copy these)

**The sys.path preamble (HR-11 - cwd-independent, imports all three module dirs):**
```bash
python3 - <<'PY'
import sys, os
Z = os.path.expanduser("~/claude/Git/repositories/zografee")
sys.path[:0] = [f"{Z}/engine", f"{Z}/ledger", f"{Z}/judge"]
import generate, ledger, shadow, analyze_ref   # all resolvable now
PY
```

**Ideate (G3) / finalize (G5) / refine:**
```python
# inside the preamble heredoc:
Z = os.path.expanduser("~/claude/Git/repositories/zografee")
job = f"{Z}/jobs/<slug>"
# G3 - 2-3 structurally distinct flash variants -> var-A.png, var-B.png, ...
generate.ideate("<measured-style + EXACT copy prompt>", f"{job}/assets", n=3, aspect="3:4",
                variations=["stance: full-bleed type-poster", "stance: split editorial", "stance: dominant-headline-over-fine-print"])
# G5 - Pro 4K re-render of the CHOSEN variant (keeps design + exact copy)
generate.finalize(f"{job}/assets/var-A.png", generate.FINALIZE_INSTRUCTION,
                  f"{job}/finals/<slug>-4k.png", aspect="3:4", size="4K")
# recovery - polish the picked variant while keeping composition (PB-3)
generate.refine(f"{job}/assets/var-A.png", "keep composition + exact text; <fix the named flaw>",
                f"{job}/assets/var-A2.png", aspect="3:4")
```

**CLI equivalents (no preamble needed, run from repo root):**
```bash
cd ~/claude/Git/repositories/zografee
python3 engine/gemini.py gen  "<prompt>" jobs/<slug>/assets/var-A.png --model flash --aspect 3:4
python3 engine/gemini.py edit jobs/<slug>/assets/var-A.png "<finalize instruction>" jobs/<slug>/finals/<slug>-4k.png --model pro --size 4K
python3 engine/gemini.py models                      # list image models on the key
python3 engine/analyze_ref.py jobs/<slug>/refs/ref.png   # measured JSON report (G2)
python3 ledger/ledger.py stats                       # ledger completeness (G0/G6)
python3 judge/shadow.py stats                         # measured agreement (G6, HR-13)
python3 engine/imageutil.py knockout src.png out.png  # luminance alpha-knockout (PB-5)
```

**Ledger row (G0/G1/G4/G6 - full keyword call; first three args are positional):**
```python
ledger.log_decision(
    "<slug>", "<content_type>", "final_pick",       # content_type grounded set below
    brief="<the request as given>",
    facets={"content_type": "<...>", "brand": "<...>", "audience": "<...>",
            "platform": "<preset>", "style_tags": ["<...>"]},
    candidates=[{"id": "var-A", "descriptor": "..."}, {"id": "var-B", "descriptor": "..."}],
    chosen="var-A",
    why="<SPECIFIC named-flaw language - the convergence signal, HR-4>",
    rejected=["var-B"],
    job_dir="<absolute job dir>")   # phases: brief | reference_pick | final_pick | edit | rejection
```
Grounded `content_type` values: `poster_illustrated`, `poster_textheavy`, `poster_darktech`, `poster_editorial_duotone`, `poster_editorial_collage`, `poster_cinematic`, `social_post`, `illustration`, `brand_graphic`.

**Shadow 4-call gate (G1 + G4 - the sequence that makes autonomy data accrue):**
```python
# candidates for shadow are {id, path} (NOT the ledger {id, descriptor} shape)
cand = [{"id": "var-A", "path": f"{job}/assets/var-A.png"}, {"id": "var-B", "path": f"{job}/assets/var-B.png"}]
verdict = shadow.predict(cand, facets={"content_type": "<ct>"}, brief="<brief>", ref_path=f"{job}/refs/ref.png")
shadow.log_prediction("<slug>", "final_pick", {"content_type": "<ct>"}, cand, verdict, brief="<brief>")
#   ... present the board to Christopher, he PICKS ...
shadow.record_human_pick("<slug>", "final_pick", "var-A")   # fills agree_top1/agree_exact
```
Full schema + graduation criteria: `references/ledger-and-judge.md`.

---

## THE FLOW - blocking gates G0..G6

Each gate has a checklist that MUST pass and an exact verification command. Do not advance on a failed gate.

### G0 - INTAKE
- [ ] Triage L2 default. If invoked from main -> delegate to a worker (HR-14).
- [ ] Resolve dimensions from `lib/presets.py` - name the preset + px + aspect. **`og_image` guard (HR-10): generate 16:9, crop to 1200x630; never pass 1.91:1.**
- [ ] Name the facets `{content_type, brand, audience, platform, style_tags[]}`.
- [ ] Optional brand input: if Christopher supplies brand tokens, capture them in the shape of `brand-kit-template.json` (colors / typography / tone / avoid) and carry them as the `brand` facet + prompt constraints. Skip if no brand.
- [ ] Create `jobs/<slug>/{refs,assets,finals}`.
- [ ] Log the `brief` row: `ledger.log_decision("<slug>", "<ct>", "brief", brief=..., facets=..., job_dir=...)`.
- **Verify:** `ls jobs/<slug>` shows the three dirs; `jq -c 'select(.job=="<slug>" and .phase=="brief")' ledger/decisions.jsonl | tail -1` prints the brief row.

### G1 - REFERENCE (one of two paths; BOTH log a `reference_pick`)
- **Path A - user-supplied:** save the attached/linked image to `jobs/<slug>/refs/ref.*`. Still log a `reference_pick` row (`chosen="user-supplied"`, `why="<why this reference is the target>"`).
- **Path B - auto-source (agent-browser `/claim` lifecycle, `references/reference-sourcing.md`; NEVER `source_refs.py`, HR-1):**
  - [ ] Curation gate - score EACH candidate at FULL SIZE, pass/fail on all 4: (1) a single self-contained design of the target type (REJECT branding-collateral grids, UI/mockup collages, style guides, diagrams, multi-panel showcases); (2) aesthetically strong; (3) on-brief; (4) unambiguous (one dominant design). Only all-pass candidates reach the 3-5 board.
  - [ ] Run the shadow sequence on the board (predict -> log_prediction), present, Christopher picks.
  - [ ] Log `reference_pick` + non-empty `why`; `shadow.record_human_pick(...)`; log rejected candidates (a rejected WHOLE board -> a `rejection` row, HR-4). Precise query >> generic.
- **Verify:** the picked image is in `refs/`; `jq -c 'select(.job=="<slug>" and .phase=="reference_pick")' ledger/decisions.jsonl | tail -1` prints the row.

### G2 - MEASURED ANALYSIS (the precision that makes it faithful; HR-2)
- [ ] `python3 engine/analyze_ref.py jobs/<slug>/refs/ref.*` -> measured JSON (dims/aspect, clean bg samples, gradient, grain stddev, 14-color palette, 5x7 tonal field).
- [ ] Find each text-tier box by VIEWING high-zoom crops (HR-7), then `analyze_ref.typographic_scale(ref, {"headline":"WxH+X+Y", "subhead":"...", "body":"..."})` for px + `pct_of_H` + tier ratios.
- [ ] Read `design-theory.md` (this dir) as the vocabulary source for the analysis.
- [ ] Write `jobs/<slug>/analysis.md` with **all 7 sections**: (1) exact hex palette; (2) color-discipline read (temperature / rich-vs-muddy dark / restraint count / perceived-brightness lead); (3) typographic-scale spec (block-footprint % + tier ratios + body measure); (4) left-margin alignment x; (5) layer-stack treatment recipe (bottom-up, blend modes named); (6) mood/stance; (7) copy mapping (theme -> every text slot, engaging copy verbatim).
- **Verify:** `test -f jobs/<slug>/analysis.md && grep -Eic 'palette|typograph|alignment|layer|mood|copy' jobs/<slug>/analysis.md` returns a non-trivial count. NO analysis.md -> STOP, do not ideate.

### G3 - IDEATE
- [ ] `generate.ideate(<measured-style + EXACT copy>, "jobs/<slug>/assets", n=2-3)` on flash, with `variations` giving each a DISTINCT compositional stance.
- [ ] Range check: variants are structurally DIFFERENT (different stance/treatment), not near-identical. If they collapse to the same look, re-ideate with wider `variations`.
- **Verify:** `ls jobs/<slug>/assets/var-*.png` shows n files; confirm by eye they differ in stance.

### G4 - PICK GATE
- [ ] Self-critique EACH candidate: 3-5 situational facet scores (what the piece should make the viewer FEEL) + ONE named specific flaw vs the reference (muddy dark / flat hierarchy / treatment reads as a flat overlay / stray cool neutral / weak focal order), using `design-theory.md` vocabulary.
- [ ] If a candidate's top flaw is fixable, `refine()` or re-ideate it BEFORE showing (generation #1 is a draft).
- [ ] Shadow 4-call: `predict -> log_prediction` (BEFORE showing) -> present refined variants side-by-side vs the reference, each with its facet read + named flaw -> Christopher picks (or edits -> refine/re-ideate).
- [ ] Log `final_pick` + non-empty `why` (the named-flaw language IS the substrate the judge converges against) + `shadow.record_human_pick(...)`. A rejected board -> a `rejection` row (HR-4).
- **Verify:** `tail -1 judge/shadow.jsonl` shows this job+phase with `human_pick` + `agree_top1` filled; `jq -c 'select(.job=="<slug>" and .phase=="final_pick")' ledger/decisions.jsonl | tail -1` shows a non-empty `why`.

### G5 - FINALIZE
- [ ] `generate.finalize("assets/<chosen>.png", generate.FINALIZE_INSTRUCTION, "finals/<slug>-4k.png", aspect=..., size="4K")` -> Nano Banana Pro 4K (~3584px long edge; keeps design + exact copy).
- [ ] **Verify triplet (HR-8)** vs the picked variant AND the reference:
  - copy read-back: open the 4K, read every text string, confirm each matches the analysis copy-mapping VERBATIM;
  - bg/palette sample diff: `for f in refs/ref.* finals/<slug>-4k.png; do echo -n "$f "; magick "$f" -format '%[pixel:p{20,20}]\n' info:; done` and compare;
  - native-scale side-by-side: `magick refs/ref.* finals/<slug>-4k.png +append /tmp/z-cmp.png` then view (montage without resizing).
- [ ] Pro 4K REINTERPRETS. On drift -> `refine()` with a keep-composition instruction, or re-finalize from the picked variant (PB-3). Pixel-identical enlargement is NOT available (no Real-ESRGAN installed) - flag it if truly required.
- **Verify:** `finals/<slug>-4k.png` exists at ~4K; the three checks above pass.

### G6 - CLOSE
- [ ] Deliver at the EXACT preset px (crop/fit if needed; `og_image` -> 1200x630).
- [ ] Ledger completeness assert: `python3 ledger/ledger.py stats` before/after - the job added at minimum `brief` + `reference_pick` + `final_pick`; every non-brief row has a non-empty `why`; any rejected board is a `rejection` row.
- [ ] `python3 judge/shadow.py stats` - confirm this job's shadow events are scored (feeds HR-13 graduation, never self-confidence).
- **Verify:** `jq -c 'select(.job=="<slug>")|{phase,why}' ledger/decisions.jsonl` shows brief + reference_pick + final_pick with non-empty whys; shadow stats `n_scored` increased.

---

## MEASURED-ANALYSIS DISCIPLINE (non-negotiable - every bullet is a paid-for lesson)

Vision perceives semantically and low-res; design is metric -> **MEASURE, do not eyeball.**

- **Palette:** exact hex via `analyze_ref.py`. Catch warm-vs-cool whites, off-black vs pure black, subtle tints (real case: warm-cream `#F2F0EB` vs the true cool off-white `#F3F1F2`, R~=B>G, faint lilac-grey).
- **Color DISCIPLINE, not just hex** - read the palette's *logic*: (1) **One temperature** - is the whole field (neutrals too) warm or cool? A stray cool grey in a warm comp is the commonest tell. (2) **Rich vs muddy darks** - a good dark shifts hue + gains chroma as it deepens, it does NOT fade toward grey. (3) **Restraint** - count the colors actually doing work (often 2-3 + neutrals); excess variance is a generic tell. (4) **Perceived brightness** - equal-value accents do not read equal-weight (a blue reads darker than a yellow-green); note which accent leads the eye (think OKLCH/perceptual lightness, not raw HSL value).
- **Genuine hierarchy is structural, not "big vs small"** - true contrast of **weight AND scale AND family** (a hairline display over a set-sans body, not one font at two sizes). Note family pairing + weight jumps + optical-size shifts, plus the body **measure** (line length). Two sizes one ratio-step apart read flat; capture the actual ratio.
- **Proportion = BLOCK FOOTPRINT + space-fill + line-structure, not a single cap-height ratio.** The eye reads the % of canvas each whole text BLOCK occupies (measure the full multi-line block, not one line), whether zones are filled (no dead voids), and the structural tricks the reference uses to dominate (wrapping a hero word to 4 lines). Reference scales can be extreme: a measured editorial ref ran **~12 : 2.3 : 1** (headline ~10.5%/line, subhead ~2.0%, body ~0.8% fine-print), NOT the 5:2:1 it looked like by feel. Secondary/body text is usually MUCH smaller than you would set by feel - measure it and respect the high contrast.
- **Treatment = an ordered LAYER STACK, not a flat filter.** Decompose the surface bottom-up and name each: base wash / duotone map / halftone (dot or line) / grain (one flat overlay vs two octaves, coarse + fine) / color wash or spot overprint / the blend interaction where layers meet (multiply, screen, overlay, color-dodge, plus-lighter). This recipe is what makes riso/editorial read as crafted, not a 5%-opacity overlay. Record the stack so the prompt can rebuild it.
- **Alignment is measured** - every element's left-edge x (usually one shared margin); inline marker rows (line / number / label) vertically centered on one axis.
- **NEVER trust a measurement without viewing the trimmed crop** (HR-7) - `-threshold -trim` silently returns the crop-box height or catches 2 lines / background. Save the crop and read it back before trusting the px; the default threshold is `78%`, adjust it if the crop is not exactly one line of the right element.
- **Compare sizes at NATIVE scale** - resize both images to one canvas and montage crops **without resizing** (the only reliable size comparison).
- **Verify output vs reference** (sample bg/colors, native-scale side-by-side) before declaring done (this is the G5 triplet).

---

## PROMPT-CRAFT (turn the measured analysis into crafted pixels)

The measured stack is only useful if it lands in the prompt (HR-6). Beyond exact palette + exact copy + composition, state these explicitly so the generator rebuilds the craft, not a generic approximation.

- **Take a compositional stance; do not let the model default.** Name the structure (full-bleed type-poster vs split editorial vs dominant-headline-over-fine-print) and the focal reading order. A stated stance separates a designed comp from "stuff centered on a background".
  - do: "full-bleed type-poster, the hero word wrapped to 4 lines dominating the top 48%, fine-print body sweeping the lower third."
  - do not: "a nice poster layout for the text."
- **Prompt the treatment as composited LAYERS, with intent.** Describe the stack from the analysis and call the blend by name: "duotone-mapped to `#hex`+`#hex`, then a fine halftone dot screen over the midtones, then two grain octaves (coarse + fine) for tooth, spot inks overprinting to a darker multiply where they overlap."
  - do not: "add grain" / "add a texture."
- **Color: discipline in words.** Lock ONE temperature across everything incl. neutrals; ask for **rich darks** ("deep `<hue>` shadows hue-shifted toward `<neighbor>`, gaining saturation, NOT washed-out grey"); keep the working palette restrained (2-3 + neutrals); for gradients ask **eased, perceptually-even** transitions ("smooth blend, no muddy mid-tone, no visible banding/horizon line"). Make the lead accent intentional by perceived brightness.
- **Type: ask for GENUINE hierarchy.** Real contrast of weight + scale + family (name the genre: "hairline high-contrast serif display over a quiet grotesque body"), the extreme ratio the reference uses, and a sane body measure. Never "a bold heading and some text".
- **Depth + light ONLY when the reference reads lit/material** (flat graphics stay flat). One consistent light direction; shadows as a tight CONTACT shadow PLUS a soft ambient falloff (a single floating drop shadow reads fake); name the material + its specular ("matte paper sheen" vs "sharp specular on foil/metal"); prefer natural/worn edges over hard geometric cuts.
- **Micro-detail = the trained-eye finish.** Borders crisp and consistent (no muddy strokes); one icon/glyph style throughout (never mix fill/weight/radius); group related elements by proximity instead of needless dividers/boxes; align everything to the shared margins from the analysis.

> Typography floors (weight >= 500, size >= 12px) and the no-monospace-unless-mono rule are **UI** constraints - they do NOT apply here. On a poster, reference fidelity governs: if the reference uses a hairline display face or tiny fine-print, MATCH it.

## COPY = engaging, themed, mapped

For themed posters, write **engaging** copy mapped to the reference's text slots (Christopher explicitly wants this). Worked examples from real jobs: gambling -> "BROKE" / "One More Hand" / "Know when to fold"; crypto -> "Profit From Chaos" / "Volatility is your edge"; hacker -> "OVERRIDE" / "Are you really alone?". Keep names/placeholders swappable. **No em/en dashes** in any copy or in any message surfaced to Toper (house style - use hyphens, colons, or restructure).

---

## LEDGER + SHADOW JUDGE (the instrumentation that must actually accrue)

The ledger is the taste substrate; the shadow judge predicts Christopher's pick behind the human gate and is scored against it. Both are ENFORCED at the gates above (G1/G4 shadow sequence, G0/G6 completeness), not merely encouraged - because historically they leaked: `judge/shadow.jsonl` did not exist (zero live predictions since the 2026-06-16 build) and the ledger had 0 rejection rows + 1 empty-`why` edit row + 3 of 7 jobs missing a `reference_pick`. The gates exist to stop that recurring.

- **Ledger:** `ledger.log_decision(...)` per decision; `why` is the highest-value field (HR-4). Phases `brief / reference_pick / final_pick / edit / rejection`.
- **Shadow:** the 4-call sequence per gate (recipe above). It NEVER decides - it guesses, Christopher decides, agreement is logged.
- **KEY LEARNING (HR-13):** the judge's self-reported confidence is unreliable (Sonnet anchors ~72% regardless). The autonomy gate keys off **measured per-facet agreement track-record**, NOT self-confidence.
- **Seed baseline:** 66.7% top1 / 33% exact on the 2026-06-16 seed backtest (`judge/backtest.py`, NOT held-out - directional only; the profile was seeded partly from those same `why`s).

Full schema, the log_decision/shadow recipes, graduation criteria, and the dream-consolidation outline: **`references/ledger-and-judge.md`.**

## BUDGET GUARD (verified economics - stop the grind)

Verified 2026-06-16: flash `gemini-2.5-flash-image` **$0.039/img**; Pro `gemini-3-pro-image` **$0.134/img at 1K/2K, $0.24/img at 4K**. A finished multi-round job runs **$0.30-1.00**; the entire 7-job test phase (~100 images incl. a ~15-round Satori crypto grind) was ~$2.80.

**Trip-wire:** more than ~6 Pro calls OR ~$3 in one job = grind smell. STOP re-rolling and RETURN to G2 to re-measure - the fix is almost always a missed measurement (a wrong body size, a mis-read temperature), not another generation. The 15-round crypto grind is the canonical failure; it was a measurement problem, not a prompt-luck problem.

## SATORI = the print shop, NOT the designer

`render_satori.mjs` is demoted to **programmatic templating only**: stamping the SAME fixed layout N-times with swapped data/copy (price-card per product, personalized poster per user, exact brand-spec template). That is data->layout at scale, a different job than reference->art. Gemini Pro keeps exact copy AND handles precise type in one shot; the one Satori-exact poster cost ~15 grinding rounds for a result Pro reaches in one. **Mental model: Gemini Pro = the designer, Satori = the print shop.** Never route reference-driven creative through Satori (HR-5). When templating genuinely qualifies: **`references/satori-templating.md`.**

## AUTONOMY ROADMAP (earned, not switched)

Instrument (DONE - ledger) -> seed taste profile (DONE - `judge/profile.json`) -> shadow-mode judge (BUILT; must now actually accrue via the enforced G1/G4 sequence) -> **graduated per-facet autonomy** once *measured* agreement clears `>=85%` over `>=10` events (HR-13; low-agreement facets escalate, hard brand/quality rules auto-reject) -> scheduled **"dream"** consolidation regenerating the taste profile + craft playbook from accumulated shadow data (recency-weighted + small exploration budget, because taste is a moving target). Until earned, Christopher picks the gates.

---

## FAILURE PLAYBOOK (PB-1 .. PB-7)

- **PB-1 - Browser sourcing fails.** Consult the agent-browser skill jump table FIRST. Daemon flaky / exit 144 -> Mode B direct WebSocket on the qutebrowser CDP (2262). CDP screenshot timeout on a heavy page -> `qb-shoot`. NEVER restart qutebrowser itself. Details + the manual `/claim` recipe: `references/reference-sourcing.md`.
- **PB-2 - Flash garbles or rewrites text at ideate.** Restate the EXACT copy in quotes in the prompt and re-ideate. Remember Pro keeps supplied copy verbatim at finalize, so garbled ideate text is pick-stage noise unless the composition depends on that exact wording.
- **PB-3 - Pro 4K drifted the design.** `refine()` the 4K output with a keep-composition instruction, or re-run `finalize()` from the picked variant. If pixel-identical enlargement is genuinely required, FLAG it: no true upscaler (Real-ESRGAN) is installed; ImageMagick upscale is interpolation only (HR-5).
- **PB-4 - Measurement looks wrong.** Threshold-trim silently lies (HR-7). Save the crop, VIEW it, adjust the threshold (default `78%`), re-measure. Never build N iterations on an unviewed number (the crypto body-size failure).
- **PB-5 - Light object on a light background knockout.** Floodfill-from-corners bleeds through highlights and fragments the object. Instead: generate the object on PURE BLACK, then `imageutil.alpha_knockout(src, out, level="4%,30%")` (luminance knockout; the code default `3%,22%` suits a near-black bg, ~`4%,30%` suits a light object on black), then `composite_over` onto the light background.
- **PB-6 - Gemini 503/429.** `gemini.py` retries transients with backoff automatically (4 tries). If it still fails, wait and rerun; do NOT switch models mid-job.
- **PB-7 - Output reads muddy or generic.** Re-prompt with the color-discipline lines: one temperature everywhere incl. neutrals; rich darks that hue-shift and gain chroma (not grey); 2-3 working colors; eased perceptually-even gradients, no banding.

## REFERENCE FILES (progressive disclosure)

- `references/reference-sourcing.md` - agent-browser-deferred sourcing, the extraction JS as a manual snippet, download/dedupe/full-size vetting, the curation-gate worked example, the `source_refs.py` STALE warning.
- `references/satori-templating.md` - when templating qualifies + the exact Satori/Fontshare/ImageMagick recipes and gotchas.
- `references/ledger-and-judge.md` - ledger schema, the log_decision + shadow recipes, agreement-based graduation, the seed-backtest caveat, unit economics, the dream outline.
- `design-theory.md` (this dir) - the 35-principle vocabulary source; read it at G2 (analysis) and G4 (naming flaws).
- `brand-kit-template.json` (this dir) - the optional brand-facet input shape captured at G0.
