--!strict
--[[
	Horror – Verfolger, Taschenlampe, Sprint und der Ablauf des Kapitels.

	Welt-Vertrag:
	  Tag ChaserSpawn  BasePart  wo der Verfolger erscheint (genau einer)
	  Tag PatrolPoint  BasePart  Attribut Order (number): Streifenroute des Verfolgers
	  Tag HideSpot     BasePart  unsichtbarer Kasten; wer darin steht, wird nicht gesehen
	  Tag Pickup       BasePart  Attribute Item (string), DisplayName (string, optional)
	  Tag Door         BasePart  Attribute DoorId (string), Key (string, optional = Item, das sie öffnet)
	  Tag StoryZone    BasePart  Attribut Zone (string): Bereich, der erreicht werden soll
	  Tag Note         BasePart  Attribut Text (string): lesbare Notiz

	Der Verfolger ist ohne eigenes Modell ein dunkler Block. Eigenes Modell: Model
	mit Humanoid und HumanoidRootPart unter ServerStorage.Assets.Chaser.

	Das Kapitel ist eine Liste von Zielen, die der Reihe nach erfüllt werden:
	  Type "Pickup"  Item = ...     Gegenstand aufheben
	  Type "Door"    Door = ...     Tür öffnen
	  Type "Reach"   Zone = ...     Bereich erreichen
]]

export type Objective = {
	Text: string,
	Type: string,
	Item: string?,
	Door: string?,
	Zone: string?,
}

local Objectives: { Objective } = {
	{ Text = "Finde den Kellerschlüssel", Type = "Pickup", Item = "CellarKey" },
	{ Text = "Öffne die Kellertür", Type = "Door", Door = "Cellar" },
	{ Text = "Finde die Sicherung", Type = "Pickup", Item = "Fuse" },
	{ Text = "Erreiche den Ausgang", Type = "Reach", Zone = "Exit" },
}

return {
	Objectives = Objectives,

	Chaser = {
		PatrolSpeed = 9,
		ChaseSpeed = 19, -- etwas schneller als Gehen (16), langsamer als Sprinten
		SightRange = 70,
		SightAngle = 65, -- halber Öffnungswinkel des Sichtkegels in Grad
		HearingRange = 30, -- so weit hört er rennende Spieler
		NoiseSpeed = 18, -- ab dieser Geschwindigkeit macht ein Spieler Lärm
		CatchRange = 5,
		LoseSightTime = 2.5, -- Sekunden ohne Sicht, bis er die Verfolgung abbricht
		SearchTime = 7, -- so lange sucht er an der letzten bekannten Stelle
		Damage = 100,
		Size = Vector3.new(3, 7, 2),
		Color = Color3.fromRGB(18, 18, 22),
	},

	Flashlight = {
		BatterySeconds = 150,
		RechargePerSecond = 0.35, -- Anteil der Entladerate, wenn aus
		Range = 55,
		Angle = 60,
		Brightness = 2.5,
	},

	Sprint = {
		Speed = 22,
		WalkSpeed = 14, -- bewusst langsamer als üblich: mehr Anspannung
		StaminaSeconds = 4.5,
		RecoverPerSecond = 0.5,
	},

	-- Rücksicht auf empfindliche Spieler: kein Aufblitzen beim Erwischtwerden, wenn false.
	FlashOnCaught = true,
	DangerDistance = 45, -- ab hier pulsiert der Bildrand
}
