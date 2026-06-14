---
name: ideate
description: The structured on-ramp from a raw idea to a delegated, gated build. Triages the idea (L1/L2/L3), runs the L3 discovery+prototype+plan+sign-off gate, then drives the BUILD by delegating phased milestones to resumable background workers (3-tier hierarchy), with /audit at milestone boundaries and /ship to deploy. Orchestrates the real triage/3-tier/gate/delegate/audit/ship machinery — it does NOT run a parallel manual process. Use when Christopher has a new project/feature idea or says /ideate.
argument-hint: [idea description | "continue" to resume from the saved docs/ideation + STATE.md]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, WebSearch, WebFetch, Skill, Agent
---

# /ideate — raw idea → triaged → gated → delegated build

Christopher's stated idea is typically ~1% of what's in his head. This skill extracts the full vision, **decides how much process it deserves** (triage), runs the **discovery + prototype + plan + sign-off gate** for serious work, and then **drives the build by delegating phased milestones to resumable background workers** — exactly the flow that built `market-events-calendar` by hand. It is the FRONT DOOR to the operating model, not a replacement for it.

`/ideate` is an **orchestrator**. It does not invent its own task system, its own worker model, or its own audit. It drives the existing machinery: **Task Complexity Triage** (`~/.claude/CLAUDE.md`), the **3-Tier Task Hierarchy** (`triage.json` + initiative + per-task `STATE.md`), the **delegated resumable worker pipeline** (`spawn-worker.sh` → `brief-worker.sh` → `resume-worker.sh`), **`/audit`**, **`/ship`**, **`/commit`**, **`/project-init`**.

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES — READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

These are HARD rules. Violating any one is a failed ideation, not a stylistic choice. If anything below appears to conflict, the NON-NEGOTIABLE wins.

1. **TRIAGE IS PHASE 0. NO EXCEPTIONS.** Before any probing, any doc, any worker — classify the idea **L1 / L2 / L3** and print the `📊 TRIAGE` header. The level decides how much of this skill runs. Starting discovery/build without a triage classification is a hard violation. (Mirrors the mandatory triage rule in `~/.claude/CLAUDE.md`.)

2. **THE L3 GATE IS A HARD GATE, NOT A SUGGESTION.** For an L3 idea you are FORBIDDEN to write `triage.json` with `signoff:true`, create the initiative, or spawn ANY build worker until ALL of these have happened **in order**: (a) **≥10 clarifying questions asked** (10 is the FLOOR, not the target), (b) answers received from Toper, (c) **PROTOTYPE-FIRST gate passed** (Phase 2 — a throwaway POC that validates the riskiest assumption against a concrete pass/fail criterion), (d) **written plan presented**, (e) **Toper's explicit sign-off** ("approved" or equivalent). Skipping or reordering any step = failed gate. (This is the L3 HARD GATE from `~/.claude/CLAUDE.md`, enforced here.)

3. **BUILD = DELEGATE. NEVER BUILD IN MAIN.** The Build phase NEVER writes product code inline. Every milestone is handed to a **spawned background worker** with its own task dir (`triage.json` + `STATE.md` + `brief.md`), checkpoints, and `result.json`. Main session coordinates, polls (FleetView), and gates — it does not implement. (Mirrors "Main Session is DISCUSSION ONLY / delegate everything" — the old Phase 6 violated this and is deleted.) If you ARE a spawned worker that received a build brief, execute it directly — do not re-delegate.

4. **PROTOTYPE BEFORE PLAN — ALWAYS, FOR ANYTHING NEW.** No plan is written on unvalidated assumptions. If the idea touches anything new (a data source, an API, a library, an integration, a design direction), a **throwaway prototype** validates the riskiest assumption FIRST, with a stated pass/fail criterion, and its findings become planning inputs. (Mirrors "Prototype & Smoke Test Before Planning". market-events did this with a dedicated recon worker before its plan.)

5. **EACH PHASE PRODUCES A DOC IN `docs/ideation/` — THE SOURCE OF TRUTH.** Vision, validation, scope, architecture, plan are written to `~/claude/Git/repositories/{project}/docs/ideation/NN-*.md` (or `~/claude/notes/<initiative-slug>/` if no repo exists yet). Memory and chat are NOT the source of truth; these docs are. `/ideate continue` resumes from them + the task `STATE.md` — never "re-open a fresh session and redo the phase".

