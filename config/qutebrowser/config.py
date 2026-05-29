import os
import subprocess

# Load existing autoconfig.yml settings
config.load_autoconfig()

# ── Tabs (sidebar style) ──
c.tabs.position = "left"
c.tabs.width = "15%"
c.tabs.show = "switching"
c.tabs.favicons.show = "always"
c.tabs.title.format = "{index}: {audio}{current_title}"
c.tabs.pinned.shrink = False

# ── UI ──
c.statusbar.show = "in-mode"
c.window.hide_decoration = True
c.scrolling.smooth = True

# ── CDP (Chrome DevTools Protocol) ──
c.qt.args = ['remote-debugging-port=2262']
c.content.headers.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'

# ── Ad blocking ──
c.content.blocking.method = 'both'
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/resource-abuse.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters-2026.txt"
]
c.content.blocking.whitelist = ["*://*.youtube.com/*"]

# ── Content ──
c.content.javascript.enabled = True
c.content.cookies.accept = 'all'

# ── Permission prompt bypass (for agent-browser-driven workflows) ──
# Pre-decide every permission prompt so qutebrowser doesn't pop up blocking
# dialogs during automated testing flows. Override per-domain if a real site
# legitimately needs e.g. mic/camera.
c.content.notifications.enabled = False
c.content.geolocation = False
c.content.media.audio_capture = False
c.content.media.video_capture = False
c.content.media.audio_video_capture = False
c.content.desktop_capture = False
c.content.javascript.alert = False
c.content.javascript.modal_dialog = False
c.content.javascript.prompt = False
c.content.javascript.can_open_tabs_automatically = True
c.content.persistent_storage = True
c.content.register_protocol_handler = False
c.content.autoplay = True

# Downloads — auto-accept, no overwrite prompts
c.downloads.location.prompt = False
c.downloads.location.suggestion = "filename"
c.downloads.remove_finished = 600000  # auto-clear after 10 min

# Tab close + window quit confirmations
c.tabs.last_close = "default-page"
c.confirm_quit = ["never"]

# ── Google OAuth fix (spoof Chrome UA per-domain) ──
_chrome_ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
config.set('content.headers.user_agent', _chrome_ua, 'https://accounts.google.com/*')
config.set('content.headers.user_agent', _chrome_ua, 'https://*.google.com/*')
config.set('content.headers.user_agent', _chrome_ua, 'https://accounts.youtube.com/*')

# ── Night Owl color scheme ──
bg_dark = "#010c18"
fg_light = "#d6deeb"
accent_cyan = "#82aaff"
accent_green = "#addb67"
accent_red = "#ef5350"
selection_bg = "#5f7e97"

c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.policy.images = "never"
c.colors.webpage.preferred_color_scheme = "dark"

c.colors.completion.fg = fg_light
c.colors.completion.odd.bg = bg_dark
c.colors.completion.even.bg = bg_dark
c.colors.completion.category.fg = accent_cyan
c.colors.completion.category.bg = bg_dark
c.colors.completion.category.border.top = bg_dark
c.colors.completion.category.border.bottom = bg_dark
c.colors.completion.item.selected.fg = "#ffffff"
c.colors.completion.item.selected.bg = selection_bg
c.colors.completion.match.fg = accent_green

c.colors.statusbar.normal.fg = fg_light
c.colors.statusbar.normal.bg = bg_dark
c.colors.statusbar.insert.bg = accent_green
c.colors.statusbar.url.success.https.fg = accent_green

c.colors.tabs.bar.bg = bg_dark
c.colors.tabs.odd.fg = fg_light
c.colors.tabs.odd.bg = bg_dark
c.colors.tabs.even.fg = fg_light
c.colors.tabs.even.bg = bg_dark
c.colors.tabs.selected.odd.fg = "#ffffff"
c.colors.tabs.selected.odd.bg = selection_bg
c.colors.tabs.selected.even.fg = "#ffffff"
c.colors.tabs.selected.even.bg = selection_bg

c.colors.hints.fg = "#000000"
c.colors.hints.bg = accent_cyan
c.colors.hints.match.fg = "#ffffff"

# ── Keybindings ──
config.bind('<F1>', 'config-cycle tabs.show never always')
config.bind('<F2>', 'config-cycle colors.webpage.darkmode.enabled true false')
config.bind('B', 'cmd-set-text -s :tab-select')
config.bind('I', 'tab-next')
config.bind('K', 'tab-prev')
config.bind('H', 'back')
config.bind('L', 'forward')
config.bind('<Ctrl-j>', 'tab-move +')
config.bind('<Ctrl-k>', 'tab-move -')
config.bind('<Ctrl-r>', 'config-source')
config.bind('<Mod1-Tab>', 'tab-focus last')

# ── Editor & search ──
c.editor.command = ["alacritty", "-e", "nvim", "{file}"]
c.url.searchengines = {
    "DEFAULT": "https://google.com/search?q={}",
    "g": "https://google.com/search?q={}",
    "y": "https://youtube.com/results?search_query={}",
    "gh": "https://github.com/search?q={}",
    "r": "https://reddit.com/r/{}"
}
c.completion.open_categories = ["searchengines", "quickmarks", "bookmarks", "history", "filesystem"]

