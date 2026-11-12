--!strict
-- MenuController: left sidebar tiles (Shop, Passes, Spectate, solo role toggle) and the
-- tabbed Shop window — Gear (coins), Coins (Robux packs), Passes, Specials. The lobby
-- shop stall's proximity prompt opens it too.

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
local HUDController = require(script.Parent:WaitForChild("HUDController") :: ModuleScript)

local Attributes = Config.Attributes
local M = Config.Monetization
local C = Theme.Colors
local player = Players.LocalPlayer

local MenuController = {}

local started = false
local gui: ScreenGui
local layer: Frame -- viewport-scaled root for all UI content
local shop: any -- Components.WindowHandle
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local TAB_ORDER = { "Gear", "Coins", "Passes", "Specials" }

local BADGE_COLORS: { [string]: { Color3 } } = {
	["Good Value"] = { C.BlueLight, C.Blue },
	["Great Value"] = { C.OrangeLight, C.Orange },
	["Most Value"] = { C.Pink, C.Purple },
	["Starter Deal"] = { C.GreenLight, C.Green },
}

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
	frame.Parent = parent

	if spec.Badge and spec.Badge ~= "" then
		local colors = BADGE_COLORS[spec.Badge] or { C.BlueLight, C.Blue }
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.new(1, -16, 0, 28)
		badge.Position = UDim2.new(0.5, 0, 0, 8)
		badge.AnchorPoint = Vector2.new(0.5, 0)
		badge.BackgroundColor3 = Color3.new(1, 1, 1)
		Components.corner(badge, Theme.Radius.Pill)
		Components.stroke(badge, Theme.Stroke.Thick)
		Components.gradient(badge, colors[1], colors[2], 0)
		badge.Parent = frame
		Components.label({ Name = "Text", Text = spec.Badge, TextSize = 18, Size = UDim2.fromScale(1, 1), Parent = badge })
	end
	Components.label({ Name = "Icon", Text = spec.Icon, TextSize = 52, StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 72), Position = UDim2.fromOffset(0, 38), Parent = frame })
	Components.label({ Name = "Title", Text = spec.Title, TextSize = 20, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 112), Parent = frame })
	local pill = Components.panel({
		Name = "Info",
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.new(0.5, 0, 0, 142),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.fromRGB(25, 30, 40),
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
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = spec.ButtonColor or C.Green,
		ColorLight = spec.ButtonLight or C.GreenLight,
		Parent = frame,
		OnClick = spec.OnClick,
	})
	return frame, button, sub
end

local function grid(parent: Frame, name: string): Frame
	local page = Instance.new("Frame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.Size = UDim2.new(1, 0, 1, -96)
	page.Position = UDim2.fromOffset(0, 60)
	page.Visible = false
	page.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
	layout.Parent = page
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
		local scale = button:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = if tab == name then 1.06 else 1
		end
	end
end

local function setOwnedLook(button: TextButton, owned: boolean)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = if owned then ColorSequence.new(C.TextDim, C.PanelLight) else ColorSequence.new(C.GreenLight, C.Green)
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
			sub.Text = string.format("%s\nOwned x%d · Key %s", def.Description, n, def.Key)
		end
		player:GetAttributeChangedSignal(Attributes.GearPrefix .. def.Id):Connect(refresh)
		refresh()
	end
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

	local revive = M.Products.Revive
	card(page, {
		Order = 4,
		Top = Color3.fromRGB(255, 150, 190),
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
	layout.Padding = UDim.new(0, 12)
	layout.Parent = tabs
	local tabColors = {
		Gear = { C.BlueLight, C.Blue },
		Coins = { C.GreenLight, C.Green },
		Passes = { C.PurpleLight, C.Purple },
		Specials = { C.OrangeLight, C.Orange },
	}
	for i, name in TAB_ORDER do
		local b = Components.button({
			Name = name,
			Text = name,
			TextSize = 22,
			Size = UDim2.fromOffset(150, 42),
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
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundTransparency = 1
	sidebar.Size = UDim2.fromOffset(96, 430)
	sidebar.Position = UDim2.new(0, 16, 0.5, -20)
	sidebar.AnchorPoint = Vector2.new(0, 0.5)
	sidebar.Parent = layer
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 18)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sidebar

	buildShop()
	HUDController.SetShopOpener(MenuController.OpenShop)

	local shopTile = Components.tile(sidebar, "🛒", "Shop", C.Red, 1)
	shopTile.Activated:Connect(function()
		MenuController.OpenShop()
	end)

	local passTile = Components.tile(sidebar, "👑", "Passes", C.Gold, 2)
	passTile.Activated:Connect(function()
		MenuController.OpenShop("Passes")
	end)

	local spectateTile = Components.tile(sidebar, "👁️", "Spectate", C.Blue, 3)
	spectateTile.Activated:Connect(SpectateController.Toggle)

	local roleTile = Components.tile(sidebar, "😈", "Play God", C.Purple, 4)
	local function refreshRoleTile()
		local solo = #Players:GetPlayers() == 1 and Config.Match.AllowSoloRoleToggle
		roleTile.Visible = solo
		local wantsGod = player:GetAttribute(Attributes.PreferredRole) == "DisasterGod"
		local icon = roleTile:FindFirstChild("Icon") :: TextLabel?
		local caption = roleTile:FindFirstChild("Caption") :: TextLabel?
		if icon and caption then
			icon.Text = if wantsGod then "🏃" else "😈"
			caption.Text = if wantsGod then "Survivor" else "Play God"
		end
	end
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

	-- hide the sidebar while flying the God camera
	local function refreshSidebar()
		sidebar.Visible = player:GetAttribute(Attributes.Role) ~= "DisasterGod" or ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active"
		if Config.Match.AllowSoloRoleToggle and #Players:GetPlayers() == 1 then
			sidebar.Visible = true -- solo tester can always flip roles
		end
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshSidebar)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshSidebar)
	refreshSidebar()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ShopPrompt" then
			MenuController.OpenShop()
		end
	end)
end

return MenuController
