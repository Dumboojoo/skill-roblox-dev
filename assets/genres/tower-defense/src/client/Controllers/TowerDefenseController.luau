--!strict
--[[
	TowerDefenseController – stellt Gegner und Türme dar und nimmt Eingaben entgegen.

	Der Server schickt nur Daten. Hier entstehen daraus sichtbare Blöcke:
	  Gegner  ein Block mit Lebensbalken, der jeden Frame selbst auf dem Weg
	          weiterläuft und sich an den Positionsmeldungen des Servers ausrichtet
	  Türme   Sockel + Block in Turmfarbe; pro Stufe ein Stück höher

	Eigene Modelle statt Blöcke: in `createEnemyVisual` / `createTowerVisual`
	ein Model aus ReplicatedStorage.Assets klonen statt Parts zu bauen.

	Bedienung
	  Turm-Knopf unten -> Vorschau folgt Maus/Finger -> Klick/Tippen baut, Rechtsklick/X bricht ab
	  Klick auf eigenen Turm -> Menü: Verbessern, Zielwahl, Verkaufen
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.TowerDefense)
local Net = require(Shared.Net)
local PathMath = require(Shared.TowerDefense.PathMath)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

type EnemyVisual = {
	Part: Part,
	Bar: Frame,
	Distance: number,
	TargetDistance: number,
	Speed: number,
	SlowFactor: number,
	Health: number,
	MaxHealth: number,
	HoverHeight: number,
}

type TowerVisual = { Model: Model, Info: { [string]: any } }

local CORRECTION_RATE = 6 -- wie schnell die Darstellung zur Server-Position aufholt

local TowerDefenseController = {}

local player = Players.LocalPlayer
local path: PathMath.Path? = nil
local folder: Folder
local enemyVisuals: { [number]: EnemyVisual } = {}
local towerVisuals: { [number]: TowerVisual } = {}

local placingType: string? = nil
local ghost: Part? = nil
local rangeRing: Part
local selectedUid: number? = nil

local statusLabel: TextLabel
local cashLabel: TextLabel
local towerPanel: Frame
local towerPanelTitle: TextLabel
local upgradeButton: TextButton
local targetButton: TextButton
local skipButton: TextButton

------------------------------------------------------------------------------
-- Darstellung
------------------------------------------------------------------------------

local function inertPart(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createEnemyVisual(id: number, enemyType: string, maxHealth: number, distance: number, health: number)
	local definition = Config.Enemies[enemyType]
	if not definition or enemyVisuals[id] then
		return
	end
	local part = inertPart(`Enemy{id}`, folder)
	part.Size = Vector3.new(definition.Size, definition.Size, definition.Size)
	part.Color = definition.Color

	local billboard = Kit.Create("BillboardGui", {
		Size = UDim2.fromOffset(60, 8),
		StudsOffset = Vector3.new(0, definition.Size / 2 + 1, 0),
		AlwaysOnTop = true,
		Parent = part,
	})
	local back = Kit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.Theme.Background,
		BorderSizePixel = 0,
		Parent = billboard,
	})
	local bar = Kit.Create("Frame", {
		Size = UDim2.fromScale(health / maxHealth, 1),
		BackgroundColor3 = Kit.Theme.Bad,
		BorderSizePixel = 0,
		Parent = back,
	})

	enemyVisuals[id] = {
		Part = part,
		Bar = bar,
		Distance = distance,
		TargetDistance = distance,
		Speed = definition.Speed,
		SlowFactor = 1,
		Health = health,
		MaxHealth = maxHealth,
		HoverHeight = definition.Size / 2,
	}
end

local function removeEnemyVisual(id: number, reason: string)
	local visual = enemyVisuals[id]
	if not visual then
		return
	end
	enemyVisuals[id] = nil
	if reason == "Killed" then
		-- Kurzes Aufplatzen statt wortlosem Verschwinden.
		Kit.Tween(visual.Part, 0.18, { Size = visual.Part.Size * 1.6, Transparency = 1 })
		task.delay(0.18, visual.Part.Destroy, visual.Part)
	else
		visual.Part:Destroy()
	end
end

