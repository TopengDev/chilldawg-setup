---
name: audit
description: Comprehensive multi-dimensional app audit — spawns 3-5 parallel lens agents (quality, security, performance, a11y+UX, biz-logic), classifies findings by severity + confidence tier, produces GA readiness verdict, and optionally auto-fixes with re-validation. Use when the user says /audit, asks to audit an app/codebase, wants a GA readiness assessment, or asks to review a full repo across multiple dimensions.
---

# /audit Skill — Multi-Dimensional App Audit

Full-codebase audit of one app OR multi-app ecosystem. Spawns parallel lens agents, each with a single sharp focus. Produces a severity-graded report, a GA readiness verdict, and an optional auto-fix + re-validate loop.

This is NOT `/qa` (which tests a running app) and NOT `/simplify` (which reviews a diff). `/audit` reviews the **full codebase** across **multiple dimensions** with **classification tiers** and **cross-cutting synthesis**.

## Usage

```
/audit                               — audit current repo (cwd)
/audit <path>                        — audit specified repo
/audit <path1> <path2> <path3> ...   — multi-repo ecosystem audit + cross-cutting synthesis
```

## Core Principles (non-negotiable)

1. **Parallel lens agents beat one general reviewer.** Each agent has ONE focus and concrete pattern lists — not fuzzy "find issues" prompts.
2. **Proof over report.** Every finding must cite `file:line` and, where possible, a concrete code path demonstrating the issue. No hand-waving.
3. **Classification tiers eliminate noise.** Every finding is tagged `confirmed | probable | theoretical`. Theoretical findings are reported but do not block verdicts.
4. **Severity is bounded.** Critical/High/Medium/Low — with strict definitions below. Don't inflate severity.
5. **Reasoning > static analyzers.** Claude understands intent. Don't just pattern-match; reason about whether the pattern is actually a problem in context.
6. **Auto-fix is gated.** Never apply fixes without explicit user selection. Always re-validate after fixing.
7. **Interactive user gate for high-risk fixes.** Present findings, user picks what to fix. Don't surprise the user.

---

## Phase 1: Setup (interactive)

Before doing anything, confirm scope with the user. Present this summary and **wait for confirmation**:

```
/audit — setup

Scope:
  - Repo(s): <paths>
  - Detected file count: <N files>
  - Detected LOC: <N lines>
  - Languages/frameworks: <detected>

Depth options:
  [1] quick     — 3 agents (quality, security, perf), ~5-10 min
  [2] standard  — 5 agents (+ a11y+UX, biz-logic), ~15-30 min  [DEFAULT]
  [3] deep      — 5 agents + compliance + deps audit + migration path, ~45-90 min

Output preference:
  [1] terse     — executive summary only
  [2] full      — full severity-graded report  [DEFAULT]
  [3] both      — exec summary at top, full report below

Auto-fix:
  [1] off               — report only  [DEFAULT]
  [2] interactive       — show findings, user picks which to fix
  [3] aggressive        — auto-fix non-breaking Low/Medium, interactive for High/Critical

Compliance frameworks:
  [1] generic   — OWASP Top 10 + WCAG 2.1 AA  [DEFAULT]
  [2] indonesian — generic + UU PDP (+Coretax if merchant app, +OJK if fintech)
  [3] custom    — user specifies (SOC 2, PCI DSS, HIPAA, NIST CSF, ...)

Reply with: depth,output,autofix,compliance  (e.g. "2,2,1,2")
```

Detect file count via Glob (`**/*`) and LOC with a quick `wc -l` on source files. Respect `.gitignore` — don't count `node_modules/`, `dist/`, `.next/`, `target/`, `venv/`, etc.

**Large codebase guardrail:** if total source file count exceeds 2000 OR LOC exceeds 300k, warn the user:

> This codebase is large. Full audit will take significant time and the lens agents may hit context limits. Recommended: scope to a specific directory (e.g. `/audit src/api`) or run `quick` depth first to triage.

Proceed only after user confirms or re-scopes.

---

## Phase 2: Per-repo parallel lens agents

For EACH repo in scope, spawn the selected lens agents **in parallel** using the Agent tool with a single message containing multiple Agent tool uses.

