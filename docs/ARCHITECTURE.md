# Architecture

How chilldawg-setup fits together. Read this if you want to understand *why* things are organized this way before changing them.

## Big picture

This repo backs three layered concerns at once:

1. **Shell environment** — bash, tmux, terminal emulators, prompt, package set
2. **Editor + tooling** — nvim (sibling repo, see [External configs](#external-configs)), qutebrowser, the various TUI utilities (lazygit, btop, etc.)
3. **Claude Code configuration** — global instructions, memory, custom skills, hooks, custom MCP servers

These three layers compose into a cohesive AI-augmented development environment where the human (Christopher) and Claude Code work in tight collaboration. The dotfiles repo is the source of truth for all three layers; `$HOME` is a symlink farm pointing back into here.

## Layout rationale

```
chilldawg-setup/
├── claude/        ← mirrors ~/.claude/
├── shell/         ← mirrors ~ for the dotfiles
├── config/        ← mirrors ~/.config/
└── local/bin/     ← mirrors ~/.local/bin/
```

The naming intentionally collapses "what kind of thing" into a top-level directory:
- Anything Claude-Code-related → `claude/`
- Anything that's a shell rc → `shell/`
- Anything in `~/.config/<tool>/` → `config/<tool>/`
- Custom scripts → `local/bin/`

`install.sh` walks the right files in each section and symlinks them to the corresponding `$HOME` location.

## Secrets architecture

**Hard rule:** no secrets in this repo. Ever.

The system works like this:

1. `~/.claude/secrets.env` is a chmod-600 file that lives **outside** the repo and is **gitignored** even if accidentally placed inside. It contains the environment variables enumerated in `.env.example` — 8 core (`ANTHROPIC_API_KEY`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ZONE_ID`, `VPS_HOST`, `VPS_USER`, `VPS_PASSWORD`, `GH_TOKEN`, `NANOBANANA_API_KEY`) plus optional ISI/fitest work logins (`ISI_EMAIL`, `ISI_PASSWORD`, `FITEST_USER`, `FITEST_PASSWORD`).

2. `~/.bashrc` ends with `[ -f ~/.claude/secrets.env ] && source ~/.claude/secrets.env`. Every interactive shell gets these env vars for free.

3. Files that previously contained literal secrets (`CLAUDE.md`, `cloudflare-dns/SKILL.md`, `deploy-landing/SKILL.md`, `settings.local.json`) have been rewritten to reference `$VAR_NAME` instead of the literal value. Bash code blocks that get executed by Claude Code skills run in a shell with secrets.env already sourced, so variable expansion just works. The `claude/memory/` directory — which holds private operational context and credential-by-reference notes — is **untracked entirely** (gitignored), so memory never enters git in the first place; the files live on disk, accessed via the `~/.claude/memory` symlink, but are not versioned.

4. `.env.example` ships in the repo as a template — same variable names, empty values. New machines copy it to `~/.claude/secrets.env` and fill in real values during onboarding.

This means: **the repo can be public, private, mirrored, forked, or accidentally pasted into a chat — and no credentials leak.** A leak would require either secrets.env itself escaping the machine, or someone re-introducing a literal secret to a tracked file (the gitignore + a pre-commit grep can catch that).

## Claude Code integration

`~/.claude/` is where Claude Code reads everything. Files in there that this repo manages:

| Path | Purpose | Symlinked? |
|------|---------|------------|
| `CLAUDE.md` | Global instructions loaded into every conversation | ✓ |
| `settings.json` | Plugins enabled, hooks, model config | ✗ (**copied, not linked** — Claude Code rewrites it live; `install.sh` restores it if absent, re-sync manually) |
| `settings.local.json` | Per-machine permission allowlist | ✗ (gitignored, sanitized live) |
| `statusline.sh` | Custom status line | ✓ |
| `memory/` | Live long-term memory `.md` files (auto-loaded; `autoMemoryDirectory`) | ◐ (dir is symlinked to the repo, but its **contents are gitignored** — private + machine-local, not versioned) |
| `skills/` | 36 custom skills (`/commit`, `/ship`, `/qa`, etc.) | ✓ |
| `scripts/` | triage/spawn pipeline (`spawn-worker.sh`, `check-triage.sh`, `journal-audit.py`, …) | ✓ |
| `hooks/` | PreToolUse hook scripts (e.g. `block-raw-git-commit.sh`) | ✓ |
| `email-mcp/` | Custom MCP server source (Outlook + Hostinger SMTP/IMAP) | ✓ |
| `whatsapp-mcp/` | Custom MCP server source (Baileys-based, with patch script) | ✓ |
| `tasks/` | Live task tracking | ✗ (the repo's `claude/tasks/` is a template only) |
| `secrets.env` | Real credentials | ✗ (chmod 600, gitignored) |
| `projects/`, `sessions/`, `cache/`, `file-history/`, `history.jsonl`, `plugins/`, etc. | Runtime state | ✗ (Tier 3, gitignored) |

Anything marked "Symlinked? ✓" lives **physically** inside this repo. The path in `$HOME` is a symbolic link.

Anything marked "Symlinked? ✗" lives outside the repo intentionally — either because it's per-machine state (`tasks/`, `settings.local.json`), runtime artifacts (`projects/`, `cache/`), or contains secrets (`secrets.env`, `.credentials.json`).

## The skills layer

Skills are markdown files that Claude Code loads as on-demand procedures. The full set lives in `claude/skills/`; each subdirectory is one skill, and the `SKILL.md` file inside is the entry point.

Some skills are simple (one-shot procedures, e.g. `/commit`); others are multi-step orchestrations (`/ship` runs simplify → security review → test → version → commit → preflight → push). The most operationally important skills:

- `/commit` — generates a clean conventional commit message and runs `git commit`. Required because `block-raw-git-commit.sh` blocks raw `git commit` invocations.
- `/preflight` — runs the same checks CI would run before pushing.
- `/ship` — full pipeline: simplify, security, test, version, commit, preflight, push.
- `/cloudflare-dns` — manages `*-landing-page.aenoxa.com` DNS records via the Cloudflare API.
- `/deploy-landing` — deploys a Next.js landing page build to the VPS via `sshpass + nginx + pm2 + certbot`.
- `/qa` — adversarial QA across 10 dimensions, severity-graded report.
- `/whatsapp` — WhatsApp messaging via the custom MCP.
- `/agent-browser` — browser automation via qutebrowser (preferred over Playwright).

All skills that make outbound API calls have been written to use `$ENV_VAR` references, not literal secrets. The shell that executes the bash blocks has `secrets.env` sourced, so expansion just works.

## The MCP layer

Two custom MCP servers ship in the repo:

### email-mcp (`claude/email-mcp/`)
A TypeScript MCP server providing 25 email tools (read inbox, send, IMAP-append-to-Sent after SMTP, search, manage folders). Supports Outlook OAuth and Hostinger IMAP/SMTP. The build artifact (`dist/`) is gitignored — `bun install && bun run build` regenerates it on each machine. `config.example.json` is the credential template; the real `config.json` is gitignored.

### whatsapp-mcp (`claude/whatsapp-mcp/`)
A TypeScript MCP server wrapping Baileys for WhatsApp Web protocol. Provides ~50 tools (send message/media/location, list chats/groups/contacts, mute, react, search, manage notifications). `patch-baileys.sh` applies a known-good fix when upstream Baileys breaks something — used during version upgrades.

Both MCPs are mounted by Claude Code via `settings.json` plugin entries (or via dynamic `.mcp.json`, which is gitignored as Tier 3).

## The hooks layer

Hooks fire on events in Claude Code. The one that matters here:

- **`block-raw-git-commit.sh`** — a `PreToolUse` hook that intercepts any `Bash(git commit ...)` invocation that didn't come from the `/commit` skill. Blocks the call with a friendly error pointing to `/commit`. This is how Christopher enforces consistent commit messages across all sessions, all branches, and all repos.

The hook itself is a portable bash script — no dependencies, no secrets, no machine-specific paths.

## The tasks layer (template only)

`~/.claude/tasks/` is where the `/tasks` skill stores per-project task lists. This data is **per-machine, mutable, and somewhat sensitive** (it can contain client info, deadlines, priorities, etc.) — so the live `tasks/` dir is **not symlinked** into the repo.

Instead, `claude/tasks/` in the repo contains:
- `INDEX.md` — template dashboard schema
- `TEMPLATE.md` — template project file (frontmatter + section headers)
- One stripped skeleton per existing live project file (so the schema is illustrated for future-self)

A fresh machine starts with these templates and grows its own live `~/.claude/tasks/` over time.

## The shell layer

`shell/.bashrc` orchestrates:
1. The `c` function (Claude Code launcher with optional `-M` WhatsApp mode and `-D` skip-permissions mode)
2. PATH augmentation for bun, flutter, chrome, webstorm, tor browser, go, gpt, local/bin, linuxbrew, cargo, foundry
3. NVM bootstrap
4. ssh-agent + ssh-add for `~/.ssh/id_ed25519`
5. OSC 7 prompt hook so tmux knows the current working directory
6. **`source ~/.claude/secrets.env` at the very end** — this is what makes secrets available to every shell

Removing or reordering anything in `.bashrc` requires care; the secrets source line MUST run last so it can override anything earlier.

## External configs

Some configuration is intentionally **not** owned by chilldawg-setup. These configs live as their own repos with their own upstreams, and `install.sh` clones them as siblings into `~/.config/`:

| Config | Upstream | Why separate |
|---|---|---|
| `~/.config/nvim/` | https://github.com/TopengDev/nvim_setup | Has independent history and is portable across machines that don't otherwise use chilldawg-setup. Lives as a standalone repo so changes can be pushed without going through this dotfiles repo. |

To update a sibling-cloned config:
```bash
cd ~/.config/nvim && git pull
```

To make changes to a sibling config and push them upstream:
```bash
cd ~/.config/nvim
$EDITOR init.lua    # edit normally
git add init.lua
git commit -m "your message"   # use /commit if you have it
git push
```

If you're starting from a fresh machine and `~/.config/nvim/` already exists (e.g. from a previous install), `install.sh` will skip the clone — it never overwrites a directory it didn't create.

## How a new machine bootstraps

1. Clone this repo somewhere
2. Create `~/.claude/secrets.env` from `.env.example`, fill in real values, chmod 600
3. Install the package set from `tools-installed.md`
4. Run `./install.sh` to symlink everything
5. `bun install && bun run build` inside `claude/email-mcp/` and `claude/whatsapp-mcp/`
6. `exec bash` to reload the shell
7. `claude` to launch Claude Code

The first interactive `claude` session will see all 36 skills, the global hooks, the plugin set, and the MCPs — exactly the same as on the source machine. Memory is the one exception: it is private + untracked (see [Secrets architecture](#secrets-architecture) / `.gitignore`), so a fresh machine starts with an empty `~/.claude/memory` and grows its own.
