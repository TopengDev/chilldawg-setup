# Autonomous Loop — wake-priority model + idle backlog

How the overnight autonomous loop decides, on each wake, **how urgently to wake
next** and **what to do first** — and what it grinds on when nothing is urgent.

> **Scope contract.** This is ADDITIVE documentation + one read-only helper
> (`claude/scripts/wake-priority.sh`). It does **not** rebuild the loop, add an
> event bus, or change how main schedules itself. It gives the existing loop a
> cheap priority lens and a backlog to pull from. The standing rule it
> operationalizes is memory `feedback_always_working` ("while Toper sleeps, keep
> grinding on real deliverables, not just health-checks").

---

## 1. How the loop actually works (the substrate — don't re-invent)

Main (the command-center session) runs a **self-pacing dynamic loop**:

- It schedules its **own next wake** with `ScheduleWakeup`, tagged with the
  sentinel `<<autonomous-loop-dynamic>>`. There is no external cron driving the
  *conversation* loop — main decides when it next wakes.
- When **harness-tracked work finishes** (a spawned sub-agent completes), main is
  **auto-re-invoked** immediately — it does not have to poll for that.
- Independently, a fleet of `systemd --user` timers runs scheduled jobs
  (deadman every ~3 min, the 06:00/21:00 briefs, the 06:30 loop-digest, memory
  autopush/decay, etc.). These are **out-of-band** of the conversation loop —
  they email/WhatsApp Toper or write state files; they do not themselves drive
  main's next wake. See `docs/ARCHITECTURE.md` §11 for the full timer layer.

So the loop's cadence was, until now, essentially *"finish the current wave →
continue, or sleep a fallback interval."* The piece that was missing: **a
priority model** for what to wake-and-act on, and **a backlog** to pull from when
nothing is urgent. That is what this document + `wake-priority.sh` +
`~/claude/notes/idle-backlog.md` add.

---

## 2. The wake-priority ladder

Three tiers. Highest pending wins. On each wake, main consults the priority (via
`wake-priority.sh`, or by reasoning over the same signals) and picks both a
**cadence** (how soon to wake again) and a **first action**.

### P0 — act immediately  (wake hot, ≤60s)
The current state is **time-critical and/or irreversible**. Shorten cadence to
seconds and handle it before anything else.

| P0 signal | Source (how it's detected) | Pollable by `wake-priority.sh`? |
|---|---|---|
| **A real daemon-death alert** — a load-bearing daemon that was running has died (the 26h wa-sender silent-death class). | `deadman.sh` writes `~/.claude/state/deadman/<target>.alerted` on an **armed alive→dead transition** and removes it on recovery. Presence of any `*.alerted` = active, un-recovered outage. | **Yes** — `wake-priority.sh` scans that dir. |
| **A Toper WhatsApp / SUPERUSER message.** | Delivered **LIVE** to main as a `<channel source="whatsapp">` event because main runs with `WHATSAPP=1`. The CLAUDE.md "WhatsApp Channel Discipline" rule already makes this first-class (always reply). | **No, by design** — it's a live push to the running session, not a state file. `wake-priority.sh` does not (and need not) detect it; the harness already surfaces it. |
| Anything else time-critical **and** irreversible (e.g. a scheduled hard-deadline firing). | Case-by-case (a `ScheduleWakeup`/`CronCreate` time-promise coming due). | Partial — see P1 "scheduled commitment". |

### P1 — handle next  (tighter cadence, ~1–10 min)
Real work is queued but not an emergency. Drain it before idle work.

| P1 signal | Source | Pollable? |
|---|---|---|
| **A fresh worker `result.json` to ingest.** A spawned worker finished and wrote its machine-readable result. | Workers write `~/claude/notes/<slug>/result.json` (Wave-3 contract; schema in `result-schema.sh`). "Fresh" = mtime newer than the last-consumed marker `~/.claude/state/wake-priority.consumed`. | **Yes** — `wake-priority.sh` scans `notes/*/result.json`, counts unconsumed, names the newest. After acting, the loop calls `wake-priority.sh --consume` to advance the marker. |
| **A paid-work thread is due.** The Ryan/BMS fitest thread typically resumes **~morning WIB**; be responsive then. | Time-of-day vs a known window (08:00–11:00 WIB, weekdays). Soft signal — "stay responsive", never an alarm. | **Yes** — `wake-priority.sh` checks the wall clock in the `Asia/Jakarta` zone. |
| **A scheduled commitment comes due** — a time-promise made via `ScheduleWakeup`/`CronCreate` (e.g. "EOD I'll send X"). | The schedule itself fires / the due time arrives. `~/.claude/tasks/*` may carry due items if cheaply readable. | Partial — the firing of a `ScheduleWakeup` re-invokes main directly; `wake-priority.sh` does not enumerate future schedules (kept cheap). |

### P2 — idle tick  (relaxed cadence, ~20–30 min)
Nothing higher is pending. **This is the productive default**, not a sleep:
pull **one loop-safe item** from the idle backlog and advance it (see §4). The
loop is a work engine, not a heartbeat (`feedback_always_working`).

> **Cadence is a hint, not a hard schedule.** `wake-priority.sh` prints a
> suggested band (e.g. "P2 → 1200–1800s"); main still self-paces with
> `ScheduleWakeup`. The point is: don't wake every 60s when idle (wasteful), and
> don't sleep 30 min when a daemon just died.

---

## 3. The reporter — `wake-priority.sh`

A **read-only, fail-open** helper main can run on each wake to get the top
pending reason + tier + a suggested cadence, without re-deriving it by hand.

```
$ wake-priority.sh                 # human report
$ wake-priority.sh --quiet         # P<n>\t<reason>\t<lo>-<hi>   (machine form)
$ wake-priority.sh --json          # {priority,tier_exit,reason,detail,cadence_*}
$ wake-priority.sh --consume       # after ingesting result.json, advance the marker
```

**Contract** (mirrors `deadman.sh` / `ops-dashboard.sh`):

- **Read-only.** Touches no daemon. The *only* thing it ever writes is its own
  `~/.claude/state/wake-priority.consumed` marker, and *only* under `--consume`.
  The default report run writes nothing.
- **Exit code encodes the tier** (scriptable without parsing stdout):
  `exit 0 → P2 (idle)`, `exit 1 → P1 (handle-next)`, `exit 2 → P0 (act-now)`.
  Mnemonic: the exit code equals the Pn number.
- **Fail-open.** Any ambiguity, missing input, or error → report **P2/idle**
  (exit 0). It must never *falsely escalate* (which would burn the loop waking
  hot) and never crash the caller.
- **Never prints a secret.** It reads only filenames, mtimes, and the wall clock
  — no secret is ever loaded or echoed. (Verified: all output modes scanned
  clean against the gitleaks secret classes even with `secrets.env` sourced.)
- **Signals it scans** (all cheap + local): `~/.claude/state/deadman/*.alerted`
  (P0); `~/claude/notes/*/result.json` newer than the consumed marker (P1);
  the wall clock vs the paid-work window (P1). Everything else degrades to P2.

It is intentionally **not** wired into any timer or hook — it's a tool the loop
*consults*, so it can't itself cause a wake or a side effect. Test hooks:
`WP_DEADMAN_DIR`, `WP_NOTES_DIR`, `WP_STATE_DIR`, `WP_NOW_EPOCH`, `WP_TZ`.

---

## 4. P2 selection protocol — pulling from the idle backlog

When `wake-priority.sh` reports **P2 (idle)**, the loop does NOT just sleep. It:

1. **Reads `~/claude/notes/idle-backlog.md`** — the structured queue of
   useful-but-not-urgent work (seeded from the initiative + memory + task list).
2. **Picks the highest-value item that is flagged `loop-safe`** *and* fits the
   remaining context/time budget (prefer S/M effort when context is low). A
   `loop-safe` item is one the loop MAY auto-execute under normal discipline.
3. **Executes it under the normal discipline** — Task Complexity Triage → the
   3-tier task hierarchy (initiative/task/steps) → prototype-if-new → verify →
   report. (For an L1-trivial backlog item, the L1 fast-path; for L2+, full
   setup + a worker.) The autonomous-execution policy still applies: self-gate
   destructive ops with backup→verify→proceed; stage anything nuclear.
4. **Logs the outcome and checks the item off / removes it** from
   `idle-backlog.md` so it isn't re-attempted.

### The hard rule — NEVER auto-fire a `human-gated` item
Every backlog entry carries a **`loop-safe` vs `human-gated`** flag.
**`human-gated` items must NEVER be auto-executed by the loop** — they are
surfaced to Toper (in the next standup / loop-digest / aggregate) and wait for
his explicit go. Nuclear / external / destructive / money / external-relationship
work is `human-gated`, no exceptions. Examples currently in the backlog:
the staged `.bashrc` age-cutover + off-machine age-key backup (W5), the W0 key
rotations (his dashboards), the #27 VPS migration (DEFERRED), and the
history-scrub+force-push of the *other* public repos (only chilldawg was
authorized). See `~/claude/notes/idle-backlog.md` for the full, flagged list.

> A `loop-safe` item executed badly is recoverable (it went through triage +
> verify + is reversible). A `human-gated` item auto-fired is the expensive
> mistake — that's the entire reason for the flag.

---

## 5. How the existing signals already feed Toper (so nothing is double-built)

This model rides on top of channels that **already exist** — it adds a lens, not
new plumbing:

- **deadman** (`deadman.sh`, every 3 min, LIVE) → out-of-band **email** on a real
  daemon death (not WhatsApp, since wa-sender may be the dead thing). Also the
  P0 signal `wake-priority.sh` reads.
- **loop-digest** (`loop-digest.sh`, 06:30 WIB, LIVE) → one **WhatsApp** summary
  of overnight decisions / task completions / worker outcomes via the
  session-independent wa-sender queue. The natural place to *surface* any
  `human-gated` backlog items the loop chose not to touch.
- **worker completion** → writes `result.json` + `report.md`; the harness
  re-invokes main; `wake-priority.sh` flags it as P1 until consumed.
- **Toper WhatsApp** → already first-class P0 via `WHATSAPP=1` on main + the
  WhatsApp Channel Discipline rule.
- **ops-dashboard.sh** / **fleetview.sh** → read-only situational awareness main
  can pull at any tier.

---

## 6. Quick reference

| Tier | Trigger | Cadence hint | First action |
|---|---|---|---|
| **P0** | deadman `*.alerted` present · Toper WA (live) · time-critical+irreversible | ≤60s | Investigate the outage NOW (`ops-dashboard.sh`, `systemctl --user status …`) / reply to Toper |
| **P1** | fresh `result.json` · paid-work window (08–11 WIB wkdy) · scheduled commitment due | 1–10 min | Ingest the result + continue the pipeline / be responsive |
| **P2** | nothing higher | 20–30 min | Pull ONE **loop-safe** item from `idle-backlog.md`, execute under triage+3-tier+verify, check it off |

Related: `docs/ARCHITECTURE.md` (the whole system map), `~/claude/notes/idle-backlog.md`
(the P2 queue), memory `feedback_always_working` (the standing rule).
