--!strict
-- Arena 9: Ironclad Armada. Three warships moored in a storm: driving rain, lightning on
-- the horizon, black cliffs and rough grey sea.
--   * The Aircraft Carrier in the middle: four hangar halls under the flight deck
--     (hatch ladders), a four-storey command island with a radar lattice, parked jets and
--     stacked shipping containers.
--   * Two Destroyers alongside, each in two hull sections with a bridge tower or deckhouse,
--     gun turrets, funnels and a yellow cargo crane.
--   * Wooden gangplanks join the ships. Fall in the sea and you are gone.
--   * Set-piece: knock out a destroyer section's bulkheads and it lists over (the deck
--     becomes a ramp toward the water); hit it again and it goes down. The cranes topple
--     across onto the carrier: a new bridge, or a crushing blow for anyone on the deck.
-- Sudden death: hurricane swells rise over the lower decks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Types = require(ReplicatedStorage.Shared.Types)

local HULL = Color3.fromRGB(70, 74, 80)
local HULL_RED = Color3.fromRGB(120, 40, 36)
local DECK = Color3.fromRGB(58, 60, 64)
local STEEL = Color3.fromRGB(110, 116, 122)
local LIGHT_GREY = Color3.fromRGB(150, 156, 160)
local YELLOW = Color3.fromRGB(232, 190, 40)
local WHITE = Color3.fromRGB(230, 230, 225)
local PLANK = Color3.fromRGB(140, 104, 66)
local GLASS = Color3.fromRGB(130, 170, 190)
local ROCK = Color3.fromRGB(46, 48, 52)
local CONTAINERS = { Color3.fromRGB(170, 60, 40), Color3.fromRGB(40, 90, 150), Color3.fromRGB(60, 120, 70), Color3.fromRGB(200, 120, 40), Color3.fromRGB(120, 120, 130) }

local CARRIER_DECK = 16 -- deck slab bottom; top is +1.5
local DESTROYER_DECK = 12
local DESTROYER_X = 70

local IroncladArmada = {}

local function steelStyle(openSide: string?): Builder.HighriseStyle
	return {
		SlabColor = DECK,
		SlabMaterial = Enum.Material.DiamondPlate,
		ColumnColor = STEEL,
		ColumnMaterial = Enum.Material.Metal,
		WallColor = LIGHT_GREY,
		WallMaterial = Enum.Material.Metal,
		WallTransparency = 0,
		OpenSide = openSide,
		Stairwell = true,
		Windows = true,
	}
end

