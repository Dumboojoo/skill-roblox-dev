--!strict
-- Spielstand-Abschnitt von Battlegrounds.

return {
	Template = {
		Battle = {
			Kills = 0,
			Deaths = 0,
			Character = "Brawler", -- zuletzt gewählter Kämpfer
		},
	},
	Leaderstats = {
		{ Name = "Kills", Path = "Battle.Kills" },
	},
}
