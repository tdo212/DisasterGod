--!strict
-- Arena 2: Magma Core Station. Four basalt quadrants over a lava sea, linked by
-- elevated steel catwalks on climbable truss supports. Snap a support and the
-- catwalk drops into the magma. Cooling silos are volatile and chain-explode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local BASALT = Color3.fromRGB(58, 50, 52)
local BASALT_LIGHT = Color3.fromRGB(85, 75, 75)
local CONCRETE = Color3.fromRGB(175, 175, 180)
local STEEL_RED = Color3.fromRGB(200, 45, 35)
local STEEL_YELLOW = Color3.fromRGB(240, 190, 30)
local STEEL_GRAY = Color3.fromRGB(140, 142, 150)
local SILO_WHITE = Color3.fromRGB(215, 215, 222)
local DARK = Color3.fromRGB(40, 40, 46)
local LAVA = Color3.fromRGB(255, 95, 20)

local GROUND = 6 -- quadrant surface
local DECK = 18 -- catwalk / hub height

local MagmaCore = {}

local function catwalk(model: Model, name: string, a: Vector3, b: Vector3)
	local walk = Builder.building(model, name)
	local flatA = Vector3.new(a.X, DECK, a.Z)
	local flatB = Vector3.new(b.X, DECK, b.Z)
	local dir = (flatB - flatA)
	local length = dir.Magnitude
	local unit = dir.Unit
	local segs = math.max(1, math.ceil(length / 8))
	local segLen = length / segs
	for i = 1, segs do
		local center = flatA + unit * segLen * (i - 0.5)
		local deck = Builder.part(walk, {
			Name = "Deck",
			Size = Vector3.new(5, 1, segLen + 0.1),
			CFrame = CFrame.lookAt(center, center + unit),
			Color = STEEL_GRAY,
			Material = Enum.Material.DiamondPlate,
		})
		Builder.structural(deck, 2, false)
		for _, side in { -2.4, 2.4 } do
			local railPos = center + CFrame.lookAt(Vector3.zero, unit).RightVector * side + Vector3.new(0, 1.6, 0)
			local rail = Builder.part(walk, {
				Name = "Rail",
				Size = Vector3.new(0.3, 0.3, segLen),
				CFrame = CFrame.lookAt(railPos, railPos + unit),
				Color = STEEL_YELLOW,
				Material = Enum.Material.Metal,
			})
			Builder.structural(rail, 2, false, 25)
		end
	end
	-- truss supports down into the lava/rock every ~16 studs
	local supports = math.max(2, math.ceil(length / 16) + 1)
	for i = 0, supports - 1 do
		local p = flatA + unit * (length * i / (supports - 1))
		local bottom = -6
		local leg = Builder.part(walk, {
			Name = "Support",
			Class = "TrussPart",
			Size = Vector3.new(2, DECK - 0.5 - bottom, 2),
			CFrame = CFrame.new(p.X, (DECK - 0.5 + bottom) / 2, p.Z),
			Color = STEEL_RED,
			Material = Enum.Material.Metal,
		})
		Builder.structural(leg, 1, true)
	end
end

local function pad(model: Model, center: Vector3, rampDir: Vector3)
	local p = Builder.building(model, "Pad")
	for _, corner in { Vector3.new(6, 0, 6), Vector3.new(-6, 0, 6), Vector3.new(6, 0, -6), Vector3.new(-6, 0, -6) } do
		local leg = Builder.part(p, {
			Name = "Leg",
			Class = "TrussPart",
			Size = Vector3.new(2, DECK - GROUND, 2),
			CFrame = CFrame.new(center.X + corner.X, (DECK + GROUND) / 2 - 0.5, center.Z + corner.Z),
			Color = STEEL_RED,
			Material = Enum.Material.Metal,
		})
		Builder.structural(leg, 1, true)
	end
	local top = Builder.block(p, "Top", Vector3.new(center.X, DECK - 0.25, center.Z), Vector3.new(15, 1.5, 15), CONCRETE, Enum.Material.Concrete)
	Builder.structural(top, 2, false)
	-- stair ramp from the quadrant floor up to the pad, running outward along rampDir
	local rampLen = 22
	local rc = Vector3.new(center.X, (DECK + GROUND) / 2, center.Z) + rampDir * (7.5 + rampLen / 2)
	Builder.ramp(model, "PadRamp", CFrame.lookAt(rc, rc + rampDir), Vector3.new(7, DECK - GROUND, rampLen), STEEL_GRAY, Enum.Material.DiamondPlate)
