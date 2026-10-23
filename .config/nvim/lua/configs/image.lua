local M = {}

function M.setup()
  local placement = Snacks.image.placement
  local terminal = Snacks.image.terminal
  local update = placement.update

  vim.api.nvim_create_autocmd("BufLeave", {
    group = vim.api.nvim_create_augroup("image_preview_cleanup", { clear = true }),
    callback = function()
      local doc = package.loaded["snacks.image.doc"]
      if doc then
        doc.hover_close()
      end
    end,
  })

  -- Fallback graphics live in the terminal, so hiding buffer text cannot remove them.
  function placement:update()
    -- Document previews open their window in on_update_pre.
    if self:ready() and not self.opts.on_update_pre and not terminal.env().placeholders then
      if self.hidden or #self:state().wins == 0 then
        terminal.request { a = "d", d = "i", i = self.img.id, p = self.id }
        self._state = nil
        return
      end
    end
    return update(self)
  end
end

return M
