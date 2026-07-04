---
name: audit
description: Comprehensive multi-dimensional app audit — detects the project type (web-app/SaaS, backend-service, data-pipeline/ETL/ML, CLI/TUI, library, infra-as-code) and adapts the lens roster (quality, security, performance, accessibility, biz-logic, data-integrity, reliability, plus an optional honesty/overclaim lens for claim-bearing repos) and verdict rubric to fit it, runs the lenses as parallel read-only agents, classifies findings by severity + confidence tier, runs an adversarial verification pass that refutes Critical/High findings before the verdict (with latent-tripwire recording), produces a type-appropriate readiness verdict gated by a report-quality checklist, and optionally auto-fixes with re-validation. Web-app/SaaS is the unchanged default (same 5 lenses + merchant/GA rubric). Use when the user says /audit, asks to audit an app/codebase, wants a GA/readiness assessment, or asks to review a full repo across multiple dimensions.
---

# /audit Skill — Multi-Dimensional App Audit

Full-codebase audit of one app OR multi-app ecosystem. Spawns parallel lens agents, each with a single sharp focus. Produces a severity-graded report, a GA readiness verdict, and an optional auto-fix + re-validate loop.

This is NOT `/qa` (which adversarially tests the running app/codebase, report-only) and NOT `/simplify` (which reviews a diff). `/audit` reviews the **full codebase** across **multiple dimensions** with **classification tiers** and **cross-cutting synthesis**.

