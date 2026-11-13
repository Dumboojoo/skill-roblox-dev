--!strict
--[[
	Effects – alle sichtbaren Effekte des Spiels als Tabelle.

	Abgespielt wird über den Namen (siehe EffectController):
	  Client:  EffectController:Play("Hit", position)
	  Server:  Net.FireNear("Effect.Play", position, 150, "Hit", position)

	Ein Effekt besteht aus einer oder mehreren Schichten (z. B. Blitz + Funken + Rauch).
	Jede Schicht stößt einmalig `Count` Partikel aus.

	Neue Effekte: Eintrag ergänzen, fertig. Das Bild einer Schicht ist ein Schlüssel aus
	Config/AssetIds (Effects). Solange dort noch keine Nummer steht, erscheint das
	Standard-Partikel von Roblox – der Effekt ist also sofort sichtbar und wird schöner,
	sobald das eigene Bild hochgeladen ist.

	Die Bilder sind weiß gezeichnet; die Farbe kommt von hier. So dient ein Bild vielen Effekten.

	Gestapelte Schichten (ein Hieb aus Schein, Körper, Rand und heißem Kern, je ein eigenes
	weißes Bild und eine eigene Farbe): alle Schichten mit Count = 1, gleicher Lifetime, gleicher
	Size, ohne Speed, mit fester Rotation { 0, 0 } und aufsteigendem Front. Dann liegen die Bilder
	genau übereinander. Ein anderes Element (Feuer, Gift, Eis) ist nur eine andere Farbtabelle.
	Anleitung: references/effekte.md.
	Bewusst nur Zahlen und Texte (keine Roblox-Datentypen), damit die Tests die Datei lesen können.
]]

export type Layer = {
	Texture: string, -- Schlüssel aus AssetIds.Effects
	Flipbook: number?, -- Bildfolge: Kacheln je Seite (2, 4 oder 8); läuft einmal über die Lebensdauer
	Count: number, -- Partikel je Auslösung
	Lifetime: { number }, -- { kürzeste, längste } Lebensdauer in Sekunden
	Size: { number }, -- { Anfang, Ende } in Studs
	Speed: { number }?, -- { langsamste, schnellste } in Studs pro Sekunde (Standard: steht still)
	Spread: number?, -- Streuwinkel in Grad; 180 = in alle Richtungen (Standard 180)
	Color: { number }, -- { R, G, B } von 0 bis 255
	ColorEnd: { number }?, -- Farbe am Lebensende (Standard: wie Color)
	Fade: { number }?, -- Durchsichtigkeit { Anfang, Ende }, 0 = deckend, 1 = unsichtbar (Standard { 0, 1 })
	Glow: number?, -- 0 = normal, 1 = leuchtet additiv (Standard 1)
	Gravity: number?, -- Studs/s² nach unten; negativ = steigt auf (Standard 0)
	Drag: number?, -- Abbremsen (Standard 0)
	Rotation: { number }?, -- Startdrehung { von, bis } in Grad
	Spin: { number }?, -- Drehgeschwindigkeit { von, bis } in Grad pro Sekunde
	Stretch: boolean?, -- true: Partikel zeigt in Flugrichtung (für Striche und Funken)
	Front: number?, -- Reihenfolge übereinander: größere Zahl liegt weiter vorn (Standard 0)
}

export type Effect = {
	Layers: { Layer },
}

