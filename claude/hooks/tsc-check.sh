#!/usr/bin/env bash
# PostToolUse hook (Edit|Write) — runs `tsc --noEmit` on edited .ts/.tsx files and
# injects the first ~20 lines of any type errors back into the agent's context via
# hookSpecificOutput.additionalContext (soft, non-blocking).
#
# Adapted from elpabl0's inline `bunx tsc` hook. Differences for THIS harness:
#   - In-script extension/tsconfig guard instead of the `"if"` glob-condition field:
#     the official CC hook command schema (verified on 2.1.158) has no `"if"` field, so
#     it would be silently ignored and tsc would run on EVERY edit regardless of type.
#   - No-op outside a TS project: walks up for the nearest tsconfig.json; exits 0 if none
#     (a bare `tsc --noEmit` in a non-TS cwd errors — this hook must stay silent there).
#   - Runner detection: prefer project-local node_modules/.bin/tsc, else `npx tsc` but ONLY
#     when a real typescript install is found up-tree (prevents npx from trying to download
#     it on a /dev/null stdin and emitting npm noise as fake "type errors").
#   - `timeout 30s` bound + FAIL-OPEN everywhere (any internal error/timeout -> exit 0).
#
# NOTE (redundancy): lint-check.sh ALSO runs tsc --noEmit on .ts/.tsx, with decision:"block".
# This hook coexists with it (per brief #158) via the softer additionalContext channel, so the
# two are behaviorally distinct (block vs. inform). The cost is tsc running TWICE per TS edit —
# see the #158 report; Christopher may want to consolidate after living with it.
#
# Exit behavior:
#   exit 0 silently  -> not a TS file / no tsconfig / no runner / clean / timeout / any error
#   exit 0 + JSON    -> type errors found; first ~20 lines injected as additionalContext

# FAIL-OPEN: never let an unexpected error block an edit or crash the harness.
set +e

main() {
  command -v jq >/dev/null 2>&1 || return 0

  local input file_path ext dir search ts_root runner found_ts out rc

  input="$(cat)" || return 0
  file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || return 0
  [ -n "$file_path" ] || return 0
  [ -f "$file_path" ] || return 0

  ext="${file_path##*.}"
  case "$ext" in
    ts|tsx) ;;
    *) return 0 ;;
  esac

  # Walk up for the nearest tsconfig.json. No tsconfig in scope -> not a TS project -> no-op.
  dir="$(dirname "$file_path")"
  ts_root=""
  search="$dir"
  while [ -n "$search" ] && [ "$search" != "/" ]; do
    if [ -f "$search/tsconfig.json" ]; then
      ts_root="$search"
      break
    fi
    search="$(dirname "$search")"
  done
  [ -n "$ts_root" ] || return 0

  # Pick a runner. Prefer a project-local tsc binary (walk up for monorepo hoisting).
  runner=""
  search="$ts_root"
  while [ -n "$search" ] && [ "$search" != "/" ]; do
    if [ -x "$search/node_modules/.bin/tsc" ]; then
      runner="$search/node_modules/.bin/tsc"
      break
    fi
    search="$(dirname "$search")"
  done

  # Fallback to `npx tsc` ONLY if typescript is actually installed up-tree (no auto-download).
  if [ -z "$runner" ]; then
    found_ts=""
    search="$ts_root"
    while [ -n "$search" ] && [ "$search" != "/" ]; do
      if [ -f "$search/node_modules/typescript/lib/tsc.js" ]; then
        found_ts="1"
        break
      fi
      search="$(dirname "$search")"
    done
    [ -n "$found_ts" ] || return 0
    command -v npx >/dev/null 2>&1 || return 0
    runner="npx tsc"
  fi

  # Run tsc bounded by timeout, from the tsconfig dir, no stdin (avoids interactive hangs).
  # $runner may be one word (path) or two (`npx tsc`) — intentional word-splitting.
  out="$(cd "$ts_root" && timeout 30s $runner --noEmit -p "$ts_root/tsconfig.json" 2>&1 < /dev/null)"
  rc=$?

  # Timeout (124) or runner vanished mid-run (126/127) -> stay silent per brief.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
    return 0
  fi

  # Cap the flood to the first 20 lines. Clean run -> empty -> silent.
  out="$(printf '%s\n' "$out" | head -20)"
  [ -n "$out" ] || return 0

  # Inject errors as additionalContext (jq does the JSON escaping).
  jq -n --arg ctx "$out" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:("tsc --noEmit found type errors:\n" + $ctx)}}' 2>/dev/null || return 0
  return 0
}

main
exit 0
