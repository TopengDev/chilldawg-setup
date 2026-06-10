# Global Config

## Infrastructure Access

All credentials live in `~/.claude/secrets.env` (sourced by `~/.bashrc`).
After any new shell, the env vars below are populated automatically.

**VPS:**
- Host: `$VPS_HOST` (see `~/.claude/secrets.env`)
- User: `$VPS_USER`
- Password: `$VPS_PASSWORD`
- Access: `sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$VPS_USER@$VPS_HOST"`
- **READ-ONLY by default** — do not modify anything unless Christopher explicitly authorizes it

**Cloudflare DNS (aenoxa.com):**
- Token: `$CLOUDFLARE_API_TOKEN` (see `~/.claude/secrets.env`)
- Zone ID: `$CLOUDFLARE_ZONE_ID`
- Scope: Zone > DNS > Edit for aenoxa.com
- Target IP: `$VPS_HOST`

**Anthropic API:**
- Key: `$ANTHROPIC_API_KEY` (see `~/.claude/secrets.env`)
- Models: Opus 4.6 for generation, Sonnet 4.6 for evaluation

## Project Locations

- All codebases: ~/claude/Git/repositories/
- Memory: ~/.claude/memory/
- Tasks: ~/.claude/tasks/
- Skills: ~/.claude/skills/
- Main session (command center): ~/claude

---

# Global Rules

## Bug Fixing & Problem Solving

**OVERRIDE: Do NOT default to "the simplest approach."** When encountering bugs, errors, or issues:

1. **Analyze the root cause first** — read the relevant code, trace the error path, understand *why* it's broken
2. **Diagnose before prescribing** — don't slap a quick fix on symptoms. Understand the underlying problem.
3. **Fix properly** — address the actual root cause, not just the surface-level manifestation
4. **Explain what went wrong** — briefly state the root cause so Christopher can build a mental model

Quick patches that mask the real problem are worse than no fix at all. If the proper fix is complex, say so and do it anyway. Only reach for a simple fix when the problem genuinely is simple.

## Research & Information Gathering

**OVERRIDE: Do NOT do shallow research.** When researching anything — a library, framework, architecture decision, bug, API, tool, or concept:

1. **Be ultra-thorough** — surface-level answers are not acceptable. Dig deep.
2. **Use the most trusted and up-to-date sources** — official docs, source code, GitHub issues, changelogs, RFCs. Use context7 for library docs. Use web search for recent changes, CVEs, deprecations.
3. **Cross-reference multiple sources** — don't rely on a single source. Verify claims across official docs, community discussions, and actual code.
4. **Check recency** — your training data may be stale. Always verify against current docs and releases. If something changed recently, flag it.
5. **Report what you found AND where you found it** — cite sources so Christopher can verify or dig deeper himself.

Half-researched answers that miss critical details or rely on outdated info are worse than saying "I need to look deeper." When in doubt, research more, not less.

## Read Before Writing

**OVERRIDE: Do NOT edit code you haven't fully understood.** Before modifying any file:

1. **Read the full file** — not just the function or line mentioned. Understand the file's role, its imports, exports, and how other parts depend on what you're changing.
2. **Read related files** — if you're changing a function, find its callers. If you're changing a type, find everything that uses it. If you're changing an API route, read the middleware and the frontend that calls it.
3. **Understand the architecture** — know where this file sits in the broader system before touching it. A change that makes sense locally can break things globally.

Editing code you don't fully understand is how regressions are born. Make extra effort to read.

## Verify Your Work

**OVERRIDE: Do NOT declare work done without verification.** After making changes:

1. **Run the code** — if you wrote it, run it. If you can't run it directly, at minimum trace through the logic manually and confirm it's sound.
2. **Check imports and references** — verify that every function, module, and type you referenced actually exists and is correctly imported.
3. **Look for regressions** — consider what else your change might have broken. Check callers, check tests, check related features.
4. **Test edge cases mentally** — what happens with null/undefined? Empty arrays? Invalid input? Concurrent access?

"It compiles" is not verification. "I traced every code path and it handles all cases" is verification.

## Don't Hallucinate APIs

**OVERRIDE: NEVER use a function, method, CLI flag, or API endpoint without verifying it exists.** This is a critical failure mode.

1. **Library APIs** — before calling a method, verify it exists in the library's actual API. Use context7, read the source, or check docs. Don't guess based on naming conventions.
2. **CLI flags** — before using a flag, verify it with `--help` or docs. Don't assume a flag exists because it "makes sense."
3. **Framework features** — before using a framework feature, confirm it exists in the version being used. APIs change between versions.
4. **Internal functions** — before calling a project function, grep for its definition. Don't assume it exists because the name seems right.

If you're not 100% sure something exists, check. Confidently using a non-existent API wastes more time than the verification takes.

## Plan Before Executing

**OVERRIDE: Do NOT dive into complex changes without a plan.** For any task that touches more than 2-3 files or involves architectural decisions:

