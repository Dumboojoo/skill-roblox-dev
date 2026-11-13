--!strict
--[[
	Daily – Regeln der täglichen Belohnung, ohne Roblox-Dienste (getestet in
	tests/Monetarisierung.spec.luau).

	Gerechnet wird in Tagesnummern (Tage seit 1970, UTC). Der Server benutzt
	os.time(); der Client rechnet nur für die Anzeige mit.
]]

local SECONDS_PER_DAY = 86400

local Daily = {}

function Daily.DayNumber(unixTime: number): number
	return math.floor(unixTime / SECONDS_PER_DAY)
end

-- Sekunden bis zum nächsten Tageswechsel (für "Wieder verfügbar in …").
function Daily.SecondsUntilNextDay(unixTime: number): number
	return SECONDS_PER_DAY - unixTime % SECONDS_PER_DAY
end

--[[
	Rückgabe: darfAbholen, TagDerReihe (1 bis cycleLength)

	lastDay   Tagesnummer der letzten Abholung (0 = noch nie)
	streak    Tag der Reihe bei der letzten Abholung
	today     heutige Tagesnummer
]]
function Daily.Status(lastDay: number, streak: number, today: number, cycleLength: number): (boolean, number)
	if lastDay >= today then
		return false, streak -- heute schon abgeholt (oder Uhr verstellt)
	end
	if lastDay == today - 1 then
		-- Gestern abgeholt: Reihe geht weiter und beginnt nach dem letzten Tag von vorn.
		return true, streak % cycleLength + 1
	end
	return true, 1 -- Tag verpasst oder erste Abholung
end

return Daily
