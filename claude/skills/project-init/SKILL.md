---
name: project-init
description: "Scaffold a new AGENT-ORG project workspace at ~/claude/projects/<slug>/ per the agent-org geometry: project CLAUDE.md (project rules), manager/CLAUDE.md (project-supervisor role + physically-included orchestrator rules), repo/ (new codebase, the worker cwd) or REPO.md (pointer to an existing repo), STATE.md, vision/goals/milestones, and tasks/ research/ docs/. This is the FRONT DOOR main runs the moment Christopher agrees to a project, BEFORE spawning the supervisor. It scaffolds the ORG WORKSPACE; filling repo/ with a language stack is delegated to the codebase scaffolder. Use when the user says /project-init, agrees to start a new project, or main needs to initiate a project."
argument-hint: "<slug> [--new-repo | --repo <existing-repo-name>] [--title \"<Human Title>\"]"
allowed-tools: Bash, Read, Glob, Grep, Edit, Write, Skill
---

# project-init - Agent-Org Project Workspace Scaffolder

Turn "Christopher agreed to project X" into a geometry-correct, resumable project
workspace at `~/claude/projects/<slug>/` that a supervisor can immediately own and
that a worker can immediately execute in with the correct rule set loaded.

This is the AGENT-ORG front door (SPEC.md sec 2, 3, 8). It does NOT do product
discovery (that is /ideate), design (/frontend-design, /artifex), deploys
(/deploy-landing, /oneshot-webapp), or the LANGUAGE-STACK scaffold of the codebase
(that is the codebase scaffolder, see sec 6). It builds the ORG WORKSPACE and the
CLAUDE.md geometry, then STOPS and hands the next step (spawn the supervisor) back
to the caller.

Design source of truth: `~/claude/projects/agent-org/SPEC.md` (sec 2 layout, sec 3
scope map + geometry proof, sec 8 project init) and `CUTOVER.md`. Read them if any
of the geometry below is unclear.

---

## 0. What it produces (the create-list, for slug `<slug>`)

```
~/claude/projects/<slug>/
  CLAUDE.md              PROJECT rules (vision / hard-constraints / tech-stack / guardrails).
                         Loaded by the supervisor AND workers. MUST NOT contain
                         orchestrator / main-only / vps rules (see PIP-2).
  manager/
    CLAUDE.md            SUPERVISOR role + the PHYSICALLY-INCLUDED orchestrator rules
                         (byte-identical copy of ~/claude/shared/orchestrator.md inside
                         BEGIN/END markers). Loaded ONLY by the supervisor.
  repo/                  NEW codebase = the worker cwd (git-init'd). MUTUALLY EXCLUSIVE
                         with REPO.md.
    OR
  REPO.md                Pointer to an EXISTING codebase at {{REPOS_DIR}}/<repo> (+ the
                         geometry note + worktree option). MUTUALLY EXCLUSIVE with repo/.
  STATE.md               DURABLE resume anchor for the whole project (supervisor maintains).
  vision.md              Full vision + success definition.
  goals.md               Measurable goals.
  milestones.md          Phased plan + status.
  tasks/                 3-tier task records re-rooted here (briefs, per-task STATE, reports,
                         triage.json). Empty at scaffold (has .gitkeep).
  research/              Findings, dossiers, and the post-debugging memory dump for project
                         work. Empty at scaffold (.gitkeep).
  docs/                  Specs, designs. Empty at scaffold (.gitkeep).
```

Why this exact shape (the geometry, verified against Claude Code up-walk loading):

- A WORKER at `~/claude/projects/<slug>/repo/` up-walks `repo/ -> projects/<slug>/
  (loads CLAUDE.md = PROJECT rules) -> projects/ -> claude/ -> ~`, plus the global
  `~/.claude/CLAUDE.md` (UNIVERSAL). It never enters `manager/` (a SIBLING of repo/),
  so orchestrator rules never reach it. After the piece-1 cutover `~/claude/CLAUDE.md`
  is removed, so nothing else is picked up. Net: worker loads exactly
  `[universal] + [project]`.
- The SUPERVISOR at `~/claude/projects/<slug>/manager/` up-walks `manager/ (loads
  CLAUDE.md = supervisor role + physically-included orchestrator) -> projects/<slug>/
  (project rules) -> ...`, plus universal. Net: `[universal] + [orchestrator] +
  [project]`.
