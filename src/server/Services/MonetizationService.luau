--!strict
-- MonetizationService: developer product receipts (idempotent) and game pass perks.
--   Products: coin packs, Be the God Next Round, Survival Kit, Welcome Pack, Second Chance,
--             wheel spin packs, cosmetics (God skins, disaster FX, finishers) and panic saves.
--             Products whose Id is still 0 (placeholders) are never matched by receipts.
--   Passes:   2x Coins, VIP, God Priority, Quick Dash (flags as Player attributes Pass_<Key>).
-- Studio only: ServerStorage.DevPurchase (BindableFunction) runs the same grant path so the
-- flow can be tested without real purchase prompts.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CosmeticService = require(script.Parent.CosmeticService)
local MatchService = require(script.Parent.MatchService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)
local ShopService = require(script.Parent.ShopService)
local SpinService = require(script.Parent.SpinService)

local M = Config.Monetization
local Attributes = Config.Attributes

local AnalyticsService = require(script.Parent.AnalyticsService)

local MonetizationService = {}

local productKeyById: { [number]: string } = {}
for key, def in M.Products do
	if def.Id ~= 0 then
		productKeyById[def.Id] = key
	end
end
local passKeyById: { [number]: string } = {}
for key, def in M.Passes do
	passKeyById[def.Id] = key
end

local popup = Remotes.get("Popup")
local GOLD = Color3.fromRGB(255, 210, 60)

---------------------------------------------------------------------------
-- passes

local function applyVipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 120
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "👑 VIP"
	label.TextColor3 = GOLD
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(60, 40, 0)
	stroke.Parent = label
end

local function setPass(player: Player, key: string, owned: boolean)
	player:SetAttribute(Attributes.PassPrefix .. key, owned)
	if owned and key == "VIP" then
		applyVipTag(player)
	end
end

local function checkPasses(player: Player)
	for key, def in M.Passes do
		task.spawn(function()
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
			end)
			if player.Parent then
				setPass(player, key, ok and owns == true)
			end
		end)
	end
end

function MonetizationService.HasPass(player: Player, key: string): boolean
	return player:GetAttribute(Attributes.PassPrefix .. key) == true
end

---------------------------------------------------------------------------
-- product grants

local grants: { [string]: (Player) -> () } = {}

local function grantCoins(key: string): (Player) -> ()
	return function(player: Player)
		local coins = M.Products[key].Coins or 0
		PlayerDataService.AddCoins(player, coins)
		AnalyticsService.CoinsBought(player, coins, key)
		popup:FireClient(player, string.format("+%d COINS — THANK YOU!", coins), GOLD)
	end
end
grants.CoinsSmall = grantCoins("CoinsSmall")
grants.CoinsMedium = grantCoins("CoinsMedium")
grants.CoinsLarge = grantCoins("CoinsLarge")
grants.CoinsHuge = grantCoins("CoinsHuge")

grants.GodNextRound = function(player: Player)
	RoleService.QueueGod(player)
	popup:FireClient(player, "YOU'LL BE THE GOD NEXT ROUND!", Color3.fromRGB(200, 130, 255))
end

grants.SurvivalKit = function(player: Player)
	ShopService.GrantKit(player)
	popup:FireClient(player, "SURVIVAL KIT ADDED", Color3.fromRGB(120, 255, 160))
end

grants.WelcomePack = function(player: Player)
	PlayerDataService.AddCoins(player, M.Products.WelcomePack.Coins or 0)
	ShopService.GrantKit(player)
	PlayerDataService.MarkWelcomeClaimed(player)
	popup:FireClient(player, "WELCOME PACK CLAIMED!", GOLD)
end

local function grantSpins(key: string): (Player) -> ()
	return function(player: Player)
		SpinService.AddSpins(player, M.Products[key].Spins or 1)
	end
end
grants.Spin1 = grantSpins("Spin1")
grants.Spin10 = grantSpins("Spin10")

grants.Revive = function(player: Player)
	if not MatchService.Revive(player) then
		-- round ended (or not eliminated) between prompt and purchase: never lose value
		PlayerDataService.AddCoins(player, M.ReviveFallbackCoins)
		popup:FireClient(player, string.format("ROUND OVER — +%d COINS INSTEAD", M.ReviveFallbackCoins), GOLD)
	end
end

-- cosmetics and panic saves come straight from their product definitions
for key, def in M.Products do
	local cosmetic, save = def.Cosmetic, def.Save
	if cosmetic then
		grants[key] = function(player: Player)
			CosmeticService.Grant(player, cosmetic)
		end
	elseif save then
		grants[key] = function(player: Player)
			PlayerDataService.AddSave(player, save, 1)
			popup:FireClient(player, string.format("%s %s +1 — FIRES AUTOMATICALLY", def.Icon, string.upper(def.Name)), GOLD)
		end
	end
end

-- `keyOverride`: Studio DevPurchase of a placeholder product (Id 0) names it directly.
local function processReceipt(receipt: { [string]: any }, keyOverride: string?): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not PlayerDataService.Get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if PlayerDataService.HasReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = keyOverride or productKeyById[receipt.ProductId]
	local grant = key and grants[key]
	if not grant then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(grant, player)
	if not ok then
		warn("[Monetization] grant failed", key, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerDataService.AddReceipt(player, purchaseId)
	PlayerDataService.SaveNow(player)
	local def = M.Products[key :: string]
	AnalyticsService.PurchaseCompleted(player, key :: string, "Product", if def then def.Price else nil)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------------

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = function(receipt)
		return processReceipt(receipt)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key then
			setPass(player, key, true)
			AnalyticsService.PurchaseCompleted(player, key, "Pass", M.Passes[key].Price)
			popup:FireClient(player, string.upper(M.Passes[key].Name) .. " UNLOCKED!", GOLD)
		end
	end)

	local function onPlayer(player: Player)
		checkPasses(player)
		player.CharacterAdded:Connect(function()
			if MonetizationService.HasPass(player, "VIP") then
				task.defer(applyVipTag, player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevPurchase"
		-- Invoke(userId, "Product" | "Pass", key [, purchaseId]) -> decision name / true
		dev.OnInvoke = function(userId: number, kind: string, key: string, purchaseId: string?)
			if kind == "Pass" then
				local player = Players:GetPlayerByUserId(userId)
				if player and M.Passes[key] then
					setPass(player, key, true)
					return true
				end
				return false
			end
			local def = M.Products[key]
			if not def then
				return "UnknownProduct"
			end
			local decision = processReceipt({
				PlayerId = userId,
				ProductId = def.Id,
				PurchaseId = purchaseId or ("studio-" .. key .. "-" .. tostring(os.clock())),
				CurrencySpent = 0,
			}, if def.Id == 0 then key else nil)
			return decision.Name
		end
		dev.Parent = ServerStorage
	end
end

return MonetizationService
