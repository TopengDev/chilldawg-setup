# go + python recipes

Companion to SKILL.md §5. Same pipeline shape as the nextjs path: preflight -> scaffold ->
assert -> tooling -> hardening -> Docker/CI -> docs -> secrets -> /commit -> terminal gate.
Website defaults (PI-4) are N/A here - these are API-service recipes. If the request is
actually a client-facing WEBSITE, it belongs on the nextjs path (or route per SKILL.md §0).

---

# GO

## G-0. TOOLCHAIN GATE (blocking - read before anything else)

**Go is NOT installed on this box** (verified 2026-07-03: `command -v go golangci-lint
govulncheck` all empty). The §3 preflight FAILS here by design (PI-12). Report and STOP:

```
BLOCKED - go toolchain absent. To unblock:
  sudo pacman -S go                                          # Arch
  go install golang.org/x/vuln/cmd/govulncheck@latest
  # golangci-lint v2: install per its official install docs (binary install recommended;
  # verify with `golangci-lint version` - must be v2.x for the config below)
Then re-run /project-init.
```

NEVER improvise a Go scaffold you cannot compile, lint, or test - every file below is UNVERIFIED
on this box until the toolchain exists. Everything in this GO section is **[verify on first
run]** by definition.

## G-1. Module init (module path CONFIRMED at SKILL.md §2 Q3 - never guessed)

```bash
cd "$PROJECT_DIR"
go mod init <MODULE_PATH>        # e.g. github.com/TopengDev/$PROJECT_NAME - as confirmed
mkdir -p cmd/$PROJECT_NAME internal/{config,handler,middleware,model,repository,service}
mkdir -p pkg tests/unit tests/integration docs scripts .github/workflows .github/ISSUE_TEMPLATE
```

**Assert:** `test -f go.mod`.

`<MODULE_PATH>` below is a literal-substitution token: replace it in EVERY file at scaffold
time (imports do not interpolate shell variables).

## G-2. Source files

`cmd/$PROJECT_NAME/main.go`:

```go
package main

import (
	"fmt"
	"log"
	"net/http"

	"<MODULE_PATH>/internal/config"
	"<MODULE_PATH>/internal/handler"
	"<MODULE_PATH>/internal/middleware"
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
		log.Fatalf("server failed: %v", err) // log.Fatalf exits; no os.Exit after it
	}
}
```

`internal/config/config.go`:

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
	cfg := &Config{
		Port:           getEnv("PORT", "8080"),
		Env:            getEnv("APP_ENV", "development"),
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

`internal/handler/health.go`:

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

`internal/middleware/middleware.go`:

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
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		// X-XSS-Protection deliberately absent (deprecated - PI-14 rationale applies here too)
		next.ServeHTTP(w, r)
	})
}
```

`tests/unit/health_test.go`:

```go
package unit

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"<MODULE_PATH>/internal/handler"
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

## G-3. Makefile - LITERAL app name (the `$(PROJECT_NAME)` Make-var bug is why)

Substitute the real project name at scaffold time. `APP_NAME := $(PROJECT_NAME)` references an
UNDEFINED Make variable and silently builds `bin/` with an empty binary name.

```makefile
.PHONY: build run test lint fmt audit coverage

APP_NAME := my-actual-project-name    # LITERAL - substituted at scaffold time
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

## G-4. `.golangci.yml` - v2 format ONLY

golangci-lint v2 REJECTS the pre-v2 schema (no `version` key, `gosimple`/`typecheck` in
enable). v2: `gosimple` merged into `staticcheck`; `typecheck` is not a linter; formatters
moved to their own section.

```yaml
version: "2"

linters:
  default: standard        # errcheck, govet, ineffassign, staticcheck, unused
  enable:
    - misspell
  settings:
    errcheck:
      check-type-assertions: true
    govet:
      enable-all: true

formatters:
  enable:
    - gofmt
    - goimports

run:
  timeout: 5m
```

Validate on a box with the toolchain: `golangci-lint config verify` then `golangci-lint run`.

## G-5. `.gitignore`

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
coverage.html
tmp/
.DS_Store
```

