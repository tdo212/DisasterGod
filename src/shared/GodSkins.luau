--!strict
-- GodSkins: part-built models for the God's sky avatar (Config.Cosmetics, GodSkin
-- category). Shared so the client can float one over the God's reticle and the lodge can
-- show small display statues. Every model is built around a "Core" part at the origin,
-- hands point their fingers down (-Y) toward the arena.

local GodSkins = {}

type PartSpec = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
}

local function add(model: Model, scale: number, spec: PartSpec): Part
	local p = Instance.new("Part")
	p.Name = spec.Name or "Piece"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if spec.Shape then
		p.Shape = spec.Shape
	end
	p.Size = spec.Size * scale
	p.CFrame = CFrame.new(spec.CFrame.Position * scale) * spec.CFrame.Rotation
	p.Color = spec.Color
	p.Material = spec.Material or Enum.Material.SmoothPlastic
	p.Transparency = spec.Transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A ring of `count` short segments around the Y axis (a hollow band: cuffs, gyroscope
-- rings, halos you can see through).
local function ring(model: Model, scale: number, center: CFrame, radius: number, count: number, thickness: Vector3, color: Color3, material: Enum.Material, name: string?)
	local segment = 2 * math.pi * radius / count * 1.08
	for i = 0, count - 1 do
		local a = i * 2 * math.pi / count
		add(model, scale, {
			Name = name or "Band",
			Size = Vector3.new(segment, thickness.Y, thickness.Z),
			CFrame = center * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, radius),
			Color = color,
			Material = material,
		})
	end
end

-- A crystal shard: a block stood on its corner (orbits around the skin).
local function shard(model: Model, scale: number, pos: Vector3, size: number, color: Color3, tilt: number)
	add(model, scale, {
		Name = "Orbit",
		Size = Vector3.new(size * 0.55, size * 1.4, size * 0.55),
		CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(tilt), math.rad(45), math.rad(20)),
		Color = color,
		Material = Enum.Material.Neon,
	})
end

