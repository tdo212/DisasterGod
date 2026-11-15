--!strict
-- Arena 11: Casino Royale. A rain-soaked twilight metropolis; the whole arena is one Art
-- Deco grand casino: velvet red, warm gold and neon purple.
--   * The Grand Atrium: marble floor, red carpet runners and marble columns under a
--     massive glass skylight on steel beams. The God aims straight through the glass;
--     break a beam and its panes rain down on the tables below.
--   * A golden coin fountain in the middle, and a twin grand staircase up to the upper
--     galleries that ring the hall, with velvet lounges, a CASINO ROYALE marquee and three
--     hotel suites you can walk into.
--   * Slot machine lanes, roulette tables, room dividers, a check-in desk, a lounge bar
--     you can climb onto and a reinforced vault with a giant round door.
--   * Three glass arched entrances open onto a rainy plaza with cars and a neon skyline.
-- Sudden death: the fountain overflows with liquid gold. Get up to the galleries.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local MARBLE = Color3.fromRGB(232, 222, 205)
local MARBLE_DARK = Color3.fromRGB(70, 46, 52)
local VELVET = Color3.fromRGB(130, 20, 40)
local CARPET = Color3.fromRGB(110, 18, 34)
local WALL = Color3.fromRGB(78, 24, 40)
local GOLD = Color3.fromRGB(240, 190, 80)
local PURPLE = Color3.fromRGB(170, 70, 255)
local FELT = Color3.fromRGB(20, 110, 60)
local STEEL = Color3.fromRGB(60, 56, 70)
local GLASS = Color3.fromRGB(170, 150, 220)
local ASPHALT = Color3.fromRGB(34, 34, 42)

local HX = 88 -- hall half-width (x)
local Z0, Z1 = -64, 64 -- hall front / back wall
local WALL_H = 44
local GALLERY_Y = 16 -- top of the gallery floor
local GALLERY_W = 16

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
	Builder.block(g, "Foundation", Vector3.new(0, -6, -20), Vector3.new(300, 10, 290), Color3.fromRGB(40, 36, 44), Enum.Material.Concrete)
	Builder.block(g, "MarbleFloor", Vector3.new(0, -0.5, 0), Vector3.new(HX * 2, 1, Z1 - Z0), MARBLE, Enum.Material.Marble)
	-- red carpet runners: entrance to fountain to the grand stair, and across the hall
	Builder.block(g, "Carpet", Vector3.new(0, 0.05, -24), Vector3.new(12, 0.1, 80), CARPET, Enum.Material.Fabric)
	Builder.block(g, "Carpet", Vector3.new(0, 0.05, 12), Vector3.new(120, 0.1, 10), CARPET, Enum.Material.Fabric)
	-- patterned carpet under the gaming floors
	for _, x in { -54, 54 } do
		Builder.block(g, "GamingCarpet", Vector3.new(x, 0.04, -18), Vector3.new(40, 0.08, 76), Color3.fromRGB(70, 14, 40), Enum.Material.Fabric)
	end
	-- the rainy plaza and avenue outside the entrances
	Builder.block(g, "Plaza", Vector3.new(0, -0.5, -86), Vector3.new(220, 1, 44), Color3.fromRGB(90, 86, 96), Enum.Material.Pavement)
	Builder.block(g, "Avenue", Vector3.new(0, -0.6, -134), Vector3.new(300, 1, 52), ASPHALT, Enum.Material.Asphalt)
	for i = -7, 7 do
		Builder.block(g, "LaneMark", Vector3.new(i * 18, -0.05, -134), Vector3.new(8, 0.1, 0.6), Color3.fromRGB(230, 220, 160), Enum.Material.SmoothPlastic)
	end
	-- walkways around the outside of the casino
	for _, x in { -HX - 14, HX + 14 } do
		Builder.block(g, "SideWalk", Vector3.new(x, -0.5, 0), Vector3.new(28, 1, Z1 - Z0 + 4), Color3.fromRGB(90, 86, 96), Enum.Material.Pavement)
	end
	Builder.block(g, "BackWalk", Vector3.new(0, -0.5, Z1 + 14), Vector3.new(HX * 2 + 56, 1, 28), Color3.fromRGB(90, 86, 96), Enum.Material.Pavement)
end

