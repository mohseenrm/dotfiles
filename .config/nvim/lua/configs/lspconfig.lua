require("nvchad.configs.lspconfig").defaults()

-- Basic servers - just enable them with default configs
local servers = {
  "html",
  "cssls",
  "tailwindcss",
  "rust_analyzer", 
  "pyright",
}

for _, server in ipairs(servers) do
  vim.lsp.enable(server)
end

-- Configure vtsls with custom settings
vim.lsp.config('vtsls', {
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
    if new_root_dir and util.root_pattern("deno.json", "deno.jsonc")(new_root_dir) then
      new_config.enabled = false
    end
  end,
})
vim.lsp.enable('vtsls')

-- Configure denols with custom settings
vim.lsp.config('denols', {
  root_dir = require("lspconfig").util.root_pattern("deno.json", "deno.jsonc"),
  single_file_support = false,
  settings = {
    deno = {
      enable = true,
      lint = true,
      unstable = true,
    },
  },
})
vim.lsp.enable('denols')
