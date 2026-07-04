---
name: atlas
description: "Exhaustively explores, documents, and screenshots EVERY feature / page / subpage / tab / modal / button / state / flow of a product, producing a complete, structured, cached DOSSIER (JSON + screenshots) that many downstream consumers (pitch-deck, QA, docs, teardown, /copywriting, /artifex) re-use. /atlas CAPTURES neutral facts; it does NOT curate. A journaled BFS crawl over a live app via /agent-browser (qutebrowser), with two-number coverage, resumable checkpoints, and incremental re-capture. Use when Toper says /atlas, asks to map / document / inventory / screenshot a whole product or app, wants a feature dossier or a single source of truth for a deck/QA/docs effort, or asks 'what are ALL the screens/states/flows in X'."
argument-hint: "<product-slug> [base_url] [--role <role>] [--tenant <name>] [--test-tenant] [--scope <module|full>], e.g. /atlas pulse https://app.pulse.aenoxa.com --role owner --tenant 'Alamanda Coffee' --test-tenant --scope full"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# /atlas: exhaustive product capture into a consumer-general dossier

> **Most "document the app" passes curate as they go: they decide what matters and record only that, baking one consumer's bias into the artifact. /atlas does the opposite. It CAPTURES every reachable surface, element, and state as neutral, measured facts, then leaves the curation to whoever reads the dossier.** A pitch-deck, a QA plan, an onboarding doc, a competitive teardown, /copywriting, and /artifex all read the SAME dossier and each pulls what it needs. The dossier is the load-bearing interface; the crawl that fills it is a journaled, resumable, two-number-honest BFS over the live app.

The method: model the product UI as a typed graph, crawl it breadth-first with a hierarchical frontier (route / in-surface / state / flow), classify and account for every interactive element, deliberately reach each state the data exposes, and write everything to a per-product on-disk dossier (canonical JSON + referenced screenshots). The capture is loop-proofed by canonicalization, bounded honestly by two separately-reported coverage numbers, and made resumable + incremental by per-surface fingerprints and an append-only journal.

This skill is operational and self-contained. A fresh worker invoking /atlas can run a full capture from this file alone. The reference files (`references/SCHEMA.md`, `references/QUERY-GUIDE.md`, `references/FRICTIONS.md`) and helper scripts (`scripts/`) add depth and convenience; every script capability also exists as an inline command in this file.

---

## NON-NEGOTIABLE RULES: READ FIRST, THESE OVERRIDE EVERYTHING BELOW

These are HARD rules. Violating one produces a corrupt or dishonest dossier, not a stylistic variation. If anything below appears to conflict, the NON-NEGOTIABLE wins.

| # | Rule | Enforcement |
|---|---|---|
| **N1** | **Capture, never curate.** The dossier records OBSERVATIONS, not decisions. No field ever encodes a consumer's priority. The fields `should_show`, `deck_priority`, `include_in_deck`, `is_important`, `recommended`, or any equivalent verdict field are BANNED outright. | The bright-line test (Section 10.4). The completeness critic greps the dossier for banned field names and fails the run on any hit. |
| **N2** | **Observations are facts, not judgments.** Every signal is a measured count / boolean / enum / timing. Where a 0-5 rating exists it carries a strictly descriptive rubric AND the raw facts that produced it sit right beside it, so any consumer can re-derive its own score. | Schema (Section 10). A bare rating with no adjacent raw facts is an N2 violation. |
| **N3** | **Two-number coverage, reported separately, never faked.** Structural coverage (reachable routes / surfaces / elements) is verifiable and can legitimately reach 100% (empty frontier). State coverage (empty / error / variant) is data-bounded: report it as a fraction with the unobserved states listed by name. States the data cannot produce are logged `detected-but-not-observed`, NEVER invented or screenshotted-by-imagination. | Completeness mechanism (Section 9). A single blended "100%" number is forbidden. |
| **N4** | **One browser tool: /agent-browser (qutebrowser). NEVER Playwright MCP.** Playwright is hook-banned (the hook denies every `mcp__plugin_playwright_*` call). If /agent-browser is unavailable, HALT and surface the blocker. NEVER fall back to another browser tool. | Tooling (Section 13) + Robustness (Section 15). The fallback path does not exist by design. |
| **N5** | **Mutation safety is two-tier, keyed off the invocation.** READ-ONLY-safe by DEFAULT on real / unknown / production data: capture forms and their validation / error states up to the confirm boundary, never persist Create / Update / Delete. FULL mutation-capture is allowed ONLY on a tenant the invocation EXPLICITLY marks test / sandbox (e.g. `--test-tenant`). | Section 7. The bright-line: mutate only when the tenant is explicitly flagged test/sandbox AND scoped to that tenant only. Absent the flag, read-only-safe is the floor. |
| **N6** | **Resumable + incremental, always.** The crawl is a journaled BFS. A killed capture RESUMES from its frontier (never redo captured surfaces). A re-run against a changed app re-captures ONLY surfaces whose fingerprint moved. | Statefulness (Section 11) + the append-only `capture-log.jsonl`. The resume recipe (11.1) unions journal evidence with surface files on disk. |
| **N7** | **JSON is canonical; screenshots are referenced by path, never inlined.** Every consumer parses ONE shape. Markdown views may be generated FROM the JSON for humans, but the JSON is the source of truth. | Schema (Section 10). Inlining base64 image data into JSON is an N7 violation. A dangling screenshot path is an N7 violation the critic FAILS on (check 7). |
| **N8** | **Canonicalization loop-proofs the crawl.** Route params are templated (`/orders/:id`, not `/orders/123`); surface state is appended to the key; a data-instance is captured ONCE as a template plus a recorded variant list, never one node per row. | Section 5 (the BFS). Crawling 10,000 product rows as 10,000 nodes is an N8 violation. |
| **N9** | **No em-dash or en-dash, ever, anywhere in this skill's output (dossier, reports, notes).** Use a comma, a colon, parentheses, or a line break. (Toper's hard style rule.) | Verify with `grep -rnP "[\x{2013}\x{2014}]"` over every emitted file before completion (critic check 6). |
| **N10** | **agent-browser `@eN` refs are VOLATILE.** They invalidate on ANY DOM mutation. The driver MUST either snapshot then act in the SAME logical step (no DOM change between), OR re-snapshot before each interaction, OR prefer semantic `find role|text|label` locators. | Tooling (Section 13). Two stale-ref failures in the smoke-test forced this rule (refinement R8). |
| **N11** | **Done = frontier empty.** Every navigation affordance discovered is captured OR explicitly `skipped(reason)` / `blocked(reason)`. Silent truncation is forbidden: every bound (params-templated, off-product skip, data-gated state, scope limit) is logged in the manifest. | Completeness mechanism (Section 9). An unexplained gap in coverage is an N11 violation. |
| **N12** | **Never follow off-product.** External hosts, OAuth providers, payment processors, "Open in Stripe", outbound links: record the destination and type, then `skipped(reason: "external host")`. Do NOT crawl off the product under capture. | Element classification (Section 6) + N5 safety. |
| **N13** | **NEVER click-probe a server-persisting mutator to discover whether it is confirm-guarded outside a `--test-tenant`.** ALWAYS treat every `mutator` as UNGUARDED until proven guarded by evidence: a11y affordance (`aria-haspopup="dialog"`, a visible dialog pattern) or prior dossier data (`confirmation_required: true` from an earlier run). On a test tenant, click-probe ONLY targets that are disposable `ATLAS-` artifacts or trivially reversible states; NEVER account / role / access / suspension controls, even there. | Section 7.1. Verified failure 2026-06-22: the staff Suspend button fired with NO confirm and suspended the owner account mid-capture (recorded as an `incident` event in `dossiers/pulse/capture-log.staff.jsonl`). |
| **N14** | **NEVER record a secret into any dossier file.** Banned from surface JSON, `data_observed`, capture logs, manifests, notes: Authorization / Cookie / Set-Cookie header VALUES, JWTs (`eyJ...`), passwords, tokens, API keys, session ids. ALWAYS strip headers before pasting `agent-browser network requests` output. ALWAYS avoid screenshotting a form with a visible typed credential (type into masked fields only, or capture the empty form). | Critic check 8 greps the dossier for secret patterns; ANY hit FAILS the run and quarantines the file for human review (report file + pattern type ONLY, never the value). Sweep of the full pulse dossier 2026-07-02: clean. |
| **N15** | **One journal dialect, forever.** Every `capture-log*.jsonl` line is JSON with an `"event"` key from the FIXED vocabulary (`seed | in-progress | captured | skipped | blocked | mutation | incident | friction | critic | resume`), the per-event required fields (Section 10.2), and a `run_id`. NEVER invent event names; NEVER emit the legacy `action`- or `type`-keyed dialects. On resume, FOLD legacy dialects in as evidence (11.1), but never emit them. | Critic check 10 lints every current-run journal line. Why: the June-22 logs used 3 dialects and 30 ad-hoc event kinds; the documented resume protocol's fold over them yields 54 raw entries of which only 44 match disk surface ids, and 17 of the 61 captured surfaces have no journal evidence at all, so the disk union is mandatory (verified 2026-07-02). |
| **N16** | **Write-then-stat every screenshot.** NEVER write a screenshot path into any JSON without `stat`-verifying the file exists at that exact path in the SAME step. Screenshot names follow the grammar `<surface-id>__<state>[-full].png` (Section 10.1); ad-hoc names are banned. | Critic check 7 (referential integrity): a dangling reference FAILS the run. Why: the pulse dossier shipped with 8 dangling refs (including a POS flow step) and 38 unreferenced files because no check existed. |

### The three failure modes this skill exists to prevent

1. **The curation leak.** A documentation pass that decides "this screen is impressive, put it in the deck" has destroyed its own reusability: the QA consumer, the docs consumer, and the teardown consumer all inherit the pitch-deck's bias and cannot trust the artifact. N1 and the banned-field test exist to make this structurally impossible.
2. **The faked-coverage lie.** A pass that reports "100% documented" when the tenant data never produced a draft order, an overdue invoice, or a non-cash payment has lied by omission. N3 splits coverage into a verifiable structural number and an honest, data-bounded state number with the gaps named. A single round "100%" is the tell of a dishonest capture.
3. **The probe that mutates.** A crawler that clicks a destructive button "to see if a confirm appears" IS the confirm. On 2026-06-22 that exact probe suspended the operating owner account mid-capture. N13 inverts the burden of proof: unguarded until proven guarded, and account/role/access controls are never probed at all.

### Grounding (verified, not asserted)

Two validation runs, both on disk:

