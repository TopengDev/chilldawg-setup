# Worker-REPL failure-mode encyclopedia

The war stories behind the SKILL.md HARD RULES. Each entry: the verified incident (date + memory
citation), the symptom, what was tried, the root cause, and the exact recovery. These are
point-in-time observations promoted to rules; the VERIFIED-NOW tmux flags + the `spawn-worker.sh:193`
command in SKILL.md are the ground truth, these incidents are the provenance. When a rule feels like
overhead, read the incident that earned it.

Cross-refs point at `~/.claude/memory/<file>.md`.

---

## A. Delivery: paste-then-submit, and the parallel-buffer race

### A1. Two sessions "running", both briefs dangled 25 min (2026-04-11) / `feedback_tmux_send_keys`
- **Symptom.** `pulseguides` + `orcadesign` spawned back-to-back, reported to Toper as running. 25 min
  later he asked for progress; a `capture-pane` showed both briefs STILL sitting unsubmitted in the
  input box. Both sessions had been idle the whole time. Main had unknowingly lied about status twice.
- **Tried.** `tmux send-keys ... Escape && tmux send-keys ... Enter` chained in one shot, no sleeps,
  no post-submit capture.
- **Root cause.** Claude Code is in INSERT mode; when a long paste and Escape+Enter arrive together the
  Escape RACES the paste, fires before the paste completes, and the prompt is never submitted.
- **Recovery / rule (HR-3, HR-5).** Separate the phases with sleeps and VERIFY: `load-buffer` →
  `paste-buffer -p` → `sleep 2` → SEPARATE `send-keys Enter` → `sleep 3` → `capture-pane` and assert
  the footer left `-- INSERT --` (spinner verb visible, no `[Pasted text` in the box). Never claim a
  session is running until you have SEEN the footer change in a post-submit capture.

### A2. Parallel spawns cross-deliver briefs / `feedback_brief_worker_helper`, `brief-worker.sh:358-366`
- **Symptom.** Two workers spawned in parallel; worker A received worker B's brief.
- **Root cause.** Both `load-buffer`d into the DEFAULT buffer. The second load overwrote the first
  before its `paste-buffer` fired.
- **Recovery / rule (HR-4).** Use a UNIQUE named buffer on BOTH ends: `load-buffer -b <uniq> ...` +
  `paste-buffer -p -b <uniq> ...`. `brief-worker.sh` names it `_brief_$$` (per-invocation PID) and
  deletes it on exit. Prefer `brief-worker.sh` for fresh workers; it also handles the trust-folder +
  dev-channels prompts and prepends the role-override preamble.

---

## B. Reading: ghost text is not input

### B1. A dim autosuggestion misread as a real command (2026-06-05) / `feedback_worker_pane_ghost_text`
- **Symptom.** A worker pane's input line read `next menu: User CMS, analyze it read only`. Main
  assumed it was Toper's stuck/unsubmitted typing, built a confident-but-WRONG "your Enter isn't
  flushing" theory, and triggered a worker analysis off it. Toper had typed nothing.
- **Root cause.** Claude Code renders inline autosuggestions (ghost text) with the ANSI DIM/faint
  attribute (`ESC[2m` / `[0;2m`). `capture-pane -p` (plain) strips ALL SGR, so the dim ghost became
  byte-identical to real bright typed input. There was no "stuck input" bug; it was fabricated from a
  stripped-color capture. A later ghost `author the user cms suites` could have triggered UNAUTHORIZED
  authoring under the same bad habit.
- **Recovery / rule (HR-6).** The input box is OFF-LIMITS for decisions; act only on SUBMITTED output
  or Toper-in-main. If you must inspect intent, capture WITH escapes: `tmux capture-pane -t <p> -e -p
  | cat -v` and look for faint `[2m` / `[0;2m` on the input line = ghost (ignore); normal foreground,
  no faint = real. To give an idle worker a task, deliver a proper brief via `brief-worker.sh` after
  `C-u`, never by submitting whatever sits in its input.

---

## C. Actuation: attn cannot drive a REPL

