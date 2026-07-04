---
name: status-report
description: Generate the weekly EXTERNAL client-facing project status report by analyzing the project's ACTUAL state (real commits, PRs, CI, issues, milestones), never a template of invented numbers. Evidence-driven, dash-clean, secret-safe, generator-only (hands the file to Christopher/Suryadi to send, never auto-sends to the client). Multi-repo aware, with an optional verified PDF/docx render. Use when the user says /status-report, or asks for a weekly client update / progress report / client status report.
argument-hint: '[period, e.g. "2026-03-17 to 2026-03-24"] [--client "Name"] [--project "Display Name"] [--repos p1,p2] [--recipient "Name"] [--pdf] [--docx] [--lang en|id]'
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
---

# /status-report: the weekly external client progress report, evidence-driven

Produce a **status report a paying client reads and trusts**: the ONE external-client-facing recurring (weekly) progress document in the Aenoxa software-house lifecycle (`project_software_house`: "Weekly status updates (CEO sends)"). It translates a week of real engineering into client-readable outcomes, reports honest project health, and asks for any decisions the client owes.

This skill exists because the #1 failure mode of an AI-written client status report is **fabrication + vanity**: an invented "Sprint 65% complete", a guessed "Expected Completion: Mar 31", a headline "Lines Added: 12,000" that trains the client to equate code churn with progress. A fabricated status detonates trust the moment reality diverges, worse than an honest gap. A vanity metric misrepresents a valuable delete-heavy refactor as negative. So this skill is built on one spine: **read the real artifacts, translate them to outcomes, report only what the evidence proves, demote churn, and never send it yourself.**

The report is generated, not sent. Christopher or Suryadi (the CEO who owns client comms) reviews and sends it.

═══════════════════════════════════════════════════════════════════════════
## 0. PRIME META-RULES (OVERRIDE EVERYTHING, mechanically verified)
═══════════════════════════════════════════════════════════════════════════

These four are non-negotiable. Each has a blocking check in the §9 VERIFICATION BLOCK. A violation is a failed report, not a style choice.

### 0.1 No em dash or en dash, ANYWHERE (PRIME RULE)

**NEVER emit an em dash (U+2014) or en dash (U+2013) in ANY output this skill produces:** not in the report body, not in the executive summary, not in a table cell, not in the chat reply to Christopher, not in this skill's own prose. This is Christopher's hard house rule (`feedback_no_long_hyphens`, Toper direct 2026-06-02) and it matches `/case-study` §0.1 and `/proposal` §0.

- **Use instead:** a comma, a colon, parentheses, or a line break for a clause break; the word "to" or a plain hyphen for a range ("8 to 10", or "Mar 17-24"), never the long-dash form; a colon when the second half defines the first.
- **Plain hyphen-minus stays allowed** for compound words and ranges (offline-first, multi-tenant, 8-10). ONLY the two long dashes are banned.
- **Scrub with meaning intact.** A heading shaped "Status (em dash) On Track" becomes "Status: On Track". Never mechanically delete a dash and leave broken grammar.
- The long dash is the single loudest "AI wrote this" tell, on the exact surface (a document a client reads) where reading as AI-generated most damages the software house's credibility.
- **Blocking check (§9 V1):** `grep -rnP "[\x{2013}\x{2014}]"` over every produced file MUST return zero.

### 0.2 No secret, PII, or internal-infra leak (PRIME RULE, this doc LEAVES THE BUILDING)

A client status report is an **external artifact**: a client stakeholder reads it. It is gathered from a codebase, `CLAUDE.md`, TODO comments, and git author data, any of which can carry a leak. Before the report ships:

- **NEVER put into the report:** an API key or token, a password, an internal hostname or IP, a `/home/...` path, a contributor's email address, a WhatsApp JID or phone number, or raw `CLAUDE.md` infra detail (VPS host, secrets-file layout, Cloudflare scope). Scrub every one.
- **NEVER READ a live secret-bearing value file as a gathering source (prevention beats scrubbing).** Do not `cat` `.env`, `.env.local`, `.env.development`, `.env.production`, `.env.*.local`, `~/.claude/secrets.env`, or any resolved-value file. A value that never enters context cannot leak. A status report never NEEDS env values anyway: deploy/build status comes from CI (`gh run`, §3b), not from a secrets file; org identity comes from `company.name` in the invoice config (§3f), not from anywhere secret. This is the verified `/handover` §0.2 lesson (that leak came from READING `.env.production` into context, one paraphrase from the client doc).
- **Contributor names:** generalize to "the team" / "the engineering team" unless a named person is genuinely client-appropriate (a named tech lead the client already works with). Never expose the internal team roster or a git author list.
- **TODO/FIXME text** pulled from the codebase can embed a credential or an internal note. Never paste raw TODO text into the report; summarize the WORK, not the comment.
- **On a real key-pattern hit:** report **file + pattern TYPE only, never the value** (not even partially redacted), the same discipline as `/case-study` §0.4 V4 and `/handover`.
- **Blocking check (§9 V2 + V3):** the secret/PII grep and the `/home/christopher` path grep over every produced file MUST return zero.

### 0.3 No fabrication: every status, percentage, date, and metric is sourced or omitted (PRIME RULE)

**NEVER invent a project-health status, a completion percentage, a date, or a metric.** Every Health-Dashboard cell, every `%`, every "Expected Completion" date, every trend arrow must trace to real evidence (a commit, a PR, an issue, a `gh run`, a file you read, a milestone source, or something Christopher told you) OR be **OMITTED**, OR be tagged `(estimate)` / `(unverified)` with the basis.

