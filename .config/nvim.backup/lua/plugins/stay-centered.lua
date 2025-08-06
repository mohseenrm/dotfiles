return {
  "arnamak/stay-centered.nvim",
  event = "VeryLazy",
  lazy = true,
  opts = function()
    vim.keymap.set("n", "<leader>CC", function()
      require("stay-centered").toggle()
      vim.notify("Toggled stay-centered", vim.log.levels.INFO)
    end, { desc = "[P]Toggle stay-centered.nvim" })
  end,
}
