--// Illumina building blocks: glass layers, springs, cards, buttons, badges, switch, inputs, avatars
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Kit = {}
local Color, Size, Motion, Font, TextSize = Theme.Color, Theme.Size, Theme.Motion, Theme.Font, Theme.TextSize
local Glass, Spring = Theme.Glass, Theme.Spring
local DISABLED_TRANSPARENCY = 0.6
local PRESS_SCALE = 0.94
local RIM_SELECTED = 2
local SPRING_MAX_STEP = 1 / 30
local SPRING_REST = 0.001
local SHEEN = NumberSequence.new(0, Glass.sheen)
local RIM_FADE = NumberSequence.new(0, Glass.rimFade)
local BADGE_HEIGHT = 22
local STAGGER_RISE = 6
local ICON_IDS = {} --// ICONS: Lucide asset ids by name; a button with no id is text-only
local thumbnails = {}
local parts = setmetatable({}, { __mode = "k" })
local rims = setmetatable({}, { __mode = "k" })
local springs = setmetatable({}, { __mode = "k" })

function Kit.new(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.tween(instance, info, goal)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

--// SPRING: drives a number property to a goal with overshoot; a new goal keeps the current velocity, so it can be interrupted
function Kit.spring(instance, property, goal, preset)
	local state = springs[instance]
	if not state then
		state = { velocity = 0 }
		springs[instance] = state
	end
	state.goal, state.tension, state.friction = goal, preset[1], preset[2]
	if state.connection then
		return
	end
	state.connection = RunService.RenderStepped:Connect(function(delta)
		local step = math.min(delta, SPRING_MAX_STEP)
		local value = instance[property]
		state.velocity += ((state.goal - value) * state.tension - state.velocity * state.friction) * step
		value += state.velocity * step
		if math.abs(state.goal - value) < SPRING_REST and math.abs(state.velocity) < SPRING_REST * 10 then
			value, state.velocity = state.goal, 0
			state.connection:Disconnect()
			state.connection = nil
		end
		instance[property] = value
	end)
end

function Kit.corner(parent, radius)
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

function Kit.stroke(parent, color, thickness)
	return Kit.new("UIStroke", { Color = color, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

--// RIM: thin light edge, brightest at the top
function Kit.rim(frame)
	local stroke = Kit.stroke(frame, Color.glass)
	stroke.Transparency = Glass.rim
	local gradient = Kit.new("UIGradient", { Rotation = 90, Transparency = RIM_FADE }, stroke)
	rims[frame] = { stroke = stroke, gradient = gradient }
	return stroke
end

--// SELECTED RIM: a solid colour marks the frame as chosen; nil puts the glass rim back
function Kit.setRim(frame, color)
	local rim = rims[frame]
	if not rim then
		return
	end
	rim.stroke.Color = color or Color.glass
	rim.stroke.Transparency = color and 0 or Glass.rim
	rim.stroke.Thickness = color and RIM_SELECTED or 1
	rim.gradient.Enabled = color == nil
end

--// GLASS: lighter translucent layer with a top sheen and a rim; level is a Theme.Glass key
function Kit.glass(frame, level, radius)
	frame.BackgroundColor3 = Color.glass
	frame.BackgroundTransparency = Glass[level or "card"]
	frame.BorderSizePixel = 0
	if radius then
		Kit.corner(frame, radius)
	end
	Kit.new("UIGradient", { Rotation = 90, Transparency = SHEEN }, frame)
	return Kit.rim(frame)
end

function Kit.glassTo(frame, level)
	return Kit.tween(frame, Motion.hover, { BackgroundTransparency = Glass[level] })
end

--// PRESSABLE: a centred face inside the button that squashes on press and springs back; content goes in the face
function Kit.pressable(button)
	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, button)
	local scale = Kit.new("UIScale", {}, face)
	button.MouseButton1Down:Connect(function()
		Kit.spring(scale, "Scale", PRESS_SCALE, Spring.press)
	end)
	button.MouseButton1Up:Connect(function()
		Kit.spring(scale, "Scale", 1, Spring.release)
	end)
	button.MouseLeave:Connect(function()
		Kit.spring(scale, "Scale", 1, Spring.release)
	end)
	return face, scale
end

function Kit.pad(parent, top, right, bottom, left)
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	}, parent)
end

