---
name: atlas
description: "Exhaustively explores, documents, and screenshots EVERY feature / page / subpage / tab / modal / button / state / flow of a product, producing a complete, structured, cached DOSSIER (JSON + screenshots) that many downstream consumers (pitch-deck, QA, docs, teardown, /copywriting, /artifex) re-use. /atlas CAPTURES neutral facts; it does NOT curate. A journaled BFS crawl over a live app via /agent-browser (qutebrowser), with two-number coverage, resumable checkpoints, and incremental re-capture. Use when Toper says /atlas, asks to map / document / inventory / screenshot a whole product or app, wants a feature dossier or a single source of truth for a deck/QA/docs effort, or asks 'what are ALL the screens/states/flows in X'."
argument-hint: "<product-slug> [base_url] [--role <role>] [--tenant <name>] [--test-tenant] [--scope <module|full>], e.g. /atlas pulse https://app.pulse.aenoxa.com --role owner --tenant 'Alamanda Coffee' --test-tenant --scope full"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Skill
---

# /atlas: exhaustive product capture into a consumer-general dossier

> **Most "document the app" passes curate as they go: they decide what matters and record only that, baking one consumer's bias into the artifact. /atlas does the opposite. It CAPTURES every reachable surface, element, and state as neutral, measured facts, then leaves the curation to whoever reads the dossier.** A pitch-deck, a QA plan, an onboarding doc, a competitive teardown, /copywriting, and /artifex all read the SAME dossier and each pulls what it needs. The dossier is the load-bearing interface; the crawl that fills it is a journaled, resumable, two-number-honest BFS over the live app.

The method: model the product UI as a typed graph, crawl it breadth-first with a hierarchical frontier (route / in-surface / state / flow), classify and account for every interactive element, deliberately reach each state the data exposes, and write everything to a per-product on-disk dossier (canonical JSON + referenced screenshots). The capture is loop-proofed by canonicalization, bounded honestly by two separately-reported coverage numbers, and made resumable + incremental by per-surface fingerprints and an append-only journal.

This skill is operational and self-contained. A fresh worker invoking /atlas can run a full capture from this file alone.

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
| **N6** | **Resumable + incremental, always.** The crawl is a journaled BFS. A killed capture RESUMES from its frontier (never redo captured surfaces). A re-run against a changed app re-captures ONLY surfaces whose fingerprint moved. | Statefulness (Section 11) + the append-only `capture-log.jsonl`. |
| **N7** | **JSON is canonical; screenshots are referenced by path, never inlined.** Every consumer parses ONE shape. Markdown views may be generated FROM the JSON for humans, but the JSON is the source of truth. | Schema (Section 10). Inlining base64 image data into JSON is an N7 violation. |
| **N8** | **Canonicalization loop-proofs the crawl.** Route params are templated (`/orders/:id`, not `/orders/123`); surface state is appended to the key; a data-instance is captured ONCE as a template plus a recorded variant list, never one node per row. | Section 5 (the BFS). Crawling 10,000 product rows as 10,000 nodes is an N8 violation. |
| **N9** | **No em-dash or en-dash, ever, anywhere in this skill's output (dossier, reports, notes).** Use a comma, a colon, parentheses, or a line break. (Toper's hard style rule.) | Verify with `grep -nP "[\x{2013}\x{2014}]"` over every emitted file before completion. |
| **N10** | **agent-browser `@eN` refs are VOLATILE.** They invalidate on ANY DOM mutation. The driver MUST either snapshot then act in the SAME logical step (no DOM change between), OR re-snapshot before each interaction, OR prefer semantic `find role|text|label` locators. | Tooling (Section 13). Two stale-ref failures in the smoke-test forced this rule (refinement R8). |
| **N11** | **Done = frontier empty.** Every navigation affordance discovered is captured OR explicitly `skipped(reason)` / `blocked(reason)`. Silent truncation is forbidden: every bound (params-templated, off-product skip, data-gated state, scope limit) is logged in the manifest. | Completeness mechanism (Section 9). An unexplained gap in coverage is an N11 violation. |
| **N12** | **Never follow off-product.** External hosts, OAuth providers, payment processors, "Open in Stripe", outbound links: record the destination and type, then `skipped(reason: "external host")`. Do NOT crawl off the product under capture. | Element classification (Section 6) + N5 safety. |

### The two failure modes this skill exists to prevent

