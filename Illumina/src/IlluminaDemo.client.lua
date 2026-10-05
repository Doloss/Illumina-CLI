--// Illumina demo: one panel showing every part, opened from a dock tile. Delete this script once the game has its own screens
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Illumina = require(ReplicatedStorage:WaitForChild("Illumina"))
local Theme, Kit, Controls, Panel, Dock, Tabs = Illumina.Theme, Illumina.Kit, Illumina.Controls, Illumina.Panel, Illumina.Dock, Illumina.Tabs

local Color, Size, TextSize = Theme.Color, Theme.Size, Theme.TextSize
local PANEL_WIDTH = 400
local SCORE_STEP = 250
local DIALOG_WIDTH, DIALOG_HEIGHT = 280, 156

local panel = Panel.new("Demo", "Illumina", nil, PANEL_WIDTH)
panel.note.Text = "Demo"

local pages = {}
local function show(name)
	for pageName, page in pairs(pages) do
		page.Visible = pageName == name
	end
end
Tabs.new(panel.body, { "Controls", "Cards" }, show)

--// CONTROLS PAGE: grouped rows, a text input and the three button kinds
local controlsPage = Kit.frame(panel.body, { LayoutOrder = 1 })
Kit.list(controlsPage, nil, Size.gap)
pages.Controls = controlsPage

local group = Controls.group(controlsPage, "Controls", 1)
local _, switchSlot = Controls.row(group, "Switch", 1, "A setting that is on or off")
Kit.switch(switchSlot, true)
local _, choiceSlot = Controls.row(group, "Choice", 2)
Controls.segmented(choiceSlot, { { label = "One", value = 1 }, { label = "Two", value = 2 }, { label = "Three", value = 3 } }, 1)
local _, sliderSlot = Controls.row(group, "Slider", 3)
Controls.slider(sliderSlot, { min = 0, max = 1, step = 0.05, value = 0.5, onDrag = function() end, onCommit = function() end })
local _, swatchSlot = Controls.row(group, "Colour", 4)
Controls.swatch(swatchSlot, Color.accent, function() end)

Kit.input(controlsPage, { placeholder = "Type here", layoutOrder = 2 })

local buttons = Kit.frame(controlsPage, { LayoutOrder = 3 })
Kit.list(buttons, Enum.FillDirection.Horizontal, Size.controlGap)
Kit.button(buttons, { kind = "primary", text = "Primary", layoutOrder = 1 })
Kit.button(buttons, { kind = "secondary", text = "Secondary", layoutOrder = 2 })
Kit.button(buttons, { kind = "danger", text = "Danger", layoutOrder = 3 })

--// CARDS PAGE: a card with a counting value, badges and a dialog
local cardsPage = Kit.frame(panel.body, { LayoutOrder = 2 })
Kit.list(cardsPage, nil, Size.gap)
pages.Cards = cardsPage

local card = Kit.card(cardsPage, 1)
local _, scoreLabel = Kit.head(card, "Score", true)
local score = 0
local function formatScore(value)
	return tostring(math.floor(value + 0.5))
end
scoreLabel.Text = formatScore(score)
Kit.button(card, { kind = "secondary", text = "Add " .. SCORE_STEP, width = UDim.new(1, 0), layoutOrder = 1, onClick = function()
	Kit.countTo(scoreLabel, score, score + SCORE_STEP, formatScore)
	score += SCORE_STEP
end })

local badges = Kit.frame(cardsPage, { LayoutOrder = 2 })
Kit.list(badges, Enum.FillDirection.Horizontal, Size.controlGap)
Kit.badge(badges, "Neutral", "neutral", 1)
Kit.badge(badges, "Accent", "accent", 2)
Kit.badge(badges, "Danger", "danger", 3)
Kit.badge(badges, "Gold", "gold", 4)

Kit.button(cardsPage, { kind = "secondary", text = "Open dialog", width = UDim.new(1, 0), layoutOrder = 3, onClick = function()
	local dialog = Controls.dialog(panel.gui, DIALOG_WIDTH, DIALOG_HEIGHT, panel.scale.Scale)
	Kit.pad(dialog.Card, Size.pad + 4)
	Kit.list(dialog.Card, nil, Size.gap)
	Kit.label(dialog.Card, { Text = "Dialog", FontFace = Theme.Font.semibold, TextSize = TextSize.title })
	Kit.label(dialog.Card, { Text = "A pane above the panel, for confirmations.", TextColor3 = Color.textSecondary, LayoutOrder = 1 })
	Kit.button(dialog.Card, { kind = "primary", text = "Close", width = UDim.new(1, 0), layoutOrder = 2, onClick = dialog.Close })
end })

show("Controls")

--// DOCK: one tile opens the panel, the other is a plain toggle
local dock = Dock.new("IlluminaDock")
dock:Add({ name = "Demo", label = "UI", panel = "Demo" })
local toggled = false
dock:Add({ name = "Toggle", label = "T", onClick = function()
	toggled = not toggled
	dock:SetLit("Toggle", toggled and "accent")
end })
