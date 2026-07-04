---
name: e2e
description: Full user-flow verification of ONE feature against a locally running app, with a root-cause fix-until-green loop — the only test skill that fixes what it finds (qa and ui-test are report-only). Use when the user asks to test a feature end-to-end, run e2e tests, verify a feature's full user flow ships, or check the app end-to-end. Not for a single-diff check (/verify), CI parity before push (/preflight), an adversarial codebase audit (/qa), or exhaustive per-role UI regression (/ui-test).
argument-hint: [feature or flow to test]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

# /e2e — Full User-Flow Verification, Fix Until Green

**The job in one line:** verify that ONE feature's full user flow actually works on a locally
running app — happy path + critical alternate paths — with evidence per step, FIX what breaks
at the root cause until everything is green, then commit the fixes via `/commit`.

All browser mechanics defer to the **agent-browser skill**
(`~/.claude/skills/agent-browser/SKILL.md`) as ground truth. This file cites its HR-x rules,
section numbers, and PB-x playbooks — it never re-derives them. The browser being driven is
**Christopher's LIVE authenticated qutebrowser**. Treat every browser action as production.

## 0. FAILING NOW? — jump table

| Symptom right now | Go to |
|---|---|
| Navigation / snapshot / screenshot wedged; tabs stuck `about:blank` | **FP-1** (server first!), then agent-browser §10.0 |
| Dev server suspected pegged (everything slow on one origin) | **FP-2** — `top` first |
| docker-compose service stuck in `Created`, `compose up` hangs | **FP-3** healthcheck startup-gate |
| Login wall mid-flow, no credentials at hand | **FP-4** — STOP guessing, equip |
| Screenshot blank / black / wrong theme / oversized | **FP-5** → agent-browser PB-4 / §9.4 / PB-5 |
| Same failure survived 3 root-caused fix attempts | **FP-6** stop-loss dossier |
| Playwright tool call denied by hook | Correct behavior — E-1. Pivot to agent-browser, zero workarounds |
| `agent-browser tab new` exited 144 | Expected in this env — agent-browser HR-9; use the `/claim` path (§P1) |
| A flow step failed once | **E-19** — re-run once BEFORE entering the fix loop |
| `503 No free ports` from /claim | agent-browser §6.3 — release ONLY provably dead entries |

## 1. What /e2e is — and is not (sibling routing)

/e2e is the only member of the test trio that **fixes and commits**. Its siblings observe and
report; /e2e closes the loop. Route by the ask:

| The ask sounds like | Skill | Role |
|---|---|---|
| "test this feature end-to-end" / "verify this flow ships" / "does checkout work?" | **/e2e** (this) | ONE feature, full user flow, fix-until-green, commits fixes |
| "how can this codebase break?" / "audit it" / adversarial multi-dimension sweep | **/qa** | whole-codebase adversarial QA, report-only, never fixes |
| "test every element on every page for every role" | **/ui-test** | config-driven exhaustive UI regression per role, report-only |
| "does my current diff work?" | **/verify** (built-in) | single-change verification, no fix loop |
| "will CI pass before I push?" | **/preflight** | local CI-parity checks |
| "map / screenshot the whole product" | **/atlas** | neutral capture dossier, no judgment, no fixes |
| "run the app so I can see it" | **/run** | launch + observe, not a test |

Boundary rules:
- **Scope = ONE feature.** If the change set spans multiple features, either pick one with the
  user or run /e2e once per feature. An unbounded "test everything" ask is /qa or /ui-test.
- **The deliverable test:** if the deliverable is "this feature works, fixed if broken" →
  /e2e. If the deliverable is "a findings report for someone else to act on" → /qa or /ui-test.
- Never cite /qa or /ui-test internals from here — they are defined by ROLE only.

## 2. HARD RULES (E-1..E-19 — memorize before the first command)

- **E-1 — NEVER use Playwright MCP or Chrome as the browser.** Hook-enforced deny in
  `~/.claude/settings.json`; a denied Playwright call means the hook fired CORRECTLY — pivot
  to agent-browser, no workarounds (agent-browser HR-1). Project test suites that require
  launching Playwright/Cypress/Chrome are NOT run — execute the same flows manually via
  agent-browser and note the suite's existence in the report.
