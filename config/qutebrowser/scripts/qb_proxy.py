# ── LIVE: multi-port CDP proxy with per-port TAB ISOLATION ────────────────────
# Multi-port CDP proxy (9222-9236) with /claim /free /sessions race-free port
# allocation, WS heartbeat, stale-connection reaper, per-port targets, companion
# filtering, and graceful per-port bind.
#
# Adapted from elpabl0/sebat-duls (github.com/alkautsarf), with permission, 2026-05-30.
# Ported macOS → Linux: QUTEBROWSER_BIN default set to /usr/bin/qutebrowser.
#
# TAB ISOLATION (2026-06-22): /claim now creates a DEDICATED background tab per
# claimed port and pins the port to it, so N concurrent agent-browser sessions
# each drive their OWN tab with zero cross-clobber (true parallel). The pin
# survives daemon disconnect/reconnect (a fleet runs many agent-browser commands
# per claim); /release?port=N closes the dedicated tab + frees the port; a reaper
# GCs dedicated tabs left idle past OWNED_TAB_GRACE.
#   • Ports that DON'T /claim (e.g. fitest, bcas, legacy single-worker on 9222)
#     are UNCHANGED — they keep the active-tab (pages[0]) fallback. Only callers
#     that explicitly /claim get a dedicated tab.
#   • Tab creation uses `qutebrowser --target tab-bg-silent <url>` (background,
#     no focus theft) serialized by a lock so the before/after id-diff is
#     race-safe under concurrent claims. Teardown uses Target.closeTarget
#     (id-scoped) on the real CDP — it never touches a tab the proxy didn't create.
#
# Restart procedure (proxy ONLY, never qutebrowser): pkill -f qb_proxy.py then
# `python3 ~/.config/qutebrowser/scripts/qb_proxy.py >>/tmp/qb_proxy.log 2>&1 &`.
# Note: config.py only auto-starts the proxy at qutebrowser launch — a mid-session
# proxy change must be relaunched manually. qutebrowser keeps running; clients reconnect.
# ──────────────────────────────────────────────────────────────────────────────
import asyncio
import json
import os
import time
import aiohttp
from aiohttp import web
import sys

TARGET_PORT = 2262
BASE_PORT = 9222
PORT_COUNT = 15  # Ports 9222-9236 (9222-9231 for agents, 9232-9236 for companion)
COMPANION_PORT = 7700  # Filter companion panel from CDP target lists
RESERVATION_TTL = 30.0  # Default /claim reservation window in seconds — allows slow daemon cold-start under system load
OWNED_TAB_GRACE = 600.0  # Seconds a dedicated (/claim-created) tab may sit with no live connection before the reaper GCs it. Generous so slow fleet workers pausing between agent-browser commands are never reaped mid-session; /release is the clean teardown path.
QB_BIN = os.environ.get(
    "QUTEBROWSER_BIN",
    "/usr/bin/qutebrowser",
)

# Per-port target state: {port: tab_id_or_None}
_targets = {}

# Per-port active WebSocket connections: {port: set(ws_response)}
_connections = {}

# Per-port reservation expiry timestamps: {port: unix_time_when_expires}
# Set by /claim, cleared when a WS connects or when the TTL elapses.
# Prevents the /free → daemon-connect race where parallel callers
# both see a port as "free" before either has actually connected.
_reservations = {}

# Per-port DEDICATED tab the proxy itself created for a /claim: {port: tab_id}.
# INVARIANT: the proxy only ever closes tabs that appear here — never a tab it
# didn't create (so bcas's tab, fitest's tab, and the user's tabs are untouchable).
# Distinct from _targets (which can also be set by a manual /target pin): _owned_tabs
# tracks proxy-OWNED lifecycle (close-on-/release, GC), _targets tracks routing.
_owned_tabs = {}

# Per-port timestamp marking when a dedicated tab last went idle (no live WS).
# {port: unix_time}. Set on last-disconnect for owned ports, cleared on reconnect.
# The reaper closes an owned tab idle longer than OWNED_TAB_GRACE.
_owned_idle_since = {}

