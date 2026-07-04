---
name: ideate
description: The structured on-ramp from a raw idea to a delegated, gated build. Triages the idea (L1/L2/L3), runs the L3 discovery+prototype+plan+sign-off HARD GATE, then drives the BUILD by delegating phased milestones to resumable background workers (3-tier hierarchy, one Opus supervisor for a fleet), with /audit at milestone boundaries and /ship to release. Orchestrates the REAL triage/3-tier/gate/delegate/audit/ship machinery, it does NOT run a parallel manual process. Use when Christopher has a new project/feature idea or says /ideate.
argument-hint: "[idea description | \"continue\" to resume from the saved docs/ideation + STATE.md]"
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, WebSearch, WebFetch, Skill
---

# /ideate: raw idea -> triaged -> gated -> delegated build

Christopher's stated idea is typically ~1% of what is in his head. This skill extracts the full vision, **decides how much process it deserves** (triage), runs the **discovery + prototype + plan + sign-off gate** for serious work, and then **drives the build by delegating phased milestones to resumable background workers**. It is the FRONT DOOR to the operating model, not a replacement for it.

`/ideate` is an **orchestrator**. It invents no task system, no worker model, no audit of its own. It drives the machinery that already exists: **Task Complexity Triage** and the **3-Tier Hierarchy** (`~/.claude/CLAUDE.md`), the **triage gate** (`triage.json` + `check-triage.sh`), the **delegated resumable worker pipeline** (`spawn-worker.sh` -> `brief-worker.sh` -> `resume-worker.sh`), the **Supervisor layer** (`spawn-supervisor.sh`) for fleets, and the sibling skills **`/audit`**, **`/ship`**, **`/commit`**, **`/project-init`**. Where a fact lives in one of those, this skill CITES it by path and never re-derives its internals (a second copy drifts).

Encyclopedic depth lives in `references/` (loaded on demand, not at invocation):
- `references/worked-example-market-events.md`: the only verified end-to-end proof (idea -> L3 gate -> prototype recon -> plan -> sign-off -> P1-P4 delegated workers with resume-after-death -> data-pipeline audit -> live).
- `references/delegation-brief-templates.md`: the equipped build-milestone brief, the recon/prototype brief, the /ship stage-and-hold brief, the supervisor brief, the STATE.md checkpoint pattern.
- `references/failure-playbooks.md`: full recovery-command sequences behind the SKILL.md playbook summary.

═══════════════════════════════════════════════════════════════════════════
## Boundary Charter: route FIRST, ideate second
═══════════════════════════════════════════════════════════════════════════

`/ideate` owns exactly one thing: turning a **raw idea** into a **triaged, gated, delegated build**. When the input is actually something else, HAND OFF, do not absorb it (prevents scope creep and the wrong-defaults failure class).

| The input really is... | Route to | Why (the boundary) |
|---|---|---|
| A raw idea to develop into a shipped build | **/ideate (here)** | this is the on-ramp |
| A personal to-do / reminder / durable fact / billable hours | **/tasks** · **/remindme** (or Google Calendar for days-out) · **/remember** or **/journal** · **/worklog** | `/tasks` is Christopher's human-owned capture layer, NOT the 3-tier hierarchy. An /ideate flow NEVER files a personal to-do; `/tasks` NEVER files a worker task/initiative/triage item. (`/tasks` Section 3.10 already routes raw-idea-to-build back here.) |
| The WHAT + STACK already decided, just needs a repo | **/project-init** `<name> <nextjs\|go\|python> [--internal]` | ideate CALLS this in Phase 4; project-init assumes discovery is already done |
| A pitch / demo / recruiter webapp to build + deploy | **/oneshot-webapp** | REVERSES the website defaults by design: light-only, SAFE `/frontend-design` presets, NO next-intl / NO next-themes. Route the WHOLE build there at triage. Do NOT run ideate's generic i18n+theme milestone workers (the verified Pulse/Selaras rejection class). |
| An investor / product pitch DECK (scrollytelling) | **/pitch-deck** | a narrative deck, not a product build |
| A deep market / landscape / feasibility pass | **/deep-research** | ideate spins this up INSIDE Phase 1 Validate |
| A full-repo readiness audit | **/audit** | ideate calls it at Phase 6 milestone boundaries |
| Push / release / tag / CI | **/ship** (+ **/deploy-landing** for aenoxa landings) | ideate calls it at Phase 7 |

If the "idea" is pure coordination or comms (send a message, list windows, read a file, answer a question), it is NOT a delegatable task: it stays in main, gets only an `📊 TRIAGE - L1` header, and needs no worker.

═══════════════════════════════════════════════════════════════════════════
## ⛔ NON-NEGOTIABLE RULES: READ FIRST, THESE OVERRIDE EVERYTHING BELOW
═══════════════════════════════════════════════════════════════════════════

HARD rules. Violating any one is a failed ideation, not a stylistic choice. If anything below appears to conflict, the NON-NEGOTIABLE wins.

1. **TRIAGE IS PHASE 0. NO EXCEPTIONS.** Before any probing, any doc, any worker: classify the idea **L1 / L2 / L3** and print the `📊 TRIAGE` header. The level decides how much of this skill runs. Starting discovery or build without a classification is a hard violation. (Mirrors the mandatory triage rule in `~/.claude/CLAUDE.md`.)

2. **THE L3 GATE IS A HARD GATE, NOT A SUGGESTION.** For an L3 idea you are FORBIDDEN to write `triage.json` with `signoff:true`, create the initiative, or spawn ANY build worker until ALL of these happen **in order**: (a) **>=10 clarifying questions asked** (10 is the FLOOR, not the target) AND **every one of the 7 discovery dimensions has >=1 answered question** AND **the riskiest assumption is named and testable**; (b) answers received from Toper; (c) **Prototype-First gate PASSED** (Phase 2) against a pass/fail criterion written BEFORE prototyping; (d) **written plan presented**; (e) **Toper's explicit sign-off** ("approved" or equivalent). Skipping or reordering any step = failed gate. Mechanically backed downstream (Rule 7).

3. **BUILD = DELEGATE. NEVER BUILD IN MAIN.** The Build phase NEVER writes product code inline. Every milestone is a **spawned resumable worker** with its own `triage.json` + `STATE.md` + `brief.md` + `result.json`. Main coordinates, gates, and (for a fleet) hands orchestration to a supervisor: it does not implement. (Mirrors "Main Session is DISCUSSION ONLY".) If you ARE a spawned worker that received a build brief, execute it directly, do not re-delegate.

