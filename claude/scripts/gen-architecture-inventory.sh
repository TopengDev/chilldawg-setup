#!/usr/bin/env bash
# gen-architecture-inventory.sh — emit the disk-verified inventory block that the
# enumerable sections of docs/ARCHITECTURE.md are built from.
#
# WHY: ARCHITECTURE.md is the setup's source-of-truth, but the *enumerable* parts
# (systemd timers, scripts, hooks, skills) drift as the system grows. Rather than
# hand-maintain those lists (and let them rot — the old doc said "36 skills" when
# there were 40), this script regenerates them straight from disk. Run it, paste
# the output into ARCHITECTURE.md's "AUTO-GENERATED INVENTORY" block, commit.
#
# It is the COUNTERPART to setup-doctor.sh:
#   * gen-architecture-inventory.sh  = what the system IS (enumerated from disk)
#   * setup-doctor.sh                = verifies what the repo DECLARES is actually live
#   * settings-drift.sh              = verifies the one non-symlinked config matches
#
# READ-ONLY. Emits Markdown to stdout. Dependency-light (bash + coreutils;
# systemctl optional — degrades gracefully on a non-systemd box / no user bus).
#
# Usage:
#   gen-architecture-inventory.sh            # markdown inventory to stdout
#   gen-architecture-inventory.sh > /tmp/inv.md   # capture to paste into the doc
#
# Exit: 0 always (a missing data source prints a "(unavailable)" note, never fails).

set -uo pipefail

# Resolve the repo root from this script's real location (chases the
# ~/.claude/scripts symlink back into the repo).
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPTS_DIR="$(cd "$(dirname "$SELF")" && pwd)"
CLAUDE_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"           # repo/claude
REPO_DIR="$(cd "$CLAUDE_DIR/.." && pwd)"              # repo root
SKILLS_DIR="$CLAUDE_DIR/skills"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
SYSTEMD_DIR="$REPO_DIR/config/systemd/user"

# tolerant one-line description extractor for a script. Prefers the
# "<name>.sh — <desc>" header convention; otherwise falls back to the first
# real comment/docstring line after the shebang. Works for .sh (# ) and .py (""").
desc_of() { # desc_of <file>
  local f="$1" line
  # 1) the "<name>.(sh|py) — <desc>" header (em-dash or double-hyphen), strip the name
  line="$(sed -n '1,8p' "$f" \
    | grep -m1 -E '\.(sh|py)[[:space:]]*[—-]' \
    | sed -E 's/^[#"[:space:]]*//; s/[[:space:]]+$//; s/^[a-zA-Z0-9_.-]+\.(sh|py)[[:space:]]*[—-]+[[:space:]]*//')"
  if [ -z "$line" ]; then
    # 2) fallback: first non-empty comment/docstring line after the shebang,
    #    skipping pure punctuation/box-drawing lines.
    line="$(sed -n '2,8p' "$f" \
      | sed -E 's/^[#"[:space:]]*//; s/"""$//; s/[[:space:]]+$//' \
      | grep -m1 -E '[A-Za-z]')"
  fi
  printf '%s' "${line:-(no description header)}"
}

echo "<!-- ───────────────────────────────────────────────────────────────────"
echo "     AUTO-GENERATED INVENTORY — do not hand-edit between the markers."
echo "     Regenerate with:  claude/scripts/gen-architecture-inventory.sh"
echo "     Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "     ─────────────────────────────────────────────────────────────────── -->"
echo

# ── systemd --user timers (LIVE, if a user bus is reachable) ───────────────────
echo "### systemd --user timers (live)"
echo
if command -v systemctl >/dev/null 2>&1 && systemctl --user list-timers >/dev/null 2>&1; then
  n_timers="$(systemctl --user list-timers --all --no-legend 2>/dev/null | grep -c '\.timer' || true)"
  echo "Live timer count: **${n_timers}**. Cadence + activated service:"
  echo
  echo '```'
  systemctl --user list-timers --all --no-pager 2>/dev/null \
    | awk 'NR==1 || /\.timer/'
  echo '```'
else
  echo "_(systemctl --user unavailable here — cannot enumerate live timers. On the"
  echo "host run: \`systemctl --user list-timers --all\`.)_"
fi
echo
echo "Unit files tracked in the repo (\`config/systemd/user/\`):"
echo
if [ -d "$SYSTEMD_DIR" ]; then
  echo '```'
  ( cd "$SYSTEMD_DIR" && ls -1 *.timer *.service 2>/dev/null )
  echo '```'
else
  echo "_(no config/systemd/user dir in repo)_"
fi
echo

# ── scripts ───────────────────────────────────────────────────────────────────
echo "### scripts (\`claude/scripts/\` ≈ \`~/.claude/scripts/\`)"
echo
n_scripts="$(find "$SCRIPTS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | wc -l | tr -d ' ')"
echo "Executable scripts: **${n_scripts}** (.sh + .py)."
echo
echo "| Script | Purpose |"
echo "|--------|---------|"
while IFS= read -r f; do
  b="$(basename "$f")"
  printf '| `%s` | %s |\n' "$b" "$(desc_of "$f")"
done < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | sort)
echo
if [ -d "$SCRIPTS_DIR/workflows" ]; then
  echo "Workflow playbooks (\`claude/scripts/workflows/\`):"
  echo
  echo '```'
  ( cd "$SCRIPTS_DIR/workflows" && ls -1 *.md *.sh 2>/dev/null )
  echo '```'
  echo
fi

# ── hooks (from settings.json) ────────────────────────────────────────────────
echo "### hooks (registered in \`settings.json\`)"
echo
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  echo "| Event | Matcher | Command |"
  echo "|-------|---------|---------|"
  jq -r '
    (.hooks // {}) | to_entries[] as $e
    | $e.value[]? as $g
    | ($g.matcher // "*") as $m
    | ($g.hooks // [])[]? | select(.command != null)
    | "| \($e.key) | `\($m)` | `\(.command | if (.|length) > 70 then (.[0:67] + "…") else . end)` |"
  ' "$SETTINGS"
else
  echo "_(jq or settings.json unavailable — run \`jq '.hooks' $SETTINGS\`.)_"
fi
echo
echo "Hook SCRIPTS on disk (\`claude/hooks/\`):"
echo
if [ -d "$HOOKS_DIR" ]; then
  echo '```'
  ( cd "$HOOKS_DIR" && ls -1 *.sh 2>/dev/null )
  echo '```'
fi
echo

# ── skills ────────────────────────────────────────────────────────────────────
echo "### skills (\`claude/skills/\`)"
echo
if [ -d "$SKILLS_DIR" ]; then
  n_skills="$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  echo "Skill count: **${n_skills}**. Each is a directory with a \`SKILL.md\`."
  echo
  echo '```'
  ( cd "$SKILLS_DIR" && ls -1d */ 2>/dev/null | sed 's:/$::' | column -c 80 2>/dev/null || ( cd "$SKILLS_DIR" && ls -1d */ | sed 's:/$::' ) )
  echo '```'
else
  echo "_(no skills dir)_"
fi
echo

echo "<!-- ─────────────────────── END AUTO-GENERATED INVENTORY ──────────────── -->"