-- the hall shell: destructible wall panels (the supports of the whole shell), gold and
-- neon bands, three glass arched entrances in the front wall
local function shell(model: Model): Model
	local hall = Builder.building(model, "HallShell")
	local function panel(center: Vector3, size: Vector3)
		local p = Builder.block(hall, "Wall", center, size, WALL, Enum.Material.SmoothPlastic)
		Builder.structural(p, 1, true, 420)
	end
	-- panels about 12 wide that exactly tile each wall
	local nx = math.ceil(HX * 2 / 12)
	local seg = HX * 2 / nx
	local nz = math.ceil((Z1 - Z0) / 12)
	local segZ = (Z1 - Z0) / nz
	-- back and side walls
	for i = 0, nx - 1 do
		panel(Vector3.new(-HX + seg * (i + 0.5), WALL_H / 2, Z1 + 0.6), Vector3.new(seg + 0.6, WALL_H, 1.2))
	end
	for _, sx in { -1, 1 } do
		for i = 0, nz - 1 do
			panel(Vector3.new(sx * (HX + 0.6), WALL_H / 2, Z0 + segZ * (i + 0.5)), Vector3.new(1.2, WALL_H, segZ + 0.6))
		end
	end
	-- the front wall with three arched entrances (gaps 14 wide, glass arch above)
	local doors = { -44, 0, 44 }
	for i = 0, nx - 1 do
		local x = -HX + seg * (i + 0.5)
		local inDoor = false
		for _, dx in doors do
			if math.abs(x - dx) < 7 then
				inDoor = true
			end
		end
		if inDoor then
			panel(Vector3.new(x, (WALL_H + 22) / 2, Z0 - 0.6), Vector3.new(seg + 0.6, WALL_H - 22, 1.2))
		else
			panel(Vector3.new(x, WALL_H / 2, Z0 - 0.6), Vector3.new(seg + 0.6, WALL_H, 1.2))
		end
	end
	for _, dx in doors do
		-- glass arch: a fan of panes over the doorway, gold frame
		for i = 0, 4 do
			local a = math.rad(i * 45)
			local p = Vector3.new(dx + math.cos(a) * 6, 16 + math.sin(a) * 5, Z0 - 0.6)
			local pane = Builder.part(hall, { Name = "ArchGlass", Size = Vector3.new(4, 4, 0.4), CFrame = CFrame.new(p) * CFrame.Angles(0, 0, a - math.pi / 2), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.4 })
			Builder.structural(pane, 1, false, 25)
		end
		local lintel = Builder.block(hall, "ArchFrame", Vector3.new(dx, 22, Z0 - 0.6), Vector3.new(seg + 2, 1, 1.6), GOLD, Enum.Material.Metal)
		Builder.structural(lintel, 1, false, 120)
		-- gold door posts
		for _, side in { -1, 1 } do
			local post = Builder.block(hall, "DoorPost", Vector3.new(dx + side * 7, 8, Z0 - 0.6), Vector3.new(1.4, 16, 1.6), GOLD, Enum.Material.Metal)
			Builder.structural(post, 1, true, 200)
		end
	end
	-- gold and neon bands along the inner walls (decor)
	for _, y in { GALLERY_Y - 1, WALL_H - 1 } do
		deco(Builder.neon(model, Vector3.new(0, y, Z1 - 0.2), Vector3.new(HX * 2, 0.6, 0.3), if y > 20 then PURPLE else GOLD))
		deco(Builder.neon(model, Vector3.new(-HX + 0.2, y, 0), Vector3.new(0.3, 0.6, Z1 - Z0), if y > 20 then PURPLE else GOLD))
		deco(Builder.neon(model, Vector3.new(HX - 0.2, y, 0), Vector3.new(0.3, 0.6, Z1 - Z0), if y > 20 then PURPLE else GOLD))
	end
	-- the marquee on the front facade
	local marquee = Builder.block(hall, "Marquee", Vector3.new(0, WALL_H - 6, Z0 - 1.6), Vector3.new(60, 8, 0.8), Color3.fromRGB(30, 12, 30), Enum.Material.SmoothPlastic)
	Builder.structural(marquee, 1, false, 120)
	Builder.sign(marquee, Enum.NormalId.Front, "CASINO ROYALE", GOLD, PURPLE)
	return hall
