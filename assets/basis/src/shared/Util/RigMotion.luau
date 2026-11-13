--!strict
--[[
	RigMotion – rechnet aus, wie sich die Körperteile einer Figur bewegen (ohne Animationsdatei).

	Reine Mathematik ohne Roblox-Dienste, deshalb mit `lune run tests/run.luau` prüfbar.
	Der RigAnimationController wendet das Ergebnis auf die Gelenke (Motor6D) an.

	  local kinds = RigMotion.Classify({ "Torso", "Head", "LeftUpperArm", "Tail1" }, "Torso")
	  local pose = RigMotion.Sample(kinds, {
	      Gait = "Zweibeiner", Phase = phase, Move = 1, Clock = os.clock(),
	      Strength = 1, Height = 7, JawOpen = 0,
	  })
	  -- pose["LeftUpperArm"] = { drehungX, drehungY, drehungZ, hebung }

	Erkannt werden die Teile am NAMEN (Groß-/Kleinschreibung egal):
	  Rumpf       das Wurzel-Teil (meist "Torso")
	  Kopf        ...Head...                    Kiefer   ...Jaw...
	  Arm         ...Arm... / ...Hand...        Bein     ...Leg... / ...Foot...
	  Schwanz     ...Tail... (Tail1, Tail2, …)  Flügel   ...Wing...
	  Seite       ...Left... / ...Right...      vorn/hinten bei Vierbeinern: ...Front... / ...Back...
	  unteres Glied (Knie, Ellbogen): ...Lower... / ...Hand... / ...Foot...
	Teile mit anderen Namen (Augen, Hörner, Panzerplatten) bleiben einfach starr an ihrem Eltern-Teil.

	Achsen der Gelenke (so baut sie assets/weltbau/rig_bauen.luau):
	  X zeigt nach rechts, Y nach oben, die Figur schaut nach -Z.
	  Drehung um X: positiv schwingt ein hängendes Glied nach VORN.
	  Drehung um Y: positiv dreht nach links (von oben gesehen gegen den Uhrzeigersinn).
	  Drehung um Z: positiv hebt, was nach rechts absteht (rechter Flügel hoch).
]]

export type Kind = {
	Role: string, -- "Body" | "Head" | "Jaw" | "Arm" | "Leg" | "Tail" | "Wing"
	Side: number, -- -1 links, 1 rechts, 0 Mitte
	Front: boolean, -- Vorderbein (bei Vierbeinern)
	Back: boolean, -- Hinterbein
	Lower: boolean, -- Unterarm, Unterschenkel, Hand, Fuß
	Index: number, -- Nummer am Namensende (Tail2 -> 2), sonst 1
}

export type Input = {
	Gait: string, -- "Zweibeiner" | "Vierbeiner" | "Schweben"
	Phase: number, -- Schritt-Takt im Bogenmaß; wächst mit der zurückgelegten Strecke
	Move: number, -- 0 = steht, 1 = läuft voll
	Clock: number, -- laufende Zeit in Sekunden (Atmen, Schwanz, Flügel)
	Strength: number, -- 1 = normal, größer = ausladender
	Height: number, -- Höhe der Figur in Studs (für das Auf und Ab des Rumpfs)
	JawOpen: number, -- 0 = Maul zu, 1 = weit offen
}

export type Pose = { [string]: { number } } -- Teilname -> { rx, ry, rz, hebung in Studs }

local RigMotion = {}

RigMotion.Gaits = { "Zweibeiner", "Vierbeiner", "Schweben" }

-- Wie weit die Glieder ausschlagen (Bogenmaß). Hier lässt sich der Charakter aller Figuren ändern.
RigMotion.Tuning = {
	LegSwing = 0.62,
	KneeBend = 0.85,
	ArmSwing = 0.5,
	ElbowBend = 0.45,
	QuadLegSwing = 0.5,
	BodyBob = 0.035, -- Anteil der Körperhöhe
	BodyLean = 0.1,
	BodyTwist = 0.07,
	Breath = 0.012, -- Anteil der Körperhöhe
	HeadIdle = 0.06,
	TailWag = 0.3,
	TailWalk = 0.12,
	JawMax = 0.6,
	JawIdle = 0.03,
	WingFlap = 0.7,
	WingIdle = 0.12,
	HoverBob = 0.05, -- Anteil der Körperhöhe
	HoverDangle = 0.16,
}

