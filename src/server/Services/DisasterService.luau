--!strict
-- DisasterService: Chaos Energy economy, ability validation (per God kit), telegraphs,
-- the disasters, the Seismic Ping, the AI Director (plays God when no human does),
-- anti-camp radar (outdoors only) and the end-of-round Hunter's Pulse.
-- World / disaster interactions live in ComboService, hiding in StealthService.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Loadout = require(ReplicatedStorage.Shared.Loadout)

local ComboService = require(script.Parent.ComboService)
local CosmeticService = require(script.Parent.CosmeticService)
local DestructionService = require(script.Parent.DestructionService)
local EnvironmentService = require(script.Parent.EnvironmentService)
local MapService = require(script.Parent.MapService)
local RoleService = require(script.Parent.RoleService)
local SaveService = require(script.Parent.SaveService)
local ScoringService = require(script.Parent.ScoringService)
local StealthService = require(script.Parent.StealthService)

type Ability = Types.AbilityDefinition
type Pool = { Energy: number, Ready: { [string]: number } }

local Attributes = Config.Attributes
local Chaos = Config.Chaos

local AudioService = require(script.Parent.AudioService)
local RagdollService = require(script.Parent.RagdollService)

local RED = Color3.fromRGB(255, 50, 50)
local ORANGE = Color3.fromRGB(255, 140, 30)
local PURPLE = Color3.fromRGB(170, 90, 255)

local DisasterService = {}

local abilities: { [string]: Ability } = {}
for _, def in Config.Disasters.Abilities do
	abilities[def.Id] = def
end

local state = {
	Active = false,
	CastingOpen = false,
	SuddenDeath = false,
	HunterPulse = false,
	God = nil :: Player?,
}
local pools: { [any]: Pool } = {}
local DIRECTOR = "Director"

local clientEffect = Remotes.get("ClientEffect")

---------------------------------------------------------------------------
-- helpers

local function hazards(): Folder
	return MapService.GetHazardsFolder()
end

local function fxPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	-- shape first: changing Shape after Size can resize the part
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = hazards()
	return p
end

-- Positional one-shot from Config.Audio.Disaster (key), e.g. "Thunder".
local function sound(key: string, at: Vector3, volume: number, speed: number?)
	AudioService.playAt(key, at, volume, speed)
end

local function shakeAll(intensity: number, duration: number, center: Vector3?)
	clientEffect:FireAllClients("Shake", intensity, duration, center)
end

local function hrpAndHumanoid(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

-- `cause` names what hit them for the kill feed ("Meteors", "Tornado", ...).
local function hurt(player: Player, damage: number, caster: Player?, cause: string?)
	local _, humanoid = hrpAndHumanoid(player)
	if humanoid and humanoid.Health > 0 and damage > 0 then
		ScoringService.NoteHit(player, caster, cause)
		if not SaveService.AllowHit(player, humanoid, damage) then
			return -- mercy window after a hit, or a panic save absorbed a fatal one
		end
		humanoid:TakeDamage(damage)
	end
end

local function knock(player: Player, velocity: Vector3)
	local info = MapService.GetCurrent()
	local mult = if info and info.KnockbackMultiplier then info.KnockbackMultiplier else 1
	local hrp = hrpAndHumanoid(player)
	if hrp then
		mult *= ComboService.KnockbackScale(hrp.Position) -- slippery puddles
	end
	local v = velocity * mult
	-- a hard enough hit sends the survivor tumbling as a ragdoll
	if v.Magnitude >= Config.Ragdoll.MinKnockback then
		RagdollService.Stun(player, Config.Ragdoll.Duration)
	end
	clientEffect:FireClient(player, "Knockback", v)
end

-- Hurt + optionally knock back survivors in a sphere; near-miss everyone just outside.
local function blast(center: Vector3, radius: number, damage: number, caster: Player?, knockback: number?, cause: string?)
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp then
			local offset = hrp.Position - center
			if offset.Magnitude <= radius + 1.5 then
				hurt(player, damage, caster, cause)
				if knockback then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
					knock(player, dir * knockback + Vector3.new(0, knockback * 0.5, 0))
				end
			end
		end
	end
	ScoringService.CheckNearMiss(center, radius, cause)
end

-- God combos (Config.GodCombo): destructive hits from *different* disasters chained
-- within a few seconds pay bonus Chaos Energy and coins, so mixing powers beats spamming.
local GC = Config.GodCombo
local lastCastId: { [Player]: string } = {}
local chains: { [Player]: { At: number, Ids: { [string]: boolean }, Links: number } } = {}
local bonusEnergy: (Player, number) -> () -- set below once pools exist

local function comboLink(caster: Player)
	local id = lastCastId[caster]
	if not id then
		return
	end
	local now = os.clock()
	local chain = chains[caster]
	if not chain or now - chain.At > GC.Window then
		chain = { At = now, Ids = {}, Links = 0 }
		chains[caster] = chain
	end
	chain.At = now
	if chain.Ids[id] then
		return
	end
	chain.Ids[id] = true
	chain.Links += 1
	if chain.Links >= 2 then
		local links = math.min(chain.Links, GC.MaxLinks)
		local energy = GC.EnergyPerLink * (links - 1)
		bonusEnergy(caster, energy)
		ScoringService.Award(caster, GC.CoinsPerLink * (links - 1), string.format("COMBO x%d (+%d ENERGY)", links, energy), Color3.fromRGB(255, 200, 60))
	end
end

local function creditDestruction(caster: Player?, count: number)
	ScoringService.RecordDestruction(caster, count)
	if caster and count >= 6 then
		ScoringService.Notify(caster, string.format("DESTRUCTION x%d", count), ORANGE)
	end
	if caster and count >= GC.MinParts then
		comboLink(caster)
	end
end

---------------------------------------------------------------------------
-- telegraphs

local function ringTelegraph(center: Vector3, radius: number, duration: number, color: Color3)
	local cf = CFrame.new(center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local outer = fxPart({
		Name = "Telegraph",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = cf,
		Color = color,
		Transparency = 0.55,
	})
	local inner = fxPart({
		Name = "TelegraphFill",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 0.5, 0.5),
		CFrame = cf * CFrame.new(0.05, 0, 0),
		Color = color,
		Transparency = 0.25,
	})
	-- inner disc grows to the edge as the countdown to impact
	TweenService:Create(inner, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(0.3, radius * 2, radius * 2) }):Play()
	TweenService:Create(outer, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.15 }):Play()
	Debris:AddItem(outer, duration + 0.05)
	Debris:AddItem(inner, duration + 0.05)
	sound("Warning", center, 0.7)
end

local function lineTelegraph(cframe: CFrame, length: number, width: number, duration: number)
	local outer = fxPart({
		Name = "Telegraph",
		Size = Vector3.new(width, 0.2, length),
		CFrame = cframe + Vector3.new(0, 0.25, 0),
		Color = RED,
		Transparency = 0.55,
	})
	local inner = fxPart({
		Name = "TelegraphFill",
		Size = Vector3.new(width * 0.95, 0.3, 0.5),
		CFrame = cframe + Vector3.new(0, 0.3, 0),
		Color = RED,
		Transparency = 0.25,
	})
	TweenService:Create(inner, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(width * 0.95, 0.3, length) }):Play()
	TweenService:Create(outer, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.15 }):Play()
	Debris:AddItem(outer, duration + 0.05)
	Debris:AddItem(inner, duration + 0.05)
	sound("Warning", cframe.Position, 1, 0.8)
	sound("Rumble", cframe.Position, 1.6)
