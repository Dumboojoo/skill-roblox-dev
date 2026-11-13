--!strict
--[[
	NotificationController – kurze Meldungen oben in der Bildschirmmitte.

	Client:  NotificationController:Notify("Checkpoint erreicht!", "Success")
	Server:  Net.Fire("Notify", player, "Nicht genug Münzen", "Error")
	         Net.FireAll("Notify", "Runde beginnt!", "Info")

	Arten: "Info", "Success", "Error", "Announcement" (größer, bleibt länger).
	Jede Aktion des Spielers sollte eine sichtbare Rückmeldung haben; für alles
	ohne eigene Anzeige ist das hier der einfachste Weg.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

export type Kind = "Info" | "Success" | "Error" | "Announcement"

local MAX_VISIBLE = 4
local DEFAULT_DURATION = 3
local ANNOUNCEMENT_DURATION = 7

local NotificationController = {}

local container: Frame? = nil
local visible: { Frame } = {}

local function colorFor(kind: Kind): Color3
	if kind == "Success" then
		return Kit.Theme.Good
	elseif kind == "Error" then
		return Kit.Theme.Bad
	elseif kind == "Announcement" then
		return Kit.Theme.Warn
	end
	return Kit.Theme.Accent
end

local function dismiss(toast: Frame)
	local index = table.find(visible, toast)
	if not index then
		return
	end
	table.remove(visible, index)
	local tween = Kit.Tween(toast, 0.2, { BackgroundTransparency = 1 })
	for _, child in toast:GetDescendants() do
		if child:IsA("TextLabel") then
			Kit.Tween(child, 0.2, { TextTransparency = 1 })
		elseif child:IsA("UIStroke") then
			Kit.Tween(child, 0.2, { Transparency = 1 })
		elseif child:IsA("Frame") then
			Kit.Tween(child, 0.2, { BackgroundTransparency = 1 })
		end
	end
	tween.Completed:Once(function()
		toast:Destroy()
	end)
end

function NotificationController:Notify(text: string, kind: Kind?, duration: number?)
	local parent = container
	if not parent then
		return
	end
	local actualKind: Kind = kind or "Info"
	local isAnnouncement = actualKind == "Announcement"

	local toast = Kit.Panel({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Kit.Theme.Background,
		BackgroundTransparency = 0.1,
	})
	Kit.Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = colorFor(actualKind),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 4, 1, 0),
		Parent = toast,
	}, Kit.Corner(2))
	Kit.Label({
		Text = text,
		TextSize = if isAnnouncement then 20 else Kit.Theme.TextSize,
		FontFace = if isAnnouncement then Kit.Theme.FontBold else Kit.Theme.Font,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = toast,
	})
	local padding = Kit.Padding(10)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.Parent = toast:FindFirstChildOfClass("TextLabel")

	toast.Parent = parent
	table.insert(visible, toast)
	Kit.Pop(toast, 0.06)
	-- Jede Meldung hat ihren Ton (Config/Sounds: Notify, Success, Error, Announcement).
	SoundController:Play(if actualKind == "Info" then "Notify" else actualKind)

	while #visible > MAX_VISIBLE do
		dismiss(visible[1])
	end

	local lifetime = duration or (if isAnnouncement then ANNOUNCEMENT_DURATION else DEFAULT_DURATION)
	task.delay(lifetime, dismiss, toast)
end

function NotificationController:Init()
	local gui = Kit.ScreenGui("Notifications", 50)
	container = Kit.Create("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, Kit.List(Enum.FillDirection.Vertical, 6))

	Net.Listen("Notify", function(text: any, kind: any, duration: any)
		if type(text) == "string" then
			NotificationController:Notify(
				text,
				if type(kind) == "string" then kind :: Kind else nil,
				if type(duration) == "number" then duration else nil
			)
		end
	end)
end

return NotificationController
