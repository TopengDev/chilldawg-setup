# Loop internals: how journal-audit.py actually works

Deep reference for the memory-consolidation loop. Read this when diagnosing the loop, reasoning about a manual audit run, or explaining the mechanics. The always-loaded SKILL.md carries the rules and the health-check; this file carries the encyclopedic detail. All facts below were verified against the on-disk scripts (do NOT edit those scripts; this skill only references them).

## The two halves

1. **Capture** (`~/.claude/scripts/journal-add.sh`): you append tagged, timestamped lines to `journal.md`. Zero LLM, deterministic, instant.
2. **Consolidate** (`~/.claude/scripts/journal-audit.py`): a daily job reads the new lines, asks an LLM to classify and draft canonical memory files, and applies the promotions conservatively.

This pair is the elpabl0-concept loop adopted 2026-05-30 (`feedback_memory_consolidation_loop`). It REPLACES auto-dream, which stays OFF (`reference_auto_dream`). Do not enable `autoDreamEnabled`; the two would double up.

## Run modes (verified from journal-audit.py argparse)

| Invocation | Mode | Writes to real store? | High-water | API call? |
|---|---|---|---|---|
| `journal-audit.py` | dry-run (DEFAULT) | No, operates on a temp copy | Not advanced | YES if candidates exist |
| `journal-audit.py --dry-run` | dry-run (explicit) | No | Not advanced | YES if candidates exist |
| `journal-audit.py --apply` | LIVE | Yes | Advanced | YES if candidates exist |
| `journal-audit.py --apply --since <ISO_TS>` | LIVE, floor overridden | Yes | Advanced | YES if candidates exist |

- `--apply` and `--dry-run` together exit 64 (mutually exclusive).
- **The daily timer runs `--apply`** (LIVE). Do not assume the scheduled run is a preview.
- **Dry-run still costs money if there are candidates.** The early-return "no candidates" branch runs BEFORE the API key is loaded, so a candidate-free dry-run is free; a dry-run with candidates loads the key and calls the model. Never loop dry-runs.

## The timer and service (verified via systemctl --user cat)

- `journal-audit.timer`: `OnCalendar=*-*-* 04:00:00 Asia/Jakarta`, `Persistent=true`, `AccuracySec=2min`. Persistent means a missed run (box asleep at 04:00) fires on next wake.
- `journal-audit.service`: `Type=oneshot`, `ExecStart=/usr/bin/python3 .../journal-audit.py --apply`, `Environment=HOME=/home/christopher TZ=Asia/Jakarta`. Note the service env does NOT export `ANTHROPIC_API_KEY`, so the script falls back to reading `secrets.env` (see below).
- Service stdout and stderr both append to `~/.local/share/journal-audit/run.log` (the full human report). The compact one-line-per-event journal is `~/.local/share/journal-audit/audit.log`.

## Model and API key sourcing

- Model: `claude-sonnet-4-6` via a direct POST to `https://api.anthropic.com/v1/messages` (urllib, no SDK), `anthropic-version: 2023-06-01`, `max_tokens 8000`, timeout 120s.
- API key resolution order: `ANTHROPIC_API_KEY` in the environment first; else parse `~/.claude/secrets.env` for an `ANTHROPIC_API_KEY=` line (handles `export ` prefix and quotes). The key is NEVER printed or logged. If neither source has it, the run dies with a FATAL (verified in the log: an early 401 on 2026-05-30 when the key was wrong).

## High-water mark (idempotency)

- State file: `~/.claude/memory/.journal-audit-state.json`, key `last_audited_ts` (plus `audited_at`, `last_backup`).
- "Un-audited" entries are those with a timestamp STRICTLY GREATER than the high-water. An entry stamped at or below it is never reprocessed. This is why back-dating an entry (violating SKILL.md §0.4) means it is never promoted.
- `--since <ISO_TS>` overrides the floor for one run (to reprocess a window). It does not rewrite the stored high-water except by the normal advance at the end of a live run.
- On a live run the high-water advances to the newest un-audited timestamp, EVEN in the "0 candidates" branch (so a batch of pure-ephemeral entries is not rescanned forever).

## What "0 candidates" means (the current idle state)

`parse_journal` builds entries only from lines matching `ENTRY_RE = ^- \[<ts>\] \(<tag>\) <summary>`. Then:
- `unaudited` = entries newer than the floor.
- `pre_skipped` = the unaudited entries tagged `ephemeral` (filtered out before the LLM).
- `candidates` = unaudited, non-ephemeral entries (these go to the model).

