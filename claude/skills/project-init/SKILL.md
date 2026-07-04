---
name: project-init
description: "Scaffold a new client project (nextjs | go | python) with everything needed to start development immediately: verified scaffold order, mandatory website defaults (next-intl id/en + next-themes) for Aenoxa-ecosystem websites, quality tooling, Docker/CI, docs suite, secrets hygiene, and a blocking terminal verification gate. Use when the user wants to create a new project, initialize a repo, start a new app, or says /project-init."
argument-hint: "<project-name> <nextjs|go|python> [--internal]"
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

# Project Init - The Scaffold Executor

Scaffold a complete, ready-to-develop repository at `~/claude/Git/repositories/<project-name>/`.
This skill is the EXECUTOR of an already-decided project: it turns "we are building X on stack Y"
into a verified, committed, gate-passing repo. It does NOT do product discovery, design, or deploys.

Everything here is enforcement-driven: hard rules first, a toolchain preflight before any file is
written, blocking asserts after every phase, and a terminal verification gate (V1-V9) before the
skill is allowed to report success. Full per-stack recipes live in `references/`:

- `references/nextjs-recipe.md` - the complete verified Next.js 16 path (the money path)
- `references/go-python-recipes.md` - Go (toolchain-gated) + Python-on-uv paths
- `references/docs-templates.md` - all document templates (README, docs/, KANBAN, issue templates, audit.sh)

---

## 0. Boundary Charter - route FIRST, scaffold second

Before doing anything, confirm this request actually belongs here:

| Request smells like | Route to | Why |
|---|---|---|
| Pitch / demo / recruiter webapp, "deploy to <slug>.topengdev.com", Laurel/Bithour build | **/oneshot-webapp** | Different non-negotiables by design: light-only, NO next-themes, SAFE /frontend-design presets. Do NOT scaffold it here with website defaults - the two skills deliberately conflict. |
| Raw idea that still needs discovery, scoping, or a build plan | **/ideate** | project-init assumes the WHAT and the STACK are already decided. |
| UI/design work beyond the scaffold's health page | **/frontend-design** (or /artifex for high-variance) | Scaffold seeds tokens only; design decisions are not made here. |
| Committing | **/commit** | The ONLY commit path (seal-guard hook, PI-3). |
| "Will CI pass?" / pre-push readiness | **/preflight** | Owns the gate ladder G0-G9; this skill CITES its PF-6/PF-8/G9a mechanics. |
| Pushing / releasing | **/ship** | project-init never pushes. |
| Deploying a landing to aenoxa.com / VPS | **/deploy-landing** | Deploy mechanics live there. |
| Client handover docs for an EXISTING project | **/handover** | project-init writes day-0 docs for a NEW repo. |

**Triage context (house law):** a new standalone client repo is an **L3 trigger** in
`~/.claude/CLAUDE.md` (10-question gate + Toper sign-off before any worker spawns). This skill
normally runs INSIDE an already-triaged worker session - it does not replace the triage/3-tier
machinery. If you are main-session and this is a fresh client project with no `triage.json`,
STOP and run the triage protocol first.

---

## 1. PRIME HARD RULES (PI-1 .. PI-16)

**PI-1 - Scaffold order: create-next-app FIRST, tooling SECOND.** NEVER run
`npx create-next-app` into a directory containing anything beyond `.git/` and `.gitignore`.
It ABORTS on any other file ("contains files that could conflict" - live-reproduced 2026-07-03
with a pre-existing commitlint.config.js), and the abort message goes to STDOUT, so a scripted
flow can sail past it. Write commitlint/husky/tests/docs ONLY AFTER the scaffold assert (PI-2).

**PI-2 - ALWAYS assert the scaffold landed before continuing.**
`test -f package.json && grep -q '"next"' package.json` (nextjs) - on failure STOP and run
playbook PB-1. Equivalent asserts per stack: `test -f go.mod` (go), `test -f pyproject.toml`
(python). A missing assert here is how you end up "configuring" an empty directory.

**PI-3 - NEVER raw `git commit`. NEVER any AI-attribution trailer.** The seal-guard PreToolUse
hook (`~/.claude/hooks/block-raw-git-commit.sh`) denies raw commits (sentinel
`CLAUDE_COMMIT_SKILL=1` is carried by /commit) AND content-denies any message matching
`Co-Authored-By:.*(Claude|Anthropic|noreply@anthropic)` or `Generated with .*Claude Code` even
WITH the sentinel. ALWAYS commit via the **/commit skill** (Skill tool). In a client repo an AI
trailer is a double failure: hook denial here, embarrassment there. Cite: memory
`feedback_commit_skill_enforced`. On a host without the hook, the same message rules still apply.

