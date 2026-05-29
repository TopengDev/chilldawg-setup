---
name: remember
description: Save, review, or clean up persistent memories. Use when you need to remember something, the user asks to save/forget something, or at end of conversation to review what should be persisted.
argument-hint: [what to remember, or "review" to scan conversation for unsaved insights]
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Memory Management Skill

Systematically save, update, and clean up persistent memories.

## Memory Directory

- **Index:** `~/.claude/memory/MEMORY.md`
- **Files:** `~/.claude/memory/<type>_<topic>.md`

## Modes

### 1. Save (`/remember <what to remember>`)

When given something specific to save:

1. Read `MEMORY.md` to check for duplicates or existing memories to update
2. Determine the type: `user`, `feedback`, `project`, or `reference`
3. Check if an existing memory file covers this topic — **update** instead of creating a duplicate
4. Write/update the memory file with proper frontmatter:

```markdown
---
name: <clear, specific name>
description: <one-line — used for relevance matching, be precise>
type: <user | feedback | project | reference>
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
tags: [<relevant-tags>]
---

## Summary
<2-3 sentence overview>

## Details
<structured content>

## Context
<why this matters>
```

5. Update `MEMORY.md` index — one line per entry, under 150 chars

### 2. Review (`/remember review`)

Scan the current conversation for unsaved insights. Check for:

- **Decisions made** (project direction, architecture, strategy) → `project` type
- **Corrections or confirmations** ("don't do X", "yes that approach works") → `feedback` type
- **New people, tools, services, external systems** → `reference` type
- **User preferences or profile details** → `user` type
- **Credentials or access details shared** → `reference` type

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
- **Keep MEMORY.md under 200 lines** — truncation happens after that
- **For feedback type:** include **Why** and **How to apply** lines
- **For project type:** include **Why** and **How to apply** lines

## Shared Memory (for tmux-spawned agents)

When spawning agents in tmux sessions, they can write to the same memory directory. To include shared context in their prompt, append:

```
Shared memories to be aware of (read these files for context):
- ~/.claude/memory/user_christopher.md
- ~/.claude/memory/reference_vps.md
- ~/.claude/memory/reference_cloudflare.md

If you learn something worth persisting across sessions, write it to:
~/.claude/memory/
and update MEMORY.md index.
```

Only include memories relevant to the agent's task, not all of them.
