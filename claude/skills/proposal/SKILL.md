---
name: proposal
description: Generate rigorous, engagement-typed technical proposals / SOW / quotes for Aenoxa software-house client work as a verified PDF (Chrome-headless) plus an editable docx. Scopes to the real engagement type (build / QA-testing / staff-aug / fixed-scope / maintenance / discovery), prices in IDR with PPN from the shared invoice config, and hands a won proposal's 30/40/30 milestones off to /invoice. Use when Christopher says /proposal, or needs a project proposal, quote, SOW, or scoped client pitch. Generator only, never auto-sends.
argument-hint: <discovery brief or project description> [--type build|qa|staff-aug|fixed|maintenance|discovery] [--client "Name"] [--intl]
allowed-tools: Bash, Read, Write, Glob, Grep, WebSearch, WebFetch, AskUserQuestion
---

# /proposal: engagement-typed, verified technical proposals for Aenoxa client work

Turn a discovery brief into a **proposal a client signs and a proposal that protects Aenoxa from scope creep**: real scope with testable acceptance criteria, explicit exclusions, honest IDR pricing with PPN, and a milestone schedule that hands off cleanly to `/invoice`. This is a livelihood tool. Freelance and software-house client work is the anchor income path (`project_income_diversification_2026`), and a proposal is the reputation-bearing document that converts a warm lead into a paid contract.

The pipeline this skill lives in:

```
/outreach  (first touch, warm the lead)
   -> /proposal  (THIS: scope + price + SOW, generator only)
   -> [client signs]
   -> /invoice  (bill the 30/40/30 milestones)  <- /worklog feeds hours
   -> /status-report (weekly)  ->  /handover (BAST + delivery)
```

This skill exists to kill two failure modes. **(1) The fill-in-the-blank template blast**: a proposal so generic it could be sent to any client by swapping the name, priced in the wrong currency, padded with a fake 6-role agency team. That is the exact AI-slop the house robustness bar bans, and the version this skill replaces did all of it. **(2) The overpromise**: scoping architecture and bug-fixing onto a QA-testing engagement (a direct `feedback_qa_scope_discipline` violation), or shipping unreviewed legal terms as if final when commercial terms are the CEO's remit. So the spine is: **classify the engagement, scope only what that engagement actually covers, price in real IDR from the shared config, verify the PDF exists, and let Christopher or Suryadi send it.**

===============================================================================
## 0. PRIME META-RULES (mechanical, OVERRIDE EVERYTHING BELOW)
===============================================================================

These are grep-verifiable and boolean on purpose, so context pressure can never erode them. They run against **every file this skill produces** (the proposal markdown, the HTML render source, the PDF, the docx, and the human-readable fields of the PROP JSON record). The mirror is `/case-study` sections 0.1 and 0.4.

### 0.1 No em dash or en dash, ANYWHERE (PRIME RULE)

**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY file this skill produces**, nor in the chat summary, nor in this skill's own prose. This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02: never long dashes in ANY outgoing text). A proposal is a top-tier client-facing document, the single worst surface to leak the loudest "AI wrote this" tell.

- **Use instead:** a comma, a colon, parentheses, or a line break for clause breaks; the word "to" or a plain hyphen for ranges (write "8 to 10" or "8-10", never the en-dash form).
- **Plain hyphen-minus stays allowed** for compounds and ranges (real-time, multi-tenant, offline-first, 30-day, 8-10). ONLY the two long dashes are banned.
- **Scrub with meaning intact.** A heading shaped "Scope (em dash) Phase 1" becomes "Scope: Phase 1" or "Scope, Phase 1". Never mechanically delete a dash and leave broken grammar.

### 0.2 No emoji in the client document

**Zero emoji** in the proposal, the render source, the PDF/docx, or the JSON record. A proposal is formal. (Structural table glyphs and box-drawing in an architecture diagram are not emoji; the V2 grep below targets the emoji ranges only.)

### 0.3 IDR and the shared config are the source of truth (NEVER hardcode identity or currency)

Company identity, currency, and tax come from the **shared invoice config** `~/.claude/invoices/config.json` (verified present; keys `company.{name,address,phone,email,website,npwp}`, `bank.{...}`, `defaults.{currency,currency_symbol,tax_rate,tax_name,payment_terms_days,late_fee_percentage,language}`). Read it, never print its raw values into chat, never hardcode a company name into the template.

- **Default currency is IDR.** Prices are `Rp ` + dot-grouped thousands, integer, no decimals (`Rp 15.000.000`). A `PPN` line at `defaults.tax_rate` (11%) is mandatory on the investment total.
- **USD is the exception, not the default.** Use USD (or any non-IDR) ONLY when the client is explicitly international (`--intl`, or Christopher says so). A proposal priced in USD that `/invoice` then bills in Rp for the same Indonesian client is incoherent. The two documents share ONE config so they cannot silently disagree.
- Why: the sibling `/invoice` + `/worklog` are IDR + PPN 11% from this exact config. The version of this skill being replaced priced everything in `$X,XXX`, which collided with the whole billing pipeline.

