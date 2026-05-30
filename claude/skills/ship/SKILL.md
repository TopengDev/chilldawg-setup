---
name: ship
description: Full shipping pipeline — simplify, security review, test, version, commit, preflight, push. Use when the user says ship, deploy, push, or is done developing a feature.
argument-hint: [feature or branch description]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill, Agent
---

## Ship Pipeline

One command to go from "done coding" to "pushed and CI-ready."

### Pipeline order

1. `/simplify` — code cleanup (reuse, quality, efficiency)
2. Security review — scan for vulnerabilities
3. `/e2e` — verify the feature works end-to-end
4. Version & changelog — bump version, update CHANGELOG.md (if applicable)
5. README update — update docs if changes affect them (if applicable)
6. `/commit` — commit all changes
7. `/preflight` — run CI/CD checks locally
8. Push
9. Distribution tail — changelog refresh from commits, annotated semver tag, CI watch, optional publish

### Step 1: Simplify (auto-fix)

Invoke the `/simplify` skill. This will review changed code for reuse, quality, and efficiency, then auto-fix issues found.

Wait for simplify to complete before proceeding.

### Step 2: Security Review (interactive)

Run `git diff HEAD` to get all uncommitted changes, then analyze as a senior security engineer.

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

**If findings exist:** Present each with severity, file/line, description, and fix. Ask: "Which findings should I fix? (all / none / comma-separated numbers)". Fix selected findings.

**If no findings:** Print "Security review: clean" and proceed.

### Step 3: E2E Test

Invoke the `/e2e` skill with $ARGUMENTS as the feature context.

If `/e2e` finds and fixes issues, it will commit those fixes automatically.

Do NOT proceed until `/e2e` reports all tests passing.

### Step 4: Version & Changelog (conditional)

**Detection:** Check for `CHANGELOG.md` in project root.

**If no CHANGELOG.md:** Skip this step entirely.

**If CHANGELOG.md exists:**

1. Read current version from `package.json`, `Cargo.toml`, or `pyproject.toml`
2. Suggest bump type based on changes:
   - Bug fixes → `patch`
   - New features → `minor`
   - Breaking changes → `major`
3. Ask user: `Release: current v{version}. Bump? (patch → {x} / minor → {x} / major → {x} / skip)`
4. If user picks a bump:
   - Update version in the manifest file
   - Insert new section in CHANGELOG.md (Keep a Changelog format):
     ```
     ## [{VERSION}] - {YYYY-MM-DD}

     ### {Category}

     - {description from actual code changes}
     ```
   - Append release link to bottom of CHANGELOG.md
5. If user says "skip": proceed without versioning

### Step 5: README Update (conditional, auto)

**If no README.md:** Skip.

**If README.md exists:** Review code changes and determine if they affect documented content (new features, changed CLI flags, updated usage, removed functionality, changed API).

- If changes affect docs: update relevant sections, keep existing style
- If no doc impact: skip silently

### Step 6: Commit

Invoke the `/commit` skill to commit all current changes (including version bump, changelog, README updates from steps 4-5).

If there are no unstaged/untracked changes, skip this step.

### Step 7: Preflight CI/CD

Invoke the `/preflight` skill to run all CI/CD checks locally.

If `/preflight` finds and fixes issues, it will commit those fixes automatically.

Do NOT proceed until `/preflight` reports all checks passing.

### Step 8: Push

1. Determine branch: `git branch --show-current`
2. Push: `git push -u origin <branch>`
   - If behind remote: `git pull --rebase origin <branch>`, then push again

> Tagging moved to Step 9 (Distribution Tail) so the tag is annotated and created only after the push lands.

### Step 9: Distribution Tail (post-push)

Runs AFTER the push succeeds. This is the "make the release real and observable" stage. Each sub-step is conditional — skip silently when it doesn't apply, never block the ship on an optional step.

**(a) Changelog refresh from commits**

