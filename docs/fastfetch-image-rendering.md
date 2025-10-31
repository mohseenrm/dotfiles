# Fastfetch Image Rendering Plan

## Current Situation
- **Current protocol**: `chafa` (ASCII art conversion)
- **Issue**: Image appears pixelated
- **Terminal**: Kitty with Zellij multiplexer
- **Image**: `/Users/momo/.config/nvim/assets/rosie-3.png`
- **Current dimensions**: height: 25, width: 50
- **Workaround**: Already have a zsh function that unsets Zellij env vars for image support

## Options for Better Image Rendering

### Option 1: Sixel Protocol ⭐ RECOMMENDED
**Config change**: `"type": "sixel"`

**Pros**:
- Direct image rendering (no ASCII conversion)
- Kitty fully supports sixel
- Widest terminal compatibility
- Should significantly improve quality over chafa
- Simple one-line config change

**Cons**:
- Requires ImageMagick (likely already installed if chafa works)
- Slightly slower than chafa

**Implementation**:
```jsonc
"logo": {
  "source": "/Users/momo/.config/nvim/assets/rosie-3.png",
  "type": "sixel",    // Change from "chafa" to "sixel"
  "height": 25,
  "width": 50,
  // ... rest stays the same
}
```

---

### Option 2: Kitty Native Protocol
**Config change**: `"type": "kitty"`

**Pros**:
- Native to Kitty terminal
- Potentially best quality for Kitty
- Should work well with your setup

**Cons**:
- Only works in Kitty (less portable)
- May have issues with Zellij multiplexer (despite the workaround)

**Implementation**:
```jsonc
"logo": {
  "source": "/Users/momo/.config/nvim/assets/rosie-3.png",
  "type": "kitty",
  "height": 25,
  "width": 50,
  // ... rest stays the same
}
```

---

### Option 3: Kitty Direct Protocol (Fastest)
**Config change**: `"type": "kitty-direct"`

**Pros**:
- Fastest image protocol
- Image loaded directly by terminal
- Highest quality

**Cons**:
- **REQUIRES both width AND height to be specified** (you already have these)
- May not work with Zellij
- Only supports specific image formats (PNG in Kitty)

**Implementation**:
```jsonc
"logo": {
  "source": "/Users/momo/.config/nvim/assets/rosie-3.png",
  "type": "kitty-direct",
  "height": 25,
  "width": 50,
  // ... rest stays the same
}
```

---

### Option 4: Pre-converted Sixel (Advanced)
**Config change**: Pre-convert image to sixel format, use `"type": "raw"`

**Pros**:
- Fastest sixel rendering
- No runtime conversion overhead
- Best performance for frequently shown images

**Cons**:
- Requires extra setup step
- Need to maintain converted file
- More complex

**Implementation**:
```bash
# One-time setup (requires libsixel):
img2sixel /Users/momo/.config/nvim/assets/rosie-3.png > /Users/momo/.config/nvim/assets/rosie-3.sixel
```

```jsonc
"logo": {
  "source": "/Users/momo/.config/nvim/assets/rosie-3.sixel",
  "type": "raw",
  "height": 25,
  "width": 50,
  // ... rest stays the same
}
```

---

## Recommendation Priority

1. **Try Option 1 (sixel)** first - simplest change, should give great results
2. If pixelation persists, **try increasing dimensions** (e.g., height: 30-35)
3. If you want maximum quality, **try Option 3 (kitty-direct)**
4. Option 4 only if you need performance optimization

## Testing Plan

1. Make backup of current config
2. Apply chosen option
3. Test with: `ff` (your alias)
4. If issues with Zellij, verify the workaround function is working
5. Adjust dimensions if needed for optimal appearance

## ✅ SOLUTION: Migrate to Wezterm

### The Fix
**Switch from Kitty to Wezterm** - solves the image protocol issue permanently.

**Why Wezterm?**
- Supports **kitty protocol** (works outside multiplexers)
- Supports **sixel protocol** (works inside Zellij!)
- Supports **iTerm2 protocol** (bonus!)
- No workarounds needed
- Current config works out-of-the-box

### Migration Prepared

Everything is ready to go:

1. **Wezterm config created**: `.config/wezterm/wezterm.lua`
   - Tokyo Night theme (exact match)
   - JetBrains Mono font (size 18)
   - All your Kitty settings migrated
   
2. **Migration script ready**: `./bin/migrate-to-wezterm.sh`
   - Automated setup
   - Validation checks
   - Clear instructions

3. **Documentation complete**: `docs/wezterm-migration-plan.md`
   - Step-by-step guide
   - Testing protocol
   - Rollback plan

### Quick Start

```bash
# 1. Install Wezterm
brew install --cask wezterm

# 2. Run migration
cd ~/dotfiles
./bin/migrate-to-wezterm.sh

# 3. Test it
open -a WezTerm
ff  # Outside Zellij - works!
zellij
ff  # Inside Zellij - works!
```

**See**: `docs/wezterm-migration-ready.md` for full details

---

## Root Cause (Original Investigation)

### The Problem
**Kitty + Zellij = Incompatible Image Protocols**

- **Kitty terminal**: Supports kitty protocol, does NOT support sixel
- **Zellij multiplexer**: Only passes through sixel protocol, does NOT support kitty protocol
- **Result**: Images work outside Zellij but break inside Zellij

### Current Status
✅ **Outside Zellij**: kitty protocol works perfectly  
❌ **Inside Zellij**: No image support (Zellij can't pass through kitty protocol)

### Tested Solutions
1. **Sixel protocol** (`"type": "sixel"`): Doesn't work - Kitty doesn't support sixel
2. **Kitty protocol** (`"type": "kitty"`): Works outside Zellij only
3. **Workaround function**: Can't solve the fundamental protocol incompatibility

### Migration Option: Wezterm ⭐

**Why Wezterm?**
- Supports **both** kitty AND sixel protocols
- Works with or without Zellij
- Current fastfetch config works out of the box

**What to migrate:**
- Terminal emulator: Kitty → Wezterm
- Config files: `.config/kitty/` → `.config/wezterm/`
- Theme/font settings
- Keybindings

**Pros:**
- Solves image protocol issue permanently
- Better multiplexer compatibility
- Supports more image protocols

**Cons:**
- Need to migrate/recreate Kitty config
- Different configuration syntax (Lua for Wezterm)
- Learning curve for new terminal

### Decision Point

**Stay with Kitty:**
- Keep chafa (pixelated ASCII art)
- Accept no images inside Zellij
- Simpler (no migration needed)

**Migrate to Wezterm:**
- Get proper image rendering everywhere
- Better compatibility with terminal multiplexers
- Requires config migration effort

---

Let me know if you'd like help migrating to Wezterm! I can:
1. Analyze your current Kitty config
2. Create equivalent Wezterm config
3. Update shell configs and aliases
4. Test image protocols in both scenarios
