--[[
	vertrag_pruefen.luau – prüft im Bearbeitungsmodus, ob die Welt zum Code passt
	(über `execute_luau` ausführen, BEVOR ein Spieltest gestartet wird).

	Kein Spielcode. Die Liste CONTRACT mit dem Welt-Vertrag des Genres füllen
	(steht in references/genres/<genre>.md und im Kopf der Config-Datei).
	Die Rückgabe ist ein Text mit allem, was fehlt oder falsch ist.

	Im Spiel selbst prüft World.Expect dasselbe beim Serverstart. Dieses Skript
	spart den Umweg über einen Spieltest.
]]

local CollectionService = game:GetService("CollectionService")

-- Tag, Mindestanzahl, erwartete Klasse (oder nil), Attribute mit erwartetem Typ.
local CONTRACT: { { Tag: string, Min: number, Class: string?, Attributes: { [string]: string }? } } = {
	{ Tag = "Checkpoint", Min = 2, Class = "BasePart", Attributes = { Stage = "number" } },
	{ Tag = "KillPart", Min = 1, Class = "BasePart" },
}

local lines: { string } = {}
local problems = 0

for _, rule in CONTRACT do
	local instances = CollectionService:GetTagged(rule.Tag)
	local status = if #instances >= rule.Min then "ok" else "FEHLT"
	if status ~= "ok" then
		problems += 1
	end
	table.insert(lines, `{status}  {rule.Tag}: {#instances} vorhanden (mindestens {rule.Min})`)

	for _, instance in instances do
		if rule.Class and not instance:IsA(rule.Class) then
			problems += 1
			table.insert(
				lines,
				`   FALSCHE KLASSE  {instance:GetFullName()} ist {instance.ClassName}, erwartet {rule.Class}`
			)
		end
		for attribute, expected in rule.Attributes or {} :: { [string]: string } do
			local actual = typeof(instance:GetAttribute(attribute))
			if actual ~= expected then
				problems += 1
				table.insert(
					lines,
					`   ATTRIBUT  {instance:GetFullName()}: {attribute} ist {actual}, erwartet {expected}`
				)
			end
		end
	end
end

-- Doppelte Reihenfolge-Nummern fallen sonst erst im Spiel auf.
for _, check in
	{
		{ Tag = "Checkpoint", Attribute = "Stage" },
		{ Tag = "PathPoint", Attribute = "Order" },
		{ Tag = "RaceCheckpoint", Attribute = "Order" },
	}
do
	local seen: { [number]: Instance } = {}
	for _, instance in CollectionService:GetTagged(check.Tag) do
		local value = instance:GetAttribute(check.Attribute)
		if type(value) == "number" then
			if seen[value] then
				problems += 1
				table.insert(
					lines,
					`   DOPPELT  {check.Tag} {check.Attribute}={value}: {seen[value]:GetFullName()} und {instance:GetFullName()}`
				)
			end
			seen[value] = instance
		end
	end
end

table.insert(lines, 1, if problems == 0 then "Welt-Vertrag erfüllt." else `Welt-Vertrag: {problems} Problem(e).`)
return table.concat(lines, "\n")
