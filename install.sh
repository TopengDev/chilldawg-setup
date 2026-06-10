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
#   ./install.sh --ci        # non-interactive (no prompts); also via CHILLDAWG_CI=1
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
FORCE=0
CI=0

# CI can also be requested via env (CHILLDAWG_CI=1) so the GitHub Action can set it
# without juggling flags.
[ "${CHILLDAWG_CI:-0}" = "1" ] && CI=1

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --ci) CI=1 ;;   # non-interactive: never prompt (e.g. for CI / headless). Proceeds without secrets.env.
    -h|--help)
      sed -n '2,16p' "$0"
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
  if [ "$CI" -eq 1 ]; then
    warn "--ci / CHILLDAWG_CI set — proceeding WITHOUT secrets.env (non-interactive)."
  elif [ ! -t 0 ]; then
    # No TTY and not explicitly --ci: refuse rather than hang on a read with no stdin.
    err "no secrets.env and no TTY to prompt. Re-run with --ci to proceed non-interactively."
    exit 1
  else
    read -r -p "Continue without secrets.env? Some things will not work until you create it. [y/N] " ans
    case "$ans" in
      y|Y|yes) ;;
      *) exit 1 ;;
    esac
  fi
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
link claude/statusline.sh .claude/statusline.sh
link claude/skills        .claude/skills
link claude/hooks         .claude/hooks
link claude/scripts       .claude/scripts   # triage/spawn pipeline (spawn-worker.sh, check-triage.sh, journal-audit.py, …)

# settings.json is NOT symlinked: Claude Code rewrites it live (model, plugin
# auth state, etc.), so a symlink would push churn back into the repo and a
# stale committed copy would clobber live changes on the next install. Instead
# we restore *a* settings.json only if the machine doesn't already have one, and
# leave re-syncing intentional changes to a manual `cp` (see INSTALL.md).
if [ ! -e "$HOME/.claude/settings.json" ]; then
  [ "$DRY_RUN" -eq 0 ] && { mkdir -p "$HOME/.claude"; cp "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"; }
  log "copied settings.json -> ~/.claude/settings.json (copied, NOT linked — Claude Code rewrites it live; re-sync manually)"
else
  log "ok (settings.json already present — left as-is; re-sync manually if the repo copy changed)"
fi

# Memory: ~/.claude/memory symlinks to claude/memory/ INSIDE the repo (that is
# where the live files physically sit — Claude Code's autoMemoryDirectory). The
# directory's CONTENTS are gitignored (private, machine-local, mutated live — see
# .gitignore), so a fresh clone won't contain it; create the real dir first, then
# link. The repo path is the physical home; ~/.claude/memory is just the alias.
[ "$DRY_RUN" -eq 0 ] && mkdir -p "$REPO_DIR/claude/memory"
link claude/memory        .claude/memory

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

# git global hooks: the pre-push secret-scan (gitleaks). The committed .gitconfig
# sets core.hooksPath = ~/.config/git/hooks, so this symlink wires that path to the
# repo's hooks. Per-child link (~/.config/git also holds a real `ignore` file).
# Requires gitleaks on PATH (see tools-installed.md); the hook fails OPEN + warns
# if gitleaks is absent, so a fresh machine isn't bricked before the tool lands.
mkdir -p "$HOME/.config/git"
link config/git/hooks .config/git/hooks

# ── systemd user units (journal-audit, qb-proxy-doctor, deadman, memory-autopush)
# CRITICAL: ~/.config/systemd/user is a REAL machine-local directory that ALSO
# holds units this repo does NOT track (wa-sender, daily-brief, reminder-check,
# macro-news, signal-trader-bridge, wa-behavior-learn — per-machine, with secrets
# baked into their environment). A whole-DIR `link config/systemd/user ...` would
# trip link()'s "existing target" branch and `mv` that live dir to .pre-stow —
# orphaning every load-bearing daemon on the next daemon-reload (data-loss-ish).
#
# So we symlink the repo's INDIVIDUAL unit files INTO the existing real dir,
# leaving the machine-local units untouched alongside them. Idempotent + safe
# whether or not the live dir already exists / already has the units.
log "=== systemd user unit files (per-file, into the real dir) ==="
SYSTEMD_USER_DST="$HOME/.config/systemd/user"
if [ -d "$REPO_DIR/config/systemd/user" ]; then
  [ "$DRY_RUN" -eq 0 ] && mkdir -p "$SYSTEMD_USER_DST"
  shopt -s nullglob
  for unit_src in "$REPO_DIR"/config/systemd/user/*.service "$REPO_DIR"/config/systemd/user/*.timer; do
    unit="$(basename "$unit_src")"
    # link() takes repo-relative src + home-relative dst; build those.
    link "config/systemd/user/$unit" ".config/systemd/user/$unit"
  done
  shopt -u nullglob
else
  warn "no config/systemd/user dir in repo — skipping systemd unit links"
fi

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

# ── enable systemd user timers ──────────────────────────────────────────────
# Symlinking the unit files is not enough — systemd must reload to discover the
# new units and the timers must be explicitly enabled+started. Idempotent:
# re-enabling an already-enabled timer is a no-op.
log "=== systemd user timers ==="
# Only the repo-managed timers are enabled here. Machine-local timers (wa-sender,
# daily-brief, reminder-check, signal-trader-bridge, macro-news, loop-digest,
# wa-behavior-learn) are enabled per-machine, out of band.
REPO_TIMERS="journal-audit.timer qb-proxy-doctor.timer memory-autopush.timer deadman.timer loop-digest.timer"
if command -v systemctl >/dev/null 2>&1; then
  if [ "$DRY_RUN" -eq 0 ]; then
    systemctl --user daemon-reload 2>/dev/null || warn "systemctl --user daemon-reload failed (no user session bus? run after login)"
    # shellcheck disable=SC2086
    if systemctl --user enable --now $REPO_TIMERS 2>/dev/null; then
      log "enabled + started: $REPO_TIMERS"
    else
      warn "could not enable timers automatically — run manually after first login:"
      warn "  systemctl --user daemon-reload && systemctl --user enable --now $REPO_TIMERS"
    fi
  else
    log "would run: systemctl --user daemon-reload && systemctl --user enable --now $REPO_TIMERS"
  fi
else
  warn "systemctl not found — skipping timer enable (not a systemd machine?)"
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
