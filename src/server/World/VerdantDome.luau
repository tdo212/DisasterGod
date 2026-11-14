--!strict
-- Arena 8: Verdant Bio-Dome. An overgrown solarpunk conservatory under a colossal ribbed
-- steel-and-glass dome. Sunbeams, waterfalls, lush greenery.
--   * Four ancient trees, each with white-steel research labs on stilts at different
--     heights (ladder shafts inside, glass walls), tied together by rope bridges you can
--     cut to strand the far side.
--   * A tiered greenhouse pavilion, hedges and reed beds around the lower pools.
--   * A rock cliff on the east wall with three waterfall cascades and climbable ledges.
--   * Set-piece: the dome. Every bay is glass panels hung from steel ribs. Panels crack
--     under impacts from above (the God aims straight through the glass); break a bay's
--     ribs and its whole sheet of glass comes down on whoever is underneath.
-- Sudden death: toxic spores rise from the lower pools as a dense green fog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local GRASS = Color3.fromRGB(118, 180, 58)
local MOSS = Color3.fromRGB(92, 150, 52)
local LEAF = Color3.fromRGB(82, 165, 58)
local LEAF_LIGHT = Color3.fromRGB(140, 205, 70)
local BARK = Color3.fromRGB(104, 72, 48)
local ROCK = Color3.fromRGB(122, 118, 110)
local WHITE = Color3.fromRGB(232, 238, 236)
local STEEL = Color3.fromRGB(176, 186, 190)
local GLASS = Color3.fromRGB(228, 242, 236)
local WATER = Color3.fromRGB(70, 170, 210)
local PLANK = Color3.fromRGB(176, 136, 90)
local ROPE = Color3.fromRGB(196, 170, 120)
local SOLAR = Color3.fromRGB(40, 70, 140)

local DOME_R = 158
local DOME_H = 106
local DOME_BAYS = 24
local DOME_RINGS = 6
local DOME_TOP = math.rad(80) -- the oculus at the crown stays open

local VerdantDome = {}

local function labStyle(openSide: string?, pillar: number?): Builder.HighriseStyle
	return {
		SlabColor = WHITE,
		SlabMaterial = Enum.Material.SmoothPlastic,
		ColumnColor = WHITE,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = GLASS,
		WallMaterial = Enum.Material.Glass,
		WallTransparency = 0.35,
		PillarHeight = pillar,
		OpenSide = openSide,
		Stairwell = true,
		Windows = true,
	}
end

local function water(parent: Instance, name: string, cframe: CFrame, size: Vector3): BasePart
	local w = Builder.part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	})
	w.CanQuery = false
	return w
end

local function mist(part: BasePart, rate: number)
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/smoke_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(2, 3)
	p.Rate = rate
	p.Speed = NumberRange.new(2, 4)
	p.SpreadAngle = Vector2.new(40, 40)
	p.Parent = part
end

local function ground(model: Model)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	Builder.block(g, "Soil", Vector3.new(0, -6.6, 0), Vector3.new(340, 12, 340), Color3.fromRGB(96, 74, 52), Enum.Material.Ground)
	Builder.block(g, "Lawn", Vector3.new(0, -0.5, 0), Vector3.new(330, 1, 330), GRASS, Enum.Material.Grass)
	-- gentle terraces and mossy mounds
	for _, t in {
		{ Vector3.new(-100, 0, -40), Vector3.new(40, 4, 50) },
		{ Vector3.new(-30, 0, 100), Vector3.new(50, 3, 30) },
		{ Vector3.new(30, 0, -110), Vector3.new(44, 5, 26) },
		{ Vector3.new(-80, 0, 100), Vector3.new(26, 7, 26) },
	} do
		Builder.block(g, "Terrace", t[1] + Vector3.new(0, t[2].Y / 2, 0), t[2], MOSS, Enum.Material.LeafyGrass)
	end
	-- lower conservatory pools (the spores rise from here)
	for _, p in { { Vector3.new(-40, 0, -20), Vector3.new(34, 0.3, 22) }, { Vector3.new(20, 0, 30), Vector3.new(26, 0.3, 30) }, { Vector3.new(90, 0, 0), Vector3.new(30, 0.3, 60) } } do
		Builder.block(g, "PoolRim", p[1] + Vector3.new(0, 0.3, 0), p[2] + Vector3.new(3, 0.3, 3), ROCK, Enum.Material.Slate).CanCollide = false
		water(g, "Pool", CFrame.new(p[1] + Vector3.new(0, 0.5, 0)), p[2])
	end
