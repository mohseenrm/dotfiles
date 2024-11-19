local home = os.getenv("HOME")
local banner_path = home .. "/.config/nvim/logo/banner.txt"
local banner_cmd = "cat " .. banner_path .. " | lolcat"

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
            indent = 8,
            width = 75,
            height = 10,
          },
          { section = "keys", gap = 1 },
          { section = "startup" },
        },
        {
          pane = 2,
          {
            section = "terminal",
            cmd = rosie_cmd,
            height = 30,
          },
        },
      },
    },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
  },
}
