# Preflight CI Recipes - per-stack gate commands

Companion to `../SKILL.md` section 2. The SKILL.md gate ladder shows the default
TS/Next path; this file carries the per-stack variants, the workflow-parsing recipes,
and the local-vs-CI divergence table. Every command here was verified on this box
2026-07-02 (or is explicitly marked BLOCKED-expected because the toolchain is absent).

House rules that apply to every recipe: PF-10 (pre-check `command -v` before running,
missing tool = BLOCKED never skip), PF-11 (any fix = full re-run), PF-15 (timeouts +
`free -h` for heavy builds).

---

## 1. Node - package manager detection first, always

NEVER assume npm. All four managers are installed on this box (npm 10.9.2,
pnpm 11.9.0, bun 1.3.12, yarn 1.22.22 classic), so the LOCKFILE decides:

| Lockfile present | Manager | Run scripts with |
|---|---|---|
| `package-lock.json` | npm | `npm run <script>` |
| `pnpm-lock.yaml` | pnpm | `pnpm <script>` |
| `bun.lock` or `bun.lockb` | bun | `bun run <script>` |
| `yarn.lock` | yarn classic | `yarn <script>` |

Tie-breakers, in order:
1. `jq -r '.packageManager // empty' package.json` (corepack field, authoritative)
2. What CI's workflow actually invokes (G1 parse) - mirror CI over local habit
3. More than one lockfile kind present = G9 FAIL (resolve before anything else)

### Gate commands per manager

```bash
# G2 lint - prefer the project's script, verify it exists first:
jq -r '.scripts.lint // empty' package.json
npm run lint        | pnpm lint        | bun run lint        | yarn lint
# fallback only if no script but an eslint config file exists:
npx eslint .

# G3 typecheck - from the nearest tsconfig.json directory:
npx tsc --noEmit    # pnpm exec tsc --noEmit / bunx tsc --noEmit also fine

# G5 tests - mirror what CI runs (vitest vs jest vs node:test):
npm test            | pnpm test        | bun run test        | yarn test
npx vitest run      # explicit runner forms when CI calls them directly
npx jest

# G6 build:
npm run build       | pnpm build       | bun run build       | yarn build

# G9b lockfile sync (verified non-mutating, exit 0 in-sync / 1 drift):
npm ci --dry-run
pnpm install --frozen-lockfile --lockfile-only
bun install --frozen-lockfile --lockfile-only
# yarn classic: `yarn install --frozen-lockfile` exists but REALLY INSTALLS
# (writes node_modules). No pure dry check in yarn 1.x. Flag before running,
# or treat sync as unverifiable (WARN) if an install is unacceptable.
```

npm test placeholder detection (script exists but is the init default):
```bash
jq -r '.scripts.test // empty' package.json | grep -q 'no test specified' && echo "N/A - placeholder"
```

### G9a denylist queries per lockfile format

```bash
# ANY lockfile - malware dep is an automatic FAIL wherever it appears:
grep -n 'plain-crypto-js' package-lock.json pnpm-lock.yaml bun.lock yarn.lock 2>/dev/null

# npm (lockfileVersion 2/3 - verified against a real v3 lockfile):
jq -r '.packages | to_entries[] | select(.key | endswith("node_modules/axios")) | .value.version' package-lock.json

# pnpm (packages keyed as name@version):
grep -nE 'axios@(1\.14\.1|0\.30\.4)' pnpm-lock.yaml

# bun (bun.lock is JSONC; keys quoted):
grep -nE '"axios@(1\.14\.1|0\.30\.4)' bun.lock

# yarn classic (resolved version on its own line under the axios block):
grep -nA2 '^axios@' yarn.lock | grep -nE 'version "(1\.14\.1|0\.30\.4)"'
```

---

## 2. Go - BLOCKED path expected on this box

Verified 2026-07-02: `go` and `golangci-lint` are NOT on PATH, while Go repos exist
(tx-engine, go-rest-api, svi_backend, attn-agnostic, go-cli-todo-app). On this box a
Go repo's G2/G3/G5/G6 gates land BLOCKED unless the toolchain gets installed. Never
fake a pass; report BLOCKED with the hint (`pacman -S go` or the repo's documented
toolchain, golangci-lint per its install docs) and let the user decide. Note that CI
still runs these checks with ITS OWN toolchain - a local BLOCKED does not predict CI
red, it predicts "cannot verify locally", which vetoes READY (PF-2).

When the toolchain IS present (re-check `command -v go golangci-lint` every run):
```bash
golangci-lint run ./...        # G2 (or `go vet ./...` if CI uses vet only)
go build ./...                 # G6 (also the closest thing to a Go typecheck; G3 = N/A)
go test ./...                  # G5
```
Match the CI go version (`grep -rn 'go-version' .github/workflows/` vs `go version`).

---

## 3. Python - venv-first resolution ladder

Verified 2026-07-02: ruff, flake8, pytest, poetry NOT on PATH; `uv` IS installed.
Python repos here: signal-trader, market-events, macro-news-scheduler,
forexfactory-scraper. Resolve tooling in THIS order, stop at the first hit:

1. **Project venv:** `ls .venv/bin/ 2>/dev/null` - run `./.venv/bin/pytest`,
   `./.venv/bin/ruff check .` directly. Also check `venv/bin/`.
2. **uv-managed:** if `pyproject.toml` (or `uv.lock`) exists: `uv run pytest`,
   `uv run ruff check .` (uv resolves the project environment itself).
