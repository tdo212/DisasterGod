--!strict
-- CosmeticService: God skins, disaster VFX packs and ragdoll finishers.
--   * Coin items are bought here (CosmeticAction "Buy"); Robux items are granted by
--     MonetizationService. Anything owned can be equipped (CosmeticAction "Equip").
--   * The God's sky rig: the human God's reticle arrives on the GodAim UnreliableRemoteEvent
--     (10 Hz max) and is relayed to every client on GodAimRelay; the AI Director's hand
--     drifts between random spots and swoops to each target it casts at. The GodAim
--     attribute mirrors it at 2 Hz for late joiners and server logic. CastGesture tells
--     clients to play the slam / snap / flare on every cast.
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
local aimRelay = Remotes.unreliable("GodAimRelay")
local currentAim: Vector3? = nil
local lastAttribute = 0
local aiDriving = false

local function setAim(aim: Vector3)
	currentAim = aim
	aimRelay:FireAllClients(aim)
	local now = os.clock()
	if now - lastAttribute >= CO.AimAttributeInterval or ReplicatedStorage:GetAttribute(Attributes.GodAim) == nil then
		lastAttribute = now
		ReplicatedStorage:SetAttribute(Attributes.GodAim, aim)
	end
end

-- The latest aim point (server-side, every update; the attribute is throttled).
function CosmeticService.GetAim(): Vector3?
	return currentAim
end

-- The God (human or AI) just cast at `at`: the rig swoops there and gestures.
function CosmeticService.CastGesture(at: Vector3, abilityId: string)
	setAim(at)
	Remotes.get("ClientEffect"):FireAllClients("GodCast", at, abilityId)
end

-- AI rounds: the Director's hand wanders over the arena between casts (never over a
-- survivor, so it can't give hiding spots away).
local function directorDrift()
	if aiDriving then
		return
	end
	aiDriving = true
	task.spawn(function()
		local rng = Random.new()
		while ReplicatedStorage:GetAttribute(Attributes.GodSkin) == CO.DirectorSkin and RoleService.GetGod() == nil do
			if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active" then
				local a = rng:NextNumber(0, math.pi * 2)
				local d = rng:NextNumber(0, Config.World.ArenaRadius * 0.6)
				setAim(Config.World.ArenaCenter + Vector3.new(math.cos(a) * d, 10, math.sin(a) * d))
			end
			task.wait(CO.DirectorDriftSeconds)
		end
		aiDriving = false
	end)
end

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

-- Round start / God change: a human God shows their equipped skin, the AI Director its own.
function CosmeticService.SetGod(god: Player?)
	ReplicatedStorage:SetAttribute(Attributes.GodSkin, if god then PlayerDataService.GetEquipped(god, "GodSkin") else CO.DirectorSkin)
	ReplicatedStorage:SetAttribute(Attributes.GodAim, nil)
	currentAim = nil
	if not god then
		directorDrift()
	end
end

-- Round over: no sky rig until the next round.
function CosmeticService.ClearSky()
	ReplicatedStorage:SetAttribute(Attributes.GodSkin, "")
	ReplicatedStorage:SetAttribute(Attributes.GodAim, nil)
	currentAim = nil
end

-- Elimination effect at the body (everyone sees it). Cartoon Boing and Sky Beam also
-- fling the body.
function CosmeticService.Finisher(player: Player, character: Model)
	local id = PlayerDataService.GetEquipped(player, "Finisher")
	-- a God Pack brings its own finisher for survivors still on the starter one
	local skin = ReplicatedStorage:GetAttribute(Attributes.GodSkin)
	local pack = if typeof(skin) == "string" then Config.GodPacks[skin] else nil
	if pack and (id == "" or id == CO.Defaults.Finisher) then
		id = pack.Finisher
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	Remotes.get("ClientEffect"):FireAllClients("Finisher", id, hrp.Position, character)
	if id == "SkyBeam" then
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
		hrp.AssemblyLinearVelocity = Vector3.new(0, CO.BoingUpSpeed * 1.6, 0)
	end
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
	Remotes.unreliable("GodAim").OnServerEvent:Connect(function(player, aim)
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
		setAim(aim)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAim[player] = nil
		if RoleService.GetGod() == player then
			CosmeticService.SetGod(nil)
		end
	end)
end

return CosmeticService
