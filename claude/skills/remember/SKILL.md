---
name: remember
description: Save, review, or clean up persistent memories — the canonical writer for the ~/.claude/memory store (schema-v2 frontmatter + BM25 retrieval enrichment). Use when you need to remember a durable fact/rule/decision, the user asks to save/forget/clean memory, or at end of conversation to review what should be persisted.
argument-hint: <what to remember> | review | forget <topic> | clean
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /remember — the canonical memory writer

Save, update, review, and retire persistent memories in the local memory store
so durable facts, rules, and decisions survive across sessions and get
**recalled proactively** by the every-prompt injection hook.

Every memory you write is served by a **local BM25 retrieval engine**
(`memory-retrieve.py`) and injected into future prompts by a
`UserPromptSubmit` hook. A memory that is written badly — thin enrichment, a
rare term buried in the body — is **invisible in practice** even though the file
exists. This skill exists to make every write *findable*, not just saved.

## Boundary vs /journal (read this first)

There are two writers into `~/.claude/memory/`. Pick the right one:

- **`/journal`** = fast, continuous, low-friction **capture** as things happen.
  It appends a tagged line to `journal.md`; a **daily 04:00 WIB audit**
  (`journal-audit.py --apply`) later classifies and **promotes** the keepers
  into canonical memory files. Use it mid-flow when you don't want to stop.
- **`/remember`** (this skill) = a **deliberate, durable write NOW** of a fact
  you want indexed and recallable immediately — a behavioral rule, a project
  decision, a person, a system reference. You do the namespace choice, the
  enrichment, the dedup, and the verify **in this turn**.

If Toper says "remember X" as a durable fact right now → `/remember` (write the
file directly). If it's a breadcrumb you'll consolidate later → `/journal`.
Neither auto-dedupes the other's writes, so **dedup is on you** (see HARD RULES).

## Memory System Map

The store is `~/.claude/memory/` (a symlink into `chilldawg-setup`; it is its
**own private git repo**, auto-pushed every 30 min — see Secret Hygiene). You
operate ONE part of a larger machine. Know what is automatic vs manual:

| Component | What it does | Auto / manual |
|---|---|---|
| `memory-retrieve.py` | BM25 engine + CLI over the corpus. Your dedup + retrievability tool. | manual (you run it) |
| `gen-memory-index.py` | Regenerates `MEMORY.md` + `indexes/*.md` shards from frontmatter. | manual after an UPDATE; auto (hook) only for a NEW file |
| `memory-inject-hook.sh` | `UserPromptSubmit` hook — injects top-5 relevant memories into every prompt. | **automatic**, wired |
| `memory-write-validate.sh` | `PostToolUse(Edit\|Write)` hook — validates frontmatter, scans for secrets, debounced index regen for NEW files only. | **automatic**, wired |
| `memory-decay.py` | Conservatively **archives** (never deletes) stale files. Your `clean` engine. | manual + **weekly** timer (`--apply`, Sun 04:30 WIB) |
| `memory-autopush.sh` | Commits + pushes the store to its **private** remote. | **automatic**, 30-min timer |
| `journal-audit.py` | Promotes `journal.md` entries to canonical memory. | **automatic**, daily 04:00 WIB (`--apply`) |
| `journal-add.sh` | The `/journal` appender. | manual (via /journal) |
| `memory-eval.py` | recall@1/3/5 + MRR on `eval/golden.json`. Regression gate after bulk changes. | manual |

All scripts live in `~/.claude/scripts/`. Canonical retrieval doc:
`~/.claude/scripts/README-memory-retrieval.md`. Deep interfaces:
`references/tooling.md`.

**Two hooks fire around your write, automatically:** the PostToolUse validator
warns (never blocks) if frontmatter is missing a required field or if it
smells a secret, and it regenerates the index **only when the file is new**.
So after **updating** an already-indexed file you MUST regen the index yourself.

---

## The four modes

### 1. Save — `/remember <what to remember>`

1. **Dedup FIRST (mandatory).** Run the retrieval engine over the topic and its
   rare terms — do NOT just eyeball `MEMORY.md` (it is sharded and can be stale;
   see HARD RULES):
   ```bash
   python3 ~/.claude/scripts/memory-retrieve.py "<topic + its rare terms>" -k 5
   ```
   If a hit is clearly the same topic → **UPDATE that file**, never create a
   parallel one. Only create when nothing covers it.
