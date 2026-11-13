--!strict
--[[
	Net – der einzige Weg, wie Server und Client miteinander reden.

	Remotes werden beim ersten Gebrauch auf dem Server angelegt (Ordner
	ReplicatedStorage.Remotes). Niemand legt RemoteEvents von Hand an.

	SERVER
	  Net.On(name, checks, handler, options?)        Client -> Server (Ereignis)
	  Net.OnInvoke(name, checks, handler, options?)  Client -> Server mit Antwort
	  Net.Declare(name, options?)                    Server -> Client ankündigen (in Init)
	  Net.Fire(name, player, ...) / FireAll / FireExcept / FireNear

	CLIENT
	  Net.Send(name, ...)            Ereignis an den Server
	  Net.Call(name, ...)            Anfrage mit Antwort (wartet)
	  Net.Listen(name, handler)      auf Server-Ereignis hören

	Sicherheit ist eingebaut: `checks` ist eine Liste aus Check-Funktionen, eine pro
	Argument. Passt Anzahl oder Typ nicht, wird der Aufruf verworfen. Zusätzlich
	gilt pro Spieler und Remote eine Aufrufgrenze (Standard 20 pro Sekunde).
	Der Handler muss trotzdem die SPIELLOGIK prüfen (hat der Spieler genug Geld?
	ist er nah genug dran? ist die Abklingzeit vorbei?).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Check = require(script.Parent.Util.Check)

export type Options = {
	Rate: number?, -- erlaubte Aufrufe pro Sekunde (Standard 20)
	Burst: number?, -- kurzzeitig erlaubte Spitze (Standard Rate * 1.5)
	Unreliable: boolean?, -- UnreliableRemoteEvent: für häufige, verlustfreundliche Daten
}

export type Disconnectable = { Disconnect: (self: Disconnectable) -> () }

type Bucket = { Tokens: number, Last: number }

local IS_SERVER = RunService:IsServer()
local IS_STUDIO = RunService:IsStudio()
local FOLDER_NAME = "Remotes"
local DEFAULT_RATE = 20
local CLIENT_WARN_AFTER = 10

local Net = {}

local folder: Instance
local buckets: { [string]: { [Player]: Bucket } } = {}
local limits: { [string]: { Rate: number, Burst: number } } = {}

if IS_SERVER then
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = ReplicatedStorage
	folder = created

	Players.PlayerRemoving:Connect(function(player)
		for _, perPlayer in buckets do
			perPlayer[player] = nil
		end
	end)
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

------------------------------------------------------------------------------
-- Intern
------------------------------------------------------------------------------

local function serverRemote(name: string, className: string): Instance
	assert(IS_SERVER, "Nur auf dem Server aufrufbar")
	local existing = folder:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			-- Ein Event darf nachträglich zum „unzuverlässigen" werden, sonst ist es ein Namenskonflikt.
			error(`[Net] "{name}" existiert bereits als {existing.ClassName}, angefragt wurde {className}`)
		end
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function clientRemote(name: string): Instance
	local remote = folder:FindFirstChild(name)
	if remote then
		return remote
	end
	local warned = task.delay(CLIENT_WARN_AFTER, function()
		warn(`[Net] Warte seit {CLIENT_WARN_AFTER}s auf Remote "{name}". Legt der Server es an (Net.On/Net.Declare)?`)
	end)
	local waited = folder:WaitForChild(name)
	task.cancel(warned)
	return waited
end

local function setLimit(name: string, options: Options?)
	local rate = if options and options.Rate then options.Rate else DEFAULT_RATE
	local burst = if options and options.Burst then options.Burst else math.max(1, rate * 1.5)
	limits[name] = { Rate = rate, Burst = burst }
	buckets[name] = buckets[name] or {}
end

-- Token-Bucket: jeder Aufruf kostet einen Token, Tokens wachsen mit `Rate` pro Sekunde nach.
local function allow(name: string, player: Player): boolean
	local limit = limits[name]
	local perPlayer = buckets[name]
	local now = os.clock()
	local bucket = perPlayer[player]
	if not bucket then
		bucket = { Tokens = limit.Burst, Last = now }
		perPlayer[player] = bucket
	end
	bucket.Tokens = math.min(limit.Burst, bucket.Tokens + (now - bucket.Last) * limit.Rate)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function validate(checks: { Check.Checker }, count: number, args: { any }): boolean
	if count > #checks then
		return false
	end
	for index, checker in checks do
		if not checker(args[index]) then
			return false
		end
	end
	return true
end

local function accept(name: string, player: Player, checks: { Check.Checker }, count: number, args: { any }): boolean
	if not allow(name, player) then
		return false
	end
	if not validate(checks, count, args) then
		if IS_STUDIO then
			warn(`[Net] "{name}" von {player.Name} verworfen: Argumente bestehen die Prüfung nicht.`)
		end
		return false
	end
	return true
end

------------------------------------------------------------------------------
-- Server
------------------------------------------------------------------------------

function Net.Declare(name: string, options: Options?)
	local className = if options and options.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
	serverRemote(name, className)
end

function Net.On(name: string, checks: { Check.Checker }, handler: (player: Player, ...any) -> (), options: Options?)
	local className = if options and options.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent"
	local remote = serverRemote(name, className) :: any
	setLimit(name, options)
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		local count = select("#", ...)
		local args = { ... }
		if accept(name, player, checks, count, args) then
			handler(player, table.unpack(args, 1, #checks))
		end
	end)
end

function Net.OnInvoke(
	name: string,
	checks: { Check.Checker },
	handler: (player: Player, ...any) -> ...any,
	options: Options?
)
	local remote = serverRemote(name, "RemoteFunction") :: RemoteFunction
	setLimit(name, options)
	remote.OnServerInvoke = function(player: Player, ...: any): ...any
		local count = select("#", ...)
		local args = { ... }
		if not accept(name, player, checks, count, args) then
			return nil
		end
		-- Fehler nicht an den Client durchreichen (würde Server-Interna verraten).
		local results = table.pack(xpcall(handler, debug.traceback, player, table.unpack(args, 1, #checks)))
		if not results[1] then
			warn(`[Net] Fehler in "{name}":\n{results[2]}`)
			return nil
		end
		return table.unpack(results, 2, results.n)
	end
end

local function eventForFire(name: string): any
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	return serverRemote(name, "RemoteEvent")
end

function Net.Fire(name: string, player: Player, ...: any)
	eventForFire(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...: any)
	eventForFire(name):FireAllClients(...)
end

function Net.FireExcept(name: string, except: Player, ...: any)
	local remote = eventForFire(name)
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

-- Nur an Spieler in der Nähe (Effekte, Geräusche): spart Bandbreite auf großen Karten.
function Net.FireNear(name: string, position: Vector3, radius: number, ...: any)
	local remote = eventForFire(name)
	for _, player in Players:GetPlayers() do
		if player:DistanceFromCharacter(position) <= radius then
			remote:FireClient(player, ...)
		end
	end
end

------------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------------

function Net.Send(name: string, ...: any)
	(clientRemote(name) :: any):FireServer(...)
end

function Net.Call(name: string, ...: any): ...any
	return (clientRemote(name) :: RemoteFunction):InvokeServer(...)
end

-- Kehrt sofort zurück, auch wenn der Server das Remote erst später anlegt.
function Net.Listen(name: string, handler: (...any) -> ()): Disconnectable
	local active = true
	local connection: RBXScriptConnection? = nil

	task.spawn(function()
		local remote = clientRemote(name) :: any
		if active then
			connection = remote.OnClientEvent:Connect(handler)
		end
	end)

	local handle = {}
	function handle.Disconnect(_self: Disconnectable)
		active = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
	return handle
end

return Net