end

-- the skylight: steel beams (supports) carrying glass panes; the God aims through it
local function skylight(model: Model, hall: Model): Model
	local sky = Builder.building(model, "Skylight")
	Builder.restsOn(sky, hall)
	local nx, nz = 8, 8
	local pw, pd = HX * 2 / nx, (Z1 - Z0) / nz
	for ix = 0, nx do
		local x = -HX + ix * pw
		local beam = Builder.block(sky, "Beam", Vector3.new(x, WALL_H + 0.8, 0), Vector3.new(1.4, 1.6, Z1 - Z0 + 1), STEEL, Enum.Material.Metal)
		Builder.structural(beam, 1, true, 200)
		Builder.canopy(beam)
	end
	for iz = 0, nz do
		local z = Z0 + iz * pd
		local purlin = Builder.block(sky, "Purlin", Vector3.new(0, WALL_H + 0.8, z), Vector3.new(HX * 2 + 1, 1.2, 1), STEEL, Enum.Material.Metal)
		Builder.structural(purlin, 2, false, 90)
		Builder.canopy(purlin)
	end
	for ix = 1, nx do
		for iz = 1, nz do
			local c = Vector3.new(-HX + (ix - 0.5) * pw, WALL_H + 0.9, Z0 + (iz - 0.5) * pd)
			local pane = Builder.part(sky, { Name = "SkylightGlass", Size = Vector3.new(pw - 1.4, 0.4, pd - 1), CFrame = CFrame.new(c), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.6, CastShadow = false })
			Builder.structural(pane, 2, false, 40)
			Builder.canopy(pane)
		end
	end
	-- three chandeliers hang from it (they come down with the glass)
	for _, p in { Vector3.new(0, 0, -18), Vector3.new(-44, 0, -10), Vector3.new(44, 0, -10) } do
		local chain = Builder.block(sky, "Chain", Vector3.new(p.X, WALL_H - 6, p.Z), Vector3.new(0.4, 12, 0.4), GOLD, Enum.Material.Metal)
		deco(chain)
		Builder.structural(chain, 2, false, 15)
		local crown = Builder.part(sky, { Name = "Chandelier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 9, 9), CFrame = CFrame.new(p.X, WALL_H - 12.5, p.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal })
		deco(crown)
		Builder.structural(crown, 2, false, 40)
		local glow = Builder.part(sky, { Name = "Crystals", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), CFrame = CFrame.new(p.X, WALL_H - 15, p.Z), Color = Color3.fromRGB(255, 235, 190), Material = Enum.Material.Neon, Transparency = 0.15 })
		deco(glow)
		Builder.structural(glow, 2, false, 20)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 150)
		light.Range = 40
		light.Brightness = 1.6
		light.Parent = glow
	end
	return sky
end

