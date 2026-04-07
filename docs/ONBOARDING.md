# Onboarding

A narrative walkthrough for setting up chilldawg-setup on a fresh machine. Reads top-to-bottom — no need to jump around. If you want the terse version, see [INSTALL.md](../INSTALL.md).

---

## Who is this for?

- **Future-Christopher** on a new laptop, after a reformat, or after a disaster
- Someone helping Christopher who needs to understand the machine before touching it
- A new collaborator who wants to mirror the environment to work alongside

If you're a third party, please ask before running `install.sh` on any machine that already has a `~/.claude/` directory — it will back things up but will also rewire what the live Claude Code session sees.

## Mental model

There are **three things** in your home directory after install:

1. **The repo itself** — wherever you cloned it (e.g., `~/dotfiles/chilldawg-setup/`). The source of truth.
2. **Symlinks in `$HOME`** — pointing into the repo. Editing `~/.bashrc` is the same as editing `<repo>/shell/.bashrc`. Same bytes, two names.
3. **Live runtime state** — `~/.claude/projects/`, `~/.claude/cache/`, `~/.claude/sessions/`, `~/.bash_history`, etc. Not in the repo. Not symlinked. Lives forever in `$HOME`.

`secrets.env` is its own special category: it lives at `~/.claude/secrets.env`, is chmod-600, is gitignored, and **never** enters the repo even by accident.

## Step-by-step

### 1. Sanity check the box

```bash
uname -a
which bash bun git
ls -la ~/.ssh/id_ed25519
```

You need bash, git, and bun. The SSH key is needed because `.bashrc` runs `ssh-add` on it. If you don't have the key yet, generate it (`ssh-keygen -t ed25519`) and add the public key to your GitHub.

### 2. Clone

```bash
mkdir -p ~/dotfiles
git clone <git-url> ~/dotfiles/chilldawg-setup
cd ~/dotfiles/chilldawg-setup
ls
```

You should see `claude/`, `shell/`, `config/`, `local/`, `docs/`, `README.md`, `INSTALL.md`, `install.sh`, `.env.example`, `tools-installed.md`, `.gitignore`.

### 3. Set up secrets BEFORE running install

This is the most important step. If you skip it, half the environment will silently fail.

```bash
mkdir -p ~/.claude
cp .env.example ~/.claude/secrets.env
chmod 600 ~/.claude/secrets.env
```

Open `~/.claude/secrets.env` in your editor. You'll see 8 empty `export FOO=""` lines. Fill each one in. Sources for each:

| Variable | Where to get it |
|---|---|
| `ANTHROPIC_API_KEY` | https://console.anthropic.com → API keys |
| `CLOUDFLARE_API_TOKEN` | https://dash.cloudflare.com → API Tokens. Scope: `Zone.DNS Edit` for the relevant zone. |
| `CLOUDFLARE_ZONE_ID` | Cloudflare dashboard → your zone → Overview tab → bottom right |
| `VPS_HOST` | Your VPS provider |
| `VPS_USER` | Probably `christopher` or whoever the VPS user is |
| `VPS_PASSWORD` | The VPS root/user password (consider switching to SSH key auth for production!) |
| `GH_TOKEN` | https://github.com/settings/tokens → classic PAT, scopes: `repo`, `read:org` |
| `NANOBANANA_API_KEY` | https://aistudio.google.com/apikey |

Save the file. Verify:
```bash
cat ~/.claude/secrets.env | grep -c '^export.*=".*[^"]"$'
# should print 8
```

### 4. Install the package set

Open `tools-installed.md` and look at the pacman section. The fastest path on Arch:

```bash
cd ~/dotfiles/chilldawg-setup

# extract package names from the markdown into a flat list
sed -n '/^## Arch Linux — explicitly installed/,/^##/p' tools-installed.md \
  | grep -E '^[a-z0-9]' | awk '{print $1}' > /tmp/pacman-list.txt

sudo pacman -S --needed - < /tmp/pacman-list.txt
```

For AUR packages you'll need a helper (`paru` or `yay`). For pipx/cargo/brew sections, copy the relevant commands by hand — they're small.

