--!strict
-- Spielstand-Abschnitt des Tycoons.

return {
	Template = {
		Tycoon = {
			Coins = 0,
			Owned = {}, -- [ItemId] = true
			LastSeen = 0, -- Unix-Zeit beim Verlassen (für Verdienst während der Abwesenheit)
		},
	},
	Leaderstats = {
		{ Name = "Geld", Path = "Tycoon.Coins" },
	},
}
