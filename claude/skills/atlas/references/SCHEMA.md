# /atlas dossier schema: normative spec (v1.2)

This file is the NORMATIVE schema for every file an /atlas run writes. SKILL.md Section 10 carries compact worked examples; when they and this file disagree, THIS file wins. The appendix at the bottom documents how the real `dossiers/pulse/` (captured 2026-06-22, schema_version 1.1) deviates: those files are IMMUTABLE legacy evidence, never edited to fit v1.2; parsers tolerate the documented deviations.

**Versioning policy (hard):** schema changes are FORWARD-ONLY via `schema_version`. A new run writes v1.2 files next to legacy files. NEVER modify, regenerate, rename, or reformat an existing dossier data file to fit a newer schema. NEVER renumber or repurpose an existing field.

---

## 1. On-disk layout

```
dossiers/<product-slug>/
  manifest.json                      # REQUIRED merged coverage ledger (one per dossier)
  manifest.partial.<module>.json     # one per fan-out worker; kept post-merge as audit evidence
  product.json                       # REQUIRED product identity
  capture-config.json                # OPTIONAL invocation defaults (Section 8)
  modules/<module-id>.json
  surfaces/<surface-id>.json
  flows/<flow-id>.json
  screenshots/<surface-id>__<state>[-full].png
  screenshots/_archive/<YYYY-MM-DD>/ # superseded shots (moved, never deleted)
  capture-log.jsonl                  # main journal
  capture-log.<module>.jsonl         # per-worker journal, same vocabulary
```

Slug rules: lowercase, hyphens, no spaces (`pulse`, `competitor-x`).

### Screenshot naming grammar (N16)

```
<surface-id>__<state>[-full].png
```

- `<surface-id>` = the surface JSON's `id`, exactly (NOT the module name, NOT an improvised prefix).
- `<state>` = the state's short name (`empty-cart`, `filled`, `validation-error`).
- `-full` suffix = full-page (`--full`) variant; only where full-page context matters.
- Every path written into JSON is stat-verified in the same step (write-then-stat).
- Ad-hoc names are BANNED going forward. Legacy exceptions in pulse: `pos-terminal__*` prefix for surface `pos-register`, `00-portal-launcher.png` (see Appendix).

---

## 2. Closed enums

| Enum | Values | Notes |
|---|---|---|
| `elements[].action` | `navigate` \| `expander` \| `mutator` \| `mutator-local` \| `control` \| `export-external` | SKILL.md Section 6. Exactly one per element. |
| `states[].kind` | `filled` \| `empty` \| `error` \| `loading` \| `precondition-gate` \| `variant` \| `permission-denied` | SKILL.md Section 8.1. |
| `surface.type` | `page` \| `tab` \| `modal` \| `drawer` \| `panel` \| `dialog` | the L1/L2 shape of the surface |
| `elements[].role` | an ARIA role string from the a11y snapshot (`button`, `link`, `searchbox`, `combobox`, `tab`, `application`, ...) | NEVER an action-class value; `role` describes what the a11y tree says, `action` describes what /atlas does with it |
| `elements[].confirmation_required` | `true` \| `false` \| `"unknown"` | `"unknown"` = no guard evidence and no probe performed (N13) |
| `capture_role` | lowercase invocation enum: `owner` \| `staff` \| `viewer` \| `admin` \| ... (the `--role` value) | UI badge text goes in `role_label_observed`, free-form |
| manifest target status | `unexplored` \| `in-progress` \| `captured` \| `skipped` \| `blocked` | Section 9 lifecycle |
| freshness bucket | `fresh` \| `aging` \| `stale` | Section 11.2 scoring |

---

## 3. Journal event vocabulary (N15)

Every `capture-log*.jsonl` line: one JSON object, `"event"` key from THIS table, plus `ts` (ISO-8601 with offset) and `run_id` (`<slug>-<YYYYMMDD>-<letter>`, e.g. `pulse-20260706-a`). No other event names. No `action`- or `type`-keyed lines.

