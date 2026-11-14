--!strict
-- MutatorService: round-to-round surprises, all free and server-rolled.
--   * Chaos Twist (Config.Mutators): right after the map vote, 20% of rounds roll one of
--     six mutators (equal weight), published as ReplicatedStorage.Mutator. Bouncy Rubble
--     and Brittle Timber are read by DestructionService, Hyperdrive by DisasterService and
--     the client dash, Gold Rush payouts by ScoringService. This service runs the live
--     parts: falling coins (Gold Rush), supply crates (Air Drops) and the darker sky
--     (Twilight Storm).
--   * Emergency Flare (Config.Beacon): in the last 30 s a flare lights up on the highest
--     exposed rooftop; survivors who hold near it for 4 s earn a big bonus (risk vs hiding).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EnvironmentService = require(script.Parent.EnvironmentService)
local MapService = require(script.Parent.MapService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)

local MU = Config.Mutators
local B = Config.Beacon
local Attributes = Config.Attributes

local MutatorService = {}

local rng = Random.new()
local active = ""
local roundOn = false
local dropped = false
local beaconOn = false
local beaconPart: BasePart? = nil
local holding: { [Player]: number } = {}
local claimed: { [Player]: boolean } = {}
local pickups: { Instance } = {}
local clientEffect = Remotes.get("ClientEffect")

local function def(id: string): any
	for _, m in MU.Pool do
		if m.Id == id then
			return m
		end
	end
	return nil
end

local function playerFrom(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	if player and RoleService.IsAliveSurvivor(player) then
		return player
	end
	return nil
end

local function hazards(): Instance
	return MapService.GetHazardsFolder()
end

-- Somewhere on the arena to drop things: a spawn point jittered, snapped to the ground.
local function dropPoint(): Vector3?
	local info = MapService.GetCurrent()
	if not info or #info.SpawnPoints == 0 then
		return nil
	end
	local base = info.SpawnPoints[rng:NextInteger(1, #info.SpawnPoints)].Position
	local p = base + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
	return MapService.GroundAt(p)
end

local function pickup(name: string, at: Vector3, color: Color3, size: Vector3, onTouch: (Player) -> ())
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.CFrame = CFrame.new(at + Vector3.new(0, 70, 0))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = part
	part.Parent = hazards()
	table.insert(pickups, part)
	TweenService:Create(part, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2 + 0.4, 0)) }):Play()
	local taken = false
	part.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = playerFrom(hit)
		if player then
			taken = true
			onTouch(player)
			part:Destroy()
		end
	end)
	Debris:AddItem(part, MU.PickupLifetime)
end

local function goldRushWave()
	for _ = 1, MU.GoldRushPerWave do
		local at = dropPoint()
		if at then
			pickup("GoldCoin", at, Color3.fromRGB(255, 210, 60), Vector3.new(2.4, 2.4, 0.6), function(player)
				ScoringService.Award(player, MU.GoldRushCoins, "GOLD RUSH", Color3.fromRGB(255, 210, 60))
			end)
		end
	end
end

local CRATE_KINDS = { "Speed", "Shield", "Coins" }

local function airDrop()
	local count = rng:NextInteger(MU.AirDropCount[1], MU.AirDropCount[2])
	for _ = 1, count do
		local at = dropPoint()
		if at then
			pickup("SupplyCrate", at, Color3.fromRGB(120, 240, 120), Vector3.new(4, 4, 4), function(player)
				local kind = CRATE_KINDS[rng:NextInteger(1, #CRATE_KINDS)]
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if kind == "Speed" and humanoid then
					player:SetAttribute(Attributes.SpeedUntil, workspace:GetServerTimeNow() + MU.AirDropSpeedSeconds)
					humanoid.WalkSpeed = MU.AirDropSpeed
					task.delay(MU.AirDropSpeedSeconds, function()
						if humanoid.Parent and humanoid.WalkSpeed == MU.AirDropSpeed then
							humanoid.WalkSpeed = Config.Player.WalkSpeed
						end
					end)
					ScoringService.Notify(player, "📦 SUPPLY: SPEED BOOST!", Color3.fromRGB(120, 240, 120))
				elseif kind == "Shield" then
					local n = player:GetAttribute(Attributes.ShieldCharges)
					player:SetAttribute(Attributes.ShieldCharges, (if typeof(n) == "number" then n else 0) + 1)
					ScoringService.Notify(player, "📦 SUPPLY: ONE-HIT SHIELD!", Color3.fromRGB(120, 200, 255))
				else
					ScoringService.Award(player, MU.AirDropCoins, "SUPPLY CRATE", Color3.fromRGB(255, 210, 60))
				end
			end)
		end
	end
	Remotes.get("Feed"):FireAllClients("📦 Supply crates are landing!", Color3.fromRGB(120, 240, 120))
end

-- The highest exposed rooftop among a handful of samples.
local function beaconSpot(): Vector3?
	local info = MapService.GetCurrent()
	if not info then
		return nil
	end
	local best: Vector3? = nil
	for _ = 1, B.Samples do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, info.Radius * 0.75)
		local g = MapService.GroundAt(info.Center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
		if not best or g.Y > best.Y then
			best = g
		end
	end
	return best
end

local function startBeacon()
	local at = beaconSpot()
	if not at then
		return
	end
	beaconOn = true
	local pole = Instance.new("Part")
	pole.Name = "EmergencyFlare"
	pole.Anchored = true
	pole.CanCollide = false
	pole.CanQuery = false
	pole.Size = Vector3.new(0.8, 6, 0.8)
	pole.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
	pole.Color = Color3.fromRGB(255, 70, 60)
	pole.Material = Enum.Material.Neon
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 14
	fire.Parent = pole
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 100, 60)
	light.Range = 30
	light.Brightness = 3
	light.Parent = pole
	local ring = Instance.new("Part")
	ring.Name = "FlareZone"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, B.Radius * 2, B.Radius * 2)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 120, 60)
	ring.Material = Enum.Material.ForceField
	ring.Parent = pole
	pole.Parent = hazards()
	beaconPart = pole
	ReplicatedStorage:SetAttribute(Attributes.BeaconAt, at)
	Remotes.get("Banner"):FireAllClients("EMERGENCY FLARE", string.format("Hold the flare for %ds for +%d coins — the God can see it!", B.HoldSeconds, B.Coins), Color3.fromRGB(255, 120, 60))
