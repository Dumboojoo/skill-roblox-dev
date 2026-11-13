--!strict
--[[
	DungeonController – Minikarte, Angriffseingabe und Meldungen des Dungeons.

	Die Minikarte zeigt den Grundriss als Raster: Jeder Raum ist ein Kästchen,
	gefärbt nach Art und Zustand. Der eigene Raum ist umrandet. Räume werden erst
	sichtbar, wenn man sie betreten hat (Erkunden bleibt spannend).

	Steuerung: Maus links / R2 / Touch-Knopf = zuschlagen.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Dungeon)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

type CellView = { X: number, Y: number, Kind: string, State: string, Frame: Frame, Visited: boolean }

local CELL_PIXELS = 22
local CELL_GAP = 4

local KIND_COLORS: { [string]: Color3 } = {
	Start = Kit.Theme.Accent,
	Combat = Kit.Theme.PanelLight,
	Treasure = Kit.Theme.Warn,
	Boss = Kit.Theme.Bad,
}

local DungeonController = {}

local player = Players.LocalPlayer
local map: Frame
local banner: TextLabel
local views: { [string]: CellView } = {}
local roomSize = Config.RoomSize
local origin = Config.Origin
local nextAttack = 0

local function key(x: number, y: number): string
	return `{x},{y}`
end

local function colorOf(view: CellView): Color3
	local base = KIND_COLORS[view.Kind] or Kit.Theme.PanelLight
	if view.State == "Cleared" then
		return base:Lerp(Kit.Theme.Good, 0.6)
	elseif view.State == "Active" then
		return base:Lerp(Color3.new(1, 1, 1), 0.3)
	end
	return base
end

local function rebuildMap(payload: { [string]: any })
	for _, view in views do
		view.Frame:Destroy()
	end
	table.clear(views)
	roomSize = payload.RoomSize
	origin = payload.Origin

	local minX, minY, maxX, maxY = 0, 0, 0, 0
	for _, cell in payload.Cells do
		minX, maxX = math.min(minX, cell.X), math.max(maxX, cell.X)
		minY, maxY = math.min(minY, cell.Y), math.max(maxY, cell.Y)
	end
	local step = CELL_PIXELS + CELL_GAP
	map.Size = UDim2.fromOffset((maxX - minX + 1) * step + 12, (maxY - minY + 1) * step + 12)

	for _, cell in payload.Cells do
		local frame = Kit.Create("Frame", {
			Position = UDim2.fromOffset(8 + (cell.X - minX) * step, 8 + (cell.Y - minY) * step),
			Size = UDim2.fromOffset(CELL_PIXELS, CELL_PIXELS),
			BorderSizePixel = 0,
			Visible = cell.Kind == "Start",
			Parent = map,
		}, Kit.Corner(4), Kit.Create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Enabled = false }))
		local view: CellView = {
			X = cell.X,
			Y = cell.Y,
			Kind = cell.Kind,
			State = cell.State,
			Frame = frame,
			Visited = cell.Kind == "Start",
		}
		frame.BackgroundColor3 = colorOf(view)
		views[key(cell.X, cell.Y)] = view
	end
end

local function showBanner(text: string, seconds: number)
	banner.Text = text
	banner.Visible = true
	Kit.Pop(banner, 0.15)
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

-- Schlagbewegung über den Schulter-Motor (wie im RPG-Beispiel), ohne Animations-Datei.
local function playSwing(character: Model)
	SoundController:PlayAt("Swing", character:GetPivot().Position)
	local upperArm = character:FindFirstChild("RightUpperArm")
	local motor = if upperArm then upperArm:FindFirstChild("RightShoulder") else nil
	if not motor or not motor:IsA("Motor6D") or motor:GetAttribute("Swinging") then
		return
	end
	motor:SetAttribute("Swinging", true)
	local rest = motor.C0
	local out = TweenService:Create(motor, TweenInfo.new(0.08), { C0 = rest * CFrame.Angles(math.rad(120), 0, 0) })
	out:Play()
	out.Completed:Once(function()
		local back = TweenService:Create(motor, TweenInfo.new(0.2), { C0 = rest })
		back:Play()
		back.Completed:Once(function()
			motor:SetAttribute("Swinging", nil)
		end)
	end)
end

local function build()
	local gui = Kit.ScreenGui("DungeonHud", 5)
	map = Kit.Panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	banner = Kit.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(700, 80),
		FontFace = Kit.Theme.FontBold,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
	Kit.Create("UIStroke", { Thickness = 3, Color = Kit.Theme.Background, Parent = banner })
end

function DungeonController:Init()
	build()
	Net.Listen("Dungeon.Layout", rebuildMap)
	Net.Listen("Dungeon.RoomState", function(x: number, y: number, state: string)
		local view = views[key(x, y)]
		if view then
			view.State = state
			view.Frame.BackgroundColor3 = colorOf(view)
		end
		if state == "Active" then
			showBanner("Die Gitter schließen sich!", 2)
		elseif state == "Cleared" then
			showBanner("Raum geschafft", 2)
			SoundController:Play("Success")
		end
	end)
	Net.Listen("Dungeon.Completed", function(elapsed: number, restartDelay: number)
		SoundController:Play("Win")
		showBanner(`Dungeon bezwungen in {Format.Time(elapsed)}!\nNächster Dungeon in {restartDelay}s`, restartDelay)
	end)
	Net.Listen("Dungeon.Swing", function(who: Player)
		if who.Character then
			playSwing(who.Character)
		end
	end)
end

function DungeonController:Start()
	Net.Send("Dungeon.RequestLayout")

	ContextActionService:BindAction("DungeonAttack", function(_name, state)
		if state == Enum.UserInputState.Begin and os.clock() >= nextAttack then
			nextAttack = os.clock() + Config.Attack.Cooldown
			Net.Send("Dungeon.Attack")
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("DungeonAttack", "Schlag")
	ContextActionService:SetPosition("DungeonAttack", UDim2.new(1, -150, 1, -130))

	-- Eigenen Raum auf der Karte markieren und betretene Räume aufdecken.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") then
			return
		end
		local offset = root.Position - origin
		local current = key(math.round(offset.X / roomSize), math.round(offset.Z / roomSize))
		for id, view in views do
			local here = id == current
			if here and not view.Visited then
				view.Visited = true
				view.Frame.Visible = true
			end
			local stroke = view.Frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Enabled = here
			end
		end
	end)
end

return DungeonController
