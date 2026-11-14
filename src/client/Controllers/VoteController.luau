--!strict
-- VoteController: the intermission map vote (server: VoteService), shown as a cinematic
-- "CHOOSE A MAP" window: three tall cards, each a slowly pushing-in shot of the arena
-- (Config.World.MapThumbnails), the live vote count in a bubble, a NEW tag on new arenas,
-- the countdown and a close button. Voting is optional: close it to keep exploring and
-- reopen it from the pill under the round bar. The winner flashes, then it tucks away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

local CARD_W = 268
local CARD_H = 330
local GAP = 14
local WINNER_SECONDS = 2.5
local ACCENTS = { Color3.fromRGB(255, 110, 100), Color3.fromRGB(120, 170, 255), Color3.fromRGB(90, 220, 255) }

local VoteController = {}

type Card = {
	Button: TextButton,
	Image: ImageLabel,
	Zoom: UIScale,
	Name: TextLabel,
	Hint: TextLabel,
	Count: TextLabel,
	CountStroke: UIStroke,
	New: Frame,
	Stroke: UIStroke,
	Scale: UIScale,
	Shade: Frame,
}

local window: Frame
local windowScale: UIScale
local timerLabel: TextLabel
local reopen: TextButton
local cards: { Card } = {}
local myVote = 0
local hideToken = 0
local pan = 0

local function split(value: any): { string }
	local list = {}
	if typeof(value) == "string" then
		for part in value:gmatch("[^,]+") do
			table.insert(list, part)
		end
	end
	return list
end

local function isOpen(): boolean
	return ReplicatedStorage:GetAttribute(Attributes.VoteOpen) == true
end

local function render()
	local keys = split(ReplicatedStorage:GetAttribute(Attributes.VoteCandidates))
	local counts = split(ReplicatedStorage:GetAttribute(Attributes.VoteCounts))
	local winner = ReplicatedStorage:GetAttribute(Attributes.VoteWinner) :: number? or 0
	for i, card in cards do
		local key = keys[i]
		card.Button.Visible = key ~= nil
		if key then
			card.Image.Image = Config.World.MapThumbnails[key] or ""
			card.Name.Text = string.upper(Config.World.MapDisplayNames[key] or key)
			card.New.Visible = Config.World.NewMaps[key] == true and winner == 0
			card.Count.Text = tostring(tonumber(counts[i]) or 0)
			local chosen = i == myVote or winner == i
			card.Stroke.Color = if winner == i then C.Gold elseif i == myVote then C.GreenLight else C.Outline
			card.Stroke.Thickness = if chosen then 5 else Theme.Stroke.Heavy
			card.CountStroke.Color = if chosen then C.GreenLight else ACCENTS[i]
			card.Hint.Text = if winner == i then "NEXT MAP!" elseif winner > 0 then "" elseif i == myVote then "YOUR VOTE ✓" else Components.inputText("{TAP} TO VOTE")
			card.Hint.TextColor3 = if winner == i then C.GoldLight elseif i == myVote then C.GreenLight else C.TextDim
			card.Shade.BackgroundTransparency = if winner > 0 and winner ~= i then 0.35 else 1
		end
	end
end

local function updateTimer()
	local endsAt = ReplicatedStorage:GetAttribute(Attributes.VoteEndsAt) :: number? or 0
	local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	if isOpen() then
		timerLabel.Text = string.format("%ds", left)
		Components.setText(reopen, string.format("CHOOSE A MAP · %ds", left))
	else
		timerLabel.Text = ""
	end
end

local function show()
	if window.Visible then
		return
	end
	window.Visible = true
	reopen.Visible = false
	windowScale.Scale = 0.8
	Components.tween(windowScale, Theme.Tweens.Pop, { Scale = 1 })
	Sound.play("Open", 0.5, 1.1)
end

local function hide(keepReopen: boolean)
	window.Visible = false
	reopen.Visible = keepReopen and isOpen()
end

local function onOpenChanged()
	hideToken += 1
	if isOpen() then
		myVote = 0
		render()
		updateTimer()
		show()
	elseif window.Visible or reopen.Visible then
		render()
		updateTimer()
		reopen.Visible = false
		if not window.Visible and ReplicatedStorage:GetAttribute(Attributes.VoteWinner) ~= nil then
			show() -- flash the winner even if it was closed
		end
		local token = hideToken
		task.delay(WINNER_SECONDS, function()
			if hideToken == token then
				hide(false)
			end
		end)
	end
end

