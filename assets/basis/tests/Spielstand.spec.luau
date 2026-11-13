--[[
	Prüft, ob jeder Spielstand-Pfad, den der Code benutzt, in der Vorlage existiert.

	Ein Tippfehler wie DataService:Increment(player, "Curency.Coins", 5) fällt weder der
	Typprüfung noch dem Stil-Prüfer auf, sondern erst im laufenden Spiel. Dieser Test liest
	deshalb alle Dateien unter src/, sammelt die Pfade aus

	    DataService:Get/Set/Update/Increment/Observe(spieler, PFAD, ...)
	    DataController:Get/Observe(PFAD, ...)
	    Leaderstats = { { Path = PFAD } }   (in Config/DataSections)

	und gleicht sie mit der zusammengesetzten Vorlage aus Config/DataSections ab.

	Erkannt werden feste Texte ("Rpg.Level"), Texte mit Einsetzung (`Rpg.Quests.{id}` – geprüft
	wird der feste Anfang) und Listen ({ "Rpg", "Quests", id }). Pfade aus Variablen kann der
	Test nicht sehen. Unterhalb einer leeren Tabelle der Vorlage (z. B. Owned = {}) ist jeder
	Schlüssel erlaubt, weil solche Tabellen erst im Spiel gefüllt werden.
]]

local fs = require("@lune/fs")

local SECTIONS = "src/shared/Config/DataSections"

local function luauFiles(folder: string, into: { string })
	for _, name in fs.readDir(folder) do
		local path = folder .. "/" .. name
		if fs.isDir(path) then
			if name ~= "Packages" then
				luauFiles(path, into)
			end
		elseif string.match(name, "%.luau$") then
			table.insert(into, path)
		end
	end
end

-- Entfernt Kommentare, damit Beispiele in Erklärtexten nicht mitgeprüft werden.
local function stripComments(source: string): string
	source = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", function()
		return ""
	end)
	local lines = {}
	for _, line in string.split(source, "\n") do
		local index = string.find(line, "--", 1, true)
		table.insert(lines, if index then string.sub(line, 1, index - 1) else line)
	end
	return table.concat(lines, "\n")
end

-- Liest ab `start` einen Pfad-Ausdruck. Gibt die festen Segmente zurück und ob der Pfad
-- danach mit veränderlichen Teilen weitergeht. nil: kein fester Pfad (Variable).
local function readPath(text: string, start: number): ({ string }?, boolean)
	local first = string.sub(text, start, start)
	if first == '"' then
		local literal = string.match(text, '^"([^"\n]*)"', start)
		if not literal then
			return nil, false
		end
		return string.split(literal, "."), false
	elseif first == "`" then
		local literal = string.match(text, "^`([^`\n]*)`", start)
		if not literal then
			return nil, false
		end
		local fixed = string.match(literal, "^([^{]*)") or ""
		local dynamic = #fixed < #literal
		local segments = string.split(fixed, ".")
		if dynamic then
			-- Das letzte Stück ist unvollständig ("Quests." + Einsetzung) und zählt nicht.
			table.remove(segments)
		end
		return segments, dynamic
	elseif first == "{" then
		local body = string.match(text, "^(%b{})", start)
		if not body then
			return nil, false
		end
		local segments = {}
		local dynamic = false
		for part in string.gmatch(string.sub(body, 2, -2), "[^,]+") do
			local literal = string.match(part, '^%s*"([^"]*)"%s*$')
			if literal and not dynamic then
				table.insert(segments, literal)
			else
				dynamic = true
			end
		end
		return segments, dynamic
	end
	return nil, false
end

type Usage = { Segments: { string }, Dynamic: boolean, Where: string }

