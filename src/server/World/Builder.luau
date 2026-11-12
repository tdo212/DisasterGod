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
	part:SetAttribute("Structural", true)
	part:SetAttribute("Level", level)
	part:SetAttribute("Support", isSupport == true)
	part:SetAttribute("Health", healthOverride or Builder.healthFor(part.Material))
	CollectionService:AddTag(part, Builder.STRUCTURAL_TAG)
	return part
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
				Builder.structural(col, lvl, true)
			end
		end
	end

	local function slab(atY: number, lvl: number)
		local nx = math.max(1, math.ceil(width / 10))
		local nz = math.max(1, math.ceil(depth / 14))
		local tw, td = width / nx, depth / nz
		for ix = 1, nx do
			for iz = 1, nz do
				local tile = Builder.block(
					model,
					"Slab",
					Vector3.new(base.X - hx + tw * (ix - 0.5), atY + 0.75, base.Z - hz + td * (iz - 0.5)),
					Vector3.new(tw, 1.5, td),
					style.SlabColor,
					style.SlabMaterial
				)
				Builder.structural(tile, lvl, false)
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
				local panel = Builder.part(model, {
					Name = "Wall",
					Size = if alongX then Vector3.new(segLen, height, 0.6) else Vector3.new(0.6, height, segLen),
					CFrame = CFrame.new(pos),
					Color = style.WallColor,
					Material = style.WallMaterial,
					Transparency = style.WallTransparency,
				})
				Builder.structural(panel, lvl, false)
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

	for floor = 1, floors do
		local floorTop = y
		if y > base.Y then
			slab(y, level)
			floorTop = y + 1.5
		end
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
	return model, roofY
end

return Builder