| event | required fields (beyond ts, run_id) | optional fields | semantics |
|---|---|---|---|
| `seed` | `targets` (array) | `module` | frontier (re)seeded |
| `in-progress` | `target` | `surface` | capture of a target started |
| `captured` | `target`, `surface`, `screenshots` (int), `states` (int) | `elements` (int) | the ONLY event that marks a surface done; emitted AFTER the surface JSON + screenshots are written and stat-verified |
| `skipped` | `target`, `reason` | `module` | intentional non-capture, auditable |
| `blocked` | `target`, `reason` | `module` | could not capture (auth wall, broken page, native picker, upload) |
| `mutation` | `tenant`, `module`, `artifact`, `reversible` (bool) | `id` | appended BEFORE the mutation commits (ledger-before-mutate, SKILL 7.1); `artifact` carries the `ATLAS-` name |
| `incident` | `target`, `what` | `recovered` (bool) | something with real-world effect went wrong (e.g. the 2026-06-22 owner suspend) |
| `friction` | `detail` | `category` | a tooling lesson to fold back into SKILL.md 13.3 |
| `critic` | `structural_pct`, `state_pct` | per-check results | end-pass outcome |
| `resume` | `resumed_from` (int), `first_incomplete` | | emitted on every resume (SKILL 11.1) |

Lint (critic check 10): every line of the CURRENT run (matched by `run_id`) parses as JSON, has a vocabulary `event`, has the event's required fields. Legacy lines without `run_id` are exempt from the lint but folded into resume evidence.

---

## 4. product.json (v1.2)

| Field | Type | Req | Notes |
|---|---|---|---|
| `schema_version` | string | yes | `"1.2"` |
| `product` | string | yes | the slug |
| `name` | string | yes | display name |
| `base_url` | string | yes | |
| `captured_at` | ISO ts | yes | last full/partial run touch |
| `capture_role` | enum | yes | lowercase invocation role |
| `role_label_observed` | string | no | UI badge text (e.g. `ADMIN`) |
| `capture_tenant` | string | yes | tenant name as recorded |
| `auth_model` | object | yes | `{type, multi_tenant, tenant_select, session, post_login_split?}`; DESCRIPTIVE prose only, never header/cookie VALUES (N14) |
| `tech_signals` | object | yes | `{framework, i18n[], locale_observed, themes[], theme_toggle_present?, keyboard_shortcuts?, app_version, app_version_fallback}` |
| `tech_signals.app_version_fallback` | string | no | sha256 of the main JS asset URL (headers stripped) when no footer build hash exists; the dossier-wide staleness signal |
| `module_index` | string[] | yes | all modules discovered |
| `modules_captured` | string[] | no | subset actually captured |

## 5. modules/<id>.json (v1.2)

| Field | Type | Req |
|---|---|---|
| `id`, `name`, `nav_path`, `purpose` | string | yes |
| `role_visibility` | string[] | no |
| `surfaces` | string[] | yes (surface ids) |
| `flows` | string[] | no (flow ids) |

## 6. surfaces/<id>.json (v1.2, the workhorse)

| Field | Type | Req | Notes |
|---|---|---|---|
| `schema_version` | string | yes | `"1.2"` |
| `id` | string | yes | matches filename minus `.json` |
| `module` | string | yes | owning module id |
| `type` | enum | yes | Section 2 |
| `route`, `route_template` | string | yes | template has params as `:id` (N8) |
| `title` | string | yes | |
| `parent_surface` | string | no | |
| `entry_preconditions` | string[] | no | R1 |
| `locale_observed` | string | yes | R6 |
| `what_it_is`, `what_it_does` | string | yes | neutral prose, no verdicts (N1) |
| `instance_note` | string | no | data-instance templates only (N8) |
| `screenshots` | object | yes | state-name -> grammar-named path; every path stat-verified (N16) |
| `states` | object[] | yes | each: `{id, kind, how_reached, screenshot|null, message?, notes?, fields_present?, fields_absent_vs_<ref>?, fields_extra_vs_<ref>?}` (R5) |
| `elements` | object[] | yes | each: `{id, label, role, action, target?, keyboard_shortcut?, confirmation_required?, exercised, result_state?, skip_reason?, options?, notes?}` |
| `data_observed` | object | yes | real on-screen values; NEVER credentials/tokens (N14) |
| `perf` | object | no | `{doc_dom_content_loaded_ms, doc_load_complete_ms, response_end_ms?, transfer_size_bytes}` |
| `gaps` | object[] | no | `{severity, what, evidence?}`; REQUIRED companion when `fingerprint` is null or `screenshot` is null |
| `signals` | object | yes | `visual_richness` / `demo_ability` / `wow_potential`, each: raw facts + `rating_0_5` beside them (N2) |
| `freshness` | object | yes | `{captured_at, fingerprint, ttl_days}` |
| `freshness.fingerprint` | string\|null | yes | `sha256:` + 64 hex from the SKILL 11.3 recipe, or `null` + a `gaps[]` entry. Placeholders and hand-typed labels are critic FAILs (check 9) |

