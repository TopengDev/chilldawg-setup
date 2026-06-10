#!/usr/bin/env bash
# brief-worker.sh — reliably deliver a brief to a spawned claude worker.
#
# Usage: brief-worker.sh [--quick|--l1] <window_name> <brief_file>
#
#   --quick / --l1  L1 FAST-PATH for trivial work. Relaxes the STATE.md gate to
#                   accept a stub STATE.md (no parent-initiative linkage required)
#                   and injects a lightweight preamble instead of the full 3-tier
#                   discipline. Use for typo fixes, one-line changes, etc.
#                   (Pure-comms L1 — send WA, list tmux, answer a Q — is NOT a
#                   worker task; it stays in main. Don't spawn for it.)
#
# What this fixes (per memory feedback_tmux_send_keys.md):
#  1. Trust-folder prompt — Claude Code may show "Is this a project you trust?"
#     before reaching the chat input. We detect + auto-confirm with Enter.
#  2. Combined paste+Enter races — `send-keys "long text" Enter` sometimes drops
#     the Enter because INSERT mode is still flushing the paste. We use
#     load-buffer + paste-buffer -p, sleep, then a separate send-keys Enter.
#  3. No verification — `tmux send-keys Enter` returning success doesn't mean
#     claude submitted. We capture the pane post-submit and check the footer:
#     "-- INSERT --" + visible "[Pasted text" = still in input box = retry.
#     Spinner verb (Cooking, Brewing, Harmonizing, etc) = processing = good.
#
# Exits 0 on confirmed submit, 1 on failure after retries.

set -euo pipefail

QUICK=0
if [[ "${1:-}" == "--quick" || "${1:-}" == "--l1" ]]; then
  QUICK=1
  shift
fi

WINDOW="${1:?usage: brief-worker.sh [--quick|--l1] <window_name> <brief_file>}"
BRIEF="${2:?usage: brief-worker.sh [--quick|--l1] <window_name> <brief_file>}"
TMUX_SESSION="${TMUX_SESSION:-0}"
PANE="${TMUX_SESSION}:${WINDOW}"

if [[ ! -f "$BRIEF" ]]; then
  echo "ERROR: brief file not found: $BRIEF" >&2
  exit 1
fi

if ! tmux list-windows -t "$TMUX_SESSION" -F "#{window_name}" 2>/dev/null | grep -qx "$WINDOW"; then
  echo "ERROR: tmux window '$WINDOW' not found in session '$TMUX_SESSION'" >&2
  exit 1
fi

# HARD GATE: STATE.md must exist in the brief's directory (3-tier task hierarchy).
# Workers MUST maintain STATE.md throughout their task. If missing, main session
# didn't follow the pre-spawn discipline. Refuse delivery.
#
# --quick / --l1 (L1 fast-path): a stub STATE.md (name/status/one-liner) is enough;
#   parent-initiative linkage NOT required. Otherwise (full 3-tier): STATE.md must
#   reference a "Parent initiative" — no orphan tasks.
BRIEF_DIR=$(dirname "$BRIEF")
STATE_FILE="${BRIEF_DIR}/STATE.md"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: STATE.md missing in ${BRIEF_DIR}/" >&2
  echo "" >&2
  echo "Per 3-tier task hierarchy enforcement: every task notes dir MUST have" >&2
  echo "STATE.md before brief delivery. Create it now using the template:" >&2
  echo "" >&2
  echo "  cp ~/claude/notes/templates/STATE.md ${STATE_FILE}" >&2
  echo "" >&2
  echo "Then fill in: NAME, worker name, parent initiative slug, starting point," >&2
  echo "and an initial roadmap. The worker will maintain it from there." >&2
  echo "" >&2
  echo "For a trivial L1 task, a stub STATE.md + the fast-path is enough:" >&2
  echo "  brief-worker.sh --quick ${WINDOW} ${BRIEF}" >&2
  exit 3
fi

