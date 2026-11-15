--!strict
-- Arena 10: Abyssal Aqua-Dome. A research station on the sea floor under a ribbed glass
-- dome, deep-ocean night: indigo murk, cyan and aqua glow, coral and kelp.
--   * The Sub Pen: a two-storey steel hangar with control rooms, a stairwell ladder and an
--     outside stair to its catwalk roof, over a flooded moon-pool channel where a blocky
--     submarine is docked (its hull lists when the God holes it, then sinks).
--   * Two round research bio-domes: glass labs with neon-cyan floor rings, glass dome caps,
--     balconies and stairs, furnished with lab benches, computers and lockers.
--   * Steel catwalks and stairs tie the pen, the domes and two lattice towers together;
--     coral arches, kelp forests and pipe runs make hiding spots on the sea floor.
--   * Set-piece: the dome. Glass panels on steel ribs; the God aims straight through, and
--     breaking a bay's ribs drops its glass.
-- Sudden death: the station floods from the moon pool. Get up on the catwalks and domes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local SAND = Color3.fromRGB(46, 66, 84)
local ROCK = Color3.fromRGB(38, 48, 66)
local DECK = Color3.fromRGB(70, 80, 92)
local STEEL = Color3.fromRGB(96, 108, 120)
local DARK = Color3.fromRGB(40, 46, 56)
local WALL = Color3.fromRGB(150, 160, 168)
local CYAN = Color3.fromRGB(60, 235, 255)
local AQUA = Color3.fromRGB(40, 200, 190)
local GLASS = Color3.fromRGB(110, 200, 230)
local WATER = Color3.fromRGB(20, 90, 130)
local SUB = Color3.fromRGB(58, 66, 80)
local CORAL = { Color3.fromRGB(255, 120, 80), Color3.fromRGB(255, 80, 150), Color3.fromRGB(180, 90, 255), Color3.fromRGB(255, 190, 70) }
local KELP = Color3.fromRGB(40, 130, 90)

local DOME_R = 150
local DOME_H = 96
local DOME_BAYS = 20
local DOME_RINGS = 5
local DOME_TOP = math.rad(80)

local AbyssalAquaDome = {}

