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
