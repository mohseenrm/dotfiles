#!/usr/bin/env bash
# Wezterm + Fastfetch Test Script

echo "🎨 Testing Wezterm Image Rendering"
echo "===================================="
echo ""

echo "✨ Test 1: Outside Zellij (Wezterm direct)"
echo "-------------------------------------------"
echo "Running fastfetch with sixel protocol..."
echo ""

fastfetch --config "$HOME/dotfiles/.config/fastfetch/config.jsonc"

echo ""
echo ""
echo "✅ Did you see the image above? (y/n)"
read -r response1

if [[ "$response1" == "y" ]]; then
    echo "✅ Test 1 PASSED: Sixel works in Wezterm!"
else
    echo "❌ Test 1 FAILED"
    echo "   Try: kitty protocol instead"
    fastfetch --logo-type kitty --logo /Users/momo/.config/nvim/assets/rosie-3.png --logo-width 50 --logo-height 25
fi

echo ""
echo ""
echo "🔄 Test 2: Inside Zellij (multiplexer test)"
echo "-------------------------------------------"
echo "Starting Zellij... (type 'exit' to quit Zellij when done)"
echo ""
echo "Inside Zellij, run: ff"
echo "Then exit Zellij to continue this script"
echo ""
read -p "Press Enter to start Zellij..."

zellij attach test-session 2>/dev/null || zellij -s test-session

echo ""
echo "✅ Did the image render inside Zellij? (y/n)"
read -r response2

echo ""
echo ""
echo "📊 Test Results"
echo "===================================="
if [[ "$response1" == "y" ]]; then
    echo "✅ Outside Zellij: PASS"
else
    echo "❌ Outside Zellij: FAIL"
fi

if [[ "$response2" == "y" ]]; then
    echo "✅ Inside Zellij: PASS"
else
    echo "❌ Inside Zellij: FAIL"
fi

echo ""
if [[ "$response1" == "y" && "$response2" == "y" ]]; then
    echo "🎉 SUCCESS! Image rendering works everywhere!"
    echo ""
    echo "Next steps:"
    echo "  1. Set Wezterm as default terminal (System Settings → General)"
    echo "  2. Enjoy beautiful images in your terminal!"
    echo "  3. Keep Kitty as backup (or uninstall if you want)"
elif [[ "$response1" == "y" ]]; then
    echo "⚠️  Partial success: Works outside Zellij only"
    echo ""
    echo "This might be a Zellij version issue. Try updating Zellij:"
    echo "  brew upgrade zellij"
else
    echo "❌ Tests failed. Let's troubleshoot:"
    echo ""
    echo "Check Wezterm image protocol support:"
    echo "  wezterm ls-fonts"
    echo ""
    echo "Try different protocol in fastfetch config:"
    echo "  Change 'type: sixel' to 'type: kitty' in"
    echo "  .config/fastfetch/config.jsonc"
fi

echo ""
echo "Full docs: docs/wezterm-migration-plan.md"
