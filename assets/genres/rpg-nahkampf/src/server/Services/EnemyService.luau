--!strict
--[[
	EnemyService – Gegner erscheinen lassen, steuern und Schaden verbuchen.

	Wichtig für die Leistung: Es gibt EINE Schleife für alle Gegner (5-mal pro
	Sekunde), nicht ein Skript oder einen Thread pro Gegner. Jeder Gegner ist ein
	Eintrag in einer Tabelle mit seinem Zustand.

	Verhalten: Steht ein Spieler in AggroRange, wird er verfolgt und in
	AttackRange angegriffen. Entfernt sich der Gegner weiter als LeashRange von
	seinem Spawn, gibt er auf und läuft zurück. Ohne Ziel schlendert er herum.

	Erweitern: neue Zustände (Fernkampf, Flucht bei wenig Leben, Boss-Phasen) in
	`think` ergänzen; pro Gegnertyp über ein Feld in Config.Enemies schaltbar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Rpg)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local World = require(Shared.Util.World)

type EnemyState = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Type: string,
	Definition: Config.Enemy,
	Home: Vector3,
	NextAttack: number,
	NextWander: number,
	Damagers: { [Player]: number }, -- wer wie viel Schaden gemacht hat
}

local THINK_INTERVAL = 0.2
local WANDER_RADIUS = 10

local EnemyService = {
	-- (Spieler mit dem meisten Schaden, Gegnertyp, Position)
	Killed = Signal.new() :: Signal.Signal<Player, string, Vector3>,
}

local enemies: { [Model]: EnemyState } = {}
local folder: Folder
local random = Random.new()

------------------------------------------------------------------------------
-- Modell
------------------------------------------------------------------------------

local function addHealthBar(model: Model, root: BasePart, humanoid: Humanoid, definition: Config.Enemy)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromOffset(110, 30)
	billboard.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 1.6, 0)
	billboard.MaxDistance = 70

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = definition.DisplayName
	name.Parent = billboard

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BorderSizePixel = 0
	back.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 80, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back

	humanoid.HealthChanged:Connect(function(health)
		fill.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
	billboard.Parent = model
	billboard.Adornee = root
end

-- Einfacher Block-Gegner: Das HumanoidRootPart ist zugleich der sichtbare Körper.
local function blockModel(enemyType: string, definition: Config.Enemy): Model
	local model = Instance.new("Model")
	model.Name = enemyType

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = definition.Size
	root.Color = definition.Color
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	-- R15-Modus: HipHeight = Abstand zwischen Boden und Unterkante des Körpers.
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.05
	humanoid.RequiresNeck = false -- kein Kopf, also darf fehlender Hals nicht töten
	humanoid.Parent = model
	return model
end

local function createModel(enemyType: string, definition: Config.Enemy): Model
	local assets = ServerStorage:FindFirstChild("Assets")
	local custom = if assets then assets:FindFirstChild("Enemies") else nil
	local template = if custom then custom:FindFirstChild(enemyType) else nil
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") and template.PrimaryPart then
		return template:Clone()
	end
	return blockModel(enemyType, definition)
end

------------------------------------------------------------------------------
-- Erscheinen und Sterben
------------------------------------------------------------------------------

local spawnEnemy: (enemyType: string, position: Vector3) -> ()

local function onDied(state: EnemyState)
	enemies[state.Model] = nil

	-- Belohnung bekommt, wer am meisten Schaden gemacht hat.
	local best: Player? = nil
	local bestDamage = 0
	for player, damage in state.Damagers do
		if damage > bestDamage and player.Parent == Players then
			best, bestDamage = player, damage
		end
	end
	if best then
		EnemyService.Killed:Fire(best, state.Type, state.Root.Position)
	end

	task.delay(1.5, state.Model.Destroy, state.Model)
	task.delay(state.Definition.RespawnTime, spawnEnemy, state.Type, state.Home)
end

function spawnEnemy(enemyType: string, position: Vector3)
	local definition = Config.Enemies[enemyType]
	if not definition then
		warn(`[Gegner] Unbekannter Gegnertyp "{enemyType}".`)
		return
	end
	local model = createModel(enemyType, definition)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart

	humanoid.MaxHealth = definition.Health
	humanoid.Health = definition.Health
	humanoid.WalkSpeed = definition.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("EnemyType", enemyType)
	model:PivotTo(CFrame.new(position + Vector3.new(0, root.Size.Y / 2 + 1, 0)))
	model.Parent = folder
	-- Der Server steuert die Physik: Kein Client kann den Gegner verschieben.
	root:SetNetworkOwner(nil)
	addHealthBar(model, root, humanoid, definition)

	local state: EnemyState = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Type = enemyType,
		Definition = definition,
		Home = position,
		NextAttack = 0,
		NextWander = 0,
		Damagers = {},
	}
	enemies[model] = state
	humanoid.Died:Once(function()
		onDied(state)
	end)