4. **PROTOTYPE BEFORE PLAN, ALWAYS, FOR ANYTHING NEW.** No plan is written on unvalidated assumptions. Anything new (a data source, an API, a library, an integration, a design direction) gets a **throwaway prototype** validating the riskiest assumption FIRST, with a falsifiable pass/fail criterion, and its findings become planning inputs. A prototype **FAIL** on a load-bearing assumption FORBIDS planning around it: PIVOT (adjust vision, re-validate), PARK (save to `/tasks` as LATER, stop the flow), or find and re-prototype a validated workaround. (Mirrors "Prototype & Smoke Test Before Planning".)

5. **DOCS IN `docs/ideation/` ARE THE SOURCE OF TRUTH.** Vision, validation, scope, architecture, plan write to `~/claude/Git/repositories/{project}/docs/ideation/NN-*.md` (or `~/claude/notes/<slug>/` pre-repo). Memory and chat are NOT the source of truth. `/ideate continue` resumes from those docs + the initiative + the latest `STATE.md`, NEVER "open a fresh session and redo the phase".

6. **DON'T ASSUME, ASK.** Christopher's vision is specific even when his words are not yet. Where an answer changes the build, ask rather than guess. (The L3 >=10-question floor operationalizes this for big ideas.)

7. **EQUIP EVERY DELEGATED WORKER (blocking checklist).** No worker is spawned without ALL of: a valid `triage.json` (`spawn-worker.sh` refuses without it, exit 4; an unsigned L3 also exit 4); the **attn round-trip verified** (the worker appears in local peers) BEFORE briefing; and an **equipped brief** carrying creds/access, docs/ideation context paths, don't-disturb invariants, an evidence-based verification gate, and the STATE.md-checkpoint + result.json resumability contract. The per-milestone checklist in Phase 5 is the gate. (Mirrors "Equip Before Delegating" + "Close the Loop".)

8. **A FLEET GETS ONE OPUS SUPERVISOR. MAIN DOES NOT BABYSIT A MULTI-MILESTONE BUILD.** For an L3 multi-milestone build (a fleet, a long-running initiative), main spawns ONE **Opus supervisor** (`spawn-supervisor.sh` + `brief-worker.sh --supervisor`) that owns the per-milestone delegate/resume/audit loop; main handles only checkpoints and stays Toper's conversation partner. A **single-milestone L2** means main spawns the one worker directly (a supervisor for one worker is pure overhead). NEVER run the full multi-milestone delegation loop inline in main. (CLAUDE.md "Supervisor Orchestration Layer", Wave-7. Verified failure: main consumed as an automation engine mid-run.)

9. **WORKER MODEL: SONNET FLOOR, OPUS CARVE-OUT.** Every build-milestone `triage.json` carries `"model":"sonnet"` by default (the hard floor). Set `"model":"opus"` ONLY for a carve-out milestone and say WHY: **security-critical** (auth/payments/secrets), **customer/recruiter-facing design-quality** frontend, or **genuinely novel root-cause debugging**. NEVER default a build worker to opus. (Exception: hackathon/AURA work is Opus-max by standing rule, memory `feedback_hackathon_opus_max`.) The schema field is real, `spawn-worker.sh` reads it (Rule 7). (CLAUDE.md "Worker Model Policy", Wave-7.)

10. **PITCH/DEMO FORK: ROUTE TO /oneshot-webapp AND REVERSE THE WEBSITE DEFAULTS.** If the idea IS a pitch/demo/recruiter webapp, route the BUILD to `/oneshot-webapp` (light-only, SAFE presets, NO next-intl/next-themes). If it is an Aenoxa PRODUCT website/web-app, bake next-intl (`id` default + `en`) + next-themes into the milestone briefs from milestone 0. NEVER apply the product i18n+theme defaults to a oneshot/pitch build, and NEVER ship a product website English-only single-theme. Detect at triage (Boundary Charter). (CLAUDE.md "One-Shot Pitch/Demo Webapps" + "Website Build Defaults".)

11. **DASH-CLEAN OUTPUT.** NEVER emit em dashes or en dashes anywhere in text ideate shows Toper (the triage header, the plan, questions) or in this skill's prose. Use plain hyphens, colons, parentheses, line breaks. Arrows (`->`) and box-drawing are fine. (House PRIME rule; every enhanced sibling SKILL.md is dash-clean.)

═══════════════════════════════════════════════════════════════════════════
## The flow
═══════════════════════════════════════════════════════════════════════════

```
        ┌───────────────────────────────────────────────────────────────┐
idea ──► │ PHASE 0  TRIAGE  -> L1 / L2 / L3   (print the 📊 header)       │
        └──────────────┬───────────────┬───────────────┬────────────────┘
                       │ L1            │ L2            │ L3
                       ▼               ▼               ▼
              ┌────────────┐   ┌──────────────┐  ┌───────────────────────────────┐
              │ just do it │   │ light path   │  │ PHASE 1  DISCOVERY            │
              │ (1 quick   │   │ Capture-lite │  │   Capture(>=10 Q, 7 dims)     │
              │  delegated │   │ + short plan │  │   -> Validate -> Scope        │
              │  task)     │   │ + 1-2 direct │  │   -> Architect               │
              └────────────┘   │  workers     │  │ PHASE 2  PROTOTYPE-FIRST GATE│
                               └──────────────┘  │   (recon worker, PASS/FAIL)  │
                                                 │ PHASE 3  PLAN + SIGN-OFF     │←HARD GATE
                                                 └───────────────┬──────────────┘
                                                                 ▼  (signoff:true)
                                                 ┌───────────────────────────────┐
                                                 │ PHASE 4  EMIT ARTIFACTS       │
                                                 │   triage.json(+model) +       │
                                                 │   initiative + per-task dirs  │
                                                 │   (+/project-init)            │
                                                 │ PHASE 5  BUILD = DELEGATE     │
                                                 │   fleet -> 1 Opus supervisor  │
                                                 │   single -> main spawns 1     │
                                                 │   STATE.md resume, result.json│
                                                 │   one gate closes b4 next     │
                                                 │ PHASE 6  /audit @ milestones  │
                                                 │ PHASE 7  /ship 9-step + loop  │
                                                 └───────────────────────────────┘
```

Old-skill mapping: old **Capture -> Validate -> Scope -> Architect -> Plan** (phases 1-5) collapse into the **L3 discovery+plan gate** (Phases 1 + 3), with the **NEW Prototype-First gate (Phase 2)** inserted before the plan. The old **Build** (which wrongly wrote code inline in main) is replaced by **delegate-to-workers** (Phase 5). The old **Ship** becomes **/audit + /ship** (Phases 6-7).

---

## Parsing `$ARGUMENTS`

