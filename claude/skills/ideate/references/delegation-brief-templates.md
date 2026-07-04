# Delegation brief templates

Copy-ready skeletons for the briefs `/ideate` hands to spawned workers. Every full-path brief is delivered with `~/.claude/scripts/brief-worker.sh <window> <brief_file>` (or `--supervisor` / `--quick`), which prepends the role-override preamble (open STATE.md first, set IN_PROGRESS, checkpoint + verify-before-marking, write `report.md` + `result.json`), so these skeletons carry only the TASK-specific content. Keep every brief dash-clean. Each brief must satisfy the Phase-5 per-milestone equipped-brief checklist (the 8 boxes) or it is incomplete.

The STATE.md checkpoint pattern (bottom of this file) is what makes every worker resumable, it is referenced by all four brief types.

---

## 1. Equipped build-milestone brief.md

The default. One per build milestone. INCOMPLETE if any of the 8 checklist boxes is unmet.

```md
# Task: <milestone name>  (Parent initiative: <slug>)

## Goal
<the ONE thing this milestone ships, from 05-build-plan.md. Independently shippable.>

## Context (read these first)
- Vision/scope/architecture: ~/claude/Git/repositories/<project>/docs/ideation/{01-vision,03-scope,04-architecture}.md
- Prototype findings that constrain you: docs/ideation/02b-prototype-findings.md  (e.g. "source X is Cloudflare-403 from the VPS, use the local relay")
- The plan milestone spec: docs/ideation/05-build-plan.md  (this milestone's section)

## Credentials / access
- Secrets: source ~/.claude/secrets.env  (e.g. $VPS_PASSWORD, $ANTHROPIC_API_KEY, $PULSE_TEST_*)
- VPS access: sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$VPS_USER@$VPS_HOST"  (READ-ONLY unless this brief says otherwise)
- Access level: <read-only | read-write on X>. Push authorized? <no by default>. Container restart? <no by default>.

## Don't-disturb invariants (HARD)
- Do NOT touch <signal-trader / other VPS services / the wa-sender queue file that belongs to another system>.
- <e.g. "market-events.jsonl is OURS; events.jsonl is signal-trader's, never write it">.

## Deliverables
- <files / units / endpoints this milestone produces>

## Verification gate (evidence, not claims, you are NOT done until every item has evidence)
- [ ] <the flow runs: paste curl codes / a real run's output>
- [ ] <persistence proven: the DB row / the file written and re-read>
- [ ] <the invariant held: e.g. sha256 of the untouched neighbor service matches before/after>
- [ ] <tests: N passing, name the file>
- [ ] <if a website milestone: the Rule-10 fork item, e.g. next-intl id/en + both themes render, OR light-only per /oneshot-webapp>

## Resumability contract
- Maintain STATE.md: decompose into idempotent Checkpoints, mark [x] ONLY after verifying the effect landed (record the proof inline), keep the Resume cursor current.
- On completion (or terminal block) write result.json next to STATE.md:
  {task_slug, status(done|blocked|partial), summary, deliverables[], evidence[], blockers[], followups[], staged_for_human[]}.

## Report back
- Ping main via attn on start (hello) and on completion/block. Report: what was done, what was verified (evidence), what is pending, surprises.

## Browser + commit rules (if relevant)
- Browser work: use /agent-browser with qutebrowser, NEVER Playwright (also hook-banned).
- Commits: use /commit (carries CLAUDE_COMMIT_SKILL=1), NO raw git commit; NO push unless this brief authorizes it.
```

`triage.json` for this dir: `{"task_slug","level":"L3"|"L2","scope","created","signoff":true,"model":"sonnet"}`. Set `"model":"opus"` ONLY on a carve-out milestone (auth/payments/secrets, customer-facing design-quality frontend, genuinely novel debugging) and say WHY in the milestone note.

---

## 2. Recon / prototype brief.md (Phase 2)

Its own task dir, `triage.json` `level:L2` (a recon sub-task is not the L3 build). It writes `report.md` + a `result.json` whose summary carries the verdict. The point is a falsifiable verdict table, not working code.

```md
# Task: RECON <riskiest assumption>  (Parent initiative: <slug>)

## The assumption under test
<the one thing that, if false, kills or reshapes the build>

## PASS / FAIL contract (do NOT deviate; this was written before you started)
- PASS if: <falsifiable, specific, measurable>
- FAIL if: <the negation + its failure signature>

## Method
- <exact probes: which URLs to curl, which library import to try, which API call, from which box (local AND VPS if reachability is the risk)>
- THROWAWAY code only. Do not build v1. Iterate cheaply.

## Deliverables
- report.md with a VERDICT TABLE: one row per sub-assumption -> PASS/FAIL + evidence (HTTP code, returned fields, error, geoblock, rate limit, version).
- result.json: status=done, summary = the overall verdict + the top findings that will reshape the plan.

## Findings to hunt for (these become planning inputs)
- geoblocks / DNS-poisoning, Cloudflare 403 from the VPS IP, rate limits, TLS-fingerprint blocks, history-depth limits, version incompatibilities, undocumented header requirements, paywalls hiding in a page's __NEXT_DATA__.

## Report back
- Ping main on start + completion. If FAIL on a load-bearing assumption, say so loudly: main must PIVOT/PARK, not plan around it.
```

