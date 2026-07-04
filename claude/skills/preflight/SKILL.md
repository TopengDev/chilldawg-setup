---
name: preflight
description: "Pre-push readiness gate: local CI-parity checks (lint, types, tests, build) PLUS house hygiene gates (gitleaks secrets, AI-trailer scan, dependency denylist, lockfile sync, CSS compile). Reports a computed READY / NOT READY verdict with per-gate evidence. NEVER pushes. Use when the user asks whether CI will pass, wants a check before pushing, or says /preflight. For actually pushing, shipping, or deploying use /ship (which invokes /preflight at its step 7)."
argument-hint: "[lint | types | css | test | build | secrets | trailers | deps | quick]"
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

# Preflight - The Pre-Push Gate

Preflight is the LAST local gate before code leaves this machine. Its job: guarantee
that when /ship (or the user) pushes, CI goes green and nothing embarrassing or
dangerous rides along in the range. It runs a fixed gate ladder (G0-G9), fixes what it
can at the root cause, commits fixes via /commit, and emits a computed verdict.

Two failure classes it exists to kill:
1. **"Green local, red CI"** - lockfile drift, version mismatch, CSS that tsc can't see.
2. **"Green CI, dirty range"** - secrets, AI-attribution trailers, compromised deps
   that no CI workflow checks for.

---

## 0. HARD RULES (PF-1 .. PF-15)

**PF-1 - NEVER push.** Never run `git push` in any form, including `--dry-run` as an
action substitute. Preflight reports readiness; /ship owns the push. If the user said
"push", run the gates, report READY / NOT READY, and hand off to /ship.

**PF-2 - NEVER declare READY while any applicable gate is FAIL or BLOCKED.**
BLOCKED (tool unavailable, env absent, check could not run) is NOT a pass. It is a
distinct status that vetoes READY. There is no "probably fine" verdict.

**PF-3 - NEVER commit via raw `git commit`. ALWAYS invoke the /commit skill** for fix
commits. The seal-guard PreToolUse hook (`~/.claude/hooks/block-raw-git-commit.sh`)
denies raw commits; /commit carries the `CLAUDE_COMMIT_SKILL=1` sentinel; the hook
denies AI-trailer messages even WITH the sentinel. Cite: memory
`feedback_commit_skill_enforced`.

**PF-4 - NEVER print or write a secret value** from a gitleaks hit anywhere (report,
log, commit message, chat). Always pass `--redact` to gitleaks. Report file:line +
rule id + commit hash only.

**PF-5 - NEVER pass a gate by weakening it.** Without explicit user approval recorded
in the final report, NEVER: add `test.skip` / `it.only` / delete a failing test, add
`eslint-disable` / `@ts-ignore` / `@ts-expect-error`, add `.gitleaksignore` entries or
inline `gitleaks:allow` comments, set `--exit-code 0`, use `--no-verify`, or comment
out a CI step. A gate you disabled is a gate that FAILED.

**PF-6 - NEVER allow axios 1.14.1 or 0.30.4.** ANY occurrence of `plain-crypto-js` in
a lockfile is an automatic FAIL (compromised supply chain, memory
`feedback_axios_supply_chain`). NEVER upgrade axios as a "fix" without verifying the
target version against current advisories (socket.dev / npm advisories) first.

**PF-7 - ALWAYS run a real CSS compile when the diff touches `.css`/`.scss`/token
files** (working tree OR push range). tsc does not parse CSS: a tsc-clean globals.css
500'd every route on 2026-06-24 (memory `feedback_verify_css_changes_with_compile`).
NEVER write `*/` inside a CSS comment.

**PF-8 - ALWAYS scan for secrets before READY.** Range:
`gitleaks git --log-opts "$UP..HEAD" --no-banner --redact .` AND working tree:
`gitleaks git --staged --pre-commit --no-banner --redact .`. No upstream? Use
`--log-opts "--branches --not --remotes"` plus `gitleaks dir . --no-banner --redact`.
NEVER use `gitleaks detect` - that subcommand does NOT exist in the installed 8.21.2
(verified 2026-07-02: subcommands are completion, dir, git, help, stdin, version).

