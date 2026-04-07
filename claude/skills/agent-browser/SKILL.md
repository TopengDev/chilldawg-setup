---
name: agent-browser
description: Automates browser interactions for web testing, form filling, screenshots, and data extraction. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages.
metadata:
  filePattern: "**/cdp*,**/browser*,**/proxy*"
  bashPattern: "agent-browser|curl.*localhost:(9222|2262)"
---

# Browser Automation with agent-browser v0.22.3

## Architecture Overview

All browser interaction goes through the user's running **qutebrowser** instance via a CDP proxy.

```
agent-browser (Rust CLI) <-> CDP Proxy (port 9222) <-> qutebrowser CDP (port 2262)
                                                      -> Spoofs Chrome identity
                                                      -> Mocks unsupported Target.* methods
                                                      -> Tab targeting via /target endpoint
                                                      -> Opens tabs via qutebrowser CLI
```

- **Proxy**: `~/.config/qutebrowser/scripts/qb_proxy.py` — MUST be running
- **Port 9222**: Proxy port — agent-browser connects here
- **Port 2262**: qutebrowser's real CDP — used for direct WebSocket targeting

## Tab Targeting (CRITICAL — read this first)

The proxy controls which tab agent-browser operates on. By default it targets the **active tab** (index 0 in qutebrowser). To target a different tab:

```bash
# Pin a tab by URL substring
curl -s "http://localhost:9222/target?url=x.com"

# Pin a tab by CDP id
curl -s "http://localhost:9222/target?id=<TAB_ID>"

# Show current target
curl -s "http://localhost:9222/target"

# Clear pin — revert to active tab
curl -s "http://localhost:9222/target?clear"
```

**IMPORTANT**: After pinning a target, you must `agent-browser close` and reconnect so the daemon attaches to the new target. Always clear the pin when done.

### Workflow for targeting a specific tab

```bash
# 1. Find the tab
curl -s http://localhost:2262/json/list | python3 -c "import sys, json; [print(f'[{t[\"id\"]}] {t[\"title\"][:60]}') for t in json.load(sys.stdin) if t.get('type') == 'page']"

# 2. Pin it
curl -s "http://localhost:9222/target?url=x.com"

# 3. Close daemon so it reconnects to new target
agent-browser close

# 4. Use agent-browser normally
export AGENT_BROWSER_CDP=9222
agent-browser snapshot -i -c --json

# 5. Clean up when done
agent-browser close
curl -s "http://localhost:9222/target?clear"
```

## Discover Tabs

Index **0** is ALWAYS the tab the user is currently looking at.

```bash
curl -s http://localhost:2262/json/list | python3 -c "import sys, json; [print(f'[{t[\"id\"]}] {t[\"title\"][:60]}') for t in json.load(sys.stdin) if t.get('type') == 'page']"
```

## Two Interaction Modes

### Mode A: agent-browser via Proxy (preferred)

Gives you snapshot (accessibility tree), element refs, click/fill/screenshot, and all v0.22.3 features. **Always prefix with `export AGENT_BROWSER_CDP=9222`.**