## 7. flows/<id>.json (v1.2)

| Field | Type | Req |
|---|---|---|
| `id`, `name`, `goal`, `entry_point`, `outcome` | string | yes |
| `real_data_used` | string | no |
| `mutation_tier` | string | yes (which tier the terminal step ran under) |
| `steps` | object[] | yes: `{n, action, surface, element?, screenshot|null, observed_result}` |
| `signals` | object | no (same N2 shape) |

Every filed flow lives in `flows/`; documenting a flow ONLY inside a partial manifest is a filing gap (record it in manifest `gaps[]`, like pulse's `stock-receive-via-po`).

## 8. capture-config.json (v1.2, optional, per product)

```json
{
  "base_url": "https://app.pulse.aenoxa.com",
  "roles": ["owner", "staff"],
  "tenants": ["Alamanda Coffee"],
  "test_tenant": "Alamanda Coffee",
  "creds_pointer": "PULSE_TEST_* in ~/.claude/secrets.env"
}
```

`creds_pointer` is an env-var NAME or file path, NEVER a credential value (N14). This file seeds invocation defaults; explicit flags override it.

## 9. manifest.json (v1.2)

| Field | Type | Req | Notes |
|---|---|---|---|
| `product`, `schema_version`, `scope` | string | yes | |
| `coverage.structural` | object | yes | `modules` / `surfaces` / `elements`, each with discovered/captured/unexplored/blocked counts + pct + lists |
| `coverage.state` | object | yes | `{observed, detected_possible, pct, observed_list?, unobserved[]}`; unobserved entries are NAMED with reasons (N3) |
| `coverage.skipped` / `coverage.blocked` | object[] | yes | `{module?, target, reason}` |
| `per_module` | object | no | per-module surface/state/element counts + surface lists |
| `modules` | string[] | yes | |
| `capture` | object | yes | `{run_id, started, finished, role, tenants[], tool, parallelization?, mutations[], atlas_artifacts_visible_in?[]}` |
| `capture.mutations` | object[] | yes | `{tenant, module, artifact}` array-of-objects; `[]` + note on read-only runs. NEVER a bare string |
| `orphan_screenshots` | string[] | yes (may be empty) | on-disk-but-unreferenced files, enumerated by critic check 7 |
| `cross_refs` | object[] | no | `{assertion, observed, consistent, module?, notes?}` (R7) |
| `gaps` | object[] | no | dossier-level gaps (filing gaps, i18n findings, UX observations) |
| `critic` | object | yes | per-check results of the 10-check critic |
| `freshness_report` | object | yes | `{verdict, fresh, aging, stale, computed_at}` (SKILL 11.2) |

## 10. manifest.partial.<module>.json (v1.2, the FIXED fan-out shape)

The merge agent VALIDATES every partial against this shape before folding. A partial that fails validation blocks the merge (fix the worker output, never hand-reconcile silently).

| Field | Type | Req |
|---|---|---|
| `schema_version` | string | yes (`"1.2"`) |
| `module` | string | yes |
| `run_id` | string | yes |
| `surfaces` | string[] | yes (surface ids owned by this worker) |
| `elements_classified` | int | yes (MUST equal the sum over this module's surface files; the merge recounts) |
| `states_observed` | int | yes (same recount rule) |
| `coverage` | object | yes: `{structural_pct, state_pct, unobserved[]}` |
| `skipped`, `blocked` | object[] | yes (may be empty) |
| `mutations` | object[] | yes: `{tenant, module, artifact}` (may be empty) |
| `frictions` | string[] | yes (may be empty; the merge promotes them to `friction` journal events) |
| `screenshot_count` | int | yes |
| `captured_at`, `capture_role`, `worker` | string | yes |

Per-module journal: `capture-log.<module>.jsonl`, same Section 3 vocabulary, same `run_id`.

---

## Appendix: observed v1.1 legacy deviations (dossiers/pulse, captured 2026-06-22; verified on disk 2026-07-02)

The pulse dossier is IMMUTABLE evidence. Consumers and future runs parse it AS-IS with these tolerances. Do not "fix" any of it.

| # | Deviation | Measured reality | Parser tolerance |
|---|---|---|---|
| L1 | **Journal dialects** | 505 lines across 10 jsonl files; 293 event-keyed (30 distinct kinds incl. both `captured` x70 and `surface_captured` x8, plus `session_start`, `crawl_start`, `navigate`, `screenshot`, `snapshot`, `dialog_open`, `tab_click`, `flow_captured`, `crawl_end`...), 191 `action`-keyed (no `event` field at all, e.g. capture-log.inventory.jsonl), 21 `type`-keyed (e.g. the POS worker's friction notes). 0 unparseable. No `run_id` anywhere | resume folds all three dialects (SKILL 11.1); journals alone reconstruct only 54/61 surfaces, so disk union is mandatory |
| L2 | **Fingerprints** | 61 surfaces: 35 have NO `fingerprint` field, 5 carry the placeholder `structural-hash-pending`, 21 carry hand-typed labels (`analytics-customers-v1`, `sha256:dashboard-main-v1-initial`). ZERO real hashes | treat every legacy fingerprint as ABSENT; the first refresh pass baselines (SKILL 11.2) |
| L3 | **Screenshot referential integrity** | 131 referenced paths (regex extraction), 8 dangling (`pos-terminal__register-filled.png` referenced by pos-register.json AND flows/pos-checkout-cash.json step 2; `inventory-bulk-import__step{2,3,4}.png`; 4 inventory-receiving refs whose on-disk names differ), 38 on-disk files unreferenced (mostly `-full` variants + dialog shots) | consumers stat every path before use; treat a dangling ref as `screenshot: null` |
| L4 | **Screenshot naming** | module-prefixed names (`pos-terminal__*` for surface `pos-register`), 10 `-full` variants, `00-portal-launcher.png` outside any grammar | join JSON->disk via the recorded path string, never by reconstructing the grammar |
| L5 | **Surface key-set drift** | 23 distinct top-level key-set variants across the 61 surface files (ad-hoc fields: `breadcrumb`, `locale_gaps`, `skill_friction` at differing levels; some files carry `schema_version`, some do not) | parse defensively: `(.field // default)` on every optional; never assume a fixed key set |
| L6 | **role/action swap** | `pos-register.json` element `pos.clear-cart` has `"role":"mutator-local","action":"expander"` (swapped vs the schema) | when classifying-by-action, ALSO check whether `role` holds an action-class value |
| L7 | **Partial manifest shapes** | two incompatible ad-hoc shapes: inventory-style `{namespace, module_file, surface_files, screenshot_count, skill_friction_log, mutations_committed, flows_captured}` vs customers-style `{module, schema_version, capture{}, coverage{}, screenshots{}, cross_refs, locale_gaps}`; customers partial says 26 elements, its 5 surface files contain 34 (the partial is stale; the MERGED manifest totals match disk: 384 elements, 147 states, verified) | trust the merged manifest.json numbers, not the partials; partials are audit evidence only |
| L8 | **mutations shape** | manifest: array-of-objects `{tenant, module, artifact}` (v1.2 adopted this); customers partial: prose string; one manifest entry is an INCIDENT record, not an artifact | when listing artifacts, filter entries whose artifact starts with `ATLAS-` |
| L9 | **role labels** | `owner` / `ADMIN` / `ADMIN (owner)` drift across partials, manifest, product.json | normalize case-insensitively; v1.2 splits `capture_role` vs `role_label_observed` |
| L10 | **flow filing** | inventory's 7-step `stock-receive-via-po` flow exists ONLY inside manifest.partial.inventory.json, not in `flows/` (recorded as a manifest gap) | flow consumers read `flows/*.json` PLUS manifest `gaps[]` for filing gaps |
| L11 | **schema_version placement** | product.json + some surfaces say `"1.1"`; many surface files omit the field entirely | absent `schema_version` on a pulse file means v1.1 legacy |
| L12 | **Secrets** | full-tree sweep 2026-07-02: CLEAN (no JWTs, no header values, no set-cookie, no password/token/secret/api_key values; the single `cookie` match is descriptive prose in product.json `auth_model.session`) | nothing to tolerate; N14 keeps it that way |
| L13 | **capture-block tenant key drift** | the merged manifest.json already carries v1.2's `tenants` (array) + `role`; the six event-style legacy partials (analytics, catalog-products, customers, dashboard, settings, staff) use scalar `tenant` (a string) + `role`, the inventory + sales-state-topup partials have no `capture` block at all (their L7 ad-hoc shapes), and the smoke-test dossier manifest also uses scalar `tenant` (all verified on disk 2026-07-02) | read tenants tolerantly: `[.capture.tenants // .capture.tenant // []] \| flatten` (verified on all three shapes, jq 1.8.1, 2026-07-02); a bare `.capture.tenants` read returns null on every legacy partial |
