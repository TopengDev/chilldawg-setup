# Memory Retrieval (Phase E) — local BM25 engine + proactive injection hook + eval

A self-contained, **zero-API**, zero-pip-dependency retrieval layer over
Christopher's memory store (`~/.claude/memory/`). It surfaces the most relevant
memory files for any query, and a `UserPromptSubmit` hook injects those pointers
into the agent's context on every prompt — so durable rules/contacts/project
facts are recalled proactively instead of relying on the agent to grep.

> v1 is **BM25-only, on purpose**. The injection hook runs on *every* prompt
> (the hot path); putting a network embedding call there would add latency +
> a hard API dependency + a failure surface to every single prompt. v1 keeps
> the hot path purely local and sub-second. The dense/hybrid upgrade path is
> documented at the bottom and is strictly additive.

---

## Components

| File | Role |
|---|---|
| `memory-retrieve.py` | The engine + CLI. Inline Okapi BM25 (k1=1.5, b=0.75) over a weighted term bag built from the schema-v2 frontmatter. No pip deps (PyYAML only, for frontmatter; has a pure-stdlib fallback). |
| `memory-inject-hook.sh` | `UserPromptSubmit` hook. Runs the engine on the prompt, injects a concise pointer list via `additionalContext`. Hard fail-open. |
| `memory-eval.py` | Eval harness. `--build` auto-generates `eval/golden.json`; default run reports recall@1/3/5 + MRR + a per-miss list. |
| `eval/golden.json` | Auto-built golden set: ~30 hypothetical-question queries sampled across namespaces + ~6 hand-written natural queries. |

The corpus = every `*.md` under `~/.claude/memory/` **except** `archive/`,
`indexes/`, `MEMORY.md`(`.prev`/`.tmp`), `journal.md`, and any `*.prev`. At time
of writing that is **193 docs** across 6 namespaces (contact, credential,
feedback, identity, project, reference).

---

## How ranking works

### Weighted term bag (per doc)

