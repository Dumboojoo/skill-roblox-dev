--!strict
--[[
	HorrorController – Taschenlampe, Sprint mit Ausdauer, Ziel-Anzeige, Notizen und
	die Gefahren-Anzeige (pulsierender Bildrand, wenn der Verfolger nah ist).

	Stimmung entsteht vor allem in Studio (Lighting: dunkel, Nebel, wenig Farbe)
	und durch Ton. Für Geräusche unten bei SOUNDS Asset-IDs eintragen.

	Steuerung
	  F / Y (Controller) / Touch-Knopf       Taschenlampe
	  Shift / L3 / Touch-Knopf (halten)      sprinten
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Horror)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

local SOUNDS = {
	FlashlightClick = "",
	Caught = "",
}

local HorrorController = {}

local player = Players.LocalPlayer

local flashlightOn = false
local battery = 1 -- 0 bis 1
local lightPart: Part? = nil
local light: SpotLight? = nil

local sprinting = false
local stamina = 1 -- 0 bis 1

local objectiveLabel: TextLabel
local batteryFill: Frame
local staminaFill: Frame
local vignette: Frame
local noteWindow: Frame
local noteLabel: TextLabel
local caughtOverlay: Frame

local function playSound(id: string)
	SoundController:Play(id) -- beachtet die Lautstärke aus den Einstellungen; leere Id bleibt still
end

------------------------------------------------------------------------------
-- Taschenlampe
------------------------------------------------------------------------------

local function ensureLight()
	if lightPart and lightPart.Parent then
		return
	end
	-- Unsichtbares Teil, das jeden Frame an die Kamera gesetzt wird und das Licht trägt.
	local part = Instance.new("Part")
	part.Name = "Flashlight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = Config.Flashlight.Range
	spot.Angle = Config.Flashlight.Angle
	spot.Brightness = Config.Flashlight.Brightness
	spot.Shadows = true
	spot.Enabled = false
	spot.Parent = part
	part.Parent = Workspace.CurrentCamera
	lightPart, light = part, spot
end

local function setFlashlight(state: boolean)
	flashlightOn = state and battery > 0
	playSound(SOUNDS.FlashlightClick)
end

------------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------------

local function bar(parent: Instance, position: UDim2, color: Color3): Frame
	local back = Kit.Create("Frame", {
		Position = position,
		Size = UDim2.fromOffset(160, 8),
		BackgroundColor3 = Kit.Theme.Background,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = parent,
	}, Kit.Corner(4))
	return Kit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	}, Kit.Corner(4))
end

local function build()
	local gui = Kit.ScreenGui("HorrorHud", 5)
	gui.IgnoreGuiInset = true

	-- Bildrand: ein Rahmen aus einem dicken, nach innen weichen Strich.
	vignette = Kit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Kit.Create("UIStroke", {
		Name = "Edge",
		Thickness = 90,
		Color = Color3.fromRGB(120, 0, 0),
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = vignette,
	})

	objectiveLabel = Kit.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(600, 30),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	Kit.Create("UIStroke", { Thickness = 2, Color = Kit.Theme.Background, Parent = objectiveLabel })

	batteryFill = bar(gui, UDim2.new(0, 20, 1, -40), Kit.Theme.Warn)
	staminaFill = bar(gui, UDim2.new(0, 20, 1, -24), Kit.Theme.Accent)

	noteWindow = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 320),
		BackgroundColor3 = Color3.fromRGB(226, 214, 186),
		Visible = false,
		Parent = gui,
	})
	noteLabel = Kit.Label({
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.new(1, -40, 1, -90),
		TextColor3 = Color3.fromRGB(40, 32, 24),
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = noteWindow,
	})
	Kit.Button({
		Text = "Schließen",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(160, 44),
		BackgroundColor3 = Color3.fromRGB(90, 70, 50),
		Parent = noteWindow,
	}, function()
		noteWindow.Visible = false
	end)

	caughtOverlay = Kit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
end

