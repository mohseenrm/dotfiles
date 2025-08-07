# 🚀 Neovim Configuration

> *A modern, feature-rich Neovim setup built on NvChad with AI-powered development tools*

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-brightgreen.svg)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg)](https://www.lua.org/)
[![NvChad](https://img.shields.io/badge/NvChad-v2.5-orange.svg)](https://nvchad.com/)

## ✨ Features

This Neovim configuration transforms your editor into a powerful IDE with modern features and beautiful aesthetics.

### 🎯 Core Capabilities

| Feature | Plugin | Description |
|---------|--------|-------------|
| 🤖 **AI Assistance** | Copilot + Copilot Chat | GitHub Copilot integration with chat interface |
| 🔍 **Fuzzy Finding** | FZF-Lua | Lightning-fast file, buffer, and text searching |
| 🌳 **File Management** | Oil.nvim | Edit your filesystem like a buffer |
| 📝 **LSP Support** | Built-in LSP | Full language server protocol support |
| 🎨 **Syntax Highlighting** | Treesitter | Advanced syntax highlighting and code understanding |
| 🔧 **Code Formatting** | Conform.nvim | Automatic code formatting on save |
| 📊 **Status Line** | Custom | Beautiful, informative status line |
| 🎭 **Theme** | Tokyo Night | Consistent theming with terminal |

### 🛠️ Language Support

- **Rust** 🦀: Full support with `rustaceanvim` and `crates.nvim`
- **Lua** 🌙: Native Neovim configuration language
- **Python** 🐍: Complete development environment
- **JavaScript/TypeScript** ⚡: Modern web development
- **Go** 🐹: Systems programming support
- **And many more!** 🌟

### 🎨 UI Enhancements

- **Dropbar**: Breadcrumb navigation
- **Render Markdown**: Beautiful markdown rendering
- **Color Highlighting**: Live color preview
- **Obsidian Integration**: Note-taking workflow
- **Stay Centered**: Keep cursor centered while scrolling

## 🚀 Quick Start

### Prerequisites

Ensure you have Neovim 0.9+ installed:

```bash
# macOS
brew install neovim

# Ubuntu
sudo apt install neovim

# Or build from source for latest features
```

### Installation

This configuration is automatically installed with the main dotfiles setup:

```bash
cd ~/dotfiles
./setup.sh
```

Or manually:

```bash
# Backup existing config
mv ~/.config/nvim ~/.config/nvim.backup

# Symlink this config
cd ~/dotfiles
stow .
```

### First Launch

1. **Start Neovim**: `nvim`
2. **Install Plugins**: Lazy.nvim will automatically install all plugins
3. **Install Language Servers**: Use `:Mason` to install LSPs
4. **Enjoy!** 🎉

## 📁 Structure

```
.config/nvim/
├── init.lua                 # 🚀 Entry point
├── lua/
│   ├── autocmds.lua        # 🔄 Auto commands
│   ├── mappings.lua        # ⌨️  Key mappings
│   ├── options.lua         # ⚙️  Vim options
│   ├── chadrc.lua          # 🎨 NvChad configuration
│   ├── configs/            # 🔧 Plugin configurations
│   │   ├── conform.lua     # 📝 Code formatting
│   │   ├── lazy.lua        # 📦 Plugin manager
│   │   └── lspconfig.lua   # 🔍 Language servers
│   └── plugins/            # 🔌 Plugin specifications
│       ├── ai.lua          # 🤖 AI tools
│       ├── copilot.lua     # 👨‍💻 GitHub Copilot
│       ├── fzf.lua         # 🔍 Fuzzy finder
│       ├── oil.lua         # 📁 File manager
│       ├── rustaceanvim.lua # 🦀 Rust support
│       └── ...
├── assets/
│   └── rosie.png           # 🌹 Custom logo
└── logo/
    └── banner.txt          # 🎨 ASCII art banner
```

## ⌨️ Key Mappings

### 🚀 Leader Key: `<Space>`

#### 🔍 Finding & Navigation
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ff` | Find Files | Fuzzy find files in project |
| `<leader>fg` | Live Grep | Search text in project |
| `<leader>fb` | Find Buffers | Switch between open buffers |
| `<leader>fh` | Find Help | Search help documentation |
| `<leader>fo` | Find Oldfiles | Recently opened files |

#### 📁 File Management
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>e` | Toggle Oil | File manager (edit filesystem) |
| `<leader>n` | New File | Create new file |

#### 🤖 AI & Copilot
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>cc` | Copilot Chat | Open AI chat interface |
| `<leader>ce` | Explain Code | Explain selected code |
| `<leader>cf` | Fix Code | Fix code issues |
| `<leader>co` | Optimize Code | Optimize performance |

#### 🔧 LSP & Development
| Key | Action | Description |
|-----|--------|-------------|
| `gd` | Go to Definition | Jump to symbol definition |
| `gr` | Go to References | Find all references |
| `K` | Hover Documentation | Show symbol information |
| `<leader>ca` | Code Actions | Available code actions |
| `<leader>rn` | Rename Symbol | Rename across project |

#### 🎨 UI & Windows
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>th` | Toggle Theme | Switch between themes |
| `<C-h/j/k/l>` | Navigate Windows | Move between splits |
| `<leader>v` | Vertical Split | Split window vertically |
| `<leader>h` | Horizontal Split | Split window horizontally |

## 🔧 Customization

### 🎨 Themes

Switch themes easily:
```lua
-- In chadrc.lua
M.ui = {
  theme = "tokyonight",  -- or "onedark", "gruvbox", etc.
}
```

### 🔌 Adding Plugins

Add new plugins in `lua/plugins/`:

```lua
-- lua/plugins/example.lua
return {
  "author/plugin-name",
  config = function()
    require("plugin-name").setup({
      -- configuration
    })
  end,
}
```

### ⌨️ Custom Key Mappings

Add mappings in `lua/mappings.lua`:

```lua
local map = vim.keymap.set

map("n", "<leader>custom", function()
  -- your custom function
end, { desc = "Custom action" })
```

## 🦀 Rust Development

### Setup

1. **Install Rust**: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
2. **Add Components**:
   ```bash
   rustup component add rust-analyzer
   rustup component add rustfmt
   rustup component add clippy
   ```

### Features

- **rust-analyzer**: Full LSP support
- **Crates.nvim**: Cargo.toml dependency management
- **Rustaceanvim**: Enhanced Rust experience
- **Debugging**: Built-in DAP support
- **Testing**: Integrated test runner

### Key Mappings

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>rc` | Cargo Commands | Run cargo commands |
| `<leader>rt` | Run Tests | Execute Rust tests |
| `<leader>rr` | Run Project | Cargo run |
| `<leader>rb` | Build Project | Cargo build |

## 🐛 Troubleshooting

### 🔧 Common Issues

#### Plugin Installation Fails
```bash
# Clear plugin cache
rm -rf ~/.local/share/nvim/lazy

# Restart Neovim and reinstall
nvim +Lazy
```

#### LSP Not Working
```bash
# Install language servers
nvim +Mason

# Check LSP status
:LspInfo
```

#### Copilot Authentication
```bash
# In Neovim
:Copilot auth
```

#### Treesitter Errors
```bash
# Update parsers
:TSUpdate

# Or reinstall specific parser
:TSInstall rust lua python
```

### 🚀 Performance Issues

#### Slow Startup
1. Check plugin loading with `:Lazy profile`
2. Disable unused plugins
3. Use lazy loading for heavy plugins

#### High Memory Usage
1. Limit Treesitter parsers: `:TSUninstall <parser>`
2. Reduce LSP clients
3. Clear old swap files: `rm ~/.local/state/nvim/swap/*`

### 🔍 Debugging

#### Enable Debug Mode
```lua
-- Add to init.lua temporarily
vim.g.debug_mode = true
```

#### Check Health
```bash
# In Neovim
:checkhealth
```

#### View Logs
```bash
# LSP logs
tail -f ~/.local/state/nvim/lsp.log

# General logs
tail -f ~/.local/state/nvim/log
```

## 🎯 Tips & Tricks

### 🚀 Productivity Boosters

1. **Use Oil.nvim**: Edit your filesystem like a buffer with `<leader>e`
2. **Master FZF**: `<leader>ff` for files, `<leader>fg` for text search
3. **Copilot Chat**: Ask questions about your code with `<leader>cc`
4. **Stay Centered**: Cursor stays centered while scrolling
5. **Quick Actions**: Use `<leader>ca` for context-aware code actions

### 🎨 Visual Enhancements

1. **Dropbar Navigation**: See your code structure at the top
2. **Color Preview**: See colors inline in CSS/config files
3. **Markdown Rendering**: Beautiful markdown preview
4. **Custom Banner**: Personalized startup screen

### ⚡ Performance Tips

1. **Lazy Loading**: Most plugins load only when needed
2. **Treesitter**: Install only needed language parsers
3. **LSP**: Use project-specific LSP configurations
4. **Caching**: Configurations are cached for faster startup

## 🤝 Contributing

This configuration is part of a larger dotfiles collection. Feel free to:

1. Fork and customize for your needs
2. Submit issues for bugs or feature requests
3. Share your improvements via pull requests

## 📚 Resources

- [NvChad Documentation](https://nvchad.com/)
- [Neovim Documentation](https://neovim.io/doc/)
- [Lua Guide for Neovim](https://github.com/nanotee/nvim-lua-guide)
- [Plugin Directory](https://dotfyle.com/neovim/plugins)

---

<div align="center">

**Happy Coding with Neovim!** 🚀

*Powered by NvChad and enhanced with AI* 🤖

</div>