end

local function quadrants(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model
	for _, s in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		Builder.block(ground, "Quadrant", Vector3.new(s.X * 51, 0, s.Z * 51), Vector3.new(90, 12, 90), BASALT, Enum.Material.Basalt)
		Builder.block(ground, "QuadrantTop", Vector3.new(s.X * 51, 6.1, s.Z * 51), Vector3.new(86, 0.2, 86), BASALT_LIGHT, Enum.Material.Slate)
		Builder.block(ground, "Outcrop", Vector3.new(s.X * 100, -1, s.Z * 40), Vector3.new(10, 10, 30), BASALT, Enum.Material.Basalt)
		Builder.block(ground, "Outcrop", Vector3.new(s.X * 40, -1, s.Z * 100), Vector3.new(30, 10, 10), BASALT, Enum.Material.Basalt)
	end
	-- central plaza under the hub + rock land bridges over the narrow lava channels:
	-- the whole station is one walkable platform
	Builder.block(ground, "HubPlaza", Vector3.new(0, 0, 0), Vector3.new(34, 12, 34), BASALT, Enum.Material.Basalt)
	Builder.block(ground, "HubPlazaTop", Vector3.new(0, 6.1, 0), Vector3.new(32, 0.2, 32), BASALT_LIGHT, Enum.Material.Slate)
	for _, b in { Vector3.new(0, 0, 60), Vector3.new(0, 0, -60), Vector3.new(60, 0, 0), Vector3.new(-60, 0, 0) } do
		local size = if b.X == 0 then Vector3.new(16, 12, 18) else Vector3.new(18, 12, 16)
		Builder.block(ground, "LandBridge", b, size, BASALT, Enum.Material.Basalt)
		Builder.block(ground, "LandBridgeTop", b + Vector3.new(0, 6.1, 0), size - Vector3.new(2, 11.8, 2), BASALT_LIGHT, Enum.Material.Slate)
	end
	-- glowing lava vents on the quadrant floors (decorative hot spots)
	for _, p in { Vector3.new(30, 6.15, 70), Vector3.new(-72, 6.15, -28), Vector3.new(72, 6.15, -75) } do
		local vent = Builder.block(ground, "Vent", p, Vector3.new(8, 0.2, 8), LAVA, Enum.Material.Neon)
		vent.CanCollide = false
		Builder.hazard(vent, Config.Hazards.VentDamagePerSecond)
	end
end

local function hub(model: Model)
	local h = Builder.building(model, "RadarHub")
	for _, c in { Vector3.new(13, 0, 13), Vector3.new(-13, 0, 13), Vector3.new(13, 0, -13), Vector3.new(-13, 0, -13) } do
		local leg = Builder.part(h, {
			Name = "Leg",
			Class = "TrussPart",
			Size = Vector3.new(3, DECK + 6, 3),
			CFrame = CFrame.new(c.X, (DECK - 6) / 2 - 0.5, c.Z),
			Color = STEEL_RED,
			Material = Enum.Material.Metal,
		})
		Builder.structural(leg, 1, true)
	end
	for _, c in { Vector3.new(8, 0, 8), Vector3.new(-8, 0, 8), Vector3.new(8, 0, -8), Vector3.new(-8, 0, -8) } do
		local tile = Builder.block(h, "Platform", Vector3.new(c.X, DECK - 0.5, c.Z), Vector3.new(16, 2, 16), CONCRETE, Enum.Material.Concrete)
		Builder.structural(tile, 2, false)
	end
	-- octagonal base walls (supports for the dome), door gap facing south
	for i = 0, 7 do
		if i == 4 then
			continue
		end
		local angle = i * math.pi / 4
		local pos = Vector3.new(math.sin(angle) * 9, DECK + 4, math.cos(angle) * 9)
		local wall = Builder.part(h, {
			Name = "DomeWall",
			Size = Vector3.new(7.6, 8, 1.2),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, DECK + 4, 0)),
			Color = SILO_WHITE,
			Material = Enum.Material.Concrete,
		})
		Builder.structural(wall, 2, true)
	end
	local stripe = Builder.block(h, "HazardStripe", Vector3.new(0, DECK + 8.5, -9.5), Vector3.new(8, 1, 0.5), STEEL_YELLOW, Enum.Material.SmoothPlastic)
	Builder.structural(stripe, 3, false, 20)
	local dome = Builder.part(h, {
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(20, 20, 20),
		CFrame = CFrame.new(0, DECK + 9, 0),
		Color = Color3.fromRGB(240, 240, 245),
		Material = Enum.Material.SmoothPlastic,
	})
	Builder.structural(dome, 3, false, 200)
	local antenna = Builder.block(h, "Antenna", Vector3.new(0, DECK + 22, 0), Vector3.new(0.8, 8, 0.8), DARK, Enum.Material.Metal)
	Builder.structural(antenna, 3, false, 30)
