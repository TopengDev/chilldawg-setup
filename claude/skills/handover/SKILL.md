---
name: handover
description: Generate a client-delivery handover package for an Aenoxa software-house project by analyzing the ACTUAL codebase (architecture, API, deployment, credentials map, maintenance, user guide) plus a bilingual signable BAST rendered to PDF. Evidence-gated so it never fabricates, secret-safe so it never reads real .env values, dash-clean. Use when Christopher says /handover, or hands a finished project to a client.
argument-hint: "[client or project name] [--pdf-summary] [--docx]"
allowed-tools: Bash, Read, Glob, Grep, Write, Agent, TaskCreate, TaskUpdate
---

# /handover: evidence-gated client delivery package + signable BAST

Turn a finished project into the **document package a client signs off on and a maintainer can actually run the system from**: an accurate architecture doc, real API reference, a deployment guide that matches how the app truly ships, a credentials MAP (where each secret lives, never the secret itself), a maintenance guide, a user guide, and the highest-stakes artifact, a **bilingual BAST (Berita Acara Serah Terima) rendered to a signable PDF**. This is the terminal deliverable of the Aenoxa software-house lifecycle (`project_software_house` Phase 4): deploy to production, hand over the doc package plus recorded training, then the BAST is signed, which **triggers the final 30% payment and starts the warranty**. An unsignable or fabricated handover blocks the money and burns the client relationship.

This skill exists to kill four failure modes the previous version allowed:

1. **A markdown-only BAST.** A BAST is a formal Indonesian legal document needing wet signatures, positions, a company stamp, and materai. A client cannot sign a `.md`. It MUST be a PDF (the same verified Chrome-headless pipeline `/proposal` and `/invoice` already use).
2. **Secret leaks.** The old skill read real `.env.production` value files into context, one paraphrase away from a live API key landing in a client-facing `credentials.md`. This skill NEVER reads a real value file and mechanically scans every output for secret shapes.
3. **Fabricated facts.** An invented endpoint, DB column, or integration is a delivery defect the client finds in production. Every documented fact traces to a source file that was read, or it is tagged `[unverified]` or omitted.
4. **AI-slop tells on a permanent client document.** An em dash in a signed BAST is a hard house-rule violation on a document the client keeps forever. A blocking grep gate stops it.

The spine, in one line: **analyze the ACTUAL codebase, document only what the evidence proves, keep secrets as WHERE-not-WHAT, render the BAST to a verified PDF, run the grep gates, and report as tables.**

The pipeline this skill closes:

```
/proposal (scope + SOW)  ->  [signed]  ->  /invoice (30/40/30)  ->  /status-report (weekly)
   ->  /handover  (THIS: prod deploy doc package + BAST)  ->  [BAST signed]
   ->  /invoice   (final 30% milestone)  ->  warranty begins
```

===============================================================================
## 0. PRIME META-RULES (mechanical, OVERRIDE EVERYTHING BELOW)
===============================================================================

These are grep-verifiable and boolean on purpose, so context pressure can never erode them. They run against **every persistent file this skill produces** (all 8 documents + the README index under `docs/handover/`). The BAST PDF's text comes from `bast.md` (scanned) rendered through the dash-clean HTML template, so scanning `bast.md` covers the PDF; if you hand-author content directly into the BAST HTML, scan that HTML before rendering (section 3). The mirror is `/proposal` section 0 and `/case-study` section 0.

### 0.1 No em dash or en dash, ANYWHERE (PRIME RULE)

**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY file this skill produces**, nor in the BAST, nor in the chat report, nor in this skill's own prose. This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02: never long dashes in ANY outgoing text). A signed BAST and a client credentials map are documents the client keeps permanently, the single worst surface to leak the loudest "AI wrote this" tell.

- **Use instead:** a comma, a colon, parentheses, or a line break for clause breaks; the word "to" or a plain hyphen for ranges (write "30 to 60 days" or "30-60", never the en-dash form).
- **Plain hyphen-minus stays allowed** for compounds and ranges (real-time, multi-tenant, offline-first, 24hr, 30-day). ONLY the two long dashes are banned.
- **Scrub with meaning intact.** A heading shaped "Warranty (em dash) 30 days" becomes "Warranty: 30 days" or "Warranty, 30 days". Never mechanically delete a dash and leave broken grammar.

### 0.2 No secret VALUES, ever (the WHERE-not-WHAT firewall)

Two rules, both hard:

**(a) NEVER read a real secret-bearing value file into context.** BANNED to read: `.env`, `.env.local`, `.env.development`, `.env.production`, `.env.*.local`, `~/.claude/secrets.env`, or ANY file that holds resolved live values. Reading one pulls a live key into context, one paraphrase from the delivered doc. **Enumerate the required variable NAMES ONLY from** `.env.example` / `.env.sample` / `.env.template` **plus a code-usage grep** (`process.env.X`, `os.environ`, `os.Getenv`, `env::var`, `Config::get`), which yields NAMES, never values. If a repo has NO example file, derive the variable list from the code grep alone and note that no example file existed. (This supersedes the old "read `.env.production` if not gitignored" instruction, which was the leak.)

