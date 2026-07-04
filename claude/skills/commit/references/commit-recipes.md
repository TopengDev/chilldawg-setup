# /commit recipes - taxonomy, staging, gallery, playbook commands

Companion to `../SKILL.md`. Every git flag here is verified on this box (git 2.54.0;
node v22.16.0 / npm 10.9.2 / pnpm 11.9.0 / bun 1.3.12 / yarn 1.22.22 classic) or is cited
from a sibling skill's verified facts. Re-verify with `--help` on tool drift.

> Note: the shell snippets below contain the literal two-word `git commit` string inside
> HEREDOC examples. That is fine in this DOCUMENT. It only matters when you type such a
> command into the Bash tool: the seal-guard hook greps the whole command string, so any
> Bash command containing `git commit` without `CLAUDE_COMMIT_SKILL=1` is denied (see
> SKILL.md Section 6, "Authoring gotcha").

---

## 1. Conventional-commits type taxonomy (worked example per type)

The core ten types are exactly what preflight G8's conventional WARN-check recognizes.
`revert` is additionally valid after a real `git revert`.

| Type | Use for | Worked subject |
|---|---|---|
| `feat` | a new capability a user can observe | `feat(billing): add IDR PPN line to invoice totals` |
| `fix` | a bug fix (wrong behavior -> correct) | `fix(auth): prevent token refresh race on parallel requests` |
| `refactor` | internal restructure, no behavior change | `refactor(api): collapse duplicate pagination into one helper` |
| `docs` | documentation only | `docs(readme): document the CLAUDE_COMMIT_SKILL sentinel` |
| `chore` | tooling / deps / housekeeping, no src behavior | `chore(deps): pin next-intl to 3.26 for the id/en routing fix` |
| `test` | add or fix tests only | `test(checkout): cover the empty-cart redirect path` |
| `style` | formatting / whitespace, no logic | `style(pos): align the receipt column widths` |
| `perf` | a measurable performance improvement | `perf(dashboard): memoize the tenant selector to cut re-renders` |
| `ci` | CI / workflow config | `ci(release): resolve the run by pushed SHA not --limit 1` |
| `build` | build system / bundler / manifest | `build(next): switch output to standalone for the docker image` |
| `revert` | undo a prior commit | `revert: feat(billing) IDR PPN line (broke rounding)` |

**Scope** is optional but preferred when it is obvious (the module / area). In a monorepo,
scope is the package or app: `feat(pos-web): ...`, `fix(billing-api): ...`. Do not invent a
scope when the change spans many areas - omit it: `refactor: unify the date formatter`.

**`!` for breaking changes:** `feat(api)!: drop the v1 tenant header` plus a
`BREAKING CHANGE:` footer (see gallery). The `!` and the footer are both conventional and
both PASS the hook (they carry no AI attribution).

---

## 2. Per-scenario staging recipes

All staging is individual-by-name (SKILL.md C-5). `git add -A` / `git add .` are never used.

### 2a. Standard change

```bash
git status                       # never -uall
git diff                         # review unstaged
git add src/auth/token.ts src/auth/token.test.ts
git diff --cached --name-only    # assert exactly the intended set is staged
```

### 2b. Monorepo scope selection

Stage only the touched package's files; let the scope name that package.

```bash
git diff --stat                                  # which packages moved?
git add packages/pos-web/src/checkout/Cart.tsx packages/pos-web/src/checkout/cart.ts
# subject: feat(pos-web): ...   (scope = the package, not the repo)
```
If two packages genuinely change together, either make TWO commits (one scope each) or use
a spanning subject with no scope. Do not sweep both packages' unrelated dirt into one blob.

### 2c. Partial-file staging (a file mixes wanted + unwanted hunks)

```bash
git add -p src/config.ts        # interactively pick hunks: y (stage) / n (skip) / s (split)
git diff --cached -- src/config.ts   # verify ONLY the intended hunks are staged
git diff -- src/config.ts            # confirm the skipped hunks remain unstaged
```
Use this when a file has both the real change and unrelated local scratch edits - stage the
real hunks only, leave the scratch unstaged (it is pre-existing dirt, SKILL.md C-5).

### 2d. Source + lockfile PAIR (the sanctioned C-7 exception)

ONLY when a caller sanctions it (see Section 3). Stage the manifest and its lockfile
together so CI's frozen install stays in sync:

| Manager | Stage together |
|---|---|
| npm | `git add package.json package-lock.json` |
| pnpm | `git add package.json pnpm-lock.yaml` |
| bun | `git add package.json bun.lock` |
| yarn (classic) | `git add package.json yarn.lock` |
| Cargo | `git add Cargo.toml Cargo.lock` |
| uv | `git add pyproject.toml uv.lock` |
| poetry | `git add pyproject.toml poetry.lock` |

### 2e. Generated / vendored files

Default: do NOT stage build output (`dist/`, `.next/`, `build/`), coverage, or vendored
trees unless the change is DELIBERATELY about a checked-in generated artifact (e.g. a
committed protobuf stub the repo tracks on purpose). If tracked-and-intended, stage the
specific generated file by name and say so in the body. Never stage a generated file that
`.gitignore` already excludes (SKILL.md C-6).

### 2f. Deletions and renames

```bash
git rm path/to/removed.ts                 # stage a deletion
git add old/name.ts new/name.ts           # a rename shows as delete+add; stage both paths
git status                                 # git auto-detects the rename (R) when staged together
```
Subject reflects intent: `refactor(auth): rename token.ts to session.ts` or
`chore: remove the dead legacy exporter`.

---

## 3. The sanctioned lockfile-staging exception - EXACT caller phrasings

