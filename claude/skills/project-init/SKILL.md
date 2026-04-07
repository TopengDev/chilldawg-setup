---
name: project-init
description: Scaffold a new client project with everything needed to start development immediately. Use when the user wants to create a new project, initialize a repo, start a new app, or says /project-init.
argument-hint: <project-name> <tech-stack (nextjs|go|python)>
allowed-tools: Bash, Read, Glob, Grep, Edit, Write
---

Scaffold a complete, ready-to-develop project repository at `~/claude/Git/repositories/{project-name}/`.

Parse `$ARGUMENTS` into two required values:
- **PROJECT_NAME**: kebab-case project name (first argument)
- **TECH_STACK**: one of `nextjs`, `go`, `python` (second argument)

If either argument is missing, stop and ask the user. Do not guess.

Set these variables for use throughout:
```
PROJECT_NAME=<first arg>
TECH_STACK=<second arg>
PROJECT_DIR=~/claude/Git/repositories/$PROJECT_NAME
```

CRITICAL RULES:
- NEVER leave placeholder TODOs. Every file must be functional.
- NEVER overwrite an existing directory. If `$PROJECT_DIR` exists, stop and ask the user.
- NEVER commit secrets or .env files.
- All generated config must be valid and parseable. Test with a dry-run where possible.
- Adapt every file to the specific tech stack. Do not generate Node configs for a Go project.

---

### 1. Repository Setup

Create the repository and initialize git:

```bash
mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
git init
```

Create the initial branch structure:

```bash
git checkout -b main
# Initial commit will happen at the end after all files are written
```

Create `.gitignore` tailored to `$TECH_STACK`:

**For nextjs:**
```
node_modules/
.next/
out/
dist/
.env
.env.local
.env.*.local
*.tsbuildinfo
next-env.d.ts
.vercel
coverage/
.DS_Store
*.log
```

**For go:**
```
bin/
vendor/
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
.env
coverage.out
tmp/
.DS_Store
```

**For python:**
```
__pycache__/
*.py[cod]
*$py.class
*.so
.env
.venv/
venv/
dist/
build/
*.egg-info/
.eggs/
.mypy_cache/
.pytest_cache/
.ruff_cache/
htmlcov/
coverage.xml
.coverage
.DS_Store
```

Set up conventional commit config by creating a `commitlint.config.js` (nextjs) or equivalent:

**For nextjs:**
```js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor',
      'perf', 'test', 'build', 'ci', 'chore', 'revert'
    ]],
    'subject-max-length': [2, 'always', 72],
  },
};
```

**For go or python:** Create a `.commitlintrc.yml` with the same rules, or skip commitlint and document the conventional commit format in CONTRIBUTING.md instead.

---

### 2. Project Structure — Scaffold by Tech Stack

#### For nextjs:

Initialize the project with the Next.js App Router, TypeScript, Tailwind CSS, and ESLint:

```bash
cd "$PROJECT_DIR"
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --yes
```

After scaffolding, create these additional directories:

```bash
mkdir -p src/components src/lib src/hooks src/types src/styles
mkdir -p tests/unit tests/integration tests/e2e
mkdir -p docs scripts .github/workflows .github/ISSUE_TEMPLATE
```

Install dev dependencies:

```bash
npm install -D vitest @testing-library/react @testing-library/jest-dom @vitejs/plugin-react jsdom
npm install -D husky lint-staged @commitlint/cli @commitlint/config-conventional
npm install -D zod
```

Create `vitest.config.ts`:

```ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: ['node_modules/', 'tests/setup.ts'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

Create `tests/setup.ts`:

```ts
import '@testing-library/jest-dom/vitest';
```

Create `tests/unit/example.test.ts`:

```ts
import { describe, it, expect } from 'vitest';

describe('project setup', () => {
  it('should be properly configured', () => {
    expect(true).toBe(true);
  });
});
```

Create `src/lib/env.ts` — environment validation with zod:

```ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  NEXT_PUBLIC_APP_URL: z.string().url().default('http://localhost:3000'),
  DATABASE_URL: z.string().optional(),
  API_SECRET: z.string().min(1).optional(),
});

