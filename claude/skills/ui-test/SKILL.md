---
name: ui-test
description: Exhaustive per-role UI testing via the live qutebrowser proxy stack — logs in as every configured role, tests every interactive element on every page in BOTH themes with hazard-classified mutation safety, and writes a gated pass/fail report (UI-QA.md). Quick mode (crawl + visibility, both themes, ~10 min) and full mode (elements + flows + responsive, ~60-120 min). Report-only, never auto-fixes.
---

# /ui-test — Exhaustive Per-Role UI Testing (report-only)

**Every element. Every page. Every role. Both themes. No sampling.** The run drives
**Christopher's LIVE qutebrowser** through the multi-port tab-isolation proxy — every browser
mechanic in this skill defers to the **agent-browser skill** (`~/.claude/skills/agent-browser/SKILL.md`);
read its §1 HARD RULES before the first command. This skill adds the testing layer on top:
role lifecycle, hazard-safe element interaction, theme/locale axes, quantified gates, and the
UI-QA.md verdict.

## 0. FAILING NOW? — jump table

| Symptom right now | Go to |
|---|---|
| Login fails for a role | **UT-PB-A** (retry ladder, OAuth-only detection) |
| Crawled page redirects to `/login` mid-run | **UT-PB-B** session expired (re-login + resume) |
| Every page after some point FAILs / redirects to login | **UT-PB-C** premature logout (misclassified session hazard) |
| Native OS picker (printer/bluetooth/file) opened, tab frozen | **UT-PB-D** — do NOT screenshot; release + re-claim |
| Tab gone after a long analysis pause (>600s idle) | **UT-PB-E** reaper ate the tab (re-claim + resume) |
| EVERY page suddenly fails / `Page.navigate` times out | agent-browser **§10.0 wedge ladder** — `top` FIRST (server pegged?) |
| `curl :9222` dead | agent-browser **PB-1** (proxy restart — proxy ONLY) |
| `curl :2262` dead / tabs never commit | agent-browser **PB-2** — **STOP, human-gated**; report "qutebrowser needs `:restart`", never do it |
| Command hangs ~25s then errors | agent-browser **PB-3** |
| Blank/black screenshot | agent-browser **PB-4** (retry → qb-shoot at `~/.config/qutebrowser/scripts/qb-shoot`) |
| `--full` shot oversized, content top-left | agent-browser **PB-5** (trim — `--full` outputs ONLY) |
| Eval returns `about:blank` / wrong tab driven | agent-browser **PB-6** |
| Snapshot shows the OLD page after a click | agent-browser **PB-7** (SPA race — `wait --load networkidle`) |
| Cert error opening the target | agent-browser **PB-8** (`/claim?url=`) |
| Dark screenshots of a light page (or vice versa) | agent-browser **§9.4** — re-pin `AGENT_BROWSER_COLOR_SCHEME`, re-shoot the batch |
| `503 No free ports` on /claim | agent-browser §0 "No free ports" row + §6.3 (release ONLY provably dead entries — never a port with live connections) |

## 1. HARD RULES (UT-HR — memorize before Phase 1)

- **UT-HR-1 — NEVER kill or restart qutebrowser.** No process kill of the browser, under
  any circumstances, at any phase, including cleanup-on-failure (agent-browser HR-2 — it is
  Christopher's live authenticated browser, load-bearing for fitest/bcas). Role isolation is
  **claim → app-logout → release**, never process death. The old "fresh browser instance per
  role" model is RETIRED as verified-harmful. Greppable invariant: the string `pkill` must
  not appear anywhere else in this skill — even proxy restarts are agent-browser PB-1's job,
  cited, never inlined here.
- **UT-HR-2 — NEVER run `agent-browser cookies clear` or any global cookie/storage wipe.**
  The claimed tab shares Christopher's live qutebrowser profile — one cookie jar for
  everything he is logged into. Verified in 0.22.3 `cookies --help`: `clear` = "Clear all
  cookies", NO domain/url scoping (scoping flags exist only on `set`). Session reset between
  roles = **the target app's own logout flow**, verified by an auth-required page redirecting
  to login. App has no logout path → STOP, mark the remaining roles `BLOCKED(no logout)`,
  report — do not improvise a wipe.
- **UT-HR-3 — ALWAYS run on a claimed port.** `/claim?from=9223&url=<login-url>` → persist
  the run env file (`AGENT_BROWSER_CDP`, unique `AGENT_BROWSER_SESSION`,
  `AGENT_BROWSER_COLOR_SCHEME`) → `agent-browser connect $PORT` within 30s → verify
  `/target` → work → `agent-browser close` → `/release?port=$PORT` → verify `/sessions` no
  longer lists the port (agent-browser §6.3, R-1, HR-6/7/8). NEVER drive port 9222 for a
  test run — that is the interactive active-tab port Christopher may be looking at.
- **UT-HR-4 — NEVER test roles in parallel.** One qutebrowser profile = ONE cookie jar; a
  second role's login clobbers the first everywhere, including in Christopher's own tabs.
  Roles run strictly SEQUENTIALLY inside the one claimed tab: role N+1 logs in ONLY after
  role N's logout is verified. This is an architectural constraint, not a perf bug — do not
  "optimize" it onto multiple claimed ports. Parallelism, if any, is per-page ANALYSIS of
  already-captured artifacts, never per-role sessions.
- **UT-HR-5 — NEVER click a hazard-class element blind.** Classify EVERY element before
  interaction (§8). DESTRUCTIVE verbs (`delete|remove|hapus|clear|reset|wipe|purge`) → click
  to OPEN the confirm modal, verify the modal appears (that IS the PASS), then CANCEL — but
  ONLY when guard evidence exists or you are on the test-tenant tier; on real/unknown data
  with NO guard evidence, SKIP + record `hazard-unprobed` — click-probing an unguarded
  mutator "to see if a confirm appears" is the exact failure that suspended an owner account
  (atlas §6 R3/N13, 2026-06-22). IRREVERSIBLE sends (`send|kirim|pay|bayar|transfer|publish|email`)
  → same open-then-cancel, never confirm outside the test-tenant tier. SESSION
  (`logout|keluar|sign out`) → defer to the LAST element of the LAST page for that role.
  NATIVE-PICKER triggers (`printer|cetak|bluetooth|usb|camera|choose file|pilih file`) →
  SKIP + record: a native OS picker permanently blocks CDP screenshots on the tab
  (atlas §13.3 item 10; recovery = UT-PB-D). ACCOUNT/ACCESS controls
  (`suspend|deactivate|remove member|change role|reset password|PIN`) → SKIP at BOTH tiers, always.
- **UT-HR-6 — NEVER approve/reject/confirm in a maker-checker or shared approval queue** —
  even on a test env — unless THIS run created the pending request and positively matches it
  by token/value. Temporal "top pending row" targeting blind-approved strangers' requests in
  a partner's shared env (verified incident 2026-06-05,
  `feedback_maker_checker_approve_automation_hazard`).
