-- Resolve a binary path that prefers the uv-tool install over Mason's copy.
-- This matters for tools (like mdformat) where the uv install includes plugins
-- (mdformat-gfm) that Mason's pip install does not. NvChad prepends
-- ~/.local/share/nvim/mason/bin to PATH, so we have to bypass it explicitly.
--
-- Provisioned identically across macOS and WSL/Ubuntu via:
--   uv tool install mdformat --with mdformat-gfm
local function resolve_bin(name, candidates)
  for _, candidate in ipairs(candidates) do
    local expanded = vim.fn.expand(candidate)
    if vim.fn.executable(expanded) == 1 then
      return expanded
    end
  end
  -- Last resort: whatever PATH resolves (may hit Mason first).
  return name
end

local mdformat_bin = resolve_bin("mdformat", {
  "~/.local/bin/mdformat",                           -- uv tool install (macOS + linux)
  "~/.local/share/uv/tools/mdformat/bin/mdformat",   -- uv tool direct path
})

local options = {
  notify_on_error = true,

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
      command = mdformat_bin,
      args = { "-" },
      stdin = true,
    },
  },

  format_on_save = {
    timeout_ms = 2000,
    lsp_fallback = true,
  },
}

return options
