require("nvchad.configs.lspconfig").defaults()

local servers = {
  cssls = {},
  -- denols = {},
  eslint = {},
  gopls = {},
  html = {},
  pyright = {},
  terraformls = {},
  tilt_ls = {},
  ts_ls = {},

  bashls = {
    on_attach = function(client, bufnr)
      local filename = vim.api.nvim_buf_get_name(bufnr)
      -- Exclude .env and .env.* files from bashls
      if filename:match("%.env$") or filename:match("%.env%.") then
        vim.lsp.buf_detach_client(bufnr, client.id)
        return false
      end
    end,
    settings = {
      bashIde = {
        shellcheckArguments = "-S warning",
      },
    },
  },

  dockerls = {
    settings = {
      docker = {
        languageserver = {
          formatter = { ignoreMultilineInstructions = true },
        },
      },
    },
  },
}

for name, opts in pairs(servers) do
  vim.lsp.config(name, opts)
  vim.lsp.enable(name)
end
