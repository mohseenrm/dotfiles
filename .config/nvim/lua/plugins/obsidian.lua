local wk = require("which-key")
wk.add({
  {
    "<leader>o",
    group = "Obsidian",
    name = "Obsidian",
    desc = "Obsidian",
    icon = "📝",
  },
  { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New Note", mode = "n" },
  { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search Notes", mode = "n" },
  { "<leader>ow", "<cmd>ObsidianWorkspace<cr>", desc = "Change Workspace", mode = "n" },
  { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open (needs to be open in buffer)", mode = "n" },
})
vim.keymap.set("n", "gf", function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
  end
end, { noremap = false, expr = true })

return {
  "epwalsh/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = true,
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
    "echasnovski/mini.pick",
    "ibhagwan/fzf-lua",
    "preservim/vim-markdown",
  },
  opts = {
    ui = {
      enable = false,
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
      name = "telescope.nvim",
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
    mappings = {},
    follow_url_func = function(url)
      -- Open the URL in the default web browser.
      vim.fn.jobstart({ "open", url }) -- Mac OS
      -- vim.fn.jobstart({"xdg-open", url})  -- linux
      -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
    end,
  },
  event = "VeryLazy",
  keys = {
    {
      "<leader>on",
      "<cmd>ObsidianNew<cr>",
      desc = "New Note",
      remap = true,
    },
  },
}
