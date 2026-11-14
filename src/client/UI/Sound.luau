--!strict
-- UI sound effects (client-local, 2D). Keys come from Config.Audio.Ui / Stings / Disaster.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript)

local A = Config.Audio

local Sound = {}

local group: SoundGroup? = nil
local templates: { [string]: Sound } = {}

local function idOf(value: number | string): string
	return if typeof(value) == "number" then "rbxassetid://" .. tostring(value) else value :: string
end

function Sound.idOf(value: number | string): string
	return idOf(value)
end

local function uiGroup(): SoundGroup
	if not group then
		local g = Instance.new("SoundGroup")
		g.Name = "UiSounds"
		g.Volume = A.Volume.Ui
		g.Parent = SoundService
		group = g
	end
	return group :: SoundGroup
end

local function template(key: string): Sound?
	local existing = templates[key]
	if existing then
		return existing
	end
	local id = A.Ui[key] or (A.Stings :: any)[key] or A.Disaster[key]
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = idOf(id)
	s.SoundGroup = uiGroup()
	s.Parent = uiGroup()
	templates[key] = s
	return s
end

-- Fire-and-forget UI sound. Overlapping plays use clones so rapid clicks don't cut off.
function Sound.play(key: string, volume: number?, pitch: number?)
	local base = template(key)
	if not base then
		return
	end
	local s = base:Clone()
	s.Volume = volume or 1
	s.PlaybackSpeed = pitch or 1
	s.Parent = uiGroup()
	s:Play()
	Debris:AddItem(s, math.max(2, s.TimeLength + 0.5))
end

return Sound
