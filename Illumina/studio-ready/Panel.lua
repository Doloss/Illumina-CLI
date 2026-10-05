local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local Color, Size, Motion, Font, TextSize = Theme.Color, Theme.Size, Theme.Motion, Theme.Font, Theme.TextSize
local Glass, Spring = Theme.Glass, Theme.Spring
local WIDTH = 400
local PAD = 18
local CLOSE = 32
local BODY_Y = PAD + CLOSE + Size.gap
local REFERENCE_HEIGHT = 720
local MIN_SCALE, MAX_SCALE = 0.8, 1.1
local FIT_SLACK = 2
local CONTENT_JITTER = 1.5
local POP_FROM = 0.86
local POP_CLOSED = 0.95
local RISE_PER_POP = 130
local SHEEN_HEIGHT = 0.4
local BLUR_NAME = "IlluminaBlur"
local DISPLAY_ORDER = 10

local closeAll = Instance.new("BindableEvent")
local changed = Instance.new("BindableEvent")
local panels = {}
local openPanels = {}
local hiddenWhileOpen = {}
local blur = nil

local Panel = {}
Panel.__index = Panel

Panel.Changed = changed.Event

function Panel.get(name)
	return panels[name]
end

function Panel.hideWhileOpen(gui)
	table.insert(hiddenWhileOpen, gui)
	gui.Enabled = next(openPanels) == nil
end

local function setBlur(name, open)
	openPanels[name] = open or nil
	if not blur or not blur.Parent then
		blur = Lighting:FindFirstChild(BLUR_NAME) or Kit.new("BlurEffect", { Name = BLUR_NAME, Size = 0, Enabled = false }, Lighting)
	end
	local any = next(openPanels) ~= nil
	for _, gui in ipairs(hiddenWhileOpen) do
		gui.Enabled = not any
	end
	if any then
		blur.Enabled = true
	end
	Kit.tween(blur, Motion.panel, { Size = any and Glass.blur or 0 })
	if not any then
		task.delay(Motion.panel.Time, function()
			if next(openPanels) == nil then
				blur.Enabled = false
			end
		end)
	end
end

function Panel.new(name, title, bodyGap, width)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local guiName = name .. "Gui"
	local old = playerGui:FindFirstChild(guiName)
	if old then
		old:Destroy()
	end

	local self = setmetatable({ name = name, width = width or WIDTH, isOpen = false, sheet = nil, token = 0, fit = 1, content = 0, base = UDim2.new(), onOpen = nil, onClose = nil, onLayout = nil }, Panel)
	self.gui = Kit.new("ScreenGui", { Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = DISPLAY_ORDER, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
	self.frame = Kit.new("CanvasGroup", {
		Name = "Panel",
		BackgroundColor3 = Color.pane,
		BackgroundTransparency = Glass.pane,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 10,
	}, self.gui)
	Kit.corner(self.frame, Size.radius.panel)
	self.rim = Kit.rim(self.frame)
	self.rim.Transparency = 1
	self.scale = Kit.new("UIScale", {}, self.frame)
	self.pop = Kit.new("NumberValue", { Value = POP_FROM })
	self.pop.Changed:Connect(function()
		self:Place()
	end)

	local sheen = Kit.new("Frame", {
		Name = "Sheen",
		BackgroundColor3 = Color.glass,
		BackgroundTransparency = Glass.paneSheen,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, SHEEN_HEIGHT),
		ZIndex = 0,
	}, self.frame)
	Kit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }, sheen)

	Kit.label(self.frame, {
		Text = title,
		FontFace = Font.semibold,
		TextSize = TextSize.title,
		TextWrapped = false,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -(PAD * 2 + CLOSE), 0, CLOSE),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	self.note = Kit.label(self.frame, {
		Text = "",
		TextSize = TextSize.label,
		TextColor3 = Color.textMuted,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(PAD + CLOSE + Size.gap), 0, PAD),
		Size = UDim2.new(0.5, 0, 0, CLOSE),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	local close = Kit.button(self.frame, { kind = "secondary", text = "×", textSize = 22, width = UDim.new(0, CLOSE), height = CLOSE, padding = 0, radius = Size.radius.small + 2, onClick = function()
		self:SetOpen(false)
	end })
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PAD, 0, PAD)

	self.body = Kit.scroll(self.frame, {
		Position = UDim2.fromOffset(PAD, BODY_Y),
		Size = UDim2.new(1, -PAD * 2, 1, -(BODY_Y + PAD)),
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	})
	self.layout = Kit.list(self.body, nil, bodyGap or Size.gap)

	closeAll.Event:Connect(function(except)
		if except ~= name then
			self:SetOpen(false)
		end
	end)
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:Layout()
	end)
	self.layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self:Layout()
	end)
	self:Layout()
	panels[name] = self
	return self
end

function Panel:Place()
	local pop = self.pop.Value
	self.scale.Scale = self.fit * pop
	self.frame.Position = self.base + UDim2.fromOffset(0, (1 - pop) * RISE_PER_POP)
end

function Panel:Layout()
	local viewport = Workspace.CurrentCamera.ViewportSize
	local sheet = viewport.X < Size.mobileBreakpoint
	local fit = (viewport.X - Size.margin * 2) / self.width
	self.fit = sheet and 1 or math.min(math.clamp(viewport.Y / REFERENCE_HEIGHT, MIN_SCALE, MAX_SCALE), fit)
	local content = self.layout.AbsoluteContentSize.Y / math.max(self.scale.Scale, 0.01)
	if math.abs(content - self.content) > CONTENT_JITTER then
		self.content = content
	end
	local wanted = BODY_Y + self.content + PAD + FIT_SLACK
	if sheet then
		self.frame.AnchorPoint = Vector2.new(0.5, 1)
		self.frame.Size = UDim2.new(1, 0, 0, math.min(wanted, viewport.Y * Size.mobileSheetHeight))
		self.base = UDim2.fromScale(0.5, 1)
	else
		self.frame.AnchorPoint = Vector2.new(0.5, 0.5)
		self.frame.Size = UDim2.fromOffset(self.width, math.min(wanted, viewport.Y / self.fit - Size.margin * 2))
		self.base = UDim2.fromScale(0.5, 0.5)
	end
	self:Place()
	local changed = sheet ~= self.sheet
	self.sheet = sheet
	if changed and self.onLayout then
		task.defer(self.onLayout, sheet)
	end
end

function Panel:SetOpen(open)
	if open == self.isOpen then
		return
	end
	self.isOpen = open
	self.token += 1
	local token = self.token
	local frame = self.frame
	if open then
		closeAll:Fire(self.name)
		if not frame.Visible then
			self.pop.Value = POP_FROM
		end
		frame.Visible = true
		Kit.spring(self.pop, "Value", 1, Spring.pop)
		Kit.tween(frame, Motion.panel, { GroupTransparency = 0 })
		Kit.tween(self.rim, Motion.panel, { Transparency = Glass.rim })
		if self.onOpen then
			task.spawn(self.onOpen)
		end
	else
		Kit.spring(self.pop, "Value", POP_CLOSED, Spring.press)
		Kit.tween(frame, Motion.close, { GroupTransparency = 1 })
		Kit.tween(self.rim, Motion.close, { Transparency = 1 })
		task.delay(Motion.close.Time, function()
			if self.token == token then
				frame.Visible = false
			end
		end)
		if self.onClose then
			task.spawn(self.onClose)
		end
	end
	setBlur(self.name, open)
	changed:Fire(self.name, open)
end

function Panel:Toggle()
	self:SetOpen(not self.isOpen)
end

return Panel