**(b) NEVER print or write a secret VALUE** into any generated document or into chat. `credentials.md` lists WHERE a secret is stored and WHICH variable or where to obtain it, never the value.

| DO (WHERE + which var) | DON'T (the value) |
|---|---|
| `STRIPE_SECRET_KEY, set in the deployment platform env, obtain from Stripe Dashboard > Developers > API keys` | pasting the live secret key value |
| `DATABASE_URL, stored in the server .env (chmod 600), format postgres://USER:PASSWORD@HOST/DB` | the resolved connection string with the real password |
| `JWT_SECRET, generated per environment, rotate via the deploy runbook` | the actual signing secret |

If you ever find a captured secret in a data file while analyzing, report the file path plus the pattern TYPE only, never the value. The scan in 0.5 (V2) enforces this on every output.

### 0.3 No fabrication (the evidence floor)

**NEVER document an API endpoint, DB table or column, env var, integration, deploy path, or feature you did not read in a real source file.** The value of a handover is that it is TRUE. Every documented route group, table, and integration must trace to the file it was read from. If a fact cannot be sourced, it becomes `[unverified]` inline with an honest note, or it is omitted, NEVER invented to fill a section. Accuracy over completeness: an honest gap ("no rate-limiting middleware was found in the code") beats a fabricated feature. The evidence floor is gated in section 1 (analysis must be complete before any Write) and re-checked by the section 4 sample-verify pass.

### 0.4 BAST identity comes from the shared config (NEVER hardcode)

The BAST Pihak Pertama (Developer party) identity, company name, address, phone, email, NPWP, comes from the **shared invoice config** `~/.claude/invoices/config.json` (verified present; keys `company.{name,address,phone,email,website,npwp}`, `bank.{...}`, `defaults.{currency,tax_rate,tax_name,payment_terms_days,language,...}`). Read the keys, **never print the raw config values into chat**, never hardcode a company name into the template. Commercial and legal terms (warranty length, SLA, IP clause) are CEO Suryadi's remit (`project_software_house`): the BAST pre-fills the house DEFAULT terms as SUGGESTED values marked for confirmation, it does not invent final contract language (mirror `/proposal` rule 5).

### 0.5 VERIFICATION BLOCK (exact commands, ALL must pass before delivery)

Scan every persistent file this run produced under `docs/handover/` (the 8 `.md` + `README.md`, plus any `.html` that lives there). Run all of it. Any line a MUST-BE-SILENT check prints on **stdout** means NOT done; fix with meaning intact and re-run until each prints nothing.

```bash
DIR="docs/handover"

# SHELL-AGNOSTIC scan form (REQUIRED, do not "simplify" it back). Scope each scan to the
# directory with `-r` + `--include`; NEVER collect a file list into a variable and pass it
# unquoted. The old `FILES=$(find ...)` + `grep ... $FILES` FALSE-PASSES in the runtime
# shell (zsh 5.9.1, verified: $0=/usr/bin/zsh, BASH_VERSION unset): zsh does NOT word-split
# an unquoted multiline expansion, so grep receives ONE multi-line non-existent filename,
# exits rc=2 with EMPTY stdout (the error goes to stderr), and empty stdout reads as CLEAN,
# so a real em dash or a leaked secret sails through. The directory-scan form below was
# verified on this box 2026-07-03 (grep is ugrep 7.5.0) to catch a planted em dash and a
# planted sk- token: rc=0 with the offending line on stdout. Keep `"$DIR"` quoted.

# V1  em / en dash (MUST be silent) - PRIME rule 0.1. PCRE unicode form (verified on this box).
grep -rnP  --include='*.md' --include='*.html' "[\x{2013}\x{2014}]" "$DIR"

# V2a TRUE-SECRET shapes (MUST be silent, HARD) - rule 0.2b. Any hit = a leaked value.
grep -rnP  --include='*.md' --include='*.html' 'sk-[A-Za-z0-9]{16}|sk_live_|ghp_[A-Za-z0-9]|xox[baprs]-|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|eyJ[A-Za-z0-9_-]{20,}\.' "$DIR"

# V2b connection-string / password shape (REVIEW TRIGGER, manual disambiguation) - rule 0.2b.
grep -rnP  --include='*.md' --include='*.html' '[a-z][a-z0-9+.]+://[^:@/\s]+:[^@/\s]+@|password\s*[:=]\s*\S' "$DIR"

# V3  internal absolute paths on client-facing docs (MUST be silent) - the "authored on my laptop" tell.
grep -rn   --include='*.md' --include='*.html' '/home/christopher\|/Users/\|/root/' "$DIR"

# V4  leftover template placeholders that are NOT sanctioned (MUST be silent).
# All-caps/underscore brace tokens (PROJECT_NAME, NOMOR, SOW_NO, YEAR ...) + the {from ...} guidance forms.
# Tuned to avoid Mermaid rhombus nodes (title-case {Decision}) which legitimately appear in architecture.md.
grep -rnE  --include='*.md' --include='*.html' '\{[A-Z_]{4,}\}|\{from |\{path\}|\{TODO\}|placeholder' "$DIR"

# BAST render HTML: the template flow renders bast.md -> a transient HTML in /tmp (section 3),
# which this directory scan does NOT reach. bast.md (the render SOURCE) IS covered above, and
# scanning bast.md covers the PDF text. ONLY if you hand-author content directly into that HTML,
# scan it too BEFORE rendering, as an explicit file arg (searched regardless of --include):
#   for pat in "[\x{2013}\x{2014}]" 'sk-[A-Za-z0-9]{16}|sk_live_|ghp_[A-Za-z0-9]'; do grep -nP "$pat" "$HTML"; done
```

