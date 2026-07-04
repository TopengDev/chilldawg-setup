---
name: qa
description: >-
  Adversarial QA — hammers any codebase across 10 testing dimensions and produces a
  severity-graded ./QA.md report with P0-P4 findings and a SHIP / FIX BEFORE SHIP / DO NOT SHIP
  verdict. REPORT-ONLY: it finds and grades defects, it NEVER auto-fixes (that is /e2e). Quick
  mode (functional + edge + UX, ~20 min) or full mode (all 10 dimensions, ~150 min cap). Use
  when the user says /qa, asks to "break it", stress-test, hammer, or adversarially QA an app,
  a feature, or a repo before shipping.
metadata:
  filePattern: "**/QA.md,**/*.test.*,**/*.spec.*,**/*_test.*,**/test_*.py"
  bashPattern: "/qa|qa quick|qa full|adversarial QA"
---

# /qa — Adversarial QA (report-only, severity-graded)

Real QA is more than `cargo test`. It is adversarial: it asks **"how can I break this?"** not
**"does this pass?"** It hammers a target across 10 dimensions, grades every defect P0-P4 with a
CONFIRMED/probable/theoretical confidence tier and hard evidence, and returns a quantified
SHIP / FIX BEFORE SHIP / DO NOT SHIP verdict in `./QA.md`.

**/qa reports. /qa does NOT fix.** That boundary is load-bearing (see §1). Remediation is the
developer's or `/e2e`'s job.

## 0. FAILING NOW? / WHERE-DO-I-GO jump table

| Situation right now | Go to |
|---|---|
| Just invoked, need the flow | §3 modes → §4 Phase 1 → §5 harness → §6 dimensions → §9 verdict → §10 report → §12 cleanup |
| Any browser symptom (blank shot, wrong tab, timeout, cert, wedge) | **Do NOT debug here** → agent-browser §0 jump table / §10.0 wedge ladder |
| Target is a live web app | §7 live-app QA layer (cites agent-browser + atlas) |
| Shared test env / maker-checker / approval queue | §8 shared-env & linear-runner safety (HARD) |
| CI says a workflow FAILED | **PB-1** (verify prod ground truth BEFORE calling it a blocker) |
| Mobile/device bug you can't reproduce locally | **PB-2** (overlay-first, never hypothesis-first) |
| Found a secret while scanning | **PB-5** (path + pattern class ONLY, never the value) |
| Test suite hung, no output | **PB-4** (sentinel absent → `top` first, PARTIAL, never blind-kill) |
| Not sure if this is /qa or /e2e / /audit / /ui-test | §1 boundary table |
| Which package manager / build cmd? | §4 detect + `references/detection-matrix.md` |
| How do I write a finding? | §9 finding schema + `references/qa-md-recipes.md` |

## 1. Identity + boundary (who owns what)

**/qa is adversarial break-it QA that produces a graded report and stops.** It never edits target
code, never commits, never deploys. It hands remediation off.

| Skill | Owns | /qa relationship |
|---|---|---|
| **/qa** (this) | Adversarial defect-hunting across 10 dimensions → severity+confidence graded `./QA.md` → SHIP/FIX/DO-NOT-SHIP verdict. REPORT-ONLY. | — |
| **/e2e** | Verify a flow works locally AND **auto-fix the root cause + /commit** in a loop. | /qa hands its findings here when the user wants fixes. /qa NEVER absorbs the fix loop. |
| **/ui-test** | Element-exhaustive, per-role UI crawl of every interactive element with screenshots. | /qa delegates a full per-element UI sweep here; /qa samples UX/visual, it does not exhaustively crawl every element. |
| **/audit** | Multi-lens READ-ONLY static codebase audit (5+ parallel lens agents) + adversarial verification + type-adaptive GA-readiness rubric. | /audit is static + read-only + multi-lens; /qa is behavioral + adversarial + executes. Overlap in security/perf: /qa executes reproductions, /audit reasons over source. Don't re-run /audit's static sweep inside /qa. |
| **/verify** | Prove ONE specific change does what it claims, end-to-end. | Single-change scope; /qa is whole-target adversarial scope. |
| **/preflight** | Local CI-parity checks (lint/build/test as CI runs them) before a push. | /qa is broader + adversarial; /preflight is "will CI pass". |
| **/atlas** | Exhaustive product CAPTURE into a cached dossier (surfaces/states/screenshots). NEUTRAL facts, no verdict. | /qa CONSUMES an atlas dossier as QA input (§4.5) and never re-crawls what it already inventoried. |

**Routing rule (SCOPE GUARD):** /qa hands off, never absorbs. User asked for fixes → write the
report, then say "route to /e2e for remediation." Element-exhaustive UI crawl → /ui-test.
Static multi-lens GA verdict → /audit. Single-change proof → /verify. CI parity → /preflight.

## 2. HARD RULES (NEVER / ALWAYS — memorize before Phase 2)

- **HR-1 — REPORT-ONLY. NEVER auto-fix, edit target code, commit, or deploy.** /qa finds and grades
  defects. It hands remediation to the developer or `/e2e`. Writing a fix to target source is a hard
  violation of this skill's identity. (The ONLY files /qa writes are `./QA.md` + evidence artifacts in
  the task dir — §5.3, §10.)
- **HR-2 — NEVER drive a browser outside `/agent-browser`.** Playwright MCP is hook-denied globally
  (agent-browser HR-1); if a Playwright call is denied the hook fired correctly — pivot, don't work
  around it. NEVER restart/kill the live qutebrowser (agent-browser HR-2). NEVER `agent-browser tab new`
  as the primary path (exit-144, agent-browser HR-9) — new surfaces via `/claim?from=9223&url=`
  (agent-browser §6.3). All browser mechanics are agent-browser's; cite by section, never duplicate.
