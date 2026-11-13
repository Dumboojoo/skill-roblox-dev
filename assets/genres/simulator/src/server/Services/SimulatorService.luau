--!strict
--[[
	SimulatorService – Klicken, Sammeln, Upgrades, Pets, Zonen, Rebirth.

	Der Client bittet nur ("ich habe geklickt", "ich will Upgrade X"). Wie viel ein
	Klick wert ist, was etwas kostet und welches Pet aus dem Ei kommt, berechnet
	ausschließlich der Server aus dem Spielstand. Der Client schickt nie Beträge.

	Schutz gegen Autoklicker: Net begrenzt "Sim.Click" auf MaxClicksPerSecond.
	Mehr Klicks pro Sekunde werden einfach verworfen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.Simulator)
local Formulas = require(Shared.Simulator.Formulas)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

local SimulatorService = {}

local random = Random.new()

------------------------------------------------------------------------------
-- Rechnen
------------------------------------------------------------------------------

local function simData(player: Player): any
	return DataService:Get(player, "Simulator")
end

local function clickValue(data: any): number
	local multipliers = {}
	for _, uid in data.Equipped do
		for _, pet in data.Pets do
			if pet.Uid == uid then
				local definition = Config.Pets[pet.Id]
				if definition then
					table.insert(multipliers, definition.Multiplier)
				end
				break
			end
		end
	end
	return Formulas.ClickValue(
		data.Upgrades.ClickPower or 0,
		Formulas.PetMultiplier(multipliers),
		Formulas.RebirthMultiplier(data.Rebirths, Config.Rebirth.BonusPerRebirth)
	)
end

-- Einziger Weg, Münzen zu geben: hält Coins und TotalCoins zusammen.
function SimulatorService:AddCoins(player: Player, amount: number)
	if amount > 0 and DataService:IsLoaded(player) then
		DataService:Increment(player, "Simulator.Coins", amount)
		DataService:Increment(player, "Simulator.TotalCoins", amount)
	end
end

local function spend(player: Player, amount: number): boolean
	local data = simData(player)
	if not data or data.Coins < amount then
		Net.Fire("Notify", player, "Nicht genug Münzen.", "Error")
		return false
	end
	DataService:Increment(player, "Simulator.Coins", -amount)
	return true
end

------------------------------------------------------------------------------
-- Aktionen
------------------------------------------------------------------------------

local function onClick(player: Player)
	local data = simData(player)
	if data then
		SimulatorService:AddCoins(player, clickValue(data))
	end
end

local function onBuyUpgrade(player: Player, upgradeId: string)
	local data = simData(player)
	local upgrade = Config.Upgrades[upgradeId]
	if not data then
		return
	end
	local level = data.Upgrades[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		return
	end
	if spend(player, Formulas.UpgradeCost(upgrade.BaseCost, upgrade.Growth, level)) then
		DataService:Set(player, { "Simulator", "Upgrades", upgradeId }, level + 1)
	end
end

-- Rückgabe an den Client: Id des geschlüpften Pets oder nil.
local function onHatch(player: Player, eggId: string): string?
	local data = simData(player)
	local egg = Config.Eggs[eggId]
	if not data then
		return nil
	end
	if #data.Pets >= Config.MaxPets then
		Net.Fire("Notify", player, "Dein Pet-Lager ist voll.", "Error")
		return nil
	end
	if not spend(player, egg.Price) then
		return nil
	end
	local petId = Formulas.PickWeighted(egg.Pets, random:NextNumber())
	local uid = data.NextPetUid
	DataService:Set(player, "Simulator.NextPetUid", uid + 1)
	DataService:Update(player, "Simulator.Pets", function(pets)
		table.insert(pets, { Uid = uid, Id = petId })
		return pets
	end)
	-- Freie Plätze automatisch belegen, damit ein neues Pet sofort etwas bringt.
	if #data.Equipped < Config.MaxEquippedPets then
		DataService:Update(player, "Simulator.Equipped", function(equipped)
			table.insert(equipped, uid)
			return equipped
		end)
	end
	return petId
end

local function onEquip(player: Player, uid: number, equip: boolean)
	local data = simData(player)
	if not data then
		return
	end
	local owned = false
	for _, pet in data.Pets do
		if pet.Uid == uid then
			owned = true
			break
		end
	end
	local index = table.find(data.Equipped, uid)
	if equip and owned and not index and #data.Equipped < Config.MaxEquippedPets then
		DataService:Update(player, "Simulator.Equipped", function(equipped)
			table.insert(equipped, uid)
			return equipped
		end)
	elseif not equip and index then
		DataService:Update(player, "Simulator.Equipped", function(equipped)
			table.remove(equipped, table.find(equipped, uid) :: number)
			return equipped
		end)
	end
end

local function onDeletePet(player: Player, uid: number)
	local data = simData(player)
	if not data then
		return
	end
	onEquip(player, uid, false)
	DataService:Update(player, "Simulator.Pets", function(pets)
		for index, pet in pets do
			if pet.Uid == uid then
				table.remove(pets, index)
				break
			end
		end
		return pets
	end)
end

local function onBuyZone(player: Player, zoneId: string)
	local data = simData(player)
	local zone = Config.Zones[zoneId]
	if not data or data.Zones[zoneId] then
		return
	end
	if spend(player, zone.Price) then
		DataService:Set(player, { "Simulator", "Zones", zoneId }, true)
		Net.Fire("Notify", player, `Zone freigeschaltet: {zone.DisplayName}`, "Success")
	end
end

local function onRebirth(player: Player)
	local data = simData(player)
	if not data then
		return
	end
	local cost = Formulas.RebirthCost(Config.Rebirth.BaseCost, Config.Rebirth.Growth, data.Rebirths)
	if data.TotalCoins < cost then
		Net.Fire("Notify", player, "Du hast noch nicht genug Münzen verdient.", "Error")
		return
	end
	-- Rebirth setzt Münzen und Upgrades zurück; Pets und Zonen bleiben.
	DataService:Set(player, "Simulator.Coins", 0)
	DataService:Set(player, "Simulator.TotalCoins", 0)
	DataService:Set(player, "Simulator.Upgrades", {})
	DataService:Increment(player, "Simulator.Rebirths", 1)
	Net.Fire("Notify", player, `Rebirth {data.Rebirths}! Du verdienst jetzt dauerhaft mehr.`, "Announcement")
end

------------------------------------------------------------------------------
-- Welt
------------------------------------------------------------------------------

local function observeCollectible(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local originalTransparency = instance.Transparency
	local available = true

	local connection = instance.Touched:Connect(function(hit)
		if not available then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		local data = if player then simData(player) else nil
		if not player or not data then
			return
		end
		local zone = instance:GetAttribute("Zone")
		if type(zone) == "string" and not data.Zones[zone] then
			return
		end
		available = false
		local value = World.Attribute(instance, "Value", 1)
		-- Auch Sammelobjekte profitieren von Pets und Rebirths (Klick-Kraft zählt hier nicht).
		local multiplier = clickValue(data) / (1 + (data.Upgrades.ClickPower or 0))
		SimulatorService:AddCoins(player, math.floor(value * multiplier))
		instance.Transparency = 1
		instance.CanTouch = false
		task.wait(World.Attribute(instance, "Respawn", Config.CollectibleRespawn))
		instance.Transparency = originalTransparency
		instance.CanTouch = true
		available = true
	end)
	return function()
		connection:Disconnect()
	end
end

-- Kauf-Hinweis direkt an der Sperre (ProximityPrompt funktioniert auf jedem Gerät).
local function observeZoneGate(instance: Instance): (() -> ())?
	local zoneId = instance:GetAttribute("Zone")
	local zone = if type(zoneId) == "string" then Config.Zones[zoneId] else nil
	if not zone or not instance:IsA("BasePart") then
		warn(`[Simulator] ZoneGate {instance:GetFullName()}: Attribut Zone fehlt oder ist unbekannt.`)
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Freischalten ({zone.Price})`
	prompt.ObjectText = zone.DisplayName
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		onBuyZone(player, zoneId :: string)
	end)
	return function()
		prompt:Destroy()
	end
end

------------------------------------------------------------------------------

function SimulatorService:Init()
	Net.On("Sim.Click", {}, onClick, { Rate = Config.MaxClicksPerSecond, Burst = Config.MaxClicksPerSecond })
	Net.On("Sim.BuyUpgrade", { Check.keyOf(Config.Upgrades) }, onBuyUpgrade, { Rate = 10 })
	Net.OnInvoke("Sim.Hatch", { Check.keyOf(Config.Eggs) }, onHatch, { Rate = 4 })
	Net.On("Sim.EquipPet", { Check.integer, Check.boolean }, onEquip, { Rate = 10 })
	Net.On("Sim.DeletePet", { Check.integer }, onDeletePet, { Rate = 10 })
	Net.On("Sim.BuyZone", { Check.keyOf(Config.Zones) }, onBuyZone, { Rate = 4 })
	Net.On("Sim.Rebirth", {}, onRebirth, { Rate = 1 })
end

function SimulatorService:Start()
	World.Observe("Collectible", observeCollectible)
	World.Observe("ZoneGate", observeZoneGate)
end

return SimulatorService
