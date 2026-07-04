---
name: tmux
description: Raw tmux control for Claude Code, orient in the pane tree, read panes safely, send commands with a verified send-and-submit loop, create and clean up windows/panes. The low-level terminal layer BENEATH the worker pipeline; it defers all delegated-worker lifecycle (spawn, brief, resume, monitor, govern) to spawn-worker.sh / brief-worker.sh / resume-worker.sh. Use when you need to run a command in another terminal, read another pane, drive a running REPL by hand, or split a view. Verified against tmux 3.6b.
allowed-tools: Bash, Read
---

# tmux, Raw Terminal Multiplexer Control (tmux 3.6b)

This skill is the RAW tmux layer: orient, read, send-and-verify, create, clean up. It is the
primitive control surface UNDER the delegated-worker pipeline, not a replacement for it. Spawning,
briefing, resuming, and monitoring a DELEGATED worker are owned by the orchestration scripts
(`~/.claude/scripts/spawn-worker.sh`, `brief-worker.sh`, `resume-worker.sh`, `worker-semaphore.sh`,
`fleetview.sh`). See the boundary table in section 7; do not re-teach or hand-roll what those scripts
do reliably.

Every command and flag below is verified against `tmux 3.6b` (`/usr/bin/tmux`). Depth lives in two
references so this file stays whole-loadable:
- `references/tmux-cheatsheet.md`, verified 3.6b flag synopsis per subcommand + a house example each.
- `references/worker-repl-playbook.md`, the worker-REPL failure-mode encyclopedia (dated incidents + memory citations).

---

## 0. FAILING NOW? (jump table)

| Symptom | Cause | Go to |
|---|---|---|
| "I sent Enter but the session/command never started" | paste + submit combined, Escape raced the paste | §4 loop steps 7-8, §8 playbook A |
| Text sits in a worker's `❯` input box, looks like a typed command | Claude Code DIM ghost autosuggestion; `-p` strips the color | §5, HR-6 |
| Worker finished a step and went idle, will not pick up the next task | attn cannot actuate an idle REPL; it queues | §8 playbook D, HR-8 |
| Worker input dead to `send-keys`, even literal `-l 'X'` shows nothing | REPL wedged (process `S`/sleeping) | §8 playbook E, HR-9 |
| A worker at "94%" looks nearly context-full | that meter is REMAINING, and inflated on fresh spawns | §8 meter note, HR-10 |
| Typed `i` to enter insert mode and it corrupted the input | `editorMode:vim` lands the REPL in INSERT already | §5, HR-11 |
| A spawned worker cannot send attn / never reports back | attn-blind hand-rolled spawn (no `ATTN_SESSION`) | §7, HR-7 |
| Almost killed / did kill my own window | did not resolve own `window_id` first | §2, HR-1/HR-2 |
| Two parallel briefs cross-delivered (A got B's brief) | shared default paste buffer raced | §4, HR-4 |
| `claude -p "$(cat brief)"` hung or garbled | special chars broke shell expansion | §7 nugget, HR-12 |

---

## 1. HARD RULES (NEVER / ALWAYS, read before your first command)

Each rule carries the concrete trigger and the verified incident that earned it. Playbooks in §8 and
the encyclopedia in `references/worker-repl-playbook.md` expand each one.

- **HR-1, ORIENT BEFORE ACTING.** Before ANY cross-pane command (`send-keys`, `capture-pane`,
  `kill-window`), run the §2 pre-flight gate: `echo "$TMUX_PANE"`, map with `tmux list-panes -a -F`,
  and confirm your target is NOT your own window. Never send or kill a target you have not identified.
- **HR-2, NEVER kill your own window.** Resolve your own `#{window_id}` from `$TMUX_PANE` first (§2).
  `kill-window` only a target whose `window_id` differs from yours. (Original skill rule, preserved.)
- **HR-3, ALWAYS separate paste from submit for multi-line/long text.** `load-buffer` →
  `paste-buffer -p` → `sleep 2` → SEPARATE `send-keys Enter`. NEVER combine paste + Escape + Enter in
  one `send-keys` call: the Escape races the paste and the prompt sits unsubmitted. (Verified
  2026-04-11: two sessions claimed running, both briefs dangled 25 min, `feedback_tmux_send_keys`.)
- **HR-4, ALWAYS use a UNIQUE named buffer** (`-b <name>`) on BOTH `load-buffer` and `paste-buffer`
  when more than one paste may be in flight. The default buffer races: the second `load-buffer`
  overwrites the first before its paste fires, so worker A receives worker B's brief. (`brief-worker.sh`
  uses `_brief_$$` per invocation for exactly this, verified in source lines 358-366.)