**Sibling boundaries** (route the request; don't overlap):

| Skill | Surface |
|---|---|
| `/audit` | full codebase, multi-lens, readiness verdict |
| `/qa` | adversarial testing of the running app/codebase, report-only QA verdict |
| `/code-review`, `/simplify` | the current diff |
| `/security-review` | pending changes on the current branch |
| `/verify` | one change, exercised end-to-end |
| `/ui-test` | browser UI testing via qutebrowser |

`/audit` is a **static-code skill — no browser automation lives here.** If a runtime browser check is ever needed, defer wholesale to the `agent-browser` skill (multi-port /claim lifecycle, never Playwright MCP); never embed browser recipes in an audit.

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

## HARD RULES (NEVER / ALWAYS) — non-negotiable, read before every run

Each rule exists because of a verified failure or a house rule. The phase sections carry the mechanics; these are the lines that must never be crossed. HR numbers are referenced throughout.

**HR-1 — NEVER state the resolved model of lens/skeptic agents as fact** — not in the report header, not in stdout, not in prose. ALWAYS write the REQUESTED model plus "resolved model not observable in-session". Fable 5 carries an upstream dual-use classifier that silently reroutes source-code security-audit work to Opus BEFORE the prompt reaches the model — invisible in-session (`feedback_fable5_dualuse_reroute_gate`; the real AURA report header said "all on Fable 5" and was factually false — the fleet resolved to Opus). For security-heavy audits request Opus directly; when the resolved model matters, defer to what Christopher observes.

**HR-2 — NEVER copy a discovered secret/credential/token/private-key VALUE** into a finding, evidence snippet, report file, or stdout. This OVERRIDES the "exact code snippet" evidence requirement. Secret findings cite `file:line` + the pattern TYPE + a redacted form (first/last 2 chars max, e.g. `sk-…Q2`). The Report Gate greps the report itself for secret patterns and must come back silent.

**HR-3 — NEVER trust in-repo docs, comments, or notes for branch/push/deploy topology** ("not pushed to v2", "only on branch X", "deployed"). ALWAYS verify with read-only git and cite the git output. A topology claim without a git citation is auto-downgraded to `theoretical`. (Verified failure: AURA's `WIRING-DECISION.md` and `deployed-v2.json _note_auraINFT` both said the wiring was "NOT pushed to v2" while `HEAD == origin/v2` carried the wiring commits.)

**HR-4 — ALWAYS run the Phase-1 git ground-truth preflight** (4 read-only commands, see Phase 1) BEFORE spawning any lens, and print the result in the report header. No preflight block → no lens spawn.

**HR-5 — web-app = EXACTLY the original 5 lenses** (quality, security, performance, accessibility, biz-logic) with the unchanged merchant/GA rubric at `standard`. The honesty lens is an explicit OPTIONAL add-on (HR-6), never an implicit 6th default. This restates the Phase 1.5 backward-compat rule so it survives every future edit.

**HR-6 — ALWAYS attach the honesty/overclaim lens** (`agents/honesty.md`) when the repo carries outward-facing claim-bearing artifacts (PROOF*/pitch/submission/landing/marketing docs, or a README making ≥3 verifiable product claims) at `standard`/`deep` depth, for ANY project type. NEVER let an outward-facing overclaim that one grep can disprove go un-flagged. (This lens caught the 2 submission-blocking findings of the only real deep run.)

**HR-7 — Dependencies pass (deep): running the ecosystem's native read-only advisory tool is MANDATORY when present** (`npm audit --json` / `pnpm audit --json` / `yarn audit --json`, `pip-audit`, `cargo audit`, `osv-scanner`) IN ADDITION TO the axios denylist. Model CVE knowledge alone is NEVER sufficient — advisories postdate training (verified miss: fast-jwt 2×Critical + ws 2×High surfaced by `npm audit` after the AURA audit shipped a clean deps bill). Tool unavailable/offline → state it in Coverage & Limits.

**HR-8 — NEVER print the verdict until main has directly re-verified every Top Blockers entry itself** (open the cited file, read the cited lines). A skeptic verdict is an INPUT, not a conclusion (`feedback_verify_load_bearing_claims`). Each blocker line carries main's own citation.

**HR-9 — NEVER run an out-of-catalogue lens or emit a bespoke verdict silently.** Ad-hoc lenses go through the Custom Lens recipe (pattern checklist + required schema + severity guidance + what-NOT-to-report, declared "(custom)" in the header). Bespoke readiness verdicts MUST anchor with "(nearest-rubric equivalent: <type>/<tier>)" — exactly as the AURA report did.

**HR-10 — NEVER drop a refuted-downgraded finding that carries a tripwire** (arming condition) from the report. Tripwires are recorded under Verification even when non-blocking — the downgrade stands, the arming condition survives.

**HR-11 — ALWAYS write the report to the durable path** `~/claude/notes/audits/audit-report-<slug>-<YYYYMMDD-HHMMSS>.md` (`mkdir -p ~/claude/notes/audits` first) AND the legacy `/tmp/audit-report-<YYYYMMDD-HHMMSS>.md` copy. `/tmp` is tmpfs on this box (verified via `findmnt`) — reports there do not survive reboot. Stdout prints both paths.

**HR-12 — NEVER auto-fix a `theoretical`-confidence finding without explicit user selection, and NEVER commit fixes.** The user runs `/commit` themselves — commits go only through the commit skill (`CLAUDE_COMMIT_SKILL=1` sentinel).

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
  [1] quick     — the type's core-3 lenses (see the Phase 1.5 roster table), ~5-10 min
  [2] standard  — the type's full roster (4-5 lenses per the Phase 1.5 table), ~15-30 min  [DEFAULT]
  [3] deep      — standard roster + compliance + deps audit + migration path, ~45-90 min

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

### Git ground-truth preflight (HR-4 — blocking, before ANY lens spawn)

Run these 4 read-only commands per repo and echo the result alongside the resolved setup block. **No preflight block → no lens spawn.**

```bash
git rev-parse HEAD                                        # audited sha
git branch --show-current                                 # branch ('' = detached HEAD)
git rev-list --left-right --count @{u}...HEAD 2>/dev/null # "<behind>TAB<ahead>" vs upstream (empty = no upstream)
git status --porcelain | wc -l                            # dirty file count
```

The report header carries the result as one line:
`Ref: <sha> on <branch>, ==origin: yes/no (+<ahead>/-<behind>), dirty files: N`

Hand this block to every lens agent too — topology claims found in the repo are graded against this ground truth, never against prose (HR-3).

**Why this exists (verified failure):** in the AURA run, the repo's own notes (`WIRING-DECISION.md`, `deployed-v2.json _note_auraINFT`) claimed the wiring was "NOT pushed to v2" — false; `git rev-list` showed `HEAD == origin/v2` with the wiring commits. Ground truth comes from git, never from in-repo prose. Dirty tree or detached HEAD → failure-mode playbook (f): audit HEAD as-is, but findings touching uncommitted files are flagged `uncommitted` and cannot be `confirmed-real`. Not a git repo at all → record `Ref: not a git repo` in the header and treat EVERY topology claim as `theoretical`.

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

### Optional add-on lens — honesty/overclaim (any type, standard/deep)

`agents/honesty.md` audits the repo's outward-facing CLAIMS against code ground truth. It is NOT in any type's default roster — HR-5 keeps `web-app` byte-compatible — it attaches via this quantified trigger, or on explicit user request:

**Attach trigger (evaluate during detection):**
1. Scan repo root + `docs/` + web page sources for claim-bearing artifacts: `PROOF*`, `pitch*`, `submission*`, landing/marketing copy, a README making product claims.
2. Count externally verifiable claims (ones a hostile reader could check against the code or live app).
3. **≥3 verifiable claims OR any jury/recruiter/customer-facing framing in the invocation → the lens ATTACHES** and is listed in the report header's lenses line.
4. Below threshold → record `honesty lens not attached (no claim surface)` in Coverage & Limits.

Runs at `standard`/`deep` only (quick stays core-3). Why it earns the slot: in the only real deep run (AURA v2, 2026-07-02) an ad-hoc honesty lens found the 2 submission-blocking findings — both confirmed-real, both one-grep-disprovable overclaims on the jury-facing proof page (`references/worked-example-aura.md`).

Carry the detected (or overridden) **type** forward — Phase 2 uses it to pick the roster, Phase 5 uses it to pick the rubric.

---

## Phase 2: Per-repo parallel lens agents

For EACH repo in scope, spawn **the lenses the detected type selected** (Phase 1.5 roster) **in parallel** using the Agent tool with a single message containing multiple Agent tool uses. Do NOT spawn a lens the roster didn't pick for this type (e.g. no accessibility on a `data-pipeline`).

**Use `subagent_type: Explore`** — these are read-only investigations, no edits.

**Model resolution & reporting (HR-1):** you may REQUEST a model for the lens fleet, but you can never OBSERVE the resolved model in-session — an upstream gate can silently override the setting (Fable 5 reroutes source-code security/dual-use audit work to Opus before the prompt ever reaches the model; `feedback_fable5_dualuse_reroute_gate`). Therefore: (a) for security-heavy audits, request Opus directly — that is the smooth, un-rerouted path; (b) everywhere the report/stdout mentions models, write `requested: <model> — resolved model not observable in-session`; (c) when the resolved model matters, defer to what Christopher observes, never to the setting.

Each agent receives:
- The repo path as its root scope
- Its lens prompt (see `agents/<name>.md` files — load the full file content into the agent prompt)
- The Phase-1 git preflight block (audited sha/branch/dirty count — so topology claims are graded against ground truth, HR-3)
- The compliance framework selection
- An explicit output format requirement (structured findings array + `verified_safe` list)

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
| honesty        | `agents/honesty.md`        | OPTIONAL add-on, any type — attaches via the Phase 1.5 claim-surface trigger or explicit request | standard, deep |
| compliance     | (inline, see below)        | all types (deep only)                  | deep |
| dependencies   | (inline, see below)        | all types (deep only)                  | deep |

### Required finding schema

Every agent must return findings in this exact JSON-compatible structure. Agents that return free-form prose get rejected and re-prompted.

```yaml
- id: <slug-unique-within-agent>
  title: <short one-line title>
  dimension: quality | security | performance | accessibility | biz-logic | data-integrity | reliability | honesty | compliance | dependencies
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

**Secret-redaction override (HR-2):** for findings whose evidence IS a secret (hardcoded key/token/password/private key), the `evidence` field does NOT get the exact snippet — cite `file:line`, the pattern TYPE (e.g. "OpenAI-style API key"), and a redacted form showing at most the first/last 2 characters (`sk-…Q2`). This overrides the "exact code snippet" requirement above for secret material only. Everything else keeps the exact-snippet bar.

### Verified-safe list (required from every lens)

Alongside `findings`, every lens returns `verified_safe`: **up to 8 items it explicitly checked and found sound, each with a `file:line` citation** (e.g. `- SIWE nonce is single-use — server/auth/nonce.ts:41`). Only what was actually traced — an empty list is honest when nothing positive was verified. This is what lets a strength-asserting verdict rest on positive evidence instead of the mere absence of findings: the Report Gate FAILS a strength-asserting verdict whose gating dimensions carry zero verified-safe items. (The AURA report's per-lens verified-safe blocks were central to its "engine is genuinely strong" conclusion and the jury-confidence framing.)

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
> - **FIRST (HR-7): run the ecosystem's native read-only advisory tool when present and treat its output as ground truth** — `npm audit --json` (pnpm: `pnpm audit --json`; yarn: `yarn audit --json`), `pip-audit`, `cargo audit`, `osv-scanner`. Your CVE knowledge alone is NEVER sufficient — advisories postdate training (verified miss: 2×Critical fast-jwt + 2×High ws surfaced by `npm audit` right after the AURA audit shipped a clean deps bill). Tool unavailable / registry unreachable → say so explicitly in your output; main records it in Coverage & Limits.
> - Flag packages with known CVEs (reference CVE IDs).
> - Flag packages pinned to compromised versions (explicit denylist: axios@1.14.1, axios@0.30.4 — supply chain compromise; `feedback_axios_supply_chain`).
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
   **Conflict escalation (playbook e):** any finding — regardless of severity — that another lens listed among its `verified_safe` items ALSO enters the verify set. A flag/safe conflict must be adjudicated by a skeptic with citations, never silently resolved; whichever side loses is corrected in the report (a wrong verified-safe item is removed from the verified-safe line).
2. For each finding in the verify set, spawn a skeptic agent **in parallel** (single message, multiple Agent tool uses), `subagent_type: Explore` (read-only). Load the full content of **`agents/verify.md`** into each, plus the one finding it must refute (id, title, file:line, evidence, description, impact). One finding per agent — do not batch multiple findings into one skeptic.
3. Each skeptic returns exactly one verdict (see `agents/verify.md`): `confirmed-real`, `refuted-downgrade`, or `refuted-drop`. The skeptic **defaults to REFUTED** — if it cannot confirm the bug/exploit/corruption path end-to-end, the finding does not stand at full weight.

### Applying verdicts

- **`confirmed-real`** → keep the finding at its current severity + confidence. It blocks the verdict normally.
- **`refuted-downgrade`** → downgrade confidence ONE tier (`confirmed → probable → theoretical`). The finding stays in the report but at the lower confidence — and the Phase 5 rubric only blocks on the *post-verification* confidence (e.g. a refuted-down Critical-confirmed becomes Critical-probable and no longer trips a "≥1 Critical confirmed → Not ready" gate). A finding already at `theoretical` that's refuted-downgrade is effectively dropped from blocking (theoretical never blocks).
- **`refuted-drop`** → remove from the blocking set entirely. Keep a one-line record in the Verification subsection (title + the concrete refutation reason + the guard/constraint file:line) so the reader sees it was considered and dismissed — never silently delete.

**Latent tripwires (HR-10):** a skeptic may attach an optional `tripwire: <arming condition>` to a `refuted-downgrade` — the defect is REAL in the code but currently MASKED by another component, and a named future change arms it (see `agents/verify.md`, "Latent vs active"). The tripwire never blocks the downgrade and never blocks the verdict — the 3-verdict vocabulary and the refute bias are unchanged — but the finding + arming condition MUST survive in the report even though non-blocking. (AURA: the AuraINFT split-brain findings were correctly downgraded High→Medium — the shipped web UI masked them — and their prod-cutover tripwire became THE durable finding of the entire audit.)

### Recording

Add a **"Verification" subsection** to the report (under the Verdict). For every verified finding, show: id, title, original severity/confidence, verdict, post-verdict severity/confidence, and the one-line refutation/confirmation reason with its citation. This makes the verdict auditable: a reader can see exactly which loud findings survived the skeptic and which were downgraded or dismissed, and why.

Add a **"Tripwires" sub-list** under Verification: every downgraded finding that carries an arming condition, with (a) the condition that arms it and (b) what must move together when it arms. Tripwires are recorded even when non-blocking (HR-10) — they are the findings that detonate at the next migration/cutover if forgotten.

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

**Main re-verification of blockers (HR-8 — blocking):** before printing the verdict, main itself opens every Top Blockers entry's cited file and reads the cited lines. A skeptic is a delegate; its verdict is an input, not a conclusion (`feedback_verify_load_bearing_claims`). Each blocker line in the report carries main's OWN citation (what main saw at file:line), not just the lens/skeptic's claim. A blocker main could not re-verify does not appear as a blocker — it goes back through Phase 4.5 or drops to the ordinary findings list. Keep every claim as narrow as its evidence ("quota not refunded on failed generation", never "billing is broken").

**Justification:** 2-3 sentences explaining the verdict, referencing the blockers by finding number AND naming the rubric used (e.g. "under the data-pipeline / trustworthy-for-downstream rubric"), with the post-verification counts stated next to the rubric row satisfied.

---

## Custom lenses & rubric overlays (the sanctioned escape hatch)

Some repos don't fit the 6-type taxonomy — the only real deep run (AURA) was a Solidity/Foundry + Fastify + Ponder + Next.js + Bun-CLI monorepo. Do NOT force-fit `web-app`; do NOT drift unbounded either. Two recipes, both gated by HR-9:

### Custom Lens recipe (ad-hoc lens, e.g. contract-correctness)

An ad-hoc lens prompt is VALID only if it contains all 4 mandatory parts — the same anatomy every `agents/*.md` file has:

1. **Concrete pattern checklist** — specific, checkable patterns for its dimension (not "find issues with the contracts").
2. **The required finding schema** with a declared `dimension:` value (plus the `verified_safe` list).
3. **Severity guidance** — what Critical/High/Medium/Low mean IN this dimension.
4. **What NOT to report** — the negative space that keeps it from flooding.

Missing any part → do not spawn; write the missing part first. The report header marks every such lens `(custom)` — e.g. `Lenses run: quality, security, contract-correctness (custom), …`. Custom-lens Critical/High findings go through Phase 4.5 like everything else.

### Custom Rubric Overlay (bespoke readiness question)

When the user's real question isn't a standard tier ("is this ready to SUBMIT to the jury?"), answer it — anchored:

- State it as: **`Overlay verdict: <X> — (nearest-rubric equivalent: <type>/<tier>)`**.
- The equivalent tier is COMPUTED from the standard rubric tables against the post-verification counts, with the counts shown next to the rubric row satisfied. The overlay can never float free of the quantified gates.
- Worked anchor: AURA's `READY TO SUBMIT — CONDITIONAL ON THE HONESTY FIXES (Merchant-rubric equivalent: Pilot-ready — 0 Critical confirmed, 0 Critical probable, 8 High confirmed/probable)`. See `references/worked-example-aura.md`.

### Custom project type

If detection lands outside all 6 types: name the composite honestly in the header (e.g. `multi-subsystem web3 monorepo`), assemble the roster from the catalogue per-subsystem (contracts → security + a custom contract-correctness lens; server → backend-service roster; web → web-app roster), and pick the nearest standard rubric as the overlay anchor. NEVER invent a 7th rubric table.

---

## Phase 6: Report output

### Report Gate (blocking checklist — runs after Phase 5, before ANYTHING is written or printed)

Every box checks, or you fix the report first. Any unchecked box → the report is NOT emitted.

- [ ] **Verification coverage** — every Critical/High has a Verification row OR an explicit `unverified (capped at 12)` flag.
- [ ] **Citations** — every finding cites `file:line`.
- [ ] **Verdict math shown** — the verdict states its post-verification counts next to the rubric row satisfied (e.g. "0 Crit confirmed, 0 Crit probable, 4 High confirmed ≤ 5 → Closed-beta-ready").
- [ ] **Model wording (HR-1)** — requested-vs-resolved wording present; no resolved-model assertion anywhere in the report or stdout.
- [ ] **Secret grep silent (HR-2)** — `grep -nE 'sk-[A-Za-z0-9]{8}|AKIA[A-Z0-9]{8}|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{8}|xox[baprs]-' <report-file>` returns nothing (exit 1). A hit = a secret leaked into the report → redact per HR-2 and re-run the grep.
- [ ] **Coverage & Limits present** — lenses not run (and why), honesty lens attached-or-not, dirs/shards skipped, verification cap hit or not, advisory tools unavailable (HR-7), anything the audit could NOT verify.
- [ ] **Blockers re-verified (HR-8)** — each Top Blocker carries main's direct re-verification citation.
- [ ] **Verified-safe backing** — a strength-asserting verdict (GA-ready / Production-SLO-ready / Trustworthy-for-downstream / Decision-grade / Team-ready+ / API-stable+ / Apply-to-staging+ tiers) has ≥1 verified-safe item in each of its gating dimensions. Zero positive evidence + a strong verdict = an assertion, not an audit → gate fails.

### Writing the report (HR-11 — durable primary + legacy copy)

Write the full report to the DURABLE path `~/claude/notes/audits/audit-report-<slug>-<YYYYMMDD-HHMMSS>.md` (`mkdir -p ~/claude/notes/audits` first; `<slug>` = repo name) AND copy it byte-identical to the legacy path `/tmp/audit-report-<YYYYMMDD-HHMMSS>.md` — /tmp is tmpfs and vanishes on reboot; the durable file is the artifact memories cite. Follow this exact structure:

```markdown
# Audit Report — {{app or ecosystem name}}

- **Generated:** {{ISO date}}
- **Scope:** {{repo paths}}
- **Ref:** {{sha}} on {{branch}}, ==origin: {{yes/no (+A/-B)}}, dirty files: {{N}}   ← Phase-1 git preflight (HR-4)
- **Project type:** {{detected type}}  ({{auto-detected | --type override | custom composite}})
- **Depth:** {{quick|standard|deep}}
- **Lenses run:** {{the type's roster, e.g. data-integrity, reliability, security, quality, performance}} {{+ honesty if attached; mark ad-hoc lenses "(custom)"}}
- **Model:** requested {{model}} — resolved model not observable in-session (HR-1)
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

1. [#{{id}}] {{title}} — {{one-line why it blocks}} — *re-verified by main: {{what main saw at file:line}}* (HR-8)
2. ...

### Verification  (Phase 4.5 — Critical/High only)

{{For each verified finding: id, title, original sev/conf → verdict → post-verdict sev/conf, with the one-line refutation/confirmation reason + citation. Note if verification was capped at 12.}}

| # | Finding | Orig | Verdict | Result | Why |
|---|---------|------|---------|--------|-----|
| {{id}} | {{title}} | {{Crit/confirmed}} | {{confirmed-real / refuted-downgrade / refuted-drop}} | {{Crit/probable / dropped}} | {{guard at file:line / traced exploit / intended}} |

**Tripwires** (downgraded-but-armed — HR-10, present whenever any downgrade carried an arming condition):
- [#{{id}}] {{title}} — arms when: {{the concrete change that makes it fire}}; must move together: {{what has to change atomically when it arms}}

## Findings by Dimension

{{Include ONLY the dimensions the detected type's roster actually ran — omit lenses that didn't run for this type. E.g. a data-pipeline report has Data Integrity + Reliability and NO Accessibility section.}}

{{Open EACH dimension section with one line from that lens's verified_safe list — omit the line only when the list is empty:}}
**Verified safe:** {{item — file:line}}; {{item — file:line}}; ...

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

### Honesty / Overclaims (N findings)  — *only when the honesty lens attached (Phase 1.5 trigger)*
...

### Compliance — {{framework}} (N findings)
...

### Dependencies (N findings, deep only)
...

## Cross-Cutting Issues (multi-repo only)
{{synthesis findings}}

## Coverage & Limits

{{The honest scope statement — REQUIRED (Report Gate): lenses not run and why; honesty lens attached or "not attached (no claim surface)"; dirs/shards skipped; verification cap hit (which findings are flagged unverified); native advisory tool availability for the deps pass (HR-7); anything the audit could NOT verify (runtime behavior, infra state, uncommitted files).}}

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
  Report (durable): ~/claude/notes/audits/audit-report-<slug>-<ts>.md
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
  2. Run the repo's build command (detected from manifests — fallback table below).
  3. Run the repo's test command if present.
  4. Record: applied, built, tested, status (success / build-failure / test-failure).
- If build or tests fail, revert the edit and mark the finding as `fix-attempt-failed`.
- Batch edits per file where possible to reduce build runs, but isolate edits for different findings so one failure doesn't taint another.

Manifest → build/test fallback (self-contained; the `/qa` skill's fuller detection table is advisory only — do not depend on it):

| Manifest | Build | Test |
|---|---|---|
| `package.json` | `npm run build` | `npm test` |
| `Cargo.toml` | `cargo build` | `cargo test` |
| `pyproject.toml` | `python -m build` | `python -m pytest` |
| `go.mod` | `go build ./...` | `go test ./...` |
| `Makefile` | `make` | `make test` |

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

## Failure-mode playbooks (exact recovery — no improvisation)

**(a) Lens returns free-form prose instead of the schema** → reject + re-prompt ONCE with the required schema block inlined verbatim in the re-prompt. Second failure → proceed without that lens and name it in Coverage & Limits (`<lens> excluded: schema non-compliance ×2`). Never hand-parse prose into findings — mis-parsed severity/confidence poisons the verdict math.

**(b) Lens exceeds the 10-min timeout** → proceed with partial findings from the others (existing rule) + a Coverage & Limits entry naming the missing lens. Do not block the run on one straggler.

**(c) API 529/overloaded mid-fleet** (verified during the AURA remediation night) → re-spawn ONLY the failed lens with the exact same prompt. NEVER restart the whole fleet — completed lens results are valid inputs; re-running them wastes the run and can shuffle finding ids mid-aggregation.

**(d) Repo over 2000 files / 300k LOC** → the Phase-1 warning fires (existing). If the user proceeds at full scope, SHARD: split by top-level directory, run one lens pass per shard, merge findings in Phase 4 (dedup catches cross-shard duplicates); record the shard map in Coverage & Limits. Never silently sub-sample.

**(e) Lens A flags what lens B lists as verified-safe** → the conflict auto-enters the Phase 4.5 skeptic queue regardless of severity. The skeptic adjudicates with citations; the losing side is corrected in the report (a wrong verified-safe item is REMOVED from the verified-safe line, or the finding is refuted).

**(f) Preflight finds a dirty tree or detached HEAD** → audit HEAD as-is (the audit is read-only — never stash, never checkout). Every finding touching an uncommitted file is flagged `uncommitted` and CANNOT be `confirmed-real` (the code may change before anyone acts on it). The header records the dirty count; Coverage & Limits names the affected findings.

---

## House profile — Aenoxa-owned repos ONLY (opt-in overlay)

When the audited repo is Aenoxa-owned (Pulse, `aenoxa_*` — say so explicitly in the setup block), the accessibility lens additionally applies the house-profile block at the end of `agents/accessibility.md`:

- **Typography floors:** flag `font-weight < 500` and `font-size < 12px` as house-floor violations (`feedback_ui_typography_floors` — size floor recalibrated 16px → 12px on 2026-07-01; body copy 16px+).
- **i18n + multi-theme gate BY CITATION:** run the global CLAUDE.md "Website Build Defaults" verification gate (next-intl `id`/`en` + next-themes light/dark/system) — cite that gate, never duplicate it here.
- **Exemption:** oneshot-webapp pitch demos are deliberately light-only with no next-themes — do not flag them.

NEVER apply this overlay to client repos (BCAS / ISI — Christopher is a QA contractor there, `feedback_qa_scope_discipline`; house design floors do not apply). Client repos get pure WCAG.

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
- **If the user has an existing `AUDIT.md`, a report in `~/claude/notes/audits/`, or `/tmp/audit-report-*.md`** from a previous run, offer to diff against it and highlight only new/resolved findings. Look in the durable dir FIRST — /tmp is wiped on reboot (HR-11).
- **Evaluate the honesty attach trigger during detection** (Phase 1.5) — attach or record "not attached (no claim surface)"; never skip the evaluation silently.
- **Run the Report Gate before emitting anything** (Phase 6) — it is blocking, not advisory.
- **Do NOT run the repo's dev server, migrations, or any destructive command** during audit. Build + test only, and only in Phase 7.
- **Do NOT commit fixes.** The user runs `/commit` themselves when satisfied (HR-12).

---

## Invocation check

When Christopher types `/audit` with no args, default to `cwd`. If cwd is `/home/christopher/claude` (the command-center discussion space), refuse with:

> /audit is a codebase skill and should not be run on the command-center directory. Either `cd` into a real repo or pass the repo path: `/audit <path>`.

---

## Files in this skill

- `SKILL.md` — this file
- `agents/quality.md` — code quality lens prompt
- `agents/security.md` — security lens prompt (OWASP Top 10; carries the secret-redaction hard rule)
- `agents/performance.md` — performance lens prompt
- `agents/accessibility.md` — a11y + UX lens prompt (WCAG 2.1 AA; optional Aenoxa house-profile block) — *web-app only*
- `agents/biz-logic.md` — business logic + edge cases lens prompt
- `agents/data-integrity.md` — data-integrity lens prompt (numeric/stat correctness, no-fabrication, idempotency, tz/units/precision, schema/migration, no-lookahead) — *data-pipeline / infra*
- `agents/reliability.md` — reliability lens prompt (long-running error handling, retry/backoff, leaks, daemon/unit correctness, concurrency/locking, crash-recovery, observability, graceful degradation) — *service / data-pipeline / cli / infra*
- `agents/honesty.md` — honesty/overclaim lens prompt (claims inventory vs code ground truth, one-grep-disproof test) — *optional add-on, any type, via the Phase 1.5 claim-surface trigger*
- `agents/verify.md` — adversarial verification (skeptic, refute-biased) prompt with the optional latent-tripwire annotation — Phase 4.5, one per Critical/High finding
- `synthesis.md` — cross-cutting synthesis prompt for multi-repo audits
- `references/worked-example-aura.md` — the AURA v2 worked case (custom type + rubric overlay, honesty catches, correct downgrades + tripwire, advisory-tool miss, model-reroute header lesson) — loaded by MAIN only, never into lens subagents
