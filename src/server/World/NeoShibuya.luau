--!strict
-- Arena 3: Neo-Shibuya Skyline. Four neon high-rise rooftops over a foggy abyss,
-- linked by fragile glass skybridges. Hologram billboards stand on truss posts at
-- the roof edges; snap their posts and they topple across the gap as makeshift
-- planks. Sudden death floods the lower roofs with rising toxic smog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local TOWER = Color3.fromRGB(52, 46, 74)
local TOWER_TRIM = Color3.fromRGB(78, 70, 104)
local ROOF = Color3.fromRGB(52, 48, 66)
local CYAN = Color3.fromRGB(60, 230, 255)
local PINK = Color3.fromRGB(255, 70, 200)
local PURPLE = Color3.fromRGB(160, 80, 255)
local LIME = Color3.fromRGB(120, 255, 90)
local METAL = Color3.fromRGB(80, 80, 92)
local GLASS = Color3.fromRGB(120, 220, 255)

local HALF = 17 -- tower half-width
local BOTTOM = -40

local NeoShibuya = {}

type Tower = { Center: Vector3, Roof: number }

local TOWERS: { Tower } = {
	{ Center = Vector3.new(-30, 0, -30), Roof = 60 },
	{ Center = Vector3.new(30, 0, -30), Roof = 68 },
	{ Center = Vector3.new(30, 0, 30), Roof = 56 },
	{ Center = Vector3.new(-30, 0, 30), Roof = 48 },
}

local SIGN_WORDS = { "夜市", "東京", "電脳", "神", "嵐", "未来" }

local function tower(model: Model, t: Tower, index: number)
	local c, roof = t.Center, t.Roof
	local body = Instance.new("Folder")
	body.Name = "Tower" .. index
	body.Parent = model
	-- indestructible core
	local height = roof - BOTTOM
	Builder.block(body, "Core", Vector3.new(c.X, BOTTOM + height / 2, c.Z), Vector3.new(HALF * 2, height, HALF * 2), TOWER, Enum.Material.Metal)
	Builder.block(body, "Parapet", Vector3.new(c.X, roof + 0.4, c.Z), Vector3.new(HALF * 2 + 1, 0.8, HALF * 2 + 1), TOWER_TRIM, Enum.Material.Metal)
	-- window bands (decor)
	local color = if index % 2 == 0 then PINK else CYAN
	local y = roof - 6
	while y > BOTTOM + 8 do
		for _, face in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local size = if face.X ~= 0 then Vector3.new(0.3, 1, HALF * 2 - 6) else Vector3.new(HALF * 2 - 6, 1, 0.3)
			Builder.neon(body, Vector3.new(c.X, y, c.Z) + face * (HALF + 0.15), size, color)
		end
		y -= 9
	end
	-- vertical neon kanji sign on the outward face
	local outward = Vector3.new(math.sign(c.X), 0, 0)
	local signPart = Builder.block(body, "VerticalSign", Vector3.new(c.X, roof - 16, c.Z) + outward * (HALF + 1.2) + Vector3.new(0, 0, 6), Vector3.new(1, 18, 5), Color3.fromRGB(25, 20, 40), Enum.Material.SmoothPlastic)
	Builder.sign(signPart, if outward.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left, SIGN_WORDS[index] .. "\n" .. SIGN_WORDS[index + 1], if index % 2 == 0 then CYAN else PINK)
end