- **UT-HR-7 — Mutations beyond open-then-cancel are allowed ONLY under test credentials on a
  designated test tenant** (config `mutationTier: "test-tenant"` + named tenant — the gate is
  "is it real data?", not "is it the prod URL"; cite atlas §7 for the full two-tier policy).
  Every executed mutation goes in the report's mutation ledger (§8.3). On real/unknown data
  the run is read-only + open-then-cancel. Never delete seed data others depend on;
  prefix created artifacts `UITEST-`.
- **UT-HR-8 — NEVER store or accept plaintext passwords silently.** Config uses
  `emailEnv`/`passwordEnv` names resolved from `~/.claude/secrets.env` at runtime. A literal
  `password` field triggers a BLOCKING gate (PF-5): inside a git work tree,
  `git check-ignore -q .ui-test-config.json` must pass or the run ABORTS with remediation
  instructions (gitignore the file, or migrate to env refs). NEVER echo credential values,
  NEVER screenshot a login form after credentials are filled, NEVER write creds or session
  tokens into UI-QA.md or screenshot filenames (agent-browser HR-15).
- **UT-HR-9 — ALWAYS pin the color scheme per theme pass** in the run env file: light pass
  `AGENT_BROWSER_COLOR_SCHEME=light`, dark pass `=dark` with the agent-browser §9.1
  brightness threshold INVERTED (dark shots of dark pages are expected ≤ ~0.4). An un-pinned
  batch is invalid evidence — CDP color-scheme drifts dark after browser restarts while the
  page displays light (agent-browser HR-16, §9.4).
- **UT-HR-10 — ALWAYS `agent-browser wait --load networkidle` (fallback `wait 2000`) after
  every navigation** before snapshot/screenshot (agent-browser HR-11). NEVER reuse an `@eN`
  ref across a DOM mutation (HR-10) — re-snapshot or use `find role|text|label` semantic
  locators (note: `find role button click --name X` is in 0.22.3 `--help` but unverified in
  this env, atlas §13.3 item 12 — on failure fall back to snapshot-then-act in the same
  step). Radix comboboxes open via `focus @ref` + `press Enter`, not click (agent-browser §5.2).
- **UT-HR-11 — ALWAYS run the PF gates (§5) before Phase 1**, including the dev-server CPU
  check (agent-browser HR-13). On mid-run failure of EVERY page, jump to the agent-browser
  §10.0 wedge ladder (server first) — do NOT record a page-crawl massacre as findings; a
  pegged `next dev` fabricates a DO-NOT-SHIP (verified 2026-07-02, an hour lost).