- That clean split is the entire reason the orchestrator rules are PHYSICALLY copied
  into `manager/CLAUDE.md` (not put in the project CLAUDE.md, which workers also load).

---

## 1. Prime hard rules (PIP-1 .. PIP-9)

**PIP-1 - Fail-closed on the shared orchestrator source.** This skill inlines
`~/claude/shared/orchestrator.md` into `manager/CLAUDE.md`. If that file is MISSING,
STOP - the agent-org piece-1 cutover has not landed yet, and a manager without the
orchestrator rules is broken. Do not fabricate the orchestrator content.

**PIP-2 - The project CLAUDE.md must contain ONLY project rules.** NEVER put
orchestrator, main-only, or vps rules in `~/claude/projects/<slug>/CLAUDE.md`. It is
loaded by WORKERS too; leaking delegation/main/vps rules to a worker is the exact
failure the geometry prevents. Orchestrator rules reach the supervisor ONLY via the
physical include in `manager/CLAUDE.md`.

**PIP-3 - The manager orchestrator block is a BYTE-IDENTICAL copy.** Inline the FULL
current `~/claude/shared/orchestrator.md` verbatim between the BEGIN/END markers. Do
not paraphrase, trim, or reorder. The block carries a "DO NOT edit here, edit
shared/orchestrator.md then re-sync" notice, matching `~/claude/main/CLAUDE.md` and
`~/claude/vps/CLAUDE.md`. Verified by the byte-sync assert in sec 5.

**PIP-4 - Targeted token fill ONLY, never a blanket `<...>` replace.** When filling
`<PROJECT_SLUG>` / `<PROJECT_TITLE>` etc., replace those SPECIFIC named tokens only.
NEVER run a wildcard `s/<[^>]*>//` style replace: the injected orchestrator content
legitimately contains angle sequences like `<N>` and `<name>` (in the triage header
example), and a blanket replace would corrupt the synced block. Fill the manager
template's named tokens BEFORE injecting the orchestrator content, so the two never
interact.

**PIP-5 - Never overwrite an existing project dir.** If `~/claude/projects/<slug>/`
already exists, STOP and ask. Re-invocation on an existing project is a RESUME/repair
(check what is missing, add only that), never a fresh clobber.

**PIP-6 - repo/ XOR REPO.md, never both.** A new project gets a git-init'd `repo/`
as the worker cwd. An existing project gets a `REPO.md` pointer and NO `repo/` (or a
git WORKTREE at repo/, see sec 4 - but never an empty repo/ AND a REPO.md).

**PIP-7 - No language-stack scaffold here.** `repo/` is created as a bare git repo
(the geometry-correct worker cwd). Filling it with Next.js/Go/Python is the codebase
scaffolder's job (sec 6), run as the supervisor's first delegated worker task. This
skill must not duplicate that pipeline.

**PIP-8 - No unfilled identity placeholders in loaded files; fill content from the
brief.** `<PROJECT_SLUG>` and `<PROJECT_TITLE>` MUST be fully resolved everywhere
(scan asserts it). Vision / hard-constraints / tech-stack / guardrails / goals /
milestones are filled from the agreed brief. If a detail is genuinely not yet
decided, write an explicit `TODO(<slug>): <what is needed>` line (which the
supervisor completes on first entry), never a raw `<...>` token. Operational
placeholders inside STATE.md and the CLAUDE.md comment guidance (roster rows,
`<milestone>`, the example `<...>` inside HTML comments) are intentionally left for
the supervisor to fill live, exactly like the house STATE.md template ships.

**PIP-9 - Plain hyphens only.** Skill prose and every generated file use plain
hyphens, never em/en dashes (house style). The ONLY exception is the injected
orchestrator block, which is a byte-identical copy of the canonical file and is
reproduced exactly as-is (its dashes are Christopher's own canonical content; byte
fidelity wins).

---

## 2. Invocation + inputs

Parse `$ARGUMENTS`:

| Token | Rule |
|---|---|
| `<slug>` | first arg, kebab-case `[a-z0-9-]+`. Missing/invalid -> STOP, ask. This is the project slug, the supervisor window name, and the supervisor attn peer name. |
| `--new-repo` | (default) create a fresh `repo/` as the worker cwd. |
| `--repo <name>` | existing codebase: `<name>` must resolve under `{{REPOS_DIR}}/<name>`. Writes REPO.md, no repo/. |
| `--title "<T>"` | human-readable project title (default: Title-Cased slug). |

