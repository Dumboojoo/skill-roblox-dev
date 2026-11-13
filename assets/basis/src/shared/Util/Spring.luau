--!strict
--[[
	Spring – gedämpfte Feder auf einem Vector3.

	Für alles, was sich „lebendig" bewegen soll, ohne Animationen zu brauchen:
	Waffen-Schwanken, Rückstoß, Kamerawackeln, federnde UI.

	local recoil = Spring.new(Vector3.zero, 180, 18)
	recoil:Impulse(Vector3.new(4, 0, 0))   -- Stoß
	local offset = recoil:Update(deltaTime) -- jeden Frame

	stiffness: wie stark die Feder zum Ziel zieht (höher = schneller)
	damping:   wie stark sie gebremst wird (höher = weniger Nachschwingen)
	Kritisch gedämpft (kein Überschwingen) ist ungefähr damping = 2 * sqrt(stiffness).
]]

export type Spring = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Stiffness: number,
	Damping: number,
	Impulse: (self: Spring, impulse: Vector3) -> (),
	Update: (self: Spring, deltaTime: number) -> Vector3,
	Reset: (self: Spring, position: Vector3?) -> (),
}

local MAX_STEP = 1 / 120
local MAX_DELTA = 1 / 10

local Spring = {}
Spring.__index = Spring

function Spring.new(initial: Vector3, stiffness: number, damping: number): Spring
	local self = setmetatable({
		Position = initial,
		Velocity = Vector3.zero,
		Target = initial,
		Stiffness = stiffness,
		Damping = damping,
	}, Spring)
	return (self :: any) :: Spring
end

function Spring.Impulse(self: Spring, impulse: Vector3)
	self.Velocity += impulse
end

function Spring.Update(self: Spring, deltaTime: number): Vector3
	-- In kleinen Teilschritten rechnen, damit die Feder auch bei Rucklern stabil bleibt.
	local remaining = math.min(deltaTime, MAX_DELTA)
	while remaining > 0 do
		local step = math.min(remaining, MAX_STEP)
		local force = (self.Target - self.Position) * self.Stiffness - self.Velocity * self.Damping
		self.Velocity += force * step
		self.Position += self.Velocity * step
		remaining -= step
	end
	return self.Position
end

function Spring.Reset(self: Spring, position: Vector3?)
	local value = position or self.Target
	self.Position = value
	self.Target = value
	self.Velocity = Vector3.zero
end

return Spring