export const env = envSchema.parse(process.env);
export type Env = z.infer<typeof envSchema>;
```

Add scripts to `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "lint": "next lint",
    "type-check": "tsc --noEmit",
    "format": "prettier --write .",
    "format:check": "prettier --check .",
    "prepare": "husky",
    "audit:deps": "npm audit --production"
  }
}
```

Create `.lintstagedrc.json`:

```json
{
  "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
  "*.{json,md,yml,yaml}": ["prettier --write"]
}
```

Initialize husky and create pre-commit hook:

```bash
npx husky init
echo 'npx lint-staged' > .husky/pre-commit
echo 'npx --no -- commitlint --edit "$1"' > .husky/commit-msg
chmod +x .husky/pre-commit .husky/commit-msg
```

Update the existing ESLint config to add stricter rules. Read the existing config file first (`eslint.config.mjs` or `.eslintrc.*`), then add rules for:
- No unused variables (error)
- No explicit any (warn)
- Consistent return types

Create or update `.prettierrc`:

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100
}
```

Update `tsconfig.json` to enable strict mode — read the existing file and ensure these are set:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

Create `src/middleware.ts` with security headers:

```ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const response = NextResponse.next();

  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=()',
  );

  return response;
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
```

Create `next.config.ts` CORS / security headers — read the existing file and add:

```ts
const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
];
```

Add the headers to the existing Next.js config's `headers()` async function.

#### For go:

```bash
cd "$PROJECT_DIR"
go mod init github.com/christopher/$PROJECT_NAME
```

Create directories:

```bash
mkdir -p cmd/$PROJECT_NAME internal/{config,handler,middleware,model,repository,service}
mkdir -p pkg tests/unit tests/integration
mkdir -p docs scripts .github/workflows .github/ISSUE_TEMPLATE
```

Create `cmd/$PROJECT_NAME/main.go`:

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/christopher/$PROJECT_NAME/internal/config"
	"github.com/christopher/$PROJECT_NAME/internal/handler"
	"github.com/christopher/$PROJECT_NAME/internal/middleware"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)

	wrapped := middleware.Chain(mux,
		middleware.Logger,
		middleware.CORS(cfg.AllowedOrigins),
		middleware.SecurityHeaders,
	)

	addr := fmt.Sprintf(":%s", cfg.Port)
	log.Printf("starting server on %s", addr)
	if err := http.ListenAndServe(addr, wrapped); err != nil {
		log.Fatalf("server failed: %v", err)
		os.Exit(1)
	}
}
```

Create `internal/config/config.go`:

```go
package config

import (
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Port           string
	Env            string
	DatabaseURL    string
	AllowedOrigins []string
	APISecret      string
}

func Load() (*Config, error) {
	port := getEnv("PORT", "8080")
	env := getEnv("APP_ENV", "development")

	cfg := &Config{
		Port:           port,
		Env:            env,
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		AllowedOrigins: strings.Split(getEnv("ALLOWED_ORIGINS", "http://localhost:3000"), ","),
		APISecret:      os.Getenv("API_SECRET"),
	}

	if cfg.Env == "production" && cfg.APISecret == "" {
		return nil, fmt.Errorf("API_SECRET is required in production")
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
```

Create `internal/handler/health.go`:

```go
package handler

import (
	"encoding/json"
	"net/http"
)

func Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
```

Create `internal/middleware/middleware.go`:

```go
package middleware

import (
	"log"
	"net/http"
	"strings"
	"time"
)

type Middleware func(http.Handler) http.Handler

func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

func Logger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))
	})
}

func CORS(allowedOrigins []string) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")
			for _, allowed := range allowedOrigins {
				if strings.TrimSpace(allowed) == origin {
					w.Header().Set("Access-Control-Allow-Origin", origin)
					break
				}
			}
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			w.Header().Set("Access-Control-Max-Age", "86400")

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		next.ServeHTTP(w, r)
	})
}
```

Create `tests/unit/health_test.go`:

```go
package unit

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/christopher/$PROJECT_NAME/internal/handler"
)

