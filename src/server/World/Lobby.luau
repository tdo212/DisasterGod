--!strict
-- Sky Lodge: a big timber great hall floating beside the arena. Inside: the Hall of
-- Legends podium (all-time records) under the title wall, four leaderboards along the
-- back wall, the gear shop, a fireside lounge, game pass pedestals, the quest board,
-- the prize wheel and the Neon Climb obby up the east wall to a loft.
-- The front opens onto a glass-floored observation deck that looks down on the arena.
-- Also builds the Disaster God's cloud perch.
--
-- Layout (offsets from Config.World.LobbyOrigin; +Z faces the arena):
--   hall interior  x -80..80, z -60..60, ceiling 34
--   deck           x -56..56, z  60..96
--   obby lane      x  67..80 (behind a glass divider), loft at the front-east corner

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local GodSkins = require(ReplicatedStorage.Shared.GodSkins)

local ROCK = Color3.fromRGB(125, 105, 90)
local ROCK_DARK = Color3.fromRGB(95, 82, 75)
local FLOOR = Color3.fromRGB(196, 146, 98)
local LOG = Color3.fromRGB(122, 80, 48)
local LOG_DARK = Color3.fromRGB(88, 58, 36)
local PLASTER = Color3.fromRGB(242, 230, 208)
local STONE = Color3.fromRGB(150, 145, 140)
local ROOF = Color3.fromRGB(120, 62, 52)
local MARBLE = Color3.fromRGB(232, 236, 242)
local GLASS = Color3.fromRGB(170, 225, 255)
local WOOD = Color3.fromRGB(165, 115, 70)
local FABRIC = Color3.fromRGB(150, 55, 52)
local GOLD = Color3.fromRGB(255, 200, 40)
local WARM_LIGHT = Color3.fromRGB(255, 214, 160)
local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 160, 50),
	Color3.fromRGB(255, 225, 60),
	Color3.fromRGB(90, 220, 90),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(170, 100, 255),
}

local HALF_X = 80
local BACK_Z = -60
local FRONT_Z = 60
local WALL_H = 34
local DECK_HALF_X = 56
local DECK_EDGE_Z = 96
local BARRIER_H = 24

-- Neon Climb (obby) lane
local OBBY_X = 73
local OBBY_PADS = 11
local OBBY_STEP_Z = 8
local OBBY_RISE = 1.5
local DIVIDER_X = 67

export type LobbyInfo = {
	Model: Model,
	Spawn: SpawnLocation,
	HallSpots: { CFrame }, -- top centre of podium tiers 1..3, facing into the hall
	BoardSlots: { CFrame }, -- ground points (facing into the hall) for the leaderboards
	ObbyFinish: BasePart,
	GodPerch: BasePart,
}

local Lobby = {}

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Decoration that should never cast shadows (ceiling, roof) so the hall stays bright.
local function noShadow(part: BasePart): BasePart
	part.CastShadow = false
	return part
end

-- Invisible wall: blocks players but not the camera or raycasts.
local function barrier(parent: Instance, center: Vector3, size: Vector3)
	Builder.part(parent, {
		Name = "InvisibleBarrier",
		Size = size,
		CFrame = CFrame.new(center),
		Color = Color3.new(1, 1, 1),
		Transparency = 1,
		CastShadow = false,
	}).CanQuery = false
end

local function glassPane(parent: Instance, center: Vector3, size: Vector3, transparency: number): BasePart
	local pane = Builder.block(parent, "Glass", center, size, GLASS, Enum.Material.Glass)
	pane.Transparency = transparency
	pane.CastShadow = false
	return pane
end

local function pointLight(part: BasePart, range: number, brightness: number, color: Color3?)
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color or WARM_LIGHT
	light.Shadows = false
	light.Parent = part
end

