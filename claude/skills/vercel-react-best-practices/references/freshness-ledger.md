# Freshness Ledger - vercel-react-best-practices

**Ledger date: 2026-07-03.** Snapshot verified against: React 19.2 (released 2025-10-01;
react.dev via context7 `/reactjs/react.dev`), SWR public API (context7 `/vercel/swr`),
Next.js config docs (context7 `/vercel/next.js`), upstream `vercel-labs/agent-skills`
(web-checked 2026-07-03).

**Re-verify trigger (whichever comes first):** any React MINOR release · any Next.js
MAJOR release · 6 months since the ledger date above. Ledger updates REQUIRE a source
citation (context7 or official blog/doc) - never memory, never vibes.

**Verdict vocabulary:**
- `verified-current` - sampled rules in the cluster hold against 2026-07 reality as written
- `corrected` - content stands but specific lines are wrong; errata below override them
- `gated` - correct ONLY under a version/feature condition recorded here + in the router
- `retired-stale` - provably wrong advice, do not apply (reason recorded; file NOT deleted)

Verification method: sample-verify by theme cluster (not all 58 files line-by-line),
with every named errata individually confirmed against the cited source.

---

## Cluster verdicts

| Cluster (rules) | Verdict | Date | Evidence source |
|---|---|---|---|
| `async-*` (5) | verified-current | 2026-07-03 | Patterns are framework-stable (Promise.all, promise-start-early, Suspense streaming). House note: `better-all` in `async-dependencies` is OPTIONAL - the rule's own zero-dep alternative is preferred (house dependency caution). `async-suspense-boundaries` already carries its own when-NOT-to-stream list - keep it surfaced. |
| `bundle-*` (5) | corrected | 2026-07-03 | Errata E1 (`bundle-barrel-imports`): Next.js built-in `optimizePackageImports` default list + `dist/esm` path brittleness. Other 4 rules current. |
| `server-*` (8) | verified-current | 2026-07-03 | `server-auth-actions` matches current Next.js auth guidance (nextjs.org auth guide) - SECURITY rule, promoted in router. Fluid-Compute notes in `server-cache-lru` / `server-hoist-static-io` are Vercel-platform framing; self-hosted annotation in router Playbook P5 (long-lived process: caches persist until restart). `after()` API mechanics defer to `next-best-practices/functions.md`. |
| `client-*` (4) | corrected | 2026-07-03 | Errata E2 (`client-swr-dedup`): two import lines do not compile against public SWR. Other 3 rules current. |
| `rerender-*` (12) | verified-current (compiler-gated) | 2026-07-03 | All 12 correct as written for non-compiler projects. With React Compiler (v1 stable, Oct 2025): `rerender-memo`, `rerender-memo-with-default-value`, `rerender-simple-expression-in-memo` are N/A (compiler auto-memoizes - the pack's own note in `rerender-memo.md` line 44 confirms). Correctness-motivated rules (`rerender-functional-setstate` stale-closure rationale, `rerender-derived-state-no-effect`) survive the compiler. |
| `rendering-*` (9) | gated + corrected | 2026-07-03 | Errata E4 (`rendering-activity`): >=19.2 gate + hidden-unmounts-Effects caveat. `rendering-hoist-jsx` N/A-if-compiler (rule's own line 46 note). `rendering-hydration-no-flicker`: pattern current, but on house builds theming belongs to next-themes (house Website Build Defaults) and user data must never be interpolated into the inline script. Other 6 rules current. |
| `js-*` (12) | verified-current | 2026-07-03 | Sampled `js-tosorted-immutable` (browser/Node support matrix correct), `js-min-max-loop` (Chrome 143 / Safari 18 spread-limit datapoint is CURRENT as of 2026-07), `js-hoist-regexp` (`/g` lastIndex hazard correct). Minor: `js-batch-dom-css` links csstriggers.com (long dead) - the Paul Irish gist it also links is the live reference. |
| `advanced-*` (3) | corrected + gated | 2026-07-03 | Errata E3: useEffectEvent >=19.2 gate + non-stable-identity caveat + `advanced-use-latest` filename/description mismatch. `advanced-init-once` current. |

---

## Errata (override the rule files' text)

### E1 - `bundle-barrel-imports.md`: Next.js auto-optimizes the named libraries by default

Verified 2026-07-03 via context7 `/vercel/next.js` (`optimizePackageImports.mdx`):
Next.js ships a BUILT-IN default optimization list including `lucide-react`, `date-fns`,
`lodash-es`, `ramda`, `antd`, `react-bootstrap`, `@ant-design/icons`, `@headlessui/react`,
`@heroicons/react/20/solid`, `@heroicons/react/24/solid`, `@heroicons/react/24/outline`,
`@visx/visx`, `@tremor/react`, `rxjs`, `@mui/material`, `@mui/icons-material`,
`recharts`, `react-use`, `@material-ui/core`, `@material-ui/icons`,
`@tabler/icons-react`, `react-icons/*`, `effect`, `@effect/*` (and more - see the doc).

- The rule presents `experimental.optimizePackageImports` as opt-in config; for the
  default-list libraries on Next.js >= 13.5 that config is REDUNDANT - keep the ergonomic
  named imports.
- Plain `lodash` (non-`es`) is NOT on the default list - it still needs manual config or
  direct imports.
- The rule's "Correct" example hardcodes `lucide-react/dist/esm/icons/check` - an
  INTERNAL path that breaks across lucide-react releases. For non-Next bundlers use
  package-DOCUMENTED subpaths (e.g. `@mui/material/Button`) instead of `dist/esm` internals.
- Next.js docs also note this optimization "is not needed when using Turbopack"
  (`local-development.mdx`).

### E2 - `client-swr-dedup.md`: two import lines do not compile

Verified 2026-07-03 via context7 `/vercel/swr` - both are DEFAULT exports:

| Rule file line | Wrong (as shipped) | Right (public SWR API) |
|---|---|---|
| line 38 | `import { useImmutableSWR } from '@/lib/swr'` | `import useSWRImmutable from 'swr/immutable'` |
| line 48 | `import { useSWRMutation } from 'swr/mutation'` | `import useSWRMutation from 'swr/mutation'` |

`@/lib/swr` is a Vercel-internal wrapper that does not exist in user projects. The rule's
core guidance (SWR dedupes identical keys across component instances) is correct.

### E3 - `advanced-use-latest.md` + `advanced-event-handler-refs.md`: useEffectEvent gates and caveats

Verified 2026-07-03 via context7 `/reactjs/react.dev` (`reference/react/useEffectEvent.md`
+ the React 19.2 blog post, 2025-10-01):

- `useEffectEvent` shipped STABLE in React 19.2. On react < 19.2,
  `import { useEffectEvent } from 'react'` FAILS at build time. Pre-19.2 fallback: the
  manual ref-store pattern (the "Correct" example in `advanced-event-handler-refs.md`,
  which works on all React versions).
- react.dev caveats the pack omits, all load-bearing:
  1. Effect Events do NOT have stable identity - it intentionally changes every render.
     This directly contradicts the pack's "Stable Callback Refs" title and the
     "creates a stable function reference" sentence in `advanced-event-handler-refs.md`.
  2. Only call Effect Events from inside Effects (or other Effect Events).
  3. Never pass them to other components or Hooks.
  4. Never use them to dodge dependency arrays wholesale.
- Filename/description mismatch: `advanced-use-latest.md` is titled "useEffectEvent for
  Stable Callback Refs" and uses `useEffectEvent`; NO `useLatest` hook exists anywhere in
  this pack. The filename is a legacy upstream artifact kept for diffability - the router
  carries the corrected description.

### E4 - `rendering-activity.md`: >=19.2 gate + hidden-mode Effect semantics

Verified 2026-07-03 via context7 `/reactjs/react.dev` (`reference/react/Activity.md` +
React 19.2 blog): `<Activity>` shipped STABLE in React 19.2 with modes
`visible | hidden`. The rule says only "preserves state/DOM" - incomplete:

- `hidden` UNMOUNTS the children's Effects (subscriptions, timers, listeners are torn
  down) and defers all updates, while PRESERVING state and DOM.
- Developers assuming effects keep running while hidden will ship subscription bugs;
  react.dev recommends StrictMode to surface problematic Effects.
- Below 19.2: conditional render (`{open ? <X/> : null}`, accepts state loss or lift
  state up) or a CSS visibility toggle.

---

## AGENTS.md corruption appendix (compile defects, confirmed by diff vs rules/)

`AGENTS.md` (2,976 lines / 83,450 bytes at import; +9 lines after the 2026-07-03
quarantine banner - the line refs below are for the ORIGINAL snapshot, add 9 in the
bannered file) is an ARCHIVAL compiled snapshot. Confirmed defects - the per-rule files
are intact and authoritative in every case:

| Section | Lines (approx) | Defect | Intact source |
|---|---|---|---|
| 3.4 Hoist Static I/O | ~786-800 | All four example headings present with ZERO code blocks | `rules/server-hoist-static-io.md` (full code, lines 14-123) |
| 7.5 Cache Storage Reads | ~2513-2527 | Explanation sentence displaced AFTER its code block with a dangling colon | `rules/js-cache-storage.md` |
| 7.9 Hoist RegExp | ~2685-2692 | Same displacement defect | `rules/js-hoist-regexp.md` |
| 8.2 Store Event Handlers in Refs | ~2894-2928 | "Correct" example uses `useEffectEvent` (contradicts the refs title), then redundantly offers useEffectEvent as "Alternative"; the actual ref-store code is missing | `rules/advanced-event-handler-refs.md` |

Also stale in AGENTS.md: the abstract claims "40+ rules" while the TOC enumerates
5+5+8+4+12+9+12+3 = 58 (58 is correct and matches the 58 files).

---

## Retired-stale

**None as of 2026-07-03.** Nothing in the pack is provably wrong enough to retire
outright. The closest candidates were the E2 SWR import forms - treated as errata (the
rule's core dedup guidance stands), not retirement. Future retirements go here as:
`rule-id | date | reason | replacement guidance | source`.

---

## Sources

- context7 `/reactjs/react.dev` - `reference/react/useEffectEvent.md`,
  `reference/react/Activity.md`, React 19.2 release post (2025-10-01)
- context7 `/vercel/swr` - import forms for `swr/immutable`, `swr/mutation`
- context7 `/vercel/next.js` - `optimizePackageImports.mdx` default list,
  `package-bundling.mdx`, `local-development.mdx` (Turbopack note)
- nextjs.org auth guide (referenced by `server-auth-actions.md` - guidance unchanged)
- `github.com/vercel-labs/agent-skills` - upstream repo, issue #169 (AGENTS.md bloat),
  rule count ~70 as of 2026-07 (local snapshot: 58 @ 2026-04-07)
