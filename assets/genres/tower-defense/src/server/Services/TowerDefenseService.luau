--!strict
--[[
	TowerDefenseService – Wellen, Gegner, Türme und Geld. Alles Wichtige passiert hier.

	Leitidee: Gegner sind auf dem Server reine DATEN (Typ, Leben, zurückgelegte
	Strecke), keine Modelle mit Humanoid. Ein einziger Heartbeat rückt alle vor und
	lässt die Türme schießen. Clients bekommen nur Ereignisse (erschienen, besiegt)
	und ein paar Mal pro Sekunde die Positionen; darstellen tun sie selbst.
	So laufen auch 200 Gegner flüssig.

	Ein Spiel pro Server, alle Spieler verteidigen gemeinsam. Geld hat jeder für sich.

	Zustand für Clients:
	  Workspace-Attribute  TDPhase, TDWave, TDBaseHealth, TDPhaseEndsAt (Serverzeit)
	  Player-Attribut      TDCash
	  Remotes              TD.EnemySpawn / TD.EnemyRemove / TD.Enemies (Positionen, unzuverlässig)
	                       TD.TowerPlaced / TD.TowerChanged / TD.TowerRemoved / TD.Shot
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.TowerDefense)
local Net = require(Shared.Net)
local PathMath = require(Shared.TowerDefense.PathMath)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

type Enemy = {
	Id: number,
	Type: string,
	Health: number,
	MaxHealth: number,
	Distance: number,
	Speed: number,
	SlowFactor: number,
	SlowUntil: number,
	Position: Vector3,
}

type Tower = {
	Uid: number,
	Owner: Player,
	Type: string,
	Level: number,
	Position: Vector3,
	NextShot: number,
	Targeting: string,
	Spent: number,
}

local SNAPSHOT_INTERVAL = 0.2
local PLACE_RAY_HEIGHT = 60

local TowerDefenseService = {}

local path: PathMath.Path? = nil
local enemies: { [number]: Enemy } = {}
local towers: { [number]: Tower } = {}
local nextEnemyId = 0
local nextTowerUid = 0
local baseHealth = Config.BaseHealth
local wave = 0
local phase = "Waiting"
local spawning = false
local gameToken = 0 -- macht laufende Wellen-Threads nach einem Neustart ungültig
local skipRequested = false
local healthScale = 1

------------------------------------------------------------------------------
-- Zustand
------------------------------------------------------------------------------

local function setPhase(newPhase: string, duration: number?)
	phase = newPhase
	Workspace:SetAttribute("TDPhase", newPhase)
	Workspace:SetAttribute("TDWave", wave)
	Workspace:SetAttribute("TDBaseHealth", baseHealth)
	Workspace:SetAttribute("TDPhaseEndsAt", if duration then Workspace:GetServerTimeNow() + duration else 0)
end

local function getCash(player: Player): number
	local cash = player:GetAttribute("TDCash")
	return if type(cash) == "number" then cash else 0
end

local function addCash(player: Player, amount: number)
	player:SetAttribute("TDCash", getCash(player) + amount)
end

local function towerPayload(tower: Tower): { [string]: any }
	return {
		Uid = tower.Uid,
		OwnerId = tower.Owner.UserId,
		Type = tower.Type,
		Level = tower.Level,
		Position = tower.Position,
		Targeting = tower.Targeting,
	}
end

------------------------------------------------------------------------------
-- Gegner
------------------------------------------------------------------------------

local function spawnEnemy(enemyType: string)
	local definition = Config.Enemies[enemyType]
	local currentPath = path
	if not definition or not currentPath then
		return
	end
	nextEnemyId += 1
	local health = math.floor(definition.Health * healthScale)
	enemies[nextEnemyId] = {
		Id = nextEnemyId,
		Type = enemyType,
		Health = health,
		MaxHealth = health,
		Distance = 0,
		Speed = definition.Speed,
		SlowFactor = 1,
		SlowUntil = 0,
		Position = currentPath.Points[1],
	}
	Net.FireAll("TD.EnemySpawn", nextEnemyId, enemyType, health)
end

local function removeEnemy(enemy: Enemy, reason: string)
	enemies[enemy.Id] = nil
	Net.FireAll("TD.EnemyRemove", enemy.Id, reason)
end

local function damageEnemy(enemy: Enemy, amount: number, attacker: Player)
	if enemies[enemy.Id] ~= enemy then
		return
	end
	enemy.Health -= amount
	if enemy.Health <= 0 then
		if attacker.Parent == Players then
			addCash(attacker, Config.Enemies[enemy.Type].Reward)
		end
		removeEnemy(enemy, "Killed")
	end
end

------------------------------------------------------------------------------
-- Türme
------------------------------------------------------------------------------

local function pickTarget(tower: Tower, range: number): Enemy?
	local best: Enemy? = nil
	local bestScore = -math.huge
	for _, enemy in enemies do
		local distance = (enemy.Position - tower.Position).Magnitude
		if distance <= range then
			local score
			if tower.Targeting == "Last" then
				score = -enemy.Distance
			elseif tower.Targeting == "Strongest" then
				score = enemy.Health
			elseif tower.Targeting == "Closest" then
				score = -distance
			else -- "First": am weitesten auf dem Weg
				score = enemy.Distance
			end
			if score > bestScore then
				best, bestScore = enemy, score
			end
		end
	end
	return best
end

local function shoot(tower: Tower, now: number)
	local level = Config.Towers[tower.Type].Levels[tower.Level]
	local target = pickTarget(tower, level.Range)
	if not target then
		return
	end
	tower.NextShot = now + level.Cooldown
	Net.FireAll("TD.Shot", tower.Uid, target.Id)

	local victims: { Enemy } = { target }
	if level.Splash then
		for _, enemy in enemies do
			if enemy ~= target and (enemy.Position - target.Position).Magnitude <= level.Splash then
				table.insert(victims, enemy)
			end
		end
	end
	for _, enemy in victims do
		if level.Slow then
			enemy.SlowFactor = math.min(enemy.SlowFactor, level.Slow)
			enemy.SlowUntil = now + (level.SlowTime or 2)
		end
		damageEnemy(enemy, level.Damage, tower.Owner)
	end
end

-- Gibt nil zurück, wenn dort gebaut werden darf, sonst den Grund.
local function placementProblem(player: Player, towerType: string, position: Vector3): (string?, Vector3?)
	local currentPath = path
	if not currentPath then
		return "Kein Weg vorhanden.", nil
	end
	if phase == "Lost" or phase == "Won" then
		return "Das Spiel ist vorbei.", nil
	end

	-- Der Server bestimmt die Höhe selbst: Strahl nach unten auf eine TowerGround-Fläche.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged("TowerGround")
	local result = Workspace:Raycast(
		position + Vector3.new(0, PLACE_RAY_HEIGHT, 0),
		Vector3.new(0, -PLACE_RAY_HEIGHT * 2, 0),
		params
	)
	if not result then
		return "Hier kann nicht gebaut werden.", nil
	end
	local ground = result.Position

	if PathMath.DistanceTo(currentPath, ground) < Config.PathClearance then
		return "Zu nah am Weg.", nil
	end
	local owned = 0
	for _, tower in towers do
		if (tower.Position - ground).Magnitude < Config.MinTowerSpacing then
			return "Zu nah an einem anderen Turm.", nil
		end
		if tower.Owner == player then
			owned += 1
		end
	end
	if owned >= Config.MaxTowersPerPlayer then
		return "Du hast die Höchstzahl an Türmen erreicht.", nil
	end
	if getCash(player) < Config.Towers[towerType].Levels[1].Cost then
		return "Nicht genug Geld.", nil
	end
	return nil, ground
end

local function onPlace(player: Player, towerType: string, position: Vector3)
	local problem, ground = placementProblem(player, towerType, position)
	if problem or not ground then
		Net.Fire("Notify", player, problem or "Hier kann nicht gebaut werden.", "Error")
		return
	end
	local cost = Config.Towers[towerType].Levels[1].Cost
	addCash(player, -cost)
	nextTowerUid += 1
	local tower: Tower = {
		Uid = nextTowerUid,
		Owner = player,
		Type = towerType,
		Level = 1,
		Position = ground,
		NextShot = 0,
		Targeting = "First",
		Spent = cost,
	}
	towers[tower.Uid] = tower
	Net.FireAll("TD.TowerPlaced", towerPayload(tower))
end

local function ownedTower(player: Player, uid: number): Tower?
	local tower = towers[uid]
	return if tower and tower.Owner == player then tower else nil
end

local function onUpgrade(player: Player, uid: number)
	local tower = ownedTower(player, uid)
	if not tower then
		return
	end
	local nextLevel = Config.Towers[tower.Type].Levels[tower.Level + 1]
	if not nextLevel then
		return
	end
	if getCash(player) < nextLevel.Cost then
		Net.Fire("Notify", player, "Nicht genug Geld.", "Error")
		return
	end
	addCash(player, -nextLevel.Cost)
	tower.Level += 1
	tower.Spent += nextLevel.Cost
	Net.FireAll("TD.TowerChanged", towerPayload(tower))
end

local function removeTower(tower: Tower, refund: boolean)
	towers[tower.Uid] = nil
	if refund and tower.Owner.Parent == Players then
		addCash(tower.Owner, math.floor(tower.Spent * Config.SellRefund))
	end
	Net.FireAll("TD.TowerRemoved", tower.Uid)
end

------------------------------------------------------------------------------
-- Spielablauf
------------------------------------------------------------------------------

local function everyPlayer(callback: (player: Player) -> ())
	for _, player in Players:GetPlayers() do
		callback(player)
	end
end

local function resetGame()
	gameToken += 1
	for _, enemy in enemies do
		Net.FireAll("TD.EnemyRemove", enemy.Id, "Reset")
	end
	table.clear(enemies)
	for _, tower in towers do
		Net.FireAll("TD.TowerRemoved", tower.Uid)
	end
	table.clear(towers)
	baseHealth = Config.BaseHealth
	wave = 0
	healthScale = 1
	spawning = false
	everyPlayer(function(player)
		player:SetAttribute("TDCash", Config.StartCash)
	end)
	setPhase("Waiting")
end

local function endGame(won: boolean)
	setPhase(if won then "Won" else "Lost", Config.RestartDelay)
	everyPlayer(function(player)
		DataService:Increment(player, "TowerDefense.GamesPlayed", 1)
		if won then
			DataService:Increment(player, "TowerDefense.Wins", 1)
		end
		local best = DataService:Get(player, "TowerDefense.BestWave")
		if type(best) == "number" and wave > best then
			DataService:Set(player, "TowerDefense.BestWave", wave)
		end
	end)
	local token = gameToken
	task.delay(Config.RestartDelay, function()
		if token == gameToken then
			resetGame()
		end
	end)
end

local function runWave(token: number)
	wave += 1
	local groups = Config.Waves[wave]
	healthScale = 1 + (wave - 1) * Config.HealthGrowthPerWave
	spawning = true
	setPhase("Wave")
	for _, group in groups do
		if group.Delay then
			task.wait(group.Delay)
		end
		for _ = 1, group.Count do
			if token ~= gameToken then
				return
			end
			spawnEnemy(group.Enemy)
			task.wait(group.Interval)
		end
	end
	-- Nur die aktuelle Welle darf das melden: Nach einem Neustart könnte sonst der Rest einer
	-- alten Welle die neue vorzeitig für beendet erklären.
	if token == gameToken then
		spawning = false
	end
end

local function gameLoop()
	while true do
		task.wait(0.25)
		if phase == "Waiting" then
			if #Players:GetPlayers() > 0 and path then
				skipRequested = false
				setPhase("Intermission", Config.Intermission)
			end
		elseif phase == "Intermission" then
			local endsAt = Workspace:GetAttribute("TDPhaseEndsAt") :: number
			if skipRequested or Workspace:GetServerTimeNow() >= endsAt then
				skipRequested = false
				task.spawn(runWave, gameToken)
			end
		elseif phase == "Wave" then
			if not spawning and next(enemies) == nil then
				everyPlayer(function(player)
					addCash(player, Config.WaveBonus)
				end)
				if wave >= #Config.Waves then
					endGame(true)
				else
					setPhase("Intermission", Config.Intermission)
				end
			end
		end
	end
end

local snapshotTimer = 0

local function step(deltaTime: number)
	local currentPath = path
	if not currentPath or (phase ~= "Wave" and phase ~= "Intermission") then
		return
	end
	local now = os.clock()

	for _, enemy in enemies do
		if enemy.SlowFactor < 1 and now >= enemy.SlowUntil then
			enemy.SlowFactor = 1
		end
		enemy.Distance += enemy.Speed * enemy.SlowFactor * deltaTime
		if enemy.Distance >= currentPath.Total then
			baseHealth = math.max(0, baseHealth - Config.Enemies[enemy.Type].Damage)
			Workspace:SetAttribute("TDBaseHealth", baseHealth)
			removeEnemy(enemy, "Leaked")
		else
			enemy.Position = PathMath.PositionAt(currentPath, enemy.Distance)
		end
	end

	if baseHealth <= 0 and phase == "Wave" then
		gameToken += 1
		spawning = false
		endGame(false)
		return
	end

	for _, tower in towers do
		if now >= tower.NextShot then
			shoot(tower, now)
		end
	end

	-- Positionen und Leben in einem Rutsch an alle (unzuverlässig: Ein verlorenes Paket schadet nicht).
	snapshotTimer += deltaTime
	if snapshotTimer >= SNAPSHOT_INTERVAL then
		snapshotTimer = 0
		local snapshot = {}
		for _, enemy in enemies do
			table.insert(snapshot, { enemy.Id, math.floor(enemy.Distance * 10) / 10, enemy.Health, enemy.SlowFactor })
			if #snapshot >= 60 then
				Net.FireAll("TD.Enemies", snapshot)
				snapshot = {}
			end
		end
		if #snapshot > 0 then
			Net.FireAll("TD.Enemies", snapshot)
		end
	end
end

------------------------------------------------------------------------------
-- Für Admin-Befehle
------------------------------------------------------------------------------

function TowerDefenseService:AddCash(player: Player, amount: number)
	addCash(player, amount)
end

function TowerDefenseService:SkipIntermission()
	skipRequested = true
end

function TowerDefenseService:Restart()
	resetGame()
end

------------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------------

function TowerDefenseService:Init()
	for _, name in
		{ "TD.EnemySpawn", "TD.EnemyRemove", "TD.TowerPlaced", "TD.TowerChanged", "TD.TowerRemoved", "TD.Sync" }
	do
		Net.Declare(name)
	end
	Net.Declare("TD.Enemies", { Unreliable = true })
	Net.Declare("TD.Shot", { Unreliable = true })

	Net.On("TD.Place", { Check.keyOf(Config.Towers), Check.Vector3 }, onPlace, { Rate = 4 })
	Net.On("TD.Upgrade", { Check.integer }, onUpgrade, { Rate = 6 })
	Net.On("TD.Sell", { Check.integer }, function(player: Player, uid: number)
		local tower = ownedTower(player, uid)
		if tower then
			removeTower(tower, true)
		end
	end, { Rate = 6 })
	Net.On(
		"TD.Targeting",
		{ Check.integer, Check.oneOf(Config.TargetModes) },
		function(player: Player, uid: number, mode: string)
			local tower = ownedTower(player, uid)
			if tower then
				tower.Targeting = mode
				Net.FireAll("TD.TowerChanged", towerPayload(tower))
			end
		end,
		{ Rate = 6 }
	)
	Net.On("TD.Skip", {}, function(_player: Player)
		if phase == "Intermission" then
			skipRequested = true
		end
	end, { Rate = 1 })
	-- Wer später beitritt, braucht den aktuellen Stand.
	Net.On("TD.RequestSync", {}, function(player: Player)
		local towerList: { any }, enemyList: { any } = {}, {}
		for _, tower in towers do
			table.insert(towerList, towerPayload(tower))
		end
		for _, enemy in enemies do
			table.insert(enemyList, { enemy.Id, enemy.Type, enemy.MaxHealth, enemy.Distance, enemy.Health } :: { any })
		end
		Net.Fire("TD.Sync", player, towerList, enemyList)
	end, { Rate = 1 })
end

function TowerDefenseService:Start()
	World.Expect("Tower Defense", {
		{
			Tag = "PathPoint",
			Min = 2,
			Class = "BasePart",
			Attributes = { Order = "number" },
			Hint = "Wegpunkte als Teile mit Tag PathPoint und Attribut Order (1, 2, 3, …) setzen.",
		},
		{ Tag = "TowerGround", Class = "BasePart", Hint = "Bauflächen mit Tag TowerGround versehen." },
	})
	path = PathMath.fromWorld()
	-- Wird die Welt während des Tests umgebaut, den Weg neu einlesen.
	CollectionService:GetInstanceAddedSignal("PathPoint"):Connect(function()
		path = PathMath.fromWorld()
	end)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("TDCash", Config.StartCash)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, tower in towers do
			if tower.Owner == player then
				removeTower(tower, false)
			end
		end
	end)
	everyPlayer(function(player)
		player:SetAttribute("TDCash", Config.StartCash)
	end)

	setPhase("Waiting")
	RunService.Heartbeat:Connect(step)
	task.spawn(gameLoop)
end

return TowerDefenseService
