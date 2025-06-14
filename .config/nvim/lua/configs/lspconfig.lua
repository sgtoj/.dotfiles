require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"
local nvlsp = require "nvchad.configs.lspconfig"

local servers = {
  cssls = {},
  eslint = {},
  gopls = {},
  html = {},
  pyright = {},
  terraformls = {},
  tilt_ls = {},

  bashls = {
    settings = {
      bashIde = {
        shellcheckArguments = "-S warning",
      },
    },
  },
  denols = {
    root_dir = lspconfig.util.root_pattern("deno.json", "deno.jsonc"),
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
  ts_ls = {
    root_dir = lspconfig.util.root_pattern "package.json",
    single_file_support = false,
  },
}

for name, opts in pairs(servers) do
  vim.lsp.config(name, opts)
  vim.lsp.enable(name)
end
