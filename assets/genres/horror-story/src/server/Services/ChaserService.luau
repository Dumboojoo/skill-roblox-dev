--!strict
--[[
	ChaserService – der Verfolger: sehen, hören, jagen, suchen, Streife laufen.

	Drei Zustände:
	  Patrol  läuft die PatrolPoints der Reihe nach ab
	  Chase   sieht einen Spieler und rennt ihm nach (Weg über PathfindingService)
	  Search  hat ihn verloren oder etwas gehört: geht zur letzten bekannten Stelle
	          und wartet dort eine Weile

	Sinne (alles aus Serversicht, also nicht manipulierbar):
	  Sehen   Entfernung + Sichtkegel + freie Sichtlinie (Raycast)
	  Hören   rennende Spieler in HearingRange
	  HideSpots machen unsichtbar, aber nur, wenn der Verfolger den Spieler nicht
	  schon verfolgt und hineinlaufen sieht.

	Horror lebt davon, dass der Verfolger FAIR und lesbar ist: Der Spieler muss
	verstehen, warum er entdeckt wurde. Deshalb klare Regeln statt Zufall.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Horror)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)

local THINK_INTERVAL = 0.15
local REPATH_INTERVAL = 0.5
local WAYPOINT_REACHED = 3.5

local ChaserService = {
	Caught = Signal.new() :: Signal.Signal<Player>,
}

local settings = Config.Chaser
local model: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local state = "Patrol"
local target: Player? = nil
local lastKnown: Vector3? = nil
local lastSeenAt = 0
local searchUntil = 0
local patrolIndex = 1

local waypoints: { PathWaypoint } = {}
local waypointIndex = 1
local lastPathAt = 0
local pathGoal: Vector3? = nil

------------------------------------------------------------------------------
-- Modell
------------------------------------------------------------------------------

local function createModel(): Model
	local assets = ServerStorage:FindFirstChild("Assets")
	local template = if assets then assets:FindFirstChild("Chaser") else nil
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") and template.PrimaryPart then
		return template:Clone()
	end
	local created = Instance.new("Model")
	created.Name = "Chaser"
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = settings.Size
	body.Color = settings.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = created
	created.PrimaryPart = body
	local newHumanoid = Instance.new("Humanoid")
	newHumanoid.RigType = Enum.HumanoidRigType.R15
	newHumanoid.HipHeight = 0.05
	newHumanoid.RequiresNeck = false
	newHumanoid.Parent = created
	return created
end

------------------------------------------------------------------------------
-- Sinne
------------------------------------------------------------------------------

local function isHidden(position: Vector3): boolean
	for _, spot in World.Tagged("HideSpot") do
		if spot:IsA("BasePart") then
			local localPosition = spot.CFrame:PointToObjectSpace(position)
			local half = spot.Size / 2
			if
				math.abs(localPosition.X) <= half.X
				and math.abs(localPosition.Y) <= half.Y
				and math.abs(localPosition.Z) <= half.Z
			then
				return true
			end
		end
	end
	return false
end