-- One hull section: hull below the waterline, a hall of bulkhead columns (supports),
-- plated sides with portholes, end bulkheads with doorways, and the deck on top with a
-- hatch ladder. Returns the section (a building).
local function hullSection(parent: Instance, name: string, cx: number, cz: number, width: number, length: number, floorY: number, deckY: number): Model
	local section = Builder.building(parent, name)
	local hw, hl = width / 2, length / 2
	-- hull (not destructible; it lists with the section)
	Builder.block(section, "Hull", Vector3.new(cx, (floorY - 12) / 2, cz), Vector3.new(width, floorY + 12, length), HULL, Enum.Material.Metal)
	Builder.block(section, "Waterline", Vector3.new(cx, -1, cz), Vector3.new(width + 0.4, 2.4, length), HULL_RED, Enum.Material.Metal)
	local wallH = deckY - floorY
	-- bulkhead columns
	local xs = { -hw + 1, hw - 1, 0 }
	if width > 30 then
		table.insert(xs, -hw / 2)
		table.insert(xs, hw / 2)
	end
	local z = -hl + 1
	while z <= hl - 1 do
		for _, x in xs do
			local col = Builder.block(section, "Bulkhead", Vector3.new(cx + x, floorY + wallH / 2, cz + z), Vector3.new(1.6, wallH, 1.6), STEEL, Enum.Material.Metal)
			Builder.structural(col, 1, true, 170)
		end
		z += 12
	end
	-- plated sides with portholes (every third panel is a low one you can see over)
	for _, side in { -1, 1 } do
		local segs = math.ceil(length / 10)
		for i = 1, segs do
			local seg = length / segs
			local h = if i % 3 == 0 then wallH * 0.45 else wallH
			local panel = Builder.block(section, "HullPlate", Vector3.new(cx + side * (hw - 0.3), floorY + h / 2, cz - hl + seg * (i - 0.5)), Vector3.new(0.6, h, seg), HULL, Enum.Material.Metal)
			Builder.structural(panel, 1, false, 160)
		end
	end
	-- end bulkheads with a doorway in the middle
	for _, e in { -1, 1 } do
		local segs = math.max(3, math.ceil(width / 8))
		for i = 1, segs do
			if i == math.ceil(segs / 2) then
				continue
			end
			local seg = width / segs
			local panel = Builder.block(section, "EndBulkhead", Vector3.new(cx - hw + seg * (i - 0.5), floorY + wallH / 2, cz + e * (hl - 0.3)), Vector3.new(seg, wallH, 0.6), HULL, Enum.Material.Metal)
			Builder.structural(panel, 1, false, 160)
		end
	end
	-- deck tiles with a hatch near the +Z end
	local nx = math.ceil(width / 10)
	local nz = math.ceil(length / 12)
	local tw, td = width / nx, length / nz
	for ix = 1, nx do
		for iz = 1, nz do
			local p = Vector3.new(cx - hw + tw * (ix - 0.5), deckY + 0.75, cz - hl + td * (iz - 0.5))
			if ix == 1 and iz == nz - 1 then
				local ladder = Builder.part(section, {
					Name = "HatchLadder",
					Class = "TrussPart",
					Size = Vector3.new(2, wallH + 3.5, 2),
					CFrame = CFrame.new(p.X - tw / 2 + 1.6, floorY + (wallH + 3.5) / 2, p.Z),
					Color = YELLOW,
					Material = Enum.Material.Metal,
				})
				Builder.structural(ladder, 1, false, 60)
				continue
			end
			local tile = Builder.block(section, "Deck", p, Vector3.new(tw, 1.5, td), DECK, Enum.Material.DiamondPlate)
			Builder.structural(tile, 2, false, 190)
		end
	end
	return section
end

-- A bow: a wedge of hull under a deck overhang, pointing along `dir` (+1 / -1 on Z).
local function bow(parent: Instance, cx: number, zEdge: number, dir: number, width: number, deckTop: number, length: number)
	local zc = zEdge + dir * length / 2
	local height = deckTop + 12
	Builder.ramp(parent, "Bow", CFrame.new(cx, deckTop - height / 2, zc) * CFrame.Angles(0, if dir > 0 then math.pi else 0, 0), Vector3.new(width, height, length), HULL, Enum.Material.Metal)
	Builder.block(parent, "BowDeck", Vector3.new(cx, deckTop - 0.75, zc - dir * length * 0.15), Vector3.new(width - 2, 1.5, length * 0.7), DECK, Enum.Material.DiamondPlate)
end

local function radar(building: Model, top: Vector3, level: number)
	local mast = Builder.block(building, "RadarMast", top + Vector3.new(0, 2, 0), Vector3.new(1, 4, 1), STEEL, Enum.Material.Metal)
	Builder.structural(mast, level, false, 40)
	local dish = Builder.block(building, "RadarDish", top + Vector3.new(0, 4.4, 0), Vector3.new(9, 2.2, 0.6), LIGHT_GREY, Enum.Material.Metal)
	Builder.spin(dish, Vector3.new(0, 1.2, 0))
	Builder.structural(dish, level, false, 30)
	local beacon = Builder.block(building, "Beacon", top + Vector3.new(0, 6, 0), Vector3.new(0.8, 0.8, 0.8), Color3.fromRGB(255, 50, 50), Enum.Material.Neon)
	Builder.structural(beacon, level, false, 10)
end

