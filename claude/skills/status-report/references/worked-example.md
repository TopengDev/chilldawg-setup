# references/worked-example.md: one full multi-repo end-to-end trace

Progressive-disclosure companion to `SKILL.md`. ONE complete run, from invocation to hand-off, showing the guarded gathering, the commit-to-outcome translation, the sourced-or-omitted health cells, the scrub, and the generator-only hand-off.

**Every number below is an ILLUSTRATIVE PLACEHOLDER, not a fact.** Do not copy any figure into a real report. The point is the SHAPE of the work, not the values.

---

## The invocation

```
/status-report "2026-03-17 to 2026-03-24" --client "PT Sinar Retail" --project "Sinar POS" --repos ~/claude/Git/repositories/sinar_web,~/claude/Git/repositories/sinar_api --pdf
```

## Step 1: parse (SKILL §1)

```bash
SINCE=2026-03-17 ; UNTIL=2026-03-24
PRIOR_UNTIL=2026-03-17 ; PRIOR_SINCE=$(date -d "2026-03-24 - 14 days" +%F)   # -> 2026-03-10
```
- Client = "PT Sinar Retail"; project display name = "Sinar POS" (NOT the repo slugs `sinar_web` / `sinar_api`).
- Repos = two (a frontend + a backend). Render = PDF requested. Language = en (default).

## Step 2: boundary check (SKILL §2)

Recurring external client progress update on active build work => this IS /status-report. Not hours (/worklog), not a personal retro, not a handover. Proceed.

## Step 3: gather, GUARDED and multi-repo (SKILL §3, references/git-recipes.md)

```bash
COMPANY_NAME=$(jq -r '.company.name' ~/.claude/invoices/config.json)   # "Prepared by", not hardcoded

for REPO in ~/claude/Git/repositories/sinar_web ~/claude/Git/repositories/sinar_api; do
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "skip $REPO"; continue; }
  echo "== $(basename "$REPO") =="
  git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --oneline | wc -l
  git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --pretty=format:'%h %s'
  # guarded period delta (no rev-list substitution footgun):
  FIRST=$(git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --format=%H --reverse | head -1)
  LAST=$(git  -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --format=%H | head -1)
  if [ -z "$FIRST" ]; then echo "NO_COMMITS"; else
    BASE=$(git -C "$REPO" rev-parse -q --verify "${FIRST}^" 2>/dev/null || git hash-object -t tree /dev/null)
    git -C "$REPO" diff --shortstat "$BASE" "$LAST"   # internal only, LOC never reaches the client
  fi
done
```

Illustrative captured output:

| Repo | Commits (period) | Net shortstat (internal only) |
|---|---|---|
| sinar_web | 14 | 22 files, +1,800 / -240 |
| sinar_api | 9 | 11 files, +640 / -3,050  (a big refactor: a DELETION, which is GOOD, §4a) |

```bash
gh pr list --state merged --search "merged:2026-03-17..2026-03-24" --limit 50 --json number,title,labels
#   -> #142 "checkout: Midtrans callback", #145 "checkout e2e", #148 "sync engine rebuild", #150 "receipt print"
gh issue list --state open --label bug --limit 30 --json number,title        # -> 3 open bugs
gh issue list --state closed --search "closed:2026-03-17..2026-03-24" ...     # -> 6 closed
gh run list --limit 5 --json conclusion,name                                  # -> latest: success
gh issue list --milestone "M2 Checkout" --state all --json state             # -> closed:8 open:4  => 8 of 12
```

Prior week (2026-03-10 to 2026-03-17) for trends: 4 PRs merged, 4 issues closed, 5 open bugs.

Memory + artifacts: `~/.claude/memory/MEMORY.md` index -> a `project_*` entry notes the M2 Checkout milestone target is 2026-03-31 (the milestone baseline that legitimizes an "Overall status"). `sinar_web/ROADMAP.md` read for planned-next. NO coverage artifact found in either repo => coverage row will be OMITTED.

## Step 4: synthesize, commit clusters -> client outcomes (SKILL §4)

| Commit cluster (internal) | Client outcome (report) | Source |
|---|---|---|
| #142 + #145 + 6 web commits around checkout | **Customer checkout is complete.** Orders now confirm end-to-end with Midtrans payment, ready for you to test on staging. | PRs #142, #145 |
| #148, api `-3,050` lines | **Rebuilt the offline sync engine.** Simpler and faster, which lowers the risk of the sync errors from last month. (No line count shown, §4a / metrics-and-framing §4.) | PR #148 |
| #150 + 3 web commits | **Receipt printing works** on the thermal printer models you use. | PR #150 |
| 6 closed bug issues | Open bugs down from 5 to 3. | gh issue counts |

Health inference (SKILL §6b): milestone M2 target 2026-03-31 EXISTS, 8 of 12 items done, no active blocker, remaining 4 items fit the week left => **On Track** is legitimately sourced (not a default green). Build = success from CI => Passing.

## Step 5: draft (SKILL §5), the client-facing report (abridged)

