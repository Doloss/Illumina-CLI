--// Settings screen (interface only): each control writes its value to a LocalPlayer attribute named in SETTINGS; nothing here applies a setting
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Illumina = require(ReplicatedStorage:WaitForChild("Illumina"))
local Kit, Controls, Panel, Dock = Illumina.Kit, Illumina.Controls, Illumina.Panel, Illumina.Dock

local PANEL_WIDTH = 400
local PREFIX = "Setting_"
local HUD_HIDDEN_WHILE_OPEN = { "Healthbar", "StaminaGui" }

--// SETTINGS: order is the order on screen; kind is slider, switch or choice
local SETTINGS = {
	{ group = "Audio", key = "MasterVolume", label = "Master volume", kind = "slider", min = 0, max = 100, step = 5, default = 100, suffix = "%" },
	{ group = "Audio", key = "Mute", label = "Mute", kind = "switch", default = false },
	{ group = "General", key = "FieldOfView", label = "Field of view", kind = "slider", min = 60, max = 100, step = 1, default = 70 },
	{ group = "General", key = "CameraShake", label = "Camera shake", kind = "switch", default = true },
	{ group = "General", key = "Crosshair", label = "Crosshair", kind = "switch", default = true },
	{ group = "Graphics", key = "Brightness", label = "Brightness", kind = "slider", min = 0, max = 100, step = 5, default = 50, suffix = "%" },
	{ group = "Graphics", key = "GraphicsMode", label = "Graphics mode", kind = "choice", options = { "Low", "High" }, default = "High" },
	{ group = "Graphics", key = "Decals", label = "Decals", kind = "switch", default = true },
}

local player = Players.LocalPlayer
local panel = Panel.new("Settings", "Settings", nil, PANEL_WIDTH)

local function store(setting, value)
	player:SetAttribute(PREFIX .. setting.key, value)
end

--// START VALUE: an attribute already on the player (a loaded save) wins over the default
local function startValue(setting)
	local saved = player:GetAttribute(PREFIX .. setting.key)
	if type(saved) == type(setting.default) then
		return saved
	end
	return setting.default
end

local build = {}

function build.slider(slot, setting, value)
	local slider = Controls.slider(slot, {
		min = setting.min,
		max = setting.max,
		step = setting.step,
		value = value,
		format = function(current)
			return string.format("%d%s", math.floor(current + 0.5), setting.suffix or "")
		end,
		onCommit = function(current)
			store(setting, current)
		end,
	})
	return slider.Set
end

function build.switch(slot, setting, value)
	local switch = Kit.switch(slot, value, function(on)
		store(setting, on)
	end)
	return function(newValue)
		switch.Set(newValue, true)
	end
end

function build.choice(slot, setting, value)
	local options = {}
	for _, name in ipairs(setting.options) do
		table.insert(options, { label = name, value = name })
	end
	local segmented = Controls.segmented(slot, options, value, function(chosen)
		store(setting, chosen)
	end)
	return function(newValue)
		segmented.Set(newValue, true)
	end
end

local groups = {}
local setters = {}
local groupCount = 0
for index, setting in ipairs(SETTINGS) do
	local card = groups[setting.group]
	if not card then
		groupCount += 1
		card = Controls.group(panel.body, setting.group, groupCount)
		groups[setting.group] = card
	end
	local _, slot = Controls.row(card, setting.label, index)
	local value = startValue(setting)
	setters[setting.key] = build[setting.kind](slot, setting, value)
	store(setting, value)
end

Kit.button(panel.body, { kind = "ghost", text = "Reset to defaults", width = UDim.new(1, 0), layoutOrder = groupCount + 1, onClick = function()
	for _, setting in ipairs(SETTINGS) do
		setters[setting.key](setting.default)
		store(setting, setting.default)
	end
end })

--// HUD: the bars under the panel are hidden while it is open; looked up by name each time because they are rebuilt on respawn
local function showHud(visible)
	for _, name in ipairs(HUD_HIDDEN_WHILE_OPEN) do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = visible
		end
	end
end
panel.onOpen = function()
	showHud(false)
end
panel.onClose = function()
	showHud(true)
end

local dock = Dock.new("HudDock", "bottom")
dock:Add({ name = "Settings", label = "S", panel = "Settings" })
