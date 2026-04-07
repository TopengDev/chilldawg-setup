#!/usr/bin/env bash
# PreToolUse hook on Bash — blocks raw `git commit` and forces use of the /commit skill.
# Allows commands that merely contain the word "commit" in flags (e.g. git log --grep=commit).
# Word boundary regex matches `git` followed by whitespace then `commit` as standalone tokens.

set -euo pipefail

cmd="$(jq -r '.tool_input.command // ""')"

if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+commit\b'; then
  cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"BLOCKED: Use the /commit skill instead of raw 'git commit'. The /commit skill handles staging, message generation, co-author attribution, and commit conventions consistently. If you genuinely need to bypass for an exotic case, ask Christopher first."}}
EOF
fi

exit 0
