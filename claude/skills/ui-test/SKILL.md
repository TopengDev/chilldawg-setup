---
name: ui-test
description: Automated UI testing via qutebrowser — exhaustively tests every interactive element on every page for every role, with screenshots and functional verification. Quick mode (page crawl + visibility) and full mode (exhaustive element testing + flows + responsive).
---

# /ui-test Skill — Automated UI Testing

Real UI testing means verifying every page works for every role, every button does what it should, and no role sees what it shouldn't. **Every element. Every page. Every role. No sampling.**

## Usage

```
/ui-test quick   — smoke test: page crawl + visibility check per role (~10 min)
/ui-test full    — exhaustive test: every element on every page + flows + responsive (~60-120 min)
```

## Execution Rules

1. **All browser interaction goes through `/agent-browser` with qutebrowser.** Never use Playwright, Chrome, or any other browser tool.
2. **Auto-login via the login form** for each role — no cookie/token injection shortcuts.
3. **Fresh browser instance per role** — kill qutebrowser between roles to prevent state leakage.
4. **Report only — never auto-fix.** Findings go into `./UI-QA.md`.
5. **Always clean up.** Kill qutebrowser when done, even on failure or timeout.
6. **30-minute hard timeout per role.** If a role exceeds this, record partial results and move to the next role.
7. **Report path**: `./UI-QA.md` — fixed path, overwritten each run.
8. **Screenshot path**: `./ui-test-screenshots/` — organized by role.

---

## Phase 1: Config & Setup

### Step 1: Read and Validate Config

Read `.ui-test-config.json` from the project root. Validate:

**Required fields:**
- `target.local` or `target.staging` (at least one)
- `login.url` — path to login page (e.g., `/login`)
- `login.emailField` — CSS selector for email input
- `login.passwordField` — CSS selector for password input
- `login.submitSelector` — CSS selector for submit button
- `login.successIndicator` — format: `url:/path` or `selector:.element`
- `roles[]` — array with at least 1 role, each having `name`, `email`, `password`
- `pages[]` — array with at least 1 page, each having `path` and `name`

**Optional fields:**
- `flows[]` — critical user journeys to test
- `visibility` — role-based element visibility expectations

**If config is missing or invalid:**
- Report the specific missing/invalid fields
- Abort the test run

### Step 2: Determine Target URL

- Default: use `target.local` if a dev server is running (check if port is in use), otherwise use `target.staging`
- Override: if user specifies `--staging` or `--local`, use that target

### Step 3: Create Screenshot Directories

```bash
mkdir -p ./ui-test-screenshots
for role in $(jq -r '.roles[].name' .ui-test-config.json); do
  mkdir -p "./ui-test-screenshots/$role/flows"
  mkdir -p "./ui-test-screenshots/$role/failures"
  mkdir -p "./ui-test-screenshots/$role/elements"
done
```

---

## Phase 2: Execute Tests (Mode-Dependent)

### Browser Session Lifecycle (Per Role)

For each role in `roles[]`, follow this exact sequence:

#### 1. Clean Start
```bash
pkill -f qutebrowser 2>/dev/null
sleep 1
```

#### 2. Launch qutebrowser via /agent-browser
Use the `/agent-browser` skill to open qutebrowser. Wait for it to be ready.

#### 3. Auto-Login
1. Navigate to `{baseUrl}{login.url}`
2. Wait 2s for page to load
3. Fill the email field (`login.emailField`) with the role's email
4. Fill the password field (`login.passwordField`) with the role's password
5. Click the submit button (`login.submitSelector`)
6. Wait up to 10s for `login.successIndicator`:
   - If format is `url:/path`: check that current URL contains `/path`
   - If format is `selector:.element`: check that the element is visible
7. **If login fails:** retry up to 3 times with 2s backoff between attempts
8. **If login still fails after 3 retries:**
   - Mark this role as `FAILED`
   - Record error: "Login failed for role '{name}' after 3 attempts"
   - Skip all page tests for this role
   - Kill qutebrowser and continue to next role

#### 4. Execute Test Dimensions