local function deco(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function seaFloor(model: Model)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	Builder.block(g, "Bedrock", Vector3.new(0, -14, 0), Vector3.new(330, 12, 330), ROCK, Enum.Material.Slate)
	-- the floor around the moon-pool channel (x -80..80 along z = 0, 24 wide)
	Builder.block(g, "SeaFloorNorth", Vector3.new(0, -4, 92), Vector3.new(320, 8, 160), SAND, Enum.Material.Sand)
	Builder.block(g, "SeaFloorSouth", Vector3.new(0, -4, -92), Vector3.new(320, 8, 160), SAND, Enum.Material.Sand)
	Builder.block(g, "SeaFloorEast", Vector3.new(120, -4, 0), Vector3.new(80, 8, 24), SAND, Enum.Material.Sand)
	Builder.block(g, "SeaFloorWest", Vector3.new(-120, -4, 0), Vector3.new(80, 8, 24), SAND, Enum.Material.Sand)
	-- the channel: a shallow moon pool (2 studs of water over a solid bed) with dock edges
	Builder.block(g, "ChannelBed", Vector3.new(0, -4, 0), Vector3.new(160, 4, 24), Color3.fromRGB(24, 36, 48), Enum.Material.Slate)
	local water = Builder.part(g, { Name = "MoonPool", Size = Vector3.new(160, 1.8, 24), CFrame = CFrame.new(0, -1.1, 0), Color = WATER, Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false, CastShadow = false })
	water.CanQuery = false
	for _, z in { -12.5, 12.5 } do
		Builder.block(g, "DockEdge", Vector3.new(0, 0.2, z), Vector3.new(160, 0.6, 1), Color3.fromRGB(230, 190, 40), Enum.Material.Metal)
	end
	-- glowing floor strips leading between the buildings
	for _, s in { { Vector3.new(-50, 0.05, -40), Vector3.new(1, 0.1, 40) }, { Vector3.new(50, 0.05, 40), Vector3.new(1, 0.1, 40) }, { Vector3.new(0, 0.05, -60), Vector3.new(60, 0.1, 1) } } do
		deco(Builder.neon(g, s[1], s[2], AQUA))
	end
end

local function domePoint(elev: number, lon: number): Vector3
	return Vector3.new(DOME_R * math.cos(elev) * math.cos(lon), DOME_H * math.sin(elev), DOME_R * math.cos(elev) * math.sin(lon))
end

-- the station dome: glass bays on steel ribs (the God aims through the glass)
local function dome(model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Dome"
	folder.Parent = model
	for b = 0, DOME_BAYS - 1 do
		local bay = Builder.building(folder, "DomeBay")
		local lon0 = b * 2 * math.pi / DOME_BAYS
		local lon1 = (b + 1) * 2 * math.pi / DOME_BAYS
		local lonM = (lon0 + lon1) / 2
		for r = 0, DOME_RINGS - 1 do
			local e0 = r * DOME_TOP / DOME_RINGS
			local e1 = (r + 1) * DOME_TOP / DOME_RINGS
			local eM = (e0 + e1) / 2
			local c = (domePoint(e0, lon0) + domePoint(e0, lon1) + domePoint(e1, lon0) + domePoint(e1, lon1)) / 4
			local up = (domePoint(e1, lonM) - domePoint(e0, lonM)).Unit
			local normal = Vector3.new(c.X / (DOME_R * DOME_R), c.Y / (DOME_H * DOME_H), c.Z / (DOME_R * DOME_R)).Unit
			local width = (domePoint(eM, lon1) - domePoint(eM, lon0)).Magnitude
			local height = (domePoint(e1, lonM) - domePoint(e0, lonM)).Magnitude
			local panel = Builder.part(bay, {
				Name = "DomePanel",
				Size = Vector3.new(width - 0.4, height - 0.4, 0.5),
				CFrame = CFrame.lookAt(c, c + normal, up),
				Color = GLASS,
				Material = Enum.Material.Glass,
				Transparency = 0.8,
				CastShadow = false,
			})
			Builder.structural(panel, 2, false, 45)
			Builder.canopy(panel)
			local a = domePoint(e0, lon0)
			local z = domePoint(e1, lon0)
			-- slim, light and half see-through: the God looks down through the dome
			local rib = Builder.part(bay, {
				Name = "DomeRib",
				Size = Vector3.new(1.1, 1.1, (z - a).Magnitude + 0.6),
				CFrame = CFrame.lookAt((a + z) / 2, z),
				Color = STEEL,
				Material = Enum.Material.Metal,
				Transparency = 0.45,
				CastShadow = false,
			})
			Builder.structural(rib, 1, true, 110)
			Builder.canopy(rib)
			if r == 1 or r == 3 then
				local p0, p1 = domePoint(e1, lon0), domePoint(e1, lon1)
				local purlin = Builder.part(bay, {
					Name = "DomePurlin",
					Size = Vector3.new(0.7, 0.7, (p1 - p0).Magnitude),
					CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
					Color = STEEL,
					Material = Enum.Material.Metal,
					Transparency = 0.45,
					CastShadow = false,
				})
				Builder.structural(purlin, 2, false, 40)
				Builder.canopy(purlin)
			end
		end
	end
	for b = 0, DOME_BAYS - 1 do
		local p0 = domePoint(0, b * 2 * math.pi / DOME_BAYS)
		local p1 = domePoint(0, (b + 1) * 2 * math.pi / DOME_BAYS)
		Builder.part(folder, { Name = "Curb", Size = Vector3.new(3, 3, (p1 - p0).Magnitude + 1), CFrame = CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 1.5, 0), p1 + Vector3.new(0, 1.5, 0)), Color = DARK, Material = Enum.Material.Metal })
		local glow = Builder.part(folder, { Name = "CurbGlow", Size = Vector3.new(0.4, 0.4, (p1 - p0).Magnitude), CFrame = CFrame.lookAt((p0 + p1) / 2 * 0.985 + Vector3.new(0, 3.1, 0), p1 * 0.985 + Vector3.new(0, 3.1, 0)), Color = CYAN, Material = Enum.Material.Neon })
		deco(glow)
	end
end

