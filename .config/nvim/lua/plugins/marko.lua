-- return {
--   -- "marko.nvim",
--   -- name = "marko.nvim",
--   -- dev = { true },
--   dir = "~/Projects/marko.nvim",
--   enabled = true,
--   opts = {},
-- }
return {
  "mohseenrm/marko.nvim",
  config = function()
    require("marko").setup()
  end,
}
