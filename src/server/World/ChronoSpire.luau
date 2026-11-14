--!strict
-- Arena 7: Chrono-Spire Citadel. A steampunk foundry town on two cliff plateaus split by a
-- molten-brass channel, under a golden sunset haze.
--   * West plateau: the five-storey Clocktower (open east face, ladder shaft inside,
--     spinning gear faces), two brick works and a row of workshops.
--   * East plateau: four brick foundries around the big Central Works, smokestacks,
--     steel catwalks between the roofs and pressurised boilers that chain-explode.
--   * Iron bridges cross the channel; a long sky-bridge runs from the Clocktower's fourth
--     floor to the Central Works roof.
--   * Set-piece: a dirigible moored over the Works by four steel tethers. Snap two and it
--     dives nose-first through the factory roof.
--   * Steam vents launch survivors up to the catwalks and upper floors.
-- Sudden death: molten brass floods up the channel and over the plateaus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local BRICK = Color3.fromRGB(150, 72, 52)
local BRICK_DARK = Color3.fromRGB(112, 54, 42)
local COPPER = Color3.fromRGB(190, 112, 62)
local BRASS = Color3.fromRGB(212, 168, 80)
local IRON = Color3.fromRGB(62, 60, 66)
local ROOF = Color3.fromRGB(58, 58, 68)
local ROCK = Color3.fromRGB(96, 84, 78)
local COBBLE = Color3.fromRGB(122, 110, 98)
local CREAM = Color3.fromRGB(236, 226, 196)
local WOOD = Color3.fromRGB(122, 86, 56)
local CANVAS = Color3.fromRGB(226, 212, 176)
local WINDOW = Color3.fromRGB(255, 196, 110)

local WEST_TOP = 0
local EAST_TOP = 8

local ChronoSpire = {}

local function brickStyle(openSide: string?): Builder.HighriseStyle
	return {
		SlabColor = ROOF,
		SlabMaterial = Enum.Material.Slate,
		ColumnColor = IRON,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = BRICK,
		WallMaterial = Enum.Material.Brick,
		WallTransparency = 0,
		OpenSide = openSide,
		Stairwell = true,
		Windows = true,
	}
end

local function smoke(part: BasePart, color: Color3, rate: number, speed: number?)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, part.Size.Y / 2, 0)
	attachment.Parent = part
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/smoke_main.dds"
	p.Color = ColorSequence.new(color)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(3, 5)
	p.Rate = rate
	p.Speed = NumberRange.new(speed or 6, (speed or 6) + 3)
	p.SpreadAngle = Vector2.new(12, 12)
	p.Acceleration = Vector3.new(2, 1, 0)
	p.LightInfluence = 1
	p.Parent = attachment
end

-- A disc facing `normal` (cylinder turned so its round face looks along normal).
local function disc(parent: Instance, name: string, center: Vector3, normal: Vector3, diameter: number, thickness: number, color: Color3, material: Enum.Material): BasePart
	return Builder.part(parent, {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.lookAt(center, center + normal) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = material,
	})
end

