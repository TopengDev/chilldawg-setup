---
name: audit
description: Comprehensive multi-dimensional app audit — detects the project type (web-app/SaaS, backend-service, data-pipeline/ETL/ML, CLI/TUI, library, infra-as-code) and adapts the lens roster (quality, security, performance, accessibility, biz-logic, data-integrity, reliability) and verdict rubric to fit it, runs the lenses as parallel read-only agents, classifies findings by severity + confidence tier, runs an adversarial verification pass that refutes Critical/High findings before the verdict, produces a type-appropriate readiness verdict, and optionally auto-fixes with re-validation. Web-app/SaaS is the unchanged default (same 5 lenses + merchant/GA rubric). Use when the user says /audit, asks to audit an app/codebase, wants a GA/readiness assessment, or asks to review a full repo across multiple dimensions.
---

# /audit Skill — Multi-Dimensional App Audit

Full-codebase audit of one app OR multi-app ecosystem. Spawns parallel lens agents, each with a single sharp focus. Produces a severity-graded report, a GA readiness verdict, and an optional auto-fix + re-validate loop.

This is NOT `/qa` (which tests a running app) and NOT `/simplify` (which reviews a diff). `/audit` reviews the **full codebase** across **multiple dimensions** with **classification tiers** and **cross-cutting synthesis**.

## Usage

```
/audit                               — audit current repo (cwd)
/audit <path>                        — audit specified repo (app-type auto-detected)
/audit <path> --type <type>          — override auto-detected project type
/audit <path1> <path2> <path3> ...   — multi-repo ecosystem audit + cross-cutting synthesis
```

`<type>` ∈ `web-app` | `backend-service` | `data-pipeline` | `cli-tui` | `library` | `infra` (see the App-Type Detection table below). Anything passed after a path on the same line (e.g. `--type data-pipeline 2,2,1,1`) is **inline config** — see "Inline config" under Phase 1; a user who passes it (or just says "proceed") skips the interactive round-trip.

## Core Principles (non-negotiable)

1. **Parallel lens agents beat one general reviewer.** Each agent has ONE focus and concrete pattern lists — not fuzzy "find issues" prompts.
2. **Proof over report.** Every finding must cite `file:line` and, where possible, a concrete code path demonstrating the issue. No hand-waving.
3. **Classification tiers eliminate noise.** Every finding is tagged `confirmed | probable | theoretical`. Theoretical findings are reported but do not block verdicts.
4. **Severity is bounded.** Critical/High/Medium/Low — with strict definitions below. Don't inflate severity.
5. **Reasoning > static analyzers.** Claude understands intent. Don't just pattern-match; reason about whether the pattern is actually a problem in context.
6. **Auto-fix is gated.** Never apply fixes without explicit user selection. Always re-validate after fixing.
7. **Interactive user gate for high-risk fixes.** Present findings, user picks what to fix. Don't surprise the user.
8. **The lens roster adapts to the app type.** A data pipeline does not get an accessibility lens; a CLI does not get a web-rubric verdict. Detect the project type, then select the lenses and the verdict rubric that actually fit it (see "App-Type Detection" + "Adaptive verdict rubric"). The web-app/SaaS path is the unchanged default — same 5 lenses, same merchant/GA rubric as before.
9. **Loud findings get a hostile second look.** Every Critical and High finding is handed to an adversarial skeptic agent that tries to REFUTE it before it reaches the verdict (Phase 4.5). Default-to-refuted: a Critical that can't be confirmed end-to-end is downgraded and no longer blocks GA. This is what keeps the report believable.

---

## Phase 1: Setup (interactive by default, inline-config aware)

Before doing anything, confirm scope with the user. Present this summary and **wait for confirmation** — UNLESS the user supplied inline config (see below), in which case skip the round-trip and proceed.

**Inline config (no round-trip):** if the invocation already carries the answers, do NOT block on the interactive prompt. Accept any of:
- `--type <type>` — sets the project type, skipping auto-detection (still run detection to confirm/echo it).
- A `depth,output,autofix,compliance` tuple on the line (e.g. `2,2,1,2`).
- An explicit "proceed" / "go ahead" / "use defaults" — run with detected type + all defaults (standard depth, full output, autofix off, generic compliance).

