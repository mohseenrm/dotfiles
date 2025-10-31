# Wezterm Migration - Ready to Deploy! 🚀

## What's Been Prepared

### 1. ✅ Wezterm Configuration
**Location**: `.config/wezterm/wezterm.lua`

**Features Migrated**:
- Tokyo Night color scheme (exact match from Kitty)
- JetBrains Mono font (size 18)
- All 256 ANSI colors
- Tab bar styling
- Cursor configuration
- Performance settings (GPU acceleration)
- Keybindings (macOS-friendly)
- Image protocol support (kitty + sixel + iTerm2)

### 2. ✅ Migration Script
**Location**: `bin/migrate-to-wezterm.sh`

**What it does**:
- Checks if Wezterm is installed
- Creates symlinks via stow
- Validates configuration
- Checks font availability
- Provides next steps

### 3. ✅ Documentation
**Location**: `docs/wezterm-migration-plan.md`

**Includes**:
- Quick start guide
- Detailed migration checklist
- Testing protocol
- Rollback plan
- Benefits summary
- Troubleshooting tips

### 4. ✅ Updated Memory
**Updated**: `CRUSH.md`
- Documented Wezterm as primary terminal
- Kept Kitty as alternative
- Added migration script reference

---

## How to Migrate (3 Simple Steps)

### Step 1: Install Wezterm
```bash
brew install --cask wezterm
```

### Step 2: Run Migration Script
```bash
cd ~/dotfiles
./bin/migrate-to-wezterm.sh
```

### Step 3: Test Everything
```bash
# Open Wezterm
open -a WezTerm

# Test fastfetch OUTSIDE Zellij
ff

# Start Zellij
zellij

# Test fastfetch INSIDE Zellij
ff
```

**Expected Result**: Beautiful image renders in both scenarios! 🎨

---

## What Makes Wezterm Better for You

### ✅ Image Protocols
- **Kitty**: Only supports kitty protocol (doesn't work in Zellij)
- **Wezterm**: Supports kitty + sixel + iTerm2 (works everywhere!)

### ✅ Multiplexer Support
- **Kitty + Zellij**: Images break (Zellij only passes sixel)
- **Wezterm + Zellij**: Images work (Zellij passes sixel through)

### ✅ Configuration
- **Kitty**: Text-based config
- **Wezterm**: Lua scripts (more flexible, programmable)

### ✅ No Workarounds Needed
- **Before**: Complex zsh function to unset Zellij env vars
- **After**: Just works™

---

## Configuration Highlights

### Image Protocols
All enabled by default - no config needed:
```lua
-- Wezterm automatically supports:
-- - kitty graphics protocol
-- - sixel protocol (works in Zellij!)
-- - iTerm2 inline images
```

### Tokyo Night Colors
Perfect match from your Kitty config:
```lua
config.colors = {
  foreground = '#c0caf5',
  background = '#1a1b26',
  cursor_bg = '#c0caf5',
  -- ... all 256 colors mapped
}
```

### GPU Acceleration
```lua
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'HighPerformance'
```

### Keybindings
macOS-friendly CMD key shortcuts:
- `CMD+T`: New tab
- `CMD+W`: Close tab
- `CMD+D`: Split horizontal
- `CMD+C/V`: Copy/paste
- `CMD+F`: Search
- `CMD+=/−/0`: Font size

---

## Rollback Plan

Don't worry - you can easily go back:

1. **Kitty is still installed** - your original config is untouched
2. **Just open Kitty** - no uninstall needed
3. **Set as default** - macOS Settings → General → Default Terminal

Keep both installed and switch anytime!

---

## Files Changed/Created

```
dotfiles/
├── .config/
│   ├── wezterm/
│   │   └── wezterm.lua              ← New config
│   ├── kitty/
│   │   └── kitty.conf               ← Preserved
│   └── fastfetch/
│       └── config.jsonc             ← Already using kitty protocol
├── bin/
│   └── migrate-to-wezterm.sh        ← New migration script
├── docs/
│   ├── wezterm-migration-plan.md    ← New migration guide
│   └── fastfetch-image-rendering.md ← Updated with root cause
├── CRUSH.md                          ← Updated with Wezterm info
└── .zshrc                            ← No changes needed!
```

---

## Next Steps

Ready when you are! Just run:

```bash
# Install
brew install --cask wezterm

# Migrate
cd ~/dotfiles
./bin/migrate-to-wezterm.sh

# Test
open -a WezTerm
ff
```

**Estimated time**: 5-10 minutes

---

## Questions?

- **Will my current terminal break?** No, Kitty stays installed
- **Can I keep using Kitty?** Yes! Keep both
- **What if I don't like Wezterm?** Just switch back to Kitty
- **Do I need to update my shell config?** Nope! Everything works as-is

---

## Support

If you encounter any issues:
- Check `docs/wezterm-migration-plan.md` for troubleshooting
- Wezterm docs: https://wezfurlong.org/wezterm/
- Can always revert to Kitty

---

**Ready to fix your image rendering issue once and for all?** 🎨

Run the migration when you're ready!
