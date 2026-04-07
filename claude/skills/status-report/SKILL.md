---
name: status-report
description: Generate comprehensive weekly client status reports by analyzing the project's actual state. Use when the user asks for a status report, weekly update, client report, progress report, or says /status-report.
argument-hint: [optional date range, e.g. "2026-03-17 to 2026-03-24"]
allowed-tools: Bash, Read, Glob, Grep, Agent, Write
---

# Weekly Client Status Report Generator

Generate a professional, client-ready status report by analyzing the project's real state — git history, issues, codebase health, and project artifacts.

## 1. Determine the Report Period

If `$ARGUMENTS` contains a date range, use it. Otherwise, default to the last 7 days ending today.

Establish two variables mentally:
- `SINCE` — start date (ISO format, e.g. `2026-03-24`)
- `UNTIL` — end date (ISO format, e.g. `2026-03-31`)

## 2. Gather Project Identity

Determine the project name by checking (in order):
1. `CLAUDE.md` or `CLAUDE.local.md` — look for a project name or title
2. `package.json` — use the `name` field
3. `go.mod` — use the module path
4. `Cargo.toml` — use `[package] name`
5. Git remote URL — extract `owner/repo`
6. Current directory name as last resort

## 3. Gather Data

Run the following data-gathering steps. Use parallel tool calls wherever possible.

### 3a. Git History

```bash
# Commits in the period
git log --since="$SINCE" --until="$UNTIL" --oneline --no-merges

# Detailed commit log with files changed
git log --since="$SINCE" --until="$UNTIL" --stat --no-merges

# Authors active this period
git log --since="$SINCE" --until="$UNTIL" --format='%aN' | sort -u

# Diff stats vs start of period
git diff --stat $(git rev-list -1 --before="$SINCE" HEAD) HEAD

# Lines added/removed
git diff --shortstat $(git rev-list -1 --before="$SINCE" HEAD) HEAD
```

If any git command fails (e.g. no commits before SINCE), skip it gracefully.

### 3b. GitHub Issues & PRs (if `gh` CLI is available)

```bash
# Check if gh is available and authenticated
gh auth status 2>/dev/null

# PRs merged this period
gh pr list --state merged --search "merged:>=$SINCE" --limit 50 --json number,title,author,mergedAt,labels

# PRs currently open
gh pr list --state open --limit 20 --json number,title,author,createdAt,labels,isDraft

# Issues closed this period
gh issue list --state closed --search "closed:>=$SINCE" --limit 50 --json number,title,labels,closedAt

# Issues currently open
gh issue list --state open --limit 30 --json number,title,labels,createdAt

# Open bugs specifically
gh issue list --state open --label bug --limit 20 --json number,title,createdAt
```

If `gh` is not available or not authenticated, skip this section and note it in the report.

### 3c. Codebase Health

```bash
# TODO/FIXME count
grep -r "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.go" --include="*.rs" --include="*.java" --include="*.rb" --include="*.css" --include="*.scss" -c . 2>/dev/null | tail -1
```

Use the Grep tool to find TODO/FIXME comments across common source file types. Count them.

### 3d. Test & Build Status

Check for and run (read-only — do NOT run builds, just check status):
- Look for recent CI results via `gh run list --limit 5` if gh is available
- Check if test coverage reports exist (e.g. `coverage/`, `htmlcov/`, `.coverage`)
- Read any coverage summary files if present

### 3e. Project Artifacts

Check for any of these and read them if they exist:
- `TODO.md`, `ROADMAP.md`, `CHANGELOG.md`, `MILESTONES.md`
- `.github/ISSUE_TEMPLATE/`
- Project board data via `gh project list` if available
- Sprint or milestone data via `gh api` if available
- Any task tracking files in the repo

### 3f. Memory & Context

Check `/home/christopher/.claude/projects/` for any memory files related to this project that contain timeline, milestone, or blocker information.

## 4. Analyze & Synthesize

Before writing the report, analyze the gathered data:

- **Group commits by area/module** — don't just list commit hashes. Translate git activity into human-readable accomplishments. Example: "Implemented user authentication flow" not "added auth.ts, updated middleware.ts, added tests".
- **Infer project health** — look at velocity (commits/PRs this week vs prior), open bug count, stale issues, failing CI.
- **Identify blockers** — issues labeled "blocked", PRs with unresolved review comments, TODO comments referencing external dependencies.
- **Determine what's next** — from open PRs, open issues with milestone labels, ROADMAP.md, or recent commit patterns.

## 5. Write the Report

Generate the report as clean markdown. Write it to `./status-report-$UNTIL.md` in the current working directory.

Use this exact structure:

```markdown
# Project Status Report — [Project Name]

**Report Period:** [SINCE] — [UNTIL]
**Report Date:** [today's date]
**Prepared by:** Aenoxa

---

## Project Health Dashboard

| Indicator | Status |
|-----------|--------|
| Overall Status | On Track / At Risk / Delayed |
| Sprint Progress | X% complete (N of M items done) |
| Open Bugs | N |
| CI/Build Status | Passing / Failing / Unknown |

> [1-2 sentence executive summary of where things stand]

---

## Completed This Week

### [Area/Module Name]
- **[Feature/task description]** — [brief explanation of what was done and why it matters]
  - Commits: `abc1234`, `def5678`
- **[Bug fix description]** — [what was broken, what was fixed]

### [Another Area]
- ...

---

## In Progress

| Item | Owner | Status | Expected Completion | Blockers |
|------|-------|--------|---------------------|----------|
| [Description] | [Author] | [X% / In Review / Testing] | [Date] | [None / Description] |

---

## Planned for Next Week

1. **[Task]** — [why this is next, what it depends on]
2. **[Task]** — [priority context]
3. **[Task]** — [any client input needed]

---

## Blockers & Risks

### Active Blockers
- **[Blocker]** — [impact and what's needed to resolve]

### Risks
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [Description] | Low/Med/High | Low/Med/High | [Plan] |

### Scope Watch
- [Any requests or changes that fall outside original scope, if detectable]

---

## Metrics

| Metric | This Week | Prior Week | Trend |
|--------|-----------|------------|-------|
| Commits | N | N | +/- |
| Files Changed | N | — | — |
| Lines Added | N | — | — |
| Lines Removed | N | — | — |
| PRs Merged | N | N | +/- |
| Open Issues | N | — | — |
| Open Bugs | N | — | — |
| Test Coverage | X% | X% | +/- |

---

## Key Decisions Needed

| # | Decision | Context | Recommendation | Deadline |
|---|----------|---------|----------------|----------|
| 1 | [What needs deciding] | [Why it matters] | [Suggested path] | [When you need it by] |

> If no decisions are needed, write: "No client decisions needed this week."

---

## Next Milestone

**[Milestone Name]** — Target: [Date]

Remaining work:
- [ ] [Item 1]
- [ ] [Item 2]
- [ ] [Item 3]

Progress: [X of Y items complete]

---

*Generated by Aenoxa — [today's date]*
```

## 6. Report Rules

- **Client-friendly language.** No jargon, no internal shorthand. Write "user login system" not "auth middleware refactor." The audience is a client stakeholder, not a developer.
- **Honest assessment.** If progress was slow, say so and explain why. Never inflate or mislead.
- **Specific, not vague.** "Completed checkout flow with Stripe integration" not "Made progress on payments."
- **Omit empty sections.** If there are no blockers, remove the blockers section entirely rather than writing "None." But always keep: Header, Health Dashboard, Completed, In Progress, Metrics.
- **Prior week comparison.** For metrics, also gather the prior week's data (`SINCE - 14 days` to `SINCE - 7 days`) to show trends. If this is the first report or there's no prior data, omit the comparison columns.
- **No fabrication.** Only report what can be verified from the data gathered. If you can't determine something (like sprint progress), leave it as "—" or omit it. Never guess at percentages or timelines not supported by evidence.
- **Actionable items bolded.** Anything requiring client action should be visually prominent.

## 7. After Writing

1. Tell the user the report has been written and where it is
2. Offer to:
   - Adjust the tone (more/less formal)
   - Add or remove sections
   - Generate a shorter executive summary version
   - Email or share it (if integrations are available)