function Kit.list(parent, direction, gap, alignment)
	return Kit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = alignment or Enum.VerticalAlignment.Top,
	}, parent)
end

function Kit.frame(parent, props)
	local base = { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y }
	for key, value in pairs(props or {}) do
		base[key] = value
	end
	return Kit.new("Frame", base, parent)
end

function Kit.label(parent, props)
	local base = {
		BackgroundTransparency = 1,
		FontFace = Font.regular,
		TextSize = TextSize.body,
		TextColor3 = Color.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		RichText = false,
	}
	for key, value in pairs(props or {}) do
		base[key] = value
	end
	return Kit.new("TextLabel", base, parent)
end

--// CARD: one section of the panel; children stack with the standard gap
function Kit.card(parent, layoutOrder, padding, gap)
	local card = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = layoutOrder or 0,
	}, parent)
	Kit.glass(card, "card", Size.radius.card)
	Kit.pad(card, padding or Size.pad)
	Kit.list(card, nil, gap or Size.gap)
	return card
end

--// HEAD: card title on the left, optional value on the right (big = value-sized)
function Kit.head(parent, title, big)
	local head = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, big and 28 or 18),
		LayoutOrder = 0,
	}, parent)
	Kit.label(head, {
		Text = title,
		TextSize = TextSize.label,
		TextColor3 = Color.textMuted,
		TextWrapped = false,
		TextYAlignment = big and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(0.3, 1),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	local value = Kit.label(head, {
		Text = "",
		RichText = true,
		FontFace = big and Font.medium or Font.regular,
		TextSize = big and TextSize.value or TextSize.badge,
		TextColor3 = big and Color.text or Color.textMuted,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = big and Enum.TextYAlignment.Bottom or Enum.TextYAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.7, 1),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	return head, value
end

function Kit.icon(parent, name, size, color)
	if not ICON_IDS[name] then
		return nil
	end
	local px = size or 14
	return Kit.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. ICON_IDS[name],
		ImageColor3 = color or Color.textSecondary,
		Size = UDim2.fromOffset(px, px),
	}, parent)
end

--// STYLES: fill colour with its resting and hover transparency; solid = no sheen or rim; ring = rim colour while in that style
local STYLES = table.freeze({
	primary = table.freeze({ fill = Color.accent, hover = Color.accentHover, rest = 0, lit = 0, text = Color.onAccent, font = Font.medium, solid = true }),
	secondary = table.freeze({ fill = Color.glass, hover = Color.glass, rest = Glass.control, lit = Glass.hover, text = Color.text, font = Font.regular }),
	danger = table.freeze({ fill = Color.danger, hover = Color.danger, rest = Glass.tint, lit = Glass.tintHover, text = Color.danger, font = Font.regular }),
	ghost = table.freeze({ fill = Color.glass, hover = Color.glass, rest = 1, lit = Glass.control, text = Color.textSecondary, font = Font.regular, solid = true }),
	stepper = table.freeze({ fill = Color.glass, hover = Color.glass, rest = Glass.card, lit = Glass.hover, text = Color.textSecondary, font = Font.regular }),
	selected = table.freeze({ fill = Color.accent, hover = Color.accent, rest = Glass.tint, lit = Glass.tint, text = Color.accent, font = Font.medium, ring = Color.accent }),
})

local function paint(button, hovering)
	local part = parts[button]
	if not part or button:GetAttribute("Disabled") then
		return
	end
	local style = part.style
	Kit.tween(part.face, Motion.hover, {
		BackgroundColor3 = hovering and style.hover or style.fill,
		BackgroundTransparency = hovering and style.lit or style.rest,
	})
end

local function press(button, down)
	local part = parts[button]
	if part and not button:GetAttribute("Disabled") then
		Kit.spring(part.scale, "Scale", down and PRESS_SCALE or 1, down and Spring.press or Spring.release)
	end
end

--// BUTTON: opts { kind, text, textSize, icon, height, width (UDim), radius, padding, onClick, layoutOrder }
function Kit.button(parent, opts)
	local style = STYLES[opts.kind or "secondary"]
	local height = opts.height or Size.control
	local fixedWidth = opts.width ~= nil
	local button = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(opts.width or UDim.new(0, 0), UDim.new(0, height)),
		AutomaticSize = fixedWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)

	local face = Kit.new("Frame", {
		Name = "Face",
		BackgroundColor3 = style.fill,
		BackgroundTransparency = style.rest,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, button)
	Kit.corner(face, opts.radius or Size.radius.control)
	if not style.solid then
		Kit.new("UIGradient", { Rotation = 90, Transparency = SHEEN }, face)
		Kit.rim(face)
	end
	local scale = Kit.new("UIScale", {}, face)

	local content = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = fixedWidth and UDim2.fromScale(1, 1) or UDim2.new(0, 0, 1, 0),
		AutomaticSize = fixedWidth and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		ZIndex = 2,
	}, button)
	Kit.pad(content, 0, opts.padding or 12)
	local row = Kit.list(content, Enum.FillDirection.Horizontal, 6, Enum.VerticalAlignment.Center)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local iconLabel = opts.icon and Kit.icon(content, opts.icon, 14, style.text) or nil
	if iconLabel then
		iconLabel.ZIndex = 2
	end
	local textLabel = Kit.label(content, {
		Text = opts.text or "",
		FontFace = style.font,
		TextSize = opts.textSize or TextSize.body,
		TextColor3 = style.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		ZIndex = 2,
	})

	parts[button] = { face = face, label = textLabel, scale = scale, style = style, base = style }

	button.MouseEnter:Connect(function()
		paint(button, true)
	end)
	button.MouseLeave:Connect(function()
		paint(button, false)
		press(button, false)
	end)
	button.MouseButton1Down:Connect(function()
		press(button, true)
	end)
	button.MouseButton1Up:Connect(function()
		press(button, false)
	end)
	button.Activated:Connect(function()
		if not button:GetAttribute("Disabled") and opts.onClick then
			opts.onClick()
		end
	end)

	return button, textLabel
