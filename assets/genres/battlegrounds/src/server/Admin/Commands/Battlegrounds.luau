--!strict
-- Admin-Befehle von Battlegrounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Battlegrounds)
local AbilityService = require(script.Parent.Parent.Parent.Services.AbilityService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "ult",
		Aliases = { "ulti" },
		Description = "Füllt die Ulti-Leiste",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			AbilityService:FillUltimate(player)
			return `Ulti von {player.Name} ist bereit.`
		end,
	},
	{
		Name = "fighter",
		Aliases = { "kaempfer" },
		Description = "Wechselt den Kämpfer",
		Args = { "kaempfer:choice", "spieler:player?" },
		Choices = {
			kaempfer = function()
				local names = {}
				for name in Config.Characters do
					table.insert(names, name)
				end
				table.sort(names)
				return names
			end,
		},
		Run = function(context: Context, characterId: string, target: Player?): string?
			local player = target or context.Player
			AbilityService:SetCharacter(player, characterId)
			return `{player.Name} spielt jetzt {characterId}.`
		end,
	},
}

return commands
