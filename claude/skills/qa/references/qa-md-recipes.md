# /qa — QA.md recipes (template, worked findings, checklist, redacted scans)

Depth behind SKILL.md §9-§10. The verdict rubric + 5-field schema live inline in the SKILL; this file
carries the full template, worked examples (one good, one banned), the pre-report checklist, and
per-language redacted secret-scan variants.

---

## 1. Full QA.md template

```markdown
# QA Report — {Project Name}

Date: {YYYY-MM-DD HH:MM WIB}
Mode: {quick | full}
Project: {absolute path}
Type: {detected type + resolved runner, e.g. "TS/Next.js (pnpm)"}
ENV CLASS: {LOCAL | TEST-ENV/TEST-CREDS | SHARED-STAGING | REAL-DATA} — {one-line policy}
Atlas dossier: {consulted (R0 fresh) | consulted (stale, live-verified) | none present}

## Executive Summary

Verdict: {[PROVISIONAL] SHIP | FIX BEFORE SHIP | DO NOT SHIP}
Total findings: {N} (P0:{n} P1:{n} P2:{n} P3:{n} P4:{n})
Confirmed P0/P1: {n}   |   PARTIAL dimensions: {list or none}

One-paragraph plain-language summary: what works, what is broken, the single most important thing.

## Dimension Results

| Dimension               | Status                       | Findings | Note / skipped items if PARTIAL |
|-------------------------|------------------------------|----------|---------------------------------|
| Functional              | {PASS|FAIL|PARTIAL}          | {n}      |                                 |
| Edge Cases              | {PASS|FAIL|PARTIAL}          | {n}      |                                 |
| Cross-Platform          | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |
| Regression              | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |
| Destructive (Simulated) | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |
| UX Audit                | {PASS|FAIL|PARTIAL}          | {n}      |                                 |
| Performance             | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |
| Security                | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |
| State                   | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |
| Visual                  | {PASS|FAIL|PARTIAL|SKIPPED}  | {n}      | (full mode only)                |

## Test Suite Results

{sentinel-confirmed output: PASS/FAIL/SKIP counts + exit code. If the sentinel never appeared, write
"PARTIAL — suite did not complete within the dimension budget" and DO NOT report a count.}

## Findings

### P0 — Critical
{findings, each in the 5-field shape below}

### P1 — High
### P2 — Medium
### P3 — Low
### P4 — Cosmetic

## Verification notes
{which probable/theoretical findings still need confirming; any P0/P1 auto-downgraded per HR-11 and why}

## House gates
{Aenoxa web build: i18n id/en, light+dark, typography floors, CSS-build result — or "N/A: <reason>"}

## Destructive Test Plans
{full mode only: safe, backup-first procedures for a HUMAN to run later. Never fired by /qa.}

## Recommendations
{prioritized by severity. If the user wants fixes: "Route remediation to /e2e."}
```

---

## 2. Worked finding — GOOD (CONFIRMED P1, all 5 fields + evidence)

```markdown
#### Order total drops the tax line when quantity is 0

- Severity: P1
- Confidence: confirmed
- Location: src/checkout/total.ts:88  (URL: /id/checkout, state: cart with a 0-qty line)
- Evidence:
    $ pnpm exec vitest run total.test.ts -t "zero qty"   → 1 failed
    expected subtotal 45000 + tax 4950 = 49950, received 45000 (tax omitted)
    network requests: POST /api/order → 200 (masked: backend accepted the wrong total)
    screenshot: $LOGDIR/evidence/checkout-zero-qty.png (passed §9.1 gate, fx:mean 0.94)
- Reproduction:
    1. Add item A (qty 1), add item B, set B qty to 0.
    2. Proceed to checkout. Toast shows "Pesanan dibuat".
    3. Re-fetch GET /api/order/<id> → total = 45000, tax field absent.
- Impact: orders with a zeroed line persist an under-charged total; revenue loss + inconsistent invoice.
```
Why it passes: executed reproduction, captured command output AND a network+screenshot artifact,
`file:line` + URL+state, concrete steps, real impact. The toast said success — the data-state re-fetch
(HR-7) is what exposed it.

