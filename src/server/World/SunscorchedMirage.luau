--!strict
-- Arena 4: Sunscorched Mirage. A sunken desert court inside canyon walls: a stepped
-- pyramid (sturdy high ground) with a golden brazier, top-heavy obelisks that topple
-- outward onto the wooden scaffold ring walkway, two stone aqueducts and quicksand
-- pits that slow and sap survivors. Sudden death: the sand itself rises.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local SAND = Color3.fromRGB(236, 205, 150)
local SAND_DARK = Color3.fromRGB(214, 180, 125)
local STONE = Color3.fromRGB(222, 186, 130)
local STONE_DARK = Color3.fromRGB(196, 158, 105)
local CLIFF = { Color3.fromRGB(226, 190, 135), Color3.fromRGB(205, 165, 112), Color3.fromRGB(232, 200, 150) }
local WOOD = Color3.fromRGB(140, 95, 55)
local GOLD = Color3.fromRGB(255, 200, 60)
local QUICKSAND = Color3.fromRGB(184, 148, 92)
local WATER = Color3.fromRGB(70, 170, 220)

local RING = 82 -- scaffold walkway square half-size
local WALK_Y = 8

local SunscorchedMirage = {}

local function canyon(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model
	Builder.block(ground, "CourtFloor", Vector3.new(0, -2, 0), Vector3.new(200, 4, 200), SAND, Enum.Material.Sand)
	-- layered canyon walls on all four sides
	for layer, spec in { { 100, 12, 26 }, { 111, 12, 38 }, { 123, 14, 50 } } do
		local offset, thick, height = spec[1], spec[2], spec[3]
		for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
			local length = offset * 2 + thick
			local size = if side.X ~= 0 then Vector3.new(thick, height, length) else Vector3.new(length, height, thick)
			local wall = Builder.block(ground, "Cliff", side * offset + Vector3.new(0, height / 2 - 2, 0), size, CLIFF[layer], Enum.Material.Sandstone)
			wall.CastShadow = layer == 1
		end
	end
	-- cliff strata lips
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local size = if side.X ~= 0 then Vector3.new(4, 2, 200) else Vector3.new(200, 2, 4)
		Builder.block(ground, "Strata", side * 95 + Vector3.new(0, 14, 0), size, STONE_DARK, Enum.Material.Sandstone)
	end
end

local function pyramid(model: Model)
	local p = Builder.building(model, "StepPyramid")
	for tier = 1, 5 do
		local half = 22 - (tier - 1) * 4
		local y = (tier - 1) * 5 + 2.5
		-- four quadrant blocks per tier so impacts chip pieces away
		for _, q in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
			local block = Builder.block(p, "Tier" .. tier, Vector3.new(q.X * half / 2, y, q.Z * half / 2), Vector3.new(half, 5, half), if tier % 2 == 0 then STONE else STONE_DARK, Enum.Material.Sandstone)
			Builder.structural(block, tier, true, 420)
		end
		-- stairs on the north and south faces
		for _, s in { -1, 1 } do
			local c = Vector3.new(0, y, s * (half + 2))
			local stair = Builder.ramp(p, "Stairs", CFrame.lookAt(c, c + Vector3.new(0, 0, s)), Vector3.new(8, 5, 4), STONE, Enum.Material.Sandstone)
			Builder.structural(stair, tier, false, 300)
		end
	end
	local apex = Builder.block(p, "Apex", Vector3.new(0, 26, 0), Vector3.new(7, 2, 7), GOLD, Enum.Material.Metal)
	Builder.structural(apex, 6, false, 200)
	local bowl = Builder.cylinder(p, "Brazier", Vector3.new(0, 27.6, 0), 1.4, 5, Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
	Builder.structural(bowl, 6, false, 60)
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 30
	light.Brightness = 2
	light.Parent = bowl
end

local function obelisk(model: Model, base: Vector3)
	local o = Builder.building(model, "Obelisk")
	local plinth = Builder.block(o, "Plinth", base + Vector3.new(0, 2, 0), Vector3.new(7, 4, 7), STONE_DARK, Enum.Material.Sandstone)
	Builder.structural(plinth, 1, true, 150)
	for i = 1, 4 do
		local seg = Builder.block(o, "Shaft", base + Vector3.new(0, 4 + (i - 0.5) * 7, 0), Vector3.new(4.4 - i * 0.3, 7, 4.4 - i * 0.3), STONE, Enum.Material.Sandstone)
		Builder.structural(seg, 2, false, 150)
	end
	local tip = Builder.part(o, {
		Name = "Pyramidion",
		Class = "WedgePart",
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 33.5, 0)),
		Color = GOLD,
		Material = Enum.Material.Metal,
	})
	Builder.structural(tip, 2, false, 100)
	-- topple outward onto the scaffold ring
	Builder.fallDirection(o, Vector3.new(base.X, 0, base.Z))
end

