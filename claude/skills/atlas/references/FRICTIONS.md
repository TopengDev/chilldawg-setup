# /atlas friction encyclopedia (extended context for SKILL.md 13.3)

SKILL.md 13.3 carries the compact must-know rules + exact recovery commands; this file carries the full context, evidence pointers, and complete snippets. Numbering matches 13.3. Evidence lines quote the dossier's own journals (`dossiers/pulse/capture-log*.jsonl`, `manifest.partial.inventory.json skill_friction_log[]`), which are the primary sources.

---

## 1. `tab new` exits 144

`agent-browser tab new <url>` fails (exit 144) in this qutebrowser+proxy environment. The working navigation pattern is claim-then-connect-then-open:

```bash
# claim a port from the multi-port proxy (reservation TTL ~30s: connect promptly)
PORT=$(curl -s "http://localhost:9222/claim?from=9223" | jq -r .port)   # during a capture run only; from=9223 leaves 9222 (the interactive active-tab port) alone: bare /claim can allocate 9222 and hijack it (agent-browser HR-7)
agent-browser connect $PORT
agent-browser open https://app.pulse.aenoxa.com/dashboard
agent-browser wait --load networkidle
```

The June-22 workers also exported `AGENT_BROWSER_CDP=$PORT` alongside. Checked against agent-browser 0.22.3 `--help` (2026-07-02): that env var is NOT in the documented env list; the documented equivalents are the sticky `connect <port>` (per session daemon) and the per-call global flag `--cdp <port>`. Keep the export if you like (harmless), but `connect` + a unique `AGENT_BROWSER_SESSION` are the load-bearing parts.

## 2. Parallel isolation triple: unique session + claimed port + release

Three requirements, ALL mandatory per worker, or workers clobber each other's tabs even through the multi-port proxy:

```bash
export AGENT_BROWSER_SESSION="atlas${PORT}"     # unique per worker; the default shared daemon re-clobbers otherwise
# ... capture ...
curl -s "http://localhost:9222/release?port=${PORT}"   # teardown (/free is a non-reserving, racy probe: never a teardown or allocation path)
```

Persist to an env file and `source` it at the top of every Bash step (the shell does NOT persist env between tool calls):

```bash
cat > /tmp/atlas-env-$PORT <<EOF
export AGENT_BROWSER_SESSION=atlas$PORT
export AGENT_BROWSER_COLOR_SCHEME=light
export ATLAS_PORT=$PORT
EOF
source /tmp/atlas-env-$PORT
```

Evidence: capture-log.inventory.jsonl `{"action":"connect","port":9224,"session":"atlas9224",...}`.

## 3. CDP screenshot timeout/blank: the verified escalation chain

Run the rungs IN ORDER; each rung resolved a real June-22 hang:

1. Retry once after 2-3s.
2. `~/.config/qutebrowser/scripts/qb-shoot <url-slug> <path>` : native Qt render path, bypasses CDP entirely. **NOT on PATH** (verified `which qb-shoot` fails, 2026-07-02): the absolute path is mandatory. The POS worker lost time to `command not found` at exactly the moment CDP was already failing; its journal: `{"type":"friction","category":"CDP screenshot","note":"...qb-shoot fallback used for all 3 screenshots. qb-shoot requires full path (not in PATH)."}`.
3. If a modal/animation is suspected (screenshot HANGS rather than times out): inject the animation kill (item 10 below), re-shoot.
4. Release the port, claim a fresh one, reconnect, re-shoot. Evidence: `{"action":"error","message":"Port 9224 screenshot timeout after modal interaction","fix":"release port + claim 9226"}` and the staff log's 9225-to-9224 re-claim.

Never silently skip a screenshot; if all four rungs fail, `screenshot: null` + a `gaps[]` entry.

## 4. Dark-mode screenshots after a browser restart

CDP color-scheme emulation can come up DARK after a qutebrowser restart while the visible browser is light. The env var is the field-verified fix; audit every batch because the downscaled inline preview LIES (a dark page with white form fields looks light when shrunk):

