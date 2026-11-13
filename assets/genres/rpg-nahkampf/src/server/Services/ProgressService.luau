--!strict
--[[
	ProgressService – Erfahrung, Stufen und Quests.

	Quests sind reine Daten (Config.Rpg.Quests). Dieser Service kennt nur den
	Quest-Typ "besiege N Gegner vom Typ X". Weitere Typen (sammle, sprich mit,
	erreiche Ort) nach demselben Muster: ein Feld `Type` in der Quest-Tabelle und
	eine Stelle, die bei dem passenden Ereignis `advance` aufruft.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.Rpg)
local Formulas = require(Shared.Rpg.Formulas)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

local ProgressService = {}

local function levelOf(xp: number): number
	local levels = Config.Levels
	return (Formulas.LevelFromXp(xp, levels.BaseXp, levels.Exponent, levels.MaxLevel))
end

local function applyHealth(player: Player, heal: boolean)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local level = DataService:Get(player, "Rpg.Level")
	if humanoid and type(level) == "number" then
		humanoid.MaxHealth = Formulas.MaxHealth(level, Config.Levels.HealthPerLevel)
		if heal then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

function ProgressService:AddXp(player: Player, amount: number)
	local xp = DataService:Increment(player, "Rpg.Xp", amount)
	if not xp then
		return
	end
	local newLevel = levelOf(xp)
	local oldLevel = DataService:Get(player, "Rpg.Level")
	if newLevel ~= oldLevel then
		DataService:Set(player, "Rpg.Level", newLevel)
		applyHealth(player, true)
		if type(oldLevel) == "number" and newLevel > oldLevel then
			Net.Fire("Notify", player, `Stufe {newLevel} erreicht!`, "Announcement", 4)
		end
	end
end

-- Zählt alle aktiven Quests des Spielers weiter, die auf dieses Ziel warten.
local function advance(player: Player, target: string)
	local active = DataService:Get(player, "Rpg.Quests.Active")
	if type(active) ~= "table" then
		return
	end
	for questId, progress in active do
		local quest = Config.Quests[questId]
		if quest and quest.Target == target and progress < quest.Count then
			DataService:Set(player, { "Rpg", "Quests", "Active", questId }, progress + 1)
			if progress + 1 >= quest.Count then
				Net.Fire(
					"Notify",
					player,
					`Quest erfüllt: {quest.Title}. Hol dir die Belohnung im Quest-Menü.`,
					"Success",
					5
				)
			end
		end
	end
end

local function onAccept(player: Player, questId: string)
	local quests = DataService:Get(player, "Rpg.Quests")
	local level = DataService:Get(player, "Rpg.Level")
	local quest = Config.Quests[questId]
	if type(quests) ~= "table" or type(level) ~= "number" then
		return
	end
	if quests.Active[questId] ~= nil or quests.Done[questId] or level < quest.RequiresLevel then
		return
	end
	local count = 0
	for _ in quests.Active do
		count += 1
	end
	if count >= Config.MaxActiveQuests then
		Net.Fire("Notify", player, "Du hast schon genug Quests angenommen.", "Error")
		return
	end
	DataService:Set(player, { "Rpg", "Quests", "Active", questId }, 0)
end

local function onClaim(player: Player, questId: string)
	local quests = DataService:Get(player, "Rpg.Quests")
	local quest = Config.Quests[questId]
	if type(quests) ~= "table" then
		return
	end
	local progress = quests.Active[questId]
	if type(progress) ~= "number" or progress < quest.Count then
		return
	end
	-- Erst als erledigt vermerken, dann belohnen: So kann nichts doppelt ausgezahlt werden.
	DataService:Set(player, { "Rpg", "Quests", "Active", questId }, nil)
	DataService:Set(player, { "Rpg", "Quests", "Done", questId }, true)
	DataService:Increment(player, "Rpg.Coins", quest.RewardCoins)
	ProgressService:AddXp(player, quest.RewardXp)
	Net.Fire("Notify", player, `Belohnung: {quest.RewardXp} XP, {quest.RewardCoins} Münzen`, "Success")
end

function ProgressService:Init()
	Net.On("Rpg.AcceptQuest", { Check.keyOf(Config.Quests) }, onAccept, { Rate = 4 })
	Net.On("Rpg.ClaimQuest", { Check.keyOf(Config.Quests) }, onClaim, { Rate = 4 })
end

function ProgressService:Start()
	EnemyService.Killed:Connect(function(player: Player, enemyType: string)
		local definition = Config.Enemies[enemyType]
		if not definition or not DataService:IsLoaded(player) then
			return
		end
		DataService:Increment(player, "Rpg.Kills", 1)
		DataService:Increment(player, "Rpg.Coins", definition.Coins)
		ProgressService:AddXp(player, definition.Xp)
		advance(player, enemyType)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			if DataService:WaitForData(player) then
				applyHealth(player, true)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	DataService:OnPlayerLoaded(function(player)
		applyHealth(player, true)
	end)
end

return ProgressService