- **Schema genesis (smoke test):** the Pulse SALES domain slice (live deck-demo tenant Alamanda Coffee): back-office Orders + Payments AND the front-office POS register, 7 surfaces, ~11 states, 2 flows, ~41 elements, 10 screenshots. Structural coverage hit a verifiable 100% in-scope (empty frontier); state coverage landed at 73% because the tenant had no draft/open orders and no non-cash payments (logged `detected-but-not-observed`, not faked). The run forced 8 concrete schema refinements (R1 to R8, folded into Sections 6 to 10) and surfaced the volatile-ref rule (N10). Dossier: `~/claude/notes/atlas-design-smoketest-2026-06-22/dossier/pulse/`.
- **Production validation (full capture, 2026-06-22):** all 11 Pulse modules via an 8-worker parallel fan-out on the live multi-port proxy: 61 surfaces, 384 elements, 147 states, 161 screenshots, 2 filed flows, merged manifest with structural 98.4% / state 75.4% and 48 named unobserved states. Dossier: `dossiers/pulse/` (in this skill dir). This run ALSO produced the failure evidence behind N13-N16 and frictions 10-15 (Section 13.3): its own dossier records the owner-suspend incident, the native-picker CDP block, the 3-dialect journal drift, and the dangling screenshot refs. The best worked example of the schema in the wild is this dossier; its legacy deviations are documented in `references/SCHEMA.md`.

---

## 1. THE PRINCIPLE: the dossier is the product, the crawl is the means

> **/atlas exists to produce a complete, neutral, reusable record of a product's surface area. Everything else is in service of that record being (a) exhaustive, (b) factual, and (c) trustworthy enough that six different consumers read it instead of re-crawling the app six times.**

Three properties make the dossier worth building once and reading many times:

| Property | What it means | Why it matters |
|---|---|---|
| **Exhaustive by construction** | The BFS does not stop until the frontier is empty. Every reachable surface and every interactive element is captured or explicitly skipped/blocked with a reason. | A consumer can trust that what is NOT in the dossier is genuinely not in the reachable app (or is logged as a known gap), not just something the crawler got bored of. |
| **Factual, not editorial** | Every entry is a measured count, boolean, enum, timing, or a rating with its raw facts attached. No field pre-decides any consumer's job. | The pitch-deck and the QA plan can disagree about what is important and both be served by the same neutral signals. |
| **Trustworthy about its own limits** | Two coverage numbers, named skip/blocked lists, per-surface freshness timestamps, and `detected-but-not-observed` states. | A consumer always knows how complete and how fresh the dossier is, and can decide for itself whether to trust a given screenshot. |

The rest of this file is the operational machinery that delivers those three properties: the crawl model (Sections 3 to 6), mutation + auth safety (Sections 7 to 8), the completeness mechanism (Section 9), the schema (Section 10), statefulness + freshness (Section 11), parallelization (Section 12), tooling (Section 13), and the end-to-end flow (Section 14).

---

## 2. USAGE + invocation

```
/atlas <product-slug> [base_url] [options]

options:
  --role <role>         capture as this role (owner | staff | viewer | admin | ...). Default: the logged-in role.
  --tenant <name>       which tenant/account the crawl runs against (recorded in the manifest).
  --test-tenant         the tenant is a designated TEST/SANDBOX tenant: enables FULL mutation-capture (N5, Section 7).
                        ABSENT this flag, /atlas is read-only-safe (the floor).
  --scope <module|full> full = the whole app (default). A module id = capture just that module's subtree.
  --refresh             force a freshness re-check of cached surfaces even if not stale (Section 11).
```

**Examples**
```
/atlas pulse https://app.pulse.aenoxa.com --role owner --tenant "Alamanda Coffee" --test-tenant --scope full
/atlas pulse --scope pos-terminal                 # incremental re-capture of one module against the cached dossier
/atlas competitor-x https://app.competitor.com    # read-only-safe (no --test-tenant): forms captured, never persisted
```

**First action on every invocation is recall-on-invoke (Section 11):** read the existing dossier for `<product-slug>` if one exists, so the run knows what is already captured, what is stale, and what is new. A bare re-run of an already-captured product is an INCREMENTAL pass, not a from-scratch crawl. **Recall hygiene (hard):** read `manifest.json` + the journal TAIL only (`tail -n 50 capture-log.jsonl`); NEVER read `capture-log*.jsonl` wholesale into context (the pulse main log alone is 43KB and grows per run).

**Mode by scope.** `--scope full` runs the whole BFS over every module. `--scope <module>` restricts the frontier to one module's subtree (used for incremental re-capture and for the parallel fan-out, Section 12). Both share the same machinery; scope only bounds the seed.

---

## 3. THE MODEL: a typed graph crawl with a hierarchical frontier

The product UI is a graph. "Page = node" is too coarse: one route holds many tabs, modals, and states. So /atlas crawls a **three-level frontier** plus a cross-cutting flow node:

| Level | Node | Discovered from | Canonical key |
|---|---|---|---|
| **L1 Route** | a URL-addressable surface | nav menu + every navigating element | normalized path with params templated (`/orders/:id`, not `/orders/123`) |
| **L2 In-surface** | tab / modal / drawer / accordion / sub-panel (often NOT URL-distinct) | snapshot of the surface | `route#descriptor` (e.g. `/settings#tab=billing`, `/pos#modal=payment`) |
| **L3 State** | empty / filled / error / loading / permission-denied / precondition-gate / variant of an L1 or L2 surface | deliberate triggering (filter to nothing, submit empty, hit a 404, satisfy a gate) | `surface@state-kind` |
| **L4 Flow** | an ordered multi-step sequence threading across surfaces (checkout, onboarding, refund) | recognized during the crawl, captured as an ordered step list | `flow-id` |

L4 flows are first-class because docs, QA, and pitch consume them directly (a step-by-step guide, a test scenario, a demoable sequence).

---

## 4. THE BFS LOOP

```
seed     = post-login landing route + every entry in the primary nav (bounded by --scope)
frontier = queue(seed)          # unvisited targets, typed L1/L2/L3
visited  = set()                # canonical keys already captured
manifest = coverage ledger      # every target: unexplored | in-progress | captured | skipped | blocked

while frontier not empty:
    target = frontier.pop()
    if canon(target) in visited: continue
    if canon(target) in cached-and-fresh: skip (incremental, Section 11); continue
    mark manifest[target] = in-progress; append to capture-log.jsonl
    surface = navigate(target); satisfy entry_preconditions (R1); wait(networkidle)
    record(surface)                          # screenshot + snapshot + metrics -> dossier surface JSON
    for el in snapshot(surface).interactive: # EVERY button / link / tab / control / form field
        kind = classify(el)                  # Section 6
        enqueue_or_capture(el, kind)         # navigate -> frontier; expander -> capture L2; etc.
    capture_states(surface)                  # Section 8
    mark manifest[target] = captured; visited.add(canon(target)); append to capture-log.jsonl
run completeness_critic()                    # Section 9
```

Every journal append uses the N15 event vocabulary (Section 10.2). Every screenshot write follows N16 (write-then-stat, grammar-named).

### 4.1 Canonicalization (the crux, N8)

Canonicalization must loop-proof the crawl without collapsing genuinely distinct states:

- **Templated params.** `/products/123` and `/products/456` collapse to `/products/:id`: capture ONE representative, record `instance_note` ("10 instances exist, 2 representative variants captured"). Never crawl every row.
- **State appended to the key.** `/settings#tab=profile` is NOT `/settings#tab=billing`. The state suffix keeps distinct states distinct.
- **Data-instance as template.** A detail page is captured as a template ("an order-detail page") plus a recorded variant list (Section 8 + R5), not one node per database row.

---

## 5. THE THREE CRAWL SUBROUTINES (what the BFS loop calls)

The BFS loop (Section 4) is small on purpose; the work lives in three subroutines, each detailed in its own section below:

| Subroutine | Called as | Detailed in | What it does |
|---|---|---|---|
| **classify(el)** | per interactive element | Section 6 | sorts every `@eN` ref into exactly one of six classes; an unclassifiable element is a coverage hole the critic flags |
| **enqueue_or_capture(el, kind)** | per classified element | Section 6 | navigate -> push the target route to the frontier; expander -> open + capture the L2 surface + restore; mutator -> respect the mutation tier (Section 7); control -> exercise + reset; external -> record + skip (N12) |
| **capture_states(surface)** | per surface | Section 8 | deliberately reaches each state the data exposes (filled / empty / error / loading / precondition-gate / variant) and records which were ACTUALLY achieved, logging the rest `detected-but-not-observed` (N3) |

Two cross-cutting rules govern all three: every interaction honors the volatile-ref rule (N10, Section 13.1), and every server-persisting action honors the mutation tier (N5, Section 7) and the probe ban (N13).

---

## 6. ELEMENT CLASSIFICATION (so nothing interactive is unaccounted-for)

Every `@eN` ref from the accessibility-tree snapshot is classified into exactly ONE bucket. An unclassifiable element is a coverage hole the critic flags.

| Class | Examples | What /atlas does |
|---|---|---|
| **navigate** | nav link, "View", row-click -> detail | enqueue target route to the frontier |
| **expander** | "Add", "Filter", kebab menu, tab, accordion | open it, capture the resulting L2 surface, close/restore |
| **mutator** | Save / Create / Delete / Pay / Submit that PERSISTS server-side | read-only-safe by default (N5, Section 7): capture the form + validation states up to the confirm boundary; commit ONLY on a designated test tenant; NEVER click-probe for a confirm guard (N13) |
| **mutator-local** | add-to-cart / clear-cart / client-side toggles that are ephemeral + reversible | safe to exercise even read-only (no server persistence); capture the resulting state, then restore (R4) |
| **control** | search, sort, toggle, date-range, pagination | exercise -> capture resulting state -> reset |
| **export / external** | "Download CSV", "Open in Stripe", outbound link | record destination + type; do NOT follow off-product, `skipped(reason: "external host")` (N12) |

**R4 (mutator vs mutator-local) is load-bearing for safety:** the read-only-safe rule keys off this distinction. `mutator-local` (cart edits, client toggles) is always safe to exercise. `mutator` (server-persisting) is captured only up to the confirm boundary unless the tenant is flagged test/sandbox.

**R2 (keyboard shortcuts).** When an element exposes a keyboard shortcut (Pulse POS is keyboard-driven: F1 search, F2 hold, F4 cash drawer, F8 orders, F9 pay), record it in the element's `keyboard_shortcut` field. Load-bearing for QA (test the shortcut) and docs (document it).

