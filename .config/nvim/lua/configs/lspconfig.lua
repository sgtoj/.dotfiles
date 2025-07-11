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
