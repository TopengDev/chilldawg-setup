---
name: commit
description: Commit latest changes with a clean, conventional commit message. Use when the user asks to commit, save changes, or says /commit.
argument-hint: [optional commit message override]
allowed-tools: Bash, Read, Glob, Grep
---

## Commit Workflow

Follow these steps exactly:

### 1. Assess the current state

Run in parallel:
- `git status` (never use `-uall`)
- `git diff` and `git diff --cached` to see all changes
- `git log --oneline -5` to match the repo's commit message style

### 2. Stage ONLY relevant files

Stage files that match these categories:
- Source code files (e.g., `.go`, `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.rs`, `.java`, `.css`, `.scss`, `.html`, `.sql`, `.sh`, `.yaml`, `.yml`, `.toml`, `.json`, `.proto`, `.graphql`, `.svelte`, `.vue`)
- Documentation files (`.md` only — README, docs, changelogs)
- Config files directly related to the code (e.g., `tsconfig.json`, `package.json`, `go.mod`, `Cargo.toml`, `Makefile`, `Dockerfile`, `docker-compose.yml`)

DO NOT stage:
- `.env`, `.env.*`, or any environment variable files
- Credentials, secrets, API keys, private keys
- Binary files, images, videos, fonts
- Lock files unless the user explicitly asks
- Anything in `.gitignore`

Stage files individually by name — never use `git add -A` or `git add .`

### 3. Write the commit message

- Use conventional commits format: `type(scope): description`
  - Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`, `ci`, `build`
  - Scope is optional but preferred when clear
- Keep the subject line under 72 characters
- Focus on the **why**, not the **what**
- Add a body (separated by blank line) only if the change is non-trivial
- NEVER include any Co-Authored-By lines
- NEVER attribute Claude or any AI in the commit message
- NEVER add signatures, tags, or footers of any kind

If the user provided $ARGUMENTS, use that as the commit message instead of generating one (still follow formatting rules).

### 4. Commit

Use a HEREDOC for the message. Prefix the command with the `CLAUDE_COMMIT_SKILL=1` sentinel — this is how the `block-raw-git-commit.sh` PreToolUse hook distinguishes a legitimate skill-driven commit from a raw `git commit` (which it blocks). Always include the sentinel:
```
CLAUDE_COMMIT_SKILL=1 git commit -m "$(cat <<'EOF'
type(scope): subject line here

Optional body here.
EOF
)"
```

### 5. Confirm

Run `git status` after committing and report what was committed.
