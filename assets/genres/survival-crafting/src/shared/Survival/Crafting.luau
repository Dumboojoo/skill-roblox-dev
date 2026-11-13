--!strict
--[[
	Crafting – Rechenregeln für Herstellen und Bauen.

	Reines Luau (getestet in tests/Survival.spec.luau). Der Server benutzt diese
	Funktionen zum Entscheiden, der Client dieselben zum Anzeigen (Knopf an/aus).
	`items` ist immer eine Tabelle [GegenstandsId] = Anzahl.
]]

local Crafting = {}

-- Reichen die Gegenstände für diese Kosten?
function Crafting.CanAfford(items: { [string]: number }, cost: { [string]: number }): boolean
	for itemId, amount in cost do
		if (items[itemId] or 0) < amount then
			return false
		end
	end
	return true
end

-- Zieht die Kosten ab. Vorher mit CanAfford prüfen. Einträge mit 0 werden entfernt.
function Crafting.Pay(items: { [string]: number }, cost: { [string]: number })
	local bag = items :: { [string]: any } -- any, weil ein Eintrag auch gelöscht (nil) werden darf
	for itemId, amount in cost do
		local left = (bag[itemId] or 0) - amount
		bag[itemId] = if left > 0 then left else nil
	end
end

function Crafting.Add(items: { [string]: number }, itemId: string, amount: number)
	items[itemId] = (items[itemId] or 0) + amount
end

-- Anteil der Kosten zurückgeben (abgerundet), z. B. beim Abbauen.
function Crafting.Refund(cost: { [string]: number }, fraction: number): { [string]: number }
	local refund = {}
	for itemId, amount in cost do
		local back = math.floor(amount * fraction)
		if back > 0 then
			refund[itemId] = back
		end
	end
	return refund
end

-- Rastet einen Wert am Raster ein.
function Crafting.Snap(value: number, grid: number): number
	return math.floor(value / grid + 0.5) * grid
end

return Crafting
