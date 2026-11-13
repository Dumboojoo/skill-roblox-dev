--!strict
--[[
	RaceService – Autos bereitstellen, Rennablauf, Checkpoints, Runden, Zeiten.

	Wer fährt das Auto? Der CLIENT des Fahrers berechnet die Fahrphysik (der Server
	gibt ihm dafür den Netzwerk-Besitz am Wagen). Nur so reagiert die Lenkung ohne
	Verzögerung. Der SERVER wertet dafür das Rennen aus und prüft es:
	  - Checkpoints müssen der Reihe nach durchfahren werden (keine Abkürzungen),
	  - zwischen zwei Checkpoints muss mindestens so viel Zeit liegen, wie das Auto
	    bei 1,5-facher Höchstgeschwindigkeit bräuchte (kein Teleportieren).

	Zustand für Clients: Workspace-Attribute RacePhase, RaceEndsAt;
	Player-Attribute RaceLap, RacePosition, RaceCheckpoint.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Racing)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

type Racer = {
	Player: Player,
	Car: Model,
	Chassis: BasePart,
	Next: number, -- Order des nächsten Checkpoints
	Lap: number,
	LastCheckpointAt: number,
	LapStartedAt: number,
	BestLap: number,
	FinishTime: number?,
}

local SPEED_TOLERANCE = 1.5

local RaceService = {}

local racers: { [Player]: Racer } = {}
local checkpoints: { BasePart } = {}
local raceStart = 0
local skipPhase = false
local random = Random.new()

------------------------------------------------------------------------------
-- Auto
------------------------------------------------------------------------------

local function weld(a: BasePart, b: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = a
	constraint.Part1 = b
	constraint.Parent = b
end

local function blockCar(): Model
	local settings = Config.Car
	local model = Instance.new("Model")

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = settings.Size
	chassis.Color = settings.Color
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	-- Kaum Reibung: Der Wagen soll nicht an Wänden und Boden hängen bleiben.
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0.1)
	chassis.Parent = model
	model.PrimaryPart = chassis

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Transparency = 1
	seat.Massless = true
	seat.CanCollide = false
	seat.CFrame = chassis.CFrame * CFrame.new(0, settings.Size.Y / 2 + 0.3, 0.5)
	seat.Parent = model
	weld(chassis, seat)

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(settings.Size.X * 0.8, 1.6, settings.Size.Z * 0.4)
	cabin.Color = Color3.fromRGB(30, 34, 44)
	cabin.Massless = true
	cabin.CanCollide = false
	cabin.CFrame = chassis.CFrame * CFrame.new(0, settings.Size.Y / 2 + 0.8, 1.2)
	cabin.Parent = model
	weld(chassis, cabin)

	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local wheel = Instance.new("Part")
			wheel.Name = "Wheel"
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(1.2, 2.6, 2.6)
			wheel.Color = Color3.fromRGB(24, 24, 28)
			wheel.Massless = true
			wheel.CanCollide = false
			wheel.CFrame = chassis.CFrame
				* CFrame.new(x * (settings.Size.X / 2 + 0.2), -0.9, z * settings.Size.Z * 0.33)
			wheel.Parent = model
			weld(chassis, wheel)
		end
	end
	return model
end

local function createCar(player: Player, grid: BasePart): (Model?, BasePart?)
	local assets = ServerStorage:FindFirstChild("Assets")
	local template = if assets then assets:FindFirstChild("Car") else nil
	local car: Model
	if
		template
		and template:IsA("Model")
		and template.PrimaryPart
		and template:FindFirstChildOfClass("VehicleSeat")
	then
		car = template:Clone()
	else
		car = blockCar()
	end
	local chassis = car.PrimaryPart
	local seat = car:FindFirstChildOfClass("VehicleSeat")
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not chassis or not seat or not humanoid or humanoid.Health <= 0 then
		car:Destroy()
		return nil, nil
	end

	car.Name = `Car_{player.UserId}`
	car:SetAttribute("OwnerId", player.UserId)
	car:PivotTo(grid.CFrame + Vector3.new(0, Config.Car.SuspensionLength, 0))
	chassis.Anchored = true -- bis zum Startsignal
	car.Parent = Workspace
	car:AddTag("RaceCar")
	seat:Sit(humanoid)
	return car, chassis
end

local function removeRacer(player: Player)
	local racer = racers[player]
	if not racer then
		return
	end
	racers[player] = nil
	racer.Car:Destroy()
	player:SetAttribute("RaceLap", nil)
	player:SetAttribute("RacePosition", nil)
	player:SetAttribute("RaceCheckpoint", nil)
	local lobby = World.Tagged("LobbySpawn")[1]
	if lobby and lobby:IsA("BasePart") and player.Character then
		player.Character:PivotTo(lobby.CFrame + Vector3.new(0, 5, 0))
	end
end

------------------------------------------------------------------------------
-- Strecke
------------------------------------------------------------------------------

local function loadCheckpoints()
	table.clear(checkpoints)
	for _, instance in World.Tagged("RaceCheckpoint") do
		if instance:IsA("BasePart") and type(instance:GetAttribute("Order")) == "number" then
			table.insert(checkpoints, instance)
		end
	end
	table.sort(checkpoints, function(a, b)
		return (a:GetAttribute("Order") :: number) < (b:GetAttribute("Order") :: number)
	end)
end

local function isInside(part: BasePart, position: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function finish(racer: Racer, now: number)
	racer.FinishTime = now - raceStart
	racer.Chassis.Anchored = true
	local player = racer.Player
	DataService:Increment(player, "Racing.Races", 1)
	local best = DataService:Get(player, "Racing.BestTime")
	if best == 0 or (racer.FinishTime :: number) < best then
		DataService:Set(player, "Racing.BestTime", racer.FinishTime)
	end
	local bestLap = DataService:Get(player, "Racing.BestLap")
	if racer.BestLap > 0 and (bestLap == 0 or racer.BestLap < bestLap) then
		DataService:Set(player, "Racing.BestLap", racer.BestLap)
	end
end

local function updateRacer(racer: Racer, now: number)
	if racer.FinishTime then
		return
	end
	local count = #checkpoints
	local target = checkpoints[racer.Next]
	if not target or not isInside(target, racer.Chassis.Position) then
		return
	end

	-- Plausibilität: So schnell kann man die Strecke seit dem letzten Checkpoint nicht fahren.
	local previous = checkpoints[if racer.Next == 1 then count else racer.Next - 1]
	local distance = (target.Position - previous.Position).Magnitude
	local minimumTime = distance / (Config.Car.MaxSpeed * SPEED_TOLERANCE)
	if now - racer.LastCheckpointAt < minimumTime then
		return
	end
	racer.LastCheckpointAt = now

	if racer.Next == count then
		local lapTime = now - racer.LapStartedAt
		if racer.BestLap == 0 or lapTime < racer.BestLap then
			racer.BestLap = lapTime
		end
		racer.LapStartedAt = now
		if racer.Lap >= Config.Race.Laps then
			finish(racer, now)
			return
		end
		racer.Lap += 1
		racer.Next = 1
	else
		racer.Next += 1
	end
	racer.Player:SetAttribute("RaceLap", racer.Lap)
	racer.Player:SetAttribute("RaceCheckpoint", racer.Next)
end

-- Fortschritt als eine Zahl: Runden, Checkpoints und Nähe zum nächsten Checkpoint.
local function progress(racer: Racer): number
	local count = #checkpoints
	local target = checkpoints[racer.Next]
	local closeness = if target then 1 / (1 + (target.Position - racer.Chassis.Position).Magnitude) else 0
	return (racer.Lap - 1) * count + (racer.Next - 1) + closeness
end

local function ranking(): { Racer }
	local list: { Racer } = {}
	for _, racer in racers do
		table.insert(list, racer)
	end
	table.sort(list, function(a, b)
		if a.FinishTime and b.FinishTime then
			return a.FinishTime < b.FinishTime
		elseif a.FinishTime or b.FinishTime then
			return a.FinishTime ~= nil
		end
		return progress(a) > progress(b)
	end)
	return list
end

------------------------------------------------------------------------------
-- Ablauf
------------------------------------------------------------------------------

local function setPhase(phase: string, duration: number?)
	Workspace:SetAttribute("RacePhase", phase)
	Workspace:SetAttribute("RaceEndsAt", if duration then Workspace:GetServerTimeNow() + duration else 0)
end

local function waitPhase(seconds: number, stop: (() -> boolean)?)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if skipPhase or (stop and stop()) then
			break
		end
		task.wait(0.1)
	end
	skipPhase = false
end

local function runRace()
	loadCheckpoints()
	local grids: { BasePart } = {}
	for _, instance in World.Tagged("StartGrid") do
		if instance:IsA("BasePart") then
			table.insert(grids, instance)
		end
	end
	if #checkpoints < 2 or #grids == 0 then
		return
	end

	-- Startplätze mischen, damit nicht immer derselbe vorn steht.
	for index = #grids, 2, -1 do
		local other = random:NextInteger(1, index)
		grids[index], grids[other] = grids[other], grids[index]
	end

	for index, player in Players:GetPlayers() do
		local grid = grids[index]
		if not grid then
			break -- mehr Spieler als Startplätze: der Rest schaut zu
		end
		local car, chassis = createCar(player, grid)
		if car and chassis then
			racers[player] = {
				Player = player,
				Car = car,
				Chassis = chassis,
				Next = 1,
				Lap = 1,
				LastCheckpointAt = 0,
				LapStartedAt = 0,
				BestLap = 0,
				FinishTime = nil,
			}
			player:SetAttribute("RaceLap", 1)
			player:SetAttribute("RaceCheckpoint", 1)
		end
	end
	if next(racers) == nil then
		return
	end

	setPhase("Countdown", Config.Race.Countdown)
	task.wait(Config.Race.Countdown)

	raceStart = os.clock()
	for player, racer in racers do
		racer.LapStartedAt = raceStart
		racer.Chassis.Anchored = false
		-- Erst nach dem Lösen übergeben: Verankerte Teile haben keinen Netzwerk-Besitzer.
		racer.Chassis:SetNetworkOwner(player)
	end
	setPhase("Racing", Config.Race.MaxDuration)

	local firstFinishAt: number? = nil
	waitPhase(Config.Race.MaxDuration, function()
		local now = os.clock()
		local allDone = true
		for _, racer in racers do
			updateRacer(racer, now)
			if racer.FinishTime then
				firstFinishAt = firstFinishAt or now
			else
				allDone = false
			end
		end
		for position, racer in ranking() do
			racer.Player:SetAttribute("RacePosition", position)
		end
		return allDone or (firstFinishAt ~= nil and now - firstFinishAt > Config.Race.FinishTimeout)
	end)

	local results = {}
	for position, racer in ranking() do
		table.insert(results, { Name = racer.Player.DisplayName, Time = racer.FinishTime, BestLap = racer.BestLap })
		if position == 1 and racer.FinishTime then
			DataService:Increment(racer.Player, "Racing.Wins", 1)
		end
	end
	Net.FireAll("Race.Results", results)
	setPhase("Results", Config.Race.ResultTime)
	waitPhase(Config.Race.ResultTime)

	for player in table.clone(racers) do
		removeRacer(player)
	end
end

local function loop()
	while true do
		if #Players:GetPlayers() < Config.Race.MinPlayers then
			setPhase("Waiting")
			task.wait(1)
			continue
		end
		setPhase("Intermission", Config.Race.Intermission)
		waitPhase(Config.Race.Intermission)
		runRace()
	end
end

------------------------------------------------------------------------------

function RaceService:SkipPhase()
	skipPhase = true
end

-- Stellt das Auto eines Spielers aufrecht auf den zuletzt durchfahrenen Checkpoint.
function RaceService:ResetCar(player: Player)
	local racer = racers[player]
	if not racer or racer.FinishTime then
		return
	end
	local count = #checkpoints
	local last = checkpoints[if racer.Next == 1 then count else racer.Next - 1]
	local nextOne = checkpoints[racer.Next]
	if last and nextOne then
		local position = last.Position + Vector3.new(0, Config.Car.SuspensionLength, 0)
		racer.Chassis.AssemblyLinearVelocity = Vector3.zero
		racer.Chassis.AssemblyAngularVelocity = Vector3.zero
		racer.Car:PivotTo(CFrame.lookAt(position, Vector3.new(nextOne.Position.X, position.Y, nextOne.Position.Z)))
	end
end

function RaceService:Init()
	Net.Declare("Race.Results")
	Net.On("Race.ResetCar", {}, function(player: Player)
		RaceService:ResetCar(player)
	end, { Rate = 0.5, Burst = 1 })
end

function RaceService:Start()
	World.Expect("Rennen", {
		{
			Tag = "StartGrid",
			Class = "BasePart",
			Hint = "Startplätze mit Tag StartGrid setzen (Vorderseite in Fahrtrichtung).",
		},
		{ Tag = "RaceCheckpoint", Min = 2, Class = "BasePart", Attributes = { Order = "number" } },
	})
	Players.PlayerRemoving:Connect(removeRacer)
	task.spawn(loop)
end

return RaceService
