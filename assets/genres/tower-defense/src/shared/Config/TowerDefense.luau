--!strict
--[[
	TowerDefense – Türme, Gegner und Wellen als Tabellen.

	Neuer Turm, neuer Gegner oder neue Welle = neuer Tabelleneintrag. Server-Logik,
	Darstellung und Anzeige lesen alles von hier.

	Welt-Vertrag (in Studio bauen und taggen):
	  Tag PathPoint    BasePart, Attribut Order (number): Wegpunkte in Reihenfolge.
	                   Der erste ist der Eingang, der letzte die Basis.
	  Tag TowerGround  BasePart: Flächen, auf denen Türme stehen dürfen.
]]

export type TowerLevel = {
	Cost: number, -- Stufe 1: Kaufpreis, danach Preis des Upgrades auf diese Stufe
	Damage: number,
	Range: number,
	Cooldown: number, -- Sekunden zwischen Schüssen
	Splash: number?, -- Radius für Flächenschaden
	Slow: number?, -- Tempo-Faktor für getroffene Gegner (0.6 = 40 % langsamer)
	SlowTime: number?,
}

export type Tower = {
	DisplayName: string,
	Description: string,
	Color: Color3,
	Levels: { TowerLevel },
}

export type Enemy = {
	DisplayName: string,
	Health: number,
	Speed: number, -- Studs pro Sekunde
	Reward: number, -- Geld beim Besiegen
	Damage: number, -- Schaden an der Basis, wenn er durchkommt
	Color: Color3,
	Size: number,
}

export type WaveGroup = { Enemy: string, Count: number, Interval: number, Delay: number? }

local Towers: { [string]: Tower } = {
	Archer = {
		DisplayName = "Schütze",
		Description = "Schnell und günstig, trifft ein Ziel.",
		Color = Color3.fromRGB(92, 170, 96),
		Levels = {
			{ Cost = 100, Damage = 6, Range = 22, Cooldown = 0.7 },
			{ Cost = 120, Damage = 10, Range = 25, Cooldown = 0.6 },
			{ Cost = 260, Damage = 18, Range = 28, Cooldown = 0.45 },
		},
	},
	Cannon = {
		DisplayName = "Kanone",
		Description = "Langsam, aber trifft alle Gegner im Umkreis.",
		Color = Color3.fromRGB(96, 104, 122),
		Levels = {
			{ Cost = 250, Damage = 14, Range = 20, Cooldown = 1.8, Splash = 7 },
			{ Cost = 300, Damage = 24, Range = 22, Cooldown = 1.6, Splash = 8 },
			{ Cost = 600, Damage = 44, Range = 24, Cooldown = 1.4, Splash = 10 },
		},
	},
	Frost = {
		DisplayName = "Frostturm",
		Description = "Wenig Schaden, verlangsamt Gegner.",
		Color = Color3.fromRGB(110, 196, 232),
		Levels = {
			{ Cost = 180, Damage = 2, Range = 18, Cooldown = 1.0, Slow = 0.6, SlowTime = 2 },
			{ Cost = 220, Damage = 4, Range = 21, Cooldown = 0.9, Slow = 0.5, SlowTime = 2.5 },
			{ Cost = 450, Damage = 8, Range = 24, Cooldown = 0.8, Slow = 0.4, SlowTime = 3 },
		},
	},
}

local Enemies: { [string]: Enemy } = {
	Grunt = {
		DisplayName = "Läufer",
		Health = 30,
		Speed = 8,
		Reward = 8,
		Damage = 1,
		Color = Color3.fromRGB(196, 78, 78),
		Size = 2.4,
	},
	Runner = {
		DisplayName = "Sprinter",
		Health = 18,
		Speed = 15,
		Reward = 10,
		Damage = 1,
		Color = Color3.fromRGB(230, 170, 60),
		Size = 1.9,
	},
	Tank = {
		DisplayName = "Brocken",
		Health = 160,
		Speed = 5,
		Reward = 30,
		Damage = 3,
		Color = Color3.fromRGB(110, 80, 150),
		Size = 3.6,
	},
	Boss = {
		DisplayName = "Boss",
		Health = 1200,
		Speed = 4,
		Reward = 300,
		Damage = 20,
		Color = Color3.fromRGB(40, 40, 46),
		Size = 6,
	},
}

-- Jede Welle ist eine Liste von Gruppen, die nacheinander erscheinen.
local Waves: { { WaveGroup } } = {
	{ { Enemy = "Grunt", Count = 8, Interval = 1.2 } },
	{ { Enemy = "Grunt", Count = 12, Interval = 0.9 } },
	{ { Enemy = "Grunt", Count = 8, Interval = 0.8 }, { Enemy = "Runner", Count = 6, Interval = 0.6, Delay = 2 } },
	{ { Enemy = "Runner", Count = 14, Interval = 0.45 } },
	{ { Enemy = "Tank", Count = 3, Interval = 3 }, { Enemy = "Grunt", Count = 14, Interval = 0.6 } },
	{ { Enemy = "Runner", Count = 18, Interval = 0.35 }, { Enemy = "Tank", Count = 5, Interval = 2, Delay = 3 } },
	{ { Enemy = "Tank", Count = 8, Interval = 1.6 }, { Enemy = "Runner", Count = 20, Interval = 0.3 } },
	{ { Enemy = "Boss", Count = 1, Interval = 1 }, { Enemy = "Grunt", Count = 24, Interval = 0.4, Delay = 4 } },
}

return {
	Towers = Towers,
	Enemies = Enemies,
	Waves = Waves,

	TargetModes = { "First", "Last", "Strongest", "Closest" },

	StartCash = 250,
	BaseHealth = 20,
	HealthGrowthPerWave = 0.08, -- Gegner werden pro Welle um diesen Anteil zäher
	Intermission = 12, -- Sekunden zwischen Wellen
	WaveBonus = 60, -- Geld für alle nach jeder überstandenen Welle
	SellRefund = 0.7, -- Anteil der Ausgaben, den man beim Verkauf zurückbekommt
	MinTowerSpacing = 4,
	PathClearance = 4, -- Mindestabstand eines Turms zum Weg
	MaxTowersPerPlayer = 20,
	RestartDelay = 10,
}
