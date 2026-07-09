#!/usr/bin/env bash
# spawn-vps-manager.sh — bring up the PERSISTENT, always-on VPS MANAGER.
#
# Usage: spawn-vps-manager.sh [<window_name>]
#   <window_name>   optional tmux window name (default: the FIXED name 'vps-manager').
#                   This name is ALSO the VPS manager's FIXED attn local-peer name
#                   and Remote Control name.
#
# ── AGENT-ORG MODEL (2026-07-09 refactor, piece 2) ───────────────────────────
# The VPS MANAGER is a PERSISTENT, always-on service that owns ALL VPS operations
# (read AND write, no exceptions) — the SINGLE executor of anything touching the
# VPS. It is NOT per-project. Like a project supervisor it is CHRISTOPHER-FACING
# via Remote Control, runs Opus at MAX effort, delegates to its OWN workers, and
# NEVER has WhatsApp. It owns the SSH creds; no project agent SSHes the VPS ever.
#
#   Christopher ──talks DIRECTLY (Remote Control)── VPS manager (Opus MAX, persistent)
#   any supervisor/worker ──attn request──►         (owns SSH + all VPS ops)
#                                                        │ delegates
#                                                        ▼
#                                                   its own Sonnet workers
#
# ── FIXED, KNOWN attn ADDRESS (so every supervisor can reach it) ─────────────
# The VPS manager launches with a FIXED attn local-peer name:  vps-manager
# (set via ATTN_SESSION). Every project supervisor/worker on THIS box reaches it
# by that name using the attn tools:  send("vps-manager", "<VPS request>").
# Local peers are trust="local" (same machine, same user) — no approval needed.
# (Cross-machine reach is NOT required: the VPS manager runs locally and SSHes out.
# If it were ever needed, register a global attn NAME via register_name — costs ETH,
# out of scope here. The local name 'vps-manager' is the documented address.)
#
# ── WHAT THIS SCRIPT GUARANTEES ──────────────────────────────────────────────
#   * FAIL-CLOSED GATE: refuses unless ~/claude/vps/CLAUDE.md exists (the VPS role
#     rules — sole-executor authority, gentle-connect, no-docker-logs-over-timeout,
#     Cloudflare DNS, deploy mechanics, secret-safety). Mirrors the triage-gate
#     fail-closed style (message + exit code, no side effects before it).
#   * SINGLE-INSTANCE: refuses if the vps-manager window already exists (only one).
#   * Launches `claude --model opus --effort max`, cwd = ~/claude/vps/.
#   * Its OWN new tmux window; attn force-loaded + Remote Control ON.
#   * NEVER sets WHATSAPP=1.  NO concurrency cap.
#
# After this returns 0, the CALLER (main) MUST verify the attn round-trip (peers
# tool shows 'vps-manager') BEFORE briefing, then brief with the ORCHESTRATOR
# preamble:  brief-worker.sh --supervisor vps-manager <brief_file>

set -euo pipefail

WINDOW_NAME="${1:-vps-manager}"
TMUX_SESSION="${TMUX_SESSION:-0}"

# VPS manager = ALWAYS Opus at MAX effort (manager tier). Env knobs are escape
# hatches only; the default is the policy.
VPS_MODEL="${CHILLDAWG_VPS_MODEL:-opus}"
VPS_EFFORT="${CHILLDAWG_VPS_EFFORT:-max}"
case "$VPS_EFFORT" in
  low|medium|high|xhigh|max) ;;
  *) echo "WARNING: invalid effort '$VPS_EFFORT' — clamping to 'max'." >&2; VPS_EFFORT="max" ;;
esac

VPS_DIR="$HOME/claude/vps"
VPS_CLAUDE="$VPS_DIR/CLAUDE.md"
CWD="$VPS_DIR"

# ── FAIL-CLOSED GATE: vps/CLAUDE.md must exist ───────────────────────────────
if [[ ! -f "$VPS_CLAUDE" ]]; then
  {
    echo "REFUSING TO SPAWN VPS MANAGER: role-rules gate failed."
    echo "  Missing: $VPS_CLAUDE"
    echo "  The VPS manager must load its consolidated VPS rules (sole-executor role,"
    echo "  SSH creds handling, gentle-connect, DNS, deploy mechanics, secret-safety)."
    echo "  Author ~/claude/vps/CLAUDE.md first (agent-org piece 1), then retry."
  } >&2
  exit 4
fi

# Sanity: tmux session must exist.
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "ERROR: tmux session '$TMUX_SESSION' not found" >&2
  exit 1
fi

