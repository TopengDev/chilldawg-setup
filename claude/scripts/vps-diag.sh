#!/usr/bin/env bash
# vps-diag.sh — SAFE bounded read-only VPS diagnostics.
# NEVER streams docker logs/events; always a hard SSH timeout; leaves no orphans.
# This is the SANCTIONED tool for checking VPS health (replaces hand-rolled
# `docker logs`-over-SSH, which orphans + spins dockerd — see memory
# feedback_no_docker_logs_via_timeout_ssh.md).
#
# Usage: vps-diag.sh            # full safe sweep (cpu + problem containers + orphan check)
#        vps-diag.sh cpu        # load + top CPU only
set -uo pipefail
source ~/.claude/secrets.env 2>/dev/null

mode="${1:-all}"

remote_all='
echo "=== load / uptime ==="; uptime
echo ""; echo "=== top CPU (snapshot) ==="; top -b -n1 -o %CPU 2>/dev/null | sed -n "1,5p;8,17p"
echo ""; echo "=== containers in a PROBLEM state ==="; docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null | grep -iE "Restarting|unhealthy|Dead|Created|Paused" || echo "(none — all up/healthy)"
echo ""; echo "=== orphaned docker client procs (MUST be empty) ==="; ps -eo pid,etimes,cmd 2>/dev/null | grep -E "docker (logs|stats|events)" | grep -v grep || echo "(clean)"
'
remote_cpu='uptime; echo "--- top CPU ---"; top -b -n1 -o %CPU 2>/dev/null | sed -n "1,5p;8,15p"'

case "$mode" in
  cpu) remote="$remote_cpu" ;;
  all) remote="$remote_all" ;;
  *)   echo "usage: vps-diag.sh [all|cpu]"; exit 1 ;;
esac

timeout 35 sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 \
  "$VPS_USER@$VPS_HOST" "$remote" 2>&1
echo "vps-diag exit: $?"
