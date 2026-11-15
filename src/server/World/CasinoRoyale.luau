--!strict
-- Arena 11: Casino Royale. An open-air neon strip on a rainy night, walled in by the resort.
--   * A walled arena: cream-and-gold resort facades ring the whole block (impassable, with
--     an invisible cap), two CASINO gatehouses with marquees and red carpets, waterfalls on
--     the east and west walls and pyramid-roofed corner pavilions.
--   * Four 4-5 storey hotel skyscrapers (purple and magenta facades, neon pilasters, gold
--     floor trim, red awnings): stairwell ladders inside every tower reach every floor and
--     the roof. Rooftops: two pools with loungers, a helipad and a cabana.
--   * Glass skybridges join the tower roofs; shear a tower's ground columns and its floors
--     pancake while survivors dash across the bridges.
--   * A central plaza with a golden coin fountain, limousines and palms, wet asphalt
--     boulevards and lane markings all around.
-- Sudden death: liquid gold floods the boulevard. Get up the towers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local CREAM = Color3.fromRGB(232, 214, 180)
local CREAM_DARK = Color3.fromRGB(196, 172, 136)
local GOLD = Color3.fromRGB(240, 190, 80)
local MAROON = Color3.fromRGB(120, 24, 48)
local PURPLE = Color3.fromRGB(110, 50, 170)
local MAGENTA = Color3.fromRGB(170, 40, 120)
local NEON_PINK = Color3.fromRGB(255, 80, 200)
local NEON_PURPLE = Color3.fromRGB(190, 90, 255)
local ASPHALT = Color3.fromRGB(38, 38, 48)
local PAVING = Color3.fromRGB(150, 130, 140)
local WATER = Color3.fromRGB(90, 190, 255)
local AWNING = Color3.fromRGB(170, 30, 40)
local BLACK = Color3.fromRGB(20, 20, 26)

local HALF = 120 -- interior half-size (x and z)
local WALL_T = 14 -- perimeter wall thickness
local WALL_H = 46
local TOWER = 30 -- tower footprint
local TC = 54 -- tower centre offset from the middle
local FLOOR_H = 12