- **HR-5, ALWAYS verify a send LANDED before claiming it ran.** After Enter, `tmux capture-pane -t
  <pane> -p -S -20` and assert the input box no longer shows `[Pasted text` / the footer is no longer
  `-- INSERT --` with the brief in it, and a processing spinner is visible. "I sent Enter" is not
  proof. (Same 2026-04-11 incident.)
- **HR-6, NEVER treat UNSUBMITTED text in a worker's input box as a command.** It is often Claude
  Code's DIM ghost autosuggestion; `capture-pane -p` strips SGR so ghost reads identical to real
  typing. Decisions come ONLY from SUBMITTED output. To inspect intent: `capture-pane -e -p | cat -v`,
  faint `[2m`/`[0;2m` on the input line = ghost. (Verified 2026-06-05, `feedback_worker_pane_ghost_text`.)
- **HR-7, NEVER hand-roll a delegated-worker spawn.** ALWAYS `~/.claude/scripts/spawn-worker.sh
  <window> [cwd]` (it sets `ATTN_SESSION` + `--dangerously-load-development-channels
  plugin:attn@s0nderlabs` + `--remote-control` + `--model`), verify the attn peer, then brief via
  `brief-worker.sh`. A bare `claude --dangerously-skip-permissions` (with or without `--add-dir`) is
  attn-BLIND: no `ATTN_SESSION` means the attn send/peers/reply tools do not register, so the worker
  cannot report back. (Verified 2026-05-01, confirmed by the attn author, `feedback_session_delegation`.)
- **HR-8, NEVER use attn `send` to START or REDIRECT a REPL.** attn is informational; it QUEUES
  between tool calls and cannot actuate an idle or mid-thinking REPL. Drive the REPL with tmux
  (`brief-worker.sh` preferred; clear stale input with `C-u` first), then verify the transition to
  processing via `capture-pane` after ~8-10s. (Verified 2026-05-23 / 2026-06-05 / 2026-06-22,
  `feedback_attn_does_not_interrupt_worker_thinking`, `reference_directing_idle_supervisors_tmux`.)
- **HR-9, NEVER fight a wedged REPL with send-keys variations.** If literal `send-keys -l 'X'`
  produces no echo AND the process is `S` (sleeping), it is wedged. `kill-window` + re-spawn (resume
  from STATE.md via `spawn-worker.sh` / `resume-worker.sh`). Do not burn context on key-combo
  experiments. (Verified 2026-05-22, `feedback_worker_context_freeze_at_90`, `feedback_worker_resume_recovery`.)
- **HR-10, NEVER judge worker health by the `N% (Xk)` meter alone.** It is context REMAINING (higher =
  more headroom) and inflated on fresh spawns (a fresh [1m] worker launches near 93-94%). Judge by
  FUNCTION: is it producing output / running tools? The real stall signals are `5h: NN%` near 100% or
  input-dead + `S`-sleeping. (Verified 2026-06-08, `reference_cc_context_indicator_is_remaining`.)
- **HR-11, NEVER `send-keys 'i'` blindly to "enter insert mode".** `editorMode: vim` is ON
  (`~/.claude/settings.json`, verified) and the Claude Code prompt lands in INSERT already. Read the
  footer (`-- INSERT --` vs `-- NORMAL --`) first; in INSERT, `i` types a literal `i` and corrupts the
  input. (`brief-worker.sh` treats `-- INSERT --` as the READY signal and never sends `i`.)
- **HR-12, NEVER `claude -p "$(cat file)"` via send-keys.** Special characters (quotes, backticks,
  angle brackets, newlines) break shell expansion and the command silently fails or hangs. Launch
  interactive and paste via `load-buffer`/`paste-buffer` (§7). (Preserved nugget, `feedback_tmux_send_keys`.)