-- galleries along the back and side walls on marble columns, with velvet lounges, the
-- marquee fascia and three walk-in hotel suites on the back gallery
local function galleries(model: Model, hall: Model): Model
	local gal = Builder.building(model, "Gallery")
	Builder.restsOn(gal, hall)
	local y = GALLERY_Y - 0.75
	local function tile(c: Vector3, size: Vector3)
		local t = Builder.block(gal, "Slab", c, size, MARBLE_DARK, Enum.Material.Marble)
		Builder.structural(t, 2, false, 150)
	end
	local function column(x: number, z: number)
		local col = Builder.cylinder(gal, "MarbleColumn", Vector3.new(x, (GALLERY_Y - 1.5) / 2, z), GALLERY_Y - 1.5, 2.6, MARBLE, Enum.Material.Marble)
		Builder.structural(col, 1, true, 260)
		local cap = Builder.block(gal, "Capital", Vector3.new(x, GALLERY_Y - 2, z), Vector3.new(3.4, 1, 3.4), GOLD, Enum.Material.Metal)
		Builder.structural(cap, 1, false, 40)
	end
	-- back gallery (full width)
	local bz = Z1 - GALLERY_W / 2
	for x = -HX + 8, HX - 7.9, 16 do
		tile(Vector3.new(x, y, bz), Vector3.new(16, 1.5, GALLERY_W))
		if math.abs(x) > 12 then
			column(x, Z1 - GALLERY_W + 1.5)
		end
	end
	-- side galleries
	for _, sx in { -1, 1 } do
		local gx = sx * (HX - GALLERY_W / 2)
		for z = Z0 + 24, Z1 - GALLERY_W - 7.9, 16 do
			tile(Vector3.new(gx, y, z), Vector3.new(GALLERY_W, 1.5, 16))
			column(sx * (HX - GALLERY_W + 1.5), z)
		end
	end
	-- glowing balustrades on the inner edges
	local railY = GALLERY_Y + 1.6
	-- (gaps at x = +-22 where the grand staircase arrives)
	local rails = {
		{ Vector3.new(-57, railY, Z1 - GALLERY_W + 0.4), Vector3.new(62, 0.4, 0.4) },
		{ Vector3.new(0, railY, Z1 - GALLERY_W + 0.4), Vector3.new(36, 0.4, 0.4) },
		{ Vector3.new(57, railY, Z1 - GALLERY_W + 0.4), Vector3.new(62, 0.4, 0.4) },
		{ Vector3.new(-HX + GALLERY_W - 0.4, railY, -4), Vector3.new(0.4, 0.4, 104) },
		{ Vector3.new(HX - GALLERY_W + 0.4, railY, -4), Vector3.new(0.4, 0.4, 104) },
	}
	for _, r in rails do
		local rail = Builder.block(gal, "Balustrade", r[1], r[2], PURPLE, Enum.Material.Neon)
		Builder.structural(rail, 2, false, 20)
		rail.CastShadow = false
		local base = Builder.block(gal, "BalustradeBase", r[1] - Vector3.new(0, 1.2, 0), r[2] + Vector3.new(0, 1.8, 0), GOLD, Enum.Material.Metal)
		Builder.structural(base, 2, false, 40)
	end
	-- the CASINO fascia on the back gallery's front edge
	local fascia = Builder.block(gal, "Fascia", Vector3.new(0, GALLERY_Y - 2.4, Z1 - GALLERY_W - 0.4), Vector3.new(20, 3, 0.6), Color3.fromRGB(30, 10, 30), Enum.Material.SmoothPlastic)
	Builder.structural(fascia, 2, false, 40)
	Builder.sign(fascia, Enum.NormalId.Front, "♠ CASINO ♥", PURPLE, Color3.new(1, 1, 1))
	-- velvet lounges on the side galleries
	for _, sx in { -1, 1 } do
		for _, z in { -24, 20 } do
			local x = sx * (HX - GALLERY_W / 2)
			local seat = Builder.block(gal, "LoungeSeat", Vector3.new(x + sx * 3, GALLERY_Y + 1, z), Vector3.new(3, 2, 10), VELVET, Enum.Material.Fabric)
			Builder.structural(seat, 2, false, 30)
			local back = Builder.block(gal, "LoungeBack", Vector3.new(x + sx * 4.8, GALLERY_Y + 2.6, z), Vector3.new(0.8, 3.2, 10), VELVET, Enum.Material.Fabric)
			Builder.structural(back, 2, false, 30)
			local table_ = Builder.cylinder(gal, "CocktailTable", Vector3.new(x - sx * 2, GALLERY_Y + 1.2, z), 2.4, 3, GOLD, Enum.Material.Metal)
			Builder.structural(table_, 2, false, 25)
		end
	end
	-- three hotel suites on the back gallery (doors face the hall)
	for _, x in { -62, -34, 44 } do
		local suite = Builder.highrise(model, "HotelSuite", Vector3.new(x, GALLERY_Y, Z1 - 7), 20, 13, 1, 10, {
			SlabColor = MARBLE_DARK,
			SlabMaterial = Enum.Material.Marble,
			ColumnColor = GOLD,
			ColumnMaterial = Enum.Material.Metal,
			WallColor = Color3.fromRGB(110, 40, 60),
			WallMaterial = Enum.Material.SmoothPlastic,
			WallTransparency = 0,
		})
		Builder.restsOn(suite, gal)
	end
	return gal
end