- **E-2 — NEVER kill, restart, or `:restart` qutebrowser; never `pkill` anything matching
  qutebrowser.** It is Christopher's live authenticated browser (agent-browser HR-2).
  Degraded qutebrowser CDP = STOP and escalate (agent-browser PB-2, human-gated).
- **E-3 — NEVER use `agent-browser tab new` as the primary new-surface path** (field-broken,
  exit 144 — agent-browser HR-9). Canonical: `/claim?from=9223&url=<url>` then connect within
  30s (agent-browser HR-7/HR-8, §6.3).
- **E-4 — ALWAYS run the agent-browser §3 pre-flight gate** (3 commands, ~2s) before the
  first browser command of the run. Any gate failure routes to its named playbook — never to
  improvisation.
- **E-5 — ALWAYS execute the §9 teardown checklist, even on failure or abort:** agent-browser
  close, `/release` every claimed port, `/target?clear` manual pins, verify `/sessions` no
  longer lists your port, stop any dev server THIS run started.
- **E-6 — ALWAYS check server CPU (`top`) FIRST when navigation, snapshot, or screenshots
  wedge.** A pegged `next dev` makes every client look wedged (agent-browser HR-13; verified
  2026-07-02, one hour lost). Never spend >5 min on browser archaeology before ruling out the
  server.
- **E-7 — NEVER kill a dev server you FOUND already running** (it may be Christopher's).
  Only stop servers this e2e run started — record the PID at start (§4).
- **E-8 — NEVER run visual/pixel assertions against `next dev` HMR state.** Dev HMR leaves
  stale inline styles that corrupt visual verification. Build static (`pnpm build` +
  `python3 -m http.server` on the output dir) for visual checks; functional flows may use the
  dev server after the E-6 CPU check.
- **E-9 — ALWAYS screenshot EVERY flow step** (before-state optional, after-state mandatory)
  and run the agent-browser §9.1 QA gate on each shot. A step without passing evidence is
  NOT_VERIFIED, and NOT_VERIFIED blocks an ALL PASS verdict. (House standard proven in fitest
  work: screenshot-per-step + expected results defined BEFORE execution.)
- **E-10 — ALWAYS assert exit codes and HTTP status codes explicitly; NEVER treat a 2xx as
  proof of a mutation.** Re-fetch the state and confirm persistence (verify-after-write —
  two verified silent-fail bugs 2026-05-09 where a 200 masked a no-op write).
- **E-11 — NEVER mutate real-tenant / real-user data.** Mutations are allowed ONLY with
  designated test credentials on the designated test tenant — the gate is "is it real
  data?", NOT "is it the prod URL?" (e.g. Pulse's Alamanda Coffee test tenant is fair game
  on the prod deployment). Never wholesale-delete seed data even there (additive
  state-creation is safe; nuking the seed is not). Destructive flows without a test tenant
  are simulated and flagged NOT_VERIFIED.
- **E-12 — NEVER modify a test to make it pass — fix the source.** A test that is genuinely
  wrong (testing outdated behavior) MAY be fixed, but that fix MUST be flagged separately in
  the report as a test correction, never silently folded into "fixes".
- **E-13 — ALWAYS fix via root cause** (§6 doctrine): read the code, trace the error to its
  origin, fix where it starts. NEVER bandaid, swallow errors with try/catch, disable checks,
  or add fallback values that mask the real issue.
- **E-14 — Stop-loss: the same failure surviving 3 DISTINCT root-caused fix attempts → STOP**,
  write the failure dossier (FP-6), ask Christopher. And after EVERY fix, re-run the FULL
  flow set from the beginning — not just the failed step.
- **E-15 — ALWAYS commit fixes via the /commit skill only** (it carries the
  `CLAUDE_COMMIT_SKILL=1` sentinel; raw `git commit` is hook-blocked). Stage ONLY files the
  fix loop touched — NEVER `git add -A` / `git add .` — and never commit evidence artifacts
  or pre-existing dirt.
