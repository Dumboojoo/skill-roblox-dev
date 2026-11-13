--!strict
--[[
	AdminService – Rechteprüfung und Ausführung der Konsolen-Befehle (Taste T).

	Der Client schickt nur den eingetippten Text. Der Server prüft bei JEDEM Befehl
	die Berechtigung und führt ihn aus. Ein Exploiter, der die Konsole nachbaut,
	erreicht damit nichts.

	Eigene Befehle: neue Datei in server/Admin/Commands anlegen, die eine Liste von
	Befehlen zurückgibt (siehe Core.luau als Vorlage). Sie wird automatisch geladen.
	Alternativ zur Laufzeit: AdminService:Register(command).
]]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local CommandParser = require(Shared.Util.CommandParser)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Effects = require(script.Parent.Parent.Admin.Effects)
local Types = require(script.Parent.Parent.Admin.Types)

type Command = Types.Command
type ArgSpec = CommandParser.ArgSpec

-- Ein angemeldeter Befehl: die Beschreibung des Autors plus die zerlegten Argumente.
type Registered = {
	Name: string,
	Aliases: { string }?,
	Description: string,
	Specs: { ArgSpec },
	Command: Command,
}

local MAX_INPUT_LENGTH = 300
local OWNER_RANK = 255
local ARG_TYPES = { "player", "players", "number", "integer", "boolean", "string", "rest", "choice" }

local AdminService = {}

local registry: { Registered } = {}
local admins: { [Player]: boolean } = {}

------------------------------------------------------------------------------
-- Rechte
------------------------------------------------------------------------------

local function rankInGroup(player: Player, groupId: number): number
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if ok and type(groups) == "table" then
		for _, group in groups do
			if group.Id == groupId then
				return if type(group.Rank) == "number" then group.Rank else 0
			end
		end
	end
	return 0
end

local function computeIsAdmin(player: Player): boolean
	local config = GameConfig.Admin
	if config.StudioIsAdmin and RunService:IsStudio() then
		return true
	end
	if table.find(config.UserIds, player.UserId) then
		return true
	end
	if config.OwnerIsAdmin then
		if game.CreatorType == Enum.CreatorType.User then
			if player.UserId == game.CreatorId then
				return true
			end
		elseif rankInGroup(player, game.CreatorId) >= OWNER_RANK then
			return true
		end
	end
	if config.GroupId ~= 0 and rankInGroup(player, config.GroupId) >= config.GroupMinRank then
		return true
	end
	return false
end

local function onPlayerAdded(player: Player)
	local isAdmin = computeIsAdmin(player)
	if player.Parent ~= Players then
		return
	end
	admins[player] = isAdmin
	-- Nur für die Anzeige (z. B. Konsolen-Knopf auf dem Handy). Sicherheit hängt NICHT daran.
	player:SetAttribute("IsAdmin", isAdmin)
end

function AdminService:IsAdmin(player: Player): boolean
	return admins[player] == true
end

function AdminService:IsGod(player: Player): boolean
	return Effects.IsGod(player)
end

------------------------------------------------------------------------------
-- Argumente auflösen
------------------------------------------------------------------------------

