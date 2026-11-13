--!strict
-- Spielstand-Abschnitt der Rennen.

return {
	Template = {
		Racing = {
			Races = 0,
			Wins = 0,
			BestTime = 0, -- Sekunden für ein ganzes Rennen (0 = noch keins beendet)
			BestLap = 0,
		},
	},
	Leaderstats = {
		{ Name = "Siege", Path = "Racing.Wins" },
	},
}
