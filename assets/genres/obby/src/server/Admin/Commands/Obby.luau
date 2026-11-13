--!strict
-- Admin-Befehle des Obbys.

local ObbyService = require(script.Parent.Parent.Parent.Services.ObbyService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "stage",
		Aliases = { "stufe" },
		Description = "Setzt einen Spieler auf eine Stufe",
		Args = { "stufe:integer", "spieler:player?" },
		Run = function(context: Context, stage: number, target: Player?): string?
			local player = target or context.Player
			ObbyService:SetStage(player, stage)
			return `{player.Name} ist jetzt auf Stufe {math.clamp(stage, 0, ObbyService:GetLastStage())}.`
		end,
	},
}

return commands