# Serializes dedicated-tab creation so the before/after /json/list id-diff is
# race-safe when multiple /claim calls arrive concurrently. Created in main().
_tab_create_lock = None


def _is_port_available(port):
    """True if port has no active WS connections AND no valid reservation."""
    if _connections.get(port):
        return False
    exp = _reservations.get(port)
    if exp and time.time() < exp:
        return False
    return True


def _request_port(request):
    """Get the listening port this request arrived on."""
    return request.transport.get_extra_info('sockname')[1]


def _is_companion(tab):
    """Check if a CDP target is the companion panel (not a real page)."""
    url = tab.get("url", "")
    return f"localhost:{COMPANION_PORT}" in url or f"127.0.0.1:{COMPANION_PORT}" in url


async def get_target_tab(port):
    """Fetch the target tab for a specific port — either pinned or active tab."""
    target_id = _targets.get(port)
    async with aiohttp.ClientSession() as session:
        async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as res:
            tabs = await res.json()
            pages = [t for t in tabs if t.get("type") == "page" and not _is_companion(t)]
            if not pages:
                return None
            if target_id:
                for p in pages:
                    if p["id"] == target_id:
                        return p
            return pages[0]
    return None


def _is_real_page(tab):
    """A real, drivable page target — not companion panel, not a devtools view."""
    if tab.get("type") != "page":
        return False
    if _is_companion(tab):
        return False
    if tab.get("url", "").startswith("devtools://"):
        return False
    return True


async def _list_pages():
    """Fetch the current real-page targets from the live CDP (dict id->tab)."""
    async with aiohttp.ClientSession() as session:
        async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as res:
            tabs = await res.json()
    return {t["id"]: t for t in tabs if _is_real_page(t)}


async def _create_dedicated_tab(url):
    """Open a fresh background tab via the qutebrowser CLI and return its CDP
    target id. Serialized via _tab_create_lock so the before/after id-diff is
    race-safe under concurrent /claim calls. Returns the new tab id, or None on
    failure. Opens with --target tab-bg-silent (background, no focus theft) so it
    never disturbs whatever tab the user is looking at."""
    async with _tab_create_lock:
        before = set((await _list_pages()).keys())
        try:
            proc = await asyncio.create_subprocess_exec(
                QB_BIN, "--target", "tab-bg-silent", url,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
                start_new_session=True,  # isolate qb CLI's process group from the proxy
            )
            try:
                await asyncio.wait_for(proc.wait(), timeout=15)
            except asyncio.TimeoutError:
                proc.kill()
        except Exception as e:
            sys.stderr.write(f"_create_dedicated_tab: qb spawn error: {e}\n")
            sys.stderr.flush()
            return None
        # Poll up to ~8s for the new page id to appear.
        base = url.split("?")[0]
        for _ in range(40):
            await asyncio.sleep(0.2)
            pages = await _list_pages()
            new_ids = set(pages.keys()) - before
            if new_ids:
                # Prefer the new id whose URL matches (robust if an unrelated tab
                # also appeared during the window); else take any new id.
                for nid in new_ids:
                    if base and base in pages[nid].get("url", ""):
                        return nid
                return next(iter(new_ids))
        return None


async def _close_tab(tab_id):
    """Close a single tab by CDP id via Target.closeTarget on the REAL CDP
    (port 2262). id-scoped — only ever called on proxy-owned tab ids, so it can
    never touch bcas/fitest/user tabs. Idempotent: closing an already-gone id is
    a harmless no-op. Returns True on success."""
    if not tab_id:
        return False
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/version") as res:
                ver = await res.json()
            ws_url = ver["webSocketDebuggerUrl"]
            async with session.ws_connect(ws_url, autoclose=True, autoping=False) as ws:
                await ws.send_str(json.dumps({
                    "id": 1,
                    "method": "Target.closeTarget",
                    "params": {"targetId": tab_id},
                }))
                for _ in range(10):
                    msg = await asyncio.wait_for(ws.receive(), timeout=5)
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = json.loads(msg.data)
                        if data.get("id") == 1:
                            return bool(data.get("result", {}).get("success", True))
                    elif msg.type in (aiohttp.WSMsgType.CLOSE,
                                      aiohttp.WSMsgType.CLOSED,
                                      aiohttp.WSMsgType.ERROR):
                        break
    except Exception as e:
        sys.stderr.write(f"_close_tab error for {tab_id[:16] if tab_id else ''}: {e}\n")
        sys.stderr.flush()
    return False