### 0.4 VERIFICATION BLOCK (exact commands, ALL must pass before delivery)

Set `FILES` to every client-facing file this run produced (the `.md`, the `.html` render source, the `.docx`). Run all of it. Any hit on a MUST-BE-SILENT check = NOT done; fix with meaning intact and re-run until clean.

```bash
# V1 em/en dash (MUST be silent) - PRIME rule 0.1
grep -rnP "[\x{2013}\x{2014}]" $FILES

# V2 emoji + variation selector (MUST be silent) - rule 0.2
grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]" $FILES

# V3 raw template placeholders left unfilled (MUST be silent) - the "still a template" tell
grep -rnE '\$ ?[X]+|[X]+,XXX|\bXX,XXX\b|\bRp ?[X]|person-day.{0,3}\$?\[?X|\[RATE\]|\[Client Name\]|\[Project Name\]|placeholder' $FILES

# V4 secret / PII (MUST be silent; if a hit is REAL, report file + pattern TYPE only, never the value)
grep -rnE 'sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[A-Z0-9]|password=|token=|@s\.whatsapp\.net|(\+?62|0)8[0-9]{7,}' $FILES

# V5 internal absolute paths (MUST be silent in the client-facing doc; the PROP JSON may store pdf_path)
grep -rn '/home/christopher' $FILES

# V6 stray non-IDR currency when NOT international (MUST be silent unless --intl was set)
grep -rnE '\$[0-9]|\bUSD\b|dollar' $FILES

# V7 the PDF exists and is non-empty (MUST print a size > 0)
test -s "$PDF" && stat -c '%n %s bytes' "$PDF" || echo "FAIL: PDF missing or empty"
```

Notes:
- **V3 bracket audit is partly manual.** `[TBD]` is the SANCTIONED placeholder (rule 0.6) and legitimately survives. After the grep, eyeball every remaining `[...]` token: it must be either `[TBD]`, a real filled value, or a labeled estimate. A leftover `[Client Name]` / `[X days]` / `[Why]` fails.
- **V6 is skipped when `--intl` is set** (an international client is legitimately priced in USD/other). Otherwise a `$` or `USD` in the client doc means a currency leak: fix to IDR.
- These checks are wired into the DELIVERY GATE and the EXECUTION FLOW. They are boolean and mechanical precisely so a nice-looking draft can never average away a mechanical failure.

===============================================================================
## NON-NEGOTIABLE RULES (semantic hard rules, READ BEFORE SCOPING)
===============================================================================

Violating any one is a failed proposal, not a stylistic choice.

1. **CLASSIFY THE ENGAGEMENT TYPE BEFORE YOU SCOPE ANYTHING.** One of: `build | qa | staff-aug | fixed | maintenance | discovery` (section 1). The engagement type selects the scope playbook (`references/engagement-playbooks.md`). You cannot write scope, team, or pricing until the type is fixed, because each type scopes IN and OUT completely different things.

2. **NEVER SCOPE OUTSIDE THE ENGAGEMENT TYPE (the QA firewall).** On a `qa` engagement, scope test suites, findings reports, coverage, and re-runs; **NEVER scope "we will fix the bugs", "we will architect X", code changes, or infra fixes** (`feedback_qa_scope_discipline`: at ISI/BMS Christopher is a QA test contractor, not dev/architect, and prescribing dev-side actions is a verified violation). Inversely, NEVER scope a `build` as QA-only. A `staff-aug` proposal scopes hours/roles/rate, not fixed deliverables. Scope-fit is a DELIVERY-GATE check.

3. **NEVER INVENT NUMBERS.** No rate, headcount, day-count, date, user volume, latency, or metric gets fabricated to fill a gap. If you cannot source it (from Christopher, from the brief, or from a defensible estimate you label as an estimate), it becomes `[TBD]` inline AND a row in the mandatory **Assumptions and Open Questions** section. A number Christopher gives verbally is a real input, use it as-is; never soften it and never manufacture one beside it.

4. **NEVER PAD THE TEAM.** The real roster is Christopher (CTO, technical) + Suryadi (CEO, commercial) + any explicitly named contractors (`project_software_house`, `contact_suryadi`). NEVER present a generic 6-role agency lineup (PM + Lead Dev + FE + BE + Designer + QA) by default. A padded team on a 2-person shop is a credibility risk a client sees through. Scale the team table to who will really do the work, per the engagement playbook.

