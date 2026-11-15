--!strict
-- MapService: builds / clears the active arena and runs the sudden-death rising fluid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local World = ServerScriptService.Server.World
local Builders: { [string]: any } = {
	FractureBay = require(World.FractureBay),
	MagmaCore = require(World.MagmaCore),
	NeoShibuya = require(World.NeoShibuya),
	SunscorchedMirage = require(World.SunscorchedMirage),
	OutpostZero = require(World.OutpostZero),
	StarlightBoardwalk = require(World.StarlightBoardwalk),
	ChronoSpire = require(World.ChronoSpire),
	VerdantDome = require(World.VerdantDome),
	IroncladArmada = require(World.IroncladArmada),
	AbyssalAquaDome = require(World.AbyssalAquaDome),
	CasinoRoyale = require(World.CasinoRoyale),
	OasisBazaar = require(World.OasisBazaar),
	ClockworkSpire = require(World.ClockworkSpire),
}

local DestructionService = require(script.Parent.DestructionService)
local Builder = require(World.Builder)
local Details = require(World.Details)

-- Hideout palette per lighting preset (wall, roof, material).
local HIDEOUT_LOOK: { [string]: { Color3 | Enum.Material } } = {
	Desert = { Color3.fromRGB(205, 170, 120), Color3.fromRGB(150, 110, 70), Enum.Material.Sandstone },
	Arctic = { Color3.fromRGB(225, 235, 245), Color3.fromRGB(120, 140, 170), Enum.Material.SmoothPlastic },
	Night = { Color3.fromRGB(70, 60, 95), Color3.fromRGB(45, 40, 60), Enum.Material.Metal },
	Volcanic = { Color3.fromRGB(110, 90, 85), Color3.fromRGB(70, 55, 50), Enum.Material.Slate },
	Tempest = { Color3.fromRGB(110, 116, 124), Color3.fromRGB(70, 74, 80), Enum.Material.Metal },
	Foundry = { Color3.fromRGB(150, 72, 52), Color3.fromRGB(58, 58, 68), Enum.Material.Brick },
	Conservatory = { Color3.fromRGB(232, 238, 236), Color3.fromRGB(176, 186, 190), Enum.Material.SmoothPlastic },
	Abyss = { Color3.fromRGB(130, 142, 150), Color3.fromRGB(70, 80, 92), Enum.Material.Metal },
	Casino = { Color3.fromRGB(110, 40, 60), Color3.fromRGB(60, 40, 50), Enum.Material.SmoothPlastic },
	Canyon = { Color3.fromRGB(214, 168, 118), Color3.fromRGB(120, 78, 46), Enum.Material.Sandstone },
	Nebula = { Color3.fromRGB(196, 186, 170), Color3.fromRGB(110, 70, 44), Enum.Material.Cobblestone },
}
local DEFAULT_LOOK = { Color3.fromRGB(170, 120, 75), Color3.fromRGB(120, 80, 50), Enum.Material.WoodPlanks }

local MapService = {}

local arena: Folder
local hazards: Folder
local current: Types.MapInfo? = nil
local fluid: BasePart? = nil
local sea: BasePart? = nil
local rotationIndex = 0

local function ensureFolder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

-- Workspace.Models (hand-made props in the place file) -> a clean, static template in
-- ServerStorage: scripts, seats, forces, sounds, emitters and welds go; every part is
-- anchored destructible structure.
local propTemplates: { [string]: Model } = {}
local function prepareProps()
	local P = Config.PropModels
	local source = workspace:FindFirstChild(P.Folder)
	if not source then
		local stored = ServerStorage:FindFirstChild("PropModels")
		source = stored
	end
	if not source then
		return
	end
	local store = ServerStorage:FindFirstChild("PropModels") or Instance.new("Folder")
	store.Name = "PropModels"
	store.Parent = ServerStorage
	if source ~= store then
		source.Parent = ServerStorage
		for _, m in source:GetChildren() do
			m.Parent = store
		end
		source:Destroy()
	end
	for _, model in store:GetChildren() do
		if not model:IsA("Model") then
			continue
		end
		local clean = Instance.new("Model")
		clean.Name = model.Name
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local part: BasePart
				if d:IsA("Seat") or d:IsA("VehicleSeat") then
					local p = Instance.new("Part")
					p.Size, p.CFrame, p.Color, p.Material = d.Size, d.CFrame, d.Color, d.Material
					part = p
				else
					part = d:Clone()
					for _, c in part:GetChildren() do
						if not (c:IsA("DataModelMesh") or c:IsA("Decal") or c:IsA("Texture") or c:IsA("SurfaceAppearance")) then
							c:Destroy()
						end
					end
				end
				part.Anchored = true
				part.CanTouch = false
				part.Parent = clean
			end
		end
		propTemplates[model.Name] = clean
	end
