# /qa — Detection matrix (runner + build resolution)

Depth behind SKILL.md §4.1. The compact table lives in the SKILL; this file carries the lockfile
resolution logic, monorepo recipes, hybrid tie-break, and the fallback interview.

All commands here are NON-mutating reads (ls/find/cat/jq). Detection never writes to the target.

---

## 1. Package-manager resolution by lockfile (JS/TS)

`package.json` alone does NOT tell you the runner. Resolve by lockfile — first present wins in this
priority (a repo can carry more than one; the lockfile that matches the committed workflow is the truth,
so prefer the one referenced in CI if ambiguous):

| Lockfile present | Package manager | Test | Build | Lint |
|---|---|---|---|---|
| `pnpm-lock.yaml` | pnpm | `pnpm test` / `pnpm exec vitest run` | `pnpm build` | `pnpm lint` |
| `bun.lockb` or `bun.lock` | bun | `bun test` / `bun run test` | `bun run build` | `bun run lint` |
| `yarn.lock` | yarn | `yarn test` | `yarn build` | `yarn lint` |
| `package-lock.json` | npm | `npm test` | `npm run build` | `npm run lint` |
| none | unknown | read `scripts.test`; ASK the user which PM | `scripts.build` | `scripts.lint` |

Confirm the actual script bodies (they override the defaults):
```bash
jq -r '.scripts | to_entries[] | "\(.key): \(.value)"' package.json 2>/dev/null
jq -r '.packageManager // "none"' package.json 2>/dev/null   # Corepack pin, if present — authoritative
```
`packageManager` (Corepack) is authoritative when present (`"pnpm@9.x"` etc.) — trust it over the
lockfile if they disagree, and flag the disagreement.

Christopher's stack is **pnpm-first** (nvm node v22.16.0) with **Bun** for some daemons — do not assume
npm.

---

## 2. Monorepo / workspace detection

Presence of ANY of these = a monorepo; scope to the changed/target package, don't run the whole graph
unless the user asks:

| Marker | Toolchain | Scoped run example |
|---|---|---|
| `pnpm-workspace.yaml` | pnpm workspaces | `pnpm --filter <pkg> test` |
| `turbo.json` | Turborepo | `pnpm turbo run test --filter=<pkg>` |
| `nx.json` | Nx | `pnpm nx test <project>` |
| `lerna.json` | Lerna | `pnpm lerna run test --scope <pkg>` |
| `workspaces` field in `package.json` | yarn/npm workspaces | `yarn workspace <pkg> test` / `npm test -w <pkg>` |

```bash
ls pnpm-workspace.yaml turbo.json nx.json lerna.json 2>/dev/null
jq -r '.workspaces // empty' package.json 2>/dev/null
```
Identify the target package from the user's ask or the `git diff` scope; QA that package + its direct
dependents, not the whole tree.

---

## 3. Non-JS ecosystems (extraction pointers)

- **Rust** (`Cargo.toml`): `cargo test` (or `cargo nextest run` if `nextest` is configured), `cargo build`,
  `cargo clippy`. Workspace: `[workspace]` in root `Cargo.toml` → `cargo test -p <crate>`.
- **Python** (`pyproject.toml`): resolve by lock — `uv.lock` → `uv run pytest`; `poetry.lock` →
  `poetry run pytest`; `Pipfile.lock` → `pipenv run pytest`; else `pytest`. Config:
  `[tool.pytest.ini_options]`, lint `[tool.ruff]`.
- **Go** (`go.mod`): `go test ./...`, `go build ./...`, `go vet ./...`.
- **Make** (`Makefile`): `grep -E '^(test|check|lint|build):' Makefile` for real target names.
- **Java**: Maven `pom.xml` → `mvn test`; Gradle `build.gradle`(`.kts`) → `gradle test` (or `./gradlew`).
- **C/C++**: `CMakeLists.txt` → configure then `ctest`; else `Makefile` targets.
- **PHP** (`composer.json`): `composer test` or `vendor/bin/phpunit`.
- **C#** (`*.csproj`/`*.sln`): `dotnet test`, `dotnet build`.
- **Ruby** (`Gemfile`): `bundle exec rspec` (or `rake test`).

---

## 4. Hybrid-repo tie-break

Two runnable ecosystems in one repo (common: a Rust/Go backend + a JS frontend, or `Cargo.toml` +
`package.json` for a WASM/napi crate) → **do NOT let "first match wins" silently pick one.**

Decision:
1. If the user named a target (feature, path, "the frontend") → scope to that ecosystem.
2. Else if `git diff --name-only HEAD~5` is dominated by one ecosystem's files → target that one, note it.
3. Else ASK: "This repo has both `<A>` and `<B>` — QA which, or both?"
4. If "both" → run each runner separately, report per-runner PASS/FAIL, and keep findings tagged by
   ecosystem.

Never merge two ecosystems' PASS/FAIL counts into one number.

---

## 5. Fallback interview (no config detected)

Ask, concisely:
1. "What language/framework is this, and what's the test runner command?"
2. "What's the build command?" (and lint, if any)
3. "Is there a running instance to QA against (URL), or should I build + run locally?" → feeds the §4.4
   env-classification gate.
4. "Any existing test suite/CI I should run first?"

Do not guess a runner from directory names — a wrong `npm test` on a pnpm repo poisons the functional
dimension's PASS/FAIL data (§4.1).
