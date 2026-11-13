--!strict
-- Admin-Befehle des Horror-Spiels.

local ChaserService = require(script.Parent.Parent.Parent.Services.ChaserService)
local StoryService = require(script.Parent.Parent.Parent.Services.StoryService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "storyskip",
		Description = "Überspringt das aktuelle Ziel",
		Run = function(_context: Context): string?
			StoryService:SkipObjective()
			return "Ziel übersprungen."
		end,
	},
	{
		Name = "storyrestart",
		Description = "Setzt das Kapitel und den Verfolger zurück",
		Run = function(_context: Context): string?
			StoryService:Restart()
			return "Kapitel zurückgesetzt."
		end,
	},
	{
		Name = "chaser",
		Description = "Zeigt den Zustand des Verfolgers (Patrol, Chase, Search)",
		Run = function(_context: Context): string?
			return `Verfolger: {ChaserService:GetState()}`
		end,
	},
}

return commands