2. **Choose the namespace** via the Namespace Decision Table below. The
   filename prefix follows the namespace; the `namespace:` frontmatter field is
   what actually routes the file (grouping, sharding, retrieval).
3. **Write / update** the file at `~/.claude/memory/<prefix>_<topic>.md` with
   **schema-v2 frontmatter** (block below, verbatim contract).
4. **Pass the Pre-Write Gate** (10-point checklist below) — enrichment,
   dates, secret self-scan, Why/How for feedback|project.
5. **Regenerate the index** — `python3 ~/.claude/scripts/gen-memory-index.py`.
   (The PostToolUse hook auto-regens for a NEW file after a ~20s debounce, but
   an UPDATE to an existing file will NOT trigger a regen — run it yourself.)
6. **Verify retrievability** — the retrievability self-test (see Verify).

**Schema-v2 frontmatter — the exact contract the tools parse. Write these
fields; do not invent new ones or the memory goes invisible:**

```markdown
---
name: <filename stem slug — MUST equal the file's basename without .md>
title: <human-readable title (shown in the index)>
namespace: <identity | feedback | project | reference | contact | credential>
tier: <1-3 importance, 1 = top>
status: <active | archived>   # project namespace only
description: <one precise line — MED-weight in retrieval; put load-bearing terms here>
tags: [<specific, high-signal topical tags — no generic filler>]
entities: [<names of people / tools / services / files / error codes this is about>]
aliases: [<alternate phrasings of the title + rare synonyms>]
trigger_keywords: [<>=3 exact query terms a future you will type>]
hypothetical_questions:
  - <a real question a future session will ask that this memory answers>
  - <another — these bridge the query-vs-statement gap for retrieval>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

## Summary
<2-3 sentence overview>

## Details
<structured content>

## Context  (feedback + project: include **Why:** and **How to apply:** lines)
<why this matters / how to act on it>
```

The six retrieval fields (`title` is always present; `tags` / `entities` /
`aliases` / `trigger_keywords` / `hypothetical_questions`) are the **HIGH-weight
fields** the BM25 engine ranks on (×3 vs description ×2 vs body ×1). They are how
a memory gets found. See the Retrieval-Bug Authoring Guardrail — this is the #1
lesson of this skill.

> **Harness nesting is fine — do NOT fight it.** When you write a memory through
> Write/Edit, Claude Code's `autoMemoryDirectory` normaliser may re-nest these
> fields under a `metadata:` block (and add `node_type` / `originSessionId` /
> `type`). Both `memory-retrieve.py` (`field()`, lines 196-213) and
> `gen-memory-index.py` read the nested block AND the flat top level, so either
> layout retrieves correctly. The ONE hard invariant: **`name` must equal the
> filename stem** — everything (retrieval, index, dedup, wikilinks) keys off the
> stem. Never hand-"un-nest" a normalised file. What you must NOT skip is
> supplying the enrichment in the first place — nesting preserves fields you
> wrote; it cannot invent fields you left out.

### 2. Review — `/remember review`

