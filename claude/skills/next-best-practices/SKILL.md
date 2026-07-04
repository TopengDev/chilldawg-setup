---
name: next-best-practices
description: Next.js framework correctness and conventions reference pack (App Router era, dual-gated for Next 15.x AND 16.x) - file conventions, RSC boundaries, caching defaults, async APIs, metadata, error handling, route handlers, image/font loading mechanics, bundling, self-hosting, plus house-verified gotchas. Use when writing, reviewing, debugging, or migrating Next.js code. For pure performance tuning (waterfalls, bundle size, re-renders) use vercel-react-best-practices instead.
user-invocable: false
---

# Next.js Best Practices

Framework **correctness, conventions, and version migration** for Next.js (App Router era).
This is a router over the aux files in this directory — load only the files the task needs.
The house estate runs BOTH Next 15.x and 16.x as live majors (verified 2026-07-03: clusters
at 15.1–15.5 and 16.0–16.2 across ~/claude/Git/repositories, plus 13/14 stragglers), so
**every version-sensitive piece of advice must be dual-gated, never floored at one version**.

---

## STEP 0 — VERSION DETECTION GATE (mandatory, every time this skill fires)

**NEVER dispense version-sensitive Next.js advice before detecting the target repo's
installed version.** Skipping this gate is a hard violation.

```bash
grep -m1 '"next"' package.json || grep -m1 '"version"' node_modules/next/package.json
```

Classify, then **state the detected version in your first response line**:

| Detected | Treatment |
|---|---|
| 13.x / 14.x | LEGACY — flag it, advise the upgrade path (`npx @next/codemod@latest upgrade`), do NOT apply 15+/16 rules blind (e.g. params are still sync objects in 14) |
| 15.x | Apply the 15.x column below |
| 16.x | Apply the 16.x column below |
| Pages Router (no `app/`) | See "Pages Router edge case" at the bottom |

### Version-sensitive advice table (the two live columns)

| Topic | 15.x | 16.x |
|---|---|---|
| Middleware file | `middleware.ts` + `middleware()` export | `proxy.ts` + `proxy()` export; config export STILL `config`; nodejs-only (no edge); `middleware.ts` deprecated NOT removed |
| `'use cache'` enablement | `experimental: { useCache: true }` (or `experimental.dynamicIO`) | Top-level `cacheComponents: true`; the 15-era flags are REMOVED (error as unrecognized) |
| `cacheComponents` conflicts | n/a | Errors at build if any segment still exports `dynamic` / `revalidate` / `fetchCache` |
| Turbopack | OPT-IN: `next dev --turbopack` / `next build --turbopack`; webpack config is LIVE | DEFAULT for dev AND build (stable); config moves `experimental.turbopack` → top-level `turbopack` |
| Bundle analyzer | `next experimental-analyze` NOT available | `next experimental-analyze [--output]` (16.1+) |
| Sync dynamic APIs (`params`, `searchParams`, `cookies()`, `headers()`) | Deprecated shim — warns but works | REMOVED — awaiting is mandatory |
| MCP debug endpoint | `experimental.mcpServer: true` flag | Default-on (verified-plausible — see ledger) |
| `forbidden()` / `unauthorized()` | `experimental.authInterrupts` required | Same — still flag-gated in both |

(Table verified against canary docs via context7, 2026-07-03; sources in the ledger below.)

---

## HARD RULES

Each rule carries its verification or incident citation. These outrank the aux files if
they ever disagree.

1. **ALWAYS run the Version Detection Gate first** and state the detected version before
   any version-sensitive advice. NEVER give proxy.ts / cacheComponents / default-Turbopack /
   `next experimental-analyze` advice to a 15.x repo; NEVER give `experimental.useCache` /
   `experimental.dynamicIO` / middleware-as-current advice to a 16.x repo.

2. **NEVER flag `Date`, `Map`, `Set`, TypedArray, `ArrayBuffer`, plain objects, JSX,
   Promises, or Server Functions passed Server → Client as serialization bugs** — React 19
   supports all of them. The only non-serializable props: non-Server-Function functions,
   classes/class instances, null-prototype objects, unregistered Symbols.
   (react.dev `'use client'` reference, verified 2026-07-03; full list: [rsc-boundaries.md](./rsc-boundaries.md).)