-- the two-storey submarine pen over the channel's west end
local function subPen(model: Model): Model
	local base = Vector3.new(-58, 0, -30)
	local pen, roofY = Builder.highrise(model, "SubPen", base, 44, 28, 2, 12, {
		SlabColor = DECK,
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = STEEL,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = WALL,
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		Windows = true,
		Stairwell = true,
		Health = 220,
	})
	-- lit control-room window strip and hazard stripes along the floors
	for _, f in { 1, 2 } do
		local y = base.Y + (f - 1) * 12 + 7
		local strip = Builder.neon(pen, Vector3.new(base.X, y, base.Z - 14.2), Vector3.new(36, 0.5, 0.3), if f == 1 then AQUA else CYAN)
		Builder.structural(strip, f, false, 20)
	end
	-- outside stair to the roof catwalk (east face)
	Builder.stairs(model, Vector3.new(base.X + 22 + 26, 0, base.Z + 6), Vector3.new(base.X + 23, roofY, base.Z + 6), 6, DECK, Enum.Material.DiamondPlate)
	-- a gantry crane over the channel from the pen roof
	local crane = Builder.building(model, "PenGantry")
	Builder.restsOn(crane, pen)
	for _, x in { base.X - 16, base.X + 16 } do
		local leg = Builder.block(crane, "GantryLeg", Vector3.new(x, roofY + 6, base.Z + 13), Vector3.new(1.6, 12, 1.6), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
		Builder.structural(leg, 1, true, 90)
	end
	local beam = Builder.block(crane, "GantryBeam", Vector3.new(base.X, roofY + 12.5, base.Z + 13), Vector3.new(34, 1.6, 1.6), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
	Builder.structural(beam, 2, false, 90)
	local hook = Builder.block(crane, "Hook", Vector3.new(base.X + 4, roofY + 6, base.Z + 13), Vector3.new(1, 10, 1), DARK, Enum.Material.Metal)
	Builder.structural(hook, 2, false, 30)
	return pen
end

-- a blocky submarine docked in the moon pool: walk its deck, hide behind the sail. When
-- the God holes it, it lists into the water; a second blow sinks it.
local function submarine(model: Model)
	local sub = Builder.building(model, "Submarine")
	local y = -1.2
	for i, x in { -18, -6, 6, 18 } do
		local seg = Builder.part(sub, {
			Name = "Hull",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12.2, 10, 10),
			CFrame = CFrame.new(x - 8, y, 0),
			Color = SUB,
			Material = Enum.Material.Metal,
		})
		Builder.structural(seg, 1, i == 2 or i == 3, 220)
	end
	local nose = Builder.part(sub, { Name = "Bow", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), CFrame = CFrame.new(18, y, 0), Color = SUB, Material = Enum.Material.Metal })
	Builder.structural(nose, 1, false, 160)
	local tail = Builder.part(sub, { Name = "Stern", Class = "WedgePart", Size = Vector3.new(8, 6, 10), CFrame = CFrame.new(-35, y, 0) * CFrame.Angles(0, math.rad(90), 0), Color = SUB, Material = Enum.Material.Metal })
	Builder.structural(tail, 1, false, 120)
	local deck = Builder.block(sub, "Deck", Vector3.new(-8, y + 5.2, 0), Vector3.new(40, 0.6, 4), DECK, Enum.Material.DiamondPlate)
	Builder.structural(deck, 2, false, 90)
	local sail = Builder.block(sub, "Sail", Vector3.new(-2, y + 9, 0), Vector3.new(9, 7, 3.6), SUB, Enum.Material.Metal)
	Builder.structural(sail, 2, false, 140)
	for _, side in { -1, 1 } do
		local fin = Builder.block(sub, "SailFin", Vector3.new(-2, y + 10, side * 3.4), Vector3.new(4, 0.5, 3.4), SUB, Enum.Material.Metal)
		Builder.structural(fin, 2, false, 40)
	end
	local scope = Builder.block(sub, "Periscope", Vector3.new(-1, y + 14, 0), Vector3.new(0.6, 3, 0.6), DARK, Enum.Material.Metal)
	Builder.structural(scope, 2, false, 20)
	local lamp = Builder.neon(sub, Vector3.new(-2, y + 12.6, 0), Vector3.new(1, 0.4, 1), CYAN)
	Builder.structural(lamp, 2, false, 10)
	for _, x in { -30, 0, 14 } do
		local port = Builder.neon(sub, Vector3.new(x, y + 1, -5.05), Vector3.new(1.4, 1.4, 0.2), Color3.fromRGB(255, 220, 140))
		Builder.structural(port, 1, false, 10)
	end
	Builder.tilt(sub, Vector3.new(-8, -6, 4), Vector3.new(1, 0, 0), 14)
	-- gangway from the dock to its deck
	Builder.bridge(model, "Gangway", Vector3.new(-10, 0.4, -13), Vector3.new(-10, y + 5.4, -2.5), 4, DECK, Enum.Material.DiamondPlate, Color3.fromRGB(230, 190, 40), STEEL, 60)