When inline config is present, still PRINT the resolved setup block (scope + detected type + resolved options) so the user sees what's running, but do not wait. This keeps `/audit` interactive for exploratory use while letting a decided user (or a calling workflow) one-shot it. Everything still defaults exactly as before when nothing is supplied.

```
/audit — setup

Scope:
  - Repo(s): <paths>
  - Detected file count: <N files>
  - Detected LOC: <N lines>
  - Languages/frameworks: <detected>
  - Detected project type: <type>  (see App-Type Detection below; override with --type)

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
       or:  proceed   (detected type + all defaults)
       or:  --type <type> + optionally the tuple, to override detection
```

Detect file count via Glob (`**/*`) and LOC with a quick `wc -l` on source files. Respect `.gitignore` — don't count `node_modules/`, `dist/`, `.next/`, `target/`, `venv/`, etc.

**Large codebase guardrail:** if total source file count exceeds 2000 OR LOC exceeds 300k, warn the user:

> This codebase is large. Full audit will take significant time and the lens agents may hit context limits. Recommended: scope to a specific directory (e.g. `/audit src/api`) or run `quick` depth first to triage.

Proceed only after user confirms or re-scopes (or inline config was supplied).

---

## Phase 1.5: App-type detection → adaptive lens roster

Before spawning lens agents, **detect the project type** for each repo. The type decides which lenses run (this section) and which verdict rubric applies (Phase 5). This is what makes `/audit` fit a data pipeline or a CLI as well as it fits a web app — instead of running an accessibility lens on a daemon and hand-steering the roster via args.

If the user passed `--type <type>`, use it directly (skip detection, but still echo the type in the setup block). Otherwise detect from **manifests + file signatures**, in priority order — first match wins, but cross-check with the signatures before committing:

### Detection heuristics (concrete)

| Type | Strong signals (manifests + file signatures) |
|------|----------------------------------------------|
| `web-app` (web-app/SaaS) | `next.config.*` / `vite.config.*` / `remix.config` / `nuxt.config` / `astro.config`; a `pages/`, `app/`, `src/components/`, or `src/routes/` tree with `.tsx`/`.vue`/`.svelte`; `index.html` + a bundler; Tailwind/CSS-in-JS; a `public/` assets dir. Browser-facing UI is the defining trait. |
| `backend-service` (backend-service/API) | a server framework with route handlers but **no UI tree**: `fastapi`/`flask`/`django` (with DRF/views, no templates-as-product), `express`/`nestjs`/`koa`/`hapi`, `gin`/`echo`/`fiber` (Go), Spring Boot, Rails API; gRPC `.proto` + server; an `openapi.yaml`; a `Dockerfile` exposing a service port; DB models + migrations serving an API. |
| `data-pipeline` (data-pipeline/ETL/ML) | `pandas`/`polars`/`numpy`/`pyarrow`/`dask`; orchestration: `airflow`/`prefect`/`dagster`/`luigi`/`dbt`; a `schema.sql` + ingest/transform/analyze modules; scheduled jobs (cron/systemd timers, `**/jobs/`, `**/etl/`, `**/pipeline/`); a local store written to on a schedule (sqlite/parquet/jsonl accumulation); ML training/feature code (`sklearn`/`torch`/`xgboost` + a dataset). The defining trait: it **produces/accumulates a dataset** unattended. |
| `cli-tui` (CLI/TUI) | `pyproject.toml` with `[project.scripts]` / `console_scripts`, **no web framework**, + an arg/TUI lib (`click`/`typer`/`argparse`/`textual`/`rich`/`prompt_toolkit`); `bin/` entrypoints; `package.json` with a `bin` field + `commander`/`yargs`/`ink`; Go/Rust `main` building a binary with `cobra`/`clap`. Defining trait: a human runs it as a command. |
| `library` (library/package) | a publishable package with a **public API and no entrypoint app**: `pyproject.toml`/`setup.py` with `[project]` but no `[project.scripts]` and no web/CLI app; `package.json` with `"main"`/`"exports"`/`"types"` + `"files"`, no `bin`, no app; Rust `[lib]` crate; Go module imported as a package; a `src/` of exported modules + a documented API surface, consumed by other code rather than run. |
| `infra` (infra-as-code) | **only/mostly** infra declarations: `*.tf`/`*.tfvars` (Terraform), `Dockerfile`/`docker-compose.yml` as the product, k8s `*.yaml` (Deployments/Services/Helm `Chart.yaml`), Ansible playbooks, Pulumi, CloudFormation, `cloud-init`. Defining trait: it provisions/configures infrastructure, not application logic. |

