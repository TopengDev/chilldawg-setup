# docs templates

Companion to SKILL.md Phase 6. Every template sits in a 4-backtick fence so inner ```bash/json
blocks stay intact (the old skill's 3-backtick nesting corrupted template boundaries) - copy
everything INSIDE the 4-backtick fence.

Anti-slop rules (SKILL.md §10) apply: fill every bracket for the chosen stack, `TBD` survives
ONLY in the Database and Auth decision slots, name the ACTUAL installed versions
(`jq -r '.dependencies.next' package.json` etc.), and never emit sections for unselected stacks.

---

## 1. README.md

````markdown
# <project-name>

<One real sentence: what this project does and for whom.>

## Tech Stack

- **Runtime**: <Node 22 / Go <version> / Python 3.14 via uv>
- **Framework**: <Next.js <actual version> / net/http stdlib / FastAPI <actual version>>
- **i18n / theming**: <next-intl (id default, en) + next-themes light/dark/system | n/a (internal tool) | n/a (API service)>
- **Database**: TBD
- **Deployment**: Docker

## Quick Start

### Prerequisites

- <Node.js 22+ / Go toolchain / uv>
- Docker & Docker Compose
- Git

### Setup

```bash
git clone <repo-url>
cd <project-name>
cp .env.example .env && chmod 600 .env
<npm install / go mod download / uv sync>
```

### Development

```bash
<npm run dev / make run / make run>
```

### Testing

```bash
<npm test / make test / make test>
```

### Container build

```bash
docker compose build
docker compose up
```

## Project Structure

```
<project-name>/
├── <src/ or cmd/ + internal/>   # Application code
├── tests/                       # Test suites
├── docs/                        # Documentation
├── scripts/                     # Utility scripts
├── .github/                     # CI/CD workflows
├── Dockerfile                   # Container build
├── docker-compose.yml           # Local container smoke
└── docker-compose.prod.yml      # Production deployment
```

## Development Workflow

1. Branch from `develop`: `git checkout -b feat/your-feature develop`
2. Make changes and write tests
3. Run checks: <the stack's lint + type-check + test commands>
4. Commit using conventional commits: `feat: add user authentication`
5. Open a PR against `develop`

## Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).
````

---

## 2. docs/ARCHITECTURE.md

````markdown
# Architecture

## Overview

<High-level description of the system - 3-5 real sentences about THIS project.>

## System Diagram

```
[Client] --> [<Next.js app / API service>] --> [Service layer] --> [Database (TBD)]
```

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | <actual framework + version> | <real rationale> |
| i18n | <next-intl, id default / n/a> | <house default / internal tool> |
| Theming | <next-themes light+dark+system / n/a> | <house default / internal tool> |
| Database | TBD | TBD |
| Auth | TBD | TBD |

## Data Flow

1. Request enters through the <proxy/API> layer
2. Middleware handles <locale routing (nextjs) / auth, CORS>, security headers, logging
3. Handler validates input and delegates to the service layer
4. Service layer contains business logic
5. Repository layer handles data persistence
6. Response is serialized and returned

## Directory Structure

<Describe what each top-level directory contains for THIS stack - no generic filler.>
````

---

## 3. docs/API.md

````markdown
# API Documentation

## Base URL

- Development: `http://localhost:<3000/8080/8000>`
- Production: TBD

## Authentication

TBD - document the auth mechanism when it lands (see ARCHITECTURE.md decision table).

## Endpoints

### Health Check

`GET <//api/health (nextjs) | /health (go, python)>`

**Response** `200 OK`
```json
{
  "status": "ok"
}
```

<!-- Template for real endpoints as they land:

### <Endpoint Name>

`<METHOD> /path`

**Headers**
| Header | Required | Description |
|--------|----------|-------------|
| Authorization | Yes | Bearer token |

**Request Body**
```json
{ "field": "value" }
```

**Response** `200 OK`
```json
{ "data": {} }
```

**Errors**
| Code | Description |
|------|-------------|
| 400 | Invalid request body |
| 401 | Unauthorized |
| 404 | Resource not found |
-->
````

---

## 4. docs/DEPLOYMENT.md

````markdown
# Deployment Guide

## Prerequisites

