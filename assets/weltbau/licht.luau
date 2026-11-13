--[[
	licht.luau – Licht-Stimmungen für Studio (über `execute_luau` ausführen).

	Kein Spielcode. Setzt Lighting, Atmosphere und Nachbearbeitung auf eine
	stimmige Grundeinstellung. Danach im Bildschirmfoto prüfen und Werte anpassen.

	Aufruf am Ende: return apply("Stilisiert")
	Stimmungen: "Stilisiert", "Tag", "Abend", "Nacht", "Horror"

	Nicht per Skript einstellbar: Lighting.Technology (im Eigenschaften-Fenster
	wählen; "Future" sieht am besten aus, kostet aber Leistung auf Handys).
]]

local Lighting = game:GetService("Lighting")

local PRESETS = {
	-- Klare, freundliche Farben: passt zu Block-Welten, Simulatoren, Obbys, Tycoons.
	Stilisiert = {
		ClockTime = 14,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(120, 124, 140),
		OutdoorAmbient = Color3.fromRGB(150, 156, 172),
		ExposureCompensation = 0.1,
		Atmosphere = { Density = 0.25, Haze = 0.6, Color = Color3.fromRGB(205, 220, 240) },
		Color = { Saturation = 0.18, Contrast = 0.08, TintColor = Color3.fromRGB(255, 252, 244) },
		Bloom = { Intensity = 0.35, Size = 28, Threshold = 1.6 },
	},
	Tag = {
		ClockTime = 12,
		Brightness = 3,
		Ambient = Color3.fromRGB(100, 104, 112),
		OutdoorAmbient = Color3.fromRGB(140, 144, 150),
		ExposureCompensation = 0,
		Atmosphere = { Density = 0.3, Haze = 1, Color = Color3.fromRGB(199, 210, 225) },
		Color = { Saturation = 0.05, Contrast = 0.05, TintColor = Color3.fromRGB(255, 255, 255) },
		Bloom = { Intensity = 0.25, Size = 24, Threshold = 2 },
	},
	Abend = {
		ClockTime = 17.8,
		Brightness = 2,
		Ambient = Color3.fromRGB(110, 86, 90),
		OutdoorAmbient = Color3.fromRGB(150, 110, 96),
		ExposureCompensation = 0.1,
		Atmosphere = { Density = 0.35, Haze = 1.8, Color = Color3.fromRGB(255, 190, 140) },
		Color = { Saturation = 0.12, Contrast = 0.1, TintColor = Color3.fromRGB(255, 236, 214) },
		Bloom = { Intensity = 0.5, Size = 32, Threshold = 1.4 },
	},
	Nacht = {
		ClockTime = 0.5,
		Brightness = 1.2,
		Ambient = Color3.fromRGB(46, 52, 78),
		OutdoorAmbient = Color3.fromRGB(58, 66, 98),
		ExposureCompensation = 0.3,
		Atmosphere = { Density = 0.3, Haze = 0.8, Color = Color3.fromRGB(70, 84, 120) },
		Color = { Saturation = -0.05, Contrast = 0.1, TintColor = Color3.fromRGB(214, 226, 255) },
		Bloom = { Intensity = 0.6, Size = 30, Threshold = 1.2 },
	},
	-- Sehr dunkel und entsättigt; Lichtquellen in der Welt tragen die Stimmung.
	Horror = {
		ClockTime = 0,
		Brightness = 0.4,
		Ambient = Color3.fromRGB(14, 14, 18),
		OutdoorAmbient = Color3.fromRGB(18, 18, 24),
		ExposureCompensation = -0.3,
		Atmosphere = { Density = 0.5, Haze = 2.4, Color = Color3.fromRGB(40, 44, 50) },
		Color = { Saturation = -0.45, Contrast = 0.2, TintColor = Color3.fromRGB(220, 226, 235) },
		Bloom = { Intensity = 0.3, Size = 20, Threshold = 1.8 },
	},
}

local function ensure(className: string): any
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = Lighting
	return created
end

local function apply(name: string): string
	local preset = PRESETS[name]
	if not preset then
		return `Unbekannte Stimmung "{name}"`
	end
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ExposureCompensation = preset.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local atmosphere = ensure("Atmosphere")
	atmosphere.Density = preset.Atmosphere.Density
	atmosphere.Haze = preset.Atmosphere.Haze
	atmosphere.Color = preset.Atmosphere.Color
	atmosphere.Decay = preset.Atmosphere.Color

	local color = ensure("ColorCorrectionEffect")
	color.Saturation = preset.Color.Saturation
	color.Contrast = preset.Color.Contrast
	color.TintColor = preset.Color.TintColor

	local bloom = ensure("BloomEffect")
	bloom.Intensity = preset.Bloom.Intensity
	bloom.Size = preset.Bloom.Size
	bloom.Threshold = preset.Bloom.Threshold

	return `Licht-Stimmung "{name}" gesetzt. Mit screen_capture prüfen.`
end

return apply("Stilisiert")
