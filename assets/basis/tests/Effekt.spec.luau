--[[
	Prüft die Effekte: Jeder im Code abgespielte Name steht in Config/Effects, jedes Bild
	einer Schicht steht in Config/AssetIds, und die Zahlen ergeben Sinn.

	Gesucht wird nach festen Namen in
	    EffectController:Play("NAME", ...) / :PlayOn("NAME", ...)
	    Net.Fire…("Effect.Play", ..., "NAME", ...)
	Namen aus Variablen kann der Test nicht sehen.
]]

local fs = require("@lune/fs")

local Effects = (require :: any)("../src/shared/Config/Effects")
local AssetIds = (require :: any)("../src/shared/Config/AssetIds")

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
	'EffectController:Play%(%s*"([^"]*)"',
	'EffectController:PlayOn%(%s*"([^"]*)"',
	'"Effect%.Play"[^"\n]*"([^"]*)"',
}

local function isPair(value: any, low: number, high: number): boolean
	if type(value) ~= "table" or type(value[1]) ~= "number" then
		return false
	end
	for _, number in value do
		if type(number) ~= "number" or number < low or number > high then
			return false
		end
	end
	return true
end

return function(t)
	t.test("Effekt: jeder abgespielte Name steht in Config/Effects", function()
		local files: { string } = {}
		luauFiles("src", files)
		table.sort(files)

		local problems = {}
		for _, path in files do
			local text = stripComments(fs.readFile(path))
			for _, pattern in PATTERNS do
				for name in string.gmatch(text, pattern) do
					if name ~= "" and Effects.List[name] == nil then
						table.insert(problems, `{path}: Effekt "{name}" fehlt in Config/Effects (List)`)
					end
				end
			end
		end
		if #problems > 0 then
			error("\n      " .. table.concat(problems, "\n      "), 0)
		end
	end)

	t.test("Effekt: Schichten sind vollständig und plausibel", function()
		local problems = {}
		for name, effect in Effects.List do
			if type(effect.Layers) ~= "table" or #effect.Layers == 0 then
				table.insert(problems, `{name}: braucht mindestens eine Schicht (Layers)`)
				continue
			end
			for index, layer in effect.Layers do
				local where = `{name}, Schicht {index}`
				local texture = layer.Texture
				if type(texture) ~= "string" then
					table.insert(problems, `{where}: Texture fehlt`)
				elseif AssetIds.Effects[texture] == nil and string.sub(texture, 1, 3) ~= "rbx" then
					table.insert(problems, `{where}: Bild "{texture}" fehlt in Config/AssetIds (Effects)`)
				end
				if layer.Flipbook ~= nil and layer.Flipbook ~= 2 and layer.Flipbook ~= 4 and layer.Flipbook ~= 8 then
					table.insert(problems, `{where}: Flipbook muss 2, 4 oder 8 sein`)
				end
				if type(layer.Count) ~= "number" or layer.Count < 1 or layer.Count > 200 then
					table.insert(problems, `{where}: Count muss zwischen 1 und 200 liegen`)
				end
				if not isPair(layer.Lifetime, 0.01, 10) then
					table.insert(problems, `{where}: Lifetime braucht Sekunden zwischen 0.01 und 10`)
				end
				if not isPair(layer.Size, 0, 100) then
					table.insert(problems, `{where}: Size braucht Studs zwischen 0 und 100`)
				end
				if not isPair(layer.Color, 0, 255) or #layer.Color ~= 3 then
					table.insert(problems, `{where}: Color braucht drei Werte von 0 bis 255`)
				end
				if layer.ColorEnd ~= nil and (not isPair(layer.ColorEnd, 0, 255) or #layer.ColorEnd ~= 3) then
					table.insert(problems, `{where}: ColorEnd braucht drei Werte von 0 bis 255`)
				end
				if layer.Front ~= nil and (type(layer.Front) ~= "number" or layer.Front < -20 or layer.Front > 20) then
					table.insert(problems, `{where}: Front braucht eine Zahl von -20 bis 20`)
				end
				if layer.Fade ~= nil and not isPair(layer.Fade, 0, 1) then
					table.insert(problems, `{where}: Fade braucht Werte von 0 bis 1`)
				end
			end
		end
		t.equal(problems, {})
	end)

	t.test("Effekt: Asset-Nummern haben die richtige Form", function()
		local problems = {}
		for group, list in AssetIds do
			for key, id in list do
				if type(id) ~= "string" then
					table.insert(problems, `AssetIds.{group}.{key}: muss ein Text sein`)
				elseif id ~= "" and not string.match(id, "^rbxassetid://%d+$") then
					table.insert(problems, `AssetIds.{group}.{key}: "{id}" hat nicht die Form rbxassetid://123456`)
				end
			end
		end
		t.equal(problems, {})
	end)
end
