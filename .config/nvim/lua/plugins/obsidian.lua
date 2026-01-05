local wk = require "which-key"
wk.add {
  {
    "<leader>O",
    group = "Obsidian",
    name = "Obsidian",
    desc = "Obsidian",
    icon = "📝",
  },
  { "<leader>On", "<cmd>Obsidian new<cr>", desc = "New Note", mode = "n" },
  {
    "<leader>Os",
    function()
      Snacks.picker.grep { cwd = vim.fn.expand "~/Projects/notes" }
    end,
    desc = "Search Notes (Snacks)",
    mode = "n",
  },
  {
    "<leader>Of",
    function()
      Snacks.picker.files { cwd = vim.fn.expand "~/Projects/notes" }
    end,
    desc = "Grep Notes (Snacks)",
    mode = "n",
  },
  {
    "<leader>Or",
    function()
      Snacks.picker.recent { filter = { cwd = vim.fn.expand "~/Projects/notes" } }
    end,
    desc = "Recent Notes (Snacks)",
    mode = "n",
  },
  {
    "<leader>Ot",
    function()
      Snacks.picker.files { cwd = vim.fn.expand "~/Projects/notes/src/twilio" }
    end,
    desc = "Search Work Notes",
    mode = "n",
  },
  {
    "<leader>Op",
    function()
      Snacks.picker.files { cwd = vim.fn.expand "~/Projects/notes/src/personal" }
    end,
    desc = "Search Personal Notes",
    mode = "n",
  },
  { "<leader>Ow", "<cmd>Obsidian workspace<cr>", desc = "Change Workspace", mode = "n" },
  { "<leader>Oo", "<cmd>Obsidian open<cr>", desc = "Open in Obsidian App", mode = "n" },
}
vim.keymap.set("n", "gf", function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>Obsidian follow_link<CR>"
  else
    return "gf"
  end
end, { noremap = false, expr = true })

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  priority = 1000,
  lazy = false, -- load on demand
  ft = "markdown",
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
  --   "BufReadPre path/to/my-vault/**.md",
  --   "BufNewFile path/to/my-vault/**.md",
  -- },
  dependencies = {
    -- Required
    "nvim-lua/plenary.nvim",
    -- Optional
    "ibhagwan/fzf-lua",
    "preservim/vim-markdown",
  },
  opts = {
    legacy_commands = false,
    ui = {
      enable = false,
    },
    attachments = {
      -- img_folder = "assets/imgs",
    },
    workspaces = {
      {
        name = "work",
        path = "~/Projects/notes/src/twilio",
        overrides = {
          notes_subdir = "twilio",
        },
      },
      {
        name = "personal",
        path = "~/Projects/notes/src/personal",
        overrides = {
          notes_subdir = "personal",
        },
      },
    },
    picker = {
      -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
      -- Using fzf-lua as fallback (most pickers are handled by custom Snacks functions)
      name = "snacks.picker",
      -- Optional, configure key mappings for the picker. These are the defaults.
      -- Not all pickers support all mappings.
      note_mappings = {
        -- Create a new note from your query.
        new = "<C-x>",
        -- Insert a link to the selected note.
        insert_link = "<C-l>",
      },
      tag_mappings = {
        -- Add tag(s) to current note.
        tag_note = "<C-x>",
        -- Insert a tag at the current location.
        insert_tag = "<C-l>",
      },
    },
    -- follow_url_func = function(url)
    --   -- Open the URL in the default web browser.
    --   vim.fn.jobstart { "open", url } -- Mac OS
    --   -- vim.fn.jobstart({"xdg-open", url})  -- linux
    --   -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
    -- end,
  },
  event = "VeryLazy",
  keys = {
    {
      "<leader>on",
      "<cmd>Obsidian new<cr>",
      desc = "New Note",
      remap = true,
    },
  },
}
