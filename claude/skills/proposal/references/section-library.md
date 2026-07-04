# references/section-library.md: the full proposal section boilerplate

Progressive-disclosure companion to `SKILL.md` section 2c. This carries the complete section-by-section structure of a proposal document. Nothing from the previous single-file skill was lost; it relocated HERE so SKILL.md stays load-bearing. The load-bearing rules and gates stay in SKILL.md; this is the assembly reference.

**Apply throughout:** IDR + PPN (never USD unless `--intl`); no em/en dash, no emoji (SKILL.md 0.1/0.2); every number real, `[TBD]`, or a labeled estimate; commercial/legal clauses under the DRAFT banner (rule 5). Scale which sections appear to the engagement type (`references/engagement-playbooks.md`): a `qa` or `staff-aug` proposal drops the build-only sections (architecture, warranty-as-build) and centers its own.

The document is one markdown file, `---` between major sections as page breaks, rendered to PDF via `references/pdf-pipeline.md`.

---

## COVER PAGE

```
# <Project Name>
## Technical Proposal and Statement of Work

Prepared for:  <Client Name>
Prepared by:   <Company Name from config, NEVER hardcoded>
Proposal no.:  PROP-YYYYMM-NNN
Date:          <today, WIB>
Valid until:   <date + 30 days>
Version:       1.0
Engagement:    <build | qa | staff-aug | fixed | maintenance | discovery>
Classification: Confidential
```

Company identity (name, and in the footer NPWP/contact) is read from `~/.claude/invoices/config.json`, never a hardcoded "Aenoxa" placeholder.

---

## TABLE OF CONTENTS

A numbered TOC of the major sections that actually appear (drop sections the engagement type does not use). Keep numbering contiguous.

---

## 1. EXECUTIVE SUMMARY

2 to 3 short paragraphs:
- **The opportunity:** what the client needs and why, reflected back in their language (proves you understood their business, not just the tech).
- **Our approach:** high-level of what we will do and how.
- **Key value propositions:** 3 to 5 bullets, concrete and QUANTIFIED where possible ("cut manual reconciliation from ~4 hours/day to under 30 minutes", not "improve efficiency"). Vague value props fail the anti-generic score (SKILL.md section 7 row 4).
- **Engagement overview:** timeline range, team, investment range (brief; details later).

Tone: confident, not arrogant; client-focused, not a tech brag.

---

## 2. SCOPE OF WORK

The feature table (with mandatory testable acceptance criteria) and the project-specific Out-of-Scope list are specified in **SKILL.md section 2** (they are load-bearing gates, so they live there). Assemble them here in the document. Priority levels: Must-have (base price), Nice-to-have (priced as an option in section 6), Future (named, deferred, unpriced).

For a `qa` engagement, "scope" is the test-suite/coverage plan, not features to build (`references/engagement-playbooks.md` type 2).

---

## 3. TECHNICAL APPROACH

(Full for `build`; trimmed for `fixed`; minimal or omitted for `qa`/`staff-aug`/`maintenance`.)

### 3.1 Recommended Tech Stack

Table with a real justification per layer (never "modern and scalable"):

| Layer | Technology | Justification |
|-------|-----------|---------------|
| Frontend | e.g. Next.js 15 + React 19 | why: SSR for SEO, ecosystem, team fit |
| Styling | e.g. Tailwind CSS v4 | why |
| Backend/API | e.g. Next.js routes / Go / FastAPI | why |
| Database | e.g. PostgreSQL | why |
| Auth | e.g. Auth.js / the Aenoxa auth system | why |
| Hosting | e.g. the Aenoxa VPS / Vercel | why |
| CI/CD | e.g. GitHub Actions | why |
| Monitoring | e.g. Sentry | why |

Choose on: project requirements (no sledgehammer for a nail), team expertise, maintainability, total cost of ownership, the client's existing infrastructure. **If a website is scoped, the stack includes next-intl (id+en) + next-themes from commit 0** (SKILL.md 2d), or the one-shot light-only exception.

### 3.2 Architecture Overview