end

local function beaconTick(dt: number)
	local part = beaconPart
	if not (beaconOn and part and part.Parent) then
		return
	end
	local at = part.Position
	for _, player in RoleService.GetAliveSurvivors() do
		if claimed[player] then
			continue
		end
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - at).Magnitude <= B.Radius + 3 then
			holding[player] = (holding[player] or 0) + dt
			clientEffect:FireClient(player, "BeaconHold", math.clamp(holding[player] / B.HoldSeconds, 0, 1))
			if holding[player] >= B.HoldSeconds then
				claimed[player] = true
				ScoringService.Award(player, B.Coins, "BEACON SECURED", Color3.fromRGB(255, 150, 60))
				Remotes.get("Feed"):FireAllClients(string.format("🔦 %s secured the Emergency Flare!", player.DisplayName), Color3.fromRGB(255, 150, 60))
				clientEffect:FireClient(player, "BeaconHold", -1)
			end
		elseif (holding[player] or 0) > 0 then
			holding[player] = 0
			clientEffect:FireClient(player, "BeaconHold", -1)
		end
	end
end

---------------------------------------------------------------------------

-- Roll the Chaos Twist for the coming round (call right after the vote closes).
function MutatorService.Roll(): string
	active = ""
	local forced = workspace:GetAttribute("ForceMutator") -- Studio testing
	if typeof(forced) == "string" and def(forced) then
		active = forced
	elseif rng:NextNumber() < MU.Chance then
		active = MU.Pool[rng:NextInteger(1, #MU.Pool)].Id
	end
	ReplicatedStorage:SetAttribute(Attributes.Mutator, active)
	return active
end

function MutatorService.Get(): string
	return active
end

function MutatorService.BeginRound()
	roundOn = true
	dropped = false
	beaconOn = false
	table.clear(holding)
	table.clear(claimed)
	if active == "TwilightStorm" then
		EnvironmentService.SetMood("Twilight", 3)
	end
	if active == "GoldRush" then
		task.spawn(function()
			while roundOn and active == "GoldRush" do
				task.wait(MU.GoldRushInterval)
				if roundOn and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) == true then
					goldRushWave()
				end
			end
		end)
	end
end

-- Called every match tick with the seconds left and the round length.
function MutatorService.Update(timeRemaining: number, duration: number, dt: number)
	if not roundOn then
		return
	end
	if active == "AirDrops" and not dropped and timeRemaining <= duration / 2 then
		dropped = true
		airDrop()
	end
	if not beaconOn and timeRemaining <= B.StartAt and timeRemaining > 3 then
		startBeacon()
	end
	beaconTick(dt)
end

-- Everything off: pickups gone, the flare out, the twist cleared.
function MutatorService.EndRound()
	roundOn = false
	beaconOn = false
	if beaconPart then
		beaconPart:Destroy()
		beaconPart = nil
	end
	for _, p in pickups do
		if p.Parent then
			p:Destroy()
		end
	end
	table.clear(pickups)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Attributes.ShieldCharges, nil)
		player:SetAttribute(Attributes.SpeedUntil, nil)
	end
	ReplicatedStorage:SetAttribute(Attributes.BeaconAt, nil)
	active = ""
	ReplicatedStorage:SetAttribute(Attributes.Mutator, "")
end

function MutatorService.Init()
	ReplicatedStorage:SetAttribute(Attributes.Mutator, "")
	Players.PlayerRemoving:Connect(function(player)
		holding[player] = nil
		claimed[player] = nil
	end)
end

return MutatorService
