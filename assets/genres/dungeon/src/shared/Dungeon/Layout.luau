--!strict
--[[
	Layout – erzeugt den Grundriss eines Dungeons auf einem Raster.

	Reines Luau mit eigenem Zufallsgenerator: Derselbe Seed ergibt auf Server,
	Client und im Test immer denselben Dungeon. Getestet in tests/Dungeon.spec.luau.

	Ergebnis ist eine Liste von Zellen. Jede Zelle ist ein Raum mit Rasterposition,
	Art (Start, Combat, Treasure, Boss) und Türen nach N/E/S/W. Wie ein Raum
	AUSSIEHT, entscheidet der DungeonService (eigene Modelle oder Block-Räume).

	Verfahren: beim Startraum beginnen und wiederholt an einen zufälligen
	vorhandenen Raum in zufälliger Richtung einen neuen anhängen. Dadurch ist
	jeder Raum garantiert erreichbar. Der am weitesten entfernte Raum wird der
	Boss, ein Teil der Sackgassen wird zu Schatzräumen.
]]

export type Doors = { N: boolean, E: boolean, S: boolean, W: boolean }

export type Cell = {
	X: number,
	Y: number,
	Kind: string, -- "Start" | "Combat" | "Treasure" | "Boss"
	Doors: Doors,
	Depth: number, -- Anzahl Räume bis zum Start
}

local Layout = {}

Layout.Directions = {
	{ Name = "N", X = 0, Y = -1, Opposite = "S" },
	{ Name = "E", X = 1, Y = 0, Opposite = "W" },
	{ Name = "S", X = 0, Y = 1, Opposite = "N" },
	{ Name = "W", X = -1, Y = 0, Opposite = "E" },
}

-- Kleiner, überall gleich rechnender Zufallsgenerator (linearer Kongruenzgenerator).
local function generator(seed: number): (max: number) -> number
	local state = math.floor(seed) % 2147483647
	return function(max: number): number
		state = (state * 48271 + 12345) % 2147483647
		return state % max + 1
	end
end

function Layout.Key(x: number, y: number): string
	return `{x},{y}`
end

function Layout.Generate(seed: number, roomCount: number): { Cell }
	local nextRandom = generator(seed)
	local start: Cell = {
		X = 0,
		Y = 0,
		Kind = "Start",
		Doors = { N = false, E = false, S = false, W = false },
		Depth = 0,
	}
	local cells: { Cell } = { start }
	local byKey: { [string]: Cell } = { [Layout.Key(0, 0)] = start }

	local attempts = 0
	while #cells < roomCount and attempts < roomCount * 200 do
		attempts += 1
		local parent = cells[nextRandom(#cells)]
		local direction = Layout.Directions[nextRandom(4)]
		local x, y = parent.X + direction.X, parent.Y + direction.Y
		local key = Layout.Key(x, y)
		if not byKey[key] then
			local cell: Cell = {
				X = x,
				Y = y,
				Kind = "Combat",
				Doors = { N = false, E = false, S = false, W = false },
				Depth = parent.Depth + 1,
			}
			local parentDoors = parent.Doors :: any
			local cellDoors = cell.Doors :: any
			parentDoors[direction.Name] = true
			cellDoors[direction.Opposite] = true
			table.insert(cells, cell)
			byKey[key] = cell
		end
	end

	-- Boss: der Raum, der am weitesten vom Start entfernt ist.
	local boss = cells[#cells]
	for _, cell in cells do
		if cell.Depth > boss.Depth then
			boss = cell
		end
	end
	if boss ~= start then
		boss.Kind = "Boss"
	end

	-- Schatzräume: jede zweite Sackgasse (Raum mit nur einer Tür).
	local deadEnds = 0
	for _, cell in cells do
		if cell.Kind == "Combat" then
			local doors = 0
			for _, open in cell.Doors :: any do
				if open then
					doors += 1
				end
			end
			if doors == 1 then
				deadEnds += 1
				if deadEnds % 2 == 1 then
					cell.Kind = "Treasure"
				end
			end
		end
	end

	return cells
end

-- Zieht einen Eintrag nach Gewicht. `roll` ist eine Zufallszahl in [0, 1).
function Layout.PickWeighted<T>(entries: { T }, roll: number): T
	local total = 0
	for _, entry in entries do
		total += (entry :: any).Weight
	end
	local threshold = roll * total
	local running = 0
	for _, entry in entries do
		running += (entry :: any).Weight
		if threshold < running then
			return entry
		end
	end
	return entries[#entries]
end

return Layout
