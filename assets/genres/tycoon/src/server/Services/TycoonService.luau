--!strict
--[[
	TycoonService – Grundstücke, Kaufknöpfe, Tropfer und Geld.

	Ablauf: Spieler berührt "Claim" -> das Grundstück gehört ihm, alles bereits
	Gekaufte wird wieder aufgebaut -> Tropfer erzeugen Tropfen -> Förderband ->
	Sammler -> Geld liegt im Sammler -> "CollectPad" berühren zahlt aus.

	Gespeichert wird nur, WAS gekauft wurde (Liste von Item-Ids), nie die Modelle.
	Beim nächsten Beitritt baut der Server daraus das Grundstück neu auf.

	Die Tropfen sind echte Physik-Teile, die der Server besitzt (SetNetworkOwner(nil)):
	Ein Client kann sie nicht in den Sammler teleportieren.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Tycoon)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

type DropperState = { Spout: BasePart, Timer: number, Spec: Config.Dropper }

type Plot = {
	Model: Model,
	Owner: Player?,
	Claim: BasePart?,
	Templates: { [string]: { Instance } }, -- ItemId -> weggeräumte Originale
	Buttons: { [string]: BasePart },
	Built: { [string]: { Instance } },
	Droppers: { DropperState },
	Drops: Folder,
	Bank: number,
}

local TycoonService = {}

local plots: { Plot } = {}
local plotOf: { [Player]: Plot } = {}
local storage: Folder

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	return if character then Players:GetPlayerFromCharacter(character) else nil
end

local function setBank(plot: Plot, amount: number)
	plot.Bank = amount
	plot.Model:SetAttribute("Bank", math.floor(amount))
end

local function setButtonVisible(button: BasePart, visible: boolean)
	button.Transparency = if visible then 0 else 1
	button.CanCollide = visible
	button.CanTouch = visible
	local billboard = button:FindFirstChildOfClass("BillboardGui")
	if billboard then
		billboard.Enabled = visible
	end
end

local function owned(player: Player): { [string]: boolean }
	local data = DataService:Get(player, "Tycoon.Owned")
	return if type(data) == "table" then data else {}
end

-- Knopf sichtbar, wenn: Grundstück hat Besitzer, Item noch nicht gekauft, alle Voraussetzungen gekauft.
local function refreshButtons(plot: Plot)
	local owner = plot.Owner
	local ownedItems = if owner then owned(owner) else {}
	for itemId, button in plot.Buttons do
		local item = Config.Items[itemId]
		local visible = owner ~= nil and item ~= nil and not ownedItems[itemId]
		if visible then
			for _, required in item.Requires do
				if not ownedItems[required] then
					visible = false
					break
				end
			end
		end
		setButtonVisible(button, visible)
	end
end

local function buildItem(plot: Plot, itemId: string)
	local templates = plot.Templates[itemId]
	if not templates or plot.Built[itemId] then
		return
	end
	local built: { Instance } = {}
	for _, template in templates do
		local clone = template:Clone()
		clone.Parent = plot.Model
		table.insert(built, clone)

		local item = Config.Items[itemId]
		local spout = clone:FindFirstChild("Spout", true)
		if item and item.Dropper and spout and spout:IsA("BasePart") then
			table.insert(plot.Droppers, { Spout = spout, Timer = 0, Spec = item.Dropper })
		end
	end
	plot.Built[itemId] = built
end

-- Geld pro Sekunde, das die gekauften Tropfer bringen (Grundlage für den Abwesenheits-Verdienst).
local function incomeRate(ownedItems: { [string]: boolean }): number
	local rate = 0
	for itemId in ownedItems do
		local item = Config.Items[itemId]
		if item and item.Dropper then
			rate += item.Dropper.Value / item.Dropper.Interval
		end
	end
	return rate
end

------------------------------------------------------------------------------
-- Besitz
------------------------------------------------------------------------------

local function release(plot: Plot)
	local owner = plot.Owner
	if owner then
		plotOf[owner] = nil
	end
	plot.Owner = nil
	plot.Model:SetAttribute("OwnerId", 0)
	for _, built in plot.Built do
		for _, instance in built do
			instance:Destroy()
		end
	end
	table.clear(plot.Built)
	table.clear(plot.Droppers)
	plot.Drops:ClearAllChildren()
	setBank(plot, 0)
	if plot.Claim then
		plot.Claim.Transparency = 0
		plot.Claim.CanTouch = true
	end
	refreshButtons(plot)
end

local function claim(plot: Plot, player: Player)
	if plot.Owner or plotOf[player] or not DataService:IsLoaded(player) then
		return
	end
	plot.Owner = player
	plotOf[player] = plot
	plot.Model:SetAttribute("OwnerId", player.UserId)
	if plot.Claim then
		plot.Claim.Transparency = 1
		plot.Claim.CanTouch = false
	end

	local ownedItems = owned(player)
	for itemId in ownedItems do
		buildItem(plot, itemId)
	end
	refreshButtons(plot)

	-- Verdienst während der Abwesenheit landet im Sammler (der Spieler holt ihn sichtbar ab).
	local lastSeen = DataService:Get(player, "Tycoon.LastSeen")
	if type(lastSeen) == "number" and lastSeen > 0 then
		local away = math.min(os.time() - lastSeen, Config.OfflineEarnings.MaxHours * 3600)
		local earned = math.floor(incomeRate(ownedItems) * away * Config.OfflineEarnings.Rate)
		if earned > 0 then
			setBank(plot, earned)
			Net.Fire(
				"Notify",
				player,
				`Während du weg warst, kamen {earned} zusammen. Hol sie am Sammler ab!`,
				"Success",
				6
			)
		end
		DataService:Set(player, "Tycoon.LastSeen", 0)
	end
end

local function buy(plot: Plot, player: Player, itemId: string)
	local item = Config.Items[itemId]
	if plot.Owner ~= player or not item then
		return
	end
	local ownedItems = owned(player)
	if ownedItems[itemId] then
		return
	end
	for _, required in item.Requires do
		if not ownedItems[required] then
			return
		end
	end
	local coins = DataService:Get(player, "Tycoon.Coins")
	if type(coins) ~= "number" or coins < item.Price then
		return -- Der Knopf zeigt den Preis; kein Meldungs-Spam beim Darüberlaufen.
	end
	DataService:Increment(player, "Tycoon.Coins", -item.Price)
	DataService:Set(player, { "Tycoon", "Owned", itemId }, true)
	buildItem(plot, itemId)
	refreshButtons(plot)
	Net.Fire("Notify", player, `Gekauft: {item.DisplayName}`, "Success", 2)
end

------------------------------------------------------------------------------
-- Aufbau eines Grundstücks
------------------------------------------------------------------------------

local function addPriceTag(button: BasePart, item: Config.Item)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(170, 44)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 60
	billboard.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = if item.Price > 0 then `{item.DisplayName}\n{item.Price}` else `{item.DisplayName}\nGratis`
	label.Parent = billboard
	billboard.Parent = button
end

local function setupPlot(model: Model)
	local claimPart = model:FindFirstChild("Claim")
	local collectPad = model:FindFirstChild("CollectPad")

	local drops = Instance.new("Folder")
	drops.Name = "Drops"
	drops.Parent = model

	local plot: Plot = {
		Model = model,
		Owner = nil,
		Claim = if claimPart and claimPart:IsA("BasePart") then claimPart else nil,
		Templates = {},
		Buttons = {},
		Built = {},
		Droppers = {},
		Drops = drops,
		Bank = 0,
	}
	table.insert(plots, plot)

	local plotStorage = Instance.new("Folder")
	plotStorage.Name = `Plot{#plots}`
	plotStorage.Parent = storage

	for _, descendant in model:GetDescendants() do
		local itemId = descendant:GetAttribute("Item")
		if type(itemId) ~= "string" then
			continue
		end
		if not Config.Items[itemId] then
			warn(`[Tycoon] {descendant:GetFullName()}: Item "{itemId}" steht nicht in Config/Tycoon.`)
		elseif CollectionService:HasTag(descendant, "TycoonButton") and descendant:IsA("BasePart") then
			plot.Buttons[itemId] = descendant
			addPriceTag(descendant, Config.Items[itemId])
			descendant.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				if player then
					buy(plot, player, itemId)
				end
			end)
		elseif CollectionService:HasTag(descendant, "TycoonItem") then
			-- Original wegräumen; gebaut wird später aus Kopien davon.
			plot.Templates[itemId] = plot.Templates[itemId] or {}
			table.insert(plot.Templates[itemId], descendant)
			descendant.Parent = plotStorage
		end
	end

	if plot.Claim then
		plot.Claim.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				claim(plot, player)
			end
		end)
	else
		warn(`[Tycoon] {model:GetFullName()}: Teil "Claim" fehlt.`)
	end

	if collectPad and collectPad:IsA("BasePart") then
		collectPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player and player == plot.Owner and plot.Bank >= 1 then
				local amount = math.floor(plot.Bank)
				setBank(plot, 0)
				DataService:Increment(player, "Tycoon.Coins", amount)
				Net.Fire("Tycoon.Collected", player, amount)
			end
		end)
	else
		warn(`[Tycoon] {model:GetFullName()}: Teil "CollectPad" fehlt.`)
	end

	model:SetAttribute("OwnerId", 0)
	setBank(plot, 0)
	refreshButtons(plot)
