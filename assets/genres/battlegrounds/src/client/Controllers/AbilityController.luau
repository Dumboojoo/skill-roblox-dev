--!strict
--[[
	AbilityController – Eingaben, Abklingzeit-Anzeige, Ulti-Leiste, Kämpferwahl und
	alle sichtbaren Effekte von Battlegrounds.

	Lesbarkeit ist in diesem Genre alles: Jeder Angriff zeigt während der
	Ausholzeit seine Trefferzone als roten, durchscheinenden Kasten. So kann der
	Gegner ausweichen oder blocken, und Treffer fühlen sich verdient an.

	Steuerung (Tasten in Config/Battlegrounds.luau)
	  Maus links / R2    Grundschlag (Kombo)
	  E, R, T            Fähigkeiten
	  G                  Ulti (wenn die Leiste voll ist)
	  F halten           Blocken (nur von vorn)
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Battlegrounds)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

type Slot = { Fill: Frame, Label: TextLabel, ReadyAt: number, Duration: number }

local ULT_SLOT = 4
local SLOT_SIZE = 64

local AbilityController = {}

local player = Players.LocalPlayer
local slots: { [number]: Slot } = {}
local ultFill: Frame
local selectWindow: Frame

------------------------------------------------------------------------------
-- Effekte
------------------------------------------------------------------------------

local function attackFor(who: Player, slot: number): Config.Attack?
	local characterId = who:GetAttribute("BattleCharacter")
	local character = if type(characterId) == "string" then Config.Characters[characterId] else nil
	if not character then
		return nil
	end
	if slot == 0 then
		return character.Basic
	elseif slot == ULT_SLOT then
		return character.Ultimate
	end
	return character.Abilities[slot]
end

local function swingArm(character: Model)
	SoundController:PlayAt("Swing", character:GetPivot().Position)
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = if upperArm then upperArm:FindFirstChild("RightShoulder") else nil
	if not motor or not motor:IsA("Motor6D") or motor:GetAttribute("Swinging") then
		return
	end
	motor:SetAttribute("Swinging", true)
	local rest = motor.C0
	local out =
		TweenService:Create(motor, TweenInfo.new(0.07), { C0 = rest * CFrame.Angles(math.rad(115), math.rad(25), 0) })
	out:Play()
	out.Completed:Once(function()
		local back = TweenService:Create(motor, TweenInfo.new(0.18), { C0 = rest })
		back:Play()
		back.Completed:Once(function()
			motor:SetAttribute("Swinging", nil)
		end)
	end)
end

-- Zeigt die Trefferzone während der Ausholzeit. Sie hängt am Kämpfer und bewegt sich mit.
local function showTelegraph(who: Player, attack: Config.Attack)
	local character = who.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	local zone = Instance.new("Part")
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone.Material = Enum.Material.ForceField
	zone.Color = if who == player then Kit.Theme.Accent else Kit.Theme.Bad
	zone.Size = attack.Size
	zone.Transparency = 0.6
	zone.Parent = Workspace.CurrentCamera

	local duration = math.max(attack.Windup, 0.08) + 0.08
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() - started >= duration or not root.Parent then
			connection:Disconnect()
			zone:Destroy()
			return
		end
		zone.CFrame = root.CFrame * CFrame.new(0, 0, -attack.Reach)
	end)
end

