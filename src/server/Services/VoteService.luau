--!strict
-- VoteService: three physical voting pads in the Sky Lodge. Each intermission offers
-- three candidate maps; a player's vote is the last pad they stood on. The winner is
-- built next, and every vote is logged as a custom analytics event (map popularity).

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local QuestService = require(script.Parent.QuestService)

local V = Config.Voting
local Attributes = Config.Attributes

local VoteService = {}

local pads: { BasePart } = {}
local labels: { TextLabel } = {}
local candidates: { string } = {}
local votes: { [Player]: number } = {}
local open = false
local lastMap: string? = nil
local rng = Random.new()

local IDLE_COLOR = Color3.fromRGB(110, 120, 150)
local PAD_COLORS = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 220, 110), Color3.fromRGB(80, 160, 255) }

local function displayName(key: string): string
	return Config.World.MapDisplayNames[key] or key
end

local function tally(): { number }
	local counts = table.create(#pads, 0)
	for player, index in votes do
		if player.Parent and counts[index] then
			counts[index] += 1
		end
	end
	return counts
end

local function render(winner: number?)
	local counts = tally()
	for i, label in labels do
		local key = candidates[i]
		local pad = pads[i]
		if not key then
			label.Text = "MAP VOTE\n<font size=\"30\">opens each intermission</font>"
			pad.Color = IDLE_COLOR
		elseif winner then
			label.Text = if winner == i then "✅ " .. displayName(key) .. "\nNEXT MAP!" else displayName(key)
			pad.Color = if winner == i then PAD_COLORS[i] else IDLE_COLOR
		else
			label.Text = string.format("%s\n%d vote%s", displayName(key), counts[i], if counts[i] == 1 then "" else "s")
			pad.Color = PAD_COLORS[i]
		end
	end
end

local function padUnder(player: Player): number?
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	for i, pad in pads do
		local d = hrp.Position - pad.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude <= V.PadRadius and math.abs(d.Y) < 8 then
			return i
		end
	end
	return nil
end

-- Lobby pads (built by World/Lobby). Called once by LobbyService.
function VoteService.SetPads(list: { BasePart })
	pads = list
	table.clear(labels)
	for i, pad in pads do
		local gui = Instance.new("BillboardGui")
		gui.Name = "VoteLabel"
		gui.Size = UDim2.new(13, 0, 4.5, 0)
		gui.StudsOffset = Vector3.new(0, 8, 0)
		gui.MaxDistance = 220
		gui.Parent = pad
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label
		labels[i] = label
	end
	table.clear(candidates)
	render(nil)
end

-- Opens a vote. False when there is nothing to vote on (Studio ForceMap, or no pads).
function VoteService.Begin(): boolean
	if #pads == 0 then
		return false
	end
	if RunService:IsStudio() and typeof(workspace:GetAttribute("ForceMap")) == "string" then
		return false
	end
	local pool = {}
	for _, key in Config.World.MapRotation do
		if key ~= lastMap then
			table.insert(pool, key)
		end
	end
	table.clear(candidates)
	for _ = 1, math.min(V.Candidates, #pads, #pool) do
		table.insert(candidates, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
	end
	table.clear(votes)
	open = true
	ReplicatedStorage:SetAttribute(Attributes.VoteOpen, true)
	task.spawn(function()
		while open do
			for _, player in Players:GetPlayers() do
				local index = padUnder(player)
				if index and candidates[index] then
					votes[player] = index
				end
			end
			render(nil)
			task.wait(V.CountInterval)
		end
	end)
	return true
end

-- Closes the vote and returns the winning map key (ties and empty votes pick at random).
function VoteService.Finish(): string
	open = false
	ReplicatedStorage:SetAttribute(Attributes.VoteOpen, false)
	local counts = tally()
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
	render(winner)
	lastMap = key
	task.delay(6, function()
		if not open then
			table.clear(candidates)
			render(nil)
		end
	end)
	return key
end

function VoteService.Init()
	ReplicatedStorage:SetAttribute(Attributes.VoteOpen, false)
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
	end)
end

return VoteService