# SINGLE-INSTANCE: the VPS manager is persistent + unique. Refuse a second one.
if tmux list-windows -t "$TMUX_SESSION" -F "#{window_name}" 2>/dev/null | grep -qx "$WINDOW_NAME"; then
  echo "ERROR: VPS manager window '$WINDOW_NAME' already exists in session '$TMUX_SESSION'." >&2
  echo "  It is persistent + single-instance. Attach instead of spawning a second:" >&2
  echo "    tmux select-window -t $TMUX_SESSION:$WINDOW_NAME" >&2
  echo "  (If it died, kill the stale window first, then retry.)" >&2
  exit 2
fi

# NO concurrency cap (unlimited; Christopher manages the box).

# Create the window at the next-highest index (never displace main = window 1).
NEXT_INDEX=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_index}' | sort -n | tail -1)
NEXT_INDEX=$((NEXT_INDEX + 1))
tmux new-window -t "${TMUX_SESSION}:${NEXT_INDEX}" -n "$WINDOW_NAME" -c "$CWD"
sleep 0.5
TARGET="${TMUX_SESSION}:${NEXT_INDEX}"
tmux select-pane -t "$TARGET" -T "$WINDOW_NAME" 2>/dev/null || true

# ── Launch: Opus MAX + attn force-loaded (FIXED name) + Remote Control ────────
# ATTN_SESSION is the FIXED 'vps-manager' name every supervisor addresses. Force-
# load ONLY attn via dev-channels (never whatsapp — WHATSAPP=1 belongs to main
# alone). --remote-control named = Christopher reaches the VPS manager directly.
tmux send-keys -t "$TARGET" \
  "ATTN_SESSION='${WINDOW_NAME}' claude --model '${VPS_MODEL}' --effort '${VPS_EFFORT}' --dangerously-load-development-channels plugin:attn@s0nderlabs --remote-control '${WINDOW_NAME}' --dangerously-skip-permissions" \
  Enter

# Auto-confirm the --dangerously-load-development-channels prompt (bare Enter).
DEVCH_MAX=20
for ((dc = 0; dc < DEVCH_MAX; dc++)); do
  sleep 1
  PANE_DC=$(tmux capture-pane -t "$TARGET" -p -S -25 2>/dev/null || true)
  if echo "$PANE_DC" | grep -qE -- 'using this for local development|Loading development channels'; then
    tmux send-keys -t "$TARGET" Enter
    echo "OK: auto-confirmed dev-channels prompt (after ~$((dc + 1))s)."
    sleep 2
    break
  fi
  if echo "$PANE_DC" | grep -qE -- '-- INSERT --|bypass permissions on'; then
    break
  fi
done

# Wait for claude to boot + MCP plugins to register (poll the pane, 30s ceiling).
READY_MAX=30
MCP_GRACE=3
BOOT_READY=0
waited=0
for ((waited = 0; waited < READY_MAX; waited++)); do
  sleep 1
  PANE_BOOT=$(tmux capture-pane -t "$TARGET" -p -S -15 2>/dev/null || true)
  if echo "$PANE_BOOT" | grep -qE -- '-- INSERT --|bypass permissions on|^[[:space:]]*[❯>][[:space:]]'; then
    BOOT_READY=1
    break
  fi
done

if [[ "$BOOT_READY" == "1" ]]; then
  sleep "$MCP_GRACE"
  echo "OK: VPS manager prompt ready after ~$((waited + 1 + MCP_GRACE))s (polled)."
else
  echo "WARN: VPS manager prompt not detected within ${READY_MAX}s — proceeding anyway." >&2
  echo "      (Boot may be slow; the attn-peers check below is the real gate.)" >&2
fi

echo "OK: VPS manager window '$WINDOW_NAME' created (persistent, single-instance)."
echo "    model=${VPS_MODEL} effort=${VPS_EFFORT}  cwd=${CWD}  WhatsApp=NEVER  RemoteControl=ON  cap=NONE"
echo "    FIXED attn peer name: '${WINDOW_NAME}'  ->  supervisors reach it via send(\"${WINDOW_NAME}\", ...)"
echo
echo "NEXT (the spawning session MUST do):"
echo "  1. Call the attn peers tool; confirm '$WINDOW_NAME' is in local peers."
echo "     If NOT visible within 15s: kill window + retry"
echo "       tmux kill-window -t ${TMUX_SESSION}:${WINDOW_NAME}"
echo "  2. Only after the peer is confirmed, brief with the ORCHESTRATOR preamble:"
echo "       brief-worker.sh --supervisor ${WINDOW_NAME} <brief_file>"
echo
echo "  REPORTING (agent-org model): the VPS manager is CHRISTOPHER-FACING via Remote"
echo "  Control and does NOT report to main. Its own workers report to IT. Record the"
echo "  fixed attn name '${WINDOW_NAME}' in every supervisor's brief as the VPS contact."
echo "  NOTE: the current brief-worker.sh --supervisor preamble still says 'report to"
echo "  main' — until updated, the VPS-manager brief MUST state: 'You are Christopher-"
echo "  facing via Remote Control; do NOT report to main.'"
