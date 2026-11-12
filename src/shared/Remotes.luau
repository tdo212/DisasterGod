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
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.get(name: string): RemoteEvent
	local remote = if RunService:IsServer() then folder:FindFirstChild(name) else folder:WaitForChild(name)
	assert(remote and remote:IsA("RemoteEvent"), "Unknown remote " .. name)
	return remote
end

return Remotes
