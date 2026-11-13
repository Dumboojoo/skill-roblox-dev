--[[
	effekt_vorschau.luau – zeigt einen Effekt aus Config/Effects im Bearbeitungsmodus,
	damit man ihn per Bildschirmfoto beurteilen kann (über `execute_luau` ausführen).

	Kein Spielcode. Einmalige Effekte (ein Treffer dauert 0,2 Sekunden) sind auf einem
	Bildschirmfoto nie zu sehen. Deshalb stößt die Vorschau die Partikel DAUERND aus:
	Man sieht alle Phasen des Effekts gleichzeitig. Im Spiel wirkt er etwas ruhiger.

	So geht es:
	  1. Bei LAYERS die Schichten des Effekts aus src/shared/Config/Effects.luau einfügen.
	  2. Bei TEXTURES die Nummern aus src/shared/Config/AssetIds.luau eintragen
	     (leer = Standard-Partikel von Roblox, genau wie im Spiel).
	  3. Ausführen, `screen_capture`, beurteilen, Zahlen in Effects.luau ändern, wiederholen.
	  4. Am Ende mit MODE = "aus" aufräumen.

	Beurteilen: Ist die Form erkennbar? Stimmt die Größe neben der Vergleichsfigur (5 Studs)?
	Ist es zu grell oder zu blass? Bleibt es im Dunkeln und im Hellen sichtbar?
]]

local Workspace = game:GetService("Workspace")

local MODE = "an" -- "an" | "aus"
local SCALE = 1 -- wie im Spiel der vierte Wert von EffectController:Play
local DARK_BACKDROP = true -- dunkle Wand dahinter (leuchtende Effekte sieht man so am besten)

-- Schlüssel wie in Config/AssetIds (Effects) -> "rbxassetid://…"
local TEXTURES: { [string]: string } = {
	Burst = "",
	Spark = "",
}

-- Schichten wie in Config/Effects (List.<Name>.Layers), unverändert hineinkopieren.
local LAYERS: { { [string]: any } } = {
	{
		Texture = "Burst",
		Flipbook = 4,
		Count = 1,
		Lifetime = { 0.22, 0.22 },
		Size = { 3.5, 4.5 },
		Color = { 255, 236, 170 },
	},
	{
		Texture = "Spark",
		Count = 10,
		Lifetime = { 0.2, 0.4 },
		Size = { 0.5, 0 },
		Speed = { 14, 26 },
		Color = { 255, 190, 90 },
		Stretch = true,
	},
}

local FOLDER_NAME = "EffektVorschau"
local FLIPBOOK_LAYOUTS: { [number]: Enum.ParticleFlipbookLayout } = {
	[2] = Enum.ParticleFlipbookLayout.Grid2x2,
	[4] = Enum.ParticleFlipbookLayout.Grid4x4,
	[8] = Enum.ParticleFlipbookLayout.Grid8x8,
}

local old = Workspace:FindFirstChild(FOLDER_NAME)
if old then
	old:Destroy()
end
if MODE ~= "an" then
	return "Effekt-Vorschau entfernt."
end

local function range(values: { number }?, default: number): NumberRange
	if not values then
		return NumberRange.new(default)
	end
	local low = values[1]
	local high = values[2] or low
	return NumberRange.new(math.min(low, high), math.max(low, high))
end

