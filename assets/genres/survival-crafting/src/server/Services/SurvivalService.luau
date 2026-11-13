--!strict
--[[
	SurvivalService – Hunger und Durst, Sammeln, Essen, Herstellen und Bauen.

	Alles, was Gegenstände erzeugt oder verbraucht, entscheidet der Server:
	Der Client schickt nur WAS er tun will (Rezept-Id, Bauteil-Id, Position),
	nie Mengen. Kosten und Ergebnis stehen in Config/Survival.

	Bauen: Der Server rastet die Position selbst am Raster ein, prüft Reichweite,
	Kosten, Höchstzahl und ob dort schon ein Bauteil steht. Gespeichert wird die
	Liste der Bauteile; beim nächsten Beitritt werden sie wieder aufgestellt.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.Survival)
local Crafting = require(Shared.Survival.Crafting)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

local NEEDS_INTERVAL = 2

local SurvivalService = {}

local buildFolder: Folder
local pieceFolders: { [Player]: Folder } = {}

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function survival(player: Player): any
	return DataService:Get(player, "Survival")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Gegenstände ändern und die Änderung an den Client schicken.
local function changeItems(player: Player, change: (items: { [string]: number }) -> ())
	DataService:Update(player, "Survival.Items", function(items)
		change(items)
		return items
	end)
end

function SurvivalService:GiveItem(player: Player, itemId: string, amount: number)
	if Config.Items[itemId] and DataService:IsLoaded(player) then
		changeItems(player, function(items)
			Crafting.Add(items, itemId, amount)
		end)
	end
end

local function nearStation(player: Player, station: string): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	for _, piece in buildFolder:GetDescendants() do
		if piece:IsA("BasePart") and piece:GetAttribute("Station") == station then
			if (piece.Position - root.Position).Magnitude <= Config.StationRange then
				return true
			end
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Bedürfnisse, Essen, Herstellen
------------------------------------------------------------------------------

local function tickNeeds()
	local needs = Config.Needs
	for _, player in Players:GetPlayers() do
		local data = survival(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not data or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local hunger = math.max(0, data.Hunger - needs.HungerPerMinute / 60 * NEEDS_INTERVAL)
		local thirst = math.max(0, data.Thirst - needs.ThirstPerMinute / 60 * NEEDS_INTERVAL)
		DataService:Set(player, "Survival.Hunger", hunger)
		DataService:Set(player, "Survival.Thirst", thirst)
		if hunger <= 0 or thirst <= 0 then
			humanoid:TakeDamage(needs.DamagePerSecond * NEEDS_INTERVAL)
		end
	end
end

local function restore(player: Player, food: number, water: number)
	local data = survival(player)
	if data then
		local max = Config.Needs.Max
		DataService:Set(player, "Survival.Hunger", math.min(max, data.Hunger + food))
		DataService:Set(player, "Survival.Thirst", math.min(max, data.Thirst + water))
	end
end

local function onEat(player: Player, itemId: string)
	local data = survival(player)
	local item = Config.Items[itemId]
	if not data or (not item.Food and not item.Water) or (data.Items[itemId] or 0) < 1 then
		return
	end
	changeItems(player, function(items)
		Crafting.Pay(items, { [itemId] = 1 })
	end)
	restore(player, item.Food or 0, item.Water or 0)
end

local function onCraft(player: Player, recipeId: string)
	local data = survival(player)
	local recipe = Config.Recipes[recipeId]
	if not data or not Crafting.CanAfford(data.Items, recipe.Inputs) then
		return
	end
	if recipe.Station and not nearStation(player, recipe.Station) then
		local station = Config.Buildables[recipe.Station]
		Net.Fire(
			"Notify",
			player,
			`Dafür brauchst du in der Nähe: {if station then station.DisplayName else recipe.Station}`,
			"Error"
		)
		return
	end
	changeItems(player, function(items)
		Crafting.Pay(items, recipe.Inputs)
		Crafting.Add(items, recipe.Output, recipe.Count)
	end)
end

------------------------------------------------------------------------------
-- Bauen
------------------------------------------------------------------------------

local function pieceCFrame(position: Vector3, rotation: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, math.rad(90) * rotation, 0)
end

local function isFree(buildable: Config.Buildable, cframe: CFrame): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { buildFolder }
	-- Etwas kleiner prüfen, damit aneinanderstoßende Teile nicht als Überschneidung zählen.
	return #Workspace:GetPartBoundsInBox(cframe, buildable.Size - Vector3.new(0.4, 0.4, 0.4), params) == 0
end

local function createPiece(player: Player, buildableId: string, position: Vector3, rotation: number): Part?
	local buildable = Config.Buildables[buildableId]
	local folder = pieceFolders[player]
	if not buildable or not folder then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = buildableId
	part.Anchored = true
	part.Size = buildable.Size
	part.Color = buildable.Color
	part.Material = buildable.Material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = pieceCFrame(position, rotation)
	part:SetAttribute("Buildable", buildableId)
	part:SetAttribute("Rotation", rotation)
	if buildable.Station then
		part:SetAttribute("Station", buildable.Station)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abbauen"
	prompt.ObjectText = buildable.DisplayName
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 9
	prompt.Parent = part
	prompt.Triggered:Connect(function(who)
		if who == player then
			SurvivalService:RemovePiece(player, part)
		end
	end)

	part.Parent = folder
	return part
end

-- Schreibt alle stehenden Bauteile eines Spielers in seinen Spielstand.
local function saveBase(player: Player)
	local folder = pieceFolders[player]
	if not folder or not DataService:IsLoaded(player) then
		return
	end
	local base = {}
	for _, piece in folder:GetChildren() do
		if piece:IsA("BasePart") then
			table.insert(base, {
				Id = piece.Name,
				X = piece.Position.X,
				Y = piece.Position.Y,
				Z = piece.Position.Z,
				R = piece:GetAttribute("Rotation") or 0,
			})
		end
	end
	DataService:Set(player, "Survival.Base", base)
end

local function onBuild(player: Player, buildableId: string, position: Vector3, rotation: number)
	local data = survival(player)
	local root = rootOf(player)
	local folder = pieceFolders[player]
	local buildable = Config.Buildables[buildableId]
	if not data or not root or not folder then
		return
	end
	local grid = Config.Grid
	-- Unterkante am Raster ausrichten, damit Böden und Wände sauber aufeinander passen.
	local snapped = Vector3.new(
		Crafting.Snap(position.X, grid),
		Crafting.Snap(position.Y, grid / 4) + buildable.Size.Y / 2,
		Crafting.Snap(position.Z, grid)
	)
	local problem: string? = nil
	if (snapped - root.Position).Magnitude > Config.BuildRange then
		problem = "Zu weit weg."
	elseif #folder:GetChildren() >= Config.MaxPieces then
		problem = "Du hast die Höchstzahl an Bauteilen erreicht."
	elseif not Crafting.CanAfford(data.Items, buildable.Cost) then
		problem = "Dir fehlt Material."
	elseif not isFree(buildable, pieceCFrame(snapped, rotation)) then
		problem = "Hier steht schon etwas."
	end
	if problem then
		Net.Fire("Notify", player, problem, "Error")
		return
	end
	changeItems(player, function(items)
		Crafting.Pay(items, buildable.Cost)
	end)
	createPiece(player, buildableId, snapped, rotation)
	saveBase(player)
end

function SurvivalService:RemovePiece(player: Player, piece: BasePart)
	local buildable = Config.Buildables[piece.Name]
	if piece.Parent ~= pieceFolders[player] or not buildable then
		return
	end
	piece:Destroy()
	changeItems(player, function(items)
		for itemId, amount in Crafting.Refund(buildable.Cost, Config.RemoveRefund) do
			Crafting.Add(items, itemId, amount)
		end
	end)
	saveBase(player)
end

------------------------------------------------------------------------------
-- Welt
------------------------------------------------------------------------------

local function setVisible(node: Instance, visible: boolean)
	local parts = node:GetDescendants()
	table.insert(parts, node)
	for _, part in parts do
		if part:IsA("BasePart") then
			if part:GetAttribute("NodeTransparency") == nil then
				part:SetAttribute("NodeTransparency", part.Transparency)
			end
			part.Transparency = if visible then part:GetAttribute("NodeTransparency") :: number else 1
			part.CanCollide = visible
		end
	end
end

local function observeHarvestable(instance: Instance): (() -> ())?
	local itemId = instance:GetAttribute("Item")
	local item = if type(itemId) == "string" then Config.Items[itemId] else nil
	if not item then
		warn(`[Survival] Harvestable {instance:GetFullName()}: Attribut Item fehlt oder ist unbekannt.`)
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sammeln"
	prompt.ObjectText = item.DisplayName
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled then
			return
		end
		prompt.Enabled = false
		local amount = World.Attribute(instance, "Amount", 1)
		SurvivalService:GiveItem(player, itemId :: string, amount)
		Net.Fire("Notify", player, `+{amount} {item.DisplayName}`, "Success", 1.2)
		setVisible(instance, false)
		task.wait(World.Attribute(instance, "Respawn", Config.HarvestRespawn))
		setVisible(instance, true)
		prompt.Enabled = true
	end)
	return function()
		prompt:Destroy()
	end
end

local function observeWater(instance: Instance): (() -> ())?
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trinken"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		restore(player, 0, Config.Needs.DrinkAmount)
	end)
	return function()
		prompt:Destroy()
	end
