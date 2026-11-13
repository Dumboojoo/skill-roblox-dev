--!strict
--[[
	DataController – der Spielstand auf dem Client (nur lesen).

	Der Server schickt den Spielstand einmal komplett und danach jede Änderung.
	Der Client ändert NIE selbst etwas daran; will der Spieler etwas tun, schickt
	er dem Server eine Bitte (Net.Send), und der Server ändert den Spielstand.

	DataController:Get("Currency.Coins")
	DataController:Observe("Currency.Coins", function(coins) label.Text = ... end)
	   -> wird sofort mit dem aktuellen Wert aufgerufen (sobald geladen) und bei jeder Änderung.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local TablePath = require(Shared.Util.TablePath)

type Path = TablePath.Path
type Segments = TablePath.Segments
type Observer = { Segments: Segments, Callback: (value: any) -> () }

local DataController = {
	Priority = 10,
	Loaded = Signal.new() :: Signal.Signal<any>,
	Changed = Signal.new() :: Signal.Signal<Segments, any>,
}

local data: { [string]: any }? = nil
local observers: { Observer } = {}

local function runObservers(changed: Segments?)
	for _, observer in table.clone(observers) do
		local affected = changed == nil
			or TablePath.StartsWith(changed, observer.Segments)
			or TablePath.StartsWith(observer.Segments, changed)
		if affected then
			task.spawn(observer.Callback, TablePath.Get(data, observer.Segments))
		end
	end
end

function DataController:Init()
	Net.Listen("Data.Sync", function(operation: string, a: any, b: any)
		if operation == "Init" then
			local first = data == nil
			data = a
			if first then
				DataController.Loaded:Fire(a)
			end
			runObservers(nil)
		elseif operation == "Set" and data then
			local segments = a :: Segments
			if #segments > 0 then
				TablePath.Set(data, segments, b)
				DataController.Changed:Fire(segments, b)
				runObservers(segments)
			end
		end
	end)
end

function DataController:IsLoaded(): boolean
	return data ~= nil
end

-- Wartet, bis der Spielstand angekommen ist.
function DataController:WaitForData(): { [string]: any }
	while data == nil do
		DataController.Loaded:Wait()
	end
	return data :: { [string]: any }
end

function DataController:Get(path: Path?): any
	if data == nil then
		return nil
	end
	if path == nil then
		return data
	end
	return TablePath.Get(data, path)
end

function DataController:Observe(path: Path, callback: (value: any) -> ()): () -> ()
	local observer: Observer = { Segments = TablePath.Parse(path), Callback = callback }
	table.insert(observers, observer)
	if data ~= nil then
		task.spawn(callback, TablePath.Get(data, observer.Segments))
	end
	return function()
		local index = table.find(observers, observer)
		if index then
			table.remove(observers, index)
		end
	end
end

return DataController
