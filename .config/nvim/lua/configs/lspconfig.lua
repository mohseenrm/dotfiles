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
})

-- Configure denols with custom settings
vim.lsp.config('denols', {
  single_file_support = false,
  settings = {
    deno = {
      enable = true,
      lint = true,
      unstable = true,
      suggest = {
        imports = {
          hosts = {
            ["https://deno.land"] = true,
          },
        },
      },
    },
  },
})

-- Enable both LSPs
vim.lsp.enable('vtsls')
vim.lsp.enable('denols')

-- Commands to disable LSPs
vim.api.nvim_create_user_command('DisableDeno', function()
  local clients = vim.lsp.get_clients({ name = "denols" })
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
  vim.notify("Disabled denols", vim.log.levels.INFO)
end, {
  desc = 'Disable denols LSP'
})

vim.api.nvim_create_user_command('DisableVtsls', function()
  local clients = vim.lsp.get_clients({ name = "vtsls" })
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
  vim.notify("Disabled vtsls", vim.log.levels.INFO)
end, {
  desc = 'Disable vtsls LSP'
})

vim.api.nvim_create_user_command('EnableDeno', function()
  vim.lsp.enable('denols')
  vim.notify("Enabled denols", vim.log.levels.INFO)
end, {
  desc = 'Enable denols LSP'
})

vim.api.nvim_create_user_command('EnableVtsls', function()
  vim.lsp.enable('vtsls')
  vim.notify("Enabled vtsls", vim.log.levels.INFO)
end, {
  desc = 'Enable vtsls LSP'
})
