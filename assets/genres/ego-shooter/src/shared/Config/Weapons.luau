--!strict
--[[
	Weapons – alle Waffen und das Aussehen der Ego-Ansicht als Tabellen.

	Neue Waffe = neuer Eintrag in List. Kein weiterer Code nötig: Server-Prüfung,
	Ego-Ansicht, Anzeige und Admin-Befehle lesen alles aus dieser Datei.

	Die Waffenmodelle bestehen aus Blöcken (Parts) und werden aus `Model.Parts`
	gebaut. Koordinaten im Waffenraum: Ursprung = Griff der rechten Hand,
	-Z zeigt nach vorn (Schussrichtung), +Y nach oben, +X nach rechts.

	Eigenes Modell aus Studio statt der Blöcke: Ein Model mit demselben Namen wie
	der Schlüssel (z. B. "Rifle") nach ReplicatedStorage.Assets.Weapons legen. Es
	braucht ein PrimaryPart mit den Attachments Grip, Support, Muzzle, Sight und
	Magazine (siehe Shooter/WeaponModel).
]]

export type PartSpec = {
	Size: Vector3,
	Position: Vector3,
	Color: Color3,
	Material: Enum.Material?,
	Rotation: Vector3?, -- Grad
}

export type ModelSpec = {
	Parts: { PartSpec },
	Support: Vector3, -- wo die linke Hand greift
	Muzzle: Vector3, -- Mündung (Mündungsfeuer, Start der Leuchtspur)
	Sight: Vector3, -- Punkt, der beim Zielen in die Bildmitte wandert
	Magazine: Vector3, -- wohin die linke Hand beim Nachladen greift
}

export type Weapon = {
	DisplayName: string,

	-- Schaden
	Damage: number,
	HeadshotMultiplier: number,
	LimbMultiplier: number,
	Range: number,
	Pellets: number, -- Schrot: mehrere Kugeln pro Schuss

	-- Feuern
	FireRate: number, -- Schuss pro Minute
	Automatic: boolean,
	Spread: number, -- Streuung aus der Hüfte in Grad
	AimSpread: number, -- Streuung beim Zielen in Grad

	-- Munition
	MagazineSize: number,
	ReserveAmmo: number,
	ReloadTime: number,

	-- Gefühl
	RecoilKick: number, -- wie weit die Waffe zurückschlägt (Studs)
	RecoilPitch: number, -- wie stark die Kamera nach oben gedrückt wird (Grad)
	RecoilYaw: number, -- zufälliger Seitenversatz (Grad)
	AimFov: number,
	AimTime: number, -- Sekunden bis voll gezielt
	HipOffset: Vector3, -- Lage der Waffe relativ zur Kamera
	WalkSpeed: number,

	Model: ModelSpec,
}

local METAL = Color3.fromRGB(52, 55, 62)
local DARK = Color3.fromRGB(30, 32, 36)
local WOOD = Color3.fromRGB(150, 92, 58)

