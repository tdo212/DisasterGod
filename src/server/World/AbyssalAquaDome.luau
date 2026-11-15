--!strict
-- Arena 10: Abyssal Aqua-Dome (the key is kept; there is no dome any more). An open-top
-- research complex on a deep-sea trench floor, lit by bioluminescence.
--   * Sheer trench walls glowing with cyan coral rise on the east and west sides
--     (impassable, with an invisible cap). The north and south ends of the deck drop off
--     into the black abyss: those are the lethal edges.
--   * A steel deck grid of wide walkways around five shallow glowing pools (about 1.8 studs
--     of water over a solid bed); steel bridges cross the two big pools.
--   * Three 4-5 storey research towers in a row (window holes, stairwell ladders to every
--     floor and the roof, antenna masts) linked by roof skybridges; a control hub and a
--     pump station.
--   * A yellow drilling rig on climbable lattice legs over the east pool, a crane gantry
--     over the south pool and two docked submarines.
-- Sudden death: the trench floods. Get up the towers and the rig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local DECK = Color3.fromRGB(78, 90, 104)
local DECK_DARK = Color3.fromRGB(50, 58, 70)
local STEEL = Color3.fromRGB(110, 124, 138)
local TOWER = Color3.fromRGB(96, 120, 150)
local ROCK = Color3.fromRGB(26, 36, 64)
local ROCK_LIGHT = Color3.fromRGB(36, 50, 86)
local CYAN = Color3.fromRGB(60, 235, 255)
local AQUA = Color3.fromRGB(40, 220, 200)
local POOL = Color3.fromRGB(70, 230, 240)
local YELLOW = Color3.fromRGB(240, 190, 40)
local WINDOW = Color3.fromRGB(255, 200, 110)
local SUB = Color3.fromRGB(70, 90, 110)

local CELL = 20
local NX, NZ = 10, 12 -- deck cells: x from -100, z from -120
local X0, Z0 = -100, -120
local DECK_Y = 0
local BED_Y = -3
local FLOOR_H = 11

-- pools as inclusive cell rectangles {i0, i1, j0, j1}
local POOLS = {
	{ 2, 3, 2, 3 }, -- A: west submarine pool
	{ 5, 7, 2, 3 }, -- B: south pool under the crane gantry
	{ 6, 8, 6, 7 }, -- C: east pool under the drilling rig
	{ 3, 4, 5, 5 }, -- D: small middle pool
	{ 0, 1, 8, 8 }, -- E: by the research towers
}

local AbyssalAquaDome = {}

local function deco(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function isPool(i: number, j: number): boolean
	for _, p in POOLS do
		if i >= p[1] and i <= p[2] and j >= p[3] and j <= p[4] then
			return true
		end
	end
	return false
end

local function cellRect(i0: number, i1: number, j0: number, j1: number): (Vector3, Vector3)
	local x0, x1 = X0 + i0 * CELL, X0 + (i1 + 1) * CELL
	local z0, z1 = Z0 + j0 * CELL, Z0 + (j1 + 1) * CELL
	return Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2), Vector3.new(x1 - x0, 0, z1 - z0)
end

local function deck(model: Model)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	-- the pool bed level under everything, then the walkway deck in merged runs per row
	Builder.block(g, "Seabed", Vector3.new(0, BED_Y - 4, 0), Vector3.new(NX * CELL, 8, NZ * CELL), DECK_DARK, Enum.Material.Slate)
	for j = 0, NZ - 1 do
		local i = 0
		while i < NX do
			if isPool(i, j) then
				i += 1
				continue
			end
			local start = i
			while i + 1 < NX and not isPool(i + 1, j) do
				i += 1
			end
			local c, s = cellRect(start, i, j, j)
			Builder.block(g, "Deck", c + Vector3.new(0, (DECK_Y + BED_Y) / 2, 0), Vector3.new(s.X, DECK_Y - BED_Y, s.Z), if j % 2 == 0 then DECK else DECK:Lerp(DECK_DARK, 0.25), Enum.Material.DiamondPlate)
			i += 1
		end
	end
	-- glowing shallow water in each pool, with a low yellow kerb round it
	for _, p in POOLS do
		local c, s = cellRect(p[1], p[2], p[3], p[4])
		local water = Builder.block(g, "PoolWater", c + Vector3.new(0, BED_Y + 0.9, 0), Vector3.new(s.X, 1.8, s.Z), POOL, Enum.Material.SmoothPlastic)
		water.Transparency = 0.35
		deco(water)
		deco(Builder.block(g, "PoolGlow", c + Vector3.new(0, BED_Y + 0.05, 0), Vector3.new(s.X - 4, 0.1, s.Z - 4), AQUA, Enum.Material.Neon))
		for _, e in { { Vector3.new(0, 0, s.Z / 2), true }, { Vector3.new(0, 0, -s.Z / 2), true }, { Vector3.new(s.X / 2, 0, 0), false }, { Vector3.new(-s.X / 2, 0, 0), false } } do
			local off, alongX = e[1] :: Vector3, e[2] :: boolean
			local kerb = Builder.block(g, "Kerb", c + off + Vector3.new(0, DECK_Y + 0.4, 0), if alongX then Vector3.new(s.X, 0.8, 1) else Vector3.new(1, 0.8, s.Z), YELLOW, Enum.Material.Metal)
			kerb.CastShadow = false
		end
	end
