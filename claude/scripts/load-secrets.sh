#!/usr/bin/env bash
# load-secrets.sh — decrypt ~/.claude/secrets.env.enc (age) and export its vars
#                   into the CURRENT shell. The encrypted-at-rest replacement for
#                   `source ~/.claude/secrets.env`.
#
# ── How to use ────────────────────────────────────────────────────────────────
#   SOURCE it (do not execute) so the exports land in your shell:
#       source ~/.claude/scripts/load-secrets.sh
#   In ~/.bashrc this replaces the line:
#       source ~/.claude/secrets.env            # OLD (plaintext)
#       source ~/.claude/scripts/load-secrets.sh # NEW (decrypt age at rest)
#   (See CUTOVER.md — the cutover is STAGED, not yet applied. Toper flips it.)
#
# ── Design guarantees ─────────────────────────────────────────────────────────
#   * Decrypts to an in-memory shell variable, then sources via process
#     substitution. NO plaintext is ever written to disk (no temp secrets.env).
#     The decrypted blob is held in a local var only for the moment of sourcing,
#     then `unset`. (Secrets are necessarily plaintext in *process memory* after
#     decrypt — that is inherent to env vars; this script does not change it.)
#   * FAIL-OPEN / NON-FATAL: if the age binary, the key, or the .enc is missing,
#     it prints a LOUD warning to stderr and RETURNS without error so a broken
#     setup never locks Toper out of new login shells. It never `exit`s a sourced
#     shell. (When run standalone it exits 0 on warn so callers don't die either.)
#   * IDEMPOTENT: safe to source multiple times; re-exports the same vars.
#   * ZERO secret values in this file. Variable NAMES only ever appear via the
#     decrypted content, never hard-coded here.
#
# ── Env knobs ─────────────────────────────────────────────────────────────────
#   SECRETS_ENC_FILE   override the .enc path  (default ~/.claude/secrets.env.enc)
#   AGE_KEY_FILE       override the age identity (default ~/.config/age/keys.txt)
#   AGE_BIN            override the age binary path (default: autodetect)
#   LOAD_SECRETS_QUIET=1  suppress the success line (warnings still print)
#
# Companion: verify-secrets-parity.sh proves this path yields a byte-identical
# environment to sourcing the plaintext.

# NOTE: deliberately NOT `set -euo pipefail` — this file is meant to be SOURCED
# into an interactive shell (e.g. from .bashrc). Flipping global shell options
# in the caller's shell would be hostile. All logic is locally defensive instead.

# Wrap everything in a function so locals don't leak into the caller's shell and
# a `return` cleanly exits the sourced context (or the function, if executed).
__load_secrets() {
  local enc="${SECRETS_ENC_FILE:-$HOME/.claude/secrets.env.enc}"
  local keyf="${AGE_KEY_FILE:-$HOME/.config/age/keys.txt}"
  local quiet="${LOAD_SECRETS_QUIET:-0}"

  # ── Resolve the age binary ──────────────────────────────────────────────────
  # A fresh non-interactive shell may not have ~/.local/bin on PATH, so probe
  # explicit candidates in addition to PATH.
  local age_bin="${AGE_BIN:-}"
  if [ -z "$age_bin" ]; then
    local c
    for c in "$HOME/.local/bin/age" "$(command -v age 2>/dev/null)" /usr/local/bin/age /usr/bin/age; do
      if [ -n "$c" ] && [ -x "$c" ]; then age_bin="$c"; break; fi
    done
  fi

  # ── Pre-flight: every dependency must exist, else warn + bail NON-FATALLY ────
  if [ -z "$age_bin" ] || [ ! -x "$age_bin" ]; then
    printf '\033[1;33m[load-secrets] WARNING:\033[0m age binary not found (looked in ~/.local/bin, PATH). Secrets NOT loaded.\n' >&2
    printf '[load-secrets]   Install age to ~/.local/bin or set AGE_BIN. Falling through (shell still usable).\n' >&2
    return 0
  fi
  if [ ! -r "$keyf" ]; then
    printf '\033[1;33m[load-secrets] WARNING:\033[0m age key not readable at %s. Secrets NOT loaded.\n' "$keyf" >&2
    printf '[load-secrets]   Restore the key from your off-machine backup, or set AGE_KEY_FILE. Falling through.\n' >&2
    return 0
  fi
  if [ ! -r "$enc" ]; then
    printf '\033[1;33m[load-secrets] WARNING:\033[0m encrypted secrets not found at %s. Secrets NOT loaded.\n' "$enc" >&2
    printf '[load-secrets]   Re-encrypt with: age -r <recipient> -o %s ~/.claude/secrets.env  (see CUTOVER.md). Falling through.\n' "$enc" >&2
    return 0
  fi

  # ── Decrypt to an IN-MEMORY variable (never to disk) + capture the real rc ──
  local _dec _rc
  _dec="$("$age_bin" -d -i "$keyf" "$enc" 2>/dev/null)"
  _rc=$?
  if [ "$_rc" -ne 0 ] || [ -z "$_dec" ]; then
    printf '\033[1;33m[load-secrets] WARNING:\033[0m age decrypt failed (rc=%s) for %s. Secrets NOT loaded.\n' "$_rc" "$enc" >&2
    printf '[load-secrets]   Wrong key for this file, or the .enc is corrupt. Falling through (shell still usable).\n' >&2
    unset _dec
    return 0
  fi

  # ── Source the decrypted content via process substitution, exporting vars ───
  # set -a marks all subsequently-set vars for export; the decrypted blob is the
  # original `export VAR=value` text, so this populates the environment exactly
  # as sourcing the plaintext would. We snapshot/restore the caller's -a state so
  # we never leave allexport flipped on in their interactive shell.
  local _had_a=0
  case $- in *a*) _had_a=1 ;; esac
  set -a
  # shellcheck disable=SC1090
  source <(printf '%s' "$_dec")
  if [ "$_had_a" -eq 0 ]; then set +a; fi

  # ── Scrub the in-memory plaintext blob ──────────────────────────────────────
  unset _dec _rc

  if [ "$quiet" != "1" ]; then
    printf '[load-secrets] secrets loaded from %s (age-decrypted at rest).\n' "$enc" >&2
  fi
  return 0
}

__load_secrets
# Tidy up the helper so it doesn't linger in the caller's shell namespace.
unset -f __load_secrets 2>/dev/null || true
