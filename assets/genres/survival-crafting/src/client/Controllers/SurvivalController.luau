--!strict
--[[
	SurvivalController – Bedürfnis-Balken, Rucksack mit Rezepten und der Baumodus.

	Baumodus: Bauteil im Menü wählen -> eine Vorschau folgt Maus/Finger und rastet
	am Raster ein -> Klick/Tippen baut, R dreht, X oder Rechtsklick bricht ab.
	Ob wirklich gebaut wird, entscheidet der Server; die Vorschau zeigt mit Grün
	und Rot nur an, ob Material und Reichweite voraussichtlich passen.

	Steuerung: Tab oder Knopf "Rucksack" öffnet das Menü.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Survival)
local Crafting = require(Shared.Survival.Crafting)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)

local SurvivalController = {}

local player = Players.LocalPlayer

local hungerFill: Frame
local thirstFill: Frame
local window: Frame
local content: ScrollingFrame

local buildingId: string? = nil
local buildRotation = 0
local ghost: Part? = nil
local ghostPosition: Vector3? = nil

local function items(): { [string]: number }
	local data = DataController:Get("Survival.Items")
	return if type(data) == "table" then data else {}
end

local function costText(cost: { [string]: number }): string
	local parts = {}
	for itemId, amount in cost do
		local item = Config.Items[itemId]
		table.insert(parts, `{amount} {if item then item.DisplayName else itemId}`)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

------------------------------------------------------------------------------
-- Baumodus
------------------------------------------------------------------------------

local function stopBuilding()
	buildingId = nil
	ghostPosition = nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
end

local function startBuilding(buildableId: string)
	stopBuilding()
	local buildable = Config.Buildables[buildableId]
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = buildable.Size
	part.Material = Enum.Material.ForceField
	part.Parent = Workspace.CurrentCamera
	ghost = part
	buildingId = buildableId
	window.Visible = false
end

local function updateGhost()
	local part = ghost
	local buildableId = buildingId
	local camera = Workspace.CurrentCamera
	local character = player.Character
	if not part or not buildableId or not camera or not character then
		return
	end
	local buildable = Config.Buildables[buildableId]
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not result then
		part.Transparency = 1
		ghostPosition = nil
		return
	end

	-- Dieselbe Einrast-Regel wie auf dem Server, damit die Vorschau stimmt.
	local grid = Config.Grid
	local snapped = Vector3.new(
		Crafting.Snap(result.Position.X, grid),
		Crafting.Snap(result.Position.Y, grid / 4) + buildable.Size.Y / 2,
		Crafting.Snap(result.Position.Z, grid)
	)
	ghostPosition = result.Position
	part.Transparency = 0
	part.CFrame = CFrame.new(snapped) * CFrame.Angles(0, math.rad(90) * buildRotation, 0)

	local root = character:FindFirstChild("HumanoidRootPart")
	local inRange = root ~= nil and root:IsA("BasePart") and (snapped - root.Position).Magnitude <= Config.BuildRange
	part.Color = if inRange and Crafting.CanAfford(items(), buildable.Cost) then Kit.Theme.Good else Kit.Theme.Bad
end

------------------------------------------------------------------------------
-- Menü
------------------------------------------------------------------------------

local function header(text: string, order: number)
	Kit.Label({
		Text = text,
		FontFace = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Accent,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = order,
		Parent = content,
	})
end

