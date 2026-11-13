--!strict
--[[
	Formulas – Stufen- und Schadensformeln des RPGs.

	Reines Luau (testbar, siehe tests/Rpg.spec.luau). Server und Client rechnen
	damit; der Client nur für die Anzeige des XP-Balkens.

	Gespeichert wird nur die GESAMTE XP. Die Stufe wird daraus berechnet. So bleibt
	alles stimmig, wenn die Kurve später geändert wird.
]]

local Formulas = {}

-- XP, die man braucht, um von `level` auf `level + 1` zu kommen.
function Formulas.XpForLevel(level: number, baseXp: number, exponent: number): number
	return math.floor(baseXp * level ^ exponent)
end

-- Rückgabe: Stufe, XP innerhalb der Stufe, XP bis zur nächsten Stufe.
function Formulas.LevelFromXp(
	totalXp: number,
	baseXp: number,
	exponent: number,
	maxLevel: number
): (number, number, number)
	local level = 1
	local remaining = math.max(0, totalXp)
	while level < maxLevel do
		local needed = Formulas.XpForLevel(level, baseXp, exponent)
		if remaining < needed then
			return level, remaining, needed
		end
		remaining -= needed
		level += 1
	end
	return maxLevel, 0, 0
end

function Formulas.MaxHealth(level: number, healthPerLevel: number): number
	return 100 + (level - 1) * healthPerLevel
end

-- Schaden eines Schlags: Grundwert, Stufenbonus und Kombo-Schritt (1 = erster Schlag).
function Formulas.AttackDamage(
	baseDamage: number,
	level: number,
	damagePerLevel: number,
	comboStep: number,
	comboBonus: number
): number
	local levelFactor = 1 + (level - 1) * damagePerLevel
	local comboFactor = 1 + (comboStep - 1) * comboBonus
	return math.floor(baseDamage * levelFactor * comboFactor + 0.5)
end

return Formulas
