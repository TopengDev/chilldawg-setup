#!/usr/bin/env bash
# settings-drift.sh — drift solver for ~/.claude/settings.json vs the repo copy.
#
# WHY THIS EXISTS
#   `~/.claude/settings.json` is the ONE Claude-Code config file that is NOT a
#   symlink into chilldawg-setup — install.sh deliberately *copies* it (Claude
#   Code rewrites it live: model, plugin-auth, channel state), so a symlink would
#   push churn back into the repo and a stale committed copy would clobber live
#   edits on the next install. The cost of that decision: the live file and the
#   repo copy (claude/settings.json) can silently DIVERGE. The highest-value
#   divergence is a HOOK registered live but absent from the repo (or vice-versa)
#   — that's the classic "works on my machine, broken after a fresh install" bug,
#   because hooks are what gate commits/triage/memory-writes.
#
#   Compounding subtlety: hook/settings edits only take effect on a Claude Code
#   RESTART. So there is also a "changed on disk but not yet active in the running
#   session" state. A shell script cannot introspect the live session's loaded
#   config, so this tool is honest about that and just emits the standing reminder.
#
# WHAT IT DOES (default = READ-ONLY, modifies nothing)
#   * Canonical diff: parses both files and compares with stable key ordering
#     (jq -S, python json fallback) so a mere key REORDER never shows as drift.
#   * Key-level report: added / removed / changed top-level keys.
#   * Hooks-aware: extracts every hook COMMAND (across PreToolUse / PostToolUse /
#     UserPromptSubmit / PreCompact / Stop / SubagentStop / SessionStart / …) and
#     set-diffs live vs repo — a hook present in one but not the other is called
#     out explicitly as the high-value signal.
#   * Pending-restart note: always prints the restart-to-activate caveat; if the
#     live file's mtime is newer than the current Claude session's start (best
#     effort), it flags "edited since session start — restart to activate".
#
# EXPLICIT SYNC (never automatic — you must pick a direction)
#   --sync-to-repo   copy LIVE  -> REPO  (the common case after editing live)
#   --sync-to-live   copy REPO  -> LIVE
#   Both: refuse if there's no drift, back up the TARGET first (<target>.bak-<ts>),
#   print the diff + exactly what will happen, then write. No flag = report only.
#
# EXIT CODES
#   0  in sync (canonically identical)            — or a sync completed cleanly
#   1  drift detected (report mode)               — CI-able / dashboard-able
#   2  self-error: a file missing / unparseable   — changes nothing, loud
#
# Dependency-light by design: bash + jq (preferred) or python3 (fallback).

set -uo pipefail   # NOT -e: a single sub-step failing must not abort the report.

LIVE="$HOME/.claude/settings.json"
# Resolve the repo copy relative to this script (works via the ~/.claude/scripts
# symlink too, because readlink -f chases it back into the repo).
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_SETTINGS="$(cd "$(dirname "$SELF")/../" && pwd)/settings.json"

# Test/CI overrides: point the comparison at fixture files instead of the live +
# repo settings.json. ONLY for the self-test harness and CI — production callers
# leave these unset and operate on the real files. (Makes sync-on-temps testable
# without ever risking the real files.)
[ -n "${SETTINGS_DRIFT_LIVE:-}" ] && LIVE="$SETTINGS_DRIFT_LIVE"
[ -n "${SETTINGS_DRIFT_REPO:-}" ] && REPO_SETTINGS="$SETTINGS_DRIFT_REPO"

# ── args ──────────────────────────────────────────────────────────────────────
MODE="report"          # report | sync-to-repo | sync-to-live
USE_COLOR=1
[ -t 1 ] || USE_COLOR=0
for a in "$@"; do
  case "$a" in
    --sync-to-repo) MODE="sync-to-repo" ;;
    --sync-to-live) MODE="sync-to-live" ;;
    --no-color)     USE_COLOR=0 ;;
    -h|--help)      sed -n '2,60p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a (try --help)" >&2; exit 2 ;;
  esac
done

if [ "$USE_COLOR" = "1" ]; then
  C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_B=$'\033[36m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
  C_G=''; C_R=''; C_Y=''; C_B=''; C_DIM=''; C_0=''
