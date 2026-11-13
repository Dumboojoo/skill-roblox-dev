--!strict
-- Admin-Befehle des Dungeons.

local DungeonService = require(script.Parent.Parent.Parent.Services.DungeonService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "newdungeon",
		Aliases = { "dungeon" },
		Description = "Erzeugt einen neuen Dungeon (optional mit festem Seed zum Nachstellen)",
		Args = { "seed:integer?" },
		Run = function(_context: Context, seed: number?): string?
			DungeonService:StartRun(seed)
			return if seed then `Neuer Dungeon mit Seed {seed}.` else "Neuer Dungeon erzeugt."
		end,
	},
	{
		Name = "loot",
		Aliases = { "beute" },
		Description = "Würfelt Beute für einen Spieler",
		Args = { "anzahl:integer?", "spieler:player?" },
		Run = function(context: Context, rolls: number?, target: Player?): string?
			local player = target or context.Player
			local count = math.clamp(rolls or 1, 1, 50)
			DungeonService:GiveLoot(player, count)
			return `{count}x Beute für {player.Name} gewürfelt.`
		end,
	},
}

return commands