end

-- Sheer trench walls east and west, glowing with coral.
local function trench(model: Model, rng: Random)
	local f = Instance.new("Folder")
	f.Name = "TrenchWalls"
	f.Parent = model
	for _, sx in { -1, 1 } do
		local face = sx * (NX * CELL / 2)
		-- the walls stop at the deck ends, so the open ends stay a clean drop into the abyss
		for k = 0, 5 do
			local z = -100 + k * 40
			local depth = rng:NextNumber(30, 44)
			local h = rng:NextNumber(80, 110)
			local col = ROCK:Lerp(ROCK_LIGHT, rng:NextNumber())
			Builder.block(f, "TrenchWall", Vector3.new(face + sx * (depth / 2 - rng:NextNumber(0, 3)), h / 2 - 30, z), Vector3.new(depth, h, 44), col, Enum.Material.Slate)
			-- bioluminescent coral streaks on the inner face
			for n = 1, 2 do
				local y = rng:NextNumber(6, h - 40)
				local streak = Builder.block(f, "Bioglow", Vector3.new(face - sx * 0.6, y, z + rng:NextNumber(-14, 14)), Vector3.new(0.6, rng:NextNumber(8, 20), rng:NextNumber(1.2, 2.4)), if n == 1 then CYAN else AQUA, Enum.Material.Neon)
				streak.CFrame *= CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, 0)
				deco(streak)
			end
		end
		Builder.boundary(f, Vector3.new(face + sx * 20, 130, 0), Vector3.new(40, 200, 244))
	end
end

-- A research tower: steel-blue walls, lit window bands, an antenna mast on the roof.
local function researchTower(model: Model, at: Vector3, floors: number): (Model, number)
	local tower, roofY = Builder.highrise(model, "ResearchTower", at, 20, 20, floors, FLOOR_H, {
		SlabColor = DECK,
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = STEEL,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = TOWER,
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		Stairwell = true,
		Windows = true,
	})
	Builder.facadeTrim(tower, WINDOW, Enum.Material.Neon, STEEL, Enum.Material.Metal)
	local mast = Builder.building(model, "AntennaMast")
	Builder.latticeTower(model, mast, Vector3.new(at.X + 4, roofY, at.Z + 4), 14, 4, STEEL, 1)
	local beacon = Builder.part(mast, { Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(at.X + 4, roofY + 15, at.Z + 4), Color = Color3.fromRGB(255, 70, 60), Material = Enum.Material.Neon })
	Builder.structural(beacon, 2, false, 10)
	Builder.restsOn(mast, tower)
	return tower, roofY
end

