--!strict
--[[
	WeaponModel – baut das 3D-Modell einer Waffe.

	Zwei Quellen, in dieser Reihenfolge:
	  1. ReplicatedStorage.Assets.Weapons.<WaffenId>  (eigenes Modell aus Studio)
	  2. Blöcke aus Weapons.List[...].Model.Parts      (funktioniert immer)

	Jedes Waffenmodell hat ein PrimaryPart namens "Root" am Griff der rechten Hand
	mit diesen Attachments. Darauf verlassen sich Ego-Ansicht und Effekte:
	  Grip      rechte Hand
	  Support   linke Hand
	  Muzzle    Mündung
	  Sight     Zielpunkt (wandert beim Zielen in die Bildmitte)
	  Magazine  Ziel der linken Hand beim Nachladen
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapons = require(script.Parent.Parent.Config.Weapons)

local ATTACHMENTS = { "Grip", "Support", "Muzzle", "Sight", "Magazine" }

local WeaponModel = {}

local function makeInert(part: BasePart, castShadow: boolean)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = castShadow
end

local function customModel(weaponId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild("Weapons") else nil
	local template = if folder then folder:FindFirstChild(weaponId) else nil
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		return nil
	end
	for _, name in ATTACHMENTS do
		if not template.PrimaryPart:FindFirstChild(name) then
			warn(
				`[WeaponModel] Assets.Weapons.{weaponId}: Attachment "{name}" fehlt am PrimaryPart. Es wird das Block-Modell benutzt.`
			)
			return nil
		end
	end
	return template:Clone()
end

local function blockModel(weaponId: string, spec: Weapons.ModelSpec): Model
	local model = Instance.new("Model")
	model.Name = weaponId

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	for index, partSpec in spec.Parts do
		local part = Instance.new("Part")
		part.Name = `Block{index}`
		part.Size = partSpec.Size
		part.Color = partSpec.Color
		part.Material = partSpec.Material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local rotation = partSpec.Rotation or Vector3.zero
		part.CFrame = CFrame.new(partSpec.Position)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	local positions: { [string]: Vector3 } = {
		Grip = Vector3.zero,
		Support = spec.Support,
		Muzzle = spec.Muzzle,
		Sight = spec.Sight,
		Magazine = spec.Magazine,
	}
	for _, name in ATTACHMENTS do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = positions[name]
		attachment.Parent = root
	end

	return model
end

-- `forViewmodel = true`: Ego-Ansicht (Root verankert, kein Schatten). Sonst für die Hand des Charakters.
function WeaponModel.Build(weaponId: string, forViewmodel: boolean): Model
	local weapon = Weapons.List[weaponId]
	assert(weapon, `Unbekannte Waffe "{weaponId}"`)

	local model = customModel(weaponId) or blockModel(weaponId, weapon.Model)
	local root = model.PrimaryPart :: BasePart

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			makeInert(descendant, not forViewmodel)
			-- Ego-Ansicht: alles verankert und per PivotTo bewegt (keine Physik im Spiel).
			-- Am Charakter: unverankert und an die Hand geschweißt.
			descendant.Anchored = forViewmodel
		end
	end
	root.Anchored = forViewmodel
	return model
end

-- Position eines Attachments im Waffenraum (relativ zum Root).
function WeaponModel.LocalPosition(model: Model, name: string): Vector3
	local root = model.PrimaryPart
	local attachment = if root then root:FindFirstChild(name) else nil
	if attachment and attachment:IsA("Attachment") then
		return attachment.Position
	end
	return Vector3.zero
end

return WeaponModel