-- A gear on a wall: brass rim, hub and two spoke bars that the client spins.
local function gear(parent: Instance, center: Vector3, normal: Vector3, diameter: number, rate: number, level: number)
	local rim = disc(parent, "GearRim", center, normal, diameter, 0.8, BRASS, Enum.Material.Metal)
	rim.CanCollide = false
	Builder.structural(rim, level, false, 80)
	local hub = disc(parent, "GearHub", center + normal * 0.5, normal, diameter * 0.25, 1, COPPER, Enum.Material.Metal)
	hub.CanCollide = false
	Builder.structural(hub, level, false, 60)
	for i = 0, 1 do
		local bar = Builder.part(parent, {
			Name = "GearSpoke",
			Size = Vector3.new(diameter * 0.12, diameter * 0.92, 0.5),
			CFrame = CFrame.lookAt(center + normal * 0.45, center + normal * 2) * CFrame.Angles(0, 0, math.rad(i * 90)),
			Color = Color3.fromRGB(150, 110, 50),
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
		Builder.spin(bar, Vector3.new(0, 0, rate))
		Builder.structural(bar, level, false, 30)
	end
end

local function plateaus(model: Model)
	local ground = Instance.new("Folder")
	ground.Name = "Ground"
	ground.Parent = model
	-- west and east cliffs; the molten channel between them (x -12..12)
	Builder.block(ground, "Cliff", Vector3.new(-86, WEST_TOP - 24, 0), Vector3.new(148, 48, 270), ROCK, Enum.Material.Slate)
	Builder.block(ground, "Cobbles", Vector3.new(-86, WEST_TOP - 0.5, 0), Vector3.new(148, 1, 270), COBBLE, Enum.Material.Cobblestone)
	Builder.block(ground, "Cliff", Vector3.new(86, EAST_TOP - 28, 0), Vector3.new(148, 56, 270), ROCK, Enum.Material.Slate)
	Builder.block(ground, "Cobbles", Vector3.new(86, EAST_TOP - 0.5, 0), Vector3.new(148, 1, 270), COBBLE, Enum.Material.Cobblestone)
	-- rough cliff faces and outcrops along the channel
	local rng = Random.new(11)
	for i = 1, 18 do
		local z = -125 + i * 14
		for _, side in { -1, 1 } do
			local top = if side < 0 then WEST_TOP else EAST_TOP
			local h = rng:NextNumber(10, 24)
			local rock = Builder.block(ground, "Outcrop", Vector3.new(side * rng:NextNumber(13, 15), top - h / 2 - rng:NextNumber(2, 8), z), Vector3.new(4, h, rng:NextNumber(8, 13)), ROCK:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25)), Enum.Material.Slate)
			rock.CanCollide = false
		end
	end
	-- copper pipes down the cliff faces into the channel
	for _, z in { -70, -10, 55, 110 } do
		for _, side in { -1, 1 } do
			local top = if side < 0 then WEST_TOP else EAST_TOP
			local pipe = Builder.cylinder(ground, "Pipe", Vector3.new(side * 13, top - 14, z), 28, 2.4, COPPER, Enum.Material.Metal)
			pipe.CanCollide = false
			Builder.cylinder(ground, "PipeFlange", Vector3.new(side * 13, top - 1, z), 1, 3.4, BRASS, Enum.Material.Metal).CanCollide = false
		end
	end
	-- low brick parapets on the channel edges (gaps for the bridges)
	for _, side in { -1, 1 } do
		local top = if side < 0 then WEST_TOP else EAST_TOP
		local z = -130
		while z < 130 do
			local nearBridge = math.abs(z + 100) < 8 or math.abs(z + 40) < 7 or math.abs(z - 40) < 7
			if not nearBridge then
				local wall = Builder.building(model, "Parapet")
				local seg = Builder.block(wall, "Parapet", Vector3.new(side * 13, top + 1.5, z + 5), Vector3.new(1.4, 3, 10), BRICK_DARK, Enum.Material.Brick)
				Builder.structural(seg, 1, true, 90)
			end
			z += 10
		end
	end
end