func TestHealth(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	handler.Health(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
}
```

Create `Makefile`:

```makefile
.PHONY: build run test lint fmt audit

APP_NAME := $(PROJECT_NAME)
BUILD_DIR := bin

build:
	go build -o $(BUILD_DIR)/$(APP_NAME) ./cmd/$(APP_NAME)

run:
	go run ./cmd/$(APP_NAME)

test:
	go test ./... -v -race -coverprofile=coverage.out

lint:
	golangci-lint run ./...

fmt:
	gofmt -s -w .

audit:
	go vet ./...
	govulncheck ./...

coverage:
	go tool cover -html=coverage.out -o coverage.html
```

Create `.golangci.yml`:

```yaml
linters:
  enable:
    - errcheck
    - govet
    - staticcheck
    - unused
    - gosimple
    - ineffassign
    - typecheck
    - gofmt
    - goimports
    - misspell

linters-settings:
  errcheck:
    check-type-assertions: true
  govet:
    enable-all: true

run:
  timeout: 5m

issues:
  max-issues-per-linter: 50
  max-same-issues: 3
```

#### For python:

```bash
cd "$PROJECT_DIR"
python -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn pydantic pydantic-settings python-dotenv
pip install -D ruff mypy pytest pytest-cov pytest-asyncio httpx
```

Create directories:

```bash
mkdir -p src/{api,core,models,services,middleware}
mkdir -p tests/unit tests/integration
mkdir -p docs scripts .github/workflows .github/ISSUE_TEMPLATE
```

Create `pyproject.toml`:

```toml
[project]
name = "$PROJECT_NAME"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.32.0",
    "pydantic>=2.0.0",
    "pydantic-settings>=2.0.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "ruff>=0.8.0",
    "mypy>=1.13.0",
    "pytest>=8.0.0",
    "pytest-cov>=6.0.0",
    "pytest-asyncio>=0.24.0",
    "httpx>=0.28.0",
]

[tool.ruff]
target-version = "py312"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "S", "B", "A", "C4", "RUF"]
ignore = ["S101"]

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
addopts = "-v --cov=src --cov-report=term-missing"
```

Create `src/__init__.py`, `src/api/__init__.py`, `src/core/__init__.py`, `src/models/__init__.py`, `src/services/__init__.py`, `src/middleware/__init__.py`, `tests/__init__.py`, `tests/unit/__init__.py`, `tests/integration/__init__.py` — all empty files.

Create `src/core/config.py`:

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "$PROJECT_NAME"
    app_env: str = "development"
    port: int = 8000
    database_url: str = ""
    api_secret: str = ""
    allowed_origins: list[str] = ["http://localhost:3000"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
```

Create `src/main.py`:

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.core.config import settings
from src.api.health import router as health_router
from src.middleware.security import SecurityHeadersMiddleware

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
    max_age=86400,
)
app.add_middleware(SecurityHeadersMiddleware)

app.include_router(health_router)
```

Create `src/api/health.py`:

```python
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
```

Create `src/middleware/security.py`:

```python
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:  # type: ignore[no-untyped-def]
        response = await call_next(request)
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        return response
```

Create `tests/unit/test_health.py`:

```python
from httpx import ASGITransport, AsyncClient

from src.main import app


async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

Create `Makefile`:

```makefile
.PHONY: run test lint fmt type-check audit

run:
	uvicorn src.main:app --reload --port 8000

test:
	pytest

lint:
	ruff check .

fmt:
	ruff format .

type-check:
	mypy src/

audit:
	pip-audit
```

---

### 3. CI/CD

#### GitHub Actions Workflow

Create `.github/workflows/ci.yml`:

**For nextjs:**
```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - name: Lint
        run: npm run lint
      - name: Type Check
        run: npm run type-check
      - name: Test
        run: npm test
      - name: Build
        run: npm run build
```

**For go:**
```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - name: Vet
        run: go vet ./...
      - name: Test
        run: go test ./... -v -race
      - name: Build
        run: go build ./cmd/${{ github.event.repository.name }}
```

**For python:**
```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install dependencies
        run: |
          pip install -e ".[dev]"
      - name: Lint
        run: ruff check .
      - name: Type Check
        run: mypy src/
      - name: Test
        run: pytest
```

#### Docker

Create `Dockerfile`:

**For nextjs:**
```dockerfile
FROM node:22-alpine AS base

FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
```

**For go:**
```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/server ./cmd/$PROJECT_NAME

FROM alpine:3.20
RUN apk --no-cache add ca-certificates && adduser -D appuser
COPY --from=builder /bin/server /bin/server
USER appuser
EXPOSE 8080
CMD ["/bin/server"]
```

