# /qa — Shared-env & linear-runner safety dossier

Depth + evidence behind SKILL.md §8. The HARD rules + the 5-step worked recipe live inline in §8;
this file carries the narrative, the incident record, and the fitest-specific point-in-time facts.

**Point-in-time notice:** the fitest/BMS mechanics below were verified 2026-06. The fitest platform
drifts — re-verify against the live UI before relying on any endpoint/column/selector. Credentials live
in `~/.claude/secrets.env`; this file names ENV-VAR NAMES only, never values.

---

## 1. Maker-checker approve hazard — the incident + the protocol (HR-5, HR-6)

### What happened (2026-06-05, verified)
During VIP full-cycle test authoring on BMS WebAdmin (a SHARED test env), an approve step targeted the
**temporal top pending row**. The maker submit was a NO-OP (the edit field already held the value the
base suite sets), so it produced NO fresh approval request. With `cancel_on_first_fail` OFF, the failed
"fresh request present" verify did NOT halt (see §2), so the approve step blind-approved whatever stale
request sat at the top of the VIP queue — processing 2-3 pending CREATE requests submitted by
admin/staff awaiting a checker. It materialized those VIPs (additive), stamped `admin@client.example` as
checker in the audit trail, and drained the pending queue. (An initial "deleted the 8000001 fixture"
alarm was RETRACTED by read-only forensics: all approvals were Create-type, zero Deletes; the fixture's
absence was ~11 days old and unrelated.) Lower severity than first flagged, but it touched a partner's
shared env + audit trail.

### The mandatory protocol (any approve/reject/delete on a shared queue)
1. `cancel_on_first_fail = ON` where the runner honors it (fast-red signal) — but NEVER rely on it as
   the safety net (§2 proves it does not halt for `verify_element`).
2. Approve ONLY on a POSITIVE token/CIF/datakey match of the request THIS run submitted. NEVER temporal
   "top row" / newest.
3. Guarantee the submit lands a FRESH pending request: edit = a real field change/increment; delete =
   the entity must exist; create = a fresh unique key. A no-op submit = no fresh request = the trap.
4. Use a disposable entity you fully control as the fixture; don't depend on a shared fixture other
   suites also mutate.
5. Exactly-1-own rail: at each checker step confirm the requester-filtered queue returns EXACTLY 1
   pending (your own). HALT if >1 — a concurrent session breaks "newest=own". (Earned its keep when Ryan
   was concurrently on `qa@qa.com` mid-run.)

### Requester-cell HARD anchor (SC-138/139/140, supersedes positional)
Where the approval queue exposes a REQUESTER column, put it IN the approve row-xpath:
`//tr[td='<menuType>'][td contains '<requester>'][td contains 'Need Approval']` → HARD-excludes
other-account rows BY CONSTRUCTION, not by position. Then exactly-1-own among same-account (pre-clean
own leftovers) + a soft eye-modal token as leg-2. NOTE: some queues expose the requester as a numeric
user-id (e.g. `'221'` = `admin@client.example`) rather than the email — anchor on whatever that queue shows.

