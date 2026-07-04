# /ship recipes - full command sequences

Companion to `../SKILL.md`. Every flag here was verified 2026-07-03 (`--help` runs on
this box: gh 2.67.0, git 2.54.0, npm 10.9.2, pnpm 11.9.0, bun 1.3.12) or is cited
from a sibling skill's verified facts. Re-verify with `--help` if a tool version
drifts.

## R1 - Version bump per manager (lockfile-safe, S-13)

The trap: editing the manifest version by hand desyncs the lockfile's root version;
`npm ci` (and preflight G9b's `npm ci --dry-run` frozen check) then FAILS on the
mismatch, and /commit won't stage the lockfile unless told. Always bump BOTH, always
tell /commit to stage BOTH.

| Stack | Bump command | Lockfile resync | Sync verification (preflight G9b) |
|---|---|---|---|
| npm | `npm version <patch\|minor\|major> --no-git-tag-version` (updates package.json + package-lock.json, NO commit, NO tag) | already done by the bump; fallback `npm install --package-lock-only` | `npm ci --dry-run` (exit 0 = in sync) |
| pnpm | manual edit of `package.json` `"version"` | `pnpm install --lockfile-only` | `pnpm install --frozen-lockfile --lockfile-only` |
| bun | manual edit of `package.json` `"version"` | `bun install --lockfile-only` | `bun install --frozen-lockfile --lockfile-only` |
| yarn classic | manual edit of `package.json` `"version"` | none pure (yarn 1.x `--frozen-lockfile` performs a REAL install - preflight G9b caveat) | flag to the user; do not run a mutating install silently |
| Cargo | manual edit of `Cargo.toml` `version` | `cargo update` regenerates Cargo.lock IF cargo is available (NOT on this box's PATH per preflight P3 - BLOCKED, tell the user) | n/a locally |
| pyproject | manual edit of `pyproject.toml` `version` | lockfile only if the project uses one (uv/poetry; poetry NOT on PATH) - resync with the project's own manager or flag | n/a locally |

WHY not bare `npm version <type>`: without `--no-git-tag-version` it creates a raw
git commit AND a git tag - the commit violates S-2 (seal-guard blocks raw commits, so
it fails messily mid-step) and the tag preempts step 9(b)'s annotated-tag flow.

Then in step 6: "commit via /commit, staging package.json AND package-lock.json
(user-authorized lockfile staging for the version bump)".

## R2 - Changelog generation from commits (step 9a)

```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)   # empty = no prior tag
RANGE=${LAST_TAG:+$LAST_TAG..HEAD}                        # full history if empty
git log --pretty=format:'%s' $RANGE
```

Group by conventional prefix: `feat:` -> **Added**, `fix:` -> **Fixed**, everything
else -> **Changed**. Write the Keep-a-Changelog section:

```markdown
## [{VERSION}] - {YYYY-MM-DD}

### Added
- {feat subjects, reworded as user-facing changes}

### Fixed
- {fix subjects}

### Changed
- {the rest, curated - drop pure chore/ci noise}
```

Append the release link at the bottom. Commit via /commit, re-push. The re-push
creates a NEW HEAD SHA - the CI watch in 9(c) must target the SHA it was started
for; note the follow-up push (and its own run, if watched) separately in the report.

## R3 - Annotated tag (step 9b)

```bash
VERSION=$(jq -r .version package.json)        # or the manifest the stack uses
git tag -l "v$VERSION" | grep -q . && echo "EXISTS -> SP-6: report + skip" 
git tag -a "v$VERSION" -m "Release v$VERSION - {one-line headline}"
git push origin "v$VERSION"
git ls-remote --tags origin "refs/tags/v$VERSION"   # evidence: tag on remote
```

Never `git tag -f`, never `git push --delete origin <tag>`, never lightweight
`git tag v...` (S-8).

## R4 - CI watch, the full verified block (step 9c)

```bash
set -u
SHA=$(git rev-parse HEAD)

# 1. Resolve the run FOR THIS SHA (S-6). Registration lag is normal - retry <= 60s.
RUN_ID=""
for i in $(seq 1 12); do
  RUN_ID=$(gh run list --commit "$SHA" --json databaseId -q '.[0].databaseId')
  [ -n "$RUN_ID" ] && break
  sleep 5
done
if [ -z "$RUN_ID" ]; then
  # SP-4: not a pipeline failure. Evidence dump for the report:
  gh run list --limit 5 --json headSha,status,conclusion,url
  echo "Remote CI: IN PROGRESS/N-A - no run registered for $SHA after 60s"
fi

# 2. Bounded watch (S-11: ~10 min; Bash tool max timeout 600000 ms fits exactly).
#    The exit code of this command is NOT the verdict (S-5).
gh run watch "$RUN_ID" --exit-status || true

# 3. MANDATORY truth check (S-5) - the ONLY green signal is conclusion=="success".
gh run view "$RUN_ID" --json conclusion,status
# status != "completed"        -> IN PROGRESS (report; optional ScheduleWakeup follow-up)
# conclusion == "success"      -> PASS (paste this JSON as the report evidence)
# any other conclusion         -> FAIL -> SP-5 ladder (R7) BEFORE escalating (S-10)
```

Fallback when `--commit` returns runs for multiple workflows: pick per workflow with
`gh run list --commit "$SHA" --json databaseId,workflowName,status,conclusion` and
watch the deploy-relevant one; report the others' conclusions too.

## R5 - Deploy-on-push detection (S-7, before step 8)

Reuse preflight G1's parse when it ran in this session (it already determined which
workflows fire on push to this branch). Otherwise:

```bash
BRANCH=$(git branch --show-current)
ls .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
# For each workflow that fires on push to $BRANCH (bare "push:" = all branches;
# "branches:" filters must match), look for deploy-shaped jobs:
grep -nEi 'ssh|scp|rsync|docker (push|build)|docker/build-push-action|appleboy/ssh-action|deploy|compose (up|pull)' \
  .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
```

- Hit on a workflow that fires for this branch -> the push IS a prod deploy: run the
  S-7 timing gate (active hours ~08:00-18:00 WIB weekdays -> offer off-peak).
- HEURISTIC-HONEST caveat: greps miss exotic deploy jobs (reusable workflows,
  repository_dispatch chains). Uncertain + known prod app (Pulse pos-web class) ->
  ROUND UP, treat as deploy-on-push.
- User chooses a scheduled off-peak push -> IMMEDIATELY CronCreate/ScheduleWakeup the
  push with a self-contained prompt (memory `feedback_time_promise_scheduling`).
  A promise without a trigger silently dies.

## R6 - Delta security pass (S-14, before step 8)

```bash
git log --oneline "$SEC_SHA..HEAD"          # empty -> delta pass N/A, done
git diff "$SEC_SHA..HEAD"                    # review THIS with step 2's exact criteria
```

Same rules as step 2: >80% exploitability bar, same check/do-not-report lists, run
INLINE (never delegated). Findings -> fix via the normal loop, commit via /commit -
which invalidates the preflight verdict (S-4): re-run /preflight, then re-anchor
`SEC_SHA=$(git rev-parse HEAD)`. The delta is usually tiny (e2e/preflight fix
commits) - this pass costs a minute and closes the only unreviewed window in the
push range.

## R7 - SP playbooks, full sequences

**SP-1 push rejected (behind-remote ONLY):**
```bash
git pull --rebase origin "$BRANCH"     # conflict? -> SP-3 immediately
# S-4: the rebase merged remote commits the gates never saw:
# re-run FULL /preflight, re-check S-14 delta, then:
git push -u origin "$BRANCH"
```
Any other rejection text (protected branch, pre-receive hook declined, non-fast-
forward with diverged history) -> S-1: STOP, paste the rejection, ask.

**SP-2 detached HEAD:** `git branch --show-current` empty -> STOP. Show `git status`
+ `git log --oneline -3`, ask which branch to ship on. Never `git push origin HEAD`
on a guess.

**SP-3 rebase conflict:**
```bash
git rebase --abort                     # FIRST action, always
git status                             # then report the conflicting files + both SHAs
```
Ask the user how to proceed. Never hand-resolve-and-continue inside /ship: conflict
resolution needs owner judgment, raw `git commit` mid-conflict is hook-blocked
anyway (S-2), and a botched resolution pushed upstream is expensive.

**SP-4 CI run not found:** covered in R4 step 1. Report row:
`Remote CI: IN PROGRESS/N-A (no run registered for <sha> after 60s)` + the
`gh run list` JSON dump. Optionally ScheduleWakeup a re-check in ~10 min.

**SP-5 CI FAIL ground-truth ladder** (preflight P6, memory
`feedback_verify_prod_before_ci_panic`):
```bash
curl -I https://<prod-url>/                                          # app answering?
gh run list --commit "$SHA" --json conclusion,status,url             # later GREEN on the SAME SHA?
# if SSH available (read-only):
docker ps --format '{{.Image}} {{.Status}} {{.CreatedAt}}'           # container freshly rebuilt?
```
Later green run on the same SHA, or prod healthy + SHA live = HISTORICAL NOISE - the
report says so with the evidence, no escalation theater. Otherwise it is REAL: report
the failing job (`gh run view "$RUN_ID" --json jobs` names it), the `--web` URL, and
the prod state. Either way the Final Report carries it loudly (S-10).

**SP-6 tag exists:** report `Tagged: skipped - v{V} already exists ({sha} it points
to via git rev-parse v{V})`. Never move it.

**SP-7 gh missing/unauthenticated:**
```bash
command -v gh || echo "gh not installed - CI watch N/A"
gh auth status || echo "gh unauthenticated - run: gh auth login"
```
CI watch = N/A with the hint; the rest of step 9 still runs.

**SP-8 sub-skill stuck-report:** preflight's `STUCK - preflight fix budget exhausted`
block or e2e's FP-6 dossier arrives -> ABORT: Final Report verdict = ABORTED at that
step, the stuck-report/dossier pasted VERBATIM, plus the "remains unshipped" list
(uncommitted work, unpushed commits by SHA, the untagged version). Never re-invoke
the sub-skill on the same wall, never weaken its gate (S-11).
