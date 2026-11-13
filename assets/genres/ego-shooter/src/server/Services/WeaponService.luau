--!strict
--[[
	WeaponService – der Server entscheidet über Munition, Feuerrate und Schaden.

	Ablauf eines Schusses:
	  1. Der Client schießt sofort (Leuchtspur, Rückstoß) und meldet: Startpunkt,
	     Richtung und was er getroffen haben will (Teil + Position).
	  2. Der Server prüft alles, was sich prüfen lässt:
	       - lebt der Schütze, hat er die Waffe, hat er Munition?
	       - ist die Feuerrate eingehalten?
	       - liegt der Startpunkt nah am Kopf des Schützen?
	       - liegt der Treffer in Reichweite und in Schussrichtung?
	       - ist das getroffene Teil wirklich ungefähr dort?
	       - ist zwischen Start und Treffer keine Wand?
	  3. Erst dann gibt es Schaden.

	Warum meldet der Client den Treffer, statt dass der Server selbst schießt?
	Wegen der Verzögerung sieht der Schütze Gegner dort, wo sie vor ~100 ms waren.
	Würde der Server mit den aktuellen Positionen schießen, gingen saubere Treffer
	daneben. So fühlt es sich für den Schützen richtig an, und die Prüfungen halten
	Schummler in engen Grenzen (kein Schießen durch Wände, quer über die Karte
	oder schneller als die Waffe erlaubt).

	Zustand für den Client: Net "Weapon.State" (nur bei Wechsel, Nachladen, Respawn).
	Andere Spieler bekommen "Weapon.Effect" für Leuchtspur und Knall.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local WeaponModel = require(Shared.Shooter.WeaponModel)
local Weapons = require(Shared.Config.Weapons)
local DataService = require(script.Parent.DataService)

type State = {
	Slot: number,
	WeaponId: string,
	Ammo: { [string]: number },
	Reserve: { [string]: number },
	Tokens: number, -- Feuerraten-Guthaben
	LastRefill: number,
	ReloadToken: number, -- macht ein laufendes Nachladen ungültig (Waffenwechsel, Tod)
	Reloading: boolean,
	InfiniteAmmo: boolean,
	HeldModel: Model?,
	HoldTrack: AnimationTrack?,
}

type LastHit = { Attacker: Player, WeaponId: string, Headshot: boolean, Time: number }

-- Toleranzen der Prüfung. Großzügiger = fairer bei schlechter Verbindung, enger = sicherer.
local MAX_ORIGIN_DISTANCE = 12 -- Studs zwischen gemeldetem Startpunkt und Kopf
local MAX_TARGET_DRIFT = 6 -- Studs, die sich ein Ziel seit dem Schuss bewegt haben darf
local EXTRA_ANGLE = 4 -- Grad über der Streuung der Waffe
local EXTRA_RANGE = 5
local FIRE_BURST = 3 -- so viele Schüsse dürfen „auf einmal" ankommen (Ruckler)
local FIRE_RATE_SLACK = 1.1
local KILL_CREDIT_SECONDS = 12
local MAX_HITS_PER_SHOT = 12

local WeaponService = {
	-- (Täter, Opfer-Humanoid, WaffenId, Kopfschuss) – für Rundenlogik, Quests, Statistik
	Killed = Signal.new() :: Signal.Signal<Player, Humanoid, string, boolean>,
}

local states: { [Player]: State } = {}
local lastHits: { [Humanoid]: LastHit } = {}

------------------------------------------------------------------------------
-- Zustand
------------------------------------------------------------------------------

local function sendState(player: Player, reloadDuration: number?)
	local state = states[player]
	if not state then
		return
	end
	Net.Fire("Weapon.State", player, {
		Slot = state.Slot,
		WeaponId = state.WeaponId,
		Ammo = state.Ammo[state.WeaponId],
		Reserve = state.Reserve[state.WeaponId],
		ReloadDuration = reloadDuration,
		Loadout = Weapons.Loadout,
	})
end

local function fullAmmo(): ({ [string]: number }, { [string]: number })
	local ammo, reserve = {}, {}
	for id, weapon in Weapons.List do
		ammo[id] = weapon.MagazineSize
		reserve[id] = weapon.ReserveAmmo
	end
	return ammo, reserve
end

-- Waffe in die Hand des Charakters, damit andere Spieler sie sehen.
local function showHeldWeapon(player: Player, state: State)
	if state.HeldModel then
		state.HeldModel:Destroy()
		state.HeldModel = nil
	end
	if state.HoldTrack then
		state.HoldTrack:Stop()
		state.HoldTrack = nil
	end

	local character = player.Character
	if not character then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hand or not hand:IsA("BasePart") or not humanoid then
		return
	end

	local model = WeaponModel.Build(state.WeaponId, false)
	local root = model.PrimaryPart :: BasePart
	local grip = hand:FindFirstChild("RightGripAttachment")
	local gripCFrame = if grip and grip:IsA("Attachment") then grip.WorldCFrame else hand.CFrame
	-- Die Waffe zeigt im Waffenraum nach -Z; in der Hand soll sie nach vorn zeigen.
	model:PivotTo(gripCFrame * CFrame.Angles(math.rad(-90), 0, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = root
	weld.Parent = root
	model.Parent = character
	state.HeldModel = model

	-- Halte-Pose: die Standard-Animation von Roblox für „Werkzeug in der Hand" (Arm nach vorn).
	-- Sie wird aus dem Animate-Skript des Charakters gelesen, es ist keine eigene Animation nötig.
	local animate = character:FindFirstChild("Animate")
	local toolNone = if animate then animate:FindFirstChild("toolnone") else nil
	local animation = if toolNone then toolNone:FindFirstChildOfClass("Animation") else nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animation and animator then
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.1)
		state.HoldTrack = track
	end
end

local function equipSlot(player: Player, slot: number)
	local state = states[player]
	local weaponId = Weapons.Loadout[slot]
	if not state or not weaponId then
		return
	end
	state.Slot = slot
	state.WeaponId = weaponId
	state.Reloading = false
	state.ReloadToken += 1
	state.Tokens = 1
	state.LastRefill = os.clock()
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = Weapons.List[weaponId].WalkSpeed
	end
	showHeldWeapon(player, state)
	sendState(player)
end

------------------------------------------------------------------------------
-- Schaden
------------------------------------------------------------------------------

local function damageFor(weapon: Weapons.Weapon, part: BasePart): (number, boolean)
	local name = part.Name
	if name == "Head" then
		return weapon.Damage * weapon.HeadshotMultiplier, true
	end
	if
		string.find(name, "Arm")
		or string.find(name, "Leg")
		or string.find(name, "Hand")
		or string.find(name, "Foot")
	then
		return weapon.Damage * weapon.LimbMultiplier, false
	end
	return weapon.Damage, false
end

local function sameTeam(a: Player, b: Player): boolean
	return a.Team ~= nil and a.Team == b.Team and not a.Neutral and not b.Neutral
end

local function watchDeath(humanoid: Humanoid)
	if humanoid:GetAttribute("ShooterWatched") then
		return
	end
	humanoid:SetAttribute("ShooterWatched", true)
	humanoid.Destroying:Once(function()
		lastHits[humanoid] = nil
	end)
	humanoid.Died:Once(function()
		local hit = lastHits[humanoid]
		lastHits[humanoid] = nil
		local character = humanoid.Parent
		local victim = if character then Players:GetPlayerFromCharacter(character) else nil
		if victim then
			DataService:Increment(victim, "Shooter.Deaths", 1)
		end
		if not hit or os.clock() - hit.Time > KILL_CREDIT_SECONDS or hit.Attacker.Parent ~= Players then
			return
		end
		DataService:Increment(hit.Attacker, "Shooter.Kills", 1)
		if hit.Headshot then
			DataService:Increment(hit.Attacker, "Shooter.Headshots", 1)
		end
		local victimName = if victim then victim.DisplayName elseif character then character.Name else "?"
		Net.FireAll("Weapon.Kill", hit.Attacker.DisplayName, victimName, hit.WeaponId, hit.Headshot)
		WeaponService.Killed:Fire(hit.Attacker, humanoid, hit.WeaponId, hit.Headshot)
	end)
end

-- Welt-Raycast, der alle Charaktere ignoriert: Steht eine Wand zwischen Start und Ziel?
local function hasLineOfSight(origin: Vector3, target: Vector3): boolean
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local offset = target - origin
	local distance = offset.Magnitude
	if distance < 1 then
		return true
	end
	-- Kurz vor dem Ziel aufhören, damit die Oberfläche des Ziels selbst nicht als Wand zählt.
	local result = Workspace:Raycast(origin, offset.Unit * (distance - 1), params)
	if not result then
		return true
	end
	-- Getroffen wurde etwas mit Humanoid (z. B. Trainingspuppe): zählt nicht als Wand.
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function validateHit(
	shooter: Player,
	weapon: Weapons.Weapon,
	origin: Vector3,
	direction: Vector3,
	part: BasePart,
	position: Vector3
): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid or humanoid.Health <= 0 or model == shooter.Character then
		return nil
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim and not Weapons.FriendlyFire and sameTeam(shooter, victim) then
		return nil
	end

	local offset = position - origin
	local distance = offset.Magnitude
	if distance > weapon.Range + EXTRA_RANGE then
		return nil
	end
	-- Liegt der Treffer in Schussrichtung (innerhalb der Streuung)?
	if distance > 2 then
		local angle = math.deg(math.acos(math.clamp(offset.Unit:Dot(direction), -1, 1)))
		if angle > math.max(weapon.Spread, weapon.AimSpread) + EXTRA_ANGLE then
			return nil
		end
	end
	-- Ist das Teil wirklich ungefähr dort, wo der Client es getroffen haben will?
	if (part.Position - position).Magnitude > part.Size.Magnitude / 2 + MAX_TARGET_DRIFT then
		return nil
	end
	if not hasLineOfSight(origin, position) then
		return nil
	end
	return humanoid
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

local function isHitEntry(value: any): boolean
	return type(value) == "table"
		and typeof(value[1]) == "Instance"
		and value[1]:IsA("BasePart")
		and Check.Vector3(value[2])
end

local function onFire(player: Player, origin: Vector3, direction: Vector3, hits: { { any } })
	local state = states[player]
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if not state or not humanoid or humanoid.Health <= 0 or not head or not head:IsA("BasePart") then
		return
	end
	if state.Reloading then
		return
	end
	local weapon = Weapons.List[state.WeaponId]

	-- Feuerrate: Guthaben wächst mit der Rate der Waffe nach, ein Schuss kostet 1.
	local now = os.clock()
	local perSecond = weapon.FireRate / 60 * FIRE_RATE_SLACK
	state.Tokens = math.min(FIRE_BURST, state.Tokens + (now - state.LastRefill) * perSecond)
	state.LastRefill = now
	if state.Tokens < 1 then
		return
	end

	if not state.InfiniteAmmo then
		local ammo = state.Ammo[state.WeaponId]
		if ammo <= 0 then
			sendState(player) -- Client hat sich verzählt: richtigstellen
			return
		end
		state.Ammo[state.WeaponId] = ammo - 1
	end
	state.Tokens -= 1

	if (origin - head.Position).Magnitude > MAX_ORIGIN_DISTANCE then
		return
	end
	if math.abs(direction.Magnitude - 1) > 0.01 then
		return
	end

	local endPosition = origin + direction * weapon.Range
	for index, hit in hits do
		if index > weapon.Pellets or index > MAX_HITS_PER_SHOT then
			break
		end
		local part = hit[1] :: BasePart
		local position = hit[2] :: Vector3
		local victimHumanoid = validateHit(player, weapon, origin, direction, part, position)
		if victimHumanoid then
			local damage, headshot = damageFor(weapon, part)
			watchDeath(victimHumanoid)
			lastHits[victimHumanoid] = { Attacker = player, WeaponId = state.WeaponId, Headshot = headshot, Time = now }
			-- TakeDamage beachtet Kraftfelder (Spawn-Schutz, Admin-Gott-Modus).
			victimHumanoid:TakeDamage(damage)
			Net.Fire("Weapon.HitConfirm", player, headshot, victimHumanoid.Health <= 0)
			endPosition = position
		end
	end

	Net.FireExcept("Weapon.Effect", player, player, origin, endPosition, state.WeaponId)
end

local function onReload(player: Player)
	local state = states[player]
	if not state or state.Reloading then
		return
	end
	local weaponId = state.WeaponId
	local weapon = Weapons.List[weaponId]
	local missing = weapon.MagazineSize - state.Ammo[weaponId]
	if missing <= 0 or state.Reserve[weaponId] <= 0 then
		return
	end

	state.Reloading = true
	state.ReloadToken += 1
	local token = state.ReloadToken
	sendState(player, weapon.ReloadTime)

	task.delay(weapon.ReloadTime, function()
		-- Abbrechen, wenn inzwischen gewechselt, gestorben oder der Spieler gegangen ist.
		if states[player] ~= state or state.ReloadToken ~= token then
			return
		end
		local amount = math.min(weapon.MagazineSize - state.Ammo[weaponId], state.Reserve[weaponId])
		state.Ammo[weaponId] += amount
		if not state.InfiniteAmmo then
			state.Reserve[weaponId] -= amount
		end
		state.Reloading = false
		sendState(player)
	end)
end

------------------------------------------------------------------------------
-- Für andere Services und Admin-Befehle
------------------------------------------------------------------------------

function WeaponService:RefillAmmo(player: Player)
	local state = states[player]
	if state then
		state.Ammo, state.Reserve = fullAmmo()
		sendState(player)
	end
end

function WeaponService:SetInfiniteAmmo(player: Player, enabled: boolean?): boolean
	local state = states[player]
	if not state then
		return false
	end
	state.InfiniteAmmo = if enabled == nil then not state.InfiniteAmmo else enabled
	return state.InfiniteAmmo
end

------------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------------

local function onCharacter(player: Player, character: Model)
	local state = states[player]
	if not state then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	watchDeath(humanoid)
	state.Ammo, state.Reserve = fullAmmo()
	state.HeldModel = nil
	state.HoldTrack = nil
	-- Aussehen fertig laden lassen, sonst fehlt die Hand zum Anschweißen.
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if player.Character == character then
		equipSlot(player, 1)
	end
end

local function onPlayer(player: Player)
	local ammo, reserve = fullAmmo()
	states[player] = {
		Slot = 1,
		WeaponId = Weapons.Loadout[1],
		Ammo = ammo,
		Reserve = reserve,
		Tokens = 1,
		LastRefill = os.clock(),
		ReloadToken = 0,
		Reloading = false,
		InfiniteAmmo = false,
		HeldModel = nil,
		HoldTrack = nil,
	}
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function WeaponService:Init()
	Net.Declare("Weapon.State")
	Net.Declare("Weapon.Kill")
	Net.Declare("Weapon.HitConfirm")
	Net.Declare("Weapon.Effect", { Unreliable = true })

	Net.On(
		"Weapon.Fire",
		{ Check.Vector3, Check.Vector3, Check.arrayOf(isHitEntry, MAX_HITS_PER_SHOT) },
		onFire,
		{ Rate = 25, Burst = 40 }
	)
	Net.On("Weapon.Reload", {}, onReload, { Rate = 4 })
	Net.On("Weapon.Equip", { Check.integerRange(1, #Weapons.Loadout) }, function(player: Player, slot: number)
		local state = states[player]
		if state and state.Slot ~= slot then
			equipSlot(player, slot)
		end
	end, { Rate = 6 })
	-- Client bittet nach dem Start um den aktuellen Zustand.
	Net.On("Weapon.RequestState", {}, function(player: Player)
		sendState(player)
	end, { Rate = 2 })
end

function WeaponService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return WeaponService