local function plant(parent: Instance, pos: Vector3)
	Builder.cylinder(parent, "Pot", pos + Vector3.new(0, 1.5, 0), 3, 4, Color3.fromRGB(190, 110, 70), Enum.Material.Slate)
	Builder.block(parent, "Stem", pos + Vector3.new(0, 4.5, 0), Vector3.new(0.6, 4, 0.6), WOOD, Enum.Material.Wood)
	for _, o in { Vector3.new(0, 7.5, 0), Vector3.new(1.3, 6.6, 0.6), Vector3.new(-1.2, 6.8, -0.6) } do
		Builder.part(parent, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			CFrame = CFrame.new(pos + o),
			Color = Color3.fromRGB(80, 170, 75),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

local function chandelier(parent: Instance, L: Vector3, offset: Vector3)
	local pos = L + offset
	local drop = WALL_H - offset.Y
	Builder.block(parent, "Chain", pos + Vector3.new(0, drop / 2, 0), Vector3.new(0.3, drop, 0.3), LOG_DARK, Enum.Material.Metal)
	local ring = Builder.part(parent, {
		Name = "ChandelierRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 9, 9),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = LOG_DARK,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	ring.CastShadow = false
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local candle = Builder.part(parent, {
			Name = "Candle",
			Size = Vector3.new(0.6, 1, 0.6),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 4, 0.8, math.sin(a) * 4)),
			Color = WARM_LIGHT,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		if i == 0 then
			pointLight(candle, 40, 0.8)
		end
	end
end

local function shell(model: Model, L: Vector3)
	local f = folder(model, "Hall")

	-- floor + floating rock underneath
	Builder.block(f, "Floor", L + Vector3.new(0, -1, 0), Vector3.new(HALF_X * 2 + 4, 2, FRONT_Z - BACK_Z + 4), FLOOR, Enum.Material.WoodPlanks)
	Builder.block(f, "Rock1", L + Vector3.new(0, -9, -2), Vector3.new(150, 14, 112), ROCK, Enum.Material.Rock)
	Builder.block(f, "Rock2", L + Vector3.new(4, -22, -4), Vector3.new(110, 14, 80), ROCK_DARK, Enum.Material.Rock)
	Builder.block(f, "Rock3", L + Vector3.new(-3, -36, 0), Vector3.new(66, 16, 50), ROCK, Enum.Material.Rock)
	Builder.block(f, "Rock4", L + Vector3.new(2, -50, -2), Vector3.new(26, 14, 22), ROCK_DARK, Enum.Material.Rock)

	-- rugs: a long runner from the spawn to the deck, and one in front of the hall of legends
	local runner = Builder.block(f, "RunnerTrim", L + Vector3.new(0, 0.04, 14), Vector3.new(16, 0.08, 84), GOLD, Enum.Material.Fabric)
	runner.CanCollide = false
	local rug = Builder.block(f, "Runner", L + Vector3.new(0, 0.08, 14), Vector3.new(13, 0.08, 82), FABRIC, Enum.Material.Fabric)
	rug.CanCollide = false

	-- back wall: plaster with a stone base and log trim
	Builder.block(f, "BackWall", L + Vector3.new(0, WALL_H / 2, BACK_Z - 1), Vector3.new(HALF_X * 2 + 4, WALL_H, 2), PLASTER, Enum.Material.Plaster)
	Builder.block(f, "BackBase", L + Vector3.new(0, 2, BACK_Z - 0.2), Vector3.new(HALF_X * 2, 4, 0.6), STONE, Enum.Material.Cobblestone)
	for x = -HALF_X, HALF_X, 20 do
		Builder.block(f, "BackPost", L + Vector3.new(x, WALL_H / 2, BACK_Z - 0.2), Vector3.new(2, WALL_H, 0.8), LOG, Enum.Material.Wood)
	end

	-- side walls: stone base, log posts and tall windows
	for _, side in { -1, 1 } do
		local x = side * (HALF_X + 1)
		Builder.block(f, "SideBase", L + Vector3.new(x, 3, 0), Vector3.new(2, 6, FRONT_Z - BACK_Z + 4), STONE, Enum.Material.Cobblestone)
		Builder.block(f, "SideTop", L + Vector3.new(x, 30, 0), Vector3.new(2, 8, FRONT_Z - BACK_Z + 4), PLASTER, Enum.Material.Plaster)
		for z = BACK_Z, FRONT_Z, 20 do
			Builder.block(f, "SidePost", L + Vector3.new(x, WALL_H / 2, z), Vector3.new(2.6, WALL_H, 2.6), LOG, Enum.Material.Wood)
		end
		for z = BACK_Z + 10, FRONT_Z - 10, 20 do
			glassPane(f, L + Vector3.new(x, 16, z), Vector3.new(0.6, 20, 17.4), 0.65)
		end
	end

	-- front wall: wide opening onto the deck, windowed wall sections either side
	local sectionW = HALF_X + 2 - DECK_HALF_X
	for _, side in { -1, 1 } do
		local cx = side * (DECK_HALF_X + sectionW / 2)
		Builder.block(f, "FrontBase", L + Vector3.new(cx, 5, FRONT_Z + 1), Vector3.new(sectionW, 10, 2), STONE, Enum.Material.Cobblestone)
		glassPane(f, L + Vector3.new(cx, 20, FRONT_Z + 1), Vector3.new(sectionW, 20, 0.6), 0.6)
		Builder.block(f, "OpeningPillar", L + Vector3.new(side * DECK_HALF_X, 13, FRONT_Z + 1), Vector3.new(3, 26, 3), LOG, Enum.Material.Wood)
	end
	local header = Builder.block(f, "FrontHeader", L + Vector3.new(0, 30, FRONT_Z + 1), Vector3.new(HALF_X * 2 + 4, 8, 2), PLASTER, Enum.Material.Plaster)
	Builder.block(f, "HeaderBeam", L + Vector3.new(0, 26.4, FRONT_Z + 1), Vector3.new(DECK_HALF_X * 2 + 3, 1.2, 2.6), LOG, Enum.Material.Wood)
	local outSign = Builder.block(f, "LodgeSign", L + Vector3.new(0, 30, FRONT_Z + 2.2), Vector3.new(40, 6, 0.4), LOG_DARK, Enum.Material.Wood)
	Builder.sign(outSign, Enum.NormalId.Back, "SKY LODGE", Color3.fromRGB(255, 225, 140))
	local inSign = Builder.block(f, "DeckSign", L + Vector3.new(0, 30, FRONT_Z - 0.2), Vector3.new(36, 5, 0.4), LOG_DARK, Enum.Material.Wood)
	Builder.sign(inSign, Enum.NormalId.Front, "OBSERVATION DECK", Color3.fromRGB(120, 240, 255))
	noShadow(header)

	-- ceiling, beams and a pitched roof
	noShadow(Builder.block(f, "Ceiling", L + Vector3.new(0, WALL_H + 1, 0), Vector3.new(HALF_X * 2 + 4, 2, FRONT_Z - BACK_Z + 4), LOG, Enum.Material.WoodPlanks))
	for z = BACK_Z + 10, FRONT_Z - 10, 20 do
		noShadow(Builder.block(f, "Beam", L + Vector3.new(0, WALL_H - 1, z), Vector3.new(HALF_X * 2, 2, 2), LOG_DARK, Enum.Material.Wood))
	end
	noShadow(Builder.block(f, "RidgeBeam", L + Vector3.new(0, WALL_H - 1.5, 0), Vector3.new(2.4, 1.6, FRONT_Z - BACK_Z), LOG_DARK, Enum.Material.Wood))
	local roofLen = (FRONT_Z - BACK_Z) / 2 + 6
	for _, dir in { 1, -1 } do
		local c = L + Vector3.new(0, WALL_H + 2 + 7, dir * roofLen / 2)
		noShadow(Builder.ramp(f, "Roof", CFrame.lookAt(c, c + Vector3.new(0, 0, dir)), Vector3.new(HALF_X * 2 + 10, 14, roofLen), ROOF, Enum.Material.Slate))
	end

	for _, x in { -44, 0, 44 } do
		for _, z in { -30, 22 } do
			chandelier(f, L, Vector3.new(x, 25, z))
		end
	end
	for _, p in { Vector3.new(-74, 0, -54), Vector3.new(-74, 0, 52), Vector3.new(18.2, 0, -55), Vector3.new(-18.2, 0, -55), Vector3.new(48, 0, 54) } do
		plant(f, L + p)
	end
end

-- Fireside lounge against the west wall.
local function lounge(model: Model, L: Vector3)
	local f = folder(model, "Lounge")
	local z0 = 25
	Builder.block(f, "Hearth", L + Vector3.new(-77.5, 7, z0), Vector3.new(5, 14, 16), STONE, Enum.Material.Cobblestone)
	Builder.block(f, "Chimney", L + Vector3.new(-78.5, 24, z0), Vector3.new(3, 20, 8), STONE, Enum.Material.Cobblestone)
	Builder.block(f, "Mantel", L + Vector3.new(-74.6, 10.5, z0), Vector3.new(1.6, 0.8, 18), WOOD, Enum.Material.Wood)
	Builder.block(f, "Firebox", L + Vector3.new(-75.1, 3, z0), Vector3.new(0.4, 5, 8), Color3.fromRGB(30, 24, 22), Enum.Material.Slate)
	local logs = Builder.block(f, "FireLogs", L + Vector3.new(-74.4, 1, z0), Vector3.new(2, 1.2, 5), LOG_DARK, Enum.Material.Wood)
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 4
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = logs
	pointLight(logs, 28, 2.2, Color3.fromRGB(255, 160, 80))

	local rug = Builder.block(f, "LoungeRug", L + Vector3.new(-64, 0.08, z0), Vector3.new(18, 0.08, 22), Color3.fromRGB(70, 110, 140), Enum.Material.Fabric)
	rug.CanCollide = false
	Builder.block(f, "CoffeeTable", L + Vector3.new(-65, 1.2, z0), Vector3.new(5, 0.6, 8), WOOD, Enum.Material.Wood)
	-- sofa facing the fire, plus one either side
	Builder.block(f, "SofaSeat", L + Vector3.new(-57, 1.2, z0), Vector3.new(5, 1.6, 14), FABRIC, Enum.Material.Fabric)
	Builder.block(f, "SofaBack", L + Vector3.new(-54.9, 3.2, z0), Vector3.new(1.4, 4.4, 14), FABRIC, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		local z = z0 + side * 10
		Builder.block(f, "SofaSeat", L + Vector3.new(-66, 1.2, z), Vector3.new(12, 1.6, 5), FABRIC, Enum.Material.Fabric)
		Builder.block(f, "SofaBack", L + Vector3.new(-66, 3.2, z + side * 2.1), Vector3.new(12, 4.4, 1.4), FABRIC, Enum.Material.Fabric)
	end
end

local function shop(model: Model, L: Vector3)
	local s = folder(model, "ShopStall")
	local c = L + Vector3.new(-50, 0, -24)
	local counter = Builder.block(s, "Counter", c + Vector3.new(0, 2, 4), Vector3.new(18, 4, 4), WOOD, Enum.Material.WoodPlanks)
	Builder.block(s, "CounterTop", c + Vector3.new(0, 4.2, 4), Vector3.new(19, 0.4, 5), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic)
	Builder.block(s, "BackWall", c + Vector3.new(0, 5, -4), Vector3.new(18, 10, 1), Color3.fromRGB(235, 240, 250), Enum.Material.SmoothPlastic)
	for _, x in { -8.5, 8.5 } do
		for _, z in { -4, 5.5 } do
			Builder.block(s, "Post", c + Vector3.new(x, 5.5, z), Vector3.new(1, 11, 1), Color3.fromRGB(70, 140, 230), Enum.Material.SmoothPlastic)
		end
	end
	-- striped awning roof
	for i = 0, 8 do
		Builder.block(s, "Awning", c + Vector3.new(-8 + i * 2, 11.3, 1), Vector3.new(2, 0.8, 12), if i % 2 == 0 then Color3.fromRGB(60, 140, 240) else Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
	local sign = Builder.block(s, "ShopSign", c + Vector3.new(0, 14, 6.5), Vector3.new(14, 4, 1), Color3.fromRGB(60, 140, 240), Enum.Material.SmoothPlastic)
	Builder.sign(sign, Enum.NormalId.Back, "SHOP", Color3.new(1, 1, 1))
	Builder.sign(sign, Enum.NormalId.Front, "SHOP", Color3.new(1, 1, 1))
	for i = 0, 6 do
		Builder.cylinder(s, "Bottle", c + Vector3.new(-6 + i * 2, 7.2, -3), 1.6, 0.9, RAINBOW[(i % #RAINBOW) + 1], Enum.Material.Glass)
	end
	Builder.block(s, "Shelf", c + Vector3.new(0, 6.2, -3), Vector3.new(16, 0.4, 1.5), WOOD, Enum.Material.Wood)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Gear Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
end

-- Hall of Legends: a three-tier podium under the title wall. LeaderboardService stands
-- the all-time top three on it. Returns the tier tops (facing into the hall).
local function hallOfLegends(model: Model, L: Vector3): { CFrame }
	local f = folder(model, "HallOfLegends")
	local z = -51
	Builder.block(f, "Dais", L + Vector3.new(0, 0.5, z), Vector3.new(30, 1, 14), Color3.fromRGB(60, 62, 80), Enum.Material.Marble)
	Builder.block(f, "DaisTrim", L + Vector3.new(0, 0.3, z), Vector3.new(31, 0.6, 15), GOLD, Enum.Material.Metal)
	local spots = {}
	local spec = {
		{ x = 0, h = 6, color = GOLD, label = "1" },
		{ x = -9, h = 4.2, color = Color3.fromRGB(205, 210, 220), label = "2" },
		{ x = 9, h = 2.8, color = Color3.fromRGB(215, 135, 60), label = "3" },
	}
	for i, s in spec do
		local block = Builder.block(f, "Tier" .. s.label, L + Vector3.new(s.x, 1 + s.h / 2, z), Vector3.new(7, s.h, 7), s.color, Enum.Material.Marble)
		block:SetAttribute("HallRank", i)
		local plate = Builder.block(f, "Number" .. s.label, L + Vector3.new(s.x, 1 + s.h / 2, z + 3.6), Vector3.new(2.6, 2.6, 0.2), Color3.fromRGB(40, 40, 55), Enum.Material.SmoothPlastic)
		Builder.sign(plate, Enum.NormalId.Back, s.label, Color3.new(1, 1, 1))
		pointLight(block, 12, 0.5, s.color)
		local top = L + Vector3.new(s.x, 1 + s.h, z)
		spots[i] = CFrame.lookAt(top, top + Vector3.new(0, 0, 1))
	end
	local title = Builder.block(f, "HallTitle", L + Vector3.new(0, 23, BACK_Z + 0.3), Vector3.new(34, 5, 0.4), LOG_DARK, Enum.Material.Wood)
	Builder.sign(title, Enum.NormalId.Back, "🏆 HALL OF LEGENDS", GOLD)
	local sub = Builder.block(f, "HallSubtitle", L + Vector3.new(0, 19.3, BACK_Z + 0.3), Vector3.new(28, 2, 0.4), LOG_DARK, Enum.Material.Wood)
	Builder.sign(sub, Enum.NormalId.Back, Config.Leaderboards.Hall.Subtitle, Color3.new(1, 1, 1))
	return spots
end

-- Neon Climb: evenly spaced pads up the east wall to a loft in the front corner, behind
-- a glass divider so nobody can skip from the return ramp. A ramp walks back down.
local function obby(model: Model, L: Vector3): BasePart
	local o = folder(model, "NeonClimb")
	local start = Builder.block(o, "ObbyStart", L + Vector3.new(OBBY_X, 0.4, -46), Vector3.new(7, 0.8, 7), Color3.fromRGB(90, 230, 120), Enum.Material.Neon)
	Builder.sign(start, Enum.NormalId.Top, "START", Color3.new(1, 1, 1))
	local sign = Builder.block(o, "ObbySign", L + Vector3.new(OBBY_X, 11, BACK_Z + 0.3), Vector3.new(12, 3.5, 0.4), LOG_DARK, Enum.Material.Wood)
	Builder.sign(sign, Enum.NormalId.Back, "NEON CLIMB  +" .. Config.Scoring.ObbyCoins .. " 🪙", Color3.fromRGB(140, 255, 160))

	for i = 1, OBBY_PADS do
		local x = OBBY_X + (if i % 2 == 0 then 2 else -2)
		local y = 1 + i * OBBY_RISE
		local pos = L + Vector3.new(x, y, -38 + (i - 1) * OBBY_STEP_Z)
		Builder.block(o, "ObbyPad", pos, Vector3.new(5, 1, 5), RAINBOW[(i % #RAINBOW) + 1], Enum.Material.Neon)
		-- slim glowing stem so the pads read as one course instead of floating bits
		local stem = Builder.part(o, {
			Name = "PadStem",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(y - 0.5, 0.8, 0.8),
			CFrame = CFrame.new(Vector3.new(pos.X, L.Y + (y - 0.5) / 2, pos.Z)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = RAINBOW[(i % #RAINBOW) + 1],
			Material = Enum.Material.Glass,
			CanCollide = false,
			CastShadow = false,
		})
		stem.Transparency = 0.4
	end

	-- loft in the front-east corner (looks out through the front windows)
	local loftTop = 1 + (OBBY_PADS + 1) * OBBY_RISE + 1
	local loftMinX = 58
	local loftZ0 = 48
	local loftW = HALF_X - loftMinX
	local loftD = FRONT_Z - loftZ0
	Builder.block(o, "Loft", L + Vector3.new(loftMinX + loftW / 2, loftTop - 0.5, loftZ0 + loftD / 2), Vector3.new(loftW, 1, loftD), FLOOR, Enum.Material.WoodPlanks)
	Builder.block(o, "LoftBeam", L + Vector3.new(loftMinX + loftW / 2, loftTop - 1.5, loftZ0), Vector3.new(loftW, 1, 1), LOG, Enum.Material.Wood)
	local finish = Builder.block(o, "ObbyFinish", L + Vector3.new(OBBY_X, loftTop - 0.4, loftZ0 + loftD / 2), Vector3.new(8, 1, 8), GOLD, Enum.Material.Neon)
	Builder.block(o, "FlagPole", L + Vector3.new(OBBY_X + 5, loftTop + 4.5, FRONT_Z - 2), Vector3.new(0.5, 9, 0.5), Color3.new(1, 1, 1), Enum.Material.Metal)
	Builder.block(o, "Flag", L + Vector3.new(OBBY_X + 5, loftTop + 8, FRONT_Z - 4), Vector3.new(0.2, 2.5, 3.5), Color3.fromRGB(255, 70, 90), Enum.Material.SmoothPlastic)
	-- loft rail on the open (west) side; the ramp joins the south edge
	glassPane(o, L + Vector3.new(loftMinX, loftTop + 1.6, loftZ0 + loftD / 2), Vector3.new(0.4, 3.2, loftD), 0.7)

	-- return ramp from the loft's south edge back to the floor, west of the divider
	local rampX = 62
	local length = loftTop * 2.2
	local center = Vector3.new(rampX, L.Y + loftTop / 2, L.Z + loftZ0 - length / 2)
	Builder.ramp(o, "ReturnRamp", CFrame.lookAt(center, center + Vector3.new(0, 0, -1)), Vector3.new(6, loftTop, length), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)

	-- glass divider between the course and the rest of the hall / the ramp
	local dz0, dz1 = -44, loftZ0
	local divider = glassPane(o, L + Vector3.new(DIVIDER_X, 14, (dz0 + dz1) / 2), Vector3.new(0.4, 28, dz1 - dz0), 0.88)
	divider.Name = "ObbyDivider"
	Builder.block(o, "DividerTrim", L + Vector3.new(DIVIDER_X, 28.2, (dz0 + dz1) / 2), Vector3.new(0.6, 0.4, dz1 - dz0), Color3.fromRGB(120, 240, 255), Enum.Material.Neon)
	return finish
end

-- Glass-floored deck past the front opening. Low rail, invisible walls above it, and the
-- telescopes pushed to the corners so the middle stays clear for looking down.
local function deck(model: Model, L: Vector3)
	local d = folder(model, "ObservationDeck")
	local solidEnd = 82
	local deckZ0 = FRONT_Z + 2 -- the hall floor runs under the doorway
	local depth = solidEnd - deckZ0
	Builder.block(d, "Deck", L + Vector3.new(0, -1, deckZ0 + depth / 2), Vector3.new(DECK_HALF_X * 2, 2, depth), MARBLE, Enum.Material.Marble)
	local glassDepth = DECK_EDGE_Z - solidEnd
	local floorGlass = glassPane(d, L + Vector3.new(0, -0.5, solidEnd + glassDepth / 2), Vector3.new(DECK_HALF_X * 2, 1, glassDepth), 0.55)
	floorGlass.Name = "GlassFloor"
	for x = -DECK_HALF_X, DECK_HALF_X, 16 do
		Builder.block(d, "FloorFrame", L + Vector3.new(x, -0.45, solidEnd + glassDepth / 2), Vector3.new(0.6, 1.1, glassDepth), Color3.fromRGB(60, 65, 80), Enum.Material.Metal)
	end
	Builder.block(d, "Under", L + Vector3.new(0, -3, deckZ0 + depth / 2), Vector3.new(DECK_HALF_X * 2 - 6, 2, depth - 2), ROCK_DARK, Enum.Material.Rock)

	-- rails: front and both sides (no neon on the front one, it would glare across the view)
	local railColor = Color3.fromRGB(60, 65, 80)
	local function rail(center: Vector3, length: number, alongX: boolean)
		local size = if alongX then Vector3.new(length, 0.4, 0.5) else Vector3.new(0.5, 0.4, length)
		Builder.block(d, "TopRail", L + center + Vector3.new(0, 3.4, 0), size, railColor, Enum.Material.Metal)
		if not alongX then
			Builder.block(d, "RailGlow", L + center + Vector3.new(0, 0.15, 0), size, Color3.fromRGB(80, 240, 255), Enum.Material.Neon)
		end
		glassPane(d, L + center + Vector3.new(0, 1.7, 0), if alongX then Vector3.new(length, 3.2, 0.2) else Vector3.new(0.2, 3.2, length), 0.85)
		barrier(d, L + center + Vector3.new(0, BARRIER_H / 2, 0), if alongX then Vector3.new(length, BARRIER_H, 1) else Vector3.new(1, BARRIER_H, length))
	end
	rail(Vector3.new(0, 0, DECK_EDGE_Z), DECK_HALF_X * 2, true)
	for _, side in { -1, 1 } do
		rail(Vector3.new(side * DECK_HALF_X, 0, (FRONT_Z + DECK_EDGE_Z) / 2), DECK_EDGE_Z - FRONT_Z, false)
	end
	for x = -DECK_HALF_X, DECK_HALF_X, 16 do
		Builder.block(d, "RailPost", L + Vector3.new(x, 1.8, DECK_EDGE_Z), Vector3.new(0.5, 3.6, 0.5), railColor, Enum.Material.Metal)
	end

	for _, x in { -48, 48 } do
		Builder.cylinder(d, "ScopeBase", L + Vector3.new(x, 1.5, DECK_EDGE_Z - 4), 3, 1, railColor, Enum.Material.Metal)
		local eye = L + Vector3.new(x, 3.4, DECK_EDGE_Z - 4)
		local aim = (Config.World.ArenaCenter - eye).Unit
		Builder.part(d, {
			Name = "Scope",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 1.4, 1.4),
			CFrame = CFrame.lookAt(eye, eye + aim) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(210, 215, 230),
			Material = Enum.Material.Metal,
		})
	end
	-- benches by the doorway, out of the sight line
	for _, x in { -40, 40 } do
		Builder.block(d, "BenchSeat", L + Vector3.new(x, 1.3, FRONT_Z + 6), Vector3.new(10, 0.6, 2.6), WOOD, Enum.Material.Wood)
		for _, dx in { -4, 4 } do
			Builder.block(d, "BenchLeg", L + Vector3.new(x + dx, 0.5, FRONT_Z + 6), Vector3.new(0.8, 1, 2.2), LOG_DARK, Enum.Material.Wood)
		end
	end
end

local function prompt(parent: Instance, name: string, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

-- Daily quest board (the client opens the quest window).
local function questBoard(model: Model, L: Vector3)
	local f = folder(model, "QuestBoard")
	local c = L + Vector3.new(-26, 0, -10)
	local board = Builder.block(f, "Board", c + Vector3.new(0, 6.5, 0), Vector3.new(13, 6, 0.6), Color3.fromRGB(130, 88, 52), Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Builder.sign(board, face, "📜 DAILY QUESTS\n3 new every day", Color3.fromRGB(255, 225, 90))
	end
	for _, x in { -5.5, 5.5 } do
		Builder.block(f, "Post", c + Vector3.new(x, 2, 0), Vector3.new(0.8, 4, 0.8), WOOD, Enum.Material.Wood)
	end
	prompt(board, "QuestPrompt", "View Quests", "Daily Quests")
end

-- Prize wheel stand (the client opens the spin window).
local function spinStand(model: Model, L: Vector3)
	local f = folder(model, "SpinStand")
	local c = L + Vector3.new(26, 0, -10)
	local hub = c + Vector3.new(0, 7.5, 0)
	Builder.block(f, "Post", c + Vector3.new(0, 3.5, 0.9), Vector3.new(1.2, 7, 1), Color3.fromRGB(45, 50, 65), Enum.Material.Metal)
	Builder.part(f, {
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 10, 10),
		CFrame = CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(190, 215, 245),
	})
	local disc = Builder.part(f, {
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9, 9, 9),
		CFrame = CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(140, 240, 20),
	})
	for i = 0, 4 do
		Builder.part(f, {
			Name = "Spoke",
			Size = Vector3.new(0.3, 4.4, 1.05),
			CFrame = CFrame.new(hub) * CFrame.Angles(0, 0, math.rad(i * 72)) * CFrame.new(0, 2.2, 0),
			Color = Color3.fromRGB(20, 60, 20),
		})
	end
	Builder.part(f, { Name = "Hub", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(hub), Color = GOLD, Material = Enum.Material.Neon })
	Builder.block(f, "Pointer", hub + Vector3.new(0, 5.2, 0), Vector3.new(1, 1.4, 1.1), Color3.fromRGB(230, 45, 55), Enum.Material.Neon)
	local sign = Builder.block(f, "SpinSign", hub + Vector3.new(0, 7.4, 0), Vector3.new(11, 2.4, 0.5), Color3.fromRGB(255, 60, 150), Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Builder.sign(sign, face, "🎡 SPIN TO WIN", Color3.new(1, 1, 1))
	end
	prompt(disc, "SpinPrompt", "Spin", "Prize Wheel")
end

local PASS_SPOTS = {
	{ Key = "VIP", Offset = Vector3.new(-38, 0, 8), Color = GOLD },
	{ Key = "GodPriority", Offset = Vector3.new(-28, 0, 22), Color = Color3.fromRGB(170, 90, 255) },
	{ Key = "DoubleCoins", Offset = Vector3.new(38, 0, 8), Color = Color3.fromRGB(90, 220, 90) },
	{ Key = "QuickDash", Offset = Vector3.new(28, 0, 22), Color = Color3.fromRGB(60, 230, 230) },
}

-- Blocky display figure standing on `feet`. Returns the torso.
local function mannequin(parent: Instance, feet: Vector3, color: Color3, material: Enum.Material): BasePart
	for _, x in { -0.55, 0.55 } do
		Builder.block(parent, "Leg", feet + Vector3.new(x, 1, 0), Vector3.new(0.95, 2, 0.95), color, material)
		Builder.block(parent, "Arm", feet + Vector3.new(x * 2.75, 3, 0), Vector3.new(0.9, 2, 0.9), color, material)
	end
	local torso = Builder.block(parent, "Torso", feet + Vector3.new(0, 3, 0), Vector3.new(2, 2, 1), color, material)
	Builder.part(parent, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), CFrame = CFrame.new(feet + Vector3.new(0, 4.8, 0)), Color = color, Material = material })
	return torso
end

-- Glowing pedestals in the middle of the hall that show each game pass in 3D.
local function passPedestals(model: Model, L: Vector3)
	local root = folder(model, "PassPedestals")
	for _, spot in PASS_SPOTS do
		local def = Config.Monetization.Passes[spot.Key]
		local f = folder(root, spot.Key)
		local base = L + spot.Offset
		local pedestal = Builder.cylinder(f, "Pedestal", base + Vector3.new(0, 0.6, 0), 1.2, 7, Color3.fromRGB(45, 48, 66), Enum.Material.Marble)
		local glow = Builder.cylinder(f, "Glow", base + Vector3.new(0, 1.25, 0), 0.15, 6, spot.Color, Enum.Material.Neon)
		pointLight(glow, 12, 0.8, spot.Color)
		local feet = base + Vector3.new(0, 1.3, 0)
		local neon = spot.Key == "GodPriority"
		local torso = mannequin(f, feet, if neon then spot.Color else Color3.fromRGB(235, 236, 242), if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic)

		if spot.Key == "VIP" then
			Builder.cylinder(f, "Crown", feet + Vector3.new(0, 5.8, 0), 0.6, 1.6, spot.Color, Enum.Material.Neon)
			for i, color in RAINBOW do
				local streak = Builder.block(f, "Trail", feet + Vector3.new(0, 1.6 + i * 0.4, 3), Vector3.new(0.25, 0.3, 4.5 - i * 0.3), color, Enum.Material.Neon)
				streak.CanCollide = false
			end
		elseif spot.Key == "GodPriority" then
			for _, x in { -2.7, 2.7 } do
				local orb = Builder.part(f, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(feet + Vector3.new(x, 4.6, 0)), Color = Color3.fromRGB(230, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
				orb.Transparency = 0.1
			end
		elseif spot.Key == "DoubleCoins" then
			for _, x in { -2.4, 2.4 } do
				for k = 0, 4 do
					Builder.cylinder(f, "Coin", feet + Vector3.new(x, 0.2 + k * 0.36, 0.4), 0.3, 1.7, GOLD, Enum.Material.Metal)
				end
			end
		else
			for i = 1, 4 do
				local streak = Builder.block(f, "Streak", feet + Vector3.new((i - 2.5) * 0.7, 1 + i * 0.8, 3.2), Vector3.new(0.2, 0.2, 5), spot.Color, Enum.Material.Neon)
				streak.CanCollide = false
			end
		end

		local gui = Instance.new("BillboardGui")
		gui.Name = "PassLabel"
		gui.Size = UDim2.new(11, 0, 3.6, 0)
		gui.StudsOffset = Vector3.new(0, 5.4, 0)
		gui.MaxDistance = 120
		gui.Parent = torso
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = string.format("%s %s\n<font color=\"#FFD23C\">R$ %d</font>", def.Icon, def.Name, def.Price)
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label

		local p = prompt(pedestal, "PassPrompt", "Get " .. def.Name, def.Description)
		p:SetAttribute("PassKey", spot.Key)
	end
end

-- God skin display: a small statue of every skin either side of the spawn, facing the
-- hall. The prompt opens the shop's Style tab (MenuController).
local SKIN_SPOTS = { Vector3.new(-40, 0, -42), Vector3.new(-30, 0, -42), Vector3.new(-20, 0, -42), Vector3.new(20, 0, -42), Vector3.new(30, 0, -42), Vector3.new(40, 0, -42) }

local function skinDisplays(model: Model, L: Vector3)
	local root = folder(model, "SkinDisplays")
	local i = 0
	for _, def in Config.Cosmetics.Items do
		if def.Category ~= "GodSkin" then
			continue
		end
		i += 1
		local spot = SKIN_SPOTS[i]
		if not spot then
			break
		end
		local base = L + spot
		local pedestal = Builder.cylinder(root, "SkinPedestal", base + Vector3.new(0, 0.75, 0), 1.5, 6, Color3.fromRGB(45, 48, 66), Enum.Material.Marble)
		local glow = Builder.cylinder(root, "SkinGlow", base + Vector3.new(0, 1.55, 0), 0.15, 5, def.Color, Enum.Material.Neon)
		pointLight(glow, 10, 0.6, def.Color)
		local statue = GodSkins.build(def.Id, Config.Cosmetics.DisplayScale)
		statue:PivotTo(CFrame.new(base + Vector3.new(0, 5.2, 0)) * CFrame.Angles(0, math.rad(180), 0))
		statue.Parent = root
		local gui = Instance.new("BillboardGui")
		gui.Name = "SkinLabel"
		gui.Size = UDim2.new(8, 0, 2.2, 0)
		gui.StudsOffset = Vector3.new(0, 7.6, 0)
		gui.MaxDistance = 90
		gui.Parent = pedestal
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = def.Icon .. " " .. def.Name
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Parent = label
		prompt(pedestal, "CosmeticPrompt", "View God Skins", def.Name)
	end
end

local function godPerch(model: Model): BasePart
	local p = Config.World.GodPerch
	local f = folder(model, "GodPerch")
	local platform = Builder.cylinder(f, "PerchPlatform", p - Vector3.new(0, 3.5, 0), 1, 14, Color3.fromRGB(150, 90, 255), Enum.Material.Neon)
	platform.Transparency = 0.2
	for _, o in { Vector3.new(5, -5, 0), Vector3.new(-5, -5.5, 2), Vector3.new(0, -6, -5), Vector3.new(2, -4.5, 5) } do
		local puff = Builder.part(f, {
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(9, 9, 9),
			CFrame = CFrame.new(p + o),
			Color = Color3.fromRGB(235, 230, 255),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		puff.Transparency = 0.15
	end
	return platform
end

function Lobby.build(parent: Instance): LobbyInfo
	local L = Config.World.LobbyOrigin
	local model = Instance.new("Model")
	model.Name = "SkyLodge"
	model.Parent = parent

	shell(model, L)
	lounge(model, L)
	deck(model, L)
	local hallSpots = hallOfLegends(model, L)
	shop(model, L)
	local finish = obby(model, L)
	questBoard(model, L)
	spinStand(model, L)
	passPedestals(model, L)
	skinDisplays(model, L)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 0.4, 12)
	spawn.CFrame = CFrame.new(L + Vector3.new(0, 0.2, -26))
	spawn.Color = Color3.fromRGB(80, 170, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- leaderboards along the back wall, two either side of the Hall of Legends
	local boardSlots = {}
	for _, x in { -56, -32, 32, 56 } do
		local p = L + Vector3.new(x, 0, BACK_Z + 3)
		table.insert(boardSlots, CFrame.lookAt(p, p + Vector3.new(0, 0, 1)))
	end

	local perch = godPerch(model)

	return {
		Model = model,
		Spawn = spawn,
		HallSpots = hallSpots,
		BoardSlots = boardSlots,
		ObbyFinish = finish,
		GodPerch = perch,
	}
end

return Lobby
