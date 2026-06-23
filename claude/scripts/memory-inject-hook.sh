#!/usr/bin/env bash
# memory-inject-hook.sh — UserPromptSubmit hook: proactive memory retrieval.
#
# On every user prompt, runs the LOCAL BM25 retrieval engine
# (memory-retrieve.py) over the prompt text and INJECTS a concise list of the
# most-relevant memory files into the model's context via `additionalContext`.
# The agent then reads the full file(s) only if it needs the detail — the hook
# never dumps bodies, just a pointer + one-line snippet per hit.
#
# This is the every-prompt hot path, so it is built to be:
#
#   * FAST   — a single `timeout 5 python3 memory-retrieve.py … --json` call.
#              The engine parses 193 docs + ranks in well under a second; the
#              5s timeout is a hard safety ceiling, not the expected cost.
#   * SILENT on anything uninteresting — trivial/empty prompts, slash-only
#              commands, and zero-hit queries emit nothing at all.
#   * FAIL-OPEN, ALWAYS — modelled on memory-write-validate.sh:
#       - `set -u`, an ERR trap to exit 0, and an EXIT path that only ever
#         exits 0.
#       - jq missing / python missing / engine error / timeout / empty output
#         / unparseable stdin  ->  emit NOTHING, exit 0.
#       - This hook must NEVER block a prompt, NEVER deny, and NEVER slow prompt
#         submission catastrophically. Losing a retrieval is acceptable;
#         disrupting the user's prompt is not.
#
# Output contract (UserPromptSubmit): a JSON object
#   {hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:"…"}}
# additionalContext is ADDITIVE context only — never a permission decision.
#
# Wire it in settings.json under hooks.UserPromptSubmit (see
# README-memory-retrieval.md for the exact snippet — it must be ADDED to the
# existing UserPromptSubmit array, not replace it). Hooks load at session start;
# restart Claude Code to pick up changes.

# Deliberately NOT `set -e`: fail-open means surviving any sub-failure.
set -u

# Absolute fail-safe: never let an uncaught error escape non-zero.
trap 'exit 0' ERR

clean_exit() { exit 0; }

# ---- locate tools (fail-open if missing) ----------------------------------- #
JQ="$(command -v jq 2>/dev/null || true)"
PY="$(command -v python3 2>/dev/null || true)"
TIMEOUT_BIN="$(command -v timeout 2>/dev/null || true)"
[ -z "$JQ" ] && clean_exit            # can't parse stdin or build output → bail open
[ -z "$PY" ] && clean_exit            # no engine runtime → bail open

ENGINE="${HOME}/.claude/scripts/memory-retrieve.py"
[ -f "$ENGINE" ] || clean_exit        # engine missing → bail open

# ---- read the UserPromptSubmit JSON; extract the prompt -------------------- #
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && clean_exit

# Harness field is `prompt`; accept `user_prompt` as a fallback. Fail open to "".
PROMPT="$(printf '%s' "$INPUT" | "$JQ" -r '.prompt // .user_prompt // ""' 2>/dev/null || true)"
[ -z "$PROMPT" ] && clean_exit

# ---- skip trivial prompts -------------------------------------------------- #
# Strip leading/trailing whitespace for the length check.
TRIMMED="$(printf '%s' "$PROMPT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' 2>/dev/null || printf '%s' "$PROMPT")"

# Too short to be worth a retrieval (e.g. "ok", "yes", "thanks", "go").
# Count characters; if under 12, skip.
NCHARS="$(printf '%s' "$TRIMMED" | wc -m 2>/dev/null | tr -d ' ' || echo 0)"
case "$NCHARS" in ''|*[!0-9]*) NCHARS=0 ;; esac
[ "$NCHARS" -lt 12 ] && clean_exit

# Pure slash-command invocations (e.g. "/commit", "/ship", "/standup morning")
# carry their own skill context — don't inject memories over them.
case "$TRIMMED" in
  /*)
    # If the WHOLE prompt is just a slash command + short args (no sentence),
    # skip. Heuristic: first token starts with '/' and the prompt is short.
    if [ "$NCHARS" -lt 60 ]; then
      clean_exit
    fi
    ;;
esac

# ---- run the engine (hard 5s ceiling) -------------------------------------- #
# Use `timeout` if available; otherwise run bare (the engine is sub-second).
if [ -n "$TIMEOUT_BIN" ]; then
  RESULTS_JSON="$("$TIMEOUT_BIN" 5 "$PY" "$ENGINE" "$PROMPT" -k 5 --json 2>/dev/null || true)"
else
  RESULTS_JSON="$("$PY" "$ENGINE" "$PROMPT" -k 5 --json 2>/dev/null || true)"
fi

# Empty / timeout / error → say nothing.
[ -z "$RESULTS_JSON" ] && clean_exit
[ "$RESULTS_JSON" = "[]" ] && clean_exit

# ---- format a concise additionalContext block ------------------------------ #
# One line per hit: "- <title> [<namespace>] (<stem>.md) — <snippet>".
# Built entirely inside jq so a malformed array can't break the shell; if jq
# can't process it, fail open.
CTX="$(printf '%s' "$RESULTS_JSON" | "$JQ" -r '
  if (type=="array" and length>0) then
    "Auto-retrieved memories possibly relevant (read the file for full detail):\n"
    + ( map("- " + (.title // .stem) + " [" + (.namespace // "?") + "] ("
            + .stem + ".md) — " + ((.snippet // "") | gsub("\n";" ")))
        | join("\n") )
  else empty end
' 2>/dev/null || true)"

[ -z "$CTX" ] && clean_exit

# ---- emit additionalContext (ADD-only; never a decision) + exit 0 ---------- #
printf '%s' "$CTX" | "$JQ" -Rsc \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}' \
  2>/dev/null || true

exit 0
