--!strict
--[[
	StoryService – Ablauf des Kapitels: Gegenstände, Türen, Notizen, Ziele.

	Alle Spieler auf dem Server spielen das Kapitel GEMEINSAM: Es gibt einen Stand
	(aktuelles Ziel, gefundene Gegenstände) für alle. Der Stand steht als Attribute
	am Workspace (StoryIndex, StoryText), daraus baut jeder Client seine Anzeige.

	Interaktionen laufen über ProximityPrompts, die der Server an die getaggten
	Teile hängt. Vorteil: funktioniert ohne eigenen Code auf Tastatur, Handy und
	Controller, und die Auslösung kommt direkt beim Server an.

	Ziele stehen in Config.Horror.Objectives. Neuer Zieltyp: in `complete` einen
	Aufruf an passender Stelle ergänzen und in der Config dokumentieren.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Horror)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)
local ChaserService = require(script.Parent.ChaserService)

local StoryService = {
	ChapterCompleted = Signal.new() :: Signal.Signal<number>, -- Dauer in Sekunden
}

local index = 1
local items: { [string]: boolean } = {}
local openDoors: { [string]: boolean } = {}
local startedAt = os.clock()
-- Zum Zurücksetzen: aufgehobene Teile und verschobene Türen.
local hiddenPickups: { [BasePart]: number } = {}
local doorOrigins: { [BasePart]: CFrame } = {}

local function publish()
	local objective = Config.Objectives[index]
	Workspace:SetAttribute("StoryIndex", index)
	Workspace:SetAttribute("StoryTotal", #Config.Objectives)
	Workspace:SetAttribute("StoryText", if objective then objective.Text else "Kapitel geschafft!")
end

local function finishChapter()
	local elapsed = os.clock() - startedAt
	for _, player in Players:GetPlayers() do
		if DataService:IsLoaded(player) then
			DataService:Increment(player, "Horror.Completions", 1)
			local best = DataService:Get(player, "Horror.BestTime")
			if best == 0 or elapsed < best then
				DataService:Set(player, "Horror.BestTime", elapsed)
			end
		end
	end
	Net.FireAll("Notify", "Ihr habt es geschafft!", "Announcement")
	StoryService.ChapterCompleted:Fire(elapsed)
end

-- Erfüllt das aktuelle Ziel, wenn Typ und Schlüssel passen.
local function complete(objectiveType: string, key: string)
	local objective = Config.Objectives[index]
	if not objective or objective.Type ~= objectiveType then
		return
	end
	local expected = if objectiveType == "Pickup"
		then objective.Item
		elseif objectiveType == "Door" then objective.Door
		else objective.Zone
	if expected ~= key then
		return
	end
	index += 1
	publish()
	if index > #Config.Objectives then
		finishChapter()
	end
end

------------------------------------------------------------------------------
-- Interaktionen
------------------------------------------------------------------------------

local function prompt(parent: Instance, action: string, object: string?, hold: number?): ProximityPrompt
	local created = Instance.new("ProximityPrompt")
	created.ActionText = action
	created.ObjectText = object or ""
	created.HoldDuration = hold or 0
	created.MaxActivationDistance = 9
	created.RequiresLineOfSight = true
	created.Parent = parent
	return created
end

local function observePickup(instance: Instance): (() -> ())?
	local item = instance:GetAttribute("Item")
	if not instance:IsA("BasePart") or type(item) ~= "string" then
		return nil
	end
	local name = World.Attribute(instance, "DisplayName", item)
	local created = prompt(instance, "Aufheben", name)
	created.Triggered:Connect(function(player)
		if items[item] then
			return
		end
		items[item] = true
		hiddenPickups[instance] = instance.Transparency
		instance.Transparency = 1
		instance.CanCollide = false
		created.Enabled = false
		Net.FireAll("Notify", `{player.DisplayName} hat gefunden: {name}`, "Success")
		complete("Pickup", item)
	end)
	return function()
		created:Destroy()
	end
end

local function observeDoor(instance: Instance): (() -> ())?
	local doorId = instance:GetAttribute("DoorId")
	if not instance:IsA("BasePart") or type(doorId) ~= "string" then
		return nil
	end
	local key = instance:GetAttribute("Key")
	local created = prompt(instance, "Öffnen", nil, 0.5)
	created.Triggered:Connect(function(player)
		if openDoors[doorId] then
			return
		end
		if type(key) == "string" and not items[key] then
			Net.Fire("Notify", player, "Verschlossen. Du brauchst einen Schlüssel.", "Error")
			return
		end
		openDoors[doorId] = true
		created.Enabled = false
		doorOrigins[instance] = instance.CFrame
		-- Die Tür fährt nach oben weg: funktioniert mit jeder Türform und klemmt nie.
		local goal = { CFrame = instance.CFrame + Vector3.new(0, instance.Size.Y * 0.95, 0) }
		TweenService:Create(instance, TweenInfo.new(1.2, Enum.EasingStyle.Quad), goal):Play()
		ChaserService:MakeNoise(instance.Position) -- Türen sind laut
		complete("Door", doorId)
	end)
	return function()
		created:Destroy()
	end
end

local function observeNote(instance: Instance): (() -> ())?
	local text = instance:GetAttribute("Text")
	if type(text) ~= "string" then
		return nil
	end
	local created = prompt(instance, "Lesen")
	created.Triggered:Connect(function(player)
		Net.Fire("Horror.Note", player, text)
	end)
	return function()
		created:Destroy()
	end
end

local function observeZone(instance: Instance): (() -> ())?
	local zone = instance:GetAttribute("Zone")
	if not instance:IsA("BasePart") or type(zone) ~= "string" then
		return nil
	end
	local connection = instance.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character and Players:GetPlayerFromCharacter(character) then
			complete("Reach", zone)
		end
	end)
	return function()
		connection:Disconnect()
	end
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

-- Setzt das Kapitel zurück (Admin-Befehl oder nach dem Abschluss).
function StoryService:Restart()
	index = 1
	table.clear(items)
	table.clear(openDoors)
	startedAt = os.clock()
	for part, transparency in hiddenPickups do
		part.Transparency = transparency
		part.CanCollide = true
		local existing = part:FindFirstChildOfClass("ProximityPrompt")
		if existing then
			existing.Enabled = true
		end
	end
	table.clear(hiddenPickups)
	for door, origin in doorOrigins do
		door.CFrame = origin
		local existing = door:FindFirstChildOfClass("ProximityPrompt")
		if existing then
			existing.Enabled = true
		end
	end
	table.clear(doorOrigins)
	ChaserService:Respawn()
	publish()
end

function StoryService:SkipObjective()
	if index <= #Config.Objectives then
		index += 1
		publish()
		if index > #Config.Objectives then
			finishChapter()
		end
	end
end

function StoryService:Init()
	Net.Declare("Horror.Note")
end

function StoryService:Start()
	World.Observe("Pickup", observePickup)
	World.Observe("Door", observeDoor)
	World.Observe("Note", observeNote)
	World.Observe("StoryZone", observeZone)
	publish()

	ChaserService.Caught:Connect(function(player: Player)
		DataService:Increment(player, "Horror.Deaths", 1)
	end)

	-- Etwas langsamer als üblich gehen; gesprintet wird auf dem Client.
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.WalkSpeed = Config.Sprint.WalkSpeed
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(onCharacter)
		-- Der Charakter kann schon da sein, bevor dieser Service startet.
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return StoryService