**Tie-breaking & mixed repos:**
- A repo with BOTH a UI tree AND backend routes (a Next.js app with API routes, a full-stack Rails app) → `web-app` (the broader rubric/roster covers it; a11y matters).
- A backend service that ALSO runs scheduled data jobs → pick the **dominant** trait by file mass and stated purpose; if data-accumulation is the point, `data-pipeline`, else `backend-service`. When genuinely 50/50, round toward the type whose rubric is stricter for the riskier concern (data-pipeline's data-correctness gate > service's SLO gate when a dataset is the product).
- A CLI that's also publishable as a library → `cli-tui` if a human runs it, `library` if it's primarily imported.
- **When detection is ambiguous, state the two candidates in the setup block and default to the one with the broader lens roster** (so nothing important is skipped), and tell the user they can `--type` to correct it.

### Type → lens-roster mapping

Each type runs the lenses marked ✓ at `standard` depth. `quick` drops to the **core 3 — the type's three most load-bearing lenses** (listed in the `quick` column; e.g. a data-pipeline's core-3 leads with data-integrity, not quality, because correctness of the dataset is the point). `deep` adds compliance + dependencies (run once per repo, inline prompts in Phase 2) on top of the standard roster, for every type.

| Type | quality | security | performance | accessibility | biz-logic | data-integrity | reliability | `quick` core-3 |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **web-app** | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | quality, security, performance |
| **backend-service** | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | security, reliability, biz-logic |
| **data-pipeline** | ✓ | ✓ | ✓ | — | — | ✓ | ✓ | data-integrity, reliability, security |
| **cli-tui** | ✓ | ✓ | ✓ | — | ✓ | — | ✓ | quality, reliability, biz-logic |
| **library** | ✓ | ✓ | ✓ | — | ✓ | — | — | quality, biz-logic, security |
| **infra** | ✓ | ✓ | — | — | — | ✓ | ✓ | security, reliability, data-integrity |

**HARD RULE (backward-compat — non-negotiable):** `web-app` maps to EXACTLY the current 5-lens set — **quality, security, performance, accessibility, biz-logic** — and nothing else (no data-integrity, no reliability) at `standard`. A `/audit <path>` on a web app with no flags MUST behave byte-for-byte as it did before this section existed. The two new lenses (data-integrity, reliability) NEVER attach to `web-app`.

Notes on the mapping rationale (each lens earns its slot):
- **accessibility** is web-app-only — it audits user-facing markup; a daemon, library, or pipeline has no a11y surface. (This is the dead-weight lens the market-events run had to drop manually.)
- **data-integrity** attaches where a dataset/state is the product: data-pipeline, infra (state files, drift), and is the *defining* lens for pipelines. Not web-app (its data lives behind biz-logic there).
- **reliability** attaches to anything that runs unattended over time: backend-service, data-pipeline, cli-tui (long runs/daemons), infra. Not library (no process) or web-app (request-scoped; perf+biz-logic cover it).
- **biz-logic** stays everywhere a human-facing correctness flow exists (web, service, cli, library API contracts) — dropped only for pure data-pipeline (data-integrity supersedes it there) and infra.

Carry the detected (or overridden) **type** forward — Phase 2 uses it to pick the roster, Phase 5 uses it to pick the rubric.

---

## Phase 2: Per-repo parallel lens agents

For EACH repo in scope, spawn **the lenses the detected type selected** (Phase 1.5 roster) **in parallel** using the Agent tool with a single message containing multiple Agent tool uses. Do NOT spawn a lens the roster didn't pick for this type (e.g. no accessibility on a `data-pipeline`).

