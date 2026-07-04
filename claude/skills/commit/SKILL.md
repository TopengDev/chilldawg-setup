---
name: commit
description: "Produce ONE clean, conventional-commits commit that passes the seal-guard hook (staging + message + CLAUDE_COMMIT_SKILL=1 sentinel, never any AI attribution). Use when the user asks to commit, save changes, or says /commit. The commit ONLY - /ship owns push/tag/CI, /preflight owns the pre-push gate."
argument-hint: [optional commit message override]
allowed-tools: Bash, Read, Glob, Grep
---

# /commit - The Commit Anchor

/commit does exactly ONE thing: turn the current working-tree changes into a single,
clean, conventional-commits commit that passes the seal-guard PreToolUse hook. It is the
UNIVERSAL commit path - 10 sibling skills (ship, preflight, e2e, qa, audit, case-study,
project-init, ideate, oneshot-webapp, launch-strategy) route every commit
through here rather than running raw `git commit`, because in this environment raw
`git commit` is BLOCKED by a hook and only /commit carries the bypass sentinel.

/commit is a leaf. It stages, writes the message, commits, verifies, and STOPS. It does
NOT push, tag, bump versions, run CI, or deep-scan for secrets - those belong to /ship
and /preflight. It never calls another skill.

```
develop -> /commit (this: ONE clean commit) -> /preflight (pre-push gate) -> /ship (push + tag + CI)
```

---

## 1. HARD RULES (C-1 .. C-15)

**C-1 - ALWAYS prefix the commit with `CLAUDE_COMMIT_SKILL=1`** (HEREDOC form, Step 4).
This sentinel is the ONLY thing that lets the commit past the live seal-guard hook
(`~/.claude/hooks/block-raw-git-commit.sh`). Without it, EVERY commit in this
environment is denied. Cite: memory `feedback_commit_skill_enforced`.

**C-2 - NEVER run raw `git commit` (no sentinel), in any form** - not `--amend`, not
`-a`, not chained (`cd x && git commit ...`). The hook word-boundary-matches
`\bgit[[:space:]]+commit\b` ANYWHERE in the Bash command string, so every one of these
is denied. The sentinel-prefixed HEREDOC recipe (Step 4) is the single sanctioned path.