**Use `subagent_type: Explore`** — these are read-only investigations, no edits.

Each agent receives:
- The repo path as its root scope
- Its lens prompt (see `agents/<name>.md` files — load the full file content into the agent prompt)
- The compliance framework selection
- An explicit output format requirement (structured findings array)

### Agent roster

| Agent | Lens prompt | Depth tiers |
|-------|------------|-------------|
| quality       | `agents/quality.md`       | quick, standard, deep |
| security      | `agents/security.md`      | quick, standard, deep |
| performance   | `agents/performance.md`   | quick, standard, deep |
| accessibility | `agents/accessibility.md` | standard, deep |
| biz-logic     | `agents/biz-logic.md`     | standard, deep |
| compliance    | (inline, see below)       | deep |
| dependencies  | (inline, see below)       | deep |

### Required finding schema

Every agent must return findings in this exact JSON-compatible structure. Agents that return free-form prose get rejected and re-prompted.

```yaml
- id: <slug-unique-within-agent>
  title: <short one-line title>
  dimension: quality | security | performance | accessibility | biz-logic | compliance | dependencies
  severity: Critical | High | Medium | Low
  confidence: confirmed | probable | theoretical
  file: <path:line> or <path> if range
  evidence: |
    <exact code snippet or concrete code path demonstrating the issue>
  description: |
    <what's wrong, in concrete terms — no hedging>
  impact: |
    <who/what breaks, how bad, under what conditions>
  suggested_fix: |
    <specific fix, not "consider refactoring">
  effort: S | M | L
  references: [<CWE-xx>, <OWASP-Axx>, <WCAG-x.x.x>, <URL>, ...]
```

### Severity definitions (strict — do not inflate)

- **Critical** — security vulnerability exploitable in production, data loss risk, or blocks release. Example: SQL injection on a public endpoint, auth bypass, hardcoded prod secret in repo.
- **High** — significant bug affecting users, meaningful performance regression, or major UX failure. Example: N+1 query on the main dashboard load, broken keyboard navigation on checkout.
- **Medium** — noticeable issue, material tech debt, or compliance risk. Example: missing ARIA labels on non-critical forms, inconsistent error handling.
- **Low** — minor improvement or polish. Example: inconsistent naming, WHAT-not-WHY comment, missing loading state on non-critical view.

### Confidence tier definitions

- **confirmed** — reproducible, traceable code path, guaranteed issue. Agent has walked the full path and validated the problem exists.
- **probable** — strong indicators but some context unclear or hard to verify without runtime data. Likely real, may be false positive under some setups.
- **theoretical** — pattern matches a known anti-pattern but whether it's actually a problem depends on unknown context. Report but do not block verdicts on these.

### Compliance agent (deep only)

Inline prompt, run once per repo:

> Audit this repo for compliance with {{frameworks}}. For each framework, check:
> - **OWASP Top 10** — map each item to presence/absence in codebase, flag missing mitigations.
> - **WCAG 2.1 AA** — sample 3-5 user-facing flows, check contrast, keyboard nav, semantic HTML, ARIA usage.
> - **UU PDP** (Indonesian) — personal data collection points, consent mechanisms, data subject rights (access/rectification/deletion), breach notification readiness, data retention policies. Flag any PII stored without consent or without a retention/deletion policy.
> - **Coretax / e-faktur** — if merchant/POS app, flag missing tax invoice generation, NPWP handling, or revenue threshold reporting.
> - **OJK** — if fintech, flag missing KYC, AML checks, transaction limits, audit logging.
> - **PCI DSS** — if handling card data, flag storage of PAN, CVV, or full magnetic stripe.
> - **SOC 2** (business apps) — flag missing audit trails, access logging, change management.
>
> Output findings using the required schema, dimension: `compliance`.

### Dependencies agent (deep only)

Inline prompt, run once per repo:

> Audit dependency manifests (package.json, requirements.txt, Cargo.toml, go.mod, pom.xml, etc).
> - Flag packages with known CVEs (reference CVE IDs).
> - Flag packages pinned to compromised versions (explicit denylist: axios@1.14.1, axios@0.30.4 — supply chain compromise).
> - Flag abandoned/unmaintained packages (last publish >2 years AND low weekly downloads).
> - Flag packages with known license conflicts (AGPL in commercial apps, unspecified licenses).
> - Flag lockfile/manifest drift (version in lockfile differs wildly from manifest range).
>
> Output findings using the required schema, dimension: `dependencies`.

