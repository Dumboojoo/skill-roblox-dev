--!strict
--[[
	Products – alles, was man kaufen kann, und die tägliche Gratis-Belohnung.

	Ids kommen aus dem Creator Hub (Monetarisierung → Pässe bzw. Entwicklerprodukte).
	Id = 0 heißt "noch nicht angelegt": Der Eintrag erscheint im Shop als "Bald
	verfügbar" und löst keinen Kauf aus.

	Leitlinien für diesen Katalog (ausführlich: references/monetarisierung.md):
	  - Wenige, klare Angebote. Jeder Eintrag sagt in einem Satz, was man bekommt.
	  - Verkauft wird Kosmetik, Komfort und Unterstützung. Keine Stärke, die
	    zahlende Spieler gegen andere gewinnen lässt.
	  - Alles Spielentscheidende ist auch ohne Robux in vertretbarer Zeit erreichbar.
	  - Keine Zufallskäufe gegen Robux ohne angezeigte Chancen; in manchen Ländern
	    sind sie ganz verboten (MonetizationService:RandomItemsAllowed prüft das).

	Was ein Produkt GIBT, bestimmt das Feld Grant: der Name eines Handlers, den
	das Spiel beim MonetizationService anmeldet (RegisterGrant). So weiß dieses
	Modul nichts über die Währung des Spiels und passt zu jedem Genre.
]]

export type GamePass = {
	Id: number,
	DisplayName: string,
	Description: string,
}

export type Product = {
	Id: number,
	DisplayName: string,
	Description: string,
	Grant: string, -- Name des Gutschrift-Handlers
	Amount: number, -- wird dem Handler übergeben
}

local GamePasses: { [string]: GamePass } = {
	Supporter = {
		Id = 0,
		DisplayName = "Unterstützer",
		Description = "Goldener Namenszug und ein Abzeichen. Danke, dass du das Spiel unterstützt!",
	},
	ExtraStorage = {
		Id = 0,
		DisplayName = "Großer Rucksack",
		Description = "30 zusätzliche Inventarplätze.",
	},
}

local Products: { [string]: Product } = {
	CoinsSmall = {
		Id = 0,
		DisplayName = "Münzbeutel",
		Description = "500 Münzen",
		Grant = "Coins",
		Amount = 500,
	},
	CoinsLarge = {
		Id = 0,
		DisplayName = "Münztruhe",
		Description = "3.000 Münzen (20 % mehr pro Robux)",
		Grant = "Coins",
		Amount = 3000,
	},
}

return {
	GamePasses = GamePasses,
	Products = Products,

	-- Tägliche Gratis-Belohnung: bindet Spieler ohne Kaufdruck. Tag 1, 2, 3 … in Folge;
	-- nach dem letzten Eintrag beginnt die Reihe von vorn. Ein verpasster Tag setzt zurück.
	Daily = {
		Grant = "Coins",
		Rewards = { 50, 75, 100, 150, 200, 300, 500 },
	},
}
