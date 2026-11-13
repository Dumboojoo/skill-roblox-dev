local CommandParser = require("../src/shared/Util/CommandParser")

local COMMANDS = {
	{
		Name = "fly",
		Aliases = { "fliegen" },
		Description = "",
		Args = {
			{ Name = "an/aus", Type = "boolean", Optional = true },
			{ Name = "spieler", Type = "player", Optional = true },
		},
	},
	{ Name = "flyspeed", Description = "", Args = { { Name = "wert", Type = "number" } } },
	{
		Name = "data",
		Description = "",
		Args = {
			{ Name = "aktion", Type = "choice", Choices = { "show", "set" } },
			{ Name = "spieler", Type = "player" },
		},
	},
	{
		Name = "kick",
		Description = "",
		Args = { { Name = "spieler", Type = "player" }, { Name = "grund", Type = "rest", Optional = true } },
	},
}
local CONTEXT = { Players = { "Max", "Maria Lu", "Tom" } }

local function labels(suggestions)
	local list = {}
	for _, suggestion in suggestions do
		table.insert(list, suggestion.Label)
	end
	return list
end

return function(t)
	t.test("Tokenize trennt an Leerzeichen", function()
		local tokens, trailing = CommandParser.Tokenize("speed 50  Max")
		t.equal(tokens, { "speed", "50", "Max" })
		t.falsy(trailing)
	end)

	t.test("Tokenize hält Anführungszeichen zusammen", function()
		local tokens = CommandParser.Tokenize('kick "Maria Lu" zu laut')
		t.equal(tokens, { "kick", "Maria Lu", "zu", "laut" })
	end)

	t.test("Tokenize erkennt abschließendes Leerzeichen", function()
		local tokens, trailing = CommandParser.Tokenize("fly ")
		t.equal(tokens, { "fly" })
		t.truthy(trailing)
	end)

	t.test("Tokenize: leere Eingabe", function()
		local tokens, trailing = CommandParser.Tokenize("")
		t.equal(tokens, {})
		t.falsy(trailing)
	end)

	t.test("StripSlash entfernt führenden Schrägstrich", function()
		t.equal(CommandParser.StripSlash("/fly an"), "fly an")
		t.equal(CommandParser.StripSlash("  fly"), "fly")
	end)

	t.test("ParseBoolean kennt deutsche und englische Wörter", function()
		t.equal(CommandParser.ParseBoolean("AN"), true)
		t.equal(CommandParser.ParseBoolean("off"), false)
		t.equal(CommandParser.ParseBoolean("Max"), nil)
	end)

	t.test("FindCommand findet Namen und Alias ohne Rücksicht auf Großschreibung", function()
		t.equal(CommandParser.FindCommand(COMMANDS, "FLY").Name, "fly")
		t.equal(CommandParser.FindCommand(COMMANDS, "fliegen").Name, "fly")
		t.equal(CommandParser.FindCommand(COMMANDS, "gibtsnicht"), nil)
	end)

	t.test("Usage zeigt Pflicht- und Wahl-Argumente", function()
		t.equal(CommandParser.Usage(COMMANDS[4]), "kick <spieler> [grund]")
	end)

	t.test("Suggest: Befehlsnamen nach Anfang", function()
		t.equal(labels(CommandParser.Suggest("fl", COMMANDS, CONTEXT)), { "fly", "flyspeed" })
		t.equal(labels(CommandParser.Suggest("/k", COMMANDS, CONTEXT)), { "kick" })
	end)

	t.test("Suggest: leere Eingabe zeigt alle Befehle", function()
		t.equal(#CommandParser.Suggest("", COMMANDS, CONTEXT), 4)
	end)

	t.test("Suggest: an/aus für Schalter", function()
		t.equal(labels(CommandParser.Suggest("fly ", COMMANDS, CONTEXT)), { "an", "aus" })
	end)

	t.test("Suggest: Auswahlwerte", function()
		t.equal(labels(CommandParser.Suggest("data s", COMMANDS, CONTEXT)), { "show", "set" })
	end)

	t.test("Suggest: Spielernamen, mit Anführungszeichen bei Leerzeichen", function()
		local suggestions = CommandParser.Suggest("kick ma", COMMANDS, CONTEXT)
		t.equal(labels(suggestions), { "Max", "Maria Lu" })
		t.equal(suggestions[2].Completion, 'kick "Maria Lu" ')
	end)

	t.test("Suggest: nichts für freie Texte und unbekannte Befehle", function()
		t.equal(#CommandParser.Suggest("kick Max we", COMMANDS, CONTEXT), 0)
		t.equal(#CommandParser.Suggest("gibtsnicht ", COMMANDS, CONTEXT), 0)
	end)
end
