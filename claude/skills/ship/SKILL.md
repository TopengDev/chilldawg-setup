---
name: ship
description: "The push + release pipeline: simplify, security review, e2e, version, commit, preflight, push, tag, CI watch. Use when the user says ship, push, or is done developing a feature. Bare push/ship/deploy verbs route here; server-side deploy MECHANICS do not - /deploy-landing owns aenoxa.com landing deploys, /oneshot-webapp owns pitch-demo deploys to <slug>.topengdev.com. /ship moves code through git + CI and never SSHes to the VPS."
argument-hint: [feature or branch description]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

# /ship - The Push + Release Pipeline

One command from "done coding" to "pushed, tagged, CI-confirmed". Ship is an
ORCHESTRATOR: it sequences /simplify, an inline security review, /e2e, /commit, and
/preflight, then owns the two things no sibling owns - the PUSH and the release tail
(changelog, annotated tag, CI watch, optional publish). It cites sibling skills'
internals instead of re-deriving them; duplicating their gate mechanics here would
create a second source of truth that drifts.

Pipeline order (S-3 - never skip, never reorder):

```
1 /simplify -> 2 security review -> 3 /e2e -> 4 version+changelog -> 5 README
-> 6 /commit -> 7 /preflight -> 8 PUSH -> 9 distribution tail
```

Steps 1-7 produce a provably-ready tree. Step 8 is the only irreversible moment.
Step 9 makes the release real and observable.

---

## 1. HARD RULES (S-1 .. S-15)

**S-1 - NEVER force push in any form** (`--force`, `--force-with-lease`). A push
rejected for any reason other than simple behind-remote (protected branch, server-side
hook, diverged history) -> STOP and ask the user; never retry with force. Behind-remote
is the ONLY self-recoverable rejection (playbook SP-1).

**S-2 - NEVER commit via raw `git commit` anywhere in the pipeline - ALWAYS the
/commit skill.** /commit carries the `CLAUDE_COMMIT_SKILL=1` sentinel; the seal-guard
PreToolUse hook (`~/.claude/hooks/block-raw-git-commit.sh`) denies raw commits AND
denies AI-attribution-trailer messages even WITH the sentinel; `git merge` /
`gh pr merge` need `CLAUDE_MERGE_OK=1`. Harness-default commit templates (Co-Authored-By
Claude etc.) do NOT apply in this environment - the hook actively blocks them. Cite:
memory `feedback_commit_skill_enforced`.

**S-3 - NEVER skip or reorder steps 1-8.** Each step ends in PASS or a recorded
N/A (with reason) before the next starts. FAIL or BLOCKED at any of steps 1-7 vetoes
the push - same semantics as preflight PF-2 (BLOCKED is never a pass).

**S-4 - NEVER push on a stale readiness verdict.** ANY commit entering the tree after
the last FULL /preflight run - a rebase pull, a delta-security fix, a changelog or
tag-prep commit - invalidates READY. Re-run /preflight (full ladder; `/preflight quick`
is NEVER a pre-push substitute, per preflight section 3) before pushing.

**S-5 - NEVER trust `gh run watch --exit-status`'s exit code as the CI verdict.** It
falsely exited 0 on a transient HTTP 401 while the run was still resolving (verified
2026-06-16, memory `reference_gh_run_watch_exit_code`). ALWAYS re-confirm with
`gh run view <id> --json conclusion,status` and treat ONLY `conclusion == "success"`
as PASS. Anything else is IN PROGRESS or FAIL.

**S-6 - ALWAYS resolve the CI run by the pushed commit's SHA** -
`gh run list --commit "$(git rev-parse HEAD)" --json databaseId,status,conclusion,url`
(the `-c/--commit` filter is verified in gh 2.67.0). NEVER `--limit 1` alone: the
newest run can belong to a DIFFERENT commit (another push, a schedule, a parallel
workflow), and you end up watching the wrong run.

