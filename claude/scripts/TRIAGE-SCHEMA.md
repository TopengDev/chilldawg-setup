# Triage Gate — `triage.json` schema & convention

Mechanical enforcement of the **Task Complexity Triage** + **3-tier hierarchy** rules.
Soft prose rules ("Claude remembers to triage / ask 10 questions") don't fire under
load — this makes them gates.

## The artifact

One `triage.json` per task, living in the task notes dir **beside `STATE.md` and `brief.md`**:
`~/claude/notes/<task-slug>-<YYYY-MM-DD>/triage.json`

```json
{
  "task_slug": "pulse-landing-redesign",
  "level":     "L1|L2|L3",
  "scope":     "one-line description of what it touches",
  "created":   "2026-05-24T15:52:00+07:00",
  "signoff":   false,
  "model":     "sonnet"
}
```

| field       | meaning |
|-------------|---------|
| `task_slug` | task slug (should match the spawn window name; not hard-enforced) |
| `level`     | `L1` trivial / `L2` standard-complex / `L3` major. **Required.** |
| `scope`     | one-line human echo of the `📊 TRIAGE` chat header |
| `created`   | ISO timestamp |
| `signoff`   | **L3 only.** Starts `false`. Flips `true` ONLY after Toper's explicit approval (10+ Q + prototype + plan + sign-off). L1/L2 ignore this field. |
| `model`     | **Optional.** Worker model: `sonnet` (default, the hard floor) or `opus` (carve-out). Omit ⇒ `sonnet`. `spawn-worker.sh` reads it; `CHILLDAWG_WORKER_MODEL` env overrides it. See "Worker model" below. |

## Worker model (Sonnet floor, Opus carve-out — Wave-7, 2026-06-15)

Workers run on **Sonnet by default** (the hard floor) to cut token cost; **Opus**
is a deliberate **carve-out** for: security-critical work · customer-facing design
(oneshot/pitch) · genuinely novel root-cause debugging. To run a worker on Opus,
set `"model":"opus"` in its `triage.json` (or `CHILLDAWG_WORKER_MODEL=opus
spawn-worker.sh …` for a one-off). Anything that isn't an `opus` token clamps to
the Sonnet floor (never lower). `spawn-worker.sh` echoes the resolved model at
spawn; `fleetview.sh` shows it per worker (Opus flagged). Supervisors are spawned
by `spawn-supervisor.sh` and are **Opus** (orchestration judgment); they are
capped + tracked separately from the shared worker pool — see CLAUDE.md
"Supervisor Orchestration Layer".

The `📊 TRIAGE` chat header main prints is the human-readable echo of this file —
write `triage.json` first, then print the header.

## Enforcement points

| Layer | File | Behaviour |
|-------|------|-----------|
| **Primary** (immediate) | `~/.claude/scripts/spawn-worker.sh` | Calls `check-triage.sh` before creating the tmux window. Refuses (exit 4) if blocked. **Fail-closed** on missing/invalid triage. |
| **Secondary** (belt-and-suspenders) | `~/.claude/hooks/triage-gate-hook.sh` (PreToolUse, matcher `Bash`) | Catches `spawn-worker.sh` Bash commands even if the wrapper is bypassed. **Fail-open** on any uncertainty — only a confirmed block denies. |
| **Shared logic** | `~/.claude/scripts/check-triage.sh` | Single source of truth. `<window>` [`<task_dir>`] → exit 0 allow / 1 block / 2 internal-error. |

> ⚠️ **Hooks load at session start.** A newly-added/edited hook does NOT affect
> already-running sessions — restart Claude Code to activate. The script guard
> (`spawn-worker.sh`) takes effect immediately; the hook protects future sessions.

## Resolution: spawn command → triage.json

`check-triage.sh <window_name> [<task_dir>]` resolves the file by:

1. **Explicit** — `<task_dir>` arg (`$2`) or `$TASK_DIR` env → `<task_dir>/triage.json`.
   Pass this when spawning for zero ambiguity:
   `TASK_DIR=~/claude/notes/foo-2026-05-24 spawn-worker.sh foo`
   or `spawn-worker.sh foo ~/claude <task_dir>` (3rd positional).
2. **Convention/glob** (fallback) — `~/claude/notes/<window_name>-*/triage.json`,
   newest by mtime. Works because the notes dir is conventionally
   `<window-name>-<YYYY-MM-DD>` and the window name is the task slug.

## Gate rules

- No `triage.json` → **blocked**.
- Invalid JSON / bad-or-missing `level` → **blocked**.
- `level=L3` and `signoff != true` → **blocked**.
- `L1` / `L2`, or `L3` with `signoff=true` → **allowed**.

## L1 fast-path (lightweight spawn)

L1 trivial work does NOT need the full 3-tier ceremony. For L1:

- triage.json with `"level":"L1"` (no signoff needed)
- a one-line brief + a **stub STATE.md** (name / status / one-liner) — no initiative
  file, no parent-initiative linkage required
- deliver with `brief-worker.sh --quick <window> <brief>` (accepts the stub; the
  default path requires a "Parent initiative" line for full 3-tier linkage)

Pure-comms L1 (send WA, list tmux, answer a question) is **not** a worker task —
it stays in main. Don't spawn a worker for it.

## Testing the gate

```bash
# block: no triage.json
check-triage.sh ghost-task ; echo "exit=$?"          # -> 1
# allow: L2 fixture
check-triage.sh workflow-hardening-local ; echo "exit=$?"   # -> 0
# block: L3 unsigned / allow: L3 signed  (see check-triage.sh header)
```
