--!strict
--[[
	OpenWorldService – Gebiete, Schnellreise, Rohstoffe, Tag/Nacht, gespeicherte Position.

	Gebiete werden NICHT über Touched erkannt (unzuverlässig bei großen Kästen und
	Teleports), sondern der Server prüft zweimal pro Sekunde, in welchem Kasten
	jeder Spieler steht. Das ist billig und stimmt immer.

	Player-Attribut Region (Anzeigename des aktuellen Gebiets) für die Anzeige;
	Workspace-Attribut IsNight für alles, was nachts anders sein soll.
	Andere Services hängen sich an die Signale RegionEntered und NightChanged.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.OpenWorld)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

local REGION_CHECK_INTERVAL = 0.5

local OpenWorldService = {
	RegionEntered = Signal.new() :: Signal.Signal<Player, string>, -- (Spieler, RegionId)
	NightChanged = Signal.new() :: Signal.Signal<boolean>,
}

local currentRegion: { [Player]: string } = {}
local lastTravel: { [Player]: number } = {}
local restored: { [Player]: boolean } = {}

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function isInside(part: BasePart, position: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function findWaypoint(waypointId: string): BasePart?
	for _, instance in World.Tagged("Waypoint") do
		if instance:IsA("BasePart") and instance:GetAttribute("WaypointId") == waypointId then
			return instance
		end
	end
	return nil
end

------------------------------------------------------------------------------
-- Gebiete
------------------------------------------------------------------------------

local function checkRegions()
	local regions = World.Tagged("Region")
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if not root or not DataService:IsLoaded(player) then
			continue
		end
		-- Bei verschachtelten Gebieten gewinnt das kleinste (die Stadt im Königreich).
		local best: BasePart? = nil
		local bestVolume = math.huge
		for _, region in regions do
			if region:IsA("BasePart") and isInside(region, root.Position) then
				local volume = region.Size.X * region.Size.Y * region.Size.Z
				if volume < bestVolume then
					best, bestVolume = region, volume
				end
			end
		end

		local regionId = if best then best:GetAttribute("RegionId") else nil
		local id = if type(regionId) == "string" then regionId else ""
		if currentRegion[player] == id then
			continue
		end
		currentRegion[player] = id
		player:SetAttribute("Region", if best then World.Attribute(best, "DisplayName", id) else "")
		if id == "" then
			continue
		end

		OpenWorldService.RegionEntered:Fire(player, id)
		local discovered = DataService:Get(player, "World.Discovered")
		if type(discovered) == "table" and not discovered[id] then
			DataService:Set(player, { "World", "Discovered", id }, true)
			DataService:Increment(player, "World.Coins", Config.DiscoveryReward)
			Net.Fire("World.Discovered", player, player:GetAttribute("Region"))
		end
	end
end

------------------------------------------------------------------------------
-- Schnellreise
------------------------------------------------------------------------------

local function observeWaypoint(instance: Instance): (() -> ())?
	local waypointId = instance:GetAttribute("WaypointId")
	if not instance:IsA("BasePart") or type(waypointId) ~= "string" then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Aktivieren"
	prompt.ObjectText = World.Attribute(instance, "DisplayName", waypointId)
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		local unlocked = DataService:Get(player, "World.Waypoints")
		if type(unlocked) == "table" and not unlocked[waypointId] then
			DataService:Set(player, { "World", "Waypoints", waypointId }, true)
			Net.Fire("Notify", player, `Schnellreise freigeschaltet: {prompt.ObjectText}`, "Success")
		end
	end)
	return function()
		prompt:Destroy()
	end
end

local function onFastTravel(player: Player, waypointId: string)
	local unlocked = DataService:Get(player, "World.Waypoints")
	local waypoint = findWaypoint(waypointId)
	local character = player.Character
	if type(unlocked) ~= "table" or not unlocked[waypointId] or not waypoint or not character then
		return
	end
	local now = os.clock()
	if now - (lastTravel[player] or 0) < Config.FastTravelCooldown then
		Net.Fire("Notify", player, "Die Schnellreise lädt noch auf.", "Error")
		return
	end
	lastTravel[player] = now
	character:PivotTo(waypoint.CFrame + Vector3.new(0, waypoint.Size.Y / 2 + 4, 0))
end

------------------------------------------------------------------------------
-- Rohstoffe
------------------------------------------------------------------------------

local function setNodeVisible(node: Instance, visible: boolean)
	local parts = node:GetDescendants()
	table.insert(parts, node)
	for _, part in parts do
		if part:IsA("BasePart") then
			-- Ursprüngliche Durchsichtigkeit merken, damit auch Glas o. Ä. richtig zurückkommt.
			if part:GetAttribute("NodeTransparency") == nil then
				part:SetAttribute("NodeTransparency", part.Transparency)
			end
			part.Transparency = if visible then part:GetAttribute("NodeTransparency") :: number else 1
			part.CanCollide = visible
		end
	end
end

local function observeResourceNode(instance: Instance): (() -> ())?
	local resourceId = instance:GetAttribute("Resource")
	local resource = if type(resourceId) == "string" then Config.Resources[resourceId] else nil
	if not resource then
		warn(`[Welt] ResourceNode {instance:GetFullName()}: Attribut Resource fehlt oder ist unbekannt.`)
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sammeln"
	prompt.ObjectText = resource.DisplayName
	prompt.HoldDuration = resource.HarvestTime
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		if not prompt.Enabled or not DataService:IsLoaded(player) then
			return
		end
		prompt.Enabled = false
		DataService:Increment(player, { "World", "Resources", resourceId :: string }, resource.Amount)
		Net.Fire("Notify", player, `+{resource.Amount} {resource.DisplayName}`, "Success", 1.5)
		setNodeVisible(instance, false)
		task.wait(resource.RespawnTime)
		setNodeVisible(instance, true)
		prompt.Enabled = true
	end)
	return function()
		prompt:Destroy()
	end
