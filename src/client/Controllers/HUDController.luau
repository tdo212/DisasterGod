--!strict
-- HUDController: round bar (map tab on top, timer text, bar only while a round runs),
-- survivors/God pills, coins, God-chance card, offers, floating score popups, big
-- banners, first-time role cards and the round summary window.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Store = require(UI:WaitForChild("Store") :: ModuleScript)
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)

local Attributes = Config.Attributes
local M = Config.Match
local C = Theme.Colors
local player = Players.LocalPlayer

local HUDController = {}

local started = false
local gui: ScreenGui
local layer: Frame -- viewport-scaled root; all HUD content parents here
local touch = false

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

function HUDController.GetLayer(): Frame
	return layer
end

---------------------------------------------------------------------------
-- round bar (top centre): map tab above, timer text, bar only during a round

local BAR_TEXT_ONLY = 48
local BAR_WITH_TRACK = 68

local function buildRoundBar()
	local holder = Instance.new("Frame")
	holder.Name = "RoundBar"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(430, 130)
	holder.Position = UDim2.new(0.5, 0, 0, 2)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Parent = layer

	-- the map name rides on top of the bar as a tab
	local mapTab = Components.panel({
		Name = "MapTab",
		Size = UDim2.fromOffset(250, 28),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Blue,
		Radius = Theme.Radius.Small,
		Parent = holder,
	})
	mapTab.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.gradient(mapTab, C.BlueLight, C.Blue, 90, true)
	Components.studs(mapTab, nil, Theme.Radius.Small)
	mapTab.ZIndex = 2
	local mapText = Components.label({ Name = "Text", Text = "", TextSize = 17, Size = UDim2.new(1, -8, 1, -3), Position = UDim2.fromOffset(4, 0), Parent = mapTab })
	mapText.TextTruncate = Enum.TextTruncate.AtEnd

	local bar = Components.panel({
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, BAR_TEXT_ONLY),
		Position = UDim2.fromOffset(0, 24),
		Color = C.Panel,
		Transparency = 0.05,
		Radius = Theme.Radius.Medium,
		Studs = true,
		Parent = holder,
	})
	local title = Components.label({
		Name = "Title",
		Text = "Waiting for players…",
		TextSize = 26,
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.fromOffset(10, 9),
		Parent = bar,
	})
	title.RichText = true
	local track, setFill, gradient = Components.progress(bar, UDim2.new(1, -36, 0, 14), UDim2.fromOffset(18, 45), C.GreenLight, C.Green)

	-- info pills under the bar
	local pills = Instance.new("Frame")
	pills.Name = "Pills"
	pills.BackgroundTransparency = 1
	pills.Size = UDim2.fromOffset(560, 26)
	pills.Position = UDim2.new(0.5, 0, 0, 24 + BAR_TEXT_ONLY + 6)
	pills.AnchorPoint = Vector2.new(0.5, 0)
	pills.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pills
	local pillCount = 0
	local function pill(name: string): TextLabel
		pillCount += 1
		local label = Components.label({ Name = name, Text = "", TextSize = 19, Size = UDim2.fromOffset(0, 24), Parent = pills })
		label.AutomaticSize = Enum.AutomaticSize.X
		label.LayoutOrder = pillCount
		return label
	end
	local alivePill = pill("Alive")
	local godPill = pill("God")
	local rolePill = pill("Role")

	local showingTrack: boolean? = nil
	local function setTrack(show: boolean)
		if showingTrack == show then
			return
		end
		showingTrack = show
		track.Visible = show
		local height = if show then BAR_WITH_TRACK else BAR_TEXT_ONLY
		Components.tween(bar, Theme.Tweens.Fade, { Size = UDim2.new(1, 0, 0, height) })
		Components.tween(pills, Theme.Tweens.Fade, { Position = UDim2.new(0.5, 0, 0, 24 + height + 6) })
	end

	local function refresh()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		local sub = ReplicatedStorage:GetAttribute(Attributes.SubPhase)
		local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining) :: number? or 0
		local map = ReplicatedStorage:GetAttribute(Attributes.MapName) :: string? or ""
		local alive = ReplicatedStorage:GetAttribute(Attributes.AliveCount) :: number? or 0
		local god = ReplicatedStorage:GetAttribute(Attributes.GodName) :: string? or ""
		local role = player:GetAttribute(Attributes.Role) :: string? or "Spectator"

		local top, bottom = C.GreenLight, C.Green
		local fraction: number? = nil -- nil = no bar (text is enough)
		if phase == "Intermission" then
			if ReplicatedStorage:GetAttribute(Attributes.VoteOpen) == true then
				local left = t - (M.IntermissionDuration - Config.Voting.Duration)
				title.Text = string.format("🗳️ Map vote closes in <font color=\"#FFD23C\">%ds</font>", math.max(0, left))
			else
				title.Text = string.format("Round starts in <font color=\"#FFD23C\">%ds</font>", t)
			end
		elseif phase == "Active" then
			local suddenAt = M.SuddenDeathDuration
			if sub == "Prep" then
				local untilCast = math.max(0, t - (M.RoundDuration - M.PrepDuration))
				title.Text = string.format("SCATTER! Disasters in <font color=\"#FFD23C\">%ds</font>", untilCast)
				top, bottom = C.BlueLight, C.Blue
				fraction = untilCast / M.PrepDuration
			elseif sub == "SuddenDeath" then
				title.Text = "SUDDEN DEATH  " .. formatTime(t)
				top, bottom = C.RedLight, C.Red
				fraction = t / suddenAt
			else
				title.Text = "SURVIVE  " .. formatTime(t)
				top, bottom = C.OrangeLight, C.Orange
				fraction = (t - suddenAt) / math.max(1, M.RoundDuration - M.PrepDuration - suddenAt)
			end
		elseif phase == "RoundEnd" then
			title.Text = string.format("ROUND OVER · next in <font color=\"#FFD23C\">%ds</font>", t)
		else
			title.Text = "Waiting for players…"
		end
		setTrack(fraction ~= nil)
		if fraction then
			gradient.Color = Components.gloss(top, bottom, true)
			setFill(fraction)
		end

		mapTab.Visible = map ~= ""
		mapText.Text = "🗺️ " .. map
		alivePill.Text = if phase == "Active" then "🏃 Survivors " .. tostring(alive) else ""
		godPill.Text = if phase == "Active" and god ~= "" then "😈 " .. god else ""
		local roleText = if role == "DisasterGod" then "DISASTER GOD" elseif role == "Survivor" then (if player:GetAttribute(Attributes.Alive) then "SURVIVOR" else "ELIMINATED") else "SPECTATOR"
		rolePill.Text = "⭐ " .. roleText
		rolePill.TextColor3 = if role == "DisasterGod" then C.PurpleLight elseif role == "Survivor" then C.GreenLight else C.TextDim
	end

	for _, attr in { Attributes.RoundPhase, Attributes.SubPhase, Attributes.TimeRemaining, Attributes.MapName, Attributes.AliveCount, Attributes.GodName, Attributes.VoteOpen } do
		ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refresh)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(refresh)
	refresh()
