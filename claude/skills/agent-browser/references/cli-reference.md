# agent-browser v0.22.3 — full verified CLI surface

Verified against `agent-browser --help` + binary strings on 2026-07-02
(binary: `~/.local/bin/agent-browser`, third-party Rust crate — NEVER patch it).
SKILL.md §5 carries the task-oriented subset; this file is the complete surface.

## Invocation basics

```
agent-browser <command> [args] [options]
```

- Daemon-based: the first command cold-starts a per-session daemon; it persists between
  commands until `agent-browser close`. Chain with `&&` in one shell call.
- Connect to our proxy stack with `AGENT_BROWSER_CDP=<port>` env (confirmed honored by the
  binary although ABSENT from `--help`) or the documented `--cdp <port>` flag
  (`agent-browser --cdp 9222 snapshot`).
- Default action timeout: **25000ms** (`AGENT_BROWSER_DEFAULT_TIMEOUT`). A command that
  "hangs ~25s then errors" hit this timeout — see SKILL.md PB-3.

## Core commands

| Command | Notes |
|---|---|
| `open <url>` | Navigate current target tab. HTTPS through the proxy can hit `ERR_CERT_COMMON_NAME_INVALID` → PB-8 (`/claim?url=`). |
| `click <sel>` / `dblclick <sel>` | Selector or `@ref`. |
| `type <sel> <text>` | APPENDS without clearing. |
| `fill <sel> <text>` | Clear then type — use for replacing field content. |
| `press <key>` | `Enter`, `Tab`, `Control+a`, … |
| `keyboard type <text>` | Real keystrokes, no selector. |
| `keyboard inserttext <text>` | Insert without key events. |
| `hover <sel>` / `focus <sel>` | Radix comboboxes: `focus @ref` + `press Enter` to open. |
| `check <sel>` / `uncheck <sel>` | Checkboxes. |
| `select <sel> <val...>` | Dropdown option(s). |
| `drag <src> <dst>` | Drag and drop. |
| `upload <sel> <files...>` | File inputs. |
| `download <sel> <path>` | Download by clicking element. |
| `scroll <dir> [px]` / `scrollintoview <sel>` | up/down/left/right. |
| `wait <sel\|ms>` | Also `--url <u>`, `--load <state>` (`networkidle`!), `--fn <js>`, `--text <t>`, `--download` — all confirmed in binary strings. |
| `screenshot [path]` | `--full` (DPR defect risk, SKILL §9.2), `--annotate` (numbered labels + legend). |
| `pdf <path>` | Save page as PDF. |
| `snapshot` | Accessibility tree with refs. Options below. |
| `eval <js>` | Run JavaScript in the page. |
| `connect <port\|url>` | Connect daemon via CDP — the /claim handshake step. |
| `close` | Kill the daemon (teardown or forced re-attach after a pin change). |
| `back` / `forward` / `reload` | Navigation. |

## Snapshot options

```
-i, --interactive     only interactive elements (recommended)
-c, --compact         remove empty structural elements
-d, --depth <n>       limit tree depth
-s, --selector <sel>  scope to CSS selector
--json                machine-readable envelope: {"data":{"snapshot": "..."}}
```

Best default: `agent-browser snapshot -i -c --json`. Refs are VOLATILE (SKILL HR-10).

## Get / Is / Find

```
get text|html|value|attr <name>|title|url|count|box|styles|cdp-url [selector]
is  visible|enabled|checked <selector>
find role|text|label|placeholder|alt|title|testid|first|last|nth <value> <action> [text]
     e.g. find role button click --name "Submit"
```

## Mouse primitives

```
mouse move <x> <y> · mouse down [btn] · mouse up [btn] · mouse wheel <dy> [dx]
```

## Browser settings (`set`)

```
set viewport <w> <h>        (3rd arg deviceScaleFactor observed in use; forcing 1 before a
                             --full shot is the UNVERIFIED DPR-defect prevention — the trim
                             recipe is the guarantee, SKILL §9.2)
set device <name>
set geo <lat> <lng>
set offline [on|off]
set headers <json>
set credentials <user> <pass>
set media [dark|light] [reduced-motion]   (exists in 0.22.3; for color-scheme use the
                                           AGENT_BROWSER_COLOR_SCHEME env — field-verified
                                           reliable path, SKILL §9.4)
```

