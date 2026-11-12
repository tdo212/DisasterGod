--!strict
-- HUDController: round bar + timer, survivors/God pills, coins, God-chance card,
-- floating score popups, big banners and the round summary window.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Store = require(UI:WaitForChild("Store") :: ModuleScript)

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local HUDController = {}

local started = false
local gui: ScreenGui
local shopOpener: ((string?) -> ())? = nil

-- MenuController registers how to open the shop (avoids a require cycle).
function HUDController.SetShopOpener(fn: (string?) -> ())
	shopOpener = fn
end

local function offersVisible(): boolean
	local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	local role = player:GetAttribute(Attributes.Role)
	return phase ~= "Active" or role == "Spectator"
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function HUDController.FormatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

---------------------------------------------------------------------------
-- round bar (top centre)

local function buildRoundBar()
	local bar = Components.panel({
		Name = "RoundBar",
		Size = UDim2.fromOffset(420, 64),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Panel,
		Transparency = 0.08,
		Radius = Theme.Radius.Medium,
		Parent = gui,
	})
	local title = Components.label({
		Name = "Title",
		Text = "Waiting for players…",
		TextSize = 26,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 4),
		Parent = bar,
	})
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -40, 0, 14)
	track.Position = UDim2.new(0, 20, 1, -22)
	track.BackgroundColor3 = C.Slot
	track.BorderSizePixel = 0
	Components.corner(track, Theme.Radius.Pill)
	Components.stroke(track, Theme.Stroke.Thin)
	track.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	Components.corner(fill, Theme.Radius.Pill)
	local gradient = Components.gradient(fill, C.GreenLight, C.Green)
	fill.Parent = track

	-- info pills under the bar
	local pills = Instance.new("Frame")
	pills.Name = "Pills"
	pills.BackgroundTransparency = 1
	pills.Size = UDim2.fromOffset(520, 30)
	pills.Position = UDim2.new(0.5, 0, 0, 78)
	pills.AnchorPoint = Vector2.new(0.5, 0)
	pills.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pills
	local pillCount = 0
	local function pill(name: string): TextLabel
		pillCount += 1
		local label = Components.label({
			Name = name,
			Text = "",
			TextSize = 20,
			Size = UDim2.fromOffset(0, 26),
			Parent = pills,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		label.LayoutOrder = pillCount
		return label
	end
	local mapPill = pill("Map")
	local alivePill = pill("Alive")
	local godPill = pill("God")
	local rolePill = pill("Role")

	local function refresh()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		local sub = ReplicatedStorage:GetAttribute(Attributes.SubPhase)
		local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining) :: number? or 0
		local duration = ReplicatedStorage:GetAttribute(Attributes.PhaseDuration) :: number? or 1
		local map = ReplicatedStorage:GetAttribute(Attributes.MapName) :: string? or ""
		local alive = ReplicatedStorage:GetAttribute(Attributes.AliveCount) :: number? or 0
		local god = ReplicatedStorage:GetAttribute(Attributes.GodName) :: string? or ""
		local role = player:GetAttribute(Attributes.Role) :: string? or "Spectator"

		local top, bottom = C.GreenLight, C.Green
		if phase == "Intermission" then
			title.Text = string.format("Round starts in <font color=\"#FFD23C\">%ds</font>", t)
		elseif phase == "Active" then
			if sub == "Prep" then
				local untilCast = t - (Config.Match.RoundDuration - Config.Match.PrepDuration)
				title.Text = string.format("SCATTER! Disasters in <font color=\"#FFD23C\">%ds</font>", math.max(0, untilCast))
				top, bottom = C.BlueLight, C.Blue
			elseif sub == "SuddenDeath" then
				title.Text = "SUDDEN DEATH  " .. formatTime(t)
				top, bottom = C.RedLight, C.Red
			else
				title.Text = "SURVIVE  " .. formatTime(t)
				top, bottom = C.OrangeLight, C.Orange
			end
		elseif phase == "RoundEnd" then
			title.Text = "ROUND OVER"
			top, bottom = C.PurpleLight, C.Purple
		end
		gradient.Color = ColorSequence.new(top, bottom)
		Components.tween(fill, Theme.Tweens.Fade, { Size = UDim2.fromScale(math.clamp(t / math.max(1, duration), 0, 1), 1) })

		mapPill.Text = if map ~= "" then "🗺️ " .. map else ""
		alivePill.Text = if phase == "Active" then "🏃 Survivors " .. tostring(alive) else ""
		godPill.Text = if phase == "Active" and god ~= "" then "😈 " .. god else ""
		local roleText = if role == "DisasterGod" then "DISASTER GOD" elseif role == "Survivor" then (if player:GetAttribute(Attributes.Alive) then "SURVIVOR" else "ELIMINATED") else "SPECTATOR"
		rolePill.Text = "⭐ " .. roleText
		rolePill.TextColor3 = if role == "DisasterGod" then C.PurpleLight elseif role == "Survivor" then C.GreenLight else C.TextDim
	end
	title.RichText = true

	for _, attr in { Attributes.RoundPhase, Attributes.SubPhase, Attributes.TimeRemaining, Attributes.MapName, Attributes.AliveCount, Attributes.GodName } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refresh)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(refresh)
	refresh()