**Quick Mode** — run these for each role:
- Page Crawl (Step 4A)
- Visibility Check (Step 4B)

**Full Mode** — run these for each role:
- Page Crawl (Step 4A)
- Visibility Check (Step 4B)
- Exhaustive Interactive Element Testing (Step 4C)
- Flow Testing (Step 4D)
- Edge Case UI (Step 4E)

#### 5. Logout & Cleanup
1. If config has `logout.url`: navigate to `{baseUrl}{logout.url}`
2. Otherwise: clear all cookies via qutebrowser command
3. Wait 2s, verify redirect to login page or that auth-required pages redirect to login
4. Kill qutebrowser:
```bash
pkill -f qutebrowser 2>/dev/null
sleep 1
```

---

### Step 4A: Page Crawl (Quick + Full Mode)

For each page in `config.pages[]`:

1. Navigate to `{baseUrl}{page.path}`
2. Wait 3s for page to settle
3. Check for error indicators:
   - Page text contains "404", "Not Found", "Error", "Something went wrong"
   - Page shows a crash/blank screen
   - Visible error toast on screen
4. **Screenshot:**
   - Full mode: always screenshot → save to `./ui-test-screenshots/{role}/{page-name}.png`
   - Quick mode: only screenshot on failure → save to `./ui-test-screenshots/{role}/failures/{page-name}.png`
5. Record result:
   - Page name, status (PASS/FAIL), error details, screenshot path

**Error handling:**
- If page doesn't load within 15s: mark FAIL, screenshot, continue
- If page returns 404: mark FAIL, screenshot, continue

---

### Step 4B: Visibility Check (Quick + Full Mode)

If `config.visibility` exists and has an entry for the current role:

1. For each selector in `visibility[role].shouldSee[]`:
   - Check if element exists and is visible on the current page
   - Record: PASS if visible, FAIL if hidden/missing
2. For each selector in `visibility[role].shouldNotSee[]`:
   - Check if element is hidden or doesn't exist
   - Record: PASS if hidden/missing, FAIL if visible
3. If any visibility check fails: take screenshot → save to `./ui-test-screenshots/{role}/failures/visibility-{role}.png`

If `config.visibility` doesn't exist for this role: skip this step, record as "NOT_CONFIGURED"

---

### Step 4C: Exhaustive Interactive Element Testing (Full Mode Only)

**This is the core of full mode. Every element on every page. No exceptions.**

For each page in `config.pages[]`, after page crawl completes:

#### Algorithm: Isolate-Per-Element Exhaustive Testing

In an SPA, interactions like expand/collapse buttons, tab switches, and dropdowns change the DOM structure, making subsequent elements unfindable by identity. The only way to achieve 100% coverage is to **test each element in isolation**: navigate to the page, snapshot, interact with ONE element, navigate away, navigate back, repeat for the next element.

```
For each page:
  1. Navigate to {baseUrl}{page.path}
  2. Wait 3s for page to settle
  3. Take snapshot → parse interactive elements → build identity list → count = N
  4. For i = 1 to N:
     a. Navigate away from page (go to /dashboard or any neutral page)
     b. Wait 1s
     c. Navigate back to {baseUrl}{page.path}
     d. Wait 3s for page to settle
     e. Re-snapshot (guaranteed fresh DOM state)
     f. Parse snapshot, find element by identity (type + text) at position i
     g. If element not found: mark SKIPPED, continue to i+1
     h. Identify element type and text/label
     i. Interact based on type (see Element Type Matrix below)
     j. Wait 2s for response
     k. Verify outcome (see Outcome Verification below)
     l. Record: element index, type, text, action, result (PASS/FAIL)
  5. Report: N elements found, N tested, M passed, K failed, S skipped
```

**Why navigate away and back?** This guarantees the page re-renders from scratch with its default state. No collapsed menus, no open modals, no toggled switches — every element test starts from a clean slate.

#### Element Type Matrix

