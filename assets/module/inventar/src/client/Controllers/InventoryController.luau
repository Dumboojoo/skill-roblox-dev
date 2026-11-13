--!strict
--[[
	InventoryController – das Inventar-Fenster.

	Aufbau wie in bekannten Roblox-Rollenspielen:
	  oben    Kategorie-Reiter ("Alle" + Categories) und Suchfeld
	  links   Raster aus quadratischen Kacheln; Rahmenfarbe = Seltenheit,
	          Zahl unten rechts = Stapelgröße, heller Rand = ausgerüstet
	  rechts  Detailfeld zur angeklickten Kachel mit Werten und Knöpfen
	          (Ausrüsten/Ablegen, Benutzen, Wegwerfen)

	Kacheln zeigen ohne Bilder die Anfangsbuchstaben des Namens. Für Symbole ein
	Feld `Icon = "rbxassetid://…"` in Config/Items ergänzen und in `createTile`
	ein ImageLabel statt des Kürzels anlegen.

	Das Fenster baut sich bei jeder Änderung des Inventars neu auf. Das ist
	einfach und bei einigen Dutzend Kacheln schnell genug.

	Steuerung: Taste aus Items.OpenKey (Standard B) oder Knopf "Inventar".
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)

type Slot = { Uid: number, Id: string, Count: number }

local TILE = 68
local ALL = "Alle"

local InventoryController = {}

local window: Frame
local grid: ScrollingFrame
local tabBar: Frame
local searchBox: TextBox
local capacityLabel: TextLabel
local detail: Frame

local category = ALL
local selectedUid: number? = nil

------------------------------------------------------------------------------
-- Daten
------------------------------------------------------------------------------

local function inventory(): { Slots: { Slot }, Equipped: { [string]: number } }?
	local data = DataController:Get("Inventory")
	return if type(data) == "table" then data else nil
end

local function isEquipped(equipped: { [string]: number }, uid: number): boolean
	for _, equippedUid in equipped do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

-- Gefiltert nach Reiter und Suche; sortiert nach Seltenheit (beste zuerst), dann Name.
local function visibleSlots(slots: { Slot }): { Slot }
	local query = string.lower(searchBox.Text)
	local list: { Slot } = {}
	for _, slot in slots do
		local item = Items.List[slot.Id]
		if item and (category == ALL or item.Category == category) then
			if query == "" or string.find(string.lower(item.DisplayName), query, 1, true) then
				table.insert(list, slot)
			end
		end
	end
	table.sort(list, function(a, b)
		local first, second = Items.List[a.Id], Items.List[b.Id]
		local firstOrder, secondOrder = Items.Rarities[first.Rarity].Order, Items.Rarities[second.Rarity].Order
		if firstOrder ~= secondOrder then
			return firstOrder > secondOrder
		elseif first.DisplayName ~= second.DisplayName then
			return first.DisplayName < second.DisplayName
		end
		return a.Uid < b.Uid
	end)
	return list
end

------------------------------------------------------------------------------
-- Darstellung
------------------------------------------------------------------------------

local refresh: () -> ()

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function createTile(slot: Slot, item: Items.Item, equipped: boolean)
	local rarity = Items.Rarities[item.Rarity]
	local tile = Kit.Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = rarity.Color:Lerp(Kit.Theme.Background, 0.78),
		BorderSizePixel = 0,
		Parent = grid,
	}, Kit.Corner(6), Kit.Stroke(if equipped then Color3.new(1, 1, 1) else rarity.Color, if equipped then 3 else 2))

	-- Kürzel aus den ersten zwei Buchstaben, bis es echte Symbole gibt.
	Kit.Label({
		Text = string.upper(string.sub(item.DisplayName, 1, 2)),
		Size = UDim2.fromScale(1, 1),
		FontFace = Kit.Theme.FontBold,
		TextSize = 22,
		TextColor3 = rarity.Color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = tile,
	})
	if slot.Count > 1 then
		Kit.Label({
			Text = tostring(slot.Count),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -5, 1, -3),
			Size = UDim2.fromOffset(40, 16),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = tile,
		})
	end
	if selectedUid == slot.Uid then
		Kit.Create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Parent = tile,
		}, Kit.Corner(6))
	end
	tile.Activated:Connect(function()
		selectedUid = slot.Uid
		refresh()
	end)
end

