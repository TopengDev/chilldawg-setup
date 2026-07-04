# references/engagement-playbooks.md: the six engagement types

Progressive-disclosure companion to `SKILL.md` sections 1 and 2. SKILL.md rule 1 says classify the engagement before scoping; rule 2 says never scope outside the type. This file is the per-type scope contract each proposal must obey.

**How to use:** after `SKILL.md` section 1b fixes the type, open that type's block here. Scope ONLY the "Scope IN" column, EXPLICITLY exclude the "Scope OUT" items in the proposal's Out-of-Scope section (they are the project-specific exclusions rule 7 wants), size the team to "Team shape", and price with "Pricing model". A scope that crosses into another type's territory is a DELIVERY-GATE scope-fit failure (section 7 row 3).

The default the old skill assumed (a full agency build with a 6-role team) is ONLY the `build` type, and even then the team is the real roster, not a padded lineup.

---

## Type selector (one line each)

| Type | The client is paying us to | Signature deliverable |
|---|---|---|
| `build` | Build a working system for them, end to end | Deployed application + handover |
| `qa` | Test a system THEY (or another vendor) built | Test suites + findings reports |
| `staff-aug` | Add engineering capacity to their team | Hours of a named role, their direction |
| `fixed` | Deliver one bounded thing for one fixed price | The one bounded output |
| `maintenance` | Keep an existing system healthy on a retainer | Monthly support within a tier |
| `discovery` | Figure out WHAT to build (paid scoping) | Requirements + design + a follow-on proposal |

When two types both seem to fit, the honest split is usually: is the client's system already built (then `qa` or `maintenance`) or are we building it (`build` or `fixed`)? Is it open-ended capacity (`staff-aug`) or a bounded output (`fixed`)? Ask if still unclear (SKILL.md 1b).

---

## 1. `build` (full end-to-end build)

The system Aenoxa builds and delivers. This is the only type where the full section-library.md structure applies in full.

| | |
|---|---|
| **Scope IN** | Requirements refinement, UI/UX design, architecture, feature development in 2-week sprints, integrations, QA (our own), UAT support, production deploy, technical handover, warranty. |
| **Scope OUT (name these in Out-of-Scope)** | Content/copy/translations the client provides; data migration from their legacy system (offer as a separate workstream); third-party subscription fees; hardware; native mobile if the build is web (state it); post-warranty maintenance (its own section); anything past the agreed feature list (change-request process). |
| **Team shape** | Christopher (technical build, architecture, delivery) + Suryadi (commercial, client comms, demos). Named contractors ONLY if a real one is engaged (never a placeholder designer/PM). Do not present a 6-role lineup. |
| **Pricing model** | Fixed price by phase, or time-and-materials with a not-to-exceed cap. 30/40/30 milestone schedule. |
| **Timeline** | Phased: Discovery+Design, Foundation, Core Dev (sprints), Integrations+Polish, QA, UAT, Deploy+Handover. |
| **The trap** | Padding the team + under-specifying Out-of-Scope. A build proposal wins or loses on the exclusions being airtight. |
| **Website builds** | If a website is scoped, the stack carries next-intl (id+en) + next-themes from commit 0 (SKILL.md 2d), unless it is a one-shot pitch demo (light-only exception). |

---

## 2. `qa` (testing engagement) -- THE FIREWALL

We test a system someone else owns. This is Christopher's real bread-and-butter (ISI/BMS fitest QA), and the type most likely to be mis-scoped into overpromising. `feedback_qa_scope_discipline` governs it, quoted here so it is impossible to miss:

> "Our role at ISI is QA (testing), not dev/architecture. Report the test FINDING + flag the blocker, but do NOT suggest or prescribe dev-side actions / solutions beyond QA scope. The dev team decides the fix; QA reports the observation." Verified violation (2026-06-03): writing "deploy tabel limit-transaction ke env terus saya re-run" prescribed a DEV action, beyond QA scope.

| | |
|---|---|
| **Scope IN** | Test plan + test-suite authoring; manual and/or automated test execution; findings reports (severity-graded); coverage reporting; regression re-runs; test-data and environment-state notes; ticket status recommendations (open/close/on-hold per the test verdict); UAT facilitation. |
| **Scope OUT (HARD, name these)** | **Fixing the bugs. Changing the client's code. Architecting or re-architecting anything. Infra/deploy/DB changes ("deploy the table", "add a CF rule", "redeploy X"). Prescribing dev-side solutions.** We report findings; the client's dev team decides and implements fixes. Also out: building features, writing production code, owning the release. |
| **Team shape** | Christopher (QA/test authoring + execution). No "Lead Developer", no "Architect" role, because we are not doing dev. |
| **Pricing model** | Per suite authored, per test cycle/run, or a QA day-rate. NOT a fixed "we will make it bug-free" price (that implies we fix, which we do not). |
| **Deliverables** | Test suites, execution reports, a findings log, coverage summary, re-run results. NOT a fixed defect count resolved. |
| **The trap** | A single sentence that prescribes a dev action ("we will fix", "you should deploy", "change X in the backend") converts a clean QA proposal into a scope violation. Grep the draft for fix/deploy/architect/refactor verbs applied to the client's system and rewrite them as findings ("we will REPORT that X fails and flag the blocker for your dev team"). |

