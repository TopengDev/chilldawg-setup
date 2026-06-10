#!/usr/bin/env bash
# resume-worker.sh — re-brief a worker that was KILLED / hit the session limit
# mid-task, so it RESUMES from its last incomplete checkpoint instead of redoing
# work or needing a babysitter.
#
# Usage: resume-worker.sh <window_name> <task_dir> [--with-brief <orig_brief_file>]
#
#   <window_name>  tmux window of the worker to resume. It may be:
#                    (a) a still-alive worker whose REPL is idle/stuck, OR
#                    (b) a freshly RE-SPAWNED window (run spawn-worker.sh first if
#                        the old one died and was killed). Either works — the resume
#                        preamble carries the full role-override for a fresh session.
#   <task_dir>     the task notes dir holding STATE.md (+ brief.md, triage.json).
#                  STATE.md is REQUIRED — it's the resume source-of-truth.
#   --with-brief <file>   ALSO re-inject the original brief body for full context
#                  (use when the worker is a brand-new session that never saw the
#                  brief). Default: resume from STATE.md alone (lighter; the worker
#                  re-reads its own STATE.md which already holds the plan).
#
# HOW IT WORKS
#   This builds a RESUME body and hands it to brief-worker.sh, which prepends the
#   standard worker role-override + STATE.md/checkpoint/result contracts and uses
#   the battle-tested paste/submit delivery. So a resumed worker gets full role
#   context AND a clear "you were killed, continue from the last checkpoint" order.
#
#   The resume is SAFE because of the checkpoint contract: every `[x]` checkpoint
#   in STATE.md is verified+idempotent, so skipping it is correct; the worker
#   continues from the first `[ ]` (the Resume cursor).
#
# Exits 0 on confirmed re-brief submit, non-zero on failure.

set -euo pipefail

WINDOW="${1:-}"
TASK_DIR="${2:-}"
WITH_BRIEF=""

if [[ -z "$WINDOW" || -z "$TASK_DIR" ]]; then
  echo "usage: resume-worker.sh <window_name> <task_dir> [--with-brief <orig_brief_file>]" >&2
  exit 2
fi
shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-brief)
      WITH_BRIEF="${2:-}"
      if [[ -z "$WITH_BRIEF" || ! -f "$WITH_BRIEF" ]]; then
        echo "ERROR: --with-brief needs an existing file (got '${2:-}')" >&2
        exit 2
      fi
      shift 2
      ;;
    *)
      echo "ERROR: unknown arg '$1'" >&2
      echo "usage: resume-worker.sh <window_name> <task_dir> [--with-brief <orig_brief_file>]" >&2
      exit 2
      ;;
  esac
done

TASK_DIR="${TASK_DIR%/}"
STATE_FILE="${TASK_DIR}/STATE.md"

if [[ ! -d "$TASK_DIR" ]]; then
  echo "ERROR: task dir not found: $TASK_DIR" >&2
  exit 2
fi
if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: STATE.md missing in ${TASK_DIR}/ — nothing to resume from." >&2
  echo "  A resume needs a checkpointed STATE.md. If this task never started," >&2
  echo "  brief it fresh with brief-worker.sh instead." >&2
  exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIEF_WORKER="$SCRIPT_DIR/brief-worker.sh"
if [[ ! -x "$BRIEF_WORKER" ]]; then
  echo "ERROR: brief-worker.sh not found/executable at $BRIEF_WORKER" >&2
  exit 2
fi

# Surface the current checkpoint state into the console (operator visibility) and
# pull out the Resume cursor line if present, to echo back to the worker.
RESUME_CURSOR="$(grep -m1 -iE '^\*\*Resume cursor:\*\*' "$STATE_FILE" 2>/dev/null || true)"
# `grep -c` exits 1 + prints 0 on no match; a `|| echo 0` would double to "0\n0".
# Grab the count, then coerce to a clean single integer.
DONE_COUNT="$(grep -cE '^\s*-\s*\[x\]' "$STATE_FILE" 2>/dev/null)"; [[ "$DONE_COUNT" =~ ^[0-9]+$ ]] || DONE_COUNT=0
TODO_COUNT="$(grep -cE '^\s*-\s*\[ \]' "$STATE_FILE" 2>/dev/null)"; [[ "$TODO_COUNT" =~ ^[0-9]+$ ]] || TODO_COUNT=0
echo "[resume-worker] STATE.md @ $STATE_FILE"
echo "[resume-worker]   checkpoints/roadmap: ${DONE_COUNT} done, ${TODO_COUNT} remaining"
[[ -n "$RESUME_CURSOR" ]] && echo "[resume-worker]   ${RESUME_CURSOR}"