end

---------------------------------------------------------------------------
-- disasters

-- One bolt: visuals, sound, structure damage and the blast. No telegraph.
local function strike(def: Ability, ground: Vector3, caster: Player?)
	local bolt = CosmeticService.VfxOf(caster).Bolt or Color3.fromRGB(200, 235, 255)
	-- jagged bolt from the sky
	local top = ground + Vector3.new(0, 140, 0)
	local prev = top
	for i = 1, 7 do
		local t = i / 7
		local nextPoint = if i == 7 then ground else top:Lerp(ground, t) + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		local seg = fxPart({
			Name = "Bolt",
			Size = Vector3.new(1.2, 1.2, (nextPoint - prev).Magnitude),
			CFrame = CFrame.lookAt((prev + nextPoint) / 2, nextPoint),
			Color = bolt,
		})
		Debris:AddItem(seg, 0.3)
		prev = nextPoint
	end
	local flash = fxPart({ Name = "Flash", Shape = Enum.PartType.Ball, Size = Vector3.one * def.Radius * 2, CFrame = CFrame.new(ground), Color = Color3.fromRGB(220, 240, 255), Transparency = 0.3 })
	local light = Instance.new("PointLight")
	light.Brightness = 8
	light.Range = 60
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.45)
	sound("Lightning", ground, 2.2)
	sound("Thunder", ground, 1.6, 0.9 + math.random() * 0.2)
	shakeAll(0.5, 0.3, ground)
	creditDestruction(caster, DestructionService.DamageArea(ground, def.Radius, def.StructureDamage))
	blast(ground, def.Radius, def.PlayerDamage, caster, 30, def.DisplayName)
	-- conducts through nearby metal, the rising water and puddles
	ComboService.Electrify(ground, def.Radius, caster)
end

local BOLT_BLUE = Color3.fromRGB(120, 200, 255)

local function lightning(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, CosmeticService.VfxOf(caster).Telegraph or BOLT_BLUE)
	task.wait(def.WarningTime)
	strike(def, ground, caster)
end

-- Storm Deity: the bolt hops between the nearest survivors.
local function chainLightning(def: Ability, ground: Vector3, caster: Player?)
	local tele = CosmeticService.VfxOf(caster).Telegraph or BOLT_BLUE
	ringTelegraph(ground, def.Radius, def.WarningTime, tele)
	task.wait(def.WarningTime)
	strike(def, ground, caster)
	local pos = ground
	local hop = def.Duration or 0.6
	local range = def.Length or 45
	local targeted: { [Player]: boolean } = {}
	for _ = 2, def.Count or 4 do
		local nextPos: Vector3? = nil
		local best = range
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpAndHumanoid(player)
			if hrp and not targeted[player] then
				local d = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z).Magnitude
				if d <= best and d > 2 then
					best = d
					nextPos = hrp.Position
					targeted[player] = true
				end
			end
		end
		if not nextPos then
			local a = math.random() * math.pi * 2
			nextPos = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * range * 0.4
		end
		local target = MapService.GroundAt(nextPos :: Vector3)
		-- crackling arc along the ground toward the next strike
		local arc = fxPart({
			Name = "Arc",
			Size = Vector3.new(0.6, 0.6, math.max(1, (target - pos).Magnitude)),
			CFrame = CFrame.lookAt((pos + target) / 2 + Vector3.new(0, 2, 0), target + Vector3.new(0, 2, 0)),
			Color = Color3.fromRGB(200, 235, 255),
			Transparency = 0.2,
		})
		TweenService:Create(arc, TweenInfo.new(hop), { Transparency = 1 }):Play()
		Debris:AddItem(arc, hop + 0.05)
		ringTelegraph(target, def.Radius, hop, tele)
		task.wait(hop)
		strike(def, target, caster)
		pos = target
	end
end

-- Magma Titan: a burst that leaves a burning lava pool behind.
local function eruption(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, ORANGE)
	shakeAll(0.2, def.WarningTime, ground)
	task.wait(def.WarningTime)
	sound("Explosion", ground, 2.4, 0.8)
	shakeAll(1, 0.6, ground)
	creditDestruction(caster, DestructionService.DamageArea(ground, def.Radius, def.StructureDamage))
	blast(ground, def.Radius, def.PlayerDamage, caster, def.Knockback, def.DisplayName)
	local duration = def.Duration or 6
	-- the pool counts as fire: a tornado through it becomes a firenado, a puddle puts it out
	local fire = ComboService.AddFire(ground, def.Radius, duration)
	local pool = fxPart({
		Name = "LavaPool",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, def.Radius * 2, def.Radius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = CosmeticService.VfxOf(caster).Lava or Color3.fromRGB(255, 110, 20),
		Transparency = 0.15,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 130, 40)
	light.Range = def.Radius * 2.5
	light.Brightness = 3
	light.Parent = pool
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local base = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * def.Radius * 0.5
		local glob = fxPart({ Name = "Magma", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, CFrame = CFrame.new(base), Color = Color3.fromRGB(255, 80, 20) })
		TweenService:Create(glob, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(base + Vector3.new(0, 26 + i * 2, 0)),
			Transparency = 1,
		}):Play()
		Debris:AddItem(glob, 1)
	end
	local elapsed = 0
	while elapsed < duration and state.Active and ComboService.IsBurning(fire) do
		task.wait(0.5)
		elapsed += 0.5
		creditDestruction(caster, DestructionService.DamageArea(ground, def.Radius * 0.8, def.StructureDamage * 0.15))
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpAndHumanoid(player)
			if hrp then
				local d = hrp.Position - ground
				if Vector3.new(d.X, 0, d.Z).Magnitude <= def.Radius and d.Y > -4 and d.Y < 12 then
					hurt(player, def.TickDamage or 10, caster, "Lava")
				end
			end
		end
	end
	TweenService:Create(pool, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	Debris:AddItem(pool, 0.85)
end

-- Cyber Glitch: reality stutters — survivors are flung straight up, glass and props break.
local GLITCH_COLORS = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 230, 255), Color3.fromRGB(120, 255, 90) }

local function glitch(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, GLITCH_COLORS[1])
	task.wait(def.WarningTime)
	sound("Glass", ground, 2, 0.5)
	sound("Lightning", ground, 1.4, 1.9)
	shakeAll(0.6, 0.3, ground)
	for i = 1, 16 do
		local r = def.Radius * math.sqrt(math.random())
		local a = math.random() * math.pi * 2
		local cube = fxPart({
			Name = "Glitch",
			Size = Vector3.new(math.random(2, 5), math.random(1, 4), math.random(2, 5)),
			CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * r, math.random(1, 14), math.sin(a) * r)),
			Color = GLITCH_COLORS[i % #GLITCH_COLORS + 1],
			Transparency = 0.2,
		})
		TweenService:Create(cube, TweenInfo.new(0.5, Enum.EasingStyle.Bounce), { Transparency = 1, Size = cube.Size * 0.2 }):Play()
		Debris:AddItem(cube, 0.55)
	end
	creditDestruction(caster, DestructionService.DamageArea(ground, def.Radius, def.StructureDamage))
	local k = def.Knockback or 70
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp and (hrp.Position - ground).Magnitude <= def.Radius + 1.5 then
			hurt(player, def.PlayerDamage, caster, def.DisplayName)
			local a = math.random() * math.pi * 2
			knock(player, Vector3.new(math.cos(a) * k * 0.3, k, math.sin(a) * k * 0.3))
		end
	end
	ScoringService.CheckNearMiss(ground, def.Radius, def.DisplayName)
