--!strict
-- Admin-Befehle des RPGs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Rpg)
local EnemyService = require(script.Parent.Parent.Parent.Services.EnemyService)
local ProgressService = require(script.Parent.Parent.Parent.Services.ProgressService)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local commands: { Command } = {
	{
		Name = "xp",
		Description = "Gibt Erfahrungspunkte",
		Args = { "betrag:integer", "spieler:player?" },
		Run = function(context: Context, amount: number, target: Player?): string?
			local player = target or context.Player
			ProgressService:AddXp(player, amount)
			return `{player.Name} hat {amount} XP bekommen.`
		end,
	},
	{
		Name = "spawnenemy",
		Aliases = { "gegner" },
		Description = "Lässt einen Gegner vor dir erscheinen",
		Args = { "typ:choice", "anzahl:integer?" },
		Choices = {
			typ = function()
				local names = {}
				for name in Config.Enemies do
					table.insert(names, name)
				end
				table.sort(names)
				return names
			end,
		},
		Run = function(context: Context, enemyType: string, count: number?): string?
			local character = context.Player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if not root or not root:IsA("BasePart") then
				error("Du hast gerade keinen Charakter.", 0)
			end
			local amount = math.clamp(count or 1, 1, 20)
			for index = 1, amount do
				local offset = (root :: BasePart).CFrame.LookVector * 12 + Vector3.new(index * 3 - amount * 1.5, 0, 0)
				EnemyService:Spawn(enemyType, (root :: BasePart).Position + offset - Vector3.new(0, 3, 0))
			end
			return `{amount}x {enemyType} erschienen.`
		end,
	},
}

return commands