| Element Type | Action | Verification |
|-------------|--------|-------------|
| `button` | Click | Some visible change occurred (toast, modal, state change, navigation) |
| `link` | Click | URL changed to expected path |
| `textbox` | Type "test123" | Input accepts text without crash |
| `combobox` | Click to open | Dropdown/options appear |
| `checkbox` | Click to toggle | Checked state changes |
| `switch` | Click to toggle | Switch state changes |
| `tab` | Click | Tab content changes |
| `menuitem` | Click to open | Menu appears |
| `slider` | Skip (requires coordinate interaction) | Record as SKIPPED |
| `colorpicker` | Skip | Record as SKIPPED |

#### Outcome Verification

After each interaction, check in this order:

1. **URL changed?** → Navigation link. Record PASS.
2. **Modal/dialog appeared?** → Record PASS (modal opened correctly).
3. **Toast/notification appeared?** → Record PASS.
4. **Page content changed?** → Record PASS.
5. **Element state changed?** (checkbox checked, switch toggled, tab switched) → Record PASS.
6. **Nothing happened?** → Record as "no visible effect" (not necessarily a failure — could be a disabled button or informational element).
7. **Error/crash/404?** → Record FAIL. Screenshot → `./ui-test-screenshots/{role}/failures/{page}-element-{i}-{element-text}.png`.

#### Snapshot Parsing

Use `agent-browser snapshot -i -c --json` to get the interactive elements tree. Parse the JSON output to extract:

```json
{
  "data": {
    "snapshot": "- button \"Sign In\" [ref=e4]\n- link \"Dashboard\" [ref=e5]\n..."
  }
}
```

Parse each line to extract:
- Element type (button, link, textbox, combobox, checkbox, switch, tab, menuitem)
- Text/label (the quoted string)
- Ref (the `@eN` identifier)
- Attributes (required, expanded, selected, etc.)

**Filter out:**
- Elements with `disabled` attribute
- Elements with `aria-hidden="true"`
- Elements inside hidden containers
- The browser's own UI elements (scrollbars, etc.)

#### Error Handling Per Element

- **Element not found in fresh snapshot**: Mark as SKIPPED (may have been removed by previous interaction or DOM changed). Continue to i+1.
- **Click fails**: Retry once with 1s wait. If still fails, mark as FAIL. Continue to i+1.
- **Page crashes**: Mark as FAIL. Screenshot. Continue to i+1.
- **Timeout (5s)**: Mark as FAIL. Continue to i+1.

#### Coverage Tracking

For each page, track and report:
```
Page: {name}
  Total interactive elements found: N
  Tested: N (every single one)
  Passed: M
  Failed: K
  Skipped: S (disabled, hidden, or unsupported type)
  Coverage: 100% (N/N tested)
```

---

### Step 4D: Flow Testing (Full Mode Only)

For each flow in `config.flows[]`:

1. Check if `flow.role` matches the current role — skip if it doesn't
2. **Execute steps sequentially:**

   **`navigate` action:**
   - Go to `{baseUrl}{step.path}`
   - Wait 3s for page to load

   **`click` action:**
   - Click the element matching `step.selector`
   - Wait 2s for response

   **`fill` action:**
   - Fill the element matching `step.selector` with `step.value`
   - Wait 1s

   **`verify` action:**
   - Check the expectation in `step.expect`:
     - `toast:success` — success toast/message is visible
     - `toast:error` — error toast/message is visible
     - `url:/path` — current URL contains `/path`
     - `selector:.element` — element is visible
     - `text:"string"` — page contains the text
   - Wait 2s for expectation to be met

3. **If any step fails:**
   - Mark flow as FAILED
   - Screenshot → save to `./ui-test-screenshots/{role}/flows/{flow-name}.png`
   - Stop executing this flow, move to next flow

4. **If all steps pass:**
   - Mark flow as PASSED
   - Screenshot final state → save to `./ui-test-screenshots/{role}/flows/{flow-name}.png`

5. **Record results:**
   - Flow name, role, step-by-step results, final outcome

---

### Step 4E: Edge Case UI (Full Mode Only)

For each page:

1. Resize viewport to 768px width via qutebrowser
2. Wait 2s for layout to adjust
3. **Check for:**
   - Horizontal scroll (layout overflow)
   - Overlapping elements
   - Cut-off content
   - Broken or hidden navigation
