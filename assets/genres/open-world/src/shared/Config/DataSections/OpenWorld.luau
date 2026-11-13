--!strict
-- Spielstand-Abschnitt der offenen Welt.

return {
	Template = {
		World = {
			Coins = 0,
			Discovered = {}, -- [RegionId] = true
			Waypoints = {}, -- [WaypointId] = true
			Resources = {}, -- [RohstoffId] = Anzahl
			-- Letzte Position als einzelne Zahlen (Vector3 lässt sich nicht speichern).
			HasPosition = false,
			X = 0,
			Y = 0,
			Z = 0,
		},
	},
	Leaderstats = {
		{ Name = "Münzen", Path = "World.Coins" },
	},
}
