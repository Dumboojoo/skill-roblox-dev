--!strict
--[[
	Trove – sammelt alles, was später aufgeräumt werden muss.

	local trove = Trove.new()
	trove:Connect(part.Touched, onTouched)
	trove:Add(Instance.new("Part"))
	trove:Add(function() print("aufgeräumt") end)
	trove:Clean() -- trennt Verbindungen, zerstört Instanzen, ruft Funktionen auf

	Faustregel: Alles, was pro Spieler, pro Runde oder pro Objekt entsteht, gehört
	in einen Trove. So gibt es keine Speicherlecks und keine Geister-Verbindungen.
]]

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Extend: (self: Trove) -> Trove,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove.new(): Trove
	local self = setmetatable({ _items = {} }, Trove)
	return (self :: any) :: Trove
end

function Trove.Add(self: any, item: any): any
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: any, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(fn)
	table.insert(self._items, connection)
	return connection
end

-- Unter-Trove, der mit aufgeräumt wird (z. B. pro Charakter innerhalb eines Spieler-Troves).
function Trove.Extend(self: any): Trove
	local child = Trove.new()
	table.insert(self._items, child)
	return child
end

function Trove.Clean(self: any)
	local items = self._items
	self._items = {}
	-- Rückwärts: zuletzt Hinzugefügtes zuerst aufräumen.
	for index = #items, 1, -1 do
		local ok, problem = pcall(cleanItem :: any, items[index])
		if not ok then
			warn("[Trove] Fehler beim Aufräumen:", problem)
		end
	end
end

Trove.Destroy = Trove.Clean

return Trove
