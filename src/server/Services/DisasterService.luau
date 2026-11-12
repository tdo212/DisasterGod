--!strict
-- DisasterService: Chaos Energy economy, ability validation, telegraphs, the five
-- disasters, the AI Director (plays God when no human does) and anti-camp radar.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local DestructionService = require(script.Parent.DestructionService)
local EnvironmentService = require(script.Parent.EnvironmentService)
local MapService = require(script.Parent.MapService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)

type Ability = Types.AbilityDefinition
type Pool = { Energy: number, Ready: { [string]: number } }

local Attributes = Config.Attributes
local Chaos = Config.Chaos

local AudioService = require(script.Parent.AudioService)

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

local function hurt(player: Player, damage: number, caster: Player?)
	local _, humanoid = hrpAndHumanoid(player)
	if humanoid and humanoid.Health > 0 and damage > 0 then
		ScoringService.NoteHit(player, caster)
		humanoid:TakeDamage(damage)
	end
end

local function knock(player: Player, velocity: Vector3)
	local info = MapService.GetCurrent()
	local mult = if info and info.KnockbackMultiplier then info.KnockbackMultiplier else 1
	clientEffect:FireClient(player, "Knockback", velocity * mult)
end

-- Hurt + optionally knock back survivors in a sphere; near-miss everyone just outside.
local function blast(center: Vector3, radius: number, damage: number, caster: Player?, knockback: number?)
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpAndHumanoid(player)
		if hrp then
			local offset = hrp.Position - center
			if offset.Magnitude <= radius + 1.5 then
				hurt(player, damage, caster)
				if knockback then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
					knock(player, dir * knockback + Vector3.new(0, knockback * 0.5, 0))
				end
			end
		end
	end
	ScoringService.CheckNearMiss(center, radius)
end

local function creditDestruction(caster: Player?, count: number)
	ScoringService.RecordDestruction(caster, count)
	if caster and count >= 6 then
		ScoringService.Notify(caster, string.format("DESTRUCTION x%d", count), ORANGE)
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

local function lightning(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, Color3.fromRGB(120, 200, 255))
	task.wait(def.WarningTime)
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
			Color = Color3.fromRGB(200, 235, 255),
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
	blast(ground, def.Radius, def.PlayerDamage, caster, 30)
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
			hurt(player, def.PlayerDamage, caster)
			knock(player, dir * k + Vector3.new(0, 28, 0))
		end
	end
	ScoringService.CheckNearMiss(ground, def.Radius)
end

