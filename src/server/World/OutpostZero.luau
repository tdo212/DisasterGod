--!strict
-- Arena 5: Outpost Zero. One large fracturing glacier shelf: safety-orange and cobalt
-- research containers on thin steel stilts (snap them and the module drops onto the ice),
-- grated walkways between container roofs, a raised comms-tower plateau and breakable ice
-- slabs along the shelf edge. Ice is slippery: knockback is doubled here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local ICE = Color3.fromRGB(165, 220, 245)
local ICE_DEEP = Color3.fromRGB(95, 175, 225)
local SNOW = Color3.fromRGB(245, 250, 255)
local ORANGE = Color3.fromRGB(240, 120, 30)
local COBALT = Color3.fromRGB(40, 105, 220)
local STEEL = Color3.fromRGB(120, 125, 135)
local RED = Color3.fromRGB(210, 40, 40)
local YELLOW = Color3.fromRGB(250, 200, 40)
local WOOD = Color3.fromRGB(140, 100, 65)

local SHELF_Y = 5
local STILT = 7

local OutpostZero = {}

local function glacier(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model
	-- one continuous glacier shelf covering the whole play area
	Builder.block(ground, "Shelf", Vector3.new(-12, 0, -2), Vector3.new(216, 10, 156), ICE, Enum.Material.Ice)
	Builder.block(ground, "ShelfSkirt", Vector3.new(-12, -2, -2), Vector3.new(222, 6, 162), ICE_DEEP, Enum.Material.Glacier)
	-- pressure ridges for cover
	for _, r in { { Vector3.new(-5, 6.5, 40), Vector3.new(26, 3, 5) }, { Vector3.new(30, 6.5, -45), Vector3.new(6, 3, 22) }, { Vector3.new(-90, 6.5, -50), Vector3.new(18, 3, 5) } } do
		Builder.block(ground, "Ridge", r[1], r[2], ICE_DEEP, Enum.Material.Glacier)
	end
	for _, patch in {
		{ Vector3.new(-60, SHELF_Y + 0.15, -25), Vector3.new(30, 0.3, 22) },
		{ Vector3.new(-25, SHELF_Y + 0.15, 20), Vector3.new(26, 0.3, 18) },
		{ Vector3.new(-70, SHELF_Y + 0.15, 22), Vector3.new(18, 0.3, 14) },
	} do
		Builder.block(ground, "Snow", patch[1], patch[2], SNOW, Enum.Material.Snow)
	end
	-- raised comms plateau on the shelf (top y = 10) with ramps up from the ice
	Builder.cylinder(ground, "Plateau", Vector3.new(58, 7.5, 12), 5, 48, ICE, Enum.Material.Ice)
	Builder.cylinder(ground, "PlateauSnow", Vector3.new(58, 10.15, 12), 0.3, 44, SNOW, Enum.Material.Snow)
	for _, d in { Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) } do
		local rc = Vector3.new(58, 7.5, 12) + d * 30
		Builder.ramp(ground, "PlateauRamp", CFrame.lookAt(rc, rc + d), Vector3.new(10, 5, 14), ICE_DEEP, Enum.Material.Glacier)
	end
	-- decorative icebergs further out
	local rng = Random.new(5)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(110, 150)
		local h = rng:NextNumber(4, 16)
		local berg = Builder.block(ground, "Iceberg", Vector3.new(math.cos(a) * d, h / 2 - 3, math.sin(a) * d), Vector3.new(rng:NextNumber(8, 22), h, rng:NextNumber(8, 22)), ICE, Enum.Material.Ice)
		berg.Transparency = 0.1
	end
end

-- Breakable ice slabs fused to the shelf edge (they snap off into the sea).
local function floes(model: Model)
	for _, p in {
		Vector3.new(-126, 3.5, 30),
		Vector3.new(-126, 3.5, -30),
		Vector3.new(102, 3.5, -40),
		Vector3.new(102, 3.5, 50),
		Vector3.new(-60, 3.5, 82),
		Vector3.new(20, 3.5, 82),
		Vector3.new(-80, 3.5, -86),
		Vector3.new(40, 3.5, -86),
	} do
		local floe = Builder.building(model, "Floe")
		local slab = Builder.block(floe, "Floe", p + Vector3.new(0, -0.5, 0), Vector3.new(12, 4, 10), ICE, Enum.Material.Ice)
		Builder.structural(slab, 1, true, 70)
		local cap = Builder.block(floe, "FloeSnow", p + Vector3.new(0, 1.6, 0), Vector3.new(10, 0.3, 8), SNOW, Enum.Material.Snow)
		Builder.structural(cap, 2, false, 30)
	end
end