local CasinoRoyale = {}

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
	-- wet asphalt everywhere (it reaches past the walls so the arena has no edge to fall off)
	local road = Builder.block(g, "Boulevard", Vector3.new(0, -3, 0), Vector3.new(520, 6, 520), ASPHALT, Enum.Material.Asphalt)
	road.Reflectance = 0.12
	-- the central plaza and the four tower blocks, a step up from the road
	Builder.block(g, "Plaza", Vector3.new(0, 0.25, 0), Vector3.new(46, 0.5, 46), PAVING, Enum.Material.Marble)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.block(g, "Sidewalk", Vector3.new(sx * TC, 0.25, sz * TC), Vector3.new(TOWER + 10, 0.5, TOWER + 10), PAVING, Enum.Material.Pavement)
		end
	end
	-- dashed lane markings on the boulevards between the blocks and round the ring road
	for i = -3, 3 do
		Builder.block(g, "Lane", Vector3.new(i * 30, 0.03, 0), Vector3.new(12, 0.06, 0.8), GOLD, Enum.Material.SmoothPlastic)
		Builder.block(g, "Lane", Vector3.new(0, 0.03, i * 30), Vector3.new(0.8, 0.06, 12), GOLD, Enum.Material.SmoothPlastic)
		Builder.block(g, "Lane", Vector3.new(i * 30, 0.03, 96), Vector3.new(12, 0.06, 0.8), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		Builder.block(g, "Lane", Vector3.new(i * 30, 0.03, -96), Vector3.new(12, 0.06, 0.8), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
	for _, p in g:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Lane" then
			deco(p)
		end
	end
end

-- The resort facades that wall the arena in: solid, indestructible, too tall to climb.
local function perimeter(model: Model)
	local w = Instance.new("Folder")
	w.Name = "Perimeter"
	w.Parent = model
	local o = HALF + WALL_T / 2
	for _, side in { { Vector3.new(0, 0, o), true, Vector3.new(0, 0, -1) }, { Vector3.new(0, 0, -o), true, Vector3.new(0, 0, 1) }, { Vector3.new(o, 0, 0), false, Vector3.new(-1, 0, 0) }, { Vector3.new(-o, 0, 0), false, Vector3.new(1, 0, 0) } } do
		local c, alongX, inward = side[1] :: Vector3, side[2] :: boolean, side[3] :: Vector3
		local len = HALF * 2 + WALL_T * 2
		local size = if alongX then Vector3.new(len, WALL_H, WALL_T) else Vector3.new(WALL_T, WALL_H, len)
		Builder.block(w, "ResortWall", c + Vector3.new(0, WALL_H / 2, 0), size, CREAM, Enum.Material.SmoothPlastic)
		-- gold cornice and a darker plinth on the inner face
		local face = c + inward * (WALL_T / 2 + 0.4)
		Builder.block(w, "Cornice", face + Vector3.new(0, WALL_H - 1, 0), if alongX then Vector3.new(len - 28, 2, 1.6) else Vector3.new(1.6, 2, len - 28), GOLD, Enum.Material.Metal)
		Builder.block(w, "Plinth", face + Vector3.new(0, 3, 0), if alongX then Vector3.new(len - 28, 6, 1.2) else Vector3.new(1.2, 6, len - 28), CREAM_DARK, Enum.Material.Marble)
		-- two rows of warm lit windows and gold pilasters every 40 studs
		for row = 0, 1 do
			local band = Builder.block(w, "Windows", face + Vector3.new(0, 16 + row * 13, 0), if alongX then Vector3.new(len - 40, 4, 0.6) else Vector3.new(0.6, 4, len - 40), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
			deco(band)
		end
		for i = -2, 2 do
			local at = face + (if alongX then Vector3.new(i * 48, 0, 0) else Vector3.new(0, 0, i * 48))
			Builder.block(w, "Pilaster", at + Vector3.new(0, WALL_H / 2, 0), Vector3.new(3, WALL_H, 3), CREAM_DARK, Enum.Material.Marble)
		end
		-- an invisible cap: nothing climbs, launches or gets flung out of the arena
		Builder.boundary(w, c + Vector3.new(0, WALL_H + 80, 0), size + Vector3.new(0, 160 - WALL_H, 0))
	end
	-- corner pavilions with maroon pyramid roofs
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local c = Vector3.new(sx * (HALF + 4), 0, sz * (HALF + 4))
			Builder.block(w, "Pavilion", c + Vector3.new(0, 27, 0), Vector3.new(34, 54, 34), CREAM, Enum.Material.SmoothPlastic)
			Builder.block(w, "PavilionTrim", c + Vector3.new(0, 54.5, 0), Vector3.new(36, 1.5, 36), GOLD, Enum.Material.Metal)
			Builder.block(w, "PavilionRoof", c + Vector3.new(0, 58, 0), Vector3.new(30, 6, 30), MAROON, Enum.Material.SmoothPlastic)
			Builder.block(w, "PavilionRoof", c + Vector3.new(0, 62.5, 0), Vector3.new(18, 3, 18), MAROON, Enum.Material.SmoothPlastic)
		end
	end
	-- two CASINO gatehouses (north and south) with marquees and red carpets
	for _, sz in { -1, 1 } do
		local face = Vector3.new(0, 0, sz * HALF)
		local inward = Vector3.new(0, 0, -sz)
		Builder.block(w, "Gatehouse", face + inward * 4 + Vector3.new(0, 18, 0), Vector3.new(44, 36, 8), CREAM_DARK, Enum.Material.Marble)
		local doors = Builder.block(w, "Doors", face + inward * 8.2 + Vector3.new(0, 7, 0), Vector3.new(18, 14, 0.4), BLACK, Enum.Material.Glass)
		doors.Transparency = 0.2
		local marquee = Builder.block(w, "Marquee", face + inward * 8.6 + Vector3.new(0, 23, 0), Vector3.new(30, 8, 1), MAROON, Enum.Material.SmoothPlastic)
		Builder.sign(marquee, if sz > 0 then Enum.NormalId.Front else Enum.NormalId.Back, "CASINO", GOLD, Color3.fromRGB(60, 0, 20))
		local glow = Builder.block(w, "MarqueeGlow", face + inward * 8.3 + Vector3.new(0, 23, 0), Vector3.new(32, 10, 0.4), NEON_PINK, Enum.Material.Neon)
		deco(glow)
		Builder.block(w, "Pediment", face + inward * 4 + Vector3.new(0, 38, 0), Vector3.new(48, 4, 10), GOLD, Enum.Material.Metal)
		for _, x in { -18, -10, 10, 18 } do
			Builder.cylinder(w, "Column", face + inward * 9.5 + Vector3.new(x, 9, 0), 18, 2.4, CREAM, Enum.Material.Marble)
		end
		local carpet = Builder.block(w, "RedCarpet", face + inward * 22 + Vector3.new(0, 0.55, 0), Vector3.new(12, 0.1, 26), AWNING, Enum.Material.Fabric)
		deco(carpet)
	end
	-- waterfalls on the east and west walls
	for _, sx in { -1, 1 } do
		local face = Vector3.new(sx * HALF, 0, 0)
		local fall = Builder.block(w, "Waterfall", face + Vector3.new(-sx * 0.8, 20, 0), Vector3.new(0.6, 36, 14), WATER, Enum.Material.Neon)
		fall.Transparency = 0.35
		deco(fall)
		Builder.block(w, "FallBasin", face + Vector3.new(-sx * 5, 1, 0), Vector3.new(10, 2, 20), CREAM_DARK, Enum.Material.Marble)
		local pool = Builder.block(w, "FallPool", face + Vector3.new(-sx * 5, 2.05, 0), Vector3.new(8, 0.1, 18), WATER, Enum.Material.SmoothPlastic)
		pool.Transparency = 0.3
		deco(pool)
	end
end

-- A hotel skyscraper: purple/magenta walls, gold slabs and trim, neon pilasters, red
-- awnings over the ground-floor doors and a lit sign. Returns the tower and its roof Y.
local function hotel(model: Model, name: string, at: Vector3, floors: number, wall: Color3, neon: Color3, title: string): (Model, number)
	local tower, roofY = Builder.highrise(model, name, at, TOWER, TOWER, floors, FLOOR_H, {
		SlabColor = Color3.fromRGB(60, 40, 70),
		SlabMaterial = Enum.Material.Concrete,
		ColumnColor = GOLD,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = wall,
		WallMaterial = Enum.Material.SmoothPlastic,
		WallTransparency = 0,
		Stairwell = true,
		Windows = true,
	})
	Builder.facadeTrim(tower, GOLD, Enum.Material.Metal, neon, Enum.Material.Neon)
	-- red awnings over the ground floor, one per side
	for _, side in { { Vector3.new(0, 0, -1), true }, { Vector3.new(0, 0, 1), true }, { Vector3.new(1, 0, 0), false }, { Vector3.new(-1, 0, 0), false } } do
		local n, alongX = side[1] :: Vector3, side[2] :: boolean
		local a = Builder.part(tower, {
			Name = "Awning",
			Size = if alongX then Vector3.new(TOWER - 6, 0.6, 5) else Vector3.new(5, 0.6, TOWER - 6),
			CFrame = CFrame.new(at + n * (TOWER / 2 + 2.4) + Vector3.new(0, 9, 0)),
			Color = AWNING,
			Material = Enum.Material.Fabric,
			CastShadow = false,
		})
		Builder.structural(a, 1, false, 20)
	end
	-- a lit name sign standing on the roof edge
	local sign = Builder.part(tower, {
		Name = "RoofSign",
		Size = Vector3.new(18, 4, 0.8),
		CFrame = CFrame.new(at + Vector3.new(0, roofY - at.Y + 2.5, -TOWER / 2 + 1)),
		Color = BLACK,
		Material = Enum.Material.SmoothPlastic,
	})
	Builder.structural(sign, floors + 1, false, 30)
	Builder.sign(sign, Enum.NormalId.Front, title, neon, Color3.new(0, 0, 0))
	return tower, roofY
end

local function pool(model: Model, base: Model, at: Vector3)
	local m = Builder.building(model, "RooftopPool")
	local rim = Builder.block(m, "PoolRim", at + Vector3.new(0, 0.6, 0), Vector3.new(18, 1.2, 12), CREAM, Enum.Material.Marble)
	Builder.structural(rim, 1, false, 40)
	local water = Builder.block(m, "PoolWater", at + Vector3.new(0, 1.25, 0), Vector3.new(16, 0.2, 10), WATER, Enum.Material.SmoothPlastic)
	water.Transparency = 0.25
	water.CanCollide = false
	Builder.structural(water, 1, false, 10)
	for i = -1, 1 do
		local lounger = Builder.block(m, "Lounger", at + Vector3.new(i * 5, 0.6, 9), Vector3.new(2.4, 1.2, 5), Color3.new(1, 1, 1), Enum.Material.Fabric)
		Builder.structural(lounger, 1, false, 15)
	end
	Builder.palm(m, at + Vector3.new(10, 0, 8), 8)
	Builder.restsOn(m, base)
end

local function helipad(model: Model, base: Model, at: Vector3)
	local m = Builder.building(model, "Helipad")
	local pad = Builder.cylinder(m, "Helipad", at + Vector3.new(0, 0.4, 0), 0.8, 22, Color3.fromRGB(60, 60, 68), Enum.Material.Concrete)
	Builder.structural(pad, 1, false, 80)
	local h = Builder.block(m, "HeliMark", at + Vector3.new(0, 0.85, 0), Vector3.new(8, 0.1, 8), Color3.fromRGB(250, 210, 60), Enum.Material.SmoothPlastic)
	h.CanCollide = false
	Builder.structural(h, 1, false, 10)
	Builder.sign(h, Enum.NormalId.Top, "H", Color3.fromRGB(40, 40, 40), Color3.fromRGB(250, 210, 60))
	Builder.restsOn(m, base)
end

local function cabana(model: Model, base: Model, at: Vector3)
	local m = Builder.building(model, "Cabana")
	for _, c in { Vector3.new(5, 0, 4), Vector3.new(-5, 0, 4), Vector3.new(5, 0, -4), Vector3.new(-5, 0, -4) } do
		local post = Builder.block(m, "Post", at + c + Vector3.new(0, 3, 0), Vector3.new(0.8, 6, 0.8), GOLD, Enum.Material.Metal)
		Builder.structural(post, 1, true, 30)
	end
	local roof = Builder.block(m, "CabanaRoof", at + Vector3.new(0, 6.5, 0), Vector3.new(12, 1, 10), MAROON, Enum.Material.Fabric)
	Builder.structural(roof, 2, false, 25)
	local sofa = Builder.block(m, "Sofa", at + Vector3.new(0, 0.8, 2), Vector3.new(8, 1.6, 3), Color3.fromRGB(240, 230, 220), Enum.Material.Fabric)
	Builder.structural(sofa, 1, false, 15)
	Builder.restsOn(m, base)
end

-- A long black limousine (destructible).
local function limo(model: Model, at: Vector3, yaw: number, color: Color3)
	local m = Builder.building(model, "Limo")
	local cf = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local body = Builder.part(m, { Name = "Body", Size = Vector3.new(6, 2.4, 18), CFrame = cf * CFrame.new(0, 1.8, 0), Color = color, Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 })
	Builder.structural(body, 1, true, 90)
	local cabin = Builder.part(m, { Name = "Cabin", Size = Vector3.new(5.6, 1.8, 11), CFrame = cf * CFrame.new(0, 3.9, -1), Color = BLACK, Material = Enum.Material.Glass, Transparency = 0.2 })
	Builder.structural(cabin, 2, false, 30)
	for _, w in { Vector3.new(3, 0.9, 6), Vector3.new(-3, 0.9, 6), Vector3.new(3, 0.9, -6), Vector3.new(-3, 0.9, -6) } do
		local wheel = Builder.part(m, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1.8, 1.8), CFrame = cf * CFrame.new(w), Color = BLACK, Material = Enum.Material.SmoothPlastic, CastShadow = false })
		Builder.structural(wheel, 1, false, 20)
	end
end

-- The golden coin fountain in the middle of the plaza.
local function fountain(model: Model)
	local m = Builder.building(model, "CoinFountain")
	local basin = Builder.cylinder(m, "Basin", Vector3.new(0, 1.5, 0), 2, 24, GOLD, Enum.Material.Metal)
	Builder.structural(basin, 1, true, 200)
	local water = Builder.cylinder(m, "FountainWater", Vector3.new(0, 2.55, 0), 0.1, 21, WATER, Enum.Material.SmoothPlastic)
	water.Transparency = 0.25
	water.CanCollide = false
	Builder.structural(water, 1, false, 10)
	local plinth = Builder.cylinder(m, "Plinth", Vector3.new(0, 4.5, 0), 5, 6, CREAM, Enum.Material.Marble)
	Builder.structural(plinth, 1, true, 160)
	for i, spec in { { Vector3.new(0, 10, 0), 0 }, { Vector3.new(-2.5, 9, 1.5), 35 }, { Vector3.new(2.6, 8.5, -1), -30 } } do
		local coin = Builder.part(m, {
			Name = "GiantCoin",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 7, 7),
			CFrame = CFrame.new(spec[1] :: Vector3) * CFrame.Angles(0, math.rad(spec[2] :: number + i * 20), 0),
			Color = Color3.fromRGB(255, 205, 60),
			Material = Enum.Material.Neon,
		})
		Builder.structural(coin, 2, false, 40)
	end
	Builder.fallDirection(m, Vector3.new(1, 0, 0.4))