end

-- One dome bay: two ribs per bay edge (supports) and a column of glass panels.
local function domePoint(elev: number, lon: number): Vector3
	return Vector3.new(DOME_R * math.cos(elev) * math.cos(lon), DOME_H * math.sin(elev), DOME_R * math.cos(elev) * math.sin(lon))
end

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
			-- glass panel
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
				Transparency = 0.72,
				CastShadow = false,
			})
			Builder.structural(panel, 2, false, 45)
			Builder.canopy(panel)
			-- rib segment along this bay's west edge
			local a = domePoint(e0, lon0)
			local z = domePoint(e1, lon0)
			local rib = Builder.part(bay, {
				Name = "DomeRib",
				Size = Vector3.new(1.4, 1.4, (z - a).Magnitude + 0.6),
				CFrame = CFrame.lookAt((a + z) / 2, z),
				Color = STEEL,
				Material = Enum.Material.Metal,
			})
			Builder.structural(rib, 1, true, 110)
			Builder.canopy(rib)
			-- horizontal purlin under the panel's top edge
			if r < DOME_RINGS - 1 then
				local p0, p1 = domePoint(e1, lon0), domePoint(e1, lon1)
				local purlin = Builder.part(bay, {
					Name = "DomePurlin",
					Size = Vector3.new(0.8, 0.8, (p1 - p0).Magnitude),
					CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
					Color = STEEL,
					Material = Enum.Material.Metal,
					CastShadow = false,
				})
				Builder.structural(purlin, 2, false, 40)
				Builder.canopy(purlin)
			end
		end
	end
	-- crown ring around the open oculus
	for b = 0, DOME_BAYS - 1 do
		local p0 = domePoint(DOME_TOP, b * 2 * math.pi / DOME_BAYS)
		local p1 = domePoint(DOME_TOP, (b + 1) * 2 * math.pi / DOME_BAYS)
		local ring = Builder.part(folder, { Name = "Oculus", Size = Vector3.new(2, 2, (p1 - p0).Magnitude + 0.5), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = STEEL, Material = Enum.Material.Metal })
		Builder.canopy(ring)
	end
	-- foundation curb
	for b = 0, DOME_BAYS - 1 do
		local p0 = domePoint(0, b * 2 * math.pi / DOME_BAYS)
		local p1 = domePoint(0, (b + 1) * 2 * math.pi / DOME_BAYS)
		Builder.part(folder, { Name = "Curb", Size = Vector3.new(3, 2, (p1 - p0).Magnitude + 1), CFrame = CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 1, 0), p1 + Vector3.new(0, 1, 0)), Color = WHITE, Material = Enum.Material.Concrete })
	end
end

