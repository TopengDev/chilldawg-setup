#!/usr/bin/env bash
# spawn-supervisor.sh — spawn a PROJECT SUPERVISOR in its own tmux window.
#
# Usage: spawn-supervisor.sh <project> [<window_name>]
#   <project>       project slug. cwd is DERIVED: ~/claude/projects/<project>/manager/
#   <window_name>   optional tmux window name (default: the project slug). This name
#                   is ALSO the supervisor's attn local-peer name + Remote Control
#                   name, and it is what spawn-worker.sh takes as <supervisor_window>.
#
# ── AGENT-ORG MODEL (2026-07-09 refactor, piece 2) ───────────────────────────
# A PROJECT SUPERVISOR OWNS one project end-to-end. Main INITIATES a project
# (agrees it with Christopher, runs project-init, spawns this supervisor) and then
# HANDS OFF COMPLETELY — after handoff main does nothing for that project.
#
#   Christopher ──talks── main (Opus, the ONLY WhatsApp session; INITIATOR; hands off)
#        │  (project-init -> spawn supervisor -> hand off)
#        └──talks DIRECTLY (Remote Control) ── project supervisor (Opus MAX, THIS session)
#                                                   │ delegates + polls its own fleet
#                                                   ▼
#                                              Sonnet workers (report to THIS supervisor)
#
# The supervisor is CHRISTOPHER-FACING, NOT main-facing: Christopher reaches it
# directly over Claude Code Remote Control (terminal or phone). It does NOT report
# to main. It NEVER has WhatsApp (main is the sole WhatsApp session). For an urgent
# AFK escalation it asks main to relay a WhatsApp DM — main is only a pipe there.
#
# ── WHAT THIS SCRIPT GUARANTEES ──────────────────────────────────────────────
#   * FAIL-CLOSED GATE: refuses unless ~/claude/projects/<project>/manager/CLAUDE.md
#     exists (proves project-init ran; that file @-carries the orchestrator rules).
#     This REPLACES the worker triage gate for the supervisor tier: the project's
#     L3 sign-off + agreement happen UPSTREAM (main + project-init) before this file
#     can exist, so its existence IS the setup gate. Mirrors the triage-gate
#     fail-closed style (specific message + exit code, no side effects before it).
#   * Launches `claude --model opus --effort max` (the manager tier is ALWAYS Opus
#     MAX — not a carve-out, it is their tier).
#   * cwd = the project's manager/  (so it loads [universal] + [orchestrator via the
#     manager CLAUDE.md] + [project via up-walk]).
#   * Its OWN new tmux window, named for the project; the supervisor is the LEFT
#     pane (workers get split into the RIGHT column by spawn-worker.sh).
#   * attn channel force-loaded + Remote Control ON.  NEVER sets WHATSAPP=1.
#   * NO supervisor concurrency cap (unlimited; Christopher manages the box).
#
# After this returns 0, the CALLER (main) MUST verify the attn round-trip (peers
# tool shows <window_name>) BEFORE briefing, then brief with the ORCHESTRATOR
# preamble:  brief-worker.sh --supervisor <window_name> <brief_file>
#
# This is a DELIBERATE near-parallel of spawn-worker.sh rather than a flag on it:
# a bug here can never brick the load-bearing worker-spawn path.

set -euo pipefail

PROJECT="${1:?usage: spawn-supervisor.sh <project> [<window_name>]}"
WINDOW_NAME="${2:-$PROJECT}"
TMUX_SESSION="${TMUX_SESSION:-0}"

# Manager tier = ALWAYS Opus at MAX effort. The env knobs are escape hatches only
# (e.g. opus temporarily unavailable); the default is the policy.
SUP_MODEL="${CHILLDAWG_SUPERVISOR_MODEL:-opus}"
SUP_EFFORT="${CHILLDAWG_SUPERVISOR_EFFORT:-max}"
case "$SUP_EFFORT" in
  low|medium|high|xhigh|max) ;;
  *) echo "WARNING: invalid effort '$SUP_EFFORT' — clamping to 'max'." >&2; SUP_EFFORT="max" ;;
esac

PROJECT_DIR="$HOME/claude/projects/$PROJECT"
MANAGER_DIR="$PROJECT_DIR/manager"
MANAGER_CLAUDE="$MANAGER_DIR/CLAUDE.md"
CWD="$MANAGER_DIR"

# ── FAIL-CLOSED GATE: manager/CLAUDE.md must exist ───────────────────────────
# Runs BEFORE any tmux side effect so a blocked spawn leaves no window behind.
if [[ ! -f "$MANAGER_CLAUDE" ]]; then
  {
    echo "REFUSING TO SPAWN SUPERVISOR for project '$PROJECT': manager gate failed."
    echo "  Missing: $MANAGER_CLAUDE"
    echo "  A project supervisor may only be spawned AFTER project-init has scaffolded"
    echo "  the project (which creates manager/CLAUDE.md carrying the orchestrator rules)."
    echo "  Run project-init for '$PROJECT' first, then retry."
  } >&2
  exit 4
