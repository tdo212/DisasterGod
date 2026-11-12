--!strict
-- MenuController: left sidebar tiles (Shop, Spectate, solo role toggle) and the
-- gear Shop window (also opened from the lobby shop stall's proximity prompt).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local SpectateController = require(script.Parent:WaitForChild("SpectateController") :: ModuleScript)
local HUDController = require(script.Parent:WaitForChild("HUDController") :: ModuleScript)

local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local MenuController = {}

local started = false
local gui: ScreenGui
local shop: any -- Components.WindowHandle

local function buildShop()
	shop = Components.window(gui, "Shop", UDim2.fromOffset(640, 440))
	local content = shop.Content

	-- section pill ("Packs" style divider)
	local pill = Components.panel({
		Name = "Section",
		Size = UDim2.fromOffset(240, 40),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Color3.fromRGB(45, 55, 85),
		Radius = Theme.Radius.Pill,
		Parent = content,
	})
	Components.label({ Name = "Text", Text = "Survival Gear", TextSize = 26, Size = UDim2.fromScale(1, 1), Parent = pill })
	for _, side in { -1, 1 } do
		local rule = Instance.new("Frame")
		rule.Size = UDim2.new(0.5, -140, 0, 3)
		rule.Position = UDim2.new(if side < 0 then 0 else 0.5, if side < 0 then 10 else 130, 0, 19)
		rule.BackgroundColor3 = C.PanelLight
		rule.BorderSizePixel = 0
		rule.Parent = content
	end

	local wallet = Components.label({
		Name = "Wallet",
		Text = "",
		TextSize = 22,
		Color = C.Gold,
		Size = UDim2.fromOffset(200, 26),
		Position = UDim2.new(1, -4, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		XAlign = Enum.TextXAlignment.Right,
		Parent = content,
	})
	local function refreshWallet()
		wallet.Text = "💰 " .. HUDController.FormatNumber(player:GetAttribute(Attributes.Coins) :: number? or 0)
	end
	player:GetAttributeChangedSignal(Attributes.Coins):Connect(refreshWallet)
	refreshWallet()

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 1, -84)
	grid.Position = UDim2.fromOffset(0, 54)
	grid.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, def in Config.Gear do
		local card = Instance.new("Frame")
		card.Name = def.Id
		card.LayoutOrder = i
		card.Size = UDim2.fromOffset(186, 268)
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		Components.corner(card, Theme.Radius.Large)
		Components.stroke(card, Theme.Stroke.Heavy)
		Components.gradient(card, def.Color:Lerp(Color3.new(1, 1, 1), 0.4), def.Color)
		card.Parent = grid

		Components.label({ Name = "Icon", Text = def.Icon, TextSize = 64, StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 8), Parent = card })
		Components.label({ Name = "Name", Text = def.DisplayName, TextSize = 22, Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 100), Parent = card })
		local desc = Components.label({ Name = "Desc", Text = def.Description, TextSize = 16, Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 128), Parent = card })
		desc.TextWrapped = true
		local owned = Components.panel({
			Name = "Owned",
			Size = UDim2.new(1, -24, 0, 30),
			Position = UDim2.new(0.5, 0, 0, 172),
			AnchorPoint = Vector2.new(0.5, 0),
			Color = Color3.fromRGB(30, 35, 45),
			Transparency = 0.35,
			Radius = Theme.Radius.Pill,
			Parent = card,
		})
		local ownedLabel = Components.label({ Name = "Text", Text = "", TextSize = 18, Size = UDim2.fromScale(1, 1), Parent = owned })
		local function refreshOwned()
			local n = player:GetAttribute(Attributes.GearPrefix .. def.Id) :: number? or 0
			ownedLabel.Text = string.format("Owned x%d  ·  Key %s", n, def.Key)
		end
		player:GetAttributeChangedSignal(Attributes.GearPrefix .. def.Id):Connect(refreshOwned)
		refreshOwned()

		Components.button({
			Name = "Buy",
			Text = "💰 " .. tostring(def.Price),
			TextSize = 26,
			Size = UDim2.new(1, -24, 0, 48),
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = C.Green,
			ColorLight = C.GreenLight,
			Parent = card,
			OnClick = function()
				Remotes.get("BuyGear"):FireServer(def.Id)
			end,
		})
	end
end

function MenuController.OpenShop()
	if shop.IsOpen() then
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

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.BackgroundTransparency = 1
	sidebar.Size = UDim2.fromOffset(96, 330)
	sidebar.Position = UDim2.new(0, 16, 0.5, -20)
	sidebar.AnchorPoint = Vector2.new(0, 0.5)
	sidebar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 18)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sidebar

	buildShop()

	local shopTile = Components.tile(sidebar, "🛒", "Shop", C.Red, 1)
	shopTile.Activated:Connect(MenuController.OpenShop)

	local spectateTile = Components.tile(sidebar, "👁️", "Spectate", C.Blue, 2)
	spectateTile.Activated:Connect(SpectateController.Toggle)

	local roleTile = Components.tile(sidebar, "😈", "Play God", C.Purple, 3)
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
