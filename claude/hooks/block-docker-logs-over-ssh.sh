#!/usr/bin/env bash
# block-docker-logs-over-ssh.sh — PreToolUse(Bash) HARD GUARD.
#
# Blocks `docker logs` (and other STREAMING docker client commands: `docker events`,
# `docker stats` without --no-stream) when run over SSH to a remote host.
#
# WHY: such commands ORPHAN on the remote when the SSH client is killed (timeout
# wrapper / backgrounding) and a stuck stream spins remote dockerd at ~ONE CORE
# EACH. On 2026-06-15, four orphaned `docker logs --tail` from main's own VPS
# diagnostics piled up over ~1.5h -> remote dockerd at ~300% (3 cores), load 6.0;
# the cause was MISDIAGNOSED as health-check churn for ~1.5h before main found its
# own orphans. Killing them dropped dockerd to 0.0%. This makes "never again"
# MECHANICAL, not a soft memory. See memory feedback_no_docker_logs_via_timeout_ssh.md.
#
# SAFETY: FAIL OPEN on any parse uncertainty (never brick Bash). Only a CONFIRMED
# match of (ssh|sshpass) AND a streaming docker client subcommand emits a deny.
#
# NOTE: hooks load at session start — this activates after a Claude Code restart.

set -uo pipefail

input="$(cat 2>/dev/null || true)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -z "$cmd" ] && exit 0   # nothing parseable -> allow (fail open)

# Cheap pre-filter: must reference a streaming docker client subcommand.
printf '%s' "$cmd" | grep -qiE 'docker[[:space:]]+(logs|events|stats)' || exit 0

# Must be going OVER SSH (remote) — that is where the orphan/spin happens.
printf '%s' "$cmd" | grep -qiE '(^|[[:space:]])(sshpass|ssh)([[:space:]])' || exit 0

# Classify the offending subcommand.
deny=""
if   printf '%s' "$cmd" | grep -qiE 'docker[[:space:]]+logs';   then deny="docker logs"
elif printf '%s' "$cmd" | grep -qiE 'docker[[:space:]]+events'; then deny="docker events"
elif printf '%s' "$cmd" | grep -qiE 'docker[[:space:]]+stats' && ! printf '%s' "$cmd" | grep -qiE 'no-stream'; then
  deny="docker stats (without --no-stream)"
fi
[ -z "$deny" ] && exit 0   # e.g. `docker stats --no-stream` over ssh is fine

reason="BLOCKED: '${deny}' over SSH. Streaming docker client commands ORPHAN on the remote when the SSH client is killed (timeout-wrap or backgrounding) and a stuck stream spins remote dockerd at ~1 core EACH — this took the VPS to ~300% dockerd / load 6.0 on 2026-06-15 and was misdiagnosed for 1.5h (memory: feedback_no_docker_logs_via_timeout_ssh). SAFE over SSH instead: 'docker ps' / 'docker inspect' / host 'ps'/'top' (cheap, return fast) or 'docker stats --no-stream'. Need logs? get the path via 'docker inspect -f {{.LogPath}} <c>' then read a bounded slice — and NEVER background or timeout-wrap it. Or use ~/.claude/scripts/vps-diag.sh (safe, bounded, no streams)."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
  "$(printf '%s' "$reason" | jq -Rs . 2>/dev/null || printf '"%s over SSH is blocked"' "$deny")"
exit 0