```markdown
# Sinar POS: Weekly Status Report

**Client:** PT Sinar Retail
**Report period:** 2026-03-17 to 2026-03-24
**Prepared by:** <company.name from config>
**Date:** 2026-03-24

## Executive summary
Checkout is complete and ready for you to test on staging, and the sync engine rebuild
is done ahead of the M2 milestone. We closed 6 issues and open bugs are down to 3. We need
one decision from you this week on the receipt logo (see below) to keep printing on schedule.

## Project health
| Indicator | Status |
|---|---|
| Overall status | On Track (M2 milestone, target Mar 31, 8 of 12 items done) |
| Milestone progress | 8 of 12 deliverables complete (M2 Checkout) |
| Open items needing attention | 3 open bugs |
| Build / deployment | Passing |

## Completed this week
### Checkout and payments
- **Customer checkout is complete.** Orders confirm end-to-end with Midtrans payment, ready to test on staging.
- **Receipt printing works** on your thermal printer models.
### Reliability
- **Rebuilt the offline sync engine.** Simpler and faster, lowering the risk of the sync errors seen last month.

## In progress
| Item | Status | Expected completion | Notes |
|---|---|---|---|
| Inventory adjustment screen | In review | 2026-03-27 (estimate) | on track for M2 |

## Decisions needed from you
| # | Decision | Why it matters | Our recommendation | Needed by |
|---|---|---|---|---|
| 1 | Final receipt logo file | Printing is built but needs your logo to finish | Send the SVG or a high-res PNG | 2026-03-26 |

## Development activity
> Activity indicators for transparency. Progress is measured by the deliverables above, not by code volume.

| Indicator | This week | Prior week | Trend |
|---|---|---|---|
| Deliverables completed | 3 | 1 | up |
| Pull requests merged | 4 | 4 | flat |
| Issues / bugs closed | 6 | 4 | up |
| Open bugs | 3 | 5 | down (good) |

## Next milestone
**M2 Checkout** target: 2026-03-31
Remaining:
- [ ] Inventory adjustment screen
- [ ] 3 open bug fixes
Progress: 8 of 12 complete
```

Note what did NOT appear: no LOC, no commit-count headline, no coverage row (no artifact), no author names, no repo slugs, no green-by-default. Every health cell traces to a source. The `-3,050`-line refactor became a positive outcome. "In progress" completion is tagged `(estimate)` because it is not a hard milestone date.

## Step 6: score + scrub (SKILL §7 + §9)

Quality score: skimmable (2), outcomes not dump (2), zero vanity metric (2), all cells sourced/tagged (2), zero slop (2), honest (2) = 12/12. Ship.

```bash
FILES="~/claude/notes/status-reports/pt-sinar-retail/status-report-2026-03-24.md /tmp/status-2026-03-24.html"
grep -rnP "[\x{2013}\x{2014}]" $FILES                 # V1 -> silent
grep -rnE 'sk-[A-Za-z0-9]|ghp_[A-Za-z0-9]|AKIA[A-Z0-9]|password=|token=|@s\.whatsapp\.net|(\+?62|0)8[0-9]{7,}' $FILES   # V2 -> silent
grep -rn '/home/christopher' $FILES                   # V3 -> silent
grep -rniE '\b(great progress|working hard|on track|no issues|leverag(e|ed)|utiliz(e|ed)|seamless(ly)?|very|various features)\b' $FILES   # V4
#   V4 hits "On Track" in the health cell. CHECK: it is evidence-backed (M2, 8 of 12, target Mar 31) => allowed, keep it (SKILL §9 note).
```

## Step 7: render (SKILL §8, --pdf), verified

```bash
HTML=/tmp/status-2026-03-24.html
PDF=~/claude/notes/status-reports/pt-sinar-retail/status-report-2026-03-24.pdf
# ... write HTML from references/render-pipeline.md §5 template ...
google-chrome-stable --headless --disable-gpu --no-sandbox \
  --print-to-pdf="$PDF" --no-pdf-header-footer --print-to-pdf-no-header "$HTML" 2>/tmp/c.log
chrome_exit=$?
[ "$chrome_exit" -eq 0 ] && test -s "$PDF" && pdfinfo "$PDF" | grep -q '^Pages: *[1-9]' \
  && { echo "PDF OK"; rm -f "$HTML"; } || echo "PDF FAILED, deliver the md"
```

## Step 8: land + hand off, do NOT send (SKILL §0.4, §5f)

```bash
mkdir -p ~/claude/notes/status-reports/pt-sinar-retail
# md + pdf written there. NOT sent to PT Sinar Retail. Handed to Christopher.
```

Hand-off report to Christopher, as tables (`feedback_visual_structured_docs`):

**Landed files**

| File | Path | Verified |
|---|---|---|
| Report (md) | ~/claude/notes/status-reports/pt-sinar-retail/status-report-2026-03-24.md | V1-V4 silent |
| Report (PDF) | same dir, .pdf | chrome exit 0, non-empty, 2 pages |

**Evidence gaps (tagged / omitted, for his review)**

| Cell | Handling | Why |
|---|---|---|
| Inventory screen completion date | tagged `(estimate)` | not a hard milestone date |
| Test coverage | omitted | no coverage artifact in either repo |

**Ready to send:** "The Sinar POS weekly report is at the path above (md + PDF). It is generator-only, ready for you or Suryadi to review the receipt-logo ask and send to PT Sinar Retail. I did not send it."

---

## What this trace demonstrates (the transferable moves)

1. **Client display name over repo slugs** (Sinar POS, not sinar_web/sinar_api).
2. **Guarded, multi-repo gathering**, no rev-list footgun, empty-tree fallback ready.
3. **Commits become outcomes**; a big deletion becomes a positive, LOC never shown.
4. **Every health cell sourced** (milestone baseline legitimizes "On Track", not a default green).
5. **Coverage omitted** because no artifact existed (no guessed number).
6. **The V4 "On Track" hit was checked, not blindly deleted**, because it was evidence-backed.
7. **Rendered and verified** (chrome exit + test -s + pdfinfo pages).
8. **Generator-only hand-off**, reported as tables, never sent to the client.
