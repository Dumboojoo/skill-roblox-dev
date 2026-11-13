--!strict
--[[
	ViewmodelController – die Ego-Ansicht: Waffe und zwei gerade Block-Arme.

	Bewusst OHNE Animationen. Die Waffe wird jeden Frame relativ zur Kamera
	gesetzt, und jeder Arm ist ein gerader Block (Ärmel + Manschette + Hand), der
	von einem festen Schulterpunkt neben der Kamera zur Griffstelle der Waffe
	gespannt wird. Bewegt sich die Waffe, folgen die Arme von selbst.

	Leben kommt allein aus Mathematik:
	  Schwanken   Waffe hinkt der Mausbewegung leicht nach (Feder)
	  Laufwippen  Sinuskurve abhängig von der Laufgeschwindigkeit
	  Rückstoß    Feder-Stoß nach hinten/oben, Kamera wird kurz hochgedrückt
	  Zielen      Überblenden zwischen Hüft- und Zielposition, Sichtfeld wird enger
	  Ziehen      Waffe kommt von unten ins Bild
	  Nachladen   Waffe kippt weg, die linke Hand greift zum Magazin

	Alle Zahlen zum Abstimmen stehen oben als Konstanten bzw. in Config/Weapons.
	Neue Bewegungen (Sprinten, Landen, Inspizieren) nach demselben Muster ergänzen:
	einen Versatz berechnen und in `update` auf Position oder Drehung addieren.

	Benutzt vom WeaponController:
	  Equip(id), Unequip(), SetAiming(bool), Fire(), Reload(dauer), GetMuzzlePosition()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Spring = require(Shared.Util.Spring)
local WeaponModel = require(Shared.Shooter.WeaponModel)
local Weapons = require(Shared.Config.Weapons)

type Arm = { Sleeve: Part, Cuff: Part, Hand: Part }

-- Abstimmung -----------------------------------------------------------------
local AIM_DISTANCE = 1.0 -- wie weit das Visier beim Zielen vor der Kamera liegt
local SWAY_IMPULSE = 1.8 -- wie stark eine Drehung der Kamera die Waffe auslenkt (negativ = andere Richtung)
local SWAY_LIMIT = 7 -- größter Schwank-Winkel in Grad
local BOB_FREQUENCY = 0.55
local BOB_SIDE = 0.035
local BOB_UP = 0.03
local EQUIP_TIME = 0.28
local EQUIP_DROP = 1.2 -- Studs, aus denen die Waffe hochkommt
local RELOAD_DROP = 0.35
local RELOAD_TILT = 22 -- Grad
local FLASH_TIME = 0.045
-- Umrechnung der Rückstoß-Werte aus der Waffentabelle in Feder-Stöße.
local KICK_IMPULSE = 21
local PITCH_IMPULSE = 40
local YAW_IMPULSE = 30
local CAMERA_PITCH_IMPULSE = 17
local CAMERA_YAW_IMPULSE = 12
-- -----------------------------------------------------------------------------

local ViewmodelController = {}

local player = Players.LocalPlayer
local random = Random.new()

local container: Model? = nil
local weaponModel: Model? = nil
local weapon: Weapons.Weapon? = nil
local rightArm: Arm? = nil
local leftArm: Arm? = nil
local flash: Part? = nil

local aiming = false
local aimAlpha = 0
local bobTime = 0
local bobAlpha = 0
local equippedAt = 0
local reloadStart = 0
local reloadDuration = 0
local flashUntil = 0
local lastLook: CFrame? = nil -- Blickrichtung der Kamera im letzten Frame (fürs Schwanken)

local swaySpring = Spring.new(Vector3.zero, 120, 16) -- X Neigung, Y Drehung, Z Rollen (Grad)
local recoilSpring = Spring.new(Vector3.zero, 160, 14) -- X Neigung (Grad), Y Drehung (Grad), Z Rückschlag (Studs)
local cameraRecoil = Spring.new(Vector3.zero, 90, 12) -- X Neigung, Y Drehung (Grad)

------------------------------------------------------------------------------
-- Aufbau
------------------------------------------------------------------------------

local function block(name: string, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function skinColor(): Color3
	local settings = Weapons.Arms
	if settings.UseSkinColor then
		local character = player.Character
		local bodyColors = if character then character:FindFirstChildOfClass("BodyColors") else nil
		if bodyColors then
			return bodyColors.RightArmColor3
		end
	end
	return settings.HandColor
end

local function createArm(name: string, parent: Instance): Arm
	local settings = Weapons.Arms
	return {
		Sleeve = block(name .. "Sleeve", settings.SleeveColor, parent),
		Cuff = block(name .. "Cuff", settings.CuffColor, parent),
		Hand = block(name .. "Hand", skinColor(), parent),
	}
end

-- Spannt einen Arm als gerade Linie von der Schulter bis zur Hand.
local function placeArm(arm: Arm, shoulder: Vector3, hand: Vector3, up: Vector3)
	local settings = Weapons.Arms
	local width = settings.Width
	local total = (hand - shoulder).Magnitude
	local handLength = math.min(settings.HandLength, total * 0.5)
	local cuffLength = settings.CuffLength
	local sleeveLength = math.max(total - handLength - cuffLength, 0.05)

	-- lookAt: -Z zeigt von der Schulter zur Hand. Die Blöcke werden entlang -Z aufgereiht.
	local frame = CFrame.lookAt(shoulder, hand, up)

	arm.Sleeve.Size = Vector3.new(width, width, sleeveLength)
	arm.Sleeve.CFrame = frame * CFrame.new(0, 0, -sleeveLength / 2)

	arm.Cuff.Size = Vector3.new(width * 1.06, width * 1.06, cuffLength)
	arm.Cuff.CFrame = frame * CFrame.new(0, 0, -(sleeveLength + cuffLength / 2))

	arm.Hand.Size = Vector3.new(width * 0.96, width * 0.96, handLength)
	arm.Hand.CFrame = frame * CFrame.new(0, 0, -(sleeveLength + cuffLength + handLength / 2))
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

function ViewmodelController:Unequip()
	if container then
		container:Destroy()
	end
	container = nil
	weaponModel = nil
	weapon = nil
	rightArm = nil
	leftArm = nil
	flash = nil
	aiming = false
	aimAlpha = 0
	reloadDuration = 0
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = Weapons.DefaultFov
	end
end

function ViewmodelController:Equip(weaponId: string)
	ViewmodelController:Unequip()
	local camera = Workspace.CurrentCamera
	local definition = Weapons.List[weaponId]
	if not camera or not definition then
		return
	end

	-- Alles unter der Kamera existiert nur auf diesem Client: Andere Spieler sehen die Ego-Ansicht nie.
	local newContainer = Instance.new("Model")
	newContainer.Name = "Viewmodel"

	local model = WeaponModel.Build(weaponId, true)
	model.Parent = newContainer

	local newFlash = block("MuzzleFlash", Color3.fromRGB(255, 214, 120), newContainer)
	newFlash.Material = Enum.Material.Neon
	newFlash.Shape = Enum.PartType.Ball
	newFlash.Size = Vector3.new(0.5, 0.5, 0.5)
	newFlash.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = newFlash.Color
	light.Range = 12
	light.Brightness = 3
	light.Enabled = false
	light.Parent = newFlash

	rightArm = createArm("Right", newContainer)
	leftArm = createArm("Left", newContainer)
	flash = newFlash
	weaponModel = model
	weapon = definition
	container = newContainer

	equippedAt = os.clock()
	lastLook = nil
	swaySpring:Reset(Vector3.zero)
	recoilSpring:Reset(Vector3.zero)
	newContainer.Parent = camera
end

function ViewmodelController:IsEquipped(): boolean
	return weapon ~= nil
end

function ViewmodelController:SetAiming(state: boolean)
	aiming = state
end

-- 0 = aus der Hüfte, 1 = voll gezielt (für Streuung und Fadenkreuz).
function ViewmodelController:GetAimAlpha(): number
	return aimAlpha
end

function ViewmodelController:Fire()
	local definition = weapon
	if not definition then
		return
	end
	local steady = 1 - aimAlpha * 0.3 -- beim Zielen etwas ruhiger
	recoilSpring:Impulse(
		Vector3.new(
			definition.RecoilPitch * PITCH_IMPULSE,
			random:NextNumber(-1, 1) * definition.RecoilYaw * YAW_IMPULSE,
			definition.RecoilKick * KICK_IMPULSE
		) * steady
	)
	cameraRecoil:Impulse(
		Vector3.new(
			definition.RecoilPitch * CAMERA_PITCH_IMPULSE,
			random:NextNumber(-1, 1) * definition.RecoilYaw * CAMERA_YAW_IMPULSE,
			0
		)
	)
	flashUntil = os.clock() + FLASH_TIME
end

function ViewmodelController:Reload(duration: number)
	reloadStart = os.clock()
	reloadDuration = duration
end

function ViewmodelController:CancelReload()
	reloadDuration = 0
end

-- Weltposition der Mündung (Startpunkt der Leuchtspur). Ohne Waffe: Kameraposition.
function ViewmodelController:GetMuzzlePosition(): Vector3
	local model = weaponModel
	if model then
		return model:GetPivot():PointToWorldSpace(WeaponModel.LocalPosition(model, "Muzzle"))
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

------------------------------------------------------------------------------
-- Jeden Frame
------------------------------------------------------------------------------

local function update(deltaTime: number)
	local camera = Workspace.CurrentCamera
	local definition = weapon
	local model = weaponModel
	local right = rightArm
	local left = leftArm
	if not camera or not definition or not model or not right or not left then
		return
	end
	local now = os.clock()

	-- Nachladen: 0 -> 1 -> 0 über die Dauer (Sinusbogen).
	local reloadBlend = 0
	if reloadDuration > 0 then
		local progress = (now - reloadStart) / reloadDuration
		if progress >= 1 then
			reloadDuration = 0
		else
			reloadBlend = math.sin(math.pi * progress)
		end
	end

	-- Zielen: weich überblenden; während des Nachladens wird nicht gezielt.
	local aimTarget = if aiming and reloadDuration == 0 then 1 else 0
	aimAlpha += (aimTarget - aimAlpha) * (1 - math.exp(-deltaTime / math.max(definition.AimTime / 3, 0.01)))
	camera.FieldOfView = Weapons.DefaultFov + (definition.AimFov - Weapons.DefaultFov) * aimAlpha

	-- Wie weit hat sich die Kamera seit dem letzten Frame gedreht? Gemessen VOR dem Rückstoß,
	-- und an der Kamera statt an der Maus: so schwankt die Waffe auch mit Touch und Controller.
	local look = camera.CFrame.Rotation
	local previousLook = lastLook or look
	lastLook = look
	local turnPitch, turnYaw = previousLook:ToObjectSpace(look):ToOrientation()

	-- Kamera-Rückstoß: nach dem Kamera-Skript aufaddieren, damit auch der Schuss dorthin geht.
	local kick = cameraRecoil:Update(deltaTime)
	camera.CFrame *= CFrame.Angles(math.rad(kick.X), math.rad(kick.Y), 0)
	local cameraCFrame = camera.CFrame

	-- Grundposition: Hüfte <-> Visier in Bildmitte.
	local sight = WeaponModel.LocalPosition(model, "Sight")
	local aimPosition = Vector3.new(-sight.X, -sight.Y, -AIM_DISTANCE - sight.Z)
	local basePosition = definition.HipOffset:Lerp(aimPosition, aimAlpha)

	-- Schwanken: Die Drehung der Kamera stößt die Feder an, sie pendelt zurück auf null.
	local pitchDegrees, yawDegrees = math.deg(turnPitch), math.deg(turnYaw)
	swaySpring:Impulse(Vector3.new(pitchDegrees, yawDegrees, yawDegrees * 0.6) * SWAY_IMPULSE)
	local sway = swaySpring:Update(deltaTime)
	if sway.Magnitude > SWAY_LIMIT then
		sway = sway.Unit * SWAY_LIMIT
		swaySpring.Position = sway
	end
	sway *= 1 - aimAlpha * 0.7

	-- Laufwippen.
	local speed = 0
	local grounded = false
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") then
			speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		end
		grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	end
	if grounded and speed > 1 then
		bobTime += deltaTime * speed * BOB_FREQUENCY
	end
	local bobTarget = if grounded then math.clamp(speed / 16, 0, 1.4) * (1 - aimAlpha * 0.85) else 0
	bobAlpha += (bobTarget - bobAlpha) * (1 - math.exp(-deltaTime * 10))
	local bob = Vector3.new(math.sin(bobTime) * BOB_SIDE, -math.abs(math.cos(bobTime)) * BOB_UP, 0) * bobAlpha

	-- Rückstoß der Waffe.
	local recoil = recoilSpring:Update(deltaTime)

	-- Ziehen: von unten ins Bild (weich auslaufend).
	local equipProgress = math.clamp((now - equippedAt) / EQUIP_TIME, 0, 1)
	local equipBlend = (1 - equipProgress) ^ 2

	local drop = equipBlend * EQUIP_DROP + reloadBlend * RELOAD_DROP
	local pitch = sway.X + recoil.X - equipBlend * 50 - reloadBlend * RELOAD_TILT
	local roll = sway.Z + reloadBlend * 18

	local weaponCFrame = cameraCFrame
		* CFrame.new(basePosition + bob + Vector3.new(0, -drop, recoil.Z))
		* CFrame.Angles(math.rad(pitch), math.rad(sway.Y + recoil.Y), math.rad(roll))
	model:PivotTo(weaponCFrame)

	-- Arme: rechte Hand am Griff, linke Hand an der Stütze bzw. beim Nachladen am Magazin.
	local supportLocal = WeaponModel.LocalPosition(model, "Support")
	if reloadBlend > 0 then
		local magazine = WeaponModel.LocalPosition(model, "Magazine") + Vector3.new(0, -0.45, 0)
		supportLocal = supportLocal:Lerp(magazine, reloadBlend)
	end
	local arms = Weapons.Arms
	local up = cameraCFrame.UpVector
	placeArm(right, cameraCFrame:PointToWorldSpace(arms.RightShoulder), weaponCFrame.Position, up)
	placeArm(left, cameraCFrame:PointToWorldSpace(arms.LeftShoulder), weaponCFrame:PointToWorldSpace(supportLocal), up)

	-- Mündungsfeuer.
	local flashPart = flash
	if flashPart then
		local visible = now < flashUntil
		flashPart.Transparency = if visible then 0.2 else 1
		flashPart.CFrame = CFrame.new(weaponCFrame:PointToWorldSpace(WeaponModel.LocalPosition(model, "Muzzle")))
		local light = flashPart:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = visible
		end
	end
end

function ViewmodelController:Start()
	-- Direkt NACH dem Kamera-Skript, damit die Waffe ohne Verzögerung an der Kamera klebt.
	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 1, update)
end

return ViewmodelController