**R3 (confirm dialogs are first-class), amended by N13.** A mutator guarded by a confirm dialog ("Hapus semua item?", "Delete this product?") gets `confirmation_required: true` and the confirm dialog is captured as its own sub-surface. This is ALSO the exact mechanism that makes read-only-safe capture possible: open the confirm, screenshot it, back out without confirming. **But R3 applies ONLY when guard evidence exists BEFORE the click** (a11y affordance such as `aria-haspopup="dialog"`, or `confirmation_required: true` in a prior dossier). Without evidence, the mutator is treated as UNGUARDED: capture the button + its label + a11y facts, set `confirmation_required: "unknown"` with a `skip_reason`, and move on. Clicking to find out IS the failure mode (N13, the suspend incident).

**Do / Don't (the mutator bright-line):**

| DO | DON'T |
|---|---|
| Open a confirm-guarded mutator's dialog and back out (R3), when guard evidence exists | Click any mutator "to see if a confirm appears" (that click suspended the owner account on 2026-06-22) |
| Create `ATLAS-` prefixed artifacts on a `--test-tenant` | Touch account / role / access / suspension controls, even on a test tenant |
| Append the `mutation` ledger event BEFORE committing (7.1) | Delete seed data, ever (teardown is human-gated) |
| Record `confirmation_required: "unknown"` when no evidence exists | Guess `confirmation_required: true` from the button looking "important" |

---

## 7. MUTATION SAFETY: the two-tier policy (first-class rule)

> **The gate for a write-action is whether it touches REAL data, not whether the URL is a production deployment.** A "prod" URL operated with TEST credentials on a TEST tenant is safe to mutate. Real customer data is never mutated.

This supersedes any strict "read-only-only" framing. The invariant is two-tier:

| Tier | When | What /atlas may do |
|---|---|---|
| **Read-only-safe (the FLOOR, default)** | real / unknown / production data; `--test-tenant` NOT set | Capture forms + their validation / error states up to the confirm boundary (R3, only with guard evidence per N13). NEVER persist Create / Update / Delete. Exercise `mutator-local` (client-ephemeral) freely; capture `mutator` (server-persisting) only up to the confirm step, then `skipped(reason: "destructive, real data")`. |
| **Full mutation-capture** | the invocation EXPLICITLY marks the tenant test / sandbox (e.g. `--test-tenant`); for Pulse this is the Alamanda Coffee test tenant with test creds | /atlas MAY commit mutations to REACH states read-only cannot: create a draft order, take a non-cash payment, trigger an error/variant state, then capture it. |

**The bright-line (memorize this):** mutate ONLY on a tenant the invocation explicitly flags test/sandbox. Three guardrails, all mandatory even in full-mutation mode:

1. **Scope to the test tenant ONLY.** On a shared multi-tenant deployment, NEVER mutate any OTHER tenant. The flag licenses the named test tenant, nothing else.
2. **Additive, not destructive-of-seed.** Creating states (a draft order, a payment) is safe. Wholesale deletion that removes seed data the dossier or a deck still needs is NOT. Add states; do not nuke the seed.
3. **Never account / role / access controls.** Suspend, Remove member, role change, PIN change, permission edits: these mutate the operating account's own ability to continue the capture (or a human's access). Off-limits at BOTH tiers (N13). The 2026-06-22 incident is the proof.

**Why this tier exists:** the smoke-test logged only 73% state coverage because the tenant had no draft orders and no non-cash payments to OBSERVE. With mutation-capture enabled on the test tenant, /atlas CREATES those states and captures them, closing the data-bounded gap honestly (the state was reached, not imagined). (Ref: memory `mutations-ok-on-test-environment-with-test-creds`.)

### 7.1 The mutation ledger (auditable, crash-safe, cleanable)

Rules for EVERY committed mutation, validated by the June-22 run (which invented most of them ad hoc; they are now mandatory):

- **`ATLAS-` prefix, always.** Every created artifact is named with the `ATLAS-` prefix (`ATLAS-Test-Customer-01`, `ATLAS-PO-001`, `ATLAS-Test-Promo`). This makes every atlas artifact findable, auditable, and cleanable by a human later.
- **Ledger-before-mutate.** Append the `mutation` journal event (Section 10.2) BEFORE committing the mutation. A crash between act and log must never orphan a mutation; a crash between log and act merely logs an intent that the resume pass re-verifies. (Same discipline as write-ahead logging.)
- **Manifest record, array-of-objects shape.** Every mutation lands in manifest `capture.mutations` as `{ "tenant": "...", "module": "...", "artifact": "..." }` objects (the shape the June-22 merge validated). Absent `--test-tenant`, the field is `[]` plus a `"note": "read-only-safe run"`.
- **Teardown is HUMAN-GATED.** /atlas NEVER auto-deletes its artifacts or any seed-adjacent data. On completion, list the `ATLAS-` artifacts in the run report for Toper to clean (or keep: they are also reusable capture states).
- **Expect cross-worker contamination in parallel runs.** Parallel module workers WILL photograph each other's `ATLAS-` artifacts (verified: `ATLAS-Test-Ingredient` appeared in the analytics worker's Umur Stok shots). Record this in the manifest (`"atlas_artifacts_visible_in": [...]`) so a consumer knows a screenshot contains test data, not product truth.

---

## 8. STATE ENUMERATION, AUTH, DYNAMIC DATA, ROLE AXIS

### 8.1 State enumeration per surface

For each surface, /atlas deliberately tries to reach each state and records which it ACTUALLY achieved (a state is an object, not a bare label, see Section 10):

- **filled** (default, on the populated tenant: the richest screenshots).
- **empty** (filter / search to no results, or visit a fresh entity: capture the empty-state UI).
- **error** (submit a form empty / with bad input: capture inline validation; hit a bad route: capture 404; where safe: a forbidden route: permission-denied).
- **loading** (captured opportunistically if catchable, often too fast).
- **precondition-gate (R1)** a surface that will not render until a precondition is satisfied (Pulse POS `/terminal` shows a "Pilih Lokasi" gate before the register loads). Record `entry_preconditions[]` on the surface; the BFS seed for such a target is "navigate AND satisfy preconditions", not just "navigate".
- **variant** meaningful data-driven variants the current data exposes (an order "paid" vs "refunded" vs "cancelled"). Status-driven FIELD variance is real and significant (R5): a completed order renders Completed/Payments/Paid; a cancelled order renders Voided/Void-reason/Due and NO Payments section. Record `fields_present[]`, and against a reference variant `fields_absent_vs_<ref>[]` / `fields_extra_vs_<ref>[]`. Variants NOT present in the data are logged `detected-but-not-observed`, NEVER invented (N3).

### 8.2 Auth + role axis

Login once at the gate. The auth surfaces themselves (login, register, forgot-password, OAuth entry, tenant-select) are FEATURES and get captured. Session cookies persist across the crawl. The same app differs by ROLE (owner / staff / viewer): the schema tags each surface and the manifest with `capture_role`. Full coverage of a role-gated app means re-crawling per role (`--role`), each role writing into the same dossier tagged by role. A single-role run is valid; it records its role and notes role-axis coverage as partial. Record the role TWICE: `capture_role` = the `--role` value as invoked (lowercase enum), `role_label_observed` = the badge the UI shows (the June-22 run drifted across "owner" / "ADMIN" / "ADMIN (owner)" because this split did not exist).

**Secret hygiene during auth capture (N14):** capture the login form EMPTY or with the password field masked; never screenshot a visible typed credential; never write the credential into `data_observed` or the journal. Credentials come from the env (`~/.claude/secrets.env` pattern) and are referenced by POINTER (env var name), never by value, in any dossier file (see `capture-config.json`, Section 11.4).

### 8.3 Dynamic / data-dependent UI

Crawl on a POPULATED tenant so surfaces render real data. Template data-instance routes (N8). Some UI only appears under data conditions the crawler cannot manufacture in read-only mode (a "low stock" badge, an "overdue" invoice): log it `detected-but-not-observed`, or, on a `--test-tenant`, CREATE the condition and capture it (Section 7). Realtime surfaces (a dashboard ticking) are captured as a point-in-time snapshot with the real on-screen numbers recorded plus a `realtime: true` signal.

### 8.4 Locale observation (R6)

Record `locale_observed` per surface, and treat mixed-localization as a first-class `gap`. (Pulse defaults to id but en leaks: breadcrumb "Orders", headers "Items"/"Payments"; and THREE date formats coexist across surfaces: `6/20/2026, 5:01 PM` vs `20 Jun 2026, 17.01` vs `2026-06-20`.) Directly useful to /copywriting (which strings to fix) and QA (i18n consistency bugs).

---

## 9. THE COMPLETENESS MECHANISM (knows when it is done + reports two honest numbers)

A live **coverage manifest** is the source of truth. Every discovered target carries a status:

```
unexplored -> in-progress -> captured
                          -> skipped(reason)     # intentional, auditable
                          -> blocked(reason)     # auth wall, broken page, out of data
```

**Done = frontier empty (N11)** = every navigation affordance discovered has been captured or explicitly skipped/blocked-with-reason. Two coverage numbers, reported SEPARATELY and HONESTLY (N3):

- **Structural coverage** = `captured / (captured + unexplored + blocked)` over routes, surfaces, and interactive elements. VERIFIABLE; can legitimately reach 100% (the reachable graph is fully expanded).
- **State coverage** = `states_observed / states_detected_as_possible` per surface. DATA-BOUNDED; reported as a fraction WITH the unobserved states listed by name. Never claims a 100% it cannot prove.

### 9.1 The completeness critic (end pass, 10 checks, runs before completion)

Checks 4 and 6-10 are mechanical: run the exact command, meet the exact PASS criterion. `scripts/atlas-verify.sh <dossier-dir>` runs all six mechanical checks in one shot (read-only, exit nonzero on violation); the inline commands below are the no-script equivalents.

