--!strict
--[[
	SimulatorController – Klick-Knopf, Münzanzeige und das Menü (Upgrades, Pets,
	Eier, Rebirth).

	Alles, was hier an Zahlen steht, ist nur ANZEIGE und wird mit denselben Formeln
	wie auf dem Server berechnet (shared/Simulator/Formulas). Ändern kann der
	Client nichts, er schickt nur Bitten an den Server.

	Aufbau: ein Fenster mit Reitern. Neuer Reiter = Eintrag in TABS und eine
	Funktion, die den Inhalt in `content` baut.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Simulator)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Simulator.Formulas)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local TABS = { "Upgrades", "Pets", "Eier", "Rebirth" }

local SimulatorController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local coinLabel: TextLabel
local window: Frame
local content: ScrollingFrame
local currentTab = "Upgrades"
local lastCoins = 0
local coinsKnown = false

local function sim(): any
	return DataController:Get("Simulator")
end

------------------------------------------------------------------------------
-- Bausteine
------------------------------------------------------------------------------

local function row(height: number, order: number): Frame
	local frame = Kit.Panel({
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Kit.Theme.PanelLight,
		LayoutOrder = order,
		Parent = content,
	})
	Kit.Padding(8).Parent = frame
	return frame
end

local function rowText(parent: Frame, title: string, detail: string)
	Kit.Label({
		Text = title,
		FontFace = Kit.Theme.FontBold,
		Size = UDim2.new(1, -150, 0, 22),
		Parent = parent,
	})
	Kit.Label({
		Text = detail,
		TextColor3 = Kit.Theme.TextDim,
		TextSize = 14,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -150, 1, -24),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = parent,
	})
end

local function rowButton(parent: Frame, text: string, color: Color3?, onClick: () -> ()): TextButton
	return Kit.Button({
		Text = text,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(140, 44),
		BackgroundColor3 = color or Kit.Theme.Accent,
		Parent = parent,
	}, onClick)
end

------------------------------------------------------------------------------
-- Reiter
------------------------------------------------------------------------------

local function buildUpgrades(data: any)
	local order = 0
	for upgradeId, upgrade in Config.Upgrades do
		order += 1
		local level = data.Upgrades[upgradeId] or 0
		local frame = row(64, order)
		rowText(frame, `{upgrade.DisplayName}  ·  Stufe {level}`, upgrade.Description)
		if level < upgrade.MaxLevel then
			local cost = Formulas.UpgradeCost(upgrade.BaseCost, upgrade.Growth, level)
			rowButton(frame, Format.Number(cost), nil, function()
				Net.Send("Sim.BuyUpgrade", upgradeId)
			end)
		end
	end
end

local function buildPets(data: any)
	Kit.Label({
		Text = `Ausgerüstet {#data.Equipped} / {Config.MaxEquippedPets}   ·   Lager {#data.Pets} / {Config.MaxPets}`,
		TextColor3 = Kit.Theme.TextDim,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 0,
		Parent = content,
	})
	-- Stärkste zuerst.
	local pets: { any } = table.clone(data.Pets)
	table.sort(pets, function(a, b)
		local first, second = Config.Pets[a.Id], Config.Pets[b.Id]
		return (if first then first.Multiplier else 0) > (if second then second.Multiplier else 0)
	end)
	for index, pet in pets do
		local definition = Config.Pets[pet.Id]
		if not definition then
			continue
		end
		local equipped = table.find(data.Equipped, pet.Uid) ~= nil
		local frame = row(64, index)
		rowText(frame, definition.DisplayName, `{definition.Rarity}  ·  x{definition.Multiplier} Münzen`)
		Kit.Create("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			Position = UDim2.fromOffset(-8, 0),
			BackgroundColor3 = definition.Color,
			BorderSizePixel = 0,
			Parent = frame,
		})
		rowButton(
			frame,
			if equipped then "Ablegen" else "Ausrüsten",
			if equipped then Kit.Theme.Panel else Kit.Theme.Good,
			function()
				Net.Send("Sim.EquipPet", pet.Uid, not equipped)
			end
		)
	end
end

local function buildEggs(_data: any)
	local order = 0
	for eggId, egg in Config.Eggs do
		order += 1
		-- Chancen offen anzeigen: aus den Gewichten berechnet, nie von Hand getippt.
		local odds = Formulas.Odds(egg.Pets)
		local parts = {}
		for _, entry in egg.Pets do
			local definition = Config.Pets[entry.Id]
			if definition then
				table.insert(parts, `{definition.DisplayName} {Format.Percent(odds[entry.Id], 0)}`)
			end
		end
		local frame = row(84, order)
		rowText(frame, egg.DisplayName, table.concat(parts, "  ·  "))
		rowButton(frame, Format.Number(egg.Price), nil, function()
			local petId = Net.Call("Sim.Hatch", eggId)
			local definition = if type(petId) == "string" then Config.Pets[petId] else nil
			if definition then
				NotificationController:Notify(`Geschlüpft: {definition.DisplayName} ({definition.Rarity})`, "Success")
			end
		end)
	end