**PF-9 - ALWAYS scan unpushed commit MESSAGES for AI-attribution trailers** before
READY (line-anchored `Co-Authored-By:.*(Claude|Anthropic|noreply@anthropic)` or
`Generated with .*Claude Code`). A hit = FAIL. Fixing it means history rewrite, which
is USER-GATED: never auto-rebase or auto-amend a multi-commit range. Verified failure
2026-06-15: 32 AI-attributed commits reached pi-setup and required a history scrub +
force-push (memory `feedback_commit_skill_enforced`).

**PF-10 - ALWAYS pre-check tool availability with `command -v` before each gate.**
Missing tool = BLOCKED with the install hint, never a silent skip. For Python repos,
resolve project-local tooling first (`.venv/bin`, `uv run`) before assuming globals:
ruff / flake8 / pytest are NOT on this box's PATH (verified 2026-07-02). Same for Go:
`go` and `golangci-lint` are absent. tsc is not global: always `npx tsc`.

**PF-11 - ALWAYS re-run ALL gates from G0 after ANY fix is applied**, in CI's
execution order. A fix to one gate can break another (a lint autofix can break a
test; a dep bump changes the lockfile).

**PF-12 - ALWAYS bound the fix loop.** Max 3 attempts per distinct error signature,
max 10 total fix cycles per run, max 30 min wall clock. On budget exhaustion STOP with
the structured stuck-report (section 4) and escalate. No unbounded loops: preflight
runs inside /ship, worker sessions, and the autonomous loop.

