# Tooling Map — the memory subsystem

Every script, hook, and timer around the memory store, with **verified**
interfaces. Canonical retrieval doc (do not duplicate it — cite it):
`~/.claude/scripts/README-memory-retrieval.md`. All scripts live in
`~/.claude/scripts/`. The store `~/.claude/memory/` is a symlink into
`chilldawg-setup/claude/memory/` and is its **own private git repo**.

## Scripts you run (manual)

### `memory-retrieve.py` — the BM25 engine + CLI
Your dedup tool and your retrievability self-test. Zero pip deps (PyYAML only,
with a stdlib fallback).
```
memory-retrieve.py "<query>" [-k N] [--json] [--namespace NS] [--expand] [--root DIR]
```
- `-k N` — number of results (default 5).
- `--json` — JSON array (what the injection hook consumes).
- `--namespace NS` — restrict to a namespace (repeatable).
- `--expand` — append 1-hop `[[wikilink]]` neighbours of the top hits.
- `--root DIR` — override the memory dir (testing only).
- Ranking: Okapi BM25 `k1=1.5 b=0.75` over a weighted term bag (HIGH ×3 title/
  aliases/trigger_keywords/hypothetical_questions/tags/entities, MED ×2
  description, LOW ×1 body). Light suffix stemmer folds `rules→rule`,
  `messaging→messag`. **CONTACT-KEY boost**: a query token matching a
  `namespace: contact` doc's name (from `title` + `aliases` only, minus a
  role/product stoplist) gets a strong additive boost — so "message Ryan"
  surfaces the Ryan contact.
- **KNOWN LIVE BUG**: no conversational-filler stripping, no rare-term boost →
  a body-only rare term loses to filler. Author around it (see the guardrail).

### `gen-memory-index.py` — regenerate the index + shards
Rebuilds `MEMORY.md` + `indexes/contact.md` + `indexes/credential.md` +
`indexes/project.md` from every file's frontmatter, then **verifies before
replacing** (backs the old up to `MEMORY.md.prev`).
```
gen-memory-index.py            # regenerate + replace (the default you want)
gen-memory-index.py --check    # assert-only: render + verify, write NOTHING
gen-memory-index.py --print    # print rendered MEMORY.md to stdout, write nothing
gen-memory-index.py --cap N    # override the byte size cap (default 24000)
```
- `MAIN_NAMESPACES = identity, feedback, reference` → `MEMORY.md`.
  `SHARD_NAMESPACES = contact, credential, project` → `indexes/<ns>.md`.
- Parses flat-v1 (`type:`), flat-v2 (`namespace:`), and harness-nested
  (`metadata:`) layouts; mirrors nested children up.
- **Run it yourself after an UPDATE** — the PostToolUse hook only auto-regens for
  a NEW file. There is NO `--json` flag.

### `memory-decay.py` — conservative archive (your `clean` engine)
**Archives, never deletes.** Default is DRY-RUN.
```
memory-decay.py                 # dry-run: list archive candidates + reasons
memory-decay.py --apply         # move candidates to archive/ + regen index
memory-decay.py --min-age-days N # age guard (default 21)
memory-decay.py --json          # machine-readable candidate list (implies dry-run)
```
- Stale signals (needs ≥1): **S1** `project_session_state_*.md` snapshots; **S2**
  self-declared superseded/merged (a REDIRECT stub / "merged into [[x]]" in the
  frontmatter description or a heading — NOT incidental body prose).
- Safety guards (ALL must hold, else KEEP): **G1** not `[[wikilinked]]` from any
  other live file; **G2** never a `user_`/`feedback_` behavioral rule unless it
  self-declares superseded; **G3** older than `--min-age-days`; **G4** a real
  top-level `*.md`, not the index/journal.
- Archived files go to `archive/` (excluded from the index by the non-recursive
  glob), stay in git history, and restore with a single `mv archive/<f> ..` +
  regen. An audit trail is appended to `archive/DECAY_LOG.md`.

