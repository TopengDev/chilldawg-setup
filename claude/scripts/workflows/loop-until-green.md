# Workflow: loop-until-green / loop-until-dry

**Iterate a check → fix → recheck cycle** until a GREEN condition holds (CI passes,
a queue drains, 0 findings remain) or a budget cap is hit. One worker window is
re-driven across iterations; each fix is an idempotent checkpoint.

## When to use

- **loop-until-green:** drive something to a passing state — make CI green, get a
  test suite to 0 failures, get a linter/typecheck/audit to 0 findings.
- **loop-until-dry:** drain a backlog — process a queue until empty, fix every item
  in a list, migrate every record, until none remain.

Both share one shape: a **terminating condition** + a **per-iteration action** +
a **budget** so it can't spin forever.

NOT for: a one-shot change (recon-implement-verify) or independent parallel review
(fan-out-review).

## Shape

```
        ┌───────────────────────────────────┐
        ▼                                   │
   run the CHECK ──► GREEN? ──yes──► DONE   │ (re-brief same window
        │              │                    │  via resume-worker.sh,
        │              no                    │  continue from checkpoint)
        ▼              │                     │
   fix first failure ──┘ ── budget left? ──yes┘
        │                      │
        └──────────────────────┴── no ──► STOP (report partial + remaining)
```

- **Single worker window**, re-driven each iteration. Between iterations the loop
  driver (main) re-briefs it with `resume-worker.sh` so it picks up from its
  STATE.md checkpoints rather than restarting.
- Each fix is recorded as an **idempotent checkpoint** — re-running is safe, and a
  kill mid-loop resumes mid-loop.
- A **budget** (max iterations / max wall-clock / max fixes) is mandatory. The loop
  reports `partial` + the remaining work if the budget is exhausted before GREEN.

## Worker shape (brief skeleton)

- Role: "Run `<the check>`. If RED/non-empty: fix the FIRST failure/item, re-run.
  Repeat until GREEN/empty or budget hit."
- Define explicitly in the brief:
  - **CHECK command** (e.g. `npm test`, `gh run watch`, a queue-length query).
  - **GREEN condition** (exit 0 / 0 failures / queue length 0).
  - **per-iteration ACTION** (fix the first failure; process the next item).
  - **BUDGET** (e.g. "max 10 iterations" / "max 30 min" / "max 20 items").
- Checkpoints: one per fix/item processed (idempotent). Update the Resume cursor.
- Gate each iteration: re-run the CHECK and record its result as the proof the fix
  landed — never mark an item done without the re-check passing.

## Sequencing (how main drives the loop)

1. `scaffold-workflow.sh loop-until-green <run> --iterations 1`
2. Fill the brief: CHECK command, GREEN condition, per-iteration ACTION, BUDGET.
3. Spawn + brief the worker. It runs its own internal loop until GREEN or its budget.
4. If the worker is killed / hits the session limit mid-loop:
   `resume-worker.sh <window> <task-dir>` — it re-reads STATE.md and continues from
   the last completed checkpoint (does NOT redo fixed items — they're idempotent).
5. `fleetview.sh --watch` shows live progress (done/remaining checkpoints = loop
   progress; STALLED flag if it wedges).
6. On exit, read `result.json`: `done` = GREEN reached; `partial` = budget hit,
   `followups[]` lists the remaining red/undrained items.

> The loop's own budget is the inner stop; the worker's session limit + the
> resume contract is the outer safety net (so a long drain survives a kill).

## Verification gates

- **Per iteration:** the CHECK is re-run after each fix and its result recorded —
  a checkpoint flips `[x]` only when the re-check confirms the fix.
- **GREEN exit:** the final CHECK genuinely passes (exit 0 / 0 findings / empty
  queue) — captured as evidence in `result.json.evidence`.
- **Budget exit:** `status=partial`, remaining items enumerated in `followups[]` /
  `blockers[]`, so a fresh run (or a human) can pick up exactly where it stopped.
- **No infinite spin:** a budget is present and enforced. A loop with no budget is
  a bug — the scaffold's brief stub requires you to set one.
