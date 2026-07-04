# references/metrics-and-framing.md: what a client should see, and how to frame it

Progressive-disclosure companion to `SKILL.md` §5a (rule 4, anti-vanity). The rule "never headline code churn as value, lead with deliverables" lives in SKILL.md; this file is the full taxonomy, the trend thresholds, and the slow-week framing playbook.

Core principle: **a client measures progress in outcomes delivered, not in code produced.** Every metric in the report is chosen to answer the client's real question ("are we getting what we are paying for, and is it on time?"), never to look busy.

---

## 1. The client-visible vs internal-only metric taxonomy

| Metric | Client-visible? | Why / how to frame it |
|---|---|---|
| **Deliverables / features completed** | YES, LEAD with it | The primary progress signal. "3 of the 4 checkout deliverables shipped." |
| **Milestone progress (M of N)** | YES, if a real source | From a board/roadmap/milestone (SKILL §6). The client's timeline anchor. |
| **Bugs closed / open-bug trend** | YES | Real client value: quality is going up or down. A falling open-bug count is genuine good news. |
| **Demo-ready / testable features** | YES | "The order screen is ready for you to try on staging." Actionable for the client. |
| **PRs merged** | YES, but SECONDARY | In the "Development activity" table, framed as activity. A rough throughput signal, not progress. |
| **Commits** | SECONDARY, activity table only | Never a headline. A busy commit week can be zero progress (thrash) or one big delete (great progress). |
| **Lines added** | NO, never in the client report | Pure vanity. More lines is not more value. Anchors the client on churn. |
| **Lines removed** | NO, never in the client report | A great refactor deletes code; shown as "-3,000" it reads as a loss. Report the OUTCOME instead. |
| **Files changed** | NO | Activity noise, meaningless to a client. |
| **Test coverage %** | ONLY if a real artifact was read | Omit entirely if no coverage file exists (SKILL §3d, §6). Never guess. |
| **TODO/FIXME count** | RARELY, only if trending meaningfully | Internal quality signal; cite the number never the comment text (leak risk, §0.2). |
| **Contributor / author list** | NO | Internal team structure; generalize to "the team" (§0.2). |
| **Velocity vs prior week** | YES, as a trend arrow | Real numbers (merged PRs, closed issues) with the §2 threshold, not a vibe. |

The "Development activity" table in the report carries ONLY: deliverables completed, PRs merged, issues/bugs closed, open bugs. It is explicitly captioned "activity indicators for transparency, progress is measured by the deliverables above". That caption is not optional; it is what stops the client anchoring on throughput.

---

## 2. Trend-arrow thresholds (kill noise, kill false precision)

An arrow appears only for a MEANINGFUL change:

| Prior | This | Arrow? |
|---|---|---|
| 4 | 4 | flat (no arrow) |
| 4 | 5 | flat (a 1-unit change is noise) |
| 4 | 7 | up arrow (>1 and >~10%) |
| 12 | 10 | down arrow (>1 and >~15%) |
| any | (no prior data) | OMIT the "Prior week" and "Trend" columns entirely (first report) |

Rule: arrow only when the difference is greater than 1 unit AND greater than ~10% of the prior value. A single up-tick is not a trend; do not draw one. Never invent a prior number to manufacture a trend.

---

## 3. Framing a slow week honestly (rule 3, the credibility test)

A slow week is where honesty is tested. The report must NOT inflate it, and must NOT bury the reason. The move: state it plainly, give the real cause, show what it protects or unblocks.

| Do | Don't |
|---|---|
| "This week was slower than planned. Two days went to a production data-integrity fix that was not on the roadmap but protected live customer orders." | "Made great progress this week!" (inflation, §7a) |
| "Feature work paused while we waited on the payment-gateway credentials from your side (see Decisions needed)." | "Everything is on track." (a bare unsourced assurance) |
| "One deliverable slipped to next week; the API it depends on needed a redesign we caught in review." | (silently omitting the slip and hoping it is not noticed) |

A client who reads an honest "slow week, here is why" trusts the next report. A client who later finds a rosy report was hollow trusts nothing. The slow-week narrative also naturally surfaces a "Decisions needed" item (waiting on the client) or a risk, which is genuinely useful.

---

## 4. When a delete-heavy refactor happens (the anti-vanity trap in action)

Scenario: the week's biggest and best work was rebuilding the sync engine, net `-3,000` lines.

- WRONG: a Metrics row "Lines removed: 3,000" (reads as a loss, §1).
- RIGHT: a Completed item, "**Rebuilt the offline sync engine.** It is now simpler and faster, which lowers the risk of the sync errors seen last month." No line count. The outcome and the client benefit, full stop.

If Christopher specifically wants an internal churn number for his own tracking, that lives in HIS internal view (or a /worklog note), never in the client report.

---

## 5. Coverage and quality metrics: the "only if real" rule

- Test coverage %: include the row ONLY if a coverage artifact (`coverage-summary.json`, `lcov.info`, `.coverage`, `htmlcov/`) was actually read and you can cite the number. Otherwise OMIT the entire row (SKILL §3d). A blank or guessed coverage cell is the same fabrication class as a guessed sprint % (§0.3).
- Performance numbers (latency, load): only if a real benchmark or monitoring source was read, else tag `(target)` and say it is a goal, not a measurement.
- "Passing" build: only from a real CI conclusion or a verified deploy. Otherwise "Unknown" is the honest cell.

---

## 6. The one-line litmus for any metric before it goes in

Ask: *"Does this number answer the client's question 'am I getting what I pay for, on time?', and can I point at where it came from?"*

- Yes to both: it belongs, with its source.
- Answers the question but no source: omit or tag (§6c).
- Has a source but does not answer the question (LOC, files changed, commit count as a headline): demote to the activity table or cut. It is activity, not progress.
