--!strict
-- Procedural geometry helpers shared by the lobby and arena builders.
-- Structural parts carry attributes read by DestructionService:
--   Structural (bool), Health (number), Level (int), Support (bool), Volatile (bool)
-- and live inside a "building" Model with a BuildingId attribute.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Builder = {}

Builder.STRUCTURAL_TAG = "Structural"

local created = 0
local buildingCounter = 0

local function maybeYield()
	created += 1
	if created % Config.World.BuildYieldEvery == 0 then
		task.wait()
	end
end

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Reflectance: number?,
	Class: string?, -- "Part" (default), "WedgePart", "TrussPart", "CornerWedgePart"
}

function Builder.part(parent: Instance, props: PartProps): BasePart
	local part: BasePart = Instance.new((props.Class or "Part") :: any)
	part.Name = props.Name or "Part"
	part.Anchored = true
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape and part:IsA("Part") then
		part.Shape = props.Shape
	end
	part.Parent = parent
	maybeYield()
	return part
end

-- Axis-aligned block from a min corner style: centre position + size.
function Builder.block(parent: Instance, name: string, center: Vector3, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return Builder.part(parent, {
		Name = name,
		Size = size,
		CFrame = CFrame.new(center),
		Color = color,
		Material = material,
	})
end

-- Vertical cylinder centred at `center`.
function Builder.cylinder(parent: Instance, name: string, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): BasePart
	return Builder.part(parent, {
		Name = name,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Shape = Enum.PartType.Cylinder,
	})
end

-- Ramp rising along +Z of the given cframe orientation.
function Builder.ramp(parent: Instance, name: string, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	return Builder.part(parent, {
		Name = name,
		Class = "WedgePart",
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material,
	})
end

function Builder.building(parent: Instance, name: string): Model
	buildingCounter += 1
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("BuildingId", buildingCounter)
	model.Parent = parent
	return model
end

function Builder.healthFor(material: Enum.Material): number
	return Config.Destruction.MaterialHealth[material.Name] or Config.Destruction.DefaultHealth
end

-- Mark a part as destructible structure.
function Builder.structural(part: BasePart, level: number, isSupport: boolean?, healthOverride: number?): BasePart
	-- performance: structure never needs Touched events (pads re-enable it), and small
	-- pieces don't cast shadows (fewer shadow-map updates when things move or break)
	part.CanTouch = false
	local s = part.Size
	if s.X * s.Y * s.Z < Config.Performance.ShadowMinVolume then
		part.CastShadow = false
	end
	part:SetAttribute("Structural", true)
	part:SetAttribute("Level", level)
	part:SetAttribute("Support", isSupport == true)
	part:SetAttribute("Health", healthOverride or Builder.healthFor(part.Material))
	CollectionService:AddTag(part, Builder.STRUCTURAL_TAG)
	return part
end

-- `model` sits on `base` (rooftop clutter, a pavilion on a tower): when the base building
-- collapses, DestructionService drops everything resting on it instead of leaving it
-- floating.
function Builder.restsOn(model: Instance, base: Instance)
	local id = base:GetAttribute("BuildingId")
	if id ~= nil then
		model:SetAttribute("RestsOn", id)
	end
end

-- Text sign on a part face.
function Builder.sign(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, strokeColor: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = strokeColor or Color3.fromRGB(25, 25, 35)
	stroke.Parent = label
end

local PALM_TRUNK = Color3.fromRGB(150, 100, 55)
local PALM_LEAF = Color3.fromRGB(60, 190, 70)

-- Destructible voxel palm tree.
function Builder.palm(parent: Instance, base: Vector3, height: number?)
	local h = height or 14
	local tree = Builder.building(parent, "Palm")
	local segments = 3
	local segH = h / segments
	for i = 1, segments do
		local seg = Builder.block(
			tree,
			"Trunk",
			base + Vector3.new((i - 1) * 0.4, segH * (i - 0.5), 0),
			Vector3.new(1.6, segH, 1.6),
			PALM_TRUNK,
			Enum.Material.Wood
		)
		Builder.structural(seg, i, true, 40)
	end
	local top = base + Vector3.new(segments * 0.4, h, 0)
	for _, offset in { Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3) } do
		local leaf = Builder.block(tree, "Leaf", top + offset + Vector3.new(0, -0.6, 0), Vector3.new(
			if offset.X ~= 0 then 6 else 2.5,
			1,
			if offset.Z ~= 0 then 6 else 2.5
		), PALM_LEAF, Enum.Material.Grass)
		Builder.structural(leaf, segments + 1, false, 20)
	end
	local crown = Builder.block(tree, "Crown", top + Vector3.new(0, 0.5, 0), Vector3.new(3, 2, 3), PALM_LEAF, Enum.Material.Grass)
	Builder.structural(crown, segments + 1, false, 20)
end

-- Destructible crate stack.
function Builder.crates(parent: Instance, base: Vector3, count: number)
	local stack = Builder.building(parent, "Crates")
	for i = 1, count do
		local crate = Builder.block(
			stack,
			"Crate",
			base + Vector3.new((i % 2) * 4.2, 2 + math.floor((i - 1) / 2) * 4, 0),
			Vector3.new(4, 4, 4),
			Color3.fromRGB(170, 120, 70),
			Enum.Material.WoodPlanks
		)
		Builder.structural(crate, 1 + math.floor((i - 1) / 2), true, 50)
	end
end

-- Simple lattice tower (four TrussPart legs, climbable) with a platform on top.
-- Returns the top Y of the platform.
function Builder.latticeTower(parent: Instance, building: Model, base: Vector3, height: number, width: number, color: Color3, level: number?): number
	local lvl = level or 1
	local half = width / 2 - 1
	for _, corner in { Vector3.new(half, 0, half), Vector3.new(-half, 0, half), Vector3.new(half, 0, -half), Vector3.new(-half, 0, -half) } do
		local leg = Builder.part(building, {
			Name = "TrussLeg",
			Class = "TrussPart",
			Size = Vector3.new(2, height, 2),
			CFrame = CFrame.new(base + corner + Vector3.new(0, height / 2, 0)),
			Color = color,
			Material = Enum.Material.Metal,
		})
		Builder.structural(leg, lvl, true)
	end
	local cross = 0
	local y = 8
	while y < height - 2 do
		cross += 1
		local beam = Builder.block(building, "CrossBeam", base + Vector3.new(0, y, half), Vector3.new(width, 1, 1), color, Enum.Material.Metal)
		Builder.structural(beam, lvl, false)
		local beam2 = Builder.block(building, "CrossBeam", base + Vector3.new(0, y, -half), Vector3.new(width, 1, 1), color, Enum.Material.Metal)
		Builder.structural(beam2, lvl, false)
		y += 10
	end
	return base.Y + height
end

export type HighriseStyle = {
	SlabColor: Color3,
	SlabMaterial: Enum.Material,
	ColumnColor: Color3,
	ColumnMaterial: Enum.Material,
	WallColor: Color3,
	WallMaterial: Enum.Material,
	WallTransparency: number,
	PillarHeight: number?, -- open ground floor of exposed pillars
	OpenSide: string?, -- "East" | "West": side left open for the ladder
	Health: number?, -- per-part health override (reinforced vaults)
	Stairwell: boolean?, -- a ladder shaft in the north-west corner reaches every floor and the roof
	Windows: boolean?, -- upper-floor walls get window gaps (see in, peek out)
}

-- Multi-storey structure whose floors stack on support columns.
-- Level 1 = ground supports; every floor above is one level higher, so
-- knocking out a floor's columns drops everything above it.
-- Returns the building model and the Y of its roof surface.
function Builder.highrise(
	parent: Instance,
	name: string,
	base: Vector3,
	width: number,
	depth: number,
	floors: number,
	floorHeight: number,
	style: HighriseStyle
): (Model, number)
	local model = Builder.building(parent, name)
	local level = 1
	local y = base.Y
	local hx, hz = width / 2, depth / 2
	local floorBelow = base.Y -- top of the floor under the slab being laid (stairwell ladders)

	local function columnGrid(fromY: number, height: number, lvl: number, size: number)
		local xs = { -hx + size / 2, hx - size / 2 }
		local midCount = math.max(0, math.floor(width / 14) - 1)
		for i = 1, midCount do
			table.insert(xs, -hx + width * i / (midCount + 1))
		end
		for _, x in xs do
			for _, z in { -hz + size / 2, hz - size / 2 } do
				local col = Builder.block(
					model,
					"Column",
					Vector3.new(base.X + x, fromY + height / 2, base.Z + z),
					Vector3.new(size, height, size),
					style.ColumnColor,
					style.ColumnMaterial
				)
				Builder.structural(col, lvl, true, style.Health)
			end
		end
	end

	local function slab(atY: number, lvl: number)
		local nx = math.max(1, math.ceil(width / 10))
		local nz = math.max(1, math.ceil(depth / 14))
		local tw, td = width / nx, depth / nz
		for ix = 1, nx do
			for iz = 1, nz do
				if style.Stairwell and ix == 1 and iz == nz and nx > 1 and nz > 1 then
					-- stairwell hole: a climbable truss rises through it from the floor below
					local hx0 = base.X - hx + tw * 0.5
					local hz0 = base.Z - hz + td * (nz - 0.5)
					local shaft = Builder.part(model, {
						Name = "StairLadder",
						Class = "TrussPart",
						Size = Vector3.new(2, atY + 1.5 - floorBelow + 2, 2),
						CFrame = CFrame.new(hx0 - tw / 2 + 1.6, (floorBelow + atY + 1.5 + 2) / 2, hz0),
						Color = Color3.fromRGB(90, 90, 100),
						Material = Enum.Material.Metal,
					})
					Builder.structural(shaft, lvl - 1, false, 60)
					continue
				end
				local tile = Builder.block(
					model,
					"Slab",
					Vector3.new(base.X - hx + tw * (ix - 0.5), atY + 0.75, base.Z - hz + td * (iz - 0.5)),
					Vector3.new(tw, 1.5, td),
					style.SlabColor,
					style.SlabMaterial
				)
				Builder.structural(tile, lvl, false, style.Health)
			end
		end
	end

	local function walls(fromY: number, height: number, lvl: number, groundFloor: boolean)
		local function run(sideName: string, center: Vector3, length: number, alongX: boolean)
			if style.OpenSide == sideName then
				return
			end
			local segs = math.max(1, math.ceil(length / 10))
			local segLen = length / segs
			for i = 1, segs do
				-- leave a doorway in the middle of the ground floor front
				if groundFloor and sideName == "South" and i == math.ceil(segs / 2) then
					continue
				end
				local offset = -length / 2 + segLen * (i - 0.5)
				local pos = center + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
				local h = height
				if style.Windows and not groundFloor and i % 2 == 0 then
					-- a window: the lower half of the wall only (crouch behind it, peek over it)
					h = height * 0.45
					pos -= Vector3.new(0, (height - h) / 2, 0)
				end
				local panel = Builder.part(model, {
					Name = "Wall",
					Size = if alongX then Vector3.new(segLen, h, 0.6) else Vector3.new(0.6, h, segLen),
					CFrame = CFrame.new(pos),
					Color = style.WallColor,
					Material = style.WallMaterial,
					Transparency = style.WallTransparency,
				})
				Builder.structural(panel, lvl, false, style.Health)
			end
		end
		local cy = fromY + height / 2
		run("North", Vector3.new(base.X, cy, base.Z + hz - 0.3), width - 4, true)
		run("South", Vector3.new(base.X, cy, base.Z - hz + 0.3), width - 4, true)
		run("East", Vector3.new(base.X + hx - 0.3, cy, base.Z), depth - 4, false)
		run("West", Vector3.new(base.X - hx + 0.3, cy, base.Z), depth - 4, false)
	end

	if style.PillarHeight then
		columnGrid(y, style.PillarHeight, level, 3)
		y += style.PillarHeight
		level += 1
	end

	local floorTops: { string } = {}
	for floor = 1, floors do
		local floorTop = y
		if y > base.Y then
			slab(y, level)
			floorTop = y + 1.5
		end
		floorBelow = floorTop
		table.insert(floorTops, string.format("%.2f:%d", floorTop, level))
		local wallHeight = floorHeight - 1.5
		columnGrid(floorTop, wallHeight, level, 2)
		walls(floorTop, wallHeight, level, floor == 1)
		y = floorTop + wallHeight
		level += 1
	end
	slab(y, level)
	local roofY = y + 1.5

	if style.OpenSide then
		local sx = if style.OpenSide == "East" then 1 else -1
		local ladder = Builder.part(model, {
			Name = "Ladder",
			Class = "TrussPart",
			Size = Vector3.new(2, roofY - base.Y, 2),
			CFrame = CFrame.new(base.X + sx * (hx + 1), (base.Y + roofY) / 2, base.Z),
			Color = Color3.fromRGB(90, 90, 100),
			Material = Enum.Material.Metal,
		})
		Builder.structural(ladder, 1, false)
	end

	model:SetAttribute("RoofY", roofY)
	-- interior furnishing (World/Details) reads the floor heights and the footprint
	model:SetAttribute("FloorYs", table.concat(floorTops, ","))
	model:SetAttribute("Footprint", Vector3.new(width, 0, depth))
	model:SetAttribute("BaseCenter", base)
	if style.Stairwell then
		model:SetAttribute("Stairwell", true)
	end
	return model, roofY
end

-- Standing on this part hurts and/or slows (quicksand, vents). Read by MatchService.
function Builder.hazard(part: BasePart, damagePerSecond: number, walkSpeed: number?): BasePart
	part:SetAttribute("HazardDPS", damagePerSecond)
	if walkSpeed then
		part:SetAttribute("HazardWalkSpeed", walkSpeed)
	end
	return part
end

-- When this building collapses it tips over toward `direction` instead of slumping
-- (dominoes, billboards that become planks, the Ferris wheel that rolls away).
function Builder.fallDirection(model: Model, direction: Vector3)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 0 then
		model:SetAttribute("FallDirection", flat.Unit)
	end
end

-- Straight or sloped bridge from a to b (deck centre heights), with rails and two
-- support brackets at each end. Returns the building.
function Builder.bridge(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	deckColor: Color3,
	deckMaterial: Enum.Material,
	railColor: Color3,
	supportColor: Color3,
	deckHealth: number?
): Model
	width = math.max(width, Config.World.MinWalkWidth)
	local model = Builder.building(parent, name)
	local span = b - a
	local length = span.Magnitude
	local dir = span.Unit
	local segs = math.max(1, math.ceil(length / 8))
	local segLen = length / segs
	local right = CFrame.lookAt(Vector3.zero, dir).RightVector
	for i = 1, segs do
		local c = a + dir * segLen * (i - 0.5)
		local deck = Builder.part(model, {
			Name = "Deck",
			Size = Vector3.new(width, 1, segLen + 0.05),
			CFrame = CFrame.lookAt(c, c + dir),
			Color = deckColor,
			Material = deckMaterial,
			Transparency = if deckMaterial == Enum.Material.Glass then 0.35 else 0,
		})
		Builder.structural(deck, 2, false, deckHealth)
		for _, side in { -1, 1 } do
			local rp = c + right * side * (width / 2 - 0.2) + Vector3.new(0, 1.8, 0)
			local rail = Builder.part(model, {
				Name = "Rail",
				Size = Vector3.new(0.35, 0.35, segLen),
				CFrame = CFrame.lookAt(rp, rp + dir),
				Color = railColor,
				Material = Enum.Material.Metal, -- not Neon: rails everywhere added up to too much glow
			})
			Builder.structural(rail, 2, false, 20)
		end
	end
	for _, endPoint in { a + dir * 1.5, b - dir * 1.5 } do
		for _, side in { -1, 1 } do
			local p = endPoint + right * side * (width / 2 - 0.6) - Vector3.new(0, 2.5, 0)
			local bracket = Builder.part(model, {
				Name = "Bracket",
				Size = Vector3.new(1.2, 4, 1.2),
				CFrame = CFrame.new(p),
				Color = supportColor,
				Material = Enum.Material.Metal,
			})
			Builder.structural(bracket, 1, true, 90)
		end
	end
	return model
end

-- Glowing sign panel (neon backing + text) on two posts. Falls toward `fallDir`.
function Builder.billboard(
	parent: Instance,
	name: string,
	base: Vector3,
	facing: Vector3,
	width: number,
	height: number,
	lift: number,
	text: string,
	panelColor: Color3,
	textColor: Color3,
	fallDir: Vector3?
): Model
	local model = Builder.building(parent, name)
	local look = CFrame.lookAt(base, base + facing)
	local right = look.RightVector
	for _, side in { -1, 1 } do
		local post = Builder.part(model, {
			Name = "Post",
			Class = "TrussPart",
			Size = Vector3.new(2, lift + height, 2),
			CFrame = CFrame.new(base + right * side * (width / 2 - 1) + Vector3.new(0, (lift + height) / 2, 0) - facing.Unit * 1.5),
			Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal,
		})
		Builder.structural(post, 1, true, 80)
	end
	local panelCf = look * CFrame.new(0, lift + height / 2, 0)
	local panel = Builder.part(model, {
		Name = "Panel",
		Size = Vector3.new(width, height, 1),
		CFrame = panelCf,
		Color = panelColor,
		Material = Enum.Material.Neon,
	})
	Builder.structural(panel, 2, false, 60)
	Builder.sign(panel, Enum.NormalId.Front, text, textColor)
	local frame = Builder.part(model, {
		Name = "Frame",
		Size = Vector3.new(width + 1, height + 1, 0.6),
		CFrame = panelCf * CFrame.new(0, 0, 0.7),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.Metal,
	})
	Builder.structural(frame, 2, false, 60)
	if fallDir then
		Builder.fallDirection(model, fallDir)
	end
	return model
end

-- Water tower: legs (supports) + tank. Topples toward fallDir when its legs go.
function Builder.waterTower(parent: Instance, base: Vector3, legHeight: number, color: Color3, fallDir: Vector3?): Model
	local model = Builder.building(parent, "WaterTower")
	for _, c in { Vector3.new(3, 0, 3), Vector3.new(-3, 0, 3), Vector3.new(3, 0, -3), Vector3.new(-3, 0, -3) } do
		local leg = Builder.block(model, "Leg", base + c + Vector3.new(0, legHeight / 2, 0), Vector3.new(1, legHeight, 1), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
		Builder.structural(leg, 1, true, 70)
	end
	local tank = Builder.cylinder(model, "Tank", base + Vector3.new(0, legHeight + 4, 0), 8, 10, color, Enum.Material.Metal)
	Builder.structural(tank, 2, false, 150)
	local cap = Builder.cylinder(model, "TankCap", base + Vector3.new(0, legHeight + 8.5, 0), 1, 8, color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Metal)
	Builder.structural(cap, 2, false)
	if fallDir then
		Builder.fallDirection(model, fallDir)
	end
	return model
end

-- Standing on this part launches you upward (steam vents, geysers). Read by the client.
function Builder.launchPad(part: BasePart, power: number): BasePart
	part:SetAttribute("LaunchPower", power)
	return part
end

-- The client spins this part around its own axes (radians / second) while it is anchored
-- (clock gears, radar dishes, propellers). Purely visual: keep it non-colliding.
function Builder.spin(part: BasePart, radiansPerSecond: Vector3): BasePart
	part:SetAttribute("Spin", radiansPerSecond)
	part.CanCollide = false
	return part
end

-- When this building's supports fail it lists (rotates `degrees` around a world axis
-- through `pivot`) instead of collapsing; a second failure afterwards collapses it.
function Builder.tilt(model: Model, pivot: Vector3, axis: Vector3, degrees: number)
	model:SetAttribute("TiltPivot", pivot)
	model:SetAttribute("TiltAxis", axis.Unit)
	model:SetAttribute("TiltDegrees", degrees)
end

-- Overhead cover the God's targeting sees through (glass dome panels): the reticle and
-- the disasters land on whatever is under it. Impacts still crack the panels above.
function Builder.canopy(part: BasePart): BasePart
	part:SetAttribute("Canopy", true)
	return part
end

-- A straight flight of stairs (a wedge) from `low` (its foot, on the ground) up to `high`
-- (the top edge, level with the floor it reaches). Destructible, so it can be cut away.
function Builder.stairs(parent: Instance, low: Vector3, high: Vector3, width: number, color: Color3, material: Enum.Material?, level: number?): BasePart
	width = math.max(width, Config.World.MinWalkWidth)
	local rise = math.max(0.5, high.Y - low.Y)
	local flat = Vector3.new(high.X - low.X, 0, high.Z - low.Z)
	local length = math.max(1, flat.Magnitude)
	local mid = Vector3.new((low.X + high.X) / 2, low.Y + rise / 2, (low.Z + high.Z) / 2)
	local wedge = Builder.ramp(parent, "Stairs", CFrame.lookAt(mid, mid - flat), Vector3.new(width, rise, length), color, material)
	Builder.structural(wedge, level or 1, false, 160)
	return wedge
end

export type RoundStyle = {
	WallColor: Color3,
	WallMaterial: Enum.Material,
	WallTransparency: number,
	SlabColor: Color3,
	SlabMaterial: Enum.Material,
	ColumnColor: Color3,
	Trim: Color3?, -- a neon ring at every floor line
	Health: number?,
	Segments: number?, -- wall panels around the ring
}

-- A round multi-storey hall (bio-domes, observatories, rotundas): a disc floor per level on
-- a ring of columns, curved walls of flat panels (a doorway on the south of the ground
-- floor, every other upper panel a window), optional neon floor rings. Furnished by
-- World/Details like any highrise. Returns the building and the Y of its roof surface.
function Builder.roundHall(parent: Instance, name: string, base: Vector3, diameter: number, floors: number, floorHeight: number, style: RoundStyle): (Model, number)
	local model = Builder.building(parent, name)
	local r = diameter / 2
	local segs = style.Segments or 12
	local y = base.Y
	local level = 1
	local floorTops: { string } = {}
	local function disc(atY: number, lvl: number)
		local d = Builder.part(model, {
			Name = "Slab",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.5, diameter, diameter),
			CFrame = CFrame.new(base.X, atY + 0.75, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = style.SlabColor,
			Material = style.SlabMaterial,
		})
		Builder.structural(d, lvl, false, style.Health)
	end
	for floor = 1, floors do
		local top = y
		if y > base.Y then
			disc(y, level)
			top = y + 1.5
		end
		table.insert(floorTops, string.format("%.2f:%d", top, level))
		local h = floorHeight - 1.5
		-- columns just inside the wall
		for i = 0, 5 do
			local a = i * math.pi / 3 + math.pi / 6
			local col = Builder.block(model, "Column", Vector3.new(base.X + math.cos(a) * (r - 2), top + h / 2, base.Z + math.sin(a) * (r - 2)), Vector3.new(1.6, h, 1.6), style.ColumnColor, Enum.Material.Metal)
			Builder.structural(col, level, true, style.Health)
		end
		-- curved wall
		local chord = 2 * r * math.sin(math.pi / segs)
		for i = 0, segs - 1 do
			local a = (i + 0.5) * 2 * math.pi / segs
			local south = math.abs(a - math.pi * 1.5) < math.pi / segs + 0.01
			if south then
				continue -- the doorway (upper floors: out onto a balcony)
			end
			local wh = h
			local cy = top + h / 2
			if floor > 1 and i % 2 == 0 then
				wh = h * 0.45 -- a window: half-height wall to peek over
				cy = top + wh / 2
			end
			local p = Vector3.new(base.X + math.cos(a) * (r - 0.3), cy, base.Z + math.sin(a) * (r - 0.3))
			local wall = Builder.part(model, {
				Name = "Wall",
				Size = Vector3.new(chord + 0.3, wh, 0.6),
				CFrame = CFrame.lookAt(p, Vector3.new(base.X, cy, base.Z)),
				Color = style.WallColor,
				Material = style.WallMaterial,
				Transparency = style.WallTransparency,
			})
			Builder.structural(wall, level, false, style.Health)
		end
		local trim = style.Trim
		if trim and floor > 1 then
			for i = 0, segs - 1 do
				local a = (i + 0.5) * 2 * math.pi / segs
				local p = Vector3.new(base.X + math.cos(a) * (r + 0.1), top - 0.4, base.Z + math.sin(a) * (r + 0.1))
				local band = Builder.part(model, {
					Name = "Neon",
					Size = Vector3.new(chord + 0.4, 0.6, 0.4),
					CFrame = CFrame.lookAt(p, Vector3.new(base.X, p.Y, base.Z)),
					Color = trim,
					Material = Enum.Material.Neon,
					CastShadow = false,
				})
				Builder.structural(band, level, false, 20)
			end
		end
		y = top + h
		level += 1
	end
	disc(y, level)
	local roofY = y + 1.5
	-- a ladder up the inside wall to every floor and the roof
	local ladder = Builder.part(model, {
		Name = "StairLadder",
		Class = "TrussPart",
		Size = Vector3.new(2, roofY - base.Y + 2, 2),
		CFrame = CFrame.new(base.X - r + 2.4, (base.Y + roofY + 2) / 2, base.Z),
		Color = Color3.fromRGB(90, 90, 100),
		Material = Enum.Material.Metal,
	})
	Builder.structural(ladder, 1, false, 60)
	model:SetAttribute("RoofY", roofY)
	model:SetAttribute("FloorYs", table.concat(floorTops, ","))
	-- furniture fits in the square inside the ring
	model:SetAttribute("Footprint", Vector3.new(diameter * 0.68, 0, diameter * 0.68))
	model:SetAttribute("BaseCenter", base)
	local trim = style.Trim
	if trim then
		local band = Builder.part(model, {
			Name = "Neon",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, diameter + 0.8, diameter + 0.8),
			CFrame = CFrame.new(base.X, roofY - 0.5, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = trim,
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		Builder.structural(band, level, false, 20)
	end
	return model, roofY
end

-- A dome cap of flat panels (tiers x segments) sitting on a ring at `center`: glass
-- research domes, observatory domes. Panels belong to `model` at `level`; glass ones are
-- canopy (the God aims through them).
function Builder.domeCap(model: Model, center: Vector3, radius: number, rise: number, color: Color3, material: Enum.Material, transparency: number, level: number, segments: number?, tiers: number?)
	local segs = segments or 10
	local rings = tiers or 3
	local function point(e: number, lon: number): Vector3
		return center + Vector3.new(radius * math.cos(e) * math.cos(lon), rise * math.sin(e), radius * math.cos(e) * math.sin(lon))
	end
	local top = math.rad(78)
	for t = 0, rings - 1 do
		local e0 = t * top / rings
		local e1 = (t + 1) * top / rings
		for i = 0, segs - 1 do
			local l0 = i * 2 * math.pi / segs
			local l1 = (i + 1) * 2 * math.pi / segs
			local lm = (l0 + l1) / 2
			local c = (point(e0, l0) + point(e0, l1) + point(e1, l0) + point(e1, l1)) / 4
			local up = (point(e1, lm) - point(e0, lm)).Unit
			local out = Vector3.new(c.X - center.X, (c.Y - center.Y) * (radius / rise) ^ 2, c.Z - center.Z).Unit
			local width = (point((e0 + e1) / 2, l1) - point((e0 + e1) / 2, l0)).Magnitude
			local height = (point(e1, lm) - point(e0, lm)).Magnitude
			local panel = Builder.part(model, {
				Name = "DomePanel",
				Size = Vector3.new(width + 0.2, height + 0.2, 0.5),
				CFrame = CFrame.lookAt(c, c + out, up),
				Color = color,
				Material = material,
				Transparency = transparency,
				CastShadow = false,
			})
			Builder.structural(panel, level, false, 40)
			if material == Enum.Material.Glass then
				Builder.canopy(panel)
			end
		end
	end
	local capD = radius * 2 * math.cos(top) + 1
	local cap = Builder.part(model, {
		Name = "DomeCap",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, capD, capD),
		CFrame = CFrame.new(center + Vector3.new(0, rise * math.sin(top), 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Transparency = transparency,
		CastShadow = false,
	})
	Builder.structural(cap, level, false, 40)
end

-- A pipe (horizontal or sloped cylinder) from a to b. Destructible at `level`.
function Builder.pipe(parent: Instance, a: Vector3, b: Vector3, diameter: number, color: Color3, level: number?): BasePart
	local p = Builder.part(parent, {
		Name = "Pipe",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new((b - a).Magnitude, diameter, diameter),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		Color = color,
		Material = Enum.Material.Metal,
		CastShadow = false,
	})
	Builder.structural(p, level or 1, false, 60)
	return p
end

-- Decorative neon strip (not destructible).
function Builder.neon(parent: Instance, center: Vector3, size: Vector3, color: Color3): BasePart
	local p = Builder.block(parent, "Neon", center, size, color, Enum.Material.Neon)
	p.CastShadow = false
	return p
end

return Builder
