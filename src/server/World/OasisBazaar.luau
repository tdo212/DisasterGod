--!strict
-- Arena 12: Oasis Bazaar. A sun-drenched sandstone city walled in by towering red-rock
-- canyon cliffs, with a shallow turquoise oasis river along its east side.
--   * A walled arena: sheer red cliffs on every side (impassable, with an invisible cap).
--   * Eight 3-4 storey sandstone apartment blocks with window holes, stairwell ladders to
--     every floor and the roof, timber balconies, outside ladders and striped rooftop
--     awnings; wooden scaffold bridges link neighbouring roofs.
--   * The palace minaret by the river: a three-storey base, a tall shaft with a ladder up to
--     its balcony, a lantern room and a white dome. Knock out its base and it topples into
--     the river.
--   * The oasis river runs in a shallow channel (about 1.5 studs of water over a sandy bed)
--     between palm-lined banks; three plank bridges cross it to a terrace of small houses.
--   * Market stalls, barrels, crates and lanterns along the streets (Details pass).
-- Sudden death: a flash flood pours into the canyon. Get up the apartment blocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local SAND = Color3.fromRGB(236, 206, 150)
local SANDSTONE = Color3.fromRGB(226, 190, 138)
local ADOBE = Color3.fromRGB(232, 200, 150)
local CLIFF = Color3.fromRGB(190, 92, 58)
local CLIFF_LIGHT = Color3.fromRGB(214, 120, 76)
local TIMBER = Color3.fromRGB(120, 78, 46)
local PLANK = Color3.fromRGB(160, 116, 70)
local WATER = Color3.fromRGB(70, 200, 215)
local DOME = Color3.fromRGB(245, 238, 225)
local GOLD = Color3.fromRGB(255, 200, 70)
local STRIPES = {
	{ Color3.fromRGB(220, 50, 40), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(40, 110, 200), Color3.fromRGB(245, 240, 225) },
	{ Color3.fromRGB(40, 160, 70), Color3.fromRGB(250, 210, 40) },
}

local HX, HZ = 120, 110 -- interior half-size
local RIVER_W0, RIVER_W1 = 52, 88 -- the river channel (x)
local WATER_X0, WATER_X1 = 62, 78 -- the water itself
local BANK_Y = -3
local BED_Y = -5
local FLOOR_H = 11

local OasisBazaar = {}

