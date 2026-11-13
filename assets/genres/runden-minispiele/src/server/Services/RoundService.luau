--!strict
--[[
	RoundService – der Rundenablauf: Lobby -> Abstimmung -> Minispiel -> Ergebnis.

	Der Ablauf ist EINE Schleife, die Phase für Phase durchläuft. Jede Phase setzt
	Attribute am Workspace (RoundPhase, RoundEndsAt, RoundMinigame), aus denen alle
	Clients ihre Anzeige bauen. Minispiele sind eigene Dateien in server/Minigames
	und werden automatisch gefunden; der Vertrag steht in server/RoundTypes.

	Neues Minispiel: Datei in server/Minigames anlegen, Map in Studio bauen und
	mit Tag MinigameMap + Attribut Minigame = Dateiname versehen. Fertig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.Rounds)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Trove = require(Shared.Util.Trove)
local World = require(Shared.Util.World)
local RoundTypes = require(script.Parent.Parent.RoundTypes)
local DataService = require(script.Parent.DataService)

type Option = { Id: string, Minigame: RoundTypes.Minigame, Map: Model }

local RoundService = {
	RoundEnded = Signal.new() :: Signal.Signal<{ Player }, string>, -- (Sieger, Minispiel-Id)
}

local minigames: { [string]: RoundTypes.Minigame } = {}
local random = Random.new()

local alive: { Player } = {}
local options: { Option } = {}
local votes: { [Player]: number } = {}
local roundFinished = false
local winners: { Player } = {}
local skipPhase = false
local forcedMinigame: string? = nil

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function setPhase(phase: string, duration: number?)
	Workspace:SetAttribute("RoundPhase", phase)
	Workspace:SetAttribute("RoundEndsAt", if duration then Workspace:GetServerTimeNow() + duration else 0)
end

-- Wartet `seconds` oder bis `stop()` wahr wird (auch bei Admin-Befehl "skipround").
local function waitPhase(seconds: number, stop: (() -> boolean)?)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if skipPhase or (stop and stop()) then
			break
		end
		task.wait(0.2)
	end
	skipPhase = false
end

local function teleport(player: Player, target: BasePart)
	local character = player.Character
	if character then
		character:PivotTo(target.CFrame + Vector3.new(0, target.Size.Y / 2 + 4, 0))
	end
end

local function toLobby(player: Player)
	local spawns = World.Tagged("LobbySpawn")
	local spawn = spawns[random:NextInteger(1, math.max(#spawns, 1))]
	if spawn and spawn:IsA("BasePart") then
		teleport(player, spawn)
	end
end

local function setAlive(player: Player, state: boolean)
	player:SetAttribute("RoundAlive", state)
	local index = table.find(alive, player)
	if state and not index then
		table.insert(alive, player)
	elseif not state and index then
		table.remove(alive, index)
	end
	Workspace:SetAttribute("RoundAliveCount", #alive)
end

local function eliminate(player: Player)
	if not table.find(alive, player) then
		return
	end
	setAlive(player, false)
	toLobby(player)
	Net.Fire("Notify", player, "Du bist ausgeschieden. Du kannst jetzt zuschauen.", "Error")
end

local function availableOptions(): { Option }
	local list: { Option } = {}
	for _, map in World.Tagged("MinigameMap") do
		local id = map:GetAttribute("Minigame")
		local minigame = if type(id) == "string" then minigames[id] else nil
		if minigame and map:IsA("Model") then
			table.insert(list, { Id = id :: string, Minigame = minigame, Map = map })
		end
	end
	return list
end

------------------------------------------------------------------------------
-- Phasen
------------------------------------------------------------------------------

local function runVote(): Option?
	local all = availableOptions()
	if #all == 0 then
		return nil
	end
	local forced = forcedMinigame
	forcedMinigame = nil
	if forced then
		for _, option in all do
			if option.Id == forced then
				return option
			end
		end
	end

	-- Zufällige Auswahl ohne Wiederholung.
	options = {}
	while #options < Config.VoteOptions and #all > 0 do
		table.insert(options, table.remove(all, random:NextInteger(1, #all)) :: Option)
	end
	if #options == 1 then
		return options[1]
	end

	table.clear(votes)
	local payload = {}
	for _, option in options do
		table.insert(payload, { Name = option.Minigame.DisplayName, Description = option.Minigame.Description })
	end
	setPhase("Voting", Config.VoteTime)
	Net.FireAll("Round.VoteOptions", payload)
	waitPhase(Config.VoteTime)

	local counts = table.create(#options, 0)
	for _, choice in votes do
		counts[choice] += 1
	end
	local best: { number } = {}
	local bestCount = -1
	for index, count in counts do
		if count > bestCount then
			best, bestCount = { index }, count
		elseif count == bestCount then
			table.insert(best, index)
		end
	end
	return options[best[random:NextInteger(1, #best)]]
end

local function runMinigame(option: Option)
	local minigame = option.Minigame
	local trove = Trove.new()
	roundFinished = false
	winners = {}
	table.clear(alive)

	local spawns: { BasePart } = {}
	for _, spawn in World.Tagged("MinigameSpawn") do
		if spawn:IsA("BasePart") and spawn:IsDescendantOf(option.Map) then
			table.insert(spawns, spawn)
		end
	end
	if #spawns == 0 then
		warn(`[Runden] {option.Map:GetFullName()} hat keine Teile mit Tag MinigameSpawn.`)
		return
	end

	local participants = 0
	for index, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 then
			participants += 1
			setAlive(player, true)
			teleport(player, spawns[(index - 1) % #spawns + 1])
			-- Tod während der Runde = ausgeschieden.
			trove:Connect(humanoid.Died, function()
				setAlive(player, false)
			end)
			DataService:Increment(player, "Rounds.Played", 1)
			DataService:Increment(player, "Rounds.Coins", Config.PlayCoins)
		end
	end
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		setAlive(player, false)
	end)

	Workspace:SetAttribute("RoundMinigame", minigame.DisplayName)
	setPhase("Playing", minigame.Duration)
	local endsAt = os.clock() + minigame.Duration

	local context: RoundTypes.Context = {
		Map = option.Map,
		Trove = trove,
		Alive = function()
			return alive
		end,
		IsAlive = function(player: Player)
			return table.find(alive, player) ~= nil
		end,
		Eliminate = eliminate,
		Finish = function(list: { Player })
			winners = list
			roundFinished = true
		end,
		TimeLeft = function()
			return math.max(0, endsAt - os.clock())
		end,
	}

	local ok, problem = xpcall(minigame.Start :: any, debug.traceback, context)
	if not ok then
		warn(`[Runden] {option.Id}.Start ist fehlgeschlagen:\n{problem}`)
		-- Kaputtes Minispiel: Runde ohne Sieger beenden, statt allen einen Sieg gutzuschreiben.
		roundFinished = true
	else
		waitPhase(minigame.Duration, function()
			-- Mit mehreren Spielern endet die Runde, sobald nur noch einer übrig ist.
			return roundFinished or #alive == 0 or (participants > 1 and #alive <= 1)
		end)
	end
	if not roundFinished then
		winners = table.clone(alive)
	end

	trove:Clean()

	for _, player in winners do
		if player.Parent == Players then
			DataService:Increment(player, "Rounds.Wins", 1)
			DataService:Increment(player, "Rounds.Coins", Config.WinCoins)
		end
	end
	for _, player in table.clone(alive) do
		setAlive(player, false)
		toLobby(player)
	end

	local names = {}
	for _, player in winners do
		table.insert(names, player.DisplayName)
	end
	Net.FireAll("Round.Results", names, minigame.DisplayName)
	RoundService.RoundEnded:Fire(winners, option.Id)
end

local function loop()
	while true do
		if #Players:GetPlayers() < Config.MinPlayers then
			setPhase("Waiting")
			task.wait(1)
			continue
		end

		setPhase("Intermission", Config.Intermission)
		waitPhase(Config.Intermission)

		local option = runVote()
		if not option then
			setPhase("Waiting")
			task.wait(3)
			continue
		end

		runMinigame(option)
		setPhase("Results", Config.ResultTime)
		waitPhase(Config.ResultTime)
	end
end

------------------------------------------------------------------------------
-- Für Admin-Befehle
------------------------------------------------------------------------------

function RoundService:SkipPhase()
	skipPhase = true
end

function RoundService:ForceMinigame(id: string): boolean
	if minigames[id] then
		forcedMinigame = id
		return true
	end
	return false
end

function RoundService:GetMinigameIds(): { string }
	local ids = {}
	for id in minigames do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

------------------------------------------------------------------------------

function RoundService:Init()
	for _, module in script.Parent.Parent.Minigames:GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, minigame = pcall(require :: any, module)
			if ok and type(minigame) == "table" and type(minigame.Start) == "function" then
				minigames[module.Name] = minigame
			else
				warn(`[Runden] Minispiel {module.Name} konnte nicht geladen werden: {minigame}`)
			end
		end
	end

	Net.Declare("Round.VoteOptions")
	Net.Declare("Round.Results")
	Net.On("Round.Vote", { Check.integerRange(1, Config.VoteOptions) }, function(player: Player, choice: number)
		if Workspace:GetAttribute("RoundPhase") == "Voting" and options[choice] then
			votes[player] = choice
		end
	end, { Rate = 4 })
end

function RoundService:Start()
	World.Expect("Runden", {
		{ Tag = "LobbySpawn", Class = "BasePart", Hint = "Mindestens ein Teil in der Lobby mit Tag LobbySpawn." },
		{
			Tag = "MinigameMap",
			Class = "Model",
			Attributes = { Minigame = "string" },
			Hint = "Je Minispiel ein Map-Model mit Tag MinigameMap und Attribut Minigame.",
		},
		{ Tag = "MinigameSpawn", Class = "BasePart" },
	})
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
	end)
	task.spawn(loop)
end

return RoundService