1. **The curation leak.** A documentation pass that decides "this screen is impressive, put it in the deck" has destroyed its own reusability: the QA consumer, the docs consumer, and the teardown consumer all inherit the pitch-deck's bias and cannot trust the artifact. N1 and the banned-field test exist to make this structurally impossible.
2. **The faked-coverage lie.** A pass that reports "100% documented" when the tenant data never produced a draft order, an overdue invoice, or a non-cash payment has lied by omission. N3 splits coverage into a verifiable structural number and an honest, data-bounded state number with the gaps named. A single round "100%" is the tell of a dishonest capture.

### Grounding (verified, not asserted)

The methodology and the v1.1 schema were smoke-tested on the Pulse SALES domain (live deck-demo tenant Alamanda Coffee): back-office Orders + Payments AND the front-office POS register, 7 surfaces, ~11 states, 2 flows, ~41 elements, 10 screenshots. Structural coverage hit a verifiable 100% in-scope (empty frontier); state coverage landed at 73% because the tenant had no draft/open orders and no non-cash payments (logged `detected-but-not-observed`, not faked). The run forced 8 concrete schema refinements (R1 to R8, folded into Section 10) and surfaced the volatile-ref rule (N10). The real validated dossier lives at `~/claude/notes/atlas-design-smoketest-2026-06-22/dossier/pulse/`.

---

## 1. THE PRINCIPLE: the dossier is the product, the crawl is the means

> **/atlas exists to produce a complete, neutral, reusable record of a product's surface area. Everything else is in service of that record being (a) exhaustive, (b) factual, and (c) trustworthy enough that six different consumers read it instead of re-crawling the app six times.**

Three properties make the dossier worth building once and reading many times:

| Property | What it means | Why it matters |
|---|---|---|
| **Exhaustive by construction** | The BFS does not stop until the frontier is empty. Every reachable surface and every interactive element is captured or explicitly skipped/blocked with a reason. | A consumer can trust that what is NOT in the dossier is genuinely not in the reachable app (or is logged as a known gap), not just something the crawler got bored of. |
| **Factual, not editorial** | Every entry is a measured count, boolean, enum, timing, or a rating with its raw facts attached. No field pre-decides any consumer's job. | The pitch-deck and the QA plan can disagree about what is important and both be served by the same neutral signals. |
| **Trustworthy about its own limits** | Two coverage numbers, named skip/blocked lists, per-surface freshness timestamps, and `detected-but-not-observed` states. | A consumer always knows how complete and how fresh the dossier is, and can decide for itself whether to trust a given screenshot. |

The rest of this file is the operational machinery that delivers those three properties: the crawl model (Sections 3 to 6), mutation + auth safety (Sections 7 to 8), the completeness mechanism (Section 9), the schema (Section 10), statefulness (Section 11), parallelization (Section 12), tooling (Section 13), and the end-to-end flow (Section 14).

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

**First action on every invocation is recall-on-invoke (Section 11):** read the existing dossier for `<product-slug>` if one exists, so the run knows what is already captured, what is stale, and what is new. A bare re-run of an already-captured product is an INCREMENTAL pass, not a from-scratch crawl.

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

Two cross-cutting rules govern all three: every interaction honors the volatile-ref rule (N10, Section 13.1), and every server-persisting action honors the mutation tier (N5, Section 7).

---

## 6. ELEMENT CLASSIFICATION (so nothing interactive is unaccounted-for)

Every `@eN` ref from the accessibility-tree snapshot is classified into exactly ONE bucket. An unclassifiable element is a coverage hole the critic flags.

| Class | Examples | What /atlas does |
|---|---|---|
| **navigate** | nav link, "View", row-click -> detail | enqueue target route to the frontier |
| **expander** | "Add", "Filter", kebab menu, tab, accordion | open it, capture the resulting L2 surface, close/restore |
| **mutator** | Save / Create / Delete / Pay / Submit that PERSISTS server-side | read-only-safe by default (N5, Section 7): capture the form + validation states up to the confirm boundary; commit ONLY on a designated test tenant |
| **mutator-local** | add-to-cart / clear-cart / client-side toggles that are ephemeral + reversible | safe to exercise even read-only (no server persistence); capture the resulting state, then restore (R4) |
| **control** | search, sort, toggle, date-range, pagination | exercise -> capture resulting state -> reset |
| **export / external** | "Download CSV", "Open in Stripe", outbound link | record destination + type; do NOT follow off-product, `skipped(reason: "external host")` (N12) |