async def handle_target(request):
    """Set or clear the target tab, scoped to the port this request arrived on.

    GET /target?id=<tabId>       — pin a specific tab by CDP id
    GET /target?url=<substring>  — pin the first tab whose URL contains substring
    GET /target?clear            — revert to active tab (index 0)
    GET /target                  — show current target
    """
    port = _request_port(request)
    tab_id = request.query.get("id")
    url_match = request.query.get("url")
    clear = "clear" in request.query

    if clear:
        _targets[port] = None
        return web.json_response({"target": "active tab (default)", "port": port})

    if tab_id:
        _targets[port] = tab_id
        return web.json_response({"target": tab_id, "port": port})

    if url_match:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as res:
                tabs = await res.json()
                for t in tabs:
                    if t.get("type") != "page":
                        continue
                    if _is_companion(t):
                        continue
                    if url_match.lower() in t.get("url", "").lower():
                        _targets[port] = t["id"]
                        return web.json_response({
                            "target": t["id"],
                            "title": t.get("title", ""),
                            "url": t.get("url", ""),
                            "port": port,
                        })
        return web.json_response({"error": f"No tab matching '{url_match}'"}, status=404)

    # Show current target
    tab = await get_target_tab(port)
    return web.json_response({
        "target": _targets.get(port) or "active tab (default)",
        "title": tab.get("title", "") if tab else "",
        "url": tab.get("url", "") if tab else "",
        "port": port,
    })


async def handle_sessions(request):
    """Show all port sessions with their targets and connection counts."""
    sessions = {}
    for port in range(BASE_PORT, BASE_PORT + PORT_COUNT):
        target_id = _targets.get(port)
        conns = len(_connections.get(port, set()))
        owned = _owned_tabs.get(port)
        entry = {"target": target_id, "connections": conns}
        if owned:
            entry["dedicated_tab"] = owned
            idle = _owned_idle_since.get(port)
            entry["idle_secs"] = round(time.time() - idle, 1) if idle else 0
        # Only include ports that have a target, an owned tab, or active connections
        if target_id or owned or conns > 0:
            # Resolve tab info for active targets
            if target_id:
                try:
                    async with aiohttp.ClientSession() as session:
                        async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as res:
                            tabs = await res.json()
                            for t in tabs:
                                if t["id"] == target_id:
                                    entry["title"] = t.get("title", "")[:60]
                                    entry["url"] = t.get("url", "")
                                    break
                except Exception:
                    pass
            sessions[str(port)] = entry
    return web.json_response({
        "ports": f"{BASE_PORT}-{BASE_PORT + PORT_COUNT - 1}",
        "active": sessions,
    })


async def handle_free(request):
    """Return the first available port with no active WebSocket connections and no active reservation.

    Unlike /claim, this does NOT reserve the port — it only reports it as currently free.
    Two parallel callers hitting /free in quick succession can both get back the same port.
    For race-free port allocation use /claim instead.
    """
    start = int(request.query.get('from', BASE_PORT))
    start = max(start, BASE_PORT)
    for port in range(start, BASE_PORT + PORT_COUNT):
        if _is_port_available(port):
            return web.json_response({"port": port})
    return web.json_response({"error": "No free ports"}, status=503)


