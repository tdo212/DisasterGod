--!strict
-- Arena 13: Clockwork Spire. A jagged, overgrown sky island floating above a sea of cloud
-- under a starry nebula night; golden gaslight, copper and amber.
--   * The Cog Tower in the middle: three stacked clockwork tiers on brass columns, giant
--     gears turning on every tier, a great clock face on top, stairs winding up between
--     the tiers and machinery to hide in under the first one.
--   * The Grand Observatory (east): two storeys under twin copper domes, with a massive
--     telescope spire and a ladder spiralling up the outside.
--   * The Grand Library (west): two storeys, a labyrinth of bookshelves on the ground
--     floor, reading balconies above; catwalks from the Cog Tower reach both roofs.
--   * A hollow fallen gear makes a crawlspace; stone archways choked with vines and
--     gas lamps line the cobbled paths.
-- Sudden death: the cloud tide rises over the island. Climb the tower.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local ROCK = Color3.fromRGB(82, 78, 92)
local ROCK_DARK = Color3.fromRGB(56, 52, 66)
local MOSS = Color3.fromRGB(70, 120, 70)
local COBBLE = Color3.fromRGB(120, 112, 118)
local BRASS = Color3.fromRGB(196, 150, 70)
local COPPER = Color3.fromRGB(184, 108, 60)
local STONE = Color3.fromRGB(196, 186, 170)
local WOOD = Color3.fromRGB(110, 70, 44)
local AMBER = Color3.fromRGB(255, 180, 80)
local VINE = Color3.fromRGB(60, 130, 60)

local TIERS = {
	{ Radius = 25, Top = 12 },
	{ Radius = 18, Top = 24 },
	{ Radius = 11, Top = 36 },
}

local ClockworkSpire = {}

local function deco(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function polar(r: number, a: number, y: number): Vector3
	return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

local function island(model: Model, rng: Random)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	Builder.block(g, "IslandTop", Vector3.new(0, -4, 0), Vector3.new(250, 8, 220), ROCK, Enum.Material.Slate)
	Builder.block(g, "Grass", Vector3.new(0, 0.1, 0), Vector3.new(240, 0.2, 210), MOSS, Enum.Material.Grass)
	-- cobbled paths: a cross through the middle and a ring around the tower
	Builder.block(g, "Path", Vector3.new(0, 0.25, 0), Vector3.new(220, 0.3, 10), COBBLE, Enum.Material.Cobblestone)
	Builder.block(g, "Path", Vector3.new(0, 0.25, 0), Vector3.new(10, 0.3, 190), COBBLE, Enum.Material.Cobblestone)
	for i = 0, 11 do
		local a0, a1 = i * math.pi / 6, (i + 1) * math.pi / 6
		local p0, p1 = polar(34, a0, 0.26), polar(34, a1, 0.26)
		Builder.part(g, { Name = "PathRing", Size = Vector3.new(8, 0.3, (p1 - p0).Magnitude + 1), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = COBBLE, Material = Enum.Material.Cobblestone })
	end
	-- jagged, mossy crags around the rim (solid ground, climbable)
	for i = 0, 27 do
		local a = i * math.pi * 2 / 28 + rng:NextNumber(-0.05, 0.05)
		local rx, rz = 118 + rng:NextNumber(-6, 4), 102 + rng:NextNumber(-6, 4)
		local h = rng:NextNumber(4, 22)
		local w = rng:NextNumber(10, 18)
		local p = Vector3.new(math.cos(a) * rx, h / 2, math.sin(a) * rz)
		Builder.part(g, { Name = "Crag", Size = Vector3.new(w, h, w * 0.8), CFrame = CFrame.new(p) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-8, 8))), Color = ROCK_DARK, Material = Enum.Material.Slate })
		Builder.part(g, { Name = "CragMoss", Size = Vector3.new(w * 0.9, 1, w * 0.7), CFrame = CFrame.new(p + Vector3.new(0, h / 2 + 0.4, 0)) * CFrame.Angles(0, -a, 0), Color = MOSS, Material = Enum.Material.LeafyGrass })
	end
	-- the island's underside hanging into the clouds, and the cloud sea (decor)
	for i = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, 70)
		local h = rng:NextNumber(30, 70)
		deco(Builder.part(model, { Name = "Underside", Size = Vector3.new(rng:NextNumber(50, 90), h, rng:NextNumber(50, 90)), CFrame = CFrame.new(math.cos(a) * d, -8 - h / 2, math.sin(a) * d) * CFrame.Angles(0, a, 0), Color = ROCK_DARK, Material = Enum.Material.Slate }))
		local _ = i
	end
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(150, 300)
		local cloud = Builder.part(model, { Name = "Cloud", Size = Vector3.new(rng:NextNumber(80, 160), rng:NextNumber(8, 16), rng:NextNumber(60, 120)), CFrame = CFrame.new(math.cos(a) * d, rng:NextNumber(-60, -30), math.sin(a) * d), Color = Color3.fromRGB(200, 196, 230), Material = Enum.Material.SmoothPlastic, Transparency = 0.35 })
		deco(cloud)
	end
