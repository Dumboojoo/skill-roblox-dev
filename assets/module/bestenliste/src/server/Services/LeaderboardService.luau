--!strict
--[[
	LeaderboardService – globale Ranglisten über alle Server.

	Technik: Pro Rangliste ein OrderedDataStore (Schlüssel = UserId, Wert = Zahl).
	Der normale Spielstand (ProfileStore) eignet sich dafür nicht, weil man ihn
	nicht sortiert abfragen kann. Dies ist neben dem DataService die einzige
	Stelle, die DataStoreService direkt benutzt.

	Anfragegrenzen: DataStores erlauben nur eine begrenzte Zahl von Aufrufen pro
	Minute. Deshalb wird gebündelt und selten gearbeitet:
	  - alle RefreshSeconds: Werte der anwesenden Spieler schreiben, Top-Liste lesen
	  - beim Verlassen: Wert des Spielers ein letztes Mal schreiben
	  - vor jedem Aufruf wird das verbleibende Budget geprüft
	Ranglisten sind dadurch bis zu ein paar Minuten alt. Das ist normal und gewollt.

	Abfragen: LeaderboardService:GetTop("PlayTime") oder vom Client Net.Call("Leaderboard.Get", "PlayTime").
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Config = require(Shared.Config.Leaderboards)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local DataService = require(script.Parent.DataService)

export type Entry = { Rank: number, UserId: number, Name: string, Value: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local top: { [string]: { Entry } } = {}
local names: { [number]: string } = {}
local boards: { [string]: { TextLabel } } = {} -- Tafeln in der Welt je Rangliste
local warned = false

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

local function hasBudget(requestType: Enum.DataStoreRequestType): boolean
	return DataStoreService:GetRequestBudgetForRequestType(requestType) > 2
end

local function warnOnce(problem: any)
	if not warned then
		warned = true
		warn(
			`[Bestenliste] DataStore nicht erreichbar ({problem}). In Studio: Spieleinstellungen → Sicherheit → API-Dienste einschalten.`
		)
	end
end

local function nameOf(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok then name else `Spieler {userId}`
	names[userId] = result
	return result
end

local function storedValue(player: Player, board: Config.Board): number?
	local value = DataService:Get(player, board.Path)
	if type(value) ~= "number" then
		return nil
	end
	local scaled = math.floor(value * board.Scale + 0.5)
	-- Bei Bestzeiten bedeutet 0 "noch keine Zeit" und gehört nicht in die Liste.
	if board.Ascending and scaled <= 0 then
		return nil
	end
	return scaled
end

function LeaderboardService:FormatValue(boardKey: string, value: number): string
	local board = Config.Boards[boardKey]
	local actual = value / board.Scale
	if board.Format == "Time" then
		return if board.Scale > 1 then Format.TimeMs(actual) else Format.Time(actual)
	end
	return Format.Commas(actual)
end

------------------------------------------------------------------------------
-- Schreiben und Lesen
------------------------------------------------------------------------------

local function writePlayer(player: Player)
	for boardKey, board in Config.Boards do
		local value = storedValue(player, board)
		if value and hasBudget(Enum.DataStoreRequestType.SetIncrementSortedAsync) then
			local ok, problem = pcall(function()
				stores[boardKey]:SetAsync(tostring(player.UserId), value)
			end)
			if not ok then
				warnOnce(problem)
			end
		end
	end
end

local function renderBoards(boardKey: string)
	local labels = boards[boardKey]
	if not labels then
		return
	end
	local lines = {}
	for _, entry in top[boardKey] or {} :: { Entry } do
		table.insert(lines, `{entry.Rank}.  {entry.Name}   {LeaderboardService:FormatValue(boardKey, entry.Value)}`)
	end
	local text = if #lines > 0 then table.concat(lines, "\n") else "Noch keine Einträge"
	for _, label in labels do
		label.Text = text
	end
end

local function readBoard(boardKey: string, board: Config.Board)
	if not hasBudget(Enum.DataStoreRequestType.GetSortedAsync) then
		return
	end
	local ok, result = pcall(function()
		local pages = stores[boardKey]:GetSortedAsync(board.Ascending, Config.TopCount)
		return pages:GetCurrentPage()
	end)
	if not ok then
		warnOnce(result)
		return
	end
	local entries: { Entry } = {}
	for rank, item in result :: { { key: string, value: number } } do
		local userId = tonumber(item.key) or 0
		table.insert(entries, { Rank = rank, UserId = userId, Name = nameOf(userId), Value = item.value })
	end
	top[boardKey] = entries
	renderBoards(boardKey)
end

function LeaderboardService:GetTop(boardKey: string): { Entry }
	return top[boardKey] or {}
end

-- Sofort aktualisieren (z. B. Admin-Befehl). Sparsam benutzen.
function LeaderboardService:Refresh()
	for _, player in Players:GetPlayers() do
		if DataService:IsLoaded(player) then
			writePlayer(player)
		end
	end
	for boardKey, board in Config.Boards do
		readBoard(boardKey, board)
	end
end

------------------------------------------------------------------------------
-- Tafeln in der Welt
------------------------------------------------------------------------------

local function observeBoard(instance: Instance): (() -> ())?
	local boardKey = instance:GetAttribute("Board")
	local board = if type(boardKey) == "string" then Config.Boards[boardKey] else nil
	if not instance:IsA("BasePart") or not board then
		warn(`[Bestenliste] {instance:GetFullName()}: Attribut Board fehlt oder ist unbekannt.`)
		return nil
	end
	local key = boardKey :: string

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.14, 0)
	title.BackgroundColor3 = Color3.fromRGB(27, 30, 39)
	title.BorderSizePixel = 0
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(246, 190, 68)
	title.Text = board.DisplayName
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Position = UDim2.fromScale(0, 0.14)
	list.Size = UDim2.fromScale(1, 0.86)
	list.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	list.BorderSizePixel = 0
	list.Font = Enum.Font.RobotoMono
	list.TextSize = 28
	list.TextColor3 = Color3.fromRGB(240, 242, 248)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lädt …"
	list.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 12)
	padding.Parent = list

	gui.Parent = instance
	boards[key] = boards[key] or {}
	table.insert(boards[key], list)
	renderBoards(key)

	return function()
		local labels = boards[key]
		local index = if labels then table.find(labels, list) else nil
		if labels and index then
			table.remove(labels, index)
		end
		gui:Destroy()
	end
end

------------------------------------------------------------------------------

function LeaderboardService:Init()
	for boardKey in Config.Boards do
		stores[boardKey] = DataStoreService:GetOrderedDataStore(`Leaderboard_{boardKey}_{Config.StoreVersion}`)
	end
	Net.OnInvoke("Leaderboard.Get", { Check.keyOf(Config.Boards) }, function(_player: Player, boardKey: string)
		return LeaderboardService:GetTop(boardKey)
	end, { Rate = 2 })
end

function LeaderboardService:Start()
	World.Observe("LeaderboardBoard", observeBoard)

	-- Letzter Stand beim Verlassen (läuft, solange der Spielstand noch offen ist).
	DataService.PlayerRemoving:Connect(function(player: Player)
		writePlayer(player)
	end)

	task.spawn(function()
		task.wait(10) -- erst die ersten Spielstände laden lassen
		while true do
			LeaderboardService:Refresh()
			task.wait(Config.RefreshSeconds)
		end
	end)
end

return LeaderboardService