local function showDetail(slot: Slot?, equipped: boolean)
	clear(detail)
	local item = if slot then Items.List[slot.Id] else nil
	if not slot or not item then
		Kit.Label({
			Text = "Wähle einen Gegenstand aus.",
			TextColor3 = Kit.Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = detail,
		})
		return
	end
	local rarity = Items.Rarities[item.Rarity]

	Kit.Label({
		Text = item.DisplayName,
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
		Parent = detail,
	})
	Kit.Label({
		Text = `{rarity.DisplayName}  ·  {item.Category}`,
		TextColor3 = rarity.Color,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
		Parent = detail,
	})
	Kit.Label({
		Text = item.Description,
		TextColor3 = Kit.Theme.TextDim,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = detail,
	})
	if item.Stats then
		local lines = {}
		for name, value in item.Stats do
			table.insert(lines, `{name}: {value}`)
		end
		table.sort(lines)
		Kit.Label({
			Text = table.concat(lines, "\n"),
			TextSize = 14,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 4,
			Parent = detail,
		})
	end

	if item.EquipSlot then
		Kit.Button({
			Text = if equipped then "Ablegen" else "Ausrüsten",
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = if equipped then Kit.Theme.PanelLight else Kit.Theme.Good,
			LayoutOrder = 10,
			Parent = detail,
		}, function()
			Net.Send("Inventory.Equip", slot.Uid)
		end)
	end
	if item.Usable then
		Kit.Button({
			Text = "Benutzen",
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = 11,
			Parent = detail,
		}, function()
			Net.Send("Inventory.Use", slot.Uid)
		end)
	end
	-- Wegwerfen braucht zwei Klicks, damit nichts aus Versehen verschwindet.
	local armed = false
	local discard
	discard = Kit.Button({
		Text = "Wegwerfen",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Kit.Theme.Panel,
		LayoutOrder = 12,
		Parent = detail,
	}, function()
		if armed then
			Net.Send("Inventory.Discard", slot.Uid, slot.Count)
		else
			armed = true
			discard.Text = "Wirklich wegwerfen?"
			discard.BackgroundColor3 = Kit.Theme.Bad
		end
	end)
end

local function buildTabs()
	clear(tabBar)
	local names = { ALL }
	table.move(Items.Categories, 1, #Items.Categories, 2, names)
	for index, name in names do
		Kit.Button({
			Text = name,
			TextSize = 14,
			Size = UDim2.fromOffset(104, 36),
			BackgroundColor3 = if name == category then Kit.Theme.Accent else Kit.Theme.PanelLight,
			LayoutOrder = index,
			Parent = tabBar,
		}, function()
			category = name
			buildTabs()
			refresh()
		end)
	end
end

function refresh()
	if not window.Visible then
		return
	end
	local data = inventory()
	clear(grid)
	if not data then
		return
	end
	capacityLabel.Text = `{#data.Slots} / {Items.Capacity}`

	local selected: Slot? = nil
	for _, slot in visibleSlots(data.Slots) do
		local item = Items.List[slot.Id]
		createTile(slot, item, isEquipped(data.Equipped, slot.Uid))
		if slot.Uid == selectedUid then
			selected = slot
		end
	end
	if not selected then
		selectedUid = nil
	end
	showDetail(selected, selected ~= nil and isEquipped(data.Equipped, selected.Uid))
end

local function toggle()
	window.Visible = not window.Visible
	refresh()
end

local function build()
	local gui = Kit.ScreenGui("Inventory", 20)

	Kit.Button({
		Text = "Inventar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, toggle)

	window = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 460),
		Visible = false,
		Parent = gui,
	})

	tabBar = Kit.Create("Frame", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -330, 0, 36),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = window,
	}, Kit.List(Enum.FillDirection.Horizontal, 6))

	searchBox = Kit.Create("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -64, 0, 12),
		Size = UDim2.fromOffset(180, 36),
		BackgroundColor3 = Kit.Theme.Background,
		BorderSizePixel = 0,
		FontFace = Kit.Theme.Font,
		TextSize = 15,
		TextColor3 = Kit.Theme.Text,
		PlaceholderText = "Suchen …",
		PlaceholderColor3 = Kit.Theme.TextDim,
		ClearTextOnFocus = false,
		Text = "",
		Parent = window,
	}, Kit.Corner(6))
	capacityLabel = Kit.Label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -252, 0, 12),
		Size = UDim2.fromOffset(70, 36),
		TextColor3 = Kit.Theme.TextDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = window,
	})
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		Parent = window,
	}, toggle)

	grid = Kit.Create(
		"ScrollingFrame",
		{
			Position = UDim2.fromOffset(12, 62),
			Size = UDim2.new(1, -264, 1, -74),
			BackgroundColor3 = Kit.Theme.Background,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = window,
		},
		Kit.Corner(6),
		Kit.Padding(8),
		Kit.Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	)

	detail = Kit.Panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 62),
		Size = UDim2.new(0, 230, 1, -74),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = window,
	})
	Kit.Padding(10).Parent = detail
	Kit.List(Enum.FillDirection.Vertical, 6).Parent = detail

	buildTabs()
end

------------------------------------------------------------------------------

function InventoryController:Init()
	build()
end

function InventoryController:Start()
	DataController:Observe("Inventory", refresh)
	searchBox:GetPropertyChangedSignal("Text"):Connect(refresh)

	ContextActionService:BindAction("InventoryToggle", function(_name, state)
		if state == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Items.OpenKey)
end

-- Für andere Controller (z. B. Händler): Inventar öffnen oder schließen.
function InventoryController:SetOpen(open: boolean)
	if window.Visible ~= open then
		toggle()
	end
end

return InventoryController