async def handle_claim(request):
    """Atomically return AND reserve a free port, and (by default) give it a
    DEDICATED tab so concurrent claims are fully isolated.

    GET /claim                 — reserve a port + create+pin a dedicated about:blank tab
    GET /claim?url=<url>       — open the dedicated tab directly at <url> (TLS-safe
                                 path: opened by qutebrowser CLI, like `tab new`)
    GET /claim?ttl=N           — reservation window N seconds (default RESERVATION_TTL)
    GET /claim?notab=1         — legacy: reserve the port only, NO dedicated tab
                                 (caller uses the active-tab fallback / pins manually)

    The reservation blocks /free and /claim from returning this port until either:
      1. A WebSocket connection is established on the port (reservation is consumed), OR
      2. The TTL elapses with no connection (reservation expires)

    This eliminates the race window between a caller picking a port and the
    daemon actually connecting. Parallel callers are guaranteed different ports.

    The dedicated tab is recorded in _owned_tabs[port] and pinned via _targets[port],
    so the port's daemon attaches to ITS OWN tab (zero cross-clobber). The pin
    persists across daemon disconnect/reconnect; call /release?port=N when done to
    close the tab + free the port (the reaper GCs it after OWNED_TAB_GRACE otherwise).
    """
    try:
        ttl = float(request.query.get('ttl', RESERVATION_TTL))
    except ValueError:
        return web.json_response({"error": "Invalid ttl"}, status=400)
    start = int(request.query.get('from', BASE_PORT))
    start = max(start, BASE_PORT)
    notab = 'notab' in request.query
    url = request.query.get('url', 'about:blank')

    for port in range(start, BASE_PORT + PORT_COUNT):
        if _is_port_available(port):
            # Reserve FIRST (before any await) so concurrent claims can't pick this port.
            _reservations[port] = time.time() + ttl
            sys.stderr.write(f"[{port}] Reserved for {ttl}s via /claim\n")
            sys.stderr.flush()

            if notab:
                return web.json_response({"port": port, "ttl": ttl})

            tab_id = await _create_dedicated_tab(url)
            if not tab_id:
                # Tab creation failed — keep the port (still usable via active-tab
                # fallback), but flag it so the caller knows it's NOT isolated.
                sys.stderr.write(f"[{port}] Dedicated-tab create FAILED; port returned unpinned\n")
                sys.stderr.flush()
                return web.json_response(
                    {"port": port, "ttl": ttl, "tab": None, "warning": "tab-create-failed"}
                )

            _owned_tabs[port] = tab_id
            _targets[port] = tab_id
            _owned_idle_since.pop(port, None)
            sys.stderr.write(f"[{port}] Dedicated tab {tab_id[:16]} pinned ({url[:48]})\n")
            sys.stderr.flush()
            return web.json_response({"port": port, "ttl": ttl, "tab": tab_id})
    return web.json_response({"error": "No free ports"}, status=503)


async def handle_release(request):
    """Release a claimed port: close its dedicated tab (if any) and clear all
    per-port state. The clean teardown counterpart to /claim.

    GET /release?port=N   — release port N
    GET /release          — release the port this request arrived on
    """
    qp = request.query.get('port')
    try:
        port = int(qp) if qp is not None else _request_port(request)
    except ValueError:
        return web.json_response({"error": "Invalid port"}, status=400)

    tab = _owned_tabs.pop(port, None)
    _owned_idle_since.pop(port, None)
    _reservations.pop(port, None)
    if tab is not None and _targets.get(port) == tab:
        _targets[port] = None
    closed = await _close_tab(tab) if tab else False
    sys.stderr.write(f"[{port}] /release — closed owned tab {tab[:16] if tab else 'none'} (closed={closed})\n")
    sys.stderr.flush()
    return web.json_response({"port": port, "released_tab": tab, "closed": closed})


