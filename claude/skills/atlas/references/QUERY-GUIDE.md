# /atlas dossier QUERY GUIDE (the read-side cookbook)

Executable recipes for every consumer of an /atlas dossier. **Every recipe below was RUN and verified against the real `dossiers/pulse/` (61 surfaces, 2 flows, merged manifest) on 2026-07-02**; output shapes shown are real. Run them from the dossier dir (`cd ~/.claude/skills/atlas/dossiers/<slug>`). All recipes are read-only.

**Two rules before any query:**

1. **R0 first, always.** Check freshness before trusting a single screenshot or selector. A STALE dossier's pixels and selectors are suspect (Pulse deploys continuously via Watchtower/GHCR).
2. **Parse defensively.** The pulse dossier has 23 distinct surface key-set variants, one role/action-swapped element, and 8 dangling screenshot refs (SCHEMA.md Appendix L3/L5/L6). Use `(.field // default)` everywhere, and stat every screenshot path before use.

---

## R0. Freshness check (BEFORE TRUST, every consumer)

```bash
bash ~/.claude/skills/atlas/scripts/atlas-freshness.sh .    # verdict + per-bucket counts
```

Inline equivalent (list ages; bucket by 11.2: fresh < 50% ttl, aging 50-100%, stale > ttl):

```bash
for f in surfaces/*.json; do
  jq -r '[.id, (.freshness.captured_at // "MISSING"), ((.freshness.ttl_days // 14)|tostring)] | @tsv' "$f"
done
```

Pulse reality: everything captured 2026-06-22 with ttl_days 14, so the whole dossier goes STALE on 2026-07-06. After that date: attach a staleness disclaimer to any handoff, and prefer triggering a refresh pass (SKILL 11.2) over consuming rotten screenshots.

## R1. QA matrix: every mutator element with its skip/exercise status

```bash
jq -r '.id as $s | (.elements // [])[] | select(.action=="mutator")
       | [$s, .id, (.skip_reason // ("exercised=" + ((.exercised // false)|tostring)))] | @tsv' surfaces/*.json
```

Verified output shape: `catalog-products-category-dialog-delete  catalog-products.category-dialog-delete.confirm  avoid deletion of test artifact`. Drift note (L6): to catch swapped elements, ALSO run with `select(.role=="mutator" or .role=="mutator-local")`.

## R2. Docs/QA: every error + empty state with its screenshot

```bash
jq -r '.id as $s | (.states // [])[] | select(.kind=="error" or .kind=="empty")
       | [$s, .id, (.screenshot // "NULL")] | @tsv' surfaces/*.json
```

Then stat each path (8 legacy refs dangle): `while IFS=$'\t' read -r s id p; do [ "$p" = NULL ] || [ -f "$p" ] || echo "DANGLING: $s -> $p"; done`.

## R3. Keyboard shortcut inventory (QA: test them; docs: document them)

```bash
jq -r '.id as $s | (.elements // [])[] | select(.keyboard_shortcut != null)
       | [$s, .keyboard_shortcut, .label] | @tsv' surfaces/*.json
```

Verified on pulse: 5 rows, all POS (`F1` search, `F2` hold, `F4` cash drawer, `F8` orders, `F9` pay).

## R4. QA gap seed: unobserved states by module

```bash
jq -r '.coverage.state.unobserved[]' manifest.json
```

Verified: 48 named entries, each with its reason (`[customers] customers-list@inactive-status (no Inactive customers in tenant data: detected-but-not-observed)`). These are the states QA must MANUFACTURE data for; the reasons say exactly what data is missing.

## R5. Docs: ordered flow steps with screenshots

```bash
jq -r '.steps[] | [(.n|tostring), .action, (.screenshot // "NULL")] | @tsv' flows/pos-checkout-cash.json
```

Filing-gap note (L10): pulse has ONE unfiled flow (`stock-receive-via-po`, 7 steps) living in `manifest.partial.inventory.json` `flows_captured`, flagged in manifest `gaps[]`. Flow consumers read `flows/*.json` PLUS `jq '.gaps[]' manifest.json`.

