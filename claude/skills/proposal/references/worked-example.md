# references/worked-example.md: one full proposal, end to end

Progressive-disclosure companion to `SKILL.md` section 8. This is ONE fully worked `build` proposal for an Indonesian SMB, in IDR with PPN and a 30/40/30 schedule, showing the anti-generic bar all the way through. It demonstrates HOW the rules produce a specific, honest, correctly-scoped document.

**All numbers here are illustrative placeholders to show the shape and the arithmetic. NEVER copy them as facts into a real proposal.** A real run uses Christopher's real rate and real estimates, or `[TBD]`.

---

## The invocation

```
/proposal "Lancar Jaya, a Jakarta retail SMB with 3 stores, needs a multi-tenant POS
to replace their spreadsheet workflow. Must work offline on the staff Android phones and
integrate Midtrans for QRIS payments. They want it before Ramadan." --type build
```

## Step 1 to 3: classify + discovery floor

- **Config read:** company name + IDR + PPN 0.11 pulled from `~/.claude/invoices/config.json`.
- **Engagement type:** `build` (we build and deliver the system). Not `qa`, not `fixed` (it is multi-module, not one bounded output).
- **Discovery floor:**

| Field | Value | Source |
|---|---|---|
| Client + project | Lancar Jaya + "Lancar POS" | brief |
| What we build | Multi-tenant offline-capable POS | brief |
| Core features | catalog, offline orders, sync, QRIS payments, reports | brief + batch 2 |
| Engagement type | build | classified |
| Budget signal | [TBD] | asked, client vague, flagged |
| Timeline | before Ramadan (about 10 weeks) | brief |
| Integrations | Midtrans QRIS (+ [TBD] others) | brief |
| Content/data provider | client provides product catalog + branding | batch 2 |

- **Confirm before writing:** "I will propose a 10-week multi-tenant POS build: offline order capture with sync, Midtrans QRIS, and reporting, for your 3 stores. Pricing in IDR with PPN, 30/40/30. Day-rate is still open, I will flag it. Anything to change?" -> client confirms.

---

## Step 4 to 6: the assembled proposal (compressed)

### 1. Executive Summary

Lancar Jaya runs 3 retail stores on shared spreadsheets, which breaks when two staff edit at once and gives no live stock or sales view. We propose Lancar POS: a multi-tenant, offline-first point-of-sale that each store runs on its existing Android phones, syncing orders and stock the moment connectivity returns, with QRIS payments via Midtrans and a live sales and stock dashboard.

Value propositions (quantified):
- Replace the shared spreadsheet: eliminate the daily 2-store reconciliation (about 4 hours/day today) with automatic sync.
- Offline-first: staff keep selling through the frequent connectivity drops in the stores; orders reconcile with no duplicates on reconnect.
- QRIS at the counter: accept Midtrans QRIS without a separate terminal.

Engagement overview: about 10 weeks, Christopher on the build with Suryadi on commercial, investment detailed in section 6, 30/40/30.

### 2. Scope of Work

Module: Tenants and Auth

| # | Feature | Description | Acceptance criteria (testable) | Priority |
|---|---------|-------------|-------------------------------|----------|
| 1 | Multi-store tenancy | Each store is a tenant with its own catalog, stock, staff | A staff account sees only its store's data; a cross-tenant read returns nothing | Must-have |
| 2 | Staff login | Per-store staff accounts with roles | A cashier cannot open the owner reports view | Must-have |

Module: Catalog and Stock

| # | Feature | Description | Acceptance criteria (testable) | Priority |
|---|---------|-------------|-------------------------------|----------|
| 3 | Product catalog | Products with price, SKU, stock per store | A stock decrement on sale is reflected within the store's data on next sync | Must-have |

Module: Offline orders and Sync

| # | Feature | Description | Acceptance criteria (testable) | Priority |
|---|---------|-------------|-------------------------------|----------|
| 4 | Offline order capture | Take orders with no connectivity | An order placed offline persists locally and survives an app restart | Must-have |
| 5 | Reconnect sync | Push offline orders on reconnect | An offline order appears on the server within 60s of reconnect, with no duplicate on repeated syncs | Must-have |

Module: Payments and Reports

| # | Feature | Description | Acceptance criteria (testable) | Priority |
|---|---------|-------------|-------------------------------|----------|
| 6 | Midtrans QRIS | Accept QRIS at checkout | A paid QRIS transaction marks the order paid via the Midtrans webhook; a failed one leaves it unpaid | Must-have |
| 7 | Sales dashboard | Live sales and stock per store | The owner sees today's per-store sales total updated on each synced sale | Must-have |
| 8 | CSV export | Export sales for the accountant | An export produces a CSV of the period's orders | Nice-to-have |

