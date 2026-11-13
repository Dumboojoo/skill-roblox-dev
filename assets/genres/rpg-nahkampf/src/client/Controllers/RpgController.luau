--!strict
--[[
	RpgController – Kampfeingaben, Schlagbewegung, Schadenszahlen, XP-Balken, Quests.

	Schlagbewegung ohne Animations-Dateien: Der Schulter-Motor (Motor6D) des
	schlagenden Charakters wird kurz über sein C0 gedreht und wieder zurück. Das
	macht jeder Client selbst, sobald der Server "Combat.Swing" meldet. Wer eigene
	Animationen hat, ersetzt `playSwing` durch Animator:LoadAnimation(...):Play().

	Steuerung
	  Maus links / R2 / Touch-Knopf   zuschlagen
	  Q / B (Controller) / Touch      Ausweichrolle in Laufrichtung
	  J oder Knopf "Quests"           Quest-Menü
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Rpg)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Rpg.Formulas)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local EffectController = require(script.Parent.EffectController)
local SoundController = require(script.Parent.SoundController)
local DataController = require(script.Parent.DataController)

local RpgController = {}

local player = Players.LocalPlayer
local nextAttack = 0
local nextDodge = 0
local originalC0: { [Motor6D]: CFrame } = {}

local levelLabel: TextLabel
local xpFill: Frame
local tracker: Frame
local questWindow: Frame
local questList: ScrollingFrame

------------------------------------------------------------------------------
-- Kampf
------------------------------------------------------------------------------

local function rightShoulder(character: Model): Motor6D?
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = if upperArm then upperArm:FindFirstChild("RightShoulder") else nil
	if not motor then
		local torso = character:FindFirstChild("Torso")
		motor = if torso then torso:FindFirstChild("Right Shoulder") else nil
	end
	return if motor and motor:IsA("Motor6D") then motor else nil
end

-- Kurzer Armschwung; der dritte Kombo-Schlag holt weiter aus.
local function playSwing(character: Model, comboStep: number)
	SoundController:PlayAt("Swing", character:GetPivot().Position)
	local motor = rightShoulder(character)
	if not motor then
		return
	end
	local rest = originalC0[motor]
	if not rest then
		rest = motor.C0
		originalC0[motor] = rest
		motor.Destroying:Once(function()
			originalC0[motor] = nil
		end)
	end
	local reach = if comboStep >= Config.Attack.ComboCount then 150 else 110
	local side = if comboStep % 2 == 0 then -35 else 35
	local swing = rest * CFrame.Angles(math.rad(reach), math.rad(side), 0)
	local out =
		TweenService:Create(motor, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = swing })
	out:Play()
	out.Completed:Once(function()
		TweenService:Create(motor, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = rest })
			:Play()
	end)
end

local function attack()
	local now = os.clock()
	if now < nextAttack then
		return
	end
	nextAttack = now + Config.Attack.Cooldown
	Net.Send("Combat.Attack")
end

local function dodge()
	local now = os.clock()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if now < nextDodge or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	nextDodge = now + Config.Dodge.Cooldown
	Net.Send("Combat.Dodge")
	-- Die Bewegung macht der eigene Client: in Laufrichtung, sonst nach vorn.
	local direction = if humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else root.CFrame.LookVector
	local velocity = direction * Config.Dodge.Speed
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)
end

