local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local Color, Motion, Font, Glass = Theme.Color, Theme.Motion, Theme.Font, Theme.Glass
local TAB_WIDTH = 96
local TAB_HEIGHT = 36
local UNDERLINE = 2
local UNDERLINE_INSET = 14

local Tabs = {}

function Tabs.new(parent, names, onSelect, opts)
	local width = opts and opts.width or TAB_WIDTH
	local frame = Kit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, opts and opts.height or TAB_HEIGHT),
		LayoutOrder = opts and opts.layoutOrder or 0,
	}, parent)
	Kit.new("Frame", {
		BackgroundColor3 = Color.glass,
		BackgroundTransparency = Glass.line,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
	}, frame)
	local underline = Kit.new("Frame", {
		BackgroundColor3 = Color.accent,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, UNDERLINE_INSET, 1, 0),
		Size = UDim2.fromOffset(width - UNDERLINE_INSET * 2, UNDERLINE),
		ZIndex = 2,
	}, frame)
	Kit.corner(underline, UNDERLINE / 2)

	local state = { Frame = frame, value = nil }
	local labels = {}

	function state.Select(name, animate)
		state.value = name
		for index, tabName in ipairs(names) do
			local active = tabName == name
			labels[tabName].TextColor3 = active and Color.text or Color.textSecondary
			labels[tabName].FontFace = active and Font.medium or Font.regular
			if active then
				local goal = { Position = UDim2.new(0, (index - 1) * width + UNDERLINE_INSET, 1, 0) }
				if animate then
					Kit.tween(underline, Motion.underline, goal)
				else
					underline.Position = goal.Position
				end
			end
		end
	end

	for index, name in ipairs(names) do
		local button = Kit.new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((index - 1) * width, 0),
			Size = UDim2.new(0, width, 1, 0),
		}, frame)
		labels[name] = Kit.label(button, {
			Text = name,
			TextColor3 = Color.textSecondary,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.None,
		})
		button.MouseEnter:Connect(function()
			if state.value ~= name then
				labels[name].TextColor3 = Color.text
			end
		end)
		button.MouseLeave:Connect(function()
			if state.value ~= name then
				labels[name].TextColor3 = Color.textSecondary
			end
		end)
		button.Activated:Connect(function()
			if state.value ~= name then
				state.Select(name, true)
				if onSelect then
					onSelect(name)
				end
			end
		end)
	end

	state.Select(names[1], false)
	return state
end

return Tabs
