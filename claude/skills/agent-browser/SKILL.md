---
name: agent-browser
description: Automates browser interactions for web testing, form filling, screenshots, and data extraction. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages.
metadata:
  filePattern: "**/cdp*,**/browser*,**/proxy*"
  bashPattern: "agent-browser|curl.*localhost:(9222|2262)"
---

# Browser Automation with agent-browser v0.22.3 — qutebrowser CDP proxy stack

This is **Christopher's LIVE production browser** (authenticated sessions, load-bearing for
fitest/bcas). Treat every action as production. Read §1 HARD RULES before driving anything.

## 0. FAILING NOW? — jump table

| Symptom right now | Go to |
|---|---|
| `curl localhost:9222` fails / connection refused | **PB-1** proxy down |
| doctor.log FAIL-loop / proxy.log `Cannot connect to host 127.0.0.1:2262` | **PB-2** qutebrowser CDP down (proxy is innocent) |
| Fresh tabs stuck as `about:blank` 640x480 targets, `Page.navigate` times out | **§10.0 wedge ladder** — check the SERVER first, then PB-2 |
| Every command hangs ~25s then errors | **PB-3** daemon wedged / stale pin (25s = the default action timeout, not a mystery) |
| Screenshot comes back blank or black | **PB-4** blank-shot ladder (retry → qb-shoot) |
| `--full` screenshot oversized, content pinned top-left | **PB-5** HiDPI DPR defect (trim recipe) |
| Driving the wrong tab / eval returns `about:blank` | **PB-6** stale/phantom pin |
| Snapshot shows the OLD page after a click / route change | **PB-7** SPA race |
| `ERR_CERT_COMMON_NAME_INVALID` on `agent-browser open <https-url>` | **PB-8** cert error → `/claim?url=` |
| Multiple independent clients ALL wedge on the SAME origin | **§10.0 wedge ladder step 1** — `top`, dev server pegged? |
| `tab new` exited 144 | Expected in this env — use `/claim?url=` (HR-9, R-1) |
| Screenshots dark but the page displays light | **§9.4** color-scheme drift → `AGENT_BROWSER_COLOR_SCHEME=light` |
| No free ports / `503 No free ports` from /claim | Someone leaked claims — `curl :9222/sessions`, then `/release?port=N` ONLY provably dead entries (`connections` 0 AND `idle_secs` near/over 600 — §6.3) |
| Playwright tool call denied by hook | Correct behavior. Pivot HERE immediately (HR-1). |

## 1. HARD RULES (NEVER / ALWAYS — memorize before first command)

- **HR-1 — NEVER use Playwright MCP / Chrome as the browser.** Hook-enforced ban
  (`~/.claude/settings.json` PreToolUse denies every `mcp__plugin_playwright_playwright__browser_*`
  call). If a Playwright call is denied, the hook fired correctly — do NOT look for workarounds,
  pivot to this skill. Headless `google-chrome-stable` is permitted ONLY as the last rung of
  PB-9, never as a general alternative.
- **HR-2 — NEVER restart, kill, or `:restart` qutebrowser.** It is Christopher's live browser.
  Agents may restart ONLY the proxy (`qb_proxy.py`). If qutebrowser's own CDP (2262) is dead or
  degraded, STOP and escalate to Christopher — a qutebrowser `:restart` is human-gated (PB-2).
- **HR-3 — NEVER hand-copy a tab id from any display.** Proxy logs truncate ids to 16 chars;
  ad-hoc listers truncate; terminals wrap. Real CDP ids are exactly **32 hex chars**. For Mode B,
  ALWAYS extract the exact `webSocketDebuggerUrl` field from `/json/list` programmatically and
  use it verbatim. *Why: 2026-07-02 — a truncated id pinned a phantom target that silently
  evaluated `about:blank` for an hour.*
- **HR-4 — ALWAYS verify a pin landed.** After any `/target?id=` or `/target?url=` pin,
  `curl http://localhost:<PORT>/target` on the SAME port and confirm `title`/`url` match the
  intended tab. `?id=` does NOT validate the id — a wrong id "succeeds" then drives a phantom.
- **HR-5 — ALWAYS pin and drive on the SAME port.** `/target` is per-port scoped (the response
  even carries a `port` field). A pin set on 9223 does nothing for a daemon connected to 9222.
- **HR-6 — ALWAYS run the §12 teardown checklist when a session ends** (`agent-browser close`;
  `/release?port=N` for claimed ports; `/target?clear` for manual pins). The 600s reaper is a
  backstop, never the plan — a leaked claim parks a zombie tab in Christopher's browser.
- **HR-7 — NEVER let fleet/parallel workers share port 9222.** Every parallel or
  non-interactive session MUST `/claim?from=9223` its own port (9222 stays the
  interactive/legacy active-tab port — bare `/claim` CAN allocate 9222 itself and silently
  hijack it) AND set a unique `AGENT_BROWSER_SESSION` (without it the shared default daemon
  re-clobbers the tab regardless of the proxy).
- **HR-8 — ALWAYS connect within the /claim reservation TTL (default 30s):**
  `export AGENT_BROWSER_CDP=$PORT && agent-browser connect $PORT` immediately after claiming,
  or the reservation lapses and another caller can take the port.
- **HR-9 — NEVER navigate with `agent-browser tab new` as the primary path.** Field-verified
  failing (exit 144) in this environment (atlas smoke test, 2026-06). Canonical new-surface
  path: `/claim?url=<url>` → connect → work (R-1). If you do try `tab new`, check its exit code.
