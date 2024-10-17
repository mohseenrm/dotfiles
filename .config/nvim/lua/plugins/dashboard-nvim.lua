return {
  "nvimdev/dashboard-nvim",
  event = "VimEnter",
  opts = function()
    local lolcat = vim.fn.executable("lolcat") == 1
    local opts = {
      theme = "hyper",
      hide = {
        statusline = false,
      },
      preview = lolcat and {
        command = "lolcat -p 1",
        file_path = vim.fn.stdpath("config") .. "/logo/banner.txt",
        file_width = 100,
        file_height = 10,
      },
      config = {
        header = (not lolcat) and vim.fn.readfile(vim.fn.stdpath("config") .. "/logo/banner.txt"),
        footer = function()
          local stats = require("lazy").stats()
          local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
          return { "⚡ Neovim loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms" }
        end,
        shortcut = {
          { desc = "󰊳 Update", group = "@property", action = "Lazy update", key = "u" },
          {
            icon = " ",
            icon_hl = "@variable",
            desc = "Files",
            group = "Label",
            action = "Telescope find_files",
            key = "f",
          },
          {
            desc = " Apps",
            group = "DiagnosticHint",
            action = "Telescope app",
            key = "a",
          },
          {
            desc = " dotfiles",
            group = "Number",
            action = "Telescope dotfiles",
            key = "d",
          },
        },
      },
      group = { "DashboardHeader" },
    }
    return opts
  end,
  dependencies = { { "nvim-tree/nvim-web-devicons" } },
}