5. **COMMERCIAL, LEGAL, IP, AND CONFIDENTIALITY CLAUSES ARE DRAFT, NEVER FINAL.** This skill owns the **technical** proposal (scope, estimation, tech approach, technical deliverables). Commercial terms and the contract are CEO Suryadi's remit (`project_software_house`). Render every section-9-type clause (IP transfer, confidentiality, T&C, change-request legal language) under a visible banner: "DRAFT terms, to be confirmed by Suryadi / counsel." Never imply the skill authored final contract language.

6. **GENERATOR, NOT SENDER.** This skill produces file(s) for Christopher or Suryadi to send. It NEVER emails, WhatsApps, or otherwise transmits the proposal to a client. Mirror `/outreach`'s draft-for-approval posture: produce, summarize, hand off, stop.

7. **ANTI-GENERIC OR IT DOES NOT SHIP (the swap test).** If this proposal could be sent to a different client by swapping only the name, it is generic and it FAILS. Every Out-of-Scope item names a boundary specific to THIS project. Every feature has a testable acceptance criterion. Every value proposition is quantified ("cut checkout from 5 steps to 2", not "improve UX"). This is scored (section 7) and gated.

8. **NO BROWSER, NO SEND, NO DEPLOY.** This skill produces documents. It runs no browser automation (there is nothing to navigate), it SSHes nowhere, it commits nothing. Research via `WebSearch`/`WebFetch` is fine; driving a live browser is not this skill's job.

> If Christopher asks for something that breaks these (for example "price it in USD" for a local client, or "just put a full agency team"), do NOT silently comply. Either it is a real instruction (an international client: then USD is correct, note it), or flag it: "This client is local, so IDR + PPN is the coherent choice for the /invoice handoff. Want me to keep IDR, or is this genuinely an international deal?"

===============================================================================
## DELIVERY GATE (satisfy ALL before reporting the proposal done)
===============================================================================

- [ ] **Engagement type is fixed** (section 1) and the scope matches that type's playbook IN/OUT (rule 2). QA engagements have ZERO dev/architecture/bug-fix scope.
- [ ] **Discovery floor met** (section 1): client, project, what-we-are-building, core features, engagement type, budget signal, timeline, integration list are known OR flagged `[TBD]`.
- [ ] **Every feature row has a testable acceptance criterion.** No vague features (they cause disputes).
- [ ] **Out-of-Scope list is non-empty AND project-specific** (rule 7). Generic exclusions do not count.
- [ ] **Pricing is IDR + a PPN line from the shared config** (rule 0.3), integer, dot-grouped, unless `--intl`. Company identity read from config, not hardcoded.
- [ ] **Every number is real, `[TBD]`, or a labeled estimate** (rule 3), and an **Assumptions and Open Questions** section exists and is non-empty.
- [ ] **Team is the real roster** (rule 4), not a padded agency lineup.
- [ ] **Commercial/legal clauses carry the DRAFT banner** (rule 5).
- [ ] **Anti-generic score >= 9/12** (section 7) with none of the three starred rows at 0, AND the swap test fails-as-generic == false.
- [ ] **PDF produced and verified** (`test -s`, section 5 / `references/pdf-pipeline.md`); a `.docx` produced when the client needs an editable copy.
- [ ] **VERIFICATION BLOCK (section 0.4) V1 to V7 all pass** on every produced file.
- [ ] **PROP-YYYYMM-NNN record written** to `~/.claude/proposals/` (section 6).
- [ ] **Nothing was sent** (rule 6). The report tells Christopher where the files are and what to do next.

If any box fails, the proposal is NOT done. Fix before reporting complete.

===============================================================================
## 1. PARSE INVOCATION, CLASSIFY ENGAGEMENT, MEET THE DISCOVERY FLOOR
===============================================================================

### 1a. Parse `$ARGUMENTS`

Extract from the brief (and `--type`, `--client`, `--intl` flags if present):
- **Client** name, **project** working title, **what we are building** (one to two sentences).
- Any **engagement-type** signal, **budget** signal, **timeline**, **integration** list already stated.

If `$ARGUMENTS` is empty or thin, gather interactively in batches of 3 to 4 (never all at once), using `AskUserQuestion` where a small closed set of choices fits. Do not interrogate; scale question count to ambiguity.

### 1b. Classify the ENGAGEMENT TYPE (rule 1, do this FIRST)

Pick exactly one. This decides everything downstream. Full per-type playbooks (scope IN, scope OUT, deliverables, team shape, pricing model, the exclusions that matter): `references/engagement-playbooks.md`.

