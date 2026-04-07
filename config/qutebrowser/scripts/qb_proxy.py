import asyncio
import json
import os
import aiohttp
from aiohttp import web
import sys

TARGET_PORT = 2262
PROXY_PORT = 9222
QB_BIN = os.environ.get(
    "QUTEBROWSER_BIN",
    "/usr/bin/qutebrowser",
)

# Target tab override: set via /target?id=<tabId> or /target?url=<substring>
# When None, defaults to the active tab (index 0).
_target_tab_id = None


async def get_target_tab():
    """Fetch the target tab — either the pinned target or the active tab."""
    async with aiohttp.ClientSession() as session:
        async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as res:
            tabs = await res.json()
            pages = [t for t in tabs if t.get("type") == "page"
                     and "localhost:7700" not in t.get("url", "")
                     and "127.0.0.1:7700" not in t.get("url", "")]
            if not pages:
                return None
            if _target_tab_id:
                for p in pages:
                    if p["id"] == _target_tab_id:
                        return p
            return pages[0]
    return None


async def handle_target(request):
    """Set or clear the target tab for agent-browser.

    GET /target?id=<tabId>       — pin a specific tab by CDP id
    GET /target?url=<substring>  — pin the first tab whose URL contains substring
    GET /target?clear            — revert to active tab (index 0)
    GET /target                  — show current target
    """
    global _target_tab_id
    tab_id = request.query.get("id")
    url_match = request.query.get("url")
    clear = "clear" in request.query

    if clear:
        _target_tab_id = None
        return web.json_response({"target": "active tab (default)"})

    if tab_id:
        _target_tab_id = tab_id
        return web.json_response({"target": tab_id})

    if url_match:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as res:
                tabs = await res.json()
                for t in tabs:
                    if t.get("type") == "page" and url_match.lower() in t.get("url", "").lower():
                        _target_tab_id = t["id"]
                        return web.json_response({
                            "target": t["id"],
                            "title": t.get("title", ""),
                            "url": t.get("url", ""),
                        })
        return web.json_response({"error": f"No tab matching '{url_match}'"}, status=404)

    # Show current target
    tab = await get_target_tab()
    return web.json_response({
        "target": _target_tab_id or "active tab (default)",
        "title": tab.get("title", "") if tab else "",
        "url": tab.get("url", "") if tab else "",
    })


async def handle_http(request):
    path = request.path.rstrip('/')
    url_path = path if path else '/'
    sys.stderr.write(f"HTTP {request.method} {url_path}\n")
    sys.stderr.flush()

    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"http://127.0.0.1:{TARGET_PORT}{url_path}") as res:
                if path == '/json/version':
                    data = await res.json()
                    data['Browser'] = "Chrome/134.0.0.0"
                    ws_url = data['webSocketDebuggerUrl']
                    data['webSocketDebuggerUrl'] = ws_url.replace(str(TARGET_PORT), str(PROXY_PORT))
                    return web.json_response(data)
                elif path in ['/json', '/json/list']:
                    data = await res.json()
                    for item in data:
                        if 'webSocketDebuggerUrl' in item:
                            item['webSocketDebuggerUrl'] = item['webSocketDebuggerUrl'].replace(str(TARGET_PORT), str(PROXY_PORT))
                    return web.json_response(data)
                else:
                    body = await res.read()
                    return web.Response(body=body, content_type=res.content_type)
        except Exception as e:
            sys.stderr.write(f"HTTP Error: {e}\n")
            sys.stderr.flush()
            return web.Response(text=str(e), status=502)

async def handle_ws(request):
    sys.stderr.write(f"WS Connection: {request.path}\n")
    sys.stderr.flush()
    ws_client = web.WebSocketResponse(autoclose=False, autoping=False)
    await ws_client.prepare(request)

    target_url = f"ws://127.0.0.1:{TARGET_PORT}{request.path}"

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
                                    sys.stderr.write("Mocking Target.createBrowserContext\n")
                                    sys.stderr.flush()
                                    await ws_client.send_str(json.dumps({
                                        "id": data['id'],
                                        "result": {"browserContextId": "fake-context-1"}
                                    }))
                                    continue
                                elif method == 'Target.getBrowserContexts':
                                    await ws_client.send_str(json.dumps({
                                        "id": data['id'],
                                        "result": {"browserContextIds": ["fake-context-1"]}
                                    }))
                                    continue
                                elif method == 'Target.setDiscoverTargets':
                                    sys.stderr.write("Mocking Target.setDiscoverTargets\n")
                                    sys.stderr.flush()
                                    await ws_client.send_str(json.dumps({
                                        "id": data['id'],
                                        "result": {}
                                    }))
                                    continue
                                elif method == 'Target.getTargets':
                                    tab = await get_target_tab()
                                    if tab:
                                        target_info = {
                                            "targetId": tab["id"],
                                            "type": "page",
                                            "title": tab.get("title", ""),
                                            "url": tab.get("url", ""),
                                            "attached": False,
                                            "browserContextId": "fake-context-1",
                                        }
                                        sys.stderr.write(f"Mocking Target.getTargets -> {tab['title'][:40]}\n")
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
                                    sys.stderr.write(f"Mocking Target.createTarget -> {url[:60]}\n")
                                    sys.stderr.flush()
                                    async with aiohttp.ClientSession() as s:
                                        async with s.get(f"http://127.0.0.1:{TARGET_PORT}/json/list") as r:
                                            before = {t["id"] for t in await r.json() if t.get("type") == "page"}
                                    proc = await asyncio.create_subprocess_exec(
                                        QB_BIN, "--target", "tab-bg-silent", url,
                                        stdout=asyncio.subprocess.DEVNULL,
                                        stderr=asyncio.subprocess.DEVNULL,
                                    )
                                    await proc.wait()
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
                    sys.stderr.write(f"Forward to target error: {e}\n")
                    sys.stderr.flush()

            async def forward_to_client():
                try:
                    async for msg in ws_target:
                        if msg.type == aiohttp.WSMsgType.TEXT:
                            if not ws_client.closed:
                                try:
                                    data = json.loads(msg.data)
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
                    sys.stderr.write(f"Forward to client error: {e}\n")
                    sys.stderr.flush()

            await asyncio.gather(forward_to_target(), forward_to_client())

    return ws_client

async def main():
    app = web.Application()
    app.router.add_get('/target', handle_target)
    app.router.add_get('/devtools/browser/{id}', handle_ws)
    app.router.add_get('/devtools/page/{id}', handle_ws)
    app.router.add_get('/{tail:.*}', handle_http)

    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '127.0.0.1', PROXY_PORT)
    await site.start()
    sys.stderr.write(f"Proxy started on port {PROXY_PORT}\n")
    sys.stderr.flush()
    await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
