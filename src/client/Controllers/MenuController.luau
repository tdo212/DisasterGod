--!strict
-- MenuController: the two-column tile menu (Shop, Spin, Quests, Passes, Spectate, solo
-- role toggle) and the tabbed Shop window — Gear (coins), God Kits (coins), Style (God
-- skins, disaster FX, finishers), Coins (Robux packs), Passes, Specials (incl. panic
-- saves). Pages scroll sideways when cards overflow. Lobby proximity prompts (shop stall,
-- quest board, prize wheel, pass pedestals, skin displays) open the matching UI.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local Store = require(ClientRoot:WaitForChild("UI"):WaitForChild("Store") :: ModuleScript)
local Analytics = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Analytics") :: ModuleScript)
local SpectateController = require(script.Parent:WaitForChild("SpectateController") :: ModuleScript)
local SettingsController = require(script.Parent:WaitForChild("SettingsController") :: ModuleScript)
local HUDController = require(script.Parent:WaitForChild("HUDController") :: ModuleScript)
local SpinController = require(script.Parent:WaitForChild("SpinController") :: ModuleScript)
local QuestController = require(script.Parent:WaitForChild("QuestController") :: ModuleScript)

local Attributes = Config.Attributes
local M = Config.Monetization
local C = Theme.Colors
local player = Players.LocalPlayer

local MenuController = {}

local started = false
local gui: ScreenGui
local layer: Frame -- viewport-scaled root for all UI content
local shop: any -- Components.WindowHandle
local pages: { [string]: GuiObject } = {}
local tabButtons: { [string]: TextButton } = {}
local TAB_ORDER = { "Gear", "Kits", "Style", "Coins", "Passes", "Specials" }
local TAB_TITLES: { [string]: string } = { Kits = "God Kits" }

local BADGE_COLORS: { [string]: { Color3 } } = {
	["Good Value"] = { C.BlueLight, C.Blue },
	["Great Value"] = { C.OrangeLight, C.Orange },
	["Most Value"] = { C.Pink, C.Purple },
	["Best Value"] = { C.Pink, C.Purple },
	["Starter Deal"] = { C.GreenLight, C.Green },
	["Legendary"] = { C.PurpleLight, C.Purple },
	["Next Round"] = { C.PinkLight, C.Pink },
	["Day 7 Streak"] = { C.OrangeLight, C.Orange },
	["Starter"] = { C.GreyLight, C.Grey },
}

local abilityIcons: { [string]: string } = {}
for _, def in Config.Disasters.Abilities do
	abilityIcons[def.Id] = def.Icon
end

---------------------------------------------------------------------------
-- card building (stud UI: square blocks with a darker depth edge, a light inner rim,
-- a studded face and a green sheen buy button)

-- shop layout: Theme.Shop, with Theme.ShopTouch overrides on phones
local S = table.clone(Theme.Shop)
if Components.isTouch() then
	for key, value in Theme.ShopTouch do
		(S :: any)[key] = value
	end
end
local hintLabel: TextLabel? = nil
local TAB_HINTS: { [string]: string } = {
	Gear = "Gear lasts one round · use it from your hotbar",
	Kits = "Every kit also gets Seismic Ping · equip one, then play God",
	Style = "God Skins hover over your hand for everyone to see",
	Coins = "Coins buy gear, God Kits and skins",
	Passes = "Bought once, active every round",
	Specials = "Panic saves fire automatically when they would save you",
}

type CardSpec = {
	Order: number,
	Top: Color3,
	Bottom: Color3,
	Icon: string,
	Title: string,
	Subtitle: string,
	Badge: string?,
	Button: string,
	ButtonColor: Color3?,
	ButtonLight: Color3?,
	Abilities: { string }?, -- God kits: the five disasters as a row of icons
	OnClick: () -> (),
}

-- a promo tag kept inside its card or hero (never over the frame above): `y` from the top,
-- anchored at its right edge `x`, tilted like a sticker on cards
local function ribbon(parent: GuiObject, text: string, colors: { Color3 }, width: number, x: UDim, y: number, tilt: number)
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(width, 22)
	badge.Position = UDim2.new(x.Scale, x.Offset, 0, y)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Rotation = tilt
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.ZIndex = 3
	Components.corner(badge, Theme.Radius.Small)
	Components.stroke(badge, Theme.Stroke.Thick)
	Components.gradient(badge, colors[1], colors[2], 90)
	Components.rim(badge, colors[2])
	badge.Parent = parent
	local label = Components.label({ Name = "Text", Text = string.upper(text), TextSize = 15, Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), Parent = badge })
	label.ZIndex = 4
	label.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 15
	fit.Parent = label
	return badge
end