local function showDamage(position: Vector3, amount: number)
	SoundController:PlayAt("Hit", position)
	EffectController:Play("Hit", position)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(math.random(-10, 10) / 10, 2, math.random(-10, 10) / 10)
	anchor.Parent = Workspace.CurrentCamera

	local billboard = Kit.Create("BillboardGui", {
		Size = UDim2.fromOffset(90, 34),
		AlwaysOnTop = true,
		Parent = anchor,
	})
	local label = Kit.Label({
		Text = tostring(math.floor(amount)),
		Size = UDim2.fromScale(1, 1),
		FontFace = Kit.Theme.FontBold,
		TextSize = 24,
		TextColor3 = Kit.Theme.Warn,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = billboard,
	})
	Kit.Create("UIStroke", { Thickness = 2, Color = Kit.Theme.Background, Parent = label })
	Kit.Tween(anchor, 0.7, { Position = anchor.Position + Vector3.new(0, 3, 0) })
	Kit.Tween(label, 0.7, { TextTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.7, anchor.Destroy, anchor)
end

------------------------------------------------------------------------------
-- Anzeige
------------------------------------------------------------------------------

local function refreshQuests()
	local rpg = DataController:Get("Rpg")
	if type(rpg) ~= "table" then
		return
	end
	for _, frame in { tracker :: GuiObject, questList } do
		for _, child in frame:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local ids = {}
	for questId in Config.Quests do
		table.insert(ids, questId)
	end
	table.sort(ids, function(a, b)
		return Config.Quests[a].RequiresLevel < Config.Quests[b].RequiresLevel
	end)

	for index, questId in ids do
		local quest = Config.Quests[questId]
		local progress = rpg.Quests.Active[questId]
		local done = rpg.Quests.Done[questId] == true
		local active = type(progress) == "number"

		if active then
			Kit.Label({
				Text = `{quest.Title}: {progress} / {quest.Count}`,
				TextSize = 14,
				TextColor3 = if progress >= quest.Count then Kit.Theme.Good else Kit.Theme.Text,
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = index,
				Parent = tracker,
			})
		end

		local row = Kit.Panel({
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = Kit.Theme.PanelLight,
			LayoutOrder = index,
			Parent = questList,
		})
		Kit.Padding(8).Parent = row
		Kit.Label({
			Text = `{quest.Title}  (ab Stufe {quest.RequiresLevel})`,
			FontFace = Kit.Theme.FontBold,
			Size = UDim2.new(1, -150, 0, 22),
			Parent = row,
		})
		Kit.Label({
			Text = `{quest.Description}  Belohnung: {quest.RewardXp} XP, {quest.RewardCoins} Münzen`,
			TextSize = 13,
			TextColor3 = Kit.Theme.TextDim,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, -150, 1, -24),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})

		local text, color, action = "Annehmen", Kit.Theme.Accent, "Rpg.AcceptQuest"
		local enabled = rpg.Level >= quest.RequiresLevel
		if done then
			text, color, enabled = "Erledigt", Kit.Theme.Panel, false
		elseif active and progress >= quest.Count then
			text, color, action = "Abholen", Kit.Theme.Good, "Rpg.ClaimQuest"
		elseif active then
			text, color, enabled = `{progress} / {quest.Count}`, Kit.Theme.Panel, false
		elseif not enabled then
			text, color = "Gesperrt", Kit.Theme.Panel
		end
		Kit.Button({
			Text = text,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(136, 44),
			BackgroundColor3 = color,
			Active = enabled,
			Parent = row,
		}, function()
			if enabled then
				Net.Send(action, questId)
			end
		end)
	end
end

local function refreshXp()
	local xp = DataController:Get("Rpg.Xp")
	local levels = Config.Levels
	local level, into, needed =
		Formulas.LevelFromXp(if type(xp) == "number" then xp else 0, levels.BaseXp, levels.Exponent, levels.MaxLevel)
	levelLabel.Text = if needed > 0
		then `Stufe {level}   {Format.Number(into)} / {Format.Number(needed)} XP`
		else `Stufe {level} (Maximum)`
	Kit.Tween(xpFill, 0.25, { Size = UDim2.fromScale(if needed > 0 then into / needed else 1, 1) })
end

local function build()
	local gui = Kit.ScreenGui("RpgHud", 5)

	local xpPanel = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(420, 40),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	levelLabel = Kit.Label({
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(1, -20, 0, 22),
		TextSize = 14,
		Parent = xpPanel,
	})
	local xpBack = Kit.Create("Frame", {
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 0, 8),
		BackgroundColor3 = Kit.Theme.Background,
		BorderSizePixel = 0,
		Parent = xpPanel,
	}, Kit.Corner(4))
	xpFill = Kit.Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Kit.Theme.Accent,
		BorderSizePixel = 0,
		Parent = xpBack,
	}, Kit.Corner(4))

	tracker = Kit.Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 120),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, Kit.List(Enum.FillDirection.Vertical, 2))

	questWindow = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 380),
		Visible = false,
		Parent = gui,
	})
	Kit.Label({
		Text = "Quests",
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Parent = questWindow,
	})
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		Parent = questWindow,
	}, function()
		questWindow.Visible = false
	end)
	questList = Kit.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 1, -68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = questWindow,
	}, Kit.List(Enum.FillDirection.Vertical, 6))

	Kit.Button({
		Text = "Quests",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, function()
		questWindow.Visible = not questWindow.Visible
	end)
end

------------------------------------------------------------------------------

function RpgController:Init()
	build()
	Net.Listen("Combat.Swing", function(who: Player, comboStep: number)
		if who.Character then
			playSwing(who.Character, comboStep)
		end
	end)
	Net.Listen("Combat.Damage", showDamage)
end

function RpgController:Start()
	DataController:Observe("Rpg.Xp", refreshXp)
	DataController:Observe("Rpg.Quests", refreshQuests)
	DataController:Observe("Rpg.Level", refreshQuests)

	ContextActionService:BindAction("RpgAttack", function(_name, state)
		if state == Enum.UserInputState.Begin then
			attack()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("RpgAttack", "Schlag")
	ContextActionService:SetPosition("RpgAttack", UDim2.new(1, -150, 1, -130))

	ContextActionService:BindAction("RpgDodge", function(_name, state)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("RpgDodge", "Rolle")
	ContextActionService:SetPosition("RpgDodge", UDim2.new(1, -230, 1, -90))

	ContextActionService:BindAction("RpgQuests", function(_name, state)
		if state == Enum.UserInputState.Begin then
			questWindow.Visible = not questWindow.Visible
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.J)
end

return RpgController