3. **poetry:** only if `poetry.lock` exists AND `command -v poetry` passes
   (currently absent) - `poetry run pytest`.
4. **Nothing resolvable** = BLOCKED per tool, with the hint
   (`uv sync` to materialize the env, or the repo's own setup docs).

```bash
# G2 lint (whichever CI uses - read the workflow, don't guess):
./.venv/bin/ruff check .     | uv run ruff check .     | ./.venv/bin/flake8
# G3 typecheck (only if CI runs it):
uv run mypy .                | ./.venv/bin/mypy .
# G5 tests:
./.venv/bin/pytest           | uv run pytest
```
Lockfile sanity for Python (G9b analog): `uv.lock` / `poetry.lock` changed whenever
`pyproject.toml` dependency tables changed in the push range - WARN if not.

---

## 4. Docker-driven CI

Only relevant when the G1 parse shows CI building or running INSIDE containers.

- CI runs `docker compose run tests` (or similar): replicate THAT locally instead of
  bare commands - the container pins the toolchain versions CI actually uses. This
  supersedes the bare-command recipes above for the affected gates.
- CI runs `docker build` / `docker compose build`: run the same build locally as G6.
  PF-15 in full: `free -h` first, Bash timeout 600000 or run_in_background, never
  concurrent with another heavy build (verified OOM history, memory
  `reference_local_box_oom_heavy_workers`).
- CI does NOT build images: do not add a Docker gate just because a Dockerfile
  exists. Dockerfile-without-CI-build = the file is someone else's deploy concern.

docker 29.5.2 + compose plugin verified installed.

---

## 5. Monorepo / workspaces

Detection: `turbo.json`, `pnpm-workspace.yaml`, or a `workspaces` field in root
package.json (`jq -r '.workspaces // empty | if type=="object" then .packages[] else .[] end' package.json 2>/dev/null`).

- **turbo:** run gates via the runner so caching + graph order match CI:
  `npx turbo run lint typecheck test build` (use the exact task names from
  turbo.json; scope with `--filter=<pkg>` when CI scopes to changed packages).
- **pnpm workspaces (no turbo):** `pnpm -r lint` / `pnpm -r test` etc., or
  `pnpm --filter <pkg> <script>` scoped to packages the push range touches
  (`git diff --name-only "$UP..HEAD" | cut -d/ -f1-2 | sort -u` to find them).
- **npm/yarn workspaces:** `npm run <script> --workspaces --if-present`.
- Report WHICH packages were covered in the gate evidence - "lint PASS" on a
  monorepo without a package list is an invalid evidence row.
- G7/G8/G9 always run at the REPO root (one git history, one push range; lockfile
  lives at the root in every workspace flavor).

---

## 6. Workflow parsing (G1) - grep recipes, no yq dependency

```bash
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null

# Trigger block per file (bare `push:` with nothing nested = fires on ALL branches):
grep -n -A8 '^on:' <wf>

# Branch filters - compare against `git branch --show-current`:
grep -n -A4 'branches:' <wf>

# The actual commands CI runs (these define your gate list):
grep -nE '^\s*(run|uses):' <wf>

# Version matrix vs local:
grep -rn 'node-version' .github/workflows/     # vs node --version (v22.16.0 local)
grep -rn 'go-version' .github/workflows/
grep -rn 'python-version' .github/workflows/

# CI-only env vars / secrets -> known-divergence list in the report:
grep -rn 'secrets\.' .github/workflows/
```

Interpretation rules, verified against real repos on this box:
- chilldawg-setup `test-install.yml`: `on: push:` bare = fires on every branch.
- knnek-client `deploy.yml`: `on: push: branches: [main]` = fires ONLY on main; if
  the current branch is not main, that workflow's steps are NOT applicable gates
  (record as "workflow skipped: branch filter").
- `workflow_dispatch` / `schedule` / `pull_request`-only workflows never gate a push.
- A workflow whose steps reference `${{ secrets.* }}` can NEVER be fully replicated
  locally - run the replicable steps, list the rest as known divergence. Do not
  fabricate secret values to force a local run.

actionlint is NOT installed (verified) - do not claim workflow-syntax validation.

---

## 7. Local-vs-CI divergence table (why "green local" can still go red)

Include applicable rows in every report's known-divergence list:

| Divergence | Local behavior | CI behavior | Preflight coverage |
|---|---|---|---|
| Install mode | `npm install` silently repairs lockfile drift | `npm ci` / frozen hard-fails on drift | G9b frozen checks (this is the top cause) |
| Node version | v22.16.0 (nvm) | Whatever the matrix pins | G1 WARN on mismatch |
| Env vars / secrets | `~/.claude/secrets.env` sourced | `${{ secrets.* }}` only | G1 lists as divergence; not locally verifiable |
| Filesystem case | Linux here, case-sensitive | ubuntu-latest also case-sensitive | Parity on this box (mac devs would differ) |
| Timezone / locale | WIB (Asia/Jakarta) | UTC on runners | Flag if tests do date math without TZ pinning |
| Cache state | Warm node_modules, .next, turbo cache | Cold every run | For a truthful G6 on cache-suspect failures, remove build output dirs (project-local only) and rebuild |
| Concurrency | 18 CPUs, 14Gi shared with fleet | Dedicated runner | PF-15 memory guard |
| Docker layer cache | Warm local layers | Usually cold or remote cache | Docker G6 timing differs; result parity still holds |