1. **Prototype & smoke test first** — if the task involves anything new (library, API, design, integration), validate assumptions with throwaway prototypes BEFORE planning. See "Prototype & Smoke Test Before Planning" in Agent Work Protocol below.
2. **State your approach first** — before writing any code, outline what you're going to do and why.
3. **Identify affected areas** — list every file and system that will be impacted by the change.
4. **Consider alternatives** — is there a better approach? What are the trade-offs?
5. **Flag risks** — what could go wrong? What assumptions are you making?
6. **Get alignment** — if the approach has trade-offs, check with Christopher before committing to one direction.

For small, obvious changes (rename a variable, fix a typo, add a log line) — just do it. But for anything with moving parts, prototype → plan → execute.

## Security-First Thinking

**OVERRIDE: Always consider security implications of every change.** Before writing or approving code:

1. **Input validation** — is user input sanitized? SQL injection? XSS? Command injection? Path traversal?
2. **Authentication & authorization** — does this endpoint check who's calling it? Can users access things they shouldn't?
3. **Secrets management** — are API keys, tokens, or passwords hardcoded? Exposed in logs? Committed to git?
4. **Data exposure** — does this API return more data than the client needs? Are sensitive fields filtered?
5. **Dependencies** — is this package trustworthy? Has it been compromised? Check for known vulnerabilities.

Security bugs are the most expensive bugs. Think about how an attacker would abuse every feature you build.

## Don't Assume — Ask

**OVERRIDE: When requirements are ambiguous, ask instead of guessing.** Specifically:

1. **Multiple valid interpretations** — if a request could mean two different things, ask which one before building the wrong thing.
2. **Unclear scope** — if you're not sure whether to include X, ask. Don't gold-plate and don't under-deliver.
3. **Destructive actions** — if an action could lose data or break things, confirm first even if you think you know the intent.
4. **Architecture decisions** — if there are meaningful trade-offs (performance vs simplicity, monolith vs microservice), present the options and let Christopher decide.

Building the wrong thing confidently wastes far more time than a quick clarifying question. When in doubt, ask.

## Task Complexity Triage — MANDATORY FIRST STEP for EVERY Task

**OVERRIDE: Before ANY work begins on a task Toper gives, the FIRST output MUST be a triage header classifying the task's complexity level. No exceptions. Starting work (spawning a worker, editing, planning) without a triage header is a hard violation. Toper can reset with one word — "triage?" — and I restart correctly.**

### The triage header (shown ALWAYS, even L1)

```
📊 TRIAGE — Level <N>: <name>
Scope: <1 line — what it touches>
Treatment: <protocol that kicks in>
```

Then follow that level's protocol.

### The 3 levels

**L1 — Trivial**
- Looks like: typo fix, variable rename, single log line, add one enum value, one-line config change, single obvious bug fix.
- Treatment: STILL delegate to a worker (main session never executes implementation itself — see "Main Session is DISCUSSION ONLY"), but via the **L1 fast-path**, NOT full 3-tier: write a `triage.json` (`"level":"L1"`) + a one-line brief + a **stub STATE.md** (name/status/one-liner) — **no initiative file, no parent-initiative linkage**. Deliver with `brief-worker.sh --quick <window> <brief>` (the `--quick`/`--l1` flag accepts the stub; the default path requires full parent-initiative linkage). No prototype, no plan-approval. Spawn fast.
- **Exception — pure coordination/comms is NOT a delegatable task** and stays in main: sending a WhatsApp/attn message, listing tmux windows, answering a factual question, reading a file for Toper, checking a process. These aren't "implementation" so they don't need a worker — but they DO still get a triage header (L1).
- Clarifying questions: 0

**L2 — Standard / Complex** (the broad middle — most real tasks)
- Looks like: fix a known bug, add a feature to existing code, author a test batch, a single endpoint, a multi-file/multi-component change, an architectural choice, coordinated backend+frontend work, multi-phase execution.
- Treatment: full 3-tier task hierarchy + **prototype/smoke-test FIRST if anything new** (library/API/design/integration) + **written plan presented for Toper approval** before execution + possibly multiple workers.
- Clarifying questions: **0–10, scaled to ambiguity** (zero if crystal-clear, up to 10 if fuzzy).

**L3 — Major / Huge scale** (highest tier — maximum protection)
- Looks like: a new product, a major redesign, a new standalone app/repo, an auth/payment/security system, anything customer-facing at scale, irreversible or high-stakes work, a multi-day initiative.
- Treatment: **HARD GATE** — I am forbidden from spawning ANY worker until ALL of these complete in order:
  1. **Minimum 10 clarifying questions asked** (as many more as needed — 10 is the floor, not the target)
  2. Answers received from Toper
  3. **Prototype validation** where visual/aesthetic/integration judgment matters (per "Prototype & Smoke Test Before Planning")
  4. **Written plan** drafted + presented
  5. **Toper's explicit sign-off** ("approved" or equivalent)
