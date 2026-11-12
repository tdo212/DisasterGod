--!strict
-- EnvironmentService: per-map lighting presets (day, neon night, desert, arctic,
-- sunset, volcanic) and mood shifts on top of them (storm darkening for telegraphs,
-- red sudden-death tint).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local EnvironmentService = {}

local correction: ColorCorrectionEffect
local atmosphere: Atmosphere
local bloom: BloomEffect

type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	AtmosphereColor: Color3,
	AtmosphereDecay: Color3,
	Density: number,
	Haze: number,
	Bloom: number,
}

local PRESETS: { [string]: Preset } = {
	Day = {
		ClockTime = 14.5,
		Brightness = 3,
		Ambient = Color3.fromRGB(90, 95, 110),
		OutdoorAmbient = Color3.fromRGB(150, 155, 170),
		Tint = Color3.fromRGB(255, 255, 255),
		Saturation = 0.18,
		Contrast = 0.05,
		AtmosphereColor = Color3.fromRGB(200, 225, 255),
		AtmosphereDecay = Color3.fromRGB(120, 150, 200),
		Density = 0.28,
		Haze = 0.6,
		Bloom = 0.35,
	},
	Night = {
		ClockTime = 20.6,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(125, 105, 165),
		OutdoorAmbient = Color3.fromRGB(165, 140, 210),
		Tint = Color3.fromRGB(235, 225, 255),
		Saturation = 0.3,
		Contrast = 0.12,
		AtmosphereColor = Color3.fromRGB(120, 80, 170),
		AtmosphereDecay = Color3.fromRGB(70, 40, 120),
		Density = 0.3,
		Haze = 1.3,
		Bloom = 0.7,
	},
	Desert = {
		ClockTime = 13,
		Brightness = 3.6,
		Ambient = Color3.fromRGB(120, 100, 80),
		OutdoorAmbient = Color3.fromRGB(190, 160, 120),
		Tint = Color3.fromRGB(255, 240, 215),
		Saturation = 0.2,
		Contrast = 0.08,
		AtmosphereColor = Color3.fromRGB(255, 225, 170),
		AtmosphereDecay = Color3.fromRGB(230, 180, 120),
		Density = 0.33,
		Haze = 1.6,
		Bloom = 0.3,
	},
	Arctic = {
		ClockTime = 12,
		Brightness = 3.2,
		Ambient = Color3.fromRGB(110, 130, 160),
		OutdoorAmbient = Color3.fromRGB(170, 195, 230),
		Tint = Color3.fromRGB(230, 245, 255),
		Saturation = 0.12,
		Contrast = 0.08,
		AtmosphereColor = Color3.fromRGB(215, 235, 255),
		AtmosphereDecay = Color3.fromRGB(150, 190, 240),
		Density = 0.35,
		Haze = 1.2,
		Bloom = 0.35,
	},
	Sunset = {
		ClockTime = 17.75,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(120, 90, 100),
		OutdoorAmbient = Color3.fromRGB(200, 150, 140),
		Tint = Color3.fromRGB(255, 225, 205),
		Saturation = 0.28,
		Contrast = 0.1,
		AtmosphereColor = Color3.fromRGB(255, 190, 160),
		AtmosphereDecay = Color3.fromRGB(240, 140, 120),
		Density = 0.3,
		Haze = 1.4,
		Bloom = 0.5,
	},
	Volcanic = {
		ClockTime = 15,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(110, 80, 70),
		OutdoorAmbient = Color3.fromRGB(170, 130, 120),
		Tint = Color3.fromRGB(255, 235, 225),
		Saturation = 0.15,
		Contrast = 0.1,
		AtmosphereColor = Color3.fromRGB(190, 150, 140),
		AtmosphereDecay = Color3.fromRGB(150, 90, 70),
		Density = 0.32,
		Haze = 1.4,
		Bloom = 0.35,
	},
}

type Mood = { Brightness: number, Tint: Color3, Contrast: number, AtmosphereColor: Color3, Haze: number }

local preset: Preset = PRESETS.Day
local currentMood = "Calm"

