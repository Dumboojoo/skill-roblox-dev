--[[
	rig_bauen.luau – macht aus einem importierten Blender-Modell eine bewegliche Figur
	(über `execute_luau` im Bearbeitungsmodus ausführen).

	Kein Spielcode. Braucht zwei Dinge aus dem Export von Blender (assets/kreativ/blender):
	  1. Das importierte Modell liegt schon in Studio (hochgeladen und eingefügt, references/modelle-blender.md).
	  2. Der Begleitzettel <Name>.roblox.json: seinen INHALT unten bei SHEET_JSON einfügen.

	Was das Skript tut:
	  - findet jedes Teil am Namen und bringt das Modell auf die richtige Größe (Studs) und Ausrichtung
	    (aufrecht, Vorderseite nach -Z); der Fußpunkt bleibt, wo das Modell lag, oder kommt nach OPTIONS.Position
	  - setzt Farbe und Material je Teil
	  - baut die Gelenke (Motor6D) genau an den Drehpunkten aus Blender; jedes Gelenk hat die Achsen
	    X = rechts, Y = oben, Figur schaut nach -Z (darauf verlässt sich shared/Util/RigMotion)
	  - baut die unsichtbare Mitte (HumanoidRootPart), Humanoid oder AnimationController und die Andockpunkte
	  - gibt einen Bericht zurück: gefundene Teile, Abweichungen, Warnungen

	Danach OPTIONS.Mode = "probe" ausführen und ein Bildschirmfoto machen: Jedes Gelenk ist
	dann ein Stück gedreht. Reißt ein Teil ab oder dreht es sich um die falsche Stelle, stimmt
	der Drehpunkt in Blender nicht. Mit Mode = "probe_aus" steht wieder alles gerade.

	Das Ergebnis ist ein normales Roblox-Rig: Es lässt sich auch im Animations-Editor öffnen.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

-- Inhalt von <Name>.roblox.json (zwischen die Klammern kopieren).
local SHEET_JSON = [==[
{}
]==]

local OPTIONS = {
	Mode = "bauen", -- "bauen" | "probe" | "probe_aus"
	Source = "", -- Pfad des importierten Modells, z. B. "Workspace.Monster". Leer = Model mit dem Namen aus dem Zettel
	Name = "", -- Name der fertigen Figur. Leer = Name aus dem Zettel
	Parent = "", -- Zielordner, z. B. "ServerStorage.Assets.Enemies". Leer = bleibt, wo das Modell lag
	Position = nil :: Vector3?, -- Fußpunkt in der Welt. nil = bleibt, wo das Modell lag
	Turn = 0, -- Blickrichtung in Grad um die Hochachse. 0 = schaut nach -Z (Norden auf der Karte)
	Humanoid = true, -- true: Figur mit Humanoid (läuft, hat Leben). false: Gerät (Tür, Truhe, Geschütz), fest verankert
	Animated = true, -- true: Tag "AnimatedRig" (bewegt sich im Spiel von selbst, siehe RigAnimationController)
	Gait = "", -- "Zweibeiner" | "Vierbeiner" | "Schweben". Leer = wird aus den Teilen erraten
	Colors = true, -- Farben aus dem Zettel setzen (false, wenn eine Textur die Farbe liefert)
	Material = Enum.Material.SmoothPlastic,
	Texture = "", -- "rbxassetid://…": gemeinsame Textur für alle Teile (aus rbx_texture.bake_color)
	ProbeAngle = 35, -- Grad, um die jedes Gelenk bei Mode = "probe" gedreht wird
}

local ROOT_NAME = "HumanoidRootPart"
local REST_ATTRIBUTE = "RestC0"

------------------------------------------------------------------------------
-- Hilfen
------------------------------------------------------------------------------

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

-- "ServerStorage.Assets.Enemies" -> Instanz. Fehlende Ordner werden angelegt, wenn create = true.
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

-- Alle 24 achsparallelen Drehungen: Der Import kann das Modell gedreht oder liegend abliefern.
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

-- Ausdehnung eines gedrehten Kastens entlang der Welt-Achsen.
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

------------------------------------------------------------------------------
-- Gelenk-Probe
------------------------------------------------------------------------------

local function findRig(sheetName: string): Model?
	local name = if OPTIONS.Name ~= "" then OPTIONS.Name else sheetName
	if OPTIONS.Parent ~= "" then
		local parent = resolve(OPTIONS.Parent, false)
		local found = if parent then parent:FindFirstChild(name) else nil
		if found and found:IsA("Model") then
			return found
		end
	end
	local services: { Instance } =
		{ game:GetService("Workspace"), game:GetService("ServerStorage"), game:GetService("ReplicatedStorage") }
	for _, service in services do
		for _, descendant in service:GetDescendants() do
			if descendant:IsA("Model") and descendant.Name == name and descendant:FindFirstChild(ROOT_NAME) then
				return descendant
			end
		end
	end
	return nil
end

local function probe(rig: Model, enable: boolean): string
	local turned = 0
	for _, descendant in rig:GetDescendants() do
		if not descendant:IsA("Motor6D") or not descendant.Part0 or descendant.Part0.Name == ROOT_NAME then
			continue
		end
		local rest = descendant:GetAttribute(REST_ATTRIBUTE)
		if enable then
			if typeof(rest) ~= "CFrame" then
				descendant:SetAttribute(REST_ATTRIBUTE, descendant.C0)
				rest = descendant.C0
			end
			local name = descendant.Name
			local sign = if string.find(name, "Right") or string.find(name, "Back") then -1 else 1
			if string.find(name, "Lower") then
				sign = if string.find(name, "Leg") then -1 else 1 -- Knie nach hinten, Ellbogen nach vorn
			end
			descendant.C0 = (rest :: CFrame) * CFrame.Angles(math.rad(OPTIONS.ProbeAngle) * sign, 0, 0)
			turned += 1
		elseif typeof(rest) == "CFrame" then
			descendant.C0 = rest
			descendant:SetAttribute(REST_ATTRIBUTE, nil)
			turned += 1
		end
	end
	return if enable
		then `Probe an: {turned} Gelenke gedreht. Bildschirmfoto machen, danach Mode = "probe_aus".`
		else `Probe aus: {turned} Gelenke stehen wieder gerade.`
end

------------------------------------------------------------------------------
-- Bauen
------------------------------------------------------------------------------

local function build(sheet: any): Model
	-- 1. Importiertes Modell und seine Teile finden
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
	table.insert(candidates, 1, container) -- ein Modell aus nur einem Teil ist selbst das Teil

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
				.. `Vorhanden sind: {table.concat(present, ", ")}.\n`
				.. "Passt der Zettel zu diesem Modell? Wurden Teile beim Import zusammengelegt?",
			0
		)
	end

	-- 2. Sauberes Model: alle Teile flach hinein
	local rig = Instance.new("Model")
	rig.Name = if OPTIONS.Name ~= "" then OPTIONS.Name else sheet.Name
	rig.Parent = container.Parent
	for _, part in parts do
		for _, joint in part:GetChildren() do
			if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
				joint:Destroy() -- alte Verbindungen aus dem Import stören die neuen Gelenke
			end
		end
		part.Anchored = true
		part.Parent = rig
	end
	-- Die leere Hülle des Imports entfernen (nur wenn wirklich nichts Sichtbares mehr darin liegt).
	if container.Parent ~= rig and not container:IsA("BasePart") then
		local leftover = false
		for _, descendant in container:GetDescendants() do
			if descendant:IsA("BasePart") then
				leftover = true
				break
			end
		end
		if leftover then
			warnLine(
				`In "{container.Name}" liegen noch Teile, die nicht im Zettel stehen. Die Hülle bleibt deshalb bestehen.`
			)
		else
			container:Destroy()
		end
	end

	-- 3. Größe: Abstände der Teile untereinander mit dem Zettel vergleichen
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
		-- Nur ein Teil (oder alle an derselben Stelle): Größe des Teils vergleichen
		local entry = sheet.Parts[1]
		local have = sortedSize(parts[entry.Name].Size)
		local want = sortedSize(vector(entry.Size))
		if have[3] > 0.0001 then
			scale = want[3] / have[3]
		end
	end
	if math.abs(scale - 1) > 0.002 then
		rig:ScaleTo(rig:GetScale() * scale)
		note(`Größe angepasst: Faktor {string.format("%.4f", scale)}`)
	end

	-- 4. Ausrichtung: die Drehung suchen, bei der alle Teile auf ihren Plätzen aus dem Zettel liegen
	actualCenter, expectedCenter = centroids()
	local best: CFrame = CFrame.identity
	local bestError = math.huge
	local bestOffset = 0
	for _, rotation in axisRotations() do
		local offsets, sizes = 0, 0
		for _, entry in sheet.Parts do
			local part = parts[entry.Name]
			local predicted = actualCenter + rotation * (vector(entry.Center) - expectedCenter)
			offsets += (predicted - part.Position).Magnitude
			-- Auch die Form muss passen: Das entscheidet, wenn die Teile auf einer Linie liegen.
			sizes += (worldExtents(rotation, vector(entry.Size)) - worldExtents(part.CFrame, part.Size)).Magnitude
		end
		if offsets + sizes < bestError - 0.001 then
			best, bestError, bestOffset = rotation, offsets + sizes, offsets
		end
	end
	local height = sheet.SizeStuds[2]
	local average = bestOffset / #sheet.Parts
	if average > math.max(0.05 * height, 0.1) then
		warnLine(
			`Die Teile liegen im Schnitt {string.format("%.2f", average)} Studs neben ihrem Platz laut Zettel. `
				.. "Modell und Zettel passen nicht zusammen (anderer Export? gespiegelt?). Gelenke prüfen!"
		)
	end

	-- current: Zettel-Koordinaten -> Welt, so wie das Modell jetzt liegt
	local current = CFrame.new(actualCenter) * best * CFrame.new(-expectedCenter)
	local foot = OPTIONS.Position or current.Position
	local target = CFrame.new(foot) * CFrame.Angles(0, math.rad(OPTIONS.Turn), 0) -- aufrecht; Turn 0 = schaut nach -Z
	local move = target * current:Inverse()
	for _, part in parts do
		part.CFrame = move * part.CFrame
	end

	-- 5. Teile einstellen und nachmessen
	for _, entry in sheet.Parts do
		local part = parts[entry.Name]
		local offset = (part.Position - target * vector(entry.Center)).Magnitude
		if offset > math.max(0.04 * height, 0.08) then
			warnLine(`{entry.Name}: liegt {string.format("%.2f", offset)} Studs neben dem erwarteten Platz.`)
		end
		local have, want = sortedSize(part.Size), sortedSize(vector(entry.Size))
		for index = 1, 3 do
			if math.abs(have[index] - want[index]) > math.max(0.1 * want[index], 0.08) then
				warnLine(
					`{entry.Name}: Größe {string.format("%.2f x %.2f x %.2f", have[1], have[2], have[3])} `
						.. `statt {string.format("%.2f x %.2f x %.2f", want[1], want[2], want[3])} (sortiert).`
				)
				break
			end
		end
		if OPTIONS.Colors then
			part.Color = Color3.fromRGB(entry.Color[1], entry.Color[2], entry.Color[3])
		end
		part.Material = OPTIONS.Material
		if OPTIONS.Texture ~= "" and part:IsA("MeshPart") then
			part.TextureID = OPTIONS.Texture
		end
		part.CanCollide = false -- die Kollision übernimmt die unsichtbare Mitte
		part.Massless = true
		part.CanTouch = false
	end

	-- 6. Unsichtbare Mitte: ein Kasten vom Boden bis zum Scheitel
	local size = vector(sheet.SizeStuds)
	local root = Instance.new("Part")
	root.Name = ROOT_NAME
	root.Size = Vector3.new(math.max(size.X * 0.6, 1), math.max(size.Y, 1), math.max(size.Z * 0.6, 1))
	root.CFrame = target * CFrame.new(0, root.Size.Y / 2, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = rig
	rig.PrimaryPart = root

	-- 7. Gelenke. Jedes Gelenk bekommt die Achsen der Figur (X rechts, Y oben, -Z vorn).
	local function connect(name: string, from: BasePart, to: BasePart, jointPosition: Vector3)
		local world = target * CFrame.new(jointPosition)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = from
		motor.Part1 = to
		motor.C0 = from.CFrame:ToObjectSpace(world)
		motor.C1 = to.CFrame:ToObjectSpace(world)
		motor.Parent = to
	end

	local joints = 0
	for _, entry in sheet.Parts do
		local part = parts[entry.Name]
		if entry.Parent and parts[entry.Parent] then
			connect(entry.Name, parts[entry.Parent], part, vector(entry.Joint))
			joints += 1
		elseif entry.Name == sheet.Root or sheet.Root == nil then
			connect(if entry.Name == sheet.Root then "Root" else entry.Name, root, part, vector(entry.Joint))
			joints += 1
		else
			warnLine(`{entry.Name}: hat kein Eltern-Teil im Zettel und hängt deshalb direkt an der Mitte.`)
			connect(entry.Name, root, part, vector(entry.Joint))
			joints += 1
		end
	end

	-- 8. Andockpunkte
	local points = 0
	for _, entry in sheet.Attachments or {} do
		local part = if entry.Part then parts[entry.Part] else nil
		if part then
			local attachment = Instance.new("Attachment")
			attachment.Name = entry.Name
			attachment.Parent = part
			attachment.WorldCFrame = target * CFrame.new(vector(entry.Position))
			points += 1
		else
			warnLine(`Andockpunkt {entry.Name}: Teil "{tostring(entry.Part)}" nicht gefunden.`)
		end
	end

	-- 9. Steuerung: Humanoid (läuft, hat Leben) oder AnimationController (Gerät)
	if OPTIONS.Humanoid then
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.HipHeight = 0.05 -- die Mitte reicht bis zum Boden
		humanoid.RequiresNeck = false
		humanoid.Parent = rig
		Instance.new("Animator").Parent = humanoid
	else
		local controller = Instance.new("AnimationController")
		controller.Parent = rig
		Instance.new("Animator").Parent = controller
	end

	-- Nur die Mitte bleibt verankert, solange im Bearbeitungsmodus gebaut wird. Figuren mit
	-- Humanoid werden für das Spiel gelöst (sonst könnten sie nicht laufen); Geräte bleiben fest.
	for _, part in parts do
		part.Anchored = false
	end
	root.Anchored = not OPTIONS.Humanoid

	if OPTIONS.Animated then
		CollectionService:AddTag(rig, "AnimatedRig")
		if OPTIONS.Gait ~= "" then
			rig:SetAttribute("Gait", OPTIONS.Gait)
		end
	end
	rig:SetAttribute("Quelle", `Blender: {sheet.Name}`)

	if OPTIONS.Parent ~= "" then
		local parent = resolve(OPTIONS.Parent, true)
		if parent then
			rig.Parent = parent
		else
			warnLine(`Zielordner "{OPTIONS.Parent}" nicht gefunden; die Figur bleibt, wo sie ist.`)
		end
	end

	note(`Figur "{rig.Name}" gebaut: {#sheet.Parts} Teile, {joints} Gelenke, {points} Andockpunkte.`)
	note(`Größe: {string.format("%.1f x %.1f x %.1f", size.X, size.Y, size.Z)} Studs. Ort: {rig:GetFullName()}`)
	if OPTIONS.Humanoid then
		note("Mit Humanoid, nicht verankert: als Vorlage gedacht (z. B. ServerStorage.Assets.Enemies.<Schlüssel>).")
	end
	return rig
end

------------------------------------------------------------------------------
-- Ablauf
------------------------------------------------------------------------------

local sheet = HttpService:JSONDecode(SHEET_JSON)
if type(sheet) ~= "table" or type(sheet.Parts) ~= "table" or #sheet.Parts == 0 then
	return "FEHLER: SHEET_JSON ist leer. Den Inhalt von <Name>.roblox.json dort einfügen."
end

local title = `Figur {sheet.Name} ({OPTIONS.Mode})`
local recording = ChangeHistoryService:TryBeginRecording(title)
local ok, result = pcall(function(): string
	if OPTIONS.Mode == "bauen" then
		build(sheet)
		return table.concat(report, "\n")
	end
	local rig = findRig(sheet.Name)
	if not rig then
		error('Fertige Figur nicht gefunden. Erst mit Mode = "bauen" bauen (und Name/Parent wie dort angeben).', 0)
	end
	return probe(rig :: Model, OPTIONS.Mode == "probe")
end)
if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end
if not ok then
	return `{title}: FEHLER {result}`
end
return `{title}: fertig, {warnings} Hinweis(e)\n{result}`
