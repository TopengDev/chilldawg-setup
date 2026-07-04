# Retrieval & Consolidation — how the store thinks

Write FOR the engine. This file explains how ranking works, the live relevance
bug and its authoring mitigation, and how the consolidation loop keeps the store
alive. Canonical engine doc: `~/.claude/scripts/README-memory-retrieval.md`.

## How BM25 ranks (so you can beat it)

`memory-retrieve.py` builds a **weighted term bag** per doc from its frontmatter,
then scores with Okapi BM25 (`k1=1.5`, `b=0.75`).

- **Field weights** (how many times a field's tokens enter the bag):
  HIGH ×3 = `title`, `aliases`, `trigger_keywords`, `hypothetical_questions`,
  `tags`, `entities`; MED ×2 = `description`; LOW ×1 = body.
- **IDF** rewards rare terms and discounts common ones (a term in >half the
  corpus contributes ≈0). This is why **specific, high-IDF enrichment wins** and
  generic filler (`memory`, `workflow`) actively hurts — filler has low IDF AND
  it dilutes the IDF of everything.
- **Stemming**: a small suffix stemmer stores each token raw + stemmed
  (`rules→rule`, `messaging→messag`), applied symmetrically to the query, so
  inflected forms match.
- **hypothetical_questions** is the highest-leverage field: a query phrased like
  one of a doc's hypothetical questions scores very strongly (it's HIGH-weight
  AND it pre-writes the query the future you will type).
- **CONTACT-KEY boost**: a query token matching a `namespace: contact` doc's name
  (from `title` + `aliases` only, minus a role/product stoplist) gets a strong
  additive boost scaled to the top BM25 score — so "message Ryan" surfaces the
  Ryan contact even though "message" out-weighs "ryan" in a pure bag.

Practical consequence: **you are writing for the HIGH-weight fields.** A fact is
"saved" only when the exact tokens a future query will use are up in
title/aliases/trigger_keywords/tags/entities + description — not just true in the
body.

## The live relevance bug (in depth) + your mitigation

**Status: LIVE** as of the 2026-06-24 engine. Root cause
([[reference_memory_retrieval_relevance_bug]]): the engine does **no
conversational-filler stripping** and **no rare-term (high-IDF) boost** at query
time — `search()` just tokenizes the raw query. So a rare term that lives ONLY in
a file body (weight 1) is out-scored by common conversational words in the query
("do you remember about…") that match OTHER files' HIGH-weight fields.

Verified failure: `memory-retrieve.py "do you remember about execfi"` returned
generic memory files and ZERO of the 5 execfi files; `memory-retrieve.py
"execfi"` alone returned all 5 correctly. Tokenization is fine — the ranking is
the problem.

**The engine fix is pending** (strip filler like "do you remember about X" →
"X", and/or bump body weight + add a rare-term boost; test gate: the execfi query
must surface the 5 files). Until it ships, the **authoring mitigation is the only
defense and it is mandatory**: hoist every rare, load-bearing term into
`trigger_keywords` + `description` + `aliases`/`entities`. A memory written that
way is recalled correctly *today*, and stays correct after the engine fix.

Do NOT edit the engine from this skill — if the bug bites a specific memory, fix
the memory's enrichment. Engine changes are a separate, eval-gated task.

## The consolidation loop (journal + audit) — and what it does NOT do for you

Adopted from elpabl0's concept ([[feedback_memory_consolidation_loop]]),
replacing auto-dream (which stays **OFF** — not in `settings.json`).

- **Capture half** = `/journal` → `journal-add.sh` appends tagged lines to
  `journal.md` as things happen (append-only).
- **Consolidate half** = `journal-audit.py --apply`, a **daily 04:00 WIB** timer.
  It reads un-audited entries (past a high-water mark), classifies state-bearing
  vs ephemeral, and promotes the keepers into canonical memory files. It backs up
  the whole store first, only ADD/APPENDs (never deletes/overwrites), and is
  idempotent (never re-promotes, never edits `journal.md`).

What this means for `/remember`:
- The loop consolidates **journal** entries, NOT your direct `/remember` writes.
  A direct write is **not** auto-deduped or auto-merged — the dedup gate (HARD
  RULE 1) is on you.
- Auto-dream must stay OFF. Don't re-enable `autoDreamEnabled` — the loop
  supersedes it and enabling both is redundant churn on the store.

## Decay (the weekly janitor)

`memory-decay.py --apply` runs **weekly (Sun 04:30 WIB)** and archives (never
deletes) only high-confidence-stale files (S1 session-state snapshots, S2
self-declared superseded) that pass all guards (G1 not wikilinked, G2 not a
durable rule, G3 old enough). Your `/remember clean` is the on-demand version.
Because decay respects wikilinks (G1) and self-declared-superseded (S2), the
correct way to retire a merged file is a **REDIRECT stub** (see
`worked-examples.md` §C), which decay will archive once nothing links to it.

## The /journal vs /remember boundary (in depth)

| | `/journal` | `/remember` |
|---|---|---|
| Motion | fast, continuous append | deliberate durable write NOW |
| Target | `journal.md` (one line) | a canonical `<ns>_<topic>.md` file |
| Enrichment | none (audit adds it later) | full schema-v2 + Pre-Write Gate, this turn |
| Indexed | after the daily audit promotes it | immediately (you regen) |
| Dedup | the audit dedups on promotion | you dedup before creating |
| Use when | mid-flow, don't want to stop | "remember X" as a durable fact right now |

Rule of thumb: if you want it **recallable on the very next prompt**, use
`/remember` (write + enrich + regen now). If you just want a breadcrumb the
daily audit will consolidate, use `/journal`. Never write the same fact through
both in the same session — pick one.

## Cross-references (pointers, not duplication)

- Retrieval engine internals + the dense/hybrid upgrade path:
  `~/.claude/scripts/README-memory-retrieval.md`.
- The refactor that built this system (schema-v2, sharded index, BM25 engine,
  injection hook, eval): [[project_memory_retrieval_refactor]].
- Proactive-save discipline: [[feedback_auto_memory]]. Consolidation loop:
  [[feedback_memory_consolidation_loop]]. auto-dream mechanism (kept OFF):
  [[reference_auto_dream]].