local function deco(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function grounds(model: Model)
	local g = Instance.new("Folder")
	g.Name = "Ground"
	g.Parent = model
	-- the city plateau (west) and the house terrace (east), at street level 0
	Builder.block(g, "CityGround", Vector3.new((RIVER_W0 - 200) / 2, -4, 0), Vector3.new(RIVER_W0 + 200, 8, 420), SAND, Enum.Material.Sand)
	Builder.block(g, "TerraceGround", Vector3.new((RIVER_W1 + 200) / 2, -4, 0), Vector3.new(200 - RIVER_W1, 8, 420), SAND, Enum.Material.Sand)
	-- the river channel: sandy banks, a bed and a shallow sheet of clear water over it
	Builder.block(g, "Bank", Vector3.new((RIVER_W0 + WATER_X0) / 2, BANK_Y - 4, 0), Vector3.new(WATER_X0 - RIVER_W0, 8, 420), SAND, Enum.Material.Sand)
	Builder.block(g, "Bank", Vector3.new((WATER_X1 + RIVER_W1) / 2, BANK_Y - 4, 0), Vector3.new(RIVER_W1 - WATER_X1, 8, 420), SAND, Enum.Material.Sand)
	Builder.block(g, "RiverBed", Vector3.new((WATER_X0 + WATER_X1) / 2, BED_Y - 4, 0), Vector3.new(WATER_X1 - WATER_X0, 8, 420), Color3.fromRGB(214, 196, 150), Enum.Material.Sand)
	local water = Builder.block(g, "River", Vector3.new((WATER_X0 + WATER_X1) / 2, BED_Y + 0.8, 0), Vector3.new(WATER_X1 - WATER_X0, 1.6, 420), WATER, Enum.Material.SmoothPlastic)
	water.Transparency = 0.4
	deco(water)
	-- paved market streets through the city
	for _, spec in { { Vector3.new(-70, 0.05, 0), Vector3.new(14, 0.1, 210) }, { Vector3.new(-20, 0.05, -40), Vector3.new(120, 0.1, 12) }, { Vector3.new(-20, 0.05, 40), Vector3.new(120, 0.1, 12) } } do
		deco(Builder.block(g, "Street", spec[1], spec[2], Color3.fromRGB(214, 180, 128), Enum.Material.Cobblestone))
	end
end

-- Towering red-rock cliffs on every side: two stacked, jagged blocks per stretch.
local function cliffs(model: Model, rng: Random)
	local f = Instance.new("Folder")
	f.Name = "Cliffs"
	f.Parent = model
	local function stretch(from: Vector3, to: Vector3, outward: Vector3, count: number)
		for i = 0, count - 1 do
			local t = (i + 0.5) / count
			local at = from:Lerp(to, t)
			local len = (to - from).Magnitude / count + 8
			local h = rng:NextNumber(58, 86)
			local depth = rng:NextNumber(28, 40)
			local alongX = math.abs(outward.Z) > 0
			local c = at + outward * (depth / 2 - rng:NextNumber(0, 4))
			local col = CLIFF:Lerp(CLIFF_LIGHT, rng:NextNumber())
			Builder.block(f, "Cliff", c + Vector3.new(0, h / 2 - 8, 0), if alongX then Vector3.new(len, h, depth) else Vector3.new(depth, h, len), col, Enum.Material.Sandstone)
			local h2 = rng:NextNumber(8, 20)
			local inset = rng:NextNumber(6, 12)
			Builder.block(f, "CliffTop", c + outward * inset + Vector3.new(rng:NextNumber(-6, 6) * (if alongX then 1 else 0), h - 8 + h2 / 2, rng:NextNumber(-6, 6) * (if alongX then 0 else 1)), if alongX then Vector3.new(len * 0.7, h2, depth - inset) else Vector3.new(depth - inset, h2, len * 0.7), col:Lerp(CLIFF_LIGHT, 0.3), Enum.Material.Sandstone)
		end
		local mid = (from + to) / 2 + outward * 20
		local alongX = math.abs(outward.Z) > 0
		local len = (to - from).Magnitude + 60
		Builder.boundary(f, mid + Vector3.new(0, 130, 0), if alongX then Vector3.new(len, 200, 40) else Vector3.new(40, 200, len))
	end
	stretch(Vector3.new(-HX - 10, 0, HZ), Vector3.new(HX + 10, 0, HZ), Vector3.new(0, 0, 1), 8)
	stretch(Vector3.new(-HX - 10, 0, -HZ), Vector3.new(HX + 10, 0, -HZ), Vector3.new(0, 0, -1), 8)
	stretch(Vector3.new(HX, 0, -HZ), Vector3.new(HX, 0, HZ), Vector3.new(1, 0, 0), 6)
	stretch(Vector3.new(-HX, 0, -HZ), Vector3.new(-HX, 0, HZ), Vector3.new(-1, 0, 0), 6)
end

-- A striped awning on four timber posts, standing on a roof.
local function roofAwning(model: Model, base: Model, at: Vector3, rng: Random)
	local m = Builder.building(model, "RoofAwning")
	for _, c in { Vector3.new(5, 0, 4), Vector3.new(-5, 0, 4), Vector3.new(5, 0, -4), Vector3.new(-5, 0, -4) } do
		local post = Builder.block(m, "Post", at + c + Vector3.new(0, 3.5, 0), Vector3.new(0.7, 7, 0.7), TIMBER, Enum.Material.Wood)
		Builder.structural(post, 1, true, 25)
	end
	local s = STRIPES[rng:NextInteger(1, #STRIPES)]
	for i = 0, 3 do
		local strip = Builder.block(m, "Canvas", at + Vector3.new(-4.5 + i * 3, 7.2, 0), Vector3.new(3, 0.4, 10), if i % 2 == 0 then s[1] else s[2], Enum.Material.Fabric)
		strip.CastShadow = false
		Builder.structural(strip, 2, false, 15)
	end
	Builder.restsOn(m, base)
end

-- A sandstone apartment block with a timber balcony on its front.
local function apartment(model: Model, at: Vector3, w: number, d: number, floors: number, openSide: string?): (Model, number)
	local block, roofY = Builder.highrise(model, "Apartment", at, w, d, floors, FLOOR_H, {
		SlabColor = SANDSTONE,
		SlabMaterial = Enum.Material.Sandstone,
		ColumnColor = ADOBE,
		ColumnMaterial = Enum.Material.Sandstone,
		WallColor = ADOBE,
		WallMaterial = Enum.Material.Sandstone,
		WallTransparency = 0,
		Stairwell = true,
		Windows = true,
		OpenSide = openSide,
	})
	-- a timber balcony on the second floor front (south)
	local by = at.Y + FLOOR_H + 1.5
	local deck = Builder.block(block, "Balcony", at + Vector3.new(0, by - at.Y, -d / 2 - 2.2), Vector3.new(w * 0.5, 0.8, 4), PLANK, Enum.Material.WoodPlanks)
	Builder.structural(deck, 2, false, 30)
	local rail = Builder.block(block, "BalconyRail", at + Vector3.new(0, by - at.Y + 1.6, -d / 2 - 4), Vector3.new(w * 0.5, 2.4, 0.4), TIMBER, Enum.Material.Wood)
	rail.CastShadow = false
	Builder.structural(rail, 2, false, 15)
	return block, roofY
end

-- The palace minaret: a three-storey base, a shaft with a ladder, a balcony, a lantern room
-- and a white dome with a gold finial. It topples east into the river.
local function minaret(model: Model, at: Vector3): Model
	local base, roofY = Builder.highrise(model, "Minaret", at, 18, 18, 3, FLOOR_H, {
		SlabColor = SANDSTONE,
		SlabMaterial = Enum.Material.Sandstone,
		ColumnColor = ADOBE,
		ColumnMaterial = Enum.Material.Sandstone,
		WallColor = Color3.fromRGB(240, 214, 168),
		WallMaterial = Enum.Material.Sandstone,
		WallTransparency = 0,
		Stairwell = true,
		Windows = true,
		Health = 260,
	})
	Builder.facadeTrim(base, GOLD, Enum.Material.Metal)
	local lvl = 5
	local y = roofY
	for i = 1, 3 do
		local seg = Builder.cylinder(base, "Shaft", Vector3.new(at.X, y + 6, at.Z), 12, 11 - i, Color3.fromRGB(240, 214, 168), Enum.Material.Sandstone)
		Builder.structural(seg, lvl, true, 220)
		local band = Builder.cylinder(base, "ShaftBand", Vector3.new(at.X, y + 11.6, at.Z), 0.8, 12 - i, GOLD, Enum.Material.Metal)
		band.CastShadow = false
		Builder.structural(band, lvl, false, 30)
		y += 12
		lvl += 1
	end
	local ladder = Builder.part(base, {
		Name = "ShaftLadder",
		Class = "TrussPart",
		Size = Vector3.new(2, y - roofY + 2, 2),
		CFrame = CFrame.new(at.X - 6, (roofY + y + 2) / 2, at.Z),
		Color = TIMBER,
		Material = Enum.Material.Wood,
	})
	Builder.structural(ladder, 5, false, 60)
	local balcony = Builder.cylinder(base, "Balcony", Vector3.new(at.X, y + 0.5, at.Z), 1, 18, ADOBE, Enum.Material.Sandstone)
	Builder.structural(balcony, lvl, false, 120)
	local lantern = Builder.cylinder(base, "Lantern", Vector3.new(at.X, y + 4.5, at.Z), 7, 7, Color3.fromRGB(240, 214, 168), Enum.Material.Sandstone)
	Builder.structural(lantern, lvl, true, 140)
	local glow = Builder.cylinder(base, "LanternGlow", Vector3.new(at.X, y + 4.5, at.Z), 2, 7.3, Color3.fromRGB(255, 190, 90), Enum.Material.Neon)
	glow.CastShadow = false
	Builder.structural(glow, lvl, false, 20)
	local dome = Builder.part(base, { Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9), CFrame = CFrame.new(at.X, y + 9, at.Z), Color = DOME, Material = Enum.Material.SmoothPlastic })
	Builder.structural(dome, lvl + 1, false, 100)
	local finial = Builder.cylinder(base, "Finial", Vector3.new(at.X, y + 15, at.Z), 4, 0.8, GOLD, Enum.Material.Metal)
	Builder.structural(finial, lvl + 1, false, 20)
	Builder.fallDirection(base, Vector3.new(1, 0, 0))
	return base
end

local function wooden(model: Model, name: string, a: Vector3, b: Vector3, base: Model?)
	local bridge = Builder.bridge(model, name, a, b, 12, PLANK, Enum.Material.WoodPlanks, Color3.fromRGB(200, 170, 120), TIMBER, 60)
	if base then
		Builder.restsOn(bridge, base)
	end
end

function OasisBazaar.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "OasisBazaar"
	model.Parent = parent
	local rng = Random.new()

	grounds(model)
	cliffs(model, rng)

	-- the city: eight apartment blocks around the market streets
	local blocks: { { Model | number } } = {}
	for _, spec in {
		{ Vector3.new(-98, 0, -80), 24, 22, 3, nil },
		{ Vector3.new(-98, 0, -14), 22, 24, 4, "East" },
		{ Vector3.new(-98, 0, 64), 24, 22, 3, nil },
		{ Vector3.new(-44, 0, -84), 24, 22, 4, nil },
		{ Vector3.new(-42, 0, 0), 26, 24, 3, "West" },
		{ Vector3.new(-44, 0, 82), 24, 22, 4, nil },
		{ Vector3.new(10, 0, -80), 22, 22, 3, nil },
		{ Vector3.new(10, 0, 76), 22, 24, 4, "East" },
	} do
		local m, roofY = apartment(model, spec[1] :: Vector3, spec[2] :: number, spec[3] :: number, spec[4] :: number, spec[5] :: string?)
		table.insert(blocks, { m, roofY })
	end
	for i, b in blocks do
		if i % 2 == 1 or i == 8 then
			local m = b[1] :: Model
			local at = m:GetAttribute("BaseCenter") :: Vector3
			roofAwning(model, m, Vector3.new(at.X + 3, b[2] :: number, at.Z + 2), rng)
		end
	end
	-- scaffold bridges between neighbouring roofs (both are 4 storeys: 2 and 4; 6 and 8)
	local function roofOf(i: number): (Vector3, number)
		local m = blocks[i][1] :: Model
		return m:GetAttribute("BaseCenter") :: Vector3, blocks[i][2] :: number
	end
	do
		local a, ay = roofOf(2)
		local b, by = roofOf(4)
		wooden(model, "RoofBridge", Vector3.new(a.X + 8, ay + 0.5, a.Z - 8), Vector3.new(b.X - 8, by + 0.5, b.Z + 8), blocks[2][1] :: Model)
		local c, cy = roofOf(6)
		local d, dy = roofOf(8)
		wooden(model, "RoofBridge", Vector3.new(c.X + 8, cy + 0.5, c.Z), Vector3.new(d.X - 6, dy + 0.5, d.Z), blocks[6][1] :: Model)
		local e, ey = roofOf(5)
		wooden(model, "RoofBridge", Vector3.new(e.X - 9, ey + 0.5, e.Z - 6), Vector3.new(a.X + 7, ay + 0.5, a.Z + 2), blocks[5][1] :: Model)
	end

	minaret(model, Vector3.new(30, 0, 4))

	-- three plank bridges across the river to the terrace
	for _, z in { -70, 0, 64 } do
		wooden(model, "RiverBridge", Vector3.new(RIVER_W0 - 4, 0.5, z), Vector3.new(RIVER_W1 + 4, 0.5, z), nil)
	end
	-- the terrace: two small houses and stairs down to the water
	Builder.highrise(model, "TerraceHouse", Vector3.new(104, 0, -36), 20, 18, 2, FLOOR_H, {
		SlabColor = SANDSTONE, SlabMaterial = Enum.Material.Sandstone, ColumnColor = ADOBE, ColumnMaterial = Enum.Material.Sandstone,
		WallColor = ADOBE, WallMaterial = Enum.Material.Sandstone, WallTransparency = 0, Stairwell = true, Windows = true,
	})
	Builder.highrise(model, "TerraceHouse", Vector3.new(104, 0, 34), 20, 20, 2, FLOOR_H, {
		SlabColor = SANDSTONE, SlabMaterial = Enum.Material.Sandstone, ColumnColor = ADOBE, ColumnMaterial = Enum.Material.Sandstone,
		WallColor = ADOBE, WallMaterial = Enum.Material.Sandstone, WallTransparency = 0, Stairwell = true, Windows = true, OpenSide = "West",
	})
	Builder.stairs(model, Vector3.new(RIVER_W1 - 10, BANK_Y, -100), Vector3.new(RIVER_W1, 0, -100), 12, SANDSTONE, Enum.Material.Sandstone)
	Builder.stairs(model, Vector3.new(RIVER_W0 + 10, BANK_Y, 100), Vector3.new(RIVER_W0, 0, 100), 12, SANDSTONE, Enum.Material.Sandstone)

	-- palms along both banks
	for _, z in { -80, 0, 80 } do
		Builder.palm(model, Vector3.new(RIVER_W0 + 4, BANK_Y, z + rng:NextNumber(-4, 4)), rng:NextNumber(12, 16))
		Builder.palm(model, Vector3.new(RIVER_W1 - 4, BANK_Y, z + 12 + rng:NextNumber(-4, 4)), rng:NextNumber(12, 16))
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-70, 3, -40), Vector3.new(-70, 3, 40), Vector3.new(-20, 3, -40), Vector3.new(-20, 3, 40),
		Vector3.new(-70, 3, 100), Vector3.new(-70, 3, -100), Vector3.new(36, 3, -40), Vector3.new(36, 3, 44),
		Vector3.new(104, 3, 0), Vector3.new(104, 3, 90), Vector3.new(57, BANK_Y + 3, -30), Vector3.new(83, BANK_Y + 3, 20),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "OasisBazaar",
		DisplayName = "Oasis Bazaar",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -9,
		FluidEndY = 15,
		FluidColor = Color3.fromRGB(70, 170, 200),
		FluidMaterial = Enum.Material.SmoothPlastic,
		HazardFloorY = nil,
		FluidName = "FLASH FLOOD",
		Lighting = "Canyon",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 130,
		Walled = true,
	}
end

return OasisBazaar
