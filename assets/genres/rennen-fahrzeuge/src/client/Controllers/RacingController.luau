--!strict
--[[
	RacingController – Fahrphysik des eigenen Autos und die Renn-Anzeige.

	Fahrphysik (Arcade, ohne echte Räder), jeden Physikschritt:
	  1. Federung   Vier Strahlen nach unten an den Ecken. Je stärker eine "Feder"
	                eingedrückt ist, desto mehr drückt sie den Wagen dort hoch.
	                Das hält ihn in der Schwebe und richtet ihn am Boden aus.
	  2. Antrieb    Geschwindigkeit entlang der Fahrzeugnase wird Richtung
	                Wunschtempo verändert (Gas, Bremse, Ausrollen).
	  3. Haftung    Seitliches Rutschen wird abgebaut. Wenig Grip = Driften.
	  4. Lenkung    Drehgeschwindigkeit um die Hochachse wird direkt gesetzt,
	                abhängig vom Tempo (im Stand dreht der Wagen nicht).

	Gas und Lenkung kommen vom VehicleSeat (ThrottleFloat / SteerFloat). Dadurch
	funktionieren Tastatur, Touch und Controller ohne eigenen Eingabe-Code.

	Abstimmen: Werte in Config/Racing.luau. Schaukelt der Wagen: Damping hoch.
	Liegt er zu tief: Stiffness hoch. Untersteuert er: Grip oder TurnRate hoch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Racing)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

local RacingController = {}

local player = Players.LocalPlayer
local settings = Config.Car

local speedLabel: TextLabel
local infoLabel: TextLabel
local centerLabel: TextLabel
local resultsPanel: Frame
local resetButton: TextButton
local racingSince: number? = nil

------------------------------------------------------------------------------
-- Fahrphysik
------------------------------------------------------------------------------

local function findOwnCar(): (BasePart?, VehicleSeat?)
	for _, car in World.Tagged("RaceCar") do
		if car:IsA("Model") and car:GetAttribute("OwnerId") == player.UserId then
			local chassis = car.PrimaryPart
			local seat = car:FindFirstChildOfClass("VehicleSeat")
			if chassis and seat then
				return chassis, seat
			end
		end
	end
	return nil, nil
end

local function simulate(chassis: BasePart, seat: VehicleSeat, deltaTime: number)
	if chassis.Anchored then
		return
	end
	local frame = chassis.CFrame
	local up = frame.UpVector
	local look = frame.LookVector
	local right = frame.RightVector
	local mass = chassis.AssemblyMass

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { chassis.Parent :: Instance, player.Character :: Instance }

	-- 1. Federung an den vier Ecken.
	local halfX = settings.Size.X / 2 - 0.3
	local halfZ = settings.Size.Z / 2 - 0.8
	local grounded = 0
	for _, corner in
		{
			Vector3.new(halfX, 0, halfZ),
			Vector3.new(-halfX, 0, halfZ),
			Vector3.new(halfX, 0, -halfZ),
			Vector3.new(-halfX, 0, -halfZ),
		}
	do
		local origin = frame:PointToWorldSpace(corner)
		local result = Workspace:Raycast(origin, -up * settings.SuspensionLength, params)
		if result then
			grounded += 1
			local compression = settings.SuspensionLength - result.Distance
			local pointSpeed = chassis:GetVelocityAtPosition(origin):Dot(up)
			local strength = (compression * settings.Stiffness - pointSpeed * settings.Damping) * mass / 4
			if strength > 0 then
				chassis:ApplyImpulseAtPosition(up * strength * deltaTime, origin)
			end
		end
	end
	if grounded < 2 then
		return -- in der Luft: keine Kontrolle
	end

	local velocity = chassis.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(look)
	local sideSpeed = velocity:Dot(right)
	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat

	-- 2. Antrieb.
	local change
	if throttle > 0.05 then
		change = if forwardSpeed < 0 then settings.Braking else settings.Acceleration
		change = math.min(change * deltaTime, math.max(0, settings.MaxSpeed * throttle - forwardSpeed))
	elseif throttle < -0.05 then
		change = if forwardSpeed > 0 then settings.Braking else settings.Acceleration * 0.6
		change = -math.min(change * deltaTime, math.max(0, forwardSpeed + settings.ReverseSpeed))
	else
		change = -math.sign(forwardSpeed) * math.min(math.abs(forwardSpeed), settings.Coasting * deltaTime)
	end

	-- 3. Haftung: einen Teil des seitlichen Rutschens pro Schritt abbauen.
	local gripChange = -sideSpeed * math.min(1, settings.Grip * deltaTime)
	chassis.AssemblyLinearVelocity = velocity + look * change + right * gripChange

	-- 4. Lenkung: Drehung um die Hochachse; rückwärts lenkt es andersherum.
	local speedFactor = math.clamp(forwardSpeed / 25, -1, 1)
	local wantedYaw = -steer * math.rad(settings.TurnRate) * speedFactor
	local angular = chassis.AssemblyAngularVelocity
	local currentYaw = angular:Dot(up)
	chassis.AssemblyAngularVelocity = angular + up * (wantedYaw - currentYaw) * math.min(1, deltaTime * 10)
end

------------------------------------------------------------------------------
-- Anzeige
------------------------------------------------------------------------------

local function build()
	local gui = Kit.ScreenGui("RaceHud", 5)

	local panel = Kit.Panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(220, 84),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	speedLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 44),
		FontFace = Kit.Theme.FontBold,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	infoLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 26),
		TextColor3 = Kit.Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	centerLabel = Kit.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(600, 110),
		FontFace = Kit.Theme.FontBold,
		TextSize = 72,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	Kit.Create("UIStroke", { Thickness = 4, Color = Kit.Theme.Background, Parent = centerLabel })

	resetButton = Kit.Button({
		Text = "Zurücksetzen",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Visible = false,
		Parent = gui,
	}, function()
		Net.Send("Race.ResetCar")
	end)

	resultsPanel = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Kit.Padding(12).Parent = resultsPanel
	Kit.List(Enum.FillDirection.Vertical, 4).Parent = resultsPanel