Scan the current conversation for unsaved, memory-worthy insights (per
[[feedback_auto_memory]] — save proactively, don't wait to be asked). Classify
each with the Namespace Decision Table:

- **Decisions** (direction, architecture, strategy) → `project`
- **Corrections / confirmations** ("don't do X", "yes that works") → `feedback`
- **New tools / services / systems / people-as-resources** → `reference`
- **A person** (how to talk to them, JIDs, tone) → `contact`
- **User preferences / profile** → `identity` (`user_` files)
- **WHERE a credential lives** (never the value) → `credential`

For each: dedup (memory-retrieve.py) → if new, Save it through the full gate; if
partial, UPDATE the existing file → report what was saved/updated. Then regen
the index once for the batch.

### 3. Forget — `/remember forget <topic>`

Deletion is the ONLY destructive mode. Guard it:

1. `memory-retrieve.py "<topic>"` to find the exact file (confirm the stem).
2. **Confirm with the user before deleting** — name the file and what it holds.
3. Only then remove the file, and regenerate the index
   (`gen-memory-index.py`).
4. Note: the store auto-pushes to its private remote every 30 min, so a delete
   propagates off-box. It stays in git history (recoverable), but prefer
   **archive over delete** for anything that might be wanted later — reach for
   `clean` (archive) unless the user explicitly wants it gone.

### 4. Clean — `/remember clean` (archive, never bulk-delete)

The store already self-cleans: `memory-decay.py --apply` runs on a **weekly
timer** (Sun 04:30 WIB). Manual `clean` is the on-demand version. It **archives,
never deletes** — moved files go to `archive/` (dropped from the index, still in
git, restored with one `mv`). Protocol:

1. **Dry-run first** — see exactly what would be archived and WHY:
   ```bash
   python3 ~/.claude/scripts/memory-decay.py            # dry-run (default)
   ```
   It only flags high-confidence-stale files: **S1** session-state snapshots
   (`project_session_state_*.md`) and **S2** self-declared superseded/merged
   (REDIRECT stubs). It shows a "HAD STALE SIGNAL BUT KEPT" list too — those
   were saved by a guard (G1 still wikilinked, G2 durable user_/feedback_ rule,
   G3 too recent).
2. **Review** each candidate + reason. Confirm you agree.
3. **Apply** to archive (moves + regenerates the index):
   ```bash
   python3 ~/.claude/scripts/memory-decay.py --apply
   ```
4. For a **finished project** the decay tool won't touch (no stale signal), flip
   its frontmatter `status: active` → `status: archived` and regen — don't
   delete it.
5. **NEVER bulk-delete in clean.** Deletion is reserved for `/remember forget`
   with explicit confirmation.

---

## HARD RULES (NEVER / ALWAYS)

1. **ALWAYS dedup BEFORE creating** — run `memory-retrieve.py "<topic + rare
   terms>"`, do NOT just read `MEMORY.md`. `MEMORY.md` is **sharded** (project,
   contact, credential live in `indexes/*.md`) and only regenerates on new-file
   writes, so it is a partial, possibly-stale human index. Same topic exists →
   UPDATE it, never fork a parallel file.
2. **ALWAYS put every load-bearing / rare / high-signal term** (product name,
   error code, person, tool, endpoint, the exact word a future query will use)
   in the HIGH-weight fields (`title`, `aliases`, `trigger_keywords`, `tags`,
   `entities`) AND in `description` — **NEVER only in the body.** The
   retrieval-relevance bug ([[reference_memory_retrieval_relevance_bug]]) is
   **LIVE**: a body-only rare term loses to conversational filler.
3. **NEVER finish a write with empty enrichment** — `trigger_keywords` (≥3
   specific terms) + `hypothetical_questions` (≥2 real future questions) +
   `tags`/`entities`/`aliases` filled, before the write is "done".
4. **NEVER use generic filler as enrichment.** Banned low-IDF terms that match
   everything: `workflow`, `memory`, `automation`, `misc`, `notes`, `general`,
   `stuff`, `info`, `session`, `data`, `system`. Every term must be specific
   enough to be rare in the corpus.
5. **NEVER write a secret/credential VALUE** into a memory file. Reference the
   location (`$VAR` in `secrets.env` / the credential index). The store is
   version-controlled AND auto-pushed to a private remote — see Secret Hygiene.
6. **`name` MUST equal the filename stem** — the one invariant everything keys
   off (retrieval, index, dedup, wikilinks). Keep them in sync even when the
   harness re-nests other fields under `metadata:`.
7. **ALWAYS convert relative dates to absolute** Asia/Jakarta dates before
   writing ("next Thursday" → "2026-07-09").
8. **NEVER hand-edit `MEMORY.md` or `indexes/*.md`** — they are auto-generated
   and verified-before-replace. Regenerate via `gen-memory-index.py`.
9. **ONE fact / one topic per file.** For `feedback` and `project`, ALWAYS
   include a **Why:** line and a **How to apply:** line.
10. **After UPDATING an already-indexed file, run `gen-memory-index.py`
    yourself** — the PostToolUse hook auto-regens only for NEW/unindexed files.
11. **NEVER save code patterns, file paths, or git history** derivable from the
    codebase, and **NEVER save ephemeral task detail** (that's `/tasks` and
    in-progress work).
12. **On `clean`: archive, never bulk-delete.** Use `memory-decay.py` (dry-run
    → `--apply`) or flip a finished project to `status: archived`.

---

## Namespace Decision Table

Pick ONE. The `namespace:` field routes the file; the filename prefix should
track it (human navigation). `name` must still equal the stem.

| Namespace | Filename prefix | When to use | Required body |
|---|---|---|---|
| `identity` | `user_` | Christopher's own profile, preferences, work style, personal facts. | Summary |
| `feedback` | `feedback_` | A correction / standing rule about how to work ("don't do X", "always Y"). | **Why:** + **How to apply:** |
| `project` | `project_` | A durable fact/decision/state about ongoing work (goal, constraint, arch choice, HEAD, env quirk). | **Why:** + **How to apply:** + `status:` |
| `reference` | `reference_` | A tool / service / external system / person-as-a-resource / how-something-works. | Summary + Details |
| `contact` | `contact_` | A person: how to talk to them, JIDs, tone, tier. (Legacy `whatsapp_style_` files also carry `namespace: contact`.) | Summary |
| `credential` | `reference_` (declares `namespace: credential`) | WHERE a secret lives — **never the value**. e.g. "`$VPS_PASSWORD` in secrets.env". | The `$VAR` location only |

Notes: **identity → `user_`** (not `identity_`). **credential** files in the
live store use the `reference_` prefix but declare `namespace: credential` (they
are references to where a secret lives). Sharding routes by the `namespace:`
field regardless of prefix: `identity`/`feedback`/`reference` render into
`MEMORY.md`; `project`/`contact`/`credential` render into `indexes/*.md`.

**Tiebreakers (the three real ambiguities — round to the more reusable home):**
- **feedback vs project** — a *reusable rule* that applies beyond one project (a
  "how we work" correction) → `feedback`. A fact/state *specific to one project*
  (its arch choice, HEAD, env quirk, `status`) → `project`.
- **reference vs project** — a durable how-it-works about a tool / service /
  system that outlives any single project → `reference`. A decision or live
  state *inside* an active project → `project`.
- **contact vs reference (for a person)** — how to *talk to / message* them
  (tone, JID, tier) → `contact`. A person as a *work resource / authority* (what
  they own, decide, or gate) → `reference`.

---

## Pre-Write Gate (blocking — all 10 pass before a write is "done")

1. ☐ **Dedup query run** (`memory-retrieve.py`) + reviewed — this is new, or I am
   updating the right existing file.
2. ☐ **Namespace chosen** via the table; filename prefix matches it.
3. ☐ **`name` == filename stem.**
4. ☐ **`description`** is one precise line containing the load-bearing terms.
5. ☐ **`trigger_keywords`** ≥ 3 specific, high-IDF terms.
6. ☐ **`hypothetical_questions`** ≥ 2 real future queries (phrased as a user
   would ask them).
7. ☐ **`tags` / `entities` / `aliases`** filled, **zero banned-generic** terms.
8. ☐ **All dates absolutized** (WIB).
9. ☐ **Secret self-scan clean** — no `sk-…` / `ghp_…` / `github_pat_…` / `AKIA…`
   / `AIza…` / `xox…` / PEM block / `password=<literal>` / raw phone number.
10. ☐ **feedback | project** carry a **Why:** and a **How to apply:** line
    (project also carries `status:`).

**Echo the gate before you regen — the forcing function.** A silent internal
checklist is exactly what let **6 live files** (incl. this program's own
`project_skills_ultra_enhance`) ship enrichment-empty. The write is NOT "done"
until you have STATED the gate outcome in one compact line, so the thin slots
are visible before they land:

```
GATE  dedup✓(none) · ns=reference · name==stem✓ · desc✓ · tk=4 · hq=2 · tags/ent/alias✓ · dates-abs✓ · secret✓ · why/how=n/a
```

Any ✗ or thin slot (`tk<3`, `hq<2`, a banned-generic term, a rare term still
body-only) → fix it FIRST, never regen a half-enriched file. The PostToolUse
hook won't save you: it **preserves** the fields you wrote, it cannot **invent**
the ones you skipped.

---

## The Retrieval-Bug Authoring Guardrail (load-bearing — the #1 lesson)

**The bug is LIVE.** `memory-retrieve.py` (2026-06-24) does BM25 over a weighted
term bag and has **no conversational-filler stripping and no rare-term boost**.
Field weights: `title` / `aliases` / `trigger_keywords` / `hypothetical_questions`
/ `tags` / `entities` = **×3 (HIGH)**, `description` = **×2 (MED)**, body =
**×1 (LOW)**. Consequence: a rare term that lives **only in the body** (weight 1)
is out-ranked by common conversational words ("do you remember about…") that hit
**other** files' HIGH-weight fields. The verified failure: asking "do you
remember about **execfi**" returned generic memory files and **zero** of the 5
files that actually discuss execfi — because "execfi" was body-only in all 5.

**The authoring fix (yours to apply on every write):** hoist every rare,
load-bearing term UP into the HIGH-weight fields + `description`. You are writing
FOR the BM25 engine's high-weight fields.

```yaml
# BAD — the rare term is body-only; it will NOT be recalled by a natural query
title: BCAS VPS rootless deploy
trigger_keywords: [vps, deploy, podman]     # generic; "execfi" is nowhere up here
# ...body mentions "execfi" 4 times...      # weight 1 — loses to filler

# GOOD — the rare term is in title-adjacent HIGH fields + description
title: BCAS execfi rootless-podman deploy (ibankent gap-fill)
description: How the execfi container deploys on the BCAS VPS via rootless Podman/Oracle — the ibankent gap-fill migration.
aliases: [execfi deploy, execfi-postgres, ibankent gap-fill]
trigger_keywords: [execfi, rootless podman oracle, ibankent gap-fill, bcas vps deploy]
entities: [execfi, ibankent, BCAS VPS, Podman, Oracle]
```

**Do / Don't:**
- DO `trigger_keywords: [execfi deploy, rootless podman oracle, ibankent gap-fill]`
- DON'T `tags: [memory, workflow, automation]` (matches everything → dilutes IDF)
- DO put a person's name in `title` + `aliases`; DON'T bury it in body prose.

Depth (how BM25 ranks, why generic terms hurt, the pending engine fix):
`references/retrieval-and-consolidation.md`.

---

## Secret Hygiene (inline — the store is private BUT auto-pushed)

The memory dir is its **own git repo** with a **private remote**, and
`memory-autopush.sh` commits + pushes it **every 30 minutes**. A secret written
here reaches an off-box remote within 30 min.

- **NEVER write a secret VALUE.** Reference the location: `$ANTHROPIC_API_KEY`
  in `secrets.env`, "see the credential index", "`$VPS_PASSWORD` in secrets.env".
  Credential-namespace files hold **only** the `$VAR`/location, never the value.
- The **PostToolUse hook** (`memory-write-validate.sh`) scans every memory write
  for `sk-ant-` / `ghp_`/`gho_`/`ghu_`/`ghs_`/`ghr_` / `github_pat_` / generic
  `sk-` / `AKIA` / `AIza` / `xox` / PEM blocks / `password=<literal>` /
  Indonesian phone numbers, and surfaces a leak warning as additionalContext. It
  does NOT block — treat the warning as **actionable**.
- **If a leak fires** (or you spot one): redact the value to a `$ENV`/secrets.env
  reference immediately, re-save so the hook re-scans clean, and **rotate the
  key** — assume autopush already pushed it to the private remote
  (`TopengDev/claude-memory`).
- **When reviewing another agent's memories**, report the **file + pattern
  type** only (e.g. "reference_x.md contains what looks like a generic sk- key")
  — **never** echo the value.

---

## Enrichment Quality rubric

A term earns a HIGH-weight slot only if it is **(a)** the exact token a future
query will use AND **(b)** rare in the corpus (high-IDF — appears in a small
minority of files). Frame every enrichment decision as: *does this help the BM25
engine surface THIS file over the ~230 others?*

- **GOOD term:** a product/system name (`execfi`, `Pulse MinIO`), an error code,
  a person's name, a tool (`rootless podman`), an endpoint, a distinctive phrase
  a future you would type.
- **REJECT (banned-generic):** `workflow`, `memory`, `automation`, `misc`,
  `notes`, `general`, `stuff`, `info`, `session`, `data`, `system` — and any
  role/product word so common it appears across many files. Generic tags don't
  just fail to help; they **dilute IDF** and worsen the relevance bug for
  everyone.
- **`hypothetical_questions` must be SPECIFIC too** — it is the highest-leverage
  field (a query phrased like one scores hardest), so a generic question throws
  the advantage away. BAD: *"What should I remember about this?"* / *"Is there
  anything about X?"*. GOOD: name the rare term + the exact decision — *"What is
  the cutover gate for the ACME billing migration?"*, *"Where does the execfi
  container deploy?"*.

**Tier rubric:** tier 1 = a durable behavioral rule or load-bearing infra fact
recalled often; tier 2 = a useful project/reference; tier 3 = niche or
point-in-time. **Status** (`project` only): flip to `archived` when the project
finishes — don't delete.

---

## Failure-Mode Playbooks (exact commands)

**"A memory I wrote isn't being recalled."**
Confirm it isn't a bare metadata-only file (enrichment present). Run the
retrievability self-test with a natural question. If the query's rare term is
body-only → that's the LIVE relevance bug; move the term into
`trigger_keywords` + `description` + `aliases` and re-test.
```bash
python3 ~/.claude/scripts/memory-retrieve.py "<a natural question about it>" -k 5 --json
```

**"A duplicate memory exists."**
Merge into the higher-tier / older-`created` file. If the loser is `[[wikilinked]]`
from live files, leave a one-line **REDIRECT** stub (so `memory-decay.py`'s G1
guard respects it, and decay can later archive it as self-declared superseded).
Regen the index.
```bash
python3 ~/.claude/scripts/gen-memory-index.py
```

**"A secret leaked into a memory."**
Redact the value to a `$ENV`/secrets.env reference, re-save (hook re-scans),
rotate the key (assume autopush already pushed it to the private remote).

**"The index is out of sync after an UPDATE."**
The PostToolUse hook regens only for NEW files. After editing an existing file:
```bash
python3 ~/.claude/scripts/gen-memory-index.py
```

**"The harness re-nested my fields under `metadata:`."**
Expected and FINE — both the retriever and the index read nested + flat. Do NOT
un-nest by hand. The only invariants are `name` == stem and enrichment-present.

**"Did my bulk change regress retrieval?"**
Run the eval after any multi-file change or engine change:
```bash
python3 ~/.claude/scripts/memory-eval.py          # recall@1/3/5 + MRR + per-miss list
```

---

## Verify (every write — dogfood the engine)

**Retrievability self-test.** After a write, ask the engine a natural question a
future you would ask, and confirm the new/updated file lands in the **top-3**:
```bash
python3 ~/.claude/scripts/memory-retrieve.py "<natural question about this fact>" -k 5
```
If it isn't there → enrichment is too generic/thin, or the load-bearing term is
still body-only. Fix and re-test. This is not optional; a saved-but-unfindable
memory is a silent failure.

For a **batch** change (review, several files, a merge, or after touching the
engine), first `gen-memory-index.py --check` (assert-only: renders + verifies +
honours the 24000-byte loader cap, writes nothing — catches a `SIZE_CAP`
overflow before it bites), then run `memory-eval.py` and confirm recall@k / MRR
did not regress.

---

## Consolidation & auto-dream (what is NOT automatic for you)

- **auto-dream stays OFF** (not in `settings.json`), deliberately superseded by
  the journal+audit loop ([[feedback_memory_consolidation_loop]]). Do NOT try to
  re-enable it.
- **The daily `journal-audit.py --apply` (04:00 WIB)** is the *consolidation*
  half of the loop — it promotes `journal.md` entries. It backs up first and
  only ADDs/APPENDs. It does NOT dedup or merge your direct `/remember` writes.
- **A direct `/remember` write is NOT auto-consolidated or auto-deduped** — the
  dedup gate is on you (HARD RULE 1).

---

## Shared Memory (for tmux-spawned agents)

Spawned agents can write to the same store. To share context in a worker brief,
append only the memories relevant to that worker's task (not the whole store):

```
Shared memories to be aware of (read these files for context):
- ~/.claude/memory/user_christopher.md
- ~/.claude/memory/reference_vps.md
- ~/.claude/memory/reference_cloudflare.md

If you learn something worth persisting across sessions, write it to:
~/.claude/memory/<namespace>_<topic>.md  (schema-v2 frontmatter — see the Save
section), pass the Pre-Write Gate, then regenerate the index:
python3 ~/.claude/scripts/gen-memory-index.py
```

---

## Reference files (progressive disclosure)

- `references/schema-reference.md` — every frontmatter field: type, purpose,
  retrieval weight, example; flat-v2 vs harness-nested layout; the name==stem
  invariant; namespace ↔ filename-prefix ↔ shard routing.
- `references/tooling.md` — the full 9-script + 2-hook + 3-timer map with
  verified interfaces and flags.
- `references/worked-examples.md` — full well-formed memories (one per
  namespace) + bad→good rewrites + a merge / REDIRECT-stub example.
- `references/retrieval-and-consolidation.md` — how BM25 ranks (so you write for
  it), the live relevance bug in depth + mitigation, the journal+audit loop, and
  the /journal boundary in depth.
