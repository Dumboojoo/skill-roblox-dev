--!strict
--[[
	DataService – der einzige Ort, an dem Spielstände geladen, geändert und
	gespeichert werden. Kein anderes Skript ruft DataStoreService direkt auf.

	Darunter arbeitet ProfileStore (server/Packages): Sitzungssperre (ein Spielstand
	ist immer nur auf EINEM Server offen -> keine Duplikate), automatisches
	Speichern, sicheres Speichern beim Herunterfahren.

	LESEN
	  DataService:Get(player, "Currency.Coins")       -- nil, solange nicht geladen
	  DataService:WaitForData(player)                 -- wartet, bis geladen (oder Spieler weg)
	  DataService:OnPlayerLoaded(function(player, data) ... end)  -- für alle jetzigen und künftigen Spieler

	ÄNDERN (nur so! Dadurch wird automatisch gespeichert UND an den Client geschickt)
	  DataService:Set(player, "Settings.MusicVolume", 0.3)
	  DataService:Increment(player, "Currency.Coins", 25)
	  DataService:Update(player, "Inventory.Items", function(items) table.insert(items, id) return items end)

	BEOBACHTEN
	  DataService:Observe(player, "Currency.Coins", function(new, old) ... end)
	  DataService.Changed:Connect(function(player, segments, new, old) ... end)

	Tabellen aus Get() nie direkt verändern, ohne danach Set/Update für denselben
	Pfad aufzurufen, sonst erfährt der Client nichts davon.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local DataTemplate = require(Shared.Config.DataTemplate)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local TablePath = require(Shared.Util.TablePath)
local Migrate = require(script.Parent.Parent.Data.Migrate)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore) :: any

type Path = TablePath.Path
type Segments = TablePath.Segments
type Observer = { Segments: Segments, Callback: (new: any, old: any) -> () }

local SYNC_REMOTE = "Data.Sync"
local KEY_PREFIX = "Player_"
local MAX_RECEIPTS = 100
local RECEIPT_SAVE_ATTEMPTS = 4
local RECEIPT_SAVE_WAIT = 8
local PLAYTIME_INTERVAL = 60 -- Sekunden zwischen zwei Gutschriften der Spielzeit

local DataService = {
	Priority = 10, -- vor allen anderen Services bereit
	PlayerLoaded = Signal.new() :: Signal.Signal<Player, any>,
	PlayerRemoving = Signal.new() :: Signal.Signal<Player, any>, -- letzte Chance, etwas in den Spielstand zu schreiben
	Changed = Signal.new() :: Signal.Signal<Player, Segments, any, any>,
}

local store: any = nil
local profiles: { [Player]: any } = {}
local observers: { [Player]: { Observer } } = {}
local playTimeMark: { [Player]: number } = {} -- bis wann die Spielzeit schon gutgeschrieben ist
local leaderstatValues: { [Player]: { [string]: IntValue } } = {}

------------------------------------------------------------------------------
-- Intern
------------------------------------------------------------------------------

local function isPrivate(segments: Segments): boolean
	local first = segments[1]
	return type(first) == "string" and string.sub(first, 1, 1) == "_"
end

-- Kopie des Spielstands ohne private Schlüssel (beginnen mit "_") für den Client.
local function publicSnapshot(data: { [string]: any }): { [string]: any }
	local snapshot = {}
	for key, value in data do
		if string.sub(key, 1, 1) ~= "_" then
			snapshot[key] = value
		end
	end
	return snapshot
end

local function updateLeaderstats(player: Player, data: any)
	local values = leaderstatValues[player]
	if not values then
		return
	end
	for _, spec in DataTemplate.Leaderstats do
		local value = TablePath.Get(data, spec.Path)
		local holder = values[spec.Name]
		if holder and type(value) == "number" then
			holder.Value = math.floor(value)
		end
	end
end

local function createLeaderstats(player: Player, data: any)
	if #DataTemplate.Leaderstats == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local values = {}
	for _, spec in DataTemplate.Leaderstats do
		local holder = Instance.new("IntValue")
		holder.Name = spec.Name
		holder.Parent = folder
		values[spec.Name] = holder
	end
	leaderstatValues[player] = values
	updateLeaderstats(player, data)
	folder.Parent = player
end

local function notify(player: Player, segments: Segments, new: any, old: any)
	local profile = profiles[player]
	if not profile then
		return
	end

	if not isPrivate(segments) then
		Net.Fire(SYNC_REMOTE, player, "Set", segments, new)
	end

	local list = observers[player]
	if list then
		for _, observer in table.clone(list) do
			-- Betroffen ist ein Beobachter, wenn sein Pfad über, auf oder unter der Änderung liegt.
			local above = TablePath.StartsWith(segments, observer.Segments)
			local below = TablePath.StartsWith(observer.Segments, segments)
			if above and below then
				task.spawn(observer.Callback, new, old)
			elseif above or below then
				-- Der alte Wert ist hier nicht bekannt (es wurde ein Teil oder das Ganze ersetzt).
				task.spawn(observer.Callback, TablePath.Get(profile.Data, observer.Segments), nil)
			end
		end
	end

	updateLeaderstats(player, profile.Data)
	DataService.Changed:Fire(player, segments, new, old)
end

local function loadPlayer(player: Player)
	local profile = store:StartSessionAsync(KEY_PREFIX .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Lieber kicken als mit leeren Daten spielen lassen: Sonst würde der echte Spielstand überschrieben.
		player:Kick(GameConfig.Data.LoadFailedMessage)
		return
	end

	profile:AddUserId(player.UserId) -- für Löschanfragen nach DSGVO

	local ok, migrated = Migrate.Run(profile.Data, DataTemplate.Version, DataTemplate.Migrations)
	if not ok then
		warn(`[DataService] {player.Name}: {migrated}`)
		profile:EndSession()
		player:Kick(GameConfig.Data.LoadFailedMessage)
		return
	end
	-- Dieselbe Tabelle behalten (ProfileStore hält eine Referenz darauf), nur den Inhalt ersetzen.
	table.clear(profile.Data)
	for key, value in migrated do
		profile.Data[key] = value
	end
	profile:Reconcile() -- fehlende Felder aus der Vorlage ergänzen

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick(GameConfig.Data.SessionEndedMessage)
	end)

	local data = profile.Data
	if data.Stats.FirstJoin == 0 then
		data.Stats.FirstJoin = os.time()
	end
	data.Stats.Joins += 1

	profiles[player] = profile
	observers[player] = {}
	playTimeMark[player] = os.clock()

	createLeaderstats(player, data)
	Net.Fire(SYNC_REMOTE, player, "Init", publicSnapshot(data))
	DataService.PlayerLoaded:Fire(player, data)
end

local function unloadPlayer(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.PlayerRemoving:Fire(player, profile.Data)
		local mark = playTimeMark[player]
		if mark then
			profile.Data.Stats.PlayTime += math.floor(os.clock() - mark)
		end
		profile:EndSession() -- speichert und gibt die Sitzungssperre frei
	end
	profiles[player] = nil
	observers[player] = nil
	playTimeMark[player] = nil
	leaderstatValues[player] = nil
end

------------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------------

function DataService:Init()
	store = ProfileStore.New(GameConfig.Data.StoreName, DataTemplate.Template)
	if RunService:IsStudio() and not GameConfig.Data.SaveInStudio then
		store = store.Mock
		print("[DataService] Studio: Es werden Testdaten benutzt (GameConfig.Data.SaveInStudio = false).")
	end
	Net.Declare(SYNC_REMOTE)
end

function DataService:Start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(unloadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	-- Spielzeit laufend gutschreiben. So stimmt sie auch, wenn der Server unsauber endet,
	-- und Ranglisten nach Spielzeit bewegen sich schon während der Sitzung.
	task.spawn(function()
		while true do
			task.wait(PLAYTIME_INTERVAL)
			local now = os.clock()
			for player in profiles do
				local mark = playTimeMark[player]
				local elapsed = if mark then math.floor(now - mark) else 0
				if mark and elapsed > 0 then
					playTimeMark[player] = mark + elapsed
					DataService:Increment(player, "Stats.PlayTime", elapsed)
				end
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Lesen
------------------------------------------------------------------------------

function DataService:IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Ganzer Spielstand (path = nil) oder ein Teil davon. nil, solange nicht geladen.
function DataService:Get(player: Player, path: Path?): any
	local profile = profiles[player]
	if not profile then
		return nil
	end
	if path == nil then
		return profile.Data
	end
	return TablePath.Get(profile.Data, path)
end

-- Wartet, bis der Spielstand da ist. nil, wenn der Spieler vorher geht.
function DataService:WaitForData(player: Player): any
	while player.Parent == Players do
		local profile = profiles[player]
		if profile then
			return profile.Data
		end
		task.wait(0.1)
	end
	return nil
end

-- Für Features: läuft einmal für jeden schon geladenen und jeden künftigen Spieler.
function DataService:OnPlayerLoaded(callback: (player: Player, data: any) -> ()): Signal.Connection
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
	return DataService.PlayerLoaded:Connect(callback)
end

------------------------------------------------------------------------------
-- Ändern
------------------------------------------------------------------------------

function DataService:Set(player: Player, path: Path, value: any): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local segments = TablePath.Parse(path)
	local old = TablePath.Set(profile.Data, segments, value)
	notify(player, segments, value, old)
	return true
end

-- `transform` bekommt den aktuellen Wert und gibt den neuen zurück.
-- Bei Tabellen darf es die Tabelle auch direkt verändern und zurückgeben.
function DataService:Update(player: Player, path: Path, transform: (current: any) -> any): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local segments = TablePath.Parse(path)
	local current = TablePath.Get(profile.Data, segments)
	local new = transform(current)
	TablePath.Set(profile.Data, segments, new)
	notify(player, segments, new, current)
	return true
end

-- Gibt den neuen Wert zurück (nil, wenn nicht geladen).
function DataService:Increment(player: Player, path: Path, amount: number): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local segments = TablePath.Parse(path)
	local current = TablePath.Get(profile.Data, segments)
	local old = if type(current) == "number" then current else 0
	local new = old + amount
	TablePath.Set(profile.Data, segments, new)
	notify(player, segments, new, old)
	return new
end

function DataService:Observe(player: Player, path: Path, callback: (new: any, old: any) -> ()): () -> ()
	local list = observers[player]
	if not list then
		return function() end
	end
	local observer: Observer = { Segments = TablePath.Parse(path), Callback = callback }
	table.insert(list, observer)
	return function()
		local index = table.find(list, observer)
		if index then
			table.remove(list, index)
		end
	end
end

------------------------------------------------------------------------------
-- Besondere Fälle
------------------------------------------------------------------------------

-- Sofort speichern. Nur für wirklich Wichtiges (Käufe); sonst reicht das automatische Speichern.
function DataService:Save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

--[[
	Führt `grant` für eine Kauf-/Belohnungs-ID genau EINMAL aus und wartet, bis das
	Ergebnis wirklich gespeichert ist. Gibt erst dann true zurück.

	Für MarketplaceService.ProcessReceipt: Nur bei true `PurchaseGranted` melden,
	sonst `NotProcessedYet`. Roblox ruft dann später erneut auf, und weil die ID
	schon vermerkt ist, wird nicht doppelt gutgeschrieben.

	`grant` darf nicht warten (kein task.wait, keine Web-Aufrufe).
]]
function DataService:GrantOnce(player: Player, receiptId: string, grant: () -> ()): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end

	local receipts = profile.Data._Receipts
	if not table.find(receipts, receiptId) then
		local ok, problem = pcall(grant :: any)
		if not ok then
			warn(`[DataService] Gutschrift {receiptId} fehlgeschlagen: {problem}`)
			return false
		end
		table.insert(receipts, receiptId)
		while #receipts > MAX_RECEIPTS do
			table.remove(receipts, 1)
		end
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData._Receipts
		return type(saved) == "table" and table.find(saved, receiptId) ~= nil
	end

	for _ = 1, RECEIPT_SAVE_ATTEMPTS do
		if isSaved() then
			return true
		end
		if not profile:IsActive() then
			return false
		end
		profile:Save()
		local deadline = os.clock() + RECEIPT_SAVE_WAIT
		while os.clock() < deadline and profile:IsActive() and not isSaved() do
			task.wait(0.25)
		end
	end
	return isSaved()
end

-- Spielstand eines Spielers lesen, der gerade NICHT auf diesem Server ist (wartet; kann nil sein).
function DataService:ReadOffline(userId: number): any
	local ok, profile = pcall(function()
		return store:GetAsync(KEY_PREFIX .. userId)
	end)
	if ok and profile then
		return profile.Data
	end
	return nil
end

-- Setzt den Spielstand auf die Vorlage zurück (Admin-Befehl). Verarbeitete Käufe bleiben vermerkt.
function DataService:Reset(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local receipts = profile.Data._Receipts
	table.clear(profile.Data)
	for key, value in TablePath.DeepCopy(DataTemplate.Template) do
		profile.Data[key] = value
	end
	profile.Data._Receipts = receipts
	profile.Data.Stats.FirstJoin = os.time()
	updateLeaderstats(player, profile.Data)
	Net.Fire(SYNC_REMOTE, player, "Init", publicSnapshot(profile.Data))
	-- Alles hat sich geändert: jeden Beobachter mit seinem neuen Wert aufrufen.
	local list = observers[player]
	if list then
		for _, observer in table.clone(list) do
			task.spawn(observer.Callback, TablePath.Get(profile.Data, observer.Segments), nil)
		end
	end
	DataService.Changed:Fire(player, {}, profile.Data, nil)
	return true
end

return DataService
