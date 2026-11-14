--!strict
-- Details: the dressing pass that makes each arena read like its reference art. Runs
-- after a map's builder (MapService): rooftop clutter on the real roofs, set dressing on
-- genuinely clear ground (or decks), signs at the edge facing the middle. Everything is a
-- small destructible building (Builder.structural), so it adds cover and things to smash
-- without changing the layout. Budgets are per map (Config.Details) to keep part counts in
-- check on phones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Builder = require(script.Parent.Builder)

local Details = {}

type Ctx = { Info: Types.MapInfo, Rng: Random, Params: RaycastParams, Overlap: OverlapParams, Lights: number }

local rgb = Color3.fromRGB
local METAL = Enum.Material.Metal
local DARK = rgb(55, 58, 66)

---------------------------------------------------------------------------
-- placement

local function rayDown(ctx: Ctx, x: number, z: number, fromY: number?): RaycastResult?
	local y = fromY or 260
	for _ = 1, 8 do
		local hit = workspace:Raycast(Vector3.new(x, y, z), Vector3.new(0, -420, 0), ctx.Params)
		if not hit or hit.Instance.Name == "Sea" then
			return nil
		end
		if hit.Instance:GetAttribute("Canopy") ~= true then
			return hit
		end
		y = hit.Position.Y - 0.05
	end
	return nil
end

-- `surface`: "Terrain" (non-structural ground) or "Top" (whatever is highest: decks)
local function groundSpot(ctx: Ctx, clearance: Vector3, surface: string?, minR: number?, maxR: number?): Vector3?
	local info = ctx.Info
	for _ = 1, 30 do
		local a = ctx.Rng:NextNumber(0, math.pi * 2)
		local d = ctx.Rng:NextNumber(minR or 12, (maxR or 0.88) * info.Radius)
		local x, z = info.Center.X + math.cos(a) * d, info.Center.Z + math.sin(a) * d
		local hit = rayDown(ctx, x, z)
		if not hit or hit.Normal.Y < 0.8 or hit.Position.Y < info.FluidStartY + 2 then
			continue
		end
		if surface ~= "Top" and hit.Instance:GetAttribute("Structural") == true then
			continue
		end
		local box = CFrame.new(hit.Position + Vector3.new(0, clearance.Y / 2 + 0.3, 0))
		if #workspace:GetPartBoundsInBox(box, clearance, ctx.Overlap) == 0 then
			return hit.Position
		end
	end
	return nil
end

type Roof = { Model: Model, Center: Vector3, Size: Vector3 }

-- Real roofs: building models standing well above the ground, tallest first.
local function roofs(ctx: Ctx): { Roof }
	local list: { Roof } = {}
	for _, m in ctx.Info.Model:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("BuildingId") ~= nil then
			local cf, size = m:GetBoundingBox()
			if size.Y >= 14 and size.X >= 10 and size.Z >= 10 and size.X <= 90 and size.Z <= 90 then
				table.insert(list, { Model = m, Center = cf.Position, Size = size })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Center.Y + a.Size.Y / 2 > b.Center.Y + b.Size.Y / 2
	end)
	return list
end

-- A point on a roof's actual top surface (raycast), inside its footprint.
local function roofSpot(ctx: Ctx, roof: Roof, clearance: Vector3): Vector3?
	local top = roof.Center.Y + roof.Size.Y / 2
	for _ = 1, 8 do
		local x = roof.Center.X + ctx.Rng:NextNumber(-0.32, 0.32) * roof.Size.X
		local z = roof.Center.Z + ctx.Rng:NextNumber(-0.32, 0.32) * roof.Size.Z
		local hit = workspace:Raycast(Vector3.new(x, top + 6, z), Vector3.new(0, -14, 0), ctx.Params)
		if hit and hit.Normal.Y > 0.8 and hit.Instance:IsDescendantOf(roof.Model) and hit.Position.Y > top - 6 then
			local box = CFrame.new(hit.Position + Vector3.new(0, clearance.Y / 2 + 0.3, 0))
			if #workspace:GetPartBoundsInBox(box, clearance, ctx.Overlap) == 0 then
				return hit.Position
			end
		end
	end
	return nil
end

local function yawTo(from: Vector3, to: Vector3): CFrame
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 0.01 then
		return CFrame.identity
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

---------------------------------------------------------------------------
-- prop kit (each returns its building model)

