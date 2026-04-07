---
name: qa
description: Adversarial QA — hammers any codebase across 10 testing dimensions and produces a severity-graded markdown report. Supports quick mode (functional + edge cases + UX) and full mode (all 10 dimensions).
---

# /qa Skill — Adversarial QA

Real QA is more than `cargo test` — it's adversarial. It asks "how can this break?" not "does this pass?"

## Usage

```
/qa quick   — smoke test: functional + edge cases + UX spot-check (~15 min)
/qa full    — deep adversarial: all 10 dimensions (~60 min per dimension max)
```

## Execution Rules

1. **All test execution happens in an isolated `qa` tmux window.** Never run tests in the main session.
2. **Report only — never auto-fix.** Findings go into `./QA.md`. Remediation is the developer's decision.
3. **Destructive tests are simulated/planned only.** Never actually inject failures, corrupt files, or kill processes.
4. **Always clean up.** The `qa` tmux window must be killed when done, even on failure or timeout.
5. **60-minute hard timeout per dimension** in full mode. If a dimension exceeds this, record partial results and move on.
6. **Report path**: `./QA.md` — fixed path, overwritten each run.

---

## Phase 1: Detect & Discover

### Step 1: Detect Project Type

Scan for config files. First match wins:

| File | Type | Test Command | Build Command |
|------|------|-------------|---------------|
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |
| `package.json` | TypeScript/JavaScript | `npm test` or `npx vitest` | `npm run build` |
| `pyproject.toml` | Python | `python -m pytest` | `python -m build` |
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `Makefile` | Universal | `make test` or `make check` | `make` or `make build` |
| `CMakeLists.txt` | C/C++ | `ctest` or `make test` | `cmake --build .` |
| `pom.xml` | Java/Maven | `mvn test` | `mvn compile` |
| `build.gradle` | Java/Gradle | `gradle test` | `gradle build` |
| `composer.json` | PHP | `composer test` or `vendor/bin/phpunit` | `composer install` |
| `*.csproj` | C# | `dotnet test` | `dotnet build` |
| `Gemfile` | Ruby | `bundle exec rspec` | `bundle install` |

**Fallback**: If no config detected, ask the user: "Could not auto-detect project type. What language/framework is this?"

### Step 2: Extract Test Commands

From the detected config, extract:
- **Test command**: the primary test runner
- **Build command**: how to compile/build
- **Lint command**: if available
- **Test file patterns**: where tests live

Examples:
- `package.json` → `scripts.test`, `scripts.build`, `scripts.lint`
- `Cargo.toml` → `cargo test`, `cargo build`, `cargo clippy`
- `pyproject.toml` → `[tool.pytest.ini_options]`, `[tool.ruff]`
- `Makefile` → `test:`, `check:`, `lint:` targets

### Step 3: Discover Test Infrastructure

Find existing test files:
```bash
# Test file patterns (run from project root)
find . -name '*_test.go' -o -name '*_test.rs' -o -name '*.test.ts' -o -name '*.test.js' \
       -o -name '*.spec.ts' -o -name '*.spec.js' -o -name 'test_*.py' -o -name '*_test.py' \
       -o -name '*_test.ts' 2>/dev/null | head -50
```

Find CI configs:
```bash
ls .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null
```

### Step 4: Create Isolated tmux Window

```bash
# Kill any existing qa window
tmux kill-window -t :qa 2>/dev/null
sleep 0.5

# Create new qa window
tmux new-window -n "qa" -c "$(pwd)"
sleep 0.5
```

All subsequent test execution goes into this window via `tmux send-keys -t :qa`.

---

## Phase 2: Execute Tests (Mode-Dependent)

### Quick Mode (`/qa quick`)

Runs 3 dimensions only. Execute in order:

#### Dimension 1: Functional Testing

1. Run the existing test suite in the qa window:
```bash
tmux send-keys -t :qa "{TEST_COMMAND} 2>&1 | tee /tmp/qa-test-output.log" Enter
```

2. Wait for completion (capture output after 30-60s):
```bash
sleep 30
tmux capture-pane -t :qa -p -S -100
```

3. Parse results: count passed, failed, skipped tests.

4. Identify critical user flows by reading the project structure:
   - For web apps: read route definitions, API endpoints
   - For CLIs/TUIs: read command definitions, main entry points
   - For libraries: read public API exports
   - Walk through each flow via code review

5. Verify error handling paths exist:
   - grep for error handling patterns (`catch`, `expect`, `Result::Err`, `try`, `unwrap_or`)
   - Check if error cases are tested

Record findings:
- Test suite: PASS/FAIL (with failure details)
- Critical flows: list each with PASS/FAIL/NOT_TESTED
- Missing coverage: areas with no tests

#### Dimension 2: Edge Case Testing

