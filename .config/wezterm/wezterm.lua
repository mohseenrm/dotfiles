-- Wezterm Configuration
-- Cobalt Kinetic (Brutus) theme

local wezterm = require("wezterm")
local config = {}

-- Use config builder for better error handling
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- ============================================================================
-- APPEARANCE
-- ============================================================================

-- Tab bar
config.enable_tab_bar = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false

-- Font Configuration
config.font = wezterm.font_with_fallback({
	{
		family = "JetBrainsMono Nerd Font",
		weight = "Medium",
		harfbuzz_features = { "calt", "liga" },
	},
	"Apple Color Emoji",
	"Noto Color Emoji",
})

config.font_size = 18.0

-- Font rendering options for sharper text
config.freetype_load_target = "HorizontalLcd"
config.freetype_render_target = "HorizontalLcd"

-- Font variations
config.font_rules = {
	{
		intensity = "Bold",
		italic = false,
		font = wezterm.font({
			family = "JetBrains Mono",
			weight = "Bold",
			harfbuzz_features = { "calt", "liga" },
		}),
	},
	{
		intensity = "Normal",
		italic = true,
		font = wezterm.font({
			family = "JetBrains Mono",
			weight = "Medium",
			style = "Italic",
			harfbuzz_features = { "calt", "liga" },
		}),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font({
			family = "JetBrains Mono",
			weight = "Bold",
			style = "Italic",
			harfbuzz_features = { "calt", "liga" },
		}),
	},
}

-- Cobalt Kinetic (Brutus) Color Scheme
config.colors = {
	-- Base colors
	foreground = "#e0e5f6",
	background = "#05080f",

	cursor_bg = "#e0e5f6",
	cursor_fg = "#05080f",
	cursor_border = "#e0e5f6",

	selection_fg = "#e0e5f6",
	selection_bg = "#172030",

	scrollbar_thumb = "#0d1220",

	split = "#7bafff",

	-- ANSI colors
	ansi = {
		"#020408", -- black (surface_floor)
		"#ff716c", -- red (error)
		"#50fa7b", -- green (string/added)
		"#ffd866", -- yellow (class/search)
		"#7bafff", -- blue (primary)
		"#c792ea", -- magenta (keyword)
		"#00fbfb", -- cyan (secondary)
		"#9ba1b0", -- white (on_surface_muted)
	},

	-- Bright ANSI colors
	brights = {
		"#28344c", -- bright black (surface_nested)
		"#ff79c6", -- bright red (baby_pink)
		"#73fdab", -- bright green (vibrant_green)
		"#ffe08a", -- bright yellow (sun)
		"#5e9eff", -- bright blue (primary_deep)
		"#ff79c6", -- bright magenta (baby_pink)
		"#00d9d9", -- bright cyan (teal)
		"#e0e5f6", -- bright white (on_surface)
	},

	-- Indexed colors
	indexed = {
		[16] = "#ff9e64",
		[17] = "#ff716c",
	},

	-- Tab bar colors
	tab_bar = {
		background = "#05080f",

		active_tab = {
			bg_color = "#7bafff",
			fg_color = "#05080f",
			intensity = "Bold",
		},

		inactive_tab = {
			bg_color = "#0d1220",
			fg_color = "#707584",
		},

		inactive_tab_hover = {
			bg_color = "#0d1220",
			fg_color = "#7bafff",
		},

		new_tab = {
			bg_color = "#0d1220",
			fg_color = "#707584",
		},

		new_tab_hover = {
			bg_color = "#0d1220",
			fg_color = "#7bafff",
		},
	},

	-- Visual bell
	visual_bell = "#0d1220",

	-- Compose cursor (IME)
	compose_cursor = "#ff9e64",

	-- Copy mode
	copy_mode_active_highlight_bg = { Color = "#172030" },
	copy_mode_active_highlight_fg = { Color = "#e0e5f6" },
	copy_mode_inactive_highlight_bg = { Color = "#172030" },
	copy_mode_inactive_highlight_fg = { Color = "#e0e5f6" },

	-- Quick select
	quick_select_label_bg = { Color = "#7bafff" },
	quick_select_label_fg = { Color = "#05080f" },
	quick_select_match_bg = { Color = "#172030" },
	quick_select_match_fg = { Color = "#e0e5f6" },
}

-- Window appearance
config.window_background_opacity = 1.0
config.window_decorations = "RESIZE"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

-- Cursor
config.default_cursor_style = "SteadyBlock"
config.animation_fps = 1
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ============================================================================
-- PERFORMANCE
-- ============================================================================

config.front_end = "OpenGL" -- Use GPU acceleration
config.max_fps = 240

-- Scrollback
config.scrollback_lines = 10000

-- ============================================================================
-- BELL
-- ============================================================================

config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_function = "EaseIn",
	fade_in_duration_ms = 150,
	fade_out_function = "EaseOut",
	fade_out_duration_ms = 150,
}

-- ============================================================================
-- MOUSE
-- ============================================================================

config.mouse_bindings = {
	-- Open URLs on click
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.OpenLinkAtMouseCursor,
	},

	-- Paste on middle click
	{
		event = { Up = { streak = 1, button = "Middle" } },
		mods = "NONE",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
}

-- ============================================================================
-- IMAGE PROTOCOLS
-- ============================================================================

-- Wezterm supports multiple image protocols:
-- - kitty graphics protocol
-- - sixel
-- - iTerm2 inline images
-- All are enabled by default and work with multiplexers like Zellij

-- ============================================================================
-- KEYBINDINGS
-- ============================================================================

config.keys = {
	-- Tabs
	{
		key = "t",
		mods = "CMD",
		action = wezterm.action.SpawnTab("CurrentPaneDomain"),
	},
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentTab({ confirm = true }),
	},

	-- Panes
	{
		key = "d",
		mods = "CMD",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "d",
		mods = "CMD|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},

	-- Copy/Paste
	{
		key = "c",
		mods = "CMD",
		action = wezterm.action.CopyTo("Clipboard"),
	},
	{
		key = "v",
		mods = "CMD",
		action = wezterm.action.PasteFrom("Clipboard"),
	},

	-- Font size
	{
		key = "=",
		mods = "CMD",
		action = wezterm.action.IncreaseFontSize,
	},
	{
		key = "-",
		mods = "CMD",
		action = wezterm.action.DecreaseFontSize,
	},
	{
		key = "0",
		mods = "CMD",
		action = wezterm.action.ResetFontSize,
	},

	-- Search
	{
		key = "f",
		mods = "CMD",
		action = wezterm.action.Search("CurrentSelectionOrEmptyString"),
	},

	-- Reload config
	{
		key = "r",
		mods = "CMD|SHIFT",
		action = wezterm.action.ReloadConfiguration,
	},
}

-- ============================================================================
-- HYPERLINKS
-- ============================================================================

-- Enable clickable hyperlinks
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- Add custom rules for common patterns
table.insert(config.hyperlink_rules, {
	regex = [[\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b]],
	format = "mailto:$0",
})

-- ============================================================================
-- MISC
-- ============================================================================

-- Shell
-- Uses default shell from $SHELL

-- Exit behavior
config.exit_behavior = "Close"

-- Confirm before closing
config.window_close_confirmation = "NeverPrompt"

-- Check for updates
config.check_for_updates = true

-- Disable ligatures in specific apps if needed
-- config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- Enable shell integration
config.set_environment_variables = {
	TERM_PROGRAM = "WezTerm",
}

return config
