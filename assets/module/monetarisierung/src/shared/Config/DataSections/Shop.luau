--!strict
-- Spielstand-Abschnitt des Shops.

return {
	Template = {
		Shop = {
			LastDailyDay = 0, -- Tagesnummer der letzten täglichen Belohnung (0 = noch nie)
			Streak = 0, -- Tag der Reihe bei der letzten Abholung
			Purchases = 0, -- Anzahl verarbeiteter Robux-Käufe
		},
	},
}
