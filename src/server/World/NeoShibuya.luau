--!strict
-- Arena 3: Neo-Shibuya Skyline. A neon city block at night: four high-rises stand on a
-- walkable street grid (no void). Every tower has a long ramp from the street to its
-- roof, and fragile glass skybridges link the rooftops. Hologram billboards on the roof
-- edges topple across the gaps as makeshift planks. Streets have kiosks, cars and vending
-- machines to hide behind. Sudden death: toxic smog floods the streets — get up high.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local TOWER = Color3.fromRGB(52, 46, 74)
local TOWER_TRIM = Color3.fromRGB(78, 70, 104)
local ROOF = Color3.fromRGB(52, 48, 66)
local ASPHALT = Color3.fromRGB(40, 38, 50)
local SIDEWALK = Color3.fromRGB(88, 84, 104)
local CYAN = Color3.fromRGB(60, 230, 255)
local PINK = Color3.fromRGB(255, 70, 200)
local PURPLE = Color3.fromRGB(160, 80, 255)
local LIME = Color3.fromRGB(120, 255, 90)
local METAL = Color3.fromRGB(80, 80, 92)
local GLASS = Color3.fromRGB(120, 220, 255)

local HALF = 17 -- tower half-width
local STREET = 0

local NeoShibuya = {}

type Tower = { Center: Vector3, Roof: number, RampDir: Vector3 }

-- Ramps run outward from each tower's outer face so they don't block the avenues.
local TOWERS: { Tower } = {
	{ Center = Vector3.new(-30, 0, -30), Roof = 30, RampDir = Vector3.new(-1, 0, 0) },
	{ Center = Vector3.new(30, 0, -30), Roof = 38, RampDir = Vector3.new(0, 0, -1) },
	{ Center = Vector3.new(30, 0, 30), Roof = 26, RampDir = Vector3.new(1, 0, 0) },
	{ Center = Vector3.new(-30, 0, 30), Roof = 22, RampDir = Vector3.new(0, 0, 1) },
}

local SIGN_WORDS = { "夜市", "東京", "電脳", "神", "嵐", "未来" }