-- An armoured hand pointing down: layered palm and back plates, jointed fingers with
-- knuckle guards and segment plates, a thumb, cuffed vambrace, an emissive palm core and
-- a back-of-hand energy core in a bezel, and crystal shards orbiting the wrist.
-- `curl` bends the fingers inward (a fist); `claw` adds talon tips.
local function hand(model: Model, scale: number, palm: Color3, accent: Color3, material: Enum.Material, curl: number, claw: boolean, trim: Color3?)
	local glow = trim or accent
	local armor = palm:Lerp(Color3.new(0, 0, 0), 0.22)
	local edge = palm:Lerp(Color3.new(1, 1, 1), 0.18)
	add(model, scale, { Name = "Core", Size = Vector3.new(14, 12, 5), CFrame = CFrame.new(0, 0, 0), Color = palm, Material = material })
	-- back of the hand: two stepped plates (reads as a bevel) and the energy core
	add(model, scale, { Name = "BackPlate", Size = Vector3.new(14.6, 11, 1.2), CFrame = CFrame.new(0, 0.4, 2.8), Color = armor, Material = material })
	add(model, scale, { Name = "BackPlateTop", Size = Vector3.new(11.4, 8.2, 0.9), CFrame = CFrame.new(0, 0.6, 3.6), Color = edge, Material = material })
	add(model, scale, { Name = "CoreBezel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 5.4, 5.4), CFrame = CFrame.new(0, 0.6, 4.1) * CFrame.Angles(0, math.rad(90), 0), Color = accent, Material = Enum.Material.Metal })
	add(model, scale, { Name = "EnergyCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.6, CFrame = CFrame.new(0, 0.6, 4.2), Color = glow, Material = Enum.Material.Neon })
	-- palm side: a recessed plate around the palm gem
	add(model, scale, { Name = "PalmPlate", Size = Vector3.new(11, 9, 0.6), CFrame = CFrame.new(0, 0.4, -2.6), Color = armor, Material = material })
	-- vambrace with two cuffs and a glowing band
	add(model, scale, { Name = "Wrist", Size = Vector3.new(10, 10, 4.5), CFrame = CFrame.new(0, 10, 0), Color = palm, Material = material })
	add(model, scale, { Name = "Vambrace", Size = Vector3.new(11, 8, 5.6), CFrame = CFrame.new(0, 11, 0.2), Color = armor, Material = material })
	for _, y in { 6.6, 15 } do
		add(model, scale, { Name = "Cuff", Size = Vector3.new(12.6, 1.6, 6.8), CFrame = CFrame.new(0, y, 0.2), Color = edge, Material = Enum.Material.Metal })
	end
	add(model, scale, { Name = "CuffGlow", Size = Vector3.new(11.6, 0.7, 6.2), CFrame = CFrame.new(0, 10.8, 0.2), Color = glow, Material = Enum.Material.Neon })
	for i = 0, 3 do
		local x = -5.25 + i * 3.5
		local length = if i == 1 or i == 2 then 11 else 9.5
		-- two jointed segments per finger with a knuckle between: reads as a hand, not a rake
		local root = CFrame.new(x, -6, 0) * CFrame.Angles(math.rad(-curl * 0.6), 0, 0)
		local first = length * 0.55
		add(model, scale, { Name = "Knuckle", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.5, CFrame = root, Color = accent, Material = material })
		-- knuckle guard: a stepped plate over the back of each knuckle
		add(model, scale, { Name = "KnuckleGuard", Size = Vector3.new(3.4, 2.6, 1.2), CFrame = root * CFrame.new(0, 0.2, 1.9), Color = armor, Material = material })
		add(model, scale, { Name = "KnuckleCap", Size = Vector3.new(2.4, 1.8, 0.6), CFrame = root * CFrame.new(0, 0.2, 2.6), Color = edge, Material = Enum.Material.Metal })
		add(model, scale, { Name = "Finger", Size = Vector3.new(3, first, 3.2), CFrame = root * CFrame.new(0, -first / 2, 0), Color = palm, Material = material })
		add(model, scale, { Name = "FingerPlate", Size = Vector3.new(3.2, first * 0.7, 0.8), CFrame = root * CFrame.new(0, -first / 2, 1.7), Color = armor, Material = material })
		local joint = root * CFrame.new(0, -first, 0) * CFrame.Angles(math.rad(-curl * 0.5), 0, 0)
		local second = length - first
		add(model, scale, { Name = "Joint", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.1, CFrame = joint, Color = palm, Material = material })
		add(model, scale, { Name = "Fingertip", Size = Vector3.new(2.7, second, 2.9), CFrame = joint * CFrame.new(0, -second / 2, 0), Color = palm, Material = material })
		add(model, scale, { Name = "TipPlate", Size = Vector3.new(2.9, second * 0.6, 0.7), CFrame = joint * CFrame.new(0, -second / 2, 1.5), Color = edge, Material = material })
		if claw then
			add(model, scale, { Name = "Talon", Size = Vector3.new(1.6, 4, 1.6), CFrame = joint * CFrame.new(0, -second - 1.6, 0.4), Color = accent, Material = Enum.Material.Neon })
			add(model, scale, { Name = "TalonTip", Size = Vector3.new(1, 2.2, 1), CFrame = joint * CFrame.new(0, -second - 4.2, 0.9) * CFrame.Angles(math.rad(18), 0, 0), Color = accent, Material = Enum.Material.Neon })
		end
		if trim then
			add(model, scale, { Name = "Trim", Size = Vector3.new(3.1, 0.6, 3.3), CFrame = root * CFrame.new(0, -first * 0.5, 0), Color = trim, Material = Enum.Material.Neon })
		end
	end
	-- an emissive palm core and crystal shards orbiting the wrist
	add(model, scale, { Name = "PalmGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, CFrame = CFrame.new(0, 0, -2.6), Color = glow, Material = Enum.Material.Neon })
	for i = 0, 5 do
		local a = math.rad(i * 60)
		shard(model, scale, Vector3.new(math.cos(a) * 11.5, 8 + (i % 2) * 2.5, math.sin(a) * 11.5), if i % 2 == 0 then 2.6 else 1.8, glow, i * 30)
	end
	-- thumb: two segments with a joint
	local thumb = CFrame.new(7.6, -1.2, -0.4) * CFrame.Angles(0, 0, math.rad(-35))
	add(model, scale, { Name = "Thumb", Size = Vector3.new(3.2, 5, 3.2), CFrame = thumb, Color = palm, Material = material })
	add(model, scale, { Name = "ThumbPlate", Size = Vector3.new(3.4, 3.4, 0.8), CFrame = thumb * CFrame.new(0, 0, 1.7), Color = armor, Material = material })
	local thumbJoint = thumb * CFrame.new(0, -2.6, 0)
	add(model, scale, { Name = "Joint", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.9, CFrame = thumbJoint, Color = accent, Material = material })
	add(model, scale, { Name = "ThumbTip", Size = Vector3.new(2.7, 3.6, 2.8), CFrame = thumbJoint * CFrame.Angles(0, 0, math.rad(15)) * CFrame.new(0, -1.8, 0), Color = palm, Material = material })
end

local BUILDERS: { [string]: (Model, number) -> () } = {
	StormEye = function(model, s)
		add(model, s, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 16, CFrame = CFrame.new(), Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Glass, Transparency = 0.1 })
		add(model, s, { Name = "Iris", Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(0, -4.2, 0), Color = Color3.fromRGB(70, 160, 255), Material = Enum.Material.Neon })
		add(model, s, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.6, CFrame = CFrame.new(0, -6.3, 0), Color = Color3.fromRGB(10, 15, 30) })
		-- layered iris: a dark limbal ring and a bright inner disc behind the pupil
		add(model, s, { Name = "IrisRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10.4, 10.4), CFrame = CFrame.new(0, -3.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 60, 120), Material = Enum.Material.Metal })
		add(model, s, { Name = "IrisGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7.4, 7.4), CFrame = CFrame.new(0, -5.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 220, 255), Material = Enum.Material.Neon })
		-- a segmented gyroscope band around the eye, tilted, with studs at the quarters
		local tilt = CFrame.Angles(math.rad(18), 0, math.rad(12))
		ring(model, s, tilt, 10.2, 12, Vector3.new(0, 1.1, 0.9), Color3.fromRGB(210, 225, 245), Enum.Material.Metal, "Gyro")
		for i = 0, 3 do
			local a = math.rad(i * 90)
			add(model, s, { Name = "GyroStud", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = tilt * CFrame.new(math.cos(a) * 10.2, 0, math.sin(a) * 10.2), Color = Color3.fromRGB(90, 180, 255), Material = Enum.Material.Neon })
		end
		for i = 0, 5 do
			local a = math.rad(i * 60)
			add(model, s, { Name = "Orbit", Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(math.cos(a) * 10, 2, math.sin(a) * 10), Color = Color3.fromRGB(120, 130, 160), Transparency = 0.25 })
		end
		-- lightning shards circling with the clouds
		for i = 0, 2 do
			local a = math.rad(30 + i * 120)
			shard(model, s, Vector3.new(math.cos(a) * 13, -2 + i, math.sin(a) * 13), 3, Color3.fromRGB(190, 230, 255), i * 40)
		end
	end,
	StoneFist = function(model, s)
		hand(model, s, Color3.fromRGB(140, 130, 120), Color3.fromRGB(90, 85, 80), Enum.Material.Slate, 70, false)
	end,
	MagmaClaw = function(model, s)
		hand(model, s, Color3.fromRGB(55, 40, 38), Color3.fromRGB(255, 110, 30), Enum.Material.Basalt, 15, true, Color3.fromRGB(255, 90, 20))
	end,
	CyberGauntlet = function(model, s)
		hand(model, s, Color3.fromRGB(70, 75, 95), Color3.fromRGB(60, 230, 255), Enum.Material.DiamondPlate, 45, false, Color3.fromRGB(60, 230, 255))
	end,
	CelestialMask = function(model, s)
		add(model, s, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(15, 19, 6), CFrame = CFrame.new(), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Foil })
		local gold = Color3.fromRGB(255, 205, 60)
		local paleGold = Color3.fromRGB(255, 232, 150)
		local deep = Color3.fromRGB(200, 140, 30)
		-- layered face plates: brow, cheeks, nose ridge, chin and a mouth slit
		add(model, s, { Name = "Brow", Size = Vector3.new(12, 2.2, 2), CFrame = CFrame.new(0, 1.2, -2.6) * CFrame.Angles(math.rad(-10), 0, 0), Color = paleGold, Material = Enum.Material.Foil })
		for _, side in { -1, 1 } do
			add(model, s, { Name = "Cheek", Size = Vector3.new(4.4, 5, 1.4), CFrame = CFrame.new(side * 4, -5, -2.2) * CFrame.Angles(0, math.rad(side * 22), math.rad(side * -8)), Color = deep, Material = Enum.Material.Foil })
			add(model, s, { Name = "EyeRim", Size = Vector3.new(4.4, 2.4, 0.8), CFrame = CFrame.new(side * 3.4, -2, -2.75), Color = deep, Material = Enum.Material.Metal })
			add(model, s, { Name = "EarFin", Size = Vector3.new(1, 9, 4), CFrame = CFrame.new(side * 7.6, -0.5, 0) * CFrame.Angles(0, 0, math.rad(side * -12)), Color = paleGold, Material = Enum.Material.Foil })
		end
		add(model, s, { Name = "Nose", Size = Vector3.new(1.6, 4.6, 1.4), CFrame = CFrame.new(0, -3.6, -3.1), Color = paleGold, Material = Enum.Material.Foil })
		add(model, s, { Name = "Chin", Size = Vector3.new(5.6, 2.4, 1.6), CFrame = CFrame.new(0, -8.4, -1.6) * CFrame.Angles(math.rad(20), 0, 0), Color = paleGold, Material = Enum.Material.Foil })
		add(model, s, { Name = "Mouth", Size = Vector3.new(4, 0.5, 0.6), CFrame = CFrame.new(0, -6.5, -2.9), Color = Color3.fromRGB(255, 255, 230), Material = Enum.Material.Neon })
		add(model, s, { Name = "ThirdEye", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = CFrame.new(0, 3.4, -2.6), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon })
		for _, x in { -3.4, 3.4 } do
			add(model, s, { Name = "Eye", Size = Vector3.new(3.4, 1.4, 1), CFrame = CFrame.new(x, -2, -2.8), Color = Color3.fromRGB(255, 255, 230), Material = Enum.Material.Neon })
		end
		-- crown: a band and seven fanned spikes with gem tips
		add(model, s, { Name = "CrownBand", Size = Vector3.new(14, 1.6, 6.4), CFrame = CFrame.new(0, 7.4, 0.2), Color = gold, Material = Enum.Material.Metal })
		for i = -3, 3 do
			local h = 6 - math.abs(i) * 1.1
			local spike = CFrame.new(i * 1.9, 8.2, 0) * CFrame.Angles(0, 0, math.rad(-i * 9)) * CFrame.new(0, h / 2, 0)
			add(model, s, { Name = "CrownSpike", Size = Vector3.new(1.4, h, 1.4), CFrame = spike * CFrame.Angles(0, math.rad(45), 0), Color = paleGold, Material = Enum.Material.Foil })
			add(model, s, { Name = "CrownGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = spike * CFrame.new(0, h / 2 + 0.4, 0), Color = if i == 0 then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(255, 250, 210), Material = Enum.Material.Neon })
		end
		add(model, s, { Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 26, 26), CFrame = CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Neon, Transparency = 0.3 })
		add(model, s, { Name = "HaloHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 22, 22), CFrame = CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Foil, Transparency = 0.85 })
		-- orbiting mask rings: gems circling the face on a tilted path
		for i = 0, 5 do
			local a = math.rad(i * 60)
			add(model, s, { Name = "Orbit", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = CFrame.new(math.cos(a) * 14, math.sin(a) * 3, math.sin(a) * 14), Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Neon })
		end
	end,
	-- day-7 login streak exclusive: a molten-gold hand with a blazing sun halo behind it
	Sunforged = function(model, s)
		hand(model, s, Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 120, 30), Enum.Material.Foil, 25, true, Color3.fromRGB(255, 230, 120))
		add(model, s, { Name = "SunHalo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 30, 30), CFrame = CFrame.new(0, 6, 4) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.Neon, Transparency = 0.35 })
		for i = 0, 7 do
			local a = math.rad(i * 45)
			add(model, s, { Name = "Ray", Size = Vector3.new(1.4, 7, 0.6), CFrame = CFrame.new(math.cos(a) * 18, 6 + math.sin(a) * 18, 4.5) * CFrame.Angles(0, 0, a - math.pi / 2), Color = Color3.fromRGB(255, 160, 40), Material = Enum.Material.Neon })
		end
	end,
	-- a thundercloud fist crackling with lightning arcs
	StormSovereign = function(model, s)
		hand(model, s, Color3.fromRGB(70, 80, 105), Color3.fromRGB(150, 210, 255), Enum.Material.Slate, 80, false, Color3.fromRGB(120, 190, 255))
		for i = 0, 6 do
			local a = math.rad(i * 51)
			add(model, s, { Name = "Orbit", Shape = Enum.PartType.Ball, Size = Vector3.one * (8 + (i % 3) * 2), CFrame = CFrame.new(math.cos(a) * 9, 9 + (i % 2) * 3, math.sin(a) * 6), Color = Color3.fromRGB(80, 88, 110), Transparency = 0.15 })
		end
		for i, x in { -6, 1, 7 } do
			add(model, s, { Name = "Arc", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(x, -14 - i, 2) * CFrame.Angles(0, 0, math.rad(i * 17 - 30)), Color = Color3.fromRGB(190, 230, 255), Material = Enum.Material.Neon })
			-- a second kinked segment so each arc zig-zags like a bolt
			add(model, s, { Name = "Arc", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(x - 1.5, -20 - i, 2) * CFrame.Angles(0, 0, math.rad(30 - i * 17)), Color = Color3.fromRGB(230, 245, 255), Material = Enum.Material.Neon })
		end
		-- a crackling crown of storm shards above the cloud bank
		for i = 0, 4 do
			local a = math.rad(i * 72)
			add(model, s, { Name = "StormSpike", Size = Vector3.new(1, 5, 1), CFrame = CFrame.new(math.cos(a) * 4, 17, math.sin(a) * 3) * CFrame.Angles(math.rad(math.sin(a) * 20), 0, math.rad(-math.cos(a) * 20)), Color = Color3.fromRGB(160, 215, 255), Material = Enum.Material.Neon })
		end
	end,
}

-- Build skin `id` at the origin (unparented). Unknown ids fall back to the Storm Eye.
function GodSkins.build(id: string, scale: number?): Model
	local model = Instance.new("Model")
	model.Name = "GodSkin_" .. id
	local builder = BUILDERS[id] or BUILDERS.StormEye
	builder(model, scale or 1)
	model.PrimaryPart = model:FindFirstChild("Core") :: BasePart?
	return model
end

-- Facing the -Z axis of `cf`: the default orientation in the lodge displays and the sky.
function GodSkins.place(model: Model, cf: CFrame)
	model:PivotTo(cf)
end

return GodSkins