- **HR-13, NEVER send-keys a secret into another pane** (it lands in the target's scrollback AND its
  shell history); NEVER echo captured-pane content containing a secret into memory/logs/reports. Use
  `paste-buffer -d` for a brief that contains credentials so the buffer is deleted after paste (§9).
- **HR-14, ANY browser step defers to `/agent-browser`** (the qutebrowser CDP-proxy authority, freshly
  enhanced 2026-07-02). NEVER hand-drive qutebrowser from tmux; NEVER Playwright MCP (globally
  hook-banned). (`feedback_browser_qutebrowser`.)
- **HR-15, ALWAYS clean up windows YOU created; one delegated worker = one window.** Never host
  multiple delegated agents in panes of a single window (§6 explains why it breaks attn identity /
  semaphore / fleetview / polling). Never leave orphan windows.

---

## 2. Orientation, pre-flight gate (run before ANY cross-pane action)

Three commands, ~1s. This is the gate that makes HR-1 and HR-2 mechanical instead of hopeful.

```bash
# (1) Who am I: my pane id, then resolve MY window so I never target it by accident.
echo "$TMUX_PANE"                                                 # e.g. %3
tmux display-message -p -t "$TMUX_PANE" \
  '#{session_name}:#{window_index} #{window_id} #{window_name}'   # e.g. 0:1 @1 main

# (2) The map: every pane on the server (target, pane-id, window-id, window-name, cmd).
tmux list-panes -a -F '#S:#I.#P #D #{window_id} #W #{pane_current_command}'

# (3) Confirm your target's #{window_id} (@N) != YOUR #{window_id} before send/kill.
```

`display-message -p` prints to stdout; `-t "$TMUX_PANE"` resolves your own pane, so the window_id it
prints is the one you must never `kill-window`. Comparing by `window_id` (`@N`, stable) beats
comparing by name (names repeat, indexes renumber).

### Target syntax (what goes after `-t`)

| Form | Means |
|---|---|
| `:N` | window index N in the CURRENT session |
| `main:4` | session `main`, window index 4 |
| `main:4.2` | session `main`, window 4, pane 2 |
| `0:worker-name` | session `0`, window NAMED `worker-name` (the house worker form) |
| `%N` | unique pane id (`#D` / `#{pane_id}`), survives renumbering |
| `@N` | unique window id (`#{window_id}`), survives renumbering |

### House convention

- Main session is `0`. `spawn-worker.sh` defaults `TMUX_SESSION=0` and creates ONE new window per
  worker, so workers are addressed `0:<window-name>` (the window name == the worker's `ATTN_SESSION`
  identity). Verified: `spawn-worker.sh:21` (`TMUX_SESSION="${TMUX_SESSION:-0}"`).
- Prefer the stable id (`%N`/`@N`) over `:index` in any script that outlives a window close: closing a
  window renumbers indexes.

---

## 3. Read, capture-pane recipes

`capture-pane [-aepPqCJMN] [-b buffer-name] [-E end-line] [-S start-line] [-t target-pane]` (alias
`capturep`). `-p` sends to stdout (without it, capture goes to a buffer). `-S`/`-E` line numbers: `0`
= first VISIBLE line, negative = into history, `-` to `-S` = start of history. Full flag table:
`references/tmux-cheatsheet.md`.

```bash
# Visible pane, plain text (SGR stripped, see the ghost-text caveat in §5/HR-6).
tmux capture-pane -t 0:worker -p

# Last 200 lines of history, wrapped lines JOINED (readable long log lines).
tmux capture-pane -t main:4.2 -p -J -S -200        # -J joins wraps + keeps trailing spaces (implies -T)

# Whole scrollback from the start of history.
tmux capture-pane -t 0:worker -p -S -

# WITH escape sequences: the only way to distinguish ghost text from real input (§5).
tmux capture-pane -t 0:worker -e -p | cat -v        # faint [2m / [0;2m on input line = ghost

# Poll snippet used in the 5-min cadence (§8): last 30 lines, tail the live 15.
tmux capture-pane -t 0:worker -p -S -30 | tail -15
```