- **HR-3 — NEVER print or persist a secret VALUE.** When scanning finds credential material, report
  `path:line + pattern class` ONLY — in the terminal, the run log, AND `./QA.md` alike. Secret-scan
  commands must be structurally incapable of emitting the value (cut to `path:line`, or redact with
  `sed 's/=.*/=<REDACTED>/'`). See §6 Dimension 8 + PB-5. (Mirrors agent-browser HR-15.)
- **HR-4 — ALWAYS classify the target environment BEFORE Phase 2 (blocking).** Into LOCAL /
  TEST-ENV-WITH-TEST-CREDS / SHARED-STAGING / REAL-DATA, and follow the mutation policy matrix (§4.4).
  The gate for ANY write is **"does it touch REAL data?"**, NEVER "is it the prod URL" (Toper 2026-06-22).
  Mutations with test creds on an owned test tenant are ALLOWED and encouraged for coverage; wholesale
  seed deletion is NOT; mutating OTHER tenants is NEVER. Phase 2 may not start until the class + policy
  line is written into the run log and the QA.md header.
- **HR-5 — NEVER automate an approve/reject/delete against a shared approval queue by POSITION**
  ("top pending row" / newest). Positive-match ONLY the token/key THIS run submitted; guarantee the
  submit landed a FRESH request (a no-op submit = the trap); use a disposable fixture you own; keep
  halt-on-failure ON where the runner honors it. (§8, PB-6. Verified incident 2026-06-05.)
- **HR-6 — NEVER trust a verify/assert pre-step to gate a destructive step in a linear runner.**
  Failed verifies may NOT halt (fitest `verify_element`, verified runs 3207-3210 with
  `cancel_on_first_fail` ON). The destructive step's OWN locator must no-op when the target is absent
  (synthetic-anchored, never positional). (§8.)
- **HR-7 — NEVER accept a UI success signal (toast, dialog close, rendered 200) as persistence proof.**
  After every exercised write, re-fetch the data state and assert the post-op state. For browser flows
  ALSO scan the network layer (`agent-browser network requests`) for any `>=400` behind a "passing"
  step (masked backend-failure class). (§8, verified: a "Request created" toast that was a false
  success dropped the request.)
- **HR-8 — NEVER kill or reuse another run's execution window.** The window name is `qa-<slug>-$$`
  (unique per run). Cleanup kills ONLY that exact window (`=`-anchored target, §5, §12). Logs/artifacts
  go to the task dir or session scratchpad with run-unique names — NEVER a fixed `/tmp` path.
- **HR-9 — NEVER parse test output without the completion sentinel.** Every command sent to the
  execution window appends `; echo __QA_<runid>_EXIT_$?__`. Poll bounded by the dimension budget; a
  missing sentinel = PARTIAL, never a verdict input (§5.2, PB-4).
- **HR-10 — NEVER report "deploy/CI broken" without the ground-truth check FIRST:** curl -I the prod
  URL; `gh run list` for a LATER green run on the same SHA; (if SSH) `docker ps` container age.
  Historical CI noise is not a blocker (PB-1, verified 2026-05-17: 90 min lost to a non-problem).
- **HR-11 — NEVER emit a P0/P1 finding without CONFIRMED confidence** (executed reproduction with
  captured evidence). Unreproduced suspicions cap at `probable` and CANNOT alone flip the verdict to
  DO NOT SHIP (§9).
- **HR-12 — NEVER write generic findings.** "add more tests", "improve error handling", "consider
  refactoring", "follow best practices", "could be improved" WITHOUT `file:line` + a concrete failure
  scenario are BANNED phrasings. A finding missing any of the 5 schema fields is rejected, not shipped
  (§9).
- **HR-13 — ALWAYS check for an /atlas dossier** (`~/.claude/skills/atlas/dossiers/<slug>/`) in Phase 1.
  If present, run QUERY-GUIDE R0 (freshness) then seed the plan from R1 (mutator matrix), R2 (error/empty
  states), R4 (unobserved-states gap seed), R8 (i18n gaps). Cite the QUERY-GUIDE recipes; never duplicate
  its jq (§4.5).
- **HR-14 — ALWAYS keep infra-level failure injection SIMULATED / planned-only.** `kill -9`, disk-full,
  OOM, connection-drop are MAPPED and PLANNED, never actually fired — anywhere, including LOCAL. The
  HR-4 mutation relaxation covers DATA operations on test envs, NOT infrastructure sabotage (§6
  Dimension 5).
- **HR-15 — ALWAYS apply the house gates when the target is an Aenoxa-ecosystem web build:** i18n
  (id/en) + light/dark theme checklist, typography floors (no weight <500, no size <12px, no monospace
  unless the archetype is mono), CSS/token changes verified via a REAL build (tsc misses them).
  EXCEPTION: one-shot pitch demos are light-only by design — do NOT flag missing dark mode there (§6
  Dimensions 6/10).
- **HR-16 — External-facing outputs (ISI/BMS tickets, client reports): FE-observable framing ONLY,**
  NEVER cite reading backend source; report findings + blockers, NEVER prescribe dev-side fixes. The
  internal `./QA.md` may cite source freely (§8, `references/env-safety.md`).
- **HR-17 — When /qa AUTHORS test artifacts a human team will own:** get/confirm their agreed standard
  FIRST, validate the convention on 1-2 examples with the owner before scaling. In evidence-capable
  runners, screenshot-per-step + Expected-Results-defined are HARD done-gates (§8, verified failure
  2026-06-05).

## 3. Modes + time budget

```
/qa quick   — smoke: functional + edge cases + UX spot-check. 20 min TOTAL hard cap.
/qa full    — deep adversarial: all 10 dimensions. 12 min/dim soft, 20 min/dim hard, 150 min TOTAL hard cap.
/qa <path>  — same, scoped to a subtree/feature.
```

