local Migrate = require("../src/server/Data/Migrate")
local TablePath = require("../src/shared/Util/TablePath")
local Format = require("../src/shared/Util/Format")
local Check = require("../src/shared/Util/Check")

return function(t)
	-- Migrationen ------------------------------------------------------------

	t.test("Migrate: läuft alle fehlenden Schritte der Reihe nach", function()
		local steps = {
			[2] = function(data)
				data.Currency = { Coins = data.Coins or 0 }
				data.Coins = nil
			end,
			[3] = function(data)
				data.Currency.Gems = 0
			end,
		}
		local ok, result = Migrate.Run({ _Version = 1, Coins = 40 }, 3, steps)
		t.truthy(ok)
		t.equal(result, { _Version = 3, Currency = { Coins = 40, Gems = 0 } })
	end)

	t.test("Migrate: Original bleibt bei Fehler unberührt", function()
		local original = { _Version = 1, Coins = 40 }
		local ok, problem = Migrate.Run(original, 2, {
			[2] = function(data)
				data.Coins = nil
				error("kaputt")
			end,
		})
		t.falsy(ok)
		t.truthy(string.find(problem, "Version 2", 1, true))
		t.equal(original, { _Version = 1, Coins = 40 })
	end)

	t.test("Migrate: neuerer Spielstand wird abgelehnt", function()
		local ok = Migrate.Run({ _Version = 5 }, 3, {})
		t.falsy(ok)
	end)

	t.test("Migrate: fehlende Versionsnummer zählt als 1", function()
		local ok, result = Migrate.Run({}, 1, {})
		t.truthy(ok)
		t.equal(result._Version, 1)
	end)

	-- Pfade --------------------------------------------------------------------

	t.test("TablePath: Get und Set mit Text- und Listenpfad", function()
		local data = { Currency = { Coins = 5 }, Items = { "a", "b" } }
		t.equal(TablePath.Get(data, "Currency.Coins"), 5)
		t.equal(TablePath.Get(data, { "Items", 2 }), "b")
		t.equal(TablePath.Get(data, "Gibt.Es.Nicht"), nil)
		local old = TablePath.Set(data, "Currency.Coins", 9)
		t.equal(old, 5)
		TablePath.Set(data, "Neu.Tief.Wert", true)
		t.equal(data.Neu.Tief.Wert, true)
	end)

	t.test("TablePath: Reconcile ergänzt nur Fehlendes", function()
		local data = { Stats = { Joins = 7 }, Items = { "x" } }
		TablePath.Reconcile(data, { Stats = { Joins = 0, PlayTime = 0 }, Items = {}, Neu = { A = 1 } })
		t.equal(data, { Stats = { Joins = 7, PlayTime = 0 }, Items = { "x" }, Neu = { A = 1 } })
	end)

	t.test("TablePath: StartsWith", function()
		t.truthy(TablePath.StartsWith({ "A", "B", "C" }, { "A", "B" }))
		t.falsy(TablePath.StartsWith({ "A" }, { "A", "B" }))
		t.truthy(TablePath.StartsWith({ "A" }, {}))
	end)

	-- Anzeige ------------------------------------------------------------------

	t.test("Format.Number kürzt große Zahlen", function()
		t.equal(Format.Number(999), "999")
		t.equal(Format.Number(1000), "1K")
		t.equal(Format.Number(1234), "1.23K")
		t.equal(Format.Number(15300000), "15.3M")
		t.equal(Format.Number(999999), "999K")
		t.equal(Format.Number(-2500), "-2.5K")
	end)

	t.test("Format.Commas, Time, TimeMs", function()
		t.equal(Format.Commas(1234567), "1,234,567")
		t.equal(Format.Commas(999), "999")
		t.equal(Format.Time(75), "1:15")
		t.equal(Format.Time(3723), "1:02:03")
		t.equal(Format.TimeMs(75.318), "1:15.31")
	end)

	-- Eingabeprüfung ---------------------------------------------------------

	t.test("Check: Zahlen ohne NaN und unendlich", function()
		t.truthy(Check.number(5))
		t.falsy(Check.number(0 / 0))
		t.falsy(Check.number(math.huge))
		t.falsy(Check.number("5"))
		t.truthy(Check.integerRange(1, 10)(10))
		t.falsy(Check.integerRange(1, 10)(2.5))
		t.falsy(Check.integerRange(1, 10)(11))
	end)

	t.test("Check: Texte, Auswahl, Listen", function()
		t.truthy(Check.stringMax(3)("abc"))
		t.falsy(Check.stringMax(3)("abcd"))
		t.truthy(Check.oneOf({ "a", "b" })("b"))
		t.falsy(Check.oneOf({ "a", "b" })("c"))
		t.truthy(Check.keyOf({ Pistol = {} })("Pistol"))
		t.falsy(Check.keyOf({ Pistol = {} })("Laser"))
		t.truthy(Check.arrayOf(Check.string, 2)({ "a", "b" }))
		t.falsy(Check.arrayOf(Check.string, 2)({ "a", "b", "c" }))
		t.falsy(Check.arrayOf(Check.string, 5)({ "a", 1 }))
		t.truthy(Check.optional(Check.string)(nil))
	end)
end