local Effects = {
	-- Ab dieser Entfernung zur Kamera wird ein Effekt gar nicht erst erzeugt (Studs).
	MaxDistance = 250,
	-- So viele Effekte dürfen gleichzeitig laufen; weitere werden übersprungen (Schutz fürs Handy).
	MaxActive = 40,

	List = {
		-- Treffer im Kampf: kurzer Blitz und wegspritzende Funken.
		Hit = {
			Layers = {
				{
					Texture = "Burst",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.22, 0.22 },
					Size = { 3.5, 4.5 },
					Color = { 255, 236, 170 },
					Rotation = { 0, 360 },
				},
				{
					Texture = "Line",
					Count = 7,
					Lifetime = { 0.18, 0.32 },
					Size = { 0.9, 0.2 },
					Speed = { 14, 26 },
					Color = { 255, 214, 120 },
					Gravity = 30,
					Stretch = true,
				},
			},
		},

		-- Schlag in die Luft: eine Sichel, die durchwischt.
		Slash = {
			Layers = {
				{
					Texture = "Slash",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.2, 0.2 },
					Size = { 6, 7 },
					Color = { 235, 245, 255 },
					Fade = { 0.1, 0.6 },
				},
			},
		},

		-- Schuss: Mündungsblitz.
		Shot = {
			Layers = {
				{
					Texture = "Glow",
					Count = 1,
					Lifetime = { 0.06, 0.09 },
					Size = { 2.2, 0.6 },
					Color = { 255, 222, 140 },
				},
				{
					Texture = "Spark",
					Count = 1,
					Lifetime = { 0.05, 0.08 },
					Size = { 3, 1.5 },
					Color = { 255, 240, 200 },
					Rotation = { 0, 90 },
				},
			},
		},

		-- Einschlag an einer Wand: Staub und ein paar Splitter.
		Impact = {
			Layers = {
				{
					Texture = "Puff",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.35, 0.45 },
					Size = { 1.2, 2.6 },
					Color = { 200, 195, 185 },
					Fade = { 0.3, 1 },
					Glow = 0,
					Rotation = { 0, 360 },
				},
				{
					Texture = "Line",
					Count = 4,
					Lifetime = { 0.15, 0.25 },
					Size = { 0.6, 0.1 },
					Speed = { 10, 18 },
					Spread = 60,
					Color = { 255, 230, 170 },
					Gravity = 40,
					Stretch = true,
				},
			},
		},

		-- Explosion: heller Kern, Druckring, Rauch.
		Explosion = {
			Layers = {
				{
					Texture = "Explosion",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.6, 0.7 },
					Size = { 9, 14 },
					Color = { 255, 190, 90 },
					ColorEnd = { 90, 80, 75 },
					Rotation = { 0, 360 },
				},
				{
					Texture = "RingGrow",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.35, 0.35 },
					Size = { 12, 18 },
					Color = { 255, 240, 210 },
				},
				{
					Texture = "Smoke",
					Count = 6,
					Lifetime = { 0.9, 1.5 },
					Size = { 3, 7 },
					Speed = { 3, 8 },
					Color = { 70, 66, 62 },
					Fade = { 0.35, 1 },
					Glow = 0,
					Gravity = -3,
					Drag = 2,
					Rotation = { 0, 360 },
					Spin = { -40, 40 },
				},
			},
		},

		-- Münze oder Gegenstand eingesammelt: Sterne steigen auf.
		Collect = {
			Layers = {
				{
					Texture = "Star",
					Count = 6,
					Lifetime = { 0.45, 0.7 },
					Size = { 0.9, 0.1 },
					Speed = { 6, 12 },
					Spread = 70,
					Color = { 255, 221, 87 },
					Gravity = 14,
					Rotation = { 0, 360 },
					Spin = { -180, 180 },
				},
				{
					Texture = "RingGrow",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.3, 0.3 },
					Size = { 3, 4 },
					Color = { 255, 240, 170 },
				},
			},
		},

		-- Heilung oder Stärkung: sanfter Ring und aufsteigende Lichtpunkte.
		Heal = {
			Layers = {
				{
					Texture = "RingGrow",
					Flipbook = 4,
					Count = 1,
					Lifetime = { 0.6, 0.6 },
					Size = { 6, 8 },
					Color = { 120, 255, 160 },
				},
				{
					Texture = "Glow",
					Count = 10,
					Lifetime = { 0.6, 1 },
					Size = { 0.5, 0.1 },
					Speed = { 3, 7 },
					Spread = 35,
					Color = { 150, 255, 180 },
					Gravity = -6,
				},
			},
		},

		-- Staub beim Landen oder Rennen.
		Dust = {
			Layers = {
				{
					Texture = "Smoke",
					Count = 4,
					Lifetime = { 0.4, 0.7 },
					Size = { 1.2, 3 },
					Speed = { 2, 5 },
					Spread = 80,
					Color = { 190, 180, 165 },
					Fade = { 0.5, 1 },
					Glow = 0,
					Drag = 3,
					Rotation = { 0, 360 },
				},
			},
		},

		-- Sieg, Level-Aufstieg: Sterne in alle Richtungen.
		Celebrate = {
			Layers = {
				{
					Texture = "Star",
					Count = 24,
					Lifetime = { 0.8, 1.4 },
					Size = { 1.1, 0.2 },
					Speed = { 12, 24 },
					Color = { 255, 214, 92 },
					ColorEnd = { 255, 120, 200 },
					Gravity = 26,
					Drag = 1,
					Rotation = { 0, 360 },
					Spin = { -220, 220 },
				},
				{
					Texture = "Glow",
					Count = 1,
					Lifetime = { 0.3, 0.3 },
					Size = { 8, 14 },
					Color = { 255, 240, 200 },
					Fade = { 0.3, 1 },
				},
			},
		},
	} :: { [string]: Effect },
}

return Effects
