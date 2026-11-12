--!strict
-- EnvironmentService: bright daytime lighting and mood shifts (storm darkening for
-- telegraphs, red sudden-death tint).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local EnvironmentService = {}

local correction: ColorCorrectionEffect
local atmosphere: Atmosphere

local MOODS = {
	Calm = {
		Brightness = 3,
		Tint = Color3.fromRGB(255, 255, 255),
		Contrast = 0.05,
		AtmosphereColor = Color3.fromRGB(200, 225, 255),
		Haze = 0.6,
	},
	Storm = {
		Brightness = 2.2,
		Tint = Color3.fromRGB(215, 220, 245),
		Contrast = 0.12,
		AtmosphereColor = Color3.fromRGB(150, 160, 190),
		Haze = 1.8,
	},
	SuddenDeath = {
		Brightness = 2,
		Tint = Color3.fromRGB(255, 200, 185),
		Contrast = 0.18,
		AtmosphereColor = Color3.fromRGB(230, 140, 110),
		Haze = 2.2,
	},
}

local currentMood = "Calm"

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
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(90, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 170)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true

	atmosphere = ensure("Atmosphere", "DGAtmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = MOODS.Calm.AtmosphereColor
	atmosphere.Decay = Color3.fromRGB(120, 150, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = MOODS.Calm.Haze

	correction = ensure("ColorCorrectionEffect", "DGColor")
	correction.Saturation = 0.18
	correction.Contrast = MOODS.Calm.Contrast
	correction.TintColor = MOODS.Calm.Tint

	local bloom: BloomEffect = ensure("BloomEffect", "DGBloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 2

	local rays: SunRaysEffect = ensure("SunRaysEffect", "DGSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6

	ensure("Sky", "DGSky")
end

function EnvironmentService.SetMood(mood: string, seconds: number?)
	local m = MOODS[mood]
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