end

local function gust(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, Color3.fromRGB(220, 240, 255))
	task.wait(def.WarningTime)
	sound("Gust", ground, 2.4, 0.8)
	for i = 1, 10 do
		local r = math.floor(def.Radius)
		local offset = Vector3.new(math.random(-r, r), math.random(2, 12), math.random(-r, r))
		local start = ground + offset - dir * def.Radius
		local streak = fxPart({
			Name = "Wind",
			Size = Vector3.new(0.4, 0.4, 14),
			CFrame = CFrame.lookAt(start, start + dir),
			Color = Color3.fromRGB(240, 250, 255),
			Transparency = 0.35,
		})
		TweenService:Create(streak, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, i * 0.03), {
			CFrame = CFrame.lookAt(start + dir * def.Radius * 2.5, start + dir * def.Radius * 3),
			Transparency = 1,
		}):Play()
		Debris:AddItem(streak, 1.2)
	end
	creditDestruction(caster, DestructionService.DamageArea(ground, def.Radius * 0.6, def.StructureDamage))
	local k = def.Knockback or 80
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp and (hrp.Position - ground).Magnitude <= def.Radius then
			hurt(player, def.PlayerDamage, caster, def.DisplayName)
			knock(player, dir * k + Vector3.new(0, 28, 0))
		end
	end
	ScoringService.CheckNearMiss(ground, def.Radius, def.DisplayName)
end

