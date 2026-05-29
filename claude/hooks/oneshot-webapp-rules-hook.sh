#!/usr/bin/env bash
# oneshot-webapp-rules-hook.sh — UserPromptSubmit hook.
#
# Wired in settings.json as a UserPromptSubmit hook. Fires on every prompt the
# user submits but ONLY acts when the prompt genuinely INVOKES the
# /oneshot-webapp skill — i.e. the token "/oneshot-webapp" appears in the
# submitted prompt. When it does, it INJECTS the skill's NON-NEGOTIABLE hard
# rules into the model's context via `additionalContext`, so the rules are
# forcibly in-context for that build regardless of whether the SKILL.md was
# fully read. This is rule-INJECTION, not a content-validator: it can't
# reliably detect "dark mode was used" mechanically, so instead it guarantees
# the rules are present every run (a reliable reinforcement beats a flaky
# blocker).
#
# SAFETY — FAIL OPEN on every uncertainty:
#   * Prompt doesn't invoke /oneshot-webapp           -> emit nothing, exit 0 (allow)
#   * stdin unparseable / jq missing / any error      -> emit nothing, exit 0 (allow)
#   This hook must NEVER block a prompt and must NEVER brick prompt submission
#   due to its own bugs. It only ever ADDS context; it never denies.
#
# NOTE: hooks load at session start. Editing this file or settings.json does NOT
# affect already-running sessions — restart Claude Code to pick up changes.

set -uo pipefail

# Read the UserPromptSubmit JSON from stdin; extract the submitted prompt.
# The harness field is `prompt`; some tooling normalizes to `user_prompt` —
# accept either, fail open to empty.
input="$(cat 2>/dev/null || true)"
prompt="$(printf '%s' "$input" | jq -r '.prompt // .user_prompt // ""' 2>/dev/null || true)"

# Cheap pre-filter: only act when /oneshot-webapp is actually invoked.
printf '%s' "$prompt" | grep -q '/oneshot-webapp' || exit 0

read -r -d '' CTX <<'RULES' || true
⛔ /oneshot-webapp NON-NEGOTIABLE RULES (auto-injected — these OVERRIDE anything conflicting):
1. PITCH-GRADE DESIGN IS PRIORITY #1. Never cut design polish to save time — cut SCOPE instead. Generic shadcn-default = failure.
2. ONLY SAFE PRESETS — Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism. HIGH-VARIANCE (Neo-Brutalist, Magazine Editorial, Dark Cinematic, art-deco, maximalist, VARIANCE≥7) is BANNED unless Toper explicitly overrides in this brief.
3. LIGHT MODE ONLY. NO dark mode, no next-themes, no theme switcher.
4. SHIP FAST — act, don't deliberate. Cap thinking; get a slice on screen, iterate the running app. No long architecture-planning thinking blocks.
5. SERVER-SIDE SECRETS ONLY + MANDATORY deterministic LLM fallback (key in container .env chmod 600, never NEXT_PUBLIC_/never in image; demo must survive API failure).
6. DEPLOY to https://<slug>.topengdev.com (create the per-subdomain CF A record — no *.topengdev.com wildcard; HTTPS via certbot behind nginx).
GATES: PRE-FLIGHT (safe preset chosen, no dark mode, scope tight, slug derived, committed design direction) and PRE-DEPLOY (clean build, no next-themes/dark:, output:"standalone", secrets server-side, A record, no other VPS services disrupted) must both pass.
Read ~/.claude/skills/oneshot-webapp/SKILL.md in full and use deploy.sh for the deploy sequence.
RULES

# Emit additionalContext (NEVER a permission decision — this hook only adds context).
jq -cn --arg c "$CTX" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'

exit 0