- If `CHANGELOG.md` was already updated in Step 4, skip — it's current.
- If there is NO `CHANGELOG.md` and the project looks like a release artifact (has a version manifest: `package.json` / `Cargo.toml` / `pyproject.toml`), offer to generate one from the git history:
  - `git log --pretty=format:'%s' {LAST_TAG}..HEAD` (or full history if no prior tag), grouped into Added / Changed / Fixed by conventional-commit prefix (`feat:`→Added, `fix:`→Fixed, else Changed).
  - Write a Keep-a-Changelog `## [{VERSION}] - {YYYY-MM-DD}` section. Commit it via `/commit` and re-push.
- If the project is not a release artifact (no manifest), skip silently — most of Christopher's repos are apps/configs, not published packages.

**(b) Annotated semver tag**

- Only when a version exists/was bumped (Step 4) OR the user explicitly asks to tag.
- Resolve `{VERSION}` from the manifest. Confirm it isn't already tagged: `git tag -l v{VERSION}`.
- Create an **annotated** tag (carries tagger, date, message — unlike a lightweight tag):
  - `git tag -a v{VERSION} -m "Release v{VERSION}"` (append a one-line summary of headline changes if available).
- Push it: `git push origin v{VERSION}`.
- If `v{VERSION}` already exists, do NOT overwrite — report it and skip.

**(c) Watch CI after push**

- Only if the repo has a GitHub remote and `.github/workflows/` exists and `gh` is authenticated (`gh auth status`).
- Give the run a moment to register, then watch the run for the pushed SHA:
  - `gh run watch $(gh run list --branch <branch> --limit 1 --json databaseId -q '.[0].databaseId') --exit-status` (or poll `gh run list` if `watch` isn't available).
  - Bound the wait sensibly; if CI is still running after a reasonable window, report "CI in progress" rather than hanging.
- Report the outcome: **PASS** / **FAIL** (with the failing job + a link via `gh run view --web`) / **IN PROGRESS** / **N/A** (no CI).
- A CI **FAIL** does not un-ship the push (it's already pushed) — surface it loudly in the Final Report so the user can act.

**(d) Publish to package registries — OPTIONAL / DEFERRED**

> ⚠️ Christopher does not currently publish CLI packages. Treat this whole sub-step as OFF by default. Only run it if the project clearly publishes a package AND the user explicitly confirms.

If this project publishes a CLI / library:
- **npm:** `npm publish` (verify `package.json` `name`/`version`/`files`/`bin`, `npm whoami`, 2FA OTP if enabled; `--access public` for scoped first publish).
- **Homebrew tap:** bump the formula in the tap repo — update `url` to the new release tarball + recompute `sha256` (`shasum -a 256`), commit + push to the tap.
- Both require credentials/auth set up first — if not configured, report "publish skipped (not configured)" and move on. Never invent registry credentials.

### Final Report

```
Ship Summary
============
Feature:      [what was shipped]
Branch:       [branch name]
Security:     CLEAN / {N} findings fixed
E2E Tests:    PASS
Preflight:    PASS
Version:      v{version} (if bumped) / unchanged
Commits:      [list of commit hashes and messages]
Pushed:       YES
Tagged:       v{version} annotated (if applicable) / none
Changelog:    updated / generated / n/a
Remote CI:    PASS / FAIL ({failing job} — {url}) / IN PROGRESS / N/A
Published:    npm + brew / skipped (deferred) / n/a
============
```

### Rules

- Follow the pipeline order strictly — no skipping steps
- Each step must fully pass before moving to the next
- If any step's fix loop gets stuck (3 attempts on same error), stop the entire pipeline and ask the user for help
- Never force push — if `git push` fails for reasons other than being behind remote, stop and ask the user
- Security review is the ONLY mandatory interactive step
- Version bump is OPTIONAL — only when CHANGELOG.md exists
- Version bump + changelog + README happen BEFORE commit
- The distribution tail (Step 9) runs AFTER push: annotated tag, then CI watch
- Tags are ANNOTATED (`git tag -a`), never lightweight; never overwrite an existing tag
- A CI FAIL in Step 9 does not un-ship — report it loudly, don't silently swallow it
- Package publishing (npm/brew) is OFF by default — only with an explicit confirm + configured creds