Inputs the skill needs from the agreed brief (ask if this is a fresh project and they
are unknown - "Don't Assume, Ask"): the one-line vision, the expanded vision, the
hard constraints, the tech stack, the guardrails, the initial goals, and the
milestone list. project-init runs AFTER project agreement, so these are normally
known; where a piece is not, seed an explicit `TODO(<slug>): ...` (PIP-8).

If this looks like product discovery (no decided WHAT/stack) -> route to /ideate. If
it is a pitch/demo/recruiter site -> /oneshot-webapp. If it is design work ->
/frontend-design. Do not scaffold in those cases.

---

## 3. Preflight (blocking, before any file is written)

```bash
SLUG="<slug>"
PROJ="$HOME/claude/projects/$SLUG"
ORCH="$HOME/claude/shared/orchestrator.md"
TPL="$HOME/claude/shared/templates"     # installed home of the 3 .tmpl files (see CUTOVER)

# PIP-1: orchestrator source must exist (piece-1 cutover landed)
test -f "$ORCH" || { echo "STOP (PIP-1): $ORCH missing - agent-org piece-1 cutover not applied yet."; exit 1; }
# templates must exist
for t in project-CLAUDE.md.tmpl manager-CLAUDE.md.tmpl STATE.md.tmpl; do
  test -f "$TPL/$t" || { echo "STOP: template $TPL/$t missing (install per CUTOVER project-init step)."; exit 1; }
done
# PIP-5: never clobber
test -e "$PROJ" && { echo "STOP (PIP-5): $PROJ already exists - resume/repair, do not clobber."; exit 1; }
# projects/ root exists (created by piece-1 layout; make it if absent, that is safe)
mkdir -p "$HOME/claude/projects"
# slug shape
printf '%s' "$SLUG" | grep -qE '^[a-z0-9][a-z0-9-]*$' || { echo "STOP: slug must be kebab-case."; exit 1; }
echo "preflight OK for $SLUG"
```

For `--repo <name>`: also assert `test -d "$HOME/claude/Git/repositories/<name>"` (the
existing repo must be real). Missing -> STOP, ask.

---

## 4. Scaffold pipeline (each phase ends with a blocking assert)

### Phase 1 - directory tree
```bash
mkdir -p "$PROJ/manager" "$PROJ/tasks" "$PROJ/research" "$PROJ/docs"
touch "$PROJ/tasks/.gitkeep" "$PROJ/research/.gitkeep" "$PROJ/docs/.gitkeep"
# Assert:
test -d "$PROJ/manager" && test -d "$PROJ/tasks" && test -d "$PROJ/research" && test -d "$PROJ/docs" || { echo "TREE FAILED"; exit 1; }
```

### Phase 2 - project CLAUDE.md (project rules)
Read `$TPL/project-CLAUDE.md.tmpl`, fill the named tokens (`<PROJECT_SLUG>`,
`<PROJECT_TITLE>`) and the content sections (vision / hard-constraints / tech-stack /
guardrails) from the agreed brief (PIP-8), and Write to `$PROJ/CLAUDE.md`. Keep it
project-only (PIP-2). Prefer Read -> fill -> Write for the content-heavy body; use
targeted seds only for the simple identity tokens (PIP-4).
```bash
# Assert (identity tokens resolved; no orchestrator leakage):
! grep -qE '<PROJECT_SLUG>|<PROJECT_TITLE>' "$PROJ/CLAUDE.md" || { echo "UNFILLED IDENTITY TOKEN in project CLAUDE.md"; exit 1; }
# PIP-2 leakage check anchors on RULE HEADINGS (a leaked orchestrator/main/vps rule
# is a pasted `##` section, not a prose mention). Anchoring avoids false-positives on
# the template's own guidance comment that NAMES the forbidden categories to teach
# "keep these out". A bare inline WHATSAPP=1 env token is also a main-only tell.
LEAK_HEADINGS='^#{1,4}[[:space:]].*(Supervisor Orchestration Layer|Task Complexity Triage|3-Tier Task Hierarchy|Worker Model Policy|Worker Orchestration Tooling|Autonomous Loop|Close the Loop|Equip Before Delegating|Creative Tasks)'
! grep -qiE "$LEAK_HEADINGS" "$PROJ/CLAUDE.md" || { echo "PIP-2 VIOLATION: orchestrator rule heading leaked into project CLAUDE.md"; exit 1; }
! grep -q 'WHATSAPP=1' "$PROJ/CLAUDE.md" || { echo "PIP-2 VIOLATION: main-only WHATSAPP=1 in project CLAUDE.md"; exit 1; }
```

### Phase 3 - manager/CLAUDE.md (supervisor role + PHYSICAL orchestrator include)
Fill the named tokens on the manager template FIRST (PIP-4), then inject the
orchestrator content verbatim in place of the `<<<ORCHESTRATOR_SYNC_TARGET>>>` token
(PIP-3). Deterministic build:
```bash
TITLE="<Human Title>"
# 1) fill ONLY the specific named tokens (never a wildcard)
sed -e "s|<PROJECT_SLUG>|$SLUG|g" -e "s|<PROJECT_TITLE>|$TITLE|g" \
    "$TPL/manager-CLAUDE.md.tmpl" > "$PROJ/manager/CLAUDE.md.stage"
