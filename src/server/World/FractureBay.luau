--!strict
-- Arena 1: Fracture Bay. Two land masses split by a water channel and joined by a
-- suspension bridge. The glass resort stands on exposed pillars (knock them out and
-- the upper floors shear off); the cliff lighthouse is the high ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local SAND = Color3.fromRGB(240, 215, 150)
local GRASS = Color3.fromRGB(110, 205, 75)
local ROCK = Color3.fromRGB(150, 135, 115)
local ROCK_DARK = Color3.fromRGB(115, 102, 90)
local WOOD = Color3.fromRGB(150, 105, 60)
local STEEL = Color3.fromRGB(110, 112, 120)
local RED = Color3.fromRGB(220, 45, 45)
local WHITE = Color3.fromRGB(245, 245, 245)
local YELLOW = Color3.fromRGB(245, 195, 40)

local G = 2 -- sand surface height

local FractureBay = {}

local function terrain(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model

	-- west land mass + east land mass, water channel between x=-5..30
	Builder.block(ground, "WestSand", Vector3.new(-70, 0, 0), Vector3.new(130, 4, 170), SAND, Enum.Material.Sand)
	Builder.block(ground, "WestSandLip", Vector3.new(-80, -0.5, 95), Vector3.new(90, 3, 20), SAND, Enum.Material.Sand)
	Builder.block(ground, "EastSand", Vector3.new(85, 0, 0), Vector3.new(110, 4, 170), SAND, Enum.Material.Sand)
	Builder.block(ground, "EastSandLip", Vector3.new(95, -0.5, -92), Vector3.new(70, 3, 16), SAND, Enum.Material.Sand)
	for _, patch in {
		{ Vector3.new(-110, 2.1, 50), Vector3.new(30, 0.4, 40) },
		{ Vector3.new(-60, 2.1, 70), Vector3.new(40, 0.4, 20) },
		{ Vector3.new(115, 2.1, 60), Vector3.new(36, 0.4, 40) },
	} do
		Builder.block(ground, "Grass", patch[1], patch[2], GRASS, Enum.Material.Grass)
	end

	-- west plateau (bridge anchor) top y=24
	Builder.block(ground, "WestPlateau", Vector3.new(-22, 13, 20), Vector3.new(34, 22, 60), ROCK, Enum.Material.Rock)
	Builder.block(ground, "WestPlateauTop", Vector3.new(-22, 24.2, 20), Vector3.new(34, 0.4, 60), GRASS, Enum.Material.Grass)
	Builder.ramp(
		ground,
		"WestRamp",
		CFrame.lookAt(Vector3.new(-61, 13, 35), Vector3.new(-62, 13, 35)),
		Vector3.new(12, 22, 44),
		ROCK_DARK,
		Enum.Material.Rock
	)

	-- east cliff top y=24, with the lighthouse
	Builder.block(ground, "EastCliff", Vector3.new(75, 13, 25), Vector3.new(60, 22, 70), ROCK, Enum.Material.Rock)
	Builder.block(ground, "EastCliffTop", Vector3.new(75, 24.2, 25), Vector3.new(60, 0.4, 70), GRASS, Enum.Material.Grass)
	Builder.block(ground, "EastCliffStep", Vector3.new(112, 8, 40), Vector3.new(16, 12, 40), ROCK_DARK, Enum.Material.Rock)
	Builder.ramp(
		ground,
		"EastRamp",
		CFrame.lookAt(Vector3.new(90, 13, -32), Vector3.new(90, 13, -33)),
		Vector3.new(12, 22, 44),
		ROCK_DARK,
		Enum.Material.Rock
	)
end

local function resort(model: Model)
	local resortModel, roofY = Builder.highrise(model, "GlassResort", Vector3.new(-85, G, -40), 40, 28, 4, 11, {
		SlabColor = Color3.fromRGB(235, 235, 240),
		SlabMaterial = Enum.Material.Concrete,
		ColumnColor = Color3.fromRGB(190, 190, 195),
		ColumnMaterial = Enum.Material.Concrete,
		WallColor = Color3.fromRGB(140, 215, 255),
		WallMaterial = Enum.Material.Glass,
		WallTransparency = 0.45,
		PillarHeight = 12,
		OpenSide = "East",
	})
	-- roof pool (part of the top level, falls with the roof)
	local pool = Builder.part(resortModel, {
		Name = "Pool",
		Size = Vector3.new(16, 0.6, 10),
		CFrame = CFrame.new(-85, roofY + 0.3, -40),
		Color = Color3.fromRGB(60, 190, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	Builder.structural(pool, 6, false, 30)
	-- entry ramp to the first floor
	Builder.ramp(
		model,
		"ResortRamp",
		CFrame.lookAt(Vector3.new(-85, G + 7, -68), Vector3.new(-85, G + 7, -69)),
		Vector3.new(10, 14, 28),
		Color3.fromRGB(200, 200, 205),
		Enum.Material.Concrete
	)

	-- small beach cafe on the east beach
	Builder.highrise(model, "BayCafe", Vector3.new(110, G, -45), 22, 16, 2, 10, {
		SlabColor = Color3.fromRGB(255, 240, 220),
		SlabMaterial = Enum.Material.WoodPlanks,
		ColumnColor = Color3.fromRGB(255, 120, 90),
		ColumnMaterial = Enum.Material.Brick,
		WallColor = Color3.fromRGB(255, 170, 120),
		WallMaterial = Enum.Material.Brick,
		WallTransparency = 0,
		OpenSide = "West",
	})
end

local function lighthouse(model: Model)
	local lh = Builder.building(model, "Lighthouse")
	local base = Vector3.new(85, 24, 42)
	local segH = 6
	for i = 1, 6 do
		local d = 12 - (i - 1) * 0.5
		local seg = Builder.cylinder(lh, "Tower", base + Vector3.new(0, segH * (i - 0.5), 0), segH, d, if i % 2 == 1 then RED else WHITE, Enum.Material.Concrete)
		Builder.structural(seg, i, true, 120)
	end
	local topY = base.Y + segH * 6
	-- balcony ring
	for _, off in { Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 0, 6), Vector3.new(0, 0, -6) } do
		local deck = Builder.block(lh, "Balcony", base + Vector3.new(0, topY - base.Y + 0.5, 0) + off, Vector3.new(
			if off.X ~= 0 then 4 else 16,
			1,
			if off.Z ~= 0 then 4 else 16
		), STEEL, Enum.Material.Metal)
		Builder.structural(deck, 7, false)
	end
	local lantern = Builder.cylinder(lh, "Lantern", base + Vector3.new(0, topY - base.Y + 4, 0), 6, 8, Color3.fromRGB(255, 250, 200), Enum.Material.Glass)
	lantern.Transparency = 0.3
	Builder.structural(lantern, 7, true, 40)
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 30
	light.Color = Color3.fromRGB(255, 240, 180)
	light.Parent = lantern
	local cap = Builder.part(lh, {
		Name = "Cap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = CFrame.new(base + Vector3.new(0, topY - base.Y + 8, 0)),
		Color = RED,
		Material = Enum.Material.SmoothPlastic,
	})
	Builder.structural(cap, 8, false)
	local ladder = Builder.part(lh, {
		Name = "Ladder",
		Class = "TrussPart",
		Size = Vector3.new(2, topY - base.Y, 2),
		CFrame = CFrame.new(base + Vector3.new(-7, (topY - base.Y) / 2, 0)),
		Color = STEEL,
		Material = Enum.Material.Metal,
	})
	Builder.structural(ladder, 1, false)
end

local function bridge(model: Model)
	local br = Builder.building(model, "SuspensionBridge")
	local y = 24
	local x0, x1 = -5, 45
	for _, x in { x0 + 1, x1 - 1 } do
		for _, z in { 13, 27 } do
			local post = Builder.block(br, "TowerPost", Vector3.new(x, y + 9, z), Vector3.new(2, 18, 2), RED, Enum.Material.Metal)
			Builder.structural(post, 1, true)
		end
		local beam = Builder.block(br, "TowerBeam", Vector3.new(x, y + 18.5, 20), Vector3.new(2, 1.5, 16), RED, Enum.Material.Metal)
		Builder.structural(beam, 2, false)
	end
	local planks = 10
	local len = (x1 - x0) / planks
	for i = 1, planks do
		local plank = Builder.block(br, "Deck", Vector3.new(x0 + len * (i - 0.5), y + 0.5, 20), Vector3.new(len - 0.3, 1, 12), WOOD, Enum.Material.WoodPlanks)
		Builder.structural(plank, 2, false)
	end
	-- sagging cables (decorative, fall with the deck)
	for _, z in { 13.5, 26.5 } do
		local a = Vector3.new(x0 + 1, y + 18, z)
		local mid = Vector3.new((x0 + x1) / 2, y + 4, z)
		local b = Vector3.new(x1 - 1, y + 18, z)
		for _, seg in { { a, mid }, { mid, b } } do
			local p0, p1 = seg[1], seg[2]
			local cable = Builder.part(br, {
				Name = "Cable",
				Size = Vector3.new(0.5, 0.5, (p1 - p0).Magnitude),
				CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
				Color = Color3.fromRGB(40, 40, 45),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			Builder.structural(cable, 2, false, 20)
		end
	end
	-- railings
	for _, z in { 14.3, 25.7 } do
		local rail = Builder.block(br, "Rail", Vector3.new((x0 + x1) / 2, y + 2, z), Vector3.new(x1 - x0, 0.4, 0.4), WHITE, Enum.Material.Metal)
		Builder.structural(rail, 2, false, 30)
	end
end

local function docks(model: Model)
	local dock = Builder.building(model, "Dock")
	for i = 0, 4 do
		local z = -88 - i * 8
		for _, x in { -66, -54 } do
			local post = Builder.block(dock, "Post", Vector3.new(x, -1, z), Vector3.new(1.5, 7, 1.5), WOOD, Enum.Material.Wood)
			Builder.structural(post, 1, true)
		end
		local deck = Builder.block(dock, "Deck", Vector3.new(-60, G + 0.5, z), Vector3.new(14, 1, 8), Color3.fromRGB(175, 125, 75), Enum.Material.WoodPlanks)
		Builder.structural(deck, 2, false)
	end
	local crane = Builder.building(model, "DockCrane")
	local top = Builder.latticeTower(model, crane, Vector3.new(-48, G, -78), 24, 6, YELLOW)
	local boom = Builder.block(crane, "Boom", Vector3.new(-48, top + 1, -90), Vector3.new(2, 2, 26), YELLOW, Enum.Material.Metal)
	Builder.structural(boom, 2, false)
	local cab = Builder.block(crane, "Cab", Vector3.new(-48, top + 2.5, -75), Vector3.new(5, 4, 5), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	Builder.structural(cab, 2, false)
	Builder.crates(model, Vector3.new(-62, G + 1, -104), 4)
	Builder.crates(model, Vector3.new(70, G, -70), 5)
	Builder.crates(model, Vector3.new(-120, G, -60), 3)
end

local function decor(model: Model)
	for _, pos in {
		Vector3.new(-120, G, 20),
		Vector3.new(-100, G, 60),
		Vector3.new(-70, G, 75),
		Vector3.new(-120, G, -20),
		Vector3.new(-40, G, -60),
		Vector3.new(-50, G, 50),
		Vector3.new(55, G, -60),
		Vector3.new(125, G, -10),
		Vector3.new(130, G, 75),
		Vector3.new(60, 24.4, 50),
		Vector3.new(100, 24.4, 10),
		Vector3.new(-30, 24.4, 40),
	} do
		Builder.palm(model, pos, 12 + (pos.X % 5))
	end

	local signPost = Builder.block(model, "SignBoard", Vector3.new(-25, G + 6, -78), Vector3.new(22, 7, 1), Color3.fromRGB(60, 120, 200), Enum.Material.SmoothPlastic)
	Builder.sign(signPost, Enum.NormalId.Front, "FRACTURE BAY", WHITE)
	Builder.sign(signPost, Enum.NormalId.Back, "FRACTURE BAY", WHITE)
	for _, x in { -34, -16 } do
		Builder.block(model, "SignLeg", Vector3.new(x, G + 1.5, -78), Vector3.new(1, 3, 1), WOOD, Enum.Material.Wood)
	end
end

function FractureBay.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "FractureBay"
	model.Parent = parent

	terrain(model)
	resort(model)
	lighthouse(model)
	bridge(model)
	docks(model)
	decor(model)

	local spawns = {}
	for _, p in {
		Vector3.new(-95, G + 3, 20),
		Vector3.new(-60, G + 3, 60),
		Vector3.new(-115, G + 3, -10),
		Vector3.new(-22, 27, 30),
		Vector3.new(-22, 27, 5),
		Vector3.new(70, G + 3, -55),
		Vector3.new(120, G + 3, -20),
		Vector3.new(60, 27, 10),
		Vector3.new(95, 27, 15),
		Vector3.new(-60, G + 4, -96),
		Vector3.new(-70, G + 3, -10),
		Vector3.new(110, G + 3, 70),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "FractureBay",
		DisplayName = "Fracture Bay",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 20,
		FluidColor = Color3.fromRGB(40, 150, 235),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		Center = Vector3.new(0, 0, 0),
		Radius = 160,
	}
end

return FractureBay