local function aqueduct(model: Model, from: Vector3, to: Vector3)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	local segs = math.floor(length / 24)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local look = CFrame.lookAt(Vector3.zero, dir)
	for i = 1, segs do
		local seg = Builder.building(model, "AqueductSpan")
		local a = from + dir * 24 * (i - 1)
		local mid = a + dir * 12
		for _, d in { 2, 22 } do
			local pillar = Builder.block(seg, "Pillar", a + dir * d + Vector3.new(0, 8, 0), Vector3.new(3.5, 16, 3.5), STONE_DARK, Enum.Material.Sandstone)
			Builder.structural(pillar, 1, true, 170)
		end
		local lintel = Builder.part(seg, {
			Name = "Arch",
			Size = Vector3.new(4, 2.5, 20),
			CFrame = CFrame.new(mid + Vector3.new(0, 13.5, 0)) * look.Rotation,
			Color = STONE,
			Material = Enum.Material.Sandstone,
		})
		Builder.structural(lintel, 2, false, 150)
		local channel = Builder.part(seg, {
			Name = "Channel",
			Size = Vector3.new(7, 1.5, 24),
			CFrame = CFrame.new(mid + Vector3.new(0, 16.75, 0)) * look.Rotation,
			Color = STONE,
			Material = Enum.Material.Sandstone,
		})
		Builder.structural(channel, 2, false, 150)
		for _, side in { -1, 1 } do
			local lip = Builder.part(seg, {
				Name = "Lip",
				Size = Vector3.new(1, 1.4, 24),
				CFrame = CFrame.new(mid + right * side * 3 + Vector3.new(0, 18.2, 0)) * look.Rotation,
				Color = STONE_DARK,
				Material = Enum.Material.Sandstone,
			})
			Builder.structural(lip, 2, false, 90)
		end
		local water = Builder.part(seg, {
			Name = "Water",
			Size = Vector3.new(5, 0.3, 24),
			CFrame = CFrame.new(mid + Vector3.new(0, 17.6, 0)) * look.Rotation,
			Color = WATER,
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			CanCollide = false,
		})
		Builder.structural(water, 2, false, 20)
	end
	-- stair ramp up to the channel at the start
	local rc = from - dir * 13 + Vector3.new(0, 8.75, 0)
	Builder.ramp(model, "AqueductRamp", CFrame.lookAt(rc, rc - dir), Vector3.new(6, 17.5, 26), STONE_DARK, Enum.Material.Sandstone)
end

-- Fragile wooden scaffold ring walkway, in independent spans.
local function scaffoldRing(model: Model)
	local span = 16
	for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local along = Vector3.new(side.Z, 0, side.X)
		local count = math.floor(RING * 2 / span)
		for i = 0, count - 1 do
			local s = Builder.building(model, "Scaffold")
			local start = side * RING + along * (-RING + i * span)
			for _, d in { 0, span } do
				local post = Builder.block(s, "Post", start + along * d + Vector3.new(0, WALK_Y / 2, 0), Vector3.new(1.2, WALK_Y, 1.2), WOOD, Enum.Material.Wood)
				Builder.structural(post, 1, true, 45)
			end
			local deckCenter = start + along * (span / 2) + Vector3.new(0, WALK_Y + 0.4, 0)
			local deck = Builder.block(s, "Planks", deckCenter, if side.X ~= 0 then Vector3.new(6, 0.8, span) else Vector3.new(span, 0.8, 6), Color3.fromRGB(165, 115, 70), Enum.Material.WoodPlanks)
			Builder.structural(deck, 2, false, 45)
			local rail = Builder.block(s, "Rail", deckCenter + side * 2.8 + Vector3.new(0, 1.6, 0), if side.X ~= 0 then Vector3.new(0.4, 0.4, span) else Vector3.new(span, 0.4, 0.4), WOOD, Enum.Material.Wood)
			Builder.structural(rail, 2, false, 20)
		end
	end
	-- ramps from the court up onto the walkway (approach from the inside of the ring)
	for _, c in { Vector3.new(RING - 20, 0, -RING), Vector3.new(-RING + 20, 0, RING), Vector3.new(RING, 0, -62), Vector3.new(-RING, 0, -20) } do
		local inward = if math.abs(c.Z) == RING then Vector3.new(0, 0, -math.sign(c.Z)) else Vector3.new(-math.sign(c.X), 0, 0)
		local rc = c + inward * 11 + Vector3.new(0, WALK_Y / 2, 0)
		Builder.ramp(model, "ScaffoldRamp", CFrame.lookAt(rc, rc + inward), Vector3.new(6, WALK_Y, 16), WOOD, Enum.Material.WoodPlanks)
	end
end

