local options = {
  formatters_by_ft = {
    -- css = { "prettier" },
    -- html = { "prettier" },
    go = { "goimports", "gofmt" },
    lua = { "stylua" },
    python = { "black" },
    sh = { "shfmt" },
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