local function meteors(def: Ability, ground: Vector3, caster: Player?)
	local pal = CosmeticService.VfxOf(caster)
	ringTelegraph(ground, def.Radius, def.WarningTime, pal.Telegraph or ORANGE)
	EnvironmentService.Darken(def.WarningTime + 2)
	task.wait(def.WarningTime * 0.6)
	local count = def.Count or 5
	local impact = def.ImpactRadius or 10
	for i = 1, count do
		local r = def.Radius * math.sqrt(math.random())
		local a = math.random() * math.pi * 2
		local point = MapService.GroundAt(ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		task.spawn(function()
			ringTelegraph(point, impact, 0.9, pal.Telegraph or RED)
			local from = point + Vector3.new(40, 130, 30)
			local rock = fxPart({
				Name = "Meteor",
				Shape = pal.MeteorShape or Enum.PartType.Ball,
				Size = Vector3.one * 7,
				CFrame = CFrame.new(from),
				Color = pal.Meteor or Color3.fromRGB(255, 90, 30),
			})
			local fire = Instance.new("Fire")
			fire.Size = 12
			fire.Heat = 20
			fire.Parent = rock
			AudioService.attach("MeteorFall", rock, 2.2, false, 0.7)
			local tween = TweenService:Create(rock, TweenInfo.new(0.9, Enum.EasingStyle.Linear), { CFrame = CFrame.new(point) })
			tween:Play()
			tween.Completed:Wait()
			rock:Destroy()
			local boom = Instance.new("Explosion")
			boom.Position = point
			boom.BlastRadius = impact
			boom.BlastPressure = 0
			boom.DestroyJointRadiusPercent = 0
			boom.Parent = workspace
			sound("MeteorImpact", point, 2.2, 0.85 + math.random() * 0.3)
			shakeAll(0.8, 0.4, point)
			creditDestruction(caster, DestructionService.DamageArea(point, impact, def.StructureDamage))
			blast(point, impact, def.PlayerDamage, caster, 45, def.DisplayName)
		end)
		task.wait(0.28)
	end
end

-- `steered` (Maelstrom Vortex): follows the God's reticle instead of chasing survivors,
-- puts out fires and hurls the rubble it gathers outward.
local function tornado(def: Ability, ground: Vector3, dir: Vector3, caster: Player?, steered: boolean?)
	ringTelegraph(ground, def.Radius, def.WarningTime, Color3.fromRGB(200, 200, 210))
	EnvironmentService.Darken(def.WarningTime + (def.Duration or 8))
	task.wait(def.WarningTime)

	local funnel = Instance.new("Model")
	funnel.Name = "Tornado"
	funnel.Parent = hazards()
	local rings: { { Part: Part, Height: number } } = {}
	for i = 1, 8 do
		local width = 6 + i * 3.2
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(7, width, width)
		p.Material = Enum.Material.SmoothPlastic
		local tint = CosmeticService.VfxOf(caster).Tornado
		p.Color = if tint then tint:Lerp(Color3.new(1, 1, 1), i * 0.05) else Color3.fromRGB(120 + i * 6, 120 + i * 6, 130 + i * 6)
		p.Transparency = 0.35 + i * 0.04
		p.Parent = funnel
		table.insert(rings, { Part = p, Height = i * 6.5 })
	end
	AudioService.attach("Tornado", rings[2].Part, 3, true)

	local pos = ground
	local heading = dir
	local speed = def.Speed or 16
	local duration = def.Duration or 8
	local elapsed = 0
	local tickTimer = 0
	local playerTimer = 0
	local spin = 0
	local radius = def.Radius
	local burning = false -- caught fire from a lava pool / burning patch: a firenado
	local dropTimer = 0
	local conn: RBXScriptConnection
	local finished = Instance.new("BindableEvent")

	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		spin += dt * 6
		-- chase the nearest survivor (keeps hiding spots under pressure)
		local nearest: Vector3? = nil
		local best = 140
		local aim = if steered then ReplicatedStorage:GetAttribute(Attributes.GodAim) else nil
		if typeof(aim) == "Vector3" then
			local flat = Vector3.new(aim.X - pos.X, 0, aim.Z - pos.Z)
			nearest = flat
			best = -1 -- the reticle wins
		end
		for _, player in RoleService.GetAliveSurvivors() do
			if best < 0 then
				break
			end
			local hrp = hrpAndHumanoid(player)
			if hrp then
				local flat = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
				if flat.Magnitude < best then
					best = flat.Magnitude
					nearest = flat
				end
			end
		end
		if nearest and nearest.Magnitude > 1 then
			heading = heading:Lerp(nearest.Unit, math.min(1, dt * (if steered then 2.5 else 0.8))).Unit
		end
		local nextPos = pos + heading * speed * dt
		if not MapService.InBounds(nextPos) then
			heading = -heading
			nextPos = pos
		end
		pos = MapService.GroundAt(nextPos)
		for i, ring in rings do
			local wobble = Vector3.new(math.sin(spin + i) * i * 0.4, 0, math.cos(spin + i) * i * 0.4)
			ring.Part.CFrame = CFrame.new(pos + Vector3.new(0, ring.Height, 0) + wobble) * CFrame.Angles(0, spin * (1 + i * 0.1), math.rad(90))
		end

		tickTimer += dt
		if tickTimer >= 0.25 then
			tickTimer = 0
			-- a column of wind: rips the ground floor and the floors above it
			creditDestruction(caster, DestructionService.DamageArea(pos + Vector3.new(0, 8, 0), radius, def.StructureDamage * 0.25))
			creditDestruction(caster, DestructionService.DamageArea(pos + Vector3.new(0, 24, 0), radius * 0.8, def.StructureDamage * 0.18))
			if steered then
				if ComboService.Extinguish(pos, radius) > 0 then
					sound("Gust", pos, 1.4, 0.7)
				end
			elseif not burning and ComboService.FireNear(pos, radius) then
				burning = true
				for i, ring in rings do
					ring.Part.Color = Color3.fromRGB(255, 120 - i * 8, 30)
					ring.Part.Material = Enum.Material.Neon
				end
				sound("Explosion", pos, 1.8, 0.7)
				if caster then
					ScoringService.Notify(caster, "🔥 COMBO: FIRENADO!", ORANGE)
				end
			end
			local fling = steered and math.random() < 0.25
			for _, part in DestructionService.GetDebrisNear(pos, radius * 1.8) do
				local offset = part.Position - pos
				local tangent = Vector3.new(-offset.Z, 0, offset.X)
				if fling and tangent.Magnitude > 0.1 then
					-- the Maelstrom hurls its rubble out like projectiles
					part.AssemblyLinearVelocity = Vector3.new(offset.X, 0, offset.Z).Unit * 85 + Vector3.new(0, 30, 0)
				elseif tangent.Magnitude > 0.1 then
					part.AssemblyLinearVelocity = tangent.Unit * 40 - Vector3.new(offset.X, 0, offset.Z) * 0.6 + Vector3.new(0, 35, 0)
				end
			end
		end
		if burning then
			dropTimer += dt
			if dropTimer >= Config.Combos.FireDropInterval then
				dropTimer = 0
				ComboService.DropFire(pos, caster)
			end
		end
		playerTimer += dt
		if playerTimer >= 0.5 then
			playerTimer = 0
			local k = def.Knockback or 60
			for _, player in RoleService.GetAliveSurvivors() do
				local hrp = hrpAndHumanoid(player)
				if hrp then
					local offset = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
					if offset.Magnitude <= radius and hrp.Position.Y - pos.Y < 50 then
						hurt(player, def.TickDamage or 8, caster, if burning then "Firenado" else def.DisplayName)
						local tangent = if offset.Magnitude > 0.1 then Vector3.new(-offset.Z, 0, offset.X).Unit else Vector3.xAxis
						knock(player, tangent * k * 0.6 + Vector3.new(0, k, 0))
					end
				end
			end
		end
		if elapsed >= duration then
			conn:Disconnect()
			finished:Fire()
		end
	end)
	finished.Event:Wait()
	for _, ring in rings do
		TweenService:Create(ring.Part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end
	Debris:AddItem(funnel, 0.7)
	finished:Destroy()
end

local function faultCleave(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
	local length = def.Length or 100
	local width = def.Width or 8
	-- the fault runs along the bedrock, not the rooftop the reticle landed on
	ground = MapService.TerrainAt(ground)
	local cf = CFrame.lookAt(ground, ground + dir)
	lineTelegraph(cf, length, width, def.WarningTime)
	EnvironmentService.Darken(def.WarningTime + 1.5)
	shakeAll(0.15, def.WarningTime, ground)
	task.wait(def.WarningTime)

	sound("Collapse", ground, 3, 0.75)
	sound("Debris", ground, 2.2)
	shakeAll(1.4, 0.9, ground)
	-- glowing crack + heaved rock chunks along the line
	local crack = fxPart({ Name = "Crack", Size = Vector3.new(2, 0.6, length), CFrame = cf + Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(255, 110, 30) })
	TweenService:Create(crack, TweenInfo.new(3), { Transparency = 1 }):Play()
	Debris:AddItem(crack, 3.1)
	for i = 1, 10 do
		local along = (i / 10 - 0.5) * length
		local chunk = fxPart({
			Name = "Chunk",
			Material = Enum.Material.Slate,
			Size = Vector3.new(math.random(3, 6), math.random(2, 5), math.random(3, 6)),
			CFrame = cf * CFrame.new(math.random(-3, 3), 1, along) * CFrame.Angles(math.random(), math.random(), math.random()),
			Color = Color3.fromRGB(90, 80, 75),
		})
		chunk.CanCollide = true
		TweenService:Create(chunk, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.5), { Transparency = 1 }):Play()
		Debris:AddItem(chunk, 3.2)
	end

	-- tall enough to shear every support standing on the line
	local boxCf = cf * CFrame.new(0, 20, 0)
	local boxSize = Vector3.new(width, 50, length)
	creditDestruction(caster, DestructionService.DamageBox(boxCf, boxSize, def.StructureDamage))
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp then
			local localPos = boxCf:PointToObjectSpace(hrp.Position)
			if math.abs(localPos.X) <= width / 2 + 1 and math.abs(localPos.Y) <= boxSize.Y / 2 and math.abs(localPos.Z) <= length / 2 then
				hurt(player, def.PlayerDamage, caster, def.DisplayName)
				knock(player, Vector3.new(0, 55, 0) + cf.RightVector * (if localPos.X >= 0 then 25 else -25))
			elseif math.abs(localPos.X) <= width / 2 + Config.Scoring.NearMissMargin and math.abs(localPos.Z) <= length / 2 then
				ScoringService.Award(player, Config.Scoring.NearMissCoins, "NEAR MISS", Color3.fromRGB(90, 230, 255))
				ScoringService.GetRecord(player).NearMisses += 1
			end
		end
	end
end

-- Every God's scouting tool: survivors in range show through walls for a moment.
local function seismicPing(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, PURPLE)
	task.wait(def.WarningTime)
	sound("Rumble", ground, 1.4, 1.4)
	local wave = fxPart({
		Name = "SeismicWave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 4, 4),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE,
		Transparency = 0.3,
	})
	TweenService:Create(wave, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, def.Radius * 2, def.Radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(wave, 0.85)
	local found = StealthService.Reveal(ground, def.Radius, def.Duration or 2, caster)
	if caster then
		ScoringService.Notify(caster, if found > 0 then string.format("📡 PING: %d FOUND", found) else "📡 PING: NOTHING NEARBY", PURPLE)
	end
end

---------------------------------------------------------------------------
-- big-map disasters (Cataclysm kit) and God Pack signatures

local VOID = Color3.fromRGB(120, 60, 255)
local CYBER = Color3.fromRGB(60, 230, 255)
local WOOD_SCALE: { [Enum.Material]: number } = { [Enum.Material.Wood] = 2, [Enum.Material.WoodPlanks] = 2 }
local METAL_SCALE: { [Enum.Material]: number } = { [Enum.Material.Metal] = 1.5, [Enum.Material.DiamondPlate] = 1.5, [Enum.Material.CorrodedMetal] = 1.5 }

-- One meteor falling onto `point` (Meteor Barrage): short fall, impact, blast.
local function dropMeteor(def: Ability, point: Vector3, caster: Player?, fall: number)
	local pal = CosmeticService.VfxOf(caster)
	local impact = def.ImpactRadius or 9
	local rock = fxPart({
		Name = "Meteor",
		Shape = pal.MeteorShape or Enum.PartType.Ball,
		Size = Vector3.one * 6,
		CFrame = CFrame.new(point + Vector3.new(25, 110, 15)),
		Color = pal.Meteor or Color3.fromRGB(255, 90, 30),
	})
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 18
	fire.Parent = rock
	local tween = TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Linear), { CFrame = CFrame.new(point) })
	tween:Play()
	tween.Completed:Wait()
	rock:Destroy()
	local boom = Instance.new("Explosion")
	boom.Position = point
	boom.BlastRadius = impact
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace
	sound("MeteorImpact", point, 2, 0.9 + math.random() * 0.3)
	shakeAll(0.6, 0.3, point)
	creditDestruction(caster, DestructionService.DamageArea(point, impact, def.StructureDamage))
	blast(point, impact, def.PlayerDamage, caster, 40, def.DisplayName)
