--!strict
-- Robux purchase prompts for developer products and game passes (keys from Config.Monetization).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config") :: ModuleScript)

local M = Config.Monetization
local player = Players.LocalPlayer

local Store = {}

function Store.robux(price: number): string
	return "R$ " .. tostring(price)
end

function Store.promptProduct(key: string)
	local def = M.Products[key]
	if def then
		MarketplaceService:PromptProductPurchase(player, def.Id)
	end
end

function Store.promptPass(key: string)
	local def = M.Passes[key]
	if def then
		MarketplaceService:PromptGamePassPurchase(player, def.Id)
	end
end

function Store.ownsPass(key: string): boolean
	return player:GetAttribute(Config.Attributes.PassPrefix .. key) == true
end

return Store