**R4 (mutator vs mutator-local) is load-bearing for safety:** the read-only-safe rule keys off this distinction. `mutator-local` (cart edits, client toggles) is always safe to exercise. `mutator` (server-persisting) is captured only up to the confirm boundary unless the tenant is flagged test/sandbox.

**R2 (keyboard shortcuts).** When an element exposes a keyboard shortcut (Pulse POS is keyboard-driven: F1 search, F2 hold, F4 cash drawer, F8 orders, F9 pay), record it in the element's `keyboard_shortcut` field. Load-bearing for QA (test the shortcut) and docs (document it).

**R3 (confirm dialogs are first-class).** A mutator guarded by a confirm dialog ("Hapus semua item?", "Delete this product?") gets `confirmation_required: true` and the confirm dialog is captured as its own sub-surface. This is ALSO the exact mechanism that makes read-only-safe capture possible: open the confirm, screenshot it, back out without confirming.

---

## 7. MUTATION SAFETY: the two-tier policy (first-class rule)

> **The gate for a write-action is whether it touches REAL data, not whether the URL is a production deployment.** A "prod" URL operated with TEST credentials on a TEST tenant is safe to mutate. Real customer data is never mutated.

This supersedes any strict "read-only-only" framing. The invariant is two-tier:

| Tier | When | What /atlas may do |
|---|---|---|
| **Read-only-safe (the FLOOR, default)** | real / unknown / production data; `--test-tenant` NOT set | Capture forms + their validation / error states up to the confirm boundary (R3). NEVER persist Create / Update / Delete. Exercise `mutator-local` (client-ephemeral) freely; capture `mutator` (server-persisting) only up to the confirm step, then `skipped(reason: "destructive, real data")`. |
| **Full mutation-capture** | the invocation EXPLICITLY marks the tenant test / sandbox (e.g. `--test-tenant`); for Pulse this is the Alamanda Coffee test tenant with test creds | /atlas MAY commit mutations to REACH states read-only cannot: create a draft order, take a non-cash payment, trigger an error/variant state, then capture it. |

**The bright-line (memorize this):** mutate ONLY on a tenant the invocation explicitly flags test/sandbox. Two guardrails, both mandatory even in full-mutation mode:

1. **Scope to the test tenant ONLY.** On a shared multi-tenant deployment, NEVER mutate any OTHER tenant. The flag licenses the named test tenant, nothing else.
2. **Additive, not destructive-of-seed.** Creating states (a draft order, a payment) is safe. Wholesale deletion that removes seed data the dossier or a deck still needs is NOT. Add states; do not nuke the seed.

**Why this tier exists:** the smoke-test logged only 73% state coverage because the tenant had no draft orders and no non-cash payments to OBSERVE. With mutation-capture enabled on the test tenant, /atlas CREATES those states and captures them, closing the data-bounded gap honestly (the state was reached, not imagined). (Ref: memory `mutations-ok-on-test-environment-with-test-creds`.)

Every mutation performed is recorded in the manifest `capture.mutations` field (what was created, on which tenant) so the dossier is auditable. Absent `--test-tenant`, that field reads `NONE`.

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

Login once at the gate. The auth surfaces themselves (login, register, forgot-password, OAuth entry, tenant-select) are FEATURES and get captured. Session cookies persist across the crawl. The same app differs by ROLE (owner / staff / viewer): the schema tags each surface and the manifest with `capture_role`. Full coverage of a role-gated app means re-crawling per role (`--role`), each role writing into the same dossier tagged by role. A single-role run is valid; it records its role and notes role-axis coverage as partial.

### 8.3 Dynamic / data-dependent UI

Crawl on a POPULATED tenant so surfaces render real data. Template data-instance routes (N8). Some UI only appears under data conditions the crawler cannot manufacture in read-only mode (a "low stock" badge, an "overdue" invoice): log it `detected-but-not-observed`, or, on a `--test-tenant`, CREATE the condition and capture it (Section 7). Realtime surfaces (a dashboard ticking) are captured as a point-in-time snapshot with the real on-screen numbers recorded plus a `realtime: true` signal.

### 8.4 Locale observation (R6)

Record `locale_observed` per surface, and treat mixed-localization as a first-class `gap`. (Pulse defaults to id but en leaks: breadcrumb "Orders", headers "Items"/"Payments"; and TWO date formats coexist across surfaces, `6/20/2026, 5:01 PM` vs `20 Jun 2026, 17.01`.) Directly useful to /copywriting (which strings to fix) and QA (i18n consistency bugs).

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

