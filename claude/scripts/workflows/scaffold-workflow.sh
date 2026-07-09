#!/usr/bin/env bash
# ============================================================================
# DRAFT (agent-org piece 2.5) -- this is NOT the live file. Install at cutover.
#   REAL PATH (live):  ~/.claude/scripts/workflows/scaffold-workflow.sh
#     ~/.claude/scripts is a SYMLINK into the chilldawg-setup dotfiles repo:
#     ~/claude/Git/repositories/chilldawg-setup/claude/scripts/workflows/scaffold-workflow.sh
#   Do NOT edit the live file while staging. Install this draft over it at
#   cutover (see CUTOVER.md, "INSTALL: piece 2.5").
#
#   WHAT CHANGED vs live (surgical): the emitted spawn-worker.sh / brief-worker.sh
#   commands now match the new agent-org signatures -- a worker is a PANE inside
#   its supervisor's window (was: its own window), briefed by its %NN pane id. A
#   `--supervisor <window>` option supplies that window. Everything else (the
#   fan-out-review / recon-implement-verify / loop-until-green scaffolding, the
#   triage.json + STATE.md + brief.md writing, the initiative file) is unchanged.
#   NOTE: task-notes are still rooted at $NOTES_DIR here; a fuller new-org
#   reconciliation (records -> projects/<p>/tasks/) is a separate follow-up,
#   out of scope for piece 2.5.
# ============================================================================
#
# scaffold-workflow.sh -- instantiate the 3-tier pre-spawn artifacts for a
# multi-worker WORKFLOW so main doesn't hand-assemble them every time.
#
# This is the codified-playbook *scaffolding*. It does NOT spawn or orchestrate
# (the supervisor still drives spawn-worker.sh + brief-worker.sh + the attn loop).
# It writes exactly the files the pipeline gates require -- one task dir per
# worker, each with triage.json + STATE.md (from the live template) + a brief.md
# stub shaped for that worker's role -- plus (optionally) an initiative file. Then
# it prints the exact spawn/brief commands to run.
#
# Usage:
#   scaffold-workflow.sh <pattern> <run-slug> [options]
#
#   <pattern>   one of: fan-out-review | recon-implement-verify | loop-until-green
#   <run-slug>  short slug for this run (e.g. pulse-ga-audit, bms-sit-closeout)
#
# Options:
#   --level L1|L2|L3        triage level for the worker tasks (default L2)
#   --initiative <slug>     parent initiative slug (created if missing). Default:
#                           <run-slug> itself.
#   --supervisor <window>   (agent-org) the SUPERVISOR window these workers are
#                           spawned INTO as PANES. A worker is a pane in this
#                           window, not its own window. Default: the initiative
#                           slug (which defaults to <run-slug>). Emitted as arg 1
#                           of spawn-worker.sh.
#   --agents "a b c"        (fan-out-review) space-separated dimension names.
#                           Default: quality security performance ux biz-logic
#   --phases "a b c"        (recon-implement-verify) phase worker names.
#                           Default: recon implement verify
#   --iterations N          (loop-until-green) how many loop-iteration stubs to
#                           pre-create. Default: 1 (the loop driver re-uses the dir).
#   --notes-dir <dir>       task-notes root (default ~/claude/notes)
#   --signoff               mark L3 triage signoff=true (ONLY after Toper approved)
#   --dry-run               print what would be created, write nothing
#
# Exit: 0 ok . 2 usage/infra error.
#
# AGENT-ORG (piece 2.5): the emitted commands match the new spawn-worker.sh
# signature `spawn-worker.sh <supervisor_window> <worker_name> [cwd] [task_dir]`
# (a worker is a PANE in the supervisor window; cwd defaults to that project's
# repo/) and brief a worker BY ITS %NN pane id (brief-worker.sh now accepts a
# pane target -- the %NN spawn-worker.sh prints).

set -uo pipefail

PROG="scaffold-workflow.sh"
NOTES_DIR="${NOTES_DIR:-$HOME/claude/notes}"
DATE="$(date +%Y-%m-%d)"
TEMPLATE_STATE="$NOTES_DIR/templates/STATE.md"
TEMPLATE_INIT="$NOTES_DIR/templates/initiative.md"

die() { echo "$PROG: $*" >&2; exit 2; }
usage() {
  grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

PATTERN="${1:-}"; RUN="${2:-}"
[[ -z "$PATTERN" || -z "$RUN" ]] && usage
shift 2

LEVEL="L2"; INITIATIVE="$RUN"; SUPERVISOR=""; AGENTS="quality security performance ux biz-logic"
PHASES="recon implement verify"; ITERS=1; SIGNOFF="false"; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --level) LEVEL="${2:?}"; shift 2 ;;
    --initiative) INITIATIVE="${2:?}"; shift 2 ;;
    --supervisor) SUPERVISOR="${2:?}"; shift 2 ;;
    --agents) AGENTS="${2:?}"; shift 2 ;;
    --phases) PHASES="${2:?}"; shift 2 ;;
    --iterations) ITERS="${2:?}"; shift 2 ;;
    --notes-dir) NOTES_DIR="${2:?}"; shift 2 ;;
    --signoff) SIGNOFF="true"; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown option: $1" ;;
  esac
