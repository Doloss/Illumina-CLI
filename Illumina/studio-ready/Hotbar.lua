local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Illumina = require(ReplicatedStorage:WaitForChild("Illumina"))
local Theme, Kit, Panel = Illumina.Theme, Illumina.Kit, Illumina.Panel

local ICONS = {
	Illumina = "rbxassetid://116833070445359",
}
local SLOTS = 1
local HIDE_ROBLOX_BACKPACK = true

local Color, Font = Theme.Color, Theme.Font
local GUI_NAME = "HotbarGui"
local SLOT = 60
local BAR_PAD = 8
local BAR_RADIUS = 16
local BOTTOM_OFFSET = 14
local ICON_INSET = 6
local NUMBER_SIZE = 13
local INITIALS_SIZE = 16
local OUTLINE = 1.5
local PRESS_SCALE = 0.95
local PULSE_HOLD = 0.4
local REFERENCE_WIDTH = 1280
local MIN_SCALE, MAX_SCALE = 0.55, 1.1
local TOUCH_SCALE = 0.8
local REMOTE_WAIT = 5
local FETCH_TRIES = 5
local FETCH_RETRY = 2
local NUMBER_KEYS = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }

local keys = {}
for index = 1, math.min(SLOTS, #NUMBER_KEYS) do
	keys[Enum.KeyCode[NUMBER_KEYS[index]]] = index
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

if HIDE_ROBLOX_BACKPACK then
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end

local old = playerGui:FindFirstChild(GUI_NAME)
if old then
	old:Destroy()
end

local gui = Kit.new("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local guiScale = Kit.new("UIScale", {}, gui)
Panel.hideWhileOpen(gui)
local function updateScale()
	local scale = math.clamp(camera.ViewportSize.X / REFERENCE_WIDTH, MIN_SCALE, MAX_SCALE)
	guiScale.Scale = Theme.Touch and scale * TOUCH_SCALE or scale
end
updateScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local bar = Kit.new("Frame", {
	Name = "SlotBar",
	BackgroundColor3 = Color.panel,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
	Size = UDim2.fromOffset(SLOT * SLOTS + BAR_PAD * (SLOTS + 1), SLOT + BAR_PAD * 2),
	ZIndex = 8,
}, gui)
Kit.corner(bar, BAR_RADIUS)
local barList = Kit.list(bar, Enum.FillDirection.Horizontal, BAR_PAD, Enum.VerticalAlignment.Center)
barList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local slots = {}
local views = {}
local hovered = nil
local fromServer = false

local function initials(sword)
	local spaced = string.gsub(string.gsub(sword, "Sword$", ""), "(%l)(%u)", "%1 %2")
	local letters = {}
	for word in string.gmatch(spaced, "%S+") do
		table.insert(letters, string.sub(word, 1, 1))
	end
	return string.upper(table.concat(letters))
end

local function icon(parent, sword)
	if ICONS[sword] then
		return Kit.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = ICONS[sword], ScaleType = Enum.ScaleType.Fit, ZIndex = 9 }, parent)
	end
	return Kit.label(parent, {
		Text = initials(sword),
		FontFace = Font.medium,
		TextSize = INITIALS_SIZE,
		TextColor3 = Color.textMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 9,
	})
end

local function readSlots(raw)
	local read = {}
	if type(raw) ~= "table" then
		return read
	end
	for index = 1, SLOTS do
		local sword = raw[index] or raw[tostring(index)]
		if type(sword) == "string" then
			read[index] = sword
		end
	end
	return read
end

local function heldName()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool and tool.Name
end

local function paint()
	local held = heldName()
	for index, view in ipairs(views) do
		local holding = held ~= nil and slots[index] == held
		Kit.tween(view.button, Theme.Motion.hover, { BackgroundColor3 = (holding or hovered == index) and Color.control or Color.card })
		if not view.pulsing then
			Kit.tween(view.outline, Theme.Motion.hover, { Transparency = holding and 0 or 1 })
		end
	end
end

local function pulse(index)
	local view = views[index]
	view.pulsing = true
	view.outline.Transparency = 0
	task.delay(PULSE_HOLD, function()
		view.pulsing = false
		paint()
	end)
