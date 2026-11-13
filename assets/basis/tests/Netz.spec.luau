--[[
	Prüft, ob Client und Server über dieselben Remotes sprechen.

	Ein Remote-Name ist nur ein Text. Schreibt der Client Net.Send("Shop.Buy", ...) und der
	Server Net.On("Shop.Kauf", ...), meldet das keine Typprüfung – im Spiel passiert einfach
	nichts. Dieser Test liest alle Dateien unter src/ und prüft:

	  - Net.Send(name)   hat ein Net.On(name) auf dem Server
	  - Net.Call(name)   hat ein Net.OnInvoke(name) auf dem Server
	  - Net.Listen(name) hat ein Net.Fire…(name) oder Net.Declare(name) auf dem Server
	  - Net.Send/Call schicken so viele Werte, wie der Server Prüfer angegeben hat
	  - Server-Funktionen stehen nicht im Client-Code und umgekehrt

	Namen aus einfachen Konstanten derselben Datei (local SYNC = "Data.Sync") werden aufgelöst.
	Namen, die erst zur Laufzeit entstehen, kann der Test nicht sehen.
]]

local fs = require("@lune/fs")

local SERVER_ONLY =
	{ On = true, OnInvoke = true, Declare = true, Fire = true, FireAll = true, FireExcept = true, FireNear = true }
local FIRE = { "Fire", "FireAll", "FireExcept", "FireNear", "Declare" }
local METHODS = { "On", "OnInvoke", "Declare", "Fire", "FireAll", "FireExcept", "FireNear", "Send", "Call", "Listen" }

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
		elseif string.match(name, "%.luau$") and name ~= "Net.luau" then
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

-- Zerlegt "a, { b, c }, f(d, e)" an den Kommas der obersten Ebene.
local function splitArguments(inner: string): { string }
	local arguments = {}
	local depth = 0
	local quote: string? = nil
	local current = ""
	for index = 1, #inner do
		local character = string.sub(inner, index, index)
		if quote then
			if character == quote then
				quote = nil
			end
			current ..= character
		elseif character == '"' or character == "'" or character == "`" then
			quote = character
			current ..= character
		elseif character == "(" or character == "{" or character == "[" then
			depth += 1
			current ..= character
		elseif character == ")" or character == "}" or character == "]" then
			depth -= 1
			current ..= character
		elseif character == "," and depth == 0 then
			table.insert(arguments, current)
			current = ""
		else
			current ..= character
		end
	end
	if string.match(current, "%S") then
		table.insert(arguments, current)
	end
	for index, argument in arguments do
		arguments[index] = string.match(argument, "^%s*(.-)%s*$") or argument
	end
	return arguments
end

type Use = { Method: string, Name: string, Count: number?, Where: string, Side: string }

local function collect(path: string, text: string, into: { Use })
	local side = if string.find(path, "src/server/", 1, true)
		then "server"
		elseif string.find(path, "src/client/", 1, true) then "client"
		else "shared"

	local constants: { [string]: string } = {}
	for name, value in string.gmatch(text, 'local%s+([%w_]+)%s*=%s*"([^"\n]*)"') do
		constants[name] = value
	end

	for _, method in METHODS do
		local search = 1
		while true do
			local from, to = string.find(text, "Net%." .. method .. "%s*%(", search)
			if not from or not to then
				break
			end
			search = to + 1
			local call = string.match(text, "^%b()", to)
			if not call then
				continue
			end
			local arguments = splitArguments(string.sub(call, 2, -2))
			local first = arguments[1]
			if not first then
				continue
			end
			local name = string.match(first, '^"([^"]*)"$') or constants[first]
			if not name then
				continue -- Name entsteht erst zur Laufzeit
			end

			local count: number? = nil
			if method == "Send" or method == "Call" then
				count = #arguments - 1
				for index = 2, #arguments do
					if arguments[index] == "..." or string.find(arguments[index], "unpack", 1, true) then
						count = nil
					end
				end
			elseif (method == "On" or method == "OnInvoke") and arguments[2] then
				local checks = string.match(arguments[2], "^(%b{})$")
				if checks then
					count = #splitArguments(string.sub(checks, 2, -2))
				end
			end

			local _, lineBreaks = string.gsub(string.sub(text, 1, from), "\n", "")
			table.insert(
				into,
				{ Method = method, Name = name, Count = count, Where = `{path}:{lineBreaks + 1}`, Side = side }
			)
		end
	end
end

return function(t)
	local files: { string } = {}
	luauFiles("src", files)
	table.sort(files)

	local uses: { Use } = {}
	for _, path in files do
		collect(path, stripComments(fs.readFile(path)), uses)
	end

	-- [Methode][Name] = erste Fundstelle
	local index: { [string]: { [string]: Use } } = {}
	for _, method in METHODS do
		index[method] = {}
	end
	for _, use in uses do
		if not index[use.Method][use.Name] then
			index[use.Method][use.Name] = use
		end
	end

	local function report(problems: { string })
		if #problems > 0 then
			error("\n      " .. table.concat(problems, "\n      "), 0)
		end
	end

	t.test("Netz: jedes Send/Call des Clients hat einen Empfänger auf dem Server", function()
		local problems = {}
		for _, use in uses do
			if use.Method == "Send" and not index.On[use.Name] then
				table.insert(
					problems,
					`{use.Where}: Net.Send("{use.Name}") – auf dem Server fehlt Net.On("{use.Name}")`
				)
			elseif use.Method == "Call" and not index.OnInvoke[use.Name] then
				table.insert(
					problems,
					`{use.Where}: Net.Call("{use.Name}") – auf dem Server fehlt Net.OnInvoke("{use.Name}")`
				)
			end
		end
		report(problems)
	end)

	t.test("Netz: jedes Listen des Clients hat einen Sender auf dem Server", function()
		local problems = {}
		for _, use in uses do
			if use.Method ~= "Listen" then
				continue
			end
			local sent = false
			for _, method in FIRE do
				if index[method][use.Name] then
					sent = true
				end
			end
			if not sent then
				table.insert(
					problems,
					`{use.Where}: Net.Listen("{use.Name}") – der Server schickt und kündigt dieses Remote nirgends an`
				)
			end
		end
		report(problems)
	end)

	t.test("Netz: Send/Call schicken so viele Werte, wie der Server prüft", function()
		local problems = {}
		for _, use in uses do
			local receiver = if use.Method == "Send"
				then index.On[use.Name]
				elseif use.Method == "Call" then index.OnInvoke[use.Name]
				else nil
			if receiver and use.Count and receiver.Count and use.Count ~= receiver.Count then
				table.insert(
					problems,
					`{use.Where}: "{use.Name}" schickt {use.Count} Werte, {receiver.Where} prüft {receiver.Count}`
				)
			end
		end
		report(problems)
	end)

	t.test("Netz: Server- und Client-Funktionen stehen auf der richtigen Seite", function()
		local problems = {}
		for _, use in uses do
			if use.Side == "client" and SERVER_ONLY[use.Method] then
				table.insert(problems, `{use.Where}: Net.{use.Method} gibt es nur auf dem Server`)
			elseif use.Side == "server" and not SERVER_ONLY[use.Method] then
				table.insert(problems, `{use.Where}: Net.{use.Method} gibt es nur auf dem Client`)
			end
		end
		report(problems)
	end)
end
