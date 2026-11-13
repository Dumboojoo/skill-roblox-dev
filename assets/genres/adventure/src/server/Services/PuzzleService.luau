--!strict
--[[
	PuzzleService – der Rätsel-Baukasten: Schalter (Activator) und Empfänger
	(Receiver), verbunden über einen Kanal-Namen.

	Jeder Kanal zählt, wie viele seiner Schalter gerade "an" sind. Jeder Empfänger
	des Kanals reagiert, sobald genug an sind (Attribut Needs, sonst alle).
	Der Zustand gilt für alle Spieler gemeinsam, so entstehen Koop-Rätsel von
	selbst (einer steht auf der Platte, der andere geht durchs Tor).

	Alles wird in Studio über Tags und Attribute verdrahtet, ohne Code. Welche es
	gibt, steht in Config/Adventure.

	Erweitern:
	  neuer Schalter   -> Fall in `observeActivator` (ruft setActive auf)
	  neue Reaktion    -> Fall in `applyReceiver`
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)

type Receiver = { Part: BasePart, Action: string, Origin: CFrame, Transparency: number, On: boolean }
type Channel = { Activators: { [BasePart]: boolean }, Receivers: { Receiver } }

local PLATE_CHECK_INTERVAL = 0.15
local MOVE_TIME = 0.8

local PuzzleService = {
	ChannelChanged = Signal.new() :: Signal.Signal<string, number>, -- (Kanal, Anzahl aktiver Schalter)
}

local channels: { [string]: Channel } = {}
local plates: { [BasePart]: string } = {}

local function channel(name: string): Channel
	local existing = channels[name]
	if not existing then
		existing = { Activators = {}, Receivers = {} }
		channels[name] = existing
	end
	return existing
end

local function applyReceiver(receiver: Receiver, on: boolean)
	if receiver.On == on then
		return
	end
	receiver.On = on
	local part = receiver.Part
	local info = TweenInfo.new(MOVE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if receiver.Action == "Open" then
		local goal = if on then receiver.Origin + Vector3.new(0, part.Size.Y * 0.95, 0) else receiver.Origin
		TweenService:Create(part, info, { CFrame = goal }):Play()
	else
		-- "Appear": an = sichtbar und fest. "Disappear": genau umgekehrt.
		local present = if receiver.Action == "Appear" then on else not on
		part.CanCollide = present
		TweenService:Create(part, info, { Transparency = if present then receiver.Transparency else 1 }):Play()
	end
end

local function evaluate(name: string)
	local data = channel(name)
	local total, active = 0, 0
	for _, isActive in data.Activators do
		total += 1
		if isActive then
			active += 1
		end
	end
	for _, receiver in data.Receivers do
		local needs = World.Attribute(receiver.Part, "Needs", total)
		applyReceiver(receiver, total > 0 and active >= needs)
	end
	PuzzleService.ChannelChanged:Fire(name, active)
end

local function setActive(name: string, part: BasePart, active: boolean)
	local data = channel(name)
	if data.Activators[part] ~= active then
		data.Activators[part] = active
		-- Sichtbare Rückmeldung am Schalter selbst.
		part.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
		evaluate(name)
	end
end

local function observeActivator(instance: Instance): (() -> ())?
	local name = instance:GetAttribute("Channel")
	if not instance:IsA("BasePart") or type(name) ~= "string" then
		warn(`[Rätsel] Activator {instance:GetFullName()} braucht das Attribut Channel.`)
		return nil
	end
	local kind = World.Attribute(instance, "Kind", "Lever")
	channel(name).Activators[instance] = false

	local prompt: ProximityPrompt? = nil
	if kind == "Plate" then
		plates[instance] = name
	else
		local created = Instance.new("ProximityPrompt")
		created.ActionText = if kind == "Button" then "Drücken" else "Umlegen"
		created.MaxActivationDistance = 9
		created.Parent = instance
		created.Triggered:Connect(function()
			if kind == "Button" then
				setActive(name, instance, true)
				created.Enabled = false
			else
				setActive(name, instance, not channel(name).Activators[instance])
			end
		end)
		prompt = created
	end
	evaluate(name)

	return function()
		plates[instance] = nil
		channel(name).Activators[instance] = nil
		if prompt then
			prompt:Destroy()
		end
		evaluate(name)
	end
end

local function observeReceiver(instance: Instance): (() -> ())?
	local name = instance:GetAttribute("Channel")
	if not instance:IsA("BasePart") or type(name) ~= "string" then
		warn(`[Rätsel] Receiver {instance:GetFullName()} braucht das Attribut Channel.`)
		return nil
	end
	local action = World.Attribute(instance, "Action", "Open")
	local receiver: Receiver = {
		Part = instance,
		Action = action,
		Origin = instance.CFrame,
		Transparency = instance.Transparency,
		On = false,
	}
	-- Ausgangslage: Eine Brücke ("Appear") ist zunächst weg.
	if action == "Appear" then
		instance.Transparency = 1
		instance.CanCollide = false
	end
	table.insert(channel(name).Receivers, receiver)
	evaluate(name)

	return function()
		local list = channel(name).Receivers
		local index = table.find(list, receiver)
		if index then
			table.remove(list, index)
		end
	end
end

-- Setzt einen Kanal zurück (z. B. wenn ein Level neu begonnen wird).
function PuzzleService:ResetChannel(name: string)
	local data = channels[name]
	if not data then
		return
	end
	for part in data.Activators do
		data.Activators[part] = false
		part.Material = Enum.Material.SmoothPlastic
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
	evaluate(name)
end

function PuzzleService:Start()
	World.Observe("Receiver", observeReceiver)
	World.Observe("Activator", observeActivator)

	-- Druckplatten: regelmäßig prüfen, ob ein Charakter darauf steht.
	-- (Zuverlässiger als Touched/TouchEnded, die bei stehenden Figuren flackern.)
	task.spawn(function()
		local params = OverlapParams.new()
		while true do
			for plate, name in plates do
				local pressed = false
				local box = plate.CFrame * CFrame.new(0, plate.Size.Y / 2 + 1.5, 0)
				for _, part in Workspace:GetPartBoundsInBox(box, Vector3.new(plate.Size.X, 3, plate.Size.Z), params) do
					local model = part:FindFirstAncestorOfClass("Model")
					if model and model:FindFirstChildOfClass("Humanoid") then
						pressed = true
						break
					end
				end
				setActive(name, plate, pressed)
			end
			task.wait(PLATE_CHECK_INTERVAL)
		end
	end)
end

return PuzzleService