end

function CasinoRoyale.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "CasinoRoyale"
	model.Parent = parent

	grounds(model)
	perimeter(model)
	fountain(model)

	-- the four hotel towers (NW, NE, SE, SW)
	local nw, nwRoof = hotel(model, "HotelAurum", Vector3.new(-TC, 0.5, TC), 5, PURPLE, NEON_PURPLE, "AURUM")
	local ne, neRoof = hotel(model, "HotelRoyale", Vector3.new(TC, 0.5, TC), 5, MAGENTA, NEON_PINK, "ROYALE")
	local se, seRoof = hotel(model, "HotelJackpot", Vector3.new(TC, 0.5, -TC), 5, PURPLE, NEON_PINK, "JACKPOT")
	local sw, swRoof = hotel(model, "HotelVelvet", Vector3.new(-TC, 0.5, -TC), 4, MAGENTA, NEON_PURPLE, "VELVET")
	pool(model, nw, Vector3.new(-TC + 3, nwRoof, TC + 3))
	pool(model, ne, Vector3.new(TC - 3, neRoof, TC + 3))
	helipad(model, se, Vector3.new(TC + 2, seRoof, -TC - 2))
	cabana(model, sw, Vector3.new(-TC, swRoof, -TC - 4))

	-- glass skybridges between the roofs (the SW link slopes down a storey)
	local edge = TOWER / 2 - 1
	local deckGlass = Color3.fromRGB(170, 220, 255)
	local function skybridge(name: string, a: Vector3, b: Vector3, base: Model)
		local bridge = Builder.bridge(model, name, a, b, 12, deckGlass, Enum.Material.Glass, GOLD, Color3.fromRGB(70, 60, 80), 70)
		Builder.restsOn(bridge, base)
	end
	skybridge("SkybridgeNorth", Vector3.new(-TC + edge, nwRoof + 0.5, TC - 6), Vector3.new(TC - edge, neRoof + 0.5, TC - 6), nw)
	skybridge("SkybridgeEast", Vector3.new(TC - 6, neRoof + 0.5, TC - edge), Vector3.new(TC - 6, seRoof + 0.5, -TC + edge), ne)
	skybridge("SkybridgeWest", Vector3.new(-TC + 6, nwRoof + 0.5, TC - edge), Vector3.new(-TC + 6, swRoof + 0.5, -TC + edge), sw)

	-- searchlight lasers from the Jackpot roof (decor)
	for i, dir in { Vector3.new(-0.5, 1, 0.3), Vector3.new(0.4, 1, -0.6) } do
		local from = Vector3.new(TC + (i - 1.5) * 10, seRoof + 1, -TC + 8)
		local laser = Builder.part(model, { Name = "Laser", Size = Vector3.new(0.6, 0.6, 220), CFrame = CFrame.lookAt(from + dir.Unit * 110, from + dir.Unit * 220), Color = NEON_PINK, Material = Enum.Material.Neon, Transparency = 0.3 })
		deco(laser)
	end

	-- limousines round the plaza and palms on the corners
	limo(model, Vector3.new(-17, 0, 30), math.rad(90), BLACK)
	limo(model, Vector3.new(16, 0, -30), math.rad(90), BLACK)
	limo(model, Vector3.new(30, 0, 14), 0, Color3.fromRGB(240, 240, 245))
	limo(model, Vector3.new(-30, 0, -12), 0, BLACK)
	for _, p in { Vector3.new(-20, 0.5, -20), Vector3.new(20, 0.5, -20), Vector3.new(-20, 0.5, 20), Vector3.new(20, 0.5, 20), Vector3.new(-TC - 18, 0, 0), Vector3.new(TC + 18, 0, 0), Vector3.new(0, 0, TC + 18), Vector3.new(0, 0, -TC - 18), Vector3.new(-96, 0, -60), Vector3.new(96, 0, 60) } do
		Builder.palm(model, p, 13)
	end

	local spawns = {}
	for _, p in {
		Vector3.new(0, 3, -16), Vector3.new(0, 3, 16), Vector3.new(-16, 3, 0), Vector3.new(16, 3, 0),
		Vector3.new(-96, 3, 0), Vector3.new(96, 3, 0), Vector3.new(0, 3, 96), Vector3.new(0, 3, -96),
		Vector3.new(-96, 3, 96), Vector3.new(96, 3, -96),
		Vector3.new(TC, 3.5, TC - 6), Vector3.new(-TC, 3.5, -TC - 6), -- inside the tower lobbies
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "CasinoRoyale",
		DisplayName = "Casino Royale",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 14,
		FluidColor = Color3.fromRGB(240, 190, 70),
		FluidMaterial = Enum.Material.Foil,
		HazardFloorY = nil,
		FluidName = "LIQUID GOLD",
		Lighting = "Casino",
		KnockbackMultiplier = 1.1,
		Center = Vector3.new(0, 0, 0),
		Radius = 130,
		Walled = true,
	}
end

return CasinoRoyale
