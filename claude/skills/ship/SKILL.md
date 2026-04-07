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
8. Push + tag

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

### Step 8: Push + Tag

1. Determine branch: `git branch --show-current`
2. Push: `git push -u origin <branch>`
   - If behind remote: `git pull --rebase origin <branch>`, then push again
3. **If version was bumped in Step 4:**
   - Create tag: `git tag v{VERSION}`
   - Push tag: `git push origin v{VERSION}`
   - Check for tag-triggered CI in `.github/workflows/` → report if release CI triggered

### Final Report

```
Ship Summary
============
Feature:     [what was shipped]
Branch:      [branch name]
Security:    CLEAN / {N} findings fixed
E2E Tests:   PASS
CI/CD:       PASS
Version:     v{version} (if bumped) / unchanged
Commits:     [list of commit hashes and messages]
Pushed:      YES
Tagged:      v{version} (if applicable)
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
- Git tag happens AFTER commit + push
