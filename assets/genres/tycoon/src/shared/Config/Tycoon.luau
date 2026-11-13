--!strict
--[[
	Tycoon – was man kaufen kann, in welcher Reihenfolge und was es bringt.

	Jedes Grundstück wird in Studio KOMPLETT ausgebaut hingestellt (alle Maschinen,
	Wände, Deko). Beim Start räumt der Server alles Kaufbare weg und stellt es erst
	wieder hin, wenn der Besitzer es gekauft hat. So sieht man beim Bauen sofort
	das fertige Ergebnis.

	Welt-Vertrag (alles innerhalb des Grundstück-Models):
	  Tag TycoonPlot       Model     das Grundstück
	    Kind "Claim"       BasePart  Berühren = Grundstück übernehmen
	    Kind "CollectPad"  BasePart  Berühren = Geld aus dem Sammler abholen
	  Tag TycoonButton     BasePart  Attribut Item (string): Kaufknopf für diesen Gegenstand
	  Tag TycoonItem       Model/BasePart  Attribut Item (string): der Gegenstand selbst.
	                       Dropper brauchen darin ein Teil namens "Spout" (dort erscheinen die Tropfen).
	  Tag TycoonCollector  BasePart  Tropfen, die es berühren, werden gutgeschrieben
	  Tag TycoonUpgrader   BasePart  Attribut Multiplier (number): Tropfen werden einmal aufgewertet
	  Tag Conveyor         BasePart  Attribut Speed (number): Förderband, Richtung = Vorderseite

	Mehrere Grundstücke: ein Grundstück fertig bauen, dann duplizieren.
]]

export type Dropper = { Interval: number, Value: number }

export type Item = {
	DisplayName: string,
	Price: number,
	Requires: { string }, -- muss vorher gekauft sein (Knopf erscheint erst dann)
	Dropper: Dropper?,
}

local Items: { [string]: Item } = {
	Dropper1 = { DisplayName = "Tropfer", Price = 0, Requires = {}, Dropper = { Interval = 2.5, Value = 5 } },
	Conveyor1 = { DisplayName = "Förderband", Price = 0, Requires = { "Dropper1" } },
	Dropper2 = {
		DisplayName = "Tropfer II",
		Price = 150,
		Requires = { "Conveyor1" },
		Dropper = { Interval = 2, Value = 12 },
	},
	Upgrader1 = { DisplayName = "Veredler", Price = 600, Requires = { "Dropper2" } },
	Walls = { DisplayName = "Wände", Price = 400, Requires = { "Dropper2" } },
	Dropper3 = {
		DisplayName = "Tropfer III",
		Price = 2500,
		Requires = { "Upgrader1" },
		Dropper = { Interval = 1.5, Value = 40 },
	},
}

return {
	Items = Items,

	StartCoins = 0,
	MaxDropsPerPlot = 60, -- Obergrenze gleichzeitiger Tropfen (Leistung)
	DropLifetime = 25, -- Sekunden, dann verschwindet ein liegengebliebener Tropfen

	-- Verdienst, während man weg war: Anteil der normalen Rate, höchstens MaxHours lang.
	OfflineEarnings = { Rate = 0.25, MaxHours = 2 },
}