## G-6. Dockerfile

```dockerfile
# Image tags: current stable at writing - re-check https://go.dev/dl/ before pinning older
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/server ./cmd/my-actual-project-name

FROM alpine:3.22
RUN apk --no-cache add ca-certificates && adduser -D appuser
COPY --from=builder /bin/server /bin/server
USER appuser
EXPOSE 8080
CMD ["/bin/server"]
```

(Substitute the literal cmd path. `go.sum` does not exist until the first external dep -
`COPY go.mod go.sum ./` fails without it; use `COPY go.* ./` for a zero-dep scaffold.)

## G-7. CI

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
          go-version: 'stable'
      - name: Vet
        run: go vet ./...
      - name: Test
        run: go test ./... -v -race
      - name: Build
        run: go build ./cmd/${{ github.event.repository.name }}
```

## G-8. Terminal gate variants (SKILL.md §7)

| Gate | go command |
|---|---|
| V1 | `go mod download` + `go mod verify` exit 0 |
| V2 | `golangci-lint run ./...` exit 0 |
| V3 | `go vet ./...` exit 0 |
| V4 | `go test ./... -race` exit 0 |
| V5 | `go build ./cmd/<name>` exit 0 |
| V6/V7 | same as nextjs (gitleaks dir; denylist N/A for Go modules - note it) |
| V8 | N/A unless commitlint was set up: for go, document conventional commits in CONTRIBUTING.md instead (carried house pattern) |
| V9 | `docker build` or DEFERRED + reason |

`.env.example` (go):

```bash
APP_ENV=development
PORT=8080
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname
# API_SECRET=change-me
ALLOWED_ORIGINS=http://localhost:3000
```

---

# PYTHON (on uv - PI-7)

uv 0.11.7 verified installed; every flag below verified via `uv --help` subcommand output
2026-07-03. There is NO `pip install -D` (that was the old skill's npm-ism bug). Never rely on
`source .venv/bin/activate` persisting between Bash tool calls - always `uv run <cmd>`.

## P-1. Scaffold

```bash
cd "$PROJECT_DIR"
uv init --bare --name "$PROJECT_NAME"     # pyproject.toml only; we own the layout
uv add fastapi "uvicorn[standard]" pydantic pydantic-settings
uv add --dev ruff mypy pytest pytest-cov pytest-asyncio httpx
mkdir -p src/{api,core,models,services,middleware} tests/unit tests/integration
mkdir -p docs scripts .github/workflows .github/ISSUE_TEMPLATE
touch src/__init__.py src/api/__init__.py src/core/__init__.py src/models/__init__.py \
      src/services/__init__.py src/middleware/__init__.py \
      tests/__init__.py tests/unit/__init__.py tests/integration/__init__.py
```

**Assert:** `test -f pyproject.toml && test -f uv.lock`.

DESIGN CHOICE (documents the old skill's packaging trap): this is an APPLICATION, not a
package. With `--bare` + no `[build-system]` table, uv never tries to build/install the project
itself, so setuptools auto-discovery NEVER sees the "multiple top-level packages (src, tests)"
layout that broke `pip install -e .`. Imports are `from src.core.config import ...`, run from
the project root. If the project must later ship as a LIBRARY: re-init with
`uv init --package` (src-layout + build-system) instead - do not bolt packaging onto this
layout.

## P-2. `pyproject.toml` - merge tool config into what uv generated

uv owns `[project]` (+ `dependencies`) and `[dependency-groups] dev` - do not hand-edit those
lists (use `uv add`/`uv remove`). APPEND the tool sections:

```toml
[tool.ruff]
target-version = "py312"     # match requires-python floor
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "S", "B", "A", "C4", "RUF"]
ignore = ["S101"]            # assert is fine in tests

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

Set `requires-python = ">=3.12"` in `[project]` (floor, not pin - local is 3.14.5).

## P-3. Source files