| `--type` | The engagement is | Scope centers on | Scope must EXCLUDE | Pricing model |
|---|---|---|---|---|
| `build` | Build a system end to end | Features, architecture, delivery, UAT, handover | (full scope OK; commercial terms stay Suryadi-confirmed) | Fixed by phase, or T&M with a cap |
| `qa` | Test someone else's system | Test suites, findings reports, coverage, re-runs | **dev fixes, architecture, infra changes, "we will fix the bugs"** (`feedback_qa_scope_discipline`) | Per suite, per cycle, or day-rate |
| `staff-aug` | Embed capacity into their team | Hours, roles, rate, ways of working | Fixed deliverables, outcome guarantees (they direct the work) | Monthly rate per role, hours cap |
| `fixed` | A bounded fixed-scope deliverable | One tightly-bounded output (a landing, an integration, an audit) | Anything past the one bounded output | One fixed price + explicit change-request rate |
| `maintenance` | Ongoing support / retainer | Tier, monthly hours cap, response SLA, overage rate | New feature builds beyond the tier | Monthly retainer + overage per hour |
| `discovery` | Paid discovery / scoping only | Requirements, technical design, a follow-on proposal | Any build commitment (that is the NEXT proposal) | Flat discovery fee |

If the type is genuinely ambiguous after the brief, ASK (one `AskUserQuestion`); do not guess, because a wrong type produces wrong scope and a scope-fit gate failure.

### 1c. DISCOVERY FLOOR (block generation until these are known or flagged)

Do NOT generate a proposal until each of these is either KNOWN or explicitly captured as `[TBD]` (and thus surfaced in Assumptions). This is a raised floor over the old "client + project + features" minimum, which let proposals ship with unknown type, budget, and timeline.

| # | Field | Why load-bearing | If missing |
|---|---|---|---|
| 1 | Client + project | Names the document | Ask (blocking) |
| 2 | What we are building | The whole premise | Ask (blocking) |
| 3 | Core features | The scope spine | Ask (blocking) |
| 4 | **Engagement type** | Selects the playbook (rule 1) | Ask (blocking) |
| 5 | Budget signal | Sizes the price honestly | Ask, else `[TBD]` + assumption |
| 6 | Timeline expectation | Sizes phases + team | Ask, else `[TBD]` + assumption |
| 7 | Integration list | Drives effort + risk | Ask, else `[TBD]` + assumption |
| 8 | Who provides content / data / access | The commonest hidden scope trap | Ask, else an explicit assumption |

Batches (adapt, skip what the brief already answered):
- **Batch 1 (blocking):** client, project, what we are building, who the end users are, engagement type.
- **Batch 2:** core features (must-have), nice-to-haves (v2), integrations, existing systems (greenfield or brownfield).
- **Batch 3:** timeline / deadline, budget range, tech preferences, compliance needs.
- **Batch 4:** why now, success metrics, competitors/references, growth expectations.

Once the floor is met, **confirm understanding in 3 to 4 bullets before writing** ("Here is what I will propose, anything to add or change?"), then generate.

===============================================================================
## 2. SCOPE RIGOR (the strongest part of this skill, do not dilute it)
===============================================================================

### 2a. Feature breakdown with MANDATORY acceptance criteria

Organize features by module. **Every feature MUST have a testable acceptance criterion. A feature without one is a dispute waiting to happen and FAILS the delivery gate.**

```markdown
#### Module: <Name>

| # | Feature | Description | Acceptance criteria (testable) | Priority |
|---|---------|-------------|-------------------------------|----------|
| 1 | <Name> | <what it does, 1-2 sentences> | <a condition you can pass/fail objectively> | Must-have |
| 2 | <Name> | <...> | <...> | Nice-to-have |
```

Priority levels: **Must-have** (in base price), **Nice-to-have** (priced separately as an option, section 3), **Future** (named, explicitly deferred, not priced).

A good acceptance criterion is falsifiable: "an order placed offline syncs and appears on the server within 60s of reconnect, with no duplicate", not "sync works well".

### 2b. Out-of-Scope discipline (CRITICAL, and project-specific by rule 7)

This is the section that protects the business. **List explicitly what is NOT included, and make every item specific to THIS project.** A generic exclusion ("mobile apps out of scope") is weak; a project-specific one ("native iOS/Android apps; this covers the responsive web PWA only, the client's field staff use Android Chrome") is a real boundary.

Work this checklist of what a client commonly ASSUMES is included but is not, and name the ones that apply to this project concretely:

- Platform boundaries (web vs native mobile vs desktop, which browsers/devices)
- Data migration from a legacy/existing system (name the system)
- Content, copywriting, translations, brand design (state who provides them)
- Third-party subscription/license costs (hosting, payment gateway fees, SaaS, API quotas)
- Ongoing maintenance past the warranty (its own section)
- Hardware / infrastructure the client must supply
- Training beyond the specified handover session
- SEO, analytics setup, marketing beyond what is listed
- Integrations with systems not named in the integration list

The Out-of-Scope list must be **non-empty** and NOT reusable verbatim for a different client. That is the gate.

### 2c. Where the verbose section boilerplate lives