Describe: the pattern (monolith / modular monolith / microservices, and why), the frontend/backend split (SSR/SPA/hybrid), data flow, API design (REST/GraphQL/tRPC, and why). Include a text architecture diagram in an `.arch` code block (mono is allowed here, it is a real code/diagram surface):

```
+-----------+     +-----------+     +--------------+
|  Browser  | --> |  CDN/Edge | --> |  App server  |
+-----------+     +-----------+     +------+-------+
                                          |
                                   +------+------+
                                   |             |
                             +-----v----+  +----v-----+
                             | Postgres |  | Storage  |
                             +----------+  +----------+
```

Adapt the diagram to the REAL architecture. Do not ship the sample verbatim.

### 3.3 Third-Party Integrations

| Service | Purpose | Method | Est. effort | Risk |
|---------|---------|--------|-------------|------|
| e.g. Midtrans | Payments | REST + webhooks | 3 to 5 days | Low |
| e.g. an email API | Transactional email | API | 1 to 2 days | Low |

Effort is a real estimate or `[TBD]`; never invented.

### 3.4 Infrastructure and Hosting

Hosting environment and why; estimated monthly infra cost as a RANGE (or `[TBD]`); scaling strategy; backup and disaster recovery; environments (dev/staging/prod).

### 3.5 Security Considerations

Auth and authorization approach; encryption at rest and in transit; input validation/sanitization; OWASP Top 10 posture; relevant compliance (state which apply, e.g. Indonesian PDP / PCI-DSS if payments); dependency scanning; secrets management. Keep it truthful to what will actually be done.

### 3.6 Performance Targets

| Metric | Target | How |
|--------|--------|-----|
| LCP | < 2.5s | SSR, CDN, image optimization |
| TTI | < 3.5s | code splitting, lazy load |
| API p95 | < 300ms | indexing, caching |
| Uptime | 99.9% | managed hosting, health checks, alerting |
| Lighthouse | > 90 | perf budget, CI checks |

Adjust to what is realistic for THIS project; do not promise numbers you cannot hit.

---

## 4. PROJECT TIMELINE

### 4.1 Phase Breakdown

Per phase: **Phase N: Name (duration)** with objective, key activities, milestone/deliverable, dependencies. Standard `build` phases (adapt): Discovery+Design, Foundation, Core Development (sprints if > 4 weeks), Integrations+Polish, QA+Testing, UAT+Revisions, Deployment+Handover.

### 4.2 Timeline Overview (Gantt)

A markdown Gantt using block characters (columns = weeks, adjust to real duration):

```
| Phase              | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 |
|--------------------|----|----|----|----|----|----|----|----|
| Discovery & Design | ## | ## |    |    |    |    |    |    |
| Foundation         |    | ## | ## |    |    |    |    |    |
| Core Development    |    |    | ## | ## | ## | ## |    |    |
| QA & UAT           |    |    |    |    |    | ## | ## |    |
| Deployment          |    |    |    |    |    |    |    | ## |
```

### 4.3 Estimation Methodology

State it plainly:
> All estimates include a 20% buffer for unforeseen complexity. Estimates are based on decomposition of the scoped work and our experience with similar projects. Final timelines are confirmed during the Discovery and Design phase.

(The method itself is SKILL.md section 3a: decompose, buffer, round, flag-for-discovery-what-you-cannot-estimate.)

### 4.4 Risks and Dependencies

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| e.g. third-party API change | High | Low | pin versions, abstract the integration |
| e.g. client feedback delays | Medium | Medium | 48h feedback SLA, parallel workstreams |
| e.g. scope expansion | High | Medium | change-request process with impact assessment |

---

## 5. TEAM AND RESOURCES

### 5.1 Team Composition (REAL roster only, rule 4)

Christopher (technical) + Suryadi (commercial) + any explicitly named contractor. NEVER the default 6-role agency lineup. Example honest shape for a solo-plus-commercial build:

