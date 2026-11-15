--!strict
-- QuestController: the Daily Quests window. Three rows with a progress bar and a claim
-- button each; the footer shows the all-done bonus, the daily streak and the reset timer.
-- State arrives as JSON in the player's QuestState attribute (see QuestService).
-- In the lodge a compact tracker pill shows today's three quests (tap to expand); it pulses
-- CLAIM when one is done, and tapping it then opens the window.

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

-- the lodge tracker pill
local tracker: Frame? = nil
local trackerHeader: TextLabel? = nil
local trackerRows: Frame? = nil
local trackerOpen = false
local trackerPulse: UIScale? = nil

local function inRound(): boolean
	local role = player:GetAttribute(Attributes.Role)
	return ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active" and (role == "DisasterGod" or (role == "Survivor" and player:GetAttribute(Attributes.Alive) == true))
end

local function refreshTracker()
	local t, header, rows = tracker, trackerHeader, trackerRows
	if not (t and header and rows) then
		return
	end
	t.Visible = #state.Quests > 0 and not inRound()
	local done, claimable = 0, 0
	for _, quest in state.Quests do
		if quest.Claimed then
			done += 1
		elseif quest.Progress >= quest.Goal then
			claimable += 1
		end
	end
	header.Text = if claimable > 0 then "🎁 QUEST DONE · CLAIM!" else string.format("📜 QUESTS %d/%d %s", done, #state.Quests, if trackerOpen then "–" else "+")
	header.TextColor3 = if claimable > 0 then C.GoldLight else C.Text
	for _, child in rows:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	rows.Visible = trackerOpen
	for i, quest in state.Quests do
		local mark = if quest.Claimed then "✔" elseif quest.Progress >= quest.Goal then "🎁" else "•"
		local row = Components.label({
			Name = "Row",
			Text = string.format("%s %s  %d/%d", mark, quest.Text, math.min(quest.Progress, quest.Goal), quest.Goal),
			TextSize = 14,
			Color = if quest.Claimed then C.TextDim else C.Text,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.fromOffset(8, (i - 1) * 24),
			Parent = rows,
		})
		row.TextTruncate = Enum.TextTruncate.AtEnd
	end
	t.Size = UDim2.fromOffset(260, 34 + (if trackerOpen then #state.Quests * 24 + 6 else 0))
end

local function buildTracker()
	local touch = Components.isTouch()
	local t = Components.panel({
		Name = "QuestTracker",
		Size = UDim2.fromOffset(260, 34),
		Position = if touch then UDim2.fromOffset(12, 350) else UDim2.new(0, 188, 1, -130),
		AnchorPoint = if touch then Vector2.zero else Vector2.new(0, 1),
		Color = C.Window,
		Transparency = 0.12,
		Parent = layer,
	})
	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.new(1, 0, 0, 34)
	button.Parent = t
	trackerHeader = Components.label({ Name = "Header", Text = "", TextSize = 17, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 2), Parent = t })
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, 0, 1, -36)
	rows.Position = UDim2.fromOffset(0, 34)
	rows.Parent = t
	trackerRows = rows
	local pulse = Instance.new("UIScale")
	pulse.Parent = t
	trackerPulse = pulse
	tracker = t
	button.Activated:Connect(function()
		if QuestController.ClaimableCount() > 0 then
			QuestController.Toggle()
		else
			trackerOpen = not trackerOpen
			refreshTracker()
		end
	end)
	-- pulse while something is ready to claim
	task.spawn(function()
		while true do
			local p = trackerPulse
			if p and QuestController.ClaimableCount() > 0 and t.Visible then
				Components.tween(p, Theme.Tweens.Fade, { Scale = 1.08 })
				task.wait(0.5)
				Components.tween(p, Theme.Tweens.Fade, { Scale = 1 })
				task.wait(0.5)
			else
				task.wait(0.5)
			end
		end
	end)
	for _, attr in { Attributes.Role, Attributes.Alive } do
		player:GetAttributeChangedSignal(attr):Connect(refreshTracker)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshTracker)
	changed.Event:Connect(refreshTracker)
	refreshTracker()
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

	buildTracker()
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