end

------------------------------------------------------------------------------

function SurvivalService:Init()
	local created = Instance.new("Folder")
	created.Name = "Builds"
	created.Parent = Workspace
	buildFolder = created

	Net.On("Survival.Eat", { Check.keyOf(Config.Items) }, onEat, { Rate = 5 })
	Net.On("Survival.Craft", { Check.keyOf(Config.Recipes) }, onCraft, { Rate = 8 })
	Net.On(
		"Survival.Build",
		{ Check.keyOf(Config.Buildables), Check.Vector3, Check.integerRange(0, 3) },
		onBuild,
		{ Rate = 5 }
	)
end

function SurvivalService:Start()
	World.Observe("Harvestable", observeHarvestable)
	World.Observe("WaterSource", observeWater)

	-- Gespeicherte Basis wieder aufstellen, sobald der Spielstand da ist.
	DataService:OnPlayerLoaded(function(player, data)
		local folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = buildFolder
		pieceFolders[player] = folder
		for _, entry in data.Survival.Base do
			local buildable = Config.Buildables[entry.Id]
			local position = Vector3.new(entry.X, entry.Y, entry.Z)
			-- Steht dort inzwischen das Bauteil eines anderen Spielers, wird dieses übersprungen.
			if buildable and isFree(buildable, pieceCFrame(position, entry.R)) then
				createPiece(player, entry.Id, position, entry.R)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local folder = pieceFolders[player]
		pieceFolders[player] = nil
		if folder then
			folder:Destroy()
		end
	end)

	-- Nach dem Tod mit halb gefüllten Bedürfnissen neu starten (sonst stirbt man sofort wieder).
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			local data = survival(player)
			if data and (data.Hunger <= 0 or data.Thirst <= 0) then
				DataService:Set(player, "Survival.Hunger", math.max(data.Hunger, Config.Needs.Max / 2))
				DataService:Set(player, "Survival.Thirst", math.max(data.Thirst, Config.Needs.Max / 2))
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	task.spawn(function()
		while true do
			task.wait(NEEDS_INTERVAL)
			tickNeeds()
		end
	end)
end

return SurvivalService
