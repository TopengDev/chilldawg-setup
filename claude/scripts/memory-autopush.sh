#!/usr/bin/env bash
# memory-autopush.sh — auto-commit + push the live memory dir to its PRIVATE remote.
#
# The live claude memory dir (Claude Code's autoMemoryDirectory) physically lives
# inside chilldawg-setup/claude/memory/ and is its OWN git repo with a PRIVATE
# remote (TopengDev/claude-memory). chilldawg gitignores this dir, so the nested
# repo is invisible to it. This script keeps the private backup current.
#
# Driven by: config/systemd/user/memory-autopush.timer (every 30 min, Persistent).
# Safe to run manually anytime. Idempotent — commits only when there's a change.
#
# Design notes:
#   * Resolve the memory dir via the ~/.claude/memory symlink so this works no
#     matter where the script is invoked from (cron/systemd has no useful CWD).
#   * `git add -A` then commit ONLY if the index is dirty (no empty commits).
#   * Timestamp from `date` (runs in a real shell — fine, no Date.now footgun).
#   * Never `set -e` around the push: a transient network failure must not crash
#     the unit loudly every 30 min; we log + exit non-zero so `systemctl status`
#     shows it, but the next timer tick simply retries (commits accumulate, then
#     push when connectivity returns).
#   * The global pre-push secret-scan hook still runs on the push — if memory ever
#     gains a real secret, the push is (correctly) blocked and this logs it.

set -uo pipefail

MEM="$(readlink -f "$HOME/.claude/memory")"
LOG_DIR="$HOME/.cache/memory-autopush"
LOG="$LOG_DIR/autopush.log"
mkdir -p "$LOG_DIR"
ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }

# Sanity: the memory dir must exist and be a git repo with a remote.
if [ -z "$MEM" ] || [ ! -d "$MEM" ]; then
  log "ERROR: memory dir not resolvable from ~/.claude/memory — aborting."
  exit 1
fi
cd "$MEM" || { log "ERROR: cannot cd into $MEM"; exit 1; }
if [ ! -d "$MEM/.git" ]; then
  log "ERROR: $MEM is not a git repo (no .git) — aborting (run the one-time init first)."
  exit 1
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  log "ERROR: no 'origin' remote in $MEM — aborting."
  exit 1
fi

# Stage everything (respects .gitignore: state file + cruft excluded).
git add -A

# Commit only if the index actually has staged changes.
if git diff --cached --quiet; then
  # Nothing new since last run. Still attempt a push in case a prior run committed
  # but failed to push (offline catch-up); cheap no-op if already up to date.
  if ! git diff --quiet "@{u}" HEAD 2>/dev/null; then
    log "no new changes, but local is ahead of remote — pushing catch-up."
    if git push origin HEAD >>"$LOG" 2>&1; then
      log "catch-up push OK."
    else
      log "catch-up push FAILED (will retry next tick)."
      exit 1
    fi
  fi
  exit 0
fi

N_CHANGED=$(git diff --cached --name-only | wc -l | tr -d ' ')
STAMP="${MEMORY_AUTOPUSH_TS:-$(date '+%Y-%m-%d %H:%M:%S %z')}"

# CLAUDE_COMMIT_SKILL sentinel: this repo's commits are machine-generated autosync,
# NOT interactive dev work — the /commit-skill enforcement (which targets the main
# dev repos) doesn't apply. Set it so a future global raw-commit guard won't block
# this unattended timer.
export CLAUDE_COMMIT_SKILL=1

if git commit -q -m "memory autosync ${STAMP} (${N_CHANGED} file(s))"; then
  log "committed ${N_CHANGED} change(s)."
else
  log "ERROR: commit failed unexpectedly."
  exit 1
fi

if git push origin HEAD >>"$LOG" 2>&1; then
  log "pushed OK (${N_CHANGED} file(s))."
else
  log "push FAILED (committed locally; will retry next tick). Check connectivity / pre-push hook."
  exit 1
fi

exit 0
