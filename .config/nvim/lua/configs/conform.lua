local options = {
  formatters_by_ft = {
    -- css = { "prettier" },
    -- html = { "prettier" },
    lua = { "stylua" },
    python = { "black" },
    terraform = { "terraform_fmt" },
  },

  formatters = {
    black = { prepend_args = { "--fast" } },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

return options
