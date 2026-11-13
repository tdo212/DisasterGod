--!strict
-- ShowdownService: the Last Stand. When a round that started with 2+ survivors is down
-- to one and at least Config.Showdown.MinSecondsLeft remain:
--   * everyone gets a LAST STAND banner and a kill-feed line, a heartbeat loops and the
--     music switches to the boss track (AudioController reads the LastStand attribute);
--   * the God is shown the survivor's general zone every few seconds (offset, not exact);
--   * the survivor's dash recharges twice as fast and near misses pay double.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AudioService = require(script.Parent.AudioService)
local RoleService = require(script.Parent.RoleService)

local SD = Config.Showdown
local Attributes = Config.Attributes
local GOLD = Color3.fromRGB(255, 200, 40)

local ShowdownService = {}

local peakAlive = 0
local survivor: Player? = nil
local heartbeat: Sound? = nil
local runId = 0

local function stop()
	runId += 1
	if heartbeat then
		heartbeat:Destroy()
		heartbeat = nil
	end
	if survivor then
		survivor:SetAttribute(Attributes.LastStander, nil)
	end
	survivor = nil
	ReplicatedStorage:SetAttribute(Attributes.LastStand, "")
end

-- Round start / end.
function ShowdownService.Reset()
	stop()
	peakAlive = 0
end

function ShowdownService.IsActive(): boolean
	return survivor ~= nil
end

local function zoneLoop(target: Player, id: number)
	local clientEffect = Remotes.get("ClientEffect")
	while runId == id and RoleService.IsAliveSurvivor(target) do
		local god = RoleService.GetGod()
		local character = target.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if god and hrp then
			local a = math.random() * math.pi * 2
			local r = math.random() * SD.ZoneJitter
			local center = hrp.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			clientEffect:FireClient(god, "Zone", center, SD.ZoneRadius, SD.ZoneInterval)
		end
		task.wait(SD.ZoneInterval)
	end
end

local function trigger(target: Player)
	survivor = target
	target:SetAttribute(Attributes.LastStander, true)
	ReplicatedStorage:SetAttribute(Attributes.LastStand, target.DisplayName)
	Remotes.get("Banner"):FireAllClients("⚔️ LAST STAND", target.DisplayName .. " is the last survivor!", GOLD)
	Remotes.get("Feed"):FireAllClients(string.format("⚔️ LAST STAND: %s vs the God", target.DisplayName), GOLD)
	heartbeat = AudioService.playGlobal("Heartbeat", SD.HeartbeatVolume, true)
	task.spawn(zoneLoop, target, runId)
end

-- Called every match tick while a round is active.
function ShowdownService.Update(alive: { Player }, timeRemaining: number)
	peakAlive = math.max(peakAlive, #alive)
	if survivor then
		if not RoleService.IsAliveSurvivor(survivor) then
			stop()
		end
		return
	end
	if peakAlive >= 2 and #alive == 1 and timeRemaining >= SD.MinSecondsLeft then
		trigger(alive[1])
	end
end

function ShowdownService.Init()
	ReplicatedStorage:SetAttribute(Attributes.LastStand, "")
end

return ShowdownService
