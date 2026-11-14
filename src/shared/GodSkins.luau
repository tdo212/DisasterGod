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

-- A hand pointing down: palm block, four fingers and a thumb. `curl` bends the fingers
-- inward (a fist); `claw` adds talon tips.
local function hand(model: Model, scale: number, palm: Color3, accent: Color3, material: Enum.Material, curl: number, claw: boolean, trim: Color3?)
	add(model, scale, { Name = "Core", Size = Vector3.new(14, 12, 5), CFrame = CFrame.new(0, 0, 0), Color = palm, Material = material })
	add(model, scale, { Name = "Wrist", Size = Vector3.new(10, 10, 4.5), CFrame = CFrame.new(0, 10, 0), Color = palm, Material = material })
	for i = 0, 3 do
		local x = -5.25 + i * 3.5
		local length = if i == 1 or i == 2 then 11 else 9.5
		local root = CFrame.new(x, -6, 0) * CFrame.Angles(math.rad(-curl), 0, 0)
		add(model, scale, { Name = "Finger", Size = Vector3.new(3, length, 3.2), CFrame = root * CFrame.new(0, -length / 2, 0), Color = palm, Material = material })
		if claw then
			add(model, scale, { Name = "Talon", Size = Vector3.new(1.6, 4, 1.6), CFrame = root * CFrame.new(0, -length - 1.6, 0.4), Color = accent, Material = Enum.Material.Neon })
		end
		if trim then
			add(model, scale, { Name = "Trim", Size = Vector3.new(3.1, 0.6, 3.3), CFrame = root * CFrame.new(0, -length * 0.45, 0), Color = trim, Material = Enum.Material.Neon })
		end
	end
	add(model, scale, { Name = "Thumb", Size = Vector3.new(3.2, 8, 3.2), CFrame = CFrame.new(8.2, -2, 0) * CFrame.Angles(0, 0, math.rad(-35)), Color = palm, Material = material })
end

local BUILDERS: { [string]: (Model, number) -> () } = {
	StormEye = function(model, s)
		add(model, s, { Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * 16, CFrame = CFrame.new(), Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Glass, Transparency = 0.1 })
		add(model, s, { Name = "Iris", Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(0, -4.2, 0), Color = Color3.fromRGB(70, 160, 255), Material = Enum.Material.Neon })
		add(model, s, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.6, CFrame = CFrame.new(0, -6.3, 0), Color = Color3.fromRGB(10, 15, 30) })
		for i = 0, 5 do
			local a = math.rad(i * 60)
			add(model, s, { Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.one * 9, CFrame = CFrame.new(math.cos(a) * 10, 2, math.sin(a) * 10), Color = Color3.fromRGB(120, 130, 160), Transparency = 0.25 })
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
		for _, x in { -3.4, 3.4 } do
			add(model, s, { Name = "Eye", Size = Vector3.new(3.4, 1.4, 1), CFrame = CFrame.new(x, -2, -2.8), Color = Color3.fromRGB(255, 255, 230), Material = Enum.Material.Neon })
		end
		add(model, s, { Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 26, 26), CFrame = CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Neon, Transparency = 0.3 })
		add(model, s, { Name = "HaloHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 22, 22), CFrame = CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Foil, Transparency = 0.85 })
	end,
	-- a thundercloud fist crackling with lightning arcs
	StormSovereign = function(model, s)
		hand(model, s, Color3.fromRGB(70, 80, 105), Color3.fromRGB(150, 210, 255), Enum.Material.Slate, 80, false, Color3.fromRGB(120, 190, 255))
		for i = 0, 6 do
			local a = math.rad(i * 51)
			add(model, s, { Name = "Thundercloud", Shape = Enum.PartType.Ball, Size = Vector3.one * (8 + (i % 3) * 2), CFrame = CFrame.new(math.cos(a) * 9, 9 + (i % 2) * 3, math.sin(a) * 6), Color = Color3.fromRGB(80, 88, 110), Transparency = 0.15 })
		end
		for i, x in { -6, 1, 7 } do
			add(model, s, { Name = "Arc", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(x, -14 - i, 2) * CFrame.Angles(0, 0, math.rad(i * 17 - 30)), Color = Color3.fromRGB(190, 230, 255), Material = Enum.Material.Neon })
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
