--!strict
--[[
	Items – alle Gegenstände des Inventars, ihre Kategorien und Seltenheiten.

	Neuer Gegenstand = neuer Eintrag in List. Das Inventar-Fenster (Raster,
	Kategorie-Reiter, Suche, Detailfeld) und der InventoryService lesen alles von
	hier. Was ein Gegenstand im Spiel BEWIRKT (Schaden einer Waffe, Heilung eines
	Tranks), setzen die jeweiligen Services um; sie hängen sich an die Signale des
	InventoryService (Equipped, Used).
]]

export type Rarity = { DisplayName: string, Color: Color3, Order: number }

export type Item = {
	DisplayName: string,
	Description: string,
	Category: string, -- einer der Einträge aus Categories
	Rarity: string, -- Schlüssel aus Rarities
	MaxStack: number, -- 1 = nicht stapelbar (jedes Stück belegt einen eigenen Platz)
	EquipSlot: string?, -- z. B. "Weapon"; nil = nicht ausrüstbar
	Usable: boolean?, -- Verbrauchsgegenstand: "Benutzen" verbraucht ein Stück
	-- Frei nutzbar, wird im Detailfeld angezeigt. Namen mit Umlauten als ["Glück"] = 5 schreiben.
	Stats: { [string]: number }?,
}

local Rarities: { [string]: Rarity } = {
	Common = { DisplayName = "Gewöhnlich", Color = Color3.fromRGB(170, 176, 190), Order = 1 },
	Uncommon = { DisplayName = "Ungewöhnlich", Color = Color3.fromRGB(96, 200, 110), Order = 2 },
	Rare = { DisplayName = "Selten", Color = Color3.fromRGB(80, 150, 255), Order = 3 },
	Epic = { DisplayName = "Episch", Color = Color3.fromRGB(176, 96, 240), Order = 4 },
	Legendary = { DisplayName = "Legendär", Color = Color3.fromRGB(250, 190, 60), Order = 5 },
	Mythical = { DisplayName = "Mythisch", Color = Color3.fromRGB(240, 70, 90), Order = 6 },
}

local List: { [string]: Item } = {
	WoodSword = {
		DisplayName = "Holzschwert",
		Description = "Besser als nichts.",
		Category = "Waffen",
		Rarity = "Common",
		MaxStack = 1,
		EquipSlot = "Weapon",
		Stats = { Schaden = 8 },
	},
	SteelSaber = {
		DisplayName = "Stahlsäbel",
		Description = "Scharf und gut ausbalanciert.",
		Category = "Waffen",
		Rarity = "Rare",
		MaxStack = 1,
		EquipSlot = "Weapon",
		Stats = { Schaden = 22 },
	},
	StormBlade = {
		DisplayName = "Sturmklinge",
		Description = "In ihr knistert ein Gewitter.",
		Category = "Waffen",
		Rarity = "Legendary",
		MaxStack = 1,
		EquipSlot = "Weapon",
		Stats = { Schaden = 60, Tempo = 15 },
	},
	LuckyCharm = {
		DisplayName = "Glücksbringer",
		Description = "Angeblich bringt er Glück.",
		Category = "Zubehör",
		Rarity = "Uncommon",
		MaxStack = 1,
		EquipSlot = "Accessory",
		Stats = { ["Glück"] = 5 },
	},
	HealthPotion = {
		DisplayName = "Heiltrank",
		Description = "Stellt 50 Leben wieder her.",
		Category = "Verbrauchbar",
		Rarity = "Common",
		MaxStack = 20,
		Usable = true,
		Stats = { Heilung = 50 },
	},
	IronOre = {
		DisplayName = "Eisenerz",
		Description = "Grundstoff für Schmiedearbeiten.",
		Category = "Material",
		Rarity = "Common",
		MaxStack = 99,
	},
	DragonScale = {
		DisplayName = "Drachenschuppe",
		Description = "Warm, obwohl der Drache längst fort ist.",
		Category = "Material",
		Rarity = "Epic",
		MaxStack = 99,
	},
}

return {
	List = List,
	Rarities = Rarities,

	-- Reihenfolge der Reiter im Inventar-Fenster ("Alle" steht automatisch davor).
	Categories = { "Waffen", "Zubehör", "Verbrauchbar", "Material" },

	-- Ausrüstungsplätze: Schlüssel = EquipSlot der Gegenstände, Wert = Anzeigename.
	EquipSlots = { Weapon = "Waffe", Accessory = "Zubehör" } :: { [string]: string },

	Capacity = 60, -- Plätze im Inventar
	OpenKey = Enum.KeyCode.B,
}