-- the twin grand staircase: a central flight to a landing, then two flights curving out
-- to the back gallery
local function grandStair(model: Model, gal: Model)
	local stair = Builder.building(model, "GrandStair")
	Builder.restsOn(stair, gal)
	local landingY = 8
	local landing = Builder.block(stair, "Landing", Vector3.new(0, landingY - 0.75, 36), Vector3.new(20, 1.5, 8), MARBLE, Enum.Material.Marble)
	Builder.structural(landing, 1, false, 200)
	for _, x in { -8, 8 } do
		local pier = Builder.block(stair, "Pier", Vector3.new(x, (landingY - 1.5) / 2, 38), Vector3.new(2, landingY - 1.5, 2), MARBLE, Enum.Material.Marble)
		Builder.structural(pier, 1, true, 260)
	end
	local central = Builder.stairs(stair, Vector3.new(0, 0, 14), Vector3.new(0, landingY, 32), 12, CARPET, Enum.Material.Fabric)
	central.Name = "GrandFlight"
	for _, sx in { -1, 1 } do
		local mid = Vector3.new(sx * 18, landingY + 4, 42)
		local f1 = Builder.stairs(stair, Vector3.new(sx * 10, landingY, 36), mid, 7, CARPET, Enum.Material.Fabric)
		f1.Name = "CurvedFlight"
		local midLanding = Builder.block(stair, "MidLanding", mid - Vector3.new(0, 0.75, 0) + Vector3.new(sx * 2, 0, 1), Vector3.new(8, 1.5, 8), MARBLE, Enum.Material.Marble)
		Builder.structural(midLanding, 1, false, 160)
		local f2 = Builder.stairs(stair, mid + Vector3.new(sx * 2, 0, 4), Vector3.new(sx * 22, GALLERY_Y, Z1 - GALLERY_W + 0.5), 7, CARPET, Enum.Material.Fabric)
		f2.Name = "CurvedFlight"
		-- gold banister along the outer edge
		local a, b = Vector3.new(sx * 13.5, landingY + 3, 36), mid + Vector3.new(sx * 4, 3, 0)
		local rail = Builder.part(stair, { Name = "Banister", Size = Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = GOLD, Material = Enum.Material.Metal })
		deco(rail)
		Builder.structural(rail, 1, false, 15)
	end
end

-- the golden coin fountain: tiered marble basins, water jets, a cascade of gold
local function fountain(model: Model, at: Vector3)
	local f = Builder.building(model, "Fountain")
	local basin = Builder.cylinder(f, "Basin", at + Vector3.new(0, 1, 0), 2, 22, MARBLE, Enum.Material.Marble)
	Builder.structural(basin, 1, true, 260)
	local water = Builder.cylinder(f, "Water", at + Vector3.new(0, 2.05, 0), 0.2, 20, Color3.fromRGB(90, 170, 220), Enum.Material.Glass)
	water.Transparency = 0.3
	deco(water)
	Builder.structural(water, 1, false, 10)
	local tier = Builder.cylinder(f, "Tier", at + Vector3.new(0, 4, 0), 4, 9, MARBLE, Enum.Material.Marble)
	Builder.structural(tier, 1, true, 200)
	local top = Builder.cylinder(f, "TopBowl", at + Vector3.new(0, 7.4, 0), 1.2, 6, GOLD, Enum.Material.Metal)
	Builder.structural(top, 2, false, 80)
	local cascade = Builder.cylinder(f, "GoldCascade", at + Vector3.new(0, 10.5, 0), 6, 2.2, GOLD, Enum.Material.Neon)
	cascade.Transparency = 0.25
	deco(cascade)
	Builder.structural(cascade, 2, false, 10)
	local coins = Instance.new("ParticleEmitter")
	coins.Name = "Coins"
	coins.Color = ColorSequence.new(Color3.fromRGB(255, 215, 90))
	coins.LightEmission = 0.6
	coins.Size = NumberSequence.new(0.35)
	coins.Lifetime = NumberRange.new(1, 1.4)
	coins.Speed = NumberRange.new(4, 7)
	coins.SpreadAngle = Vector2.new(30, 30)
	coins.Acceleration = Vector3.new(0, -14, 0)
	coins.Rate = 18
	coins.Parent = cascade
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local jet = Builder.block(f, "Jet", at + Vector3.new(math.cos(a) * 7, 4.5, math.sin(a) * 7), Vector3.new(0.5, 5, 0.5), Color3.fromRGB(190, 230, 255), Enum.Material.Glass)
		jet.Transparency = 0.4
		deco(jet)
		Builder.structural(jet, 1, false, 5)
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 26
	light.Brightness = 1.8
	light.Parent = cascade