local function createTowerVisual(info: { [string]: any })
	local definition = Config.Towers[info.Type]
	local existing = towerVisuals[info.Uid]
	if existing then
		existing.Model:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = `Tower{info.Uid}`
	model:SetAttribute("TowerUid", info.Uid)

	local position = info.Position :: Vector3
	local height = 2.5 + info.Level * 1.2

	local base = inertPart("Base", model)
	base.CanQuery = true -- anklickbar
	base.Size = Vector3.new(3.4, 1, 3.4)
	base.Color = Kit.Theme.PanelLight
	base.Position = position + Vector3.new(0, 0.5, 0)

	local body = inertPart("Body", model)
	body.CanQuery = true
	body.Size = Vector3.new(2.2, height, 2.2)
	body.Color = definition.Color
	body.Position = position + Vector3.new(0, 1 + height / 2, 0)

	local top = inertPart("Top", model)
	top.Size = Vector3.new(1.2, 0.8, 2.8)
	top.Color = definition.Color:Lerp(Color3.new(0, 0, 0), 0.35)
	top.Position = position + Vector3.new(0, 1 + height + 0.4, 0)

	model.Parent = folder
	towerVisuals[info.Uid] = { Model = model, Info = info }
end

-- Dünner Strahl vom Turm zum Ziel als Schuss-Rückmeldung.
local function showShot(uid: number, enemyId: number)
	local tower = towerVisuals[uid]
	local enemy = enemyVisuals[enemyId]
	if not tower or not enemy then
		return
	end
	local top = tower.Model:FindFirstChild("Top")
	if not top or not top:IsA("BasePart") then
		return
	end
	local from, to = top.Position, enemy.Part.Position
	local length = (to - from).Magnitude
	SoundController:PlayAt("Shot", from, 0.6)
	top.CFrame = CFrame.lookAt(top.Position, Vector3.new(to.X, top.Position.Y, to.Z))
	local beam = inertPart("Shot", folder)
	beam.Material = Enum.Material.Neon
	beam.Color = Config.Towers[tower.Info.Type].Color
	beam.Size = Vector3.new(0.15, 0.15, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	Kit.Tween(beam, 0.12, { Transparency = 1 })
	task.delay(0.12, beam.Destroy, beam)
end

------------------------------------------------------------------------------
-- Auswahl und Bau
------------------------------------------------------------------------------

local function showRange(position: Vector3?, range: number?)
	if position and range then
		rangeRing.Size = Vector3.new(0.2, range * 2, range * 2)
		rangeRing.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		rangeRing.Transparency = 0.8
	else
		rangeRing.Transparency = 1
	end
end

local function refreshTowerPanel()
	local visual = if selectedUid then towerVisuals[selectedUid] else nil
	if not visual then
		selectedUid = nil
		towerPanel.Visible = false
		if not placingType then
			showRange(nil, nil)
		end
		return
	end
	local info = visual.Info
	local definition = Config.Towers[info.Type]
	local level = definition.Levels[info.Level]
	local nextLevel = definition.Levels[info.Level + 1]
	towerPanel.Visible = true
	towerPanelTitle.Text = `{definition.DisplayName}  ·  Stufe {info.Level}`
	upgradeButton.Text = if nextLevel then `Verbessern ({nextLevel.Cost})` else "Höchste Stufe"
	targetButton.Text = `Ziel: {info.Targeting}`
	showRange(info.Position, level.Range)
end

local function stopPlacing()
	placingType = nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	refreshTowerPanel()
end

local function startPlacing(towerType: string)
	stopPlacing()
	selectedUid = nil
	towerPanel.Visible = false
	placingType = towerType
	local part = inertPart("Ghost", folder)
	part.Size = Vector3.new(2.2, 4, 2.2)
	part.Material = Enum.Material.ForceField
	part.Color = Config.Towers[towerType].Color
	ghost = part
end

-- Strahl von der Maus bzw. dem Finger in die Welt.
local function screenRay(screenPosition: Vector2, include: { Instance }?): RaycastResult?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	if include then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = include
	end
	return Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
end

local function canPlaceAt(position: Vector3): boolean
	local currentPath = path
	if not currentPath or PathMath.DistanceTo(currentPath, position) < Config.PathClearance then
		return false
	end
	for _, visual in towerVisuals do
		if ((visual.Info.Position :: Vector3) - position).Magnitude < Config.MinTowerSpacing then
			return false
		end
	end
	return true
end

local function onPrimaryInput(screenPosition: Vector2)
	local towerType = placingType
	if towerType then
		local result = screenRay(screenPosition, World.Tagged("TowerGround"))
		if result and canPlaceAt(result.Position) then
			Net.Send("TD.Place", towerType, result.Position)
			-- Shift gedrückt halten, um mehrere zu bauen.
			if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				stopPlacing()
			end
		end
		return
	end

	local result = screenRay(screenPosition, { folder :: Instance })
	local model = if result then result.Instance:FindFirstAncestorOfClass("Model") else nil
	local uid = if model then model:GetAttribute("TowerUid") else nil
	local visual = if type(uid) == "number" then towerVisuals[uid] else nil
	if visual and visual.Info.OwnerId == player.UserId then
		selectedUid = uid :: number
	else
		selectedUid = nil
	end
	refreshTowerPanel()
end

------------------------------------------------------------------------------
-- Anzeige
------------------------------------------------------------------------------

local function buildHud()
	local gui = Kit.ScreenGui("TowerDefenseHud", 5)

	local top = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(460, 44),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	statusLabel = Kit.Label({
		Size = UDim2.new(1, -150, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		FontFace = Kit.Theme.FontBold,
		Parent = top,
	})
	cashLabel = Kit.Label({
		Size = UDim2.new(0, 130, 1, 0),
		Position = UDim2.new(1, -142, 0, 0),
		FontFace = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Warn,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = top,
	})

	skipButton = Kit.Button({
		Text = "Welle starten",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(170, 44),
		Parent = gui,
	}, function()
		Net.Send("TD.Skip")
	end)

	-- Turm-Leiste unten.
	local bar = Kit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 64),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	}, Kit.List(Enum.FillDirection.Horizontal, 8))
	local names = {}
	for towerType in Config.Towers do
		table.insert(names, towerType)
	end
	table.sort(names, function(a, b)
		return Config.Towers[a].Levels[1].Cost < Config.Towers[b].Levels[1].Cost
	end)
	for index, towerType in names do
		local definition = Config.Towers[towerType]
		Kit.Button({
			Text = `{definition.DisplayName}\n{definition.Levels[1].Cost}`,
			Size = UDim2.fromOffset(120, 64),
			BackgroundColor3 = definition.Color:Lerp(Kit.Theme.Background, 0.35),
			LayoutOrder = index,
			Parent = bar,
		}, function()
			if placingType == towerType then
				stopPlacing()
			else
				startPlacing(towerType)
			end
		end)
	end

	-- Menü für den ausgewählten Turm.
	towerPanel = Kit.Panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(220, 210),
		Visible = false,
		Parent = gui,
	})
	Kit.Padding(10).Parent = towerPanel
	Kit.List(Enum.FillDirection.Vertical, 8).Parent = towerPanel
	towerPanelTitle = Kit.Label({
		Size = UDim2.new(1, 0, 0, 24),
		FontFace = Kit.Theme.FontBold,
		LayoutOrder = 1,
		Parent = towerPanel,
	})
	upgradeButton = Kit.Button({ Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 2, Parent = towerPanel }, function()
		if selectedUid then
			Net.Send("TD.Upgrade", selectedUid)
		end
	end)
	targetButton = Kit.Button({
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		LayoutOrder = 3,
		Parent = towerPanel,
	}, function()
		local visual = if selectedUid then towerVisuals[selectedUid] else nil
		if visual then
			local index = table.find(Config.TargetModes, visual.Info.Targeting) or 1
			Net.Send("TD.Targeting", visual.Info.Uid, Config.TargetModes[index % #Config.TargetModes + 1])
		end
	end)
	Kit.Button({
		Text = "Verkaufen",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		LayoutOrder = 4,
		Parent = towerPanel,
	}, function()
		if selectedUid then
			Net.Send("TD.Sell", selectedUid)
		end
	end)
end

local function refreshStatus()
	local phase = Workspace:GetAttribute("TDPhase")
	local wave = Workspace:GetAttribute("TDWave") or 0
	local health = Workspace:GetAttribute("TDBaseHealth") or 0
	local endsAt = Workspace:GetAttribute("TDPhaseEndsAt") or 0
	local remaining = math.max(0, math.ceil((endsAt :: number) - Workspace:GetServerTimeNow()))
	local text
	if phase == "Intermission" then
		text = `Nächste Welle in {remaining}s`
	elseif phase == "Wave" then
		text = `Welle {wave} / {#Config.Waves}`
	elseif phase == "Won" then
		text = `Gewonnen! Neustart in {remaining}s`
	elseif phase == "Lost" then
		text = `Basis zerstört. Neustart in {remaining}s`
	else
		text = "Warte auf Spieler …"
	end
	statusLabel.Text = `{text}   ·   Basis {health}`
	skipButton.Visible = phase == "Intermission"
	local cash = player:GetAttribute("TDCash")
	cashLabel.Text = `{if type(cash) == "number" then cash else 0} Gold`
end

------------------------------------------------------------------------------
-- Jeden Frame
------------------------------------------------------------------------------

local function update(deltaTime: number)
	local currentPath = path
	if currentPath then
		for _, visual in enemyVisuals do
			local advance = visual.Speed * visual.SlowFactor * deltaTime
			visual.TargetDistance += advance
			-- Selbst weiterlaufen und sanft zur Server-Position aufholen (kein Springen).
			visual.Distance += advance + (visual.TargetDistance - visual.Distance) * math.min(
				1,
				deltaTime * CORRECTION_RATE
			)
			local position, direction = PathMath.PositionAt(currentPath, visual.Distance)
			local lifted = position + Vector3.new(0, visual.HoverHeight, 0)
			visual.Part.CFrame = CFrame.lookAt(lifted, lifted + direction)
		end
	end

	local ghostPart = ghost
	local towerType = placingType
	if ghostPart and towerType then
		local result = screenRay(UserInputService:GetMouseLocation(), World.Tagged("TowerGround"))
		if result then
			local allowed = canPlaceAt(result.Position)
			ghostPart.Position = result.Position + Vector3.new(0, 2, 0)
			ghostPart.Color = if allowed then Kit.Theme.Good else Kit.Theme.Bad
			showRange(result.Position, Config.Towers[towerType].Levels[1].Range)
		end
	end

	refreshStatus()
end

------------------------------------------------------------------------------

function TowerDefenseController:Init()
	local created = Instance.new("Folder")
	created.Name = "TowerDefenseVisuals"
	created.Parent = Workspace
	folder = created

	rangeRing = inertPart("RangeRing", Workspace)
	rangeRing.Shape = Enum.PartType.Cylinder
	rangeRing.Material = Enum.Material.ForceField
	rangeRing.Color = Kit.Theme.Accent
	rangeRing.Transparency = 1

	buildHud()

	Net.Listen("TD.EnemySpawn", function(id: number, enemyType: string, maxHealth: number)
		createEnemyVisual(id, enemyType, maxHealth, 0, maxHealth)
	end)
	Net.Listen("TD.EnemyRemove", removeEnemyVisual)
	Net.Listen("TD.Enemies", function(snapshot: { { number } })
		for _, entry in snapshot do
			local visual = enemyVisuals[entry[1]]
			if visual then
				visual.TargetDistance = entry[2]
				visual.Health = entry[3]
				visual.SlowFactor = entry[4]
				visual.Bar.Size = UDim2.fromScale(math.clamp(entry[3] / visual.MaxHealth, 0, 1), 1)
			end
		end
	end)
	Net.Listen("TD.TowerPlaced", createTowerVisual)
	Net.Listen("TD.TowerChanged", function(info: { [string]: any })
		createTowerVisual(info)
		refreshTowerPanel()
	end)
	Net.Listen("TD.TowerRemoved", function(uid: number)
		local visual = towerVisuals[uid]
		if visual then
			visual.Model:Destroy()
			towerVisuals[uid] = nil
		end
		refreshTowerPanel()
	end)
	Net.Listen("TD.Shot", showShot)
	Net.Listen("TD.Sync", function(towerList: { { [string]: any } }, enemyList: { { any } })
		for _, info in towerList do
			createTowerVisual(info)
		end
		for _, entry in enemyList do
			createEnemyVisual(entry[1], entry[2], entry[3], entry[4], entry[5])
		end
	end)
end

function TowerDefenseController:Start()
	path = PathMath.fromWorld()
	World.Observe("PathPoint", function()
		path = PathMath.fromWorld()
		return nil
	end)
	Net.Send("TD.RequestSync")

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			onPrimaryInput(Vector2.new(input.Position.X, input.Position.Y) + Vector2.new(0, Kit.TopInset()))
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.X then
			stopPlacing()
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return TowerDefenseController
