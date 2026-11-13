--!strict
--[[
	World – die Verbindung zwischen Code und der in Studio gebauten Welt.

	Der Code kennt keine festen Pfade wie Workspace.Map.Lava1. Er sucht nach
	TAGS (CollectionService) und liest ATTRIBUTE. Dadurch kann die Welt beliebig
	umgebaut, verschoben und verschönert werden, ohne dass Code bricht.

	World.Observe("KillPart", function(part)
		local connection = part.Touched:Connect(...)
		return function() connection:Disconnect() end   -- Aufräumen, wenn das Teil verschwindet
	end)

	World.Observe funktioniert auch mit StreamingEnabled: Teile, die erst später
	geladen werden, lösen die Funktion dann aus.

	World.Expect prüft beim Serverstart den „Welt-Vertrag": Fehlt etwas, steht eine
	klare Meldung in der Ausgabe statt eines stillen Fehlers.
]]

local CollectionService = game:GetService("CollectionService")

export type Rule = {
	Tag: string,
	Min: number?, -- wie viele mindestens vorhanden sein müssen (Standard 1)
	Class: string?, -- erwartete Klasse (IsA), z. B. "BasePart" oder "Model"
	Attributes: { [string]: string }?, -- Attributname -> erwarteter Typ ("number", "string", "boolean", ...)
	Hint: string?, -- was man in Studio tun muss
}

local World = {}

function World.Tagged(tag: string): { Instance }
	return CollectionService:GetTagged(tag)
end

-- Ruft `onAdded` für jedes vorhandene und jedes künftige Objekt mit dem Tag auf.
-- Gibt `onAdded` eine Funktion zurück, läuft sie, sobald das Objekt den Tag verliert oder zerstört wird.
function World.Observe(tag: string, onAdded: (instance: Instance) -> (() -> ())?): () -> ()
	local cleanups: { [Instance]: () -> () } = {}

	local function added(instance: Instance)
		if cleanups[instance] then
			return
		end
		local ok, result = xpcall(onAdded, debug.traceback, instance)
		if not ok then
			warn(`[Welt] Fehler bei Tag "{tag}" an {instance:GetFullName()}:\n{result}`)
		elseif type(result) == "function" then
			cleanups[instance] = result
		end
	end

	local function removed(instance: Instance)
		local cleanup = cleanups[instance]
		if cleanup then
			cleanups[instance] = nil
			task.spawn(cleanup)
		end
	end

	local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	local removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(added, instance)
	end

	return function()
		addedConnection:Disconnect()
		removedConnection:Disconnect()
		for instance in cleanups do
			removed(instance)
		end
	end
end

-- Attribut mit Standardwert lesen; falscher Typ zählt als „nicht gesetzt".
function World.Attribute<T>(instance: Instance, name: string, default: T): T
	local value = instance:GetAttribute(name)
	if value == nil or typeof(value) ~= typeof(default) then
		return default
	end
	return value :: any
end

-- Prüft den Welt-Vertrag eines Features. Gibt true zurück, wenn alles da ist.
function World.Expect(feature: string, rules: { Rule }): boolean
	local problems: { string } = {}

	for _, rule in rules do
		local instances = CollectionService:GetTagged(rule.Tag)
		local minimum = rule.Min or 1
		local hint = if rule.Hint then ` Tipp: {rule.Hint}` else ""

		if #instances < minimum then
			table.insert(problems, `Tag "{rule.Tag}": {#instances} gefunden, mindestens {minimum} nötig.{hint}`)
		end

		for _, instance in instances do
			if rule.Class and not instance:IsA(rule.Class) then
				table.insert(
					problems,
					`{instance:GetFullName()} hat Tag "{rule.Tag}", ist aber {instance.ClassName} statt {rule.Class}.`
				)
			end
			if rule.Attributes then
				for attribute, expectedType in rule.Attributes do
					local actualType = typeof(instance:GetAttribute(attribute))
					if actualType ~= expectedType then
						table.insert(
							problems,
							`{instance:GetFullName()}: Attribut "{attribute}" fehlt oder ist {actualType} statt {expectedType}.`
						)
					end
				end
			end
		end
	end

	if #problems == 0 then
		return true
	end

	warn(`[Welt] {feature}: Die Welt passt noch nicht zum Code ({#problems} Punkt(e)):`)
	for _, problem in problems do
		warn("   - " .. problem)
	end
	return false
end

return World