For every input-accepting function (APIs, CLIs, UI forms, public functions):

1. **Empty inputs**: Test with `""`, `null`, `undefined`, `None`, empty arrays/objects
2. **Max length**: Test strings at and beyond documented limits
3. **Unicode/emoji**: Test with `"🔥"`, `"日本語"`, `"العربية"`, zero-width characters (`\u200b`)
4. **Special characters**: Test with SQL injection strings (`' OR 1=1 --`), shell metacharacters (`; rm -rf /`, `$(whoami)`), HTML (`<script>alert(1)</script>`)
5. **Boundary values**: Test `0`, `-1`, `MAX_INT`, `MAX_FLOAT`, empty files
6. **Null/missing fields**: Test JSON/objects with missing required fields

For each edge case, determine if the project handles it gracefully or crashes. Record which ones pass and which break.

#### Dimension 3: UX Spot-Check

1. **Error messages**: Read all error messages in the codebase. Are they:
   - Actionable? (tells user what to do)
   - Or cryptic? (e.g., "Error 500", "Something went wrong", raw stack traces)

2. **Missing feedback**: Identify operations that could take time without progress indicators:
   - File uploads, DB operations, network requests
   - Any operation >1 second without feedback

3. **Confusing flows**: Walk through user journeys. Are there:
   - Non-obvious next steps?
   - Dead ends (no way back)?
   - Inconsistent naming or behavior?

Record UX issues with severity.

---

### Full Mode (`/qa full`)

Runs all 10 dimensions. Execute in order. 60-minute hard timeout per dimension.

#### Dimension 1: Functional (Extended)

Everything in Quick Mode's functional testing, plus:

1. **Map all user flows** from code analysis:
   - Read route files, command definitions, API handlers
   - Trace data flow from input to output
   - Identify every entry point (CLI commands, API endpoints, UI routes)

2. **Build adversarial tests from scratch**:
   - For each flow, ask: "What's the worst input for this?"
   - Test with malformed data, unexpected types, out-of-order operations
   - Test state transitions: can you reach invalid states?

3. **Verify error handling paths**:
   - Every `try/catch`, `Result`, `Option` — is the error case handled or just propagated?
   - Are there `unwrap()`, `panic!()`, `throw` in production paths?

4. **Check integration points**:
   - Database connections: what happens on connection failure?
   - File I/O: what happens on permission denied, disk full?
   - Network: what happens on timeout, DNS failure, SSL error?

Record comprehensive pass/fail per flow with missing coverage areas.

#### Dimension 2: Edge Cases (Extended)

Everything in Quick Mode's edge case testing, plus:

1. **Concurrent actions**: If the project handles concurrent operations:
   - What happens with two simultaneous writes to the same resource?
   - Race conditions in shared state?
   - Lock contention or deadlocks?

2. **Encoding edge cases**:
   - Mixed encodings in the same input
   - BOM characters at file start
   - Surrogate pairs in strings
   - Right-to-left text mixed with LTR

3. **Numeric edge cases**:
   - Floating point precision: `0.1 + 0.2 !== 0.3`
   - Integer overflow/underflow
   - Division by zero
   - NaN, Infinity handling

4. **Time-related edge cases**:
   - Leap years, leap seconds
   - Daylight saving time transitions
   - Timezone mismatches
   - Unix timestamp overflow (Year 2038 problem)

Record severity for each failure found.

#### Dimension 3: Cross-Platform Testing

1. **Terminal rendering**:
   - Review ANSI escape code usage — are colors/cursor positions portable?
   - Check for ncurses/termbox dependencies — are they cross-platform?
   - Test with different terminal widths (80 cols minimum)