fi
say()  { printf '%s\n' "$*"; }
hdr()  { printf '\n%s== %s ==%s\n' "$C_B" "$1" "$C_0"; }
good() { printf '  %sOK%s    %s\n' "$C_G" "$C_0" "$*"; }
bad()  { printf '  %sDRIFT%s %s\n' "$C_R" "$C_0" "$*"; }
note() { printf '  %s· %s%s\n'    "$C_DIM" "$*" "$C_0"; }
die2() { printf '%sERROR%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 2; }

# ── canonicalizer: emit stable-sorted JSON, or fail loudly ────────────────────
# Prefer jq -S (sorts object keys recursively); fall back to python3.
HAVE_JQ=0; command -v jq >/dev/null 2>&1 && HAVE_JQ=1
HAVE_PY=0; command -v python3 >/dev/null 2>&1 && HAVE_PY=1

canon() { # canon <file>  -> stdout canonical JSON; non-zero on parse failure
  local f="$1"
  if [ "$HAVE_JQ" = "1" ]; then
    jq -S . "$f" 2>/dev/null && return 0
  fi
  if [ "$HAVE_PY" = "1" ]; then
    python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])),indent=2,sort_keys=True))' "$f" 2>/dev/null && return 0
  fi
  return 1
}

# ── preflight: both files must exist + parse ──────────────────────────────────
[ "$HAVE_JQ" = "1" ] || [ "$HAVE_PY" = "1" ] || die2 "need jq or python3 to parse JSON (neither found on PATH)."
[ -f "$LIVE" ]          || die2 "live settings missing: $LIVE"
[ -f "$REPO_SETTINGS" ] || die2 "repo settings missing: $REPO_SETTINGS"

LIVE_CANON="$(canon "$LIVE")"       || die2 "live settings is not valid JSON: $LIVE"
REPO_CANON="$(canon "$REPO_SETTINGS")" || die2 "repo settings is not valid JSON: $REPO_SETTINGS"

# ── hook-command extractor ────────────────────────────────────────────────────
# Walk .hooks.<EVENT>[].hooks[].command for every event, emit one line per command
# as "<EVENT>\t<command>". Order-independent (we sort before diffing). jq path
# preferred; python fallback mirrors it exactly.
extract_hooks() { # extract_hooks <file>
  local f="$1"
  if [ "$HAVE_JQ" = "1" ]; then
    jq -r '
      (.hooks // {}) | to_entries[] as $e
      | $e.value[]? | (.hooks // [])[]? | select(.command != null)
      | "\($e.key)\t\(.command)"
    ' "$f" 2>/dev/null | sort
    return
  fi
  python3 - "$f" <<'PY' 2>/dev/null | sort
import json,sys
d=json.load(open(sys.argv[1]))
for ev,groups in (d.get("hooks") or {}).items():
    for g in (groups or []):
        for h in (g.get("hooks") or []):
            c=h.get("command")
            if c is not None:
                print(f"{ev}\t{c}")
PY
}

# ── top-level key differ ──────────────────────────────────────────────────────
top_keys() { # top_keys <file>
  if [ "$HAVE_JQ" = "1" ]; then jq -r 'keys[]' "$1" 2>/dev/null | sort
  else python3 -c 'import json,sys;[print(k) for k in sorted(json.load(open(sys.argv[1])).keys())]' "$1" 2>/dev/null; fi
}

# value of one top-level key, canonicalized (for "changed" detection)
key_val() { # key_val <file> <key>
  if [ "$HAVE_JQ" = "1" ]; then jq -S --arg k "$2" '.[$k]' "$1" 2>/dev/null
  else python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1])).get(sys.argv[2]),indent=2,sort_keys=True))' "$1" "$2" 2>/dev/null; fi
}

# ── compute drift ─────────────────────────────────────────────────────────────
DRIFT=0

# (a) whole-file canonical equality — the authoritative verdict
if [ "$LIVE_CANON" = "$REPO_CANON" ]; then
  WHOLE_IN_SYNC=1
else
  WHOLE_IN_SYNC=0
  DRIFT=1
fi

