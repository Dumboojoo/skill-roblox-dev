--[[
	Prüft, ob jeder Ton-Name, den der Code abspielt, in Config/Sounds steht.

	SoundController:Play("Koin") bleibt im Spiel einfach still. Dieser Test findet solche
	Tippfehler vorher. Gesucht wird nach festen Namen in

	    SoundController:Play("NAME") / :PlayAt("NAME", ...) / :PlayMusic("NAME")
	    Net.Fire("Sound.Play", spieler, "NAME") und die anderen Net.Fire…-Formen

	Direkte Ids ("rbxassetid://…") und Namen aus Variablen werden übersprungen.
]]

local fs = require("@lune/fs")

local Sounds = (require :: any)("../src/shared/Config/Sounds")

local function luauFiles(folder: string, into: { string })
	if not fs.isDir(folder) then
		return
	end
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

local function stripComments(source: string): string
	source = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", function(_level: string)
		return ""
	end)
	local lines = {}
	for _, line in string.split(source, "\n") do
		local index = string.find(line, "--", 1, true)
		table.insert(lines, if index then string.sub(line, 1, index - 1) else line)
	end
	return table.concat(lines, "\n")
end

local PATTERNS = {
	'SoundController:Play%(%s*"([^"]*)"',
	'SoundController:PlayAt%(%s*"([^"]*)"',
	'SoundController:PlayMusic%(%s*"([^"]*)"',
	-- Net.Fire("Sound.Play", player, "NAME") / Net.FireAll("Sound.Play", "NAME") /
	-- Net.FireNear("Sound.Play", position, radius, "NAME", ...): der erste feste Text danach.
	'"Sound%.Play"[^"\n]*"([^"]*)"',
}

return function(t)
	t.test("Ton: jeder abgespielte Name steht in Config/Sounds", function()
		local files: { string } = {}
		luauFiles("src", files)
		table.sort(files)

		local problems = {}
		for _, path in files do
			local text = stripComments(fs.readFile(path))
			for _, pattern in PATTERNS do
				for name in string.gmatch(text, pattern) do
					local isId = string.sub(name, 1, 3) == "rbx" or string.sub(name, 1, 4) == "http"
					if name ~= "" and not isId and Sounds.Effects[name] == nil then
						table.insert(problems, `{path}: Ton "{name}" fehlt in Config/Sounds (Effects)`)
					end
				end
			end
		end
		if #problems > 0 then
			error("\n      " .. table.concat(problems, "\n      "), 0)
		end
	end)

	t.test("Ton: Einträge haben eine Id (auch wenn sie noch leer ist)", function()
		local problems = {}
		for name, spec in Sounds.Effects do
			if type(spec) ~= "table" or type(spec.Id) ~= "string" then
				table.insert(problems, `Effects.{name}: Feld Id (Text) fehlt`)
			end
		end
		for index, spec in Sounds.Music do
			if type(spec) ~= "table" or type(spec.Id) ~= "string" then
				table.insert(problems, `Music[{index}]: Feld Id (Text) fehlt`)
			end
		end
		t.equal(problems, {})
	end)
end
