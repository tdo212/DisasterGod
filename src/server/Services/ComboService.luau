--!strict
-- ComboService: disasters reacting to the world and to each other.
--   * Conduction: a bolt near metal structure arcs along it and shocks survivors close to
--     the charged parts; a bolt at the rising water line, or into a puddle, shocks
--     everyone in the water.
--   * Firenado: a tornado that passes through fire (an Eruption pool or burning patches)
--     catches light and drops burning patches along its path.
--   * Puddles: a toppled water tower or broken pipe gantry floods the ground. Puddles put
--     out fires, conduct lightning and make knockback stronger (slippery).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local AudioService = require(script.Parent.AudioService)
local DestructionService = require(script.Parent.DestructionService)
local MapService = require(script.Parent.MapService)
local RoleService = require(script.Parent.RoleService)
local SaveService = require(script.Parent.SaveService)
local ScoringService = require(script.Parent.ScoringService)

local CB = Config.Combos

local ComboService = {}

type Zone = { Position: Vector3, Radius: number, Until: number, Damaging: boolean, Caster: Player?, Part: BasePart? }

local fires: { Zone } = {}
local puddles: { Zone } = {}

local SPARK = Color3.fromRGB(190, 230, 255)
local FIRE = Color3.fromRGB(255, 120, 30)
local WATER = Color3.fromRGB(80, 170, 235)
local METALS = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
}

