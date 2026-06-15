#!/usr/bin/env bash
# worker-semaphore.sh — shared concurrency-governor helpers for the worker pipeline.
#
# The box is 4 vCPU / ~15GB. Nothing previously stopped over-spawning workers and
# thrashing. This provides an accurate "how many pipeline-spawned workers are live"
# count + a max-cap check, used by:
#   - spawn-worker.sh   (gate: refuse/queue a spawn at/over the cap)
#   - fleetview.sh      (read the live-worker set for the dashboard)
#
# WHY A REGISTRY (not naive window counting):
#   Window names/indices are unreliable as a worker signal — main is "claude" at an
#   arbitrary index, there can be stray `bash`/manual windows, etc. So spawn-worker
#   APPENDS each window it creates to a registry; the live count is
#   (registry entries) ∩ (currently-live tmux windows). That precisely counts
#   workers THIS PIPELINE spawned, ignores main + manual windows, and self-prunes
#   dead workers (a killed window drops out of the intersection).
#
# FAIL-OPEN CONTRACT (critical):
#   If the live count cannot be determined (tmux missing, registry unreadable, any
#   error), counting helpers print -1 and the gate ALLOWS the spawn. A counting bug
#   must NEVER hard-block the pipeline. Only a CONFIDENT over-cap reading refuses.
#
# This file is meant to be SOURCED (it defines functions) but also runs a small
# self-test / status dump when executed directly:  worker-semaphore.sh [status]
#
# SUPERVISOR LAYER (Wave-7, 2026-06-15):
#   The orchestration model now has THREE execution tiers — main (Opus, the
#   command center) → supervisors (Opus, idle-cheap, one per long-running
#   initiative) → workers (Sonnet, execution). Supervisors are spawned by
#   spawn-supervisor.sh and tracked in a SEPARATE registry with their OWN cap, so
#   the box stays bounded: at most CHILLDAWG_MAX_SUPERVISORS supervisors AND
#   CHILLDAWG_MAX_WORKERS workers (the worker pool is GLOBAL/shared — every
#   supervisor + main draws from the same pool, it is NOT multiplied per
#   supervisor). Total concurrent claude sessions ≤ 1 (main) + sup-cap + worker-cap.
#   Supervisor helpers mirror the worker ones on cs_*_supervisor* names and share
#   the same fail-open contract.
#
# Env knobs (all optional):
#   CHILLDAWG_MAX_WORKERS      max concurrent pipeline workers, GLOBAL/shared (default 6)
#   CHILLDAWG_MAX_SUPERVISORS  max concurrent supervisors (default 4)
#   CHILLDAWG_SPAWN_WAIT       seconds spawn-worker waits+polls for a free slot before
#                              giving up (default 0 = don't wait, refuse immediately)
#   CHILLDAWG_WORKER_REGISTRY     override the worker registry file path
#   CHILLDAWG_SUPERVISOR_REGISTRY override the supervisor registry file path
#   TMUX_SESSION               tmux session to inspect (default 0)

# NB: NO `set -e` here — this is sourced into callers and must never abort them.
# Callers keep their own error handling; these helpers fail soft by contract.

# --- config ------------------------------------------------------------------
_cs_session() { echo "${TMUX_SESSION:-0}"; }

_cs_max_workers() {
  local m="${CHILLDAWG_MAX_WORKERS:-6}"
  # validate: positive integer, else fall back to default (fail-safe, not fail-weird)
  if [[ "$m" =~ ^[0-9]+$ ]] && (( m >= 1 )); then
    echo "$m"
  else
    echo 6
  fi
}

# Supervisor cap — default 4 (Toper 2026-06-15). Separate from the worker cap.
_cs_supervisor_max() {
  local m="${CHILLDAWG_MAX_SUPERVISORS:-4}"
  if [[ "$m" =~ ^[0-9]+$ ]] && (( m >= 1 )); then
    echo "$m"
  else
    echo 4
  fi
}

_cs_registry_path() {
  if [[ -n "${CHILLDAWG_WORKER_REGISTRY:-}" ]]; then
    echo "$CHILLDAWG_WORKER_REGISTRY"
    return
  fi
  local base="${XDG_RUNTIME_DIR:-/tmp}/chilldawg-workers"
  echo "${base}/$(_cs_session).registry"
}

