-- Wezterm Configuration
-- Migrated from Kitty - Tokyo Night theme

local wezterm = require("wezterm")
local config = {}

-- Use config builder for better error handling
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- ============================================================================
-- APPEARANCE
-- ============================================================================

config.hide_tab_bar_if_only_one_tab = true
config.enable_tab_bar = false
-- Font Configuration
config.font = wezterm.font_with_fallback({
	{
		family = "JetBrains Mono",
		weight = "Regular",
	},
	"Apple Color Emoji",
	"Noto Color Emoji",
})

config.font_size = 12.0

-- Font variations
config.font_rules = {
	{
		intensity = "Bold",
		italic = false,
		font = wezterm.font({
			family = "JetBrains Mono",
			weight = "Bold",
		}),
	},
	{
		intensity = "Normal",
		italic = true,
		font = wezterm.font({
			family = "JetBrains Mono",
			style = "Italic",
		}),
	},
	{
		intensity = "Bold",
		italic = true,
		font = wezterm.font({
			family = "JetBrains Mono",
			weight = "Bold",
			style = "Italic",
		}),
	},
}

-- Tokyo Night Color Scheme
config.colors = {
	-- Base colors
	foreground = "#c0caf5",
	background = "#1a1b26",

	cursor_bg = "#c0caf5",
	cursor_fg = "#1a1b26",
	cursor_border = "#c0caf5",

	selection_fg = "#c0caf5",
	selection_bg = "#283457",

	scrollbar_thumb = "#292e42",

	split = "#7aa2f7",

	-- ANSI colors
	ansi = {
		"#15161e", -- black
		"#f7768e", -- red
		"#9ece6a", -- green
		"#e0af68", -- yellow
		"#7aa2f7", -- blue
		"#bb9af7", -- magenta
		"#7dcfff", -- cyan
		"#a9b1d6", -- white
	},

	-- Bright ANSI colors
	brights = {
		"#414868", -- bright black
		"#ff899d", -- bright red
		"#9fe044", -- bright green
		"#faba4a", -- bright yellow
		"#8db0ff", -- bright blue
		"#c7a9ff", -- bright magenta
		"#a4daff", -- bright cyan
		"#c0caf5", -- bright white
	},

	-- Indexed colors
	indexed = {
		[16] = "#ff9e64",
		[17] = "#db4b4b",
	},

	-- Tab bar colors
	tab_bar = {
		background = "#1a1b26",

		active_tab = {
			bg_color = "#7aa2f7",
			fg_color = "#16161e",
			intensity = "Bold",
		},

		inactive_tab = {
			bg_color = "#292e42",
			fg_color = "#545c7e",
		},

		inactive_tab_hover = {
			bg_color = "#292e42",
			fg_color = "#7aa2f7",
		},

		new_tab = {
			bg_color = "#292e42",
			fg_color = "#545c7e",
		},

		new_tab_hover = {
			bg_color = "#292e42",
			fg_color = "#7aa2f7",
		},
	},

	-- Visual bell
	visual_bell = "#292e42",

	-- Compose cursor (IME)
	compose_cursor = "#ff9e64",

	-- Copy mode
	copy_mode_active_highlight_bg = { Color = "#283457" },
	copy_mode_active_highlight_fg = { Color = "#c0caf5" },
	copy_mode_inactive_highlight_bg = { Color = "#283457" },
	copy_mode_inactive_highlight_fg = { Color = "#c0caf5" },

	-- Quick select
	quick_select_label_bg = { Color = "#7aa2f7" },
	quick_select_label_fg = { Color = "#16161e" },
	quick_select_match_bg = { Color = "#283457" },
	quick_select_match_fg = { Color = "#c0caf5" },
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

-- Tab bar
config.enable_tab_bar = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false

-- Cursor
config.default_cursor_style = "SteadyBlock"
config.animation_fps = 1
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

-- ============================================================================
-- PERFORMANCE
-- ============================================================================

config.front_end = "WebGpu" -- Use GPU acceleration
config.webgpu_power_preference = "HighPerformance"
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
config.check_for_updates = false

-- Disable ligatures in specific apps if needed
-- config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- Enable shell integration
config.set_environment_variables = {
	TERM_PROGRAM = "WezTerm",
}

return config