3. **NEVER write `export const proxyConfig` in proxy.ts** — the config export is still
   `config`; `proxyConfig` is silently ignored and the proxy runs on EVERY route.
   **NEVER use proxy.ts when edge runtime is required** — proxy is nodejs-only; keep
   `middleware.ts` for edge. (canary proxy.mdx, verified 2026-07-03.)

4. **NEVER use `forbidden()` / `unauthorized()` without
   `experimental: { authInterrupts: true }`** — still flag-gated in 15 AND 16.
   (canary forbidden.mdx, verified 2026-07-03; snippet: [error-handling.md](./error-handling.md).)

5. **NEVER wrap `redirect()` / `permanentRedirect()` / `notFound()` / `forbidden()` /
   `unauthorized()` in a try-catch without `unstable_rethrow(error)` first** — navigation
   APIs throw internally and a bare catch swallows the navigation.
   (Load-bearing original rule; recipe: [error-handling.md](./error-handling.md).)

6. **NEVER call `next/dynamic` with `ssr: false` inside a Server Component** — the App
   Router throws. Host the `dynamic()` call inside a `'use client'` wrapper.
   (Recipe: [bundling.md](./bundling.md) Solution 1.)

7. **NEVER assume `fetch()` or GET route handlers are cached** — since Next 15 both are
   UNCACHED by default; caching is explicit opt-in (`cache: 'force-cache'`,
   `export const dynamic = 'force-static'`, `revalidate`, `'use cache'`).
   (Defaults table: [data-patterns.md](./data-patterns.md).)

