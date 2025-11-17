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
map({ "n", "v", "x" }, "<leader><leader>", function()
  Snacks.picker.files()
end, { desc = "Find files" })
map({ "n", "v", "x" }, "<leader>ff", function()
  Snacks.picker.files()
end, { desc = "Find files" })
map({ "n", "v", "x" }, "<leader><leader><leader>", function()
  Snacks.picker.grep()
end, { desc = "Live grep" })
map({ "n", "v", "x" }, "<leader>fr", function()
  Snacks.picker.recent()
end, { desc = "Find recent files" })
map({ "n", "v", "x" }, "<leader>sm", function()
  Snacks.picker.marks()
end, { desc = "Find marks" })
map({ "n", "v", "x" }, "<leader>sg", function()
  Snacks.picker.grep()
end, { desc = "Live grep" })

-- themeing
map("n", "<leader>t", function()
  require("nvchad.themes").open {
    style = "compact",
  }
end)

map("n", "<leader>q", "<CMD>qa<CR>", { desc = "Quit" })

-- yanky
map({ "n", "v", "x" }, "<leader>p", function()
  Snacks.picker.registers()
end, { desc = "Yank history" })

-- Additional snacks picker keymaps
map("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Find buffers" })
map("n", "<leader>fh", function()
  Snacks.picker.help()
end, { desc = "Find help" })
map("n", "<leader>fk", function()
  Snacks.picker.keymaps()
end, { desc = "Find keymaps" })
map("n", "<leader>gc", function()
  Snacks.picker.git_log()
end, { desc = "Git log" })
map("n", "<leader>gs", function()
  Snacks.picker.git_status()
end, { desc = "Git status" })
map("n", "<leader>sd", function()
  Snacks.picker.diagnostics()
end, { desc = "Diagnostics" })
map("n", "<leader>ss", function()
  Snacks.picker.lsp_symbols()
end, { desc = "LSP symbols" })
map("n", "gr", function()
  Snacks.picker.lsp_references()
end, { desc = "LSP references" })
map("n", "gd", function()
  Snacks.picker.lsp_definitions()
end, { desc = "LSP definitions" })

-- copilot chat
map({ "n", "v", "x" }, "<leader>aq", "<CMD>CopilotChat<CR>", { desc = "AI quick chat" })

-- word wrap
map({ "n", "v", "x" }, "<leader>ww", "<CMD>set wrap!<CR>", { desc = "Toggle word wrap" })

-- lazy

map({ "n", "v", "x" }, "<leader>l", "<CMD>Lazy<CR>", { desc = "Lazy" })

-- LSP
map({ "n", "v", "x" }, "<leader>cd", vim.diagnostic.open_float, { desc = "Show diagnostic under cursor" })

-- Spectre: Search and Replace
map("n", "<leader>S", '<cmd>lua require("spectre").toggle()<CR>', {
  desc = "Toggle Spectre",
})
map("n", "<leader>sw", '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', {
  desc = "Search current word",
})
map("v", "<leader>sw", '<esc><cmd>lua require("spectre").open_visual()<CR>', {
  desc = "Search current word",
})
map("n", "<leader>sp", '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>', {
  desc = "Search on current file",
})

-- Open URL under cursor with gx
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

  -- Try to get URL from visual selection first
  local url = get_visual_selection()

  -- If no visual selection, try to extract URL from current line
  if not url or url == "" then
    local line = vim.fn.getline "."
    local col = vim.fn.col "."

    -- Try to find URL patterns around cursor
    -- Match URLs like http://, https://, www., or markdown links
    local patterns = {
      "https?://[%w-_%.%?%.:/%+=&]+", -- http(s) URLs
      "www%.[%w-_%.%?%.:/%+=&]+", -- www URLs
      "%[.-%]%((.-)%)", -- markdown links [text](url)
      "<(.-)>", -- angle bracket URLs <url>
    }

    for _, pattern in ipairs(patterns) do
      for match in line:gmatch(pattern) do
        local start_pos = line:find(match, 1, true)
        local end_pos = start_pos + #match - 1

        if start_pos and col >= start_pos and col <= end_pos then
          -- For markdown links, extract just the URL from [text](url)
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
    -- Add http:// prefix if missing
    if not url:match "^https?://" and not url:match "^www%." then
      -- Check if it looks like a relative path
      if url:match "^%.%./" or url:match "^%./" or url:match "^/" then
        -- It's a file path, use gf instead
        vim.cmd "normal! gf"
        return
      end
    end

    -- Add http:// to www. URLs
    if url:match "^www%." then
      url = "http://" .. url
    end

    -- Open URL with macOS 'open' command
    vim.fn.jobstart({ "open", url }, { detach = true })
    vim.notify("Opening: " .. url, vim.log.levels.INFO)
  else
    vim.notify("No URL found under cursor", vim.log.levels.WARN)
  end
end

map("n", "gx", open_url_under_cursor, { desc = "Open URL under cursor", noremap = true, silent = true })
map("v", "gx", open_url_under_cursor, { desc = "Open selected URL", noremap = true, silent = true })