local function color(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local camera = Workspace.CurrentCamera
local origin = if camera then camera.CFrame * CFrame.new(0, 0, -22) else CFrame.new(0, 10, 0)
local flat = CFrame.new(origin.Position) -- aufrecht, an der Stelle vor der Kamera
local facing = if camera
	then CFrame.lookAt(flat.Position, Vector3.new(camera.CFrame.Position.X, flat.Position.Y, camera.CFrame.Position.Z))
	else flat

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = Workspace

local holder = Instance.new("Part")
holder.Name = "Halter"
holder.Size = Vector3.new(0.2, 0.2, 0.2)
holder.CFrame = flat
holder.Anchored = true
holder.CanCollide = false
holder.Transparency = 1
holder.Parent = folder

-- Vergleichsfigur: so groß wie ein Spieler (2 x 5 x 1 Studs)
local figure = Instance.new("Part")
figure.Name = "Vergleich_5_Studs"
figure.Size = Vector3.new(2, 5, 1)
figure.CFrame = facing * CFrame.new(5, 0, 0)
figure.Anchored = true
figure.CanCollide = false
figure.Color = Color3.fromRGB(120, 130, 150)
figure.Material = Enum.Material.SmoothPlastic
figure.Parent = folder

if DARK_BACKDROP then
	local wall = Instance.new("Part")
	wall.Name = "Hintergrund"
	wall.Size = Vector3.new(28, 18, 0.5)
	wall.CFrame = facing * CFrame.new(0, 0, 6) -- hinter dem Effekt, von der Kamera aus gesehen
	wall.Anchored = true
	wall.CanCollide = false
	wall.Color = Color3.fromRGB(18, 20, 28)
	wall.Material = Enum.Material.SmoothPlastic
	wall.Parent = folder
end

local attachment = Instance.new("Attachment")
attachment.Parent = holder

local missing: { string } = {}
for index, layer in LAYERS do
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = `Schicht{index}`

	local key = layer.Texture
	local texture = TEXTURES[key] or (if string.sub(key, 1, 3) == "rbx" then key else "")
	if texture ~= "" then
		emitter.Texture = texture
		local layout = if layer.Flipbook then FLIPBOOK_LAYOUTS[layer.Flipbook] else nil
		if layout then
			emitter.FlipbookLayout = layout
			emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	else
		table.insert(missing, key)
	end

	local lifetime = range(layer.Lifetime, 0.5)
	emitter.Lifetime = lifetime
	emitter.Size = NumberSequence.new(layer.Size[1] * SCALE, (layer.Size[2] or layer.Size[1]) * SCALE)
	local speed = range(layer.Speed, 0)
	emitter.Speed = NumberRange.new(speed.Min * SCALE, speed.Max * SCALE)
	local spread = layer.Spread or 180
	emitter.SpreadAngle = Vector2.new(spread, spread)
	local startColor = color(layer.Color)
	emitter.Color = ColorSequence.new(startColor, if layer.ColorEnd then color(layer.ColorEnd) else startColor)
	local fade = layer.Fade or { 0, 1 }
	emitter.Transparency = NumberSequence.new(fade[1], fade[2] or fade[1])
	emitter.LightEmission = layer.Glow or 1
	emitter.LightInfluence = 0
	emitter.Acceleration = Vector3.new(0, -(layer.Gravity or 0) * SCALE, 0)
	emitter.Drag = layer.Drag or 0
	emitter.Rotation = range(layer.Rotation, 0)
	emitter.RotSpeed = range(layer.Spin, 0)
	if layer.Stretch then
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	emitter.ZOffset = (layer.Front or 0) * 0.05 -- kleine Schritte zur Kamera hin: legt die Reihenfolge fest

	-- Dauernd so viele Partikel, wie ein einzelner Ausstoß im Schnitt gleichzeitig zeigt.
	local average = (lifetime.Min + lifetime.Max) / 2
	emitter.Rate = math.clamp(layer.Count / math.max(average, 0.05), 2, 200)
	emitter.Enabled = true
	emitter.Parent = attachment
end

local lines = {
	`Effekt-Vorschau läuft: {#LAYERS} Schicht(en), 22 Studs vor der Kamera. Jetzt screen_capture.`,
	"Daneben steht eine Vergleichsfigur in Spielergröße (5 Studs hoch).",
}
if #missing > 0 then
	table.insert(lines, `Ohne eigenes Bild (Standard-Partikel): {table.concat(missing, ", ")}`)
end
table.insert(lines, 'Aufräumen: MODE = "aus" und noch einmal ausführen.')
return table.concat(lines, "\n")
