#!/usr/bin/env bash
# PostToolUse hook for Edit|Write — runs linters after file modifications.
# Reports lint errors back to Claude so it can self-correct in the next turn.
#
# Supported:
#   .go       → golangci-lint run (scoped to the edited package)
#   .ts/.tsx  → tsc --noEmit (from nearest tsconfig.json directory)
#
# Exit behavior:
#   exit 0 silently   → lint passed or unsupported file type (no output = no block)
#   exit 0 with JSON  → lint failed, "decision":"block" tells Claude to fix errors

set -euo pipefail

# Read tool input from stdin (Claude Code pipes JSON with tool_input)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path or file doesn't exist (e.g., deleted file)
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

EXT="${FILE_PATH##*.}"
LINT_OUTPUT=""
LINTER_NAME=""

case "$EXT" in
  go)
    # Verify golangci-lint is available
    command -v golangci-lint &>/dev/null || exit 0

    # Find Go module root (walk up to go.mod)
    DIR=$(dirname "$FILE_PATH")
    MOD_ROOT="$DIR"
    while [[ "$MOD_ROOT" != "/" ]]; do
      [[ -f "$MOD_ROOT/go.mod" ]] && break
      MOD_ROOT=$(dirname "$MOD_ROOT")
    done
    [[ ! -f "$MOD_ROOT/go.mod" ]] && exit 0

    LINTER_NAME="golangci-lint"
    # Scope to the edited file's package directory, check EXIT CODE (not just output)
    REL_DIR=$(realpath --relative-to="$MOD_ROOT" "$DIR" 2>/dev/null || echo ".")
    LINT_EXIT=0
    LINT_OUTPUT=$(cd "$MOD_ROOT" && golangci-lint run "./$REL_DIR/..." 2>&1) || LINT_EXIT=$?
    # Exit code 0 = clean, exit code 1+ = issues found
    [[ $LINT_EXIT -eq 0 ]] && exit 0
    ;;

  ts|tsx)
    # Find nearest tsconfig.json (walk up from file)
    DIR=$(dirname "$FILE_PATH")
    TS_ROOT=""
    SEARCH="$DIR"
    while [[ "$SEARCH" != "/" ]]; do
      if [[ -f "$SEARCH/tsconfig.json" ]]; then
        TS_ROOT="$SEARCH"
        break
      fi
      SEARCH=$(dirname "$SEARCH")
    done
    [[ -z "$TS_ROOT" ]] && exit 0

    # Verify npx + local typescript installation exist
    command -v npx &>/dev/null || exit 0
    # Check for real typescript installation (walk up for monorepo hoisting)
    FOUND_TS=""
    SEARCH="$TS_ROOT"
    while [[ "$SEARCH" != "/" ]]; do
      if [[ -f "$SEARCH/node_modules/typescript/lib/tsc.js" ]]; then
        FOUND_TS="1"
        break
      fi
      SEARCH=$(dirname "$SEARCH")
    done
    [[ -z "$FOUND_TS" ]] && exit 0

    LINTER_NAME="tsc"
    # tsc exits 0 on clean, non-zero on errors
    LINT_EXIT=0
    LINT_OUTPUT=$(cd "$TS_ROOT" && npx tsc --noEmit 2>&1) || LINT_EXIT=$?
    [[ $LINT_EXIT -eq 0 ]] && exit 0
    ;;

  *)
    # Unsupported file type — skip silently
    exit 0
    ;;
esac

# No output despite non-zero exit → skip (edge case)
[[ -z "$LINT_OUTPUT" ]] && exit 0

# Truncate to avoid flooding Claude's context window (max 3000 chars)
if [[ ${#LINT_OUTPUT} -gt 3000 ]]; then
  LINT_OUTPUT="${LINT_OUTPUT:0:3000}
... (truncated — run $LINTER_NAME manually for full output)"
fi

# Build the block response with proper JSON escaping via jq
jq -n \
  --arg reason "Lint errors after editing $FILE_PATH ($LINTER_NAME)" \
  --arg errors "$LINT_OUTPUT" \
  '{
    decision: "block",
    reason: ($reason + ":\n" + $errors)
  }'