2. **OS-specific paths**:
   - Grep for hardcoded `/` or `\` in path construction
   - Check for OS-specific commands (`rm`, `del`, `kill`, `taskkill`)
   - Review environment variable usage (`$HOME` vs `%USERPROFILE%`)

3. **tmux compatibility**:
   - If the project uses tmux: verify pane splits, key bindings work
   - Check for tmux version assumptions

4. **Screen size assumptions**:
   - Fixed-width layouts that break on small terminals
   - Assumptions about terminal height
   - Overflow handling in TUI components

Record compatibility issues and platform-specific risks.

#### Dimension 4: Regression Testing

1. **Review recent changes**:
```bash
git log --oneline -10
git diff HEAD~10 --stat
```

2. **Identify risk areas**:
   - What files changed most?
   - Were any shared utilities or core modules modified?
   - Were any tests removed or disabled?

3. **Check for breaking changes**:
   - Renamed functions/types that callers might not have updated
   - Changed function signatures
   - Removed error handling
   - Changed default values

4. **Run targeted tests** on changed modules:
```bash
tmux send-keys -t :qa "git diff HEAD~10 --name-only | xargs dirname | sort -u" Enter
```

5. **Check adjacent features** — if module X changed, what depends on X?

Record regression risks and any broken adjacent features.

#### Dimension 5: Destructive Testing (Simulated)

**DO NOT actually inject failures.** Map and plan only.

1. **Map critical failure points**:
   - Database connections: what happens if the DB drops mid-query?
   - File I/O: what happens if disk fills during write?
   - Network: what happens if connection drops mid-request?
   - Memory: what happens if OOM killer fires?
   - Process: what happens if `kill -9` hits during operation?

2. **For each failure point, document**:
   - What state would be left in? (corrupt, partial, clean?)
   - Is there recovery logic? (retry, rollback, checkpoint?)
   - Would the user see a clean error or a crash?
   - Is there data loss risk?

3. **Plan safe test procedures** for each:
   - "To test DB drop: start transaction → insert data → kill connection → verify rollback"
   - "To test disk full: create large file → attempt write → verify error handling"
   - Include backup/restore steps

4. **Rate each failure point** by likelihood × impact:
   - High likelihood + high impact = P0
   - Low likelihood + high impact = P1
   - High likelihood + low impact = P2

Record failure mode analysis with recommended safe tests.

#### Dimension 6: UX Audit

1. **Error message review** (comprehensive):
   - Every error message: is it user-facing or developer-facing?
   - Do error messages suggest next steps?
   - Are technical details exposed to end users?

2. **Feedback gaps**:
   - Long operations (>2s) without progress indicators
   - Silent failures (operation fails but UI shows success)
   - Loading states missing or inconsistent

3. **Flow analysis**:
   - Are there dead ends? (user reaches a state with no way forward or back)
   - Are destructive actions confirmed? (delete, overwrite, reset)
   - Is there undo capability for destructive actions?

4. **Consistency check**:
   - Mixed naming conventions in UI
   - Inconsistent date/time formats
   - Inconsistent number formatting
   - Mixed terminology for the same concept

5. **Accessibility** (if web/TUI):
   - Keyboard navigation support
   - Screen reader compatibility
   - Color contrast for terminal themes

Record UX issues ranked by user impact.

#### Dimension 7: Performance Testing

1. **N+1 query patterns**:
   - Look for loops that execute database queries
   - Look for `.map()` or `.forEach()` with async DB calls
   - Check for missing `JOIN` or `INCLUDE` in ORM queries

2. **Unbounded operations**:
   - Loops with no limit on iteration count
   - API endpoints that return all records (no pagination)
   - File reads with no size limit
   - Cache with no eviction policy

3. **Memory leak indicators**:
   - Unclosed file handles, database connections, HTTP clients
   - Growing arrays/caches with no cleanup
   - Event listeners added but never removed
   - Circular references in object graphs

4. **Large dataset handling**:
   - What happens with 1000+ records?
   - What happens with 10,000+ records?
   - Is there pagination, virtualization, or streaming?

5. **Time critical operations**:
   - If possible, time the slowest operations
   - Identify operations that block the main thread
   - Check for synchronous operations that should be async

Record performance bottlenecks with severity based on impact.

#### Dimension 8: Security Testing

1. **SQL injection**:
   - Grep for string concatenation in SQL queries
   - Check for parameterized query usage
   - Look for raw SQL execution with user input

2. **XSS**:
   - Check if user input is rendered without escaping
   - Look for `innerHTML`, `dangerouslySetInnerHTML`, `|safe`
   - Check if user-generated content is sanitized

3. **Command injection**:
   - Grep for `exec`, `spawn`, `system`, `os.system`, `subprocess`
   - Check if user input is interpolated into shell commands
   - Look for missing input sanitization before shell execution

4. **Auth bypass**:
   - Are there endpoints without auth checks?
   - Can users access other users' data (IDOR)?
   - Are admin endpoints protected?
   - Is token/session validation consistent?

5. **Data leaks**:
   - Check logging for sensitive data (passwords, tokens, PII)
   - Check error responses for stack traces or internal details
   - Check API responses for over-exposure (returning more fields than needed)

6. **Hardcoded secrets**:
```bash
grep -rn 'password\|secret\|api_key\|token\|private_key' --include='*.rs' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.json' --include='*.yaml' --include='*.yml' --include='*.env' . | grep -v 'node_modules\|target\|\.git\|test\|spec\|example\|sample' | grep -v 'process\.env\|std::env\|os\.environ\|os\.Getenv'
```

Record security vulnerabilities severity-graded.

#### Dimension 9: State Testing

1. **Fresh install**:
   - What happens on first run with no config files?
   - Are default configs created automatically?
   - Is there a setup/init command?
   - Does it crash or gracefully guide the user?

2. **Missing files**:
   - What happens if required files don't exist?
   - Are missing files detected with clear error messages?
   - Does the project create missing files automatically?

3. **Corrupt config**:
   - What happens with malformed JSON/YAML/TOML?
   - Is there config validation with actionable error messages?
   - Does it fall back to defaults or crash?

4. **Migration**:
   - If the project has versioned data/config: can it migrate from older versions?
   - Are migrations reversible?
   - What happens if a migration fails mid-way?

5. **State recovery**:
   - If the process crashes, can it recover on restart?
   - Are there checkpoint/restore mechanisms?
   - Is there data corruption risk on crash?

Record state handling issues and crash scenarios.

#### Dimension 10: Visual Testing

1. **UI code review** (apply UI/UX expert perspective):
   - Layout consistency: are spacing, padding, margins consistent?
   - Visual hierarchy: is important content visually prominent?
   - Alignment: are elements properly aligned?
   - Typography: are font sizes, weights, line heights appropriate?

2. **Responsive design** (if web):
   - Does the layout break at common breakpoints (320px, 768px, 1024px, 1440px)?
   - Are touch targets large enough on mobile?
   - Does content overflow or get cut off?

3. **Terminal output formatting** (if CLI/TUI):
   - Is output aligned and readable at 80 columns?
   - Do tables/formatting break with long content?
   - Are colors accessible in both light and dark terminal themes?

4. **If display is available**, capture screenshots and review:
   - Compare expected vs actual rendering
   - Note any visual glitches, misalignments, or inconsistencies

5. **Graceful degradation**: If no display is available, note:
   - "Visual testing: skipped (no display available)"
   - Still review UI code for issues via code analysis

Record visual issues with UI/UX recommendations.

---

## Phase 3: Generate Report

After all dimensions are complete, generate `./QA.md`:

### Severity Grading Criteria

| Severity | Label | Criteria |
|----------|-------|----------|
| **P0** | Critical | System crash, data loss, security vulnerability, core feature broken |
| **P1** | High | Feature broken for specific inputs, significant UX failure, performance issue that blocks usage |
| **P2** | Medium | Edge case failure, confusing UX, minor security concern, performance degradation |
| **P3** | Low | Cosmetic issue, minor inconsistency, nice-to-have improvement |
| **P4** | Cosmetic | Spelling, formatting, color, alignment — no functional impact |

### Verdict Logic

- **SHIP**: No P0 or P1 findings. P2+ are acceptable.
- **FIX BEFORE SHIP**: Has P0 or P1 findings that are fixable.
- **DO NOT SHIP**: Has P0 findings indicating fundamental brokenness or data loss risk.

### Report Template

Write the report to `./QA.md` using this structure:

```markdown
# QA Report — {Project Name}

