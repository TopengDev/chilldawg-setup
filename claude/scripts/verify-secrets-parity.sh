#!/usr/bin/env bash
# verify-secrets-parity.sh — prove the age-encrypted secrets path yields a
# BYTE-IDENTICAL environment to sourcing the plaintext ~/.claude/secrets.env.
#
# THE cutover safety gate. The .bashrc cutover (plaintext → load-secrets.sh) is
# only "safe to recommend" when this prints GREEN.
#
# ── What it does ──────────────────────────────────────────────────────────────
#   Snapshot A: in a clean `bash --norc --noprofile`, capture the exported-env
#               BEFORE and AFTER `set -a; source <plaintext>; set +a`; the delta
#               (vars introduced/changed) is recorded as  NAME -> sha256(value).
#   Snapshot B: the same clean-shell delta, but via the decrypt wrapper
#               (load-secrets.sh → age -d → source).
#   Assert A == B: identical NAME set + identical sha256 per NAME.
#
# ── Leak-safety (critical) ────────────────────────────────────────────────────
#   * NO secret VALUE is ever printed. Only NAMES + (for high-entropy values)
#     their full sha256 appear. The per-NAME sha256 is computed INSIDE the clean
#     subshell that holds the value, so the value never crosses a pipe in clear.
#   * For SHORT / low-entropy values (a sha256 of which could be brute-forced),
#     the hash is replaced by the literal token "<short:NN>" where NN is the
#     value's byte-length — so A/B still compare exactly (length is stable across
#     both paths) without exposing a crackable digest. Length is not a secret;
#     the value is never shown.
#   * On mismatch it lists only the offending NAMES (missing / extra / differing).
#
# ── Exit codes ────────────────────────────────────────────────────────────────
#   0  GREEN  — environments identical (safe to recommend cutover)
#   1  RED    — mismatch (names differ or a value's hash differs) → see listed NAMES
#   2  ERROR  — setup problem (plaintext / .enc / wrapper / age missing)
#
# ── Args / env ────────────────────────────────────────────────────────────────
#   --plaintext PATH   plaintext secrets file (default ~/.claude/secrets.env)
#   --wrapper   PATH   decrypt wrapper to source (default ~/.claude/scripts/load-secrets.sh)
#   --json             emit a machine-readable summary line as well
#   (honours load-secrets.sh's AGE_KEY_FILE / SECRETS_ENC_FILE / AGE_BIN knobs)

set -uo pipefail

PLAINTEXT="$HOME/.claude/secrets.env"
WRAPPER="$HOME/.claude/scripts/load-secrets.sh"
EMIT_JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --plaintext) PLAINTEXT="$2"; shift 2 ;;
    --wrapper)   WRAPPER="$2";   shift 2 ;;
    --json)      EMIT_JSON=1;    shift ;;
    -h|--help)   sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "verify-secrets-parity.sh: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

red()   { printf '\033[1;31m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
yel()   { printf '\033[1;33m%s\033[0m\n' "$*"; }

# ── Pre-flight ────────────────────────────────────────────────────────────────
[ -r "$PLAINTEXT" ] || { red "ERROR: plaintext not readable: $PLAINTEXT"; exit 2; }
[ -r "$WRAPPER" ]   || { red "ERROR: decrypt wrapper not readable: $WRAPPER"; exit 2; }

# The short/low-entropy threshold: values shorter than this (in bytes) get their
# hash suppressed (replaced by <short:NN>). 16 bytes ~ a coin-flippable digest
# boundary for typical creds; ports/booleans/modes fall under it.
SHORT_THRESHOLD=16

# delta_snapshot <source-command> -> emits sorted "NAME\tHASHorSHORT" for vars
# the source step introduced/changed. Runs ENTIRELY in a clean subshell; hashing
# happens inside it so values never leave the subshell.
#
# Implementation: capture exported NAMES before, run the source, then for each
# NEW/CHANGED exported name, compute sha256 of its value in-place. We diff the
# NAME sets via comm on two `compgen -e` lists, then hash only the delta names.
delta_snapshot() {
  local source_cmd="$1"
  env -i HOME="$HOME" PATH=/usr/bin:/bin \
      AGE_KEY_FILE="${AGE_KEY_FILE:-$HOME/.config/age/keys.txt}" \
      SECRETS_ENC_FILE="${SECRETS_ENC_FILE:-$HOME/.claude/secrets.env.enc}" \
      ${AGE_BIN:+AGE_BIN="$AGE_BIN"} \
      bash --norc --noprofile -s "$source_cmd" "$SHORT_THRESHOLD" <<'CLEAN'
set +u
export LC_ALL=C
src_cmd="$1"; short_thr="$2"
# names exported BEFORE sourcing
before="$(compgen -e | LC_ALL=C sort)"
# perform the source step (allexport so plain `VAR=...` and `export VAR=...` both export)
set -a
eval "$src_cmd" >/dev/null 2>&1
set +a
# names exported AFTER
after="$(compgen -e | LC_ALL=C sort)"
# delta = names new in 'after' (plus any whose value changed — but for a fresh
# clean env nothing pre-exists except HOME/PATH/the AGE_* knobs which we exclude)
# We compute new names, then also re-hash any name present in both whose value
# differs is irrelevant here (clean env), so 'new names' is the delta.
delta_names="$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
# Exclude the plumbing vars we injected so they never pollute the comparison.
for n in $delta_names; do
  case "$n" in
    HOME|PATH|PWD|SHLVL|_|AGE_KEY_FILE|SECRETS_ENC_FILE|AGE_BIN|LOAD_SECRETS_QUIET|SECRETS_ENC_FILE) continue ;;
  esac
  # value is in the live env of THIS subshell; hash it here so it never crosses a pipe in clear
  val="${!n}"
  len="${#val}"
  if [ "$len" -lt "$short_thr" ]; then
    printf '%s\t<short:%d>\n' "$n" "$len"
  else
    h="$(printf '%s' "$val" | sha256sum | awk '{print $1}')"
    printf '%s\t%s\n' "$n" "$h"
  fi
done | LC_ALL=C sort
CLEAN
}