- **An idea description** -> start at **Phase 0: Triage**.
- **`continue`** (or a phase name) -> **resume from the saved artifacts**: locate the project's `docs/ideation/` + the initiative file + the latest task `STATE.md`, read them, continue from the first incomplete phase/checkpoint. Do NOT re-run a completed phase (its doc is `[x]` in the initiative). See "`/ideate continue`".
- **No arguments** -> ask what the idea is, then go to Phase 0.

---

## PHASE 0: TRIAGE the idea  (NON-NEGOTIABLE 1)

Classify the idea, **print the header, write nothing yet**. The level is the single most important decision: it sets how much ceremony the rest imposes.

```
📊 TRIAGE - Level <N>: <name>
Scope: <1 line, what it touches>
Treatment: <which /ideate path runs>
Model: <sonnet default, or opus + why, when a build worker is a carve-out>
```

### Triage scoring / decision table (signals -> level)

Score the signals, then apply the round-up rule. **Any one L3 trigger true -> L3.**

| Signal (ask of the idea) | If true |
|---|---|
| A new standalone repo / product? | -> **L3** |
| Customer-facing at scale? | -> **L3** |
| Touches auth / payments / secrets (security-critical)? | -> **L3** |
| Irreversible or high-stakes (data loss, money, external relationships)? | -> **L3** |
| Multi-day / multi-milestone (a fleet)? | -> **L3** |
| A bounded feature on an existing stack, a few moving parts, multi-file, NO L3 trigger | -> **L2** |
| A one-off script, a tiny tweak, a single obvious addition, not a project | -> **L1** |

| Level | /ideate treatment |
|-------|-------------------|
| **L1 Trivial** | **Just-do-it path**: skip discovery. One quick **delegated** task (L1 fast-path: `triage.json` `level:L1` + stub `STATE.md` + one-line brief -> `brief-worker.sh --quick`). No prototype, no plan, no sign-off. Main still never builds inline (Rule 3). |
| **L2 Standard/Complex** | **Light path**: Capture-lite (a focused probe, NOT the >=10-Q floor), prototype ONLY if something new (Rule 4), a **short written plan** for Toper, then **1-2 delegated workers spawned directly by main** (no supervisor). Full 3-tier artifacts, no L3 sign-off gate. |
| **L3 Major/Huge** | **Full gate**: Phase 1->7. HARD GATE (Rule 2): >=10 Qs + 7-dimension coverage + riskiest assumption -> answers -> prototype -> plan -> explicit sign-off before any artifact or worker. Multi-milestone -> one Opus supervisor (Rule 8). |

**HARD RULES for triage:**
- **Borderline rounds UP.** Torn between L2 and L3 -> it is L3 (more questions, the prototype + sign-off gate). An L3-treated-as-L2 is the expensive mistake (verified: the Pulse landing rejection). Never talk an L3 down to L2 to skip the gate.
- A **new standalone repo or a customer-facing product is L3 by default.**
- **Print the resolved level AND the triggering signal** in the header (e.g. "L3: new standalone repo + touches WA-bridge infra").
- The header is echoed by the `triage.json` you write in Phase 4 (`scope` field). Write the file, then print the header, but for L3 the file's `signoff` stays `false` until Phase 3 closes.

After the header, branch: **L1** -> "L1 just-do-it path" (near the end). **L2** -> "L2 light path" (near the end). **L3** -> Phase 1 below (the full gate).

---

## PHASE 1: DISCOVERY  (the L3 gate's discovery half: Capture -> Validate -> Scope -> Architect)

**Goal:** go from a vague idea to a validated, scoped, architected understanding, and for L3 satisfy the **>=10-question floor AND the 7-dimension coverage gate**. Run as ONE discovery push feeding the plan. Each sub-step emits its doc (Rule 5).

> **L3 discovery-completeness gate (HARD).** You may NOT proceed to Phase 2 until ALL are `[x]`:
> - [ ] Question count **>=10** AND Toper has answered.
> - [ ] **Each of the 7 dimensions has >=1 answered question:** (1) core value prop, (2) users & personas, (3) user flows & features incl. edge + failure states, (4) business model, (5) constraints & context incl. deploy target + don't-disturb infra, (6) competitive landscape, (7) the riskiest assumption.
> - [ ] The **riskiest assumption is named and testable** (it seeds Phase 2).
>
> If discovery feels "done" at 6 questions or one dimension is blank, you have under-probed: keep going. Track the count and the dimension coverage explicitly. (market-events asked 12 across all 7.)

### 1a. Capture: extract the full vision

1. **Mirror back.** Restate the idea in your own words; confirm the core concept before probing. Be specific, not generic (an anti-slop mirror names the actual problem, not a template).
2. **Structured probing, dimension by dimension, 3-5 questions per round, wait for answers between rounds.** Do NOT dump all questions at once. The 7 dimensions:
   - **Core value proposition:** what problem, whose, the current alternative + why it is inadequate, what makes this uniquely better.
   - **Users & personas:** primary/secondary users, technical level, day-in-the-life before vs after.
   - **User flows & features:** the core journey end-to-end; must-haves vs nice-to-haves; decision points; **edge cases + failure states**.
   - **Business model** (if a product): how it makes money, pricing intuition, growth loop.
   - **Constraints & context:** stack preferences, budget/timeline, integrations (APIs/services), **deployment target** (VPS / Vercel / local / standalone), regulatory, and **does it touch existing infra** (the market-events "don't disturb signal-trader" invariant lives here).
   - **Competitive landscape:** who else, the differentiation, what to learn from them.
   - **The riskiest assumption:** ask explicitly "what is the one thing that, if false, kills this?" This seeds Phase 2.
3. **Expansion loop.** After each round: surface branches the answers opened, ask follow-ups, confirm in-scope vs out-of-scope. Repeat until the vision is complete AND (L3) the count is >=10 AND all 7 dimensions are covered.
4. **Emit `docs/ideation/01-vision.md`** (one-liner · problem · solution · users · core flows · feature map MUST/SHOULD/NICE · business model · constraints · **riskiest assumption** · open questions).

### 1b. Validate: is this worth building?  (research-backed, NOT a prototype, that is Phase 2)

Research thoroughly (ultra-thorough per `~/.claude/CLAUDE.md`: official docs, context7 for libraries, web search for recency/CVEs; spin up **`/deep-research`** for a deep market/landscape pass if warranted):
- **Market:** existing solutions, pricing, weaknesses, size indicators.
- **Technical feasibility:** buildable with the proposed stack? risky dependencies? the hardest technical problem, is it solvable? (This *names* the risk; Phase 2 *tests* it.)
- **Effort vs impact:** rough complexity (simple/moderate/complex/massive), MVP speed, impact-to-effort.
- **Alignment:** fits Aenoxa direction? bandwidth? timing?

