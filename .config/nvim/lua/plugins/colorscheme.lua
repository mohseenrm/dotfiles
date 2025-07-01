return {
  -- add tokyonight
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    opts = { style = "dragon" },
    enabled = false,
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "night" },
    enabled = false,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = true,
    enabled = true,
  },
  -- Configure LazyVim to load prefered colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "oxocarbon",
    },
  },
}