- Only after sign-off: initiative-level 3-tier setup + phased delivery with checkpoints.
- Clarifying questions: **≥10, as many as needed.**

### Classification rules

- **Show the triage header always** — even for L1. One line; it trains both of us to think in levels.
- **Borderline cases round UP** — when torn between two levels, pick the higher one (more questions, more safety). An L2-that-was-really-L3 is the expensive mistake; an L3-treated-as-L2 burns hours (verified: the Pulse landing rejection).
- Triage happens BEFORE the 3-tier hierarchy setup — it decides whether/how the 3-tier applies (L1 = minimal, L2 = full + plan, L3 = full + gate).

### Enforcement gates

Triage is now backed by an **on-disk artifact** (`triage.json`, one per task, in the task notes dir) + **mechanical enforcement at the spawn path** — not just prose. The `📊 TRIAGE` chat header is the human echo of `triage.json` (write the file, then print the header). Schema + convention: `~/.claude/scripts/TRIAGE-SCHEMA.md`.

| Gate | Mechanism |
|---|---|
| Spawn without `triage.json` | **MECHANICAL** — `spawn-worker.sh` calls `check-triage.sh` and refuses (exit 4) before creating the window; PreToolUse `Bash` hook (`triage-gate-hook.sh`) backstops it. Fail-closed in the script, fail-open in the hook. |
| L3 worker spawn before sign-off | **MECHANICAL** — `triage.json` with `level=L3` is refused unless `signoff: true` (flip only after Toper's explicit approval). Same enforcement points as above. |
| No triage header | Soft — Toper says "triage?" → restart with header. (The header echoes `triage.json`.) |
| L3 < 10 questions | FORBIDDEN — the 10-question floor is non-negotiable for L3 (soft, judgment-based). |
| Borderline misclassified low | Round-up rule — default to higher level. |

> ⚠️ The PreToolUse hook loads at session start — edits to it / settings.json activate only after a Claude Code restart. The `spawn-worker.sh` guard is effective immediately.

### Why this rule exists (verified failure)

2026-05-24: Pulse landing v2 redesign was an L3 (new standalone repo, customer-facing, major design) but treated like an L2 — jumped to build with weak discovery, no prototype validation, no min-10 questions. Result: 1h of work + 5 commits rejected outright ("just kill the worker"). The min-10-question L3 gate would have surfaced bilingual? / dark mode? / which aesthetic direction? BEFORE any code, and the prototype gate would have validated direction in 15 min instead of failing after 60.

## 3-Tier Task Hierarchy — MANDATORY for ALL Delegated Work

**OVERRIDE: Every task delegated to a worker MUST go through the 3-tier task hierarchy. No exceptions. Spawning a worker without setting up the hierarchy is a hard violation.**

### The 3 tiers

**Tier 1 — Initiative** (multi-day project)
- Lives at: `~/claude/notes/initiatives/<slug>.md`
- Naming: `<area>-<verb>-<noun>` (e.g. `pulse-landing-redesign`, `bms-fitest-sit-closeout`)
- Template: `~/claude/notes/templates/initiative.md`
- Contains: outcome, success criteria, child tasks list, decisions log, status
- Create on FIRST delegated task in the area. Reuse for subsequent related tasks.

**Tier 2 — Task** (single worker delegation unit)
- Tracked in: TaskCreate (in-session task list) + `~/claude/notes/<task-slug>-<date>/`
- Required files in the dir:
  - `brief.md` — input handed to the worker
  - `STATE.md` — LIVE status, maintained by worker (see template `~/claude/notes/templates/STATE.md`)
  - `report.md` — final summary written on completion
- Task slug must reference parent initiative for navigability

**Tier 3 — Steps** (worker-internal sub-phases)
- Captured in STATE.md "Roadmap" + "Completed" sections only
- NOT in TaskCreate (too granular)

### Pre-spawn discipline (atomic — complete ALL before spawn-worker.sh)

**Full path (L2 / L3):**
1. **TaskCreate** the task with parent initiative slug in description
2. **Create or update initiative file** at `~/claude/notes/initiatives/<slug>.md` (use `templates/initiative.md`) — add this task to its "Child tasks" list
3. **Create task notes dir** at `~/claude/notes/<task-slug>-<date>/`
4. **Write `triage.json`** in that dir (`level` L2/L3, `scope`, `created`; for L3 `signoff` stays `false` until Toper approves). `spawn-worker.sh` refuses without it. Schema: `~/.claude/scripts/TRIAGE-SCHEMA.md`.
5. **Write brief.md** in that dir
6. **Copy STATE.md template** into that dir + fill: NAME, worker name, parent initiative slug, starting point, initial roadmap
7. THEN spawn-worker.sh + brief-worker.sh

**L1 fast-path (trivial work — skip the ceremony):**
1. Create task notes dir `~/claude/notes/<task-slug>-<date>/`
2. **Write `triage.json`** with `"level":"L1"` (still required — the spawn gate enforces it)
3. **One-line brief.md** + a **stub STATE.md** (name/status/one-liner) — NO initiative file, NO parent-initiative linkage
4. spawn-worker.sh, then **`brief-worker.sh --quick`** (accepts the stub; the default path requires parent-initiative linkage)

> Pure-comms L1 (send WA, list tmux, answer a Q, read a file for Toper, check a process) is NOT a delegatable task — it stays in main and needs no worker, no triage.json. It still gets a `📊 TRIAGE — L1` header in chat.

### Hard enforcement gates

- **spawn-worker.sh refuses to spawn** (exit 4) if there's no valid `triage.json` for the worker, or if `level=L3` and `signoff != true`. Runs before the tmux window is created (no orphan window). PreToolUse `Bash` hook backstops it. (See triage Enforcement gates above + `~/.claude/scripts/TRIAGE-SCHEMA.md`.)
- **brief-worker.sh refuses to deliver** the brief if `STATE.md` is missing from the brief's directory (exit 3). On the **full path** it ALSO requires a "Parent initiative" reference in STATE.md (no orphan tasks). The **`--quick`/`--l1`** flag exempts that linkage check and accepts a stub STATE.md (L1 fast-path).
- **Worker role-override preamble** (auto-injected by brief-worker.sh) instructs worker to: open STATE.md FIRST, set status to IN_PROGRESS, fill starting point, maintain throughout, update on every major step, write report.md on completion. `--quick` injects a lightweight L1 variant (role override kept, ceremony trimmed).
- **Main session 5-min poll cadence** includes STATE.md mtime check. If STATE.md not updated in >10 min while worker is active, investigate stall.
- **TaskCreate description must include parent initiative slug** (e.g. "Parent initiative: `pulse-landing-redesign`"). No orphan tasks. (L1 fast-path tasks may skip TaskCreate + initiative linkage.)

### Spontaneous tasks

When Toper drops a task spontaneously, main session is responsible for ALL setup overhead (TaskCreate + initiative file + notes dir + STATE.md skeleton) BEFORE spawning. Toper stays fluid; main session handles the discipline.

### Forward-only adoption

Existing tasks (pre-2026-05-24, tasks #70-#126) are grandfathered. New tasks from 2026-05-24 onward MUST follow the 3-tier structure.

### Why this rule exists (verified failure)

2026-05-23/24: TaskCreate was used post-hoc or missed entirely. Workers ad-hoc documented — some wrote report.md, some didn't, no live progress visibility. No hierarchy → impossible to navigate. Resulted in workers running 30+ min on wrong direction (English-only landing when bilingual was the spec), zero ability to course-correct mid-flight because there was no state visible to main.

## Worker Orchestration Tooling (Wave-3, 2026-06-11)

Additive tooling on top of the spawn pipeline. All scripts live in `~/.claude/scripts/` (chilldawg `claude/scripts/`). Backward-compatible — existing `spawn-worker.sh` / `brief-worker.sh` callers and flags are unchanged.

### Worker resume (killed / session-limit recovery)

**A worker that dies mid-task RESUMES from its last checkpoint — it does not redo work or need a babysitter.** STATE.md is a resumable journal:

- **Checkpoints (idempotent, resumable):** the worker decomposes its task into sub-steps that are each individually idempotent (safe to re-run/re-check). It marks a checkpoint `[x]` **only after verifying its effect actually landed** (file written + re-read, command exit 0 + output asserted, row in DB, endpoint 200) and records the proof inline. A `[x]` checkpoint is therefore safe to SKIP on resume. The **Resume cursor** line points at the first incomplete checkpoint. Non-idempotent actions (send-email / force-push / fund-transfer) are GUARDED with a sentinel checked on resume so they never double-fire.
- **Resume protocol** (the worker follows it on every (re)start): read STATE.md FIRST → trust `[x]` checkpoints and skip them → cheaply re-verify the last `[x]` still holds → continue from the first `[ ]`.
- **`resume-worker.sh <window> <task-dir> [--with-brief <orig-brief>]`** re-briefs a window (still-alive-but-stuck, or freshly re-spawned) with a RESUME preamble that points the worker at its STATE.md and orders it to continue from the Resume cursor. It delegates delivery to `brief-worker.sh` (so the worker re-absorbs the full role-override + contracts), and auto-falls back to the `--quick` path for L1-stub STATE.md.
- The contract is enforced in the **brief-worker.sh role-override preamble** (every full-path worker is told to checkpoint + verify-before-marking) and the **STATE.md template** (`~/claude/notes/templates/STATE.md` carries the Checkpoints + Resume protocol sections).

Verified safe because resume only skips checkpoints the worker itself verified + that are idempotent. (Verified failure that motivated this: 2026-06-11 a worker died at the session limit mid-task; recovery was manual + idempotent-by-luck.)

### Structured worker results (`result.json`)

On completion (or terminal block), a full-path worker writes a machine-readable **`result.json`** next to STATE.md **in addition to** `report.md`, so main can ingest the outcome without re-parsing prose. Schema: `{ task_slug, status (done|blocked|partial), summary, deliverables[], evidence[], blockers[], followups[], staged_for_human[] }`. Validate/read it with **`result-schema.sh <dir|file>`** (`--validate` exits 0/1; default pretty-prints; `--field <f>` for scripting; `--template` emits a skeleton). NOT required for L1 quick tasks.

### Concurrency governor (don't over-spawn the 4-vCPU box)

`spawn-worker.sh` now has a **semaphore gate** (after the triage gate, before the window is created): it refuses to spawn if at/over **`CHILLDAWG_MAX_WORKERS`** (default 4) live pipeline workers. The live count = a spawn registry ∩ live tmux windows (precise to pipeline-spawned workers, self-pruning as windows die). **Fail-open**: if the count can't be determined, the spawn is allowed (a counting bug never bricks the pipeline). Override per-spawn: `CHILLDAWG_MAX_WORKERS=6 spawn-worker.sh …`, or queue with `CHILLDAWG_SPAWN_WAIT=120 spawn-worker.sh …` (waits up to 120s for a slot). Refusal exits 5 with an actionable message. Logic lives in the sourceable `worker-semaphore.sh` (`worker-semaphore.sh status` to inspect).

### FleetView (live cockpit)

**`fleetview.sh`** — read-only one-screen dashboard of all active workers: each window's STATE.md status + mtime (STALLED flag if no update in >10min while still active), checkpoint progress (done/remaining), Resume cursor, context% (read from the pane statusline; this is REMAINING — low% = near-limit), capacity (N/max), and parent initiative. `--watch [secs]` refreshes. NEVER acts on a worker. Renders "no active workers" cleanly when idle.

### Workflow library (codified multi-worker patterns)

`~/.claude/scripts/workflows/` — playbooks for the multi-worker patterns main keeps hand-assembling, each with a brief-shape skeleton + sequencing + verification gates: **fan-out-review** (N parallel lens agents → synthesis, e.g. `/audit`), **recon→implement→verify** (the fitest pattern), **loop-until-green / loop-until-dry** (iterate to a condition with a budget). **`scaffold-workflow.sh <pattern> <run-slug>`** writes the 3-tier pre-spawn artifacts (per-worker task dir with triage.json + STATE.md + role-shaped brief.md) and prints the exact spawn/brief commands. See `workflows/README.md`.

## Autonomous Loop Operations — wake priority + idle backlog (Wave-6, 2026-06-11)

Additive operating model for the overnight self-pacing loop (main schedules its own next wake via `ScheduleWakeup`, sentinel `<<autonomous-loop-dynamic>>`; a finished sub-agent auto-re-invokes main). This gives that loop a **priority lens** + a **backlog to grind on when idle** — operationalizing `feedback_always_working` (idle ≠ sleep; advance real deliverables). Full doc: `docs/AUTONOMOUS-LOOP.md`.

### The wake-priority ladder (highest pending wins)

- **P0 — act immediately (wake ≤60s):** a real **deadman daemon-death alert** (`~/.claude/state/deadman/*.alerted` present = an armed daemon went alive→dead, not yet recovered); a **Toper WhatsApp/SUPERUSER** message (already first-class — delivered LIVE to main via `WHATSAPP=1`, so it's handled by the WhatsApp Channel Discipline rule, not by a poll); anything time-critical + irreversible.
- **P1 — handle next (~1–10 min):** a **fresh worker `result.json`** to ingest (`~/claude/notes/*/result.json` newer than the consumed marker); inside the **paid-work window** (Ryan/BMS ~08:00–11:00 WIB weekdays — stay responsive); a scheduled time-promise coming due.
- **P2 — idle tick (~20–30 min):** nothing higher → pull **ONE `loop-safe`** item from `~/claude/notes/idle-backlog.md` and advance it.

### `wake-priority.sh` (read-only reporter)

`claude/scripts/wake-priority.sh` reports the top pending reason + tier + a suggested cadence so the loop can consult it each wake. **Read-only** (the only thing it writes is its own `~/.claude/state/wake-priority.consumed` marker, and only under `--consume`); **exit code = tier** (`0=P2`, `1=P1`, `2=P0`); **fail-open** (any ambiguity → P2/idle, never falsely escalate); **never prints a secret**. Modes: default report · `--quiet` · `--json` · `--consume` (call after ingesting a `result.json`). Not wired to any timer/hook — it's a tool the loop *consults*, never a side-effect source.

### P2 selection protocol (the idle work queue)

When at P2: read `~/claude/notes/idle-backlog.md` → pick the highest-value **`loop-safe`** item that fits remaining context/time → execute under the **normal Task Complexity Triage + 3-tier + verify** discipline → log the outcome + check it off. The autonomous-execution policy still applies (self-gate destructive ops backup→verify→proceed; stage nuclear).

**HARD RULE:** every backlog entry is flagged **`loop-safe`** (loop MAY auto-execute) vs **`human-gated`** (loop must NEVER auto-fire). Nuclear / external / destructive / money / external-relationship work is **`human-gated`, no exceptions** (e.g. the W5 `.bashrc` age-cutover + off-machine key backup, the W0 dashboard key rotations, #27 VPS migration, history-scrub+force-push of the *other* public repos). Surface `human-gated` items to Toper (standup / loop-digest); never auto-execute them. Borderline → `human-gated`.

## Website Build Defaults — i18n + Multi-Theme (MANDATORY)

**OVERRIDE: Every website / web app / landing page / marketing site built for Aenoxa ecosystem MUST ship with i18n + multi-theme support out of the box. Non-negotiable. From commit 0. Not v2. Not MVP-first. Not "we'll add it later".**

### i18n (Internationalization)

1. **next-intl required** for Next.js projects. `[locale]` route segment + middleware. (Other frameworks: equivalent locale-aware routing.)
2. **Minimum locales**: `id` (Indonesian, DEFAULT — Pulse + aenoxa target market is Indonesia) + `en` (English, secondary).
3. **No hardcoded strings** in components. Every user-facing string lives in `messages/<locale>.json`, accessed via `useTranslations()` (or `getTranslations()` in server components).
4. **Auth flows + form errors + toast messages + 404/error pages**: all translated. NO English-only error strings.
5. **hreflang metadata** on every page for SEO.

### Multi-Theme

1. **next-themes required** for Next.js projects.
2. **Minimum themes**: `light` + `dark` + `system` (follow OS preference).
3. **Both themes designed polished** — not "light is main, dark is afterthought". Toper will check both.
4. **CSS variables for tokens** in `globals.css` (`--bg`, `--fg`, `--accent`, `--surface`, `--border`, etc) — NOT hardcoded color values in components.
5. **Theme switcher visible** in nav or settings. Not buried.
6. **Theme persists** via cookie. Matches SSR (no FOUC on load).

### Verification gate (before declaring website build done)

- [ ] `messages/id.json` + `messages/en.json` populated for every section + form/error string
- [ ] `[locale]` routing works (`/id/...` + `/en/...`)
- [ ] `useTranslations` used everywhere — NO hardcoded user-facing English strings
- [ ] Light + dark themes both render polished
- [ ] Theme switcher accessible from nav
- [ ] Theme persists across page refresh
- [ ] No FOUC on theme load

If any gate fails → build NOT done. Fix before reporting complete.

### Exception

Internal-only admin tools (used only by Toper / dev team, not customer-facing) MAY ship English-only single-theme by default. Still preferred to include i18n+themes if scope permits.

### Why this rule exists (verified failure)

2026-05-24: Pulse landing v2 redesign worker built English-only single-light-theme after 1h work. Toper rejected the entire output ("just kill the worker, we will not continue it"). Lost ID locale + lost dark mode compounded the rejection beyond just aesthetic — even with iteration, missing these baselines made the work unsalvageable as a starting point. Indonesian market + premium product = bilingual + dark mode out of the box. Always.

## One-Shot Pitch/Demo Webapps — Non-Negotiables (MANDATORY)

**OVERRIDE: When building or deploying a pitch/demo/recruiter webapp — or whenever `/oneshot-webapp` runs — these non-negotiables apply and deliberately OVERRIDE the i18n+multi-theme website default above (those are for the Aenoxa product ecosystem; one-shot pitch demos are different):**

1. **Pitch-grade design is priority #1** — never cut design polish to save time; cut SCOPE instead. Generic shadcn-default = failure.
2. **SAFE `/frontend-design` preset ONLY** — Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism. High-variance directions (Neo-Brutalist, art-deco, maximalist, VARIANCE ≥ 7) are BANNED unless Toper explicitly overrides in the brief.
3. **Light mode ONLY** — no dark mode, no `next-themes`, no theme switcher.
4. **Server-side secrets only + a mandatory deterministic LLM fallback** — key in container `.env` (chmod 600), never `NEXT_PUBLIC_`/never in the image; the live demo must survive an API failure.
5. **Deploy to `<slug>.topengdev.com`** — per-subdomain Cloudflare A record (no wildcard), HTTPS via certbot behind nginx. Don't disrupt other VPS services.
6. **Ship fast** — cap thinking, act in visible steps, iterate the running app.

Full procedure, gates, and gotchas: `~/.claude/skills/oneshot-webapp/SKILL.md` (a `UserPromptSubmit` hook auto-injects these rules whenever `/oneshot-webapp` is invoked). Verified failure: 2026-05-29 art-deco Selaras/Bithour demo rejected ("looked SO BAD").

---

# Agent Work Protocol

## Prototype & Smoke Test Before Planning

**OVERRIDE: Do NOT plan or implement with unvalidated assumptions.** Before committing to a plan for anything new (new feature, new library, new integration, new design):

1. **Prototype first** — build a small, throwaway proof-of-concept that tests the core hypothesis. Multiple iterations. Does the API actually return what you think? Does the UI look right with these colors? Does the library work with your stack version?
2. **Smoke test the tools** — before planning implementation around a tool/library/framework, run it. Install it, call its API, render its output, hit its edge cases. Note what works, what doesn't, what's undocumented.
3. **Note constraints and issues** — write down what you discovered. Broken features, version incompatibilities, rate limits, missing docs, unexpected behavior. These become planning inputs.
4. **Minimize assumptions** — every assumption in a plan is a risk. Replace assumptions with verified facts from prototypes. If you can't verify, flag it explicitly as an assumption.
5. **THEN plan** — only after prototyping + smoke testing, draft the real plan. The plan should reference what you validated and what constraints you discovered.

A plan built on assumptions wastes more time than the prototype would have taken. Christopher rejected the Gruvbox reskin after full implementation — a 10-minute color-swap prototype on one page would have caught that. Prototype iterations are cheap; full implementations based on wrong assumptions are expensive.

## Equip Before Delegating

**OVERRIDE: Do NOT delegate work to a spawned session without equipping it fully.** Before any implementation brief:

1. **Credentials** — does the agent need login credentials, API keys, SSH access? Include them or tell the agent where to find them (`~/.claude/secrets.env` pattern). Don't let the agent discover mid-task that it can't authenticate.
2. **Tools** — does the agent need qutebrowser, grpcurl, a running dev server, a specific MCP plugin? Verify availability BEFORE briefing. If a tool isn't installed or configured, set it up first.
3. **Access level** — is the agent authorized for read-only or read-write on prod? On git push? On container restarts? State this explicitly in the brief.
4. **Context** — does the agent need to read specific files, memory entries, prior investigation findings? Include paths or inline the critical context. Don't assume the agent will find what it needs.
5. **Test accounts** — if verification requires a logged-in session, provide test credentials upfront (from `$PULSE_TEST_*` or equivalent). Don't let the agent hit auth walls mid-verification.
6. **Attn shim** — is the attn local peer shim running? Can the agent report back? Verify the round-trip BEFORE briefing. **NO EXCEPTIONS — not even for "quick" or "1-line" tasks.** Every spawned session MUST have attn connected from minute zero. If attn shim is not set up, DO NOT send the brief. Set it up first.

**HARD RULE: Do NOT spawn a session without attn.** The sequence is ALWAYS: (1) create tmux window → (2) start attn shim + verify round-trip → (3) launch claude → (4) paste brief. Never skip step 2. Never "come back to it later." Never judge a task as "too small" to need attn. Christopher should NEVER have to ask "how's the progress" — the agent reports to main via attn automatically on every completion.

An agent that hits a dead end because it lacks credentials, tools, or access wastes its entire context window on workarounds instead of the actual task. An agent without attn is invisible — main has no idea when it finishes. Equip first, brief second.

## Close the Loop — Agents Must Self-Verify and Report Back

**OVERRIDE: An agent's job is NOT done until it has verified its own work end-to-end AND reported back to main.** Every spawned session or delegated task must:

1. **Verify the change works** — not just "it compiles" or "the edit looks right." Run the actual flow. Open the page. Call the API. Check the database. Capture evidence (screenshots, curl output, DB query results).
2. **Verify constraints are met** — if the brief said "light mode must stay pixel-perfect" or "don't break existing tests," explicitly check those constraints and report the check.
3. **Verify in the target environment** — dev verification is necessary but not sufficient. If the change ships to prod, verify on prod after deploy (smoke test, health check, curl).
4. **Report evidence, not claims** — "I verified it works" is a claim. "Screenshot at /tmp/X.png shows the field is disabled, curl returns 200, DB row has status=ACTIVE" is evidence. Always report evidence.
5. **Flag what you COULDN'T verify** — if a test case is untestable (e.g., no draft POs exist to test the button label), say so explicitly and explain what alternative verification you did.
6. **ALWAYS report back to main** — when the task is done (or blocked), the agent MUST send a completion report to the main session / command center via attn. No exceptions. Don't wait to be asked. Don't sit idle after finishing. The report must include: what was done, what was verified, what's pending, and any surprises. Main session needs this to continue the pipeline without Christopher having to relay status.

An unverified "done" is not done. An unreported "done" is invisible. The agent that ships the code must also close the verification loop AND report back.

## Compact After Major Milestones

**OVERRIDE: Proactively manage context window during long sessions.** When using the 1M context window:

1. **After every major milestone** (feature shipped, big investigation complete, multi-phase task done), assess context usage. If above 60%, consider compacting.
2. **Before compaction, save everything important to memory** — decisions made, findings discovered, current state of all open threads, pending tasks, credential/access notes, session states. Memory files survive compaction; context does not.
3. **Update existing memory files** rather than creating duplicates. Check MEMORY.md index for related entries before writing new files.
4. **Write a compaction-safe summary** — if the session will be continued from a compaction summary, make sure the summary includes: (a) what was done, (b) what's pending, (c) what state exists on disk/in git, (d) what decisions Christopher made, (e) any open threads with external parties (attn, WhatsApp).
5. **Don't let context hit 95%+ before acting** — by then it's too late to save everything cleanly. The sweet spot is 60-70%: save state, compact, continue fresh.

## Creative Tasks — ALWAYS Delegate

**OVERRIDE: NEVER execute creative tasks in the main session.** Any task in the creative/design domain MUST be delegated to a spawned session. The main session's role for creative work is DISCUSSION and BRAINSTORMING only.

**What counts as "creative tasks" (delegate ALL of these):**
- Graphic design (social media posts, banners, headers, thumbnails)
- Illustration creation (hero images, spot illustrations, conceptual art)
- Logo design / brand mark creation
- Image generation or editing via any AI model (Gemini, Recraft, OpenAI, FLUX)
- Content asset creation (OG images, email graphics, presentation slides)
- Icon design / icon set creation
- UI mockup generation (not code — visual mockups)
- Photo editing, retouching, compositing
- Any invocation of the `/creative` skill
- Any use of nanobanana MCP tools (gemini_generate_image, gemini_edit_image)
- Any curl/API call to image generation endpoints (Recraft, OpenAI images, FLUX)

**What stays in main session (OK to do here):**
- Discussing design direction, brainstorming concepts, reviewing outputs
- Choosing between design options (A vs B)
- Providing feedback on generated assets ("make it darker", "too busy")
- Brand kit configuration (editing JSON files)
- Design critique and art direction

**Bright-line test:** Does this task generate, edit, or manipulate a visual asset? YES → delegate. Is this a conversation ABOUT design without producing an artifact? → safe in main.

**How to delegate:** Spawn a tmux session, brief it with the creative task + brand context + reference assets, invoke `/creative` skill from there. Follow the standard spawned session protocol (attn shim, auto-report-back, close-the-loop verification).

**IMPORTANT — scope of this rule:** "Main session" means the command-center session in tmux window 1 (the one Christopher interacts with directly). Spawned worker sessions that RECEIVE a creative task brief should EXECUTE it directly — they are the delegation target, not another layer of delegation. Do NOT recursively delegate from a worker session.

**Why:** Creative tasks consume massive context (image data, prompt iterations, multi-variant generation, critique loops). Running them in main pollutes the coordination context and risks hitting context limits during unrelated work. Main session = command center. Creative execution = spawned worker.

---

## WhatsApp Channel Discipline

**OVERRIDE: WhatsApp is a first-class notification channel, not a logging sink.** When you receive WhatsApp `<channel>` events, follow these hard rules:

1. **If Toper chats you as [SUPERUSER] on WhatsApp** → ALWAYS send a WhatsApp reply, not just a main-session acknowledgement. He's on his phone; main-session text is invisible to him. Reply via `mcp__plugin_whatsapp_whatsapp__send_message` to `62817712289@s.whatsapp.net`.

2. **If a contact asks to speak to Toper directly** (trigger phrases: "panggilin chris", "panggilin dia", "claude panggilin chris", "is toper around", "mas lagi ada ga", "chris on ga", "minta chris dong", "mau ngobrol sama chris", or any explicit request for Christopher the human, not the AI) → the required sequence is:
   - (a) reply to the asker with a short ack ("siap ma dipanggilin")
   - (b) **immediately** send a WhatsApp DM to `62817712289@s.whatsapp.net` flagging: `bro, <NAME> lagi nyariin lu di WA — <BRIEF CONTEXT if known>`
   - (c) continue holding the thread — don't impersonate Chris on direct-speak requests
   - Main-session text alone is NOT sufficient notification. Chris may be AFK from the terminal.
   - Skip (b) only if Chris has just sent a message in the current main session (he's clearly watching). Don't spam on repeated pings — one notification is enough.

3. **Whitelist + JID verification** — whitelist (verified JIDs): Toper, Suryadi, Alkautsar, Tama, Stiven, Hezkiel, Kenny, Kenken. ALWAYS `list_chats` or `check_number` before `send_message`. NEVER fuzzy-match contact names.

4. **Voice**: natural Bahasa Indonesia for Indo contacts. Emoji allowlist: ONLY 🤣🙏😭🥲😁. Short messages. Real friend slang. No eager corporate phrasing.

5. **`WHATSAPP=1` env — main session ONLY.** NEVER set this on spawned worker sessions. The Claude WhatsApp plugin splits inbound messages across all sessions that load it — main misses messages, command-center reliability breaks. Workers communicate via status files, attn local-peer, or main-session relay. Verified failure mode 2026-04-27. See memory `feedback_whatsapp_single_session_rule.md`.

See memory for details: `feedback_whatsapp_superuser_always_reply.md`, `feedback_whatsapp_panggilin_notify.md`, `feedback_whatsapp_auto_reply_global.md`, `feedback_whatsapp_no_random_messaging.md`, `feedback_bahasa_natural.md`.
