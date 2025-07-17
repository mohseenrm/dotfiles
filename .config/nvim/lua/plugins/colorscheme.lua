return {
  -- add tokyonight
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    opts = { theme = "dragon" },
    enabled = false,
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "night" },
    enabled = false,
  },
  {
    "tiagovla/tokyodark.nvim",
    opts = {
      -- custom options here
    },
    config = function(_, opts)
      require("tokyodark").setup(opts) -- calling setup is optional
      vim.cmd([[colorscheme tokyodark]])
    end,
    enabled = false,
  },
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    enabled = true,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = true,
    enabled = false,
  },
  -- Configure LazyVim to load prefered colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "cyberdream",
    },
  },
}
