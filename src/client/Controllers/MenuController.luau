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
	["Starter Deal"] = { C.GreenLight, C.Green },
}

local abilityIcons: { [string]: string } = {}
for _, def in Config.Disasters.Abilities do
	abilityIcons[def.Id] = def.Icon
end

---------------------------------------------------------------------------
-- card building

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
	OnClick: () -> (),
}

local function card(parent: Instance, spec: CardSpec): (Frame, TextButton, TextLabel)
	local frame = Instance.new("Frame")
	frame.Name = spec.Title
	frame.LayoutOrder = spec.Order
	frame.Size = UDim2.fromOffset(170, 270)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(frame, Theme.Radius.Large)
	Components.stroke(frame, Theme.Stroke.Heavy)
	Components.gradient(frame, spec.Top, spec.Bottom)
	Components.studs(frame, nil, Theme.Radius.Large)
	frame.Parent = parent

	if spec.Badge and spec.Badge ~= "" then
		local colors = BADGE_COLORS[spec.Badge] or { C.BlueLight, C.Blue }
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.new(1, -16, 0, 28)
		badge.Position = UDim2.new(0.5, 0, 0, 8)
		badge.AnchorPoint = Vector2.new(0.5, 0)
		badge.BackgroundColor3 = Color3.new(1, 1, 1)
		Components.corner(badge, Theme.Radius.Small)
		Components.stroke(badge, Theme.Stroke.Thick)
		Components.gradient(badge, colors[1], colors[2], 0)
		badge.Parent = frame
		Components.label({ Name = "Text", Text = spec.Badge, TextSize = 18, Size = UDim2.fromScale(1, 1), Parent = badge })
	end
	Components.icon({ Name = "Icon", Icon = spec.Icon, TextSize = 52, Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, 0, 0, 38), AnchorPoint = Vector2.new(0.5, 0), Parent = frame })
	Components.label({ Name = "Title", Text = spec.Title, TextSize = 20, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 112), Parent = frame })
	local pill = Components.panel({
		Name = "Info",
		Size = UDim2.new(1, -20, 0, 48),
		Position = UDim2.new(0.5, 0, 0, 142),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.fromRGB(20, 26, 36),
		Transparency = 0.35,
		Radius = Theme.Radius.Medium,
		Parent = frame,
	})
	local sub = Components.label({ Name = "Text", Text = spec.Subtitle, TextSize = 16, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), Parent = pill })
	sub.TextWrapped = true
	local button = Components.button({
		Name = "Buy",
		Text = spec.Button,
		TextSize = 24,
		Size = UDim2.new(1, -20, 0, 52),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = spec.ButtonColor or C.Green,
		ColorLight = spec.ButtonLight or C.GreenLight,
		Parent = frame,
		OnClick = spec.OnClick,
	})
	return frame, button, sub
end

-- A page of cards in a row; scrolls sideways (thumb-friendly) when they don't fit.
local function grid(parent: GuiObject, name: string, top: number?): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.new(1, 0, 1, -92 - (top or 0))
	page.Position = UDim2.fromOffset(0, 56 + (top or 0))
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.X
	page.ScrollingDirection = Enum.ScrollingDirection.X
	page.ScrollBarThickness = 6
	page.ScrollBarImageColor3 = C.Gold
	page.VerticalScrollBarInset = Enum.ScrollBarInset.None
	page.Visible = false
	page.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
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

