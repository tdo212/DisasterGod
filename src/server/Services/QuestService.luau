--!strict
-- QuestService: three daily quests (two from the pool + "survive on the map of the day").
-- Other services report progress with QuestService.Progress(player, stat, amount).
-- Claiming pays coins; finishing all three in a day grants a wheel spin and builds a streak.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local PlayerDataService = require(script.Parent.PlayerDataService)

type Quest = Types.QuestDefinition

local Q = Config.Quests
local Attributes = Config.Attributes

local QuestService = {}

local popup = Remotes.get("Popup")
local GOLD = Color3.fromRGB(255, 210, 60)
local GREEN = Color3.fromRGB(120, 255, 140)

local cachedDay = -1
local cachedList: { Quest } = {}

local function today(): number
	return math.floor(os.time() / Q.DaySeconds)
end

-- Same three quests for everyone on a given day.
local function dailyQuests(day: number): { Quest }
	if day == cachedDay then
		return cachedList
	end
	local rng = Random.new(day)
	local pool = table.clone(Q.Pool)
	local list: { Quest } = {}
	for _ = 1, math.min(Q.RandomPerDay, #pool) do
		table.insert(list, table.remove(pool, rng:NextInteger(1, #pool)) :: Quest)
	end
	local rotation = Config.World.MapRotation
	local key = rotation[day % #rotation + 1]
	table.insert(list, {
		Id = "Map_" .. key,
		Text = "Survive a round on " .. (Config.World.MapDisplayNames[key] or key),
		Stat = "Survive:" .. key,
		Goal = 1,
		Reward = Q.MapQuestReward,
	})
	cachedDay = day
	cachedList = list
	return list
end

-- Reset progress when the day rolls over. Returns today's day number.
local function roll(profile: Types.PlayerProfile): number
	local day = today()
	local q = profile.Quests
	if q.Day ~= day then
		q.Day = day
		table.clear(q.Progress)
		table.clear(q.Claimed)
		if q.LastAllDoneDay < day - 1 then
			q.Streak = 0
		end
	end
	return day
end

local function publish(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local day = roll(profile)
	local rows = {}
	for _, quest in dailyQuests(day) do
		table.insert(rows, {
			Id = quest.Id,
			Text = quest.Text,
			Goal = quest.Goal,
			Progress = math.min(quest.Goal, profile.Quests.Progress[quest.Stat] or 0),
			Reward = quest.Reward,
			Claimed = profile.Quests.Claimed[quest.Id] == true,
		})
	end
	player:SetAttribute(Attributes.QuestState, HttpService:JSONEncode({
		Streak = profile.Quests.Streak,
		ResetAt = (day + 1) * Q.DaySeconds,
		Quests = rows,
	}))
end

-- Report progress on a stat ("Survive", "NearMiss", "Survive:<MapKey>", ...).
function QuestService.Progress(player: Player, stat: string, amount: number?)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local day = roll(profile)
	for _, quest in dailyQuests(day) do
		if quest.Stat == stat then
			local before = profile.Quests.Progress[stat] or 0
			if before >= quest.Goal then
				return
			end
			local after = math.min(quest.Goal, before + (amount or 1))
			profile.Quests.Progress[stat] = after
			if after >= quest.Goal then
				popup:FireClient(player, "QUEST READY: " .. string.upper(quest.Text), GREEN)
			end
			publish(player)
			return
		end
	end
end

local function claim(player: Player, questId: string)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local day = roll(profile)
	local quests = dailyQuests(day)
	local q = profile.Quests
	for _, quest in quests do
		if quest.Id == questId then
			if q.Claimed[quest.Id] or (q.Progress[quest.Stat] or 0) < quest.Goal then
				return
			end
			q.Claimed[quest.Id] = true
			PlayerDataService.AddCoins(player, quest.Reward)
			popup:FireClient(player, string.format("QUEST CLAIMED +%d", quest.Reward), GOLD)
			break
		end
	end
	local allDone = true
	for _, quest in quests do
		if not q.Claimed[quest.Id] then
			allDone = false
			break
		end
	end
	if allDone and q.LastAllDoneDay ~= day then
		q.Streak = if q.LastAllDoneDay == day - 1 then q.Streak + 1 else 1
		q.LastAllDoneDay = day
		PlayerDataService.AddSpins(player, Q.AllDoneSpins)
		popup:FireClient(player, string.format("ALL QUESTS DONE! +%d SPIN", Q.AllDoneSpins), GOLD)
	end
	publish(player)
	PlayerDataService.SaveNow(player)
end

function QuestService.Init()
	PlayerDataService.ProfileLoaded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Remotes.get("QuestClaim").OnServerEvent:Connect(function(player, questId)
		if typeof(questId) == "string" then
			claim(player, questId)
		end
	end)
	-- catch the daily rollover for players who stay online
	task.spawn(function()
		local last = today()
		while true do
			task.wait(30)
			local day = today()
			if day ~= last then
				last = day
				for _, player in Players:GetPlayers() do
					publish(player)
				end
			end
		end
	end)
end

return QuestService