- **E-16 — ALWAYS run a real CSS compile when a fix touches `.css` or token files** (postcss
  parse / `next build` / tailwind build). `tsc` does not parse CSS — a `*/` inside a CSS
  comment 500'd every route while tsc passed clean (verified 2026-06-24). Match the
  verification tool to the artifact.
- **E-17 — NEVER write screenshots of authenticated apps to shared /tmp, never dump
  cookies/tokens, never embed credentials in the report** (agent-browser HR-15). Evidence
  lives in the task dir or session scratchpad. A secret found in the app under test is
  reported as "found at <file>, pattern <type>" only — never the value.
- **E-18 — ALWAYS wait for SPA settle before snapshot** (`agent-browser wait --load
  networkidle` — agent-browser HR-11) and never reuse `@eN` refs across a DOM mutation —
  prefer `find role|text|label` semantic locators (HR-10). Stale refs create FALSE failures
  that poison the fix loop.
- **E-19 — ALWAYS distinguish flake from regression BEFORE entering the fix loop.** Re-run a
  failed step once. Only a reproduced failure enters root-cause analysis. A one-off
  pass/fail flip is logged as FLAKY with BOTH artifacts kept — it is never "fixed" and never
  ignored.

## 3. Pipeline — P0..P5, each gate blocks the next

### P0 — Scope contract (before touching the app)

1. **Feature under test:** `$ARGUMENTS` if provided. Otherwise detect the change set — in
   this order (the dominant e2e trigger is UNCOMMITTED just-written work):
   ```bash
   git status --porcelain            # dirty tree? → the uncommitted change set is the scope
   git diff --name-only HEAD         # names of uncommitted changes
   git diff --name-only HEAD~1       # ONLY if the tree is clean (fails on single-commit repos — use: git show --stat HEAD)
   ```
2. **Read the changed files** to understand what feature was modified; identify the
   user-facing flows affected. Monorepo: scope detection to the changed package.
3. **Enumerate the flows** — 1 happy path + the critical alternates that apply (validation
   error, empty state, permission denial, cancel/back-out). Number every step and write the
   **expected result per step BEFORE execution** (fitest expected-results discipline — a
   test without a pre-declared expected result cannot fail honestly).
4. **Declare the mutation plan:** which steps write data, and against which test tenant /
   test creds (E-11). No test tenant for a destructive step → mark it simulated/NOT_VERIFIED
   NOW, not mid-flow.
5. **Create the evidence dir** `$EVID`: inside the 3-tier task dir when one exists
   (`~/claude/notes/<task-slug>-<date>/evidence/`), else the session scratchpad. Never
   shared /tmp (E-17).

**Gate:** flows + numbered steps + expected results + mutation plan written to
`$EVID/ledger.md` before any execution.

### P1 — Environment gate

1. **Dev server** — apply the §4 decision table (found-running vs start-and-record-PID vs
   compose vs static build).
2. **Existing test infra check** (informs, never replaces, the manual flow):
   - Look for `**/*.e2e.*`, `**/*.spec.*`, `**/*.test.*` in e2e/test directories;
     `cypress/`, `playwright/`, `e2e/`, `tests/` dirs; `package.json` e2e scripts.
   - Runnable suites that do NOT depend on Playwright/Cypress/Chrome (e.g. vitest/jest API
     tests) → run them first as a supplement, assert their exit codes into the ledger.
   - Playwright/Cypress suites → do NOT launch (E-1); execute the same flows manually via
     agent-browser and note the suite in the report.
   - **No test infra at all is the NORM, not a degraded mode** — the manual agent-browser
     flow IS the e2e test.
3. **Equip credentials BEFORE the first flow** (never hit a login wall mid-run — FP-4):
   locate the app's designated test creds (memory `reference_pulse_test_creds` for Pulse;
   `~/.claude/secrets.env` env-var pointers; the app's own seed/README). Pointers only —
   never inline values into briefs, ledgers, or reports.
