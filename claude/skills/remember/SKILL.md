---
name: remember
description: Save, review, or clean up persistent memories. Use when you need to remember something, the user asks to save/forget something, or at end of conversation to review what should be persisted.
argument-hint: [what to remember, or "review" to scan conversation for unsaved insights]
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Memory Management Skill

Systematically save, update, and clean up persistent memories.

## Memory Directory

- **Index:** `~/.claude/memory/MEMORY.md` (auto-generated — never hand-edit; run `~/.claude/scripts/gen-memory-index.py` to regenerate from frontmatter)
- **Files:** `~/.claude/memory/<namespace>_<topic>.md` (e.g. `feedback_no_dev_in_main.md`, `project_skills.md`)

## Modes

### 1. Save (`/remember <what to remember>`)

When given something specific to save:

1. Read `MEMORY.md` to check for duplicates or existing memories to update
2. Determine the `namespace`: `identity`, `feedback`, `project`, `reference`, `contact`, or `credential`
3. Check if an existing memory file covers this topic — **update** instead of creating a duplicate
4. Write/update the memory file with **schema v2** frontmatter:

```markdown
---
name: <filename stem slug — MUST equal the file's basename without .md>
title: <human-readable title (shown in the index)>
namespace: <identity | feedback | project | reference | contact | credential>
tier: <1-3 importance, 1 = top>
status: <active | archived>   # project namespace only
description: <one-line — used for relevance matching, be precise>
tags: [<topical tags>]
entities: [<names of people / tools / services / files this is about>]
aliases: [<alternate phrasings of the title>]
trigger_keywords: [<short query terms that should surface this memory>]
hypothetical_questions:
  - <a question a future session might ask that this memory answers>
  - <another — these bridge the query-vs-statement gap for retrieval>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

## Summary
<2-3 sentence overview>

## Details
<structured content>

## Context
<why this matters>
```

The five enrichment fields (`tags` / `entities` / `aliases` / `trigger_keywords` / `hypothetical_questions`) feed the local BM25 retrieval engine (`~/.claude/scripts/memory-retrieve.py`) — fill them; they are how a memory gets found.

> **Harness nesting is fine.** When you write a memory through the Write/Edit tool, Claude Code's `autoMemoryDirectory` normaliser may re-nest these fields under a `metadata:` block (and re-add `node_type` / `originSessionId`). The retrieval tooling reads BOTH the flat top-level keys AND the nested `metadata:` block, so either layout retrieves correctly — don't fight it. The one hard invariant: **`name` must equal the filename stem** (everything keys off the stem slug).

5. Regenerate the index with `~/.claude/scripts/gen-memory-index.py` (do NOT hand-edit `MEMORY.md` — it is auto-generated from frontmatter and verified before replace)

### 2. Review (`/remember review`)

Scan the current conversation for unsaved insights. Check for:

- **Decisions made** (project direction, architecture, strategy) → `project` namespace
- **Corrections or confirmations** ("don't do X", "yes that approach works") → `feedback` namespace
- **New tools, services, external systems** → `reference` namespace
- **A person (name, how to talk to them, JIDs)** → `contact` namespace
- **User preferences or profile details** → `identity` namespace
- **Credentials or access details shared** → `credential` namespace

For each found:
1. Check MEMORY.md — is it already saved?
2. If not, save it
3. If partially saved, update the existing memory
4. Report what was saved/updated

### 3. Forget (`/remember forget <topic>`)

1. Find the memory file matching the topic
2. Confirm with user before deleting
3. Remove the file and its entry from MEMORY.md

### 4. Clean (`/remember clean`)

1. Read all memory files
2. Flag stale memories (outdated info, resolved projects, old feedback that no longer applies)
3. Flag duplicates
4. Present findings — let user decide what to remove
5. Remove confirmed stale entries

## Rules

- **Never save code patterns, file paths, or git history** — these are derivable from the codebase
- **Never save ephemeral task details** — use tasks for in-progress work
- **Convert relative dates to absolute** — "next Thursday" → "2026-04-03"
- **One topic per file** — don't dump unrelated things together
- **`name` must equal the filename stem** — everything keys off the stem slug; keep them in sync
- **Fill the enrichment fields** (`tags` / `entities` / `aliases` / `trigger_keywords` / `hypothetical_questions`) — they are how the BM25 engine finds the memory
- **Don't hand-edit `MEMORY.md`** — it's auto-generated + sharded (contacts/credentials → `indexes/`); regenerate via `gen-memory-index.py`
- **For feedback namespace:** include **Why** and **How to apply** lines
- **For project namespace:** include **Why** and **How to apply** lines

## Shared Memory (for tmux-spawned agents)

When spawning agents in tmux sessions, they can write to the same memory directory. To include shared context in their prompt, append:

```
Shared memories to be aware of (read these files for context):
- ~/.claude/memory/user_christopher.md
- ~/.claude/memory/reference_vps.md
- ~/.claude/memory/reference_cloudflare.md

If you learn something worth persisting across sessions, write it to:
~/.claude/memory/<namespace>_<topic>.md  (schema v2 frontmatter — see the Save section)
then regenerate the index: ~/.claude/scripts/gen-memory-index.py
```

Only include memories relevant to the agent's task, not all of them.
