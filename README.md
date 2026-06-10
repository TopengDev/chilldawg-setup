# chilldawg-setup

Christopher's complete personal development environment — Claude Code configuration, custom skills, MCP servers, terminal setup, editor config, and shell dotfiles. The repo is the source of truth; files in `$HOME` are symlinks pointing back into here.

```
chilldawg-setup/
├── claude/             Claude Code config, memory, skills, hooks, MCPs (mirrors ~/.claude/)
│   ├── CLAUDE.md         global instructions (sanitized — secrets via ~/.claude/secrets.env)
│   ├── settings.json     enabled plugins, hooks, model config
│   ├── statusline.sh     custom statusline script
│   ├── memory/           live long-term memory (private — untracked, gitignored)
│   ├── skills/           36 custom skills (/commit, /ship, /qa, etc.)
│   ├── hooks/            block-raw-git-commit.sh and friends
│   ├── email-mcp/        custom Email MCP server (Outlook + Hostinger SMTP/IMAP)
│   ├── whatsapp-mcp/     custom WhatsApp MCP server (forked + patched Baileys)
│   └── tasks/            template task tracking schema (live data NOT committed)
├── shell/              .bashrc, .bash_profile, .tmux.conf, .gitconfig
├── config/             ~/.config/* — kitty, wezterm, btop, cmus, mpv, lazygit, lazydocker,
│                       gh, glow, htop, bottom, neofetch, qutebrowser, oh-my-posh
│                       (nvim is sibling-cloned by install.sh from TopengDev/nvim_setup)
├── local/bin/          custom shell scripts (toggle-topbar)
├── docs/
│   ├── ARCHITECTURE.md   how the pieces fit together
│   └── ONBOARDING.md     fresh-machine bootstrap walkthrough
├── tools-installed.md  pacman/npm/cargo/pipx/brew package snapshot
├── install.sh          bootstrap script — symlinks repo files into $HOME
├── INSTALL.md          manual install instructions
├── .env.example        secrets template (real secrets live in ~/.claude/secrets.env)
└── .gitignore          excludes runtime state, secrets, build artifacts
```

## Stack overview

- **OS:** Arch Linux
- **Shell:** bash + oh-my-posh + custom prompt (`chris.omp.json`)
- **Terminal:** kitty primary, wezterm available
- **Multiplexer:** tmux
- **Editor:** nvim with lazy.nvim (config is its own repo: TopengDev/nvim_setup, sibling-cloned by install.sh)
- **Browser (programmatic):** qutebrowser via custom `/agent-browser` skill
- **AI:** Claude Code with custom plugins (attn, whatsapp, ralph-loop, ui-ux-pro-max, context7, playwright, nativ)
- **Custom MCPs:** email-mcp (Outlook/Hostinger), whatsapp-mcp (Baileys-based)
- **Languages:** TypeScript/Bun, Go, Rust, Python, Flutter

## Quick install (existing Arch box)

```bash
git clone <git-url> ~/dotfiles/chilldawg-setup
cd ~/dotfiles/chilldawg-setup
cp .env.example ~/.claude/secrets.env
chmod 600 ~/.claude/secrets.env
$EDITOR ~/.claude/secrets.env  # fill in real values
./install.sh
```

`install.sh` is non-destructive: it backs up any existing target file as `<file>.pre-stow` before symlinking.

## Manual install

See [INSTALL.md](./INSTALL.md) for the step-by-step walkthrough — useful when you want to understand each step or are setting up a non-Arch system.

## Architecture

See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for how Claude Code, the custom skills, the MCP servers, the hooks, and the shell environment all fit together.

## Onboarding

If you're picking this up fresh (e.g., new machine, future-self, or someone else helping out), start with [docs/ONBOARDING.md](./docs/ONBOARDING.md).

## Contributing

This is a personal dotfiles repo. PRs are not expected — but if you spot something useful (a portability bug, a security issue, a stale tool), open an issue.

## Secrets

**No secrets are tracked in this repo.** All credentials live in `~/.claude/secrets.env` (gitignored, chmod 600). Files that previously held literal tokens have been rewritten to reference the env vars instead. The live memory dir (`claude/memory/`) is private and **untracked entirely** (gitignored) — it never enters git. See `.env.example` for the full list of expected variables.

If you find a secret in this repo, that's a bug — please flag it.