end

---------------------------------------------------------------------------
-- coins (bottom left) + streak

local function buildCoins()
	local frame = Instance.new("Frame")
	frame.Name = "Wallet"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(260, 60)
	frame.Position = UDim2.new(0, 16, 1, -16)
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Parent = gui
	Components.label({
		Name = "Icon",
		Text = "💰",
		TextSize = 42,
		Size = UDim2.fromOffset(50, 56),
		StrokeThickness = 0,
		Parent = frame,
	})
	local amount = Components.label({
		Name = "Amount",
		Text = "$0",
		TextSize = 44,
		Size = UDim2.new(1, -56, 0, 56),
		Position = UDim2.fromOffset(56, 0),
		Color = C.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = Theme.Stroke.Heavy,
		Parent = frame,
	})
	local streak = Components.label({
		Name = "Streak",
		Text = "",
		TextSize = 22,
		Size = UDim2.fromOffset(220, 26),
		Position = UDim2.fromOffset(4, -24),
		Color = C.OrangeLight,
		XAlign = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = amount
	local last = 0
	local function refresh()
		local coins = player:GetAttribute(Attributes.Coins) :: number? or 0
		amount.Text = "$" .. HUDController.FormatNumber(coins)
		if coins > last then
			scale.Scale = 1.25
			Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
		end
		last = coins
		local s = player:GetAttribute(Attributes.Streak) :: number? or 0
		streak.Text = if s > 0 then string.format("🔥 Survival streak %d", s) else ""
	end
	player:GetAttributeChangedSignal(Attributes.Coins):Connect(refresh)
	player:GetAttributeChangedSignal(Attributes.Streak):Connect(refresh)
	refresh()
end

---------------------------------------------------------------------------
-- God chance card (right side) — the "one more round" hook

local function buildGodChance()
	local card = Instance.new("Frame")
	card.Name = "GodChance"
	card.Size = UDim2.fromOffset(170, 170)
	card.Position = UDim2.new(1, -16, 0.5, -40)
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(card, Theme.Radius.Large)
	Components.stroke(card, Theme.Stroke.Heavy)
	Components.gradient(card, C.PurpleLight, C.Purple)
	card.Parent = gui

	Components.label({ Name = "Caption", Text = "Next round", TextSize = 18, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 8), Parent = card })
	Components.label({ Name = "Headline", Text = "Be the GOD", TextSize = 24, Color = C.Pink, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 30), Parent = card })
	Components.label({ Name = "Face", Text = "😈", TextSize = 46, StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 58), Parent = card })
	local pct = Components.label({ Name = "Percent", Text = "0%", TextSize = 34, Color = C.Gold, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -48), StrokeThickness = Theme.Stroke.Heavy, Parent = card })
	local scale = Instance.new("UIScale")
	scale.Parent = card

	local last = -1
	local function refresh()
		card.Visible = offersVisible()
		local chance = player:GetAttribute(Attributes.GodChance) :: number? or 0
		pct.Text = string.format("%s%%", if chance % 1 == 0 then tostring(math.floor(chance)) else string.format("%.1f", chance))
		if last >= 0 and chance > last then
			scale.Scale = 1.15
			Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
		end
		last = chance
	end
	player:GetAttributeChangedSignal(Attributes.GodChance):Connect(refresh)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refresh)
	refresh()

	-- Robux shortcut: guarantee God next round
	local god = Config.Monetization.Products.GodNextRound
	local guarantee = Components.button({
		Name = "Guarantee",
		Text = Store.robux(god.Price) .. " GUARANTEE",
		TextSize = 16,
		Size = UDim2.fromOffset(160, 34),
		Position = UDim2.new(0.5, 0, 1, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Green,
		ColorLight = C.GreenLight,
		Parent = card,
		OnClick = function()
			if player:GetAttribute(Attributes.GodQueued) ~= true then
				Store.promptProduct("GodNextRound")
			end
		end,
	})
	local function refreshGuarantee()
		local queued = player:GetAttribute(Attributes.GodQueued) == true
		Components.setText(guarantee, if queued then "QUEUED ✔" else Store.robux(god.Price) .. " GUARANTEE")
	end
	player:GetAttributeChangedSignal(Attributes.GodQueued):Connect(refreshGuarantee)
	refreshGuarantee()
end

---------------------------------------------------------------------------
-- Welcome Pack offer (right side, under the God card) + Second Chance revive offer

local function buildWelcomeOffer()
	local def = Config.Monetization.Products.WelcomePack
	local offer = Instance.new("TextButton")
	offer.Name = "WelcomePack"
	offer.Text = ""
	offer.AutoButtonColor = false
	offer.Size = UDim2.fromOffset(170, 132)
	offer.Position = UDim2.new(1, -16, 0.5, 112)
	offer.AnchorPoint = Vector2.new(1, 0)
	offer.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(offer, Theme.Radius.Large)
	Components.stroke(offer, Theme.Stroke.Heavy)
	Components.gradient(offer, C.OrangeLight, C.Orange)
	offer.Parent = gui
	Components.label({ Name = "Title", Text = "Welcome Pack", TextSize = 20, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 6), Parent = offer })
	Components.label({ Name = "Icon", Text = def.Icon, TextSize = 30, StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 28), Parent = offer })
	Components.label({
		Name = "Coins",
		Text = "+" .. HUDController.FormatNumber(def.Coins or 0) .. " Coins",
		TextSize = 20,
		Color = C.Gold,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 62),
		Parent = offer,
	})
	local was = Components.label({
		Name = "ListPrice",
		Text = Store.robux(Config.Monetization.WelcomePackListPrice),
		TextSize = 16,
		Color = C.RedLight,
		Size = UDim2.fromOffset(60, 22),
		Position = UDim2.new(0, 10, 1, -32),
		Parent = offer,
	})
	local strike = Instance.new("Frame")
	strike.Size = UDim2.new(1, 0, 0, 2)
	strike.Position = UDim2.fromScale(0, 0.5)
	strike.BackgroundColor3 = C.Red
	strike.BorderSizePixel = 0
	strike.Rotation = -12
	strike.Parent = was
	local price = Components.panel({
		Name = "Price",
		Size = UDim2.fromOffset(84, 30),
		Position = UDim2.new(1, -8, 1, -6),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Green,
		Radius = Theme.Radius.Pill,
		Parent = offer,
	})
	Components.label({ Name = "Text", Text = Store.robux(def.Price), TextSize = 18, Size = UDim2.fromScale(1, 1), Parent = price })
	local scale = Instance.new("UIScale")
	scale.Parent = offer
	offer.MouseEnter:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 1.05 })
	end)
	offer.MouseLeave:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 1 })
	end)
	offer.Activated:Connect(function()
		Store.promptProduct("WelcomePack")
	end)
	local function refresh()
		offer.Visible = player:GetAttribute(Attributes.WelcomeClaimed) ~= true and offersVisible()
	end
	player:GetAttributeChangedSignal(Attributes.WelcomeClaimed):Connect(refresh)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refresh)
	refresh()
