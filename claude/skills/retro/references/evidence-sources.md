# retro evidence sources - windowed parse recipes + freshness rules

Loaded on demand by `/retro` Step 1. Every recipe here is **windowed** to the
`WINDOW_START` / `WINDOW_END` shell vars that Step 0 exports (never a bare
`"7 days ago"` / `-mtime -7`, which anchors to NOW and pulls the WRONG week on a
back-fill). All times are WIB (Asia/Jakarta). Read-only: the retro never mutates
any of these files.

```
WINDOW_START = Monday 00:00 of the target ISO week      (inclusive)
WINDOW_END   = the following Monday 00:00 (back-fill)   (exclusive)
             = now (current-week Sunday/slip run)        (exclusive)
```

Pass dates to `git` as `--since="$WINDOW_START" --until="$WINDOW_END 23:59:59"`
and to `find` as `-newermt "$WINDOW_START" ! -newermt "$WINDOW_END"`.

---

## Source priority ladder (freshness-ranked - verified 2026-07-03)

The old skill made **work-queue.md** the primary stalled-work source. On disk it
was last modified 2026-05-12 (**52 days stale**), so it silently reported weeks-old
paused dates as current. Meanwhile **result.json** is the fresh, abundant 3-tier
orchestration artifact (**201 files, 120 modified in 14d, 117 done + 3 partial**).
Reprioritized ladder:

| Rank | Source | Role | Freshness expectation |
|---|---|---|---|
| 1 (PRIMARY) | `result.json` (status filter) | Section 1 shipped (`done`) + Section 2 stalled (`blocked`/`partial`) | Always fresh, per-task mtime = the window |
| 1 (PRIMARY) | windowed `git log` | Section 1 shipped (commits) | Live, always trustworthy |
| 1 (PRIMARY) | `journal.md` | Section 1/2/3/6 narrative | Appended continuously; the richest single source |
| 2 (corrob.) | `decisions.log` | Section 3/6 decision-latency signal | Appended on each defaulted decision |
| 3 (corrob. IF fresh) | `work-queue.md` | Section 2 paused-since dates | **GUARD: skip if mtime < WINDOW_START** |
| 3 (detail) | `notes/*/report.md` | Section 1/2 prose detail | Per-task mtime |
| n/a | `~/.claude/memory/*.md` diff | Section 5 memory diffs | Per-file mtime |

**Rule:** if `result.json` + windowed git + journal disagree with a stale
work-queue, the fresh three win. work-queue is corroboration, never the sole
basis for a Section 2 row.

---

## 1. result.json - PRIMARY shipped + stalled (fresh, abundant)

Schema (validate with `~/.claude/scripts/result-schema.sh <file> --validate`,
exit 0/1): `{ task_slug, status(done|blocked|partial), summary, deliverables[],
evidence[], blockers[], followups[], staged_for_human[] }`.

```bash
# Windowed find, then classify by status
find ~/claude/notes -name result.json -newermt "$WINDOW_START" ! -newermt "$WINDOW_END" 2>/dev/null \
| while read -r f; do
    st=$(jq -r '.status // "?"' "$f" 2>/dev/null)
    sl=$(jq -r '.task_slug // "?"' "$f" 2>/dev/null)
    sm=$(jq -r '.summary // "" | .[0:70]' "$f" 2>/dev/null)
    printf '%-8s %-40s %s\n  path=%s\n' "$st" "$sl" "$sm" "$f"
  done
```

- `status:done`  -> a **Section 1 shipped** row. Evidence = the `result.json` path
  (and its `evidence[]` / `deliverables[]` entries).
- `status:blocked` / `status:partial` -> a **Section 2 stalled** row. Pull
  `blockers[]` for the "why stalled" cell; compute `days paused` from the file mtime
  or the blocker text. `staged_for_human[]` is a strong kill-vs-resume signal.
- jq present on this box (`jq-1.8.1`). If a file is unparseable, `result-schema.sh
  <file> --validate` exits non-zero; note it and move on (do not crash the retro).

## 2. windowed git log + repo prefilter (PRIMARY shipped)

95 repos carry `.git` under `~/claude/Git/repositories/`; in a typical 7-day window
only ~2-4 have commits (measured 2 this week). The old loop `git log`-ged all 95
(many inert `challenge-*` / `belajar-*` / `*-course` learning repos). **Prefilter on
HEAD mtime before the expensive `git log`:**

```bash
for r in ~/claude/Git/repositories/*/; do
  [ -d "$r/.git" ] || continue
  # cheap prefilter: skip repos whose HEAD was not touched inside the window
  find "$r/.git/HEAD" -newermt "$WINDOW_START" 2>/dev/null | grep -q . || continue
  out=$(git -C "$r" log --since="$WINDOW_START" --until="$WINDOW_END 23:59:59" \
          --pretty=format:'%ad %h %s' --date=short 2>/dev/null)
  [ -n "$out" ] && printf '\n=== %s ===\n%s\n' "$(basename "$r")" "$out"
done
```

