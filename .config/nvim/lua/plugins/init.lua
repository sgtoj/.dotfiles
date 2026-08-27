return {
  { import = "nvchad.blink.lazyspec" },
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, conf)
      conf.pickers = conf.pickers or {}
      conf.pickers.find_files = conf.pickers.find_files or {}
      conf.pickers.find_files.hidden = true
      conf.pickers.find_files.file_ignore_patterns = { ".git/", "node_modules/", "%.worktrees/" }
      return conf
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      git = {
        timeout = 1000,
      },
    },
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    -- main branch does not support lazy-loading
    lazy = false,
    -- fully override NvChad's spec (which uses archived-branch options)
    event = false,
    cmd = false,
    opts = false,
    build = ":TSUpdate",
    config = function()
      require "configs.treesitter"
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    opts = {
      latex = { enabled = false },
      code = {
        width = "block",
        right_pad = 2,
      },
      win_options = {
        -- no line wrapping while rendered; restored when toggled off
        wrap = { default = true, rendered = false },
      },
    },
  },
  {
    "sphamba/smear-cursor.nvim",
    lazy = false,
    opts = {
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      scroll_buffer_space = true,
      smear_insert_mode = true,
    },
  },
  {
    "github/copilot.vim",
    enabled = false,
    lazy = false,
    config = function()
      vim.g.copilot_node_command = vim.fn.expand "~/.local/share/fnm/aliases/default/bin/node"
      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<C-f>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
      })
    end,
  },
}