end

---------------------------------------------------------------------------
-- coins + streak (bottom left; top right on touch so the thumbstick stays clear)

local function buildCoins()
	local frame = Instance.new("Frame")
	frame.Name = "Wallet"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(if touch then 190 else 250, 56)
	if touch then
		frame.Position = UDim2.new(1, -12, 0, 2)
		frame.AnchorPoint = Vector2.new(1, 0)
	else
		frame.Position = UDim2.new(0, 16, 1, -14)
		frame.AnchorPoint = Vector2.new(0, 1)
	end
	frame.Parent = layer
	Components.label({ Name = "Icon", Text = "💰", TextSize = 38, Size = UDim2.fromOffset(46, 52), StrokeThickness = 0, Parent = frame })
	local amount = Components.label({
		Name = "Amount",
		Text = "$0",
		TextSize = 40,
		Size = UDim2.new(1, -52, 0, 52),
		Position = UDim2.fromOffset(52, 0),
		Color = C.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = Theme.Stroke.Heavy,
		Parent = frame,
	})
	local streak = Components.label({
		Name = "Streak",
		Text = "",
		TextSize = if touch then 17 else 20,
		Size = UDim2.fromOffset(240, 24),
		Position = if touch then UDim2.new(1, -240, 0, 52) else UDim2.fromOffset(4, -24),
		Color = C.OrangeLight,
		XAlign = if touch then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
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
-- God chance card (right side) — the "one more round" hook; the whole card buys God

local function buildGodChance()
	local card = Instance.new("TextButton")
	card.Name = "GodChance"
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	if touch then
		card.Size = UDim2.fromOffset(164, 196)
		card.Position = UDim2.new(1, -12, 0, 84)
		card.AnchorPoint = Vector2.new(1, 0)
	else
		card.Size = UDim2.fromOffset(176, 214)
		card.Position = UDim2.new(1, -16, 0.5, -40)
		card.AnchorPoint = Vector2.new(1, 0.5)
	end
	Components.corner(card, Theme.Radius.Large)
	Components.stroke(card, Theme.Stroke.Heavy)
	Components.gradient(card, C.PurpleLight, C.Purple, 90, true)
	Components.studs(card, nil, Theme.Radius.Large)
	card.Parent = layer

	Components.label({ Name = "Caption", Text = "Next round", TextSize = 17, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 6), Parent = card })
	Components.label({ Name = "Headline", Text = "Be the GOD", TextSize = 24, Color = C.PinkLight, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 26), Parent = card })
	Components.label({ Name = "Face", Text = "😈", TextSize = 42, StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 54), Parent = card })
	local pct = Components.label({ Name = "Percent", Text = "0%", TextSize = 32, Color = C.Gold, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 100), StrokeThickness = Theme.Stroke.Heavy, Parent = card })
	local scale = Components.pressable(card)

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

	local god = Config.Monetization.Products.GodNextRound
	local pill = Components.panel({
		Name = "Price",
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Green,
		Radius = Theme.Radius.Medium,
		Parent = card,
	})
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.gradient(pill, C.GreenLight, C.Green, 90, true)
	Components.studs(pill)
	local pillText = Components.label({ Name = "Text", Text = "", TextSize = 20, Size = UDim2.new(1, 0, 1, -4), Parent = pill })
	card.Activated:Connect(function()
		if player:GetAttribute(Attributes.GodQueued) == true then
			Sound.play("Error", 0.6)
			return
		end
		Sound.play("Click", 0.9)
		Store.promptProduct("GodNextRound")
	end)
	local function refreshGuarantee()
		local queued = player:GetAttribute(Attributes.GodQueued) == true
		pillText.Text = if queued then "QUEUED ✔" else (if touch then "TAP · " else "BUY · ") .. Store.robux(god.Price)
	end
	player:GetAttributeChangedSignal(Attributes.GodQueued):Connect(refreshGuarantee)
	refreshGuarantee()
