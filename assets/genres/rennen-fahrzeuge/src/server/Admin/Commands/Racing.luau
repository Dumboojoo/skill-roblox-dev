--!strict
-- Admin-Befehle der Rennen.

local RaceService = require(script.Parent.Parent.Parent.Services.RaceService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "raceskip",
		Aliases = { "startrace" },
		Description = "Beendet die laufende Phase (Pause, Rennen, Ergebnis) sofort",
		Run = function(_context: Context): string?
			RaceService:SkipPhase()
			return "Phase übersprungen."
		end,
	},
	{
		Name = "resetcar",
		Description = "Stellt das Auto auf den letzten Checkpoint zurück",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			RaceService:ResetCar(player)
			return `Auto von {player.Name} zurückgesetzt.`
		end,
	},
}

return commands
