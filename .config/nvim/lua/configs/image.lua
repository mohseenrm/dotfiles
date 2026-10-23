local M = {}

function M.setup()
  local placement = Snacks.image.placement
  local terminal = Snacks.image.terminal
  local update = placement.update

  -- Fallback graphics live in the terminal, so hiding buffer text cannot remove them.
  function placement:update()
    if self:ready() and not terminal.env().placeholders then
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
