--!strict
--[[
	SettingsService – nimmt Einstellungen des Spielers an (Lautstärke usw.) und
	schreibt sie in den Spielstand unter "Settings".

	Erlaubt ist nur, was in GameConfig.Settings.Entries steht. Der Typ richtet sich
	nach dem aktuellen Wert im Spielstand: Zahlen werden auf 0 bis 1 begrenzt,
	Wahrheitswerte bleiben Wahrheitswerte. So kann ein Client nichts Fremdes in den
	Spielstand schreiben.

	Neue Einstellung: Feld in Config/DataSections/Core (Settings) ergänzen und in
	GameConfig.Settings.Entries eintragen. Kein Code nötig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local function isAllowed(key: string): boolean
	for _, entry in GameConfig.Settings.Entries do
		if entry.Key == key then
			return true
		end
	end
	return false
end

local function onSet(player: Player, key: string, value: any)
	if not isAllowed(key) then
		return
	end
	local current = DataService:Get(player, { "Settings", key })
	if type(current) == "number" and Check.number(value) then
		DataService:Set(player, { "Settings", key }, math.clamp(value, 0, 1))
	elseif type(current) == "boolean" and type(value) == "boolean" then
		DataService:Set(player, { "Settings", key }, value)
	end
end

function SettingsService:Init()
	Net.On("Settings.Set", { Check.stringMax(40), Check.any }, onSet, { Rate = 10 })
end

return SettingsService