end

function Kit.setEnabled(button, enabled)
	button:SetAttribute("Disabled", not enabled)
	button.Active = enabled
	local part = parts[button]
	if part then
		part.label.TextTransparency = enabled and 0 or DISABLED_TRANSPARENCY
		part.scale.Scale = 1
	end
end

--// SELECTED: accent-tinted state for a chosen option
function Kit.setSelected(button, selected)
	local part = parts[button]
	if not part then
		return
	end
	local style = selected and STYLES.selected or part.base
	part.style = style
	part.face.BackgroundColor3 = style.fill
	part.face.BackgroundTransparency = style.rest
	Kit.setRim(part.face, style.ring)
	part.label.TextColor3 = style.text
	part.label.FontFace = style.font
end

--// BADGE: chip tinted with its own text colour; tone is a Theme.Badge key
function Kit.badge(parent, text, tone, layoutOrder)
	local colors = Theme.Badge[tone] or Theme.Badge.neutral
	local badge = Kit.new("Frame", {
		BackgroundColor3 = colors.text,
		BackgroundTransparency = Glass.tint,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, BADGE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = layoutOrder or 0,
	}, parent)
	Kit.corner(badge, Size.radius.small)
	Kit.pad(badge, 0, 8)
	local label = Kit.label(badge, {
		Text = text,
		TextSize = TextSize.badge,
		TextColor3 = colors.text,
		TextWrapped = false,
		Size = UDim2.fromOffset(0, BADGE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	return badge, label
end

--// SWITCH: returns { Frame, Set(value, animate) }; onChange(value) fires on user taps
function Kit.switch(parent, value, onChange, layoutOrder, offColor)
	local off = offColor or Color.glass
	local offTransparency = offColor and 0 or Glass.track
	local track = Kit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(34, 20),
		LayoutOrder = layoutOrder or 0,
	}, parent)
	Kit.corner(track, 10)
	local knob = Kit.new("Frame", { BorderSizePixel = 0, Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0, 0.5) }, track)
	Kit.corner(knob, 7)
	local state = { Frame = track, value = value == true }

	local function render(animate)
		local on = state.value
		local trackGoal = { BackgroundColor3 = on and Color.accent or off, BackgroundTransparency = on and 0 or offTransparency }
		local knobGoal = { Position = UDim2.new(0, on and 17 or 3, 0.5, 0), BackgroundColor3 = on and Color.onAccent or Color.textSecondary }
		if animate then
			Kit.tween(track, Motion.toggle, trackGoal)
			Kit.tween(knob, Motion.toggle, knobGoal)
		else
			track.BackgroundColor3, track.BackgroundTransparency = trackGoal.BackgroundColor3, trackGoal.BackgroundTransparency
			knob.Position, knob.BackgroundColor3 = knobGoal.Position, knobGoal.BackgroundColor3
		end
	end

	function state.Set(newValue, animate)
		state.value = newValue == true
		render(animate)
	end

	track.Activated:Connect(function()
		state.Set(not state.value, true)
		if onChange then
			onChange(state.value)
		end
	end)
	render(false)
	return state