### `memory-eval.py` — retrieval regression gate
```
memory-eval.py                 # recall@1/3/5 + MRR + per-miss list on eval/golden.json
memory-eval.py --json          # machine-readable {metrics, misses}
memory-eval.py --build [--n 30] [--seed 7]   # (re)build the golden set from the corpus
memory-eval.py --golden PATH -k 5            # eval a specific golden set
```
Run it after any bulk-memory change or engine change; each change must hold or
improve recall@k / MRR. The per-miss list names the expected file, its actual
rank, and what surfaced instead — misses are diagnosable, not just counted.

### `journal-add.sh` — the `/journal` appender (manual, via /journal)
```
journal-add.sh <tag> "<summary>" ["<detail>"]     # tag: decision|feedback|project|reference|ephemeral
```
Appends one WIB-timestamped line to `journal.md` in the exact format the daily
audit parses. Append-only. Prefer the `/journal` skill over calling it directly.

## Hooks (automatic — wired in settings.json)

### `memory-inject-hook.sh` — `UserPromptSubmit` (retrieval)
On **every** prompt: runs `memory-retrieve.py -k 5 --json` over the prompt and
injects a pointer + one-line-snippet block as `additionalContext`. **Skips**
prompts under 12 chars and pure slash-commands under 60 chars. Hard **fail-open**
(any error → emit nothing, exit 0). Never dumps bodies — the agent reads the
file if it needs detail. This is why enrichment matters: this hook is how a
memory reaches a future you.

### `memory-write-validate.sh` — `PostToolUse(Edit|Write)` (validate + secret-scan + reindex)
Fires ONLY for writes under the memory dir. It:
- **(a) validates frontmatter** — warns (never blocks) if `name` /
  `description` / (`namespace`|`type`) are missing or the block is unclosed;
- **(b) secret/PII scans** — `sk-ant-` / `ghp_`/`gho_`/`ghu_`/`ghs_`/`ghr_` /
  `github_pat_` / generic `sk-` / `AKIA` / `AIza` / `xox` / PEM /
  `password=<literal>` / Indonesian phone numbers; surfaces a leak warning as
  additionalContext;
- **(c) debounced index regen** — but ONLY when the file is new/unindexed
  (`grep "(<basename>)" MEMORY.md` misses) or was deleted-and-dangling; 20s
  debounce, backgrounded. **An UPDATE to an already-indexed file does NOT
  trigger a regen** — you must run `gen-memory-index.py` yourself.
Hard fail-open, always exit 0, invisible outside the memory dir.

## Timers (automatic — systemd user units)

| Timer | Schedule | Runs | Effect |
|---|---|---|---|
| `memory-autopush.timer` | every 30 min (Persistent) | `memory-autopush.sh` | commit + push the store to its **private** remote `TopengDev/claude-memory` (idempotent; catch-up push if offline). Sets `CLAUDE_COMMIT_SKILL=1` so the raw-commit guard allows the unattended autosync. |
| `journal-audit.timer` | daily 04:00 WIB (Persistent) | `journal-audit.py --apply` | promote un-audited `journal.md` entries into canonical memory files. Backs up the store first; only ADD/APPEND, never delete; idempotent via a high-water mark. |
| `memory-decay.timer` | weekly Sun 04:30 WIB (Persistent) | `memory-decay.py --apply` | archive high-confidence-stale files + regen index. Same conservatism as manual `clean`. |

Implication for you: the store **self-maintains** (autopush + daily consolidate
+ weekly decay). Your `/remember clean` is the on-demand version of the weekly
decay; your direct writes are consolidated by neither timer (dedup is on you).

## What is NOT here / NOT wired

- **auto-dream is OFF** — `autoDreamEnabled` is absent from `settings.json`,
  deliberately superseded by the journal+audit loop. Do not re-enable it.
- **No embeddings / no network in the hot path** — v1 is BM25-only on purpose
  (the injection hook runs on every prompt). The dense/hybrid/rerank upgrade
  path is documented in `README-memory-retrieval.md`, deferred to stay
  dependency-free and sub-second.