Notes:
- **V2b is a manual-disambiguation trigger, not an auto-fail.** The sanctioned WHERE-not-WHAT placeholder `postgres://USER:PASSWORD@HOST/DB` legitimately matches (uppercase placeholder tokens), and so does a real leaked connection string. On any V2b hit, EYEBALL the line: if the credential portion is a placeholder (`USER:PASSWORD`, `<user>:<pass>`, `xxx`, `YOUR_PASSWORD`), it passes; if it is a real value, replace it with the placeholder form and re-scan. `password` used as a documented VARIABLE NAME (`DB_PASSWORD, stored in ...`) passes; `password=hunter2` fails.
- **V4 sanctioned survivors:** `[unverified]` (rule 0.3), `[TO CONFIRM: Suryadi]` on commercial terms (0.4), and the blank underscore fill-lines in the BAST signature block (`_______`) are legitimate. A leftover `{PROJECT_NAME}` or `{from package.json}` is the "still a template" tell and fails.
- These checks are wired into the DELIVERY GATE and the EXECUTION FLOW. They are boolean and mechanical precisely so a nice-looking package can never average away a mechanical failure.

===============================================================================
## NON-NEGOTIABLE RULES (semantic hard rules, READ BEFORE ANALYZING)
===============================================================================

Violating any one is a failed handover, not a stylistic choice.

1. **ANALYZE THE REAL CODEBASE FIRST, NEVER TEMPLATE A FACT.** The section 1 analysis pass runs to completion BEFORE a single document is written (the evidence floor, rule 0.3). Every endpoint, table, env var, integration, and deploy path is read from a file. Do not write architecture.md from the project's name or a plausible guess.

2. **THE BAST IS A SIGNABLE PDF, NEVER MARKDOWN-ONLY.** The BAST markdown is the render source; the deliverable is the PDF (section 3). A markdown BAST cannot carry a wet signature, a stamp, or materai, so it is not a real handover certificate. `test -s` plus `pdfinfo` page-count must both pass before you claim the PDF exists (section 3, G3).

3. **CREDENTIALS ARE WHERE-NOT-WHAT (rule 0.2).** `credentials.md` and the env sections of `deployment.md` list storage location plus variable name plus where-to-obtain, never a resolved value. Never read a real value file to build them.

4. **NO FABRICATION (rule 0.3).** Unverifiable is `[unverified]` or omitted with an honest note. Never invent to fill a section. "Rate limiting: no rate-limiting middleware found in the code" is a correct, honest line.

5. **NEVER USE pandoc OR md-to-pdf FOR DIRECT PDF.** No LaTeX engine is installed on this box (`pdflatex`/`xelatex`/`tectonic`/`typst` all ABSENT, verified). `pandoc file.md -o file.pdf` FAILS. Chrome-headless HTML to PDF is the ONLY PDF route (section 3); pandoc is for the client-editable `.docx` copy only.

