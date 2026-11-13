--!strict
-- Spielstand-Abschnitt des Obbys.

return {
	Template = {
		Obby = {
			Stage = 0, -- höchster erreichter Checkpoint
			Completions = 0,
			BestTime = 0, -- Sekunden für einen kompletten Lauf ab Start (0 = noch keiner)
		},
	},
	Leaderstats = {
		{ Name = "Stufe", Path = "Obby.Stage" },
	},
}
