--!strict
--[[
	AdminEffectsController – setzt Fliegen und Noclip für den eigenen Charakter um.

	Der Server setzt die Attribute AdminFly / AdminNoclip am Player. Bewegung des
	eigenen Charakters berechnet in Roblox immer der eigene Client, darum passiert
	die Umsetzung hier.

	Fliegen: WASD bzw. Stick in Blickrichtung (nach oben schauen = aufsteigen),
	zusätzlich Leertaste hoch und Shift/Strg runter.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage.Shared.Util.Trove)

local DEFAULT_FLY_SPEED = 60

local AdminEffectsController = {}

local player = Players.LocalPlayer
local flyTrove = Trove.new()
local noclipTrove = Trove.new()

local function characterParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

------------------------------------------------------------------------------
-- Fliegen
------------------------------------------------------------------------------

-- Das Steuerungs-Modul von Roblox liefert die Bewegungseingabe von Tastatur, Touch-Stick und
-- Controller in einem Wert – auch dann, wenn der Humanoid gerade nicht läuft (PlatformStand).
-- false: gesucht, aber nicht vorhanden (z. B. eigene Steuerung im Spiel).
local controls: any = nil

local function getControls(): any
	if controls == nil then
		controls = false
		local playerScripts = player:FindFirstChildOfClass("PlayerScripts")
		local module = if playerScripts then playerScripts:FindFirstChild("PlayerModule") else nil
		if module and module:IsA("ModuleScript") then
			local ok, playerModule = pcall(require :: any, module)
			if ok and type(playerModule) == "table" and type(playerModule.GetControls) == "function" then
				local okControls, result = pcall(playerModule.GetControls, playerModule)
				if okControls and type(result) == "table" and type(result.GetMoveVector) == "function" then
					controls = result
				end
			end
		end
	end
	return if controls then controls else nil
end

local function stopFly()
	flyTrove:Clean()
end

local function startFly()
	stopFly()
	local _character, humanoid, root = characterParts()
	if not humanoid or not root then
		return
	end

	local attachment = flyTrove:Add(Instance.new("Attachment"))
	attachment.Name = "AdminFlyAttachment"
	attachment.Parent = root

	local velocity = flyTrove:Add(Instance.new("LinearVelocity"))
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local orientation = flyTrove:Add(Instance.new("AlignOrientation"))
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.RigidityEnabled = true
	orientation.Parent = root

	humanoid.PlatformStand = true
	flyTrove:Add(function()
		humanoid.PlatformStand = false
	end)

	flyTrove:Connect(RunService.RenderStepped, function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local speed = player:GetAttribute("AdminFlySpeed")
		local flySpeed = if type(speed) == "number" then speed else DEFAULT_FLY_SPEED

		local look = camera.CFrame.LookVector
		local right = camera.CFrame.RightVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local flatRight = Vector3.new(right.X, 0, right.Z)

		local forwardAmount, rightAmount = 0, 0
		local activeControls = getControls()
		if activeControls then
			local input: Vector3 = activeControls:GetMoveVector() -- X: rechts, Z: zurück
			forwardAmount, rightAmount = -input.Z, input.X
		else
			-- Ersatz: die Laufrichtung des Humanoids auf die Blickrichtung umrechnen.
			local move = humanoid.MoveDirection
			forwardAmount = if flatLook.Magnitude > 0.01 then move:Dot(flatLook.Unit) else 0
			rightAmount = if flatRight.Magnitude > 0.01 then move:Dot(flatRight.Unit) else 0
		end

		local vertical = 0
		if not UserInputService:GetFocusedTextBox() then
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				vertical += 1
			end
			if
				UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			then
				vertical -= 1
			end
		end

		velocity.VectorVelocity = (look * forwardAmount + right * rightAmount + Vector3.yAxis * vertical) * flySpeed
		-- Aufrecht bleiben und in Blickrichtung drehen.
		if flatLook.Magnitude > 0.01 then
			orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook)
		end
	end)
end

------------------------------------------------------------------------------
-- Noclip
------------------------------------------------------------------------------

local function stopNoclip()
	noclipTrove:Clean()
end

local function startNoclip()
	stopNoclip()
	-- Vor jedem Physikschritt neu setzen, weil der Humanoid die Kollision selbst wieder einschaltet.
	noclipTrove:Connect(RunService.Stepped, function()
		local character = player.Character
		if not character then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end)
end

------------------------------------------------------------------------------

local function refresh()
	if player:GetAttribute("AdminFly") then
		startFly()
	else
		stopFly()
	end
	if player:GetAttribute("AdminNoclip") then
		startNoclip()
	else
		stopNoclip()
	end
end

function AdminEffectsController:Start()
	player:GetAttributeChangedSignal("AdminFly"):Connect(refresh)
	player:GetAttributeChangedSignal("AdminNoclip"):Connect(refresh)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 5)
		character:WaitForChild("Humanoid", 5)
		refresh()
	end)
	refresh()
end

return AdminEffectsController