end

------------------------------------------------------------------------------
-- Verhalten
------------------------------------------------------------------------------

local function nearestTarget(state: EnemyState): (Humanoid?, BasePart?, Player?)
	local definition = state.Definition
	local best: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestPlayer: Player? = nil
	local bestDistance = definition.AggroRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local distance = (root.Position - state.Root.Position).Magnitude
			local fromHome = (root.Position - state.Home).Magnitude
			if distance < bestDistance and fromHome < definition.LeashRange then
				best, bestRoot, bestPlayer, bestDistance = humanoid, root, player, distance
			end
		end
	end
	return best, bestRoot, bestPlayer
end

local function think(state: EnemyState, now: number)
	local definition = state.Definition
	local targetHumanoid, targetRoot, targetPlayer = nearestTarget(state)

	if targetHumanoid and targetRoot and targetPlayer then
		local distance = (targetRoot.Position - state.Root.Position).Magnitude
		if distance <= definition.AttackRange then
			state.Humanoid:MoveTo(state.Root.Position)
			if now >= state.NextAttack then
				state.NextAttack = now + definition.AttackCooldown
				-- Ausweichrolle: Der CombatService setzt DodgeUntil (Serverzeit).
				local dodgeUntil = targetPlayer:GetAttribute("DodgeUntil")
				if type(dodgeUntil) ~= "number" or Workspace:GetServerTimeNow() > dodgeUntil then
					targetHumanoid:TakeDamage(definition.Damage)
				end
			end
		else
			state.Humanoid:MoveTo(targetRoot.Position)
		end
		return
	end

	-- Kein Ziel: nach Hause bzw. gelegentlich herumschlendern.
	local fromHome = (state.Root.Position - state.Home).Magnitude
	if fromHome > WANDER_RADIUS * 1.5 then
		state.Humanoid:MoveTo(state.Home)
	elseif now >= state.NextWander then
		state.NextWander = now + random:NextNumber(3, 7)
		local offset = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * WANDER_RADIUS
		state.Humanoid:MoveTo(state.Home + offset)
	end
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

-- Fügt einem Gegner Schaden zu. `instance` ist irgendein Teil des Gegners. Gibt true zurück, wenn es einer war.
function EnemyService:Damage(instance: Instance, amount: number, attacker: Player): boolean
	local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
	local state = if model then enemies[model] else nil
	if not state or state.Humanoid.Health <= 0 then
		return false
	end
	state.Damagers[attacker] = (state.Damagers[attacker] or 0) + amount
	state.Humanoid:TakeDamage(amount)
	Net.FireNear("Combat.Damage", state.Root.Position, 90, state.Root.Position, amount)
	return true
end

function EnemyService:IsEnemy(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and enemies[model] ~= nil
end

-- Für Admin-Befehle und Ereignisse: Gegner an einer Stelle erscheinen lassen.
function EnemyService:Spawn(enemyType: string, position: Vector3)
	spawnEnemy(enemyType, position)
end

------------------------------------------------------------------------------

function EnemyService:Init()
	Net.Declare("Combat.Damage", { Unreliable = true })
	local created = Instance.new("Folder")
	created.Name = "Enemies"
	created.Parent = Workspace
	folder = created
end

function EnemyService:Start()
	World.Expect("RPG", {
		{
			Tag = "EnemySpawn",
			Class = "BasePart",
			Attributes = { Enemy = "string" },
			Hint = "Teile mit Tag EnemySpawn und Attribut Enemy (z. B. Slime) setzen.",
		},
	})
	World.Observe("EnemySpawn", function(instance)
		local enemyType = instance:GetAttribute("Enemy")
		if instance:IsA("BasePart") and type(enemyType) == "string" then
			spawnEnemy(enemyType, instance.Position)
		end
		return nil
	end)

	task.spawn(function()
		while true do
			local now = os.clock()
			for _, state in enemies do
				if state.Humanoid.Health > 0 then
					think(state, now)
				end
			end
			task.wait(THINK_INTERVAL)
		end
	end)
end

return EnemyService
