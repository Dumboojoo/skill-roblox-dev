local Formulas = require("../src/shared/Simulator/Formulas")

return function(t)
	t.test("Simulator: Upgrade-Preis wächst pro Stufe", function()
		t.equal(Formulas.UpgradeCost(25, 1.35, 0), 25)
		t.equal(Formulas.UpgradeCost(25, 1.35, 1), 33)
		t.truthy(Formulas.UpgradeCost(25, 1.35, 10) > Formulas.UpgradeCost(25, 1.35, 9))
	end)

	t.test("Simulator: Pets addieren ihre Boni", function()
		t.equal(Formulas.PetMultiplier({}), 1)
		t.equal(Formulas.PetMultiplier({ 1.5, 2 }), 2.5)
	end)

	t.test("Simulator: Klickwert aus Stufe, Pets und Rebirths", function()
		t.equal(Formulas.ClickValue(0, 1, 1), 1)
		t.equal(Formulas.ClickValue(4, 2.5, Formulas.RebirthMultiplier(2, 0.5)), 25)
	end)

	t.test("Simulator: Rebirth wird teurer", function()
		t.equal(Formulas.RebirthCost(1000, 2, 0), 1000)
		t.equal(Formulas.RebirthCost(1000, 2, 3), 8000)
	end)

	t.test("Simulator: gewichtete Auswahl trifft die Grenzen richtig", function()
		local entries = { { Id = "A", Weight = 50 }, { Id = "B", Weight = 30 }, { Id = "C", Weight = 20 } }
		t.equal(Formulas.PickWeighted(entries, 0), "A")
		t.equal(Formulas.PickWeighted(entries, 0.499), "A")
		t.equal(Formulas.PickWeighted(entries, 0.5), "B")
		t.equal(Formulas.PickWeighted(entries, 0.799), "B")
		t.equal(Formulas.PickWeighted(entries, 0.8), "C")
		t.equal(Formulas.PickWeighted(entries, 0.9999), "C")
	end)

	t.test("Simulator: Chancen ergeben zusammen 100 %", function()
		local odds = Formulas.Odds({ { Id = "A", Weight = 3 }, { Id = "B", Weight = 1 } })
		t.equal(odds.A, 0.75)
		t.equal(odds.B, 0.25)
	end)
end