6. **DON'T ASSUME — ASK.** Christopher's vision is specific even when his words aren't yet. Where an answer changes the build, ask rather than guess. (The L3 ≥10-question floor operationalizes this for big ideas.)

7. **EQUIP EVERY DELEGATED WORKER.** No worker is spawned without: credentials/access notes, the docs/ideation context it needs, attn round-trip verified, and a verification gate in its brief. (Mirrors "Equip Before Delegating" + "Close the Loop".)

═══════════════════════════════════════════════════════════════════════════
## The flow (old 7 phases → the integrated on-ramp)
═══════════════════════════════════════════════════════════════════════════

```
        ┌───────────────────────────────────────────────────────────────┐
idea ──► │ PHASE 0  TRIAGE  → L1 / L2 / L3   (print 📊 header)            │
        └──────────────┬───────────────┬───────────────┬────────────────┘
                       │ L1            │ L2            │ L3
                       ▼               ▼               ▼
              ┌────────────┐   ┌──────────────┐  ┌───────────────────────────────┐
              │ just do it │   │ light path   │  │ PHASE 1  DISCOVERY            │
              │ (1 quick   │   │ Capture-lite │  │   Capture(≥10 Q) → Validate  │
              │  delegated │   │ + short plan │  │   → Scope → Architect        │
              │  task)     │   │ + ≤1-2       │  │ PHASE 2  PROTOTYPE-FIRST GATE│
              └────────────┘   │  workers     │  │   (recon worker, pass/fail)  │
                               └──────────────┘  │ PHASE 3  PLAN + SIGN-OFF     │←HARD GATE
                                                 └───────────────┬──────────────┘
                                                                 ▼  (signoff:true)
                                                 ┌───────────────────────────────┐
                                                 │ PHASE 4  EMIT ARTIFACTS       │
                                                 │   triage.json + initiative +  │
                                                 │   per-task dirs (+/project-init)│
                                                 │ PHASE 5  BUILD = DELEGATE     │
                                                 │   phased background workers,  │
                                                 │   STATE.md resume, result.json│
                                                 │   one phase closes b4 next    │
                                                 │ PHASE 6  /audit @ milestones  │
                                                 │ PHASE 7  /ship + close loop   │
                                                 └───────────────────────────────┘
```

The mapping from the old skill: old **Capture → Validate → Scope → Architect → Plan** (phases 1-5) collapse into the **L3 discovery+plan gate** (Phases 1 + 3 here), with the **NEW Prototype-First gate (Phase 2)** inserted before the plan. The old **Build** (phase 6, which wrongly wrote code inline in main) is replaced by **delegate-to-workers** (Phase 5). The old **Ship** (phase 7) becomes **/audit + /ship** (Phases 6-7).

---

## Parsing `$ARGUMENTS`

- **An idea description** → start at **Phase 0: Triage**.
- **`continue`** (or a phase name) → **resume from the saved artifacts**: locate the project's `docs/ideation/` + the initiative file + the latest task `STATE.md`, read them, and continue from the first incomplete phase/checkpoint. Do NOT re-run a completed phase (its doc is `[x]` in the initiative). See "`/ideate continue` — resume".
- **No arguments** → ask what the idea is, then go to Phase 0.

---

## PHASE 0 — TRIAGE the idea  (NON-NEGOTIABLE 1)

Classify the idea, **print the header, write nothing yet**. The level is the single most important decision — it sets how much ceremony the rest of the skill imposes.

```
📊 TRIAGE — Level <N>: <name>
Scope: <1 line — what it touches>
Treatment: <which /ideate path runs>
```

### Classification (from `~/.claude/CLAUDE.md` — same rubric, applied to an idea)

