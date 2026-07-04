# /case-study evidence recipes (extended gathering)

Extended, per-situation recipes that back SKILL.md §2. Rules, gates, and the core gathering commands live in SKILL.md; this file only deepens the hunt. Everything here is read-only inspection: no repo mutation, no deploys, no SSH.

---

## 1. Per-stack gathering recipes

All are additive on top of the §2a-2e core pass. Commands are plain reads (cat/ls/find/grep/git); if a file doesn't exist, skip it, never invent its contents.

### Node / Next.js
```bash
cat package.json                      # deps + versions + scripts (versions are evidence)
cat next.config.* 2>/dev/null         # output: 'export'? i18n? images? tells the deploy story
ls messages/ 2>/dev/null              # i18n presence (id.json + en.json = bilingual claim evidence)
cat middleware.ts src/middleware.ts 2>/dev/null   # auth/locale routing surface
ls .github/workflows/ 2>/dev/null && cat .github/workflows/*.yml 2>/dev/null | head -40
cat Dockerfile docker-compose.y*ml 2>/dev/null
```
Claim fuel: framework versions, static-export vs server, i18n locales, CI presence, container story.

### Go
```bash
cat go.mod                            # module path + go version + deps
ls cmd/ internal/ pkg/ 2>/dev/null    # layout = architecture evidence
cat Makefile 2>/dev/null
grep -rIl -iE 'context\.|goroutine|sync\.|channel' --include=*.go . 2>/dev/null | head   # concurrency surface
```
Claim fuel: concurrency patterns actually used, module boundaries, build/release story.

### Python
```bash
cat pyproject.toml requirements.txt Pipfile 2>/dev/null
ls alembic/ migrations/ 2>/dev/null   # schema-migration discipline evidence
cat tox.ini pytest.ini setup.cfg 2>/dev/null
```
Claim fuel: dependency hygiene, migration discipline, test infrastructure.

### Monorepo
```bash
cat pnpm-workspace.yaml turbo.json lerna.json nx.json 2>/dev/null
ls packages/ apps/ 2>/dev/null
# per-package scale (honest about which package the claim is about):
for p in packages/*/ apps/*/; do echo "== $p"; (cd "$p" && cloc . 2>/dev/null | tail -3); done
```
Claim fuel: which package Christopher actually built (scope claims to it; don't absorb the whole monorepo's LOC into a personal claim).

---

## 2. Body-of-work evidence hunting (no single repo to `git log`)

For contribution-shaped subjects ("my BMS fitest QA work", "the orchestration tooling"). Every claim still needs a ledger row pointing at a SPECIFIC source.

| Evidence source | How to hunt | What it proves |
|---|---|---|
| Memory index | `~/.claude/memory/MEMORY.md` first, then follow to the named file (never guess filenames) | The why behind decisions, dated facts, verified failures |
| Task notes dirs | `ls -t ~/claude/notes/ \| head -30`, then read `STATE.md` / `report.md` / `brief.md` in the relevant dirs | What was actually done, when, with what outcome |
| Initiative files | `ls ~/claude/notes/initiatives/` (e.g. `dev-job-outreach.md`) | Multi-task arcs, decisions logs, success criteria |
| fitest artifacts | Suite/test counts via the fitest memories (start at the index; e.g. `reference_fitest_bms_authoring_standard.md`) | Scale of QA authoring work; counts stay `CHRISTOPHER` or memory-cited, never invented |
| Raw-material store | `~/claude/notes/portfolio-raw-material.md` (rule 6 gate applies to PRODUCTIZING, reading is fine) | Pre-digested problem/insight/why narratives |
| The live portfolio data | `~/claude/Git/repositories/christopher-portfolio/src/lib/data.ts` | What's already publicly claimed; keeps new claims consistent |

Ledger discipline for body-of-work: the "Evidence" cell names the exact file (`~/claude/notes/<dir>/report.md`, memory `<name>.md`), not "notes" generically. If the only source is Christopher's memory of it, status is `CHRISTOPHER` with the date.

---

## 3. Raw-material story map (rule 6: Toper-gated productizing)

`~/claude/notes/portfolio-raw-material.md` holds 3 consolidated stories, each already in problem / insight / why-portfolio-worthy shape (captured 2026-06-11, Wave-6; locked decision #26 = capture-only). **Productize ONLY when Christopher names the story in a direct /case-study invocation.** The map below exists so that when he DOES name one, the angle is ready.

| Story | The core thesis | Case-study angle | Strong `--for` fits |
|---|---|---|---|
| **W1: Liveness-armed deadman + out-of-band alerting + dotfiles-install CI** | Arm a watchdog only after observing ALIVE once; alert only on the alive-to-dead transition (separates "crashed" from "paused"); alert through a channel that is NOT the monitored one; CI that proves the install actually installs. Motivated by a real dated outage (wa-sender silently dead 26h). | Infra-resilience / self-healing-ops story with a crisp, generally-true engineering idea and a dated failure as the hook. | portfolio, linkedin |
| **W3: Multi-agent orchestration resilience kit** | Verify-before-marking resumable checkpoints; sentinel-guarded non-idempotent actions; self-pruning registry-intersect-live-windows semaphore (fail-open); structured result.json + read-only fleet cockpit; codified workflow library. | Production-grade agent-orchestration reliability: a hot, under-served space; the "crash-consistent journaling for agents" analogy carries the narrative. | portfolio, github (if the tooling is ever public), application (AI-infra roles) |
| **W5: Leak-safe secrets-parity gate + format-aware encryption selection** | Prove an encrypted-secrets cutover decrypts byte-identically WITHOUT printing a secret (per-var sha256 in a clean subshell, report only mismatched names, length-tag low-entropy values); whole-file `age` over `sops`-dotenv (which mis-parses `export VAR=` files and leaks var names). | Security-engineering signal: "verify a risky migration is identity-preserving without exposing the payload" generalizes to any secret/PII cutover; the sops-vs-age lesson is sharp and counter-intuitive. | portfolio, application (security-leaning roles), linkedin |

Notes:
- The store is also tracked as idle-backlog item LS-4 and pointed to by memory `reference_portfolio_raw_material`.
- Story details (the exact mechanisms, the dated failures) come from the store file itself at run time; re-read it, don't trust this summary as the source.
- These stories are about Christopher's own infra: the §3 privacy pass still applies (no internal hostnames, no JIDs, no secret names).