### 9.1 The completeness critic (end pass, runs before completion)

1. **Orphan check.** Diff the primary-nav inventory against `visited` routes: catch nav entries that were never crawled.
2. **Classification check.** Re-snapshot a sample of captured surfaces; assert every interactive element got a class (no `unclassified`).
3. **Expander + flow terminality.** Assert every `expander` produced a captured L2 node and every L4 flow reached a terminal step.
4. **Banned-field scan (N1).** grep the whole dossier for `should_show`, `deck_priority`, `include_in_deck`, `is_important`, `recommended` (and equivalents). ANY hit FAILS the run: a curation verdict leaked into the neutral interface.
5. **Coverage report.** Emit `coverage` into the manifest: the two percentages + the explicit skip/blocked lists + the named unobserved states. Silent truncation is forbidden: any bound (params-templated, off-product skip, data-gated state, scope limit) is logged.
6. **Style scan (N9).** grep every emitted file for em/en-dashes (`grep -nP "[\x{2013}\x{2014}]"`); any hit must be fixed before completion.

### 9.2 Referential-integrity observations (R7)

Record cross-surface integrity facts in the manifest `cross_refs[]` as neutral assertions a consumer (especially QA) can assert on: e.g. "10 orders, 9 payments; the 1 cancelled order has no payment row, consistent: true". These are observations, not pass/fail verdicts.

---

## 10. THE CONSUMER-GENERAL DOSSIER SCHEMA (v1.1, the load-bearing interface)

Designed NOT pitch-deck-shaped. Structure: **product -> modules -> surfaces (pages/subpages/tabs/modals) -> elements + states**, with **flows** cross-cutting, a top-level **coverage manifest**, and a per-product index. JSON is canonical (N7); screenshots are referenced by path.

### 10.1 On-disk layout (one dossier per product)

```
~/.claude/skills/atlas/dossiers/<product-slug>/
  manifest.json              # coverage ledger + index + capture metadata + cross_refs (top level)
  product.json               # product identity, auth model, tech signals, module index
  modules/<module-id>.json   # one per module
  surfaces/<surface-id>.json # the workhorse (one per surface)
  flows/<flow-id>.json       # one per multi-step flow
  screenshots/<surface-id>__<state>.png
  capture-log.jsonl          # append-only BFS journal (resumability + audit)
```

Per-file writes (one JSON per surface) keep writes atomic-ish: a mid-run abort cannot corrupt the whole store, and `capture-log.jsonl` is append-only.

### 10.2 Entity schemas (v1.1)

**product.json**
```json
{
  "schema_version": "1.1",
  "product": "pulse",
  "name": "Pulse by Aenoxa",
  "base_url": "https://app.pulse.aenoxa.com",
  "captured_at": "2026-06-22T...",
  "capture_role": "owner",
  "auth_model": { "type": "email+password+oauth", "multi_tenant": true, "tenant_select": true },
  "tech_signals": { "framework": "next.js", "i18n": ["id","en"], "themes": ["light","dark","system"], "app_version": "<build hash if exposed>" },
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
      "action": "mutator", "keyboard_shortcut": "F2", "exercised": false, "skip_reason": "would persist a held draft (read-only-safe)" }
  ],
  "data_observed": { "product_count": 14, "categories": 6, "currency": "IDR", "sample_prices": ["18000","22000","32000"] },
  "perf": { "doc_dom_content_loaded_ms": 113, "doc_load_complete_ms": 157, "transfer_size_bytes": 77627 },
  "gaps": [ { "severity": "N4", "what": "select-location gate appears even with a single location", "evidence": "screenshots/pos-register__select-location.png" } ],
  "signals": {
    "visual_richness": { "charts": 0, "tables": 0, "images": 14, "distinct_colors": 8, "interactive_controls": 30, "density": "high", "rating_0_5": 5 },
    "demo_ability":   { "requires_data_setup": true, "has_destructive_actions": true, "destructive_guarded_by_confirm": true, "load_ms": 157, "stable_across_reloads": true, "needs_auth": true, "rating_0_5": 5 },
    "wow_potential":  { "realtime": false, "animation_present": true, "data_volume": "high", "unique_capability": "photo-rich tap-to-sell register, keyboard-driven, offline-capable", "rating_0_5": 5 }
  },
  "freshness": { "captured_at": "2026-06-22T04:54+07:00", "fingerprint": "sha256:<structural-hash>", "ttl_days": 14 }
}
```

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

