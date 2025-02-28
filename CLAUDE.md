# Dotfiles Configuration Guide

## Commands
- **Stow Setup**: `stow .` to create symlinks, `stow -D .` to delete symlinks
- **Neovim Lint**: `stylua` for Lua files (2-space indentation, 120 column width)
- **ZSH**: Use `zsh` commands directly to test shell configurations
- **Update System**: `update` alias (brew update/upgrade on macOS, apt on Ubuntu)

## Code Style Guidelines
- **Lua**: 2-space indentation, 120 column width (see stylua.toml)
- **Vim/Neovim**: Use vim.api.nvim_set_keymap for keymappings with descriptive comments
- **Shell Scripts**: Follow ZSH conventions, use comments for complex functions
- **Naming**: Use descriptive names with lowercase_with_underscores for variables/functions
- **Error Handling**: Apply appropriate error checking in scripts
- **Configuration**: Keep environment-specific config in conditionals `if [[ $(uname) == "Darwin" ]]`

## Tool Configurations
- **Editor**: Neovim is the primary editor (`export EDITOR="nvim"`)
- **Terminal**: Uses zsh with starship prompt, zoxide, and fzf
- **AI Tools**: Configured for aider with claude-3-7-sonnet model
- **Theme**: Tokyo Night theme applied to various tools (kitty, bat, fzf)

## Project Structure
A collection of dotfiles symlinked via GNU stow, organized by application.