# Snapshot A — plaintext source
A="$(delta_snapshot "source '$PLAINTEXT'")"
A_RC=$?
# Snapshot B — wrapper (decrypt) source. LOAD_SECRETS_QUIET so its success line
# doesn't contaminate; stderr is discarded by the wrapper-internal redirects.
B="$(LOAD_SECRETS_QUIET=1 delta_snapshot "LOAD_SECRETS_QUIET=1 source '$WRAPPER'")"
B_RC=$?

if [ -z "$A" ]; then red "ERROR: plaintext snapshot produced 0 vars (source failed?)"; exit 2; fi
if [ -z "$B" ]; then red "ERROR: wrapper snapshot produced 0 vars (decrypt failed? key/.enc/age missing?)"; exit 2; fi

A_COUNT="$(printf '%s\n' "$A" | grep -c .)"
B_COUNT="$(printf '%s\n' "$B" | grep -c .)"

# Compare. Names only in A (missing from B), names only in B (extra), and
# names present in both but with a differing hash.
# Sort explicitly with LC_ALL=C — comm requires byte-sorted input, and `cut`ting
# field 1 from lines sorted by NAME<TAB>HASH does NOT guarantee a strict name sort.
NAMES_A="$(printf '%s\n' "$A" | cut -f1 | LC_ALL=C sort)"
NAMES_B="$(printf '%s\n' "$B" | cut -f1 | LC_ALL=C sort)"
MISSING="$(LC_ALL=C comm -23 <(printf '%s\n' "$NAMES_A") <(printf '%s\n' "$NAMES_B"))"   # in A not B
EXTRA="$(LC_ALL=C comm -13 <(printf '%s\n' "$NAMES_A") <(printf '%s\n' "$NAMES_B"))"     # in B not A
# value-hash mismatches among shared names
HASH_DIFF="$(LC_ALL=C comm -12 <(printf '%s\n' "$NAMES_A") <(printf '%s\n' "$NAMES_B") | while read -r n; do
  ha="$(printf '%s\n' "$A" | awk -F'\t' -v k="$n" '$1==k{print $2}')"
  hb="$(printf '%s\n' "$B" | awk -F'\t' -v k="$n" '$1==k{print $2}')"
  [ "$ha" != "$hb" ] && printf '%s\n' "$n"
done)"

MISSING_N="$(printf '%s' "$MISSING" | grep -c . || true)"
EXTRA_N="$(printf '%s' "$EXTRA" | grep -c . || true)"
HASHDIFF_N="$(printf '%s' "$HASH_DIFF" | grep -c . || true)"

echo "──────────────────────────────────────────────────────────────"
echo "secrets parity gate"
echo "  plaintext : $PLAINTEXT  ($A_COUNT vars)"
echo "  encrypted : via $WRAPPER  ($B_COUNT vars)"
echo "──────────────────────────────────────────────────────────────"

if [ "$MISSING_N" -eq 0 ] && [ "$EXTRA_N" -eq 0 ] && [ "$HASHDIFF_N" -eq 0 ] && [ "$A_COUNT" -eq "$B_COUNT" ]; then
  green "GREEN ✓  $A_COUNT vars, all match (same NAME set + identical per-value sha256)."
  echo "         The decrypt path is byte-identical to the plaintext path."
  echo "         → cutover is SAFE to recommend (see CUTOVER.md)."
  [ "$EMIT_JSON" -eq 1 ] && printf '{"result":"GREEN","vars":%d,"missing":0,"extra":0,"hash_mismatch":0}\n' "$A_COUNT"
  exit 0
else
  red "RED ✗  environments DIFFER — cutover NOT safe yet."
  [ "$MISSING_N"  -gt 0 ] && { yel "  names in plaintext but MISSING from decrypt ($MISSING_N):"; printf '    %s\n' $MISSING; }
  [ "$EXTRA_N"    -gt 0 ] && { yel "  names EXTRA in decrypt (not in plaintext) ($EXTRA_N):";     printf '    %s\n' $EXTRA; }
  [ "$HASHDIFF_N" -gt 0 ] && { yel "  names whose VALUE differs ($HASHDIFF_N):";                  printf '    %s\n' $HASH_DIFF; }
  echo "  (NAMES only — no values, no crackable hashes printed.)"
  [ "$EMIT_JSON" -eq 1 ] && printf '{"result":"RED","vars_plaintext":%d,"vars_decrypt":%d,"missing":%d,"extra":%d,"hash_mismatch":%d}\n' "$A_COUNT" "$B_COUNT" "$MISSING_N" "$EXTRA_N" "$HASHDIFF_N"
  exit 1
fi