- If "Sprint Progress %" has no real board/issue/milestone source, **OMIT the row.** Do not compute a plausible-looking percentage from commit counts. Commits are not sprint items.
- If there is no milestone or deadline baseline anywhere, **OMIT "Overall Status"** or mark it `(no milestone baseline set)`. Do NOT default a green "On Track": a green with no basis is the exact fabrication that detonates trust.
- If no coverage artifact was actually read, **OMIT the coverage row entirely.**
- The audit standard and the health-inference rules are §6. When in doubt, leave it out: an honest gap beats a fabricated win.

### 0.4 Generator-only: NEVER send the report to the client (PRIME RULE)

**This skill PRODUCES a file. It NEVER sends it.** Client communication is external and human-gated across the whole house: `/proposal` is "generator only, never auto-sends", `/invoice` never auto-sends, and `project_software_house` records the weekly status update as something **the CEO (Suryadi) sends**, not the agent.

- NO WhatsApp send, NO email send, NO attn send, NO "share it for you" belongs in this skill. Do not load or call a send tool.
- The deliverable is the report file (+ optional PDF/docx). Hand it to Christopher, name where it is, and stop. He or Suryadi reviews and sends.
- The single exception a client report can never take: auto-delivery. Even if asked "just send it", produce the file and hand it over; escalate the send to Christopher.

═══════════════════════════════════════════════════════════════════════════
## NON-NEGOTIABLE RULES (read first, these override the sections below)
═══════════════════════════════════════════════════════════════════════════

Violating any one is a failed report.

1. **EVIDENCE-DRIVEN, NEVER TEMPLATE-FILLED.** You analyze the project's ACTUAL state and report what the artifacts prove. You never fill the template shape with plausible numbers. Do the §3 gathering pass on a real repo (or repos) BEFORE writing a word of narrative. If there is no repo and no facts, STOP and ask Christopher for the source, do not invent a week of progress.

2. **TRANSLATE COMMITS TO CLIENT-READABLE OUTCOMES.** This is the single most load-bearing idea in the skill. The client is a business stakeholder, not a developer. Report the OUTCOME and why it matters, never file names, never commit hashes as narrative, never internal jargon. "Completed the customer checkout flow with Midtrans payment, orders now confirm end-to-end" beats "added checkout.ts, updated middleware.ts" every time (§4, §5).

3. **HONEST ASSESSMENT, NO INFLATION, NO SUGARCOAT.** If the week was slow, say so and say why ("two days went to an unplanned production data-integrity fix"). Never inflate a quiet week into "great progress". A client who later discovers a rosy report was hollow trusts nothing after. Honesty is the software house's credibility (`feedback_no_yesman_sugarcoat` applied to client comms).

4. **ANTI-VANITY-METRIC: never headline code churn as value.** Lines added/removed and raw commit counts are ACTIVITY, not PROGRESS. A refactor that deletes 3,000 lines is often the best work of the week and reads as negative under a churn metric. Lead with deliverables and milestone progress; demote code activity to a clearly-labeled secondary table; keep Lines Added/Removed OUT of the client view (§5, `references/metrics-and-framing.md`).

5. **ANTI-SLOP, SPECIFIC NOT VAGUE.** Banned: "great progress", "working hard", "on track" / "as planned" / "no issues" / "everything is fine" when not evidence-backed, plus the resume-cliche set (leveraged, utilized, seamless, robust scalable). "Completed offline order sync with conflict resolution" not "made good progress on the app". The §7 ban list is grep-checked.

6. **VISUALLY STRUCTURED (client skims in 60 seconds).** Lead with tables, a health dashboard, and scannable bullets, not prose walls (`feedback_visual_structured_docs`). A busy client must get the gist from the headers + dashboard + Completed section alone. Reserve prose for the executive summary and the "why" (§5).

> If Christopher's instruction conflicts with these (e.g. "just say we're 80% done"), do not silently comply. Either it is a real figure he is providing (then it is evidence: note "per Christopher, <date>"), or flag it: "I can't source 80% from the repo or a board. Mark it as an estimate, or omit it?"

═══════════════════════════════════════════════════════════════════════════
## DELIVERY GATE (satisfy ALL before declaring the report done)
═══════════════════════════════════════════════════════════════════════════

- [ ] **Evidence gathered on a real repo (or repos).** The §3 pass ran; you can name the commits/PRs/issues behind each claim. No narrative was written before gathering.
- [ ] **Every metric, status, and date is sourced, omitted, or tagged.** No health cell, no `%`, no completion date appears without a real source or an `(estimate)`/`(unverified)` tag. Unsourced = deleted, not guessed (§0.3, §6).
- [ ] **Commits translated to outcomes**, not a file/hash dump (rule 2). The Completed section reads to a business stakeholder.
- [ ] **Zero vanity-metric-as-value.** No Lines Added/Removed in the client view; code activity is in a labeled secondary table only (rule 4).
- [ ] **§9 VERIFICATION BLOCK all green:** V1 dash grep silent, V2 secret/PII grep silent, V3 `/home/christopher` grep silent, V4 anti-slop grep silent, on every produced file.
- [ ] **Boundary check done** (§2): this really is a recurring external client progress report, not a mis-routed /worklog / /retro / /standup / /handover / /proposal request.
- [ ] **Org identity read from config**, not hardcoded (§3f): "Prepared by" uses `company.name` from `~/.claude/invoices/config.json`, no raw config values printed, no bank/npwp read.
- [ ] **§7 QUALITY SCORE >= 10/12**, and none of criteria #3 / #4 / #5 scored 0.
- [ ] **If a render was requested**, the PDF is VERIFIED (chrome exit 0 AND `test -s` AND `pdfinfo` pages >= 1), or you reported the render failure honestly and delivered the markdown (§8).
- [ ] **Generator-only confirmed** (§0.4): the report was NOT sent; it is handed to Christopher with its path.
- [ ] **Landed in a deliberate location** (§5f), not accidentally inside a client repo where it could be committed with raw git.

