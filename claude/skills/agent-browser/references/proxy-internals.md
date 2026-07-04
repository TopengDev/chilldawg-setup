# qb_proxy.py internals — endpoint semantics from source

Source: `~/.config/qutebrowser/scripts/qb_proxy.py` (34,779 bytes, 705 lines, mtime
2026-06-22 13:41 — the LIVE multi-port + per-port TAB ISOLATION revision). Distilled from
the source docstrings on 2026-07-02; re-verify against the file if it has a newer mtime.

## Constants (source of the SKILL timing table)

```python
TARGET_PORT = 2262          # qutebrowser's real CDP
BASE_PORT = 9222            # first proxy port
PORT_COUNT = 15             # 9222-9236 (source comment: 9222-9231 agents, 9232-9236 companion)
COMPANION_PORT = 7700       # elsummariz00r panel — filtered from all target lists
RESERVATION_TTL = 30.0      # default /claim window (allows slow daemon cold-start under load)
OWNED_TAB_GRACE = 600.0     # idle seconds before the reaper GCs an un-/release'd dedicated tab
QB_BIN = $QUTEBROWSER_BIN or /usr/bin/qutebrowser
```

State maps (all keyed by port): `_targets` (routing pin), `_connections` (live WS set),
`_reservations` (claim expiry), `_owned_tabs` (proxy-created dedicated tab),
`_owned_idle_since` (GC clock). `_tab_create_lock` serializes dedicated-tab creation so the
before/after id-diff is race-safe under concurrent claims.

## HTTP endpoints (available on EVERY proxy port)

### `/target` — per-port pin (GET)

- `?id=<tabId>` — pin by CDP id. **NO VALIDATION**: any string is accepted and stored. This
  is the mechanical root of the phantom-pin failure (SKILL HR-3/HR-4): a truncated id never
  matches in `get_target_tab`, and the WS path `/devtools/page/<bad-id>` on 2262 gives a
  target that evaluates `about:blank`.
- `?url=<substring>` — case-insensitive substring match over page URLs (companion filtered);
  404 `{"error": "No tab matching '<s>'"}` if none. Response includes matched title/url.
- `?clear` — revert to active-tab default.
- bare — show `{"target": <id or "active tab (default)">, "title", "url", "port"}`.

Scoping: `_request_port(request)` — the pin belongs to the port the request ARRIVED on.
Pinning 9223 does nothing for a daemon on 9222 (SKILL HR-5).

Fallback semantics (`get_target_tab`): pinned id present in the live page list → that tab;
pinned id NOT found (closed tab, bogus id) → **silent fallback to pages[0]** (active tab) at
the `Target.getTargets` level. So a stale pin can also silently drive the user's active tab
— another reason for the HR-4 verify step.

### `/claim` — atomic reserve + dedicated tab (GET)