/commit excludes lockfiles by default (SKILL.md C-7). It stages a lockfile ONLY when a
caller EXPLICITLY asks. This is a bidirectional contract - the callers below phrase the
request; /commit honors exactly that phrasing.

**From /ship (S-13, its Step 6, after a version bump):**
> "commit via /commit, staging package.json AND package-lock.json (user-authorized
> lockfile staging for the version bump)"
- WHY: `npm version <type> --no-git-tag-version` updates BOTH files with no commit/tag; if
  /commit stages only the manifest, /ship's own Step 7 preflight G9b (`npm ci --dry-run`)
  fails on the drift.

**From /preflight (P4 lockfile-drift playbook / its fix loop step 4 / G9d WARN):**
> "stage BOTH package.json and lockfile (tell /commit explicitly)"
- WHY: preflight regenerated the lockfile to fix drift; G9d WARNs precisely because
  /commit skips lockfiles by default and CI's frozen install would otherwise hard-fail.

**From the user:** any explicit "commit the lockfile too" / "stage the lockfile".

When you receive one of these, stage the PAIR (Section 2d) and note in the report:
"lockfile staged (sanctioned by <caller>)". Absent an explicit request, leave the lockfile
unstaged - that is the correct default, not an omission.

---

## 4. Expanded good/bad message gallery

| GOOD | Why it works | BAD | Why it fails |
|---|---|---|---|
| `fix(auth): prevent token refresh race on parallel requests` | names the effect + the condition | `fix bug` | falsifiable-by-nothing; C-9 banned |
| `refactor(api): collapse duplicate pagination into one helper` | what + why (dedup) | `update files` | zero signal; C-9 banned |
| `feat(billing): add IDR PPN line to invoice totals` | user-visible capability | `changes` | meaningless; C-9 banned |
| `perf(dashboard): memoize tenant selector to cut re-renders` | measurable intent | `improve code` | vague; C-9 banned |
| `fix(pos): guard against null cart on SW replay` | root-cause specific | `wip` | not a finished unit; C-9 banned |
| `chore(deps): pin next-intl to 3.26 for id/en routing` | why the pin | `misc` | dump-bucket; C-9 banned |

**Body example (non-trivial change):**
```
fix(auth): prevent token refresh race on parallel requests

Two concurrent requests could both see an expired token and each trigger a
refresh, invalidating the first token mid-flight. Serialize refresh behind a
single in-flight promise so parallel callers await the same result.

Refs: PULSE-482
```

**Breaking-change example (footer PASSES the hook, C-15):**
```
feat(api)!: require the tenant header on all v2 routes

BREAKING CHANGE: v2 endpoints now 400 without X-Tenant-Id. Clients must send
the header; the implicit-default-tenant fallback is removed.
```

**NEVER (hook-denied even with the sentinel, C-3):**
```
feat(x): add thing

Co-Authored-By: Claude <noreply@anthropic.com>      <- DENIED
```
```
feat(x): add thing

Generated with Claude Code                           <- DENIED
```

---

## 5. Playbook command sequences (Section 5 of SKILL.md)

### Playbook 1 - denied despite the sentinel (AI trailer in the message)

The content-guard fired. Rebuild the message WITHOUT the trailer, re-commit:
```bash
CLAUDE_COMMIT_SKILL=1 git commit -m "$(cat <<'EOF'
fix(auth): prevent token refresh race on parallel requests

Serialize refresh behind a single in-flight promise.
EOF
)"
```
If the trailer came from `$ARGUMENTS`, strip the offending line before composing (C-4).
Never escalate the sentinel, never `--no-verify`. (Memory `feedback_commit_skill_enforced`
#238: 32 AI-attributed commits reached pi-setup and needed a history scrub + force-push.)

### Playbook 2 - nothing to commit

```bash
git diff --cached --name-only     # empty
git status --porcelain            # confirm the tree really is clean of in-scope changes
```
Report N/A (SKILL.md C-14). If the user expected a change, say so plainly - the edit may
not have landed. Never invent one, never make an empty commit.

### Playbook 3 - repo pre-commit hook reformats / rejects

Reformat case (prettier / lint-staged rewrote files as part of the hook):
```bash
git status                        # see which files the hook re-touched
git add path/to/reformatted.ts    # re-stage BY NAME
CLAUDE_COMMIT_SKILL=1 git commit -m "$(cat <<'EOF'
fix(scope): subject
EOF
)"
```
Reject case (commitlint): fix the MESSAGE to satisfy the repo's rule and retry. NEVER
`--no-verify` without asking Christopher (SKILL.md C-11, mirror preflight PF-5).

### Playbook 4 - mid-merge / rebase

```bash
git rev-parse -q --verify MERGE_HEAD && echo "MID-MERGE"        # non-empty => mid-merge
ls .git/rebase-apply .git/rebase-merge 2>/dev/null && echo "MID-REBASE"
```
Either present -> do NOT commit. Report the in-progress state; the caller resolves the
merge/rebase. (A raw commit mid-conflict is hook-blocked anyway, SKILL.md C-2.)

### Playbook 5 - commit signing fails (gpgsign, non-interactive)

```bash
git config --get commit.gpgSign    # true?
```
If signing fails non-interactively (no agent / no TTY), report the failure plainly. Do NOT
silently `--no-gpg-sign` - that strips the trust property the repo opted into. Ask
Christopher whether to sign (fix the agent) or intentionally skip signing this once.

### Playbook 6 - oversized diff

```bash
git diff --stat                    # scope overview first (files + churn)
git diff -- path/to/one/file       # targeted per-file review
```
Review and stage in reviewed chunks (Section 2c for partial hunks). Never blind-stage a
huge tree to "get it done".
