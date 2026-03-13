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
}