end

-- a gear disc with teeth (decor: it turns)
local function gear(parent: Instance, cf: CFrame, diameter: number, rate: number, color: Color3)
	local disc = Builder.part(parent, { Name = "Gear", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, diameter, diameter), CFrame = cf, Color = color, Material = Enum.Material.Metal })
	Builder.spin(disc, Vector3.new(rate, 0, 0))
	deco(disc)
	local hub = Builder.part(parent, { Name = "GearHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, diameter * 0.3, diameter * 0.3), CFrame = cf, Color = ROCK_DARK, Material = Enum.Material.Metal })
	deco(hub)
end

-- the three-tier Cog Tower with a clock on top
local function cogTower(model: Model): Model
	local t = Builder.building(model, "CogTower")
	local prevTop = 0
	for k, tier in TIERS do
		local h = tier.Top - prevTop - 1.5
		-- brass columns under the tier
		local n = if k == 1 then 10 else 8
		for i = 0, n - 1 do
			local a = i * math.pi * 2 / n
			local col = Builder.block(t, "BrassColumn", polar(tier.Radius - 2, a, prevTop + h / 2), Vector3.new(2.2, h, 2.2), BRASS, Enum.Material.Metal)
			Builder.structural(col, k, true, 240)
		end
		-- the tier's floor disc and a copper rim
		local slab = Builder.part(t, { Name = "Slab", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, tier.Radius * 2, tier.Radius * 2), CFrame = CFrame.new(0, tier.Top - 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = STONE, Material = Enum.Material.Cobblestone })
		Builder.structural(slab, k + 1, false, 260)
		local rim = Builder.part(t, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, tier.Radius * 2 + 1.2, tier.Radius * 2 + 1.2), CFrame = CFrame.new(0, tier.Top - 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = COPPER, Material = Enum.Material.Metal })
		Builder.structural(rim, k + 1, false, 60)
		-- giant gears turning on the tier's flanks (decor)
		for i = 0, 3 do
			local a = i * math.pi / 2 + k * 0.4
			local p = polar(tier.Radius + 0.8, a, prevTop + h * 0.55)
			gear(t, CFrame.lookAt(p, Vector3.new(0, p.Y, 0)) * CFrame.Angles(0, math.rad(90), 0), math.min(h * 0.9, 12), if i % 2 == 0 then 0.5 else -0.7, if i % 2 == 0 then BRASS else COPPER)
		end
		prevTop = tier.Top
	end
	-- machinery under the first tier: a turning flywheel and crates to hide among
	local fly = Builder.part(t, { Name = "Flywheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 18, 18), CFrame = CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = BRASS, Material = Enum.Material.Metal })
	Builder.spin(fly, Vector3.new(0.6, 0, 0))
	deco(fly)
	local shaft = Builder.block(t, "Driveshaft", Vector3.new(0, 18, 0), Vector3.new(3, 36, 3), ROCK_DARK, Enum.Material.Metal)
	Builder.structural(shaft, 1, true, 400)
	-- the clock: a spire on the top tier with a great face and turning hands
	local top = TIERS[3].Top
	local spire = Builder.block(t, "ClockSpire", Vector3.new(0, top + 8, 0), Vector3.new(7, 16, 7), STONE, Enum.Material.Cobblestone)
	Builder.structural(spire, 4, false, 220)
	local roof = Builder.part(t, { Name = "SpireRoof", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(0, top + 16.5, 0), Color = COPPER, Material = Enum.Material.Metal })
	Builder.structural(roof, 4, false, 60)
	for _, face in { Vector3.new(0, 0, -1), Vector3.new(0, 0, 1) } do
		local c = Vector3.new(0, top + 11, 0) + face * 3.7
		local dial = Builder.part(t, { Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6.4, 6.4), CFrame = CFrame.lookAt(c, c + face) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(250, 236, 200), Material = Enum.Material.Neon })
		Builder.structural(dial, 4, false, 30)
		local hand = Builder.part(t, { Name = "ClockHand", Size = Vector3.new(0.3, 2.8, 0.3), CFrame = CFrame.lookAt(c + face * 0.3, c + face * 2), Color = ROCK_DARK, Material = Enum.Material.Metal })
		Builder.spin(hand, Vector3.new(0, 0, 0.4))
		deco(hand)
	end
	local glow = t:FindFirstChild("ClockFace") :: BasePart?
	if glow then
		local light = Instance.new("PointLight")
		light.Color = AMBER
		light.Range = 40
		light.Brightness = 1.4
		light.Parent = glow
	end
	-- stairs winding up: ground -> tier 1 -> tier 2 -> tier 3 (each a chord across the ring)
	local legs = {
		{ R0 = 40, Y0 = 0, R1 = TIERS[1].Radius - 1, Y1 = TIERS[1].Top, A = 0.3 },
		{ R0 = TIERS[1].Radius - 2, Y0 = TIERS[1].Top, R1 = TIERS[2].Radius - 1, Y1 = TIERS[2].Top, A = 2.4 },
		{ R0 = TIERS[2].Radius - 2, Y0 = TIERS[2].Top, R1 = TIERS[3].Radius - 1, Y1 = TIERS[3].Top, A = 4.4 },
	}
	for i, leg in legs do
		local chord = (leg.Y1 - leg.Y0) * 1.35
		local cosPhi = math.clamp((leg.R0 * leg.R0 + leg.R1 * leg.R1 - chord * chord) / (2 * leg.R0 * leg.R1), -1, 1)
		local phi = math.acos(cosPhi)
		local stair = Builder.stairs(t, polar(leg.R0, leg.A, leg.Y0), polar(leg.R1, leg.A + phi, leg.Y1), 5, WOOD, Enum.Material.WoodPlanks, i)
		stair.Name = "TowerStair"
	end
	return t
end

-- twin domes, a telescope spire and an outside spiral ladder
local function observatory(model: Model): (Model, number)
	local base = Vector3.new(74, 0, -6)
	local obs, roofY = Builder.highrise(model, "Observatory", base, 34, 26, 2, 11, {
		SlabColor = STONE,
		SlabMaterial = Enum.Material.Cobblestone,
		ColumnColor = BRASS,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = STONE,
		WallMaterial = Enum.Material.Limestone,
		WallTransparency = 0,
		Windows = true,
		Stairwell = true,
	})
	local domes = Builder.building(model, "ObservatoryDomes")
	Builder.restsOn(domes, obs)
	for _, dx in { -8, 8 } do
		local c = Vector3.new(base.X + dx, roofY, base.Z + 4)
		local drum = Builder.cylinder(domes, "DomeDrum", c + Vector3.new(0, 1.5, 0), 3, 13, STONE, Enum.Material.Limestone)
		Builder.structural(drum, 1, true, 160)
		Builder.domeCap(domes, c + Vector3.new(0, 3, 0), 6.4, 5.5, COPPER, Enum.Material.Metal, 0, 2, 8, 2)
	end
	-- the telescope spire: a huge brass tube angled at the nebula
	local scope = Builder.building(model, "TelescopeSpire")
	Builder.restsOn(scope, obs)
	local foot = Vector3.new(base.X + 8, roofY + 6, base.Z + 4)
	local tip = foot + Vector3.new(10, 26, -6)
	local tube = Builder.part(scope, { Name = "Tube", Shape = Enum.PartType.Cylinder, Size = Vector3.new((tip - foot).Magnitude, 4, 4), CFrame = CFrame.lookAt((foot + tip) / 2, tip) * CFrame.Angles(0, math.rad(90), 0), Color = BRASS, Material = Enum.Material.Metal })
	Builder.structural(tube, 2, false, 120)
	local lens = Builder.part(scope, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.6, 4.6), CFrame = CFrame.lookAt(tip, tip + (tip - foot)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(160, 220, 255), Material = Enum.Material.Neon })
	Builder.structural(lens, 2, false, 20)
	local mount = Builder.block(scope, "Mount", foot - Vector3.new(0, 3, 0), Vector3.new(4, 6, 4), COPPER, Enum.Material.Metal)
	Builder.structural(mount, 1, true, 140)
	-- a ladder up the outside (the "spiral" is a ladder per face, offset)
	local ladder = Builder.part(model, { Name = "SpiralLadder", Class = "TrussPart", Size = Vector3.new(2, roofY, 2), CFrame = CFrame.new(base.X + 18, roofY / 2, base.Z - 8), Color = BRASS, Material = Enum.Material.Metal })
	Builder.structural(ladder, 1, false, 60)
	return obs, roofY
end

-- the library: bookshelf labyrinth on the ground floor, balcony on the north side
local function library(model: Model): (Model, number)
	local base = Vector3.new(-74, 0, 8)
	local lib, roofY = Builder.highrise(model, "GrandLibrary", base, 46, 32, 2, 12, {
		SlabColor = WOOD,
		SlabMaterial = Enum.Material.WoodPlanks,
		ColumnColor = STONE,
		ColumnMaterial = Enum.Material.Limestone,
		WallColor = Color3.fromRGB(140, 70, 60),
		WallMaterial = Enum.Material.Brick,
		WallTransparency = 0,
		Windows = true,
		Stairwell = true,
		OpenSide = "East",
	})
	local bookColors = { Color3.fromRGB(150, 40, 40), Color3.fromRGB(40, 80, 140), Color3.fromRGB(50, 110, 60), Color3.fromRGB(180, 140, 60), Color3.fromRGB(90, 50, 110) }
	-- the labyrinth: rows of tall shelves with gaps that don't line up
	local rows = { { Z = -6, Gaps = { -12, 8 } }, { Z = 0, Gaps = { -2, 14 } }, { Z = 6, Gaps = { -16, 4 } } }
	for r, row in ipairs(rows) do
		for x = -18, 18, 6 do
			local gap = false
			for _, gx in row.Gaps do
				if math.abs(x - gx) < 3.5 then
					gap = true
				end
			end
			if not gap then
				local shelf = Builder.block(lib, "Bookshelf", Vector3.new(base.X + x, 4.5, base.Z + row.Z), Vector3.new(5.6, 9, 1.6), WOOD, Enum.Material.Wood)
				Builder.structural(shelf, 1, false, 70)
				local books = Builder.block(lib, "Books", Vector3.new(base.X + x, 4.5, base.Z + row.Z), Vector3.new(5.2, 7.4, 1.8), bookColors[(x // 6 + r) % #bookColors + 1], Enum.Material.Fabric)
				Builder.structural(books, 1, false, 20)
			end
		end
	end
	-- reading balcony on the north side of the upper floor
	local balcony = Builder.building(model, "ReadingBalcony")
	Builder.restsOn(balcony, lib)
	local deckY = base.Y + 12
	local deck = Builder.block(balcony, "Deck", Vector3.new(base.X, deckY - 0.75, base.Z + 16 + 3), Vector3.new(26, 1.5, 6), WOOD, Enum.Material.WoodPlanks)
	Builder.structural(deck, 1, false, 80)
	for _, x in { -12, 0, 12 } do
		local strut = Builder.block(balcony, "Corbel", Vector3.new(base.X + x, deckY - 1.5, base.Z + 17), Vector3.new(1.2, 3, 2.4), STONE, Enum.Material.Limestone)
		Builder.structural(strut, 1, true, 100)
	end
	local rail = Builder.block(balcony, "Rail", Vector3.new(base.X, deckY + 2.6, base.Z + 21.6), Vector3.new(26, 0.4, 0.4), BRASS, Enum.Material.Metal)
	Builder.structural(rail, 1, false, 15)
	Builder.stairs(model, Vector3.new(base.X + 13 + 18, 0, base.Z + 19), Vector3.new(base.X + 13, deckY, base.Z + 19), 5, STONE, Enum.Material.Cobblestone)
	return lib, roofY
end

-- a fallen giant gear lying flat: a ring of teeth with a low hub roof (crawl inside)
local function hollowGear(model: Model, at: Vector3)
	local g = Builder.building(model, "HollowGear")
	for i = 0, 13 do
		if i % 5 == 0 then
			continue -- gaps to crawl in through
		end
		local a = i * math.pi * 2 / 14
		local tooth = Builder.part(g, { Name = "Tooth", Size = Vector3.new(3, 4.4, 4.4), CFrame = CFrame.lookAt(at + polar(11, a, 2.2), at + Vector3.new(0, 2.2, 0)), Color = COPPER, Material = Enum.Material.Metal })
		Builder.structural(tooth, 1, true, 90)
	end
	local roof = Builder.part(g, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 24, 24), CFrame = CFrame.new(at + Vector3.new(0, 4.9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = BRASS, Material = Enum.Material.Metal })
	Builder.structural(roof, 2, false, 120)
	local axle = Builder.cylinder(g, "Axle", at + Vector3.new(0, 2.2, 0), 4.4, 3, ROCK_DARK, Enum.Material.Metal)
	Builder.structural(axle, 1, true, 120)
end

-- a stone archway choked with hanging vines
local function archway(model: Model, at: Vector3, yaw: number, rng: Random)
	local a = Builder.building(model, "VineArch")
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		local pillar = Builder.part(a, { Name = "Pillar", Size = Vector3.new(2.4, 12, 2.4), CFrame = cf * CFrame.new(side * 6, 6, 0), Color = STONE, Material = Enum.Material.Cobblestone })
		Builder.structural(pillar, 1, true, 150)
	end
	local lintel = Builder.part(a, { Name = "Lintel", Size = Vector3.new(15, 2.4, 2.8), CFrame = cf * CFrame.new(0, 13.2, 0), Color = STONE, Material = Enum.Material.Cobblestone })
	Builder.structural(lintel, 2, false, 120)
	for i = 1, 5 do
		local len = rng:NextNumber(3, 8)
		local vine = Builder.part(a, { Name = "Vine", Size = Vector3.new(0.6, len, 0.6), CFrame = cf * CFrame.new(rng:NextNumber(-6.5, 6.5), 12 - len / 2, rng:NextNumber(-1.2, 1.2)), Color = VINE:Lerp(Color3.fromRGB(110, 170, 80), rng:NextNumber()), Material = Enum.Material.LeafyGrass })
		deco(vine)
		Builder.structural(vine, 2, false, 5)
		local _ = i
	end
	local moss = Builder.part(a, { Name = "Moss", Size = Vector3.new(15.4, 0.8, 3.2), CFrame = cf * CFrame.new(0, 14.7, 0), Color = MOSS, Material = Enum.Material.LeafyGrass })
	Builder.structural(moss, 2, false, 10)
end

function ClockworkSpire.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "ClockworkSpire"
	model.Parent = parent
	local rng = Random.new(13)

	island(model, rng)
	local tower = cogTower(model)
	local obs, obsRoof = observatory(model)
	local lib, libRoof = library(model)

	-- catwalks from the second tier out to both roofs
	local t2 = TIERS[2]
	Builder.restsOn(Builder.bridge(model, "Catwalk", Vector3.new(t2.Radius - 1, t2.Top + 0.3, -4), Vector3.new(57.5, obsRoof + 0.3, -4), 5, WOOD, Enum.Material.WoodPlanks, BRASS, COPPER, 60), obs)
	Builder.restsOn(Builder.bridge(model, "Catwalk", Vector3.new(-t2.Radius + 1, t2.Top + 0.3, 6), Vector3.new(-50.5, libRoof + 0.3, 6), 5, WOOD, Enum.Material.WoodPlanks, BRASS, COPPER, 60), lib)
	local _ = tower

	-- a clockmaker's workshop and a gatehouse (more interiors)
	Builder.highrise(model, "Workshop", Vector3.new(10, 0, 70), 24, 18, 2, 10, {
		SlabColor = WOOD,
		SlabMaterial = Enum.Material.WoodPlanks,
		ColumnColor = COPPER,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(120, 90, 70),
		WallMaterial = Enum.Material.Brick,
		WallTransparency = 0,
		Windows = true,
		Stairwell = true,
	})
	Builder.highrise(model, "Gatehouse", Vector3.new(-14, 0, -74), 20, 14, 2, 10, {
		SlabColor = STONE,
		SlabMaterial = Enum.Material.Cobblestone,
		ColumnColor = STONE,
		ColumnMaterial = Enum.Material.Limestone,
		WallColor = STONE,
		WallMaterial = Enum.Material.Cobblestone,
		WallTransparency = 0,
		Windows = true,
		OpenSide = "West",
	})

	hollowGear(model, Vector3.new(50, 0, 56))
	for _, spec in { { Vector3.new(0, 0, -44), 0 }, { Vector3.new(0, 0, 46), 0 }, { Vector3.new(-40, 0, 0), math.pi / 2 }, { Vector3.new(-30, 0, -60), 0.6 }, { Vector3.new(60, 0, -60), -0.5 } } do
		archway(model, spec[1] :: Vector3, spec[2] :: number, rng)
	end

	local spawns = {}
	for _, p in {
		Vector3.new(0, 3, -30), Vector3.new(30, 3, 30), Vector3.new(-30, 3, 30), Vector3.new(74, 3, -6),
		Vector3.new(-74, 3, 8), Vector3.new(10, 3, 70), Vector3.new(-14, 3, -74), Vector3.new(50, 3, 56),
		Vector3.new(0, TIERS[1].Top + 3, 18), Vector3.new(-90, 3, -50), Vector3.new(90, 3, 50), Vector3.new(40, 3, -40),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "ClockworkSpire",
		DisplayName = "Clockwork Spire",
		Model = model,
		SpawnPoints = spawns,
		-- the cloud sea far below the island rises to swallow it
		FluidStartY = -40,
		FluidEndY = 14,
		FluidColor = Color3.fromRGB(205, 198, 240),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "CLOUD TIDE",
		Lighting = "Nebula",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 125,
	}
end

return ClockworkSpire
