local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local player = Players.LocalPlayer
local gui = script.Parent
local Parser = require(gui:WaitForChild("CommandParser"))
local shared = ReplicatedStorage:WaitForChild("MonarchShared", 30)
local remotes = shared and shared:WaitForChild("Remotes", 30)
local action = remotes and remotes:WaitForChild("AdminAction", 30)
if not action then return end

local function call(name, userId, payload)
	local ok, reply = pcall(function() return action:InvokeServer(name, userId, payload or {}) end)
	if not ok or type(reply) ~= "table" then return false, "Server unavailable; no automatic retry" end
	return reply.ok == true, reply.message, reply.state
end

local state
for _ = 1, 5 do
	local ok, _, result = call("state")
	if ok then state = result; break end
	task.wait(2)
end
if not state then return end
local allowed = {}
for _, name in ipairs(state.actions) do allowed[name] = true end

local WHITE = Color3.fromRGB(235, 237, 242)
local MUTED = Color3.fromRGB(150, 154, 166)
local GREEN = Color3.fromRGB(137, 222, 154)
local RED = Color3.fromRGB(255, 157, 153)
local MONO = Enum.Font.RobotoMono
local function make(className, parent, properties)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function round(object, radius)
	make("UICorner", object, { CornerRadius = UDim.new(0, radius) })
end
local function label(parent, text, properties)
	local object = make("TextLabel", parent, {
		BackgroundTransparency = 1, Font = MONO, TextSize = 14, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left, Text = text, RichText = false,
	})
	for key, value in pairs(properties or {}) do object[key] = value end
	return object
end

local root = make("Frame", gui, {
	Name = "CommandConsole", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 80,
})
local dock = make("Frame", root, {
	Name = "Dock", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -194),
	Size = UDim2.fromOffset(400, 50), BackgroundTransparency = 1, Visible = false,
})
local panel = make("CanvasGroup", dock, {
	Name = "Terminal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(44, 45, 49),
	BackgroundTransparency = 0.14, GroupTransparency = 1,
})
round(panel, 18)
make("UIStroke", panel, { Color = Color3.fromRGB(180, 185, 196), Transparency = 0.88, Thickness = 1 })
local log = make("ScrollingFrame", panel, {
	Name = "Output", Position = UDim2.fromOffset(17, 12), Size = UDim2.new(1, -34, 1, -64),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
	ScrollBarImageColor3 = MUTED, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
local layout = make("UIListLayout", log, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
local inputRow = make("Frame", panel, {
	Name = "InputRow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 50),
})
label(inputRow, ">", { Position = UDim2.fromOffset(17, 0), Size = UDim2.fromOffset(20, 50), TextSize = 17 })
local ghost = label(inputRow, "", {
	Name = "ArgumentHint", Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -85, 1, 0), TextColor3 = MUTED,
})
local input = make("TextBox", inputRow, {
	Name = "CommandInput", Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -87, 1, 0),
	BackgroundTransparency = 1, ClearTextOnFocus = false, Font = MONO, TextSize = 14,
	TextColor3 = WHITE, PlaceholderColor3 = MUTED, PlaceholderText = "Type a command...",
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", MultiLine = false,
})
local submit = make("TextButton", inputRow, {
	Name = "Submit", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromOffset(43, 50), BackgroundTransparency = 1, Text = "",
	TextColor3 = MUTED, Font = Enum.Font.Gotham, TextSize = 21,
})

make("Frame", submit, { BackgroundColor3 = MUTED, BorderSizePixel = 0, Position = UDim2.fromOffset(26, 17), Size = UDim2.fromOffset(1, 10) })
make("Frame", submit, { BackgroundColor3 = MUTED, BorderSizePixel = 0, Position = UDim2.fromOffset(15, 26), Size = UDim2.fromOffset(12, 1) })
make("Frame", submit, { BackgroundColor3 = MUTED, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(5, 1), Rotation = -45 })
make("Frame", submit, { BackgroundColor3 = MUTED, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 28), Size = UDim2.fromOffset(5, 1), Rotation = 45 })
local suggestionBox = make("CanvasGroup", dock, {
	Name = "Suggestions", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(0, -8),
	Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(24, 25, 29),
	BackgroundTransparency = 0.08, Visible = false,
})
round(suggestionBox, 13)

local opened, busy = false, false
local pending, dockTween
local history, lines, suggestions, buttons = {}, {}, {}, {}
local selected, historyIndex, lineNumber = 1, 1, 0
local refresh, setOpen, run

