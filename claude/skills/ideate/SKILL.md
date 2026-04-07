---
name: ideate
description: Structured ideation-to-execution framework. Takes a raw idea and develops it through capture, validation, scoping, architecture, and build planning. Use when the user has a new project idea or says /ideate.
argument-hint: [idea description or "continue" to resume from last phase]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, WebSearch, WebFetch, Agent
---

# Ideation Framework

Christopher's initial idea is typically ~1% of what's in his head. This skill systematically extracts the full vision, validates it, scopes it, and plans the build — producing concrete artifacts at each phase.

Parse `$ARGUMENTS`:
- If arguments contain an idea description → start at **Phase 1: Capture**
- If arguments say "continue" or reference a phase → read the project's ideation docs and resume from the appropriate phase
- If no arguments → ask what the idea is

## Important Rules

1. **Each phase produces a document** saved to `~/claude/Git/repositories/{project-name}/docs/ideation/` — these are the source of truth, not memory.
2. **Never skip phases** — each phase depends on the output of the previous one.
3. **Never assume** — if something is ambiguous, ask. Christopher's vision is specific even when his words aren't yet.
4. **Research must be ultra-thorough** — when validating or architecting, use web search, context7, official docs. No shallow takes.
5. **Each phase should ideally run in its own session** due to context size. At the end of each phase, summarize what was decided and tell Christopher to start a new session with `/ideate continue` for the next phase.
6. **Save key decisions to memory** — project memories for the new project should be created/updated as decisions are locked.

---

## Phase 1: CAPTURE — Extract the Full Vision

**Goal:** Go from a vague idea to a comprehensive vision document.

### Step 1: Mirror Back
Restate the idea in your own words to confirm you understood the core concept. Be specific about what you think Christopher means.

### Step 2: Structured Probing
Ask targeted questions across these dimensions. Don't dump all questions at once — go dimension by dimension, 3-5 questions per round, and let Christopher respond before moving to the next.

**Dimensions to probe:**

1. **Core Value Proposition**
   - What problem does this solve? Who has this problem?
   - What's the current alternative? Why is it inadequate?
   - What makes this solution uniquely better?

2. **Users & Personas**
   - Who are the primary users? Secondary users?
   - What's their technical level? Their workflow?
   - What does their day look like before vs after using this?

3. **User Flows & Features**
   - Walk through the core user journey end-to-end
   - What are the critical features vs nice-to-haves?
   - What happens at each decision point?
   - What are the edge cases and failure states?

4. **Business Model**
   - How does this make money? (SaaS, one-time, freemium, marketplace?)
   - What's the pricing intuition? Who pays?
   - What's the growth loop?

5. **Constraints & Context**
   - Tech stack preferences or requirements?
   - Budget and timeline constraints?
   - Integration requirements? (APIs, services, platforms)
   - Deployment target? (VPS, Vercel, cloud?)
   - Regulatory or compliance considerations?

6. **Competitive Landscape**
   - Who else does something similar?
   - What's the differentiation?
   - What can we learn from their approach?

### Step 3: Expansion Loop
After each round of answers:
- Identify branches and possibilities that Christopher's answers opened up
- Ask follow-up questions on those branches
- Let Christopher confirm what's in scope vs out of scope
- Repeat until Christopher says "that's everything" or the vision feels complete

### Step 4: Produce Vision Document
Create `~/claude/Git/repositories/{project-name}/docs/ideation/01-vision.md`:

```markdown
# {Project Name} — Vision Document

## One-Liner
{What it is in one sentence}

## Problem
{The problem being solved, who has it, why current solutions fail}

## Solution
{How this product solves it, what makes it unique}

## Users
{Primary and secondary personas with context}

## Core User Flows
{End-to-end journeys, step by step}

## Feature Map
### Must Have (MVP)
### Should Have (v2)
### Nice to Have (v3+)

## Business Model
{How it makes money, pricing intuition, growth loop}

## Constraints
{Tech, budget, timeline, integrations, deployment}

## Open Questions
{Anything still unresolved}
```

Tell Christopher: "Phase 1 complete. Vision locked. Start a new session and run `/ideate continue` for Phase 2: Validation."

---

## Phase 2: VALIDATE — Is This Worth Building?

**Goal:** Research-backed go/no-go decision.

### Step 1: Read the Vision Document
Read `~/claude/Git/repositories/{project-name}/docs/ideation/01-vision.md` to load context.

### Step 2: Research
Investigate thoroughly:

1. **Market Validation**
   - Search for existing solutions, competitors, alternatives
   - Analyze their pricing, features, reviews, weaknesses
   - Look for market size indicators (search volume, community size, funding in the space)

2. **Technical Feasibility**
   - Can this actually be built with the proposed stack?
   - Are there critical dependencies that are risky (unmaintained libs, complex integrations)?
   - What's the hardest technical challenge? Is it solvable?

3. **Effort vs Impact**
   - Rough estimate of build complexity (simple / moderate / complex / massive)
   - How quickly can an MVP be shipped?
   - What's the expected impact relative to effort?

4. **Alignment Check**
   - Does this align with Aenoxa's direction?
   - Does Christopher have bandwidth for this given current projects?
   - Is the timing right?