local function collect(path: string, text: string, into: { Usage })
	local function add(position: number, pathStart: number)
		local segments, dynamic = readPath(text, pathStart)
		if segments and #segments > 0 then
			local _, lineBreaks = string.gsub(string.sub(text, 1, position), "\n", "")
			table.insert(into, { Segments = segments, Dynamic = dynamic, Where = `{path}:{lineBreaks + 1}` })
		end
	end

	-- DataService:Methode(spieler, PFAD ...): der Pfad ist das zweite Argument.
	for _, method in { "Get", "Set", "Update", "Increment", "Observe" } do
		local search = 1
		while true do
			local from, to = string.find(text, "DataService:" .. method .. "%(%s*[%w_%.]+%s*,%s*", search)
			if not from or not to then
				break
			end
			add(from, to + 1)
			search = to + 1
		end
	end
	-- DataController:Methode(PFAD ...): der Pfad ist das erste Argument.
	for _, method in { "Get", "Observe" } do
		local search = 1
		while true do
			local from, to = string.find(text, "DataController:" .. method .. "%(%s*", search)
			if not from or not to then
				break
			end
			add(from, to + 1)
			search = to + 1
		end
	end
end

-- nil: Pfad ist in Ordnung. Sonst das erste Segment, das es nicht gibt.
local function missingSegment(template: any, usage: Usage): string?
	local current = template
	for _, segment in usage.Segments do
		if type(current) ~= "table" then
			return segment
		end
		if next(current) == nil then
			return nil -- leere Tabelle: wird erst im Spiel gefüllt
		end
		local key: any = segment
		if current[key] == nil and tonumber(segment) then
			key = tonumber(segment)
		end
		if current[key] == nil then
			return segment
		end
		current = current[key]
	end
	return nil
end

return function(t)
	local template: { [string]: any } = {}
	local leaderstats: { Usage } = {}
	local sectionProblems: { string } = {}

	if fs.isDir(SECTIONS) then
		local names = fs.readDir(SECTIONS)
		table.sort(names)
		for _, name in names do
			local moduleName = string.match(name, "^(.+)%.luau$")
			if not moduleName then
				continue
			end
			local section = (require :: any)("../" .. SECTIONS .. "/" .. moduleName)
			for key, value in section.Template do
				if template[key] ~= nil then
					table.insert(sectionProblems, `DataSections/{name}: Schlüssel "{key}" ist doppelt vergeben`)
				end
				template[key] = value
			end
			for _, spec in section.Leaderstats or {} do
				table.insert(leaderstats, {
					Segments = string.split(spec.Path, "."),
					Dynamic = false,
					Where = `{SECTIONS}/{name} (Leaderstats "{spec.Name}")`,
				})
			end
		end
	end

	t.test("Spielstand: kein Oberschlüssel ist doppelt vergeben", function()
		t.equal(sectionProblems, {})
	end)

	t.test("Spielstand: Leaderstats zeigen auf vorhandene Zahlen", function()
		local problems = {}
		for _, usage in leaderstats do
			local current: any = template
			for _, segment in usage.Segments do
				current = if type(current) == "table" then current[segment] else nil
			end
			if type(current) ~= "number" then
				table.insert(
					problems,
					`{usage.Where}: "{table.concat(usage.Segments, ".")}" ist keine Zahl in der Vorlage`
				)
			end
		end
		t.equal(problems, {})
	end)

	t.test("Spielstand: jeder im Code benutzte Pfad steht in der Vorlage", function()
		local files: { string } = {}
		luauFiles("src", files)
		table.sort(files)
		local usages: { Usage } = {}
		for _, path in files do
			collect(path, stripComments(fs.readFile(path)), usages)
		end

		local problems = {}
		for _, usage in usages do
			local missing = missingSegment(template, usage)
			if missing then
				local shown = table.concat(usage.Segments, ".")
				table.insert(
					problems,
					`{usage.Where}: "{shown}" – "{missing}" fehlt in der Vorlage (Config/DataSections)`
				)
			end
		end
		if #problems > 0 then
			error("\n      " .. table.concat(problems, "\n      "), 0)
		end
	end)
end
