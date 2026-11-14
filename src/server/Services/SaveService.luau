--!strict
-- SaveService: cheap single-use "panic saves" that fire automatically (no prompt in the
-- middle of a fall):
--   * Emergency Glider: about to drop into the void or sinking in the rising fluid ->
--     launched back up toward the middle of the map on a slow glide.
--   * Aegis Bubble: a disaster hit that would kill you is absorbed; brief shield.
-- After a death a save would have prevented, the player gets a one-tap offer card.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AudioService = require(script.Parent.AudioService)
local MapService = require(script.Parent.MapService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RoleService = require(script.Parent.RoleService)

local SV = Config.Saves
local CYAN = Color3.fromRGB(90, 230, 255)
local GOLD = Color3.fromRGB(255, 210, 60)

local SaveService = {}

local lastFired: { [Player]: number } = {}
local mercyUntil: { [Player]: number } = {}

local function ready(player: Player): boolean
	return (lastFired[player] or 0) + SV.Cooldown <= os.clock()
end

local function announce(player: Player, text: string, color: Color3)
	Remotes.get("Popup"):FireClient(player, text, color)
	Remotes.get("Feed"):FireAllClients(string.format("%s %s", player.DisplayName, text:lower()), color)
end

-- Called every hazard step for alive survivors. Returns true if a glider fired.
function SaveService.TryGlider(player: Player, hrp: BasePart, fluidTop: number?): boolean
	local falling = hrp.Position.Y < Config.Player.KillPlaneY + SV.GliderDropBelow and hrp.AssemblyLinearVelocity.Y < SV.GliderFallSpeed
	local sinking = fluidTop ~= nil and hrp.Position.Y < fluidTop - 1
	if not (falling or sinking) or not ready(player) then
		return false
	end
	if not PlayerDataService.UseSave(player, "Glider") then
		return false
	end
	lastFired[player] = os.clock()
	local info = MapService.GetCurrent()
	local center = if info then info.Center else Vector3.zero
	local toCenter = Vector3.new(center.X - hrp.Position.X, 0, center.Z - hrp.Position.Z)
	local dir = if toCenter.Magnitude > 1 then toCenter.Unit else Vector3.zero
	local clientEffect = Remotes.get("ClientEffect")
	clientEffect:FireClient(player, "Knockback", dir * SV.GliderLaunchForward + Vector3.new(0, SV.GliderLaunchUp, 0))
	clientEffect:FireClient(player, "LowGravity", SV.GliderFloatSeconds, SV.GliderGravityScale)
	AudioService.playAt("Gust", hrp.Position, 2, 1.2)
	announce(player, "🪂 EMERGENCY GLIDER deployed!", CYAN)
	return true
end

-- Called before disaster damage. Returns true when the hit was absorbed.
function SaveService.TryAegis(player: Player, humanoid: Humanoid, damage: number): boolean
	if damage < humanoid.Health or humanoid.Health <= 0 or not ready(player) then
		return false
	end
	if not PlayerDataService.UseSave(player, "Aegis") then
		return false
	end
	lastFired[player] = os.clock()
	humanoid.Health = math.max(humanoid.Health, SV.AegisHealth)
	local character = humanoid.Parent
	if character then
		local field = Instance.new("ForceField")
		field.Visible = true
		field.Parent = character
		Debris:AddItem(field, SV.AegisShieldSeconds)
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			AudioService.playAt("Glass", hrp.Position, 1.8, 0.7)
		end
	end
	announce(player, "🛡️ AEGIS BUBBLE blocked a fatal hit!", GOLD)
	return true
end

-- The single gate for disaster damage. False = absorbed: the player is in their mercy
-- window after a previous hit (no chain deaths from overlapping blasts), or an Aegis charge
-- caught a fatal hit. Otherwise the hit lands and opens a short mercy window.
function SaveService.AllowHit(player: Player, humanoid: Humanoid, damage: number): boolean
	local now = os.clock()
	if (mercyUntil[player] or 0) > now then
		return false
	end
	if SaveService.TryAegis(player, humanoid, damage) then
		return false
	end
	-- an air-drop shield soaks one whole hit
	local shields = player:GetAttribute(Config.Attributes.ShieldCharges)
	if typeof(shields) == "number" and shields > 0 then
		player:SetAttribute(Config.Attributes.ShieldCharges, shields - 1)
		mercyUntil[player] = now + Config.Feel.MercySeconds
		Remotes.get("ClientEffect"):FireClient(player, "Mercy", Config.Feel.MercySeconds)
		Remotes.get("Popup"):FireClient(player, "🛡️ SHIELD BLOCKED A HIT", Color3.fromRGB(120, 200, 255))
		return false
	end
	mercyUntil[player] = now + Config.Feel.MercySeconds
	Remotes.get("ClientEffect"):FireClient(player, "Mercy", Config.Feel.MercySeconds)
	return true
end

-- True while the player has a ForceField (Aegis or Shield gear): skip further damage.
function SaveService.IsShielded(humanoid: Humanoid): boolean
	return humanoid.Parent ~= nil and humanoid.Parent:FindFirstChildOfClass("ForceField") ~= nil
end

-- After an elimination: offer the save that would have prevented it, if they had none.
function SaveService.OfferAfterDeath(player: Player, cause: string?)
	if not cause or not RoleService.GetRole(player) then
		return
	end
	local kind: string? = nil
	if cause == "Void" or cause:sub(1, 6) == "Fluid:" then
		kind = "Glider"
	elseif cause ~= "Quicksand" and cause ~= "HazardFloor" then
		kind = "Aegis"
	end
	if kind and (player:GetAttribute(Config.Attributes.SavePrefix .. kind) or 0) == 0 then
		Remotes.get("ClientEffect"):FireClient(player, "SaveOffer", kind, SV.OfferSeconds)
	end
end

function SaveService.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastFired[player] = nil
		mercyUntil[player] = nil
	end)
end

return SaveService
