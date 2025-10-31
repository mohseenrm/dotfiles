require "nvchad.autocmds"

-- Ensure gx mapping works in markdown files (override vim-markdown plugin)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    -- Unmap vim-markdown's gx if it exists
    pcall(vim.keymap.del, "n", "gx", { buffer = true })

    -- Apply our custom gx mapping
    local function open_url_under_cursor()
      local function get_visual_selection()
        local _, start_row, start_col = unpack(vim.fn.getpos "'<")
        local _, end_row, end_col = unpack(vim.fn.getpos "'>")

        if start_row == end_row then
          local line = vim.fn.getline(start_row)
          return string.sub(line, start_col, end_col)
        end
        return nil
      end

      local url = get_visual_selection()

      if not url or url == "" then
        local line = vim.fn.getline "."
        local col = vim.fn.col "."

        local patterns = {
          "https?://[%w-_%.%?%.:/%+=&]+",
          "www%.[%w-_%.%?%.:/%+=&]+",
          "%[.-%]%((.-)%)",
          "<(.-)>",
        }

        for _, pattern in ipairs(patterns) do
          for match in line:gmatch(pattern) do
            local start_pos = line:find(match, 1, true)
            local end_pos = start_pos + #match - 1

            if start_pos and col >= start_pos and col <= end_pos then
              if pattern == "%[.-%]%((.-)%)" then
                url = match:match "%((.-)%)"
              elseif pattern == "<(.-)>" then
                url = match
              else
                url = match
              end
              break
            end
          end
          if url then
            break
          end
        end
      end

      if url and url ~= "" then
        if not url:match "^https?://" and not url:match "^www%." then
          if url:match "^%.%./" or url:match "^%./" or url:match "^/" then
            vim.cmd "normal! gf"
            return
          end
        end

        if url:match "^www%." then
          url = "http://" .. url
        end

        vim.fn.jobstart({ "open", url }, { detach = true })
        vim.notify("Opening: " .. url, vim.log.levels.INFO)
      else
        vim.notify("No URL found under cursor", vim.log.levels.WARN)
      end
    end

    vim.keymap.set("n", "gx", open_url_under_cursor, {
      desc = "Open URL under cursor",
      buffer = true,
      noremap = true,
      silent = true,
    })
  end,
})
