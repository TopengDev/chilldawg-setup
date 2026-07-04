---
name: retro
description: Run Christopher's weekly Sunday retrospective, a 30-min evidence-based review of the week's shipped/stalled work that names ONE bottleneck and commits to ONE behavioral change, writes ~/claude/notes/retros/retro_<YYYY-W##>.md, checks whether last week's change stuck, and DMs Toper a sub-20-line digest. Use when the user says /retro, "run the retro", "weekly retro", or it's Sunday and the retro is due.
argument-hint: [week YYYY-W## | --dry-run]
allowed-tools: Read, Write, Glob, Grep, Bash, mcp__plugin_whatsapp_whatsapp__check_number, mcp__plugin_whatsapp_whatsapp__list_chats, mcp__plugin_whatsapp_whatsapp__send_message, mcp__plugin_whatsapp_whatsapp__connection_status, mcp__claude_ai_Google_Calendar__create_event, mcp__claude_ai_Google_Calendar__list_events
---

# /retro - weekly Sunday retrospective (one bottleneck, one change)

Formalizes the weekly-retro ritual (`feedback_weekly_retro` + `~/claude/templates/retro-template.md`). Reads the week's REAL evidence, produces a structured retro file, sends Toper a short digest, and arms next week's run. The whole point is **cumulative**: name ONE friction point, commit to ONE specific change, and **check next week whether it stuck**, so last week's bottleneck does not silently become this week's.

**Output file:** `~/claude/notes/retros/retro_<YYYY-W##>.md` (ISO week, e.g. `retro_2026-W27.md`).
**Digest recipient:** `$TOPER_WA_JID` (Toper SUPERUSER, phone-format). See the JID reconciliation note in Step 5 before "fixing" this.
**Timezone:** `Asia/Jakarta` (WIB). Do ALL time math in WIB.
**Cadence:** Sunday ~20:00 WIB, ~30 min. **Recurrence owner:** this skill owns a dedicated `retro.timer` (Step 6), NOT /remindme.

---

## Boundary / routing (which ritual owns what)

Four rituals read overlapping truth-files but answer different questions. Do not collapse them.

| Ritual | Cadence | Audience | Answers |
|---|---|---|---|
| **/retro** (this skill) | weekly (Sun) | internal (Toper) | evidence-based self-improvement: ONE bottleneck + ONE change, cumulative |
| **/standup** + **/daily-brief** | daily | internal (Toper) | state snapshot (what's on my plate / what got done), NOT analysis |
| **/status-report** | weekly | **client-facing** | external progress for a paying project, not the internal week |
| **/journal** | continuous | internal | the append-only capture that **FEEDS** the retro (Section 1/3 spine) |
| **/remindme** | ad-hoc | internal | one-off reminders. **Does NOT schedule the retro** (its HARD RULE 7: retro owns its own timer) |

**Bright line:** standup/daily-brief report *state*; the retro *analyzes* it to change behavior. If asked to "schedule the retro," that is Step 6 here (a dedicated systemd timer), never a /remindme row.

---

## The two non-negotiable disciplines (the skill exists to enforce these)

1. **ONE bottleneck per week. Not two. Not a list.** Section 3 names exactly one friction point, with a *quantified* cost (hours wasted / threads stalled / decisions missed / context lost). If you are tempted to list three, you have not found the real one: pick the highest-cost one and cut the rest. A vague bottleneck ("too much context-switching") is a FAIL; a specific one ("Toper decision latency on fitest-batches-6-7, paused 5 days awaiting a one-word Go, blocking ~6h queued authoring") passes.

2. **ONE behavioral change per week. Specific, triggered, measurable.** Section 4 commits to exactly one change with a concrete **trigger** ("when a thread is paused >48h"), a concrete **action** ("send a one-line WA nudge with explicit default + 24h timer"), and a **hypothesis** ("paused-thread age drops below 48h median"). Banned as non-changes: "communicate better", "be more proactive", "improve X". If it cannot be evaluated next Sunday with a yes/no "did it stick?", rewrite it.

Both are scored PASS/FAIL at the Step 4 gate. If either fails, fix before sending.

---

## HARD RULES (NEVER / ALWAYS)

1. **NEVER** arm the weekly recurrence with `CronCreate(durable)`. It is a **verified no-op** (session-only, dies on restart, per `feedback_time_promise_scheduling` + /remindme MECHANISM TRUTH). The recurrence MUST be the dedicated **systemd `retro.timer`** (Step 6); the only in-skill durable fallback is a **Google Calendar event**. `ScheduleWakeup` is removed from the harness, never reference it.
2. **NEVER** route the retro through **/remindme** (its HARD RULE 7 forbids it). The retro owns its own ritual/timer.
3. **NEVER** change the digest JID from `$TOPER_WA_JID` (phone-format) to the `@lid`. It deliberately matches /standup (both on-demand MCP rituals); the `@lid` is a different surface for the same Toper, not a bug to "fix" (Step 5 note).
4. **NEVER** gather evidence with a hardcoded `"7 days ago"` / `-mtime -7`. **ALWAYS** window `git log` and `find` to the computed `WINDOW_START`..`WINDOW_END` (Step 0). A back-fill with a NOW-anchored window pulls the WRONG week's evidence.
5. **NEVER** fabricate a bottleneck or invent friction on a genuinely quiet week. **ALWAYS** allow `No single friction met the cost bar this week (quiet week)` with evidence (`feedback_no_yesman_sugarcoat`: say it true, do not manufacture drama to look productive).
6. **ALWAYS** treat every Section 1/2 row AND the Section 3 bottleneck as evidence-bound: a specific artifact (commit hash / paused-since date / decisions.log row / result.json path) or it FAILS the gate.
7. **ALWAYS** check `work-queue.md` freshness (mtime vs `WINDOW_START`); if stale, flag it UNRELIABLE and fall back to the fresh spine (result.json `blocked`/`partial` + windowed git + journal).
8. **ALWAYS** pre-flight the digest JID, verify the send return, and on failure run the send-failure playbook (`connection_status` -> preserve the retro to file + flag main). **NEVER** silently drop the retro.
9. **ALWAYS** keep exactly ONE bottleneck and exactly ONE evaluable change; both scored PASS/FAIL at the gate before any send.
10. **NEVER** clobber a finished retro file. Read-first, refresh-a-stub-only.

---

## Step 0 - parse, pick the week, compute the window

`$ARGUMENTS`:
- empty -> the **ISO week being closed** (see the anchor rule below).
- `week YYYY-W##` -> that explicit week (back-fill a missed Sunday).
- `--dry-run` -> run everything EXCEPT the WhatsApp send + the Step-6 recurrence arm; print the digest under a banner.

Anchor to the real clock (never hand-calculate dates):

```bash
date '+now: %Y-%m-%d %H:%M %Z (dow %u)'    # dow 7 = Sunday, 1 = Monday
```

**Pick TARGET_WEEK.** For empty args, anchor so a Sunday run reviews the closing week and a Monday slip reviews the week that just ended:

```bash
if [ -n "$EXPLICIT_WEEK" ]; then
  TARGET_WEEK="$EXPLICIT_WEEK"                        # e.g. 2026-W24
else
  DOW=$(date +%u)
  if [ "$DOW" -eq 1 ]; then ANCHOR=$(date -d "yesterday" +%Y-%m-%d); else ANCHOR=$(date +%Y-%m-%d); fi
  TARGET_WEEK=$(TZ=Asia/Jakarta date -d "$ANCHOR" +%G-W%V)
fi
```

**Compute the window** (ISO-week -> Monday..next-Monday, verified across year boundaries):

```bash
YEAR=${TARGET_WEEK%%-W*}; WK=$((10#${TARGET_WEEK##*-W}))
JAN4="$YEAR-01-04"; J4DOW=$(date -d "$JAN4" +%u)
W1MON=$(date -d "$JAN4 -$((J4DOW-1)) days" +%Y-%m-%d)          # Monday of ISO week 1
export WINDOW_START=$(date -d "$W1MON +$(( (WK-1)*7 )) days" +%Y-%m-%d)   # Mon of target week (inclusive)
export WINDOW_END=$(date -d "$WINDOW_START +7 days" +%Y-%m-%d)            # next Mon (exclusive)
# sanity: this MUST print TARGET_WEEK, else abort
[ "$(date -d "$WINDOW_START" +%G-W%V)" = "$TARGET_WEEK" ] && echo "window $WINDOW_START..$WINDOW_END OK" || echo "WINDOW MISMATCH, abort"
```

Every Step-1 source is windowed to `$WINDOW_START`/`$WINDOW_END` (recipes in `references/evidence-sources.md`). This is the fix for the back-fill bug (HARD RULE 4).

**Cadence guard:** if today is not Sunday and no explicit week was given, note the slip but proceed (`feedback_weekly_retro`: "If Sunday is missed, do Monday, but log the slip", recorded in Section 6). Never silently skip a week; for a 2+ week gap see the multi-week playbook.

**Idempotency (HARD RULE 10):** if `~/claude/notes/retros/retro_<TARGET_WEEK>.md` already exists, do NOT overwrite blind. Read it: if complete (all six `## ` sections, non-stub) report "retro for <week> already exists" and exit; if a stub, refresh the empty sections in place. See failure playbook 6.

## Step 1 - gather the week's evidence (freshness-aware spine)

Pull from ALL sources; evidence-free retro sections are not acceptable. **Priority is freshness-ranked** (full windowed recipes + the repo prefilter live in `references/evidence-sources.md`):

- **PRIMARY (always fresh):** `result.json` (status filter) + windowed `git log` + `journal.md`.
  - `result.json` (`~/claude/notes/*/result.json`, schema `{status(done|blocked|partial), summary, blockers[], ...}`, 201 files / 120 in 14d): `status:done` -> Section 1 shipped; `status:blocked`/`partial` -> Section 2 stalled (with `blockers[]`).
  - windowed git (95 repos, ~2-4 active/week): **prefilter on HEAD mtime** before `git log --since="$WINDOW_START" --until="$WINDOW_END 23:59:59"` so you scan ~4 repos, not 95.
  - journal (`~/.claude/memory/journal.md`, grammar `- [ISO+07:00] (tag) summary`): `(decision)`/`(feedback)`/`(project)` in-window entries are the week's narrative and the richest single source.
- **CORROBORATION only:** `decisions.log` (in-window rows; `overridden: y` and same-slug default clusters are decision-latency signals feeding Section 3), and `work-queue.md` **only if fresh**.
- **FRESHNESS GUARD (HARD RULE 7):** `work-queue.md` was 52 days stale on 2026-07-03. Before using it, compare its mtime to `WINDOW_START`; if older, print `WARN work-queue stale -> UNRELIABLE` and build Section 2 from the fresh spine instead (playbook 4). Never quote a stale paused-since date as current.

Build the Section 1 per-day table (Day | Task | Outcome | Evidence) and the Section 2 stalled table (Task | Why | days paused | Resolution). **Flag anything paused >5 days** for a kill-vs-resume call. Memory diffs for Section 5: `find ~/.claude/memory -name '*.md' -newermt "$WINDOW_START" ! -newermt "$WINDOW_END"`.

## Step 2 - read LAST week's retro (closes the loop)

This is what makes the ritual cumulative. Find the most recent prior retro:

```bash
ls -1 ~/claude/notes/retros/retro_*.md 2>/dev/null | sort | tail -3
```

Read the latest prior `retro_<week-1>.md`, extract its **Section 4 "Change to try"** (trigger + action + hypothesis), then **evaluate from THIS week's evidence whether it actually happened and helped.** Required subsection in Section 4 of the new retro:

```
### Did last week's change stick?
- Last week's change: <verbatim>
- Evidence it fired: <journal/decisions.log/result.json proof, or "no evidence it fired">
- Verdict: STUCK / PARTIAL / DROPPED
- Carry-over: <keep it / evolve it / abandon + why>
```

If the SAME bottleneck appears 2+ weeks running, that is **structural, not tactical**: escalate it explicitly in Section 3 (cross-ref past retros). If there is no prior retro (first ever, the retros dir is empty as of 2026-07-03), say so and skip this subsection.

## Step 3 - write the retro file

Author `~/claude/notes/retros/retro_<TARGET_WEEK>.md`. Use `~/claude/templates/retro-template.md` for the **section 1-6 LAYOUT ONLY**; the skill's own steps **supersede** that template's stale "How to run the retro" appendix (which still repeats the broken reminder assumption). If the template is missing, use the embedded layout below (playbook 5). Read the template for exact table shapes:

1. **Shipped this week** - per-day table + total count.
2. **Stalled / dropped** - table with `days paused` + resolution; >5-day items flagged for kill-vs-resume.
3. **Bottleneck identified** - exactly ONE, quantified cost, new-or-recurring pattern (cross-ref past retros). On a quiet week, `No single friction met the cost bar this week (quiet week)` with thin-evidence citation is valid (HARD RULE 5), never a fabricated one.
4. **Change to try next week** - exactly ONE (trigger + action + hypothesis) + the "Did last week's change stick?" subsection from Step 2.
5. **Memory / playbook diffs** - files added/modified in `~/.claude/memory/`; if a rule was learned but not saved, note it and prefer `/journal` to queue it (do not hand-write a memory file from here).
6. **Notes for compaction-safe context** - active threads, decisions + rationale, open external deps, people-state. Log any cadence slip here.

**Tone (HARD RULE, `feedback_no_yesman_sugarcoat`):** name uncomfortable patterns honestly. If a thread stalled because main waited too long to nudge Toper, write that. If a worker shipped low-quality work, write that. Ask of every line: "am I writing this because it is true, or to make the week look better?" If the latter, rewrite it truer. The inverse also holds: do not invent friction to make a quiet week look eventful.

## Step 4 - self-check gate (run BEFORE sending; fix failures in place)

Score the retro. Render as a PASS/FAIL table; ALL must PASS or the retro is not done:

| # | Check | PASS condition |
|---|---|---|
| 1 | ONE bottleneck | Section 3 names exactly one (not 0, not 2+), with a *quantified* cost (a number). Vague-cost = FAIL |
| 2 | ONE change | Section 4 has exactly one with trigger + action + hypothesis, evaluable next Sunday yes/no. "Be better"-class = FAIL |
| 3 | Last week evaluated | STUCK/PARTIAL/DROPPED with evidence (unless first-ever retro) |
| 4 | Evidence-citation | every Section 1/2 row AND the bottleneck cite a concrete artifact (hash / path / paused-since / log row) |
| 5 | Window-correctness | for a back-fill, evidence dates fall inside `WINDOW_START`..`WINDOW_END` (spot-check 2 rows) |
| 6 | Freshness | work-queue mtime verified fresh, or flagged UNRELIABLE and the fresh spine used |
| 7 | Recurring escalated | a bottleneck seen 2+ weeks running is flagged structural in Section 3 |
| 8 | Honest tone | at least one uncomfortable truth named IF the week had friction; AND no fabricated bottleneck on a quiet week |

If any box FAILS, revise the file, then re-check. Do not send a failing retro.

## Step 5 - send the digest

A **5-section digest, sub-20 lines**, NOT the whole retro (`feedback_weekly_retro`). Pre-flight the JID (`feedback_whatsapp_no_random_messaging`) via `check_number` (param `phone`) or `list_chats` before sending. No em/en dashes (`feedback_no_long_hyphens`). Structural label emojis only (the six below are the retro's greenlit label set, like /standup's, not conversational emoji).

```
🗓️ retro {YYYY-W##}

✅ shipped: {N} tasks
⏸️ stalled: {M} ({worst one, days paused})
🎯 bottleneck: {one line, the single friction + its cost}
🔧 change minggu depan: {one line, trigger + action}
↩️ last week's change: {STUCK | PARTIAL | DROPPED | n/a (first retro)}

full: ~/claude/notes/retros/retro_{YYYY-W##}.md
```

- **First-ever retro** (retros dir empty, the current state on 2026-07-03): the `↩️` line reads `n/a (first retro)` and Section 4's "did it stick?" subsection is skipped (Step 2). **Quiet week:** render `⏸️ stalled: 0 (none)` and put the verbatim quiet-week line on `🎯` (playbook 1).
- **If dry-run:** print under `=== DRY RUN (retro digest, not sent) ===`; do NOT call WhatsApp, do NOT arm the recurrence (Step 6).
- **If not dry-run:** `mcp__plugin_whatsapp_whatsapp__send_message(to="$TOPER_WA_JID", message=<body>)`. **Verify the return** (`feedback_verify_after_write`). On error, run the **send-failure playbook** (playbook 2): `connection_status` -> retry once if connected -> if still failing, preserve the digest into the retro file under a `## DIGEST (unsent ...)` block + flag main. NEVER silently drop the retro.

> **JID reconciliation (do NOT silently change):** the digest goes to `$TOPER_WA_JID` (phone-format) via the WhatsApp MCP, matching /standup's on-demand MCP-ritual choice (`feedback_whatsapp_lid_vs_phone_jid`). `$TOPER_WA_LID` reaches the same Toper but is a different surface (standup + daily-brief each document their own JID/transport choice; do NOT reconcile them from here). The per-ritual differences are deliberate, never a bug to "silently fix" (standup reconciliation note). remindme HARD RULE 5's "the LID is the MCP-ritual JID" is an over-simplification; do NOT switch retro to the LID on the strength of it.

## Step 6 - arm the next-week evaluation (durable recurrence, NO CronCreate)

So the "did it stick?" check actually happens, the retro must be scheduled by a mechanism that **survives a session restart**. `CronCreate(durable)` does NOT (HARD RULE 1). Full architecture + exact unit content in `references/scheduling.md`.

**Detect the dedicated timer:**
```bash
systemctl --user list-timers --all 2>/dev/null | grep -i retro
```
- **Timer PRESENT** -> report `recurrence armed (retro.timer, next Sun 20:00 WIB)`. Done. Do NOT also arm the calendar (that would double-nudge).
- **Timer ABSENT** -> (a) surface the one-time **human-gated install** (the `retro.timer` + `retro.service` unit content lives in `references/scheduling.md`; installing writes to `~/.config/systemd/user/`, outside this skill dir), AND (b) arm ONE durable **Google Calendar** event for next Sunday as the bridge:
  1. **Duplicate guard first:** `list_events` for next Sunday with `fullText="weekly-retro"`; if any exists, skip (already armed).
  2. Else `create_event(summary="weekly-retro: run /retro", startTime="<next-Sun>T20:00:00+07:00", endTime="<next-Sun>T20:30:00+07:00", timeZone="Asia/Jakarta", overrideReminders=[{"method":"popup","minutes":0}])`. Compute `<next-Sun>` off the clock: `dow=$(date +%u); add=$(( (7-dow)%7 )); [ "$add" -eq 0 ] && add=7; date -d "+$add days" +%Y-%m-%d`.

In dry-run, skip this step entirely. Note in the session output whether the timer was armed/confirmed or the calendar bridge was set.

## Failure playbooks (condensed, full commands in `references/failure-playbooks.md`)

| Trigger | Recovery (one line) |
|---|---|
| **Quiet / no-data week** | Produce the retro honestly; Section 3 = "no friction met the cost bar (quiet week)" + thin-evidence cite; still commit ONE experiment or carry last week's. NEVER fabricate a bottleneck. |
| **Digest send fails** | `connection_status`; retry once if connected; else write the digest into the retro file (`## DIGEST (unsent)`) + flag main. Never drop. Never restart wa-sender. |
| **Multi-week gap** | Back-fill each missed week oldest-first as its own windowed file (`/retro week YYYY-W##`), or one catch-up retro that logs the slip in Section 6. |
| **Stale / missing work-queue** | Freshness guard; if stale, mark UNRELIABLE and build Section 2 from result.json (`blocked`/`partial`) + windowed git + journal. |
| **Missing retro-template** | Use the embedded Step-3 layout; note the template was missing in Section 6. Never edit the read-only template. |
| **Idempotent re-run** | Read-first; complete file -> report + exit; stub -> refresh empty sections in place. Never blind-overwrite. |

## Worked examples

**A - normal week.** `/retro`, Sun 2026-06-14 ~20:00 WIB, `TARGET_WEEK=2026-W24`, window `2026-06-08..2026-06-15`, prior `retro_2026-W23.md` exists.
- **Evidence:** prefilter -> 3 active repos; windowed git 9 commits (aenoxa_pos_web 3, chilldawg-setup 4, bms fitest notes 2); result.json 2 `done`, 1 `partial`; work-queue mtime fresh -> `fitest-batches-6-7` paused 5 days; decisions.log 1 `overridden: n`; journal 14 entries, theme = ISI fitest closeout.
- **Section 3:** "Toper decision latency on `fitest-batches-6-7`, paused 5 days awaiting a one-word Go, blocking ~6h queued authoring." (cost: 5 days + 6h). Recurring W23+W24 -> flagged structural.
- **Section 4:** Trigger = "any thread paused >48h awaiting a Toper yes/no". Action = "morning standup surfaces it with an explicit 1h-default + auto-proceed". Hypothesis = "paused-decision median age drops under 48h, measured next retro."
- **Did last week's change stick?** W23 committed "send WA nudge for >48h paused threads". Evidence: 2 nudges in journal (`feedback`-tagged), 1 thread resumed within 24h. Verdict: PARTIAL. Carry-over: evolve into the standup-default above.
- **Gate:** all 8 boxes PASS. Digest sent (7 lines). Step 6: timer PRESENT -> confirmed, no calendar.

**B - quiet week (anti-fabrication).** `/retro`, Sun, `TARGET_WEEK=2026-W27`, window `2026-06-29..2026-07-06`.
- **Evidence:** prefilter -> 2 active repos, 6 commits (both chilldawg-setup skill work); result.json all `done`, zero `blocked`/`partial`; work-queue STALE (mtime 52d < window) -> flagged UNRELIABLE, spine = git+journal+result.json; journal quiet.
- **Section 3:** `No single friction met the cost bar this week (quiet week).` Cite: 6 commits, zero blocked threads, no overridden decisions. (NOT a manufactured bottleneck.)
- **Section 4:** carry W26's change forward one more week (state why), OR one small forward experiment.
- **Gate:** box 8 (anti-fabrication) PASSES because no invented bottleneck. Digest sent.

**C - back-fill a missed week.** `/retro week 2026-W24`, run on 2026-07-03 (a Friday, W27).
- Step 0 computes `WINDOW_START=2026-06-08`, `WINDOW_END=2026-06-15` (the target week, NOT the current one). All Step-1 commands window to those dates: `git log --since="2026-06-08" --until="2026-06-15 23:59:59"`, `find ... -newermt "2026-06-08" ! -newermt "2026-06-15"`.
- Gate box 5 (window-correctness) spot-checks that cited commit/result.json dates fall in `2026-06-08..2026-06-15`, not this week. Section 6 logs "back-filled, ran W27".

## Never-do list

- Never list more than one bottleneck or more than one change-to-try. The discipline IS the value.
- Never write a vague bottleneck or a non-evaluable change (they fail the gate); and never FABRICATE one on a quiet week.
- Never skip the "did last week's change stick?" evaluation (unless first-ever retro).
- Never clobber an existing finished retro file.
- Never paste the whole retro into WhatsApp; digest only, sub-20 lines.
- Never flatter the week (`feedback_no_yesman_sugarcoat`). An all-green retro with no friction named is a red flag; re-examine.
- Never use em/en dashes or non-label emoji in the digest.
- Never gather evidence with a NOW-anchored window on a back-fill (HARD RULE 4).
- Never arm the recurrence with `CronCreate`, and never route the retro through /remindme (HARD RULES 1, 2).
- Never silently skip a missed week; back-fill or log the slip.
- Never switch the digest JID to the LID (Step 5 note).
- Never modify the read-only sources (work-queue, decisions.log, journal, template) or edit them from here.

## Done

After writing the file + sending the digest (+ arming/confirming the recurrence), print:
```
DONE - retro {TARGET_WEEK} written (~/claude/notes/retros/retro_{TARGET_WEEK}.md), digest {sent|UNSENT-preserved}, recurrence {timer-confirmed|calendar-bridge-armed}
```
(or the dry-run equivalent: `DONE - retro {TARGET_WEEK} dry-run printed, no send, no recurrence arm`).
