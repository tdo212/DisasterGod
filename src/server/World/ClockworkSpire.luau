--!strict
-- Arena 13: Clockwork Spire. An open-sky steampunk foundry yard at golden hour, walled in
-- by massive brick-and-iron blast walls.
--   * A walled arena: brick walls with iron pilasters, brass pipe runs, glowing furnace
--     arches and giant brass gears turning on every wall (impassable, with an invisible cap).
--   * Two brick-and-brass clocktowers (4 and 5 storeys) with lit clock faces, an open belfry
--     on the roof under a pointed spire; stairwell ladders reach every floor and the roof.
--   * Three multi-floor brick factories and a small foundry, all with window holes and
--     stairwells; iron skybridges link the clocktower roofs to the factories.
--   * Four free-standing smokestacks that topple when their base is blasted, steam-vent
--     launch pads that fling survivors onto the roofs, glowing furnace pans, brass rail
--     tracks and minecarts across the cobbled yard.
-- Sudden death: molten brass floods the yard. Get up the towers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local BRICK = Color3.fromRGB(150, 72, 50)
local BRICK_DARK = Color3.fromRGB(110, 52, 40)
local IRON = Color3.fromRGB(52, 50, 54)
local BRASS = Color3.fromRGB(200, 150, 60)
local BRASS_DARK = Color3.fromRGB(160, 110, 45)
local YARD = Color3.fromRGB(88, 80, 76)
local GLOW = Color3.fromRGB(255, 140, 40)
local CLOCK = Color3.fromRGB(255, 236, 180)
local ROOF = Color3.fromRGB(90, 60, 50)

local HALF = 115 -- interior half-size
local WALL_T = 14
local WALL_H = 52
local FLOOR_H = 12

local ClockworkSpire = {}

