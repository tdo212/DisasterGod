--!strict
-- DestructionService: structural health, support-based collapse, volatile chain
-- reactions and debris cleanup.
--
-- Every destructible part has attributes Health / Level / Support (see World/Builder).
-- When the intact supports of a level in a building drop below
-- Config.Destruction.CollapseSupportFraction, every level above it is welded into
-- slabs, unanchored and left to physics.
--
-- Performance: small non-load-bearing pieces are not simulated here. They are removed
-- and sent (batched once per frame) to clients as cosmetic rubble (DebrisController).
-- Server debris that comes to rest is put to sleep: anchored with CanTouch/CanQuery off.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AudioService = require(script.Parent.AudioService)

local DC = Config.Destruction
local DB = Config.Debris
local DEBRIS_TAG = "Debris"

local DestructionService = {}

-- Characters are put in this group (MatchService) so fading debris can pass through them.
DestructionService.CharacterGroup = "Characters"
local FADING_GROUP = "DebrisFading"
DestructionService.RubbleGroup = "ClientRubble" -- client-only rubble never touches characters

local collapsed = Instance.new("BindableEvent")
-- (building: Model, center: Vector3, size: Vector3)
DestructionService.Collapsed = collapsed.Event

local volatileBurst = Instance.new("BindableEvent")
-- (position: Vector3, radius: number)
DestructionService.VolatileBurst = volatileBurst.Event

local arenaFolder: Instance? = nil
local debrisList: { BasePart } = {}
local restingFor: { [BasePart]: number } = {}
local pendingRubble: { { any } } = {}
local rubbleRemote = Remotes.get("Rubble")

function DestructionService.SetArena(folder: Instance?)
	arenaFolder = folder
	table.clear(debrisList)
	table.clear(restingFor)
end

local function overlapParams(): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if arenaFolder then { arenaFolder } else {}
	return params
end

local function isIntact(part: BasePart): boolean
	return part:GetAttribute("Structural") == true and part:GetAttribute("Broken") ~= true
end

-- End of a chunk's life: it stops colliding with players (so rubble can't trap anyone),
-- then shrinks and fades out instead of popping.
local function fade(part: BasePart)
	if not part.Parent then
		return
	end
	part.CollisionGroup = FADING_GROUP
	part.CastShadow = false
	TweenService:Create(part, TweenInfo.new(DC.DebrisFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = part.Size * DC.DebrisFadeScale,
	}):Play()
	Debris:AddItem(part, DC.DebrisFadeTime + 0.1)
end

