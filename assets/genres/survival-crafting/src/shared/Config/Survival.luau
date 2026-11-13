--!strict
--[[
	Survival – Bedürfnisse, Gegenstände, Rezepte und Bauteile.

	Welt-Vertrag:
	  Tag Harvestable  BasePart oder Model  Attribute Item (Schlüssel aus Items),
	                   Amount (number, Standard 1), Respawn (Sek., Standard 40)
	  Tag WaterSource  BasePart  hier kann man trinken

	Gebaute Teile (Boden, Wand, Werkbank …) erzeugt der Server aus Buildables;
	sie werden pro Spieler gespeichert und beim nächsten Beitritt wieder aufgestellt.
	Eine Werkbank ist einfach ein Bauteil mit dem Feld Station.
]]

export type Item = {
	DisplayName: string,
	Food: number?, -- stillt so viel Hunger
	Water: number?, -- stillt so viel Durst
}

export type Recipe = {
	DisplayName: string,
	Inputs: { [string]: number },
	Output: string,
	Count: number,
	Station: string?, -- muss in der Nähe stehen (z. B. "Workbench")
}

export type Buildable = {
	DisplayName: string,
	Cost: { [string]: number },
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	Station: string?, -- macht das Bauteil zu einer Arbeitsstation
}

local Items: { [string]: Item } = {
	Wood = { DisplayName = "Holz" },
	Stone = { DisplayName = "Stein" },
	Fiber = { DisplayName = "Faser" },
	Plank = { DisplayName = "Brett" },
	Rope = { DisplayName = "Seil" },
	Berry = { DisplayName = "Beere", Food = 8, Water = 4 },
	RawMeat = { DisplayName = "Rohes Fleisch", Food = 6 },
	CookedMeat = { DisplayName = "Gebratenes Fleisch", Food = 40 },
}

local Recipes: { [string]: Recipe } = {
	Plank = { DisplayName = "Brett", Inputs = { Wood = 2 }, Output = "Plank", Count = 1 },
	Rope = { DisplayName = "Seil", Inputs = { Fiber = 3 }, Output = "Rope", Count = 1 },
	CookedMeat = {
		DisplayName = "Fleisch braten",
		Inputs = { RawMeat = 1, Wood = 1 },
		Output = "CookedMeat",
		Count = 1,
		Station = "Campfire",
	},
}

local Buildables: { [string]: Buildable } = {
	Floor = {
		DisplayName = "Boden",
		Cost = { Plank = 4 },
		Size = Vector3.new(8, 1, 8),
		Color = Color3.fromRGB(150, 110, 74),
		Material = Enum.Material.WoodPlanks,
	},
	Wall = {
		DisplayName = "Wand",
		Cost = { Plank = 3 },
		Size = Vector3.new(8, 8, 1),
		Color = Color3.fromRGB(136, 98, 66),
		Material = Enum.Material.WoodPlanks,
	},
	Workbench = {
		DisplayName = "Werkbank",
		Cost = { Wood = 6, Stone = 4 },
		Size = Vector3.new(4, 3, 2),
		Color = Color3.fromRGB(110, 84, 60),
		Material = Enum.Material.Wood,
		Station = "Workbench",
	},
	Campfire = {
		DisplayName = "Lagerfeuer",
		Cost = { Wood = 5, Stone = 3 },
		Size = Vector3.new(3, 1.5, 3),
		Color = Color3.fromRGB(230, 120, 50),
		Material = Enum.Material.Slate,
		Station = "Campfire",
	},
}

return {
	Items = Items,
	Recipes = Recipes,
	Buildables = Buildables,

	Needs = {
		Max = 100,
		HungerPerMinute = 5,
		ThirstPerMinute = 7,
		DamagePerSecond = 2, -- bei Hunger oder Durst auf 0
		DrinkAmount = 35,
	},

	Grid = 4, -- Raster in Studs, an dem Bauteile einrasten
	BuildRange = 45, -- so weit vom Spieler entfernt darf gebaut werden
	StationRange = 16,
	MaxPieces = 150,
	RemoveRefund = 0.5,
	HarvestRespawn = 40,
}
