--// Side dock: a solid column of icon tiles on the left edge; lights the tile of the open panel; collapses with the arrow
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Panel = require(script.Parent.Panel)

local Color, Size, Motion, Font, Spring = Theme.Color, Theme.Size, Theme.Motion, Theme.Font, Theme.Spring
local TILE = Theme.Touch and 52 or 44
local DOCK_PAD = 8
local DOCK_RADIUS = 18
local DOCK_WIDTH = TILE + DOCK_PAD * 2
local EDGE = 8
local ARROW = 28
local ICON_SCALE = 0.52
local LABEL_SIZE = 15
local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.94
local REFERENCE_WIDTH = 1280
local MIN_SCALE, MAX_SCALE = 0.55, 1.1
local TOUCH_SCALE = 0.78
local ALIGN = { top = 0, center = 0.5, bottom = 1 }

local Dock = {}
Dock.__index = Dock

local function imageOf(icon)
	local text = tostring(icon)
	return string.sub(text, 1, 3) == "rbx" and text or "rbxassetid://" .. text
end

--// PAINT: tile colour and icon colour together
local function paint(tile, background, foreground)
	tile.button.BackgroundColor3 = background
	if tile.icon:IsA("ImageLabel") then
		tile.icon.ImageColor3 = foreground
	else
		tile.icon.TextColor3 = foreground
	end
end

--// NEW: align is "top", "center" (default) or "bottom": where on the left edge the dock sits
function Dock.new(name, align)
	local y = ALIGN[align] or ALIGN.center
	local inset = (0.5 - y) * 2 * EDGE
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = Workspace.CurrentCamera
	local guiName = name or "IlluminaDock"
	local old = playerGui:FindFirstChild(guiName)
	if old then
		old:Destroy()
	end

	local self = setmetatable({ tiles = {}, count = 0, hidden = false }, Dock)
	self.gui = Kit.new("ScreenGui", { Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
	local guiScale = Kit.new("UIScale", {}, self.gui)
	local function updateScale()
		local scale = math.clamp(camera.ViewportSize.X / REFERENCE_WIDTH, MIN_SCALE, MAX_SCALE)
		guiScale.Scale = Theme.Touch and scale * TOUCH_SCALE or scale
	end
	updateScale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	self.frame = Kit.new("Frame", {
		Name = "Dock",
		BackgroundColor3 = Color.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, y),
		Position = UDim2.new(0, EDGE, y, inset),
		Size = UDim2.fromOffset(DOCK_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, self.gui)
	Kit.corner(self.frame, DOCK_RADIUS)
	Kit.pad(self.frame, DOCK_PAD)
	Kit.list(self.frame, nil, DOCK_PAD)

	--// COLLAPSE: the arrow tile slides the dock off the left edge and back
	local arrow = Kit.new("TextButton", {
		Name = "Collapse",
		Text = "<",
		FontFace = Font.medium,
		TextSize = 16,
		TextColor3 = Color.textSecondary,
		AutoButtonColor = false,
		BackgroundColor3 = Color.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, y),
		Position = UDim2.new(0, EDGE + DOCK_WIDTH + EDGE, y, inset),
		Size = UDim2.fromOffset(ARROW, ARROW),
	}, self.gui)
	Kit.corner(arrow, Size.radius.small)
	arrow.Activated:Connect(function()
		self.hidden = not self.hidden
		arrow.Text = self.hidden and ">" or "<"
		Kit.tween(self.frame, Motion.panel, { Position = UDim2.new(0, self.hidden and -(DOCK_WIDTH + EDGE) or EDGE, y, inset) })
		Kit.tween(arrow, Motion.panel, { Position = UDim2.new(0, self.hidden and EDGE or EDGE + DOCK_WIDTH + EDGE, y, inset) })
	end)

	Panel.Changed:Connect(function(panelName, open)
		for tileName, tile in pairs(self.tiles) do
			if tile.panel == panelName then
				self:SetLit(tileName, open)
			end
		end
	end)
	return self
end

--// ADD: opts { name, icon (image id), label (short text shown when there is no icon), panel (name of the Panel this tile toggles), onClick }
function Dock:Add(opts)
	self.count += 1
	local button = Kit.new("TextButton", {
		Name = opts.name,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(TILE, TILE),
		LayoutOrder = self.count,
	}, self.frame)
	Kit.corner(button, Size.radius.tile)
	local scale = Kit.new("UIScale", {}, button)
	local icon
	if opts.icon then
		icon = Kit.new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(ICON_SCALE, ICON_SCALE),
			Image = imageOf(opts.icon),
		}, button)
	else
		icon = Kit.label(button, {
			Name = "Icon",
			Text = opts.label or string.sub(opts.name, 1, 1),
			FontFace = Font.medium,
			TextSize = LABEL_SIZE,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
		})
	end
	local tile = { button = button, icon = icon, panel = opts.panel }
	self.tiles[opts.name] = tile
	paint(tile, Color.card, Color.textSecondary)

	button.MouseEnter:Connect(function()
		Kit.spring(scale, "Scale", HOVER_SCALE, Spring.release)
	end)
	button.MouseLeave:Connect(function()
		Kit.spring(scale, "Scale", 1, Spring.release)
	end)
	button.MouseButton1Down:Connect(function()
		Kit.spring(scale, "Scale", PRESS_SCALE, Spring.press)
	end)
	button.MouseButton1Up:Connect(function()
		Kit.spring(scale, "Scale", HOVER_SCALE, Spring.release)
	end)
	button.Activated:Connect(function()
		local panel = opts.panel and Panel.get(opts.panel)
		if panel then
			panel:Toggle()
		end
		if opts.onClick then
			opts.onClick()
		end
	end)
	return button
end

--// LIT: true = lighter tile (its panel is open), "accent" = accent fill (a toggle that is on), false or nil = resting
function Dock:SetLit(name, state)
	local tile = self.tiles[name]
	if not tile then
		return
	end
	if state == "accent" then
		paint(tile, Color.accent, Color.onAccent)
	elseif state then
		paint(tile, Color.control, Color.text)
	else
		paint(tile, Color.card, Color.textSecondary)
	end
end

return Dock