local function rooftop(model: Model, t: Tower, index: number)
	local c, roof = t.Center, t.Roof
	local top = roof + 0.8
	-- HVAC units (destructible)
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
	-- water tank on legs (topples toward the tower centre)
	Builder.waterTower(model, Vector3.new(c.X + 9, top, c.Z - 9), 6, Color3.fromRGB(90, 70, 110), Vector3.new(-1, 0, 1))
	local hasPavilion = index == 1 or index == 2
	-- neon helipad (towers without a pavilion)
	if not hasPavilion then
		local pad = Builder.block(model, "Helipad", Vector3.new(c.X - 4, top + 0.1, c.Z + 6), Vector3.new(10, 0.2, 10), Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)
		Builder.sign(pad, Enum.NormalId.Top, "H", LIME)
		for _, e in { Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0), Vector3.new(0, 0, 5), Vector3.new(0, 0, -5) } do
			Builder.neon(model, pad.Position + e + Vector3.new(0, 0.15, 0), if e.X ~= 0 then Vector3.new(0.4, 0.2, 10) else Vector3.new(10, 0.2, 0.4), LIME)
		end
	end
	-- antenna mast
	local mast = Builder.building(model, "Antenna")
	local pole = Builder.block(mast, "Pole", Vector3.new(c.X - 13, top + 9, c.Z - 13), Vector3.new(0.8, 18, 0.8), METAL, Enum.Material.Metal)
	Builder.structural(pole, 1, true, 60)
	local blink = Builder.block(mast, "Beacon", Vector3.new(c.X - 13, top + 18.5, c.Z - 13), Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 40, 60), Enum.Material.Neon)
	Builder.structural(blink, 2, false, 20)
	-- glass rooftop pavilion (2 storeys of glass on columns, high ground + collapse target)
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

-- Billboard on the roof edge facing `toward`, falling across the gap.
local function edgeBillboard(model: Model, t: Tower, toward: Vector3, text: string, color: Color3, lateral: number)
	local dir = Vector3.new(toward.X, 0, toward.Z).Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local base = Vector3.new(t.Center.X, t.Roof + 0.8, t.Center.Z) + dir * (HALF - 3) + right * lateral
	Builder.billboard(model, "HoloBillboard", base, -dir, 12, 22, 4, text, color, Color3.new(1, 1, 1), dir)
end

function NeoShibuya.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "NeoShibuya"
	model.Parent = parent

	for i, t in TOWERS do
		tower(model, t, i)
		rooftop(model, t, i)
	end

	-- skybridges between neighbours (sloped where roof heights differ)
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

	-- billboards that can be toppled into planks across the gaps
	edgeBillboard(model, TOWERS[1], TOWERS[4].Center - TOWERS[1].Center, "NEON\nKOI", PINK, 4)
	edgeBillboard(model, TOWERS[2], TOWERS[1].Center - TOWERS[2].Center, "DISASTER\nTV", PURPLE, 3)
	edgeBillboard(model, TOWERS[3], TOWERS[2].Center - TOWERS[3].Center, "CYBER\nRAMEN", CYAN, -4)
	edgeBillboard(model, TOWERS[2], TOWERS[3].Center - TOWERS[2].Center, "未来", PINK, -5)

	-- distant city silhouettes (decor, outside the play area)
	local rng = Random.new(7)
	for _ = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(110, 170)
		local h = rng:NextNumber(30, 110)
		local w = rng:NextNumber(12, 26)
		local p = Vector3.new(math.cos(angle) * dist, BOTTOM + h / 2, math.sin(angle) * dist)
		local block = Builder.block(model, "Skyline", p, Vector3.new(w, h, w), Color3.fromRGB(28, 24, 42), Enum.Material.SmoothPlastic)
		block.CanCollide = false
		Builder.neon(model, p + Vector3.new(0, h / 2 - 3, w / 2 + 0.1), Vector3.new(w * 0.7, 0.6, 0.2), if rng:NextNumber() > 0.5 then PINK else CYAN)
	end

	local spawns = {}
	for _, t in TOWERS do
		for _, off in { Vector3.new(-6, 0, 0), Vector3.new(6, 0, -2), Vector3.new(0, 0, 10) } do
			table.insert(spawns, CFrame.new(t.Center + off + Vector3.new(0, t.Roof + 4, 0)))
		end
	end

	return {
		Name = "NeoShibuya",
		DisplayName = "Neo-Shibuya Skyline",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -12,
		FluidEndY = 52,
		FluidColor = Color3.fromRGB(150, 70, 210),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "TOXIC SMOG",
		Lighting = "Night",
		KnockbackMultiplier = 1.2,
		Center = Vector3.new(0, 0, 0),
		Radius = 110,
	}
end

return NeoShibuya