**Use `subagent_type: Explore`** — these are read-only investigations, no edits.

Each agent receives:
- The repo path as its root scope
- Its lens prompt (see `agents/<name>.md` files — load the full file content into the agent prompt)
- The compliance framework selection
- An explicit output format requirement (structured findings array)

### Agent roster

The **roster table in Phase 1.5** decides which of these run for a given type + depth. This table is the catalogue of every available lens and where its prompt lives:

| Agent | Lens prompt | Runs for types (standard) | Depth tiers |
|-------|------------|---------------------------|-------------|
| quality        | `agents/quality.md`        | all types                              | quick, standard, deep |
| security       | `agents/security.md`       | all types                              | quick, standard, deep |
| performance    | `agents/performance.md`    | web, service, data-pipeline, cli, library | quick, standard, deep |
| accessibility  | `agents/accessibility.md`  | **web-app only**                       | standard, deep |
| biz-logic      | `agents/biz-logic.md`      | web, service, cli, library             | standard, deep |
| data-integrity | `agents/data-integrity.md` | data-pipeline, infra                   | quick (if in core-3), standard, deep |
| reliability    | `agents/reliability.md`    | service, data-pipeline, cli, infra     | quick (if in core-3), standard, deep |
| compliance     | (inline, see below)        | all types (deep only)                  | deep |
| dependencies   | (inline, see below)        | all types (deep only)                  | deep |

### Required finding schema

Every agent must return findings in this exact JSON-compatible structure. Agents that return free-form prose get rejected and re-prompted.

