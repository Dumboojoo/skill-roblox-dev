--!strict
--[[
	Signal – leichtgewichtiges Ereignis ohne BindableEvent.

	local changed = Signal.new() :: Signal.Signal<number, string>
	local connection = changed:Connect(function(amount, reason) ... end)
	changed:Fire(5, "Quest")
	connection:Disconnect()

	Jeder Zuhörer läuft in einem eigenen Thread: Ein Fehler oder ein `task.wait`
	in einem Zuhörer hält die anderen nicht auf.
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local connection = { Connected = true } :: any
	connection._fn = fn

	function connection.Disconnect(conn: any)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local handlers = self._handlers
		local index = table.find(handlers, conn)
		if index then
			table.remove(handlers, index)
		end
	end

	table.insert(self._handlers, connection)
	return connection
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local connection: Connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal.Fire(self: any, ...: any)
	-- Kopie, damit Zuhörer sich während des Feuerns gefahrlos trennen können.
	for _, connection in table.clone(self._handlers) :: { any } do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	for _, connection in self._handlers do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
