local function isempty(s)
  return s == nil or s == ""
end

return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
  dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" }, -- if you use standalone mini plugins
  -- dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
  ---@module "render-markdown"
  ---@type render.md.UserConfig
  event = "VeryLazy",
  lazy = true,
  opts = {},
  config = function()
    require("obsidian").get_client().opts.ui.enable = false
    local obsidianNS = vim.api.nvim_get_namespaces()["ObsidianUI"]
    if not isempty(obsidianNS) then
      vim.api.nvim_buf_clear_namespace(0, obsidianNS, 0, -1)
    end
    -- vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_get_namespaces()["ObsidianUI"], 0, -1)
    require("render-markdown").setup({})
  end,
}
