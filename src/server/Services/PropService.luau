--!strict
-- PropService: builds each arena's interactive props (World/Props) and runs them.
--   * Circuit breakers: hold to jam the God's radar nearby (StealthService.AddJam).
--     Flipping one is loud: the God sees a noise ripple at the breaker.
--   * Launch pads: fling an alive survivor up and toward the middle of the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Props = require(ServerScriptService.Server.World.Props)

local AudioService = require(script.Parent.AudioService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)
local StealthService = require(script.Parent.StealthService)

local P = Config.Props
local GREEN = Color3.fromRGB(90, 255, 140)
local RED = Color3.fromRGB(255, 70, 70)
local CYAN = Color3.fromRGB(90, 230, 255)

local PropService = {}

local connections: { RBXScriptConnection } = {}
local padCooldown: { [Player]: number } = {}
local roundActive = false
local clientEffect = Remotes.get("ClientEffect")

function PropService.SetRoundActive(active: boolean)
	roundActive = active
end

local function clear()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(padCooldown)
end

local function wireBreaker(b: { Panel: BasePart, Light: BasePart, Prompt: ProximityPrompt })
	local readyAt = 0
	table.insert(connections, b.Prompt.Triggered:Connect(function(player)
		if not (roundActive and RoleService.IsAliveSurvivor(player)) then
			return
		end
		local now = os.clock()
		if now < readyAt then
			ScoringService.Notify(player, string.format("BREAKER RECHARGING (%ds)", math.ceil(readyAt - now)), RED)
			return
		end
		readyAt = now + P.BreakerCooldown
		StealthService.AddJam(b.Panel.Position, P.JamRadius, P.JamDuration)
		StealthService.Noise(player, 1.6)
		AudioService.playAt("Warning", b.Panel.Position, 1.4, 0.6)
		ScoringService.Notify(player, "📡 RADAR JAMMED NEARBY", CYAN)
		local god = RoleService.GetGod()
		if god then
			ScoringService.Notify(god, "📡 A SURVIVOR JAMMED YOUR RADAR", RED)
		end
		b.Light.Color = RED
		b.Prompt.Enabled = false
		task.delay(P.BreakerCooldown, function()
			if b.Light.Parent then
				b.Light.Color = GREEN
				b.Prompt.Enabled = true
			end
		end)
	end))
end

local function wirePad(pad: BasePart, center: Vector3)
	table.insert(connections, pad.Touched:Connect(function(hit)
		if not roundActive or pad:GetAttribute("Broken") == true then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not (player and RoleService.IsAliveSurvivor(player)) then
			return
		end
		local now = os.clock()
		if (padCooldown[player] or 0) > now then
			return
		end
		padCooldown[player] = now + P.LaunchCooldown
		local toCenter = Vector3.new(center.X - pad.Position.X, 0, center.Z - pad.Position.Z)
		local dir = if toCenter.Magnitude > 1 then toCenter.Unit else Vector3.zero
		clientEffect:FireClient(player, "Knockback", dir * P.LaunchForward + Vector3.new(0, P.LaunchUp, 0))
		AudioService.playAt("Gust", pad.Position, 1.6, 1.3)
		StealthService.Noise(player, 1.2)
	end))
end

-- Called right after a map is built.
function PropService.Setup(info: Types.MapInfo)
	clear()
	local set = Props.build(info.Model, info.Name, info.Center)
	if not set then
		return
	end
	for _, b in set.Breakers do
		wireBreaker(b)
	end
	for _, pad in set.Pads do
		wirePad(pad, set.Center)
	end
end

function PropService.Init()
	Players.PlayerRemoving:Connect(function(player)
		padCooldown[player] = nil
	end)
end

return PropService
