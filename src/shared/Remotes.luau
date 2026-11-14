--!strict
-- Single place that declares every RemoteEvent. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"CastDisaster", -- C->S (abilityId, target: Vector3, direction: Vector3)
	"BuyGear", -- C->S (gearId)
	"UseGear", -- C->S (gearId)
	"SetSoloRole", -- C->S (role)
	"GhostPing", -- C->S (position)
	"Popup", -- S->C (text, color)
	"Banner", -- S->C (title, subtitle, color)
	"ClientEffect", -- S->C (kind, ...)
	"RoundSummary", -- S->C (summary)
	"SpinRequest", -- C->S ()
	"SpinResult", -- S->C (rewardIndex, text)
	"KitAction", -- C->S ("Buy" | "Equip", kitId)
	"QuestClaim", -- C->S (questId)
	"TutorialSeen", -- C->S (kind)
	"Rubble", -- S->C ({ { CFrame, Size, Color, Material, Transparency, Velocity } }) cosmetic debris, batched per frame
	"Emote", -- C->S (emoteId) taunt wheel
	"Feed", -- S->C (text, color) kill feed / clutch callouts
	"CosmeticAction", -- C->S ("Buy" | "Equip", cosmeticId) coin cosmetics + equipping
	"MapVote", -- C->S (candidateIndex) intermission map vote
	"Cheer", -- C->S (kind, targetUserId) spectator cheers / aid, paid in coins
	"ClaimStreak", -- C->S () open today's lodge streak chest
	"SaveSetting", -- C->S (key, value) quick settings (LowFx, Shake, Music, Sfx)
	"Analytics", -- C->S (event, detail?) UI-only funnel steps (Config.Analytics.ClientEvents)
}

-- High-rate, loss-tolerant streams (UnreliableRemoteEvent): a dropped update is simply
-- replaced by the next one.
local UNRELIABLE = {
	"GodAim", -- C->S (Vector3) the God's reticle, max 10 Hz, only after moving 1.5 studs
	"GodAimRelay", -- S->C (Vector3) the latest aim (human God or AI Director) for the sky rig
}

local Remotes = {}

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		folder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
		folder = f
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in UNRELIABLE do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("UnreliableRemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.get(name: string): RemoteEvent
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	assert(remote and remote:IsA("RemoteEvent"), "Unknown remote " .. name)
	return remote
end

function Remotes.unreliable(name: string): UnreliableRemoteEvent
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	assert(remote and remote:IsA("UnreliableRemoteEvent"), "Unknown unreliable remote " .. name)
	return remote
end

return Remotes