### 3.1 Time budget table (enforced, replaces the old "60-min-per-dimension" claim)

| Mode | Per-dimension soft | Per-dimension hard | TOTAL hard cap |
|---|---|---|---|
| quick (3 dims) | 5 min | 8 min | **20 min** |
| full (10 dims) | 12 min | 20 min | **150 min** |

**Enforcement (not prose):**
- Record `START_EPOCH=$(date +%s)` at Phase 1. Check elapsed at EVERY dimension boundary:
  `ELAPSED=$(( ($(date +%s) - START_EPOCH) / 60 ))`.
- Dimension exceeds its HARD budget → stop it, mark it **PARTIAL**, write an explicit skipped-items
  list into the report.
- TOTAL hard cap hit → stop, mark all remaining dimensions PARTIAL/SKIPPED, go straight to §9/§10.
- A verdict from a run with **>3 PARTIAL dimensions** MUST be labeled **PROVISIONAL** in the header.

## 4. Phase 1 — Detect, discover, classify (blocking gates)

### 4.1 Detect project type + runner (lockfile-resolved)

Resolve the package manager by LOCKFILE, not by `package.json` presence. First-match-wins on the
config file, but the runner comes from the lockfile:

| Config file | Type | Runner resolution | Build |
|---|---|---|---|
| `Cargo.toml` | Rust | `cargo test` / `cargo nextest run` | `cargo build` |
| `package.json` + `pnpm-lock.yaml` | TS/JS (pnpm) | `pnpm test` / `pnpm exec vitest` | `pnpm build` |
| `package.json` + `bun.lockb`/`bun.lock` | TS/JS (bun) | `bun test` / `bun run test` | `bun run build` |
| `package.json` + `yarn.lock` | TS/JS (yarn) | `yarn test` | `yarn build` |
| `package.json` + `package-lock.json` | TS/JS (npm) | `npm test` | `npm run build` |
| `package.json` (no lockfile) | TS/JS | read `scripts.test`; ASK which PM if ambiguous | `scripts.build` |
| `pyproject.toml` | Python | `pytest` (or `uv run pytest` / `poetry run pytest` per lock) | `python -m build` |
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `Makefile` | Universal | `make test` / `make check` | `make` / `make build` |
| `CMakeLists.txt` | C/C++ | `ctest` / `make test` | `cmake --build .` |
| `pom.xml` | Java/Maven | `mvn test` | `mvn compile` |
| `build.gradle` | Java/Gradle | `gradle test` | `gradle build` |
| `composer.json` | PHP | `composer test` / `vendor/bin/phpunit` | `composer install` |
| `*.csproj` | C# | `dotnet test` | `dotnet build` |
| `Gemfile` | Ruby | `bundle exec rspec` | `bundle install` |

**Monorepo / workspace:** `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, or a
`workspaces` field → this is a monorepo; scope to the changed/target package, don't run the whole
graph unless asked. **Hybrid tie-break:** two runnable ecosystems in one repo (e.g. `Cargo.toml` +
`package.json`) → ASK which to target, or run BOTH and report per-runner. Never let "first match
wins" silently pick one. Full recipes + fallback interview: `references/detection-matrix.md`.

**Fallback:** no config detected → ASK "Could not auto-detect project type. What
language/framework/runner is this?" Do not guess.

### 4.2 Extract commands

From the detected config, extract the primary **test**, **build**, and **lint** commands + test-file
locations. Examples: `package.json` → `scripts.{test,build,lint}`; `Cargo.toml` → `cargo
{test,build,clippy}`; `pyproject.toml` → `[tool.pytest.ini_options]` + `[tool.ruff]`; `Makefile` →
`test:`/`check:`/`lint:` targets.

### 4.3 Discover test infrastructure

```bash
# Test files (from project root; NON-mutating read)
find . -name '*_test.go' -o -name '*_test.rs' -o -name '*.test.ts' -o -name '*.test.js' \
       -o -name '*.spec.ts' -o -name '*.spec.js' -o -name 'test_*.py' -o -name '*_test.py' \
       -o -name '*_test.ts' 2>/dev/null | grep -v node_modules | head -50
# CI configs (read-only)
ls .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null
```

### 4.4 ENV-CLASSIFICATION GATE (mandatory, blocking — HR-4)

**Phase 2 may NOT start until you have classified the target and written the class + policy line into
the run log AND the QA.md header.** The gate for any write is "does it touch REAL data?", never "is it
the prod URL."

| Class | What it is | Mutation policy |
|---|---|---|
| **LOCAL** | localhost / a build you spun up / a scratch DB you own | ALL actions allowed, incl. planning infra-failure SIMULATIONS (never firing them, HR-14). Real edge-case inputs OK. |
| **TEST-ENV / TEST-CREDS** | a "prod" URL but scoped to a designated test tenant with test creds (e.g. Pulse → Alamanda Coffee) | Data mutations ALLOWED + encouraged, scoped to the OWNED tenant/fixtures (create/edit/delete to reach states). NO wholesale seed deletion. NEVER touch other tenants. |
| **SHARED-STAGING** | a staging env other people/sessions also use (e.g. fitest on BMS WebAdmin) | Mutations ONLY on run-owned disposable fixtures. Approve-protocol MANDATORY (§8, HR-5). Exactly-1-own-pending rail: HALT if the requester-filtered queue shows >1. |
| **REAL-DATA** | real customers' data / unknown env / prod with real tenants | READ-ONLY, period. No writes. |

When unsure which class → treat as the STRICTER one (REAL-DATA). Write, e.g.:
`ENV CLASS: TEST-ENV/TEST-CREDS — Alamanda test tenant; data mutations allowed on owned fixtures, no
seed deletion, no other tenants.`

### 4.5 Atlas dossier check (HR-13)

```bash
ls ~/.claude/skills/atlas/dossiers/<slug>/ 2>/dev/null   # dossier present?
```

If present, this is a QA head-start — the dossier already inventoried surfaces/states. Run
**QUERY-GUIDE R0 (freshness)** first (if stale, note it and fall back to live discovery), then seed the
test plan from:
- **R1** — mutator matrix (every mutating element + skip/exercise status) → your write-path targets.
- **R2** — error + empty states with screenshots → states to reproduce + assert.
- **R4** — unobserved-states gap seed (the exact states never captured) → adversarial coverage targets.
- **R8** — i18n gaps → house-gate input for Dimension 6/10.

Cite the QUERY-GUIDE recipe IDs; do NOT copy its jq. DON'T re-crawl what the dossier already inventoried.

## 5. Execution harness (unique window, sentinel protocol, artifact locations)

### 5.1 Isolated, collision-free execution window (HR-8)

All test EXECUTION happens outside the invoking session. Prefer a uniquely-named tmux window; if not
inside tmux, fall back to in-session bash with the SAME sentinel protocol.

```bash
# Derive a run id + slug + log dir FIRST (no fixed /tmp path — HR-8)
RUNID="$(date +%s)-$$"
SLUG="$(basename "$(pwd)" | tr -c 'a-zA-Z0-9' '-' | sed 's/-*$//')"
WIN="qa-${SLUG}-$$"                              # unique per run
LOGDIR="${TASK_DIR:-$(mktemp -d -t qa-${RUNID}-XXXX)}"   # task dir, else a run-unique scratch dir
START_EPOCH=$(date +%s)