| Level | The idea looks like | /ideate treatment |
|-------|---------------------|-------------------|
| **L1 — Trivial** | a one-off script, a tiny tweak to an existing project, a single obvious addition. Not really a "project". | **Just-do-it path** — skip discovery. One quick **delegated** task (L1 fast-path: `triage.json` `level:L1` + stub `STATE.md` + one-line brief → `brief-worker.sh --quick`). No prototype, no plan, no sign-off. (Main still never builds inline — NON-NEGOTIABLE 3.) |
| **L2 — Standard/Complex** | a real but bounded feature/app: a known shape, existing stack, a few moving parts, multi-file. The broad middle. | **Light path** — Capture-lite (a focused probe, NOT the full ≥10-Q floor), prototype ONLY if something new (NON-NEGOTIABLE 4), a **short written plan** for Toper, then **1–2 delegated workers**. Full 3-tier artifacts, no L3 sign-off gate. |
| **L3 — Major/Huge** | a new product, a new standalone repo, an auth/payment/security system, anything customer-facing at scale, irreversible/high-stakes, multi-day. | **Full gate** — the complete Phase 1→7. **HARD GATE (NON-NEGOTIABLE 2): ≥10 Qs → answers → prototype → plan → explicit sign-off** before any artifact or worker. |

**HARD RULES for triage:**
- **Borderline rounds UP.** Torn between L2 and L3 → it's L3 (more questions, the prototype + sign-off gate). An L3-treated-as-L2 is the expensive mistake (verified: the Pulse landing rejection).
- A **new standalone repo or a customer-facing product is L3 by default** — do not talk yourself down to L2 to skip the gate.
- The triage header is printed in chat AND echoed by the `triage.json` you write in Phase 4 (`scope` field). Write the file, then the header — but for L3 the file's `signoff` stays `false` until Phase 3 completes.

After the header, branch:
- **L1** → go to **"L1 just-do-it path"** (near the end). Done in one delegation.
- **L2** → run **"L2 light path"** (near the end) — a trimmed Phase 1/3/4/5/6/7.
- **L3** → continue to **Phase 1** below (the full gate).

---

## PHASE 1 — DISCOVERY  (the L3 gate's discovery half: Capture → Validate → Scope → Architect)

**Goal:** go from a vague idea to a validated, scoped, architected understanding — and, for L3, satisfy the **≥10 clarifying-question floor**. This is the old Capture/Validate/Scope/Architect, run as ONE discovery push that feeds the plan. Each sub-step still emits its doc (NON-NEGOTIABLE 5).

> **L3 question counter (HARD):** track the count of clarifying questions asked across Capture+Validate+Scope+Architect. You may NOT proceed to Phase 2 until the count is **≥10 AND Toper has answered them**. If discovery feels "done" at 6 questions, you have under-probed — keep going. (market-events asked 12.)

### 1a. Capture — extract the full vision  *(keep the strong probing — this is the best part of the old skill)*

1. **Mirror back.** Restate the idea in your own words; confirm the core concept before probing.
2. **Structured probing — dimension by dimension, 3–5 questions per round, wait for answers between rounds.** Do NOT dump all questions at once. Dimensions:
   - **Core value proposition** — what problem, whose problem, the current alternative + why it's inadequate, what makes this uniquely better.
   - **Users & personas** — primary/secondary users, technical level, day-in-the-life before vs after.
   - **User flows & features** — the core journey end-to-end; must-haves vs nice-to-haves; decision points; **edge cases + failure states**.
   - **Business model** (if a product) — how it makes money, pricing intuition, growth loop.
   - **Constraints & context** — stack preferences, budget/timeline, integrations (APIs/services), **deployment target (VPS / Vercel / local / standalone)**, regulatory/compliance, **does it touch existing infra** (the market-events "don't disturb signal-trader" invariant lives here).
   - **Competitive landscape** — who else, the differentiation, what to learn from them.
   - **The riskiest assumption** — explicitly ask: "what's the one thing that, if false, kills this?" This seeds the Phase 2 prototype.
3. **Expansion loop.** After each round: surface branches the answers opened, ask follow-ups, confirm in-scope vs out-of-scope. Repeat until Christopher says "that's everything" or the vision is complete **AND (for L3) the question count is ≥10**.
4. **Emit `docs/ideation/01-vision.md`** (one-liner · problem · solution · users · core flows · feature map MUST/SHOULD/NICE · business model · constraints · **riskiest assumption** · open questions).

### 1b. Validate — is this worth building?  *(research-backed, NOT a prototype — that's Phase 2)*

Research thoroughly (ultra-thorough per `~/.claude/CLAUDE.md`: official docs, context7 for libraries, web search for recency/CVEs; spin up `/deep-research` for a deep market/landscape pass if warranted):
- **Market** — existing solutions, pricing, weaknesses, size indicators.
- **Technical feasibility** — buildable with the proposed stack? risky dependencies? the hardest technical problem — is it solvable? (This *names* the risk; Phase 2 *tests* it.)
- **Effort vs impact** — rough complexity (simple/moderate/complex/massive), MVP speed, impact-to-effort.
- **Alignment** — fits Aenoxa direction? bandwidth? timing?