end

local function plotOfDrop(drop: BasePart): Plot?
	for _, plot in plots do
		if drop.Parent == plot.Drops then
			return plot
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- Tropfen
------------------------------------------------------------------------------

local function spawnDrop(plot: Plot, dropper: DropperState)
	if #plot.Drops:GetChildren() >= Config.MaxDropsPerPlot then
		return
	end
	local drop = Instance.new("Part")
	drop.Name = "Drop"
	drop.Size = Vector3.new(1, 1, 1)
	drop.Color = dropper.Spout.Color
	drop.Material = Enum.Material.SmoothPlastic
	drop.TopSurface = Enum.SurfaceType.Smooth
	drop.BottomSurface = Enum.SurfaceType.Smooth
	drop.CFrame = dropper.Spout.CFrame * CFrame.new(0, -dropper.Spout.Size.Y / 2 - 0.6, 0)
	drop:SetAttribute("Value", dropper.Spec.Value)
	drop.Parent = plot.Drops
	drop:SetNetworkOwner(nil)
	task.delay(Config.DropLifetime, drop.Destroy, drop)
end

local function step(deltaTime: number)
	for _, plot in plots do
		if not plot.Owner then
			continue
		end
		for _, dropper in plot.Droppers do
			dropper.Timer += deltaTime
			if dropper.Timer >= dropper.Spec.Interval then
				dropper.Timer -= dropper.Spec.Interval
				spawnDrop(plot, dropper)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Für Admin-Befehle
