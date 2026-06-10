---
name: retro
description: Run Christopher's weekly Sunday retrospective — a 30-min evidence-based review of the week's shipped/stalled work that names ONE bottleneck and commits to ONE behavioral change, writes ~/claude/notes/retros/retro_<YYYY-W##>.md, checks whether last week's change stuck, and DMs Toper a <20-line digest. Use when the user says /retro, "run the retro", "weekly retro", or it's Sunday and the retro is due.
argument-hint: [week YYYY-W## | --dry-run]
allowed-tools: Read, Glob, Grep, Bash, mcp__plugin_whatsapp_whatsapp__check_number, mcp__plugin_whatsapp_whatsapp__list_chats, mcp__plugin_whatsapp_whatsapp__send_message
---

# /retro — weekly Sunday retrospective (one bottleneck, one change)

Formalizes the weekly-retro ritual (`feedback_weekly_retro` + `~/claude/templates/retro-template.md`). Reads the week's REAL evidence (git, work-queue, journal, decisions.log, notes, memory diffs), produces a structured retro file, and sends Toper a short digest. The whole point is **cumulative**: name one friction point, commit to one specific change, and **check next week whether it stuck** — so last week's bottleneck doesn't silently become this week's.

**Output file:** `~/claude/notes/retros/retro_<YYYY-W##>.md` (ISO week, e.g. `retro_2026-W24.md`).
**Digest recipient:** `62817712289@s.whatsapp.net` (Toper SUPERUSER).
**Timezone:** `Asia/Jakarta` (WIB). **Cadence:** Sunday, ~30 min.

---

## The two non-negotiable disciplines (HARD RULES — the skill exists to enforce these)

1. **ONE bottleneck per week. Not two. Not a list.** Section 3 names exactly one friction point, with a *quantified* cost (hours wasted / threads stalled / decisions missed / context lost). If you're tempted to list three, you haven't found the real one — pick the highest-cost one and cut the rest. A vague bottleneck ("too much context-switching") is a failure; a specific one ("Toper decision latency on signal-trader patches — 2 threads paused 3+ days each") passes.

2. **ONE behavioral change per week. Specific, triggered, measurable.** Section 4 commits to exactly one change. It MUST have a concrete **trigger** ("when a thread is paused >48h"), a concrete **action** ("send a one-line WA nudge with explicit default + 24h timer"), and a **hypothesis** ("paused-thread age drops below 48h median"). Banned: "communicate better", "be more proactive", "improve X" — these are not changes, they're wishes. If the change can't be evaluated next Sunday with a yes/no "did it stick?", rewrite it.

Both disciplines are scored at the end (see "Self-check gate"). If either fails the gate, fix before sending.

---

## Step 0 — parse + pick the week

`$ARGUMENTS`:
- empty → retro for the **current ISO week** (the one being closed today).
- `week YYYY-W##` → retro for that explicit week (back-fill a missed Sunday).
- `--dry-run` → run everything except the WhatsApp send + the next-week reminder; print the digest under a banner.

Anchor the clock, derive the ISO week, and compute the 7-day window:

```bash
date '+now: %Y-%m-%d %H:%M %Z (dow %u)'              # dow 7 = Sunday
TZ=Asia/Jakarta date +"%G-W%V"                        # ISO year-week, e.g. 2026-W24
TZ=Asia/Jakarta date -d "7 days ago" +"%Y-%m-%d"     # window start
TZ=Asia/Jakarta date +"%Y-%m-%d"                      # window end (today)
```

**Cadence guard:** if today is NOT Sunday and no explicit week was given, note the slip but proceed — `feedback_weekly_retro`: "If Sunday is missed, do Monday, but log the slip" (record it in Section 6). Never silently skip a week.

**Idempotency:** if `~/claude/notes/retros/retro_<week>.md` already exists, do NOT overwrite blind — read it, and either (a) report "retro for <week> already exists" and exit if it's complete, or (b) append/refresh if it was a stub. Never clobber a finished retro.

## Step 1 — gather the week's evidence (sources are mandatory, not optional)

Per `feedback_weekly_retro`, pull from ALL of these. Evidence-free retro sections are not acceptable.

```bash
# 1. Shipped-work signal across active repos (run per repo under ~/claude/Git/repositories/)
for r in ~/claude/Git/repositories/*/; do
  [ -d "$r/.git" ] && printf '\n=== %s ===\n' "$r" && git -C "$r" log --since="7 days ago" --pretty=format:'%ad %h %s' --date=short 2>/dev/null
done
```

- **Shipped (Section 1):** the git log above + work-queue `## Recently shipped` rows + `result.json` files with `status:done` in `~/claude/notes/*/` modified this week. Build the per-day table: Day | Task | Outcome | Evidence(commit/path).
- **Stalled/dropped (Section 2):** `~/claude/state/work-queue.md` → `## Paused — awaiting Toper decision` + `## Paused — awaiting external …` (paused-since dates), plus any `result.json` with `status:blocked`/`partial`. Compute `days paused` from the paused-since date. **Flag anything paused >5 days** for a kill-vs-resume call.
- **Decisions audit (feeds Section 3/6):** `~/claude/state/decisions.log` rows within the window — especially `overridden: y` rows (a defaulted decision Toper later reversed is a strong bottleneck signal) and clusters of defaults on the same slug (decision latency).
- **Journal (feeds everything):** `~/.claude/memory/journal.md` entries within the window — `decision`/`feedback`/`project` tags are the week's narrative. This is the richest single source for "what actually happened". (Capture half of the journal→audit loop; see `/journal`.)
- **Notes (Section 1/2 detail):** skim `~/claude/notes/*/report.md` modified this week for major outcomes.
- **Memory diffs (Section 5):** files added/modified in `~/.claude/memory/` this week:
  ```bash
  find ~/.claude/memory -name '*.md' -mtime -7 -printf '%TY-%Tm-%Td  %p\n' | sort
  ```

## Step 2 — read LAST week's retro (HARD RULE — closes the loop)

This is what makes the ritual cumulative. Find the most recent prior retro:

```bash
ls -1 ~/claude/notes/retros/retro_*.md 2>/dev/null | sort | tail -3
```

Read the latest prior `retro_<week-1>.md` and extract its **Section 4 "Change to try"** (trigger + action + hypothesis). Then **evaluate, from this week's evidence, whether that change actually happened and whether it helped.** This becomes a required subsection in Section 4 of the new retro:

```
### Did last week's change stick?
- Last week's change: <verbatim>
- Evidence it fired: <journal/decisions.log/work-queue proof, or "no evidence it fired">
- Verdict: STUCK / PARTIAL / DROPPED
- Carry-over: <keep it / evolve it / abandon + why>
```

If the SAME bottleneck shows up 2+ weeks running, that's **structural, not tactical** — escalate it explicitly in Section 3 (`feedback_weekly_retro`: cross-reference past retros; recurring = escalate). If there is no prior retro (first ever), say so and skip the "did it stick" subsection.

## Step 3 — write the retro file

Write `~/claude/notes/retros/retro_<week>.md` using `~/claude/templates/retro-template.md` verbatim (read it for the exact section layout). The six sections:

1. **Shipped this week** — the per-day table + total count.
2. **Stalled / dropped this week** — table with `days paused` + resolution; >5-day items flagged for kill-vs-resume.
3. **Bottleneck identified** — exactly ONE, with quantified cost + new-or-recurring pattern (cross-ref past retros).
4. **Change to try next week** — exactly ONE (trigger + action + hypothesis) + the "Did last week's change stick?" subsection from Step 2.
5. **Memory / playbook diffs** — files added/modified in `~/.claude/memory/`; if a feedback rule was learned but not yet saved, note it (and prefer `/journal` to queue it for the audit).
6. **Notes for compaction-safe context** — active threads (link work-queue), decisions made + rationale, open external deps, people-state. Log any cadence slip here.

**Tone (HARD RULE, `feedback_no_yesman_sugarcoat`):** name uncomfortable patterns honestly. If a thread stalled because main waited too long to nudge Toper, write that. If a worker shipped low-quality work, write that. The retro is worthless if it flatters. Ask of every line: "am I writing this because it's true, or to make the week look better?" — if the latter, rewrite it truer.

## Step 4 — self-check gate (run BEFORE sending; fix failures in-place)

Score the retro against the two disciplines. ALL must pass or the retro is not done:

- [ ] **Section 3 names exactly ONE bottleneck** (not 0, not 2+) and it has a *quantified* cost (a number: hours / threads / days / decisions). Vague-cost = FAIL.
- [ ] **Section 4 commits to exactly ONE change** with an explicit trigger + action + hypothesis, and it is evaluable next Sunday with a yes/no. "Be better"-class = FAIL.
- [ ] **Last week's change was evaluated** (STUCK/PARTIAL/DROPPED with evidence) — unless this is the first-ever retro.
- [ ] **Every Section 1/2 row cites evidence** (a commit hash, a file path, a paused-since date) — no evidence-free claims.
- [ ] **Recurring bottleneck escalated** if it appears 2+ weeks running.
- [ ] **Tone is honest** — at least one uncomfortable truth is named if the week had friction (a frictionless week is rare; be suspicious of an all-green retro).

If any box fails, revise the file, then re-check. Do not send a failing retro.

## Step 5 — send the digest

Per `feedback_weekly_retro`: a **5-section digest, <20 lines**, NOT the whole retro. Pre-flight the JID (`feedback_whatsapp_no_random_messaging`) via `check_number`/`list_chats` before sending. No em/en dashes (`feedback_no_long_hyphens`). Structural label emojis only.

```
🗓️ retro {YYYY-W##}

✅ shipped: {N} tasks
⏸️ stalled: {M} ({worst one, days paused})
🎯 bottleneck: {one line — the single friction + its cost}
🔧 change minggu depan: {one line — trigger + action}
↩️ last week's change: {STUCK | PARTIAL | DROPPED}

full: ~/claude/notes/retros/retro_{YYYY-W##}.md
```

- **If dry-run:** print the digest under `=== DRY RUN (retro digest, not sent) ===`; do NOT call WhatsApp and do NOT set the reminder.
- **If not dry-run:** `mcp__plugin_whatsapp_whatsapp__send_message` to `62817712289@s.whatsapp.net`. Verify the return (`feedback_verify_after_write`); retry once on error, then surface failure. (Param names vary — inspect schema at call-time.)

## Step 6 — arm the next-week evaluation (closes the loop forward)

So the "did it stick?" check actually happens, schedule a reminder to run the retro next Sunday. Use the `/remindme` mechanism (CronCreate, recurring, durable). If a recurring `weekly-retro` reminder already exists (`CronList` → filter `[REMINDME id=weekly-retro`), do NOT create a duplicate — just confirm it's armed. Otherwise create:

```
CronCreate(cron="58 9 * * 0", recurring=true, durable=true,
  prompt="[REMINDME id=weekly-retro] Send WA to 62817712289@s.whatsapp.net: ⏰ REMINDER / Topic: run /retro (weekly Sunday retro, evaluate last week's change) / Scheduled: every Sunday ~10am … <AUTO_RENEW_CLAUSE>")
```

(Sunday = dow `0`; ~10am via early-nudge minute `58` hour `9`, per `/remindme` conventions.) In dry-run, skip this step. Note in the session output whether the reminder was already armed or freshly created.

## Worked example

`/retro`, now Sun 2026-06-14 ~20:00 WIB, ISO week `2026-W24`, prior retro `retro_2026-W23.md` exists.

- **Evidence:** git log shows 9 commits across aenoxa_pos_web (3) + chilldawg-setup (4) + bms fitest notes (2). work-queue: `fitest-batches-6-7` paused 5 days (awaiting Toper "Go"); `pulse-billing-tenant-id-bug` paused 8 days (backlog). decisions.log: one `overridden: n` default on `bms-remaining-author`. journal: 14 entries, dominant theme = ISI fitest closeout.
- **Section 3 bottleneck:** "Toper decision latency on `fitest-batches-6-7` — paused 5 days awaiting a one-word 'Go', blocking ~6h of queued authoring." (cost quantified: 5 days + 6h).
- **Section 4 change:** Trigger = "any thread paused >48h awaiting a Toper yes/no". Action = "morning standup surfaces it with an explicit 1h-default + auto-proceed". Hypothesis = "paused-decision median age drops under 48h; measured from work-queue paused-since dates next retro."
- **Did last week's change stick?** Last week (W23) committed "send WA nudge for >48h paused threads". Evidence: 2 nudges in journal (`feedback`-tagged), 1 thread resumed within 24h of nudge. Verdict: PARTIAL (nudges fired but one thread still aged out). Carry-over: evolve into the standup-default mechanism above.
- **Self-check:** 1 bottleneck ✓ quantified ✓ / 1 change ✓ trigger+action+hypothesis ✓ evaluable ✓ / last week evaluated ✓ / rows cite commits+paused-since ✓ / recurring? decision-latency appeared W23+W24 → flagged structural ✓ / honest? named that main let `pulse-billing` age 8 days without a kill-call ✓. Gate PASS.
- **Digest** sent to Toper (7 lines). **Reminder** `weekly-retro` already armed → confirmed, not duplicated.

## Never-do list

- Never list more than one bottleneck or more than one change-to-try. The discipline IS the value.
- Never write a vague bottleneck or a non-evaluable change — they fail the gate.
- Never skip the "did last week's change stick?" evaluation (unless first-ever retro).
- Never clobber an existing finished retro file.
- Never paste the whole retro into WhatsApp — digest only, <20 lines.
- Never flatter the week (`feedback_no_yesman_sugarcoat`). An all-green retro with no friction named is a red flag, re-examine.
- Never use em/en dashes or non-label emoji in the digest.
- Never silently skip a missed week — back-fill or log the slip.
- Never duplicate the `weekly-retro` reminder if one already exists.

## Done

After writing the file + sending the digest (+ arming/confirming the reminder), print:
```
DONE — retro {YYYY-W##} written (~/claude/notes/retros/retro_{YYYY-W##}.md), digest sent, next-week reminder {armed|confirmed}
```
(or the dry-run equivalent without send/reminder).