local function trackDebris(part: BasePart)
	table.insert(debrisList, part)
	CollectionService:AddTag(part, DEBRIS_TAG)
	task.delay(DC.DebrisLifetime + math.random() * DC.DebrisLifetimeJitter, fade, part)
	while #debrisList > DC.MaxDebris do
		local oldest = table.remove(debrisList, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

local function breakVelocity(part: BasePart, from: Vector3, power: number): Vector3
	local away = part.Position - from
	local dir = if away.Magnitude > 0.01 then away.Unit else Vector3.yAxis
	return dir * power + Vector3.new(0, power * 0.6, 0)
end

-- Wall panels, glass and trim: cosmetic only, so the clients simulate them.
local function isCosmetic(part: BasePart): boolean
	if part:GetAttribute("Support") == true or part:GetAttribute("Volatile") == true then
		return false
	end
	if DB.ClientMaterials[part.Material.Name] then
		return true
	end
	local s = part.Size
	return s.X * s.Y * s.Z <= DB.ClientMaxVolume
end

local function shatter(part: BasePart, from: Vector3?)
	part:SetAttribute("Broken", true)
	local velocity = if from then breakVelocity(part, from, DC.BreakImpulse) else Vector3.zero
	table.insert(pendingRubble, { part.CFrame, part.Size, part.Color, part.Material, part.Transparency, velocity })
	part:Destroy()
end

local function release(part: BasePart, from: Vector3?, power: number)
	part:SetAttribute("Broken", true)
	part.Anchored = false
	part.CanCollide = true
	if from then
		part.AssemblyLinearVelocity = breakVelocity(part, from, power)
		part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6
	end
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	trackDebris(part)
end

local function buildingOf(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("BuildingId") == nil do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

-- Drop every intact part above `level` in the building, welded per level so floors fall as slabs.
local function collapseAbove(building: Model, level: number, from: Vector3?): number
	local byLevel: { [number]: { BasePart } } = {}
	for _, d in building:GetDescendants() do
		if d:IsA("BasePart") and isIntact(d) then
			local l = d:GetAttribute("Level") :: number? or 1
			if l > level then
				byLevel[l] = byLevel[l] or {}
				table.insert(byLevel[l], d)
			end
		end
	end
	local count = 0
	local fallDir = building:GetAttribute("FallDirection") :: Vector3?
	for _, parts in byLevel do
		local root = parts[1]
		for i, part in parts do
			if i > 1 then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = root
			end
		end
		for _, part in parts do
			part:SetAttribute("Broken", true)
			part.Anchored = false
			trackDebris(part)
			count += 1
		end
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		if fallDir then
			-- directed fall: shove the whole assembly and tip it over toward fallDir
			root.AssemblyLinearVelocity = fallDir * DC.DirectedFallSpeed
			root.AssemblyAngularVelocity = Vector3.yAxis:Cross(fallDir) * DC.DirectedTipSpin
			continue
		end
		-- nudge the slab so it shears off instead of dropping straight down
		if from then
			local away = root.Position - from
			local horizontal = Vector3.new(away.X, 0, away.Z)
			if horizontal.Magnitude > 0.01 then
				root.AssemblyLinearVelocity = horizontal.Unit * 12 - Vector3.new(0, 10, 0)
			end
		end
		root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 1.5
	end
	return count
end

local function checkStability(building: Model, from: Vector3?): number
	local total: { [number]: number } = {}
	local intact: { [number]: number } = {}
	for _, d in building:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Support") == true then
			local l = d:GetAttribute("Level") :: number? or 1
			total[l] = (total[l] or 0) + 1
			if isIntact(d) then
				intact[l] = (intact[l] or 0) + 1
			end
		end
	end
	-- find the lowest failing level
	local failing: number? = nil
	for l, t in total do
		if (intact[l] or 0) / t < DC.CollapseSupportFraction then
			if failing == nil or l < failing then
				failing = l
			end
		end
	end
	if failing == nil then
		-- damaged but still standing: groan as a warning to anyone inside
		for l, t in total do
			if (intact[l] or 0) < t then
				AudioService.playAt("Creak", building:GetPivot().Position, 1.8, 0.9 + math.random() * 0.3, DC.CreakCooldown)
				break
			end
		end
		return 0
	end
	local cf, size = building:GetBoundingBox()
	local count = collapseAbove(building, failing, from)
	-- the failing level's own remaining supports buckle out from under the load:
	-- kicked sideways and briefly non-colliding so the floors above actually drop
	for _, d in building:GetDescendants() do
		if d:IsA("BasePart") and isIntact(d) and d:GetAttribute("Level") == failing and d:GetAttribute("Support") == true then
			release(d, from, DC.BuckleImpulse)
			d.CanCollide = false
			task.delay(DC.BuckleNoCollideTime, function()
				if d.Parent then
					d.CanCollide = true
				end
			end)
			count += 1
		end
	end
	if count > 0 then
		AudioService.playAt("Collapse", cf.Position, 2.4, 0.8 + math.random() * 0.3, Config.Audio.CollapseSoundCooldown)
		collapsed:Fire(building, cf.Position, size)
	end
	return count
end

local function breakPart(part: BasePart, from: Vector3?): boolean
	if not isIntact(part) then
		return false
	end
	if part.Material == Enum.Material.Glass then
		AudioService.playAt("Glass", part.Position, 1.4, 0.9 + math.random() * 0.3, Config.Audio.GlassSoundCooldown)
	end
	if isCosmetic(part) then
		shatter(part, from)
		return true
	end
	release(part, from, DC.BreakImpulse)
	if part:GetAttribute("Volatile") == true then
		local pos = part.Position
		task.delay(0.35, function()
			local boom = Instance.new("Explosion")
			boom.Position = pos
			boom.BlastRadius = DC.VolatileRadius
			boom.BlastPressure = 0
			boom.DestroyJointRadiusPercent = 0
			boom.Parent = workspace
			volatileBurst:Fire(pos, DC.VolatileRadius)
			DestructionService.DamageArea(pos, DC.VolatileRadius, DC.VolatileStructureDamage)
		end)
	end
	return true
end

local function applyDamage(parts: { BasePart }, damage: number, from: Vector3?): number
	local destroyed = 0
	local touched: { [Model]: boolean } = {}
	for _, part in parts do
		if isIntact(part) then
			local health = (part:GetAttribute("Health") :: number? or DC.DefaultHealth) - damage
			part:SetAttribute("Health", health)
			local building = buildingOf(part)
			if building then
				touched[building] = true
			end
			if health <= 0 and breakPart(part, from) then
				destroyed += 1
			end
		end
	end
	for building in touched do
		if building.Parent then
			destroyed += checkStability(building, from)
		end
	end
	return destroyed
end

-- Damage all structural parts within a sphere. Returns parts destroyed (incl. collapses).
function DestructionService.DamageArea(center: Vector3, radius: number, damage: number): number
	if not arenaFolder then
		return 0
	end
	local hits = workspace:GetPartBoundsInRadius(center, radius, overlapParams())
	return applyDamage(hits, damage, center)
end

-- Damage all structural parts within an oriented box (fault lines).
function DestructionService.DamageBox(cframe: CFrame, size: Vector3, damage: number): number
	if not arenaFolder then
		return 0
	end
	local hits = workspace:GetPartBoundsInBox(cframe, size, overlapParams())
	return applyDamage(hits, damage, cframe.Position)
end

local function wake(part: BasePart)
	part.Anchored = false
	part.CanTouch = true
	part.CanQuery = true
	restingFor[part] = nil
end

-- Loose debris near a point (used by the tornado to swirl wreckage). Sleeping pieces wake up.
function DestructionService.GetDebrisNear(center: Vector3, radius: number): { BasePart }
	local list = {}
	for _, part in debrisList do
		if part.Parent and (part.Position - center).Magnitude <= radius then
			if part.Anchored then
				wake(part)
			end
			table.insert(list, part)
		end
	end
	return list
end

-- Resting server debris stops costing the physics solver.
local function sleepResting(step: number)
	for _, part in debrisList do
		if part.Parent and not part.Anchored then
			if part.AssemblyLinearVelocity.Magnitude < DB.SleepSpeed and part.AssemblyAngularVelocity.Magnitude < DB.SleepSpeed then
				local t = (restingFor[part] or 0) + step
				restingFor[part] = t
				if t >= DB.SleepSeconds then
					part.Anchored = true
					part.CanTouch = false
					part.CanQuery = false
					restingFor[part] = nil
				end
			else
				restingFor[part] = nil
			end
		end
	end
end

function DestructionService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DestructionService.CharacterGroup)
		PhysicsService:RegisterCollisionGroup(FADING_GROUP)
		PhysicsService:CollisionGroupSetCollidable(DestructionService.CharacterGroup, FADING_GROUP, false)
		PhysicsService:RegisterCollisionGroup(DestructionService.RubbleGroup)
		PhysicsService:CollisionGroupSetCollidable(DestructionService.CharacterGroup, DestructionService.RubbleGroup, false)
		PhysicsService:CollisionGroupSetCollidable(FADING_GROUP, DestructionService.RubbleGroup, false)
	end)
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		if #pendingRubble > 0 then
			rubbleRemote:FireAllClients(pendingRubble)
			pendingRubble = {}
		end
		accum += dt
		if accum < 0.5 then
			return
		end
		local step = accum
		accum = 0
		sleepResting(step)
		-- sink debris that fell into the ocean / lava / void
		for i = #debrisList, 1, -1 do
			local part = debrisList[i]
			if not part.Parent then
				restingFor[part] = nil
				table.remove(debrisList, i)
			elseif part.Position.Y < Config.Player.KillPlaneY - 10 then
				part:Destroy()
				table.remove(debrisList, i)
			end
		end
	end)
end

return DestructionService
