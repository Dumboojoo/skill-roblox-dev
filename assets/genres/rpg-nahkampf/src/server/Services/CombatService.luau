--!strict
--[[
	CombatService – Nahkampf-Schläge und Ausweichrolle der Spieler.

	Der Client meldet nur "ich schlage zu". Der Server
	  - prüft die Abklingzeit,
	  - berechnet die Trefferzone selbst aus der Position, die ER vom Charakter
	    kennt (ein Kasten vor dem Spieler),
	  - bestimmt Kombo-Schritt und Schaden.
	Der Client kann also weder Reichweite noch Schaden noch Ziele vorgeben.

	Für Nahkampf ist das die richtige Aufteilung: Die Zone ist groß und nah, die
	kleine Verzögerung fällt kaum auf. (Bei Schusswaffen meldet dagegen der Client
	den Treffer, siehe Genre Ego-Shooter.)

	Ausweichrolle: Der Server vergibt kurz Unverwundbarkeit (Attribut DodgeUntil),
	die Bewegung selbst macht der Client des Spielers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Rpg)
local Formulas = require(Shared.Rpg.Formulas)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

type State = { NextAttack: number, LastAttack: number, ComboStep: number, NextDodge: number }

local TOLERANCE = 0.05 -- Sekunden Nachsicht bei der Abklingzeit (Netzwerk-Schwankung)
local HITBOX_HEIGHT = 6

local CombatService = {}

local states: { [Player]: State } = {}

local function aliveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function onAttack(player: Player)
	local state = states[player]
	local root = aliveRoot(player)
	if not state or not root then
		return
	end
	local now = os.clock()
	if now < state.NextAttack - TOLERANCE then
		return
	end

	local attack = Config.Attack
	state.ComboStep = if now - state.LastAttack <= attack.ComboWindow
		then state.ComboStep % attack.ComboCount + 1
		else 1
	state.LastAttack = now
	state.NextAttack = now + attack.Cooldown

	local level = DataService:Get(player, "Rpg.Level")
	local damage = Formulas.AttackDamage(
		attack.Damage,
		if type(level) == "number" then level else 1,
		Config.Levels.DamagePerLevel,
		state.ComboStep,
		attack.ComboBonus
	)

	-- Trefferzone: Kasten direkt vor dem Spieler, aus Serversicht.
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local center = root.CFrame * CFrame.new(0, 0, -attack.Range / 2)
	local parts = Workspace:GetPartBoundsInBox(center, Vector3.new(attack.Width, HITBOX_HEIGHT, attack.Range), params)

	local struck: { [Model]: boolean } = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		if not model or struck[model] then
			continue
		end
		struck[model] = true
		if EnemyService:Damage(model, damage, player) then
			continue
		end
		if Config.PvP then
			local victim = Players:GetPlayerFromCharacter(model)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if victim and humanoid and humanoid.Health > 0 then
				local dodgeUntil = victim:GetAttribute("DodgeUntil")
				if type(dodgeUntil) ~= "number" or Workspace:GetServerTimeNow() > dodgeUntil then
					humanoid:TakeDamage(damage)
				end
			end
		end
	end

	-- Alle in der Nähe sehen den Schlag (Armbewegung macht jeder Client selbst).
	Net.FireNear("Combat.Swing", root.Position, 120, player, state.ComboStep)
end

local function onDodge(player: Player)
	local state = states[player]
	if not state or not aliveRoot(player) then
		return
	end
	local now = os.clock()
	if now < state.NextDodge - TOLERANCE then
		return
	end
	state.NextDodge = now + Config.Dodge.Cooldown
	player:SetAttribute("DodgeUntil", Workspace:GetServerTimeNow() + Config.Dodge.Duration)
end

function CombatService:Init()
	Net.Declare("Combat.Swing", { Unreliable = true })
	Net.On("Combat.Attack", {}, onAttack, { Rate = 6 })
	Net.On("Combat.Dodge", {}, onDodge, { Rate = 3 })
end

function CombatService:Start()
	local function onPlayer(player: Player)
		states[player] = { NextAttack = 0, LastAttack = 0, ComboStep = 0, NextDodge = 0 }
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CombatService
