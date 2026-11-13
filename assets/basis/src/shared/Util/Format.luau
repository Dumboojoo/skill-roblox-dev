--!strict
-- Format – Zahlen und Zeiten für die Anzeige aufbereiten.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 15300000 -> "15.3M". Für Simulator-Zahlen, die schnell riesig werden.
function Format.Number(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	local absolute = math.abs(value)
	if absolute < 1000 then
		return sign .. tostring(math.floor(absolute))
	end
	local tier = math.min(math.floor(math.log10(absolute) / 3), #SUFFIXES - 1)
	local scaled = absolute / 10 ^ (tier * 3)
	-- Drei signifikante Stellen, abgeschnitten statt gerundet (nie mehr anzeigen, als man hat).
	local decimals = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
	local factor = 10 ^ decimals
	local text = string.format("%." .. decimals .. "f", math.floor(scaled * factor) / factor)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

-- 1234567 -> "1,234,567"
function Format.Commas(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local result = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	result = string.gsub(result, "^,", "")
	return if value < 0 then "-" .. result else result
end

-- 75 -> "1:15", 3723 -> "1:02:03"
function Format.Time(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- 75.318 -> "1:15.31" (Bestzeiten in Obbys und Rennen)
function Format.TimeMs(seconds: number): string
	local clamped = math.max(0, seconds)
	local minutes = math.floor(clamped) // 60
	local rest = clamped - minutes * 60
	local whole = math.floor(rest)
	local hundredths = math.floor((rest - whole) * 100)
	return string.format("%d:%02d.%02d", minutes, whole, hundredths)
end

-- 0.256 -> "25.6%"
function Format.Percent(fraction: number, decimals: number?): string
	return string.format("%." .. (decimals or 1) .. "f%%", fraction * 100)
end

return Format