6. **NEVER DRIVE A BROWSER FROM THIS SKILL.** If `user-guide.md` needs UI screenshots, that is a SEPARATE, Christopher-gated task deferred to the `/agent-browser` skill (multi-port `/claim` lifecycle, never kill Christopher's live browser, qb-shoot fallback, DPR trim). NEVER bolt Playwright MCP or any other browser stack. This skill produces documents; it navigates nothing.

7. **GENERATOR, NEVER SENDER OR DEPLOYER.** This skill writes files for Christopher to review and deliver. It NEVER emails or WhatsApps the client, NEVER SSHes to the VPS, NEVER deploys, NEVER commits (commits go through `/commit`, `CLAUDE_COMMIT_SKILL=1`). It analyzes a codebase read-only and writes into `docs/handover/`.

8. **BILINGUAL BAST WITH CORRECT INDONESIAN CONVENTIONS.** Indonesian primary, English secondary, with the real conventions (Nomor, Para Pihak, Daftar Deliverables, Masa Garansi, Tanda Tangan, materai/stamp, rangkap-2 legal-force clause). Full template and conventions: `references/bast-guide.md`.

> If Christopher asks for something that breaks these (for example "just PDF the whole package" when architecture.md has Mermaid diagrams that only render in markdown, or "read the prod .env to fill credentials"), do NOT silently comply. Flag it: the diagram docs stay markdown so the Mermaid renders (section 3), and credentials come from the example file plus code grep, never the real value file (rule 0.2).

===============================================================================
## THE SIX GATES (G1 to G6) and where each is enforced
===============================================================================

The reviewer's gate model, mapped to the section that owns each. No gate is prose-only.

| Gate | What it enforces | Enforced in |
|---|---|---|
| **G1 Evidence floor** | Analysis complete + every documented fact traces to a read file, before any Write | Section 1 (checklist) |
| **G2 Grep battery** | Dash-silent, secret-silent, path-silent, placeholder-silent on every file | Section 0.5 (V1 to V4) |
| **G3 PDF verify** | BAST PDF: `chrome_exit==0` AND `test -s` AND `pdfinfo` pages >= 1 | Section 3 |
| **G4 Completeness** | Every expected file exists + non-empty; reported count == on-disk count | DELIVERY GATE + section 4 |
| **G5 Format decision** | Each output tagged audience x format; diagram docs stay md, BAST is PDF | Section 2 (decision table) |
| **G6 Delivery checklist** | The boolean roll-up below, all boxes ticked | DELIVERY GATE |

===============================================================================
## DELIVERY GATE (G6, satisfy ALL before reporting the handover done)
===============================================================================

- [ ] **Evidence floor met** (G1): the section 1 analysis ran on the real codebase; every documented route group / table / integration / deploy path cites the source file it came from. Nothing templated.
- [ ] **All 8 documents + README exist and are non-empty** (G4): `test -s` passes on each of the 9 files; the report's file count equals the on-disk count.
- [ ] **BAST PDF produced and verified** (G3): `chrome_exit==0`, `test -s "$PDF"`, `pdfinfo` pages >= 1 (qpdf fallback). Never claim a PDF that fails all three.
- [ ] **credentials.md is WHERE-not-WHAT** (rule 0.2): no resolved secret values; every entry names a storage location + variable + where-to-obtain.
- [ ] **BAST identity from config** (rule 0.4): Pihak Pertama read from `~/.claude/invoices/config.json` keys, not hardcoded; commercial terms carry the `[TO CONFIRM: Suryadi]` marker.
- [ ] **VERIFICATION BLOCK (0.5) V1 to V4 all pass** on every produced file (V2b hits manually disambiguated to placeholder-only).
- [ ] **Format decision respected** (G5): diagram-bearing dev docs are markdown; the BAST is a PDF; the summary PDF only if `--pdf-summary`.
- [ ] **Boundaries respected** (section 4): nothing sent, nothing deployed, no browser driven, no commit.
- [ ] **Report delivered as tables** (section 6): files-landed, gates pass/fail, open items, and the `/invoice` handoff command.

If any box fails, the handover is NOT done. Fix before reporting complete.

===============================================================================
## 1. CODEBASE ANALYSIS DISCIPLINE (G1, do this FIRST, this is the core competence)
===============================================================================

**No document is written until this pass is complete and the evidence floor holds.** Use the `Agent` tool with `subagent_type=Explore` to gather different aspects in parallel where it speeds things up (this is the valid read-only parallel-analysis pattern). Track progress with `TaskCreate` (an internal aid; this skill does not spawn pipeline workers or need triage.json machinery, it is a self-contained in-session generator like `/proposal` and `/invoice`). Capture the source file behind each finding as you go: those citations are what section 4 samples back.

**Evidence floor (boolean, must hold before the first Write):**
- [ ] Stack + framework detected from a real lockfile / manifest (1a).
- [ ] Every documented API route group traces to a route file you read (1c).
- [ ] Every documented DB table traces to a schema / model file you read (1d).
- [ ] Env var list derived from `.env.example` + code grep NAMES only, no value file read (1e).
- [ ] Deploy path traces to a real infra signal (Dockerfile / compose / CI / nginx), not assumed (1f).

### 1a. Project identity and stack

Read whichever exist (these are safe, non-secret): `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`; `pyproject.toml`, `requirements.txt`, `Pipfile`; `go.mod`, `go.sum`; `Cargo.toml`; `composer.json`; `Gemfile`; `README.md`, `CLAUDE.md`; `docker-compose.y*ml`, `Dockerfile`; `.github/workflows/*.yml`; `Makefile`, `justfile`, `Taskfile.yml`.

Extract: project name and description, language(s) and framework(s) with versions (versions are evidence), production + dev dependencies, available scripts, runtime version requirements (engines, `.nvmrc`, `.python-version`).

**Client / project name resolution:** if `$ARGUMENTS` names the client or project, use it. Else infer the project name from `package.json` `name`, `pyproject.toml`, `go.mod`, `Cargo.toml`, the `README.md` title, or the directory name. The CLIENT name, if not in `$ARGUMENTS`, is `[TO CONFIRM]` in the docs and the BAST, never invented.

### 1b. Architecture and structure

```bash
find . -type f \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' \
  -not -path '*/__pycache__/*' -not -path '*/.next/*' -not -path '*/dist/*' \
  -not -path '*/build/*' -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/.turbo/*' \
  | head -500
```

Identify: monorepo vs single project, source directories and their purpose, frontend / backend / shared boundaries, ORM models or migration dirs, config files and their roles.

### 1c. API routes (detect by framework, read each route file fully)

Run the matcher for the framework you detected in 1a. **Read each matched file fully** to extract method, path, middleware, handler, and request/response shape. Cite the file behind each documented route group.

| Framework | Detection command |
|---|---|
| Express / Fastify / Hono (Node) | `grep -rnE "(router\|app)\.(get\|post\|put\|patch\|delete)\(" --include='*.ts' --include='*.js' .` |
| Next.js App Router | `find . -path '*/app/**/route.*' \( -name 'route.ts' -o -name 'route.js' \)` |
| Next.js Pages Router | `find . -path '*/pages/api/*' \( -name '*.ts' -o -name '*.js' \)` |
| Django | `find . -name urls.py -not -path '*/site-packages/*'` then read each `urlpatterns` |
| FastAPI / Flask | `grep -rnE "@(app\|router)\.(get\|post\|put\|patch\|delete)\(" --include='*.py' .` |
| Go (net/http, Gin, Chi, Echo) | `grep -rnE "HandleFunc\|\.(GET\|POST\|PUT\|DELETE)\(\|r\.(Route\|Get\|Post\|Method)" --include='*.go' .` |
| Laravel | `grep -rnE "Route::(get\|post\|put\|patch\|delete\|resource\|apiResource)" --include='*.php' routes/` |

> **The App Router matcher is parenthesized on purpose (verified fix).** The old form `find . -path "*/app/api/*" -name "route.ts" -o -name "route.js"` has an operator-precedence bug: the unparenthesized `-o` binds `-path` to only the first `-name`, so `-name "route.js"` matches EVERY `route.js` in the whole tree (verified: it pulled in a `lib/route.js` outside `app/api`), polluting the endpoint inventory. Always wrap the alternation: `\( -name 'route.ts' -o -name 'route.js' \)`.

### 1d. Database schema (detect by ORM, read each schema/model file)

Read the schema fully to extract table names, columns + types, relationships, indexes, constraints. Cite the schema file behind each documented table.

| ORM / tool | Where to look |
|---|---|
| Prisma | `prisma/schema.prisma` |
| Drizzle | files with `pgTable` / `mysqlTable` / `sqliteTable` (`grep -rl` them), `*.schema.ts` |
| TypeORM / MikroORM | files with `@Entity(` |
| Sequelize | files with `.init(` or `sequelize.define(` |
| Django | `models.py` files |
| SQLAlchemy | files with `Column(` or a declarative `Base` subclass |
| Raw SQL migrations | `migrations/`, `db/migrate/`, `alembic/versions/` |
| Knex | `migrations/`, `knexfile.*` |

### 1e. Environment variables (NAMES ONLY, never read a real value file, rule 0.2)

```bash
# Required-var NAMES from the EXAMPLE file only (safe, non-secret):
cat .env.example .env.sample .env.template .env.local.example 2>/dev/null

# Cross-check against actual code usage (yields NAMES, never values):
grep -rhoE "process\.env\.[A-Z0-9_]+|os\.environ(\.get)?\(['\"][A-Z0-9_]+|os\.Getenv\(['\"][A-Z0-9_]+|env::var\(['\"][A-Z0-9_]+|Config::get\(['\"][A-Za-z0-9_.]+" . \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rs' --include='*.php' \
  2>/dev/null | sort -u

# The compose file's env KEYS (names) are fine to read; do NOT transcribe resolved values:
grep -nE '^\s+[A-Z0-9_]+:' docker-compose.y*ml 2>/dev/null
```

If there is NO example file, build the list from the code grep alone and note that the repo shipped no `.env.example` (a maintenance gap worth flagging in `maintenance.md`). NEVER `cat .env`, `.env.production`, `.env.local`, or `~/.claude/secrets.env`.

### 1f. Infrastructure and deployment (evidence the REAL deploy, do not assume)

Read: `Dockerfile`, `docker-compose.y*ml`; `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`; `vercel.json`, `netlify.toml`, `fly.toml`, `railway.json`, `render.yaml`; `nginx.conf` / reverse-proxy configs; `k8s/`, `helm/`, `terraform/`.

**Deploy-path hypothesis (evidence-gated).** Pick the deployment story from the signals actually present, do NOT default to a generic "Vercel/Railway/AWS" menu:

| Signals in the repo | Primary deploy hypothesis to document | Cite |
|---|---|---|
| `Dockerfile` + `docker-compose` + an `nginx` vhost/config | **Aenoxa VPS pattern**: docker container behind nginx + certbot TLS, per-subdomain Cloudflare A record | `/oneshot-webapp` (docker + nginx + certbot, `.env` chmod 600); `/deploy-landing` `references/vps-facts.md` |
| Static export + nginx static root | VPS static nginx vhost + certbot | `/deploy-landing` (tar-over-ssh, nginx, `/cloudflare-dns`) |
| `vercel.json` / `.vercel` | Vercel | the config file itself |
| `fly.toml` / `railway.json` / `render.yaml` | that PaaS | the config file itself |
| No infra signal at all | `[unverified]`: state that no deploy config was found and the client should confirm the target | (honest gap) |

The Aenoxa VPS is READ-ONLY by default and this skill never SSHes to it; you are documenting the deploy path from the repo signals, not performing it. Keep "analyze the ACTUAL codebase" as the hard gate: never assert a deploy path the repo does not evidence.

### 1g. Third-party integrations (read each integration file)

```bash
grep -rnE "stripe|midtrans|xendit|duitku|twilio|sendgrid|mailgun|resend|postmark|aws-sdk|@google-cloud|firebase|supabase|clerk|auth0|sentry|datadog|segment|amplitude|mixpanel|cloudinary|uploadthing|redis|elasticsearch|algolia|pusher|socket\.io|minio" \
  --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.rb' --include='*.php' . 2>/dev/null
```

Read the file behind each hit to document how the integration is configured (which env var, which webhook, which endpoint). An import alone is not proof of use; confirm it is wired.

### 1h. Attribution (honest, scoped to the delivering party)

For the handover summary "Prepared By" and any team list, get the real contribution split, then CURATE to the delivering party (Aenoxa: Christopher plus any named contractors), not a blind dump of every historical committer (bots, squashed authors, and ex-teammates pollute it).

```bash
git shortlog -sn HEAD 2>/dev/null    # HEAD is load-bearing (see note)
```

> **The `HEAD` is mandatory.** Without an explicit revision, `git shortlog` reads log data from stdin in a non-interactive shell (exactly this runtime) and returns EMPTY with exit 0, silently blanking attribution (verified live 2026-07-02 in `/case-study`). Always pass `HEAD`. Then name only the actual delivering party in the doc, honestly.

===============================================================================
## 2. THE DOCUMENT SPEC (8 documents + README = 9 files; G5 format decision)
===============================================================================

Output directory: `mkdir -p docs/handover`. After the section 1 analysis, generate each document from evidence, writing each as soon as its analysis is ready (incremental writing is fine). **Full markdown templates for the 7 non-BAST docs + the README index live in `references/document-templates.md`** (progressive disclosure: they are the encyclopedic bulk, pulled in when assembling, so this file stays load-bearing). The BAST template + Indonesian conventions live in `references/bast-guide.md`.

### 2a. The 9 files, each tagged {audience} x {format} (G5)

| # | File | Audience | Required content (from evidence) | Format | Source of truth |
|---|---|---|---|---|---|
| 1 | `handover.md` | client-exec + dev | Project meta, overview, deliverables table, tech stack, team, warranty (house defaults, 0.4) | markdown (+ PDF if `--pdf-summary`) | 1a, 1h, README, config |
| 2 | `architecture.md` | dev | System diagram, component breakdown, data-flow, DB schema, integrations, infra | **markdown** (Mermaid renders in GitHub/VS Code) | 1b, 1d, 1f, 1g |
| 3 | `api.md` | dev | Every route: method, path, auth, middleware, request/response shape, error codes, webhooks | **markdown** | 1c |
| 4 | `deployment.md` | dev / ops | Prereqs, env-var NAMES (0.2), local setup, docker, DB setup, prod deploy (the 1f hypothesis), CI/CD, TLS/domain, rollback, health checks | markdown | 1e, 1f |
| 5 | `user-guide.md` | client (end user) | Feature walkthrough by role, admin panel, FAQ. Screenshots deferred to `/agent-browser` (rule 6) | markdown | 1c pages/UI, README |
| 6 | `credentials.md` | dev / ops | WHERE each secret lives + variable + where-to-obtain, NEVER the value (0.2) | markdown | 1e, 1f, 1g |
| 7 | `maintenance.md` | dev / ops | Routine tasks, monitoring, logs, troubleshooting, dependency updates, backup/recovery, scaling | markdown | stack facts |
| 8 | `bast.md` | client-exec (LEGAL) | Bilingual handover certificate, the render SOURCE for the PDF | markdown SOURCE + **signable PDF** | `references/bast-guide.md`, config |
| 9 | `README.md` | index | Navigation table + how-to-use | markdown | the other 8 |

**Why the format split (resolves the Mermaid trap).** `mmdc` (mermaid-cli) is ABSENT and Chrome-headless renders a ```mermaid fence as raw code text, so a naive "PDF everything" would turn architecture diagrams into garbage. Therefore: **diagram-bearing dev docs stay markdown** (Mermaid renders in the GitHub / VS Code viewers the dev audience uses). The BAST (and the optional handover summary) are diagram-free by design, so they render to PDF cleanly. If a diagram truly must appear in a PDF, the escape hatch is in `references/render-pipeline.md` (inline the mermaid.js library into the HTML); the DEFAULT is to keep diagram docs in markdown.

### 2b. Warranty and support defaults (house values, not blanks; finding-10 fix)

`handover.md` and the BAST pre-fill the house warranty defaults from `project_software_house` Phase 5 as SUGGESTED values, each marked `[TO CONFIRM: Suryadi]` because commercial terms are the CEO's remit (rule 0.4):

| Term | House default (suggested) |
|---|---|
| Warranty period | 30 to 60 days from BAST signing |
| Coverage | Bug fixes + critical security patches only |
| Excluded | New features, requirement changes, third-party-modification damage, force majeure |
| SLA | 24hr response for critical issues |
| Warranty start | Date the BAST is signed |

Do not leave these as empty `[TO BE AGREED]` blanks (the AI-slop default the robustness bar bans): commit to the house default and mark it for confirmation.

===============================================================================
## 3. THE PDF PIPELINE FOR THE BAST (G3, verified path only)
===============================================================================

The BAST deliverable is a **PDF** (rule 0.2 of the non-negotiables). The base recipe is the house-canonical one; **cite `/proposal` `references/pdf-pipeline.md` as the source of truth** rather than re-deriving it. The handover-specific deltas (the bilingual BAST HTML template, the multi-doc format decision, Mermaid-in-PDF handling) are in **`references/render-pipeline.md`**.

The one-screen version, verified live on this box 2026-07-03 (Chrome 144, a bilingual BAST HTML produced a valid 1-page PDF):

```bash
# 1. Render bast.md into a self-contained HTML (template in references/render-pipeline.md):
#    all CSS inline, no remote fonts/images/scripts, typography floors honored.
HTML="/tmp/bast-${SLUG}.html"
PDF="docs/handover/bast.pdf"

# 2. Chrome-headless HTML -> PDF. Capture stderr (Chrome prints "N bytes written" there):
google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header \
  "$HTML" 2>/tmp/bast-${SLUG}.chrome.log
RC=$?

# 3. VERIFY (G3, ALL must hold, else NOT done):
pages=$(pdfinfo "$PDF" 2>/dev/null | awk '/^Pages:/{print $2}')   # qpdf --show-npages fallback
[ "$RC" -eq 0 ] && [ -s "$PDF" ] && [ "${pages:-0}" -ge 1 ] \
  && echo "BAST PDF OK: $(stat -c%s "$PDF") bytes, ${pages} page(s)" \
  || echo "BAST PDF FAIL: rc=$RC size=$(stat -c%s "$PDF" 2>/dev/null || echo 0) pages=${pages:-0}"
```

- Binary verified at `/usr/bin/google-chrome-stable`. Fallback chain: `google-chrome` (`/opt/google/chrome/google-chrome`), then `chromium` (ABSENT here, so effectively chrome-stable then chrome).
- `pdfinfo` (poppler 26.05, `/usr/bin/pdfinfo`) is the page-count tool; `qpdf --show-npages "$PDF"` (qpdf 12.3, verified) is the fallback if pdfinfo is missing.
- **Client-editable copy** when the client will redline the BAST: `pandoc docs/handover/bast.md -o docs/handover/bast.docx` (works with NO LaTeX, verified). A second PDF route if every Chrome variant fails: `soffice --headless --convert-to pdf --outdir docs/handover docs/handover/bast.docx` (LibreOffice 26.2, verified). Chrome is primary (full CSS control); soffice is the safety net.
- **BANNED:** `pandoc bast.md -o bast.pdf` (no LaTeX engine, it fails). Never claim a PDF the verify step did not confirm.

Optional: `--pdf-summary` also renders `handover.md` to a PDF (same pipeline). It is diagram-free (tables only), so it renders cleanly.

===============================================================================
## 4. BOUNDARIES vs sibling client-ops skills
===============================================================================

Handover is the TERMINAL delivery package (software-house Phase 4). Do not conflate it with, or duplicate, the siblings.

| Skill | Its lane | vs /handover |
|---|---|---|
| `/proposal` | Pre-sales: scope + SOW + IDR price, before the work | Handover is AFTER the work ships |
| `/status-report` | Ongoing weekly progress during the build | Handover is the one-time terminal package |
| `/invoice` | Billing (30/40/30). **BAST sign triggers the final 30%** | Handover generates the BAST; `/invoice` bills it (section 6 handoff) |
| `/case-study` | INTERNAL portfolio narrative (private evidence ledger, recruiter-facing) | Handover is the CLIENT-facing delivery doc; shares only the "analyze-the-real-codebase" discipline |
| `/project-init` | Scaffolds the `docs/` structure at project START | Handover fills the delivery docs at project END |

Post-signature completeness check (G4 sample-verify): after generation, sample 3 to 5 documented endpoints or tables and grep them back to their source file to confirm they were not fabricated. A claim that cannot be traced is fixed or tagged `[unverified]`.

===============================================================================
## 5. FAILURE-MODE PLAYBOOK (smell -> exact recovery)
===============================================================================

| Failure mode | Smell | Fix / recovery |
|---|---|---|
| **Broken PDF path** | someone ran `pandoc bast.md -o bast.pdf`, or a claimed PDF that does not exist | Chrome-headless (section 3); `test -s` + `pdfinfo` before claiming; docx via pandoc. Cite `/proposal` `references/pdf-pipeline.md`. |
| **Mermaid shows as raw code in a PDF** | a ```mermaid fence rendered to literal text | Keep that doc markdown (G5), OR inline mermaid.js (`references/render-pipeline.md`). Diagram docs default to markdown. |
| **Real .env read by mistake** | a live value appeared in context | STOP, drop it from context, switch to `.env.example` + code-grep NAMES only (1e). |
| **Secret value in credentials.md** | V2a grep hits, or V2b shows a real connection string | G2 blocks it; replace the value with WHERE + which-var + where-to-obtain (0.2). |
| **Fabricated endpoint / table** | a documented route with no source file behind it | section 4 sample-verify; grep it back to source; if absent, delete or `[unverified]`. |
| **Empty `git shortlog`** | attribution came back blank | you dropped `HEAD`; re-run `git shortlog -sn HEAD` (1h). |
| **App Router over-match** | `route.js` files outside `app/` in the endpoint list | parenthesize the find alternation (1c). |
| **Blank warranty terms** | `[TO BE AGREED]` everywhere | pre-fill the house defaults marked `[TO CONFIRM: Suryadi]` (2b). |
| **Generic deploy menu** | deployment.md lists "Vercel/Railway/AWS/..." with no evidence | document only the 1f hypothesis the repo signals support; `[unverified]` if none. |
| **Em/en dash leak** | a long dash in the BAST or credentials map | V1 grep silent before delivery (0.1). |
| **File count mismatch** | report says 9, disk has 8 | G4: `test -s` each, reconcile the count before the success banner. |
| **Hardcoded company name in BAST** | a literal company string in Pihak Pertama | read `~/.claude/invoices/config.json` keys (0.4); never hardcode. |

===============================================================================
## 6. REPORT AS TABLES + THE /invoice HANDOFF
===============================================================================

Report to Christopher as tables (`feedback_visual_structured_docs`), never a prose wall. Four tables:

**(a) Files landed**

| # | Document | Format | Path | Verified |
|---|---|---|---|---|
| 1 | Handover summary | md (+pdf) | `docs/handover/handover.md` | test -s ok |
| ... | ... | ... | ... | ... |
| 8 | BAST | md + **PDF** | `docs/handover/bast.pdf` | rc0, N pages |
| 9 | Index | md | `docs/handover/README.md` | test -s ok |

**(b) Gates**

| Gate | Check | Result |
|---|---|---|
| G1 evidence floor | every fact traces to a source file | pass |
| G2 dash (V1) | grep silent | pass |
| G2 secret (V2a/V2b) | no true-secret shapes; connection strings are placeholders | pass |
| G3 BAST PDF | rc0 + test -s + pages>=1 | pass |
| G4 completeness | 9/9 files non-empty, count matches | pass |

**(c) Open items:** every `[unverified]` fact, every `[TO CONFIRM: Suryadi]` term, every `[TO CONFIRM]` client field, any missing `.env.example`, any deploy path that stayed `[unverified]`.

**(d) The /invoice handoff (on BAST sign).** Handover generates the certificate; it does NOT bill. When Christopher confirms the client signed the BAST, the final 30% milestone bills via `/invoice` (the 30/40/30 schedule from `project_software_house` Phase 4). Print the exact next command:

```
Next (when the BAST is signed): /invoice "<Client>" "<Project>"
   Bill the final milestone (30%, UAT sign-off / BAST). PPN is added by /invoice.
   The signed BAST is the trigger: final payment + warranty start.
```

===============================================================================
## EXECUTION FLOW
===============================================================================

1. **Parse** `$ARGUMENTS` (client / project name, `--pdf-summary`, `--docx`). Read `~/.claude/invoices/config.json` keys for BAST identity (0.4, never print values). `mkdir -p docs/handover`.
2. **Analyze** the real codebase (section 1), in parallel via `Explore` where useful, tracking with `TaskCreate`. Capture the source file behind every finding. Do not write until the evidence floor (G1) holds.
3. **Generate** the 8 documents + README from evidence, pulling templates from `references/document-templates.md`, each fact traced to a source. Deploy path from the 1f hypothesis. Warranty from the 2b house defaults marked for confirmation. Credentials WHERE-not-WHAT (0.2).
4. **Render the BAST** to a signable PDF (section 3, `references/bast-guide.md` + `references/render-pipeline.md`): fill the bilingual template from config + deliverables, HTML, Chrome-headless PDF, then G3 verify (rc0 + test -s + pdfinfo). docx too if `--docx`. Optional summary PDF if `--pdf-summary`.
5. **Sample-verify** (section 4): grep 3 to 5 documented endpoints / tables back to source; fix or `[unverified]` any that do not trace.
6. **VERIFY** (0.5): run V1 to V4 over every produced file; V2b hits disambiguated to placeholder-only; all silent.
7. **Completeness** (G4): `test -s` each of the 9 files; reported count == on-disk count.
8. **Report as tables** (section 6): files-landed, gates, open items, the `/invoice` handoff. **Send nothing, deploy nothing, commit nothing** (rule 7).

## COMPOSES WITH

- **/proposal** scoped the engagement and defined the 30/40/30 milestones; **/handover** produces the BAST that unlocks the final one.
- **/invoice** bills the final milestone when the BAST is signed (section 6 handoff, shared config).
- **/status-report** ran the weekly updates during the build; handover is the terminal package, not a weekly.
- **/agent-browser** owns any UI screenshot capture for `user-guide.md` (a separate, Christopher-gated task; never Playwright MCP, never kill the live browser).
- **/commit** lands `docs/handover/` in the repo if Christopher wants it versioned (commit-skill enforced, never raw `git commit`).

Remember: this is the document a client signs to accept the work and pay the final invoice, and the runbook whoever maintains the system relies on. Its value is that it is TRUE (every fact traced to the code), SAFE (no secret value ever leaves its vault), and SIGNABLE (the BAST is a verified PDF, not a draft). Analyze the real codebase, keep secrets as WHERE-not-WHAT, render the BAST, run the gates, and hand Christopher a package he can deliver.
