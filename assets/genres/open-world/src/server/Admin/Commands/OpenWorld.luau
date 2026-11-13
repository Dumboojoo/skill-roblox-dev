--!strict
-- Admin-Befehle der offenen Welt.

local CollectionService = game:GetService("CollectionService")

local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "waypoints",
		Description = "Schaltet alle Schnellreise-Punkte frei",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			local count = 0
			for _, waypoint in CollectionService:GetTagged("Waypoint") do
				local id = waypoint:GetAttribute("WaypointId")
				if type(id) == "string" then
					DataService:Set(player, { "World", "Waypoints", id }, true)
					count += 1
				end
			end
			return `{count} Wegpunkte für {player.Name} freigeschaltet.`
		end,
	},
	{
		Name = "region",
		Description = "Zeigt, in welchem Gebiet ein Spieler steht",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			local region = player:GetAttribute("Region")
			return `{player.Name}: {if type(region) == "string" and region ~= "" then region else "kein Gebiet"}`
		end,
	},
}

return commands
