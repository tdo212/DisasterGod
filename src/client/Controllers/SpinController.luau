--!strict
-- SpinController: the prize wheel window. A pie wheel with the real odds on every
-- segment, a centre SPIN! hub, the red pointer, and the bottom row from the reference:
-- [buy 1 spin] [Spin! xN] [buy 10 spins] with the free-spin countdown underneath.
--
-- The pie is drawn without image assets: each half of the wheel is a clipped frame
-- holding stacked circles, each cut to a half-plane by a transparency gradient
-- (painter's algorithm). Spinning re-aims the gradients and labels every frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Analytics = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Analytics") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Store = require(UI:WaitForChild("Store") :: ModuleScript)
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)
local HUDController = require(script.Parent:WaitForChild("HUDController") :: ModuleScript)

local S = Config.Spin
local M = Config.Monetization
local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local SpinController = {}

local REWARDS = S.Rewards
local COUNT = #REWARDS
local THETA = 360 / COUNT
local RIM = 348 -- outer ring diameter
local DISC = 304 -- pie diameter
local RADIUS = DISC / 2
local RIM_BLUE = Color3.fromRGB(190, 215, 245)
local SEPARATOR = Color3.fromRGB(16, 48, 16)
-- transparent first half, opaque second half: a circle with this gradient at rotation r
-- shows the half-disc covering angles [r, r + 180) clockwise from 12 o'clock
local HALF_CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4995, 1),
	NumberSequenceKeypoint.new(0.5005, 0),
	NumberSequenceKeypoint.new(1, 0),
})

type Slice = { Frame: Frame, Gradient: UIGradient }

local started = false
local gui: ScreenGui
local layer: Frame
local root: Frame
local dim: TextButton
local rootScale: UIScale
local halves: { { Slice } } = {}
local separators: { Frame } = {}
-- The prize in words on every slice, next to its odds.
local function prizeText(reward: any): string
	if reward.Kind == "Coins" then
		return reward.Label .. " COINS"
	elseif reward.Kind == "God" then
		return "BE THE GOD"
	elseif reward.Kind == "Kit" then
		return "FREE GOD KIT"
	end
	return string.upper(tostring(reward.Label))
end

local icons: { GuiObject } = {}
local prizes: { TextLabel } = {} -- what the slice wins, in words ("1,500 COINS")
local odds: { TextLabel } = {}
local spinTag: TextLabel
local timerLabel: TextLabel
local buyButtons: { TextButton } = {}
local wheelAngle = 0
local spinning = false
local waiting = false
local open = false

local totalWeight = 0
for _, reward in REWARDS do
	totalWeight += reward.Weight
end

---------------------------------------------------------------------------
-- wheel drawing

local function onCircle(object: GuiObject, angle: number, radius: number)
	local r = math.rad(angle)
	object.Position = UDim2.new(0.5, math.sin(r) * radius, 0.5, -math.cos(r) * radius)
end

local function segmentAt(angle: number): number
	return math.floor(((angle - wheelAngle) % 360) / THETA) + 1
end

local function render()
	for h, slices in halves do
		local startAngle = if h == 1 then 0 else 180
		-- bottom layer: the segment that owns the start of this half
		slices[1].Frame.BackgroundColor3 = REWARDS[segmentAt(startAngle + 0.01)].Color
		-- then every boundary inside the half, in clockwise order, painted over it
		local inside: { { Rel: number, Angle: number, Index: number } } = {}
		for i = 1, COUNT do
			local angle = ((i - 1) * THETA + wheelAngle) % 360
			local rel = (angle - startAngle) % 360
			if rel > 0.01 and rel < 180 then
				table.insert(inside, { Rel = rel, Angle = angle, Index = i })
			end
		end
		table.sort(inside, function(a, b)
			return a.Rel < b.Rel
		end)
		for j = 2, #slices do
			local slice = slices[j]
			local entry = inside[j - 1]
			slice.Frame.Visible = entry ~= nil
			if entry then
				slice.Frame.BackgroundColor3 = REWARDS[entry.Index].Color
				slice.Gradient.Rotation = entry.Angle
			end
		end
	end
	for i = 1, COUNT do
		local boundary = (i - 1) * THETA + wheelAngle
		local mid = boundary + THETA / 2
		onCircle(separators[i], boundary, RADIUS / 2)
		separators[i].Rotation = boundary
		onCircle(icons[i], mid, RADIUS * 0.4)
		icons[i].Rotation = mid
		onCircle(prizes[i], mid, RADIUS * 0.63)
		prizes[i].Rotation = mid
		onCircle(odds[i], mid, RADIUS * 0.85)
		odds[i].Rotation = mid
	end
end

