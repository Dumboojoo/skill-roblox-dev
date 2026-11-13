--!strict
--[[
	SettingsController – kleines Einstellungs-Fenster (Lautstärke usw.).

	Welche Einstellungen es gibt, steht in GameConfig.Settings.Entries. Zahlen
	werden als Regler mit - und + gezeigt (0 bis 100 %), Wahrheitswerte als
	An/Aus-Knopf. Gespeichert wird über den Server (SettingsService) im Spielstand.

	  SettingsController:Open() / :Close() / :Toggle()      (Taste: GameConfig.Settings.Key)

	Der Knopf am linken Rand lässt sich in GameConfig.Settings abschalten oder
	verschieben, z. B. wenn das Spiel ein eigenes Hauptmenü bekommt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)

local STEP = 0.1
local ROW_HEIGHT = 44

local SettingsController = {}

local panel: Frame? = nil
-- Je Einstellung eine Funktion, die die Anzeige auf den aktuellen Wert bringt.
local refreshers: { [string]: (value: any) -> () } = {}

local function send(key: string, value: any)
	Net.Send("Settings.Set", key, value)
end

local function currentValue(key: string): any
	return DataController:Get({ "Settings", key })
end

local function buildRow(parent: Instance, order: number, key: string, labelText: string)
	local row: Frame = Kit.Create("Frame", {
		Name = key,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Label({
		Text = labelText,
		Size = UDim2.new(1, -170, 1, 0),
		TextWrapped = false,
		Parent = row,
	})

	-- Beide Bedienarten anlegen; sichtbar ist die, die zum Wert passt.
	local minus = Kit.Button({
		Text = "-",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -116, 0.5, 0),
		Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = row,
	}, function()
		local value = currentValue(key)
		if type(value) == "number" then
			send(key, math.clamp(math.round((value - STEP) / STEP) * STEP, 0, 1))
		end
	end)
	local valueLabel = Kit.Label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(64, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Parent = row,
	})
	local plus = Kit.Button({
		Text = "+",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = row,
	}, function()
		local value = currentValue(key)
		if type(value) == "number" then
			send(key, math.clamp(math.round((value + STEP) / STEP) * STEP, 0, 1))
		end
	end)
	local switch = Kit.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(96, ROW_HEIGHT),
		Visible = false,
		Parent = row,
	}, function()
		local value = currentValue(key)
		if type(value) == "boolean" then
			send(key, not value)
		end
	end)

	refreshers[key] = function(value: any)
		local isSwitch = type(value) == "boolean"
		minus.Visible = not isSwitch
		plus.Visible = not isSwitch
		valueLabel.Visible = not isSwitch
		switch.Visible = isSwitch
		if isSwitch then
			switch.Text = if value then "An" else "Aus"
		elseif type(value) == "number" then
			valueLabel.Text = `{math.round(value * 100)} %`
		else
			valueLabel.Text = "-"
		end
	end
end

local function build()
	local config = GameConfig.Settings
	local gui = Kit.ScreenGui("Settings", 60)

	if config.ShowButton then
		Kit.Button({
			Name = "OpenSettings",
			Text = config.ButtonText,
			TextSize = 14,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = config.ButtonPosition,
			Size = UDim2.fromOffset(72, 40),
			BackgroundColor3 = Kit.Theme.Panel,
			Parent = gui,
		}, function()
			SettingsController:Toggle()
		end)
	end

	local window = Kit.Panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Kit.Padding(16).Parent = window
	Kit.List(Enum.FillDirection.Vertical, 10).Parent = window

	local header: Frame = Kit.Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = window,
	})
	Kit.Label({
		Text = "Einstellungen",
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Size = UDim2.new(1, -ROW_HEIGHT, 1, 0),
		Parent = header,
	})
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT),
		BackgroundColor3 = Kit.Theme.Bad,
		-- Modal: Solange das Fenster sichtbar ist, gibt Roblox die Maus frei – auch in der
		-- Ich-Ansicht (Ego-Shooter), in der sie sonst in der Bildmitte gefangen ist.
		Modal = true,
		Parent = header,
	}, function()
		SettingsController:Close()
	end)

	for index, entry in config.Entries do
		buildRow(window, index, entry.Key, entry.Label)
	end

	panel = window
end

local function refreshAll()
	for key, refresh in refreshers do
		refresh(currentValue(key))
	end
end

function SettingsController:Open()
	local window = panel
	if window then
		refreshAll()
		window.Visible = true
		Kit.Pop(window, 0.04)
	end
end

function SettingsController:Close()
	local window = panel
	if window then
		window.Visible = false
	end
end

function SettingsController:Toggle()
	local window = panel
	if window and window.Visible then
		SettingsController:Close()
	else
		SettingsController:Open()
	end
end

function SettingsController:Init()
	build()
end

function SettingsController:Start()
	DataController:Observe("Settings", refreshAll)

	-- Taste zum Öffnen: wichtig in der Ich-Ansicht, wo man den Knopf nicht anklicken kann.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == GameConfig.Settings.Key then
			SettingsController:Toggle()
		end
	end)
end

return SettingsController
