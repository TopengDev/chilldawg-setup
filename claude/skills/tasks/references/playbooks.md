# Playbooks (reference)

Worked recipes per command, failure-mode recovery with exact commands, the scheduling handoff, and the data-integrity / verify-after-write flow. SKILL.md Section 5 is the summary; this is the depth. Every printed or written string here is dash-free.

Prerequisite for all recipes: `today=$(date +%F)` (verified WIB via `date +%Z`). Staleness math uses GNU `date -d` (verified available):
```bash
age_days=$(( ( $(date +%s -d "$today") - $(date +%s -d "$backtick_date") ) / 86400 ))
```

---

## 1. Command recipes

### 1.1 add (the hot path, keep it under 5s)

```
in:  /tasks add "fix cash drawer init bug in pulse"
1. today=2026-07-03
2. score (auto-file-rubric §2): pulse token +60, pulse keyword +40 = 100  -> silent band
3. tier (§4): "fix" -> NOW
4. dedup: read pulse.md, no open item matches "cash drawer init" -> proceed
5. max-5-NOW gate: count open [ ] under pulse.md "## NOW" -> under 5 -> ok
6. Edit pulse.md: insert "- [ ] fix cash drawer init bug in pulse `2026-07-03`" under "## NOW"
7. verify: re-read pulse.md, assert --- block + 5 tier headers present
8. no hard time -> no handoff
out: → pulse / NOW: fix cash drawer init bug in pulse
```

### 1.2 done (single match)

```
in:  /tasks done "cash drawer"
1. Glob *.md, grep open "- [ ]" for "cash drawer" -> 1 hit in pulse.md ## NOW
2. Edit: remove that "- [ ]" line; add "- [x] fix cash drawer init bug `2026-07-03`" under "## Completed"
3. verify-after-write; recount pulse NOW in INDEX.md if it changed
out: ✓ fix cash drawer init bug  (completed 2026-07-03, pulse)
```

### 1.3 done (multi-match, the common trap)

```
in:  /tasks done "duitku"
1. grep open items -> 2 hits: pulse.md ## NEXT "explore Midtrans/Xendit as Duitku alternative"
                                infrastructure.md ## NOW "renew Duitku sub-merchant cert"
2. do NOT auto-pick. list them:
   which one?
     1) pulse / NEXT: explore Midtrans/Xendit as Duitku alternative
     2) infrastructure / NOW: renew Duitku sub-merchant cert
3. on "1": move only that item to pulse.md ## Completed with today's date; verify.
out: ✓ explore Midtrans/Xendit as Duitku alternative  (completed 2026-07-03, pulse)
```

### 1.4 review (weekly hygiene)

```
in:  /tasks review
1. Glob *.md; for each open item compute age_days vs today.
2. flag: NOW age>7 ; NEXT age>14 ; WAITING follow-up<today ; project max-date age>14 (dormant) ; inbox non-empty
3. present grouped, offer keep/reprioritize/archive/delete per item; act with targeted Edits + verify.
4. run archive (§1.5).
5. update INDEX.md: recount tiers, set "Last updated: 2026-07-03", refresh ## This Week top 5.
out: review summary: {a} stale NOW, {b} overdue WAITING, {c} dormant projects, {d} inbox items; archived {e}.
```

### 1.5 archive (real trigger, fixes the never-fired legacy rule)

```
in:  /tasks archive   (or auto, inside review)
1. today=2026-07-03; read INDEX.md last-archived marker; explicit call always runs.
2. mkdir -p ~/.claude/tasks/archive
3. Glob *.md; for each "## Completed" [x] item with completion date > 30 days ago:
     bucket = completion month (YYYY-MM)
     append the [x] line to ~/.claude/tasks/archive/{bucket}.md (create with "# Archive {bucket}" if absent)
     remove the line from the source file (targeted Edit)
4. verify-after-write every touched source file (tier headers intact)
5. write "<!-- last-archived: 2026-07 -->" into INDEX.md
out: archived 14 completed items older than 30 days into archive/
```
Bucket by COMPLETION month, not the run month: a task finished 2026-05-15, archived in July, lands in `archive/2026-05.md`. Deterministic and retrieval-friendly ("what did I finish in May").

---

## 2. Failure-mode recovery

### 2.1 Malformed file found (would break /standup + /daily-brief)

Trigger: during any scan you find a file missing its `---` frontmatter block, or missing/misspelled a tier header, or with a stray `[x]` under a live tier.

Real example on disk (2026-07-03): `pulse.md` has a DUPLICATE `## Completed` header at the end and a `- [x]` item parked under `## NEXT` (`Static QRIS payment method support`). This is exactly the shape that confuses a tier parser.