### C1. Override pings ignored mid-build (2026-05-23) / `feedback_attn_does_not_interrupt_worker_thinking`
- **Symptom.** `pulse-landing-redesign` worker pinged for a decision (English-only vs bilingual). Main
  replied OPTION B (bilingual) via attn three times over 30 min. The worker built the entire landing
  English-only and, post-completion, said "you never replied B, so went A."
- **Root cause.** attn messages QUEUE and are only processed BETWEEN tool calls. A worker in a long
  batch tool-call cycle (building N sections) never emerges to see them. From its POV the pings did
  not exist mid-flow.
- **Rule.** Put every known decision branch in the INITIAL brief. Do not rely on attn mid-flow to
  redirect. If a decision might change, the brief must say "PAUSE and ping before X". Model workers as
  fire-and-forget batch processors, not real-time agents.

### C2. attn cannot START an idle worker (2026-06-05, `fc-fix195`) / same memory
- **Symptom.** Worker finished task 1, checkpointed, went idle at the prompt. Main sent the next task
  via attn `send` (got "Message sent to local session"). Worker sat idle ~6 min until Toper caught it.
- **Root cause.** attn is informational, not an actuator. The message queued; nothing drove the idle
  REPL to read + act on it.
- **Recovery / rule (HR-8).** `tmux send-keys -t <win> C-u` (clear stale input) → `brief-worker.sh
  <win> <brieffile>` → the worker immediately transitioned to processing. Then VERIFY via
  `capture-pane`. attn is fine for informational pings the worker reads on its own next cycle; it
  cannot start work on an idle/waiting worker.

### C3. Idle supervisor would not wake on attn (2026-06-22, atlas) / `reference_directing_idle_supervisors_tmux`
- **Symptom.** The atlas supervisor, IDLE waiting on a decision, ignored `attn send` ~3x; it sat at
  its prompt with the message queued.
- **Root cause.** Same class as C2: a BUSY session processes attn between turns fine, an IDLE one
  often will not.
- **Recovery / rule.** Reliable delivery to an idle session is a SHORT tmux nudge (~1-2 sentences; a
  ~600-char single-line `send-keys -l` collapses to "paste again to expand" and does NOT submit).
  Clear ghost text first with `C-u`. The pane looks idle right after you submit and only starts
  processing after ~tens of seconds, so VERIFY by re-capturing after ~8-10s (or check it spawned the
  expected child / STATE.md moved), NOT the immediate capture. Best combined pattern: full directive
  in `attn send` (clean, in the inbox) + a short tmux nudge "read your attn inbox + execute now".

---

## D. Health + recovery: wedge, meter, resume, completion

### D1. Wedged REPL, input dead (2026-05-22, `fitest-phase-a4-closemodal`) / `feedback_worker_context_freeze_at_90`
- **Symptom.** Worker idled with a typed-but-unsubmitted prompt at ~92% meter. Nothing submitted it.
- **Tried (all failed).** `send-keys ... Enter`; `send-keys ... C-m`; `send-keys -l "X"` (literal, X
  never appeared); `select-window` + send-keys; direct `echo > /dev/pts/N`. Process introspection:
  claude alive but `S` (sleeping on epoll), PTY intact, no pending signals. 30+ min, not transient.
- **Root cause.** At/near the autocompact threshold the REPL's input handler wedges in a race where
  the compact never triggers. A real wedge (rare) versus the far-more-common meter misread (D2).
- **Recovery / rule (HR-9).** Do NOT experiment with key combos. Confirm the wedge by two signals
  together: literal `send-keys -l 'X'` produces no echo AND `ps` shows the claude process `S`
  sleeping. Then `tmux kill-window -t 0:<w>` → re-spawn (D3).

### D2. Fresh worker at "94%" killed as "context-maxed" (2026-06-08) / `reference_cc_context_indicator_is_remaining`
- **Symptom.** A freshly-spawned worker showed "92-94% (~930k)". Main read it as nearly-full → frozen,
  killed it, and paused the workstream. Toper corrected it.
- **Root cause.** The `N% (Xk)` meter is context REMAINING, not used (higher = more headroom). A fresh
  [1m] worker launches near the top; the % on fresh spawns is inflated/unreliable. The "94%" worker
  was actively reading STATE.md, running `ls`, sending attn-hello, fully FUNCTIONAL.