**PF-13 - ALWAYS fix root-cause-first.** Read the relevant source, trace the
execution path, identify the actual root cause. Understand WHY the error exists, not
just WHAT the symptom is. Fix where the error starts, not where it surfaces. NEVER
apply bandaids, suppress errors, swallow with try/catch, or add fallback values that
mask the real issue. (Carried forward intact from the original skill - this is
Christopher's global override.)

**PF-14 - NEVER use browser automation inside preflight.** Behavioral / browser
verification belongs to /verify and /e2e, which defer to the /agent-browser skill
(its HR-1: Playwright MCP is hook-banned in this environment). Preflight is
command-line only.

**PF-15 - ALWAYS set an explicit Bash timeout (up to 600000 ms) or
`run_in_background`** for build gates expected to exceed 2 minutes (`next build`,
`docker compose build`), and check `free -h` before heavy builds. This 14Gi box has
verified OOM history under 2+ concurrent heavy builds (memory
`reference_local_box_oom_heavy_workers`). Never run two heavy builds concurrently.

---

## 1. Boundary Charter - who does what

Trigger routing: bare "push" / "ship" / "deploy" verbs route to **/ship**. Preflight
answers "will CI pass?", "check before push", "/preflight". /ship calls /preflight; a
user asking to push gets the gates run here and the push handed off.

| Skill | It owns | Preflight's relationship |
|---|---|---|
| **/ship** | The push + full pipeline (simplify, security review, e2e, version, commit, preflight, push, tag, CI watch) | Calls /preflight at its step 7. Preflight NEVER pushes back. |
| **/commit** | Staging, message generation, conventional format, `CLAUDE_COMMIT_SKILL=1` sentinel, no-AI-attribution | Preflight invokes /commit for every fix commit. CAVEAT: /commit does NOT stage lockfiles by default - when a fix regenerates a lockfile, tell /commit explicitly to stage BOTH package.json and the lockfile. |
| **/qa** | Adversarial testing across 10 dimensions, severity-graded report | Different question: "where does it break?" vs preflight's "will CI pass?". |
| **/e2e** | Browser-flow end-to-end testing (via /agent-browser) | Ship step 3, before preflight. Preflight never drives a browser (PF-14). |
| **/verify** | Single-change behavioral verification (exercise the affected flow) | Per-change depth; preflight is per-push breadth. |
| **/audit** | Whole-repo multi-lens readiness verdict | Strategic; preflight is the mechanical pre-push gate. |
| **/security-review** | Judgment review of diff for exploitable vulns | Preflight's security surface is MECHANICAL only: gitleaks + denylist + lockfile. Logic vulns belong to /security-review (ship step 2). |

**Ship-step-7 contract (preflight upholds its side):** when invoked from /ship,
preflight MUST (a) commit its own fixes via /commit, (b) block until all gates pass
or the fix budget exhausts, (c) return the gate table so ship's final report can
embed `Preflight: PASS`. Ship's SKILL.md states "If /preflight finds and fixes
issues, it will commit those fixes automatically" - that promise is honored here.

**Commit-time vs push-time secret scanning:** preflight owns the PRE-PUSH range scan
and the staged scan (G7). Commit-time staged scanning may additionally live in
/commit; that does not replace G7, because commits made by other tools / hosts /
sessions still enter the push range.

---

## 2. Gate Ladder G0-G9

Run in order. Every gate emits one of four statuses:

| Status | Definition |
|---|---|
| **PASS** | Check ran, exit criterion met, evidence recorded (command + exit code). |
| **FAIL** | Check ran, criterion not met. |
| **BLOCKED** | Check could NOT run: tool missing, no upstream, env absent. NEVER a pass (PF-2). |
| **N/A** | Gate does not apply to this stack; the reason is recorded. |

**Verdict rule (computed, not judged): READY iff every applicable gate = PASS and
BLOCKED count = 0.** WARNs do not veto READY but must appear in the report.

Per-stack command variants (Go, Python, Docker-driven CI, monorepo) live in
`references/ci-recipes.md`. The commands below are the default TS/Next path.

### G0 - Context (always)

```bash
git rev-parse --is-inside-work-tree          # must be true
git branch --show-current
UP=$(git rev-parse --abbrev-ref '@{upstream}')   # fails => no-upstream playbook
git log --oneline "$UP..HEAD" | wc -l        # unpushed commit count
git status --porcelain | wc -l               # dirty-tree summary
```

Detect the stack: `package.json` / `go.mod` / `pyproject.toml` / `Cargo.toml`.
Detect the package manager from the LOCKFILE (never assume npm):
`package-lock.json` -> npm, `pnpm-lock.yaml` -> pnpm, `bun.lock`/`bun.lockb` -> bun,
`yarn.lock` -> yarn; tie-break with `jq -r '.packageManager // empty' package.json`.
Exit criterion: repo, branch, push range, stack, and package manager all resolved.
No upstream is NOT a failure: switch to the no-upstream playbook ranges and note
"first push of branch" in the report.

### G1 - CI parse (always)

Read `.github/workflows/*.yml` / `*.yaml`. For EACH workflow determine:
1. Does it fire on push to THIS branch? (`on:` block; bare `push:` = all branches;
   `branches:` filters must match `git branch --show-current`.)
2. What commands do its steps run? These define which gates below are "applicable"
   and their exact commands - mirror CI, don't invent.
3. Version matrix vs local (`node-version:` vs local node v22.16.0, etc.) - mismatch
   is a WARN in the known-divergence list, not auto-FAIL.
4. CI-only env vars / secrets (`${{ secrets.* }}`) - list as known divergence.

Parsing recipes (grep-based, no yq): `references/ci-recipes.md` section "Workflow
parsing". If CI runs its checks inside Docker (e.g. `docker compose run tests`),
replicate that approach locally rather than running bare commands.

**NO-CI FALLBACK:** if no workflows exist, do NOT dead-stop. Run the house default
gate set for the detected stack (G2/G3/G5/G6 from package.json scripts or stack
conventions; G7/G8/G9 ALWAYS) and note "no CI defined" in the report. Ask the user
only if the stack itself is undetectable.

### G2 - Lint

```bash
jq -r '.scripts.lint // empty' package.json   # prefer the project's own script
npm run lint            # or: pnpm lint / bun run lint - match the package manager
# fallback if no script but eslint config exists: npx eslint .
```
Exit criterion: exit 0. Missing linter binary = BLOCKED (PF-10), not skip.
Note: the PostToolUse hook `lint-check.sh` already self-lints `.ts/.tsx` (npx tsc)
and `.go` (golangci-lint, silently skipped when absent) on every Edit/Write, but it
only sees EDITED files - it is NOT a substitute for this full-project gate.

### G3 - Typecheck

```bash
npx tsc --noEmit        # from the nearest tsconfig.json directory; NEVER global tsc
```
Exit criterion: exit 0. No tsconfig.json anywhere = N/A (reason: not a TS project).

### G4 - CSS compile (CONDITIONAL)

Trigger: the working tree diff OR the push range touches `.css` / `.scss` / token
files:
```bash
{ git diff --name-only; git diff --name-only --cached; git diff --name-only "$UP..HEAD"; } | sort -u | grep -E '\.(css|scss)$'
```
If triggered, parse every touched CSS file with the same parser the dev server uses:
```bash
node -e "const p=require('postcss');const fs=require('fs');p.parse(fs.readFileSync('<file>','utf8'))"
```
Pre-check `node -e "require.resolve('postcss')"` from the project root; if postcss is
not resolvable, the project's real build (G6) becomes the CSS gate - record that in
evidence. Exit criterion: parse exits 0 for every touched file. Root-cause class from
the verified failure: `*/` inside a CSS comment (e.g. prose mentioning `bg-*/10`) -
reword the comment (memory `feedback_verify_css_changes_with_compile`).

### G5 - Tests

```bash
jq -r '.scripts.test // empty' package.json
npm test                # or npx vitest run / npx jest - whatever CI actually runs
```
Exit criterion: exit 0. A test script that is the npm placeholder
(`echo "Error: no test specified"`) = N/A (reason: no tests defined), and WARN if CI
runs a test job anyway. Missing runner = BLOCKED. Never `test.skip` your way to green
(PF-5).

### G6 - Build

```bash
npm run build           # or npx next build / stack equivalent from G1
```
`docker compose build` ONLY when CI actually builds images (from G1 parse).
Exit criterion: exit 0. PF-15 applies: Bash timeout 600000 or run_in_background +
poll; `free -h` first; if <2Gi available and a worker fleet is active, flag before
building (memory `reference_local_box_oom_heavy_workers`).

### G7 - Secrets (always, even with no CI)

```bash
UP=$(git rev-parse --abbrev-ref '@{upstream}')
gitleaks git --log-opts "$UP..HEAD" --no-banner --redact .     # unpushed range
gitleaks git --staged --pre-commit --no-banner --redact .      # staged + working tree
```
No upstream: `gitleaks git --log-opts "--branches --not --remotes" --no-banner
--redact .` plus `gitleaks dir . --no-banner --redact`.
Exit criterion: exit 0 (zero findings) on BOTH scans. Any finding = FAIL -> playbook
"secret-found" (`references/failure-playbooks.md`). PF-4: `--redact` always; report
file:line + rule id + commit hash, never the value. Scope to the push range for
speed; do NOT rescan full history every run. Gotcha (verified 2026-07-02): gitleaks'
default config allowlists canonical docs example keys (e.g. AWS's
AKIAIOSFODNN7EXAMPLE), so a clean scan does not prove example-looking strings were
scanned.

### G8 - Commit hygiene (always)

AI-trailer scan of every unpushed commit message (same line-anchored regex the
seal-guard hook uses):
```bash
git log "$UP..HEAD" --format='%H%n%B%n---' \
  | grep -iE '^[[:space:]]*Co-Authored-By:[[:space:]]*.*(claude|anthropic|noreply@anthropic)|^[[:space:]]*(🤖[[:space:]]*)?Generated with[[:space:]]+.*Claude Code'
```
Exit criterion: grep exits 1 (NO match). A match = FAIL -> playbook
"AI-trailer-found": list offending hashes (`git rev-list "$UP..HEAD"` then
`git log -1 --format=%B <sha>` per commit); history rewrite is USER-GATED (PF-9).
Conventional-format check is WARN only:
```bash
git log "$UP..HEAD" --format=%s | grep -vE '^(feat|fix|refactor|docs|chore|test|style|perf|ci|build)(\(.+\))?!?: ' || true
```

### G9 - Dependency safety (always for Node stacks; lockfile part per manager)

**(a) Compromised-dep denylist** (memory `feedback_axios_supply_chain`):
```bash
grep -n 'plain-crypto-js' <lockfile>                                   # ANY hit = FAIL
jq -r '.packages | to_entries[] | select(.key | endswith("node_modules/axios")) | .value.version' package-lock.json
grep -nE 'axios@(1\.14\.1|0\.30\.4)' pnpm-lock.yaml                    # pnpm form
grep -nE '"axios@(1\.14\.1|0\.30\.4)' bun.lock                         # bun form
```
FAIL if axios resolves to 1.14.1 or 0.30.4, or plain-crypto-js appears anywhere.

**(b) Lockfile sync** (all verified non-mutating, no node_modules written,
exit 0 in-sync / 1 drift - smoke-tested 2026-07-02):
```bash
npm ci --dry-run                                   # npm
pnpm install --frozen-lockfile --lockfile-only     # pnpm
bun install --frozen-lockfile --lockfile-only      # bun
```
yarn classic (1.x): `yarn install --frozen-lockfile` exists but ACTUALLY INSTALLS
(mutates node_modules) - flag that before running; there is no pure dry check.

**(c) Lockfile integrity:**
```bash
grep -nE '^(<{7} |={7}$|>{7} )' <lockfile>         # conflict markers = FAIL; regenerate, never hand-edit
ls package-lock.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb 2>/dev/null | wc -l   # >1 kind = FAIL
```

**(d) Range coherence (WARN):** `package.json` changed in `$UP..HEAD` with dependency
fields touched, but no lockfile changed in the same range -> WARN loudly: /commit
skips lockfiles by default, and CI's frozen install will hard-fail on the drift the
next `npm install` silently repaired locally. Fix via playbook "lockfile-drift".

---

## 3. Run Modes + Argument Grammar

| Invocation | Gates run |
|---|---|
| `/preflight` | Full ladder G0-G9. The only mode /ship accepts. |
| `/preflight lint` | G0 + G2 |
| `/preflight types` | G0 + G3 |
| `/preflight css` | G0 + G4 (forced on, even if diff detection would skip) |
| `/preflight test` | G0 + G5 |
| `/preflight build` | G0 + G6 |
| `/preflight secrets` | G0 + G7 |
| `/preflight trailers` | G0 + G8 |
| `/preflight deps` | G0 + G9 |
| `/preflight quick` | G0 + G2 + G3 + G7 + G8 + G9 (skips test/build) |

G0 always runs (everything depends on its context). `quick` is for mid-work
checkpoints ONLY - it is NEVER a substitute for the full ladder before a /ship push.
Single-gate runs report that gate's row plus the banner "PARTIAL RUN - not a
readiness verdict".

---

## 4. Fix Loop

When any gate FAILs:

1. **Show the error** (truncated to the key lines).
2. **Root cause analysis first - MANDATORY (PF-13).** Read the relevant source,
   trace the execution path, identify why the error exists. Fix where the error
   starts, not where it surfaces. No bandaids, no suppression, no swallowed errors,
   no gate-weakening (PF-5).
3. **Fix immediately** - edit the code directly, do not ask permission for ordinary
   code fixes. EXCEPTIONS that are USER-GATED, always: history rewrite (rebase /
   reword / amend of a multi-commit range), `.gitleaksignore` / `gitleaks:allow`
   additions, deleting or skipping tests, force-push of any kind.
4. **Commit the fix via /commit (PF-3).** If the fix touched a lockfile, explicitly
   tell /commit to stage the lockfile too.
5. **Re-run the ENTIRE ladder from G0 (PF-11)** in CI's order.
6. Loop within budget (PF-12): **max 3 attempts per distinct error signature, max 10
   total fix cycles, max 30 min wall clock.**

**On budget exhaustion, STOP and emit the stuck-report:**
```
STUCK - preflight fix budget exhausted
Gate:        G<N> <name>
Error:       <one-line signature>
Attempts:    <n> - (1) <approach + result> (2) ... (3) ...
Hypotheses:  <remaining theories, best first>
Needed:      <what would unblock: a decision, a credential, an upstream fix>
```
Do not silently keep grinding, and do not weaken the gate to escape the loop.

If ALL gates pass on the first run (no fixes needed): report READY, tell the user it
is safe to push (via /ship). If fixes were committed: report them in the gate table,
then the verdict.

---

## 5. Report Contract

Evidence, not claims: a gate row WITHOUT its command + exit code is invalid.

```
Preflight Report - <repo> @ <branch> (<N> unpushed commits, range <UP>..HEAD)
================================================================================
Gate                | Status  | Evidence                             | Fix commits
--------------------|---------|--------------------------------------|------------
G0 Context          | PASS    | npm via package-lock.json; UP=origin/main | -
G1 CI parse         | PASS    | 1 workflow fires on push->main       | -
G2 Lint             | PASS    | `npm run lint` exit 0                | -
G3 Typecheck        | PASS    | `npx tsc --noEmit` exit 0            | -
G4 CSS compile      | N/A     | no .css/.scss in diff or range       | -
G5 Tests            | PASS    | `npx vitest run` exit 0, 42 passed   | abc1234
G6 Build            | PASS    | `npm run build` exit 0 (312s)        | -
G7 Secrets          | PASS    | gitleaks range+staged exit 0, 0 leaks| -
G8 Commit hygiene   | PASS    | trailer grep exit 1 (no match)       | -
G9 Dependency safety| PASS    | axios 1.7.7 ok; npm ci --dry-run exit 0 | -
================================================================================
Known divergence (CI-only, cannot verify locally):
- CI node 22.3.0 vs local 22.16.0 (WARN)
- secrets.VPS_HOST et al only exist in CI
READY TO PUSH: YES        (computed: all applicable PASS, 0 BLOCKED)
```

Verdict line is COMPUTED per the rule in section 2, never judged. NOT READY must
name the vetoing gates. Report prose uses plain hyphens, never em/en dashes.

---

## 6. Failure-Mode Playbooks (index)

Full recovery recipes with exact commands: `references/failure-playbooks.md`.

| # | Playbook | One-line protocol |
|---|---|---|
| P1 | secret-found | Classify true/false positive by reading the flagged line (never echo the value). Staged-only: move to `~/.claude/secrets.env` pattern, re-scan. In an unpushed commit: history mutation = USER-GATED, surface hash + file + rule id and ask. Ever pushed before: rotation FIRST, then Christopher decides on scrub. False positive: allowlist only with user approval (PF-5). |
| P2 | AI-trailer-found | List offending hashes + matched lines. Single HEAD commit: offer message rewrite via the /commit path. Multi-commit range: present commits, WAIT for approval (2026-06-15 pi-setup scrub precedent). Never silently reword. |
| P3 | missing-tool (BLOCKED) | Report `command -v <tool>` empty + gate blocked + install hint. Expected absent on this box: go, golangci-lint, ruff, flake8, pytest, actionlint. Go/Python repos route here or through a project venv - never fake a pass. |
| P4 | lockfile-drift | Regenerate with the detected manager, stage BOTH package.json and lockfile (tell /commit explicitly), re-verify with the frozen check. Conflict markers: never hand-edit, regenerate. |
| P5 | css-compile-fail | Run the postcss parse one-liner for the exact line; commonest cause is `*/` inside a comment - reword it; re-run G4 then the full ladder. |
| P6 | ci-failed-after-push | BEFORE panic: (1) `curl -I https://<prod-url>/` (2) `gh run list -R <repo> --limit 5` for a LATER green run on the same SHA (3) `docker ps` freshness if SSH available. Later green on same SHA = historical noise, not a blocker. 90s of verification saves 90min (memory `feedback_verify_prod_before_ci_panic`). |
| P7 | long-build | Timeout 600000 or run_in_background + poll; `free -h` first; <2Gi free + active fleet = flag before building; never two heavy builds at once. |
| P8 | no-upstream-branch | `git rev-parse --abbrev-ref '@{upstream}'` fails: trailer range = `git log --branches --not --remotes`; secrets = same log-opts + `gitleaks dir .` + staged scan; note "first push of branch". |

DO / DON'T quick pairs:
- DO run gates in CI's order / DON'T reorder for convenience.
- DO fix source to satisfy tests / DON'T edit tests to pass (unless the test provably
  encodes outdated behavior - then fix it AND flag it in the report).
