--// Illumina tokens: dark glass panels over a solid HUD, one accent colour (Config), one font family (Config)
local UserInputService = game:GetService("UserInputService")

local Config = require(script.Parent.Config)

local Theme = {}

local FAMILY = Config.fontFamily
local TOUCH = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local ACCENT_HOVER_MIX = 0.2
local ON_ACCENT_MIX = 0.82
local BLUR_SIZE = 22

local function hex(value)
	return Color3.fromHex(value)
end

local function ease(seconds)
	return TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

Theme.Touch = TOUCH

--// COLOURS: panel, card, control and hover are the solid HUD surfaces; pane, glass and well are the layers inside a panel
Theme.Color = table.freeze({
	panel = hex("#15171C"),
	card = hex("#1D2026"),
	control = hex("#282C34"),
	hover = hex("#343944"),
	pane = hex("#101318"),
	glass = hex("#FFFFFF"),
	well = hex("#000000"),
	text = hex("#F2F5F7"),
	textSecondary = hex("#DDE1E6"),
	textMuted = hex("#C6CBD3"),
	accent = Config.accent,
	accentHover = Config.accent:Lerp(hex("#FFFFFF"), ACCENT_HOVER_MIX),
	onAccent = Config.accent:Lerp(hex("#000000"), ON_ACCENT_MIX),
	danger = hex("#E5616F"),
	gold = hex("#E9C46A"),
	scrim = hex("#0B0C0F"),
})

--// BADGES: a badge is tinted with its own text colour
Theme.Badge = table.freeze({
	neutral = table.freeze({ text = hex("#DDE1E6") }),
	accent = table.freeze({ text = Config.accent }),
	danger = table.freeze({ text = hex("#E5616F") }),
	gold = table.freeze({ text = hex("#E9C46A") }),
})

--// GLASS: transparencies of the layers inside a panel; a fill fades toward the bottom by sheen, a rim by rimFade
Theme.Glass = table.freeze({
	pane = 0.24,
	dialog = 0.06,
	card = 0.9,
	control = 0.87,
	hover = 0.78,
	tint = 0.82,
	tintHover = 0.72,
	well = 0.78,
	line = 0.9,
	track = 0.84,
	paneSheen = 0.87,
	sheen = 0.5,
	rim = 0.72,
	rimFade = 0.6,
	blur = Config.blur and BLUR_SIZE or 0,
})

--// SPRINGS: { tension, friction }; lower friction bounces more
Theme.Spring = table.freeze({
	press = table.freeze({ 620, 42 }),
	release = table.freeze({ 420, 16 }),
	pop = table.freeze({ 260, 16 }),
})

--// WEIGHTS: one step heavier than their names; thin strokes do not hold up over glass
Theme.Font = table.freeze({
	regular = Font.new(FAMILY, Enum.FontWeight.Medium),
	medium = Font.new(FAMILY, Enum.FontWeight.SemiBold),
	semibold = Font.new(FAMILY, Enum.FontWeight.Bold),
})

Theme.TextSize = table.freeze({
	value = 24,
	title = 20,
	body = 15,
	label = 13,
	badge = 13,
})

Theme.Size = table.freeze({
	margin = 16,
	pad = 14,
	gap = 12,
	controlGap = 8,
	control = TOUCH and 44 or 34,
	mobileBreakpoint = 700,
	mobileSheetHeight = 0.7,
	radius = table.freeze({ panel = 24, card = 16, tile = 14, control = 14, small = 10 }),
})

Theme.Motion = table.freeze({
	hover = ease(0.12),
	toggle = ease(0.18),
	view = ease(0.18),
	underline = ease(0.2),
	panel = ease(0.25),
	close = ease(0.16),
	value = ease(0.3),
	rowStagger = 0.03,
	rowStaggerCap = 12,
})

return Theme
