# Wezterm Migration Plan

## Quick Start 🚀

Ready to migrate? Follow these steps:

### 1. Install Wezterm
```bash
brew install --cask wezterm
# or for nightly: brew install --cask wezterm-nightly
```

### 2. Run Migration Script
```bash
cd ~/dotfiles
./bin/migrate-to-wezterm.sh
```

### 3. Test It Out
```bash
# Open Wezterm
open -a WezTerm

# Test image rendering outside Zellij
ff

# Test inside Zellij
zellij
ff
```

### 4. Set as Default (Optional)
- macOS Settings → General → Default Terminal → WezTerm
- Or keep Kitty and use both!

---

## Current State
**Terminal**: Kitty  
**Theme**: Tokyo Night  
**Font**: JetBrains Mono (size 18)  
**Multiplexer**: Zellij  
**Issue**: Image protocols don't work inside Zellij (Kitty doesn't support sixel)

## Migration Checklist

### Pre-Migration
- [x] Analyze current Kitty configuration
- [x] Create Wezterm configuration matching Kitty settings
- [ ] Install Wezterm
- [ ] Test Wezterm outside Zellij
- [ ] Test Wezterm inside Zellij
- [ ] Test fastfetch image rendering in both scenarios

### Migration Steps
- [ ] Install Wezterm via Homebrew
- [ ] Copy Wezterm config to dotfiles
- [ ] Stow Wezterm config
- [ ] Update default terminal app
- [ ] Test all workflows
- [ ] Remove Kitty (optional - keep as backup)

### Post-Migration
- [ ] Update shell aliases if needed
- [ ] Verify image protocols work everywhere
- [ ] Update documentation

## Installation Command

```bash
# Install Wezterm
brew install --cask wezterm

# Or install nightly for latest features
brew install --cask wezterm-nightly
```

## Configuration Location

Wezterm config will be at:
```
~/.config/wezterm/wezterm.lua
```

## Key Differences: Kitty vs Wezterm

| Feature | Kitty | Wezterm |
|---------|-------|---------|
| Config Format | Text conf | Lua scripts |
| Image Protocols | Kitty only | Kitty + Sixel + iTerm2 |
| Multiplexer Support | Limited | Excellent (own mux + sixel passthrough) |
| Performance | Very fast | Fast |
| GPU Acceleration | Yes | Yes |
| Ligatures | Yes | Yes |

## Testing Protocol

### Test 1: Basic Functionality
```bash
# Open Wezterm
wezterm

# Test font rendering
# Test color scheme
# Test key bindings
```

### Test 2: Outside Zellij
```bash
# In Wezterm (not in Zellij)
fastfetch --config "$HOME/dotfiles/.config/fastfetch/config.jsonc"

# Expected: Image renders properly using kitty protocol
```

### Test 3: Inside Zellij
```bash
# Start Zellij in Wezterm
zellij

# Run fastfetch
fastfetch --config "$HOME/dotfiles/.config/fastfetch/config.jsonc"

# Expected: Image renders properly (Zellij passes sixel through)
```

### Test 4: Sixel Protocol
```bash
# Test explicit sixel rendering
# Create test config with sixel protocol
fastfetch --logo-type sixel --logo /Users/momo/.config/nvim/assets/rosie-3.png

# Expected: Works in both scenarios
```

## Rollback Plan

If issues arise:
1. Keep Kitty installed during testing period
2. Switch default terminal back to Kitty in macOS
3. Original configs are preserved
4. Can switch back anytime

## Benefits After Migration

✅ **Image rendering works everywhere**
- Outside Zellij: kitty protocol
- Inside Zellij: sixel passthrough
- No workarounds needed

✅ **Better multiplexer compatibility**
- Native support for image protocols through multiplexers
- Can use Wezterm's built-in multiplexer as alternative

✅ **More flexible configuration**
- Lua scripts allow programmatic config
- Conditional settings based on environment
- Custom key bindings with logic

✅ **Active development**
- Frequent updates
- Good cross-platform support
- Strong community

## Timeline

**Estimated time**: 30-60 minutes
- Install: 5 mins
- Config setup: 10 mins
- Testing: 15-30 mins
- Tweaking: 10-20 mins

## Support

If you encounter issues:
- Wezterm docs: https://wezfurlong.org/wezterm/
- Wezterm GitHub: https://github.com/wez/wezterm
- Can always revert to Kitty
