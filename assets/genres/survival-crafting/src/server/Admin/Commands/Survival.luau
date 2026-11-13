--!strict
-- Admin-Befehle des Survival-Spiels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Survival)
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local SurvivalService = require(script.Parent.Parent.Parent.Services.SurvivalService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "give",
		Aliases = { "gib" },
		Description = "Gibt Gegenstände",
		Args = { "gegenstand:choice", "anzahl:integer?", "spieler:player?" },
		Choices = {
			gegenstand = function()
				local names = {}
				for name in Config.Items do
					table.insert(names, name)
				end
				table.sort(names)
				return names
			end,
		},
		Run = function(context: Context, itemId: string, amount: number?, target: Player?): string?
			local player = target or context.Player
			local count = math.clamp(amount or 1, 1, 9999)
			SurvivalService:GiveItem(player, itemId, count)
			return `{player.Name} hat {count}x {itemId} bekommen.`
		end,
	},
	{
		Name = "feed",
		Aliases = { "satt" },
		Description = "Füllt Hunger und Durst auf",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			DataService:Set(player, "Survival.Hunger", Config.Needs.Max)
			DataService:Set(player, "Survival.Thirst", Config.Needs.Max)
			return `{player.Name} ist satt.`
		end,
	},
}

return commands