**S-7 - ALWAYS run deploy-on-push detection BEFORE Step 8** (parse
`.github/workflows/` for deploy/ssh/docker-push jobs firing on this branch; reuse
preflight G1's parse when fresh - recipe R5). If the push auto-deploys prod during
active hours (~08:00-18:00 WIB weekdays): flag the timing risk and offer off-peak
BEFORE pushing (memory `feedback-prod-deploy-timing`, Toper 2026-06-02: "salah nih
deploy siang2"). Urgent live-outage fixes override. When detection is uncertain and
the repo is a known prod app, ROUND UP: treat it as deploy-on-push. A user-chosen
scheduled push REQUIRES an immediate CronCreate/ScheduleWakeup (memory
`feedback_time_promise_scheduling`) - a promise without a trigger silently dies.

**S-8 - Tags are ALWAYS annotated** (`git tag -a`), NEVER lightweight. NEVER overwrite
or delete an existing tag - `git tag -l v{V}` hit means report and skip (SP-6).

**S-9 - When /ship is DELEGATED to a worker, the brief MUST bake in the push gate from
the start:** "run steps 1-7, STOP before Step 8, report SHAs, wait for the explicit
go" - unless push is explicitly pre-authorized in the brief. Mid-flight overrides lose
the race: verified 2026-05-30, a worker racing at ~30s/repo pushed 3 of 4 repos before
BOTH attn and tmux holds landed (memory `feedback_gate_irreversible_in_brief`). And
NEVER ask a sub-agent to push/deploy on relayed or coordinator-"owned" authorization -
it will correctly refuse (verified twice 2026-07-01, memory
`feedback_subagent_relayed_authorization_wall`). The push executes in the session
holding FIRST-HAND authorization (main), or on the user's direct message to the worker.

**S-10 - A CI FAIL after push does NOT un-ship and is NEVER silently swallowed.**
ALWAYS run the ground-truth ladder FIRST (curl prod, later-green-run check on the SAME
SHA, docker ps if SSH available - preflight playbook P6, memory
`feedback_verify_prod_before_ci_panic`: 90s of verification saves 90min of misframed
planning). Classify historical-noise vs real, then surface loudly in the Final Report
either way (SP-5).

**S-11 - ALWAYS bound loops.** Ship-owned fix attempts: max 3 per distinct error
signature. CI watch: bounded (default 10 min), then report IN PROGRESS and optionally
ScheduleWakeup a follow-up check - never hang. When a sub-skill emits its stuck-report
(preflight section 4, e2e FP-6 dossier), STOP the entire pipeline and escalate with
that report attached - NEVER re-invoke the sub-skill hoping for a different result,
NEVER weaken its gate to pass (SP-8).

**S-12 - Package publishing (npm/brew) is OFF by default.** Only with the user's
explicit confirmation IN THIS RUN and pre-configured credentials. NEVER invent or
prompt for registry credentials. Not configured = "publish skipped (not configured)".

**S-13 - ALWAYS sync the lockfile after a manifest version bump, and explicitly tell
/commit to stage BOTH manifest and lockfile** (/commit skips lockfiles by default -
its "DO NOT stage" list). npm recipe: `npm version <type> --no-git-tag-version`
(updates package.json + package-lock.json, creates no commit or tag - the DEFAULT
`npm version` creates a raw commit that violates S-2); resync fallback
`npm install --package-lock-only`. Both flags verified 2026-07-03 on npm 10.9.2.
Other managers: recipe R1. A half-shipped bump fails ship's own step 7 (preflight
G9b frozen check / G9d range-coherence WARN).

**S-14 - ALWAYS record the HEAD SHA when Step 2's security review completes**
(`SEC_SHA`). Before Step 8, if `git log $SEC_SHA..HEAD` is non-empty, run a delta
security review on `git diff $SEC_SHA..HEAD` with the same criteria (recipe R6).
Fix commits from the /e2e and /preflight loops are written under time pressure - the
highest-risk commits in the pipeline must not ship unreviewed.

**S-15 - NEVER print or write a secret value in any report or log** (mirror preflight
PF-4: file:line + pattern type only). Final Report prose uses plain hyphens - never
em/en dashes (house rule, mirrors preflight section 5).

---

## 2. Boundary Charter - who does what

Trigger routing: bare "push" / "ship" / "deploy" verbs route to **/ship** (consistent
with preflight section 1). But deploy MECHANICS on a server are not ship's: "deploy
the landing to the VPS" is /deploy-landing; "build+deploy the pitch demo" is
/oneshot-webapp. Rule of thumb: **/ship moves code through git + CI; skills that own
SSH/nginx/certbot mechanics do server deploys. /ship never SSHes to the VPS.**

| Skill | It owns | Ship's relationship |
|---|---|---|
| **/preflight** | "Will CI pass?" - local CI-parity gates G0-G9, computed READY/NOT READY, NEVER pushes (its PF-1) | Ship invokes it at step 7 and consumes its gate table into the Final Report. |
| **/commit** | Staging + message + conventional format + `CLAUDE_COMMIT_SKILL=1` sentinel, no AI attribution | Ship's only commit path (S-2). CAVEAT: does NOT stage lockfiles by default - always tell it explicitly (S-13). |
| **/e2e** | ONE feature's full user-flow verification, fix-until-green, commits its own fixes via /commit (its E-15) | Ship step 3. Verdicts: ALL PASS / PASS WITH FLAGS / FAIL (its section 5.2) - mapped in step 3's table. |
| **/simplify** | Quality-only cleanup (reuse, simplification, efficiency), applies fixes | Ship step 1. Not a bug hunt. |
| **/security-review** | Judgment review of the diff for exploitable vulns | Ship step 2 runs this review inline. Preflight's security surface is mechanical only (gitleaks/denylist/lockfile) - logic vulns are covered HERE. |
| **/verify** | Single-change behavioral verification | Per-change depth during development; ship is the per-release pipeline. |
| **/deploy-landing** | VPS deploys of already-built landings (static or standalone) to *-landing-page.aenoxa.com (tar-over-ssh/nginx/certbot mechanics) | Server deploy verbs with a landing target route THERE, not here. |
| **/oneshot-webapp** | Pitch-demo build+deploy to <slug>.topengdev.com (docker/nginx/certbot) | Same - it owns its own deploy tail. |
| **/ideate** | Idea -> gated build orchestration | Calls /ship at its Phase 7 as the deploy step. |

---

## 3. Pipeline Ladder - per-step status contract

Every step ends in exactly one status, recorded in the run ledger as it happens:

| Status | Definition |
|---|---|
| **PASS** | Step ran, exit criterion met, evidence recorded. |
| **FAIL** | Step ran, criterion not met, fix budget exhausted (S-11). |
| **N/A** | Step does not apply; the reason is recorded (e.g. "no CHANGELOG.md"). |
| **BLOCKED** | Step could not run (sub-skill stuck-report, missing tool, no authorization). |

**FAIL or BLOCKED at steps 1-7 mechanically vetoes Step 8** - the run ends ABORTED,
naming the vetoing step. N/A never vetoes.

**Before Step 1 - context (30 seconds):** `git rev-parse --is-inside-work-tree`;
`git branch --show-current` (empty = detached HEAD -> SP-2, stop);
`git status --porcelain` (dirty state); `git log @{u}..HEAD --oneline 2>/dev/null`
(pre-existing unpushed commits); note whether this session is main or a delegated
worker (section 4 applies if worker).

### Step 1: Simplify (auto-fix)

Invoke the `/simplify` skill. This will review changed code for reuse, quality, and
efficiency, then auto-fix issues found. Wait for simplify to complete before
proceeding.

Exit criterion: /simplify returned and its changes are in the working tree (they get
security-reviewed in step 2 and committed in step 6). N/A if there are no code
changes to review (push-only ship of pre-existing commits).

### Step 2: Security Review (interactive; inline - never delegated)

Review scope: `git diff HEAD` (all uncommitted changes) AND, when an upstream exists
and the unpushed range is non-empty, `git diff @{u}..HEAD` (commits already made but
never pushed - they enter the push range too). Analyze as a senior security engineer.

Run this review INLINE in the current session - never delegate it to a sub-agent
(Fable 5's upstream classifier reroutes security-framed prompts; memory
`feedback_fable5_dualuse_reroute_gate`).

**Only flag issues with >80% confidence of real exploitability.**

**Check for:**
- Input Validation: SQL injection, command injection, XXE, path traversal, template injection
- Auth & Authorization: authentication bypass, privilege escalation, session flaws
- Crypto & Secrets: hardcoded API keys/passwords/tokens, weak crypto
- Injection & Code Execution: XSS, unsafe eval, prototype pollution, deserialization

**Do NOT report:**
- Denial of Service vulnerabilities
- Secrets stored on disk
- Rate limiting or resource exhaustion
- Pre-existing issues (only flag what's NEW in the diff)
- Theoretical issues with low practical impact

**If findings exist:** Present each with severity, file/line, description, and fix.
Ask: "Which findings should I fix? (all / none / comma-separated numbers)". Fix
selected findings. (Unattended: defaults matrix, section 4.)

**If no findings:** Print "Security review: clean" and proceed.

**On completion, record the delta anchor (S-14):** `SEC_SHA=$(git rev-parse HEAD)`.

Exit criterion: review ran over the full scope; findings fixed or explicitly declined
by the user; SEC_SHA recorded.

### Step 3: E2E Test

Invoke the `/e2e` skill with $ARGUMENTS as the feature context.

If `/e2e` finds and fixes issues, it will commit those fixes automatically.

/e2e returns a three-way verdict (its section 5.2). Map it mechanically:

| /e2e verdict | Ship's action |
|---|---|
| **ALL PASS** | Proceed to step 4. |
| **PASS WITH FLAGS** | Enumerate the flags (FLAKY / NOT_VERIFIED steps, console findings). Interactive: proceed only with the user's ack. Unattended: proceed iff zero FAIL and no security-adjacent flags; carry ALL flags into the Final Report either way. |
| **FAIL** | Pipeline BLOCKED at step 3 - attach /e2e's FP-6 dossier, run ends ABORTED (S-11: never re-invoke hoping for different results). |

Exit criterion: verdict is ALL PASS, or PASS WITH FLAGS with the proceed condition
met and flags carried forward.

### Step 4: Version & Changelog (conditional)

**Detection:** Check for `CHANGELOG.md` in project root.

**If no CHANGELOG.md:** N/A - skip this step entirely.

**If CHANGELOG.md exists:**

1. Read current version from `package.json`, `Cargo.toml`, or `pyproject.toml`
2. Suggest bump type based on changes:
   - Bug fixes -> `patch`
   - New features -> `minor`
   - Breaking changes -> `major`
3. Ask user: `Release: current v{version}. Bump? (patch -> {x} / minor -> {x} / major -> {x} / skip)`
   (Unattended: default SKIP unless the bump was pre-authorized in the brief - section 4.)
4. If user picks a bump - **use the lockfile-safe recipe (S-13, full per-manager
   table in recipe R1):**
   - npm: `npm version <type> --no-git-tag-version` - updates package.json AND
     package-lock.json, no commit, no tag. NEVER bare `npm version <type>` (it
     creates a raw commit + lightweight-tag flow that violates S-2/S-8).
   - pnpm / bun / yarn / cargo / pyproject: manual manifest edit + the manager's
     lockfile resync (R1), then verify sync with the same frozen check preflight
     G9b runs.
   - Insert new section in CHANGELOG.md (Keep a Changelog format):
     ```
     ## [{VERSION}] - {YYYY-MM-DD}

     ### {Category}

     - {description from actual code changes}
     ```
   - Append release link to bottom of CHANGELOG.md
5. If user says "skip": proceed without versioning

Exit criterion: version bumped with manifest AND lockfile in sync (or skipped/N-A,
recorded).

### Step 5: README Update (conditional, auto)

**If no README.md:** N/A - skip.

**If README.md exists:** Review code changes and determine if they affect documented
content (new features, changed CLI flags, updated usage, removed functionality,
changed API).

- If changes affect docs: update relevant sections, keep existing style
- If no doc impact: skip silently (record N/A - no doc impact)

### Step 6: Commit

Invoke the `/commit` skill to commit all current changes (including version bump,
changelog, README updates from steps 4-5).

**If step 4 bumped the version: explicitly instruct /commit to stage BOTH the
manifest and the lockfile** (S-13 - /commit will otherwise leave the lockfile
unstaged and step 7's G9 catches the drift the hard way).

If there are no unstaged/untracked changes, skip this step (N/A).

Exit criterion: working tree clean (`git status --porcelain` empty except
deliberately-ignored dirt), commit hash recorded.

### Step 7: Preflight CI/CD

Invoke the `/preflight` skill to run all CI/CD checks locally.

If `/preflight` finds and fixes issues, it will commit those fixes automatically.

Do NOT proceed until `/preflight` reports all checks passing.

**Additionally (additive to the contract):** capture the returned G0-G9 gate table -
it embeds verbatim in the Final Report (section 5). If preflight emits its
stuck-report instead of READY -> SP-8, run ends ABORTED with the stuck-report
forwarded.

Exit criterion: preflight verdict READY, gate table captured.

### Step 8: Push (the irreversible moment)

**Pre-push checklist - ALL boxes checked before `git push` runs:**

- [ ] **1. Verdict fresh (S-4):** zero commits entered the tree after the last full
      /preflight. Any did (delta-security fix, changelog commit, rebase pull) ->
      re-run /preflight first.
- [ ] **2. Deploy-on-push detection done + timing gate resolved (S-7):** workflows
      parsed (R5); if push auto-deploys prod in active hours, the user chose
      go-now / off-peak (scheduled = CronCreate/ScheduleWakeup SET) / hold.
      Uncertain + known prod app = treat as deploy-on-push.
- [ ] **3. Delta security pass clean or N/A (S-14):** `git log $SEC_SHA..HEAD` empty,
      OR the delta diff reviewed with step 2's criteria (R6).
- [ ] **4. Branch resolved:** `git branch --show-current` non-empty (empty ->
      SP-2, stop - never guess a target branch).
- [ ] **5. Push authorization verified (S-9):** running in main with the user's ask,
      OR the delegating brief explicitly pre-authorized the push, OR the user's
      direct go landed in THIS session. A relayed "main says push" does not count.

Then:

1. Push: `git push -u origin <branch>`
2. If rejected as behind-remote: playbook SP-1 - `git pull --rebase origin <branch>`,
   then **re-run /preflight (S-4: the rebase merged commits the gates never saw)**,
   then push again. Rebase conflict -> SP-3 (abort, report, ask - never hand-resolve
   and force).
3. Rejected for ANY other reason (protected branch, server hook, diverged history) ->
   S-1: STOP and ask. Never force.
4. Confirm the push landed: `git rev-parse @{u}` == `git rev-parse HEAD`.

> Tagging moved to Step 9 (Distribution Tail) so the tag is annotated and created
> only after the push lands.

Exit criterion: remote-tracking ref equals local HEAD (evidence: both SHAs).

### Step 9: Distribution Tail (post-push)

Runs AFTER the push succeeds. This is the "make the release real and observable"
stage. Each sub-step is conditional - skip silently when it doesn't apply (record
N/A), never block the ship on an optional step.

**(a) Changelog refresh from commits**

- If `CHANGELOG.md` was already updated in Step 4, skip - it's current.
- If there is NO `CHANGELOG.md` and the project looks like a release artifact (has a
  version manifest: `package.json` / `Cargo.toml` / `pyproject.toml`), offer to
  generate one from the git history:
  - `git log --pretty=format:'%s' {LAST_TAG}..HEAD` (or full history if no prior
    tag), grouped into Added / Changed / Fixed by conventional-commit prefix
    (`feat:` -> Added, `fix:` -> Fixed, else Changed). Full recipe: R2.
  - Write a Keep-a-Changelog `## [{VERSION}] - {YYYY-MM-DD}` section. Commit it via
    `/commit` and re-push. (This commit post-dates the CI run being watched in (c) -
    resolve runs per-SHA (S-6), and note the extra push in the report.)
- If the project is not a release artifact (no manifest), skip silently - most of
  Christopher's repos are apps/configs, not published packages.

**(b) Annotated semver tag**

- Only when a version exists/was bumped (Step 4) OR the user explicitly asks to tag.
- Resolve `{VERSION}` from the manifest. Confirm it isn't already tagged:
  `git tag -l v{VERSION}` - a hit = SP-6: report and skip, NEVER overwrite or delete
  (S-8).
- Create an **annotated** tag (carries tagger, date, message - unlike a lightweight
  tag): `git tag -a v{VERSION} -m "Release v{VERSION}"` (append a one-line summary
  of headline changes if available).
- Push it: `git push origin v{VERSION}`.

**(c) Watch CI after push - the verified block**

- Only if the repo has a GitHub remote and `.github/workflows/` exists and `gh` is
  authenticated (`command -v gh` + `gh auth status` - missing/unauthenticated ->
  SP-7, report N/A with the hint).
- The single verified sequence (full annotated version: R4):

  ```bash
  SHA=$(git rev-parse HEAD)
  # 1. Resolve the run FOR THIS SHA (S-6) - retry up to 60s for registration lag
  RUN_ID=$(gh run list --commit "$SHA" --json databaseId -q '.[0].databaseId')
  # (empty after 60s of retries -> SP-4: report IN PROGRESS/N-A, not a failure)
  # 2. Watch, bounded ~10 min (S-11) - the exit code is NOT the verdict
  gh run watch "$RUN_ID" --exit-status
  # 3. MANDATORY re-confirmation (S-5) - this JSON is the only truth
  gh run view "$RUN_ID" --json conclusion,status
  ```

- PASS **only** on `conclusion == "success"`. `status != "completed"` = IN PROGRESS
  (optionally ScheduleWakeup a follow-up check; never hang). Any other conclusion =
  FAIL -> SP-5 ground-truth ladder BEFORE panic (S-10).
- Report the outcome: **PASS** / **FAIL** (with the failing job + a link via
  `gh run view --web`) / **IN PROGRESS** / **N/A** (no CI) - each with the
  conclusion/status JSON as evidence.
- A CI **FAIL** does not un-ship the push (it's already pushed) - surface it loudly
  in the Final Report so the user can act (S-10).

**(d) Publish to package registries - OPTIONAL / DEFERRED**

> Christopher does not currently publish CLI packages. Treat this whole sub-step as
> OFF by default (S-12). Only run it if the project clearly publishes a package AND
> the user explicitly confirms in this run.

If this project publishes a CLI / library:
- **npm:** `npm publish` (verify `package.json` `name`/`version`/`files`/`bin`,
  `npm whoami`, 2FA OTP if enabled; `--access public` for scoped first publish).
- **Homebrew tap:** bump the formula in the tap repo - update `url` to the new
  release tarball + recompute `sha256` (`shasum -a 256`), commit + push to the tap.
- Both require credentials/auth set up first - if not configured, report "publish
  skipped (not configured)" and move on. Never invent registry credentials (S-12).

---

## 4. Delegated & Unattended Runs

### Delegated (/ship inside a worker session)

- The push gate lives in the BRIEF, not in a mid-flight override (S-9). Default
  delegated shape: **"run /ship steps 1-7, STOP before Step 8, report the commit
  SHAs + preflight verdict, wait for the explicit go."** Verified race 2026-05-30:
  3 of 4 repos were pushed before both attn and tmux overrides landed.
- The worker pushes ONLY if (a) the brief explicitly pre-authorized the push, or
  (b) the user's own direct message lands in the worker's session. A coordinator
  relay ("Christopher approved") or coordinator-"owned" instruction will be - and
  should be - refused (memory `feedback_subagent_relayed_authorization_wall`,
  verified twice 2026-07-01). Don't burn round-trips on it: route the push to main
  or to the user's direct go.
- Workers report completion per house protocol (attn + STATE.md); the staged-and-
  holding state is a normal, successful worker outcome - not a failure.

### Unattended defaults matrix (autonomous loop / no user at the prompt)

| Interactive point | Unattended default |
|---|---|
| Step 2 findings prompt | Fix ALL findings with clear exploitability (High+), report the rest in the Final Report. Never silently drop a finding. |
| Step 3 PASS WITH FLAGS | Proceed iff zero FAIL and no security-adjacent flags; carry flags into the report. |
| Step 4 bump prompt | SKIP unless the bump was pre-authorized in the brief. |
| S-7 timing gate on a business-hours prod-deploy push | **Human-gated HOLD** - complete steps 1-7, stage everything, do NOT push (autonomous-loop hard rule: destructive/external work is human-gated). Surface for the user's go. |
| Step 9(d) publish | Always skipped (S-12 requires explicit confirmation in-run). |

---

## 5. Final Report - computed verdict + evidence

**Verdict is COMPUTED, never judged:**

- **SHIPPED** iff steps 1-8 all PASS/N-A AND the push is confirmed on the remote
  (`git rev-parse @{u}` == local HEAD) AND no flags below apply.
- **SHIPPED WITH FLAGS** iff pushed, but any of: CI FAIL or IN PROGRESS; e2e
  PASS WITH FLAGS carried; timing gate overridden (pushed in active hours on a
  deploy-on-push repo); tag skipped (already exists).
- **ABORTED** otherwise - name the vetoing step and attach its evidence
  (stuck-report / dossier / rejection message).

Anti-slop discipline: **every report line carries its artifact** - commit SHAs, exit
codes, the run URL + conclusion JSON, the tag name. "Remote CI: PASS" without the
conclusion JSON is an INVALID report row (mirror of preflight's "a gate row without
evidence is invalid"). Prose uses plain hyphens, never em/en dashes (S-15).

```
Ship Summary
============
Verdict:      SHIPPED / SHIPPED WITH FLAGS (list) / ABORTED at step N
Feature:      [what was shipped]
Branch:       [branch name]
Security:     CLEAN / {N} findings fixed / declined: {list}   (SEC_SHA {sha}, delta pass: clean/N-A)
E2E Tests:    ALL PASS / PASS WITH FLAGS ({flags}) / FAIL     (evidence: {$EVID path})
Version:      v{version} (if bumped, lockfile synced) / unchanged
Commits:      [hashes + messages, including e2e/preflight fix commits]
Preflight:    READY - gate table below
Deploy-on-push: yes/no ({workflow file}) - timing: {off-peak | user go | n/a}
Pushed:       YES ({local sha} == {remote sha}) / HELD (staged, awaiting go) / NO
Tagged:       v{version} annotated / skipped-exists / none
Changelog:    updated / generated / n/a
Remote CI:    PASS / FAIL ({job} - {url}) / IN PROGRESS / N/A   (conclusion JSON: {...})
Published:    npm + brew / skipped (deferred) / n/a
============
[preflight G0-G9 gate table, embedded verbatim from step 7]
```

---

## 6. Failure Playbooks + Do/Don't

One-line protocols here; exact command sequences in `references/ship-recipes.md`.

| # | Playbook | One-line protocol |
|---|---|---|
| SP-1 | push rejected: behind-remote | `git pull --rebase origin <branch>` -> S-4 re-gate (full /preflight) -> push. ANY other rejection -> stop and ask (S-1). |
| SP-2 | detached HEAD / empty branch name | STOP, show `git status`, ask for the target branch - never guess, never push a detached HEAD. |
| SP-3 | rebase conflict | `git rebase --abort` IMMEDIATELY, report the conflicting files, ask. Never hand-resolve + force; raw `git commit` mid-conflict is hook-blocked anyway (S-2). |
| SP-4 | CI run not found for pushed SHA | Retry the `--commit`-filtered lookup for 60s (registration lag), then dump `gh run list --json headSha,status,url` into the report as IN PROGRESS/N-A. Not a pipeline failure. |
| SP-5 | CI FAIL after push | Ground-truth ladder BEFORE panic: (1) `curl -I https://<prod-url>/` (2) later GREEN run on the SAME SHA (`gh run list --commit $SHA --json conclusion,status,url`) (3) `docker ps` freshness if SSH available. Cite preflight P6. Classify historical-noise vs real; report loudly either way (S-10). |
| SP-6 | tag already exists | `git tag -l v{V}` hit -> report + skip. Never delete/retag (S-8). |
| SP-7 | gh missing / unauthenticated | `command -v gh` / `gh auth status` fail -> CI watch = N/A with the install/auth hint. The rest of the tail still runs. |
| SP-8 | sub-skill stuck-report received | ABORT the pipeline, forward the stuck-report/dossier VERBATIM, list exactly what remains unshipped. Never re-invoke, never weaken (S-11). |

| DO | DON'T |
|---|---|
| Resolve CI runs by the pushed SHA (`--commit`) (S-6) | Trust `--limit 1` - it can watch a different commit's run |
| Re-confirm with `gh run view --json conclusion,status` (S-5) | Trust `gh run watch --exit-status`'s exit code (verified false green) |
| Re-run full /preflight after ANY rebase or late commit (S-4) | Push a merged/patched tree on the old READY verdict |
| Tell /commit to stage manifest + lockfile together (S-13) | Let the version bump ship half and fail G9b |
| Offer off-peak for prod-deploy pushes in active hours (S-7) | Deploy siang-siang silently |
| Bake stage-and-hold into delegated briefs (S-9) | Rely on a mid-flight "don't push" override landing in time |
| Ground-truth prod before escalating a CI FAIL (S-10) | 90 min of misframed planning over historical noise |
| Cite preflight/e2e section numbers for their internals | Re-derive gitleaks/gate/browser mechanics inside ship |
| Annotated tags, skip-if-exists (S-8) | Lightweight tags, retagging, tag deletion |
| Stop and ask on any non-behind-remote rejection (S-1) | `--force`/`--force-with-lease` retries |

---

## 7. Verified Environment Facts (2026-07-03 - re-verify with `--help` on drift)

- **gh 2.67.0** at `~/.local/bin/gh`. `gh run watch` flags: `--exit-status`,
  `-i/--interval` only. `gh run list` supports `-c/--commit SHA`, `-b/--branch`,
  `-L/--limit`, `-w/--workflow`, `--json` (fields incl. databaseId, headSha, status,
  conclusion, url). `gh run view --json` exposes conclusion, status, jobs, url, etc.
- **git 2.54.0** (`git tag -a` = annotated). **jq** at `/usr/bin/jq`.
- **npm 10.9.2:** `npm version <type> --no-git-tag-version` updates package.json AND
  package-lock.json with no commit/tag; `npm install --package-lock-only` exists.
  **pnpm 11.9.0 / bun 1.3.12:** both have `--lockfile-only` and `--frozen-lockfile`.
  (All flag-verified 2026-07-03 via `--help`.)
- **Seal-guard hook LIVE** at `~/.claude/hooks/block-raw-git-commit.sh`, wired in
  settings.json PreToolUse(Bash): denies raw `git commit` (bypass
  `CLAUDE_COMMIT_SKILL=1`, carried by /commit), denies `git merge`/`gh pr merge`
  (bypass `CLAUDE_MERGE_OK=1`), ALWAYS denies AI-attribution trailers even with the
  sentinel. `git push` is NOT gated by any hook - ship's own checklist is the only
  gate at the push boundary.
- **gitleaks 8.21.2** exists but is PREFLIGHT's tool (its G7/PF-8) - ship never
  duplicates secret scanning.
- **Playwright MCP is hook-banned** environment-wide; ship never touches browsers -
  /e2e owns that via /agent-browser.
- Sibling contracts consumed here: `/preflight` SKILL.md (sections 1-7, playbook P6),
  `/e2e` SKILL.md (sections 5.2, 6.2, FP-6), `/commit` SKILL.md (staging rules).
- Memories encoded (cite, don't re-learn): `reference_gh_run_watch_exit_code`,
  `feedback-prod-deploy-timing`, `feedback_time_promise_scheduling`,
  `feedback_gate_irreversible_in_brief`, `feedback_subagent_relayed_authorization_wall`,
  `feedback_verify_prod_before_ci_panic`, `feedback_commit_skill_enforced`,
  `feedback_fable5_dualuse_reroute_gate`.

## 8. References

- `references/ship-recipes.md` - R1 version bump per manager, R2 changelog from
  commits, R3 annotated tag, R4 full CI watch block with retry/bounds, R5
  deploy-on-push detection, R6 delta security pass, R7 SP-1..SP-8 full command
  sequences.
