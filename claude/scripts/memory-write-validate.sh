#!/usr/bin/env bash
# memory-write-validate.sh — PostToolUse(Edit|Write) hook for the memory store.
#
# Fires ONLY when the edited file lives under the memory dir (~/.claude/memory).
# For such writes it:
#   (a) validates frontmatter (name + description + type present & well-formed),
#   (b) scans the written content for LITERAL secrets/PII (reusing the gitleaks
#       prefixes: sk-ant- / ghp_ / sk- / AKIA / password=<literal> / phone #s),
#   (c) keeps MEMORY.md current by (debounced) regenerating the index when this
#       file is new/not-yet-indexed.
# Anything noteworthy is surfaced to Claude via additionalContext (non-blocking).
#
# HARD CONTRACT — FAIL-OPEN, ALWAYS:
#   * PostToolUse cannot block the write (the tool already ran) and we never try.
#   * This script NEVER emits decision:"block". It ALWAYS exits 0.
#   * Every step is guarded; any error/timeout -> emit nothing (or a soft note)
#     and exit 0. Losing a lint/warning is acceptable; disrupting a memory write
#     is not.
#   * Non-memory edits -> silent exit 0 (the hook is invisible outside memory).
#
# Wired in settings.json under hooks.PostToolUse matcher "Edit|Write".

# Deliberately NOT `set -e` — fail-open means we must survive any sub-failure.
set -u

# ---- absolute fail-safe: never let an uncaught error escape non-zero -------- #
trap 'exit 0' ERR

emit_clean_exit() { exit 0; }
# A second guard: even if something below `exit 1`s, normalize to 0 on the way
# out. (trap EXIT can't change the code, so we rely on explicit `exit 0`s and
# the ERR trap; every exit path below is an explicit `exit 0`.)

# ---- locate tools (fail-open if missing) ----------------------------------- #
JQ="$(command -v jq 2>/dev/null || true)"
PY="$(command -v python3 2>/dev/null || true)"

# Resolve the canonical memory dir. If we can't, we can't gate safely -> exit.
MEM_LINK="${HOME}/.claude/memory"
MEM_REAL="$(readlink -f "$MEM_LINK" 2>/dev/null || true)"
[ -z "$MEM_REAL" ] && emit_clean_exit

GEN_INDEX="${HOME}/.claude/scripts/gen-memory-index.py"
GITLEAKS_TOML="${HOME}/.config/git/hooks/gitleaks.toml"   # informational only
LOCK_DIR="${HOME}/.cache/memory-write-validate"
DEBOUNCE_SECS=20

# ---- read tool input (fail-open) ------------------------------------------- #
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && emit_clean_exit
[ -z "$JQ" ] && emit_clean_exit   # without jq we can't parse the path; bail open

FILE_PATH="$(printf '%s' "$INPUT" | "$JQ" -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[ -z "$FILE_PATH" ] && emit_clean_exit

# Canonicalize the edited path. Resolve symlinks so a path that goes through the
# ~/.claude/memory symlink still matches the real dir.
FILE_REAL="$(readlink -f "$FILE_PATH" 2>/dev/null || true)"
[ -z "$FILE_REAL" ] && FILE_REAL="$FILE_PATH"