local function fx(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = MapService.GetHazardsFolder()
	return p
end

local function disc(position: Vector3, radius: number, color: Color3, transparency: number, material: Enum.Material?): Part
	return fx({
		Name = "ComboZone",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency,
		Material = material or Enum.Material.Neon,
	})
end

local function arc(from: Vector3, to: Vector3)
	local seg = fx({ Name = "Arc", Size = Vector3.new(0.5, 0.5, math.max(1, (to - from).Magnitude)), CFrame = CFrame.lookAt((from + to) / 2, to), Color = SPARK, Transparency = 0.1 })
	TweenService:Create(seg, TweenInfo.new(0.35), { Transparency = 1 }):Play()
	Debris:AddItem(seg, 0.4)
end

local function shock(player: Player, damage: number, caster: Player?, cause: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and hrp and humanoid.Health > 0 then
		ScoringService.NoteHit(player, caster, cause)
		if SaveService.TryAegis(player, humanoid, damage) then
			return
		end
		humanoid:TakeDamage(damage)
		arc(hrp.Position + Vector3.new(0, 6, 0), hrp.Position)
	end
end

local function inZone(zones: { Zone }, position: Vector3, pad: number?): Zone?
	local now = os.clock()
	for _, z in zones do
		if z.Until > now then
			local d = Vector3.new(position.X - z.Position.X, 0, position.Z - z.Position.Z).Magnitude
			if d <= z.Radius + (pad or 0) and math.abs(position.Y - z.Position.Y) < 8 then
				return z
			end
		end
	end
	return nil
end

-- Lightning follow-up: conduct through metal, water and puddles.
function ComboService.Electrify(center: Vector3, radius: number, caster: Player?)
	local shocked: { [Player]: boolean } = {}
	local hit = false

	-- metal structure nearby carries the charge
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { MapService.GetArenaFolder() }
	local metal: { BasePart } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, radius * CB.MetalReach, params) do
		if METALS[part.Material] and part:GetAttribute("Structural") == true and part:GetAttribute("Broken") ~= true then
			table.insert(metal, part)
		end
	end
	table.sort(metal, function(a, b)
		return (a.Position - center).Magnitude < (b.Position - center).Magnitude
	end)
	local charged = {}
	for i = 1, math.min(#metal, CB.MetalMaxArcs) do
		table.insert(charged, metal[i])
		arc(center + Vector3.new(0, 3, 0), metal[i].Position)
	end
	if #charged > 0 then
		for _, player in RoleService.GetAliveSurvivors() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				for _, part in charged do
					if (hrp.Position - part.Position).Magnitude <= CB.MetalShockRadius + part.Size.Magnitude / 2 then
						shocked[player] = true
						shock(player, CB.ShockDamage, caster, "Conducted Lightning")
						hit = true
						break
					end
				end
			end
		end
	end

	-- rising water line, or a puddle under the strike
	local fluidTop = MapService.GetFluidTop()
	local atWater = fluidTop ~= nil and math.abs(center.Y - fluidTop) <= CB.WaterShockMargin
	local puddle = inZone(puddles, center, radius)
	if atWater or puddle then
		local origin = if puddle then puddle.Position else center
		for _, player in RoleService.GetAliveSurvivors() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and not shocked[player] then
				local wet = (atWater and fluidTop ~= nil and hrp.Position.Y < fluidTop + 2 and (hrp.Position - origin).Magnitude <= CB.WaterShockRadius)
					or (puddle ~= nil and inZone({ puddle }, hrp.Position) ~= nil)
				if wet then
					shock(player, CB.WaterShockDamage, caster, "Electrified Water")
					hit = true
				end
			end
		end
	end

	if #charged > 0 or atWater or puddle then
		AudioService.playAt("Lightning", center, 1.2, 1.6)
		if caster then
			ScoringService.Notify(caster, if hit then "⚡ COMBO: CONDUCTED SHOCK!" else "⚡ CONDUCTED", Color3.fromRGB(120, 220, 255))
		end
	end
end

-- Eruption pools register as fire (they deal their own damage).
function ComboService.AddFire(position: Vector3, radius: number, duration: number): Zone
	local zone: Zone = { Position = position, Radius = radius, Until = os.clock() + duration, Damaging = false }
	table.insert(fires, zone)
	return zone
end

function ComboService.IsBurning(zone: Zone): boolean
	return zone.Until > os.clock()
end

-- True when a tornado at `position` touches fire.
function ComboService.FireNear(position: Vector3, radius: number): boolean
	return inZone(fires, position, radius) ~= nil
end

-- Firenado trail: a burning patch that hurts survivors standing in it.
function ComboService.DropFire(position: Vector3, caster: Player?)
	local ground = MapService.GroundAt(position)
	if inZone(puddles, ground) then
		return
	end
	local part = disc(ground, CB.FireRadius, FIRE, 0.35)
	local flame = Instance.new("Fire")
	flame.Size = CB.FireRadius * 1.4
	flame.Heat = 8
	flame.Parent = part
	TweenService:Create(part, TweenInfo.new(CB.FireDuration, Enum.EasingStyle.Linear), { Transparency = 0.9 }):Play()
	Debris:AddItem(part, CB.FireDuration)
	table.insert(fires, { Position = ground, Radius = CB.FireRadius, Until = os.clock() + CB.FireDuration, Damaging = true, Caster = caster, Part = part })
end

-- A flooded patch at `position`. Puts out fires inside it.
function ComboService.Puddle(position: Vector3)
	local ground = MapService.GroundAt(position)
	local part = disc(ground, CB.PuddleRadius, WATER, 0.35, Enum.Material.Glass)
	TweenService:Create(part, TweenInfo.new(CB.PuddleDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	Debris:AddItem(part, CB.PuddleDuration)
	local zone: Zone = { Position = ground, Radius = CB.PuddleRadius, Until = os.clock() + CB.PuddleDuration, Damaging = false, Part = part }
	table.insert(puddles, zone)
	AudioService.playAt("Gust", ground, 1.2, 0.6)
	for _, fire in fires do
		if (fire.Position - ground).Magnitude <= CB.PuddleRadius + fire.Radius then
			fire.Until = 0
			if fire.Part and fire.Part.Parent then
				fire.Part:Destroy()
			end
		end
	end
end

-- Knockback multiplier for someone standing at `position` (slippery puddles).
function ComboService.KnockbackScale(position: Vector3): number
	return if inZone(puddles, position, 1) then CB.WetKnockback else 1
end

function ComboService.Reset()
	for _, z in fires do
		if z.Part and z.Part.Parent then
			z.Part:Destroy()
		end
	end
	table.clear(fires)
	table.clear(puddles)
end

function ComboService.Init()
	DestructionService.Collapsed:Connect(function(building: Model, center: Vector3)
		for _, name in CB.PuddleSources do
			if building.Name == name then
				ComboService.Puddle(center)
				return
			end
		end
	end)
	-- burning patches hurt; expired zones are dropped
	task.spawn(function()
		while true do
			task.wait(CB.FireTick)
			local now = os.clock()
			for i = #fires, 1, -1 do
				if fires[i].Until <= now then
					table.remove(fires, i)
				end
			end
			for i = #puddles, 1, -1 do
				if puddles[i].Until <= now then
					table.remove(puddles, i)
				end
			end
			for _, player in RoleService.GetAliveSurvivors() do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local zone = hrp and inZone(fires, hrp.Position)
				if zone and zone.Damaging then
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						ScoringService.NoteHit(player, zone.Caster, "Firenado")
						if not SaveService.TryAegis(player, humanoid, CB.FireDamage) then
							humanoid:TakeDamage(CB.FireDamage)
						end
					end
				end
			end
		end
	end)
end

return ComboService
