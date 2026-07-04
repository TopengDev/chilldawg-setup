# /e2e — Worked Flow Recipes

Companion to `../SKILL.md`. Every recipe names its verification step explicitly — "ran the
command" is never done. Browser mechanics cite the agent-browser skill
(`~/.claude/skills/agent-browser/SKILL.md`) by section — never re-derive them from here.

Conventions used throughout:

```bash
EVID=~/claude/notes/<task-slug>-<date>/evidence   # or the session scratchpad — NEVER shared /tmp (E-17)
mkdir -p "$EVID"
```

Locator note: the `find role button click --name "X"` form used below is agent-browser §5.1's
canonical shape, but the `--name` flag is UNVERIFIED in this env (atlas §13.3 item 12). If it
errors ("Unknown subaction" / no match), fall back in the same step to
`agent-browser snapshot -i -c --json` → locate the ref by accessible name → `click @ref` (E-18).

## Dev-server start/stop pattern (E-7-safe)

Start in its own process GROUP so teardown can kill the whole tree (`pnpm dev` spawns
children that survive a plain parent kill):

```bash
# START (only if nothing is already listening — check first!)
curl -s -o /dev/null -m2 http://localhost:3000 && echo "ALREADY RUNNING — reuse, never kill (E-7)" || {
  setsid pnpm dev > "$EVID/devserver.log" 2>&1 &
  echo $! > "$EVID/devserver.pid"          # setsid ⇒ PID == PGID
  sleep 5 && tail -5 "$EVID/devserver.log" # verify it actually booted (compile errors show here)
}

# STATIC BUILD for visual assertions (E-8)
pnpm build
setsid python3 -m http.server 8080 --directory out > "$EVID/static.log" 2>&1 &
echo $! > "$EVID/static.pid"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/   # expect 200 before shooting

# TEARDOWN (P5) — only PIDs THIS run recorded
for f in "$EVID"/devserver.pid "$EVID"/static.pid; do
  [ -f "$f" ] && kill -- -"$(cat "$f")" 2>/dev/null
done
ps -p "$(cat "$EVID/devserver.pid" 2>/dev/null)" 2>/dev/null && echo "STILL ALIVE — escalate" || echo "server gone — verified"
```

**Verify:** boot confirmed via log tail + a 200 curl BEFORE the first flow step; death
confirmed via `ps -p` at teardown.

## Compose healthcheck startup-gate recovery (FP-3, verified 2026-06-16)

Symptom: `docker compose up` hangs; `docker compose ps` shows a service in `Created` while
its dependency sits at `health: starting` — because a long healthcheck `interval` (e.g. 1h)
without `start_interval` delays the FIRST probe by a full interval, and
`depends_on: condition: service_healthy` blocks on it.

```bash
docker compose ps                          # identify: dependency "health: starting", dependents "Created"
# 1. Kill the hung compose up (Ctrl-C the foreground process, or kill its recorded PID)
# 2. Start the gated containers directly — they connect fine to the already-running dependency:
docker start <gated-container> [<gated-container-2> ...]
# 3. Verify the app answers:
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:<port>/health   # expect 200
```

Then file the ROOT-CAUSE finding (do not just recover and move on): the dependency's
healthcheck must pair the long interval with fast startup probing —

```yaml
healthcheck:
  interval: 1h          # cheap steady-state
  start_period: 60s     # startup window
  start_interval: 5s    # fast probes DURING startup ⇒ healthy in seconds
```

This is a latent bomb: it fires on the NEXT restart too, not just the recreate. Also check
for separately-broken probes (e.g. `grpc_health_probe` against a server not implementing
`grpc.health.v1.Health` → always unhealthy) in the same pass.

## Login / equip patterns (FP-4)

Credential SOURCES (pointers only — values never go into ledgers, briefs, or reports):

- Pulse → memory `reference_pulse_test_creds` (test creds scoped to the Alamanda Coffee test
  tenant — the designated mutation-safe tenant per E-11).
- Env-var pointers → `~/.claude/secrets.env` (e.g. the `$PULSE_TEST_*` pattern).
- Project-local → the app's seed scripts / README / `.env.example` naming test accounts.
- Nothing found → auth-gated flows are NOT_VERIFIED; report it; never invent accounts
  (lockout risk — BMS admin locks at 3 failed attempts).

Auto-login through the REAL login form (never cookie/token injection):

