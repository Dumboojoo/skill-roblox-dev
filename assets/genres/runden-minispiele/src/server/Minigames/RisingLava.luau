--!strict
--[[
	Steigende Lava – die Lava steigt, wer sie berührt, scheidet aus. Wer am Ende
	noch steht, gewinnt.

	Braucht in der Map ein Teil namens "Lava" (flach, deckt den ganzen Boden ab)
	und etwas zum Hochklettern. Optionales Attribut am Lava-Teil:
	  Speed (number)  Studs pro Sekunde, Standard 1.2
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RoundTypes = require(script.Parent.Parent.RoundTypes)

local DEFAULT_SPEED = 1.2
local HEAD_START = 4 -- Sekunden, bevor die Lava losläuft

local minigame: RoundTypes.Minigame = {
	DisplayName = "Steigende Lava",
	Description = "Klettere nach oben! Die Lava steigt.",
	Duration = 75,

	Start = function(context: RoundTypes.Context)
		local lava = context.Map:FindFirstChild("Lava", true)
		if not lava or not lava:IsA("BasePart") then
			warn(`[RisingLava] In {context.Map:GetFullName()} fehlt ein Teil namens "Lava".`)
			return
		end

		local originalCFrame = lava.CFrame
		local speedAttribute = lava:GetAttribute("Speed")
		local speed = if type(speedAttribute) == "number" then speedAttribute else DEFAULT_SPEED
		local startedAt = os.clock()

		context.Trove:Add(function()
			lava.CFrame = originalCFrame
		end)

		context.Trove:Connect(RunService.Heartbeat, function(deltaTime: number)
			if os.clock() - startedAt >= HEAD_START then
				lava.CFrame += Vector3.new(0, speed * deltaTime, 0)
			end
		end)

		context.Trove:Connect(lava.Touched, function(hit: BasePart)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = if character then Players:GetPlayerFromCharacter(character) else nil
			if player and context.IsAlive(player) then
				context.Eliminate(player)
			end
		end)
	end,
}

return minigame