end

local function showResults(results: { { Name: string, Time: number?, BestLap: number } })
	SoundController:Play("Win")
	for _, child in resultsPanel:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	Kit.Label({
		Text = "Ergebnis",
		FontFace = Kit.Theme.FontBold,
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 0,
		Parent = resultsPanel,
	})
	for position, entry in results do
		Kit.Label({
			Text = `{position}.  {entry.Name}   {if entry.Time then Format.TimeMs(entry.Time) else "nicht im Ziel"}`,
			FontFace = Kit.Theme.FontMono,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = position,
			Parent = resultsPanel,
		})
	end
	resultsPanel.Visible = true
	task.delay(Config.Race.ResultTime, function()
		resultsPanel.Visible = false
	end)
end

local function refreshHud(chassis: BasePart?)
	local phase = Workspace:GetAttribute("RacePhase")
	local endsAt = Workspace:GetAttribute("RaceEndsAt")
	local remaining = if type(endsAt) == "number" then math.max(0, endsAt - Workspace:GetServerTimeNow()) else 0

	if phase == "Countdown" then
		centerLabel.Text = tostring(math.ceil(remaining))
		racingSince = nil
	elseif phase == "Racing" then
		if not racingSince then
			racingSince = os.clock()
		end
		-- "LOS!" eine Sekunde lang stehen lassen.
		centerLabel.Text = if os.clock() - (racingSince :: number) < 1 then "LOS!" else ""
	elseif phase == "Intermission" then
		centerLabel.Text = ""
		racingSince = nil
	else
		centerLabel.Text = ""
	end

	local lap = player:GetAttribute("RaceLap")
	local position = player:GetAttribute("RacePosition")
	resetButton.Visible = chassis ~= nil and phase == "Racing"
	if chassis and type(lap) == "number" then
		speedLabel.Text = tostring(math.floor(chassis.AssemblyLinearVelocity.Magnitude))
		infoLabel.Text = `Runde {lap}/{Config.Race.Laps}   Platz {if type(position) == "number" then position else "-"}`
	else
		speedLabel.Text = ""
		infoLabel.Text = if phase == "Intermission"
			then `Rennen startet in {math.ceil(remaining)}s`
			elseif phase == "Racing" then "Rennen läuft"
			else "Warte auf Spieler …"
	end
end

------------------------------------------------------------------------------

function RacingController:Init()
	build()
	Net.Listen("Race.Results", showResults)
end

function RacingController:Start()
	-- Vor jedem Physikschritt, damit die Kräfte im selben Schritt wirken.
	local jumpLocked = false
	RunService.PreSimulation:Connect(function(deltaTime: number)
		local chassis, seat = findOwnCar()
		local driving = chassis ~= nil and seat ~= nil and seat.Occupant ~= nil
		if chassis and seat and driving then
			simulate(chassis, seat, deltaTime)
		end

		-- Im Auto ist Springen gesperrt: Die Sprungtaste würde den Fahrer sonst mitten im Rennen
		-- aus dem Sitz werfen. Ohne Auto (Lobby, Zuschauen) ist Springen wieder frei.
		if driving ~= jumpLocked then
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not driving)
				jumpLocked = driving
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		refreshHud((findOwnCar()))
	end)
end

return RacingController
