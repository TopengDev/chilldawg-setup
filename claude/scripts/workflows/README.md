# Workflow Library

Codified, reusable **multi-worker orchestration patterns** that main keeps
hand-assembling. Each is a **playbook** (when to use, worker shapes, sequencing,
verification gates) plus a **scaffolding helper** (`scaffold-workflow.sh`) that
writes the 3-tier pre-spawn artifacts (one task dir per worker, each with
`triage.json` + `STATE.md` + a role-shaped `brief.md` stub) so you don't build
them by hand every time.

These are **NOT an executable orchestrator** — main still drives the loop via the
Agent tool / tmux + `spawn-worker.sh` + `brief-worker.sh` + attn. The library
codifies the *shape* and hands you the exact commands to run.

## The patterns

| Pattern | Playbook | Use when |
|---|---|---|
| **fan-out-review** | [fan-out-review.md](fan-out-review.md) | N parallel single-focus agents review/explore the same target, then one synthesis agent consolidates. (Tonight's 4-agent audit; the `/audit` skill.) |
| **recon → implement → verify** | [recon-implement-verify.md](recon-implement-verify.md) | A change that must be mapped before touched, implemented scoped, then proven end-to-end. (The fitest pattern; most feature/bugfix work.) |
| **loop-until-green / loop-until-dry** | [loop-until-green.md](loop-until-green.md) | Iterate a check→fix→recheck cycle until a GREEN condition (CI passes / queue drains / 0 findings) or a budget cap. |

## The scaffolding helper

```bash
# fan-out-review: 5 dimension agents + a synthesis agent
scaffold-workflow.sh fan-out-review pulse-ga-audit \
  --agents "quality security performance ux biz-logic"

# recon→implement→verify: 3 phase workers
scaffold-workflow.sh recon-implement-verify bms-export-fix

# loop-until-green: one re-briefable iteration window
scaffold-workflow.sh loop-until-green ci-green --iterations 1

# preview without writing anything
scaffold-workflow.sh fan-out-review demo --dry-run
```

It writes (under `~/claude/notes/`):
- the **initiative** file (`--initiative <slug>`, default = run slug) if missing,
- per worker a **task dir** `<window>-<date>/` with `triage.json`, `STATE.md`
  (from the live template), and a **`brief.md` stub** pre-filled with that
  worker's role + an empty Task section + a verification gate,

then prints the exact `spawn-worker.sh` + `brief-worker.sh` commands to run.

> You still fill each `brief.md`'s **Task** section with concrete specifics before
> spawning — the scaffold gives structure + the role framing, not the content.

## How it composes with the rest of the pipeline

```
triage.json  ─┐
STATE.md     ─┼─► spawn-worker.sh ─► (attn peers check) ─► brief-worker.sh ─► worker runs
brief.md     ─┘        │                                        │
   (scaffold writes)   │ concurrency governor (worker-semaphore.sh) gates here
                       ▼
                 fleetview.sh --watch   (monitor live)
                 resume-worker.sh       (if a worker dies → resume from checkpoint)
                 result-schema.sh <dir> (read each worker's machine-readable result)
```

Every pattern leans on the same primitives:
- **STATE.md checkpoints** make each worker resumable (`resume-worker.sh`).
- **result.json** (validated by `result-schema.sh`) lets main ingest outcomes.
- **The concurrency governor** keeps a wide fan-out from thrashing the 4-vCPU box
  (raise the ceiling with `CHILLDAWG_MAX_WORKERS` for a big fan-out, or let it
  queue with `CHILLDAWG_SPAWN_WAIT`).
- **FleetView** is the live cockpit across all of them.

## Verification gates are mandatory in every pattern

No pattern lets a worker self-declare "done" without evidence. Each playbook bakes
in a verification gate per the global "Close the Loop" rule — a worker proves its
output (command output, screenshots, curl, DB rows, re-run results), not claims it.