end

local function silos(model: Model)
	local farm = Builder.building(model, "CoolingSilos")
	local spots = { Vector3.new(66, GROUND, 24), Vector3.new(78, GROUND, 46), Vector3.new(62, GROUND, 66) }
	for _, base in spots do
		for i = 1, 2 do
			local seg = Builder.cylinder(farm, "Silo", base + Vector3.new(0, 6 * (2 * i - 1), 0), 12, 10, SILO_WHITE, Enum.Material.Metal)
			Builder.structural(seg, i, true, 150)
			seg:SetAttribute("Volatile", true)
		end
		local cap = Builder.cylinder(farm, "SiloCap", base + Vector3.new(0, 24.5, 0), 1, 8, DARK, Enum.Material.Metal)
		Builder.structural(cap, 3, false)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Rate = 4
		smoke.Lifetime = NumberRange.new(4, 6)
		smoke.Speed = NumberRange.new(4, 6)
		smoke.Size = NumberSequence.new(3, 9)
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = cap
	end
	-- connecting pipes
	for i = 1, #spots - 1 do
		local a = spots[i] + Vector3.new(0, 16, 0)
		local b = spots[i + 1] + Vector3.new(0, 16, 0)
		local pipe = Builder.part(farm, {
			Name = "Pipe",
			Size = Vector3.new(1.5, 1.5, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = STEEL_GRAY,
			Material = Enum.Material.Metal,
		})
		Builder.structural(pipe, 3, false, 40)
	end
	-- red fuel barrels (volatile)
	for _, p in { Vector3.new(30, GROUND, 30), Vector3.new(34, GROUND, 28), Vector3.new(-30, GROUND, -30), Vector3.new(30, GROUND, -60) } do
		local barrels = Builder.building(model, "Barrel")
		local barrel = Builder.cylinder(barrels, "Barrel", p + Vector3.new(0, 2, 0), 4, 3, STEEL_RED, Enum.Material.Metal)
		Builder.structural(barrel, 1, true, 40)
		barrel:SetAttribute("Volatile", true)
	end
end

local function industry(model: Model)
	-- SW crane
	local crane = Builder.building(model, "Crane")
	local top = Builder.latticeTower(model, crane, Vector3.new(-62, GROUND, -60), 30, 6, STEEL_YELLOW)
	local boom = Builder.block(crane, "Boom", Vector3.new(-62 + 12, top + 1, -60), Vector3.new(30, 2, 2), STEEL_YELLOW, Enum.Material.Metal)
	Builder.structural(boom, 2, false)
	local cab = Builder.block(crane, "Cab", Vector3.new(-62, top + 2.5, -60), Vector3.new(6, 4, 6), DARK, Enum.Material.Metal)
	Builder.structural(cab, 2, false)
	local weight = Builder.block(crane, "Counterweight", Vector3.new(-62 - 8, top, -60), Vector3.new(5, 4, 4), CONCRETE, Enum.Material.Concrete)
	Builder.structural(weight, 2, false)

	-- NW twin red lattice towers joined by a sky beam (high ground)
	local towers = Builder.building(model, "RedTowers")
	local t1 = Builder.latticeTower(model, towers, Vector3.new(-62, GROUND, 52), 38, 8, STEEL_RED)
	Builder.latticeTower(model, towers, Vector3.new(-32, GROUND, 70), 38, 8, STEEL_RED)
	for _, c in { Vector3.new(-62, 0, 52), Vector3.new(-32, 0, 70) } do
		local deck = Builder.block(towers, "TowerDeck", Vector3.new(c.X, t1 + 0.5, c.Z), Vector3.new(10, 1, 10), STEEL_GRAY, Enum.Material.DiamondPlate)
		Builder.structural(deck, 2, false)
	end
	local a, b = Vector3.new(-62, t1 + 0.5, 52), Vector3.new(-32, t1 + 0.5, 70)
	local skyBeam = Builder.part(towers, {
		Name = "SkyBeam",
		Size = Vector3.new(3, 1, (b - a).Magnitude),
		CFrame = CFrame.lookAt((a + b) / 2, b),
		Color = STEEL_YELLOW,
		Material = Enum.Material.DiamondPlate,
	})
	Builder.structural(skyBeam, 2, false)

	-- SE control block (3 storeys)
	Builder.highrise(model, "ControlBlock", Vector3.new(55, GROUND, -55), 26, 18, 3, 10, {
		SlabColor = CONCRETE,
		SlabMaterial = Enum.Material.Concrete,
		ColumnColor = STEEL_GRAY,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(230, 120, 40),
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		OpenSide = "West",
	})
	Builder.crates(model, Vector3.new(-25, GROUND, -50), 5)
	Builder.crates(model, Vector3.new(70, GROUND, -25), 3)

	local board = Builder.block(model, "SignBoard", Vector3.new(-50, GROUND + 7, -86), Vector3.new(26, 8, 1), DARK, Enum.Material.Metal)
	Builder.sign(board, Enum.NormalId.Front, "MAGMA CORE STATION", STEEL_YELLOW)
	Builder.sign(board, Enum.NormalId.Back, "MAGMA CORE STATION", STEEL_YELLOW)
	for _, x in { -60, -40 } do
		Builder.block(model, "SignLeg", Vector3.new(x, GROUND + 1.5, -86), Vector3.new(1.5, 3, 1.5), STEEL_YELLOW, Enum.Material.Metal)
	end
end

local function refineryAndStacks(model: Model)
	-- SW refinery block (4 storeys, open west side ladder)
	Builder.highrise(model, "Refinery", Vector3.new(-70, GROUND, -28), 18, 14, 4, 9, {
		SlabColor = CONCRETE,
		SlabMaterial = Enum.Material.Concrete,
		ColumnColor = STEEL_RED,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(95, 95, 105),
		WallMaterial = Enum.Material.CorrodedMetal,
		WallTransparency = 0,
		OpenSide = "West",
	})
	-- SE smokestacks: stacked drums that topple toward the hub
	for _, base in { Vector3.new(76, GROUND, -76), Vector3.new(24, GROUND, -76) } do
		local stack = Builder.building(model, "Smokestack")
		for i = 1, 4 do
			local drum = Builder.cylinder(stack, "Drum", base + Vector3.new(0, (i - 0.5) * 8, 0), 8, 6 - i * 0.4, if i % 2 == 0 then SILO_WHITE else STEEL_RED, Enum.Material.Metal)
			Builder.structural(drum, i, true, 160)
		end
		local smoke = Instance.new("ParticleEmitter")
		smoke.Rate = 6
		smoke.Lifetime = NumberRange.new(5, 7)
		smoke.Speed = NumberRange.new(5, 8)
		smoke.Size = NumberSequence.new(4, 12)
		smoke.Transparency = NumberSequence.new(0.3, 1)
		smoke.Color = ColorSequence.new(Color3.fromRGB(80, 75, 75))
		smoke.EmissionDirection = Enum.NormalId.Top
		local top = Builder.block(stack, "Vent", base + Vector3.new(0, 32.5, 0), Vector3.new(4, 1, 4), DARK, Enum.Material.Metal)
		Builder.structural(top, 5, false, 40)
		smoke.Parent = top
		Builder.fallDirection(stack, Vector3.new(-base.X, 0, -base.Z))
	end
	-- pipe gantry from the silo farm toward the hub pad
	local gantry = Builder.bridge(model, "PipeGantry", Vector3.new(60, DECK, 22), Vector3.new(46, DECK, 34), 4, STEEL_GRAY, Enum.Material.DiamondPlate, STEEL_YELLOW, STEEL_RED, 90)
	gantry:SetAttribute("Gantry", true)
end

-- Larger destructible plant buildings on the free quadrant ground.
local function district(model: Model)
	local industrial: Builder.HighriseStyle = {
		SlabColor = CONCRETE,
		SlabMaterial = Enum.Material.Concrete,
		ColumnColor = STEEL_GRAY,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(150, 60, 45),
		WallMaterial = Enum.Material.CorrodedMetal,
		WallTransparency = 0,
	}
	local forge = table.clone(industrial)
	forge.OpenSide = "East"
	Builder.highrise(model, "ForgeHall", Vector3.new(-69, GROUND, 78), 24, 20, 3, 11, forge)
	local pump = table.clone(industrial)
	pump.WallColor = Color3.fromRGB(230, 120, 40)
	pump.WallMaterial = Enum.Material.Metal
	pump.OpenSide = "West"
	Builder.highrise(model, "PumpStation", Vector3.new(6, GROUND, -63), 24, 20, 3, 11, pump)
	local lab = table.clone(industrial)
	lab.WallColor = Color3.fromRGB(190, 200, 210)
	lab.WallMaterial = Enum.Material.Glass
	lab.WallTransparency = 0.35
	lab.OpenSide = "East"
	Builder.highrise(model, "AssayLab", Vector3.new(3, GROUND, 66), 24, 20, 4, 10, lab)
	local depot = table.clone(industrial)
	depot.WallColor = DARK
	depot.OpenSide = "East"
	Builder.highrise(model, "OreDepot", Vector3.new(63, GROUND, 0), 20, 20, 3, 11, depot)
end

function MagmaCore.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "MagmaCore"
	model.Parent = parent

	quadrants(model)
	district(model)
	hub(model)

	local pads = {
		{ Vector3.new(40, 0, 40), Vector3.new(0, 0, 1) },
		{ Vector3.new(-40, 0, 40), Vector3.new(-1, 0, 0) },
		{ Vector3.new(40, 0, -40), Vector3.new(1, 0, 0) },
		{ Vector3.new(-40, 0, -40), Vector3.new(0, 0, -1) },
	}
	for _, p in pads do
		pad(model, p[1], p[2])
		-- hub corner to pad
		local corner = Vector3.new(math.sign(p[1].X) * 15, 0, math.sign(p[1].Z) * 15)
		catwalk(model, "Catwalk", corner, p[1] - Vector3.new(math.sign(p[1].X) * 7, 0, math.sign(p[1].Z) * 7))
	end
	-- ring catwalks between neighbouring pads (cross the lava channels)
	catwalk(model, "RingCatwalk", Vector3.new(40, 0, 32), Vector3.new(40, 0, -32))
	catwalk(model, "RingCatwalk", Vector3.new(-40, 0, 32), Vector3.new(-40, 0, -32))
	catwalk(model, "RingCatwalk", Vector3.new(32, 0, 40), Vector3.new(-32, 0, 40))

	silos(model)
	industry(model)
	refineryAndStacks(model)

	local spawns = {}
	for _, p in {
		Vector3.new(60, GROUND + 3, 85 - 10),
		Vector3.new(30, GROUND + 3, 60),
		Vector3.new(-60, GROUND + 3, 30),
		Vector3.new(-25, GROUND + 3, 30),
		Vector3.new(-70, GROUND + 3, -30),
		Vector3.new(-30, GROUND + 3, -70),
		Vector3.new(30, GROUND + 3, -30),
		Vector3.new(75, GROUND + 3, -75),
		Vector3.new(40, DECK + 3, 40),
		Vector3.new(-40, DECK + 3, -40),
		Vector3.new(0, DECK + 3, -12),
		Vector3.new(-40, DECK + 3, 40),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "MagmaCore",
		DisplayName = "Magma Core Station",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -4,
		FluidEndY = 14,
		FluidColor = LAVA,
		FluidMaterial = Enum.Material.CrackedLava,
		HazardFloorY = 2,
		FluidName = "LAVA",
		Lighting = "Volcanic",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 150,
	}
end

return MagmaCore