async def handle_http(request):
    path = request.path.rstrip('/')
    url_path = path if path else '/'
    port = _request_port(request)
    sys.stderr.write(f"HTTP {request.method} {url_path} (port {port})\n")
    sys.stderr.flush()

    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"http://127.0.0.1:{TARGET_PORT}{url_path}") as res:
                if path == '/json/version':
                    data = await res.json()
                    data['Browser'] = "Chrome/134.0.0.0"
                    ws_url = data['webSocketDebuggerUrl']
                    data['webSocketDebuggerUrl'] = ws_url.replace(str(TARGET_PORT), str(port))
                    return web.json_response(data)
                elif path in ['/json', '/json/list']:
                    data = await res.json()
                    # Filter out companion panel views from target list
                    data = [item for item in data if not _is_companion(item)]
                    for item in data:
                        if 'webSocketDebuggerUrl' in item:
                            item['webSocketDebuggerUrl'] = item['webSocketDebuggerUrl'].replace(str(TARGET_PORT), str(port))
                    return web.json_response(data)
                else:
                    body = await res.read()
                    return web.Response(body=body, content_type=res.content_type)
        except Exception as e:
            sys.stderr.write(f"HTTP Error: {e}\n")
            sys.stderr.flush()
            return web.Response(text=str(e), status=502)