**manifest.json** (top level: two-number coverage + index + cross_refs)
```json
{
  "product": "pulse", "schema_version": "1.1", "scope": "full | <module>",
  "coverage": {
    "structural": {
      "modules":  { "discovered": 11, "captured": 11, "unexplored": 0, "pct_of_app": 100 },
      "surfaces": { "captured": 31, "unexplored": 0, "blocked": 0, "pct": 100, "list": ["..."] },
      "elements": { "classified": 204, "unclassified": 0, "pct": 100 }
    },
    "state": {
      "observed": 58, "detected_possible": 71, "pct": 81.7,
      "observed_list": ["..."],
      "unobserved": ["invoice@overdue (no overdue data)","payments@non-cash (all cash in tenant)"]
    },
    "skipped": [ { "target": "/billing -> Stripe", "reason": "external host" },
                 { "target": "delete-product", "reason": "destructive, real data (no --test-tenant)" } ],
    "blocked": [ { "target": "/admin", "reason": "403 for owner role" } ]
  },
  "modules": ["dashboard","pos","inventory","customers","reports","settings"],
  "capture": { "started": "...", "finished": "...", "role": "owner", "tenant": "Alamanda Coffee",
               "tool": "/agent-browser (qutebrowser, CDP proxy 9222)",
               "mutations": "NONE | <list of created states + tenant>" },
  "cross_refs": [ { "assertion": "payments == paid-orders", "observed": "10 orders, 9 payments; cancelled #10 has no payment", "consistent": true } ]
}
```

**capture-log.jsonl** (append-only journal, one event per line)
```
{"ts":"...","event":"seed","targets":["/dashboard","/pos",...]}
{"ts":"...","event":"in-progress","target":"/terminal"}
{"ts":"...","event":"captured","target":"/terminal","surface":"pos-register","screenshots":2,"states":3}
{"ts":"...","event":"skipped","target":"pos.hold","reason":"would persist a held draft"}
{"ts":"...","event":"critic","structural_pct":100,"state_pct":81.7}
```

### 10.3 Why this serves EVERY consumer (the justification)

| Consumer | Reads | Produces |
|---|---|---|
| **pitch-deck curation** | `signals.wow_potential` + `visual_richness` + flows; sorts surfaces; pulls `screenshots` | the most impressive screens + a demoable flow |
| **QA test-planning** | every `elements[].action=mutator` + all `states` (esp. error) + `flows` + `gaps[]` + `cross_refs` | a test matrix; `manifest` = the surface inventory to cover; `gaps` = known-issue seed |
| **user / onboarding docs** | `flows[]` in order + `what_it_is` / `what_it_does` + step `screenshots` | step-by-step guides; `module_index` = the doc TOC |
| **competitive teardown** | `module_index` + `signals` + `tech_signals` across two product dossiers | a feature / coverage diff vs a competitor's atlas |
| **/copywriting** | `what_it_does` + `data_observed` (real numbers = falsifiable proof) + `locale_observed` + `signals` | feature-facts that pass "visualize it / falsify it"; knows what is worth writing |
| **/artifex what-to-show** | `signals.visual_richness` + `screenshots` | which real screens to feature in a design |

The schema holds the UNION of what these need as neutral facts. None of them find a field that pre-decides their job. That is the test that it is consumer-general, not pitch-shaped.

### 10.4 The bright-line test (N1, restated)

> A `should_show` / `deck_priority` (or any verdict) field is BANNED. If you are tempted to add one, a consumer's bias has leaked into the capture interface. The signals are neutral; the consumer scores them. The completeness critic greps for these field names and fails the run on any hit.

---

## 11. STATEFULNESS (cached, fresh, incremental)