end

---------------------------------------------------------------------------
-- Welcome Pack offer (under the God card) — only after the first finished round,
-- once the player knows the loop

local function buildWelcomeOffer()
	local def = Config.Monetization.Products.WelcomePack
	local offer = Instance.new("TextButton")
	offer.Name = "WelcomePack"
	offer.Text = ""
	offer.AutoButtonColor = false
	offer.BackgroundColor3 = Color3.new(1, 1, 1)
	if touch then
		offer.Size = UDim2.fromOffset(164, 112)
		offer.Position = UDim2.new(1, -12, 0, 288)
	else
		offer.Size = UDim2.fromOffset(176, 126)
		offer.Position = UDim2.new(1, -16, 0.5, 76)
	end
	offer.AnchorPoint = Vector2.new(1, 0)
	Components.corner(offer, Theme.Radius.Large)
	Components.stroke(offer, Theme.Stroke.Heavy)
	Components.gradient(offer, C.OrangeLight, C.Orange, 90, true)
	Components.studs(offer, nil, Theme.Radius.Large)
	offer.Parent = layer
	Components.label({ Name = "Title", Text = def.Icon .. " Welcome Pack", TextSize = 19, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 6), Parent = offer })
	Components.label({
		Name = "Coins",
		Text = "+" .. HUDController.FormatNumber(def.Coins or 0) .. " Coins + Kit",
		TextSize = 18,
		Color = C.GoldLight,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 32),
		Parent = offer,
	})
	local was = Components.label({
		Name = "ListPrice",
		Text = Store.robux(Config.Monetization.WelcomePackListPrice),
		TextSize = 16,
		Color = C.RedLight,
		Size = UDim2.fromOffset(64, 22),
		Position = UDim2.new(0, 8, 1, -42),
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
		Size = UDim2.fromOffset(88, 32),
		Position = UDim2.new(1, -8, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Green,
		Radius = Theme.Radius.Medium,
		Parent = offer,
	})
	price.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.gradient(price, C.GreenLight, C.Green, 90, true)
	Components.label({ Name = "Text", Text = Store.robux(def.Price), TextSize = 18, Size = UDim2.new(1, 0, 1, -3), Parent = price })
	Components.pressable(offer, 1.05)
	offer.Activated:Connect(function()
		Store.promptProduct("WelcomePack")
	end)
	local function refresh()
		local played = player:GetAttribute(Attributes.RoundsPlayed) :: number? or 0
		offer.Visible = player:GetAttribute(Attributes.WelcomeClaimed) ~= true and played >= 1 and offersVisible()
	end
	player:GetAttributeChangedSignal(Attributes.WelcomeClaimed):Connect(refresh)
	player:GetAttributeChangedSignal(Attributes.RoundsPlayed):Connect(refresh)
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
		ColorLight = C.PinkLight,
		Parent = layer,
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
	local upper = string.upper(text)
	if string.find(upper, "BOUGHT", 1, true) or string.find(upper, "UNLOCKED", 1, true) or string.find(upper, "THANK", 1, true) or string.find(upper, "CLAIMED", 1, true) or string.find(upper, "WHEEL WIN", 1, true) then
		Sound.play("Purchase", 0.9)
	elseif string.find(text, "+", 1, true) then
		Sound.play("Coin", 0.8, 0.95 + math.random() * 0.15)
	elseif string.find(upper, "NOT ENOUGH", 1, true) or string.find(upper, "ONLY", 1, true) then
		Sound.play("Error", 0.7)
	else
		Sound.play("Open", 0.4, 1.3)
	end
	popupLane = (popupLane + 1) % 4
	local label = Components.label({
		Name = "Popup",
		Text = text,
		TextSize = 30,
		Color = color or C.Gold,
		Size = UDim2.fromOffset(520, 38),
		Position = UDim2.new(0.5, 0, 0.4, popupLane * 34),
		AnchorPoint = Vector2.new(0.5, 0.5),
		StrokeThickness = Theme.Stroke.Heavy,
		Parent = layer,
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
	bannerFrame.Position = UDim2.fromScale(0.5, 0.32)
	bannerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	bannerFrame.Visible = false
	bannerFrame.Parent = layer
	bannerTitle = Components.label({ Name = "Title", Text = "", TextSize = 56, Size = UDim2.new(1, 0, 0, 64), StrokeThickness = 5, Parent = bannerFrame })
	bannerSub = Components.label({ Name = "Subtitle", Text = "", TextSize = 23, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 66), Parent = bannerFrame })
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = bannerFrame
end

function HUDController.Banner(title: string, subtitle: string?, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	Sound.play("Banner", 0.8)
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
-- first-time role cards: three bullets, shown once per role

type RoleCard = { Title: string, Color: Color3, Light: Color3, Bullets: { string } }

local function roleCards(): { [string]: RoleCard }
	return {
		God = {
			Title = "😈 YOU ARE THE DISASTER GOD",
			Color = C.Purple,
			Light = C.PurpleLight,
			Bullets = if touch
				then { "👆 Drag to fly · pinch to zoom", "🎯 Pick a disaster, then tap the arena", "📡 Round radar button finds hidden survivors" }
				else { "🕹️ WASD to fly · scroll to zoom", "🎯 Keys 1-5 pick · click to cast", "📡 Key 6 pings survivors hiding indoors" },
		},
		Survivor = {
			Title = "🏃 SURVIVE THE DISASTERS",
			Color = C.Green,
			Light = C.GreenLight,
			Bullets = {
				"🔴 Red zones mean a disaster is about to hit",
				if touch then "💨 Tap DASH to dodge out of danger" else "💨 Press Q to DASH out of danger",
				"🫥 Stand still indoors to hide · jumping is loud",
			},
		},
	}
end

local cardShown: { [string]: boolean } = {}
local openCard: Frame? = nil

local function showRoleCard(kind: string)
	local spec = roleCards()[kind]
	if not spec or cardShown[kind] then
		return
	end
	cardShown[kind] = true
	if openCard then
		openCard:Destroy()
	end
	local card = Components.panel({
		Name = "RoleCard",
		Size = UDim2.fromOffset(500, 250),
		Position = UDim2.fromScale(0.5, 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Window,
		Transparency = 0.05,
		Radius = Theme.Radius.Large,
		Studs = true,
		Parent = layer,
	})
	card.ZIndex = 15
	openCard = card
	local header = Components.panel({ Name = "Header", Size = UDim2.new(1, 0, 0, 52), Color = spec.Color, Radius = Theme.Radius.Large, Parent = card })
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.gradient(header, spec.Light, spec.Color, 90, true)
	Components.studs(header, nil, Theme.Radius.Large)
	Components.label({ Name = "Title", Text = spec.Title, TextSize = 27, Size = UDim2.new(1, 0, 1, -5), Parent = header })
	for i, bullet in spec.Bullets do
		Components.label({
			Name = "Bullet" .. i,
			Text = bullet,
			TextSize = 23,
			XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -40, 0, 30),
			Position = UDim2.fromOffset(24, 64 + (i - 1) * 38),
			Parent = card,
		})
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card
	Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
	local function dismiss()
		if card.Parent then
			card:Destroy()
		end
		if openCard == card then
			openCard = nil
		end
	end
	Components.button({
		Name = "GotIt",
		Text = "GOT IT!",
		TextSize = 24,
		Size = UDim2.fromOffset(190, 50),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = card,
		OnClick = dismiss,
	})
	Remotes.get("TutorialSeen"):FireServer(kind)
	task.delay(Config.Onboarding.CardSeconds, dismiss)
end

local function roleKind(): string?
	if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" then
		return nil
	end
	local role = player:GetAttribute(Attributes.Role)
	return if role == "DisasterGod" then "God" elseif role == "Survivor" then "Survivor" else nil
end

local function evaluateRoleCard()
	local kind = roleKind()
	if kind and not cardShown[kind] and player:GetAttribute(Attributes.TutorialPrefix .. kind) ~= true then
		-- wait for the round-start banner to clear, then show the card if the role still holds
		task.delay(Config.Onboarding.CardDelay, function()
			if roleKind() == kind then
				showRoleCard(kind)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- round summary

local function showSummary(summary: any)
	local window = Components.window(layer, "Round Over", UDim2.fromOffset(520, 420))
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
	task.delay(M.RoundEndDuration - 0.5, function()
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
	touch = Components.isTouch()

	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 1 -- role cards and popups sit above the God / survivor HUDs
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	buildRoundBar()
	buildCoins()
	buildGodChance()
	buildBanner()
	buildWelcomeOffer()
	buildReviveOffer()

	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluateRoleCard)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(evaluateRoleCard)
	evaluateRoleCard()

	Remotes.get("Popup").OnClientEvent:Connect(function(text: string, color: Color3?)
		if typeof(text) == "string" then
			HUDController.Popup(text, color)
		end
	end)
	Remotes.get("Banner").OnClientEvent:Connect(function(title: string, subtitle: string?, color: Color3?)
		if typeof(title) == "string" then
			HUDController.Banner(Components.inputText(title), if typeof(subtitle) == "string" then Components.inputText(subtitle) else nil, color)
		end
	end)
	Remotes.get("RoundSummary").OnClientEvent:Connect(function(summary)
		if typeof(summary) == "table" then
			showSummary(summary)
		end
	end)
end

return HUDController