Emit `docs/ideation/02-validation.md` with a verdict: **GO / PIVOT / PARK.** PIVOT -> adjust vision, re-validate. PARK -> save to `/tasks` as a LATER item and STOP the flow (no gate, no build).

### 1c. Scope: define the MVP

Cut the vision to the smallest thing delivering core value: the ONE core flow that must work, its minimum feature set, what can be manual/hacky in v1, the launch criteria. Break the feature map into shipping phases (v1/v2/v3+). **These v1 phases become the delegated build milestones in Phase 5**, so scope them as independently-shippable, verify-gated units (market-events' P1->P4). Ban MVP-theater: a scope doc that marks everything must-have is not scoped, force a real cut to the ONE core flow. Emit `docs/ideation/03-scope.md` (core flow · MVP features w/ acceptance criteria · explicitly-out-of-scope · launch criteria · phase roadmap · success metrics).

### 1d. Architect: design the system

For each major technical decision: research current best practice (context7 / official docs / web search), compare options with trade-offs, **factor in Christopher's existing infra** (VPS, Cloudflare, systemd-user units, wa-sender bridge, tech preferences). Design: system overview, data model, API/contracts, exact stack + versions with justification, infrastructure/deploy/CI, **security model** (auth, secrets, access, "don't disturb X" invariants). If the build is a **website/web-app, resolve the Rule-10 fork now** (Aenoxa product -> next-intl + next-themes; pitch/demo -> route to /oneshot-webapp). Present trade-off decisions, get alignment. Emit `docs/ideation/04-architecture.md`.

**End of Phase 1 (L3):** vision + validation(GO) + scope + architecture docs exist; the discovery-completeness gate is all `[x]`. Proceed to the Prototype gate.

---

## PHASE 2: PROTOTYPE-FIRST GATE  (NON-NEGOTIABLE 4)

**The single most important addition of the rewrite.** Before the plan is written, **validate the riskiest assumption with a throwaway prototype** and a concrete pass/fail criterion. A plan built on an unverified assumption wastes far more time than the prototype. (Christopher rejected the Gruvbox reskin after a full build; a 10-minute prototype would have caught it. market-events ran a dedicated recon worker that smoke-tested every free data source, the TUI framework, and the WA-bridge reuse path BEFORE the plan, and that recon reshaped the plan.)

### Prototype pass/fail contract (write the whole thing BEFORE prototyping)

```
Riskiest assumption : <the one thing that, if false, kills or reshapes the build>
PASS criterion      : <falsifiable, specific, measurable>
FAIL criterion      : <falsifiable, the negation with the failure signature>
Method              : <how you test it: curl, one import, a headless render, an API call>
Delegate?           : <recon worker if it is real work (L3); inline only if it is one curl / one import>
Verdict             : PASS | FAIL   (filled after)
Findings            : <surprises: geoblocks, rate limits, version incompat, header gotchas>
```

**HARD RULES:**
1. **State the riskiest assumption explicitly** (pulled from `01-vision.md` / `04-architecture.md`). Examples: "the free data source returns the fields we need from the VPS IP", "this library works with our stack version", "this design direction reads premium".
2. **Write the PASS and FAIL criteria BEFORE prototyping.** Not "see if it works". Example PASS: *"ForexFactory + BLS + OKX + Deribit all return parseable target fields with HTTP 200 from BOTH the local box and the VPS."* Example FAIL: *"any tier-1 source is unreachable or geoblocked with no bypass."*
3. **The prototype is THROWAWAY.** It tests the hypothesis, it is not v1 code. Iterate it cheaply.
4. **Delegate the prototype if it is real work** (Rule 3). For L3 this is a **dedicated recon worker** (its own task dir: `triage.json` `level:L2` is fine for the recon sub-task, plus `STATE.md` + brief; it writes `report.md` + `result.json` with the verdict table). Trivial smoke tests (one curl, one import) may run inline in the discovery session. Never run a sprawling prototype inline in main. Brief skeleton: `references/delegation-brief-templates.md`.
5. **Findings become planning inputs.** Record what passed, what failed, what was undocumented/surprising in `docs/ideation/02b-prototype-findings.md` (or the recon worker's report). The plan MUST cite them.

**Gate outcome:**
- **PASS** -> proceed to Phase 3 (Plan). Carry the findings forward.
- **FAIL on a load-bearing assumption** -> do NOT plan around it. Find a validated workaround (and re-prototype it), or take it back to Toper as a PIVOT/PARK. A plan that assumes a failed prototype is forbidden.

> **L2:** run a prototype **only if something is genuinely new**. A feature on a known stack with proven APIs may skip it (note that you judged it unnecessary). **L1:** never.

---

## PHASE 3: PLAN + SIGN-OFF  (the gate's second half, HARD GATE close; NON-NEGOTIABLE 2)

**Goal:** turn validated architecture + prototype findings into an actionable, phased build plan, then get explicit sign-off. Only sign-off unlocks artifacts + workers.

### 3a. Write the plan

Turn the MVP scope + architecture into ordered, **delegatable** milestones, each an independently-shippable, verify-gated unit (the P1->P4 shape). For each milestone: goal, the worker's deliverables, **acceptance/verification gate** (evidence-based: tests/curl/screenshots/DB rows, never claims), dependencies on prior milestones, "don't disturb" invariants, and (Rule 9) whether it is a **model carve-out**. Ban assumption-laden plans: every load-bearing assumption is prototype-validated or explicitly flagged as a risk. The plan MUST cite the prototype findings (what was de-risked, what constraints they imposed). Save it as `docs/ideation/05-build-plan.md` (and, for an initiative, a plan file beside the initiative, e.g. `~/claude/notes/initiatives/<slug>-plan.md`).

### 3b. Present + sign-off  (THE GATE)

Present the plan to Toper. **Until Toper explicitly says "approved" (or equivalent), you are FORBIDDEN to** write `triage.json` with `signoff:true`, create the initiative file, create any per-task dir, or spawn ANY build worker.

This is **mechanically backed** downstream: `spawn-worker.sh` (and `spawn-supervisor.sh`) call `check-triage.sh`, which refuses an `L3` `triage.json` whose `signoff != true` (**exit 4**), before the tmux window is created; the PreToolUse `triage-gate-hook.sh` backstops it (fail-open, loads at session start). So even if this prose is skipped, the spawn gate blocks an unsigned L3 build. **Do not flip `signoff` to `true` until the words land.** Record the sign-off (date + any decisions Toper made at sign-off, e.g. market-events' "reuse wa-sender queue · systemd user units · curl_cffi · local relay") in the initiative's decisions log.

**L3 sign-off gate checklist, ALL `[x]` before Phase 4:**
- [ ] >=10 clarifying questions asked AND the 7-dimension coverage gate met
- [ ] Answers received from Toper
- [ ] Prototype-First gate PASSED (Phase 2) with its criterion met
- [ ] Written plan presented
- [ ] Toper's explicit sign-off recorded (date + decisions) in the initiative decisions log

If Toper says "just start building" before the gate closes: **HOLD.** The gate is hard and mechanically backed; explain the two remaining boxes and close them.

---

## PHASE 4: EMIT THE ARTIFACTS  (3-tier pre-spawn discipline)

Only after sign-off (L3) / after the short plan (L2). Materialize the **real** 3-tier artifacts, do NOT invent a parallel structure. Reference each live template by path.

1. **`triage.json`** in each task notes dir (schema: `~/.claude/scripts/TRIAGE-SCHEMA.md`). Include the **`model`** field (Rule 9):
   ```json
   { "task_slug": "<slug>", "level": "L3", "scope": "<one-line>", "created": "<ISO ts>", "signoff": true, "model": "sonnet" }
   ```
   `signoff:true` ONLY for an L3 whose Phase-3 gate closed (L1/L2 ignore `signoff`). `"model":"sonnet"` by default; `"model":"opus"` ONLY for a carve-out milestone (auth/payments/secrets, customer-facing design-quality frontend, genuinely novel debugging), and note WHY in the milestone's triage note. Precedence when spawned: `CHILLDAWG_WORKER_MODEL` env > `triage.json.model` > `sonnet` floor (any non-`opus` token clamps to sonnet).
2. **Initiative file** at `~/claude/notes/initiatives/<area-verb-noun>.md` from `~/claude/notes/templates/initiative.md`: fill Outcome, Success criteria (from `03-scope.md`), the **L3 gate progress** checklist (the 5 items, all `[x]`), the Child-tasks list (one line per build milestone), the Decisions log (incl. sign-off). Reuse the area's EXISTING initiative if one exists, do not create a duplicate. market-events' initiative is the worked reference.
3. **Per-milestone task dirs** `~/claude/notes/<task-slug>-<date>/`: each with its own `triage.json`, a **`STATE.md`** from `~/claude/notes/templates/STATE.md` (fill NAME, worker name, **Parent initiative** link, starting point, roadmap, **Checkpoints** section, Resume cursor), and a **`brief.md`** (the equipped hand-off, see Phase 5 + `references/delegation-brief-templates.md`). The task slug must reference the parent initiative for navigability.
4. **`TaskCreate`** each milestone with the parent initiative slug in the description (full path; L1 may skip).
5. **Supervisor ledger (fleet only, Rule 8):** for an L3 multi-milestone build, also create the supervisor's task dir with its `triage.json` (`level:L3`, `signoff:true`) + a **`SUPERVISOR-STATE.md`** from `~/claude/notes/templates/SUPERVISOR-STATE.md` (Direction / Plan-partition / Fleet roster / Orchestration checkpoints / Resume cursor). This is the supervisor's resumable orchestration ledger.
6. **Scaffold shortcut (optional):** `~/.claude/scripts/workflows/scaffold-workflow.sh <pattern> <run-slug>` writes the per-worker task dirs (triage.json + STATE.md + role-shaped brief.md stub) and prints the exact spawn/brief commands. You still fill each brief's Task section. (`recon-implement-verify` fits prototype->build->verify; `fan-out-review` fits the /audit milestone.)
7. **`/project-init`** to scaffold a fresh repo: `/project-init <project-name> <nextjs|go|python> [--internal]` creates `~/claude/Git/repositories/<project>/`. The `docs/ideation/` docs then move into that repo. **Resolve the Rule-10 fork:** an Aenoxa product website/web-app inherits next-intl (`id`+`en`) + next-themes from milestone 0; a pitch/demo goes to `/oneshot-webapp` instead (do NOT scaffold it here with website defaults, the two skills deliberately conflict).

---

## PHASE 5: BUILD = DELEGATE  (NON-NEGOTIABLE 3, main NEVER builds inline)

Build is executed by **spawned, resumable background workers**, one per milestone, phased, with a verification gate closing each phase before the next opens. Main coordinates and gates only.

### Fleet-vs-single fork (do this FIRST)

Count the planned milestones/workers:
- **Multi-milestone L3 (a fleet / long-running):** spawn ONE **Opus supervisor** and hand IT the plan + initiative. It runs the per-milestone delegate/resume/audit loop and reports up to main only at checkpoints. Main stays free.
  ```bash
  ~/.claude/scripts/spawn-supervisor.sh <sup-window> [<cwd>] [<task_dir>]   # Opus; same triage gate (exit 4; L3 needs signoff)
  # verify attn peer (the window appears in local peers) BEFORE briefing
  ~/.claude/scripts/brief-worker.sh --supervisor <sup-window> <sup-brief>   # orchestrator preamble; mutually exclusive with --quick
  ```
  The supervisor reports its **DIRECTION/partition plan to main BEFORE spawning the fleet** (catch drift in minute 5, not hour 2), then milestone boundaries, blockers needing Toper, gated/irreversible actions, and DONE. It NEVER DMs Toper and NEVER sets `WHATSAPP=1` (escalations go supervisor -> main -> Toper). If it dies, it re-reads `SUPERVISOR-STATE.md` and re-attaches to the fleet, it does NOT re-spawn done/in-flight workers. Supervisor cap = **`CHILLDAWG_MAX_SUPERVISORS`=4**. Supervisor brief skeleton: `references/delegation-brief-templates.md`.
- **Single-milestone L2:** main spawns the one worker directly (below). A supervisor for one worker is pure overhead.

### Per-milestone delegation loop (the supervisor runs this for a fleet; main runs it for a single L2)

For each build milestone, in dependency order:

1. **Equip the brief** (Rule 7, `brief.md`). The **per-milestone equipped-brief checklist**, brief is INCOMPLETE if any box is unchecked:
   - [ ] milestone goal + acceptance/verification gate (from the plan)
   - [ ] docs/ideation context paths
   - [ ] credentials/access notes (`~/.claude/secrets.env` pattern, VPS access, test accounts)
   - [ ] don't-disturb invariants ("do not touch signal-trader / other VPS services")
   - [ ] evidence-based verification gate (tests/curl/screenshots/DB rows, not claims)
   - [ ] resumability contract (STATE.md checkpoints verify-before-mark + `result.json` on completion)
   - [ ] model (sonnet default / opus carve-out + why) matches `triage.json`
   - [ ] attn round-trip verified before briefing
2. **Spawn:** `~/.claude/scripts/spawn-worker.sh <window> [<cwd>] [<task_dir>]`. The **triage gate** refuses without a valid `triage.json` (and refuses an unsigned L3, exit 4). The **concurrency governor** (`worker-semaphore.sh`, default **`CHILLDAWG_MAX_WORKERS`=6, a GLOBAL/shared pool** across main + all supervisors, sized for the 4-vCPU box) refuses at the cap (**exit 5**); raise it per-spawn (`CHILLDAWG_MAX_WORKERS=8 spawn-worker.sh ...`) or queue (`CHILLDAWG_SPAWN_WAIT=120 spawn-worker.sh ...`). **After spawn, verify the attn round-trip** (the worker appears in local peers) BEFORE briefing. No brief without attn.
3. **Brief:** `~/.claude/scripts/brief-worker.sh <window> <brief_file>` (full path). It injects the role-override preamble (open STATE.md first, set IN_PROGRESS, checkpoint + verify-before-marking, write `report.md` + `result.json` on completion) and refuses if `STATE.md` is missing or (full path) lacks a Parent-initiative link (**exit 3**). (L1 sub-tasks: `brief-worker.sh --quick`.)
4. **Serialize on dependency, parallelize where the graph allows** within the shared cap of 6. market-events ran P1->P2->P3->P4 serially (each built on the last). **One phase's verification gate must PASS before the next phase's worker is spawned.**
5. **Poll / monitor:** `~/.claude/scripts/fleetview.sh [--watch <secs>]` is the live cockpit (per-worker STATE.md status + mtime, STALLED flag if no update >10min, checkpoint progress, Resume cursor, context%, model). Poll every ~5 min; investigate a stall. (For a fleet, the SUPERVISOR polls; main just consumes its checkpoints.)
6. **Resume on death** (NOT redo): if a worker dies (session limit / crash), it RESUMES from its last verified checkpoint. `~/.claude/scripts/resume-worker.sh <window> <task-dir> [--with-brief <orig-brief>]` re-briefs it with a RESUME preamble pointing at its `STATE.md` Resume cursor. (market-events' P3 and P4 each survived a session-limit death and resumed cleanly, this is the model, not an exception.)
7. **Ingest the result:** on completion the worker writes `result.json` next to `STATE.md`; read/validate with `~/.claude/scripts/result-schema.sh <dir>` (defaults to a full pretty-print; `--validate` exits 0/1, `--field <f>` extracts one field). Schema: `{task_slug, status, summary, deliverables, evidence, blockers, followups, staged_for_human}`. Update the initiative's child-task status, then open the next milestone.

**Never** write product code in the main `/ideate` session. If you catch yourself editing the product repo here, STOP: that work belongs in a worker.

---

## PHASE 6: /audit AT MILESTONE BOUNDARIES

At natural milestone boundaries (a phase closes, or before ship), run **`/audit <repo-path>`**. It is project-type-adaptive: it **auto-detects** the type (web-app / backend-service / **data-pipeline** / cli-tui / library / infra) and selects the matching lens roster + verdict rubric, then runs an adversarial refutation pass on Critical/High before the verdict. Do NOT hand-pick lenses, let `/audit` detect the type (override with `--type` only if detection is wrong).

> For a data system like market-events, `/audit` NOW auto-selects the **data-pipeline** roster (core-3: **data-integrity, reliability, security**), NOT the web-app a11y lenses. (This is forward guidance: the historical 2026-06-15 market-events run predated the type-adaptive roster and used the older biz-logic/security/perf/quality/deps set.)

Feed the audit's blockers back as **new delegated fix milestones**, then re-audit. **NEVER ship on an unrefuted Critical.** This replaces any hand-rolled "security/perf/design review" bullets, `/audit` does all of that, adapted to the type, with severity tiers.

---

## PHASE 7: /ship + CLOSE THE LOOP

When the build passes its audit gate:

1. **`/ship`** runs its **9-step pipeline** (cite it, do not re-derive its gate mechanics):
   ```
   1 /simplify -> 2 security review -> 3 /e2e -> 4 version+changelog -> 5 README
   -> 6 /commit -> 7 /preflight -> 8 PUSH -> 9 distribution tail
   ```
   **Step 8 (push) is the only irreversible moment.** **Step 9 (distribution tail)** is where the release becomes real and observable: (a) changelog refresh, (b) **annotated** semver tag (`git tag -a`) + push, (c) CI watch (`gh run watch` then the MANDATORY `gh run view <id> --json conclusion,status` re-confirm, PASS only on `conclusion == "success"`), (d) optional publish (OFF by default). `/ship` **never SSHes to the VPS**; server-deploy mechanics belong to `/deploy-landing` and `/oneshot-webapp`.
   - **If /ship is delegated to a worker,** the brief bakes in the push gate from the start: "run steps 1-7, STOP before Step 8, report the commit SHAs + the preflight verdict, wait for the explicit go" (per /ship S-9). Stage-and-hold brief: `references/delegation-brief-templates.md`.
2. **Deploy** per the architecture doc (VPS + nginx + certbot via `/deploy-landing`, or `/oneshot-webapp` for a pitch demo, or Vercel). Do NOT disturb other VPS services (the standing invariant).
3. **Smoke-test in the target environment:** verify the core flow live (curl codes, a real run, screenshots), not just locally. Close the loop with **evidence, not claims**.
4. **Update artifacts:** mark the initiative `COMPLETE` (or move to an OPERATE/OBSERVE mode like market-events), fill its "Outcome" section, update memory with durable project facts/decisions (`/remember` or a project memory file), check off the tasks.
5. **Report back to main** with what shipped, what was verified (evidence), what is pending, and surprises. (For a fleet, the supervisor reports DONE up to main.)

---

## L1 just-do-it path  (Phase 0 said L1)

A trivial idea does not pay for discovery, prototype, plan, or sign-off, but it is STILL delegated (main never builds inline, Rule 3). The L1 fast-path:

1. `~/claude/notes/<task-slug>-<date>/` with **`triage.json`** `{"level":"L1", ...}` (no `signoff`; `model` defaults to sonnet), a **one-line `brief.md`**, and a **stub `STATE.md`** (name / status / one-liner). NO initiative file, NO parent-initiative linkage.
2. `spawn-worker.sh <window>` -> verify attn -> `brief-worker.sh --quick <window> <brief>` (the `--quick` flag accepts the stub).
3. The worker does it, verifies, reports back. Done.

> Pure-comms "ideas" (send a message, list windows, answer a question, read a file) are NOT delegatable tasks: they stay in main, need no worker, and get only an `📊 TRIAGE - L1` header.

---

## L2 light path  (Phase 0 said L2)

A real but bounded idea: full 3-tier artifacts, but NO L3 >=10-Q floor and NO sign-off gate. Trimmed flow:

1. **Capture-lite:** a focused probe (not the full floor; ask what genuinely changes the build, 0 to a handful of questions scaled to ambiguity). Emit a short `docs/ideation/01-vision.md` (or one combined doc).
2. **Prototype ONLY if something new** (Rule 4): a new library/API/integration/design gets a quick prototype with a pass/fail criterion (delegate it if it is real work). A known-stack feature with proven APIs may skip it (note you judged it unnecessary).
3. **Short written plan** presented to Toper (L2 gets a plan, not a hard sign-off gate, but still align before building if there are trade-offs).
4. **Emit artifacts** (Phase 4): `triage.json` `level:L2` (+ `model`), an initiative file (create or reuse the area's existing one), the task dir(s) with STATE.md + brief.md.
5. **Delegate 1-2 workers directly** (Phase 5 loop, no supervisor, most L2 work is one or two milestones).
6. **/audit** if substantial enough; **/ship** to release. Close the loop.

If scope explodes mid-L2-discovery (it turns out to be a new repo / customer-facing / touches auth), **re-triage UP to L3** and invoke the full gate before any worker. Round up, never down.

---

## `/ideate continue`: resume from the saved artifacts  (kills the old "new session each phase" friction)

The old skill told Christopher to open a brand-new session for every phase (a context workaround). That friction is gone: the **docs + STATE.md ARE the resumable state** (Rule 5). On `/ideate continue`:

1. **Locate the artifacts.** Find the project's `docs/ideation/` (in `~/claude/Git/repositories/<project>/` if scaffolded, else `~/claude/notes/<slug>/`) and the initiative `~/claude/notes/initiatives/<slug>.md`. If ambiguous, ask which idea.
2. **Read the state.** The initiative's L3-gate checklist + child-task statuses tell you which phase is done. The `docs/ideation/NN-*.md` files tell you discovery state. The latest task `STATE.md` (Checkpoints + Resume cursor), or `SUPERVISOR-STATE.md` for a fleet, tells you mid-build state.
3. **Resume from the first incomplete phase/checkpoint**, do NOT re-run a completed phase. If discovery docs exist through `04-architecture.md` but no `02b-prototype-findings.md`, resume at Phase 2. If the plan is signed and workers are mid-flight, resume at Phase 5 (poll FleetView, resume any dead worker via `resume-worker.sh`). Trust `[x]` items; re-verify the last one cheaply; continue.

There is no "summarize and tell Christopher to start a new session" step. Continuity lives on disk. The file contract the resume path depends on is stable: `01-vision`, `02-validation`, `02b-prototype-findings`, `03-scope`, `04-architecture`, `05-build-plan`.

---

## FAILURE-MODE PLAYBOOKS  (summary; full recovery commands in `references/failure-playbooks.md`)

| Symptom | First move | Then |
|---|---|---|
| **Worker died mid-milestone** (session limit / crash) | `resume-worker.sh <window> <task-dir> [--with-brief <orig-brief>]` | RESUME from the verified checkpoint, NEVER redo. Re-verify the last `[x]` cheaply, continue from the first `[ ]`. |
| **Worker stalled** (STATE.md mtime >10min while active) | `fleetview.sh` to spot the STALLED flag, `tmux capture-pane` to inspect | resume or re-brief; do not assume "done" from silence. |
| **attn peer never appears after spawn** | do NOT brief blind | fall back to a status file (`feedback_session_delegation`), investigate before proceeding. No brief without attn. |
| **Prototype FAILED on a load-bearing assumption** | do NOT plan around it | PIVOT (adjust vision, re-validate) or PARK (`/tasks` LATER, stop) or find + re-prototype a validated workaround. |
| **spawn-worker.sh exit 4** | missing/invalid `triage.json` OR unsigned L3 | write/fix `triage.json`, or close the L3 sign-off gate (flip `signoff:true` only after Toper's words). It is a GATE, not a bug. |
| **spawn-worker.sh exit 5** | worker cap reached (6 shared) | raise `CHILLDAWG_MAX_WORKERS` per-spawn or queue with `CHILLDAWG_SPAWN_WAIT`. |
| **Scope explodes mid-L2 discovery** (turns out L3) | re-triage UP | invoke the full L3 gate (>=10 Q + coverage + prototype + sign-off) before ANY worker. |
| **/audit returns Critical/High blockers** | delegate the fixes as NEW milestones | re-audit; never ship on an unrefuted Critical. |
| **Toper says "just start building" before L3 sign-off** | HOLD | the gate is hard and mechanically backed (exit 4); name the open boxes and close them. |

**Do / Don't:**
- DO route a pitch-demo idea's whole build to `/oneshot-webapp`. DON'T build it via ideate's generic i18n+theme milestone workers.
- DO spawn an Opus supervisor for a fleet. DON'T babysit FleetView in main for a multi-hour L3.
- DO set `model:opus` on the auth/payments + design-quality milestones. DON'T let carve-out milestones default to Sonnet.
- DO cite /ship's 9 steps. DON'T re-derive its tag + CI-watch mechanics.
- DO write the prototype criterion before prototyping. DON'T "see if it works".
- DO keep docs/ideation as source of truth. DON'T summarize-and-open-a-new-session.
- DO round borderline triage UP. DON'T talk an L3 down to L2 to skip the gate.
- DO verify attn before briefing every worker. DON'T brief blind.

---

## ROBUSTNESS SELF-CHECK  (run before declaring an /ideate flow correctly set up)

- [ ] **Phase 0 triage header printed** with the correct level + triggering signal; borderline rounded UP.
- [ ] **L3 only:** >=10 questions asked AND answered (count tracked) AND all 7 dimensions covered AND riskiest assumption named; not 6-and-called-done.
- [ ] **Prototype-First gate** ran for anything new, with a **concrete PASS/FAIL criterion stated BEFORE** prototyping; findings recorded and referenced by the plan. (Skipped only for L1, or L2-with-nothing-new with a noted reason.)
- [ ] **L3 only:** plan presented AND explicit Toper sign-off received BEFORE any artifact/worker; `triage.json` `signoff` was `false` until then.
- [ ] **Fleet -> one Opus supervisor** spawned (multi-milestone L3); single L2 -> main spawned the one worker directly. Main is not babysitting a fleet.
- [ ] **`model` field set correctly** on every milestone `triage.json` (sonnet default; opus only on a stated carve-out).
- [ ] **Website fork resolved:** Aenoxa product -> next-intl+next-themes from milestone 0; pitch/demo -> routed to /oneshot-webapp (NOT ideate's generic build).
- [ ] **Boundary-charter routing applied:** the input really was a build (not a /tasks to-do, a /pitch-deck, a /project-init scaffold, a /deep-research pass).
- [ ] **Every referenced artifact is the REAL one** at its real path: `triage.json` (`TRIAGE-SCHEMA.md`), initiative/STATE/SUPERVISOR-STATE templates, spawn/brief/resume/result/fleetview/supervisor scripts under `~/.claude/scripts/`. No invented parallel structure.
- [ ] **Build is delegated, never inline;** each milestone has a task dir + equipped brief (8-box checklist) + verification gate + attn verified.
- [ ] **Workers are resumable:** STATE.md checkpoints + result.json contract in every full-path brief; a dead worker resumes, does not redo.
- [ ] **/audit ran at the milestone boundary** with auto-detected type; blockers fed back as delegated fixes; no ship on an unrefuted Critical.
- [ ] **/ship's 9 steps cited** (incl. the step-9 distribution tail); loop closed with evidence in the target environment; initiative marked complete + memory updated.
- [ ] **docs/ideation/ is the source of truth;** `/ideate continue` resumes from it + STATE.md.
- [ ] **Output is dash-clean** (no em/en dashes in the header, plan, or questions shown to Toper).

If any box fails, the flow is NOT correctly set up. Fix it before building.

---

## VERIFIED ENVIRONMENT FACTS  (dated 2026-07-03; re-verify before asserting)

- **Scripts** (all present + executable at `~/.claude/scripts/`): `spawn-worker.sh`, `brief-worker.sh`, `resume-worker.sh`, `result-schema.sh`, `fleetview.sh`, `worker-semaphore.sh`, `check-triage.sh`, `spawn-supervisor.sh`. The scaffold helper lives ONE level down at `~/.claude/scripts/workflows/scaffold-workflow.sh` (NOT top-level), beside the playbooks `fan-out-review.md`, `recon-implement-verify.md`, `loop-until-green.md`, `README.md`.
- **Caps** (`worker-semaphore.sh`): `CHILLDAWG_MAX_WORKERS` default **6** (GLOBAL/shared across main + all supervisors); `CHILLDAWG_MAX_SUPERVISORS` default **4**. Per-spawn override + `CHILLDAWG_SPAWN_WAIT` queueing. Cap refusal = **exit 5**.
- **Model precedence** (`spawn-worker.sh`): `CHILLDAWG_WORKER_MODEL` env > `triage.json.model` > `sonnet`; any non-`opus` token clamps to the sonnet floor. Supervisors are Opus (`spawn-supervisor.sh`, `CHILLDAWG_SUPERVISOR_MODEL` default `opus`).
- **Triage gate** (`check-triage.sh`, called by both spawn scripts before the window is created): **exit 4** on missing/invalid `triage.json` OR `level=L3` with `signoff != true`. PreToolUse `triage-gate-hook.sh` (matcher `Bash`) backstops it fail-open; hooks load at session start.
- **`triage.json` schema** (`TRIAGE-SCHEMA.md`): `task_slug`, `level` (L1|L2|L3, required), `scope`, `created` (ISO), `signoff` (L3-only, starts false), `model` (optional: `sonnet` default / `opus` carve-out).
- **brief-worker.sh flags:** default full path (requires STATE.md + a "Parent initiative" line, **exit 3** if STATE.md missing); `--quick`/`--l1` (L1 stub STATE.md, relaxes linkage); `--supervisor` (orchestrator preamble; mutually exclusive with `--quick`).
- **spawn-supervisor.sh** `<window> [<cwd>] [<task_dir>]`: same triage gate (L3 needs sign-off), separate supervisor cap, launches Opus. Spawn ONE only for a fleet or long-running initiative.
- **Templates** (`~/claude/notes/templates/`): `initiative.md` (Outcome / Success criteria / Context / Child tasks / Decisions log), `STATE.md`, `SUPERVISOR-STATE.md` (Direction / Plan-partition / Fleet roster / Orchestration checkpoints / Resume cursor).
- **/ship** is a 9-step pipeline ending in the distribution tail (annotated tag + CI watch + optional publish); step 8 is the only irreversible moment; it never SSHes to the VPS.
- **/audit** is type-adaptive (data-pipeline core-3 = data-integrity, reliability, security); **/project-init** `<name> <nextjs|go|python> [--internal]` bakes next-intl+next-themes and deliberately conflicts with /oneshot-webapp's light-only defaults.

---

## References

- **Operating model** (the gears this drives): `~/.claude/CLAUDE.md`: Task Complexity Triage, 3-Tier Task Hierarchy, Prototype & Smoke Test Before Planning, Main-Session-is-DISCUSSION-ONLY, Equip Before Delegating, Close the Loop, **Worker Orchestration Tooling (Wave-3)**, **Worker Model Policy (Wave-7)**, **Supervisor Orchestration Layer (Wave-7)**.
- **Triage gate schema** (incl. the `model` field): `~/.claude/scripts/TRIAGE-SCHEMA.md`. **Templates:** `~/claude/notes/templates/{initiative,STATE,SUPERVISOR-STATE}.md`.
- **Pipeline scripts:** `~/.claude/scripts/{spawn-worker,brief-worker,resume-worker,result-schema,fleetview,worker-semaphore,check-triage,spawn-supervisor}.sh`; workflow scaffolds: `~/.claude/scripts/workflows/` (`scaffold-workflow.sh` + the 3 playbooks).
- **Sibling skills:** `/audit`, `/ship`, `/commit`, `/preflight`, `/project-init`, `/oneshot-webapp`, `/pitch-deck`, `/deploy-landing`, `/deep-research`, `/remember`, `/journal`, `/tasks`, `/remindme`, `/worklog`.
- **This skill's reference files:** `references/worked-example-market-events.md`, `references/delegation-brief-templates.md`, `references/failure-playbooks.md`.
- **The worked example this flow reproduces:** `~/claude/notes/initiatives/market-events-calendar.md` + `~/claude/notes/initiatives/market-events-calendar-plan.md` (idea -> L3 gate (12 Q) -> prototype recon worker -> plan -> sign-off -> P1-P4 delegated workers w/ resume -> data-pipeline /audit -> live).
- **Skill-robustness bar:** memory `feedback_skill_authoring_robustness`. **Spawn protocol:** memory `feedback_session_delegation`. **Model carve-out for hackathon:** memory `feedback_hackathon_opus_max`.