-- A giant tree: trunk, root flares and canopy clusters (the leaves can be blasted away).
local function tree(model: Model, base: Vector3, height: number, rng: Random)
	local t = Builder.building(model, "AncientTree")
	Builder.cylinder(t, "Trunk", base + Vector3.new(0, height / 2, 0), height, 14, BARK, Enum.Material.Wood)
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		Builder.part(t, {
			Name = "Root",
			Size = Vector3.new(4, 4, 14),
			CFrame = CFrame.new(base + Vector3.new(math.cos(a) * 8, 1.5, math.sin(a) * 8)) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = BARK,
			Material = Enum.Material.Wood,
		})
	end
	for i = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, 14)
		local size = Vector3.new(rng:NextInteger(12, 20), rng:NextInteger(6, 10), rng:NextInteger(12, 20))
		local leaf = Builder.block(t, "Canopy", base + Vector3.new(math.cos(a) * d, height - 4 + rng:NextNumber(0, 10), math.sin(a) * d), size, if i % 3 == 0 then LEAF_LIGHT else LEAF, Enum.Material.LeafyGrass)
		Builder.structural(leaf, 2, false, 50)
	end
	-- a few vines hanging from the canopy
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(14, 26)
		local vine = Builder.block(t, "Vine", base + Vector3.new(math.cos(a) * 12, height - 4 - len / 2, math.sin(a) * 12), Vector3.new(0.6, len, 0.6), MOSS, Enum.Material.LeafyGrass)
		vine.CanCollide = false
	end
end

-- A research lab on stilts beside a tree trunk; returns its roof Y and centre.
local function lab(model: Model, name: string, center: Vector3, w: number, d: number, pillar: number, floors: number, openSide: string): (Model, number)
	local house, roofY = Builder.highrise(model, name, center, w, d, floors, 10, labStyle(openSide, pillar))
	-- solar panels on the roof
	local roofLevel = floors + 3
	for i = -1, 1, 2 do
		local panel = Builder.part(house, {
			Name = "SolarPanel",
			Size = Vector3.new(w * 0.35, 0.3, d * 0.4),
			CFrame = CFrame.new(center.X + i * w * 0.22, roofY + 1.6, center.Z) * CFrame.Angles(math.rad(22), 0, 0),
			Color = SOLAR,
			Material = Enum.Material.Glass,
			Reflectance = 0.2,
		})
		Builder.structural(panel, roofLevel, false, 25)
		local leg = Builder.block(house, "SolarLeg", Vector3.new(center.X + i * w * 0.22, roofY + 0.7, center.Z), Vector3.new(0.4, 1.4, 0.4), STEEL, Enum.Material.Metal)
		Builder.structural(leg, roofLevel, false, 20)
	end
	-- lab clutter on the first floor (desks + screens) to hide behind
	local floorY = center.Y + pillar + 1.5
	for i = -1, 1, 2 do
		local desk = Builder.block(house, "LabDesk", Vector3.new(center.X + i * w * 0.25, floorY + 1.4, center.Z + d * 0.2), Vector3.new(6, 2.8, 2.6), WHITE, Enum.Material.SmoothPlastic)
		Builder.structural(desk, 3, false, 40)
		local screen = Builder.block(house, "Monitor", Vector3.new(center.X + i * w * 0.25, floorY + 3.6, center.Z + d * 0.2 + 0.8), Vector3.new(2.6, 1.6, 0.2), Color3.fromRGB(70, 140, 220), Enum.Material.Glass)
		Builder.structural(screen, 3, false, 10)
	end
	return house, roofY
end

local function cliff(model: Model)
	local c = Instance.new("Folder")
	c.Name = "WaterfallCliff"
	c.Parent = model
	-- three stepped rock tiers on the east wall, climbable by ledges on the south side
	local tiers = { { x = 118, w = 40, h = 12 }, { x = 128, w = 30, h = 24 }, { x = 136, w = 20, h = 36 } }
	for _, t in tiers do
		Builder.block(c, "CliffTier", Vector3.new(t.x, t.h / 2, 0), Vector3.new(t.w, t.h, 80), ROCK, Enum.Material.Slate)
		Builder.block(c, "CliffMoss", Vector3.new(t.x, t.h + 0.4, 0), Vector3.new(t.w, 0.8, 80), MOSS, Enum.Material.LeafyGrass)
	end
	for i = 1, 6 do
		Builder.block(c, "Ledge", Vector3.new(100 + i * 5, i * 6 - 2, -44), Vector3.new(6, 2, 8), ROCK, Enum.Material.Slate)
	end
	-- cascades: sheets of water down each tier face into the pool below
	for _, z in { -22, 6, 26 } do
		for i, t in tiers do
			local top = t.h
			local bottom = if i == 1 then 0.5 else tiers[i - 1].h
			local face = t.x - t.w / 2 - 0.4
			local sheet = water(c, "Waterfall", CFrame.new(face, (top + bottom) / 2, z), Vector3.new(0.6, top - bottom, 7))
			if i == 1 then
				mist(sheet, 4)
			end
			water(c, "Stream", CFrame.new((face + t.x + t.w / 2) / 2, top + 0.85, z), Vector3.new(t.w / 2, 0.3, 7))
		end
	end
