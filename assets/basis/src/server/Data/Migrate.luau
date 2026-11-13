--!strict
--[[
	Migrate – bringt einen geladenen Spielstand auf die aktuelle Version.

	Reines Luau ohne Roblox-Dienste (testbar außerhalb von Studio). Arbeitet auf
	einer Kopie: Schlägt ein Schritt fehl, bleibt der Original-Spielstand unberührt.
]]

export type Step = (data: { [string]: any }) -> ()

local Migrate = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Rückgabe: (true, migrierteKopie) oder (false, Fehlertext)
function Migrate.Run(data: { [string]: any }, targetVersion: number, steps: { [number]: Step }): (boolean, any)
	local storedVersion = data._Version
	local current = if type(storedVersion) == "number" then storedVersion else 1

	if current > targetVersion then
		-- Ein älterer Server darf einen neueren Spielstand nicht anfassen (würde Daten zerstören).
		return false, `Spielstand hat Version {current}, dieser Server kennt nur {targetVersion}`
	end

	local copy = deepCopy(data)
	for version = current + 1, targetVersion do
		local step = steps[version]
		if step then
			local ok, problem = pcall(step :: any, copy)
			if not ok then
				return false, `Migration auf Version {version} fehlgeschlagen: {problem}`
			end
		end
	end
	copy._Version = targetVersion
	return true, copy
end

return Migrate
