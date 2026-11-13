--!strict
-- Spielstand-Abschnitt des RPGs.

return {
	Template = {
		Rpg = {
			Xp = 0, -- gesamte XP; die Stufe wird daraus berechnet
			Level = 1, -- nur für Anzeige/Rangliste, wird vom ProgressService gepflegt
			Coins = 0,
			Kills = 0,
			Quests = {
				Active = {}, -- [QuestId] = Fortschritt
				Done = {}, -- [QuestId] = true
			},
		},
	},
	Leaderstats = {
		{ Name = "Stufe", Path = "Rpg.Level" },
	},
}
