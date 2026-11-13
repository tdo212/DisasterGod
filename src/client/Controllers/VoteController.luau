--!strict
-- VoteController: the intermission map vote (server: VoteService). A compact strip of
-- three map cards under the round bar, only while the vote is open: tap / click a card
-- to vote (change your mind any time), live counts, then the winner flashes and the strip
-- tucks away. Nothing else on screen moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local CARD_W = 166
local CARD_H = 58
local WINNER_SECONDS = 2.5
local CARD_COLORS = { { C.RedLight, C.Red }, { C.GreenLight, C.Green }, { C.BlueLight, C.Blue } }

local VoteController = {}

local strip: Frame
local title: TextLabel
local cards: { TextButton } = {}
local myVote = 0
local hideToken = 0

local function split(value: any): { string }
	local list = {}
	if typeof(value) == "string" then
		for part in value:gmatch("[^,]+") do
			table.insert(list, part)
		end
	end
	return list
end

local function render()
	local keys = split(ReplicatedStorage:GetAttribute(Attributes.VoteCandidates))
	local counts = split(ReplicatedStorage:GetAttribute(Attributes.VoteCounts))
	local winner = ReplicatedStorage:GetAttribute(Attributes.VoteWinner) :: number? or 0
	for i, card in cards do
		local key = keys[i]
		card.Visible = key ~= nil
		if key then
			local name = Config.World.MapDisplayNames[key] or key
			local icon = Config.World.MapIcons[key] or "🗺️"
			local n = tonumber(counts[i]) or 0
			local status = if winner == i then "NEXT MAP!" else string.format("%d vote%s", n, if n == 1 then "" else "s")
			Components.setText(card, string.format("%s %s\n<font size=\"14\">%s</font>", icon, name, status))
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if i == myVote or winner == i then C.Gold else C.Outline
				stroke.Thickness = if i == myVote or winner == i then 4 else Theme.Stroke.Heavy
			end
			card.BackgroundTransparency = if winner > 0 and winner ~= i then 0.5 else 0
		end
	end
end

-- The round bar already counts the vote down; the strip only says what to do.
local function updateTitle()
	title.Text = if ReplicatedStorage:GetAttribute(Attributes.VoteOpen) == true then Components.inputText("🗳️ {Tap} a map to vote") else "🗳️ MAP CHOSEN"
end

local function onOpenChanged()
	local isOpen = ReplicatedStorage:GetAttribute(Attributes.VoteOpen) == true
	hideToken += 1
	if isOpen then
		myVote = 0
		strip.Visible = true
		render()
		updateTitle()
	elseif strip.Visible then
		render()
		updateTitle()
		local token = hideToken
		task.delay(WINNER_SECONDS, function()
			if hideToken == token then
				strip.Visible = false
			end
		end)
	end
end

function VoteController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoteHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)

	strip = Instance.new("Frame")
	strip.Name = "MapVote"
	strip.BackgroundTransparency = 1
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, 134) -- 10 below the round bar's status pills
	strip.Size = UDim2.fromOffset(CARD_W * 3 + 16, CARD_H + 26)
	strip.Visible = false
	strip.Parent = layer
	title = Components.label({ Name = "Title", Text = "", TextSize = 18, Color = C.GoldLight, Size = UDim2.new(1, 0, 0, 22), Parent = strip })
	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 24)
	row.Size = UDim2.new(1, 0, 0, CARD_H)
	row.Parent = strip
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
	for i = 1, 3 do
		local colors = CARD_COLORS[i]
		local card = Components.button({
			Name = "Card" .. i,
			Text = "",
			TextSize = 16,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			Color = colors[2],
			ColorLight = colors[1],
			Parent = row,
			OnClick = function()
				if ReplicatedStorage:GetAttribute(Attributes.VoteOpen) == true then
					myVote = i
					Remotes.get("MapVote"):FireServer(i)
					Sound.play("Click", 0.8, 1.1)
					render()
				end
			end,
		})
		card.LayoutOrder = i
		local label = card:FindFirstChild("Text") :: TextLabel?
		if label then
			label.RichText = true
			label.TextWrapped = true
		end
		cards[i] = card
	end

	for _, attr in { Attributes.VoteCandidates, Attributes.VoteCounts, Attributes.VoteWinner } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(render)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.VoteOpen):Connect(onOpenChanged)
	onOpenChanged()
end

return VoteController
