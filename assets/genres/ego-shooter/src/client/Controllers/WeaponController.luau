--!strict
--[[
	WeaponController – Eingaben, Schießen, Effekte und Anzeige des Shooters.

	Der Client reagiert SOFORT (Rückstoß, Leuchtspur, Munitionszähler), damit sich
	das Schießen direkt anfühlt, und meldet den Schuss dem Server. Der Server
	entscheidet über Schaden (siehe WeaponService).

	Steuerung
	  Maus links / R2 / Touch-Knopf   schießen
	  Maus rechts / L2 / Touch-Knopf  zielen
	  R / X                           nachladen
	  1, 2, 3 … / Y                   Waffe wechseln

	Geräusche: SOUNDS unten mit Asset-IDs füllen (über Studio-MCP `search_asset`
	suchen). Leere Einträge werden übersprungen.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Weapons = require(Shared.Config.Weapons)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local SOUNDS = {
	Fire = "", -- z. B. "rbxassetid://123456"
	Reload = "",
	Empty = "",
	Hit = "",
}

local TRACER_TIME = 0.08
local TRACER_WIDTH = 0.08
local EFFECT_RANGE = 350 -- fremde Schüsse weiter weg werden nicht gezeichnet
local KILLFEED_SECONDS = 5
local MOVE_SPREAD = 1.2 -- zusätzliche Streuung in Grad bei vollem Lauftempo (nur aus der Hüfte)
local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
}

local WeaponController = {}

local player = Players.LocalPlayer
local random = Random.new()

local weaponId: string? = nil
local weapon: Weapons.Weapon? = nil
local slot = 1
local slotCount = #Weapons.Loadout
local ammo = 0
local reserve = 0
local reloadingUntil = 0
local nextShot = 0
local triggerHeld = false
local firedThisPress = false

-- Anzeige
local crosshairLines: { Frame } = {}
local hitMarker: Frame
local ammoLabel: TextLabel
local weaponLabel: TextLabel
local killFeed: Frame

------------------------------------------------------------------------------
-- Effekte
------------------------------------------------------------------------------

-- Über den SoundController: beachtet die Lautstärke aus den Einstellungen; leere Id bleibt still.
local function playSound(id: string, volumeScale: number?)
	SoundController:Play(id, volumeScale)
end

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 226, 150)
	part.Size = Vector3.new(TRACER_WIDTH, TRACER_WIDTH, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Parent = Workspace.CurrentCamera
	Kit.Tween(part, TRACER_TIME, { Transparency = 1 })
	task.delay(TRACER_TIME, part.Destroy, part)
end

local function impact(position: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 240, 200)
	part.Size = Vector3.new(0.35, 0.35, 0.35)
	part.Position = position
	part.Parent = Workspace.CurrentCamera
	Kit.Tween(part, 0.15, { Transparency = 1, Size = Vector3.new(0.9, 0.9, 0.9) })
	task.delay(0.15, part.Destroy, part)
end

local function showHitMarker(kill: boolean)
	local color = if kill then Kit.Theme.Bad else Color3.new(1, 1, 1)
	for _, line in hitMarker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = color
			line.BackgroundTransparency = 0
			Kit.Tween(line, 0.25, { BackgroundTransparency = 1 })
		end
	end
	playSound(SOUNDS.Hit, 0.8)
end

------------------------------------------------------------------------------
-- Schießen
------------------------------------------------------------------------------

-- Zufällige Richtung innerhalb eines Kegels von `degrees` um `direction` (gleichmäßig auf der Kreisfläche).
local function spreadDirection(direction: Vector3, degrees: number): Vector3
	local angle = math.rad(degrees) * math.sqrt(random:NextNumber())
	local roll = random:NextNumber() * math.pi * 2
	local frame = CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)
	return frame.LookVector
end

local function currentSpread(definition: Weapons.Weapon): number
	local aimAlpha = ViewmodelController:GetAimAlpha()
	local spread = definition.Spread + (definition.AimSpread - definition.Spread) * aimAlpha
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		spread += math.clamp(speed / 16, 0, 1.5) * MOVE_SPREAD * (1 - aimAlpha)
	end
	return spread
end

