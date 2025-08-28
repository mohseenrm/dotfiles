require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"

local servers = {
  "html",
  "cssls",
  "tailwindcss",
  "vscode-css-language-server",
  "rust_analyzer",
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {}
end

lspconfig.vtsls.setup {
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  on_new_config = function(new_config, new_root_dir)
    local util = require("lspconfig").util
    -- Don't start vtsls if we're in a Deno project
    if new_root_dir and util.root_pattern("deno.json", "deno.jsonc")(new_root_dir) then
      new_config.enabled = false
    end
  end,
}

lspconfig.denols.setup {
  root_dir = require("lspconfig").util.root_pattern("deno.json", "deno.jsonc"),
  single_file_support = false,
  settings = {
    deno = {
      enable = true,
      lint = true,
      unstable = true,
    },
  },
}

-- read :h vim.lsp.config for changing options of lsp servers