4. **Browser session** (only if the flow needs a browser):
   - Run the agent-browser **§3 pre-flight gate** (3 commands). Gate 1 fail → PB-1; gate 2
     fail → PB-2 (STOP, human-gated); unexpected pin → PB-6.
   - Single interactive flow on the current tab → Mode A on 9222 (agent-browser §4).
   - Anything parallel, long-running, or needing a fresh surface → the `/claim` lifecycle
     **exactly per agent-browser §6.3** — claim with `from=9223`, connect within 30s, verify
     the pin landed (HR-4), persist `AGENT_BROWSER_CDP` / unique `AGENT_BROWSER_SESSION` /
     `AGENT_BROWSER_COLOR_SCHEME=light` in `$EVID/browser.env` and source it in EVERY
     subsequent call (§6.4). Minimal claim form (full recipe in §6.3):
     ```bash
     curl -s -G "http://localhost:9222/claim" --data-urlencode "from=9223" --data-urlencode "url=<url>"
     # then: agent-browser connect <port>   (within 30s)
     ```
5. **Record run state** in the ledger header: claimed port(s), dev-server PID if started,
   static-build port if serving one.

**Gate:** pre-flight green + creds equipped + server decision recorded. Any failure routes
to the named playbook — do not start flows on a limping environment.

### P2 — Execution (evidence ledger per step)

Per step: **act → settle → capture → assert → record.**

- Read page state with `agent-browser snapshot -i -c --json`; interact with
  `agent-browser fill` (replaces) / `click` / `find role|text|label ...`; after any SPA
  navigation or DOM-mutating click: `agent-browser wait --load networkidle`, then
  re-snapshot (E-18).
- **UI step evidence:** after-state screenshot to `$EVID/`, passing the agent-browser §9.1
  QA gate (brightness/blank checks; DPR trim ONLY on `--full` outputs per §9.2).
- **API step evidence:** capture status + body and assert both (worked pattern in
  references/flow-recipes.md R-B):
  ```bash
  code=$(curl -s -o "$EVID/resp.json" -w '%{http_code}' <url>); [ "$code" = "200" ] || echo "FAIL status=$code"
  jq -e '.status == "ACTIVE"' "$EVID/resp.json"   # exit 0 = assertion holds
  ```
- **Mutation step evidence:** verify-after-write (E-10) — re-fetch via GET / re-read the
  file / SELECT the row and confirm the change persisted. The re-fetch output IS the
  evidence; the 2xx is not.
- **End of each flow:** console + network sweep even if the UI looks correct —
  `agent-browser console`, `agent-browser errors`,
  `agent-browser network requests --filter api --type xhr,fetch`. Console errors on a
  "passing" flow are findings, not noise.
- **On a failed step:** re-run it once (E-19). Reproduced → P3 fix loop. One-off → verdict
  FLAKY, keep both artifacts, continue the flow.

**Gate:** every executed step has a ledger row with evidence + exit/status code + verdict.

### P3 — Fix loop (§6 doctrine, budgeted by E-14)

### P4 — Report gate (§5 template; commit gate in §6 must pass first if fixes were made)

### P5 — Teardown (§9 checklist — runs even on failure/abort)

## 4. Dev-server hygiene — decision table

The two verified failure classes this section exists for: (a) 2026-07-02 — a CPU-pegged
`next dev` masqueraded as a browser/CDP wedge for an hour; (b) 2026-06-16 — a compose
healthcheck `interval: 1h` without `start_interval` left gated services stuck in `Created`
(~10 min prod outage).

| Situation | Action |
|---|---|
| Server ALREADY running on the target port | Reuse it. NEVER kill it (E-7). If flows later wedge → `top` FIRST (E-6), then FP-2. |
| Not running | Start it yourself and RECORD THE PID (start pattern in references/flow-recipes.md — `setsid` + pid file so teardown can kill the whole group). Stop it at P5. |
| docker-compose stack | `docker compose up -d`; then `docker compose ps` — ANY service sitting in `Created` → FP-3 recovery, and file the healthcheck finding. |
| Visual / pixel / theme assertions | Static build ONLY (E-8): `pnpm build`, then `python3 -m http.server <port> --directory <outdir>`. Functional flows may stay on the dev server after the CPU check. |
| Mid-run: nav timeouts, blank shots, `about:blank` tabs | `top` FIRST (E-6) → FP-1 / FP-2. Not browser archaeology. |
| Backend-only feature | No browser at all — R-B (API flow) against the running service; same evidence bar. |