print_report() {
  hdr "settings.json drift"
  note "live: $LIVE"
  note "repo: $REPO_SETTINGS"

  # mtimes (informational + drives the pending-restart hint)
  local lm rm
  lm="$(stat -c '%Y' "$LIVE" 2>/dev/null || echo 0)"
  rm="$(stat -c '%Y' "$REPO_SETTINGS" 2>/dev/null || echo 0)"
  note "live mtime: $(date -d "@$lm" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')   repo mtime: $(date -d "@$rm" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')"

  if [ "$WHOLE_IN_SYNC" = "1" ]; then
    good "canonically IN SYNC (key order ignored) — 0 drift"
  else
    bad "canonical content DIFFERS"

    # --- top-level key delta ---
    local lk rk
    lk="$(top_keys "$LIVE")"; rk="$(top_keys "$REPO_SETTINGS")"
    local only_live only_repo common
    only_live="$(comm -23 <(printf '%s\n' "$lk") <(printf '%s\n' "$rk"))"
    only_repo="$(comm -13 <(printf '%s\n' "$lk") <(printf '%s\n' "$rk"))"
    common="$(comm -12 <(printf '%s\n' "$lk") <(printf '%s\n' "$rk"))"

    [ -n "$only_live" ] && while IFS= read -r k; do [ -n "$k" ] && bad "key only in LIVE  (missing from repo): .$k"; done <<<"$only_live"
    [ -n "$only_repo" ] && while IFS= read -r k; do [ -n "$k" ] && bad "key only in REPO  (missing from live): .$k"; done <<<"$only_repo"

    # --- changed common keys ---
    if [ -n "$common" ]; then
      while IFS= read -r k; do
        [ -z "$k" ] && continue
        if [ "$(key_val "$LIVE" "$k")" != "$(key_val "$REPO_SETTINGS" "$k")" ]; then
          bad "key CHANGED (live != repo): .$k"
        fi
      done <<<"$common"
    fi
  fi

  # --- hooks-array analysis (ALWAYS run — the high-value signal) ---
  hdr "hooks (the high-value signal)"
  local lh rh
  lh="$(extract_hooks "$LIVE")"
  rh="$(extract_hooks "$REPO_SETTINGS")"
  local hook_only_live hook_only_repo
  hook_only_live="$(comm -23 <(printf '%s\n' "$lh") <(printf '%s\n' "$rh"))"
  hook_only_repo="$(comm -13 <(printf '%s\n' "$lh") <(printf '%s\n' "$rh"))"

  if [ -z "$hook_only_live" ] && [ -z "$hook_only_repo" ]; then
    local n; n="$(printf '%s\n' "$lh" | grep -c . || true)"
    good "hook set identical live vs repo ($n hook command(s))"
  else
    if [ -n "$hook_only_live" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        bad "hook LIVE-only (would NOT survive a fresh install): ${line//$'\t'/ → }"
      done <<<"$hook_only_live"
    fi
    if [ -n "$hook_only_repo" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        bad "hook REPO-only (declared but NOT active live): ${line//$'\t'/ → }"
      done <<<"$hook_only_repo"
    fi
    DRIFT=1
  fi

  # --- pending-restart caveat (always) ---
  hdr "activation"
  note "Hook/settings edits load only at Claude Code STARTUP — a script cannot"
  note "introspect the running session's loaded config. After ANY settings.json"
  note "change (here or via /update-config), restart Claude Code to activate it."
  # best-effort "edited since this session started" hint
  if [ -n "${CLAUDE_SESSION_START:-}" ] && [ "$lm" -gt "${CLAUDE_SESSION_START}" ] 2>/dev/null; then
    bad "live settings.json mtime is NEWER than this session's start — restart to activate the on-disk changes."
  fi
}

# ── sync (explicit direction only) ────────────────────────────────────────────
do_sync() { # do_sync <src> <dst> <human-direction>
  local src="$1" dst="$2" dir="$3"
  if [ "$WHOLE_IN_SYNC" = "1" ]; then
    good "already canonically in sync — nothing to $dir. (No file written.)"
    return 0
  fi
  hdr "SYNC: $dir"
  note "source: $src"
  note "target: $dst  (will be backed up first)"
  say ""
  say "Unified diff (target <<< source), key-canonicalized:"
  # show what the target will become, canonically (so reorder noise is gone)
  if command -v diff >/dev/null 2>&1; then
    diff -u <(canon "$dst") <(canon "$src") | sed 's/^/    /' || true
  fi
  say ""
  local ts backup
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="${dst}.bak-${ts}"
  if ! cp -p "$dst" "$backup"; then
    die2 "could not back up target to $backup — aborting, target untouched."
  fi
  good "backed up target -> $backup"
  # Write the SOURCE VERBATIM (preserve its exact formatting/comments-as-written;
  # settings.json is plain JSON so verbatim copy is correct + lossless).
  if cp -p "$src" "$dst"; then
    good "wrote $src -> $dst"
    note "Restart Claude Code to activate (hooks/settings load at startup)."
    say ""
    good "$dir complete."
    return 0
  else
    # restore from backup on failure
    cp -p "$backup" "$dst" 2>/dev/null
    die2 "write failed — restored target from backup. No change made."
  fi
}

# ── dispatch ──────────────────────────────────────────────────────────────────
case "$MODE" in
  report)
    print_report
    printf '\n──────────────────────────────────────────\n'
    if [ "$DRIFT" = "0" ]; then
      printf '%sVERDICT%s settings.json: IN SYNC (live == repo, canonical).\n' "$C_G" "$C_0"
      exit 0
    else
      printf '%sVERDICT%s settings.json: DRIFT — reconcile with --sync-to-repo (live→repo) or --sync-to-live (repo→live).\n' "$C_R" "$C_0"
      exit 1
    fi
    ;;
  sync-to-repo) do_sync "$LIVE" "$REPO_SETTINGS" "sync-to-repo (live → repo)"; exit $? ;;
  sync-to-live) do_sync "$REPO_SETTINGS" "$LIVE" "sync-to-live (repo → live)"; exit $? ;;
esac
