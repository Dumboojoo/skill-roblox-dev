local Layout = require("../src/shared/Dungeon/Layout")

local function countKind(cells, kind)
	local count = 0
	for _, cell in cells do
		if cell.Kind == kind then
			count += 1
		end
	end
	return count
end

return function(t)
	t.test("Dungeon: gleicher Seed ergibt gleichen Grundriss", function()
		t.equal(Layout.Generate(1234, 9), Layout.Generate(1234, 9))
	end)

	t.test("Dungeon: Raumanzahl, genau ein Start und ein Boss", function()
		for seed = 1, 40 do
			local cells = Layout.Generate(seed * 7919, 9)
			t.equal(#cells, 9, `Seed {seed}`)
			t.equal(countKind(cells, "Start"), 1)
			t.equal(countKind(cells, "Boss"), 1)
		end
	end)

	t.test("Dungeon: keine zwei Räume auf demselben Feld", function()
		for seed = 1, 40 do
			local seen = {}
			for _, cell in Layout.Generate(seed, 12) do
				local key = Layout.Key(cell.X, cell.Y)
				t.falsy(seen[key], `doppeltes Feld {key}`)
				seen[key] = true
			end
		end
	end)

	t.test("Dungeon: Türen passen auf beiden Seiten zusammen", function()
		for seed = 1, 40 do
			local cells = Layout.Generate(seed, 12)
			local byKey = {}
			for _, cell in cells do
				byKey[Layout.Key(cell.X, cell.Y)] = cell
			end
			for _, cell in cells do
				for _, direction in Layout.Directions do
					if cell.Doors[direction.Name] then
						local neighbor = byKey[Layout.Key(cell.X + direction.X, cell.Y + direction.Y)]
						t.truthy(neighbor, "Tür führt ins Leere")
						t.truthy(neighbor.Doors[direction.Opposite], "Gegentür fehlt")
					end
				end
			end
		end
	end)

	t.test("Dungeon: jeder Raum ist vom Start erreichbar", function()
		for seed = 1, 40 do
			local cells = Layout.Generate(seed, 12)
			local byKey = {}
			for _, cell in cells do
				byKey[Layout.Key(cell.X, cell.Y)] = cell
			end
			local visited = { [Layout.Key(0, 0)] = true }
			local queue = { byKey[Layout.Key(0, 0)] }
			local reached = 1
			while #queue > 0 do
				local cell = table.remove(queue, 1)
				for _, direction in Layout.Directions do
					local key = Layout.Key(cell.X + direction.X, cell.Y + direction.Y)
					if cell.Doors[direction.Name] and not visited[key] then
						visited[key] = true
						reached += 1
						table.insert(queue, byKey[key])
					end
				end
			end
			t.equal(reached, #cells, `Seed {seed}`)
		end
	end)

	t.test("Dungeon: Boss ist nicht der Startraum und am weitesten weg", function()
		local cells = Layout.Generate(99, 10)
		local maxDepth = 0
		for _, cell in cells do
			maxDepth = math.max(maxDepth, cell.Depth)
		end
		for _, cell in cells do
			if cell.Kind == "Boss" then
				t.equal(cell.Depth, maxDepth)
				t.truthy(cell.Depth > 0)
			end
		end
	end)

	t.test("Dungeon: gewichtete Beute-Auswahl", function()
		local entries = { { Id = "A", Weight = 70 }, { Id = "B", Weight = 30 } }
		t.equal(Layout.PickWeighted(entries, 0).Id, "A")
		t.equal(Layout.PickWeighted(entries, 0.69).Id, "A")
		t.equal(Layout.PickWeighted(entries, 0.7).Id, "B")
		t.equal(Layout.PickWeighted(entries, 0.999).Id, "B")
	end)
end