- DO detect the package manager from the lockfile / DON'T assume npm.
- DO use `npx tsc` / DON'T assume a global tsc.
- DO scope gitleaks to the push range / DON'T rescan full history every run.
- DO let lint-check.sh (PostToolUse) catch per-edit errors / DON'T treat it as G2/G3.

---

## 7. Verified Environment Facts (2026-07-02 - re-check with `command -v` on drift)

- **gitleaks 8.21.2** at `~/.local/bin/gitleaks`. Subcommands: completion, dir, git,
  help, stdin, version. There is NO `detect` subcommand. `gitleaks git` flags:
  `--log-opts <string>`, `--pre-commit`, `--staged`. `gitleaks dir` extra flag:
  `--follow-symlinks`. Global: `--exit-code` (default 1 on leaks), `--redact`,
  `--no-banner`, `--baseline-path`, `-c/--config` (precedence: flag > GITLEAKS_CONFIG
  > (target)/.gitleaks.toml), `--gitleaks-ignore-path`, `--max-target-megabytes`.
  Live-verified: range scan on a real 5-commit unpushed range exit 0; synthetic leak
  exit 1; clean dir exit 0; AWS docs example key allowlisted by default config.
- **Node toolchain:** node v22.16.0 (nvm), npm 10.9.2, pnpm 11.9.0, bun 1.3.12,
  yarn 1.22.22 (classic), eslint global. tsc NOT global - `npx tsc` per project.
