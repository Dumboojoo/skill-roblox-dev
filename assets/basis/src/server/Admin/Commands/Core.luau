--!strict
--[[
	Grundbefehle der Admin-Konsole.

	Vorlage für eigene Befehlsdateien: Eine Datei gibt eine Liste von Befehlen
	zurück. Wie Args und Choices aufgebaut sind, steht in Admin/Types.luau.

	Optionale Argumente, die nicht passen, werden übersprungen. Darum steht bei den
	Schaltern "an/aus" VOR dem Spieler: `fly`, `fly an`, `fly Max`, `fly aus Max`
	funktionieren alle.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Net = require(ReplicatedStorage.Shared.Net)
local Effects = require(script.Parent.Parent.Effects)
local Types = require(script.Parent.Parent.Types)

type Command = Types.Command
type Context = Types.Context

local function humanoidOf(player: Player): Humanoid
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		error(`{player.Name} hat gerade keinen Charakter.`, 0)
	end
	return humanoid :: Humanoid
end

local function rootOf(player: Player): BasePart
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		error(`{player.Name} hat gerade keinen Charakter.`, 0)
	end
	return root :: BasePart
end

local function onOff(state: boolean): string
	return if state then "an" else "aus"
end

local function toggle(name: string, aliases: { string }, description: string, flag: Effects.Flag): Command
	return {
		Name = name,
		Aliases = aliases,
		Description = description,
		Args = { "an/aus:boolean?", "spieler:player?" },
		Run = function(context: Context, state: boolean?, target: Player?): string?
			local player = target or context.Player
			local new = Effects.Set(player, flag, state)
			return `{name} für {player.Name}: {onOff(new)}`
		end,
	}
end

local commands: { Command } = {
	toggle("fly", { "fliegen" }, "Fliegen (WASD, Leertaste hoch, Shift runter)", "AdminFly"),
	toggle("noclip", { "nc" }, "Durch Wände gehen", "AdminNoclip"),
	toggle("god", { "unsterblich" }, "Unsterblich", "AdminGod"),
	toggle("invisible", { "inv", "unsichtbar" }, "Unsichtbar für alle", "AdminInvisible"),

	{
		Name = "flyspeed",
		Description = "Fluggeschwindigkeit (Standard 60)",
		Args = { "wert:number" },
		Run = function(context: Context, value: number): string?
			context.Player:SetAttribute("AdminFlySpeed", math.clamp(value, 5, 1000))
			return `Fluggeschwindigkeit: {math.clamp(value, 5, 1000)}`
		end,
	},
	{
		Name = "speed",
		Aliases = { "ws" },
		Description = "Laufgeschwindigkeit (Standard 16)",
		Args = { "wert:number", "spieler:player?" },
		Run = function(context: Context, value: number, target: Player?): string?
			local player = target or context.Player
			humanoidOf(player).WalkSpeed = math.clamp(value, 0, 1000)
			return `Laufgeschwindigkeit von {player.Name}: {math.clamp(value, 0, 1000)}`
		end,
	},
	{
		Name = "jump",
		Aliases = { "jp" },
		Description = "Sprungkraft (Standard 50)",
		Args = { "wert:number", "spieler:player?" },
		Run = function(context: Context, value: number, target: Player?): string?
			local player = target or context.Player
			local humanoid = humanoidOf(player)
			humanoid.UseJumpPower = true
			humanoid.JumpPower = math.clamp(value, 0, 1000)
			return `Sprungkraft von {player.Name}: {humanoid.JumpPower}`
		end,
	},
	{
		Name = "tp",
		Aliases = { "goto" },
		Description = "Teleportiert dich zu einem Spieler",
		Args = { "ziel:player" },
		Run = function(context: Context, target: Player): string?
			rootOf(context.Player).CFrame = rootOf(target).CFrame * CFrame.new(0, 0, 4)
			return `Zu {target.Name} teleportiert.`
		end,
	},
	{
		Name = "bring",
		Description = "Holt Spieler zu dir (Name, all oder others)",
		Args = { "spieler:players" },
		Run = function(context: Context, targets: { Player }): string?
			local destination = rootOf(context.Player).CFrame
			local count = 0
			for _, target in targets do
				local character = target.Character
				if character and target ~= context.Player then
					character:PivotTo(destination * CFrame.new(0, 0, -4 - count))
					count += 1
				end
			end
			return `{count} Spieler geholt.`
		end,
	},
	{
		Name = "tppos",
		Description = "Teleportiert dich an eine Position",
		Args = { "x:number", "y:number", "z:number" },
		Run = function(context: Context, x: number, y: number, z: number): string?
			rootOf(context.Player).CFrame = CFrame.new(x, y, z)
			return `Teleportiert nach {x}, {y}, {z}.`
		end,
	},
	{
		Name = "heal",
		Aliases = { "heilen" },
		Description = "Heilt vollständig",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			local humanoid = humanoidOf(player)
			humanoid.Health = humanoid.MaxHealth
			return `{player.Name} geheilt.`
		end,
	},
	{
		Name = "kill",
		Description = "Tötet einen Spieler",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			if Effects.IsGod(player) then
				error(`{player.Name} ist unsterblich (erst "god aus").`, 0)
			end
			humanoidOf(player).Health = 0
			return `{player.Name} getötet.`
		end,
	},
	{
		Name = "respawn",
		Aliases = { "re" },
		Description = "Lässt einen Spieler neu erscheinen",
		Args = { "spieler:player?" },
		Run = function(context: Context, target: Player?): string?
			local player = target or context.Player
			task.spawn(function()
				player:LoadCharacterAsync()
			end)
			return `{player.Name} erscheint neu.`
		end,
	},
	{
		Name = "kick",
		Description = "Wirft einen Spieler vom Server",
		Args = { "spieler:player", "grund:rest?" },
		Run = function(context: Context, target: Player, reason: string?): string?
			if target == context.Player then
				error("Du kannst dich nicht selbst kicken.", 0)
			end
			target:Kick(reason or "Du wurdest von einem Admin vom Server entfernt.")
			return `{target.Name} wurde gekickt.`
		end,
	},
	{
		Name = "time",
		Aliases = { "zeit" },
		Description = "Tageszeit in Stunden (0 bis 24)",
		Args = { "stunde:number" },
		Run = function(_context: Context, hour: number): string?
			Lighting.ClockTime = math.clamp(hour, 0, 24)
			return `Tageszeit: {math.clamp(hour, 0, 24)} Uhr`
		end,
	},
	{
		Name = "announce",
		Aliases = { "say", "ansage" },
		Description = "Zeigt allen Spielern eine Nachricht",
		Args = { "text:rest" },
		Run = function(context: Context, text: string): string?
			-- Text, den andere Spieler sehen, MUSS durch den Roblox-Filter.
			local ok, filtered = pcall(function()
				local result = TextService:FilterStringAsync(text, context.Player.UserId)
				return result:GetNonChatStringForBroadcastAsync()
			end)
			if not ok then
				error("Die Nachricht konnte nicht gefiltert werden. Bitte später erneut versuchen.", 0)
			end
			Net.FireAll("Notify", filtered, "Announcement")
			return "Ansage gesendet."
		end,
	},
}

return commands
