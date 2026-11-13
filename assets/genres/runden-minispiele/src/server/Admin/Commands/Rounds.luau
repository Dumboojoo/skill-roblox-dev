--!strict
-- Admin-Befehle für den Rundenablauf.

local RoundService = require(script.Parent.Parent.Parent.Services.RoundService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "skipround",
		Aliases = { "skip" },
		Description = "Beendet die laufende Phase (Pause, Abstimmung, Runde) sofort",
		Run = function(_context: Context): string?
			RoundService:SkipPhase()
			return "Phase übersprungen."
		end,
	},
	{
		Name = "forcegame",
		Description = "Legt das nächste Minispiel fest (ohne Abstimmung)",
		Args = { "minispiel:choice" },
		Choices = {
			minispiel = function()
				return RoundService:GetMinigameIds()
			end,
		},
		Run = function(_context: Context, id: string): string?
			if not RoundService:ForceMinigame(id) then
				error(`Minispiel "{id}" gibt es nicht.`, 0)
			end
			return `Nächstes Minispiel: {id} (falls eine Map dafür existiert).`
		end,
	},
}

return commands
