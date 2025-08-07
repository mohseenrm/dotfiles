require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- start oil
map("n", "<leader>o", "<CMD>Oil<CR>", { desc = "Start Oil" })

-- movement
map("n", "<C-d>", "<C-d>zz", { desc = "Move half page down, centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Move half page up, centered" })
map("v", "<C-d>", "<C-d>zz", { desc = "Move half page down, centered" })
map("v", "<C-u>", "<C-u>zz", { desc = "Move half page up, centered" })
map("n", "H", "^", { desc = "Move to start of line" })
map("n", "L", "$", { desc = "Move to end of line" })
map("v", "H", "^", { desc = "Move to start of line" })
map("v", "L", "$", { desc = "Move to end of line" })

-- copy file path to clipboard
local function insertFullPath()
  local filepath = vim.fn.expand "%"
  vim.fn.setreg("+", filepath) -- write to clipboard
end

map("n", "<leader>fp", insertFullPath, { noremap = true })

-- grepping
map({ "n", "v", "x" }, "<leader><leader>", "<CMD>Telescope find_files<CR>", { desc = "Telescope find files" })
map({ "n", "v", "x" }, "<leader><leader><leader>", "<CMD>Telescope live_grep<CR>", { desc = "Telescope live grep" })
map({ "n", "v", "x" }, "<leader>fr", "<CMD>Telescope oldfiles<CR>", { desc = "Telescope find recent files" })
map({ "n", "v", "x" }, "<leader>sm", "<CMD>Telescope marks<CR>", { desc = "Telescope find marks" })
map({ "n", "v", "x" }, "<leader>sg", "<CMD>Telescope live_grep<CR>", { desc = "Telescope live grep" })

-- themeing
map("n", "<leader>t", function()
  require("nvchad.themes").open {
    style = "compact",
  }
end)

map("n", "<leader>q", "<CMD>qa<CR>", { desc = "Quit" })

-- yanky
map({ "n", "v", "x" }, "<leader>p", "<CMD>Telescope yank_history<CR>", { desc = "Telescope yank history" })

-- copilot chat
map({ "n", "v", "x" }, "<leader>aq", "<CMD>CopilotChat<CR>", { desc = "AI quick chat" })

-- word wrap
map({ "n", "v", "x" }, "<leader>ww", "<CMD>set wrap!<CR>", { desc = "Toggle word wrap" })
