--!strict
-- Admin-Befehle der Bestenliste.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Leaderboards)
local LeaderboardService = require(script.Parent.Parent.Parent.Services.LeaderboardService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "leaderboard",
		Aliases = { "lb", "rangliste" },
		Description = "Zeigt eine Rangliste (mit 'refresh' vorher neu laden)",
		Args = { "rangliste:choice", "aktion:string?" },
		Choices = {
			rangliste = function()
				local names = {}
				for name in Config.Boards do
					table.insert(names, name)
				end
				table.sort(names)
				return names
			end,
		},
		Run = function(_context: Context, boardKey: string, action: string?): string?
			if action == "refresh" then
				LeaderboardService:Refresh()
			end
			local lines = { Config.Boards[boardKey].DisplayName }
			for _, entry in LeaderboardService:GetTop(boardKey) do
				table.insert(
					lines,
					`{entry.Rank}. {entry.Name}  {LeaderboardService:FormatValue(boardKey, entry.Value)}`
				)
			end
			if #lines == 1 then
				table.insert(lines, "Noch keine Einträge.")
			end
			return table.concat(lines, "\n")
		end,
	},
}

return commands
