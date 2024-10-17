return {
  -- add tokyonight
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "night" },
    enabled = true,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = true,
    enabled = false,
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    enabled = false,
  },
  -- Configure LazyVim to load prefered colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