4. **If issues found:**
   - Screenshot → save to `./ui-test-screenshots/{role}/failures/{page}-768px.png`
   - Record the specific issue
5. Resize back to default width (1280px or original)

---

## Phase 3: Generate Report

After all roles are tested, generate `./UI-QA.md`:

### Severity Grading Criteria

| Severity | Label | Criteria |
|----------|-------|----------|
| **P0** | Critical | Role leak (user sees admin-only elements), auth bypass, crash on page load for any role, login fails for all roles |
| **P1** | High | Broken buttons (click does nothing or causes error), 404 on valid routes, form submission failures, flow failures for primary journeys |
| **P2** | Medium | Layout issues at 768px, missing non-critical elements, confusing error states |
| **P3** | Low | Minor visual inconsistencies, non-critical UX issues |

### Verdict Logic

- **SHIP**: No P0 or P1 findings. All pages load for all roles. Role visibility is correct. All interactive elements pass.
- **FIX BEFORE SHIP**: Has P0 or P1 findings that are fixable.
- **DO NOT SHIP**: P0 findings indicating fundamental brokenness (login fails for all roles, crash on every page, data exposure).

### Report Template

Write to `./UI-QA.md`:

```markdown
# UI QA Report — {Project Name}

Date: {YYYY-MM-DD HH:MM}
Mode: {quick | full}
Target: {local | staging} URL

## Executive Summary

Verdict: {SHIP | FIX BEFORE SHIP | DO NOT SHIP}
Total pages tested: {N}
Total roles tested: {N}
Total interactive elements tested: {N}
Total findings: {N} (P0: {n}, P1: {n}, P2: {n}, P3: {n})

## Role × Page Matrix

| Page | {role1} | {role2} | {role3} |
|------|---------|---------|---------|
| {page1} | {PASS|FAIL} | {PASS|FAIL} | {PASS|FAIL} |
| {page2} | ... | ... | ... |

## Element Coverage

| Page | Elements Found | Tested | Passed | Failed | Skipped | Coverage |
|------|---------------|--------|--------|--------|---------|----------|
| {page1} | {N} | {N} | {M} | {K} | {S} | 100% |
| {page2} | ... | ... | ... | ... | ... | 100% |

## Page Details

### {Page Name} ({role})
- Status: {PASS|FAIL}
- Screenshot: [view](./ui-test-screenshots/{role}/{page-name}.png)
- Visibility: {all expected elements visible | issues found}
- Interactive elements: {N} found, {N} tested, {M} passed, {K} failed, {S} skipped

### Failed Elements
{List each failed element with:}
- Element #{i}: {type} "{text}"
- Action: {what was done}
- Result: {what happened}
- Screenshot: [view](./ui-test-screenshots/...)

## Flow Results
{If full mode and flows exist:}

| Flow | Role | Status |
|------|------|--------|
| {flow-name} | {role} | {PASS|FAIL} |

## Findings

### P0 — Critical

#### {Finding title}
- **Description**: {what's wrong}
- **Affected**: {which page/role}
- **Evidence**: [screenshot](./ui-test-screenshots/...)

### P1 — High

{Same format as P0}

### P2 — Medium

{Same format as P0}

### P3 — Low

{Same format as P0}

## Screenshots

{Gallery of all screenshots with role/page labels}
```

---

## Phase 4: Cleanup

Always execute, even on partial failure:

```bash
pkill -f qutebrowser 2>/dev/null
sleep 1
pkill -f qutebrowser 2>/dev/null
```

If the report was not fully generated due to timeout/interruption, write whatever was collected so far to `./UI-QA.md` with a note: "UI testing interrupted — partial results only."

---

## Config Example