local function buildCard(parent: Instance, i: number): Card
	local button = Instance.new("TextButton")
	button.Name = "Card" .. i
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = i
	button.Size = UDim2.fromOffset(CARD_W, CARD_H)
	button.BackgroundColor3 = C.Panel
	button.BorderSizePixel = 0
	button.ClipsDescendants = true
	Components.corner(button, Theme.Radius.Medium)
	local stroke = Components.stroke(button, Theme.Stroke.Heavy)
	button.Parent = parent
	-- the shot, pushing in slowly (cinematic camera feel, no 3D cost)
	local image = Instance.new("ImageLabel")
	image.Name = "Shot"
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Crop
	image.Size = UDim2.fromScale(1, 1)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Parent = button
	local zoom = Instance.new("UIScale")
	zoom.Parent = image
	Components.corner(image, Theme.Radius.Medium)
	-- dark fade at the bottom for the title
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.Size = UDim2.new(1, 0, 0.5, 0)
	fade.Position = UDim2.fromScale(0, 0.5)
	fade.ZIndex = 2
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.45), NumberSequenceKeypoint.new(1, 0.1) })
	g.Parent = fade
	fade.Parent = button
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 4
	shade.Parent = button
	local name = Components.label({ Name = "MapName", Text = "", TextSize = 24, Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 14, 1, -62), XAlign = Enum.TextXAlignment.Left, ZIndex = 3, Parent = button })
	name.TextScaled = true
	local hint = Components.label({ Name = "Hint", Text = "", TextSize = 15, Color = C.TextDim, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 14, 1, -30), XAlign = Enum.TextXAlignment.Left, ZIndex = 3, Parent = button })
	-- vote count bubble
	local bubble = Instance.new("Frame")
	bubble.Name = "CountBubble"
	bubble.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	bubble.Size = UDim2.fromOffset(44, 30)
	bubble.Position = UDim2.new(1, -12, 0, 12)
	bubble.AnchorPoint = Vector2.new(1, 0)
	bubble.ZIndex = 3
	Components.corner(bubble, Theme.Radius.Pill)
	local countStroke = Components.stroke(bubble, 3, ACCENTS[i])
	bubble.Parent = button
	local count = Components.label({ Name = "Count", Text = "0", TextSize = 18, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = bubble })
	-- NEW tag for the newest arenas
	local new = Instance.new("Frame")
	new.Name = "NewTag"
	new.BackgroundColor3 = Color3.new(1, 1, 1)
	new.Size = UDim2.fromOffset(78, 26)
	new.Position = UDim2.fromOffset(12, 14)
	new.ZIndex = 3
	Components.corner(new, Theme.Radius.Pill)
	Components.stroke(new, 2)
	Components.gradient(new, C.GreenLight, C.Green, 90)
	new.Parent = button
	Components.label({ Name = "Text", Text = "NEW!", TextSize = 15, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = new })

	local scale = Components.pressable(button, 1.03)
	button.Activated:Connect(function()
		if isOpen() then
			myVote = i
			Remotes.get("MapVote"):FireServer(i)
			Sound.play("Click", 0.8, 1.1)
			scale.Scale = 0.95
			Components.tween(scale, Theme.Tweens.Spring, { Scale = 1 })
			render()
		end
	end)
	return {
		Button = button,
		Image = image,
		Zoom = zoom,
		Name = name,
		Hint = hint,
		Count = count,
		CountStroke = countStroke,
		New = new,
		Stroke = stroke,
		Scale = scale,
		Shade = shade,
	}
end

function VoteController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoteHUD"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)

	local width = CARD_W * 3 + GAP * 2 + 36
	window = Components.panel({
		Name = "MapVote",
		Size = UDim2.fromOffset(width, CARD_H + 122),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Window,
		Transparency = 0.18,
		Radius = Theme.Radius.Large,
		Parent = layer,
	})
	local stroke = window:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = Theme.Stroke.Window
	end
	window.Visible = false
	window.ZIndex = 5
	windowScale = Instance.new("UIScale")
	windowScale.Parent = window

	Components.label({ Name = "Title", Text = "CHOOSE A MAP", TextSize = 36, Size = UDim2.new(1, -160, 0, 44), Position = UDim2.fromOffset(18, 12), XAlign = Enum.TextXAlignment.Left, StrokeThickness = Theme.Stroke.Heavy, Parent = window })
	timerLabel = Components.label({ Name = "Timer", Text = "", TextSize = 22, Color = C.GoldLight, Size = UDim2.fromOffset(60, 30), Position = UDim2.new(1, -72, 0, 22), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, Parent = window })
	Components.button({
		Name = "Close",
		Text = "X",
		TextSize = 24,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -14, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Red,
		ColorLight = C.RedLight,
		Parent = window,
		OnClick = function()
			hide(true)
		end,
	})

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -36, 0, CARD_H)
	row.Position = UDim2.fromOffset(18, 66)
	row.Parent = window
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = row
	for i = 1, 3 do
		cards[i] = buildCard(row, i)
	end
	Components.label({ Name = "Footer", Text = "Optional · close to explore, then reopen from the top", TextSize = 14, Color = C.TextDim, Size = UDim2.new(1, -36, 0, 20), Position = UDim2.new(0, 18, 1, -30), XAlign = Enum.TextXAlignment.Left, StrokeThickness = 2, Parent = window })

	-- reopen pill under the round bar while the vote is still running
	reopen = Components.button({
		Name = "ReopenVote",
		Text = "CHOOSE A MAP",
		TextSize = 17,
		Size = UDim2.fromOffset(220, 38),
		Position = UDim2.new(0.5, 0, 0, 134),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Header,
		ColorLight = C.HeaderLight,
		Parent = layer,
		OnClick = show,
	})
	reopen.Visible = false

	for _, attr in { Attributes.VoteCandidates, Attributes.VoteCounts, Attributes.VoteWinner } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(render)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.VoteOpen):Connect(onOpenChanged)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.TimeRemaining):Connect(updateTimer)
	-- slow push-in on the shots (only while the window is up)
	RunService.RenderStepped:Connect(function(dt)
		if not window.Visible then
			return
		end
		pan += dt
		for i, card in cards do
			card.Zoom.Scale = 1.06 + math.sin(pan * 0.35 + i * 1.7) * 0.05
		end
	end)
	onOpenChanged()
end

return VoteController
