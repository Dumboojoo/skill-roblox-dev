--!strict
-- Spielstand-Abschnitt des Inventars (Aufbau siehe shared/Inventory/Logic).

return {
	Template = {
		Inventory = {
			Slots = {}, -- Liste von { Uid = number, Id = string, Count = number }
			Equipped = {}, -- [Ausrüstungsplatz] = Uid
			NextUid = 1,
		},
	},
}
