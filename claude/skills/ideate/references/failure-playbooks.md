# Failure-mode playbooks (full recovery commands)

The exact command sequences behind the SKILL.md playbook summary table. Every command here is verified against the live scripts (2026-07-03). Dash-clean. When a mid-build failure hits, run the matching playbook rather than re-deriving the fix and burning context.

---

## P-1. Worker died mid-milestone (session limit / crash) -> RESUME, never redo

A dead worker resumes from its last verified `STATE.md` checkpoint. It does NOT redo completed work.

```bash
# 1. Confirm the death: is the window gone, or the REPL wedged?
tmux list-windows -t 0 | grep <window>
# 2. If the window died, re-spawn it (same window name; the triage.json + STATE.md persist on disk):
~/.claude/scripts/spawn-worker.sh <window> [<cwd>] [<task_dir>]
#    verify the attn peer reappears BEFORE re-briefing.
# 3. Re-brief with the RESUME preamble (points the worker at its STATE.md Resume cursor):
~/.claude/scripts/resume-worker.sh <window> <task-dir>
#    add the original brief for full context if the task was context-heavy:
~/.claude/scripts/resume-worker.sh <window> <task-dir> --with-brief <orig-brief-file>
```

`resume-worker.sh` builds a RESUME body and hands it to `brief-worker.sh` (so the worker re-absorbs the full role-override + contracts), and auto-falls back to the `--quick` path for an L1-stub STATE.md. The worker then reads STATE.md first, trusts `[x]` checkpoints, cheaply re-verifies the last one, and continues from the first `[ ]`. (Verified twice on market-events: P3 and P4 each died at a limit and resumed cleanly.)

Non-idempotent actions (a WA send, a force-push, a fund-transfer) are sentinel-guarded in STATE.md so a resume never double-fires them. If you are unsure whether a guarded action fired, check the sentinel / the downstream effect (the ledger row, the sent-folder) before allowing the resume to pass that checkpoint.

---

## P-2. Worker stalled (STATE.md mtime >10min while still active)

```bash
# 1. Spot it: fleetview flags STALLED when there is no STATE.md update in >10min while active.
~/.claude/scripts/fleetview.sh              # one-shot; or --watch 30 to refresh
# 2. Inspect the pane to see what it is actually doing (or wedged on):
tmux capture-pane -t 0:<window> -p | tail -40
```

