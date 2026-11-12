--!strict
-- DestructionService: structural health, support-based collapse, volatile chain
-- reactions and debris cleanup.
--
-- Every destructible part has attributes Health / Level / Support (see World/Builder).
-- When the intact supports of a level in a building drop below
-- Config.Destruction.CollapseSupportFraction, every level above it is welded into
-- slabs, unanchored and left to physics.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DC = Config.Destruction

local DestructionService = {}

local collapsed = Instance.new("BindableEvent")
-- (building: Model, center: Vector3, size: Vector3)
DestructionService.Collapsed = collapsed.Event

local volatileBurst = Instance.new("BindableEvent")
-- (position: Vector3, radius: number)
DestructionService.VolatileBurst = volatileBurst.Event

local arenaFolder: Instance? = nil
local debrisList: { BasePart } = {}

function DestructionService.SetArena(folder: Instance?)
	arenaFolder = folder
	table.clear(debrisList)
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

local function trackDebris(part: BasePart)
	table.insert(debrisList, part)
	Debris:AddItem(part, DC.DebrisLifetime + math.random() * 4)
	while #debrisList > DC.MaxDebris do
		local oldest = table.remove(debrisList, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

local function release(part: BasePart, from: Vector3?, power: number)
	part:SetAttribute("Broken", true)
	part.Anchored = false
	part.CanCollide = true
	if from then
		local away = part.Position - from
		local dir = if away.Magnitude > 0.01 then away.Unit else Vector3.yAxis
		part.AssemblyLinearVelocity = dir * power + Vector3.new(0, power * 0.6, 0)
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
		collapsed:Fire(building, cf.Position, size)
	end
	return count
end

local function breakPart(part: BasePart, from: Vector3?): boolean
	if not isIntact(part) then
		return false
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

-- Loose debris near a point (used by the tornado to swirl wreckage).
function DestructionService.GetDebrisNear(center: Vector3, radius: number): { BasePart }
	local list = {}
	for _, part in debrisList do
		if part.Parent and not part.Anchored and (part.Position - center).Magnitude <= radius then
			table.insert(list, part)
		end
	end
	return list
end

function DestructionService.Init()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 1 then
			return
		end
		accum = 0
		-- sink debris that fell into the ocean / lava / void
		for i = #debrisList, 1, -1 do
			local part = debrisList[i]
			if not part.Parent then
				table.remove(debrisList, i)
			elseif part.Position.Y < Config.Player.KillPlaneY - 10 then
				part:Destroy()
				table.remove(debrisList, i)
			end
		end
	end)
end

return DestructionService