end

------------------------------------------------------------------------------
-- Position
------------------------------------------------------------------------------

local function placeOnJoin(player: Player, character: Model)
	local data = DataService:WaitForData(player)
	if not data or player.Character ~= character then
		return
	end
	task.wait(0.1) -- direkt beim Erscheinen setzt Roblox die Position noch selbst
	if Config.SavePosition and data.World.HasPosition and not restored[player] then
		-- Nur beim ersten Erscheinen der Sitzung; nach einem Tod geht es zum Startpunkt.
		character:PivotTo(CFrame.new(data.World.X, data.World.Y + 3, data.World.Z))
	else
		local spawn = World.Tagged("WorldSpawn")[1]
		if spawn and spawn:IsA("BasePart") then
			character:PivotTo(spawn.CFrame + Vector3.new(0, spawn.Size.Y / 2 + 4, 0))
		end
	end
	restored[player] = true
end

------------------------------------------------------------------------------

function OpenWorldService:Init()
	Net.Declare("World.Discovered")
	Net.On("World.FastTravel", { Check.stringMax(60) }, onFastTravel, { Rate = 2 })
end

function OpenWorldService:Start()
	World.Expect("Open World", {
		{ Tag = "WorldSpawn", Class = "BasePart", Hint = "Startpunkt mit Tag WorldSpawn setzen." },
		{ Tag = "Region", Class = "BasePart", Attributes = { RegionId = "string", DisplayName = "string" } },
	})
	World.Observe("Waypoint", observeWaypoint)
	World.Observe("ResourceNode", observeResourceNode)

	-- Tag und Nacht.
	Lighting.ClockTime = Config.StartHour
	local wasNight = false
	RunService.Heartbeat:Connect(function(deltaTime: number)
		Lighting.ClockTime = (Lighting.ClockTime + deltaTime * 24 / (Config.DayLengthMinutes * 60)) % 24
		local hour = Lighting.ClockTime
		local isNight = hour >= Config.NightStartsAt or hour < Config.NightEndsAt
		if isNight ~= wasNight then
			wasNight = isNight
			Workspace:SetAttribute("IsNight", isNight)
			OpenWorldService.NightChanged:Fire(isNight)
		end
	end)

	task.spawn(function()
		while true do
			checkRegions()
			task.wait(REGION_CHECK_INTERVAL)
		end
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			placeOnJoin(player, character)
		end)
		if player.Character then
			task.spawn(placeOnJoin, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		currentRegion[player] = nil
		lastTravel[player] = nil
		restored[player] = nil
	end)

	-- Position merken, kurz bevor der Spielstand geschlossen wird.
	DataService.PlayerRemoving:Connect(function(player: Player, data: any)
		local root = rootOf(player)
		if root and Config.SavePosition then
			data.World.HasPosition = true
			data.World.X, data.World.Y, data.World.Z = root.Position.X, root.Position.Y, root.Position.Z
		end
	end)
end

return OpenWorldService
