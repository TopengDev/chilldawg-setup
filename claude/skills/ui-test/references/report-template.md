# UI-QA.md Report Template (normative)

Path: `./UI-QA.md` — fixed, overwritten each run. Written EVEN on interruption (partial
results + banner). Screenshot layout: `./ui-test-screenshots/{role}/{page}-{theme}.png`,
plus `{role}/failures/`, `{role}/flows/`, `{role}/elements/` — compatible with existing
field artifacts (aenoxa_dashboard, zerog-smoke). Filenames NEVER contain credential values.

Anti-slop contract: every number below is COMPUTED from recorded results, never templated
in. Every finding cites evidence (screenshot path + what it observably shows, or an eval
result). The verdict quotes the gate results that produced it.

```markdown
# UI QA Report — {Project Name}

Date: {YYYY-MM-DD HH:MM}
Mode: {quick | full}{ (adapted: <auth.mode note if none/external>)}
Target: {local | staging} {URL}
Driver: agent-browser via claimed port {N} (qutebrowser tab-isolation proxy)
Themes: {light, dark | light-only (exception: <cited reason>)}
Mutation tier: {read-only | test-tenant "<name>"}

<!-- ONLY if the run did not complete: -->
> ⚠ UI testing interrupted — partial results only. Completed: {what}. Missing: {what}.

## Executive Summary

Verdict: {SHIP | FIX BEFORE SHIP | DO NOT SHIP}
Roles tested: {n}/{configured} · Pages: {n} · Elements tested: {n} · Flows: {n}
Findings: P0: {n} · P1: {n} · P2: {n} · P3: {n}

## Gate Results  ← the verdict MUST be derivable from this block alone

| Gate | Result | Detail |
|---|---|---|
| P0/P1 count | {PASS: 0/0 | FAIL: ...} | |
| Login per role | {PASS all | FAIL: <role>} | |
| Coverage arithmetic | {PASS every page | FAIL: <page> found N ≠ T+S} | |
| Theme parity | {PASS both themes | LIGHT-ONLY (exception cited) | FAIL} | |
| Screenshot QA | {PASS n/n shots | FAIL: <list>} | fx:mean audited per batch |
| Mutation ledger | {empty | n entries, all accounted} | |

## Role × Page Matrix (per theme)

| Page | {role1} light | {role1} dark | {role2} light | {role2} dark |
|---|---|---|---|---|
| {page} | PASS/FAIL | ... | ... | ... |

## Element Coverage (the arithmetic gate, per page)

| Page | Found | Tested | Passed | Failed | Skipped (reasons) | Arithmetic |
|---|---|---|---|---|---|---|
| {page} | {N} | {T} | {M} | {K} | {S} ({disabled: a, hazard-native: b, hazard-unprobed: c, hazard-deferred: d, not-refound: e, unsupported-type: f, hidden: g}) | {N} == {T}+{S} ✓/✗ |

Per-class counts: SAFE {n} · NAV {n} · FORM {n} · HAZARD-DESTRUCTIVE {n} ·
HAZARD-IRREVERSIBLE {n} · HAZARD-SESSION {n} · HAZARD-NATIVE {n} · HAZARD-ACCOUNT {n}

"Coverage: 100%" may appear ONLY where the arithmetic column proves it.

## Theme Parity

- Switch mechanism: {app switcher element + eval evidence: html class/data-theme value}
- Color-scheme pin: light pass = AGENT_BROWSER_COLOR_SCHEME=light, dark pass = dark (per-batch fx:mean audit done)
- Parity findings: {none | list — element readable in <theme> but broken in <theme>, → P1}
<!-- light-only runs: state the exception here, verbatim: config themes:["light"],
     oneshot-webapp light-only house rule (or internal-only tool) -->

## Visibility / Role Isolation

| Role | shouldSee | shouldNotSee | Result |
|---|---|---|---|
| {role} | {n}/{n} visible | {n}/{n} hidden | PASS / FAIL (→P0 if a shouldNotSee is visible) / NOT_CONFIGURED |

## Flow Results

| Flow | Role | Steps | verifyState | Status | Evidence |
|---|---|---|---|---|---|
| {name} | {role} | {passed}/{total} | {row present in list re-fetch | n/a} | PASS/FAIL | [shot](./ui-test-screenshots/{role}/flows/{name}-{theme}.png) |

## Responsive (full mode)

375x812: {findings or "no horizontal overflow on any page (scrollWidth == clientWidth everywhere)"}
768x1024: {findings}
Viewport restored: {yes — teardown item}
Note: emulation is necessary-not-sufficient for real-device bugs — device-class findings need a real-device check.

## Locale Spot-Check (if locales configured)

Crawl locale: {id}. Secondary {en} spot-check on {pages}: {hardcoded-string leaks found | none}.

## Findings

### P0 — Critical
#### {Finding title}
- **Description**: {what is wrong — falsifiable, no adjectives}
- **Affected**: {page / role / theme}
- **Evidence**: [screenshot](./ui-test-screenshots/...) — shows {what is observably visible}; {eval output if any}

### P1 — High
{same shape; theme-parity and silent-write findings land here}

### P2 — Medium
{same shape}

### P3 — Low
{same shape; typography floor violations carry the computed-style eval as evidence}

## Mutation Ledger (append-only)

{0 mutations executed.
 — or —
| # | Page | Element | Action | Entity | Cleanup |
|---|---|---|---|---|---|
| 1 | Products | Save | create | UITEST-Product-01 | left-in-place (human-gated teardown) |}

## Blocked / Skipped (honest gaps)

- {role BLOCKED(no logout) | element blocked(native OS picker) | page skipped(reason) | none}

## Screenshots

{Gallery: per role → per theme → page shots; failures and flows subfolders linked.}
```

## Notes for the writer

- **Interrupted runs**: keep every recorded result, add the banner, set the verdict from
  what IS known (an interrupted run can still be DO NOT SHIP; it can never be SHIP — gate 3
  fails by definition).
- **Discarded wedge-window findings** (SKILL §10 mass-failure rule): list the discarded
  window under Blocked/Skipped with the diagnosis (e.g. "pages X-Y re-run after §10.0
  ladder found next dev pegged").
- **Hygiene grep before finishing** (SKILL §11): no token/credential patterns in this file;
  role emails may appear only as env-var NAMES, never values.
- The old v1 template (role×page matrix, element coverage, page details, flow table,
  P0-P3 findings, screenshot gallery) is a strict subset of this one — consumers of old
  reports lose nothing.