- **HR-10 — NEVER treat `@eN` refs as stable.** They invalidate on ANY DOM mutation (two
  verified field failures, atlas smoke test). Snapshot-then-act in the same logical step,
  re-snapshot before each interaction, or use `find role|text|label` semantic locators.
- **HR-11 — ALWAYS wait after SPA navigation before snapshot/screenshot:**
  `agent-browser wait --load networkidle` (fallback `wait 2000`). Never snapshot immediately
  after a client-side route change; all pre-nav `@eN` refs are dead.
- **HR-12 — NEVER blanket-trim screenshots.** Apply the ImageMagick content-bbox trim ONLY to
  `--full` outputs exhibiting the DPR defect (canvas ~1.667x oversized, content top-left). A
  legitimately small-content state (centered modal) must not be cropped.
- **HR-13 — ALWAYS check the SERVER before blaming the browser.** When multiple independent
  clients wedge on the same origin (`Page.navigate` timeouts, `about:blank` tabs, blank
  qb-shoot), run `top` and inspect the dev-server process FIRST. QA against a static build
  (`pnpm build` + `python3 -m http.server` on `out/`), not `next dev`. *Why: 2026-07-02 — an
  hour lost chasing "wedged renderers" while `next dev` sat pegged at 115% CPU.*
- **HR-14 — NEVER promote `qb_proxy.py.new` over the live `qb_proxy.py`.** The `.new` file
  (2026-05-30) is **OBSOLETE** — it predates the live tab-isolation revision (2026-06-22).
  Retained as history only (`references/upgrade-history.md`).
- **HR-15 — NEVER print or persist secrets via the browser.** No `auth save` of real
  credentials without explicit instruction, no screenshots of token/key pages into shared
  /tmp, no cookie dumps in reports. Report "found credential at <file>, pattern <type>" only.
- **HR-16 — ALWAYS pin the color scheme explicitly for screenshot work**
  (`export AGENT_BROWSER_COLOR_SCHEME=...` in the session env file): `light` unless the task
  is dark-theme QA, in which case set `dark` deliberately and invert/skip the §9.1
  light-page brightness threshold. CDP color-scheme can default to dark after a browser
  restart while qutebrowser displays light — un-pinned batches come out wrong-theme (§9.4).
- **HR-17 — ALWAYS restart the proxy the canonical way** (proxy ONLY, never qutebrowser):
  anchored `pkill -f '/qb_proxy\.py($|[[:space:]])'`, then
  `setsid python3 ~/.config/qutebrowser/scripts/qb_proxy.py >> ~/.cache/qb_proxy/proxy.log 2>&1 &`.
  Never log to /dev/null (kills post-mortem diagnostics), never unanchored pkill (the bare
  pattern substring-matches the `.new`/`.bak` sibling files).

## 2. Architecture — LIVE multi-port tab-isolation proxy

