# House-Verified Next.js Gotchas

Paid-in-blood traps from the Aenoxa/AURA/Pulse estate. Each entry cites the memory file that
carries the full incident narrative — read it before improvising a different fix.

## 1. Encoded-Slash (%2F) in a Dynamic Path Segment → 404 Behind nginx

**Symptom:** route returns 200 under `next dev`, but 404 in prod (standalone behind nginx);
the route handler NEVER logs — the request dies upstream.

**Cause:** nginx and the Next-standalone router normalize/reject `%2F` in a path segment
before your `[param]` route runs. There is NO app-level fix inside the handler.
Verified live on AURA agent portraits, 2026-06-23 (`0g://showcase-x` → `/images/0g%3A%2F%2F...` → 404).

**Fix recipe (in preference order):**
1. Slug-ify at ONE chokepoint before the value becomes a path segment, e.g.
   `r.startsWith('0g://') ? r.slice(5) : r` — and keep the old slashy keys as tolerant
   aliases in the route's lookup (defense-in-depth for cached URLs).
2. Move the value to a QUERY param instead of a path segment.
3. Last resort (riskier): nginx `merge_slashes off` + Next `skipMiddlewareUrlNormalize`.

**Rule:** NEVER put a value that can contain a slash (raw or %2F-encoded) into a dynamic
path segment. Audit every new `[param]` for slash-bearing inputs.
Memory: `reference_nextjs_encoded_slash_path_404`.

## 2. Long Healthcheck `interval` Without `start_interval` → Compose Stack Hangs

**Symptom:** after a healthcheck tune, `docker compose up` blocks; the gated service sits in
`Created` forever; app down. Verified 10-min prod outage (aenoxa auth), 2026-06-16.

**Cause:** Docker does not run the FIRST health probe until ~`interval` after start. With
`interval: 1h` and `depends_on: condition: service_healthy`, dependents wait up to an hour.
It bites on the NEXT restart too, not just the recreate — a latent bomb.

**Recovery:** kill the hung `docker compose up`, then `docker start <gated-containers>`
(they connect fine to the already-running dependency), THEN fix the source.

**Fix:** ALWAYS pair a long `interval` with `start_period` + `start_interval`
(e.g. `interval: 1h`, `start_period: 60s`, `start_interval: 5s`) — healthy in seconds at
startup, hourly probes in steady state. Also check the probe itself works (a
`grpc_health_probe` against a server without the Health service is ALWAYS unhealthy).
Memory: `reference_healthcheck_interval_breaks_startup_gate`.

## 3. Serwist/Workbox `navigationPreload` → Flaky OAuth (~50/50 invalid_grant)

**Symptom:** Google login fails roughly half the time in a Next PWA; backend logs show the
OAuth callback hit TWICE ~40ms apart, second exchange gets `invalid_grant`.

**Cause:** with `navigationPreload: true`, the browser pre-sends the navigation request
(fetch #1); the SW's preload await REJECTS on the 302-redirecting GET callback, so the
strategy falls through to its own `fetch()` (fetch #2). The one-time authorization code is
exchanged twice. Verified + fixed on Pulse (aenoxa_pos_web), 2026-06-02, serwist@9.5.7.

**Fix (one line):** `navigationPreload: false` in `sw.ts`. It is a single GLOBAL SW boolean
(cannot be scoped per-route). DO NOT re-enable while any redirecting-GET API route is
SW-handled. Note: NetworkOnly on `/api/auth/*` does NOT protect you — caching was never
the cause. Memory: `reference_pulse_sw_oauth_navigationpreload`.

## 4. CSS/Token Edit Passes tsc, Then Every Route 500s (CssSyntaxError)

**Symptom:** after a `globals.css` / token edit, every route 500s with
`CssSyntaxError: Unknown word ...` — but `tsc --noEmit` was clean.

**Cause:** tsc does NOT parse CSS. A comment containing `*/` (easy when a comment mentions
`bg-*/10` or a glob) closes the CSS comment early and leaks invalid CSS. Verified on
aenoxa_pos_web, 2026-06-24.

**Fix + gate:**
- Locate via the postcss error line; reword the comment (e.g. `bg-token/10`) — NEVER put
  `*/` inside a CSS comment.
- ALWAYS verify CSS/token edits with a REAL CSS compile (`next dev`, `next build`, or the
  fast parser repro):
  `node -e "const p=require('postcss');const fs=require('fs');p.parse(fs.readFileSync('src/app/globals.css','utf8'))"`
- Match the verification tool to the artifact: tsc for TS/JSX, a CSS compile for CSS.
Memory: `feedback_verify_css_changes_with_compile`.

## 5. next-themes → `suppressHydrationWarning` on `<html>` (house default stack)

House website builds ship next-themes from commit 0 (CLAUDE.md Website Build Defaults).
next-themes mutates the `<html>` class pre-hydration, so ALWAYS add
`suppressHydrationWarning` to the `<html>` element — and ONLY there. Full recipe +
anti-abuse rule: [hydration-error.md](./hydration-error.md).