```bash
export AGENT_BROWSER_COLOR_SCHEME=light        # in the env file (item 2)
convert shot.png -background white -flatten -colorspace Gray -format '%[fx:mean]' info:
# ~0.95 = light page over white. ~0.10 = dark frame. < 0.6 = re-shoot before accepting the batch.
```

`agent-browser set media light` exists in 0.22.3 per `--help` but is UNVERIFIED in this env; do not swap it in for the env var without proving it.

## 5. Claim-tab reaping + qutebrowser crash recovery

- The dedicated `/claim` tab is reaped after ~600s idle. Long analysis pause = expect to re-claim.
- On `Connection refused` / `All CDP discovery methods failed`: re-`/claim`, reconnect, re-verify the session.
- `qb-proxy-doctor.sh` (in `~/.config/qutebrowser/scripts/`) restarts the PROXY only when qutebrowser is UP. If qutebrowser itself died, relaunching it is an action on the user's live desktop: **flag the human, never relaunch the GUI from a worker** (its config.py auto-restarts the proxy on launch).
- NEVER touch `qb_proxy.py` (live, load-bearing for fitest + captures) or `qb_proxy.py.new` (OBSOLETE pre-tab-isolation history, 2026-05-30: never promote it, agent-browser HR-14), and never restart either from a capture run (SKILL 12.1).

## 6. Mid-run auth expiry resets MORE than the session

A token timeout logs you out mid-crawl; a fresh login lands on the EN locale + a tenant selector. Recovery is a 4-step, not a 1-step: re-login, RE-SELECT the tenant, RESET the locale to the dossier's locale, then VERIFY one known surface renders as previously captured before continuing. Skipping the locale reset poisons every subsequent `locale_observed` + screenshot. (Cookie jar survives a browser RESTART; it does not survive token expiry.)

## 7. Radix/React Select + HTML5 validation

- Radix Select comboboxes: the `role=combobox` node is NOT the click target (an inner `generic [onclick]` is), so `@eN` click and JS click both no-op. Keyboard works: `agent-browser focus @ref` then `agent-browser press Enter`. Arrow keys + Enter select an option.
- Radix TAB lists are normally clickable via their `@eN` refs.
- Native HTML5 required-field tooltips ("Please fill out this field") do NOT persist into a screenshot. Capture the form state and record the constraint in the surface JSON instead of chasing the tooltip pixel.

## 8. POS-style flow gotchas (Pulse-specific, generalizable pattern)

