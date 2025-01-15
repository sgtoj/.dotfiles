require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"
local nvlsp = require "nvchad.configs.lspconfig"

local servers = {
  bashls = {},
  cssls = {},
  eslint = {},
  gopls = {},
  html = {},
  pyright = {},
  terraformls = {},
  tilt_ls = {},

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
  opts.on_init = nvlsp.on_init
  opts.on_attach = nvlsp.on_attach
  opts.capabilities = nvlsp.capabilities

  lspconfig[name].setup(opts)
end
