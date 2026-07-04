# references/document-templates.md: the 7 non-BAST document templates + README index

Progressive-disclosure companion to `SKILL.md` section 2. The load-bearing rules, gates, and analysis discipline live in SKILL.md; this file carries the full markdown skeletons so SKILL.md stays lean. The BAST is separate (`references/bast-guide.md`).

**Fill-in discipline (applies to every template here):**
- Every `{placeholder}` is replaced with a real value derived from the section 1 analysis, or the line is dropped, or it is tagged `[unverified]` with an honest note (SKILL.md rule 0.3). A leftover `{...}` is the "still a template" tell and fails V4.
- NO em or en dash in any filled value (rule 0.1). NO secret VALUE anywhere (rule 0.2): credentials are WHERE + which-variable + where-to-obtain.
- Prefer tables and Mermaid diagrams over prose (`feedback_visual_structured_docs`). These docs are the dev audience, so Mermaid is correct (it renders in GitHub / VS Code); they stay MARKDOWN (SKILL.md G5).
- Cite the source file behind each documented route group / table / integration as you fill (those citations are what SKILL.md section 4 samples back).

---

## Document 1: handover.md (Handover Summary)

```markdown
# Project Handover: {PROJECT_NAME}

## Handover Details
| Field | Detail |
|-------|--------|
| Project Name | {from package.json / manifest} |
| Client | {from $ARGUMENTS, else [TO CONFIRM]} |
| Handover Date | {today, TZ=Asia/Jakarta} |
| Prepared By | {curated delivering party from git shortlog -sn HEAD, section 1h} |
| Repository | {remote or "provided separately"} |

## Project Overview
{From README.md or inferred from code: what the project does, its purpose, target users. If the README is thin, state what the code shows and mark anything uncertain [unverified].}

## Objectives
{The problems this system solves, from the README + the feature set actually present.}

## Deliverables

| # | Feature / Module | Status | Source (file / route) |
|---|------------------|--------|-----------------------|
{One row per major feature found in the codebase, each tracing to where it lives. Status is Delivered unless the code shows it incomplete.}

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
{From package.json / go.mod / pyproject dependencies, with real versions (versions are evidence).}

## Team
{The real delivering party (section 1h), curated, not a raw committer dump. Aenoxa: Christopher (CTO, technical) + any named contractor. Honest about solo vs team.}

## Warranty & Support (house defaults, confirm commercial terms with Suryadi)

| Term | Detail |
|------|--------|
| Warranty Period | 30 to 60 days from BAST signing [TO CONFIRM: Suryadi] |
| Coverage | Bug fixes + critical security patches only [TO CONFIRM: Suryadi] |
| Excluded | New features, requirement changes, third-party-modification damage, force majeure |
| SLA | 24hr response for critical issues [TO CONFIRM: Suryadi] |
| Warranty Start | Date the BAST is signed |
| Support Contact | {from config company.email / phone, else [TO CONFIRM]} |
```

---

## Document 2: architecture.md (Architecture Documentation)

```markdown
# Architecture Documentation: {PROJECT_NAME}

## System Architecture

{A Mermaid diagram of the high-level architecture, built from the REAL component boundaries found in section 1b, not a generic 3-tier stock diagram.}

\```mermaid
graph TB
    subgraph Client
        {real frontend surfaces}
    end
    subgraph Server
        {real services / API layers}
    end
    subgraph Data
        {real datastores}
    end
    subgraph External
        {real third-party integrations from 1g}
    end
\```

## Component Breakdown

{For each major directory / module found in 1b:}
### {Component Name}
- **Location**: `{path}`
- **Purpose**: {what it does, from reading it}
- **Key Files**: {the important files}
- **Depends On**: {what it imports / calls}

## Data Flow

{For each key user journey actually present (auth, the main CRUD flow, payment if a payment integration exists): a Mermaid sequence diagram built from the real handler chain.}

### {Journey Name}
\```mermaid
sequenceDiagram
    {real participants + calls}
\```

## Database Schema

{Every table / model found in 1d. Cite the schema file.}

### {Table Name}  (source: `{schema file}`)
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
{From the actual schema.}

### Relationships
\```mermaid
erDiagram
    {real relationships from the schema}
\```

## API Architecture
- **Style**: {REST / GraphQL / gRPC / tRPC, from the code}
- **Authentication**: {the real mechanism: JWT / session / API key / OAuth, from the middleware}
- **Base path**: {from the router config or env NAME}
- **Rate Limiting**: {describe the middleware if present, else "No rate-limiting middleware found in the code"}

## Third-Party Integrations

| Service | Purpose | Config (env NAME) | Wired in (file) | Docs |
|---------|---------|-------------------|-----------------|------|
{From 1g, each row tracing to the file that wires it. Env is the NAME only, never the value.}

## Infrastructure

{An infra diagram from the Dockerfile / compose / deploy signals found in 1f.}

\```mermaid
graph LR
    {real infra topology}
\```
```

---

## Document 3: api.md (API Documentation)

