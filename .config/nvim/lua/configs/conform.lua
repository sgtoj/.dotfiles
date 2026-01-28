local options = {
  formatters_by_ft = {
    go = { "goimports", "gofmt" },
    lua = { "stylua" },
    markdown = { "mdformat" },
    ["markdown.mdx"] = { "mdformat" },
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
    mdformat = {
      command = "mdformat",
      args = { "$FILENAME" },
      stdin = false,
    },
  },

  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
}

return options
