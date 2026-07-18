#!/usr/bin/env bash
# block-worktree-isolation.sh — PreToolUse hook: global ban on isolated git worktrees.
#
# Wired in settings.json as a PreToolUse hook with matchers "Bash" and
# "Agent|Workflow|EnterWorktree". Denies any tool call that CREATES or ENTERS an
# isolated git worktree, for every agent (main, supervisors, workers, VPS manager,
# subagents) per Christopher's 2026-07-17 standing directive (universal CLAUDE.md,
# "Git Worktrees — TOTAL BAN").
#
# Branches on .tool_name:
#   Bash          -> deny iff the command invokes `git worktree add|move|lock`
#                    (cleanup verbs list/remove/prune/unlock stay ALLOWED — they
#                    reduce worktrees, never create/mutate one into existence)
#   Agent         -> deny iff tool_input.isolation == "worktree"
#   Workflow      -> deny iff the script (inline tool_input.script, or read from
#                    tool_input.scriptPath when script is absent) sets
#                    isolation: 'worktree' on an agent() call
#   EnterWorktree -> deny unconditionally (this tool ONLY creates/enters a worktree)
#   anything else -> allow
#
# SAFETY — FAIL OPEN on every uncertainty (same posture as triage-gate-hook.sh /
# block-raw-git-commit.sh):
#   * Unknown/malformed JSON, unrecognized tool_name, unreadable scriptPath -> allow
#   * Only a CONFIRMED match denies.
#
# KNOWN ACCEPTED FALSE POSITIVE (same class as the seal-guard's own caveat): a
# command that merely CONTAINS the literal text "git worktree add" inside a quoted
# string (e.g. `echo "run git worktree add later"`) will false-deny, since this
# hook does not parse shell quoting/tokenization. Rare in practice; accepted.
#
# NOTE: hooks load at session start. Editing this file or settings.json does NOT
# affect already-running sessions — restart Claude Code to pick up changes.

set -uo pipefail

input="$(cat 2>/dev/null || true)"
[[ -z "$input" ]] && exit 0

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)"

MSG="WORKTREE BAN: isolated git worktrees are banned for ALL agents (Christopher's standing directive 2026-07-17; universal CLAUDE.md rule). Do the work in the live working tree; for parallel mutations, sequence the work or split by file ownership. Cleanup of an existing worktree (list/remove/prune) is allowed."

deny() {
  jq -cn --arg m "$MSG" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m}}'
  exit 0
}

case "$tool_name" in
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
    [[ -z "$cmd" ]] && exit 0
    # Collapse backslash-newline line continuations before matching (same as
    # triage-gate-hook.sh) so a multi-line chained invocation still matches.
    cmd="$(printf '%s' "$cmd" | sed -e ':x' -e '/\\$/{N;s/\\\n//;bx}')"
    if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?worktree[[:space:]]+(add|move|lock)\b'; then
      deny
    fi
    exit 0
    ;;
  Agent)
    isolation="$(printf '%s' "$input" | jq -r '.tool_input.isolation // ""' 2>/dev/null || true)"
    [[ "$isolation" == "worktree" ]] && deny
    exit 0
    ;;
  Workflow)
    script="$(printf '%s' "$input" | jq -r '.tool_input.script // empty' 2>/dev/null || true)"
    if [[ -z "$script" ]]; then
      script_path="$(printf '%s' "$input" | jq -r '.tool_input.scriptPath // empty' 2>/dev/null || true)"
      if [[ -n "$script_path" && -r "$script_path" ]]; then
        script="$(cat "$script_path" 2>/dev/null || true)"
      fi
    fi
    [[ -z "$script" ]] && exit 0
    if printf '%s' "$script" | grep -qE "isolation[[:space:]]*:[[:space:]]*['\"]worktree['\"]"; then
      deny
    fi
    exit 0
    ;;
  EnterWorktree)
    deny
    ;;
  *)
    exit 0
    ;;
esac
