--[[
	blockout.luau – Helfer zum Bauen von Block-Welten DIREKT IN STUDIO.

	Kein Spielcode. Dieser Text wird über das Studio-MCP-Werkzeug `execute_luau`
	im Bearbeitungsmodus ausgeführt: Helfer von hier kopieren, darunter die
	eigentlichen Bau-Aufrufe schreiben, als EIN Skript abschicken.

	Regeln beim Bauen:
	  - Alles Gebaute liegt unter Workspace.Welt in sprechend benannten Ordnern.
	  - Jeder Bau-Aufruf ist ein Rückgängig-Schritt in Studio (Strg+Z).
	  - Neu bauen = Ordner mit Blockout.Clear leeren und neu erzeugen. Teile oder
	    Ordner mit dem Attribut Handarbeit = true bleiben dabei unangetastet
	    (das setzt der Nutzer oder Claude, sobald etwas von Hand verfeinert wurde).
	  - Was der Code finden soll, bekommt Tags und Attribute (Welt-Vertrag des Genres).
	  - Maße: Ein Charakter ist ca. 5 Studs hoch und 2 breit, springt 7 hoch und
	    ca. 12 weit. Türen mind. 5 x 8, Gänge mind. 8 breit.

	Beispiel am Ende der Datei.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local Blockout = {}

-- Ordner unter Workspace holen oder anlegen: Blockout.Folder("Welt/Arena/Deckung")
function Blockout.Folder(path: string): Instance
	local current: Instance = Workspace
	for _, name in string.split(path, "/") do
		local child = current:FindFirstChild(name)
		if not child then
			child = Instance.new("Folder")
			child.Name = name
			child.Parent = current
		end
		current = child
	end
	return current
end

-- Leert einen Ordner für einen Neubau. Alles mit Attribut Handarbeit = true bleibt.
function Blockout.Clear(path: string): number
	local folder = Blockout.Folder(path)
	local removed = 0
	for _, child in folder:GetChildren() do
		if child:GetAttribute("Handarbeit") ~= true then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

--[[
	Ein Block. Pflicht: Size und Position (oder CFrame). Alles andere optional:
	  Name, Color, Material, Transparency, CanCollide, Shape, Parent,
	  Tags = { "Checkpoint" }, Attributes = { Stage = 1 }
]]
function Blockout.Part(properties: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = Color3.fromRGB(163, 162, 165)

	local parent: Instance? = nil
	for key, value in properties do
		if key == "Parent" then
			parent = value
		elseif key == "Tags" then
			for _, tag in value do
				part:AddTag(tag)
			end
		elseif key == "Attributes" then
			for name, attribute in value do
				part:SetAttribute(name, attribute)
			end
		else
			(part :: any)[key] = value
		end
	end
	part.Parent = parent or Workspace
	return part
end

-- Boden mit der Oberkante auf Höhe `center.Y`.
function Blockout.Floor(center: Vector3, sizeX: number, sizeZ: number, color: Color3?, parent: Instance?): Part
	return Blockout.Part({
		Name = "Boden",
		Size = Vector3.new(sizeX, 2, sizeZ),
		Position = center - Vector3.new(0, 1, 0),
		Color = color or Color3.fromRGB(120, 124, 132),
		Parent = parent,
	})
end

-- Wand zwischen zwei Punkten am Boden.
function Blockout.Wall(from: Vector3, to: Vector3, height: number, color: Color3?, parent: Instance?): Part
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	return Blockout.Part({
		Name = "Wand",
		Size = Vector3.new(1.5, height, length),
		CFrame = CFrame.lookAt(middle + Vector3.new(0, height / 2, 0), to + Vector3.new(0, height / 2, 0)),
		Color = color or Color3.fromRGB(92, 96, 104),
		Parent = parent,
	})
end

-- Rechteckiger Raum: Boden und vier Wände. `doors` = Lücken, z. B. { N = 10 } für eine 10 Studs breite Öffnung im Norden.
function Blockout.Room(
	center: Vector3,
	sizeX: number,
	sizeZ: number,
	height: number,
	doors: { [string]: number }?,
	parent: Instance?
)
	Blockout.Floor(center, sizeX, sizeZ, nil, parent)
	local halfX, halfZ = sizeX / 2, sizeZ / 2
	local sides = {
		N = { Vector3.new(-halfX, 0, -halfZ), Vector3.new(halfX, 0, -halfZ) },
		S = { Vector3.new(-halfX, 0, halfZ), Vector3.new(halfX, 0, halfZ) },
		W = { Vector3.new(-halfX, 0, -halfZ), Vector3.new(-halfX, 0, halfZ) },
		E = { Vector3.new(halfX, 0, -halfZ), Vector3.new(halfX, 0, halfZ) },
	}
	for name, ends in sides do
		local from, to = center + ends[1], center + ends[2]
		local gap = if doors then doors[name] else nil
		if gap then
			local direction = (to - from).Unit
			local middle = (from + to) / 2
			Blockout.Wall(from, middle - direction * gap / 2, height, nil, parent)
			Blockout.Wall(middle + direction * gap / 2, to, height, nil, parent)
		else
			Blockout.Wall(from, to, height, nil, parent)
		end
	end
end

-- Treppe aus Stufen von `from` (unten) in Richtung `direction`.
function Blockout.Stairs(from: Vector3, direction: Vector3, steps: number, width: number, parent: Instance?)
	local flat = Vector3.new(direction.X, 0, direction.Z).Unit
	for index = 1, steps do
		local position = from + flat * (index - 0.5) * 2 + Vector3.new(0, index - 0.5, 0)
		Blockout.Part({
			Name = "Stufe",
			Size = Vector3.new(width, 1, 2),
			CFrame = CFrame.lookAt(position, position + flat),
			Parent = parent,
		})
	end
end

function Blockout.Spawn(position: Vector3, parent: Instance?): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = position
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 3 -- Sekunden Spawn-Schutz
	spawn.Parent = parent or Workspace
	return spawn
end

-- Führt `build` als EINEN Rückgängig-Schritt aus und meldet, was passiert ist.
function Blockout.Run(title: string, build: () -> ()): string
	local recording = ChangeHistoryService:TryBeginRecording(title)
	local ok, problem = pcall(build)
	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
	return if ok then `{title}: fertig` else `{title}: FEHLER {problem}`
end

--[[ BEISPIEL (unter die Helfer setzen und alles zusammen ausführen):

return Blockout.Run("Obby Stufe 1 bis 3", function()
	Blockout.Clear("Welt/Obby")
	local folder = Blockout.Folder("Welt/Obby")
	for stage = 0, 3 do
		Blockout.Part({
			Name = `Checkpoint{stage}`,
			Size = Vector3.new(10, 1, 10),
			Position = Vector3.new(0, 10, -stage * 40),
			Color = Color3.fromRGB(80, 200, 120),
			Tags = { "Checkpoint" },
			Attributes = { Stage = stage },
			Parent = folder,
		})
	end
	Blockout.Part({
		Name = "Abgrund",
		Size = Vector3.new(400, 1, 400),
		Position = Vector3.new(0, -20, -60),
		Transparency = 1,
		CanCollide = false,
		Tags = { "KillPart" },
		Parent = folder,
	})
end)
]]

return Blockout