local function updateAmmoLabel()
	local definition = weapon
	if not definition then
		ammoLabel.Text = ""
		weaponLabel.Text = ""
		return
	end
	ammoLabel.Text = `{ammo} / {reserve}`
	ammoLabel.TextColor3 = if ammo == 0 then Kit.Theme.Bad else Kit.Theme.Text
	local reloading = os.clock() < reloadingUntil
	weaponLabel.Text = if reloading then "Lädt nach …" else definition.DisplayName
end

local function requestReload()
	local definition = weapon
	if not definition or os.clock() < reloadingUntil then
		return
	end
	if ammo >= definition.MagazineSize or reserve <= 0 then
		return
	end
	Net.Send("Weapon.Reload")
end

local function fire()
	local definition = weapon
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not definition or not camera or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < nextShot or now < reloadingUntil then
		return
	end
	if ammo <= 0 then
		nextShot = now + 0.25
		playSound(SOUNDS.Empty)
		requestReload()
		return
	end

	nextShot = now + 60 / definition.FireRate
	ammo -= 1
	updateAmmoLabel()

	local origin = camera.CFrame.Position
	local aimDirection = camera.CFrame.LookVector
	local spread = currentSpread(definition)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }

	ViewmodelController:Fire()
	local muzzle = ViewmodelController:GetMuzzlePosition()
	playSound(SOUNDS.Fire)

	local hits: { { any } } = {}
	for _ = 1, definition.Pellets do
		local direction = spreadDirection(aimDirection, spread)
		local result = Workspace:Raycast(origin, direction * definition.Range, params)
		local endPosition = if result then result.Position else origin + direction * definition.Range
		tracer(muzzle, endPosition)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local targetHumanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
			if targetHumanoid and targetHumanoid.Health > 0 then
				-- Nur melden; ob es zählt, entscheidet der Server und antwortet mit Weapon.HitConfirm.
				table.insert(hits, { result.Instance, result.Position } :: { any })
			else
				impact(result.Position)
			end
		end
	end

	Net.Send("Weapon.Fire", origin, aimDirection, hits)
end

------------------------------------------------------------------------------
-- Zustand vom Server
------------------------------------------------------------------------------

local function applyState(state: any)
	local previous = weaponId
	slot = state.Slot
	slotCount = #state.Loadout
	weaponId = state.WeaponId
	weapon = Weapons.List[state.WeaponId]
	ammo = state.Ammo
	reserve = state.Reserve

	if weaponId ~= previous and weaponId then
		ViewmodelController:Equip(weaponId)
		reloadingUntil = 0
	end
	if type(state.ReloadDuration) == "number" then
		reloadingUntil = os.clock() + state.ReloadDuration
		ViewmodelController:Reload(state.ReloadDuration)
		playSound(SOUNDS.Reload)
		task.delay(state.ReloadDuration, updateAmmoLabel)
	else
		reloadingUntil = 0
	end
	updateAmmoLabel()
end

local function addKillFeed(killer: string, victim: string, usedWeapon: string, headshot: boolean)
	local definition = Weapons.List[usedWeapon]
	local weaponName = if definition then definition.DisplayName else usedWeapon
	local label = Kit.Label({
		Text = `{killer}  [{weaponName}{if headshot then ", Kopfschuss" else ""}]  {victim}`,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = killFeed,
	})
	Kit.Create("UIStroke", { Thickness = 1.5, Color = Kit.Theme.Background, Parent = label })
	task.delay(KILLFEED_SECONDS, label.Destroy, label)
end

------------------------------------------------------------------------------
-- Anzeige
------------------------------------------------------------------------------