- Each printed line is a **Section 1 shipped** evidence source; cite the short hash
  (`%h`) + repo in the Evidence cell.
- The prefilter is an optimisation only; a repo with a very old HEAD mtime but a
  fresh in-window commit is rare. If a specific repo matters and gets skipped, drop
  the prefilter line and re-run for that repo.
- `--until="$WINDOW_END 23:59:59"` makes the end-day inclusive; without the time
  suffix `git` cuts at 00:00 and drops the final day's commits.

## 3. journal.md - PRIMARY narrative (feeds every section)

`~/.claude/memory/journal.md`, append-only. Entry grammar (verified):
`- [ISO+07:00] (tag) summary`, continuation lines indented 2 spaces. Tag is exactly
one of `decision | feedback | project | reference | ephemeral`.

```bash
# In-window entries by date prefix (WINDOW_START/END are YYYY-MM-DD)
grep -nE '^- \[[0-9]{4}-[0-9]{2}-[0-9]{2}T' ~/.claude/memory/journal.md \
| awk -v a="$WINDOW_START" -v b="$WINDOW_END" '{ d=substr($2,2,10); if (d>=a && d<b) print }'
```

- `(decision)` / `(feedback)` / `(project)` tags are the week's spine -> Section 1/2/3.
- `(feedback)` entries that describe a friction Toper corrected are prime **Section 3
  bottleneck** candidates. `(ephemeral)` is low-signal; ignore for the retro.

## 4. decisions.log - corroboration (decision-latency signal)

`~/claude/state/decisions.log`, append-only. Header `# Decisions Log`; row format:
`ISO | decision-key | default-taken | reason | overridden? (y/n + when)` (5
pipe-delimited fields).

```bash
grep -nE '^\S' ~/claude/state/decisions.log | grep -v '^#' \
| awk -v a="$WINDOW_START" -v b="$WINDOW_END" -F' *\\| *' '{ d=substr($1,1,10); if (d>=a && d<b) print }'
```

- A row with `overridden: y` = a default Toper later reversed -> **strong Section 3
  bottleneck signal** (main defaulted wrong, or defaulted too eagerly).
- A **cluster of defaults on the same `decision-key`** across the week = decision
  latency on that thread -> Section 3.

## 5. work-queue.md - corroboration ONLY when fresh (STALENESS GUARD)

`~/claude/state/work-queue.md`. **Always run the freshness guard first** (Step 1
HARD RULE). Section headers (the file uses an em dash in some headers; match the
ASCII substring shown, never type the dash into a pattern):

| Section (grep substring) | Feeds |
|---|---|
| `In-flight (worker actively running)` | context only (not shipped/stalled) |
| `awaiting Toper decision` | Section 2 stalled (paused-since dates) |
| `awaiting external` | Section 2 stalled (external block) |
| `Recently shipped` | Section 1 shipped (corroboration) |
| `Backlog` | ignore |

```bash
WQ=~/claude/state/work-queue.md
WQ_MTIME=$(stat -c %Y "$WQ" 2>/dev/null || echo 0)
WS_EPOCH=$(date -d "$WINDOW_START" +%s)
if [ "$WQ_MTIME" -lt "$WS_EPOCH" ]; then
  echo "WARN work-queue.md stale (mtime $(date -d @"$WQ_MTIME" +%F) < window start $WINDOW_START) -> UNRELIABLE, using result.json+git+journal spine"
else
  grep -nA6 'awaiting Toper decision' "$WQ"   # paused-decision rows
  grep -nA6 'awaiting external'        "$WQ"   # external-block rows
  grep -nA8 'Recently shipped'         "$WQ"   # shipped corroboration
fi
```

- Skip header + separator rows and any row whose first cell is `_(none)_` / empty /
  `~~struck~~`. Truncate cells to ~60 chars.
- If stale: DO NOT quote its paused-since dates as current. The Section 2 spine
  becomes result.json (`blocked`/`partial`) + windowed git gaps + journal.

## 6. notes report.md - Section 1/2 prose detail

```bash
find ~/claude/notes -name report.md -newermt "$WINDOW_START" ! -newermt "$WINDOW_END" 2>/dev/null
```
Skim only the ones a result.json already flagged; the report is the human-readable
expansion of the machine row.

## 7. memory diff - Section 5

```bash
find ~/.claude/memory -name '*.md' -newermt "$WINDOW_START" ! -newermt "$WINDOW_END" \
  -printf '%TY-%Tm-%Td  %p\n' 2>/dev/null | sort
```
Each hit is a Section 5 row: `<file> - <one-line reason it changed>`. If a rule was
learned this week but is not yet a file here, note it and prefer `/journal` to queue
it for the memory audit (do not hand-write a memory file from inside the retro).

---

## Freshness cheat-sheet

- **Trust unconditionally:** windowed git log, journal.md, result.json (all live).
- **Trust with guard:** work-queue.md (mtime >= WINDOW_START), decisions.log (in-window rows).
- **Never trust blind:** any paused-since date from a work-queue whose mtime predates the window.