async def handle_ws(request):
    port = _request_port(request)
    sys.stderr.write(f"WS Connection on port {port}: {request.path}\n")
    sys.stderr.flush()
    ws_client = web.WebSocketResponse(
        autoclose=False,
        autoping=True,        # Send pings to detect dead clients
        heartbeat=15.0,       # Ping every 15s, close if no pong in 15s
    )
    await ws_client.prepare(request)

    # Track this connection
    if port not in _connections:
        _connections[port] = set()
    _connections[port].add(ws_client)

    # A (re)connect on an owned port cancels any pending idle-GC for it.
    _owned_idle_since.pop(port, None)

    # Consume any active /claim reservation — caller has now connected
    if _reservations.pop(port, None) is not None:
        sys.stderr.write(f"[{port}] Reservation consumed by WS connect\n")
        sys.stderr.flush()

    target_url = f"ws://127.0.0.1:{TARGET_PORT}{request.path}"

    try:
        async with aiohttp.ClientSession() as session:
            async with session.ws_connect(target_url, autoclose=False, autoping=False) as ws_target:
                async def forward_to_target():
                    try:
                        async for msg in ws_client:
                            if msg.type == aiohttp.WSMsgType.TEXT:
                                try:
                                    data = json.loads(msg.data)
                                    method = data.get('method', '')

                                    if method == 'Target.createBrowserContext':
                                        sys.stderr.write(f"[{port}] Mocking Target.createBrowserContext\n")
                                        sys.stderr.flush()
                                        await ws_client.send_str(json.dumps({
                                            "id": data['id'],
                                            "result": {"browserContextId": f"fake-context-{port}"}
                                        }))
                                        continue
                                    elif method == 'Target.getBrowserContexts':
                                        await ws_client.send_str(json.dumps({
                                            "id": data['id'],
                                            "result": {"browserContextIds": [f"fake-context-{port}"]}
                                        }))
                                        continue
                                    elif method == 'Target.setDiscoverTargets':
                                        sys.stderr.write(f"[{port}] Mocking Target.setDiscoverTargets\n")
                                        sys.stderr.flush()
                                        await ws_client.send_str(json.dumps({
                                            "id": data['id'],
                                            "result": {}
                                        }))
                                        continue
                                    elif method == 'Target.getTargets':
                                        # Return only the target tab for THIS port
                                        tab = await get_target_tab(port)
                                        if tab:
                                            target_info = {
                                                "targetId": tab["id"],
                                                "type": "page",
                                                "title": tab.get("title", ""),
                                                "url": tab.get("url", ""),
                                                "attached": False,
                                                "browserContextId": f"fake-context-{port}",
                                            }
                                            sys.stderr.write(f"[{port}] Mocking Target.getTargets -> {tab['title'][:40]}\n")
                                            sys.stderr.flush()
                                            await ws_client.send_str(json.dumps({
                                                "id": data['id'],
                                                "result": {"targetInfos": [target_info]}
                                            }))
                                        else:
                                            await ws_client.send_str(json.dumps({
                                                "id": data['id'],
                                                "result": {"targetInfos": []}
                                            }))
                                        continue
                                    elif method == 'Target.createTarget':
                                        url = data.get('params', {}).get('url', 'about:blank')
                                        sys.stderr.write(f"[{port}] Mocking Target.createTarget -> {url[:60]}\n")
                                        sys.stderr.flush()
                                        # Snapshot existing tab IDs
                                        async with aiohttp.ClientSession() as s:
                                            async with s.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as r:
                                                before = {t["id"] for t in await r.json() if t.get("type") == "page"}
                                        # Open tab via qutebrowser CLI
                                        proc = await asyncio.create_subprocess_exec(
                                            QB_BIN, "--target", "tab-bg-silent", url,
                                            stdout=asyncio.subprocess.DEVNULL,
                                            stderr=asyncio.subprocess.DEVNULL,
                                        )
                                        await proc.wait()
                                        # Poll for the new tab (up to 10s)
                                        new_tab = None
                                        for _ in range(20):
                                            await asyncio.sleep(0.5)
                                            async with aiohttp.ClientSession() as s:
                                                async with s.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as r:
                                                    tabs = await r.json()
                                                    for t in tabs:
                                                        if t.get("type") == "page" and t["id"] not in before:
                                                            new_tab = t
                                                            break
                                            if new_tab:
                                                break
                                        if new_tab:
                                            await ws_client.send_str(json.dumps({
                                                "id": data['id'],
                                                "result": {"targetId": new_tab["id"]}
                                            }))
                                        else:
                                            await ws_client.send_str(json.dumps({
                                                "id": data['id'],
                                                "error": {"code": -32000, "message": "Tab open timed out"}
                                            }))
                                        continue
                                    elif method == 'Target.setAutoAttach':
                                        await ws_client.send_str(json.dumps({
                                            "id": data['id'],
                                            "result": {}
                                        }))
                                        continue
                                except:
                                    pass
                                await ws_target.send_str(msg.data)
                            elif msg.type == aiohttp.WSMsgType.BINARY:
                                await ws_target.send_bytes(msg.data)
                            elif msg.type == aiohttp.WSMsgType.CLOSE:
                                await ws_target.close()
                    except Exception as e:
                        sys.stderr.write(f"[{port}] Forward to target error: {e}\n")
                        sys.stderr.flush()

                async def forward_to_client():
                    try:
                        async for msg in ws_target:
                            if msg.type == aiohttp.WSMsgType.TEXT:
                                if not ws_client.closed:
                                    try:
                                        data = json.loads(msg.data)
                                        # Intercept Browser.getVersion response
                                        if data.get('result', {}).get('product', '').startswith('qutebrowser'):
                                            data['result']['product'] = "Chrome/134.0.0.0"
                                            await ws_client.send_str(json.dumps(data))
                                            continue
                                    except:
                                        pass
                                    await ws_client.send_str(msg.data)
                            elif msg.type == aiohttp.WSMsgType.BINARY:
                                if not ws_client.closed:
                                    await ws_client.send_bytes(msg.data)
                            elif msg.type == aiohttp.WSMsgType.CLOSE:
                                if not ws_client.closed:
                                    await ws_client.close()
                    except Exception as e:
                        sys.stderr.write(f"[{port}] Forward to client error: {e}\n")
                        sys.stderr.flush()

                await asyncio.gather(forward_to_target(), forward_to_client())
    finally:
        # Clean up connection tracking
        if port in _connections:
            _connections[port].discard(ws_client)
            if not _connections[port]:
                if port in _owned_tabs:
                    # OWNED (/claim) port: KEEP the pin so a fleet's next
                    # agent-browser command on this same port still hits its
                    # dedicated tab. Mark it idle so the reaper can GC the tab
                    # later if /release is never called.
                    _owned_idle_since[port] = time.time()
                    sys.stderr.write(f"[{port}] Last connection dropped; owned tab pin retained, idle clock started\n")
                    sys.stderr.flush()
                else:
                    # Non-owned port (legacy active-tab / manual-pin): clear as before.
                    old_target = _targets.get(port)
                    _targets[port] = None
                    if old_target:
                        sys.stderr.write(f"[{port}] Last connection dropped, auto-cleared target {old_target[:20] if old_target else ''}\n")
                        sys.stderr.flush()

    return ws_client