local function selectTab(name: string)
	for tab, page in pages do
		page.Visible = tab == name
	end
	for tab, button in tabButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if tab == name then C.Gold else C.Outline
		end
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
	local page = grid(content, "Gear")
	for i, def in Config.Gear do
		local _, _, sub = card(page, {
			Order = i,
			Top = def.Color:Lerp(Color3.new(1, 1, 1), 0.4),
			Bottom = def.Color,
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
			local use = if Components.isTouch() then "tap it on your hotbar" else "Key " .. def.Key
			sub.Text = string.format("%s\nOwned x%d · %s", def.Description, n, use)
		end
		player:GetAttributeChangedSignal(Attributes.GearPrefix .. def.Id):Connect(refresh)
		refresh()
	end
end

-- God loadouts: buy with coins, then equip. The equipped kit is your hotbar as God.
local function buildKitsPage(content: Frame)
	local page = grid(content, "Kits")
	for i, kit in Config.Kits do
		local list = {}
		for _, id in kit.Abilities do
			table.insert(list, abilityIcons[id] or "?")
		end
		local _, button = card(page, {
			Order = i,
			Top = kit.Color:Lerp(Color3.new(1, 1, 1), 0.45),
			Bottom = kit.Color,
			Icon = kit.Icon,
			Title = kit.Name,
			Subtitle = table.concat(list, " ") .. "\n" .. kit.Description,
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
	{ Id = "GodSkin", Title = "🖐️ God Skins" },
	{ Id = "Vfx", Title = "⚡ Disaster FX" },
	{ Id = "Finisher", Title = "💥 Finishers" },
}

local function showStyle(category: string)
	styleCategory = category
	local visible = pages.Style ~= nil and pages.Style.Visible
	for id, strip in styleStrips do
		strip.Visible = visible and id == category
	end
	for id, button in styleButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if id == category then C.Gold else C.Outline
		end
	end
end

local function buildStylePage(content: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Style"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Visible = false
	holder.Parent = content
	pages.Style = holder
	local row = Instance.new("Frame")
	row.Name = "Categories"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Position = UDim2.fromOffset(0, 52)
	row.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row
	for i, tab in STYLE_TABS do
		local b = Components.button({
			Name = tab.Id,
			Text = tab.Title,
			TextSize = 17,
			Size = UDim2.fromOffset(170, 32),
			Color = C.Purple,
			ColorLight = C.PurpleLight,
			Parent = row,
			OnClick = function()
				showStyle(tab.Id)
			end,
		})
		b.LayoutOrder = i
		styleButtons[tab.Id] = b
		local strip = grid(holder, tab.Id, 40)
		pages[tab.Id] = nil -- strips are switched by showStyle, not selectTab
		styleStrips[tab.Id] = strip
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
			Badge = if product and product.Badge ~= "" then product.Badge elseif def.Coins == nil and def.Product == nil then "Starter" else nil,
			Button = "",
			OnClick = function()
				local owned = player:GetAttribute(Attributes.CosmeticPrefix .. def.Id) == true
				if owned then
					Remotes.get("CosmeticAction"):FireServer("Equip", def.Id)
				elseif def.Coins then
					Remotes.get("CosmeticAction"):FireServer("Buy", def.Id)
				elseif def.Product and not Store.promptProduct(def.Product) then
					HUDController.Popup("COMING SOON", C.GoldLight)
				end
			end,
		})
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
			elseif def.Coins then
				Components.setText(button, "💰 " .. HUDController.FormatNumber(def.Coins))
				Components.setColors(button, C.GreenLight, C.Green, true)
			elseif product then
				Components.setText(button, if product.Id == 0 then "SOON" else Store.robux(product.Price))
				Components.setColors(button, C.PinkLight, C.Pink, true)
			end
		end
		player:GetAttributeChangedSignal(Attributes.CosmeticPrefix .. def.Id):Connect(refresh)
		player:GetAttributeChangedSignal(equipAttr):Connect(refresh)
		refresh()
	end
	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		showStyle(styleCategory)
	end)
end

local function buildCoinsPage(content: Frame)
	local page = grid(content, "Coins")
	for i, key in { "CoinsSmall", "CoinsMedium", "CoinsLarge", "CoinsHuge" } do
		local def = M.Products[key]
		card(page, {
			Order = i,
			Top = C.GreenLight,
			Bottom = C.Green,
			Icon = def.Icon,
			Title = def.Name,
			Subtitle = "+" .. HUDController.FormatNumber(def.Coins or 0) .. " coins",
			Badge = def.Badge,
			Button = Store.robux(def.Price),
			ButtonColor = C.Blue,
			ButtonLight = C.BlueLight,
			OnClick = function()
				Store.promptProduct(key)
			end,
		})
	end
end

local function buildPassesPage(content: Frame)
	local page = grid(content, "Passes")
	for i, key in { "DoubleCoins", "VIP", "GodPriority", "QuickDash" } do
		local def = M.Passes[key]
		local _, button = card(page, {
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
	local page = grid(content, "Specials")
	local god = M.Products.GodNextRound
	local _, godButton = card(page, {
		Order = 1,
		Top = C.Pink,
		Bottom = C.Purple,
		Icon = god.Icon,
		Title = "Be the God",
		Subtitle = "Guaranteed God next round",
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
	end
	player:GetAttributeChangedSignal(Attributes.GodQueued):Connect(refreshGod)
	refreshGod()

	local kit = M.Products.SurvivalKit
	card(page, {
		Order = 2,
		Top = C.BlueLight,
		Bottom = C.Blue,
		Icon = kit.Icon,
		Title = kit.Name,
		Subtitle = "1x Soda, Glider and Shield",
		Button = Store.robux(kit.Price),
		OnClick = function()
			Store.promptProduct("SurvivalKit")
		end,
	})

	local welcome = M.Products.WelcomePack
	local _, welcomeButton = card(page, {
		Order = 3,
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

	-- panic saves: charges that fire automatically
	for i, key in { "SaveGlider", "SaveAegis" } do
		local def = M.Products[key]
		local kind = def.Save or ""
		local _, button, sub = card(page, {
			Order = 4 + i,
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
			sub.Text = string.format("%s\nAuto-fires · you have x%d", if kind == "Glider" then "Catches a fatal fall" else "Blocks one fatal hit", n)
			Components.setText(button, if def.Id == 0 then "SOON" else Store.robux(def.Price))
		end
		player:GetAttributeChangedSignal(Attributes.SavePrefix .. kind):Connect(refresh)
		refresh()
	end

	local revive = M.Products.Revive
	card(page, {
		Order = 4,
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
end

local function buildShop()
	shop = Components.window(layer, "Shop", UDim2.fromOffset(780, 470))
	local content = shop.Content

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, 46)
	tabs.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = tabs
	local tabColors = {
		Gear = { C.BlueLight, C.Blue },
		Kits = { C.PinkLight, C.Pink },
		Style = { C.PurpleLight, C.Purple },
		Coins = { C.GreenLight, C.Green },
		Passes = { C.PurpleLight, C.Purple },
		Specials = { C.OrangeLight, C.Orange },
	}
	for i, name in TAB_ORDER do
		local b = Components.button({
			Name = name,
			Text = TAB_TITLES[name] or name,
			TextSize = 19,
			Size = UDim2.fromOffset(116, 42),
			Color = tabColors[name][2],
			ColorLight = tabColors[name][1],
			Parent = tabs,
			OnClick = function()
				selectTab(name)
			end,
		})
		b.LayoutOrder = i
		tabButtons[name] = b
	end

	buildGearPage(content)
	buildKitsPage(content)
	buildStylePage(content)
	buildCoinsPage(content)
	buildPassesPage(content)
	buildSpecialsPage(content)

	local wallet = Components.label({
		Name = "Wallet",
		Text = "",
		TextSize = 22,
		Color = C.Gold,
		Size = UDim2.fromOffset(220, 26),
		Position = UDim2.new(1, -4, 1, -2),
		AnchorPoint = Vector2.new(1, 1),
		XAlign = Enum.TextXAlignment.Right,
		Parent = content,
	})
	local function refreshWallet()
		wallet.Text = "💰 " .. HUDController.FormatNumber(player:GetAttribute(Attributes.Coins) :: number? or 0)
	end
	player:GetAttributeChangedSignal(Attributes.Coins):Connect(refreshWallet)
	refreshWallet()
	selectTab("Gear")
end

-- Open the shop (optionally on a tab). Without a tab it toggles.
function MenuController.OpenShop(tab: string?)
	if tab then
		selectTab(tab)
	end
	if shop.IsOpen() and not tab then
		shop.Close()
	else
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
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	-- two-column tile grid: left-centre on desktop, tucked top-left on touch so it
	-- stays clear of the thumbstick
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundTransparency = 1
	sidebar.Size = UDim2.fromOffset(160, 336)
	if Components.isTouch() then
		sidebar.Position = UDim2.fromOffset(12, 6)
	else
		sidebar.Position = UDim2.new(0, 16, 0.5, -20)
		sidebar.AnchorPoint = Vector2.new(0, 0.5)
	end
	sidebar.Parent = layer
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(74, 74)
	layout.CellPadding = UDim2.fromOffset(12, 12)
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
	local function refreshQuestBadge()
		Components.setBadge(questTile, if QuestController.ClaimableCount() > 0 then "!" else nil)
	end
	QuestController.Changed:Connect(refreshQuestBadge)
	refreshQuestBadge()

	local passTile = Components.tile(sidebar, "Passes", "Passes", C.Gold, 4)
	passTile.Activated:Connect(function()
		MenuController.OpenShop("Passes")
	end)

	local spectateTile = Components.tile(sidebar, "Spectate", "Spectate", C.Blue, 5)
	spectateTile.Activated:Connect(SpectateController.Toggle)

	local roleTile = Components.tile(sidebar, "PlayGod", "Play God", C.Purple, 6)
	local function refreshRoleTile()
		local solo = #Players:GetPlayers() == 1 and Config.Match.AllowSoloRoleToggle
		roleTile.Visible = solo
		local wantsGod = player:GetAttribute(Attributes.PreferredRole) == "DisasterGod"
		local icon = roleTile:FindFirstChild("Icon")
		local caption = roleTile:FindFirstChild("Caption") :: TextLabel?
		if icon and caption then
			Components.setIcon(icon, if wantsGod then "Dash" else "PlayGod")
			caption.Text = if wantsGod then "Survivor" else "Play God"
		end
	end
	local settingsTile = Components.tile(sidebar, "Settings", "Settings", C.Green, 7)
	settingsTile.Activated:Connect(SettingsController.Toggle)

	roleTile.Activated:Connect(function()
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
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshSidebar)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshSidebar)
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
