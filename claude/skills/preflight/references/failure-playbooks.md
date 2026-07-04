# Preflight Failure-Mode Playbooks - full recipes

Companion to `../SKILL.md` section 6. Each playbook: symptom, exact recovery
commands, and the USER-GATED points marked. Hard rules PF-1..PF-15 apply throughout;
the ones each playbook leans on are cited inline.

---

## P1 - secret-found (G7 FAIL)

gitleaks exited 1. NEVER echo the matched value (PF-4); `--redact` keeps it out of
tool output, keep it out of your prose too. Report pattern TYPE + file:line +
rule id + commit hash only.

1. **Classify.** Read the flagged line yourself (Read tool, the one place the raw
   value legitimately passes through your context - it still never goes into output).
   True secret, or a false positive (test fixture, docs example, high-entropy
   non-secret)? Note: gitleaks' default config already allowlists canonical docs
   example keys, so a hit usually means something real.
2. **True + only staged/working tree (not yet committed):** remove it from the tree.
   Correct destinations: env injection at runtime, or the `~/.claude/secrets.env`
   pattern (sourced by the shell profile). Ensure `.env*` is gitignored. Re-run BOTH
   G7 scans; the staged scan must go 0 findings.
3. **True + inside an unpushed commit:** the tree fix alone does NOT clean the range;
   the secret lives in the commit object. Removing it requires history mutation
   (rebase / reword / drop), which is **USER-GATED** - surface commit hash + file +
   rule id, propose the minimal rewrite, and WAIT. Never auto-rebase (PF-9's
   history-mutation rule applies to secrets too).
4. **True + was EVER pushed previously** (check: does the secret also appear in
   commits reachable from any remote ref? `git log --remotes -S'<file path>' --oneline`
   on the FILE, not the value): escalate. Rotation comes FIRST (a pushed secret is
   burned regardless of scrubbing), then the history-scrub + force-push decision is
   Christopher's, per the standing human-gated rule for history scrubs of public
   repos.
5. **False positive:** `.gitleaksignore` entries or inline `gitleaks:allow` comments
   ONLY with explicit user approval recorded in the report (PF-5). Present the
   file:line + rule id + why it is not a secret, and wait.

---

## P2 - AI-trailer-found (G8 FAIL)

The range scan matched `Co-Authored-By: ...Claude/Anthropic...` or
`Generated with ... Claude Code` in an unpushed commit message.

1. **Identify every offender:**
   ```bash
   for sha in $(git rev-list "$UP..HEAD"); do
     git log -1 --format=%B "$sha" \
       | grep -qiE '^[[:space:]]*Co-Authored-By:[[:space:]]*.*(claude|anthropic|noreply@anthropic)|^[[:space:]]*(🤖[[:space:]]*)?Generated with[[:space:]]+.*Claude Code' \
       && echo "$sha"
   done
   ```
2. **Single offender and it is HEAD:** offer a message rewrite. The mechanical fix is
   `git commit --amend`, which the seal guard blocks raw - and the hook ALWAYS
   denies a message still carrying the trailer, sentinel or not. Route the rewrite
   through the /commit path / ask Christopher for the amend authorization. Do not
   improvise a bypass.
3. **Multiple commits, or the offender is not HEAD:** fixing means an interactive-
   rebase-equivalent over the range = history mutation = **USER-GATED** (PF-9).
   Present the exact commit list + matched lines and WAIT for approval. Never
   silently reword a range.
4. **Precedent to cite:** 2026-06-15, 32 AI-attributed commits reached pi-setup via
   a non-hooked commit path; recovery required a full history scrub + force-push
   (rollback bundle kept). G8 exists so preflight catches this BEFORE the push,
   where the fix is still cheap (memory `feedback_commit_skill_enforced`).
5. Commits from OTHER tools/hosts/sessions are exactly the expected source: the
   seal-guard hook only covers this harness. Never assume "the hook would have
   caught it".

---

## P3 - missing-tool (gate BLOCKED)

`command -v <tool>` came back empty for a gate's required binary.

1. Record BLOCKED with: the empty `command -v` evidence, which gate it blocks, and
   the install hint. BLOCKED vetoes READY (PF-2) - never silent-skip, never fake.
2. Expected-absent on this box (verified 2026-07-02, always re-check): go,
   golangci-lint, ruff, flake8, pytest, actionlint, poetry, trivy, semgrep,
   osv-scanner. Also: tsc is not global (use `npx tsc`).
3. Before declaring BLOCKED on a Python repo, walk the venv ladder
   (`ci-recipes.md` section 3): `.venv/bin/<tool>` then `uv run <tool>` then poetry.
   A repo-local tool that resolves = not BLOCKED.
4. Before declaring BLOCKED on a Node repo, try the `npx` form - most Node tooling
   resolves from the project's own node_modules.
5. Installing a missing GLOBAL toolchain is a system mutation - propose it, do not
   just do it mid-preflight. Installing project-local devDependencies the project
   already declares (`npm install` to materialize node_modules) is fine, but note it
   in the report and re-run G9b afterwards.

---

## P4 - lockfile-drift (G9b FAIL)

The frozen check failed: lockfile out of sync with package.json. This is THE top
"passes locally, fails in CI" cause, and /commit's default lockfile exclusion makes
it easy to ship package.json without its lockfile.