```yaml
- id: <slug-unique-within-agent>
  title: <short one-line title>
  dimension: quality | security | performance | accessibility | biz-logic | data-integrity | reliability | compliance | dependencies
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

## Phase 4.5: Adversarial verification pass

Before the verdict, **every Critical and High finding gets a hostile second look.** A lens agent's incentive is to find problems; left unchecked that inflates the report with plausible-but-unprovable Criticals, and one false Critical erodes trust in all of them. This phase spawns a skeptic per loud finding whose job is to **refute** it.

**Only Critical and High findings are verified** (Medium and Low pass through unchanged — verifying them isn't worth the cost). This bounds the work to the findings that actually move the verdict.

### Procedure

1. Collect the post-dedup Critical + High findings. **Cap at N = 12** (sorted by severity desc, then confidence desc). If there are more than 12, verify the top 12 and **note in the report that verification was capped** (the un-verified Crit/High keep their original severity/confidence but are flagged `unverified` in the Verification subsection).
2. For each finding in the verify set, spawn a skeptic agent **in parallel** (single message, multiple Agent tool uses), `subagent_type: Explore` (read-only). Load the full content of **`agents/verify.md`** into each, plus the one finding it must refute (id, title, file:line, evidence, description, impact). One finding per agent — do not batch multiple findings into one skeptic.
3. Each skeptic returns exactly one verdict (see `agents/verify.md`): `confirmed-real`, `refuted-downgrade`, or `refuted-drop`. The skeptic **defaults to REFUTED** — if it cannot confirm the bug/exploit/corruption path end-to-end, the finding does not stand at full weight.

### Applying verdicts

- **`confirmed-real`** → keep the finding at its current severity + confidence. It blocks the verdict normally.
- **`refuted-downgrade`** → downgrade confidence ONE tier (`confirmed → probable → theoretical`). The finding stays in the report but at the lower confidence — and the Phase 5 rubric only blocks on the *post-verification* confidence (e.g. a refuted-down Critical-confirmed becomes Critical-probable and no longer trips a "≥1 Critical confirmed → Not ready" gate). A finding already at `theoretical` that's refuted-downgrade is effectively dropped from blocking (theoretical never blocks).
- **`refuted-drop`** → remove from the blocking set entirely. Keep a one-line record in the Verification subsection (title + the concrete refutation reason + the guard/constraint file:line) so the reader sees it was considered and dismissed — never silently delete.

### Recording

Add a **"Verification" subsection** to the report (under the Verdict). For every verified finding, show: id, title, original severity/confidence, verdict, post-verdict severity/confidence, and the one-line refutation/confirmation reason with its citation. This makes the verdict auditable: a reader can see exactly which loud findings survived the skeptic and which were downgraded or dismissed, and why.

**The verdict (Phase 5) consumes the POST-verification findings** — it computes its tiers against the verified severities/confidences, not the raw lens output. A Critical that was refuted-down to probable no longer blocks GA at the "≥1 Critical confirmed" gate; a Critical refuted-dropped is out of the count entirely.

---

## Phase 5: GA Readiness Verdict

Compute the verdict based on the **post-verification** (Phase 4.5) findings, using the rubric for the **detected project type** (Phase 1.5). The web-app/SaaS rubric below is the original, unchanged. Pick the matching rubric table by type:

### Rubric — `web-app` / SaaS  (DEFAULT — unchanged from prior versions)

| Verdict | Criteria |
|---------|----------|
| **Not ready**         | ≥1 Critical confirmed OR ≥3 Critical (any confidence) OR ≥1 Critical compliance finding |
| **Pilot-ready**       | 0 Critical confirmed, ≤2 Critical probable, ≤10 High confirmed. Safe for 1-3 friendly merchants. |
| **Closed-beta-ready** | 0 Critical confirmed, 0 Critical probable, ≤5 High confirmed. Safe for 5-10 merchants with support. |
| **GA-ready**          | 0 Critical (any confidence), ≤2 High confirmed, all compliance critical/high findings resolved. |

### Rubric — `backend-service` / API  (reliability / SLO tiers)

Gates lean on **security**, **reliability**, and **biz-logic**; "user-facing" becomes "consumer-facing" (the clients of the API).

| Verdict | Criteria |
|---------|----------|
| **Not ready**          | ≥1 Critical confirmed (security OR reliability OR biz-logic) OR ≥3 Critical (any confidence) OR ≥1 Critical compliance finding |
| **Internal-only**      | 0 Critical confirmed, ≤2 Critical probable, ≤10 High confirmed. Safe behind a trusted network / for first-party consumers only. |
| **Partner-ready**      | 0 Critical confirmed, 0 Critical probable, ≤5 High confirmed, no unrecovered single-point reliability failure (no unhandled main-loop crash, retries+timeouts present on every external call). Safe for a few trusted external integrators. |
| **Production-SLO-ready** | 0 Critical (any confidence), ≤2 High confirmed, 0 High reliability open (graceful degradation + restart/backoff + observability on every critical path), all compliance critical/high resolved. Safe for an SLO-backed public API. |

### Rubric — `data-pipeline` / ETL / ML  (trustworthy-for-downstream — data-correctness gates)

The product is the **dataset**, so the gates are dominated by **data-integrity** + **reliability**. "Is it up" and "is it correct" are separated — a pipeline can be safe to run while its data is not yet safe to trust.

| Verdict | Criteria |
|---------|----------|
| **Not ready**                  | ≥1 Critical confirmed (data-integrity OR reliability) OR ≥3 Critical (any confidence) OR any confirmed data-loss / silent-corruption / lookahead-leakage finding |
| **Ops-ready** (safe to run)    | 0 Critical confirmed, reliability High ≤5: the pipeline stays up / recovers (no unhandled-crash main loop, units restart, no leak that OOMs). Data may still have known integrity caveats — it runs, it doesn't lose data, but downstream shouldn't fully trust the numbers yet. |
| **Trustworthy-for-downstream** | 0 Critical (any confidence) data-integrity, **0 High confirmed data-integrity** (no small-n statistic bias, no fabricated-as-real values, no double-count-on-retry, no unit/precision error on a key field, no lookahead), ≤2 High confirmed reliability. The dataset is safe to feed a report / dashboard / non-money model. |
| **Decision-grade** (trust with money/ML labels) | 0 Critical/High data-integrity (any confidence), all honesty markers present (NULL+reason for unknowns, n/quality propagated, backfill NULLs structural), core stateful path has tests, ≤1 High reliability. Safe to train a real-money algo / drive financial decisions on it. |

### Rubric — `cli-tui` / internal-tool  (ops-ready tiers)

Gates lean on **reliability** (long runs / repeated invocation), **biz-logic** (correct output), **quality**, **security** (arg/shell injection, secret handling).

| Verdict | Criteria |
|---------|----------|
| **Not ready**        | ≥1 Critical confirmed (e.g. shell/arg injection, data-destroying command with no guard) OR ≥3 Critical (any confidence) |
| **Personal-use**     | 0 Critical confirmed, ≤2 Critical probable, ≤10 High confirmed. Fine for the author on their own box. |
| **Team-ready**       | 0 Critical confirmed, 0 Critical probable, ≤5 High confirmed, no unguarded destructive default, clear error messages on bad input. Safe to hand to teammates. |
| **Distribution-ready** | 0 Critical (any confidence), ≤2 High confirmed, robust failure handling (non-zero exit on error, no crash on bad input, no resource leak on long/looped runs), all compliance critical/high resolved. Safe to publish/ship widely. |

### Rubric — `library` / package  (publish-readiness tiers)

Gates lean on **quality** (API surface, types), **biz-logic** (correctness of the public contract), **security** (no injection sinks exposed via the API), **dependencies** (deep).

| Verdict | Criteria |
|---------|----------|
| **Not ready**            | ≥1 Critical confirmed (e.g. an exposed injection sink, a correctness bug in a core public function) OR ≥3 Critical (any confidence) |
| **Breaking-change-risk** | 0 Critical confirmed, ≤2 Critical probable, ≤10 High confirmed. Usable, but the public API is unstable / under-typed / under-tested — expect breaking changes. |
| **API-stable**           | 0 Critical confirmed, 0 Critical probable, ≤5 High confirmed, public API typed + documented + covered by tests, no correctness bug in a core exported path. Safe to depend on for non-critical use. |
| **Publish-ready**        | 0 Critical (any confidence), ≤2 High confirmed, semver-honest (no silent breaking changes), committed lockfile / pinned dev deps, no known-CVE/compromised dependency, license clean. Safe to publish to a public registry. |

### Rubric — `infra` (infra-as-code)  (safe-to-apply tiers)

Gates lean on **security** (exposed secrets, over-broad IAM, open ports), **reliability** (restart/health/ordering), **data-integrity** (state-file integrity, destructive-migration / drift).

| Verdict | Criteria |
|---------|----------|
| **Not safe to apply**     | ≥1 Critical confirmed (hardcoded prod secret, world-open security group on a sensitive port, a destructive resource replacement with no lifecycle guard, public bucket with data) OR ≥3 Critical (any confidence) |
| **Apply-in-dev**          | 0 Critical confirmed, ≤2 Critical probable, ≤10 High confirmed. Safe to apply to a non-prod environment. |
| **Apply-to-staging**      | 0 Critical confirmed, 0 Critical probable, ≤5 High confirmed, no over-broad IAM/network on a prod-shaped resource, restart/health policies present on long-running services. Safe for a staging/pre-prod apply. |
| **Production-apply-ready** | 0 Critical (any confidence), ≤2 High confirmed, least-privilege IAM, no plaintext secrets (vault/SOPS/secret-manager), state-file integrity + lifecycle guards on stateful resources, all compliance critical/high resolved. Safe to apply to production. |

**Top blockers:** list up to 5 findings that are driving the verdict downward. Sorted by severity then impact.

**Justification:** 2-3 sentences explaining the verdict, referencing the blockers by finding number AND naming the rubric used (e.g. "under the data-pipeline / trustworthy-for-downstream rubric").

---

## Phase 6: Report output

Write the full report to `/tmp/audit-report-<YYYYMMDD-HHMMSS>.md`. Follow this exact structure:

```markdown
# Audit Report — {{app or ecosystem name}}