# 2) inject the orchestrator file verbatim where the token sits (getline preserves bytes)
awk -v ORCH="$ORCH" '
  index($0,"<<<ORCHESTRATOR_SYNC_TARGET>>>") { while ((getline line < ORCH) > 0) print line; close(ORCH); next }
  { print }
' "$PROJ/manager/CLAUDE.md.stage" > "$PROJ/manager/CLAUDE.md"
rm -f "$PROJ/manager/CLAUDE.md.stage"
# Asserts:
grep -q 'BEGIN synced content from ~/claude/shared/orchestrator.md' "$PROJ/manager/CLAUDE.md" || { echo "BEGIN marker missing"; exit 1; }
grep -q 'END synced content from ~/claude/shared/orchestrator.md'   "$PROJ/manager/CLAUDE.md" || { echo "END marker missing"; exit 1; }
! grep -q '<<<ORCHESTRATOR_SYNC_TARGET>>>' "$PROJ/manager/CLAUDE.md" || { echo "token not injected"; exit 1; }
! grep -qE '<PROJECT_SLUG>|<PROJECT_TITLE>' "$PROJ/manager/CLAUDE.md" || { echo "UNFILLED IDENTITY TOKEN in manager CLAUDE.md"; exit 1; }
```

### Phase 4 - repo/ (new) OR REPO.md (existing)
NEW (`--new-repo`, default):
```bash
mkdir -p "$PROJ/repo"
git -C "$PROJ/repo" init -b main >/dev/null
printf '# %s codebase\n\nWorker cwd for the %s project. Fill with the language stack via the codebase scaffolder (see SKILL sec 6).\n' "$TITLE" "$SLUG" > "$PROJ/repo/README.md"
# Assert (repo/ is the worker cwd; REPO.md must NOT also exist - PIP-6):
test -d "$PROJ/repo/.git" && ! test -e "$PROJ/REPO.md" || { echo "repo/ setup failed or REPO.md conflict"; exit 1; }
```
EXISTING (`--repo <name>`): write `$PROJ/REPO.md` (no repo/) with: canonical path
`{{REPOS_DIR}}/<name>`, the stack + deploy/ops facts, and this geometry note:
"A worker whose cwd is the canonical repo does NOT load this project's CLAUDE.md
(different up-walk). To preserve `[universal] + [project]` for work on an existing
repo, create a git WORKTREE at `~/claude/projects/<slug>/repo/` backed by the
canonical repo (SPEC sec 2 'workers cwd + worktrees'):
`git -C {{REPOS_DIR}}/<name> worktree add ~/claude/projects/<slug>/repo <branch>` ;
otherwise the supervisor must inject the project rules into each worker brief."
```bash
# Assert (existing case):
test -f "$PROJ/REPO.md" && ! test -d "$PROJ/repo" || { echo "REPO.md setup failed or repo/ conflict"; exit 1; }
```

### Phase 5 - STATE.md + vision/goals/milestones
Read `$TPL/STATE.md.tmpl`, fill the identity + north-star + started fields, Write to
`$PROJ/STATE.md`. Write `vision.md` (expanded vision + success definition),
`goals.md` (measurable goals), `milestones.md` (phased plan; mirror the M-list into
STATE.md's milestones section). Fill from the brief; explicit `TODO(<slug>): ...` for
any genuinely-undecided piece (PIP-8).
```bash
# Asserts:
for f in STATE.md vision.md goals.md milestones.md; do test -s "$PROJ/$f" || { echo "$f missing/empty"; exit 1; }; done
! grep -qE '<PROJECT_SLUG>|<PROJECT_TITLE>' "$PROJ/STATE.md" || { echo "UNFILLED IDENTITY TOKEN in STATE.md"; exit 1; }
```

---

## 5. Verification gate (blocking, before the report)

Evidence = command + exit code + key output. Run all; any FAIL means NOT done.

```bash
# G1 tree shape
test -f "$PROJ/CLAUDE.md" && test -f "$PROJ/manager/CLAUDE.md" && test -f "$PROJ/STATE.md" \
  && test -f "$PROJ/vision.md" && test -f "$PROJ/goals.md" && test -f "$PROJ/milestones.md" \
  && test -d "$PROJ/tasks" && test -d "$PROJ/research" && test -d "$PROJ/docs" \
  && { test -d "$PROJ/repo/.git" || test -f "$PROJ/REPO.md"; } && echo "G1 tree OK"