local function meteors(def: Ability, ground: Vector3, caster: Player?)
	ringTelegraph(ground, def.Radius, def.WarningTime, ORANGE)
	EnvironmentService.Darken(def.WarningTime + 2)
	task.wait(def.WarningTime * 0.6)
	local count = def.Count or 5
	local impact = def.ImpactRadius or 10
	for i = 1, count do
		local r = def.Radius * math.sqrt(math.random())
		local a = math.random() * math.pi * 2
		local point = MapService.GroundAt(ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		task.spawn(function()
			ringTelegraph(point, impact, 0.9, RED)
			local from = point + Vector3.new(40, 130, 30)
			local rock = fxPart({
				Name = "Meteor",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 7,
				CFrame = CFrame.new(from),
				Color = Color3.fromRGB(255, 90, 30),
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
			blast(point, impact, def.PlayerDamage, caster, 45)
		end)
		task.wait(0.28)
	end
end

local function tornado(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
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
		p.Color = Color3.fromRGB(120 + i * 6, 120 + i * 6, 130 + i * 6)
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
	local conn: RBXScriptConnection
	local finished = Instance.new("BindableEvent")

	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		spin += dt * 6
		-- chase the nearest survivor (keeps hiding spots under pressure)
		local nearest: Vector3? = nil
		local best = 140
		for _, player in RoleService.GetAliveSurvivors() do
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
			heading = heading:Lerp(nearest.Unit, math.min(1, dt * 0.8)).Unit
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
			creditDestruction(caster, DestructionService.DamageArea(pos + Vector3.new(0, 8, 0), radius, def.StructureDamage * 0.25))
			for _, part in DestructionService.GetDebrisNear(pos, radius * 1.8) do
				local offset = part.Position - pos
				local tangent = Vector3.new(-offset.Z, 0, offset.X)
				if tangent.Magnitude > 0.1 then
					part.AssemblyLinearVelocity = tangent.Unit * 40 - Vector3.new(offset.X, 0, offset.Z) * 0.6 + Vector3.new(0, 35, 0)
				end
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
						hurt(player, def.TickDamage or 8, caster)
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
				hurt(player, def.PlayerDamage, caster)
				knock(player, Vector3.new(0, 55, 0) + cf.RightVector * (if localPos.X >= 0 then 25 else -25))
			elseif math.abs(localPos.X) <= width / 2 + Config.Scoring.NearMissMargin and math.abs(localPos.Z) <= length / 2 then
				ScoringService.Award(player, Config.Scoring.NearMissCoins, "NEAR MISS", Color3.fromRGB(90, 230, 255))
				ScoringService.GetRecord(player).NearMisses += 1
			end
		end
	end
end

local function execute(def: Ability, ground: Vector3, dir: Vector3, caster: Player?)
	if def.Id == "Lightning" then
		lightning(def, ground, caster)
	elseif def.Id == "Gust" then
		gust(def, ground, dir, caster)
	elseif def.Id == "Meteor" then
		meteors(def, ground, caster)
	elseif def.Id == "Tornado" then
		tornado(def, ground, dir, caster)
	elseif def.Id == "FaultCleave" then
		faultCleave(def, ground, dir, caster)
	end
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
	publish(caster)

	local dir = Vector3.new(1, 0, 0)
	if rawDir then
		local flat = Vector3.new(rawDir.X, 0, rawDir.Z)
		if flat.Magnitude > 0.01 then
			dir = flat.Unit
		end
	end
	local ground = MapService.GroundAt(target)
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
			if pool.Energy >= def.Cost and (pool.Ready[def.Id] or 0) <= now then
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

---------------------------------------------------------------------------
-- public API (driven by MatchService)

function DisasterService.BeginRound(god: Player?)
	table.clear(pools)
	state.Active = true
	state.CastingOpen = false
	state.SuddenDeath = false
	state.God = god
	ReplicatedStorage:SetAttribute(Attributes.CastingOpen, false)
	poolFor(DIRECTOR)
	publish(god)
	task.spawn(directorLoop)
end

function DisasterService.SetGod(god: Player?)
	state.God = god
	publish(god)
end

function DisasterService.SetCastingOpen(open: boolean)
	state.CastingOpen = open
	ReplicatedStorage:SetAttribute(Attributes.CastingOpen, open)
end

function DisasterService.SetSuddenDeath(on: boolean)
	state.SuddenDeath = on
end

function DisasterService.EndRound()
	state.Active = false
	state.CastingOpen = false
	state.SuddenDeath = false
	state.God = nil
	ReplicatedStorage:SetAttribute(Attributes.CastingOpen, false)
	table.clear(pools)
end

function DisasterService.Init()
	Remotes.get("CastDisaster").OnServerEvent:Connect(function(player, id, target, dir)
		if typeof(id) ~= "string" or typeof(target) ~= "Vector3" or not isFiniteVector(target) then
			return
		end
		if dir ~= nil and (typeof(dir) ~= "Vector3" or not isFiniteVector(dir)) then
			return
		end
		if state.God ~= player or RoleService.GetRole(player) ~= "DisasterGod" then
			return
		end
		tryCast(player, player, id, target, dir)
	end)

	DestructionService.VolatileBurst:Connect(function(pos: Vector3, radius: number)
		shakeAll(0.9, 0.5, pos)
		sound("Explosion", pos, 2.6)
		blast(pos, radius, Config.Destruction.VolatilePlayerDamage, state.God, 50)
	end)

	-- energy regen
	local publishTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		if not state.Active then
			return
		end
		local mult = if state.SuddenDeath then Chaos.SuddenDeathRegenMultiplier else 1
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
			state.God = nil
		end
	end)
end

return DisasterService
