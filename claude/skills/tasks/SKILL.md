---
name: tasks
description: Personal task management system with auto-sorting. Capture tasks instantly, auto-file into projects, track progress. Use when the user says /tasks, wants to add/check/complete tasks, or needs to see what they're working on.
argument-hint: [add "task" | done "task" | today | week | review | sort | <project-name> | (no args = dashboard)]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Task Management System

## Directory

All task data lives in `~/.claude/tasks/`:
- `INDEX.md` — dashboard with 1-line status per project
- `inbox.md` — unsorted quick captures
- `{project-name}.md` — project-specific task files
- `client_{name}.md` — client project task files
- `archive/` — completed tasks moved here monthly

## Commands

### `/tasks` (no args) — Dashboard

1. Read `~/.claude/tasks/INDEX.md`
2. Read `~/.claude/tasks/inbox.md` — count unsorted items
3. Scan all project files for NOW-tier tasks
4. Display:

```
═══ DASHBOARD ═══

Inbox: {N} unsorted items

This Week:
- [ ] {top priority from each active project, max 5 total}

Projects:
| Project | Status | NOW tasks | Next Action |
|---------|--------|-----------|-------------|
| ... | ... | ... | ... |

Waiting On:
- {task} — waiting on {who} since {date}, follow up {date}
```

### `/tasks add "{task description}"` — Quick Capture + Auto-Sort

1. Analyze the task text
2. **Auto-sort logic:**
   - Read all existing project filenames in `~/.claude/tasks/`
   - Match task text against project names and keywords:
     - Contains "beacon" → `beacon.md`
     - Contains "pulse" or "pos" → `pulse.md`
     - Contains "client" or a known client name → `client_{name}.md`
     - Contains "PT" or "company" or "legal" → `pt-aenoxa.md`
     - Contains project-specific keywords (check INDEX.md for project descriptions)
   - **New project detection:**
     - If task mentions "client" + unrecognized name → create new `client_{name}.md` + update INDEX.md
     - If task clearly implies a new project domain not matching any existing file → create new project file + update INDEX.md
     - Tell the user: "Created new project: {name}"
   - **Ambiguous:** Can't determine project → file in `inbox.md`, note "1 item needs sorting" next time dashboard is shown
3. Determine priority tier from context:
   - Urgency words ("now", "today", "urgent", "asap", "fix") → **NOW**
   - Planning words ("need to", "should", "want to", "think about") → **NEXT**
   - Future words ("someday", "later", "eventually", "idea") → **LATER**
   - Blocked words ("waiting", "blocked", "need X from", "after Y") → **WAITING** (extract who/what)
   - Default: **NEXT**
4. Add to the appropriate file under the right tier
5. Confirm: `"→ {project} / {tier}: {task}"`

### `/tasks done "{task or keyword}"` — Complete a Task

1. Search all project files for a matching task (fuzzy match on keyword)
2. If multiple matches, show them and ask which one
3. Move the task from its current tier to a `## Completed` section with today's date
4. Update INDEX.md if project status changed
5. Confirm: `"✓ {task} — completed"`

### `/tasks today` — Today's Focus

1. Scan all project files for NOW-tier items
2. If more than 5 NOW items, ask user to pick top 3-5
3. Display as a focused list:

```
═══ TODAY ═══

1. {task} ({project})
2. {task} ({project})
3. {task} ({project})

Waiting on:
- {blocked task} — {who}, follow up {date}
```

### `/tasks week` — Weekly View

1. Scan all project files for NOW + NEXT tier items
2. Group by project
3. Show deadlines if any are set
4. Display:

```
═══ THIS WEEK ═══

Beacon:
  NOW:  {task}
  NEXT: {task}

Pulse:
  NOW:  {task}
  NEXT: {task}

Client: Sinar Surya:
  NEXT: {task}

───
LATER (backlog): {count} items across {N} projects
WAITING: {count} items
```

### `/tasks {project-name}` — Project Detail

1. Read `~/.claude/tasks/{project-name}.md`
2. Display all tasks grouped by tier
3. Show project-specific context (description, client, deadline if any)

### `/tasks review` — Weekly Review

Run this once a week. It:
1. Scans all project files
2. Flags:
   - NOW tasks older than 7 days (stale — should they be demoted or done?)
   - WAITING tasks with overdue follow-up dates
   - NEXT tasks that have been sitting for 2+ weeks
   - Projects with zero activity in 2+ weeks (dormant — archive?)
   - Inbox items that haven't been sorted
3. For each flagged item, ask: keep / reprioritize / archive / delete
4. Update INDEX.md with current status
5. Suggest top 5 priorities for next week

### `/tasks sort` — Sort Inbox

1. Read `~/.claude/tasks/inbox.md`
2. For each item, auto-sort using the same logic as `/tasks add`
3. Show where each item was filed
4. Clear inbox

## Task File Format

Each project file follows this structure:

```markdown
---
project: {Project Name}
description: {One-line description}
status: {active | planning | maintenance | paused | completed}
client: {client name, if applicable}
deadline: {YYYY-MM-DD, if applicable}
---

## NOW
- [ ] {task} `{date added}`
- [ ] {task} `{date added}`

## NEXT
- [ ] {task} `{date added}`

## LATER
- [ ] {task} `{date added}`

## WAITING
- [ ] {task} — waiting on: {who/what}, follow up: {YYYY-MM-DD} `{date added}`

## Completed
- [x] {task} `{date completed}`
```

## INDEX.md Format

```markdown
# Task Dashboard

Last updated: {YYYY-MM-DD}

| Project | Status | NOW | NEXT | WAITING | Next Action |
|---------|--------|-----|------|---------|-------------|
| Beacon | active | 2 | 5 | 0 | Test generation pipeline |
| Pulse | active | 1 | 3 | 1 | Duitku verification |
| ... | ... | ... | ... | ... | ... |

## This Week (max 5)
1. {highest priority}
2. {second priority}
3. {third priority}
```

## Auto-Sort Keywords Map

Maintain this mapping (update as new projects are created):

| Keywords | Project File |
|----------|-------------|
| beacon, landing page gen, generation pipeline | beacon.md |
| pulse, pos, point of sale, inventory | pulse.md |
| PT, company, legal, notaris, partner | pt-aenoxa.md |
| attn, s0nderlabs, elpabl0, messaging | attn.md |
| email, mcp, imap, smtp | email-mcp.md |
| vps, server, deploy, nginx, infrastructure | infrastructure.md |
| client + {name} | client_{name}.md |
| skill, /skill-name, claude code tooling | tooling.md |
| personal, non-work | personal.md |

When a new project file is created, add its keywords to this map (stored in INDEX.md as a comment block or at the bottom).

## Rules

1. **Zero friction capture** — `/tasks add` should take under 5 seconds. Don't ask clarifying questions on add. Just file it.
2. **Auto-sort confidence** — if >70% sure of the project, file it silently. If unsure, inbox it.
3. **Never lose a task** — everything goes somewhere (project file or inbox). Nothing gets dropped.
4. **Dates are absolute** — always use YYYY-MM-DD, never relative dates.
5. **Inbox zero daily** — remind user if inbox has items during dashboard view.
6. **Max 5 NOW items per project** — if someone tries to add a 6th, warn them.
7. **Archive monthly** — at start of each month, move completed tasks to `archive/{YYYY-MM}.md`.
8. **New project creation** — when auto-creating a project, always update INDEX.md and the keywords map.