if [ -n "$TMUX" ] || tmux info >/dev/null 2>&1; then
  tmux new-window -d -n "$WIN" -c "$(pwd)"       # -d: don't steal focus. NO pre-kill of ':qa'.
  HARNESS=tmux
else
  HARNESS=inline                                  # no tmux server → run in-session, same sentinel
fi
```

Never `tmux kill-window -t :qa` — that would kill ANY window named `qa`, including a concurrent
/qa run's window (the house fleet routinely shares one tmux server). Cleanup targets `=$WIN` only (§12).

### 5.2 SENTINEL EXECUTION PROTOCOL (HR-9)

Every command sent to the window is suffixed so completion + exit code are unambiguous:

```bash
# Send a test command (tmux path). NOTE the sentinel suffix + tee to the per-run log.
RUNLOG="$LOGDIR/run-d1.log"
tmux send-keys -t "=$WIN" \
  "{TEST_COMMAND} 2>&1 | tee '$RUNLOG'; echo __QA_${RUNID}_EXIT_\${PIPESTATUS[0]}__ | tee -a '$RUNLOG'" Enter
# (inline harness: run the same string with bash -c, redirecting to "$RUNLOG")
```

Poll for the sentinel, bounded by the dimension's HARD budget (§3.1), every 5-10s:

```bash
DEADLINE=$(( $(date +%s) + 20*60 ))             # dimension hard budget in seconds
until grep -q "__QA_${RUNID}_EXIT_" "$RUNLOG" 2>/dev/null || [ "$(date +%s)" -ge "$DEADLINE" ]; do
  sleep 8
done
if grep -q "__QA_${RUNID}_EXIT_" "$RUNLOG"; then
  EXITCODE=$(grep -o "__QA_${RUNID}_EXIT_[0-9]*__" "$RUNLOG" | tail -1 | grep -o '[0-9]*')
  # parse PASS/FAIL counts from "$RUNLOG" only NOW (sentinel present)
else
  : # sentinel ABSENT at budget → dimension PARTIAL (never a verdict input) → PB-4
fi
```

**HARD:** never read PASS/FAIL counts off a `capture-pane` snapshot of a still-running suite — a long
suite's output is truncated/incomplete and produces a wrong verdict. Only parse after the sentinel
appears. Sentinel absent at the hard budget = PARTIAL + document the process; do NOT blind-kill a
process you did not start (PB-4).

Use `run_in_background` for long suites when you want the poll to re-invoke you on exit, but the
sentinel remains the source of truth.

### 5.3 Artifact locations (HR-8)

- Run logs: `$LOGDIR/run-<dim>.log` (run-unique; NEVER `/tmp/qa-test-output.log`).
- Screenshots/evidence: `$LOGDIR/evidence/` (each must pass the agent-browser §9.1 QA gate before
  it counts).
- The deliverable: `./QA.md` at target root (canonical, §10) + a timestamped archive copy
  `$LOGDIR/QA-$(date +%Y%m%d-%H%M).md`.

## 6. The 10 dimensions (each = probes + do/don't; no prose padding)

Quick mode runs **1, 2, 6**. Full mode runs all 10 in order. Respect the §3.1 budgets.

### Dimension 1 — Functional
Probes: run the existing suite via the sentinel harness (§5.2), parse PASS/FAIL/SKIP; map every entry
point (routes, API handlers, CLI commands, public exports); trace input→output per flow; for each flow
ask "what is the worst input?"; hit error paths (`try/catch`, `Result`, `Option`, `unwrap`, `panic`,
`throw`) — handled or propagated?; integration points (DB-down, file-permission-denied, network
timeout/DNS/SSL) — reasoned, not fired (HR-14).
DO re-run edge inputs for real on LOCAL/TEST-ENV · assert post-op DATA STATE on every write (HR-7).
DON'T fire infra failure injection (HR-14) · trust a green toast as persistence (HR-7).

### Dimension 2 — Edge cases
Probes: empty (`""`, `null`, `undefined`, `None`, `[]`, `{}`); max-length + beyond documented limits;
unicode/emoji (`🔥`, `日本語`, `العربية`, zero-width `​`, RTL-in-LTR, BOM, surrogate pairs);
injection-shaped strings as INPUT DATA (`' OR 1=1 --`, `; rm -rf /`, `$(whoami)`,
`<script>alert(1)</script>`); boundary numerics (`0`, `-1`, `MAX_INT`, `MAX_FLOAT`, NaN, Infinity,
`0.1+0.2`, div-by-zero, overflow); missing required fields; concurrent writes / races / lock contention;
time edges (leap year/second, DST, tz mismatch, Y2038).
DO feed these as real inputs on LOCAL/TEST-ENV and record which break · DON'T actually run
`rm -rf` etc. — these are INPUT STRINGS to test sanitization, never commands you execute.

