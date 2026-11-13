--!strict
-- Spielstand-Abschnitt des Shooters.

return {
	Template = {
		Shooter = {
			Kills = 0,
			Deaths = 0,
			Headshots = 0,
		},
	},
	Leaderstats = {
		{ Name = "Kills", Path = "Shooter.Kills" },
	},
}