---

## 3. Worked finding — BANNED (annotated counter-example)

```markdown
#### Error handling could be improved        <- REJECTED
- The error handling in the API layer isn't great and should be refactored to be more robust.
  Consider adding more tests.
```
Why it is rejected (HR-12): no `file:line`, no confidence tier, no evidence, no reproduction, no concrete
failure scenario. "could be improved" + "add more tests" + "refactored" are banned phrasings. Either
turn it into a real 5-field finding (which specific input causes which specific wrong behavior at which
`file:line`, with a captured repro) or delete it before the verdict. The report-reviewer step (SKILL
§9.2) must catch this.

---

## 4. Pre-report checklist (10 items, blocking — run before writing the verdict)

- [ ] 1. ENV CLASS recorded in the run log AND the QA.md header (§4.4).
- [ ] 2. Every command's completion sentinel accounted for; no count read off an unfinished suite (§5.2).
- [ ] 3. Every finding passes the 5-field gate; incomplete findings deleted or completed (§9.1).
- [ ] 4. Zero secret VALUES anywhere — grep the draft QA.md for the scanned patterns' value-shapes (§6/PB-5).
- [ ] 5. Every kept screenshot passed the agent-browser §9.1 brightness/blank/DPR gate.
- [ ] 6. Network `>=400` scan done for every browser-exercised write flow (§8/HR-7).
- [ ] 7. Atlas dossier consulted (R0 freshness) or its absence noted in the header (§4.5).
- [ ] 8. House gates run (Aenoxa web build) or explicitly N/A'd with a reason (§6/HR-15).
- [ ] 9. All PARTIAL dimensions listed with their skipped items; verdict labeled PROVISIONAL if >3 (§3.1).
- [ ] 10. Cleanup checklist complete (window killed by `=name`, browser torn down, artifacts archived) (§12).

Only after all 10 pass: compute the verdict from the POST-downgrade confidences (§9.4) and write it.

---

## 5. Redacted secret-scan variants (emit path:line + pattern class ONLY — HR-3)

The default multi-pattern scan is in SKILL §6 Dimension 8. Keep the pattern list and the
noise-exclusion pipeline; change only what PRINTS. Two safe shapes:

**A. Drop the value with `cut` (keeps `file:line`):**
```bash
grep -rniE '<pattern>' <includes> . 2>/dev/null | <noise-excludes> | cut -d: -f1,2
```
`cut -d: -f1,2` = `path:line`; the matched text (field 3+) is discarded before it can print.

**B. Redact in place (keeps context, hides the value):**
```bash
grep -rniE '<pattern>' <includes> . 2>/dev/null | <noise-excludes> \
  | sed -E 's/((=|:)[[:space:]]*)("?[A-Za-z0-9_\-\/\+\.]{6,}"?)/\1<REDACTED>/'
```

**Per-language include sets:**
```bash
# JS/TS:   --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.env' --include='*.json'
# Python:  --include='*.py' --include='*.env' --include='*.ini' --include='*.cfg' --include='*.toml'
# Go:      --include='*.go' --include='*.env' --include='*.yaml' --include='*.yml'
# Rust:    --include='*.rs' --include='*.toml' --include='*.env'
# Config:  --include='*.yaml' --include='*.yml' --include='*.json' --include='*.env' --include='*.properties'
```

**Standard noise-exclude pipeline** (env-var reads are not secrets):
```bash
| grep -v 'node_modules\|target\|\.git\|/test\|spec\|example\|sample\|fixture' \
| grep -vE 'process\.env|std::env|os\.environ|os\.Getenv|import\.meta\.env|System\.getenv'
```

**NEVER** `grep -n` without the `cut`/`sed` stage — `grep -n` prints the whole matched line (the value).
If a match lands in a data/log file, treat the FILE as the finding and do NOT quote its contents (PB-5).
