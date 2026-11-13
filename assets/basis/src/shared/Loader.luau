--!strict
--[[
	Loader – lädt alle Module eines Ordners und startet sie in zwei Phasen.

	Ein Service (Server) bzw. Controller (Client) ist ein ModuleScript, das eine
	Tabelle zurückgibt. Optional:

	  Priority: number   kleinere Zahl = früher dran (Standard 100)
	  Init(self)         Phase 1: eigene Dinge vorbereiten (Remotes anlegen, Tabellen
	                     füllen). Nicht warten (kein task.wait/WaitForChild) und noch
	                     keine anderen Services benutzen.
	  Start(self)        Phase 2: läuft, nachdem ALLE Init fertig sind. Hier darf
	                     alles benutzt und auch gewartet werden.

	Neues Feature = neue Datei im Ordner. Es muss nirgends eingetragen werden.
]]

local Loader = {}

local DEFAULT_PRIORITY = 100
local SLOW_INIT_SECONDS = 0.2

local function describe(problem: any): string
	return debug.traceback(tostring(problem), 2)
end

function Loader.Load(folder: Instance, label: string): { [string]: any }
	local entries: { { Name: string, Module: any, Priority: number } } = {}

	for _, child in folder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		-- `require` über eine Variable: bewusst dynamisch, daher der any-Umweg.
		local ok, result = xpcall(require :: any, describe, child)
		if not ok then
			warn(`[{label}] {child.Name} konnte nicht geladen werden:\n{result}`)
		elseif type(result) ~= "table" then
			warn(`[{label}] {child.Name} gibt keine Tabelle zurück und wird übersprungen.`)
		else
			local priority = if type(result.Priority) == "number" then result.Priority else DEFAULT_PRIORITY
			table.insert(entries, { Name = child.Name, Module = result, Priority = priority })
		end
	end

	table.sort(entries, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority < b.Priority
		end
		return a.Name < b.Name
	end)

	local modules: { [string]: any } = {}
	for _, entry in entries do
		modules[entry.Name] = entry.Module
	end

	for _, entry in entries do
		local init = entry.Module.Init
		if type(init) == "function" then
			local started = os.clock()
			local ok, problem = xpcall(init, describe, entry.Module)
			if not ok then
				warn(`[{label}] {entry.Name}:Init ist fehlgeschlagen:\n{problem}`)
			elseif os.clock() - started > SLOW_INIT_SECONDS then
				warn(`[{label}] {entry.Name}:Init hat lange gebraucht. Wartendes gehört in Start.`)
			end
		end
	end

	for _, entry in entries do
		local start = entry.Module.Start
		if type(start) == "function" then
			task.spawn(function()
				local ok, problem = xpcall(start, describe, entry.Module)
				if not ok then
					warn(`[{label}] {entry.Name}:Start ist fehlgeschlagen:\n{problem}`)
				end
			end)
		end
	end

	return modules
end

return Loader