- **UT-HR-12 — Report-only.** NEVER auto-fix app code; NEVER modify the target project
  beyond writing `./UI-QA.md` + `./ui-test-screenshots/` (auto-fixing is /e2e's job). NEVER
  use Playwright/Chrome — hook-enforced at settings level (agent-browser HR-1); a denied
  Playwright call means the hook fired correctly, pivot here.
- **UT-HR-13 — ALWAYS apply the screenshot QA gate (§9.2) to every kept shot.** DPR trim
  ONLY on `--full` outputs showing the defect (agent-browser HR-12/PB-5); blank/black shots
  escalate retry → qb-shoot by absolute path `~/.config/qutebrowser/scripts/qb-shoot` (NOT
  on PATH — agent-browser PB-4/§9.3). Never silently keep or skip a failed shot.
- **UT-HR-14 — A run is not DONE until the teardown checklist (§11) passes AND UI-QA.md is
  written** — even on timeout/partial failure (partial results + an "interrupted" banner). A
  leaked claim parks a zombie tab in Christopher's browser (agent-browser HR-6).

## 2. WHAT /ui-test IS (boundary vs siblings)

Two invariants define this skill's unique cell — if a request doesn't need BOTH, route elsewhere:

1. **Every-element-every-role coverage with pass/fail judgment** — not a sample, not a
   single flow, not neutral capture.
2. **Report-only** — findings land in UI-QA.md; the fix loop belongs to someone else.

| You want | Use | Why not /ui-test |
|---|---|---|
| Exhaustive per-role element pass/fail + verdict | **/ui-test** | — |
| One feature/flow verified AND auto-fixed | **/e2e** | e2e fixes; ui-test never does |
| Adversarial multi-dimension codebase QA (code-level) | **/qa** | qa hammers the codebase; ui-test hammers the rendered UI |
| Neutral exhaustive capture/dossier, no pass/fail | **/atlas** | atlas documents; ui-test judges |
| Multi-lens readiness verdict across a whole repo | **/audit** | audit is code+arch lenses; ui-test is the browser lens only |

Composes: an /atlas dossier (surfaces, `confirmation_required` facts, element classes) is
excellent PRIOR input — it supplies guard evidence for §8 and a page inventory for the config.

## 3. MODES + QUANTIFIED BUDGETS

```
/ui-test quick   — page crawl + visibility, per role, BOTH themes            (~10 min)
/ui-test full    — quick + exhaustive elements + flows + responsive + locale (~60-120 min)
```

Optional flags: `--staging` / `--local` (target override), `--themes light` (light-only, needs
the config/exception in §7.6), `--role <name>` (single-role rerun after a fix).

| Budget | Value | On breach |
|---|---|---|
| Per-element interaction timeout | **5s**, then exactly **1 retry after 1s** | mark FAIL, continue |
| Per-page element-count trigger | **>40 interactive elements → hybrid two-pass MANDATORY** (§7.3) | isolate-everything is the disavowed slow path |
| Per-role hard timeout | **30 min** | record partials, verified logout, next role |
| Page load timeout | **15s** | mark FAIL, screenshot, continue |
| Login retry | **3 attempts, 2s backoff** | role FAILED, continue to next role (UT-PB-A) |
| Session keep-alive | navigate a neutral page every **min(10, ttlMinutes − 5) min** when config sets `session.ttlMinutes` | prevents UT-PB-B and the 600s tab reaper |
| Infinite-scroll bound | first viewport + **one** scroll page | note the bound in the report |

Keep quick mode genuinely quick: crawl + visibility only, no element pass, no responsive.
The theme axis doubles crawl cost — that is priced into the ~10 min, do not skip it to save time.

## 4. CONFIG CONTRACT (compact — full normative schema: `references/config-schema.md`)

Read `.ui-test-config.json` from the project root. **v1 configs remain valid** (the fielded
aenoxa_dashboard instance must still parse); v2 adds optional fields.

**Required:** `target.local` and/or `target.staging` · `login.url` · `login.emailField` ·
`login.passwordField` · `login.submitSelector` · `login.successIndicator`
(`url:/path` or `selector:.element`) · `roles[]` (≥1: `name` + credentials) · `pages[]`
(≥1: `path` + `name`). Under `auth.mode: "none"|"external"` the entire `login` block and
role credentials become optional (§7.7).

**Credentials (UT-HR-8):** preferred `roles[].emailEnv` / `roles[].passwordEnv` — names of
vars resolved from `~/.claude/secrets.env` at runtime. Legacy literal `email`/`password`
still parse but arm the PF-5 blocking gitignore gate.

**Optional v2:** `auth.mode` (`form` default | `none` | `external`) ·
`login.tenantSelector` (post-login tenant/workspace click step, Pulse-style) ·
`logout.url` / `logout.selector` · `session.ttlMinutes` · `themes[]` (default
`["light","dark"]`) · `locales[]` · `mutationTier` (`read-only` default | `test-tenant`) ·
`mutation.testTenant` · `budgets{}` overrides · `flows[]` · `visibility{}`.

**If config is missing/invalid:** report the SPECIFIC missing/invalid fields and abort. Do
not guess selectors.

## 5. PRE-FLIGHT GATES PF-1..PF-6 (ALL blocking, ~10s total, before Phase 1)

```bash
# PF-1 — proxy alive + spoof working (must print Chrome/134.0.0.0)
curl -s -m3 http://localhost:9222/json/version | python3 -c "import sys,json; print(json.load(sys.stdin)['Browser'])"
# PF-2 — qutebrowser CDP alive (must return an array; FAIL → STOP, human-gated, agent-browser PB-2)
curl -s -m3 http://localhost:2262/json/list | python3 -c "import sys,json; print(len(json.load(sys.stdin)),'targets')"
# PF-3 — claim capacity (a free port must exist in 9223-9236)
curl -s http://localhost:9222/sessions
# PF-4 — tooling present (qb-shoot is NOT on PATH — absolute path only)
ls -l ~/.config/qutebrowser/scripts/qb-shoot /usr/bin/convert /usr/bin/jq
# PF-5 — config valid + credentials resolve (see below)
# PF-6 — target sane (see below)
```

**PF-5 — config + credential gate.** Validate required fields (`jq` parse + field checks).
Resolve each role's `emailEnv`/`passwordEnv` WITHOUT printing values:

```bash
source ~/.claude/secrets.env
for v in $(jq -r '.roles[] | .emailEnv // empty, .passwordEnv // empty' .ui-test-config.json); do
  [ -n "${!v}" ] && echo "OK: \$$v resolves (non-empty)" || { echo "ABORT: \$$v is empty/unset"; exit 1; }
done
# Literal-password gate (only when a literal `password` field exists AND we are in a git work tree):
if jq -e '.roles[] | select(.password)' .ui-test-config.json >/dev/null 2>&1 \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git check-ignore -q .ui-test-config.json || {
    echo "ABORT: .ui-test-config.json holds a plaintext password and is NOT gitignored."
    echo "Fix: echo '.ui-test-config.json' >> .gitignore   (or migrate to emailEnv/passwordEnv)"; exit 1; }
fi
```

**PF-6 — target sanity.** (a) Dev-server CPU: `ps -eo pid,pcpu,comm,args --sort=-pcpu | head -5`
— the target's server process pegged >100% → fix/kill it first; prefer QA against a static
build (`pnpm build` + `python3 -m http.server` on `out/`) over `next dev` (agent-browser
HR-13; dev HMR also leaves stale inline styles that corrupt visual checks). (b) The target
URL answers HTML: `curl -sI -m5 <baseUrl>` → 200/30x. (c) Target choice: `target.local` if
its port answers, else `target.staging`; user `--staging`/`--local` overrides.

Any gate fails → do NOT start; jump to the mapped playbook or abort with the remediation text.

## 6. RUN LIFECYCLE — R-A (claim → sequential roles → teardown)

### 6.1 Claim + env file (once per run — agent-browser §6.3 is the normative recipe)

```bash
# Screenshots live in the project (./ui-test-screenshots/ — field-compatible);
# the env file does NOT (never committable):
ENV_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ui-test-env.XXXXXX")"
CLAIM=$(curl -s -G "http://localhost:9222/claim" \
        --data-urlencode "from=9223" \
        --data-urlencode "url=${BASE_URL}${LOGIN_URL}")
PORT=$(echo "$CLAIM" | jq -r .port); TAB=$(echo "$CLAIM" | jq -r '.tab // empty')
[ -n "$TAB" ] || echo "WARNING: tab-create-failed — port NOT isolated (agent-browser §6.3)"
cat > "$ENV_DIR/browser.env" <<EOF
export AGENT_BROWSER_CDP=$PORT
export AGENT_BROWSER_SESSION=uitest-$PORT-$$
export AGENT_BROWSER_COLOR_SCHEME=light
EOF
source "$ENV_DIR/browser.env"
agent-browser connect $PORT                          # within 30s of the claim (HR-8)
curl -s "http://localhost:$PORT/target"              # VERIFY: title/url = your login URL (HR-4/5)
```

**Every subsequent tool call starts with `source "$ENV_DIR/browser.env"`** — shell env does
not survive between calls (agent-browser §6.4). Create screenshot dirs:

```bash
for role in $(jq -r '.roles[].name' .ui-test-config.json); do
  mkdir -p "./ui-test-screenshots/$role/flows" "./ui-test-screenshots/$role/failures" "./ui-test-screenshots/$role/elements"
done
```

### 6.2 Per-role loop (STRICTLY sequential — UT-HR-4)

For each role in `roles[]`, in order:

1. **Login** (auth.mode `form`) — through the REAL login form, no cookie/token injection
   shortcuts (the login flow itself is under test): navigate `{baseUrl}{login.url}` →
   `wait --load networkidle` → snapshot → `fill` email field with `${!emailEnv}` → `fill`
   password field (ALWAYS
   `fill`, never `type` — type APPENDS and corrupts credentials) → click submit → wait up to
   10s for `login.successIndicator` (`url:` → current URL contains path; `selector:` →
   element visible). If `login.tenantSelector` is set, execute it now (click the configured
   tenant/workspace entry, re-verify successIndicator). No screenshot between fill and
   submit (UT-HR-8). Failure → UT-PB-A.
2. **Theme passes** (§7.6): for each theme in `themes[]` — switch via the app's own
   switcher, verify via eval, re-pin `AGENT_BROWSER_COLOR_SCHEME` in browser.env, re-source,
   then run the mode's dimensions (§7) for that theme.
3. **Logout** (the ONLY session reset — UT-HR-2): navigate `logout.url` if set, else click
   the element matching `logout.selector`, else find the app's logout UI (this is also the
   deferred HAZARD-SESSION element — clicking it here IS its test). **Verify**: navigate an
   auth-required page → `wait --load networkidle` → `agent-browser get url --json` must show
   redirect to `login.url`. Unverified logout → do NOT start the next role; retry once, then
   mark remaining roles `BLOCKED(logout unverified)` and go to teardown.
