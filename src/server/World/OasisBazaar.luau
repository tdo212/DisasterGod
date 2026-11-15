--!strict
-- Arena 12: Oasis Bazaar. A sandstone gorge at golden-orange dusk, cut by a blue river
-- lined with palms, with a dusty wind blowing through.
--   * Two cliff plateaus face each other across the gorge. Rope-and-plank bridges link
--     the tops; wooden scaffolding towers in the gorge carry a lower walkway across the
--     river, with ladders up the cliff faces and carved ramps from the gorge floor.
--   * Three two-storey adobe-and-timber market halls (one in the gorge, one on each
--     plateau) with open windows, shop stalls inside and flat roofs to climb.
--   * Carved caves in both cliff walls: a treasure room and a tomb, with pillars, gold,
--     chests and stacks of crates to hide behind.
--   * Market tents, fruit stands, barrels and parked cars on the plateaus (Details pass).
-- Sudden death: a flash flood fills the gorge. Get up the cliffs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local SAND = Color3.fromRGB(222, 182, 128)
local SANDSTONE = Color3.fromRGB(205, 140, 90)
local SANDSTONE_DARK = Color3.fromRGB(170, 105, 70)
local ADOBE = Color3.fromRGB(214, 168, 118)
local TIMBER = Color3.fromRGB(120, 78, 46)
local PLANK = Color3.fromRGB(160, 116, 70)
local ROPE = Color3.fromRGB(200, 170, 120)
local GOLD = Color3.fromRGB(255, 200, 70)
local BUSH = Color3.fromRGB(90, 140, 60)

local TOP = 26 -- cliff plateau height
local GORGE = 32 -- the gorge runs along x between z = -32 and z = 32
local RIVER = 8 -- river channel half-width

local OasisBazaar = {}

