#!/usr/bin/env bash
# PreToolUse hook on Bash — "seal guard". Blocks raw history-mutating git operations and
# forces use of the proper skills/flows. Currently guards three operations:
#
#   1. `git commit`   -> use the /commit skill        (bypass: CLAUDE_COMMIT_SKILL=1)
#   2. `git merge`    -> intentional merge only       (bypass: CLAUDE_MERGE_OK=1)
#   3. `gh pr merge`  -> intentional PR merge only     (bypass: CLAUDE_MERGE_OK=1)
#
# Matchers are word-boundary precise so commands that merely CONTAIN the words pass:
#   - `git log --grep=commit` / `git log --grep=merge`  -> allowed (git is followed by `log`)
#   - `git merge-base` / `git merge-tree` / `git merge-file`  -> allowed (read-only plumbing;
#     `merge` must be followed by whitespace or end-of-string, not `-`)
#
# Bypass sentinels are env-var prefixes on the command itself:
#   - The /commit skill prefixes CLAUDE_COMMIT_SKILL=1, so skill-driven commits pass while a
#     bare `git commit` typed by the model is denied (#157).
#   - Prefix CLAUDE_MERGE_OK=1 for an intentional `git merge` / `gh pr merge` (e.g. a /seal-style
#     flow or a deliberate manual merge) so those aren't deadlocked. `git merge --abort` (recovery)
#     is also caught by the matcher — prefix the sentinel to run it.
#
# This is a nudge toward the proper flow (not a hard security boundary). Ask Christopher before
# bypassing for anything non-routine.

set -euo pipefail

cmd="$(jq -r '.tool_input.command // ""')"

# 1. Raw `git commit` (no /commit sentinel) -> deny.
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+commit\b' \
   && ! printf '%s' "$cmd" | grep -qE 'CLAUDE_COMMIT_SKILL=1'; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: Use the /commit skill instead of raw 'git commit'. The /commit skill handles staging, message generation, attribution rules, and commit conventions consistently. (It bypasses this hook via the CLAUDE_COMMIT_SKILL=1 sentinel.) If you genuinely need to bypass for an exotic case, ask Christopher first."}}
EOF
  exit 0
fi

# 2. Raw `git merge` (no merge sentinel) -> deny. `merge` must be followed by whitespace or
#    end-of-line so `git merge-base`/`merge-tree`/`merge-file` (read-only) stay allowed.
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+merge([[:space:]]|$)' \
   && ! printf '%s' "$cmd" | grep -qE 'CLAUDE_MERGE_OK=1'; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: raw 'git merge' is gated (seal guard). Merging mutates history and should be an intentional, reviewed action — not an incidental model step. If this merge is deliberate (e.g. a /seal-style flow), re-run it prefixed with the CLAUDE_MERGE_OK=1 sentinel. If unsure, ask Christopher first. (Read-only 'git merge-base'/'merge-tree' are NOT blocked.)"}}
EOF
  exit 0
fi

# 3. `gh pr merge` (no merge sentinel) -> deny.
if printf '%s' "$cmd" | grep -qE '\bgh[[:space:]]+pr[[:space:]]+merge\b' \
   && ! printf '%s' "$cmd" | grep -qE 'CLAUDE_MERGE_OK=1'; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: 'gh pr merge' is gated (seal guard). Merging a PR is an intentional, reviewed action. If deliberate, re-run prefixed with the CLAUDE_MERGE_OK=1 sentinel, or ask Christopher first."}}
EOF
  exit 0
fi

exit 0