# Supervisor registry — a DISTINCT file so supervisor + worker counts never mix.
_cs_supervisor_registry_path() {
  if [[ -n "${CHILLDAWG_SUPERVISOR_REGISTRY:-}" ]]; then
    echo "$CHILLDAWG_SUPERVISOR_REGISTRY"
    return
  fi
  local base="${XDG_RUNTIME_DIR:-/tmp}/chilldawg-workers"
  echo "${base}/$(_cs_session).supervisors.registry"
}

# --- registry mutators (called by spawn-worker.sh) ---------------------------
# Record a successfully-spawned worker window. Idempotent (dedups). Best-effort:
# a registry write failure must NOT fail the spawn (caller ignores our exit).
cs_register_worker() {
  local window="${1:?cs_register_worker <window_name>}"
  local reg; reg="$(_cs_registry_path)"
  local dir; dir="$(dirname "$reg")"
  mkdir -p "$dir" 2>/dev/null || return 0
  # append if not already present
  if [[ -f "$reg" ]] && grep -qxF "$window" "$reg" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$window" >> "$reg" 2>/dev/null || true
  return 0
}

# Remove a worker from the registry (e.g. on explicit teardown). Best-effort.
cs_unregister_worker() {
  local window="${1:?cs_unregister_worker <window_name>}"
  local reg; reg="$(_cs_registry_path)"
  [[ -f "$reg" ]] || return 0
  local tmp; tmp="$(mktemp 2>/dev/null)" || return 0
  grep -vxF "$window" "$reg" > "$tmp" 2>/dev/null && mv "$tmp" "$reg" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  return 0
}

# --- supervisor registry mutators (called by spawn-supervisor.sh) ------------
# Same idempotent/best-effort contract as the worker mutators, on the supervisor
# registry. A registry write failure must NOT fail the spawn.
cs_register_supervisor() {
  local window="${1:?cs_register_supervisor <window_name>}"
  local reg; reg="$(_cs_supervisor_registry_path)"
  local dir; dir="$(dirname "$reg")"
  mkdir -p "$dir" 2>/dev/null || return 0
  if [[ -f "$reg" ]] && grep -qxF "$window" "$reg" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$window" >> "$reg" 2>/dev/null || true
  return 0
}

cs_unregister_supervisor() {
  local window="${1:?cs_unregister_supervisor <window_name>}"
  local reg; reg="$(_cs_supervisor_registry_path)"
  [[ -f "$reg" ]] || return 0
  local tmp; tmp="$(mktemp 2>/dev/null)" || return 0
  grep -vxF "$window" "$reg" > "$tmp" 2>/dev/null && mv "$tmp" "$reg" 2>/dev/null || rm -f "$tmp" 2>/dev/null
  return 0
}

