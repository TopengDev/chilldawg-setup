---
name: session-handoff
description: "Write a successor-proof handoff of the CURRENT session (derived from live probes, never from memory), so a fresh session or another agent continues with zero loss. Verification-gated, atomic, PreCompact-integrated. Use when context passes ~60%, before ending a work session, when transferring a task to another session/agent, after a major milestone, when the PreCompact nudge fires, or when the user says /session-handoff. NOT the client-delivery skill (that is /handover)."
argument-hint: [optional focus note, e.g. "pausing for the night" | --emergency]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# /session-handoff — the zero-loss session handoff

ONE contract: **if this session dies the moment the handoff passes its gate, NOTHING
is lost.** A reader with ZERO context (fresh session, different model, another agent,
Christopher in 3 weeks) can pick the work up from the file alone.

This skill is a LEAF (like /commit): it probes, writes, verifies, reports, and STOPS.
It never spawns sessions, never sends messages, never compacts. Delivering the handoff
to a successor is the caller's job; the skill's job is that the artifact is COMPLETE,
TRUE, and FINDABLE.

Distinct from its siblings — do not blur them:
- `STATE.md` (worker checkpoint journal): live, incremental, for the SAME task resuming.
- `/remember`: atomic durable facts into the memory store.
- Compaction summary: automatic, lossy, not user-controlled.
- `/handover`: CLIENT delivery package (BAST, credentials map). Completely different thing.
- **/session-handoff**: deliberate, complete, successor-facing snapshot of a whole session.

## Locations (fixed, never improvise)

| What | Where |
|---|---|
| Handoff files | `~/claude/notes/handoffs/YYYY-MM-DD-<session-slug>.md` |
| Pointer | `~/claude/notes/handoffs/LATEST.md` (line 1 = absolute path of newest handoff) |
| Index | `~/claude/notes/handoffs/_index.md` (one line per handoff, newest first) |
| Breadcrumb | `~/.claude/memory/journal.md` (append one tagged line) |
| Schema | `references/template.md` in this skill dir (copy it, fill it) |
| Prober | `scripts/probe-state.sh` in this skill dir |

`<session-slug>`: the session's name if it has one (e.g. `chill-fable`), else the
primary topic in kebab-case (e.g. `aura-demo-video`). Same session + same day =
SAME file, updated in place with `Revision:` bumped. Different session, same day,
same slug = append `-2`, `-3`. NEVER overwrite a file this session did not create.

## HARD RULES

- **HR-1 DERIVE, DON'T RECALL.** Every claim about machine state (git, processes,
  tmux, files, deploys) comes from a probe command run NOW, in this invocation.
  Conversation-derived facts that cannot be probed (user decisions, gate owners,
  verbal agreements) are allowed but MUST carry the literal tag `[conv]`.
  A handoff with zero probe output is INVALID — no exceptions.
- **HR-2 FAIL-OPEN PROBES.** A failing probe yields `n/a (probe failed)` in the
  handoff; it NEVER aborts the handoff. The handoff must be writable on a half-broken
  box — that is precisely when it matters most.
- **HR-3 ZERO-CONTEXT READER.** No "as discussed", no bare "the fix", no pronoun
  whose referent lives only in the conversation. Every codename/alias is expanded
  once at first use ("main (the orchestrator session)"). Read it as a stranger before
  submitting it to the gate.
- **HR-4 ATOMIC + COLLISION-PROOF.** Write to `<file>.tmp` then `mv` into place.
  Flip `LATEST.md` LAST — the pointer flip is the commit. If the target filename
  exists and was not created by this session, suffix `-2` instead of overwriting.
- **HR-5 THE GATE IS BLOCKING.** The verification gate below must PASS before the
  handoff is reported as done. A failed check = fix and re-gate, not a caveat.
- **HR-6 NO SECRETS.** Never inline a key, token, password, or seed phrase. Point at
  the pattern instead: "creds: `$VPS_PASSWORD` in `~/.claude/secrets.env`". A handoff
  is a plaintext file that outlives the session.
- **HR-7 OWNERS ON EVERY OPEN ITEM.** Each open decision/gate names WHO moves it
  (Toper / main / a named session / external). An open item without an owner is a
  dropped item.
- **HR-8 EVIDENCE OVER ADJECTIVES.** "Done" claims carry their receipt: the commit
  sha, the passing command, the verified URL, the file path. "Tests pass" without
  the command+result is banned.
