--!strict
--[[
	RigAnimationController – bewegt Figuren aus Einzelteilen, ganz ohne Animationsdatei.

	Jedes Model mit dem Tag "AnimatedRig" wird bewegt: Beine und Arme schwingen beim
	Laufen, der Rumpf wippt, der Schwanz wedelt, Flügel schlagen, das Maul geht auf.
	Die Rechnung dazu steht in shared/Util/RigMotion (getestet).

	Voraussetzung: Die Teile sind über Motor6D verbunden und tragen sprechende Namen
	(Torso, Head, Jaw, LeftUpperArm, LeftLowerLeg, Tail1, LeftWing …). Genau so baut
	sie assets/weltbau/rig_bauen.luau aus einem Blender-Modell.

	Attribute am Model (alle freiwillig, jederzeit änderbar, auch vom Server):
	  Gait      "Zweibeiner" | "Vierbeiner" | "Schweben"  (ohne Angabe: aus den Teilen erraten)
	  Tempo     Zahl, 1 = normal; größer = schnellere Schritte
	  Strength  Zahl, 1 = normal; größer = ausladender, 0 = starr
	  JawOpen   0 bis 1: Maul offen (z. B. der Server setzt 1 beim Angriff und danach wieder 0)

	Läuft nur auf dem Client und nur für Figuren in der Nähe der Kamera: Der Server rechnet
	nichts, und es wird nichts übertragen. Ob die Figur läuft, erkennt der Controller daran,
	wie weit sie sich seit dem letzten Bild bewegt hat (klappt mit Humanoid, mit Physik
	und mit verankerten Figuren, die per Code verschoben werden).

	Wer eine Figur lieber von Hand animiert (Animations-Editor in Studio): Tag weglassen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local RigMotion = require(Shared.Util.RigMotion)
local World = require(Shared.Util.World)

local TAG = "AnimatedRig"
local MAX_DISTANCE = 140 -- weiter entfernte Figuren stehen starr (Studs)
local FULL_SPEED = 3 -- ab dieser Geschwindigkeit (Studs/s) schwingen die Glieder voll aus
local BLEND_RATE = 8 -- wie schnell zwischen Stehen und Laufen überblendet wird
local TELEPORT_DISTANCE = 25 -- größere Sprünge in einem Bild zählen nicht als Laufen

type Rig = {
	Model: Model,
	Motors: { [string]: Motor6D },
	Kinds: { [string]: RigMotion.Kind },
	Guessed: string,
	Height: number,
	Phase: number,
	Move: number,
	Jaw: number,
	LastPosition: Vector3?,
	Dirty: boolean,
	Resting: boolean,
}

local RigAnimationController = {
	Priority = 60,
}

local rigs: { [Model]: Rig } = {}

local function rootPart(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local found = model:FindFirstChild("HumanoidRootPart")
	return if found and found:IsA("BasePart") then found else nil
end

-- Liest die Gelenke neu ein (beim Start und wenn Teile nachgeladen werden).
local function collect(rig: Rig)
	rig.Dirty = false
	local motors: { [string]: Motor6D } = {}
	local names: { string } = {}
	local root = rootPart(rig.Model)
	local bodyName: string? = nil
	for _, descendant in rig.Model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 then
			local name = descendant.Part1.Name
			if not motors[name] then
				motors[name] = descendant
				table.insert(names, name)
			end
			if root and descendant.Part0 == root then
				bodyName = name -- das Teil, das an der unsichtbaren Mitte hängt, ist der Rumpf
			end
		end
	end
	rig.Motors = motors
	rig.Kinds = RigMotion.Classify(names, bodyName)
	rig.Guessed = RigMotion.GuessGait(rig.Kinds)
	rig.Height = math.max(rig.Model:GetExtentsSize().Y, 0.5)
end

local function rest(rig: Rig)
	if rig.Resting then
		return
	end
	rig.Resting = true
	for _, motor in rig.Motors do
		motor.Transform = CFrame.identity
	end
end

local function numberAttribute(model: Model, name: string, default: number): number
	local value = model:GetAttribute(name)
	return if type(value) == "number" then value else default
end

local function update(rig: Rig, deltaTime: number, cameraPosition: Vector3)
	local model = rig.Model
	local root = rootPart(model)
	if not root then
		return
	end
	if rig.Dirty then
		collect(rig)
	end

	local position = root.Position
	if (position - cameraPosition).Magnitude > MAX_DISTANCE then
		rig.LastPosition = position
		rest(rig)
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return -- tot: in der letzten Haltung bleiben
	end

	-- Zurückgelegte Strecke seit dem letzten Bild (nur waagerecht).
	local last = rig.LastPosition or position
	rig.LastPosition = position
	local step = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
	if step > TELEPORT_DISTANCE then
		step = 0
	end
	local speed = if deltaTime > 0 then step / deltaTime else 0
	local target = math.clamp(speed / FULL_SPEED, 0, 1)
	local blend = 1 - math.exp(-BLEND_RATE * deltaTime)
	rig.Move += (target - rig.Move) * blend
	rig.Jaw += (math.clamp(numberAttribute(model, "JawOpen", 0), 0, 1) - rig.Jaw) * blend

	local tempo = numberAttribute(model, "Tempo", 1)
	rig.Phase = (rig.Phase + RigMotion.Advance(step, rig.Height, tempo)) % (2 * math.pi)

	local gait = model:GetAttribute("Gait")
	local pose = RigMotion.Sample(rig.Kinds, {
		Gait = if type(gait) == "string" and gait ~= "" then gait else rig.Guessed,
		Phase = rig.Phase,
		Move = rig.Move,
		Clock = os.clock() * tempo,
		Strength = numberAttribute(model, "Strength", 1),
		Height = rig.Height,
		JawOpen = rig.Jaw,
	})

	rig.Resting = false
	for name, values in pose do
		local motor = rig.Motors[name]
		if motor then
			motor.Transform = CFrame.new(0, values[4], 0) * CFrame.Angles(values[1], values[2], values[3])
		end
	end
end

function RigAnimationController:Init()
	World.Observe(TAG, function(instance: Instance)
		if not instance:IsA("Model") then
			if RunService:IsStudio() then
				warn(`[Figur] Tag "{TAG}" gehört an ein Model, nicht an {instance:GetFullName()}.`)
			end
			return nil
		end
		local rig: Rig = {
			Model = instance,
			Motors = {},
			Kinds = {},
			Guessed = "Zweibeiner",
			Height = 5,
			Phase = 0,
			Move = 0,
			Jaw = 0,
			LastPosition = nil,
			Dirty = true,
			Resting = false,
		}
		rigs[instance] = rig
		-- Teile können später nachgeladen werden (Streaming): dann Gelenke neu einlesen.
		local added = instance.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("Motor6D") or descendant:IsA("BasePart") then
				rig.Dirty = true
			end
		end)
		local removing = instance.DescendantRemoving:Connect(function(descendant: Instance)
			if descendant:IsA("Motor6D") then
				rig.Dirty = true
			end
		end)
		return function()
			added:Disconnect()
			removing:Disconnect()
			rigs[instance] = nil
		end
	end)
end

function RigAnimationController:Start()
	-- PreSimulation läuft nach den Roblox-Animationen: Eine von Hand abgespielte Animation
	-- wird für Figuren mit dem Tag also überschrieben. Deshalb: entweder Tag oder eigene Animation.
	RunService.PreSimulation:Connect(function(deltaTime: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		for _, rig in rigs do
			update(rig, deltaTime, cameraPosition)
		end
	end)
end

return RigAnimationController