Recovery (never silently propagate):
```
1. name the exact file + the exact defect to Christopher.
2. offer to repair to the canonical skeleton (format-contract §1):
   - collapse duplicate tier headers into one
   - move stray [x] items to ## Completed
   - restore any missing header (empty is fine)
   - preserve every task line verbatim (never drop content)
3. on yes: targeted Edits, then verify-after-write.
```
Do NOT auto-repair without a heads-up, and NEVER drop a task line during a repair. If unsure whether a line is a real task, keep it.

### 2.2 Corrupt / truncated write

The tasks dir is NOT git-tracked, there is no version safety net. Your IN-CONTEXT pre-edit Read IS the backup.
```
1. you always Read the target file before an Edit (steps in §1). that content is your restore point.
2. if a write truncated or mangled the file: re-Write the file from the pre-edit content you hold in context,
   then re-apply the intended change as a targeted Edit under the correct tier header.
3. verify-after-write: re-Read, assert --- block + all 5 tier headers.
```
This is why every write is a targeted Edit under a header, not a blind full-file rewrite: a rewrite that goes wrong loses everything; an Edit that goes wrong is bounded and recoverable from the read you just did.

### 2.3 Two-project tie on add

See `auto-file-rubric.md` §3. Specificity first (exact token beats keyword). A genuine tie (both exact tokens, equal score) goes to `inbox.md` naming both candidates. Never coin-flip, never pick first-alphabetical.

### 2.4 Inbox overflow (> 15 items)

```
1. surface at the dashboard: "Inbox: 18 unsorted (overflow, run /tasks sort)"
2. on /tasks sort: process OLDEST-first through the same §2 rubric.
3. items that still score < 40 stay in inbox with a one-line note; do not force a wrong home.
```

### 2.5 About to scan the directory broadly (the dangerous one)

If any step is about to `ls ~/.claude/tasks`, `find -type f`, or a recursive glob: STOP. Use `Glob ~/.claude/tasks/*.md` or `find ~/.claude/tasks -maxdepth 1 -name '*.md'`. The 144 harness subdirs must never be enumerated, read, or written (format-contract §4). This guard is an invariant, not a preference.

---

## 3. Scheduling handoff (a filed date does NOT fire)

A dated task is a passive list entry. Main session is reactive and never checks the clock, so a captured deadline slips silently unless a real alarm is set (verified failure 2026-05-21: an EOD promise tracked only as a task list entry was missed by 2 hours). When `/tasks add` detects a hard time (`by 5pm`, `EOD`, `tonight`, `in 30 min`, a specific clock time or date), offer the real mechanism after filing:

### 3.1 Same-day / hours out -> /remindme (WhatsApp)

```
heads up: this has a 5pm deadline. the task alone will not alert you.
want me to /remindme so it pings your WhatsApp at 17:00 WIB?
```
On yes, hand the deliverable to `/remindme` (natural language, fires as a WhatsApp DM to Toper). That is the same-day nudge layer.

### 3.2 Days or weeks out -> Google Calendar (durable)

`CronCreate durable:true` does NOT persist across a session restart (verified 2026-06-25), so it is unreliable for anything days out. Use the Google Calendar MCP, the durable layer that survives restarts and fires a native phone popup:
```
mcp__claude_ai_Google_Calendar__create_event on $TOPER_EMAIL
  timeZone: Asia/Jakarta
  a timed event at the deadline
  overrideReminders: [{"method":"popup","minutes":0}]
```
Offer it dash-free:
```
this is due Jul 18. a task line will not remind you. want a Google Calendar event
($TOPER_EMAIL, Asia/Jakarta) with a popup so your phone alerts you?
```

The task still lives in `/tasks` (the item + its `deadline:` frontmatter or backtick date), the scheduling handoff is ADDITIVE, it makes the date actually fire. Never imply the filed task will alert on its own.

---

## 4. Verify-after-write flow (every write)

Non-negotiable, because these files feed live WhatsApp briefs (Rule 9). After ANY Edit/Write to a task file:
```
1. re-Read the file.
2. assert the "---" frontmatter block opens and closes.
3. assert all five tier headers present: ## NOW, ## NEXT, ## LATER, ## WAITING, ## Completed.
4. assert the line you added/changed is present and well-formed
   (checkbox + trailing backtick date, "waiting on:" intact for WAITING).
5. if any assertion fails -> §2.2 recovery from your pre-edit read.
```
"The Edit returned success" is NOT verification (the tool confirms the string replace, not that the file still parses). The re-Read + header assertion IS.