local function refreshObjective()
	local text = Workspace:GetAttribute("StoryText")
	local index = Workspace:GetAttribute("StoryIndex")
	local total = Workspace:GetAttribute("StoryTotal")
	if type(text) == "string" and type(index) == "number" and type(total) == "number" then
		objectiveLabel.Text = if index <= total then `Ziel {index}/{total}: {text}` else text
		Kit.Pop(objectiveLabel, 0.08)
	end
end

------------------------------------------------------------------------------
-- Jeden Frame
------------------------------------------------------------------------------

local function update(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil

	-- Taschenlampe: Batterie leert sich an, lädt langsam aus.
	local flashlight = Config.Flashlight
	if flashlightOn then
		battery = math.max(0, battery - deltaTime / flashlight.BatterySeconds)
		if battery == 0 then
			flashlightOn = false
		end
	else
		battery = math.min(1, battery + deltaTime / flashlight.BatterySeconds * flashlight.RechargePerSecond)
	end
	ensureLight()
	if light and lightPart and camera then
		lightPart.CFrame = camera.CFrame
		-- Flackern kurz vor leer: warnt, ohne eine Meldung zu brauchen.
		local flicker = battery < 0.12 and math.random() < 0.15
		light.Enabled = flashlightOn and not flicker
	end
	batteryFill.Size = UDim2.fromScale(battery, 1)

	-- Sprint: nur mit Ausdauer und nur in Bewegung.
	local sprint = Config.Sprint
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
	local canSprint = sprinting and moving and stamina > 0
	if canSprint then
		stamina = math.max(0, stamina - deltaTime / sprint.StaminaSeconds)
	else
		stamina = math.min(1, stamina + deltaTime / sprint.StaminaSeconds * sprint.RecoverPerSecond)
	end
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = if canSprint then sprint.Speed else sprint.WalkSpeed
	end
	staminaFill.Size = UDim2.fromScale(stamina, 1)

	-- Gefahr: je näher der Verfolger, desto stärker und schneller pulsiert der Rand.
	local danger = 0
	if root and root:IsA("BasePart") then
		for _, chaser in World.Tagged("Chaser") do
			if chaser:IsA("Model") then
				local distance = (chaser:GetPivot().Position - root.Position).Magnitude
				danger = math.max(danger, 1 - math.clamp(distance / Config.DangerDistance, 0, 1))
			end
		end
	end
	local edge = vignette:FindFirstChild("Edge")
	if edge and edge:IsA("UIStroke") then
		local pulse = (math.sin(os.clock() * (3 + danger * 9)) + 1) / 2
		edge.Transparency = 1 - danger * (0.35 + 0.4 * pulse)
	end
end

------------------------------------------------------------------------------

function HorrorController:Init()
	build()
	Net.Listen("Horror.Note", function(text: string)
		noteLabel.Text = text
		noteWindow.Visible = true
	end)
	Net.Listen("Horror.Caught", function()
		playSound(SOUNDS.Caught)
		if Config.FlashOnCaught then
			caughtOverlay.BackgroundColor3 = Color3.fromRGB(140, 0, 0)
			caughtOverlay.BackgroundTransparency = 0.2
		else
			caughtOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
			caughtOverlay.BackgroundTransparency = 0.4
		end
		Kit.Tween(caughtOverlay, 1.5, { BackgroundTransparency = 1 })
	end)
end

function HorrorController:Start()
	refreshObjective()
	Workspace:GetAttributeChangedSignal("StoryText"):Connect(refreshObjective)

	ContextActionService:BindAction("HorrorFlashlight", function(_name, state)
		if state == Enum.UserInputState.Begin then
			setFlashlight(not flashlightOn)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("HorrorFlashlight", "Licht")
	ContextActionService:SetPosition("HorrorFlashlight", UDim2.new(1, -150, 1, -130))

	ContextActionService:BindAction("HorrorSprint", function(_name, state)
		sprinting = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("HorrorSprint", "Rennen")
	ContextActionService:SetPosition("HorrorSprint", UDim2.new(1, -230, 1, -90))

	RunService.RenderStepped:Connect(update)
end

return HorrorController
