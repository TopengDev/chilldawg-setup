#!/usr/bin/env bash
# setup-doctor.sh — READ-ONLY drift auditor for the chilldawg-setup dotfiles repo.
#
# Reports divergence between what the repo DECLARES (install.sh link targets,
# settings.json hooks, config/systemd units) and what the live machine actually
# has. Changes NOTHING. Safe to run anytime, any number of times (idempotent).
#
# Usage:
#   setup-doctor.sh            # full report, human-readable
#   setup-doctor.sh --quiet    # only print DRIFT lines + the final verdict
#   setup-doctor.sh --no-color # disable ANSI color
#
# Exit codes:
#   0  no drift          (everything the repo declares is live + correct)
#   1  drift detected    (at least one MISS/DRIFT — see report)
#   2  doctor self-error (couldn't locate repo / install.sh / settings.json)
#
# Checks performed:
#   1. install.sh `link <src> <dst>` — every target is a symlink that resolves
#      to the repo's source (the actual file on disk, via readlink -f).
#   2. settings.json hooks — every hook whose command is a FILE PATH exists on
#      disk + is executable (inline `echo {...}` hooks are skipped by design).
#   3. config/systemd/user/*.{timer,service} — timers enabled + active; oneshot
#      services enabled (their "active" is transient, so only flagged if the unit
#      is in a failed state).
#   4. ~/.claude/.mcp.json present.
#   5. settings.json `enabledPlugins` present + non-empty.
#   6. secrets.env present AND sourced into the running shell (sentinel var set).
#
# This is the verification backbone the rest of the setup-overhaul program leans
# on — keep it dependency-light (bash + python3 for JSON only) and side-effect-free.

set -uo pipefail   # NOT -e: a single failed check must not abort the whole audit.

# ── args ──────────────────────────────────────────────────────────────────────
QUIET=0
USE_COLOR=1
[ -t 1 ] || USE_COLOR=0   # auto-disable color when not a TTY (piped/redirected)
for a in "$@"; do
  case "$a" in
    --quiet|-q)    QUIET=1 ;;
    --no-color)    USE_COLOR=0 ;;
    -h|--help)     sed -n '2,38p' "$0"; exit 0 ;;
    *) echo "unknown flag: $a (try --help)" >&2; exit 2 ;;
  esac
done

if [ "$USE_COLOR" = "1" ]; then
  C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_B=$'\033[36m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
  C_G=''; C_R=''; C_Y=''; C_B=''; C_DIM=''; C_0=''
fi

# ── tallies ───────────────────────────────────────────────────────────────────
PASS=0; DRIFT=0; SKIP=0

pass() { PASS=$((PASS+1)); [ "$QUIET" = "1" ] || printf '  %sPASS%s  %s\n' "$C_G" "$C_0" "$1"; }
drift(){ DRIFT=$((DRIFT+1));               printf '  %sDRIFT%s %s\n' "$C_R" "$C_0" "$1"; }
skip() { SKIP=$((SKIP+1));  [ "$QUIET" = "1" ] || printf '  %sSKIP%s  %s\n' "$C_Y" "$C_0" "$1"; }
sect() { [ "$QUIET" = "1" ] || printf '\n%s== %s ==%s\n' "$C_B" "$1" "$C_0"; }

# ── locate the real repo root (this script may be invoked via the symlinked
#    ~/.claude/scripts/setup-doctor.sh; resolve through it to the physical repo) ─
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPTS_DIR="$(dirname "$SELF")"
REPO_DIR="$(readlink -f "$SCRIPTS_DIR/../..")"
INSTALL_SH="$REPO_DIR/install.sh"
SETTINGS="$HOME/.claude/settings.json"
SYSTEMD_DIR="$REPO_DIR/config/systemd/user"

if [ ! -f "$INSTALL_SH" ]; then
  echo "${C_R}FATAL${C_0}: could not find install.sh at $INSTALL_SH" >&2
  echo "  (resolved repo root: $REPO_DIR — is the script in claude/scripts/?)" >&2
  exit 2
fi

