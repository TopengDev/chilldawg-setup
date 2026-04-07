#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# chilldawg-setup install script
#
# Idempotent. Backs up existing files as <file>.pre-stow before symlinking.
# Re-running is safe — already-correct symlinks are skipped.
#
# Usage:
#   ./install.sh             # symlink everything
#   ./install.sh --dry-run   # print what would happen, change nothing
#   ./install.sh --force     # overwrite existing symlinks (still backs up regular files)
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

# ── helpers ─────────────────────────────────────────────────────────────────
log()  { printf '\033[36m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[31m[err]\033[0m %s\n' "$*" >&2; }

# link <repo-relative-source> <home-relative-target>
link() {
  local src="$REPO_DIR/$1"
  local dst="$HOME/$2"

  if [ ! -e "$src" ]; then
    warn "missing source (skipping): $1"
    return 0
  fi

  # Already a symlink to the right place — skip
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    log "ok (already linked): ~/$2"
    return 0
  fi

  # Existing target needs handling
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$FORCE" -eq 1 ] && [ -L "$dst" ]; then
      [ "$DRY_RUN" -eq 0 ] && rm "$dst"
      log "removed wrong symlink: ~/$2"
    else
      local backup="${dst}.pre-stow"
      if [ -e "$backup" ]; then
        warn "backup already exists at ~/${2}.pre-stow — leaving original alone"
        return 1
      fi
      [ "$DRY_RUN" -eq 0 ] && mv "$dst" "$backup"
      log "backed up existing ~/$2 -> ~/${2}.pre-stow"
    fi
  fi

  # Make parent dir if needed
  local parent
  parent="$(dirname "$dst")"
  if [ ! -d "$parent" ]; then
    [ "$DRY_RUN" -eq 0 ] && mkdir -p "$parent"
    log "mkdir -p ~/$(dirname "$2")"
  fi

  # Create the symlink
  [ "$DRY_RUN" -eq 0 ] && ln -s "$src" "$dst"
  log "linked ~/$2 -> $1"
}

# ── secrets check ───────────────────────────────────────────────────────────
if [ ! -f "$HOME/.claude/secrets.env" ]; then
  warn "~/.claude/secrets.env does not exist."
  warn "Create it from the template before continuing:"
  warn "  mkdir -p ~/.claude"
  warn "  cp $REPO_DIR/.env.example ~/.claude/secrets.env"
  warn "  chmod 600 ~/.claude/secrets.env"
  warn "  \$EDITOR ~/.claude/secrets.env"
  warn ""
  read -r -p "Continue without secrets.env? Some things will not work until you create it. [y/N] " ans
  case "$ans" in
    y|Y|yes) ;;
    *) exit 1 ;;
  esac
fi

# ── shell dotfiles ──────────────────────────────────────────────────────────
log "=== shell ==="
link shell/.bashrc       .bashrc
link shell/.bash_profile .bash_profile
link shell/.tmux.conf    .tmux.conf
link shell/.gitconfig    .gitconfig

# ── claude code ─────────────────────────────────────────────────────────────
log "=== claude code (~/.claude) ==="
link claude/CLAUDE.md     .claude/CLAUDE.md
link claude/settings.json .claude/settings.json
link claude/statusline.sh .claude/statusline.sh
link claude/memory        .claude/memory
link claude/skills        .claude/skills
link claude/hooks         .claude/hooks

# email-mcp + whatsapp-mcp: per-child symlinks so node_modules/ and dist/
# (untracked, machine-local) stay as real dirs alongside the symlinked source.
mkdir -p "$HOME/.claude/email-mcp" "$HOME/.claude/whatsapp-mcp"
link claude/email-mcp/src                 .claude/email-mcp/src
link claude/email-mcp/package.json        .claude/email-mcp/package.json
link claude/email-mcp/package-lock.json   .claude/email-mcp/package-lock.json
link claude/email-mcp/tsconfig.json       .claude/email-mcp/tsconfig.json
link claude/email-mcp/config.example.json .claude/email-mcp/config.example.json

link claude/whatsapp-mcp/src               .claude/whatsapp-mcp/src
link claude/whatsapp-mcp/package.json      .claude/whatsapp-mcp/package.json
link claude/whatsapp-mcp/package-lock.json .claude/whatsapp-mcp/package-lock.json
link claude/whatsapp-mcp/tsconfig.json     .claude/whatsapp-mcp/tsconfig.json
link claude/whatsapp-mcp/patch-baileys.sh  .claude/whatsapp-mcp/patch-baileys.sh

# Note: claude/tasks/ in the repo is a TEMPLATE — do NOT symlink it. The live
# ~/.claude/tasks/ is per-machine and stays out of the repo.

# ── ~/.config dirs ──────────────────────────────────────────────────────────
log "=== ~/.config ==="
link config/kitty       .config/kitty
link config/wezterm     .config/wezterm
link config/btop        .config/btop
link config/cmus        .config/cmus
link config/mpv         .config/mpv
link config/lazygit     .config/lazygit
link config/lazydocker  .config/lazydocker
link config/gh          .config/gh
link config/glow        .config/glow
link config/htop        .config/htop
link config/bottom      .config/bottom
link config/neofetch    .config/neofetch
# qutebrowser: per-child links so personal state (bookmarks, qsettings,
# quickmarks, autoconfig.yml, history, sessions) stays as real machine-local data.
mkdir -p "$HOME/.config/qutebrowser"
link config/qutebrowser/config.py    .config/qutebrowser/config.py
link config/qutebrowser/scripts      .config/qutebrowser/scripts
link config/qutebrowser/greasemonkey .config/qutebrowser/greasemonkey

# ── oh-my-posh config (lives in ~/Documents per christopher's setup) ────────
link config/oh-my-posh/chris.omp.json Documents/chris.omp.json

# ── ~/.local/bin custom scripts ─────────────────────────────────────────────
log "=== ~/.local/bin ==="
link local/bin/toggle-topbar .local/bin/toggle-topbar

# ── nvim — sibling clone of TopengDev/nvim_setup ────────────────────────────
# nvim config is maintained as its OWN git repo (TopengDev/nvim_setup) so we
# clone it as a sibling rather than absorbing it into chilldawg-setup. This
# preserves its independent history and lets you push nvim changes upstream
# without going through this dotfiles repo.
log "=== ~/.config/nvim (sibling clone) ==="
NVIM_REPO_URL="https://github.com/TopengDev/nvim_setup.git"
NVIM_TARGET="$HOME/.config/nvim"
if [ -d "$NVIM_TARGET/.git" ]; then
  log "nvim already a git repo at ~/.config/nvim — skipping clone (run 'git -C $NVIM_TARGET pull' to update)"
elif [ -e "$NVIM_TARGET" ] || [ -L "$NVIM_TARGET" ]; then
  warn "~/.config/nvim exists but is not a git repo — leaving alone. Move it aside if you want to clone fresh."
else
  if [ "$DRY_RUN" -eq 0 ]; then
    git clone "$NVIM_REPO_URL" "$NVIM_TARGET"
  fi
  log "would clone $NVIM_REPO_URL -> ~/.config/nvim"
fi

# ── done ────────────────────────────────────────────────────────────────────
echo ""
log "install complete."
if [ "$DRY_RUN" -eq 1 ]; then
  log "(dry run — no changes made)"
fi
echo ""
log "Next steps:"
log "  1. exec bash      # reload your shell"
log "  2. echo \$VPS_HOST # confirm secrets.env is sourced"
log "  3. claude         # launch Claude Code"