| Role | Who | Responsibility | Allocation |
|------|-----|---------------|------------|
| Technical lead / build | Christopher | Architecture, development, delivery, technical handover | Full-time during build |
| Commercial / client lead | Suryadi | Client comms, sprint demos, commercial terms, UAT coordination | Part-time throughout |

Scale honestly. If a contractor is genuinely engaged for a specialty (e.g. a designer), name them; do not invent a role to look bigger.

### 5.2 Effort Estimate

| Phase | Days |
|-------|------|
| per phase | X or [TBD] |
| **Total** | **X person-days** |

Real numbers or `[TBD]`; underestimating erodes trust when timelines slip.

---

## 6. INVESTMENT

(IDR + PPN from config; the pricing mechanics, PPN calc, and 30/40/30 schedule are SKILL.md section 3.)

### 6.1 Cost Breakdown

| Phase | Effort (days) | Cost |
|-------|---------------|------|
| per phase | X | Rp ... |
| **Subtotal** | | **Rp ...** |
| **PPN (11%)** | | **Rp ...** |
| **Total** | | **Rp ...** |

If no day-rate is known, ask, else `[TBD]`; never the old `$[X]/person-day` placeholder.

### 6.2 Optional Items (nice-to-haves priced separately)

| Item | Effort | Cost | Notes |
|------|--------|------|-------|
| nice-to-have 1 | X days | Rp ... | can be added in phase N |

### 6.3 Payment Schedule

The 30/40/30 milestone table (SKILL.md section 3d), integer IDR, summing exactly to the total. Payment due within `payment_terms_days` (14) of milestone completion; next-phase work may pause on outstanding payment.

### 6.4 Not Included in the Price (client bears)

Third-party subscriptions (hosting, payment gateway fees, SaaS, API quotas); domain and SSL; app-store accounts if any; licensed fonts/stock; post-warranty maintenance (section 8).

---

## 7. DELIVERABLES

### 7.1 Core
- Source code (full repository access, all branches and history).
- Deployed application (production, on the agreed environment).
- Technical documentation (architecture, API docs, environment setup, deployment procedures).
- User guide for key workflows (if applicable).

### 7.2 Design Assets (if design is in scope)
- Design files (all screens, components, the design system).
- Style guide (color, typography, component library).

### 7.3 Knowledge Transfer
- Handover session (a walkthrough of codebase, architecture, deployment).
- Recorded demo (a video walkthrough of the features).

