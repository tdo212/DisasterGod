--!strict
-- EnvironmentService: per-map lighting presets (day, neon night, desert, arctic,
-- sunset, volcanic) and mood shifts on top of them (storm darkening for telegraphs,
-- red sudden-death tint).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local EnvironmentService = {}

local correction: ColorCorrectionEffect
local atmosphere: Atmosphere
local bloom: BloomEffect
local sky: Sky? = nil

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
	-- the Sky Lodge between rounds: indoor warmth, gentle exposure so avatars keep their colour
	Lodge = {
		ClockTime = 15.5,
		Brightness = 1.8,
		Ambient = Color3.fromRGB(80, 72, 70),
		OutdoorAmbient = Color3.fromRGB(120, 112, 108),
		Tint = Color3.fromRGB(255, 244, 232),
		Saturation = 0.1,
		Contrast = 0.06,
		AtmosphereColor = Color3.fromRGB(220, 210, 200),
		AtmosphereDecay = Color3.fromRGB(150, 140, 130),
		Density = 0.25,
		Haze = 0.8,
		Bloom = 0.15,
	},
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
		Ambient = Color3.fromRGB(118, 100, 155),
		OutdoorAmbient = Color3.fromRGB(155, 132, 198),
		Tint = Color3.fromRGB(235, 225, 255),
		Saturation = 0.3,
		Contrast = 0.12,
		AtmosphereColor = Color3.fromRGB(120, 80, 170),
		AtmosphereDecay = Color3.fromRGB(70, 40, 120),
		Density = 0.3,
		Haze = 1.3,
		Bloom = 0.22,
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
		Bloom = 0.3,
	},
	-- Chrono-Spire: warm golden sunset haze over the foundries
	Foundry = {
		ClockTime = 17.4,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(115, 90, 70),
		OutdoorAmbient = Color3.fromRGB(190, 150, 110),
		Tint = Color3.fromRGB(255, 232, 200),
		Saturation = 0.22,
		Contrast = 0.1,
		AtmosphereColor = Color3.fromRGB(255, 200, 130),
		AtmosphereDecay = Color3.fromRGB(220, 140, 80),
		Density = 0.36,
		Haze = 2,
		Bloom = 0.25,
	},
	-- Verdant Bio-Dome: bright midday through glass, green bounce light
	Conservatory = {
		ClockTime = 12.5,
		Brightness = 3,
		Ambient = Color3.fromRGB(105, 110, 80),
		OutdoorAmbient = Color3.fromRGB(170, 175, 135),
		Tint = Color3.fromRGB(255, 252, 230),
		Saturation = 0.25,
		Contrast = 0.06,
		AtmosphereColor = Color3.fromRGB(235, 240, 210),
		AtmosphereDecay = Color3.fromRGB(190, 210, 150),
		Density = 0.26,
		Haze = 0.9,
		Bloom = 0.2,
	},
	-- Ironclad Armada: dark overcast storm, driving rain (client weather adds the flashes)
	Tempest = {
		ClockTime = 15,
		Brightness = 2,
		Ambient = Color3.fromRGB(100, 108, 120),
		OutdoorAmbient = Color3.fromRGB(140, 150, 165),
		Tint = Color3.fromRGB(215, 225, 240),
		Saturation = -0.15,
		Contrast = 0.14,
		AtmosphereColor = Color3.fromRGB(120, 130, 145),
		AtmosphereDecay = Color3.fromRGB(70, 80, 95),
		Density = 0.42,
		Haze = 2.4,
		Bloom = 0.15,
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
	elseif mood == "Twilight" then
		-- Chaos Twist: a darker, moodier sky; telegraphs and outlines are neon so they stay readable
		return {
			Brightness = p.Brightness * 0.62,
			Tint = p.Tint:Lerp(Color3.fromRGB(190, 195, 255), 0.45),
			Contrast = p.Contrast + 0.1,
			AtmosphereColor = p.AtmosphereColor:Lerp(Color3.fromRGB(90, 95, 140), 0.55),
			Haze = p.Haze + 0.8,
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
	Lighting.ExposureCompensation = -0.15
	-- the place file ships its own Bloom / SunRays / Atmosphere / DepthOfField; stacked on
	-- ours they doubled the glow (neon and white avatars blew out). Ours are the only ones.
	for _, effect in Lighting:GetChildren() do
		if string.sub(effect.Name, 1, 2) ~= "DG" then
			if effect:IsA("PostEffect") then
				effect.Enabled = false
			elseif effect:IsA("Atmosphere") then
				effect:Destroy()
			end
		end
	end

	atmosphere = ensure("Atmosphere", "DGAtmosphere")
	atmosphere.Offset = 0.2
	atmosphere.Glare = 0.2
	correction = ensure("ColorCorrectionEffect", "DGColor")
	bloom = ensure("BloomEffect", "DGBloom")
	bloom.Size = 18
	bloom.Threshold = 2.4
	local rays: SunRaysEffect = ensure("SunRaysEffect", "DGSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local s: Sky = ensure("Sky", "DGSky")
	s.SunAngularSize = 14
	s.MoonAngularSize = 9
	sky = s

	EnvironmentService.ApplyPreset("Lodge", 0)
end

-- Switch the whole look for a map (tweened unless seconds == 0).
function EnvironmentService.ApplyPreset(name: string, seconds: number?)
	local p = PRESETS[name] or PRESETS.Day
	preset = p
	currentMood = "Calm"
	local faces = Config.Skies[name] or Config.Skies.Day
	local sk = sky
	if sk and faces then
		local function id(n: number): string
			return "rbxassetid://" .. tostring(n)
		end
		sk.SkyboxBk, sk.SkyboxDn, sk.SkyboxFt = id(faces[1]), id(faces[2]), id(faces[3])
		sk.SkyboxLf, sk.SkyboxRt, sk.SkyboxUp = id(faces[4]), id(faces[5]), id(faces[6])
		sk.StarCount = if name == "Night" or name == "Tempest" then 3000 else 600
		sk.CelestialBodiesShown = name ~= "Volcanic" and name ~= "Tempest"
	end
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
