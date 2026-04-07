---
name: handover
description: Generate a comprehensive project handover documentation package for client delivery. Analyzes the actual codebase to produce accurate architecture docs, API docs, deployment guide, credentials map, maintenance guide, user guide, and BAST document. Use when the user needs to hand over a project or says /handover.
argument-hint: [optional: client name or project name]
allowed-tools: Bash, Read, Glob, Grep, Write, Agent, TaskCreate, TaskUpdate
---

## Project Handover Documentation Generator

Generate a complete handover documentation package by analyzing the actual codebase. Every document must reflect real project state — no generic placeholders.

### 0. Setup

Create the output directory:
```bash
mkdir -p docs/handover
```

If `$ARGUMENTS` is provided, parse it as the client name or project name to use in the documents. If not provided, infer the project name from `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `README.md`, or the directory name.

### 1. Codebase Analysis (Do this FIRST)

Before writing any document, perform a thorough analysis of the project. Use the Agent tool with subagent_type=Explore to gather information in parallel where possible.

#### 1a. Project Identity & Stack

Read these files (if they exist) to understand the project:
- `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
- `pyproject.toml`, `requirements.txt`, `Pipfile`
- `go.mod`, `go.sum`
- `Cargo.toml`
- `composer.json`
- `Gemfile`
- `README.md`, `CLAUDE.md`
- `docker-compose.yml`, `docker-compose.yaml`, `Dockerfile`
- `.github/workflows/*.yml`
- `Makefile`, `justfile`, `Taskfile.yml`

Extract:
- Project name, description
- Language(s) and framework(s)
- All dependencies (production and dev)
- Scripts/commands available
- Node/Python/Go/Rust version requirements

#### 1b. Architecture & Code Structure

```bash
# Get full directory tree (depth-limited)
find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' -not -path '*/.next/*' -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.venv/*' -not -path '*/venv/*' -not -path '*/.turbo/*' | head -500
```

Identify:
- Monorepo or single project
- Source code directories and their purpose
- Frontend / backend / shared code boundaries
- Database ORM models or migration files
- Configuration files and their roles

#### 1c. API Routes

Search for route definitions based on the framework detected:

**Express/Fastify/Hono (Node.js):**
```
grep -rn "router\.\(get\|post\|put\|patch\|delete\)\|app\.\(get\|post\|put\|patch\|delete\)" --include="*.ts" --include="*.js"
```

**Next.js App Router:**
```
find . -path "*/app/api/*" -name "route.ts" -o -name "route.js"
```

**Next.js Pages Router:**
```
find . -path "*/pages/api/*" \( -name "*.ts" -o -name "*.js" \)
```

**Django:**
```
grep -rn "path\|url\|urlpatterns" --include="*.py" */urls.py
```

**FastAPI/Flask:**
```
grep -rn "@app\.\(get\|post\|put\|patch\|delete\)\|@router\.\(get\|post\|put\|patch\|delete\)" --include="*.py"
```

**Go (net/http, Gin, Chi, Echo):**
```
grep -rn "HandleFunc\|Handle\|GET\|POST\|PUT\|DELETE\|r\.Route\|e\.GET\|e\.POST" --include="*.go"
```

**Laravel:**
```
grep -rn "Route::\(get\|post\|put\|patch\|delete\|resource\|apiResource\)" --include="*.php" routes/
```

Read each route file fully to extract: method, path, middleware, handler function, request/response types.

#### 1d. Database Schema

Search for schema definitions:

**Prisma:** Read `prisma/schema.prisma`
**Drizzle:** Search for `*.schema.ts`, `schema.ts`, or files containing `pgTable`, `mysqlTable`, `sqliteTable`
**TypeORM/MikroORM:** Search for `@Entity` decorators
**Sequelize:** Search for `Model.init` or `define`
**Django:** Read `models.py` files
**SQLAlchemy:** Search for `class.*Base.*Model` or `Column(`
**Raw SQL migrations:** Read files in `migrations/`, `db/migrate/`, `alembic/versions/`
**Knex:** Read migration files in `migrations/` or `knexfile`

Read every schema/model file to extract: table names, column names and types, relationships, indexes, constraints.

#### 1e. Environment Variables

Read these files:
- `.env.example`, `.env.sample`, `.env.template`
- `.env.local.example`
- `.env.development`, `.env.production` (if not gitignored)
- `docker-compose.yml` (environment section)
- Deployment configs

Also search for `process.env.`, `os.environ`, `os.Getenv`, `env::var`, `Config::get` across the codebase to find all env vars actually used.

#### 1f. Infrastructure & Deployment