8. **NEVER put a value that can contain a slash (raw or %2F) into a dynamic path segment**
   — nginx + Next-standalone 404 the request before the route runs. Slug-ify at one
   chokepoint or use a query param. (Verified AURA 2026-06-23,
   `reference_nextjs_encoded_slash_path_404`; playbook: [house-gotchas.md](./house-gotchas.md) #1.)

9. **ALWAYS verify `globals.css` / Tailwind token edits with a real CSS compile**
   (`next dev` / `next build` / the postcss one-liner) — tsc does not parse CSS and a stray
   `*/` in a comment can 500 every route. (Verified 2026-06-24,
   `feedback_verify_css_changes_with_compile`; playbook: [house-gotchas.md](./house-gotchas.md) #4.)

10. **ALWAYS pair a long docker-compose healthcheck `interval` with `start_period` +
    `start_interval`** when anything gates on `service_healthy` — otherwise the stack hangs
    in `Created` for up to one interval. (Verified 10-min prod outage 2026-06-16,
    `reference_healthcheck_interval_breaks_startup_gate`; playbook: [house-gotchas.md](./house-gotchas.md) #2.)

11. **ALWAYS add `suppressHydrationWarning` to `<html>` when next-themes is in the stack**
    (house builds always include it) — and ONLY on `<html>`, never to hide real hydration
    bugs. (Recipe: [hydration-error.md](./hydration-error.md).)

12. **NEVER contradict the house Website Build Defaults** — Aenoxa-ecosystem Next.js sites
    ship next-intl (`[locale]` segment, `id` default + `en`) and next-themes from commit 0
    (CLAUDE.md, `feedback_website_build_defaults_i18n_themes`). NEVER advise removing
    either. The `/oneshot-webapp` exception (light-only, no next-themes) is governed by
    that skill, not this one.

13. **NEVER present Inter/Roboto/monospace as example font choices** — font SELECTION
    belongs to `/frontend-design` (Inter/Roboto banned as AI-slop; monospace only for mono
    archetypes, `feedback_no_monospace_unless_archetype`; weight floor 500 / size floor
    12px, `feedback_ui_typography_floors`). This skill owns `next/font` LOADING mechanics only.

14. **ALWAYS route pure performance-optimization asks (waterfalls, bundle size, re-render
    tuning) to `/vercel-react-best-practices`.** This skill owns correctness, conventions,
    and version migration. On overlap: correctness verdicts HERE win; perf-tuning verdicts
    THERE win.

15. **ALWAYS re-verify the Freshness Ledger via context7 (`/vercel/next.js`) when a new
    Next.js MAJOR ships or observed behavior contradicts a ledger row**, and restamp with
    the new date + version. NEVER add an aux file without a ledger row. An unstamped file
    may not be cited as authority.

---

## BOUNDARY ROUTER (which skill wins — double-loading is a violation)

| Ask | Owner | Loser |
|---|---|---|
| Framework correctness, file conventions, RSC boundaries, caching semantics, version migration | **this skill** | vercel-react-best-practices |
| Performance rules: waterfalls, bundle size, re-renders, "why is this page slow" | `/vercel-react-best-practices` | this skill |
| Design, aesthetics, font/color SELECTION | `/frontend-design` | this skill |
| Deploy-to-VPS mechanics (nginx, certbot, subdomains) | `/deploy-landing`, `/oneshot-webapp` | this skill |
| Tailwind token architecture, design systems | `/tailwind-design-system` | this skill |
| Scaffolding a NEW Next.js repo (create-next-app flags, scaffold order, day-0 defaults) | `/project-init` (its §12 env-facts ledger, stamped 2026-07-03, is the verified scaffold ground truth) | this skill |

Conflict rule: correctness verdicts here win; perf-tuning verdicts in
`/vercel-react-best-practices` win. Cite the other skill instead of restating its rules.

---

## PRE-REVIEW CHECKLIST (before flagging ANY code as wrong under this skill)

All 5 must pass or the finding is NOT raised:

1. [ ] Next version confirmed from package.json (Step 0 ran)
2. [ ] Router confirmed: App Router vs Pages Router
3. [ ] The API's existence confirmed in the INSTALLED version (node_modules or context7 —
       never assumed from naming conventions)
4. [ ] RSC serialization judged against the React 19 list ONLY ([rsc-boundaries.md](./rsc-boundaries.md))
5. [ ] Caching assumptions checked against the 15+ uncached-by-default table ([data-patterns.md](./data-patterns.md))

This checklist exists because the pack itself previously carried pre-React-19 serialization
lore that would have generated false findings against correct code.

---

## FRESHNESS LEDGER (single source of truth for pack trust)

Statuses: `verified-current` (checked, accurate) · `corrected` (was wrong, fixed in place) ·
`verified-plausible` (probably right, unverifiable locally — re-verify on first use) ·
`retired-stale` (removed).

**Re-verify trigger:** a new Next.js MAJOR release, or any observed framework behavior that
contradicts a row → re-check that row via context7 `/vercel/next.js` + restamp date/version.
Verification basis for the 2026-07-03 stamps: context7 canary docs (proxy.mdx,
version-16.mdx upgrade guide, forbidden.mdx, use-cache docs) + react.dev `'use client'`
reference + live estate grep.

| File | Status | Verified against | Date | Note |
|---|---|---|---|---|
| async-patterns.md | corrected | 15.5/16.2 canary docs | 2026-07-03 | Added "sync access REMOVED in 16" gate; codemod verified |
| bundling.md | corrected | version-16.mdx | 2026-07-03 | Turbopack claim fixed (opt-in 15 / default 16); ssr:false moved into client wrapper; analyzer stamped 16.1+ |
| data-patterns.md | corrected | Next 15 caching defaults | 2026-07-03 | Uncached-by-default block added; "GET is cacheable" comment fixed |
| debug-tricks.md | verified-plausible | (not locally verifiable) | 2026-07-03 | MCP roster + `--debug-build-paths` — RE-VERIFY vs a live dev server on first use |
| directives.md | corrected | version-16.mdx, use-cache docs | 2026-07-03 | use-cache flags version-gated; dead `next-cache-components` skill ref removed |
| error-handling.md | corrected | forbidden.mdx | 2026-07-03 | authInterrupts gate added; redirect/try-catch section verified-current, kept verbatim |
| file-conventions.md | corrected | proxy.mdx | 2026-07-03 | Hallucinated `proxyConfig` → `config`; nodejs-only + deprecated-not-removed notes |
| font.md | corrected | next/font docs + house law | 2026-07-03 | Mechanics verified-current; banned example fonts (Inter/Roboto_Mono) swapped for placeholders |
| functions.md | verified-current | API reference index | 2026-07-03 | Official function tables, spot-checked |
| house-gotchas.md | verified-current | house memory files | 2026-07-03 | NEW — four verified incidents + next-themes note |
| hydration-error.md | corrected | next-themes house default | 2026-07-03 | suppressHydrationWarning subsection added |
| image.md | verified-current | image docs | 2026-07-03 | sizes-with-fill etc. still accurate |
| metadata.md | corrected | metadata docs + house law | 2026-07-03 | Content verified-current; banned Inter swapped out of the OG-image font example |
| parallel-routes.md | corrected | routing docs | 2026-07-03 | `[...]catchall` → `[...catchall]` typo; recipe otherwise verified sound |
| route-handlers.md | corrected | Next 15 caching defaults | 2026-07-03 | Caching-defaults block added; route/page conflict rule kept |
| rsc-boundaries.md | corrected | react.dev use-client reference | 2026-07-03 | Rule 2 rewritten to React 19 serialization list; Promise+use() recipe added; Rules 1+3 verbatim |
| runtime-selection.md | corrected | version-16.mdx | 2026-07-03 | proxy-is-nodejs-only note added |
| scripts.md | corrected | App Router metadata API | 2026-07-03 | next/head section labeled Pages-Router-only |
| self-hosting.md | corrected | Compose Spec + house incident | 2026-07-03 | compose `version:` dropped; start_period/start_interval; env-whitelist warning; boundary cite |
| suspense-boundaries.md | verified-current | useSearchParams docs | 2026-07-03 | CSR-bailout rules still accurate |
| SKILL.md | corrected | this pass | 2026-07-03 | Bare TOC → gates + hard rules + ledger + boundary router |

Retired-stale facts (removed, with reason):
- "Date/Map/Set are non-serializable Server→Client props" — false under React 19.
- "`export const proxyConfig`" — hallucinated export; docs show `config`.
- "Turbopack is the default bundler in Next.js 15+" — false for 15; default only in 16.
- "'use cache' requires `cacheComponents: true`" stated version-unconditionally — 16-only; 15 uses `experimental.useCache`.
- "see the `next-cache-components` skill" — no such skill exists (checked 2026-07-03).
- compose `version: '3.8'` key — obsolete under the Compose Spec.

---

## TOPIC MAP (load only what the task needs)

| File | Covers |
|---|---|
| [file-conventions.md](./file-conventions.md) | Project structure, special files, route segments (dynamic/catch-all/groups), parallel + intercepting route layout, middleware→proxy rename (v16) |
| [rsc-boundaries.md](./rsc-boundaries.md) | Async-client-component ban, React 19 serialization rules, Server Action exception, Promise+`use()` streaming |
| [async-patterns.md](./async-patterns.md) | Async `params`/`searchParams`/`cookies()`/`headers()`, `React.use()` in sync components, migration codemod, 16 removal gate |
| [runtime-selection.md](./runtime-selection.md) | Node.js default vs Edge; when Edge is appropriate; v16 proxy nodejs-only |
| [directives.md](./directives.md) | `'use client'`, `'use server'`, `'use cache'` (version-gated flags), cacheLife/cacheTag pointers |
| [functions.md](./functions.md) | Navigation hooks (`useRouter`/`usePathname`/`useSearchParams`/`useParams`), server functions (`cookies`/`headers`/`draftMode`/`after`), generate functions |
| [error-handling.md](./error-handling.md) | `error.tsx`/`global-error.tsx`/`not-found.tsx`, redirect/notFound throw semantics + `unstable_rethrow`, forbidden/unauthorized + authInterrupts gate |
| [data-patterns.md](./data-patterns.md) | Caching defaults (15+), Server Components vs Server Actions vs Route Handlers, waterfall avoidance (Promise.all/Suspense/preload), client fetching |
| [route-handlers.md](./route-handlers.md) | `route.ts` basics, caching defaults, page.tsx conflicts, no-React-DOM environment, vs Server Actions |
| [metadata.md](./metadata.md) | Static + `generateMetadata`, OG images with `next/og`, file-based metadata conventions, Server-Components-only constraint |
| [image.md](./image.md) | `next/image` over `<img>`, remote config, responsive `sizes`, blur placeholders, priority/LCP |
| [font.md](./font.md) | `next/font` loading mechanics (Google/local/Tailwind/subsets/display) — selection owned by /frontend-design |
| [bundling.md](./bundling.md) | Server-incompatible packages (client-wrapper recipe), serverExternalPackages/transpilePackages, CSS imports, polyfills, analyzer, Turbopack version gate |
| [scripts.md](./scripts.md) | `next/script` strategies, inline-script id, `@next/third-parties` (GA/GTM), Pages-Router-only next/head note |
| [hydration-error.md](./hydration-error.md) | Browser-API/date/random causes, invalid nesting, next-themes suppressHydrationWarning, next/script fix |
| [suspense-boundaries.md](./suspense-boundaries.md) | CSR bailout: `useSearchParams` (always) + `usePathname` (dynamic routes) need Suspense |
| [parallel-routes.md](./parallel-routes.md) | Modal pattern with `@slot` + `(.)` interceptors, mandatory `default.tsx`, `router.back()` closing, matcher table |
| [self-hosting.md](./self-hosting.md) | `output: 'standalone'`, Docker/compose (healthcheck trap), PM2, cache handlers for multi-instance ISR, env var hygiene, OpenNext |
| [debug-tricks.md](./debug-tricks.md) | MCP dev endpoint (verified-plausible), `--debug-build-paths` route rebuilds (16+) |
| [house-gotchas.md](./house-gotchas.md) | Verified house incidents: %2F path 404, healthcheck startup hang, navigationPreload OAuth double-fetch, CSS-compile gate, next-themes note |

---

## DONE-GATE (all must pass before reporting Next.js work complete)

- [ ] `next build` exits 0 (or `next dev` compiles clean for dev-only tasks)
- [ ] If `globals.css`/tokens touched → a REAL CSS compile ran (Hard Rule 9)
- [ ] If house-ecosystem website → `id`+`en` locales and light+dark themes still render
      (CLAUDE.md Website Build Defaults verification gate — cite it, don't duplicate it)
- [ ] Browser console free of hydration errors on the touched routes
- [ ] Any NEW dynamic path segment audited for slash-bearing values (Hard Rule 8)
- [ ] Anything irreversible (deploy, push) — governed by /ship and the house gates, not here

---

## HOUSE ALIGNMENT (citations, not duplicates)

- Website builds: next-intl (`id` default + `en`) + next-themes from commit 0 —
  CLAUDE.md "Website Build Defaults" + `feedback_website_build_defaults_i18n_themes`.
- Pitch/demo one-shots override that (light-only, no next-themes) — `/oneshot-webapp` owns it.
- Typography floors (weight ≥ 500, size ≥ 12px) — `feedback_ui_typography_floors`.
- Font selection + anti-slop bans — `/frontend-design`; monospace gate —
  `feedback_no_monospace_unless_archetype`.
- Browser verification of running apps — `/agent-browser` (qutebrowser stack; never Playwright MCP).
- Commits — only via the commit skill (`CLAUDE_COMMIT_SKILL=1` sentinel).

## Pages Router edge case

This pack is App-Router-era. On a Pages Router repo (no `app/` dir), apply ONLY the
router-agnostic files — [image.md](./image.md), [font.md](./font.md),
[scripts.md](./scripts.md) (its next/head section applies there),
[bundling.md](./bundling.md), [self-hosting.md](./self-hosting.md) — and SAY SO explicitly.
NEVER force App Router conventions (metadata API, route handlers, error.tsx, RSC rules)
onto Pages Router code.
