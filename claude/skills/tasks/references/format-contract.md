# Format contract (reference)

The task-file and INDEX.md format is a FROZEN DOWNSTREAM CONTRACT. Three components read these files read-only and depend on the exact shape. `/tasks` is their SOLE WRITER. A silent format change here breaks all three with no error and no exception thrown. Do not "improve" or reformat the structure. If it genuinely must change, that is a cross-skill task: update all three consumers in lockstep FIRST, and flag it to Christopher (the consumers live outside this skill directory).

---

## 1. The exact task-file format

```markdown
---
project: {Project Name}
description: {one-line}
status: {active | planning | maintenance | paused | completed}
client: {name, optional}
deadline: {YYYY-MM-DD, optional, may be empty}
---

## NOW
- [ ] {task} `{YYYY-MM-DD}`

## NEXT
- [ ] {task} `{YYYY-MM-DD}`

## LATER
- [ ] {task} `{YYYY-MM-DD}`

## WAITING
- [ ] {task}, waiting on: {who}, follow up: {YYYY-MM-DD} `{YYYY-MM-DD}`

## Completed
- [x] {task} `{YYYY-MM-DD completed}`
```

Load-bearing invariants:
- **Frontmatter** delimited by `---` lines. `project:` is read by `/daily-brief` + `/standup` (fallback = filename). Any value containing a colon must be safe; keep values simple.
- **Five tier headers**, exact spelling and case: `## NOW`, `## NEXT`, `## LATER`, `## WAITING`, `## Completed`. Present even when empty. `## LATER` is not currently read by a consumer but is part of the model, keep it.
- **Checkbox**: `- [ ]` open, `- [x]` done. Exactly one space in the brackets.
- **Trailing backtick date**: `` `YYYY-MM-DD` `` at the end of the line. For open items it is the added-date; for `[x]` items it is the completion-date. Optional per the parsers (they tolerate its absence) but ALWAYS write it.
- **WAITING phrasing**: the literal substring `waiting on:` must survive (consumers extract the "who" from it). Separate clauses with a comma, never a dash.

---

## 2. The three read-only consumers (what each parses, what breaks)

| Consumer | Path + scan | Reads | Breaks if... |
|---|---|---|---|
| **`/daily-brief`** (systemd 06:00 + 21:00 WIB) | Glob `~/.claude/tasks/*.md`, excludes `INDEX.md` + `archive/` | frontmatter `project:`; `## NOW`/`## NEXT`/`## WAITING`/`## Completed`; `- [ ] desc \`YYYY-MM-DD\``; morning `tasks_due_today` = open items whose backtick date == today OR undated `## NOW` items; `now_count` = open items under `## NOW`; `waiting` = `## WAITING` items with "who" extracted | a tier header is renamed/removed, the checkbox shape changes, or the backtick date moves. Morning WhatsApp brief silently loses items. States "never modify, read-only" (line 227). |
| **`/standup`** | Glob `~/.claude/tasks/*.md`, excludes `INDEX.md` + `archive/` | frontmatter `project:` (fallback filename); parses all four active tiers + `## Completed`; line shape `- [ ] desc … \`YYYY-MM-DD\``; morning `yesterday_closed` reads `## Completed` items dated yesterday | same as above. Also treats `~/claude/state/work-queue.md` as the canonical kanban (separate source A); tasks `*.md` is source B. States "never modify, read-only" (line 209). |
| **`~/.claude/scripts/loop-digest.sh`** | `find ~/.claude/tasks -maxdepth 1 -name '*.md' ! -name INDEX.md` | files whose mtime falls in the lookback window; pulls `- [x]` lines, strips the checkbox + trailing backtick-date, truncates. Uses file mtime as the completion-time proxy | the `[x]` shape or trailing-date changes. Idle loop-digest silently misreports completions. |

Note the mtime proxy in loop-digest: any write to a task file bumps its mtime, so an unrelated edit can make old `[x]` items appear "recent". This is a known conservative approximation in loop-digest, not something to fix here, but a reason to keep writes targeted (Edit under a header) rather than rewriting whole files unnecessarily.

---

## 3. INDEX.md format

```markdown
# Task Dashboard

Last updated: {YYYY-MM-DD}

| Project | Status | NOW | NEXT | WAITING | Next Action |
|---------|--------|-----|------|---------|-------------|
| {Name} | {status} | {n} | {n} | {n} | {action} |

## This Week
1. {top priority}
2. {second}
3. {third}

<!-- KEYWORDS MAP
{keyword, keyword} → {file}.md
-->
<!-- last-archived: {YYYY-MM} -->
```

- INDEX.md is EXCLUDED by `/daily-brief`, `/standup`, and `loop-digest.sh` (all name-exclude it), so its format is internal to this skill, not a shared contract. You have freedom here that you do NOT have in the project files.
- The `<!-- KEYWORDS MAP -->` comment is the single live source of truth for auto-file routing (see `auto-file-rubric.md` Section 1).
- The `<!-- last-archived: YYYY-MM -->` comment is the archive run-marker (SKILL.md Section 3.8), it prevents a double-run in the same month.

---

## 4. The `*.md` glob-safety proof (why the scan scoping is an invariant)

`~/.claude/tasks/` holds this skill's `*.md` files AND (144 at rebuild time, growing) harness TaskCreate subdirectories: `session-*/` and `<uuid>/`, each containing `N.json`, `.lock`, `.highwatermark`. Those are the in-session execution store behind the 3-tier delegated-worker hierarchy. Reading or writing one corrupts a live worker's task state.

Why `*.md` at maxdepth 1 is collision-safe:
- The harness subdirs contain `.json`, `.lock`, `.highwatermark`, verified NOT any `.md`. A depth-2 scan for `*.md` returns ZERO files (verified `find ~/.claude/tasks -mindepth 2 -name '*.md'` = 0).
- A maxdepth-1 `*.md` glob therefore returns exactly the personal files and never descends into a session dir.
- The harness dir NAMES (`session-*`, a UUID) do not end in `.md`, so even a maxdepth-1 `find -name '*.md'` cannot match a subdir.

This is why the invariant is: **always `Glob ~/.claude/tasks/*.md` or `find ~/.claude/tasks -maxdepth 1 -name '*.md'`. Never `ls` the dir wide, never `find -type f`, never a recursive glob.** A future "helpful" widening of the scan is the single most dangerous edit anyone could make to this skill.

---

## 5. The `archive/` layout (depth-2, consumer-safe)

`~/.claude/tasks/archive/{YYYY-MM}.md` holds completed items older than 30 days, bucketed by completion month (SKILL.md Section 3.8). Depth-2 is deliberately safe for all three consumers:
- `/daily-brief` and `/standup` explicitly exclude `archive/`.
- `loop-digest.sh` uses `-maxdepth 1 -name '*.md'`: `archive/` is a directory at depth 1 (not named `*.md`, so unmatched), and maxdepth 1 stops `find` from descending into it, so `archive/2026-05.md` at depth 2 is invisible to it.

So archived completions drop out of all three consumers cleanly (which is correct, anything older than 30 days is outside any brief or loop-digest window anyway). Archive files need only a `# Archive {YYYY-MM}` heading; they carry `- [x]` lines but no tier headers or frontmatter are required (nothing parses them).