The full section-by-section proposal body (cover, table of contents, executive summary, technical approach with architecture/integrations/infra/security/performance, timeline with the Gantt table, team, investment, deliverables, warranty, maintenance tiers, the draft T&C) is in **`references/section-library.md`**. It carries every section the previous skill had, nothing was lost, it just relocated so this file stays load-bearing. Pull from it when assembling the document; the load-bearing rules and gates stay HERE.

### 2d. Tech-stack note (when the proposal scopes an Aenoxa website)

i18n and theming are properties of a proposed website's STACK, not of this PDF document. Do NOT bolt i18n/theming onto the proposal document. But when the Recommended Tech Stack scopes an Aenoxa-ecosystem website build, that scoped stack must itself carry the house baseline: **next-intl (id default + en) + next-themes (light/dark/system) from commit 0** (`feedback_website_build_defaults_i18n_themes`), OR the light-only single-theme exception if it is a one-shot pitch/recruiter demo. Scoping a website that silently omits the baseline sells a build that violates house defaults.

===============================================================================
## 3. ESTIMATION, IDR PRICING, AND THE 30/40/30 SCHEDULE
===============================================================================

### 3a. Estimation method (survives from the old skill, now a rule)

1. **Decompose** the work into tasks small enough to reason about.
2. **Raw estimate** each in person-days.
3. **Add a 20% buffer** for unforeseen complexity, then state that the buffer is included.
4. **Round to clean numbers** (12 days or 2.5 weeks, not 11.7 days).
5. **Anything you do not understand well enough to estimate is flagged "needs discovery", NOT estimated** (rule 3). A `discovery` engagement is the honest answer when too much is unknown.

If genuinely uncertain on scale, give a range ("8 to 10 weeks") and state what pushes it to the upper end.

### 3b. IDR formatting (non-negotiable, mirrors /invoice + /worklog)

- `Rp ` + a space + dot-grouped thousands + integer, no decimals: `Rp 15.000.000`. NEVER `15,000,000`, `15000000`, or a decimal.
- Verified formatter (bash):
  ```bash
  fmt_idr() { printf 'Rp %s\n' "$(printf '%s' "$1" | sed ':a;s/\B[0-9]\{3\}\>/.&/;ta')"; }
  # fmt_idr 187500000  ->  Rp 187.500.000
  ```
- The HTML render template uses the `/invoice` `formatIDR` JS helper (proven in production; see `references/pdf-pipeline.md`).

### 3c. PPN and the investment table

Read `defaults.tax_rate` (0.11) and `defaults.tax_name` (`PPN`) from config. Compute integer:

```bash
subtotal=187500000
ppn=$(awk "BEGIN{printf \"%.0f\", $subtotal*0.11}")   # 20625000
total=$((subtotal + ppn))                              # 208125000
```

| Phase | Effort (person-days) | Cost |
|-------|----------------------|------|
| ... per phase ... | X | Rp X |
| **Subtotal** | | **Rp 187.500.000** |
| **PPN (11%)** | | **Rp 20.625.000** |
| **Total** | | **Rp 208.125.000** |

- Price nice-to-haves as **separate optional line items** so the client chooses (do not fold them into the base).
- List what the client will bear that is NOT in the price (gateway fees, hosting, domains, licensed assets).
- If you have no day-rate, ask for it, else use `[TBD]` (never invent a rate; the old `$[X]/person-day` placeholder is exactly the leak V3 catches).

### 3d. The 30/40/30 payment schedule (verified in project_software_house)

| Milestone | % | Amount | Trigger |
|-----------|---|--------|---------|
| Kickoff | 30% | Rp ... | On signing |
| Mid-project | 40% | Rp ... | Core development complete, must-haves demoed in staging |
| Final | 30% | Rp ... | Production deploy + UAT sign-off (BAST) |

Compute each milestone as an **integer** percentage of the total (round; make the three sum exactly to the total, adjust the last by the rounding remainder). Payment due within `defaults.payment_terms_days` (14) of milestone completion; work on the next phase may pause if payment is outstanding. These three milestones are what the proposal->invoice handoff emits (section 4b).

===============================================================================
## 4. BOUNDARIES AND THE PROPOSAL -> INVOICE HANDOFF
===============================================================================

### 4a. Boundary map (do / do not)

| This skill | Its lane | Hand off to |
|---|---|---|
| `/proposal` | Technical scope + estimation + IDR pricing + technical deliverables, as a document | |
| FROM `/outreach` | A warm lead becomes a scoped proposal | `/outreach` warms, `/proposal` scopes |
| TO `/invoice` | A won proposal's milestones become invoice records | 4b handoff |
| NOT `/worklog` | Hours accrual is worklog's ledger | do not log hours here |
| NOT `/status-report` | Weekly client updates | separate skill |
| NOT `/handover` | BAST + delivery docs | separate skill |
| Commercial terms | The CONTRACT + legal are Suryadi/counsel | draft-flag only (rule 5) |