Follows the stateful-domain-skill pattern (like /copywriting's per-brand voice-bank).

- **Cache path:** `~/.claude/skills/atlas/dossiers/<product-slug>/` (owned by the skill, outside `~/.claude/memory/`). Create it on first capture of a product; reuse it on every subsequent run.
- **Recall-on-invoke (first action of every run, N6):** read the existing dossier + manifest. The run then KNOWS what is already captured, what is stale, and what is new. A re-run is incremental, not from-scratch.
- **Update-on-exit:** write back captured surfaces, bump the manifest, tombstone removed routes. Per-file writes (one JSON per surface) are atomic-ish so a mid-run abort cannot corrupt the store; `capture-log.jsonl` is append-only.
- **Freshness / staleness rule:**
  - Each surface carries a `fingerprint` = hash of its STRUCTURAL snapshot (accessibility tree with volatile data stripped), NOT a pixel hash. Data changes do not force re-capture; structure changes do.
  - A global `app_version` signal (footer build hash / asset hash): when it moves, mark the whole dossier `possibly-stale`.
  - **Staleness check:** re-fetch a surface, re-fingerprint, compare. Different -> stale -> re-capture just that surface.
  - **Incremental re-capture:** diff the live nav against the cached `module_index` / routes. New routes enter the frontier; vanished routes get tombstoned; changed-fingerprint surfaces re-capture; unchanged surfaces are SKIPPED. The manifest records per-surface `captured_at` + `ttl_days` so a consumer always knows how old each screenshot is.

### 11.1 Resumable checkpoints (N6)

The `capture-log.jsonl` journal IS the resume mechanism. On a killed/re-spawned capture: read the journal, reconstruct `visited` from `captured` events, and continue the BFS from the remaining frontier. Already-captured surfaces are skipped (their JSON already exists on disk). A capture interrupted at surface 17 of 31 resumes at 18, never redoing 1 to 17.

---

## 12. PARALLELIZATION (the full-capture fan-out)

**Partition by MODULE.** Modules are near-independent subtrees of the nav graph, the natural unit of parallelism.

**Three phases (via the Workflow engine or a spawned-worker fan-out):**
1. **Seed (1 agent):** login + enumerate top-level modules + per-module nav entry points -> the partition + a shared `product.json`.
2. **Fan-out (N agents, one per module):** each module-worker crawls its subtree with the Section 4 BFS, writing ONLY `modules/<id>.json` + its `surfaces/*` + `screenshots/*` + a `manifest.partial.<module>.json`. No shared-file write contention (each owns its namespace).
3. **Merge + coverage-reconcile (1 agent):** combine partial manifests, dedup cross-module shared surfaces (global search modal, account menu), recompute global structural + state coverage, run the completeness critic, write the final `manifest.json`.

```js
// pipeline shape: capture each module, fold its partial manifest in as it lands
const partials = await pipeline(modules,
  m => captureModule(m),            // Section 4 BFS, writes its own namespace
  d => foldIntoManifest(d));        // reconcile incrementally
await completenessCritic(manifest); // final orphan / unclassified / flow-terminal / banned-field checks
```

### 12.1 The browser-concurrency constraint (corrected framing)

The live /agent-browser proxy (`qb_proxy.py`) is single-port (9222), single-target. Multiple workers all collide on one daemon + one pinned tab. So true parallel browser capture is GATED:

- **Serial-per-module (works today, no infra change).** Run modules through one or few workers but SERIALIZE browser access: each module-worker captures its module, then the next runs. Wins the reasoning/merge concurrency; browser I/O stays serial. Roughly serial wall-clock for the capture itself. Safe by default.
- **True parallel (requires the multi-port proxy cut-over).** A staged multi-port qutebrowser proxy binds ports 9222 to 9236 and exposes `/claim`, `/free`, `/sessions`. Once it is live, each module-worker `/claim`s its OWN port + a dedicated qutebrowser tab, giving per-port isolation, and the modules capture genuinely in parallel.

**The cut-over is a deliberate file-swap + qutebrowser restart that is SMOKE-TESTED FIRST. It is NOT a hot-swap of the running proxy mid-use.** The live single-port proxy is load-bearing for fitest; hot-swapping it would drop the CDP connection for every active session. The sequence is: stage the new proxy file, swap it in, restart qutebrowser against it, smoke-test that `/claim` `/free` `/sessions` and a basic capture work, THEN run the parallel fan-out. Until that cut-over is done and verified, use serial-per-module.

This gating is a real constraint, logged in the manifest, not a footnote: a parallel run that assumes multi-port without verifying the cut-over will collide on port 9222 and corrupt captures.

---

## 13. TOOLING (how capture actually works)

**/agent-browser (qutebrowser) for ALL live navigation. NEVER Playwright MCP (N4)** (hook-enforced ban; the hook denies every `mcp__plugin_playwright_*` call). If /agent-browser is unavailable, HALT and surface. Never fall back.

How each capture primitive maps to agent-browser:

| Need | Command | Notes |
|---|---|---|
| Navigate (cross-origin / new surface) | `agent-browser tab new <url>` | handles TLS; `open` over the proxy fails on HTTPS cert |
| SPA in-app nav | `agent-browser open <path>` then `wait --load networkidle` | SPA needs the wait before snapshot |
| **Enumerate elements** | `agent-browser snapshot -i -c --json` | the accessibility tree with `@eN` refs = THE element-inventory primitive |
| Interact / drive flows | `click @e` / `fill @e` / `find role\|text\|label ... <action>` | see N10 on ref volatility |
| Open states | `click` the expander, snapshot the result, then close | L2 / L3 capture |
| **Screenshot** | `agent-browser screenshot [--full] <path>` | primary |
| Screenshot (heavy page) | `qb-shoot <url-slug> <path>` | native Qt path; use when CDP returns blank/black (backdrop-filter, masks, big bg PNGs) |
| On-screen numbers (real metrics) | `agent-browser get text @e` / `eval "<js>"` | feeds `data_observed` |
| Perf / load timing | `agent-browser network requests` + `eval "performance.timing..."` | feeds `perf` |
| Tab targeting (avoid clobbering other workers) | `curl /target?url=...` -> `close` -> reconnect -> `...?clear` | the proxy targets the active tab by default |

### 13.1 The volatile-ref rule (N10, R8, hard)

agent-browser `@eN` refs invalidate on ANY DOM mutation. Two stale-ref failures occurred in the smoke-test. The capture driver MUST do ONE of:
1. **snapshot then act in the same logical step** (no DOM change between the snapshot and the action), OR
2. **re-snapshot before each interaction**, OR
3. **prefer semantic locators** (`find role|text|label ...`) over positional `@eN` refs.

Never carry an `@eN` ref across a click that mutated the DOM.

### 13.2 Tab-pinning / coordination

Other sessions (e.g. another worker) may share the single proxy. /atlas must PIN its own product tab target before operating and CLEAR the pin when done, so it never steals another worker's active tab. Under the multi-port proxy (Section 12.1) this becomes per-port isolation and the pin is the `/claim`.

---

## 14. EXECUTION FLOW (the step-by-step a fresh worker follows)

1. **Parse the invocation.** product-slug, base_url, `--role`, `--tenant`, `--test-tenant` (sets the mutation tier, Section 7), `--scope`. Establish the mutation tier NOW: test-tenant flag present -> full-mutation on that tenant only; absent -> read-only-safe floor.
2. **Verify the tool.** Confirm /agent-browser is available. If not, HALT (N4). Pin/claim a tab (Section 13.2).
3. **Recall-on-invoke.** Read the existing dossier for the product if any (Section 11). Decide: fresh full crawl, or incremental re-capture of stale/new surfaces.
4. **Auth.** Log in once at the gate (capture the auth surfaces as features). Persist the session.
5. **Seed the frontier.** Post-login landing route + every primary-nav entry (bounded by `--scope`). Write/update `product.json`.
6. **Run the BFS (Section 4).** For each target: navigate (+ satisfy preconditions, R1), record (screenshot + snapshot + metrics), classify every element (Section 6), enumerate states (Section 8), enqueue navigations, capture L2 expanders. Append every state change to `capture-log.jsonl`. Respect the mutation tier (Section 7) on every mutator. Honor N10 on every interaction.
7. **Write per-surface JSON as you go** (Section 10). One file per surface; screenshots referenced by path (N7).
8. **Run the completeness critic (Section 9).** Orphan + classification + expander/flow-terminal + banned-field scan (N1) + coverage report (N3) + em/en-dash scan (N9).
9. **Write the final manifest.json** with the two coverage numbers, named skip/blocked lists, unobserved states, cross_refs, and the mutation record.
10. **Update-on-exit.** Bump freshness, tombstone vanished routes, clear the tab pin / free the port.
11. **Report.** Summarize: structural %, state % (with the named gaps), surfaces/elements/flows/screenshots counts, mutations performed (if any), and where the dossier lives.

> Depth is not optional. The crawl is DONE when the frontier is empty (N11), not when it "feels covered". A surface skipped for a reason is logged; a surface skipped silently is a bug.

---

## 15. ROBUSTNESS (degrade gracefully, fail loud, never fake)

Self-contained and defensive. The skill assumes no external state it has not verified.

- **/agent-browser unavailable:** HALT, report the blocker. NEVER fall back to Playwright or any other browser tool (N4). This is the single most important failure path.
- **Login fails / auth wall mid-crawl:** mark the affected targets `blocked(reason: "auth")`, continue the rest of the frontier, report the blocked set. Do not stall the whole crawl on one wall.
- **A surface will not load (broken page, 500):** `blocked(reason)`, screenshot whatever rendered, continue.
- **Stale `@eN` ref:** re-snapshot and retry the interaction (N10). If it still fails after a re-snapshot, log it and move on; do not loop forever on one element.
- **Screenshot returns blank/black:** retry with `qb-shoot` (native Qt path, Section 13). If both fail, record the surface JSON with `screenshot: null` + a gap note; do not block the crawl on one image.
- **Data-gated state cannot be reached read-only:** log `detected-but-not-observed` (N3). On a `--test-tenant`, CREATE it (Section 7). NEVER invent or fabricate a screenshot.
- **Killed / session-limit mid-crawl:** resume from `capture-log.jsonl` (Section 11.1). Already-captured surfaces are skipped.
- **Multi-port assumed but not cut over:** detect the single-port proxy, fall back to serial-per-module (Section 12.1), log the downgrade. Never run a parallel fan-out against an un-cut-over single-port proxy.
- **Ambiguous scope / role / tenant:** record what was assumed in the manifest `capture` block and report it. Do not silently pick.
- **Every degraded path still writes an honest manifest.** Robustness reduces what gets captured, never the honesty of the two coverage numbers or the skip/blocked accounting. A partial crawl reports itself as partial, with the gaps named.

---

## 16. COMPOSES WITH

/atlas is the CAPTURE layer. These consumers CURATE the dossier it produces.

| Skill | How it consumes the /atlas dossier |
|---|---|
| **/pitch-deck** | Reads `signals.wow_potential` + `visual_richness` + flows + screenshots to pick the most impressive screens and a demoable flow. /atlas does NOT decide what goes in the deck (N1); pitch-deck does. |
| **/qa + /ui-test** | Reads every `mutator` element, all `states` (esp. error), `flows`, `gaps`, and `cross_refs` as the test matrix + surface inventory + known-issue seed. The mutation-tier discipline (Section 7) matches QA's own test-tenant policy. |
| **/handover + docs** | Reads `flows[]` in order + `what_it_is`/`what_it_does` + step screenshots for step-by-step guides; `module_index` is the doc TOC. |
| **competitive teardown** | Diffs two product dossiers (`module_index` + `signals` + `tech_signals`) into a feature/coverage comparison. |
| **/copywriting** | Reads `what_it_does` + `data_observed` (real numbers = falsifiable proof) + `locale_observed` for feature-facts that pass the visualize/falsify gate. |
| **/artifex + /frontend-design** | Reads `visual_richness` + screenshots to know which REAL screens to feature in a design (instead of inventing placeholder UI). |

The contract: /atlas writes neutral facts; every consumer scores them against its own priorities. If a consumer wishes a field pre-decided its job, that is exactly the field N1 bans.

---

## 17. ATTRIBUTION + SOURCES

- **Spec:** the Phase-1 design doc `~/claude/notes/atlas-design-smoketest-2026-06-22/design-doc.md` (the methodology, the v1.0 schema, the parallelization + tooling decisions). This SKILL.md is its operational, agent-facing distillation.
- **Validated v1.1 schema in practice:** `~/claude/notes/atlas-design-smoketest-2026-06-22/dossier/pulse/` (the Pulse SALES smoke-test slice: states-as-objects, precondition-gate, keyboard_shortcut, mutator-local, per-state field variance, cross_refs, two-number coverage). The refinements R1 to R8 were forced by that run and are folded into Sections 6 to 10.
- **Folded-in corrections (supersede the design doc where they conflict):** (1) the two-tier mutation policy (memory `mutations-ok-on-test-environment-with-test-creds`): read-only-safe on real data, full mutation-capture on a designated test tenant; (2) the corrected multi-port framing: parallelism via a deliberate, smoke-tested file-swap + restart cut-over, never a hot-swap of the load-bearing live proxy.
- **House pattern:** modeled on `~/.claude/skills/artifex/SKILL.md` and `~/.claude/skills/copywriting/SKILL.md` (the non-negotiable spine + numbered methodology + schema/templates + robustness + composes-with) and `~/.claude/skills/qa/SKILL.md` (the adversarial-completeness discipline).
- **Honors:** the no-em-dash style rule (N9), the skill-authoring-robustness bar (`skill-authoring-robustness-mandatory`), the stateful-domain-skill pattern, and the /agent-browser-only browser rule (`Use qutebrowser via agent-browser, NEVER Playwright MCP`).