end

-- Cars etc. on open ground (or decks) that is genuinely clear, each a destructible model.
local function addProps(info: Types.MapInfo, key: string)
	local P = Config.PropModels
	local spec = P.Cars[key]
	local template = propTemplates[P.CarModel]
	if not spec or not template then
		return
	end
	local cf0, size0 = template:GetBoundingBox()
	local pivot = template:GetPivot()
	local bottom = pivot:ToObjectSpace(cf0 * CFrame.new(0, -size0.Y / 2, 0)).Position
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { info.Model }
	local rng = Random.new()
	local placed = 0
	for _ = 1, P.Tries do
		if placed >= spec.Count then
			break
		end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(15, info.Radius * 0.85)
		local flat = info.Center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local ground = if spec.Surface == "Top" then MapService.GroundAt(flat) else MapService.TerrainAt(flat)
		if ground.Y < info.FluidStartY + 2 then
			continue
		end
		local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local box = CFrame.new(ground + Vector3.new(0, size0.Y / 2 + 0.4, 0)) * yaw
		if #workspace:GetPartBoundsInBox(box, size0 + Vector3.new(2, 0, 2), params) > 0 then
			continue
		end
		placed += 1
		local car = Builder.building(info.Model, "Car")
		for _, part in template:GetChildren() do
			local p = (part :: BasePart):Clone()
			Builder.structural(p, 1, false, P.CarHealth)
			p.Parent = car
		end
		car:PivotTo(CFrame.new(ground) * yaw * CFrame.new(-bottom))
	end
end

function MapService.Init()
	prepareProps()
	arena = ensureFolder("Arena")
	hazards = ensureFolder("Hazards")
	-- maps may have been built in edit mode for previewing; start clean
	arena:ClearAllChildren()
end

function MapService.GetArenaFolder(): Folder
	return arena
end

function MapService.GetHazardsFolder(): Folder
	return hazards
end

function MapService.GetCurrent(): Types.MapInfo?
	return current
end

function MapService.NextMapName(): string
	-- Studio testing: set workspace attribute ForceMap = "<MapName>" to pin the next map
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("ForceMap")
		if typeof(forced) == "string" and Builders[forced] then
			return forced
		end
	end
	local rotation = Config.World.MapRotation
	rotationIndex = rotationIndex % #rotation + 1
	return rotation[rotationIndex]
end

function MapService.Clear()
	hazards:ClearAllChildren()
	arena:ClearAllChildren()
	current = nil
	fluid = nil
	sea = nil
	DestructionService.SetArena(nil)
end