```bash
export AGENT_BROWSER_CDP=9222

# Snapshot — accessibility tree with interactive element refs
agent-browser snapshot -i -c --json    # -i = interactive only, -c = compact

# Read page info
agent-browser get url --json
agent-browser get title --json
agent-browser get text @e1 --json    # Text of specific element

# Interact with elements by ref
agent-browser click @e2                          # Click element
agent-browser fill @e3 "search query"  # Clear and type into input
agent-browser hover @e1                          # Hover
agent-browser type @e3 "append text"   # Type without clearing
agent-browser press Enter                        # Press key

# Navigate
agent-browser open <url>                         # Navigate current page
agent-browser back                               # Go back
agent-browser forward                            # Go forward
agent-browser reload                             # Reload

# Tabs
agent-browser tab                                # List tabs
agent-browser tab new "https://..."              # Open new tab in qutebrowser
agent-browser tab <n>                            # Switch to tab n
agent-browser tab close [n]                      # Close tab

# Scroll
agent-browser scroll down 500                    # Scroll down 500px
agent-browser scroll up 300                      # Scroll up
agent-browser scrollintoview @e5                 # Scroll element into view

# Screenshots
agent-browser screenshot /tmp/page.png           # Save screenshot
agent-browser screenshot --full /tmp/full.png  # Full page
agent-browser screenshot --annotate              # Numbered labels on elements

# Execute JS
agent-browser eval "document.title"    # Run JavaScript

# Wait
agent-browser wait @e1                           # Wait for element visible
agent-browser wait --text "Welcome"  # Wait for text to appear
agent-browser wait 2000                          # Wait 2 seconds

# Get element info
agent-browser get html @e1                       # innerHTML
agent-browser get value @e2                      # Input value
agent-browser get attr @e1 "href"                # Get attribute
agent-browser get count "a"                      # Count matching elements
agent-browser get box @e1                        # Bounding box

# Check state
agent-browser is visible @e1
agent-browser is enabled @e2
agent-browser is checked @e3

# Semantic locators (find by role/text/label)
agent-browser find role button click --name "Submit"
agent-browser find text "Sign In" click
agent-browser find label "Email" fill "test@test.com"

# Batch execution (multiple commands, one invocation)
echo '[["snapshot", "-i"], ["click", "@e2"], ["screenshot", "/tmp/after.png"]]' | agent-browser batch --json

# Network monitoring
agent-browser network requests                   # View tracked requests
agent-browser network requests --filter api     # Filter by substring
agent-browser network requests --type xhr,fetch

# Clipboard
agent-browser clipboard read
agent-browser clipboard write "text"

# Diff (compare snapshots)
agent-browser diff snapshot                      # Current vs last
agent-browser diff screenshot --baseline before.png    # Visual diff

# Console & errors
agent-browser console                            # View console messages
agent-browser errors                             # View page errors

# Close daemon when done
agent-browser close
```

### Snapshot — The Key Feature

Snapshot returns a structured accessibility tree with refs for every interactive element:

```
- button "Log In" [ref=e4]
- combobox "Search" [ref=e9]
- tab "Details" [selected, ref=e19]
- link "Documentation" [ref=e86]
- textbox "Email" [ref=e123]
```

Each `@eN` ref is a stable handle to click, fill, or read that element. This is the primary way to understand and interact with pages.

**Snapshot options:**
```bash
agent-browser snapshot                           # Full tree
agent-browser snapshot -i                        # Interactive elements only (recommended)
agent-browser snapshot -c                        # Compact (remove empty nodes)
agent-browser snapshot -i -c                     # Both — best for most tasks
agent-browser snapshot -d 3                      # Limit depth
agent-browser snapshot -s "#main"                # Scope to CSS selector
agent-browser snapshot -i -c --json              # Machine-readable (for parsing)
```

### Mode B: Direct WebSocket (for bot-protected sites)

For sites with bot detection (X, Google, LinkedIn, CoinGecko, DeFiLlama, block explorers), use direct CDP to the user's authenticated tab. This bypasses agent-browser entirely.

```bash
# Get tab ID first
TAB_ID=$(curl -s http://localhost:2262/json/list | python3 -c "import sys,json; tabs=[t for t in json.load(sys.stdin) if t.get('type')=='page']; print(tabs[0]['id'])")

# Read page content
python3 -c "
import asyncio, websockets, json
async def run():
    async with websockets.connect('ws://localhost:2262/devtools/page/$TAB_ID') as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Runtime.evaluate', 'params': {'expression': 'document.body.innerText', 'returnByValue': True}}))
        res = json.loads(await ws.recv())
        print(res.get('result',{}).get('result',{}).get('value',''))
asyncio.run(run())
"

# Navigate a tab
python3 -c "
import asyncio, websockets, json
async def run():
    async with websockets.connect('ws://localhost:2262/devtools/page/$TAB_ID') as ws:
        await ws.send(json.dumps({'id': 1, 'method': 'Page.navigate', 'params': {'url': 'https://example.com'}}))
        print(json.loads(await ws.recv()))
asyncio.run(run())
"

# Extract links
python3 -c "
import asyncio, websockets, json
async def run():
    async with websockets.connect('ws://localhost:2262/devtools/page/$TAB_ID') as ws:
        js = 'JSON.stringify(Array.from(document.querySelectorAll(\"a\")).slice(0,20).map(a=>({text:a.innerText.trim().substring(0,50),href:a.href})))'
        await ws.send(json.dumps({'id': 1, 'method': 'Runtime.evaluate', 'params': {'expression': js, 'returnByValue': True}}))
        res = json.loads(await ws.recv())
        for l in json.loads(res.get('result',{}).get('result',{}).get('value','[]')):
            if l['text']: print(f'{l[\"text\"]} -> {l[\"href\"]}')
asyncio.run(run())
"
```