### Out of Scope (project-specific, rule 7)

The following are explicitly excluded unless added via a change request:
- Native iOS/Android apps. This covers a responsive web PWA only; Lancar Jaya's staff use Android Chrome, which the PWA targets.
- Migration of the existing spreadsheet data into the new catalog. We can scope a separate discovery + migration workstream; the base build starts from a fresh catalog the client enters.
- Midtrans account fees, QRIS settlement fees, and the client's Midtrans onboarding. The client holds and funds the Midtrans account.
- The Android devices themselves. The client supplies the staff phones.
- Accounting-system integration (e.g. to their bookkeeping tool). Not in this build; the CSV export (feature 8) is the interchange.
- Content and product photography. The client provides catalog data and any product images.

### 3. Technical Approach (brief)

Stack: Next.js PWA (offline via a service worker + IndexedDB queue) + Postgres (multi-tenant, row-scoped) + Midtrans QRIS + the Aenoxa VPS. Because this is an Aenoxa website build, the stack carries next-intl (id default + en) and next-themes (light/dark/system) from commit 0 per house defaults. Architecture: a modular monolith (one deployable, tenant-scoped data), chosen over microservices because 3 stores do not justify the operational overhead. Sync: an append-only offline order queue with idempotency keys so a repeated sync never double-posts (the feature-5 acceptance criterion).

### 4. Timeline (about 10 weeks)

```
| Phase              | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | W9 | W10 |
|--------------------|----|----|----|----|----|----|----|----|----|-----|
| Discovery & Design | ## | ## |    |    |    |    |    |    |    |     |
| Foundation         |    | ## | ## |    |    |    |    |    |    |     |
| Core Development    |    |    | ## | ## | ## | ## |    |    |    |     |
| Integrations (QRIS) |    |    |    |    |    | ## | ## |    |    |     |
| QA & UAT           |    |    |    |    |    |    | ## | ## | ## |     |
| Deploy & Handover   |    |    |    |    |    |    |    |    | ## | ##  |
```
Estimates include a 20% buffer; final timeline confirmed in Discovery and Design.

### 5. Team (real roster, rule 4)

| Role | Who | Responsibility | Allocation |
|------|-----|---------------|------------|
| Technical lead / build | Christopher | Architecture, full build, QRIS integration, technical handover | Full-time |
| Commercial / client lead | Suryadi | Client comms, sprint demos, commercial terms, UAT coordination | Part-time |

No padded PM/designer/second-dev roles: this is a real 2-person shop.

### 6. Investment (IDR + PPN)

Day-rate is [TBD] (see Assumptions); the phase costs below are illustrative pending the rate.

| Phase | Effort (days) | Cost |
|-------|---------------|------|
| Discovery & Design | 8 | Rp 20.000.000 |
| Foundation | 6 | Rp 15.000.000 |
| Core Development | 24 | Rp 60.000.000 |
| Integrations (QRIS) | 8 | Rp 20.000.000 |
| QA & UAT | 12 | Rp 30.000.000 |
| Deploy & Handover | 7 | Rp 17.500.000 |
| **Subtotal** | 65 | **Rp 162.500.000** |
| **PPN (11%)** | | **Rp 17.875.000** |
| **Total** | | **Rp 180.375.000** |

Optional item: CSV export (feature 8), 3 days, Rp 7.500.000, addable in phase Core Development.

Not included in the price: the Midtrans account fees, hosting/domain, and any licensed assets.

### 6.3 Payment Schedule (30/40/30)

Base milestone amounts are 30/40/30 of the subtotal; PPN is applied on each invoice, so the client's per-milestone payment includes PPN.

| Milestone | Base (30/40/30 of subtotal) | PPN (11%) | Client pays | Trigger |
|-----------|-----------------------------|-----------|-------------|---------|
| 1. Kickoff | Rp 48.750.000 | Rp 5.362.500 | Rp 54.112.500 | On signing |
| 2. Mid-project | Rp 65.000.000 | Rp 7.150.000 | Rp 71.500.000 | Core Development complete, must-haves demoed in staging |
| 3. Final | Rp 48.750.000 | Rp 5.362.500 | Rp 54.112.500 | Production deploy + UAT sign-off (BAST) |
| **Total** | **Rp 162.500.000** | **Rp 17.875.000** | **Rp 180.375.000** | |