**For python:**
```dockerfile
FROM python:3.12-slim AS base
WORKDIR /app
COPY pyproject.toml ./
RUN pip install --no-cache-dir .

FROM base AS production
COPY src/ ./src/
RUN adduser --disabled-password --no-create-home appuser
USER appuser
EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Create `docker-compose.yml` (for local development):

```yaml
services:
  app:
    build: .
    ports:
      - "${PORT:-3000}:${PORT:-3000}"
    env_file: .env
    volumes:
      - .:/app
      - /app/node_modules  # nextjs only
    restart: unless-stopped

  # Uncomment and configure as needed:
  # db:
  #   image: postgres:16-alpine
  #   environment:
  #     POSTGRES_DB: ${DB_NAME:-app}
  #     POSTGRES_USER: ${DB_USER:-postgres}
  #     POSTGRES_PASSWORD: ${DB_PASSWORD:-postgres}
  #   ports:
  #     - "5432:5432"
  #   volumes:
  #     - pgdata:/var/lib/postgresql/data

# volumes:
#   pgdata:
```

Adjust the port mapping to match the tech stack (3000 for nextjs, 8080 for go, 8000 for python). Remove the node_modules volume line for go/python.

Create `docker-compose.prod.yml`:

```yaml
services:
  app:
    build:
      context: .
      target: production  # or runner for nextjs
    ports:
      - "${PORT:-3000}:${PORT:-3000}"
    env_file: .env
    restart: always
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:${PORT:-3000}/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Adjust ports and healthcheck URL to match the tech stack.

---

### 4. Documentation

Create `README.md`:

```markdown
# $PROJECT_NAME

Brief description of what this project does.

## Tech Stack

- **Runtime**: [Node.js 22 / Go 1.23 / Python 3.12]
- **Framework**: [Next.js 15 / stdlib / FastAPI]
- **Database**: TBD
- **Deployment**: Docker

## Quick Start

### Prerequisites

- [Node.js 22+ / Go 1.23+ / Python 3.12+]
- Docker & Docker Compose
- Git

### Setup

```bash
git clone <repo-url>
cd $PROJECT_NAME
cp .env.example .env
[npm install / go mod download / pip install -e ".[dev]"]
```

### Development

```bash
[npm run dev / make run / make run]
```

### Testing

```bash
[npm test / make test / make test]
```

### Building

```bash
docker compose build
docker compose up
```

## Project Structure

```
$PROJECT_NAME/
├── [src/ or cmd/ + internal/]  # Application code
├── tests/                       # Test suites
├── docs/                        # Documentation
├── scripts/                     # Utility scripts
├── .github/                     # CI/CD workflows
├── Dockerfile                   # Container build
├── docker-compose.yml           # Local development
└── docker-compose.prod.yml      # Production deployment
```

## Development Workflow

1. Create a feature branch from `develop`: `git checkout -b feat/your-feature develop`
2. Make changes and write tests
3. Run checks: `[npm run lint && npm run type-check && npm test / make lint && make test / make lint && make type-check && make test]`
4. Commit using conventional commits: `feat: add user authentication`
5. Open a PR against `develop`

## Deployment

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for the full deployment guide.
```

Fill in the brackets with the actual values for the chosen tech stack. Do not leave brackets in the final output.

Create `docs/ARCHITECTURE.md`:

```markdown
# Architecture

## Overview

High-level description of the system architecture.

## System Diagram

```
[Client] --> [API Gateway / Next.js] --> [Service Layer] --> [Database]
```

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | [Next.js / Go stdlib / FastAPI] | [Rationale] |
| Database | TBD | TBD |
| Auth | TBD | TBD |

## Data Flow

1. Request enters through the API layer
2. Middleware handles auth, CORS, security headers, logging
3. Handler validates input and delegates to service layer
4. Service layer contains business logic
5. Repository layer handles data persistence
6. Response is serialized and returned

## Directory Structure

Describe what each top-level directory contains and its responsibility.
```

Create `docs/API.md`:

```markdown
# API Documentation

## Base URL

- Development: `http://localhost:[3000/8080/8000]`
- Production: TBD

## Authentication

TBD — document auth mechanism here.

