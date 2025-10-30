local home = os.getenv "HOME"
local banner_path = home .. "/.config/nvim/logo/banner.txt"
local banner_cmd = "bat " .. banner_path .. " | lolcat -p 1"

local rosie_path = home .. "/.config/nvim/assets/rosie.png"
local rosie_cmd = "chafa " .. rosie_path .. " --size 60X20 --format symbols --stretch"

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    scratch = { enabled = true },
    bigfile = { enabled = true },
    notifier = { enabled = true },
    dashboard = {
      width = 85,
      pane_gap = 4,
      sections = {
        {
          pane = 1,
          {
            section = "terminal",
            cmd = banner_cmd,
            indent = 2,
            width = 80,
            height = 10,
            ttl = 0.1,
            padding = 1,
          },
          { section = "keys", gap = 1 },
          { section = "startup" },
        },
        {
          pane = 2,
          {
            section = "terminal",
            cmd = rosie_cmd,
            height = 32,
            ttl = 0.1,
          },
        },
      },
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua require('telescope.builtin').find_files()" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "m", desc = "Search Marks", action = ":lua require('telescope.builtin').marks()" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua require('telescope.builtin').oldfiles()" },
          { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    scroll = { enabled = false },
    picker = { enabled = false },
    indent = { enabled = true },
  },
}