done

# Resolve the supervisor window (arg 1 of the emitted spawn-worker.sh). Defaults
# to the initiative slug (which itself defaults to the run slug). In the agent-org
# model the supervisor window is normally the project slug.
[[ -z "$SUPERVISOR" ]] && SUPERVISOR="$INITIATIVE"

case "$LEVEL" in L1|L2|L3) ;; *) die "--level must be L1|L2|L3" ;; esac
case "$PATTERN" in
  fan-out-review|recon-implement-verify|loop-until-green) ;;
  *) die "unknown pattern '$PATTERN' (fan-out-review|recon-implement-verify|loop-until-green)" ;;
esac
[[ -f "$TEMPLATE_STATE" ]] || die "STATE.md template not found at $TEMPLATE_STATE"

INIT_FILE="$NOTES_DIR/initiatives/${INITIATIVE}.md"

say() { echo "$@"; }
write_file() {  # write_file <path> <<<content  (respects --dry-run)
  local path="$1"
  if (( DRY )); then
    say "  [dry-run] would write: $path"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  say "  wrote: $path"
}

# --- initiative (create if missing) ------------------------------------------
ensure_initiative() {
  if [[ -f "$INIT_FILE" ]]; then
    say "initiative exists: $INIT_FILE (reusing)"
    return 0
  fi
  say "initiative: creating $INIT_FILE"
  if (( DRY )); then say "  [dry-run] would create initiative from template"; return 0; fi
  mkdir -p "$(dirname "$INIT_FILE")"
  if [[ -f "$TEMPLATE_INIT" ]]; then
    sed -e "s/<NAME>/${INITIATIVE}/g" -e "s/<area-verb-noun>/${INITIATIVE}/g" \
        -e "s/<YYYY-MM-DD>/${DATE}/g" "$TEMPLATE_INIT" > "$INIT_FILE"
  else
    {
      echo "# Initiative: ${INITIATIVE}"
      echo
      echo "**Slug:** ${INITIATIVE}"
      echo "**Status:** ACTIVE"
      echo "**Started:** ${DATE}"
      echo
      echo "## Child tasks"
    } > "$INIT_FILE"
  fi
  say "  wrote: $INIT_FILE"
}

# --- per-worker task dir (triage.json + STATE.md + brief.md) ------------------
# make_task <window-name> <role-line> <brief-body-file-or-empty>
make_task() {
  local win="$1" role="$2" briefbody="${3:-}"
  local dir="$NOTES_DIR/${win}-${DATE}"
  say "task: $win  ->  $dir"

  # triage.json
  printf '{\n  "task_slug": "%s",\n  "level": "%s",\n  "scope": "%s",\n  "created": "%s",\n  "signoff": %s\n}\n' \
    "$win" "$LEVEL" "$role" "$(date -Iseconds)" "$SIGNOFF" | write_file "$dir/triage.json"

  # STATE.md from template (fill name/worker/parent/date)
  if (( DRY )); then
    say "  [dry-run] would write: $dir/STATE.md (from template)"
  else
    mkdir -p "$dir"
    sed -e "s/<NAME>/${win}/g" -e "s/<worker-name>/${win}/g" \
        -e "s/<initiative-slug>/${INITIATIVE}/g" \
        -e "s|<YYYY-MM-DD HH:MM WIB>|${DATE} $(date +%H:%M) WIB|g" \
        "$TEMPLATE_STATE" > "$dir/STATE.md"
    say "  wrote: $dir/STATE.md"
  fi

  # brief.md stub
  {
    echo "# Brief: ${win}"
    echo
    echo "**Workflow:** ${PATTERN} . **Run:** ${RUN} . **Parent initiative:** ${INITIATIVE}"
    echo "**Supervisor window:** ${SUPERVISOR} (you are a PANE in this window; report to this supervisor)"
    echo
    echo "## Role"
    echo
    echo "${role}"
    echo
    if [[ -n "$briefbody" && -f "$briefbody" ]]; then
      cat "$briefbody"
    else
      echo "## Task"
      echo
      echo "<FILL ME: the concrete task for this worker. Be specific -- concrete"
      echo "targets, file paths, pattern lists, and the verification gate this"
      echo "worker must pass before reporting COMPLETE.>"
      echo
      echo "## Verification gate (must pass before COMPLETE)"
      echo
      echo "- [ ] <how this worker proves its output is correct -- evidence, not claims>"
      echo
      echo "## On completion"
      echo
      echo "- Write report.md + result.json (see brief-worker role-override contract)."
      echo "- Decompose your work into idempotent STATE.md checkpoints as you go"
      echo "  (resumable if you get killed / hit the session limit)."
    fi
  } | write_file "$dir/brief.md"

  # echo the spawn/brief lines for this worker (agent-org signatures).
  # spawn-worker.sh <supervisor_window> <worker_name> [cwd] [task_dir]:
  #   arg1 = the supervisor window the worker is a PANE in
  #   arg2 = the worker name (this task's slug)
  #   cwd  = omitted -> spawn-worker.sh defaults it to ~/claude/projects/<sup>/repo
  #   TASK_DIR env carries the triage.json + STATE.md dir (avoids a positional
  #     empty-cwd footgun on copy-paste).
  SPAWN_CMDS+=("TASK_DIR=${dir} spawn-worker.sh ${SUPERVISOR} ${win}")
  # brief-worker.sh now takes the worker's %NN PANE id (printed by spawn-worker.sh),
  # NOT the worker name. Replace PANE_ID with that %NN. WORKER_NAME=<name> makes the
  # role-override preamble name the worker correctly (pane title is unreliable).
  BRIEF_CMDS+=("WORKER_NAME=${win} brief-worker.sh PANE_ID ${dir}/brief.md")
}

