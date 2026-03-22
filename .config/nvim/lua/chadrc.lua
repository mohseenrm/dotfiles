-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "cobalt-kinetic",

  hl_override = {
    -- Statusline mode colors — Cobalt Kinetic palette
    -- Normal:  cobalt blue  (primary action color)
    -- Insert:  cyan         (secondary / focus color)
    -- Visual:  error red    (selection = danger/active)
    -- Command: neon yellow  (command = attention)
    -- Terminal: neon green  (terminal = live/running)
    -- Replace: neon orange  (replace = mutation)

    St_NormalMode     = { bg = "#7bafff", fg = "#080e19", bold = true },
    St_NormalModeSep  = { fg = "#7bafff" },

    St_InsertMode     = { bg = "#00fbfb", fg = "#080e19", bold = true },
    St_InsertModeSep  = { fg = "#00fbfb" },

    St_VisualMode     = { bg = "#ff716c", fg = "#080e19", bold = true },
    St_VisualModeSep  = { fg = "#ff716c" },

    St_CommandMode    = { bg = "#ffd866", fg = "#080e19", bold = true },
    St_CommandModeSep = { fg = "#ffd866" },

    St_TerminalMode   = { bg = "#50fa7b", fg = "#080e19", bold = true },
    St_TerminalModeSep = { fg = "#50fa7b" },

    St_ReplaceMode    = { bg = "#ff9e64", fg = "#080e19", bold = true },
    St_ReplaceModeSep = { fg = "#ff9e64" },

    St_SelectMode     = { bg = "#7bafff", fg = "#080e19", bold = true },
    St_SelectModeSep  = { fg = "#7bafff" },

    -- CursorLine: subtle highlight using surface_container
    CursorLine = { bg = "#0d1220" },

    -- WinSeparator: use outline color for 2px-feel structural borders
    WinSeparator = { fg = "#172030" },

    -- FloatBorder: cobalt blue — Neo-Brutalist frame
    FloatBorder = { fg = "#7bafff" },

    -- MatchParen: cyan pulse — the "neon glow" effect
    MatchParen = { fg = "#00fbfb", bg = "#172030", bold = true },

    -- Search: neon yellow background — high visibility
    Search    = { fg = "#05080f", bg = "#ffd866" },
    IncSearch = { fg = "#05080f", bg = "#ff9e64" },

    -- Visual selection: surface_container_highest
    Visual = { bg = "#172030" },
  },
}

-- M.nvdash = { load_on_startup = true }
M.ui = {
  cmp = {
    style = "atom",
  },

  statusline = {
    separator_style = "arrow",
  },

  --  tabufline = {
  --     lazyload = false
  -- }
}

return M