local function piece(model: Model, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, level: number?, props: { [string]: any }?): BasePart
	local p = Builder.part(model, { Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	Builder.structural(p, level or 1, false)
	return p
end

local function cyl(model: Model, name: string, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?, level: number?): BasePart
	-- a vertical cylinder at cf (cylinders run along X, so turn it upright)
	local p = Builder.part(model, { Name = name, Size = Vector3.new(height, diameter, diameter), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material or METAL, Shape = Enum.PartType.Cylinder })
	Builder.structural(p, level or 1, false)
	return p
end

local function light(ctx: Ctx, part: BasePart, color: Color3, range: number)
	if ctx.Lights >= Config.Details.MaxLights then
		return
	end
	ctx.Lights += 1
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.2
	l.Shadows = false
	l.Parent = part
end

local Kit = {}

function Kit.acUnit(ctx: Ctx, at: Vector3, yaw: CFrame): Model
	local m = Builder.building(ctx.Info.Model, "ACUnit")
	local base = CFrame.new(at) * yaw
	piece(m, "Body", base * CFrame.new(0, 1.6, 0), Vector3.new(5, 3.2, 4), rgb(150, 155, 165), METAL)
	for _, x in { -1.2, 1.2 } do
		local fan = cyl(m, "Fan", base * CFrame.new(x, 3.3, 0), 0.3, 2.2, rgb(30, 32, 38))
		Builder.spin(fan, Vector3.new(0, 6, 0))
	end
	piece(m, "Grille", base * CFrame.new(0, 1.6, -2.05), Vector3.new(4.4, 2.4, 0.1), rgb(60, 62, 70), METAL)
	return m
end

function Kit.waterTank(ctx: Ctx, at: Vector3, color: Color3): Model
	local m = Builder.building(ctx.Info.Model, "RoofTank")
	for _, c in { Vector3.new(1.6, 0, 1.6), Vector3.new(-1.6, 0, 1.6), Vector3.new(1.6, 0, -1.6), Vector3.new(-1.6, 0, -1.6) } do
		local leg = piece(m, "Leg", CFrame.new(at + c + Vector3.new(0, 2, 0)), Vector3.new(0.6, 4, 0.6), DARK, METAL)
		leg:SetAttribute("Support", true)
	end
	cyl(m, "Tank", CFrame.new(at + Vector3.new(0, 6.5, 0)), 5, 5.5, color, Enum.Material.Wood, 2)
	local cap = Builder.part(m, { Name = "Cap", Class = "WedgePart", Size = Vector3.new(5.6, 1.6, 2.8), CFrame = CFrame.new(at + Vector3.new(0, 9.8, 1.4)) * CFrame.Angles(0, math.pi, 0), Color = DARK, Material = METAL })
	Builder.structural(cap, 2, false)
	return m
end

function Kit.dish(ctx: Ctx, at: Vector3, yaw: CFrame): Model
	local m = Builder.building(ctx.Info.Model, "Dish")
	local base = CFrame.new(at) * yaw
	piece(m, "Pole", base * CFrame.new(0, 2, 0), Vector3.new(0.6, 4, 0.6), DARK, METAL)
	local dish = cyl(m, "Dish", base * CFrame.new(0, 4.4, 0) * CFrame.Angles(math.rad(50), 0, 0), 0.5, 5, rgb(225, 228, 235), METAL)
	dish.CanCollide = false
	return m
end

-- Truss gantry holding a glowing holo billboard (Neo-Shibuya rooftops).
function Kit.holoBoard(ctx: Ctx, at: Vector3, yaw: CFrame, color: Color3, text: string): Model
	local m = Builder.building(ctx.Info.Model, "HoloBoard")
	local base = CFrame.new(at) * yaw
	for _, x in { -4.5, 4.5 } do
		local post = Builder.part(m, { Name = "Truss", Class = "TrussPart", Size = Vector3.new(1, 14, 1), CFrame = base * CFrame.new(x, 7, 0), Color = rgb(40, 42, 52), Material = METAL })
		Builder.structural(post, 1, true, 70)
	end
	piece(m, "Beam", base * CFrame.new(0, 14.2, 0), Vector3.new(10, 0.8, 0.8), rgb(40, 42, 52), METAL, 2)
	local panel = piece(m, "Holo", base * CFrame.new(0, 10, 0), Vector3.new(8.6, 6, 0.3), color, Enum.Material.Neon, 2, { Transparency = 0.15, CastShadow = false })
	Builder.sign(panel, Enum.NormalId.Front, text, rgb(255, 255, 255), color:Lerp(rgb(0, 0, 0), 0.5))
	Builder.sign(panel, Enum.NormalId.Back, text, rgb(255, 255, 255), color:Lerp(rgb(0, 0, 0), 0.5))
	light(ctx, panel, color, 18)
	return m
end

function Kit.helipad(ctx: Ctx, at: Vector3): Model
	local m = Builder.building(ctx.Info.Model, "Helipad")
	piece(m, "Pad", CFrame.new(at + Vector3.new(0, 0.15, 0)), Vector3.new(9, 0.3, 9), rgb(40, 44, 50), METAL)
	piece(m, "Glow", CFrame.new(at + Vector3.new(0, 0.32, 0)), Vector3.new(6, 0.05, 6), rgb(110, 255, 90), Enum.Material.Neon, 1, { CastShadow = false })
	piece(m, "H", CFrame.new(at + Vector3.new(0, 0.36, 0)), Vector3.new(1, 0.05, 4), rgb(20, 22, 26), METAL)
	return m
end

function Kit.chimney(ctx: Ctx, at: Vector3, height: number): Model
	local m = Builder.building(ctx.Info.Model, "Chimney")
	local h = height
	for i = 1, 3 do
		local seg = piece(m, "Stack", CFrame.new(at + Vector3.new(0, (i - 0.5) * h / 3, 0)), Vector3.new(2.6, h / 3, 2.6), rgb(130, 60, 45), Enum.Material.Brick, i)
		seg:SetAttribute("Support", true)
	end
	piece(m, "Cap", CFrame.new(at + Vector3.new(0, h + 0.4, 0)), Vector3.new(3.2, 0.8, 3.2), rgb(70, 50, 40), METAL, 3)
	return m
end

function Kit.gear(ctx: Ctx, cf: CFrame, diameter: number, spinRate: number): Model
	local m = Builder.building(ctx.Info.Model, "Gear")
	local rim = Builder.part(m, { Name = "Rim", Size = Vector3.new(0.8, diameter, diameter), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = rgb(190, 140, 60), Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder })
	Builder.structural(rim, 1, false)
	Builder.spin(rim, Vector3.new(spinRate, 0, 0))
	for i = 0, 7 do
		local tooth = piece(m, "Tooth", cf * CFrame.Angles(0, 0, i * math.pi / 4) * CFrame.new(0, diameter / 2 + 0.4, 0), Vector3.new(1, 1, 0.9), rgb(170, 120, 50), METAL)
		tooth.CanCollide = false
	end
	return m
end

function Kit.pipe(ctx: Ctx, a: Vector3, b: Vector3, diameter: number, color: Color3): Model
	local m = Builder.building(ctx.Info.Model, "Pipe")
	local len = (b - a).Magnitude
	local p = Builder.part(m, { Name = "Pipe", Size = Vector3.new(len, diameter, diameter), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = METAL, Shape = Enum.PartType.Cylinder })
	Builder.structural(p, 1, false)
	local dir = (b - a).Unit
	for _, e in { a, b } do
		piece(m, "Flange", CFrame.lookAt(e, e + dir), Vector3.new(diameter + 0.5, diameter + 0.5, 0.5), color:Lerp(rgb(0, 0, 0), 0.25), METAL)
	end
	return m
end

function Kit.barrel(ctx: Ctx, at: Vector3, color: Color3, volatile: boolean?): Model
	local m = Builder.building(ctx.Info.Model, "Barrel")
	local b = cyl(m, "Barrel", CFrame.new(at + Vector3.new(0, 1.6, 0)), 3.2, 2.4, color, METAL)
	if volatile then
		b:SetAttribute("Volatile", true)
	end
	return m
end

function Kit.barrier(ctx: Ctx, at: Vector3, yaw: CFrame): Model
	local m = Builder.building(ctx.Info.Model, "Barrier")
	local base = CFrame.new(at) * yaw
	for _, x in { -2.4, 2.4 } do
		piece(m, "Leg", base * CFrame.new(x, 1, 0), Vector3.new(0.4, 2, 0.4), DARK, METAL)
	end
	for i = 0, 4 do
		piece(m, "Stripe", base * CFrame.new(-2.4 + 0.6 + i * 0.95, 2.2, 0), Vector3.new(0.95, 0.9, 0.3), if i % 2 == 0 then rgb(255, 200, 30) else rgb(25, 25, 30), Enum.Material.SmoothPlastic)
	end
	return m
end

function Kit.lamp(ctx: Ctx, at: Vector3, color: Color3, height: number?): Model
	local m = Builder.building(ctx.Info.Model, "Lamp")
	local h = height or 9
	local post = piece(m, "Post", CFrame.new(at + Vector3.new(0, h / 2, 0)), Vector3.new(0.6, h, 0.6), rgb(40, 40, 46), METAL)
	post:SetAttribute("Support", true)
	local bulb = piece(m, "Bulb", CFrame.new(at + Vector3.new(0, h + 0.5, 0)), Vector3.new(1.4, 1.2, 1.4), color, Enum.Material.Neon, 2, { CastShadow = false })
	light(ctx, bulb, color, 16)
	return m
end

-- A sagging row of bulbs between two points (carnival / dock lights).
function Kit.stringLights(ctx: Ctx, a: Vector3, b: Vector3, colors: { Color3 }): Model
	local m = Builder.building(ctx.Info.Model, "Lights")
	local n = math.clamp(math.floor((b - a).Magnitude / 3), 4, 18)
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
		piece(m, "Bulb", CFrame.new(p), Vector3.one * 0.7, colors[i % #colors + 1], Enum.Material.Neon, 1, { Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
	end
	return m
end

function Kit.stall(ctx: Ctx, at: Vector3, yaw: CFrame, a: Color3, b: Color3, label: string?): Model
	local m = Builder.building(ctx.Info.Model, "Stall")
	local base = CFrame.new(at) * yaw
	local counter = piece(m, "Counter", base * CFrame.new(0, 1.6, 0), Vector3.new(7, 3.2, 3), rgb(150, 100, 60), Enum.Material.WoodPlanks)
	counter:SetAttribute("Support", true)
	for _, x in { -3.3, 3.3 } do
		local post = piece(m, "Post", base * CFrame.new(x, 4.2, -1.2), Vector3.new(0.5, 8.4, 0.5), rgb(240, 240, 240), Enum.Material.Wood)
		post:SetAttribute("Support", true)
	end
	for i = 0, 5 do
		piece(m, "Awning", base * CFrame.new(-3.5 + 0.6 + i * 1.16, 8.6, 0) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(1.16, 0.3, 4.4), if i % 2 == 0 then a else b, Enum.Material.Fabric, 2)
	end
	if label then
		local plate = piece(m, "Sign", base * CFrame.new(0, 7.2, -2.3), Vector3.new(6, 1.4, 0.2), a, Enum.Material.SmoothPlastic, 2)
		Builder.sign(plate, Enum.NormalId.Front, label, rgb(255, 255, 255))
	end
	return m
end

function Kit.arcade(ctx: Ctx, at: Vector3, yaw: CFrame, color: Color3): Model
	local m = Builder.building(ctx.Info.Model, "Arcade")
	local base = CFrame.new(at) * yaw
	piece(m, "Cabinet", base * CFrame.new(0, 2.6, 0), Vector3.new(2.6, 5.2, 2.4), color, Enum.Material.SmoothPlastic)
	piece(m, "Screen", base * CFrame.new(0, 3.6, -1.22), Vector3.new(2, 1.6, 0.1), rgb(110, 240, 255), Enum.Material.Neon, 1, { CastShadow = false })
	piece(m, "Marquee", base * CFrame.new(0, 5.4, -0.9), Vector3.new(2.6, 0.7, 0.8), color:Lerp(rgb(255, 255, 255), 0.4), Enum.Material.Neon, 1, { CastShadow = false })
	return m
end

function Kit.umbrella(ctx: Ctx, at: Vector3, a: Color3, b: Color3): Model
	local m = Builder.building(ctx.Info.Model, "Umbrella")
	piece(m, "Pole", CFrame.new(at + Vector3.new(0, 3, 0)), Vector3.new(0.3, 6, 0.3), rgb(240, 240, 240), METAL)
	for i = 0, 3 do
		piece(m, "Canopy", CFrame.new(at + Vector3.new(0, 6, 0)) * CFrame.Angles(0, i * math.pi / 4, 0), Vector3.new(6, 0.25, 1.4), if i % 2 == 0 then a else b, Enum.Material.Fabric)
	end
	piece(m, "Lounger", CFrame.new(at + Vector3.new(2.6, 0.5, 0)), Vector3.new(2, 1, 5), rgb(250, 250, 245), Enum.Material.SmoothPlastic)
	return m
end

function Kit.crane(ctx: Ctx, at: Vector3, yaw: CFrame, height: number): Model
	local m = Builder.building(ctx.Info.Model, "DockCrane")
	local base = CFrame.new(at) * yaw
	for _, x in { -1.6, 1.6 } do
		local leg = Builder.part(m, { Name = "Mast", Class = "TrussPart", Size = Vector3.new(1.2, height, 1.2), CFrame = base * CFrame.new(x, height / 2, 0), Color = rgb(70, 72, 80), Material = METAL })
		Builder.structural(leg, 1, true, 80)
	end
	piece(m, "Cab", base * CFrame.new(0, height + 1.4, 0), Vector3.new(4.4, 2.8, 4), rgb(255, 190, 30), METAL, 2)
	piece(m, "Boom", base * CFrame.new(0, height + 2, -7), Vector3.new(1.2, 1.2, 14), rgb(70, 72, 80), METAL, 2)
	piece(m, "Hook", base * CFrame.new(0, height - 3, -13), Vector3.new(0.3, 9, 0.3), rgb(30, 30, 30), METAL, 2, { CanCollide = false })
	piece(m, "Load", base * CFrame.new(0, height - 8, -13), Vector3.new(3, 3, 3), rgb(170, 120, 70), Enum.Material.WoodPlanks, 2)
	return m
end

function Kit.dock(ctx: Ctx, at: Vector3, yaw: CFrame, length: number): Model
	local m = Builder.building(ctx.Info.Model, "Dock")
	local base = CFrame.new(at) * yaw
	local n = math.floor(length / 4)
	for i = 0, n - 1 do
		piece(m, "Plank", base * CFrame.new(0, 0.4, -2 - i * 4), Vector3.new(7, 0.5, 3.9), rgb(140, 95, 55), Enum.Material.WoodPlanks)
		if i % 2 == 1 then
			for _, x in { -3.2, 3.2 } do
				local pile = piece(m, "Pile", base * CFrame.new(x, -2.5, -2 - i * 4), Vector3.new(0.9, 6, 0.9), rgb(100, 70, 45), Enum.Material.Wood)
				pile:SetAttribute("Support", true)
			end
		end
	end
	return m
end

function Kit.boatStatic(ctx: Ctx, at: Vector3, yaw: CFrame, color: Color3): Model
	local m = Builder.building(ctx.Info.Model, "Boat")
	local base = CFrame.new(at) * yaw
	piece(m, "Hull", base * CFrame.new(0, 0.8, 0), Vector3.new(4, 1.6, 9), color, Enum.Material.SmoothPlastic)
	local bow = Builder.part(m, { Name = "Bow", Class = "WedgePart", Size = Vector3.new(4, 1.6, 3), CFrame = base * CFrame.new(0, 0.8, -6) * CFrame.Angles(0, math.pi, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	Builder.structural(bow, 1, false)
	piece(m, "Cabin", base * CFrame.new(0, 2.6, 1.5), Vector3.new(3, 2, 3), rgb(245, 245, 245), Enum.Material.SmoothPlastic)
	return m
end

function Kit.rock(ctx: Ctx, at: Vector3, size: number, color: Color3, material: Enum.Material?): Model
	local m = Builder.building(ctx.Info.Model, "Rock")
	for i = 1, 3 do
		local s = size * (1 - i * 0.18)
		piece(m, "Rock", CFrame.new(at + Vector3.new(ctx.Rng:NextNumber(-1, 1) * size * 0.3, s / 2 + (i - 1) * size * 0.25, ctx.Rng:NextNumber(-1, 1) * size * 0.3)) * CFrame.Angles(0, ctx.Rng:NextNumber(0, 3), 0), Vector3.new(s * 1.2, s * 0.8, s), color, material or Enum.Material.Slate, i)
	end
	return m
end

function Kit.solarPanel(ctx: Ctx, at: Vector3, yaw: CFrame): Model
	local m = Builder.building(ctx.Info.Model, "Solar")
	local base = CFrame.new(at) * yaw
	piece(m, "Stand", base * CFrame.new(0, 1, 0), Vector3.new(0.4, 2, 0.4), rgb(200, 205, 210), METAL)
	piece(m, "Panel", base * CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(3.6, 0.2, 2.4), rgb(40, 70, 140), Enum.Material.Glass)
	return m
end

function Kit.jet(ctx: Ctx, at: Vector3, yaw: CFrame): Model
	local m = Builder.building(ctx.Info.Model, "Jet")
	local base = CFrame.new(at) * yaw
	local grey = rgb(120, 128, 138)
	piece(m, "Fuselage", base * CFrame.new(0, 1.6, 0), Vector3.new(2.2, 2, 13), grey, METAL)
	local nose = Builder.part(m, { Name = "Nose", Class = "WedgePart", Size = Vector3.new(2.2, 2, 3.4), CFrame = base * CFrame.new(0, 1.6, -8.2) * CFrame.Angles(0, math.pi, 0), Color = grey, Material = METAL })
	Builder.structural(nose, 1, false)
	piece(m, "Canopy", base * CFrame.new(0, 2.9, -4), Vector3.new(1.4, 0.9, 2.6), rgb(60, 90, 120), Enum.Material.Glass)
	piece(m, "Wings", base * CFrame.new(0, 1.3, 1), Vector3.new(11, 0.4, 4.4), grey, METAL)
	piece(m, "Tail", base * CFrame.new(0, 3.4, 5.6), Vector3.new(0.4, 3.4, 2.2), grey, METAL)
	piece(m, "Stabiliser", base * CFrame.new(0, 1.6, 5.8), Vector3.new(5, 0.3, 1.8), grey, METAL)
	return m
end

function Kit.container(ctx: Ctx, at: Vector3, yaw: CFrame, color: Color3, levels: number?): Model
	local m = Builder.building(ctx.Info.Model, "Container")
	local base = CFrame.new(at) * yaw
	for l = 1, levels or 1 do
		local c = piece(m, "Box", base * CFrame.new(0, 2.5 + (l - 1) * 5.1, 0), Vector3.new(5, 5, 11), if l == 2 then color:Lerp(rgb(255, 255, 255), 0.2) else color, Enum.Material.CorrodedMetal, l)
		c:SetAttribute("Support", true)
		for i = -2, 2 do
			piece(m, "Rib", base * CFrame.new(2.55, 2.5 + (l - 1) * 5.1, i * 2.2), Vector3.new(0.15, 4.6, 0.4), color:Lerp(rgb(0, 0, 0), 0.25), METAL, l, { CanCollide = false })
		end
	end
	return m
end

-- Climbable wooden / steel scaffold tower with plank decks (docks between ships).
function Kit.scaffold(ctx: Ctx, at: Vector3, height: number, color: Color3, material: Enum.Material): Model
	local m = Builder.building(ctx.Info.Model, "Scaffold")
	for _, c in { Vector3.new(2.5, 0, 2.5), Vector3.new(-2.5, 0, 2.5), Vector3.new(2.5, 0, -2.5), Vector3.new(-2.5, 0, -2.5) } do
		local leg = Builder.part(m, { Name = "Leg", Class = "TrussPart", Size = Vector3.new(1, height, 1), CFrame = CFrame.new(at + c + Vector3.new(0, height / 2, 0)), Color = color, Material = material })
		Builder.structural(leg, 1, true, 70)
	end
	for y = 6, height, 6 do
		piece(m, "Deck", CFrame.new(at + Vector3.new(0, y, 0)), Vector3.new(6.4, 0.4, 6.4), rgb(150, 105, 60), Enum.Material.WoodPlanks, 2)
		piece(m, "Brace", CFrame.new(at + Vector3.new(0, y - 3, 2.5)) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(7, 0.4, 0.4), color, material, 2, { CanCollide = false })
	end
	return m
end

function Kit.snowCap(ctx: Ctx, roof: Roof)
	local m = Builder.building(ctx.Info.Model, "SnowCap")
	local top = roof.Center.Y + roof.Size.Y / 2
	piece(m, "Snow", CFrame.new(roof.Center.X, top + 0.5, roof.Center.Z), Vector3.new(roof.Size.X * 0.92, 1, roof.Size.Z * 0.92), rgb(245, 250, 255), Enum.Material.Snow)
	for i = 1, 5 do
		local x = roof.Center.X + (i / 6 - 0.5) * roof.Size.X
		local ice = piece(m, "Icicle", CFrame.new(x, top - 1.2, roof.Center.Z - roof.Size.Z / 2 - 0.3), Vector3.new(0.5, ctx.Rng:NextNumber(1.2, 2.6), 0.5), rgb(190, 225, 255), Enum.Material.Ice, 1, { Transparency = 0.2, CanCollide = false })
		ice.CastShadow = false
	end
end

function Kit.columnRuin(ctx: Ctx, at: Vector3, height: number): Model
	local m = Builder.building(ctx.Info.Model, "Column")
	local stone = rgb(214, 180, 128)
	piece(m, "Base", CFrame.new(at + Vector3.new(0, 0.6, 0)), Vector3.new(4, 1.2, 4), stone:Lerp(rgb(0, 0, 0), 0.1), Enum.Material.Sandstone)
	for i = 1, math.max(1, math.floor(height / 3)) do
		local drum = cyl(m, "Drum", CFrame.new(at + Vector3.new(0, 1.2 + (i - 0.5) * 3, 0)) * CFrame.Angles(0, ctx.Rng:NextNumber(-0.1, 0.1), 0), 3, 3, stone, Enum.Material.Sandstone, i)
		drum:SetAttribute("Support", true)
	end
	-- a carved band of glyphs
	for i = 0, 3 do
		piece(m, "Glyph", CFrame.new(at + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, -1.55), Vector3.new(1.4, 0.8, 0.1), rgb(150, 110, 70), Enum.Material.Sandstone, 1, { CanCollide = false })
	end
	return m
end

function Kit.pool(ctx: Ctx, at: Vector3, size: Vector3): Model
	local m = Builder.building(ctx.Info.Model, "Oasis")
	piece(m, "Rim", CFrame.new(at + Vector3.new(0, 0.3, 0)), size + Vector3.new(2, 0.6, 2), rgb(200, 165, 110), Enum.Material.Sandstone)
	piece(m, "Water", CFrame.new(at + Vector3.new(0, 0.62, 0)), size, rgb(60, 160, 200), Enum.Material.Glass, 1, { Transparency = 0.25, CanCollide = false })
	return m
end

function Kit.sign(ctx: Ctx, at: Vector3, yaw: CFrame, text: string, panel: Color3, textColor: Color3, width: number): Model
	local m = Builder.building(ctx.Info.Model, "Sign")
	local base = CFrame.new(at) * yaw
	for _, x in { -width / 2 + 0.6, width / 2 - 0.6 } do
		local post = piece(m, "Post", base * CFrame.new(x, 2.5, 0), Vector3.new(0.8, 5, 0.8), rgb(110, 75, 45), Enum.Material.Wood)
		post:SetAttribute("Support", true)
	end
	local board = piece(m, "Board", base * CFrame.new(0, 6, 0), Vector3.new(width, width * 0.32, 0.6), panel, Enum.Material.SmoothPlastic, 2)
	Builder.sign(board, Enum.NormalId.Front, text, textColor)
	Builder.sign(board, Enum.NormalId.Back, text, textColor)
	piece(m, "Trim", base * CFrame.new(0, 6, 0.05), Vector3.new(width + 0.6, width * 0.32 + 0.6, 0.4), rgb(255, 200, 40), Enum.Material.Neon, 2, { CastShadow = false })
	return m
end

---------------------------------------------------------------------------
-- per-map passes

local function randomYaw(ctx: Ctx): CFrame
	return CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi * 2), 0)
end

-- a sign at the arena edge facing the middle
local function edgeSign(ctx: Ctx, text: string, panel: Color3, textColor: Color3, width: number, surface: string?)
	local at = groundSpot(ctx, Vector3.new(width + 2, 9, 3), surface, ctx.Info.Radius * 0.55, 0.85)
	if at then
		Kit.sign(ctx, at, yawTo(at, ctx.Info.Center), text, panel, textColor, width)
	end
end

local function onRoofs(ctx: Ctx, count: number, clearance: Vector3, fn: (Vector3, Roof) -> ())
	local list = roofs(ctx)
	local placed = 0
	for i = 1, #list * 3 do
		if placed >= count or #list == 0 then
			break
		end
		local roof = list[(i - 1) % #list + 1]
		local at = roofSpot(ctx, roof, clearance)
		if at then
			placed += 1
			fn(at, roof)
		end
	end
end

local function onGround(ctx: Ctx, count: number, clearance: Vector3, surface: string?, fn: (Vector3) -> ())
	for _ = 1, count do
		local at = groundSpot(ctx, clearance, surface)
		if at then
			fn(at)
		end
	end
end

local NEON = { rgb(255, 70, 200), rgb(70, 220, 255), rgb(150, 90, 255), rgb(110, 255, 120) }
local KANJI = { "ネオ渋谷", "ラーメン", "ゲーム", "未来", "電気", "夜市" }

local PASSES: { [string]: (Ctx) -> () } = {
	NeoShibuya = function(ctx)
		-- rooftop gantries with holo boards, AC units with spinning fans, water tanks,
		-- dishes and glowing helipads, like the reference skyline
		local list = roofs(ctx)
		for i, roof in list do
			if i > 6 then
				break
			end
			local at = roofSpot(ctx, roof, Vector3.new(11, 15, 3))
			if at then
				Kit.holoBoard(ctx, at, yawTo(at, ctx.Info.Center), NEON[i % #NEON + 1], KANJI[i % #KANJI + 1])
			end
		end
		onRoofs(ctx, 12, Vector3.new(6, 4, 5), function(at)
			Kit.acUnit(ctx, at, randomYaw(ctx))
		end)
		onRoofs(ctx, 4, Vector3.new(6, 10, 6), function(at)
			Kit.waterTank(ctx, at, rgb(90, 80, 100))
		end)
		onRoofs(ctx, 5, Vector3.new(4, 6, 4), function(at)
			Kit.dish(ctx, at, randomYaw(ctx))
		end)
		onRoofs(ctx, 3, Vector3.new(10, 2, 10), function(at)
			Kit.helipad(ctx, at)
		end)
		onGround(ctx, 8, Vector3.new(3, 10, 3), "Terrain", function(at)
			Kit.lamp(ctx, at, NEON[ctx.Rng:NextInteger(1, #NEON)], 10)
		end)
		onGround(ctx, 6, Vector3.new(6, 3, 3), "Terrain", function(at)
			Kit.barrier(ctx, at, randomYaw(ctx))
		end)
	end,

	ChronoSpire = function(ctx)
		-- chimneys on every works roof, wall gears, copper pipes, lamps and crates
		onRoofs(ctx, 10, Vector3.new(4, 14, 4), function(at)
			Kit.chimney(ctx, at, ctx.Rng:NextNumber(7, 12))
		end)
		for i, roof in roofs(ctx) do
			if i > 6 then
				break
			end
			-- a big gear on a wall face, spinning
			local face = roof.Center + Vector3.new(0, ctx.Rng:NextNumber(-0.2, 0.2) * roof.Size.Y, -roof.Size.Z / 2 - 0.6)
			Kit.gear(ctx, CFrame.new(face), ctx.Rng:NextNumber(5, 9), if i % 2 == 0 then 0.6 else -0.8)
			-- a copper pipe running down the side
			local x = roof.Center.X + roof.Size.X / 2 + 0.8
			Kit.pipe(ctx, Vector3.new(x, roof.Center.Y + roof.Size.Y / 2 - 1, roof.Center.Z), Vector3.new(x, roof.Center.Y - roof.Size.Y / 2 + 1, roof.Center.Z), 1.2, rgb(190, 110, 60))
		end
		onGround(ctx, 10, Vector3.new(3, 9, 3), "Terrain", function(at)
			Kit.lamp(ctx, at, rgb(255, 190, 90), 8)
		end)
		onGround(ctx, 6, Vector3.new(9, 9, 5), "Terrain", function(at)
			Builder.crates(ctx.Info.Model, at, ctx.Rng:NextInteger(2, 4))
		end)
		onGround(ctx, 3, Vector3.new(8, 14, 16), "Terrain", function(at)
			Kit.crane(ctx, at, randomYaw(ctx), 12)
		end)
	end,

	VerdantDome = function(ctx)
		-- solar panels, lab clutter, rocks with moss and fern clumps around the paths
		onGround(ctx, 10, Vector3.new(4, 4, 4), "Terrain", function(at)
			Kit.solarPanel(ctx, at, randomYaw(ctx))
		end)
		onRoofs(ctx, 6, Vector3.new(4, 4, 4), function(at)
			Kit.solarPanel(ctx, at, randomYaw(ctx))
		end)
		onRoofs(ctx, 3, Vector3.new(4, 6, 4), function(at)
			Kit.dish(ctx, at, randomYaw(ctx))
		end)
		onGround(ctx, 10, Vector3.new(7, 6, 7), "Terrain", function(at)
			Kit.rock(ctx, at, ctx.Rng:NextNumber(3, 5), rgb(110, 120, 105), Enum.Material.Slate)
			Builder.palm(ctx.Info.Model, at + Vector3.new(4, 0, 0), ctx.Rng:NextNumber(10, 15))
		end)
	end,

	IroncladArmada = function(ctx)
		-- parked jets, container stacks, scaffolding towers and radar dishes on the decks
		onGround(ctx, 6, Vector3.new(12, 5, 14), "Top", function(at)
			Kit.jet(ctx, at, randomYaw(ctx))
		end)
		local colors = { rgb(200, 70, 50), rgb(60, 120, 190), rgb(70, 150, 80), rgb(230, 160, 40) }
		onGround(ctx, 8, Vector3.new(7, 11, 12), "Top", function(at)
			Kit.container(ctx, at, randomYaw(ctx), colors[ctx.Rng:NextInteger(1, #colors)], ctx.Rng:NextInteger(1, 2))
		end)
		onGround(ctx, 3, Vector3.new(7, 18, 7), "Top", function(at)
			Kit.scaffold(ctx, at, 18, rgb(150, 105, 60), Enum.Material.Wood)
		end)
		onRoofs(ctx, 5, Vector3.new(4, 6, 4), function(at)
			Kit.dish(ctx, at, randomYaw(ctx))
		end)
		onGround(ctx, 6, Vector3.new(3, 9, 3), "Top", function(at)
			Kit.lamp(ctx, at, rgb(255, 230, 170), 7)
		end)
	end,

	SunscorchedMirage = function(ctx)
		-- broken carved columns, oasis pools with palms, rubble
		onGround(ctx, 10, Vector3.new(5, 12, 5), "Terrain", function(at)
			Kit.columnRuin(ctx, at, ctx.Rng:NextNumber(4, 11))
		end)
		onGround(ctx, 4, Vector3.new(14, 4, 14), "Terrain", function(at)
			Kit.pool(ctx, at, Vector3.new(ctx.Rng:NextNumber(6, 10), 0.4, ctx.Rng:NextNumber(6, 10)))
			Builder.palm(ctx.Info.Model, at + Vector3.new(6, 0, 4), 13)
			Builder.palm(ctx.Info.Model, at + Vector3.new(-5, 0, -5), 11)
		end)
		onGround(ctx, 8, Vector3.new(6, 4, 6), "Terrain", function(at)
			Kit.rock(ctx, at, ctx.Rng:NextNumber(2, 4), rgb(210, 175, 120), Enum.Material.Sandstone)
		end)
	end,

	OutpostZero = function(ctx)
		-- snow on every roof with icicles, barrels, barriers, crates, pipe runs, a dock
		for _, roof in roofs(ctx) do
			Kit.snowCap(ctx, roof)
		end
		onGround(ctx, 8, Vector3.new(3, 4, 3), "Terrain", function(at)
			Kit.barrel(ctx, at, if ctx.Rng:NextNumber() < 0.5 then rgb(40, 90, 170) else rgb(190, 110, 40))
		end)
		onGround(ctx, 6, Vector3.new(6, 3, 3), "Terrain", function(at)
			Kit.barrier(ctx, at, randomYaw(ctx))
		end)
		onGround(ctx, 5, Vector3.new(9, 9, 5), "Terrain", function(at)
			Builder.crates(ctx.Info.Model, at, ctx.Rng:NextInteger(1, 3))
		end)
		onGround(ctx, 3, Vector3.new(14, 4, 4), "Terrain", function(at)
			local yaw = randomYaw(ctx)
			Kit.pipe(ctx, at + yaw:VectorToWorldSpace(Vector3.new(-6, 1.2, 0)), at + yaw:VectorToWorldSpace(Vector3.new(6, 1.2, 0)), 1.6, rgb(150, 155, 165))
		end)
		local edge = groundSpot(ctx, Vector3.new(9, 4, 9), "Terrain", ctx.Info.Radius * 0.7, 0.92)
		if edge then
			Kit.dock(ctx, edge, yawTo(ctx.Info.Center, edge), 20)
		end
	end,

	StarlightBoardwalk = function(ctx)
		-- the WONDER PIER sign, rows of arcade cabinets, striped food stalls, string lights,
		-- benches and bins
		edgeSign(ctx, "WONDER PIER", rgb(60, 40, 120), rgb(255, 220, 80), 16, "Top")
		local cab = { rgb(240, 60, 150), rgb(60, 200, 90), rgb(60, 140, 240), rgb(250, 190, 40), rgb(160, 80, 230) }
		onGround(ctx, 7, Vector3.new(4, 7, 4), "Top", function(at)
			Kit.arcade(ctx, at, yawTo(at, ctx.Info.Center), cab[ctx.Rng:NextInteger(1, #cab)])
		end)
		local stripes = { { rgb(230, 50, 60), rgb(250, 250, 250) }, { rgb(40, 150, 230), rgb(250, 250, 250) }, { rgb(250, 200, 40), rgb(230, 80, 40) }, { rgb(60, 190, 90), rgb(250, 250, 250) } }
		local names = { "POPCORN", "CANDY", "HOT DOGS", "PRIZES", "ICE CREAM" }
		onGround(ctx, 6, Vector3.new(9, 10, 6), "Top", function(at)
			local s = stripes[ctx.Rng:NextInteger(1, #stripes)]
			Kit.stall(ctx, at, yawTo(at, ctx.Info.Center), s[1], s[2], names[ctx.Rng:NextInteger(1, #names)])
		end)
		local lamps: { Vector3 } = {}
		onGround(ctx, 8, Vector3.new(3, 10, 3), "Top", function(at)
			Kit.lamp(ctx, at, rgb(255, 210, 140), 9)
			table.insert(lamps, at + Vector3.new(0, 9.5, 0))
		end)
		local bulbs = { rgb(255, 80, 80), rgb(255, 220, 80), rgb(90, 220, 255), rgb(120, 255, 120), rgb(255, 120, 220) }
		for i = 1, #lamps - 1 do
			if (lamps[i] - lamps[i + 1]).Magnitude < 60 then
				Kit.stringLights(ctx, lamps[i], lamps[i + 1], bulbs)
			end
		end
	end,

	FractureBay = function(ctx)
		-- the FRACTURE BAY sign, harbour cranes, docks with crates and boats, palms and
		-- beach umbrellas
		edgeSign(ctx, "FRACTURE BAY", rgb(40, 110, 200), rgb(255, 255, 255), 13, "Terrain")
		onGround(ctx, 2, Vector3.new(8, 16, 16), "Terrain", function(at)
			Kit.crane(ctx, at, yawTo(at, ctx.Info.Center) * CFrame.Angles(0, math.pi, 0), 13)
		end)
		for _ = 1, 2 do
			local edge = groundSpot(ctx, Vector3.new(9, 4, 9), "Terrain", ctx.Info.Radius * 0.6, 0.9)
			if edge then
				local out = yawTo(ctx.Info.Center, edge)
				Kit.dock(ctx, edge, out, 24)
				Builder.crates(ctx.Info.Model, edge + out:VectorToWorldSpace(Vector3.new(-1, 0.6, -8)), 3)
				Kit.boatStatic(ctx, edge + out:VectorToWorldSpace(Vector3.new(7, -0.6, -18)), out, rgb(220, 60, 60))
			end
		end
		onGround(ctx, 8, Vector3.new(6, 15, 6), "Terrain", function(at)
			Builder.palm(ctx.Info.Model, at, ctx.Rng:NextNumber(11, 16))
		end)
		onGround(ctx, 6, Vector3.new(7, 7, 7), "Terrain", function(at)
			Kit.umbrella(ctx, at, rgb(240, 70, 70), rgb(250, 250, 250))
		end)
	end,

	MagmaCore = function(ctx)
		-- the MAGMA CORE STATION sign, hazard barriers, crates, volatile barrels, cranes
		-- and pipe runs
		edgeSign(ctx, "MAGMA CORE STATION", rgb(40, 40, 46), rgb(255, 200, 40), 15, "Top")
		onGround(ctx, 10, Vector3.new(6, 3, 3), "Top", function(at)
			Kit.barrier(ctx, at, randomYaw(ctx))
		end)
		onGround(ctx, 6, Vector3.new(3, 4, 3), "Top", function(at)
			Kit.barrel(ctx, at, rgb(200, 40, 30), true)
		end)
		onGround(ctx, 6, Vector3.new(9, 9, 5), "Top", function(at)
			Builder.crates(ctx.Info.Model, at, ctx.Rng:NextInteger(2, 3))
		end)
		onGround(ctx, 2, Vector3.new(8, 16, 16), "Top", function(at)
			Kit.crane(ctx, at, randomYaw(ctx), 14)
		end)
		onGround(ctx, 4, Vector3.new(14, 4, 4), "Top", function(at)
			local yaw = randomYaw(ctx)
			Kit.pipe(ctx, at + yaw:VectorToWorldSpace(Vector3.new(-6, 1.4, 0)), at + yaw:VectorToWorldSpace(Vector3.new(6, 1.4, 0)), 1.8, rgb(170, 170, 175))
		end)
	end,
}

function Details.apply(key: string, info: Types.MapInfo)
	local pass = PASSES[key]
	if not pass then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { info.Model }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { info.Model }
	local ctx: Ctx = { Info = info, Rng = Random.new(), Params = params, Overlap = overlap, Lights = 0 }
	local ok, err = pcall(pass, ctx)
	if not ok then
		warn("[Details]", key, err)
	end
end

return Details
