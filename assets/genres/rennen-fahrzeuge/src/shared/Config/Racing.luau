--!strict
--[[
	Racing – Fahrverhalten und Rennablauf.

	Welt-Vertrag:
	  Tag StartGrid       BasePart  Startplätze; die Vorderseite des Teils zeigt in Fahrtrichtung
	  Tag RaceCheckpoint  BasePart  Attribut Order (number, 1 bis N). Unsichtbare Kästen quer über
	                                die Strecke, großzügig hoch und breit. Der Checkpoint mit der
	                                höchsten Order ist die Ziellinie.
	  Tag LobbySpawn      BasePart  wohin Fahrer nach dem Rennen kommen (optional)

	Das Auto ist ohne eigenes Modell ein Block mit vier Rädern. Eigenes Modell:
	Model unter ServerStorage.Assets.Car mit PrimaryPart "Chassis" (ein Quader) und
	einem VehicleSeat. Aussehen als unkollidierbare, masselose Teile daran schweißen.

	Fahrphysik: Das Auto hat keine echten Räder. Vier unsichtbare Federn (Raycasts
	nach unten) tragen den Wagen, Antrieb und Lenkung werden direkt als
	Geschwindigkeit gesetzt. Das ist das übliche Arcade-Verfahren: stabil,
	gut abstimmbar und auf jedem Gerät gleich.
]]

return {
	Car = {
		Size = Vector3.new(6, 1.4, 11),
		Color = Color3.fromRGB(214, 62, 62),

		MaxSpeed = 120, -- Studs pro Sekunde
		ReverseSpeed = 35,
		Acceleration = 60, -- Studs/s² beim Gasgeben
		Braking = 110,
		Coasting = 18, -- Ausrollen ohne Gas
		TurnRate = 115, -- Grad pro Sekunde bei voller Lenkung
		Grip = 7, -- wie schnell seitliches Rutschen abgebaut wird (höher = klebt mehr)

		SuspensionLength = 3, -- Länge der Federn in Studs
		Stiffness = 150, -- Federhärte
		Damping = 12, -- Dämpfung (weniger = schaukelt nach)
	},

	Race = {
		MinPlayers = 1, -- zum Testen 1; veröffentlicht mindestens 2
		Laps = 3,
		Intermission = 12,
		Countdown = 3,
		FinishTimeout = 30, -- Sekunden für die anderen, nachdem der Erste im Ziel ist
		MaxDuration = 300,
		ResultTime = 8,
	},
}