local function card(parent: Instance, spec: CardSpec): (Frame, TextButton, TextLabel)
	local frame = Instance.new("Frame")
	frame.Name = spec.Title
	frame.LayoutOrder = spec.Order
	frame.Size = UDim2.fromOffset(S.CardWidth, if spec.Abilities then S.KitCardHeight else S.CardHeight)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(frame, Theme.Radius.Large)
	Components.stroke(frame, Theme.Stroke.Heavy)
	Components.gradient(frame, spec.Top, spec.Bottom)
	Components.studs(frame, nil, Theme.Radius.Large)
	Components.block(frame, spec.Bottom, Theme.Block.DepthCard)
	frame.Parent = parent

	if spec.Badge and spec.Badge ~= "" then
		local tag = ribbon(frame, spec.Badge, BADGE_COLORS[spec.Badge] or { C.GoldLight, C.Gold }, 86, UDim.new(1, -10), S.CardIconTop + 12, 8)
		tag.ZIndex = 5
	end
	-- fixed rhythm on every card: title, icon, text, (abilities), buy button
	Components.label({ Name = "Title", Text = spec.Title, TextSize = if #spec.Title > 13 then 16 else 19, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, S.CardPadTop), Parent = frame })
	Components.icon({ Name = "Icon", Icon = spec.Icon, TextSize = 48, Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, S.CardIconTop), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
	local sub = Components.label({ Name = "Subtitle", Text = spec.Subtitle, TextSize = 14, Size = UDim2.new(1, -14, 0, S.CardTextHeight), Position = UDim2.fromOffset(7, S.CardTextTop), StrokeThickness = Theme.Stroke.Thin, Parent = frame })
	sub.FontFace = Theme.FontFaceBold
	sub.TextWrapped = true
	if spec.Abilities then
		-- the kit's five disasters in a dark well
		local well = Instance.new("Frame")
		well.Name = "Abilities"
		well.Size = UDim2.new(1, -14, 0, 38)
		well.Position = UDim2.new(0.5, 0, 0, S.CardAbilityTop)
		well.AnchorPoint = Vector2.new(0.5, 0)
		well.BackgroundColor3 = C.Outline
		well.BackgroundTransparency = 0.7
		well.Parent = frame
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, 2)
		row.Parent = well
		for i, id in spec.Abilities do
			local icon = Components.icon({ Name = id, Icon = abilityIcons[id] or "?", TextSize = 18, Size = UDim2.fromOffset(S.AbilityIcon, S.AbilityIcon), Parent = well })
			icon.LayoutOrder = i
		end
	end
	local button = Components.button({
		Name = "Buy",
		Text = spec.Button,
		TextSize = 22,
		Size = UDim2.new(1, -16, 0, 42),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = spec.ButtonColor or C.Green,
		ColorLight = spec.ButtonLight or C.GreenLight,
		Sheen = true,
		Parent = frame,
		OnClick = spec.OnClick,
	})
	return frame, button, sub
end

type HeroSpec = {
	Name: string,
	Top: Color3,
	Bottom: Color3,
	Title: string,
	Bullets: { string },
	Icons: { string },
	Badge: string?,
	ListPrice: string?, -- struck-through "was" price beside the button
	Button: string,
	Height: number?,
	OnClick: () -> (),
}

-- Wide featured offer at the top of a tab (stud reference's BUNDLE card): yellow title,
-- two bullets, a sheen buy button, the item art on a translucent halo on the right.
local function hero(parent: GuiObject, spec: HeroSpec): (Frame, TextButton, { TextLabel })
	local h = spec.Height or S.HeroHeight
	local frame = Instance.new("Frame")
	frame.Name = "Hero" .. spec.Name
	frame.Size = UDim2.new(1, -S.EdgeInset * 2, 0, h)
	frame.Position = UDim2.new(0.5, 0, 0, S.PageTop)
	frame.ClipsDescendants = false
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(frame, Theme.Radius.Large)
	Components.stroke(frame, Theme.Stroke.Heavy)
	Components.gradient(frame, spec.Top, spec.Bottom)
	Components.studs(frame, nil, Theme.Radius.Large)
	Components.block(frame, spec.Bottom, Theme.Block.DepthCard)
	frame.Parent = parent
	-- translucent diagonal stripes and a halo square behind the art
	local art = Components.sheen(frame, S.HeroStripeTransparency)
	art.Name = "Stripes"
	for _, stripe in art:GetChildren() do
		if stripe:IsA("Frame") then
			stripe.Position = UDim2.fromScale((stripe.Position.X.Scale - 0.2), 0.5)
		end
	end
	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.Size = UDim2.fromOffset(h + 50, h - 24)
	halo.Position = UDim2.new(1, -14, 0.5, 0)
	halo.AnchorPoint = Vector2.new(1, 0.5)
	halo.BackgroundColor3 = Color3.new(1, 1, 1)
	halo.BackgroundTransparency = 0.78
	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = UDim.new(0, 18)
	haloCorner.Parent = halo
	Components.stroke(halo, 3, spec.Top)
	halo.Parent = frame
	local n = #spec.Icons
	for i, key in spec.Icons do
		local size = if n == 1 then h - 34 else h - 62
		local icon = Components.icon({
			Name = "Art" .. i,
			Icon = key,
			TextSize = 60,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.new(1, -14 - (h + 50) / 2 + (i - (n + 1) / 2) * (size * 0.62), 0.5, if n == 1 then 0 else (if i % 2 == 0 then -14 else 12)),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Parent = frame,
		})
		icon.ZIndex = 2
	end
	Components.label({ Name = "Title", Text = spec.Title, TextSize = S.HeroTitleSize, Color = S.HeroTitleColor, StrokeThickness = Theme.Stroke.Window, XAlign = Enum.TextXAlignment.Left, Size = UDim2.new(1, -240, 0, S.HeroTitleSize + 6), Position = UDim2.fromOffset(16, 6), Parent = frame })
	local bullets: { TextLabel } = {}
	-- only as many bullet lines as fit above the buy button
	local room = math.min(S.HeroBullets, math.floor((h - 10 - S.HeroButtonHeight - S.HeroBulletTop) / 20))
	for i, text in spec.Bullets do
		if i > room then
			break
		end
		local b = Components.label({ Name = "Bullet" .. i, Text = "•  " .. text, TextSize = 16, XAlign = Enum.TextXAlignment.Left, Size = UDim2.new(1, -240, 0, 20), Position = UDim2.fromOffset(18, S.HeroBulletTop + (i - 1) * 21), Parent = frame })
		b.FontFace = Theme.FontFaceBold
		table.insert(bullets, b)
	end
	local button = Components.button({
		Name = "Buy",
		Text = spec.Button,
		TextSize = 24,
		Size = UDim2.fromOffset(S.HeroButtonWidth, S.HeroButtonHeight),
		Position = UDim2.new(0, 16, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		Color = C.Green,
		ColorLight = C.GreenLight,
		Sheen = true,
		Parent = frame,
		OnClick = spec.OnClick,
	})
	if spec.ListPrice then
		local was = Components.label({ Name = "ListPrice", Text = spec.ListPrice, TextSize = 18, Color = C.RedLight, Size = UDim2.fromOffset(70, 24), Position = UDim2.new(0, 16 + S.HeroButtonWidth + 8, 1, -21), AnchorPoint = Vector2.new(0, 0.5), Parent = frame })
		local strike = Instance.new("Frame")
		strike.Size = UDim2.new(0.8, 0, 0, 3)
		strike.Position = UDim2.fromScale(0.1, 0.5)
		strike.BackgroundColor3 = C.Red
		strike.BorderSizePixel = 0
		strike.Rotation = -10
		strike.Parent = was
	end
	if spec.Badge and spec.Badge ~= "" then
		local tag = ribbon(frame, spec.Badge, BADGE_COLORS[spec.Badge] or { C.PinkLight, C.Pink }, 130, UDim.new(1, -12), 10, 0)
		tag.ZIndex = 5
	end
	return frame, button, bullets
end

-- Slim purple strip above a card row (God Kits loadout, Passes): icon, gold title,
-- and a right-aligned status line that callers update.
local function strip(parent: GuiObject, icon: string, title: string, statusText: string): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = "Strip"
	frame.Size = UDim2.new(1, -S.EdgeInset * 2, 0, S.StripHeight)
	frame.Position = UDim2.new(0.5, 0, 0, S.PageTop)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(frame, Theme.Radius.Large)
	Components.stroke(frame, Theme.Stroke.Heavy)
	Components.gradient(frame, C.PurpleLight:Lerp(C.Purple, 0.5), C.Purple:Lerp(C.Outline, 0.25))
	Components.studs(frame, nil, Theme.Radius.Large)
	Components.block(frame, C.Purple, Theme.Block.Depth)
	frame.Parent = parent
	Components.icon({ Name = "Icon", Icon = icon, TextSize = 30, Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = frame })
	Components.label({ Name = "Title", Text = title, TextSize = 26, Color = S.HeroTitleColor, XAlign = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(60, 0), Parent = frame })
	local status = Components.label({ Name = "Status", Text = statusText, TextSize = 17, XAlign = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.new(1, -14, 0, 0), AnchorPoint = Vector2.new(1, 0), Parent = frame })
	status.FontFace = Theme.FontFaceBold
	return status
end

-- A page of cards in a row under an optional hero; scrolls sideways (thumb-friendly)
-- when the cards don't fit.
local function grid(parent: GuiObject, name: string, top: number?): ScrollingFrame
	local y = S.PageTop + (top or 0)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.new(1, 0, 1, -y - S.FooterHeight)
	page.Position = UDim2.fromOffset(0, y)
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.X
	page.ScrollingDirection = Enum.ScrollingDirection.X
	page.ScrollBarThickness = 6
	page.ScrollBarImageColor3 = C.Gold
	page.VerticalScrollBarInset = Enum.ScrollBarInset.None
	page.Visible = false
	page.Parent = parent
	local pad = Instance.new("UIPadding")
	-- the scroller clips, so pad by the stroke inset (cards line up with the hero above)
	pad.PaddingLeft = UDim.new(0, S.EdgeInset)
	pad.PaddingRight = UDim.new(0, S.EdgeInset)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 12) -- the depth edge
	pad.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, S.CardGap)
	layout.Parent = page
	-- centred while the cards fit; left-aligned once they overflow so the first card can be scrolled to
	local function fit()
		layout.HorizontalAlignment = if layout.AbsoluteContentSize.X > page.AbsoluteWindowSize.X then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	page:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(fit)
	pages[name] = page
	return page
end

-- A tab page holding a hero / strip plus its card grid (switched as one by selectTab).
local function holder(content: Frame, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Visible = false
	frame.Parent = content
	pages[name] = frame
	return frame
end

local function strips(page: GuiObject, name: string, top: number): ScrollingFrame
	local g = grid(page, name .. "Cards", top)
	pages[name .. "Cards"] = nil -- shown with its holder
	g.Visible = true
	return g
end

local function selectTab(name: string)
	for tab, page in pages do
		page.Visible = tab == name
	end
	for tab, button in tabButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if tab == name then C.Gold else C.Outline
			stroke.Thickness = if tab == name then Theme.Stroke.Window else Theme.Stroke.Heavy
		end
	end
	if hintLabel then
		hintLabel.Text = TAB_HINTS[name] or ""
	end
end

local function setOwnedLook(button: TextButton, owned: boolean)
	if owned then
		Components.setColors(button, C.GreyLight, C.Grey, true)
	else
		Components.setColors(button, C.GreenLight, C.Green, true)
	end
end

---------------------------------------------------------------------------
-- pages

local function buildGearPage(content: Frame)
	local page = holder(content, "Gear")
	local kit = M.Products.SurvivalKit
	hero(page, {
		Name = "SurvivalKit",
		Top = C.BlueLight,
		Bottom = C.Blue,
		Title = "SURVIVAL KIT",
		Bullets = { "1x Speed Soda, Balloon Glider and Shield", "Instant: no coins needed" },
		Icons = { "SpeedSoda", "Glider", "Shield" },
		Button = Store.robux(kit.Price),
		OnClick = function()
			Store.promptProduct("SurvivalKit")
		end,
	})
	local cards = strips(page, "Gear", S.HeroHeight + S.HeroGap)
	for i, def in Config.Gear do
		local _, _, sub = card(cards, {
			Order = i,
			Top = C.BlueLight,
			Bottom = C.Blue,
			Icon = def.Icon,
			Title = def.DisplayName,
			Subtitle = def.Description,
			Button = "💰 " .. tostring(def.Price),
			OnClick = function()
				Remotes.get("BuyGear"):FireServer(def.Id)
			end,
		})
		local function refresh()
			local n = player:GetAttribute(Attributes.GearPrefix .. def.Id) :: number? or 0
			sub.Text = string.format("%s · %ds\nOwned x%d", def.Description, def.Duration, n)
		end
		player:GetAttributeChangedSignal(Attributes.GearPrefix .. def.Id):Connect(refresh)
		refresh()
	end
end

-- God loadouts: buy with coins, then equip. The equipped kit is your hotbar as God.
local function buildKitsPage(content: Frame)
	local page = holder(content, "Kits")
	local status = strip(page, "PlayGod", "YOUR GOD LOADOUT", "")
	local function refreshStatus()
		local id = player:GetAttribute(Attributes.Kit)
		local name = "The Architect"
		for _, kit in Config.Kits do
			if kit.Id == id then
				name = kit.Name
			end
		end
		status.Text = "Equipped: " .. name
	end
	player:GetAttributeChangedSignal(Attributes.Kit):Connect(refreshStatus)
	refreshStatus()
	local cards = strips(page, "Kits", S.StripHeight + S.HeroGap)
	for i, kit in Config.Kits do
		local _, button = card(cards, {
			Order = i,
			Top = kit.Color:Lerp(Color3.new(1, 1, 1), 0.45),
			Bottom = kit.Color,
			Icon = kit.Icon,
			Title = kit.Name,
			Subtitle = kit.Description,
			Abilities = kit.Abilities,
			Button = "",
			OnClick = function()
				local owned = player:GetAttribute(Attributes.KitPrefix .. kit.Id) == true
				if not owned then
					Remotes.get("KitAction"):FireServer("Buy", kit.Id)
				elseif player:GetAttribute(Attributes.Kit) ~= kit.Id then
					Remotes.get("KitAction"):FireServer("Equip", kit.Id)
				end
			end,
		})
		local function refresh()
			local owned = player:GetAttribute(Attributes.KitPrefix .. kit.Id) == true
			local equipped = player:GetAttribute(Attributes.Kit) == kit.Id
			Components.setText(button, if equipped then "EQUIPPED ✔" elseif owned then "EQUIP" else "💰 " .. HUDController.FormatNumber(kit.Price))
			if equipped then
				Components.setColors(button, C.GreyLight, C.Grey, true)
			elseif owned then
				Components.setColors(button, C.BlueLight, C.Blue, true)
			else
				Components.setColors(button, C.GreenLight, C.Green, true)
			end
		end
		player:GetAttributeChangedSignal(Attributes.KitPrefix .. kit.Id):Connect(refresh)
		player:GetAttributeChangedSignal(Attributes.Kit):Connect(refresh)
		refresh()
	end
end

-- Style: God skins, disaster FX and finishers. A category row switches the card strip.
local styleCategory = "GodSkin"
local styleStrips: { [string]: ScrollingFrame } = {}
local styleButtons: { [string]: TextButton } = {}
local STYLE_TABS = {
	{ Id = "GodSkin", Title = "God Skins", Icon = "PlayGod" },
	{ Id = "Vfx", Title = "Disaster FX", Icon = "⚡" },
	{ Id = "Finisher", Title = "Finishers", Icon = "🎉" },
}

local function showStyle(category: string)
	styleCategory = category
	for id, cards in styleStrips do
		cards.Visible = id == category
	end
	for id, button in styleButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if id == category then C.Gold else C.Outline
		end
	end
end

-- Buy / equip a cosmetic (cards and the Style hero share this).
local function cosmeticClick(def: any)
	local owned = player:GetAttribute(Attributes.CosmeticPrefix .. def.Id) == true
	if owned then
		Remotes.get("CosmeticAction"):FireServer("Equip", def.Id)
	elseif def.Exclusive then
		HUDController.Popup("REACH DAY 7 OF YOUR LOGIN STREAK", C.GoldLight)
	elseif def.Coins then
		Remotes.get("CosmeticAction"):FireServer("Buy", def.Id)
	elseif def.Product and not Store.promptProduct(def.Product) then
		HUDController.Popup("COMING SOON", C.GoldLight)
	end
end

local function cosmeticButton(button: TextButton, def: any)
	local product = if def.Product then M.Products[def.Product] else nil
	local equipAttr = Attributes.EquipPrefix .. def.Category
	local function refresh()
		local owned = player:GetAttribute(Attributes.CosmeticPrefix .. def.Id) == true
		local equipped = player:GetAttribute(equipAttr) == def.Id
		if equipped then
			Components.setText(button, "EQUIPPED ✔")
			Components.setColors(button, C.GreyLight, C.Grey, true)
		elseif owned then
			Components.setText(button, "EQUIP")
			Components.setColors(button, C.BlueLight, C.Blue, true)
		elseif def.Exclusive then
			Components.setText(button, "🔒 DAY 7")
			Components.setColors(button, C.GreyLight, C.Grey, true)
		elseif def.Coins then
			Components.setText(button, "💰 " .. HUDController.FormatNumber(def.Coins))
			Components.setColors(button, C.GreenLight, C.Green, true)
		elseif product then
			Components.setText(button, if product.Id == 0 then "SOON" else Store.robux(product.Price))
			Components.setColors(button, C.GreenLight, C.Green, true)
		end
	end
	player:GetAttributeChangedSignal(Attributes.CosmeticPrefix .. def.Id):Connect(refresh)
	player:GetAttributeChangedSignal(equipAttr):Connect(refresh)
	refresh()
end

local function buildStylePage(content: Frame)
	local page = holder(content, "Style")
	local row = Instance.new("Frame")
	row.Name = "Categories"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, S.CategoryHeight)
	row.Position = UDim2.fromOffset(0, S.PageTop)
	row.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row
	-- the featured skin sits under the category row
	local featured: any = nil
	for _, def in Config.Cosmetics.Items do
		if def.Id == S.FeaturedSkin then
			featured = def
		end
	end
	local heroTop = S.CategoryHeight + S.HeroGap
	if S.StyleHeroHeight <= 0 then
		featured = nil -- phones: no room for the banner
	end
	if featured then
		local product = if featured.Product then M.Products[featured.Product] else nil
		local frame, button = hero(page, {
			Name = "Featured",
			Top = C.GoldLight,
			Bottom = C.Orange,
			Title = string.upper(featured.Name),
			Bullets = { "Legendary God Skin: hovers over the arena", featured.Description },
			Icons = { featured.Icon },
			Badge = if product and product.Badge ~= "" then product.Badge else nil,
			Button = "",
			Height = S.StyleHeroHeight,
			OnClick = function()
				cosmeticClick(featured)
			end,
		})
		frame.Position = UDim2.new(0.5, 0, 0, S.PageTop + heroTop)
		cosmeticButton(button, featured)
	end
	local cardTop = heroTop + (if featured then S.StyleHeroHeight + S.HeroGap else 0)
	for i, tab in STYLE_TABS do
		local b = Components.button({
			Name = tab.Id,
			Text = tab.Title,
			TextSize = 17,
			Size = UDim2.fromOffset(170, S.CategoryHeight - 4),
			Color = C.Pink,
			ColorLight = C.PinkLight,
			Parent = row,
			OnClick = function()
				showStyle(tab.Id)
			end,
		})
		b.LayoutOrder = i
		local label = b:FindFirstChild("Text") :: TextLabel?
		if label then
			label.Position = UDim2.fromOffset(14, 0)
		end
		Components.icon({ Name = "Icon", Icon = tab.Icon, TextSize = 18, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 8, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2, Parent = b })
		styleButtons[tab.Id] = b
		local cards = grid(page, tab.Id, cardTop)
		pages[tab.Id] = nil -- strips are switched by showStyle, not selectTab
		styleStrips[tab.Id] = cards
	end
	local order: { [string]: number } = {}
	for _, def in Config.Cosmetics.Items do
		order[def.Category] = (order[def.Category] or 0) + 1
		local product = if def.Product then M.Products[def.Product] else nil
		local _, button = card(styleStrips[def.Category], {
			Order = order[def.Category],
			Top = def.Color:Lerp(Color3.new(1, 1, 1), 0.45),
			Bottom = def.Color:Lerp(Color3.new(0, 0, 0), 0.25),
			Icon = def.Icon,
			Title = def.Name,
			Subtitle = def.Description,
			Badge = if def.Exclusive then "Day 7 Streak" elseif product and product.Badge ~= "" then product.Badge elseif def.Coins == nil and def.Product == nil then "Starter" else nil,
			Button = "",
			OnClick = function()
				cosmeticClick(def)
			end,
		})
		cosmeticButton(button, def)
	end
	showStyle(styleCategory)
end

local function buildCoinsPage(content: Frame)
	local page = holder(content, "Coins")
	local vault = M.Products.CoinsHuge
	hero(page, {
		Name = "Vault",
		Top = C.GoldLight,
		Bottom = C.Gold:Lerp(C.Orange, 0.35),
		Title = string.upper(vault.Name),
		Bullets = { "+" .. HUDController.FormatNumber(vault.Coins or 0) .. " coins", "Enough for any God Kit, twice over" },
		Icons = { vault.Icon, "🪙" },
		Badge = vault.Badge,
		Button = Store.robux(vault.Price),
		OnClick = function()
			Store.promptProduct("CoinsHuge")
		end,
	})
	local cards = strips(page, "Coins", S.HeroHeight + S.HeroGap)
	for i, key in { "CoinsSmall", "CoinsMedium", "CoinsLarge" } do
		local def = M.Products[key]
		card(cards, {
			Order = i,
			Top = C.GoldLight,
			Bottom = C.Gold:Lerp(C.Orange, 0.35),
			Icon = def.Icon,
			Title = def.Name,
			Subtitle = "+" .. HUDController.FormatNumber(def.Coins or 0) .. " coins",
			Badge = def.Badge,
			Button = Store.robux(def.Price),
			OnClick = function()
				Store.promptProduct(key)
			end,
		})
	end
end

local function buildPassesPage(content: Frame)
	local page = holder(content, "Passes")
	strip(page, "🏅", "GAME PASSES", "Own them forever")
	local cards = strips(page, "Passes", S.StripHeight + S.HeroGap)
	for i, key in { "DoubleCoins", "VIP", "GodPriority", "QuickDash" } do
		local def = M.Passes[key]
		local _, button = card(cards, {
			Order = i,
			Top = C.PurpleLight,
			Bottom = C.Purple,
			Icon = def.Icon,
			Title = def.Name,
			Subtitle = def.Description,
			Button = Store.robux(def.Price),
			OnClick = function()
				if not Store.ownsPass(key) then
					Store.promptPass(key)
				end
			end,
		})
		local function refresh()
			local owned = Store.ownsPass(key)
			Components.setText(button, if owned then "OWNED ✔" else Store.robux(def.Price))
			setOwnedLook(button, owned)
		end
		player:GetAttributeChangedSignal(Attributes.PassPrefix .. key):Connect(refresh)
		refresh()
	end
end

local function buildSpecialsPage(content: Frame)
	local page = holder(content, "Specials")
	local god = M.Products.GodNextRound
	local _, godButton, bullets = hero(page, {
		Name = "BeTheGod",
		Top = C.PurpleLight,
		Bottom = C.Purple,
		Title = "BE THE GOD",
		Bullets = { "Guaranteed God next round", "" },
		Icons = { god.Icon, "⭐" },
		Badge = "Next Round",
		Button = Store.robux(god.Price),
		OnClick = function()
			if player:GetAttribute(Attributes.GodQueued) ~= true then
				Store.promptProduct("GodNextRound")
			end
		end,
	})
	local function refreshGod()
		local queued = player:GetAttribute(Attributes.GodQueued) == true
		Components.setText(godButton, if queued then "QUEUED ✔" else Store.robux(god.Price))
		setOwnedLook(godButton, queued)
		local chance = player:GetAttribute(Attributes.GodChance) :: number? or 0
		local line = bullets[2]
		if line then
			line.Text = string.format("•  Your God Chance: %s%%", if chance % 1 == 0 then tostring(math.floor(chance)) else string.format("%.1f", chance))
		end
	end
	player:GetAttributeChangedSignal(Attributes.GodQueued):Connect(refreshGod)
	player:GetAttributeChangedSignal(Attributes.GodChance):Connect(refreshGod)
	refreshGod()

	local cards = strips(page, "Specials", S.HeroHeight + S.HeroGap)
	local welcome = M.Products.WelcomePack
	local _, welcomeButton = card(cards, {
		Order = 1,
		Top = C.OrangeLight,
		Bottom = C.Orange,
		Icon = welcome.Icon,
		Title = welcome.Name,
		Subtitle = "+" .. HUDController.FormatNumber(welcome.Coins or 0) .. " coins + Survival Kit",
		Badge = welcome.Badge,
		Button = Store.robux(welcome.Price),
		OnClick = function()
			if player:GetAttribute(Attributes.WelcomeClaimed) ~= true then
				Store.promptProduct("WelcomePack")
			end
		end,
	})
	local function refreshWelcome()
		local claimed = player:GetAttribute(Attributes.WelcomeClaimed) == true
		Components.setText(welcomeButton, if claimed then "CLAIMED ✔" else Store.robux(welcome.Price))
		setOwnedLook(welcomeButton, claimed)
	end
	player:GetAttributeChangedSignal(Attributes.WelcomeClaimed):Connect(refreshWelcome)
	refreshWelcome()

	local revive = M.Products.Revive
	card(cards, {
		Order = 2,
		Top = C.PinkLight,
		Bottom = C.Pink,
		Icon = revive.Icon,
		Title = revive.Name,
		Subtitle = "Revive while eliminated",
		Button = Store.robux(revive.Price),
		OnClick = function()
			local eliminated = player:GetAttribute(Attributes.Role) == "Survivor" and player:GetAttribute(Attributes.Alive) ~= true
			if eliminated and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active" then
				Store.promptProduct("Revive")
			else
				HUDController.Popup("ONLY WHILE ELIMINATED", C.RedLight)
			end
		end,
	})

	-- panic saves: charges that fire automatically
	for i, key in { "SaveGlider", "SaveAegis" } do
		local def = M.Products[key]
		local kind = def.Save or ""
		local _, button, sub = card(cards, {
			Order = 2 + i,
			Top = if kind == "Glider" then C.BlueLight else C.GoldLight,
			Bottom = if kind == "Glider" then C.Blue else C.Gold,
			Icon = def.Icon,
			Title = def.Name,
			Subtitle = "",
			Button = "",
			OnClick = function()
				if not Store.promptProduct(key) then
					HUDController.Popup("COMING SOON", C.GoldLight)
				end
			end,
		})
		local function refresh()
			local n = player:GetAttribute(Attributes.SavePrefix .. kind) :: number? or 0
			sub.Text = string.format("%s\nYou have x%d", if kind == "Glider" then "Catches a fatal fall" else "Blocks one fatal hit", n)
			Components.setText(button, if def.Id == 0 then "SOON" else Store.robux(def.Price))
		end
		player:GetAttributeChangedSignal(Attributes.SavePrefix .. kind):Connect(refresh)
		refresh()
	end
end

local function buildShop()
	shop = Components.window(layer, "Shop!", UDim2.fromOffset(S.Width, S.Height), { Dim = true, Inset = S.Inset })
	local content = shop.Content

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, -S.EdgeInset * 2, 0, S.TabHeight)
	tabs.Position = UDim2.fromOffset(S.EdgeInset, 0)
	tabs.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = tabs
	-- category colours: survivor gear blue, God purple, style pink, coins gold, passes
	-- deep purple, specials orange
	local tabStyle = {
		Gear = { C.BlueLight, C.Blue, "SpeedSoda" },
		Kits = { C.PurpleLight, C.Purple, "PlayGod" },
		Style = { C.PinkLight, C.Pink, "⭐" },
		Coins = { C.GoldLight, C.Gold:Lerp(C.Orange, 0.35), "Coin" },
		Passes = { C.PurpleLight:Lerp(C.Purple, 0.6), C.Purple:Lerp(C.Outline, 0.3), "Passes" },
		Specials = { C.OrangeLight, C.Orange, "🎁" },
	}
	for i, name in TAB_ORDER do
		local style = tabStyle[name]
		local b = Components.button({
			Name = name,
			Text = TAB_TITLES[name] or name,
			TextSize = 18,
			Size = UDim2.fromOffset(S.TabWidth, S.TabHeight - 6),
			Color = style[2],
			ColorLight = style[1],
			Parent = tabs,
			OnClick = function()
				selectTab(name)
				Analytics.track("ItemPreviewed", name)
			end,
		})
		b.LayoutOrder = i
		local label = b:FindFirstChild("Text") :: TextLabel?
		if label then
			label.Position = UDim2.fromOffset(15, 0)
		end
		Components.icon({ Name = "Icon", Icon = style[3], TextSize = 20, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0, 6, 0.5, -2), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2, Parent = b })
		tabButtons[name] = b
	end

	buildGearPage(content)
	buildKitsPage(content)
	buildStylePage(content)
	buildCoinsPage(content)
	buildPassesPage(content)
	buildSpecialsPage(content)

	-- wallet (left) and a per-tab hint (right) along the bottom
	Components.icon({ Name = "WalletCoin", Icon = "Coin", TextSize = 24, Size = UDim2.fromOffset(32, 32), Position = UDim2.new(0, S.EdgeInset, 1, -2), AnchorPoint = Vector2.new(0, 1), Parent = content })
	local wallet = Components.label({
		Name = "Wallet",
		Text = "",
		TextSize = 24,
		Color = C.Gold,
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.new(0, S.EdgeInset + 38, 1, -3),
		AnchorPoint = Vector2.new(0, 1),
		XAlign = Enum.TextXAlignment.Left,
		Parent = content,
	})
	hintLabel = Components.label({
		Name = "Hint",
		Text = "",
		TextSize = 14,
		Size = UDim2.new(1, -260, 0, 26),
		Position = UDim2.new(1, -S.EdgeInset, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		XAlign = Enum.TextXAlignment.Right,
		StrokeThickness = Theme.Stroke.Thin,
		Parent = content,
	})
	local function refreshWallet()
		wallet.Text = HUDController.FormatNumber(player:GetAttribute(Attributes.Coins) :: number? or 0)
	end
	player:GetAttributeChangedSignal(Attributes.Coins):Connect(refreshWallet)
	refreshWallet()
	selectTab("Gear")
end

function MenuController.IsShopOpen(): boolean
	return shop ~= nil and shop.IsOpen()
end

-- Open the shop (optionally on a tab). Without a tab it toggles.
function MenuController.OpenShop(tab: string?)
	if tab then
		selectTab(tab)
	end
	if shop.IsOpen() and not tab then
		shop.Close()
	else
		if not shop.IsOpen() then
			Analytics.track("ShopOpened", tab or "Shop")
		end
		shop.Open()
	end
end

function MenuController.Start()
	if started then
		return
	end
	started = true
	gui = Instance.new("ScreenGui")
	gui.Name = "Menu"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 7 -- the shop opens above the map vote
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	-- two-column tile grid on the left, vertically centred (phones sit it a little
	-- higher so it ends above the thumbstick zone)
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundTransparency = 1
	local cell, gapX, gapY = Theme.Layout.SidebarCell, Theme.Layout.SidebarGapX, Theme.Layout.SidebarGapY
	sidebar.Size = UDim2.fromOffset(cell * 2 + gapX, cell * 3 + gapY * 2)
	sidebar.AnchorPoint = Vector2.new(0, 0.5)
	sidebar.Position = if Components.isTouch() then UDim2.new(0, 12, 0.5, -36) else UDim2.new(0, 16, 0.5, -20)
	sidebar.Parent = layer
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cell, cell)
	layout.CellPadding = UDim2.fromOffset(gapX, gapY)
	layout.FillDirectionMaxCells = 2
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sidebar

	buildShop()

	local shopTile = Components.tile(sidebar, "Shop", "Shop", C.Red, 1)
	shopTile.Activated:Connect(function()
		MenuController.OpenShop()
	end)

	local spinTile = Components.tile(sidebar, "Spin", "Spin", C.Pink, 2)
	spinTile.Activated:Connect(SpinController.Toggle)
	local function refreshSpinBadge()
		local n = player:GetAttribute(Attributes.Spins) :: number? or 0
		Components.setBadge(spinTile, if n > 0 then tostring(n) else nil)
	end
	player:GetAttributeChangedSignal(Attributes.Spins):Connect(refreshSpinBadge)
	refreshSpinBadge()

	local questTile = Components.tile(sidebar, "Quests", "Quests", C.Orange, 3)
	questTile.Activated:Connect(QuestController.Toggle)
	-- the quest tile carries the day's progress ("1/3"), or "!" when one can be claimed
	local function refreshQuestBadge()
		local done, total, claimable = QuestController.Progress()
		Components.setBadge(questTile, if claimable > 0 then "!" elseif total > 0 then string.format("%d/%d", done, total) else nil)
	end
	QuestController.Changed:Connect(refreshQuestBadge)
	refreshQuestBadge()

	local passTile = Components.tile(sidebar, "Passes", "Passes", C.Gold, 4)
	passTile.Activated:Connect(function()
		MenuController.OpenShop("Passes")
	end)

	SpectateController.SetShopOpener(MenuController.OpenShop)
	HUDController.SetShopOpener(MenuController.OpenShop)
	local spectateTile = Components.tile(sidebar, "Spectate", "Spectate", C.Blue, 5)
	spectateTile.Activated:Connect(SpectateController.Toggle)

	-- sixth tile: alone in a server it toggles your role; with others it opens the
	-- Be the God offer, so the grid is always a full 2 x 3
	local roleTile = Components.tile(sidebar, "PlayGod", "Play God", C.Purple, 6)
	local function refreshRoleTile()
		local solo = #Players:GetPlayers() == 1 and Config.Match.AllowSoloRoleToggle
		local wantsGod = solo and player:GetAttribute(Attributes.PreferredRole) == "DisasterGod"
		local icon = roleTile:FindFirstChild("Icon")
		local caption = roleTile:FindFirstChild("Caption") :: TextLabel?
		if icon and caption then
			Components.setIcon(icon, if wantsGod then "Dash" else "PlayGod")
			caption.Text = if wantsGod then "Survivor" else "Play God"
		end
	end
	-- Settings lives on a gear button beside the coin bar (HUDController)
	HUDController.SetSettingsOpener(SettingsController.Toggle)

	roleTile.Activated:Connect(function()
		if not (#Players:GetPlayers() == 1 and Config.Match.AllowSoloRoleToggle) then
			MenuController.OpenShop("Specials")
			return
		end
		local wantsGod = player:GetAttribute(Attributes.PreferredRole) == "DisasterGod"
		Remotes.get("SetSoloRole"):FireServer(if wantsGod then "Survivor" else "DisasterGod")
	end)
	player:GetAttributeChangedSignal(Attributes.PreferredRole):Connect(refreshRoleTile)
	Players.PlayerAdded:Connect(refreshRoleTile)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshRoleTile)
	end)
	refreshRoleTile()

	-- hide the menu while flying the God camera (the solo tester keeps the role toggle)
	local function refreshSidebar()
		local flying = player:GetAttribute(Attributes.Role) == "DisasterGod" and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active"
		local solo = Config.Match.AllowSoloRoleToggle and #Players:GetPlayers() == 1
		sidebar.Visible = not flying or solo
		for _, tile in { shopTile, spinTile, questTile, passTile, spectateTile } do
			tile.Visible = not flying
		end
		roleTile.Visible = not flying or solo
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshSidebar)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshSidebar)
	-- a round starting drops you into the arena: lobby windows close so nothing covers the
	-- screen when the disasters begin (a spin in progress is left to finish)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(function()
		local role = player:GetAttribute(Attributes.Role)
		if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" or (role ~= "Survivor" and role ~= "DisasterGod") then
			return
		end
		if shop.IsOpen() then
			shop.Close()
		end
		QuestController.Close()
		if not SpinController.IsSpinning() then
			SpinController.Close()
		end
	end)
	refreshSidebar()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			MenuController.OpenShop()
		elseif prompt.Name == "QuestPrompt" then
			QuestController.Toggle()
		elseif prompt.Name == "SpinPrompt" then
			SpinController.Open()
		elseif prompt.Name == "CosmeticPrompt" then
			MenuController.OpenShop("Style")
		elseif prompt.Name == "PassPrompt" then
			local key = prompt:GetAttribute("PassKey")
			if typeof(key) == "string" then
				if Store.ownsPass(key) then
					HUDController.Popup("YOU ALREADY OWN THIS PASS", C.GreenLight)
				else
					Store.promptPass(key)
				end
			end
		end
	end)
end

return MenuController