`src/core/config.py`:

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "my-actual-project-name"   # literal, substituted at scaffold time
    app_env: str = "development"
    port: int = 8000
    database_url: str = ""
    api_secret: str = ""
    allowed_origins: list[str] = ["http://localhost:3000"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
```

`src/main.py`:

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.health import router as health_router
from src.core.config import settings
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

`src/api/health.py`:

```python
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
```

`src/middleware/security.py`:

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
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        # X-XSS-Protection deliberately absent (deprecated)
        return response
```

`tests/unit/test_health.py`:

```python
from httpx import ASGITransport, AsyncClient

from src.main import app


async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

## P-4. Makefile (everything through uv run)

```makefile
.PHONY: run test lint fmt type-check audit

run:
	uv run uvicorn src.main:app --reload --port 8000

test:
	uv run pytest

lint:
	uv run ruff check .

fmt:
	uv run ruff format .

type-check:
	uv run mypy src/

audit:
	uvx pip-audit
```

(pip-audit is NOT installed globally - `uvx pip-audit` runs it ephemerally via uv.)

## P-5. `.gitignore`

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

Commit `uv.lock` (it is the lockfile - CI's `--frozen` depends on it).

## P-6. Dockerfile - source copied BEFORE anything imports it **[verify on first run]**

```dockerfile
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY src/ ./src/

FROM python:3.13-slim AS production
WORKDIR /app
RUN adduser --disabled-password --no-create-home appuser
COPY --from=builder /app/.venv ./.venv
COPY --from=builder /app/src ./src
ENV PATH="/app/.venv/bin:$PATH"
USER appuser
EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Both stages MUST share the same python minor version (the venv records its interpreter path).
`--no-install-project` is correct here because the project is intentionally unpackaged (P-1).
Old-skill bug this replaces: `COPY pyproject.toml` + `pip install .` with zero source present.

## P-7. CI (deterministic - no unverified action pins)

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
          python-version: '3.13'
      - name: Install uv
        run: pip install uv
      - name: Sync (frozen)
        run: uv sync --frozen
      - name: Lint
        run: uv run ruff check .
      - name: Type check
        run: uv run mypy src/
      - name: Test
        run: uv run pytest
```

## P-8. Terminal gate variants (SKILL.md §7)

| Gate | python command |
|---|---|
| V1 | `uv sync --frozen` exit 0 |
| V2 | `uv run ruff check .` exit 0 |
| V3 | `uv run mypy src/` exit 0 |
| V4 | `uv run pytest` exit 0, all green |
| V5 | N/A (no build step) - `uv run python -c "from src.main import app"` as the import smoke |
| V6 | `gitleaks dir . --no-banner --redact` exit 0 |
| V7 | npm denylist N/A; run `uvx pip-audit` instead (advisory, WARN not FAIL on network flake - note in report) |
| V8 | N/A unless commitlint set up - document conventional commits in CONTRIBUTING.md (house pattern) |
| V9 | `docker build` or DEFERRED + reason |

`.env.example` (python; pydantic-settings parses the list as JSON):

```bash
APP_ENV=development
PORT=8000
# DATABASE_URL=postgresql://user:password@localhost:5432/dbname
# API_SECRET=change-me
ALLOWED_ORIGINS=["http://localhost:3000"]
```

---

# SHARED: docker-compose for go / python

Adapt ports per stack: go **8080**, python **8000**. Healthcheck path is `/health` (both stacks
scaffold that handler - PI-15). No node_modules volume line here (that was a nextjs-only hack in
the old skill, retired even there).

`docker-compose.yml` (dev smoke):

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"        # python: 8000:8000
    env_file: .env
    restart: unless-stopped

  # Uncomment when a database lands (also update .env + config):
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

`docker-compose.prod.yml`:

```yaml
services:
  app:
    build:
      context: .
      target: production      # go: the final unnamed stage - use `target: builder`-free build (omit target)
    ports:
      - "8080:8080"           # python: 8000:8000
    env_file: .env
    restart: always
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
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

Gotcha: the go Dockerfile's final stage is unnamed and the python one is named `production` -
either name the go final stage (`FROM alpine:3.22 AS production`) or drop the `target:` key.
Alpine-based images ship busybox `wget`; `python:slim` (Debian) does NOT - for python either
`apt-get install -y wget` in the final stage or use
`test: ["CMD", "python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"]`.