local function deco(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

type Cave = { X: number, Width: number, Depth: number, Height: number }
-- caves cut into each cliff face at gorge level (north cliff: z > 0, south: z < 0)
local NORTH_CAVES: { Cave } = { { X = -64, Width = 24, Depth = 30, Height = 14 } }
local SOUTH_CAVES: { Cave } = { { X = 20, Width = 22, Depth = 26, Height = 13 } }

-- one cliff (side = 1 north, -1 south): solid sandstone with caves carved out, ledges on
-- its face and a sandy plateau on top
local function cliff(g: Folder, side: number, caves: { Cave })
	local z0 = side * GORGE -- the face
	local depth = 110
	local zc = side * (GORGE + depth / 2)
	-- split the cliff along x around each cave: full blocks between, roof + back over caves
	local spans: { { number } } = {}
	local x = -160
	table.sort(caves, function(a, b)
		return a.X < b.X
	end)
	for _, c in caves do
		table.insert(spans, { x, c.X - c.Width / 2 })
		x = c.X + c.Width / 2
	end
	table.insert(spans, { x, 160 })
	for _, s in spans do
		local w = s[2] - s[1]
		if w > 0.5 then
			Builder.block(g, "Cliff", Vector3.new((s[1] + s[2]) / 2, TOP / 2, zc), Vector3.new(w, TOP, depth), SANDSTONE, Enum.Material.Sandstone)
		end
	end
	for _, c in caves do
		Builder.block(g, "CaveRoof", Vector3.new(c.X, (c.Height + TOP) / 2, zc), Vector3.new(c.Width, TOP - c.Height, depth), SANDSTONE, Enum.Material.Sandstone)
		local backDepth = depth - c.Depth
		Builder.block(g, "CaveBack", Vector3.new(c.X, c.Height / 2, side * (GORGE + c.Depth + backDepth / 2)), Vector3.new(c.Width, c.Height, backDepth), SANDSTONE_DARK, Enum.Material.Sandstone)
		Builder.block(g, "CaveFloor", Vector3.new(c.X, 0.1, side * (GORGE + c.Depth / 2)), Vector3.new(c.Width, 0.2, c.Depth), SANDSTONE_DARK, Enum.Material.Sandstone)
	end
	-- plateau sand and a rim of rock along the edge
	Builder.block(g, "Plateau", Vector3.new(0, TOP + 0.3, zc), Vector3.new(320, 0.6, depth), SAND, Enum.Material.Sand)
	-- ledges on the face: steps to scramble up, ripples of darker rock
	local rng = Random.new(if side > 0 then 21 else 22)
	for i = 1, 14 do
		local lx = -140 + i * 19 + rng:NextNumber(-4, 4)
		local blocked = false
		for _, c in caves do
			if math.abs(lx - c.X) < c.Width / 2 + 4 then
				blocked = true
			end
		end
		if not blocked then
			local h = rng:NextNumber(4, TOP - 4)
			Builder.block(g, "Ledge", Vector3.new(lx, h / 2, z0 - side * 2), Vector3.new(rng:NextNumber(8, 16), h, 4), SANDSTONE_DARK, Enum.Material.Sandstone)
		end
	end
	-- carved ramps from the gorge floor up the face (always there: cliffs stay solid)
	for _, rx in { -132, 88 } do
		local low = Vector3.new(rx, 0, z0 - side * 4)
		local mid = Vector3.new(rx + 40, TOP, z0 - side * 4)
		local flat = mid - low
		local c = Vector3.new((low.X + mid.X) / 2, TOP / 2, low.Z)
		Builder.ramp(g, "CliffRamp", CFrame.lookAt(c, c - Vector3.new(flat.X, 0, 0)), Vector3.new(7, TOP, flat.X), SANDSTONE_DARK, Enum.Material.Sandstone)
	end
end

local function gorge(model: Model)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	Builder.block(g, "Bedrock", Vector3.new(0, -9, 0), Vector3.new(320, 6, 320), SANDSTONE_DARK, Enum.Material.Sandstone)
	-- gorge floor either side of the river, and the river bed
	for _, side in { -1, 1 } do
		local w = GORGE - RIVER
		Builder.block(g, "GorgeFloor", Vector3.new(0, -3, side * (RIVER + w / 2)), Vector3.new(320, 6, w), SAND, Enum.Material.Sand)
	end
	-- a shallow river: wade across (1.5 studs deep over a pebble bed)
	Builder.block(g, "RiverBed", Vector3.new(0, -3.5, 0), Vector3.new(320, 4, RIVER * 2), Color3.fromRGB(120, 100, 80), Enum.Material.Pebble)
	local water = Builder.part(g, { Name = "River", Size = Vector3.new(320, 1.3, RIVER * 2), CFrame = CFrame.new(0, -0.85, 0), Color = Color3.fromRGB(50, 150, 210), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, CastShadow = false })
	water.CanQuery = false
	-- stone banks along the river (the low walls in the reference)
	for _, side in { -1, 1 } do
		Builder.block(g, "RiverBank", Vector3.new(0, -0.6, side * (RIVER + 0.6)), Vector3.new(320, 1.2, 1.2), Color3.fromRGB(150, 130, 110), Enum.Material.Cobblestone)
	end
	-- stepping stones across the river
	for _, x in { -100, -30, 90 } do
		for k = -1, 1 do
			Builder.block(g, "SteppingStone", Vector3.new(x + k * 0.8, -1.2, k * 5), Vector3.new(4, 1.6, 3.4), Color3.fromRGB(150, 130, 110), Enum.Material.Slate)
		end
	end
	cliff(g, 1, NORTH_CAVES)
	cliff(g, -1, SOUTH_CAVES)
end

-- a palm and a couple of bushes on the river bank (they break)
local function bank(model: Model, at: Vector3, rng: Random)
	Builder.palm(model, at, rng:NextNumber(12, 18))
	local bush = Builder.building(model, "Bush")
	for i = 1, 2 do
		local b = Builder.part(bush, { Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4) * rng:NextNumber(0.8, 1.3), CFrame = CFrame.new(at + Vector3.new(rng:NextNumber(-4, 4), 1.4, rng:NextNumber(-3, 3))), Color = BUSH:Lerp(Color3.fromRGB(140, 180, 80), i / 3), Material = Enum.Material.LeafyGrass })
		Builder.structural(b, 1, i == 1, 30)
	end
end

