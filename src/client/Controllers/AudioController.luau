--!strict
-- AudioController: adaptive music + environment ambience + round-flow cues.
--   Music:    lobby playlist in the Sky Lodge, tense playlist in the arena, boss track in
--             sudden death (crossfaded; each track plays through, then the next).
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

-- Crossfade a channel to a track (nil = silence). Looping unless `looped` is false.
local function crossfade(c: Channel, id: (number | string)?, volume: number?, looped: boolean?): Sound?
	local sid = if id then Sound.idOf(id) else nil
	if sid == c.CurrentId then
		return c.Current
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
		s.Looped = looped ~= false
		s.Volume = 0
		s.SoundGroup = c.Group
		s.Parent = c.Group
		s:Play()
		TweenService:Create(s, fade, { Volume = volume or 1 }):Play()
		c.Current = s
	end
	return c.Current
end

-- Music playlists (Config.Audio.Music): a track plays through, then the next one starts.
-- A list of one loops. A track that fails to load is skipped.
local playlist: string? = nil
local trackIndex = 0

local function playTrack(c: Channel)
	local name = playlist
	local list = if name then A.Music[name] else nil
	if not (name and list and #list > 0) then
		crossfade(c, nil)
		return
	end
	local single = #list == 1
	local s = crossfade(c, list[trackIndex], nil, single)
	if single or not s then
		return
	end
	local function advance()
		if playlist == name and c.Current == s then
			trackIndex = trackIndex % #list + 1
			playTrack(c)
		end
	end
	s.Ended:Once(advance)
	task.delay(A.MusicLoadTimeout, function()
		if not s.IsLoaded then
			advance()
		end
	end)
end

local function playList(c: Channel, name: string)
	if playlist == name then
		return
	end
	playlist = name
	local list = A.Music[name]
	trackIndex = if list and #list > 0 then math.random(1, #list) else 1
	playTrack(c)
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
		-- the boss track for Sudden Death and for a Last Stand showdown
		local lastStand = ReplicatedStorage:GetAttribute(Attributes.LastStand)
		local sudden = ReplicatedStorage:GetAttribute(Attributes.SubPhase) == "SuddenDeath" or (typeof(lastStand) == "string" and lastStand ~= "")
		playList(music, if sudden then "SuddenDeath" else "Round")
		local key = ReplicatedStorage:GetAttribute(Attributes.MapKey)
		local mapKey = if typeof(key) == "string" then key else ""
		crossfade(ambience, A.Ambience[mapKey] or A.Ambience.Lobby)
		crossfade(layer, A.AmbienceLayer[mapKey])
	else
		playList(music, "Lobby")
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
	if phase == "Intermission" and t > 3 and t <= A.CountdownTicks then
		-- rising pitch as the round approaches
		Sound.play("Tick", 1, 1 + (A.CountdownTicks - t) * 0.08)
	elseif phase == "Intermission" and t == 3 then
		Sound.play("Countdown", 1) -- one "3, 2, 1" clip covers the last three seconds
	elseif phase == "Active" and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) ~= true then
		local untilCast = t - (Config.Match.RoundDuration - Config.Match.PrepDuration)
		if untilCast == 3 then
			Sound.play("Countdown", 1)
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
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.LastStand):Connect(evaluate)
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
