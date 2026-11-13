--!strict
-- Grund-Abschnitt des Spielstands, den jedes Spiel hat.

return {
	Template = {
		Stats = {
			FirstJoin = 0, -- Unix-Zeit des ersten Beitritts
			Joins = 0,
			PlayTime = 0, -- Sekunden insgesamt
		},
		Settings = {
			MusicVolume = 0.5,
			SfxVolume = 0.8,
		},
	},
}
