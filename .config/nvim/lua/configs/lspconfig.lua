require("nvchad.configs.lspconfig").defaults()

-- Basic servers - just enable them with default configs
-- Note: pyright is configured separately below with uv venv support
local servers = {
  "html",
  "cssls",
  "tailwindcss",
  "rust_analyzer",
  "black",
  "harper_ls",
}

for _, server in ipairs(servers) do
  if server ~= "harper_ls" and server ~= "pyright" then
    vim.lsp.enable(server)
  end
end

-- Configure vtsls with custom settings
vim.lsp.config("vtsls", {
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
})

-- Configure Pyright with uv venv support using vim.lsp.config
local util = require "lspconfig.util"

-- Function to find Python interpreter in uv venv
local function get_python_path(workspace)
  local path = util.path

  -- Check for uv venv in .venv
  local venv = path.join(workspace, ".venv", "bin", "python")
  if path.exists(venv) then
    return venv
  end

  -- Check for uv venv in venv
  venv = path.join(workspace, "venv", "bin", "python")
  if path.exists(venv) then
    return venv
  end

  -- Fallback to system python
  return vim.fn.exepath "python3" or vim.fn.exepath "python" or "python"
end

vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_dir = function(fname)
    -- Look for uv project markers first, then fallback to common Python project markers
    return util.root_pattern("pyproject.toml", "uv.lock", "setup.py", "setup.cfg", "requirements.txt", ".git")(fname)
  end,
  on_init = function(client)
    local workspace = client.config.root_dir
    if workspace then
      local python_path = get_python_path(workspace)
      client.config.settings.python.pythonPath = python_path
      client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
      -- Notify that we've detected a venv
      if python_path:match "%.venv" or python_path:match "/venv/" then
        vim.notify("Pyright using: " .. python_path, vim.log.levels.INFO)
      end
    end
  end,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
        typeCheckingMode = "basic",
      },
    },
  },
})

vim.lsp.enable "pyright"

-- Configure denols with custom settings
vim.lsp.config("denols", {
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
vim.lsp.enable "vtsls"
vim.lsp.enable "denols"

-- Commands to disable LSPs
vim.api.nvim_create_user_command("DisableDeno", function()
  local clients = vim.lsp.get_clients { name = "denols" }
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
  vim.notify("Disabled denols", vim.log.levels.INFO)
end, {
  desc = "Disable denols LSP",
})

vim.api.nvim_create_user_command("DisableVtsls", function()
  local clients = vim.lsp.get_clients { name = "vtsls" }
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
  vim.notify("Disabled vtsls", vim.log.levels.INFO)
end, {
  desc = "Disable vtsls LSP",
})

vim.api.nvim_create_user_command("DisableHarper", function()
  local clients = vim.lsp.get_clients { name = "harper_ls" }
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
  vim.notify("Disabled Harper", vim.log.levels.INFO)
end, {
  desc = "Disable Harper LSP",
})

vim.api.nvim_create_user_command("EnableDeno", function()
  vim.lsp.enable "denols"
  vim.notify("Enabled denols", vim.log.levels.INFO)
end, {
  desc = "Enable denols LSP",
})

vim.api.nvim_create_user_command("EnableVtsls", function()
  vim.lsp.enable "vtsls"
  vim.notify("Enabled vtsls", vim.log.levels.INFO)
end, {
  desc = "Enable vtsls LSP",
})

vim.api.nvim_create_user_command("EnableHarper", function()
  vim.lsp.enable "harper_ls"
  vim.notify("Enabled harper_ls", vim.log.levels.INFO)
end, {
  desc = "Enable Harper LSP",
})