---

## Phase 3: Synthesis agent (if multi-repo)

After per-repo agents complete, spawn ONE synthesis agent with ALL per-repo findings inlined. Use `agents/../synthesis.md` (see `synthesis.md` in this skill directory).

Synthesis agent's job is NOT to re-find per-repo issues. It's to find **cross-cutting** issues that only appear at the ecosystem level.

---

## Phase 4: Findings aggregation & classification

Collect all findings from all agents. Assign a stable global finding number (1, 2, 3, ...) for reference in the auto-fix gate.

Deduplicate: if two agents flag the same `file:line` with similar descriptions, merge into one finding with both dimensions listed and the higher severity/confidence.

Sort findings by (severity desc, confidence desc, dimension).

---

## Phase 5: GA Readiness Verdict

Compute the verdict based on remaining (post-dedup) findings:

| Verdict | Criteria |
|---------|----------|
| **Not ready**         | ≥1 Critical confirmed OR ≥3 Critical (any confidence) OR ≥1 Critical compliance finding |
| **Pilot-ready**       | 0 Critical confirmed, ≤2 Critical probable, ≤10 High confirmed. Safe for 1-3 friendly merchants. |
| **Closed-beta-ready** | 0 Critical confirmed, 0 Critical probable, ≤5 High confirmed. Safe for 5-10 merchants with support. |
| **GA-ready**          | 0 Critical (any confidence), ≤2 High confirmed, all compliance critical/high findings resolved. |

**Top blockers:** list up to 5 findings that are driving the verdict downward. Sorted by severity then impact.

**Justification:** 2-3 sentences explaining the verdict, referencing the blockers by finding number.

---

## Phase 6: Report output

Write the full report to `/tmp/audit-report-<YYYYMMDD-HHMMSS>.md`. Follow this exact structure:

```markdown
# Audit Report — {{app or ecosystem name}}

- **Generated:** {{ISO date}}
- **Scope:** {{repo paths}}
- **Depth:** {{quick|standard|deep}}
- **Compliance:** {{frameworks}}
- **Files audited:** N
- **LOC audited:** N
- **Total findings:** N  (Critical: X, High: Y, Medium: Z, Low: W)

## Executive Summary

{{2-3 paragraphs — current status, top 3 concerns, GA verdict, recommended next 1-2 weeks of work}}

## GA Readiness Verdict

**{{verdict}}**

{{2-3 sentence justification referencing finding numbers}}

### Top Blockers

1. [#{{id}}] {{title}} — {{one-line why it blocks}}
2. ...

## Findings by Dimension

### Code Quality (N findings)
{{list findings in schema format, sorted by severity desc}}

### Security (N findings)
...

### Performance (N findings)
...

### Accessibility & UX (N findings)
...

### Business Logic Coverage (N findings)
...

### Compliance — {{framework}} (N findings)
...

### Dependencies (N findings, deep only)
...

## Cross-Cutting Issues (multi-repo only)
{{synthesis findings}}

## Remediation Plan

### Critical — fix before any launch
- [#{{global_id}}] [{{severity}}] [{{confidence}}] {{title}}
  - File: {{file:line}}
  - Issue: {{description}}
  - Fix: {{suggested fix}}
  - Effort: {{S/M/L}}

### High — fix before GA
...

### Medium — tech debt, schedule for post-launch
...

### Low — polish, nice-to-have
...
```

Each finding entry in "Findings by Dimension" must use the full schema (severity, confidence, file, evidence, description, impact, suggested_fix, effort, references).

Also emit a **terse summary to stdout** regardless of output preference:
```
/audit complete
  Findings: <C critical, H high, M medium, L low>
  Verdict: <verdict>
  Report: /tmp/audit-report-<ts>.md
  Top blockers: <list>
```

If user chose `terse` output, skip the per-dimension sections in the report file and keep only Executive Summary + Verdict + Remediation Plan.

---

## Phase 7: Interactive fix gate (if auto-fix enabled)