local List: { [string]: Weapon } = {
	Rifle = {
		DisplayName = "Sturmgewehr",
		Damage = 24,
		HeadshotMultiplier = 1.8,
		LimbMultiplier = 0.85,
		Range = 400,
		Pellets = 1,
		FireRate = 600,
		Automatic = true,
		Spread = 2.2,
		AimSpread = 0.35,
		MagazineSize = 30,
		ReserveAmmo = 120,
		ReloadTime = 2.1,
		RecoilKick = 0.22,
		RecoilPitch = 1.1,
		RecoilYaw = 0.5,
		AimFov = 52,
		AimTime = 0.18,
		HipOffset = Vector3.new(0.85, -0.95, -1.5),
		WalkSpeed = 16,
		Model = {
			Parts = {
				{ Size = Vector3.new(0.34, 0.5, 2.1), Position = Vector3.new(0, 0.35, -0.55), Color = METAL },
				{ Size = Vector3.new(0.2, 0.2, 1.3), Position = Vector3.new(0, 0.42, -2.2), Color = DARK },
				{ Size = Vector3.new(0.3, 0.42, 1.0), Position = Vector3.new(0, 0.3, 0.95), Color = WOOD },
				{
					Size = Vector3.new(0.28, 0.6, 0.34),
					Position = Vector3.new(0, -0.1, 0),
					Color = WOOD,
					Rotation = Vector3.new(-12, 0, 0),
				},
				{
					Size = Vector3.new(0.26, 0.75, 0.42),
					Position = Vector3.new(0, -0.2, -0.75),
					Color = DARK,
					Rotation = Vector3.new(12, 0, 0),
				},
				{ Size = Vector3.new(0.12, 0.18, 0.5), Position = Vector3.new(0, 0.7, -0.4), Color = DARK },
			},
			Support = Vector3.new(0, 0.12, -1.35),
			Muzzle = Vector3.new(0, 0.42, -2.9),
			Sight = Vector3.new(0, 0.84, -0.4),
			Magazine = Vector3.new(0, -0.5, -0.75),
		},
	},

	Pistol = {
		DisplayName = "Pistole",
		Damage = 30,
		HeadshotMultiplier = 2,
		LimbMultiplier = 0.9,
		Range = 220,
		Pellets = 1,
		FireRate = 380,
		Automatic = false,
		Spread = 1.6,
		AimSpread = 0.4,
		MagazineSize = 12,
		ReserveAmmo = 60,
		ReloadTime = 1.4,
		RecoilKick = 0.3,
		RecoilPitch = 1.8,
		RecoilYaw = 0.4,
		AimFov = 58,
		AimTime = 0.12,
		HipOffset = Vector3.new(0.7, -0.85, -1.7),
		WalkSpeed = 18,
		Model = {
			Parts = {
				{ Size = Vector3.new(0.3, 0.36, 1.25), Position = Vector3.new(0, 0.38, -0.4), Color = METAL },
				{
					Size = Vector3.new(0.28, 0.7, 0.36),
					Position = Vector3.new(0, -0.1, 0),
					Color = DARK,
					Rotation = Vector3.new(-10, 0, 0),
				},
				{ Size = Vector3.new(0.1, 0.12, 0.12), Position = Vector3.new(0, 0.62, -0.95), Color = DARK },
			},
			Support = Vector3.new(-0.12, -0.2, -0.05),
			Muzzle = Vector3.new(0, 0.38, -1.05),
			Sight = Vector3.new(0, 0.74, -0.2),
			Magazine = Vector3.new(0, -0.55, 0),
		},
	},

	Shotgun = {
		DisplayName = "Schrotflinte",
		Damage = 11,
		HeadshotMultiplier = 1.4,
		LimbMultiplier = 0.9,
		Range = 90,
		Pellets = 8,
		FireRate = 75,
		Automatic = false,
		Spread = 5.5,
		AimSpread = 4,
		MagazineSize = 6,
		ReserveAmmo = 30,
		ReloadTime = 2.6,
		RecoilKick = 0.6,
		RecoilPitch = 4.5,
		RecoilYaw = 1.2,
		AimFov = 60,
		AimTime = 0.22,
		HipOffset = Vector3.new(0.85, -0.95, -1.4),
		WalkSpeed = 15,
		Model = {
			Parts = {
				{ Size = Vector3.new(0.34, 0.42, 1.5), Position = Vector3.new(0, 0.34, -0.3), Color = METAL },
				{ Size = Vector3.new(0.24, 0.24, 1.9), Position = Vector3.new(0, 0.42, -1.9), Color = DARK },
				{ Size = Vector3.new(0.3, 0.3, 0.9), Position = Vector3.new(0, 0.14, -1.6), Color = WOOD },
				{ Size = Vector3.new(0.3, 0.44, 1.1), Position = Vector3.new(0, 0.24, 0.95), Color = WOOD },
				{
					Size = Vector3.new(0.28, 0.55, 0.32),
					Position = Vector3.new(0, -0.08, 0),
					Color = WOOD,
					Rotation = Vector3.new(-14, 0, 0),
				},
			},
			Support = Vector3.new(0, 0.02, -1.6),
			Muzzle = Vector3.new(0, 0.42, -2.9),
			Sight = Vector3.new(0, 0.66, -0.3),
			Magazine = Vector3.new(0, 0.05, -0.6),
		},
	},
}

return {
	List = List,

	-- Womit jeder Spieler startet (Plätze 1, 2, …; Wechsel mit den Zifferntasten oder dem Mausrad).
	Loadout = { "Rifle", "Pistol" },

	FriendlyFire = false, -- Schaden an Spielern im eigenen Team

	-- Die Ego-Arme: gerade Blöcke von der Schulter zur Hand, bewusst ohne Animationen.
	Arms = {
		Width = 0.46,
		HandLength = 0.5, -- der Block am Ende des Ärmels
		SleeveColor = Color3.fromRGB(38, 40, 46),
		CuffColor = Color3.fromRGB(200, 48, 48), -- schmaler Ring zwischen Ärmel und Hand
		CuffLength = 0.12,
		UseSkinColor = true, -- Handfarbe vom Avatar übernehmen
		HandColor = Color3.fromRGB(234, 184, 146), -- falls UseSkinColor = false
		-- Schulterpunkte relativ zur Kamera (hinter und unter dem Bild, damit das Ende nicht sichtbar ist).
		RightShoulder = Vector3.new(1.05, -1.55, 0.7),
		LeftShoulder = Vector3.new(-0.75, -1.6, 0.7),
	},

	DefaultFov = 70,
}
