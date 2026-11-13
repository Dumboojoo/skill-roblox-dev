--!strict
--[[
	ObbyService – Checkpoints, Tod durch Hindernisse und Zeitmessung.

	Der Server ist zuständig für alles, was zählt: welche Stufe erreicht ist, wo
	man neu erscheint, die Laufzeit. Bewegte Hindernisse laufen auf dem Client
	(ObbyController), damit sie butterweich aussehen; ihr Takt hängt an der
	Serverzeit und ist deshalb bei allen Spielern gleich.

	Schutz gegen Teleport-Schummeln: Ein Checkpoint zählt nur, wenn er der nächste
	ist (Config.AllowCheckpointSkipping = false) und der Server den Charakter
	selbst dort sieht (Touched läuft auf dem Server).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Obby)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

local ObbyService = {
	StageReached = Signal.new() :: Signal.Signal<Player, number>,
	Completed = Signal.new() :: Signal.Signal<Player, number?>, -- Zeit in Sekunden oder nil (kein gültiger Lauf)
}

local checkpoints: { [number]: BasePart } = {}
local lastStage = 0
-- Startzeit eines Laufs ab Stufe 0 (nur dann zählt die Zeit).
local runStart: { [Player]: number } = {}

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

local function moveToCheckpoint(player: Player, stage: number)
	local character = player.Character
	local checkpoint = checkpoints[stage] or checkpoints[0]
	if character and checkpoint then
		character:PivotTo(checkpoint.CFrame + Vector3.new(0, checkpoint.Size.Y / 2 + Config.RespawnHeight, 0))
	end
end

local function reachStage(player: Player, stage: number)
	local current = DataService:Get(player, "Obby.Stage")
	if type(current) ~= "number" or stage <= current then
		return
	end
	if not Config.AllowCheckpointSkipping and stage ~= current + 1 then
		return
	end

	DataService:Set(player, "Obby.Stage", stage)
	ObbyService.StageReached:Fire(player, stage)

	if stage >= lastStage then
		local started = runStart[player]
		local elapsed = if started then os.clock() - started else nil
		runStart[player] = nil
		DataService:Increment(player, "Obby.Completions", 1)
		if elapsed then
			local best = DataService:Get(player, "Obby.BestTime")
			if best == 0 or elapsed < best then
				DataService:Set(player, "Obby.BestTime", elapsed)
			end
		end
		Net.Fire("Obby.Finished", player, elapsed)
		ObbyService.Completed:Fire(player, elapsed)
	else
		Net.Fire("Obby.Checkpoint", player, stage)
	end
end

-- Zurück zum Start; ab hier läuft die Zeit für einen Bestzeit-Lauf.
function ObbyService:Restart(player: Player)
	if not DataService:IsLoaded(player) then
		return
	end
	DataService:Set(player, "Obby.Stage", 0)
	runStart[player] = os.clock()
	moveToCheckpoint(player, 0)
	Net.Fire("Obby.RunStarted", player)
end

-- Für Admin-Befehle: Stufe direkt setzen (macht den Zeitlauf ungültig).
function ObbyService:SetStage(player: Player, stage: number)
	local clamped = math.clamp(math.floor(stage), 0, lastStage)
	runStart[player] = nil
	DataService:Set(player, "Obby.Stage", clamped)
	moveToCheckpoint(player, clamped)
end

function ObbyService:GetLastStage(): number
	return lastStage
end

------------------------------------------------------------------------------

function ObbyService:Init()
	Net.Declare("Obby.Checkpoint")
	Net.Declare("Obby.Finished")
	Net.Declare("Obby.RunStarted")
	Net.On("Obby.Restart", {}, function(player: Player)
		ObbyService:Restart(player)
	end, { Rate = 1, Burst = 2 })
end

function ObbyService:Start()
	World.Expect("Obby", {
		{
			Tag = "Checkpoint",
			Min = 2,
			Class = "BasePart",
			Attributes = { Stage = "number" },
			Hint = "Teile mit Tag Checkpoint und Attribut Stage (0 = Start, 1, 2, …) anlegen.",
		},
	})

	World.Observe("Checkpoint", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local stage = World.Attribute(instance, "Stage", -1)
		if stage < 0 then
			return nil
		end
		checkpoints[stage] = instance
		lastStage = math.max(lastStage, stage)
		workspace:SetAttribute("ObbyLastStage", lastStage)
		local connection = instance.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player then
				reachStage(player, stage)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	World.Observe("KillPart", function(instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local connection = instance.Touched:Connect(function(hit)
			local _player, humanoid = playerFromHit(hit)
			if humanoid then
				-- TakeDamage statt Health = 0: beachtet Admin-Gott-Modus und Kraftfelder.
				humanoid:TakeDamage(humanoid.MaxHealth)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end)

	-- Förderbänder: Ein verankertes Teil mit Geschwindigkeit schiebt alles, was darauf steht.
	World.Observe("Conveyor", function(instance)
		if instance:IsA("BasePart") then
			local speed = World.Attribute(instance, "Speed", Config.Defaults.ConveyorSpeed)
			instance.AssemblyLinearVelocity = instance.CFrame.LookVector * speed
		end
		return nil
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			local data = DataService:WaitForData(player)
			if not data or player.Character ~= character then
				return
			end
			-- Einen Moment warten: Direkt beim Erscheinen setzt Roblox die Position noch selbst.
			task.wait(0.1)
			moveToCheckpoint(player, data.Obby.Stage)
			-- Spawn-Schutz entfernen: Sonst könnte man nach jedem Tod ein paar Sekunden lang über
			-- tödliche Teile laufen. Der Gott-Modus der Admin-Konsole bleibt unberührt.
			for _, child in character:GetChildren() do
				if child:IsA("ForceField") and child.Name ~= "AdminGodField" then
					child:Destroy()
				end
			end
		end)
		if player.Character then
			local data = DataService:WaitForData(player)
			if data then
				moveToCheckpoint(player, data.Obby.Stage)
			end
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		runStart[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end

	-- Wer bei Stufe 0 neu beginnt, startet automatisch einen Zeitlauf.
	DataService:OnPlayerLoaded(function(player, data)
		if data.Obby.Stage == 0 then
			runStart[player] = os.clock()
		end
	end)
end

return ObbyService