Read:
- `Dockerfile`, `docker-compose.yml`
- `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `bitbucket-pipelines.yml`
- `vercel.json`, `netlify.toml`, `fly.toml`, `railway.json`, `render.yaml`
- `terraform/`, `pulumi/`, `cdk/` directories
- `nginx.conf`, `caddy`, reverse proxy configs
- `k8s/`, `kubernetes/`, `helm/` directories

#### 1g. Third-Party Integrations

Search for SDK imports, API client instantiations, webhook handlers:
```
grep -rn "stripe\|twilio\|sendgrid\|mailgun\|aws-sdk\|@google-cloud\|firebase\|supabase\|clerk\|auth0\|sentry\|datadog\|segment\|amplitude\|mixpanel\|cloudinary\|uploadthing\|resend\|postmark\|redis\|elasticsearch\|algolia\|pusher\|socket\.io" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" --include="*.rb" --include="*.php"
```

Read the relevant files to understand how each integration is configured.

---

### 2. Generate Documents

After analysis is complete, generate all 8 documents. Write them using the Write tool. Every document must contain ONLY information derived from the actual codebase analysis — never fabricate endpoints, tables, or features that don't exist.

Use tasks (TaskCreate) to track progress through each document.

---

#### Document 1: handover.md — Handover Summary

```markdown
# Project Handover: {PROJECT_NAME}