local function adobeStyle(openSide: string?): Builder.HighriseStyle
	return {
		SlabColor = PLANK,
		SlabMaterial = Enum.Material.WoodPlanks,
		ColumnColor = TIMBER,
		ColumnMaterial = Enum.Material.Wood,
		WallColor = ADOBE,
		WallMaterial = Enum.Material.Sandstone,
		WallTransparency = 0,
		Windows = true,
		Stairwell = true,
		OpenSide = openSide,
	}
end

-- a two-storey adobe market hall with timber vigas poking out under the roof and stalls
-- inside the ground floor
local function marketHall(model: Model, name: string, base: Vector3, w: number, d: number, openSide: string?): Model
	local hall, roofY = Builder.highrise(model, name, base, w, d, 2, 11, adobeStyle(openSide))
	-- vigas: timber beam ends along the top of the north and south walls
	for x = -w / 2 + 3, w / 2 - 3, 4 do
		for _, sz in { -1, 1 } do
			local beam = Builder.part(hall, { Name = "Viga", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1, 1), CFrame = CFrame.new(base.X + x, roofY - 1, base.Z + sz * (d / 2 + 0.6)) * CFrame.Angles(0, math.rad(90), 0), Color = TIMBER, Material = Enum.Material.Wood })
			Builder.structural(beam, 3, false, 20)
		end
	end
	-- a low parapet around the flat roof
	for _, e in { { Vector3.new(0, 0, d / 2), Vector3.new(w, 1.4, 0.8) }, { Vector3.new(0, 0, -d / 2), Vector3.new(w, 1.4, 0.8) }, { Vector3.new(w / 2, 0, 0), Vector3.new(0.8, 1.4, d) }, { Vector3.new(-w / 2, 0, 0), Vector3.new(0.8, 1.4, d) } } do
		local p = Builder.block(hall, "Parapet", Vector3.new(base.X, roofY + 0.7, base.Z) + e[1], e[2], ADOBE, Enum.Material.Sandstone)
		Builder.structural(p, 3, false, 60)
	end
	-- patterned rugs hanging over the upper-floor sill, and a striped cloth awning
	local rugColors = { Color3.fromRGB(170, 40, 40), Color3.fromRGB(60, 70, 150), Color3.fromRGB(190, 120, 40) }
	for i, x in { -w / 4, w / 4 } do
		local rug = Builder.block(hall, "HangingRug", Vector3.new(base.X + x, base.Y + 14, base.Z - d / 2 - 0.5), Vector3.new(4, 5, 0.2), rugColors[(i + math.floor(w)) % #rugColors + 1], Enum.Material.Fabric)
		Builder.structural(rug, 2, false, 10)
		rug.CanCollide = false
		local trim = Builder.block(hall, "RugTrim", Vector3.new(base.X + x, base.Y + 14, base.Z - d / 2 - 0.62), Vector3.new(3, 3.6, 0.1), Color3.fromRGB(240, 210, 140), Enum.Material.Fabric)
		Builder.structural(trim, 2, false, 5)
		trim.CanCollide = false
	end
	local awning = Builder.part(hall, { Name = "Awning", Size = Vector3.new(w * 0.7, 0.3, 4), CFrame = CFrame.new(base.X, base.Y + 8.5, base.Z - d / 2 - 2) * CFrame.Angles(math.rad(-15), 0, 0), Color = rugColors[(math.floor(w) % #rugColors) + 1], Material = Enum.Material.Fabric, CanCollide = false })
	Builder.structural(awning, 1, false, 10)

	-- shop counters inside on the ground floor
	for _, x in { -w / 4, w / 4 } do
		local counter = Builder.block(hall, "ShopCounter", Vector3.new(base.X + x, base.Y + 1.6, base.Z + d / 2 - 4), Vector3.new(7, 3.2, 2), TIMBER, Enum.Material.Wood)
		Builder.structural(counter, 1, false, 40)
		local goods = Builder.block(hall, "Goods", Vector3.new(base.X + x, base.Y + 3.6, base.Z + d / 2 - 4), Vector3.new(6, 0.8, 1.6), ({ Color3.fromRGB(230, 80, 60), Color3.fromRGB(240, 190, 60), Color3.fromRGB(90, 170, 210) })[(math.floor(x) % 3) + 1], Enum.Material.Fabric)
		Builder.structural(goods, 1, false, 15)
	end
	return hall
end

-- a wooden scaffolding tower in the gorge: four timber legs, a deck at mid height and a
-- ladder up the cliff face behind it
local function scaffold(model: Model, base: Vector3, height: number, cliffSide: number): (Model, number)
	local s = Builder.building(model, "Scaffold")
	for _, c in { Vector3.new(4, 0, 4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, -4) } do
		local leg = Builder.block(s, "Leg", base + c + Vector3.new(0, height / 2, 0), Vector3.new(1.2, height, 1.2), TIMBER, Enum.Material.Wood)
		Builder.structural(leg, 1, true, 70)
	end
	for _, y in { height * 0.5 } do
		for _, sz in { -1, 1 } do
			local brace = Builder.block(s, "Brace", base + Vector3.new(0, y, sz * 4), Vector3.new(9, 0.6, 0.6), TIMBER, Enum.Material.Wood)
			Builder.structural(brace, 1, false, 20)
		end
	end
	local deck = Builder.block(s, "Deck", base + Vector3.new(0, height + 0.5, 0), Vector3.new(10, 1, 10), PLANK, Enum.Material.WoodPlanks)
	Builder.structural(deck, 2, false, 60)
	local ladder = Builder.part(s, { Name = "Ladder", Class = "TrussPart", Size = Vector3.new(2, height + 1, 2), CFrame = CFrame.new(base + Vector3.new(5.2, (height + 1) / 2, 0)), Color = TIMBER, Material = Enum.Material.Wood })
	Builder.structural(ladder, 1, false, 40)
	-- a ladder from the deck up the cliff face to the plateau
	local face = Vector3.new(base.X, 0, cliffSide * (GORGE - 1))
	local cliffLadder = Builder.part(s, { Name = "CliffLadder", Class = "TrussPart", Size = Vector3.new(2, TOP - height + 2, 2), CFrame = CFrame.new(face.X, height + (TOP - height + 2) / 2, face.Z), Color = TIMBER, Material = Enum.Material.Wood })
	Builder.structural(cliffLadder, 2, false, 40)
	return s, base.Y + height + 1
end

-- inside a cave: pillars, a treasure pile, chests and crates
local function treasureRoom(model: Model, c: Cave, side: number, tomb: boolean)
	local room = Builder.building(model, if tomb then "Tomb" else "TreasureRoom")
	local z0 = side * GORGE
	for _, px in { -c.Width / 2 + 4, c.Width / 2 - 4 } do
		for _, dz in { 8, c.Depth - 8 } do
			local pillar = Builder.block(room, "Pillar", Vector3.new(c.X + px, c.Height / 2, z0 + side * dz), Vector3.new(2.4, c.Height, 2.4), SANDSTONE_DARK, Enum.Material.Sandstone)
			Builder.structural(pillar, 1, true, 160)
		end
	end
	if tomb then
		local sarc = Builder.block(room, "Sarcophagus", Vector3.new(c.X, 1.6, z0 + side * (c.Depth - 6)), Vector3.new(4, 3.2, 8), Color3.fromRGB(190, 160, 90), Enum.Material.Sandstone)
		Builder.structural(sarc, 1, false, 120)
		local lid = Builder.block(room, "Lid", Vector3.new(c.X, 3.5, z0 + side * (c.Depth - 6)), Vector3.new(4.4, 0.6, 8.4), GOLD, Enum.Material.Metal)
		Builder.structural(lid, 1, false, 60)
	else
		for i = 1, 3 do
			local pile = Builder.part(room, { Name = "GoldPile", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5) * (1 - i * 0.15), CFrame = CFrame.new(c.X + (i - 2) * 4, 0.6, z0 + side * (c.Depth - 6)), Color = GOLD, Material = Enum.Material.Neon })
			Builder.structural(pile, 1, false, 30)
		end
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 22
		light.Brightness = 1.6
		light.Parent = room:FindFirstChild("GoldPile") :: Instance
	end
	for _, dx in { -6, 6 } do
		local chest = Builder.block(room, "Chest", Vector3.new(c.X + dx, 1.2, z0 + side * (c.Depth - 3)), Vector3.new(4, 2.4, 2.6), TIMBER, Enum.Material.Wood)
		Builder.structural(chest, 1, false, 40)
		local band = Builder.block(room, "ChestBand", Vector3.new(c.X + dx, 2.5, z0 + side * (c.Depth - 3)), Vector3.new(4.2, 0.3, 2.8), GOLD, Enum.Material.Metal)
		Builder.structural(band, 1, false, 10)
	end
	Builder.crates(model, Vector3.new(c.X - c.Width / 2 + 3, 0, z0 + side * 6), 3)
	-- torches at the mouth
	for _, dx in { -c.Width / 2 + 1.5, c.Width / 2 - 1.5 } do
		local torch = Builder.neon(room, Vector3.new(c.X + dx, 6, z0 + side * 1.5), Vector3.new(0.8, 1.4, 0.8), Color3.fromRGB(255, 150, 60))
		Builder.structural(torch, 1, false, 5)
	end
end

function OasisBazaar.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "OasisBazaar"
	model.Parent = parent
	local rng = Random.new(12)

	gorge(model)

	-- market halls: one in the gorge (south bank), one on each plateau
	marketHall(model, "BazaarHall", Vector3.new(56, 0, -21), 24, 16, "East")
	marketHall(model, "MerchantHouse", Vector3.new(-30, TOP + 0.6, 70), 26, 20, nil)
	marketHall(model, "CaravanInn", Vector3.new(44, TOP + 0.6, -74), 24, 20, "West")
	-- a small adobe watch post on each rim
	for _, p in { Vector3.new(100, TOP + 0.6, 46), Vector3.new(-96, TOP + 0.6, -48) } do
		Builder.highrise(model, "WatchPost", p, 10, 10, 2, 9, adobeStyle(nil))
	end

	-- caves
	for _, c in NORTH_CAVES do
		treasureRoom(model, c, 1, false)
	end
	for _, c in SOUTH_CAVES do
		treasureRoom(model, c, -1, true)
	end

	-- scaffolding towers and the low walkway across the river
	local scaffN, topN = scaffold(model, Vector3.new(10, 0, 20), 13, 1)
	local scaffS, topS = scaffold(model, Vector3.new(10, 0, -20), 13, -1)
	Builder.restsOn(Builder.bridge(model, "RiverWalk", Vector3.new(10, topN, 15), Vector3.new(10, topS, -15), 5, PLANK, Enum.Material.WoodPlanks, ROPE, TIMBER, 45), scaffN)
	local _ = scaffS
	local scaffE, topE = scaffold(model, Vector3.new(-86, 0, 20), 13, 1)
	Builder.restsOn(Builder.bridge(model, "RiverWalk", Vector3.new(-86, topE, 15), Vector3.new(-86, 1.2, -12), 5, PLANK, Enum.Material.WoodPlanks, ROPE, TIMBER, 45), scaffE)

	-- rope bridges between the plateaus (cut them to strand a side)
	for _, x in { -36, 70 } do
		Builder.bridge(model, "RopeBridge", Vector3.new(x, TOP + 0.4, GORGE + 2), Vector3.new(x, TOP + 0.4, -GORGE - 2), 6, PLANK, Enum.Material.WoodPlanks, ROPE, TIMBER, 35)
	end
	-- small footbridges over the river on the gorge floor
	for _, x in { -60, 40 } do
		Builder.bridge(model, "FootBridge", Vector3.new(x, 0.4, RIVER + 2), Vector3.new(x, 0.4, -RIVER - 2), 5, PLANK, Enum.Material.WoodPlanks, ROPE, TIMBER, 40)
	end

	-- palms and bushes along both banks
	for i = -6, 6 do
		if i ~= 0 then
			for _, side in { -1, 1 } do
				local x = i * 22 + rng:NextNumber(-5, 5)
				-- keep clear of the gorge market hall, the scaffolds and the bridges
				local clear = not (side < 0 and x > 38 and x < 74) and math.abs(x - 10) > 9 and math.abs(x + 86) > 9 and math.abs(x + 60) > 6 and math.abs(x - 40) > 6
				if clear and rng:NextNumber() < 0.65 then
					bank(model, Vector3.new(x, 0, side * (RIVER + 4 + rng:NextNumber(0, 6))), rng)
				end
			end
		end
	end

	-- the natural rock arch spanning the gorge (walk across it; the reference's sunlit arch)
	local arch = Instance.new("Folder")
	arch.Name = "RockArch"
	arch.Parent = model
	local segs = 9
	for i = 0, segs - 1 do
		local a0 = math.pi * i / segs
		local a1 = math.pi * (i + 1) / segs
		local function at(a: number): Vector3
			return Vector3.new(-112, TOP + 4 + math.sin(a) * 18, math.cos(a) * (GORGE + 6))
		end
		local p0, p1 = at(a0), at(a1)
		Builder.part(arch, { Name = "Arch", Size = Vector3.new(16, 6, (p1 - p0).Magnitude + 2), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = SANDSTONE, Material = Enum.Material.Sandstone })
	end
	-- bunting: lines of colourful pennants strung across the gorge between the rims
	local flagColors = { Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 200, 50), Color3.fromRGB(60, 170, 90), Color3.fromRGB(60, 120, 220), Color3.fromRGB(230, 120, 40) }
	for line, x in { -10, 34, 96 } do
		local a = Vector3.new(x, TOP + 6, GORGE + 1)
		local b = Vector3.new(x + 8, TOP + 6, -GORGE - 1)
		local rope = Builder.part(model, { Name = "BuntingRope", Size = Vector3.new(0.2, 0.2, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2 - Vector3.new(0, 3, 0), b - Vector3.new(0, 3, 0)), Color = ROPE, Material = Enum.Material.Fabric })
		deco(rope)
		local count = 14
		for i = 1, count do
			local t = i / (count + 1)
			local sag = math.sin(t * math.pi) * 3
			local p = a:Lerp(b, t) - Vector3.new(0, 3 + sag + 0.9, 0)
			local flag = Builder.part(model, { Name = "Pennant", Class = "WedgePart", Size = Vector3.new(0.2, 1.8, 1.6), CFrame = CFrame.lookAt(p, p + (b - a).Unit) * CFrame.Angles(math.pi, math.rad(90), 0), Color = flagColors[(i + line) % #flagColors + 1], Material = Enum.Material.Fabric })
			deco(flag)
		end
	end
	-- lanterns hanging from the rope bridges
	for _, x in { -36, 70 } do
		for _, z in { -14, 14 } do
			local chain = Builder.part(model, { Name = "LanternChain", Size = Vector3.new(0.2, 3, 0.2), CFrame = CFrame.new(x + 6.2, TOP - 1.6, z), Color = Color3.fromRGB(60, 50, 40), Material = Enum.Material.Metal })
			deco(chain)
			local lantern = Builder.part(model, { Name = "Lantern", Size = Vector3.new(1.2, 1.6, 1.2), CFrame = CFrame.new(x + 6.2, TOP - 3.8, z), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon })
			deco(lantern)
		end
	end

	-- mesas and dunes on the horizon (decor)
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(200, 270)
		local h = rng:NextNumber(30, 80)
		deco(Builder.block(model, "Mesa", Vector3.new(math.cos(a) * dist, h / 2 - 6, math.sin(a) * dist), Vector3.new(rng:NextNumber(40, 80), h, rng:NextNumber(40, 80)), SANDSTONE:Lerp(Color3.fromRGB(240, 170, 110), rng:NextNumber()), Enum.Material.Sandstone))
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-60, 3, 20), Vector3.new(40, 3, -20), Vector3.new(0, 3, 22), Vector3.new(-120, 3, -20),
		Vector3.new(-30, TOP + 4, 50), Vector3.new(40, TOP + 4, -55), Vector3.new(100, TOP + 4, 70), Vector3.new(-100, TOP + 4, -70),
		Vector3.new(-64, 3, 50), Vector3.new(20, 3, -46), Vector3.new(0, TOP + 4, 100), Vector3.new(0, TOP + 4, -100),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "OasisBazaar",
		DisplayName = "Oasis Bazaar",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 15,
		FluidColor = Color3.fromRGB(60, 140, 190),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "FLASH FLOOD",
		Lighting = "Canyon",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 135,
	}
end

return OasisBazaar
