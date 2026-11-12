--!strict
-- AudioController: adaptive music + environment ambience + round-flow cues.
--   Music:    lobby track in the Sky Sanctuary, tense track in the arena, boss track in
--             sudden death (crossfaded).
--   Ambience: birds in the lobby; per-map beds in the arena (waves, city, lava, wind...).
--   Cues:     intermission countdown ticks, prep tocks, round-start hit, sudden-death
--             alarm, win/lose stingers on the round summary.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)

local A = Config.Audio
local Attributes = Config.Attributes
local player = Players.LocalPlayer

local AudioController = {}

type Channel = { Group: SoundGroup, Current: Sound?, CurrentId: string? }

local started = false
local channels: { [string]: Channel } = {}

local function channel(name: string, volume: number): Channel
	local existing = channels[name]
	if existing then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = SoundService
	local c: Channel = { Group = g, Current = nil, CurrentId = nil }
	channels[name] = c
	return c
end

-- Crossfade a channel to a looping track (nil = silence).
local function crossfade(c: Channel, id: (number | string)?, volume: number?)
	local sid = if id then Sound.idOf(id) else nil
	if sid == c.CurrentId then
		return
	end
	local fade = TweenInfo.new(A.CrossfadeSeconds, Enum.EasingStyle.Sine)
	local old = c.Current
	if old then
		local t = TweenService:Create(old, fade, { Volume = 0 })
		t:Play()
		t.Completed:Once(function()
			old:Destroy()
		end)
	end
	c.Current = nil
	c.CurrentId = sid
	if sid then
		local s = Instance.new("Sound")
		s.SoundId = sid
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = c.Group
		s.Parent = c.Group
		s:Play()
		TweenService:Create(s, fade, { Volume = volume or 1 }):Play()
		c.Current = s
	end
end

local function inArena(): boolean
	if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" then
		return false
	end
	local role = player:GetAttribute(Attributes.Role)
	return role == "DisasterGod" or (role == "Survivor" and player:GetAttribute(Attributes.Alive) == true)
end

local function evaluate()
	local music = channel("Music", A.Volume.Music)
	local ambience = channel("Ambience", A.Volume.Ambience)
	local layer = channel("AmbienceLayer", A.Volume.Ambience * 0.6)
	if inArena() then
		local sudden = ReplicatedStorage:GetAttribute(Attributes.SubPhase) == "SuddenDeath"
		crossfade(music, if sudden then A.Music.SuddenDeath else A.Music.Round)
		local key = ReplicatedStorage:GetAttribute(Attributes.MapKey)
		local mapKey = if typeof(key) == "string" then key else ""
		crossfade(ambience, A.Ambience[mapKey] or A.Ambience.Lobby)
		crossfade(layer, A.AmbienceLayer[mapKey])
	else
		crossfade(music, A.Music.Lobby)
		crossfade(ambience, A.Ambience.Lobby)
		crossfade(layer, nil)
	end
end

local lastTick = -1

local function onTimer()
	local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining) :: number? or 0
	if t == lastTick then
		return
	end
	lastTick = t
	if phase == "Intermission" and t > 0 and t <= A.CountdownTicks then
		-- rising pitch as the round approaches
		Sound.play("Tick", 1, 1 + (A.CountdownTicks - t) * 0.08)
	elseif phase == "Active" and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) ~= true then
		local untilCast = t - (Config.Match.RoundDuration - Config.Match.PrepDuration)
		if untilCast > 0 and untilCast <= 3 then
			Sound.play("Tock", 1, 0.9)
		end
	elseif phase == "Active" and t > 0 and t <= 5 then
		Sound.play("Tick", 0.8, 1.3)
	end
end

function AudioController.Start()
	if started then
		return
	end
	started = true

	local previousPhase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(function()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		if phase == "Active" and previousPhase ~= "Active" then
			Sound.play("RoundStart", 1)
			if player:GetAttribute(Attributes.Role) == "DisasterGod" then
				Sound.play("GodChosen", 0.9)
			end
		end
		previousPhase = phase
		evaluate()
	end)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.SubPhase):Connect(function()
		if ReplicatedStorage:GetAttribute(Attributes.SubPhase) == "SuddenDeath" then
			local s = Instance.new("Sound")
			s.SoundId = Sound.idOf(A.Disaster.SuddenDeathAlarm)
			s.Volume = 0.9
			s.Parent = SoundService
			s:Play()
			task.delay(1, function()
				s:Play()
			end)
			task.delay(4, function()
				s:Destroy()
			end)
		end
		evaluate()
	end)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.MapKey):Connect(evaluate)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.TimeRemaining):Connect(onTimer)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluate)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(evaluate)

	Remotes.get("RoundSummary").OnClientEvent:Connect(function(summary)
		if typeof(summary) ~= "table" then
			return
		end
		local won = summary.Survived == true or summary.Role == "DisasterGod"
		Sound.play(if won then "Win" else "Lose", 1)
	end)

	evaluate()
end

return AudioController
