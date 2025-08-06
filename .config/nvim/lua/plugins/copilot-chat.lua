return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    event = "BufReadPost",
    dependencies = {
      { "nvim-lua/plenary.nvim", branch = "master" },
    },
    build = "make tiktoken",
    opts = {
      -- See Configuration section for options
    },
  },
}
