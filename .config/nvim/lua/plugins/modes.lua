return {
  "mvllow/modes.nvim",
  event = "BufReadPre",
  tag = "v0.2.1",
  config = function()
    require("modes").setup()
  end,
}
