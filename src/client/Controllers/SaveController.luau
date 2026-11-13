--!strict
-- SaveController: panic-save charges on the survivor HUD (🪂 Glider / 🛡️ Aegis, only when
-- you own some) and the "this would have saved you" offer after a preventable death.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Store = require(UI:WaitForChild("Store") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local HUDController = require(script.Parent:WaitForChild("HUDController") :: ModuleScript)

local Attributes = Config.Attributes
local M = Config.Monetization
local C = Theme.Colors
local player = Players.LocalPlayer

local KINDS = {
	{ Kind = "Glider", Product = "SaveGlider", Saved = "A Glider would have caught that fall!" },
	{ Kind = "Aegis", Product = "SaveAegis", Saved = "An Aegis Bubble would have blocked that!" },
}

local SaveController = {}

local chips: Frame
local chipLabels: { [string]: TextLabel } = {}
local offer: Frame
local offerText: TextLabel
local offerButton: TextButton
local offerKey = ""
local offerToken = 0

local function refreshChips()
	local active = player:GetAttribute(Attributes.Role) == "Survivor"
		and player:GetAttribute(Attributes.Alive) == true
		and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active"
	local any = false
	for _, k in KINDS do
		local n = player:GetAttribute(Attributes.SavePrefix .. k.Kind) :: number? or 0
		local label = chipLabels[k.Kind]
		label.Visible = n > 0
		label.Text = string.format("%s x%d", M.Products[k.Product].Icon, n)
		any = any or n > 0
	end
	chips.Visible = active and any
end

local function showOffer(kind: string, seconds: number)
	for _, k in KINDS do
		if k.Kind == kind then
			local def = M.Products[k.Product]
			offerKey = k.Product
			offerText.Text = string.format("%s %s", def.Icon, k.Saved)
			Components.setText(offerButton, if def.Id == 0 then "SOON" else "Get one · " .. Store.robux(def.Price))
		end
	end
	offerToken += 1
	local token = offerToken
	offer.Visible = true
	task.delay(seconds, function()
		if offerToken == token then
			offer.Visible = false
		end
	end)
end

function SaveController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaveHUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local layer = Components.scaledRoot(gui)

	chips = Instance.new("Frame")
	chips.Name = "Saves"
	chips.BackgroundTransparency = 1
	chips.AnchorPoint = Vector2.new(0.5, 1)
	chips.Position = UDim2.new(0.5, 0, 1, -108)
	chips.Size = UDim2.fromOffset(240, 26)
	chips.Visible = false
	chips.Parent = layer
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = chips
	for i, k in KINDS do
		local label = Components.label({ Name = k.Kind, Text = "", TextSize = 20, Color = C.GoldLight, Size = UDim2.fromOffset(90, 26), Parent = chips })
		label.LayoutOrder = i
		chipLabels[k.Kind] = label
	end

	offer = Components.panel({
		Name = "SaveOffer",
		Size = UDim2.fromOffset(470, 98),
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Panel,
		Transparency = 0.1,
		Parent = layer,
	})
	offer.Visible = false
	offerText = Components.label({ Name = "Text", Text = "", TextSize = 19, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 6), Parent = offer })
	offerText.TextWrapped = true
	offerButton = Components.button({
		Name = "Buy",
		Text = "",
		TextSize = 20,
		Size = UDim2.fromOffset(230, 44),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Pink,
		ColorLight = C.PinkLight,
		Parent = offer,
		OnClick = function()
			if not Store.promptProduct(offerKey) then
				HUDController.Popup("COMING SOON", C.GoldLight)
			end
			offer.Visible = false
		end,
	})

	for _, k in KINDS do
		player:GetAttributeChangedSignal(Attributes.SavePrefix .. k.Kind):Connect(refreshChips)
	end
	for _, attr in { Attributes.Role, Attributes.Alive } do
		player:GetAttributeChangedSignal(attr):Connect(refreshChips)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshChips)
	refreshChips()

	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "SaveOffer" and typeof(a) == "string" then
			showOffer(a, if typeof(b) == "number" then b else 8)
		end
	end)
end

return SaveController
