--!strict
--[[
	ShopController – das Shop-Fenster: tägliche Belohnung, Pässe, Robux-Produkte.

	Grundsätze, die hier eingebaut sind:
	  - Der Shop öffnet sich NUR, wenn der Spieler auf "Shop" drückt. Kein Aufpoppen
	    beim Beitritt, beim Tod oder nach einer Runde.
	  - Die Gratis-Belohnung steht ganz oben, Kaufbares darunter.
	  - Preise kommen live von Roblox (stimmen also immer mit dem Creator Hub überein).
	  - Gekaufte Pässe zeigen "Gehört dir" statt eines Kaufknopfs.

	Andere Controller dürfen den Shop gezielt öffnen, wenn der Spieler selbst danach
	fragt (z. B. Klick auf ein Schloss-Symbol): ShopController:Open().
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Daily = require(Shared.Shop.Daily)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)

local ShopController = {}

local player = Players.LocalPlayer
local window: Frame
local content: ScrollingFrame
local prices: { [number]: string } = {}

-- Preis einmal bei Roblox erfragen und merken.
local function priceText(id: number, infoType: Enum.InfoType, onLoaded: () -> ()): string
	if id == 0 then
		return "Bald"
	end
	local known = prices[id]
	if known then
		return known
	end
	prices[id] = "…"
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		local price = if ok and type(info) == "table" then info.PriceInRobux else nil
		prices[id] = if type(price) == "number" then `{price} R$` else "Kaufen"
		onLoaded()
	end)
	return "…"
end

local refresh: () -> ()

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
	description: string,
	buttonText: string,
	color: Color3,
	order: number,
	onClick: (() -> ())?
)
	local frame = Kit.Panel({
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = Kit.Theme.PanelLight,
		LayoutOrder = order,
		Parent = content,
	})
	Kit.Padding(8).Parent = frame
	Kit.Label({ Text = title, FontFace = Kit.Theme.FontBold, Size = UDim2.new(1, -150, 0, 22), Parent = frame })
	Kit.Label({
		Text = description,
		TextSize = 13,
		TextColor3 = Kit.Theme.TextDim,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -150, 1, -24),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
	Kit.Button({
		Text = buttonText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(136, 44),
		BackgroundColor3 = color,
		Parent = frame,
	}, onClick)
end

function refresh()
	if not window.Visible then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Tägliche Belohnung.
	local shop = DataController:Get("Shop")
	if type(shop) == "table" then
		local rewards = Products.Daily.Rewards
		local now = os.time()
		local canClaim, streak = Daily.Status(shop.LastDailyDay, shop.Streak, Daily.DayNumber(now), #rewards)
		header("Täglich gratis", nextOrder())
		if canClaim then
			row(
				`Tag {streak} von {#rewards}`,
				`Heute: +{rewards[streak]}. Komm morgen wieder für mehr.`,
				"Abholen",
				Kit.Theme.Good,
				nextOrder(),
				function()
					Net.Send("Shop.ClaimDaily")
				end
			)
		else
			local wait = Format.Time(Daily.SecondsUntilNextDay(now))
			row(
				`Tag {streak} von {#rewards} abgeholt`,
				`Nächste Belohnung in {wait} Stunden.`,
				"Abgeholt",
				Kit.Theme.Panel,
				nextOrder(),
				nil
			)
		end
	end

	header("Pässe (einmalig)", nextOrder())
	for passKey, pass in Products.GamePasses do
		if player:GetAttribute("Pass_" .. passKey) then
			row(pass.DisplayName, pass.Description, "Gehört dir", Kit.Theme.Panel, nextOrder(), nil)
		else
			local price = priceText(pass.Id, Enum.InfoType.GamePass, refresh)
			row(pass.DisplayName, pass.Description, price, Kit.Theme.Accent, nextOrder(), function()
				Net.Send("Shop.Prompt", "Pass", passKey)
			end)
		end
	end

	header("Extras", nextOrder())
	for productKey, product in Products.Products do
		local price = priceText(product.Id, Enum.InfoType.Product, refresh)
		row(product.DisplayName, product.Description, price, Kit.Theme.Accent, nextOrder(), function()
			Net.Send("Shop.Prompt", "Product", productKey)
		end)
	end
end

local function build()
	local gui = Kit.ScreenGui("Shop", 20)

	Kit.Button({
		Text = "Shop",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 52),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Parent = gui,
	}, function()
		window.Visible = not window.Visible
		refresh()
	end)

	window = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 440),
		Visible = false,
		Parent = gui,
	})
	Kit.Label({
		Text = "Shop",
		FontFace = Kit.Theme.FontBold,
		TextSize = 20,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Parent = window,
	})
	Kit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Kit.Theme.Bad,
		Parent = window,
	}, function()
		window.Visible = false
	end)
	content = Kit.Create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 1, -68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	}, Kit.List(Enum.FillDirection.Vertical, 6))
end

function ShopController:Open()
	window.Visible = true
	refresh()
end

function ShopController:Init()
	build()
end

function ShopController:Start()
	DataController:Observe("Shop", refresh)
	-- Nach einem Pass-Kauf setzt der Server das Attribut; die Zeile wechselt sofort auf "Gehört dir".
	for passKey in Products.GamePasses do
		player:GetAttributeChangedSignal("Pass_" .. passKey):Connect(refresh)
	end
end

return ShopController
