--!strict
--[[
	Adventure – Level, Dialoge und Belohnungen.

	Ein Adventure besteht aus einem Hub und mehreren Leveln, die nacheinander
	freigeschaltet werden. In jedem Level: Weg zum Ziel finden, Rätsel lösen,
	versteckte Edelsteine sammeln, mit Figuren sprechen.

	Welt-Vertrag:
	  Tag HubSpawn            BasePart  Startpunkt im Hub
	  Tag LevelStart          BasePart  Attribut Level (string): Startpunkt des Levels
	  Tag LevelGoal           BasePart  Attribut Level (string): Berühren schließt das Level ab
	  Tag AdventureCheckpoint BasePart  Zwischenspeicher im Level (gilt bis zum Verlassen)
	  Tag Hazard              BasePart  tödlich (zurück zum letzten Checkpoint)
	  Tag Gem                 BasePart  Attribute Level (string), GemId (string, im Level eindeutig)
	  Tag Npc                 BasePart/Model  Attribute Dialog (Schlüssel aus Dialogs), DisplayName (string)

	Rätsel-Baukasten (Schalter und Empfänger sind über einen Kanal-Namen verbunden):
	  Tag Activator  BasePart  Attribute Channel (string), Kind (string):
	                   "Lever"   Hebel, per Interaktion an/aus
	                   "Plate"   Druckplatte, an, solange jemand darauf steht
	                   "Button"  Knopf, bleibt nach dem Drücken an
	  Tag Receiver   BasePart  Attribute Channel (string), Action (string):
	                   "Open"       fährt nach oben weg (Tor, Gitter)
	                   "Appear"     wird sichtbar und fest (Brücke)
	                   "Disappear"  verschwindet (Barriere)
	                 optional Needs (number): so viele Schalter des Kanals müssen an sein
	                 (Standard: alle)

	Beispiele: Zwei Druckplatten auf einem Kanal + ein Tor = Koop-Rätsel.
	Ein Hebel + eine Brücke mit "Appear" = Weg freischalten.
]]

export type Level = {
	Id: string,
	DisplayName: string,
	Description: string,
}

-- Reihenfolge = Freischalt-Reihenfolge. Das erste Level ist immer offen.
local Levels: { Level } = {
	{ Id = "Forest", DisplayName = "Der Flüsterwald", Description = "Finde den Weg durch den Wald." },
	{ Id = "Cave", DisplayName = "Die Kristallhöhle", Description = "Tief unten wartet ein Rätsel." },
	{ Id = "Tower", DisplayName = "Der Sturmturm", Description = "Ganz nach oben." },
}

-- Jede Zeile ist ein Bildschirm im Dialogfenster.
local Dialogs: { [string]: { string } } = {
	Guide = {
		"Da bist du ja! Der Wald ist nicht mehr sicher.",
		"Hebel öffnen Tore. Manche Platten brauchen aber zwei Abenteurer.",
		"Halte die Augen offen: Überall sind Edelsteine versteckt.",
	},
}

return {
	Levels = Levels,
	Dialogs = Dialogs,

	LevelReward = 50, -- Münzen beim ersten Abschluss eines Levels
	GemReward = 10, -- Münzen pro Edelstein
	ReturnDelay = 4, -- Sekunden nach dem Ziel, bis es zurück in den Hub geht
}