local function jet(parent: Instance, p: Vector3, yaw: number)
	local plane = Builder.building(parent, "Jet")
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local function piece(name: string, offset: Vector3, size: Vector3, color: Color3, material: Enum.Material, level: number, support: boolean)
		local part = Builder.part(plane, { Name = name, Size = size, CFrame = cf * CFrame.new(offset), Color = color, Material = material })
		Builder.structural(part, level, support, 80)
	end
	piece("Fuselage", Vector3.new(0, 2, 0), Vector3.new(3, 2.6, 16), LIGHT_GREY, Enum.Material.Metal, 1, true)
	piece("Wing", Vector3.new(0, 1.6, 1), Vector3.new(14, 0.5, 5), STEEL, Enum.Material.Metal, 2, false)
	piece("Tailplane", Vector3.new(0, 2.2, 7), Vector3.new(7, 0.4, 2.4), STEEL, Enum.Material.Metal, 2, false)
	piece("Fin", Vector3.new(0, 4.4, 7), Vector3.new(0.4, 3.6, 2.6), STEEL, Enum.Material.Metal, 2, false)
	piece("Cockpit", Vector3.new(0, 3.5, -3.5), Vector3.new(2, 1.2, 3.6), GLASS, Enum.Material.Glass, 2, false)
	piece("Gear", Vector3.new(0, 0.4, 0), Vector3.new(1, 0.8, 1), Color3.fromRGB(30, 30, 30), Enum.Material.Metal, 1, true)
end