4. **30-min role clock** runs across steps 1-3; on breach record partials, still execute
   step 3 (verified logout), move on.

### 6.3 Teardown (always, even on failure — §11 checklist is blocking)

```bash
agent-browser close
curl -s "http://localhost:9222/release?port=$PORT"    # response must show released_tab/closed
curl -s http://localhost:9222/sessions                 # your port must be GONE
rm -rf "$ENV_DIR"                                      # kills the color-scheme pin with it
```

## 7. TEST DIMENSIONS

### 7.1 — 4A Page Crawl (quick + full)

For each page in `pages[]`: navigate `{baseUrl}{page.path}` → `agent-browser wait --load
networkidle` (fallback `wait 2000`) → check error indicators: page text contains
"404" / "Not Found" / "Error" / "Something went wrong"; crash/blank screen; visible error
toast. Screenshot policy: full mode always (`./ui-test-screenshots/{role}/{page}-{theme}.png`);
quick mode only on failure (`.../failures/{page}-{theme}.png`). Every kept shot passes the
§9.2 QA gate. Page not loaded in 15s or 404 → FAIL, screenshot, continue. An **empty-state
page (0 interactive elements) is a VALID result**, not a parse failure. A redirect to
`login.url` here is NOT a page failure — it is UT-PB-B (session expiry).

