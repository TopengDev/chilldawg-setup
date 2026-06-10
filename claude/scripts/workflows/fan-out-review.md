# Workflow: fan-out-review

**N parallel single-focus agents → one synthesis.** Each agent reviews/explores the
SAME target through ONE sharp lens; a final synthesis agent consolidates, dedupes,
and classifies. This is the pattern behind tonight's 4-agent audit and the
`/audit` skill.

## When to use

- A **multi-dimensional review** where one general reviewer would be shallow
  (code audit across quality / security / perf / a11y / biz-logic).
- A **broad exploration** that parallelizes cleanly (survey N libraries, N repos,
  N candidate approaches), then needs a consolidated recommendation.
- Anything where **breadth + independence** beats a single sequential pass.

NOT for: a change with strong ordering between steps (use recon-implement-verify),
or a converge-on-a-condition loop (use loop-until-green).

## Shape

```
            ┌─ lens: quality     ─┐
            ├─ lens: security    ─┤
target ──►  ├─ lens: performance ─┼──►  synthesis agent  ──►  consolidated verdict
            ├─ lens: ux          ─┤      (runs AFTER all)
            └─ lens: biz-logic   ─┘
```

- **Lens agents run in PARALLEL** (independent task dirs, spawned together up to the
  concurrency cap). Each has ONE focus and a concrete pattern list — never a fuzzy
  "find issues" prompt.
- **Synthesis runs LAST**, after every lens reports. It reads each lens's
  `result.json` + `report.md`, dedupes overlaps, classifies by severity x
  confidence, and produces the single verdict.

## Worker shapes (brief skeletons)

**Lens agent (×N):**
- Role: "Review `<target>` through the `<dimension>` lens ONLY."
- Hard rules: cite `file:line` for every finding; tag each
  `confirmed | probable | theoretical`; bounded severity (Critical/High/Med/Low);
  **report only, do NOT fix**.
- Verification gate: every finding has a concrete code path / evidence; no
  hand-waving. Theoretical findings are allowed but flagged.
- Output: `report.md` (narrative) + `result.json` with
  `deliverables`=[findings count], `evidence`=[the file:line citations].

**Synthesis agent (×1):**
- Role: ingest all lens outputs, produce consolidated severity-graded report +
  GA/readiness verdict.
- Inputs: `result-schema.sh <each-lens-dir>` to read structured results.
- Verification gate: every consolidated finding traces back to ≥1 lens finding;
  the verdict is justified by the severity distribution.

## Sequencing

1. `scaffold-workflow.sh fan-out-review <run> --agents "quality security performance ux biz-logic"`
2. Fill each lens `brief.md` Task section (the target + the dimension's pattern list).
3. **Mind the concurrency cap.** A 5-lens fan-out + your other workers may exceed
   `CHILLDAWG_MAX_WORKERS` (default 4). Either raise it for the burst
   (`CHILLDAWG_MAX_WORKERS=6`) or let spawns queue (`CHILLDAWG_SPAWN_WAIT=180`).
4. Spawn + brief all lens agents (parallel). Confirm each via attn peers first.
5. `fleetview.sh --watch` until all lenses hit COMPLETE (watch for STALLED).
6. Spawn + brief the synthesis agent; hand it the lens task dirs.
7. Read the synthesis `result.json` with `result-schema.sh`.

## Verification gates

- **Per lens:** findings cite `file:line`; classification tier present; no fixes applied.
- **Synthesis:** consolidated findings dedupe correctly; verdict matches the
  severity distribution; nothing from a lens is silently dropped.
- **Fleet-level:** all lenses reached COMPLETE (not STALLED) before synthesis ran.

## Reference

The `/audit` skill (`~/.claude/skills/audit/`) is the fully-developed version of
this pattern — parallel lens agents, `confirmed|probable|theoretical` tiers,
bounded severity, cross-cutting synthesis. Read its `SKILL.md` + `synthesis.md` for
the mature lens prompt lists and the synthesis classification rubric.
