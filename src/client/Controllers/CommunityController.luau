--!strict
-- CommunityController: the client half of CommunityService.
--   * The lodge's community board prompt opens Roblox's join-group prompt, then asks the
--     server for the reward (the server checks membership itself and pays once).
--   * "Favorite" from the server shows Roblox's favourite prompt for this game (once ever,
--     unrewarded).
--   * After the reward is claimed the board's prompt says so and switches off.

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local Attributes = Config.Attributes
local player = Players.LocalPlayer

local CommunityController = {}

local busy = false

local function groupId(): number
	local id = ReplicatedStorage:GetAttribute(Attributes.CommunityGroupId)
	return if typeof(id) == "number" then id else 0
end

local function claimed(): boolean
	return player:GetAttribute(Attributes.CommunityClaimed) == true
end

local function onBoard()
	local id = groupId()
	if busy or id <= 0 then
		return
	end
	busy = true
	if not claimed() then
		local member = false
		pcall(function()
			member = player:IsInGroup(id)
		end)
		if not member then
			-- yields until the player answers Roblox's prompt
			pcall(function()
				GroupService:PromptJoinAsync(id)
			end)
		end
	end
	Remotes.get("CommunityClaim"):FireServer()
	busy = false
end

-- (checking for an existing favourite needs an inventory-read permission prompt of its own,
-- so we don't: a player who already favourited just closes Roblox's prompt)
local function onFavorite()
	pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
end

-- the board prompt reads "Claimed" (and switches off) once the reward is paid
local function refreshPrompt(prompt: ProximityPrompt)
	if claimed() then
		prompt.ActionText = "Claimed ✓"
		prompt.Enabled = false
	end
end

function CommunityController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "CommunityPrompt" then
			task.spawn(onBoard)
		end
	end)
	Remotes.get("CommunityPrompt").OnClientEvent:Connect(function(kind: any)
		if kind == "Favorite" then
			task.spawn(onFavorite)
		end
	end)
	task.spawn(function()
		-- the lodge builds over a few frames (and streams in): wait for the board's prompt
		local found: Instance? = nil
		for _ = 1, 120 do
			local lodge = workspace:FindFirstChild("SkyLodge")
			found = lodge and lodge:FindFirstChild("CommunityPrompt", true)
			if found then
				break
			end
			task.wait(0.5)
		end
		if found and found:IsA("ProximityPrompt") then
			local prompt = found
			refreshPrompt(prompt)
			player:GetAttributeChangedSignal(Attributes.CommunityClaimed):Connect(function()
				refreshPrompt(prompt)
			end)
		end
	end)
end

return CommunityController
