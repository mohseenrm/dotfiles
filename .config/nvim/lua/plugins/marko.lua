return {
  "mohseenrm/marko.nvim",
  -- lazy = true,
  -- event = "VeryLazy",
  --
  -- "marko.nvim",
  -- name = "marko.nvim",
  -- dev = true,
  -- dir = "~/Projects/marko.nvim",
  enabled = true,
  priority = 1000,
  lazy = false,
  opts = {},
  config = function()
    require("marko").setup()
  end,
}