async def _reap_stale_connections():
    """Periodically remove closed/dead WebSocket connections from tracking, and
    GC dedicated (/claim-created) tabs left idle past OWNED_TAB_GRACE."""
    while True:
        await asyncio.sleep(30)
        for port in list(_connections.keys()):
            stale = {ws for ws in _connections[port] if ws.closed}
            if stale:
                _connections[port] -= stale
                sys.stderr.write(f"[{port}] Reaped {len(stale)} stale connection(s)\n")
                sys.stderr.flush()
                if not _connections[port]:
                    if port in _owned_tabs:
                        # Owned port: keep pin, start the idle clock for GC.
                        _owned_idle_since.setdefault(port, time.time())
                        sys.stderr.write(f"[{port}] No connections left; owned tab pin retained, idle clock running\n")
                        sys.stderr.flush()
                    else:
                        old_target = _targets.get(port)
                        _targets[port] = None
                        if old_target:
                            sys.stderr.write(f"[{port}] No connections left, auto-cleared target\n")
                            sys.stderr.flush()

        # GC pass: close dedicated tabs that have been idle (no live WS) too long
        # and were never explicitly /release'd (e.g. a fleet worker died).
        now = time.time()
        for port in list(_owned_tabs.keys()):
            if _connections.get(port):
                # Still connected — not idle. Ensure no stale idle marker.
                _owned_idle_since.pop(port, None)
                continue
            if _reservations.get(port, 0) > now:
                # Claimed but the daemon hasn't connected yet — give it time.
                continue
            idle = _owned_idle_since.get(port)
            if idle is None:
                # Owned + no connection + reservation expired but never marked
                # idle (e.g. claimed, tab made, daemon never connected). Start clock.
                _owned_idle_since[port] = now
                continue
            if now - idle > OWNED_TAB_GRACE:
                tab = _owned_tabs.pop(port, None)
                _owned_idle_since.pop(port, None)
                if tab is not None and _targets.get(port) == tab:
                    _targets[port] = None
                sys.stderr.write(f"[{port}] GC: closing dedicated tab {tab[:16] if tab else ''} (idle > {OWNED_TAB_GRACE}s, no /release)\n")
                sys.stderr.flush()
                await _close_tab(tab)


async def main():
    global _tab_create_lock
    _tab_create_lock = asyncio.Lock()
    app = web.Application()
    app.router.add_get('/target', handle_target)
    app.router.add_get('/free', handle_free)
    app.router.add_get('/claim', handle_claim)
    app.router.add_get('/release', handle_release)
    app.router.add_get('/sessions', handle_sessions)
    app.router.add_get('/devtools/browser/{id}', handle_ws)
    app.router.add_get('/devtools/page/{id}', handle_ws)
    app.router.add_get('/{tail:.*}', handle_http)

    runner = web.AppRunner(app)
    await runner.setup()
    # Start background reaper for stale connections
    asyncio.create_task(_reap_stale_connections())

    # Bind all ports in range
    sites = []
    for port in range(BASE_PORT, BASE_PORT + PORT_COUNT):
        try:
            site = web.TCPSite(runner, '127.0.0.1', port)
            await site.start()
            _targets[port] = None
            _connections[port] = set()
            sites.append(site)
            sys.stderr.write(f"Listening on port {port}\n")
            sys.stderr.flush()
        except OSError as e:
            # Port in use — skip it, don't crash the whole proxy
            sys.stderr.write(f"Port {port} unavailable: {e}\n")
            sys.stderr.flush()

    if not sites:
        sys.stderr.write("FATAL: No ports available\n")
        sys.stderr.flush()
        return

    sys.stderr.write(f"Proxy started on {len(sites)} ports ({BASE_PORT}-{BASE_PORT + PORT_COUNT - 1})\n")
    sys.stderr.flush()
    await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
