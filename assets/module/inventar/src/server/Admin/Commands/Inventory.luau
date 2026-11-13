--!strict
-- Admin-Befehle des Inventars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local InventoryService = require(script.Parent.Parent.Parent.Services.InventoryService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "giveitem",
		Aliases = { "item" },
		Description = "Legt einen Gegenstand ins Inventar",
		Args = { "gegenstand:choice", "anzahl:integer?", "spieler:player?" },
		Choices = {
			gegenstand = function()
				local names = {}
				for name in Items.List do
					table.insert(names, name)
				end
				table.sort(names)
				return names
			end,
		},
		Run = function(context: Context, itemId: string, amount: number?, target: Player?): string?
			local player = target or context.Player
			local added = InventoryService:Give(player, itemId, math.clamp(amount or 1, 1, 9999))
			return `{player.Name} hat {added}x {itemId} bekommen.`
		end,
	},
	{
		Name = "clearinv",
		Description = "Leert das Inventar eines Spielers (zur Bestätigung JA anhängen)",
		Args = { "spieler:player", "bestaetigung:string?" },
		Run = function(_context: Context, target: Player, confirmation: string?): string?
			if confirmation ~= "JA" then
				error(`Das löscht alle Gegenstände. Zur Bestätigung: clearinv {target.Name} JA`, 0)
			end
			DataService:Set(target, "Inventory", { Slots = {}, Equipped = {}, NextUid = 1 })
			return `Inventar von {target.Name} geleert.`
		end,
	},
}

return commands