**PI-4 - Website defaults from commit 0 (MANDATORY).** NEVER scaffold an Aenoxa-ecosystem
website/webapp/landing without **next-intl** (`id` DEFAULT + `en`) and **next-themes**
(light + dark + system) wired from the initial commit. The ONLY exceptions:
(a) explicitly-confirmed internal-only admin tools (`--internal` flag or mode-gate answer), and
(b) /oneshot-webapp territory (route away per §0 - light-only, no next-themes, BY DESIGN).
Verified failure 2026-05-24: Pulse landing v2 built English-only single-theme, rejected outright
("just kill the worker"). The scaffolder must not institutionalize that failure.

**PI-5 - NEVER write `"lint": "next lint"`.** `next lint` is REMOVED in Next 16 (and
`next build` no longer lints). create-next-app 16.2.10 generates `"lint": "eslint"` with an
eslint 9 flat config (`eslint.config.mjs`, defineConfig/globalIgnores) - KEEP it and EXTEND the
flat config; never invent scripts. CI runs `npm run lint` which resolves to eslint.

**PI-6 - Docker: standalone output + no lifecycle scripts.** NEVER ship the nextjs Dockerfile
without `output: 'standalone'` in next.config.ts (`.next/standalone` does not exist otherwise;
the COPY layer fails). NEVER let `npm ci` run lifecycle scripts in a Docker stage: husky v9's
`prepare` exits non-zero without `.git` - ALWAYS `npm ci --ignore-scripts` in the deps stage.

**PI-7 - Python runs on uv.** `pip install -D` is NOT a pip flag (npm-ism; pip errors).
The python path is: `uv init` / `uv add` / `uv add --dev` / `uv run` (uv 0.11.7 verified
installed). Never rely on venv activation persisting across Bash tool calls - `uv run` and
explicit `.venv/bin/<tool>` paths only.

**PI-8 - Dependency roles are not interchangeable.** zod is a RUNTIME dependency
(`npm install zod` - src/lib/env.ts imports it in prod builds), NEVER `-D`. prettier MUST be
explicitly installed (`npm install -D prettier`) if any script or lint-staged entry references
it - create-next-app 16 does NOT include it.

**PI-9 - Compromised-dependency denylist.** NEVER allow axios `1.14.1` or `0.30.4`; ANY
occurrence of `plain-crypto-js` in a lockfile = automatic FAIL (supply-chain malware, memory
`feedback_axios_supply_chain`). Mechanical check commands are owned by **/preflight PF-6 + G9a**
- cite them, run the V7 gate here, do not fork the logic.

**PI-10 - Secrets hygiene from day 0.** ALWAYS `chmod 600` any `.env` you create. NEVER put a
secret in a `NEXT_PUBLIC_*` var, client bundle, or Dockerfile layer. NEVER copy values out of
`~/.claude/secrets.env` (operator credential source, mode 600) into a repo. ALWAYS run gitleaks
(V6) BEFORE the initial commit. Only `.env.example` (placeholder values) is ever committed.

**PI-11 - No success report without the terminal gate.** NEVER declare the project initialized
until V1-V9 (§7) pass with evidence (exit codes + output snippets). The box-art report comes
AFTER the gate, never instead of it. BLOCKED/deferred gates must be listed with reasons.

**PI-12 - Toolchain preflight is fail-fast.** NEVER proceed with a stack whose toolchain fails
§3. Go is NOT installed on this box (verified 2026-07-03: `go`, `golangci-lint`, `govulncheck`
all absent) - report the install commands and STOP; do not improvise a Go scaffold you cannot
run, lint, or test.

**PI-13 - Placement + preservation.** Repo location is ALWAYS `~/claude/Git/repositories/<name>`
(verified dir). NEVER overwrite an existing `$PROJECT_DIR` - if it exists, STOP and ask. NEVER
leave placeholder brackets/TODOs in generated files (anti-slop, §10). NEVER generate files for a
stack that wasn't selected (a Go project has no package.json).

