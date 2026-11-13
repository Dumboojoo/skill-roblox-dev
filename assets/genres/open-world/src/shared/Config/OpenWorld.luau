--!strict
--[[
	OpenWorld – Tag/Nacht, Rohstoffe, Belohnungen der offenen Welt.

	Welt-Vertrag:
	  Tag WorldSpawn    BasePart  Startpunkt für neue Spieler
	  Tag Region        BasePart  unsichtbarer Kasten (CanCollide aus), Attribute RegionId (string),
	                              DisplayName (string). Wer darin steht, ist in diesem Gebiet.
	                              Kleine Gebiete dürfen in großen liegen: das kleinste zählt.
	  Tag Waypoint      BasePart  Attribute WaypointId (string), DisplayName (string).
	                              Aktivieren schaltet die Schnellreise dorthin frei.
	  Tag ResourceNode  BasePart oder Model  Attribut Resource (Schlüssel aus Resources)

	Große Welten brauchen Streaming (Workspace.StreamingEnabled = true), damit
	Handys nicht die ganze Karte laden müssen. Der Beispielcode ist dafür gebaut:
	Der Server kennt immer alles, der Client reagiert über World.Observe darauf,
	was bei ihm gerade geladen ist. Details: references/genres/open-world.md.
]]

export type Resource = {
	DisplayName: string,
	HarvestTime: number, -- Sekunden gedrückt halten
	Amount: number,
	RespawnTime: number,
}

local Resources: { [string]: Resource } = {
	Wood = { DisplayName = "Holz", HarvestTime = 1.2, Amount = 3, RespawnTime = 45 },
	Stone = { DisplayName = "Stein", HarvestTime = 1.8, Amount = 2, RespawnTime = 60 },
	Herb = { DisplayName = "Kraut", HarvestTime = 0.5, Amount = 1, RespawnTime = 30 },
}

return {
	Resources = Resources,

	DayLengthMinutes = 14, -- echte Minuten für einen ganzen Tag
	StartHour = 9,
	NightStartsAt = 19,
	NightEndsAt = 6,

	DiscoveryReward = 25, -- Münzen für ein neu entdecktes Gebiet
	FastTravelCooldown = 8,
	SavePosition = true, -- beim nächsten Beitritt dort weitermachen, wo man aufgehört hat
}