end

type Dome = { Center: Vector3, Diameter: number }
local DOMES: { Dome } = {
	{ Center = Vector3.new(52, 0, 46), Diameter = 36 },
	{ Center = Vector3.new(86, 0, -42), Diameter = 30 },
}

-- a round glass research lab, two floors, a glass dome cap and a balcony with stairs
local function bioDome(model: Model, d: Dome, index: number): (Model, number)
	local lab, roofY = Builder.roundHall(model, "BioDome" .. index, d.Center, d.Diameter, 2, 12, {
		WallColor = GLASS,
		WallMaterial = Enum.Material.Glass,
		WallTransparency = 0.45,
		SlabColor = Color3.fromRGB(200, 214, 222),
		SlabMaterial = Enum.Material.SmoothPlastic,
		ColumnColor = STEEL,
		Trim = CYAN,
		Health = 160,
		Segments = 14,
	})
	-- the cap leaves a ring walkway on the roof for the catwalks to land on
	Builder.domeCap(lab, d.Center + Vector3.new(0, roofY, 0), d.Diameter / 2 - 5, d.Diameter * 0.3, GLASS, Enum.Material.Glass, 0.55, 4, 10, 2)
	-- a glowing core column in the middle of the cap
	local core = Builder.neon(lab, d.Center + Vector3.new(0, roofY + 4, 0), Vector3.new(1.4, 8, 1.4), AQUA)
	Builder.structural(core, 4, false, 20)
	local light = Instance.new("PointLight")
	light.Color = CYAN
	light.Range = 30
	light.Brightness = 1.4
	light.Parent = core
	-- balcony off the upper floor (south) with a stair down to the sea floor
	local r = d.Diameter / 2
	local balconyY = d.Center.Y + 12
	local balcony = Builder.building(model, "Balcony")
	Builder.restsOn(balcony, lab)
	local floor = Builder.block(balcony, "Deck", Vector3.new(d.Center.X, balconyY - 0.75, d.Center.Z - r - 4), Vector3.new(14, 1.5, 8), DECK, Enum.Material.DiamondPlate)
	Builder.structural(floor, 1, false, 90)
	for _, x in { -6.5, 6.5 } do
		local post = Builder.block(balcony, "Strut", Vector3.new(d.Center.X + x, balconyY / 2, d.Center.Z - r - 7.4), Vector3.new(1, balconyY, 1), STEEL, Enum.Material.Metal)
		Builder.structural(post, 1, true, 80)
	end
	local rail = Builder.neon(balcony, Vector3.new(d.Center.X, balconyY + 3.4, d.Center.Z - r - 8), Vector3.new(14, 0.3, 0.3), CYAN)
	Builder.structural(rail, 1, false, 10)
	Builder.stairs(model, Vector3.new(d.Center.X + 7 + 22, 0, d.Center.Z - r - 4), Vector3.new(d.Center.X + 7, balconyY, d.Center.Z - r - 4), 5, DECK, Enum.Material.DiamondPlate)
	return lab, roofY
end

-- lattice watch towers that anchor the catwalks
local function tower(model: Model, base: Vector3, height: number): (Model, number)
	local t = Builder.building(model, "CatwalkTower")
	local top = Builder.latticeTower(model, t, base, height, 8, STEEL)
	local deck = Builder.block(t, "Platform", base + Vector3.new(0, height + 0.5, 0), Vector3.new(10, 1, 10), DECK, Enum.Material.DiamondPlate)
	Builder.structural(deck, 2, false, 90)
	local beacon = Builder.neon(t, base + Vector3.new(0, height + 1.4, 0), Vector3.new(1.2, 0.8, 1.2), CYAN)
	Builder.structural(beacon, 2, false, 10)
	return t, top + 1