If any box fails, the report is NOT done. Fix before reporting complete.

---

## 1. PARSE THE INVOCATION

Read `$ARGUMENTS` and lock these before gathering.

### 1a. Report period (default: last 7 days ending today)

- If `$ARGUMENTS` contains a date range (e.g. `2026-03-17 to 2026-03-24`), use it.
- Otherwise default to the last 7 days ending today.
- **Compute the two ISO dates with `date -d`, never mentally** (GNU date 9.11 verified on this box):

```bash
UNTIL=$(date +%F)                              # today, or the given end date
SINCE=$(date -d "$UNTIL - 7 days" +%F)         # 7-day window
PRIOR_UNTIL="$SINCE"                            # prior-period baseline for trends
PRIOR_SINCE=$(date -d "$UNTIL - 14 days" +%F)   # verified: date -d "2026-03-24 - 14 days" +%F -> 2026-03-10
```

Use `SINCE`/`UNTIL` for the report window and `PRIOR_SINCE`/`PRIOR_UNTIL` for the prior-week trend (rule: trends only if prior data exists, else omit the comparison, §5).

### 1b. Client, project display name, recipient (the client-facing identity layer)

A client report addresses a client about a project the client has a NAME for. A repo slug (`aenoxa_pos_web`) is not that name (`Pulse POS` is). Resolve, in order:

| Field | From | Fallback |
|---|---|---|
| `--client "Name"` | the client/company the report goes TO | ask, or "the client" if truly unknown |
| `--project "Display Name"` | what the client calls the project | detect a repo name (order below), then FLAG it: "I detected the repo slug `X`, what does the client call this project?" Prefer the display name in the report. |
| `--recipient "Name"` | who receives it (a person) | optional, omit if unknown |
| `--lang en\|id` | report language | `en` default; for an Indonesian client, offer/use `id` (Bahasa Indonesia). Match the client's working language. Not a bilingual mandate (that is for websites, not documents). |

**Repo-name detection order** (only to SEED a display-name suggestion, never to address the client raw): (1) `CLAUDE.md` / `CLAUDE.local.md` project title, (2) `package.json` `name`, (3) `go.mod` module path, (4) `Cargo.toml` `[package] name`, (5) the git remote `owner/repo`, (6) the directory name. The result is a repo slug; humanize it and confirm the client-facing name.

Never put a bare repo slug in front of a client. If you cannot get a display name and Christopher is AFK, use the cleanest human form of the repo name and tag it `(confirm project name)` for his review.

### 1c. Repos to analyze (`--repos`, multi-repo aware)

- `--repos path1,path2`: explicit list. An Aenoxa client project often spans repos (a frontend + a backend). Aggregate across ALL of them (§3a, `references/git-recipes.md`).
- No `--repos`: default to the current working directory if it is a git repo. If cwd is not a repo, ask which repo(s).
- **Monorepo:** if the project is one path inside a larger repo, scope git to it with `-- <path>` (§3a).

### 1d. Render format (`--pdf` / `--docx`, both optional; markdown is the fast default)

Markdown is always produced. A PDF or docx is OPT-IN (a weekly report should stay fast; do not force a render). If requested, §8 + `references/render-pipeline.md`.

---

## 2. BOUNDARY: is /status-report even the right skill?

Five near-siblings all touch "progress" or "weekly". status-report is the ONLY external-client-facing recurring progress document. Before gathering, confirm the request is really this one. If it matches another row, say so and redirect.

| The request is really about... | Right skill | Why not status-report |
|---|---|---|
| Billable HOURS, a timesheet, "how many hours on X" | **/worklog** | worklog is the hours ledger that feeds /invoice; status-report never counts or bills hours |
| Christopher's PERSONAL weekly self-review (bottleneck, one behavior change) | **/retro** | retro is his private Sunday retrospective (self, WA digest), not a client artifact |
| The twice-daily PERSONAL standup ritual (yesterday/today/blockers) | **/standup** | standup is to Toper via WhatsApp, internal, not client-facing |
| FINAL project delivery, the handover package, a signable BAST | **/handover** | handover is the one-time close-out + BAST, not a recurring mid-build update |
| PRE-sales scope, an SOW, a quote, pricing | **/proposal** | proposal is pre-engagement commercial scoping, not progress on active work |
| A recurring EXTERNAL client progress update (weekly) | **status-report (this)** | this is the one |

Bright line: **external + recurring + progress-on-active-work = status-report.** Anything internal, one-time, hours-based, or pre-sales routes elsewhere. If a request is ambiguous ("give me a weekly update"), ask one question: "for the client, or your personal review?"

---

## 3. GATHERING PASS (do this FIRST, evidence before narrative)

No narrative until this pass runs. Use parallel tool calls where independent. Every guarded git recipe below has its full per-VCS-state form in `references/git-recipes.md`; the guards here are load-bearing and stay in this file.

### 3a. Git history, GUARDED and multi-repo aware

For EACH repo in the resolved list, run inside it (`git -C <repo>` or cd). Aggregate across repos, label per repo in the report.