local function moodValues(mood: string): Mood?
	local p = preset
	if mood == "Calm" then
		return { Brightness = p.Brightness, Tint = p.Tint, Contrast = p.Contrast, AtmosphereColor = p.AtmosphereColor, Haze = p.Haze }
	elseif mood == "Storm" then
		return {
			Brightness = p.Brightness * 0.72,
			Tint = p.Tint:Lerp(Color3.fromRGB(200, 205, 235), 0.6),
			Contrast = p.Contrast + 0.07,
			AtmosphereColor = p.AtmosphereColor:Lerp(Color3.fromRGB(120, 125, 150), 0.6),
			Haze = p.Haze + 1.2,
		}
	elseif mood == "SuddenDeath" then
		return {
			Brightness = p.Brightness * 0.7,
			Tint = p.Tint:Lerp(Color3.fromRGB(255, 170, 150), 0.6),
			Contrast = p.Contrast + 0.13,
			AtmosphereColor = p.AtmosphereColor:Lerp(Color3.fromRGB(220, 110, 90), 0.6),
			Haze = p.Haze + 1.6,
		}
	end
	return nil
end

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing :: any
	end
	local inst = Instance.new(className :: any)
	inst.Name = name
	inst.Parent = Lighting
	return inst :: any
end

function EnvironmentService.Init()
	Lighting.GeographicLatitude = 30
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true

	atmosphere = ensure("Atmosphere", "DGAtmosphere")
	atmosphere.Offset = 0.2
	atmosphere.Glare = 0.2
	correction = ensure("ColorCorrectionEffect", "DGColor")
	bloom = ensure("BloomEffect", "DGBloom")
	bloom.Size = 24
	bloom.Threshold = 2
	local rays: SunRaysEffect = ensure("SunRaysEffect", "DGSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	ensure("Sky", "DGSky")

	EnvironmentService.ApplyPreset("Day", 0)
end

-- Switch the whole look for a map (tweened unless seconds == 0).
function EnvironmentService.ApplyPreset(name: string, seconds: number?)
	local p = PRESETS[name] or PRESETS.Day
	preset = p
	currentMood = "Calm"
	local t = seconds or 2
	if t <= 0 then
		Lighting.ClockTime = p.ClockTime
		Lighting.Brightness = p.Brightness
		Lighting.Ambient = p.Ambient
		Lighting.OutdoorAmbient = p.OutdoorAmbient
		correction.TintColor = p.Tint
		correction.Saturation = p.Saturation
		correction.Contrast = p.Contrast
		atmosphere.Color = p.AtmosphereColor
		atmosphere.Decay = p.AtmosphereDecay
		atmosphere.Density = p.Density
		atmosphere.Haze = p.Haze
		bloom.Intensity = p.Bloom
		return
	end
	local info = TweenInfo.new(t, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { ClockTime = p.ClockTime, Brightness = p.Brightness, Ambient = p.Ambient, OutdoorAmbient = p.OutdoorAmbient }):Play()
	TweenService:Create(correction, info, { TintColor = p.Tint, Saturation = p.Saturation, Contrast = p.Contrast }):Play()
	TweenService:Create(atmosphere, info, { Color = p.AtmosphereColor, Decay = p.AtmosphereDecay, Density = p.Density, Haze = p.Haze }):Play()
	TweenService:Create(bloom, info, { Intensity = p.Bloom }):Play()
end

function EnvironmentService.SetMood(mood: string, seconds: number?)
	local m = moodValues(mood)
	if not m then
		return
	end
	currentMood = mood
	local info = TweenInfo.new(seconds or 2, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { Brightness = m.Brightness }):Play()
	TweenService:Create(correction, info, { TintColor = m.Tint, Contrast = m.Contrast }):Play()
	TweenService:Create(atmosphere, info, { Color = m.AtmosphereColor, Haze = m.Haze }):Play()
end

-- Brief darkening used when a major disaster is telegraphed.
function EnvironmentService.Darken(seconds: number)
	local back = currentMood
	EnvironmentService.SetMood("Storm", 0.4)
	task.delay(seconds, function()
		if currentMood == "Storm" then
			EnvironmentService.SetMood(back, 1)
		end
	end)
end

return EnvironmentService