local function findPlayer(executor: Player, text: string): (Player?, string?)
	local lowered = string.lower(text)
	if lowered == "me" or lowered == "ich" then
		return executor, nil
	end
	local matches: { Player } = {}
	for _, player in Players:GetPlayers() do
		local name = string.lower(player.Name)
		local display = string.lower(player.DisplayName)
		if name == lowered or display == lowered then
			return player, nil
		end
		if string.sub(name, 1, #lowered) == lowered or string.sub(display, 1, #lowered) == lowered then
			table.insert(matches, player)
		end
	end
	if #matches == 1 then
		return matches[1], nil
	elseif #matches == 0 then
		return nil, `Spieler "{text}" nicht gefunden.`
	end
	return nil, `"{text}" passt auf mehrere Spieler.`
end

local function choicesOf(command: Command, argName: string): { string }
	local source = if command.Choices then command.Choices[argName] else nil
	if type(source) == "function" then
		local ok, list = pcall(source)
		return if ok and type(list) == "table" then list else {}
	elseif type(source) == "table" then
		return source
	end
	return {}
end

-- Wandelt ein Wort in den Wert für `spec` um. Rückgabe: (Wert, nil) oder (nil, Fehlertext).
local function convert(executor: Player, command: Command, spec: ArgSpec, token: string): (any, string?)
	local kind = spec.Type
	if kind == "string" then
		return token, nil
	elseif kind == "number" or kind == "integer" then
		local number = tonumber(token)
		if number == nil or number ~= number or math.abs(number) == math.huge then
			return nil, `"{token}" ist keine Zahl.`
		end
		if kind == "integer" and number % 1 ~= 0 then
			return nil, `"{token}" ist keine ganze Zahl.`
		end
		return number, nil
	elseif kind == "boolean" then
		local value = CommandParser.ParseBoolean(token)
		if value == nil then
			return nil, `"{token}" ist weder an noch aus.`
		end
		return value, nil
	elseif kind == "player" then
		return findPlayer(executor, token)
	elseif kind == "players" then
		local lowered = string.lower(token)
		if lowered == "all" or lowered == "alle" then
			return Players:GetPlayers(), nil
		elseif lowered == "others" or lowered == "andere" then
			local list = Players:GetPlayers()
			local index = table.find(list, executor)
			if index then
				table.remove(list, index)
			end
			return list, nil
		end
		local player, problem = findPlayer(executor, token)
		if not player then
			return nil, problem
		end
		return { player }, nil
	elseif kind == "choice" then
		local lowered = string.lower(token)
		for _, choice in choicesOf(command, spec.Name) do
			if string.lower(choice) == lowered then
				return choice, nil
			end
		end
		return nil, `"{token}" ist keine gültige Auswahl für {spec.Name}.`
	end
	return nil, `Unbekannter Argumenttyp {kind}.`
end

-- Rückgabe: (Argumente, nil) oder (nil, Fehlertext). Die Liste hat genau #Specs Plätze (mit nil-Lücken).
local function resolveArgs(executor: Player, entry: Registered, tokens: { string }): ({ any }?, string?)
	local specs = entry.Specs
	local args: { any } = table.create(#specs)
	local position = 2 -- tokens[1] ist der Befehlsname

	for index, spec in specs do
		local token = tokens[position]
		if token == nil then
			if not spec.Optional then
				return nil, `Es fehlt: {spec.Name}.`
			end
		elseif spec.Type == "rest" then
			args[index] = table.concat(tokens, " ", position)
			position = #tokens + 1
		else
			local value, problem = convert(executor, entry.Command, spec, token)
			if value ~= nil then
				args[index] = value
				position += 1
			elseif not spec.Optional then
				return nil, problem
			end
			-- Optionales Argument, das nicht passt: überspringen und das Wort beim nächsten versuchen.
		end
	end

	if position <= #tokens then
		return nil, `Zu viele oder unpassende Angaben ab "{tokens[position]}".`
	end
	return args, nil
end

------------------------------------------------------------------------------
-- Befehle
------------------------------------------------------------------------------

-- "spieler:player?" -> { Name = "spieler", Type = "player", Optional = true }
local function parseSpecs(command: Command): { ArgSpec }
	local specs: { ArgSpec } = {}
	local texts: { string } = command.Args or {}
	for index, text in texts do
		local where = `[Admin] Befehl "{command.Name}", Argument {index} ("{text}")`
		local name, kind, optional = string.match(text, "^(.+):(%a+)(%??)$")
		if not name or not kind then
			warn(`{where}: erwartet wird "name:typ" oder "name:typ?".`)
			continue
		end
		if not table.find(ARG_TYPES, kind) then
			warn(`{where}: unbekannter Typ "{kind}". Erlaubt: {table.concat(ARG_TYPES, ", ")}.`)
			continue
		end
		if kind == "rest" and index ~= #texts then
			warn(`{where}: "rest" muss das letzte Argument sein.`)
		end
		if kind == "choice" and not (command.Choices and command.Choices[name]) then
			warn(`{where}: Für "choice" fehlt Choices["{name}"].`)
		end
		table.insert(specs, { Name = name, Type = kind, Optional = optional == "?" })
	end
	return specs
end

function AdminService:Register(command: Command)
	local existing = CommandParser.FindCommand(registry, command.Name)
	if existing then
		warn(`[Admin] Befehl "{command.Name}" gibt es schon und wird ersetzt.`)
		table.remove(registry, table.find(registry, existing) :: number)
	end
	table.insert(registry, {
		Name = command.Name,
		Aliases = command.Aliases,
		Description = command.Description,
		Specs = parseSpecs(command),
		Command = command,
	})
end

-- Beschreibung aller Befehle für Hilfe und Vervollständigung (ohne Funktionen, kann zum Client).
function AdminService:Describe(): { CommandParser.CommandInfo }
	local list: { CommandParser.CommandInfo } = {}
	for _, entry in registry do
		local args: { ArgSpec } = {}
		for _, spec in entry.Specs do
			table.insert(args, {
				Name = spec.Name,
				Type = spec.Type,
				Optional = spec.Optional,
				Choices = if spec.Type == "choice" then choicesOf(entry.Command, spec.Name) else nil,
			})
		end
		table.insert(list, {
			Name = entry.Name,
			Aliases = entry.Aliases,
			Description = entry.Description,
			Args = args,
		})
	end
	return list
end

-- Führt eine Eingabezeile im Namen von `player` aus. Rückgabe: (Erfolg, Text für die Konsole)
function AdminService:Execute(player: Player, text: string): (boolean, string)
	if not AdminService:IsAdmin(player) then
		return false, "Keine Berechtigung."
	end

	local stripped = CommandParser.StripSlash(text)
	local tokens = CommandParser.Tokenize(stripped)
	if #tokens == 0 then
		return false, ""
	end

	local entry = CommandParser.FindCommand(registry, tokens[1])
	if not entry then
		return false, `Unbekannter Befehl "{tokens[1]}". Mit "help" siehst du alle Befehle.`
	end

	local args, problem = resolveArgs(player, entry, tokens)
	if not args then
		local usage = CommandParser.Usage({ Name = entry.Name, Description = "", Args = entry.Specs })
		return false, `{problem}\nBenutzung: {usage}`
	end

	print(`[Admin] {player.Name} ({player.UserId}): {stripped}`)

	local context: Types.Context = { Player = player, Raw = stripped }
	local ok, result = pcall(entry.Command.Run, context, table.unpack(args, 1, #entry.Specs))
	if not ok then
		-- error("Text", 0) in einem Befehl ist der vorgesehene Weg, eine Meldung zurückzugeben.
		return false, tostring(result)
	end
	return true, if type(result) == "string" then result else "OK"
end

local function helpCommand(): Command
	return {
		Name = "help",
		Aliases = { "hilfe", "?" },
		Description = "Zeigt alle Befehle oder die Benutzung eines Befehls",
		Args = { "befehl:string?" },
		Run = function(_context, name: string?): string?
			if name then
				local entry = CommandParser.FindCommand(registry, name)
				if not entry then
					error(`Unbekannter Befehl "{name}".`, 0)
				end
				local found = entry :: Registered
				local usage = CommandParser.Usage({ Name = found.Name, Description = "", Args = found.Specs })
				local aliases = if found.Aliases and #found.Aliases > 0
					then `\nKurzformen: {table.concat(found.Aliases, ", ")}`
					else ""
				return `{usage}\n{found.Description}{aliases}`
			end
			local names = {}
			for _, entry in registry do
				table.insert(names, entry.Name)
			end
			table.sort(names)
			return "Befehle: " .. table.concat(names, ", ") .. '\nDetails mit "help <befehl>".'
		end,
	}
end

------------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------------

function AdminService:Init()
	AdminService:Register(helpCommand())

	local folder = script.Parent.Parent.Admin.Commands
	local modules = folder:GetChildren()
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)
	for _, module in modules do
		if module:IsA("ModuleScript") then
			local ok, list = pcall(require :: any, module)
			if ok and type(list) == "table" then
				for _, command in list do
					AdminService:Register(command)
				end
			else
				warn(`[Admin] Befehlsdatei {module.Name} konnte nicht geladen werden: {list}`)
			end
		end
	end

	Net.OnInvoke("Admin.Run", { Check.stringMax(MAX_INPUT_LENGTH) }, function(player: Player, text: string)
		local ok, message = AdminService:Execute(player, text)
		return ok, message
	end, { Rate = 5 })

	Net.OnInvoke("Admin.GetCommands", {}, function(player: Player)
		-- Warten, bis die Rechte geprüft sind (Gruppenrang braucht einen Moment).
		while admins[player] == nil and player.Parent == Players do
			task.wait(0.1)
		end
		if not AdminService:IsAdmin(player) then
			return nil
		end
		return AdminService:Describe()
	end, { Rate = 2 })
end

function AdminService:Start()
	Effects.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		admins[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return AdminService
