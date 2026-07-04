# .ui-test-config.json — Normative Schema (v2, v1 back-compatible)

Lives in the target project root. **v1 files parse unchanged** — the only behavioral change
for a v1 file is the PF-5 blocking gitignore gate when a literal `password` is present.
Report/screenshot paths are fixed by the skill (`./UI-QA.md`, `./ui-test-screenshots/`) and
are not configurable.

## Field-by-field spec

### `target` (required — at least one key)

| Field | Type | Meaning |
|---|---|---|
| `target.local` | url | dev target, chosen when its port answers (PF-6) |
| `target.staging` | url | fallback / `--staging` target |

### `auth` (optional, v2)

| Field | Type / values | Meaning |
|---|---|---|
| `auth.mode` | `"form"` (default) \| `"none"` \| `"external"` | `form` = email+password login (the whole `login` block + role creds required). `none` = anonymous app: `login`, `logout`, role credentials all optional; roles degrade to one implicit `anonymous` role. `external` = wallet/SIWE/OAuth-only: login flow out of scope, test on the pre-authenticated claimed tab (SKILL §7.7). |

### `login` (required when `auth.mode` is `form`)

| Field | Type | Meaning |
|---|---|---|
| `login.url` | path | login page path, e.g. `/login` |
| `login.emailField` | CSS selector | email input |
| `login.passwordField` | CSS selector | password input |
| `login.submitSelector` | CSS selector | submit button |
| `login.successIndicator` | `url:/path` or `selector:.el` | login-succeeded check (URL contains path / element visible), waited up to 10s |
| `login.tenantSelector` | object (v2, optional) | post-login tenant/workspace pick: `{ "match": "text:Lancar Jaya" \| "selector:.tenant-card", "then": "url:/dashboard" }` — click the matched element, then re-verify `then` the same way as successIndicator |

### `logout` (optional but STRONGLY recommended for multi-role — the ONLY session reset, SKILL UT-HR-2)

| Field | Type | Meaning |
|---|---|---|
| `logout.url` | path | direct logout endpoint (preferred — most reliable) |
| `logout.selector` | CSS selector | logout UI element to click when no URL exists |

Neither present + multiple roles → the run finds the app's logout UI itself; if none exists,
remaining roles are `BLOCKED(no logout)` — a global cookie wipe is NEVER the fallback.

### `roles[]` (required unless `auth.mode` ≠ `form`; ≥1 entry)

| Field | Type | Meaning |
|---|---|---|
| `name` | string | role label; also the screenshot subdir name — keep it filename-safe |
| `emailEnv` | string (v2, **preferred**) | env var NAME holding the email, resolved from `~/.claude/secrets.env` at runtime |
| `passwordEnv` | string (v2, **preferred**) | env var NAME holding the password |
| `email` / `password` | string (v1, legacy) | literal creds — still parsed, but a literal `password` ARMS the PF-5 blocking gate: inside a git work tree, `git check-ignore -q .ui-test-config.json` must pass or the run aborts with remediation text |

Precedence per role: `emailEnv`/`passwordEnv` when present, else the literal fields. Both
absent under `auth.mode: form` → config invalid (report the role name).

### `pages[]` (required; ≥1 entry)

`{ "path": "/dashboard", "name": "Dashboard" }` — `name` is used in the report and
screenshot filenames.

### `session` (optional, v2)

| Field | Type | Meaning |
|---|---|---|
| `session.ttlMinutes` | int | the app's auth-token TTL. Sets the keep-alive budget: navigate a neutral page every `min(10, ttlMinutes − 5)` minutes (SKILL §3). This is a PER-APP fact — e.g. Pulse's JWT TTL is 15 min (the old skill wrongly stated that as universal) |

### `themes[]` / `locales[]` (optional, v2)

- `themes`: default `["light","dark"]`. `["light"]` is valid ONLY with a reason the report
  must cite (the oneshot-webapp light-only exception, or an internal-only tool) — otherwise
  the theme parity gate blocks SHIP (SKILL §7.6).
- `locales`: e.g. `["id","en"]` — first entry is the crawl locale; the rest get a
  hardcoded-string spot-check (full mode).

### `mutationTier` / `mutation` (optional, v2 — SKILL §8.2, atlas §7)

| Field | Values | Meaning |
|---|---|---|
| `mutationTier` | `"read-only"` (default) \| `"test-tenant"` | `test-tenant` licenses persisting mutations, ONLY with test creds on the named tenant |
| `mutation.testTenant` | string | the tenant name the license is scoped to — REQUIRED when tier is `test-tenant` |

### `budgets` (optional, v2 — overrides of SKILL §3 defaults)

`{ "perElementTimeoutMs": 5000, "roleTimeoutMin": 30, "hybridThreshold": 40, "pageLoadTimeoutS": 15 }`
— only override with a reason recorded in the report.

### `flows[]` (optional)