# --- live-count core ---------------------------------------------------------
# Print the registry ∩ live-tmux-windows set (one window name per line), AND
# rewrite the registry to that pruned set (self-cleaning). Fail-open: on any
# inability to determine, prints nothing and returns 2 (caller treats as unknown).
# Generic over the registry FILE so workers AND supervisors share one proven core
# (the supervisor counter can never drift from the worker counter).
_cs_live_in_registry() {
  local reg="${1:?_cs_live_in_registry <registry_file>}"
  local session; session="$(_cs_session)"

  # tmux must be usable, else we cannot count -> unknown (fail-open)
  command -v tmux >/dev/null 2>&1 || return 2
  tmux has-session -t "$session" 2>/dev/null || {
    # no session at all => zero live (a legitimate, confident answer)
    : > "$reg" 2>/dev/null || true
    return 0
  }

  # snapshot live window names in the session
  local live_windows
  live_windows="$(tmux list-windows -t "$session" -F '#{window_name}' 2>/dev/null)" || return 2

  [[ -f "$reg" ]] || return 0   # no registry => nothing recorded yet

  local pruned=()
  local name
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if printf '%s\n' "$live_windows" | grep -qxF "$name"; then
      pruned+=("$name")
    fi
  done < "$reg"

  # self-prune: rewrite registry to only-live entries (dead entries drop out)
  if (( ${#pruned[@]} )); then
    printf '%s\n' "${pruned[@]}" > "$reg" 2>/dev/null || true
    printf '%s\n' "${pruned[@]}"
  else
    : > "$reg" 2>/dev/null || true
  fi
  return 0
}

# Worker live set (registry ∩ live windows). Behaviour UNCHANGED — now delegates
# to the generic core so the supervisor counter can't drift from it.
cs_live_workers()     { _cs_live_in_registry "$(_cs_registry_path)"; }
# Supervisor live set — same proven core, supervisor registry.
cs_live_supervisors() { _cs_live_in_registry "$(_cs_supervisor_registry_path)"; }

# Print the COUNT of a live set ($1 = "worker" | "supervisor"), or -1 if unknown.
_cs_count_of() {
  local kind="${1:-worker}" out rc
  if [[ "$kind" == "supervisor" ]]; then out="$(cs_live_supervisors)"; else out="$(cs_live_workers)"; fi
  rc=$?
  if (( rc == 2 )); then echo -1; return 0; fi
  if [[ -z "$out" ]]; then echo 0; else printf '%s\n' "$out" | grep -c .; fi
  return 0
}

# Print the COUNT of live pipeline workers, or -1 if it can't be determined.
cs_live_count()            { _cs_count_of worker; }
# Print the COUNT of live supervisors, or -1 if it can't be determined.
cs_live_supervisor_count() { _cs_count_of supervisor; }

# Generic gate check. $1 = "worker" | "supervisor". exit 0 = room (or unknown →
# fail-open), exit 1 = at/over cap. Echoes a human line to stderr.
_cs_has_capacity_of() {
  local kind="${1:-worker}" max count label
  if [[ "$kind" == "supervisor" ]]; then
    max="$(_cs_supervisor_max)"; count="$(cs_live_supervisor_count)"; label="supervisors"
  else
    max="$(_cs_max_workers)";    count="$(cs_live_count)";            label="workers"
  fi
  if [[ "$count" == "-1" ]]; then
    echo "[semaphore] live-${label%s} count UNDETERMINED — failing OPEN (allowing spawn). Cap=${max}." >&2
    return 0
  fi
  if (( count < max )); then
    echo "[semaphore] ${count}/${max} ${label} live — room available." >&2
    return 0
  fi
  echo "[semaphore] ${count}/${max} ${label} live — AT/OVER cap." >&2
  return 1
}

# Gate check: room for one more worker?  (exit 0 = room, 1 = at/over cap.)
cs_has_capacity()            { _cs_has_capacity_of worker; }
# Gate check: room for one more supervisor?
cs_supervisor_has_capacity() { _cs_has_capacity_of supervisor; }

# --- standalone status / self-test ------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-status}"
  case "$cmd" in
    status)
      echo "session:        $(_cs_session)"
      echo "--- workers (Sonnet execution tier) ---"
      echo "max:            $(_cs_max_workers)  (CHILLDAWG_MAX_WORKERS, GLOBAL/shared)"
      echo "registry:       $(_cs_registry_path)"
      echo "live count:     $(cs_live_count)"
      echo "live workers:"
      cs_live_workers | sed 's/^/  - /' || true
      if cs_has_capacity 2>/dev/null; then echo "capacity:       ROOM"; else echo "capacity:       FULL"; fi
      echo "--- supervisors (Opus orchestration tier) ---"
      echo "max:            $(_cs_supervisor_max)  (CHILLDAWG_MAX_SUPERVISORS)"
      echo "registry:       $(_cs_supervisor_registry_path)"
      echo "live count:     $(cs_live_supervisor_count)"
      echo "live supervisors:"
      cs_live_supervisors | sed 's/^/  - /' || true
      if cs_supervisor_has_capacity 2>/dev/null; then echo "capacity:       ROOM"; else echo "capacity:       FULL"; fi
      ;;
    count)     cs_live_count ;;
    list)      cs_live_workers ;;
    sup-count) cs_live_supervisor_count ;;
    sup-list)  cs_live_supervisors ;;
    *) echo "usage: worker-semaphore.sh [status|count|list|sup-count|sup-list]" >&2; exit 2 ;;
  esac
fi