local function roster()
	local list = {}
	for _, member in ipairs(Players:GetPlayers()) do
		table.insert(list, { userId = member.UserId, name = member.Name, displayName = member.DisplayName })
	end
	table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
	return list
end

local function resize()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local width = math.min(#lines > 0 and 480 or 400, math.max(240, viewport.X - 32))
	local height = 50 + math.min(#lines > 0 and layout.AbsoluteContentSize.Y + 18 or 0, math.min(190, viewport.Y * 0.3))
	if dockTween then dockTween:Cancel() end
	dockTween = TweenService:Create(dock, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(width, height) })
	dockTween:Play()
end

local function write(text, color)
	lineNumber += 1
	local row = label(log, text, {
		Size = UDim2.new(1, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = color or WHITE,
		LayoutOrder = lineNumber,
	})
	table.insert(lines, row)
	if #lines > 60 then table.remove(lines, 1):Destroy() end
	task.defer(function()
		resize()
		log.CanvasPosition = Vector2.new(0, math.max(0, layout.AbsoluteContentSize.Y))
	end)
end

local function cancelPending()
	pending = nil
	input.PlaceholderText = "Type a command..."
end

local function complete()
	local item = suggestions[selected]
	if not item then return end
	input.Text = item.text
	input:CaptureFocus()
	input.CursorPosition = #input.Text + 1
end

refresh = function()
	for _, button in ipairs(buttons) do button:Destroy() end
	buttons = {}
	suggestions = opened and not busy and not pending and input:IsFocused()
		and Parser.Suggest(input.Text, roster(), player.UserId, allowed) or {}
	selected = math.clamp(selected, 1, math.max(1, #suggestions))
	suggestionBox.Visible = #suggestions > 0 and input.Text ~= ""
	local first = math.max(1, selected - 4)
	local count = math.min(5, #suggestions - first + 1)
	suggestionBox.Size = UDim2.new(1, 0, 0, math.max(0, count) * 37 + 8)
	for index = first, math.min(#suggestions, first + 4) do
		local item = suggestions[index]
		local button = make("TextButton", suggestionBox, {
			Position = UDim2.fromOffset(4, 4 + (index - first) * 37), Size = UDim2.new(1, -8, 0, 37),
			Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(70, 73, 82),
			BackgroundTransparency = index == selected and 0.45 or 1,
		})
		round(button, 9)
		label(button, item.label, { Position = UDim2.fromOffset(13, 0), Size = UDim2.new(0.48, 0, 1, 0), Font = Enum.Font.Gotham, TextSize = 13 })
		label(button, item.detail, { Position = UDim2.fromScale(0.48, 0), Size = UDim2.new(0.52, -12, 1, 0), TextColor3 = MUTED, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd })
		button.Activated:Connect(function() selected = index; complete() end)
		table.insert(buttons, button)
	end
	ghost.Text = ""
	local words = Parser.Words(input.Text)
	local definition = Parser.Find(words[1])
	if definition and definition.target and #words == 1 and not pending then
		local size = TextService:GetTextSize(input.Text, 14, MONO, Vector2.new(2000, 50))
		ghost.Position = UDim2.fromOffset(38 + size.X + 8, 0)
		ghost.Size = UDim2.new(1, -100 - size.X, 1, 0)
		ghost.Text = "target:"
	end
end

local function navigation(_, inputState, event)
	if not opened or not input:IsFocused() then return Enum.ContextActionResult.Pass end
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local key = event.KeyCode
	if key == Enum.KeyCode.Escape then
		cancelPending(); setOpen(false)
	elseif key == Enum.KeyCode.Tab then
		complete()
	elseif key == Enum.KeyCode.Up or key == Enum.KeyCode.Down then
		local delta = key == Enum.KeyCode.Up and -1 or 1
		if suggestionBox.Visible then
			selected = (selected - 1 + delta) % #suggestions + 1; refresh()
		else
			historyIndex = math.clamp(historyIndex + delta, 1, #history + 1)
			input.Text = history[historyIndex] or ""
			input.CursorPosition = #input.Text + 1
		end
	end
	return Enum.ContextActionResult.Sink
end

setOpen = function(value)
	opened = value
	if value then
		dock.Visible = true
		resize()
		TweenService:Create(panel, TweenInfo.new(0.18), { GroupTransparency = 0 }):Play()
		CAS:BindActionAtPriority("MonarchConsoleNavigation", navigation, false, 3000,
			Enum.KeyCode.Tab, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Escape)
		task.defer(function() if opened then input:CaptureFocus() end end)
	else
		input:ReleaseFocus()
		cancelPending()
		CAS:UnbindAction("MonarchConsoleNavigation")
		suggestionBox.Visible = false
		TweenService:Create(panel, TweenInfo.new(0.14), { GroupTransparency = 1 }):Play()
		task.delay(0.15, function() if not opened then dock.Visible = false end end)
	end
end

local function dispatch(plan)
	local ok, message = call(plan.action, plan.userId, plan.payload)
	write(ok and "+ OK" or "! REFUSED", ok and GREEN or RED)
	write(message or "No response", ok and GREEN or RED)
end

run = function()
	if busy then return end
	local text = input.Text:match("^%s*(.-)%s*$")
	if text == "" then return end
	busy = true
	suggestionBox.Visible = false
	input.Text = ""
	input.TextEditable = false
	table.insert(history, text)
	if #history > 50 then table.remove(history, 1) end
	historyIndex = #history + 1
	write("> " .. text)
	if pending then
		local saved = pending
		cancelPending()
		if text:lower() == "confirm" and os.clock() <= saved.expires then
			dispatch(saved.plan)
		else
			write("Cancelled or confirmation expired. No action sent.", MUTED)
		end
	else
		local plan, message = Parser.Parse(text, roster(), player.UserId, allowed)
		if not plan then
			write(message, RED)
		elseif plan.name == "clear" then
			for _, row in ipairs(lines) do row:Destroy() end
			lines = {}; resize()
		elseif plan.name == "help" then
			for _, definition in ipairs(Parser.Definitions) do
				if Parser.Allowed(definition, allowed) then write(definition.usage, MUTED) end
			end
			write("Tab complete / Up-Down select / Esc or ; close", MUTED)
		elseif plan.confirm then
			pending = { plan = plan, expires = os.clock() + 30 }
			write(string.upper(plan.name) .. " @" .. plan.targetName .. " (" .. plan.userId .. ")"
				.. (plan.payload.duration and " · " .. plan.payload.duration or ""), WHITE)
			write("Type confirm within 30s, or anything else to cancel.", MUTED)
			input.PlaceholderText = "confirm / cancel"
		else
			dispatch(plan)
		end
	end
	busy = false
	input.TextEditable = true
	if opened then input:CaptureFocus() end
	refresh()
end

input:GetPropertyChangedSignal("Text"):Connect(function()
	if input.Text == ";" then
		input.Text = ""
		return
	end
	if #input.Text > 350 then
		local stop = 350
		while stop > 0 and bit32.band(input.Text:byte(stop + 1), 0xC0) == 0x80 do stop -= 1 end
		input.Text = input.Text:sub(1, stop)
		return
	end
	selected = 1; refresh()
end)
input.Focused:Connect(refresh)
input.FocusLost:Connect(function(enterPressed)
	if enterPressed then task.spawn(run) end
	task.delay(0.15, function() if not input:IsFocused() then suggestionBox.Visible = false end end)
end)
submit.Activated:Connect(function() task.spawn(run) end)
UIS.InputBegan:Connect(function(event, processed)
	if event.KeyCode ~= Enum.KeyCode.Semicolon then return end
	local focused = UIS:GetFocusedTextBox()
	local emptyConsole = focused == input and (input.Text == "" or input.Text == ";")
	if emptyConsole or (not focused and not processed) then
		setOpen(not opened)
	end
end)
Players.PlayerAdded:Connect(refresh)
Players.PlayerRemoving:Connect(function() task.defer(refresh) end)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

local flightRemote = remotes:WaitForChild("AdminFlightInput", 30)
local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
	if not flightRemote or not player:GetAttribute("MonarchFlying") then return end
	elapsed += dt
	if elapsed < 1 / 20 then return end
	elapsed = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	local direction = Vector3.zero
	if not UIS:GetFocusedTextBox() then
		local function down(key) return UIS:IsKeyDown(key) and 1 or 0 end
		direction = camera.CFrame.LookVector * (down(Enum.KeyCode.W) - down(Enum.KeyCode.S))
			+ camera.CFrame.RightVector * (down(Enum.KeyCode.D) - down(Enum.KeyCode.A))
			+ Vector3.yAxis * (down(Enum.KeyCode.Space) - math.max(down(Enum.KeyCode.LeftControl), down(Enum.KeyCode.RightControl)))
	end
	flightRemote:FireServer(direction.Magnitude > 1 and direction.Unit or direction, camera.CFrame.LookVector)
end)