end

function VerdantDome.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "VerdantDome"
	model.Parent = parent
	local rng = Random.new(23)

	ground(model)
	cliff(model)

	-- four ancient trees, each with labs at two heights
	local trees = {
		{ base = Vector3.new(-70, 0, -64), h = 66 },
		{ base = Vector3.new(52, 0, -78), h = 64 },
		{ base = Vector3.new(-66, 0, 62), h = 68 },
		{ base = Vector3.new(44, 0, 70), h = 72 },
	}
	local lowTops: { Vector3 } = {}
	for i, t in trees do
		tree(model, t.base, t.h, rng)
		local out = if i % 2 == 1 then 1 else -1
		local tx, tz = t.base.X, t.base.Z
		-- a low lab and a high lab on two sides of the trunk; the high lab's open face
		-- looks at the low lab's roof and a rope ramp joins them
		local lowCenter = t.base + Vector3.new(out * 20, 0, 0)
		local _, lowRoof = lab(model, "LowLab" .. i, lowCenter, 22, 20, 12, 2, if out > 0 then "East" else "West")
		local highCenter = t.base + Vector3.new(0, 0, -out * 19)
		lab(model, "HighLab" .. i, highCenter, 20, 18, 30, 2, if out > 0 then "East" else "West")
		table.insert(lowTops, Vector3.new(lowCenter.X, lowRoof, lowCenter.Z))
		Builder.bridge(model, "RopeRamp", Vector3.new(tx + out * 28, lowRoof + 0.5, tz - out * 9), Vector3.new(tx + out * 8, 32, tz - out * 26), 4, PLANK, Enum.Material.WoodPlanks, ROPE, BARK, 45)
		-- steel braces from the trunk to the high lab (decor)
		for _, s in { -1, 1 } do
			local a = t.base + Vector3.new(s * 4, 26, -out * 6)
			local b = highCenter + Vector3.new(s * 6, 30, out * 8)
			local brace = Builder.part(model, { Name = "Brace", Size = Vector3.new(0.8, 0.8, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = WHITE, Material = Enum.Material.Metal })
			brace.CanCollide = false
		end
	end
	-- rope bridges between the labs (cut a bridge to strand the far side)
	for _, link in { { 1, 2 }, { 3, 4 } } do
		local a, b = lowTops[link[1]], lowTops[link[2]]
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		Builder.bridge(model, "RopeBridge", a + dir * 9 + Vector3.new(0, 0.5, 0), b - dir * 9 + Vector3.new(0, 0.5, 0), 5, PLANK, Enum.Material.WoodPlanks, ROPE, BARK, 45)
	end

	-- tiered greenhouse pavilion in the middle
	Builder.highrise(model, "Greenhouse", Vector3.new(-6, 0, -6), 36, 30, 2, 11, {
		SlabColor = WHITE,
		SlabMaterial = Enum.Material.SmoothPlastic,
		ColumnColor = WHITE,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = GLASS,
		WallMaterial = Enum.Material.Glass,
		WallTransparency = 0.45,
		OpenSide = "East",
		Stairwell = true,
		Windows = true,
	})
	local cupola = Builder.highrise(model, "GreenhouseCupola", Vector3.new(-6, 22, -6), 20, 16, 1, 9, {
		SlabColor = WHITE,
		SlabMaterial = Enum.Material.SmoothPlastic,
		ColumnColor = WHITE,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = GLASS,
		WallMaterial = Enum.Material.Glass,
		WallTransparency = 0.45,
	})
	local planter = Builder.block(cupola, "Planter", Vector3.new(-6, 24.5, -6), Vector3.new(8, 2, 8), LEAF_LIGHT, Enum.Material.LeafyGrass)
	Builder.structural(planter, 2, false, 30)

	-- hedges, flower beds and reed clumps to duck behind
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(30, 135)
		local p = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if p.X > 95 and math.abs(p.Z) < 50 then
			continue -- keep the waterfall pool clear
		end
		local hedge = Builder.building(model, "Hedge")
		local size = Vector3.new(rng:NextInteger(6, 12), rng:NextInteger(4, 6), rng:NextInteger(3, 5))
		local h = Builder.part(hedge, { Name = "Hedge", Size = size, CFrame = CFrame.new(p + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, a, 0), Color = if rng:NextNumber() > 0.5 then LEAF else MOSS, Material = Enum.Material.LeafyGrass })
		Builder.structural(h, 1, true, 50)
		if rng:NextNumber() > 0.6 then
			local bloom = Builder.part(hedge, { Name = "Flowers", Size = Vector3.new(size.X * 0.8, 0.6, size.Z * 0.8), CFrame = h.CFrame * CFrame.new(0, size.Y / 2 + 0.3, 0), Color = Color3.fromRGB(255, rng:NextInteger(120, 220), rng:NextInteger(80, 200)), Material = Enum.Material.Fabric })
			bloom.CanCollide = false
			Builder.structural(bloom, 2, false, 10)
		end
	end
	-- palms and ferns around the pools
	for _, p in { Vector3.new(-62, 0, -20), Vector3.new(-18, 0, -34), Vector3.new(36, 0, 10), Vector3.new(5, 0, 50), Vector3.new(76, 0, -40), Vector3.new(76, 0, 40), Vector3.new(-120, 0, 10), Vector3.new(-110, 0, -90) } do
		Builder.palm(model, p, rng:NextNumber(14, 22))
	end
	-- sunbeams through the dome (decor shafts)
	for _ = 1, 7 do
		local p = Vector3.new(rng:NextNumber(-90, 90), 45, rng:NextNumber(-90, 90))
		local beam = Builder.part(model, { Name = "Sunbeam", Size = Vector3.new(10, 100, 10), CFrame = CFrame.new(p) * CFrame.Angles(math.rad(14), 0, math.rad(-18)), Color = Color3.fromRGB(255, 250, 210), Material = Enum.Material.Neon, Transparency = 0.96, CanCollide = false, CastShadow = false })
		beam.CanQuery = false
		beam.CanTouch = false
	end

	dome(model)

	-- distant hills outside the glass (decor)
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(230, 300)
		local h = rng:NextNumber(20, 60)
		local hill = Builder.block(model, "Hill", Vector3.new(math.cos(a) * d, h / 2 - 12, math.sin(a) * d), Vector3.new(rng:NextNumber(50, 90), h, rng:NextNumber(50, 90)), MOSS, Enum.Material.Grass)
		hill.CanCollide = false
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-30, 3, 30),
		Vector3.new(20, 3, -40),
		Vector3.new(-100, 6, -40),
		Vector3.new(60, 3, 0),
		Vector3.new(-20, 3, 120),
		Vector3.new(30, 7, -110),
		Vector3.new(-120, 3, 50),
		Vector3.new(100, 3, 80),
		Vector3.new(100, 3, -80),
		Vector3.new(0, 3, 90),
		Vector3.new(-50, 3, -120),
		Vector3.new(118, 15, 0),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "VerdantDome",
		DisplayName = "Verdant Bio-Dome",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 18,
		FluidColor = Color3.fromRGB(130, 210, 70),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "TOXIC SPORES",
		Lighting = "Conservatory",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 155,
	}
end

return VerdantDome