### 4b. The proposal -> invoice milestone handoff contract

On a **WON** proposal (Christopher says the client signed), emit the 30/40/30 milestones in `/invoice`'s payment-record shape so billing is a clean handoff, not re-keying. This mirrors the `/worklog` -> `/invoice` line-item contract (the contract is the shape; **neither skill writes the other's store**).

Each milestone becomes:

```json
{
  "description": "<Project> - Milestone 1: Kickoff (30%)",
  "detail": "On signing",
  "qty": 1,
  "unit_price": 56250000,
  "amount": 56250000
}
```

`unit_price` and `amount` are integer IDR (the milestone rupiah amount; PPN is added by `/invoice` from its config, do not double-apply it here). Then print the exact next command for the user to run:

```
Next (when signed): /invoice "<Client>" "<Project>"
   Bill milestone 1 (Kickoff, 30%): use the line item above, PPN is added by /invoice.
   Record: the PROP JSON stores all three milestones for later billing.
```

Store the three milestones inside the PROP record (section 6) so a later `/invoice` for milestone 2 or 3 reads them without recomputation.

===============================================================================
## 5. THE PDF PIPELINE (verified path only, full recipe in references)
===============================================================================

The primary deliverable is a PDF. **The old "convert with Pandoc or md-to-pdf" instruction is BROKEN on this box** (verified: `md-to-pdf` absent; `pandoc file.md -o file.pdf` fails with "pdflatex not found", no LaTeX engine, no weasyprint/wkhtmltopdf/prince installed). Do NOT use pandoc for direct PDF.

**The working path (adopted from `/invoice` sections 8 and 9, verified live 2026-07-03):**

1. Render the proposal into a **self-contained HTML** file (all CSS inline; template + typography floors in `references/pdf-pipeline.md`).
2. Chrome headless HTML -> PDF (this exact command produced a valid PDF in test):
   ```bash
   google-chrome-stable --headless --disable-gpu --no-sandbox \
     --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header \
     "$HTML" 2>/dev/null
   ```
   Binary verified at `/usr/bin/google-chrome-stable` (Chrome 144). Fallbacks in order: `google-chrome` (`/opt/google/chrome/google-chrome`), then `chromium`.
3. **Client-editable copy** (when the client will edit / redline): `pandoc <md> -o <docx>` WORKS with no LaTeX (verified, produced a valid docx). Optionally `soffice --headless --convert-to pdf --outdir <dir> <docx>` also works (LibreOffice 26.2, verified) as a second PDF route.
4. **VERIFY** the PDF exists and is > 0 bytes (`test -s "$PDF"`, V7). NEVER claim a PDF that does not exist.

**Typography floors in the template (`feedback_ui_typography_floors` + `feedback_no_monospace_unless_archetype`):** body >= 12px, every text element font-weight >= 500. Monospace ONLY inside a code or architecture-diagram block (their legitimate archetype), never for labels or metadata. **Do NOT copy `/invoice`'s CSS sizing**: its label styles use 10 to 11px (below the 12px floor). The proposal template in `references/pdf-pipeline.md` already sits at/above 12px.

Full recipe, HTML template, the "which format when" table, and the failure playbook: **`references/pdf-pipeline.md`**.

===============================================================================
## 6. NUMBERING AND THE RECORD STORE (PROP-YYYYMM-NNN)
===============================================================================

A proposal is a numbered business document. Every run writes a JSON record; the number is computed from the store, like `/invoice`'s `INV-YYYYMM-NNN`.

```bash
mkdir -p ~/.claude/proposals ~/Documents/proposals   # first run; ~/.claude/proposals did not exist before
ym=$(TZ=Asia/Jakarta date +%Y%m)
last=$(find ~/.claude/proposals -maxdepth 1 -name "PROP-${ym}-*.json" 2>/dev/null \
        | sed -E 's/.*PROP-[0-9]{6}-([0-9]{3})\.json/\1/' | sort -n | tail -1)
if [ -z "$last" ]; then n=1; else n=$((10#$last + 1)); fi
prop=$(printf "PROP-%s-%03d" "$ym" "$n")
```

`find` (not a raw glob) so an empty dir does not error under zsh nullglob.

### Record schema (`~/.claude/proposals/PROP-YYYYMM-NNN.json`)

