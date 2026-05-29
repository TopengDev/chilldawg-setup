#!/usr/bin/env bash
# PreToolUse hook on Bash — blocks raw `git commit` and forces use of the /commit skill.
# Allows commands that merely contain the word "commit" in flags (e.g. git log --grep=commit).
# Word-boundary regex matches `git` followed by whitespace then `commit` as standalone tokens.
#
# Bypass: the /commit skill prefixes its commit with the CLAUDE_COMMIT_SKILL=1 sentinel, so
# skill-driven commits pass while a bare `git commit` typed by the model is denied. This is a
# nudge toward /commit (not a security boundary) — an exotic manual case can add the sentinel
# after asking Christopher first.

set -euo pipefail

cmd="$(jq -r '.tool_input.command // ""')"

if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+commit\b' \
   && ! printf '%s' "$cmd" | grep -qE 'CLAUDE_COMMIT_SKILL=1'; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: Use the /commit skill instead of raw 'git commit'. The /commit skill handles staging, message generation, attribution rules, and commit conventions consistently. (It bypasses this hook via the CLAUDE_COMMIT_SKILL=1 sentinel.) If you genuinely need to bypass for an exotic case, ask Christopher first."}}
EOF
fi

exit 0