Each: `{ "name", "role", "steps": [...] }`. Step actions: `navigate` (`path`), `click`
(`selector`), `fill` (`selector`, `value`), `verify` (`expect`: `toast:success` |
`toast:error` | `url:/path` | `selector:.el` | `text:"s"`), and v2 `verifyState`
(`path` + `expect`) — **required as the final step of any flow with a mutating step**
(persistence proof, SKILL §7.4).

### `visibility` (optional)

Per role: `{ "shouldSee": [selectors], "shouldNotSee": [selectors] }`. A visible
`shouldNotSee` element is a role-leak candidate → P0 review.

## Validation summary (what PF-5 enforces)

1. JSON parses (`jq .` exits 0).
2. Required fields present for the declared `auth.mode`.
3. Every `emailEnv`/`passwordEnv` resolves non-empty after `source ~/.claude/secrets.env`
   (checked with `[ -n "${!var}" ]` — values are NEVER printed).
4. Literal `password` present + git work tree → `git check-ignore -q .ui-test-config.json`
   passes, or ABORT with: gitignore it, or migrate to env refs.
5. `mutationTier: "test-tenant"` requires `mutation.testTenant`.
6. `successIndicator` / `expect` strings match the `url:`/`selector:`/`toast:`/`text:` grammar.

Invalid → abort reporting the SPECIFIC failing fields. Never guess selectors.

## Worked example 1 — multi-role form-auth app (Pulse-shaped, env-ref creds)

```json
{
  "target": { "local": "http://localhost:3000", "staging": "https://aenoxa.com" },
  "auth": { "mode": "form" },
  "login": {
    "url": "/login",
    "emailField": "input[name='email']",
    "passwordField": "input[name='password']",
    "submitSelector": "button[type='submit']",
    "successIndicator": "url:/dashboard",
    "tenantSelector": { "match": "text:Lancar Jaya", "then": "url:/dashboard" }
  },
  "logout": { "url": "/logout" },
  "session": { "ttlMinutes": 15 },
  "roles": [
    { "name": "owner", "emailEnv": "PULSE_TEST_EMAIL", "passwordEnv": "PULSE_TEST_PASSWORD" },
    { "name": "staff", "emailEnv": "PULSE_STAFF_EMAIL", "passwordEnv": "PULSE_STAFF_PASSWORD" }
  ],
  "pages": [
    { "path": "/dashboard", "name": "Dashboard" },
    { "path": "/dashboard/products", "name": "Products" },
    { "path": "/dashboard/settings", "name": "Settings" }
  ],
  "themes": ["light", "dark"],
  "locales": ["id", "en"],
  "mutationTier": "read-only",
  "flows": [
    {
      "name": "create-product",
      "role": "owner",
      "steps": [
        { "action": "navigate", "path": "/dashboard/products" },
        { "action": "click", "selector": "button:contains('Add Product')" },
        { "action": "fill", "selector": "input[name='name']", "value": "UITEST-Product-01" },
        { "action": "click", "selector": "button:contains('Save')" },
        { "action": "verify", "expect": "toast:success" },
        { "action": "verifyState", "path": "/dashboard/products", "expect": "text:\"UITEST-Product-01\"" }
      ]
    }
  ],
  "visibility": {
    "owner": { "shouldSee": [".admin-panel"], "shouldNotSee": [] },
    "staff": { "shouldSee": [".staff-dashboard"], "shouldNotSee": [".admin-panel"] }
  }
}
```

Pulse notes (labeled example, NOT generic truth): creds live ONLY in `~/.claude/secrets.env`
(`$PULSE_TEST_*` = jenniejesse5 account with the Lancar Jaya test tenant;
`$PULSE_ALAMANDA_*` = toper289982 — the Alamanda Coffee tenant exists ONLY there, do not mix
accounts). A create-product flow on `mutationTier: "test-tenant"` +
`"mutation": { "testTenant": "Alamanda Coffee" }` may persist; on the default tier the flow
above should target a form that open-then-cancels, or be omitted.

## Worked example 2 — anonymous / wallet app (AURA-shaped)

```json
{
  "target": { "local": "http://localhost:3000" },
  "auth": { "mode": "external" },
  "pages": [
    { "path": "/", "name": "Home" },
    { "path": "/agents", "name": "Agents" },
    { "path": "/generate", "name": "Generate" },
    { "path": "/dashboard", "name": "Dashboard (no-wallet state)" }
  ],
  "themes": ["light", "dark"]
}
```

Field precedent: the 2026-06-23 AURA run ("no email/password login; single anonymous public
role, auth is wallet/SIWE") — write-gates verified up to the wallet-sign boundary, report
says so explicitly. `auth.mode: "none"` is the same shape for apps with no auth at all.

## Worked example 3 — light-only oneshot pitch demo

```json
{
  "target": { "local": "http://localhost:3000" },
  "auth": { "mode": "none" },
  "pages": [ { "path": "/", "name": "Landing" } ],
  "themes": ["light"]
}
```

The report MUST cite the oneshot-webapp exception ("pitch/demo one-shots are light-only by
house rule") next to the theme-parity gate result — otherwise `themes:["light"]` blocks SHIP.