```bash
source "$EVID/browser.env"                       # every call — agent-browser §6.4
agent-browser open http://localhost:3000/login \
  && agent-browser wait --load networkidle
agent-browser find label "Email" fill "$TEST_USER_EMAIL"
agent-browser find label "Password" fill "$TEST_USER_PASSWORD"
agent-browser find role button click --name "Sign In" \
  && agent-browser wait --load networkidle
# VERIFY login actually landed — a logged-in-only element, not just "no error":
agent-browser snapshot -i -c --json | grep -i "logout\|dashboard" || echo "LOGIN FAILED — stop"
agent-browser screenshot "$EVID/00-logged-in.png"
```

## R-A — Web feature flow (canonical)

Example feature: "create product" in a Next.js admin. Assumes P0 ledger written (numbered
steps + expected results), P1 gates passed (server up, creds equipped, agent-browser §3
pre-flight green).

```bash
# 1. Surface — claim lifecycle EXACTLY per agent-browser §6.3 (from=9223, connect ≤30s,
#    verify pin HR-4, env file §6.4). Skeleton:
CLAIM=$(curl -s -G "http://localhost:9222/claim" \
        --data-urlencode "from=9223" \
        --data-urlencode "url=http://localhost:3000/login")
#    → parse port, check for "tab-create-failed" warning, write $EVID/browser.env,
#      agent-browser connect $PORT, curl :$PORT/target shows your URL.  (Full recipe: §6.3.)

# 2. Login — see "Login / equip patterns" above. Evidence: 00-logged-in.png.

# 3. Numbered steps — act → settle → capture → assert → record. Example step 3
#    ("open create-product form; expected: form visible with Name/Price/Save"):
source "$EVID/browser.env"
agent-browser find role button click --name "New Product" \
  && agent-browser wait --load networkidle
agent-browser snapshot -i -c --json > "$EVID/03-form.json"
grep -q '"Name"' "$EVID/03-form.json" && grep -q '"Save"' "$EVID/03-form.json"; echo "assert exit: $?"
agent-browser screenshot "$EVID/03-form.png"      # then run the §9.1 QA gate on it

# 4. Mutation step ("save product; expected: success toast + product in list"):
agent-browser find label "Name" fill "E2E Test Product $(date +%s)"
agent-browser find label "Price" fill "15000"
agent-browser find role button click --name "Save" \
  && agent-browser wait --load networkidle
agent-browser screenshot "$EVID/04-saved.png"

# 5. VERIFY-AFTER-WRITE (E-10) — the toast is NOT proof. Re-fetch through the API:
code=$(curl -s -o "$EVID/05-products.json" -w '%{http_code}' \
       -H "Authorization: Bearer $TEST_TOKEN" http://localhost:3000/api/products)
[ "$code" = "200" ] && jq -e '.items[] | select(.name | startswith("E2E Test Product"))' \
  "$EVID/05-products.json" > /dev/null; echo "persisted: $?"

# 6. Alternate path (validation error): submit empty form; expected: inline error, NO
#    network write. Assert the error element exists AND network shows no POST:
agent-browser network requests --clear
agent-browser find role button click --name "Save"
agent-browser find text "Name is required" click 2>/dev/null; agent-browser snapshot -i -c --json | grep -q "required"
agent-browser network requests --filter api --type xhr,fetch    # expect: no POST /api/products
agent-browser screenshot "$EVID/06-validation.png"

# 7. Flow-end sweep (even though everything "passed"):
agent-browser console > "$EVID/console.txt"
agent-browser errors  > "$EVID/errors.txt"

# 8. Teardown — agent-browser §12 + server PIDs (see SKILL.md §9).
```

**Verification steps named:** boot curl (setup), login element grep (step 2), form-field
grep exit code (step 3), §9.1 gate on every screenshot, API re-fetch + jq for the mutation
(step 5), network-silence assertion for the negative case (step 6), console/errors sweep.

## R-B — API-only flow

Example feature: `POST /api/orders`. No browser at all; same evidence bar. Covers the happy
path + the three mandatory negative classes: invalid input, missing auth, boundary values.

