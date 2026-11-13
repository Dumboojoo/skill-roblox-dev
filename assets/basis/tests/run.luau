--[[
	Testlauf für reine Logik-Module (ohne Roblox-Dienste), ausgeführt mit Lune:

	    lune run tests/run.luau

	Jede Datei tests/<Name>.spec.luau gibt eine Funktion zurück, die Tests anmeldet:

	    return function(t)
	        t.test("addiert", function()
	            t.equal(1 + 1, 2)
	        end)
	    end

	Testbar ist alles, was weder `game` noch `script` benutzt: Parser, Formeln,
	Migrationen, Inventar-Logik, Wellen-Berechnung. Solche Logik bewusst in eigene
	Module ohne Roblox-Abhängigkeiten legen, dann lässt sie sich hier absichern.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function show(value: any): string
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for key, child in value do
		table.insert(parts, `{tostring(key)}={show(child)}`)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

local passed, failed = 0, 0
local currentFile = ""

local t = {}

function t.test(name: string, body: () -> ())
	local ok, problem = pcall(body)
	if ok then
		passed += 1
	else
		failed += 1
		print(`  FEHLGESCHLAGEN  {currentFile}: {name}\n      {problem}`)
	end
end

function t.equal(actual: any, expected: any, message: string?)
	if not deepEqual(actual, expected) then
		error(`{message or "Werte ungleich"}: erwartet {show(expected)}, bekommen {show(actual)}`, 2)
	end
end

function t.truthy(value: any, message: string?)
	if not value then
		error(message or "sollte wahr sein", 2)
	end
end

function t.falsy(value: any, message: string?)
	if value then
		error(message or "sollte falsch sein", 2)
	end
end

local files = fs.readDir("tests")
table.sort(files)
for _, file in files do
	local name = string.match(file, "^(.+%.spec)%.luau$")
	if name then
		currentFile = file
		local register = (require :: any)("./" .. name)
		register(t)
	end
end

print(`{passed} bestanden, {failed} fehlgeschlagen`)
process.exit(if failed > 0 then 1 else 0)