local function showDamage(position: Vector3, amount: number, blocked: boolean)
	SoundController:PlayAt("Hit", position, if blocked then 0.5 else 1)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(math.random(-10, 10) / 8, 2.5, math.random(-10, 10) / 8)
	anchor.Parent = Workspace.CurrentCamera
	local billboard =
		Kit.Create("BillboardGui", { Size = UDim2.fromOffset(120, 36), AlwaysOnTop = true, Parent = anchor })
	local label = Kit.Label({
		Text = if blocked then `Block {amount}` else tostring(amount),
		Size = UDim2.fromScale(1, 1),
		FontFace = Kit.Theme.FontBold,
		TextSize = if blocked then 18 else 26,
		TextColor3 = if blocked then Kit.Theme.TextDim else Kit.Theme.Warn,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})
	Kit.Create("UIStroke", { Thickness = 2, Color = Kit.Theme.Background, Parent = label })
	Kit.Tween(anchor, 0.6, { Position = anchor.Position + Vector3.new(0, 3, 0) })
	Kit.Tween(label, 0.6, { TextTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.6, anchor.Destroy, anchor)
end

------------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------------

local function refreshSlotLabels()
	for slot, view in slots do
		local attack = attackFor(player, slot)
		local key = Config.Keys[slot][1]
		view.Label.Text = `{key.Name}\n{if attack then attack.DisplayName else ""}`
	end
end

local function buildSelectWindow(gui: ScreenGui)
	selectWindow = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Kit.Padding(12).Parent = selectWindow
	Kit.List(Enum.FillDirection.Vertical, 8).Parent = selectWindow
	Kit.Label({
		Text = "Kämpfer wählen",
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 0,
		Parent = selectWindow,
	})
	local order = 0
	for characterId, character in Config.Characters do
		order += 1
		Kit.Button({
			Text = `{character.DisplayName}  ({character.Health} Leben)\n{character.Description}`,
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = character.Color:Lerp(Kit.Theme.Background, 0.4),
			LayoutOrder = order,
			Parent = selectWindow,
		}, function()
			selectWindow.Visible = false
			Net.Send("Battle.Select", characterId)
		end)
	end
end

local function build()
	local gui = Kit.ScreenGui("BattleHud", 5)

	local bar = Kit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(0, SLOT_SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = gui,
	}, Kit.List(Enum.FillDirection.Horizontal, 8))

	for slot = 1, ULT_SLOT do
		local frame = Kit.Panel({
			Size = UDim2.fromOffset(SLOT_SIZE + 24, SLOT_SIZE),
			BackgroundColor3 = if slot == ULT_SLOT
				then Kit.Theme.Warn:Lerp(Kit.Theme.Background, 0.6)
				else Kit.Theme.Panel,
			ClipsDescendants = true,
			LayoutOrder = slot,
			Parent = bar,
		})
		-- Dunkler Schleier, der von oben nach unten abläuft, solange die Fähigkeit auflädt.
		local fill = Kit.Create("Frame", {
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Kit.Theme.Background,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = frame,
		})
		local label = Kit.Label({
			Size = UDim2.fromScale(1, 1),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
			Parent = frame,
		})
		slots[slot] = { Fill = fill, Label = label, ReadyAt = 0, Duration = 1 }
	end

	local ultBack = Kit.Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(4 * (SLOT_SIZE + 24) + 24, 10),
		BackgroundColor3 = Kit.Theme.Background,
		BorderSizePixel = 0,
		Parent = gui,
	}, Kit.Corner(5))
	ultFill = Kit.Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Kit.Theme.Warn,
		BorderSizePixel = 0,
		Parent = ultBack,
	}, Kit.Corner(5))

	Kit.Button({
		Text = "Kämpfer",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(120, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, function()
		selectWindow.Visible = not selectWindow.Visible
	end)
	buildSelectWindow(gui)
end

------------------------------------------------------------------------------
-- Eingaben
------------------------------------------------------------------------------

local function bindInputs()
	ContextActionService:BindAction("BattleBasic", function(_name, state)
		if state == Enum.UserInputState.Begin then
			Net.Send("Battle.Basic")
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("BattleBasic", "Schlag")
	ContextActionService:SetPosition("BattleBasic", UDim2.new(1, -150, 1, -130))

	for slot, keys in Config.Keys do
		local name = `BattleAbility{slot}`
		ContextActionService:BindAction(name, function(_name, state)
			if state == Enum.UserInputState.Begin then
				Net.Send("Battle.Ability", slot)
			end
			return Enum.ContextActionResult.Pass
		end, true, table.unpack(keys))
		ContextActionService:SetTitle(name, if slot == ULT_SLOT then "Ulti" else tostring(slot))
		ContextActionService:SetPosition(name, UDim2.new(1, -90 - slot * 62, 1, -210))
	end

	ContextActionService:BindAction("BattleBlock", function(_name, state)
		if state == Enum.UserInputState.Begin then
			Net.Send("Battle.Block", true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			Net.Send("Battle.Block", false)
		end
		return Enum.ContextActionResult.Pass
	end, true, table.unpack(Config.BlockKeys))
	ContextActionService:SetTitle("BattleBlock", "Block")
	ContextActionService:SetPosition("BattleBlock", UDim2.new(1, -230, 1, -90))
end

------------------------------------------------------------------------------

function AbilityController:Init()
	build()

	Net.Listen("Battle.Cooldown", function(slot: number, duration: number)
		local view = slots[slot]
		if view then
			view.ReadyAt = os.clock() + duration
			view.Duration = math.max(duration, 0.01)
		end
	end)
	Net.Listen("Battle.Cast", function(who: Player, slot: number)
		local attack = attackFor(who, slot)
		if attack and who.Character then
			swingArm(who.Character)
			showTelegraph(who, attack)
		end
	end)
	Net.Listen("Battle.Hit", showDamage)
	-- Rückstoß bzw. eigener Vorwärtssprung: Der Server gibt die Geschwindigkeit vor, wir setzen sie um.
	Net.Listen("Battle.Push", function(velocity: Vector3)
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity =
				Vector3.new(velocity.X, math.max(velocity.Y, root.AssemblyLinearVelocity.Y), velocity.Z)
		end
	end)
end

function AbilityController:Start()
	bindInputs()
	refreshSlotLabels()
	player:GetAttributeChangedSignal("BattleCharacter"):Connect(refreshSlotLabels)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, view in slots do
			view.Fill.Size = UDim2.fromScale(1, math.clamp((view.ReadyAt - now) / view.Duration, 0, 1))
		end
		local ult = player:GetAttribute("BattleUlt")
		ultFill.Size =
			UDim2.fromScale(math.clamp((if type(ult) == "number" then ult else 0) / Config.Ultimate.Max, 0, 1), 1)
	end)
end

return AbilityController
