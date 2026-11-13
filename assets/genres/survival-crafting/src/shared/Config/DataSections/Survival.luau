--!strict
-- Spielstand-Abschnitt des Survival-Spiels.

return {
	Template = {
		Survival = {
			Hunger = 100,
			Thirst = 100,
			Items = {}, -- [GegenstandsId] = Anzahl
			-- Gebaute Teile als Liste von { Id = string, X = number, Y = number, Z = number, R = number }
			-- (R = Drehung in Vierteldrehungen). Positionen als Zahlen, weil sich Vector3 nicht speichern lässt.
			Base = {},
		},
	},
}