-- Enterable interiors (sheds, two-storey houses with a stairwell, bunkers, lookouts)
-- dropped onto genuinely empty ground: more places to hide on every arena. A spot counts
-- if the ground there is not a building and a box the size of the building is clear.
-- Each gets crates inside to crouch behind.
local function addHideouts(info: Types.MapInfo)
	local H = Config.Hideouts
	local perMap = H.PerMapOverride[info.Name] or H.PerMap
	local look = HIDEOUT_LOOK[info.Lighting] or DEFAULT_LOOK
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { info.Model }
	local rng = Random.new()
	local totalWeight = 0
	for _, v in H.Variants do
		totalWeight += v.Weight
	end
	local function pick(): any
		local roll = rng:NextNumber(0, totalWeight)
		for _, v in H.Variants do
			roll -= v.Weight
			if roll <= 0 then
				return v
			end
		end
		return H.Variants[1]
	end
	local placed = 0
	for _ = 1, H.Tries do
		if placed >= perMap then
			break
		end
		local v = pick()
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(20, info.Radius * 0.85)
		local ground = MapService.TerrainAt(info.Center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
		if ground.Y < info.FluidStartY + 2 then
			continue -- in the water
		end
		local height = v.Floors * v.FloorHeight + 2
		local size = Vector3.new(v.Width + 4, height, v.Depth + 4)
		local box = CFrame.new(ground + Vector3.new(0, height / 2 + 0.6, 0))
		if #workspace:GetPartBoundsInBox(box, size, params) > 0 then
			continue
		end
		placed += 1
		Builder.highrise(info.Model, "Hideout" .. v.Name, ground, v.Width, v.Depth, v.Floors, v.FloorHeight, {
			SlabColor = look[2] :: Color3,
			SlabMaterial = look[3] :: Enum.Material,
			ColumnColor = look[2] :: Color3,
			ColumnMaterial = Enum.Material.Metal,
			WallColor = look[1] :: Color3,
			WallMaterial = if v.Name == "Bunker" then Enum.Material.Concrete else look[3] :: Enum.Material,
			WallTransparency = 0,
			Windows = v.Windows,
			Stairwell = v.Stairwell,
			Health = v.Health,
		})
		-- cover inside: crates against the back wall (crouch behind them, peek over)
		if v.Crates > 0 then
			Builder.crates(info.Model, ground + Vector3.new(-v.Width / 2 + 4, 0, v.Depth / 2 - 4), v.Crates)
		end
	end
end

-- Interior seal (Config.Seal): fill holes and deep pits inside the island with a shallow
-- floor just under the waterline, and put ladders up high edges, so a survivor looking up at
-- the God and dashing backward never drops into an unseen pit. The island's outer rim stays
-- a lethal drop: a hole only counts if solid ground lies further out in that direction.
local function sealInterior(info: Types.MapInfo)
	local SE = Config.Seal
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { info.Model }
	params.RespectCanCollide = true
	local function cast(x: number, z: number, terrainOnly: boolean): number?
		local y = 300
		for _ = 1, 24 do
			local r = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -420, 0), params)
			if not r then
				return nil
			end
			if terrainOnly and r.Instance:GetAttribute("Structural") == true then
				y = r.Position.Y - 0.05
			else
				return r.Position.Y
			end
		end
		return y -- a tall stack of structure (a tower): solid ground underneath
	end
	local step = SE.Cell
	local deep = info.FluidStartY - 2
	local c = info.Center
	local n = math.floor((info.Radius + 30) / step)
	local anyY: { [number]: number } = {}
	local terY: { [number]: number } = {}
	local function key(ix: number, iz: number): number
		return (ix + 1000) * 4096 + (iz + 1000)
	end
	local reach = table.create(SE.Bearings, 0)
	local function bearing(ix: number, iz: number): number
		local a = math.atan2(iz, ix) % (2 * math.pi)
		return math.floor(a / (2 * math.pi) * SE.Bearings) % SE.Bearings + 1
	end
	for ix = -n, n do
		for iz = -n, n do
			local x, z = c.X + ix * step, c.Z + iz * step
			local a = cast(x, z, false)
			local t = cast(x, z, true)
			local k = key(ix, iz)
			if a then
				anyY[k] = a
			end
			if t then
				terY[k] = t
			end
			if a and a > deep then
				local b = bearing(ix, iz)
				reach[b] = math.max(reach[b], math.sqrt(ix * ix + iz * iz) * step)
			end
		end
		task.wait()
	end
	local function solid(ix: number, iz: number): boolean
		local a = anyY[key(ix, iz)]
		return a ~= nil and a > deep
	end
	-- a channel: ground on both sides across it (also fills channel mouths that run out to
	-- the rim, where there is no ground further out along the channel itself)
	local function enclosed(ix: number, iz: number): boolean
		local len = math.sqrt(ix * ix + iz * iz)
		if len < 0.5 then
			return true
		end
		local px, pz = -iz / len, ix / len
		local found = 0
		for _, side in { 1, -1 } do
			for s = 1, SE.ChannelCells do
				if solid(math.floor(ix + px * s * side + 0.5), math.floor(iz + pz * s * side + 0.5)) then
					found += 1
					break
				end
			end
		end
		return found == 2
	end
	local lava = info.HazardFloorY ~= nil or info.FluidMaterial == Enum.Material.CrackedLava
	local top = if info.HazardFloorY then info.HazardFloorY - SE.LavaDepth else info.FluidStartY + SE.FloorLift
	local fill: { [number]: boolean } = {}
	for ix = -n, n do
		for iz = -n, n do
			local k = key(ix, iz)
			local t = terY[k]
			if t ~= nil and t > deep then
				continue
			end
			-- inside the island: ground further out in this direction, or a channel
			local d = math.sqrt(ix * ix + iz * iz) * step
			if d < reach[bearing(ix, iz)] - SE.Margin or enclosed(ix, iz) then
				fill[k] = true
			end
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "Shallows"
	-- safe interior shallows look nothing like the lethal outer sea: bright sand under
	-- clear turquoise water, or dark basalt crust with glowing seams on lava maps
	local color = if lava then SE.CrustColor else SE.SandColor
	local material = if lava then Enum.Material.Basalt else Enum.Material.Sand
	local function skin(name: string, size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material, transparency: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = col
		p.Material = mat
		p.Transparency = transparency
		p.Parent = folder
	end
	-- merge each row's run of cells into one tile
	for iz = -n, n do
		local ix = -n
		while ix <= n do
			if fill[key(ix, iz)] then
				local start = ix
				while ix + 1 <= n and fill[key(ix + 1, iz)] do
					ix += 1
				end
				local count = ix - start + 1
				local tile = Instance.new("Part")
				tile.Name = "Shallows"
				tile.Anchored = true
				tile.Size = Vector3.new(count * step, 2, step)
				tile.CFrame = CFrame.new(c.X + (start + ix) / 2 * step, top - 1, c.Z + iz * step)
				tile.Color = color
				tile.Material = material
				tile.TopSurface = Enum.SurfaceType.Smooth
				tile.BottomSurface = Enum.SurfaceType.Smooth
				tile.CastShadow = false
				tile.CanTouch = false
				tile.Parent = folder
				local mid = CFrame.new(c.X + (start + ix) / 2 * step, top, c.Z + iz * step)
				if lava then
					skin("CrustSeam", Vector3.new(count * step - 2, 0.12, 0.7), mid + Vector3.new(0, 0.04, (iz % 2 - 0.5) * 2), SE.SeamColor, Enum.Material.Neon, 0)
				else
					skin("ShallowWater", Vector3.new(count * step, SE.WaterDepth, step), mid + Vector3.new(0, SE.WaterDepth / 2, 0), SE.WaterColor, Enum.Material.SmoothPlastic, SE.WaterTransparency)
				end
			end
			ix += 1
		end
	end
	-- ladders out of the shallows wherever the edge is too high to jump
	local ladders: { Vector3 } = {}
	for ix = -n, n do
		for iz = -n, n do
			local k = key(ix, iz)
			local open = anyY[k] == nil or (anyY[k] :: number) <= deep
			if not (fill[k] and open) or #ladders >= SE.MaxLadders then
				continue
			end
			for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
				local nk = key(ix + dir.X, iz + dir.Z)
				if fill[nk] then
					continue
				end
				local h = terY[nk] or anyY[nk]
				if not h or h - top < SE.LadderMinClimb then
					continue
				end
				local at = Vector3.new(c.X + ix * step, 0, c.Z + iz * step) + dir * (step / 2 - 1)
				local near = false
				for _, p in ladders do
					if (Vector3.new(p.X, 0, p.Z) - at).Magnitude < SE.LadderSpacing then
						near = true
						break
					end
				end
				if near then
					continue
				end
				table.insert(ladders, at)
				local height = h - top + 1
				local ladder = Instance.new("TrussPart")
				ladder.Name = "ShoreLadder"
				ladder.Anchored = true
				ladder.Size = Vector3.new(2, height, 2)
				ladder.CFrame = CFrame.new(at.X, top + height / 2, at.Z)
				ladder.Color = Color3.fromRGB(110, 100, 90)
				ladder.Material = Enum.Material.Metal
				ladder.CastShadow = false
				ladder.Parent = folder
				break
			end
		end
	end
	-- warning buoys just past the rim, where the lethal drop begins (not on walled arenas)
	if not info.Walled then
		for b = 1, SE.Bearings, SE.BuoyEvery do
			local r = reach[b]
			if r <= 0 then
				continue
			end
			local a = (b - 0.5) / SE.Bearings * 2 * math.pi
			local at = Vector3.new(c.X + math.cos(a) * (r + SE.BuoyOffset), info.FluidStartY + 0.5, c.Z + math.sin(a) * (r + SE.BuoyOffset))
			local body = if lava then SE.CrustColor else SE.BuoyColor
			skin("Buoy", Vector3.new(4, 2.4, 2.4), CFrame.new(at + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), body, Enum.Material.SmoothPlastic, 0)
			skin("BuoyLight", Vector3.new(1.2, 1.2, 1.2), CFrame.new(at + Vector3.new(0, 4.2, 0)), if lava then SE.SeamColor else SE.BuoyLight, Enum.Material.Neon, 0)
		end
		for _, p in folder:GetChildren() do
			if p.Name == "Buoy" and p:IsA("Part") then
				p.Shape = Enum.PartType.Cylinder
			end
		end
	end
	folder.Parent = info.Model
end

function MapService.Build(name: string): Types.MapInfo
	MapService.Clear()
	local builder = Builders[name]
	assert(builder, "Unknown map " .. name)
	local info: Types.MapInfo = builder.build(arena)
	addHideouts(info)
	addProps(info, name)
	Details.apply(name, info) -- reference-art dressing: rooftop clutter, signs, set dressing
	sealInterior(info) -- no hidden pits inside the island: shallow floors + ladders

	-- infinite sea (water or lava) under the island
	local s = Instance.new("Part")
	s.Name = "Sea"
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.Size = Vector3.new(2048, 1, 2048)
	s.CFrame = CFrame.new(info.Center.X, info.FluidStartY, info.Center.Z)
	local lavaSea = info.HazardFloorY ~= nil or info.FluidMaterial == Enum.Material.CrackedLava
	-- the lethal outer sea: dark opaque navy on water maps, glowing magma on lava maps
	-- (walled arenas keep their own flood fluid: liquid gold, a flash flood, molten brass)
	local keep = lavaSea or info.Walled == true
	s.Color = if keep then info.FluidColor else info.FluidColor:Lerp(Config.Seal.SeaShade, Config.Seal.SeaShadeAmount)
	s.Material = if keep then info.FluidMaterial else Enum.Material.SmoothPlastic
	s.Transparency = 0
	s.Parent = info.Model
	sea = s

	current = info
	DestructionService.SetArena(info.Model)
	return info
end

-- Raise the sea to FluidEndY over `duration` seconds.
function MapService.StartFluid(duration: number)
	local info = current
	local s = sea
	if not (info and s) then
		return
	end
	fluid = s
	local goal = CFrame.new(info.Center.X, info.FluidEndY, info.Center.Z)
	TweenService:Create(s, TweenInfo.new(duration * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = goal }):Play()
end

-- Current top surface of the rising fluid, or nil when not rising.
function MapService.GetFluidTop(): number?
	local f = fluid
	if not f or not f.Parent then
		return nil
	end
	return f.Position.Y + f.Size.Y / 2
end

-- Raycast straight down onto the arena to find the ground under an XZ point.
function MapService.GroundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arena }
	local y = 250
	for _ = 1, 24 do
		local result = workspace:Raycast(Vector3.new(position.X, y, position.Z), Vector3.new(0, -400, 0), params)
		if not result or result.Instance.Name == "Sea" then
			break
		end
		-- glass canopies (the Bio-Dome roof), see-through glass and non-solid trim are seen
		-- through: aim at what is under them (the client's OrbitCamera.ScreenToWorld matches)
		local hit = result.Instance
		local seeThrough = hit:GetAttribute("Canopy") == true or (hit:IsA("BasePart") and (not hit.CanCollide or hit.Transparency >= 0.5))
		if not seeThrough then
			return result.Position
		end
		y = result.Position.Y - 0.05
	end
	return Vector3.new(position.X, 0, position.Z)
end

-- The intact canopy part straight above a point, if any (impacts crack the dome over them).
function MapService.CanopyAbove(position: Vector3): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arena }
	local result = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, 250, 0), params)
	if result and result.Instance:GetAttribute("Canopy") == true and result.Instance:IsA("BasePart") then
		return result.Instance
	end
	return nil
end

-- Like GroundAt, but sees through destructible structures to the island surface below.
-- Each step restarts just inside the structural part it hit; rays ignore the part
-- that contains their origin, so the cast continues downward through it.
function MapService.TerrainAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arena }
	local y = 250
	for _ = 1, 16 do
		local result = workspace:Raycast(Vector3.new(position.X, y, position.Z), Vector3.new(0, -400, 0), params)
		if not result or result.Instance.Name == "Sea" then
			break
		end
		if result.Instance:GetAttribute("Structural") ~= true then
			return result.Position
		end
		y = result.Position.Y - 0.05
	end
	return Vector3.new(position.X, 0, position.Z)
end

function MapService.InBounds(position: Vector3): boolean
	local info = current
	if not info then
		return false
	end
	local flat = Vector3.new(position.X - info.Center.X, 0, position.Z - info.Center.Z)
	return flat.Magnitude <= math.max(Config.World.ArenaRadius, info.Radius + Config.World.BoundsMargin)
end

return MapService
