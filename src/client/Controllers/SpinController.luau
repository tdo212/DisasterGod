--!strict
-- SpinController: the prize wheel window. A purple SPIN WHEEL header with the red X, a
-- gold-rimmed pie wheel ringed with blinking bulbs (alternating purple and gold segments,
-- the real odds on every one), a gold pointer at 12 o'clock and a star hub, and the bottom
-- row: SPIN 1 [price] · SPIN [n] · SPIN 10 [price], with the free-spin countdown under it.
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
local DISC = 300 -- pie diameter
local RADIUS = DISC / 2
local RIM_GOLD = Color3.fromRGB(255, 196, 40)
local RIM_GOLD_LIGHT = Color3.fromRGB(255, 236, 130)
local SEPARATOR = Color3.fromRGB(70, 24, 120)
local HEADER_PURPLE = Color3.fromRGB(120, 50, 210)
local BULBS = 16
local WHEEL_TOP = 66 -- top of the rim, under the header
local ROW_TOP = WHEEL_TOP + RIM + 14 -- the SPIN 1 / SPIN [n] / SPIN 10 row
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
local bulbs: { Frame } = {}
local prizes: { TextLabel } = {} -- what the slice wins, in words ("1,500 COINS")
local odds: { TextLabel } = {}
local spinButton: TextButton -- SPIN [n]
local spinLabel: TextLabel
local timerLabel: TextLabel
local buyButtons: { TextButton } = {}
local wheelAngle = 0
local blink = 0
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

-- A UIStroke with mitred joins draws a square around a pill frame: circles use round joins.
local function roundStroke(object: GuiObject, thickness: number)
	Components.stroke(object, thickness).LineJoinMode = Enum.LineJoinMode.Round
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

local function buildWheel(parent: Frame)
	-- black outline, gold rim, dark inner ring, then the pie
	local outline = circle(parent, "Outline", RIM + 8, C.Outline)
	outline.Position = UDim2.new(0.5, 0, 0, WHEEL_TOP + RIM / 2)
	local rim = circle(outline, "Rim", RIM, Color3.new(1, 1, 1))
	Components.gradient(rim, RIM_GOLD_LIGHT, RIM_GOLD)
	local ring = circle(rim, "Ring", DISC + 10, SEPARATOR)

	-- bulbs around the rim (they blink while the window is open)
	for b = 1, BULBS do
		local bulb = circle(rim, "Bulb" .. b, 14, Color3.new(1, 1, 1))
		onCircle(bulb, (b - 0.5) * 360 / BULBS, (RIM + DISC + 10) / 4)
		bulb.ZIndex = 2
		roundStroke(bulb, 2)
		bulbs[b] = bulb
	end

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
		line.Size = UDim2.fromOffset(3, RADIUS)
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
			Parent = overlay,
		})
		odds[i] = Components.label({
			Name = "Odds" .. i,
			Text = string.format("%.2f%%", reward.Weight / totalWeight * 100),
			TextSize = 16,
			Size = UDim2.fromOffset(110, 20),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = overlay,
		})
	end

	-- centre hub: a gold ring around a purple star cap (spinning is the button below)
	local hubRing = circle(overlay, "HubRing", 78, Color3.new(1, 1, 1))
	hubRing.ZIndex = 3
	Components.gradient(hubRing, RIM_GOLD_LIGHT, RIM_GOLD)
	roundStroke(hubRing, Theme.Stroke.Thick)
	local cap = circle(hubRing, "Cap", 58, Color3.new(1, 1, 1))
	Components.gradient(cap, C.PurpleLight, HEADER_PURPLE)
	roundStroke(cap, 2)
	Components.label({ Name = "Star", Text = "⭐", TextSize = 34, StrokeThickness = 0, Size = UDim2.fromScale(1, 1), Parent = cap })

	-- gold pointer at 12 o'clock, tip down into the wheel: the bottom half of a diamond
	local clip = Instance.new("Frame")
	clip.Name = "Pointer"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromOffset(52, 30)
	clip.Position = UDim2.new(0.5, 0, 0, -10)
	clip.AnchorPoint = Vector2.new(0.5, 0)
	clip.ZIndex = 6
	clip.Parent = outline
	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.Size = UDim2.fromOffset(36, 36)
	diamond.Position = UDim2.new(0.5, 0, 0, 0)
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Color3.new(1, 1, 1)
	diamond.BorderSizePixel = 0
	diamond.ZIndex = 6
	Components.gradient(diamond, RIM_GOLD_LIGHT, RIM_GOLD, 45)
	Components.stroke(diamond, Theme.Stroke.Thick)
	diamond.Parent = clip
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
		if Store.paidRandomAllowed() then
			HUDController.Popup("NO SPINS LEFT — BUY MORE OR WAIT", C.RedLight)
			nudgeBuyButtons()
		else
			HUDController.Popup("NO SPINS LEFT — EARN MORE FROM QUESTS", C.RedLight)
		end
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
	-- the ratchet whirls fast, then slows with the wheel
	local whirl = Sound.loop("SpinWhirl", 0.9, 1.25)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - began) / S.SpinSeconds)
		wheelAngle = from + total * (1 - (1 - alpha) ^ 4)
		render()
		if whirl then
			-- speed of the ease-out (1 - (1-a)^4)' = 4(1-a)^3, mapped to pitch and volume
			local speed = (1 - alpha) ^ 3
			whirl.PlaybackSpeed = 0.7 + speed * 0.65
			whirl.Volume = 0.25 + speed * 0.65
		end
		local segment = math.floor(wheelAngle / THETA)
		if segment ~= lastSegment and os.clock() - lastTick > 0.05 then
			lastSegment = segment
			lastTick = os.clock()
			Sound.play("Tick", 0.75, 1.1 + alpha * 0.3)
		end
		if alpha >= 1 then
			connection:Disconnect()
			spinning = false
			if whirl then
				whirl:Stop()
				whirl:Destroy()
			end
			Sound.play("SpinWin", 0.9)
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

