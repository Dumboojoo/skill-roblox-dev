--!strict
--[[
	Rounds – Zeiten und Belohnungen des Rundenablaufs.

	Welt-Vertrag:
	  Tag LobbySpawn      BasePart  wohin Spieler zwischen den Runden kommen
	  Tag MinigameMap     Model     Attribut Minigame (string) = Name der Minispiel-Datei
	                                in server/Minigames (z. B. "HotPotato")
	  Tag MinigameSpawn   BasePart  Startpunkte, innerhalb des jeweiligen Map-Models

	Ein Minispiel wird nur zur Wahl gestellt, wenn es eine Map dafür gibt.
	Zusätzliche Teile, die ein Minispiel braucht, stehen in dessen Datei
	(RisingLava erwartet z. B. ein Teil namens "Lava" in der Map).
]]

return {
	-- Zum Testen allein in Studio 1; für das veröffentlichte Spiel mindestens 2.
	MinPlayers = 1,

	Intermission = 12,
	VoteTime = 10,
	VoteOptions = 3,
	ResultTime = 6,

	PlayCoins = 5, -- fürs Mitspielen
	WinCoins = 25, -- zusätzlich für Sieger
}