**As of 2026-06-22 the LIVE proxy is multi-port with per-port TAB ISOLATION.** Any doc that
says "multi-port is staged / not yet live" is stale (atlas §12.1's copy was corrected 2026-07-02). Verified live:
all 15 ports listening, `/sessions` answering, header comment "LIVE: multi-port CDP proxy
with per-port TAB ISOLATION".

```
agent-browser (Rust CLI, per-session daemon)
      │  AGENT_BROWSER_CDP=<port>  (or --cdp <port>)
      ▼
qb_proxy.py — 15 ports on 127.0.0.1:9222-9236          ~/.config/qutebrowser/scripts/qb_proxy.py
      │  · spoofs Browser "Chrome/134.0.0.0" on /json/version (so agent-browser accepts it)
      │  · mocks unsupported Target.* methods (createTarget opens via qutebrowser CLI)
      │  · per-port /target pins · /claim /release /free /sessions on EVERY port
      │  · filters companion-panel (port 7700) targets from all lists
      │  · rewrites webSocketDebuggerUrl to the arriving port
      ▼
qutebrowser real CDP — 127.0.0.1:2262 (QtWebEngine 6.11, qutebrowser v3.7.0)
      = Christopher's LIVE authenticated browser. Mode B talks here directly.
```

### 2.1 Port map

| Port | Role | Rules |
|---|---|---|
| **9222** | Legacy/interactive **active-tab** port. Unpinned default target = the tab the user is looking at (pages[0] after companion filtering). fitest/bcas legacy flows depend on this. | Single interactive tasks only. Fleet claims MUST skip it (`?from=9223`) — bare `/claim` can allocate 9222 and hijack it (HR-7). |
| **9223-9236** | Claimable pool. `/claim` gives each port a DEDICATED background tab (true parallel isolation, zero cross-clobber). | Claim → connect ≤30s → work → `/release` (§6). |
| **2262** | qutebrowser's real CDP. Full 32-char ids + real `webSocketDebuggerUrl` in `/json/list`. | Mode B reads/drives here directly. NEVER restart qutebrowser (HR-2). |
| **7700** | elsummariz00r companion panel. | Filtered out of every target list — you will never see it; don't go looking. |

### 2.2 Timing constants (memorize — these explain most "mystery hangs")

| Constant | Value | Where it bites |
|---|---|---|
| `/claim` reservation TTL | **30s** default (`?ttl=N`) | connect within it or the reservation lapses (HR-8) |
| Owned-tab reaper grace | **600s** idle | un-`/release`d dedicated tab gets GC'd; long pauses between commands are safe, dead workers leak a tab for 10 min |
| Reaper loop cadence | every **30s** | granularity of pin auto-clear + GC |
| WS heartbeat | **15s** ping | dead daemon connections detected/cut |
| agent-browser action timeout | **25000ms** (`AGENT_BROWSER_DEFAULT_TIMEOUT`) | "hangs ~25s then errors" = timeout firing, not a random wedge (PB-3) |
| Dedicated-tab create poll | ~8s (`/claim`), up to 10s (`Target.createTarget` mock) | slow tab commit under load → `"warning": "tab-create-failed"` |
| Doctor watchdog | every **2 min**, 3x2s re-check | how fast a dead proxy self-heals (PB-1) |

## 3. PRE-FLIGHT GATE (mandatory, 3 commands, ~2s, before ANY browser work)

```bash
# Gate 1 — proxy up + spoof working: must print Chrome/134.0.0.0
curl -s -m3 http://localhost:9222/json/version | python3 -c "import sys,json; print(json.load(sys.stdin)['Browser'])"
# Gate 2 — qutebrowser CDP alive: must return a JSON array
curl -s -m3 http://localhost:2262/json/list | python3 -c "import sys,json; print(len(json.load(sys.stdin)), 'targets')"
# Gate 3 — no unexpected stale pin on the port you'll use
curl -s http://localhost:9222/target
```

Gate 1 fails → **PB-1**. Gate 2 fails → **PB-2** (STOP, human-gated). Gate 3 shows a pin you
didn't set → **PB-6**. Any gate fails → do NOT start driving; jump to the playbook.

## 4. Session-mode decision table (hard triggers)

| Situation | Mode / port | Why |
|---|---|---|
| Interactive single task on the user's current tab | **Mode A on 9222**, no claim | active-tab default; zero setup |
| ANY parallel / fleet / long-running / multi-tab work | **Mode A on a claimed port** — `/claim?from=9223` + unique `AGENT_BROWSER_SESSION` (R-1) | dedicated tab, zero cross-clobber (HR-7) |
| Bot-protected site, READ only (X, Google, LinkedIn, CoinGecko, DeFiLlama, block explorers) | **Mode B** — direct ws to the user's authenticated tab via exact `webSocketDebuggerUrl` (R-2) | user's cookies + real browser fingerprint; no daemon startup |
| Bot-protected site, INTERACTION needed | `/claim?url=<url>` then **Mode A on that claimed port** | the claimed tab lives in the same qutebrowser profile → still authenticated; refs make interaction reliable |
| Quick one-shot text extraction from any open tab | **Mode B** (R-2) | fastest; no daemon |
| Open a NEW page/tab | `/claim?url=` (R-1) — NEVER `tab new` primary (HR-9) | tab-new exit-144; claim path is TLS-safe |
| Heavy-page screenshot after a blank/black CDP result | **qb-shoot fallback ladder** (PB-4) | native Qt render path |
| Everything CDP-side wedged, need viewport-emulated evidence NOW | **PB-9** headless-chrome (last resort, only allowed exception to HR-1) | qutebrowser CDP degraded + human unavailable |

Bot-protection works in BOTH B and claimed-A because the page loads inside the real
qutebrowser with the user's cookies and fingerprint — agent-browser/CDP only drives it; the
site never sees an automation browser.

## 5. Mode A — agent-browser via proxy (the workhorse)

Always prefix with the port (env or flag — `AGENT_BROWSER_CDP` is honored by the binary even
though it is absent from `--help`; `--cdp <port>` is the flag equivalent):

```bash
export AGENT_BROWSER_CDP=9222     # or a claimed port; persist in the session env file (§6.3)
```

### 5.1 Task-oriented core (full verified surface: references/cli-reference.md)

```bash
# Snapshot — accessibility tree with interactive element refs (THE key feature)
agent-browser snapshot -i -c --json     # -i interactive-only, -c compact — best for most tasks
agent-browser snapshot -d 3             # limit depth
agent-browser snapshot -s "#main"       # scope to CSS selector

# Read page info
agent-browser get url --json
agent-browser get title --json
agent-browser get text @e1 --json       # text of a specific element
agent-browser get html @e1              # innerHTML
agent-browser get value @e2             # input value
agent-browser get attr @e1 "href"
agent-browser get count "a"             # count matching elements
agent-browser get box @e1               # bounding box

# Interact (fill = clear-then-type; type = APPEND without clearing — see do/don't §13)
agent-browser click @e2
agent-browser fill @e3 "search query"
agent-browser type @e3 "appended text"
agent-browser hover @e1
agent-browser focus @e4
agent-browser press Enter
agent-browser select @e5 "option-value"
agent-browser check @e6                 # (uncheck @e6 to untick)

# Navigate
agent-browser open <url>                # navigates the CURRENT target tab
agent-browser back                      # also: forward, reload

# Scroll
agent-browser scroll down 500
agent-browser scrollintoview @e5

# Wait (MANDATORY after SPA navigation — HR-11)
agent-browser wait --load networkidle
agent-browser wait @e1                  # wait for element visible
agent-browser wait --text "Welcome"
agent-browser wait 2000                 # ms fallback

# Execute JS
agent-browser eval "document.title"

# State checks
agent-browser is visible @e1            # also: is enabled @e2, is checked @e3

# Semantic locators — the ref-churn-proof alternative (HR-10)
agent-browser find role button click --name "Submit"
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "test@test.com"

# Screenshots (QA gate in §9 applies to EVERY shot)
agent-browser screenshot /path/page.png
agent-browser screenshot --full /path/full.png    # DPR defect risk — §9.2 / PB-5
agent-browser screenshot --annotate               # numbered labels for vision models

# Console & errors & network (QA evidence bundle — R-5)
agent-browser console
agent-browser errors
agent-browser network requests --filter api --type xhr,fetch

# Clipboard
agent-browser clipboard read            # also: clipboard write "text"

# Diff
agent-browser diff snapshot                          # current vs last
agent-browser diff screenshot --baseline before.png  # visual diff

# Batch — multiple commands, one daemon round-trip (R-4)
echo '[["snapshot","-i"],["click","@e2"],["screenshot","/path/after.png"]]' | agent-browser batch --json

# Tabs — list/switch OK; `tab new` is HR-9-banned as primary
agent-browser tab            # list
agent-browser tab 2          # switch
agent-browser tab close 3

# Close daemon when done (part of teardown §12)
agent-browser close
```

### 5.2 Snapshot semantics + the ref-volatility rule

Snapshot returns a structured accessibility tree with refs for every interactive element:

```
- button "Log In" [ref=e4]
- combobox "Search" [ref=e9]
- tab "Details" [selected, ref=e19]
- link "Documentation" [ref=e86]
- textbox "Email" [ref=e123]
```

**`@eN` refs are VOLATILE, not stable** (HR-10). They invalidate on ANY DOM mutation — a
click that opens a dropdown, a fetch that re-renders a list, a route change. Discipline
(pick ONE per interaction):
1. **Snapshot-then-act in the same logical step** — no DOM change between snapshot and action.
2. **Re-snapshot before each interaction** on churny pages.
3. **Prefer semantic locators** (`find role|text|label ...`) — they re-resolve at action time.

Never carry an `@eN` ref across a click that mutated the DOM. *Verified failure: two
stale-ref failures in the atlas smoke test.*

**Radix/React-Select gotcha (field-verified):** Radix comboboxes often don't open via `@eN`
click or JS (the `role=combobox` element isn't the click target). They DO open via keyboard:
`agent-browser focus @ref` then `agent-browser press Enter`. Radix TAB lists, by contrast,
click fine via their tab refs.

### 5.3 Daemon lifecycle

- The daemon persists between commands — **chain with `&&`**, don't `close` between steps:
  `agent-browser open <url> && agent-browser wait --load networkidle && agent-browser snapshot -i`
- `agent-browser close` kills the daemon; the next command cold-starts it (~seconds). Use
  `close` only for teardown or to force re-attach after a pin change (§6.2).
- One target at a time: the daemon operates on whatever the proxy returns via
  `Target.getTargets` for its port. Changing tabs = change the pin, then `close` + reconnect.

## 6. Tab targeting & the /claim lifecycle

### 6.1 Discover tabs (real CDP, full ids)

```bash
curl -s http://localhost:2262/json/list | python3 -c "
import sys, json
for t in json.load(sys.stdin):
    if t.get('type') == 'page':
        print(t['id'], '|', t['title'][:60], '|', t['url'][:80])"
```

Index 0 = the tab the user is currently looking at (after companion filtering). Ids are
**32 hex chars** — if what you're holding is shorter, it's truncated (HR-3).

### 6.2 Manual /target pins (per-port — HR-5)

```bash
curl -s "http://localhost:9222/target?url=github.com"   # pin first tab whose URL contains substring (404 if none)
curl -s "http://localhost:9222/target?id=<FULL_32CHAR_ID>"  # pin by exact id — NOT validated, HR-4 verify!
curl -s "http://localhost:9222/target"                  # show current target {target,title,url,port}
curl -s "http://localhost:9222/target?clear"            # revert to active tab
```

**Workflow:** pin → **verify** (`/target` shows your title/url — HR-4) → `agent-browser close`
(so the daemon re-attaches to the new target) → work → `agent-browser close` →
`/target?clear`.

**Pin lifecycle (differs by port type):**
- **Manual pin on a non-owned port** (e.g. 9222): AUTO-CLEARS when the last WS connection on
  that port drops. Stale-pin risk is a daemon that reconnects while an old pin lingers.
- **Owned pin from /claim**: PERSISTS across daemon disconnect/reconnect by design (a fleet
  runs many agent-browser commands per claim). It ends only via `/release` or the 600s reaper.

### 6.3 /claim → connect → work → /release (canonical for anything parallel or new-tab)

```bash
# 1. Claim a port with your start URL (from=9223 leaves 9222 alone — HR-7).
#    Use -G --data-urlencode when the URL has its own query params.
CLAIM=$(curl -s -G "http://localhost:9222/claim" \
        --data-urlencode "from=9223" \
        --data-urlencode "url=https://app.example.com/search?q=beta&scope=all")
PORT=$(echo "$CLAIM" | python3 -c "import sys,json; print(json.load(sys.stdin)['port'])")
TAB=$(echo "$CLAIM"  | python3 -c "import sys,json; print(json.load(sys.stdin).get('tab') or '')")
[ -n "$TAB" ] || echo "WARNING: tab-create-failed — port NOT isolated (active-tab fallback)"

# 2. Persist session env NOW (shell env does NOT survive between tool calls)
TASK_DIR=${TASK_DIR:-<your task notes dir or the session scratchpad>}   # set it if you're outside the 3-tier task-dir convention
cat > "$TASK_DIR/browser.env" <<EOF
export AGENT_BROWSER_CDP=$PORT
export AGENT_BROWSER_SESSION=worker-$PORT-$$
export AGENT_BROWSER_COLOR_SCHEME=light   # HR-16: light unless the task is dark-theme QA
EOF
source "$TASK_DIR/browser.env"

# 3. Connect WITHIN 30s of the claim (HR-8)
agent-browser connect $PORT

# 4. Verify the pin landed on YOUR dedicated tab (HR-4/HR-5 — same port!)
curl -s "http://localhost:$PORT/target"    # title/url must be your start URL

# 5. Work. EVERY subsequent tool call starts with: source "$TASK_DIR/browser.env"

# 6. Teardown (§12): agent-browser close; curl -s "http://localhost:9222/release?port=$PORT"
```

`/claim` options: `?url=<url>` (dedicated tab opens directly there — TLS-safe, opened by the
qutebrowser CLI), `?ttl=N` (reservation seconds, default 30), `?from=N` (start of port scan),
`?notab=1` (legacy: port only, no dedicated tab — caller pins manually or uses active-tab
fallback). Returns `{"port":N,"ttl":T,"tab":"<id>"}`; on tab-create failure the port is still
returned with `"warning":"tab-create-failed"` — **check for it**: an unwarned claim is
isolated, a warned one is NOT. Exhausted pool → HTTP 503 `{"error":"No free ports"}`.

`/release?port=N` (or bare `/release` from the arriving port) closes the owned tab
(`Target.closeTarget`, id-scoped — the proxy can only ever close tabs it created) and clears
all port state. Idempotent. Verify: response shows `released_tab`/`closed`, and
`curl -s http://localhost:9222/sessions` no longer lists your port under `active`.

`/free` exists but is a **non-reserving, racy probe** (two parallel callers can get the same
port). Never use it for allocation — `/claim` only.

`/sessions` = fleet visibility: `{"ports":"9222-9236","active":{<port>:{target,connections,
dedicated_tab,idle_secs,title,url}}}`. Check it before claiming (see who's live) and after
releasing (verify you're gone).

**Releasing someone ELSE's port (the "No free ports" cleanup):** `/release` closes that
port's dedicated tab — release a live-but-momentarily-idle fleet worker's port and you
destroy its session mid-task (long pauses between commands are NORMAL; that is exactly why
the owned-tab grace is 600s). Treat a `/sessions` entry as dead ONLY when `connections` is 0
AND `idle_secs` is approaching/exceeding 600 (or you positively know the owning worker is
gone). NEVER `/release` a port that shows live connections.

### 6.4 The ENV-FILE discipline (multi-step sessions)

Shell env does NOT persist between tool calls. Persist `AGENT_BROWSER_CDP`,
`AGENT_BROWSER_SESSION`, `AGENT_BROWSER_COLOR_SCHEME` to a small env file at session start
(§6.3 step 2) and `source` it in EVERY subsequent call. A worker whose commands mysteriously
hit the wrong tab / wrong theme has almost always lost its env.

## 7. Mode B — direct WebSocket to 2262 (bot-protected reads, quick extraction)

Bypasses agent-browser entirely; talks CDP straight to the user's authenticated tab.
`websockets` 16.0 + `aiohttp` are installed. **HR-3 applies with full force: take the
`webSocketDebuggerUrl` field verbatim — never string-build a ws URL from a hand-copied id.**

```bash
# 1. Select the tab programmatically and extract its EXACT webSocketDebuggerUrl
WS_URL=$(curl -s http://localhost:2262/json/list | python3 -c "
import sys, json
tabs = [t for t in json.load(sys.stdin) if t.get('type') == 'page']
tab = next((t for t in tabs if 'x.com' in t.get('url','')), tabs[0])  # match by URL, else active tab
print(tab['webSocketDebuggerUrl'])")

# 2a. Read page text — loop recv until the response id matches (CDP events interleave on busy pages)
python3 - "$WS_URL" <<'PY'
import asyncio, websockets, json, sys
async def run():
    async with websockets.connect(sys.argv[1], max_size=20*1024*1024) as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Runtime.evaluate',
            'params': {'expression': 'document.body.innerText', 'returnByValue': True}}))
        while True:
            res = json.loads(await ws.recv())
            if res.get('id') == 1:
                print(res.get('result', {}).get('result', {}).get('value', ''))
                break
asyncio.run(run())
PY

# 2b. Navigate the tab
python3 - "$WS_URL" <<'PY'
import asyncio, websockets, json, sys
async def run():
    async with websockets.connect(sys.argv[1]) as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Page.navigate',
            'params': {'url': 'https://example.com'}}))
        while True:
            res = json.loads(await ws.recv())
            if res.get('id') == 1:
                print(res)
                break
asyncio.run(run())
PY

# 2c. Extract links
python3 - "$WS_URL" <<'PY'
import asyncio, websockets, json, sys
async def run():
    js = ('JSON.stringify(Array.from(document.querySelectorAll("a")).slice(0,20)'
          '.map(a=>({text:a.innerText.trim().substring(0,50),href:a.href})))')
    async with websockets.connect(sys.argv[1], max_size=20*1024*1024) as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Runtime.evaluate',
            'params': {'expression': js, 'returnByValue': True}}))
        while True:
            res = json.loads(await ws.recv())
            if res.get('id') == 1:
                for l in json.loads(res.get('result',{}).get('result',{}).get('value','[]')):
                    if l['text']: print(f"{l['text']} -> {l['href']}")
                break
asyncio.run(run())
PY
```

Mode B constraints: no snapshot/refs (raw JS only), no daemon conveniences, and a
`Page.navigate` that never resolves is a wedge symptom → §10.0 ladder. For interaction on a
bot-protected site, switch to `/claim?url=` + Mode A (§4).

## 8. Bot-protected-site protocol

1. **READ-only** (X, Google, LinkedIn, CoinGecko, DeFiLlama, block explorers): Mode B against
   the user's already-authenticated tab (R-2). The site sees the real browser, real cookies,
   real fingerprint. Do NOT navigate the user's tab away from where they left it without
   restoring it (note the URL first; restore via `Page.navigate` when done).
2. **INTERACTION needed**: `/claim?url=<target>` → Mode A on the claimed port. The dedicated
   tab shares the qutebrowser profile → already logged in, still bot-proof.
3. **NEVER** `agent-browser open` a bot-protected site through an independent/fresh browser
   context — that's exactly the automation fingerprint these sites flag.
4. Respect the standing rule: reuse the running qutebrowser, no duplicate tabs of the same
   target (check `/json/list` for an existing tab before claiming a new one).

## 9. Screenshots — QA gates, DPR defect, qb-shoot ladder

### 9.1 SCREENSHOT QA GATE (quantified — applies to EVERY batch; never silently keep a failed shot)

| Check | How | Threshold / action |
|---|---|---|
| (a) DPR | `--full` canvas ~1.667x the size of a viewport shot of the same page, content top-left | → PB-5 trim recipe |
| (b) Brightness | `convert <f> -background white -flatten -colorspace Gray -format '%[fx:mean]' info:` | light page expected ≥ ~0.6 (typical ≈0.95; dark frame ≈0.10). Under 0.6 on a light theme → §9.4, re-shoot |
| (c) Blank | near-uniform frame (mean ≈1.0 or ≈0.0) on a page that has content | → retry once after 2-3s, then qb-shoot (PB-4) |

Downscaled inline previews are unreliable for judging brightness (a dark page with white
form fields looks light when shrunk) — trust `fx:mean`, not your eyes on a thumbnail.

### 9.2 `--full` DPR double-scale defect (HiDPI fractional scaling — verified 2026-06-24)

On this box (166.7% scaling, device-scale-factor 5/3) `screenshot --full` sizes the canvas
at `page_size x 1.667` but rasterizes at 1x → content pinned top-left of an oversized blank
canvas (e.g. 4800x2928 holding 2635x1757 — exactly 1/DPR on each axis). agent-browser is a
third-party Rust crate — NEVER patch the binary. Recovery (content is rendered correctly,
just in an oversized canvas):

```bash
convert in.png -bordercolor white -border 1 -trim +repage out.png
# 1px white border makes -trim robust when content touches an edge.
```

Pillow alternative + detection heuristics: `references/cli-reference.md` §screenshots.
Apply ONLY to `--full` outputs (HR-12). Optional UNVERIFIED prevention:
`agent-browser set viewport <W> <H> 1` before the shot — the trim is the guarantee
regardless. A rarer qb-shoot variant (NON-maximized window → content top-RIGHT at ~62%,
window-geometry cause not DPR) is fixed by the same trim.

### 9.3 qb-shoot — native Qt fallback for heavy pages

CDP screenshots hit a compositor cliff on heavy pages — **triggers: backdrop-filter,
mask-image, mix-blend-mode, SVG feTurbulence, multi-MB background PNGs** (e.g. fitest's UI)
— and come back blank/black. Fallback (NOT on PATH — always use the full path):

```bash
~/.config/qutebrowser/scripts/qb-shoot <url-slug> <output.png>
# e.g. ~/.config/qutebrowser/scripts/qb-shoot test-suites/702 /tmp/suite.png
```

Mechanism: qb IPC socket (`$XDG_RUNTIME_DIR/qutebrowser/ipc-*`) → `:tab-select <slug>` →
`:screenshot --force <out>` → restores the previous tab BY URL. Dependencies + edge cases:
- Requires the IPC socket to exist and the **focus-theft suppression patch** in `config.py`
  (~line 305, qb upstream issue #5094) — present; without it every IPC command raises qb to
  the foreground.
- Restore-by-URL can mis-restore when multiple tabs share a URL.
- It briefly switches the visible tab (~2s) — acceptable, but don't run it in a tight loop
  while Christopher is actively using the browser.
- Hardcodes IPC payload version "3.6.3" vs running qb v3.7.0 — works because
  `protocol_version: 1` is what matters; flag if qb ever bumps the IPC protocol.

### 9.4 Color-scheme drift (dark screenshots of a light page — field-verified)

After a browser restart, CDP color-scheme can default to DARK while qutebrowser displays
light. Fix: pin it — `export AGENT_BROWSER_COLOR_SCHEME=light` persisted in the env file
(HR-16; for deliberate dark-theme QA pin `dark` instead and invert/skip the §9.1
light-page threshold).
`agent-browser set media light` exists in v0.22.3 but the env var is the field-verified
reliable path. Audit every batch with the §9.1 brightness gate.

## 10. FAILURE-MODE PLAYBOOKS

### 10.0 WEDGE TRIAGE LADDER (ordered — first hit wins; do NOT skip step 1)

1. **`top`** — is the target's dev server pegged (>100% CPU)? → fix/kill the server; QA
   against a static build. A pegged `next dev` makes EVERY client look wedged (HR-13).
2. **`curl -s -m3 http://localhost:2262/json/list`** direct — dead? → qutebrowser CDP down
   → **PB-2** (human-gated; the doctor FAIL-loop you may see is expected noise).
3. **`curl -s -m3 http://localhost:9222/json/version`** — dead while 2262 alive? → **PB-1**
   restart proxy.
4. Daemon level → **PB-3** (`agent-browser close` + verify pin + reconnect).
5. Still blank on screenshots only → **PB-4** qb-shoot.
6. Still stuck AND you need viewport-emulated evidence now → **PB-9** headless-chrome.

### PB-1 — Proxy down (9222 dead, 2262 alive)

Symptom: gate-1 curl fails; gate-2 passes.
```bash
tail -5 ~/.cache/qb_proxy/doctor.log     # doctor runs every 2 min — it may have fixed it already
# Not fixed? Canonical restart (HR-17 — proxy ONLY, never qutebrowser):
pkill -f '/qb_proxy\.py($|[[:space:]])'; sleep 1
setsid python3 ~/.config/qutebrowser/scripts/qb_proxy.py >> ~/.cache/qb_proxy/proxy.log 2>&1 &
sleep 2
# Verify: re-run the §3 pre-flight gate. Expect "Proxy started on 15 ports" in proxy.log.
```
Note: config.py auto-starts the proxy only at qutebrowser LAUNCH — a mid-session proxy death
needs the doctor or this manual restart.

### PB-2 — qutebrowser CDP down/degraded (2262 dead, or tabs never commit)

**Signature** (live-observed 2026-07-02 18:32-18:51): doctor.log repeats
`DRIFT: port 9222 down ... restarting proxy` → `FAIL: proxy still down after restart attempt`
every 2 min, while proxy.log shows the proxy binding all 15 ports fine but
`Cannot connect to host 127.0.0.1:2262`. **The doctor health-checks only 9222/json/version,
which the proxy forwards to 2262 — so when qutebrowser's CDP dies, the doctor endlessly
kill/restarts a HEALTHY proxy.** "FAIL: proxy still down" ≠ proxy broken.

Degraded variant: 2262 answers, but fresh tabs stay 640x480 `about:blank` uncommitted
targets and `Page.navigate` wedges — can persist even AFTER a pegged server recovered.

**Recovery: NONE self-service.** STOP. Report to Christopher that qutebrowser needs a
`:restart` (heals its CDP). Do NOT fight the proxy, do NOT restart qutebrowser yourself
(HR-2). If evidence is needed meanwhile → PB-9.

### PB-3 — Daemon wedged / every command hangs ~25s then times out

25s = `AGENT_BROWSER_DEFAULT_TIMEOUT` firing — the daemon is waiting on a dead/wrong target.
```bash
agent-browser close
curl -s "http://localhost:$AGENT_BROWSER_CDP/target"   # pin still points at a LIVE tab?
curl -s http://localhost:2262/json/list | grep -c "<pinned-id>"   # tab ids CHANGE when tabs close/reopen
# Stale pin → clear (or /release for owned) → re-pin with the FULL 32-char id → reconnect:
agent-browser connect $AGENT_BROWSER_CDP && agent-browser get url
```

### PB-4 — Blank/black screenshot

```bash
# 1. Retry once after 2-3s (transient compositor load — common under concurrent fleets)
sleep 3 && agent-browser screenshot /path/retry.png
# 2. Still blank → native Qt path (full path — qb-shoot is NOT on PATH):
~/.config/qutebrowser/scripts/qb-shoot <url-slug> /path/shot.png
# 3. Run the §9.1 QA gate on the result. Never silently keep or skip a failed shot.
```
Heavy-page triggers and qb-shoot dependencies: §9.3.

### PB-5 — Oversized `--full` screenshot, content top-left (DPR defect)

```bash
convert in.png -bordercolor white -border 1 -trim +repage out.png
```
Apply ONLY to `--full` outputs (HR-12). Details/detection: §9.2. Never patch the binary.

### PB-6 — Stale target pin / wrong tab driven / eval returns about:blank

```bash
curl -s "http://localhost:$PORT/target"    # title/url ≠ your intended tab → it's stale/phantom
curl -s "http://localhost:$PORT/target?clear"        # (owned port: use /release instead)
curl -s http://localhost:2262/json/list | python3 -c "..."   # re-list, take FULL 32-char id (§6.1)
curl -s "http://localhost:$PORT/target?id=<FULL_ID>"
curl -s "http://localhost:$PORT/target"    # VERIFY title/url now match (HR-4)
agent-browser close && agent-browser connect $PORT
```
Root causes: truncated hand-copied id (HR-3); tab closed/reopened (ids change); pin set on a
different port than the daemon drives (HR-5).

### PB-7 — SPA race (snapshot shows the old page)

```bash
agent-browser wait --load networkidle   # fallback: agent-browser wait 2000
agent-browser snapshot -i -c --json     # re-snapshot; ALL pre-nav @eN refs are invalid
```

### PB-8 — Cert error in independent mode

`agent-browser open <https-url>` through the proxy fails with `ERR_CERT_COMMON_NAME_INVALID`
(the proxy's spoofed identity breaks TLS name checks). Open via qutebrowser's own TLS stack
instead — the `/claim?url=` path:
```bash
CLAIM=$(curl -s -G "http://localhost:9222/claim" --data-urlencode "from=9223" --data-urlencode "url=<https-url>")
# parse port → connect → work → /release  (full recipe §6.3)
```
(The old "use `tab new`" advice is retired — tab new exit-144s in this env, HR-9.)

### PB-9 — Everything wedged, need viewport-emulated QA evidence NOW (LAST RESORT)

The ONLY allowed exception to HR-1, and only when: qutebrowser CDP is degraded (PB-2) AND
Christopher is unavailable to `:restart` AND evidence cannot wait.
```bash
google-chrome-stable --headless=new --remote-debugging-port=9333 \
  --user-data-dir=<scratchpad-tmp-dir> &
# Raw CDP over websocket on :9333. Gotchas (all field-verified 2026-07-02):
#  · /json/new requires PUT on Chrome 144+ (GET returns 405)
#  · Emulation.setDeviceMetricsOverride for mobile viewports
#  · Emulation.setEmulatedMedia for prefers-reduced-motion
#  · do NOT pass --disable-gpu for heavy pages (software raster wedges on them)
#  · full-viewport SVG feTurbulence can hard-wedge software-rendered Chromium
# TEAR IT DOWN after: kill the headless instance, delete the user-data-dir.
```
This is one rung of one playbook — never a general alternative to qutebrowser.

## 11. Worked recipes (each names its verification step — "ran the command" is never done)

### R-1 — Parallel fleet worker (canonical claimed-port session)

Full sequence in §6.3. Skeleton: `/claim?from=9223&url=<start>` → parse `port`+`tab` (check
`tab-create-failed`!) → write env file (`AGENT_BROWSER_CDP`, unique `AGENT_BROWSER_SESSION`,
`AGENT_BROWSER_COLOR_SCHEME=light`) → `agent-browser connect $PORT` within 30s → verify
`curl :$PORT/target` shows your URL → work (source env every call) → `agent-browser close` →
`/release?port=$PORT` → **verify** `/sessions` no longer lists the port.

### R-2 — Bot-protected read (Mode B)

`curl :2262/json/list` → select tab programmatically → `webSocketDebuggerUrl` verbatim →
websockets `Runtime.evaluate` with `returnByValue`, recv-loop matching response `id` (§7).
**Verify:** the extracted text/links are non-empty and match the expected page (a phantom
target returns empty/about:blank content — that's PB-6/HR-3 territory).

### R-3 — Search X / open a bot-protected page fresh (no tab-new)

```bash
CLAIM=$(curl -s -G "http://localhost:9222/claim" \
        --data-urlencode "from=9223" \
        --data-urlencode "url=https://x.com/search?q=<query>&f=user")
# parse port → connect within 30s → wait --load networkidle → snapshot -i -c --json
# The claimed tab shares the user's qutebrowser profile: logged in, real fingerprint, no bot flags.
# Teardown: close + /release?port=N.
```
**Verify:** snapshot contains search-result elements, not a login/challenge wall.

### R-4 — Batch execution (one daemon round-trip, atomic logs)

```bash
echo '[["snapshot","-i"],["click","@e2"],["wait","--load","networkidle"],["screenshot","/path/after.png"]]' \
  | agent-browser batch --json
```
Default: continue-all (every command runs, failures reported per-step). `--bail`: stop on
first error — use for dependent sequences (click must succeed before the screenshot means
anything). Batch beats `&&` chains when you want a single round-trip + machine-readable
per-step results. **Verify:** parse the JSON result; assert every step's status.

### R-5 — Network monitoring / QA evidence bundle

```bash
agent-browser network requests --filter api --type xhr,fetch   # tracked requests
agent-browser network requests --clear                          # reset between phases
agent-browser network har start /path/session.har               # full capture … har stop
agent-browser network route "**/api/flaky" --body '{"ok":true}' # mock; --abort to block; unroute to undo
agent-browser console && agent-browser errors                   # pair for the evidence bundle
```
**Verify:** the HAR/requests list actually contains the endpoints you claim were hit.

## 12. TEARDOWN CHECKLIST (blocking — a session is not "done" until ALL pass)

- [ ] `agent-browser close` — daemon down.
- [ ] Claimed ports released: `curl -s "http://localhost:9222/release?port=$PORT"` — response
      shows `released_tab`/`closed`.
- [ ] Manual pins cleared: `/target?clear` on every port you pinned (owned-port pins persist
      by design until `/release` — that IS the release).
- [ ] No leftover dedicated tabs: `curl -s http://localhost:9222/sessions` shows no entry for
      your port(s).
- [ ] Every kept screenshot passed the §9.1 QA gate.
- [ ] Mode B: if you navigated the user's tab, you restored its original URL.

The 600s reaper will eventually GC a leaked claim — that is a backstop for dead workers, not
permission to skip this list (HR-6).

## 13. Do / Don't quick pairs

| DO | DON'T |
|---|---|
| `fill @e5 "text"` to replace field content | `type` to replace — type APPENDS |
| Re-snapshot after any click that mutates DOM | Reuse pre-click `@eN` refs (HR-10) |
| `find role button click --name Submit` when refs churn | Loop snapshot-grep-click blindly |
| Chain with `&&` (daemon persists) | `close` between every command |
| Write screenshots to the scratchpad / task dir | Litter shared /tmp with captures of authenticated apps (HR-15) |
| `/claim?from=9223` for any parallel work | Bare `/claim` (can hijack 9222) or sharing 9222 across workers (HR-7) |
| Extract `webSocketDebuggerUrl` programmatically | Hand-copy a tab id from logs/output (HR-3) |
| `wait --load networkidle` after SPA nav | Snapshot immediately after a route change (HR-11) |
| `top` first when everything wedges on one origin | An hour of CDP archaeology while `next dev` burns a core (HR-13) |

## 14. References (progressive disclosure)

- `references/cli-reference.md` — full verified v0.22.3 command surface (keyboard/mouse, set,
  cookies/storage, auth vault + security caution, record/trace/profiler, streaming, iOS, all
  env vars incl. binary-only `AGENT_BROWSER_CDP`, config-file precedence, wait variants,
  screenshot post-processing snippets).
- `references/proxy-internals.md` — qb_proxy.py endpoint semantics from source, Target.*
  mocks, owned-tab invariants, reaper logic, doctor behavior + log signatures, config.py
  integration, canonical restart.
- `references/upgrade-history.md` — elpabl0/sebat-duls adoption credit, the 2026-06-22
  tab-isolation cut-over record, `qb_proxy.py.new` OBSOLETE notice, template cutover
  checklist for any FUTURE staged proxy revision.