## 5. Evidence ledger + report

### 5.1 The ledger (`$EVID/ledger.md` — one table per flow, REQUIRED)

| # | Action (exact command) | Expected | Actual | Evidence | Exit/Status | Verdict |
|---|---|---|---|---|---|---|

- Verdicts: **PASS / FAIL / FLAKY / NOT_VERIFIED**.
- Quantified floor: every UI step has ≥1 screenshot passing the §9.1 gate; every mutation
  step has a re-fetch proof; every API step has status + body assertion; every shell step
  has its exit code.
- Expected column is filled at P0, BEFORE execution. Actual/Evidence/Verdict at P2.
- Filled example: references/flow-recipes.md.

### 5.2 Report template

```
E2E RESULTS — <feature>
=======================
Feature:      <what was tested>
Flows:        <N> — <names>
Steps:        <total> | PASS <n> · FAIL <n> · FLAKY <n> · NOT_VERIFIED <n>
Fixes made:   <count, 0 if none — each as symptom → root cause → fix → proof>
Test fixes:   <separately flagged corrections of genuinely-outdated tests (E-12), or none>
Commits:      <hash(es) via /commit, or none>
Console:      <clean | N errors, listed>
Not verified: <each NOT_VERIFIED step + why + what alternative check was done>
Verdict:      ALL PASS | PASS WITH FLAGS | FAIL
Evidence:     <$EVID path>
```

**Verdict logic (mechanical, not vibes):**
- **ALL PASS** — every step PASS. INVALID if any step is FAIL, FLAKY, or NOT_VERIFIED (E-9).
- **PASS WITH FLAGS** — no FAILs, but FLAKY/NOT_VERIFIED steps or console findings exist;
  each flagged with its reason.
- **FAIL** — any FAIL remains after the fix loop (i.e. E-14 stop-loss fired → FP-6 dossier).

If fixes were committed, list what was fixed and the commit hash. Never claim "verified" for
anything without a ledger row — "I ran it and it looked fine" is a claim, not evidence.

## 6. Fix loop doctrine + commit gate

### 6.1 The loop (load-bearing — this is the skill's payload)

If ANY step or verification fails (and E-19 confirmed it reproduces):

1. **Capture the exact error** — screenshot, console output, test failure message.
2. **Root cause analysis first — MANDATORY.** Before writing any fix:
   - Read the relevant source code, trace the execution path, and identify the actual root cause.
   - Understand WHY the bug exists, not just WHAT the symptom is.
   - Trace the error back to its origin — don't fix where it surfaces, fix where it starts.
   - NEVER apply temporary fixes, workarounds, bandaids, or suppress errors.
   - NEVER use try/catch to swallow errors, disable checks, or add fallback values that mask
     the real issue.
   - The fix must address the underlying cause, not the symptom.
3. **Fix the root cause immediately — do not ask for permission.** BOUND: this covers
   in-scope bug fixes. A fix that requires an ARCHITECTURAL change (schema migration, API
   contract change, cross-service refactor) STOPS the loop — present it with evidence
   instead of auto-executing.
4. **Verify with the right tool for the artifact:** code → run it; CSS/token files → real
   CSS compile (E-16); config → restart the affected process and probe it.
5. **Re-run ALL flows from the beginning** — not just the one that failed. A fix that breaks
   a previously-green step is a regression, not progress.
6. **Log every fix** in the ledger: symptom → root cause → fix → proof.
7. Keep looping until ALL steps and verifications pass.
8. **Stop-loss (E-14):** same failure surviving 3 DISTINCT root-caused attempts → STOP,
   FP-6 dossier, ask Christopher. Leave the code at the LAST known-good state — revert a
   half-fix rather than leaving it in.

