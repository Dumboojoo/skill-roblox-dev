--!strict
--[[
	Formulas – alle Rechenregeln des Simulators an einer Stelle.

	Reines Luau ohne Roblox-Dienste: Server und Client rechnen mit denselben
	Funktionen (der Client nur für die Anzeige), und tests/Simulator.spec.luau
	sichert sie ab. Balancing = diese Datei und Config/Simulator ändern.
]]

export type Weighted = { Id: string, Weight: number }

local Formulas = {}

-- Preis der nächsten Stufe eines Upgrades.
function Formulas.UpgradeCost(baseCost: number, growth: number, level: number): number
	return math.floor(baseCost * growth ^ level)
end

-- Pets addieren ihre Boni: 1.5 und 2.0 ergeben zusammen 2.5 (nicht 3.0).
-- Additiv bleibt die Wirtschaft beherrschbar; multiplikativ explodiert sie.
function Formulas.PetMultiplier(multipliers: { number }): number
	local total = 1
	for _, multiplier in multipliers do
		total += multiplier - 1
	end
	return total
end

function Formulas.RebirthMultiplier(rebirths: number, bonusPerRebirth: number): number
	return 1 + rebirths * bonusPerRebirth
end

-- Münzen pro Klick.
function Formulas.ClickValue(clickLevel: number, petMultiplier: number, rebirthMultiplier: number): number
	return math.floor((1 + clickLevel) * petMultiplier * rebirthMultiplier)
end

function Formulas.RebirthCost(baseCost: number, growth: number, rebirths: number): number
	return math.floor(baseCost * growth ^ rebirths)
end

-- Zieht einen Eintrag nach Gewicht. `roll` ist eine Zufallszahl in [0, 1).
function Formulas.PickWeighted(entries: { Weighted }, roll: number): string
	local total = 0
	for _, entry in entries do
		total += entry.Weight
	end
	local threshold = roll * total
	local running = 0
	for _, entry in entries do
		running += entry.Weight
		if threshold < running then
			return entry.Id
		end
	end
	return entries[#entries].Id
end

-- Chance jedes Eintrags als Anteil (0 bis 1), für die Anzeige im Eier-Menü.
function Formulas.Odds(entries: { Weighted }): { [string]: number }
	local total = 0
	for _, entry in entries do
		total += entry.Weight
	end
	local odds = {}
	for _, entry in entries do
		odds[entry.Id] = if total > 0 then entry.Weight / total else 0
	end
	return odds
end

return Formulas
