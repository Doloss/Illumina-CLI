local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local Color, Size, Motion, Font, TextSize = Theme.Color, Theme.Size, Theme.Motion, Theme.Font, Theme.TextSize
local Glass = Theme.Glass
local SEGMENT_WIDTH = 78
local SEGMENT_INSET = 3
local TRACK_WIDTH = 120
local TRACK_HEIGHT = 4
local KNOB = 16
local VALUE_WIDTH = 40
local SWATCH_WIDTH = 52
local SWATCH_INSET = 5
local DIALOG_Z = 50
local DIALOG_RISE = 12
local SCRIM_TRANSPARENCY = 0.35
local ROW = Size.control + 8
local ROW_WITH_NOTE = Size.control + 20
local TITLE_LINE = 18
local NOTE_LINE = 16
local GROUP_PAD = 14
local GROUP_TITLE = 16
local GROUP_TITLE_GAP = 8

local Controls = {}

local function isRelease(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Controls.group(parent, title, layoutOrder)
	local holder = Kit.frame(parent, { LayoutOrder = layoutOrder or 0 })
	Kit.list(holder, nil, GROUP_TITLE_GAP)
	if title then
		local heading = Kit.label(holder, {
			Text = title,
			TextSize = TextSize.label,
			TextColor3 = Color.textMuted,
			TextWrapped = false,
			Size = UDim2.new(1, 0, 0, GROUP_TITLE),
			AutomaticSize = Enum.AutomaticSize.None,
		})
		Kit.pad(heading, 0, 0, 0, GROUP_PAD)
	end
	local card = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	}, holder)
	Kit.glass(card, "card", Size.radius.card)
	Kit.pad(card, 0, GROUP_PAD)
	Kit.list(card)
	return card
end

function Controls.row(card, text, layoutOrder, note)
	local order = (layoutOrder or 0) * 2
	if card:GetAttribute("HasRow") then
		Kit.new("Frame", { BackgroundColor3 = Color.glass, BackgroundTransparency = Glass.line, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = order - 1 }, card)
	end
	card:SetAttribute("HasRow", true)

	local row = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, note and ROW_WITH_NOTE or ROW),
		LayoutOrder = order,
	}, card)
	Kit.list(row, Enum.FillDirection.Horizontal, Size.gap, Enum.VerticalAlignment.Center)
	local words = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0, 1), LayoutOrder = 1 }, row)
	Kit.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }, words)
	Kit.list(words, nil, 2, Enum.VerticalAlignment.Center)
	local title = Kit.label(words, {
		Text = text,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, TITLE_LINE),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	if note then
		Kit.label(words, {
			Text = note,
			TextSize = TextSize.badge,
			TextColor3 = Color.textMuted,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, NOTE_LINE),
			AutomaticSize = Enum.AutomaticSize.None,
			LayoutOrder = 1,
		})
	end
	local slot = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	}, row)
	local slotList = Kit.list(slot, Enum.FillDirection.Horizontal, Size.controlGap, Enum.VerticalAlignment.Center)
	slotList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	return row, slot, title
end

function Controls.segmented(parent, options, value, onChange, layoutOrder)
	local frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(#options * SEGMENT_WIDTH + SEGMENT_INSET * 2, Size.control),
		LayoutOrder = layoutOrder or 0,
	}, parent)
	Kit.glass(frame, "control", Size.radius.control)
	local thumb = Kit.new("Frame", {
		BackgroundColor3 = Color.accent,
		BackgroundTransparency = Glass.tint,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(SEGMENT_INSET, SEGMENT_INSET),
		Size = UDim2.new(0, SEGMENT_WIDTH, 1, -SEGMENT_INSET * 2),
	}, frame)
	Kit.corner(thumb, Size.radius.control - SEGMENT_INSET)

	local state = { Frame = frame, value = nil }
	local labels = {}
	local function render(animate)
		thumb.Visible = false
		for index, option in ipairs(options) do
			local active = option.value == state.value
			labels[index].TextColor3 = active and Color.accent or Color.textSecondary
			labels[index].FontFace = active and Font.medium or Font.regular
			if active then
				thumb.Visible = true
				local goal = { Position = UDim2.fromOffset(SEGMENT_INSET + (index - 1) * SEGMENT_WIDTH, SEGMENT_INSET) }
				if animate then
					Kit.tween(thumb, Motion.toggle, goal)
				else
					thumb.Position = goal.Position
				end
			end
		end
	end

	for index, option in ipairs(options) do
		local button = Kit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(SEGMENT_INSET + (index - 1) * SEGMENT_WIDTH, 0),
			Size = UDim2.new(0, SEGMENT_WIDTH, 1, 0),
			ZIndex = 2,
		}, frame)
		local label = Kit.label(button, {
			Text = option.label,
			TextSize = TextSize.label,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
			ZIndex = 2,
		})
		labels[index] = label
		button.MouseEnter:Connect(function()
			if option.value ~= state.value then
				label.TextColor3 = Color.text
			end
		end)
		button.MouseLeave:Connect(function()
			if option.value ~= state.value then
				label.TextColor3 = Color.textSecondary
			end
		end)
		button.Activated:Connect(function()
			if option.value ~= state.value then
				state.Set(option.value, true)
				if onChange then
					onChange(option.value)
				end
			end
		end)
	end

	function state.Set(newValue, animate)
		state.value = newValue
		render(animate)
	end
	state.Set(value, false)
	return state
