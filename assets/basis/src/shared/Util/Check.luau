--!strict
--[[
	Check – Prüffunktionen für alles, was vom Client kommt.

	Ein Exploiter kann jedem Remote beliebige Werte schicken: falsche Typen, NaN,
	riesige Texte, fremde Instanzen. Jede Prüffunktion gibt true/false zurück und
	wird in Net.On / Net.OnInvoke als Liste übergeben:

	Net.On("Shop.Buy", { Check.stringMax(40), Check.integerRange(1, 99) }, handler)
]]

export type Checker = (value: any) -> boolean

local Check = {}

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function Check.any(_value: any): boolean
	return true
end

function Check.string(value: any): boolean
	return type(value) == "string"
end

function Check.boolean(value: any): boolean
	return type(value) == "boolean"
end

-- Zahl, aber weder NaN noch unendlich.
function Check.number(value: any): boolean
	return type(value) == "number" and isFinite(value)
end

function Check.integer(value: any): boolean
	return type(value) == "number" and isFinite(value) and value % 1 == 0
end

function Check.Vector3(value: any): boolean
	return typeof(value) == "Vector3" and isFinite(value.X) and isFinite(value.Y) and isFinite(value.Z)
end

function Check.CFrame(value: any): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end
	local position = value.Position
	return isFinite(position.X) and isFinite(position.Y) and isFinite(position.Z)
end

function Check.table(value: any): boolean
	return type(value) == "table"
end

function Check.stringMax(maxLength: number): Checker
	return function(value: any): boolean
		return type(value) == "string" and #value <= maxLength
	end
end

function Check.numberRange(min: number, max: number): Checker
	return function(value: any): boolean
		return type(value) == "number" and isFinite(value) and value >= min and value <= max
	end
end

function Check.integerRange(min: number, max: number): Checker
	return function(value: any): boolean
		return type(value) == "number" and isFinite(value) and value % 1 == 0 and value >= min and value <= max
	end
end

-- Instanz einer bestimmten Klasse (IsA), z. B. Check.instance("BasePart").
function Check.instance(className: string): Checker
	return function(value: any): boolean
		return typeof(value) == "Instance" and value:IsA(className)
	end
end

-- Einer der erlaubten Werte, z. B. Check.oneOf({ "First", "Last", "Strongest" }).
function Check.oneOf(options: { any }): Checker
	return function(value: any): boolean
		return table.find(options, value) ~= nil
	end
end

-- Schlüssel einer Konfigurationstabelle, z. B. Check.keyOf(Weapons).
function Check.keyOf(dictionary: { [any]: any }): Checker
	return function(value: any): boolean
		return (type(value) == "string" or type(value) == "number") and dictionary[value] ~= nil
	end
end

function Check.optional(checker: Checker): Checker
	return function(value: any): boolean
		return value == nil or checker(value)
	end
end

-- Liste, deren Einträge alle `checker` bestehen und die höchstens `maxLength` lang ist.
function Check.arrayOf(checker: Checker, maxLength: number): Checker
	return function(value: any): boolean
		if type(value) ~= "table" then
			return false
		end
		local count = 0
		for key, item in value do
			count += 1
			if count > maxLength or type(key) ~= "number" or not checker(item) then
				return false
			end
		end
		return count == #value
	end
end

return Check
