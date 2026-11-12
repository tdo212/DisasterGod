--!strict
-- PlayerDataService: per-player profile (coins, streaks, owned gear).
-- Persists through DataStoreService on published places; in-memory in unpublished Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

local Attributes = Config.Attributes
local STORE_NAME = "DisasterGodProfiles_v1"

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function defaultProfile(): Profile
	local gear = {}
	for _, def in Config.Gear do
		gear[def.Id] = 0
	end
	return {
		Coins = 0,
		Wins = 0,
		Streak = 0,
		BestStreak = 0,
		RoundsSurvived = 0,
		Gear = gear,
	}
end

local function publish(player: Player, profile: Profile)
	player:SetAttribute(Attributes.Coins, profile.Coins)
	player:SetAttribute(Attributes.Streak, profile.Streak)
	for id, count in profile.Gear do
		player:SetAttribute(Attributes.GearPrefix .. id, count)
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local coins = stats:FindFirstChild("Coins") :: IntValue?
		local survived = stats:FindFirstChild("Survived") :: IntValue?
		if coins then
			coins.Value = profile.Coins
		end
		if survived then
			survived.Value = profile.RoundsSurvived
		end
	end
end

local function load(player: Player): Profile
	local profile = defaultProfile()
	if store then
		local ok, data = pcall(function()
			return (store :: DataStore):GetAsync(tostring(player.UserId))
		end)
		if ok and typeof(data) == "table" then
			for key, value in data do
				if key == "Gear" and typeof(value) == "table" then
					for id, count in value do
						if typeof(count) == "number" then
							profile.Gear[id] = count
						end
					end
				elseif typeof((profile :: any)[key]) == "number" and typeof(value) == "number" then
					(profile :: any)[key] = value
				end
			end
		elseif not ok then
			warn("[PlayerData] load failed for", player.UserId, data)
		end
	end
	return profile
end

local function save(player: Player)
	local profile = profiles[player]
	if not (store and profile) then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(tostring(player.UserId), profile)
	end)
	if not ok then
		warn("[PlayerData] save failed for", player.UserId, err)
	end
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local survived = Instance.new("IntValue")
	survived.Name = "Survived"
	survived.Parent = stats
	stats.Parent = player

	local profile = load(player)
	if player.Parent then
		profiles[player] = profile
		publish(player, profile)
	end
end

function PlayerDataService.Init()
	-- Studio sessions and unpublished places stay in-memory (no API access errors while testing).
	if game.PlaceId ~= 0 and not game:GetService("RunService"):IsStudio() then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		for player in profiles do
			save(player)
		end
	end)
end

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	profile.Coins = math.max(0, math.floor(profile.Coins + amount))
	publish(player, profile)
end

function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	publish(player, profile)
	return true
end

function PlayerDataService.AddGear(player: Player, gearId: string, count: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Gear[gearId] = (profile.Gear[gearId] or 0) + count
	publish(player, profile)
end

function PlayerDataService.ConsumeGear(player: Player, gearId: string): boolean
	local profile = profiles[player]
	if not profile or (profile.Gear[gearId] or 0) <= 0 then
		return false
	end
	profile.Gear[gearId] -= 1
	publish(player, profile)
	return true
end

-- Records survival result; returns the new streak.
function PlayerDataService.RecordRound(player: Player, survived: boolean): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	if survived then
		profile.Streak += 1
		profile.RoundsSurvived += 1
		profile.BestStreak = math.max(profile.BestStreak, profile.Streak)
	else
		profile.Streak = 0
	end
	publish(player, profile)
	return profile.Streak
end

function PlayerDataService.RecordWin(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Wins += 1
	end
end

return PlayerDataService