## Endpoints

### Health Check

`GET /health`

**Response** `200 OK`
```json
{
  "status": "ok"
}
```

### [Endpoint Name]

`[METHOD] /path`

**Headers**
| Header | Required | Description |
|--------|----------|-------------|
| Authorization | Yes | Bearer token |

**Request Body**
```json
{
  "field": "value"
}
```

**Response** `200 OK`
```json
{
  "data": {}
}
```

**Errors**
| Code | Description |
|------|-------------|
| 400 | Invalid request body |
| 401 | Unauthorized |
| 404 | Resource not found |
```

Create `docs/DEPLOYMENT.md`:

```markdown
# Deployment Guide

## Prerequisites

- Docker and Docker Compose installed on the target server
- Domain name configured with DNS pointing to the server
- SSL certificate (use Let's Encrypt / Caddy for automatic HTTPS)

## Environment Variables

Copy `.env.example` to `.env` and fill in production values:

```bash
cp .env.example .env
```

See `.env.example` for all required variables and their descriptions.

## Deploy with Docker Compose

```bash
# Build and start
docker compose -f docker-compose.prod.yml up -d --build

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Stop
docker compose -f docker-compose.prod.yml down
```

## Health Check

```bash
curl http://localhost:[PORT]/health
```

## Rollback

```bash
# Stop current version
docker compose -f docker-compose.prod.yml down

# Checkout previous version
git checkout <previous-tag>

# Rebuild and start
docker compose -f docker-compose.prod.yml up -d --build
```

## Monitoring

- Health endpoint: `GET /health`
- Application logs: `docker compose logs -f app`
```

Create `CONTRIBUTING.md`:

```markdown
# Contributing

## Code Style

- Follow the linter and formatter configurations in the repository
- Run `[npm run lint / make lint / make lint]` before committing
- All code must pass type checking

## Branch Naming

- `feat/short-description` — new features
- `fix/short-description` — bug fixes
- `docs/short-description` — documentation
- `refactor/short-description` — code refactoring
- `chore/short-description` — maintenance tasks

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional longer description.
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

## Pull Request Process

1. Create a branch from `develop`
2. Make your changes with tests
3. Ensure all checks pass locally
4. Open a PR against `develop`
5. Request review from at least one team member
6. Squash and merge after approval

## Testing

- Write tests for all new functionality
- Maintain or improve code coverage
- Run the full test suite before opening a PR
```

Fill in brackets with actual values for the tech stack.

---

### 5. CLAUDE.md

Create `CLAUDE.md` at the project root with project-specific content:

```markdown
# CLAUDE.md

## Project Overview

$PROJECT_NAME — [brief description]. Built with [tech stack details].

## Commands

[List all available commands for the specific tech stack, e.g.:]

### For nextjs:
- `npm run dev` — start development server
- `npm run build` — production build
- `npm run lint` — run ESLint
- `npm run type-check` — run TypeScript compiler check
- `npm test` — run tests with Vitest
- `npm run test:watch` — run tests in watch mode
- `npm run test:coverage` — run tests with coverage report
- `npm run format` — format code with Prettier
- `npm run format:check` — check formatting
- `npm run audit:deps` — audit production dependencies

### For go:
- `make run` — start development server
- `make build` — build binary
- `make test` — run tests with race detector
- `make lint` — run golangci-lint
- `make fmt` — format code
- `make audit` — vet + vulnerability check

### For python:
- `make run` — start development server with hot reload
- `make test` — run tests with coverage
- `make lint` — run ruff linter
- `make fmt` — format code with ruff
- `make type-check` — run mypy

## Architecture

- [Describe the directory layout and what goes where]
- [Describe the request lifecycle]
- [Describe the data layer when configured]

## Code Standards

- All code must pass lint and type-check before committing
- Write tests for new functionality
- Use conventional commits
- Keep functions focused and small
- Handle errors explicitly — do not swallow errors silently

## Environment

- Copy `.env.example` to `.env` for local development
- See `src/lib/env.ts` (nextjs) / `internal/config/config.go` (go) / `src/core/config.py` (python) for all environment variables and validation

## Deployment

- See `docs/DEPLOYMENT.md` for full deployment instructions
- Use `docker-compose.yml` for local development
- Use `docker-compose.prod.yml` for production
```

Only include the section relevant to the chosen tech stack. Do not include all three.

---

### 6. Environment and Project Management

Create `.env.example`:

**For nextjs:**
```bash
# Application
NODE_ENV=development
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Database (uncomment when configured)
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# API
# API_SECRET=your-secret-key-here
```

**For go:**
```bash
# Application
APP_ENV=development
PORT=8080

# Database (uncomment when configured)
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# API
# API_SECRET=your-secret-key-here

# CORS
ALLOWED_ORIGINS=http://localhost:3000
```

**For python:**
```bash
# Application
APP_ENV=development
PORT=8000

# Database (uncomment when configured)
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname

# API
# API_SECRET=your-secret-key-here

# CORS
ALLOWED_ORIGINS=["http://localhost:3000"]
```

Create `KANBAN.md`:

```markdown
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
```

#### Issue Templates

Create `.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
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
```

Create `.github/ISSUE_TEMPLATE/feature_request.md`:

```markdown
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
```

Create `.github/ISSUE_TEMPLATE/change_request.md`:

```markdown
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
```

#### Dependency Audit Script

Create `scripts/audit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Dependency Audit ==="

# Detect tech stack and run appropriate audit
if [ -f "package.json" ]; then
    echo "Running npm audit..."
    npm audit --production 2>&1 || true
    echo ""
    echo "Checking for outdated packages..."
    npm outdated 2>&1 || true
elif [ -f "go.mod" ]; then
    echo "Running go vet..."
    go vet ./... 2>&1 || true
    echo ""
    echo "Checking for vulnerabilities..."
    if command -v govulncheck &> /dev/null; then
        govulncheck ./... 2>&1 || true
    else
        echo "govulncheck not installed. Install with: go install golang.org/x/vuln/cmd/govulncheck@latest"
    fi
elif [ -f "pyproject.toml" ]; then
    echo "Running pip-audit..."
    if command -v pip-audit &> /dev/null; then
        pip-audit 2>&1 || true
    else
        echo "pip-audit not installed. Install with: pip install pip-audit"
    fi
fi

echo ""
echo "=== Audit Complete ==="
```

Make it executable: `chmod +x scripts/audit.sh`

---

### 7. Create develop branch and initial commit

After all files are created:

```bash
cd "$PROJECT_DIR"
git add -A
git commit -m "$(cat <<'EOF'
chore: initial project scaffolding

Set up $PROJECT_NAME with complete development environment:
- $TECH_STACK project structure with health endpoint
- CI/CD pipeline (GitHub Actions)
- Docker setup for dev and production
- Pre-commit hooks and linting
- Security headers and CORS configuration
- Comprehensive documentation

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"

git checkout -b develop
```

---

### 8. Final Report

After everything is complete, output a summary:

```
╔══════════════════════════════════════════════╗
║           PROJECT INITIALIZED                ║
╠══════════════════════════════════════════════╣
║ Project:    $PROJECT_NAME                    ║
║ Stack:      $TECH_STACK                      ║
║ Location:   ~/claude/Git/repositories/$PROJECT_NAME ║
║ Branches:   main, develop (current)          ║
╠══════════════════════════════════════════════╣
║ NEXT STEPS:                                  ║
║ 1. cd ~/claude/Git/repositories/$PROJECT_NAME       ║
║ 2. cp .env.example .env                      ║
║ 3. [npm install / go mod download / ...]     ║
║ 4. [npm run dev / make run / ...]            ║
║ 5. Create GitHub repo and push               ║
╚══════════════════════════════════════════════╝
```

Adjust all lines to match the actual tech stack — no brackets in the output.

---

## Rules

- NEVER leave placeholder brackets like `[value]` in generated files. Fill in everything for the chosen stack.
- NEVER generate files for a stack that wasn't selected. A Go project should not have `package.json`.
- NEVER commit `.env` files. Only commit `.env.example`.
- NEVER skip the test setup. The test suite must run and pass out of the box.
- If `create-next-app` or `go mod init` or `pip install` fails, diagnose and fix — do not skip.
- If `$PROJECT_DIR` already exists, STOP and ask the user before proceeding.
- Always `chmod +x` any shell scripts.
- The `develop` branch must be checked out at the end, not `main`.
