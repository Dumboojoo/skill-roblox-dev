--!strict
-- Admin-Befehle des Tycoons.

local TycoonService = require(script.Parent.Parent.Parent.Services.TycoonService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "money",
		Aliases = { "geld" },
		Description = "Gibt Geld",
		Args = { "betrag:integer", "spieler:player?" },
		Run = function(context: Context, amount: number, target: Player?): string?
			local player = target or context.Player
			TycoonService:AddCoins(player, amount)
			return `{player.Name} hat {amount} bekommen.`
		end,
	},
}

return commands