-- A brick works: floors with a ladder shaft and windows, sawtooth roof, smokestacks.
local function works(model: Model, name: string, base: Vector3, w: number, d: number, floors: number, openSide: string?, stacks: number, stacksSouth: boolean?): (Model, number)
	local house, roofY = Builder.highrise(model, name, base, w, d, floors, 12, brickStyle(openSide))
	local roofLevel = floors + 2
	-- sawtooth skylights (glass, fall with the roof)
	local teeth = math.max(1, math.floor(w / 10))
	for i = 1, teeth do
		local x = base.X - w / 2 + (i - 0.5) * (w / teeth)
		local tooth = Builder.ramp(house, "Sawtooth", CFrame.new(x, roofY + 2, base.Z) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(d * 0.6, 4, w / teeth - 1), ROOF, Enum.Material.Slate)
		Builder.structural(tooth, roofLevel, false, 60)
	end
	-- warm lit windows on the outer faces (decor, fall with the floors)
	for f = 2, floors do
		local y = base.Y + (f - 1) * 12 + 5
		local glow = Builder.block(house, "WindowGlow", Vector3.new(base.X, y, base.Z - d / 2 - 0.1), Vector3.new(w * 0.7, 2, 0.2), WINDOW, Enum.Material.SmoothPlastic)
		glow.CanCollide = false
		Builder.structural(glow, f, false, 15)
	end
	-- smokestacks beside the building: each is its own building and topples outward
	for i = 1, stacks do
		local side = if i % 2 == 1 then -1 else 1
		local back = if stacksSouth then -1 else 1
		local p = Vector3.new(base.X + side * (w / 2 - 4), base.Y, base.Z + back * (d / 2 + 4))
		local stack = Builder.building(model, "Smokestack")
		local h = roofY - base.Y + 22
		local body = Builder.cylinder(stack, "Stack", p + Vector3.new(0, h / 2, 0), h, 6, BRICK_DARK, Enum.Material.Brick)
		Builder.structural(body, 1, true, 260)
		local lip = Builder.cylinder(stack, "StackLip", p + Vector3.new(0, h + 0.5, 0), 1.4, 7.4, IRON, Enum.Material.Metal)
		Builder.structural(lip, 2, false, 40)
		for b = 1, 3 do
			local band = Builder.cylinder(stack, "StackBand", p + Vector3.new(0, h * b / 4, 0), 0.8, 6.6, COPPER, Enum.Material.Metal)
			Builder.structural(band, 2, false, 30)
		end
		smoke(lip, Color3.fromRGB(70, 66, 64), 4)
		Builder.fallDirection(stack, Vector3.new(side, 0, if stacksSouth then -1 else 1))
	end
	return house, roofY
end

-- Pressurised boiler: a volatile tank that bursts and sets off the ones near it.
local function boiler(model: Model, p: Vector3)
	local unit = Builder.building(model, "Boiler")
	local tank = Builder.cylinder(unit, "BoilerTank", p + Vector3.new(0, 3.5, 0), 7, 5, COPPER, Enum.Material.Metal)
	Builder.structural(tank, 1, true, 70)
	tank:SetAttribute("Volatile", true)
	local gauge = disc(unit, "Gauge", p + Vector3.new(0, 5, -2.6), Vector3.new(0, 0, -1), 1.6, 0.3, CREAM, Enum.Material.SmoothPlastic)
	Builder.structural(gauge, 2, false, 10)
	local valve = Builder.cylinder(unit, "Valve", p + Vector3.new(0, 7.4, 0), 1, 2, BRASS, Enum.Material.Metal)
	Builder.structural(valve, 2, false, 15)
	smoke(valve, Color3.fromRGB(235, 235, 235), 2, 3)
end

local function steamVent(model: Model, p: Vector3)
	local vent = Builder.block(model, "SteamVent", p + Vector3.new(0, 0.3, 0), Vector3.new(6, 0.6, 6), IRON, Enum.Material.DiamondPlate)
	Builder.launchPad(vent, 92)
	local ring = Builder.cylinder(model, "VentRing", p + Vector3.new(0, 0.7, 0), 0.4, 6.8, BRASS, Enum.Material.Metal)
	ring.CanCollide = false
	smoke(vent, Color3.fromRGB(240, 240, 240), 10, 14)
end

