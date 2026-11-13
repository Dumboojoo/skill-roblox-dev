--!strict
-- Spielstand-Abschnitt des Simulators.

return {
	Template = {
		Simulator = {
			Coins = 0,
			TotalCoins = 0, -- seit dem letzten Rebirth verdient (Maßstab für den nächsten Rebirth)
			Rebirths = 0,
			Upgrades = {}, -- [UpgradeId] = Stufe
			Pets = {}, -- Liste von { Uid = number, Id = string }
			Equipped = {}, -- Liste von Uids
			NextPetUid = 1,
			Zones = { Start = true }, -- [ZonenId] = true
		},
	},
	Leaderstats = {
		{ Name = "Münzen", Path = "Simulator.Coins" },
		{ Name = "Rebirths", Path = "Simulator.Rebirths" },
	},
}
