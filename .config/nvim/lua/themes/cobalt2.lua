 
local M = {}

M.base_30 = {
  white = "#ffffff",
  black = "#193549", -- official background
  darker_black = "#0a2e4b", -- line highlight from official theme
  black2 = "#0d3a58", -- selection background (slightly lighter than line highlight)
  one_bg = "#224566", -- a slightly lighter shade than the background
  one_bg2 = "#2a4f72", -- incrementally lighter blue shade
  one_bg3 = "#30587e",
  grey = "#4b647f", -- a medium grey-blue
  grey_fg = "#607b96", -- lighter grey-blue
  grey_fg2 = "#6a86a3",
  light_grey = "#7490af",
  red = "#ff0000", -- a pure red, used occasionally
  baby_pink = "#ff9da4", -- a lighter pink than the official constant pink
  pink = "#ff628c", -- official pink (constants)
  line = "#0a2e4b", -- line highlight from official theme
  green = "#29e8a8", -- teal/green accent from official theme
  vibrant_green = "#00ffbb", -- a more vibrant green if needed
  nord_blue = "#9effff", -- classes/support (cyan) from official theme
  blue = "#0088ff", -- comments from official theme
  seablue = "#00aaff",
  yellow = "#ffee00", -- strings from official theme
  sun = "#ffdf00", -- a slightly different yellow variant
  purple = "#a074c4", -- purple from official theme
  dark_purple = "#7f5ea0",
  teal = "#29e8a8", -- same as green accent
  orange = "#ff9d00", -- keywords/storage from official theme
  cyan = "#9effff", -- same as classes/support
  statusline_bg = "#0d3a58", -- using selection bg as a statusline base
  lightbg = "#224566",
  pmenu_bg = "#ff9d00", -- popup menu highlight using keyword color
  folder_bg = "#0088ff" -- folder icons: using comment color (blue)
}

M.base_16 = {
  base00 = "#193549", -- main background
  base01 = "#0a2e4b", -- line highlight
  base02 = "#0d3a58", -- selection background
  base03 = "#0088ff", -- comments
  base04 = "#9effff", -- class/support (light cyan)
  base05 = "#ffffff", -- main foreground
  base06 = "#ffee00", -- strings
  base07 = "#ff9d00", -- keywords/storage
  base08 = "#ff628c", -- constants/pink
  base09 = "#ff0000", -- red accent
  base0A = "#a074c4", -- purple
  base0B = "#29e8a8", -- green/teal accent
  base0C = "#ff00a0", -- an extra accent (magenta-ish)
  base0D = "#ffffff", -- (functions/operators)
  base0E = "#ff9d00", -- keywords again (for variation)
  base0F = "#ffee00"  -- strings or special highlights
}


M.polish_hl = {
  defaults = {
    Comment = {
      fg = "#0088ff",
      italic = true,
    },
    String = {
      fg = "#ffee00"
    },
    Keyword = {
      fg = "#ff9d00",
      bold = true,
    },
    Function = {
      fg = "#ffffff",
      bold = true
    },
    Type = {
      fg = "#a074c4"
    },
  },

  treesitter = {
    ["@variable"] = { fg = "#9effff" },
    ["@property"] = { fg = "#9effff" },
    ["@parameter"] = { fg = "#9effff" },
    ["@field"] = { fg = "#9effff" },

    ["@keyword"] = { fg = "#ff9d00" },
    ["@keyword.function"] = { fg = "#ff9d00" },
    ["@keyword.operator"] = { fg = "#ff9d00" },

    ["@string"] = { fg = "#ffee00" },
    ["@string.regex"] = { fg = "#ff628c" }, -- highlight regex strings as pink for variety

    ["@type"] = { fg = "#a074c4" },
    ["@type.builtin"] = { fg = "#a074c4", italic = true },

    ["@function"] = { fg = "#ffffff" },
    ["@function.builtin"] = { fg = "#ffffff", italic = true },
    ["@function.call"] = { fg = "#ffffff" },
    ["@method"] = { fg = "#ffffff" },
  },
}

M.type = "dark"

M = require("base46").override_theme(M, "cobalt2")

return M
