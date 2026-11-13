--!strict
--[[
	TablePath – verschachtelte Tabellen über Pfade lesen und schreiben.

	Ein Pfad ist entweder ein Text mit Punkten ("Currency.Coins") oder eine Liste
	({ "Inventory", "Items", 3 }). Die Liste ist nötig, wenn ein Schlüssel eine Zahl
	ist oder selbst einen Punkt enthält.
]]

export type Path = string | { string | number }
export type Segments = { string | number }

local TablePath = {}

function TablePath.Parse(path: Path): Segments
	if type(path) == "table" then
		return path
	end
	if path == "" then
		return {}
	end
	return string.split(path, ".") :: { any }
end

function TablePath.ToString(path: Path): string
	if type(path) == "string" then
		return path
	end
	local parts = table.create(#path)
	for index, segment in path do
		parts[index] = tostring(segment)
	end
	return table.concat(parts, ".")
end

function TablePath.Get(root: any, path: Path): any
	local current = root
	for _, segment in TablePath.Parse(path) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[segment]
	end
	return current
end

-- Setzt den Wert und legt fehlende Zwischentabellen an. Gibt den alten Wert zurück.
function TablePath.Set(root: any, path: Path, value: any): any
	local segments = TablePath.Parse(path)
	local count = #segments
	assert(count > 0, "TablePath.Set braucht einen nicht-leeren Pfad")
	local current = root
	for index = 1, count - 1 do
		local segment = segments[index]
		local nextTable = current[segment]
		if type(nextTable) ~= "table" then
			nextTable = {}
			current[segment] = nextTable
		end
		current = nextTable
	end
	local last = segments[count]
	local old = current[last]
	current[last] = value
	return old
end

function TablePath.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value :: any do
		copy[key] = TablePath.DeepCopy(child)
	end
	return copy :: any
end

function TablePath.DeepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not TablePath.DeepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- Ergänzt in `target` alle Schlüssel aus `template`, die noch fehlen (vorhandene bleiben unberührt).
function TablePath.Reconcile(target: any, template: any)
	for key, templateValue in template do
		local current = target[key]
		if current == nil then
			target[key] = TablePath.DeepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" then
			-- Listen (Arrays) sind Spielerdaten und werden nicht mit der Vorlage vermischt.
			if #templateValue == 0 then
				TablePath.Reconcile(current, templateValue)
			end
		end
	end
end

-- true, wenn `path` mit `prefix` beginnt (oder gleich ist).
function TablePath.StartsWith(path: Segments, prefix: Segments): boolean
	if #prefix > #path then
		return false
	end
	for index, segment in prefix do
		if tostring(path[index]) ~= tostring(segment) then
			return false
		end
	end
	return true
end

return TablePath
