--!strict
-- Spielstand-Abschnitt des Adventures.

return {
	Template = {
		Adventure = {
			Coins = 0,
			Completed = {}, -- [LevelId] = true
			Gems = {}, -- [LevelId] = { [GemId] = true }
		},
	},
	Leaderstats = {
		{ Name = "Münzen", Path = "Adventure.Coins" },
	},
}