local function clocktower(model: Model): number
	local base = Vector3.new(-62, WEST_TOP, -20)
	local tower, roofY = Builder.highrise(model, "Clocktower", base, 26, 26, 5, 11, {
		SlabColor = ROOF,
		SlabMaterial = Enum.Material.Slate,
		ColumnColor = IRON,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = BRICK,
		WallMaterial = Enum.Material.Brick,
		WallTransparency = 0,
		OpenSide = "East",
		Stairwell = true,
		Windows = true,
	})
	-- clock room: four corner piers and a clock face on every side
	local headLevel = 7
	local headTop = roofY + 16
	for _, c in { Vector3.new(-11, 0, -11), Vector3.new(11, 0, -11), Vector3.new(-11, 0, 11), Vector3.new(11, 0, 11) } do
		local pier = Builder.block(tower, "ClockPier", Vector3.new(base.X + c.X, roofY + 8, base.Z + c.Z), Vector3.new(4, 16, 4), BRICK_DARK, Enum.Material.Brick)
		Builder.structural(pier, headLevel, true, 160)
	end
	for _, n in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local center = Vector3.new(base.X, roofY + 8, base.Z) + n * 12.6
		local face = disc(tower, "ClockFace", center, n, 15, 0.8, CREAM, Enum.Material.SmoothPlastic)
		Builder.structural(face, headLevel + 1, false, 50)
		local frame = disc(tower, "ClockFrame", center - n * 0.3, n, 17, 0.8, BRASS, Enum.Material.Metal)
		Builder.structural(frame, headLevel + 1, false, 60)
		for i = 0, 11 do
			local a = i * math.pi / 6
			local mark = Builder.part(tower, {
				Name = "HourMark",
				Size = Vector3.new(0.6, 1.4, 0.3),
				CFrame = CFrame.lookAt(center, center + n) * CFrame.new(math.cos(a) * 6.2, math.sin(a) * 6.2, -0.5) * CFrame.Angles(0, 0, a + math.pi / 2),
				Color = IRON,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CastShadow = false,
			})
			Builder.structural(mark, headLevel + 1, false, 10)
		end
		-- the hands sweep (client spin): a long and a short bar
		for h, len in { 6, 4.2 } do
			local hand = Builder.part(tower, {
				Name = "ClockHand",
				Size = Vector3.new(0.6, len * 2, 0.3),
				CFrame = CFrame.lookAt(center + n * 0.7, center + n * 2),
				Color = Color3.fromRGB(40, 36, 34),
				Material = Enum.Material.Metal,
				CastShadow = false,
			})
			Builder.spin(hand, Vector3.new(0, 0, if h == 1 then -0.35 else -0.06))
			Builder.structural(hand, headLevel + 1, false, 10)
		end
	end
	local cap = Builder.block(tower, "ClockRoof", Vector3.new(base.X, headTop + 0.75, base.Z), Vector3.new(28, 1.5, 28), ROOF, Enum.Material.Slate)
	Builder.structural(cap, headLevel + 1, false)
	-- stepped spire with a brass finial
	for i, size in { 22, 16, 10, 5 } do
		local tier = Builder.block(tower, "Spire", Vector3.new(base.X, headTop + 1.5 + (i - 0.5) * 5, base.Z), Vector3.new(size, 5, size), if i % 2 == 0 then ROOF else Color3.fromRGB(48, 70, 70), Enum.Material.Slate)
		Builder.structural(tier, headLevel + 1 + i, false, 90)
	end
	local finial = Builder.block(tower, "Finial", Vector3.new(base.X, headTop + 24.5, base.Z), Vector3.new(1.2, 6, 1.2), BRASS, Enum.Material.Metal)
	Builder.structural(finial, headLevel + 6, false, 20)
	-- huge gears on the tower's lower faces
	gear(tower, Vector3.new(base.X, 20, base.Z - 13.6), Vector3.new(0, 0, -1), 16, 0.5, 2)
	gear(tower, Vector3.new(base.X - 13.6, 26, base.Z + 4), Vector3.new(-1, 0, 0), 12, -0.8, 3)
	gear(tower, Vector3.new(base.X - 13.6, 14, base.Z - 6), Vector3.new(-1, 0, 0), 9, 1.1, 2)
	return roofY
end