Params: `url` (default `about:blank`), `ttl` (default 30.0; 400 on non-numeric), `from`
(scan start, clamped to ≥9222 — note bare `/claim` starts AT 9222 and can claim it, hence
SKILL HR-7's `?from=9223` convention), `notab` (reserve only, no tab).

Sequence per free port (`_is_port_available` = no live WS AND no unexpired reservation):
1. **Reserve BEFORE any await** — parallel claims can never pick the same port.
2. `notab=1` → return `{"port", "ttl"}` (legacy: caller pins manually / active-tab fallback).
3. Else `_create_dedicated_tab(url)`: under the creation lock, snapshot page ids →
   `qutebrowser --target tab-bg-silent <url>` (background, no focus theft; subprocess capped
   at 15s) → poll up to ~8s (40x0.2s) for the new id, preferring the id whose URL matches.
4. Success → record in `_owned_tabs[port]` + pin `_targets[port]` → return
   `{"port", "ttl", "tab": "<32-char id>"}`.
5. Tab-create failure → port still returned but
   `{"port", "ttl", "tab": null, "warning": "tab-create-failed"}` — **NOT isolated**
   (active-tab fallback). Callers must check for the warning (SKILL §6.3).
6. Pool exhausted → 503 `{"error": "No free ports"}`.

Reservation is consumed by the first WS connect on the port, or expires after TTL.

### `/release` — clean teardown (GET)

`?port=N` or bare (releases the arriving port). Pops `_owned_tabs`/`_owned_idle_since`/
`_reservations`, clears the pin if it pointed at the owned tab, closes the tab via
`Target.closeTarget` on 2262 (`_close_tab`, **id-scoped — the proxy only ever closes tabs
recorded in `_owned_tabs`**, so bcas/fitest/user tabs are untouchable). Idempotent (closing
a gone id is a no-op). Returns `{"port", "released_tab", "closed"}`.

### `/free` — non-reserving probe (GET)

`?from=` supported. Returns the first available port WITHOUT reserving it — **racy by
design** (two parallel callers can get the same answer). Allocation must use `/claim`.

### `/sessions` — fleet visibility (GET)

`{"ports": "9222-9236", "active": {<port>: {"target", "connections", "dedicated_tab"?,
"idle_secs"?, "title"?, "url"?}}}` — only ports with a target, owned tab, or live
connections appear. Live-verified shape 2026-07-02.

### Everything else — transparent HTTP forward to 2262, with rewrites

- `/json/version`: `Browser` field forced to `"Chrome/134.0.0.0"` (agent-browser refuses
  non-Chrome identities); `webSocketDebuggerUrl` port rewritten 2262 → arriving port.
- `/json`, `/json/list`: companion (7700) targets filtered out; each target's
  `webSocketDebuggerUrl` rewritten to the arriving port.
- Anything else: body passed through. Upstream connection failure → 502 with the error text
  (this is where `Cannot connect to host 127.0.0.1:2262` surfaces when qutebrowser's CDP is
  dead — the PB-2 signature).

## WebSocket path (`/devtools/browser/{id}`, `/devtools/page/{id}`)

- Client WS: `autoping=True, heartbeat=15.0` — ping every 15s, close on missed pong.
- On connect: tracked in `_connections[port]`; cancels the port's `_owned_idle_since` clock;
  consumes any pending `/claim` reservation.
- Bidirectional forward to `ws://127.0.0.1:2262<same path>` with these **Target.* mocks**
  intercepted client→target (qutebrowser doesn't implement them):
  - `Target.createBrowserContext` → fake `browserContextId` (`fake-context-<port>`)
  - `Target.getBrowserContexts` → the fake context
  - `Target.setDiscoverTargets`, `Target.setAutoAttach` → empty success
  - `Target.getTargets` → **ONLY the port's target tab** (pin or active-tab fallback) as a
    single `targetInfo`. This is what makes one-port-one-tab work.
  - `Target.createTarget` → opens the URL via `qutebrowser --target tab-bg-silent`, polls
    up to 10s (20x0.5s) for the new id; timeout → CDP error `-32000 "Tab open timed out"`.
    (This mock is what `tab new` rides; the exit-144 failure is on the agent-browser side.)
- Target→client: `Browser.getVersion` responses with product `qutebrowser*` rewritten to
  `Chrome/134.0.0.0`.
- **Disconnect finally-block (the pin lifecycle):** when the LAST connection on a port drops —
  - owned (`/claim`) port → **pin retained**, `_owned_idle_since[port]` clock starts
    ("owned tab pin retained, idle clock started" in the log);
  - non-owned port → **pin auto-cleared** ("auto-cleared target").

## Reaper (`_reap_stale_connections`, every 30s)

1. Drops closed WS objects from `_connections`; applies the same owned-retain /
   non-owned-clear pin logic when a port empties.
2. GC pass over `_owned_tabs`: skip ports with live connections (and clear any stale idle
   marker) or unexpired reservations; start the idle clock for claimed-but-never-connected
   ports; **close the dedicated tab once idle > 600s** ("GC: closing dedicated tab … no
   /release" in the log). The GC exists for dead workers — `/release` is the contract.

## Startup / binding

Binds 127.0.0.1 on each of 9222-9236 individually; a port already in use is SKIPPED with a
log line (graceful per-port bind) instead of crashing. Logs
`Proxy started on 15 ports (9222-9236)` on success; `FATAL: No ports available` if none
bind. Proxy log lines print tab ids TRUNCATED to 16 chars (`tab_id[:16]`) — never copy an id
out of the proxy log (SKILL HR-3).

## qb-proxy-doctor.sh (systemd --user watchdog)

- `qb-proxy-doctor.timer`: every 2 min (enabled since 2026-06-27; docs link →
  `~/claude/notes/adopt-qbproxy-2026-05-30/`). Health-check it with
  `systemctl --user status qb-proxy-doctor.timer` (expect `active (waiting)`).
- Health check: `curl -sf -m3 http://127.0.0.1:9222/json/version` ONLY. Healthy → silent
  no-op (exit 0, no log spam). Down → 3x2s re-checks before acting.
- Acts ONLY when qutebrowser is running (`pgrep -f '(^|/)qutebrowser'`); qb down → SKIP
  (config.py will start the proxy at next qb launch; no orphan proxies).
- Restart path: **anchored** `pkill -f '/qb_proxy\.py($|[[:space:]])'` (deliberately does
  not substring-match the `.new`/`.bak` sibling files), `setsid python3 <proxy> >>
  ~/.cache/qb_proxy/proxy.log 2>&1 &`, verify after 2s.
- Logs: `~/.cache/qb_proxy/doctor.log` (its actions), `~/.cache/qb_proxy/proxy.log` (proxy
  stderr, append-only across restarts). Exit 0 = healthy/no-op/fixed, 1 = restart attempted
  but still down.
- **THE FAIL-LOOP SIGNATURE (live-observed 2026-07-02 18:32-18:51):** doctor.log repeating
  `DRIFT: port 9222 down … restarting proxy` → `FAIL: proxy still down after restart
  attempt` every 2 min, while proxy.log shows all 15 ports binding fine plus hundreds of
  `Cannot connect to host 127.0.0.1:2262`. Meaning: **qutebrowser's CDP is dead; the proxy
  is innocent; the doctor is kill/restarting a healthy proxy on loop.** Correct response:
  SKILL PB-2 — verify with a direct `curl -m3 localhost:2262/json/list`, then escalate to
  Christopher for a human-gated qutebrowser `:restart`. Do not modify the doctor script.

## config.py integration (`~/.config/qutebrowser/config.py`)

- Line 21: `c.qt.args = ['remote-debugging-port=2262']` — this is what turns on
  qutebrowser's CDP.
- Lines ~186-193: at qutebrowser launch, if 9222 is dead → `pkill -f qb_proxy.py` then
  `Popen(["python3", <proxy_path>])`. **Launch-time only** — a mid-session proxy death is
  the doctor's (or your PB-1 restart's) job. Note config.py's own pkill is the unanchored
  variant; the doctor's anchored regex is the pattern to copy for manual restarts (HR-17).
- Line ~305: the IPC `:command` focus-theft suppression monkey-patch (qb upstream issue
  #5094) — the dependency that lets qb-shoot send IPC commands without raising the window.
- Also auto-starts the elsummariz00r companion (port 7700) — the reason the proxy filters
  companion targets.

## Canonical manual restart (proxy ONLY — never qutebrowser)

```bash
pkill -f '/qb_proxy\.py($|[[:space:]])'; sleep 1
setsid python3 ~/.config/qutebrowser/scripts/qb_proxy.py >> ~/.cache/qb_proxy/proxy.log 2>&1 &
sleep 2 && curl -s -m3 http://localhost:9222/json/version
```

(The proxy header's own one-liner logs to `/tmp/qb_proxy.log`; prefer the doctor-equivalent
above so all diagnostics stay in `~/.cache/qb_proxy/proxy.log`. Never `> /dev/null` — that
destroys the PB-2 signature evidence.)