## R6. Pitch-deck: surfaces ranked by neutral signals (consumer does the scoring)

```bash
jq -r '[.id, (.signals.wow_potential.rating_0_5 // 0), (.signals.visual_richness.rating_0_5 // 0),
        ((.screenshots // {}) | length)] | @tsv' surfaces/*.json | sort -t$'\t' -k2,2nr -k3,3nr
```

N1 reminder: the ratings are descriptive with raw facts beside them; the RANKING here is the consumer's own curation step, which is exactly where it belongs.

## R7. Per-module screenshot set (deck/docs asset pull)

```bash
jq -r 'select(.module=="pos-terminal") | (.screenshots // {}) | to_entries[] | .value' surfaces/*.json | sort -u
```

Stat every path before copying (L3/L4: module-prefixed legacy names, dangling refs, `-full` variants that JSON may not reference).

## R8. /copywriting + QA: locale gaps + real observed numbers

```bash
jq -r 'select(.gaps != null) | .id as $s | .gaps[] | select(.severity=="i18n") | [$s, .what] | @tsv' surfaces/*.json
jq -r '[.id, (.data_observed | tostring | .[0:120])] | @tsv' surfaces/*.json    # falsifiable proof numbers
```

Plus the dossier-level i18n finding: `jq -r '.gaps[] | select(.severity=="i18n") | .what' manifest.json` (pulse: mixed id/en + 3 coexisting date formats).

## R9. Integrity self-check (what critic check 7 runs; consumers can re-run anytime)

```bash
python3 - <<'EOF'
import re, os, glob
refs = set()
pat = re.compile(r'screenshots/[A-Za-z0-9._-]+\.png')
for f in glob.glob('surfaces/*.json') + glob.glob('flows/*.json') + glob.glob('modules/*.json') \
         + ['manifest.json','product.json'] + glob.glob('manifest.partial.*.json'):
    refs.update(pat.findall(open(f).read()))
disk = {'screenshots/'+x for x in os.listdir('screenshots') if x.endswith('.png')}
print("dangling:", sorted(refs - disk))
print("unreferenced:", len(disk - refs))
EOF
```

Verified pulse output: 8 dangling, 38 unreferenced (SCHEMA.md L3). A v1.2 dossier must print `dangling: []`.

## R10. Stale-surface report (which surfaces to refresh first)

```bash
bash ~/.claude/skills/atlas/scripts/atlas-freshness.sh . --list-stale
```

Inline: R0's listing piped through an age filter. Refresh ONLY the stale surfaces (targeted re-capture, SKILL 11.2), not the whole dossier.

## R11. Resume reconstruction (for /atlas itself; here for completeness)

The visited-set recipe (journal fold UNION disk) lives in SKILL.md 11.1. Verified 2026-07-02: the fold yields 54 raw entries of which only 44 match disk surface ids; 17 of the 61 disk surfaces have no journal evidence at all; the union is complete.

---

## Drift tolerances a parser MUST carry (summary; full table SCHEMA.md Appendix)

- `(.field // default)` on EVERY optional field: 23 key-set variants exist (L5).
- Stat every screenshot path; treat a dangling ref as `screenshot: null` (L3).
- `action` classification queries also check `role` for action-class values (L6, the `pos.clear-cart` swap).
- Trust merged `manifest.json` counts over `manifest.partial.*` counts (L7: the customers partial is stale, 26 vs 34).
- `capture.mutations` may be an array of objects (manifest) or a prose string (legacy partials); artifact listing filters on the `ATLAS-` prefix (L8).
- Role strings drift (`owner`/`ADMIN`/`ADMIN (owner)`): normalize case-insensitively (L9).
- Absent `schema_version` on a pulse file means v1.1 legacy (L11).
- Capture-block tenant key drifts: the merged manifest carries v1.2's `tenants` (array), but legacy partials use scalar `tenant` (a string) and two partials have no `capture` block at all. Tolerant read: `[.capture.tenants // .capture.tenant // []] | flatten` (L13).