# ---- GATE: only act on files under the memory dir -------------------------- #
case "$FILE_REAL/" in
  "$MEM_REAL"/*) : ;;          # inside memory dir — proceed
  *) emit_clean_exit ;;        # anything else — invisible, exit 0
esac

BASE="$(basename "$FILE_REAL")"

# Skip files that are not memory ENTRIES (index, journal, prev/tmp, non-md, and
# anything inside archive/).
case "$FILE_REAL" in
  "$MEM_REAL"/archive/*) emit_clean_exit ;;
esac
case "$BASE" in
  MEMORY.md|MEMORY.md.prev|MEMORY.md.tmp|journal.md) emit_clean_exit ;;
  *.md) : ;;
  *) emit_clean_exit ;;        # non-markdown write in memory dir — ignore
esac

# If the file no longer exists (e.g. a delete), there's nothing to validate, but
# we should still refresh the index so a now-dangling link gets pruned.
FILE_EXISTS=1
[ -f "$FILE_REAL" ] || FILE_EXISTS=0

WARN=""   # accumulates human-readable warning lines
add_warn() { WARN="${WARN}${WARN:+$'\n'}$1"; }

# --------------------------------------------------------------------------- #
# (a) frontmatter validation  (only if the file exists)
# --------------------------------------------------------------------------- #
if [ "$FILE_EXISTS" -eq 1 ] && [ -n "$PY" ]; then
  FM_REPORT="$("$PY" - "$FILE_REAL" <<'PYEOF' 2>/dev/null || true
import re, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    t = p.read_text(encoding="utf-8")
except Exception:
    sys.exit(0)  # unreadable -> say nothing (fail-open)
if not t.startswith("---"):
    print("NO_FRONTMATTER")
    sys.exit(0)
m = re.search(r"\n---\s*\n", t[3:])
if not m:
    print("UNCLOSED_FRONTMATTER")
    sys.exit(0)
fm = t[3:3+m.start()]
# collect keys both top-level and nested under metadata:
keys = set()
in_meta = False
for raw in fm.splitlines():
    if not raw.strip():
        continue
    if re.match(r"^metadata:\s*$", raw):
        in_meta = True; continue
    indented = raw.startswith("  ") or raw.startswith("\t")
    if in_meta and indented:
        mm = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:", raw)
        if mm: keys.add(mm.group(1))
        continue
    if in_meta and not indented:
        in_meta = False
    mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:", raw)
    if mm: keys.add(mm.group(1))
missing = [k for k in ("name", "description", "type") if k not in keys]
if missing:
    print("MISSING:" + ",".join(missing))
PYEOF
)"
  case "$FM_REPORT" in
    NO_FRONTMATTER)
      add_warn "frontmatter MISSING in ${BASE} — add a YAML block with at least: name, description, type. (Memory files need frontmatter so the auto-index can place them.)" ;;
    UNCLOSED_FRONTMATTER)
      add_warn "frontmatter in ${BASE} is not closed by a second '---' fence." ;;
    MISSING:*)
      add_warn "frontmatter in ${BASE} is missing required field(s): ${FM_REPORT#MISSING:} (need name + description + type)." ;;
  esac
fi

# --------------------------------------------------------------------------- #
# (b) literal secret / PII scan  (only if the file exists)
#   Reuse the gitleaks prefix intelligence (sk-ant-, ghp_, generic sk-, AKIA,
#   password=<literal>) PLUS Indonesian-style phone numbers, to catch the class
#   of leak that put Admin@12345 / live keys into files. This is a heuristic
#   tripwire (loud warning), NOT the authoritative pre-push gitleaks scan.
# --------------------------------------------------------------------------- #
if [ "$FILE_EXISTS" -eq 1 ]; then
  HITS=""
  add_hit() { HITS="${HITS}${HITS:+, }$1"; }

  # grep -E patterns; -q just tests presence (we don't echo the secret itself).
  grep -Eq 'sk-ant-[A-Za-z0-9]{2,}-[A-Za-z0-9_-]{8,}' "$FILE_REAL" 2>/dev/null && add_hit "Anthropic sk-ant- key"
  grep -Eq '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}' "$FILE_REAL" 2>/dev/null && add_hit "GitHub token (ghp_/gho_/…)"
  grep -Eq 'github_pat_[A-Za-z0-9_]{30,}' "$FILE_REAL" 2>/dev/null && add_hit "GitHub fine-grained PAT"
  grep -Eq '\bsk-[A-Za-z0-9]{20,}\b' "$FILE_REAL" 2>/dev/null && add_hit "generic sk- API key (OpenAI-style)"
  grep -Eq '\bAKIA[0-9A-Z]{16}\b' "$FILE_REAL" 2>/dev/null && add_hit "AWS access key id (AKIA…)"
  grep -Eq 'AIza[0-9A-Za-z_-]{35}' "$FILE_REAL" 2>/dev/null && add_hit "Google API key (AIza…)"
  grep -Eq 'xox[baprs]-[A-Za-z0-9-]{10,}' "$FILE_REAL" 2>/dev/null && add_hit "Slack token (xox…)"
  grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$FILE_REAL" 2>/dev/null && add_hit "PEM private key block"
  # password / passwd / pwd = <literal value> (not a placeholder like <...>, $VAR, ***), >=4 chars
  grep -Eiq '(password|passwd|pwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*[^[:space:]$<>*"'"'"'#][^[:space:]]{3,}' "$FILE_REAL" 2>/dev/null && add_hit "literal password/secret assignment"
  # Indonesian phone numbers: 62xxxxxxxxxx or 08xxxxxxxxxx (10+ digits). Exclude
  # known-safe JIDs is hard in bash, so this is a soft heads-up (PII), not loud.
  PHONE_HIT=""
  grep -Eq '\b(62|\+62)8[0-9]{8,12}\b|\b08[0-9]{8,11}\b' "$FILE_REAL" 2>/dev/null && PHONE_HIT=1

  if [ -n "$HITS" ]; then
    add_warn "POSSIBLE SECRET LEAK in ${BASE}: detected ${HITS}. Memory is version-controlled (private repo) — do NOT commit live credentials. If this is a real secret, redact it now (use \$ENV_VAR refs or 'see ~/.claude/secrets.env'), then rotate the key. This is the exact class of leak that exposed Admin@12345 / live keys before."
  fi
  if [ -n "$PHONE_HIT" ]; then
    add_warn "${BASE} contains what looks like a literal phone number (PII). If it's a real personal number, prefer a contact reference over the raw digits."
  fi
fi

# --------------------------------------------------------------------------- #
# (c) keep the index current — debounced regen, incremental-aware.
#   Only regenerate when needed:
#     * file deleted (prune dangling link), OR
#     * file not yet referenced in MEMORY.md (a new memory file).
#   Debounce with a lock-dir + mtime so rapid successive writes don't each spawn
#   a regen. Backgrounded + detached so it never adds latency to the write.
# --------------------------------------------------------------------------- #
needs_reindex() {
  [ -n "$PY" ] || return 1
  [ -f "$GEN_INDEX" ] || return 1
  local idx="$MEM_REAL/MEMORY.md"
  if [ "$FILE_EXISTS" -eq 0 ]; then
    # deleted: reindex only if the index still links to it (dangling)
    grep -q "(${BASE})" "$idx" 2>/dev/null && return 0
    return 1
  fi
  # exists: reindex if NOT already linked (new file)
  grep -q "(${BASE})" "$idx" 2>/dev/null && return 1
  return 0
}

debounced_reindex() {
  mkdir -p "$LOCK_DIR" 2>/dev/null || return 0
  local stamp="$LOCK_DIR/last-reindex"
  # debounce: if we regenerated within DEBOUNCE_SECS, skip (a later write or the
  # daily journal-audit will catch it; the safety-net guarantees eventual index)
  if [ -f "$stamp" ]; then
    local now last age
    now="$(date +%s 2>/dev/null || echo 0)"
    last="$(stat -c %Y "$stamp" 2>/dev/null || echo 0)"
    age=$(( now - last ))
    [ "$age" -lt "$DEBOUNCE_SECS" ] && return 0
  fi
  # single-flight lock so concurrent hook invocations don't race
  local lock="$LOCK_DIR/lock"
  if mkdir "$lock" 2>/dev/null; then
    touch "$stamp" 2>/dev/null || true
    # detach fully: own session, no controlling tty, output discarded. Best-effort.
    ( "$PY" "$GEN_INDEX" >/dev/null 2>&1; rmdir "$lock" 2>/dev/null ) &
    disown 2>/dev/null || true
  fi
  return 0
}

if needs_reindex; then
  debounced_reindex
  # Note (non-blocking) that the index is being refreshed — only if a new file.
  if [ "$FILE_EXISTS" -eq 1 ]; then
    add_warn "ℹ️ ${BASE} is new to the memory store — the MEMORY.md index is being regenerated to include it."
  fi
fi

# --------------------------------------------------------------------------- #
# emit (non-blocking additionalContext) + ALWAYS exit 0
# --------------------------------------------------------------------------- #
if [ -n "$WARN" ] && [ -n "$JQ" ]; then
  printf '%s' "$WARN" | "$JQ" -Rsc \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:.}}' 2>/dev/null \
    || true
fi

exit 0