end

--// INPUT: opts { placeholder, suffix, digits, width (UDim), height, text, fill, layoutOrder }
function Kit.input(parent, opts)
	local holder = Kit.new("Frame", {
		Size = UDim2.new(opts.width or UDim.new(1, 0), UDim.new(0, opts.height or Size.control)),
		LayoutOrder = opts.layoutOrder or 0,
	}, parent)
	Kit.glass(holder, "control", Size.radius.control)
	if opts.fill then
		holder.BackgroundColor3, holder.BackgroundTransparency = opts.fill, 0
	end
	Kit.pad(holder, 0, 12)
	local box = Kit.new("TextBox", {
		BackgroundTransparency = 1,
		Text = opts.text or "",
		PlaceholderText = opts.placeholder or "",
		PlaceholderColor3 = Color.textMuted,
		TextColor3 = Color.text,
		FontFace = Font.regular,
		TextSize = TextSize.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, opts.suffix and -34 or 0, 1, 0),
	}, holder)
	if opts.suffix then
		Kit.label(holder, {
			Text = opts.suffix,
			TextSize = TextSize.label,
			TextColor3 = Color.textMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			Size = UDim2.new(0, 30, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.new(1, -30, 0, 0),
		})
	end
	if opts.digits then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local cleaned = string.gsub(box.Text, "[^%d]", "")
			if cleaned ~= box.Text then
				box.Text = cleaned
			end
		end)
	end
	box.Focused:Connect(function()
		Kit.setRim(holder, Color.accent)
	end)
	box.FocusLost:Connect(function()
		Kit.setRim(holder, nil)
	end)
	return box, holder
end

--// AVATAR: Roblox headshot, cached per UserId; shows the name's initial until it loads or if it fails
function Kit.avatar(parent, userId, size, radius, name, layoutOrder)
	local tile = Kit.new("Frame", {
		BackgroundColor3 = Color.glass,
		BackgroundTransparency = Glass.control,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = layoutOrder or 0,
	}, parent)
	Kit.corner(tile, radius)
	local initial = Kit.label(tile, {
		Text = string.upper(string.sub(name or "?", 1, 1)),
		FontFace = Font.medium,
		TextSize = math.floor(size * 0.4),
		TextColor3 = Color.textMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	local image = Kit.new("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = thumbnails[userId] or "",
		ZIndex = 2,
	}, tile)
	Kit.corner(image, radius)
	if thumbnails[userId] then
		initial.Visible = false
	else
		task.spawn(function()
			local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			if ok and type(url) == "string" then
				thumbnails[userId] = url
				if image.Parent then
					image.Image = url
					initial.Visible = false
				end
			end
		end)
	end
	return tile
end

--// COUNT: animates a number label to its new value; format(number) returns the text
function Kit.countTo(label, from, to, format)
	if from == to then
		label.Text = format(to)
		return
	end
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(current)
		label.Text = format(current)
	end)
	local tween = TweenService:Create(value, Motion.value, { Value = to })
	tween.Completed:Connect(function()
		label.Text = format(to)
		value:Destroy()
	end)
	tween:Play()
end

--// STAGGER: fades and lifts a CanvasGroup row in, a little later for each index
function Kit.stagger(group, index)
	if index > Motion.rowStaggerCap then
		return
	end
	group.GroupTransparency = 1
	group.Position = UDim2.fromOffset(0, STAGGER_RISE)
	task.delay((index - 1) * Motion.rowStagger, function()
		if group.Parent then
			Kit.tween(group, Motion.view, { GroupTransparency = 0, Position = UDim2.new() })
		end
	end)
end

function Kit.scroll(parent, props)
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color.glass,
		ScrollBarImageTransparency = Glass.hover,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for key, value in pairs(props or {}) do
		base[key] = value
	end
	return Kit.new("ScrollingFrame", base, parent)
end

function Kit.clear(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

return Kit
