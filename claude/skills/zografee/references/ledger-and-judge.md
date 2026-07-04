# zografee ledger + shadow judge (instrumentation depth)

The ledger is the taste substrate; the shadow judge predicts Christopher's pick behind the human gate and is scored against it. Both are ENFORCED at the SKILL gates (G1/G4 shadow sequence, G0/G6 completeness) precisely because they leaked historically: `judge/shadow.jsonl` did not exist (zero live predictions since the 2026-06-16 build), and the ledger had 0 rejection rows, 1 empty-`why` edit row, and 3 of 7 jobs missing a `reference_pick`. Gates apply FORWARD only; never backfill or edit existing rows (HR-16).

## Decision ledger

Canonical schema: `~/claude/Git/repositories/zografee/ledger/schema.md`. One JSON object per line in `ledger/decisions.jsonl`. Fields: `ts, job, content_type, phase, facets, brief, candidates, chosen, why, rejected, notes, decided_by`.

- **Phases:** `brief` | `reference_pick` | `final_pick` | `edit` | `rejection`.
- **`why` is the highest-value field** (the convergence signal) - never empty on any non-brief row (HR-4).
- **`facets`** = `{content_type, brand, audience, platform, style_tags[]}` - taste is FACETED by context, not global.
- **`rejected`** = ids explicitly rejected (hard negatives). A whole rejected board -> a `rejection` row.
- **`decided_by`** = `human` now -> `judge` (shadow) -> `judge_auto` (autonomous, once graduated).

Full call (first three args positional, rest keyword-only):
```python
ledger.log_decision(
    "<slug>", "<content_type>", "reference_pick",
    brief="<request as given>",
    facets={"content_type": "<ct>", "brand": "<...>", "audience": "<...>",
            "platform": "<preset>", "style_tags": ["<...>"]},
    candidates=[{"id": "cand-1", "descriptor": "..."}, {"id": "cand-2", "descriptor": "..."}],
    chosen="cand-1", why="<specific reason>", rejected=["cand-3", "cand-4", "cand-5"],
    job_dir="<absolute job dir>")   # job_dir mirrors the row into jobs/<slug>/decisions.jsonl (best-effort)
```

Read/inspect (read-only):
```bash
python3 ~/claude/Git/repositories/zografee/ledger/ledger.py stats   # {total, by_phase, by_content_type, picks_with_why}
jq -c 'select(.job=="<slug>")|{phase,chosen,why}' ledger/decisions.jsonl
```

## Shadow taste judge

`judge/shadow.py` (model `claude-sonnet-4-6`, the eval model per infra policy; Anthropic key from `ANTHROPIC_API_KEY` env then `~/.claude/secrets.env` - never echo it). It applies HIS seeded profile (`judge/profile.json`) and only ever GUESSES; the human still decides. Candidate images are downscaled to max side 1024 for token economy. Log is `judge/shadow.jsonl`.

**The 4-call sequence per gate (candidates are `{id, path}`, NOT the ledger `{id, descriptor}` shape):**
```python
cand = [{"id": "var-A", "path": ".../assets/var-A.png"}, {"id": "var-B", "path": ".../assets/var-B.png"}]
verdict = shadow.predict(cand, facets={"content_type": "<ct>"}, brief="<brief>", ref_path=".../refs/ref.png")
#   -> {predicted, tie, confidence, ranking, why}
shadow.log_prediction("<slug>", "<phase>", {"content_type": "<ct>"}, cand, verdict, brief="<brief>")  # human_pick=None
#   ... present board, Christopher picks ...
shadow.record_human_pick("<slug>", "<phase>", "var-A")   # fills agree_top1 + agree_exact on the open row
```
Verify after the pick: `tail -1 judge/shadow.jsonl` shows this job+phase with `human_pick` and `agree_top1` filled. Inspect the metric:
```bash
python3 ~/claude/Git/repositories/zografee/judge/shadow.py stats
#   {n_scored, top1_pct, exact_pct, by_content_type:{ct:{n,top1_pct,exact_pct}}, by_phase:{...}}
```

`agree_top1` = the judge's primary pick is among what Christopher chose; `agree_exact` = the sets match (handles ties). The profile allows a TIE as a valid prediction (P8) - two variants that both fully satisfy P1-P3 often means he likes both.

## Graduation criteria (autonomy is EARNED)

- **Graduate a facet to autonomy ONLY on measured per-facet agreement `>=85%` over `>=10` real shadow events** (`by_content_type[ct].top1_pct` in `shadow.py stats`).
- **NEVER graduate on the judge's self-reported `confidence`** (HR-13): Sonnet anchors ~72% regardless of the real margin; prompt-calibration barely moved it. Confidence is logged but is NOT the gate.
- Below the bar -> escalate to Christopher. Hard brand/quality rules (garbled copy, wrong dimensions, off-palette, visibly low fidelity - profile P9) auto-reject regardless of the judge.

## Seed backtest caveat (do not over-trust the number)

`judge/backtest.py` replays the seeded judge on 6 historical picks (hand-mapped from the ledger to on-disk candidate images): **66.7% top1 / 33% exact.** It is **NOT held-out** - the profile was seeded partly from those same `why` fields, so this is a sanity check that the generalized principles reproduce the picks, not a clean metric. The trustworthy number comes from FUTURE jobs accumulating in shadow (which is exactly why the G1/G4 sequence must actually run). Rows where Christopher rejected the whole board and supplied his own reference are skipped (out-of-band, unpredictable from images).

```bash
python3 ~/claude/Git/repositories/zografee/judge/backtest.py   # replays; prints per-event + top1/exact
```

## Unit economics (verified 2026-06-16 via Cloud billing)

| Model | Rate | Use |
|---|---|---|
| `gemini-2.5-flash-image` | $0.039 / img | ideation variants (G3) |
| `gemini-3-pro-image` | $0.134 / img at 1K/2K | (not the default final size) |
| `gemini-3-pro-image` | $0.24 / img at 4K | the final (G5) |

A finished multi-round job runs **$0.30-1.00**; the entire 7-job test phase (~100 images, incl. a ~15-round Satori crypto grind) was ~$2.80. **Budget trip-wire (SKILL): >~6 Pro calls or >~$3 in one job = grind smell -> STOP re-rolling, RETURN to G2 and re-measure.** No free tier; billed in IDR behind the `AIza...` Gemini key.

## Dream consolidation (Step 5, future - not manual)

A scheduled pass will read accumulated shadow data + the ledger and REGENERATE `profile.json` (the faceted taste profile) + a craft playbook: recency-weighted (taste drifts) with a small exploration budget (occasionally offer off-distribution options to detect when his taste moved, so the judge does not become a yes-man echo of past-him). This regeneration belongs to the dream loop, NOT to manual edits - the skill only ever APPENDS forward via the engine APIs (HR-16).