local function has(text: string, word: string): boolean
	return string.find(text, word, 1, true) ~= nil
end

-- Ordnet jedem Teilnamen seine Rolle zu. `rootName` ist das Wurzel-Teil (der Rumpf).
function RigMotion.Classify(names: { string }, rootName: string?): { [string]: Kind }
	local result: { [string]: Kind } = {}
	for _, name in names do
		local lower = string.lower(name)
		local role: string? = nil
		if name == rootName then
			role = "Body"
		elseif has(lower, "jaw") then
			role = "Jaw"
		elseif has(lower, "tail") then
			role = "Tail"
		elseif has(lower, "wing") then
			role = "Wing"
		elseif has(lower, "arm") or has(lower, "hand") then
			role = "Arm"
		elseif has(lower, "leg") or has(lower, "foot") then
			role = "Leg"
		elseif has(lower, "head") or has(lower, "neck") then
			role = "Head"
		end
		if role then
			local side = if has(lower, "left") then -1 elseif has(lower, "right") then 1 else 0
			result[name] = {
				Role = role,
				Side = side,
				Front = has(lower, "front"),
				Back = has(lower, "back") or has(lower, "hind") or has(lower, "rear"),
				Lower = has(lower, "lower") or has(lower, "hand") or has(lower, "foot"),
				Index = tonumber(string.match(name, "(%d+)$")) or 1,
			}
		end
	end
	return result
end

-- Sucht die passende Gangart aus den Teilen: Vorder- und Hinterbeine = Vierbeiner,
-- Beine = Zweibeiner, keine Beine = Schweben.
function RigMotion.GuessGait(kinds: { [string]: Kind }): string
	local legs, frontOrBack = 0, 0
	for _, kind in kinds do
		if kind.Role == "Leg" and not kind.Lower then
			legs += 1
			if kind.Front or kind.Back then
				frontOrBack += 1
			end
		end
	end
	if legs >= 4 and frontOrBack >= 2 then
		return "Vierbeiner"
	elseif legs >= 2 then
		return "Zweibeiner"
	end
	return "Schweben"
end

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

-- Der Schritt-Takt eines Beins: Gegenüberliegende Beine laufen gegengleich.
local function legPhase(kind: Kind, gait: string, phase: number): number
	local offset = if kind.Side > 0 then math.pi else 0
	if gait == "Vierbeiner" and kind.Back then
		offset += math.pi -- Trab: vorn links und hinten rechts gemeinsam
	end
	return phase + offset
end

