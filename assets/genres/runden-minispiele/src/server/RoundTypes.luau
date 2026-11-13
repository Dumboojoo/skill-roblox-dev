--!strict
--[[
	Die Schnittstelle, die jedes Minispiel erfüllt.

	Ein Minispiel ist eine Datei in server/Minigames, die eine Tabelle zurückgibt:

	    return {
	        DisplayName = "Heiße Kartoffel",
	        Description = "Gib die Kartoffel weiter, bevor sie explodiert!",
	        Duration = 90,
	        Start = function(context) ... end,
	    }

	`Start` richtet das Spiel ein und kehrt sofort zurück. Alles, was es anlegt
	(Verbindungen, Teile, Schleifen), kommt in context.Trove und wird am Rundenende
	automatisch aufgeräumt. Deshalb braucht ein Minispiel keine Stop-Funktion.

	Der RoundService beendet die Runde von selbst, wenn die Zeit um ist (alle
	Überlebenden gewinnen) oder nur noch einer übrig ist. Ein Minispiel mit eigenem
	Ziel (z. B. Wettlauf) ruft context.Finish(sieger) auf.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Util.Trove)

export type Context = {
	Map: Model,
	Trove: Trove.Trove,
	-- Aktuelle Liste der Spieler, die noch dabei sind (nicht verändern).
	Alive: () -> { Player },
	IsAlive: (player: Player) -> boolean,
	-- Wirft einen Spieler aus der Runde und bringt ihn in die Lobby.
	Eliminate: (player: Player) -> (),
	-- Beendet die Runde sofort mit diesen Siegern.
	Finish: (winners: { Player }) -> (),
	TimeLeft: () -> number,
}

export type Minigame = {
	DisplayName: string,
	Description: string,
	Duration: number,
	Start: (context: Context) -> (),
}

return {}
