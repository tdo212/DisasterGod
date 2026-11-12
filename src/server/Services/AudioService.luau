--!strict
-- AudioService: positional world sounds for disasters and destruction (server-side,
-- replicated to everyone). Keys come from Config.Audio.Disaster.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local A = Config.Audio

local AudioService = {}

local group: SoundGroup? = nil
local holderFolder: Folder? = nil
local lastPlayed: { [string]: number } = {}

local function soundGroup(): SoundGroup
	if not group then
		local g = SoundService:FindFirstChild("DisasterSounds") :: SoundGroup?
		if not g then
			g = Instance.new("SoundGroup")
			g.Name = "DisasterSounds"
			g.Volume = A.Volume.Disaster
			g.Parent = SoundService
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

local function makeSound(key: string, volume: number, speed: number?, looped: boolean?): Sound?
	local id = A.Disaster[key]
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = AudioService.idOf(id)
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = A.RollOffMaxDistance
	s.RollOffMinDistance = 20
	s.SoundGroup = soundGroup()
	return s
end

-- One-shot sound at a world position. `cooldown` throttles repeats of the same key.
function AudioService.playAt(key: string, position: Vector3, volume: number?, speed: number?, cooldown: number?)
	if cooldown then
		local now = os.clock()
		if (lastPlayed[key] or 0) + cooldown > now then
			return
		end
		lastPlayed[key] = now
	end
	local s = makeSound(key, volume or 1, speed)
	if not s then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "Sound_" .. key
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
