require "nvchad.options"

-- add yours here!

local o = vim.o
o.cursorlineopt = "both" -- to enable cursorline!
o.autoindent = true
o.copyindent = true
o.breakindent = true
o.clipboard = "unnamedplus"
o.updatetime = 100
o.wrap = false

-- Disable vim-markdown's gx mapping (conflicts with our custom one)
vim.g.vim_markdown_no_default_key_mappings = 1

-- Disable Ruby ftplugin's <C-]>/g<C-]> tag mappings.
-- They use `tagfunc` which makes the LSP fall back to workspace/symbol
-- (returns wrong locations and triggers "Invalid cursor line: out of range")
-- instead of textDocument/definition. See neovim#30160.
vim.g.no_ruby_maps = true
