--!strict
--[[
	EffectController – spielt die Effekte aus Config/Effects ab (Partikel, einmaliger Ausstoß).

	Client:
	  EffectController:Play("Hit", position)                -- an einer Stelle in der Welt
	  EffectController:Play("Shot", position, richtung)     -- mit Richtung (z. B. Lauf der Waffe, Wand-Normale)
	  EffectController:Play("Explosion", position, nil, 1.5) -- 1.5-mal so groß
	  EffectController:PlayOn("Heal", teilOderAttachment)   -- haftet an einem Teil und bewegt sich mit

	Server (für Effekte, die alle in der Nähe sehen sollen):
	  Net.FireNear("Effect.Play", position, 150, "Explosion", position)
	  Net.FireNear("Effect.Play", position, 150, "Shot", position, richtung, 1)

	Effekte laufen nur auf dem Client: Der Server rechnet nichts, und jeder Client lässt weg,
	was zu weit entfernt ist. Ein unbekannter Name bleibt unsichtbar (in Studio mit Warnung).

	Dauerhafte Effekte (Fackel, Aura, Spur hinter einem Geschoss) gehören nicht hierher:
	Die baut man in Studio als ParticleEmitter, Beam oder Trail direkt am Teil (references/effekte.md).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AssetIds = require(Shared.Config.AssetIds)
local Effects = require(Shared.Config.Effects)
local Net = require(Shared.Net)

local EffectController = {
	Priority = 20, -- früh, damit andere Controller schon in Init Effekte spielen können
}

local active = 0
local warned: { [string]: boolean } = {}

local FLIPBOOK_LAYOUTS: { [number]: Enum.ParticleFlipbookLayout } = {
	[2] = Enum.ParticleFlipbookLayout.Grid2x2,
	[4] = Enum.ParticleFlipbookLayout.Grid4x4,
	[8] = Enum.ParticleFlipbookLayout.Grid8x8,
}

local function color(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function range(values: { number }?, default: number): NumberRange
	if not values then
		return NumberRange.new(default)
	end
	local low = values[1]
	local high = values[2] or low
	return NumberRange.new(math.min(low, high), math.max(low, high))
end

-- Schlüssel aus AssetIds.Effects oder direkt eine Id. "" = kein eigenes Bild.
local function textureFor(key: string): string
	local id = AssetIds.Effects[key]
	if id ~= nil then
		return id
	end
	if string.sub(key, 1, 3) == "rbx" then
		return key
	end
	return ""
end

local function buildEmitter(layer: Effects.Layer, scale: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0 -- nur einmaliger Ausstoß über Emit
	emitter.Enabled = false

	local texture = textureFor(layer.Texture)
	if texture ~= "" then
		emitter.Texture = texture
		local layout = if layer.Flipbook then FLIPBOOK_LAYOUTS[layer.Flipbook] else nil
		if layout then
			emitter.FlipbookLayout = layout
			emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
	end
	-- Ohne eigenes Bild bleibt das Standard-Partikel von Roblox: sichtbar, nur schlichter.

	emitter.Lifetime = range(layer.Lifetime, 0.5)
	local sizeStart = layer.Size[1] * scale
	local sizeEnd = (layer.Size[2] or layer.Size[1]) * scale
	emitter.Size = NumberSequence.new(sizeStart, sizeEnd)

	local speed = range(layer.Speed, 0)
	emitter.Speed = NumberRange.new(speed.Min * scale, speed.Max * scale)
	local spread = layer.Spread or 180
	emitter.SpreadAngle = Vector2.new(spread, spread)

	local startColor = color(layer.Color)
	emitter.Color = ColorSequence.new(startColor, if layer.ColorEnd then color(layer.ColorEnd) else startColor)
	local fade: { number } = layer.Fade or { 0, 1 }
	emitter.Transparency = NumberSequence.new(fade[1], fade[2] or fade[1])
	emitter.LightEmission = layer.Glow or 1
	emitter.LightInfluence = 0 -- Effekte sollen auch im Dunkeln ihre Farbe behalten

	emitter.Acceleration = Vector3.new(0, -(layer.Gravity or 0) * scale, 0)
	emitter.Drag = layer.Drag or 0
	emitter.Rotation = range(layer.Rotation, 0)
	emitter.RotSpeed = range(layer.Spin, 0)
	if layer.Stretch then
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	emitter.ZOffset = (layer.Front or 0) * 0.05 -- kleine Schritte zur Kamera hin: legt die Reihenfolge fest
	return emitter
end

local function longestLifetime(effect: Effects.Effect): number
	local longest = 0
	for _, layer in effect.Layers do
		longest = math.max(longest, layer.Lifetime[1], layer.Lifetime[2] or 0)
	end
	return longest
end

local function lookup(name: string): Effects.Effect?
	local effect = Effects.List[name]
	if not effect and name ~= "" and RunService:IsStudio() and not warned[name] then
		warned[name] = true
		warn(`[Effekt] "{name}" steht nicht in Config/Effects.`)
	end
	return effect
end

-- Erzeugt die Partikel an `holder` und räumt danach auf.
local function emit(effect: Effects.Effect, holder: Attachment, scale: number, destroyHolder: boolean)
	active += 1
	local emitters: { ParticleEmitter } = {}
	for _, layer in effect.Layers do
		local emitter = buildEmitter(layer, scale)
		emitter.Parent = holder
		table.insert(emitters, emitter)
		emitter:Emit(layer.Count)
	end
	task.delay(longestLifetime(effect) + 0.1, function()
		active -= 1
		if destroyHolder then
			holder:Destroy()
		else
			for _, emitter in emitters do
				emitter:Destroy()
			end
		end
	end)
end

local function tooFar(position: Vector3): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude > Effects.MaxDistance
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

-- `direction`: wohin der Effekt zeigt (für Schichten mit Spread < 180). Standard: nach oben.
function EffectController:Play(name: string, position: Vector3, direction: Vector3?, scale: number?)
	local effect = lookup(name)
	if not effect or active >= Effects.MaxActive or tooFar(position) then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = "Effect_" .. name
	if direction and direction.Magnitude > 0.001 then
		-- Partikel fliegen entlang der Y-Achse des Attachments: diese auf die Richtung drehen.
		local unit = direction.Unit
		local helper = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local right = unit:Cross(helper).Unit
		holder.CFrame = CFrame.fromMatrix(position, right, unit)
	else
		holder.CFrame = CFrame.new(position)
	end
	-- Terrain dient nur als Halter, der immer da ist (dort sind Welt- und Ortskoordinaten gleich).
	holder.Parent = Workspace.Terrain
	emit(effect, holder, scale or 1, true)
end

-- Haftet an einem Teil oder Attachment und bewegt sich mit.
function EffectController:PlayOn(name: string, target: BasePart | Attachment, scale: number?)
	local effect = lookup(name)
	if not effect or active >= Effects.MaxActive then
		return
	end
	local position = if target:IsA("Attachment") then target.WorldPosition else target.Position
	if tooFar(position) then
		return
	end
	if target:IsA("Attachment") then
		emit(effect, target, scale or 1, false)
	else
		local holder = Instance.new("Attachment")
		holder.Name = "Effect_" .. name
		holder.Parent = target
		emit(effect, holder, scale or 1, true)
	end
end

function EffectController:Init()
	Net.Listen("Effect.Play", function(name: any, position: any, direction: any, scale: any)
		if type(name) ~= "string" or typeof(position) ~= "Vector3" then
			return
		end
		EffectController:Play(
			name,
			position,
			if typeof(direction) == "Vector3" then direction else nil,
			if type(scale) == "number" then scale else nil
		)
	end)
end

return EffectController