1. **Regenerate with the DETECTED manager** (never a different one):
   ```bash
   npm install               # npm - rewrites package-lock.json
   pnpm install              # pnpm - rewrites pnpm-lock.yaml
   bun install               # bun - rewrites bun.lock
   ```
2. **Re-verify** with the frozen check (`npm ci --dry-run` etc.) - must exit 0 now.
3. **Commit BOTH files.** Tell /commit EXPLICITLY to stage the lockfile alongside
   package.json - its default policy is "Lock files unless the user explicitly
   asks", so an unmentioned lockfile gets left behind and the drift ships anyway.
4. **Conflict markers inside a lockfile** (`^<<<<<<< ` / `^=======$` / `^>>>>>>> `):
   NEVER hand-edit a lockfile. Take the package.json resolution as truth and
   regenerate the lockfile from it, then steps 2-3.
5. **package.json changed in range, lockfile did not (the G9d WARN):** confirm the
   change touched dependency fields (`git diff "$UP..HEAD" -- package.json`); if
   yes, treat as drift and run steps 1-3 so the range that ships is coherent.
6. Full ladder re-run after the fix commit (PF-11).

---

## P5 - css-compile-fail (G4 FAIL)

Verified failure class (2026-06-24, memory `feedback_verify_css_changes_with_compile`):
a `*/` inside a globals.css comment closed the comment early, tsc stayed green, and
every dashboard route 500'd at runtime.

1. **Get the exact line** with the same parser the dev server throws from:
   ```bash
   node -e "const p=require('postcss');const fs=require('fs');p.parse(fs.readFileSync('<file>','utf8'))"
   ```
   The CssSyntaxError includes line:column.
2. **Commonest root cause:** `*/` inside a comment - prose mentioning `bg-*/10`, a
   glob, or a path. Reword the comment (`bg-token/10`). Never leave a literal `*/`
   inside CSS comment text (PF-7).
3. Other regulars: unclosed brace from a hand-edited token block, a stray `;` in a
   custom-property value, `@import` after other rules.
4. If postcss is not resolvable in this project (`node -e "require.resolve('postcss')"`
   fails), the project's REAL build is the gate - run G6 and read its CSS error.
5. Fix, re-run the one-liner to confirm parse-clean, then the full ladder (PF-11).
   tsc passing is NOT evidence for this gate - match the verification tool to the
   artifact.

---

## P6 - ci-failed-after-push (post-push triage, not a gate)

Preflight is the natural landing spot when someone says "CI failed, can we still
ship?". BEFORE treating a red run as a blocker, run the 3-step ground truth (memory
`feedback_verify_prod_before_ci_panic`; verified 2026-05-17: 90+ min lost to a
historical failure that a 90-second check would have dismissed):

1. `curl -I https://<prod-url>/` - is the app responding right now?
2. `gh run list -R <owner>/<repo> --limit 5` - is there a LATER successful run on
   the SAME SHA? (Auto-retries and parallel workflows produce exactly this.)
3. If SSH is available: `docker ps --format "{{.Image}} {{.Status}} {{.CreatedAt}}"`
   - was the container actually rebuilt recently?

A later green run on the same SHA = the failure is historical noise, NOT a current
blocker. Report that and stop. Only if prod is stale/broken AND no later green run
exists does this become a real incident - then root-cause the failing job
(`gh run view <id> --log-failed`) under the normal fix discipline (PF-13).
Related gotcha: `gh run watch --exit-status` can falsely exit 0 on a transient HTTP
error (memory `reference_gh_run_watch_exit_code`) - trust `gh run list` state over a
watch exit code.

---

## P7 - long-build (G6 operational)

`next build` and `docker compose build` routinely exceed the Bash tool's 120s
default timeout; the box (14Gi, 18 CPUs) has verified OOM history with 2+ concurrent
heavy builds (memory `reference_local_box_oom_heavy_workers`).

1. `free -h` BEFORE the build. Under ~2Gi available with an active worker fleet:
   flag it and wait or coordinate - do not pile on.
2. Run with Bash `timeout: 600000`, or `run_in_background: true` and poll the output.
3. NEVER run two heavy builds concurrently (yours + a worker's counts).
4. A build killed with no error output and exit 137 = OOM kill, not a code failure:
   check `free -h`, serialize, retry once. Do not "fix" code for an OOM.
5. Timeout at 600s with the build still healthy: rerun in background mode; do not
   mark FAIL on a timeout alone - FAIL requires a real compile error as evidence.

---

## P8 - no-upstream-branch (G0 branch of the ladder)

`git rev-parse --abbrev-ref '@{upstream}'` fails: first push of this branch, no
`@{upstream}..HEAD` range exists.

1. **Trailer range (G8):** `git log --branches --not --remotes --format='%H%n%B%n---'`
   piped through the same trailer regex - everything not on any remote is about to
   become public.
2. **Secrets (G7):** `gitleaks git --log-opts "--branches --not --remotes"
   --no-banner --redact .` plus the staged scan, plus `gitleaks dir . --no-banner
   --redact` as the tree-level backstop.
3. **G9d range coherence:** compare against the default remote branch instead
   (`git diff --name-only origin/HEAD...HEAD -- package.json` when origin/HEAD is
   set; skip with a note when it is not).
4. Report "first push of branch - range = all unpushed local commits" in G0
   evidence. This is a normal state, not BLOCKED, as long as the substitute ranges
   ran.
5. PF-1 unchanged: even for a brand-new branch, preflight never runs the
   `git push -u` itself - /ship does.
