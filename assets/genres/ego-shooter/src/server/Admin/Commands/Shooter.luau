--!strict
-- Admin-Befehle des Shooters.

local WeaponService = require(script.Parent.Parent.Parent.Services.WeaponService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "ammo",
		Aliases = { "munition" },
		Description = "Füllt die Munition auf",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			WeaponService:RefillAmmo(player)
			return `Munition von {player.Name} aufgefüllt.`
		end,
	},
	{
		Name = "infammo",
		Description = "Unendlich Munition an/aus",
		Args = { "an/aus:boolean?", "spieler:player?" },
		Run = function(context: Context, state: boolean?, target: Player?): string?
			local player = target or context.Player
			local enabled = WeaponService:SetInfiniteAmmo(player, state)
			return `Unendlich Munition für {player.Name}: {if enabled then "an" else "aus"}`
		end,
	},
}

return commands
