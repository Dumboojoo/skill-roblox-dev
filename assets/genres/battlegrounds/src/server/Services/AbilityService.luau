--!strict
--[[
	AbilityService – Grundschläge, Fähigkeiten, Block, Betäubung, Ulti.

	Der Client meldet nur "Taste X gedrückt". Der Server
	  - prüft, ob der Kämpfer handeln darf (lebt, nicht betäubt, Abklingzeit vorbei),
	  - wartet die Ausholzeit ab,
	  - legt die Trefferzone aus SEINER Sicht vor den Kämpfer,
	  - verteilt Schaden, Betäubung und Rückstoß.
	Werte kommen ausschließlich aus Config/Battlegrounds.

	Rückstoß und Vorwärtssprung: Die Bewegung eines Spieler-Charakters berechnet in
	Roblox dessen eigener Client. Deshalb schickt der Server dem betroffenen
	Client die Geschwindigkeit ("Battle.Push"), und der setzt sie um. Puppen ohne
	Spieler schiebt der Server direkt.

	Zustand für Clients: Player-Attribute BattleCharacter, BattleUlt, BattleBlocking,
	StunnedUntil (Serverzeit). Abklingzeiten kommen über "Battle.Cooldown".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local CombatMath = require(Shared.Battlegrounds.CombatMath)
local Config = require(Shared.Config.Battlegrounds)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

type State = {
	Character: string,
	Ready: { [number]: number }, -- Slot -> Zeitpunkt, ab dem er wieder geht (0 = Grundschlag, 1-3, 4 = Ulti)
	ComboStep: number,
	LastBasic: number,
	Blocking: boolean,
	Ult: number,
	Busy: number, -- bis wann der Kämpfer ausholt (verhindert Überlagern)
}

type LastHit = { Attacker: Player, Time: number }

local ULT_SLOT = 4
local TOLERANCE = 0.05
local EFFECT_RANGE = 160

local AbilityService = {
	Killed = Signal.new() :: Signal.Signal<Player, Humanoid>,
}

local states: { [Player]: State } = {}
local lastHits: { [Humanoid]: LastHit } = {}

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function parts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

local function isStunned(player: Player): boolean
	local untilTime = player:GetAttribute("StunnedUntil")
	return type(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

local function setUlt(player: Player, state: State, value: number)
	state.Ult = value
	player:SetAttribute("BattleUlt", math.floor(value))
end

local function applyWalkSpeed(player: Player)
	local state = states[player]
	local _character, humanoid = parts(player)
	if not state or not humanoid then
		return
	end
	if isStunned(player) then
		humanoid.WalkSpeed = 0
	elseif state.Blocking then
		humanoid.WalkSpeed = Config.Block.WalkSpeed
	else
		humanoid.WalkSpeed = Config.Characters[state.Character].WalkSpeed
	end
end

local function stun(player: Player, seconds: number)
	local untilTime = Workspace:GetServerTimeNow() + seconds
	local current = player:GetAttribute("StunnedUntil")
	if type(current) == "number" and current > untilTime then
		return -- eine längere Betäubung läuft schon
	end
	player:SetAttribute("StunnedUntil", untilTime)
	applyWalkSpeed(player)
	task.delay(seconds + 0.02, applyWalkSpeed, player)
end

local function watchDeath(humanoid: Humanoid)
	if humanoid:GetAttribute("BattleWatched") then
		return
	end
	humanoid:SetAttribute("BattleWatched", true)
	humanoid.Destroying:Once(function()
		lastHits[humanoid] = nil
	end)
	humanoid.Died:Once(function()
		local hit = lastHits[humanoid]
		lastHits[humanoid] = nil
		local model = humanoid.Parent
		local victim = if model then Players:GetPlayerFromCharacter(model) else nil
		if victim then
			DataService:Increment(victim, "Battle.Deaths", 1)
		end
		if hit and os.clock() - hit.Time <= Config.KillCreditSeconds and hit.Attacker.Parent == Players then
			DataService:Increment(hit.Attacker, "Battle.Kills", 1)
			AbilityService.Killed:Fire(hit.Attacker, humanoid)
			Net.FireAll(
				"Notify",
				`{hit.Attacker.DisplayName} hat {if victim then victim.DisplayName else "eine Puppe"} besiegt`,
				"Info",
				3
			)
		end
	end)
end

------------------------------------------------------------------------------
-- Treffer
------------------------------------------------------------------------------

local function resolveHit(attacker: Player, attack: Config.Attack, knockback: number, stunTime: number)
	local state = states[attacker]
	local character, _humanoid, root = parts(attacker)
	if not state or not character or not root or isStunned(attacker) then
		return -- wurde der Angreifer beim Ausholen betäubt, verpufft der Angriff
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local center = root.CFrame * CFrame.new(0, 0, -attack.Reach)
	local struck: { [Model]: boolean } = {}

	for _, part in Workspace:GetPartBoundsInBox(center, attack.Size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local victimRoot = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if not model or struck[model] or not humanoid or humanoid.Health <= 0 then
			continue
		end
		if not victimRoot or not victimRoot:IsA("BasePart") then
			continue
		end
		struck[model] = true

		local victim = Players:GetPlayerFromCharacter(model)
		local victimState = if victim then states[victim] else nil
		local toAttacker = root.Position - victimRoot.Position
		local facing = if toAttacker.Magnitude > 0.1 then victimRoot.CFrame.LookVector:Dot(toAttacker.Unit) else 1
		local damage, blocked = CombatMath.ApplyBlock(
			attack.Damage,
			victimState ~= nil and victimState.Blocking,
			facing,
			Config.Block.Reduction
		)

		watchDeath(humanoid)
		lastHits[humanoid] = { Attacker = attacker, Time = os.clock() }
		humanoid:TakeDamage(damage) -- beachtet Spawn-Schutz und Admin-Gott-Modus

		local ult = Config.Ultimate
		setUlt(attacker, state, CombatMath.GainUltimate(state.Ult, damage, ult.PerDamageDealt, ult.Max))
		if victim and victimState then
			setUlt(victim, victimState, CombatMath.GainUltimate(victimState.Ult, damage, ult.PerDamageTaken, ult.Max))
		end

		if not blocked then
			local away = Vector3.new(-toAttacker.X, 0, -toAttacker.Z)
			local push = if away.Magnitude > 0.1
				then away.Unit * knockback + Vector3.new(0, knockback * 0.35, 0)
				else Vector3.zero
			if victim then
				if stunTime > 0 then
					stun(victim, stunTime)
				end
				if knockback > 0 then
					Net.Fire("Battle.Push", victim, push)
				end
			elseif knockback > 0 then
				victimRoot.AssemblyLinearVelocity = push
			end
		end
		Net.FireNear(
			"Battle.Hit",
			victimRoot.Position,
			EFFECT_RANGE,
			victimRoot.Position,
			math.floor(damage + 0.5),
			blocked
		)
	end
end

local function canAct(player: Player, state: State, slot: number, now: number): boolean
	local _character, humanoid = parts(player)
	return humanoid ~= nil
		and not state.Blocking
		and not isStunned(player)
		and now >= (state.Ready[slot] or 0) - TOLERANCE
		and now >= state.Busy - TOLERANCE
end

local function perform(
	player: Player,
	state: State,
	slot: number,
	attack: Config.Attack,
	knockback: number,
	stunTime: number
)
	local now = os.clock()
	local _character, _humanoid, root = parts(player)
	if not root then
		return
	end
	state.Ready[slot] = now + attack.Cooldown
	state.Busy = now + attack.Windup
	Net.Fire("Battle.Cooldown", player, slot, attack.Cooldown)
	-- Alle in der Nähe sehen das Ausholen (Armbewegung und Zonen-Vorschau macht jeder Client selbst).
	Net.FireNear("Battle.Cast", root.Position, EFFECT_RANGE, player, slot)
	if attack.Dash then
		Net.Fire("Battle.Push", player, root.CFrame.LookVector * attack.Dash)
	end
	task.delay(attack.Windup, resolveHit, player, attack, knockback, stunTime)
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

local function onBasic(player: Player)
	local state = states[player]
	local now = os.clock()
	if not state or not canAct(player, state, 0, now) then
		return
	end
	local character = Config.Characters[state.Character]
	state.ComboStep =
		CombatMath.NextComboStep(state.ComboStep, now - state.LastBasic, Config.ComboWindow, character.ComboCount)
	state.LastBasic = now
	-- Der letzte Schlag der Kombo stößt weg und betäubt länger.
	local finisher = state.ComboStep == character.ComboCount
	perform(
		player,
		state,
		0,
		character.Basic,
		if finisher then Config.FinisherKnockback else character.Basic.Knockback,
		if finisher then Config.FinisherStun else character.Basic.Stun
	)
end

local function onAbility(player: Player, slot: number)
	local state = states[player]
	local now = os.clock()
	if not state or not canAct(player, state, slot, now) then
		return
	end
	local character = Config.Characters[state.Character]
	if slot == ULT_SLOT then
		if state.Ult < Config.Ultimate.Max then
			return
		end
		setUlt(player, state, 0)
		perform(player, state, slot, character.Ultimate, character.Ultimate.Knockback, character.Ultimate.Stun)
	else
		local attack = character.Abilities[slot]
		if attack then
			perform(player, state, slot, attack, attack.Knockback, attack.Stun)
		end
	end
end

local function onBlock(player: Player, blocking: boolean)
	local state = states[player]
	if not state or (blocking and isStunned(player)) then
		return
	end
	state.Blocking = blocking
	player:SetAttribute("BattleBlocking", blocking)
	applyWalkSpeed(player)
end

------------------------------------------------------------------------------
-- Kämpfer
------------------------------------------------------------------------------

local function applyCharacter(player: Player)
	local state = states[player]
	local _character, humanoid = parts(player)
	if not state or not humanoid then
		return
	end
	local definition = Config.Characters[state.Character]
	humanoid.MaxHealth = definition.Health
	humanoid.Health = definition.Health
	watchDeath(humanoid)
	applyWalkSpeed(player)
end

function AbilityService:SetCharacter(player: Player, characterId: string)
	local state = states[player]
	if not state or not Config.Characters[characterId] then
		return
	end
	state.Character = characterId
	state.Ready = {}
	player:SetAttribute("BattleCharacter", characterId)
	DataService:Set(player, "Battle.Character", characterId)
	applyCharacter(player)
end

function AbilityService:FillUltimate(player: Player)
	local state = states[player]
	if state then
		setUlt(player, state, Config.Ultimate.Max)
	end
end

------------------------------------------------------------------------------

function AbilityService:Init()
	for _, name in { "Battle.Cooldown", "Battle.Push" } do
		Net.Declare(name)
	end
	Net.Declare("Battle.Cast", { Unreliable = true })
	Net.Declare("Battle.Hit", { Unreliable = true })

	Net.On("Battle.Basic", {}, onBasic, { Rate = 8 })
	Net.On("Battle.Ability", { Check.integerRange(1, ULT_SLOT) }, onAbility, { Rate = 8 })
	Net.On("Battle.Block", { Check.boolean }, onBlock, { Rate = 10 })
	Net.On("Battle.Select", { Check.keyOf(Config.Characters) }, function(player: Player, characterId: string)
		AbilityService:SetCharacter(player, characterId)
	end, { Rate = 1 })
end

function AbilityService:Start()
	DataService:OnPlayerLoaded(function(player, data)
		local saved = data.Battle.Character
		local characterId = if Config.Characters[saved] then saved else Config.DefaultCharacter
		states[player] = {
			Character = characterId,
			Ready = {},
			ComboStep = 0,
			LastBasic = 0,
			Blocking = false,
			Ult = 0,
			Busy = 0,
		}
		player:SetAttribute("BattleCharacter", characterId)
		player:SetAttribute("BattleUlt", 0)
		applyCharacter(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			local state = states[player]
			if state then
				state.Blocking = false
				state.Ready = {}
				player:SetAttribute("BattleBlocking", false)
				player:SetAttribute("StunnedUntil", 0)
				applyCharacter(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return AbilityService
