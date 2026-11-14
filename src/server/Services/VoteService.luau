--!strict
-- VoteService: the intermission map vote (client: VoteController). Each intermission
-- offers three candidate maps (never the one just played); players tap a card to vote and
-- can change their mind until it closes. The winner is built next (ties and empty votes
-- pick at random), and every vote is logged as a custom analytics event (map popularity).
-- State is replicated on ReplicatedStorage: VoteOpen, VoteCandidates ("A,B,C"),
-- VoteCounts ("2,0,1"), VoteEndsAt (server time) and VoteWinner (index, 0 = none).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local QuestService = require(script.Parent.QuestService)

local V = Config.Voting
local Attributes = Config.Attributes

local VoteService = {}

local candidates: { string } = {}
local votes: { [Player]: number } = {}
local open = false
local lastMap: string? = nil
local rng = Random.new()

local function publishCounts()
	local counts = table.create(#candidates, 0)
	for player, index in votes do
		if player.Parent and counts[index] then
			counts[index] += 1
		end
	end
	local parts = {}
	for i, c in counts do
		parts[i] = tostring(c)
	end
	ReplicatedStorage:SetAttribute(Attributes.VoteCounts, table.concat(parts, ","))
	return counts
end

-- Opens a vote. False when there is nothing to vote on (Studio ForceMap).
function VoteService.Begin(): boolean
	if RunService:IsStudio() and typeof(workspace:GetAttribute("ForceMap")) == "string" then
		return false
	end
	-- Fresh choices every vote: never the map just played, and none of the maps that
	-- were on the previous ballot while enough others exist (9 maps -> always 3 new).
	local previous: { [string]: boolean } = {}
	for _, key in candidates do
		previous[key] = true
	end
	local fresh, fallback = {}, {}
	for _, key in Config.World.MapRotation do
		if key ~= lastMap then
			table.insert(if previous[key] then fallback else fresh, key)
		end
	end
	table.clear(candidates)
	for _ = 1, V.Candidates do
		local pool = if #fresh > 0 then fresh else fallback
		if #pool == 0 then
			break
		end
		table.insert(candidates, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
	end
	if #candidates == 0 then
		return false
	end
	table.clear(votes)
	open = true
	ReplicatedStorage:SetAttribute(Attributes.VoteWinner, 0)
	ReplicatedStorage:SetAttribute(Attributes.VoteCandidates, table.concat(candidates, ","))
	ReplicatedStorage:SetAttribute(Attributes.VoteEndsAt, workspace:GetServerTimeNow() + V.Duration)
	publishCounts()
	ReplicatedStorage:SetAttribute(Attributes.VoteOpen, true)
	return true
end

-- Closes the vote and returns the winning map key.
function VoteService.Finish(): string
	open = false
	local counts = publishCounts()
	local best = -1
	local winners: { number } = {}
	for i in candidates do
		local c = counts[i] or 0
		if c > best then
			best = c
			winners = { i }
		elseif c == best then
			table.insert(winners, i)
		end
	end
	local winner = winners[rng:NextInteger(1, #winners)]
	local key = candidates[winner]
	for player, index in votes do
		if player.Parent then
			QuestService.Progress(player, "Vote", 1)
			-- telemetry: which maps players ask for
			pcall(function()
				AnalyticsService:LogCustomEvent(player, "MapVote", 1, {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = candidates[index],
					[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = if index == winner then "won" else "lost",
				})
			end)
		end
	end
	ReplicatedStorage:SetAttribute(Attributes.VoteWinner, winner)
	ReplicatedStorage:SetAttribute(Attributes.VoteOpen, false)
	lastMap = key
	return key
end

function VoteService.Init()
	ReplicatedStorage:SetAttribute(Attributes.VoteOpen, false)
	ReplicatedStorage:SetAttribute(Attributes.VoteWinner, 0)
	Remotes.get("MapVote").OnServerEvent:Connect(function(player, index)
		if not open or typeof(index) ~= "number" or not candidates[index] then
			return
		end
		votes[player] = index
		publishCounts()
	end)
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		if open then
			publishCounts()
		end
	end)
end

return VoteService
