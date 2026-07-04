---
name: vercel-react-best-practices
description: React runtime performance patterns from Vercel Engineering - 58 impact-tiered rules for writing, reviewing, or refactoring React/Next.js code. Triggers on React components, Next.js pages, data fetching, bundle optimization, re-render issues, "why is this page slow", and performance work. For Next.js framework mechanics (file conventions, route handlers, metadata, image/font, caching) use next-best-practices instead. NEVER apply on cosmetic-only / reskin / token-swap briefs.
license: MIT
metadata:
  author: vercel
  version: "1.1.0"
---

# Vercel React Best Practices

Impact-tiered React/Next.js performance rule pack (58 rules, 8 clusters) imported from
Vercel's `vercel-labs/agent-skills`, wrapped in a house enforcement layer: an applicability
triage gate, a tier-ordered review protocol, a fix-verification gate, and a dated freshness
ledger. **The source of truth is the individual `rules/<rule-id>.md` files (~40 lines each).**
This SKILL.md is a router: read it, then open ONLY the specific rule files you need.

- Freshness verdicts + errata: `references/freshness-ledger.md` (dated, per-cluster)
- Provenance + upstream sync: [Provenance](#provenance--upstream-sync) section below
- Sibling skill for Next.js framework mechanics: `~/.claude/skills/next-best-practices/`

---

## HARD RULES (non-negotiable)

1. **NEVER load `AGENTS.md` into context.** It is an 83KB / ~2,976-line archival compiled
   snapshot with KNOWN corruption (section 3.4 lost all four code blocks; 7.5/7.9 have
   displaced prose; 8.2's "Correct" example contradicts its own title - details in the
   ledger appendix). ALWAYS read individual `rules/<rule-id>.md` files instead. Loading
   AGENTS.md whole burns ~33k tokens on content available per-rule at ~40 lines each.
   This exact failure is documented upstream (vercel-labs/agent-skills issue #169).

2. **ALWAYS run the Applicability Triage before citing any rule** (4 checks, block emitted
   first - see [Applicability Triage Gate](#applicability-triage-gate)). Skipping the
   block is a protocol violation.

3. **NEVER apply this skill on a cosmetic-only / reskin / className-token-swap brief.**
   Zero refactor suggestions on cosmetic work. Verified failure: Christopher explicitly
   removed this skill from the Pulse dark-reskin brief because it "would tempt refactor
   suggestions that violate the cosmetic-only rule" (memory
   `project_pulse_dark_theme_reskin.md`). Cosmetic brief detected in triage -> STOP,
   report "skill not applicable", do nothing else.

4. **NEVER suggest `<Activity>` or `useEffectEvent` on react < 19.2** - the imports fail
   at build time (both shipped stable in React 19.2, 2025-10-01). Below 19.2:
   CSS visibility / conditional render replaces Activity; the manual ref-store pattern
   (`rules/advanced-event-handler-refs.md`, "Correct" example) replaces useEffectEvent.
   ALWAYS state the version gate when citing `rendering-activity`, `advanced-use-latest`,
   or `advanced-event-handler-refs`. Never bump a React major/minor as a drive-by fix.

5. **NEVER describe useEffectEvent results as "stable references".** Per react.dev: an
   Effect Event's identity intentionally CHANGES every render. Effect Events may only be
   called from inside Effects (or other Effect Events), must NOT be passed to other
   components or Hooks, and must NOT be used to dodge dependency arrays. The pack's
   "Stable Callback Refs" framing is wrong - see ledger errata E3.

6. **React Compiler enabled -> manual memoization rules are N/A.** NEVER file findings for
   `rerender-memo`, `rerender-memo-with-default-value`, `rerender-simple-expression-in-memo`,
   `rendering-hoist-jsx`, or the stable-callback rationale of `rerender-functional-setstate`
   when the compiler is on. ALWAYS still apply the correctness-motivated rules: functional
   setState for stale closures, `rerender-derived-state-no-effect`, `js-tosorted-immutable`,
   `server-auth-actions`.

7. **NEVER copy `client-swr-dedup.md` imports verbatim - they do not compile.** Correct
   public API (context7-verified /vercel/swr, both DEFAULT exports):
   `import useSWRImmutable from 'swr/immutable'` and
   `import useSWRMutation from 'swr/mutation'`.
   The rule file's `import { useImmutableSWR } from '@/lib/swr'` is a Vercel-internal
   wrapper that does not exist in user projects, and its named-import mutation form is
   wrong. Ledger errata E2.

8. **`server-auth-actions` is a SECURITY rule, not a perf rule - it outranks every other
   rule in this pack.** ALWAYS verify auth + authz INSIDE every Server Action. NEVER let a
   perf refactor move or remove an auth check. If parallelizing, only non-privileged
   fetches may start before the auth await (see Playbook P4). House Security-First
   Thinking applies.

9. **NEVER hand-roll localStorage theme persistence on Aenoxa/house website builds** -
   `next-themes` owns theming (house Website Build Defaults; it implements the
   inline-script no-flicker technique internally, with cookie persistence). The
   `rendering-hydration-no-flicker` pattern is for OTHER client-only data. NEVER
   interpolate user-controlled data into a `dangerouslySetInnerHTML` inline script (XSS).

10. **NEVER claim a performance improvement without a measurement or an explicit
    `UNVERIFIED` flag** (house `feedback_verify_load_bearing_claims`). Evidence types per
    fix class are quantified in the [Fix-Verification Gate](#fix-verification-gate).

11. **NEVER recommend `.sort()` on props/state.** Use `.toSorted()` (Chrome 110+,
    Safari 16+, Firefox 115+, Node 20+) or the `[...arr].sort()` fallback for older
    targets (`rules/js-tosorted-immutable.md`).

12. **Boundary: React runtime/component/JS patterns live HERE; Next.js framework mechanics
    live in `next-best-practices`.** ALWAYS cross-cite the sibling instead of duplicating
    its content. Ownership table below.

13. **NEVER rewrite, rename, or delete the 58 `rules/*.md` files.** They are the imported
    upstream payload, kept byte-diffable for upstream sync (this is why
    `advanced-use-latest.md` keeps its legacy filename). Corrections travel via the
    freshness ledger + the router annotations in this file. Retirements are ledger entries
    with reasons, never file deletions.

14. **Browser-based perf verification defers 100% to the `/agent-browser` skill** for all
    automation mechanics (multi-port /claim lifecycle, `tab new` is broken, qb-shoot
    fallback, DPR trim, never kill the live browser, never Playwright MCP). This skill
    carries zero browser recipes of its own.

---

## Applicability Triage Gate

**BLOCKING. Emit this block (4 checks, 5 lines) BEFORE citing any rule.** Cosmetic task -> STOP.

```
REACT TRIAGE
  React version : <from package.json>          (gates Activity / useEffectEvent at 19.2)
  Compiler      : <on|off>                     (gates the manual-memoization rules)
  Task type     : <feature|review|refactor|perf-debug | COSMETIC-ONLY -> STOP>
  Framework     : <Next.js <ver> | plain React/Vite>   (gates server-*/bundle-* clusters)
  In scope      : <cluster list that survives the checks>
```

**The 4 checks (all commands verified):**

```bash
# 1. React version
jq -r '.dependencies.react // .devDependencies.react // "absent"' package.json

# 2. React Compiler enabled?
grep -rs "babel-plugin-react-compiler\|reactCompiler" package.json next.config.* babel.config.* 2>/dev/null
# any hit -> Compiler: on

# 3. Task type - read the brief. Trigger words for COSMETIC-ONLY -> STOP:
#    "reskin", "recolor", "theme swap", "token swap", "className only", "no logic changes",
#    "cosmetic". Also skip on prototype/throwaway code (perf review is premature there).

# 4. Framework
jq -r '.dependencies.next // "not-next"' package.json
```

**Gate consequences:**

| Condition | Effect |
|---|---|
| Task = cosmetic-only | STOP. Skill does not apply. Report and exit. (Hard Rule 3) |
| React < 19.2 | `rendering-activity`, `advanced-use-latest` OFF; `advanced-event-handler-refs` ref-store form only |
| Compiler on | `rerender-memo`, `rerender-memo-with-default-value`, `rerender-simple-expression-in-memo`, `rendering-hoist-jsx` OFF; keep correctness rules (Hard Rule 6) |
| Plain React/Vite (no Next) | `server-*` cluster OFF; `bundle-*` applies minus `next/dynamic` + `optimizePackageImports` specifics; `async-api-routes` applies to whatever server framework exists |
| Next.js >= 13.5 | `bundle-barrel-imports` config advice is mostly obsolete - see errata E1 (default auto-optimized list) |
| House VPS deploy (long-lived Docker, not serverless) | `server-cache-lru` / `server-hoist-static-io` caches persist FOREVER - TTL mandatory, see Playbook P5 |

---

## Boundary vs next-best-practices (ownership table)

Both skills fire on Next.js work. Ownership is split by layer - cross-cite, never duplicate.

| Topic | Owner | Cross-cite |
|---|---|---|
| Promise parallelization, waterfalls, Suspense streaming trade-offs | HERE (`async-*`) | Next-specific preload/data patterns: `next-best-practices/data-patterns.md` |
| CSR bailout (`useSearchParams` needs Suspense) | next-best-practices | `next-best-practices/suspense-boundaries.md` |
| Barrel imports, dynamic imports, deferring third-party JS | HERE (`bundle-*`) | Server-incompatible packages, ESM/CJS, bundle analysis: `next-best-practices/bundling.md` |
| Server Action auth, RSC serialization, per-request vs cross-request caching | HERE (`server-*`) | Route-handler mechanics, `after()` API details, directives: `next-best-practices/route-handlers.md`, `functions.md`, `directives.md` |
| SWR client fetching, event listeners, localStorage | HERE (`client-*`) | - |
| Re-render + rendering optimization, hydration no-flicker PATTERN | HERE (`rerender-*`, `rendering-*`) | Hydration error DEBUGGING (causes, overlay): `next-best-practices/hydration-error.md` |
| Raw JS hot-path patterns | HERE (`js-*`) | - |
| File conventions, metadata/OG, `next/image`, `next/font`, middleware/proxy, parallel routes, self-hosting | next-best-practices | its `file-conventions.md`, `metadata.md`, `image.md`, `font.md`, `parallel-routes.md`, `self-hosting.md` |
| Theming on house builds | NEITHER - `next-themes` per house Website Build Defaults | Hard Rule 9 |

---

## Rule Categories by Priority

The impact-tier ordering is the spine of this pack. Reviews MUST walk it top-down.

| Priority | Category | Impact | Prefix | Count |
|----------|----------|--------|--------|-------|
| 1 | Eliminating Waterfalls | CRITICAL | `async-` | 5 |
| 2 | Bundle Size Optimization | CRITICAL | `bundle-` | 5 |
| 3 | Server-Side Performance | HIGH | `server-` | 8 |
| 4 | Client-Side Data Fetching | MEDIUM-HIGH | `client-` | 4 |
| 5 | Re-render Optimization | MEDIUM | `rerender-` | 12 |
| 6 | Rendering Performance | MEDIUM | `rendering-` | 9 |
| 7 | JavaScript Performance | LOW-MEDIUM | `js-` | 12 |
| 8 | Advanced Patterns | LOW | `advanced-` | 3 |

Total: 58 rules (the AGENTS.md abstract's "40+ rules" is stale upstream prose; 58 is correct).

## Rule Index (read `rules/<id>.md` for the full rule)

Annotation legend:
`[>=19.2]` React 19.2 version gate | `[ERRATA]` correction in ledger | `[N/A-if-compiler]`
skip when React Compiler on | `[SECURITY]` outranks perf | `[HOUSE]` house-rule interaction.

### 1. Eliminating Waterfalls (CRITICAL)

- `async-defer-await` - Move await into branches where actually used
- `async-parallel` - Use Promise.all() for independent operations
- `async-dependencies` - Partial-dependency parallelization. **Default to the
  zero-dependency promise-chaining alternative shown in the rule**; `better-all` is
  OPTIONAL, only for genuinely complex dependency graphs (house dependency caution -
  /preflight runs a dependency denylist)
- `async-api-routes` - Start promises early, await late in API routes (its sessionPromise
  pattern is the auth-safe parallelization template - see Playbook P4)
- `async-suspense-boundaries` - Use Suspense to stream content. **Includes when NOT to
  stream: layout-critical data, above-fold SEO content, layout-shift aversion, small fast
  queries** - do not lose that half. CSR-bailout specifics belong to
  `next-best-practices/suspense-boundaries.md`

### 2. Bundle Size Optimization (CRITICAL)

- `bundle-barrel-imports` - Import directly, avoid barrel files `[ERRATA E1]` - on
  Next.js >= 13.5 the commonly named libraries (lucide-react, @mui/material, date-fns,
  react-icons/*, ...) are auto-optimized by a built-in default list; do NOT hardcode
  `lucide-react/dist/esm/*` internal paths (version-brittle)
- `bundle-dynamic-imports` - Use next/dynamic for heavy components
- `bundle-defer-third-party` - Load analytics/logging after hydration
- `bundle-conditional` - Load modules only when feature is activated
- `bundle-preload` - Preload on hover/focus for perceived speed

### 3. Server-Side Performance (HIGH)

- `server-auth-actions` - Authenticate Server Actions like API routes `[SECURITY]` -
  auth + authz INSIDE every action + zod input validation; the pack's most important rule
- `server-cache-react` - Use React.cache() for per-request deduplication
- `server-cache-lru` - LRU cache for cross-request caching `[HOUSE]` - on long-lived VPS
  processes ALWAYS pair with TTL, never module-cache per-user/mutable data (Playbook P5)
- `server-dedup-props` - Avoid duplicate serialization in RSC props
- `server-hoist-static-io` - Hoist static I/O (fonts, logos) to module level `[HOUSE]` -
  same long-lived-process staleness caveat (Playbook P5)
- `server-serialization` - Minimize data passed to client components
- `server-parallel-fetching` - Restructure components to parallelize fetches
- `server-after-nonblocking` - Use after() for non-blocking operations (API mechanics:
  `next-best-practices/functions.md`)

### 4. Client-Side Data Fetching (MEDIUM-HIGH)

- `client-swr-dedup` - SWR for automatic request deduplication `[ERRATA E2]` - two of its
  import lines do not compile; correct forms in Hard Rule 7 and the Do/Don't table
- `client-event-listeners` - Deduplicate global event listeners
- `client-passive-event-listeners` - Use passive listeners for scroll
- `client-localstorage-schema` - Version and minimize localStorage data

### 5. Re-render Optimization (MEDIUM)

- `rerender-defer-reads` - Don't subscribe to state only used in callbacks
- `rerender-memo` - Extract expensive work into memoized components `[N/A-if-compiler]`
- `rerender-memo-with-default-value` - Hoist default non-primitive props `[N/A-if-compiler]`
- `rerender-dependencies` - Use primitive dependencies in effects
- `rerender-derived-state` - Subscribe to derived booleans, not raw values
- `rerender-derived-state-no-effect` - Derive state during render, not effects
  (correctness - applies even with compiler)
- `rerender-functional-setstate` - Functional setState for stable callbacks (keep even
  with compiler: prevents stale-closure BUGS, not just re-renders)
- `rerender-lazy-state-init` - Pass function to useState for expensive values
- `rerender-simple-expression-in-memo` - Avoid memo for simple primitives `[N/A-if-compiler]`
- `rerender-move-effect-to-event` - Put interaction logic in event handlers
- `rerender-transitions` - Use startTransition for non-urgent updates
- `rerender-use-ref-transient-values` - Use refs for transient frequent values

### 6. Rendering Performance (MEDIUM)

- `rendering-animate-svg-wrapper` - Animate div wrapper, not SVG element
- `rendering-content-visibility` - Use content-visibility for long lists
- `rendering-hoist-jsx` - Extract static JSX outside components `[N/A-if-compiler]`
- `rendering-svg-precision` - Reduce SVG coordinate precision
- `rendering-hydration-no-flicker` - Inline script for client-only data `[HOUSE]` - for
  NON-theme client-only data only; theming = next-themes (Hard Rule 9); never interpolate
  user input into the inline script
- `rendering-hydration-suppress-warning` - Suppress expected mismatches
- `rendering-activity` - Activity component for show/hide `[>=19.2]` `[ERRATA E4]` -
  hidden mode UNMOUNTS Effects (subscriptions/timers torn down) and defers updates while
  preserving state; below 19.2 use conditional render / CSS visibility
- `rendering-conditional-render` - Use ternary, not && for conditionals (`count && <X/>`
  renders a literal 0/NaN)
- `rendering-usetransition-loading` - Prefer useTransition for loading state

### 7. JavaScript Performance (LOW-MEDIUM)

Only claim wins here for measured hot paths (profiler-verified) - micro-optimizing cold
code is noise.

- `js-batch-dom-css` - Group CSS changes via classes or cssText (its csstriggers.com link
  is dead - use the Paul Irish gist it also links)
- `js-index-maps` - Build Map for repeated lookups
- `js-cache-property-access` - Cache object properties in loops
- `js-cache-function-results` - Cache function results in module-level Map
- `js-cache-storage` - Cache localStorage/sessionStorage reads
- `js-combine-iterations` - Combine multiple filter/map into one loop
- `js-length-check-first` - Check array length before expensive comparison
- `js-early-exit` - Return early from functions
- `js-hoist-regexp` - Hoist RegExp creation outside loops (beware `/g` lastIndex state)
- `js-min-max-loop` - Loop for min/max instead of sort (spread caps at ~124k elems Chrome / ~638k Safari)
- `js-set-map-lookups` - Use Set/Map for O(1) lookups
- `js-tosorted-immutable` - toSorted() for immutability (Node 20+; `[...arr].sort()` fallback)

### 8. Advanced Patterns (LOW)

- `advanced-event-handler-refs` - Store event handlers in refs `[ERRATA E3]` - the
  ref-store "Correct" example works on ALL React versions and is the pre-19.2 fallback;
  the useEffectEvent alternative is `[>=19.2]` and its "stable function reference" claim
  is wrong (identity changes every render; only call inside Effects)
- `advanced-init-once` - Initialize app once per app load
- `advanced-use-latest` - useEffectEvent for effect-event callbacks `[>=19.2]` `[ERRATA E3]` -
  legacy filename; there is NO useLatest hook anywhere in this pack. Same react.dev
  caveats as above apply

---

## Review Protocol (tier-ordered, mandatory shape)

A perf review that skips clusters 1-3 is INCOMPLETE - they carry the CRITICAL/HIGH impact.

**Worked recipe - full perf review of a Next.js repo (6 steps):**

1. **Triage block** (gate above). Cosmetic -> stop. Record version/compiler/framework.
2. **Cluster 1 sweep (async):** hunt sequential awaits in `app/` + API routes:
   ```bash
   # files with an await on consecutive lines (heuristic - verify each hit by reading it):
   grep -rPzl 'await[^\n]*\n[^\n]*await' app/ --include="*.ts" --include="*.tsx"
   ```
   Check `Promise.all` usage, promise-started-early patterns, Suspense boundary placement
   (including the when-NOT-to-stream list).
3. **Cluster 2 sweep (bundle):** barrel imports of known-heavy libs NOT covered by the
   Next.js default list (errata E1), missing `next/dynamic` on heavy client-only
   components, third-party scripts loaded before hydration.
4. **Cluster 3 sweep (server):** EVERY Server Action checked for internal auth
   (`server-auth-actions` - grep `'use server'` files for a session/auth call), module
   caches without TTL, per-request re-reads of static assets, RSC props over-serialization.
5. **Clusters 4-8 only where symptoms exist** - profiler evidence, jank reports, a named
   slow interaction. Do not carpet-bomb a healthy codebase with MEDIUM/LOW findings.
6. **Emit the graded report** (format below).

**Report format - one finding per line, max 25 findings** (overflow: report the count +
top-N by severity):

```
<CRITICAL|HIGH|MEDIUM|LOW> | <rule-id> | <file>:<line> | <one-line fix>
```

Severity is inherited from the rule's `impact:` frontmatter tag. Every finding cites a
rule-id and a file:line - no vibes-based findings.

---

## Fix-Verification Gate (per applied fix)

Every fix report line carries evidence or the literal flag `UNVERIFIED`. Claiming an
unmeasured win violates house `feedback_verify_load_bearing_claims`.

| Fix class | Required evidence |
|---|---|
| Waterfall (`async-*`, `server-parallel-fetching`) | Before/after wall-clock (`time curl` the route) or a network trace showing serial -> parallel |
| Bundle (`bundle-*`) | `next build` size diff or module-count diff for the touched route |
| Re-render (`rerender-*`, `rendering-*`) | React DevTools profiler render-count diff on the affected interaction |
| JS hot path (`js-*`) | Profiler timing on the measured hot path - if it was never profiled hot, do not claim a win |
| Security (`server-auth-actions`) | Unauthed invocation attempt now rejected (test or curl output) |

If the environment cannot produce the measurement (no running app, no build access),
apply the fix, flag `UNVERIFIED`, and say exactly what measurement is owed. Browser-based
measurement: defer to `/agent-browser` (Hard Rule 14).

**Worked recipe - proving a waterfall fix:** capture baseline (`time curl -s -o /dev/null
http://localhost:3000/<route>` x3, take median, or a dev-tools network waterfall
screenshot) -> apply parallelization -> re-capture identically -> report the ms delta.
Unmeasurable -> `UNVERIFIED` explicitly.

---

## Failure-Mode Playbooks

**P1 - Context blown by AGENTS.md.** Symptom: agent loaded the 83KB compiled doc.
Recovery: stop reading it; cite rule-ids from this router only; open just the specific
`rules/<id>.md` needed (~40 lines each). Do not summarize AGENTS.md "since it's already
loaded" - its corrupted sections poison the summary.

**P2 - `'react' has no export named Activity/useEffectEvent`.** Cause: react < 19.2.
Recovery: Activity -> conditional render (`{open ? <Menu/> : null}`) or a CSS visibility
toggle (accept state loss, or lift state up); useEffectEvent -> the ref-store pattern from
`rules/advanced-event-handler-refs.md` (store handler in a ref, update it in an effect,
call `ref.current` inside the subscribing effect). NEVER bump React versions as a
drive-by fix - that is its own task with its own triage.

**P3 - Compiler-enabled repo flagged with useMemo/memo findings.** Recovery: drop all
`[N/A-if-compiler]` findings, keep correctness findings (functional setState,
derived-state-no-effect, toSorted, auth), re-emit the report, and note "React Compiler
active" in the triage block so the reviewer sees why the memo findings vanished.

**P4 - Perf refactor broke a Server Action.** Root cause is usually an auth check moved
out during parallelization. Recovery recipe: `auth()` stays awaited BEFORE any
authorization-dependent mutation; only non-privileged fetches start early. The
`rules/async-api-routes.md` "Correct" example is the template: `sessionPromise` STARTS
early but is AWAITED before `session.user.id` is used. Re-run the unauthed-invocation
check from the Fix-Verification Gate before closing.

**P5 - LRU/module-level cache serving stale data on VPS deploys.** House apps run as
long-lived Docker processes (not serverless), so `server-cache-lru` and
`server-hoist-static-io` module caches persist indefinitely - the upside is bigger than
on Vercel, and so is the staleness risk. Rules: ALWAYS set `ttl` on LRUCache (the rule's
own example uses 5 min - keep it); NEVER module-cache per-user or mutable data without
an invalidation path; document that caches reset only on container restart/deploy. The
pack's Fluid Compute notes (`server-cache-lru`, `server-hoist-static-io`) describe
Vercel's shared-instance model - translate, don't copy.

---

## Do / Don't quick table

| Topic | DO | DON'T |
|---|---|---|
| SWR immutable | `import useSWRImmutable from 'swr/immutable'` | `import { useImmutableSWR } from '@/lib/swr'` (Vercel-internal, won't compile) |
| SWR mutation | `import useSWRMutation from 'swr/mutation'` | `import { useSWRMutation } from 'swr/mutation'` (it's a default export) |
| Conditional render | `count > 0 ? <X/> : null` | `count && <X/>` (renders 0/NaN) |
| Barrel imports (Next >= 13.5) | Keep ergonomic named imports for default-list libs; add `experimental.optimizePackageImports: ['lib']` only for uncovered libs | Hardcode `lucide-react/dist/esm/icons/*` internals (breaks across releases) |
| Barrel imports (non-Next bundlers) | Package-DOCUMENTED subpath imports (`@mui/material/Button`) | `dist/esm` internal paths |
| Partial-dependency parallelism | Zero-dep promise chaining (`userPromise.then(u => fetchProfile(u.id))` + one `Promise.all`) | Reach for `better-all` on simple graphs (new dep; denylist-checked by /preflight) |
| Sorting state/props | `.toSorted()` / `[...arr].sort()` | `.sort()` in place |
| Theming (house builds) | `next-themes` | Hand-rolled localStorage + inline script |
| Effect Events | Call only inside Effects; treat identity as unstable | Pass to components/Hooks; use to dodge dependency arrays |

---

## Provenance & Upstream Sync

- **Upstream:** `github.com/vercel-labs/agent-skills`, path `skills/react-best-practices`.
  Originally created by [@shuding](https://x.com/shuding) at Vercel. MIT license.
  Announced via the Vercel blog post "Introducing React Best Practices" (Jan 2026).
- **Local snapshot:** imported **2026-04-07** (all file mtimes 21:05, single import event)
  at **58 rules**. The upstream repo's build tooling (`pnpm build`, `rules/_template.md`,
  `rules/_sections.md`, `src/`, `metadata.json`, `test-cases.json`) was NOT imported -
  the README below its banner describes a workflow that does not exist here.
- **Drift status (checked 2026-07-03):** upstream has grown to ~70 rules across the same
  8 categories - the local snapshot is ~12 rules behind. Upstream issue #169 documents
  the AGENTS.md context-bloat problem this wrapper quarantines.
- **Editing policy:** `rules/*.md` frontmatter (`title` / `impact` / `impactDescription` /
  `tags`) must stay parseable and files must stay byte-identical to import, so upstream
  diffs stay clean. All house corrections live in this router + the freshness ledger.

**Upstream sync protocol (manual, run when drift matters):**

1. List upstream rule filenames (`skills/react-best-practices/rules/` in the repo) and
   diff against `ls rules/` locally.
2. Import NEW upstream rules verbatim (no restyling).
3. Ledger-verify each new rule (same discipline as `references/freshness-ledger.md` -
   context7/official-source citation per verdict) BEFORE adding it to the Rule Index above.
4. For rules upstream has since EDITED: prefer re-importing the upstream file verbatim and
   re-running its ledger row, over hand-merging.
5. Update this section's snapshot count + date, and the ledger's header date.

---

## Freshness Ledger

`references/freshness-ledger.md` - dated per-cluster verdict table
(verified-current / corrected / gated / retired-stale), per-rule errata E1-E4, the
AGENTS.md corruption appendix, and re-verify triggers (any React minor, any Next major,
or 6 months since the ledger date - whichever comes first). Ledger updates require a
source citation (context7 or an official blog/doc), never memory.