local shownCount = -1
local function refreshCounts()
	local n = spins()
	spinLabel.Text = string.format("SPIN [%d]", n)
	if shownCount >= 0 and n ~= shownCount then
		local pop = spinButton:FindFirstChildOfClass("UIScale")
		if pop then
			pop.Scale = 1.25
			Components.tween(pop, Theme.Tweens.Pop, { Scale = 1 })
		end
	end
	shownCount = n
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

-- A gold price pill with its caption ("SPIN 10") above it; x is the column centre.
local function buyButton(parent: Instance, key: string, x: number): TextButton
	local def = M.Products[key]
	local caption = Components.label({
		Name = key .. "Caption",
		Text = string.format("SPIN %d", def.Spins or 1),
		TextSize = 22,
		Size = UDim2.fromOffset(160, 26),
		Position = UDim2.new(0.5, x, 0, ROW_TOP),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = parent,
	})
	local button = Components.button({
		Name = key,
		Text = Store.robux(def.Price),
		TextSize = 26,
		Size = UDim2.fromOffset(150, 54),
		Position = UDim2.new(0.5, x, 0, ROW_TOP + 28),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = RIM_GOLD,
		ColorLight = RIM_GOLD_LIGHT,
		Parent = parent,
		OnClick = function()
			Store.promptProduct(key)
		end,
	})
	button:SetAttribute("Caption", caption.Name)
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
	root.Size = UDim2.fromOffset(600, ROW_TOP + 120)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Visible = false
	root.ZIndex = 9
	root.Parent = layer
	rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	-- header: a purple title bar with the red X block on its right
	local header = Components.panel({
		Name = "Header",
		Size = UDim2.fromOffset(360, 52),
		Position = UDim2.new(0.5, 0, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = HEADER_PURPLE,
		Transparency = 0,
		Parent = root,
	})
	Components.block(header, HEADER_PURPLE)
	Components.label({ Name = "Title", Text = "SPIN WHEEL", TextSize = 32, Size = UDim2.fromScale(1, 1), Parent = header })
	Components.button({
		Name = "Close",
		Text = "X",
		TextSize = 34,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(0.5, 194, 0, 2),
		AnchorPoint = Vector2.new(0, 0),
		Color = C.Red,
		ColorLight = C.RedLight,
		Parent = root,
		OnClick = function()
			SpinController.Close()
		end,
	})

	buildWheel(root)

	-- bottom row: SPIN 1 [price] · SPIN [n] · SPIN 10 [price]
	buyButton(root, "Spin1", -196)
	spinButton = Components.button({
		Name = "Spin",
		Text = "SPIN [0]",
		TextSize = 30,
		Size = UDim2.fromOffset(200, 62),
		Position = UDim2.new(0.5, 0, 0, ROW_TOP + 22),
		AnchorPoint = Vector2.new(0.5, 0),
		Sheen = true,
		Parent = root,
		OnClick = requestSpin,
	})
	spinLabel = (spinButton:FindFirstChild("Text") or spinButton:FindFirstChildWhichIsA("TextLabel", true)) :: TextLabel
	if not spinButton:FindFirstChildOfClass("UIScale") then
		Instance.new("UIScale").Parent = spinButton
	end
	buyButton(root, "Spin10", 196)

	-- where Robux spins aren't allowed (PolicyService), the buy buttons give way to a note
	local freeNote = Components.label({
		Name = "FreeSpinsNote",
		Text = "Earn Free Spins via Quests & Daily Login!",
		TextSize = 20,
		Color = C.GoldLight,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, ROW_TOP - 6),
		Parent = root,
	})
	local function refreshPolicy()
		local allowed = Store.paidRandomAllowed()
		for _, button in buyButtons do
			button.Visible = allowed
			local caption = root:FindFirstChild(button:GetAttribute("Caption") :: string)
			if caption and caption:IsA("GuiObject") then
				caption.Visible = allowed
			end
		end
		freeNote.Visible = not allowed
	end
	player:GetAttributeChangedSignal(Attributes.PaidRandomRestricted):Connect(refreshPolicy)
	refreshPolicy()

	timerLabel = Components.label({
		Name = "Timer",
		Text = "",
		TextSize = 22,
		Color = C.GreenLight,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, ROW_TOP + 90),
		Parent = root,
	})
	render()
end

function SpinController.IsOpen(): boolean
	return open
end

function SpinController.IsSpinning(): boolean
	return spinning
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
	local fit = Components.fitScale(root, rootScale)
	rootScale.Scale = 0.7 * fit
	Components.tween(rootScale, Theme.Tweens.Pop, { Scale = fit })
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
	gui.DisplayOrder = 10 -- opened on purpose: above the map vote and the HUD
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
				blink += 1
				local phase = blink // 2 % 2
				for b, bulb in bulbs do
					bulb.BackgroundColor3 = if (b + phase) % 2 == 0 then Color3.new(1, 1, 1) else RIM_GOLD_LIGHT
				end
			end
		end
	end)
end

return SpinController
