--!strict
-- Spielstand-Abschnitt des Dungeon-Spiels.

return {
	Template = {
		Dungeon = {
			Clears = 0,
			BestTime = 0, -- Sekunden (0 = noch nie geschafft)
			Coins = 0,
			Loot = {}, -- [BeuteId] = Anzahl gefunden
		},
	},
	Leaderstats = {
		{ Name = "Siege", Path = "Dungeon.Clears" },
	},
}