------------------------------------------------------------------------------

function TycoonService:AddCoins(player: Player, amount: number)
	DataService:Increment(player, "Tycoon.Coins", amount)
end

------------------------------------------------------------------------------

function TycoonService:Init()
	Net.Declare("Tycoon.Collected")
	local folder = Instance.new("Folder")
	folder.Name = "TycoonTemplates"
	folder.Parent = ServerStorage
	storage = folder
end

function TycoonService:Start()
	World.Expect("Tycoon", {
		{ Tag = "TycoonPlot", Class = "Model", Hint = "Grundstück als Model mit Tag TycoonPlot anlegen." },
		{ Tag = "TycoonButton", Class = "BasePart", Attributes = { Item = "string" } },
		{ Tag = "TycoonItem", Attributes = { Item = "string" } },
		{ Tag = "TycoonCollector", Class = "BasePart" },
	})

	for _, instance in World.Tagged("TycoonPlot") do
		if instance:IsA("Model") then
			setupPlot(instance)
		end
	end

	World.Observe("TycoonCollector", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local connection = instance.Touched:Connect(function(hit)
			local plot = plotOfDrop(hit)
			local value = hit:GetAttribute("Value")
			if plot and type(value) == "number" then
				hit:Destroy()
				setBank(plot, plot.Bank + value)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("TycoonUpgrader", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local multiplier = World.Attribute(instance, "Multiplier", 2)
		local connection = instance.Touched:Connect(function(hit)
			local value = hit:GetAttribute("Value")
			-- Jeder Tropfen wird höchstens einmal aufgewertet (sonst Endlos-Schleife möglich).
			if plotOfDrop(hit) and type(value) == "number" and not hit:GetAttribute("Upgraded") then
				hit:SetAttribute("Upgraded", true)
				hit:SetAttribute("Value", value * multiplier)
				hit.Material = Enum.Material.Neon
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("Conveyor", function(instance)
		if instance:IsA("BasePart") then
			instance.AssemblyLinearVelocity = instance.CFrame.LookVector * World.Attribute(instance, "Speed", 8)
		end
		return nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		local plot = plotOf[player]
		if plot then
			release(plot)
		end
	end)
	-- Zeitpunkt des Verlassens merken (läuft, bevor der Spielstand geschlossen wird).
	DataService.PlayerRemoving:Connect(function(_player, data)
		data.Tycoon.LastSeen = os.time()
	end)
	DataService:OnPlayerLoaded(function(player, data)
		if data.Stats.Joins == 1 and data.Tycoon.Coins == 0 and Config.StartCoins > 0 then
			DataService:Set(player, "Tycoon.Coins", Config.StartCoins)
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return TycoonService