end

function Controls.slider(parent, opts)
	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(VALUE_WIDTH + Size.controlGap + TRACK_WIDTH, Size.control),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	local valueLabel = Kit.label(holder, {
		TextSize = TextSize.label,
		TextColor3 = Color.textSecondary,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		Size = UDim2.new(0, VALUE_WIDTH, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	local track = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, TRACK_WIDTH, 1, 0),
	}, holder)
	local rail = Kit.new("Frame", {
		BackgroundColor3 = Color.glass,
		BackgroundTransparency = Glass.track,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
	}, track)
	Kit.corner(rail, TRACK_HEIGHT / 2)
	local fill = Kit.new("Frame", { BackgroundColor3 = Color.accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, rail)
	Kit.corner(fill, TRACK_HEIGHT / 2)
	local knob = Kit.new("Frame", {
		BackgroundColor3 = Color.text,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		ZIndex = 2,
	}, rail)
	Kit.corner(knob, KNOB / 2)

	local format = opts.format or function(value)
		return string.format("%.2f", value)
	end
	local current = opts.value
	local function paint(value)
		current = value
		local ratio = math.clamp((value - opts.min) / (opts.max - opts.min), 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.fromScale(ratio, 0.5)
		valueLabel.Text = format(value)
	end
	paint(opts.value)

	local dragging, connection = false, nil
	track.MouseButton1Down:Connect(function()
		if dragging then
			return
		end
		dragging = true
		connection = RunService.RenderStepped:Connect(function()
			local pointer = UserInputService:GetMouseLocation()
			local ratio = math.clamp((pointer.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			local value = math.clamp(math.floor((opts.min + (opts.max - opts.min) * ratio) / opts.step + 0.5) * opts.step, opts.min, opts.max)
			if value ~= current then
				paint(value)
				if opts.onDrag then
					opts.onDrag(value)
				end
			end
		end)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and isRelease(input) then
			dragging = false
			connection:Disconnect()
			connection = nil
			if opts.onCommit then
				opts.onCommit(current)
			end
		end
	end)
	return { Frame = holder, Set = paint }
end

function Controls.swatch(parent, color, onClick, layoutOrder)
	local button = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(SWATCH_WIDTH, Size.control),
		LayoutOrder = layoutOrder or 0,
	}, parent)
	Kit.glass(button, "control", Size.radius.control)
	local chip = Kit.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(SWATCH_INSET, SWATCH_INSET),
		Size = UDim2.new(1, -SWATCH_INSET * 2, 1, -SWATCH_INSET * 2),
	}, button)
	Kit.corner(chip, Size.radius.control - SWATCH_INSET)
	button.MouseEnter:Connect(function()
		Kit.glassTo(button, "hover")
	end)
	button.MouseLeave:Connect(function()
		Kit.glassTo(button, "control")
	end)
	button.Activated:Connect(onClick)
	return {
		Frame = button,
		Set = function(newColor)
			chip.BackgroundColor3 = newColor
		end,
	}
end

function Controls.dialog(gui, width, height, scale)
	local scrim = Kit.new("TextButton", {
		Name = "Dialog",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color.scrim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = DIALOG_Z,
	}, gui)
	local lowered = UDim2.new(0.5, 0, 0.5, DIALOG_RISE)
	local card = Kit.new("CanvasGroup", {
		BackgroundColor3 = Color.pane,
		BackgroundTransparency = Glass.dialog,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = lowered,
		Size = UDim2.fromOffset(width, height),
	}, scrim)
	Kit.corner(card, Size.radius.panel)
	local rim = Kit.rim(card)
	rim.Transparency = 1
	Kit.new("UIScale", { Scale = scale or 1 }, card)
	Kit.tween(rim, Motion.panel, { Transparency = Glass.rim })
	Kit.tween(scrim, Motion.panel, { BackgroundTransparency = SCRIM_TRANSPARENCY })
	Kit.tween(card, Motion.panel, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) })

	local dialog = { Card = card, closed = false }
	function dialog.Close()
		if dialog.closed then
			return
		end
		dialog.closed = true
		Kit.tween(rim, Motion.panel, { Transparency = 1 })
		Kit.tween(scrim, Motion.panel, { BackgroundTransparency = 1 })
		Kit.tween(card, Motion.panel, { GroupTransparency = 1, Position = lowered })
		task.delay(Motion.panel.Time, function()
			scrim:Destroy()
		end)
	end
	return dialog
end

return Controls