### 7.2 — 4B Visibility Check (quick + full)

If `visibility[role]` exists: every `shouldSee[]` selector must exist AND be visible (PASS)
— hidden/missing → FAIL; every `shouldNotSee[]` selector must be hidden/absent (PASS) —
visible → **FAIL, and a role-leak candidate → P0 review** (§9.1). Any failure → screenshot
`.../failures/visibility-{role}-{theme}.png`. No entry for this role → record
`NOT_CONFIGURED` (never silently skip). Run in the FIRST theme pass only (visibility is
theme-independent); parity issues are caught by §7.6.

### 7.3 — 4C Exhaustive Element Testing (full mode) — THE HYBRID TWO-PASS ALGORITHM

The full algorithm, element type matrix, and parsing gotchas live in
`references/element-playbook.md`. The operating summary:

1. Navigate to the page, `wait --load networkidle`, `agent-browser snapshot -i -c --json`.
2. **Classify every element** (§8) — the hazard classifier runs BEFORE any interaction.
3. **Pass 1 (single visit):** test all NON-DOM-mutating elements in one page visit — links
   (nav verified by URL change then `back`), textboxes (`fill "test123"`), checkboxes,
   switches, simple buttons whose effect is a toast/inline change. Re-snapshot whenever a
   prior interaction mutated the DOM (UT-HR-10).
4. **Pass 2 (isolate-per-element):** ONLY for DOM-churny elements (expanders, tabs,
   modal-opening buttons, menus): navigate away → back → `wait` → fresh snapshot → find the
   element by identity (type + text + position) → interact → verify → record. The
   away-and-back guarantees a default-state re-render — no collapsed menus, no open modals,
   no toggled switches contaminating the next element's test.
5. Outcome verification order (check in sequence): URL changed → PASS(nav); modal appeared →
   PASS; toast appeared → PASS (screenshot IMMEDIATELY — toasts can auto-dismiss <2s);
   content changed → PASS; element state changed → PASS; **nothing happened → record
   exactly "no visible effect"** (NOT a FAIL and NOT a PASS — check `is enabled` and mark
   informational if disabled); error/crash/404 → FAIL + screenshot
   `.../failures/{page}-element-{i}-{text}.png`.
6. Per-element error handling: not re-found in fresh snapshot → SKIPPED(`not-refound`);
   click fails → 1 retry after 1s, then FAIL; crash → FAIL + screenshot; 5s timeout → FAIL.
7. **Coverage arithmetic (per page, mandatory):** `found == tested + skipped`, every skip
   with an enumerated reason (`disabled | hidden | unsupported-type | hazard-native |
   hazard-unprobed | hazard-deferred | not-refound`). Unexplained delta → run marked
   INCOMPLETE, verdict capped at FIX BEFORE SHIP (§9.3). The phrase "Coverage: 100%" is
   BANNED unless the arithmetic line proves it.

Pages with >40 interactive elements MUST use this hybrid (Budget table §3);
isolate-per-element for ALL elements is the disavowed 2-3x-slower path — it exists only as
pass 2.

### 7.4 — 4D Flow Testing (full mode)

For each flow in `flows[]` whose `role` matches the current role, execute steps sequentially:

- `navigate` → go to `{baseUrl}{step.path}`, `wait --load networkidle`.
- `click` → click `step.selector` (prefer `find role|text|label`; fallback snapshot-then-act).
- `fill` → fill `step.selector` with `step.value` (fill, never type).
- `verify` → `step.expect`: `toast:success` | `toast:error` | `url:/path` |
  `selector:.element` | `text:"string"` — wait up to 2s for the expectation.
- `verifyState` (v2, **REQUIRED as the final step of any flow containing a mutating step**):
  navigate to the given path and assert presence/absence of the given selector/text — a
  success toast is a CLAIM, persistence is the PROOF (`feedback_verify_after_write`: two
  verified silent-fail incidents where the 200/toast lied). Example: create-product flow
  ends by revisiting the product list and asserting the row exists.

