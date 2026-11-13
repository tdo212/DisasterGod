--!strict
-- CosmeticService: God skins, disaster VFX packs and ragdoll finishers.
--   * Coin items are bought here (CosmeticAction "Buy"); Robux items are granted by
--     MonetizationService. Anything owned can be equipped (CosmeticAction "Equip").
--   * The human God's reticle (GodAim remote, throttled by the client) and equipped skin
--     are published on ReplicatedStorage; every client floats the skin over that point.
--   * VfxOf(caster) gives DisasterService the caster's palette.
--   * Finisher(player, character) plays the victim's equipped elimination effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local AudioService = require(script.Parent.AudioService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)

local CO = Config.Cosmetics
local Attributes = Config.Attributes
local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(255, 90, 90)

local CosmeticService = {}

local defs: { [string]: Types.CosmeticDefinition } = {}
for _, def in CO.Items do
	defs[def.Id] = def
end

local popup = Remotes.get("Popup")
local lastAim: { [Player]: number } = {}

local function isFree(def: Types.CosmeticDefinition): boolean
	return def.Coins == nil and def.Product == nil
end

-- Palette for the caster's disasters (the AI Director and default kits use Classic).
function CosmeticService.VfxOf(caster: Player?): Types.VfxPack
	if not caster then
		return CO.VfxPacks.ClassicFx
	end
	return CO.VfxPacks[PlayerDataService.GetEquipped(caster, "Vfx")] or CO.VfxPacks.ClassicFx
end

-- Publish the God's skin for the sky avatar ("" when the AI Director plays God).
function CosmeticService.SetGod(god: Player?)
	ReplicatedStorage:SetAttribute(Attributes.GodSkin, if god then PlayerDataService.GetEquipped(god, "GodSkin") else "")
	ReplicatedStorage:SetAttribute(Attributes.GodAim, nil)
end

-- Elimination effect at the body (everyone sees it). Cartoon Boing also flings the body.
function CosmeticService.Finisher(player: Player, character: Model)
	local id = PlayerDataService.GetEquipped(player, "Finisher")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	Remotes.get("ClientEffect"):FireAllClients("Finisher", id, hrp.Position, character)
	if id == "CartoonBoing" then
		AudioService.playAt("Boing", hrp.Position, 2)
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
		hrp.AssemblyLinearVelocity = Vector3.new(0, CO.BoingUpSpeed, 0)
		local attachment = Instance.new("Attachment")
		attachment.Parent = hrp
		local float = Instance.new("VectorForce")
		float.Attachment0 = attachment
		float.RelativeTo = Enum.ActuatorRelativeTo.World
		-- cancel most of gravity so the toon drifts back down slowly
		float.Force = Vector3.new(0, character:GetMass() * workspace.Gravity * 0.85, 0)
		float.Parent = hrp
		task.delay(CO.BoingFloatSeconds, function()
			float:Destroy()
			attachment:Destroy()
		end)
	elseif id == "ConfettiPop" then
		AudioService.playAt("Glass", hrp.Position, 1.6, 2.2)
	end
end

local function onAction(player: Player, action: any, id: any)
	if typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	local def = defs[id]
	if not def then
		return
	end
	if action == "Buy" then
		if PlayerDataService.OwnsCosmetic(player, id) then
			PlayerDataService.EquipCosmetic(player, id)
			return
		end
		local price = def.Coins
		if not price then
			return -- Robux items go through MonetizationService
		end
		if not PlayerDataService.SpendCoins(player, price) then
			popup:FireClient(player, "NOT ENOUGH COINS", RED)
			return
		end
		PlayerDataService.GrantCosmetic(player, id)
		PlayerDataService.EquipCosmetic(player, id)
		popup:FireClient(player, string.upper(def.Name) .. " UNLOCKED!", GOLD)
	elseif action == "Equip" then
		if PlayerDataService.EquipCosmetic(player, id) and def.Category == "GodSkin" and RoleService.GetGod() == player then
			ReplicatedStorage:SetAttribute(Attributes.GodSkin, id)
		end
	end
end

-- Robux grant (MonetizationService): unlock and equip.
function CosmeticService.Grant(player: Player, id: string)
	local def = defs[id]
	if not def then
		return
	end
	PlayerDataService.GrantCosmetic(player, id)
	PlayerDataService.EquipCosmetic(player, id)
	popup:FireClient(player, string.upper(def.Name) .. " UNLOCKED!", GOLD)
	if def.Category == "GodSkin" and RoleService.GetGod() == player then
		ReplicatedStorage:SetAttribute(Attributes.GodSkin, id)
	end
end

function CosmeticService.IsFree(id: string): boolean
	local def = defs[id]
	return def ~= nil and isFree(def)
end

function CosmeticService.Init()
	ReplicatedStorage:SetAttribute(Attributes.GodSkin, "")
	Remotes.get("CosmeticAction").OnServerEvent:Connect(onAction)
	Remotes.get("GodAim").OnServerEvent:Connect(function(player, aim)
		if typeof(aim) ~= "Vector3" or aim.X ~= aim.X or aim.Magnitude > 1e4 then
			return
		end
		if RoleService.GetGod() ~= player or RoleService.GetRole(player) ~= "DisasterGod" then
			return
		end
		local now = os.clock()
		if (lastAim[player] or 0) + 0.5 / CO.AimSendRate > now then
			return -- ignore floods beyond twice the send rate
		end
		lastAim[player] = now
		ReplicatedStorage:SetAttribute(Attributes.GodAim, aim)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAim[player] = nil
		if RoleService.GetGod() == player then
			CosmeticService.SetGod(nil)
		end
	end)
end

return CosmeticService
