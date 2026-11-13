--!strict
--[[
	Effects – die dauerhaften Admin-Zustände eines Spielers.

	Jeder Zustand ist ein Attribut am Player (vom Server gesetzt, für Clients nur
	lesbar):
	  AdminFly, AdminNoclip   -> setzt der eigene Client um (AdminEffectsController)
	  AdminGod, AdminInvisible -> setzt der Server um (hier)

	Zustände überleben den Tod: Beim neuen Charakter werden sie wieder angewendet.

	Für eigene Schadenssysteme: Schaden immer über Humanoid:TakeDamage() austeilen,
	dann schützt der Gott-Modus automatisch. Wer Health direkt setzt, fragt vorher
	Effects.IsGod(player).
]]

local Players = game:GetService("Players")

export type Flag = "AdminFly" | "AdminNoclip" | "AdminGod" | "AdminInvisible"

local ORIGINAL_TRANSPARENCY = "AdminOriginalTransparency"
local GOD_FIELD_NAME = "AdminGodField"

local Effects = {}

local characterCleanups: { [Player]: { [string]: () -> () } } = {}

local function setCleanup(player: Player, key: string, cleanup: (() -> ())?)
	local cleanups = characterCleanups[player]
	if not cleanups then
		cleanups = {}
		characterCleanups[player] = cleanups
	end
	local previous = cleanups[key]
	if previous then
		previous()
	end
	cleanups[key] = cleanup :: any
end

------------------------------------------------------------------------------
-- Unsterblich
------------------------------------------------------------------------------

local function applyGod(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	-- Erst einen schon laufenden Gott-Modus beenden (z. B. bei zweimal "god an").
	setCleanup(player, "God", nil)

	-- Unsichtbares Kraftfeld: blockt TakeDamage und Explosionen.
	local field = Instance.new("ForceField")
	field.Name = GOD_FIELD_NAME
	field.Visible = false
	field.Parent = character

	-- Zusätzlich direkte Health-Änderungen sofort ausgleichen.
	humanoid.Health = humanoid.MaxHealth
	local connection = humanoid.HealthChanged:Connect(function(health)
		if health < humanoid.MaxHealth and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			humanoid.Health = humanoid.MaxHealth
		end
	end)

	setCleanup(player, "God", function()
		connection:Disconnect()
		field:Destroy()
	end)
end

------------------------------------------------------------------------------
-- Unsichtbar
------------------------------------------------------------------------------

local function hide(instance: Instance)
	if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
		-- BasePart, Decal und Texture haben alle `Transparency`, aber keine gemeinsame Klasse dafür.
		local target = instance :: any
		if instance:GetAttribute(ORIGINAL_TRANSPARENCY) == nil then
			instance:SetAttribute(ORIGINAL_TRANSPARENCY, target.Transparency)
		end
		target.Transparency = 1
	end
end

local function show(instance: Instance)
	if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
		local original = instance:GetAttribute(ORIGINAL_TRANSPARENCY)
		if type(original) == "number" then
			(instance :: any).Transparency = original
			instance:SetAttribute(ORIGINAL_TRANSPARENCY, nil)
		end
	end
end

local function applyInvisible(player: Player, character: Model)
	-- Erst eine schon laufende Unsichtbarkeit beenden. Würde das erst nach dem Verstecken
	-- passieren, machte ihre Aufräumfunktion den Charakter wieder sichtbar.
	setCleanup(player, "Invisible", nil)
	for _, descendant in character:GetDescendants() do
		hide(descendant)
	end
	-- Später angelegte Teile (Werkzeuge, Accessoires) ebenfalls verstecken.
	local connection = character.DescendantAdded:Connect(hide)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local originalDisplay = if humanoid then humanoid.DisplayDistanceType else nil
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	setCleanup(player, "Invisible", function()
		connection:Disconnect()
		for _, descendant in character:GetDescendants() do
			show(descendant)
		end
		if humanoid and originalDisplay then
			humanoid.DisplayDistanceType = originalDisplay
		end
	end)
end

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

local function applyToCharacter(player: Player, character: Model)
	if player:GetAttribute("AdminGod") then
		applyGod(player, character)
	end
	if player:GetAttribute("AdminInvisible") then
		applyInvisible(player, character)
	end
end

-- Setzt einen Zustand. `state = nil` schaltet um. Gibt den neuen Zustand zurück.
function Effects.Set(player: Player, flag: Flag, state: boolean?): boolean
	local new = if state == nil then not player:GetAttribute(flag) else state
	player:SetAttribute(flag, new)

	local character = player.Character
	if flag == "AdminGod" then
		if new and character then
			applyGod(player, character)
		elseif not new then
			setCleanup(player, "God", nil)
		end
	elseif flag == "AdminInvisible" then
		if new and character then
			applyInvisible(player, character)
		elseif not new then
			setCleanup(player, "Invisible", nil)
		end
	end
	return new
end

function Effects.IsGod(player: Player): boolean
	return player:GetAttribute("AdminGod") == true
end

function Effects.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Der alte Charakter ist weg: seine Aufräumfunktionen verwerfen, nicht ausführen.
			characterCleanups[player] = {}
			-- Kurz warten, bis Aussehen und Humanoid vollständig geladen sind.
			character:WaitForChild("Humanoid", 5)
			task.wait(0.1)
			if player.Character == character then
				applyToCharacter(player, character)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		characterCleanups[player] = nil
	end)
end

return Effects
