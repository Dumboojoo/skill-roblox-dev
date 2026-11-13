--!strict
-- Admin-Befehle zum Ansehen und Ändern von Spielständen (zum Testen und für Support).

local HttpService = game:GetService("HttpService")

local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local MAX_OUTPUT = 700
local RESET_WORD = "JA"

local function encode(value: any): string
	local ok, text = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	local result = if ok then text else tostring(value)
	if #result > MAX_OUTPUT then
		result = string.sub(result, 1, MAX_OUTPUT) .. " … (gekürzt, Pfad genauer angeben)"
	end
	return result
end

-- "500" -> 500, "true" -> true, '{"a":1}' -> Tabelle, alles andere bleibt Text.
local function decode(text: string): any
	local ok, value = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if ok then
		return value
	end
	return text
end

local commands: { Command } = {
	{
		Name = "data",
		Description = "Spielstand: show <spieler> [pfad] | set <spieler> <pfad> <wert> | add <spieler> <pfad> <zahl> | reset <spieler> JA",
		Args = { "aktion:choice", "spieler:player", "pfad:string?", "wert:rest?" },
		Choices = { aktion = { "show", "set", "add", "reset" } },
		Run = function(_context: Context, action: string, target: Player, path: string?, value: string?): string?
			if not DataService:IsLoaded(target) then
				error(`Der Spielstand von {target.Name} ist noch nicht geladen.`, 0)
			end

			if action == "show" then
				return `{target.Name} {path or "(alles)"}: {encode(DataService:Get(target, path))}`
			elseif action == "set" then
				if not path or value == nil then
					error("Benutzung: data set <spieler> <pfad> <wert>", 0)
				end
				DataService:Set(target, path :: string, decode(value :: string))
				return `{target.Name} {path} = {encode(DataService:Get(target, path))}`
			elseif action == "add" then
				local amount = if value then tonumber(value) else nil
				if not path or not amount then
					error("Benutzung: data add <spieler> <pfad> <zahl>", 0)
				end
				local new = DataService:Increment(target, path :: string, amount :: number)
				return `{target.Name} {path} = {new}`
			elseif action == "reset" then
				if path ~= RESET_WORD then
					error(
						`Das löscht den ganzen Spielstand. Zur Bestätigung: data reset {target.Name} {RESET_WORD}`,
						0
					)
				end
				DataService:Reset(target)
				return `Spielstand von {target.Name} zurückgesetzt.`
			end
			return nil
		end,
	},
}

return commands
