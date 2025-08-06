return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    files = {
      hidden = true,
    },
    grep = {
      hidden = true,
    },
    oldfiles = {
      cwd_only = true,
      include_current_session = true,
    },
    keymap = {
      fzf = {
        ["ctrl-u"] = "half-page-up",
        ["ctrl-d"] = "half-page-down",
        ["ctrl-h"] = "first",
        ["ctrl-l"] = "last",
      },
    },
  },
}