```json
{
  "proposal_number": "PROP-202607-001",
  "date": "2026-07-03",
  "valid_until": "2026-08-02",
  "version": "1.0",
  "status": "draft",
  "client": { "name": "...", "contact": "...", "email": null },
  "project": "...",
  "engagement_type": "build",
  "currency": "IDR",
  "subtotal": 187500000,
  "tax_name": "PPN",
  "tax_rate": 0.11,
  "tax_amount": 20625000,
  "total": 208125000,
  "milestones": [
    { "description": "<Project> - Milestone 1: Kickoff (30%)", "detail": "On signing", "qty": 1, "unit_price": 56250000, "amount": 56250000 },
    { "description": "<Project> - Milestone 2 (40%)", "detail": "Core dev complete", "qty": 1, "unit_price": 75000000, "amount": 75000000 },
    { "description": "<Project> - Milestone 3 (30%)", "detail": "UAT sign-off / BAST", "qty": 1, "unit_price": 56250000, "amount": 56250000 }
  ],
  "pdf_path": "/home/christopher/Documents/proposals/PROP-202607-001.pdf",
  "md_path": "/home/christopher/Documents/proposals/PROP-202607-001.md",
  "created_at": "2026-07-03T10:00:00+07:00"
}
```

- `status`: `draft` -> `sent` -> `won` | `lost` (flip on Christopher's word; win/loss gives a win-rate view later).
- `valid_until` = date + 30 days (`date -d "+30 days" +%Y-%m-%d`, verified).
- The PROP JSON is a **private record** (like `/case-study`'s evidence ledger): it may store the local `pdf_path` (V5 only gates the client-facing doc, not this record).
- **Save-location for the human docs:** `./proposals/` when invoked inside a project directory, else `~/Documents/proposals/` (mirrors `/invoice`). The PROP JSON always lives in `~/.claude/proposals/`.

===============================================================================
## 7. ANTI-GENERIC SCORING (rule 7 enforcement, SEPARATE from the boolean gates)
===============================================================================

Score the draft 0 to 2 on each. **Ship only at >= 9/12, and none of the three starred rows may be 0.** Kept separate from the section 0.4 boolean gates so a good score can never average away a mechanical failure (the `/case-study` pattern).

| # | Criterion | 0 | 1 | 2 |
|---|---|---|---|---|
| 1* | **Out-of-Scope is specific to THIS project** (rule 7) | generic/reusable | some specific | every item project-named |
| 2* | **Every feature has a testable acceptance criterion** | missing/vague | most | all falsifiable |
| 3* | **Scope fits the engagement type** (rule 2) | crosses the line | mostly | clean fit, QA firewall intact |
| 4 | Value props are quantified, not vague | "improve UX" | mixed | "5 steps to 2" |
| 5 | Estimates honest, buffered, discovery-flagged | invented | mixed | clean + assumptions listed |
| 6 | Team is the real roster, not padded (rule 4) | 6-role agency default | mixed | real people |

**The swap test (boolean, in the delivery gate):** could this proposal be sent to a different client by swapping only the name? If yes, it is generic, rewrite it until no. A starred-row 0 is an automatic fail regardless of total.

Replacement discipline: every time you cut a generic line, the fix is a **concrete detail this project actually has** (the client's real platform boundary, the named legacy system, the specific content they provide), not a softer adjective.

===============================================================================
## 8. ONE COMPACT WORKED EXAMPLE (full example in references)
===============================================================================

Input: `/proposal "Lancar Jaya, a Jakarta retail SMB, needs a multi-tenant POS to replace spreadsheets, offline-capable on Android, integrate Midtrans" --type build`

- **Classify:** `build` (end-to-end system). Not `qa`, not `fixed`.
- **Discovery floor:** client + project + build-a-POS + core features known; budget `[TBD]` (asked), timeline "before Ramadan" captured, integrations = Midtrans (+ `[TBD]` others).
- **Scope:** Modules {Auth+tenants, Catalog, Offline order capture, Sync, Midtrans payments, Reports}. Each feature gets a falsifiable acceptance criterion (offline order syncs within 60s of reconnect, no dupes).
- **Out-of-Scope (project-specific):** native iOS/Android apps (responsive PWA only, staff use Android Chrome); migration of the client's existing spreadsheets (a separate `discovery` workstream); Midtrans account fees (client bears); hardware (client supplies the Android devices).
- **Stack note (2d):** the web build carries next-intl (id+en) + next-themes from commit 0.
- **Estimate:** decomposed, +20% buffer, rounded. Subtotal `Rp 162.500.000`, PPN `Rp 17.875.000`, total `Rp 180.375.000`. 30/40/30 base = `Rp 48.750.000 / 65.000.000 / 48.750.000` (sums to the subtotal exactly; `/invoice` adds PPN per milestone). Numbers illustrative, rate is `[TBD]`.
- **Team:** Christopher (build) + Suryadi (commercial). No padding.
- **Render:** HTML -> `google-chrome-stable` PDF, `test -s` passes. docx via pandoc for the client to redline.
- **Record:** `PROP-202607-001.json`, status `draft`, milestones stored.
- **Report:** files + totals + `[TBD]`s + the `/invoice` handoff command. Nothing sent.

The full filled proposal (Indonesian SMB, IDR, PPN, 30/40/30, project-specific exclusions, end to end): **`references/worked-example.md`**. Its numbers are illustrative, never copy them as facts.

===============================================================================
## 9. FAILURE MODES (smell -> fix)
===============================================================================

| Failure mode | Smell | Fix / recovery |
|---|---|---|
| **Broken PDF path** | "convert with pandoc/md-to-pdf", or a claimed PDF that does not exist | Chrome-headless HTML->PDF (section 5); `test -s` before claiming; docx via pandoc. `references/pdf-pipeline.md`. |
| **Currency incoherence** | `$X,XXX`, USD on a local client, no PPN line | IDR from config + PPN line (0.3); USD only on `--intl`; V6 grep. |
| **Scope-fit violation** | QA engagement scopes "we will fix the bugs" / architecture | rule 2 QA firewall; re-scope to suites/findings/coverage; `references/engagement-playbooks.md`. |
| **Template blast** | passes the swap test as generic; reusable Out-of-Scope | section 7 score + swap test; name THIS project's boundaries. |
| **Invented numbers** | a rate/headcount/metric with no source | `[TBD]` + Assumptions row (rule 3); never fabricate. |
| **Padded team** | default 6-role agency lineup on a 2-person shop | real roster (rule 4); scale to the playbook. |
| **Legal overreach** | IP/confidentiality/T&C shipped as final | DRAFT banner (rule 5); commercial terms are Suryadi/counsel. |
| **Em/en dash leak** | a long dash in the client PDF | V1 grep silent before delivery (rule 0.1). |
| **Thin discovery** | generated with unknown type/budget/timeline | discovery floor (1c); ask (blocking) or `[TBD]`. |
| **Auto-send** | the proposal got transmitted to the client | NEVER (rule 6); generator only, hand off to Christopher/Suryadi. |
| **Sub-floor typography** | copied `/invoice`'s 10-11px labels | template >= 12px, weight >= 500, mono only in code (section 5). |
| **No record** | file written, no PROP number, no JSON | section 6; `mkdir -p`, compute number, write record every run. |

===============================================================================
## EXECUTION FLOW
===============================================================================

1. **Parse** `$ARGUMENTS` + flags (section 1a). Read the shared config `~/.claude/invoices/config.json` for company + currency + tax (rule 0.3).
2. **Classify** the engagement type (1b); load its playbook from `references/engagement-playbooks.md`. Ask if ambiguous.
3. **Discovery floor** (1c): batched questions until the 8 fields are known or `[TBD]`. Confirm understanding in 3 to 4 bullets before writing.
4. **Scope** (section 2): feature table with acceptance criteria + project-specific Out-of-Scope. Pull section boilerplate from `references/section-library.md`. Apply the 2d website baseline note if a website is scoped.
5. **Estimate + price** (section 3): decompose, +20% buffer, round; IDR + PPN from config; 30/40/30 milestones (integers summing exactly).
6. **Assemble** the markdown to the `references/section-library.md` structure, in the honest professional voice, DRAFT banner on commercial clauses (rule 5), Assumptions and Open Questions section non-empty.
7. **Score** (section 7): anti-generic >= 9/12, no starred 0, swap test fails-as-generic == false. Rewrite generic lines with real details.
8. **Render** (section 5): self-contained HTML -> Chrome-headless PDF; docx via pandoc if the client edits; `test -s` the PDF (V7).
9. **VERIFY** (section 0.4): run V1 to V7 on every produced file; all silent/pass.
10. **Record** (section 6): `mkdir -p`, compute PROP-YYYYMM-NNN, write the JSON with milestones + status `draft`.
11. **Report as tables** (`feedback_visual_structured_docs`): (a) files landed (md | pdf | docx | PROP json), (b) totals (subtotal | PPN | total | 30/40/30), (c) open items ([TBD]s + assumptions), (d) the `/invoice` handoff command for when it is won. **Send nothing** (rule 6).

## COMPOSES WITH

- **/outreach** warms the lead; its cover blurb points at the proof, `/proposal` scopes the deal.
- **/invoice** bills the milestones (4b handoff, shared config, INV-YYYYMM-NNN); **/worklog** feeds it hours. Neither writes the other's store.
- **/case-study** supplies proof-points for the proposal's credibility (a shipped, relevant project).
- **/handover** produces the BAST + delivery docs at the end; **/status-report** the weekly updates. Not this skill's lane.

Remember: this is Christopher's name on a document a client uses to decide whether to pay him. Its value is that it is honest, specific, correctly scoped to the real engagement, and priced coherently with how it will be billed. Scope only what the engagement covers, price in real IDR, verify the PDF, and let Christopher send it.
