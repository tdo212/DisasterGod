--!strict
-- QuestController: the Daily Quests window. Three rows with a progress bar and a claim
-- button each; the footer shows the all-done bonus, the daily streak and the reset timer.
-- State arrives as JSON in the player's QuestState attribute (see QuestService).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Components = require(UI:WaitForChild("Components") :: ModuleScript)

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local QuestController = {}

type QuestRow = { Id: string, Text: string, Goal: number, Progress: number, Reward: number, Claimed: boolean }
type QuestState = { Streak: number, ResetAt: number, Quests: { QuestRow } }

local ROW_HEIGHT = 84

local started = false
local gui: ScreenGui
local layer: Frame
local window: any -- Components.WindowHandle
local list: Frame
local footer: TextLabel
local state: QuestState = { Streak = 0, ResetAt = 0, Quests = {} }

local changed = Instance.new("BindableEvent")
-- Fires when quest state changes (the menu tile shows how many are claimable).
QuestController.Changed = changed.Event

local function decode(): QuestState
	local raw = player:GetAttribute(Attributes.QuestState)
	if typeof(raw) == "string" then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and typeof(data) == "table" and typeof(data.Quests) == "table" then
			return data
		end
	end
	return { Streak = 0, ResetAt = 0, Quests = {} }
end

function QuestController.ClaimableCount(): number
	local n = 0
	for _, quest in state.Quests do
		if not quest.Claimed and quest.Progress >= quest.Goal then
			n += 1
		end
	end
	return n
end

local function refreshFooter()
	local remaining = math.max(0, state.ResetAt - os.time())
	footer.Text = string.format(
		"All 3 done: +%d 🎡 spin  ·  🔥 Streak %d  ·  New in %02d:%02d:%02d",
		Config.Quests.AllDoneSpins,
		state.Streak,
		remaining // 3600,
		remaining % 3600 // 60,
		remaining % 60
	)
end

local function rebuild()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, quest in state.Quests do
		local done = quest.Progress >= quest.Goal
		local row = Components.panel({
			Name = quest.Id,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Color = C.WindowLight,
			Radius = Theme.Radius.Medium,
			Studs = true,
			Parent = list,
		})
		row.LayoutOrder = i
		Components.label({
			Name = "Text",
			Text = quest.Text,
			TextSize = 22,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -170, 0, 28),
			Position = UDim2.fromOffset(14, 8),
			Parent = row,
		}).TextTruncate = Enum.TextTruncate.AtEnd
		local track, setFill = Components.progress(row, UDim2.new(1, -260, 0, 24), UDim2.fromOffset(14, 46), C.GreenLight, C.Green)
		setFill(quest.Progress / math.max(1, quest.Goal))
		local count = Components.label({ Name = "Count", Text = string.format("%d / %d", quest.Progress, quest.Goal), TextSize = 17, Size = UDim2.fromScale(1, 1), Parent = track })
		count.ZIndex = 2
		Components.label({
			Name = "Reward",
			Text = "💰 " .. tostring(quest.Reward),
			TextSize = 20,
			Color = C.Gold,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromOffset(90, 24),
			Position = UDim2.new(1, -236, 0, 46),
			Parent = row,
		})
		local label = if quest.Claimed then "DONE ✔" elseif done then "CLAIM" else "…"
		local ready = done and not quest.Claimed
		Components.button({
			Name = "Claim",
			Text = label,
			TextSize = 22,
			Size = UDim2.fromOffset(128, 56),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = if ready then C.Green else C.Grey,
			ColorLight = if ready then C.GreenLight else C.GreyLight,
			Parent = row,
			OnClick = function()
				if ready then
					Remotes.get("QuestClaim"):FireServer(quest.Id)
				end
			end,
		})
	end
	refreshFooter()
end

local function onState()
	state = decode()
	rebuild()
	changed:Fire()
end

function QuestController.Toggle()
	if window.IsOpen() then
		window.Close()
	else
		window.Open()
	end
end

function QuestController.Start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "Quests"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	window = Components.window(layer, "Daily Quests", UDim2.fromOffset(600, 410))
	list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -34)
	list.Parent = window.Content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	footer = Components.label({
		Name = "Footer",
		Text = "",
		TextSize = 18,
		Color = C.GoldLight,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -2),
		AnchorPoint = Vector2.new(0, 1),
		Parent = window.Content,
	})

	player:GetAttributeChangedSignal(Attributes.QuestState):Connect(onState)
	onState()
	task.spawn(function()
		while true do
			task.wait(1)
			if window.IsOpen() then
				refreshFooter()
			end
		end
	end)
end

return QuestController
