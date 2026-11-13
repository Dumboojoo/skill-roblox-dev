--!strict
--[[
	Logic – die Buchhaltung des Inventars, ohne Roblox-Dienste (getestet in
	tests/Inventar.spec.luau).

	Aufbau des Inventars im Spielstand:
	  Slots     Liste von { Uid = number, Id = string, Count = number }
	            Jeder Eintrag belegt einen Platz. Stapelbare Gegenstände teilen sich
	            Plätze bis MaxStack, nicht stapelbare haben Count = 1.
	  Equipped  [Ausrüstungsplatz] = Uid
	  NextUid   fortlaufende Nummer für neue Einträge

	Die Uid macht jeden Platz eindeutig ansprechbar ("rüste GENAU dieses Schwert
	aus"), auch wenn man mehrere gleiche besitzt. Das ist die Grundlage für
	späteres Verzaubern, Aufwerten oder Handeln einzelner Stücke.
]]

export type Slot = { Uid: number, Id: string, Count: number }
export type Inventory = { Slots: { Slot }, Equipped: { [string]: number }, NextUid: number }

local Logic = {}

function Logic.Count(inventory: Inventory, itemId: string): number
	local total = 0
	for _, slot in inventory.Slots do
		if slot.Id == itemId then
			total += slot.Count
		end
	end
	return total
end

function Logic.Find(inventory: Inventory, uid: number): (Slot?, number?)
	for index, slot in inventory.Slots do
		if slot.Uid == uid then
			return slot, index
		end
	end
	return nil, nil
end

-- Wie viele Stück von diesem Gegenstand noch hineinpassen.
function Logic.SpaceFor(inventory: Inventory, itemId: string, maxStack: number, capacity: number): number
	local space = (capacity - #inventory.Slots) * maxStack
	for _, slot in inventory.Slots do
		if slot.Id == itemId then
			space += maxStack - slot.Count
		end
	end
	return math.max(0, space)
end

-- Legt Gegenstände ab: erst angefangene Stapel auffüllen, dann neue Plätze belegen.
-- Gibt zurück, wie viele wirklich hineingepasst haben.
function Logic.Add(inventory: Inventory, itemId: string, count: number, maxStack: number, capacity: number): number
	local remaining = count
	for _, slot in inventory.Slots do
		if remaining <= 0 then
			break
		end
		if slot.Id == itemId and slot.Count < maxStack then
			local moved = math.min(remaining, maxStack - slot.Count)
			slot.Count += moved
			remaining -= moved
		end
	end
	while remaining > 0 and #inventory.Slots < capacity do
		local moved = math.min(remaining, maxStack)
		table.insert(inventory.Slots, { Uid = inventory.NextUid, Id = itemId, Count = moved })
		inventory.NextUid += 1
		remaining -= moved
	end
	return count - remaining
end

-- Löst die Ausrüstung, falls dieser Platz ausgerüstet war.
local function unequipUid(inventory: Inventory, uid: number)
	for equipSlot, equippedUid in inventory.Equipped do
		if equippedUid == uid then
			(inventory.Equipped :: { [string]: any })[equipSlot] = nil
		end
	end
end

-- Entfernt `count` Stück aus einem bestimmten Platz. false, wenn dort nicht genug liegt.
function Logic.RemoveFromSlot(inventory: Inventory, uid: number, count: number): boolean
	local slot, index = Logic.Find(inventory, uid)
	if not slot or not index or slot.Count < count then
		return false
	end
	slot.Count -= count
	if slot.Count <= 0 then
		table.remove(inventory.Slots, index)
		unequipUid(inventory, uid)
	end
	return true
end

-- Entfernt `count` Stück eines Gegenstands, egal aus welchen Plätzen. Alles oder nichts.
function Logic.Remove(inventory: Inventory, itemId: string, count: number): boolean
	if Logic.Count(inventory, itemId) < count then
		return false
	end
	local remaining = count
	-- Von hinten: zuletzt angelegte (meist unvollständige) Stapel zuerst leeren.
	for index = #inventory.Slots, 1, -1 do
		local slot = inventory.Slots[index]
		if slot.Id == itemId and remaining > 0 then
			local taken = math.min(remaining, slot.Count)
			slot.Count -= taken
			remaining -= taken
			if slot.Count <= 0 then
				table.remove(inventory.Slots, index)
				unequipUid(inventory, slot.Uid)
			end
		end
	end
	return true
end

return Logic
