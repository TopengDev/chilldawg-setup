#!/usr/bin/env bash
# result-schema.sh — validate + read a worker's structured result.json.
#
# The RESULT CONTRACT (Wave-3 orchestration): workers return free-text that main
# had to parse + re-summarize. This adds a lightweight machine-readable companion
# to report.md so main can ingest a worker's outcome programmatically.
#
# Usage:
#   result-schema.sh <dir|file>            validate + pretty-print (default)
#   result-schema.sh --validate <dir|file> validate only (exit 0 ok / 1 invalid), quiet-ish
#   result-schema.sh --read     <dir|file> human-readable summary only (assumes valid)
#   result-schema.sh --field <f> <dir|file>  print one field (status|summary|...) raw
#   result-schema.sh --template            print a blank result.json skeleton to stdout
#
#   <dir>  resolves to <dir>/result.json ; <file> used as-is.
#
# Schema (validated):
#   {
#     "task_slug":        string   (required, non-empty)
#     "status":           enum     (required: "done" | "blocked" | "partial")
#     "summary":          string   (required, non-empty)
#     "deliverables":     [string] (required array; may be empty)
#     "evidence":         [string] (required array; may be empty)
#     "blockers":         [string] (required array; empty unless status=blocked)
#     "followups":        [string] (optional array)
#     "staged_for_human": [string] (optional array)
#   }
#
# Exit codes: 0 ok · 1 invalid/failed validation · 2 usage/infra error.

set -uo pipefail   # no -e: explicit error handling

PROG="result-schema.sh"

die_usage() { echo "$PROG: $*" >&2; echo "usage: $PROG [--validate|--read|--field <f>|--template] <dir|file>" >&2; exit 2; }

if ! command -v jq >/dev/null 2>&1; then
  echo "$PROG: jq not found — required to validate result.json" >&2
  exit 2
fi

MODE="full"
FIELD=""
case "${1:-}" in
  --validate) MODE="validate"; shift ;;
  --read)     MODE="read"; shift ;;
  --field)    MODE="field"; FIELD="${2:-}"; [[ -z "$FIELD" ]] && die_usage "--field needs a field name"; shift 2 ;;
  --template) MODE="template" ;;
  -h|--help)  die_usage "help" ;;
esac

# --template needs no path
if [[ "$MODE" == "template" ]]; then
  cat <<'JSON'
{
  "task_slug": "",
  "status": "done",
  "summary": "",
  "deliverables": [],
  "evidence": [],
  "blockers": [],
  "followups": [],
  "staged_for_human": []
}
JSON
  exit 0
fi

TARGET="${1:-}"
[[ -z "$TARGET" ]] && die_usage "missing <dir|file>"

if [[ -d "$TARGET" ]]; then
  FILE="${TARGET%/}/result.json"
else
  FILE="$TARGET"
fi

if [[ ! -f "$FILE" ]]; then
  echo "$PROG: result.json not found at: $FILE" >&2
  exit 1
fi

# --- JSON well-formed? -------------------------------------------------------
if ! jq -e . "$FILE" >/dev/null 2>&1; then
  echo "$PROG: INVALID — not well-formed JSON: $FILE" >&2
  exit 1
fi

# --field short-circuit (raw value, for scripting) ----------------------------
if [[ "$MODE" == "field" ]]; then
  # arrays joined by newline, scalars as-is
  jq -r --arg f "$FIELD" '
    .[$f] // empty
    | if type=="array" then .[] else . end
  ' "$FILE"
  exit 0
fi

# --- schema validation -------------------------------------------------------
# Build a list of human-readable problems via jq; empty list = valid.
PROBLEMS="$(jq -r '
  def reqstr($k):  if (has($k)|not) then "missing required field: \($k)"
                   elif (.[$k]|type) != "string" then "field \($k) must be a string"
                   elif (.[$k]|length)==0 then "field \($k) must be non-empty"
                   else empty end;
  def reqarr($k):  if (has($k)|not) then "missing required array field: \($k)"
                   elif (.[$k]|type) != "array" then "field \($k) must be an array"
                   else (.[$k][] | select(type!="string") | "field \($k) must contain only strings") end;
  def optarr($k):  if (has($k)) and (.[$k]|type) != "array" then "field \($k), if present, must be an array"
                   else (if has($k) then (.[$k][]? | select(type!="string") | "field \($k) must contain only strings") else empty end) end;

  [
    reqstr("task_slug"),
    reqstr("summary"),
    ( if (has("status")|not) then "missing required field: status"
      elif (.status|type)!="string" then "field status must be a string"
      elif ([.status]|inside(["done","blocked","partial"])|not)
           then "field status must be one of: done|blocked|partial (got \"\(.status)\")"
      else empty end ),
    reqarr("deliverables"),
    reqarr("evidence"),
    reqarr("blockers"),
    optarr("followups"),
    optarr("staged_for_human"),
    ( if (.status=="blocked") and ((.blockers|length? // 0)==0)
      then "status=blocked but blockers[] is empty — describe what blocked you"
      else empty end )
  ] | map(select(. != null)) | .[]
' "$FILE" 2>/dev/null)"

if [[ -n "$PROBLEMS" ]]; then
  echo "$PROG: INVALID result.json — $FILE" >&2
  while IFS= read -r p; do
    [[ -n "$p" ]] && echo "  - $p" >&2
  done <<< "$PROBLEMS"
  exit 1
fi

if [[ "$MODE" == "validate" ]]; then
  echo "$PROG: OK — result.json valid ($FILE)"
  exit 0
fi

# --- human-readable render (read / full) -------------------------------------
render() {
  local status; status="$(jq -r '.status' "$FILE")"
  local slug;   slug="$(jq -r '.task_slug' "$FILE")"
  local badge
  case "$status" in
    done)    badge="✅ DONE" ;;
    partial) badge="🟡 PARTIAL" ;;
    blocked) badge="⛔ BLOCKED" ;;
    *)       badge="$status" ;;
  esac
  echo "──────────────────────────────────────────────────────────────"
  echo " result: ${slug}   [${badge}]"
  echo "──────────────────────────────────────────────────────────────"
  echo " summary:"
  jq -r '.summary' "$FILE" | sed 's/^/   /'
  _list() {
    local key="$1" label="$2"
    local n; n="$(jq -r --arg k "$key" '(.[$k] // []) | length' "$FILE")"
    if [[ "$n" -gt 0 ]]; then
      echo " ${label} (${n}):"
      jq -r --arg k "$key" '.[$k][]' "$FILE" | sed 's/^/   • /'
    fi
  }
  _list deliverables    "deliverables"
  _list evidence        "evidence"
  _list blockers        "blockers"
  _list followups       "followups"
  _list staged_for_human "STAGED FOR HUMAN"
  echo "──────────────────────────────────────────────────────────────"
}
render
exit 0
