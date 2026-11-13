--!strict
--[[
	ObbyController – bewegte Hindernisse und die Obby-Anzeige.

	Hindernisse laufen hier auf dem Client, damit sie flüssig sind. Ihr Takt kommt
	aus der Serverzeit (Workspace:GetServerTimeNow), also sehen alle Spieler die
	Plattform an derselben Stelle.

	Der Trick, damit man auf bewegten Plattformen mitfährt: Ein verankertes Teil
	wird per CFrame versetzt UND bekommt die passende Geschwindigkeit
	(AssemblyLinearVelocity / AssemblyAngularVelocity). Die Physik schiebt den
	Charakter dann mit, als würde sich das Teil wirklich bewegen.

	Neues Hindernis: neuen Tag ausdenken, hier einen World.Observe-Block ergänzen,
	Tag und Attribute in Config/Obby dokumentieren.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Obby)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

type Mover = (now: number) -> ()

local ObbyController = {}

local player = Players.LocalPlayer
local movers: { [Instance]: Mover } = {}
local runStartedAt: number? = nil

local stageLabel: TextLabel
local timeLabel: TextLabel

local function isLocalCharacter(hit: BasePart): boolean
	local character = player.Character
	return character ~= nil and hit:IsDescendantOf(character)
end

------------------------------------------------------------------------------
-- Hindernisse
------------------------------------------------------------------------------

local function observeSpinner(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local origin = instance.CFrame
	local speed = math.rad(World.Attribute(instance, "Speed", Config.Defaults.SpinnerSpeed))
	local axisName = World.Attribute(instance, "Axis", "Y")
	local axis = if axisName == "X" then Vector3.xAxis elseif axisName == "Z" then Vector3.zAxis else Vector3.yAxis

	movers[instance] = function(now: number)
		instance.CFrame = origin * CFrame.fromAxisAngle(axis, (now * speed) % (math.pi * 2))
		instance.AssemblyAngularVelocity = origin:VectorToWorldSpace(axis) * speed
	end
	return function()
		movers[instance] = nil
	end
end

local function observeMovingPlatform(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local origin = instance.CFrame
	local offset = World.Attribute(instance, "Offset", Vector3.new(0, 0, 20))
	local duration = math.max(World.Attribute(instance, "Time", Config.Defaults.MovingTime), 0.1)

	movers[instance] = function(now: number)
		-- Weiches Hin und Her: Kosinus von 0 bis 1 und zurück.
		local phase = now * math.pi / duration
		local alpha = (1 - math.cos(phase)) / 2
		instance.CFrame = origin + offset * alpha
		instance.AssemblyLinearVelocity = offset * (math.sin(phase) * math.pi / (2 * duration))
	end
	return function()
		movers[instance] = nil
	end
end

local function observeFadingPlatform(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local delay = World.Attribute(instance, "Delay", Config.Defaults.FadeDelay)
	local respawn = World.Attribute(instance, "Respawn", Config.Defaults.FadeRespawn)
	local originalTransparency = instance.Transparency
	local busy = false

	local connection = instance.Touched:Connect(function(hit)
		if busy or not isLocalCharacter(hit) then
			return
		end
		busy = true
		-- Nur lokal: Jeder Spieler hat „seine" Plattform, niemand reißt sie anderen weg.
		Kit.Tween(instance, delay, { Transparency = 0.8 })
		task.wait(delay)
		instance.Transparency = 1
		instance.CanCollide = false
		task.wait(respawn)
		instance.CanCollide = true
		Kit.Tween(instance, 0.2, { Transparency = originalTransparency })
		busy = false
	end)
	return function()
		connection:Disconnect()
	end
end

local function observeJumpPad(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local power = World.Attribute(instance, "Power", Config.Defaults.JumpPower)
	local lastBounce = 0

	local connection = instance.Touched:Connect(function(hit)
		if not isLocalCharacter(hit) or os.clock() - lastBounce < 0.3 then
			return
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			lastBounce = os.clock()
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, velocity.Z)
		end
	end)
	return function()
		connection:Disconnect()
	end
end

------------------------------------------------------------------------------
-- Anzeige
------------------------------------------------------------------------------

local function buildHud()
	local gui = Kit.ScreenGui("ObbyHud", 5)
	local panel = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 44),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	stageLabel = Kit.Label({
		Size = UDim2.new(0.5, -12, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		FontFace = Kit.Theme.FontBold,
		TextSize = 18,
		Parent = panel,
	})
	timeLabel = Kit.Label({
		Size = UDim2.new(0.5, -12, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		FontFace = Kit.Theme.FontMono,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})

	Kit.Button({
		Text = "Neustart",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(120, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, function()
		Net.Send("Obby.Restart")
	end)
end

local function updateStage(stage: any)
	local last = Workspace:GetAttribute("ObbyLastStage")
	local total = if type(last) == "number" then tostring(last) else "?"
	stageLabel.Text = `Stufe {if type(stage) == "number" then stage else 0} / {total}`
end

------------------------------------------------------------------------------

function ObbyController:Init()
	buildHud()

	Net.Listen("Obby.Checkpoint", function(stage: number)
		NotificationController:Notify(`Checkpoint {stage} erreicht`, "Success", 1.5)
		Kit.Pop(stageLabel)
	end)
	Net.Listen("Obby.RunStarted", function()
		runStartedAt = os.clock()
	end)
	Net.Listen("Obby.Finished", function(elapsed: number?)
		runStartedAt = nil
		if elapsed then
			timeLabel.Text = Format.TimeMs(elapsed)
			NotificationController:Notify(`Geschafft in {Format.TimeMs(elapsed)}!`, "Announcement")
		else
			NotificationController:Notify(
				"Geschafft! Für eine Bestzeit mit Neustart ab Stufe 0 laufen.",
				"Announcement"
			)
		end
	end)
end

function ObbyController:Start()
	World.Observe("Spinner", observeSpinner)
	World.Observe("MovingPlatform", observeMovingPlatform)
	World.Observe("FadingPlatform", observeFadingPlatform)
	World.Observe("JumpPad", observeJumpPad)

	DataController:Observe("Obby.Stage", updateStage)
	Workspace:GetAttributeChangedSignal("ObbyLastStage"):Connect(function()
		updateStage(DataController:Get("Obby.Stage"))
	end)

	-- Wer bei Stufe 0 einsteigt, läuft bereits auf Zeit (der Server misst ab dem Laden).
	task.spawn(function()
		local data = DataController:WaitForData()
		if data.Obby.Stage == 0 then
			runStartedAt = os.clock()
		end
	end)

	-- Vor der Physik, damit der Charakter die neue Plattform-Position im selben Schritt bekommt.
	RunService.PreSimulation:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for _, mover in movers do
			mover(now)
		end
		local started = runStartedAt
		if started then
			timeLabel.Text = Format.TimeMs(os.clock() - started)
		end
	end)
end

return ObbyController
