--!strict
--[[
	CommandParser – zerlegt Konsolen-Eingaben und berechnet Vorschläge.

	Reines Luau ohne Roblox-Dienste, damit es sich außerhalb von Studio testen lässt
	(siehe tests/). Der Server benutzt Tokenize/ParseBoolean zum Ausführen, der
	Client benutzt Suggest für die Tab-Vervollständigung.
]]

-- Erlaubte Werte: "player", "players", "number", "integer", "boolean", "string", "rest", "choice".
-- Bewusst als string getypt: So lassen sich Befehlstabellen ohne Typ-Umwege hinschreiben.
export type ArgType = string

export type ArgSpec = {
	Name: string,
	Type: ArgType,
	Optional: boolean?,
	Choices: { string }?,
}

export type CommandInfo = {
	Name: string,
	Aliases: { string }?,
	Description: string,
	Args: { ArgSpec }?,
}

export type Suggestion = {
	Label: string, -- das einzelne Wort, das vorgeschlagen wird
	Completion: string, -- die ganze Zeile nach Annahme des Vorschlags
}

export type SuggestContext = {
	Players: { string },
}

local CommandParser = {}

local TRUE_WORDS = { on = true, an = true, ["true"] = true, ja = true, yes = true, ["1"] = true }
local FALSE_WORDS = { off = true, aus = true, ["false"] = true, nein = true, no = true, ["0"] = true }

-- Zerlegt in Wörter; "Text in Anführungszeichen" bleibt ein Wort.
-- Zweiter Rückgabewert: endet die Eingabe mit einem Leerzeichen (nächstes Wort wird begonnen)?
function CommandParser.Tokenize(text: string): ({ string }, boolean)
	local tokens: { string } = {}
	local current: { string } = {}
	local inQuotes = false
	local hasToken = false

	for index = 1, #text do
		local character = string.sub(text, index, index)
		if character == '"' then
			inQuotes = not inQuotes
			hasToken = true
		elseif character == " " and not inQuotes then
			if hasToken then
				table.insert(tokens, table.concat(current))
				table.clear(current)
				hasToken = false
			end
		else
			table.insert(current, character)
			hasToken = true
		end
	end

	if hasToken then
		table.insert(tokens, table.concat(current))
	end

	local trailingSpace = not inQuotes and string.sub(text, -1) == " "
	return tokens, trailingSpace
end

-- Entfernt einen führenden Schrägstrich, damit "/fly" und "fly" gleich funktionieren.
function CommandParser.StripSlash(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	if string.sub(trimmed, 1, 1) == "/" then
		return string.sub(trimmed, 2)
	end
	return trimmed
end

function CommandParser.ParseBoolean(text: string): boolean?
	local lowered = string.lower(text)
	if TRUE_WORDS[lowered] then
		return true
	elseif FALSE_WORDS[lowered] then
		return false
	end
	return nil
end

function CommandParser.FindCommand<T>(commands: { T }, name: string): T?
	local lowered = string.lower(name)
	for _, command in commands do
		local info = command :: any
		if string.lower(info.Name) == lowered then
			return command
		end
		if info.Aliases then
			for _, alias in info.Aliases do
				if string.lower(alias) == lowered then
					return command
				end
			end
		end
	end
	return nil
end

-- "fly [spieler] [an/aus]"
function CommandParser.Usage(command: CommandInfo): string
	local parts = { command.Name }
	local args: { ArgSpec } = command.Args or {}
	for _, arg in args do
		if arg.Optional then
			table.insert(parts, `[{arg.Name}]`)
		else
			table.insert(parts, `<{arg.Name}>`)
		end
	end
	return table.concat(parts, " ")
end

local function quoteIfNeeded(word: string): string
	if string.find(word, " ", 1, true) then
		return `"{word}"`
	end
	return word
end

local function candidatesFor(arg: ArgSpec, context: SuggestContext): { string }
	if arg.Type == "player" then
		local list = { "me" }
		table.move(context.Players, 1, #context.Players, 2, list)
		return list
	elseif arg.Type == "players" then
		local list = { "me", "all", "others" }
		table.move(context.Players, 1, #context.Players, 4, list)
		return list
	elseif arg.Type == "boolean" then
		return { "an", "aus" }
	elseif arg.Type == "choice" then
		return arg.Choices or {}
	end
	return {}
end

-- Vorschläge für das Wort, das gerade getippt wird.
function CommandParser.Suggest(text: string, commands: { CommandInfo }, context: SuggestContext): { Suggestion }
	local stripped = CommandParser.StripSlash(text)
	local tokens, trailingSpace = CommandParser.Tokenize(stripped)

	-- Das Wort in Arbeit: nach einem Leerzeichen ein neues, leeres Wort.
	local typingIndex = if trailingSpace or #tokens == 0 then #tokens + 1 else #tokens
	local prefix = string.lower(tokens[typingIndex] or "")

	local candidates: { string } = {}
	if typingIndex == 1 then
		for _, command in commands do
			table.insert(candidates, command.Name)
		end
		table.sort(candidates)
	else
		local command = CommandParser.FindCommand(commands, tokens[1])
		local args = if command then command.Args else nil
		if not args then
			return {}
		end
		local arg = args[typingIndex - 1]
		if not arg then
			return {}
		end
		candidates = candidatesFor(arg, context)
	end

	local head: { string } = {}
	for index = 1, typingIndex - 1 do
		table.insert(head, quoteIfNeeded(tokens[index]))
	end

	local suggestions: { Suggestion } = {}
	for _, candidate in candidates do
		if string.sub(string.lower(candidate), 1, #prefix) == prefix then
			local parts = table.clone(head)
			table.insert(parts, quoteIfNeeded(candidate))
			table.insert(suggestions, { Label = candidate, Completion = table.concat(parts, " ") .. " " })
		end
	end
	return suggestions
end

return CommandParser
