require "nvchad.options"

local g = vim.g
local o = vim.o

g.markdown_fenced_languages = {
  "ts=typescript",
}

o.relativenumber = true

-- Filetype detection for .env files
vim.filetype.add {
  filename = {
    [".env"] = "dotenv",
  },
  pattern = {
    ["%.env%..*"] = "dotenv",
  },
}
