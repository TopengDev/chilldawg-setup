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

Fill in the variables you need. The first 8 are core (empty values will silently break things downstream); the last 4 are ISI/fitest work logins, only needed if you run the QA/fitest flows. Refer to:
- `ANTHROPIC_API_KEY` — https://console.anthropic.com
- `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ZONE_ID` — Cloudflare dashboard, scope `Zone.DNS Edit`
- `VPS_HOST` / `VPS_USER` / `VPS_PASSWORD` — your hosting provider
- `GH_TOKEN` — https://github.com/settings/tokens (classic PAT, scopes: repo, read:org)
- `NANOBANANA_API_KEY` — https://aistudio.google.com/apikey
- `ISI_EMAIL` / `ISI_PASSWORD` / `FITEST_USER` / `FITEST_PASSWORD` — ISI / BMS WebAdmin + fitest portal credentials (work-specific; leave blank if unused)

## 4. Install the package set

This step assumes Arch Linux. The full snapshot of what's expected lives in `tools-installed.md` — there are no pre-split `.txt` package lists in the repo; extract the package names straight from the markdown with `sed` (same approach as [ONBOARDING.md](./docs/ONBOARDING.md) step 4):

```bash
# Native Arch packages — extract names from the "explicitly installed" section
sed -n '/^## Arch Linux — explicitly installed/,/^##/p' tools-installed.md \
  | grep -E '^[a-z0-9]' | awk '{print $1}' > /tmp/pacman-list.txt
sudo pacman -S --needed - < /tmp/pacman-list.txt

# AUR packages — needs a helper (paru or yay). Extract from the AUR section:
sed -n '/^## Arch Linux — AUR/,/^##/p' tools-installed.md \
  | grep -E '^[a-z0-9]' | awk '{print $1}' > /tmp/aur-list.txt
paru -S --needed - < /tmp/aur-list.txt

# Optional toolchains
pipx install nanobanana-mcp-server
cargo install <whatever you want from the tools-installed.md cargo section>
```

The exact package names (with versions) live in `tools-installed.md`. The `sed` snippets above slice the relevant section out of that file and feed the bare names to your package manager.

## 5. Symlink dotfiles into $HOME

The install script does this for you:

```bash
./install.sh
```

What it does:
- For every tracked file, backs up any existing `$HOME` target as `<file>.pre-stow`
- Creates a symlink from `$HOME/<path>` → `<this repo>/<path>`
- Skips anything already symlinked correctly
- Links `claude/scripts` (the triage/spawn pipeline) and `config/systemd/user` (the journal-audit + qb-proxy-doctor timers), then reloads systemd and enables those timers
- **Copies** `settings.json` (does not link it) if `~/.claude/settings.json` is absent — see the caveat below

After it runs, `~/.bashrc`, `~/.tmux.conf`, `~/.config/kitty/kitty.conf`, `~/.claude/CLAUDE.md`, etc. will all be symlinks pointing into the repo. Edit them in either place — they refer to the same bytes.

> **settings.json is the one exception — it is copied, not symlinked.** Claude Code rewrites `~/.claude/settings.json` live (model selection, plugin auth state, etc.). A symlink would push that churn back into the repo, and a stale committed copy would clobber live changes on the next install. So `install.sh` only restores a `settings.json` when none exists, and otherwise leaves the live one alone. If you intentionally change the repo's `claude/settings.json` (e.g. add a plugin) and want it on this machine, re-sync by hand: `cp claude/settings.json ~/.claude/settings.json` (and vice-versa to capture live changes back into the repo).

> **systemd user timers don't auto-start on symlink.** `install.sh` runs `systemctl --user daemon-reload && systemctl --user enable --now journal-audit.timer qb-proxy-doctor.timer` for you, but if that step warned (e.g. no user-session bus during a headless install), run it manually after your first graphical/login session. Check with `systemctl --user list-timers`.

## 6. Build the custom MCP servers

The Email MCP and WhatsApp MCP need their dependencies installed and a TypeScript build:

```bash
cd ~/.claude/email-mcp && bun install && bun run build
cd ~/.claude/whatsapp-mcp && bun install && bun run build
```

For email-mcp, you also need to copy `config.example.json` to `config.json` and fill in your IMAP/SMTP credentials.

For whatsapp-mcp, run `patch-baileys.sh` if a recent Baileys upgrade has broken anything (the script applies a known-good fix).

Finally, tell Claude Code how to launch the custom email MCP. The live `~/.claude/.mcp.json` is gitignored (machine-specific absolute paths), so seed it from the sanitized template:

```bash
cp claude/.mcp.json.example ~/.claude/.mcp.json
# edit ~/.claude/.mcp.json and replace <HOME> with your absolute home path,
# e.g. sed -i "s#<HOME>#$HOME#g" ~/.claude/.mcp.json
```

The template wires only the local `email` server (pointing at `email-mcp/dist/index.js`); it carries **no secrets** — the email credentials live in `email-mcp/config.json`. The marketplace plugins (attn, whatsapp, etc.) are handled separately in step 6b below.

## 6b. Add the non-official plugin marketplaces

`settings.json` enables several plugins that do **not** live in the official Claude Code marketplace (`attn@s0nderlabs`, `whatsapp@TopengDev`, `nativ`, `ui-ux-pro-max`). Before Claude Code can install/enable them, register their marketplaces once:

```bash
claude plugin marketplace add s0nderlabs/marketplace            # provides: attn, nativ deps
claude plugin marketplace add TopengDev/whatsapp-marketplace    # provides: whatsapp
claude plugin marketplace add s0nderlabs/nativ                  # provides: nativ
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill  # provides: ui-ux-pro-max
```

These four `extraKnownMarketplaces` are already declared in `settings.json`, so on launch Claude Code knows where each enabled plugin comes from; the commands above make the marketplaces locally available so the plugins actually resolve. (The official-marketplace plugins — `ralph-loop`, `context7`, `playwright`, `gopls-lsp` — need no extra step.)

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

Claude Code should pick up the symlinked `~/.claude/CLAUDE.md`, load all 36 skills, mount the configured MCPs, and apply the hooks.

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
