--!strict
--[[
	Kit – kleiner UI-Baukasten, damit jede Oberfläche im Spiel gleich aussieht.

	Die gesamte UI entsteht im Code (nicht von Hand in StarterGui). Vorteile: Sie
	liegt als Datei im Projekt, ist versionierbar und lässt sich überall gleich
	stylen. Farben, Schrift und Abstände stehen NUR hier in Kit.Theme.

	local gui = Kit.ScreenGui("Shop")
	local panel = Kit.Panel({ Size = UDim2.fromOffset(420, 300), Position = UDim2.fromScale(0.5, 0.5),
	                          AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui })
	Kit.Button({ Text = "Kaufen", Size = UDim2.fromOffset(160, 44), Parent = panel }, function() ... end)

	Regeln für gute Roblox-UI:
	  - Größen in Offset (Pixel), skaliert wird über das UIScale von Kit.ScreenGui.
	  - Knöpfe mindestens 44 Pixel hoch (Finger auf dem Handy).
	  - Nichts Wichtiges in die Ecken oben (Roblox-Menü) oder unter die Sprungtaste.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = {}

-- Wird bei jedem Klick auf einen Kit.Button aufgerufen. Der SoundController hängt hier den Klick-Ton ein.
Kit.OnButtonClick = nil :: (() -> ())?

Kit.Theme = {
	Background = Color3.fromRGB(16, 18, 24),
	Panel = Color3.fromRGB(27, 30, 39),
	PanelLight = Color3.fromRGB(41, 45, 58),
	Stroke = Color3.fromRGB(62, 68, 86),
	Text = Color3.fromRGB(240, 242, 248),
	TextDim = Color3.fromRGB(158, 165, 182),
	Accent = Color3.fromRGB(84, 160, 255),
	Good = Color3.fromRGB(76, 201, 122),
	Bad = Color3.fromRGB(236, 88, 88),
	Warn = Color3.fromRGB(246, 190, 68),

	Font = Font.fromEnum(Enum.Font.GothamMedium),
	FontBold = Font.fromEnum(Enum.Font.GothamBold),
	FontMono = Font.fromEnum(Enum.Font.RobotoMono),

	Corner = 8,
	Padding = 12,
	TextSize = 16,
	MinTouchSize = 44,
}

-- Bezugshöhe: Bei dieser Bildschirmhöhe ist der Maßstab 1.
local BASE_HEIGHT = 720
local MIN_SCALE = 0.55
local MAX_SCALE = 1.6

-- Allgemeiner Instanz-Bauer: Kit.Create("Frame", { Size = ..., Parent = ... }, kind1, kind2, ...)
-- Parent wird zuletzt gesetzt (schneller und ohne Flackern).
function Kit.Create(className: string, properties: { [string]: any }?, ...: Instance): any
	local instance = Instance.new(className) :: any
	local parent: Instance? = nil
	if properties then
		for key, value in properties do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	for _, child in { ... } do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.Corner(radius: number?): UICorner
	return Kit.Create("UICorner", { CornerRadius = UDim.new(0, radius or Kit.Theme.Corner) })
end

function Kit.Stroke(color: Color3?, thickness: number?): UIStroke
	return Kit.Create("UIStroke", {
		Color = color or Kit.Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.Padding(amount: number?): UIPadding
	local padding = UDim.new(0, amount or Kit.Theme.Padding)
	return Kit.Create("UIPadding", {
		PaddingTop = padding,
		PaddingBottom = padding,
		PaddingLeft = padding,
		PaddingRight = padding,
	})
end

function Kit.List(direction: Enum.FillDirection?, spacing: number?): UIListLayout
	return Kit.Create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function applyOverrides(instance: any, properties: { [string]: any }?)
	local parent: Instance? = nil
	if properties then
		for key, value in properties do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
end

-- ScreenGui im PlayerGui mit automatischem Maßstab für jede Bildschirmgröße.
function Kit.ScreenGui(name: string, displayOrder: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = Kit.Create("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
	})
	local scale: UIScale = Kit.Create("UIScale", { Parent = gui })

	local function updateScale()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / BASE_HEIGHT, MIN_SCALE, MAX_SCALE)
		end
	end
	-- Die Kamera kann ausgetauscht werden: der Größen-Beobachter muss dann an die neue.
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera then
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

	gui.Parent = playerGui
	return gui
end

function Kit.Panel(properties: { [string]: any }?): Frame
	local frame: Frame = Kit.Create("Frame", {
		BackgroundColor3 = Kit.Theme.Panel,
		BorderSizePixel = 0,
	}, Kit.Corner(), Kit.Stroke())
	applyOverrides(frame, properties)
	return frame
end

function Kit.Label(properties: { [string]: any }?): TextLabel
	local label: TextLabel = Kit.Create("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Kit.Theme.Font,
		TextColor3 = Kit.Theme.Text,
		TextSize = Kit.Theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	})
	applyOverrides(label, properties)
	return label
end

function Kit.Tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Kurzes „Aufploppen" als Rückmeldung (Kauf geklappt, Münze bekommen …).
function Kit.Pop(object: GuiObject, strength: number?)
	local scale = object:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = Kit.Create("UIScale", { Name = "PopScale", Parent = object }) :: UIScale
	end
	local target = scale :: UIScale
	target.Scale = 1 + (strength or 0.15)
	Kit.Tween(target, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Knopf mit Farbwechsel beim Überfahren/Drücken. `onClick` läuft bei Maus, Finger und Controller.
function Kit.Button(properties: { [string]: any }?, onClick: (() -> ())?): TextButton
	local baseColor = if properties and properties.BackgroundColor3
		then properties.BackgroundColor3
		else Kit.Theme.Accent
	local button: TextButton = Kit.Create("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = baseColor,
		BorderSizePixel = 0,
		FontFace = Kit.Theme.FontBold,
		TextColor3 = Kit.Theme.Text,
		TextSize = Kit.Theme.TextSize,
		Text = "",
		Size = UDim2.fromOffset(160, Kit.Theme.MinTouchSize),
	}, Kit.Corner())
	applyOverrides(button, properties)

	local function shade(amount: number): Color3
		return baseColor:Lerp(if amount > 0 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0), math.abs(amount))
	end

	button.MouseEnter:Connect(function()
		Kit.Tween(button, 0.1, { BackgroundColor3 = shade(0.12) })
	end)
	button.MouseLeave:Connect(function()
		Kit.Tween(button, 0.1, { BackgroundColor3 = baseColor })
	end)
	button.MouseButton1Down:Connect(function()
		Kit.Tween(button, 0.05, { BackgroundColor3 = shade(-0.15) })
	end)
	button.MouseButton1Up:Connect(function()
		Kit.Tween(button, 0.1, { BackgroundColor3 = baseColor })
	end)
	button.Activated:Connect(function()
		local clickSound = Kit.OnButtonClick
		if clickSound then
			clickSound()
		end
		if onClick then
			onClick()
		end
	end)
	return button
end

-- true auf Geräten, die (auch) per Finger bedient werden.
function Kit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Abstand zum oberen Rand, den die Roblox-Leiste belegt.
function Kit.TopInset(): number
	local inset = GuiService:GetGuiInset()
	return inset.Y
end

return Kit
