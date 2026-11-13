local Crafting = require("../src/shared/Survival/Crafting")

return function(t)
	t.test("Survival: CanAfford prüft jede Zutat", function()
		t.truthy(Crafting.CanAfford({ Wood = 4, Stone = 1 }, { Wood = 4 }))
		t.falsy(Crafting.CanAfford({ Wood = 3 }, { Wood = 4 }))
		t.falsy(Crafting.CanAfford({ Wood = 9 }, { Wood = 2, Stone = 1 }))
		t.truthy(Crafting.CanAfford({}, {}))
	end)

	t.test("Survival: Pay zieht ab und entfernt leere Einträge", function()
		local items = { Wood = 5, Stone = 2 }
		Crafting.Pay(items, { Wood = 5, Stone = 1 })
		t.equal(items, { Stone = 1 })
	end)

	t.test("Survival: Add legt neue Einträge an", function()
		local items = { Wood = 1 }
		Crafting.Add(items, "Wood", 2)
		Crafting.Add(items, "Plank", 1)
		t.equal(items, { Wood = 3, Plank = 1 })
	end)

	t.test("Survival: Refund rundet ab und lässt Nullen weg", function()
		t.equal(Crafting.Refund({ Plank = 4, Rope = 1 }, 0.5), { Plank = 2 })
	end)

	t.test("Survival: Snap rastet auf das Raster", function()
		t.equal(Crafting.Snap(5.9, 4), 4)
		t.equal(Crafting.Snap(6.1, 4), 8)
		t.equal(Crafting.Snap(-5.9, 4), -4)
		t.equal(Crafting.Snap(0, 4), 0)
	end)
end