### 5. Run install.sh

```bash
./install.sh --dry-run     # see what it would do
./install.sh               # actually do it
```

The script is idempotent — re-running won't break anything. It backs up any existing `$HOME` file as `<file>.pre-stow` before symlinking.

After it runs, verify a few key symlinks:
```bash
ls -la ~/.bashrc                       # → ~/dotfiles/chilldawg-setup/shell/.bashrc
ls -la ~/.claude/CLAUDE.md             # → .../claude/CLAUDE.md
ls -la ~/.config/kitty/kitty.conf      # → .../config/kitty/kitty.conf
ls -la ~/.tmux.conf                    # → .../shell/.tmux.conf
```

### 6. Build the custom MCPs

```bash
cd ~/.claude/email-mcp
bun install
bun run build       # produces dist/

cd ~/.claude/whatsapp-mcp
bun install
bun run build
# If Baileys upstream broke something, run:
./patch-baileys.sh
```

For email-mcp, copy `config.example.json` to `config.json` and fill in your IMAP/SMTP credentials.

### 7. Reload the shell + verify secrets are loaded

```bash
exec bash
echo "${ANTHROPIC_API_KEY:0:15}"   # should print the Anthropic key prefix
echo "$VPS_HOST"                    # should print your VPS IP
echo "$GH_TOKEN" | head -c 8        # should print ghp_...
```

If any of these print empty: `~/.claude/secrets.env` either doesn't exist, isn't readable, or has malformed lines. Fix and `exec bash` again.

### 8. Launch Claude Code

```bash
claude
# or use the alias from .bashrc:
c
```

You should see:
- All 29 skills available (`/commit`, `/ship`, `/qa`, `/cloudflare-dns`, `/deploy-landing`, etc.)
- The custom hooks active (try `git commit -m "test"` from inside Claude Code — it should be blocked, redirecting you to `/commit`)
- Memory files auto-loaded
- Custom MCPs (email + whatsapp) listed in `claude mcp list`

### 9. Restart your terminal one more time

This catches anything that wasn't picked up by `exec bash`. Open a new window in your terminal emulator and confirm the prompt looks right (oh-my-posh themed via `chris.omp.json`).

## Troubleshooting

### `~/.claude/CLAUDE.md` is a regular file, not a symlink
You skipped step 5 or `install.sh` failed. Re-run `./install.sh`. If it complains about an existing backup, that's because you ran it twice and the backup from the first run is in the way — investigate `~/.claude/CLAUDE.md.pre-stow` before deleting it.

### `source: ~/.claude/secrets.env: No such file`
You skipped step 3. The shell will still work but env-var-dependent things will silently fail. Create the file.

### Skills don't load
Check `ls -la ~/.claude/skills/` — every entry should be a symlink into the repo. If they're regular files, something went wrong with the install. If they're empty dirs, the repo's skills/ is empty (re-clone).

### MCP servers fail to start
1. `bun --version` — need ≥ 1.0
2. `cd ~/.claude/email-mcp && bun install && bun run build` — re-build
3. `claude mcp list` — see which one is failing
4. `cat /tmp/claude-debug.log` if you launched with `-d`

### `git commit` works directly (not blocked)
The `block-raw-git-commit.sh` hook didn't load. Check `~/.claude/hooks/` is a symlink and that `~/.claude/settings.json` lists the hook (it should — settings.json is also symlinked from the repo).

### `~/.bashrc` modification gets lost on next install
You edited the live `~/.bashrc` while it was a symlink, which means you actually edited `<repo>/shell/.bashrc`. That's fine — but you should commit the change to the repo so it's tracked. Run `cd ~/dotfiles/chilldawg-setup && /commit`.

## What to do next

- Personalize `~/.claude/tasks/` — start tracking your own projects using the templates in `claude/tasks/TEMPLATE.md`
- Add machine-specific permissions to `~/.claude/settings.local.json` (which is per-machine, gitignored)
- Read `docs/ARCHITECTURE.md` to understand how the layers fit together
- Browse `claude/skills/` to see what's available — try a few

Welcome aboard.
