--!strict
--[[
	SoundController – spielt Töne und Musik und hält sich an die Lautstärke aus den
	Einstellungen des Spielers (Spielstand: Settings.SfxVolume, Settings.MusicVolume).

	Client:
	  SoundController:Play("Coin")                    -- überall gleich laut (Oberfläche, Belohnung)
	  SoundController:Play("Coin", 0.5)               -- halb so laut
	  SoundController:PlayAt("Explosion", position)   -- in der Welt, wird mit der Entfernung leiser
	  SoundController:PlayMusic("rbxassetid://…")     -- einzelnes Stück statt der Liste aus Config/Sounds
	  SoundController:StopMusic()

	Server (für Töne, die ein oder mehrere Spieler hören sollen):
	  Net.Fire("Sound.Play", player, "Purchase")
	  Net.FireNear("Sound.Play", position, 120, "Explosion", position)

	Der Name kommt aus Config/Sounds. Statt eines Namens geht auch direkt eine Id
	("rbxassetid://…"). Ein leerer oder unbekannter Ton bleibt still.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Sounds = require(Shared.Config.Sounds)
local Kit = require(script.Parent.Parent.UI.Kit)
local DataController = require(script.Parent.DataController)

local DEFAULT_VOLUME = 0.5
local CLEANUP_AFTER = 15 -- Sekunden: Sicherheitsnetz, falls ein Ton nie „fertig" meldet

local SoundController = {
	Priority = 20, -- früh, damit andere Controller schon in Init Töne spielen können
}

local effectsGroup: SoundGroup
local musicGroup: SoundGroup
local random = Random.new()
local warned: { [string]: boolean } = {}

local musicSound: Sound? = nil
local musicToken = 0
local musicIndex = 0

local function group(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = name
	created.Parent = SoundService
	return created
end

local function resolve(nameOrId: string): Sounds.Sound?
	local spec = Sounds.Effects[nameOrId]
	if spec then
		return spec
	end
	if string.sub(nameOrId, 1, 3) == "rbx" or string.sub(nameOrId, 1, 4) == "http" then
		return { Id = nameOrId }
	end
	if nameOrId ~= "" and RunService:IsStudio() and not warned[nameOrId] then
		warned[nameOrId] = true
		warn(`[Sound] "{nameOrId}" steht nicht in Config/Sounds (Effects).`)
	end
	return nil
end

local function create(spec: Sounds.Sound, volumeScale: number?, parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = spec.Id
	sound.Volume = (spec.Volume or DEFAULT_VOLUME) * (volumeScale or 1)
	local variation = spec.SpeedVariation or 0
	sound.PlaybackSpeed = (spec.Speed or 1) * (1 + random:NextNumber(-variation, variation))
	sound.SoundGroup = effectsGroup
	sound.Parent = parent
	return sound
end

------------------------------------------------------------------------------
-- Töne
------------------------------------------------------------------------------

function SoundController:Play(nameOrId: string, volumeScale: number?)
	local spec = resolve(nameOrId)
	if not spec or spec.Id == "" then
		return
	end
	local sound = create(spec, volumeScale, SoundService)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(CLEANUP_AFTER, sound.Destroy, sound)
	sound:Play()
end

function SoundController:PlayAt(nameOrId: string, position: Vector3, volumeScale: number?)
	local spec = resolve(nameOrId)
	if not spec or spec.Id == "" then
		return
	end
	-- Ein Ton an einem Attachment kommt hörbar von dieser Stelle. Terrain dient nur als Halter.
	local holder = Instance.new("Attachment")
	holder.Name = "SoundAt"
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain

	local sound = create(spec, volumeScale, holder)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Sounds.WorldMinDistance
	sound.RollOffMaxDistance = Sounds.WorldMaxDistance
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	task.delay(CLEANUP_AFTER, holder.Destroy, holder)
	sound:Play()
end

------------------------------------------------------------------------------
-- Musik
------------------------------------------------------------------------------

local function fadeOut(sound: Sound)
	local tween = Kit.Tween(sound, Sounds.MusicFadeSeconds, { Volume = 0 }, Enum.EasingStyle.Linear)
	tween.Completed:Once(function()
		sound:Destroy()
	end)
end

local function startTrack(spec: Sounds.Sound, onEnded: (() -> ())?)
	musicToken += 1
	local token = musicToken
	local previous = musicSound
	if previous then
		fadeOut(previous)
	end
	musicSound = nil
	if spec.Id == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = spec.Id
	sound.PlaybackSpeed = spec.Speed or 1
	sound.Volume = 0
	sound.Looped = onEnded == nil
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	musicSound = sound

	Kit.Tween(sound, Sounds.MusicFadeSeconds, { Volume = spec.Volume or DEFAULT_VOLUME }, Enum.EasingStyle.Linear)
	if onEnded then
		sound.Ended:Once(function()
			if token == musicToken then
				onEnded()
			end
		end)
	end
	sound:Play()
end

local function nextFromPlaylist()
	local playlist = Sounds.Music
	if #playlist == 0 then
		return
	end
	musicIndex = musicIndex % #playlist + 1
	-- Bei nur einem Stück einfach in Schleife spielen.
	startTrack(playlist[musicIndex], if #playlist > 1 then nextFromPlaylist else nil)
end

-- Ohne Angabe: die Liste aus Config/Sounds. Mit Angabe: genau dieses Stück in Schleife
-- (z. B. Kampfmusik); danach bringt PlayMusic() die Liste zurück.
function SoundController:PlayMusic(nameOrId: string?)
	if nameOrId == nil then
		nextFromPlaylist()
		return
	end
	local spec = resolve(nameOrId)
	if spec then
		startTrack(spec, nil)
	end
end

function SoundController:StopMusic()
	startTrack({ Id = "" }, nil)
end

------------------------------------------------------------------------------
-- Lebenszyklus
------------------------------------------------------------------------------

function SoundController:Init()
	effectsGroup = group("Effects")
	musicGroup = group("Music")

	-- Jeder Kit.Button klickt hörbar.
	Kit.OnButtonClick = function()
		SoundController:Play("Click")
	end

	Net.Listen("Sound.Play", function(nameOrId: any, position: any, volumeScale: any)
		if type(nameOrId) ~= "string" then
			return
		end
		local scale = if type(volumeScale) == "number" then volumeScale else nil
		if typeof(position) == "Vector3" then
			SoundController:PlayAt(nameOrId, position, scale)
		else
			SoundController:Play(nameOrId, scale)
		end
	end)
end

function SoundController:Start()
	DataController:Observe("Settings.SfxVolume", function(volume: any)
		effectsGroup.Volume = if type(volume) == "number" then math.clamp(volume, 0, 1) else 1
	end)
	DataController:Observe("Settings.MusicVolume", function(volume: any)
		musicGroup.Volume = if type(volume) == "number" then math.clamp(volume, 0, 1) else 1
	end)
	nextFromPlaylist()
end

return SoundController