### 6.2 Commit gate (blocking checklist BEFORE invoking /commit)

- [ ] `git status --porcelain` diffed against the fix log — ONLY loop-touched files staged,
      by name (never `git add -A` / `git add .`).
- [ ] Pre-existing dirt (files dirty before this run) left unstaged.
- [ ] No evidence artifacts / screenshots / `$EVID` contents staged.
- [ ] CSS compile ran clean if any `.css`/token file was touched (E-16).
- [ ] Every staged change maps to a logged fix (symptom → root cause → fix → proof).
- [ ] Commit via the **/commit skill** (Skill tool) — it carries `CLAUDE_COMMIT_SKILL=1`;
      raw `git commit` is hook-blocked (E-15).

## 7. Failure-mode playbooks (FP-1..FP-6 — thin by design; agent-browser owns the browser lore)

### FP-1 — Browser/CDP wedge

/e2e adds ONE step in FRONT of the agent-browser ladder: **is the wedge actually the app
under test crashing?** `tail -50` the dev-server log ($EVID/devserver.log or the compose
logs) — a crash-looping app produces identical symptoms to a browser wedge. Then run the
agent-browser **§10.0 wedge triage ladder verbatim** (step 1 is `top` — E-6; then 2262, then
9222/PB-1, then daemon/PB-3, then qb-shoot/PB-4, then PB-9 last resort). Never skip step 1.

### FP-2 — Pegged dev server

Symptoms: `Page.navigate` timeouts, `about:blank` tabs, ALL clients wedged on one origin.
Diagnose with `top` (the 2026-07-02 case: `next dev` at 115% CPU starving every client).
- THIS run started it → `kill -- -$(cat $EVID/devserver.pid)` (group kill), restart it — or
  switch visual work to the static build (E-8).
- Found it running → report to Christopher (E-7 — never kill it), continue against a static
  build meanwhile.
- Aftermath trap: qutebrowser CDP can STAY degraded after the server recovers (fresh tabs
  never commit) — that needs a human-gated `:restart` → agent-browser PB-2. Don't fight it.

### FP-3 — Compose service stuck in `Created` (healthcheck startup-gate trap)

A long healthcheck `interval` without `start_interval` means the FIRST probe waits a full
interval — `depends_on: condition: service_healthy` blocks and gated services never start
(verified 2026-06-16, ~10 min outage). Recovery: kill the hung `docker compose up`, then
`docker start <gated-containers>` (they connect fine to the already-running dependency),
verify the app answers. Then file the ROOT-CAUSE finding: the healthcheck needs
`start_period` + `start_interval` alongside the long `interval`. Exact commands:
references/flow-recipes.md.

### FP-4 — Login wall mid-flow

STOP guessing credentials (lockout risk — e.g. BMS admin locks at 3 failed attempts).
Equip from the designated source (P1 step 3), auto-login through the REAL login form
(`find label` → `fill` → submit → `wait --load networkidle` → verify a logged-in element) —
never cookie/token injection. No test creds exist for this app → mark every auth-gated flow
NOT_VERIFIED and report; do not improvise accounts.

### FP-5 — Bad screenshot evidence

Blank/black → agent-browser **PB-4** ladder (retry once after 2-3s → qb-shoot full-path
fallback). Dark shot of a light page → **§9.4** color-scheme drift — pin
`AGENT_BROWSER_COLOR_SCHEME=light` in `$EVID/browser.env` (dark only for deliberate
dark-theme QA, inverting the §9.1 threshold). Oversized `--full` with content top-left →
**PB-5** trim recipe, `--full` outputs ONLY (HR-12). Never keep a failed shot as evidence.

### FP-6 — Fix loop stuck (stop-loss fired)

Write the failure dossier into the report: symptom; all 3 attempts each as
hypothesis → fix → proof-it-didn't-work; remaining hypotheses; exact repro steps + evidence
paths. Revert any half-fix so the tree sits at the last known-good state. Verdict = FAIL.
Ask Christopher — do not burn a 4th attempt on the same wall.