local function circle(parent: Instance, name: string, diameter: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromOffset(diameter, diameter)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	Components.corner(f, Theme.Radius.Pill)
	f.Parent = parent
	return f
end

local function buildWheel(parent: Frame): TextButton
	local rim = circle(parent, "Rim", RIM, RIM_BLUE)
	rim.Position = UDim2.new(0.5, 0, 0, RIM / 2 + 14)
	Components.stroke(rim, Theme.Stroke.Heavy)
	Components.gradient(rim, Color3.new(1, 1, 1), RIM_BLUE)
	local ring = circle(rim, "Ring", DISC + 12, C.Outline)

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.BackgroundTransparency = 1
	disc.Size = UDim2.fromOffset(DISC, DISC)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Parent = ring

	for h = 1, 2 do
		local clip = Instance.new("Frame")
		clip.Name = if h == 1 then "RightHalf" else "LeftHalf"
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromOffset(RADIUS, DISC)
		clip.Position = UDim2.fromOffset(if h == 1 then RADIUS else 0, 0)
		clip.Parent = disc
		local slices: { Slice } = {}
		for j = 1, COUNT + 1 do
			local f = Instance.new("Frame")
			f.Name = "Slice" .. j
			f.Size = UDim2.fromOffset(DISC, DISC)
			f.Position = UDim2.fromOffset(if h == 1 then -RADIUS else 0, 0)
			f.BorderSizePixel = 0
			f.ZIndex = j
			Components.corner(f, Theme.Radius.Pill)
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = HALF_CUT
			gradient.Enabled = j > 1 -- the bottom slice is a full circle
			gradient.Parent = f
			f.Parent = clip
			slices[j] = { Frame = f, Gradient = gradient }
		end
		halves[h] = slices
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 5
	overlay.Parent = disc
	for i, reward in REWARDS do
		local line = Instance.new("Frame")
		line.Name = "Separator" .. i
		line.Size = UDim2.fromOffset(4, RADIUS)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = SEPARATOR
		line.BorderSizePixel = 0
		line.Parent = overlay
		separators[i] = line
		icons[i] = Components.icon({ Name = "Icon" .. i, Icon = reward.Icon, TextSize = 40, Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(0.5, 0.5), Parent = overlay })
		prizes[i] = Components.label({
			Name = "Prize" .. i,
			Text = prizeText(reward),
			TextSize = 18,
			Size = UDim2.fromOffset(130, 22),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = C.GoldLight,
			Parent = overlay,
		})
		odds[i] = Components.label({
			Name = "Odds" .. i,
			Text = string.format("%.2f%%", reward.Weight / totalWeight * 100),
			TextSize = 19,
			Size = UDim2.fromOffset(110, 24),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = overlay,
		})
	end

	-- centre hub: the SPIN! button
	local hubRing = circle(overlay, "HubRing", 92, C.Gold)
	hubRing.ZIndex = 3
	Components.stroke(hubRing, Theme.Stroke.Thick)
	local hub = Instance.new("TextButton")
	hub.Name = "Hub"
	hub.Text = ""
	hub.AutoButtonColor = false
	hub.Size = UDim2.fromOffset(76, 76)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(hub, Theme.Radius.Pill)
	Components.stroke(hub, Theme.Stroke.Thick)
	Components.gradient(hub, C.GreenLight, C.Green)
	Components.label({ Name = "Text", Text = "SPIN!", TextSize = 20, Size = UDim2.fromScale(1, 1), Parent = hub })
	Components.pressable(hub, 1.08)
	hub.Parent = hubRing

	-- red gem pointer at 12 o'clock
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.Size = UDim2.fromOffset(34, 34)
	pointer.Position = UDim2.new(0.5, 0, 0, 6)
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Rotation = 45
	pointer.BackgroundColor3 = Color3.new(1, 1, 1)
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 6
	Components.corner(pointer, Theme.Radius.Small)
	Components.stroke(pointer, Theme.Stroke.Thick)
	Components.gradient(pointer, C.RedLight, C.Red, 45)
	pointer.Parent = rim
	return hub
end

---------------------------------------------------------------------------
-- spinning

local function spins(): number
	return player:GetAttribute(Attributes.Spins) :: number? or 0
end

local function nudgeBuyButtons()
	for _, button in buyButtons do
		local scale = button:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1.2
			Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
		end
	end
end

local function requestSpin()
	if spinning or waiting then
		return
	end
	if spins() <= 0 then
		Sound.play("Error", 0.7)
		HUDController.Popup("NO SPINS LEFT — BUY MORE OR WAIT", C.RedLight)
		nudgeBuyButtons()
		return
	end
	waiting = true
	Remotes.get("SpinRequest"):FireServer()
	task.delay(3, function()
		waiting = false
	end)
end

local function spinTo(index: number, text: string, color: Color3?)
	waiting = false
	spinning = true
	-- land somewhere inside the winning segment, not always dead centre
	local landing = (index - 1) * THETA + THETA / 2 + (math.random() - 0.5) * THETA * 0.6
	local delta = ((-landing) % 360 - wheelAngle % 360) % 360
	local total = S.ExtraTurns * 360 + delta
	local from = wheelAngle
	local began = os.clock()
	local lastSegment = math.floor(wheelAngle / THETA)
	local lastTick = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - began) / S.SpinSeconds)
		wheelAngle = from + total * (1 - (1 - alpha) ^ 4)
		render()
		local segment = math.floor(wheelAngle / THETA)
		if segment ~= lastSegment and os.clock() - lastTick > 0.05 then
			lastSegment = segment
			lastTick = os.clock()
			Sound.play("Tick", 0.45, 1.1 + alpha * 0.3)
		end
		if alpha >= 1 then
			connection:Disconnect()
			spinning = false
			wheelAngle %= 360
			local icon = icons[index]
			local pop = Instance.new("UIScale")
			pop.Scale = 1.7
			pop.Parent = icon
			Components.tween(pop, Theme.Tweens.Pop, { Scale = 1 }).Completed:Once(function()
				pop:Destroy()
			end)
			HUDController.Popup(text, color)
		end
	end)