end

-- Meteor Barrage: a rolling line of impacts along the God's facing (carpet sweep).
local function meteorBarrage(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
	local length = def.Length or 80
	local cf = CFrame.lookAt(ground, ground + dir)
	lineTelegraph(cf, length, def.Width or 12, def.WarningTime)
	task.wait(def.WarningTime * 0.55)
	local count = def.Count or 7
	for i = 1, count do
		local along = length / 2 - length * (i - 0.5) / count
		local point = MapService.GroundAt((cf * CFrame.new(math.random(-2, 2), 0, along)).Position)
		task.spawn(dropMeteor, def, point, caster, 0.6)
		task.wait(def.Duration or 0.18)
	end
end

-- Gravity Singularity / Astral Collapse: survivors and loose debris are dragged toward a
-- point for a moment, then it detonates. Astral Collapse throws everything skyward and
-- leaves the rubble floating.
local function singularity(def: Ability, ground: Vector3, caster: Player?, astral: boolean)
	local center = ground + Vector3.new(0, 4, 0)
	local tint = if astral then Color3.fromRGB(255, 215, 120) else (CosmeticService.VfxOf(caster).Telegraph or VOID)
	ringTelegraph(ground, def.Radius, def.WarningTime, tint)
	task.wait(def.WarningTime)
	local core = fxPart({ Name = "Singularity", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(center), Color = Color3.fromRGB(10, 6, 20), Material = Enum.Material.SmoothPlastic })
	local halo = fxPart({ Name = "EventHorizon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10, 10), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = tint, Transparency = 0.3 })
	TweenService:Create(core, TweenInfo.new(def.Duration or 2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 9 }):Play()
	TweenService:Create(halo, TweenInfo.new(def.Duration or 2.5), { Size = Vector3.new(0.4, def.Radius * 1.6, def.Radius * 1.6), Transparency = 0.7 }):Play()
	AudioService.attach("Tornado", core, 2.2, true, 0.6)
	shakeAll(0.3, def.Duration or 2.5, center)
	local pull = def.Pull or 36
	local elapsed = 0
	local duration = def.Duration or 2.5
	while elapsed < duration do
		local dt = task.wait(0.12)
		elapsed += dt
		halo.CFrame = CFrame.new(center) * CFrame.Angles(elapsed * 3, 0, math.rad(90))
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpAndHumanoid(player)
			if hrp then
				local offset = center - hrp.Position
				if offset.Magnitude <= def.Radius and offset.Magnitude > 3 then
					-- a steady drag (below ragdoll strength): sprint or dash out of it
					clientEffect:FireClient(player, "Knockback", offset.Unit * pull + Vector3.new(0, 6, 0))
				end
			end
		end
		for _, part in DestructionService.GetDebrisNear(center, def.Radius) do
			local offset = center - part.Position
			if offset.Magnitude > 2 then
				part.AssemblyLinearVelocity = offset.Unit * pull * 1.2
			end
		end
	end
	core:Destroy()
	halo:Destroy()
	local impact = def.ImpactRadius or 16
	local burst = fxPart({ Name = "Detonation", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, CFrame = CFrame.new(center), Color = tint, Transparency = 0.2 })
	TweenService:Create(burst, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.one * impact * 2.4, Transparency = 1 }):Play()
	Debris:AddItem(burst, 0.5)
	sound("Explosion", center, 2.6, if astral then 0.6 else 0.8)
	shakeAll(1.1, 0.5, center)
	creditDestruction(caster, DestructionService.DamageArea(center, impact, def.StructureDamage))
	local k = def.Knockback or 70
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp then
			local offset = hrp.Position - center
			if offset.Magnitude <= impact + 1.5 then
				hurt(player, def.PlayerDamage, caster, def.DisplayName)
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local out = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
				knock(player, if astral then out * k * 0.25 + Vector3.new(0, k, 0) else out * k + Vector3.new(0, k * 0.45, 0))
			end
		end
	end
	ScoringService.CheckNearMiss(center, impact, def.DisplayName)
	for _, part in DestructionService.GetDebrisNear(center, impact * 1.6) do
		local offset = part.Position - center
		local out = if offset.Magnitude > 0.1 then offset.Unit else Vector3.yAxis
		part.AssemblyLinearVelocity = if astral then Vector3.new(out.X * 12, 70, out.Z * 12) else out * 70 + Vector3.new(0, 25, 0)
		if astral then
			-- low-gravity float: the rubble hangs in the air before drifting down
			local attachment = Instance.new("Attachment")
			attachment.Parent = part
			local float = Instance.new("VectorForce")
			float.Attachment0 = attachment
			float.RelativeTo = Enum.ActuatorRelativeTo.World
			float.Force = Vector3.new(0, part:GetMass() * workspace.Gravity * 0.8, 0)
			float.Parent = part
			Debris:AddItem(float, 3)
			Debris:AddItem(attachment, 3)
		end
	end
end

-- Tectonic Spire: rock pillars burst up from the bedrock, through every floor above.
local function tectonicSpire(def: Ability, ground: Vector3, caster: Player?)
	ground = MapService.TerrainAt(ground)
	ringTelegraph(ground, def.Radius, def.WarningTime, Color3.fromRGB(200, 120, 60))
	shakeAll(0.25, def.WarningTime, ground)
	task.wait(def.WarningTime)
	sound("Collapse", ground, 2.6, 0.7)
	sound("Rumble", ground, 2, 1.2)
	shakeAll(1.2, 0.6, ground)
	local count = def.Count or 5
	local height = def.Length or 46
	local hitPlayers: { [Player]: boolean } = {}
	for i = 1, count do
		local offset = if i == 1 then Vector3.zero else (function()
			local a = (i - 1) / (count - 1) * math.pi * 2 + math.random() * 0.6
			local d = def.Radius * (0.45 + math.random() * 0.45)
			return Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		end)()
		local base = MapService.TerrainAt(ground + offset)
		local w = math.random(5, 8)
		local h = height * (0.65 + math.random() * 0.35)
		local spire = fxPart({
			Name = "Spire",
			Size = Vector3.new(w, h, w),
			CFrame = CFrame.new(base - Vector3.new(0, h / 2 + 1, 0)) * CFrame.Angles(0, math.random() * 3, math.rad(math.random(-8, 8))),
			Color = Color3.fromRGB(110, 92, 80),
			Material = Enum.Material.Slate,
		})
		local up = spire.CFrame + Vector3.new(0, h, 0)
		TweenService:Create(spire, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = up }):Play()
		task.delay(0.3, function()
			if spire.Parent then
				spire.CanCollide = true
			end
		end)
		task.delay(4.5, function()
			if spire.Parent then
				spire.CanCollide = false
				TweenService:Create(spire, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = up - Vector3.new(0, h, 0), Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(spire, 6)
		-- smash straight up through every floor
		creditDestruction(caster, DestructionService.DamageBox(CFrame.new(base + Vector3.new(0, h / 2, 0)), Vector3.new(w + 3, h, w + 3), def.StructureDamage))
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpAndHumanoid(player)
			if hrp and not hitPlayers[player] then
				local flat = Vector3.new(hrp.Position.X - base.X, 0, hrp.Position.Z - base.Z)
				if flat.Magnitude <= w / 2 + 3 and hrp.Position.Y >= base.Y - 2 and hrp.Position.Y <= base.Y + h + 4 then
					hitPlayers[player] = true
					hurt(player, def.PlayerDamage, caster, def.DisplayName)
					knock(player, Vector3.new(0, def.Knockback or 95, 0) + (if flat.Magnitude > 0.1 then flat.Unit * 15 else Vector3.zero))
				end
			end
		end
		task.wait(0.08)
	end
	ScoringService.CheckNearMiss(ground, def.Radius, def.DisplayName)
end

-- Chain Arc: an energy bolt that jumps between survivors (through walls) or along metal.
local function arcFx(from: Vector3, to: Vector3, color: Color3, life: number)
	local prev = from
	for i = 1, 4 do
		local nextPoint = if i == 4 then to else from:Lerp(to, i / 4) + Vector3.new(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
		local seg = fxPart({ Name = "Arc", Size = Vector3.new(0.5, 0.5, math.max(0.5, (nextPoint - prev).Magnitude)), CFrame = CFrame.lookAt((prev + nextPoint) / 2, nextPoint), Color = color, Transparency = 0.1 })
		TweenService:Create(seg, TweenInfo.new(life), { Transparency = 1 }):Play()
		Debris:AddItem(seg, life + 0.05)
		prev = nextPoint
	end
end

local function chainArc(def: Ability, ground: Vector3, caster: Player?)
	local color = CosmeticService.VfxOf(caster).Bolt or CYBER
	ringTelegraph(ground, def.Radius, def.WarningTime, CosmeticService.VfxOf(caster).Telegraph or CYBER)
	task.wait(def.WarningTime)
	local hit: { [Player]: boolean } = {}
	local pos = ground + Vector3.new(0, 3, 0)
	local range = def.Length or 32
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { MapService.GetArenaFolder() }
	local function zap(at: Vector3, victim: Player?)
		sound("Lightning", at, 1.4, 1.4)
		creditDestruction(caster, DestructionService.DamageArea(at, def.Radius * 0.6, def.StructureDamage, METAL_SCALE))
		if victim then
			hurt(victim, def.PlayerDamage, caster, def.DisplayName)
			local hrp = hrpAndHumanoid(victim)
			if hrp then
				local flat = Vector3.new(hrp.Position.X - pos.X, 0, hrp.Position.Z - pos.Z)
				knock(victim, (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 25 + Vector3.new(0, 30, 0))
			end
		end
	end
	-- first strike: whoever is closest to the reticle
	local first: Player? = nil
	local best = def.Radius * 1.5
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp and (hrp.Position - pos).Magnitude <= best then
			best = (hrp.Position - pos).Magnitude
			first = player
		end
	end
	arcFx(pos + Vector3.new(0, 60, 0), pos, color, 0.3)
	if first then
		hit[first] = true
		local hrp = hrpAndHumanoid(first)
		if hrp then
			pos = hrp.Position
		end
	end
	zap(pos, first)
	for _ = 1, def.Count or 4 do
		task.wait(def.Duration or 0.25)
		local target: Vector3? = nil
		local victim: Player? = nil
		local nearest = range
		for _, player in RoleService.GetAliveSurvivors() do
			local hrp = hrpAndHumanoid(player)
			if hrp and not hit[player] and (hrp.Position - pos).Magnitude <= nearest then
				nearest = (hrp.Position - pos).Magnitude
				target = hrp.Position
				victim = player
			end
		end
		if not target then
			-- no one near: crawl along the nearest metal
			local bestMetal = range
			for _, part in workspace:GetPartBoundsInRadius(pos, range, params) do
				if part:GetAttribute("Structural") == true and METAL_SCALE[part.Material] and part:GetAttribute("Broken") ~= true then
					local d = (part.Position - pos).Magnitude
					if d > 6 and d < bestMetal then
						bestMetal = d
						target = part.Position
					end
				end
			end
		end
		if not target then
			break
		end
		if victim then
			hit[victim] = true
		end
		arcFx(pos, target :: Vector3, color, 0.35)
		pos = target :: Vector3
		zap(pos, victim)
	end
end

-- Pyroclast Surge (Magma Claw): a slow lava wave rolls along a line, igniting wood.
local function pyroclastSurge(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
	local length = def.Length or 100
	local width = def.Width or 12
	ground = MapService.TerrainAt(ground)
	local cf = CFrame.lookAt(ground, ground + dir)
	lineTelegraph(cf, length, width, def.WarningTime)
	EnvironmentService.Darken(def.WarningTime + 2)
	task.wait(def.WarningTime)
	local wave = fxPart({ Name = "LavaWave", Size = Vector3.new(width, 7, 6), CFrame = cf * CFrame.new(0, 3, length / 2), Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.CrackedLava })
	local glow = Instance.new("Fire")
	glow.Size = width
	glow.Heat = 12
	glow.Parent = wave
	AudioService.attach("Rumble", wave, 2.2, true, 0.7)
	local speed = def.Speed or 22
	local travelled = 0
	local tick = 0
	local fireTimer = 0
	local hit: { [Player]: boolean } = {}
	while travelled < length do
		local dt = task.wait()
		travelled = math.min(length, travelled + speed * dt)
		local at = cf * CFrame.new(0, 0, length / 2 - travelled)
		local ground2 = MapService.TerrainAt(at.Position)
		wave.CFrame = CFrame.lookAt(ground2, ground2 + dir) + Vector3.new(0, 3, 0)
		tick += dt
		fireTimer += dt
		if tick >= 0.2 then
			tick = 0
			creditDestruction(caster, DestructionService.DamageBox(CFrame.lookAt(ground2, ground2 + dir) + Vector3.new(0, 15, 0), Vector3.new(width, 30, 7), def.StructureDamage * 0.3, WOOD_SCALE))
			for _, player in RoleService.GetAliveSurvivors() do
				local hrp = hrpAndHumanoid(player)
				if hrp and not hit[player] then
					local rel = wave.CFrame:PointToObjectSpace(hrp.Position)
					if math.abs(rel.X) <= width / 2 + 1 and math.abs(rel.Z) <= 5 and rel.Y < 12 then
						hit[player] = true
						hurt(player, def.PlayerDamage, caster, def.DisplayName)
						knock(player, dir * 40 + Vector3.new(0, 55, 0))
					end
				end
			end
		end
		if fireTimer >= 0.9 then
			fireTimer = 0
			ComboService.DropFire(ground2, caster)
		end
	end
	TweenService:Create(wave, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	Debris:AddItem(wave, 0.65)
end

-- System Override (Cyber Gauntlet): an EMP burst. Survivors caught lose their dash and
-- get a scrambled screen for a few seconds.
local function systemOverride(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, CYBER)
	task.wait(def.WarningTime)
	local pulse = fxPart({ Name = "Emp", Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)), Color = CYBER, Transparency = 0.2 })
	TweenService:Create(pulse, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = Vector3.one * def.Radius * 2.2, Transparency = 1 }):Play()
	Debris:AddItem(pulse, 0.45)
	sound("Glass", ground, 2, 0.5)
	sound("Lightning", ground, 1.6, 1.8)
	shakeAll(0.5, 0.3, ground)
	creditDestruction(caster, DestructionService.DamageArea(ground, def.Radius, def.StructureDamage, METAL_SCALE))
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp and (hrp.Position - ground).Magnitude <= def.Radius + 1.5 then
			clientEffect:FireClient(player, "Emp", def.Duration or 3)
		end
	end
	blast(ground, def.Radius, def.PlayerDamage, caster, 25, def.DisplayName)
end

local function execute(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
	if def.Id == "SeismicPing" then
		seismicPing(def, ground, caster)
	elseif def.Id == "Lightning" then
		lightning(def, ground, caster)
	elseif def.Id == "Gust" then
		gust(def, ground, dir, caster)
	elseif def.Id == "Meteor" then
		meteors(def, ground, caster)
	elseif def.Id == "Tornado" then
		tornado(def, ground, dir, caster)
	elseif def.Id == "FaultCleave" then
		faultCleave(def, ground, dir, caster)
	elseif def.Id == "ChainLightning" then
		chainLightning(def, ground, caster)
	elseif def.Id == "Eruption" then
		eruption(def, ground, caster)
	elseif def.Id == "Glitch" then
		glitch(def, ground, caster)
	elseif def.Id == "GravitySingularity" then
		singularity(def, ground, caster, false)
	elseif def.Id == "AstralCollapse" then
		singularity(def, ground, caster, true)
	elseif def.Id == "TectonicSpire" then
		tectonicSpire(def, ground, caster)
	elseif def.Id == "ChainArc" then
		chainArc(def, ground, caster)
	elseif def.Id == "MeteorBarrage" then
		meteorBarrage(def, ground, dir, caster)
	elseif def.Id == "PyroclastSurge" then
		pyroclastSurge(def, ground, dir, caster)
	elseif def.Id == "SystemOverride" then
		systemOverride(def, ground, caster)
	elseif def.Id == "MaelstromVortex" then
		tornado(def, ground, dir, caster, true)
	end
end

-- A human God may only cast what their loadout holds: the equipped kit, the God Pack
-- signature swapped in (shared/Loadout) and the universal slot.
local function kitAllows(player: Player, id: string): boolean
	return Loadout.allows(player:GetAttribute(Attributes.Kit), ReplicatedStorage:GetAttribute(Attributes.GodSkin), id)
end

---------------------------------------------------------------------------
-- energy + casting

local function poolFor(key: any): Pool
	local pool = pools[key]
	if not pool then
		pool = { Energy = Chaos.StartEnergy, Ready = {} }
		pools[key] = pool
	end
	return pool
end

bonusEnergy = function(player: Player, amount: number)
	local pool = poolFor(player)
	pool.Energy = math.min(Chaos.Max, pool.Energy + amount)
end

local function publish(player: Player?)
	if not player then
		return
	end
	local pool = poolFor(player)
	player:SetAttribute(Attributes.ChaosEnergy, math.floor(pool.Energy * 10) / 10)
	for id in abilities do
		player:SetAttribute(Attributes.CooldownPrefix .. id, pool.Ready[id] or 0)
	end
end

local function tryCast(caster: Player?, key: any, id: string, target: Vector3, rawDir: Vector3?): boolean
	local def = abilities[id]
	if not def or not state.Active or not state.CastingOpen then
		return false
	end
	if not MapService.InBounds(target) then
		return false
	end
	local pool = poolFor(key)
	local now = workspace:GetServerTimeNow()
	if (pool.Ready[id] or 0) > now or pool.Energy < def.Cost then
		return false
	end
	pool.Energy -= def.Cost
	pool.Ready[id] = now + def.Cooldown
	if caster then
		lastCastId[caster] = id
	end
	publish(caster)

	local dir = Vector3.new(1, 0, 0)
	if rawDir then
		local flat = Vector3.new(rawDir.X, 0, rawDir.Z)
		if flat.Magnitude > 0.01 then
			dir = flat.Unit
		end
	end
	local ground = MapService.GroundAt(target)
	-- under a glass canopy (the Bio-Dome) the impact cracks the panels overhead too
	if def.Tier ~= "Utility" then
		local canopy = MapService.CanopyAbove(ground)
		if canopy then
			task.delay(def.WarningTime, function()
				DestructionService.DamageArea(canopy.Position, Config.Destruction.CanopyCrackRadius, def.StructureDamage * Config.Destruction.CanopyCrackScale)
			end)
		end
	end
	-- every disaster announces itself with its own sound
	local cue = Config.Audio.AbilityCue[id]
	if cue then
		sound(cue.Key, ground, cue.Volume, cue.Speed)
	end
	task.spawn(execute, def, ground, dir, caster)
	return true
end

local function isFiniteVector(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e5
end

---------------------------------------------------------------------------
-- AI Director: plays God whenever no human holds the role

local function directorLoop()
	while state.Active do
		local scale = if state.SuddenDeath then Config.Director.SuddenDeathIntervalScale else 1
		task.wait((Config.Director.MinInterval + math.random() * (Config.Director.MaxInterval - Config.Director.MinInterval)) * scale)
		if not state.Active then
			break
		end
		if state.God ~= nil or not state.CastingOpen then
			continue
		end
		local pool = poolFor(DIRECTOR)
		local now = workspace:GetServerTimeNow()
		local affordable: { Ability } = {}
		local majors: { Ability } = {}
		for _, def in Config.Disasters.Abilities do
			if def.Tier ~= "Utility" and def.Signature ~= true and pool.Energy >= def.Cost and (pool.Ready[def.Id] or 0) <= now then
				table.insert(affordable, def)
				if def.Tier == "Major" then
					table.insert(majors, def)
				end
			end
		end
		if #affordable == 0 then
			continue
		end
		local pick = if #majors > 0 and math.random() < Config.Director.MajorChance
			then majors[math.random(#majors)]
			else affordable[math.random(#affordable)]
		local target: Vector3
		local survivors = RoleService.GetAliveSurvivors()
		local victim = survivors[math.random(math.max(1, #survivors))]
		local hrp = if victim then hrpAndHumanoid(victim) else nil
		if hrp then
			local j = math.floor(Config.Director.TargetJitter)
			target = hrp.Position + Vector3.new(math.random(-j, j), 0, math.random(-j, j))
		else
			local info = MapService.GetCurrent()
			local r = math.floor(if info then info.Radius * 0.6 else 60)
			target = Vector3.new(math.random(-r, r), 0, math.random(-r, r))
		end
		local a = math.random() * math.pi * 2
		tryCast(nil, DIRECTOR, pick.Id, target, Vector3.new(math.cos(a), 0, math.sin(a)))
	end
end

---------------------------------------------------------------------------
-- anti-camp radar

local stillSince: { [Player]: number } = {}
local lastPos: { [Player]: Vector3 } = {}

local function reveal(player: Player, hrp: BasePart)
	local character = player.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = PURPLE
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	Debris:AddItem(highlight, Config.AntiCamp.RevealDuration)

	local ripple = fxPart({
		Name = "Radar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 4, 4),
		CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE,
		Transparency = 0.2,
	})
	TweenService:Create(ripple, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, 50, 50), Transparency = 1 }):Play()
	Debris:AddItem(ripple, 1.5)

	ScoringService.Notify(player, "SPOTTED! KEEP MOVING", Color3.fromRGB(255, 90, 160))
	if state.God then
		ScoringService.Notify(state.God, "CAMPER REVEALED: " .. string.upper(player.DisplayName), PURPLE)
	end
end

local function radarTick()
	if not (state.Active and state.CastingOpen) then
		table.clear(stillSince)
		table.clear(lastPos)
		return
	end
	local now = os.clock()
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		-- hiding indoors or in a jammed zone is fair play; camping in the open is not
		if hrp and (StealthService.IsIndoors(player) or StealthService.IsJammed(hrp.Position)) then
			stillSince[player] = os.clock()
			lastPos[player] = hrp.Position
			continue
		end
		if hrp then
			local last = lastPos[player]
			if not last or (hrp.Position - last).Magnitude > Config.AntiCamp.StationaryRadius then
				lastPos[player] = hrp.Position
				stillSince[player] = now
			elseif now - (stillSince[player] or now) >= Config.AntiCamp.StationaryTime then
				stillSince[player] = now
				reveal(player, hrp)
			end
		end
	end
end

-- Hunter's Pulse: in the final seconds, the last survivor is pinged for the God so the
-- round ends in a chase instead of a hide-and-seek stalemate.
local function hunterPulse(target: Player, god: Player)
	local character = target.Character
	local hrp = hrpAndHumanoid(target)
	if not (character and hrp) then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = RED
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	Debris:AddItem(highlight, Config.HunterPulse.Duration)
	local ripple = fxPart({
		Name = "HunterPulse",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 4, 4),
		CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = RED,
		Transparency = 0.2,
	})
	TweenService:Create(ripple, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, 70, 70), Transparency = 1 }):Play()
	Debris:AddItem(ripple, 1.3)
	sound("Warning", hrp.Position, 0.9, 1.4)
	ScoringService.Notify(god, "HUNTER'S PULSE: " .. string.upper(target.DisplayName), RED)
	ScoringService.Notify(target, "THE GOD CAN SEE YOU — RUN!", Color3.fromRGB(255, 90, 160))
end

---------------------------------------------------------------------------
-- public API (driven by MatchService)

function DisasterService.BeginRound(god: Player?)
	table.clear(pools)
	ComboService.Reset()
	StealthService.Reset()
	state.Active = true
	state.CastingOpen = false
	state.SuddenDeath = false
	state.God = god
	CosmeticService.SetGod(god)
	ReplicatedStorage:SetAttribute(Attributes.CastingOpen, false)
	poolFor(DIRECTOR)
	publish(god)
	task.spawn(directorLoop)
end

function DisasterService.SetGod(god: Player?)
	state.God = god
	CosmeticService.SetGod(god)
	publish(god)
end

function DisasterService.SetCastingOpen(open: boolean)
	state.CastingOpen = open
	ReplicatedStorage:SetAttribute(Attributes.CastingOpen, open)
end

function DisasterService.SetSuddenDeath(on: boolean)
	state.SuddenDeath = on
end

function DisasterService.SetHunterPulse(on: boolean)
	state.HunterPulse = on
end

function DisasterService.EndRound()
	state.Active = false
	state.CastingOpen = false
	state.SuddenDeath = false
	state.HunterPulse = false
	state.God = nil
	CosmeticService.SetGod(nil)
	ReplicatedStorage:SetAttribute(Attributes.CastingOpen, false)
	table.clear(pools)
	table.clear(chains)
	table.clear(lastCastId)
end

function DisasterService.Init()
	Remotes.get("CastDisaster").OnServerEvent:Connect(function(player, id, target, dir)
		if typeof(id) ~= "string" or typeof(target) ~= "Vector3" or not isFiniteVector(target) then
			return
		end
		if dir ~= nil and (typeof(dir) ~= "Vector3" or not isFiniteVector(dir)) then
			return
		end
		if state.God ~= player or RoleService.GetRole(player) ~= "DisasterGod" or not kitAllows(player, id) then
			return
		end
		tryCast(player, player, id, target, dir)
	end)

	DestructionService.VolatileBurst:Connect(function(pos: Vector3, radius: number)
		shakeAll(0.9, 0.5, pos)
		sound("Explosion", pos, 2.6)
		blast(pos, radius, Config.Destruction.VolatilePlayerDamage, state.God, 50, "Explosion")
	end)

	-- big collapses rattle every camera nearby
	DestructionService.Collapsed:Connect(function(_building: Model, center: Vector3, size: Vector3)
		-- a whole floor / building coming down rewards the human God
		local god = state.God
		if god and state.Active and state.CastingOpen and size.Magnitude >= GC.CollapseMinSize then
			bonusEnergy(god, GC.CollapseEnergy)
			ScoringService.Award(god, GC.CollapseCoins, string.format("COLLAPSE COMBO (+%d ENERGY)", GC.CollapseEnergy), Color3.fromRGB(255, 160, 60))
		end
		local J = Config.Juice
		shakeAll(math.min(J.CollapseShakeMax, J.CollapseShakeBase + size.Magnitude * J.CollapseShakePerStud), 0.6, center)
		sound("Debris", center, 1.6, 0.9 + math.random() * 0.2)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.HunterPulse.Interval)
			local god = state.God
			if state.Active and state.HunterPulse and god then
				local alive = RoleService.GetAliveSurvivors()
				if #alive == 1 then
					hunterPulse(alive[1], god)
				end
			end
		end
	end)

	-- energy regen
	local publishTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		if not state.Active then
			return
		end
		local mult = if state.SuddenDeath then Chaos.SuddenDeathRegenMultiplier else 1
		if ReplicatedStorage:GetAttribute(Attributes.Mutator) == "Hyperdrive" then
			mult *= Config.Mutators.HyperdriveScale -- Chaos Twist: everything recharges faster
		end
		for _, pool in pools do
			pool.Energy = math.min(Chaos.Max, pool.Energy + Chaos.RegenPerSecond * mult * dt)
		end
		publishTimer += dt
		if publishTimer >= 0.1 then
			publishTimer = 0
			publish(state.God)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AntiCamp.CheckInterval)
			radarTick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pools[player] = nil
		stillSince[player] = nil
		lastPos[player] = nil
		if state.God == player then
			-- the God left mid-round: the AI Director picks the round up seamlessly
			state.God = nil
			if state.Active then
				ReplicatedStorage:SetAttribute(Attributes.GodName, "The Storm")
				Remotes.get("Banner"):FireAllClients("THE GOD HAS LEFT", "The Storm Director takes over!", PURPLE)
			end
		end
	end)
end

return DisasterService