- `/terminal` location selection does NOT persist across full reloads: re-select after EVERY reload.
- The "Terbuka" (open) order state is reached by ENTERING the payment flow then abandoning it, which confirms the order server-side. Recall does not produce it. (This is also why an abandoned payment is a MUTATION on a real tenant: order #13 stayed Terbuka.)
- Partial cash payment is blocked in the UI (disabled "short by Rp X" button): a detected-but-not-observable state on any tenant.

## 9. HiDPI `--full` DPR double-application (deep dive)

On fractional display scaling (166.7%, device-scale-factor 1.667) `agent-browser screenshot --full` sizes the canvas at page-dimensions x DPR but rasterizes the page at 1x: the real UI lands in the TOP-LEFT of an oversized blank canvas (measured: 4800x2928 canvas holding 2635x1757 of content).

- **The guarantee is the post-trim** (SKILL 13.3 item 9 keeps the command inline): `convert in.png -bordercolor white -border 1 -trim +repage out.png`. The 1px white border makes `-trim` behave when content touches an edge. Near no-op on a correct capture. Apply ONLY to `--full` outputs: a legitimately small-content state (a centered gate modal) must not be cropped by a blanket trim.
- Python alternative: `PIL.ImageChops.difference(im, white_bg).convert("L").point(lambda p: 255 if p>8 else 0).getbbox()` then `im.crop(bbox)`.
- Fixing it at capture time is UNVERIFIED, not absent: 0.22.3 `set --help` shows `set viewport <w> <h> [scale]` (scale = deviceScaleFactor; verified 2026-07-02), but forcing scale 1 before a `--full` shot is unproven as prevention in this qutebrowser+proxy env (agent-browser SKILL §9.2): the trim stays the guarantee.
- Detection: canvas width ~1.667x the viewport shot of the same page.
- Related memory: `reference_agent_browser_full_dpr_defect`.

## 10. Native OS device picker = permanent CDP screenshot block

Clicking "Tambah Printer" (Web Bluetooth/USB chooser) opened a NATIVE OS picker; from that moment `Page.captureScreenshot` hung PERMANENTLY on that tab; no retry, no qb-shoot via that tab, nothing recovers it except closing the tab. Evidence: `{"event":"blocked","target":"settings-printer-struk@tambah-printer-native-dialog","reason":"native OS Bluetooth/USB device picker blocks CDP captureScreenshot; tab closed and port re-claimed"}` + the manifest `blocked[]` entry.

Rule: enumerate the picker button from the a11y snapshot; do NOT click it, or if exploration requires the click, accept in advance that the state is screenshot-blocked: log `blocked(reason)`, close the tab, `/release` + `/claim` fresh, reconnect. NEVER attempt a screenshot with a native picker open.

The animation-kill injection (used when a WEB modal's animation/opacity blocks screenshots; distinct from the native-picker case, which no JS can fix):

```bash
agent-browser eval "const s=document.createElement('style');s.textContent='*,*::before,*::after{animation:none!important;transition:none!important}';document.head.appendChild(s)"
```

(Canonical form of the verified fix; the staff journal records "disable CSS animations via JS injection, works for subsequent screenshots".)

## 11. screenshot + eval in one Bash call exits 144

`agent-browser screenshot x.png && agent-browser eval "..."` in a SINGLE Bash tool call exited 144 (inventory worker). Split into two Bash calls, always. (General chaining of non-screenshot commands with `&&` is fine and documented by agent-browser itself.)

## 12. `find role <role> name <x>` is not a thing

`agent-browser find role button name Cancel` fails with `Unknown subaction 'name'`. The grammar (0.22.3 `--help`): `find <locator> <value> <action> [text]` with locators `role|text|label|placeholder|alt|title|testid|first|last|nth`; there is no positional name subaction after the locator. Fix: `snapshot -i -c`, find the ref whose accessible name matches, `click @ref` in the same step (N10). For unique labels, `find text "Cancel" click` also works. Note: a `--name` FLAG does exist in 0.22.3 `--help` (`agent-browser find role button click --name Submit`) but is UNVERIFIED in this env; if a run proves it, log a `friction` event and fold it back here.

## 13. Date spinbuttons: a11y fill does not reach the real input

Filling Month/Day/Year spinbutton refs updates the widget visually but React never sees a value change on the underlying `<input>`. The verified fix drives the native setter and dispatches real events:

```bash
agent-browser eval "const el=document.querySelector('input[type=date]');
const set=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
set.call(el,'2026-06-22');
el.dispatchEvent(new Event('input',{bubbles:true}));
el.dispatchEvent(new Event('change',{bubbles:true}))"
```

(One line in practice. For non-date React inputs that ignore `fill`, the same pattern applies with the matching selector.) Evidence: staff journal friction event, 2026-06-22T07:23:30.

## 14. File-upload wizards

Bulk-import steps 2-4 (Map Columns / Review / Import) require a file chosen via the native OS picker; not capturable via the CDP path in this env. Logged `blocked`, honestly listed in `coverage.state.unobserved`. Do not burn time attempting them. `agent-browser upload <sel> <files...>` exists in 0.22.3 `--help` and MIGHT bypass the native picker; it is UNVERIFIED in this qutebrowser+proxy environment: if a future run proves it works, log a `friction` event and upgrade SKILL 13.3 item 14.

## 15. Radix portals + DIV-buttons

- Portal-rendered modal content (`radix-_r_t_` containers) is missed by `document.querySelectorAll` run from the main document scope in the obvious way; target `document.getElementById('radix-<id>')` explicitly when driving portal content via JS.
- Product cards are DIVs in the DOM that the a11y snapshot reports as `role=button`. Trust the SNAPSHOT for classification (Section 6) and the DOM for JS targeting; they legitimately disagree.
- Evidence: POS worker journal, 2026-06-22T15:08.