local function canSee(chaserRoot: BasePart, character: Model, playerRoot: BasePart): boolean
	local offset = playerRoot.Position - chaserRoot.Position
	local distance = offset.Magnitude
	if distance > settings.SightRange then
		return false
	end
	if distance > 6 then
		local angle = math.deg(math.acos(math.clamp(chaserRoot.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
		if angle > settings.SightAngle then
			return false
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model :: Model, character }
	return Workspace:Raycast(chaserRoot.Position, offset, params) == nil
end

-- Rückgabe: sichtbarer Spieler (nächster) und gehörte Position (nächste).
local function sense(chaserRoot: BasePart): (Player?, Vector3?)
	local seen: Player? = nil
	local seenDistance = math.huge
	local heard: Vector3? = nil
	local heardDistance = settings.HearingRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local playerHumanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not character or not playerHumanoid or playerHumanoid.Health <= 0 then
			continue
		end
		if not playerRoot or not playerRoot:IsA("BasePart") then
			continue
		end
		local distance = (playerRoot.Position - chaserRoot.Position).Magnitude
		-- Wer verfolgt wird, kann sich nicht vor den Augen des Verfolgers verstecken.
		local hidden = isHidden(playerRoot.Position) and player ~= target
		if not hidden and distance < seenDistance and canSee(chaserRoot, character, playerRoot) then
			seen, seenDistance = player, distance
		end
		local speed = (playerRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if speed >= settings.NoiseSpeed and distance < heardDistance then
			heard, heardDistance = playerRoot.Position, distance
		end
	end
	return seen, heard
end

------------------------------------------------------------------------------
-- Bewegung
------------------------------------------------------------------------------

local function moveToward(goal: Vector3, now: number)
	local chaserHumanoid, chaserRoot = humanoid, root
	if not chaserHumanoid or not chaserRoot then
		return
	end

	local goalMoved = pathGoal == nil or (goal - (pathGoal :: Vector3)).Magnitude > 4
	if (goalMoved and now - lastPathAt >= REPATH_INTERVAL) or waypointIndex > #waypoints then
		lastPathAt = now
		pathGoal = goal
		local path = PathfindingService:CreatePath({
			AgentRadius = math.max(settings.Size.X, settings.Size.Z) / 2,
			AgentHeight = settings.Size.Y,
			AgentCanJump = false,
		})
		local ok = pcall(function()
			path:ComputeAsync(chaserRoot.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = path:GetWaypoints()
			waypointIndex = 2 -- der erste Wegpunkt ist die eigene Position
		else
			-- Kein Weg gefunden: direkt darauf zulaufen ist besser als stehen bleiben.
			waypoints = {}
			chaserHumanoid:MoveTo(goal)
			return
		end
	end

	local waypoint = waypoints[waypointIndex]
	if waypoint then
		if (waypoint.Position - chaserRoot.Position).Magnitude < WAYPOINT_REACHED then
			waypointIndex += 1
			waypoint = waypoints[waypointIndex]
		end
		if waypoint then
			chaserHumanoid:MoveTo(waypoint.Position)
		end
	end
end

local function patrolPoints(): { BasePart }
	local points: { BasePart } = {}
	for _, instance in World.Tagged("PatrolPoint") do
		if instance:IsA("BasePart") then
			table.insert(points, instance)
		end
	end
	table.sort(points, function(a, b)
		return World.Attribute(a, "Order", 0) < World.Attribute(b, "Order", 0)
	end)
	return points
end

local function setState(newState: string)
	if state ~= newState then
		state = newState
		-- Clients nutzen das für Musik und Stimmung (z. B. Herzschlag bei "Chase").
		Workspace:SetAttribute("ChaserState", newState)
	end
end

------------------------------------------------------------------------------
-- Denken
------------------------------------------------------------------------------

local function think(now: number)
	local chaserHumanoid, chaserRoot = humanoid, root
	if not chaserHumanoid or not chaserRoot then
		return
	end

	local seen, heard = sense(chaserRoot)
	if seen and seen.Character then
		target = seen
		lastSeenAt = now
		lastKnown = (seen.Character:GetPivot()).Position
		setState("Chase")
	elseif heard and state ~= "Chase" then
		lastKnown = heard
		searchUntil = now + settings.SearchTime + 10
		setState("Search")
	end

	if state == "Chase" then
		chaserHumanoid.WalkSpeed = settings.ChaseSpeed
		local victim = target
		local character = if victim then victim.Character else nil
		local victimHumanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not victim or not character or not victimHumanoid or victimHumanoid.Health <= 0 then
			target = nil
			setState("Patrol")
			return
		end
		local position = character:GetPivot().Position
		if (position - chaserRoot.Position).Magnitude <= settings.CatchRange then
			victimHumanoid:TakeDamage(settings.Damage)
			Net.Fire("Horror.Caught", victim)
			ChaserService.Caught:Fire(victim)
			target = nil
			setState("Patrol")
			return
		end
		if now - lastSeenAt > settings.LoseSightTime then
			-- Sicht verloren: zur letzten bekannten Stelle und dort suchen.
			target = nil
			searchUntil = now + settings.SearchTime + 10
			setState("Search")
			return
		end
		moveToward(position, now)
	elseif state == "Search" then
		chaserHumanoid.WalkSpeed = settings.ChaseSpeed * 0.8
		local goal = lastKnown
		if not goal or now > searchUntil then
			setState("Patrol")
			return
		end
		if (goal - chaserRoot.Position).Magnitude < 5 then
			-- Angekommen: stehen bleiben, bis die Suchzeit um ist.
			searchUntil = math.min(searchUntil, now + settings.SearchTime)
			chaserHumanoid:MoveTo(chaserRoot.Position)
		else
			moveToward(goal, now)
		end
	else
		chaserHumanoid.WalkSpeed = settings.PatrolSpeed
		local points = patrolPoints()
		if #points == 0 then
			return
		end
		patrolIndex = (patrolIndex - 1) % #points + 1
		local point = points[patrolIndex]
		if (point.Position - chaserRoot.Position).Magnitude < 6 then
			patrolIndex = patrolIndex % #points + 1
		else
			moveToward(point.Position, now)
		end
	end
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

-- Lärm an einer Stelle (z. B. umgeworfene Vase, zugeschlagene Tür) lockt den Verfolger an.
function ChaserService:MakeNoise(position: Vector3)
	local chaserRoot = root
	if chaserRoot and state ~= "Chase" and (position - chaserRoot.Position).Magnitude <= settings.HearingRange * 2 then
		lastKnown = position
		searchUntil = os.clock() + settings.SearchTime + 10
		setState("Search")
	end
end

function ChaserService:GetState(): string
	return state
end

function ChaserService:Respawn()
	if model then
		model:Destroy()
	end
	local spawns = World.Tagged("ChaserSpawn")
	local spawn = spawns[1]
	if not spawn or not spawn:IsA("BasePart") then
		return
	end
	local created = createModel()
	local newHumanoid = created:FindFirstChildOfClass("Humanoid") :: Humanoid
	local newRoot = created.PrimaryPart :: BasePart
	newHumanoid.MaxHealth = math.huge
	newHumanoid.Health = math.huge
	newHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	created:PivotTo(spawn.CFrame + Vector3.new(0, newRoot.Size.Y / 2 + 1, 0))
	created.Parent = Workspace
	newRoot:SetNetworkOwner(nil)
	-- Clients finden den Verfolger über diesen Tag (Abstand für die Gefahren-Anzeige).
	created:AddTag("Chaser")

	model, humanoid, root = created, newHumanoid, newRoot
	target = nil
	waypoints = {}
	setState("Patrol")
end

function ChaserService:Init()
	Net.Declare("Horror.Caught")
end

function ChaserService:Start()
	World.Expect("Horror (Verfolger)", {
		{ Tag = "ChaserSpawn", Class = "BasePart", Hint = "Ein Teil mit Tag ChaserSpawn setzen." },
		{ Tag = "PatrolPoint", Min = 2, Class = "BasePart", Attributes = { Order = "number" } },
	})
	ChaserService:Respawn()

	task.spawn(function()
		while true do
			think(os.clock())
			task.wait(THINK_INTERVAL)
		end
	end)
end

return ChaserService