# ── elsummariz00r aliases ──
c.aliases['summarize'] = 'spawn --userscript summarize'
c.aliases['resummarize'] = 'spawn --userscript resummarize'
c.aliases['summarize-site'] = 'spawn --userscript summarize-site'
c.aliases['resummarize-site'] = 'spawn --userscript resummarize-site'
c.aliases['discuss'] = 'spawn --userscript discuss'
c.aliases['discuss-new'] = 'spawn --userscript discuss-new'
c.aliases['companion'] = 'spawn --userscript companion'
config.bind('<Ctrl-/>', 'companion')
config.bind('gc', 'devtools-focus')

# ── Session ──
c.auto_save.session = True
c.session.lazy_restore = True

# ── Auto-start: CDP proxy + Companion server ──
import atexit
import signal

_child_procs = []

def _cleanup_children():
    for p in _child_procs:
        try:
            os.killpg(os.getpgid(p.pid), signal.SIGTERM)
        except (ProcessLookupError, OSError):
            pass
    subprocess.run(["pkill", "-f", "agent-browser"], capture_output=True)

atexit.register(_cleanup_children)

import urllib.request

def _is_port_alive(port):
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1)
        return True
    except Exception:
        return False

proxy_path = os.path.expanduser("~/.config/qutebrowser/scripts/qb_proxy.py")
if os.path.exists(proxy_path) and not _is_port_alive(9222):
    subprocess.run(["pkill", "-f", "qb_proxy.py"], capture_output=True)
    _p = subprocess.Popen(["python3", proxy_path],
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL,
                          preexec_fn=os.setpgrp)
    _child_procs.append(_p)

_companion_script = os.path.expanduser("~/claude/Git/repositories/elsummariz00r/src/companion/index.ts")
_bun = os.path.expanduser("~/.bun/bin/bun")
if os.path.exists(_companion_script) and os.path.exists(_bun) and not _is_port_alive(7700):
    subprocess.run(["pkill", "-f", "companion/index.ts"], capture_output=True)
    _log = open("/tmp/els-companion.log", "w")
    # Ensure PATH includes dirs needed by the Claude Agent SDK to find the claude CLI
    _env = os.environ.copy()
    _extra_paths = [
        os.path.expanduser("~/.local/bin"),
        os.path.expanduser("~/.bun/bin"),
        os.path.expanduser("~/.cargo/bin"),
    ]
    _env["PATH"] = ":".join(_extra_paths) + ":" + _env.get("PATH", "/usr/bin")
    _p = subprocess.Popen([_bun, "run", _companion_script],
                          stdout=subprocess.DEVNULL,
                          stderr=_log,
                          env=_env,
                          preexec_fn=os.setpgrp)
    _child_procs.append(_p)

# ── Companion panel (InspectorSplitter injection) ──
from qutebrowser.qt.core import QTimer

_COMPANION_PORT = 7700

def _setup_companion():
    try:
        from qutebrowser.qt.core import QUrl, Qt, QFileSystemWatcher
        from qutebrowser.qt.webenginewidgets import QWebEngineView
        from qutebrowser.misc import objects
        from qutebrowser.utils import objreg

        _panels = {}  # tab_id -> QWebEngineView

        def _get_tab_url(tab):
            try:
                return tab.url().toString()
            except Exception:
                return ""

        def _panel_url(tab):
            tab_url = _get_tab_url(tab).replace("&", "%26")
            tid = tab.tab_id
            return f"http://127.0.0.1:{_COMPANION_PORT}/?tabId=tab-{tid}&url={tab_url}"

        def toggle_for_tab(tab):
            tid = tab.tab_id
            splitter = tab.data.splitter
            if splitter is None:
                return

            if tid in _panels:
                panel = _panels[tid]
                if panel.isVisible():
                    panel.hide()
                    splitter._preferred_size = 0
                    splitter.setSizes([1, 0])
                else:
                    panel.load(QUrl(_panel_url(tab)))
                    panel.show()
                    panel_w = min(380, max(splitter.width() // 3, 200))
                    splitter._preferred_size = panel_w
                    splitter.setSizes([splitter.width() - panel_w, panel_w])
                return

            # Create new companion panel
            panel = QWebEngineView()
            panel.load(QUrl(_panel_url(tab)))
            splitter.addWidget(panel)
            splitter.setOrientation(Qt.Orientation.Horizontal)

            splitter._main_idx = 0
            splitter._inspector_idx = 1
            panel_w = min(380, max(splitter.width() // 3, 200))
            splitter._preferred_size = panel_w
            splitter.setSizes([splitter.width() - panel_w, panel_w])
            _panels[tid] = panel

        # File-based IPC: userscript writes to signal file, QFileSystemWatcher reacts
        signal_file = "/tmp/els-companion-signal"
        with open(signal_file, "w") as fh:
            fh.write("")

        watcher = QFileSystemWatcher([signal_file])

        def on_signal(path):
            try:
                for win_id in list(objreg.window_registry):
                    tb = objreg.get("tabbed-browser", scope="window", window=win_id)
                    tab = tb.widget.currentWidget()
                    if tab:
                        toggle_for_tab(tab)
            except Exception as e:
                import sys
                sys.stderr.write(f"[companion] signal error: {e}\n")
            if path not in watcher.files():
                watcher.addPath(path)

        watcher.fileChanged.connect(on_signal)

        # Keep watcher alive by storing on qapp
        objects.qapp._els_companion_watcher = watcher

    except Exception as e:
        import sys
        sys.stderr.write(f"[companion] setup error: {e}\n")

QTimer.singleShot(0, _setup_companion)
