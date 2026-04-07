---
name: preflight
description: Run local CI/CD checks before pushing to avoid failed workflows. Use when the user wants to push, verify builds, run tests, or check that CI would pass.
argument-hint: [optional: specific check to run]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

## Preflight CI/CD Check

Prevent wasted CI/CD runs by verifying everything passes locally first.

### 1. Discover CI/CD workflows

Read all workflow files:
- `.github/workflows/*.yml` / `.github/workflows/*.yaml`
- `Dockerfile` and `docker-compose.yml` if present

Parse each workflow to extract the actual jobs and steps — linting, type checking, testing, building. Understand what commands CI runs.

### 2. Run checks locally

Execute the equivalent local commands for each CI step found. Common checks to look for and run:

**Linting & Formatting**
- Go: `golangci-lint run ./...` or `go vet ./...`
- TypeScript/JavaScript: `npx eslint .` or the lint script in package.json
- Python: `ruff check .` or `flake8`

**Type Checking**
- TypeScript: `npx tsc --noEmit`

**Tests**
- Go: `go test ./...`
- Node: `npm test` or `npx vitest run` or `npx jest`
- Python: `pytest`

**Build**
- Node: `npm run build` or `npx next build`
- Go: `go build ./...`
- Docker: `docker compose build` (only if the CI workflow builds Docker images)

If the project uses Docker for CI (e.g., `docker compose run tests`), replicate that approach locally rather than running bare commands.

If $ARGUMENTS is provided, only run the matching check (e.g., `/preflight test` runs only tests).

### 3. Report results

Present a clear summary table:

```
Preflight Results
-----------------
Lint:       PASS / FAIL
Types:      PASS / FAIL / N/A
Tests:      PASS / FAIL
Build:      PASS / FAIL
-----------------
Ready to push: YES / NO
```

### 4. Auto-fix loop

If ANY check fails:
1. Show the error output (truncated to key lines)
2. **Root cause analysis first — MANDATORY.** Before writing any fix:
   - Read the relevant source code, trace the execution path, and identify the actual root cause
   - Understand WHY the error exists, not just WHAT the symptom is
   - Trace the error back to its origin — don't fix where it surfaces, fix where it starts
   - NEVER apply temporary fixes, workarounds, bandaids, or suppress errors
   - NEVER use try/catch to swallow errors, disable lint rules, skip tests, or add fallback values that mask the real issue
   - The fix must address the underlying cause, not the symptom
3. Fix the root cause immediately — edit the code directly, do not ask for permission
3. After fixing, re-run ALL checks from the beginning (not just the one that failed)
4. If checks fail again, fix again and re-run ALL checks again
5. Keep looping until ALL checks pass
6. After all checks pass, invoke the `/commit` skill to commit the fixes
7. Then report the final results

There is no maximum retry limit — keep fixing until it works. If you are truly stuck on the same error after 3 attempts with different approaches, stop and ask the user for help.

### 5. Rules

- NEVER push code automatically — only report readiness
- If ALL checks pass on first run (no fixes needed), tell the user it's safe to push
- If fixes were needed, commit them via `/commit` first, then tell the user it's safe to push
- Run checks in the same order CI would run them
- If no CI workflows are found, tell the user and ask what checks they want to run