### Step 3: Present Findings
Present a clear recommendation:
- **GO** — the idea is viable, differentiated, and buildable. Here's why.
- **PIVOT** — the core idea has merit but needs adjustment. Here's what to change.
- **PARK** — not the right time or not enough differentiation. Save for later.

### Step 4: Produce Validation Report
Create `~/claude/Git/repositories/{project-name}/docs/ideation/02-validation.md`:

```markdown
# {Project Name} — Validation Report

## Verdict: {GO / PIVOT / PARK}

## Market Analysis
{Competitors, market size, gaps, opportunities}

## Technical Feasibility
{Stack viability, hard problems, dependencies}

## Effort Estimate
{Complexity, timeline estimate, resource requirements}

## Risks
{Top 3-5 risks and mitigations}

## Recommendation
{Clear next steps}
```

If GO → tell Christopher to continue to Phase 3.
If PIVOT → discuss adjustments, update vision doc, then re-validate.
If PARK → save the idea to tasks as LATER tier, end the flow.

---

## Phase 3: SCOPE — Define the MVP

**Goal:** Cut the vision down to the smallest thing that delivers core value.

### Step 1: Read Previous Docs
Read vision + validation docs.

### Step 2: MVP Definition
Work with Christopher to answer:
- What is the ONE core flow that must work for this to be useful?
- What's the absolute minimum feature set for that flow?
- What can be manual/hacky in v1 that gets automated later?
- What's the launch criteria? (When is it "done enough" to ship?)

### Step 3: Phase Roadmap
Break the full feature map into shipping phases:
- **MVP (v1)** — core value, ship in X weeks
- **v2** — enhanced experience, based on v1 feedback
- **v3+** — full vision, scale features

### Step 4: Produce Scope Document
Create `~/claude/Git/repositories/{project-name}/docs/ideation/03-scope.md`:

```markdown
# {Project Name} — MVP Scope

## Core Flow
{The one critical user journey}

## MVP Features
{Exact feature list with acceptance criteria}

## Explicitly Out of Scope for MVP
{Features deferred to v2+, and why}

## Launch Criteria
{Definition of done for v1}

## Phase Roadmap
### v1 (MVP)
### v2
### v3+

## Success Metrics
{How do we know v1 worked?}
```

---

## Phase 4: ARCHITECT — Design the System

**Goal:** Research-backed architecture and tech decisions.

### Step 1: Read Previous Docs
Read vision + validation + scope docs.

### Step 2: Research Best Approach
For each major technical decision:
- Research current best practices (use context7, web search, official docs)
- Compare options with trade-offs
- Consider Christopher's existing infrastructure (VPS, Cloudflare, tech preferences)

### Step 3: Design
Produce architecture covering:
- **System overview** — components and how they connect
- **Data model** — entities, relationships, storage
- **API design** — endpoints, contracts, auth
- **Tech stack** — exact tools, frameworks, versions with justification
- **Infrastructure** — hosting, deployment, CI/CD
- **Security model** — auth, encryption, access control

### Step 4: Review with Christopher
Present the architecture, highlight trade-off decisions, get alignment.

### Step 5: Produce Architecture Document
Create `~/claude/Git/repositories/{project-name}/docs/ideation/04-architecture.md`

---

## Phase 5: PLAN — Break Down the Build

**Goal:** Turn architecture into an actionable task breakdown.

### Step 1: Read Architecture Doc

### Step 2: Create Task Breakdown
Break the MVP into ordered implementation tasks:
- Group by milestone (e.g., "data layer", "core API", "frontend", "auth", "deploy")
- Each task should be independently completable in one session
- Include acceptance criteria per task
- Identify dependencies between tasks

### Step 3: Produce Build Plan
Create `~/claude/Git/repositories/{project-name}/docs/ideation/05-build-plan.md`

Also create tasks in the task system (`~/.claude/tasks/{project-name}.md`) with proper tiers.

### Step 4: Initialize Project
Run `/project-init` with the decided stack to scaffold the repo.

Tell Christopher: "Ready to build. Start a new session in the project directory and follow the build plan."

---

## Phase 6: BUILD — Implementation Loop

**Goal:** Build the product following the plan.

For each milestone:
1. **Implement** — write code following the architecture doc
2. **Self-review** — re-read what you wrote, check for issues
3. **Test** — write and run tests for the new code
4. **Commit** — use `/commit`

At milestone boundaries (every 3-5 tasks or at natural breakpoints):
- **Security audit** — review for vulnerabilities (OWASP top 10)
- **Performance review** — check for N+1 queries, unnecessary re-renders, missing indexes
- **Design review** — does the UX match the vision? Is it intuitive?
- Update the build plan with progress and any adjustments

---

## Phase 7: SHIP — Deploy and Launch

**Goal:** Get the product live.

1. **Pre-flight** — run `/preflight` for final checks
2. **Deploy** — set up hosting, DNS, SSL
3. **Smoke test** — verify core flow works in production
4. **Monitor** — set up basic error tracking / logging
5. **Document** — update README, create user-facing docs if needed
6. **Ship it** — announce, share, get feedback
