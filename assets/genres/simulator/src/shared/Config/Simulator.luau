--!strict
--[[
	Simulator – Upgrades, Pets, Eier, Zonen und Rebirth als Tabellen.

	Das Spiel läuft schon ohne Welt (Klick-Knopf und Menüs). Die Welt macht es
	zum Erlebnis. Welt-Vertrag:

	  Tag Collectible  BasePart   Attribute Value (number), Zone (string, optional),
	                              Respawn (Sek., Standard 8). Berühren sammelt ein.
	  Tag ZoneGate     BasePart   Attribut Zone (string). Sperre vor einer Zone; wer die
	                              Zone gekauft hat, kann hindurch.
	  Tag EggStand     BasePart   Attribut Egg (string). Öffnet das Eier-Menü.

	Fairness: Chancen der Eier werden im Menü angezeigt (berechnet aus Weight).
	Eier kosten Spielwährung. Sobald sie direkt oder über gekaufte Währung Robux
	kosten, gelten die Roblox-Regeln für Zufallskäufe (siehe monetarisierung.md).
]]

export type Upgrade = {
	DisplayName: string,
	Description: string,
	BaseCost: number,
	Growth: number, -- Preis mal diesem Faktor pro Stufe
	MaxLevel: number,
}

export type Pet = {
	DisplayName: string,
	Multiplier: number, -- 1.5 = +50 % Münzen
	Rarity: string,
	Color: Color3,
}

export type EggEntry = { Id: string, Weight: number }
export type Egg = { DisplayName: string, Price: number, Pets: { EggEntry } }
export type Zone = { DisplayName: string, Price: number, Order: number }

local Upgrades: { [string]: Upgrade } = {
	ClickPower = {
		DisplayName = "Klick-Kraft",
		Description = "+1 Münze pro Klick",
		BaseCost = 25,
		Growth = 1.35,
		MaxLevel = 200,
	},
}

local Pets: { [string]: Pet } = {
	Cat = { DisplayName = "Katze", Multiplier = 1.2, Rarity = "Gewöhnlich", Color = Color3.fromRGB(230, 170, 90) },
	Dog = { DisplayName = "Hund", Multiplier = 1.35, Rarity = "Gewöhnlich", Color = Color3.fromRGB(170, 120, 80) },
	Fox = { DisplayName = "Fuchs", Multiplier = 1.8, Rarity = "Selten", Color = Color3.fromRGB(235, 110, 50) },
	Owl = { DisplayName = "Eule", Multiplier = 2.6, Rarity = "Episch", Color = Color3.fromRGB(130, 100, 200) },
	Dragon = { DisplayName = "Drache", Multiplier = 5, Rarity = "Legendär", Color = Color3.fromRGB(220, 60, 70) },
}

local Eggs: { [string]: Egg } = {
	Basic = {
		DisplayName = "Einfaches Ei",
		Price = 150,
		Pets = {
			{ Id = "Cat", Weight = 50 },
			{ Id = "Dog", Weight = 35 },
			{ Id = "Fox", Weight = 12 },
			{ Id = "Owl", Weight = 3 },
		},
	},
	Golden = {
		DisplayName = "Goldenes Ei",
		Price = 5000,
		Pets = {
			{ Id = "Fox", Weight = 60 },
			{ Id = "Owl", Weight = 32 },
			{ Id = "Dragon", Weight = 8 },
		},
	},
}

local Zones: { [string]: Zone } = {
	Start = { DisplayName = "Wiese", Price = 0, Order = 1 },
	Forest = { DisplayName = "Wald", Price = 2500, Order = 2 },
	Volcano = { DisplayName = "Vulkan", Price = 40000, Order = 3 },
}

return {
	Upgrades = Upgrades,
	Pets = Pets,
	Eggs = Eggs,
	Zones = Zones,

	Rebirth = {
		BaseCost = 100000, -- Münzen (insgesamt verdient seit dem letzten Rebirth)
		Growth = 2.5,
		BonusPerRebirth = 0.5, -- +50 % Münzen pro Rebirth
	},

	MaxEquippedPets = 3,
	MaxPets = 60,
	MaxClicksPerSecond = 12,
	CollectibleRespawn = 8,
}
