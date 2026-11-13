--!strict
-- Spielstand-Abschnitt der Rundenspiele.

return {
	Template = {
		Rounds = {
			Wins = 0,
			Played = 0,
			Coins = 0,
		},
	},
	Leaderstats = {
		{ Name = "Siege", Path = "Rounds.Wins" },
	},
}