## 8. Do / Don't

| DO | DON'T |
|---|---|
| Write expected results BEFORE executing a step (P0) | Decide "what it should do" after seeing what it did |
| Assert exit codes + HTTP statuses explicitly (E-10) | Eyeball output and call it passing |
| Re-fetch state after every mutation (E-10) | Trust a 2xx as proof the write landed |
| Re-run a failed step once, then classify (E-19) | "Fix" a one-off flake or ignore it silently |
| `top` first when anything wedges (E-6) | An hour of CDP archaeology while `next dev` burns a core |
| Static build for visual assertions (E-8) | Pixel-judge `next dev` HMR state |
| Reuse a found dev server; kill only own-started PIDs (E-7) | `pkill -f node` "cleanup" |
| Re-snapshot after DOM-mutating clicks; `find role/text/label` (E-18) | Reuse pre-click `@eN` refs |
| Chain browser commands with `&&` (daemon persists) | `agent-browser close` between every step |
| Evidence into `$EVID` (task dir / scratchpad) | Screenshots of authenticated apps in shared /tmp (E-17) |
| Stage named, loop-touched files; commit via /commit (E-15) | `git add -A`, raw `git commit`, sweeping pre-existing dirt |
| Fix the source when a test fails (E-12) | Doctor the test until it passes |
| CSS compile when the fix touched CSS (E-16) | "tsc passed" as verification for a CSS change |

## 9. Teardown checklist (blocking DONE — runs even on abort)

- [ ] Browser teardown per **agent-browser §12**: `agent-browser close`; `/release?port=N`
      every claimed port; `/target?clear` any manual pin; `curl -s
      http://localhost:9222/sessions` no longer lists your port(s).
- [ ] Dev servers THIS run started: killed by recorded PID/group, `ps -p <pid>` confirms
      gone. Found-running servers untouched (E-7).
- [ ] Static-build `http.server` (if any) stopped.
- [ ] Evidence ledger complete — every executed step has a row.
- [ ] Report written (§5.2), NOT_VERIFIED items explained.
- [ ] No orphaned processes from this run (`ps` sweep for anything you spawned).

## 10. Edge cases

- **No test infra in the repo** — normal. The manual agent-browser flow IS the e2e test.
- **Playwright/Cypress suite present** — not launched (E-1); flows run manually; suite noted
  in the report so the owner knows it exists and wasn't executed.
- **Monorepo** — scope P0 detection to the changed package; run only that package's flows.
- **Feature flags** — test BOTH states, or explicitly flag which state was tested and why.
- **i18n apps (Aenoxa ecosystem house default)** — spot-check the `id` default-locale route,
  not just `en`. If only `en` works, FLAG it as a finding (house website-build default
  violation) — flagging, not fixing, unless the feature under test IS the i18n change.
- **Feature spans UI + API + DB** — use the R-C mixed recipe: verify at every layer the flow
  crosses, not just the one it started in.

## 11. References

- `references/flow-recipes.md` — worked recipes R-A (web flow), R-B (API flow), R-C (mixed),
  dev-server start/stop pattern, compose healthcheck recovery commands, login/equip
  patterns, filled example ledger + report.
- `~/.claude/skills/agent-browser/SKILL.md` — GROUND TRUTH for all browser mechanics: HR-1..17,
  §3 pre-flight gate, §4 mode table, §6.3 claim lifecycle, §6.4 env-file discipline, §9.1
  screenshot QA gate, §9.2 DPR trim, §10.0 wedge ladder, PB-1..PB-9, §12 teardown.
- Memories encoded here (cite, don't re-learn): `reference_devserver_peg_phantom_wedge`,
  `reference_healthcheck_interval_breaks_startup_gate`, `feedback_verify_after_write`,
  `feedback_fitest_screenshot_per_step`, `feedback_mutations_ok_on_test_env` (+
  `reference_pulse_test_creds` as the creds pointer), `feedback_verify_css_changes_with_compile`,
  `feedback_browser_qutebrowser`, `feedback_commit_skill_enforced`.