Then decide: if it is genuinely working (a long compile/fetch) leave it; if the REPL is wedged (input dead, common at >90% context) treat it as a death and run P-1 (respawn + resume). Do NOT assume "done" from silence, and do NOT trust an attn "done" ping alone without checking STATE.md (a worker's internal background-wait once fabricated future-dated output on market-events, foreground verification is the fix).

---

## P-3. attn peer never appears after spawn -> do NOT brief blind

The equip rule (NON-NEGOTIABLE 7) is a hard gate: no brief without a verified attn round-trip.

```bash
# 1. After spawn-worker.sh (it already sleeps ~8s), verify from main:
#    call the attn peers tool; confirm <window> shows in Local peers.
# 2. If not visible after ~15s, kill and retry once:
tmux kill-window -t 0:<window>
~/.claude/scripts/spawn-worker.sh <window> [<cwd>]
# 3. Still no peer after 2 retries? Do NOT proceed on attn. Fall back to a status file:
#    brief the worker to write /tmp/<window>-status.md, and main polls it.
```

Root causes worth knowing (memory `feedback_session_delegation`): a missing `ATTN_SESSION` env (send-blind), the "1 MCP server failed" boot race, or the dev-channels flag not applied. `spawn-worker.sh` already launches with the correct `ATTN_SESSION=<window>` + dev-channels + `--remote-control`, so a persistent miss means an attn-shim/plugin problem, investigate it, do not burn the worker's context on send-keys workarounds.

---

## P-4. Prototype FAILED on a load-bearing assumption

A plan that assumes a failed prototype is forbidden (NON-NEGOTIABLE 4). There is no "push through".

- **PIVOT:** adjust the vision so the failed assumption is no longer load-bearing (e.g. swap the blocked data source for a reachable one), then re-run Phase 2 against the new assumption with a fresh PASS/FAIL contract.
- **Validated workaround:** if a bypass exists (market-events' DoH + pinned-IP for the DNS-poisoned exchanges, or the local-relay for the Cloudflare-403 sources), PROTOTYPE THE WORKAROUND before it enters the plan. An untested workaround is still an assumption.
- **PARK:** if neither works, save the idea to `/tasks` as a LATER item with the failure recorded, and STOP the flow. No gate, no build.

Take the FAIL back to Toper explicitly. Do not quietly re-scope around it.

---

## P-5. spawn refusal decode (exit 4 vs exit 5): these are GATES, not bugs

**Exit 4 (triage gate, from `check-triage.sh`):** missing/invalid `triage.json`, OR `level=L3` with `signoff != true`.

```bash
# missing/invalid: write or fix the triage.json in the task dir
cat ~/claude/notes/<task-slug>-<date>/triage.json   # confirm it parses + has a valid level
# unsigned L3: the sign-off gate has NOT closed. Do NOT flip signoff to bypass.
#   Close Phase 3 first (>=10 Q + coverage + prototype PASS + plan + Toper's "approved"),
#   THEN set "signoff": true. The gate is doing its job.
```

**Exit 5 (concurrency governor, from `worker-semaphore.sh`):** at/over the worker cap (default `CHILLDAWG_MAX_WORKERS=6`, a GLOBAL/shared pool).

```bash
~/.claude/scripts/worker-semaphore.sh status         # inspect live worker + supervisor counts
CHILLDAWG_MAX_WORKERS=8 ~/.claude/scripts/spawn-worker.sh <window>     # raise per-spawn (mind the 4-vCPU box)
CHILLDAWG_SPAWN_WAIT=120 ~/.claude/scripts/spawn-worker.sh <window>    # or queue up to 120s for a free slot
```

The pool is shared across main + all supervisors, so a fleet does not multiply it. If you are at the cap during a large fan-out, prefer queueing (`SPAWN_WAIT`) or serializing the dependency chain over raising the cap on a 4-vCPU box.

---

## P-6. Scope explodes mid-L2 discovery (it is really L3)

If, mid Capture-lite, the idea reveals an L3 trigger (a new standalone repo, customer-facing at scale, touches auth/payments/secrets, irreversible/high-stakes, multi-day), STOP the L2 light path and **re-triage UP to L3**. Print a corrected `📊 TRIAGE - Level 3` header, then invoke the full gate: `>=10` questions + the 7-dimension coverage + a prototype with a PASS/FAIL criterion + a written plan + explicit sign-off, all BEFORE any worker. Round up, never down; an L3-treated-as-L2 is the expensive mistake (the Pulse landing rejection).

---

## P-7. /audit returns Critical/High blockers

Do not ship on an unrefuted Critical.

```bash
# 1. The audit already ran an adversarial refutation pass; a surviving Critical is real.
# 2. Turn each blocker into a NEW delegated fix milestone (its own task dir + brief + verification gate),
#    spawn + brief it exactly like a build milestone (Phase 5 loop).
# 3. Re-run /audit on the repo after the fixes land; only proceed when Critical == 0.
```

market-events is the pattern: 4 data-integrity blockers became fix task #234 + deploy #235 (commit `06d7ba7`), re-verified (sha256 non-disturbance proof, 98 -> 123 tests), then it went live.

---

## P-8. Toper says "just start building" before L3 sign-off -> HOLD

The L3 gate is hard AND mechanically backed: `spawn-worker.sh` / `spawn-supervisor.sh` refuse an unsigned L3 (`exit 4`) via `check-triage.sh`, backstopped by the PreToolUse `triage-gate-hook.sh` (fail-open, loads at session start). So flipping `signoff:true` early to "just build" both violates the rule AND would push an unvalidated build. HOLD: name the open boxes (usually prototype + explicit approval), close them fast, then proceed. The gate exists because the one time it was skipped (Pulse landing) cost an hour of work + 5 commits rejected outright.
