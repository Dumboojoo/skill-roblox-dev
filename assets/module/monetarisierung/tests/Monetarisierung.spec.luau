local Daily = require("../src/shared/Shop/Daily")

return function(t)
	t.test("Täglich: Tagesnummer und Restzeit", function()
		t.equal(Daily.DayNumber(0), 0)
		t.equal(Daily.DayNumber(86399), 0)
		t.equal(Daily.DayNumber(86400), 1)
		t.equal(Daily.SecondsUntilNextDay(86400 + 100), 86300)
	end)

	t.test("Täglich: erste Abholung beginnt bei Tag 1", function()
		local can, streak = Daily.Status(0, 0, 20000, 7)
		t.truthy(can)
		t.equal(streak, 1)
	end)

	t.test("Täglich: am selben Tag kein zweites Mal", function()
		local can = Daily.Status(20000, 3, 20000, 7)
		t.falsy(can)
	end)

	t.test("Täglich: Folgetag setzt die Reihe fort", function()
		local can, streak = Daily.Status(20000, 3, 20001, 7)
		t.truthy(can)
		t.equal(streak, 4)
	end)

	t.test("Täglich: nach dem letzten Tag beginnt die Reihe von vorn", function()
		local _, streak = Daily.Status(20000, 7, 20001, 7)
		t.equal(streak, 1)
	end)

	t.test("Täglich: verpasster Tag setzt zurück", function()
		local can, streak = Daily.Status(20000, 5, 20002, 7)
		t.truthy(can)
		t.equal(streak, 1)
	end)

	t.test("Täglich: verstellte Uhr (Zukunft) gibt nichts", function()
		local can = Daily.Status(20005, 2, 20000, 7)
		t.falsy(can)
	end)
end
