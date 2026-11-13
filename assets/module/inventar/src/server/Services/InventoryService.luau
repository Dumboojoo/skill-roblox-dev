--!strict
--[[
	InventoryService – verwaltet die Inventare aller Spieler auf dem Server.

	Für andere Services (Beute, Händler, Quests, Herstellen):
	  InventoryService:Give(player, "IronOre", 5)      -> wie viele hineingepasst haben
	  InventoryService:Take(player, "IronOre", 3)      -> true/false (alles oder nichts)
	  InventoryService:Count(player, "IronOre")
	  InventoryService:GetEquipped(player, "Weapon")   -> Item-Id oder nil

	Signale, an die sich das Spiel hängt:
	  Equipped(player, equipSlot, itemId?)   Ausrüstung hat sich geändert (nil = abgelegt)
	  Used(player, itemId)                   ein Verbrauchsgegenstand wurde benutzt
	                                         (ein Stück ist dann schon abgezogen)

	Beispiel: Heiltrank wirken lassen
	  InventoryService.Used:Connect(function(player, itemId)
	      if itemId == "HealthPotion" then ... Humanoid heilen ... end
	  end)

	Der Client schickt nur Uids ("rüste Platz 17 aus"). Was dort liegt und ob das
	erlaubt ist, schaut der Server selbst im Spielstand nach.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Items = require(Shared.Config.Items)
local Logic = require(Shared.Inventory.Logic)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

local InventoryService = {
	Equipped = Signal.new() :: Signal.Signal<Player, string, string?>,
	Used = Signal.new() :: Signal.Signal<Player, string>,
}

-- Führt `change` auf dem Inventar aus und schickt das Ergebnis an den Client.
local function mutate<T>(player: Player, change: (inventory: Logic.Inventory) -> T): T?
	local result: T? = nil
	local ok = DataService:Update(player, "Inventory", function(inventory)
		result = change(inventory)
		return inventory
	end)
	return if ok then result else nil
end

local function inventoryOf(player: Player): Logic.Inventory?
	return DataService:Get(player, "Inventory")
end

------------------------------------------------------------------------------
-- Für andere Services
------------------------------------------------------------------------------

function InventoryService:Give(player: Player, itemId: string, count: number?): number
	local item = Items.List[itemId]
	if not item then
		warn(`[Inventar] Unbekannter Gegenstand "{itemId}".`)
		return 0
	end
	local amount = count or 1
	local added = mutate(player, function(inventory)
		return Logic.Add(inventory, itemId, amount, item.MaxStack, Items.Capacity)
	end) or 0
	if added < amount then
		Net.Fire("Notify", player, "Dein Inventar ist voll.", "Error")
	end
	return added
end

function InventoryService:Take(player: Player, itemId: string, count: number?): boolean
	local before = InventoryService:GetAllEquipped(player)
	local removed = mutate(player, function(inventory)
		return Logic.Remove(inventory, itemId, count or 1)
	end) == true
	if removed then
		InventoryService:_announceUnequipped(player, before)
	end
	return removed
end

function InventoryService:Count(player: Player, itemId: string): number
	local inventory = inventoryOf(player)
	return if inventory then Logic.Count(inventory, itemId) else 0
end

function InventoryService:HasSpace(player: Player, itemId: string, count: number): boolean
	local inventory = inventoryOf(player)
	local item = Items.List[itemId]
	return inventory ~= nil
		and item ~= nil
		and Logic.SpaceFor(inventory, itemId, item.MaxStack, Items.Capacity) >= count
end

function InventoryService:GetEquipped(player: Player, equipSlot: string): string?
	local inventory = inventoryOf(player)
	local uid = if inventory then inventory.Equipped[equipSlot] else nil
	local slot = if inventory and uid then Logic.Find(inventory, uid) else nil
	return if slot then slot.Id else nil
end

function InventoryService:GetAllEquipped(player: Player): { [string]: string }
	local result = {}
	for equipSlot in Items.EquipSlots do
		local itemId = InventoryService:GetEquipped(player, equipSlot)
		if itemId then
			result[equipSlot] = itemId
		end
	end
	return result
end

-- Meldet Plätze, die durch Entfernen eines Gegenstands leer geworden sind.
function InventoryService:_announceUnequipped(player: Player, before: { [string]: string })
	for equipSlot in before do
		if not InventoryService:GetEquipped(player, equipSlot) then
			InventoryService.Equipped:Fire(player, equipSlot, nil)
		end
	end
end

------------------------------------------------------------------------------
-- Aktionen des Spielers
------------------------------------------------------------------------------

local function onEquip(player: Player, uid: number)
	local inventory = inventoryOf(player)
	local slot = if inventory then Logic.Find(inventory, uid) else nil
	local item = if slot then Items.List[slot.Id] else nil
	local equipSlot = if item then item.EquipSlot else nil
	if not inventory or not slot or not equipSlot then
		return
	end
	-- Schon ausgerüstet: ablegen. Sonst: anlegen (ersetzt, was vorher dort war).
	local unequip = inventory.Equipped[equipSlot] == uid
	DataService:Set(player, { "Inventory", "Equipped", equipSlot }, if unequip then nil else uid)
	InventoryService.Equipped:Fire(player, equipSlot, if unequip then nil else slot.Id)
end

local function onUse(player: Player, uid: number)
	local inventory = inventoryOf(player)
	local slot = if inventory then Logic.Find(inventory, uid) else nil
	local item = if slot then Items.List[slot.Id] else nil
	if not slot or not item or not item.Usable then
		return
	end
	local itemId = slot.Id
	local removed = mutate(player, function(target)
		return Logic.RemoveFromSlot(target, uid, 1)
	end)
	if removed then
		InventoryService.Used:Fire(player, itemId)
	end
end

local function onDiscard(player: Player, uid: number, count: number)
	local before = InventoryService:GetAllEquipped(player)
	local removed = mutate(player, function(inventory)
		return Logic.RemoveFromSlot(inventory, uid, count)
	end)
	if removed then
		InventoryService:_announceUnequipped(player, before)
	end
end

------------------------------------------------------------------------------

function InventoryService:Init()
	Net.On("Inventory.Equip", { Check.integer }, onEquip, { Rate = 8 })
	Net.On("Inventory.Use", { Check.integer }, onUse, { Rate = 6 })
	Net.On("Inventory.Discard", { Check.integer, Check.integerRange(1, 9999) }, onDiscard, { Rate = 6 })
end

function InventoryService:Start()
	-- Beim Laden melden, was ausgerüstet ist, damit Waffen-/Werte-Systeme es anwenden können.
	DataService:OnPlayerLoaded(function(player)
		for equipSlot, itemId in InventoryService:GetAllEquipped(player) do
			InventoryService.Equipped:Fire(player, equipSlot, itemId)
		end
	end)
	-- Nach jedem Erscheinen erneut: Ausrüstung hängt meist am Charakter.
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if DataService:WaitForData(player) then
				for equipSlot, itemId in InventoryService:GetAllEquipped(player) do
					InventoryService.Equipped:Fire(player, equipSlot, itemId)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return InventoryService
