-- ~/.wezterm.lua
local wezterm = require("wezterm")
local act = wezterm.action
local config = {}

-- disable wayland
config.enable_wayland = true

-- UI
--config.color_scheme = "Builtin Solarized Dark"
config.font = wezterm.font_with_fallback({ "JetBrains Mono", "Noto Color Emoji" })
config.font_size = 9.0
config.window_padding = { left = 6, right = 6, top = 4, bottom = 4 }
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.adjust_window_size_when_changing_font_size = false
config.scrollback_lines = 10000

-- Quality of life
config.audible_bell = "Disabled"
config.default_cursor_style = "BlinkingBar"
config.check_for_updates = false

-- Splits & tabs (no tmux required)
config.keys = {
  { key = "d", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "D", mods = "CTRL|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "LeftArrow",  mods = "ALT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "ALT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow",    mods = "ALT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow",  mods = "ALT", action = act.ActivatePaneDirection("Down") },
}

return config

