--!strict
--[[
	PathMath – Rechnen auf dem Gegnerweg.

	Gegner sind auf dem Server keine Modelle, sondern nur eine Zahl: die Strecke,
	die sie auf dem Weg zurückgelegt haben. Aus dieser Zahl berechnen Server
	(Reichweite der Türme) und Client (Darstellung) mit denselben Funktionen die
	Position. Das spart fast die gesamte Bandbreite und Physik.
]]

local CollectionService = game:GetService("CollectionService")

export type Path = {
	Points: { Vector3 },
	Lengths: { number }, -- Lengths[i] = Strecke vom Start bis Punkt i
	Total: number,
}

local PathMath = {}

function PathMath.new(points: { Vector3 }): Path
	local lengths = table.create(#points, 0)
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
		lengths[index] = total
	end
	return { Points = points, Lengths = lengths, Total = total }
end

-- Baut den Weg aus allen Teilen mit Tag PathPoint, sortiert nach Attribut Order.
function PathMath.fromWorld(): Path?
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged("PathPoint") do
		if instance:IsA("BasePart") and type(instance:GetAttribute("Order")) == "number" then
			table.insert(parts, instance)
		end
	end
	if #parts < 2 then
		return nil
	end
	table.sort(parts, function(a, b)
		return (a:GetAttribute("Order") :: number) < (b:GetAttribute("Order") :: number)
	end)
	local points = table.create(#parts)
	for index, part in parts do
		points[index] = part.Position
	end
	return PathMath.new(points)
end

-- Position und Laufrichtung nach `distance` Studs auf dem Weg.
function PathMath.PositionAt(path: Path, distance: number): (Vector3, Vector3)
	local points = path.Points
	local clamped = math.clamp(distance, 0, path.Total)
	for index = 2, #points do
		if clamped <= path.Lengths[index] then
			local from = points[index - 1]
			local segment = points[index] - from
			local length = segment.Magnitude
			local alpha = if length > 0 then (clamped - path.Lengths[index - 1]) / length else 0
			return from + segment * alpha, if length > 0 then segment.Unit else Vector3.zAxis
		end
	end
	local last = points[#points]
	return last, (last - points[#points - 1]).Unit
end

-- Kürzester Abstand eines Punktes zum Weg (in der Ebene, Höhe wird ignoriert).
function PathMath.DistanceTo(path: Path, point: Vector3): number
	local flat = Vector3.new(point.X, 0, point.Z)
	local best = math.huge
	local points = path.Points
	for index = 2, #points do
		local a = Vector3.new(points[index - 1].X, 0, points[index - 1].Z)
		local b = Vector3.new(points[index].X, 0, points[index].Z)
		local segment = b - a
		local lengthSquared = segment:Dot(segment)
		local alpha = if lengthSquared > 0 then math.clamp((flat - a):Dot(segment) / lengthSquared, 0, 1) else 0
		best = math.min(best, (flat - (a + segment * alpha)).Magnitude)
	end
	return best
end

return PathMath