## Network

```
network route <url> [--abort|--body <json>]   mock/block a request pattern
network unroute [url]
network requests [--clear] [--filter <pattern>] [--type <types>]   --type xhr,fetch,document confirmed
network har start|stop [path]                 full capture for QA evidence
```

## Storage / cookies

```
cookies [get|set|clear]    set supports --url --domain --path --httpOnly --secure --sameSite --expires
storage local|session      web storage
```

Never dump cookies of authenticated apps into reports (SKILL HR-15).

## Tabs

```
tab            list
tab <n>        switch
tab close [n]  close
tab new <url>  ⚠ UNRELIABLE IN THIS ENV — field-verified exit 144 (atlas smoke test,
               2026-06). Not re-tested since (re-testing drives the live browser). Use
               /claim?url= as the canonical new-tab path (SKILL HR-9). If you try it
               anyway, CHECK THE EXIT CODE.
```

## Diff

```
diff snapshot                       current vs last snapshot
diff screenshot --baseline <img>    visual diff vs baseline
diff url <u1> <u2>                  compare two pages
```

## Debug / recording

```
trace start|stop [path]      Chrome DevTools trace
profiler start|stop [path]   CPU profile
record start <path> [url]    WebM video recording · record stop
console [--clear]            console logs
errors [--clear]             page errors
highlight <sel>              flash an element
inspect                      open DevTools for the active page
clipboard read|write|copy|paste [text]
```

## Streaming

```
stream enable [--port <n>] · stream disable · stream status
(AGENT_BROWSER_STREAM_PORT env)
```

## Batch

```
batch [--bail]     commands from stdin as JSON array of string arrays
```
Default continue-all; `--bail` stops on first error. One daemon round-trip, per-step
machine-readable results (SKILL R-4).

## Auth vault — SECURITY CAUTION

```
auth save <name> [--url --username --password/--password-stdin]
auth login <name> · auth list · auth show <name> · auth delete <name>
```

This stores credentials on disk. **NEVER `auth save` Christopher's real credentials without
his explicit instruction** (SKILL HR-15). Prefer `--password-stdin` over argv (argv leaks to
process lists) when authorized. `AGENT_BROWSER_ENCRYPTION_KEY` (64-char hex) enables
AES-256-GCM state encryption; `AGENT_BROWSER_STATE_EXPIRE_DAYS` (default 30) auto-expires
saved states.

## Confirmation / sessions / setup

```
confirm <id> / deny <id>    approve/deny a pending gated action
session                     show current session name
session list                list active sessions
install [--with-deps]       download browser binaries (NOT needed here — we attach to qutebrowser)
upgrade                     upgrade the binary (do not run casually; the skill is version-pinned to 0.22.3 behavior)
```

## Authentication / identity options

```
--profile <path>            persistent profile (AGENT_BROWSER_PROFILE)
--session-name <name>       auto-save/restore cookies+localStorage (AGENT_BROWSER_SESSION_NAME)
--state <path>              load saved auth state JSON (AGENT_BROWSER_STATE)
--auto-connect              attach to a running Chrome (AGENT_BROWSER_AUTO_CONNECT) — not our path; we use --cdp/env
--headers <json>            origin-scoped HTTP headers (e.g. Authorization)
```

## General options (selected — full list in --help)

