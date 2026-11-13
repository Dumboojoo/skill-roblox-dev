--!strict
--[[
	DungeonService – baut den Dungeon aus dem Grundriss, steuert Räume, Gegner,
	Beute und den Durchlauf.

	Ablauf eines Durchlaufs:
	  1. Grundriss würfeln (shared/Dungeon/Layout, mit Seed)
	  2. Räume aufstellen: eigene Modelle aus ServerStorage.Assets.DungeonRooms
	     oder ersatzweise Block-Räume
	  3. Betritt ein Spieler einen Kampfraum, schließen sich die Gitter und die
	     Gegner erscheinen. Sind alle besiegt, öffnen sich die Gitter wieder.
	  4. Boss besiegt -> Beute für alle, Zeit wird gewertet, neuer Dungeon.

	Gegner: eine gemeinsame Schleife für alle (wie im RPG-Beispiel), der Server
	besitzt ihre Physik.

	Für eigene Server pro Gruppe (Lobby -> Dungeon) siehe references/genres/dungeon.md.
	Dieser Service läuft so, wie er ist, in jedem Server, in dem er geladen wird.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Dungeon)
local Layout = require(Shared.Dungeon.Layout)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

type Room = {
	Cell: Layout.Cell,
	Center: Vector3,
	Gates: { BasePart },
	Spawns: { Vector3 },
	State: string, -- "Idle" | "Active" | "Cleared"
	MobsAlive: number,
	Looted: { [Player]: boolean },
}

type MobState = {
	Humanoid: Humanoid,
	Root: BasePart,
	Definition: Config.Mob,
	Room: Room,
	NextAttack: number,
}

local THINK_INTERVAL = 0.2
local ENTER_MARGIN = 8 -- so weit muss man im Raum stehen, bevor er sich schließt
local WALL_THICKNESS = 2

local KIND_COLORS: { [string]: Color3 } = {
	Start = Color3.fromRGB(90, 110, 130),
	Combat = Color3.fromRGB(86, 82, 90),
	Treasure = Color3.fromRGB(130, 112, 70),
	Boss = Color3.fromRGB(110, 60, 70),
}

local DungeonService = {
	Completed = Signal.new() :: Signal.Signal<number>, -- Dauer in Sekunden
}

local folder: Folder? = nil
local rooms: { [string]: Room } = {}
local cells: { Layout.Cell } = {}
local mobs: { [Model]: MobState } = {}
local attackCooldowns: { [Player]: number } = {}
local runStart = 0
local runToken = 0
local random = Random.new()

------------------------------------------------------------------------------
-- Räume bauen
------------------------------------------------------------------------------

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Slate
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function setGate(gate: BasePart, closed: boolean)
	gate.CanCollide = closed
	gate.Transparency = if closed then 0.25 else 1
end

local function defaultSpawns(center: Vector3): { Vector3 }
	local list = {}
	local radius = Config.RoomSize * 0.25
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		table.insert(list, center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	return list
end

local function addChest(room: Room, chest: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Öffnen"
	prompt.ObjectText = "Truhe"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = chest
	prompt.Triggered:Connect(function(player)
		if not room.Looted[player] then
			room.Looted[player] = true
			DungeonService:GiveLoot(player, 1)
		else
			Net.Fire("Notify", player, "Diese Truhe hast du schon geöffnet.", "Info")
		end
	end)
end

-- Ersatz-Raum aus Blöcken: Boden, vier Wände, Türöffnungen mit Gitter.
local function buildBlockRoom(room: Room, parent: Instance)
	local size = Config.RoomSize
	local height = Config.WallHeight
	local color = KIND_COLORS[room.Cell.Kind] or KIND_COLORS.Combat
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.35)
	local center = room.Center

	block("Floor", Vector3.new(size, 2, size), CFrame.new(center - Vector3.new(0, 1, 0)), color, parent)

	for _, direction in Layout.Directions do
		local normal = Vector3.new(direction.X, 0, direction.Y)
		local along = Vector3.new(-direction.Y, 0, direction.X) -- Richtung entlang der Wand
		local wallCenter = center + normal * (size / 2 - WALL_THICKNESS / 2) + Vector3.new(0, height / 2, 0)
		local frame = CFrame.lookAt(wallCenter, wallCenter + normal)
		local hasDoor = (room.Cell.Doors :: any)[direction.Name] == true

		if hasDoor then
			local segment = (size - Config.DoorWidth) / 2
			for _, side in { -1, 1 } do
				local offset = along * side * (Config.DoorWidth / 2 + segment / 2)
				block("Wall", Vector3.new(segment, height, WALL_THICKNESS), frame + offset, wallColor, parent)
			end
			local gate = block(
				"Gate",
				Vector3.new(Config.DoorWidth, height, WALL_THICKNESS),
				frame,
				Color3.fromRGB(255, 90, 60),
				parent
			)
			gate.Material = Enum.Material.ForceField
			setGate(gate, false)
			table.insert(room.Gates, gate)
		else
			block("Wall", Vector3.new(size, height, WALL_THICKNESS), frame, wallColor, parent)
		end
	end

	if room.Cell.Kind == "Treasure" then
		local chest = block(
			"Chest",
			Vector3.new(4, 3, 3),
			CFrame.new(center + Vector3.new(0, 1.5, 0)),
			Color3.fromRGB(214, 170, 60),
			parent
		)
		chest.Material = Enum.Material.Wood
		addChest(room, chest)
	end
	room.Spawns = defaultSpawns(center)
end

-- Eigener Raum aus ServerStorage.Assets.DungeonRooms.<Art>. Gibt false zurück, wenn es keinen gibt.
local function buildCustomRoom(room: Room, parent: Instance): boolean
	local assets = ServerStorage:FindFirstChild("Assets")
	local library = if assets then assets:FindFirstChild("DungeonRooms") else nil
	local entry = if library then library:FindFirstChild(room.Cell.Kind) else nil
	local template: Instance? = entry
	if entry and entry:IsA("Folder") then
		local variants = entry:GetChildren()
		template = if #variants > 0 then variants[random:NextInteger(1, #variants)] else nil
	end
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		return false
	end

	local model = template:Clone()
	model:PivotTo(CFrame.new(room.Center))
	model.Parent = parent

	for _, direction in Layout.Directions do
		local door = model:FindFirstChild("Door" .. direction.Name, true)
		if door and door:IsA("BasePart") and (room.Cell.Doors :: any)[direction.Name] then
			setGate(door, false)
			table.insert(room.Gates, door)
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:HasTag("MobSpawn") then
				table.insert(room.Spawns, descendant.Position)
			elseif descendant:HasTag("Chest") then
				addChest(room, descendant)
			end
		end
	end
	if #room.Spawns == 0 then
		room.Spawns = defaultSpawns(room.Center)
	end
	return true
end

------------------------------------------------------------------------------
-- Gegner
------------------------------------------------------------------------------

local function completeRun()
	local elapsed = os.clock() - runStart
	for _, player in Players:GetPlayers() do
		if DataService:IsLoaded(player) then
			DataService:Increment(player, "Dungeon.Clears", 1)
			local best = DataService:Get(player, "Dungeon.BestTime")
			if best == 0 or elapsed < best then
				DataService:Set(player, "Dungeon.BestTime", elapsed)
			end
			DungeonService:GiveLoot(player, Config.BossLootRolls)
		end
	end
	Net.FireAll("Dungeon.Completed", elapsed, Config.RestartDelay)
	DungeonService.Completed:Fire(elapsed)
	local token = runToken
	task.delay(Config.RestartDelay, function()
		if token == runToken then
			DungeonService:StartRun()
		end
	end)
end

local function onMobDied(model: Model, state: MobState)
	mobs[model] = nil
	task.delay(1.2, model.Destroy, model)
	local room = state.Room
	room.MobsAlive -= 1
	if room.MobsAlive <= 0 and room.State == "Active" then
		room.State = "Cleared"
		for _, gate in room.Gates do
			setGate(gate, false)
		end
		Net.FireAll("Dungeon.RoomState", room.Cell.X, room.Cell.Y, "Cleared")
		if room.Cell.Kind == "Boss" then
			completeRun()
		end
	end
end

local function spawnMob(room: Room, mobType: string, position: Vector3)
	local definition = Config.Mobs[mobType]
	local parent = folder
	if not definition or not parent then
		return
	end
	local model = Instance.new("Model")
	model.Name = mobType
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = definition.Size
	root.Color = definition.Color
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.05
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = definition.Health
	humanoid.Health = definition.Health
	humanoid.WalkSpeed = definition.Speed
	humanoid.DisplayName = definition.DisplayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model

	model:PivotTo(CFrame.new(position + Vector3.new(0, definition.Size.Y / 2 + 1, 0)))
	model.Parent = parent
	root:SetNetworkOwner(nil)

	local state: MobState = { Humanoid = humanoid, Root = root, Definition = definition, Room = room, NextAttack = 0 }
	mobs[model] = state
	room.MobsAlive += 1
	humanoid.Died:Once(function()
		onMobDied(model, state)
	end)
end

local function activate(room: Room)
	room.State = "Active"
	for _, gate in room.Gates do
		setGate(gate, true)
	end
	Net.FireAll("Dungeon.RoomState", room.Cell.X, room.Cell.Y, "Active")
	local index = 0
	local groups: { { Mob: string, Count: number } } = Config.RoomMobs[room.Cell.Kind] or {}
	for _, group in groups do
		for _ = 1, group.Count do
			index += 1
			spawnMob(room, group.Mob, room.Spawns[(index - 1) % #room.Spawns + 1])
		end
	end
end

local function think(now: number)
	for _, state in mobs do
		if state.Humanoid.Health <= 0 then
			continue
		end
		local nearest: Humanoid? = nil
		local nearestRoot: BasePart? = nil
		local nearestDistance = Config.RoomSize
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local distance = (root.Position - state.Root.Position).Magnitude
				if distance < nearestDistance then
					nearest, nearestRoot, nearestDistance = humanoid, root, distance
				end
			end
		end
		if nearest and nearestRoot then
			if nearestDistance <= state.Definition.AttackRange then
				state.Humanoid:MoveTo(state.Root.Position)
				if now >= state.NextAttack then
					state.NextAttack = now + state.Definition.AttackCooldown
					nearest:TakeDamage(state.Definition.Damage)
				end
			else
				state.Humanoid:MoveTo(nearestRoot.Position)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Spieler
------------------------------------------------------------------------------

local function roomAt(position: Vector3): (Room?, boolean)
	local size = Config.RoomSize
	local offset = position - Config.Origin
	local x, y = math.round(offset.X / size), math.round(offset.Z / size)
	local room = rooms[Layout.Key(x, y)]
	if not room then
		return nil, false
	end
	local inner = size / 2 - ENTER_MARGIN
	local deep = math.abs(offset.X - x * size) < inner and math.abs(offset.Z - y * size) < inner
	return room, deep
end

local function placeAtStart(player: Player)
	local start = rooms[Layout.Key(0, 0)]
	local character = player.Character
	if start and character then
		character:PivotTo(CFrame.new(start.Center + Vector3.new(random:NextNumber(-6, 6), 5, random:NextNumber(-6, 6))))
	end
end

local function checkPlayers()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local room, deep = roomAt(root.Position)
			if room and deep and room.State == "Idle" and Config.RoomMobs[room.Cell.Kind] then
				activate(room)
			end
		end
	end
end

local function onAttack(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local now = os.clock()
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	if now < (attackCooldowns[player] or 0) - 0.05 then
		return
	end
	local attack = Config.Attack
	attackCooldowns[player] = now + attack.Cooldown

	-- Trefferzone aus Serversicht: Kasten vor dem Spieler.
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local center = root.CFrame * CFrame.new(0, 0, -attack.Range / 2)
	local struck: { [Model]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(center, Vector3.new(attack.Width, 8, attack.Range), params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local state = if model then mobs[model] else nil
		if model and state and not struck[model] then
			struck[model] = true
			state.Humanoid:TakeDamage(attack.Damage)
		end
	end
	Net.FireNear("Dungeon.Swing", root.Position, 120, player)
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

-- Würfelt `rolls`-mal Beute für einen Spieler und schreibt sie gut.
function DungeonService:GiveLoot(player: Player, rolls: number)
	if not DataService:IsLoaded(player) then
		return
	end
	for _ = 1, rolls do
		local entry = Layout.PickWeighted(Config.Loot, random:NextNumber())
		DataService:Increment(player, { "Dungeon", "Loot", entry.Id }, 1)
		DataService:Increment(player, "Dungeon.Coins", entry.Coins)
		Net.Fire("Notify", player, `{entry.Rarity}: {entry.DisplayName} (+{entry.Coins} Münzen)`, "Success", 4)
	end
end

local function layoutPayload(): { [string]: any }
	local list = {}
	for _, cell in cells do
		local room = rooms[Layout.Key(cell.X, cell.Y)]
		table.insert(list, { X = cell.X, Y = cell.Y, Kind = cell.Kind, State = if room then room.State else "Idle" })
	end
	return { Cells = list, RoomSize = Config.RoomSize, Origin = Config.Origin }
end

function DungeonService:StartRun(seed: number?)
	runToken += 1
	if folder then
		folder:Destroy()
	end
	table.clear(rooms)
	table.clear(mobs)

	local created = Instance.new("Folder")
	created.Name = "Dungeon"
	folder = created

	cells = Layout.Generate(seed or random:NextInteger(1, 2 ^ 30), Config.RoomCount)
	for _, cell in cells do
		local room: Room = {
			Cell = cell,
			Center = Config.Origin + Vector3.new(cell.X * Config.RoomSize, 0, cell.Y * Config.RoomSize),
			Gates = {},
			Spawns = {},
			State = "Idle",
			MobsAlive = 0,
			Looted = {},
		}
		rooms[Layout.Key(cell.X, cell.Y)] = room
		if not buildCustomRoom(room, created) then
			buildBlockRoom(room, created)
		end
	end
	created.Parent = Workspace

	runStart = os.clock()
	for _, player in Players:GetPlayers() do
		placeAtStart(player)
	end
	Net.FireAll("Dungeon.Layout", layoutPayload())
end

function DungeonService:Init()
	for _, name in { "Dungeon.Layout", "Dungeon.RoomState", "Dungeon.Completed" } do
		Net.Declare(name)
	end
	Net.Declare("Dungeon.Swing", { Unreliable = true })
	Net.On("Dungeon.Attack", {}, onAttack, { Rate = 6 })
	Net.On("Dungeon.RequestLayout", {}, function(player: Player)
		Net.Fire("Dungeon.Layout", player, layoutPayload())
	end, { Rate = 1 })
end

function DungeonService:Start()
	DungeonService:StartRun()

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			placeAtStart(player)
		end)
		if player.Character then
			placeAtStart(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		attackCooldowns[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	task.spawn(function()
		while true do
			checkPlayers()
			think(os.clock())
			task.wait(THINK_INTERVAL)
		end
	end)
end

return DungeonService