- **HR-9 THREE DISCOVERY PATHS, ALWAYS.** File + LATEST pointer + journal breadcrumb
  (+ index line). All four writes happen every time; a successor must find the handoff
  even if two of the paths are broken.
- **HR-10 HOUSE STYLE.** No em/en dashes anywhere in the file. Mono-friendly markdown.
  Timestamps carry timezone (WIB).
- **HR-11 UPDATE IN PLACE.** Re-invocation in the same session regenerates the SAME
  file (bump `Revision:`), refreshing every probe. Handoffs do not proliferate.
- **HR-12 EMERGENCY MODE FIRST WHEN CRITICAL.** If context is critically low
  (>90% used, or the user said `--emergency`, or auto-compact feels imminent):
  write the 12-line MICRO-HANDOFF (see Emergency mode) and pass its micro-gate
  BEFORE expanding to the full schema. A tiny true handoff beats a full one that
  never finished.

## THE FLOW

### 0 · Preflight (10s)
```bash
mkdir -p ~/claude/notes/handoffs
ls ~/claude/notes/handoffs/ | tail -5   # existing files -> naming + collision check
```
Determine the session slug (session name > primary topic). Decide file name per the
naming rule. Check whether THIS session already wrote one today (then: update mode).

### 1 · Probe reality
```bash
bash ~/.claude/skills/session-handoff/scripts/probe-state.sh [extra-repo-path ...]
```
Pass every repo path this session touched as extra args. THEN read the
session-specific truth the prober cannot know:
- the task's `STATE.md` / notes dir, if one exists
- `git -C <repo> log --oneline -5` for each touched repo (the prober covers this
  only for paths you passed)
- anything the session left running (renders, dev servers, monitors) — verify with
  `pgrep -af <pattern>`, do not assert from memory (HR-1).

### 2 · Draft against the template
Copy `references/template.md` structure EXACTLY — all 9 sections, in order. Fill
every section; a section with nothing to say gets the literal word `none` (an empty
section fails the gate — `none` is a checked, deliberate answer, absence is not).
Tag conversation-only facts `[conv]` (HR-1). Expand every alias (HR-3).

### 3 · Write atomically + plant the discovery paths
```bash
# 1. write <file>.tmp, then:  mv <file>.tmp <file>
# 2. printf '%s\n' "<abs path>" > ~/claude/notes/handoffs/LATEST.md.tmp && mv ...   # pointer LAST
# 3. prepend one line to _index.md:  - YYYY-MM-DD HH:MM WIB · <slug> · <TLDR fragment> · <abs path>
# 4. append to ~/.claude/memory/journal.md:
#    - [ops <ts> WIB] session-handoff written: <abs path> (rev N, <slug>) — <10-word TLDR>
```

### 4 · VERIFICATION GATE (blocking, mechanical)
Run each check; print the table; ALL must PASS:

| # | Check | How |
|---|---|---|
| G1 | file exists, non-trivial | `wc -l` ≥ 60 (full) / ≥ 12 (emergency) |
| G2 | all 9 mandatory headers present | `grep -c '^## '` == 9 and each expected title matches |
| G3 | no empty section | no header directly followed by another header (awk/grep) |
| G4 | probe evidence present | file contains `### probe` output marker from step 1 |
| G5 | every referenced local path exists | extract `` `/abs/or/~ paths` `` -> `test -e` each; missing ones must carry `(gone)` tag or FAIL |
| G6 | resume commands parse | each fenced `bash` block -> `bash -n` |
| G7 | no secrets | `grep -Ei 'PRIVATE_KEY=|BEGIN (RSA|OPENSSH)|password.*=.*[^$]|sk-[A-Za-z0-9]{20}'` finds nothing (values, not var NAMES) |
| G8 | no em/en dashes | `grep -cP '[\x{2013}\x{2014}]'` == 0 |
| G9 | pointer resolves | `head -1 LATEST.md` == this file's abs path AND `test -f` it |
| G10 | journal breadcrumb landed | `tail -3 journal.md` contains the path |
| G11 | zero-context read | re-read the TL;DR + Resume sections cold: would a stranger know what to type first? (judgment, but MANDATORY to perform) |

Any FAIL: fix the file, re-run the gate. Report the final table to the user.

### 5 · Report
One short message: the absolute path, revision, gate table result, what is `[conv]`
(unverifiable), and — if anything was left running — the one-line babysit note.

## The 9 mandatory sections (schema)

See `references/template.md` for the copyable skeleton. Summary of the bar per section:

