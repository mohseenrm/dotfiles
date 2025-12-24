require("nvchad.configs.lspconfig").defaults()

-- Basic servers - just enable them with default configs
-- Note: pyright is configured separately below with uv venv support
local servers = {
  "html",
  "cssls",
  "tailwindcss",
  "rust_analyzer",
}

for _, server in ipairs(servers) do
  vim.lsp.enable(server)
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

-- Function to find Python interpreter in venv (uv, virtualenv, etc.)
local function get_python_path(workspace)
  local path = util.path

  -- Priority order for finding Python interpreter:
  -- 1. .venv/bin/python (uv default, also used by venv)
  -- 2. venv/bin/python (alternative venv location)
  -- 3. .venv/bin/python3 (explicit python3)
  -- 4. venv/bin/python3 (explicit python3)
  -- 5. System python3/python

  local candidates = {
    path.join(workspace, ".venv", "bin", "python"),
    path.join(workspace, "venv", "bin", "python"),
    path.join(workspace, ".venv", "bin", "python3"),
    path.join(workspace, "venv", "bin", "python3"),
  }

  for _, candidate in ipairs(candidates) do
    if path.exists(candidate) then
      return candidate
    end
  end

  -- Fallback to system python
  return vim.fn.exepath "python3" or vim.fn.exepath "python" or "python"
end

vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  single_file_support = true, -- Allow attaching to single Python files
  root_dir = function(fname)
    -- For monorepos: Look for project-specific markers first, then walk up
    -- This finds the NEAREST marker, which is crucial for monorepos
    -- Priority order:
    -- 1. pyrightconfig.json (project-specific pyright config)
    -- 2. pyproject.toml (Python project root)
    -- 3. setup.py, setup.cfg (legacy Python projects)
    -- 4. requirements.txt (simple Python projects)
    -- 5. Pipfile (pipenv projects)

    -- First try to find Python-specific markers (not .git)
    local python_root =
      util.root_pattern("pyrightconfig.json", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile")(
        fname
      )

    if python_root then
      return python_root
    end

    -- Fallback to .git as last resort
    return util.root_pattern ".git"(fname)
  end,
  on_init = function(client)
    local workspace = client.config.root_dir
    if workspace then
      local python_path = get_python_path(workspace)

      -- Update settings with the detected Python path
      if not client.config.settings.python then
        client.config.settings.python = {}
      end
      client.config.settings.python.pythonPath = python_path

      -- Notify the server of the configuration change
      client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })

      -- Notify user about detected root and venv
      local short_path = workspace:gsub(vim.fn.expand "~", "~")
      if python_path:match "%.venv" or python_path:match "/venv/" then
        local short_python = python_path:gsub(vim.fn.expand "~", "~")
        vim.notify(string.format("Pyright root: %s\nPython: %s", short_path, short_python), vim.log.levels.INFO)
      else
        vim.notify(
          string.format("Pyright root: %s\nUsing system Python: %s", short_path, python_path),
          vim.log.levels.WARN
        )
      end
    end
  end,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly", -- Use "workspace" for full project analysis
        -- typeCheckingMode omitted - will be read from pyrightconfig.json
        -- Additional settings for better monorepo support
        autoImportCompletions = true,
      },
    },
  },
})

vim.lsp.enable "pyright"

-- Autocommand to ensure pyright attaches when navigating to Python files
-- This is especially useful when opening nvim from monorepo root
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function(ev)
    -- Check if pyright is already attached to this buffer
    local clients = vim.lsp.get_clients { bufnr = ev.buf, name = "pyright" }
    if #clients == 0 then
      -- Try to start pyright for this buffer
      vim.lsp.start {
        name = "pyright",
        cmd = { "pyright-langserver", "--stdio" },
        root_dir = (function()
          local util_local = require "lspconfig.util"
          local fname = vim.api.nvim_buf_get_name(ev.buf)
          local python_root = util_local.root_pattern(
            "pyrightconfig.json",
            "pyproject.toml",
            "setup.py",
            "setup.cfg",
            "requirements.txt",
            "Pipfile"
          )(fname)
          if python_root then
            return python_root
          end
          return util_local.root_pattern ".git"(fname)
        end)(),
        on_init = function(client)
          local workspace = client.config.root_dir
          if workspace then
            local python_path = get_python_path(workspace)
            if not client.config.settings.python then
              client.config.settings.python = {}
            end
            client.config.settings.python.pythonPath = python_path
            client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
            local short_path = workspace:gsub(vim.fn.expand "~", "~")
            if python_path:match "%.venv" or python_path:match "/venv/" then
              local short_python = python_path:gsub(vim.fn.expand "~", "~")
              vim.notify(string.format("Pyright root: %s\nPython: %s", short_path, short_python), vim.log.levels.INFO)
            end
          end
        end,
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
              autoImportCompletions = true,
            },
          },
        },
      }
    end
  end,
  desc = "Ensure pyright attaches to Python files in monorepo",
})

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

vim.api.nvim_create_user_command("EnablePyright", function()
  vim.lsp.enable "pyright"
  vim.notify("Enabled pyright", vim.log.levels.INFO)
end, {
  desc = "Enable pyright LSP",
})

vim.api.nvim_create_user_command("DisablePyright", function()
  local clients = vim.lsp.get_clients { name = "pyright" }
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end
  vim.notify("Disabled pyright", vim.log.levels.INFO)
end, {
  desc = "Disable pyright LSP",
})
