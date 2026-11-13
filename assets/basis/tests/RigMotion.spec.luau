--[[
	Prüft die Rechnung hinter der Figuren-Bewegung (shared/Util/RigMotion).
	Hier lässt sich absichern, was man im Spiel nur schwer sieht: dass linkes und rechtes
	Bein gegengleich laufen, Knie nur nach hinten beugen und im Stand nichts zappelt.
]]

local RigMotion = require("../src/shared/Util/RigMotion")

local BIPED = {
	"Torso",
	"Head",
	"Jaw",
	"LeftEye",
	"LeftUpperArm",
	"LeftLowerArm",
	"RightUpperArm",
	"RightLowerArm",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"RightUpperLeg",
	"RightLowerLeg",
	"Tail1",
	"Tail2",
	"Tail3",
}
local QUAD = { "Body", "Head", "FrontLeftLeg", "FrontRightLeg", "BackLeftLeg", "BackRightLeg", "Tail1" }
local FLYER = { "Body", "Head", "LeftWing", "RightWing", "Tail1" }

local function input(overrides: { [string]: any }?): any
	local values = {
		Gait = "Zweibeiner",
		Phase = 0,
		Move = 1,
		Clock = 0,
		Strength = 1,
		Height = 6,
		JawOpen = 0,
	}
	for key, value in overrides or {} do
		values[key] = value
	end
	return values
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t)
	t.test("Bewegung: Teile werden am Namen erkannt", function()
		local kinds = RigMotion.Classify(BIPED, "Torso")
		t.equal(kinds.Torso.Role, "Body")
		t.equal(kinds.Head.Role, "Head")
		t.equal(kinds.Jaw.Role, "Jaw")
		t.equal(kinds.LeftEye, nil) -- unbekannte Teile bleiben starr
		t.equal(kinds.LeftUpperArm.Role, "Arm")
		t.equal(kinds.LeftUpperArm.Side, -1)
		t.equal(kinds.RightLowerLeg.Role, "Leg")
		t.equal(kinds.RightLowerLeg.Side, 1)
		t.equal(kinds.RightLowerLeg.Lower, true)
		t.equal(kinds.LeftUpperLeg.Lower, false)
		t.equal(kinds.Tail3.Index, 3)

		local quad = RigMotion.Classify(QUAD, "Body")
		t.equal(quad.FrontLeftLeg.Front, true)
		t.equal(quad.BackRightLeg.Back, true)
		t.equal(quad.BackRightLeg.Side, 1)
	end)

	t.test("Bewegung: Gangart wird aus den Teilen erraten", function()
		t.equal(RigMotion.GuessGait(RigMotion.Classify(BIPED, "Torso")), "Zweibeiner")
		t.equal(RigMotion.GuessGait(RigMotion.Classify(QUAD, "Body")), "Vierbeiner")
		t.equal(RigMotion.GuessGait(RigMotion.Classify(FLYER, "Body")), "Schweben")
	end)

	t.test("Bewegung: linkes und rechtes Bein laufen gegengleich", function()
		local kinds = RigMotion.Classify(BIPED, "Torso")
		for step = 0, 15 do
			local pose = RigMotion.Sample(kinds, input({ Phase = step * 0.4 }))
			t.truthy(near(pose.LeftUpperLeg[1], -pose.RightUpperLeg[1]))
			-- Arm und Bein derselben Seite schwingen entgegengesetzt
			t.truthy(pose.LeftUpperLeg[1] * pose.LeftUpperArm[1] <= 1e-9)
		end
	end)

	t.test("Bewegung: Knie beugen nur nach hinten, Ellbogen nur nach vorn", function()
		local kinds = RigMotion.Classify(BIPED, "Torso")
		for step = 0, 31 do
			local pose = RigMotion.Sample(kinds, input({ Phase = step * 0.2, Clock = step * 0.13 }))
			t.truthy(pose.LeftLowerLeg[1] <= 1e-9)
			t.truthy(pose.RightLowerLeg[1] <= 1e-9)
			t.truthy(pose.LeftLowerArm[1] >= -1e-9)
			t.truthy(pose.RightLowerArm[1] >= -1e-9)
		end
	end)

	t.test("Bewegung: im Stand ruhen Arme und Beine", function()
		local kinds = RigMotion.Classify(BIPED, "Torso")
		for step = 0, 15 do
			local pose = RigMotion.Sample(kinds, input({ Move = 0, Phase = step, Clock = step * 0.3 }))
			t.truthy(near(pose.LeftUpperLeg[1], 0))
			t.truthy(near(pose.RightLowerLeg[1], 0))
			t.truthy(near(pose.LeftUpperArm[1], 0))
			-- Atmen und Schwanz bleiben sichtbar, aber klein
			t.truthy(math.abs(pose.Torso[4]) < 0.2)
			t.truthy(math.abs(pose.Tail1[2]) < 0.4)
		end
	end)

	t.test("Bewegung: Vierbeiner trabt über Kreuz", function()
		local kinds = RigMotion.Classify(QUAD, "Body")
		for step = 0, 15 do
			local pose = RigMotion.Sample(kinds, input({ Gait = "Vierbeiner", Phase = step * 0.4 }))
			t.truthy(near(pose.FrontLeftLeg[1], pose.BackRightLeg[1]))
			t.truthy(near(pose.FrontRightLeg[1], pose.BackLeftLeg[1]))
			t.truthy(near(pose.FrontLeftLeg[1], -pose.FrontRightLeg[1]))
		end
	end)

	t.test("Bewegung: Flügel schlagen spiegelbildlich, Maul öffnet nach unten", function()
		local kinds = RigMotion.Classify(FLYER, "Body")
		for step = 0, 15 do
			local pose = RigMotion.Sample(kinds, input({ Gait = "Schweben", Clock = step * 0.11 }))
			t.truthy(near(pose.LeftWing[3], -pose.RightWing[3]))
		end
		local biped = RigMotion.Classify(BIPED, "Torso")
		local closed = RigMotion.Sample(biped, input({ JawOpen = 0 }))
		local open = RigMotion.Sample(biped, input({ JawOpen = 1 }))
		t.truthy(open.Jaw[1] < closed.Jaw[1])
		t.truthy(near(open.Jaw[1], -RigMotion.Tuning.JawMax))
	end)

	t.test("Bewegung: Ausschläge bleiben im Rahmen und Stärke 0 hält alles still", function()
		local kinds = RigMotion.Classify(BIPED, "Torso")
		for step = 0, 63 do
			local pose = RigMotion.Sample(kinds, input({ Phase = step * 0.37, Clock = step * 0.21, Strength = 1.5 }))
			for _, values in pose do
				for index = 1, 3 do
					t.truthy(math.abs(values[index]) < 1.6) -- nie mehr als etwa 90 Grad
				end
			end
		end
		local still = RigMotion.Sample(kinds, input({ Phase = 1.3, Clock = 0, Strength = 0 }))
		t.truthy(near(still.LeftUpperLeg[1], 0))
		t.truthy(near(still.Tail2[2], 0))
		t.truthy(near(still.Head[2], 0))
	end)

	t.test("Bewegung: große Figuren machen längere Schritte", function()
		local small = RigMotion.Advance(4, 3, 1)
		local big = RigMotion.Advance(4, 12, 1)
		t.truthy(small > big)
		t.truthy(near(RigMotion.Advance(4, 6, 2), RigMotion.Advance(4, 6, 1) * 2))
	end)
end