fi

# Sanity: tmux session must exist.
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "ERROR: tmux session '$TMUX_SESSION' not found" >&2
  exit 1
fi

# Sanity: window name (= supervisor attn name) must be unique in the session.
if tmux list-windows -t "$TMUX_SESSION" -F "#{window_name}" 2>/dev/null | grep -qx "$WINDOW_NAME"; then
  echo "ERROR: window '$WINDOW_NAME' already exists in session '$TMUX_SESSION'" >&2
  echo "  A supervisor for this project may already be running. Attach:" >&2
  echo "    tmux select-window -t $TMUX_SESSION:$WINDOW_NAME" >&2
  echo "  Or choose a different window name / kill the stale window first." >&2
  exit 2
fi

# NO concurrency cap. The old CHILLDAWG_MAX_SUPERVISORS semaphore gate is REMOVED
# (agent-org piece 2): supervisors are unlimited; Christopher manages the box.

# Create the window at the next-highest index (never displace main = window 1).
NEXT_INDEX=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_index}' | sort -n | tail -1)
NEXT_INDEX=$((NEXT_INDEX + 1))
tmux new-window -t "${TMUX_SESSION}:${NEXT_INDEX}" -n "$WINDOW_NAME" -c "$CWD"
sleep 0.5
TARGET="${TMUX_SESSION}:${NEXT_INDEX}"
# Label the supervisor pane (human readability; also lets spawn-worker.sh identify
# the left/main pane by geometry — it uses pane_left, this title is a bonus).
tmux select-pane -t "$TARGET" -T "$WINDOW_NAME" 2>/dev/null || true

# ── Launch: Opus MAX + attn force-loaded + Remote Control ON, NEVER WhatsApp ──
# attn is a CHANNEL plugin: being in settings.json is NOT enough to start its
# MCP/peer daemon — it needs explicit channel activation at launch, or the session
# never registers a local peer and cannot be reached / cannot report. Use
# --dangerously-load-development-channels (NOT --channels; the "approved" path
# silently fails the allowlist inside spawned sessions on CC 2.1.179+). Load ONLY
# attn — NEVER whatsapp (WHATSAPP=1 belongs to main alone; splitting it breaks the
# command center). The dev-channels flag triggers a one-time blocking confirm that
# --dangerously-skip-permissions does NOT auto-accept, so we auto-confirm below.
# --remote-control named = Christopher reaches this supervisor directly.
tmux send-keys -t "$TARGET" \
  "ATTN_SESSION='${WINDOW_NAME}' claude --model '${SUP_MODEL}' --effort '${SUP_EFFORT}' --dangerously-load-development-channels plugin:attn@s0nderlabs --remote-control '${WINDOW_NAME}' --dangerously-skip-permissions" \
  Enter

# Auto-confirm the --dangerously-load-development-channels prompt (bare Enter on the
# pre-highlighted "I am using this for local development"). Poll for it, then confirm.
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
    break   # input already up — confirm not needed
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
  echo "OK: supervisor prompt ready after ~$((waited + 1 + MCP_GRACE))s (polled)."
else
  echo "WARN: supervisor prompt not detected within ${READY_MAX}s — proceeding anyway." >&2
  echo "      (Boot may be slow; the attn-peers check below is the real gate.)" >&2
fi

echo "OK: supervisor window '$WINDOW_NAME' created for project '$PROJECT'."
echo "    model=${SUP_MODEL} effort=${SUP_EFFORT}  cwd=${CWD}  WhatsApp=NEVER  RemoteControl=ON  cap=NONE"
echo
echo "NEXT (the spawning session MUST do):"
echo "  1. Call the attn peers tool; confirm '$WINDOW_NAME' is in local peers."
echo "  2. If NOT visible within 15s: kill window + retry"
echo "       tmux kill-window -t ${TMUX_SESSION}:${WINDOW_NAME}"
echo "  3. Only after the peer is confirmed, brief with the ORCHESTRATOR preamble:"
echo "       brief-worker.sh --supervisor ${WINDOW_NAME} <brief_file>"
echo
echo "  REPORTING (agent-org model): this supervisor is CHRISTOPHER-FACING via Remote"
echo "  Control and does NOT report to main. It surfaces direction/milestones/blockers/"
echo "  DONE straight to Christopher. Its workers report to IT (attn name '$WINDOW_NAME')."
echo "  NOTE: the current brief-worker.sh --supervisor preamble still says 'report to"
echo "  main' (pre-agent-org wording). Until that preamble is updated, the project brief"
echo "  MUST state: 'You are Christopher-facing via Remote Control; do NOT report to main.'"
echo "  For VPS actions, message the fixed VPS-manager peer 'vps-manager' via attn."
