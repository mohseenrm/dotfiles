# Dotfiles Configuration Guide

## Crush

- For all prompts, plan first, come up with options, alternatives and pros/cons for each option
- Create a `docs/**/*.md` to track plans, tasks, and progress (relative to current project)
- Ask user to proceed or modify approach in the new doc
- Iterate and update progress in `docs/**/*.md` (relative to current project)

## Commands

- **Stow Setup**: `stow .` to create symlinks, `stow -D .` to delete symlinks
- **Neovim Lint**: `stylua .config/nvim/` for Lua files (2-space indentation, 120 column width)
- **ZSH**: Use `zsh` commands directly to test shell configurations
- **Update System**: `update` alias (brew update/upgrade on macOS, apt on Ubuntu)
- **Setup**: `./setup.sh` to install dependencies and configure system

## Code Style Guidelines

- **Lua**: 2-space indentation, 120 column width (see .config/nvim/stylua.toml)
- **Vim/Neovim**: Use vim.api.nvim_set_keymap for keymappings with descriptive comments
- **Shell Scripts**: Follow ZSH conventions, use comments for complex functions
- **Naming**: Use descriptive names with lowercase_with_underscores for variables/functions
- **Error Handling**: Apply appropriate error checking in scripts with `set -e`
- **Configuration**: Keep environment-specific config in conditionals `if [[ $(uname) == "Darwin" ]]`

## Tool Configurations

- **Editor**: Neovim is the primary editor (`export EDITOR="nvim"`)
- **Terminal**: Wezterm (supports both kitty and sixel protocols for images)
  - Alternative: Kitty (config preserved in `.config/kitty/`)
  - Migration: `./bin/migrate-to-wezterm.sh` (see `docs/wezterm-migration-plan.md`)
- **Shell**: zsh with starship prompt, zoxide, and fzf
- **Multiplexer**: Zellij (works with Wezterm's image protocols)
- **AI Tools**: Configured for aider with claude-3-7-sonnet model
- **Theme**: Tokyo Night theme applied to various tools (wezterm, kitty, bat, fzf)

## Project Structure

A collection of dotfiles symlinked via GNU stow, organized by application in `.config/`.
Main entry point is `setup.sh` for automated installation across macOS and Ubuntu.

## Testing

- Test shell configurations by sourcing: `source ~/.zshrc`
- Verify symlinks: `ls -la ~/ | grep -E '\->'`
- Check tool installations: `which nvim starship zoxide fzf eza bat`