| # | Check | How | PASS criterion |
|---|---|---|---|
| 1 | **Orphan nav** | diff the primary-nav inventory against `visited` routes | every nav entry crawled or skipped/blocked with reason |
| 2 | **Classification** | re-snapshot a sample of captured surfaces; assert every interactive element got a class | zero `unclassified` |
| 3 | **Expander + flow terminality** | assert every `expander` produced a captured L2 node and every L4 flow reached a terminal step | all terminal |
| 4 | **Banned-field scan (N1)** | `grep -rniE '"(should_show|deck_priority|include_in_deck|is_important|recommended)"\s*:' --include='*.json' --include='*.jsonl' <dossier>/` | ZERO hits; any hit FAILS the run (a curation verdict leaked) |
| 5 | **Two-number coverage report (N3)** | emit `coverage` into the manifest: the two percentages + explicit skip/blocked lists + named unobserved states | no silent truncation; every bound logged |
| 6 | **Style scan (N9)** | `grep -rlP '[\x{2013}\x{2014}]' --include='*.json' --include='*.jsonl' --include='*.md' <dossier>/` | ZERO hits. Scope greps to TEXT files: a bare recursive grep false-positives on raw PNG bytes (verified: 3 pulse screenshots matched, 2026-07-02) |
| 7 | **Screenshot referential integrity (N16)** | extract every `screenshots/*.png` path from all JSON (regex), diff against disk (python one-liner in `references/QUERY-GUIDE.md` R9, or `atlas-verify.sh`) | ZERO dangling refs (FAIL otherwise); unreferenced files enumerated into manifest `orphan_screenshots[]` (warning, not FAIL) |
| 8 | **Secret-pattern scan (N14)** | over text files only (`--include='*.json' --include='*.jsonl' --include='*.md'`): `grep -rlE 'eyJ[A-Za-z0-9_-]{20,}' <d>/` ; `grep -rliE '"(authorization|cookie|set-cookie)"\s*:\s*"[^"]+"' <d>/` ; `grep -rliE 'bearer [A-Za-z0-9._/+-]{16,}' <d>/` ; `grep -rliE '"(password|token|secret|api_key|apikey|access_token|refresh_token|session_id)"\s*:\s*"[^"<$]{4,}"' <d>/` | ZERO hits; ANY hit FAILS the run + quarantines the file for human review; report file + pattern type ONLY (`-l`, never `-o`/`-n` output of the value) |
| 9 | **Fingerprint completeness** | every captured surface's `freshness.fingerprint` matches `^sha256:[0-9a-f]{64}$` OR is `null` with a matching `gaps[]` entry | zero placeholders / hand-typed labels (a placeholder is a critic FAIL; the June-22 run shipped 0 real hashes out of 61) |
| 10 | **Journal lint (N15)** | every current-run journal line parses as JSON, has `event` in the fixed vocabulary, has `run_id` | zero violations (legacy pre-v1.2 lines are exempt: filter by `run_id`) |

### 9.2 Referential-integrity observations (R7)

Record cross-surface integrity facts in the manifest `cross_refs[]` as neutral assertions a consumer (especially QA) can assert on: e.g. "10 orders, 9 payments; the 1 cancelled order has no payment row, consistent: true". These are observations, not pass/fail verdicts.

---

## 10. THE CONSUMER-GENERAL DOSSIER SCHEMA (v1.2, the load-bearing interface)

Designed NOT pitch-deck-shaped. Structure: **product -> modules -> surfaces (pages/subpages/tabs/modals) -> elements + states**, with **flows** cross-cutting, a top-level **coverage manifest**, and a per-product index. JSON is canonical (N7); screenshots are referenced by path.

**The normative spec is `references/SCHEMA.md`** (full field tables, required-vs-optional, closed enums, the journal event vocabulary, and the "observed v1.1 legacy deviations" appendix documenting exactly how the real pulse dossier differs). This section keeps compact worked EXAMPLES so a fresh worker can write correct files without opening the reference. **Schema changes are forward-only** via `schema_version`: NEVER modify, regenerate, or reformat existing dossier data files to fit a new schema; legacy files are documented as-is and parsers tolerate them.

### 10.1 On-disk layout (one dossier per product; the REAL tree, as shipped)

```
~/.claude/skills/atlas/dossiers/<product-slug>/
  manifest.json                      # merged coverage ledger + index + capture metadata + cross_refs
  manifest.partial.<module>.json     # per-module partial manifest from a fan-out worker (kept post-merge as audit evidence)
  product.json                       # product identity, auth model, tech signals, module index
  capture-config.json                # OPTIONAL per-product defaults: base_url, roles[], tenants[], test_tenant,
                                     #   creds_pointer (an env-var NAME or file path, NEVER a credential value)
  modules/<module-id>.json           # one per module
  surfaces/<surface-id>.json         # the workhorse (one per surface)
  flows/<flow-id>.json               # one per multi-step flow
  screenshots/<surface-id>__<state>.png        # the naming grammar (N16)
  screenshots/<surface-id>__<state>-full.png   # full-page variant (only where full-page context matters)
  screenshots/_archive/<YYYY-MM-DD>/           # superseded shots moved here on re-capture (NEVER silently deleted)
  capture-log.jsonl                  # append-only BFS journal (resumability + audit), run_id-stamped per line
  capture-log.<module>.jsonl         # per-module journal from a fan-out worker (same N15 vocabulary)
```

Per-file writes (one JSON per surface) keep writes atomic-ish: a mid-run abort cannot corrupt the whole store, and journals are append-only. **Screenshot naming grammar (N16):** `<surface-id>__<state>[-full].png`, exactly. The surface JSON references the exact emitted filename, stat-verified in the same step. (Legacy exceptions in the pulse dossier: module-prefixed names like `pos-terminal__*` for surface `pos-register`, and `00-portal-launcher.png`; documented in SCHEMA.md, tolerated by parsers, banned going forward.)

### 10.2 Entity schemas (compact v1.2 examples; normative spec in references/SCHEMA.md)

**product.json**
```json
{
  "schema_version": "1.2",
  "product": "pulse",
  "name": "Pulse by Aenoxa",
  "base_url": "https://app.pulse.aenoxa.com",
  "captured_at": "2026-06-22T...",
  "capture_role": "owner",
  "role_label_observed": "ADMIN",
  "auth_model": { "type": "email+password+oauth", "multi_tenant": true, "tenant_select": true },
  "tech_signals": { "framework": "next.js", "i18n": ["id","en"], "themes": ["light","dark","system"],
                    "app_version": "<build hash if exposed>",
                    "app_version_fallback": "sha256 of the main JS asset URL from 'agent-browser network requests' (headers stripped, N14); use when no footer build hash exists" },
  "module_index": ["dashboard","pos","inventory","customers","reports","settings"]
}
```

**modules/<id>.json**
```json
{
  "id": "pos", "name": "Point of Sale", "nav_path": "/pos",
  "purpose": "Ring up a sale: pick products, take payment, issue receipt.",
  "role_visibility": ["owner","staff"],
  "surfaces": ["pos-register","pos-payment-modal","pos-clear-cart-confirm"],
  "flows": ["checkout-cash","checkout-empty-cart-error"]
}
```

**surfaces/<id>.json** (the workhorse, with states as OBJECTS, R1/R2/R4/R5/R6 fields baked in)
```json
{
  "schema_version": "1.2",
  "id": "pos-register", "module": "pos", "type": "page",
  "route": "/terminal", "route_template": "/terminal", "title": "POS Register",
  "parent_surface": "pos-select-location",
  "entry_preconditions": ["location selected via 'Pilih Lokasi' gate"],
  "locale_observed": "id (en leaks on some labels)",
  "what_it_is": "The front-of-house point-of-sale register.",
  "what_it_does": "Product grid by category + barcode search; tap to add to cart; hold or pay. Keyboard-driven (F1/F2/F4/F8/F9).",
  "instance_note": "<only for data-instance surfaces: 'N instances exist; M representative variants captured'>",
  "screenshots": { "empty-cart": "screenshots/pos-register__empty-cart.png", "cart-filled": "screenshots/pos-register__cart-filled.png" },
  "states": [
    { "id": "pos@select-location-gate", "kind": "precondition-gate", "how_reached": "open /terminal",
      "screenshot": "screenshots/pos-register__select-location.png", "notes": "blocks register until a location is chosen" },
    { "id": "pos-register@empty-cart", "kind": "empty", "how_reached": "register loaded, no items",
      "screenshot": "screenshots/pos-register__empty-cart.png", "message": "Keranjang kosong" },
    { "id": "pos-register@cart-filled", "kind": "filled", "how_reached": "tap a product (client-side add)",
      "screenshot": "screenshots/pos-register__cart-filled.png",
      "fields_present": ["item row","qty stepper","note","subtotal"],
      "notes": "cleared after capture (mutator-local, no persist)" }
  ],
  "elements": [
    { "id": "pos.search", "label": "Cari atau pindai barcode... (F1)", "role": "searchbox",
      "action": "control", "keyboard_shortcut": "F1", "exercised": false },
    { "id": "pos.product", "label": "<product card>", "role": "button",
      "action": "expander", "target": "adds item to cart", "exercised": true, "result_state": "pos-register@cart-filled" },
    { "id": "pos.clear-cart", "label": "Hapus (cart)", "role": "button",
      "action": "mutator-local", "confirmation_required": true, "target": "pos-clear-cart-confirm", "exercised": true },
    { "id": "pos.pay", "label": "Bayar (F9)", "role": "button",
      "action": "navigate", "target": "pos-payment-modal", "keyboard_shortcut": "F9", "exercised": true },
    { "id": "pos.hold", "label": "Tahan (F2)", "role": "button",
      "action": "mutator", "confirmation_required": "unknown", "keyboard_shortcut": "F2", "exercised": false,
      "skip_reason": "would persist a held draft (read-only-safe)" }
  ],
  "data_observed": { "product_count": 14, "categories": 6, "currency": "IDR", "sample_prices": ["18000","22000","32000"] },
  "perf": { "doc_dom_content_loaded_ms": 113, "doc_load_complete_ms": 157, "transfer_size_bytes": 77627 },
  "gaps": [ { "severity": "N4", "what": "select-location gate appears even with a single location", "evidence": "screenshots/pos-register__select-location.png" } ],
  "signals": {
    "visual_richness": { "charts": 0, "tables": 0, "images": 14, "distinct_colors": 8, "interactive_controls": 30, "density": "high", "rating_0_5": 5 },
    "demo_ability":   { "requires_data_setup": true, "has_destructive_actions": true, "destructive_guarded_by_confirm": true, "load_ms": 157, "stable_across_reloads": true, "needs_auth": true, "rating_0_5": 5 },
    "wow_potential":  { "realtime": false, "animation_present": true, "data_volume": "high", "unique_capability": "photo-rich tap-to-sell register, keyboard-driven, offline-capable", "rating_0_5": 5 }
  },
  "freshness": { "captured_at": "2026-06-22T04:54+07:00", "fingerprint": "sha256:<64 hex chars from the Section 11 recipe>", "ttl_days": 14 }
}
```

