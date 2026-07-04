# Schema Reference — memory frontmatter (schema-v2)

The exact frontmatter contract that `gen-memory-index.py` (index) and
`memory-retrieve.py` (retrieval) parse. Write these fields; **do not invent new
ones** or the memory becomes invisible to one or both tools. Source of truth for
the parser behaviour: `memory-retrieve.py` `field()` (lines 196-213) and
`gen-memory-index.py` frontmatter parsing.

## Field-by-field

| Field | Type | Required | Retrieval weight | Purpose / notes |
|---|---|---|---|---|
| `name` | string (kebab slug) | **yes** | (identity, not scored) | **MUST equal the filename stem.** The stable key for retrieval, index, dedup, wikilinks. Historically drifted (slug vs human-title) — keep it == stem, always. |
| `title` | string | yes | **HIGH ×3** | Human-readable title shown in the index. First HIGH-weight field — put the distinctive name of the thing here. |
| `namespace` | enum | **yes** | (routes, not scored) | `identity` \| `feedback` \| `project` \| `reference` \| `contact` \| `credential`. Drives index grouping + sharding + the retrieval `--namespace` filter. Legacy `type:` is still accepted as a fallback by both tools. |
| `tier` | 1-3 | yes | (not scored) | 1 = durable rule / load-bearing infra recalled often; 2 = useful project/reference; 3 = niche / point-in-time. |
| `status` | enum | project only | (not scored) | `active` \| `archived`. Flip to `archived` when a project finishes (don't delete). Other namespaces omit it. |
| `description` | string | **yes** | **MED ×2** | One precise line. Used as the retrieval snippet AND ranked at MED weight. Put load-bearing terms here — it is the cheapest high-value place to hoist a rare term out of the body. |
| `tags` | list[str] | yes | **HIGH ×3** | Specific, high-IDF topical tags. No generic filler (see banned list). |
| `entities` | list[str] | yes | **HIGH ×3** | Names of people / tools / services / files / error codes the memory is about. |
| `aliases` | list[str] | yes | **HIGH ×3** | Alternate phrasings of the title + rare synonyms a future query might use. |
| `trigger_keywords` | list[str] | yes (≥3) | **HIGH ×3** | The exact short query terms that should surface this memory. The single most important enrichment field — this is where you defeat the relevance bug. |
| `hypothetical_questions` | list[str] | yes (≥2) | **HIGH ×3** | Real questions a future session will ask that this memory answers. Bridges the query-vs-statement gap (a query phrased like one of these scores very strongly). |
| `created` | YYYY-MM-DD | yes | — | Creation date (absolute, WIB). |
| `updated` | YYYY-MM-DD | yes | — | Last-updated date. `memory-decay.py` reads it for its age guard (G3). |

Retrieval weights verified in `memory-retrieve.py`: `_W_HIGH = 3`, `_W_MED = 2`,
`_W_LOW = 1` (lines 59-61); the HIGH blob = title + aliases + trigger_keywords +
hypothetical_questions + tags + entities (lines 293-301). BM25 params:
`k1 = 1.5`, `b = 0.75` (locked).

## Flat-v2 vs harness-nested (both retrieve — don't fight it)

Two on-disk layouts coexist in the corpus and BOTH are parsed correctly:

**Flat schema-v2** (what you write by hand):
```yaml
---
name: feedback_example
namespace: feedback
tier: 1
description: ...
trigger_keywords: [a, b, c]
---
```

**Harness-nested** (what `autoMemoryDirectory` may produce after a Write/Edit):
```yaml
---
name: feedback_example
metadata:
  node_type: memory
  type: feedback
  namespace: feedback
  tier: 1
  trigger_keywords: [a, b, c]
originSessionId: ...
---
```

`memory-retrieve.py field()` resolves every field **top-level first, then the
nested `metadata:` block** (lines 196-213). `gen-memory-index.py` mirrors the
nested `metadata:` children up to the top level for the index. So:

- **Do NOT hand-"un-nest"** a normalised file — it retrieves fine and un-nesting
  is churn that the next write re-nests anyway.
- The nesting **preserves** fields you wrote; it **cannot invent** fields you
  omitted. If you skipped `trigger_keywords`, nesting won't add them — the file
  is under-retrievable regardless of layout. (This is exactly why 6 live files
  are metadata-nested AND enrichment-empty — see the worked-examples file.)
- The two invariants that survive every layout: **`name` == filename stem** and
  **enrichment present**.

## Namespace ↔ filename-prefix ↔ shard routing

| Namespace | Canonical prefix | Index shard |
|---|---|---|
| `identity` | `user_` | `MEMORY.md` |
| `feedback` | `feedback_` | `MEMORY.md` |
| `reference` | `reference_` | `MEMORY.md` |
| `project` | `project_` | `indexes/project.md` |
| `contact` | `contact_` (legacy `whatsapp_style_` also = contact) | `indexes/contact.md` |
| `credential` | `reference_` + `namespace: credential` | `indexes/credential.md` |

Verified in `gen-memory-index.py`: `MAIN_NAMESPACES = ["identity","feedback",
"reference"]`, `SHARD_NAMESPACES = ["contact","credential","project"]` (project
was sharded 2026-06-24 when `MEMORY.md` hit the `SIZE_CAP = 24000`-byte loader
cap). The routing is by the **`namespace:` field**, not the filename prefix — a
`reference_`-prefixed file that declares `namespace: credential` renders into
`indexes/credential.md`. `identity` maps to the `user_` prefix (NOT `identity_`).

## The MEMORY.md loader cap (why sharding exists)

`MEMORY.md` is loaded whole into context, so it has a hard **24000-byte** cap
(`SIZE_CAP`). If a regen would exceed it, `gen-memory-index.py` trims per-line
hooks and/or you shard another namespace out to `indexes/`. This is why the
high-volume namespaces (`project`, `contact`, `credential`) are retrieval-served
via shards rather than always-resident in `MEMORY.md`. Never defeat this by
hand-editing `MEMORY.md`.
