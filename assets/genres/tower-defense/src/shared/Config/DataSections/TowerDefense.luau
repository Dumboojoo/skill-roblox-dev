--!strict
-- Spielstand-Abschnitt für Tower Defense.

return {
	Template = {
		TowerDefense = {
			Wins = 0,
			GamesPlayed = 0,
			BestWave = 0,
		},
	},
	Leaderstats = {
		{ Name = "Siege", Path = "TowerDefense.Wins" },
	},
}