### Dimension 3 — Cross-platform
Probes: ANSI/terminal-rendering portability + 80-col minimum; hardcoded `/` vs `\`, OS-specific
commands (`rm`/`del`/`kill`/`taskkill`), env vars (`$HOME` vs `%USERPROFILE%`); tmux/version
assumptions; fixed-width layouts + terminal-height assumptions.
DO grep for path/OS assumptions statically · DON'T claim a platform bug you can't reproduce — mark
it `probable` (HR-11).

### Dimension 4 — Regression
Probes: `git log --oneline -15` + `git diff HEAD~10 --stat`; which files/shared-utils/core modules
changed; any tests removed/disabled; renamed fns/changed signatures/removed error-handling/changed
defaults; run targeted tests on changed modules; adjacency (module X changed → what depends on X?).
**If a CI/workflow reports FAILED here → PB-1 BEFORE calling it a blocker (HR-10).**
DO ground CI-failure claims in prod truth (PB-1) · DON'T treat historical CI noise as a ship blocker.

### Dimension 5 — Destructive (SIMULATED / PLANNED ONLY — HR-14)
**Map and plan, never fire.** Probes: critical failure points (DB drops mid-query, disk fills mid-write,
connection drops mid-request, OOM kill, `kill -9` mid-op); per point document left-behind state
(corrupt/partial/clean), recovery logic (retry/rollback/checkpoint), user-visible outcome (clean error
vs crash), data-loss risk; write a SAFE test procedure per point (with backup/restore steps) for a
HUMAN to run later; rate each likelihood×impact → P-level.
DO produce a "Destructive Test Plans" section a human can execute · DON'T actually inject any infra
failure anywhere, incl. LOCAL (HR-14) — the HR-4 relaxation is DATA-only.

### Dimension 6 — UX audit  (quick-mode: UX spot-check)
Probes: every error message — actionable vs cryptic (`Error 500`, raw stack traces, "something went
wrong"); technical details leaking to end users; feedback gaps (>2s ops without progress, SILENT
failures where the op fails but UI shows success — HR-7); dead ends / no-way-back; destructive actions
unconfirmed / no undo; consistency (mixed naming, date/number formats, terminology); a11y (keyboard
nav, screen reader, contrast).
**HOUSE GATE (HR-15) — if target is an Aenoxa-ecosystem web build:** run the i18n + theme checklist
below. If it is a one-shot pitch demo, apply the light-only EXCEPTION (don't flag missing dark mode).

```
[ ] messages/id.json + messages/en.json populated for every section + form/error/toast string
[ ] [locale] routing works (/id/... AND /en/...); no hardcoded user-facing English strings
[ ] Light + dark BOTH render polished; theme switcher reachable from nav; persists across refresh; no FOUC
[ ] Auth flows + form errors + 404/error pages translated (no English-only error strings)
```
DO run the house gate on Aenoxa web builds · DON'T flag missing dark mode on a one-shot pitch demo
(light-only by design).

### Dimension 7 — Performance
Probes: N+1 (query-in-loop, `.map`/`.forEach` with async DB calls, missing JOIN/INCLUDE); unbounded
ops (no iteration cap, no pagination, unbounded file read, cache with no eviction); leak indicators
(unclosed handles/connections/clients, growing caches, listeners never removed, circular refs); large
dataset behavior (1k / 10k+ records — pagination/virtualization/streaming?); time the slowest ops if
cheap; sync ops that should be async / main-thread blockers.
DO time real ops on LOCAL where cheap · DON'T assert a leak you didn't observe — `probable` (HR-11).

### Dimension 8 — Security
Probes: SQLi (string-concat in queries, raw SQL with user input, parameterization present?); XSS
(`innerHTML`, `dangerouslySetInnerHTML`, `|safe`, unescaped user content); command injection
(`exec`/`spawn`/`system`/`os.system`/`subprocess` with interpolated input); auth bypass / IDOR /
unprotected admin endpoints / inconsistent token validation; data leaks (secrets in logs, stack traces
in error responses, over-exposed API fields); hardcoded secrets scan (REDACTED — HR-3).

**Secret scan (emits `path:line` + pattern class ONLY — never the value, HR-3, PB-5):**
```bash
for pat in password secret api_key apikey token private_key; do
  grep -rniE "${pat}[\"']?[[:space:]]*[:=]" \
    --include='*.rs' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' \
    --include='*.json' --include='*.yaml' --include='*.yml' --include='*.env' . 2>/dev/null \
    | grep -v 'node_modules\|target\|\.git\|/test\|spec\|example\|sample' \
    | grep -vE 'process\.env|std::env|os\.environ|os\.Getenv|import\.meta\.env' \
    | cut -d: -f1,2 | sed "s/^/[${pat}] /"