local function deco(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local BRICK_STYLE: Builder.HighriseStyle = {
	SlabColor = IRON,
	SlabMaterial = Enum.Material.DiamondPlate,
	ColumnColor = IRON,
	ColumnMaterial = Enum.Material.Metal,
	WallColor = BRICK,
	WallMaterial = Enum.Material.Brick,
	WallTransparency = 0,
	Stairwell = true,
	Windows = true,
}

local function grounds(model: Model)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	Builder.block(g, "Yard", Vector3.new(0, -3, 0), Vector3.new(500, 6, 500), YARD, Enum.Material.Cobblestone)
	-- brass rail tracks: a loop round the yard and a cross line
	local function rail(a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		for _, off in { -1.6, 1.6 } do
			local side = CFrame.lookAt(mid, b) * CFrame.new(off, 0, 0)
			deco(Builder.part(g, { Name = "Rail", Size = Vector3.new(0.5, 0.3, len), CFrame = side + Vector3.new(0, 0.15, 0), Color = BRASS, Material = Enum.Material.Metal }))
		end
	end
	local r = 102
	rail(Vector3.new(-r, 0, -r), Vector3.new(r, 0, -r))
	rail(Vector3.new(r, 0, -r), Vector3.new(r, 0, r))
	rail(Vector3.new(r, 0, r), Vector3.new(-r, 0, r))
	rail(Vector3.new(-r, 0, r), Vector3.new(-r, 0, -r))
	rail(Vector3.new(-r, 0, 0), Vector3.new(r, 0, 0))
end

-- A giant brass gear that turns on a wall (purely visual: every piece spins about the same
-- axis through the hub, so the teeth turn with the rim).
local function wallGear(parent: Instance, center: Vector3, normal: Vector3, diameter: number, rate: number)
	local axis = CFrame.lookAt(center, center + normal) * CFrame.Angles(0, math.rad(90), 0) -- local X along the normal
	local rim = Builder.part(parent, { Name = "GearRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, diameter, diameter), CFrame = axis, Color = BRASS, Material = Enum.Material.Metal })
	Builder.spin(rim, Vector3.new(rate, 0, 0))
	for i = 0, 3 do
		local bar = Builder.part(parent, { Name = "GearTeeth", Size = Vector3.new(1.4, diameter + 3, 2), CFrame = axis * CFrame.Angles(i * math.pi / 4, 0, 0), Color = BRASS_DARK, Material = Enum.Material.Metal })
		Builder.spin(bar, Vector3.new(rate, 0, 0))
		bar.CastShadow = false
	end
	local hub = Builder.part(parent, { Name = "GearHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, diameter * 0.25, diameter * 0.25), CFrame = axis, Color = IRON, Material = Enum.Material.Metal })
	Builder.spin(hub, Vector3.new(rate, 0, 0))
end

-- The blast walls: brick, iron pilasters and cap, brass pipes, furnace arches and gears.
local function perimeter(model: Model)
	local w = Instance.new("Folder")
	w.Name = "Perimeter"
	w.Parent = model
	local o = HALF + WALL_T / 2
	local sides = {
		{ Vector3.new(0, 0, o), true, Vector3.new(0, 0, -1) },
		{ Vector3.new(0, 0, -o), true, Vector3.new(0, 0, 1) },
		{ Vector3.new(o, 0, 0), false, Vector3.new(-1, 0, 0) },
		{ Vector3.new(-o, 0, 0), false, Vector3.new(1, 0, 0) },
	}
	for i, side in sides do
		local c, alongX, inward = side[1] :: Vector3, side[2] :: boolean, side[3] :: Vector3
		local len = HALF * 2 + WALL_T * 2
		local size = if alongX then Vector3.new(len, WALL_H, WALL_T) else Vector3.new(WALL_T, WALL_H, len)
		Builder.block(w, "BlastWall", c + Vector3.new(0, WALL_H / 2, 0), size, BRICK, Enum.Material.Brick)
		Builder.block(w, "WallCap", c + Vector3.new(0, WALL_H + 1, 0), size + Vector3.new(if alongX then 0 else 3, 2 - WALL_H, if alongX then 3 else 0), IRON, Enum.Material.Metal)
		local face = c + inward * (WALL_T / 2 + 0.6)
		local along = if alongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		-- iron pilasters every 38 studs
		for k = -3, 3 do
			Builder.block(w, "Pilaster", face + along * (k * 38) + Vector3.new(0, WALL_H / 2, 0), Vector3.new(4, WALL_H, 4), IRON, Enum.Material.Metal)
		end
		-- a brass steam main along the wall, with a drop pipe at each end
		local pipeY = 14
		Builder.part(w, { Name = "SteamMain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(len - 40, 3, 3), CFrame = CFrame.lookAt(face + inward * 2 + Vector3.new(0, pipeY, 0), face + inward * 2 + Vector3.new(0, pipeY, 0) + along) * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = Enum.Material.Metal, CastShadow = false })
		-- a glowing furnace arch in the middle of the wall
		Builder.block(w, "FurnaceArch", face + Vector3.new(0, 9, 0), if alongX then Vector3.new(20, 18, 2) else Vector3.new(2, 18, 20), IRON, Enum.Material.Metal)
		deco(Builder.block(w, "FurnaceGlow", face + inward * 1.1 + Vector3.new(0, 7, 0), if alongX then Vector3.new(14, 12, 0.4) else Vector3.new(0.4, 12, 14), GLOW, Enum.Material.Neon))
		-- two giant turning gears
		for _, k in { -1, 1 } do
			wallGear(w, face + inward * 1.2 + along * (k * 60) + Vector3.new(0, 30, 0), inward, 24, (if (i + k) % 2 == 0 then 0.35 else -0.35))
		end
		Builder.boundary(w, c + Vector3.new(0, WALL_H + 80, 0), size + Vector3.new(0, 160 - WALL_H, 0))
	end
	-- corner turrets
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local c = Vector3.new(sx * (HALF + 4), 0, sz * (HALF + 4))
			Builder.cylinder(w, "Turret", c + Vector3.new(0, 30, 0), 60, 26, BRICK_DARK, Enum.Material.Brick)
			Builder.cylinder(w, "TurretCap", c + Vector3.new(0, 61, 0), 2, 28, IRON, Enum.Material.Metal)
		end
	end
end

-- A clocktower: a brick highrise with clock faces on its top storey and an open belfry with
-- a pointed spire on the roof.
local function clocktower(model: Model, at: Vector3, floors: number): (Model, number)
	local tower, roofY = Builder.highrise(model, "Clocktower", at, 20, 20, floors, FLOOR_H, BRICK_STYLE)
	Builder.facadeTrim(tower, BRASS, Enum.Material.Metal, IRON, Enum.Material.Metal)
	local faceY = roofY - FLOOR_H / 2
	for _, n in { Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		local p = at + n * 10.8 + Vector3.new(0, faceY - at.Y, 0)
		local face = Builder.part(tower, { Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9), CFrame = CFrame.lookAt(p, p + n) * CFrame.Angles(0, math.rad(90), 0), Color = CLOCK, Material = Enum.Material.Neon })
		Builder.structural(face, floors, false, 30)
		local hand = Builder.part(tower, { Name = "ClockHand", Size = Vector3.new(0.5, 3.6, 0.3), CFrame = CFrame.lookAt(p + n * 0.5, p + n) * CFrame.new(0, 1.6, 0), Color = IRON, Material = Enum.Material.Metal, CastShadow = false })
		hand.CanCollide = false
		Builder.structural(hand, floors, false, 10)
	end
	-- a brick belfry in the middle of the roof (a walkway rings it), then a stepped spire
	local lvl = floors + 2
	local belfry = Builder.block(tower, "Belfry", Vector3.new(at.X, roofY + 4, at.Z), Vector3.new(9, 8, 9), BRICK_DARK, Enum.Material.Brick)
	Builder.structural(belfry, lvl, true, 160)
	local bell = Builder.block(tower, "BellGlow", Vector3.new(at.X, roofY + 5, at.Z), Vector3.new(9.4, 3, 9.4), CLOCK, Enum.Material.Neon)
	bell.CanCollide = false
	Builder.structural(bell, lvl, false, 10)
	local tiers = { { 11, 1.5 }, { 8, 4 }, { 5, 4 }, { 2.5, 4 } }
	local y = roofY + 8
	for _, t in tiers do
		local roof = Builder.block(tower, "SpireRoof", Vector3.new(at.X, y + t[2] / 2, at.Z), Vector3.new(t[1], t[2], t[1]), ROOF, Enum.Material.Slate)
		Builder.structural(roof, lvl + 1, false, 60)
		y += t[2]
	end
	local tip = Builder.cylinder(tower, "Spire", Vector3.new(at.X, y + 5, at.Z), 10, 1, BRASS, Enum.Material.Metal)
	Builder.structural(tip, lvl + 1, false, 20)
	return tower, roofY
end

-- A brick factory with a sawtooth roof light (on the east half, clear of the stairwell in
-- the north-west corner and of the skybridge landings) and a brass sign.
local function factory(model: Model, at: Vector3, w: number, d: number, floors: number, title: string): (Model, number)
	local m, roofY = Builder.highrise(model, "Factory", at, w, d, floors, FLOOR_H + 2, BRICK_STYLE)
	Builder.facadeTrim(m, IRON, Enum.Material.Metal)
	local light = Builder.part(m, { Name = "Rooflight", Class = "WedgePart", Size = Vector3.new(w * 0.3, 4, d * 0.5), CFrame = CFrame.new(at.X + w * 0.22, roofY + 2, at.Z), Color = ROOF, Material = Enum.Material.Slate })
	Builder.structural(light, floors + 2, false, 40)
	local sign = Builder.block(m, "FactorySign", Vector3.new(at.X, roofY - 3, at.Z - d / 2 - 0.8), Vector3.new(w * 0.6, 3.2, 0.5), IRON, Enum.Material.Metal)
	Builder.structural(sign, floors, false, 20)
	Builder.sign(sign, Enum.NormalId.Front, title, BRASS, Color3.new(0, 0, 0))
	return m, roofY
end

-- A free-standing brick smokestack: three stacked drums (each a support for the ones above)
-- with an iron collar and steam; it topples toward `fall` when its base goes.
local function smokestack(model: Model, at: Vector3, height: number, fall: Vector3)
	local m = Builder.building(model, "Smokestack")
	local seg = height / 3
	for i = 1, 3 do
		local drum = Builder.cylinder(m, "Stack", at + Vector3.new(0, (i - 0.5) * seg, 0), seg, 7 - i * 0.6, if i % 2 == 0 then BRICK_DARK else BRICK, Enum.Material.Brick)
		Builder.structural(drum, i, true, 160)
	end
	local collar = Builder.cylinder(m, "Collar", at + Vector3.new(0, height + 0.6, 0), 1.2, 6.6, IRON, Enum.Material.Metal)
	Builder.structural(collar, 3, false, 40)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(235, 230, 225)
	smoke.Opacity = 0.18
	smoke.RiseVelocity = 6
	smoke.Size = 6
	smoke.Parent = collar
	Builder.fallDirection(m, fall)
end

-- A steam vent: an iron grate that launches survivors (Builder.launchPad) with a hiss of steam.
local function vent(model: Model, at: Vector3)
	local f = Instance.new("Folder")
	f.Name = "SteamVent"
	f.Parent = model
	local rim = Builder.block(f, "VentRim", at + Vector3.new(0, 0.3, 0), Vector3.new(10, 0.6, 10), IRON, Enum.Material.Metal)
	rim.CanTouch = false
	local grate = Builder.block(f, "SteamVent", at + Vector3.new(0, 0.7, 0), Vector3.new(7, 0.2, 7), BRASS_DARK, Enum.Material.DiamondPlate)
	Builder.launchPad(grate, 88)
	deco(Builder.block(f, "VentGlow", at + Vector3.new(0, 0.62, 0), Vector3.new(8, 0.1, 8), GLOW, Enum.Material.Neon))
	local steam = Instance.new("Smoke")
	steam.Color = Color3.fromRGB(250, 250, 250)
	steam.Opacity = 0.12
	steam.RiseVelocity = 14
	steam.Size = 3
	steam.Parent = grate
end

-- A glowing furnace pan of molten brass behind a low iron kerb (solid; just looks hot).
local function furnacePan(model: Model, at: Vector3)
	local m = Builder.building(model, "FurnacePan")
	local kerb = Builder.block(m, "Kerb", at + Vector3.new(0, 1, 0), Vector3.new(16, 2, 12), IRON, Enum.Material.Metal)
	Builder.structural(kerb, 1, true, 200)
	local melt = Builder.block(m, "Melt", at + Vector3.new(0, 2.05, 0), Vector3.new(13, 0.1, 9), GLOW, Enum.Material.Neon)
	melt.CanCollide = false
	Builder.structural(melt, 1, false, 10)
end

local function minecart(model: Model, at: Vector3, yaw: number)
	local m = Builder.building(model, "Minecart")
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local body = Builder.part(m, { Name = "Cart", Size = Vector3.new(5, 3, 7), CFrame = cf * CFrame.new(0, 2, 0), Color = IRON, Material = Enum.Material.Metal })
	Builder.structural(body, 1, true, 80)
	local ore = Builder.part(m, { Name = "Ore", Size = Vector3.new(4.2, 0.8, 6), CFrame = cf * CFrame.new(0, 3.6, 0), Color = BRASS, Material = Enum.Material.Pebble })
	Builder.structural(ore, 1, false, 20)
end

function ClockworkSpire.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "ClockworkSpire"
	model.Parent = parent

	grounds(model)
	perimeter(model)

	-- two clocktowers and four factories; every skybridge runs straight from one roof edge
	-- to the next (the clocktower belfries sit in the middle of their roofs)
	local westClock, westRoof = clocktower(model, Vector3.new(-24, 0, 30), 5)
	local eastClock, eastRoof = clocktower(model, Vector3.new(34, 0, -22), 4)
	local nw, nwRoof = factory(model, Vector3.new(-24, 0, 82), 32, 24, 4, "FOUNDRY No.1")
	local ne, neRoof = factory(model, Vector3.new(40, 0, 30), 30, 28, 4, "GEARWORKS")
	local se, seRoof = factory(model, Vector3.new(34, 0, -76), 26, 22, 3, "SMELTERY")
	local sw, swRoof = factory(model, Vector3.new(-72, 0, -24), 32, 28, 3, "BOILER HOUSE")

	local function skybridge(name: string, a: Vector3, b: Vector3, base: Model)
		local bridge = Builder.bridge(model, name, a, b, 12, IRON, Enum.Material.DiamondPlate, BRASS, IRON, 90)
		Builder.restsOn(bridge, base)
	end
	skybridge("Skybridge", Vector3.new(-24, westRoof + 0.5, 39), Vector3.new(-24, nwRoof + 0.5, 71), nw)
	skybridge("Skybridge", Vector3.new(-15, westRoof + 0.5, 27), Vector3.new(26, neRoof + 0.5, 27), westClock)
	skybridge("Skybridge", Vector3.new(34, eastRoof + 0.5, -13), Vector3.new(34, neRoof + 0.5, 17), eastClock)
	skybridge("Skybridge", Vector3.new(34, eastRoof + 0.5, -31), Vector3.new(34, seRoof + 0.5, -66), se)
	skybridge("Skybridge", Vector3.new(25, eastRoof + 0.5, -27), Vector3.new(-57, swRoof + 0.5, -27), sw)

	-- smokestacks, steam vents, furnace pans and minecarts across the yard
	smokestack(model, Vector3.new(-96, 0, 44), 46, Vector3.new(1, 0, 0))
	smokestack(model, Vector3.new(96, 0, -10), 42, Vector3.new(-1, 0, 0.3))
	smokestack(model, Vector3.new(-20, 0, -86), 40, Vector3.new(0.4, 0, 1))
	smokestack(model, Vector3.new(16, 0, 92), 44, Vector3.new(0, 0, -1))
	for _, p in { Vector3.new(0, 0, 0), Vector3.new(-50, 0, 10), Vector3.new(80, 0, 0), Vector3.new(10, 0, -60) } do
		vent(model, p)
	end
	furnacePan(model, Vector3.new(-6, 0, 58))
	furnacePan(model, Vector3.new(75, 0, -45))
	minecart(model, Vector3.new(0, 0, -102), math.rad(90))
	minecart(model, Vector3.new(-102, 0, -70), 0)

	local spawns = {}
	for _, p in {
		Vector3.new(-30, 3, -10), Vector3.new(20, 3, 20), Vector3.new(-90, 3, 0), Vector3.new(90, 3, -30),
		Vector3.new(0, 3, 96), Vector3.new(0, 3, -96), Vector3.new(-96, 3, -96), Vector3.new(96, 3, 96),
		Vector3.new(-60, 3, 100), Vector3.new(60, 3, -100),
		Vector3.new(-24, 3.5, 26), Vector3.new(44, 3.5, 26), -- inside the west clocktower and the gearworks
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "ClockworkSpire",
		DisplayName = "Clockwork Spire",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -6,
		FluidEndY = 14,
		FluidColor = Color3.fromRGB(255, 150, 40),
		FluidMaterial = Enum.Material.CrackedLava,
		HazardFloorY = nil,
		FluidName = "MOLTEN BRASS",
		Lighting = "Foundry",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 125,
		Walled = true,
	}
end

return ClockworkSpire