# G2 repo/ XOR REPO.md (PIP-6)
if test -d "$PROJ/repo" && test -f "$PROJ/REPO.md"; then echo "G2 FAIL: both repo/ and REPO.md"; else echo "G2 XOR OK"; fi

# G3 project CLAUDE.md carries NO orchestrator/main/vps RULES (PIP-2). Heading-anchored
# so it does not false-positive on the template's guidance that NAMES the excluded
# categories. Plus a WHATSAPP=1 literal check (main-only env tell).
LEAK_HEADINGS='^#{1,4}[[:space:]].*(Supervisor Orchestration Layer|Task Complexity Triage|3-Tier Task Hierarchy|Worker Model Policy|Worker Orchestration Tooling|Autonomous Loop|Close the Loop|Equip Before Delegating|Creative Tasks)'
if grep -qiE "$LEAK_HEADINGS" "$PROJ/CLAUDE.md" || grep -q 'WHATSAPP=1' "$PROJ/CLAUDE.md"; then echo "G3 FAIL: non-project rule leaked into project CLAUDE.md"; else echo "G3 project-only OK"; fi

# G4 manager CLAUDE.md byte-sync with the canonical orchestrator (PIP-3)
python3 - "$PROJ/manager/CLAUDE.md" "$ORCH" <<'PY'
import sys
mgr=open(sys.argv[1]).read(); orch=open(sys.argv[2]).read()
a='# Orchestrator Rules (shared)'
b='<!-- ===== END synced content from ~/claude/shared/orchestrator.md ===== -->'
i=mgr.find(a); j=mgr.rfind(b)   # rfind: the real END marker is the LAST occurrence
region = mgr[i:j].strip('\n') if (i!=-1 and j!=-1 and i<j) else None
print('G4 byte-sync OK' if region is not None and region==orch.strip('\n') else 'G4 FAIL: manager orchestrator block not byte-identical to canonical')
PY

# G5 no unfilled IDENTITY tokens anywhere in loaded files
! grep -rqE '<PROJECT_SLUG>|<PROJECT_TITLE>|<<<ORCHESTRATOR_SYNC_TARGET>>>' \
  "$PROJ/CLAUDE.md" "$PROJ/manager/CLAUDE.md" "$PROJ/STATE.md" "$PROJ/vision.md" "$PROJ/goals.md" "$PROJ/milestones.md" \
  && echo "G5 no unfilled identity tokens"

# G6 GEOMETRY PROOF (up-walk simulation, no session needed):
#   worker cwd = repo/ (new) : the ONLY CLAUDE.md files on its up-walk (excluding the
#   global ~/.claude one) must be the project CLAUDE.md - NOT manager/, main/, vps/.
if test -d "$PROJ/repo"; then
  d="$PROJ/repo"; hits=""
  while [ "$d" != "$HOME" ] && [ "$d" != "/" ]; do
    [ -f "$d/CLAUDE.md" ] && hits="$hits $d/CLAUDE.md"
    d="$(dirname "$d")"
  done
  echo "G6 worker up-walk CLAUDE.md hits:$hits"
  # EXPECT exactly: $PROJ/CLAUDE.md  (project). NOT manager/, NOT main/, NOT vps/, NOT ~/claude/CLAUDE.md (removed at cutover).
  case "$hits" in
    *"$PROJ/manager/CLAUDE.md"*|*"$HOME/claude/CLAUDE.md"*|*"$HOME/claude/main/CLAUDE.md"*|*"$HOME/claude/vps/CLAUDE.md"*)
      echo "G6 FAIL: worker up-walk would load a non-project CLAUDE.md";;
    *"$PROJ/CLAUDE.md"*) echo "G6 OK: worker loads [universal] + [project] only";;
    *) echo "G6 WARN: project CLAUDE.md not on the up-walk (unexpected)";;
  esac