end

-- coral: a walk-through arch of branching blocks with glowing tips (cover, and it breaks)
local function coralArch(model: Model, at: Vector3, yaw: number, rng: Random)
	local c = Builder.building(model, "CoralArch")
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local color = CORAL[rng:NextInteger(1, #CORAL)]
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			local p = cf * CFrame.new(side * (5 - k * 0.8), 2 + k * 3.6, 0)
			local lump = Builder.part(c, { Name = "Coral", Size = Vector3.new(3.2 - k * 0.5, 4, 3.2 - k * 0.5), CFrame = p * CFrame.Angles(0, 0, math.rad(side * -12 * k)), Color = color, Material = Enum.Material.Rock })
			Builder.structural(lump, 1 + (if k > 0 then 1 else 0), k == 0, 70)
		end
	end
	local top = Builder.part(c, { Name = "Coral", Size = Vector3.new(8, 2.4, 3), CFrame = cf * CFrame.new(0, 11.6, 0), Color = color, Material = Enum.Material.Rock })
	Builder.structural(top, 2, false, 60)
	for i = 1, 4 do
		local tip = Builder.part(c, { Name = "CoralTip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = cf * CFrame.new(rng:NextNumber(-4, 4), 12.8 + rng:NextNumber(0, 1), rng:NextNumber(-1, 1)), Color = CORAL[(i % #CORAL) + 1], Material = Enum.Material.Neon })
		deco(tip)
		Builder.structural(tip, 2, false, 5)
	end
end

local function kelp(model: Model, at: Vector3, rng: Random)
	local k = Builder.building(model, "Kelp")
	for i = 1, 3 do
		local h = rng:NextNumber(10, 22)
		local off = Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		local stalk = Builder.part(k, { Name = "Kelp", Size = Vector3.new(0.8, h, 2.2), CFrame = CFrame.new(at + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-8, 8))), Color = KELP:Lerp(Color3.fromRGB(90, 200, 120), i / 4), Material = Enum.Material.LeafyGrass })
		stalk.CanCollide = false
		Builder.structural(stalk, 1, i == 1, 25)
	end
end

function AbyssalAquaDome.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "AbyssalAquaDome"
	model.Parent = parent
	local rng = Random.new(10)

	seaFloor(model)
	local pen = subPen(model)
	submarine(model)
	local labs: { Model } = {}
	local labRoofs: { number } = {}
	for i, d in DOMES do
		labs[i], labRoofs[i] = bioDome(model, d, i)
	end

	-- a storage block and a pump house (more interiors on the south and north floors)
	Builder.highrise(model, "StorageBay", Vector3.new(-96, 0, 44), 26, 20, 2, 10, {
		SlabColor = DECK,
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = STEEL,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(120, 132, 140),
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		Windows = true,
		Stairwell = true,
		OpenSide = "East",
	})
	Builder.highrise(model, "PumpHouse", Vector3.new(4, 0, -78), 22, 16, 1, 11, {
		SlabColor = DECK,
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = STEEL,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(90, 120, 130),
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		OpenSide = "West",
	})

	-- catwalk network: pen roof -> tower -> dome 1 roof -> tower -> dome 2 roof
	local penRoof = (pen:GetAttribute("RoofY") :: number?) or 26
	local t1, t1Top = tower(model, Vector3.new(4, 0, 30), 22)
	local t2, t2Top = tower(model, Vector3.new(60, 0, -4), 26)
	Builder.restsOn(Builder.bridge(model, "Catwalk", Vector3.new(-36, penRoof + 0.3, -22), Vector3.new(0, t1Top - 0.2, 26), 5, DECK, Enum.Material.DiamondPlate, CYAN, STEEL, 70), t1)
	Builder.restsOn(Builder.bridge(model, "Catwalk", Vector3.new(8, t1Top - 0.2, 32), Vector3.new(DOMES[1].Center.X - 17, labRoofs[1] + 0.3, DOMES[1].Center.Z - 4), 5, DECK, Enum.Material.DiamondPlate, CYAN, STEEL, 70), labs[1])
	Builder.restsOn(Builder.bridge(model, "Catwalk", Vector3.new(DOMES[1].Center.X + 6, labRoofs[1] + 0.3, DOMES[1].Center.Z - 17), Vector3.new(60, t2Top - 0.2, 0), 5, DECK, Enum.Material.DiamondPlate, CYAN, STEEL, 70), t2)
	Builder.restsOn(Builder.bridge(model, "Catwalk", Vector3.new(62, t2Top - 0.2, -8), Vector3.new(DOMES[2].Center.X - 10, labRoofs[2] + 0.3, DOMES[2].Center.Z + 10), 5, DECK, Enum.Material.DiamondPlate, CYAN, STEEL, 70), labs[2])
	-- a stair up each tower
	Builder.stairs(model, Vector3.new(4, 0, 30 + 5 + t1Top * 1.3), Vector3.new(4, t1Top, 35), 4, DECK, Enum.Material.DiamondPlate)
	Builder.stairs(model, Vector3.new(60, 0, -9 - t2Top * 1.3), Vector3.new(60, t2Top, -9), 4, DECK, Enum.Material.DiamondPlate)

	-- pipe runs along the floor and up the pen wall (cover you can crouch behind)
	local pipes = Builder.building(model, "PipeRun")
	Builder.pipe(pipes, Vector3.new(-100, 1.4, -24), Vector3.new(-82, 1.4, -24), 2.2, Color3.fromRGB(180, 110, 60))
	Builder.pipe(pipes, Vector3.new(-30, 1.4, -60), Vector3.new(40, 1.4, -60), 2.2, Color3.fromRGB(170, 175, 185))
	Builder.pipe(pipes, Vector3.new(40, 1.4, -60), Vector3.new(70, 1.4, -42), 2.2, Color3.fromRGB(170, 175, 185))
	Builder.pipe(pipes, Vector3.new(-30, 1.4, 70), Vector3.new(30, 1.4, 90), 2.6, Color3.fromRGB(180, 110, 60))
	Builder.pipe(pipes, Vector3.new(30, 1.4, 90), Vector3.new(30, 18, 90), 2.6, Color3.fromRGB(180, 110, 60))

	-- coral arches and kelp forests on the sea floor
	for _, spec in {
		{ Vector3.new(-30, 0, 46), 0.3 },
		{ Vector3.new(20, 0, 100), 1.2 },
		{ Vector3.new(-80, 0, -84), 2 },
		{ Vector3.new(110, 0, 30), 0.8 },
		{ Vector3.new(-120, 0, 10), 1.6 },
		{ Vector3.new(40, 0, -110), 0.2 },
	} do
		coralArch(model, spec[1] :: Vector3, spec[2] :: number, rng)
	end
	for _, p in {
		Vector3.new(-40, 0, 90), Vector3.new(-60, 0, 100), Vector3.new(80, 0, 80), Vector3.new(100, 0, -80),
		Vector3.new(-110, 0, -50), Vector3.new(-20, 0, -110), Vector3.new(120, 0, -10), Vector3.new(-128, 0, 60),
	} do
		kelp(model, p, rng)
	end

	dome(model)

	-- rock spires and a dark trench outside the glass (decor)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(200, 280)
		local h = rng:NextNumber(30, 90)
		deco(Builder.block(model, "OceanRock", Vector3.new(math.cos(a) * dist, h / 2 - 10, math.sin(a) * dist), Vector3.new(rng:NextNumber(30, 60), h, rng:NextNumber(30, 60)), Color3.fromRGB(20, 30, 48), Enum.Material.Slate))
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-58, 3, -30), Vector3.new(-40, 3, 20), Vector3.new(0, 3, 50), Vector3.new(52, 3, 46),
		Vector3.new(86, 3, -42), Vector3.new(20, 3, -40), Vector3.new(-96, 3, 44), Vector3.new(4, 3, -78),
		Vector3.new(-90, 3, -70), Vector3.new(100, 3, 70), Vector3.new(-10, 9, 0), Vector3.new(30, 3, 110),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "AbyssalAquaDome",
		DisplayName = "Abyssal Aqua-Dome",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 15,
		FluidColor = Color3.fromRGB(30, 120, 160),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "FLOODWATER",
		Lighting = "Abyss",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 140,
	}
end

return AbyssalAquaDome
