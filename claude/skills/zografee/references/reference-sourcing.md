# zografee reference sourcing (G1, Path B)

How to auto-source a reference board when Christopher does NOT supply his own image. This defers ALL browser mechanics to the **agent-browser skill** and supplies only the zografee-specific payloads (search URLs, extraction JS, download/vet steps).

> **STALE / HAZARD WARNING (HR-1).** `engine/source_refs.py` is verified broken and hazardous: its interior hardcodes `CDP="9222"` (the user's interactive ACTIVE-TAB port), calls `agent-browser tab new` (field-broken, exit 144, BANNED), and `close`s a live tab. Its interior predates the 2026-06-22 multi-port proxy. **Do NOT run `source_refs.py`.** Reuse only its *payloads* (the two search URLs, the CDN filters, the extraction JS) via the manual recipe below, executed on a CLAIMED port. Fixing the script in-repo is a follow-up for main, out of scope for the skill.

## The manual recipe (agent-browser `/claim` lifecycle)

Read the **agent-browser skill** for the exact `/claim`, connect, `eval`, screenshot, and `/release` command syntax, the env-file discipline, the pre-flight gate, and the failure jump table. It is the source of truth; do not duplicate it. The load-bearing facts you must honor:

- **Claim your own port from the pool - `/claim?from=9223`** (connect within the 30s TTL, set a unique `AGENT_BROWSER_SESSION`). NEVER work on **9222** (the interactive active-tab port; a bare `/claim` can allocate 9222 and hijack it). Point the tooling at your claimed port (`AGENT_BROWSER_CDP=<claimed>`).
- **NEVER `agent-browser tab new`** (HR-9, exit 144). The canonical new-surface path is `/claim?url=<url>` then connect, or navigate on the already-claimed port.
- **NEVER restart qutebrowser** (agent-browser HR-2). If its CDP (2262) is the problem, that is Mode B territory, not a restart.
- **`/release` your port when the board is sourced.**

### Step 1 - open the search on your claimed port

Precise query >> generic (a real lesson: "tech service poster" pulled noise; "tech conference poster typography" pulled real posters). Search URLs (verified from the engine):

```
dribbble:  https://dribbble.com/search/shots/popular?q=<URL-encoded query>
behance:   https://www.behance.net/search/projects?search=<URL-encoded query>
```

Dribbble is the validated backbone. **Behance's image selector is UNTESTED** (noted in project memory) - prefer Dribbble; treat a Behance run as best-effort. Navigate on your claimed port (agent-browser open/navigate), let it settle, scroll down ~600px to load more shots.

### Step 2 - extract candidate image URLs (eval on the claimed port)

Run this JS via `agent-browser eval` (it returns a JSON string of `{s:src, a:alt}` objects filtered to the site's real shot CDN). Swap the CDN literal per site:

```js
// dribbble CDN literal: dribbble.com/userupload
// behance  CDN literal: mir-s3-cdn-cf.behance.net
JSON.stringify(Array.from(document.querySelectorAll('img'))
  .map(i => ({ s: i.src || '', a: i.alt || '' }))
  .filter(x => x.s.includes('dribbble.com/userupload') && x.a.length > 3))
```

If `eval` returns nothing on a heavy page, that is the agent-browser blank/timeout path - fall back to `qb-shoot` per the agent-browser skill (PB-4 there); never restart the browser.

### Step 3 - download, size-filter, dedupe (safe, no browser)

Feed the eval'd JSON array into this standalone snippet (the only safe part of `source_refs.py`, lifted out - no browser calls). It drops anything under 8 KB (thumbnails/icons) and dedupes by URL base:

```bash
python3 - "<slug>" <<'PY'
import sys, os, json, urllib.request
slug = sys.argv[1]
outdir = os.path.expanduser(f"~/claude/Git/repositories/zografee/jobs/{slug}/refs")
os.makedirs(outdir, exist_ok=True)
items = json.load(open(f"{outdir}/_raw.json"))   # save the eval output here first
if isinstance(items, str):                        # agent-browser eval may double-encode the JSON string
    items = json.loads(items)
ua = {"User-Agent": "Mozilla/5.0"}
seen, n = set(), 0
for it in items:
    base = it["s"].split("?")[0]
    if base in seen:
        continue
    seen.add(base)
    try:
        data = urllib.request.urlopen(urllib.request.Request(base, headers=ua), timeout=40).read()
        if len(data) < 8000:            # skip thumbnails/icons
            continue
        n += 1
        open(f"{outdir}/cand-{n}.png", "wb").write(data)
        print(f"cand-{n}", "-", it["a"][:80])
    except Exception:
        continue
PY
```

### Step 4 - CURATION GATE (vet at FULL SIZE; HR-15)

Open each `cand-*.png` at full size and score pass/fail on ALL 4. Relay a candidate to the board ONLY if all pass:

1. **Single self-contained design of the target type** - REJECT branding-collateral grids, UI/mockup collages, style guides, diagrams, multi-panel showcases.
2. **Aesthetically strong.**
3. **On-brief.**
4. **Unambiguous** (one dominant design, so the gen target is clear).

Quality over filling slots: a 3-strong board beats a 5-with-2-weak board. NEVER relay raw thumbnails.

**Worked example (SAB run, verified):** of 5 scraped candidates, Christopher rejected 3 - one ugly (fail #2), one a multi-panel branding collage (fail #1 + #4, ambiguous gen target), one a not-a-poster explainer graphic (fail #1). Only 2 survived. Log the rejected ones: a whole rejected board -> a `rejection` row (HR-4), with the failed check as the `why` (negative examples are training data).

### Step 5 - present + pick + release

Present the surviving 3-5 board, run the shadow sequence (predict -> log_prediction), Christopher picks, log the `reference_pick` + `why` + `shadow.record_human_pick(...)` (see `ledger-and-judge.md`), then `/release` your claimed port.

## When sourcing keeps failing

Consult the agent-browser skill's jump table first. Common paths: daemon flaky / exit 144 -> Mode B direct WebSocket read on the qutebrowser CDP (2262); screenshot timeout on a heavy shot page -> `qb-shoot`. If sourcing is genuinely blocked, ask Christopher to drop a reference (G1 Path A) rather than shipping a weak board.