> **`role` vs `action` (do not swap them):** `role` is the ARIA role from the snapshot (`button`, `searchbox`, `combobox`...); `action` is the atlas class from Section 6 (`navigate|expander|mutator|mutator-local|control|export-external`). The pulse dossier contains one swapped element (`pos.clear-cart`: `"role":"mutator-local","action":"expander"`), preserved as legacy evidence; check 9's companion lint in `atlas-verify.sh` flags action-values in the role field.
>
> **`fingerprint` is a REAL hash or null.** `sha256:` + 64 hex from the Section 11 recipe, computed at capture time. NEVER a placeholder (`structural-hash-pending`) or a hand-typed label (`analytics-customers-v1`). If uncomputable, write `null` AND a `gaps[]` entry saying why (critic check 9).
>
> **For data-instance surfaces (order detail, product detail):** capture as a TEMPLATE, set `instance_note`, and record 2+ representative variant states under `states[]` with per-state `fields_present` / `fields_absent_vs_<ref>` / `fields_extra_vs_<ref>` (R5). Do NOT emit one surface file per row (N8).

**flows/<id>.json**
```json
{
  "id": "checkout-cash", "name": "Cash checkout", "goal": "Complete a cash sale",
  "entry_point": "pos-register", "outcome": "receipt issued", "real_data_used": "2 products, IDR 54000",
  "mutation_tier": "read-only-safe (captured up to Bayar confirm) | full (committed on test tenant)",
  "steps": [
    { "n": 1, "action": "tap product", "surface": "pos-register", "element": "pos.product", "screenshot": "...", "observed_result": "cart shows 1 item" },
    { "n": 2, "action": "press Bayar (F9)", "surface": "pos-register", "element": "pos.pay", "screenshot": "...", "observed_result": "payment modal opens" },
    { "n": 3, "action": "select Cash + confirm", "surface": "pos-payment-modal", "element": "...", "screenshot": "...", "observed_result": "receipt screen (only on --test-tenant; else captured to confirm boundary)" }
  ],
  "signals": { "demo_ability": { "steps": 3, "destructive": false, "rating_0_5": 5 }, "wow_potential": { "realtime": false, "rating_0_5": 3 } }
}
```

**manifest.json** (top level: two-number coverage + index + cross_refs + mutations as array-of-objects)
```json
{
  "product": "pulse", "schema_version": "1.2", "scope": "full | <module>",
  "coverage": {
    "structural": {
      "modules":  { "discovered": 11, "captured": 11, "unexplored": 0, "pct_of_app": 100 },
      "surfaces": { "captured": 61, "unexplored": 0, "blocked": 0, "pct": 100, "list": ["..."] },
      "elements": { "classified": 384, "unclassified": 0, "pct": 100 }
    },
    "state": {
      "observed": 147, "detected_possible": 195, "pct": 75.4,
      "observed_list": ["..."],
      "unobserved": ["invoice@overdue (no overdue data)","payments@non-cash (all cash in tenant)"]
    },
    "skipped": [ { "target": "/billing -> Stripe", "reason": "external host" },
                 { "target": "delete-product", "reason": "destructive, real data (no --test-tenant)" } ],
    "blocked": [ { "target": "/admin", "reason": "403 for owner role" } ]
  },
  "modules": ["dashboard","pos","inventory","customers","reports","settings"],
  "capture": { "run_id": "pulse-20260622-a", "started": "...", "finished": "...", "role": "owner", "tenants": ["Alamanda Coffee"],
               "tool": "/agent-browser (qutebrowser, multi-port CDP proxy 9222-9236; per-worker port claim)",
               "mutations": [ { "tenant": "Alamanda Coffee", "module": "customers", "artifact": "ATLAS-Test-Customer-01" } ],
               "atlas_artifacts_visible_in": ["analytics (Umur Stok shows ATLAS-Test-Ingredient)"] },
  "orphan_screenshots": ["screenshots/<on-disk-but-unreferenced>.png"],
  "cross_refs": [ { "assertion": "payments == paid-orders", "observed": "10 orders, 9 payments; cancelled #10 has no payment", "consistent": true } ],
  "freshness_report": { "verdict": "fresh|aging|stale", "fresh": 61, "aging": 0, "stale": 0, "computed_at": "..." }
}
```

