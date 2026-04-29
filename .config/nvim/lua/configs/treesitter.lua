-- nvim-treesitter `main` branch config (post-archive rewrite).
--
-- Key differences vs. the old `master` branch API:
--   * No `ensure_installed` option to `setup`; install parsers imperatively.
--   * No `highlight`/`indent`/`fold` tables; enable each via autocmd/ftplugin.
--   * Requires tree-sitter-cli (>= 0.26.1) and a C compiler on PATH.

pcall(function()
  dofile(vim.g.base46_cache .. "syntax")
  dofile(vim.g.base46_cache .. "treesitter")
end)

local ts = require "nvim-treesitter"

ts.setup {
  install_dir = vim.fn.stdpath "data" .. "/site",
}

-- Parsers to keep installed. Add/remove freely; existing parsers aren't removed.
local parsers = {
  "bash",
  "css",
  "diff",
  "dockerfile",
  "editorconfig",
  "gitcommit",
  "go",
  "gomod",
  "gosum",
  "hcl",
  "html",
  "javascript",
  "json",
  "lua",
  "luadoc",
  "make",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "query",
  "regex",
  "scss",
  "sql",
  "svelte",
  "terraform",
  "tmux",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

-- Install missing parsers asynchronously; no-op if already installed.
ts.install(parsers)

-- Map filetypes that don't share a name with a parser.
vim.treesitter.language.register("json", { "jsonc" })

-- Filetypes we want treesitter highlighting on. Kept explicit (no auto_install).
-- Maps parser name -> filetype(s). If nil, parser name == filetype.
local highlight_filetypes = {
  bash = { "sh", "bash", "zsh" },
  dockerfile = "dockerfile",
  gitcommit = "gitcommit",
  go = "go",
  gomod = "gomod",
  gosum = "gosum",
  hcl = { "hcl", "terraform" },
  html = "html",
  javascript = { "javascript", "javascriptreact" },
  -- `jsonc` filetype is handled by the `json` parser (registered below).
  json = { "json", "jsonc" },
  lua = "lua",
  make = "make",
  markdown = "markdown",
  python = "python",
  scss = "scss",
  sql = "sql",
  svelte = "svelte",
  terraform = "terraform",
  toml = "toml",
  tsx = "typescriptreact",
  typescript = "typescript",
  vim = "vim",
  vimdoc = "help",
  yaml = "yaml",
  css = "css",
  diff = "diff",
}

local ft_list = {}
for _, ft in pairs(highlight_filetypes) do
  if type(ft) == "table" then
    vim.list_extend(ft_list, ft)
  else
    table.insert(ft_list, ft)
  end
end

local group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = ft_list,
  callback = function(args)
    -- Start highlighting (noop if parser missing).
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- Folds and indent are intentionally NOT enabled globally.
--
-- Treesitter folds default to `foldlevel=0`, which collapses everything on
-- open (e.g. a markdown buffer folds into a single heading). Treesitter
-- indent is still marked experimental upstream and regresses several
-- filetypes. Neither was enabled on the old `master` branch either, so
-- leaving them off preserves the prior behavior.
--
-- To opt-in per filetype, add an `after/ftplugin/<ft>.lua` with:
--   vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
--   vim.wo[0][0].foldmethod = "expr"
--   vim.wo[0][0].foldlevel = 99  -- open everything by default
--   vim.bo[0].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
