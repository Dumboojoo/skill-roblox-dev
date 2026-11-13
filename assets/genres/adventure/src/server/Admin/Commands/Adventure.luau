--!strict
-- Admin-Befehle des Adventures.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Adventure)
local AdventureService = require(script.Parent.Parent.Parent.Services.AdventureService)
local DataService = require(script.Parent.Parent.Parent.Services.DataService)
local PuzzleService = require(script.Parent.Parent.Parent.Services.PuzzleService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local function levelIds(): { string }
	local ids = {}
	for _, level in Config.Levels do
		table.insert(ids, level.Id)
	end
	return ids
end

local commands: { Command } = {
	{
		Name = "level",
		Description = "Bringt dich in ein Level (schaltet es dafür frei)",
		Args = { "level:choice" },
		Choices = { level = levelIds },
		Run = function(context: Context, levelId: string): string?
			-- Alle Level davor als geschafft vermerken, damit das Betreten erlaubt ist.
			for _, id in levelIds() do
				if id == levelId then
					break
				end
				DataService:Set(context.Player, { "Adventure", "Completed", id }, true)
			end
			AdventureService:EnterLevel(context.Player, levelId)
			return `Level {levelId} betreten.`
		end,
	},
	{
		Name = "hub",
		Description = "Bringt dich zurück in den Hub",
		Run = function(context: Context): string?
			AdventureService:ReturnToHub(context.Player)
			return "Zurück im Hub."
		end,
	},
	{
		Name = "puzzlereset",
		Description = "Setzt alle Schalter eines Rätsel-Kanals zurück",
		Args = { "kanal:string" },
		Run = function(_context: Context, channel: string): string?
			PuzzleService:ResetChannel(channel)
			return `Kanal {channel} zurückgesetzt.`
		end,
	},
}

return commands
