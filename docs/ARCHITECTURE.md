# Architecture — chilldawg-setup

The single source-of-truth for how this machine's AI-augmented dev environment is
wired. Read this if you want to understand *what exists and why* before changing
anything. A future reader (or a fresh Claude) should be able to reconstruct the
whole system from this one document.

> **Honesty contract.** Every enumerable claim here (timers, scripts, hooks,
> skills) is regenerated from disk by `claude/scripts/gen-architecture-inventory.sh`
> and lives in the **AUTO-GENERATED INVENTORY** block near the end — do not trust a
> hand-typed count over that block. This doc is the *map*; `setup-doctor.sh` is the
> *verifier* (it asserts what the repo declares is actually live), and
> `settings-drift.sh` checks the one config file that can silently diverge.
> States are labelled **LIVE** / **STAGED** / **DEFERRED** so nothing reads as
> shipped when it isn't.

---

## 1. Big picture

This repo backs three layered concerns at once:

1. **Shell environment** — bash, tmux, terminal emulators (kitty/wezterm), prompt (oh-my-posh), the TUI utility set (lazygit, btop, etc.).
2. **Editor + tooling** — nvim (its own sibling repo, see [§17](#17-external-configs)), qutebrowser (+ a CDP proxy), the various CLI tools.
3. **Claude Code configuration** — global instructions, an auto-indexed memory store, ~40 custom skills, hooks, two custom MCP servers, a worker-orchestration pipeline, and a fleet of systemd `--user` timers that run autonomous jobs.

These compose into an environment where the human (Christopher / "Toper") and Claude Code work in tight collaboration, including **fully autonomous overnight operation** (timers wake Claude, workers get spawned, results get reported back over WhatsApp). The dotfiles repo is the source of truth; `$HOME` is largely a **symlink farm** pointing back into here.

```
chilldawg-setup/
├── claude/        ← mirrors ~/.claude/   (CLAUDE.md, skills, scripts, hooks, MCP servers, settings.json*)
├── shell/         ← mirrors ~           (.bashrc, .bash_profile, .tmux.conf, .gitconfig)
├── config/        ← mirrors ~/.config/  (terminal emulators, TUI tools, git hooks, systemd units)
├── local/bin/     ← mirrors ~/.local/bin/
├── docs/          ← ARCHITECTURE.md (this), ONBOARDING.md, SECRETS.md
└── install.sh     ← symlinks everything into $HOME (idempotent, backs up to *.pre-stow)
```

The naming collapses "what kind of thing" into a top-level directory: Claude-related → `claude/`, shell rc → `shell/`, `~/.config/<tool>/` → `config/<tool>/`, custom scripts → `local/bin/`.

---

## 2. The symlink farm — and the ONE file that isn't

`install.sh` walks each section and **symlinks** the repo file to its `$HOME` location, backing up any pre-existing real file to `<file>.pre-stow` first. Because the live paths are symlinks *into* the repo, editing `~/.claude/skills/foo/SKILL.md` edits the repo copy directly — there is no "copy back" step and these paths **cannot drift**.

| `~/.claude/` path | Backing | Drift-able? |
|---|---|---|
| `CLAUDE.md` | symlink → repo | no |
| `skills/` | symlink → repo | no |
| `scripts/` | symlink → repo | no |
| `hooks/` | symlink → repo | no |
| `memory/` | symlink → repo (dir), **contents gitignored** + in a *separate private repo* | n/a (see [§8](#8-memory-architecture)) |
| `statusline.sh` | symlink → repo | no |
| **`settings.json`** | **REAL FILE — copied, not linked** | **YES — the sole config drift surface** |

**Why `settings.json` is special.** Claude Code rewrites `settings.json` live (model selection, plugin-auth state, channel state). A symlink would push that churn back into the repo, and a stale committed copy would clobber live edits on the next `install.sh`. So `install.sh` (lines 131-141) **copies** it only if absent and otherwise leaves it alone — "re-sync manually". The cost: `~/.claude/settings.json` and `claude/settings.json` can silently diverge, and the highest-value divergence is a **hook present live but missing from the repo** (the classic "works on my machine, broken after a fresh install"). That exact risk is what `settings-drift.sh` solves — see [§7](#7-hooks) and [§16](#16-machine-checkable-inventory).

> **Activation caveat (applies to all settings/hook changes):** hooks + settings load only at Claude Code **startup**. A change on disk is *not active* in a running session until you restart. No script can introspect a running session's loaded config — tooling here is honest about that and just emits the standing reminder.

---

## 3. Secrets architecture

**Hard rule: no secret values in this repo. Ever.** (Enforced by a global pre-push gitleaks hook — see [§9](#9-the-hooks-on-disk-git-hooks).)

**Today (LIVE):**
1. `~/.claude/secrets.env` — a `chmod 600` file **outside** the repo, gitignored even if accidentally placed inside. Holds the real credential **values** (~56 env vars: Anthropic, Cloudflare, VPS, GitHub, nanobanana, ISI/fitest work logins, Pulse test creds, and more). `.env.example` ships the **names** with empty values as the onboarding template.
2. `~/.bashrc` ends with `[ -f ~/.claude/secrets.env ] && source ~/.claude/secrets.env`, so every interactive shell — and every bash block a skill runs — gets the vars for free. Skills reference `$VAR_NAME`, never literals.
3. Files that ever held literal secrets were rewritten to `$VAR` references; `claude/memory/` is gitignored entirely (private repo, see §8).

**Staged (W5 — built + verified, NOT cut over):** an **age-at-rest** path encrypts `secrets.env` → `secrets.env.enc` (whole-file age; `~/.config/age/keys.txt` is the machine-local key). `load-secrets.sh` decrypts-and-sources in-memory (no plaintext to disk, fail-open so a broken setup can't lock you out of new shells), and `verify-secrets-parity.sh` proves the encrypted path yields byte-identical vars **without printing any value**. The `.bashrc` cutover is left for a supervised flip. **Full detail + threat model + rollback: [`docs/SECRETS.md`](./SECRETS.md)** — not duplicated here.

Net: the repo can be public, forked, or pasted into a chat and **no credential leaks** — a leak would require `secrets.env` itself escaping the machine or someone re-introducing a literal to a tracked file (gitignore + the pre-push scanner catch the latter).

---

## 4. Claude Code integration map

`~/.claude/` is where Claude Code reads everything. What this repo manages there:

| Path | Purpose | In repo? |
|------|---------|----------|
| `CLAUDE.md` | Global instructions loaded into every conversation (the behavioral OS) | ✓ symlink |
| `settings.json` | Plugins, hooks, env, model, channels | ✗ **copied, re-sync manually** |
| `settings.local.json` | Per-machine permission allowlist | ✗ gitignored |
| `statusline.sh` | Custom status line | ✓ symlink |
| `skills/` | ~40 custom skills | ✓ symlink |
| `scripts/` | Orchestration + memory + ops pipeline (25 scripts + workflows) | ✓ symlink |
| `hooks/` | Hook scripts (triage gate, commit guard, oneshot injector, lint) | ✓ symlink |
| `memory/` | Live long-term memory `.md` files (auto-loaded via `autoMemoryDirectory`) | ◐ dir symlinked; contents in **separate private repo** |
| `email-mcp/` | Custom MCP server source (Outlook + Hostinger IMAP/SMTP) | ✓ per-file symlinks |
| `whatsapp-mcp/` | Custom MCP server source (Baileys-based) | ✓ per-file symlinks |
| `tasks/` | Live `/tasks` data (per-machine) | ✗ repo ships a template only |
| `secrets.env[.enc]` | Real credentials (+ staged encrypted form) | ✗ chmod 600, gitignored |
| `projects/`, `sessions/`, `cache/`, `plugins/`, `history.jsonl`, … | Runtime state | ✗ gitignored |

`settings.json` essentials: `effortLevel: xhigh`, `autoMemoryDirectory: ~/.claude/memory`, `channelsEnabled: true` (attn + whatsapp), `skipDangerousModePermissionPrompt: true`, 8 enabled plugins (ralph-loop, gopls-lsp, context7, ui-ux-pro-max, playwright, attn, whatsapp, nativ), and the hooks block ([§7](#7-hooks)).

---

## 5. The skills layer (40 skills)

Skills are directories under `claude/skills/`, each with a `SKILL.md` entry point that Claude loads as an on-demand procedure. Some are one-shot (`/commit`); some are multi-step orchestrations (`/ship` = simplify → security → test → version → commit → preflight → push). Grouped by domain:

- **Dev pipeline:** `commit`, `preflight`, `ship`, `e2e`, `verify`*, `project-init`, `next-best-practices`, `vercel-react-best-practices`, `tailwind-design-system`.
- **QA / testing:** `qa`, `audit`, `ui-test`, `e2e`. (fitest authoring lives in memory + briefs, not a skill.)
- **Creative / design:** `creative`, `frontend-design`, `canvas-design`, `lumiere` (video perception), `ui-ux-pro-max` (plugin).
- **Deploy / infra:** `deploy-landing`, `oneshot-webapp`, `cloudflare-dns`.
- **Comms / ops:** `whatsapp`, `agent-browser`, `tmux`, `daily-brief`, `standup`, `remindme`.
- **Client engagement:** `proposal`, `invoice`, `handover`, `status-report`, `worklog`, `outreach`, `case-study`.
- **Content / strategy:** `content-strategy`, `launch-strategy`, `ideate`.
- **Memory / self:** `remember`, `journal`, `retro`, `wa-behavior-learn`, `tasks`.

*(`verify` ships via a plugin/marketplace, not the repo skills dir.)*

**Recent churn (W4, 2026-06-11):** added 5 — `case-study`, `outreach`, `standup`, `retro`, `worklog`; **retired** `web-design-guidelines` (a redundant WebFetch-only shell). `skill-eval.sh` structurally validates every skill (CI-able). The authoritative count + list is regenerable via the inventory generator ([§16](#16-machine-checkable-inventory)).

---

## 6. The scripts layer (`claude/scripts/`)

The operational backbone — 25 scripts + a workflow library. Functional groups (one-liners are in the inventory block):

- **Worker orchestration:** `spawn-worker.sh`, `brief-worker.sh`, `resume-worker.sh`, `worker-semaphore.sh`, `check-triage.sh`, `result-schema.sh`, `fleetview.sh`, `scaffold-workflow.sh` + `workflows/` (see [§10](#10-orchestration-the-autonomous-loop)).
- **Memory:** `gen-memory-index.py`, `journal-audit.py`, `journal-add.sh`, `memory-decay.py`, `memory-autopush.sh`, `memory-write-validate.sh` (see [§8](#8-memory-architecture)).
- **Ops / health:** `setup-doctor.sh`, `ops-dashboard.sh`, `deadman.sh`, `lib-email-alert.py`, `loop-digest.sh`, `settings-drift.sh`, `gen-architecture-inventory.sh`.
- **Secrets (staged):** `load-secrets.sh`, `verify-secrets-parity.sh`.
- **Integrations:** `signal-trader-bridge.sh` (VPS→local notif relay), `lumiere.py` (video), `skill-eval.sh`.

Convention: each script's header carries a `name — one-line purpose`; they're dependency-light (bash + jq/python3) and the ops/audit ones are strictly **read-only + side-effect-free**.

---

## 7. Hooks

Hooks fire on Claude Code events and are registered in `settings.json` (`.hooks.<EVENT>[].hooks[].command`). The full live table is in the inventory block; what each one does:

| Event | Hook | Gate |
|---|---|---|
| `PreToolUse(Bash)` | `triage-gate-hook.sh` | Backstops the triage gate — refuses a `spawn-worker.sh` call with no valid `triage.json` (fail-open in the hook; fail-closed in the script). |
| `PreToolUse(Bash)` | `block-raw-git-commit.sh` | Blocks raw `git commit` that didn't come from `/commit` (or `CLAUDE_COMMIT_SKILL=1`) — enforces conventional messages everywhere. |
| `PreToolUse(mcp__…playwright…)` | inline `echo` deny | Hard-bans Playwright/Chrome; points to `/agent-browser` + qutebrowser. |
| `PostToolUse(Edit\|Write)` | `lint-check.sh` | Runs a linter on edited files. |
| `PostToolUse(Edit\|Write)` | `memory-write-validate.sh` | On memory-dir writes only: validates frontmatter, scans for literal secrets/PII, debounced index regen. **Fail-open — never blocks** (and PostToolUse can't block the write anyway). |
| `UserPromptSubmit` | `oneshot-webapp-rules-hook.sh` | Injects the `/oneshot-webapp` non-negotiables when that skill is invoked. |
| `PreCompact` | inline `echo` | Reminds Claude to `/remember review` before context is compacted. |

> Hook + settings changes need a **Claude Code restart** to activate (the W2 `memory-write-validate` hook, for instance, is wired in `settings.json` but only takes effect on next start). `settings-drift.sh` flags a hook that's live-but-not-in-repo (the high-value signal) and vice-versa.

---

## 8. Memory architecture

**Auto-indexed flat files, in a separate private git repo.** (Embeddings/vector DB were considered and parked — see the setup-overhaul initiative.)

- **Where it lives:** physically in `claude/memory/` inside this repo, exposed as `~/.claude/memory` via symlink (Claude's `autoMemoryDirectory`). But the **contents are gitignored from chilldawg-setup** and instead version-controlled in a **separate PRIVATE repo `github.com/TopengDev/claude-memory`** — so private operational context never enters the public dotfiles repo. ~180 `.md` files today.
- **How it's loaded:** `MEMORY.md` is an auto-generated index (one line per file, grouped User/Feedback/Projects/References/WhatsApp-Styles). Claude loads the index + pulls individual files by relevance. There is a **~24 KB loader cap** on the index — `gen-memory-index.py` renders to temp and asserts (0 orphans, 0 dangling links, size < cap) before atomic replace, so the chronic "index too big, partial load" failure is gone.
- **Write path:** memory files are written directly (by `/remember`, `wa-behavior-learn`, workers, or by hand). The `memory-write-validate.sh` PostToolUse hook validates frontmatter + scans for leaked secrets on each write and triggers a debounced index regen.
- **Consolidation:** `journal-add.sh` appends to an append-only `journal.md`; `journal-audit.py` (daily timer) promotes state-bearing journal entries to canonical memory files AND runs an **orphan safety-net** (re-indexes any memory file not yet linked in MEMORY.md, so an un-indexed file can never silently drop from the loader).
- **Decay:** `memory-decay.py` (weekly timer) conservatively **archives, never deletes** clearly-stale files (old session-state snapshots, self-declared-superseded), with multiple guards (no inbound wikilinks, age ≥ 21d, user_/feedback_ exempt). Moves to `archive/` + a `DECAY_LOG.md`; fully reversible via git history.
- **Durability:** `memory-autopush.sh` (every 30 min timer) commits + pushes the live memory dir to the private remote. The pre-push gitleaks hook scans it too.

---

## 9. The hooks-on-disk + git hooks

- **Claude hook scripts** live in `claude/hooks/` (symlinked to `~/.claude/hooks/`): `triage-gate-hook.sh`, `block-raw-git-commit.sh`, `oneshot-webapp-rules-hook.sh`, `lint-check.sh`. Portable bash, no secrets, no machine-specific paths.
- **Global git pre-push hook (LIVE):** `config/git/hooks/` (wired via `core.hooksPath = ~/.config/git/hooks` in the committed `.gitconfig`) runs **gitleaks** with a custom TOML that adds Anthropic `sk-ant-` rules the stock 8.21.x ruleset lacks. It scans every push across **all** repos on the machine, fails the push on a leak, and **fails-open with a warning if gitleaks is absent** (so a fresh machine isn't bricked before the tool lands). `--no-verify` is the only bypass and is forbidden by policy.

---

## 10. Orchestration & the autonomous loop

The defining capability: Claude delegates real work to **spawned worker sessions** under a disciplined contract, and runs **autonomously** on a schedule.

### 10a. The 3-tier task hierarchy + triage
Every delegated task is classified by a **triage** level (L1 trivial / L2 standard / L3 major) recorded in a `triage.json`, and structured as:
- **Tier 1 — Initiative** (`~/claude/notes/initiatives/<slug>.md`): the multi-day project.
- **Tier 2 — Task** (a `~/claude/notes/<slug>-<date>/` dir with `brief.md` + `STATE.md` + `report.md` + `result.json`): one worker delegation.
- **Tier 3 — Steps**: the worker's internal checkpoints, captured in `STATE.md` only.

`check-triage.sh` + the `triage-gate-hook.sh` **mechanically refuse** a spawn without a valid `triage.json` (and an L3 without `signoff: true`).

### 10b. Spawn → brief → STATE → resume contract
- `spawn-worker.sh` opens a tmux window, force-loads the **attn** plugin (so the worker can report back), and is gated by both the triage check and a **concurrency semaphore** (`worker-semaphore.sh`, `CHILLDAWG_MAX_WORKERS` default 4 — sized to the 4-vCPU box, fail-open).
- `brief-worker.sh` delivers the brief, injecting a **role-override preamble** that orders the worker to maintain `STATE.md` as a **resumable checkpoint journal** (flip `[x]` only after verifying an effect landed; keep a Resume cursor) and to write `result.json` (machine-readable outcome) + `report.md` on completion. It also warns on any literal secret in the outgoing brief.
- `resume-worker.sh` re-briefs a worker that died / hit the session limit, pointing it at its `STATE.md` Resume cursor so it continues from the last verified checkpoint instead of redoing work.
- `fleetview.sh` is a read-only cockpit of all live workers (status, checkpoint progress, staleness, context% remaining, capacity). `result-schema.sh` validates the `result.json` contract.
- `scaffold-workflow.sh` + `workflows/` codify the recurring multi-worker patterns (**fan-out-review**, **recon→implement→verify**, **loop-until-green/dry**) as gate-valid pre-spawn artifacts.

### 10c. The autonomous loop (systemd + scheduled wakes)
Two mechanisms drive unattended operation:
1. **systemd `--user` timers** ([§11](#11-systemd---user-timers-11-live)) fire scheduled jobs — some run plain scripts, some literally invoke `claude -p "/skill"` headless (the daily briefs, wa-behavior-learn).
2. **Scheduled wakes** — the session can schedule its own future wake-ups (a `ScheduleWakeup`-style mechanism referenced by `/remindme` + `feedback_time_promise_scheduling`) to honour time-bound commitments without a human in the loop.

`loop-digest.sh` (06:30 timer) then summarizes what happened overnight (decisions, task completions, worker outcomes) into one WhatsApp via the wa-sender queue, so Toper wakes to a digest instead of having to ask.

---

## 11. systemd `--user` timers (11 live)

The always-on job fleet. **8 of the 11 are repo-tracked**; the other 5 are **machine-local** (they bake in secrets / machine specifics and are enabled out-of-band — `install.sh` only enables the repo-managed ones). The live cadence table is in the inventory block; purposes + output channels:

| Timer | Cadence | Purpose | Output | In repo? |
|---|---|---|---|---|
| `reminder-check` | every 1 min | Fire due `/remindme` reminders | wa-sender queue → WhatsApp | ✗ local |
| `signal-trader-bridge` | every 1 min | Pull signal-trader WA events off the VPS into the local queue | wa-sender queue | ✗ local |
| `qb-proxy-doctor` | every 2 min | Self-heal the qutebrowser CDP proxy (restart `qb_proxy.py` if :9222 is down while qb runs) | (silent self-heal) | ✓ |
| `deadman` | every 3 min | Liveness-armed watchdog for wa-sender + signal-trader; alerts only on an observed alive→dead transition | **out-of-band email** (not wa-sender) | ✓ |
| `memory-autopush` | every 30 min | Commit + push live memory to the private remote | git (`TopengDev/claude-memory`) | ✓ |
| `daily-brief-morning` | 06:00 WIB | `claude -p "/daily-brief morning"` (tasks + calendar) | WhatsApp to Toper | ✗ local |
| `loop-digest` | 06:30 WIB | Summarize overnight autonomous activity | wa-sender queue → WhatsApp | ✓ |
| `daily-brief-evening` | 21:00 WIB | `claude -p "/daily-brief evening"` | WhatsApp to Toper | ✗ local |
| `wa-behavior-learn` | 03:17 daily | `claude -p "/wa-behavior-learn"` (refresh per-contact style memory) | memory files | ✗ local |
| `journal-audit` | 04:00 WIB | Promote journal → canonical memory + orphan-net re-index | memory files | ✓ |
| `memory-decay` | Sun 04:30 WIB | Archive clearly-stale memory + regen index | `archive/` + memory | ✓ |

> **systemd symlink note:** `~/.config/systemd/user/` is a **real machine-local directory** (it holds units this repo does NOT track — wa-sender, daily-brief, reminder-check, signal-trader-bridge, macro-news, wa-behavior-learn). `install.sh` therefore symlinks the repo's **individual** unit files INTO that real dir (never `link`-ing the whole dir, which would `mv` it to `.pre-stow` and orphan the load-bearing daemons). Today `deadman` + `loop-digest` are the symlinked ones; the rest are real files whose content matches the repo — a real `install.sh` run would convert them to symlinks (idempotent improvement).

---

## 12. The MCP layer

Two custom MCP servers ship in the repo (mounted via `settings.json` plugins or a gitignored `.mcp.json`):

- **email-mcp** (`claude/email-mcp/`): TypeScript, **24 email tools** (read/send, IMAP-append-to-Sent after SMTP, search, folder mgmt). Outlook OAuth + Hostinger IMAP/SMTP. `dist/` gitignored — `bun install && bun run build` regenerates it; `config.json` gitignored (`config.example.json` is the template). This is also the channel `deadman.sh` alerts through (out-of-band from wa-sender).
- **whatsapp-mcp** (`claude/whatsapp-mcp/`): TypeScript, Baileys-based WhatsApp Web wrapper (**33 tools** registered in `src/index.ts`). `patch-baileys.sh` applies a known-good fix when upstream breaks during a version bump.

Plus marketplace plugins (attn agent-messaging, context7 docs, playwright [hard-banned via hook], ralph-loop, gopls-lsp, ui-ux-pro-max, nativ).

---

## 13. State locations (what lives where, and its durability tier)

| State | Location | Tier |
|---|---|---|
| Credentials | `~/.claude/secrets.env` (+ staged `secrets.env.enc`, key `~/.config/age/keys.txt`) | secret, gitignored |
| Memory | `~/.claude/memory/*.md` → private repo `TopengDev/claude-memory` | private-versioned |
| Initiatives / tasks / templates | `~/claude/notes/{initiatives,<task-dirs>,templates}/` | project-space (NOT in chilldawg) |
| `/tasks` skill data | `~/.claude/tasks/` | per-machine (repo ships template only) |
| STATE.md template | `~/claude/notes/templates/STATE.md` | project-space real file |
| wa-sender outbound queue | `~/claude/Git/repositories/signal-trader/wa-sender/queue/events.jsonl` | runtime queue |
| reminders | `~/reminders/reminders.jsonl` | runtime |
| Claude runtime | `~/.claude/{projects,sessions,cache,history.jsonl,plugins}` | gitignored runtime |

> Note: the orchestration **notes** (`~/claude/notes/`) and the **memory** (`~/.claude/memory/`, private repo) deliberately live *outside* chilldawg-setup — chilldawg is the *config* source-of-truth, not the *work-product/operational-state* store.

---

## 14. Data flow — how it connects

### How a delegated task flows
```
Toper drops a task (chat / WhatsApp)
        │
        ▼
  MAIN SESSION (command center, tmux win 1 — discussion + coordination only)
        │  triage → write triage.json + initiative + notes dir + STATE.md skeleton
        ▼
  spawn-worker.sh ──[triage gate ✓]──[semaphore ✓ (≤4)]──► new tmux window + attn loaded
        │
        ▼
  brief-worker.sh ──(role-override preamble + brief)──► WORKER claude session
        │                                                   │ maintains STATE.md checkpoints
        │                                                   │ does the work, verifies each effect
        │                                                   ▼
        │                                            writes result.json + report.md
        │                                                   │
        ◄────────────── attn report-back ──────────────────┘
   main ingests result.json → continues the pipeline
   (if worker died: resume-worker.sh → continue from STATE.md Resume cursor)
```

### How the autonomous loop wakes + acts
```
systemd --user timer fires (or a scheduled self-wake)
        │
        ├─ plain script  ─► deadman.sh / memory-autopush.sh / loop-digest.sh / journal-audit.py …
        │                        │
        │                        ├─ alert?  ─► lib-email-alert.py (out-of-band email)   [deadman]
        │                        ├─ notify? ─► wa-sender queue → WhatsApp to Toper       [loop-digest, reminders]
        │                        └─ mutate? ─► memory files / git push                   [memory-*]
        │
        └─ headless claude ─► `claude -p "/daily-brief …"` / `/wa-behavior-learn`
                                 └─► WhatsApp to Toper / memory files
```

### The verification triad (keep this doc honest)
```
gen-architecture-inventory.sh   →  what the system IS      (enumerated from disk → §16)
setup-doctor.sh                 →  what the repo DECLARES is actually LIVE (symlinks/units/hooks)
settings-drift.sh               →  the one non-symlinked config still matches (canonical, hooks-aware)
```

---

## 15. Keeping this doc honest (regeneration + verification)

- **Regenerate the enumerable inventory** (timers / scripts / hooks / skills) whenever the system changes:
  ```bash
  claude/scripts/gen-architecture-inventory.sh > /tmp/inv.md
  # then replace the AUTO-GENERATED INVENTORY block below with /tmp/inv.md
  ```
- **Verify the repo's declarations are live:** `claude/scripts/setup-doctor.sh` (expect `PASS — no drift`).
- **Check settings.json drift:** `claude/scripts/settings-drift.sh` (read-only; `--sync-to-repo` / `--sync-to-live` to reconcile, explicit direction + backup).

---

## 16. Machine-checkable inventory

The enumerable parts of this system (timers, scripts, hooks, skills) are **regenerated from disk**, not hand-maintained — that's how the old doc's "36 skills" rotted to wrong while the truth was 40. Two design choices keep this honest *without* this file churning on every run:

1. The **verified enumerations live in the prose above** — §5 (all 40 skills, grouped), §6 (all 25 scripts, grouped), §7 (every hook + its gate), §11 (all 11 timers with cadence + output). Those are disk-verified as of the commit that last touched this file.
2. The **machine-checkable form is produced on demand** by the generator, which prints a full Markdown inventory (counts + tables + the *live* timer cadence) straight from disk:

```bash
claude/scripts/gen-architecture-inventory.sh        # full inventory to stdout
claude/scripts/gen-architecture-inventory.sh | less # browse it
```

Run it any time you suspect this doc has drifted: if the generator's counts/tables disagree with §5/§6/§7/§11, **the generator is right** — update the prose. (The live timer table carries timestamps, which is why it's emitted on demand rather than frozen into this file.) Pair it with `setup-doctor.sh` (verifies the repo's declared symlinks/units/hooks are actually live) and `settings-drift.sh` (verifies the one non-symlinked config still matches).

> Snapshot baseline at last doc update: **11 timers · 25 scripts · 7 hook commands (4 file-path + 3 inline) · 40 skills.**

---

## 17. External configs

Some config is intentionally **not** owned by chilldawg-setup — it lives as its own repo with its own upstream, cloned as a sibling by `install.sh`:

| Config | Upstream | Why separate |
|---|---|---|
| `~/.config/nvim/` | `github.com/TopengDev/nvim_setup` | Independent history; portable to machines that don't use chilldawg. `install.sh` skips the clone if it already exists. |

Update: `cd ~/.config/nvim && git pull`. Push nvim changes through *its* repo, not this one.

---

## 18. How a new machine bootstraps

1. Clone this repo.
2. `cp .env.example ~/.claude/secrets.env`, fill real values, `chmod 600`.
3. Install the package set from `tools-installed.md` (incl. `jq`, `gitleaks`, `age`/`sops` for the staged secrets path).
4. `./install.sh` — symlinks everything, restores `settings.json` if absent, links + enables the repo-managed systemd timers.
5. `bun install && bun run build` inside `claude/email-mcp/` and `claude/whatsapp-mcp/`.
6. `exec bash` (loads secrets), then `claude`.
7. **Verify:** `setup-doctor.sh` (→ PASS), `settings-drift.sh` (→ IN SYNC).

The first `claude` session sees all ~40 skills, the hooks, the plugin set, and the MCPs — identical to the source machine. **Memory is the exception:** it's private + in a separate repo, so a fresh machine starts empty and either clones `TopengDev/claude-memory` into `claude/memory/` or grows its own. Machine-local timers (briefs, reminders, signal-trader bridge, wa-behavior-learn) are enabled out-of-band.
