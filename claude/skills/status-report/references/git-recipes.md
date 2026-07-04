# references/git-recipes.md: guarded gathering, multi-repo, monorepo, date baselines

Progressive-disclosure companion to `SKILL.md` §3a. The **guards are load-bearing and also live in SKILL.md**; this file carries the full per-VCS-state forms, the multi-repo loop, monorepo scoping, and the `gh` scope handling. Every command here was verified on this box on 2026-07-03 (git 2.54.0, gh 2.67.0 as account TopengDev via GH_TOKEN, GNU date 9.11).

The one invariant across everything: **never let an empty command-substitution silently mis-diff the working tree, and never invent a number when a command returns empty.** A guarded empty result is an honest "no data", not a wrong number.

---

## 1. Period baselines with `date -d` (never mental math)

```bash
UNTIL=$(date +%F)                               # or the explicit end date from $ARGUMENTS
SINCE=$(date -d "$UNTIL - 7 days" +%F)
PRIOR_UNTIL="$SINCE"
PRIOR_SINCE=$(date -d "$UNTIL - 14 days" +%F)
# verified: date -d "2026-03-24 - 14 days" +%F  ->  2026-03-10
```

For an explicit range `A to B`: `SINCE=A; UNTIL=B; PRIOR_UNTIL=A; PRIOR_SINCE=$(date -d "$A - 7 days" +%F)`.

---

## 2. The footgun and its guard (the reason this file exists)

### 2a. NEVER write this

```bash
# BANNED. If `git rev-list -1 --before="$SINCE" HEAD` prints nothing (young repo, or SINCE
# precedes the first commit), the $() collapses and the command becomes `git diff --stat HEAD`,
# which diffs the WORKING TREE against HEAD, reporting uncommitted changes as period metrics,
# with exit code 0. Silent, wrong, and it looks fine.
git diff --stat  $(git rev-list -1 --before="$SINCE" HEAD)  HEAD
git diff --shortstat $(git rev-list -1 --before="$SINCE" HEAD) HEAD
```

### 2b. The guarded replacement (capture, test, empty-tree base for a root commit)

```bash
FIRST=$(git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --format=%H --reverse | head -1)
LAST=$(git  -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --format=%H | head -1)

if [ -z "$FIRST" ]; then
  echo "NO_COMMITS"                              # honest quiet week, do not pad
else
  BASE=$(git -C "$REPO" rev-parse -q --verify "${FIRST}^" 2>/dev/null \
         || git hash-object -t tree /dev/null)   # 4b825dc642cb6eb9a060e54bf8d69288fbee4904 if root
  git -C "$REPO" diff --shortstat "$BASE" "$LAST"
fi
```

- `${FIRST}^` is the parent of the oldest commit in the window (the true "before" state).
- If the oldest commit IS the repo root it has no parent, so `rev-parse --verify` fails and we fall back to the **empty-tree SHA** `4b825dc642cb6eb9a060e54bf8d69288fbee4904` (verified: `git hash-object -t tree /dev/null`). Diffing against it yields the full initial content, which is correct for a brand-new repo's first week.

### 2c. Clean per-period line aggregation (an alternative, still footgun-free)

```bash
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --numstat --format= 2>/dev/null \
  | awk 'NF==3 && $1!="-" { add+=$1; del+=$2; files[$3]=1 }
         END { print "files_touched="length(files)" insertions="add" deletions="del }'
```

`$1=="-"` guards binary files (git prints `-` for their line counts). Remember: these numbers feed the INTERNAL activity table only; Lines Added/Removed never reach the client report (SKILL §5a).

---

## 3. Safe commit / merge / author gathering (no substitution footgun anywhere)

```bash
# commit count in period
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --oneline | wc -l

# the commits (raw material for outcome translation)
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --pretty=format:'%h %ad %s' --date=short

# merges landed (integration / "shipped" signal)
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --merges --pretty=format:'%h %s'

# who did what: INTERNAL ONLY (never in the client report, SKILL §0.2). HEAD is load-bearing:
# without an explicit rev, shortlog reads stdin in a non-interactive shell and returns EMPTY.
git -C "$REPO" shortlog -sn HEAD
```

---

## 4. Per-VCS-state handling (detached, shallow, no-commits, not-a-repo)

```bash
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "NOT_A_REPO: $REPO"; }   # ask which repo
git -C "$REPO" symbolic-ref -q HEAD >/dev/null || echo "DETACHED_HEAD"    # still fine for log by date; note it
[ "$(git -C "$REPO" rev-parse --is-shallow-repository)" = "true" ] && \
  echo "SHALLOW: history may be truncated, a period delta before the shallow boundary is unreliable, note it"
git -C "$REPO" rev-list --count HEAD    # total commits, an effort-scale signal (internal)
```

