--[[
	modell_einbauen.luau – bringt ein importiertes Blender-Modell OHNE Gelenke in Form:
	Deko, Gebäudeteile, Waffen, Fahrzeug-Karosserien, Gegenstände
	(über `execute_luau` im Bearbeitungsmodus ausführen).

	Für Figuren und alles mit beweglichen Teilen stattdessen rig_bauen.luau benutzen.

	Kein Spielcode. Das Modell liegt schon in Studio (hochgeladen und eingefügt). Den Inhalt
	des Begleitzettels <Name>.roblox.json unten bei SHEET_JSON einfügen.

	Was das Skript tut:
	  - Größe auf Studs bringen, aufrecht stellen, Fußpunkt setzen (bleibt am Ort oder OPTIONS.Position)
	  - Farbe, Material, Textur bzw. SurfaceAppearance je Teil
	  - Kollision: ein unsichtbarer Kasten (schnell und verlässlich), je Teil oder keine
	  - verankern ODER alle Teile an das Hauptteil schweißen (für alles, was getragen oder bewegt wird)
	  - Andockpunkte aus Blender als Attachments am Hauptteil (Griff, Mündung, …)
	  - Tags und Attribute setzen, in den Zielordner legen
	  - Bericht zurückgeben

	Vorn und hinten vertauscht? Bei Modellen aus EINEM Teil kann das Skript die Vorderseite
	nicht erkennen. Bildschirmfoto machen; wenn es falsch herum steht, MeshTurn = 180 setzen
	und noch einmal ausführen (vorher Strg+Z bzw. neu einfügen).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

-- Inhalt von <Name>.roblox.json (zwischen die Klammern kopieren).
local SHEET_JSON = [==[
{}
]==]

local OPTIONS = {
	Source = "", -- Pfad des importierten Modells, z. B. "Workspace.Kiste". Leer = Name aus dem Zettel
	Name = "", -- Name des fertigen Modells. Leer = Name aus dem Zettel
	Parent = "", -- Zielordner, z. B. "Workspace.Welt.Deko" oder "ReplicatedStorage.Assets.Weapons". Leer = bleibt
	Position = nil :: Vector3?, -- Fußpunkt in der Welt. nil = bleibt, wo das Modell lag
	Turn = 0, -- Blickrichtung in Grad um die Hochachse (0 = Vorderseite nach -Z)
	MeshTurn = 0, -- 0 | 90 | 180 | 270: dreht nur das Mesh gegenüber dem Zettel, falls vorn/hinten vertauscht ist
	Anchored = true, -- true: steht fest in der Welt. false: Teile werden ans Hauptteil geschweißt (Waffe, Gegenstand)
	Collision = "Kasten", -- "Kasten" (ein unsichtbarer Block) | "Teile" (jedes Teil für sich) | "Keine"
	Colors = true, -- Farben aus dem Zettel setzen (false, wenn eine Textur die Farbe liefert)
	Material = Enum.Material.SmoothPlastic,
	Texture = "", -- "rbxassetid://…": einfache Textur (TextureID) für alle Teile
	-- Für schönere Oberflächen stattdessen Karten angeben (erzeugt eine SurfaceAppearance je Teil):
	ColorMap = "",
	NormalMap = "",
	RoughnessMap = "",
	MetalnessMap = "",
	Tags = {} :: { string }, -- z. B. { "Collectible" }
	Attributes = {} :: { [string]: any }, -- z. B. { Value = 5 }
}

local report: { string } = {}
local warnings = 0

local function note(text: string)
	table.insert(report, text)
end

local function warnLine(text: string)
	warnings += 1
	table.insert(report, "HINWEIS  " .. text)
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

local function resolve(path: string, create: boolean): Instance?
	local current: Instance = game
	for index, name in string.split(path, ".") do
		local child: Instance? = nil
		if index == 1 then
			local ok, service = pcall(game.GetService, game, name)
			child = if ok then service else game:FindFirstChild(name)
		else
			child = current:FindFirstChild(name)
		end
		if not child then
			if not create or index == 1 then
				return nil
			end
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = current
			child = folder
		end
		current = child :: Instance
	end
	return current
end

local function axisRotations(): { CFrame }
	local axes = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis, Vector3.yAxis, -Vector3.yAxis }
	local upright: { CFrame } = {}
	local others: { CFrame } = {}
	for _, right in axes do
		for _, up in axes do
			if math.abs(right:Dot(up)) < 0.5 then
				local rotation = CFrame.fromMatrix(Vector3.zero, right, up)
				table.insert(if up == Vector3.yAxis then upright else others, rotation)
			end
		end
	end
	-- Aufrechte Lagen zuerst (die allererste ist "unverändert"): Bei gleich guter Passung gewinnt die frühere.
	table.move(others, 1, #others, #upright + 1, upright)
	return upright
end

local function worldExtents(rotation: CFrame, size: Vector3): Vector3
	local x, y, z = rotation.XVector, rotation.YVector, rotation.ZVector
	return Vector3.new(
		math.abs(x.X) * size.X + math.abs(y.X) * size.Y + math.abs(z.X) * size.Z,
		math.abs(x.Y) * size.X + math.abs(y.Y) * size.Y + math.abs(z.Y) * size.Z,
		math.abs(x.Z) * size.X + math.abs(y.Z) * size.Y + math.abs(z.Z) * size.Z
	)
end

local function sortedSize(size: Vector3): { number }
	local values = { size.X, size.Y, size.Z }
	table.sort(values)
	return values
end

local function build(sheet: any): Model
	-- 1. Modell und Teile finden
	local source: Instance? = nil
	if OPTIONS.Source ~= "" then
		source = resolve(OPTIONS.Source, false)
	else
		source = game:GetService("Workspace"):FindFirstChild(sheet.Name, true)
	end
	if not source then
		error(
			`Importiertes Modell nicht gefunden ({if OPTIONS.Source ~= "" then OPTIONS.Source else sheet.Name}). OPTIONS.Source setzen.`,
			0
		)
	end
	local container = source :: Instance
	if container.Parent == game or container:IsA("Workspace") then
		error("OPTIONS.Source muss das importierte Modell sein, kein ganzer Dienst wie Workspace.", 0)
	end
	local candidates = container:GetDescendants()
	table.insert(candidates, 1, container)

	local parts: { [string]: BasePart } = {}
	local missing: { string } = {}
	for _, entry in sheet.Parts do
		local found: BasePart? = nil
		for _, candidate in candidates do
			if candidate:IsA("BasePart") and candidate.Name == entry.Name then
				found = candidate
				break
			end
		end
		if found then
			parts[entry.Name] = found
		else
			table.insert(missing, entry.Name)
		end
	end
	if #missing > 0 then
		local present = {}
		for _, candidate in candidates do
			if candidate:IsA("BasePart") then
				table.insert(present, candidate.Name)
			end
		end
		error(
			`Diese Teile fehlen im importierten Modell: {table.concat(missing, ", ")}.\n`
				.. `Vorhanden sind: {table.concat(present, ", ")}.`,
			0
		)
	end

	-- 2. Sauberes Model
	local model = Instance.new("Model")
	model.Name = if OPTIONS.Name ~= "" then OPTIONS.Name else sheet.Name
	model.Parent = container.Parent
	for _, part in parts do
		for _, joint in part:GetChildren() do
			if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
				joint:Destroy()
			end
		end
		part.Anchored = true
		part.Parent = model
	end
	if container.Parent ~= model and not container:IsA("BasePart") then
		local leftover = false
		for _, descendant in container:GetDescendants() do
			if descendant:IsA("BasePart") then
				leftover = true
				break
			end
		end
		if leftover then
			warnLine(`In "{container.Name}" liegen noch Teile, die nicht im Zettel stehen. Die Hülle bleibt bestehen.`)
		else
			container:Destroy()
		end
	end

	-- 3. Größe
	local function centroids(): (Vector3, Vector3)
		local actual, expected, count = Vector3.zero, Vector3.zero, 0
		for _, entry in sheet.Parts do
			actual += parts[entry.Name].Position
			expected += vector(entry.Center)
			count += 1
		end
		return actual / count, expected / count
	end

	local actualCenter, expectedCenter = centroids()
	local actualSpread, expectedSpread = 0, 0
	for _, entry in sheet.Parts do
		actualSpread += (parts[entry.Name].Position - actualCenter).Magnitude
		expectedSpread += (vector(entry.Center) - expectedCenter).Magnitude
	end
	local scale = 1
	if expectedSpread > 0.01 and actualSpread > 0.0001 then
		scale = expectedSpread / actualSpread
	else
		local entry = sheet.Parts[1]
		local have = sortedSize(parts[entry.Name].Size)
		local want = sortedSize(vector(entry.Size))
		if have[3] > 0.0001 then
			scale = want[3] / have[3]
		end
	end
	if math.abs(scale - 1) > 0.002 then
		model:ScaleTo(model:GetScale() * scale)
		note(`Größe angepasst: Faktor {string.format("%.4f", scale)}`)
	end

	-- 4. Ausrichtung
	actualCenter, expectedCenter = centroids()
	local best: CFrame = CFrame.identity
	local bestError = math.huge
	local ties = 0
	for _, rotation in axisRotations() do
		local total = 0
		for _, entry in sheet.Parts do
			local part = parts[entry.Name]
			local predicted = actualCenter + rotation * (vector(entry.Center) - expectedCenter)
			total += (predicted - part.Position).Magnitude
			total += (worldExtents(rotation, vector(entry.Size)) - worldExtents(part.CFrame, part.Size)).Magnitude
		end
		if total < bestError - 0.001 then
			best, bestError, ties = rotation, total, 0
		elseif math.abs(total - bestError) <= 0.001 then
			ties += 1
		end
	end
	if ties > 0 then
		note(
			"Die Vorderseite lässt sich aus der Form nicht sicher erkennen: per Bildschirmfoto prüfen, sonst MeshTurn = 180."
		)
	end
	best = best * CFrame.Angles(0, math.rad(OPTIONS.MeshTurn), 0)

	local current = CFrame.new(actualCenter) * best * CFrame.new(-expectedCenter)
	local foot = OPTIONS.Position or current.Position
	local target = CFrame.new(foot) * CFrame.Angles(0, math.rad(OPTIONS.Turn), 0)
	local move = target * current:Inverse()
	for _, part in parts do
		part.CFrame = move * part.CFrame
	end

	-- 5. Aussehen
	local useMaps = OPTIONS.ColorMap ~= ""
		or OPTIONS.NormalMap ~= ""
		or OPTIONS.RoughnessMap ~= ""
		or OPTIONS.MetalnessMap ~= ""
	local triangles = 0
	for _, entry in sheet.Parts do
		local part = parts[entry.Name]
		triangles += entry.Triangles or 0
		if OPTIONS.Colors then
			part.Color = Color3.fromRGB(entry.Color[1], entry.Color[2], entry.Color[3])
		end
		part.Material = OPTIONS.Material
		if part:IsA("MeshPart") then
			if OPTIONS.Texture ~= "" then
				part.TextureID = OPTIONS.Texture
			end
			if useMaps then
				local old = part:FindFirstChildOfClass("SurfaceAppearance")
				if old then
					old:Destroy()
				end
				local surface = Instance.new("SurfaceAppearance")
				surface.ColorMap = OPTIONS.ColorMap
				surface.NormalMap = OPTIONS.NormalMap
				surface.RoughnessMap = OPTIONS.RoughnessMap
				surface.MetalnessMap = OPTIONS.MetalnessMap
				surface.Parent = part
			end
		elseif OPTIONS.Texture ~= "" or useMaps then
			warnLine(`{entry.Name}: ist kein MeshPart, Textur nicht gesetzt.`)
		end
	end

	-- 6. Hauptteil, Kollision, Halt
	local primaryName = sheet.Root or sheet.Parts[1].Name
	local primary = parts[primaryName]
	model.PrimaryPart = primary

	for _, part in parts do
		part.CanCollide = OPTIONS.Collision == "Teile"
		if OPTIONS.Collision == "Teile" and part:IsA("MeshPart") then
			-- Kasten statt genauer Form: viel billiger. Lässt sich nur im Bearbeitungsmodus umstellen.
			local ok = pcall(function()
				(part :: any).CollisionFidelity = Enum.CollisionFidelity.Box
			end)
			if not ok then
				warnLine(
					`{part.Name}: Kollisions-Art ließ sich nicht umstellen (im Eigenschaften-Fenster auf "Box" setzen).`
				)
			end
		end
	end

	local size = vector(sheet.SizeStuds)
	if OPTIONS.Collision == "Kasten" then
		local box = Instance.new("Part")
		box.Name = "Collision"
		box.Size = Vector3.new(math.max(size.X, 0.2), math.max(size.Y, 0.2), math.max(size.Z, 0.2))
		box.CFrame = target * CFrame.new(vector(sheet.CenterStuds))
		box.Transparency = 1
		box.CanCollide = true
		box.Anchored = true
		box.TopSurface = Enum.SurfaceType.Smooth
		box.BottomSurface = Enum.SurfaceType.Smooth
		box.Parent = model
		parts["Collision"] = box
	end

	if OPTIONS.Anchored then
		for _, part in parts do
			part.Anchored = true
		end
	else
		for _, part in parts do
			if part ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = part
				part.Massless = true
			end
			part.Anchored = false
		end
		note(
			"Nicht verankert: alle Teile sind ans Hauptteil geschweißt. Im Bearbeitungsmodus bleibt es stehen, im Spiel fällt es."
		)
	end
	-- Drehpunkt des Modells = Fußpunkt: So setzt PivotTo es sauber auf den Boden.
	model.WorldPivot = target

	-- 7. Andockpunkte (immer am Hauptteil, damit der Code sie an einer Stelle findet)
	local points = 0
	for _, entry in sheet.Attachments or {} do
		local attachment = Instance.new("Attachment")
		attachment.Name = entry.Name
		attachment.Parent = primary
		attachment.WorldCFrame = target * CFrame.new(vector(entry.Position))
		points += 1
	end

	-- 8. Vertrag mit dem Code
	for _, tag in OPTIONS.Tags do
		CollectionService:AddTag(model, tag)
	end
	for key, value in OPTIONS.Attributes do
		model:SetAttribute(key, value)
	end
	model:SetAttribute("Quelle", `Blender: {sheet.Name}`)

	if OPTIONS.Parent ~= "" then
		local parent = resolve(OPTIONS.Parent, true)
		if parent then
			model.Parent = parent
		else
			warnLine(`Zielordner "{OPTIONS.Parent}" nicht gefunden; das Modell bleibt, wo es ist.`)
		end
	end

	note(`Modell "{model.Name}" eingebaut: {#sheet.Parts} Teil(e), {triangles} Dreiecke, {points} Andockpunkte.`)
	note(
		`Größe: {string.format("%.1f x %.1f x %.1f", size.X, size.Y, size.Z)} Studs. Hauptteil: {primaryName}. Ort: {model:GetFullName()}`
	)
	return model
end

local sheet = HttpService:JSONDecode(SHEET_JSON)
if type(sheet) ~= "table" or type(sheet.Parts) ~= "table" or #sheet.Parts == 0 then
	return "FEHLER: SHEET_JSON ist leer. Den Inhalt von <Name>.roblox.json dort einfügen."
end

local title = `Modell {sheet.Name} einbauen`
local recording = ChangeHistoryService:TryBeginRecording(title)
local ok, problem = pcall(build, sheet)
if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end
if not ok then
	return `{title}: FEHLER {problem}`
end
return `{title}: fertig, {warnings} Hinweis(e)\n{table.concat(report, "\n")}`