**C-3 - NEVER put AI attribution in a commit message.** No `Co-Authored-By:` line
referencing Claude / Anthropic / noreply@anthropic, no `Generated with ... Claude Code`,
no robot-emoji tool footer. The hook runs a content-guard that DENIES these EVEN WITH the
`CLAUDE_COMMIT_SKILL=1` sentinel (the content check runs FIRST, before the sentinel gate).
Verified failure: 32 AI-attributed commits reached the pi-setup repo via the
harness-default commit path (NOT /commit) and required a full history scrub + force-push
(2026-06-15, memory `feedback_commit_skill_enforced` #238). This ban is ABSOLUTE.

**C-4 - If user-supplied `$ARGUMENTS` contains an AI-attribution trailer line, STRIP it
before committing.** Do not pass it through - the hook will deny the commit (C-3) and the
operator sees an opaque block. Grep the override for the C-3 patterns, remove the
offending line(s), keep the rest of the message.

**C-5 - ALWAYS stage files individually by name.** NEVER `git add -A`, NEVER `git add .`,
NEVER `git add -u` as a blanket sweep. Stage ONLY the files THIS change touched - never
sweep pre-existing dirt into the commit. (Cited as a contract by e2e E-15 and its 6.2
commit gate.)

**C-6 - NEVER stage the exclusion denylist.** Before staging any file, assert it is NOT:
- `.env`, `.env.*`, or any environment-variable file
- a credential / secret / key file: `id_rsa*`, `*.pem`, `*.key`, `*.p12`, `*.keystore`,
  `.npmrc` (may hold `_authToken`), `.aws/credentials`, `service-account*.json`,
  `credentials.json`, `*.jks`, `*.pfx`
- a binary / image / video / font (unless it is a deliberate, reviewed asset the change
  is actually about)
- anything matched by `.gitignore`
A hit -> exclude it and note the exclusion. A LIKELY-SECRET hit -> exclude, and report
`file + pattern type` ONLY, never the value (C-12).

**C-7 - Lockfiles are EXCLUDED by default.** A plain feature/fix commit does NOT stage
`package-lock.json` / `pnpm-lock.yaml` / `bun.lock` / `yarn.lock` / `Cargo.lock` /
`poetry.lock` / `uv.lock`. SANCTIONED EXCEPTION: when a caller explicitly requests staging
the manifest + lockfile as a PAIR - **/ship step S-13** (version bump), **/preflight P4**
(lockfile-drift playbook / G9d WARN), or the **user** - stage BOTH together (e.g.
`package.json` + `package-lock.json`). WHY it matters: CI's frozen install
(`npm ci` / `--frozen-lockfile`) HARD-FAILS on lockfile drift, so a manifest bump without
its lockfile ships red CI. Recipe + all-manager pairings: `references/commit-recipes.md`.

**C-8 - ALWAYS use conventional-commits format `type(scope): subject`.** Core types:
`feat` `fix` `refactor` `docs` `chore` `test` `style` `perf` `ci` `build` (these ten are
exactly what preflight G8's conventional WARN-check recognizes). `revert` is additionally
valid after a real `git revert`. Scope is optional but preferred when it is clear
(`feat(auth):`). Subject: imperative mood, describes the effect / WHY, <=72 chars, no
trailing period.

**C-9 - NEVER emit a banned-generic subject.** Bare `update` / `fix` / `changes` / `misc`
/ `stuff` / `wip` / `updates` / `various changes` / `minor fixes` / `improve code` /
`update files` / `cleanup` are BANNED (Section 4). The subject must be falsifiable and
specific - a reader who never saw the diff should learn what changed and why.

**C-10 - Commit subject AND body use plain ASCII hyphens ONLY.** NEVER an em dash or an en
dash - use a comma, a plain hyphen, or a line break (house rule, memory
`feedback_no_long_hyphens`). This lands in permanent git history, so it is not exempt.

**C-11 - NEVER `--no-verify` to bypass a repo pre-commit hook** (husky / commitlint /
pre-commit / lint-staged) without asking Christopher first (mirror preflight PF-5). If the
hook REFORMATS files, re-stage the reformatted files by name and retry. If it REJECTS
(e.g. commitlint), fix the message to satisfy it. A gate you skipped is a gate that failed.

**C-12 - NEVER print or write a secret VALUE** if one is encountered while inspecting or
staging. Report `file + pattern type` only (mirror ship S-15 / preflight PF-4). Do NOT
"show what I'm staging" by echoing a file that may contain a key.

**C-13 - /commit produces exactly ONE clean commit and STOPS.** NEVER push, tag,
version-bump, run CI, or gitleaks-scan - those are /ship (push + release tail) and
/preflight (pre-push gate + deep secret scan). NEVER add `Skill` to allowed-tools:
/commit is a leaf and calls no sub-skill.

**C-14 - If nothing relevant is staged / no in-scope changes exist, report N/A.** NEVER
fabricate a change, NEVER make an empty commit. If the user expected a change and there is
none, surface that plainly (the edit may not have landed) - do not invent one.

**C-15 - The ban is on AI/tool attribution ONLY, not on all footers.** PERMIT legitimate
conventional footers when the change warrants them: `BREAKING CHANGE: <desc>` (semver
signal - banning it would break conventional-commits), `Refs: <id>`, `Closes #<n>`. Default
to NO `Co-Authored-By`, but a REAL, NAMED human co-author on explicit user request is
allowed (the hook passes `Co-Authored-By: Jane <jane@x.com>`; it blocks only
Claude/Anthropic ones). Never invent a co-author.

---

## 2. Boundary Charter - what /commit is NOT

Trigger routing: "commit" / "save changes" / "save my work" / "/commit" route HERE.
"push" / "ship" / "deploy" route to **/ship**. "will CI pass?" / "check before push"
route to **/preflight**. /commit is the commit ONLY; it never crosses into the push or
the pre-push gate.

| Skill | It owns | /commit's relationship |
|---|---|---|
| **/commit** (this) | Staging + conventional message + `CLAUDE_COMMIT_SKILL=1` sentinel commit, ONE clean commit | The single sanctioned commit path in this environment. |
| **/preflight** | The pre-push gate: lint/types/tests/build + gitleaks secret scan (its G7/PF-8) + AI-trailer range scan (G8/PF-9) + lockfile sync (G9). NEVER pushes. | Calls /commit for its own fix commits. Deep secret scanning is ITS job, not /commit's. |
| **/ship** | Push + release tail (version, tag, CI watch, publish). The only push path. | Calls /commit at its Step 6; tells /commit to stage manifest+lockfile after a bump (S-13, C-7). |
| **/e2e** | ONE feature's fix-until-green loop; commits its OWN fixes via /commit (its E-15). | A caller. Stages only loop-touched files. |
| **/simplify** | Quality-only cleanup, applies fixes. | Its cleanup is committed via /commit when the caller commits. |

**Explicit negatives (things /commit NEVER does):**
- NEVER `git push` in any form (that is /ship Step 8).
- NEVER create or move a tag (that is /ship Step 9b - annotated only).
- NEVER bump a version or edit a manifest version field (that is /ship Step 4).
- NEVER run CI or `gh run` (that is /ship Step 9c).
- NEVER run gitleaks or a deep secret scan. /commit's front-line defense is the FILENAME
  denylist (C-6) at the staging boundary; the DEEP content scan is push-time
  (/preflight G7). The gitleaks-clean expectation before a push is verified by
  /ship + /preflight, not here.
- NEVER `git merge` / `gh pr merge` (seal-guard gated behind `CLAUDE_MERGE_OK=1`; not
  /commit's concern).

---

## 3. The Workflow

Five steps. Do not skip the gates in Step 2 and Step 3.

### Step 1 - Assess the current state

Run in parallel (all hook-safe - none contains the literal `git commit` two-word string):
- `git status` (never `-uall` - it floods on large untracked trees)
- `git diff` and `git diff --cached` to see every unstaged + staged change
- `git log --oneline -5` to match the repo's existing message style (types, scope
  convention, tense)

If the diff is oversized (hundreds of lines), review with `git diff --stat` first, then
targeted per-file `git diff -- <path>`, to understand the change without blowing context
before you stage (Playbook 6).

Detect an in-progress operation before doing anything else: if
`git rev-parse -q --verify MERGE_HEAD` succeeds, or `.git/rebase-apply` / `.git/rebase-merge`
exists, you are mid-merge/rebase -> Playbook 4 (do NOT blindly commit).

### Step 2 - Stage ONLY relevant files (staging-safety gate)

Stage files that match the change and these categories:
- Source code (`.go`, `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.rs`, `.java`, `.css`,
  `.scss`, `.html`, `.sql`, `.sh`, `.yaml`, `.yml`, `.toml`, `.json`, `.proto`,
  `.graphql`, `.svelte`, `.vue`)
- Documentation (`.md` - README, docs, changelogs)
- Config directly related to the code (`tsconfig.json`, `package.json`, `go.mod`,
  `Cargo.toml`, `Makefile`, `Dockerfile`, `docker-compose.yml`)

**Staging-safety gate - for EACH file, before `git add <file>`, assert ALL hold:**
- [ ] NOT on the C-6 exclusion denylist (`.env*`, keys/secrets, binaries-unless-asset,
      `.gitignore`d)
- [ ] NOT a lockfile UNLESS a caller sanctioned it this run (C-7)
- [ ] This file is part of THIS change (in the diff you just reviewed), not pre-existing
      dirt
Any box fails -> exclude the file and note why. A likely-secret hit -> C-12 (report
file+pattern type, never the value; never stage it).

Stage individually by name: `git add path/to/file1 path/to/file2`. NEVER `git add -A` /
`git add .` (C-5). Partial-file staging (a file mixes wanted + unwanted hunks) ->
`git add -p <file>` (recipe in `references/commit-recipes.md`).

If the caller asked for a manifest+lockfile pair (C-7), stage BOTH now:
`git add package.json package-lock.json`.

### Step 3 - Write the commit message (through the quality gate)

Compose `type(scope): subject` per C-8. Run it through the Section 4 message-quality
checklist - ALL boxes must hold or rewrite. Add a body (blank line, then wrapped prose
explaining the WHY / the tradeoff) only when the change is non-trivial. Footers per C-15
(BREAKING CHANGE / Refs / Closes) when warranted; never AI attribution (C-3).

If the user provided `$ARGUMENTS`, use that as the message - but STILL enforce the
format rules AND strip any AI-attribution trailer line (C-4) before committing.

### Step 4 - Commit (the verbatim sentinel recipe)

Pre-commit assertion: `git diff --cached --name-only` MUST be non-empty. If it is empty,
STOP -> N/A (C-14), never an empty commit.

Use a HEREDOC for the message. Prefix the command with the `CLAUDE_COMMIT_SKILL=1`
sentinel - this is how the `block-raw-git-commit.sh` PreToolUse hook distinguishes a
legitimate skill-driven commit from a raw `git commit` (which it blocks). Always include
the sentinel:
```
CLAUDE_COMMIT_SKILL=1 git commit -m "$(cat <<'EOF'
type(scope): subject line here

Optional body here.
EOF
)"
```

If this commit is DENIED while it carries `CLAUDE_COMMIT_SKILL=1`, that is PROOF the
message carries an AI-attribution trailer (the content-guard fired) -> Playbook 1: strip
the trailer and re-commit. NEVER "escalate" the sentinel and NEVER reach for `--no-verify`.

### Step 5 - Confirm (post-commit verification)

- `git status` - the tree is clean except deliberately-ignored dirt.
- `git log -1` - confirm the intended files + message landed (this avoids the literal
  `git commit` two-word string, which the hook would otherwise deny even in a read-only
  inspection command).
- Report the short hash + subject and exactly which files were committed.

---

## 4. Message Quality Gate (anti-slop)

A commit message is a permanent, high-visibility AI-slop surface. It gets a blocking gate.

**Subject checklist - ALL must hold before Step 4, else rewrite:**
- [ ] Has a valid conventional type (C-8)
- [ ] Imperative mood (`add`, `fix`, `remove` - not `added` / `fixes` / `adding`)
- [ ] Describes the EFFECT / WHY, not the mechanical WHAT ("prevent double-charge on
      retry", not "changed the if statement")
- [ ] <= 72 characters
- [ ] No trailing period
- [ ] NOT a banned-generic subject (C-9)

**Body (only when non-trivial):** blank line after subject, wrap ~72-100 cols, explain the
WHY and any tradeoff / alternative rejected. Do not restate the diff. Plain hyphens (C-10).

**Footers:** ALLOWED - `BREAKING CHANGE: <desc>`, `Refs: <id>`, `Closes #<n>`, a real named
human `Co-Authored-By:` on explicit request (C-15). BANNED - ANY AI/tool attribution (C-3).

**Inline good/bad (fuller gallery in `references/commit-recipes.md`):**

| GOOD (why-focused, specific) | BAD (generic slop) |
|---|---|
| `fix(auth): prevent token refresh race on parallel requests` | `fix bug` |
| `refactor(api): collapse duplicate pagination into one helper` | `update files` |
| `feat(billing): add IDR PPN line to invoice totals` | `changes` |

---

## 5. Failure Playbooks

One-line protocols here; exact command sequences in `references/commit-recipes.md`.

| # | Situation | Recovery |
|---|---|---|
| 1 | **Denied despite the sentinel** | The message carries an AI-attribution trailer (content-guard fired first). Grep out the `Co-Authored-By: ...Claude/Anthropic` OR `Generated with ...Claude Code` line(s), re-run the HEREDOC commit. Never escalate the sentinel, never `--no-verify`. Cite `feedback_commit_skill_enforced` #238. |
| 2 | **Nothing to commit** | `git diff --cached --name-only` empty -> report N/A (C-14). If the user expected a change, say plainly that nothing was modified. Never invent a change, never empty-commit. |
| 3 | **Repo pre-commit hook reformats / rejects** | Hook MODIFIED files (prettier/lint-staged) -> re-stage the reformatted files BY NAME, re-commit. Hook REJECTED (commitlint) -> fix the message to satisfy it. NEVER `--no-verify` without asking Christopher (C-11 / PF-5). |
| 4 | **Mid-merge / rebase** | `.git/MERGE_HEAD` or `.git/rebase-apply|rebase-merge` present -> do NOT blindly commit. Report the in-progress state and let the caller resolve. A raw commit mid-conflict is hook-blocked anyway (C-2). |
| 5 | **Commit signing fails** (`commit.gpgSign=true`, non-interactive) | Report the signing failure plainly. Do NOT silently `--no-gpg-sign` to escape it - that changes the commit's trust properties without the user's knowledge. Ask. |
| 6 | **Oversized diff** | `git diff --stat` first, then targeted per-file `git diff -- <path>`. Review and stage in reviewed chunks; never blind-`git add .` a huge tree to "get it done". |

**DO / DON'T:**

| DO | DON'T |
|---|---|
| Prefix `CLAUDE_COMMIT_SKILL=1` on every commit (C-1) | Run a bare `git commit` (hook-denied) |
| Stage individually by name (C-5) | `git add -A` / `git add .` |
| Stage source + its lockfile together WHEN a caller says so (C-7) | Stage a lockfile on a plain feature commit |
| Strip AI trailers from `$ARGUMENTS` (C-4) | Pass a tainted override straight to the hook |
| Write a why-focused, specific subject (C-8/C-9) | Emit `update files` / `wip` / `changes` |
| Report file+pattern type for a secret (C-12) | Echo a secret value to "show what's staged" |
| Re-stage + retry when a repo hook reformats (C-11) | `--no-verify` past a husky/commitlint hook |

---

## 6. Verified Environment Facts (2026-07-03 - re-verify on drift)

- **git 2.54.0**, **jq 1.8.1** at `/usr/bin/jq`. Node toolchain (for the C-7 lockfile
  pairings): node v22.16.0, npm 10.9.2, pnpm 11.9.0, bun 1.3.12, yarn 1.22.22 (classic).
  `git add -p`, `git diff --stat`, `git ls-files --error-unmatch`, and the `commit.gpgSign`
  config key all verified present.
- **Seal-guard hook LIVE:** `~/.claude/hooks/block-raw-git-commit.sh` (5612 bytes,
  executable, mtime 2026-06-15), WIRED in `settings.json` `hooks.PreToolUse` under the
  `Bash` matcher alongside `triage-gate-hook.sh` and `block-docker-logs-over-ssh.sh`.
  Read from source this session.
- **Hook behavior (from source):** it greps the ENTIRE Bash command string. (1) The
  AI-attribution content-guard runs FIRST: a `git commit` whose message has a line-anchored
  `Co-Authored-By:.*([Cc]laude|[Aa]nthropic|noreply@anthropic)` or `(robot-emoji )?Generated
  with .*Claude Code` is DENIED - EVEN WITH the sentinel (it sed-normalizes `\n` escapes to
  real newlines first, so single-line `-m "...\nCo-Authored-By:..."` is caught too).
  (2) Then a raw `git commit` is denied unless the command contains `CLAUDE_COMMIT_SKILL=1`.
  A HUMAN `Co-Authored-By: Jane <jane@x.com>` PASSES; a mid-sentence prose mention PASSES
  (the anchor requires the trailer at line start). The hook ALSO gates `git merge` /
  `gh pr merge` behind `CLAUDE_MERGE_OK=1` - not /commit's concern.
- **Authoring gotcha (from the same source):** because the match runs against the whole
  command string, ANY Bash command that merely CONTAINS the literal two-word `git commit`
  sequence (a grep pattern, an `echo`, a `--grep="git commit"`) is treated as a commit and
  denied unless it carries the sentinel. `git log --grep=commit` (one word) is fine;
  `git log --grep="git commit"` is denied. When writing/debugging shell for this skill, use
  `git log -1`, `git show`, or a split pattern - avoid the adjacent two-word string.
- **gitleaks 8.21.2** at `~/.local/bin/gitleaks` exists, but it is **/preflight's** tool
  (its G7 / PF-8), NOT /commit's. /commit does NO secret scanning - its C-6 filename
  denylist is the front-line staging guard; the deep content scan is push-time.
- **/commit has 10 caller skills** (verified via grep): ship, preflight, e2e, qa, audit,
  case-study, project-init, ideate, oneshot-webapp, launch-strategy. It is the
  universal commit anchor; a change to the sentinel recipe (Step 4) or the individual-
  staging rule (C-5) ripples through all of them.
- **Memories encoded (cite, don't re-learn):** `feedback_commit_skill_enforced` (the
  sentinel + content-guard + the 32-commit pi-setup scrub), `feedback_no_long_hyphens`
  (C-10), `feedback_axios_supply_chain` (why lockfiles get scrutiny - cross-ref via
  /preflight G9), `feedback_skill_authoring_robustness` (this skill's bar).

## 7. References

- `references/commit-recipes.md` - conventional-commits type taxonomy with a worked
  example per type; per-scenario staging recipes (monorepo scope, `git add -p` partial
  staging, source+lockfile pair with the EXACT sanctioning caller phrasings from /ship
  S-13 and /preflight P4, generated/vendored files, deletions/renames); the expanded
  good/bad message gallery; and exact command sequences for every Section-5 playbook.