local function buildHud()
	local gui = Kit.ScreenGui("ShooterHud", 5)
	gui.IgnoreGuiInset = true

	-- Fadenkreuz: vier Striche, deren Abstand die aktuelle Streuung zeigt.
	local center = Kit.Create("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for index = 1, 4 do
		local vertical = index <= 2
		crosshairLines[index] = Kit.Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = if vertical then UDim2.fromOffset(2, 8) else UDim2.fromOffset(8, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = center,
		}, Kit.Stroke(Color3.new(0, 0, 0), 1))
	end

	hitMarker = Kit.Create("Frame", {
		Name = "HitMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	for _, rotation in { 45, -45 } do
		Kit.Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(22, 2),
			Rotation = rotation,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = hitMarker,
		})
	end

	local ammoPanel = Kit.Panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(190, 70),
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	ammoLabel = Kit.Label({
		Size = UDim2.new(1, -24, 0, 38),
		Position = UDim2.fromOffset(12, 6),
		FontFace = Kit.Theme.FontBold,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = ammoPanel,
	})
	weaponLabel = Kit.Label({
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 44),
		TextColor3 = Kit.Theme.TextDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = ammoPanel,
	})

	killFeed = Kit.Create("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 70),
		Size = UDim2.fromOffset(360, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, Kit.List(Enum.FillDirection.Vertical, 2))
end

local function updateCrosshair()
	local definition = weapon
	local visible = definition ~= nil and ViewmodelController:GetAimAlpha() < 0.8
	local gap = if definition then 6 + currentSpread(definition) * 5 else 6
	local offsets = { Vector2.new(0, -gap), Vector2.new(0, gap), Vector2.new(-gap, 0), Vector2.new(gap, 0) }
	for index, line in crosshairLines do
		line.Visible = visible
		line.Position = UDim2.fromOffset(offsets[index].X, offsets[index].Y)
	end
end

------------------------------------------------------------------------------
-- Eingaben
------------------------------------------------------------------------------

local function bindInputs()
	ContextActionService:BindAction("ShooterFire", function(_name, state)
		triggerHeld = state == Enum.UserInputState.Begin
		if not triggerHeld then
			firedThisPress = false
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("ShooterFire", "Feuer")
	ContextActionService:SetPosition("ShooterFire", UDim2.new(1, -150, 1, -130))

	ContextActionService:BindAction("ShooterAim", function(_name, state, input)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Auf dem Handy umschalten statt halten.
			if state == Enum.UserInputState.Begin then
				ViewmodelController:SetAiming(ViewmodelController:GetAimAlpha() < 0.5)
			end
		else
			ViewmodelController:SetAiming(state == Enum.UserInputState.Begin)
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("ShooterAim", "Zielen")
	ContextActionService:SetPosition("ShooterAim", UDim2.new(1, -230, 1, -90))

	ContextActionService:BindAction("ShooterReload", function(_name, state)
		if state == Enum.UserInputState.Begin then
			requestReload()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("ShooterReload", "Laden")
	ContextActionService:SetPosition("ShooterReload", UDim2.new(1, -90, 1, -210))

	ContextActionService:BindAction("ShooterSlot", function(_name, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local wanted = table.find(SLOT_KEYS, input.KeyCode)
		if input.KeyCode == Enum.KeyCode.ButtonY then
			wanted = slot % slotCount + 1
		end
		if wanted and wanted <= slotCount and wanted ~= slot then
			Net.Send("Weapon.Equip", wanted)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonY, table.unpack(SLOT_KEYS))
end

------------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------------

function WeaponController:Init()
	buildHud()

	Net.Listen("Weapon.State", applyState)
	Net.Listen("Weapon.Kill", addKillFeed)
	Net.Listen("Weapon.HitConfirm", function(_headshot: boolean, kill: boolean)
		showHitMarker(kill)
	end)
	-- Schüsse anderer Spieler: Leuchtspur vom Kopf des Schützen zum Endpunkt.
	Net.Listen("Weapon.Effect", function(shooter: Player, origin: Vector3, endPosition: Vector3)
		if shooter == player or player:DistanceFromCharacter(origin) > EFFECT_RANGE then
			return
		end
		tracer(origin, endPosition)
		SoundController:PlayAt(SOUNDS.Fire, origin)
	end)
end

function WeaponController:Start()
	-- Ego-Shooter: Kamera fest in der Ich-Ansicht.
	player.CameraMode = Enum.CameraMode.LockFirstPerson

	bindInputs()

	-- Waffe weglegen: beim Tod (sonst schwebt sie bis zum Neuerscheinen im Bild) und beim neuen Charakter.
	local function dropWeapon()
		triggerHeld = false
		weaponId = nil -- erzwingt neues Ausrüsten, sobald der Server den Zustand schickt
		weapon = nil
		ViewmodelController:Unequip()
		updateAmmoLabel()
	end

	local function onCharacter(character: Model)
		dropWeapon()
		-- Zustand ausdrücklich neu anfordern, statt sich auf die Reihenfolge der Nachrichten zu verlassen.
		Net.Send("Weapon.RequestState")
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Once(dropWeapon)
		end
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	RunService.RenderStepped:Connect(function()
		local definition = weapon
		if triggerHeld and definition and (definition.Automatic or not firedThisPress) then
			firedThisPress = true
			fire()
		end
		updateCrosshair()
	end)
end

return WeaponController
