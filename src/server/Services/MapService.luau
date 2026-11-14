--!strict
-- MapService: builds / clears the active arena and runs the sudden-death rising fluid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
}

local DestructionService = require(script.Parent.DestructionService)
local Builder = require(World.Builder)

-- Hideout palette per lighting preset (wall, roof, material).
local HIDEOUT_LOOK: { [string]: { Color3 | Enum.Material } } = {
	Desert = { Color3.fromRGB(205, 170, 120), Color3.fromRGB(150, 110, 70), Enum.Material.Sandstone },
	Arctic = { Color3.fromRGB(225, 235, 245), Color3.fromRGB(120, 140, 170), Enum.Material.SmoothPlastic },
	Night = { Color3.fromRGB(70, 60, 95), Color3.fromRGB(45, 40, 60), Enum.Material.Metal },
	Volcanic = { Color3.fromRGB(110, 90, 85), Color3.fromRGB(70, 55, 50), Enum.Material.Slate },
	Tempest = { Color3.fromRGB(110, 116, 124), Color3.fromRGB(70, 74, 80), Enum.Material.Metal },
	Foundry = { Color3.fromRGB(150, 72, 52), Color3.fromRGB(58, 58, 68), Enum.Material.Brick },
	Conservatory = { Color3.fromRGB(232, 238, 236), Color3.fromRGB(176, 186, 190), Enum.Material.SmoothPlastic },
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

function MapService.Init()
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
		if placed >= H.PerMap then
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

function MapService.Build(name: string): Types.MapInfo
	MapService.Clear()
	local builder = Builders[name]
	assert(builder, "Unknown map " .. name)
	local info: Types.MapInfo = builder.build(arena)
	addHideouts(info)

	-- infinite sea (water or lava) under the island
	local s = Instance.new("Part")
	s.Name = "Sea"
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.Size = Vector3.new(2048, 1, 2048)
	s.CFrame = CFrame.new(info.Center.X, info.FluidStartY, info.Center.Z)
	s.Color = info.FluidColor
	s.Material = info.FluidMaterial
	s.Transparency = if info.FluidMaterial == Enum.Material.Glass then 0.15 else 0
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
	for _ = 1, 8 do
		local result = workspace:Raycast(Vector3.new(position.X, y, position.Z), Vector3.new(0, -400, 0), params)
		if not result or result.Instance.Name == "Sea" then
			break
		end
		-- glass canopies (the Bio-Dome roof) are seen through: aim at what is under them
		if result.Instance:GetAttribute("Canopy") ~= true then
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