Read-before-write is a rule (original skill, preserved): always `capture-pane` a target to confirm
its ready-state BEFORE you `send-keys` into it.

---

## 4. The Send-and-Verify Loop (the centerpiece)

Fire-and-forget `send-keys` silently drops briefs and commands. This numbered loop is mandatory for
anything you must know landed. It encodes HR-3, HR-4, HR-5.

**Single-line command** into a shell pane (short, no special chars), one call is fine:

```bash
tmux send-keys -t 0:build 'pnpm test' Enter        # 'Enter' is a KEY NAME, sent as a keypress
sleep 1
tmux capture-pane -t 0:build -p -S -20             # assert the command ran (prompt returned / output)
```

**Multi-line or long text** into a REPL, the 8-step loop:

```bash
# 1. Capture the target's ready-state first (HR-1). REPL should show -- INSERT -- (or bypass footer).
tmux capture-pane -t 0:worker -p -S -10

# 2. If driving a REPL, clear any stale/ghost input line so your text does not append to leftovers.
tmux send-keys -t 0:worker C-u

# 3. Deliver via a UNIQUE named buffer (HR-4). '-' reads the file from stdin.
tmux load-buffer  -b b_worker - < /path/to/brief.md
tmux paste-buffer -p -b b_worker -t 0:worker        # -p = bracketed paste => one [Pasted text #N] event

# 4. Let Claude Code flush the paste into its input buffer.
sleep 2

# 5. Submit: a SEPARATE send-keys call (NEVER combined with the paste, HR-3).
tmux send-keys -t 0:worker Enter

# 6. Let it register the submit and transition to processing.
sleep 3

# 7. VERIFY it committed (HR-5). Bad = '[Pasted text' still in the box / footer still -- INSERT --.
#    Good = spinner verb (Cooking, Harmonizing, Symbioting...) or the token count moved.
tmux capture-pane -t 0:worker -p -S -20

# 8. If still dangling: send Escape then Enter; recheck; up to 3x. Still stuck => brief-worker.sh / respawn.
tmux send-keys -t 0:worker Escape; sleep 0.5; tmux send-keys -t 0:worker Enter; sleep 3
tmux capture-pane -t 0:worker -p -S -20
```

Thresholds are fixed, not vibes: **1s** after a single-line command, **2s** after a paste, **3s**
after a submit, then ASSERT. This is exactly what `brief-worker.sh` automates (verified source: named
buffer → `paste-buffer -p` → `sleep 2` → separate `Enter` → `sleep 3` → verify no `[Pasted text` →
retry Escape+Enter up to 3, lines 365-390). For a FRESH worker, prefer `brief-worker.sh` (§7): it also
handles the trust-folder prompt, the dev-channels prompt, and the role-override preamble. Hand-run
this loop only for a nudge to an ALREADY-RUNNING pane.

> Key-name vs literal: each `send-keys` arg is a key NAME (`Enter`, `C-c`, `C-u`, `Escape`, `NPage`)
> unless unrecognized, then it is sent as literal characters. If a line of literal text could collide
> with a key name (e.g. the bare word `Enter`), force literal with `-l`: `send-keys -l 'Enter'`.
> `send-keys` has NO `-p` flag (that is `paste-buffer`).

---

## 5. Ghost text + vim-mode (editorMode: vim)

Two traps that both live on the REPL input line.

**Ghost text (HR-6).** Claude Code renders inline autosuggestions with the ANSI DIM/faint attribute
(`ESC[2m` / `[0;2m`). `capture-pane -p` (plain) strips ALL SGR, so a dim ghost suggestion becomes
byte-identical to real bright typed input. You cannot tell them apart from a plain capture.