declare -a SPAWN_CMDS=() BRIEF_CMDS=()

say "──────────────────────────────────────────────────────────────"
say " scaffold-workflow: ${PATTERN}  (run=${RUN}, level=${LEVEL}, supervisor=${SUPERVISOR})"
say "──────────────────────────────────────────────────────────────"
ensure_initiative

case "$PATTERN" in
  fan-out-review)
    for a in $AGENTS; do
      make_task "${RUN}-${a}" "Parallel REVIEW LENS '${a}': review the target with this ONE sharp focus. Cite file:line for every finding. Tag each confirmed|probable|theoretical. Do NOT fix -- report only. See workflows/fan-out-review.md."
    done
    SYNTH_DIR="$NOTES_DIR/${RUN}-synthesis-${DATE}"
    make_task "${RUN}-synthesis" "SYNTHESIS agent: ingest all lens workers' result.json + report.md, dedupe, classify by severity x confidence, produce the consolidated verdict. Runs AFTER all lenses report. See workflows/fan-out-review.md."
    ;;
  recon-implement-verify)
    set -- $PHASES
    for p in "$@"; do
      case "$p" in
        recon)     role="RECON phase: map the territory before any change. Read the code/system, identify the exact change surface, list affected files + callers + tests, surface constraints/risks. Output a recon report the implement phase consumes. NO code changes." ;;
        implement) role="IMPLEMENT phase: make the change per the recon findings. Follow read-before-write. Keep changes scoped. Update STATE.md checkpoints per sub-step (resumable)." ;;
        verify)    role="VERIFY phase: prove the implementation works end-to-end. Run the actual flow, capture evidence (command output, screenshots, curl, DB rows). Check for regressions. Report evidence, not claims." ;;
        *)         role="Phase '${p}': <fill role>." ;;
      esac
      make_task "${RUN}-${p}" "$role"
    done
    ;;
  loop-until-green)
    for ((i = 1; i <= ITERS; i++)); do
      make_task "${RUN}-iter${i}" "LOOP iteration ${i}: run the check (build/test/lint/audit), if RED fix the first failure, re-run. Repeat until GREEN or budget hit. Each fix is an idempotent checkpoint. The loop driver re-briefs this same worker via resume-worker.sh between iterations. See workflows/loop-until-green.md."
    done
    ;;
esac

say "──────────────────────────────────────────────────────────────"
if (( DRY )); then
  say " [dry-run] no files written."
else
  say " scaffold complete. Update each brief.md 'Task' section, then run:"
fi
say ""
say " # 0. ensure the SUPERVISOR window '${SUPERVISOR}' exists first:"
say " #      spawn-supervisor.sh ${SUPERVISOR}"
say " #    Workers below are spawned as PANES inside it; each worker's cwd"
say " #    defaults to ~/claude/projects/${SUPERVISOR}/repo (pass a 3rd arg to override)."
say ""
say " # 1. spawn each worker as a pane in '${SUPERVISOR}' (triage-gated). Each spawn"
say " #    prints the worker's pane id: 'OK: worker ... spawned as pane %NN ...':"
for c in "${SPAWN_CMDS[@]}"; do say "   $c"; done
say ""
say " # 2. after attn-peers confirms the worker, brief it BY THAT %NN pane id"
say " #    (replace PANE_ID with the %NN spawn-worker.sh printed for that worker):"
for c in "${BRIEF_CMDS[@]}"; do say "   $c"; done
say ""
say " # monitor: fleetview.sh --watch   .   read results: result-schema.sh <task-dir>"
say "──────────────────────────────────────────────────────────────"