---

## 3. /ship-delegated stage-and-hold brief.md (Phase 7)

When `/ship` is handed to a worker, the push gate is baked in from the start (per /ship S-9): the worker runs steps 1-7, STOPS before Step 8, and waits for the explicit go. Never let a worker self-authorize the irreversible push (verified 2026-05-30: a worker racing at ~30s/repo pushed 3 of 4 before the holds landed).

```md
# Task: SHIP <project/feature>  (Parent initiative: <slug>)

## What to run
- Invoke /ship. Run steps 1-7 ONLY: 1 /simplify -> 2 security review -> 3 /e2e -> 4 version+changelog -> 5 README -> 6 /commit -> 7 /preflight.
- STOP before Step 8 (PUSH). Do NOT push. Do NOT tag. Do NOT run the Step 9 distribution tail.

## Report at the hold
- The commit SHA(s) produced, the /preflight READY|NOT READY verdict with per-gate evidence, and any FAIL/BLOCKED at steps 1-7 (which vetoes the push).
- Then WAIT for main's explicit "go".

## On the explicit go (and only then)
- Step 8: push (NEVER --force; behind-remote is the only self-recoverable rejection).
- Step 9 distribution tail: (a) changelog refresh if not already current, (b) annotated tag git tag -a v{VERSION} + push, (c) CI watch: gh run watch then the MANDATORY gh run view <id> --json conclusion,status re-confirm (PASS only on conclusion=="success"), (d) publish stays OFF unless main confirms.
- /ship never SSHes to the VPS. Server-deploy is /deploy-landing or /oneshot-webapp, a separate step.

## Report back
- Ping main at the hold and again after the CI verdict, with the run URL + conclusion JSON as evidence.
```

---

## 4. Supervisor brief (fleet only, Phase 5, delivered with `brief-worker.sh --supervisor`)

Hand the supervisor the plan + initiative, not a single milestone. It decomposes and delegates to Sonnet workers itself.

```md
# Supervisor: <initiative name>  (initiative: <slug>)

## Your role
- You are an OPUS SUPERVISOR. You DELEGATE to Sonnet workers (spawn-worker.sh + brief-worker.sh, full pre-spawn discipline per worker). You do NOT write product code.
- Idle-cheap / event-driven: after spawning the fleet, WAIT. Wake only on a real event (a worker's result.json, a stall, a milestone, a decision). No busy-poll.
- You NEVER DM Toper and NEVER set WHATSAPP=1. Escalations go supervisor -> main -> Toper. Main is the sole relay.

## The plan
- docs/ideation/05-build-plan.md + ~/claude/notes/initiatives/<slug>-plan.md. Milestones: <P1..Pn>, dependency order <chain | graph>.
- Model policy: each milestone triage.json is sonnet by default; opus ONLY on a stated carve-out.

## Your ledger (resumable)
- Maintain SUPERVISOR-STATE.md (template ~/claude/notes/templates/SUPERVISOR-STATE.md): Direction, Plan/partition, Fleet roster, Orchestration checkpoints (idempotent, verify-before-mark), Resume cursor. If you die, re-read it and re-attach to the fleet, do NOT re-spawn done/in-flight workers.

## Report UP to main via attn ONLY at these checkpoints
1. FIRST: your DIRECTION / partition plan BEFORE spawning any worker (direction confirmation, catch drift in minute 5).
2. Each milestone boundary (a gate passed).
3. A blocker needing Toper's decision.
4. A gated / irreversible action (e.g. the ship push).
5. DONE.
Do NOT relay every worker ping.

## The per-milestone loop (for each milestone, dependency order)
- Equip the brief (the 8-box checklist), spawn-worker.sh, VERIFY attn peer before briefing, brief-worker.sh, poll fleetview.sh, resume a dead worker via resume-worker.sh (RESUME not redo), ingest result.json, run /audit at the boundary, feed blockers back as new milestones, then open the next.
- Serialize on dependency; parallelize where the graph allows within the shared worker cap of 6.
```

---

## The STATE.md checkpoint pattern (referenced by all four)

Every full-path worker maintains `STATE.md` (from `~/claude/notes/templates/STATE.md`) as a resumable journal. The load-bearing mechanics:

- **Checkpoints are idempotent and verified.** Decompose the task into sub-steps that are each safe to re-run/re-check. Mark a checkpoint `[x]` ONLY after verifying its effect actually landed (file written + re-read, command exit 0 + output asserted, a DB row, an endpoint 200), and record the proof inline. A `[x]` checkpoint is therefore safe to SKIP on resume.
- **The Resume cursor** points at the first incomplete checkpoint.
- **Non-idempotent actions** (send-email, force-push, fund-transfer, a WA send) are GUARDED with a sentinel checked on resume so they never double-fire.
- **Resume protocol** (on every restart): read STATE.md FIRST, trust `[x]` and skip them, cheaply re-verify the last `[x]` still holds, continue from the first `[ ]`.
- **Parent initiative** line is mandatory on the full path (`brief-worker.sh` exits 3 without it): `**Parent initiative:** [<slug>](../initiatives/<slug>.md)`.

This is why a worker that dies at the session limit resumes instead of redoing, and why market-events' P3 and P4 both survived a death cleanly.
