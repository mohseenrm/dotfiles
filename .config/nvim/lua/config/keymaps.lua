-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- local wk = require("which-key")
-- wk.add({
--   {
--     "<leader>o",
--     group = "Obsidian",
--     name = "Obsidian",
--     desc = "Obsidian",
--     icon = "📝",
--   },
--   { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New Note", mode = "n" },
--   { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search Notes", mode = "n" },
--   { "<leader>ow", "<cmd>ObsidianWorkspace<cr>", desc = "Change Workspace", mode = "n" },
--   { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open (needs to be open in buffer)", mode = "n" },
-- })
-- restore the session for the current directory
vim.api.nvim_set_keymap("n", "<leader>qs", [[<cmd>lua require("persistence").load()<cr>]], {})

-- restore the last session
vim.api.nvim_set_keymap("n", "<leader>ql", [[<cmd>lua require("persistence").load({ last = true })<cr>]], {})

vim.api.nvim_set_keymap(
  "n",
  "<leader>xfG",
  [[<cmd>lua require('telescope.builtin').find_files({ cwd = require("telescope.utils").buffer_dir() })<cr>]],
  {}
)

-- start oil
vim.api.nvim_set_keymap("n", "<leader>o", [[<cmd>Oil<cr>]], { desc = "Start Oil" })