- Primary defense is behavioral: the input box is OFF-LIMITS for decisions. Act only on SUBMITTED
  output (the worker's actual messages) or on Toper-in-main. Do not narrate theories about "stuck
  typing" from a plain capture.
- Technical check when you must inspect intent:
  ```bash
  tmux capture-pane -t 0:worker -e -p | cat -v | tail -5
  # ^[[2m or ^[[0;2m on the input line  => ghost autosuggestion (IGNORE)
  # normal foreground, no faint          => real typed input
  ```
  (2026-06-05: a ghost `next menu: User CMS, analyze it read only` was misread as a real instruction
  and triggered a wrong worker action; a later ghost `author the user cms suites` could have triggered
  UNAUTHORIZED authoring. `feedback_worker_pane_ghost_text`.)

**Vim mode (HR-11).** `editorMode: vim` is set. The prompt lands in INSERT by default. Read the footer
before you type:

- Footer `-- INSERT --` → you are already in insert. Type/paste directly. Do NOT send `i` (it inserts
  a literal `i`). This is the READY signal `brief-worker.sh` waits for.
- Footer `-- NORMAL --` → send `i` (or `a`) ONCE to enter insert, verify the footer flipped, then type.
- Never assume the mode. Capture and read it. The old "send-keys 'i' to enter insert mode" step was
  removed as harmful (it corrupts input whenever the REPL is already in INSERT, which is the default).

---

## 6. Create / split / clean up

```bash
# New window (worker-style: named + explicit cwd). new-window [-abdkPS] [-c dir] [-n name] [-t target]
tmux new-window -t 0 -n scratch -c /home/christopher/claude

# Split the CURRENT window for an operator's OWN side-by-side view (code left, logs right).
tmux split-window -t :1 -h        # -h = left|right split
tmux split-window -t :1 -v        # -v = top/bottom (also the default if neither given)

# Kill ONLY a window you created + confirmed is not yours (HR-2).
tmux kill-window -t 0:scratch
```

**One delegated worker = one window (HR-15).** Do NOT cram multiple delegated agents into panes of a
single window. Each delegated worker needs its OWN window because its identity, monitoring, and
recovery are all per-window:
- `ATTN_SESSION` (its addressable attn peer name) == the window name, one per window.
- `worker-semaphore.sh` counts live worker WINDOWS; panes-in-one-window break the count.
- `fleetview.sh` and the 5-min poll key off `0:<window-name>`; `resume-worker.sh` targets
  `<session>:<window>`. Panes are invisible to all of it.

Splits/panes are for the OPERATOR's own multi-view inside one session (a dev server left, a `curl`
loop right), never for hosting delegated agents. **Cleanup gate before you declare done:** kill every
window you created; leave no orphans. (Original skill rules preserved and sharpened.)

---

## 7. Delegation boundary, this skill vs the worker pipeline

Raw tmux is the layer UNDER the pipeline. Reach for the right tool:

| You want to... | Use | Not |
|---|---|---|
| Orient / read a pane / send-and-verify / create / clean up / split-view | THIS skill (§2-§6) | -- |
| Spawn a DELEGATED worker (attn + model + RC + triage gate + semaphore) | `spawn-worker.sh <window> [cwd] [task_dir]` | a hand-rolled `claude ...` (HR-7) |
| Deliver a brief to a fresh worker (trust-folder + role-override + verify) | `brief-worker.sh <window> <brief>` (`--quick` for L1) | inline `send-keys "..." Enter` |
| Resume a killed/wedged worker from STATE.md | `resume-worker.sh <window> <task_dir> [--with-brief <file>]` | fighting the dead REPL (HR-9) |
| Check capacity / who is live (workers + supervisors) | `worker-semaphore.sh status` | eyeballing `list-windows` |
| Live cockpit of all workers (status, checkpoints, context%, stalls) | `fleetview.sh` (`--watch [secs]`) | manual capture loops |
| Govern triage / 3-tier / concurrency / model policy | the pipeline + `~/.claude/CLAUDE.md` | re-teaching it here |

**The REAL delegated spawn command** (reference only, you call `spawn-worker.sh`, which builds this;
verified `spawn-worker.sh:193`):

```bash
ATTN_SESSION='<window>' claude --model '<WORKER_MODEL>' \
  --dangerously-load-development-channels plugin:attn@s0nderlabs \
  --remote-control '<window>' --dangerously-skip-permissions
```