Step fails → flow FAILED, screenshot `.../flows/{flow-name}-{theme}.png`, stop this flow,
continue to the next. All steps pass → PASSED + final-state screenshot. A flow whose
mutating step actually persisted on the test tenant → mutation ledger entry (§8.3). Flows
run in the primary theme only.

### 7.5 — 4E Responsive Pass (full mode) — R-D

Per page, two breakpoints (Indonesia is mobile-first — the phone tier is NOT optional):

```bash
agent-browser set viewport 375 812     # phone
# navigate + wait, then per page:
agent-browser eval "document.scrollingElement.scrollWidth - document.scrollingElement.clientWidth"
#   > 0  → horizontal overflow → FAIL(P2) + screenshot .../failures/{page}-375-{theme}.png
# check: overlapping elements, cut-off content, broken/hidden navigation (snapshot + shot)
agent-browser set viewport 768 1024    # tablet — repeat checks
agent-browser set viewport 1280 800    # RESTORE — a §11 checklist item; a persisting
                                       # emulation corrupts every subsequent pass
```

Viewport emulation is necessary-NOT-sufficient for real-device bugs (touch, DPR, mobile
Chrome quirks) — note in the report that device-class findings need a real-device check
(`feedback_mobile_debug_first`).

### 7.6 — Theme axis (BOTH modes) — R-C

Light and dark are both first-class ("Toper will check both" — house Website Build
Defaults). Per role: run the light pass, then the dark pass.

**Theme switch recipe (R-C):** click the app's own theme switcher (find by
role/aria-label) → verify via eval:
`agent-browser eval "document.documentElement.className + '|' + (document.documentElement.dataset.theme||'')"`
must show the dark class/attr → update `AGENT_BROWSER_COLOR_SCHEME=dark` in browser.env →
re-source → re-crawl. Brightness gate INVERTS on the dark pass (UT-HR-9). Apps with only a
`system` option: use `agent-browser set media dark` AND verify the page actually flipped
(the env-var pin remains the evidence-integrity guard either way).

**Theme parity gate:** element visible/readable in one theme but unreadable/missing in the
other → **P1**. SHIP requires both passes complete for every role+page — OR config
`themes:["light"]` with the oneshot-webapp exception explicitly cited in the report
(pitch/demo one-shots are light-only BY RULE; everything else Aenoxa ships dark+light).

**Locale axis (optional, full mode):** config `locales[]` → crawl in the default locale;
spot-check the secondary locale on 2-3 key pages for hardcoded-English leakage (house i18n
default: id + en). Element text matching must be LOCALE-AWARE — match the crawl locale's
strings, or match by role+position (`references/element-playbook.md`).

### 7.7 — Auth-mode edge cases

- **`auth.mode: "none"`** (anonymous app — AURA precedent 2026-06-23): single implicit role
  `"anonymous"`, skip ALL login/logout machinery; everything else runs unchanged.