(The three base amounts sum to the subtotal exactly; the three client-pays amounts sum to the total exactly.)

### 7. Deliverables + Warranty

Source code (full repo access), the deployed PWA on the VPS, technical docs, a user guide for the counter and owner flows, a handover session + recorded demo. 30-day warranty from production deploy: fixes for defects against the agreed acceptance criteria, per the section-library warranty split.

### 9. Commercial Terms (DRAFT)

> DRAFT terms, to be confirmed by Suryadi / counsel.

Change-request process (2-business-day impact assessment), IP transfer on final payment, 2-year mutual confidentiality, a 2-business-day client-feedback SLA. All draft, finalized in the contract.

### Appendix: Assumptions and Open Questions

| # | Item | Type | Needs |
|---|------|------|-------|
| 1 | Day-rate not yet set | [TBD] | Christopher's blended day-rate to finalize section 6 |
| 2 | Assuming the client provides the full product catalog + branding | assumption | client confirm |
| 3 | Assuming Midtrans is the only integration | open question | client confirm no others (accounting, marketplace) |
| 4 | Assuming under 3 concurrent cashiers per store | assumption | client confirm store staffing |

---

## Step 7: anti-generic score

| # | Criterion | Score | Why |
|---|---|---|---|
| 1* | Out-of-Scope specific to THIS project | 2 | names the spreadsheet migration, the Midtrans account, the Android devices |
| 2* | Every feature has a testable acceptance criterion | 2 | e.g. "within 60s of reconnect, no duplicate" |
| 3* | Scope fits `build` | 2 | full build scope, commercial terms flagged draft |
| 4 | Value props quantified | 2 | "4 hours/day reconciliation eliminated" |
| 5 | Estimates honest + discovery-flagged | 2 | 20% buffer stated, rate is [TBD] |
| 6 | Real team | 2 | Christopher + Suryadi, no padding |

Total 12/12, no starred 0. Swap test: could this go to another client name-swapped? No, it names Lancar Jaya's stores, spreadsheet, Android phones, Ramadan deadline, QRIS. Passes.

---

## Step 8 to 11: render, verify, record, report

- **Render:** markdown -> self-contained HTML (12.5px serif body, weight 500, mono only in the arch block) -> `google-chrome-stable --headless ... --print-to-pdf`. `test -s` passes (PDF is 41 KB). docx via `pandoc md -o docx` for the client to redline.
- **Verify (0.4):** V1 dash silent, V2 emoji silent, V3 no raw placeholders (rate is `[TBD]`, allowed), V4/V5 clean, V6 no `$`/USD (IDR only), V7 PDF > 0. All pass.
- **Record:** `PROP-202607-001.json` written to `~/.claude/proposals/`, status `draft`, the three base milestones stored (48.75M / 65M / 48.75M), `pdf_path` set.
- **Report (tables):**

Files:
| File | Path |
|---|---|
| Proposal PDF | ~/Documents/proposals/PROP-202607-001.pdf |
| Editable docx | ~/Documents/proposals/PROP-202607-001.docx |
| Markdown | ~/Documents/proposals/PROP-202607-001.md |
| Record | ~/.claude/proposals/PROP-202607-001.json |

Totals: subtotal Rp 162.500.000 | PPN Rp 17.875.000 | total Rp 180.375.000 | 30/40/30 base 48.75M / 65M / 48.75M.

Open items: day-rate [TBD] (blocks final pricing), integration list to confirm, catalog-provider assumption to confirm.

Handoff (when signed):
```
/invoice "Lancar Jaya" "Lancar POS"
   -> bill milestone 1 (Kickoff, base Rp 48.750.000, /invoice adds PPN -> Rp 54.112.500)
   The PROP record stores all three milestones for milestones 2 and 3 later.
```

Nothing was sent. Christopher or Suryadi sends the PDF.

---

## What this example demonstrates

- **Specificity beats template:** every exclusion, every acceptance criterion, every value prop is Lancar-Jaya-specific. That is the swap-test passing.
- **The QA firewall is not needed here** (this is a `build`), but note how a `qa` version would drop sections 3/5/7-warranty and replace section 2 with a test-suite/coverage plan, and would NEVER scope "we will fix the sync bug".
- **Currency coherence:** priced in IDR + PPN from the same config `/invoice` bills from, so the milestone hands off cleanly.
- **Honest gaps:** the day-rate is `[TBD]` and surfaced in Assumptions, not invented, exactly as rule 3 requires.
