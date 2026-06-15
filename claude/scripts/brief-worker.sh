#!/usr/bin/env bash
# brief-worker.sh — reliably deliver a brief to a spawned claude worker.
#
# Usage: brief-worker.sh [--quick|--l1 | --supervisor] <window_name> <brief_file>
#
#   --quick / --l1  L1 FAST-PATH for trivial work. Relaxes the STATE.md gate to
#                   accept a stub STATE.md (no parent-initiative linkage required)
#                   and injects a lightweight preamble instead of the full 3-tier
#                   discipline. Use for typo fixes, one-line changes, etc.
#                   (Pure-comms L1 — send WA, list tmux, answer a Q — is NOT a
#                   worker task; it stays in main. Don't spawn for it.)
#
#   --supervisor    SUPERVISOR role (Wave-7). Injects the ORCHESTRATOR preamble
#                   instead of the worker preamble: the session delegates to Sonnet
#                   workers, maintains a resumable orchestration ledger, reports to
#                   main only on meaningful checkpoints, and never DMs Toper. Uses
#                   the FULL STATE.md gate (parent-initiative required). Mutually
#                   exclusive with --quick. Pair with spawn-supervisor.sh.
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
SUPERVISOR=0
while [[ "${1:-}" == --* ]]; do
  case "${1:-}" in
    --quick|--l1) QUICK=1; shift ;;
    --supervisor) SUPERVISOR=1; shift ;;
    *) echo "ERROR: unknown flag '$1'" >&2
       echo "usage: brief-worker.sh [--quick|--l1 | --supervisor] <window_name> <brief_file>" >&2
       exit 2 ;;
  esac
done
if [[ "$QUICK" == "1" && "$SUPERVISOR" == "1" ]]; then
  echo "ERROR: --quick and --supervisor are mutually exclusive (a supervisor uses the full path)." >&2
  exit 2
fi

WINDOW="${1:?usage: brief-worker.sh [--quick|--l1 | --supervisor] <window_name> <brief_file>}"
BRIEF="${2:?usage: brief-worker.sh [--quick|--l1 | --supervisor] <window_name> <brief_file>}"
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