```bash
# Safe commit count in the period (NO footgun: never uses rev-list command-substitution)
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --oneline | wc -l

# The commits themselves (raw material for the outcome translation in §4)
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --pretty=format:'%h %ad %s' --date=short

# Merges landed (feature integrations, often the real "shipped" signal)
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --merges --pretty=format:'%h %s' --date=short
```

**THE FOOTGUN (never write this):**

```bash
# BANNED: if rev-list returns empty (young repo, or SINCE precedes the first commit),
# the command substitution COLLAPSES to `git diff --stat HEAD`, which silently diffs the
# WORKING TREE vs HEAD and reports uncommitted junk as period metrics, with exit 0.
git diff --stat $(git rev-list -1 --before="$SINCE" HEAD) HEAD    # <-- do NOT use
```

**The guard (capture, test non-empty, use an empty-tree base for a root commit):**

```bash
FIRST=$(git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --format=%H --reverse | head -1)
LAST=$(git  -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --format=%H | head -1)
if [ -z "$FIRST" ]; then
  echo "NO COMMITS in period for $REPO"   # honest quiet week, do not pad (§4, §10)
else
  BASE=$(git -C "$REPO" rev-parse -q --verify "${FIRST}^" 2>/dev/null \
         || git hash-object -t tree /dev/null)   # empty-tree 4b825dc... if FIRST is the root commit
  git -C "$REPO" diff --shortstat "$BASE" "$LAST"   # net change across the period, guarded
fi
```

- **Detached / shallow / no-commits:** handle cleanly, `references/git-recipes.md`. A shallow clone can hide older history; note it rather than reporting a wrong delta.
- **Monorepo scope:** append `-- <path>` to every `git log`/`git diff` above.
- Author-vs-committer date can diverge on rebased history; `--since/--until` filter by commit date. Good enough for a weekly window; do not over-engineer.
- Contributor list stays INTERNAL (§0.2): `git shortlog -sn HEAD` tells YOU who did what, it does not go in the client report.

### 3b. GitHub issues, PRs, CI (if `gh` is available and authed, else skip gracefully)

`gh` is authed on this box as account TopengDev via `GH_TOKEN` (verified). It may still lack scope on a specific private repo; on any failure, skip that item and note "not tracked in GitHub" rather than inventing.

```bash
gh auth status >/dev/null 2>&1 || echo "gh unavailable, skip the GitHub section"

# PRs merged in the period (the strongest "delivered" signal after demos)
gh pr list --state merged --search "merged:$SINCE..$UNTIL" --limit 50 --json number,title,mergedAt,labels 2>/dev/null

# PRs open now (in-progress work)
gh pr list --state open --limit 20 --json number,title,createdAt,labels,isDraft 2>/dev/null

# Issues closed in the period + open bugs (the honest open-bug count)
gh issue list --state closed --search "closed:$SINCE..$UNTIL" --limit 50 --json number,title,labels 2>/dev/null
gh issue list --state open --label bug --limit 30 --json number,title,createdAt 2>/dev/null

# CI/build reality (latest COMPLETED run conclusion => the Build/Deploy dashboard cell)
# in-progress runs have conclusion=null: skip them, take the latest non-null, else "Unknown" (git-recipes §7)
gh run list --limit 10 --json headBranch,conclusion,createdAt,name 2>/dev/null
```

- **Milestone / sprint progress source** (the ONLY legitimate source for a "% complete", §6): a GitHub milestone (`gh issue list --milestone "<name>" --json state`), a project board, or a `ROADMAP.md` / `MILESTONES.md` checklist with `[x]`/`[ ]`. If none exists, there is no `%` to report. Do NOT synthesize one from commits.

### 3c. Codebase health signals (summarize the work, never paste raw comments)

```bash
# TODO/FIXME as a COUNT only (a trend signal), never paste the text (a TODO can hold a secret, §0.2)
grep -rIn --include=*.{ts,tsx,js,jsx,py,go,rs,java,rb,php,css,scss} -E 'TODO|FIXME|HACK|XXX' "$REPO" 2>/dev/null | wc -l
```

The count can inform an internal quality note; it rarely belongs in a client report unless it is trending meaningfully. If you cite it, cite the number, never the comment body.

Never `cat` a `.env` / `secrets.env` / resolved-value file to gather config or deploy status (§0.2). Build/deploy status comes from CI (§3b); org identity comes from the invoice config (§3f). A secrets file is never a status-report source.

### 3d. Coverage / tests (include a coverage row ONLY if a real artifact was read, §0.3)

Look for `coverage/`, `htmlcov/`, `.coverage`, `coverage-summary.json`, `lcov.info`. If one exists, read the summary and cite the real number. **If none exists, OMIT the coverage row entirely.** Never guess a coverage percentage, never leave a blank cell to be filled by wishful thinking.

### 3e. Project artifacts (the roadmap / milestone / decision context)

Read whichever exist in the repo(s): `ROADMAP.md`, `MILESTONES.md`, `CHANGELOG.md`, `TODO.md`, `docs/`, a sprint doc, a project board export. These give you the milestone baseline (for Health) and the "planned next" material (for §5). A `CHANGELOG.md` with a dated entry is a clean, honest "shipped" source.

### 3f. Memory, project context, and ORG IDENTITY (correct paths, never guess)

