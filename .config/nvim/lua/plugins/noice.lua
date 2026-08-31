return {
  "folke/noice.nvim",
  lazy = true,
  event = "BufReadPre",
  opts = {
    lsp = {
      signature = {
        enabled = false,
      },
      -- hover enabled: Noice renders LSP hover docs with Treesitter syntax highlighting
      hover = {
        enabled = true,
      },
    },
    cmdline = {
      view = "cmdline_popup",
      opts = {
        position = {
          row = "50%",
          col = "50%",
        },
      },
    },
    presets = {
      bottom_search = false,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = true,
    },
  },
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  config = function(_, opts)
    -- lazy.nvim's module cache removes Neovim's own vim._load_package from
    -- package.loaders and replaces it with an rtp-index cache loader. When that
    -- index goes stale, require("vim.lsp.buf") misses the runtime dir, falls
    -- through to bare package.path and errors.
    -- Reinstate the builtin loader as a last-resort fallback.
    local has_builtin = false
    for _, loader in ipairs(package.loaders) do
      if loader == vim._load_package then
        has_builtin = true
        break
      end
    end
    if not has_builtin then
      table.insert(package.loaders, vim._load_package)
    end

    require("noice").setup(opts)
  end,
}
