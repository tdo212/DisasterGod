--!strict
-- AudioService: positional world sounds for disasters and destruction (server-side,
-- replicated to everyone). Keys come from Config.Audio.Disaster; material break
-- one-shots come from Config.Audio.Break.
--
-- Mixing: every one-shot is scaled by Config.Audio.Mix.Scale and clamped to Mix.Max,
-- and at most Mix.MaxVoices world sounds play at once, so a ten-building collapse is
-- loud and layered but never deafening.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local A = Config.Audio
local MIX = A.Mix

local AudioService = {}

local group: SoundGroup? = nil
local holderFolder: Folder? = nil
local lastPlayed: { [string]: number } = {}
local voices = 0
local GLOBAL_SOUND_LIFETIME = 40
local VOICE_SECONDS = 2.5 -- a one-shot counts against the voice cap for this long

local function soundGroup(): SoundGroup
	if not group then
		local g = SoundService:FindFirstChild("DisasterSounds") :: SoundGroup?
		if not g then
			g = Instance.new("SoundGroup")
			g.Name = "DisasterSounds"
			g.Parent = SoundService
		end
		(g :: SoundGroup).Volume = A.Volume.Disaster
		-- soft limiter so stacked impacts don't clip
		if not (g :: SoundGroup):FindFirstChildOfClass("CompressorSoundEffect") then
			local c = Instance.new("CompressorSoundEffect")
			c.Threshold = -14
			c.Ratio = 4
			c.Attack = 0.01
			c.Release = 0.2
			c.Parent = g
		end
		group = g
	end
	return group :: SoundGroup
end

local function holders(): Folder
	if not holderFolder or not holderFolder.Parent then
		local f = workspace:FindFirstChild("WorldSounds") :: Folder?
		if not f then
			f = Instance.new("Folder")
			f.Name = "WorldSounds"
			f.Parent = workspace
		end
		holderFolder = f
	end
	return holderFolder :: Folder
end

function AudioService.idOf(value: number | string): string
	return if typeof(value) == "number" then "rbxassetid://" .. tostring(value) else value :: string
end

local function mixed(volume: number): number
	return math.min(volume * MIX.Scale, MIX.Max)
end

local function newSound(name: string, id: number | string, volume: number, speed: number?, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = AudioService.idOf(id)
	s.Volume = mixed(volume)
	s.PlaybackSpeed = speed or 1
	s.Looped = looped == true
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = MIX.RollOffMin
	s.RollOffMaxDistance = MIX.RollOffMax
	s.SoundGroup = soundGroup()
	return s
end

local function makeSound(key: string, volume: number, speed: number?, looped: boolean?): Sound?
	local id = A.Disaster[key]
	if not id then
		return nil
	end
	return newSound(key, id, volume, speed, looped)
end

local function takeVoice(): boolean
	if voices >= MIX.MaxVoices then
		return false
	end
	voices += 1
	task.delay(VOICE_SECONDS, function()
		voices -= 1
	end)
	return true
end

local function throttled(key: string, cooldown: number?): boolean
	if not cooldown then
		return false
	end
	local now = os.clock()
	if (lastPlayed[key] or 0) + cooldown > now then
		return true
	end
	lastPlayed[key] = now
	return false
end

local function playOnHolder(s: Sound, position: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "Sound_" .. s.Name
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = holders()
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 12)
end

-- One-shot sound at a world position. `cooldown` throttles repeats of the same key.
function AudioService.playAt(key: string, position: Vector3, volume: number?, speed: number?, cooldown: number?)
	if throttled(key, cooldown) or not takeVoice() then
		return
	end
	local s = makeSound(key, volume or 1, speed)
	if s then
		playOnHolder(s, position)
	end
end

-- A part of `material` broke at `position`: a random crack / clang / shatter for its
-- material family (Config.Audio.BreakMaterials), throttled per family.
function AudioService.playBreak(material: Enum.Material, position: Vector3, volume: number?)
	local family = A.BreakMaterials[material.Name] or "Stone"
	local pool = A.Break[family]
	if not pool or #pool == 0 or throttled("Break_" .. family, A.BreakCooldown) or not takeVoice() then
		return
	end
	local id = pool[math.random(1, #pool)]
	local s = newSound("Break_" .. family, id, (volume or 1) * A.BreakVolume / MIX.Scale, 0.88 + math.random() * 0.25)
	playOnHolder(s, position)
end

-- Non-positional sound everyone hears at the same volume (sirens). Looped sounds are
-- returned so the caller can destroy them.
function AudioService.playGlobal(key: string, volume: number?, looped: boolean?): Sound?
	local s = makeSound(key, volume or 1, 1, looped)
	if not s then
		return nil
	end
	s.Parent = holders()
	s:Play()
	if not looped then
		Debris:AddItem(s, GLOBAL_SOUND_LIFETIME)
	end
	return s
end

-- Sound attached to a part (follows it). Looped sounds stop when the part is destroyed.
function AudioService.attach(key: string, part: BasePart, volume: number?, looped: boolean?, speed: number?): Sound?
	local s = makeSound(key, volume or 1, speed, looped)
	if not s then
		return nil
	end
	s.Parent = part
	s:Play()
	return s
end

return AudioService
