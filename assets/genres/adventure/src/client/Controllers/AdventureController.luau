--!strict
--[[
	AdventureController – Level-Auswahl im Hub, Level-Leiste, Dialogfenster,
	Edelsteine ausblenden, Abschluss-Banner.

	Ob der Spieler im Hub oder in einem Level ist, liest der Client aus dem
	Player-Attribut AdventureLevel (setzt der Server).

	Gefundene Edelsteine werden nur LOKAL ausgeblendet: Jeder Spieler sammelt seine
	eigenen, niemand nimmt einem anderen etwas weg.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Adventure)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)
local DataController = require(script.Parent.DataController)

local AdventureController = {}

local player = Players.LocalPlayer

local levelWindow: Frame
local levelList: Frame
local levelBar: Frame
local levelBarLabel: TextLabel
local openButton: TextButton
local banner: TextLabel

local dialogPanel: Frame
local dialogName: TextLabel
local dialogText: TextLabel
local dialogLines: { string } = {}
local dialogIndex = 0

------------------------------------------------------------------------------
-- Edelsteine
------------------------------------------------------------------------------

local function gemCounts(levelId: string): (number, number)
	local found = DataController:Get({ "Adventure", "Gems", levelId })
	local total, collected = 0, 0
	for _, gem in World.Tagged("Gem") do
		if gem:GetAttribute("Level") == levelId then
			total += 1
			local gemId = gem:GetAttribute("GemId")
			if type(found) == "table" and type(gemId) == "string" and found[gemId] then
				collected += 1
			end
		end
	end
	return collected, total
end

local function refreshGems()
	local all = DataController:Get("Adventure.Gems")
	for _, gem in World.Tagged("Gem") do
		if gem:IsA("BasePart") then
			local levelId = gem:GetAttribute("Level")
			local gemId = gem:GetAttribute("GemId")
			local found = type(all) == "table"
				and type(levelId) == "string"
				and type(all[levelId]) == "table"
				and all[levelId][gemId] == true
			gem.LocalTransparencyModifier = if found then 1 else 0
		end
	end
end

------------------------------------------------------------------------------
-- Dialog
------------------------------------------------------------------------------

local function showDialogLine()
	dialogIndex += 1
	local line = dialogLines[dialogIndex]
	if line then
		dialogText.Text = line
		dialogPanel.Visible = true
	else
		dialogPanel.Visible = false
	end
end

------------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------------

local function refreshLevelList()
	for _, child in levelList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local completed = DataController:Get("Adventure.Completed")
	if type(completed) ~= "table" then
		return
	end
	for index, level in Config.Levels do
		local unlocked = index == 1 or completed[Config.Levels[index - 1].Id] == true
		local done = completed[level.Id] == true
		local collected, total = gemCounts(level.Id)

		local row = Kit.Panel({
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = Kit.Theme.PanelLight,
			LayoutOrder = index,
			Parent = levelList,
		})
		Kit.Padding(8).Parent = row
		Kit.Label({
			Text = `{index}. {level.DisplayName}{if done then "  ✓" else ""}`,
			FontFace = Kit.Theme.FontBold,
			Size = UDim2.new(1, -150, 0, 22),
			Parent = row,
		})
		Kit.Label({
			Text = if unlocked
				then `{level.Description}  Edelsteine: {collected}/{total}`
				else "Schließe zuerst das Level davor ab.",
			TextSize = 13,
			TextColor3 = Kit.Theme.TextDim,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -150, 1, -24),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
		Kit.Button({
			Text = if unlocked then "Spielen" else "Gesperrt",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(136, 44),
			BackgroundColor3 = if unlocked then Kit.Theme.Accent else Kit.Theme.Panel,
			Parent = row,
		}, function()
			if unlocked then
				levelWindow.Visible = false
				Net.Send("Adventure.Enter", level.Id)
			end
		end)
	end
end

local function refreshMode()
	local levelId = player:GetAttribute("AdventureLevel")
	local inLevel = type(levelId) == "string"
	levelBar.Visible = inLevel
	openButton.Visible = not inLevel
	if not inLevel then
		return
	end
	levelWindow.Visible = false
	for _, level in Config.Levels do
		if level.Id == levelId then
			local collected, total = gemCounts(level.Id)
			levelBarLabel.Text = `{level.DisplayName}   ·   Edelsteine {collected}/{total}`
		end
	end
end

local function build()
	local gui = Kit.ScreenGui("AdventureHud", 5)

	openButton = Kit.Button({
		Text = "Level",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(180, 52),
		TextSize = 20,
		Parent = gui,
	}, function()
		levelWindow.Visible = not levelWindow.Visible
		refreshLevelList()
	end)

	levelWindow = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 360),
		Visible = false,
		Parent = gui,
	})
	Kit.Label({
		Text = "Level wählen",
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Parent = levelWindow,
	})
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		Parent = levelWindow,
	}, function()
		levelWindow.Visible = false
	end)
	levelList = Kit.Create("Frame", {
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 1, -68),
		BackgroundTransparency = 1,
		Parent = levelWindow,
	}, Kit.List(Enum.FillDirection.Vertical, 6))

	levelBar = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(520, 44),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	})
	levelBarLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -150, 1, 0),
		FontFace = Kit.Theme.FontBold,
		Parent = levelBar,
	})
	Kit.Button({
		Text = "Zum Hub",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = levelBar,
	}, function()
		Net.Send("Adventure.Leave")
	end)

	dialogPanel = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(620, 130),
		Visible = false,
		Parent = gui,
	})
	dialogName = Kit.Label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 24),
		FontFace = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Accent,
		Parent = dialogPanel,
	})
	dialogText = Kit.Label({
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -170, 1, -48),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = dialogPanel,
	})
	Kit.Button({
		Text = "Weiter",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(120, 44),
		Parent = dialogPanel,
	}, showDialogLine)

	banner = Kit.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 80),
		FontFace = Kit.Theme.FontBold,
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
	Kit.Create("UIStroke", { Thickness = 3, Color = Kit.Theme.Background, Parent = banner })
end

------------------------------------------------------------------------------

function AdventureController:Init()
	build()

	Net.Listen("Adventure.Dialog", function(name: string, lines: { string })
		dialogName.Text = name
		dialogLines = lines
		dialogIndex = 0
		showDialogLine()
	end)
	Net.Listen("Adventure.LevelComplete", function(levelId: string, firstTime: boolean)
		local collected, total = gemCounts(levelId)
		banner.Text = `Level geschafft!  Edelsteine {collected}/{total}`
			.. (if firstTime then `\n+{Config.LevelReward} Münzen` else "")
		banner.Visible = true
		Kit.Pop(banner, 0.2)
		SoundController:Play("Win")
		task.delay(Config.ReturnDelay, function()
			banner.Visible = false
		end)
	end)
end

function AdventureController:Start()
	player:GetAttributeChangedSignal("AdventureLevel"):Connect(refreshMode)
	DataController:Observe("Adventure.Gems", function()
		refreshGems()
		refreshMode()
	end)
	DataController:Observe("Adventure.Completed", refreshLevelList)
	World.Observe("Gem", function()
		refreshGems()
		return nil
	end)
	refreshMode()

	-- Edelsteine drehen sich langsam: macht sie von Weitem als Sammelobjekt erkennbar.
	RunService.RenderStepped:Connect(function(deltaTime: number)
		for _, gem in World.Tagged("Gem") do
			if gem:IsA("BasePart") and gem.LocalTransparencyModifier < 1 then
				gem.CFrame *= CFrame.Angles(0, deltaTime * 1.5, 0)
			end
		end
	end)
end

return AdventureController
