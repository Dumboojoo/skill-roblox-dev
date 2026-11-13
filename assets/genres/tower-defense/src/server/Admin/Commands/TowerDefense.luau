--!strict
-- Admin-Befehle für Tower Defense.

local TowerDefenseService = require(script.Parent.Parent.Parent.Services.TowerDefenseService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "cash",
		Aliases = { "gold" },
		Description = "Gibt Gold für die laufende Partie",
		Args = { "betrag:integer", "spieler:player?" },
		Run = function(context: Context, amount: number, target: Player?): string?
			local player = target or context.Player
			TowerDefenseService:AddCash(player, amount)
			return `{player.Name} hat {amount} Gold bekommen.`
		end,
	},
	{
		Name = "nextwave",
		Aliases = { "welle" },
		Description = "Startet sofort die nächste Welle",
		Run = function(_context: Context): string?
			TowerDefenseService:SkipIntermission()
			return "Nächste Welle wird gestartet."
		end,
	},
	{
		Name = "tdrestart",
		Description = "Setzt die Partie zurück",
		Run = function(_context: Context): string?
			TowerDefenseService:Restart()
			return "Partie zurückgesetzt."
		end,
	},
}

return commands
