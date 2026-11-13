--!strict
-- Admin-Befehle des Simulators.

local SimulatorService = require(script.Parent.Parent.Parent.Services.SimulatorService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "coins",
		Aliases = { "muenzen" },
		Description = "Gibt Münzen (zählt auch für den Rebirth-Fortschritt)",
		Args = { "betrag:number", "spieler:player?" },
		Run = function(context: Context, amount: number, target: Player?): string?
			local player = target or context.Player
			SimulatorService:AddCoins(player, math.floor(amount))
			return `{player.Name} hat {math.floor(amount)} Münzen bekommen.`
		end,
	},
}

return commands
