--!strict
-- SpinService: the prize wheel. Players bank spins (a free one every few minutes, more from
-- Robux products and daily quests). The server rolls the weighted reward, grants it at
-- once and tells the client which segment to land on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService = require(script.Parent.QuestService)
local RoleService = require(script.Parent.RoleService)
local ShopService = require(script.Parent.ShopService)

local S = Config.Spin
local Attributes = Config.Attributes

local SpinService = {}

local popup = Remotes.get("Popup")
local result = Remotes.get("SpinResult")
local busyUntil: { [Player]: number } = {}
local rng = Random.new()

local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(255, 80, 80)
local PURPLE = Color3.fromRGB(200, 130, 255)

local totalWeight = 0
for _, reward in S.Rewards do
	totalWeight += reward.Weight
end

local function interval(player: Player): number
	local vip = player:GetAttribute(Attributes.PassPrefix .. "VIP") == true
	return S.FreeIntervalSeconds * (if vip then S.VipIntervalMultiplier else 1)
end

local function accrue(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local now = workspace:GetServerTimeNow()
	if profile.FreeSpinAt <= 0 then
		PlayerDataService.SetFreeSpinAt(player, now + interval(player))
	elseif now >= profile.FreeSpinAt and profile.Spins < S.MaxBankedFree then
		PlayerDataService.AddSpins(player, 1)
		PlayerDataService.SetFreeSpinAt(player, now + interval(player))
		popup:FireClient(player, "+1 FREE SPIN!", GOLD)
	end
end

local function roll(): number
	local pick = rng:NextNumber() * totalWeight
	for i, reward in S.Rewards do
		pick -= reward.Weight
		if pick <= 0 then
			return i
		end
	end
	return #S.Rewards
end

local function grant(player: Player, reward: Types.SpinReward): (string, Color3)
	if reward.Kind == "Coins" then
		PlayerDataService.AddCoins(player, reward.Amount)
		return string.format("WHEEL WIN +%d COINS", reward.Amount), GOLD
	elseif reward.Kind == "Kit" then
		ShopService.GrantKit(player)
		return "WHEEL WIN: SURVIVAL KIT", Color3.fromRGB(120, 255, 160)
	end
	RoleService.QueueGod(player)
	return "WHEEL WIN: YOU'RE THE NEXT GOD!", PURPLE
end

local function onRequest(player: Player)
	local now = os.clock()
	if (busyUntil[player] or 0) > now then
		return
	end
	if not PlayerDataService.UseSpin(player) then
		popup:FireClient(player, "NOT ENOUGH SPINS", RED)
		return
	end
	busyUntil[player] = now + S.SpinSeconds
	local index = roll()
	local text, color = grant(player, S.Rewards[index])
	result:FireClient(player, index, text, color)
	QuestService.Progress(player, "Spin", 1)
	PlayerDataService.SaveNow(player)
end

-- Robux spin packs.
function SpinService.AddSpins(player: Player, count: number)
	PlayerDataService.AddSpins(player, count)
	popup:FireClient(player, string.format("+%d SPIN%s — THANK YOU!", count, if count == 1 then "" else "S"), GOLD)
end

function SpinService.Init()
	Remotes.get("SpinRequest").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				accrue(player)
			end
		end
	end)
end

return SpinService