### Good epistemics (the pattern that worked)
The worker over-flagged the worst case cautiously, then did READ-ONLY forensics on the audit/activity
log and honestly RETRACTED with evidence. Over-flag + correct beats under-flag. Main held all mutations,
looped Christopher before remediation/disclosure (partner's env = relationship-sensitive), then disclosed
proportionately once de-escalated.

---

## 2. `verify_element` does NOT halt — the load-bearing safety fact (HR-6)

**Verified 2026-06-19 (runs 3207-3210).** In fitest, a failed `verify_element` step does NOT halt the
run — EVEN when `cancel_on_first_fail` ("Cancel on first failed step") is ticked. That flag is IGNORED
for `verify_element` failures; the run continues to the next step. (Linear = steps run in fixed order,
TRUE. Halt-on-any-failure = FALSE for `verify_element`.)

Consequence: a sequence `step13 verify_element(synthetic row present)` → `step14 click(approve/reject)`
does NOT guarantee step14 is skipped when the row is absent. **Step14 still fires.**

### The real guarantee: synthetic-anchored destructive locators
Re-run safety for a destructive maker-checker suite must come from the destructive locator ITSELF being
synthetic-anchored so that, when the intended synthetic target is absent, the click resolves to no
element and no-ops (fitest marks the step failed but performs no DOM action — you can't click what
doesn't exist).

Pattern that holds (verified on 884/885/873/874):
- `send_keys` a synthetic-only search string into the queue filter (e.g. literally
  `'Seed VIP approval request'`) — excludes real rows client-side.
- The destructive `click` xpath is double-anchored, never by position:
  `(//table//tbody/tr[.//td[contains(normalize-space(),'<synthetic string>')]][.//*[local-name()='svg' and contains(@class,'lucide-check')]])[1]//button[...]`
  — predicate = row whose cell text contains the synthetic string AND carries the approve/reject
  affordance, then `[1]`. NOT `(//tbody/tr)[1]` / first-pending.
- Seed absent → xpath matches nothing → click no-ops → queue untouched. Worst case (a synthetic seed
  exists) → it actions a `'Seed …'` synthetic row ONLY, never a real/human row.

**SVG-icon trap:** SVG lives in the SVG namespace, so an unprefixed `//svg[...]` in XPath matches
NOTHING under fitest's Selenium chromedriver (`document.evaluate`). ALWAYS use
`//*[local-name()='svg' and contains(@class,'lucide-check')]`. A CSS `querySelector('svg.lucide-check')`
"verifies" fine in a browser console (CSS ignores namespaces) so a locator can look validated yet match
0 at run time. Verify icon locators with `document.evaluate` (XPath), not `querySelector` (CSS).

### When AUDITING a destructive re-run
Verify the destructive step's OWN locator is synthetic-anchored from the raw step def. Do NOT accept "a
verify gate precedes it so a halt protects us" — read the raw locator, confirm the synthetic predicate.

---

## 3. Data-state assertion model, NOT the toast (HR-7)

Assert on the OUTCOME in the data/UI, never on a "berhasil"/"Request created" toast (a toast can fire
even when data did not persist = false-pass). Verified: a "Request created for approval" toast was a
FALSE SUCCESS (request silently dropped); confirming the request actually landed in the queue (ID-gap
check: would-be IDs simply don't exist) caught 2 of 3 SC-138/139 defects after an initial wrong
"not-a-defect" read that trusted the toast.

Archetypes (EXTENSIBLE — confirm each on the live run):
- **Add / Tambah** (no maker-checker): search the datakey → new row APPEARS.
- **Edit / Ubah**: search the datakey → row shows the CHANGED value(s).
- **Delete / Hapus**: search the datakey → row is GONE ("Tidak ada data" / no match).
- **View / Detail**: it RENDERS and shows the expected info.
- **Maker-checker CRUD = split across two suites**: the maker suite goes only to "request submitted"
  and asserts the maker-side success; the checker (approve/reject) is a SEPARATE suite on the approval
  menu. Checker/action-suite success = a NO-ERROR gate (no error toast/alert, dialog closed) rather
  than a specific success-toast text (wording differs per action → fixed-text waits false-fail).
- **Special non-CRUD**: read the rendered cell/toggle state directly.

Add/edit/delete are the SAME move: re-search by datakey, compare the table dataset to the expected
post-op state.

### Network-log masked-failure scan (browser flows)
A create/update/delete CLICK passes as a UI step even when the backend rejects (4xx/5xx). For
browser-exercised flows, pull `agent-browser network requests --filter api --type xhr,fetch` and flag
any `>=400` behind a "passing" step. In fitest run CSVs the equivalent is the `Network_Log` column
(embeds method/url/status/response_body) — scan for `>=400` to catch masked backend bugs (ticket #33
pattern); first-fail triage alone misses them.

---

## 4. Mutation policy — the gate is REAL DATA, not the prod URL (HR-4)

Christopher (2026-06-22): mutations (create/update/delete) on a "prod" deployment are FINE as long as
you operate with test creds on a designated test tenant. **The gate for a write is whether it touches
REAL data, not whether the URL is the prod deployment.** For Pulse, test creds map to the Alamanda
Coffee test tenant (seeded test data) — any agent doing QA/capture there MAY exercise mutators to reach
and verify states that read-only cannot.

Guardrails (correct scoping, NOT caution):
- Mutations stay scoped to the test tenant / test creds.
- On a shared multi-tenant deployment, NEVER mutate OTHER (real) tenants.
- Additive state-creation is safe; wholesale deletion that removes seed data the tenant still needs is
  NOT.

This is why "read-only on prod" was overcautious: it capped coverage (the atlas smoke logged only ~73%
state coverage because the tenant had no draft orders / non-cash payments to observe; with mutations
allowed it can CREATE and capture them).

---

## 5. External-facing outputs — QA scope + FE-observable framing (HR-16)

The internal `./QA.md` may cite source freely. Anything LEAVING the house (ISI/BMS tickets, client
reports, team comms):

- **FE-observable framing only (Ryan, 2026-05-26):** frame bugs strictly from the test-suite /
  FE-observable angle. NEVER cite reading the code, prisma, route handlers, or source. The QA/test
  team's official position is that it has no backend/codebase access. Example: the orphaned-approval
  bug → "submitted change does not appear in the approval queue / cannot be approved" (observable), NOT
  "the route writes the wrong status" (source).
- **QA-scope discipline (Christopher, 2026-06-03):** report the FINDING + flag the blocker; do NOT
  prescribe dev-side actions ("deploy the table", "change X in the backend", "add a CF rule",
  "redeploy Y"). Those are the dev team's call. IN-SCOPE: ticket status, re-runs, test-data notes,
  suite authoring. Ask "how do you want to handle it?" rather than prescribe.
- Source-knowledge is INTERNAL — use it to GUIDE test-authoring, never surface it externally.

---

## 6. Human-first test authoring — done-gates (HR-17)

When /qa AUTHORS test artifacts a human team will own, audit, and maintain:

- Get their AGREED STANDARD + practice UP FRONT. None exists → propose a SIMPLE, human-readable one and
  get sign-off before scaling — do not fill the vacuum with automation-optimal complexity.
- Validate the convention on 1-2 concrete examples WITH the human owner before scaling.
- Prefer simple + readable + auditable over clever + safe-but-opaque. Keep automation-internal
  complexity (safety harnesses, matching logic) OUT of what the human reads.
- **Verified failure (2026-06-05):** `fc-`-prefixed, hardened-auto-approve, breadth/depth full-cycle
  suites were technically sound but too complex/opaque for human QAs; Christopher + Ryan REDID every
  suite MANUALLY on a human-first standard.

### Evidence-capable-runner HARD done-gates (fitest, verified; Ryan-enforced)
A suite is NOT done unless BOTH hold, re-verified post-save:
1. **Screenshot enabled on EVERY step** (fitest: select-all → the bulk "Screenshot" button → save).
2. **Expected Results DEFINED** in the dedicated suite-level "Expected Results" section (NOT per-step,
   NOT the description text; the "No Expected" badge must be cleared; expect-PASS for happy-path,
   expect-fail for negative suites).
Recurrence 2026-06-18: Ryan caught a whole UMB batch with blank expected-results + screenshots-off
despite the rule existing since 2026-05-06 — write both gates explicitly into every authoring brief as a
checklist + verification step, belt-and-suspenders.

---

## 7. fitest run mechanics relevant to a QA run (verified 2026-06; re-verify live)

Only the facts a QA run actually needs. Full API doc = memory `reference_fitest_api_docs`.

- **Auth = DISTINCT fitest creds** (`FITEST_USER=chris` + `$FITEST_PASSWORD` in `~/.claude/secrets.env`),
  NOT the ISI email. fitest login is SEPARATE auth → wrong attempts do NOT risk BMS admin lockout.
- **DRIVER = `playwright` always for BMS WebAdmin** — chromedriver/selenium false-fails
  Tambah/heavy-modal/row-action steps (`reference_bms_webadmin_fitest_selenium_bug`).
- **Trigger a run:** `POST /executions/run/<sid>` (HTML form, not JSON);
  `driver=playwright&network_log_form_present=true&network_log_enabled=true&cancel_on_first_fail_form_present=1`;
  header `X-CSRFToken` = `document.querySelector('meta[name=csrf-token]').content`.
- **Poll:** `GET /test-suites/<sid>/recent-runs?page=1&per_page=3` → `{runs:[{id,status,passed_cases,
  failed_cases,total_cases}]}`. New run = id > pre-trigger latest.
- **Per-step triage:** `GET /executions/<run_id>/download/csv` → cols incl. `Success(PASS/FAIL)`,
  `Network_Log`. Scan `Network_Log` for `>=400` (masked backend bugs, §3).
- **WAF spacing:** Cloudflare blocked the IP at ~47 rapid runs once → keep `>=60s` between run triggers,
  sequential. Don't run parallel python/requests against fitest while a run-batch is active (contends on
  the shared session).
- **Batch login-flake:** a back-to-back maker-checker batch does ~40 BMS logins; the documented
  post-login/post-logout H1-render flake (~1-in-4) reds several suites per batch. FIX = per-suite RETRY
  (ISI standard) — each retried once → green at the same steps. A retry red at a NON-login step = a real
  bug, stop + flag.
- **`increment_value` is persistent per-case, not a run param:** `POST /test-cases/<case_id>/set-increment`
  `{"increment_value":true}`. Existing-entity maker-checker ops MUST use a FIXED valid datakey, not an
  increment (an incremented value isn't a real entity and fails validation) — which applies is a
  judgment call per step; if unsure, make the call and FLAG for human audit.
- **Object dedup by `(application_id, locator_value, action)`:** creating a search/input Object whose
  locator matches an existing one REUSES the existing Object including its stored VALUE, silently
  ignoring the value you passed — a search-value vs row-locator-value mismatch hides the target row.
  Always verify the actual VALUE on search/datakey inputs after authoring.