- **Generated:** {{ISO date}}
- **Scope:** {{repo paths}}
- **Project type:** {{detected type}}  ({{auto-detected | --type override}})
- **Depth:** {{quick|standard|deep}}
- **Lenses run:** {{the type's roster, e.g. data-integrity, reliability, security, quality, performance}}
- **Compliance:** {{frameworks}}
- **Files audited:** N
- **LOC audited:** N
- **Total findings:** N  (Critical: X, High: Y, Medium: Z, Low: W)  — post-verification

## Executive Summary

{{2-3 paragraphs — current status, top 3 concerns, verdict, recommended next 1-2 weeks of work}}

## GA Readiness Verdict

**{{verdict}}**  *(rubric: {{type rubric, e.g. data-pipeline / trustworthy-for-downstream}})*

{{2-3 sentence justification referencing finding numbers + the rubric used}}

### Top Blockers

1. [#{{id}}] {{title}} — {{one-line why it blocks}}
2. ...

### Verification  (Phase 4.5 — Critical/High only)

{{For each verified finding: id, title, original sev/conf → verdict → post-verdict sev/conf, with the one-line refutation/confirmation reason + citation. Note if verification was capped at 12.}}

| # | Finding | Orig | Verdict | Result | Why |
|---|---------|------|---------|--------|-----|
| {{id}} | {{title}} | {{Crit/confirmed}} | {{confirmed-real / refuted-downgrade / refuted-drop}} | {{Crit/probable / dropped}} | {{guard at file:line / traced exploit / intended}} |

## Findings by Dimension

{{Include ONLY the dimensions the detected type's roster actually ran — omit lenses that didn't run for this type. E.g. a data-pipeline report has Data Integrity + Reliability and NO Accessibility section.}}

### Code Quality (N findings)
{{list findings in schema format, sorted by severity desc}}

### Security (N findings)
...

### Performance (N findings)
...

### Accessibility & UX (N findings)  — *web-app only*
...

### Business Logic Coverage (N findings)
...

### Data Integrity (N findings)  — *data-pipeline / infra*
...

### Reliability (N findings)  — *service / data-pipeline / cli / infra*
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
  Type: <detected type>  Lenses: <roster>
  Findings: <C critical, H high, M medium, L low>  (post-verification)
  Verified: <K Crit/High checked, V confirmed, D downgraded, X dropped>
  Verdict: <verdict>  (<type rubric>)
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

- **Detect the type first (Phase 1.5).** The detected (or `--type`-overridden) type drives BOTH the lens roster (Phase 2) and the verdict rubric (Phase 5). Do not skip detection even when the user passes inline config — still run it to confirm/echo the type. Carry the type through every downstream phase.
- **Use the Agent tool in parallel** — send a single message with multiple Agent tool uses (one per **selected** lens, one per repo). Spawn only the lenses the type's roster picked. Do NOT use Bash-spawned workers or tmux for this skill; it's an in-session multi-agent flow.
- **Subagent type:** use `Explore` for lens agents, the verification skeptics (Phase 4.5), and the synthesis agent — all read-only investigation.
- **Agent prompts** — load the full content of `agents/<name>.md` into each agent's prompt (including `agents/verify.md` for the skeptic pass). The lens prompt files are the authoritative patterns; don't paraphrase.
- **Verification is a real phase, not a vibe (Phase 4.5).** Spawn one skeptic per Critical/High (cap 12), in parallel, loading `agents/verify.md`. Apply the verdicts (keep / downgrade-confidence-one-tier / drop) BEFORE computing the Phase 5 verdict. The verdict reads post-verification findings.
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
- `agents/accessibility.md` — a11y + UX lens prompt (WCAG 2.1 AA) — *web-app only*
- `agents/biz-logic.md` — business logic + edge cases lens prompt
- `agents/data-integrity.md` — data-integrity lens prompt (numeric/stat correctness, no-fabrication, idempotency, tz/units/precision, schema/migration, no-lookahead) — *data-pipeline / infra*
- `agents/reliability.md` — reliability lens prompt (long-running error handling, retry/backoff, leaks, daemon/unit correctness, concurrency/locking, crash-recovery, observability, graceful degradation) — *service / data-pipeline / cli / infra*
- `agents/verify.md` — adversarial verification (skeptic, refute-biased) prompt — Phase 4.5, one per Critical/High finding
- `synthesis.md` — cross-cutting synthesis prompt for multi-repo audits
