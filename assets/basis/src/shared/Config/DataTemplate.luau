--!strict
--[[
	DataTemplate – wie der Spielstand eines neuen Spielers aussieht.

	Der Spielstand wird aus ABSCHNITTEN zusammengesetzt. Jedes Feature legt eine
	eigene Datei in Config/DataSections an und bekommt dort seinen eigenen
	Oberschlüssel (z. B. "Obby", "Inventory", "Currency"). So muss für ein neues
	Feature keine bestehende Datei angefasst werden.

	Regeln für Spielstand-Daten:
	  - Nur Zahlen, Texte, Wahrheitswerte und Tabellen daraus. Keine Instanzen,
	    kein Vector3/Color3 (vorher in Zahlen zerlegen), keine Funktionen.
	  - Listen ohne Lücken; keine Tabellen, die Zahlen- und Text-Schlüssel mischen.
	  - Schlüssel mit Unterstrich am Anfang (z. B. _Receipts) werden NICHT an den
	    Client geschickt.
	  - Neue Felder einfach in die Vorlage schreiben: Bestehende Spieler bekommen
	    sie beim nächsten Laden automatisch. Umbenennen/Umbauen nur per Migration
	    (Config/DataMigrations) und VERSION erhöhen.
]]

local Migrations = require(script.Parent.DataMigrations)

export type LeaderstatSpec = {
	Name: string, -- Anzeigename in der Spielerliste
	Path: string, -- Pfad im Spielstand, z. B. "Currency.Coins"
}

export type Section = {
	Template: { [string]: any },
	Leaderstats: { LeaderstatSpec }?,
}

-- Bei jedem Umbau bestehender Felder um 1 erhöhen und eine Migration schreiben.
local VERSION = Migrations.Version

local Template: { [string]: any } = {
	_Version = VERSION,
	_Receipts = {}, -- bereits verarbeitete Käufe (Schutz vor doppelter Gutschrift)
}
local Leaderstats: { LeaderstatSpec } = {}

local sectionModules = script.Parent.DataSections:GetChildren()
table.sort(sectionModules, function(a, b)
	return a.Name < b.Name
end)

for _, module in sectionModules do
	if not module:IsA("ModuleScript") then
		continue
	end
	local section = (require :: any)(module) :: Section
	for key, value in section.Template do
		assert(Template[key] == nil, `DataSections/{module.Name}: Schlüssel "{key}" ist schon vergeben`)
		Template[key] = value
	end
	local sectionLeaderstats: { LeaderstatSpec } = section.Leaderstats or {}
	for _, leaderstat in sectionLeaderstats do
		table.insert(Leaderstats, leaderstat)
	end
end

return {
	Version = VERSION,
	Template = Template,
	Leaderstats = Leaderstats,
	Migrations = Migrations.Steps,
}
