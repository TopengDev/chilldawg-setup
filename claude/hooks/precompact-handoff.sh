#!/usr/bin/env bash
# PreCompact hook — mechanical tripwire for /session-handoff.
# 1) appends an append-only journal breadcrumb that a compaction fired (survives everything)
# 2) emits a handoff-aware systemMessage: names the latest handoff + age, or instructs
#    post-compact reconstruction if none exists.
# FAIL-OPEN CONTRACT: this hook ALWAYS exits 0 and ALWAYS emits valid JSON, even if
# every probe inside it fails. A broken tripwire must never break compaction.
set -u
HANDOFFS="$HOME/claude/notes/handoffs"
JOURNAL="$HOME/.claude/memory/journal.md"

TS=$(date '+%Y-%m-%d %H:%M %Z' 2>/dev/null) || TS="time-unknown"

# trigger (manual|auto) from the hook's stdin JSON; fail-open to "unknown"
IN=$(cat 2>/dev/null) || IN=""
TRIG=$(printf '%s' "$IN" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("trigger","unknown"))' 2>/dev/null) || TRIG="unknown"
[ -n "$TRIG" ] || TRIG="unknown"

# resolve latest handoff via the pointer file (line 1 = abs path)
LATEST=""
if [ -f "$HANDOFFS/LATEST.md" ]; then
  LATEST=$(head -1 "$HANDOFFS/LATEST.md" 2>/dev/null | tr -d '[:space:]') || LATEST=""
fi

if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
  NOW=$(date +%s 2>/dev/null) || NOW=0
  MT=$(stat -c %Y "$LATEST" 2>/dev/null) || MT=0
  if [ "$NOW" -gt 0 ] && [ "$MT" -gt 0 ]; then AGE=$(( (NOW - MT) / 60 )); else AGE="?"; fi
  MSG="PreCompact(${TRIG}): handoff on file: $(basename "$LATEST") (${AGE}m old). If it predates this session's work, run /session-handoff to refresh AFTER the compact."
else
  MSG="PreCompact(${TRIG}): NO session handoff on file. Immediately after this compact, run /session-handoff in RECONSTRUCTION mode (probes + summary, tag [conv][post-compact])."
fi

# journal breadcrumb (append-only; never fail the hook over it)
{ printf -- '- [ops %s] PreCompact(%s) fired; latest handoff: %s\n' "$TS" "$TRIG" "${LATEST:-NONE}" >> "$JOURNAL"; } 2>/dev/null || true

# emit systemMessage JSON (python for proper escaping; hard fallback if python dies)
python3 - "$MSG" <<'PY' 2>/dev/null || printf '{"systemMessage":"PreCompact fired: run /session-handoff to preserve session state."}\n'
import json, sys
print(json.dumps({"systemMessage": sys.argv[1]}))
PY
exit 0