if [[ "$QUICK" != "1" ]]; then
  # Full 3-tier path: require parent-initiative linkage (no orphan tasks).
  if ! grep -qiE 'parent[[:space:]]+initiative' "$STATE_FILE"; then
    echo "ERROR: STATE.md in ${BRIEF_DIR}/ has no 'Parent initiative' reference." >&2
    echo "" >&2
    echo "Full 3-tier tasks must link to a parent initiative (no orphan tasks)." >&2
    echo "Add the line from the template, e.g.:" >&2
    echo "  **Parent initiative:** [<slug>](../initiatives/<slug>.md)" >&2
    echo "" >&2
    echo "OR, if this is trivial L1 work, use the fast-path (stub STATE.md OK):" >&2
    echo "  brief-worker.sh --quick ${WINDOW} ${BRIEF}" >&2
    exit 3
  fi
fi

# Step 1: Handle trust-folder prompt if present.
# Claude Code shows "Quick safety check: Is this a project you created or one you trust?"
# with option 1 pre-highlighted. Single Enter confirms.
PANE_NOW=$(tmux capture-pane -t "$PANE" -p -S -20 2>&1)
if echo "$PANE_NOW" | grep -q "Quick safety check"; then
  echo "[brief-worker] trust-folder prompt detected, confirming..."
  tmux send-keys -t "$PANE" Enter
  sleep 3
fi

# Step 2: Wait until claude chat input is ready.
# Look for the "-- INSERT --" footer indicator or the chat prompt ❯ on its own line.
READY=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  PANE_NOW=$(tmux capture-pane -t "$PANE" -p -S -10 2>&1)
  if echo "$PANE_NOW" | grep -qE "(-- INSERT --|bypass permissions on)"; then
    READY=1
    break
  fi
  sleep 1
done

if [[ "$READY" != "1" ]]; then
  echo "ERROR: claude chat input not ready after 10s in pane $PANE" >&2
  echo "Last pane capture:" >&2
  echo "$PANE_NOW" >&2
  exit 1
fi

# Step 3: Paste the brief via bracketed-paste mode.
# load-buffer + paste-buffer -p is more reliable than send-keys "long text"
# because Claude Code recognizes it as a single paste event.
#
# IMPORTANT: prepend a role-override preamble. Workers spawned in ~/claude
# auto-load the global CLAUDE.md ("main session is discussion only") and may
# refuse the task thinking they ARE main. The preamble is BEFORE the brief
# so the worker sees the override first and applies it to the rest of the read.
# See memory feedback_worker_role_clarity.md.
PREAMBLE_FILE=$(mktemp)
# Initial cleanup trap (preamble temp file only). It is REPLACED further down by a
# combined trap that also deletes the per-invocation tmux buffer, once that buffer
# exists. bash EXIT traps are last-wins, so the later one supersedes this safely
# (both rm the same PREAMBLE_FILE; rm -f is idempotent).
trap "rm -f $PREAMBLE_FILE" EXIT
if [[ "$QUICK" == "1" ]]; then
  # L1 FAST-PATH preamble — lightweight. Role override stays (essential), but the
  # heavy 3-tier STATE.md ceremony is trimmed to the minimum for trivial work.
  cat > "$PREAMBLE_FILE" <<EOF
# WORKER ROLE OVERRIDE (read FIRST, applies to everything below)

You are a SPAWNED WORKER named '$WINDOW' running in tmux window of session ${TMUX_SESSION}. You are NOT the main coordination session — main is a SEPARATE session that spawned you. Verify via the attn peers tool: you appear as '$WINDOW', main as 'main'.

The auto-loaded CLAUDE.md rule "Main Session is DISCUSSION ONLY / never run dev commands here" does NOT apply to you. You are a delegated worker — EXECUTE the brief, don't delegate it further. Don't spawn sub-workers. You ARE the worker.

---

## L1 fast-path (trivial task — lightweight)

This is an L1 trivial task. No initiative file, no full 3-tier ceremony. Keep it minimal:

