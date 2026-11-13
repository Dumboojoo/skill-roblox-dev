--!strict
--[[
	Rpg – Kampfwerte, Gegner und Quests als Tabellen.

	Welt-Vertrag:
	  Tag EnemySpawn  BasePart  Attribut Enemy (string) = Schlüssel aus Enemies.
	                            Dort erscheint ein Gegner und kehrt dorthin zurück.

	Gegner sind ohne eigenes Modell farbige Blöcke. Eigenes Modell: ein Model mit
	Humanoid und HumanoidRootPart unter ServerStorage.Assets.Enemies.<Schlüssel>.
]]

export type Enemy = {
	DisplayName: string,
	Health: number,
	Damage: number,
	Speed: number,
	AttackRange: number,
	AttackCooldown: number,
	AggroRange: number, -- ab hier verfolgt er Spieler
	LeashRange: number, -- so weit entfernt er sich höchstens von seinem Spawn
	RespawnTime: number,
	Xp: number,
	Coins: number,
	Size: Vector3,
	Color: Color3,
}

export type Quest = {
	Title: string,
	Description: string,
	Target: string, -- Gegner-Schlüssel
	Count: number,
	RewardXp: number,
	RewardCoins: number,
	RequiresLevel: number,
}

local Enemies: { [string]: Enemy } = {
	Slime = {
		DisplayName = "Schleim",
		Health = 40,
		Damage = 6,
		Speed = 9,
		AttackRange = 5,
		AttackCooldown = 1.4,
		AggroRange = 28,
		LeashRange = 55,
		RespawnTime = 8,
		Xp = 12,
		Coins = 4,
		Size = Vector3.new(3, 2.4, 3),
		Color = Color3.fromRGB(96, 200, 120),
	},
	Wolf = {
		DisplayName = "Wolf",
		Health = 90,
		Damage = 12,
		Speed = 18,
		AttackRange = 5.5,
		AttackCooldown = 1.1,
		AggroRange = 40,
		LeashRange = 80,
		RespawnTime = 12,
		Xp = 35,
		Coins = 10,
		Size = Vector3.new(2.4, 2.6, 4.4),
		Color = Color3.fromRGB(120, 124, 136),
	},
	Golem = {
		DisplayName = "Golem",
		Health = 420,
		Damage = 30,
		Speed = 8,
		AttackRange = 8,
		AttackCooldown = 2.2,
		AggroRange = 34,
		LeashRange = 60,
		RespawnTime = 30,
		Xp = 220,
		Coins = 60,
		Size = Vector3.new(6, 9, 5),
		Color = Color3.fromRGB(120, 96, 80),
	},
}

local Quests: { [string]: Quest } = {
	FirstBlood = {
		Title = "Schleimplage",
		Description = "Besiege 5 Schleime.",
		Target = "Slime",
		Count = 5,
		RewardXp = 60,
		RewardCoins = 25,
		RequiresLevel = 1,
	},
	WolfHunt = {
		Title = "Wolfsjagd",
		Description = "Besiege 8 Wölfe.",
		Target = "Wolf",
		Count = 8,
		RewardXp = 300,
		RewardCoins = 120,
		RequiresLevel = 3,
	},
	GolemSlayer = {
		Title = "Steinbrecher",
		Description = "Besiege einen Golem.",
		Target = "Golem",
		Count = 1,
		RewardXp = 500,
		RewardCoins = 250,
		RequiresLevel = 6,
	},
}

return {
	Enemies = Enemies,
	Quests = Quests,

	Attack = {
		Damage = 14,
		Range = 7, -- wie weit der Schlag nach vorn reicht
		Width = 6,
		Cooldown = 0.45,
		ComboCount = 3, -- Schläge in Folge
		ComboWindow = 0.9, -- Sekunden, in denen der nächste Schlag zur Kombo zählt
		ComboBonus = 0.25, -- +25 % Schaden pro Kombo-Schritt
	},

	Dodge = {
		Cooldown = 1.6,
		Duration = 0.35, -- so lange ist man unverwundbar
		Speed = 55,
	},

	Levels = {
		BaseXp = 50, -- XP von Stufe 1 auf 2
		Exponent = 1.5,
		MaxLevel = 50,
		HealthPerLevel = 12,
		DamagePerLevel = 0.08, -- +8 % Schaden pro Stufe
	},

	PvP = false,
	MaxActiveQuests = 3,
}