fi
```

Note on G6 + `~/claude/CLAUDE.md`: pre-cutover that file still exists, so a live
worker would ALSO pick it up - G6 asserts the DIRECTORY geometry (project is the only
non-global project-scoped hit); the removal of `~/claude/CLAUDE.md` is the piece-1
cutover's job (CUTOVER.md). Post-cutover the geometry is exactly `[universal] +
[project]`. The authoritative live check is the CUTOVER `_cutover-test` `/memory`
probe.

---

## 6. Codebase (repo/) stack scaffold - DELEGATED, not done here (PIP-7)

`repo/` is created as a bare git repo (the worker cwd). Filling it with a language
stack (Next.js / Go / Python, with the full verified toolchain, website defaults,
Docker/CI, gates) is the CODEBASE SCAFFOLDER's job, run as the supervisor's FIRST
delegated worker task with cwd = `~/claude/projects/<slug>/repo/`:

- The verified codebase pipeline + recipes are preserved from the pre-agent-org
  project-init (see CUTOVER: kept as the companion scaffolder). Its recipes live in
  `references/` (nextjs-recipe.md, go-python-recipes.md, docs-templates.md).
- The ONE change vs the old flow: target dir is `~/claude/projects/<slug>/repo/`
  (this project's worker cwd), NOT `{{REPOS_DIR}}/<name>`, so the codebase sits inside
  the project workspace and the worker geometry holds.
- For an EXISTING repo (`--repo`), there is no stack scaffold; use the worktree option
  in REPO.md if geometry-preserving worker cwd is needed.

Keeping the two concerns separate is deliberate: this skill guarantees the WORKSPACE +
geometry; the codebase scaffolder guarantees a green, gate-passing REPO.

---

## 7. Final report (only after sec 5 passes)

```
+------------------------------------------------------------+
|                 PROJECT WORKSPACE INITIALIZED              |
+------------------------------------------------------------+
| Project:   <slug>  (<Human Title>)                        |
| Location:  ~/claude/projects/<slug>/                      |
| Codebase:  repo/ (new, bare git)  |  REPO.md -> <name>    |
| Supervisor cwd: manager/  (loads universal+orchestrator+project) |
| Worker cwd:     repo/     (loads universal+project)       |
+------------------------------------------------------------+
```
Then, all mandatory:
1. Verification gate table (G1-G6, each: command, exit code, evidence snippet).
2. The create-list actually written (file inventory).
3. Any `TODO(<slug>): ...` seeds left for the supervisor to complete (PIP-8).
4. NEXT STEP (hand back to the caller, NOT done here): spawn the supervisor -
   `spawn-supervisor.sh <slug>` (piece 2) -> verify the attn peer -> brief it with
   `brief-worker.sh --supervisor <slug> <brief>`; then the supervisor delegates the
   repo/ stack scaffold (sec 6) as its first worker task. project-init NEVER spawns
   the supervisor itself.

---

## 8. Edge cases

- **Project dir exists:** STOP, ask (PIP-5); treat as resume/repair (add only what is
  missing; re-verify sec 5).
- **`--repo <name>` where the repo is absent:** STOP, ask - never invent a pointer.
- **orchestrator.md changed after scaffold:** re-sync `manager/CLAUDE.md` the same way
  main/vps re-sync (CUTOVER.md re-sync procedure) - keep everything above the BEGIN
  marker, re-inject, re-append END. G4 catches drift.
- **Monorepo / multi-repo project:** out of scope for the single repo/ + REPO.md
  model; STOP and ask (a project may carry several REPO.md pointers only if Christopher
  confirms the layout).
- **Pre-cutover invocation:** PIP-1 fails fast if `shared/orchestrator.md` is absent;
  do not scaffold a manager without the orchestrator rules.
