local options = {
  formatters_by_ft = {
    go = { "goimports", "gofmt" },
    lua = { "stylua" },
    python = { "black" },
    sh = { "shfmt" },
    terraform = { "terraform_fmt" },
    javascript = { "deno_fmt", "prettier" },
    typescript = { "deno_fmt", "prettier" },
    javascriptreact = { "deno_fmt", "prettier" },
    typescriptreact = { "deno_fmt", "prettier" },
  },

  formatters = {
    black = { prepend_args = { "--fast" } },
    deno_fmt = { command = "deno", args = { "fmt", "-" } },
  },

  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

return options
