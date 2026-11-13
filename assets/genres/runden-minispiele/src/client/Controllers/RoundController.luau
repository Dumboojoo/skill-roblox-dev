--!strict
--[[
	RoundController – Rundenanzeige, Abstimmung, Ergebnis und Zuschauen.

	Die Anzeige liest nur die Workspace-Attribute, die der RoundService setzt
	(RoundPhase, RoundEndsAt, RoundMinigame, RoundAliveCount). Dadurch stimmt sie
	auch für Spieler, die mitten in einer Runde beitreten.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)
local SoundController = require(script.Parent.SoundController)

local RoundController = {}

local player = Players.LocalPlayer
local statusLabel: TextLabel
local votePanel: Frame
local voteButtons: { TextButton } = {}
local banner: TextLabel
local spectateButton: TextButton
local spectateIndex = 0

------------------------------------------------------------------------------
-- Zuschauen
------------------------------------------------------------------------------

local function stopSpectating()
	spectateIndex = 0
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
	spectateButton.Text = "Zuschauen"
end

local function spectateNext()
	local targets: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("RoundAlive") and other.Character then
			table.insert(targets, other)
		end
	end
	local camera = Workspace.CurrentCamera
	if #targets == 0 or not camera then
		stopSpectating()
		return
	end
	spectateIndex = spectateIndex % #targets + 1
	local target = targets[spectateIndex]
	local humanoid = if target.Character then target.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		camera.CameraSubject = humanoid
		spectateButton.Text = `Zuschauen: {target.DisplayName}`
	end
end

------------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------------

local function build()
	local gui = Kit.ScreenGui("RoundHud", 5)

	local top = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 44),
		BackgroundTransparency = 0.2,
		Parent = gui,
	})
	statusLabel = Kit.Label({
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		FontFace = Kit.Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = top,
	})

	votePanel = Kit.Panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Kit.Padding(10).Parent = votePanel
	Kit.List(Enum.FillDirection.Vertical, 8).Parent = votePanel

	banner = Kit.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 90),
		FontFace = Kit.Theme.FontBold,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Parent = gui,
	})
	Kit.Create("UIStroke", { Thickness = 3, Color = Kit.Theme.Background, Parent = banner })

	spectateButton = Kit.Button({
		Text = "Zuschauen",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(260, 44),
		BackgroundColor3 = Kit.Theme.PanelLight,
		Visible = false,
		Parent = gui,
	}, spectateNext)
end

local function showVote(list: { { Name: string, Description: string } })
	for _, button in voteButtons do
		button:Destroy()
	end
	table.clear(voteButtons)
	for index, option in list do
		local button
		button = Kit.Button({
			Text = `{option.Name}\n{option.Description}`,
			TextSize = 15,
			Size = UDim2.new(1, 0, 0, 60),
			BackgroundColor3 = Kit.Theme.PanelLight,
			LayoutOrder = index,
			Parent = votePanel,
		}, function()
			Net.Send("Round.Vote", index)
			-- Eigene Wahl hervorheben.
			for _, other in voteButtons do
				other.BackgroundColor3 = Kit.Theme.PanelLight
			end
			button.BackgroundColor3 = Kit.Theme.Accent
		end)
		table.insert(voteButtons, button)
	end
end

local function refresh()
	local phase = Workspace:GetAttribute("RoundPhase")
	local endsAt = Workspace:GetAttribute("RoundEndsAt")
	local remaining = if type(endsAt) == "number" and endsAt > 0
		then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
		else 0

	if phase == "Intermission" then
		statusLabel.Text = `Nächste Runde in {remaining}s`
	elseif phase == "Voting" then
		statusLabel.Text = `Abstimmung: {remaining}s`
	elseif phase == "Playing" then
		local name = Workspace:GetAttribute("RoundMinigame") or ""
		local count = Workspace:GetAttribute("RoundAliveCount") or 0
		statusLabel.Text = `{name}  ·  {remaining}s  ·  {count} dabei`
	elseif phase == "Results" then
		statusLabel.Text = "Ergebnis"
	else
		statusLabel.Text = "Warte auf Spieler …"
	end

	votePanel.Visible = phase == "Voting"
	local canSpectate = phase == "Playing" and not player:GetAttribute("RoundAlive")
	spectateButton.Visible = canSpectate
	if not canSpectate and spectateIndex > 0 then
		stopSpectating()
	end
end

------------------------------------------------------------------------------

function RoundController:Init()
	build()
	Net.Listen("Round.VoteOptions", showVote)
	Net.Listen("Round.Results", function(names: { string }, minigame: string)
		banner.Text = if #names == 0
			then `{minigame}\nNiemand hat gewonnen`
			else `{minigame}\nSieger: {table.concat(names, ", ")}`
		banner.Visible = true
		Kit.Pop(banner, 0.2)
		SoundController:Play("Win")
		task.delay(5, function()
			banner.Visible = false
		end)
	end)
end

function RoundController:Start()
	-- Zweimal pro Sekunde reicht für einen Sekunden-Countdown.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= 0.25 then
			elapsed = 0
			refresh()
		end
	end)
	refresh()
end

return RoundController
