--!strict
--[[
	TycoonController – Geldanzeige und Stand des eigenen Sammlers.

	Das eigene Grundstück erkennt der Client am Attribut OwnerId, das der Server am
	Grundstück-Model setzt. Der Sammler-Stand steht dort als Attribut Bank.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local World = require(Shared.Util.World)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)

local TycoonController = {}

local player = Players.LocalPlayer
local coinLabel: TextLabel
local bankLabel: TextLabel

local function refreshBank()
	for _, plot in World.Tagged("TycoonPlot") do
		if plot:GetAttribute("OwnerId") == player.UserId then
			local bank = plot:GetAttribute("Bank")
			bankLabel.Text = `Im Sammler: {Format.Number(if type(bank) == "number" then bank else 0)}`
			return
		end
	end
	bankLabel.Text = "Berühre ein freies Grundstück, um zu starten"
end

function TycoonController:Init()
	local gui = Kit.ScreenGui("TycoonHud", 5)
	local panel = Kit.Panel({
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.fromOffset(300, 70),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	coinLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 32),
		FontFace = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Good,
		TextSize = 24,
		Parent = panel,
	})
	bankLabel = Kit.Label({
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 22),
		TextColor3 = Kit.Theme.TextDim,
		TextSize = 14,
		Parent = panel,
	})

	Net.Listen("Tycoon.Collected", function(amount: number)
		NotificationController:Notify(`+{Format.Number(amount)}`, "Success", 1.5)
		Kit.Pop(coinLabel)
	end)
end

function TycoonController:Start()
	DataController:Observe("Tycoon.Coins", function(coins: any)
		coinLabel.Text = `$ {Format.Number(if type(coins) == "number" then coins else 0)}`
	end)

	World.Observe("TycoonPlot", function(plot)
		local bankConnection = plot:GetAttributeChangedSignal("Bank"):Connect(refreshBank)
		local ownerConnection = plot:GetAttributeChangedSignal("OwnerId"):Connect(refreshBank)
		refreshBank()
		return function()
			bankConnection:Disconnect()
			ownerConnection:Disconnect()
		end
	end)
	refreshBank()
end

return TycoonController