end

local function buildReviveOffer()
	local def = Config.Monetization.Products.Revive
	local button = Components.button({
		Name = "SecondChance",
		Text = def.Icon .. " SECOND CHANCE  " .. Store.robux(def.Price),
		TextSize = 24,
		Size = UDim2.fromOffset(340, 60),
		Position = UDim2.new(0.5, 0, 1, -120),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Pink,
		ColorLight = Color3.fromRGB(255, 150, 190),
		Parent = gui,
		OnClick = function()
			Store.promptProduct("Revive")
		end,
	})
	button.Visible = false
	local token = 0
	local function eliminated(): boolean
		return player:GetAttribute(Attributes.Role) == "Survivor"
			and player:GetAttribute(Attributes.Alive) ~= true
			and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active"
	end
	local function refresh()
		token += 1
		local my = token
		if eliminated() then
			button.Visible = true
			task.delay(Config.Monetization.ReviveOfferSeconds, function()
				if my == token then
					button.Visible = false
				end
			end)
		else
			button.Visible = false
		end
	end
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refresh)
end

---------------------------------------------------------------------------
-- popups + banners

local popupLane = 0

function HUDController.Popup(text: string, color: Color3?)
	popupLane = (popupLane + 1) % 4
	local label = Components.label({
		Name = "Popup",
		Text = text,
		TextSize = 32,
		Color = color or C.Gold,
		Size = UDim2.fromOffset(420, 40),
		Position = UDim2.new(0.5, 120, 0.42, popupLane * 36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = Theme.Stroke.Heavy,
		Parent = gui,
	})
	label.ZIndex = 20
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
	task.delay(0.6, function()
		Components.tween(label, Theme.Tweens.Float, {
			Position = label.Position - UDim2.fromOffset(0, 60),
			TextTransparency = 1,
		})
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			Components.tween(stroke, Theme.Tweens.Float, { Transparency = 1 })
		end
		task.delay(1.3, function()
			label:Destroy()
		end)
	end)
end

local bannerFrame: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel
local bannerScale: UIScale
local bannerToken = 0

local function buildBanner()
	bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "Banner"
	bannerFrame.BackgroundTransparency = 1
	bannerFrame.Size = UDim2.fromOffset(800, 110)
	bannerFrame.Position = UDim2.fromScale(0.5, 0.28)
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerFrame.Visible = false
	bannerFrame.Parent = gui
	bannerTitle = Components.label({ Name = "Title", Text = "", TextSize = 58, Size = UDim2.new(1, 0, 0, 64), StrokeThickness = 5, Parent = bannerFrame })
	bannerSub = Components.label({ Name = "Subtitle", Text = "", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 68), Parent = bannerFrame })
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = bannerFrame
end

