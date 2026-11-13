--!strict
-- Arena 6: Starlight Boardwalk. A sunset carnival pier. The whole map stands on wooden
-- pilings in 20x20 sections: knock out pilings and the deck section drops into the sea.
-- The Ferris wheel rides on an A-frame; break the legs and the welded wheel rolls down
-- the boardwalk like a wrecking ball. A wooden coaster on climbable trestles is the high
-- ground; a striped circus tent and stalls fill the plaza.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local DECK_Y = 8 -- deck centre (top = 8.5)
local TOP = DECK_Y + 0.5
local PLANK = Color3.fromRGB(170, 120, 72)
local PILING = Color3.fromRGB(110, 78, 50)
local TRESTLE = Color3.fromRGB(125, 85, 52)
local RED = Color3.fromRGB(225, 45, 50)
local WHITE = Color3.fromRGB(250, 245, 240)
local LIGHTS = {
	Color3.fromRGB(255, 80, 120),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(150, 255, 110),
	Color3.fromRGB(190, 110, 255),
}

local COLS, ROWS = 8, 6
local FERRIS_ROW, FERRIS_LAST_COLUMN = 3, 2 -- pier sections under the Ferris wheel
local FOOTING = Color3.fromRGB(150, 150, 158)
local X0, Z0 = -70, -40 -- centre of the first section

local StarlightBoardwalk = {}

local function pier(model: Model)
	for ix = 0, COLS - 1 do
		for iz = 0, ROWS - 1 do
			local c = Vector3.new(X0 + ix * 20, 0, Z0 + iz * 20)
			local section = Builder.building(model, "PierSection")
			-- the sections under the Ferris wheel's feet stand on unbreakable concrete
			-- footings, so the wheel always snaps off its A-frame and rolls down the
			-- boardwalk instead of sinking straight through the floor
			local reinforced = iz == FERRIS_ROW and ix <= FERRIS_LAST_COLUMN
			for _, o in { Vector3.new(8.5, 0, 8.5), Vector3.new(-8.5, 0, 8.5), Vector3.new(8.5, 0, -8.5), Vector3.new(-8.5, 0, -8.5) } do
				if reinforced then
					Builder.cylinder(section, "Footing", c + o + Vector3.new(0, 0.75, 0), 13.5, 3, FOOTING, Enum.Material.Concrete)
				else
					local pile = Builder.cylinder(section, "Piling", c + o + Vector3.new(0, 0.75, 0), 13.5, 1.8, PILING, Enum.Material.Wood)
					Builder.structural(pile, 1, true, 60)
				end
			end
			local deck = Builder.block(section, "Deck", c + Vector3.new(0, DECK_Y, 0), Vector3.new(20, 1, 20), if (ix + iz) % 2 == 0 then PLANK else PLANK:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.WoodPlanks)
			if not reinforced then
				Builder.structural(deck, 2, false, 60)
			end
			-- perimeter rails belong to their section (they fall with it)
			local edges = {}
			if ix == 0 then
				table.insert(edges, Vector3.new(-1, 0, 0))
			end
			if ix == COLS - 1 then
				table.insert(edges, Vector3.new(1, 0, 0))
			end
			if iz == 0 then
				table.insert(edges, Vector3.new(0, 0, -1))
			end
			if iz == ROWS - 1 then
				table.insert(edges, Vector3.new(0, 0, 1))
			end
			for _, e in edges do
				local rail = Builder.block(section, "Rail", c + e * 9.6 + Vector3.new(0, TOP + 1.6, 0), if e.X ~= 0 then Vector3.new(0.5, 0.5, 20) else Vector3.new(20, 0.5, 0.5), PILING, Enum.Material.Wood)
				Builder.structural(rail, 2, false, 20)
				for _, k in { -8, 0, 8 } do
					local baluster = Builder.block(section, "Baluster", c + e * 9.6 + (if e.X ~= 0 then Vector3.new(0, 0, k) else Vector3.new(k, 0, 0)) + Vector3.new(0, TOP + 0.8, 0), Vector3.new(0.4, 1.6, 0.4), PILING, Enum.Material.Wood)
					Builder.structural(baluster, 2, false, 15)
				end
			end
		end
	end
end

