--!strict
--[[
	Leaderboards – welche globalen Ranglisten es gibt.

	Jede Rangliste liest einen Zahlenwert aus dem Spielstand (Path). Der
	LeaderboardService schreibt ihn regelmäßig in einen eigenen OrderedDataStore
	und liest daraus die besten Spieler aller Server.

	Welt-Vertrag (optional):
	  Tag LeaderboardBoard  BasePart  Attribut Board (Schlüssel aus Boards).
	                        Der Server legt auf die Vorderseite eine Tafel mit der Rangliste.

	Ranglisten speichern nur ganze Zahlen. Zeiten deshalb mit Scale = 1000 als
	Millisekunden ablegen; bei Ascending = true gewinnt der kleinste Wert, und
	Einträge mit 0 (noch keine Zeit) werden nicht aufgenommen.
]]

export type Board = {
	DisplayName: string,
	Path: string, -- Pfad im Spielstand
	Ascending: boolean, -- true = kleinster Wert zuerst (Bestzeiten)
	Scale: number, -- Wert wird damit multipliziert und gerundet gespeichert
	Format: string, -- "Number" | "Time"
}

local Boards: { [string]: Board } = {
	PlayTime = {
		DisplayName = "Meiste Spielzeit",
		Path = "Stats.PlayTime",
		Ascending = false,
		Scale = 1,
		Format = "Time",
	},
	-- Beispiele für die Genres:
	-- Kills = { DisplayName = "Meiste Kills", Path = "Shooter.Kills", Ascending = false, Scale = 1, Format = "Number" },
	-- ObbyTime = { DisplayName = "Schnellster Lauf", Path = "Obby.BestTime", Ascending = true, Scale = 1000, Format = "Time" },
}

return {
	Boards = Boards,
	TopCount = 20, -- so viele Plätze werden angezeigt
	RefreshSeconds = 120, -- wie oft gelesen und geschrieben wird (nicht unter 60: Anfragegrenzen)
	StoreVersion = "v1", -- erhöhen, um alle Ranglisten zurückzusetzen
}