## When to Use Which Mode

| Situation | Mode | Why |
|-----------|------|-----|
| Read/interact with any page | **A (agent-browser)** | Snapshot gives structured tree + refs |
| Bot-protected sites (X, Google, etc.) | **B (Direct WebSocket)** | Uses user's cookies/session, no bot flags |
| Open a new tab | **A** (`tab new`) | Proxy mocks Target.createTarget via qb CLI |
| Fill forms, click buttons | **A** | Refs make targeting reliable |
| Quick text extraction | **B** | Faster, no daemon startup |
| Research / navigate a site | **A or B** | A for interaction, B for reading |

## Common Workflows

### Read a page with snapshot
```bash
export AGENT_BROWSER_CDP=9222
agent-browser snapshot -i -c --json | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['snapshot'])"
agent-browser close
```

### Target a non-active tab
```bash
curl -s "http://localhost:9222/target?url=github.com"
agent-browser close    # reconnect to new target
export AGENT_BROWSER_CDP=9222
agent-browser snapshot -i -c --json
agent-browser close
curl -s "http://localhost:9222/target?clear"
```

### Open new tab and interact
```bash
export AGENT_BROWSER_CDP=9222
agent-browser tab new "https://docs.example.com"
# Pin the new tab
curl -s "http://localhost:9222/target?url=docs.example.com"
agent-browser close
agent-browser snapshot -i -c --json
agent-browser click @e5    # click a link
agent-browser snapshot -i -c --json  # see updated page
agent-browser close
curl -s "http://localhost:9222/target?clear"
```

### Search on X (bot-protected — use Direct WebSocket for reading)
```bash
export AGENT_BROWSER_CDP=9222
agent-browser tab new "https://x.com/search?q=query&f=user"
agent-browser close

# Pin and snapshot (works because proxy targets the tab, not agent-browser visiting X)
curl -s "http://localhost:9222/target?url=x.com/search"
agent-browser close
agent-browser snapshot -i -c --json
agent-browser close
curl -s "http://localhost:9222/target?clear"
```

## Debugging

```bash
# Check proxy is running
curl -s http://localhost:9222/json/version | python3 -c "import sys,json; print(json.load(sys.stdin)['Browser'])"

# Check qutebrowser CDP
curl -s http://localhost:2262/json/list | head -5

# Restart proxy
pkill -f "qb_proxy.py"; sleep 1
python3 ~/.config/qutebrowser/scripts/qb_proxy.py > /dev/null 2>&1 &

# Check current target
curl -s http://localhost:9222/target

# Daemon stuck? Close and retry
agent-browser close
```

## Known Limitations

- **HTTPS in Independent Mode**: `agent-browser open <https-url>` fails with `ERR_CERT_COMMON_NAME_INVALID` through the proxy. Use `tab new` instead (opens via qutebrowser CLI which handles TLS normally).
- **One target at a time**: The daemon operates on whichever tab the proxy returns via `Target.getTargets`. Pin a different tab with `/target?url=...`, close the daemon, and reconnect.
- **Daemon lifecycle**: Each `agent-browser close` + new command restarts the daemon. For multi-step workflows, chain commands without closing (the daemon persists between commands).
- **SPA navigation**: After client-side navigation, wait before snapshot (`agent-browser wait --load networkidle` or `wait 2000`).