end

local function buildRebirth(data: any)
	local cost = Formulas.RebirthCost(Config.Rebirth.BaseCost, Config.Rebirth.Growth, data.Rebirths)
	local bonus = Format.Percent(Config.Rebirth.BonusPerRebirth, 0)
	local frame = row(110, 1)
	rowText(
		frame,
		`Rebirth {data.Rebirths + 1}`,
		`Setzt Münzen und Upgrades zurück. Dafür dauerhaft +{bonus} Münzen. Pets und Zonen bleiben.\nFortschritt: {Format.Number(
			data.TotalCoins
		)} / {Format.Number(cost)}`
	)
	if data.TotalCoins >= cost then
		rowButton(frame, "Rebirth", Kit.Theme.Warn, function()
			Net.Send("Sim.Rebirth")
		end)
	end
end

local BUILDERS: { [string]: (data: any) -> () } = {
	Upgrades = buildUpgrades,
	Pets = buildPets,
	Eier = buildEggs,
	Rebirth = buildRebirth,
}

local function refreshWindow()
	if not window.Visible then
		return
	end
	local data = sim()
	if not data then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	BUILDERS[currentTab](data)
end

------------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------------

local function build()
	gui = Kit.ScreenGui("SimulatorHud", 5)

	local coinPanel = Kit.Panel({
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(200, 44),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	coinLabel = Kit.Label({
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		FontFace = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Warn,
		TextSize = 20,
		Parent = coinPanel,
	})

	Kit.Button({
		Text = "Klick!",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(180, 64),
		Parent = gui,
	}, function()
		Net.Send("Sim.Click")
	end)

	Kit.Button({
		Text = "Menü",
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.fromOffset(100, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, function()
		window.Visible = not window.Visible
		refreshWindow()
	end)

	window = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 420),
		Visible = false,
		Parent = gui,
	})
	local tabBar = Kit.Create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -70, 0, 44),
		BackgroundTransparency = 1,
		Parent = window,
	}, Kit.List(Enum.FillDirection.Horizontal, 6))
	for index, tab in TABS do
		Kit.Button({
			Text = tab,
			Size = UDim2.fromOffset(104, 44),
			BackgroundColor3 = Kit.Theme.PanelLight,
			LayoutOrder = index,
			Parent = tabBar,
		}, function()
			currentTab = tab
			refreshWindow()
		end)
	end
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		Parent = window,
	}, function()
		window.Visible = false
	end)
	content = Kit.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 64),
		Size = UDim2.new(1, -20, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	}, Kit.List(Enum.FillDirection.Vertical, 6))
end

------------------------------------------------------------------------------

function SimulatorController:Init()
	build()
end

function SimulatorController:Start()
	DataController:Observe("Simulator.Coins", function(coins: any)
		local amount = if type(coins) == "number" then coins else 0
		coinLabel.Text = `{Format.Number(amount)} Münzen`
		if amount > lastCoins then
			Kit.Pop(coinLabel, 0.08)
			-- Nicht beim ersten Wert nach dem Laden klimpern.
			if coinsKnown then
				SoundController:Play("Coin")
			end
		end
		coinsKnown = true
		lastCoins = amount
	end)
	-- Jede Änderung am Simulator-Stand baut das offene Fenster neu (einfach und immer richtig).
	DataController:Observe("Simulator", refreshWindow)

	-- Klick in die Welt zählt ebenfalls (nicht, wenn auf Oberfläche geklickt wurde).
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			Net.Send("Sim.Click")
		end
	end)

	-- Zonen-Sperren: für Besitzer durchlässig und unsichtbar (nur auf diesem Client).
	World.Observe("ZoneGate", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local zoneId = instance:GetAttribute("Zone")
		local originalTransparency = instance.Transparency
		return DataController:Observe("Simulator.Zones", function(zones: any)
			local owned = type(zones) == "table" and type(zoneId) == "string" and zones[zoneId] == true
			instance.CanCollide = not owned
			instance.Transparency = if owned then 1 else originalTransparency
			local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = not owned
			end
		end)
	end)

	-- Eier-Stände öffnen das Menü direkt im Eier-Reiter.
	World.Observe("EggStand", function(instance)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Eier ansehen"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = instance
		prompt.Triggered:Connect(function(who)
			if who == player then
				currentTab = "Eier"
				window.Visible = true
				refreshWindow()
			end
		end)
		return function()
			prompt:Destroy()
		end
	end)
end

return SimulatorController