local function quicksand(model: Model, center: Vector3, size: Vector3)
	local pit = Builder.block(model, "Quicksand", center + Vector3.new(0, 0.1, 0), Vector3.new(size.X, 0.2, size.Z), QUICKSAND, Enum.Material.Sand)
	Builder.hazard(pit, Config.Hazards.QuicksandDamagePerSecond, Config.Hazards.QuicksandWalkSpeed)
	-- swirl rings
	for r = 1, 2 do
		local ring = Builder.part(model, {
			Name = "Swirl",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, math.min(size.X, size.Z) * 0.35 * r, math.min(size.X, size.Z) * 0.35 * r),
			CFrame = CFrame.new(center + Vector3.new(0, 0.22 + r * 0.01, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = SAND_DARK,
			Material = Enum.Material.Sand,
			CanCollide = false,
		})
		Builder.hazard(ring, Config.Hazards.QuicksandDamagePerSecond, Config.Hazards.QuicksandWalkSpeed)
	end
end

local function ruins(model: Model)
	local rng = Random.new(11)
	for _, p in { Vector3.new(-40, 0, -62), Vector3.new(44, 0, 62), Vector3.new(-66, 0, 30), Vector3.new(62, 0, -34), Vector3.new(-20, 0, 52) } do
		local col = Builder.building(model, "BrokenColumn")
		local h = rng:NextInteger(2, 4)
		for i = 1, h do
			local seg = Builder.cylinder(col, "Drum", p + Vector3.new(0, (i - 0.5) * 4, 0), 4, 4.5, if i % 2 == 0 then STONE else STONE_DARK, Enum.Material.Sandstone)
			Builder.structural(seg, i, true, 120)
		end
		local fallen = Builder.part(model, {
			Name = "FallenBlock",
			Size = Vector3.new(5, 3, 3),
			CFrame = CFrame.new(p + Vector3.new(5, 1.5, 3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color = STONE_DARK,
			Material = Enum.Material.Sandstone,
		})
		Builder.structural(fallen, 1, true, 120)
	end
end

local function oasis(model: Model)
	for _, q in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local pool = Builder.block(model, "OasisPool", Vector3.new(q.X * 30, 0.05, q.Z * 28), Vector3.new(12, 0.1, 9), WATER, Enum.Material.Glass)
		pool.Transparency = 0.2
		Builder.block(model, "PoolRim", Vector3.new(q.X * 30, 0.15, q.Z * 28 + q.Z * 5), Vector3.new(14, 0.5, 1), STONE_DARK, Enum.Material.Sandstone)
		Builder.palm(model, Vector3.new(q.X * 36, 0, q.Z * 24), 12)
		Builder.palm(model, Vector3.new(q.X * 24, 0, q.Z * 33), 10)
		local bush = Builder.block(model, "Shrub", Vector3.new(q.X * 38, 1, q.Z * 32), Vector3.new(3, 2, 3), Color3.fromRGB(90, 170, 60), Enum.Material.Grass)
		Builder.structural(bush, 1, true, 20)
	end
end

function SunscorchedMirage.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "SunscorchedMirage"
	model.Parent = parent

	canyon(model)
	pyramid(model)
	oasis(model)
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		obelisk(model, Vector3.new(math.cos(a) * 50, 0, math.sin(a) * 50))
	end
	aqueduct(model, Vector3.new(-48, 0, 66), Vector3.new(48, 0, 66))
	aqueduct(model, Vector3.new(66, 0, 48), Vector3.new(66, 0, -48))
	scaffoldRing(model)
	quicksand(model, Vector3.new(-62, 0, -40), Vector3.new(18, 0, 14))
	quicksand(model, Vector3.new(30, 0, -64), Vector3.new(16, 0, 12))
	quicksand(model, Vector3.new(-64, 0, 56), Vector3.new(12, 0, 14))
	quicksand(model, Vector3.new(48, 0, 30), Vector3.new(10, 0, 12))
	ruins(model)

	local sign = Builder.block(model, "SignBoard", Vector3.new(0, 7, -90), Vector3.new(28, 6, 1), STONE_DARK, Enum.Material.Sandstone)
	Builder.sign(sign, Enum.NormalId.Back, "SUNSCORCHED MIRAGE", GOLD, Color3.fromRGB(90, 55, 20))

	local spawns = {}
	for _, p in {
		Vector3.new(0, 3, -40),
		Vector3.new(0, 3, 40),
		Vector3.new(-40, 3, 0),
		Vector3.new(40, 3, 0),
		Vector3.new(-30, 3, -50),
		Vector3.new(50, 3, -55),
		Vector3.new(0, 13, -12),
		Vector3.new(0, 23, 6),
		Vector3.new(0, 21, 66),
		Vector3.new(66, 21, 0),
		Vector3.new(RING, WALK_Y + 3, -20),
		Vector3.new(-RING, WALK_Y + 3, 20),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "SunscorchedMirage",
		DisplayName = "Sunscorched Mirage",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 12,
		FluidColor = Color3.fromRGB(222, 186, 120),
		FluidMaterial = Enum.Material.Sand,
		HazardFloorY = nil,
		FluidName = "SAND",
		Lighting = "Desert",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 95,
	}
end

return SunscorchedMirage