```
--session <name>            isolated session (AGENT_BROWSER_SESSION) — UNIQUE per fleet worker (SKILL HR-7)
--cdp <port>                connect via CDP — flag twin of AGENT_BROWSER_CDP env
--color-scheme <scheme>     dark|light|no-preference (AGENT_BROWSER_COLOR_SCHEME — SKILL HR-16)
--json                      JSON output (AGENT_BROWSER_JSON)
--annotate                  annotated screenshot (AGENT_BROWSER_ANNOTATE)
--screenshot-dir <path>     default output dir (AGENT_BROWSER_SCREENSHOT_DIR)
--screenshot-format <fmt>   png|jpeg (AGENT_BROWSER_SCREENSHOT_FORMAT)
--screenshot-quality <n>    JPEG 0-100 (AGENT_BROWSER_SCREENSHOT_QUALITY)
--download-path <path>      (AGENT_BROWSER_DOWNLOAD_PATH)
--user-agent <ua>           (AGENT_BROWSER_USER_AGENT)
--proxy / --proxy-bypass    (AGENT_BROWSER_PROXY / _PROXY_BYPASS, std HTTP(S)_PROXY/NO_PROXY fallbacks)
--ignore-https-errors       (AGENT_BROWSER_IGNORE_HTTPS_ERRORS) — does NOT fix the proxy cert error (that's a name-mismatch at the proxy layer; use /claim?url=, PB-8)
--allow-file-access         file:// access (Chromium only)
--args <args>               browser launch args — only relevant for launched browsers, not our attach flow
--engine chrome|lightpanda  (AGENT_BROWSER_ENGINE)
--headed                    show window — irrelevant when attaching to qutebrowser
--allowed-domains <list>    navigation allow-list (AGENT_BROWSER_ALLOWED_DOMAINS)
--action-policy <path>      action policy JSON (AGENT_BROWSER_ACTION_POLICY)
--confirm-actions <list>    categories requiring confirmation (AGENT_BROWSER_CONFIRM_ACTIONS)
--max-output <chars>        truncate page output (AGENT_BROWSER_MAX_OUTPUT)
--content-boundaries        wrap page output in markers (AGENT_BROWSER_CONTENT_BOUNDARIES)
--debug                     debug output
-p, --provider <name>       ios|browserbase|kernel|browseruse|browserless (iOS needs Xcode+Appium — not this box)
--config <path>             explicit config file (errors if missing/invalid)
```

## Environment variables (beyond the flag twins above)

```
AGENT_BROWSER_CDP              CDP port — binary-verified, ABSENT from --help. Our primary knob.
AGENT_BROWSER_DEFAULT_TIMEOUT  action timeout ms (default 25000)
AGENT_BROWSER_IDLE_TIMEOUT_MS  auto-shutdown daemon after N ms idle (disabled by default)
AGENT_BROWSER_SESSION          session name (default "default") — unique per fleet worker
AGENT_BROWSER_ENCRYPTION_KEY   64-char hex AES-256-GCM key for saved state
AGENT_BROWSER_STATE_EXPIRE_DAYS auto-delete saved states older than N days (default 30)
AGENT_BROWSER_STREAM_PORT      runtime WebSocket streaming port
AGENT_BROWSER_IOS_DEVICE / _IOS_UDID   iOS provider defaults
```

## Config-file precedence (lowest → highest)

1. `~/.agent-browser/config.json` — user defaults (**does not exist on this box** — no
   hidden overrides in play, verified 2026-07-02)
2. `./agent-browser.json` — project overrides
3. Environment variables
4. CLI flags

Boolean flags accept explicit `true/false` to override config (`--headed false`).
Extensions from user + project configs are merged.

## Screenshot post-processing snippets (companions to SKILL §9)

DPR trim (ImageMagick, `/usr/bin/convert` + `/usr/bin/magick` both present):
```bash
convert in.png -bordercolor white -border 1 -trim +repage out.png
```

Pillow alternative:
```python
from PIL import Image, ImageChops
im = Image.open("in.png").convert("RGB")
white = Image.new("RGB", im.size, (255, 255, 255))
bbox = ImageChops.difference(im, white).convert("L").point(lambda p: 255 if p > 8 else 0).getbbox()
im.crop(bbox).save("out.png")
```

Brightness gate:
```bash
convert shot.png -background white -flatten -colorspace Gray -format '%[fx:mean]' info:
# light page ≈0.95 · dark frame ≈0.10 · re-shoot anything under ~0.6 on a light theme
```

Detection heuristic for the DPR defect: a `--full` canvas roughly 1.667x wider than a
viewport shot of the same page (or than the known display logical width) is the defect.
Apply the trim ONLY to `--full` outputs (SKILL HR-12).
