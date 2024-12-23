local wezterm = require("wezterm")
local act = wezterm.action

local is_dwn <const> = wezterm.target_triple:find("darwin") ~= nil
local is_nix <const> = wezterm.target_triple:find("linux") ~= nil
local is_win <const> = wezterm.target_triple:find("windows") ~= nil

local config = wezterm.config_builder()

config.font = wezterm.font("Hack Nerd Font Mono")
config.font_size = 15

-- config.color_scheme = "tokyonight"
config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = "Cobalt2"

config.enable_tab_bar = false
config.window_background_opacity = 1
config.window_decorations = "RESIZE"
config.window_padding = { left = "8px", right = "8px", top = "8px", bottom = "8px" }
config.macos_window_background_blur = 10

wezterm.on("resize-to-screen", function(window, _)
  local screens = wezterm.gui.screens()
  local active_screen = screens.active
  if is_win then
    active_screen.height = active_screen.height - 100
  end
  window:set_position(active_screen.x, active_screen.y)
  window:set_inner_size(active_screen.width, active_screen.height)
end)

config.disable_default_key_bindings = false
config.keys = {
  { key = "LeftArrow", mods = "OPT", action = act.SendString("\u{1b}b") },
  { key = "RightArrow", mods = "OPT", action = act.SendString("\u{1b}f") },
  { key = "F10", mods = "NONE", action = act.EmitEvent("resize-to-screen") },
}

if is_win then
  config.default_domain = "WSL:Ubuntu-24.04"
end

return config