**QA proposal language pattern (do / do not):**
- DO: "We author and run a regression suite covering the payment flows and deliver a severity-graded findings report each cycle."
- DO: "Where a test blocks on an environment gap, we flag it plainly and defer the disposition to your team."
- DO NOT: "We will fix the failing payment webhook." (that is dev, out of scope)
- DO NOT: "We will re-architect the sync layer for reliability." (architecture, out of scope)
- DO NOT: "We will deploy the missing table and re-run." (infra/dev, out of scope)

---

## 3. `staff-aug` (embedded capacity)

We rent capacity to the client's team; they direct the work day to day.

| | |
|---|---|
| **Scope IN** | A named role (e.g. senior fullstack engineer) for a number of hours/days per week/month; participation in the client's process (their standups, board, repo); ways-of-working (comms channel, hours, timezone overlap). |
| **Scope OUT** | Fixed deliverables or outcome guarantees. Because THEY direct the work, we do not commit to shipping feature X by date Y; we commit to CAPACITY. Also out: owning their architecture decisions, hiring/managing their other staff. |
| **Team shape** | The specific person(s) and their role + seniority. Rate is per role. |
| **Pricing model** | Monthly rate per role (or day-rate x days), an hours cap, and an overage rate. Not milestone-based. Minimum commitment period if any. |
| **Deliverables** | Timesheets (via `/worklog`) and whatever the client's board assigns; NOT a fixed feature list from us. |
| **The trap** | Writing fixed deliverables/acceptance-criteria as if it were a `build`. Staff-aug scopes hours and a role, not outcomes. If the client wants guaranteed outcomes, it is a `build` or `fixed`, re-classify. |

---

## 4. `fixed` (one bounded deliverable, one price)

A single tightly-bounded output: a landing page, one integration, a one-off audit, a migration.

| | |
|---|---|
| **Scope IN** | Exactly one bounded output, spelled out with acceptance criteria. Revisions rounds (state how many). |
| **Scope OUT** | Anything past that one output. This type lives or dies on a razor-sharp boundary: name what is NOT the deliverable explicitly (no ongoing support, no adjacent feature, no "while you are at it"). |
| **Team shape** | Usually Christopher solo, or + one contractor for a specialty. |
| **Pricing model** | One fixed price. An explicit change-request rate for anything outside the boundary. Optionally 50/50 (deposit/delivery) instead of 30/40/30 for a short engagement. |
| **Deliverables** | The one output + its source/assets + a short handover if code. |
| **The trap** | Scope creep past the single output. Every "can you also..." is a change request at the stated rate, not a freebie. Say so in the proposal. |

---

## 5. `maintenance` (retainer / support)

Ongoing support of an EXISTING system on a monthly retainer (recurring revenue, `project_software_house` phase 5).

| | |
|---|---|
| **Scope IN** | A support tier: a monthly hours cap, a response-time SLA, what the hours cover (bug fixes, minor updates, security patches, small enhancements per tier). |
| **Scope OUT** | New feature builds beyond the tier (those are a `build`/`fixed` change order); rewrites; supporting environments we did not build (unless scoped); third-party outages. |
| **Team shape** | Christopher on call within the SLA. |
| **Pricing model** | Monthly retainer per tier + an overage rate per hour past the cap. Month-to-month with a notice period (e.g. 30 days). Unused hours do not roll over (state it). |
| **Tiers (adapt, price with real numbers or [TBD]):** | Essential (small cap, business-hours SLA); Growth (mid cap, faster SLA, enhancements); Scale (large cap, critical SLA, continuous capacity). Do not invent the rupiah amounts; ask or `[TBD]`. |
| **The trap** | Treating the retainer as unlimited work. The cap + overage rate + tier boundaries are what make it sustainable; without them it becomes free unbounded labor. |

---

## 6. `discovery` (paid scoping only)

The client pays for us to figure out WHAT to build. The honest answer when a `build` proposal would be too speculative to estimate.

| | |
|---|---|
| **Scope IN** | Requirements gathering, stakeholder interviews, technical design, architecture options, a risk assessment, and a follow-on build proposal + estimate as the deliverable. |
| **Scope OUT** | Any build commitment. Discovery produces the plan; the BUILD is the next, separate proposal. No code shipped (a throwaway prototype only if explicitly scoped). |
| **Team shape** | Christopher (technical discovery) + Suryadi (commercial framing of the follow-on). |
| **Pricing model** | A flat discovery fee. Often credited against the build if the client proceeds (state whether it is). |
| **Deliverables** | A discovery document: requirements, technical design, options with trade-offs, risks, and a scoped follow-on build proposal. |
| **The trap** | Doing free discovery inside a build proposal. If too much is unknown to estimate the build honestly (SKILL.md rule 3), propose paid discovery FIRST rather than padding a build estimate with guesses. |

---

## Cross-type rules

- **Every type still obeys the SKILL.md non-negotiables:** no invented numbers, real team only, IDR + PPN from config, DRAFT banner on commercial terms, generator-not-sender, no em/en dash.
- **Every type has a project-specific Out-of-Scope** (rule 7); the "Scope OUT" rows above are the STARTING material, made concrete for THIS client.
- **When the client's ask spans two types** (common: "test it AND fix what you find"), do NOT silently merge them into one overscoped QA-plus-dev blob. Either propose the QA engagement (findings only) and note that fixes are a separate `build`/`fixed` change order, or propose a `build` if we are actually owning the code. Name the split; let the client choose. Merging is how the QA firewall gets breached.
- **The engagement type is recorded** in the PROP JSON `engagement_type` field (SKILL.md section 6), so a later `/invoice` and any win/loss analysis know what kind of deal it was.