# Build the RESUME body DIRECTLY inside the task dir. This becomes brief-worker.sh's
# <brief_file>, so (a) it lands AFTER the role-override preamble brief-worker
# prepends, and (b) brief-worker's STATE.md gate — which checks dirname(brief)/STATE.md
# — resolves to the REAL STATE.md in this task dir. One transient file, one trap.
RESUME_BODY="${TASK_DIR}/.resume-brief.$$.md"
# shellcheck disable=SC2064  # expand $RESUME_BODY now (it won't change) for the trap
trap "rm -f '$RESUME_BODY'" EXIT

{
  echo "# RESUME — you were KILLED / hit the session limit mid-task. CONTINUE, do not restart."
  echo
  echo "You are the SAME worker resuming task **${TASK_DIR##*/}**. A previous run of you"
  echo "was interrupted (kill / Claude session limit / crash). You are NOT starting fresh."
  echo
  echo "## Do this NOW, in order (Resume protocol):"
  echo
  echo "1. **Read your STATE.md FIRST** (\`${STATE_FILE}\`) before any other tool call."
  echo "2. Read the **Checkpoints (idempotent, resumable)** section. Every checkpoint marked"
  echo "   \`[x]\` is DONE and was VERIFIED — its effect already landed and it is idempotent."
  echo "   **Do NOT redo \`[x]\` checkpoints** (redoing risks duplication, wasted cost, or"
  echo "   corrupting already-correct state)."
  echo "3. Find the **first \`[ ]\` checkpoint** (the \"Resume cursor\"). That is where you continue."
  echo "   For any GUARDED non-idempotent checkpoint, re-check its sentinel before assuming state."
  echo "4. **Cheaply re-verify the last \`[x]\`** still holds (confirm the prior run's effect"
  echo "   persisted — a file still exists, a process is still up), then proceed from the first \`[ ]\`."
  echo "5. Update STATE.md \"Current progress\" to note you RESUMED and from which checkpoint,"
  echo "   set Status back to IN_PROGRESS, and continue maintaining checkpoints as you finish them."
  echo
  echo "6. On completion: Status COMPLETE + report.md + result.json (as in the original contract)."
  echo "   On block: Status BLOCKED + ping main."
  echo
  if [[ -n "$RESUME_CURSOR" ]]; then
    echo "> Your STATE.md currently reports: ${RESUME_CURSOR#\*\*Resume cursor:\*\* }"
    echo
  fi
  echo "Remember: the checkpoint contract exists so this is a fast resume, not a redo."
  echo "Trust your own verified \`[x]\` checkpoints."

  if [[ -n "$WITH_BRIEF" ]]; then
    echo
    echo "---"
    echo
    echo "## Original brief (re-included for full context):"
    echo
    cat "$WITH_BRIEF"
  fi
} > "$RESUME_BODY"

echo "[resume-worker] delivering RESUME re-brief to window '$WINDOW' via brief-worker.sh ..."
# Delegate delivery (role-override prepend + robust paste/submit) to brief-worker.sh.
# Use the full (non-quick) path so the worker re-absorbs the full discipline. If the
# task's STATE.md lacks a Parent-initiative line (an L1 stub), fall back to --quick so
# the STATE.md gate's linkage check doesn't reject the resume.
# NB: `set -e` is on — capture brief-worker's exit without aborting (|| rc=$?).
rc=0
if grep -qiE 'parent[[:space:]]+initiative' "$STATE_FILE"; then
  "$BRIEF_WORKER" "$WINDOW" "$RESUME_BODY" || rc=$?
else
  echo "[resume-worker] STATE.md is an L1 stub (no Parent initiative) — using --quick path."
  "$BRIEF_WORKER" --quick "$WINDOW" "$RESUME_BODY" || rc=$?
fi

if [[ $rc -eq 0 ]]; then
  echo "[resume-worker] OK — resume re-brief submitted to '$WINDOW'. Worker should re-read STATE.md and continue from the Resume cursor."
else
  echo "[resume-worker] FAILED to deliver resume re-brief (brief-worker.sh exit $rc)." >&2
fi
exit $rc
