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
      conf.pickers.find_files.file_ignore_patterns = { ".git/", "node_modules/" }
      return conf
    end,
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      auto_install = true,
      ensure_installed = {
        "bash",
        "css",
        "editorconfig",
        "go",
        "gomod",
        "gosum",
        "hcl",
        "html",
        "javascript",
        "json",
        "jsonc",
        "make",
        "lua",
        "python",
        "scss",
        "sql",
        "terraform",
        "toml",
        "tmux",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      },
      highlight = {
        disable = {
          "dockerfile", -- broken
        },
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
    lazy = false,
    config = function()
      vim.g.copilot_no_tab_map = true
      vim.keymap.set("i", "<C-y>", 'copilot#Accept("\\<CR>")', {
        expr = true,
        replace_keycodes = false,
      })
    end,
  },
}
