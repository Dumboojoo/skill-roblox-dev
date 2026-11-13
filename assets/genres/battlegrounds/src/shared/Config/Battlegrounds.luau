--!strict
--[[
	Battlegrounds – Kämpfer und ihre Fähigkeiten als Tabellen.

	Neuer Kämpfer = neuer Eintrag in Characters. Neue Fähigkeit = neuer Eintrag in
	dessen Abilities. Server-Prüfung, Anzeige und Effekte lesen alles von hier.

	Jede Fähigkeit ist im Kern dasselbe: nach einer kurzen Ausholzeit (Windup)
	entsteht vor dem Kämpfer eine Trefferzone (Kasten). Wer darin steht, bekommt
	Schaden, Betäubung und Rückstoß. Aus diesen wenigen Werten entstehen sehr
	unterschiedliche Angriffe:
	  schnell und schwach, langsam und stark, weit und schmal, kurz und breit,
	  mit Vorwärtssprung (Dash), mit langer Betäubung als Kombo-Starter …

	Welt-Vertrag: nur eine Arena mit SpawnLocations. Trainingspuppen sind Models
	mit Humanoid und HumanoidRootPart; sie nehmen Schaden wie Spieler.
]]

export type Attack = {
	DisplayName: string,
	Damage: number,
	Cooldown: number,
	Windup: number, -- Sekunden zwischen Tastendruck und Treffer (Zeit zum Reagieren)
	Size: Vector3, -- Trefferzone: Breite, Höhe, Tiefe
	Reach: number, -- wie weit die Mitte der Zone vor dem Kämpfer liegt
	Stun: number, -- Sekunden, die Getroffene nichts tun können
	Knockback: number, -- Rückstoß-Geschwindigkeit
	Dash: number?, -- der Angreifer schnellt mit diesem Tempo nach vorn
}

export type Character = {
	DisplayName: string,
	Description: string,
	Health: number,
	WalkSpeed: number,
	Color: Color3,
	Basic: Attack, -- Grundschlag (Maus links); der letzte Schlag der Kombo stößt weg
	ComboCount: number,
	Abilities: { Attack }, -- genau drei, Tasten siehe Keys
	Ultimate: Attack,
}

local Characters: { [string]: Character } = {
	Brawler = {
		DisplayName = "Raufbold",
		Description = "Ausgewogen. Schnelle Schläge, starker Aufwärtshaken.",
		Health = 120,
		WalkSpeed = 18,
		Color = Color3.fromRGB(230, 120, 60),
		ComboCount = 4,
		Basic = {
			DisplayName = "Schlag",
			Damage = 6,
			Cooldown = 0.38,
			Windup = 0.08,
			Size = Vector3.new(6, 6, 6),
			Reach = 4,
			Stun = 0.35,
			Knockback = 0,
		},
		Abilities = {
			{
				DisplayName = "Sturmlauf",
				Damage = 12,
				Cooldown = 6,
				Windup = 0.2,
				Size = Vector3.new(7, 6, 9),
				Reach = 5,
				Stun = 0.8,
				Knockback = 25,
				Dash = 70,
			},
			{
				DisplayName = "Aufwärtshaken",
				Damage = 18,
				Cooldown = 9,
				Windup = 0.3,
				Size = Vector3.new(6, 8, 6),
				Reach = 4,
				Stun = 1.2,
				Knockback = 60,
			},
			{
				DisplayName = "Bodenschlag",
				Damage = 14,
				Cooldown = 12,
				Windup = 0.45,
				Size = Vector3.new(16, 6, 16),
				Reach = 0,
				Stun = 1,
				Knockback = 40,
			},
		},
		Ultimate = {
			DisplayName = "Meteorfaust",
			Damage = 45,
			Cooldown = 1,
			Windup = 0.6,
			Size = Vector3.new(14, 10, 18),
			Reach = 8,
			Stun = 2,
			Knockback = 110,
			Dash = 90,
		},
	},

	Blade = {
		DisplayName = "Klinge",
		Description = "Wenig Leben, große Reichweite, schnelle Vorstöße.",
		Health = 95,
		WalkSpeed = 20,
		Color = Color3.fromRGB(90, 170, 230),
		ComboCount = 3,
		Basic = {
			DisplayName = "Hieb",
			Damage = 8,
			Cooldown = 0.45,
			Windup = 0.1,
			Size = Vector3.new(5, 6, 9),
			Reach = 5.5,
			Stun = 0.3,
			Knockback = 0,
		},
		Abilities = {
			{
				DisplayName = "Blitzstoß",
				Damage = 14,
				Cooldown = 5,
				Windup = 0.12,
				Size = Vector3.new(4, 6, 16),
				Reach = 8,
				Stun = 0.5,
				Knockback = 15,
				Dash = 95,
			},
			{
				DisplayName = "Wirbel",
				Damage = 16,
				Cooldown = 8,
				Windup = 0.25,
				Size = Vector3.new(14, 6, 14),
				Reach = 0,
				Stun = 0.7,
				Knockback = 35,
			},
			{
				DisplayName = "Sichelschnitt",
				Damage = 22,
				Cooldown = 11,
				Windup = 0.4,
				Size = Vector3.new(12, 6, 10),
				Reach = 6,
				Stun = 1.1,
				Knockback = 50,
			},
		},
		Ultimate = {
			DisplayName = "Tausend Schnitte",
			Damage = 40,
			Cooldown = 1,
			Windup = 0.5,
			Size = Vector3.new(10, 8, 26),
			Reach = 13,
			Stun = 2.2,
			Knockback = 80,
			Dash = 120,
		},
	},
}

return {
	Characters = Characters,
	DefaultCharacter = "Brawler",

	-- Tasten für Fähigkeit 1 bis 3 und die Ulti (Tastatur, Controller).
	Keys = {
		{ Enum.KeyCode.E, Enum.KeyCode.ButtonX },
		{ Enum.KeyCode.R, Enum.KeyCode.ButtonY },
		{ Enum.KeyCode.T, Enum.KeyCode.ButtonB },
		{ Enum.KeyCode.G, Enum.KeyCode.ButtonL1 },
	},
	BlockKeys = { Enum.KeyCode.F, Enum.KeyCode.ButtonL2 },

	ComboWindow = 0.9, -- Sekunden, in denen der nächste Grundschlag zur Kombo zählt
	FinisherKnockback = 55, -- Rückstoß des letzten Kombo-Schlags
	FinisherStun = 0.9,

	Block = {
		Reduction = 0.8, -- Anteil des Schadens, der geblockt wird (nur von vorn)
		WalkSpeed = 7,
	},

	Ultimate = {
		Max = 100,
		PerDamageDealt = 0.7,
		PerDamageTaken = 0.35,
	},

	KillCreditSeconds = 10,
}