```markdown
# API Documentation: {PROJECT_NAME}

## Base URL
{From the router config or an env NAME; if only known at deploy time, say so.}

## Authentication
{The real auth mechanism from the middleware: token format, required headers, how it is validated. Cite the middleware file.}

## Endpoints

{For EVERY route found in 1c, grouped by resource. Cite the route file per group.}

### {Group Name}  (source: `{route file}`)

#### `{METHOD} {PATH}`
{Description inferred from reading the handler.}

- **Auth**: {required / optional / none}
- **Middleware**: {list}
- **Request**: {the body / query shape from the code, as a TS interface or JSON schema}
- **Response** (`{status}`): {the shape returned by the handler}
- **Errors**:
  | Status | Condition |
  |--------|-----------|
  {From the handler's error paths.}

{Repeat for every endpoint. Do not invent an endpoint that is not in the code.}

## Error Codes
{If the project has a centralized error catalog, document it from the source. Else omit with a note.}

| Code | HTTP Status | Meaning |
|------|-------------|---------|
{From the real error definitions.}

## Rate Limiting
{From the middleware / config, else "Not implemented (no rate-limiting middleware found)".}

## Webhooks
{For each webhook handler found:}
### {Webhook Name}  (source: `{file}`)
- **Path**: {the route}
- **Trigger**: {what fires it}
- **Payload**: {the shape}
- **Verification**: {signature check method, if any}
```

---

## Document 4: deployment.md (Deployment Guide)

```markdown
# Deployment Guide: {PROJECT_NAME}

## Prerequisites

| Requirement | Version | Notes |
|------------|---------|-------|
{From package.json engines, .nvmrc, .python-version, go.mod, Dockerfile base image.}

## Environment Variables (NAMES + purpose, NEVER values)

> This lists the variable NAMES the app requires and where each value is obtained.
> The actual secret values live in the deployment environment, never in this doc.

| Variable | Required | Purpose | Where the value comes from |
|----------|----------|---------|----------------------------|
{From the .env.example + code-usage grep of section 1e. NAMES only. No resolved values.}

## Local Development Setup
1. Clone the repository.
2. Install dependencies: `{the real install command}`
3. Environment: `cp .env.example .env`, then fill each value (see credentials.md for where each is obtained).
4. Database: `{the real migration command}`
5. Start: `{the real dev command}`

## Docker Setup
{If a Dockerfile / compose exists, the real commands from the project.}
\```bash
{actual docker commands}
\```

## Database Setup
### Initial
{Migration command from the scripts / framework convention.}
### Migrations
{How to create + run a migration.}
### Seeding
{If a seed script exists, document it; else omit.}

## Production Deployment

{Document ONLY the deploy hypothesis the repo signals support (SKILL.md 1f). Do NOT list a generic platform menu.}

### {The evidenced target}
{If the repo shows Docker + nginx signals, this is the Aenoxa VPS pattern: docker container behind nginx + certbot TLS + a per-subdomain Cloudflare A record. The mechanics are owned by /oneshot-webapp (docker + .env chmod 600) and /deploy-landing (nginx + certbot, references/vps-facts.md); this guide describes THIS app's deploy, and points the maintainer at those runbooks. The VPS is READ-ONLY by default; this doc does not perform the deploy.}

{If a PaaS config (vercel.json / fly.toml / render.yaml) is present, document that platform from the config file. If NO infra signal exists, state that and mark the target [unverified] for the client to confirm.}

## CI/CD Pipeline
{From .github/workflows or equivalent: each workflow, its trigger, its steps, what it deploys.}

## SSL / Domain
{From the nginx config / platform settings found in 1f.}

## Rollback
1. {How to roll back to the previous version, per the deploy method.}
2. {How to roll back a database migration.}

## Health Checks
{If health endpoints exist, document them.}
| Endpoint | Expected | Purpose |
|----------|----------|---------|
```

---

## Document 5: user-guide.md (User Guide)

```markdown
# User Guide: {PROJECT_NAME}

## Overview
{What the application does from a user's perspective.}

## Getting Started
{How to access it: URL (or "provided at handover"), the login flow.}

## Features

{Organized by user role if role-based access exists (from the auth code), else by feature area. For each feature found in the pages / UI:}

### {Feature Name}
- **Access**: {who can use it, the role or permission}
- **Location**: {where in the UI / which page}

#### How to {action}
1. {Step, based on the actual UI components / pages found in the code.}
2. ...

> Screenshots: capturing live UI screenshots is a SEPARATE, Christopher-gated task
> handled by the /agent-browser skill (never Playwright MCP, never kill the live
> browser). Leave `[screenshot: {page}]` markers where an image belongs.

{If an admin panel exists:}
## Admin Panel
### Dashboard
{What it shows.}
### User Management
{The CRUD operations available.}

## FAQ
{Real FAQs generated from the features present.}
### Q: {question}
A: {answer}
```

---

## Document 6: credentials.md (Credentials & Access Map)

