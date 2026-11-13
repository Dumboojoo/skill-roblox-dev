--!strict
--[[
	Dungeon – Raumgrößen, Gegner, Beute.

	Der Dungeon wird bei jedem Durchlauf neu aus Räumen zusammengesetzt. Darum ist
	er (anders als sonst) keine von Hand gebaute Welt, sondern entsteht aus
	BAUSTEINEN:

	  Ohne eigene Bausteine baut der Server schlichte Block-Räume. Sofort spielbar.

	  Eigene Räume: je Raumart ein oder mehrere Models unter
	  ServerStorage.Assets.DungeonRooms.<Art>  (Art = Start, Combat, Treasure, Boss;
	  mehrere Varianten als Kinder eines Folders mit diesem Namen).
	    - PrimaryPart = Boden, genau RoomSize x RoomSize groß, mittig
	    - Teile namens DoorN, DoorE, DoorS, DoorW: das Wandstück in der jeweiligen
	      Türöffnung. Wo der Grundriss eine Tür vorsieht, wird es zum Gitter, das
	      sich im Kampf schließt; wo nicht, bleibt es als Wand stehen.
	    - Tag MobSpawn (BasePart): wo Gegner erscheinen (optional)
	    - Tag Chest (BasePart): die Truhe im Schatzraum (optional)

	Außerhalb des Dungeons braucht die Welt nichts. Eine Lobby mit eigenen
	Servern pro Gruppe beschreibt references/genres/dungeon.md.
]]

export type Mob = {
	DisplayName: string,
	Health: number,
	Damage: number,
	Speed: number,
	AttackRange: number,
	AttackCooldown: number,
	Size: Vector3,
	Color: Color3,
}

export type LootEntry = { Id: string, DisplayName: string, Weight: number, Coins: number, Rarity: string }

local Mobs: { [string]: Mob } = {
	Grunt = {
		DisplayName = "Skelett",
		Health = 50,
		Damage = 8,
		Speed = 13,
		AttackRange = 5,
		AttackCooldown = 1.2,
		Size = Vector3.new(2.4, 5, 2),
		Color = Color3.fromRGB(214, 210, 196),
	},
	Brute = {
		DisplayName = "Oger",
		Health = 180,
		Damage = 20,
		Speed = 9,
		AttackRange = 7,
		AttackCooldown = 2,
		Size = Vector3.new(4.5, 7.5, 4),
		Color = Color3.fromRGB(110, 140, 90),
	},
	Boss = {
		DisplayName = "Dungeon-Fürst",
		Health = 900,
		Damage = 34,
		Speed = 11,
		AttackRange = 9,
		AttackCooldown = 1.8,
		Size = Vector3.new(6, 11, 5),
		Color = Color3.fromRGB(120, 40, 60),
	},
}

-- Welche Gegner in welcher Raumart erscheinen.
local RoomMobs: { [string]: { { Mob: string, Count: number } } } = {
	Combat = { { Mob = "Grunt", Count = 3 }, { Mob = "Brute", Count = 1 } },
	Boss = { { Mob = "Boss", Count = 1 }, { Mob = "Grunt", Count = 2 } },
}

-- Beute aus Truhen und vom Boss. Chance = Weight / Summe aller Weights.
local Loot: { LootEntry } = {
	{ Id = "Pouch", DisplayName = "Münzbeutel", Weight = 60, Coins = 30, Rarity = "Gewöhnlich" },
	{ Id = "Gem", DisplayName = "Edelstein", Weight = 28, Coins = 90, Rarity = "Selten" },
	{ Id = "Relic", DisplayName = "Relikt", Weight = 10, Coins = 250, Rarity = "Episch" },
	{ Id = "Crown", DisplayName = "Krone", Weight = 2, Coins = 1000, Rarity = "Legendär" },
}

return {
	Mobs = Mobs,
	RoomMobs = RoomMobs,
	Loot = Loot,

	RoomCount = 9,
	RoomSize = 64, -- Kantenlänge eines Raums in Studs
	WallHeight = 20,
	DoorWidth = 12,
	Origin = Vector3.new(0, 200, 0), -- wo der Dungeon in der Welt entsteht (weit weg von der Lobby)

	Attack = { Damage = 18, Range = 8, Width = 7, Cooldown = 0.45 },

	BossLootRolls = 3, -- so oft würfelt jeder Spieler beim Boss
	RestartDelay = 15, -- Sekunden nach dem Boss bis zum nächsten Dungeon
}