end

local function slotRow(model: Model, x: number, z0: number, count: number, facing: number)
	local row = Builder.building(model, "SlotRow")
	local colors = { PURPLE, Color3.fromRGB(255, 70, 120), Color3.fromRGB(60, 200, 255), GOLD }
	for i = 0, count - 1 do
		local z = z0 + i * 4.6
		local cab = Builder.block(row, "SlotCabinet", Vector3.new(x, 3.2, z), Vector3.new(3, 6.4, 3.8), Color3.fromRGB(40, 30, 50), Enum.Material.Metal)
		Builder.structural(cab, 1, true, 70)
		local screen = Builder.block(row, "SlotScreen", Vector3.new(x + facing * 1.55, 4.2, z), Vector3.new(0.2, 2.6, 3), colors[i % #colors + 1], Enum.Material.Neon)
		Builder.structural(screen, 1, false, 15)
		local topper = Builder.block(row, "SlotTopper", Vector3.new(x, 7, z), Vector3.new(2.8, 1.2, 3.6), GOLD, Enum.Material.Neon)
		Builder.structural(topper, 2, false, 15)
	end
end

local function roulette(model: Model, at: Vector3)
	local t = Builder.building(model, "RouletteTable")
	local leg = Builder.cylinder(t, "Pedestal", at + Vector3.new(0, 1.4, 0), 2.8, 2, GOLD, Enum.Material.Metal)
	Builder.structural(leg, 1, true, 80)
	local top = Builder.block(t, "Felt", at + Vector3.new(0, 3.1, 0), Vector3.new(12, 0.6, 6), FELT, Enum.Material.Fabric)
	Builder.structural(top, 2, false, 40)
	local rim = Builder.block(t, "Rim", at + Vector3.new(0, 3.0, 0), Vector3.new(12.8, 0.5, 6.8), Color3.fromRGB(80, 40, 30), Enum.Material.Wood)
	Builder.structural(rim, 2, false, 40)
	local wheel = Builder.cylinder(t, "Wheel", at + Vector3.new(-4, 3.6, 0), 0.6, 4, Color3.fromRGB(60, 30, 20), Enum.Material.Wood)
	Builder.structural(wheel, 2, false, 25)
	local spinner = Builder.cylinder(t, "WheelGold", at + Vector3.new(-4, 3.95, 0), 0.2, 2.6, GOLD, Enum.Material.Neon)
	Builder.spin(spinner, Vector3.new(0, 0, 2))
	Builder.structural(spinner, 2, false, 10)
	for _, off in { Vector3.new(2, 0, 5), Vector3.new(-2, 0, 5), Vector3.new(4, 0, -5), Vector3.new(-1, 0, -5) } do
		local stool = Builder.cylinder(t, "Stool", at + off + Vector3.new(0, 1.3, 0), 2.6, 1.8, VELVET, Enum.Material.Fabric)
		Builder.structural(stool, 1, false, 20)
	end
end

local function divider(model: Model, at: Vector3, alongX: boolean)
	local d = Builder.building(model, "VelvetDivider")
	local size = if alongX then Vector3.new(10, 6, 0.6) else Vector3.new(0.6, 6, 10)
	local p = Builder.block(d, "Velvet", at + Vector3.new(0, 3.4, 0), size, VELVET, Enum.Material.Fabric)
	Builder.structural(p, 1, true, 40)
	local trim = Builder.block(d, "Trim", at + Vector3.new(0, 6.6, 0), size + Vector3.new(0.2, -5.6, 0.2), GOLD, Enum.Material.Metal)
	Builder.structural(trim, 1, false, 20)
end

-- outside: a porte-cochere over the middle entrance and a neon skyline in the rain
local function exterior(model: Model, hall: Model, rng: Random)
	local canopy = Builder.building(model, "EntranceCanopy")
	Builder.restsOn(canopy, hall)
	local roof = Builder.block(canopy, "CanopyRoof", Vector3.new(0, 14, Z0 - 10), Vector3.new(30, 1.2, 18), Color3.fromRGB(30, 14, 30), Enum.Material.Metal)
	Builder.structural(roof, 2, false, 100)
	local edge = Builder.neon(canopy, Vector3.new(0, 13.2, Z0 - 19), Vector3.new(30, 0.6, 0.4), PURPLE)
	Builder.structural(edge, 2, false, 10)
	for _, x in { -13, 13 } do
		local col = Builder.cylinder(canopy, "CanopyColumn", Vector3.new(x, 6.7, Z0 - 17), 13.4, 1.8, GOLD, Enum.Material.Metal)
		Builder.structural(col, 1, true, 120)
	end
	-- skyline beyond the avenue (decor)
	for _ = 1, 24 do
		local a = rng:NextNumber(math.pi * 0.95, math.pi * 2.05)
		local dist = rng:NextNumber(185, 240)
		local h = rng:NextNumber(50, 140)
		local w = rng:NextNumber(18, 34)
		local p = Vector3.new(math.cos(a) * dist, h / 2 - 2, math.sin(a) * dist)
		deco(Builder.block(model, "Skyline", p, Vector3.new(w, h, w), Color3.fromRGB(24, 20, 36), Enum.Material.SmoothPlastic))
		deco(Builder.neon(model, p + Vector3.new(0, h / 2 - 4, -w / 2 - 0.1), Vector3.new(w * 0.7, 0.8, 0.2), if rng:NextNumber() > 0.5 then PURPLE else Color3.fromRGB(255, 70, 150)))
	end
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi)
		local dist = rng:NextNumber(150, 200)
		local h = rng:NextNumber(40, 90)
		deco(Builder.block(model, "Skyline", Vector3.new(math.cos(a) * dist, h / 2 - 2, math.sin(a) * dist + 30), Vector3.new(26, h, 26), Color3.fromRGB(28, 22, 40), Enum.Material.SmoothPlastic))
	end
	-- street lamps on the plaza
	for _, x in { -80, -40, 40, 80 } do
		local lamp = Builder.building(model, "StreetLamp")
		local pole = Builder.block(lamp, "Pole", Vector3.new(x, 6, -104), Vector3.new(0.6, 12, 0.6), STEEL, Enum.Material.Metal)
		Builder.structural(pole, 1, true, 40)
		local bulb = Builder.block(lamp, "Bulb", Vector3.new(x, 12.4, -104), Vector3.new(1.6, 0.8, 1.6), Color3.fromRGB(255, 200, 150), Enum.Material.Neon)
		Builder.structural(bulb, 2, false, 10)
	end
end

function CasinoRoyale.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "CasinoRoyale"
	model.Parent = parent
	local rng = Random.new(11)

	grounds(model)
	local hall = shell(model)
	skylight(model, hall)
	local gal = galleries(model, hall)
	grandStair(model, gal)
	fountain(model, Vector3.new(0, 0, -18))

	-- the gaming floors either side of the carpet
	for _, spec in { { -68, 1 }, { -58, -1 }, { 58, 1 }, { 68, -1 } } do
		slotRow(model, spec[1], -50, 9, spec[2])
	end
	for _, p in { Vector3.new(-30, 0, -44), Vector3.new(30, 0, -44), Vector3.new(-34, 0, 2), Vector3.new(34, 0, 2), Vector3.new(-20, 0, 26), Vector3.new(20, 0, 26) } do
		roulette(model, p)
	end
	for _, d in { { Vector3.new(-44, 0, -30), false }, { Vector3.new(44, 0, -30), false }, { Vector3.new(-44, 0, 10), false }, { Vector3.new(44, 0, 10), false }, { Vector3.new(-18, 0, -56), true }, { Vector3.new(18, 0, -56), true } } do
		divider(model, d[1] :: Vector3, d[2] :: boolean)
	end

	-- the lounge bar (climb its roof via the ladder) and the reinforced vault
	local bar, barRoof = Builder.highrise(model, "LoungeBar", Vector3.new(-54, 0, 38), 26, 16, 1, 12, {
		SlabColor = Color3.fromRGB(50, 30, 30),
		SlabMaterial = Enum.Material.Wood,
		ColumnColor = GOLD,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(90, 30, 45),
		WallMaterial = Enum.Material.Wood,
		WallTransparency = 0,
		Windows = true,
		OpenSide = "East",
	})
	local counter = Builder.block(bar, "BarCounter", Vector3.new(-54, 1.8, 33), Vector3.new(18, 3.6, 2.4), Color3.fromRGB(60, 30, 25), Enum.Material.Wood)
	Builder.structural(counter, 1, false, 60)
	local shelf = Builder.block(bar, "Bottles", Vector3.new(-54, 6, 45), Vector3.new(16, 3, 1), Color3.fromRGB(120, 220, 200), Enum.Material.Neon)
	shelf.Transparency = 0.3
	Builder.structural(shelf, 1, false, 20)
	local barSign = Builder.block(bar, "BarSign", Vector3.new(-54, barRoof + 2, 30), Vector3.new(12, 3, 0.6), Color3.fromRGB(30, 10, 30), Enum.Material.SmoothPlastic)
	Builder.structural(barSign, 2, false, 30)
	Builder.sign(barSign, Enum.NormalId.Front, "LOUNGE", PURPLE, Color3.new(1, 1, 1))

	local vault = Builder.highrise(model, "Vault", Vector3.new(56, 0, 36), 22, 18, 1, 13, {
		SlabColor = Color3.fromRGB(70, 70, 80),
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = Color3.fromRGB(90, 90, 100),
		ColumnMaterial = Enum.Material.Metal,
		WallColor = Color3.fromRGB(80, 80, 92),
		WallMaterial = Enum.Material.DiamondPlate,
		WallTransparency = 0,
		Health = 520,
	})
	local door = Builder.part(vault, { Name = "VaultDoor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 9, 9), CFrame = CFrame.new(64, 5, 26.4) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(190, 190, 200), Material = Enum.Material.DiamondPlate })
	Builder.structural(door, 1, false, 300)
	local wheel = Builder.part(vault, { Name = "VaultWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3.4, 3.4), CFrame = CFrame.new(64, 5, 25.6) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = Enum.Material.Metal })
	Builder.structural(wheel, 1, false, 40)
	for _, p in { Vector3.new(52, 1, 40), Vector3.new(58, 1, 42) } do
		local gold = Builder.block(vault, "GoldBars", p, Vector3.new(4, 2, 2.4), GOLD, Enum.Material.Neon)
		Builder.structural(gold, 1, false, 30)
	end

	-- the check-in desk by the entrance
	local desk = Builder.building(model, "CheckIn")
	local counter2 = Builder.block(desk, "Desk", Vector3.new(-56, 2, -56), Vector3.new(20, 4, 3), MARBLE, Enum.Material.Marble)
	Builder.structural(counter2, 1, true, 120)
	local top = Builder.block(desk, "DeskTop", Vector3.new(-56, 4.2, -56), Vector3.new(21, 0.4, 3.6), GOLD, Enum.Material.Metal)
	Builder.structural(top, 2, false, 30)
	local sign = Builder.block(desk, "DeskSign", Vector3.new(-56, 8, -57.6), Vector3.new(12, 2.4, 0.4), Color3.fromRGB(30, 10, 30), Enum.Material.SmoothPlastic)
	Builder.structural(sign, 2, false, 20)
	Builder.sign(sign, Enum.NormalId.Front, "CHECK-IN", GOLD, Color3.new(0, 0, 0))

	exterior(model, hall, rng)

	local spawns = {}
	for _, p in {
		Vector3.new(0, 3, -40), Vector3.new(-30, 3, -20), Vector3.new(30, 3, -20), Vector3.new(-62, 3, -10),
		Vector3.new(62, 3, -10), Vector3.new(0, 3, 30), Vector3.new(-50, GALLERY_Y + 3, Z1 - 8), Vector3.new(50, GALLERY_Y + 3, Z1 - 8),
		Vector3.new(-HX + 8, GALLERY_Y + 3, 0), Vector3.new(HX - 8, GALLERY_Y + 3, 0), Vector3.new(-40, 3, -90), Vector3.new(40, 3, -90),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "CasinoRoyale",
		DisplayName = "Casino Royale",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 12,
		FluidColor = Color3.fromRGB(240, 190, 70),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "LIQUID GOLD",
		Lighting = "Casino",
		KnockbackMultiplier = 1.1,
		Center = Vector3.new(0, 0, -10),
		Radius = 125,
	}
end

return CasinoRoyale