end

local function holdSlot(index)
	local sword = slots[index]
	if not sword then
		return
	end
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or not backpack then
		return
	end
	local holding = character:FindFirstChild(sword)
	humanoid:UnequipTools()
	if not holding then
		local tool = backpack:FindFirstChild(sword)
		if tool then
			humanoid:EquipTool(tool)
		end
	end
end

for index = 1, SLOTS do
	local button = Kit.new("TextButton", {
		Name = "Slot" .. index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color.card,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(SLOT, SLOT),
		LayoutOrder = index,
		ZIndex = 8,
	}, bar)
	Kit.corner(button, Theme.Size.radius.tile)
	local outline = Kit.stroke(button, Color.accent, OUTLINE)
	outline.Transparency = 1
	local scale = Kit.new("UIScale", {}, button)
	local art = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(ICON_INSET, ICON_INSET),
		Size = UDim2.new(1, -ICON_INSET * 2, 1, -ICON_INSET * 2),
		ZIndex = 9,
	}, button)
	Kit.label(button, {
		Text = tostring(index),
		FontFace = Font.regular,
		TextSize = NUMBER_SIZE,
		TextColor3 = Color.textMuted,
		TextWrapped = false,
		Position = UDim2.fromOffset(5, 3),
		Size = UDim2.fromOffset(14, 14),
		AutomaticSize = Enum.AutomaticSize.None,
		ZIndex = 10,
	})
	views[index] = { button = button, outline = outline, art = art, sword = nil, pulsing = false }

	button.MouseEnter:Connect(function()
		hovered = index
		paint()
	end)
	button.MouseLeave:Connect(function()
		if hovered == index then
			hovered = nil
		end
		Kit.spring(scale, "Scale", 1, Theme.Spring.release)
		paint()
	end)
	button.MouseButton1Down:Connect(function()
		Kit.spring(scale, "Scale", PRESS_SCALE, Theme.Spring.press)
	end)
	button.MouseButton1Up:Connect(function()
		Kit.spring(scale, "Scale", 1, Theme.Spring.release)
	end)
	button.Activated:Connect(function()
		holdSlot(index)
	end)
end

local function apply(rawSlots, announce)
	slots = readSlots(rawSlots)
	for index, view in ipairs(views) do
		if view.sword ~= slots[index] then
			view.sword = slots[index]
			Kit.clear(view.art)
			if view.sword then
				icon(view.art, view.sword)
			end
			if announce then
				pulse(index)
			end
		end
	end
	paint()
end

local function ownSword()
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = (character and character:FindFirstChildOfClass("Tool")) or (backpack and backpack:FindFirstChildOfClass("Tool"))
	return { tool and tool.Name or nil }
end

local function refresh()
	if fromServer then
		paint()
	else
		apply(ownSword(), false)
	end
end

local function queueRefresh()
	task.defer(refresh)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local index = keys[input.KeyCode]
	if index then
		holdSlot(index)
	end
end)

local function watch(container)
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			queueRefresh()
		end
	end)
	container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			queueRefresh()
		end
	end)
	queueRefresh()
end
player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watch(child)
	end
end)
local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
	watch(backpack)
end

task.spawn(function()
	local inventoryUpdated = ReplicatedStorage:WaitForChild("InventoryUpdated", REMOTE_WAIT)
	if inventoryUpdated and inventoryUpdated:IsA("RemoteEvent") then
		inventoryUpdated.OnClientEvent:Connect(function(_, rawSlots)
			if rawSlots ~= nil then
				fromServer = true
				apply(rawSlots, true)
			end
		end)
	end
	local getInventory = ReplicatedStorage:WaitForChild("GetInventory", REMOTE_WAIT)
	if not (getInventory and getInventory:IsA("RemoteFunction")) then
		return
	end
	for _ = 1, FETCH_TRIES do
		local ok, data = pcall(getInventory.InvokeServer, getInventory)
		if ok and type(data) == "table" then
			fromServer = true
			apply(data.slots, false)
			return
		end
		task.wait(FETCH_RETRY)
	end
end)