local function row(
	title: string,
	detail: string,
	buttonText: string?,
	enabled: boolean,
	order: number,
	onClick: (() -> ())?
)
	local frame = Kit.Panel({
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Kit.Theme.PanelLight,
		LayoutOrder = order,
		Parent = content,
	})
	Kit.Padding(6).Parent = frame
	Kit.Label({ Text = title, FontFace = Kit.Theme.FontBold, Size = UDim2.new(1, -140, 0, 20), Parent = frame })
	Kit.Label({
		Text = detail,
		TextSize = 13,
		TextColor3 = Kit.Theme.TextDim,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, -140, 0, 20),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	if buttonText and onClick then
		Kit.Button({
			Text = buttonText,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(126, 40),
			BackgroundColor3 = if enabled then Kit.Theme.Accent else Kit.Theme.Panel,
			Parent = frame,
		}, function()
			if enabled then
				onClick()
			end
		end)
	end
end

local function refreshWindow()
	if not window.Visible then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local owned = items()
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	header("Rucksack", nextOrder())
	local ids = {}
	for itemId in owned do
		table.insert(ids, itemId)
	end
	table.sort(ids)
	for _, itemId in ids do
		local item = Config.Items[itemId]
		if item then
			local edible = item.Food ~= nil or item.Water ~= nil
			row(
				`{item.DisplayName}  x{owned[itemId]}`,
				if edible then "Essbar" else "Material",
				if edible then "Essen" else nil,
				true,
				nextOrder(),
				function()
					Net.Send("Survival.Eat", itemId)
				end
			)
		end
	end
	if #ids == 0 then
		row("Leer", "Sammle Holz, Stein und Beeren in der Welt.", nil, false, nextOrder(), nil)
	end

	header("Herstellen", nextOrder())
	for recipeId, recipe in Config.Recipes do
		local station = if recipe.Station then Config.Buildables[recipe.Station] else nil
		local detail = costText(recipe.Inputs) .. (if station then `  ·  an: {station.DisplayName}` else "")
		row(recipe.DisplayName, detail, "Herstellen", Crafting.CanAfford(owned, recipe.Inputs), nextOrder(), function()
			Net.Send("Survival.Craft", recipeId)
		end)
	end

	header("Bauen", nextOrder())
	for buildableId, buildable in Config.Buildables do
		row(
			buildable.DisplayName,
			costText(buildable.Cost),
			"Platzieren",
			Crafting.CanAfford(owned, buildable.Cost),
			nextOrder(),
			function()
				startBuilding(buildableId)
			end
		)
	end
end

local function toggleWindow()
	window.Visible = not window.Visible
	refreshWindow()
end

local function bar(parent: Instance, y: number, color: Color3, label: string): Frame
	Kit.Label({
		Text = label,
		TextSize = 13,
		Position = UDim2.new(0, 16, 1, y - 4),
		Size = UDim2.fromOffset(60, 16),
		Parent = parent,
	})
	local back = Kit.Create("Frame", {
		Position = UDim2.new(0, 76, 1, y),
		Size = UDim2.fromOffset(170, 10),
		BackgroundColor3 = Kit.Theme.Background,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = parent,
	}, Kit.Corner(5))
	return Kit.Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = back,
	}, Kit.Corner(5))
end

local function build()
	local gui = Kit.ScreenGui("SurvivalHud", 5)
	hungerFill = bar(gui, -44, Kit.Theme.Warn, "Hunger")
	thirstFill = bar(gui, -26, Kit.Theme.Accent, "Durst")

	Kit.Button({
		Text = "Rucksack",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -64),
		Size = UDim2.fromOffset(130, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, toggleWindow)

	window = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 440),
		Visible = false,
		Parent = gui,
	})
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		ZIndex = 2,
		Parent = window,
	}, toggleWindow)
	content = Kit.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -70, 1, -20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	}, Kit.List(Enum.FillDirection.Vertical, 5))
end

------------------------------------------------------------------------------

function SurvivalController:Init()
	build()
end

function SurvivalController:Start()
	local max = Config.Needs.Max
	DataController:Observe("Survival.Hunger", function(value: any)
		hungerFill.Size = UDim2.fromScale(math.clamp((if type(value) == "number" then value else max) / max, 0, 1), 1)
	end)
	DataController:Observe("Survival.Thirst", function(value: any)
		thirstFill.Size = UDim2.fromScale(math.clamp((if type(value) == "number" then value else max) / max, 0, 1), 1)
	end)
	DataController:Observe("Survival.Items", refreshWindow)

	ContextActionService:BindAction("SurvivalMenu", function(_name, state)
		if state == Enum.UserInputState.Begin then
			toggleWindow()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Tab)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if not buildingId or gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			buildRotation = (buildRotation + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.X or input.UserInputType == Enum.UserInputType.MouseButton2 then
			stopBuilding()
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local position = ghostPosition
			if position then
				Net.Send("Survival.Build", buildingId, position, buildRotation)
			end
		end
	end)

	RunService.RenderStepped:Connect(updateGhost)
end

return SurvivalController