- **Project context = the memory store at `~/.claude/memory/`, index-first via `MEMORY.md`.** Start at `~/.claude/memory/MEMORY.md`, follow the index to the relevant file (e.g. a `project_*` or `reference_*` entry for this client's project). **NEVER guess a memory filename** (they drift). Use it for milestone context, known blockers, and the "why" behind decisions, with PII stripped for the client (§0.2).
  - **NEVER read `~/.claude/projects/` for project context.** That directory is Claude Code SESSION-TRANSCRIPT JSONL, not project memory. (The prior version of this skill pointed here; it was wrong, verified 2026-07-03.)
  - A repo-local `~/claude/notes/<project>/` or in-repo `docs/` is a valid second source.
- **Org identity from the shared config, never hardcoded:** read `company.name` (and `company.website` if you want a footer) from `~/.claude/invoices/config.json`. This is the same source `/proposal` and `/invoice` use, so "Prepared by" stays consistent with the billing pipeline. Verified keys present: `company.{name,address,phone,email,website,npwp}`, `bank.{...}`, `defaults.{...}`.

```bash
COMPANY_NAME=$(jq -r '.company.name' ~/.claude/invoices/config.json 2>/dev/null)   # into the "Prepared by" line
# NEVER print raw config to the user or the report; NEVER read bank.* or company.npwp into a client report.
```

If the config is missing, ask Christopher for the "Prepared by" name; do not hardcode "Aenoxa".

---

## 4. ANALYZE AND SYNTHESIZE (turn raw git into client outcomes)

Before writing, process the gathered data. This is where a good report is won.

### 4a. Cluster commits into outcomes (rule 2, the core move)

Group the period's commits by area/feature (not by file). Each cluster becomes ONE client-readable accomplishment: the outcome + why it matters. Discard the mechanics.

| Raw commits (internal) | Client outcome (report) |
|---|---|
| `feat: add checkout.ts`, `fix: midtrans callback`, `test: checkout e2e` | **Customer checkout is complete.** Orders now confirm end-to-end with Midtrans payment. |
| `refactor: extract sync engine`, `perf: batch writes`, `-3,000 LOC` | **Rebuilt the offline sync engine.** Faster and simpler, which lowers the risk of the sync bugs seen last month. (A large deletion here is GOOD, never reported as negative, rule 4.) |
| 1 commit `chore: bump deps` | (omit or fold into a one-line "housekeeping" note; not a headline) |

### 4b. Infer project health with RULES, not vibes (feeds §5 dashboard, governed by §6)

- Velocity: this week's merged-PR / closed-issue count vs the prior week (real numbers from §3a/§3b), not a feeling.
- Blockers: issues labeled `blocked`, PRs stuck in review, a TODO referencing an external dependency, or a stated waiting-on-client item.
- Milestone fit: does remaining work fit the remaining time to the next milestone date (if one exists)? That, and only that, sets On Track / At Risk / Delayed (§6). No milestone date => no overall status.

### 4c. Determine "planned next" from evidence

From open PRs/issues with a milestone, the ROADMAP, or the recent commit trajectory. Frame as client-facing priorities, not a backlog dump.

### 4d. Surface decisions the client owes

Anything blocking that needs the client's input (a spec question, an approval, access, a scope call). These become the "Decisions Needed" table, the highest-value part of the report for keeping the project moving.

---

## 5. THE REPORT TEMPLATE (outcomes-first, metrics reframed)

Keep this shape (it is genuinely client-appropriate). Fill from §3/§4. **Omit any section with no real content** rather than writing "None" or padding, EXCEPT always keep: Header, Health Dashboard, Completed. Every filled cell obeys §6 (sourced or omitted or tagged). Write to the location in §5f.

```markdown
# <Project Display Name>: Weekly Status Report

**Client:** <Client Name>
**Report period:** <SINCE> to <UNTIL>
**Prepared for:** <Recipient, if known>
**Prepared by:** <company.name from config>
**Date:** <today>

---

## Executive summary

<2 to 3 honest sentences: where things stand, the headline outcome of the week, and any
one thing the client should note. This is the only prose block. If the week was slow, this
is where you say so and why (rule 3).>

## Project health

| Indicator | Status |
|---|---|
| Overall status | On Track / At Risk / Delayed  (OMIT if no milestone baseline, §6) |
| Milestone progress | <M of N deliverables complete>  (OMIT if no board/roadmap source, §6) |
| Open items needing attention | <N>  (from the tracker; OMIT if untracked) |
| Build / deployment | Passing / Failing / Unknown  (from CI; §6) |

## Completed this week

### <Area / feature, in client language>
- **<Outcome>.** <One line on what it means for the client.>
- **<Outcome>.** <Why it matters.>

### <Another area>
- ...

## In progress

| Item (client language) | Status | Expected completion | Notes |
|---|---|---|---|
| <Feature> | In review / Testing / <M of N> | <date, or "(estimate)", or omit> | <blocker or context> |

## Planned for next week

1. **<Priority>** <why it is next / what it unblocks>
2. **<Priority>** <context>

## Blockers and risks   (omit the whole section if genuinely none)

### Active blockers
- **<Blocker>** <impact + what is needed to clear it>

### Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| <Risk> | Low/Med/High | Low/Med/High | <plan> |

## Decisions needed from you   (the client-action section, make it prominent)

| # | Decision | Why it matters | Our recommendation | Needed by |
|---|---|---|---|---|
| 1 | <what to decide> | <context> | <suggested path> | <date> |

> If none: "No decisions needed from you this week."

## Development activity   (SECONDARY, explicitly framed as activity, not value, rule 4)

> Activity indicators for transparency. Progress is measured by the deliverables above, not by code volume.

| Indicator | This week | Prior week | Trend |
|---|---|---|---|
| Features / deliverables completed | <N> | <N> | <arrow if >1 diff> |
| Pull requests merged | <N> | <N> | <arrow> |
| Issues / bugs closed | <N> | <N> | <arrow> |
| Open bugs | <N> | <N> | <arrow> |

## Next milestone

**<Milestone name>** target: <date, from a real roadmap/board; omit if none>

Remaining:
- [ ] <item>
- [ ] <item>

Progress: <M of N complete>   (omit if no source)
```

### 5a. Metric reframing rules (the anti-vanity core, rule 4)

| Do | Don't |
|---|---|
| Lead with "Milestone 2: 4 of 6 deliverables complete" | Lead with "Lines added: 12,000" |
| Put commits / PRs in the labeled **Development activity** table, framed as activity | Put commit count or LOC in the top health dashboard as a headline |
| Report a delete-heavy refactor as a positive outcome | Show "Lines removed: 3,000" as if it were a loss |
| Show bugs-closed and open-bug trend (real client value) | Show "files changed" as a progress number |

**Lines Added / Lines Removed NEVER appear in the client report.** Full taxonomy of client-visible vs internal-only metrics, trend-arrow thresholds, and slow-week framing: `references/metrics-and-framing.md`.

### 5b. Trend-arrow rule

An up/down arrow appears only when the change is meaningful (a difference greater than 1 unit, or greater than ~10% for a count). A 4-vs-4 or a 5-vs-4 is flat, not a trend. If there is no prior-period data (first report), OMIT the "Prior week" and "Trend" columns entirely.

### 5c. Language and tone

Client-friendly, professional, warm-but-precise. No developer jargon ("auth middleware refactor" becomes "user login improvements"). No internal shorthand, no repo slugs, no ticket IDs the client does not use. `--lang id` renders the whole report in Bahasa Indonesia for an Indonesian client (translate outcomes, keep the same structure).

### 5d. Bold the client actions

Anything the client must do (a decision, an approval, providing access) is bold and lands in the "Decisions needed" table. That section is the report's operational payload.

### 5e. Omit-empty discipline

No blockers this week? Delete the Blockers section (do not write a section that says "None"). No risks? Delete it. Always keep Header, Health, Completed. A shorter honest report beats a padded one.

### 5f. Where the report lands (deliberate, not the client repo)

Default to a deliberate notes location so an internal-flavored draft never gets accidentally committed into a client repo:

```bash
mkdir -p ~/claude/notes/status-reports/<client-slug>
# write to: ~/claude/notes/status-reports/<client-slug>/status-report-<UNTIL>.md
```

If Christopher wants it elsewhere, honor that. If it must live inside a repo, route any commit through `/commit` (the seal-guard hook blocks raw `git commit`; `CLAUDE_COMMIT_SKILL=1` sentinel), never raw git.

---

## 6. EVIDENCE AND HEALTH-STATUS DISCIPLINE (lightweight, rule enforcement)

This is the anti-fabrication firewall (§0.3), sized for a WEEKLY cadence: a lightweight source discipline, NOT a full `/case-study` evidence-ledger file. The rule: **you must be able to name the evidence behind every status, %, and date. Anything you cannot, you delete or tag.**

### 6a. What counts as a source

A commit hash, a PR number, an issue number, a `gh run` conclusion, a file you read (ROADMAP/CHANGELOG/coverage), a milestone/board state, or "per Christopher, <date>". A source note may appear inline in the report where it BUILDS client trust ("4 of 6 milestone issues closed, per the project board"). A raw commit hash does NOT belong in a client cell; keep hashes as your internal backing.

### 6b. Health-cell inference rules (mechanical, kills the green-by-default fabrication)

| Cell | Set it to... | ONLY when... | Else |
|---|---|---|---|
| Overall status = **On Track** | deliverables landing on cadence, no active blocker, remaining work fits the milestone date | a milestone/deadline baseline EXISTS | OMIT the cell (or `(no milestone baseline set)`) |
| = **At Risk** | a blocker exists, OR velocity dropped, OR the milestone date is near with heavy remaining work | same | never invent |
| = **Delayed** | a milestone/deadline already slipped (date passed, work incomplete) | same | never invent |
| **Milestone progress %** | `M of N` from a board / milestone / roadmap checklist | that source exists and you counted it | OMIT the row (never derive % from commits) |
| **Open bugs / items** | the tracker count | `gh`/board reachable | `(not tracked in GitHub)` or omit |
| **Build / deployment** | latest CI conclusion or a verified deploy | you read it | `Unknown` (honest) or omit |
| **Expected completion date** | a real milestone/plan date, or Christopher's word | such a source exists | OMIT, or tag `(estimate)` with the basis |
| **Test coverage** | the real number from a coverage artifact | you read the artifact (§3d) | OMIT the row entirely |

### 6c. The tag vocabulary

`(estimate)` (a reasoned guess, basis stated), `(unverified)` (claimed but not confirmed), `(target)` (a goal, not yet measured). A tagged cell is honest; a fabricated cell is not. A cell that can get neither a source nor a defensible tag is DELETED.

---

## 7. ANTI-SLOP BAN LIST + QUALITY SCORE

### 7a. Ban list (client-report specific, grep-checked in §9 V4)

Kill every hit, replace with a concrete sourced specific:

- **Hollow progress phrases (banned when not evidence-backed):** "great progress", "good progress", "working hard", "on track" / "as planned" / "no issues" / "everything is fine" / "smoothly" used as a bare assurance. If the thing is true, state the EVIDENCE ("shipped 3 of 4 checkout deliverables"), not the assurance.
- **Resume / marketing cliches:** leveraged, leverage, utilized/utilize, seamless/seamlessly, robust, scalable (as filler), cutting-edge, state-of-the-art, best-in-class, world-class, synergy, spearheaded, streamlined (as filler), "next-level", "game-changer".
- **Empty intensifiers:** very, really, extremely, incredibly, a wide range of, numerous, various (as in "various features").

Replacement discipline: every deleted filler word is replaced by a detail THIS week actually has (a real feature name, a real number, the real reason), never a different adjective.

### 7b. Quality score (0-2 each, ship at >= 10/12)

| # | Criterion | 0 | 1 | 2 |
|---|---|---|---|---|
| 1 | Skimmable in 60s from headers + dashboard + Completed alone | needs full read | mostly | yes |
| 2 | Commits translated to outcomes (not a file/hash dump) | dump | partial | clean outcomes |
| 3 | Zero vanity-metric-as-value (no LOC/churn as progress) | present | borderline | clean |
| 4 | Every status / % / date sourced or omitted or tagged | fabricated/bare | mostly | all clean |
| 5 | Zero AI-slop progress phrases (§7a) | several | 1-2 | none |
| 6 | Honest about a slow week / real blockers | inflated | mixed | honest |

**Any of #3, #4, #5 scoring 0 is an automatic fail regardless of total** (they are non-negotiables 4, and 0.3, and 5). The mechanical greps (§9) are SEPARATE boolean gates so a high score can never average away a dash or a leaked secret.

---

## 8. RENDER (optional PDF / docx, verified house pipeline)

Markdown is the fast default. Render ONLY when `--pdf` or `--docx` is passed. The full self-contained recipe (HTML template tuned for a status report, fallback chain, failure playbook) is `references/render-pipeline.md`; the load-bearing rules stay here.

### 8a. Hard rules

- **PDF route = Chrome-headless ONLY.** Verified: `/usr/bin/google-chrome-stable` (Chrome 144). Fallback `/opt/google/chrome/google-chrome`.
- **`pandoc md -o file.pdf` is BANNED.** There is NO LaTeX engine on this box (pdflatex/xelatex/tectonic/lualatex all absent), so pandoc-direct-PDF fails. `pandoc` is **docx-only** here (verified).
- **docx route:** `pandoc <md> -o <docx>` (works, no LaTeX). A `soffice --headless --convert-to pdf` route exists as a PDF safety net if every Chrome variant fails.
- **Typography floors** in the HTML template: body >= 12px, all weights >= 500, NO monospace for labels (mono only inside a real code/diagram block), no sub-12px text (`feedback_ui_typography_floors`, `feedback_no_monospace_unless_archetype`).
- If a live-app screenshot is ever wanted in the report, **defer entirely to the `/agent-browser` skill** (multi-port `/claim` lifecycle, `tab new` is broken so use `/claim?url=`, `qb-shoot` fallback, DPR trim, NEVER kill the live browser, NEVER Playwright MCP). Do not inline a browser recipe here.

### 8b. The verified PDF command + the verify gate (never claim a PDF you did not confirm)

```bash
HTML="/tmp/status-${UNTIL}.html"; PDF="<report-dir>/status-report-${UNTIL}.pdf"
# ... write $HTML from the template in references/render-pipeline.md ...
google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header "$HTML" 2>/tmp/chrome.log
chrome_exit=$?
# GATE (all three, else the PDF is NOT done):
[ "$chrome_exit" -eq 0 ] && test -s "$PDF" && pdfinfo "$PDF" | grep -q '^Pages: *[1-9]' \
  && echo "PDF OK" || echo "PDF FAILED, deliver the markdown and report the failure honestly"
rm -f "$HTML"   # only after the PDF is confirmed
```

`pdfinfo` and `qpdf` (fallback page check) and `soffice` are all present (verified). Run the §9 verification block on the markdown AND the render HTML source before rendering (a dash or a leaked token in the source lands in the PDF).

---

## 9. VERIFICATION BLOCK (run on EVERY produced file, all must return zero)

Run these against the report markdown, and any HTML render source, before declaring done. Any hit = NOT done; scrub with meaning intact and re-run until silent.

```bash
FILES="<report.md> [<render.html>]"

# V1 em/en dash (§0.1) MUST be silent
grep -rnP "[\x{2013}\x{2014}]" $FILES

# V2 secret / PII (§0.2) MUST be silent. A real hit: report file + pattern TYPE only, never the value.
grep -rnE 'sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[A-Z0-9]|password=|token=|@s\.whatsapp\.net|(\+?62|0)8[0-9]{7,}' $FILES

# V3 internal path (§0.2) MUST be silent in the client-facing report
grep -rn '/home/christopher' $FILES

# V4 anti-slop progress phrases (§7a) MUST be silent
grep -rniE '\b(great progress|good progress|working hard|on track|as planned|no issues|everything is fine|leverag(e|ed|ing)|utiliz(e|ed|ing)|seamless(ly)?|synerg(y|ies)|cutting.edge|state.of.the.art|best.in.class|world.class|game.chang(er|ing)|very|really|extremely|a wide range of|various features)\b' $FILES
```

- V4 word boundaries are deliberate ("on track" as a bare assurance is banned; a sourced "on track to hit the Mar 24 milestone, 5 of 6 items done" is a legitimate evidenced statement, keep it and note the source). If a V4 hit is genuinely evidence-backed in context, it is allowed; the grep is a prompt to CHECK, not a blind delete.
- These four are wired into the DELIVERY GATE and are boolean precisely so context pressure cannot erode them.

---

## 10. FAILURE-MODE PLAYBOOK (smell -> fix)

| Failure mode | Smell | Fix / recovery |
|---|---|---|
| **Empty rev-list mis-diffs the working tree** | metrics include uncommitted junk, exit 0 hides it | Use the §3a guard (capture FIRST/LAST, empty-tree base for a root commit). Never the `$(rev-list ...)` substitution form. |
| **No commits in the range** | tempted to pad a quiet week | Report an honest quiet week and WHY (holiday, an unplanned prod fix, waiting on client). Never invent activity (rule 3). |
| **Fabricated Sprint %** | a clean "65%" with no board behind it | OMIT the row unless a real milestone/board/roadmap gives `M of N` (§0.3, §6). Never derive % from commit counts. |
| **Green "On Track" by default** | overall status is green with no milestone baseline | OMIT overall status, or mark `(no milestone baseline set)`. Green needs a real date to be true (§6b). |
| **Vanity LOC headlined** | "Lines added: 12,000" near the top | Delete LOC from the client view; lead with deliverables; put commits/PRs in the labeled activity table (rule 4). |
| **Delete-heavy refactor reads negative** | a great cleanup shown as "-3,000 lines" | Report it as a positive outcome (simpler, lower-risk), no negative churn number (§4a). |
| **Multi-repo project, single-repo report** | only the frontend's activity, backend invisible | Aggregate across `--repos`, label per repo (`references/git-recipes.md`). |
| **Monorepo, whole-repo metrics** | numbers include unrelated packages | Scope git with `-- <path>` (§3a). |
| **Secret in a TODO leaks** | a key/host pasted from a code comment | Never paste raw TODO text; summarize the work. Scrub. Report a real key hit as file + type only (§0.2, §9 V2). |
| **Wrong memory path** | reading `~/.claude/projects/` finds transcript JSONL | Use `~/.claude/memory/` index-first via MEMORY.md (§3f). |
| **Contributor names leak** | git author list in the client doc | Generalize to "the team" unless a name is client-appropriate (§0.2). |
| **Auto-send temptation** | "I'll WhatsApp it to the client" | Generator-only. Produce the file, hand it to Christopher/Suryadi (§0.4). |
| **Client name = repo slug** | "aenoxa_pos_web" in front of a client | Use the client-facing display name (§1b). Flag for confirmation if unknown. |
| **pandoc PDF fails** | `pdflatex not found` | Chrome-headless only; pandoc is docx-only here (§8a). |
| **Report committed into a client repo via raw git** | seal-guard blocks, or an internal draft lands in the repo | Land in `~/claude/notes/status-reports/` (§5f); any in-repo commit goes through `/commit`. |
| **Hardcoded "Aenoxa"** | org name baked into the template | Read `company.name` from `~/.claude/invoices/config.json` (§3f). |

---

## 11. EXECUTION FLOW

1. **Parse** (§1): period via `date -d`, client + project display name + recipient, repos, render format, language.
2. **Boundary check** (§2): confirm this is a recurring external client progress report, not /worklog / /retro / /standup / /handover / /proposal. Redirect if not.
3. **Gather** (§3): guarded multi-repo git, gh + CI (graceful skip), artifacts, memory at the correct path, org identity from config. NO narrative until this is done.
4. **Analyze** (§4): cluster commits into outcomes, infer health by the §6 rules, determine planned-next, surface client decisions.
5. **Draft** (§5): fill the template, outcomes-first, metrics reframed, every cell sourced-or-omitted-or-tagged (§6), omit-empty, client language.
6. **Score + scrub** (§7 + §9): quality score >= 10/12 with #3/#4/#5 nonzero, then run the four verification greps on every produced file until silent.
7. **Render** (§8, only if `--pdf`/`--docx`): Chrome-headless PDF (verify chrome exit 0 + `test -s` + `pdfinfo` pages >= 1) and/or pandoc docx. Never pandoc-PDF.
8. **Land** (§5f): `mkdir -p` the deliberate notes dir, write the file(s).
9. **Hand off, do NOT send** (§0.4): tell Christopher exactly where the report is, report the evidence gaps (anything tagged/omitted for lack of a source), and that it is ready for him or Suryadi to review and send. Report back as tables (`feedback_visual_structured_docs`).

> First run, or want the whole flow on one page? `references/worked-example.md` is a complete multi-repo trace end to end: guarded gathering (the rev-list guard + the multi-repo loop), commit clusters becoming client outcomes, every health cell sourced (a milestone baseline legitimizing "On Track", not a default green), coverage omitted for lack of an artifact, the V1-V4 scrub, the verified Chrome render, and the generator-only hand-off. Every number in it is illustrative, never copy a figure.

## COMPOSES WITH

- **/worklog** owns billable hours (this skill never counts hours); a status report and a timesheet are different artifacts for the same week.
- **/handover** is the FINAL close-out (BAST + delivery package) when the project ends; status-report is the recurring mid-build update.
- **/proposal** scoped the engagement; a won proposal's milestones are the baseline this report measures progress against.
- **/invoice** bills a milestone; the status report is the progress narrative, not the bill.
- **/agent-browser** owns any live-app screenshot for the report (never inline a browser recipe, never kill the live browser).
- **/commit** for any in-repo write (seal-guard enforced; never raw `git commit`).

Remember: this report leaves the building and a paying client reads it. Its value is that it is TRUE, SPECIFIC, and SKIMMABLE. A client who can trust every number in it trusts the software house. Translate the real week into real outcomes, report health honestly, demote the churn, scrub the leaks, and hand it to Christopher to send.
