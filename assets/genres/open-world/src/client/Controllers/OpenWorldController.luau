--!strict
--[[
	OpenWorldController – Gebietsanzeige, Uhr, Rohstoffe und das Schnellreise-Menü.

	Steuerung: M oder Knopf "Karte" öffnet die Schnellreise.
]]

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.OpenWorld)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)
local DataController = require(script.Parent.DataController)

local OpenWorldController = {}

local player = Players.LocalPlayer
local regionLabel: TextLabel
local clockLabel: TextLabel
local resourceLabel: TextLabel
local banner: TextLabel
local travelWindow: Frame
local travelList: Frame

local function showBanner(text: string)
	banner.Text = text
	banner.TextTransparency = 0
	banner.Visible = true
	Kit.Pop(banner, 0.15)
	task.delay(2.5, function()
		if banner.Text == text then
			Kit.Tween(banner, 0.6, { TextTransparency = 1 })
		end
	end)
end

local function refreshResources(resources: any)
	local parts = {}
	if type(resources) == "table" then
		for resourceId, definition in Config.Resources do
			local amount = resources[resourceId]
			if type(amount) == "number" and amount > 0 then
				table.insert(parts, `{definition.DisplayName} {amount}`)
			end
		end
	end
	table.sort(parts)
	resourceLabel.Text = table.concat(parts, "   ")
end

local function refreshTravelList()
	for _, child in travelList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local unlocked = DataController:Get("World.Waypoints")
	local count = 0
	if type(unlocked) == "table" then
		-- Namen kommen von den geladenen Wegpunkten; nicht geladene zeigen ihre Id.
		local names: { [string]: string } = {}
		for _, waypoint in World.Tagged("Waypoint") do
			local id = waypoint:GetAttribute("WaypointId")
			if type(id) == "string" then
				names[id] = World.Attribute(waypoint, "DisplayName", id)
			end
		end
		for waypointId in unlocked do
			count += 1
			Kit.Button({
				Text = names[waypointId] or waypointId,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Kit.Theme.PanelLight,
				Parent = travelList,
			}, function()
				travelWindow.Visible = false
				Net.Send("World.FastTravel", waypointId)
			end)
		end
	end
	if count == 0 then
		Kit.Label({
			Text = "Noch keine Wegpunkte aktiviert. Suche in der Welt nach ihnen.",
			TextColor3 = Kit.Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 44),
			Parent = travelList,
		})
	end
end

local function toggleTravel()
	travelWindow.Visible = not travelWindow.Visible
	if travelWindow.Visible then
		refreshTravelList()
	end
end

local function build()
	local gui = Kit.ScreenGui("OpenWorldHud", 5)

	local panel = Kit.Panel({
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(250, 76),
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	regionLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -80, 0, 26),
		FontFace = Kit.Theme.FontBold,
		Parent = panel,
	})
	clockLabel = Kit.Label({
		Position = UDim2.new(1, -72, 0, 4),
		Size = UDim2.fromOffset(60, 26),
		FontFace = Kit.Theme.FontMono,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = panel,
	})
	resourceLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 40),
		TextSize = 14,
		TextColor3 = Kit.Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = panel,
	})

	banner = Kit.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.25),
		Size = UDim2.fromOffset(700, 70),
		FontFace = Kit.Theme.FontBold,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
	Kit.Create("UIStroke", { Thickness = 3, Color = Kit.Theme.Background, Parent = banner })

	Kit.Button({
		Text = "Karte",
		Position = UDim2.fromOffset(12, 144),
		Size = UDim2.fromOffset(100, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, toggleTravel)

	travelWindow = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Kit.Padding(12).Parent = travelWindow
	Kit.List(Enum.FillDirection.Vertical, 8).Parent = travelWindow
	Kit.Label({
		Text = "Schnellreise",
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 1,
		Parent = travelWindow,
	})
	travelList = Kit.Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = travelWindow,
	}, Kit.List(Enum.FillDirection.Vertical, 6))
	Kit.Button({
		Text = "Schließen",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Kit.Theme.Panel,
		LayoutOrder = 3,
		Parent = travelWindow,
	}, toggleTravel)
end

function OpenWorldController:Init()
	build()
	Net.Listen("World.Discovered", function(name: string)
		showBanner(`Entdeckt: {name}`)
		SoundController:Play("Success")
	end)
end

function OpenWorldController:Start()
	local function refreshRegion()
		local region = player:GetAttribute("Region")
		regionLabel.Text = if type(region) == "string" and region ~= "" then region else "Wildnis"
	end
	player:GetAttributeChangedSignal("Region"):Connect(refreshRegion)
	refreshRegion()

	DataController:Observe("World.Resources", refreshResources)
	DataController:Observe("World.Waypoints", function()
		if travelWindow.Visible then
			refreshTravelList()
		end
	end)

	ContextActionService:BindAction("WorldMap", function(_name, state)
		if state == Enum.UserInputState.Begin then
			toggleTravel()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)

	-- Die Uhr muss nicht jeden Frame neu geschrieben werden.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= 0.5 then
			elapsed = 0
			local hour = Lighting.ClockTime
			clockLabel.Text = string.format("%02d:%02d", math.floor(hour), math.floor(hour % 1 * 60))
		end
	end)
end

return OpenWorldController