**manifest.partial.<module>.json** (fan-out worker output; the merge validates each partial against this fixed shape BEFORE folding; full spec in SCHEMA.md)
```json
{
  "schema_version": "1.2", "module": "inventory", "run_id": "pulse-20260622-a",
  "surfaces": ["inventory-overview","inventory-stock"],
  "elements_classified": 55, "states_observed": 25,
  "coverage": { "structural_pct": 100, "state_pct": 88, "unobserved": ["..."] },
  "skipped": [], "blocked": [],
  "mutations": [ { "tenant": "Alamanda Coffee", "module": "inventory", "artifact": "ATLAS-PO-001" } ],
  "frictions": ["..."], "screenshot_count": 41,
  "captured_at": "...", "capture_role": "owner", "worker": "atlas-cap-inventory"
}
```
(The June-22 partials shipped in TWO incompatible ad-hoc shapes, and the customers partial's element count disagreed with disk, 26 vs 34; the merge succeeded only by hand-reconciling. The fixed shape above makes a machine merge possible. Legacy shapes documented in SCHEMA.md.)

**capture-log.jsonl** (append-only journal; N15 vocabulary, one event per line, `run_id` on EVERY line)

| event | required fields (beyond `ts`, `run_id`) | notes |
|---|---|---|
| `seed` | `targets[]`, optional `module` | frontier seeded |
| `in-progress` | `target`, optional `surface` | capture of a target started |
| `captured` | `target`, `surface`, `screenshots` (count), `states` (count) | ONLY event that marks a surface done |
| `skipped` | `target`, `reason` | intentional, auditable |
| `blocked` | `target`, `reason` | auth wall / broken page / uncapturable |
| `mutation` | `tenant`, `module`, `artifact`, `reversible` (bool) | appended BEFORE the commit (7.1) |
| `incident` | `target`, `what` | anything that went wrong with real-world effect |
| `friction` | `detail` | tooling lesson worth folding back into this skill |
| `critic` | `structural_pct`, `state_pct` | end-pass result |
| `resume` | `resumed_from` (visited count), `first_incomplete` | emitted on every resume |

```
{"ts":"...","run_id":"pulse-20260622-a","event":"seed","targets":["/dashboard","/pos"]}
{"ts":"...","run_id":"pulse-20260622-a","event":"captured","target":"/terminal","surface":"pos-register","screenshots":2,"states":3}
{"ts":"...","run_id":"pulse-20260622-a","event":"mutation","tenant":"Alamanda Coffee","module":"customers","artifact":"ATLAS-Test-Customer-01","reversible":true}
{"ts":"...","run_id":"pulse-20260622-a","event":"critic","structural_pct":100,"state_pct":81.7}
```

These ten events are the WHOLE vocabulary (N15). `surface_captured`, `crawl_start`, `session_start`, `navigate`, `screenshot`, and the `action`/`type`-keyed dialects the June-22 logs used are LEGACY: tolerated on read (11.1), never emitted.

### 10.3 Why this serves EVERY consumer (the justification)

| Consumer | Reads | Produces |
|---|---|---|
| **pitch-deck curation** | `signals.wow_potential` + `visual_richness` + flows; sorts surfaces; pulls `screenshots` | the most impressive screens + a demoable flow |
| **QA test-planning** | every `elements[].action=mutator` + all `states` (esp. error) + `flows` + `gaps[]` + `cross_refs` | a test matrix; `manifest` = the surface inventory to cover; `gaps` = known-issue seed |
| **user / onboarding docs** | `flows[]` in order + `what_it_is` / `what_it_does` + step `screenshots` | step-by-step guides; `module_index` = the doc TOC |
| **competitive teardown** | `module_index` + `signals` + `tech_signals` across two product dossiers | a feature / coverage diff vs a competitor's atlas |
| **/copywriting** | `what_it_does` + `data_observed` (real numbers = falsifiable proof) + `locale_observed` + `signals` | feature-facts that pass "visualize it / falsify it"; knows what is worth writing |
| **/artifex what-to-show** | `signals.visual_richness` + `screenshots` | which real screens to feature in a design |

The schema holds the UNION of what these need as neutral facts. None of them find a field that pre-decides their job. That is the test that it is consumer-general, not pitch-shaped. **Executable read-side recipes (verified against the real pulse dossier) live in `references/QUERY-GUIDE.md`**; consumers run the freshness check FIRST (11.2) and treat a STALE dossier's screenshots/selectors as suspect.

### 10.4 The bright-line test (N1, restated)

> A `should_show` / `deck_priority` (or any verdict) field is BANNED. If you are tempted to add one, a consumer's bias has leaked into the capture interface. The signals are neutral; the consumer scores them. The completeness critic greps for these field names and fails the run on any hit.

---

## 11. STATEFULNESS (cached, fresh, incremental, resumable)

Follows the stateful-domain-skill pattern (like /copywriting's per-brand voice-bank).

- **Cache path:** `~/.claude/skills/atlas/dossiers/<product-slug>/` (owned by the skill, outside `~/.claude/memory/`). Create it on first capture of a product; reuse it on every subsequent run.
- **Recall-on-invoke (first action of every run, N6):** read the existing dossier's `manifest.json` + the journal tail (`tail -n 50 capture-log.jsonl`), compute the freshness verdict (11.2). The run then KNOWS what is already captured, what is stale, and what is new. A re-run is incremental, not from-scratch. NEVER read whole journals into context.
- **Update-on-exit:** write back captured surfaces, bump the manifest, tombstone removed routes, write the `freshness_report`. Per-file writes (one JSON per surface) are atomic-ish so a mid-run abort cannot corrupt the store; journals are append-only.

### 11.1 Resumable checkpoints (N6): the verified resume recipe

The journal is the resume mechanism, but journals ALONE are insufficient against legacy data (verified 2026-07-02: the tolerant fold below yields 54 raw visited entries, some of them route keys like `/terminal`, of which only 44 match on-disk surface ids; 17 of the pulse dossier's 61 disk surfaces have no journal evidence at all, so the disk union is mandatory). The canonical `visited` set is the UNION of journal evidence and surface files on disk:

```bash
python3 - <<'EOF'
import json, glob, os
D = os.path.expanduser('~/.claude/skills/atlas/dossiers/<slug>')
visited = {f[:-5] for f in os.listdir(os.path.join(D,'surfaces'))}   # disk = ground truth
for f in glob.glob(os.path.join(D,'capture-log*.jsonl')):
    for line in open(f):
        line = line.strip()
        if not line: continue
        try: j = json.loads(line)
        except Exception: continue
        if j.get('event') in ('captured','surface_captured') and (j.get('surface') or j.get('target')):
            visited.add(j.get('surface') or j.get('target'))          # canonical + legacy event dialect
        elif j.get('action') == 'screenshot' and j.get('surface'):
            visited.add(j['surface'])                                 # legacy action dialect evidence
print('\n'.join(sorted(visited)))
EOF
```

Resume protocol: (1) reconstruct `visited` with the union above; (2) cheaply RE-VERIFY the last captured surface still holds (its JSON parses, its screenshots stat); (3) check the journal for `mutation` events with no subsequent `captured` on that surface: those mutations may or may not have committed (ledger-before-mutate), so re-VERIFY the artifact exists in the app before re-creating it, never blindly re-fire; (4) emit a `resume` event; (5) continue the BFS from the first incomplete target. A capture interrupted at surface 17 of 31 resumes at 18, never redoing 1 to 17.

### 11.2 Freshness scoring + staleness policy (operational, not aspirational)

Each surface carries `freshness: { captured_at, fingerprint, ttl_days }` (default ttl 14). Score per surface: `age = now - captured_at`;

| Bucket | Condition |
|---|---|
| **fresh** | age < 50% of ttl_days |
| **aging** | 50% to 100% of ttl_days |
| **stale** | age > ttl_days |

Dossier verdict = the worst bucket present, with counts. **Freshness duty (hard):** report the verdict in EVERY run report and WHENEVER a consumer skill is pointed at the dossier; a STALE dossier may not be handed to a consumer without an explicit staleness disclaimer. Inline report (or `scripts/atlas-freshness.sh <dossier-dir>`):

```bash
for f in ~/.claude/skills/atlas/dossiers/<slug>/surfaces/*.json; do
  jq -r '[.id, (.freshness.captured_at // "MISSING"), ((.freshness.ttl_days // 14)|tostring)] | @tsv' "$f"
done   # then bucket by age; the script does the arithmetic + verdict
```

**Refresh triggers (any ONE fires a refresh pass):**
1. age > ttl_days on any surface a consumer needs;
2. a KNOWN app deploy (Pulse ships continuously via Watchtower/GHCR: screenshot/selector rot is a when, not an if);
3. a consumer reports a failed selector or a visual mismatch against the dossier;
4. explicit `--refresh`.

**app_version fallback:** Pulse exposes no footer build hash (`product.json` records `<not exposed in footer>`). Record `tech_signals.app_version_fallback` = sha256 of the main JS asset URL from `agent-browser network requests` output (hashed asset filenames change on deploy; strip headers first, N14). When the fallback moves, mark the whole dossier `possibly-stale`.

**Refresh protocol (targeted, not from-scratch):** re-fetch a SAMPLE of surfaces (1-2 per module), re-fingerprint with the 11.3 recipe, compare. Different fingerprint -> stale -> re-capture just that surface (superseded screenshots move to `screenshots/_archive/<date>/`, N16 naming for the new ones). Same -> bump `captured_at`, keep everything. New routes in the live nav enter the frontier; vanished routes get tombstoned. **First-refresh caveat:** no legacy pulse surface has a real hash (35 missing / 5 placeholders / 21 hand-typed labels), so the FIRST refresh pass BASELINES fingerprints (compute + store, no comparison) and decides staleness by age + app_version fallback only.

### 11.3 The structural fingerprint recipe (concrete, verified)

The fingerprint is a hash of the STRUCTURAL snapshot: roles + hierarchy + digit-normalized labels of interactive controls, with volatile leaves (free text, counts, prices, dates) stripped. Compute it in the SAME step as the surface capture:

```bash
agent-browser snapshot -i -c --json > /tmp/atlas-snap.json
jq -S '[.. | objects | select(has("role")) | {r: .role, l: (if (.role | IN("button","link","tab","menuitem","combobox","searchbox","textbox","checkbox","radio","switch","option")) then ((.name // "") | gsub("[0-9][0-9.,:/]*"; "#")) else "" end)}]' \
  /tmp/atlas-snap.json | sha256sum | awk '{print "sha256:" $1}'
```

Properties (filter logic verified on jq 1.8.1 against a synthetic snapshot, 2026-07-02): shape-agnostic (recursive descent finds `role`-bearing objects at any depth, so it survives snapshot-format drift); control labels are kept but digits are normalized to `#` so "Bayar Rp 54.000" and "Bayar Rp 18.000" hash identically while "Bayar" -> "Pay" does not; non-control text is dropped entirely. Data changes do not force re-capture; structure changes do. If the snapshot returns no `role`-bearing objects (filter output `[]`), write `fingerprint: null` + a `gaps[]` entry; NEVER a placeholder (critic check 9).

### 11.4 Multi-app scaffold + size hygiene

**Multi-app convention:** one dossier per product at `dossiers/<slug>/` (slug: lowercase, hyphens, no spaces: `pulse`, `competitor-x`). First run bootstraps `product.json`, `manifest.json`, `capture-log.jsonl`, and the `modules/ surfaces/ flows/ screenshots/` subdirs. Optional `capture-config.json` per product records invocation defaults: `{ "base_url": "...", "roles": ["owner","staff"], "tenants": ["..."], "test_tenant": "Alamanda Coffee", "creds_pointer": "PULSE_TEST_* in ~/.claude/secrets.env" }`. `creds_pointer` is a POINTER (env var name or file path), NEVER a credential value (N14).

**Size hygiene (the pulse dossier is 34MB after ONE run; screenshots dominate):**
- On re-capture, move superseded screenshots to `screenshots/_archive/<YYYY-MM-DD>/`; NEVER silently delete (they are evidence), NEVER leave them masquerading as current.
- `-full` variants only where full-page context matters (long analytics tabs); viewport shots are the default.
- Journals: append-only with `run_id` per line; recall reads manifest + tail only (Section 2).
- Soft budget: flag any dossier over 100MB in the run report (archive candidates: `_archive/` dirs, superseded `-full` shots).

---

## 12. PARALLELIZATION (the full-capture fan-out)

**Partition by MODULE.** Modules are near-independent subtrees of the nav graph, the natural unit of parallelism.

**Three phases (via the Workflow engine or a spawned-worker fan-out):**
1. **Seed (1 agent):** login + enumerate top-level modules + per-module nav entry points -> the partition + a shared `product.json`.
2. **Fan-out (N agents, one per module):** each module-worker crawls its subtree with the Section 4 BFS, writing ONLY `modules/<id>.json` + its `surfaces/*` + `screenshots/*` + `capture-log.<module>.jsonl` + a `manifest.partial.<module>.json` (the FIXED 10.2 shape). No shared-file write contention (each owns its namespace).
3. **Merge + coverage-reconcile (1 agent):** VALIDATE each partial against the 10.2 shape, combine them, dedup cross-module shared surfaces (global search modal, account menu), recompute global structural + state coverage, run the completeness critic (all 10 checks), write the final `manifest.json`.

```js
// pipeline shape: capture each module, fold its partial manifest in as it lands
const partials = await pipeline(modules,
  m => captureModule(m),            // Section 4 BFS, writes its own namespace
  d => foldIntoManifest(d));        // validate partial shape, then reconcile incrementally
await completenessCritic(manifest); // the 10 checks of Section 9.1
```

### 12.1 The browser-concurrency reality (verified LIVE 2026-07-02)

**The multi-port CDP proxy IS LIVE.** `qb_proxy.py` binds ports 9222-9236 on 127.0.0.1 and fronts the real qutebrowser CDP on port 2262 (qutebrowser 3.7.0). `http://localhost:9222/json/version` answers with the Chrome-identity spoof (`"Browser": "Chrome/134.0.0.0"`); `http://localhost:9222/target` (no params) answers per-port target JSON. The proxy exposes `/claim`, `/free`, `/sessions` (and `/release?port=N`; `/free` is a non-reserving racy probe, never an allocation or teardown path: 13.2); each module-worker `/claim`s its OWN port + a dedicated qutebrowser tab for per-port isolation. The June-22 full capture ran 8 parallel module workers this way (`manifest.capture.tool` records it).

- **Preflight detection (PF-2, non-mutating):** `ss -ltn | grep -cE '127\.0\.0\.1:92(2[3-9]|3[0-6])'`. Count >= 2 -> multi-port live -> the parallel fan-out is allowed. Count < 2 -> the proxy is running single-port (or down): log the downgrade in the manifest and run **serial-per-module** (one worker at a time through the browser; reasoning/merge stays concurrent, browser I/O serializes). NEVER run a parallel fan-out without this check passing; parallel workers against a single-port proxy collide on one daemon + one pinned tab and corrupt captures.
- **HOT-SWAP BAN (retained, still critical):** the live `qb_proxy.py` is load-bearing (fitest + every capture session). NEVER hot-swap, restart, modify, or stop it from a capture run; hot-swapping drops the CDP connection for every active session. An OBSOLETE `qb_proxy.py.new` (+ `.README`, dated 2026-05-30: the pre-tab-isolation revision, OLDER than the live 2026-06-22 proxy) sits in `~/.config/qutebrowser/scripts/`: it is retained as history only and must NEVER be promoted (agent-browser HR-14 + `references/upgrade-history.md`); this skill NEVER activates it. A proxy cut-over is a deliberate human sequence: stage the file, swap, restart qutebrowser, smoke-test `/claim` `/free` `/sessions` + a basic capture, THEN capture. (The completed single-to-multi cut-over followed exactly this; its backup is `qb_proxy.py.single-port.bak`.)
- **Never relaunch the user's GUI qutebrowser from a worker** (13.3 item 5): flag the human.

---

## 13. TOOLING (how capture actually works)

**/agent-browser (qutebrowser) for ALL live navigation. NEVER Playwright MCP (N4)** (hook-enforced ban; the hook denies every `mcp__plugin_playwright_*` call). If /agent-browser is unavailable, HALT and surface. Never fall back. (Installed: agent-browser 0.22.3 at `~/.local/bin/agent-browser`, on PATH; all flags below verified against its `--help`.)

How each capture primitive maps to agent-browser:

| Need | Command | Notes |
|---|---|---|
| Navigate (cross-origin / new surface) | claim a port, `agent-browser connect $PORT`, then `agent-browser open <url>` | `tab new` FAILS (exit 144) in this env; use connect + open (see 13.3). `--cdp <port>` per call is the help-verified alternative to a sticky connect |
| SPA in-app nav | `agent-browser open <path>` then `wait --load networkidle` | SPA needs the wait before snapshot |
| **Enumerate elements** | `agent-browser snapshot -i -c --json` | the accessibility tree with `@eN` refs = THE element-inventory primitive; also feeds the fingerprint (11.3) |
| Interact / drive flows | `click @e` / `fill @e` / `find role\|text\|label <value> <action>` | see N10 on ref volatility; `find ... name <x>` is NOT a subaction (13.3 item 12) |
| Open states | `click` the expander, snapshot the result, then close | L2 / L3 capture |
| **Screenshot** | `agent-browser screenshot [--full] <path>` | primary; write-then-stat (N16); `--full` needs the HiDPI trim (13.3 item 9) |
| Screenshot (heavy page / CDP dead) | `~/.config/qutebrowser/scripts/qb-shoot <url-slug> <path>` | native Qt path, bypasses CDP; use when CDP returns blank/black (backdrop-filter, masks, big bg PNGs). qb-shoot is NOT on PATH: ALWAYS the absolute path (13.3 item 3; preflight PF-5 stats it) |
| On-screen numbers (real metrics) | `agent-browser get text @e` / `eval "<js>"` | feeds `data_observed`; never combine with screenshot in one Bash call (13.3 item 11) |
| Perf / load timing | `agent-browser network requests` + `eval "performance.timing..."` | feeds `perf`; STRIP HEADERS from network output before writing anything (N14) |
| Tab targeting (avoid clobbering other workers) | `curl /target?url=...` -> `close` -> reconnect -> `...?clear` | the proxy targets the active tab by default; under multi-port the `/claim` is the pin (13.2) |

### 13.1 The volatile-ref rule (N10, R8, hard)

agent-browser `@eN` refs invalidate on ANY DOM mutation. Two stale-ref failures occurred in the smoke-test. The capture driver MUST do ONE of:
1. **snapshot then act in the same logical step** (no DOM change between the snapshot and the action), OR
2. **re-snapshot before each interaction**, OR
3. **prefer semantic locators** (`find role|text|label ...`) over positional `@eN` refs.

Never carry an `@eN` ref across a click that mutated the DOM.

### 13.2 Tab-pinning / coordination

Other sessions (e.g. another worker) may share the proxy. /atlas must PIN its own product tab target before operating and CLEAR the pin when done, so it never steals another worker's active tab. Under the live multi-port proxy (Section 12.1) this is per-port isolation: the pin is the `/claim`, the clear is `/release?port=N` on teardown (`/free` is a non-reserving, racy PROBE, never an allocation or teardown path: agent-browser §6.3).

### 13.3 Verified agent-browser frictions (ALL confirmed in the field; do these or lose hours)

Compact rules + exact recovery commands here; extended context, transcripts, and full JS snippets in `references/FRICTIONS.md`.

1. **`tab new` fails (exit 144).** Do NOT navigate with `agent-browser tab new <url>`. Instead: claim a port (`/claim?from=9223`: leave 9222, the interactive active-tab port, alone per agent-browser HR-7), `agent-browser connect $PORT`, then `agent-browser open <url>`. The `connect` MUST happen within the `/claim` reservation TTL (about 30s) or the reservation lapses. (The June-22 workers also exported `AGENT_BROWSER_CDP=$PORT` alongside; note 0.22.3 `--help` does not list that env var: `connect` + the unique session are the load-bearing parts, `--cdp <port>` per call is the help-verified fallback.)
2. **Parallel isolation requires a UNIQUE `AGENT_BROWSER_SESSION` per worker PLUS a claimed port PLUS `/release` on teardown.** Without the unique session name the shared default daemon re-clobbers the tab regardless of the proxy. The `/claim` pins a dedicated tab; `/release?port=N` closes it. Persist `AGENT_BROWSER_SESSION` + the claimed PORT to a small env file and `source` it each step (the shell does not persist env between tool calls).
3. **CDP screenshots time out / return blank under concurrent load.** Verified escalation chain, in order: (a) retry once after 2-3s; (b) fall back to `~/.config/qutebrowser/scripts/qb-shoot <url-slug> <path>` (native Qt path, does not go through CDP; NOT on PATH, absolute path required, verified 2026-07-02); (c) if a WEB modal/animation is suspected (screenshot HANGS rather than times out), kill animations then re-shoot: `agent-browser eval "const s=document.createElement('style');s.textContent='*,*::before,*::after{animation:none!important;transition:none!important}';document.head.appendChild(s)"`; (d) `/release` the port and `/claim` a fresh one, reconnect, re-shoot (this resolved the June-22 hangs twice: 9224 to 9226, 9225 to 9224). Never silently skip a screenshot. (Native OS pickers are NOT recoverable by any rung: item 10.)
4. **CDP color-scheme can default to DARK after a browser restart** even though qutebrowser displays light, so screenshots come out dark-mode while the live page is light. FIX: `export AGENT_BROWSER_COLOR_SCHEME=light` (persist it in the env file; the env var is the field-verified fix; `agent-browser set media light` exists in 0.22.3 per `--help` but is unverified in this env). AUDIT every batch of shots: a light page composited over white should mean about 0.95; a full-page dark frame means about 0.10. Detecting this is hard from the downscaled inline preview (a dark page with white form fields can look light when shrunk) -> use ImageMagick `convert <f> -background white -flatten -colorspace Gray -format '%[fx:mean]' info:` and re-shoot anything under ~0.6 BEFORE accepting the batch.
5. **The dedicated `/claim` tab is reaped after a long idle gap (about 600s), and qutebrowser itself can CRASH and take the proxy down.** On any `Connection refused` / `All CDP discovery methods failed`: re-`/claim` a fresh port, reconnect, and re-verify the session. The `qb-proxy-doctor` watchdog only restarts the PROXY when qutebrowser is UP; if qutebrowser itself died it must be relaunched (its config.py then auto-restarts the proxy). Relaunching the user's GUI browser is an outward/intrusive action on their live desktop -> flag the human, do not do it unilaterally from a worker.
6. **The auth session can EXPIRE mid-run, and a fresh login defaults to the EN locale + a tenant-selector.** After any unexpected `/login` redirect: re-login, RE-SELECT the tenant, RESET the locale to match the rest of the dossier, then VERIFY with one known surface before continuing (the cookie jar persists across a browser restart, so a restart alone usually does NOT log you out, but a token timeout will).
7. **Radix/React Select comboboxes do not open via `@eN` click or JS** (the `role=combobox` element is not the click target; an inner `generic [onclick]` is). They DO open via keyboard: `agent-browser focus @ref` then `agent-browser press Enter`. Radix TAB lists, by contrast, are clickable via their `@eN` tab refs. Native HTML5 required-validation tooltips do not persist in a screenshot (capture the form state; note the constraint in the surface JSON).
8. **POS-style flows have their own gotchas (Pulse-specific but generalizable):** `/terminal` requires selecting a location that does NOT persist across full reloads (re-select after every reload); an order's "open" (Terbuka) state was reached by ENTERING the payment flow then abandoning it (which confirms it server-side), NOT by recall; partial cash payment is blocked (disabled "short by Rp X" button).
9. **HiDPI fractional-scaling: `--full` produces an oversized canvas with content pinned to the top-left.** On a display at fractional scaling (e.g. 166.7%, device-scale-factor 1.667), `agent-browser screenshot --full` double-applies the scale: the capture canvas is sized at page dimensions times the DPR, but the page rasterizes at 1x (e.g. a 4800x2928 canvas holding 2635x1757 of real content, top-left). FIX: ALWAYS post-process a `--full` capture by trimming to its content bounding box: `convert in.png -bordercolor white -border 1 -trim +repage out.png` (the 1px white border ensures `-trim` works when content touches an edge; near no-op on a correctly sized capture). Apply ONLY to `--full` outputs, NEVER blanket to every screenshot: a legitimately small-content state (a centered gate modal) must not be cropped. DETECTION: compare the `--full` canvas width to a normal viewport shot of the same page; a canvas roughly 1.667x larger is the defect. (0.22.3 `set --help` shows `set viewport <w> <h> [scale]`; forcing scale 1 before a `--full` shot is UNVERIFIED as prevention in this env, per agent-browser SKILL §9.2, so the trim IS the fix. Deep-dive incl. the PIL alternative: FRICTIONS.md.)
10. **A native OS device picker (Web Bluetooth / Web USB, e.g. "Tambah Printer") blocks CDP `Page.captureScreenshot` PERMANENTLY.** NEVER attempt a screenshot once a native picker is open: it will hang every subsequent CDP call on that tab. Recovery: log the state `blocked(reason: "native OS device picker blocks CDP")`, CLOSE the tab, `/release` + `/claim` a fresh port, reconnect. Capture the picker's existence from the a11y snapshot BEFORE clicking, or not at all. (Verified: settings printer capture, June-22.)
11. **Combining screenshot + eval in ONE Bash call exits 144.** Always split into two Bash calls (one screenshot, one eval). (Verified: inventory worker, June-22.)
12. **`find role button name <X>` fails: "Unknown subaction 'name'".** The `find` grammar is `find <locator> <value> <action>` (locators: role, text, label, placeholder, alt, title, testid, first, last, nth); there is no positional `name` subaction step. FIX: `snapshot -i -c`, locate the ref by its accessible name in the output, then `click @ref` in the same step (N10). (Verified: inventory worker, June-22; grammar re-confirmed against 0.22.3 `--help` 2026-07-02.) Note: a `--name` FLAG does exist in 0.22.3 `--help` (`agent-browser find role button click --name Submit`) but is UNVERIFIED in this env; if a run proves it, log a `friction` event and fold it back here.
13. **Date spinbutton a11y fills do not propagate to the hidden date input.** Filling the Month/Day/Year spinbutton refs updates the visible widget but not the real `<input>` value (React state ignores it). FIX: set the value via the native setter + dispatch events: `agent-browser eval "const el=document.querySelector('input[type=date]');Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set.call(el,'2026-06-22');el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}))"` (canonical form of the verified fix; full context in FRICTIONS.md). (Verified: June-22.)
14. **File-upload wizard steps are not capturable via the CDP path in this env** (native OS file picker). Log the downstream steps `blocked(reason: "file upload requires native OS picker")`, do NOT attempt them (the June-22 bulk-import steps 2-4 are honest gaps). Note: `agent-browser upload <sel> <files...>` exists in 0.22.3 `--help` but is UNVERIFIED in this qutebrowser+proxy env; if a future run proves it, log a `friction` event and fold it back here.
15. **Radix portal modals are invisible to main-document JS queries.** `document.querySelectorAll` from the main document scope misses portal content (`radix-_r_t_` containers); target `document.getElementById('radix-<id>')` explicitly. Also: product cards can be DIVs in the DOM that the a11y snapshot reports as `role=button` (trust the snapshot for classification, the DOM for JS targeting). (Verified: POS worker, June-22.)

---

## 14. EXECUTION FLOW (the step-by-step a fresh worker follows)

### 14.0 Preflight gates PF-1..PF-8 (ALL blocking; do not start the BFS with any unmet)

| Gate | Check | On fail |
|---|---|---|
| **PF-1** | `agent-browser --version` succeeds (0.22.3 at `~/.local/bin/agent-browser`) | HALT (N4): surface the blocker, never fall back |
| **PF-2** | Proxy mode, non-mutating: `ss -ltn \| grep -cE '127\.0\.0\.1:92(2[3-9]\|3[0-6])'` >= 2 means multi-port LIVE | log downgrade in manifest; run serial-per-module (12.1) |
| **PF-3** | `/claim` round-trip + `agent-browser connect $PORT` within the ~30s TTL; verify with `agent-browser get url` | re-claim; if the proxy is down see 13.3 item 5 (flag human for qutebrowser itself) |
| **PF-4** | `export AGENT_BROWSER_COLOR_SCHEME=light` + unique `AGENT_BROWSER_SESSION` + claimed PORT persisted to the run's env file, `source`d each step | fix before any screenshot (13.3 items 2 + 4) |
| **PF-5** | `stat ~/.config/qutebrowser/scripts/qb-shoot /usr/bin/convert /usr/bin/jq` all exist | HALT: the screenshot recovery ladder (13.3 item 3) and the critic depend on them |
| **PF-6** | Recall-on-invoke done: manifest + journal tail read, freshness verdict computed (11.2) | first-run bootstrap (11.4) if no dossier exists |
| **PF-7** | Mutation tier established + echoed in the run header: `--test-tenant` present -> full-mutation on that NAMED tenant only; absent -> read-only-safe floor | never proceed with an ambiguous tier (Section 7) |
| **PF-8** | Dossier dir + `run_id` initialized (`<slug>-<YYYYMMDD>-<letter>`), journal `seed` event written | the journal is the resume mechanism; no un-journaled crawl |

### 14.1 The run

1. **Parse the invocation.** product-slug, base_url, `--role`, `--tenant`, `--test-tenant` (sets the mutation tier, Section 7), `--scope`, `--refresh`.
2. **Run the preflight gates PF-1..PF-8.** All blocking.
3. **Decide the pass type from recall (PF-6):** fresh full crawl, incremental re-capture of stale/new surfaces, or resume (11.1) if the journal tail shows an interrupted run.
4. **Auth.** Log in once at the gate (capture the auth surfaces as features, with N14 secret hygiene: masked/empty credential fields only). Persist the session.
5. **Seed the frontier.** Post-login landing route + every primary-nav entry (bounded by `--scope`). Write/update `product.json` (including `app_version_fallback`, 11.2).
6. **Run the BFS (Section 4).** For each target: navigate (+ satisfy preconditions, R1), record (screenshot + snapshot + metrics + fingerprint per 11.3), classify every element (Section 6), enumerate states (Section 8), enqueue navigations, capture L2 expanders. Append every state change to the journal in the N15 vocabulary. Respect the mutation tier (Section 7) + ledger-before-mutate (7.1) on every mutator; honor the probe ban (N13). Honor N10 on every interaction. Write-then-stat every screenshot (N16); trim every `--full` shot immediately (13.3 item 9); brightness-audit every batch (13.3 item 4).
7. **Write per-surface JSON as you go** (Section 10). One file per surface; screenshots referenced by path (N7).
8. **Run the completeness critic (Section 9.1, all 10 checks).** Mechanical checks via `scripts/atlas-verify.sh <dossier-dir>` or the inline commands.
9. **Write the final manifest.json** with the two coverage numbers, named skip/blocked lists, unobserved states, cross_refs, the mutation array, `orphan_screenshots`, and the `freshness_report`.
10. **Update-on-exit.** Bump freshness, tombstone vanished routes, archive superseded screenshots (11.4), clear the tab pin / `/release` the port.
11. **Report.** Structural %, state % (with the named gaps), surfaces/elements/flows/screenshots counts, mutations performed with their `ATLAS-` artifacts listed for human teardown (7.1), the freshness verdict (11.2), and where the dossier lives.

> Depth is not optional. The crawl is DONE when the frontier is empty (N11), not when it "feels covered". A surface skipped for a reason is logged; a surface skipped silently is a bug.

---

## 15. ROBUSTNESS (degrade gracefully, fail loud, never fake)

Self-contained and defensive. The skill assumes no external state it has not verified.

- **/agent-browser unavailable:** HALT, report the blocker. NEVER fall back to Playwright or any other browser tool (N4). This is the single most important failure path.
- **Login fails / auth wall mid-crawl:** mark the affected targets `blocked(reason: "auth")`, continue the rest of the frontier, report the blocked set. Do not stall the whole crawl on one wall.
- **A surface will not load (broken page, 500):** `blocked(reason)`, screenshot whatever rendered, continue.
- **Stale `@eN` ref:** re-snapshot and retry the interaction (N10). If it still fails after a re-snapshot, log it and move on; do not loop forever on one element.
- **Screenshot returns blank/black or times out:** run the 13.3 item 3 escalation chain (retry -> qb-shoot by absolute path -> animation-kill JS -> fresh port). If ALL rungs fail, record the surface JSON with `screenshot: null` + a gap note; do not block the crawl on one image.
- **A native OS picker opened (Bluetooth/USB/file):** do NOT screenshot (it blocks CDP permanently, 13.3 item 10/14); log `blocked(reason)`, close the tab, re-claim a fresh port, continue.
- **An unguarded mutator is suspected (no confirm evidence):** do NOT click-probe (N13). Record the element with `confirmation_required: "unknown"` + `skip_reason`, continue. Account/role/access controls are never probed at any tier.
- **Data-gated state cannot be reached read-only:** log `detected-but-not-observed` (N3). On a `--test-tenant`, CREATE it (Section 7). NEVER invent or fabricate a screenshot.
- **Killed / session-limit mid-crawl:** resume via the 11.1 recipe (journal fold UNION disk). Already-captured surfaces are skipped; un-`captured` mutations are re-verified in the app before any re-fire.
- **Multi-port assumed but PF-2 fails:** fall back to serial-per-module (Section 12.1), log the downgrade. Never run a parallel fan-out against a single-port proxy.
- **A secret pattern appears in anything about to be written:** stop, strip it (N14); if it already landed, critic check 8 quarantines the file: report file + pattern type to the human, never the value.
- **Ambiguous scope / role / tenant:** record what was assumed in the manifest `capture` block and report it. Do not silently pick.
- **Every degraded path still writes an honest manifest.** Robustness reduces what gets captured, never the honesty of the two coverage numbers or the skip/blocked accounting. A partial crawl reports itself as partial, with the gaps named.

---

## 16. COMPOSES WITH

/atlas is the CAPTURE layer. These consumers CURATE the dossier it produces. **Handoff rule:** whenever a consumer is pointed at a dossier, run the freshness check first (11.2 / QUERY-GUIDE R0) and attach the verdict; a STALE dossier travels with an explicit staleness disclaimer or not at all.

| Skill | How it consumes the /atlas dossier |
|---|---|
| **/pitch-deck** | Reads `signals.wow_potential` + `visual_richness` + flows + screenshots to pick the most impressive screens and a demoable flow. /atlas does NOT decide what goes in the deck (N1); pitch-deck does. |
| **/qa + /ui-test** | Reads every `mutator` element, all `states` (esp. error), `flows`, `gaps`, and `cross_refs` as the test matrix + surface inventory + known-issue seed. The mutation-tier discipline (Section 7) matches QA's own test-tenant policy. QUERY-GUIDE R1/R2/R4 are the ready-made extraction recipes. |
| **/handover + docs** | Reads `flows[]` in order + `what_it_is`/`what_it_does` + step screenshots for step-by-step guides; `module_index` is the doc TOC. (QUERY-GUIDE R5; note the pulse legacy quirk: one inventory flow lives in its partial manifest, not in `flows/`.) |
| **competitive teardown** | Diffs two product dossiers (`module_index` + `signals` + `tech_signals`) into a feature/coverage comparison. |
| **/copywriting** | Reads `what_it_does` + `data_observed` (real numbers = falsifiable proof) + `locale_observed` for feature-facts that pass the visualize/falsify gate. |
| **/artifex + /frontend-design** | Reads `visual_richness` + screenshots to know which REAL screens to feature in a design (instead of inventing placeholder UI). |

The contract: /atlas writes neutral facts; every consumer scores them against its own priorities. If a consumer wishes a field pre-decided its job, that is exactly the field N1 bans.

---

## 17. ATTRIBUTION + SOURCES

- **Spec:** the Phase-1 design doc `~/claude/notes/atlas-design-smoketest-2026-06-22/design-doc.md` (the methodology, the v1.0 schema, the parallelization + tooling decisions). This SKILL.md is its operational, agent-facing distillation.
- **Validated in practice, twice:** (1) the smoke-test slice `~/claude/notes/atlas-design-smoketest-2026-06-22/dossier/pulse/` (schema genesis: states-as-objects, precondition-gate, keyboard_shortcut, mutator-local, per-state field variance, cross_refs, two-number coverage; refinements R1 to R8); (2) the full production capture `dossiers/pulse/` in this skill dir (11 modules, 61 surfaces, 384 elements, 147 states, 161 screenshots, 8-worker parallel fan-out on the live multi-port proxy). The production run's OWN recorded failures (owner-suspend incident, native-picker CDP block, 3-dialect journal drift, dangling screenshot refs, zero real fingerprints) forced N13-N16, the 10-check critic, and frictions 10-15.
- **Folded-in corrections (supersede the design doc where they conflict):** (1) the two-tier mutation policy (memory `mutations-ok-on-test-environment-with-test-creds`): read-only-safe on real data, full mutation-capture on a designated test tenant; (2) the multi-port proxy is LIVE (verified 2026-07-02, Section 12.1): the old "staged, use serial until cut-over" framing is retired; the hot-swap ban and the human-gate on `qb_proxy.py.new` remain in force.
- **Normative references in this skill dir:** `references/SCHEMA.md` (v1.2 entity schemas + journal vocabulary + closed enums + v1.1 legacy deviations), `references/QUERY-GUIDE.md` (verified consumer recipes), `references/FRICTIONS.md` (extended friction encyclopedia). Helper scripts (all read-only, browser-free): `scripts/atlas-verify.sh`, `scripts/atlas-freshness.sh`.
- **House pattern:** modeled on `~/.claude/skills/artifex/SKILL.md` and `~/.claude/skills/copywriting/SKILL.md` (the non-negotiable spine + numbered methodology + schema/templates + robustness + composes-with) and `~/.claude/skills/qa/SKILL.md` (the adversarial-completeness discipline); enforcement structure per `~/.claude/skills/frontend-design/SKILL.md` (blocking gate checklists + verified-failure rationales).
- **Honors:** the no-em-dash style rule (N9), the skill-authoring-robustness bar (`skill-authoring-robustness-mandatory`), the stateful-domain-skill pattern, and the /agent-browser-only browser rule (`Use qutebrowser via agent-browser, NEVER Playwright MCP`).
