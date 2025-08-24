-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "material-deep-ocean",

  hl_override = {
    St_NormalMode = { bg = "#86e1fc" },
    St_NormalModeSep = { fg = "#86e1fc" },
    St_InsertMode = { bg = "green" },
    St_InsertModeSep = { fg = "green" },
    St_VisualMode = { bg = "#fa5056" },
    St_VisualModeSep = { fg = "#fa5056" },
  },
}

-- M.nvdash = { load_on_startup = true }
M.ui = {
  cmp = {
    style = "atom",
  },

  --  tabufline = {
  --     lazyload = false
  -- }
}

return M