Every piece is load-bearing: `ATTN_SESSION` registers the send/peers/reply tools (without it the
worker is send-blind); the dev-channels flag force-loads attn; `--remote-control` is mandatory on
every session (Toper's rule); `--model` enforces the Sonnet-floor / Opus-carve-out policy.
`spawn-worker.sh` also gates on `triage.json` (exit 4) and the worker semaphore (exit 5) BEFORE the
window is created, so you never get an orphan window. Do NOT reproduce this by hand.

### Preserved nuggets (correct, re-scoped)

- **`claude -p "$(cat file)"` is banned (HR-12).** Special chars break shell expansion. Launch
  interactive, then paste via the §4 loop.
- **`--add-dir ~/claude` is ONLY for a HAND-LAUNCHED interactive session** whose cwd is some other
  repo and that still needs `~/claude` memory + CLAUDE.md. It is NOT how you spawn a delegated worker
  (that is `spawn-worker.sh`, which defaults cwd to `~/claude` and injects context via the brief
  preamble). Never present `--add-dir` as a worker-spawn recipe.
- **Any browser step → `/agent-browser`** (HR-14). A "test from the next window" pattern hands browser
  control to `/agent-browser` (qutebrowser); it never hand-drives qutebrowser and never uses Playwright.

---

## 8. Worker-health triage + failure playbooks + the 5-min poll

### Triage table (symptom → diagnosis → exact action)

| Pane symptom | Diagnosis | Action |
|---|---|---|
| Footer `-- INSERT --` + `[Pasted text` still in box | brief unsubmitted | re-send `Enter` (§4 step 8); if 3x fails, `brief-worker.sh` |
| DIM/faint text on the input line (`-e` capture) | ghost autosuggestion | IGNORE it (HR-6) |
| Idle at empty `❯` after finishing a step | attn will not start it | `C-u` → `brief-worker.sh` → verify transition (playbook D) |
| `send-keys -l 'X'` echoes nothing + process `S` sleeping | REPL wedged | `kill-window` → respawn from STATE (playbook E) |
| Statusline `5h: ~100%` | 5h rate-limit window near full | wait for the window to roll, or rotate to a fresh worker |
| `N% (Xk)` low AND producing no output over time | genuinely near context limit | let it finish + checkpoint, then respawn |
| No attn peer + no output for 10 min | silent stall | run the 4-step poll below |

### Playbooks (exact recovery). Full incident write-ups: `references/worker-repl-playbook.md`.

**A, "I sent Enter but nothing started."** `capture-pane`. If `[Pasted text` / `-- INSERT --` still
shows the brief: `send-keys Escape` → `send-keys Enter` → recheck. Up to 3x. Still stuck → re-deliver
via `brief-worker.sh`.

**D, "Worker went idle after finishing a step."** It will NOT pick up an attn-queued next task (HR-8).
`tmux send-keys -t 0:<w> C-u` → `brief-worker.sh 0:<w> <nextbrief>` → `capture-pane` after ~8-10s to
confirm it transitioned to processing (the pane looks idle for tens of seconds first, verify late, not
immediately).

**E, "Worker REPL wedged (input dead, `S` sleeping)."** Do NOT keep trying keys (HR-9).
```bash
tmux kill-window -t 0:<w>
~/.claude/scripts/spawn-worker.sh <w>-fresh ~/claude      # or resume-worker.sh <w> <task_dir>
# the fresh worker reads STATE.md (resume protocol) and continues from the Resume cursor,
# zero work lost because checkpoints + commits are on disk.
```

**F, "Worker silent >10 min."** Run the 4-step poll. Common causes: a manual `claude` restart that
lost `ATTN_SESSION` (stale peer, no pings), a VPN drop, a trust-folder prompt waiting for input, a
hung shell. Fix = a proper respawn via `spawn-worker.sh` (re-binds `ATTN_SESSION`).

### The context meter (HR-10)

`N% (Xk)` is context REMAINING, not used. Higher = more headroom. A fresh [1m] worker starts near
93-94% and that is NORMAL, not "bloated". Do NOT kill on the % alone, Toper caught two healthy fresh
workers killed this way. Judge by FUNCTION (producing output / running tools / pinging on attn). The
real limiter is `5h: NN%`.

### The 5-min poll (while ANY worker is alive, `feedback_worker_polling_5min`)

1. attn peer still listed? (`mcp__plugin_attn_attn__peers`), missing = died or lost attn.
2. `tmux capture-pane -t 0:<name> -p -S -30 | tail -15`, spinner / recent output? Or idle `❯`?
3. STATE.md / live-output file mtime advancing? (or use `fleetview.sh`.)
4. Last attn ping age < 10 min? Any stalled → diagnose (idle / VPN / env-loss / wedge) → apply the
   matching playbook. "It pinged STARTING, I'll come back at DONE" is the failure mode: workers fail
   silently; poll until you have SEEN the DONE. Note: a `completed` notification whose message reads
   like "still running / awaiting Monitor" is premature, verify STATE.md before spawning any recovery
   (`feedback_worker_completion_ambiguity`), and never run two workers on one single-threaded resource.

---

## 9. Security + box-safety

**send-keys is command injection into a live shell (HR-1, HR-13).** It types into whatever pane you
target. Never `send-keys` into a pane you have not identified as a legitimate target (§2). Never
`send-keys` a secret: it lands in the target's scrollback AND its shell `history`.

**capture-pane can read another pane's secrets (HR-13).** Never echo captured content that contains a
credential into memory, a report, a log, or attn. If you spot a secret in a capture, reference it by
location + type only ("token on the OPENAI line"), never the value.

**paste-buffer residue (HR-13).** `load-buffer - < brief-with-creds` leaves the credential sitting in
the tmux paste buffer until it is overwritten. For any brief containing secrets, delete it after
paste: `paste-buffer -d -b <buf>` (deletes the buffer after pasting), or `delete-buffer -b <buf>`
afterward.

**Box-safety (memory-bound, not count-bound, `reference_local_box_oom_heavy_workers`).** This box is
~14Gi RAM / 18 logical CPUs / 15Gi swap (verified now). It OOM-kills workers when ~2 heavy Opus builds
run concurrently, the worker-COUNT semaphore does NOT protect against memory. Before spawning heavy
work (a Next build + `pnpm install`, an `/artifex` run, a browser + lumiere fleet):
```bash
free -h        # swap creeping toward full => back off; serialize the heavy phase
```
Serialize heavy builds (one finishes install/compile before the next starts); do not stack a build
fleet on top of a browser fleet. A killed worker resumes from its STATE checkpoints, so
serialize-then-resume loses little. Concurrency governance itself lives in the pipeline scripts, this
is just the `free -h` reflex before you pull the trigger.

---

## 10. Do / Don't quick-ref card

**send-keys**
- DO send `Enter` / `C-c` / `C-u` / `Escape` as separate KEY-NAME args.
- DO use `-l` for arbitrary literal text that could collide with a key name.
- DON'T combine paste + Escape + Enter in one call for long text (HR-3).
- DON'T assume success, capture and assert (HR-5).

**capture-pane**
- DO use `-p` for plain reads, `-J -S -N` for long history, `-e` to distinguish ghost text.
- DON'T drive any decision from unsubmitted input-box text (HR-6).
- DON'T paste captured content containing a secret anywhere (HR-13).

**spawning / briefing**
- DO one worker per window via `spawn-worker.sh` + attn round-trip; brief via `brief-worker.sh`.
- DON'T host multiple delegated agents in panes of one window (HR-15).
- DON'T hand-roll `claude --dangerously-skip-permissions` for delegated work (HR-7).

**recovery**
- DO `kill-window` + respawn-from-STATE for a wedged REPL (HR-9).
- DON'T attn-send to start/redirect an idle or mid-thinking REPL (HR-8).
- DON'T kill a worker on the context % alone (HR-10).

---

## References

- `references/tmux-cheatsheet.md`, verified tmux 3.6b synopsis for every subcommand this skill uses,
  each with the man flag set + a one-line house example. Reach for it when you need a flag detail.
- `references/worker-repl-playbook.md`, the worker-REPL failure-mode encyclopedia: each dated incident
  (symptom, what was tried, root cause, exact recovery) with its memory citation. The war stories
  behind the HARD RULES.

Composes with: `/agent-browser` (all browser steps, HR-14), the worker pipeline scripts (§7), and the
triage / 3-tier / model-policy rules in `~/.claude/CLAUDE.md` (cited, not duplicated).
