--!strict
-- PlayerDataService: per-player profile (coins, streaks, gear, spins, kits, quests).
-- Persists through DataStoreService on published places; in-memory in Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

local Attributes = Config.Attributes
local STORE_NAME = "DisasterGodProfiles_v1"

local AnalyticsService = require(script.Parent.AnalyticsService)

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local loaded = Instance.new("BindableEvent")
-- Fired as (player) once a profile is ready.
PlayerDataService.ProfileLoaded = loaded.Event

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
		RoundsPlayed = 0,
		GodKills = 0,
		Spins = Config.Spin.StarterSpins,
		FreeSpinAt = 0,
		Kit = Config.DefaultKit,
		Kits = { [Config.DefaultKit] = true },
		Tutorials = {},
		Quests = { Day = 0, Progress = {}, Claimed = {}, Streak = 0, LastAllDoneDay = 0 },
		Gear = gear,
		WelcomeClaimed = false,
		Receipts = {},
		Cosmetics = {},
		Equipped = table.clone(Config.Cosmetics.Defaults),
		Saves = { Glider = 0, Aegis = 0 },
		Mastery = {},
		LoginDay = 0,
		LoginStreak = 0,
		StreakClaimedDay = 0,
		FirstSurviveDay = 0,
		FirstGodWinDay = 0,
		GoldenTrail = false,
		Set_LowFx = false,
		Set_Shake = 1,
		Set_Music = true,
		Set_Sfx = true,
	}
end

-- Free starters are always owned.
local function isFree(def: any): boolean
	return def.Coins == nil and def.Product == nil
end

local function publish(player: Player, profile: Profile)
	player:SetAttribute(Attributes.Coins, profile.Coins)
	player:SetAttribute(Attributes.Streak, profile.Streak)
	player:SetAttribute(Attributes.WelcomeClaimed, profile.WelcomeClaimed)
	player:SetAttribute(Attributes.Spins, profile.Spins)
	player:SetAttribute(Attributes.FreeSpinAt, profile.FreeSpinAt)
	player:SetAttribute(Attributes.RoundsPlayed, profile.RoundsPlayed)
	player:SetAttribute(Attributes.Kit, profile.Kit)
	for id, count in profile.Gear do
		player:SetAttribute(Attributes.GearPrefix .. id, count)
	end
	for _, kit in Config.Kits do
		player:SetAttribute(Attributes.KitPrefix .. kit.Id, profile.Kits[kit.Id] == true)
	end
	for kind, seen in profile.Tutorials do
		player:SetAttribute(Attributes.TutorialPrefix .. kind, seen)
	end
	for _, def in Config.Cosmetics.Items do
		player:SetAttribute(Attributes.CosmeticPrefix .. def.Id, profile.Cosmetics[def.Id] == true or isFree(def))
	end
	for category, id in profile.Equipped do
		player:SetAttribute(Attributes.EquipPrefix .. category, id)
	end
	for kind, count in profile.Saves do
		player:SetAttribute(Attributes.SavePrefix .. kind, count)
	end
	player:SetAttribute(Attributes.GoldenTrail, profile.GoldenTrail)
	player:SetAttribute(Attributes.LoginStreak, profile.LoginStreak)
	for _, key in { "LowFx", "Shake", "Music", "Sfx" } do
		player:SetAttribute(Attributes.SettingPrefix .. key, (profile :: any)["Set_" .. key])
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

-- Copy primitive entries of `saved` whose type is `kind` into `into`.
local function copyMap(into: { [string]: any }, saved: any, kind: string)
	if typeof(saved) ~= "table" then
		return
	end
	for key, value in saved do
		if typeof(key) == "string" and typeof(value) == kind then
			into[key] = value
		end
	end
end