Verified live 2026-07-03: high-water frozen at `2026-06-15T07:54:59`, and the newest CONFORMING entry in journal.md is that exact decision entry. So `unaudited` is empty and `candidates` is 0 on every run since. The `## 2026-06-23 AURA Phase 4` block is dated later but is NON-CONFORMING, so it never becomes an entry at all (the silent-drop failure, SKILL.md §0.2). Result: "9 total, 0 un-audited, 0 candidates" every day. The capture front-end is idle; direct `/remember` writes dominate.

## The orphan safety-net (the audit's now-primary job)

Because journal capture is idle but memory files keep being written directly (by `/remember`, wa-behavior-learn, worker sessions), the audit runs a SECOND pass on EVERY run regardless of journal candidates:

1. `find_index_orphans()`: top-level `*.md` in the memory dir (excluding MEMORY.md, MEMORY.md.prev, journal.md) that are NOT linked from `MEMORY.md`.
2. In live mode, it regenerates `MEMORY.md` by shelling out to `~/.claude/scripts/gen-memory-index.py`. Best-effort: a failure is logged and reported but never rolls back the promotions and never crashes the audit.

### Why the logged orphan count is INFLATED (do not panic at "89 orphans")

The detector reads links from `MEMORY.md` ONLY. But the store deliberately SHARDS three namespaces out of MEMORY.md into `~/.claude/memory/indexes/` (`contact.md`, `credential.md`, `project.md`), a change from the 2026-06-24 memory-retrieval refactor (`project_memory_retrieval_refactor`) that fixed a real ~200-line MEMORY.md truncation. Verified 2026-07-03: 61 `contact_*`/`credential_*`/`project_*` files exist on disk, 0 are linked in MEMORY.md, and the orphan list is led by exactly those (`contact_cece.md`, `contact_hezkiel.md`, ... `project_aenoxa_*`). So most of the "89 orphans" are sharded files that ARE indexed, just in a shard the detector does not scan. They also remain retrievable: the BM25 engine (`memory-retrieve.py`) scans the memory FILES directly, not MEMORY.md, so a MEMORY.md-orphan is still found on-demand. The orphan-net matters for the startup MEMORY.md surface, not for on-demand recall.

### The real failure to watch: the --cap ceiling

`gen-memory-index.py` has `--cap` (default 24000 bytes). On 2026-06-24 the log recorded a genuine `FATAL: cannot fit index under 24000 bytes even at min line width (24012 bytes, 218 entries)`; the reindex aborted that run. The sharding that shipped the same day brought the main index back under cap (verified: `entries(main namespaces)=143` in a recent run.log). But the store keeps growing. If the FATAL recurs, that is the RED signal (SKILL.md §5.4). Root fix is a bigger `--cap` or further sharding, which is OUT of the journal skill's scope; surface it to Toper. NEVER hand-edit MEMORY.md, it is auto-generated (its header says so) and edits are overwritten.

## Safety properties (why a manual --apply is not scary, but still gated)

- **Conservative**: `create` only if the file is absent, else it degrades to an append; `update` appends a section, never a destructive overwrite.
- **Reversible**: before any live write it tars the whole memory dir to `~/.claude/memory-backups/memory-<stamp>.tar.gz`. The backup resolves the symlink so it captures the real files, not a 260-byte link.
- **Idempotent**: the high-water prevents reprocessing.
- **Fail-safe**: any exception during apply restores from the just-made backup and exits non-zero.

Still, a live run mutates the tracked, auto-pushed store, so treat a manual `--apply` as a real change: preview with `--dry-run` first, confirm the proposed promotions are correct, then apply. See `failure-playbooks.md`.

## journal.md is git-tracked and auto-pushed (secret stakes)

`~/.claude/memory/journal.md` resolves (readlink -f) to `~/claude/Git/repositories/chilldawg-setup/claude/memory/journal.md`: the whole memory dir is symlinked into the dotfiles repo. `memory-autopush.timer` commits and pushes the memory dir on `:00`/`:30`. A secret value written into an entry is therefore committed and pushed within about 30 minutes. This is the mechanical reason behind SKILL.md §0.3 (reference locations, never values) and the §5.2 pre-append secret scan.