[ "$QUIET" = "1" ] || {
  printf '%ssetup-doctor%s — drift audit  %s%s%s\n' "$C_B" "$C_0" "$C_DIM" "$(date '+%Y-%m-%d %H:%M:%S %z')" "$C_0"
  printf '%srepo:%s %s\n' "$C_DIM" "$C_0" "$REPO_DIR"
}

# ── 1. install.sh link targets ────────────────────────────────────────────────
# Parse lines of the form:  link <src> <dst>   (possibly with a trailing # comment).
# Skip the function definition line `link() {` and any commented-out calls.
sect "symlinks (install.sh link targets)"
while IFS= read -r line; do
  # strip leading whitespace
  stripped="${line#"${line%%[![:space:]]*}"}"
  case "$stripped" in
    link\ *) : ;;        # a real `link <src> <dst>` invocation
    *) continue ;;
  esac
  # tokens: $1=link $2=src $3=dst  (ignore trailing inline comment)
  # shellcheck disable=SC2086
  set -- $stripped
  src="${2:-}"; dst="${3:-}"
  [ -z "$src" ] || [ -z "$dst" ] && continue
  # guard against the definition line `link() {` slipping through
  case "$src" in *'('*|*'{'*) continue ;; esac

  repo_src="$REPO_DIR/$src"
  home_dst="$HOME/$dst"

  if [ ! -e "$repo_src" ]; then
    drift "~/$dst -> repo source MISSING in repo: $src"
    continue
  fi
  if [ ! -L "$home_dst" ]; then
    if [ -e "$home_dst" ]; then
      drift "~/$dst exists but is NOT a symlink (expected -> $src)"
    else
      drift "~/$dst MISSING (expected symlink -> $src)"
    fi
    continue
  fi
  # is a symlink — does it resolve to the repo source?
  if [ "$(readlink -f "$home_dst")" = "$(readlink -f "$repo_src")" ]; then
    pass "~/$dst -> $src"
  else
    drift "~/$dst symlink resolves to $(readlink -f "$home_dst") (expected $repo_src)"
  fi
done < "$INSTALL_SH"

# ── 2. settings.json hooks (file-path hooks must exist + be executable) ───────
sect "hooks (settings.json — file-path hooks)"
if [ ! -f "$SETTINGS" ]; then
  drift "settings.json not found at $SETTINGS"
else
  # Emit one line per hook whose command's first token is a file path.
  # Format: <event>\t<resolved-abs-path>
  HOOK_LINES="$(python3 - "$SETTINGS" <<'PY' 2>/dev/null
import json, os, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    sys.exit(0)
for evt, arr in (d.get("hooks") or {}).items():
    for matcher in arr:
        for h in matcher.get("hooks", []):
            cmd = (h.get("command") or "").strip()
            if not cmd:
                continue
            first = cmd.split()[0]
            # only file-path hooks (skip inline `echo {...}` style hooks)
            if first.startswith("~"):
                first = os.path.expanduser(first)
            if first.startswith("/"):
                print(f"{evt}\t{first}")
PY
)"
  if [ -z "$HOOK_LINES" ]; then
    skip "no file-path hooks declared (only inline hooks, if any)"
  else
    while IFS=$'\t' read -r evt path; do
      [ -z "$path" ] && continue
      if [ ! -e "$path" ]; then
        drift "hook ($evt) MISSING on disk: $path"
      elif [ ! -x "$path" ]; then
        drift "hook ($evt) NOT executable: $path"
      else
        pass "hook ($evt): $path"
      fi
    done <<< "$HOOK_LINES"
  fi
fi

# ── 3. systemd --user units ───────────────────────────────────────────────────
sect "systemd --user units (config/systemd/user)"
if ! command -v systemctl >/dev/null 2>&1; then
  skip "systemctl not available — not a systemd machine?"
elif [ ! -d "$SYSTEMD_DIR" ]; then
  skip "no systemd unit dir in repo ($SYSTEMD_DIR)"
