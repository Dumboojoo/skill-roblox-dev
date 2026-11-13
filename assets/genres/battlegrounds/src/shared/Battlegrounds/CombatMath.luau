--!strict
--[[
	CombatMath – die Rechenregeln des Kampfes, ohne Roblox-Dienste (testbar).

	Zahlen statt Vektoren als Eingabe, damit die Tests außerhalb von Studio laufen:
	`facing` ist das Skalarprodukt aus Blickrichtung des Opfers und Richtung zum
	Angreifer (1 = schaut ihn direkt an, -1 = Rücken zugewandt).
]]

local CombatMath = {}

-- Ab diesem Wert gilt ein Angriff als „von vorn" und kann geblockt werden.
CombatMath.BlockFacing = 0.25

-- Rückgabe: Schaden nach Block und ob geblockt wurde.
function CombatMath.ApplyBlock(damage: number, blocking: boolean, facing: number, reduction: number): (number, boolean)
	if blocking and facing >= CombatMath.BlockFacing then
		return damage * (1 - reduction), true
	end
	return damage, false
end

-- Nächster Kombo-Schritt: zählt weiter, wenn schnell genug nachgeschlagen wird, sonst von vorn.
function CombatMath.NextComboStep(step: number, sinceLast: number, window: number, count: number): number
	if sinceLast <= window and step < count then
		return step + 1
	end
	return 1
end

-- Neuer Stand der Ulti-Leiste nach ausgeteiltem oder erlittenem Schaden.
function CombatMath.GainUltimate(current: number, damage: number, perDamage: number, max: number): number
	return math.clamp(current + damage * perDamage, 0, max)
end

return CombatMath