local function streets(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model
	Builder.block(ground, "Street", Vector3.new(0, STREET - 2, 0), Vector3.new(240, 4, 240), ASPHALT, Enum.Material.Asphalt)
	for _, t in TOWERS do
		Builder.block(ground, "Sidewalk", Vector3.new(t.Center.X, STREET + 0.2, t.Center.Z), Vector3.new(HALF * 2 + 10, 0.4, HALF * 2 + 10), SIDEWALK, Enum.Material.Concrete)
	end
	-- dashed lane markings down the two avenues
	for i = -11, 11 do
		if math.abs(i) <= 1 then
			continue
		end
		Builder.block(ground, "LaneMark", Vector3.new(i * 10, STREET + 0.05, 0), Vector3.new(5, 0.1, 0.6), Color3.fromRGB(230, 230, 200), Enum.Material.SmoothPlastic)
		Builder.block(ground, "LaneMark", Vector3.new(0, STREET + 0.05, i * 10), Vector3.new(0.6, 0.1, 5), Color3.fromRGB(230, 230, 200), Enum.Material.SmoothPlastic)
	end
	-- glowing crosswalk at the central intersection
	for i = -3, 3 do
		Builder.neon(ground, Vector3.new(i * 2.2, STREET + 0.06, 9), Vector3.new(1.2, 0.1, 4), Color3.fromRGB(240, 240, 255))
		Builder.neon(ground, Vector3.new(i * 2.2, STREET + 0.06, -9), Vector3.new(1.2, 0.1, 4), Color3.fromRGB(240, 240, 255))
	end
end

local function tower(model: Model, t: Tower, index: number)
	local c, roof = t.Center, t.Roof
	local body = Instance.new("Folder")
	body.Name = "Tower" .. index
	body.Parent = model
	Builder.block(body, "Core", Vector3.new(c.X, roof / 2, c.Z), Vector3.new(HALF * 2, roof, HALF * 2), TOWER, Enum.Material.Metal)
	Builder.block(body, "Parapet", Vector3.new(c.X, roof + 0.4, c.Z), Vector3.new(HALF * 2 + 1, 0.8, HALF * 2 + 1), TOWER_TRIM, Enum.Material.Metal)
	-- window bands (decor)
	local color = if index % 2 == 0 then PINK else CYAN
	local y = roof - 5
	while y > 4 do
		for _, face in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local size = if face.X ~= 0 then Vector3.new(0.3, 1, HALF * 2 - 6) else Vector3.new(HALF * 2 - 6, 1, 0.3)
			Builder.neon(body, Vector3.new(c.X, y, c.Z) + face * (HALF + 0.15), size, color)
		end
		y -= 7
	end
	-- glowing shop-front entrance on the ground floor
	local inward = Vector3.new(-math.sign(c.X), 0, 0)
	Builder.neon(body, Vector3.new(c.X, 3, c.Z) + inward * (HALF + 0.2), Vector3.new(0.3, 5, 10), LIME)
	-- vertical kanji sign on a face without a ramp
	local signFace = if t.RampDir.X ~= 0 then Vector3.new(0, 0, math.sign(c.Z)) else Vector3.new(math.sign(c.X), 0, 0)
	local signSize = if signFace.X ~= 0 then Vector3.new(1, 14, 5) else Vector3.new(5, 14, 1)
	local signPart = Builder.block(body, "VerticalSign", Vector3.new(c.X, roof - 9, c.Z) + signFace * (HALF + 1.2), signSize, Color3.fromRGB(25, 20, 40), Enum.Material.SmoothPlastic)
	local normal = if signFace.X > 0 then Enum.NormalId.Right elseif signFace.X < 0 then Enum.NormalId.Left elseif signFace.Z > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	Builder.sign(signPart, normal, SIGN_WORDS[index] .. "\n" .. SIGN_WORDS[index + 1], if index % 2 == 0 then CYAN else PINK)
	-- street-to-roof ramp (outer face)
	local d = t.RampDir
	local length = roof * 2
	local rc = Vector3.new(c.X, roof / 2, c.Z) + d * (HALF + length / 2)
	Builder.ramp(model, "RoofRamp", CFrame.lookAt(rc, rc + d), Vector3.new(10, roof, length), Color3.fromRGB(70, 66, 90), Enum.Material.DiamondPlate)
	-- neon edge strips along the ramp
	local right = Vector3.new(-d.Z, 0, d.X)
	for _, side in { -1, 1 } do
		local a = Vector3.new(c.X, roof + 0.3, c.Z) + d * HALF + right * side * 5
		local b = Vector3.new(c.X, 0.3, c.Z) + d * (HALF + length) + right * side * 5
		local strip = Builder.part(model, {
			Name = "RampGlow",
			Size = Vector3.new(0.4, 0.3, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		strip.CastShadow = false
	end
end

local function rooftop(model: Model, t: Tower, index: number)
	local c, roof = t.Center, t.Roof
	local top = roof + 0.8
	for i, off in { Vector3.new(-9, 0, -9), Vector3.new(-2, 0, -10), Vector3.new(9, 0, 8) } do
		local unit = Builder.building(model, "HVAC")
		local box = Builder.block(unit, "Unit", Vector3.new(c.X + off.X, top + 2, c.Z + off.Z), Vector3.new(6, 4, 5), METAL, Enum.Material.Metal)
		Builder.structural(box, 1, true, 120)
		local fan = Builder.cylinder(unit, "Fan", Vector3.new(c.X + off.X, top + 4.2, c.Z + off.Z), 0.4, 4, Color3.fromRGB(30, 30, 36), Enum.Material.Metal)
		Builder.structural(fan, 2, false, 40)
		if i == 3 then
			Builder.neon(unit, Vector3.new(c.X + off.X, top + 0.2, c.Z + off.Z - 2.6), Vector3.new(6, 0.3, 0.3), LIME)
		end
	end
	Builder.waterTower(model, Vector3.new(c.X + 9, top, c.Z - 9), 6, Color3.fromRGB(90, 70, 110), Vector3.new(-1, 0, 1))
	local hasPavilion = index == 1 or index == 2
	if not hasPavilion then
		local pad = Builder.block(model, "Helipad", Vector3.new(c.X - 4, top + 0.1, c.Z + 6), Vector3.new(10, 0.2, 10), Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)
		Builder.sign(pad, Enum.NormalId.Top, "H", LIME)
		for _, e in { Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0), Vector3.new(0, 0, 5), Vector3.new(0, 0, -5) } do
			Builder.neon(model, pad.Position + e + Vector3.new(0, 0.15, 0), if e.X ~= 0 then Vector3.new(0.4, 0.2, 10) else Vector3.new(10, 0.2, 0.4), LIME)
		end
	end
	local mast = Builder.building(model, "Antenna")
	local pole = Builder.block(mast, "Pole", Vector3.new(c.X - 13, top + 9, c.Z - 13), Vector3.new(0.8, 18, 0.8), METAL, Enum.Material.Metal)
	Builder.structural(pole, 1, true, 60)
	local blink = Builder.block(mast, "Beacon", Vector3.new(c.X - 13, top + 18.5, c.Z - 13), Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 40, 60), Enum.Material.Neon)
	Builder.structural(blink, 2, false, 20)
	if hasPavilion then
		Builder.highrise(model, "Pavilion", Vector3.new(c.X - 4, top, c.Z + 6), 14, 10, 1, 9, {
			SlabColor = ROOF,
			SlabMaterial = Enum.Material.Metal,
			ColumnColor = METAL,
			ColumnMaterial = Enum.Material.Metal,
			WallColor = GLASS,
			WallMaterial = Enum.Material.Glass,
			WallTransparency = 0.5,
			OpenSide = "West",
		})
	end
end

local function edgeBillboard(model: Model, t: Tower, toward: Vector3, text: string, color: Color3, lateral: number)
	local dir = Vector3.new(toward.X, 0, toward.Z).Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local base = Vector3.new(t.Center.X, t.Roof + 0.8, t.Center.Z) + dir * (HALF - 3) + right * lateral
	Builder.billboard(model, "HoloBillboard", base, -dir, 12, 22, 4, text, color, Color3.new(1, 1, 1), dir)
end

-- Street-level cover: kiosks, parked cars, vending machines, lamp posts.
local function streetProps(model: Model)
	for i, spec in {
		{ Vector3.new(0, STREET, -62), PINK, "RAMEN" },
		{ Vector3.new(62, STREET, 0), CYAN, "ARCADE" },
		{ Vector3.new(0, STREET, 62), LIME, "SUSHI" },
		{ Vector3.new(-62, STREET, 0), PURPLE, "NOODLE" },
	} do
		local kiosk = Builder.highrise(model, "Kiosk" .. i, spec[1], 10, 8, 1, 7, {
			SlabColor = Color3.fromRGB(60, 56, 78),
			SlabMaterial = Enum.Material.Metal,
			ColumnColor = METAL,
			ColumnMaterial = Enum.Material.Metal,
			WallColor = spec[2]:Lerp(Color3.new(0, 0, 0), 0.4),
			WallMaterial = Enum.Material.SmoothPlastic,
			WallTransparency = 0,
		})
		local sign = Builder.block(kiosk, "KioskSign", spec[1] + Vector3.new(0, 7.6, -4.4), Vector3.new(9, 1.6, 0.4), spec[2], Enum.Material.Neon)
		Builder.structural(sign, 2, false, 20)
		Builder.sign(sign, Enum.NormalId.Front, spec[3], Color3.new(1, 1, 1))
	end
	local carColors = { PINK, CYAN, Color3.fromRGB(255, 200, 60), Color3.fromRGB(240, 240, 250), PURPLE }
	for i, p in {
		Vector3.new(-6, STREET, -80),
		Vector3.new(6, STREET, 40),
		Vector3.new(80, STREET, 6),
		Vector3.new(-45, STREET, -6),
		Vector3.new(40, STREET, -6),
	} do
		local car = Builder.building(model, "Car")
		local alongX = math.abs(p.Z) < 10
		local size = if alongX then Vector3.new(9, 2.4, 4.4) else Vector3.new(4.4, 2.4, 9)
		local body = Builder.block(car, "Body", p + Vector3.new(0, 1.6, 0), size, carColors[i], Enum.Material.SmoothPlastic)
		Builder.structural(body, 1, true, 120)
		local cabin = Builder.block(car, "Cabin", p + Vector3.new(0, 3.4, 0), if alongX then Vector3.new(5, 1.4, 4) else Vector3.new(4, 1.4, 5), Color3.fromRGB(30, 30, 45), Enum.Material.Glass)
		Builder.structural(cabin, 2, false, 25)
	end
	for _, p in { Vector3.new(12, STREET, -50), Vector3.new(-12, STREET, 50), Vector3.new(50, STREET, 12), Vector3.new(-50, STREET, -12) } do
		local vm = Builder.building(model, "VendingMachine")
		local box = Builder.block(vm, "Machine", p + Vector3.new(0, 3, 0), Vector3.new(3, 6, 2.4), Color3.fromRGB(230, 60, 80), Enum.Material.SmoothPlastic)
		Builder.structural(box, 1, true, 70)
		local glow = Builder.block(vm, "Panel", p + Vector3.new(0, 3.6, -1.25), Vector3.new(2.4, 3.6, 0.1), Color3.fromRGB(200, 240, 255), Enum.Material.Neon)
		Builder.structural(glow, 2, false, 15)
	end
	for _, p in { Vector3.new(10, 0, -10), Vector3.new(-10, 0, 10), Vector3.new(10, 0, 10), Vector3.new(-10, 0, -10), Vector3.new(0, 0, -100), Vector3.new(0, 0, 100), Vector3.new(100, 0, 0), Vector3.new(-100, 0, 0) } do
		local lamp = Builder.building(model, "StreetLamp")
		local pole = Builder.block(lamp, "Pole", p + Vector3.new(0, 5, 0), Vector3.new(0.5, 10, 0.5), METAL, Enum.Material.Metal)
		Builder.structural(pole, 1, true, 40)
		local bulb = Builder.block(lamp, "Bulb", p + Vector3.new(0, 10.3, 0), Vector3.new(1.4, 0.6, 1.4), Color3.fromRGB(255, 200, 255), Enum.Material.Neon)
		Builder.structural(bulb, 2, false, 10)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 240)
		light.Range = 20
		light.Brightness = 1.5
		light.Parent = bulb
	end
end

-- Neon shophouses on the outer streets: destructible, unlike the four solid towers.
local function district(model: Model)
	for i, spec in {
		{ Vector3.new(-72, STREET, 36), PINK, "West" },
		{ Vector3.new(36, STREET, 78), CYAN, "East" },
		{ Vector3.new(72, STREET, -36), LIME, "West" },
		{ Vector3.new(-42, STREET, -78), PURPLE, "East" },
	} do
		local house, roofY = Builder.highrise(model, "Shophouse" .. i, spec[1], 24, 20, 4, 10, {
			SlabColor = ROOF,
			SlabMaterial = Enum.Material.Metal,
			ColumnColor = METAL,
			ColumnMaterial = Enum.Material.Metal,
			WallColor = spec[2]:Lerp(Color3.new(0, 0, 0), 0.55),
			WallMaterial = Enum.Material.Glass,
			WallTransparency = 0.25,
			OpenSide = spec[3],
		})
		-- neon trim along the front roof edge (falls with the roof)
		local trim = Builder.neon(house, Vector3.new(spec[1].X, roofY + 0.3, spec[1].Z - 10), Vector3.new(24, 0.6, 0.6), spec[2])
		Builder.structural(trim, 5, false, 30)
	end
end

function NeoShibuya.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "NeoShibuya"
	model.Parent = parent

	streets(model)
	district(model)
	for i, t in TOWERS do
		tower(model, t, i)
		rooftop(model, t, i)
	end

	-- skybridges between neighbouring rooftops (sloped where heights differ)
	local links = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 } }
	for i, link in links do
		local a, b = TOWERS[link[1]], TOWERS[link[2]]
		local dir = (b.Center - a.Center).Unit
		local pa = Vector3.new(a.Center.X, a.Roof + 0.3, a.Center.Z) + dir * (HALF - 1)
		local pb = Vector3.new(b.Center.X, b.Roof + 0.3, b.Center.Z) - dir * (HALF - 1)
		local lateral = if i % 2 == 0 then 6 else -6
		local right = Vector3.new(-dir.Z, 0, dir.X)
		Builder.bridge(model, "GlassSkybridge", pa + right * lateral, pb + right * lateral, 7, GLASS, Enum.Material.Glass, if i % 2 == 0 then PINK else CYAN, METAL, 45)
	end

	edgeBillboard(model, TOWERS[1], TOWERS[4].Center - TOWERS[1].Center, "NEON\nKOI", PINK, 4)
	edgeBillboard(model, TOWERS[2], TOWERS[1].Center - TOWERS[2].Center, "DISASTER\nTV", PURPLE, 3)
	edgeBillboard(model, TOWERS[3], TOWERS[2].Center - TOWERS[3].Center, "CYBER\nRAMEN", CYAN, -4)
	edgeBillboard(model, TOWERS[2], TOWERS[3].Center - TOWERS[2].Center, "未来", PINK, -5)

	streetProps(model)

	-- distant skyline (decor, beyond the street)
	local rng = Random.new(7)
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(135, 180)
		local h = rng:NextNumber(30, 90)
		local w = rng:NextNumber(12, 26)
		local p = Vector3.new(math.cos(angle) * dist, h / 2 - 2, math.sin(angle) * dist)
		local block = Builder.block(model, "Skyline", p, Vector3.new(w, h, w), Color3.fromRGB(28, 24, 42), Enum.Material.SmoothPlastic)
		block.CanCollide = false
		Builder.neon(model, p + Vector3.new(0, h / 2 - 3, w / 2 + 0.1), Vector3.new(w * 0.7, 0.6, 0.2), if rng:NextNumber() > 0.5 then PINK else CYAN)
	end

	local spawns = {}
	for _, t in TOWERS do
		table.insert(spawns, CFrame.new(t.Center + Vector3.new(-6, t.Roof + 4, 0)))
		table.insert(spawns, CFrame.new(t.Center + Vector3.new(0, t.Roof + 4, 10)))
	end
	for _, p in { Vector3.new(0, 3, 0), Vector3.new(0, 3, -40), Vector3.new(40, 3, 0), Vector3.new(0, 3, 40) } do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "NeoShibuya",
		DisplayName = "Neo-Shibuya Skyline",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 16,
		FluidColor = Color3.fromRGB(150, 70, 210),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "TOXIC SMOG",
		Lighting = "Night",
		KnockbackMultiplier = 1.2,
		Center = Vector3.new(0, 0, 0),
		Radius = 120,
	}
end

return NeoShibuya