- **Rule (HR-10).** NEVER kill on the % alone. Judge by FUNCTION (producing output / running tools /
  pinging). The real constraint is `5h: NN%` (the 5-hour rate window); when THAT nears 100%,
  generation throttles/stops. Distinguish D1 (genuine wedge: no output over time + input dead + `S`)
  from D2 (healthy fresh worker with a high meter).

### D3. Re-spawn from STATE beats fighting the REPL (2026-06-16) / `feedback_worker_resume_recovery`
- **Symptom.** Overnight 5h-limit + wedged-input workers during the attn-agnostic-client build.
- **Root cause.** Raw `send-keys` nudges are flaky on the REPL: Enter often does not submit (treated
  as a newline), and repeated attempts ACCUMULATE unsent text across `❯` lines until the buffer
  wedges. Limit-blocked workers do NOT auto-resume after the budget resets; they sit idle with a stale
  statusline.
- **Recovery / rule.** For a wedged/limit-blocked worker WHOSE PROGRESS IS COMMITTED:
  ```bash
  tmux kill-window -t 0:<w>
  ~/.claude/scripts/spawn-worker.sh <w>-fresh ~/claude   # same cwd
  # or, if the task dir + STATE.md exist:
  ~/.claude/scripts/resume-worker.sh <w> <task_dir> [--with-brief <orig_brief>]
  ```
  The fresh worker reads STATE.md (resume protocol), trusts `[x]` checkpoints, re-verifies the last
  one, and continues from the Resume cursor. Zero work lost because checkpoints + commits are on disk.
  (`resume-worker.sh` may exit 1 on an already-wedged window; re-spawn instead.) Parallel workers on
  the SAME repo must be git-worktree-isolated (`git worktree add ../<repo>-<slug> -b <branch> <base>`).

### D4. Premature "completed" spawned a duplicate (2026-06-12, `apprsys-refine`) / `feedback_worker_completion_ambiguity`
- **Symptom.** A background worker emitted a `completed` notification whose message read "Still
  running. I'll await the Monitor event." Main misread it as a bail and spawned a recovery worker on
  the SAME fitest suites. Both hit the single-worker fitest runner concurrently → runner contention →
  false-RED runs.
- **Rule.** On an ambiguous "completed-but-incomplete-message" notification, do NOT immediately spawn a
  recovery/duplicate. First READ the worker's STATE.md + result.json + the live target state. If
  unclear, WAIT for a clearer signal. NEVER run two workers against one single-threaded resource.

---

## E. Spawn identity: attn-blind spawns are invisible

### E1. attn-blind "quick task" could not report back (2026-04-11 og-fix; 2026-04-15 x3) / `feedback_session_delegation`
- **Symptom.** Sessions spawned as "quick 1-line fixes" completed but could not report back; Toper had
  to ASK for progress every time. Across pulse-bridge-apk + auto-barcode + daily-brief, ZERO of three
  reported autonomously.
- **Root cause.** Spawned via a bare `claude --dangerously-skip-permissions` (or with the dev-channels
  flag but no `ATTN_SESSION`). Without `ATTN_SESSION` the attn plugin's per-session identity does not
  register the write tools (`send`/`peers`/`reply`), so the worker is silently SEND-BLIND (receive
  still works, which masks it). Confirmed by the attn author (elpabl0, s0nderlabs) 2026-05-01.
- **Recovery / rule (HR-7).** ALWAYS spawn via `spawn-worker.sh` (it builds the full
  `spawn-worker.sh:193` command with `ATTN_SESSION` + dev-channels + `--remote-control` + `--model`),
  then VERIFY the peer with `mcp__plugin_attn_attn__peers` BEFORE briefing. No "quick task" exemption.

### E2. "1 MCP server failed" hand-rolled spawn (2026-05-13, BRI F3B) / same memory
- **Symptom.** Worker A spawned with `tmux new-window + claude --dangerously-skip-permissions + send
  brief`, skipping the peer-verify step. Boot showed "1 MCP server failed" (attn failed to register).
  Worker had to be hand-driven via `send-keys` for 1h45m: no async ack, no proactive pings.