- **NOT on PATH:** go, golangci-lint, ruff, flake8, pytest, actionlint, poetry,
  trivy, semgrep, osv-scanner. `uv` IS installed (`~/.local/bin/uv`). Go repos
  (tx-engine, go-rest-api, svi_backend, attn-agnostic) and Python repos
  (signal-trader, market-events, macro-news-scheduler) exist in
  `~/claude/Git/repositories` - they hit BLOCKED or project-local venvs.
- **Lockfile checks smoke-tested** (scratch projects, 2026-07-02): `npm ci --dry-run`
  exit 0 in-sync / 1 drift, no node_modules; `pnpm install --frozen-lockfile
  --lockfile-only` same; `bun install --frozen-lockfile --lockfile-only` same.
  yarn classic `--frozen-lockfile` exists but performs a real install.
- **Seal guard LIVE:** `~/.claude/hooks/block-raw-git-commit.sh` wired in
  settings.json PreToolUse(Bash). Denies raw `git commit` (bypass
  `CLAUDE_COMMIT_SKILL=1`, carried by /commit), denies `git merge` / `gh pr merge`
  (bypass `CLAUDE_MERGE_OK=1`), and ALWAYS denies (even with sentinel) messages
  matching the AI-trailer regex in G8. Read from hook source.
- **lint-check.sh (PostToolUse Edit|Write):** `.go` -> golangci-lint (exits silently
  when absent), `.ts/.tsx` -> `npx tsc --noEmit` from nearest tsconfig. Edited files
  only.
- **Box:** 18 logical CPUs, 14Gi RAM (~4Gi available at check time). OOM history with
  2+ concurrent heavy builds. Bash tool: 120s default timeout, 600s max,
  run_in_background available. docker 29.5.2, gh 2.67.0, jq at /usr/bin/jq.
- **Playwright MCP hook-banned** environment-wide (settings.json deny on
  `mcp__plugin_playwright_playwright__browser_.*`); browser work defers to
  /agent-browser.
- **axios compromised versions:** 1.14.1 and 0.30.4, malware dep
  `plain-crypto-js@4.2.1` (source: elpabl0 / @feross, 2026-03-31; re-check recency
  via socket.dev before ANY axios version change).