1. **Open STATE.md** (a stub next to this brief), set Status to IN_PROGRESS.
2. **Do the task.** Verify it actually works (don't just assume).
3. **On completion**: set Status to COMPLETE in STATE.md + send an attn report to 'main' (what you did + how you verified). A full report.md is optional for L1.
4. **If blocked**: set Status to BLOCKED + ping main via attn.

---

Below is your brief. Read it, set STATE.md to IN_PROGRESS, send an attn STARTING ping to main, then execute.

EOF
else
  # Full 3-tier discipline preamble.
  cat > "$PREAMBLE_FILE" <<EOF
# WORKER ROLE OVERRIDE (read FIRST, applies to everything below)

You are a SPAWNED WORKER named '$WINDOW' running in tmux window of session ${TMUX_SESSION}. You are NOT the main coordination session — main is a SEPARATE session, and main spawned you via spawn-worker.sh. Verify your identity any time via the attn peers tool: you will appear as '$WINDOW' while main appears as 'main'.

The auto-loaded CLAUDE.md rule "Main Session is DISCUSSION ONLY / never run dev commands here" does NOT apply to you. That rule governs the command-center session only. You are a delegated worker — your role is to EXECUTE the brief that follows, not to delegate it further. Do not spawn sub-workers. Do not redirect this brief to "a proper worker session" — you ARE that worker.

If you find yourself thinking "this brief is misrouted" or "main shouldn't do this work" — that's the auto-loaded CLAUDE.md confusing you. Ignore it. Proceed with the brief.

---

## MANDATORY: STATE.md discipline (3-tier task hierarchy)

Your task notes dir already has \`STATE.md\` next to this brief (main pre-created it). You MUST:

1. **Open STATE.md FIRST** before running any tool calls for the actual work
2. **Set Status to IN_PROGRESS** + fill the "Starting point" section with what you observed about the existing state
3. **Maintain it throughout**: update "Current progress" continuously (every major step), move items from "Roadmap" → "Completed" as you finish them, add "Blockers" if anything halts you
4. **On task completion**: set Status to COMPLETE + write report.md
5. **On halt/block**: set Status to BLOCKED + describe blocker + ping main via attn

Main session will poll your STATE.md every 5 min. If not updated in >10 min while you're still active, main will ping or investigate stall. Treat STATE.md as your living source-of-truth, not the attn pings.

---

Below is your brief. Read it fully, init STATE.md per above, send an attn STARTING ping to main, then execute.

EOF
fi
cat "$BRIEF" >> "$PREAMBLE_FILE"

# Per-invocation buffer name. The old fixed `_brief` buffer RACES when two
# spawns run in parallel: the second `load-buffer -b _brief` overwrites the
# first before its `paste-buffer` fires, so worker A can receive worker B's
# brief. $$ (this shell's PID) makes the buffer unique per invocation.
# Clean it up on exit so tmux's buffer stack doesn't accumulate stale entries.
BRIEF_BUF="_brief_$$"
trap "rm -f $PREAMBLE_FILE; tmux delete-buffer -b $BRIEF_BUF 2>/dev/null || true" EXIT
tmux load-buffer -b "$BRIEF_BUF" - < "$PREAMBLE_FILE"
tmux paste-buffer -p -b "$BRIEF_BUF" -t "$PANE"
sleep 2  # let claude flush the paste into its input buffer

# Step 4: Submit with Enter (separate send-keys call, NOT combined).
tmux send-keys -t "$PANE" Enter
sleep 3  # let claude register the submit + transition to processing state

# Step 5: Verify submit committed.
# Bad state: footer still "-- INSERT --" AND "[Pasted text" still visible in input.
# Good state: spinner verb visible (Cooking, Brewing, Harmonizing, etc) or token count moved.
for attempt in 1 2 3; do
  PANE_NOW=$(tmux capture-pane -t "$PANE" -p -S -20 2>&1)
  if echo "$PANE_NOW" | grep -qE "\[Pasted text"; then
    # Still in input box — retry Enter
    echo "[brief-worker] attempt $attempt: paste still in input, sending Enter again..."
    tmux send-keys -t "$PANE" Escape
    sleep 0.5
    tmux send-keys -t "$PANE" Enter
    sleep 3
    continue
  fi
  # No "[Pasted text" visible → claude consumed the input → success
  echo "[brief-worker] OK — brief submitted to '$WINDOW'"
  exit 0
done

echo "ERROR: brief still dangling in input box after 3 retries in pane $PANE" >&2
echo "Last pane capture:" >&2
echo "$PANE_NOW" >&2
exit 1