else
  # Probe the user bus once; if it's unreachable, skip rather than false-DRIFT.
  if ! systemctl --user is-system-running >/dev/null 2>&1 && \
     ! systemctl --user list-units >/dev/null 2>&1; then
    skip "no reachable --user systemd bus (run inside a logged-in session)"
  else
    for unit_path in "$SYSTEMD_DIR"/*.timer "$SYSTEMD_DIR"/*.service; do
      [ -e "$unit_path" ] || continue
      unit="$(basename "$unit_path")"
      enabled="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
      active="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
      case "$unit" in
        *.timer)
          # Timers must be BOTH enabled and active to actually fire.
          if [ "$enabled" = "enabled" ] && [ "$active" = "active" ]; then
            pass "$unit (enabled, active)"
          else
            drift "$unit is-enabled=$enabled is-active=$active (expected enabled+active)"
          fi
          ;;
        *.service)
          # Oneshot services run transiently (active only while the timer fires),
          # so "inactive" is NORMAL. Flag only if enablement is wrong or it failed.
          if [ "$active" = "failed" ]; then
            drift "$unit is in FAILED state (last run errored)"
          elif [ "$enabled" = "enabled" ] || [ "$enabled" = "static" ] || [ "$enabled" = "linked" ]; then
            pass "$unit (enabled=$enabled, active=$active — oneshot, transient OK)"
          elif [ "$enabled" = "disabled" ]; then
            # A service driven solely by its timer is often 'disabled' itself and
            # that's fine; note it but don't fail the audit on the service alone.
            skip "$unit is-enabled=disabled (timer-driven service; OK if its .timer passes)"
          else
            drift "$unit is-enabled=$enabled is-active=$active (unexpected)"
          fi
          ;;
      esac
    done
  fi
fi

# ── 4. ~/.claude/.mcp.json ────────────────────────────────────────────────────
sect "mcp config"
if [ -f "$HOME/.claude/.mcp.json" ]; then
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HOME/.claude/.mcp.json" 2>/dev/null; then
    pass "~/.claude/.mcp.json present + valid JSON"
  else
    drift "~/.claude/.mcp.json present but is NOT valid JSON"
  fi
else
  drift "~/.claude/.mcp.json MISSING"
fi

# ── 5. enabledPlugins in settings.json ────────────────────────────────────────
sect "enabled plugins"
if [ -f "$SETTINGS" ]; then
  N_PLUGINS="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); ep=d.get('enabledPlugins') or {}; print(sum(1 for v in ep.values() if v))" "$SETTINGS" 2>/dev/null || echo "ERR")"
  if [ "$N_PLUGINS" = "ERR" ]; then
    drift "could not read enabledPlugins from settings.json"
  elif [ "$N_PLUGINS" -gt 0 ] 2>/dev/null; then
    pass "settings.json enabledPlugins present ($N_PLUGINS enabled)"
  else
    drift "settings.json has NO enabled plugins (enabledPlugins empty/absent)"
  fi
else
  drift "settings.json missing — cannot check enabledPlugins"
fi

# ── 6. secrets.env present + sourced ──────────────────────────────────────────
sect "secrets"
if [ -f "$HOME/.claude/secrets.env" ]; then
  pass "~/.claude/secrets.env present"
else
  drift "~/.claude/secrets.env MISSING (copy from .env.example + chmod 600)"
fi
# "Sourced" = a sentinel var the secrets file is expected to export is populated
# in THIS shell. VPS_HOST is referenced throughout CLAUDE.md as a known secret.
if [ -n "${VPS_HOST:-}" ]; then
  pass "secrets.env appears SOURCED (VPS_HOST is set in the environment)"
else
  drift "secrets.env not sourced — VPS_HOST unset (ensure ~/.bashrc sources it; open a fresh shell)"
fi

# ── verdict ───────────────────────────────────────────────────────────────────
printf '\n%s──────────────────────────────────────────%s\n' "$C_DIM" "$C_0"
if [ "$DRIFT" -eq 0 ]; then
  printf '%sVERDICT: PASS%s — no drift. %d checks passed, %d skipped.\n' "$C_G" "$C_0" "$PASS" "$SKIP"
  exit 0
else
  printf '%sVERDICT: DRIFT%s — %d issue(s). %d passed, %d skipped.\n' "$C_R" "$C_0" "$DRIFT" "$PASS" "$SKIP"
  printf '%sRe-run install.sh (or fix the flagged items) then re-run setup-doctor.%s\n' "$C_DIM" "$C_0"
  exit 1
fi
