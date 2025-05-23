-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.diagnostic.config({ virtual_lines = true })
vim.api.nvim_set_hl(0, "HighLight", {
  fg = "#f7768e",
})
-- Move to default picker
-- vim.g.lazyvim_picker = "telescope"