Emit `docs/ideation/02-validation.md` with a verdict: **GO / PIVOT / PARK**. PIVOT → adjust vision, re-validate. PARK → save to `/tasks` as a LATER item and STOP the flow (no gate, no build).

### 1c. Scope — define the MVP

Cut the vision to the smallest thing that delivers core value: the ONE core flow that must work, its minimum feature set, what can be manual/hacky in v1, the launch criteria. Break the feature map into shipping phases (v1/v2/v3+). **These v1 phases become the delegated build milestones in Phase 5** — scope them as independently-shippable, verify-gated units (market-events' P1→P4). Emit `docs/ideation/03-scope.md` (core flow · MVP features w/ acceptance criteria · explicitly-out-of-scope · launch criteria · phase roadmap · success metrics).

### 1d. Architect — design the system

For each major technical decision: research current best practice (context7 / official docs / web search), compare options with trade-offs, **factor in Christopher's existing infra** (VPS, Cloudflare, systemd-user units, wa-sender bridge, tech preferences). Design: system overview, data model, API/contracts, exact stack + versions w/ justification, infrastructure/deploy/CI, **security model** (auth, secrets, access, "don't disturb X" invariants). Present trade-off decisions, get alignment. Emit `docs/ideation/04-architecture.md`.

**End of Phase 1 (L3):** vision + validation(GO) + scope + architecture docs exist; the ≥10-question floor is met and answered. Proceed to the Prototype gate.

---

## PHASE 2 — PROTOTYPE-FIRST GATE  (NEW — the old skill lacked this; NON-NEGOTIABLE 4)

**The single most important addition.** Before the plan is written, **validate the riskiest assumption with a throwaway prototype** and a concrete pass/fail criterion. A plan built on an unverified assumption wastes far more time than the prototype. (Christopher rejected the Gruvbox reskin after a full build — a 10-min prototype would have caught it. market-events ran a dedicated recon worker that smoke-tested every free data source, the TUI framework, and the WA-bridge reuse path BEFORE the plan — and that recon reshaped the plan.)

**HARD RULES:**
1. **State the riskiest assumption explicitly** (pulled from `01-vision.md` / `04-architecture.md`). Examples: "the free data source actually returns the fields we need from the VPS IP", "this library works with our stack version", "the API returns what we think", "this design direction reads premium".
2. **Write a concrete PASS/FAIL criterion BEFORE prototyping.** Not "see if it works" — e.g. *"PASS = ForexFactory + BLS + OKX + Deribit all return parseable target fields with HTTP 200 from BOTH the local box and the VPS; FAIL = any tier-1 source is unreachable or geoblocked with no bypass."*
3. **The prototype is THROWAWAY** — it tests the hypothesis, it is not v1 code. Iterate it cheaply.
4. **Delegate the prototype if it's real work** (NON-NEGOTIABLE 3) — for L3 this is a **dedicated recon worker** (its own task dir: `triage.json` `level:L2` is fine for the recon sub-task + `STATE.md` + brief; it writes a `report.md` + `result.json` with the verdict table). Trivial smoke tests (one curl, one import) may run inline in the discovery session. Never run a sprawling prototype inline in main.
5. **Findings become planning inputs.** Record what passed, what failed, what was undocumented/surprising (geoblocks, rate limits, version incompatibilities, header gotchas) in `docs/ideation/` (e.g. `02b-prototype-findings.md`) or the recon worker's report. The plan MUST reference them.

**Gate outcome:**
- **PASS** → proceed to Phase 3 (Plan). Carry the findings forward.
- **FAIL on a load-bearing assumption** → do NOT plan around it. Either find a validated workaround (and re-prototype it) or take it back to Toper as a PIVOT/PARK. A plan that assumes a failed prototype is forbidden.

> For L2 ideas: run a prototype **only if something is genuinely new**. A feature on a known stack with proven APIs may skip the prototype (note that you judged it unnecessary). For L1: never.

---

## PHASE 3 — PLAN + SIGN-OFF  (the gate's second half — HARD GATE close; NON-NEGOTIABLE 2)

**Goal:** turn validated architecture + prototype findings into an actionable, phased build plan, then get explicit sign-off. Only sign-off unlocks artifacts + workers.

### 3a. Write the plan

Turn the MVP scope + architecture into ordered, **delegatable** milestones — each one an independently-shippable, verify-gated unit (the P1→P4 shape). For each milestone: goal, the worker's deliverables, **acceptance/verification gate**, dependencies on prior milestones, and any "don't disturb" invariants. The plan MUST cite the prototype findings (what was de-risked, what constraints they imposed). Save it as `docs/ideation/05-build-plan.md` (and, for an initiative, a plan file beside the initiative — market-events used `~/claude/notes/initiatives/<slug>-plan.md`).

### 3b. Present + sign-off  (THE GATE)

Present the plan to Toper. **Until Toper explicitly says "approved" (or equivalent), you are FORBIDDEN to:**
- write `triage.json` with `signoff:true`,
- create the initiative file,
- create any per-task dir,
- spawn ANY build worker.

This is mechanically backed downstream: `spawn-worker.sh` refuses an `L3` `triage.json` whose `signoff != true` (exit 4 — see `~/.claude/scripts/check-triage.sh` + `TRIAGE-SCHEMA.md`). So even if this prose is ignored, the spawn gate blocks an unsigned L3 build. **Do not flip `signoff` to `true` until the words land.** Record the sign-off (date + any decisions Toper made at sign-off, e.g. market-events' "reuse wa-sender queue · systemd user units · curl_cffi · local relay") in the initiative's decisions log.

**L3 gate checklist — ALL must be `[x]` before Phase 4:**
- [ ] ≥10 clarifying questions asked
- [ ] Answers received from Toper
- [ ] Prototype-First gate PASSED (Phase 2) with its pass/fail criterion met
- [ ] Written plan presented
- [ ] Toper's explicit sign-off

---

## PHASE 4 — EMIT THE ARTIFACTS  (3-tier pre-spawn discipline)

Only after sign-off (L3) / after the short plan (L2). Materialize the **real** 3-tier artifacts — do NOT invent a parallel structure. For each item, reference the live template by path.

1. **`triage.json`** in each task notes dir — schema at `~/.claude/scripts/TRIAGE-SCHEMA.md`:
   ```json
   { "task_slug": "<slug>", "level": "L3", "scope": "<one-line>", "created": "<ISO ts>", "signoff": true }
   ```
   `signoff:true` ONLY for an L3 whose Phase-3 gate closed. (L1/L2 ignore `signoff`.)
2. **Initiative file** at `~/claude/notes/initiatives/<area-verb-noun>.md` from the template `~/claude/notes/templates/initiative.md` — fill outcome, success criteria (from `03-scope.md`), the **L3 gate progress** checklist (the 5 items above, all `[x]`), the child-tasks list (one per build milestone), the decisions log (incl. sign-off). market-events' initiative is the worked reference.
3. **Per-milestone task dirs** `~/claude/notes/<task-slug>-<date>/` — each with: its own `triage.json`, a **`STATE.md`** copied from `~/claude/notes/templates/STATE.md` (fill NAME, worker name, **Parent initiative** link, starting point, roadmap, **Checkpoints** section), and a **`brief.md`** (the equipped task hand-off — see Phase 5). The task slug must reference the parent initiative for navigability.
4. **`TaskCreate`** each milestone with the parent initiative slug in the description (full path; L1 may skip).
5. **Scaffold shortcut (optional):** for a clean fan-out of phase workers, `~/.claude/scripts/workflows/scaffold-workflow.sh <pattern> <run-slug>` writes the per-worker task dirs (triage.json + STATE.md + role-shaped brief.md stub) and prints the exact spawn/brief commands. You still fill each brief's Task section. (`recon-implement-verify` fits the prototype→build→verify shape; `fan-out-review` fits the /audit milestone.)
6. **`/project-init`** to scaffold the repo when the build needs a fresh codebase — `/project-init <project-name> <nextjs|go|python>` creates `~/claude/Git/repositories/<project>/`. The `docs/ideation/` docs then move into that repo. **If the build is a website/web app, the i18n + multi-theme + (for Aenoxa products) Website Build Defaults in `~/.claude/CLAUDE.md` apply** — bake them into the milestone briefs from milestone 0.

---

## PHASE 5 — BUILD = DELEGATE  (NON-NEGOTIABLE 3 — main NEVER builds inline)

**This replaces the old Phase 6, which wrongly told the main session to write code inline.** Build is executed by **spawned, resumable background workers**, one per milestone, phased, with a verification gate closing each phase before the next opens. Main coordinates and gates only.

### Per-milestone delegation loop

For each build milestone, in dependency order:

1. **Equip the brief** (NON-NEGOTIABLE 7 — `brief.md` in the task dir): the milestone goal + acceptance gate from the plan; the docs/ideation context paths; credentials/access notes (`~/.claude/secrets.env` pattern, VPS access, test accounts); the "don't disturb X" invariants; an explicit **verification gate** (the worker must prove its output — tests/curl/screenshots/DB rows, not claims); and the resumability contract (maintain `STATE.md` checkpoints, write `result.json` on completion).
2. **Spawn** the worker: `~/.claude/scripts/spawn-worker.sh <window> [<cwd>] [<task_dir>]`. The script's **triage gate** refuses to spawn without a valid `triage.json` (and refuses an unsigned L3 — exit 4); the **concurrency governor** (`worker-semaphore.sh`, default `CHILLDAWG_MAX_WORKERS=4`) keeps the 4-vCPU box from thrashing — raise it per-spawn for a wide fan-out or queue with `CHILLDAWG_SPAWN_WAIT`. **After spawn, verify the attn round-trip** (the worker appears in local peers) BEFORE briefing — no brief without attn.
3. **Brief** the worker: `~/.claude/scripts/brief-worker.sh <window> <brief_file>` (full path) — it injects the role-override preamble (open STATE.md first, set IN_PROGRESS, checkpoint + verify-before-marking, write `report.md` + `result.json` on completion) and refuses to deliver if `STATE.md` is missing or (full path) lacks a Parent-initiative link. (L1 sub-tasks: `brief-worker.sh --quick`.)
4. **Run workers in parallel where the dependency graph allows; serialize where a phase depends on the prior one** (market-events ran P1→P2→P3→P4 serially because each built on the last). One phase's **verification gate must PASS before the next phase's worker is spawned.**
5. **Poll / monitor:** `~/.claude/scripts/fleetview.sh [--watch <secs>]` is the live cockpit (STATE.md status + mtime, STALLED flag if no update >10min, checkpoint progress, Resume cursor, context%). Main polls every ~5 min; investigate a stall.
6. **Resume on death** (NOT redo): if a worker dies (session limit / crash), it RESUMES from its last verified checkpoint — `~/.claude/scripts/resume-worker.sh <window> <task-dir> [--with-brief <orig-brief>]` re-briefs it with a RESUME preamble pointing at its `STATE.md` Resume cursor. (market-events' P3 and P4 each survived a session-limit death and resumed cleanly — this is the model, not an exception.)
7. **Ingest the result:** on completion the worker writes `result.json` next to `STATE.md`; read/validate it with `~/.claude/scripts/result-schema.sh <dir>` (`{status, summary, deliverables, evidence, blockers, followups, staged_for_human}`). Update the initiative's child-task status. Then open the next milestone.

**Never** write the product code in the main `/ideate` session. If you catch yourself editing the product repo here, STOP — that work belongs in a worker.

---

## PHASE 6 — /audit AT MILESTONE BOUNDARIES

At natural milestone boundaries (a phase closes, or before ship), run **`/audit <repo-path>`** — it is project-type-adaptive: it **auto-detects** the type (web-app / backend-service / **data-pipeline** / cli-tui / library / infra) and selects the matching lens roster + verdict rubric. (market-events audited under the **data-pipeline** roster — data-integrity + reliability lenses, the *trustworthy-for-downstream* rubric — NOT the web-app a11y lenses.) Feed the audit's blockers back as fix tasks (themselves delegated), then re-audit. Do NOT hand-pick lenses — let `/audit` detect the type (override with `--type` only if detection is wrong).

This replaces the old Phase 6's hand-rolled "security audit / perf review / design review" bullets — `/audit` does all of that, adapted to the project type, with severity tiers + an adversarial verification pass.

---

## PHASE 7 — /ship + CLOSE THE LOOP

When the build passes its audit gate:

1. **`/ship`** runs the full pipeline (simplify → security review → test → version → `/commit` → `/preflight` → push). For a one-shot pitch/demo deploy use **`/oneshot-webapp`** instead; for a landing page, `/deploy-landing`.
2. **Deploy** per the architecture doc (VPS + nginx + certbot, or Vercel, etc.). Do NOT disturb other VPS services (the standing invariant).
3. **Smoke-test in the target environment** — verify the core flow live (curl codes, a real run, screenshots), not just locally. Close the loop with **evidence, not claims**.
4. **Update artifacts:** mark the initiative `COMPLETE` (or move to an OPERATE/OBSERVE mode like market-events), fill its "Outcome" section, update memory with durable project facts/decisions (`/remember` or a project memory file), and check off the tasks.
5. **Report back to main** with what shipped, what was verified (evidence), what's pending, and surprises.

---

## L1 just-do-it path  (Phase 0 said L1)

A trivial idea doesn't pay for discovery, prototype, plan, or sign-off — but it is STILL delegated (main never builds inline, NON-NEGOTIABLE 3). The L1 fast-path:

1. `~/claude/notes/<task-slug>-<date>/` with **`triage.json`** `{"level":"L1", ...}` (no `signoff`), a **one-line `brief.md`**, and a **stub `STATE.md`** (name / status / one-liner) — NO initiative file, NO parent-initiative linkage.
2. `spawn-worker.sh <window>` → verify attn → `brief-worker.sh --quick <window> <brief>` (the `--quick` flag accepts the stub).
3. The worker does it, verifies, reports back. Done.

> Pure-comms "ideas" (send a message, list windows, answer a question, read a file) are NOT delegatable tasks — they stay in main and need no worker. They still get an `📊 TRIAGE — L1` header.

---

## L2 light path  (Phase 0 said L2)

A real but bounded idea — full 3-tier artifacts, but NO L3 ≥10-Q floor and NO sign-off gate. Run a trimmed flow:

1. **Capture-lite** — a focused probe (not the full ≥10-question floor; ask what genuinely changes the build — 0 to a handful of questions scaled to ambiguity). Emit a short `docs/ideation/01-vision.md` (or a single combined doc).
2. **Prototype ONLY if something new** (NON-NEGOTIABLE 4) — a new library/API/integration/design gets a quick prototype with a pass/fail criterion (delegate it if it's real work). A known-stack feature with proven APIs may skip it (note that you judged it unnecessary).
3. **Short written plan** presented to Toper (L2 gets a plan, not a hard sign-off gate — but still align before building if there are trade-offs).
4. **Emit artifacts** (Phase 4) — `triage.json` `level:L2`, an initiative file (create or reuse the area's existing one), the task dir(s) with STATE.md + brief.md.
5. **Delegate 1–2 workers** (Phase 5 loop) — most L2 work is one or two milestones.
6. **/audit** if it's substantial enough to warrant it; **/ship** to deploy. Close the loop.

---

## `/ideate continue` — resume from the saved artifacts  (kills the old "new session each phase" friction)

The old skill told Christopher to **open a brand-new session for every phase** (context-size workaround). That friction is gone: the **docs + STATE.md ARE the resumable state** (NON-NEGOTIABLE 5). On `/ideate continue`:

1. **Locate the artifacts.** Find the project's `docs/ideation/` (in `~/claude/Git/repositories/<project>/` if scaffolded, else `~/claude/notes/<slug>/`) and the initiative file `~/claude/notes/initiatives/<slug>.md`. If ambiguous, ask which idea.
2. **Read the state.** The initiative's L3-gate checklist + child-task statuses tell you which phase is done. The `docs/ideation/NN-*.md` files tell you discovery state. The latest task `STATE.md` (Checkpoints + Resume cursor) tells you mid-build state.
3. **Resume from the first incomplete phase/checkpoint** — do NOT re-run a completed phase. If discovery docs exist through `04-architecture.md` but no prototype findings, resume at Phase 2. If the plan is signed and workers are mid-flight, resume at Phase 5 (poll FleetView, resume any dead worker via `resume-worker.sh`). Trust `[x]` items; re-verify the last one cheaply; continue.

There is no "summarize and tell Christopher to start a new session" step. Continuity lives on disk.

---

## ROBUSTNESS SELF-CHECK  (run before declaring an /ideate flow correctly set up)

Mirror the skill-authoring robustness bar. Confirm every box before handing off to the build:

- [ ] **Phase 0 triage header printed** with the correct level; borderline rounded UP.
- [ ] **L3 only:** ≥10 questions asked AND answered (count tracked); not 6-and-called-done.
- [ ] **Prototype-First gate** ran for anything new, with a **concrete pass/fail criterion stated before** prototyping; findings recorded and referenced by the plan. (Skipped only for L1, or L2-with-nothing-new with a noted reason.)
- [ ] **L3 only:** plan presented AND explicit Toper sign-off received BEFORE any artifact/worker; `triage.json` `signoff` was `false` until then.
- [ ] **Every referenced artifact is the REAL one** at its real path: `triage.json` (`~/.claude/scripts/TRIAGE-SCHEMA.md`), initiative (`~/claude/notes/templates/initiative.md`), STATE.md (`~/claude/notes/templates/STATE.md`), spawn/brief/resume/result/fleetview scripts under `~/.claude/scripts/`. No invented parallel structure.
- [ ] **Build is delegated, never inline** — no product code written in the main `/ideate` session; each milestone has a task dir + equipped brief + verification gate + attn verified.
- [ ] **Workers are resumable** — STATE.md checkpoints + result.json contract in every full-path brief; a dead worker resumes, doesn't redo.
- [ ] **/audit ran at the milestone boundary** with auto-detected type (not hand-picked lenses); blockers fed back as delegated fixes.
- [ ] **Ship closed the loop** with evidence in the target environment; initiative marked complete + memory updated.
- [ ] **docs/ideation/ is the source of truth**; `/ideate continue` resumes from it + STATE.md, with no "open a new session" friction.

If any box fails, the flow is NOT correctly set up — fix it before building.

---

## What changed from the old /ideate (for reference)

| Old (2026-04, standalone) | New (the on-ramp) |
|---|---|
| 7 manual phases, all in main | Triage-gated flow that **orchestrates** triage/3-tier/gate/delegate/audit/ship |
| No triage — every idea got the same heavy 7 phases | **Phase 0 triage** → L1 just-do-it / L2 light / L3 full gate |
| No prototype — "Validate" was market research only | **Phase 2 Prototype-First gate** with a concrete pass/fail criterion (the key fix) |
| No sign-off gate | **L3 HARD GATE**: ≥10 Q → prototype → plan → explicit sign-off (mechanically backed by the spawn gate) |
| Phase 6 "Build" wrote code **inline in main** (violated discussion-only) | **Phase 5 Build = DELEGATE** to resumable background workers; main never builds |
| "Open a new session each phase" friction | **`/ideate continue`** resumes from docs/ideation + STATE.md |
| Hand-rolled "security/perf/design review" | **`/audit`** (project-type-adaptive) at milestone boundaries |
| Manual deploy bullets | **`/ship`** (+ `/oneshot-webapp` / `/deploy-landing`) |
| Plugged into none of the machinery | Emits real `triage.json` + initiative + task dirs; drives `spawn`/`brief`/`resume`/`fleetview`/`result-schema` |

## References

- Operating model (the gears this drives): `~/.claude/CLAUDE.md` — Task Complexity Triage, 3-Tier Task Hierarchy, Prototype & Smoke Test Before Planning, Main-Session-is-DISCUSSION-ONLY, Equip Before Delegating, Close the Loop, Worker Orchestration Tooling (Wave-3).
- Triage gate schema: `~/.claude/scripts/TRIAGE-SCHEMA.md`. Templates: `~/claude/notes/templates/{initiative,STATE}.md`.
- Pipeline scripts: `~/.claude/scripts/{spawn-worker,brief-worker,resume-worker,result-schema,fleetview,worker-semaphore}.sh`; workflow scaffolds: `~/.claude/scripts/workflows/` (`scaffold-workflow.sh` + the 3 playbooks).
- Sibling skills: `/audit`, `/ship`, `/commit`, `/preflight`, `/project-init`, `/oneshot-webapp`, `/deploy-landing`, `/deep-research`, `/remember`, `/tasks`.
- The worked example this flow reproduces: `~/claude/notes/initiatives/market-events-calendar.md` + `~/claude/notes/initiatives/market-events-calendar-plan.md` (idea → L3 gate (12 Q) → prototype recon worker → plan → sign-off → P1-P4 delegated workers w/ resume → data-pipeline /audit → live).
- Skill-robustness bar: memory `feedback_skill_authoring_robustness`.