- **Rule.** There is a race at MCP startup where attn can silently fail to register; the belt-and-
  suspenders is the explicit `--dangerously-load-development-channels plugin:attn@s0nderlabs` flag PLUS
  the polling peer-verify. Do not proceed without a confirmed peer.

### E3. Worker refused the brief thinking it was main (2026-05-08, `fitest-rerun`) / `feedback_worker_role_clarity`
- **Symptom.** Worker spawned in `~/claude` auto-loaded the global CLAUDE.md, read "Main session is
  DISCUSSION ONLY", and refused: "this brief is misrouted, main is discussion-only."
- **Root cause.** cwd `~/claude` auto-loads the discussion-only rule; the worker applied it to itself.
- **Recovery / rule.** `brief-worker.sh` prepends a role-override preamble ("you are worker <NAME>, not
  main; that rule does not apply to you"). If you see the refusal signature, clarify role + tell it to
  proceed. This is another reason to brief via `brief-worker.sh`, not raw `send-keys`.

### E4. Manual restart lost ATTN_SESSION + VPN drop = silent stall (2026-05-21) / `feedback_worker_polling_5min`
- **Symptom.** `fitest-neg-flip-exec` was manually `claude`-restarted after a context drop. Old PID
  lingered in the attn peers list (stale); the new session had no attn binding and sent no pings. In
  parallel Netbird VPN expired and the worker correctly halted, but no signal reached main. Toper had
  to flag "workers idling."
- **Root cause.** A manual restart loses the `ATTN_SESSION` env that `spawn-worker.sh` sets at launch.
  attn-ping silence != progress.
- **Recovery / rule.** Poll every live worker every 5 min (the 4-step poll in SKILL.md §8). To restart
  a worker, respawn PROPERLY via `spawn-worker.sh` so `ATTN_SESSION` is re-bound; never a bare manual
  `claude`.

---

## F. Box safety: memory, not count

### F1. Two heavy Opus builds OOM-killed (2026-06-22) / `reference_local_box_oom_heavy_workers`
- **Symptom.** The AURA `next build` + `pnpm install` (Opus) and the `/artifex` design worker (Opus),
  running alongside the atlas browser re-capture + main, drove swap to ~10Gi; the kernel OOM-killed the
  two newest heavy procs. main / atlas / supervisor survived.
- **Root cause.** The worker-COUNT semaphore (`CHILLDAWG_MAX_WORKERS`) does NOT bound MEMORY. 2-3 heavy
  workers can OOM the ~14Gi box while well under the count cap. "Heavy" = Node/Next build + npm/pnpm
  install, an `/artifex` run, a browser + lumiere (ffmpeg) fleet.
- **Rule (SKILL.md §9).** Check `free -h` before spawning heavy work; swap creeping toward full → back
  off. Serialize heavy builds (one finishes install/compile before the next starts). Do not stack a
  build fleet on a browser fleet. A killed worker resumes from STATE checkpoints (install-done →
  lighter on resume), so serialize-then-resume loses little.

---

## Quick index (incident → rule)

| Incident | Date | Rule |
|---|---|---|
| A1 unsubmitted brief | 2026-04-11 | HR-3, HR-5 |
| A2 parallel buffer race | (source) | HR-4 |
| B1 ghost text misread | 2026-06-05 | HR-6 |
| C1 attn ignored mid-build | 2026-05-23 | HR-8 |
| C2 attn cannot start idle worker | 2026-06-05 | HR-8 |
| C3 idle supervisor + tmux nudge | 2026-06-22 | HR-8 |
| D1 wedged REPL | 2026-05-22 | HR-9 |
| D2 meter misread | 2026-06-08 | HR-10 |
| D3 resume from STATE | 2026-06-16 | HR-9 |
| D4 premature completion | 2026-06-12 | §8 poll |
| E1/E2 attn-blind spawn | 2026-04-11/05-13 | HR-7 |
| E3 role-clarity refusal | 2026-05-08 | HR-7 (brief-worker.sh) |
| E4 lost ATTN_SESSION | 2026-05-21 | §8 poll |
| F1 box OOM | 2026-06-22 | §9 box-safety |