done
```
`cut -d: -f1,2` keeps only `file:line` (the matched value is dropped before it can print). If you need
context, redact: pipe through `sed -E 's/(=|:)[[:space:]]*.*/\1 <REDACTED>/'`. NEVER `grep -n`
(prints the whole line = the value). Per-language redacted variants: `references/qa-md-recipes.md`.
DO report `credential material at <path>:<line>, pattern class <api-key|password|private-key|token>`
· DON'T reproduce the value in the terminal, the run log, or QA.md (HR-3).

### Dimension 9 — State
Probes: fresh install (no config — auto-created? init cmd? crash vs guide?); missing required files
(detected? clear error? auto-created?); corrupt config (malformed JSON/YAML/TOML — validated? falls
back vs crashes?); migration (versioned data — migrates from older? reversible? mid-migration failure?);
crash recovery (restart recovers? checkpoint/restore? corruption risk?).
DO reproduce fresh-install/corrupt-config on LOCAL for real · DON'T simulate a crash by killing a
process on a shared env (HR-14).

### Dimension 10 — Visual
Probes: layout consistency (spacing/padding/margins), visual hierarchy, alignment, typography;
responsive breakpoints (320/768/1024/1440px — overflow? touch targets?); terminal output at 80 cols
(tables break on long content? colors readable light+dark?); if a display is available, capture
screenshots via the §7 live-app layer and review; if not, note "Visual: code-analysis only (no display)".
**HOUSE GATE (HR-15):** typography floors — flag any `font-weight < 500`, any text `< 12px` (`text-[10px]`,
`text-[11px]`), any monospace where the archetype is NOT mono. CSS/token diffs: verified via a REAL
build, NOT `tsc` (tsc does not parse CSS — a `*/`-in-comment bug 500'd every route while tsc passed):
```bash
node -e "const p=require('postcss'),f=require('fs');p.parse(f.readFileSync('src/app/globals.css','utf8'))"
```
DO capture screenshots through agent-browser + run the agent-browser §9.1 brightness gate · DON'T
bless a CSS/token change off tsc alone (HR-15).

## 7. Live-app QA layer (browser mechanics defer to /agent-browser)

When the target is a running web app, ALL browser interaction goes through **/agent-browser**. /qa
never re-implements browser mechanics — it CITES them. (Playwright MCP is hook-denied; qutebrowser is
Christopher's live browser — HR-2.)

**Before any browser work:** run agent-browser's §3 pre-flight gate (3 curls, ~2s). Any gate fails →
agent-browser's playbook, not here.

| Need | agent-browser recipe to follow |
|---|---|
| Open a NEW surface for QA (parallel/isolated) | `/claim?from=9223&url=<url>` → connect ≤30s → work (§6.3 / R-1). NEVER `tab new` (HR-9). |
| Read page state | `agent-browser snapshot -i -c --json` (§5.1); refs are volatile (HR-10) — re-snapshot after any DOM mutation. |
| Exercise a flow | `fill`/`click`/`find role|text|label` (§5.1); `fill`=clear-then-type, `type`=append (§13). |
| Wait after SPA nav | `agent-browser wait --load networkidle` (HR-11) before snapshot/screenshot. |
| **Network evidence (HR-7)** | `agent-browser network requests --filter api --type xhr,fetch` — scan for `>=400` behind any "passing" step (qa §8.1). |
| Console/errors bundle | `agent-browser console && agent-browser errors` (R-5). |
| Screenshot (evidence) | `agent-browser screenshot <path>`; run the §9.1 brightness gate; `--full` DPR trim per §9.2/PB-5; blank → qb-shoot (§9.3/PB-4). |
| Any browser symptom | agent-browser §0 jump table / §10.0 wedge ladder — do NOT debug in /qa. |
| Teardown | agent-browser §12 checklist: `close` daemon, `/release` claimed ports, verify `/sessions`. Cite in §12. |

**Screenshots as evidence must pass the agent-browser §9.1 gate** (brightness `fx:mean` ≥ ~0.6 on a
light page, not blank, DPR-corrected) before they count toward a CONFIRMED finding.

## 8. Shared-env & linear-runner safety (LOAD-BEARING — read before any write on a shared env)

This section is the hard core; the narrative + evidence live in `references/env-safety.md`. The rules
and the worked recipe stay inline.

### 8.1 The five hard rules (restated from §2 for the write path)
1. **Data-state, not toast (HR-7):** after every exercised write, re-fetch and assert the post-op DATA
   STATE. Add: search the datakey → row APPEARS (create) / shows CHANGED value (edit) / is GONE (delete).
   A "berhasil"/"Request created" toast can fire on a silently-dropped write (false-pass; caught 2 of 3
   SC-138/139 defects). For browser flows ALSO scan `network requests` for `>=400` behind the green step
   (masked backend bug, ticket #33 pattern).
2. **No positional approve (HR-5):** never approve/reject/delete the "top pending"/newest row. Positive-
   match ONLY the token/CIF/datakey THIS run submitted.
3. **No verify-gate safety (HR-6):** a failed `verify_element` may NOT halt (`cancel_on_first_fail`
   ignored for it — runs 3207-3210). The destructive locator itself must no-op on an absent target:
   synthetic-anchored + affordance-anchored + `[1]`, NEVER by-position. Example holding pattern:
   `(//table//tbody/tr[.//td[contains(normalize-space(),'<synthetic-string>')]][.//*[local-name()='svg' and contains(@class,'lucide-check')]])[1]//button[...]`.
   Seed absent → matches nothing → click no-ops → queue untouched.
4. **Fresh-request guarantee (HR-5):** the submit must land a NEW pending request (edit = a real field
   change/increment; delete = the entity must exist; create = a fresh unique key). A NO-OP submit = no
   fresh request = the trap that caused the 2026-06-05 blind-approve.
5. **Exactly-1-own rail (SHARED-STAGING):** at each checker step, confirm the requester-filtered queue
   returns EXACTLY 1 pending (your own). HALT if >1 (a concurrent session breaks "newest=own").

### 8.2 Worked recipe — safe approve on a shared queue (from the 2026-06-05 incident)
1. Submit with a run-unique token/datakey on a disposable fixture you OWN.
2. VERIFY the fresh request landed — search the queue for YOUR token (this is a fast-RED signal, NOT
   the safety net; HR-6 says the halt can't be trusted).
3. The approve click's locator embeds the token predicate + the action affordance + `[1]` — absent
   target ⇒ no match ⇒ no-op (leg-2 is the real guarantee).
4. After approve, re-fetch state and assert (HR-7).
5. If the requester-filter shows >1 own-pending, HALT (§8.1 rule 5).

### 8.3 Environment relaxation vs sabotage (don't over-relax)
The HR-4 mutation relaxation is DATA-only on TEST-ENV/SHARED-STAGING fixtures you own. It NEVER
authorizes: infra failure injection (HR-14), wholesale seed deletion, or mutating other tenants.

### 8.4 External-facing outputs (HR-16)
Internal `./QA.md` may cite source freely. Anything LEAVING the house (ISI/BMS tickets, client reports):
FE-observable framing ONLY, never cite reading backend source; report the finding + blocker, NEVER
prescribe a dev-side fix ("deploy the table", "change X", "add a CF rule" are OUT of QA scope).
Human-owned test artifacts: confirm THEIR agreed standard first, validate on 1-2 examples, and in
evidence-capable runners screenshot-per-step + Expected-Results-defined are HARD done-gates (HR-17).
Full ISI/fitest point-in-time facts (verified 2026-06): `references/env-safety.md`.

## 9. Finding quality gate + verdict rubric (enforcement)

### 9.1 Finding schema (5 fields, ALL required — HR-12)
A finding that is missing ANY field is REJECTED, not shipped.

| Field | Requirement |
|---|---|
| **severity** | P0-P4 per §9.3. |
| **confidence** | `confirmed` (executed reproduction with captured evidence) / `probable` (strong static indication) / `theoretical` (pattern-level only). |
| **evidence artifact** | the exact command + output snippet, OR a screenshot path that passed the agent-browser §9.1 gate, OR a `file:line` excerpt. No evidence = not confirmed. |
| **reproduction** | concrete steps to reproduce (inputs/state → observed wrong behavior). |
| **location** | `file:line` OR `URL + state`. |

**Confidence rules (HR-11):** a P0 or P1 MUST be `confirmed`. If it is only `probable`/`theoretical`,
auto-downgrade it ONE severity and tag it `needs verification` — it cannot alone flip the verdict to
DO NOT SHIP.

### 9.2 Anti-generic bans (HR-12)
BANNED as standalone findings (unless accompanied by `file:line` + a concrete failure scenario +
evidence): "add more tests", "improve error handling", "consider refactoring", "follow best practices",
"could be improved". **Report-reviewer step (blocking):** before writing the verdict, scan the draft
QA.md for these phrasings and either upgrade them to a full 5-field finding or delete them.

### 9.3 Severity ladder (preserved verbatim)

| Severity | Label | Criteria |
|---|---|---|
| **P0** | Critical | System crash, data loss, security vulnerability, core feature broken |
| **P1** | High | Feature broken for specific inputs, significant UX failure, perf issue that blocks usage |
| **P2** | Medium | Edge-case failure, confusing UX, minor security concern, perf degradation |
| **P3** | Low | Cosmetic issue, minor inconsistency, nice-to-have |
| **P4** | Cosmetic | Spelling, formatting, color, alignment — no functional impact |

### 9.4 QUANTIFIED VERDICT RUBRIC (replaces the old ambiguous "fixable" logic)

| Verdict | Condition |
|---|---|
| **DO NOT SHIP** | ≥1 **confirmed P0** |
| **FIX BEFORE SHIP** | ≥1 confirmed P1, OR ≥1 probable P0 (no confirmed P0) |
| **SHIP** | zero confirmed/probable P0-P1 (P2+ acceptable, listed) |

A run with **>3 PARTIAL dimensions** → prefix the verdict **PROVISIONAL** (§3.1). The verdict consumes
POST-downgrade confidences (a probable-only P0 does not trip DO NOT SHIP; it lands FIX BEFORE SHIP).

## 10. Report — `./QA.md` (canonical deliverable) + archive

Write `./QA.md` at target root (canonical — preserved). ALSO archive
`$LOGDIR/QA-$(date +%Y%m%d-%H%M).md` + evidence (history survives; QA.md is overwritten each run).
Before any /commit of the target, check `./QA.md` is gitignored or flag it (it can contain internal
detail; HR-3 keeps VALUES out regardless). Full template + worked findings + the 10-item pre-report
checklist: `references/qa-md-recipes.md`. Skeleton:

```markdown
# QA Report — {Project Name}

Date: {YYYY-MM-DD HH:MM}   Mode: {quick|full}   Project: {path}   Type: {detected type + runner}
ENV CLASS: {LOCAL | TEST-ENV/TEST-CREDS | SHARED-STAGING | REAL-DATA} — {policy line}
Atlas dossier: {consulted (R0 fresh) | consulted (stale, live-verified) | none}

## Executive Summary
Verdict: {[PROVISIONAL] SHIP | FIX BEFORE SHIP | DO NOT SHIP}
Findings: {N} (P0:{n} P1:{n} P2:{n} P3:{n} P4:{n})   Confirmed P0/P1: {n}

## Dimension Results
| Dimension | Status | Findings | Note (skipped items if PARTIAL) |
|-----------|--------|----------|---------------------------------|
| Functional | {PASS|FAIL|PARTIAL} | {n} | |
| ... (Edge, Cross-Platform, Regression, Destructive(Sim), UX, Performance, Security, State, Visual) |

## Test Suite Results
{sentinel-confirmed PASS/FAIL counts + exit code; PARTIAL if sentinel absent}

## Findings   (each: Severity · Confidence · Evidence · Reproduction · Location + Impact)
### P0 — Critical
#### {title}
- Severity: P0   Confidence: {confirmed|probable|theoretical}
- Location: {file:line | URL+state}
- Evidence: {command+output snippet | screenshot path (passed agent-browser §9.1) | file:line excerpt}
- Reproduction: {steps}
- Impact: {what breaks}
### P1 … P4  {same shape}

## Verification notes   {which probable/theoretical findings need confirming; any auto-downgrades}
## House gates   {i18n/theme/typography/CSS-build results, or N/A + reason}
## Destructive Test Plans   {full mode: safe procedures for a HUMAN to run — never fired}
## Recommendations   {prioritized by severity; route fixes to /e2e}
```

## 11. Failure-mode playbooks

### PB-1 — CI-panic ground truth (HR-10; verified 2026-05-17, 90 min lost)
CI/workflow reports FAILED during Dimension 4 → BEFORE writing any deploy-blocking finding:
```bash
curl -I https://<prod-url>/                                   # app responding?
gh run list -R <repo> --limit 5                               # a LATER green run on the same SHA?
# if SSH available:
sshpass -p "$VPS_PASSWORD" ssh "$VPS_USER@$VPS_HOST" \
  'docker ps --format "{{.Image}} {{.Status}} {{.CreatedAt}}"'  # container rebuilt recently?
```
Prod healthy + SHA live → the CI failure is historical noise → report as a P3 observability note, NOT
a blocker. Don't make anyone choose unblock options for a non-problem.

### PB-2 — Mobile/device bug, not reproducible locally (verified 2026-04-11, 7 wasted iterations)
STOP hypothesis-fixing. (1) Request a device screenshot. (2) Have the dev inject a diagnostic overlay
reporting: `prefers-reduced-motion`, `navigator.connection.{saveData,effectiveType}`, `visibilityState`,
`navigator.userAgentData.brands`, full UA, viewport+dpr, captured `onerror`/`unhandledrejection`,
app-specific hidden-count, and a pure-CSS keyframe test element. (3) Only then direct testing from the
overlay data. Simulator/Playwright-webkit verification is necessary but NOT sufficient for real-device
OS quirks. Complementary: if an adjacent repo already solved this bug class (e.g. orca-design-landing
motion stack), READ the working reference and diff BEFORE authoring cases (verified 2026-04-16) — 5 min
of reading beats 2 h of iterating.

### PB-3 — References-first
Same bug class solved in an adjacent repo → read the working reference, diff the approaches, THEN
author adversarial cases. Don't iterate from scratch against hypotheses.

### PB-4 — Hung suite (sentinel absent at hard budget, HR-9)
Capture pane state + the partial log; record the dimension **PARTIAL**; check `top` FIRST — a pegged
`next dev`/test process masquerades as everything-wedged (agent-browser HR-13). QA web apps against a
STATIC build (`pnpm build` + `python3 -m http.server` on `out/`), not `next dev`. NEVER kill a process
you did not start; if it's your own harness process and truly hung, kill only `=$WIN`.

### PB-5 — Secret found (HR-3)
Finding text: `credential material at <path>:<line>, pattern class <api-key|password|private-key|token>`;
severity per exposure (committed AND pushed = P0). The VALUE is NEVER reproduced anywhere. If the match
is in a data/log file, treat the FILE as the finding (don't quote its contents).

### PB-6 — Shared-queue approve
Follow §8.2 verbatim. If anything is ambiguous (>1 own-pending, no fresh request landed, unsure the
locator is synthetic-anchored), HALT and report rather than fire the approve.

### PB-7 — Browser wedge / any browser symptom
Do NOT debug in /qa. Jump to agent-browser §0 jump table → §10.0 wedge ladder and follow it verbatim.
If qutebrowser CDP itself is degraded and a human is unavailable, that is agent-browser's PB-2/PB-9,
not a /qa problem — mark the visual/live dimensions PARTIAL and continue with the static dimensions.

## 12. Cleanup checklist (always run, even on interrupt)

- [ ] Kill ONLY the run's window: `tmux kill-window -t "=$WIN" 2>/dev/null` (double-tap if unresponsive).
      NEVER `kill-window -t :qa` (HR-8).
- [ ] If the browser was used: agent-browser §12 teardown — `agent-browser close`; `/release?port=$PORT`
      for claimed ports; `/target?clear` for manual pins; verify `/sessions` no longer lists your port.
- [ ] Archive `QA-<timestamp>.md` + `$LOGDIR/evidence/` to the task dir.
- [ ] `./QA.md` written even on interruption, with the note "QA interrupted — partial results only" and
      the PARTIAL/PROVISIONAL labels set.
- [ ] No secret values in QA.md, the run log, or terminal scrollback (grep the draft for the scanned
      patterns' value-shapes before finalizing — HR-3).

## 13. References (progressive disclosure)

- `references/env-safety.md` — the full shared-env dossier: maker-checker approve incident narrative +
  protocol, `verify_element` no-halt evidence + synthetic-anchor xpath, exactly-1 rail, requester
  anchor, fitest-relevant QA gotchas (Network_Log CSV `>=400` triage, per-suite login-flake retry, WAF
  60s spacing, playwright driver for BMS), external-reporting rules (QA-scope, FE-observable framing),
  human-first authoring + screenshot-per-step/Expected-Results done-gates. Point-in-time facts (verified
  2026-06); creds live in `~/.claude/secrets.env` (env-var NAMES only, never values).
- `references/detection-matrix.md` — full language/framework detection with lockfile-based PM
  resolution, monorepo/workspace recipes, per-ecosystem command extraction, hybrid tie-break, fallback
  interview.
- `references/qa-md-recipes.md` — full QA.md template, worked findings (one exemplary CONFIRMED P1
  with evidence, one BANNED generic counter-example annotated), the expanded 10-item pre-report
  checklist, per-language redacted secret-scan variants.