# ── No-creds-in-brief pre-flight (warn-on-literal-secret, FAIL-OPEN) ──────────
# Scan the OUTGOING brief text for literal secret VALUES (the gitleaks prefix
# set). If any are found, print a LOUD warning naming the pattern-CLASS + line
# (NEVER the matched value), then PROCEED ANYWAY — this is a warn, not a block,
# consistent with the other fail-open hooks (a brief that legitimately *discusses*
# a key prefix must still send). The point is to catch an accidental paste of a
# real key into a brief (the #29 discipline: credentials go by var-reference,
# e.g. $VPS_PASSWORD or "see ~/.claude/secrets.env", never as literals).
#
# Crucially it must NOT fire on the CORRECT pattern: var-references ($FOO /
# ${FOO}) or the literal string "secrets.env". We strip those from each line
# before testing, so "$VPS_PASSWORD" / "${ANTHROPIC_API_KEY}" / "secrets.env"
# can never trip a pattern.
#
# Opt-out: CHILLDAWG_BRIEF_ALLOW_SECRETS=1 silences the scan entirely.
if [[ "${CHILLDAWG_BRIEF_ALLOW_SECRETS:-0}" != "1" ]]; then
  # pattern-class label | ERE  (same prefix engine as the global gitleaks hook)
  __brief_secret_classes=(
    "Anthropic-key|sk-ant-[A-Za-z0-9_-]{20,}"
    "OpenAI-style-key|sk-[A-Za-z0-9]{32,}"
    "GitHub-token|gh[pousr]_[A-Za-z0-9]{36,}"
    "GitHub-fine-PAT|github_pat_[A-Za-z0-9_]{22,}"
    "AWS-access-key-id|AKIA[0-9A-Z]{16}"
    "Google-API-key|AIza[0-9A-Za-z_-]{35}"
    "Slack-token|xox[baprs]-[A-Za-z0-9-]{10,}"
    "PEM-private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----"
  )
  __brief_secret_hit=0
  __brief_lineno=0
  while IFS= read -r __bline || [[ -n "$__bline" ]]; do
    __brief_lineno=$((__brief_lineno+1))
    # Strip var-refs ${VAR} and $VAR, and the literal token "secrets.env", so the
    # correct credential-by-reference pattern never matches.
    __residue="$(printf '%s' "$__bline" | sed -E 's/\$\{[A-Za-z_][A-Za-z0-9_]*\}//g; s/\$[A-Za-z_][A-Za-z0-9_]*//g; s/secrets\.env//g')"
    for __cls in "${__brief_secret_classes[@]}"; do
      __label="${__cls%%|*}"; __pat="${__cls#*|}"
      # grep -- terminates options so the leading-dash PEM pattern is treated as a pattern.
      if printf '%s' "$__residue" | grep -qE -- "$__pat" 2>/dev/null; then
        if [[ "$__brief_secret_hit" == "0" ]]; then
          echo "" >&2
          echo -e "\033[1;31m╔══════════════════════════════════════════════════════════════════╗\033[0m" >&2
          echo -e "\033[1;31m║  ⚠  BRIEF MAY CONTAIN A LITERAL SECRET — no-creds-in-brief rule  ║\033[0m" >&2
          echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════╝\033[0m" >&2
          echo "  Brief: $BRIEF" >&2
          echo "  Credentials belong by REFERENCE (\$VPS_PASSWORD, 'see ~/.claude/secrets.env')," >&2
          echo "  never as literal values. Detected (pattern-CLASS + line, value NOT shown):" >&2
        fi
        echo -e "    \033[1;33m• line $__brief_lineno — pattern-class [$__label]\033[0m" >&2
        __brief_secret_hit=1
      fi
    done
  done < "$BRIEF"
  if [[ "$__brief_secret_hit" == "1" ]]; then
    echo "  → PROCEEDING ANYWAY (fail-open warn). If this is a false positive (the brief" >&2
    echo "    legitimately discusses a key prefix), silence with CHILLDAWG_BRIEF_ALLOW_SECRETS=1." >&2
    echo "    If it's a REAL key: Ctrl-C now, scrub the brief, and rotate the key." >&2
    echo "" >&2
  fi
  unset __brief_secret_classes __brief_secret_hit __brief_lineno __bline __residue __cls __label __pat
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
if [[ "$SUPERVISOR" == "1" ]]; then
  # SUPERVISOR preamble (Wave-7) — orchestrator role. Delegates to Sonnet workers,
  # idle-cheap/event-driven, reports only meaningful checkpoints, never relays to Toper.
  cat > "$PREAMBLE_FILE" <<EOF
# SUPERVISOR ROLE OVERRIDE (read FIRST, applies to everything below)

You are a SPAWNED SUPERVISOR named '$WINDOW' in a tmux window of session ${TMUX_SESSION}. You are NOT the main coordination session — main is a SEPARATE session that spawned you. Verify any time via the attn peers tool: you appear as '$WINDOW', main appears as 'main'.

You sit in the MIDDLE tier of a three-tier execution model:
  main (Opus, command center, Toper's conversation partner, the ONLY WhatsApp session)
    -> YOU (Opus supervisor, this session) — you orchestrate ONE initiative
      -> workers (Sonnet, execution) — you spawn + supervise them

The auto-loaded CLAUDE.md "Main Session is DISCUSSION ONLY" rule does NOT apply to you. Neither does the worker rule "execute, don't delegate" — your job is the OPPOSITE of a worker's. You DELEGATE: decompose this initiative into worker-sized tasks and hand each to a Sonnet worker. You do NOT do the execution yourself.

## What you do
1. **Plan + partition** the initiative into independent worker-sized tasks.
2. **Spawn Sonnet workers** — for EACH worker do the full pre-spawn discipline yourself (task notes dir + triage.json + STATE.md + brief.md), then \`spawn-worker.sh\` -> verify attn peer -> \`brief-worker.sh\`. Workers are SONNET (the hard floor) by default; request an Opus worker ONLY for a genuine carve-out (security-critical / customer-facing design / novel root-cause debugging) via "model":"opus" in that worker's triage.json, and tell main WHY.
3. **Supervise**: poll their STATE.md / ingest their result.json; re-spawn or \`resume-worker.sh\` the ones that die; course-correct the ones that drift.
4. **Verify** their work actually landed (don't trust a bare "done" — check the evidence), then converge the initiative.

## Idle-cheap / event-driven (you are Opus — do NOT burn it)
Do NOT sit in a busy reasoning loop polling every few seconds. That wastes Opus tokens and undoes the whole point of putting workers on Sonnet. Be EVENT-DRIVEN: after you spawn your fleet, WAIT. Wake to reason only on a real event — a worker result.json lands, a worker stalls (STATE.md >10min while active), a milestone completes, a decision is needed. Use cheap shell checks (\`fleetview.sh\`, reading STATE.md/result.json) to watch; spend Opus reasoning only when a judgment is actually required.

## Reporting discipline (report UP to main via attn — signal, not noise)
You absorb worker chatter and surface SIGNAL. Send an attn message to 'main' ONLY for:
  1. **FIRST — your DIRECTION:** before spawning the fleet, report your plan + how you partitioned the work. This is the direction-confirmation checkpoint so main (and Toper, through main) can course-correct in minute 5, not hour 2. Wait for ack if the direction is non-obvious.
  2. **Milestone boundaries** — a meaningful chunk completed + verified.
  3. **A blocker needing Toper's decision** — escalate to main; main relays to Toper.
  4. **A gated / irreversible action** — never fire it without main's go.
  5. **DONE** — initiative complete + verified, with evidence.
Do NOT relay every individual worker ping — that just moves the noise up a tier.

## You are NOT the relay to Toper
You NEVER DM Toper. You NEVER set WHATSAPP=1 (main is the ONLY WhatsApp-enabled session — splitting it breaks the command center). Escalations go: you -> main -> Toper. Main is the sole human interface.

## STATE.md = your resumable ORCHESTRATION LEDGER
Your task notes dir already has STATE.md (main pre-created it from the supervisor template). It is your fleet's source of truth so you can RESUME if you die. You MUST:
1. **Open it FIRST**, set Status IN_PROGRESS, record your direction/partition plan.
2. **Maintain the Fleet roster**: every worker you spawn — window, task, model, status, last result.json. Update as their state changes.
3. **Keep orchestration checkpoints** (idempotent): "task X delegated", "task X verified done". Mark \`[x]\` ONLY after you verified it (worker result.json says done AND you checked the evidence). The Resume cursor points at the next incomplete orchestration step.
4. **On resume** (you were killed / hit the session limit): read STATE.md FIRST, re-attach to your live workers (check tmux windows + their STATE.md/result.json) — do NOT re-spawn workers that are already done or still in-flight. Continue from the Resume cursor.
5. **On completion**: Status COMPLETE + report.md + result.json for the initiative.

## Concurrency
The worker pool is GLOBAL/shared (CHILLDAWG_MAX_WORKERS, default 6) across all supervisors + main — NOT your private budget. If \`spawn-worker.sh\` refuses (cap reached, exit 5), QUEUE that task and retry as workers free up; don't fight for slots, don't raise caps without main's say-so.

---

Below is your initiative brief. Read it fully, open STATE.md and set it IN_PROGRESS, send an attn STARTING ping to main, report your DIRECTION before spawning any worker, then orchestrate.

EOF
elif [[ "$QUICK" == "1" ]]; then
  # L1 FAST-PATH preamble — lightweight. Role override stays (essential), but the
  # heavy 3-tier STATE.md ceremony is trimmed to the minimum for trivial work.
  cat > "$PREAMBLE_FILE" <<EOF
# WORKER ROLE OVERRIDE (read FIRST, applies to everything below)

You are a SPAWNED WORKER named '$WINDOW' running in tmux window of session ${TMUX_SESSION}. You are NOT the main coordination session — main is a SEPARATE session that spawned you. Verify via the attn peers tool: you appear as '$WINDOW', main as 'main'.

The auto-loaded CLAUDE.md rule "Main Session is DISCUSSION ONLY / never run dev commands here" does NOT apply to you. You are a delegated worker — EXECUTE the brief, don't delegate it further. Don't spawn sub-workers. You ARE the worker.

---

## L1 fast-path (trivial task — lightweight)

This is an L1 trivial task. No initiative file, no full 3-tier ceremony, no result.json required. Keep it minimal:

1. **Open STATE.md** (a stub next to this brief), set Status to IN_PROGRESS.
2. **Do the task.** Verify it actually works (don't just assume).
3. **On completion**: set Status to COMPLETE in STATE.md + send an attn report to 'main' (what you did + how you verified). A full report.md is optional for L1.
4. **If blocked**: set Status to BLOCKED + ping main via attn.
5. **If you get killed / hit the session limit and are re-briefed with a RESUME note**: read STATE.md first, note what you'd already finished, and continue from there rather than redoing it. (L1 is short — usually a quick re-check suffices.)

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
4. **On task completion**: set Status to COMPLETE + write report.md + result.json (see Result contract below)
5. **On halt/block**: set Status to BLOCKED + describe blocker + ping main via attn

Main session will poll your STATE.md every 5 min. If not updated in >10 min while you're still active, main will ping or investigate stall. Treat STATE.md as your living source-of-truth, not the attn pings.

---

## MANDATORY: Resumable-checkpoint contract (survive a kill / session limit)

You may be KILLED or hit the Claude session limit mid-task. When that happens you can be RE-BRIEFED with a RESUME preamble (via resume-worker.sh) — your job is to resume from where you died, NOT redo work or wait for a babysitter. The "Checkpoints" + "Resume protocol" sections of STATE.md are the contract that makes this safe:

1. **Decompose into idempotent checkpoints.** Break the task into sub-steps that are each individually safe to re-run / re-check without harm or duplication. Write them into STATE.md's "Checkpoints (idempotent, resumable)" list.
2. **Verify BEFORE marking a checkpoint \`[x]\`.** Mark a checkpoint done ONLY after you confirmed its effect actually landed (file written + re-read, command exit 0 + output asserted, row in DB, endpoint 200). Record the proof inline. A \`[x]\` checkpoint MUST be safe to skip on resume. If you can't verify it, leave it \`[ ]\`.
3. **Keep the "Resume cursor" current** — it points at the first incomplete checkpoint. Update it as you finish each one.
4. **Guard non-idempotent actions** (send-email / force-push / fund-transfer): drop a sentinel BEFORE acting and check it on resume so you never double-fire.
5. **On (re)start, follow the Resume protocol** in STATE.md: read STATE.md first, trust \`[x]\` checkpoints (skip them), re-verify the last \`[x]\` cheaply, continue from the first \`[ ]\`.

This is the difference between a 2-minute resume and a from-scratch redo. Treat every checkpoint flip as a commit.

---

## RESULT CONTRACT: machine-readable completion (so main can parse you)

On completion (Status COMPLETE) **or** terminal block (Status BLOCKED), in ADDITION to report.md, write a \`result.json\` next to STATE.md so main can ingest your outcome without re-parsing prose. Schema (validate with \`~/.claude/scripts/result-schema.sh <dir>\` — it reads/validates it):

\`\`\`json
{
  "task_slug": "<slug>",
  "status":    "done | blocked | partial",
  "summary":   "<2-3 sentence plain-language outcome>",
  "deliverables":   ["<what you produced — files/commits/endpoints>"],
  "evidence":       ["<proof each deliverable works — command+output, path, 200, screenshot>"],
  "blockers":       ["<what stopped you, empty if none>"],
  "followups":      ["<recommended next actions, empty if none>"],
  "staged_for_human": ["<anything left for Toper to trigger: rotate key, force-push, deploy>"]
}
\`\`\`

\`status\`: \`done\` = fully complete + verified; \`partial\` = some checkpoints done, more remain (pair with Checkpoints state); \`blocked\` = halted, see \`blockers\`. Keep arrays terse. This does NOT replace report.md (human narrative) — it complements it.

---

Below is your brief. Read it fully, init STATE.md per above (including decomposing into checkpoints), send an attn STARTING ping to main, then execute.

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