end

---------------------------------------------------------------------------
-- window

local function refreshCounts()
	spinTag.Text = "x" .. tostring(spins())
end

local function refreshTimer()
	local at = player:GetAttribute(Attributes.FreeSpinAt) :: number? or 0
	local remaining = at - workspace:GetServerTimeNow()
	if remaining > 0 then
		local s = math.ceil(remaining)
		timerLabel.Text = string.format("+1 spin in %02d:%02d", s // 60, s % 60)
	elseif spins() >= S.MaxBankedFree then
		timerLabel.Text = "Free spins full — spin to earn more!"
	else
		timerLabel.Text = "+1 free spin on its way…"
	end
end

local function buyButton(parent: Instance, key: string, x: number, anchorX: number): TextButton
	local def = M.Products[key]
	local button = Components.button({
		Name = key,
		Text = Store.robux(def.Price),
		TextSize = 26,
		Size = UDim2.fromOffset(152, 56),
		Position = UDim2.new(0.5, x, 0, 398),
		AnchorPoint = Vector2.new(anchorX, 0),
		Color = C.Blue,
		ColorLight = C.BlueLight,
		Parent = parent,
		OnClick = function()
			Store.promptProduct(key)
		end,
	})
	Components.tag(button, "x" .. tostring(def.Spins or 1), UDim2.new(1, 8, 1, 6), Vector2.new(1, 1))
	table.insert(buyButtons, button)
	return button
end

local function build()
	dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.ZIndex = 8
	dim.Parent = layer

	root = Instance.new("Frame")
	root.Name = "SpinWheel"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(600, 500)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Visible = false
	root.ZIndex = 9
	root.Parent = layer
	rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	local hub = buildWheel(root)
	hub.Activated:Connect(requestSpin)

	Components.button({
		Name = "Close",
		Text = "X",
		TextSize = 34,
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(1, -30, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Red,
		ColorLight = C.RedLight,
		Parent = root,
		OnClick = function()
			SpinController.Close()
		end,
	})

	buyButton(root, "Spin1", -144, 1)
	local spin = Components.button({
		Name = "Spin",
		Text = "⏫ Spin!",
		TextSize = 34,
		Size = UDim2.fromOffset(264, 68),
		Position = UDim2.new(0.5, 0, 0, 392),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = root,
		OnClick = requestSpin,
	})
	spinTag = Components.tag(spin, "x0", UDim2.new(1, 10, 0, -10), Vector2.new(1, 0))
	buyButton(root, "Spin10", 144, 0)

	timerLabel = Components.label({
		Name = "Timer",
		Text = "",
		TextSize = 24,
		Color = C.GreenLight,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 466),
		Parent = root,
	})
	render()
end

function SpinController.IsOpen(): boolean
	return open
end

function SpinController.Open()
	if open then
		return
	end
	open = true
	Analytics.track("SpinOpened")
	Sound.play("Open", 0.5, 1.2)
	dim.Visible = true
	root.Visible = true
	rootScale.Scale = 0.7
	Components.tween(rootScale, Theme.Tweens.Pop, { Scale = 1 })
	refreshCounts()
	refreshTimer()
end

function SpinController.Close()
	if not open then
		return
	end
	open = false
	Sound.play("Click", 0.6, 0.8)
	dim.Visible = false
	root.Visible = false
end

function SpinController.Toggle()
	if open then
		SpinController.Close()
	else
		SpinController.Open()
	end
end

function SpinController.Start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "SpinWheel"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)
	build()

	dim.Activated:Connect(function()
		if not spinning then
			SpinController.Close()
		end
	end)
	player:GetAttributeChangedSignal(Attributes.Spins):Connect(refreshCounts)
	Remotes.get("SpinResult").OnClientEvent:Connect(function(index: number, text: string, color: Color3?)
		if typeof(index) == "number" and REWARDS[index] and typeof(text) == "string" then
			SpinController.Open()
			spinTo(index, text, color)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if open then
				refreshTimer()
			end
		end
	end)
end

return SpinController
