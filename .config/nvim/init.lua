vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- INFO: Prepend the mise-managed Go bin dir so vim.system() calls (e.g. from gopls's
-- root_dir detection) resolve the real 'go' binary, not the repo's Bazel wrapper
-- in scripts/bin/go which requires CODE_ROOT and a full Bazel environment.
local mise_go_bin = vim.fn.expand "~/.local/share/mise/installs/go/latest/bin"
if vim.fn.isdirectory(mise_go_bin) == 1 then
  vim.env.PATH = mise_go_bin .. ":" .. vim.env.PATH
end

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

-- Customized vim options
vim.opt.foldenable = false
vim.wo.relativenumber = true

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme (guard against missing cache on first run)
local function safe_dofile(path)
  if vim.uv.fs_stat(path) then
    dofile(path)
  end
end
safe_dofile(vim.g.base46_cache .. "defaults")
safe_dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)

-- Telescope config - migrated to snacks.nvim picker
-- require("telescope").setup {
--   pickers = {
--     find_files = {
--       find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
--     },
--   },
--   defaults = {
--     layout_config = { prompt_position = "bottom" },
--     path_display = { "smart" },
--     vimgrep_arguments = {
--       "rg",
--       "--color=never",
--       "--no-heading",
--       "--with-filename",
--       "--line-number",
--       "--column",
--       "--smart-case",
--       "--hidden",
--     },
--   },
-- }

require("gitsigns").setup {
  signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
  numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
  linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
  word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
  watch_gitdir = {
    follow_files = true,
  },
  auto_attach = true,
  attach_to_untracked = false,
  current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = "eol", -- "eol" | "overlay" | "right_align"
    delay = 1000,
    ignore_whitespace = false,
    virt_text_priority = 100,
  },
  current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
  sign_priority = 6,
  update_debounce = 100,
  status_formatter = nil, -- Use default
  max_file_length = 40000, -- Disable if file is longer than this (in lines)
  preview_config = {
    -- Options passed to nvim_open_win
    border = "single",
    style = "minimal",
    relative = "cursor",
    row = 0,
    col = 1,
  },
  -- yadm = {
  --   enable = false,
  -- },
}

-- Custom themes
-- require("cyberdream").setup()
-- vim.cmd("colorscheme cyberdream")

local vim = vim
local opt = vim.opt

opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