```bash
API=http://localhost:8080

# Happy path — capture status AND body, assert both:
code=$(curl -s -o "$EVID/order-ok.json" -w '%{http_code}' -X POST "$API/api/orders" \
  -H "Authorization: Bearer $TEST_TOKEN" -H "Content-Type: application/json" \
  -d '{"item_id":"itm_123","qty":2}')
[ "$code" = "201" ]; echo "status assert: $?"
ORDER_ID=$(jq -re '.id' "$EVID/order-ok.json"); echo "body assert (id present): $?"
jq -e '.qty == 2 and .status == "PENDING"' "$EVID/order-ok.json"; echo "field asserts: $?"

# VERIFY-AFTER-WRITE (E-10) — GET the resource back; the 201 is not persistence:
code=$(curl -s -o "$EVID/order-refetch.json" -w '%{http_code}' \
  -H "Authorization: Bearer $TEST_TOKEN" "$API/api/orders/$ORDER_ID")
[ "$code" = "200" ] && jq -e '.qty == 2' "$EVID/order-refetch.json"; echo "persisted: $?"

# Negative 1 — invalid input (expected: 400/422 + error body, NOT a 500):
code=$(curl -s -o "$EVID/order-bad.json" -w '%{http_code}' -X POST "$API/api/orders" \
  -H "Authorization: Bearer $TEST_TOKEN" -H "Content-Type: application/json" \
  -d '{"item_id":"","qty":-1}')
{ [ "$code" = "400" ] || [ "$code" = "422" ]; } && jq -e '.error' "$EVID/order-bad.json"; echo "invalid-input: $?"

# Negative 2 — missing auth (expected: 401, and NO order created):
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/api/orders" \
  -H "Content-Type: application/json" -d '{"item_id":"itm_123","qty":1}')
[ "$code" = "401" ]; echo "missing-auth: $?"

# Negative 3 — boundary values (qty=0, qty=max+1, oversized strings) — same pattern.
# A 500 on ANY negative case is a finding: unhandled input reached the handler.
```

**Verification steps named:** status assert + body assert per call (exit codes echoed into
the ledger), GET-after-POST persistence proof, negative-case status classes, the
"500-on-bad-input is a bug" rule.

## R-C — Mixed flow (UI action → API/DB state verification)

The pattern for anything where the UI is only the front half of the truth: perform the
action in the browser, then verify the STATE at the layer below (API, then DB if reachable).

```bash
# UI half — per R-A: click "Mark as Paid" on order X, screenshot the resulting badge.
source "$EVID/browser.env"
agent-browser find role button click --name "Mark as Paid" \
  && agent-browser wait --load networkidle
agent-browser screenshot "$EVID/10-paid-badge.png"

# API half — the badge could be optimistic-UI lying; re-fetch (E-10):
code=$(curl -s -o "$EVID/10-order.json" -w '%{http_code}' \
  -H "Authorization: Bearer $TEST_TOKEN" "$API/api/orders/$ORDER_ID")
[ "$code" = "200" ] && jq -e '.payment_status == "PAID"' "$EVID/10-order.json"; echo "api state: $?"

# DB half (when a test DB is reachable — deepest proof, use for money/state-machine steps):
psql "$TEST_DATABASE_URL" -tAc \
  "SELECT payment_status FROM orders WHERE id='$ORDER_ID'" | grep -qx "PAID"; echo "db state: $?"
```

A mismatch BETWEEN layers (badge says PAID, API says PENDING) is itself the finding — record
which layer lied; that locates the bug (optimistic UI vs write path) before the fix loop
starts reading code.

## Filled example — evidence ledger + report

### Ledger (`$EVID/ledger.md`), flow "create product — happy path"

Header: `port=9224 (claimed) · devserver PID 41233 (self-started) · creds: reference_pulse_test_creds (Alamanda test tenant)`

| # | Action (exact command) | Expected | Actual | Evidence | Exit/Status | Verdict |
|---|---|---|---|---|---|---|
| 1 | login via form (R-A step 2) | dashboard visible | dashboard rendered, "Logout" in snapshot | 00-logged-in.png | grep 0 | PASS |
| 2 | `find role button click --name "New Product"` | form w/ Name, Price, Save | form rendered | 03-form.png, 03-form.json | grep 0 | PASS |
| 3 | fill Name+Price, click Save | success toast, item in list | toast shown | 04-saved.png | — | PASS |
| 4 | GET /api/products re-fetch | new product persisted | present in response | 05-products.json | 200 / jq 0 | PASS |
| 5 | submit empty form | inline "required" error, no POST | error shown; network clean | 06-validation.png | grep 0 | PASS |
| 6 | console/errors sweep | clean | 1 warning (React key) | console.txt | — | PASS (flagged) |

### Report

```
E2E RESULTS — create product (admin)
=======================
Feature:      create-product form, admin panel (uncommitted change set, 4 files)
Flows:        2 — happy path, validation-error path
Steps:        6 | PASS 6 · FAIL 0 · FLAKY 0 · NOT_VERIFIED 0
Fixes made:   1 — symptom: Save 500'd → root cause: price parsed as string reached
              Prisma decimal column → fix: zod coerce in the route handler →
              proof: re-ran both flows, step 4 re-fetch shows persisted row
Test fixes:   none
Commits:      a1b2c3d (via /commit — only src/app/api/products/route.ts staged)
Console:      1 warning (React list key, pre-existing) — flagged, out of scope
Not verified: none
Verdict:      ALL PASS
Evidence:     ~/claude/notes/pulse-create-product-2026-07-02/evidence/
```
