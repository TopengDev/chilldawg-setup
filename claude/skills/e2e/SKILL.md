---
name: e2e
description: Run end-to-end tests locally for a feature, using browser automation when needed. Use when the user asks to test a feature, run e2e tests, verify a flow works, or check the app end-to-end.
argument-hint: [feature or flow to test]
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

## End-to-End Testing

Test features locally end-to-end before they ship. Fix anything that breaks.

### 1. Understand what to test

If $ARGUMENTS is provided, that's the feature or flow to test.

If not, look at recent changes to infer what should be tested:
- Run `git diff --name-only HEAD~1` to see what changed
- Read the changed files to understand what feature was modified
- Identify the user-facing flows affected

### 2. Check for existing e2e tests

Look for existing test files:
- `**/*.e2e.*`, `**/*.spec.*`, `**/*.test.*` in e2e/test directories
- `cypress/`, `playwright/`, `e2e/`, `tests/` directories
- Check `package.json` for e2e test scripts

If existing e2e tests exist for the feature, run them first.

### 3. Run e2e tests

**Always use the `/agent-browser` skill with qutebrowser for browser-based testing.** Do NOT use Playwright MCP, Chrome, or headless browsers.

- Ensure the local dev server is running (start it if not)
- Navigate to the relevant pages using `agent-browser open` or `agent-browser tab new`
- Use `agent-browser snapshot -i -c --json` to read page state
- Interact with the feature: fill forms (`agent-browser fill`), click buttons (`agent-browser click`), verify outputs
- Take screenshots at key steps as evidence (`agent-browser screenshot`)
- Check for console errors (`agent-browser console`, `agent-browser errors`), network failures (`agent-browser network requests`), visual issues

**If the project has existing e2e test scripts** (e.g. in `package.json`):
- Run them, but only if they don't depend on Playwright/Chrome — if they do, use `/agent-browser` manually instead

**For API-only features**:
- Use `curl` or equivalent to hit endpoints
- Verify request/response payloads, status codes, error handling
- Test edge cases: invalid input, missing auth, boundary values

### 4. Auto-fix loop

If ANY test or verification fails:
1. Capture the exact error — screenshot, console output, test failure message
2. **Root cause analysis first — MANDATORY.** Before writing any fix:
   - Read the relevant source code, trace the execution path, and identify the actual root cause
   - Understand WHY the bug exists, not just WHAT the symptom is
   - Trace the error back to its origin — don't fix where it surfaces, fix where it starts
   - NEVER apply temporary fixes, workarounds, bandaids, or suppress errors
   - NEVER use try/catch to swallow errors, disable checks, or add fallback values that mask the real issue
   - The fix must address the underlying cause, not the symptom
3. Fix the root cause immediately — do not ask for permission
4. Re-run ALL e2e tests from the beginning (not just the one that failed)
5. If it fails again, fix again and re-run everything
6. Keep looping until ALL tests and verifications pass
7. After all tests pass, invoke the `/commit` skill to commit the fixes

If stuck on the same error after 3 different fix attempts, stop and ask the user for help.

### 5. Report results

After all tests pass, present:

```
E2E Results
-----------
Feature:    [what was tested]
Tests run:  [count]
Fixes made: [count, 0 if none]
Status:     ALL PASS
-----------
```

If fixes were committed, list what was fixed and the commit hash.

### 6. Rules

- Always ensure the dev server is running before browser tests
- Do not modify test files to make tests pass — fix the source code
- If a test is genuinely wrong (testing outdated behavior), fix the test AND note it in the report
- Use `/agent-browser` for visual/interactive verification when automated tests aren't sufficient
- Take screenshots as evidence for visual features
- Check browser console for errors even if the UI looks correct