```markdown
# Credentials & Access Map: {PROJECT_NAME}

> This document lists WHERE each credential is stored and HOW to obtain it.
> It contains NO secret values. Never paste a key, password, token, or connection
> string into this file. (SKILL.md rule 0.2, enforced by the V2 secret scan.)

## Environment Configuration
| Environment | Config File | Location |
|-------------|-------------|----------|
{The .env files by environment and where each lives, e.g. "production: .env on the server, chmod 600". NAMES and locations, not contents.}

## Service Accounts & API Keys
| Service | Purpose | Env Variable(s) | Where to Obtain |
|---------|---------|-----------------|-----------------|
{From 1e + 1g. Example row: "Stripe | payments | STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET | Stripe Dashboard > Developers > API keys". Never the value.}

## Server Access
| Resource | Access Method | Details |
|----------|--------------|---------|
{From the deploy configs: SSH host + user (not the password, which lives in the client's vault), dashboard URLs. Point at where the credential is held, never inline it.}

## Third-Party Services
| Service | Purpose | Dashboard URL | Account Owner |
|---------|---------|---------------|---------------|
{From 1g.}

## Database Access
| Database | Type | Connection Env Var | Management Tool |
|----------|------|--------------------|-----------------|
{The connection is referenced by its env VARIABLE NAME, with the format documented as a placeholder only: postgres://USER:PASSWORD@HOST/DB. Never the resolved string.}

## DNS & Domain
| Domain | Registrar | DNS Provider | Notes |
|--------|-----------|-------------|-------|
{If detectable from config; else [TO CONFIRM].}

## Monitoring & Logging
| Service | Purpose | Dashboard | Env Var(s) |
|---------|---------|-----------|------------|
{From Sentry / Datadog / etc. detected in 1g.}

## CI/CD Secrets
| Platform | Repository | Secrets Location |
|----------|-----------|-------------------|
{From the workflow files: which secrets the pipeline expects, stored in the CI provider's secret store (named, not valued).}
```

---

## Document 7: maintenance.md (Maintenance Guide)

```markdown
# Maintenance Guide: {PROJECT_NAME}

## Regular Maintenance Tasks
| Task | Frequency | How |
|------|-----------|-----|
{Based on the real stack: dependency updates, certificate renewal (certbot auto-renew if VPS), backup verification, log rotation.}

## Monitoring & Alerting
{From the monitoring tools detected in 1g. If none, say "No monitoring integration found; recommend adding one" as an honest gap.}
### {Tool}
- **Dashboard**: {URL from config}
- **Monitors**: {what}
- **Alert channels**: {from config}

## Log Locations
| Log | Location | How to Access |
|-----|----------|---------------|
{From the logging config / Docker logs / platform logs. If VPS docker, note the docker logs discipline: bounded foreground reads only.}

## Common Issues & Troubleshooting
{Generated from the real stack + its common failure modes.}
### {Issue}
- **Symptoms**: {what the user sees}
- **Likely cause**: {based on the architecture}
- **Fix**:
  \```bash
  {diagnostic + fix commands}
  \```

## Dependency Updates
### Process
{Per the package manager detected: how to check, update, test.}
### Critical Dependencies
| Package | Current | Purpose | Update Caution |
|---------|---------|---------|----------------|
{Major deps that need careful updating. If axios appears, note the supply-chain caution: do not blind-upgrade axios, per feedback_axios_supply_chain.}

## Backup & Recovery
### What to Back Up
| Data | Location | Method | Frequency |
|------|----------|--------|-----------|
{Database, uploaded files (MinIO / S3 if present), configs.}
### Recovery Procedure
1. {Step-by-step recovery per the deploy method.}

## Scaling (if the architecture warrants it)
- **When**: {signs scaling is needed}
- **How**: {horizontal / vertical per the deploy method}
- **Database**: {per the DB type}
```

---

## The README index (docs/handover/README.md)

```markdown
# Handover Documentation: {PROJECT_NAME}

Generated {today, TZ=Asia/Jakarta} for {CLIENT / [TO CONFIRM]}.

## Documents

| # | Document | Audience | Format |
|---|----------|----------|--------|
| 1 | [Handover Summary](handover.md) | Client + dev | Markdown |
| 2 | [Architecture](architecture.md) | Dev | Markdown (Mermaid) |
| 3 | [API Documentation](api.md) | Dev | Markdown |
| 4 | [Deployment Guide](deployment.md) | Dev / ops | Markdown |
| 5 | [User Guide](user-guide.md) | End user | Markdown |
| 6 | [Credentials & Access Map](credentials.md) | Dev / ops | Markdown (no secrets) |
| 7 | [Maintenance Guide](maintenance.md) | Dev / ops | Markdown |
| 8 | [BAST](bast.md) | Client (legal) | Markdown source + **bast.pdf** |

## How to Use This Package
1. Review every document for accuracy.
2. Fill the `[TO CONFIRM]` fields (client details) and confirm the `[TO CONFIRM: Suryadi]` commercial terms with the CEO.
3. Populate real secret values into your deployment vault using credentials.md as the map (never write values into these docs).
4. Walk the deployment guide to verify it reproduces a working deploy.
5. Sign the BAST PDF (both parties, positions, dates, stamp, materai) to complete the handover.
6. Archive this package alongside the source code.
```