-- The moored dirigible: four tethers (supports) hold a hull that dives into the Works.
local function airship(model: Model)
	local ship = Builder.building(model, "Dirigible")
	local c = Vector3.new(70, 80, 30) -- hovering over the Central Works' north half
	local along = CFrame.new(c) * CFrame.Angles(0, math.rad(90), 0) -- cylinder axis along Z
	local hull = Builder.part(ship, { Name = "Envelope", Shape = Enum.PartType.Cylinder, Size = Vector3.new(44, 20, 20), CFrame = along, Color = CANVAS, Material = Enum.Material.Fabric })
	Builder.structural(hull, 2, false, 220)
	for _, z in { -22, 22 } do
		local tip = Builder.part(ship, { Name = "EnvelopeTip", Shape = Enum.PartType.Ball, Size = Vector3.new(20, 20, 20), CFrame = CFrame.new(c + Vector3.new(0, 0, z)), Color = CANVAS, Material = Enum.Material.Fabric })
		Builder.structural(tip, 2, false, 120)
	end
	for i = -2, 2 do
		local rib = Builder.part(ship, { Name = "Rib", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 20.6, 20.6), CFrame = CFrame.new(c + Vector3.new(0, 0, i * 9)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood })
		Builder.structural(rib, 2, false, 40)
	end
	-- tail fins
	for _, f in { Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0) } do
		local size = if f.Y ~= 0 then Vector3.new(0.8, 9, 10) else Vector3.new(9, 0.8, 10)
		local fin = Builder.block(ship, "Fin", c + Vector3.new(0, 0, 30) + f * 10, size, Color3.fromRGB(150, 60, 45), Enum.Material.Fabric)
		Builder.structural(fin, 2, false, 40)
	end
	-- gondola with a rail and two propellers
	local g = c + Vector3.new(0, -13, 0)
	local cabin = Builder.block(ship, "Gondola", g, Vector3.new(9, 5, 24), WOOD, Enum.Material.WoodPlanks)
	Builder.structural(cabin, 2, false, 120)
	local windows = Builder.block(ship, "GondolaWindows", g + Vector3.new(0, 0.8, 0), Vector3.new(9.2, 1.4, 20), WINDOW, Enum.Material.SmoothPlastic)
	Builder.structural(windows, 2, false, 20)
	for _, s in { -1, 1 } do
		local strut = Builder.block(ship, "Strut", c + Vector3.new(s * 3, -9.5, 0), Vector3.new(0.6, 4, 18), IRON, Enum.Material.Metal)
		Builder.structural(strut, 2, false, 40)
		local prop = Builder.part(ship, {
			Name = "Propeller",
			Size = Vector3.new(0.6, 6, 0.4),
			CFrame = CFrame.lookAt(g + Vector3.new(s * 6.5, 0, 10), g + Vector3.new(s * 6.5, 0, 20)),
			Color = Color3.fromRGB(90, 70, 50),
			Material = Enum.Material.Wood,
		})
		Builder.spin(prop, Vector3.new(0, 0, 6 * s))
		Builder.structural(prop, 2, false, 20)
	end
	-- tethers from hull to ground bollards on the east plateau
	local hooks = { Vector3.new(-8, -6, -16), Vector3.new(8, -6, -16), Vector3.new(-8, -6, 16), Vector3.new(8, -6, 16) }
	local anchors = { Vector3.new(40, EAST_TOP, 12), Vector3.new(100, EAST_TOP, 12), Vector3.new(40, EAST_TOP, 50), Vector3.new(100, EAST_TOP, 50) }
	for i, hook in hooks do
		local a = anchors[i] + Vector3.new(0, 2.5, 0)
		local b = c + hook
		Builder.block(model, "Bollard", anchors[i] + Vector3.new(0, 1.2, 0), Vector3.new(2.6, 2.4, 2.6), IRON, Enum.Material.Metal)
		local cable = Builder.part(ship, {
			Name = "Tether",
			Size = Vector3.new(0.7, 0.7, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = Color3.fromRGB(40, 40, 44),
			Material = Enum.Material.Metal,
			CastShadow = false,
		})
		Builder.structural(cable, 1, true, 90)
	end
	-- nose first through the Central Works roof
	Builder.fallDirection(ship, Vector3.new(0, 0, -1))
	ship:SetAttribute("FallSpeed", 30)
	-- the hull smashes whatever it lands on (DestructionService crash impact)
	ship:SetAttribute("CrashDamage", 400)
	ship:SetAttribute("CrashRadius", 22)
end

function ChronoSpire.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "ChronoSpire"
	model.Parent = parent

	plateaus(model)
	clocktower(model)

	-- west plateau: two works and a row of workshops
	works(model, "WestWorks", Vector3.new(-112, WEST_TOP, 62), 30, 28, 4, "East", 2)
	works(model, "PumpHouse", Vector3.new(-112, WEST_TOP, -86), 28, 26, 3, "East", 1)
	for i, z in { 40, 70, 100 } do
		local shop = Builder.highrise(model, "Workshop" .. i, Vector3.new(-40, WEST_TOP, z), 18, 16, 2, 10, brickStyle(if i % 2 == 0 then "West" else "East"))
		local awning = Builder.block(shop, "Awning", Vector3.new(-40, WEST_TOP + 9, z - 9.5), Vector3.new(16, 0.4, 3), if i % 2 == 0 then Color3.fromRGB(150, 50, 40) else Color3.fromRGB(50, 90, 80), Enum.Material.Fabric)
		Builder.structural(awning, 2, false, 15)
	end
	boiler(model, Vector3.new(-90, WEST_TOP, 10))
	boiler(model, Vector3.new(-86, WEST_TOP, 16))

	-- east plateau: the Central Works and four foundries
	local _, worksRoof = works(model, "CentralWorks", Vector3.new(70, EAST_TOP, 0), 44, 36, 3, "West", 2, true)
	works(model, "NorthFoundry", Vector3.new(124, EAST_TOP, 84), 30, 28, 3, "West", 1)
	works(model, "SouthFoundry", Vector3.new(124, EAST_TOP, -84), 30, 30, 4, "West", 2)
	works(model, "GearWorks", Vector3.new(40, EAST_TOP, -96), 28, 24, 3, "East", 1)
	works(model, "BrassMill", Vector3.new(42, EAST_TOP, 100), 26, 24, 4, "East", 1)
	-- boilers inside the Central Works ground floor (and two in the yard): chain reactions
	for _, p in { Vector3.new(60, EAST_TOP, -8), Vector3.new(66, EAST_TOP, -8), Vector3.new(80, EAST_TOP, 6), Vector3.new(104, EAST_TOP, 30), Vector3.new(108, EAST_TOP, 26) } do
		boiler(model, p)
	end

	-- bridges over the channel
	Builder.bridge(model, "IronBridge", Vector3.new(-16, WEST_TOP + 0.5, -100), Vector3.new(16, EAST_TOP + 0.5, -100), 10, IRON, Enum.Material.DiamondPlate, COPPER, IRON, 140)
	Builder.bridge(model, "IronBridge", Vector3.new(-16, WEST_TOP + 0.5, -40), Vector3.new(16, EAST_TOP + 0.5, -40), 8, IRON, Enum.Material.DiamondPlate, COPPER, IRON, 120)
	Builder.bridge(model, "IronBridge", Vector3.new(-16, WEST_TOP + 0.5, 40), Vector3.new(16, EAST_TOP + 0.5, 40), 8, WOOD, Enum.Material.WoodPlanks, BRASS, IRON, 70)
	-- Clocktower 4th floor (open east face) to the Central Works roof
	Builder.bridge(model, "SkyBridge", Vector3.new(-48, 33.5, -27), Vector3.new(51, worksRoof + 0.5, -10), 7, IRON, Enum.Material.Metal, COPPER, IRON, 110)
	-- catwalks between the east roofs
	Builder.bridge(model, "Catwalk", Vector3.new(89, worksRoof + 0.5, 12), Vector3.new(112, EAST_TOP + 36.5, 74), 5, IRON, Enum.Material.DiamondPlate, BRASS, IRON, 80)
	Builder.bridge(model, "Catwalk", Vector3.new(89, worksRoof + 0.5, -12), Vector3.new(112, EAST_TOP + 48.5, -72), 5, IRON, Enum.Material.DiamondPlate, BRASS, IRON, 80)
	Builder.bridge(model, "Catwalk", Vector3.new(-100, WEST_TOP + 48.5, 67), Vector3.new(-45, WEST_TOP + 20.5, 64), 5, IRON, Enum.Material.DiamondPlate, BRASS, IRON, 80)

	airship(model)

	-- steam vents launch you up to the upper floors and catwalks
	for _, p in { Vector3.new(-40, WEST_TOP, -6), Vector3.new(-84, WEST_TOP, -44), Vector3.new(-100, WEST_TOP, 30), Vector3.new(100, EAST_TOP, -2), Vector3.new(60, EAST_TOP, -44), Vector3.new(104, EAST_TOP, 52), Vector3.new(30, EAST_TOP, 10) } do
		steamVent(model, p)
	end

	-- yard clutter to hide behind: crates, coal carts, half-buried gears
	for _, p in { Vector3.new(-30, WEST_TOP, -60), Vector3.new(-80, WEST_TOP, 110), Vector3.new(-130, WEST_TOP, 10), Vector3.new(30, EAST_TOP, -50), Vector3.new(95, EAST_TOP, -40), Vector3.new(140, EAST_TOP, 20), Vector3.new(70, EAST_TOP, 120) } do
		Builder.crates(model, p, 3)
	end
	for _, spec in { { Vector3.new(-26, WEST_TOP + 5, -110), Vector3.new(0, 0, 1), 14, 0.3 }, { Vector3.new(146, EAST_TOP + 6, -10), Vector3.new(-1, 0, 0), 16, -0.25 }, { Vector3.new(-140, WEST_TOP + 4, -40), Vector3.new(1, 0, 0), 12, 0.4 } } do
		local yard = Builder.building(model, "YardGear")
		gear(yard, spec[1], spec[2], spec[3], spec[4], 1)
		local stand = Builder.block(yard, "GearStand", spec[1] - Vector3.new(0, spec[3] / 2, 0) + Vector3.new(0, 0.5, 0), Vector3.new(4, 1, 4), IRON, Enum.Material.Metal)
		Builder.structural(stand, 1, true, 80)
	end
	-- gas lamps
	for _, p in { Vector3.new(-30, WEST_TOP, -30), Vector3.new(-30, WEST_TOP, 20), Vector3.new(-80, WEST_TOP, -110), Vector3.new(30, EAST_TOP, -20), Vector3.new(30, EAST_TOP, 60), Vector3.new(100, EAST_TOP, -120) } do
		local lamp = Builder.building(model, "GasLamp")
		local pole = Builder.block(lamp, "Pole", p + Vector3.new(0, 5, 0), Vector3.new(0.6, 10, 0.6), IRON, Enum.Material.Metal)
		Builder.structural(pole, 1, true, 40)
		local bulb = Builder.block(lamp, "Lamp", p + Vector3.new(0, 10.4, 0), Vector3.new(1.4, 1.6, 1.4), WINDOW, Enum.Material.Glass)
		Builder.structural(bulb, 2, false, 10)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Range = 18
		light.Brightness = 0.9
		light.Parent = bulb
	end

	-- distant foundry skyline and sea stacks (decor)
	local rng = Random.new(31)
	for _ = 1, 22 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(220, 280)
		local h = rng:NextNumber(30, 80)
		local w = rng:NextNumber(14, 28)
		local p = Vector3.new(math.cos(angle) * dist, h / 2 - 20, math.sin(angle) * dist)
		local block = Builder.block(model, "Skyline", p, Vector3.new(w, h, w), BRICK_DARK:Lerp(Color3.fromRGB(40, 30, 30), 0.4), Enum.Material.Brick)
		block.CanCollide = false
		if rng:NextNumber() > 0.5 then
			local chimney = Builder.cylinder(model, "SkylineStack", p + Vector3.new(w * 0.3, h / 2 + 10, 0), 20, 3, BRICK_DARK, Enum.Material.Brick)
			chimney.CanCollide = false
			smoke(chimney, Color3.fromRGB(80, 70, 70), 1.5)
		end
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-30, WEST_TOP + 3, -40),
		Vector3.new(-90, WEST_TOP + 3, -20),
		Vector3.new(-70, WEST_TOP + 3, 40),
		Vector3.new(-120, WEST_TOP + 3, 0),
		Vector3.new(-60, WEST_TOP + 3, 110),
		Vector3.new(-50, WEST_TOP + 3, -110),
		Vector3.new(30, EAST_TOP + 3, -30),
		Vector3.new(104, EAST_TOP + 3, 12),
		Vector3.new(30, EAST_TOP + 3, 60),
		Vector3.new(130, EAST_TOP + 3, 40),
		Vector3.new(90, EAST_TOP + 3, -120),
		Vector3.new(75, EAST_TOP + 3, 120),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "ChronoSpire",
		DisplayName = "Chrono-Spire Citadel",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -4,
		FluidEndY = 20,
		FluidColor = Color3.fromRGB(232, 168, 60),
		FluidMaterial = Enum.Material.CrackedLava,
		HazardFloorY = nil,
		FluidName = "MOLTEN BRASS",
		Lighting = "Foundry",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 0),
		Radius = 165,
	}
end

return ChronoSpire
