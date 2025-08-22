require("nvchad.configs.lspconfig").defaults()

local lspconfig = require("lspconfig")

local servers = {
  "html",
  "cssls",
  "rust_analyzer",
}

for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup({})
end

lspconfig.vtsls.setup({
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
})

-- read :h vim.lsp.config for changing options of lsp servers