## Handover Details
| Field | Detail |
|-------|--------|
| Project Name | {from package.json/config} |
| Client | {from $ARGUMENTS or "TBD"} |
| Handover Date | {today's date} |
| Prepared By | {from git log --format='%an' | sort -u} |

## Project Overview
{From README.md or inferred from code — what the project does, its purpose, target users}

## Objectives
{Inferred from features and README}

## Deliverables

| # | Feature | Status | Notes |
|---|---------|--------|-------|
{List every major feature found in the codebase — routes, pages, services}

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
{From package.json dependencies, go.mod, etc.}

## Team
{From git log contributors}

## Warranty & Support

| Term | Detail |
|------|--------|
| Warranty Period | [TO BE AGREED] |
| Support Contact | [TO BE AGREED] |
| Support Hours | [TO BE AGREED] |
| SLA | [TO BE AGREED] |
| Escalation Path | [TO BE AGREED] |
```

---

#### Document 2: architecture.md — Architecture Documentation

```markdown
# Architecture Documentation: {PROJECT_NAME}

## System Architecture

{Generate a Mermaid diagram showing the high-level architecture}

\```mermaid
graph TB
    subgraph Client
        ...
    end
    subgraph Server
        ...
    end
    subgraph Database
        ...
    end
    subgraph External
        ...
    end
\```

## Component Breakdown

{For each major directory/module, describe:}
### {Component Name}
- **Location**: `{path}`
- **Purpose**: {what it does}
- **Key Files**: {important files}
- **Dependencies**: {what it depends on}

## Data Flow Diagrams

{For each key user journey (auth, main CRUD operations, payment if applicable):}

### {Journey Name}
\```mermaid
sequenceDiagram
    ...
\```

## Database Schema

{Document every table/model found:}

### {Table Name}
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
{From actual schema files}

### Relationships
\```mermaid
erDiagram
    ...
\```

## API Architecture
- **Style**: {REST/GraphQL/gRPC/tRPC}
- **Authentication**: {method found in code — JWT, session, API key, OAuth}
- **Base URL**: {from config or env}
- **Rate Limiting**: {if implemented, describe; otherwise note "Not implemented"}

## Third-Party Integrations

| Service | Purpose | Config Location | Env Vars | Docs |
|---------|---------|-----------------|----------|------|
{From integration analysis}

## Infrastructure

{Generate infrastructure diagram from Docker/deployment configs:}

\```mermaid
graph LR
    ...
\```
```

---

#### Document 3: api.md — API Documentation

```markdown
# API Documentation: {PROJECT_NAME}

## Base URL
{From config/env}

## Authentication
{Describe the auth mechanism found in the code — middleware, token format, headers required}

## Endpoints

{For EVERY route found in the codebase:}

### {GROUP NAME}

#### `{METHOD} {PATH}`
{Description inferred from handler code}

**Authentication**: {required/optional/none}
**Middleware**: {list any middleware applied}

**Request**:
{If body expected, show the TypeScript interface or JSON schema from the code}

**Response** (`{status_code}`):
{Show the response type/shape from the code}

**Error Responses**:
| Status | Description |
|--------|-------------|
{From error handling in the handler}

---

{Repeat for every endpoint}

## Error Codes
{If the project has a centralized error handling system, document it}

| Code | HTTP Status | Description |
|------|-------------|-------------|
{From actual error definitions}

## Rate Limiting
{From middleware or config, or "Not implemented" if none found}

## Webhooks
{If any webhook handlers exist, document:}
### {Webhook Name}
- **URL**: {path}
- **Trigger**: {what causes it}
- **Payload**: {shape}
- **Verification**: {signature verification method if any}
```

---

#### Document 4: deployment.md — Deployment Guide

```markdown
# Deployment Guide: {PROJECT_NAME}

## Prerequisites

| Requirement | Version | Notes |
|------------|---------|-------|
{From package.json engines, .nvmrc, .python-version, go.mod, Dockerfile, etc.}

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
{From .env.example and process.env usage analysis — NEVER include actual secret values}

## Local Development Setup

{Step-by-step from README or inferred from scripts:}
1. Clone the repository
2. Install dependencies: `{actual install command}`
3. Set up environment: `cp .env.example .env`
4. Set up database: `{actual migration command}`
5. Start development server: `{actual dev command}`

## Docker Setup
{If Dockerfile/docker-compose exists, document:}
```bash
{actual docker commands from the project}
```

## Database Setup

### Initial Setup
{Migration commands from package.json scripts or framework conventions}

### Migrations
{How to create and run migrations}

### Seeding
{If seed scripts exist, document them}

## Production Deployment

{Based on what deployment platform is detected:}

### {Platform Name} (Vercel/Railway/AWS/GCP/VPS/etc.)
{Step-by-step deployment instructions derived from configs}

## CI/CD Pipeline

{From .github/workflows or equivalent:}
{Describe each workflow — trigger, steps, what it deploys}

## SSL / Domain Configuration
{From nginx config, Caddyfile, or platform settings}

## Rollback Procedures

{Based on deployment method:}
1. {How to roll back to previous version}
2. {How to roll back database migrations}

## Health Checks
{If health check endpoints exist, document them}
| Endpoint | Expected Response | Purpose |
|----------|-------------------|---------|
```

---

#### Document 5: user-guide.md — User Guide

```markdown
# User Guide: {PROJECT_NAME}

## Overview
{What the application does from a user's perspective}

## Getting Started
{How to access the application — URL, login process}

## Features

{Organize by user role if role-based access exists, otherwise by feature area.
For each feature, describe:}

### {Feature Name}
**Access**: {who can use this — role or permission level}
**Location**: {where in the UI / which page}

#### How to {action}
1. {Step-by-step based on the actual UI components and pages found in the code}
2. ...

{If admin panel exists:}
## Admin Panel

### Dashboard
{What the admin dashboard shows}

### User Management
{CRUD operations available}

### {Other admin features}

## FAQ

{Generate relevant FAQs based on the features found:}

### Q: {question}
A: {answer}
```

---

#### Document 6: credentials.md — Credentials & Access

```markdown
# Credentials & Access Map: {PROJECT_NAME}

> **IMPORTANT**: This document lists WHERE credentials are stored, NOT the credentials themselves.
> Never commit actual secrets to this file.

## Environment Configuration
| Environment | Config File | Location |
|-------------|-------------|----------|
{.env files and their purpose}

## Service Accounts & API Keys

| Service | Purpose | Env Variable(s) | Where to Obtain |
|---------|---------|-----------------|-----------------|
{From env var analysis and integration detection}

## Server Access

| Resource | Access Method | Details |
|----------|--------------|---------|
{From deployment configs — SSH, dashboard URLs, etc.}

## Third-Party Services

| Service | Purpose | Dashboard URL | Account Owner |
|---------|---------|---------------|---------------|
{From detected integrations}

## Database Access

| Database | Type | Connection Env Var | Management Tool |
|----------|------|--------------------|-----------------|
{From database config}

## DNS & Domain

| Domain | Registrar | DNS Provider | Nameservers |
|--------|-----------|-------------|-------------|
{If detectable from config}

## Monitoring & Logging

| Service | Purpose | Dashboard | Env Vars |
|---------|---------|-----------|----------|
{From Sentry, Datadog, LogRocket, etc. integration detection}

## CI/CD

| Platform | Repository | Secrets Location |
|----------|-----------|-----------------|
{From workflow files}
```

---

#### Document 7: maintenance.md — Maintenance Guide

```markdown
# Maintenance Guide: {PROJECT_NAME}

## Regular Maintenance Tasks

| Task | Frequency | How |
|------|-----------|-----|
{Based on the stack — e.g., dependency updates, certificate renewal, backup verification}

## Monitoring & Alerting

{From detected monitoring tools:}
### {Tool Name}
- **Dashboard**: {URL from config}
- **What it monitors**: {description}
- **Alert channels**: {from config}

## Log Locations

| Log | Location | How to Access |
|-----|----------|---------------|
{From logging config, Docker logs, platform-specific logs}

## Common Issues & Troubleshooting

{Generate based on the stack and common failure modes:}

### {Issue}
**Symptoms**: {what the user would see}
**Cause**: {likely cause based on the architecture}
**Fix**:
```bash
{commands to diagnose and fix}
```

## Dependency Updates

### Process
{Based on the package manager detected:}
1. {How to check for updates}
2. {How to update}
3. {How to test after updating}

### Critical Dependencies
| Package | Current Version | Purpose | Update Caution |
|---------|----------------|---------|----------------|
{Major dependencies that need careful updating}

## Performance Optimization

{Based on the stack:}
- {Database query optimization tips}
- {Caching strategy from the code}
- {CDN/static asset optimization}

## Scaling Guide

{Based on the architecture:}

### When to Scale
{Signs that scaling is needed}

### How to Scale
{Horizontal/vertical scaling based on the deployment method}

### Database Scaling
{Based on the database type}

## Backup & Recovery

### What to Back Up
| Data | Location | Method | Frequency |
|------|----------|--------|-----------|
{Database, uploaded files, configs}

### Recovery Procedure
1. {Step-by-step recovery}
```

---

#### Document 8: bast.md — Berita Acara Serah Terima

```markdown
# BERITA ACARA SERAH TERIMA PEKERJAAN
# WORK HANDOVER CERTIFICATE

---

**Nomor / Number**: _______________
**Tanggal / Date**: {today's date}

---

## PARA PIHAK / PARTIES

### Pihak Pertama / First Party (Pengembang / Developer):
| | |
|---|---|
| Nama / Name | _________________________ |
| Jabatan / Position | _________________________ |
| Perusahaan / Company | _________________________ |
| Alamat / Address | _________________________ |

### Pihak Kedua / Second Party (Klien / Client):
| | |
|---|---|
| Nama / Name | {client name from $ARGUMENTS or "_________________________"} |
| Jabatan / Position | _________________________ |
| Perusahaan / Company | _________________________ |
| Alamat / Address | _________________________ |

---

## LINGKUP PEKERJAAN / SCOPE OF WORK

Proyek pengembangan aplikasi **{PROJECT_NAME}** sebagaimana tertuang dalam perjanjian kerja nomor _______________ tanggal _______________.

Development of **{PROJECT_NAME}** application as stated in the work agreement number _______________ dated _______________.

---

## DAFTAR DELIVERABLES / DELIVERABLES CHECKLIST

| No | Deliverable | Deskripsi / Description | Status | Tanda Tangan / Sign-off |
|----|-------------|------------------------|--------|------------------------|
{Generate rows from actual features/deliverables found in codebase}
| | Source Code | Repository akses penuh / Full repository access | [ ] Selesai / Complete | _______ |
| | Dokumentasi / Documentation | Paket dokumentasi handover / Handover documentation package | [ ] Selesai / Complete | _______ |
| | Akses Server / Server Access | Kredensial dan akses server / Server credentials and access | [ ] Selesai / Complete | _______ |
| | Database | Skema dan data migrasi / Schema and data migrations | [ ] Selesai / Complete | _______ |

---

## DOKUMENTASI YANG DISERAHKAN / DOCUMENTS HANDED OVER

| No | Dokumen / Document | Format | Lokasi / Location |
|----|-------------------|--------|-------------------|
| 1 | Ringkasan Handover / Handover Summary | Markdown | `docs/handover/handover.md` |
| 2 | Dokumentasi Arsitektur / Architecture Documentation | Markdown | `docs/handover/architecture.md` |
| 3 | Dokumentasi API / API Documentation | Markdown | `docs/handover/api.md` |
| 4 | Panduan Deployment / Deployment Guide | Markdown | `docs/handover/deployment.md` |
| 5 | Panduan Pengguna / User Guide | Markdown | `docs/handover/user-guide.md` |
| 6 | Peta Kredensial / Credentials Map | Markdown | `docs/handover/credentials.md` |
| 7 | Panduan Pemeliharaan / Maintenance Guide | Markdown | `docs/handover/maintenance.md` |
| 8 | Berita Acara / Handover Certificate | Markdown | `docs/handover/bast.md` |

---

## MASA GARANSI / WARRANTY PERIOD

Masa garansi dimulai sejak tanggal penandatanganan Berita Acara ini selama **_____ (______) bulan**.

The warranty period starts from the date of signing this Handover Certificate for a period of **_____ (______) months**.

### Cakupan Garansi / Warranty Coverage:
- [ ] Perbaikan bug / Bug fixes
- [ ] Perbaikan keamanan kritis / Critical security patches
- [ ] Dukungan teknis melalui {channel} / Technical support via {channel}

### Tidak Termasuk Garansi / Not Covered:
- Penambahan fitur baru / New feature additions
- Perubahan requirement / Requirement changes
- Kerusakan akibat modifikasi oleh pihak ketiga / Damage from third-party modifications
- Force majeure

---

## PERNYATAAN SERAH TERIMA / HANDOVER DECLARATION

Dengan ditandatanganinya Berita Acara ini, Pihak Pertama menyerahkan dan Pihak Kedua menerima seluruh deliverables sebagaimana tercantum di atas dalam keadaan baik dan lengkap.

By signing this Handover Certificate, the First Party hands over and the Second Party accepts all deliverables as listed above in good and complete condition.

---

## TANDA TANGAN / SIGNATURES

| | Pihak Pertama / First Party | Pihak Kedua / Second Party |
|---|---|---|
| Tanda Tangan / Signature | | |
| Nama / Name | _________________________ | _________________________ |
| Jabatan / Position | _________________________ | _________________________ |
| Tanggal / Date | _________________________ | _________________________ |
| Stempel / Stamp | | |

---

*Dokumen ini dibuat dalam rangkap 2 (dua), masing-masing mempunyai kekuatan hukum yang sama.*
*This document is made in 2 (two) copies, each having the same legal force.*
```

---

### 3. Final Output

After generating all documents, create an index file:

#### docs/handover/README.md

```markdown
# Handover Documentation: {PROJECT_NAME}

Generated on {today's date}

## Documents

| Document | Description |
|----------|-------------|
| [Handover Summary](handover.md) | Project overview, deliverables, team, warranty |
| [Architecture](architecture.md) | System architecture, components, data flow, database schema |
| [API Documentation](api.md) | All endpoints, authentication, error codes |
| [Deployment Guide](deployment.md) | Setup, deployment, CI/CD, rollback procedures |
| [User Guide](user-guide.md) | Feature walkthrough, admin docs, FAQ |
| [Credentials & Access](credentials.md) | Service accounts, server access, third-party services |
| [Maintenance Guide](maintenance.md) | Monitoring, troubleshooting, scaling, backups |
| [BAST](bast.md) | Berita Acara Serah Terima / Formal handover certificate |

## How to Use This Package

1. Review all documents with your team
2. Fill in TBD/blank fields (warranty terms, credentials, signatures)
3. Walk through the deployment guide to verify accuracy
4. Complete the BAST with client signatures
5. Archive this documentation alongside the source code
```

### 4. Report

Print a summary when complete:

```
========================================
  Handover Documentation - Complete
========================================
  Project:     {PROJECT_NAME}
  Client:      {CLIENT_NAME}
  Output:      docs/handover/
  Documents:   9 files generated
  
  Files:
    - docs/handover/README.md
    - docs/handover/handover.md
    - docs/handover/architecture.md
    - docs/handover/api.md
    - docs/handover/deployment.md
    - docs/handover/user-guide.md
    - docs/handover/credentials.md
    - docs/handover/maintenance.md
    - docs/handover/bast.md
  
  Next Steps:
    1. Review each document for accuracy
    2. Fill in [TO BE AGREED] and blank fields
    3. Add screenshots to user-guide.md
    4. Complete BAST with client
========================================
```

### Rules

1. **Accuracy over completeness**: Only document what actually exists in the codebase. Leave sections empty with a note rather than fabricating content.
2. **No secrets**: NEVER include actual API keys, passwords, tokens, or connection strings. Only reference WHERE they are stored.
3. **Read before writing**: Always read the actual source files before generating documentation for them. Use Grep and Glob extensively.
4. **Use Mermaid**: Prefer Mermaid diagrams for architecture, data flow, and ER diagrams. They render in most markdown viewers.
5. **Bilingual BAST**: The BAST document must be bilingual (Indonesian/English) as it's a formal Indonesian document format.
6. **Parallel analysis**: Use Agent tool with subagent_type=Explore to analyze different aspects of the codebase in parallel for speed.
7. **Incremental writing**: Write each document as soon as its analysis is complete. Don't wait for all analysis to finish.
8. **Respect .gitignore**: Don't read files that are gitignored (except .env.example patterns).
