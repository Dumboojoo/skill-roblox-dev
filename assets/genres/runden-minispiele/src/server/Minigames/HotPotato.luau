--!strict
--[[
	Heiße Kartoffel – ein Spieler trägt die Kartoffel und gibt sie durch Berühren
	weiter. Wer sie hält, wenn die Zeit abläuft, scheidet aus. Der Letzte gewinnt.

	Braucht keine besonderen Teile in der Map, nur Startpunkte.
]]

local Players = game:GetService("Players")

local RoundTypes = require(script.Parent.Parent.RoundTypes)

local FUSE_TIME = 12 -- Sekunden bis zur „Explosion"
local PASS_COOLDOWN = 0.6 -- verhindert sofortiges Zurückgeben
local HOLDER_SPEED = 20 -- der Träger ist etwas schneller als die anderen (16)

local random = Random.new()

local minigame: RoundTypes.Minigame = {
	DisplayName = "Heiße Kartoffel",
	Description = "Gib die Kartoffel weiter, bevor sie explodiert!",
	Duration = 120,

	Start = function(context: RoundTypes.Context)
		local holder: Player? = nil
		local highlight: Highlight? = nil
		local touchConnection: RBXScriptConnection? = nil
		local lastPass = 0

		local function setHolder(player: Player?)
			if highlight then
				highlight:Destroy()
				highlight = nil
			end
			if touchConnection then
				touchConnection:Disconnect()
				touchConnection = nil
			end
			local previous = holder
			if previous and previous.Character then
				local humanoid = previous.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 16
				end
			end

			holder = player
			lastPass = os.clock()
			local character = if player then player.Character else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if not player or not character or not root or not root:IsA("BasePart") then
				return
			end

			local newHighlight = Instance.new("Highlight")
			newHighlight.FillColor = Color3.fromRGB(255, 120, 40)
			newHighlight.OutlineColor = Color3.fromRGB(255, 220, 120)
			newHighlight.Parent = character
			highlight = newHighlight

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = HOLDER_SPEED
			end

			touchConnection = root.Touched:Connect(function(hit)
				if os.clock() - lastPass < PASS_COOLDOWN then
					return
				end
				local otherCharacter = hit:FindFirstAncestorOfClass("Model")
				local other = if otherCharacter then Players:GetPlayerFromCharacter(otherCharacter) else nil
				if other and other ~= holder and context.IsAlive(other) then
					setHolder(other)
				end
			end)
		end

		local function pickRandomHolder()
			local alive = context.Alive()
			if #alive > 0 then
				setHolder(alive[random:NextInteger(1, #alive)])
			end
		end

		context.Trove:Add(function()
			setHolder(nil)
		end)

		pickRandomHolder()
		context.Trove:Add(task.spawn(function()
			while true do
				task.wait(FUSE_TIME)
				local current = holder
				-- Hat der Träger die Runde inzwischen verlassen, trifft es niemanden.
				if current and context.IsAlive(current) then
					context.Eliminate(current)
				end
				pickRandomHolder()
			end
		end))
	end,
}

return minigame
