-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "catppuccin",
  hl_add = {
    TelescopePathFilter = { fg = "yellow", bold = true },
  },

  -- hl_override = {
  -- 	Comment = { italic = true },
  -- 	["@comment"] = { italic = true },
  -- },
}

M.cheatsheet = {
  excluded_groups = { "help" },
  theme = "simple",
}

M.ui = {
  statusline = {
    -- right-side segments (cwd/cursor) consume the "left" glyph (u+e0b6,
    -- round cap as in the stock default style); the "right" glyph is unused
    -- because the left-side modules are overridden below to be flat
    separator_style = { left = "\u{e0b6}", right = "" },
    theme = "default",
    -- flat left-side segments: no separator/staircase cells after mode/file
    modules = {
      mode = function()
        local utils = require "nvchad.stl.utils"
        if not utils.is_activewin() then
          return ""
        end
        local modes = utils.modes
        local m = vim.api.nvim_get_mode().mode
        return "%#St_" .. modes[m][2] .. "Mode#  " .. modes[m][1] .. " "
      end,
      file = function()
        local utils = require "nvchad.stl.utils"
        local x = utils.file()
        return "%#St_file# " .. x[1] .. " " .. x[2] .. " "
      end,
    },
  },
  telescope = {
    style = "bordered",
  },
}

return M