local function ferrisWheel(model: Model)
	local hub = Vector3.new(-52, TOP + 26, 22)
	local wheel = Builder.building(model, "FerrisWheel")
	-- A-frame legs (supports)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local foot = Vector3.new(hub.X + sx * 12, TOP, hub.Z + sz * 5)
			local head = Vector3.new(hub.X, hub.Y, hub.Z + sz * 2.5)
			local leg = Builder.part(wheel, {
				Name = "AFrameLeg",
				Size = Vector3.new(1.6, 1.6, (head - foot).Magnitude),
				CFrame = CFrame.lookAt((foot + head) / 2, head),
				Color = Color3.fromRGB(230, 230, 240),
				Material = Enum.Material.Metal,
			})
			Builder.structural(leg, 1, true, 110)
		end
	end
	local axle = Builder.part(wheel, {
		Name = "Axle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2.4, 2.4),
		CFrame = CFrame.new(hub) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(200, 200, 210),
		Material = Enum.Material.Metal,
	})
	Builder.structural(axle, 2, false, 150)
	local star = Builder.part(wheel, {
		Name = "HubStar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 5, 5),
		CFrame = CFrame.new(hub + Vector3.new(0, 0, -1.6)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.Neon,
	})
	Builder.structural(star, 2, false, 60)
	local radius = 22
	local segments = 20
	for i = 0, segments - 1 do
		local a0 = i / segments * math.pi * 2
		local a1 = (i + 1) / segments * math.pi * 2
		local p0 = hub + Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
		local p1 = hub + Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
		local seg = Builder.part(wheel, {
			Name = "Rim",
			Size = Vector3.new(1.2, 1.2, (p1 - p0).Magnitude + 0.3),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = LIGHTS[(i % #LIGHTS) + 1],
			Material = Enum.Material.Neon,
		})
		Builder.structural(seg, 2, false, 80)
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local rimPoint = hub + Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		local spoke = Builder.part(wheel, {
			Name = "Spoke",
			Size = Vector3.new(0.6, 0.6, radius),
			CFrame = CFrame.lookAt((hub + rimPoint) / 2, rimPoint),
			Color = Color3.fromRGB(235, 235, 245),
			Material = Enum.Material.Metal,
		})
		Builder.structural(spoke, 2, false, 70)
		local gondola = Builder.block(wheel, "Gondola", rimPoint - Vector3.new(0, 2.6, 0), Vector3.new(3.4, 3, 3), LIGHTS[(i % #LIGHTS) + 1]:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.SmoothPlastic)
		Builder.structural(gondola, 2, false, 70)
	end
	-- rolls east down the boardwalk once the A-frame fails
	Builder.fallDirection(wheel, Vector3.new(1, 0, 0))
	-- boarding platform (decor)
	Builder.block(model, "BoardingDeck", Vector3.new(hub.X, TOP + 0.3, hub.Z - 8), Vector3.new(10, 0.6, 5), Color3.fromRGB(80, 80, 95), Enum.Material.DiamondPlate)
end

local function coaster(model: Model)
	local centre = Vector3.new(16, 0, 48)
	local rx, rz = 34, 13
	local points = 28
	local perBuilding = 7
	local building: Model? = nil
	local function trackPoint(i: number): Vector3
		local t = i / points * math.pi * 2
		local h = 19 + 9 * math.sin(2 * t) + 4 * math.sin(t)
		return centre + Vector3.new(math.cos(t) * rx, TOP + h, math.sin(t) * rz)
	end
	for i = 0, points - 1 do
		if i % perBuilding == 0 then
			building = Builder.building(model, "CoasterSection")
		end
		local b = building :: Model
		local p0, p1 = trackPoint(i), trackPoint(i + 1)
		local dir = (p1 - p0).Unit
		local right = CFrame.lookAt(Vector3.zero, dir).RightVector
		local deck = Builder.part(b, {
			Name = "Track",
			Size = Vector3.new(4.5, 0.6, (p1 - p0).Magnitude + 0.2),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = Color3.fromRGB(150, 105, 62),
			Material = Enum.Material.WoodPlanks,
		})
		Builder.structural(deck, 2, false, 70)
		for _, side in { -1, 1 } do
			local q0 = p0 + right * side * 1.8 + Vector3.new(0, 0.5, 0)
			local q1 = p1 + right * side * 1.8 + Vector3.new(0, 0.5, 0)
			local rail = Builder.part(b, {
				Name = "Rail",
				Size = Vector3.new(0.35, 0.35, (q1 - q0).Magnitude + 0.2),
				CFrame = CFrame.lookAt((q0 + q1) / 2, q1),
				Color = Color3.fromRGB(70, 70, 80),
				Material = Enum.Material.Metal,
			})
			Builder.structural(rail, 2, false, 40)
		end
		-- climbable trestle down to the deck
		local trestle = Builder.part(b, {
			Name = "Trestle",
			Class = "TrussPart",
			Size = Vector3.new(2, p0.Y - TOP - 0.4, 2),
			CFrame = CFrame.new(p0.X, (p0.Y - 0.4 + TOP) / 2, p0.Z),
			Color = TRESTLE,
			Material = Enum.Material.Wood,
		})
		Builder.structural(trestle, 1, true, 70)
	end
	-- coaster train parked on the first section
	for i = 0, 3 do
		local p = trackPoint(1) + Vector3.new(-i * 3.6, 1.6, 0)
		local car = Builder.block(model:FindFirstChild("CoasterSection") :: Model, "Car", p, Vector3.new(3.2, 2, 3.4), LIGHTS[(i % #LIGHTS) + 1], Enum.Material.SmoothPlastic)
		Builder.structural(car, 2, false, 60)
	end
end

local function circusTent(model: Model)
	local c = Vector3.new(52, TOP, -22)
	local tent = Builder.building(model, "CircusTent")
	local radius = 16
	for i = 0, 15 do
		if i == 8 or i == 7 then
			continue -- entrance facing west
		end
		local a = i / 16 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * radius, 4, math.sin(a) * radius)
		local panel = Builder.part(tent, {
			Name = "TentWall",
			Size = Vector3.new(6.4, 8, 0.6),
			CFrame = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z)),
			Color = if i % 2 == 0 then RED else WHITE,
			Material = Enum.Material.Fabric,
		})
		Builder.structural(panel, 1, true, 35)
	end
	local pole = Builder.cylinder(tent, "CenterPole", c + Vector3.new(0, 11, 0), 22, 1.4, PILING, Enum.Material.Wood)
	Builder.structural(pole, 1, true, 90)
	local tiers = { { 17.5, 2, 9 }, { 14, 3, 11.5 }, { 10, 3, 14.5 }, { 6.5, 3, 17.5 }, { 3, 3, 20.5 } }
	for i, t in tiers do
		local roof = Builder.cylinder(tent, "TentRoof", c + Vector3.new(0, t[3], 0), t[2], t[1] * 2, if i % 2 == 0 then WHITE else RED, Enum.Material.Fabric)
		Builder.structural(roof, 2, false, 35)
	end
	for _, o in { Vector3.new(0, 24, 0), Vector3.new(12, 12, 0), Vector3.new(-12, 12, 0) } do
		local flagPole = Builder.block(tent, "FlagPole", c + o + Vector3.new(0, 2, 0), Vector3.new(0.4, 4, 0.4), WHITE, Enum.Material.Metal)
		Builder.structural(flagPole, 2, false, 20)
		local flag = Builder.block(tent, "Flag", c + o + Vector3.new(1.2, 3.4, 0), Vector3.new(2, 1.2, 0.15), RED, Enum.Material.Fabric)
		Builder.structural(flag, 2, false, 10)
	end
	-- warm bulbs around the brim
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		Builder.neon(model, c + Vector3.new(math.cos(a) * 17.6, 9.4, math.sin(a) * 17.6), Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(255, 220, 140))
	end
end

local function stall(model: Model, c: Vector3, color: Color3, label: string)
	local s = Builder.building(model, "Stall")
	for _, o in { Vector3.new(4, 0, 2.5), Vector3.new(-4, 0, 2.5), Vector3.new(4, 0, -2.5), Vector3.new(-4, 0, -2.5) } do
		local post = Builder.block(s, "Post", c + o + Vector3.new(0, 3.5, 0), Vector3.new(0.6, 7, 0.6), WHITE, Enum.Material.Wood)
		Builder.structural(post, 1, true, 40)
	end
	local counter = Builder.block(s, "Counter", c + Vector3.new(0, 1.5, -2), Vector3.new(8.6, 3, 1.4), color, Enum.Material.WoodPlanks)
	Builder.structural(counter, 2, false, 50)
	for i = 0, 4 do
		local stripe = Builder.block(s, "Awning", c + Vector3.new(-3.6 + i * 1.8, 7.3, 0), Vector3.new(1.8, 0.5, 6.4), if i % 2 == 0 then color else WHITE, Enum.Material.Fabric)
		Builder.structural(stripe, 2, false, 25)
	end
	local sign = Builder.block(s, "Sign", c + Vector3.new(0, 8.8, -3.1), Vector3.new(7, 2, 0.3), Color3.fromRGB(40, 30, 50), Enum.Material.SmoothPlastic)
	Builder.structural(sign, 2, false, 20)
	Builder.sign(sign, Enum.NormalId.Front, label, color:Lerp(Color3.new(1, 1, 1), 0.3))
end

local function arcade(model: Model, c: Vector3, color: Color3)
	local a = Builder.building(model, "ArcadeCabinet")
	local body = Builder.block(a, "Cabinet", c + Vector3.new(0, 2.5, 0), Vector3.new(2.6, 5, 2.2), color, Enum.Material.SmoothPlastic)
	Builder.structural(body, 1, true, 60)
	local screen = Builder.block(a, "Screen", c + Vector3.new(0, 3.4, -1.15), Vector3.new(2, 1.6, 0.1), Color3.fromRGB(120, 255, 200), Enum.Material.Neon)
	Builder.structural(screen, 2, false, 15)
end

function StarlightBoardwalk.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "StarlightBoardwalk"
	model.Parent = parent

	pier(model)
	ferrisWheel(model)
	coaster(model)
	circusTent(model)

	local y = TOP
	stall(model, Vector3.new(-22, y, -38), LIGHTS[1], "COTTON CANDY")
	stall(model, Vector3.new(-6, y, -38), LIGHTS[2], "CORN DOGS")
	stall(model, Vector3.new(10, y, -38), LIGHTS[3], "RING TOSS")
	stall(model, Vector3.new(-22, y, -8), LIGHTS[4], "SODA POP")
	stall(model, Vector3.new(-6, y, -8), LIGHTS[5], "PRIZES")
	for i = 0, 4 do
		arcade(model, Vector3.new(16 + i * 3.2, y, -10), LIGHTS[(i % #LIGHTS) + 1])
	end

	-- entrance arch at the south edge
	local arch = Builder.building(model, "EntranceArch")
	for _, x in { -40, -22 } do
		local post = Builder.block(arch, "ArchPost", Vector3.new(x, y + 6, -46), Vector3.new(1.6, 12, 1.6), Color3.fromRGB(255, 120, 160), Enum.Material.SmoothPlastic)
		Builder.structural(post, 1, true, 60)
	end
	local board = Builder.block(arch, "ArchSign", Vector3.new(-31, y + 13.5, -46), Vector3.new(22, 4, 1), Color3.fromRGB(40, 30, 80), Enum.Material.SmoothPlastic)
	Builder.structural(board, 2, false, 60)
	Builder.sign(board, Enum.NormalId.Front, "STARLIGHT BOARDWALK", Color3.fromRGB(255, 210, 90))
	Builder.sign(board, Enum.NormalId.Back, "STARLIGHT BOARDWALK", Color3.fromRGB(255, 210, 90))

	-- lamp posts with warm bulbs
	for _, p in { Vector3.new(-30, 0, -24), Vector3.new(0, 0, -24), Vector3.new(30, 0, -24), Vector3.new(-30, 0, 6), Vector3.new(30, 0, 6) } do
		Builder.block(model, "LampPost", p + Vector3.new(0, y + 4, 0), Vector3.new(0.5, 8, 0.5), Color3.fromRGB(40, 40, 50), Enum.Material.Metal)
		Builder.neon(model, p + Vector3.new(0, y + 8.4, 0), Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(255, 220, 140))
	end

	-- little boats bobbing around the pier (decor)
	for _, p in { Vector3.new(-100, 0, -30), Vector3.new(-40, 0, -70), Vector3.new(60, 0, -72), Vector3.new(105, 0, 20), Vector3.new(0, 0, 90) } do
		Builder.block(model, "BoatHull", p + Vector3.new(0, 0.2, 0), Vector3.new(8, 2, 4), Color3.fromRGB(200, 90, 60), Enum.Material.Wood)
		Builder.block(model, "BoatCabin", p + Vector3.new(-1, 2, 0), Vector3.new(3, 2.4, 3), WHITE, Enum.Material.SmoothPlastic)
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-60, 0, -30),
		Vector3.new(-40, 0, 0),
		Vector3.new(-10, 0, -20),
		Vector3.new(20, 0, -30),
		Vector3.new(30, 0, 10),
		Vector3.new(60, 0, 15),
		Vector3.new(75, 0, -45),
		Vector3.new(-70, 0, 55),
		Vector3.new(50, 0, 60),
		Vector3.new(0, 0, 25),
		Vector3.new(-25, 0, 40),
		Vector3.new(75, 0, 40),
	} do
		table.insert(spawns, CFrame.new(p + Vector3.new(0, TOP + 3, 0)))
	end

	return {
		Name = "StarlightBoardwalk",
		DisplayName = "Starlight Boardwalk",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = -3,
		FluidEndY = 12,
		FluidColor = Color3.fromRGB(45, 120, 190),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "THE TIDE",
		Lighting = "Sunset",
		KnockbackMultiplier = 1,
		Center = Vector3.new(0, 0, 10),
		Radius = 110,
	}
end

return StarlightBoardwalk