Skip this phase if auto-fix is `off`.

Present to user:

```
/audit — fix gate

Findings eligible for auto-fix:
  Critical: X   High: Y   Medium: Z   Low: W

Which to fix?
  [all]              — fix everything (risky)
  [critical]         — all critical
  [critical,high]    — critical + high
  [1,3,5,12]         — pick specific finding numbers
  [none]             — skip, exit

Reply:
```

Rules:
- If `aggressive` auto-fix was selected, pre-fill Low + Medium as accepted and prompt only for High + Critical.
- Never auto-fix a `theoretical` confidence finding without explicit user selection.
- For each selected finding:
  1. Apply the `suggested_fix` via Edit/Write tool.
  2. Run the repo's build command (detected from manifests — see `/qa` skill detection table).
  3. Run the repo's test command if present.
  4. Record: applied, built, tested, status (success / build-failure / test-failure).
- If build or tests fail, revert the edit and mark the finding as `fix-attempt-failed`.
- Batch edits per file where possible to reduce build runs, but isolate edits for different findings so one failure doesn't taint another.

---

## Phase 8: Re-validate loop

After applying fixes:

1. For each successfully applied fix, re-spawn the specific lens agent that flagged it with a **scoped prompt**: "verify finding #N at {{file:line}} is resolved; check for newly introduced issues in the same file/function".
2. If the agent confirms resolution AND no new findings: mark `resolved`.
3. If the finding is still present: mark `fix-ineffective`, revert the edit.
4. If new findings introduced: mark `fix-introduced-regression`, revert the edit.

After the loop, append a **Fix Report** section to the original audit report file:

```markdown
## Fix Report

Applied: N   Reverted: M   Still failing: K

| # | Finding | Status | Notes |
|---|---------|--------|-------|
| 1 | {{title}} | resolved | — |
| 3 | {{title}} | fix-ineffective | reverted, still present |
| 5 | {{title}} | fix-introduced-regression | reverted, introduced {{new finding}} |
```

Print final stdout line:
```
/audit fix loop complete
  Applied: N  Resolved: M  Reverted: K
  Final verdict: <recompute>
```

Recompute the GA verdict after fixes — it may have moved up a tier.

---

## Implementation notes for Claude running this skill

- **Use the Agent tool in parallel** — send a single message with multiple Agent tool uses (one per lens, one per repo). Do NOT use Bash-spawned workers or tmux for this skill; it's an in-session multi-agent flow.
- **Subagent type:** use `Explore` for lens agents (read-only investigation). For the synthesis agent, also `Explore`.
- **Agent prompts** — load the full content of `agents/<name>.md` into each agent's prompt. The lens prompt files are the authoritative patterns; don't paraphrase.
- **Timeout guardrail** — if an agent exceeds 10 min without returning, print a warning and proceed with partial findings from the others.
- **Context hygiene** — don't inline raw source files into the main session. Agents do that on their own. Main session only holds the structured findings arrays.
- **Respect `.gitignore`** and common build-artifact directories. If a repo has a `.auditignore` file, respect it too.
- **If the user has an existing `AUDIT.md` or `/tmp/audit-report-*.md`** from a previous run, offer to diff against it and highlight only new/resolved findings.
- **Do NOT run the repo's dev server, migrations, or any destructive command** during audit. Build + test only, and only in Phase 7.
- **Do NOT commit fixes.** The user runs `/commit` themselves when satisfied.

---

## Invocation check

When Christopher types `/audit` with no args, default to `cwd`. If cwd is `/home/christopher/claude` (the command-center discussion space), refuse with:

> /audit is a codebase skill and should not be run on the command-center directory. Either `cd` into a real repo or pass the repo path: `/audit <path>`.

---

## Files in this skill

- `SKILL.md` — this file
- `agents/quality.md` — code quality lens prompt
- `agents/security.md` — security lens prompt (OWASP Top 10)
- `agents/performance.md` — performance lens prompt
- `agents/accessibility.md` — a11y + UX lens prompt (WCAG 2.1 AA)
- `agents/biz-logic.md` — business logic + edge cases lens prompt
- `synthesis.md` — cross-cutting synthesis prompt for multi-repo audits