Date: {YYYY-MM-DD HH:MM}
Mode: {quick | full}
Project: {path}
Type: {detected type}

## Executive Summary

Verdict: {SHIP | FIX BEFORE SHIP | DO NOT SHIP}
Total findings: {N} (P0: {n}, P1: {n}, P2: {n}, P3: {n}, P4: {n})

## Dimension Results

| Dimension | Status | Findings |
|-----------|--------|----------|
| Functional | {PASS|FAIL|PARTIAL} | {count} |
| Edge Cases | {PASS|FAIL|PARTIAL} | {count} |
{Only in full mode:}
| Cross-Platform | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |
| Regression | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |
| Destructive (Simulated) | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |
| UX Audit | {PASS|FAIL|PARTIAL} | {count} |
| Performance | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |
| Security | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |
| State | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |
| Visual | {PASS|FAIL|PARTIAL|SKIPPED} | {count} |

## Test Suite Results

{Output from running existing tests}

## Findings

### P0 — Critical

#### {Finding title}
- **Dimension**: {which dimension}
- **Description**: {what's wrong}
- **Reproduction**: {steps to reproduce}
- **Affected**: {which files/components}
- **Impact**: {what breaks}

{Repeat for each P0 finding}

### P1 — High

{Same format as P0}

### P2 — Medium

{Same format as P0}

### P3 — Low

{Same format as P0}

### P4 — Cosmetic

{Same format as P0}

## Recommendations

{Prioritized list of what to fix first, grouped by severity}

{If full mode, include destructive test plans:}
## Destructive Test Plans

{List of planned destructive tests with safe execution procedures}
```

---

## Phase 4: Cleanup

Always execute, even on partial failure:

```bash
tmux kill-window -t :qa 2>/dev/null
```

If the qa window is unresponsive:
```bash
tmux kill-window -t :qa 2>/dev/null
sleep 1
tmux kill-window -t :qa 2>/dev/null  # double-tap
```

If the report was not fully generated due to timeout/interruption, write whatever was collected so far to `./QA.md` with a note: "QA interrupted — partial results only."