(Delivery/BAST documents themselves are the `/handover` skill's output, not this proposal.)

### 7.4 Warranty Period (build/fixed engagements)

> A 30-day warranty period (30 to 60 days per `project_software_house`) begins on the date of production deployment. During it we fix any defect where delivered functionality deviates from the agreed acceptance criteria, at no additional cost.
>
> The warranty COVERS: bugs where delivered functionality deviates from acceptance criteria; critical security vulnerabilities in our code; data-integrity issues caused by application defects.
>
> The warranty does NOT cover: new feature requests or enhancements; issues caused by client modifications to the codebase; third-party service outages or API changes; issues in environments we do not manage.

(This warranty split is strong; keep it. It does not apply to `qa`/`staff-aug`/`maintenance`, which have their own terms.)

---

## 8. MAINTENANCE AND SUPPORT OPTIONS

(For a `build`/`fixed` proposal offering ongoing support after warranty; a `maintenance` engagement makes this the CENTER, see `references/engagement-playbooks.md` type 5.)

| Tier | Hours/month | Response | Monthly cost | Best for |
|------|-------------|----------|--------------|----------|
| Essential | 5 | 48h (business) | Rp ... or [TBD] | bug fixes, minor updates, security patches |
| Growth | 15 | 24h (business) | Rp ... or [TBD] | enhancements, perf tuning, priority support |
| Scale | 40 | 4h (critical) | Rp ... or [TBD] | continuous development, new features |

> Unused hours do not roll over. Hours past the tier are billed at Rp .../hour. Agreements are month-to-month with 30 days written notice to cancel.

Never invent the rupiah tier prices; ask or `[TBD]`.

---

## 9. COMMERCIAL TERMS (DRAFT, rule 5)

Render this whole section under the DRAFT banner. The skill owns technical scope; these are Suryadi/counsel's to finalize in the contract.

> DRAFT terms, to be confirmed by Suryadi / counsel. This proposal covers technical scope; the commercial, IP, and confidentiality terms below are drafts finalized in the contract.

### 9.1 Change Request Process (keep, it is solid)

> Changes to the agreed scope are welcome and expected. Process: (1) client submits a written change request; (2) we assess impact on timeline and budget within 2 business days; (3) we provide a written impact assessment with revised estimates; (4) client approves or withdraws; (5) approved changes are documented as an addendum. Work on a change begins only after written approval. Changes may affect the timeline and total investment.

### 9.2 Intellectual Property (DRAFT)

> On receipt of final payment, IP rights to the custom-developed software transfer to the client (application source code, custom designs and assets, technical documentation). Excluded: pre-existing frameworks/libraries/tools (their own licenses), our internal tools/templates/methodologies, open-source components (their original licenses). We retain the right to reuse general knowledge and non-proprietary patterns.

(Flagged DRAFT: final IP language is the contract's, per rule 5.)

### 9.3 Confidentiality (DRAFT)

> Both parties keep confidential all proprietary information shared during the engagement (business strategies, technical specs, user data, financial terms), surviving termination for 2 years. Excludes information that is public, independently developed, or rightfully obtained from a third party.

### 9.4 Communication Protocol

> Primary channel: <ask, e.g. WhatsApp/email/PM tool>. Status updates: a weekly written progress report (the `/status-report` output). Sync: a weekly or bi-weekly call. Client feedback SLA: responses within 2 business days to hold the timeline. Escalation path: adapt to the real team. Feedback delays past 5 business days may adjust the timeline (communicated in advance).

### 9.5 Acceptance and Sign-off

> This proposal is valid for 30 days from the date of issue. To proceed, sign below or confirm in writing by email.
>
> Client approval:  Name ____  Title ____  Date ____  Signature ____

---

## APPENDIX: ASSUMPTIONS AND OPEN QUESTIONS (MANDATORY, non-empty)

Every `[TBD]`, every stated assumption ("assuming under 10,000 concurrent users", "assuming the client provides content"), and every open question goes here as a list or table. This is a DELIVERY-GATE item (SKILL.md): a proposal with unknowns and NO assumptions section is not done. It is also the honest hedge that lets the client correct a wrong assumption before signing.

| # | Item | Type | Needs |
|---|------|------|-------|
| 1 | Day-rate not provided | [TBD] | Christopher's blended rate |
| 2 | Assuming client provides all content/copy | assumption | client confirm |
| 3 | Integration list may be incomplete | open question | client confirm the full list |

---

## WRITING GUIDELINES (voice, carried forward)

**Tone:** professional but warm (not corporate robot, not casual freelancer); confident (state recommendations directly, no "perhaps we could potentially"); client-focused (their benefit, not our tech prowess); specific ("cut checkout from 5 steps to 2", not "improve UX").

**Estimates:** always the 20% buffer, stated; round to clean numbers; a range when genuinely uncertain, with what pushes the upper end; never estimate what you do not understand (flag for discovery, SKILL.md rule 3).

**Pricing:** use the client's day-rate if given, else `[TBD]`; always separate must-haves from nice-to-haves; never hide a cost the client will bear (list them, section 6.4); IDR + PPN (rule 0.3).

**Formatting:** consistent heading hierarchy (never skip levels); tables for structured data; blockquotes for terms and formal statements; bold for key terms not whole sentences; short paragraphs (3 to 5 sentences); `---` page breaks between major sections; no em/en dash, no emoji (rules 0.1/0.2).

**Handling unknowns (carried forward):** do not make up numbers (`[TBD]`); do not guess requirements (flag "to be confirmed during discovery"); DO make recommendations (stack, architecture, approach based on the description); DO note assumptions explicitly so the client can correct them; end with the Assumptions and Open Questions appendix.