**PI-14 - One home for security headers; proxy.ts, not middleware.ts.** ALL security headers
live in ONE place: `next.config.ts` `headers()`. Next 16 renamed middleware.ts to `src/proxy.ts`
(nodejs runtime only; edge unsupported; codemod `middleware-to-proxy`) - scaffold `src/proxy.ts`
(it hosts the next-intl locale handling). Do NOT set the deprecated `X-XSS-Protection: 1;
mode=block`; do not ship contradictory duplicate headers (one X-Frame-Options policy, period).

**PI-15 - Healthcheck must point at a route that exists.** If any compose healthcheck references
a health URL, the route MUST exist for the stack: nextjs = `src/app/api/health/route.ts`
(healthcheck hits `/api/health`); go/python scaffold `/health` handlers. The locale matcher in
proxy.ts MUST exclude `/api` or the healthcheck gets locale-redirected.

**PI-16 - Respect the generated agent files.** create-next-app 16 emits `AGENTS.md` +
`CLAUDE.md` (containing `@AGENTS.md`). KEEP AGENTS.md; EXTEND the generated CLAUDE.md via
Read -> Edit (never blind-Write over it) with project commands/architecture/standards
(template block: `references/docs-templates.md` §8).

---

## 2. Invocation + Mode Gate

Parse `$ARGUMENTS`:

| Value | Rule |
|---|---|
| `PROJECT_NAME` | first arg, kebab-case. Missing -> STOP and ask. Never guess. |
| `TECH_STACK` | second arg, exactly one of `nextjs` / `go` / `python`. Anything else -> STOP, list the supported stacks, ask. |
| `--internal` | optional flag: pre-answers mode question Q1 as "internal admin tool". |
| `PROJECT_DIR` | always `~/claude/Git/repositories/$PROJECT_NAME` (PI-13). |