local function merge(profile: Profile, data: { [string]: any })
	for key, value in data do
		if key == "Gear" then
			copyMap(profile.Gear, value, "number")
		elseif key == "Kits" then
			copyMap(profile.Kits, value, "boolean")
		elseif key == "Tutorials" then
			copyMap(profile.Tutorials, value, "boolean")
		elseif key == "Cosmetics" then
			copyMap(profile.Cosmetics, value, "boolean")
		elseif key == "Equipped" then
			copyMap(profile.Equipped, value, "string")
		elseif key == "Saves" then
			copyMap(profile.Saves, value, "number")
		elseif key == "Mastery" then
			copyMap(profile.Mastery, value, "number")
		elseif key == "Receipts" and typeof(value) == "table" then
			for _, id in value do
				if typeof(id) == "string" then
					table.insert(profile.Receipts, id)
				end
			end
		elseif key == "Quests" and typeof(value) == "table" then
			local q = profile.Quests
			copyMap(q.Progress, value.Progress, "number")
			copyMap(q.Claimed, value.Claimed, "boolean")
			for _, field in { "Day", "Streak", "LastAllDoneDay" } do
				if typeof(value[field]) == "number" then
					(q :: any)[field] = value[field]
				end
			end
		else
			local current = (profile :: any)[key]
			local kind = typeof(current)
			if (kind == "number" or kind == "boolean" or kind == "string") and typeof(value) == kind then
				(profile :: any)[key] = value
			end
		end
	end
	profile.Kits[Config.DefaultKit] = true
	if not profile.Kits[profile.Kit] then
		profile.Kit = Config.DefaultKit
	end
	-- an equipped cosmetic that is no longer owned (or no longer exists) falls back
	for category, fallback in Config.Cosmetics.Defaults do
		local id = profile.Equipped[category]
		local ok = false
		for _, def in Config.Cosmetics.Items do
			if def.Id == id and def.Category == category and (profile.Cosmetics[id] or isFree(def)) then
				ok = true
			end
		end
		if not ok then
			profile.Equipped[category] = fallback
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
			merge(profile, data)
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
		loaded:Fire(player)
	end
end

function PlayerDataService.Init()
	-- Studio sessions and unpublished places stay in-memory (no API access errors while testing).
	if PlayerDataService.UsesDataStores() then
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

-- True on live servers; Studio and unpublished places keep everything in memory.
function PlayerDataService.UsesDataStores(): boolean
	return game.PlaceId ~= 0 and not game:GetService("RunService"):IsStudio()
end

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Re-publish attributes after a caller edits the profile table directly.
function PlayerDataService.Publish(player: Player)
	local profile = profiles[player]
	if profile then
		publish(player, profile)
	end
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount == 0 then
		return
	end
	profile.Coins = math.max(0, math.floor(profile.Coins + amount))
	publish(player, profile)
end

-- Coins earned through play: doubled for 2x Coins pass owners. Returns the amount paid.
function PlayerDataService.EarnCoins(player: Player, amount: number): number
	local mult = if player:GetAttribute(Attributes.PassPrefix .. "DoubleCoins") == true
		then Config.Monetization.DoubleCoinsMultiplier
		else 1
	local paid = math.floor(amount * mult)
	PlayerDataService.AddCoins(player, paid)
	return paid
end

