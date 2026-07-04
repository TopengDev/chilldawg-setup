# Proxy stack upgrade history + future-cutover template

## Attribution (keep this credit)

The hardening layer (multi-port proxy, qb-shoot, qb-proxy-doctor) was adapted from
**elpabl0's private `sebat-duls` repo (github.com/alkautsarf), with permission, 2026-05-30**,
and ported macOS → Linux (IPC socket discovery → `$XDG_RUNTIME_DIR/qutebrowser`;
`QUTEBROWSER_BIN` default → `/usr/bin/qutebrowser`). qb-proxy-doctor is a Linux-native fresh
build inspired by the repo (his symlink-doctor.sh was a macOS Homebrew checker, not a proxy
watchdog).

## Timeline

| Date | Event |
|---|---|
| 2026-05-30 | Single-port proxy live. Multi-port version staged as `qb_proxy.py.new` + `.README` (not hot-swapped — the live proxy was load-bearing for fitest). qb-shoot + doctor adopted. |
| 2026-06-22 ~12:36 | Cut-over began: live single-port backed up as `qb_proxy.py.single-port.bak` (13,220 B). |
| 2026-06-22 ~13:37 | Multi-port promoted, then immediately superseded: the promoted file was backed up as `qb_proxy.py.pre-tabiso.bak` (23,143 B — byte-identical size to `.new`, proving the README's cut-over procedure was executed). |
| 2026-06-22 13:41 | **TAB ISOLATION revision written as the LIVE `qb_proxy.py`** (34,779 B): `/claim` creates a dedicated background tab per port, owned-pin persistence, `/release`, 600s reaper, creation lock. This is the current architecture (SKILL §2). |
| 2026-06-27 | qb-proxy-doctor.timer enabled as the standing watchdog. |

## ⚠ qb_proxy.py.new is OBSOLETE — DO NOT PROMOTE

`~/.config/qutebrowser/scripts/qb_proxy.py.new` (23,143 B, 2026-05-30) is **OLDER than the
live proxy** (2026-06-22). It is the pre-tab-isolation multi-port version, retained as
history only. Promoting it over `qb_proxy.py` would **destroy the tab-isolation upgrade**
(dedicated tabs, owned-pin persistence, `/release` teardown). Same for both `.bak` files —
they are rollback artifacts, not upgrade candidates. SKILL HR-14. The old skill text
"multi-port is staged, NOT yet live" is stale — do not cite it as truth. (atlas §12.1
carried a copy of it plus a "NEWER staged `qb_proxy.py.new`" mischaracterization that
contradicted HR-14; both were corrected 2026-07-02 per cutover step 5 — `.new` is obsolete
pre-tab-isolation history, not newer.)

File inventory (`~/.config/qutebrowser/scripts/`):

| File | Bytes | Date | Status |
|---|---|---|---|
| `qb_proxy.py` | 34,779 | 2026-06-22 | **LIVE** (multi-port + tab isolation) |
| `qb_proxy.py.new` | 23,143 | 2026-05-30 | OBSOLETE — pre-tabiso multi-port |
| `qb_proxy.py.new.README` | 2,578 | 2026-05-30 | Historical cut-over doc (executed 2026-06-22) |
| `qb_proxy.py.pre-tabiso.bak` | 23,143 | 2026-06-22 | Rollback artifact |
| `qb_proxy.py.single-port.bak` | 13,220 | 2026-06-22 | Rollback artifact (original single-port) |
| `qb-shoot` | 2,883 | 2026-05-30 | LIVE (native screenshot fallback) |
| `qb-proxy-doctor.sh` | 3,285 | 2026-06-11 | LIVE (systemd watchdog) |

## Template cutover checklist for any FUTURE staged proxy revision

The live proxy is load-bearing (fitest browses through it) — never hot-swap. When a new
revision is staged:

1. **Stage** as `qb_proxy.py.next` + a README describing the delta. Do NOT reuse the `.new`
   suffix (it's burned as "the obsolete one").
2. **Back up live**: `cp qb_proxy.py qb_proxy.py.<desc>.bak` with a dated, descriptive name.
3. **Swap during a deliberate qutebrowser restart** (Toper-initiated — HR-2 means agents
   never trigger this): `cp qb_proxy.py.next qb_proxy.py`, then the anchored pkill; config.py
   auto-starts the new proxy at qb launch.
4. **Smoke-test immediately** (all read-only):
   `curl -s localhost:9222/json/version` (Chrome/134 spoof) ·
   `curl -s localhost:9222/sessions | python3 -m json.tool` ·
   one throwaway `/claim?from=9223` → connect → `get url` → `/release` → `/sessions` clean.
5. **Update the agent-browser skill THE SAME DAY** — the 2026-06-22 cut-over went
   undocumented for 10 days and left the skill teaching a dead architecture (the exact
   failure this file exists to prevent). Also sweep consumer skills (atlas §12.1/13.2,
   ui-test, e2e) for stale architecture claims.
6. **Mark the previous stage file OBSOLETE** in this history table.
