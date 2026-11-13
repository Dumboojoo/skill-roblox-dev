--!strict
--[[
	AdventureService – Level betreten und abschließen, Checkpoints, Edelsteine, Dialoge.

	Gespeichert wird pro Spieler: welche Level geschafft sind und welche Edelsteine
	gefunden wurden. In welchem Level jemand gerade steht und sein letzter
	Checkpoint gelten nur für die laufende Sitzung.

	Die Rätsel (Hebel, Platten, Tore) stehen im PuzzleService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.Adventure)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

type Session = { Level: string?, Checkpoint: BasePart?, Finishing: boolean }

local AdventureService = {
	LevelCompleted = Signal.new() :: Signal.Signal<Player, string>,
}

local sessions: { [Player]: Session } = {}
local levelIds: { string } = {}

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function playerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = if character then Players:GetPlayerFromCharacter(character) else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if player and humanoid and humanoid.Health > 0 then
		return player, humanoid
	end
	return nil, nil
end

local function taggedForLevel(tag: string, levelId: string): BasePart?
	for _, instance in World.Tagged(tag) do
		if instance:IsA("BasePart") and instance:GetAttribute("Level") == levelId then
			return instance
		end
	end
	return nil
end

local function placeAt(player: Player, target: BasePart?)
	local character = player.Character
	if character and target then
		character:PivotTo(target.CFrame + Vector3.new(0, target.Size.Y / 2 + 4, 0))
	end
end

local function hubSpawn(): BasePart?
	local spawn = World.Tagged("HubSpawn")[1]
	return if spawn and spawn:IsA("BasePart") then spawn else nil
end

-- Ein Level ist offen, wenn es das erste ist oder das Level davor geschafft wurde.
local function isUnlocked(player: Player, levelId: string): boolean
	local index = table.find(levelIds, levelId)
	if not index then
		return false
	end
	if index == 1 then
		return true
	end
	local completed = DataService:Get(player, "Adventure.Completed")
	return type(completed) == "table" and completed[levelIds[index - 1]] == true
end

local function setLevel(player: Player, levelId: string?)
	local session = sessions[player]
	if session then
		session.Level = levelId
		session.Checkpoint = nil
		session.Finishing = false
		-- Der Client liest das für seine Anzeige (Hub-Menü oder Level-Leiste).
		player:SetAttribute("AdventureLevel", levelId)
	end
end

------------------------------------------------------------------------------
-- Level
------------------------------------------------------------------------------

function AdventureService:EnterLevel(player: Player, levelId: string)
	if not DataService:IsLoaded(player) or not isUnlocked(player, levelId) then
		return
	end
	local start = taggedForLevel("LevelStart", levelId)
	if not start then
		Net.Fire("Notify", player, "Dieses Level ist noch nicht gebaut.", "Error")
		return
	end
	setLevel(player, levelId)
	placeAt(player, start)
end

function AdventureService:ReturnToHub(player: Player)
	setLevel(player, nil)
	placeAt(player, hubSpawn())
end

local function completeLevel(player: Player, levelId: string)
	local session = sessions[player]
	if not session or session.Level ~= levelId or session.Finishing then
		return
	end
	session.Finishing = true

	local completed = DataService:Get(player, "Adventure.Completed")
	local firstTime = type(completed) == "table" and not completed[levelId]
	if firstTime then
		DataService:Set(player, { "Adventure", "Completed", levelId }, true)
		DataService:Increment(player, "Adventure.Coins", Config.LevelReward)
	end
	Net.Fire("Adventure.LevelComplete", player, levelId, firstTime)
	AdventureService.LevelCompleted:Fire(player, levelId)

	task.delay(Config.ReturnDelay, function()
		if sessions[player] == session and session.Level == levelId then
			AdventureService:ReturnToHub(player)
		end
	end)
end

local function collectGem(player: Player, gem: BasePart)
	local levelId = gem:GetAttribute("Level")
	local gemId = gem:GetAttribute("GemId")
	local session = sessions[player]
	if type(levelId) ~= "string" or type(gemId) ~= "string" or not session or session.Level ~= levelId then
		return
	end
	local found = DataService:Get(player, { "Adventure", "Gems", levelId })
	if type(found) == "table" and found[gemId] then
		return
	end
	DataService:Set(player, { "Adventure", "Gems", levelId, gemId }, true)
	DataService:Increment(player, "Adventure.Coins", Config.GemReward)
	Net.Fire("Notify", player, "Edelstein gefunden!", "Success", 1.5)
end

------------------------------------------------------------------------------

function AdventureService:Init()
	for _, level in Config.Levels do
		table.insert(levelIds, level.Id)
	end
	Net.Declare("Adventure.LevelComplete")
	Net.Declare("Adventure.Dialog")
	Net.On("Adventure.Enter", { Check.oneOf(levelIds) }, function(player: Player, levelId: string)
		AdventureService:EnterLevel(player, levelId)
	end, { Rate = 2 })
	Net.On("Adventure.Leave", {}, function(player: Player)
		AdventureService:ReturnToHub(player)
	end, { Rate = 2 })
end

function AdventureService:Start()
	World.Expect("Adventure", {
		{ Tag = "HubSpawn", Class = "BasePart", Hint = "Startpunkt im Hub mit Tag HubSpawn setzen." },
		{ Tag = "LevelStart", Class = "BasePart", Attributes = { Level = "string" } },
		{ Tag = "LevelGoal", Class = "BasePart", Attributes = { Level = "string" } },
	})

	World.Observe("LevelGoal", function(instance)
		local levelId = instance:GetAttribute("Level")
		if not instance:IsA("BasePart") or type(levelId) ~= "string" then
			return nil
		end
		local connection = instance.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				completeLevel(player, levelId)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("AdventureCheckpoint", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local connection = instance.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local session = if player then sessions[player] else nil
			if player and session and session.Level and session.Checkpoint ~= instance then
				session.Checkpoint = instance
				Net.Fire("Notify", player, "Checkpoint", "Info", 1.2)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("Hazard", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local connection = instance.Touched:Connect(function(hit)
			local _player, humanoid = playerFromHit(hit)
			if humanoid then
				humanoid:TakeDamage(humanoid.MaxHealth)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("Gem", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local connection = instance.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				collectGem(player, instance)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("Npc", function(instance)
		local lines = Config.Dialogs[World.Attribute(instance, "Dialog", "")]
		if not lines then
			warn(`[Adventure] {instance:GetFullName()}: Attribut Dialog fehlt oder ist unbekannt.`)
			return nil
		end
		local name = World.Attribute(instance, "DisplayName", instance.Name)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Sprechen"
		prompt.ObjectText = name
		prompt.MaxActivationDistance = 10
		prompt.Parent = instance
		prompt.Triggered:Connect(function(player)
			Net.Fire("Adventure.Dialog", player, name, lines)
		end)
		return function()
			prompt:Destroy()
		end
	end)

	local function onPlayer(player: Player)
		sessions[player] = { Level = nil, Checkpoint = nil, Finishing = false }
		player.CharacterAdded:Connect(function(character)
			-- Kurz warten: Direkt beim Erscheinen setzt Roblox die Position noch selbst.
			task.wait(0.1)
			local session = sessions[player]
			if not session or player.Character ~= character then
				return
			end
			if session.Level then
				placeAt(player, session.Checkpoint or taggedForLevel("LevelStart", session.Level))
			else
				placeAt(player, hubSpawn())
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return AdventureService