- Docker and Docker Compose on the target server
- Domain DNS pointing at the server
- TLS (Let's Encrypt via certbot/nginx, or Caddy)

## Environment Variables

```bash
cp .env.example .env
chmod 600 .env        # always - secrets hygiene
```

Fill production values. See `.env.example` for every variable. Secrets are server-side only -
never in client bundles or image layers.

## Deploy with Docker Compose

```bash
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml logs -f
docker compose -f docker-compose.prod.yml down
```

## Health Check

```bash
curl -fsS http://localhost:<PORT></api/health | /health>
```

The prod compose healthcheck hits the same route - if `docker ps` shows unhealthy, curl the
route from the host FIRST (see the skill's PB-4 playbook: fix the route or URL, never delete
the healthcheck).

## Rollback

```bash
docker compose -f docker-compose.prod.yml down
git checkout <previous-tag>
docker compose -f docker-compose.prod.yml up -d --build
```

## Monitoring

- Health endpoint (above)
- `docker compose -f docker-compose.prod.yml logs -f app`
````

---

## 5. CONTRIBUTING.md

````markdown
# Contributing

## Code Style

- Follow the linter and formatter configurations in the repository
- Run <the stack's lint command> before committing
- All code must pass type checking

## Branch Naming

- `feat/short-description` - new features
- `fix/short-description` - bug fixes
- `docs/short-description` - documentation
- `refactor/short-description` - code refactoring
- `chore/short-description` - maintenance tasks

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional longer description.
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

<nextjs: commit messages are enforced by commitlint via the commit-msg hook.>
<go/python: no commitlint is wired - the format above is the enforced convention in review.>

## Pull Request Process

1. Branch from `develop`
2. Make changes with tests
3. Ensure all checks pass locally
4. Open a PR against `develop`
5. Request review from at least one team member
6. Squash and merge after approval

## Testing

- Write tests for all new functionality
- Maintain or improve coverage
- Run the full suite before opening a PR

<website projects: every user-facing string goes in BOTH messages/id.json and messages/en.json -
the i18n parity test fails otherwise.>
````

---

## 6. KANBAN.md

````markdown
# Project Board

## Backlog

- [ ] Set up database and ORM/driver
- [ ] Implement authentication
- [ ] Create core API endpoints
- [ ] Set up error tracking (Sentry)
- [ ] Configure production logging
- [ ] Set up monitoring and alerts

## Phase 1: Foundation (Current)

- [x] Project scaffolding
- [x] CI/CD pipeline
- [x] Docker setup
- [x] Health check endpoint
- [ ] Database integration
- [ ] Authentication system

## Phase 2: Core Features

- [ ] Core business logic
- [ ] API endpoints
- [ ] Input validation
- [ ] Error handling
- [ ] Integration tests

## Phase 3: Production Readiness

- [ ] Performance optimization
- [ ] Security audit
- [ ] Load testing
- [ ] Documentation review
- [ ] Staging deployment
- [ ] Production deployment

## Done

- [x] Repository initialized
- [x] Development environment configured
- [x] Documentation created
````

---

## 7. Issue templates (.github/ISSUE_TEMPLATE/)

`bug_report.md`:

````markdown
---
name: Bug Report
about: Report a bug
labels: bug
---

## Description

A clear description of the bug.

## Steps to Reproduce

1. Step one
2. Step two
3. Step three

## Expected Behavior

What should happen.

## Actual Behavior

What actually happens.

## Environment

- OS:
- Version:
- Browser (if applicable):
````

`feature_request.md`:

````markdown
---
name: Feature Request
about: Suggest a new feature
labels: enhancement
---

## Description

A clear description of the feature.

## Motivation

Why is this feature needed? What problem does it solve?

## Proposed Solution

Describe the solution you'd like.

## Alternatives Considered

Any alternative solutions or features you've considered.
````

`change_request.md`:

````markdown
---
name: Change Request
about: Request a change to existing functionality
labels: change-request
---

## Current Behavior

How the feature currently works.

## Desired Behavior

How it should work after the change.

## Rationale

Why this change is needed.

## Impact

What parts of the system are affected by this change.
````

---

## 8. CLAUDE.md extension block (nextjs: APPEND to the GENERATED file via Read -> Edit - PI-16;
go/python: create fresh with this content)

````markdown
## Project Overview

<project-name> - <one real sentence>. Built with <actual stack + versions>.

## Commands

<ONLY the chosen stack's commands - verified against package.json scripts / Makefile targets:>
<nextjs: npm run dev · npm run build · npm run lint (eslint) · npm run type-check · npm test ·
npm run test:coverage · npm run format · npm run audit:deps>
<go: make run · make build · make test · make lint · make fmt · make audit>
<python: make run · make test · make lint · make fmt · make type-check · make audit>

## Architecture

- <Directory layout and what goes where - THIS project's, not generic>
- <Request lifecycle: proxy/middleware -> handler -> service -> repository>
- <i18n: [locale] routing, messages/{id,en}.json, id is default (website projects)>

## Code Standards

- All code must pass lint and type-check before committing
- Write tests for new functionality
- Conventional commits (enforced by commitlint on nextjs)
- Website projects: no hardcoded user-facing strings - useTranslations/getTranslations +
  messages/{id,en}.json, both locales together
- Handle errors explicitly - never swallow them

## Environment

- `cp .env.example .env && chmod 600 .env`
- Validation lives in <src/lib/env.ts / internal/config/config.go / src/core/config.py>
- Secrets are server-side only: never NEXT_PUBLIC_, never committed, never in image layers

## Deployment

- `docs/DEPLOYMENT.md` for the full guide
- `docker-compose.yml` local smoke / `docker-compose.prod.yml` production
````

---

## 9. scripts/audit.sh (chmod +x after writing)

````bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Dependency Audit ==="

if [ -f "package.json" ]; then
    echo "Running npm audit..."
    npm audit --omit=dev 2>&1 || true
    echo ""
    echo "Compromised-dep denylist (house rule - see /preflight PF-6/G9a):"
    if grep -n 'plain-crypto-js' package-lock.json 2>/dev/null; then
        echo "FAIL: plain-crypto-js found (supply-chain malware)"; exit 1
    fi
    AXIOS_VERSIONS=$(jq -r '.packages | to_entries[] | select(.key | endswith("node_modules/axios")) | .value.version' package-lock.json 2>/dev/null || true)
    if echo "$AXIOS_VERSIONS" | grep -qE '^(1\.14\.1|0\.30\.4)$'; then
        echo "FAIL: compromised axios version pinned"; exit 1
    fi
    echo "denylist clean"
    echo ""
    echo "Checking for outdated packages..."
    npm outdated 2>&1 || true
elif [ -f "go.mod" ]; then
    echo "Running go vet..."
    go vet ./... 2>&1 || true
    echo ""
    if command -v govulncheck &> /dev/null; then
        govulncheck ./... 2>&1 || true
    else
        echo "govulncheck not installed: go install golang.org/x/vuln/cmd/govulncheck@latest"
    fi
elif [ -f "pyproject.toml" ]; then
    echo "Running pip-audit via uvx..."
    if command -v uv &> /dev/null; then
        uvx pip-audit 2>&1 || true
    else
        echo "uv not installed - see https://docs.astral.sh/uv/"
    fi
fi

echo ""
echo "=== Audit Complete ==="
````
