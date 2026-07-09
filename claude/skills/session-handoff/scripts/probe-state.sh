#!/usr/bin/env bash
# session-handoff prober — dumps live machine state for a handoff.
# FAIL-OPEN BY CONTRACT: every section is guarded; a failing probe prints
# "n/a (probe failed)" and the script ALWAYS exits 0. Never abort a handoff
# because the box is sick — that is when the handoff matters most.
# Usage: probe-state.sh [extra-git-repo-path ...]
set -u
trap 'true' ERR
sec() { printf '\n### probe · %s\n' "$1"; }
run() { # run "label" cmd... -> bounded, guarded
  local label="$1"; shift
  sec "$label"
  { "$@" 2>&1 | head -40; } || echo "n/a (probe failed)"
}

echo '```'
echo "probe-state.sh v1 · $(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo 'date n/a')"

run "identity" bash -c 'echo "host=$(hostname 2>/dev/null) user=$(whoami 2>/dev/null) cwd=$(pwd)"'

sec "git (cwd + args)"
for repo in "$(pwd)" "$@"; do
  if git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "--- repo: $repo"
    { git -C "$repo" status --porcelain=v1 2>/dev/null | head -15; } || true
    { git -C "$repo" status --porcelain=v1 2>/dev/null | wc -l | sed 's/^/dirty files: /'; } || true
    { git -C "$repo" log --oneline -3 2>/dev/null | sed 's/^/  /'; } || true
    { git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's/^/branch: /'; } || true
    { git -C "$repo" stash list 2>/dev/null | wc -l | sed 's/^/stashes: /'; } || true
  else
    echo "--- $repo: not a git repo"
  fi
done

run "tmux windows" tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name} #{?window_active,(active),}'
run "claude/agent processes" bash -c 'pgrep -af "claude|own-renderer|lumiere" | grep -v probe-state | head -20 || echo none'
run "heavy processes (chrome/node/bun/ffmpeg/python)" bash -c 'ps -eo pid,pcpu,pmem,etime,comm --sort=-pcpu 2>/dev/null | head -12'
run "docker" bash -c 'docker ps --format "{{.Names}} {{.Status}}" 2>/dev/null | head -15 || echo "n/a (no docker or not running)"'
run "background monitors/timers (systemd user)" bash -c 'systemctl --user list-timers --no-pager 2>/dev/null | head -10 || echo n/a'
run "disk" df -h /home /tmp
run "memory" free -h
run "recent handoffs" bash -c 'ls -lat ~/claude/notes/handoffs/*.md 2>/dev/null | head -5 || echo "none yet"'
echo '```'
exit 0