```json
{
  "target": {
    "local": "http://localhost:3000",
    "staging": "https://staging.aenoxa.com"
  },
  "login": {
    "url": "/login",
    "emailField": "input[name='email']",
    "passwordField": "input[name='password']",
    "submitSelector": "button[type='submit']",
    "successIndicator": "url:/dashboard"
  },
  "roles": [
    {
      "name": "admin",
      "email": "admin@aenoxa.com",
      "password": "password123"
    },
    {
      "name": "user",
      "email": "user@aenoxa.com",
      "password": "password123"
    }
  ],
  "pages": [
    { "path": "/dashboard", "name": "Dashboard" },
    { "path": "/dashboard/billing", "name": "Billing" },
    { "path": "/dashboard/settings", "name": "Settings" }
  ],
  "flows": [
    {
      "name": "create-product",
      "role": "admin",
      "steps": [
        { "action": "navigate", "path": "/dashboard/products" },
        { "action": "click", "selector": "button:contains('Add Product')" },
        { "action": "fill", "selector": "input[name='name']", "value": "Test Product" },
        { "action": "click", "selector": "button:contains('Save')" },
        { "action": "verify", "expect": "toast:success" }
      ]
    }
  ],
  "visibility": {
    "admin": {
      "shouldSee": [".admin-panel", ".user-management"],
      "shouldNotSee": []
    },
    "user": {
      "shouldSee": [".user-dashboard"],
      "shouldNotSee": [".admin-panel", ".user-management"]
    }
  }
}
```

---

## Implementation Notes

### Critical: Use `fill` Not `type` for Form Inputs

When using agent-browser to fill form fields (login, search, etc.), **always use `fill`** not `type`:

```bash
# CORRECT — fill clears the field first, then types
agent-browser fill @e5 "user@example.com"

# WRONG — type appends to existing content, corrupting input
agent-browser type @e5 "user@example.com"
```

`type` appends text without clearing. If the field has browser autocomplete, placeholder residue, or leftover text from a previous attempt, the credentials get corrupted.

### Session Management During Long Runs

The JWT access token has a 15-minute TTL. Full mode tests can exceed this. Two strategies:

**Strategy A: Periodic session keep-alive**
Every 10 minutes, navigate to a neutral page (like `/dashboard`) to trigger the middleware's proactive refresh. This keeps the session alive without re-login.

**Strategy B: Hybrid element testing (recommended)**
Instead of isolate-per-element for ALL elements (which is too slow), use a two-pass approach:
1. **Pass 1**: Test all non-DOM-changing elements in one page visit (fast, ~80% coverage)
2. **Pass 2**: Test DOM-changing elements (expand/collapse, tabs) with isolated navigation (the remaining ~20%)

This achieves near-100% coverage in half the time, staying within the session TTL.

### Re-login Script (Fallback)

If session expires and middleware refresh fails, re-login through the full flow:

```python
# 1. Navigate to login page
navigate("/login")
sleep(2)

# 2. Find form elements via snapshot
elements = snapshot()
email_el = find_element(elements, 'textbox', 'Email')
pass_el = find_element(elements, 'textbox', 'Password')
signin_el = find_element_by_text(elements, 'button', 'Sign In')

# 3. Fill credentials using FILL, not type
click_ref(f"@{email_el['ref']}")
sleep(0.5)
run(f'agent-browser fill @{email_el["ref"]} "user@example.com"')
sleep(0.5)
click_ref(f"@{pass_el['ref']}")
sleep(0.5)
run(f'agent-browser fill @{pass_el["ref"]} "password123"')
sleep(0.5)
click_ref(f"@{signin_el['ref']}")
sleep(5)

# 4. Handle tenant selection if applicable
elements = snapshot()
for el in elements:
    if 'Tenant Name' in el['text']:
        click_ref(f"@{el['ref']}")
        sleep(5)
        break

# 5. Navigate to dashboard/landing
elements = snapshot()
for el in elements:
    if 'Back Office' in el['text'] or 'Dashboard' in el['text']:
        click_ref(f"@{el['ref']}")
        sleep(5)
        break
```

### Snapshot Parsing Gotchas

- Element text may contain newlines or extra whitespace — normalize before matching
- Some elements have no text (icons, checkboxes) — match by type + attributes
- Duplicate elements with same text — use position index to disambiguate
- The `combobox` type in snapshots may appear as `combobox "(no text)"` — handle empty text gracefully