local function container(model: Model, center: Vector3, color: Color3, label: string): number
	local c = Builder.building(model, "ResearchModule")
	local length, width, height = 22, 9, 8
	for _, x in { -9, 0, 9 } do
		for _, z in { -3.5, 3.5 } do
			local stilt = Builder.block(c, "Stilt", Vector3.new(center.X + x, SHELF_Y + STILT / 2, center.Z + z), Vector3.new(1.2, STILT, 1.2), STEEL, Enum.Material.Metal)
			Builder.structural(stilt, 1, true, 70)
		end
	end
	local floorY = SHELF_Y + STILT
	local body = Builder.block(c, "Container", Vector3.new(center.X, floorY + height / 2, center.Z), Vector3.new(length, height, width), color, Enum.Material.SmoothPlastic)
	Builder.structural(body, 2, false, 220)
	-- corrugation ribs
	for i = -4, 4 do
		local rib = Builder.block(c, "Rib", Vector3.new(center.X + i * 2.4, floorY + height / 2, center.Z - width / 2 - 0.1), Vector3.new(0.4, height - 0.6, 0.3), color:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Metal)
		Builder.structural(rib, 2, false, 30)
	end
	local door = Builder.block(c, "Door", Vector3.new(center.X + length / 2 + 0.1, floorY + 3.2, center.Z), Vector3.new(0.3, 6, 4), Color3.fromRGB(70, 75, 85), Enum.Material.Metal)
	Builder.structural(door, 2, false, 40)
	local snow = Builder.block(c, "RoofSnow", Vector3.new(center.X, floorY + height + 0.4, center.Z), Vector3.new(length - 0.5, 0.8, width - 0.5), SNOW, Enum.Material.Snow)
	Builder.structural(snow, 2, false, 40)
	local plate = Builder.block(c, "LabelPlate", Vector3.new(center.X, floorY + height - 1.5, center.Z - width / 2 - 0.25), Vector3.new(8, 2, 0.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	Builder.structural(plate, 2, false, 20)
	Builder.sign(plate, Enum.NormalId.Front, label, Color3.fromRGB(30, 30, 40), Color3.new(1, 1, 1))
	return floorY + height + 0.8
end

local function commsTower(model: Model)
	local base = Vector3.new(58, 10.3, 12)
	local tower = Builder.building(model, "CommsTower")
	local top = Builder.latticeTower(model, tower, base, 40, 8, STEEL)
	-- red bracing bands
	for y = 10, 34, 12 do
		for _, z in { -3, 3 } do
			local band = Builder.block(tower, "Brace", base + Vector3.new(0, y, z), Vector3.new(8, 1.2, 1.2), RED, Enum.Material.Metal)
			Builder.structural(band, 1, false, 60)
		end
	end
	local deck = Builder.block(tower, "Deck", Vector3.new(base.X, top + 0.5, base.Z), Vector3.new(11, 1, 11), Color3.fromRGB(90, 95, 105), Enum.Material.DiamondPlate)
	Builder.structural(deck, 2, false)
	local hazard = Builder.block(tower, "HazardBand", Vector3.new(base.X, top + 1.3, base.Z - 5.4), Vector3.new(11, 0.6, 0.3), YELLOW, Enum.Material.SmoothPlastic)
	Builder.structural(hazard, 2, false, 20)
	local dish = Builder.part(tower, {
		Name = "Dish",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = CFrame.new(base.X, top + 9, base.Z) * CFrame.Angles(0, math.rad(-30), math.rad(-35)),
		Color = Color3.fromRGB(235, 240, 245),
		Material = Enum.Material.SmoothPlastic,
	})
	Builder.structural(dish, 2, false, 90)
	local mast = Builder.block(tower, "DishMast", Vector3.new(base.X, top + 4.5, base.Z), Vector3.new(1.2, 8, 1.2), STEEL, Enum.Material.Metal)
	Builder.structural(mast, 2, false, 60)
	Builder.fallDirection(tower, Vector3.new(-1, 0, -0.3))
	-- fence around the island top
	for i = 0, 11 do
		local a = i * math.pi / 6
		local post = Builder.block(model, "FencePost", Vector3.new(58 + math.cos(a) * 21, 11.8, 12 + math.sin(a) * 21), Vector3.new(0.6, 3, 0.6), STEEL, Enum.Material.Metal)
		post.CanCollide = true
	end
end

local function dockArea(model: Model)
	local dock = Builder.building(model, "Dock")
	for i = 0, 3 do
		local z = -84 - i * 7
		for _, x in { 2, 14 } do
			local post = Builder.block(dock, "Post", Vector3.new(x, 0.5, z), Vector3.new(1.2, 9, 1.2), WOOD, Enum.Material.Wood)
			Builder.structural(post, 1, true, 50)
		end
		local deck = Builder.block(dock, "Deck", Vector3.new(8, 4.9, z), Vector3.new(14, 0.8, 7), Color3.fromRGB(165, 120, 80), Enum.Material.WoodPlanks)
		Builder.structural(deck, 2, false, 45)
	end
	Builder.crates(model, Vector3.new(-6, 5.3, -60), 4)
	for _, p in { Vector3.new(20, 5.3, -56), Vector3.new(23, 5.3, -58), Vector3.new(21, 5.3, -62) } do
		local b = Builder.building(model, "FuelBarrel")
		local barrel = Builder.cylinder(b, "Barrel", p + Vector3.new(0, 1.8, 0), 3.6, 2.6, COBALT, Enum.Material.Metal)
		Builder.structural(barrel, 1, true, 40)
		barrel:SetAttribute("Volatile", true)
	end
	-- pipe run + barriers
	for i = 0, 2 do
		local pipe = Builder.part(model, {
			Name = "Pipe",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12, 1.6, 1.6),
			CFrame = CFrame.new(Vector3.new(4 + i * 0.5, 6.3 + i * 1.6, -50)),
			Color = Color3.fromRGB(190, 195, 205),
			Material = Enum.Material.Metal,
		})
		Builder.structural(pipe, 1, true, 80)
	end
	for _, x in { -2, 18 } do
		local barrier = Builder.block(model, "Barrier", Vector3.new(x, 5.7, -74), Vector3.new(5, 1.4, 0.6), YELLOW, Enum.Material.SmoothPlastic)
		Builder.structural(barrier, 1, true, 30)
	end
end

function OutpostZero.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "OutpostZero"
	model.Parent = parent

	glacier(model)
	floes(model)

	local roofs = {
		container(model, Vector3.new(-66, 0, -20), ORANGE, "LAB-01"),
		container(model, Vector3.new(-38, 0, -26), ORANGE, "LAB-02"),
		container(model, Vector3.new(-62, 0, 12), ORANGE, "GEN-03"),
		container(model, Vector3.new(-30, 0, 8), COBALT, "COMMS"),
	}
	local roofY = roofs[1]
	-- grated roof walkways between modules
	local grate = Color3.fromRGB(110, 115, 125)
	Builder.bridge(model, "RoofWalk", Vector3.new(-55, roofY - 0.5, -22), Vector3.new(-49, roofY - 0.5, -24), 4, grate, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)
	Builder.bridge(model, "RoofWalk", Vector3.new(-51, roofY - 0.5, 11), Vector3.new(-41, roofY - 0.5, 9), 4, grate, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)
	Builder.bridge(model, "RoofWalk", Vector3.new(-64, roofY - 0.5, -15), Vector3.new(-63, roofY - 0.5, 7), 4, grate, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)
	Builder.bridge(model, "RoofWalk", Vector3.new(-36, roofY - 0.5, -21), Vector3.new(-32, roofY - 0.5, 3), 4, grate, Enum.Material.DiamondPlate, YELLOW, STEEL, 80)
	-- metal stairs from the ice up to the roofs
	for _, spec in { { Vector3.new(-66, 0, -35.5), Vector3.new(0, 0, -1) }, { Vector3.new(-30, 0, 23.5), Vector3.new(0, 0, 1) } } do
		local foot, outward = spec[1], spec[2]
		local rise = roofY - SHELF_Y
		local rc = foot + Vector3.new(0, SHELF_Y + rise / 2, 0)
		Builder.ramp(model, "Stairs", CFrame.lookAt(rc, rc + outward), Vector3.new(5, rise, rise * 1.4), grate, Enum.Material.DiamondPlate)
	end


	commsTower(model)
	dockArea(model)

	local sign = Builder.block(model, "SignBoard", Vector3.new(-12, SHELF_Y + 5, -38), Vector3.new(20, 5, 0.6), COBALT, Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Front, "OUTPOST ZERO", Color3.new(1, 1, 1))
	Builder.sign(sign, Enum.NormalId.Back, "OUTPOST ZERO", Color3.new(1, 1, 1))
	for _, x in { -20, -4 } do
		Builder.block(model, "SignLeg", Vector3.new(x, SHELF_Y + 1.25, -38), Vector3.new(0.6, 2.5, 0.6), STEEL, Enum.Material.Metal)
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-80, SHELF_Y + 3, -5),
		Vector3.new(-50, SHELF_Y + 3, -5),
		Vector3.new(-15, SHELF_Y + 3, -10),
		Vector3.new(-20, SHELF_Y + 3, 25),
		Vector3.new(-75, SHELF_Y + 3, 30),
		Vector3.new(-66, roofY + 3, -20),
		Vector3.new(-30, roofY + 3, 8),
		Vector3.new(50, 13, 0),
		Vector3.new(66, 13, 22),
		Vector3.new(8, 8, -50),
		Vector3.new(20, 8, -40),
		Vector3.new(-45, SHELF_Y + 3, -35),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "OutpostZero",
		DisplayName = "Outpost Zero",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 9,
		FluidColor = Color3.fromRGB(30, 110, 200),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "FREEZING WATER",
		Lighting = "Arctic",
		KnockbackMultiplier = 2,
		Center = Vector3.new(-10, 0, 0),
		Radius = 120,
	}
end

return OutpostZero
