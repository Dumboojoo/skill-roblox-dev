--!strict
--[[
	ConsoleController – die Admin-Befehlszeile (Taste T, wie der Chat in Minecraft).

	  T            öffnen (nicht, während man in ein anderes Textfeld tippt)
	  Enter        Befehl ausführen und schließen
	  Tab          Vorschlag übernehmen / durch Vorschläge blättern
	  Pfeil hoch/runter   frühere Befehle
	  Klick daneben / Esc  schließen

	Für Nicht-Admins entsteht gar keine Oberfläche. Die Sicherheit liegt aber
	allein beim Server (AdminService prüft jeden Befehl), nicht hier.

	Der Befehl "clear" leert nur die Anzeige und läuft rein auf dem Client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local CommandParser = require(Shared.Util.CommandParser)
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Parent.UI.Kit)

type CommandInfo = CommandParser.CommandInfo
type Suggestion = CommandParser.Suggestion

local WIDTH = 640
local OUTPUT_HEIGHT = 230
local INPUT_HEIGHT = 34
local MAX_LINES = 80
local MAX_HISTORY = 50
local MAX_SUGGESTIONS = 6
local OUTPUT_LINGER = 6 -- Sekunden, die die Ausgabe nach dem Schließen sichtbar bleibt

local ConsoleController = {}

local commands: { CommandInfo } = {}
local history: { string } = {}
local historyIndex = 0
local isOpen = false
local openedAt = 0
local lingerToken = 0

-- Zeitfenster nach dem Öffnen, in dem der Buchstabe der Öffnen-Taste verworfen wird.
local OPEN_KEY_GRACE = 0.2

local root: Frame
local output: ScrollingFrame
local input: TextBox
local hint: TextLabel
local suggestionFrame: Frame

local suggestions: { Suggestion } = {}
local cycleIndex = 0
local lastCompletion: string? = nil

------------------------------------------------------------------------------
-- Ausgabe
------------------------------------------------------------------------------

local function print_(text: string, color: Color3?)
	for _, line in string.split(text, "\n") do
		Kit.Label({
			Text = line,
			FontFace = Kit.Theme.FontMono,
			TextSize = 15,
			TextColor3 = color or Kit.Theme.Text,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = output,
		})
	end
	local lines = {}
	for _, child in output:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	for index = 1, #lines - MAX_LINES do
		lines[index]:Destroy()
	end
	-- Nach dem Layout ganz nach unten rollen.
	task.defer(function()
		output.CanvasPosition = Vector2.new(0, 1e6)
	end)
end

local function showOutputFor(seconds: number)
	lingerToken += 1
	local token = lingerToken
	output.Visible = true
	task.delay(seconds, function()
		if token == lingerToken and not isOpen then
			output.Visible = false
		end
	end)
end

------------------------------------------------------------------------------
-- Vorschläge
------------------------------------------------------------------------------

local function playerNames(): { string }
	local names = {}
	for _, player in Players:GetPlayers() do
		table.insert(names, player.Name)
	end
	return names
end

local function renderSuggestions()
	for _, child in suggestionFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local shown = math.min(#suggestions, MAX_SUGGESTIONS)
	suggestionFrame.Visible = shown > 0
	for index = 1, shown do
		local selected = index == cycleIndex
		Kit.Label({
			Text = " " .. suggestions[index].Label,
			FontFace = Kit.Theme.FontMono,
			TextSize = 15,
			TextColor3 = if selected then Kit.Theme.Background else Kit.Theme.TextDim,
			BackgroundColor3 = Kit.Theme.Accent,
			BackgroundTransparency = if selected then 0 else 1,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = index,
			Parent = suggestionFrame,
		})
	end
end

local function updateHint(text: string)
	local tokens = CommandParser.Tokenize(CommandParser.StripSlash(text))
	local command = if tokens[1] then CommandParser.FindCommand(commands, tokens[1]) else nil
	if command then
		hint.Text = `{CommandParser.Usage(command)}  –  {command.Description}`
	else
		hint.Text = 'Tab: vervollständigen   Enter: ausführen   "help": alle Befehle'
	end
end

local function refreshSuggestions()
	suggestions = CommandParser.Suggest(input.Text, commands, { Players = playerNames() })
	cycleIndex = 0
	renderSuggestions()
	updateHint(input.Text)
end

local function applyNextSuggestion()
	if #suggestions == 0 then
		return
	end
	local limit = math.min(#suggestions, MAX_SUGGESTIONS)
	cycleIndex = cycleIndex % limit + 1
	local completion = suggestions[cycleIndex].Completion
	lastCompletion = completion
	input.Text = completion
	input.CursorPosition = #completion + 1
	renderSuggestions()
	updateHint(completion)
end

------------------------------------------------------------------------------
-- Öffnen, Schließen, Ausführen
------------------------------------------------------------------------------

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	root.Visible = false
	suggestionFrame.Visible = false
	if input:IsFocused() then
		input:ReleaseFocus(false)
	end
	showOutputFor(OUTPUT_LINGER)
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	openedAt = os.clock()
	historyIndex = 0
	root.Visible = true
	output.Visible = true
	-- Einen Frame warten: Sonst landet das "t" des Tastendrucks im Textfeld.
	RunService.RenderStepped:Wait()
	if not isOpen then
		return
	end
	input:CaptureFocus()
	input.Text = ""
	refreshSuggestions()
end

local function submit(text: string)
	local trimmed = string.gsub(string.gsub(text, "^%s+", ""), "%s+$", "")
	if trimmed == "" then
		return
	end
	if history[#history] ~= trimmed then
		table.insert(history, trimmed)
		if #history > MAX_HISTORY then
			table.remove(history, 1)
		end
	end
	print_("> " .. trimmed, Kit.Theme.TextDim)

	if string.lower(CommandParser.StripSlash(trimmed)) == "clear" then
		for _, child in output:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		return
	end

	task.spawn(function()
		local ok, message = Net.Call("Admin.Run", trimmed)
		if type(message) == "string" and message ~= "" then
			print_(message, if ok then Kit.Theme.Good else Kit.Theme.Bad)
		elseif ok == nil then
			print_("Keine Antwort vom Server (zu viele Befehle hintereinander?).", Kit.Theme.Bad)
		end
		showOutputFor(OUTPUT_LINGER)
	end)
end

local function browseHistory(direction: number)
	if #history == 0 then
		return
	end
	-- historyIndex 0 = neue Eingabe, 1 = letzter Befehl, 2 = vorletzter …
	historyIndex = math.clamp(historyIndex + direction, 0, #history)
	local text = if historyIndex == 0 then "" else history[#history - historyIndex + 1]
	lastCompletion = text
	input.Text = text
	input.CursorPosition = #text + 1
end

------------------------------------------------------------------------------
-- Oberfläche
------------------------------------------------------------------------------

local function build()
	local gui = Kit.ScreenGui("AdminConsole", 100)

	output = Kit.Create("ScrollingFrame", {
		Name = "Output",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -(12 + INPUT_HEIGHT + 22 + 6)),
		Size = UDim2.fromOffset(WIDTH, OUTPUT_HEIGHT),
		BackgroundColor3 = Kit.Theme.Background,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	}, Kit.Corner(6), Kit.Padding(8), Kit.List(Enum.FillDirection.Vertical, 2))

	root = Kit.Create("Frame", {
		Name = "InputRow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(WIDTH, INPUT_HEIGHT + 22),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	local inputBack = Kit.Panel({
		Size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
		BackgroundColor3 = Kit.Theme.Background,
		BackgroundTransparency = 0.1,
		Parent = root,
	})
	Kit.Label({
		Text = ">",
		FontFace = Kit.Theme.FontMono,
		TextColor3 = Kit.Theme.Accent,
		Size = UDim2.new(0, 24, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = inputBack,
	})
	input = Kit.Create("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -32, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = Kit.Theme.FontMono,
		TextSize = 16,
		TextColor3 = Kit.Theme.Text,
		PlaceholderText = "Befehl eingeben …",
		PlaceholderColor3 = Kit.Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = inputBack,
	})
	hint = Kit.Label({
		Position = UDim2.fromOffset(4, INPUT_HEIGHT + 2),
		Size = UDim2.new(1, -8, 0, 20),
		FontFace = Kit.Theme.FontMono,
		TextSize = 13,
		TextColor3 = Kit.Theme.TextDim,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = root,
	})

	suggestionFrame = Kit.Create("Frame", {
		Name = "Suggestions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 0, -4),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Kit.Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}, Kit.Corner(6), Kit.Padding(4), Kit.List(Enum.FillDirection.Vertical, 0))

	-- Handy/Tablet: kleiner Knopf, weil es keine T-Taste gibt.
	if UserInputService.TouchEnabled then
		Kit.Button({
			Text = ">_",
			FontFace = Kit.Theme.FontMono,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(48, 44),
			BackgroundColor3 = Kit.Theme.Panel,
			Parent = gui,
		}, function()
			if isOpen then
				close()
			else
				open()
			end
		end)
	end
end

local function connect()
	input:GetPropertyChangedSignal("Text"):Connect(function()
		local text = input.Text
		-- Je nach Gerät kommt der Buchstabe der Öffnen-Taste erst nach dem Fokus im Feld an.
		if
			os.clock() - openedAt < OPEN_KEY_GRACE
			and #text == 1
			and string.upper(text) == GameConfig.Admin.ConsoleKey.Name
		then
			input.Text = ""
			return
		end
		-- Die Tab-Taste schreibt ein Tab-Zeichen ins Feld: als „Vorschlag übernehmen" deuten.
		if string.find(text, "\t", 1, true) then
			input.Text = string.gsub(text, "\t", "")
			applyNextSuggestion()
			return
		end
		if text ~= lastCompletion then
			lastCompletion = nil
			refreshSuggestions()
		end
	end)

	input.FocusLost:Connect(function(enterPressed: boolean)
		if not isOpen then
			return
		end
		if enterPressed then
			submit(input.Text)
		end
		close()
	end)

	UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessed: boolean)
		if inputObject.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if isOpen then
			if inputObject.KeyCode == Enum.KeyCode.Up then
				browseHistory(1)
			elseif inputObject.KeyCode == Enum.KeyCode.Down then
				browseHistory(-1)
			end
			return
		end
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if inputObject.KeyCode == GameConfig.Admin.ConsoleKey then
			open()
		end
	end)
end

function ConsoleController:Start()
	local list = Net.Call("Admin.GetCommands")
	if type(list) ~= "table" then
		return -- kein Admin: keine Konsole
	end
	commands = list
	table.insert(commands, { Name = "clear", Description = "Leert die Konsolen-Anzeige" })

	build()
	connect()
	print_(`Admin-Konsole bereit. Taste {GameConfig.Admin.ConsoleKey.Name} zum Öffnen, "help" für alle Befehle.`)
end

-- Für andere Controller: Text in die Konsole schreiben (nur sichtbar für Admins).
function ConsoleController:Print(text: string)
	if output then
		print_(text)
		showOutputFor(OUTPUT_LINGER)
	end
end

return ConsoleController