function HUDController.Banner(title: string, subtitle: string?, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color or C.Text
	bannerSub.Text = subtitle or ""
	for _, label in { bannerTitle, bannerSub } do
		label.TextTransparency = 0
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0
		end
	end
	bannerFrame.Visible = true
	bannerScale.Scale = 0.4
	Components.tween(bannerScale, Theme.Tweens.Pop, { Scale = 1 })
	task.delay(2.8, function()
		if token ~= bannerToken then
			return
		end
		for _, label in { bannerTitle, bannerSub } do
			Components.tween(label, Theme.Tweens.Fade, { TextTransparency = 1 })
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				Components.tween(stroke, Theme.Tweens.Fade, { Transparency = 1 })
			end
		end
		task.delay(0.3, function()
			if token == bannerToken then
				bannerFrame.Visible = false
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- round summary

local function showSummary(summary: any)
	local window = Components.window(gui, "Round Over", UDim2.fromOffset(520, 430))
	local content = window.Content
	local headline = if summary.Role == "DisasterGod" then "GOD ROUND COMPLETE" elseif summary.Survived then "YOU SURVIVED!" else "ELIMINATED"
	local headColor = if summary.Role == "DisasterGod" then C.PurpleLight elseif summary.Survived then C.GreenLight else C.RedLight
	Components.label({ Name = "Headline", Text = headline, TextSize = 34, Color = headColor, Size = UDim2.new(1, 0, 0, 40), Parent = content })
	Components.label({
		Name = "Info",
		Text = string.format("%s · %d survived · God: %s", summary.MapName, summary.SurvivorCount, summary.GodName),
		TextSize = 18,
		Color = C.TextDim,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 40),
		Parent = content,
	})
	local y = 72
	for _, line in summary.Lines do
		Components.label({ Name = "Line", Text = line.Text, TextSize = 21, XAlign = Enum.TextXAlignment.Left, Size = UDim2.new(0.7, 0, 0, 26), Position = UDim2.fromOffset(16, y), Parent = content })
		Components.label({ Name = "Amount", Text = "+" .. tostring(line.Amount), TextSize = 21, Color = C.Gold, XAlign = Enum.TextXAlignment.Right, Size = UDim2.new(0.3, -16, 0, 26), Position = UDim2.new(0.7, 0, 0, y), Parent = content })
		y += 28
	end
	Components.label({ Name = "Total", Text = "TOTAL  💰 " .. tostring(summary.Total), TextSize = 28, Color = C.Gold, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, y + 6), Parent = content })
	local podiumText = {}
	for i, entry in summary.Podium do
		table.insert(podiumText, string.format("%s %s", ({ "🥇", "🥈", "🥉" })[i], entry.Name))
	end
	Components.label({
		Name = "Podium",
		Text = table.concat(podiumText, "   "),
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 1, -30),
		Parent = content,
	})
	window.Open()
	task.delay(Config.Match.RoundEndDuration - 0.5, function()
		window.Close()
		task.delay(0.5, function()
			window.Root:Destroy()
		end)
	end)
end

---------------------------------------------------------------------------

function HUDController.GetGui(): ScreenGui
	return gui
end

function HUDController.Start()
	if started then
		return
	end
	started = true

	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	buildRoundBar()
	buildCoins()
	buildGodChance()
	buildBanner()
	buildWelcomeOffer()
	buildReviveOffer()

	Remotes.get("Popup").OnClientEvent:Connect(function(text: string, color: Color3?)
		if typeof(text) == "string" then
			HUDController.Popup(text, color)
		end
	end)
	Remotes.get("Banner").OnClientEvent:Connect(function(title: string, subtitle: string?, color: Color3?)
		if typeof(title) == "string" then
			HUDController.Banner(title, subtitle, color)
		end
	end)
	Remotes.get("RoundSummary").OnClientEvent:Connect(function(summary)
		if typeof(summary) == "table" then
			showSummary(summary)
		end
	end)
end

return HUDController
