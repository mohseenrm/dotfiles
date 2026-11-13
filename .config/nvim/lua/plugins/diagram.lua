return {
  "3rd/diagram.nvim",
  ft = "markdown",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    {
      "3rd/image.nvim",
      build = false,
      opts = {
        backend = "kitty",
        processor = "magick_cli",
        kitty_method = "normal",
        max_height_window_percentage = 160,
        scale_factor = 2.0,
        integrations = {
          markdown = { download_remote_images = false },
          asciidoc = { enabled = false },
          typst = { enabled = false },
          neorg = { enabled = false },
          syslang = { enabled = false },
        },
        hijack_file_patterns = {},
      },
    },
  },
  opts = function()
    return {
      events = { render_buffer = {} },
      integrations = { require "diagram.integrations.markdown" },
      renderer_options = {
        mermaid = {
          background = "transparent",
          theme = "dark",
          scale = 2,
        },
      },
    }
  end,
  config = function(_, opts)
    local diagram = require "diagram"
    diagram.setup(opts)

    local pending
    local function render()
      if vim.bo.filetype ~= "markdown" then
        return
      end
      local buf = vim.api.nvim_get_current_buf()
      if pending then
        pending:stop()
        pending:close()
      end
      pending = vim.defer_fn(function()
        pending = nil
        if vim.api.nvim_get_current_buf() == buf then
          diagram.render()
        end
      end, 200)
    end

    local group = vim.api.nvim_create_augroup("inline_diagrams", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "InsertLeave", "TextChanged" }, {
      group = group,
      callback = render,
    })
    vim.api.nvim_create_autocmd("BufLeave", {
      group = group,
      callback = function()
        diagram.clear()
      end,
    })
    render()
  end,
  keys = {
    {
      "<leader>md",
      function()
        require("diagram").show_diagram_hover()
      end,
      ft = "markdown",
      desc = "Show diagram in a tab",
    },
    {
      "<leader>mr",
      function()
        require("diagram").render()
      end,
      ft = "markdown",
      desc = "Render inline diagrams",
    },
    {
      "<leader>mc",
      function()
        require("diagram").clear()
      end,
      ft = "markdown",
      desc = "Clear inline diagrams",
    },
  },
}