-- The yellow drilling rig over the east pool: four climbable lattice legs, a working deck,
-- a derrick and a drill string down into the water.
local function drillRig(model: Model, center: Vector3)
	local rig = Builder.building(model, "DrillRig")
	local hx, hz, top = 16, 12, 18
	for _, c in { Vector3.new(hx, 0, hz), Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, -hz), Vector3.new(-hx, 0, -hz) } do
		local leg = Builder.part(rig, { Name = "RigLeg", Class = "TrussPart", Size = Vector3.new(2, top - BED_Y, 2), CFrame = CFrame.new(center + c + Vector3.new(0, (top + BED_Y) / 2, 0)), Color = YELLOW, Material = Enum.Material.Metal })
		Builder.structural(leg, 1, true, 140)
	end
	for _, z in { hz, -hz } do
		local beam = Builder.block(rig, "RigBeam", center + Vector3.new(0, top - 1.5, z), Vector3.new(hx * 2 + 2, 2, 2), YELLOW, Enum.Material.Metal)
		Builder.structural(beam, 2, false, 90)
	end
	for _, x in { -hx / 2, hx / 2 } do
		local plate = Builder.block(rig, "RigDeck", center + Vector3.new(x, top, 0), Vector3.new(hx, 1, hz * 2 + 2), DECK, Enum.Material.DiamondPlate)
		Builder.structural(plate, 2, false, 90)
	end
	for _, z in { hz + 1, -hz - 1 } do
		local rail = Builder.block(rig, "RigRail", center + Vector3.new(0, top + 2, z), Vector3.new(hx * 2 + 2, 0.4, 0.4), YELLOW, Enum.Material.Metal)
		rail.CastShadow = false
		Builder.structural(rail, 2, false, 15)
	end
	local cabin = Builder.block(rig, "RigCabin", center + Vector3.new(-hx + 5, top + 4, -hz + 4), Vector3.new(8, 7, 6), STEEL, Enum.Material.Metal)
	Builder.structural(cabin, 3, false, 70)
	local derrickBase = center + Vector3.new(4, top + 0.5, 0)
	Builder.latticeTower(model, rig, derrickBase, 26, 8, YELLOW, 3)
	local drill = Builder.cylinder(rig, "DrillString", center + Vector3.new(4, (top + BED_Y) / 2, 0), top - BED_Y, 1.4, STEEL, Enum.Material.Metal)
	drill.CanCollide = false
	Builder.structural(drill, 3, false, 30)
end

-- A crane gantry over the south pool: A-frame lattice legs, a top beam and a trolley.
local function gantry(model: Model, center: Vector3, span: number)
	local g = Builder.building(model, "CraneGantry")
	local h = 24
	for _, x in { -span / 2, span / 2 } do
		for _, z in { -6, 6 } do
			local leg = Builder.part(g, { Name = "GantryLeg", Class = "TrussPart", Size = Vector3.new(2, h, 2), CFrame = CFrame.new(center + Vector3.new(x, h / 2, z)), Color = YELLOW, Material = Enum.Material.Metal })
			Builder.structural(leg, 1, true, 120)
		end
	end
	for _, z in { -6, 6 } do
		local beam = Builder.block(g, "GantryBeam", center + Vector3.new(0, h + 1, z), Vector3.new(span + 4, 2, 2), YELLOW, Enum.Material.Metal)
		Builder.structural(beam, 2, false, 90)
	end
	local trolley = Builder.block(g, "Trolley", center + Vector3.new(6, h + 2.5, 0), Vector3.new(6, 3, 14), STEEL, Enum.Material.Metal)
	Builder.structural(trolley, 2, false, 40)
	local cable = Builder.block(g, "Cable", center + Vector3.new(6, h - 6, 0), Vector3.new(0.4, 14, 0.4), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	cable.CanCollide = false
	Builder.structural(cable, 2, false, 10)
	local hook = Builder.block(g, "Hook", center + Vector3.new(6, h - 13.5, 0), Vector3.new(2, 2, 2), YELLOW, Enum.Material.Metal)
	Builder.structural(hook, 2, false, 15)
end

-- A small docked submarine, half under the pool surface.
local function submarine(model: Model, at: Vector3, yaw: number)
	local m = Builder.building(model, "Submarine")
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local hull = Builder.part(m, { Name = "Hull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(18, 7, 7), CFrame = cf, Color = SUB, Material = Enum.Material.Metal })
	Builder.structural(hull, 1, true, 200)
	for _, e in { 9, -9 } do
		local cap = Builder.part(m, { Name = "HullCap", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, CFrame = cf * CFrame.new(e, 0, 0), Color = SUB, Material = Enum.Material.Metal })
		Builder.structural(cap, 1, false, 80)
	end
	local tower = Builder.part(m, { Name = "Sail", Size = Vector3.new(5, 4, 3), CFrame = cf * CFrame.new(1, 5, 0), Color = YELLOW, Material = Enum.Material.Metal })
	Builder.structural(tower, 2, false, 50)
	local port = Builder.part(m, { Name = "Porthole", Size = Vector3.new(10, 1, 0.3), CFrame = cf * CFrame.new(-1, 0.5, 3.5), Color = CYAN, Material = Enum.Material.Neon, CastShadow = false })
	port.CanCollide = false
	Builder.structural(port, 1, false, 10)
end

-- Jellyfish drifting high over the trench (decor).
local function jellyfish(model: Model, at: Vector3, color: Color3)
	local bell = Builder.part(model, { Name = "Jellyfish", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 7, 9), CFrame = CFrame.new(at), Color = color, Material = Enum.Material.Neon, Transparency = 0.35 })
	deco(bell)
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3
		local t = Builder.part(model, { Name = "Tentacle", Size = Vector3.new(0.4, 12, 0.4), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 2, -8, math.sin(a) * 2)), Color = color, Material = Enum.Material.Neon, Transparency = 0.5 })
		deco(t)
	end
