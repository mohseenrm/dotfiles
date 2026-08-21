local home = os.getenv "HOME"
local banner_path = home .. "/.config/nvim/logo/banner.txt"
local banner_cmd = "bat " .. banner_path .. " | lolcat -p 1"

local rosie_path = home .. "/.config/nvim/assets/rosie.png"

-- Zellij >= 0.45 speaks the kitty graphics protocol, but snacks hardcodes it as
-- unsupported and can't detect it: zellij answers XTVERSION with "Zellij(4500)",
-- which matches no known terminal, so detection falls back to "unknown".
-- Verified against zellij 0.45 by querying the protocol directly:
--   a=q  -> OK                                          (direct transmission works)
--   U=1  -> ENOTSUPPORTED: unicode placeholders          (so placeholders must stay off)
-- SNACKS_ZELLIJ=0 clears the hardcoded unsupported flag; SNACKS_WEZTERM=1 then
-- selects the profile that matches those capabilities exactly
-- (supported=true, placeholders=false). SNACKS_KITTY would be wrong here: it
-- implies placeholders=true, which zellij rejects.
if vim.env.ZELLIJ then
  if not vim.env.SNACKS_ZELLIJ then
    vim.env.SNACKS_ZELLIJ = "0"
  end
  if not vim.env.SNACKS_WEZTERM then
    vim.env.SNACKS_WEZTERM = "1"
  end
end

-- Without unicode placeholders snacks can't anchor an image to buffer text:
-- `render_fallback` pins it to `nvim_win_get_position(win)` (the window's
-- top-left) and ignores `opts.pos` entirely. Anchoring to the dashboard buffer
-- therefore parks rosie in the top-left corner. Giving the image its own
-- floating window makes that corner the corner we want, so the pane-2 position
-- is preserved on the fallback path.
local function rosie_image(width, height)
  return function(dashboard, pos)
    local buf = vim.api.nvim_create_buf(false, true)
    local win

    local function close()
      if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
      win = nil
    end

    local function draw()
      if not (dashboard.win and vim.api.nvim_win_is_valid(dashboard.win)) then
        return close()
      end
      -- Below the 2-pane threshold the dashboard stacks panes vertically and
      -- pane 2 resolves to {1, 0}, which would put the float on top of the
      -- banner. Keep it hidden until there's room for the side-by-side layout.
      local dash_width = vim.api.nvim_win_get_width(dashboard.win)
      local o = dashboard.opts or {}
      local needed = (o.width or 85) * 2 + (o.pane_gap or 4)
      if pos[2] == 0 or dash_width < needed then
        return close()
      end
      local dash = vim.api.nvim_win_get_position(dashboard.win)
      local cfg = {
        relative = "editor",
        row = dash[1] + pos[1] - 1,
        col = dash[2] + pos[2],
        width = width,
        height = height,
        focusable = false,
        style = "minimal",
        noautocmd = true,
      }
      if win and vim.api.nvim_win_is_valid(win) then
        cfg.noautocmd = nil
        vim.api.nvim_win_set_config(win, cfg)
      else
        win = vim.api.nvim_open_win(buf, false, cfg)
        vim.wo[win].winblend = 0
        vim.wo[win].winhighlight = "Normal:DashboardNormal,NormalFloat:DashboardNormal"
        pcall(function()
          Snacks.image.placement.new(buf, rosie_path, {
            inline = false,
            width = width,
            height = height,
            pos = { 1, 0 },
          })
        end)
      end
    end

    draw()

    local group = vim.api.nvim_create_augroup("rosie_dashboard_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd("VimResized", { group = group, callback = draw })
    vim.api.nvim_create_autocmd("BufWipeout", {
      group = group,
      buffer = dashboard.buf,
      callback = close,
    })
  end
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    scratch = { enabled = true },
    bigfile = { enabled = true },
    image = { enabled = true },
    notifier = { enabled = true },
    dashboard = {
      width = 85,
      pane_gap = 4,
      sections = {
        {
          pane = 1,
          {
            section = "terminal",
            cmd = banner_cmd,
            indent = 2,
            width = 80,
            height = 10,
            ttl = 0.1,
            padding = 1,
          },
          { section = "keys", gap = 1 },
          { section = "startup" },
        },
        {
          pane = 2,
          {
            text = string.rep("\n", 20),
            render = rosie_image(60, 30),
            padding = 4,
          },
        },
      },
      preset = {
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "m", desc = "Search Marks", action = ":lua Snacks.picker.marks()" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent()" },
          { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
    scroll = { enabled = false },
    picker = {
      enabled = true,
      layout = "telescope",
      -- Configure snacks picker to match your telescope setup
      sources = {
        files = {
          hidden = true, -- show hidden files (matches your rg --hidden)
        },
        grep = {
          hidden = true, -- search hidden files
        },
      },
    },
    indent = { enabled = true },
  },
}