- **`auth.mode: "external"`** (wallet/SIWE/OAuth-only): the login flow itself is OUT of
  scope — element+page testing runs on the pre-authenticated claimed tab (the claimed tab
  shares the live profile's auth — agent-browser §8), write-gates are verified up to the
  auth boundary ("Connect wallet" gate renders = PASS), and the report SAYS so. If a form
  login page shows NO password field in the snapshot → `auth.mode` is misconfigured as
  `form` — abort with that guidance (UT-PB-A). Note: OAuth callbacks can be flaky for
  unrelated reasons (verified Pulse service-worker double-fetch history) — 3-attempt retry
  before concluding login is broken.
- **Tenant selection after login** (Pulse-style): `login.tenantSelector` config step; the
  Alamanda tenant exists ONLY on the toper289982 account — never mix accounts
  (`reference_pulse_test_creds`).

## 8. HAZARD CLASSIFICATION + MUTATION POLICY + LEDGER

### 8.1 The classifier (runs on every snapshot BEFORE any interaction)

Every interactive element gets exactly ONE class, by label/verb regex (EN + ID — full lists
in `references/element-playbook.md`) plus available guard evidence:

| Class | Trigger (EN + ID verbs) | Action |
|---|---|---|
| **SAFE** | no verb match AND no destructive iconography label (e.g. `aria-label="trash"`) | interact per element-type matrix |
| **NAV** | link semantics / URL-changing | click → verify URL → `back` |
| **FORM** | textbox/checkbox/switch/combobox/tab | fill "test123" / toggle / keyboard-open |
| **HAZARD-DESTRUCTIVE** | `delete|remove|hapus|clear|reset|wipe|purge` | guard evidence or test tenant → open confirm → verify modal (=PASS) → CANCEL → re-snapshot (modal closed). Real data + no evidence → SKIP(`hazard-unprobed`) |
| **HAZARD-IRREVERSIBLE** | `send|kirim|pay|bayar|transfer|publish|terbitkan|email|checkout|mint` | open-then-cancel only; CONFIRM only on the test tenant + ledger. Approval queues: UT-HR-6 positive-match or never |
| **HAZARD-SESSION** | `logout|keluar|sign out|log out` | DEFER to the last element of the last page for the role (clicking it there is both its test and the role's logout) |
| **HAZARD-NATIVE** | `printer|print|cetak|bluetooth|usb|camera|kamera|scan|choose file|pilih file|upload` | SKIP + record — NEVER click (atlas §13.3 items 10 & 14) |
| **HAZARD-ACCOUNT** | `suspend|deactivate|nonaktifkan|remove member|change role|ubah peran|reset password|ganti PIN|permission` | SKIP at BOTH tiers, always (atlas N13 — the 2026-06-22 suspend incident) |

Report per-class counts per page. "Unclassified" is not a class — an element that fits
nothing defaults to SAFE only when BOTH conditions in the SAFE row hold.

### 8.2 Two-tier mutation policy (cite: atlas §7 — do not re-derive)

| Tier | When | Element pass may |
|---|---|---|
| **Read-only + open-then-cancel** (DEFAULT) | real / unknown data; `mutationTier` unset or `read-only` | everything except persisting a mutation; hazard rows per §8.1 |
| **Test-tenant mutations** | config `mutationTier: "test-tenant"` + `mutation.testTenant` named + test creds | persist create/edit (flows, element confirms) — scoped to THAT tenant only, additive not seed-destructive, `UITEST-` artifact prefix, every mutation ledgered |

### 8.3 The mutation ledger (append-only section in UI-QA.md)

Every EXECUTED mutation: `{page, element, action, entity created/changed, cleanup:
done | left-in-place + why}`. An empty ledger is itself a report line ("0 mutations
executed"). Teardown of created artifacts is HUMAN-GATED — list `UITEST-` artifacts for
Christopher; never bulk-delete.

## 9. SEVERITY + THE GATED VERDICT

### 9.1 Severity grading (unchanged floor + new rows)

| Severity | Criteria |
|---|---|
| **P0 — Critical** | role leak (user sees admin-only elements / `shouldNotSee` visible), auth bypass, crash on page load for any role, login fails for ALL roles, data exposure |
| **P1 — High** | broken buttons (click errors), 404 on valid routes, form submission failures, primary-flow failures, `verifyState` failure after a success toast (silent no-op write), **theme parity failure** (element unreadable/missing in one theme) |
| **P2 — Medium** | layout issues at 375/768px (overflow, overlap, cutoff), missing non-critical elements, confusing error states |
| **P3 — Low** | minor visual inconsistencies, non-critical UX issues, **typography floor violations** (UI text <12px or weight <500 — evidence = a computed-style eval, floors per the frontend-design skill) |

### 9.2 Screenshot QA gate (every batch — thresholds are agent-browser §9.1's, cited not re-derived)

`convert <f> -background white -flatten -colorspace Gray -format '%[fx:mean]' info:` —
light-pass shot of a light page expected ≥ ~0.6 (dark pass: inverted, expected low);
near-uniform frame (≈1.0 / ≈0.0) on a content page = blank → agent-browser PB-4 ladder;
`--full` canvas ~1.667x a viewport shot → PB-5 trim (that output only). Judged by `fx:mean`,
NEVER by eyeballing thumbnails (downscaled previews lie).

### 9.3 VERDICT LOGIC GATE — SHIP requires ALL of:

1. Zero P0 and zero P1 findings.
2. Login succeeded for every configured role (or auth.mode exempts it).
3. Coverage arithmetic passed on every page (`found == tested + skipped`, reasons enumerated).
4. Theme parity gate passed (both themes complete, or the light-only exception cited).
5. Every kept screenshot passed §9.2.
6. Mutation ledger empty or fully accounted (every entry has a cleanup status).

**FIX BEFORE SHIP** = fixable P0/P1 present, or the run is INCOMPLETE (coverage delta,
missing theme pass, interrupted). **DO NOT SHIP** = fundamental brokenness only: login
fails all roles, crash-on-load, role leak/auth bypass, data exposure.

**Anti-slop:** the verdict section MUST quote the specific gate results that produced it
(numbers, not adjectives). Every finding carries evidence — a screenshot path + what it
observably shows, or an eval result. The Role × Page matrix and coverage tables are
COMPUTED from recorded results, never templated in. Full report template:
`references/report-template.md`. Report path stays `./UI-QA.md` (overwritten each run).

## 10. FAILURE-MODE PLAYBOOKS

Browser-stack failures → the agent-browser playbooks by citation (jump table §0). ui-test's
own layer:

**UT-PB-A — LOGIN FAILS.** Retry 3x with 2s backoff. Still failing → screenshot the login
page (BEFORE any credential fill — UT-HR-8), mark the role FAILED, record the on-screen
error verbatim, continue to the NEXT role — never burn the 30-min budget on one login.
Snapshot shows NO password field → `auth.mode` misconfiguration (OAuth/wallet app declared
as `form`) → abort the run with that guidance instead of failing every role identically.

**UT-PB-B — SESSION EXPIRES MID-RUN.** Detected by a crawled page redirecting to
`login.url`. Run the config-driven re-login recipe (`references/element-playbook.md` §5) →
re-verify `successIndicator` (+ tenantSelector if set) → RESUME from the page that
redirected (do not restart the role; results already recorded stand). Recurs → set
`session.ttlMinutes` in config so the keep-alive budget (§3) engages; note fresh logins can
reset locale/tenant — re-select both before resuming (atlas §13.3 item 6).

**UT-PB-C — LOGOUT CLICKED PREMATURELY (session hazard misclassified).** Signature: every
page AFTER some element test redirects to login. STOP recording FAILs immediately —
everything after the event is contaminated. Re-login, re-run ONLY the pages after the
event, and fix the classification record (that element = HAZARD-SESSION, deferred).

**UT-PB-D — NATIVE PICKER OPENED ANYWAY.** Do NOT attempt any screenshot — the picker
blocks CDP capture on that tab PERMANENTLY (atlas §13.3 item 10). Record the element
`blocked(native OS picker)`, then: `agent-browser close` → `/release?port=$PORT` → `/claim`
a fresh port → new browser.env → connect → re-login the current role → resume AFTER the
offending element.

**UT-PB-E — REAPER ATE THE TAB** (>600s idle mid-run, e.g. a long analysis pause).
Symptom: connection refused / target gone. `/claim` fresh → new env file → connect →
re-login current role → resume from the last recorded page. Prevention: the keep-alive
budget (§3) — touch the tab at least every 10 min.

**MASS-FAILURE RULE (UT-HR-11).** Every page suddenly failing is a STACK symptom, not 20
findings: jump to the agent-browser §10.0 wedge ladder, step 1 = `top` (a pegged dev server
fabricates a massacre). Findings recorded during a diagnosed wedge window are DISCARDED and
those pages re-run.

## 11. TEARDOWN CHECKLIST (blocking — the run is not DONE until ALL pass)

- [ ] `agent-browser close` — daemon down.
- [ ] `curl -s "http://localhost:9222/release?port=$PORT"` — response shows `released_tab`/`closed`.
- [ ] `curl -s http://localhost:9222/sessions` — the port is no longer listed.
- [ ] Viewport restored (1280x800) if §7.5 ran.
- [ ] Run env file deleted (`rm -rf "$ENV_DIR"`) — the color-scheme pin dies with it.
- [ ] Credential hygiene grep is CLEAN:
      `grep -nE 'eyJ[A-Za-z0-9_-]{20,}|Bearer [A-Za-z0-9]|password.{0,3}[:=]' UI-QA.md` → no hits;
      no credential value in any screenshot filename.
- [ ] `./UI-QA.md` written — even on interruption, with partial results + the banner
      "UI testing interrupted — partial results only" (UT-HR-14).
- [ ] Mutation ledger present (even if "0 mutations executed").

## 12. DO / DON'T

| DO | DON'T |
|---|---|
| `fill @e5 "$EMAIL"` (clears first) | `type` for credentials — it APPENDS and corrupts them |
| `find role\|text\|label` / re-snapshot per interaction | reuse a positional `@eN` across a DOM mutation |
| `wait --load networkidle` after every nav | `sleep 3` and hope |
| `/claim?from=9223` + env file + `/release` | drive 9222, or leave a claim leaked |
| App-logout between roles, verified by redirect | `cookies clear` — nukes Christopher's every session |
| Open confirm modal → verify → CANCEL (with guard evidence) | blind-confirm, blind-approve, or click-probe unguarded destroyers on real data |
| Sequential roles in one claimed tab | parallel role sessions (one profile = one cookie jar) |
| Hybrid two-pass on element-heavy pages | isolate-per-element for everything (2-3x slower, same coverage) |
| Screenshots into `./ui-test-screenshots/{role}/` | /tmp captures of an authenticated app (agent-browser HR-15) |
| Report evidence ("shot X shows the toast; list re-fetch shows the row") | report claims ("verified it works") |
| Record "no visible effect" as exactly that | inflate it to PASS or FAIL without a disabled/informational check |
| `top` first when every page wedges | an hour of CDP archaeology while `next dev` burns a core |

## 13. REFERENCES (progressive disclosure)

- `references/config-schema.md` — normative v2 schema for `.ui-test-config.json` (v1
  back-compat guaranteed), field-by-field spec, three worked examples: multi-role form-auth
  (Pulse-shaped, env-ref creds), anonymous/wallet app (AURA-shaped), light-only oneshot demo.
- `references/element-playbook.md` — the hybrid two-pass algorithm in full, element type
  matrix (incl. Radix keyboard-open, slider/colorpicker skip reasons), hazard regex lists
  (EN + ID), snapshot parsing gotchas, outcome verification detail, the config-driven
  re-login recipe (+ labeled Pulse example with `$PULSE_TEST_*` env refs).
- `references/report-template.md` — the full UI-QA.md template: role×page matrix, coverage
  arithmetic tables, theme parity section, mutation ledger, gate-results block, screenshot
  gallery conventions, interruption banner.
- Browser mechanics ground truth: `~/.claude/skills/agent-browser/SKILL.md` (HR-1..17,
  PB-1..9, §3 pre-flight, §6.3 claim lifecycle, §9 screenshot gates, §12 teardown).
- Mutation-tier rationale + field frictions: `~/.claude/skills/atlas/SKILL.md` §6-§7, §13.3.
- Design-quality floors: `~/.claude/skills/frontend-design/SKILL.md` (typography floors,
  theme polish bar) — cite, don't restate.