Each doc's searchable text is built from its frontmatter with field weights
(weight = how many times the field's tokens are added to the bag):

| Weight | Fields |
|---|---|
| **HIGH (×3)** | `title`, `aliases`, `trigger_keywords`, `hypothetical_questions`, `tags`, `entities` |
| **MEDIUM (×2)** | `description` |
| **LOW (×1)** | body |

`trigger_keywords` and `hypothetical_questions` are the high-signal retrieval
fields the schema-v2 migration added, so they dominate the bag — a query phrased
like one of a doc's hypothetical questions scores very strongly.

### Tokenisation + stemming

- lowercase, split on non-alphanumeric, keep tokens of length ≥ 2.
- Each token is stored **both raw and stemmed** (a small conservative suffix
  stemmer: `committing→commit`, `rules→rule`, `messaging→messag`). The same
  stemming is applied to the query, so inflected forms match symmetrically.

### BM25

Standard Okapi BM25 with `k1=1.5`, `b=0.75`, smoothed IDF clamped at ≥0 (so a
term present in >half the corpus can't push a score negative). Document length =
total weighted term count, normalised against the corpus average.

### CONTACT-KEY boost

If a query token matches the **name** of a person who owns a `namespace: contact`
doc (name tokens drawn from that doc's `title` + `aliases` only — *not*
`entities`, which list associated things like "Pulse POS"), that contact doc
gets a strong additive boost scaled to the result set's top BM25 score. This is
why `"message Ryan"` surfaces the Ryan contact at rank 1 even though "message"
out-weights "ryan" in a pure bag-of-words sense.

Generic role/product words (`pulse`, `aenoxa`, `cofounder`, `qa`, …) are
stop-listed out of the person-key set, so a topical query like
`"pulse dark theme reskin"` does **not** wrongly boost a contact who happens to
be a Pulse user.

### 1-hop expansion (`--expand`)

Optional. After the top-k, it appends the `[[wikilink]]` neighbours of those top
results (deduped, each re-scored against the query, ranked below the originals).
Off by default and **not** used by the hook (keeps injected context tight).

---

## CLI usage

```bash
# human-readable (default)
memory-retrieve.py "how do I message my Aenoxa cofounder"

# top 8, restricted to a namespace
memory-retrieve.py "fitest authoring rules" -k 8 --namespace reference

# JSON (what the hook consumes)
memory-retrieve.py "rule about committing" -k 5 --json

# include 1-hop wikilink neighbours
memory-retrieve.py "pulse dark theme" --expand
```

Flags: `-k N` (default 5), `--json`, `--namespace NS` (repeatable),
`--expand`, `--root DIR` (override the memory dir, for testing).

**Latency** (this box, 193 docs): full CLI invocation ≈ **0.73s**, of which the
per-query BM25 scan is ≈ **0.4ms** — essentially all the cost is Python startup
+ PyYAML parsing the 193 frontmatters (~408ms). Well under the 1s budget. (See
the v2 path for how a persisted index removes the rebuild.)

---

## The injection hook

`memory-inject-hook.sh` is a `UserPromptSubmit` hook. On every prompt it:

1. reads the hook stdin JSON, extracts `.prompt` (falls back to `.user_prompt`);
2. **skips** trivial prompts — empty, < 12 chars (`"ok thanks"`), or a pure
   short slash-command (`/commit`), which carry their own context;
3. runs `timeout 5 python3 memory-retrieve.py "$prompt" -k 5 --json`;
4. formats the hits into a concise `additionalContext` block:

   ```
   Auto-retrieved memories possibly relevant (read the file for full detail):
   - Ryan (ISI QA Lead) [contact] (whatsapp_style_ryan.md) — ISI QA lead (fitest/BMS) — deep Sundanese register, structured test-suite directives; …
   - ISI Coworker Tier — Auto-Respond + Notify Toper [feedback] (feedback_isi_coworker_tier.md) — WhatsApp contact tier for Toper's coworkers …
   …
   ```

   It injects **pointers + one-line snippets only** — never full bodies. The
   agent reads the file(s) for detail if it needs them.

### Fail-open contract (hard)

Modelled on `memory-write-validate.sh`: `set -u`, an `ERR` trap → `exit 0`, and
every code path exits 0. **Any** of these → emit nothing, exit 0, never block or
slow the prompt:

- missing `jq` / `python3` / `timeout` / the engine file,
- unparseable stdin, missing/empty `.prompt`,
- engine error / timeout / empty or `[]` result,
- jq formatting failure.

Losing a retrieval is acceptable; disrupting a prompt is not.

### Wiring it (see the snippet in the handover report)

The hook must be **added to** the existing `hooks.UserPromptSubmit` array in
`~/.claude/settings.json` (there's already a `oneshot-webapp-rules-hook.sh`
entry there — do not replace it). Hooks load at session start, so **restart
Claude Code** after wiring.

### Disabling the hook

Pick any one:

1. **Remove the entry** from `hooks.UserPromptSubmit` in
   `~/.claude/settings.json`, then restart Claude Code. (Clean / permanent.)
2. **Neuter without editing settings** — make the hook a no-op:
   ```bash
   chmod -x ~/.claude/scripts/memory-inject-hook.sh   # type:"command" still runs via bash, so also:
   ```
   The robust no-edit kill switch is an env guard — add near the top of the
   script `[ "${MEMORY_INJECT_DISABLE:-0}" = "1" ] && exit 0`, then export
   `MEMORY_INJECT_DISABLE=1`. (Not wired by default; the settings-removal route
   above is the supported off switch.)
3. **Temporarily**, just rename the engine — the hook fails open if
   `memory-retrieve.py` is absent:
   ```bash
   mv ~/.claude/scripts/memory-retrieve.py{,.off}
   ```

---

## Running the eval

```bash
# (re)build the golden set from the live corpus (deterministic; seeded)
memory-eval.py --build            # writes eval/golden.json (~30 sampled + 6 hand-written)

# run the eval → recall@1/3/5, MRR, per-miss list
memory-eval.py                    # human report
memory-eval.py --json             # machine-readable {metrics, misses}
```

The golden set takes ONE `hypothetical_question` from each sampled doc as a
query whose `expected_file` is that doc, then appends hand-written natural
queries (e.g. *"how do I message my Aenoxa cofounder"*). The eval imports the
engine in-process, so a full run is ≈ **0.77s**.

This is the **baseline miss-rate metric** — re-run it after any engine change to
catch regressions. The per-miss list names, for each query that didn't land at
rank 1, the expected file, its actual rank (or "not in top-5"), and what
surfaced instead — so misses are diagnosable, not just counted.

> Note: BM25 cannot close pure **synonym** gaps (e.g. a query saying
> "development work" against a doc that only says "implementation"). Such a miss
> is an expected v1 limitation and is exactly what the dense path below fixes.

---

## v2 upgrade path (documented, not built)

v1 is deliberately BM25-only to keep the every-prompt hook local + sub-second.
The upgrade is **additive** and staged so each step is independently shippable:

1. **Persisted index (do this first — pure latency win, no quality change).**
   The cold-start cost is ~0.6s, ~70% of it PyYAML parsing 193 frontmatters.
   Cache the parsed term bags + IDF table to a pickle/JSON keyed on a corpus
   fingerprint (file mtimes/hashes); rebuild only changed docs. Warm retrieval
   then drops to the ~0.4ms scan. This makes the hook effectively free and
   removes the only real latency concern before adding heavier stages.

2. **Dense embeddings (semantic recall).** Embed each doc (title + description +
   hypothetical_questions is a strong, cheap unit to embed) with a local model
   (e.g. a small sentence-transformer / fastembed — keep it **local** to honour
   the no-API-in-hot-path rule) or a batched offline API job that writes vectors
   into the persisted index. At query time, embed the query and cosine-rank.
   This is what closes the synonym gaps BM25 structurally can't
   ("development"↔"implementation").

3. **Hybrid dense + BM25 (the real v2).** Fuse the two rankings —
   Reciprocal Rank Fusion (RRF) is the simplest robust choice (no score
   normalisation needed), or a weighted convex sum of normalised scores. Keep
   the CONTACT-KEY boost as a post-fusion adjustment. Hybrid reliably beats
   either signal alone: BM25 nails exact-term/keyword/code-token queries, dense
   nails paraphrase/intent queries.

4. **Cross-encoder rerank (precision top of funnel).** Take the top ~20 hybrid
   candidates and re-score each `(query, doc)` pair with a cross-encoder
   reranker, then return the top-k. This is the highest-quality stage but the
   most expensive, so it runs only over a small candidate set — and, to respect
   the hot-path constraint, ideally only on an explicit `memory-retrieve.py`
   call, **not** inside the every-prompt hook (or behind an opt-in flag).

Throughout: the eval harness (`memory-eval.py`) is the guardrail — each stage
must move recall@k / MRR up (or hold) on the golden set before it ships, and the
golden set should grow with real missed queries over time.
