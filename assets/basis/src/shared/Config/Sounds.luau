--!strict
--[[
	Sounds – alle Töne und die Musik des Spiels an einer Stelle.

	Abgespielt wird über den Namen (siehe SoundController):
	  Client:  SoundController:Play("Coin")
	  Server:  Net.Fire("Sound.Play", player, "Coin")

	Eine leere Id ("") heißt „noch kein Ton ausgesucht": Es bleibt still, ohne Fehler.
	Töne sucht man in Studio (Toolbox → Audio) oder über das Studio-MCP (`search_asset`)
	und trägt die Id als "rbxassetid://123456" ein. Nur Töne verwenden, die für das
	Spiel freigegeben sind (eigene oder von Roblox bereitgestellte).

	Neue Töne: einfach einen Eintrag ergänzen. Kein Code nötig.
]]

export type Sound = {
	Id: string,
	Volume: number?, -- 0 bis 1 (Standard 0.5)
	Speed: number?, -- Abspieltempo/Tonhöhe (Standard 1)
	SpeedVariation: number?, -- zufällige Abweichung, z. B. 0.08: klingt bei Wiederholung weniger eintönig
}

local Sounds = {
	Effects = {
		-- Diese Namen benutzt das Grundprojekt von selbst:
		Click = { Id = "", Volume = 0.4 }, -- jeder Kit.Button
		Notify = { Id = "", Volume = 0.4 }, -- Meldung "Info"
		Success = { Id = "", Volume = 0.5 }, -- Meldung "Success"
		Error = { Id = "", Volume = 0.5 }, -- Meldung "Error"
		Announcement = { Id = "", Volume = 0.6 }, -- Meldung "Announcement"

		-- Typische Töne fürs Spiel (nach Bedarf benutzen, umbenennen, ergänzen):
		Coin = { Id = "", Volume = 0.45, SpeedVariation = 0.08 },
		Purchase = { Id = "", Volume = 0.5 },
		LevelUp = { Id = "", Volume = 0.6 },
		Hit = { Id = "", Volume = 0.5, SpeedVariation = 0.1 }, -- Treffer (Kampf-Genres)
		Swing = { Id = "", Volume = 0.4, SpeedVariation = 0.1 }, -- Schlag in die Luft
		Shot = { Id = "", Volume = 0.4, SpeedVariation = 0.06 }, -- Schuss (Türme)
		Win = { Id = "", Volume = 0.6 }, -- Runde, Level, Rennen, Dungeon geschafft
	} :: { [string]: Sound },

	-- Hintergrundmusik: wird der Reihe nach gespielt und beginnt dann von vorn. Leer = keine Musik.
	Music = {} :: { Sound },

	MusicFadeSeconds = 1.5,

	-- Wie weit ein Ton in der Welt zu hören ist (SoundController:PlayAt).
	WorldMinDistance = 12,
	WorldMaxDistance = 140,
}

return Sounds