end

function AbyssalAquaDome.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "AbyssalAquaDome"
	model.Parent = parent
	local rng = Random.new()

	deck(model)
	trench(model, rng)

	-- three research towers in a row on the north deck, linked roof to roof
	local t1, r1 = researchTower(model, Vector3.new(-84, 0, 74), 5)
	local t2, r2 = researchTower(model, Vector3.new(-50, 0, 74), 5)
	local t3, r3 = researchTower(model, Vector3.new(-16, 0, 74), 4)
	local function skybridge(a: Vector3, b: Vector3, base: Model)
		local bridge = Builder.bridge(model, "Skybridge", a, b, 12, DECK, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)
		Builder.restsOn(bridge, base)
	end
	skybridge(Vector3.new(-75, r1 + 0.5, 70), Vector3.new(-59, r2 + 0.5, 70), t1)
	skybridge(Vector3.new(-41, r2 + 0.5, 70), Vector3.new(-25, r3 + 0.5, 70), t3)

	-- the control hub and the pump station
	local hubStyle: Builder.HighriseStyle = {
		SlabColor = DECK,
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = YELLOW,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(130, 146, 160),
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		Stairwell = true,
		Windows = true,
	}
	local hub = Builder.highrise(model, "ControlHub", Vector3.new(-70, 0, -10), 26, 24, 3, FLOOR_H, hubStyle)
	Builder.facadeTrim(hub, CYAN, Enum.Material.Neon)
	local pump = Builder.highrise(model, "PumpStation", Vector3.new(78, 0, -90), 22, 20, 3, FLOOR_H, hubStyle)
	Builder.facadeTrim(pump, YELLOW, Enum.Material.Metal)
	Builder.highrise(model, "Lab", Vector3.new(70, 0, 92), 24, 20, 2, FLOOR_H, hubStyle)

	-- the drilling rig over pool C and the crane gantry over pool B
	local c = cellRect(6, 8, 6, 7)
	drillRig(model, Vector3.new(c.X, 0, c.Z))
	local b = cellRect(5, 7, 2, 3)
	gantry(model, Vector3.new(b.X, 0, b.Z), 64)
	-- steel bridges across the two big pools
	Builder.bridge(model, "PoolBridge", Vector3.new(b.X - 12, DECK_Y + 0.5, b.Z - 22), Vector3.new(b.X - 12, DECK_Y + 0.5, b.Z + 22), 12, DECK, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)
	Builder.bridge(model, "PoolBridge", Vector3.new(c.X - 24, DECK_Y + 0.5, c.Z - 22), Vector3.new(c.X - 24, DECK_Y + 0.5, c.Z + 22), 12, DECK, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)

	-- submarines docked in pools A and B
	local a = cellRect(2, 3, 2, 3)
	submarine(model, Vector3.new(a.X, BED_Y + 2.5, a.Z), math.rad(90))
	submarine(model, Vector3.new(b.X + 14, BED_Y + 2.5, b.Z + 4), 0)

	for _, j in { { Vector3.new(-70, 70, -40), CYAN }, { Vector3.new(60, 80, 40), Color3.fromRGB(150, 120, 255) }, { Vector3.new(-30, 90, 110), AQUA }, { Vector3.new(40, 64, -110), CYAN } } do
		jellyfish(model, j[1] :: Vector3, j[2] :: Color3)
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-90, 3, 30), Vector3.new(-30, 3, 30), Vector3.new(0, 3, 50), Vector3.new(10, 3, -20),
		Vector3.new(-90, 3, -90), Vector3.new(-10, 3, -100), Vector3.new(90, 3, -40), Vector3.new(90, 3, 60),
		Vector3.new(0, 3, 100), Vector3.new(-50, 3, 110),
		Vector3.new(-50, 3.5, 74), Vector3.new(-70, 3.5, -10), -- inside a tower and the hub
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "AbyssalAquaDome",
		DisplayName = "Abyssal Aqua-Dome",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -16,
		FluidEndY = 14,
		FluidColor = Color3.fromRGB(30, 110, 150),
		FluidMaterial = Enum.Material.SmoothPlastic,
		HazardFloorY = nil,
		FluidName = "FLOODWATER",
		Lighting = "Abyss",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 130,
	}
end

return AbyssalAquaDome