function RigMotion.Sample(kinds: { [string]: Kind }, input: Input): Pose
	local tuning = RigMotion.Tuning
	local strength = math.max(input.Strength, 0)
	local move = clamp01(input.Move)
	local phase = input.Phase
	local clock = input.Clock
	local height = math.max(input.Height, 0.1)
	local hover = input.Gait == "Schweben"
	local quad = input.Gait == "Vierbeiner"

	local pose: Pose = {}
	for name, kind in kinds do
		local rx, ry, rz, lift = 0, 0, 0, 0

		if kind.Role == "Body" then
			local breath = math.sin(clock * 1.7) * tuning.Breath * height
			if hover then
				lift = math.sin(clock * 2.1) * tuning.HoverBob * height * strength + breath
				rx = -tuning.BodyLean * 1.6 * move * strength -- neigt sich in Flugrichtung
				rz = math.sin(clock * 1.3) * 0.04 * strength
			else
				-- Zwei Auf-und-Ab je Schrittzyklus (einmal je Bein).
				lift = math.abs(math.sin(phase)) * tuning.BodyBob * height * move * strength + breath
				rx = -tuning.BodyLean * move * strength
				ry = math.sin(phase) * tuning.BodyTwist * move * strength * (if quad then 0.5 else 1)
			end
		elseif kind.Role == "Head" then
			-- Gleicht die Drehung des Rumpfs aus und schaut im Stand langsam umher.
			ry = -math.sin(phase) * tuning.BodyTwist * move * strength
				+ math.sin(clock * 0.6) * tuning.HeadIdle * (1 - move) * strength
			rx = math.sin(clock * 0.9 + 1) * tuning.HeadIdle * 0.5 * strength + tuning.BodyLean * 0.6 * move * strength
		elseif kind.Role == "Jaw" then
			local open = clamp01(input.JawOpen)
			rx = -(open * tuning.JawMax + (0.5 + 0.5 * math.sin(clock * 1.7)) * tuning.JawIdle * (1 - open))
		elseif kind.Role == "Leg" then
			local own = legPhase(kind, input.Gait, phase)
			if hover then
				-- Beine baumeln leicht nach hinten.
				local dangle = math.sin(clock * 1.6 + kind.Side) * tuning.HoverDangle * 0.5
				rx = (if kind.Lower then -0.25 else -0.15 - 0.25 * move) * strength + dangle * strength
			elseif kind.Lower then
				-- Knie beugt nur nach hinten, und zwar während das Bein nach vorn durchschwingt.
				rx = -math.max(0, math.cos(own)) * tuning.KneeBend * move * strength
			else
				local swing = if quad then tuning.QuadLegSwing else tuning.LegSwing
				rx = math.sin(own) * swing * move * strength
			end
		elseif kind.Role == "Arm" then
			-- Arme schwingen gegengleich zum Bein derselben Seite.
			local own = phase + (if kind.Side > 0 then 0 else math.pi)
			if hover then
				rx = math.sin(clock * 1.4 + kind.Side * 0.8) * tuning.HoverDangle * strength
				rz = kind.Side * 0.12 * strength
			elseif kind.Lower then
				rx = (0.25 + 0.75 * math.max(0, math.sin(own))) * tuning.ElbowBend * move * strength
			else
				rx = math.sin(own) * tuning.ArmSwing * move * strength
				-- Im Stand atmen die Arme leicht mit.
				rz = kind.Side * math.sin(clock * 1.7) * 0.025 * (1 - move) * strength
			end
		elseif kind.Role == "Tail" then
			-- Eine Welle läuft den Schwanz entlang: jedes Glied etwas später als das vorige.
			local delay = (kind.Index - 1) * 0.7
			ry = math.sin(clock * 2.4 - delay) * tuning.TailWag * (0.5 + 0.5 * move) * strength
				+ math.sin(phase - delay) * tuning.TailWalk * move * strength
			rx = math.sin(clock * 1.2 - delay) * 0.05 * strength
		elseif kind.Role == "Wing" then
			local amount = if hover
				then tuning.WingFlap
				else tuning.WingIdle + (tuning.WingFlap - tuning.WingIdle) * move * 0.5
			local speed = if hover then 9 else 2.2 + 5 * move
			local flap = math.sin(clock * speed) * amount * strength
			-- Links und rechts spiegelbildlich: beide Flügel gehen gleichzeitig hoch.
			rz = (if kind.Side < 0 then -1 else 1) * flap
		end

		pose[name] = { rx, ry, rz, lift }
	end
	return pose
end

-- Wie weit der Schritt-Takt für eine zurückgelegte Strecke vorrückt (Bogenmaß).
-- Große Figuren machen längere Schritte, damit die Füße nicht über den Boden rutschen.
function RigMotion.Advance(distance: number, height: number, tempo: number): number
	local stride = math.max(height, 0.5) * 0.9 -- Strecke für einen ganzen Zyklus (zwei Schritte)
	return distance / stride * 2 * math.pi * tempo
end

return RigMotion
