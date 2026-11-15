--!strict
-- Robux purchase prompts for developer products and game passes (keys from Config.Monetization).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript)
local Analytics = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Analytics") :: ModuleScript)

local M = Config.Monetization
local player = Players.LocalPlayer

local Store = {}

local ROBUX_GLYPH = utf8.char(0xE002) -- the Robux icon in Roblox's built-in fonts

function Store.robux(price: number): string
	return ROBUX_GLYPH .. " " .. tostring(price)
end

-- Prompt a developer product. Returns false for placeholders (Id 0, not on sale yet).
-- Robux wheel spins are paid random items: hidden where PolicyService restricts them
-- (MonetizationService sets the attribute; unknown counts as restricted).
function Store.paidRandomAllowed(): boolean
	return player:GetAttribute(Config.Attributes.PaidRandomRestricted) == false
end

function Store.promptProduct(key: string): boolean
	local def = M.Products[key]
	if not def or def.Id == 0 then
		return false
	end
	if (def.Spins or 0) > 0 and not Store.paidRandomAllowed() then
		return false
	end
	Analytics.track("PromptShown", key)
	MarketplaceService:PromptProductPurchase(player, def.Id)
	return true
end

-- On sale: the product exists and has a live id.
function Store.isLive(key: string): boolean
	local def = M.Products[key]
	return def ~= nil and def.Id ~= 0
end

function Store.promptPass(key: string)
	local def = M.Passes[key]
	if def then
		Analytics.track("PromptShown", key)
		MarketplaceService:PromptGamePassPurchase(player, def.Id)
	end
end

function Store.ownsPass(key: string): boolean
	return player:GetAttribute(Config.Attributes.PassPrefix .. key) == true
end

return Store
