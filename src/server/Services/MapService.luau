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
}

local DestructionService = require(script.Parent.DestructionService)

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

function MapService.Build(name: string): Types.MapInfo
	MapService.Clear()
	local builder = Builders[name]
	assert(builder, "Unknown map " .. name)
	local info: Types.MapInfo = builder.build(arena)

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
	local origin = Vector3.new(position.X, 250, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
	if result and result.Instance.Name ~= "Sea" then
		return result.Position
	end
	return Vector3.new(position.X, 0, position.Z)
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
	return flat.Magnitude <= Config.World.ArenaRadius
end

return MapService