local function containers(parent: Instance, base: Vector3, rows: number, high: number, rng: Random)
	for r = 0, rows - 1 do
		local stack = Builder.building(parent, "Containers")
		for h = 0, high - 1 do
			local box = Builder.block(stack, "Container", base + Vector3.new(r * 6.6, 3 + h * 6.1, 0), Vector3.new(6, 6, 13), CONTAINERS[rng:NextInteger(1, #CONTAINERS)], Enum.Material.CorrodedMetal)
			Builder.structural(box, h + 1, true, 130)
			local rib = Builder.block(stack, "ContainerRib", box.Position + Vector3.new(0, 0, 6.6), Vector3.new(6.2, 6.2, 0.4), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
			Builder.structural(rib, h + 1, false, 20)
		end
	end
end

-- A yellow dockside crane: lattice mast (supports) and a long boom that topples toward
-- `toward` when the mast gives way.
local function crane(parent: Instance, base: Vector3, toward: Vector3)
	local c = Builder.building(parent, "CargoCrane")
	local top = Builder.latticeTower(c, c, base, 30, 5, YELLOW, 1)
	local dir = Vector3.new(toward.X, 0, toward.Z).Unit
	local cab = Builder.block(c, "CraneCab", Vector3.new(base.X, top + 2, base.Z), Vector3.new(6, 4, 6), YELLOW, Enum.Material.Metal)
	Builder.structural(cab, 2, false, 90)
	local boomStart = Vector3.new(base.X, top + 4.5, base.Z) - dir * 6
	local boomEnd = Vector3.new(base.X, top + 4.5, base.Z) + dir * 34
	local boom = Builder.part(c, { Name = "Boom", Size = Vector3.new(2.6, 2.6, (boomEnd - boomStart).Magnitude), CFrame = CFrame.lookAt((boomStart + boomEnd) / 2, boomEnd), Color = YELLOW, Material = Enum.Material.DiamondPlate })
	Builder.structural(boom, 2, false, 120)
	local weight = Builder.block(c, "Counterweight", boomStart - dir * 1 + Vector3.new(0, -1, 0), Vector3.new(5, 4, 5), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	Builder.structural(weight, 2, false, 120)
	local hookLine = Builder.block(c, "HookLine", boomEnd - dir * 2 + Vector3.new(0, -7, 0), Vector3.new(0.3, 12, 0.3), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	hookLine.CanCollide = false
	Builder.structural(hookLine, 2, false, 10)
	Builder.fallDirection(c, dir)
	c:SetAttribute("FallSpeed", 22)
end

local function carrier(model: Model, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Carrier"
	folder.Parent = model
	local width = 50
	for i, cz in { -90, -30, 30, 90 } do
		local section = hullSection(folder, "Hangar" .. i, 0, cz, width, 60, 4, CARRIER_DECK)
		-- flight deck markings (fall with the deck)
		local top = CARRIER_DECK + 1.55
		for k = 0, 2 do
			local dash = Builder.block(section, "CenterLine", Vector3.new(-4, top, cz - 20 + k * 20), Vector3.new(0.8, 0.1, 10), WHITE, Enum.Material.SmoothPlastic)
			dash.CanCollide = false
			Builder.structural(dash, 2, false, 10)
		end
		for _, x in { -width / 2 + 2, width / 2 - 2 } do
			local edge = Builder.block(section, "EdgeLine", Vector3.new(x, top, cz), Vector3.new(0.6, 0.1, 58), YELLOW, Enum.Material.SmoothPlastic)
			edge.CanCollide = false
			Builder.structural(edge, 2, false, 10)
		end
		-- the angled landing-strip line
		local slant = Builder.part(section, { Name = "LandingLine", Size = Vector3.new(0.8, 0.1, 62), CFrame = CFrame.new(-10 + (i - 2.5) * 4, top, cz) * CFrame.Angles(0, math.rad(9), 0), Color = YELLOW, Material = Enum.Material.SmoothPlastic, CanCollide = false })
		Builder.structural(slant, 2, false, 10)
		-- cargo inside the hangar to hide among
		Builder.crates(section, Vector3.new(-14, 4, cz + 8), 4)
		Builder.crates(section, Vector3.new(10, 4, cz - 12), 3)
	end
	bow(folder, 0, 120, 1, width, CARRIER_DECK + 1.5, 26)
	Builder.block(folder, "Stern", Vector3.new(0, (CARRIER_DECK + 1.5 - 12) / 2, -122), Vector3.new(width, CARRIER_DECK + 13.5, 4), HULL, Enum.Material.Metal)

	-- command island on the starboard edge
	local deckTop = CARRIER_DECK + 1.5
	local island, islandRoof = Builder.highrise(folder, "CommandIsland", Vector3.new(18, deckTop, -18), 12, 30, 4, 8, steelStyle("West"))
	local bridgeGlass = Builder.block(island, "BridgeWindows", Vector3.new(18, deckTop + 28, -33.4), Vector3.new(11, 2.4, 0.3), GLASS, Enum.Material.Glass)
	Builder.structural(bridgeGlass, 4, false, 20)
	local hullNo = Builder.block(island, "HullNumber", Vector3.new(24.4, deckTop + 18, -18), Vector3.new(0.3, 6, 10), Color3.fromRGB(80, 84, 90), Enum.Material.Metal)
	Builder.sign(hullNo, Enum.NormalId.Right, "77", WHITE)
	Builder.structural(hullNo, 3, false, 40)
	local lattice = Builder.building(folder, "RadarLattice")
	local latticeTop = Builder.latticeTower(lattice, lattice, Vector3.new(18, islandRoof, -24), 16, 6, LIGHT_GREY, 1)
	radar(lattice, Vector3.new(18, latticeTop, -24), 2)
	local funnel = Builder.building(folder, "Funnel")
	local stack = Builder.block(funnel, "FunnelStack", Vector3.new(18, islandRoof + 5, -8), Vector3.new(8, 10, 8), HULL, Enum.Material.Metal)
	Builder.structural(stack, 1, true, 200)

	for _, j in { { Vector3.new(-12, deckTop, 40), 0.3 }, { Vector3.new(-14, deckTop, 72), 0.3 }, { Vector3.new(4, deckTop, 100), 0 }, { Vector3.new(-10, deckTop, -64), -0.4 }, { Vector3.new(8, deckTop, -96), 0.5 } } do
		jet(folder, j[1], j[2])
	end
	containers(folder, Vector3.new(4, deckTop, 10), 2, 2, rng)
	containers(folder, Vector3.new(-18, deckTop, -30), 2, 3, rng)
	containers(folder, Vector3.new(8, deckTop, 56), 1, 2, rng)
end

local function destroyer(model: Model, side: number, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = if side > 0 then "StarboardDestroyer" else "PortDestroyer"
	folder.Parent = model
	local cx = side * DESTROYER_X
	local width = 24
	local deckTop = DESTROYER_DECK + 1.5
	local inward = if side > 0 then "West" else "East"
	for i, cz in { 42.5, -42.5 } do
		local section = hullSection(folder, (if i == 1 then "Fore" else "Aft") .. "Section", cx, cz, width, 85, 2, DESTROYER_DECK)
		-- lists outward over the keel's outer edge
		Builder.tilt(section, Vector3.new(cx + side * width / 2, 0, cz), Vector3.new(0, 0, 1), -side * 16)
		if i == 1 then
			-- bridge tower and a gun turret on the fore section
			local tower, towerRoof = Builder.highrise(section, "BridgeTower", Vector3.new(cx, deckTop, cz - 8), 14, 16, 4, 8, steelStyle(inward))
			local glass = Builder.block(tower, "BridgeWindows", Vector3.new(cx, deckTop + 28, cz - 16.4), Vector3.new(13, 2.4, 0.3), GLASS, Enum.Material.Glass)
			Builder.structural(glass, 4, false, 20)
			radar(tower, Vector3.new(cx, towerRoof, cz - 8), 6)
			local turret = Builder.building(section, "Turret")
			local ring = Builder.cylinder(turret, "TurretRing", Vector3.new(cx, deckTop + 1, cz + 26), 2, 9, HULL, Enum.Material.Metal)
			Builder.structural(ring, 1, true, 150)
			local house = Builder.block(turret, "TurretHouse", Vector3.new(cx, deckTop + 3.5, cz + 26), Vector3.new(7, 3, 8), LIGHT_GREY, Enum.Material.Metal)
			Builder.structural(house, 2, false, 120)
			for _, o in { -1.2, 1.2 } do
				local barrel = Builder.part(turret, { Name = "Barrel", Size = Vector3.new(0.8, 0.8, 10), CFrame = CFrame.new(cx + o, deckTop + 3.8, cz + 34), Color = STEEL, Material = Enum.Material.Metal })
				Builder.structural(barrel, 2, false, 40)
			end
		else
			-- deckhouse, funnel and the crane on the aft section
			Builder.highrise(section, "Deckhouse", Vector3.new(cx, deckTop, cz + 10), 14, 14, 2, 8, steelStyle(inward))
			local funnel = Builder.building(section, "Funnel")
			local stack = Builder.cylinder(funnel, "FunnelStack", Vector3.new(cx, deckTop + 9, cz - 8), 18, 8, HULL, Enum.Material.Metal)
			Builder.structural(stack, 1, true, 200)
			local band = Builder.cylinder(funnel, "FunnelBand", Vector3.new(cx, deckTop + 16, cz - 8), 2, 8.4, Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
			Builder.structural(band, 2, false, 40)
			crane(section, Vector3.new(cx - side * (width / 2 - 3), deckTop, cz - 26), Vector3.new(-side, 0, 0))
			containers(section, Vector3.new(cx - 4, deckTop, cz + 30), 2, 2, rng)
		end
	end
	bow(folder, cx, 85, 1, width, deckTop, 20)
	Builder.block(folder, "Stern", Vector3.new(cx, (deckTop - 12) / 2, -87), Vector3.new(width, deckTop + 12, 4), HULL, Enum.Material.Metal)
end

function IroncladArmada.build(parent: Instance): Types.MapInfo
	local model = Instance.new("Model")
	model.Name = "IroncladArmada"
	model.Parent = parent
	local rng = Random.new(57)

	carrier(model, rng)
	destroyer(model, 1, rng)
	destroyer(model, -1, rng)

	-- gangplanks between the ships
	local carrierTop = CARRIER_DECK + 1.5
	local destroyerTop = DESTROYER_DECK + 1.5
	for _, side in { -1, 1 } do
		for _, z in { -64, 4, 66 } do
			Builder.bridge(model, "Gangplank", Vector3.new(side * 24, carrierTop + 0.5, z), Vector3.new(side * (DESTROYER_X - 11), destroyerTop + 0.5, z), 5, PLANK, Enum.Material.WoodPlanks, YELLOW, STEEL, 55)
		end
	end

	-- tugboats bobbing alongside (somewhere to land if you are thrown off)
	for _, p in { Vector3.new(-110, 0, -40), Vector3.new(110, 0, 60), Vector3.new(30, 0, 150), Vector3.new(-40, 0, -150) } do
		local tug = Builder.building(model, "Tugboat")
		local hull = Builder.block(tug, "TugHull", p + Vector3.new(0, 0.5, 0), Vector3.new(9, 4, 16), HULL_RED, Enum.Material.Metal)
		Builder.structural(hull, 1, true, 160)
		local cabin = Builder.block(tug, "TugCabin", p + Vector3.new(0, 4.5, 2), Vector3.new(6, 4, 6), WHITE, Enum.Material.Metal)
		Builder.structural(cabin, 2, false, 70)
	end

	-- black cliffs on the west horizon and a distant fleet (decor)
	for i = 1, 14 do
		local z = -300 + i * 42
		local h = rng:NextNumber(70, 140)
		local rock = Builder.block(model, "Cliff", Vector3.new(-250 - rng:NextNumber(0, 40), h / 2 - 20, z), Vector3.new(rng:NextNumber(40, 70), h, 46), ROCK, Enum.Material.Slate)
		rock.CanCollide = false
	end
	for _ = 1, 6 do
		local p = Vector3.new(rng:NextNumber(200, 320), 0, rng:NextNumber(-260, 260))
		local ghost = Builder.block(model, "DistantShip", p + Vector3.new(0, 4, 0), Vector3.new(14, 8, 70), Color3.fromRGB(60, 64, 70), Enum.Material.Metal)
		ghost.CanCollide = false
		local tower = Builder.block(model, "DistantShip", p + Vector3.new(0, 14, 6), Vector3.new(8, 12, 12), Color3.fromRGB(60, 64, 70), Enum.Material.Metal)
		tower.CanCollide = false
	end

	local spawns = {}
	for _, p in {
		Vector3.new(-10, carrierTop + 3, 20),
		Vector3.new(6, carrierTop + 3, -50),
		Vector3.new(-6, carrierTop + 3, 84),
		Vector3.new(0, carrierTop + 3, -110),
		Vector3.new(-14, 7, -30), -- hangar
		Vector3.new(10, 7, 40), -- hangar
		Vector3.new(DESTROYER_X, destroyerTop + 3, 60),
		Vector3.new(DESTROYER_X, destroyerTop + 3, -20),
		Vector3.new(-DESTROYER_X, destroyerTop + 3, 60),
		Vector3.new(-DESTROYER_X, destroyerTop + 3, -20),
		Vector3.new(DESTROYER_X - 4, 5, 10),
		Vector3.new(-DESTROYER_X + 4, 5, -60),
	} do
		table.insert(spawns, CFrame.new(p))
	end

	return {
		Name = "IroncladArmada",
		DisplayName = "Ironclad Armada",
		Model = model,
		SpawnPoints = spawns,
		FluidStartY = 0,
		FluidEndY = 21,
		FluidColor = Color3.fromRGB(46, 70, 86),
		FluidMaterial = Enum.Material.Glass,
		HazardFloorY = nil,
		FluidName = "HURRICANE SWELL",
		Lighting = "Tempest",
		KnockbackMultiplier = 1.15,
		Center = Vector3.new(0, 0, 0),
		Radius = 160,
	}
end

return IroncladArmada