| State | Effect on the report | Handling |
|---|---|---|
| Not a repo | no git data | Ask Christopher which repo(s); do not proceed on a guess. |
| Detached HEAD | log-by-date still works | Proceed; the branch label is just absent. |
| Shallow clone | a delta reaching before the shallow boundary is wrong | Note "history truncated (shallow clone)"; report only what the available history supports. |
| No commits in period | a genuinely quiet week | Report it honestly with the reason (SKILL §10). Never pad. |
| Root commit is the window's oldest | no parent to diff | Empty-tree base (§2b). |

---

## 5. Multi-repo aggregation (an Aenoxa project often spans repos)

```bash
IFS=',' read -ra REPOS <<< "$REPOS_CSV"          # from --repos frontend,backend
for REPO in "${REPOS[@]}"; do
  REPO="${REPO/#\~/$HOME}"                        # expand a leading ~
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "skip (not a repo): $REPO"; continue; }
  label=$(basename "$REPO")
  n=$(git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --oneline | wc -l)
  echo "== $label: $n commits =="
  git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --pretty=format:'%h %s'
done
```

In the report: cluster outcomes ACROSS repos by feature (the client cares about "checkout works", not which repo it lived in), but when an activity number is per-repo, label it (`frontend: 8 PRs, backend: 5 PRs`). Aggregate totals for the health/activity tables.

---

## 6. Monorepo path scoping

When the project is one path inside a bigger repo, scope every git command with a `-- <path>` pathspec:

```bash
SCOPE="apps/pos-web"
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --oneline -- "$SCOPE" | wc -l
git -C "$REPO" log --since="$SINCE" --until="$UNTIL" --no-merges --numstat --format= -- "$SCOPE"
# the guarded diff also takes the pathspec:
git -C "$REPO" diff --shortstat "$BASE" "$LAST" -- "$SCOPE"
```

Without the scope, an unrelated package's churn pollutes the client's numbers.

---

## 7. GitHub (`gh`) with scope-aware graceful skip

`gh` is authed here as account TopengDev via `GH_TOKEN`. It can still lack scope on a specific private repo, so EVERY `gh` call is best-effort: on failure, skip and note "not tracked in GitHub", never invent.

```bash
gh auth status >/dev/null 2>&1 || { echo "gh unavailable: skip the GitHub section entirely"; }

# merged PRs in the period (delivered signal)
gh pr list --state merged --search "merged:$SINCE..$UNTIL" --limit 50 \
  --json number,title,mergedAt,labels 2>/dev/null || echo "PRs: not available"

# open PRs (in progress)
gh pr list --state open --limit 20 --json number,title,createdAt,labels,isDraft 2>/dev/null

# closed issues + open bugs (the honest open-bug count)
gh issue list --state closed --search "closed:$SINCE..$UNTIL" --limit 50 --json number,title,labels 2>/dev/null
gh issue list --state open --label bug --limit 30 --json number,title,createdAt 2>/dev/null

# CI/build reality -> the Build/deployment dashboard cell.
# GOTCHA: a run still in progress has conclusion=null. Skip nulls, take the latest COMPLETED run,
# else "Unknown" (never show a stale/blank Build cell or misread an in-progress run as a failure):
gh run list --limit 10 --json headBranch,conclusion,createdAt,name 2>/dev/null \
  | jq -r 'map(select(.conclusion!=null and .conclusion!=""))[0] // "Unknown"
           | if type=="object" then "\(.conclusion) on \(.headBranch)" else . end'
#   success -> Passing, failure/timed_out/cancelled -> Failing, "Unknown" -> Unknown (honest, §6b).
#   verified 2026-07-03: the select skips a null in-progress run and returns the latest completed one.

# the ONLY legitimate "% complete" source (SKILL §6): a real milestone
gh issue list --milestone "<milestone>" --state all --json number,state,title 2>/dev/null \
  | jq -r 'group_by(.state)[] | "\(.[0].state): \(length)"'   # closed:M open:K  ->  M of (M+K)
```

Note on `--search "merged:$SINCE..$UNTIL"`: the GitHub search range is inclusive of the day boundaries; that is fine for a weekly report. If a PR count looks off by the boundary day, prefer the explicit `>=`/`<=` search form and reconcile against the local git merge list (§3).

---

## 8. Reconciling git and gh

The local `git log --merges` list and the `gh pr list --merged` list should broadly agree. When they diverge (squash-merges show as a single commit, rebase-merges lose the merge commit), trust the `gh` PR list for the "delivered" narrative and the local `git log` for the raw activity count. Note which you used if a number is load-bearing. Never report both as if they were independent corroboration of a bigger number.
