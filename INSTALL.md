# INSTALL — chilldawg-setup

Manual setup walkthrough. For a one-shot install on Arch, just run `./install.sh` (see step 5).

---

## 1. Prerequisites

Arch Linux is the assumed target. On other distros, the package manager step will fail and you'll need to translate package names manually.

You need at minimum:
- `git` — to clone the repo
- `bash` — the shell this whole environment is built around
- `bun` and/or `node` — the MCP servers and most skill scripts run on Bun
- A working `~/.ssh/id_ed25519` — used by `ssh-add` in `.bashrc`
- Optional: `pacman`, `pipx`, `cargo`, `linuxbrew` (the install script handles each conditionally)

## 2. Clone the repo

```bash
mkdir -p ~/dotfiles
git clone <git-url> ~/dotfiles/chilldawg-setup
cd ~/dotfiles/chilldawg-setup
```

The repo can live anywhere — `~/dotfiles/chilldawg-setup`, `~/repos/chilldawg-setup`, etc. The install script will follow whatever path you cloned to.

## 3. Set up secrets

```bash
mkdir -p ~/.claude
cp .env.example ~/.claude/secrets.env
chmod 600 ~/.claude/secrets.env
$EDITOR ~/.claude/secrets.env
```

Fill in **all 8** environment variables. Empty values will silently break things downstream. Refer to:
- `ANTHROPIC_API_KEY` — https://console.anthropic.com
- `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ZONE_ID` — Cloudflare dashboard, scope `Zone.DNS Edit`
- `VPS_HOST` / `VPS_USER` / `VPS_PASSWORD` — your hosting provider
- `GH_TOKEN` — https://github.com/settings/tokens (classic PAT, scopes: repo, read:org)
- `NANOBANANA_API_KEY` — https://aistudio.google.com/apikey

## 4. Install the package set

This step assumes Arch Linux. Inspect `tools-installed.md` for the full snapshot of what's expected.

```bash
# Native Arch packages (the big set — feel free to filter by hand first)
sudo pacman -S --needed $(awk '{print $1}' < tools-installed-pacman.txt)

# AUR packages — needs paru or yay
paru -S --needed $(awk '{print $1}' < tools-installed-aur.txt)

# Optional toolchains
pipx install nanobanana-mcp-server
cargo install <whatever you want from tools-installed.md cargo section>
```

The exact package names live in `tools-installed.md`. You can split them into `tools-installed-pacman.txt` / `tools-installed-aur.txt` by hand if you want pacman to consume them directly.

## 5. Symlink dotfiles into $HOME

The install script does this for you:

```bash
./install.sh
```

What it does:
- For every tracked file, backs up any existing `$HOME` target as `<file>.pre-stow`
- Creates a symlink from `$HOME/<path>` → `<this repo>/<path>`
- Skips anything already symlinked correctly

After it runs, `~/.bashrc`, `~/.tmux.conf`, `~/.config/kitty/kitty.conf`, `~/.claude/CLAUDE.md`, etc. will all be symlinks pointing into the repo. Edit them in either place — they refer to the same bytes.

## 6. Build the custom MCP servers

The Email MCP and WhatsApp MCP need their dependencies installed and a TypeScript build:

```bash
cd ~/.claude/email-mcp && bun install && bun run build
cd ~/.claude/whatsapp-mcp && bun install && bun run build
```

For email-mcp, you also need to copy `config.example.json` to `config.json` and fill in your IMAP/SMTP credentials.

For whatsapp-mcp, run `patch-baileys.sh` if a recent Baileys upgrade has broken anything (the script applies a known-good fix).

## 7. Restart your shell

```bash
exec bash
```

Confirm the secrets are loaded:
```bash
echo "$ANTHROPIC_API_KEY" | head -c 15  # should print the Anthropic key prefix
echo "$VPS_HOST"                        # should print your VPS IP
```

## 8. Verify Claude Code

```bash
claude  # or `c` (alias defined in .bashrc)
```

Claude Code should pick up the symlinked `~/.claude/CLAUDE.md`, load all 29 skills, mount the configured MCPs, and apply the hooks.

To verify the global hooks:
```bash
ls -la ~/.claude/hooks/   # should be a symlink into the repo
git commit -m "test"      # should be blocked by block-raw-git-commit.sh — use /commit instead
```

## Troubleshooting

- **`source: ~/.claude/secrets.env: No such file`** — you skipped step 3. Create the file.
- **Symlinks point to the wrong place** — re-run `./install.sh`. It's idempotent.
- **Skills not loading in Claude Code** — check `ls -la ~/.claude/skills/` and confirm they're symlinks. If broken, re-run install.
- **Bun MCP fails to start** — `bun --version` (need ≥1.0). Then `bun install` inside the MCP dir.
- **`gh auth` fails** — `GH_TOKEN` env var not set. Check `~/.claude/secrets.env` is sourced (`echo $GH_TOKEN`).

See [docs/ONBOARDING.md](./docs/ONBOARDING.md) for a more narrative walkthrough.