function PlayerDataService.HasReceipt(player: Player, purchaseId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and table.find(profile.Receipts, purchaseId) ~= nil
end

function PlayerDataService.AddReceipt(player: Player, purchaseId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > Config.Monetization.ReceiptHistory do
		table.remove(profile.Receipts, 1)
	end
end

function PlayerDataService.MarkWelcomeClaimed(player: Player)
	local profile = profiles[player]
	if profile then
		profile.WelcomeClaimed = true
		publish(player, profile)
	end
end

-- Persist right away (after Robux purchases).
function PlayerDataService.SaveNow(player: Player)
	task.spawn(save, player)
end

-- `sku` names what the coins bought (economy analytics; optional).
function PlayerDataService.SpendCoins(player: Player, amount: number, sku: string?): boolean
	local profile = profiles[player]
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	publish(player, profile)
	AnalyticsService.CoinsSpent(player, amount, sku)
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

---------------------------------------------------------------------------
-- spins

function PlayerDataService.AddSpins(player: Player, count: number)
	local profile = profiles[player]
	if profile then
		profile.Spins = math.max(0, profile.Spins + count)
		publish(player, profile)
	end
end

function PlayerDataService.UseSpin(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.Spins <= 0 then
		return false
	end
	profile.Spins -= 1
	publish(player, profile)
	return true
end

function PlayerDataService.SetFreeSpinAt(player: Player, when: number)
	local profile = profiles[player]
	if profile then
		profile.FreeSpinAt = when
		publish(player, profile)
	end
end

---------------------------------------------------------------------------
-- kits + tutorials

function PlayerDataService.OwnsKit(player: Player, kitId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Kits[kitId] == true
end

function PlayerDataService.GrantKit(player: Player, kitId: string)
	local profile = profiles[player]
	if profile then
		profile.Kits[kitId] = true
		publish(player, profile)
	end
end

function PlayerDataService.EquipKit(player: Player, kitId: string): boolean
	local profile = profiles[player]
	if not profile or not profile.Kits[kitId] then
		return false
	end
	profile.Kit = kitId
	publish(player, profile)
	return true
end

---------------------------------------------------------------------------
-- cosmetics and panic saves

local function cosmeticDef(id: string): Types.CosmeticDefinition?
	for _, def in Config.Cosmetics.Items do
		if def.Id == id then
			return def
		end
	end
	return nil
end

function PlayerDataService.OwnsCosmetic(player: Player, id: string): boolean
	local profile = profiles[player]
	local def = cosmeticDef(id)
	return profile ~= nil and def ~= nil and (profile.Cosmetics[id] == true or isFree(def))
end

function PlayerDataService.GrantCosmetic(player: Player, id: string)
	local profile = profiles[player]
	if profile and cosmeticDef(id) then
		profile.Cosmetics[id] = true
		player:SetAttribute(Attributes.CosmeticPrefix .. id, true)
	end
end

function PlayerDataService.EquipCosmetic(player: Player, id: string): boolean
	local profile = profiles[player]
	local def = cosmeticDef(id)
	if not (profile and def and PlayerDataService.OwnsCosmetic(player, id)) then
		return false
	end
	profile.Equipped[def.Category] = id
	player:SetAttribute(Attributes.EquipPrefix .. def.Category, id)
	return true
end

function PlayerDataService.GetEquipped(player: Player, category: string): string
	local profile = profiles[player]
	return (profile and profile.Equipped[category]) or Config.Cosmetics.Defaults[category]
end

function PlayerDataService.AddSave(player: Player, kind: string, count: number)
	local profile = profiles[player]
	if profile then
		profile.Saves[kind] = (profile.Saves[kind] or 0) + count
		player:SetAttribute(Attributes.SavePrefix .. kind, profile.Saves[kind])
	end
end

function PlayerDataService.UseSave(player: Player, kind: string): boolean
	local profile = profiles[player]
	if not profile or (profile.Saves[kind] or 0) <= 0 then
		return false
	end
	profile.Saves[kind] -= 1
	player:SetAttribute(Attributes.SavePrefix .. kind, profile.Saves[kind])
	return true
end

function PlayerDataService.MarkTutorial(player: Player, kind: string)
	local profile = profiles[player]
	if profile then
		profile.Tutorials[kind] = true
		publish(player, profile)
	end
end

---------------------------------------------------------------------------
-- round records

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

function PlayerDataService.RecordPlayed(player: Player)
	local profile = profiles[player]
	if profile then
		profile.RoundsPlayed += 1
		publish(player, profile)
	end
end

function PlayerDataService.RecordGodKill(player: Player)
	local profile = profiles[player]
	if profile then
		profile.GodKills += 1
	end
end

function PlayerDataService.RecordWin(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Wins += 1
	end
end

return PlayerDataService
