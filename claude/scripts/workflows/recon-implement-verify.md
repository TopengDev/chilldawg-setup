# Workflow: recon → implement → verify

**Three sequential phases** for a change that must be understood before it's touched,
implemented in a scoped way, then proven end-to-end. This is the fitest pattern and
the default shape for most feature/bugfix work that isn't trivial.

## When to use

- A bug fix or feature in **unfamiliar or load-bearing code** where blind editing
  risks regressions (the global "Read Before Writing" rule, mechanized).
- Work where **verification is non-trivial** and deserves its own phase (run the
  flow, hit the endpoint, check the DB) — not an afterthought.
- A change you want a **clean audit trail** for: what was the territory, what
  changed, how it was proven.

NOT for: independent parallel review (use fan-out-review) or a converge-to-green
loop (use loop-until-green). If recon reveals the work is huge, fan-out the
*implement* phase into sub-tasks.

## Shape

```
recon  ──►  implement  ──►  verify
 (map)       (change)        (prove)
   │            │              │
 report     scoped diff     evidence
 consumed   per recon       (not claims)
 by impl
```

Phases are **sequential** — each consumes the prior phase's output. They can be:
- **separate workers** (clean handoff, each phase's context isolated), or
- **one worker doing all three phases** as STATE.md checkpoint groups (lighter for
  smaller tasks). The scaffold defaults to 3 workers; collapse to 1 for small work.

## Worker shapes (brief skeletons)

**recon:**
- Role: map the territory. Read the code/system, identify the EXACT change surface,
  enumerate affected files + callers + tests, surface constraints + risks.
- Hard rule: **NO code changes** in recon.
- Output: a recon report the implement phase reads (paths, call graph, risks,
  the proposed change plan).
- Gate: the change surface is complete (every caller/test that touches it is listed).

**implement:**
- Role: make the change per the recon plan. Read-before-write on each file recon
  flagged. Keep the diff scoped to the plan.
- Checkpoints: one idempotent STATE.md checkpoint per sub-change (so a kill mid-way
  resumes cleanly via `resume-worker.sh`).
- Gate: change matches the recon plan; no scope creep; `bash -n` / typecheck / lint
  clean for what was touched.

**verify:**
- Role: prove it works end-to-end. Run the ACTUAL flow, capture evidence (command
  output, screenshots, curl, DB rows). Check for regressions in the callers recon
  listed. Verify in the target env if it ships.
- Gate (the "Close the Loop" rule): **evidence, not claims.** Report what couldn't
  be verified explicitly.

## Sequencing

1. `scaffold-workflow.sh recon-implement-verify <run>`  (or `--phases "recon implement verify"`)
2. Fill the **recon** brief Task section first (the others depend on its output).
3. Spawn + brief **recon**. Wait for COMPLETE; read its `report.md` / `result.json`.
4. Fold recon's findings into the **implement** brief, then spawn + brief it.
5. After implement COMPLETE, fold the change summary into the **verify** brief,
   spawn + brief it.
6. `fleetview.sh` between phases to confirm each reached COMPLETE before the next.

> Because the phases are sequential, concurrency is rarely the constraint here —
> but if you run several recon-implement-verify chains at once, the governor still
> keeps the total worker count under `CHILLDAWG_MAX_WORKERS`.

## Verification gates

- **recon → implement handoff:** implement only starts once recon's change surface
  is complete (no "discover a new caller mid-implement" surprises).
- **implement → verify handoff:** verify gets the actual diff/commit to test against.
- **verify exit:** end-to-end evidence captured; regressions in known callers
  checked; anything untestable flagged with the alternative check done.
- Each phase writes `result.json`; `status=partial` is valid for implement if it
  checkpointed but didn't finish (resume it).