1. **TL;DR** — ≤3 lines: what this session was, where it ended, the single next action.
2. **Deliverables + evidence** — table: artifact · abs path · proof it works (HR-8).
3. **Live machine state** — the probe output (fenced), plus per-repo git summary.
   Anything running (daemons, renders, monitors) with the command to check it.
4. **Open decisions + gates** — table: item · state · OWNER (HR-7). Include standing
   gates verbatim (e.g. "release gate: Toper says ship, in his window, nobody else").
5. **Standing rules in force** — session-scoped rules a successor must obey
   (bans, model policies, framing rules like "zero rival references").
6. **Resume protocol** — read-first files IN ORDER, then the next 1-3 actions as
   runnable fenced commands. This is the section a successor executes.
7. **Hazards / do-NOT list** — the traps: things that look safe and are not, with the
   one-line reason each (e.g. "do NOT git reset --hard on the VPS: reverts compose edit").
8. **Context pointers** — related memories (`[[name]]`), notes dirs, prior handoffs.
9. **Provenance** — session name+id if known, model, date+time WIB, context% at write
   (model-supplied, tag `[conv]`), `Revision: N`, `reconstructed-post-compact: true|false`.

## Emergency mode (`--emergency` or >90% context)

Write THIS first — 12 lines, same file name, gate G1(≥12)/G5/G7/G9 only:

```markdown
# EMERGENCY HANDOFF · <slug> · <ts WIB> · Revision 0
1. DOING: <one line>
2. DONE+PROOF: <one line, sha/path>
3. IN-FLIGHT: <process/command + how to check>
4. NEXT: <the exact next command/action>
5. GATE: <open gates + owners>
6. HAZARD: <the one thing NOT to do>
7. READ: <STATE.md / notes dir path>
```
Then, ONLY if context still permits, expand in place to the full schema (Revision 1).

## PreCompact integration (how the tripwire and this skill interlock)

The user-global PreCompact hook (`~/.claude/hooks/precompact-handoff.sh`) fires on
every compaction (manual + auto). It is FAIL-OPEN and mechanical:
1. Appends a journal breadcrumb that a compaction happened (survives everything).
2. Emits a systemMessage: if `LATEST.md` resolves, it names the file + its age so the
   post-compact session can judge staleness; if not, it instructs to run
   /session-handoff immediately after compact in RECONSTRUCTION mode.

Because PreCompact cannot pause compaction (nobody gets a turn between hook and
squeeze), the reliability model is layered:
- **Primary**: the 60-70% threshold discipline — run /session-handoff BEFORE the zone
  where auto-compact can fire (this is the CLAUDE.md compact-after-milestones protocol;
  this skill is its executable form).
- **Tripwire**: the hook's breadcrumb + nudge guarantee the gap is VISIBLE afterward,
  never silent.
- **Recovery**: RECONSTRUCTION mode — invoked post-compact with no/stale handoff:
  run the full flow anyway; probes recover machine truth; the compaction summary
  supplies conversation truth (tag those lines `[conv][post-compact]`); set
  `reconstructed-post-compact: true` in Provenance. A reconstructed handoff passes
  the same gate.

## Do / Don't

| DO | DON'T |
|---|---|
| Run probes even when "sure" (HR-1) | Write state from memory and call it verified |
| `none` in a section after checking | Leave a section blank or delete it |
| Name an owner per open item | "TBD" / passive-voice gates |
| Same file, bump Revision | A second file for the same session |
| `bash -n` your resume commands | Ship a resume block with a typo'd flag |
| Micro-handoff first at >90% | Start the full schema at 95% and lose the race |
| `$VAR in secrets.env` pointers | Any literal credential (HR-6) |

## Worked example (fragment, section 6)

```markdown
## Resume protocol
Read first, in order:
1. `~/claude/notes/aura-demo-video-2026-07-05/STATE.md` (task journal, checkpoints)
2. `~/claude/notes/handoffs/2026-07-06-chill-fable.md` (this file, sections 4+7)

Next actions:
​```bash
# 1. confirm the render never got re-triggered
pgrep -af own-renderer-parallel || echo idle
# 2. resume at the release gate: deliverable already verified at
ls -la ~/claude/notes/aura-demo-video-2026-07-05/build/renders/AURA-demo-v4-FINAL.mp4
​```
Gate: publishing = Toper's call, given in HIS window directly. No other signal counts.
```

Anti-pattern (FAILS G11): "Continue where we left off with the video and check with
main about the thing." (Which video? What thing? Who is main?)
