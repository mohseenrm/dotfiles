return {
   'nvim-telescope/telescope.nvim', version = '*',
   enabled = true,
   priority = 1000,
   lazy = false,
   dependencies = {
     'nvim-lua/plenary.nvim',
     -- optional but recommended
     { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
   }
}
