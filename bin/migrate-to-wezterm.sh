#!/usr/bin/env bash
# Wezterm Migration Helper Script

set -e

DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"

echo "🚀 Wezterm Migration Helper"
echo "================================"
echo ""

# Check if Wezterm is installed
if ! command -v wezterm &> /dev/null; then
    echo "❌ Wezterm is not installed"
    echo ""
    echo "Install Wezterm with:"
    echo "  brew install --cask wezterm"
    echo "  # or for nightly builds:"
    echo "  brew install --cask wezterm-nightly"
    echo ""
    exit 1
fi

echo "✅ Wezterm is installed"
wezterm --version
echo ""

# Check if config exists
if [ ! -f "$DOTFILES_DIR/.config/wezterm/wezterm.lua" ]; then
    echo "❌ Wezterm config not found in dotfiles"
    exit 1
fi

echo "✅ Wezterm config found"
echo ""

# Stow the config
echo "📦 Stowing Wezterm config..."
cd "$DOTFILES_DIR"

# Check if wezterm config already exists
if [ -e "$CONFIG_DIR/wezterm" ] && [ ! -L "$CONFIG_DIR/wezterm" ]; then
    echo "⚠️  Existing wezterm config found (not a symlink)"
    echo "   Backing up to $CONFIG_DIR/wezterm.backup"
    mv "$CONFIG_DIR/wezterm" "$CONFIG_DIR/wezterm.backup"
fi

# Create symlink using stow
stow . 2>&1 | grep -v "BUG in find_stowed_path" || true

if [ -L "$CONFIG_DIR/wezterm/wezterm.lua" ]; then
    echo "✅ Config stowed successfully"
else
    echo "ℹ️  Manual linking: ln -sf $DOTFILES_DIR/.config/wezterm $CONFIG_DIR/wezterm"
    mkdir -p "$CONFIG_DIR"
    ln -sf "$DOTFILES_DIR/.config/wezterm" "$CONFIG_DIR/wezterm"
fi

echo ""

# Test config
echo "🧪 Testing Wezterm config..."
if wezterm ls-fonts &> /dev/null; then
    echo "✅ Config is valid"
else
    echo "❌ Config has errors"
    exit 1
fi

echo ""

# Show font check
echo "📝 Verifying fonts..."
wezterm ls-fonts --list-system | grep -i "jetbrains mono" | head -3 || echo "⚠️  JetBrains Mono not found"

echo ""
echo "================================"
echo "✅ Migration setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open Wezterm: open -a WezTerm"
echo "  2. Test outside Zellij:"
echo "     fastfetch --config \$HOME/dotfiles/.config/fastfetch/config.jsonc"
echo "  3. Test inside Zellij:"
echo "     zellij"
echo "     fastfetch --config \$HOME/dotfiles/.config/fastfetch/config.jsonc"
echo "  4. If all looks good, set Wezterm as default terminal in macOS"
echo ""
echo "To revert: Keep Kitty installed and switch back anytime"
echo ""