Then the **3-question mode gate** (house rule: Don't Assume - Ask). Skip a question only when
the invocation or brief already answers it unambiguously:

1. **What is this?** `client-facing website/webapp` | `internal-only admin tool` | `API service`.
   - Client-facing + nextjs -> **WEBSITE mode**: website defaults (PI-4) are mandatory, §6 gate applies.
   - Internal admin tool (`--internal`) -> **INTERNAL mode**: MAY ship en-only single-theme
     (i18n+themes still preferred if scope permits - say which was chosen in the report).
   - API service -> go/python (or nextjs API-only); website defaults N/A.
2. **Is this actually another skill's territory?** Pitch/demo/recruiter site -> /oneshot-webapp.
   Undiscovered idea -> /ideate. If yes: route away NOW (§0), do not scaffold.
3. **Placement + identity confirm:** repo path `~/claude/Git/repositories/$PROJECT_NAME` OK?
   For go: module path (default `github.com/TopengDev/$PROJECT_NAME` - CONFIRM, never assume the
   GitHub org for client work). For client repos: which GitHub org will own the remote?

Ambiguous answers = STOP and ask. A wrong-mode scaffold (e.g. next-themes on what turns out to
be a oneshot pitch demo) is a full restart.

---

## 3. Toolchain Preflight (blocking, before ANY file is written)

Run the stack's row + the shared row. ANY failure = STOP with the install hint (PI-12).
Record every version for the final report.

| Stack | Commands (all must succeed) | Local ground truth 2026-07-03 |
|---|---|---|
| nextjs | `node --version` (>= 20) · `npm --version` | node v22.16.0 (nvm), npm 10.9.2 |
| go | `command -v go golangci-lint govulncheck` | ALL ABSENT locally -> FAIL-FAST. Install: `sudo pacman -S go`; `go install golang.org/x/vuln/cmd/govulncheck@latest`; golangci-lint v2 per its install docs. Then re-run preflight. |
| python | `command -v uv` (preferred) else `python3 --version` (>= 3.12) | uv 0.11.7, python 3.14.5 |
| shared | `git --version` · `command -v jq` · `docker --version` (only if Docker phase runs) · `command -v gitleaks` · `command -v gh` (only if creating a GitHub repo) | git 2.54.0 (init.defaultBranch=main), jq /usr/bin/jq, docker 29.5.2, gitleaks 8.21.2, gh 2.67.0 |
| network | `npm ping` (nextjs; registry reachable) | If offline: FAIL preflight - NEVER hand-write a fake scaffold (PB-7). |

---

## 4. Phase Pipeline - nextjs (the primary worked path)

Full copy-paste file bodies: `references/nextjs-recipe.md`. This section is the ORDER + the
asserts. Every phase ends with its blocking assert; a failed assert stops the pipeline (fix via
§8 playbooks, then resume idempotently - §9).

### Phase 0 - Repository setup

```bash
PROJECT_DIR=~/claude/Git/repositories/$PROJECT_NAME
test -e "$PROJECT_DIR" && { echo "EXISTS - STOP (PI-13)"; }   # ask the user, never overwrite
mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
git init -b main        # explicit, config-independent
```

Do NOT create .gitignore/commitlint/anything else yet (PI-1). The directory must hold at most
`.git/` when Phase 1 runs.
**Assert:** `git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree` -> true.

### Phase 1 - Scaffold

```bash
cd "$PROJECT_DIR"
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir \
  --import-alias "@/*" --use-npm --yes
```

Flags verified against captured `--help` (16.2.10): `--ts/--typescript --tailwind --eslint
--biome --app --src-dir --import-alias --use-npm --yes --skip-install --disable-git
--agents-md(default) --react-compiler --rspack` exist; **`--turbopack` no longer exists**
(Turbopack is the default). If it prompts despite `--yes`, a required flag is missing - add the
flag it asked about and re-run non-interactively (PB-6), never answer prompts interactively.

What lands (live-verified 2026-07-03): next 16.2.10 + react 19.2.4, Tailwind v4
(`@tailwindcss/postcss`, `@theme inline` in globals.css), eslint 9 flat config, `"lint":
"eslint"`, NO `type: module`, NO prettier, `AGENTS.md` + `CLAUDE.md` (`@AGENTS.md`), tsconfig
`strict: true`, its own `.gitignore`, `public/` with svg assets.

**Assert (PI-2, blocking):**
```bash
test -f package.json && grep -q '"next"' package.json || echo "SCAFFOLD FAILED - PB-1"
```

### Phase 2 - Website defaults (WEBSITE mode; INTERNAL mode may skip per §2)

From commit 0, per PI-4. Full wiring: `references/nextjs-recipe.md` §3-§4.

```bash
npm install next-intl next-themes     # RUNTIME deps
```

- **i18n:** `src/i18n/routing.ts` (defineRouting, locales `['id','en']`, defaultLocale `'id'`),
  `src/i18n/navigation.ts`, `src/i18n/request.ts`, `src/proxy.ts` (createMiddleware(routing),
  matcher EXCLUDES `/api` - PI-15), move pages under `src/app/[locale]/`, `messages/id.json` +
  `messages/en.json` (real Bahasa Indonesia, key-parallel), translated `not-found`/error states,
  hreflang via `alternates.languages` metadata.
- **themes:** ThemeProvider wrapper (`attribute="class"`, `defaultTheme="system"`,
  `enableSystem`), `suppressHydrationWarning` on `<html>`, visible switcher (mounted-guard),
  CSS tokens in globals.css (Tailwind v4 `@theme inline` + `.dark` overrides +
  `@custom-variant dark`), persistence + no-FOUC via next-themes' injected script.

**Asserts (blocking):**
```bash
jq -e '.dependencies["next-intl"] and .dependencies["next-themes"]' package.json
diff <(jq -r 'paths | join(".")' messages/id.json | sort) \
     <(jq -r 'paths | join(".")' messages/en.json | sort)          # empty = key-parallel
test -s messages/id.json && test -s messages/en.json
```

### Phase 3 - Quality tooling

```bash
npm install zod                                   # RUNTIME (PI-8)
npm install -D vitest @testing-library/react @testing-library/jest-dom @vitejs/plugin-react jsdom
npm install -D husky lint-staged @commitlint/cli @commitlint/config-conventional prettier
npx husky init
echo 'npx lint-staged' > .husky/pre-commit
echo 'npx --no -- commitlint --edit "$1"' > .husky/commit-msg
chmod +x .husky/pre-commit .husky/commit-msg
```

- `commitlint.config.mjs` (**.mjs** - unambiguous ESM; the package has no `type: module`, a
  `.js` export-default config is loader-dependent).
- `vitest.config.ts` + `tests/setup.ts` + one real example test.
- `src/lib/env.ts` - zod **4** idioms (`z.url()`, not the zod-3 `z.string().url()`).
- `.prettierrc` + `.lintstagedrc.json` (eslint --fix + prettier).
- package.json scripts: KEEP generated `"lint": "eslint"` (PI-5); ADD `test`, `test:watch`,
  `test:coverage`, `type-check` (`tsc --noEmit`), `format`, `format:check`,
  `audit:deps` (`npm audit --omit=dev` - `--production` is the deprecated spelling).
- Extend `eslint.config.mjs` (flat config, defineConfig format) with the stricter rules; extend
  tsconfig with `noUncheckedIndexedAccess` + `forceConsistentCasingInFileNames`.

**Asserts:** `npx commitlint --print-config >/dev/null` exit 0 · `test -x .husky/pre-commit &&
test -x .husky/commit-msg` · `jq -e '.devDependencies.prettier' package.json`.

### Phase 4 - Hardening

- `next.config.ts`: `createNextIntlPlugin()` wrapper + `output: 'standalone'` (PI-6) +
  consolidated `headers()` (PI-14; modern set, no X-XSS-Protection, single X-Frame-Options,
  CSP comment block).
- `src/app/api/health/route.ts` returning `{status:'ok'}` (PI-15).
- Extend the generated `.gitignore` with the house additions (env files, coverage, .DS_Store).

**Asserts:** `grep -q "output: 'standalone'" next.config.ts` ·
`test -f src/app/api/health/route.ts`.

### Phase 5 - Docker + CI

- `Dockerfile`: multi-stage; deps stage `RUN npm ci --ignore-scripts` (PI-6); runner copies
  `.next/standalone` + `.next/static` + `public/`; non-root user.
- `docker-compose.yml` (dev) + `docker-compose.prod.yml` (healthcheck ->
  `http://localhost:3000/api/health`, resource limits, log rotation).
- `.github/workflows/ci.yml`: npm ci -> lint -> type-check -> test -> build (node 22, cache npm).

**Assert:** compose healthcheck URL matches the actual health route path (PI-15).

### Phase 6 - Documentation + project management

All templates: `references/docs-templates.md` (4-backtick fenced - copy the whole template).
Create: `README.md`, `docs/ARCHITECTURE.md`, `docs/API.md`, `docs/DEPLOYMENT.md`,
`CONTRIBUTING.md`, `KANBAN.md`, `.github/ISSUE_TEMPLATE/` (bug_report / feature_request /
change_request), `scripts/audit.sh` (+`chmod +x`), `.env.example`. EXTEND the generated
CLAUDE.md via Read -> Edit (PI-16). Anti-slop rules (§10) apply to every doc.

### Phase 7 - Secrets hygiene (before ANY commit)

```bash
cp .env.example .env && chmod 600 .env            # if a local .env is needed now (PI-10)
gitleaks dir . --no-banner --redact               # V6; `gitleaks detect` DOES NOT EXIST in 8.21.2 (preflight PF-8)
grep -rn 'plain-crypto-js' package-lock.json      # V7; must be EMPTY (PI-9, preflight G9a)
jq -r '.packages | to_entries[] | select(.key | endswith("node_modules/axios")) | .value.version' package-lock.json
# any axios result must NOT be 1.14.1 / 0.30.4
```

### Phase 8 - Commit + branches (via /commit ONLY)

1. Run the TERMINAL VERIFICATION GATE §7 first - the initial commit must be a green commit.
2. Invoke the **/commit skill** (Skill tool) with instructions: message
   `chore: initial project scaffolding` + a short body naming stack + versions; stage the full
   scaffold INCLUDING `package-lock.json` (CI's `npm ci` hard-fails without it; /commit skips
   lockfiles by default - tell it explicitly), EXCLUDING `.env`. No trailers of any kind (PI-3).
3. Verify: `git log --oneline -1` shows the commit; `git status --porcelain` has no stray
   unstaged source files.
4. `git checkout -b develop` - develop is the checked-out branch at the end, not main.

---

## 5. go / python paths (gated summaries)

Both live in full in `references/go-python-recipes.md`. Same pipeline shape: preflight (§3) ->
scaffold -> assert -> tooling -> hardening -> Docker/CI -> docs -> secrets -> /commit -> gate.

**go** - HARD GATE: the §3 go row currently FAILS on this box (no toolchain, verified
2026-07-03). Fail fast with install commands; NEVER improvise. When available: `go mod init
<confirmed-module-path>` (§2 Q3), stdlib `net/http` service layout (cmd/ + internal/), Makefile
with LITERAL app name (never `$(PROJECT_NAME)` - undefined Make var builds an empty binary
name), `.golangci.yml` in **v2 format** (`version: "2"`; the pre-v2 schema with
gosimple/typecheck enables is REJECTED by golangci-lint v2), `/health` handler + tests,
multi-stage Dockerfile (CGO_ENABLED=0, current stable golang:alpine image).

**python** - runs on uv (PI-7): `uv init --bare --name $PROJECT_NAME` -> `uv add fastapi
"uvicorn[standard]" pydantic pydantic-settings` -> `uv add --dev ruff mypy pytest pytest-cov
pytest-asyncio httpx` -> everything through `uv run`. The app layout is INTENTIONALLY
unpackaged (no `[build-system]`) - that sidesteps the setuptools "multiple top-level packages"
trap that broke the old `pip install -e .` flow; a library needs `uv init --package` instead
(recipe §P-1 documents the choice). Dockerfile copies source BEFORE anything imports it
(uv sync --frozen pattern). `/health` router + async httpx test.
Assert: `test -f pyproject.toml && test -f uv.lock`.

Website defaults (PI-4) are N/A for pure API services - both recipes note the boundary.

---

## 6. WEBSITE-DEFAULTS GATE (WEBSITE mode only - blocking)

Mirror of the CLAUDE.md checklist, verbatim. ALL seven must PASS before the build is "done":

- [ ] `messages/id.json` + `messages/en.json` populated for every section + form/error string
- [ ] `[locale]` routing works (`/id/...` + `/en/...`)
- [ ] `useTranslations` used everywhere - NO hardcoded user-facing English strings
- [ ] Light + dark themes both render polished
- [ ] Theme switcher accessible from nav
- [ ] Theme persists across page refresh
- [ ] No FOUC on theme load

Mechanical spot-checks (evidence for the report):

```bash
diff <(jq -r 'paths | join(".")' messages/id.json | sort) <(jq -r 'paths | join(".")' messages/en.json | sort)
grep -rn "useTranslations\|getTranslations" src/app | head -5        # in use
grep -rEn '>[A-Z][a-z]+ [a-z]+' src/app/\[locale\]/page.tsx || true  # hardcoded-string smell, review hits
```

Routing/theme behavior checks (dev server + curl `/id/`, `/en/`; theme toggling) need a running
app: run `npm run dev` in the background, curl both locale roots for HTTP 200, kill it. Full
visual verification (both themes polished, FOUC) is flagged "verify on first run" in the report
if not visually checked. Any FAIL = build NOT done (PI-4). If the gate cannot fully run, the
report says NOT DONE - never quietly downgrade to done.

---

## 7. TERMINAL VERIFICATION GATE (V1-V9 - blocking, before /commit and before the report)

Evidence = command + exit code (+ key output line). A row without evidence is invalid.
nextjs commands below; go/python variants in `references/go-python-recipes.md` §gate.

| Gate | Command (nextjs) | PASS criterion |
|---|---|---|
| V1 install | `npm install` (already run through phases) then `npm ls --depth=0` | exit 0, no missing/invalid deps |
| V2 lint | `npm run lint` | exit 0 |
| V3 types | `npx tsc --noEmit` | exit 0 |
| V4 tests | `npm test` (vitest run) | exit 0, all green |
| V5 build | `npm run build` (Bash timeout 600000; `free -h` first - preflight PF-15) | exit 0 |
| V6 secrets | `gitleaks dir . --no-banner --redact` | exit 0, zero findings (PI-10; never print a hit's value) |
| V7 denylist | Phase-7 greps (PI-9, cite /preflight PF-6/G9a) | plain-crypto-js absent; axios not 1.14.1/0.30.4 |
| V8 hooks | `npx commitlint --print-config >/dev/null` · `echo "bad message" \| npx commitlint` · `echo "chore: scaffold test" \| npx commitlint` · `test -x .husky/pre-commit` | config parses; bad msg REJECTED (non-zero); good msg accepted (0); hooks executable |
| V9 docker | `docker build -t $PROJECT_NAME:ci-test .` (timeout 600000) | exit 0 - OR explicitly DEFERRED with reason in the report (e.g. box under memory pressure). Deferral is visible, never silent. |

Plus §6 when in WEBSITE mode. **Any FAIL -> fix loop:** root-cause first (house override),
re-run the failed gate, then re-run V2-V5 (a fix can regress a sibling gate). Max 3 attempts per
distinct error signature; then STOP with a stuck-report (gate, error, attempts, hypotheses,
what's needed) - never report done, never weaken a gate to pass it.

---

## 8. Failure-Mode Playbooks

**PB-1 - create-next-app conflict abort.** Symptom: "The directory ... contains files that
could conflict" (STDOUT - easy to miss), PI-2 assert fails. Recovery: `ls -a` the dir; move
every non-allowlisted file out (`mv <file> /tmp/claude-*/`... use the session scratchpad);
re-run the scaffold; restore the files AFTER the PI-2 assert passes. Prevention: PI-1 ordering.
`.git/` and `.gitignore` are tolerated by create-next-app; nothing else is guaranteed to be.

**PB-2 - seal-guard denial.** Symptom: "BLOCKED: Use the /commit skill instead of raw 'git
commit'...". Recovery: do NOT retry raw, do NOT hand-add sentinels - invoke /commit (Skill
tool). If the message itself is rejected (AI-trailer content gate), strip the trailer and
retry via /commit. On a non-chilldawg host without the hook: follow the same message rules
anyway (PI-3).

**PB-3 - docker build failures.**
(a) `"/app/.next/standalone": not found` at a COPY layer -> `output: 'standalone'` missing in
next.config.ts (PI-6); add it, rebuild.
(b) `npm ci` fails in deps stage with a husky/prepare error (`.git can't be found` or husky
exit 1) -> deps stage lacks `--ignore-scripts` (PI-6); add it, rebuild.
(c) python: build backend "no packages found" / "Multiple top-level packages discovered" ->
source not copied before install, or a `[build-system]` table crept into the intentionally
unpackaged app layout (`references/go-python-recipes.md` §P-1/P-6); fix, rebuild.

**PB-4 - unhealthy prod container.** Healthcheck flapping/unhealthy: FIRST confirm the health
route exists for the stack and curl it from the host (`curl -fsS localhost:3000/api/health` for
nextjs) with the container running. Only then trust compose health status. NEVER "fix" by
deleting the healthcheck; fix the route or the URL (PI-15). Also check the proxy.ts matcher is
not swallowing `/api`.

**PB-5 - partial-failure re-entry.** Re-running after a mid-pipeline failure: NEVER `rm -rf`
and restart. Check what exists (`ls`, the phase asserts) and resume at the first failing
assert. Every phase is idempotent-by-construction: file writes overwrite identically; `npm
install` of an installed dep is a no-op; re-running `npx husky init` is safe.

**PB-6 - create-next-app prompts despite --yes.** A new required option was added upstream.
Read the prompt text, find the corresponding flag in `npx create-next-app@latest --help`, add
it explicitly, re-run. Never answer interactively (Bash tool prompts hang) and never downgrade
to an older create-next-app to dodge the prompt.

**PB-7 - offline / registry unreachable.** `npm ping` fails or installs time out. FAIL the §3
preflight and report. NEVER hand-write a fake scaffold (package.json + files without installed
node_modules) - it poisons every downstream gate.

---

## 9. Edge Cases

- **$PROJECT_DIR exists:** STOP, ask (PI-13). Even if it "looks empty" - hidden files break PI-1.
- **Monorepo requested:** out of scope for this skill's single-repo pipeline. STOP, ask - do not
  improvise a workspace layout.
- **Stack not in {nextjs, go, python}:** STOP, list supported stacks, ask. Do not "adapt" the
  nearest recipe to an unsupported stack.
- **Re-invocation on an already-initialized repo:** treat as PB-5 resume, not a fresh scaffold.
- **GitHub repo creation:** only if asked; `gh repo create` needs the §2 Q3 org answer first.
  Pushing is /ship's job.

---

## 10. Anti-Slop Rules (blocking, checked before the report)

- NO placeholder brackets `[value]` anywhere in generated files. Fill everything for the chosen
  stack.
- `TBD` is allowed ONLY in the two designated doc slots: Database decision and Auth decision
  (README/ARCHITECTURE tables). Anywhere else = not done.
- `messages/id.json` strings are REAL Bahasa Indonesia (natural register, the kind a Jakarta
  product would ship) - not machine-transliterated English, not lorem.
- README/docs name the ACTUAL installed versions (`jq -r '.dependencies.next' package.json`),
  never generic "Next.js 15" boilerplate.
- Design handoff note: scaffold seeds CSS token variables in globals.css only; ALL UI beyond the
  health page routes through /frontend-design (typography floors: weight >= 500, size >= 12px;
  no monospace unless the archetype's identity is mono). Do not seed component styles that
  violate the floors.
- Skill prose + generated copy: plain hyphens only, never em/en dashes.

---

## 11. Final Report (only after §7 passes)

```
╔══════════════════════════════════════════════════════╗
║                 PROJECT INITIALIZED                  ║
╠══════════════════════════════════════════════════════╣
║ Project:   <name>                                    ║
║ Stack:     <stack + key versions actually installed> ║
║ Mode:      WEBSITE / INTERNAL / SERVICE              ║
║ Location:  ~/claude/Git/repositories/<name>          ║
║ Branches:  main, develop (current)                   ║
╚══════════════════════════════════════════════════════╝
```

Followed by (all mandatory):
1. **Gate table** - V1-V9 (+§6 in WEBSITE mode), each row: command, exit code, evidence snippet,
   or DEFERRED + reason.
2. **Toolchain versions** recorded at §3 preflight.
3. **What was scaffolded** - file inventory by area (scaffold / i18n+themes / tooling /
   docker+ci / docs).
4. **Verify-on-first-run list** - anything not fully exercised (e.g. visual theme polish,
   CI on GitHub, docker if V9 deferred).
5. **Next steps** - cd, cp .env.example .env && chmod 600 .env, dev command, GitHub repo +
   push (via /ship).

---

## 12. Env-Facts Ledger (verified 2026-07-03 - re-check on drift)

| Fact | Value | Re-check |
|---|---|---|
| create-next-app@latest | 16.2.10; scaffolds next 16.2.10 + react 19.2.4, Tailwind v4, eslint 9 flat config, `lint: eslint`, AGENTS.md + CLAUDE.md, no prettier, no type:module | `npm view create-next-app version` |
| create-next-app flags | `--ts --tailwind --eslint --biome --app --src-dir --import-alias --use-npm --yes --skip-install --disable-git --agents-md --react-compiler --rspack`; NO `--turbopack` | `npx create-next-app@latest --help` |
| Conflict abort | any non-allowlisted file in target dir aborts scaffold, message on STDOUT (live-reproduced with commitlint.config.js) | scratch-dir repro |
| Next 16 removals/renames | `next lint` + eslint config option REMOVED (codemod `next-lint-to-eslint-cli`); middleware.ts -> proxy.ts (nodejs runtime only; codemod `middleware-to-proxy`) | context7 /vercel/next.js upgrade guide |
| Registry floors (floors, not pins) | next>=15.5.19 via @latest (16.2.10 now), react 19 (19.2.7 latest), zod 4 (4.4.3), next-intl 4.x (4.13.1), next-themes 0.4.x (0.4.6), vitest 4.1.9, husky 9.1.7, prettier 3.9.4, axios latest 1.18.1 (DENY 1.14.1/0.30.4) | `npm view <pkg> version` |
| Node toolchain | node v22.16.0 (nvm), npm 10.9.2; tsc NOT global (`npx tsc`) | `node --version` |
| Python | python3 3.14.5, uv 0.11.7 (`uv init/add/add --dev/run/sync/export` flags verified via --help); pip has NO `-D` flag | `uv --version` |
| ABSENT on this box | go, golangci-lint, govulncheck, pip-audit | `command -v go` |
| Shared tools | git 2.54.0 (init.defaultBranch=main; `git init -b main` works), docker 29.5.2, gh 2.67.0, jq /usr/bin/jq, prettier on PATH (nvm), gitleaks 8.21.2 (**no `detect` subcommand** - use `gitleaks dir` / `gitleaks git`, cite /preflight PF-8) | `--version` each |
| Seal-guard hook | LIVE in settings.json PreToolUse(Bash): denies raw `git commit`; content-denies AI trailers even with sentinel | memory `feedback_commit_skill_enforced` |
| House paths | `~/claude/Git/repositories/` exists (repo home); `~/.claude/secrets.env` mode 600 (operator creds - never copy into repos) | `ls -d`, `stat -c '%a'` |
| next-intl 4.x wiring | docs now show `src/proxy.ts` natively (createMiddleware(routing) default export + api-excluding matcher); request.ts uses `requestLocale` + `hasLocale` | context7 /amannn/next-intl |
| next-themes 0.4.x | ThemeProvider `attribute="class" defaultTheme="system" enableSystem`; `suppressHydrationWarning` on html; switcher needs mounted-guard | context7 /pacocoursey/next-themes |
| husky v9 in Docker | `prepare` fails without .git -> `npm ci --ignore-scripts` in deps stage | husky docs / PB-3b |
