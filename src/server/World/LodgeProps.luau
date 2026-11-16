--!strict
-- LodgeProps: the detailed pieces of the Sky Lodge (World/Lobby.luau lays them out).
--   * showcase plinths: tiered marble-and-gold octagons with a recessed neon ring, corner
--     pillars and a holographic projector
--   * game pass icons: a 2x coin stack, a jewelled crown, a horned energy orb and a
--     winged lightning boot
--   * the gear stall (timber and brass) and its three counter props
--   * architecture: trusses, wainscot, arched windows, the hearth, shields and banners
-- Showcase models are tagged Config.Lodge.DisplayTag; the client's LodgeController bobs
-- and turns them and spins their "Orbit" parts. Decorative lights share the
-- Config.Details.MaxLights budget (LodgeProps.light).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Signage = require(ReplicatedStorage.Shared.Signage)

local LC = Config.Lodge

local LodgeProps = {}

local GOLD = Color3.fromRGB(255, 196, 60)
local GOLD_DARK = Color3.fromRGB(205, 145, 35)
local BRASS = Color3.fromRGB(214, 168, 82)
local MARBLE = Color3.fromRGB(236, 238, 244)
local MARBLE_DARK = Color3.fromRGB(52, 56, 76)
local IRON = Color3.fromRGB(42, 40, 44)
local TIMBER = Color3.fromRGB(122, 80, 48)
local TIMBER_DARK = Color3.fromRGB(84, 55, 34)
local WOOD = Color3.fromRGB(165, 115, 70)
local STONE = Color3.fromRGB(150, 145, 140)
local STONE_LIGHT = Color3.fromRGB(184, 178, 168)
local STONE_DARK = Color3.fromRGB(110, 104, 100)
local PLASTER = Color3.fromRGB(242, 230, 208)
local WARM = Color3.fromRGB(255, 200, 130)

type PieceOpts = {
	Shape: Enum.PartType?,
	Class: string?,
	Collide: boolean?,
	Transparency: number?,
}

-- One part. Decorative by default: no collision, no touch, no query.
local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, opts: PieceOpts?): BasePart
	local o: PieceOpts = opts or {}
	local p = Builder.part(parent, {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material,
		Shape = o.Shape,
		Class = o.Class,
		Transparency = o.Transparency,
		CanCollide = o.Collide == true,
	})
	p.CanTouch = false
	if o.Collide ~= true then
		p.CanQuery = false
	end
	return p
end

local function ball(parent: Instance, name: string, d: number, cf: CFrame, color: Color3, material: Enum.Material): BasePart
	return piece(parent, name, Vector3.one * d, cf, color, material, { Shape = Enum.PartType.Ball })
end

-- Cylinder with its axis along the CFrame's Y.
local function disc(parent: Instance, name: string, height: number, d: number, cf: CFrame, color: Color3, material: Enum.Material, opts: PieceOpts?): BasePart
	local o: PieceOpts = if opts then table.clone(opts) else {}
	o.Shape = Enum.PartType.Cylinder
	return piece(parent, name, Vector3.new(height, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, o)
end

-- Regular octagonal prism, `d` across the flats, axis along cf's Y: the union of four
-- d x (d·tan 22.5°) slabs turned 45° apart is exactly an octagon.
function LodgeProps.octagon(parent: Instance, name: string, cf: CFrame, d: number, h: number, color: Color3, material: Enum.Material, collide: boolean?): BasePart
	local s = d * math.tan(math.rad(22.5))
	local first: BasePart? = nil
	for k = 0, 3 do
		local p = piece(parent, name, Vector3.new(d, h, s), cf * CFrame.Angles(0, math.rad(k * 45), 0), color, material, { Collide = collide })
		first = first or p
	end
	return first :: BasePart
end

-- Regular hexagon tile `d` across the flats, `t` thick, lying in cf's XY plane (normal Z).
local function hexTile(parent: Instance, name: string, cf: CFrame, d: number, t: number, color: Color3, material: Enum.Material, transparency: number?)
	local s = d * math.tan(math.rad(30))
	for k = 0, 2 do
		piece(parent, name, Vector3.new(d, s, t), cf * CFrame.Angles(0, 0, math.rad(k * 60)), color, material, { Transparency = transparency })
	end
end

-- Hollow band of `count` segments around cf's Y axis.
local function band(parent: Instance, name: string, cf: CFrame, radius: number, count: number, height: number, thick: number, color: Color3, material: Enum.Material)
	local segment = 2 * math.pi * radius / count * 1.1
	for i = 0, count - 1 do
		piece(parent, name, Vector3.new(segment, height, thick), cf * CFrame.Angles(0, i * 2 * math.pi / count, 0) * CFrame.new(0, 0, radius), color, material)
	end
end

---------------------------------------------------------------------------
-- lights, animation tags

local lightsUsed = 0

function LodgeProps.resetLights()
	lightsUsed = 0
end

-- A decorative PointLight, within the Config.Details.MaxLights budget (past it the neon
-- still glows, it just doesn't light the room).
function LodgeProps.light(part: BasePart, range: number, brightness: number, color: Color3, flicker: boolean?): PointLight?
	if lightsUsed >= Config.Details.MaxLights then
		return nil
	end
	lightsUsed += 1
	local light = Instance.new("PointLight")
	light.Range = range
	light.Brightness = brightness
	light.Color = color
	light.Shadows = false
	light.Parent = part
	if flicker then
		LodgeProps.flicker(light)
	end
	return light
end

function LodgeProps.flicker(light: Light)
	light:SetAttribute("BaseBrightness", light.Brightness)
	CollectionService:AddTag(light, LC.FlickerTag)
end

-- Mark a model for the client's idle animation: `spin` scales Config.Lodge.DisplaySpin
-- (0 = no turntable), `bob` floats it up and down. Parts named "Orbit" circle the pivot.
function LodgeProps.animate(model: Model, spin: number, bob: boolean)
	model:SetAttribute("Spin", spin)
	model:SetAttribute("Bob", bob)
	CollectionService:AddTag(model, LC.DisplayTag)
end

-- A soft particle aura at `pos` (relative to `part`), in the style of Config.Lodge.Auras.
function LodgeProps.aura(part: BasePart, pos: Vector3, style: { Texture: string, Color: Color3, Size: number, Speed: number }, spread: number)
	local att = Instance.new("Attachment")
	att.Name = "AuraPoint"
	att.WorldPosition = pos
	att.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Texture = style.Texture
	e.Color = ColorSequence.new(style.Color)
	e.LightEmission = 0.6
	e.LightInfluence = 0.2
	e.Rate = LC.AuraRate
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(style.Speed * 0.5, style.Speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, style.Speed * 0.4, 0)
	e.Drag = 1.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, style.Size * spread), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.25, 0.25), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = att
	CollectionService:AddTag(e, LC.AuraTag)
end

---------------------------------------------------------------------------
-- showcase plinth

export type Plinth = {
	Pedestal: BasePart, -- carries the ProximityPrompt and the name tag
	Top: number, -- studs from the floor to the projector lens
}

-- Tiered plinth on the floor point `base`, `d` studs across: dark marble foot, gold band,
-- a recessed neon ring, a white marble drum with a gold lip, four slim corner pillars
-- with glowing finials, and a holographic projector with a faint beam.
function LodgeProps.plinth(parent: Instance, base: Vector3, d: number, accent: Color3, beam: number): Plinth
	local f = Instance.new("Model")
	f.Name = "Plinth"
	f.Parent = parent
	local at = CFrame.new(base)
	LodgeProps.octagon(f, "Foot", at * CFrame.new(0, 0.45, 0), d, 0.9, MARBLE_DARK, Enum.Material.Marble, true)
	LodgeProps.octagon(f, "GoldBand", at * CFrame.new(0, 1.0, 0), d * 0.93, 0.22, GOLD, Enum.Material.Metal, true)
	local ring = disc(f, "EnergyRing", 0.34, d * 0.8, at * CFrame.new(0, 1.28, 0), accent, Enum.Material.Neon)
	local drum = LodgeProps.octagon(f, "Pedestal", at * CFrame.new(0, 1.95, 0), d * 0.84, 1.0, MARBLE, Enum.Material.Marble, true)
	LodgeProps.octagon(f, "Lip", at * CFrame.new(0, 2.56, 0), d * 0.9, 0.22, GOLD, Enum.Material.Metal, true)
	disc(f, "Emitter", 0.32, d * 0.46, at * CFrame.new(0, 2.83, 0), IRON, Enum.Material.Metal)
	disc(f, "Lens", 0.12, d * 0.32, at * CFrame.new(0, 3.04, 0), accent, Enum.Material.Neon)
	if beam > 0 then
		disc(f, "HoloBeam", beam, d * 0.3, at * CFrame.new(0, 3.1 + beam / 2, 0), accent, Enum.Material.Neon, { Transparency = 0.86 })
	end
	local r = d * 0.46
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		local p = at * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
		piece(f, "Pillar", Vector3.new(0.45, 2.4, 0.45), p * CFrame.new(0, 2.1, 0), GOLD_DARK, Enum.Material.Metal)
		ball(f, "Finial", 0.6, p * CFrame.new(0, 3.45, 0), accent, Enum.Material.Neon)
	end
	ring.CastShadow = false
	return { Pedestal = drum, Top = 3.1 }
end

---------------------------------------------------------------------------
-- game pass icons (built around a "Core" part at the origin, then pivoted into place)

local function icon(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

local function finish(m: Model, core: BasePart, at: CFrame, parent: Instance): Model
	core.Name = "Core"
	m.PrimaryPart = core
	-- built around the origin: move it as a whole (a cylinder core keeps its own rotation)
	m:PivotTo(at * core.CFrame)
	m.Parent = parent
	return m
end

-- 2x Coins: a big embossed "2x" coin over a stack of coins, with coins orbiting it.
local function coinIcon(parent: Instance, at: CFrame): Model
	local m = icon("CoinIcon")
	local face = CFrame.Angles(math.rad(90), 0, 0) -- disc axis along Z: the coin faces front/back
	local rim = disc(m, "CoinRim", 0.5, 3.4, face, GOLD_DARK, Enum.Material.Metal)
	disc(m, "CoinFace", 0.64, 2.9, face, GOLD, Enum.Material.Foil)
	-- reeded edge
	for i = 0, 11 do
		local a = math.rad(i * 30)
		piece(m, "Reed", Vector3.new(0.22, 0.42, 0.56), CFrame.new(math.cos(a) * 1.68, math.sin(a) * 1.68, 0) * CFrame.Angles(0, 0, a), GOLD, Enum.Material.Metal)
	end
	local emblem = piece(m, "Emblem", Vector3.new(2.2, 1.6, 0.7), CFrame.new(), GOLD, Enum.Material.Foil, { Transparency = 1 })
	for _, normal in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = normal
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0.6
		gui.Parent = emblem
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		text.TextScaled = true
		text.Text = "2x"
		text.TextColor3 = Color3.fromRGB(255, 240, 190)
		text.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Color = Color3.fromRGB(150, 95, 10)
		stroke.Parent = text
	end
	-- the stack beneath
	for k = 0, 4 do
		disc(m, "StackCoin", 0.3, 1.7, CFrame.new((k % 2) * 0.12 - 0.06, -2.5 + k * 0.32, (k % 3) * 0.08), if k % 2 == 0 then GOLD else GOLD_DARK, Enum.Material.Metal)
	end
	for i = 0, 2 do
		local a = math.rad(i * 120)
		disc(m, "Orbit", 0.18, 0.9, CFrame.new(math.cos(a) * 2.7, 0.4 + i * 0.3, math.sin(a) * 2.7) * CFrame.Angles(math.rad(70), a, 0), GOLD, Enum.Material.Neon)
	end
	return finish(m, rim, at, parent)
end

-- VIP: a jewelled crown, gold band over ermine trim, velvet cap, pearl-tipped points and
-- an orb and cross on top.
local function crownIcon(parent: Instance, at: CFrame): Model
	local m = icon("CrownIcon")
	local core = disc(m, "Ermine", 0.5, 3.5, CFrame.new(0, -0.7, 0), Color3.fromRGB(248, 246, 240), Enum.Material.Fabric)
	ball(m, "Velvet", 2.7, CFrame.new(0, 0.35, 0), Color3.fromRGB(150, 25, 45), Enum.Material.Fabric)
	band(m, "Band", CFrame.new(0, -0.05, 0), 1.55, 10, 0.95, 0.32, GOLD, Enum.Material.Metal)
	local jewels = { Color3.fromRGB(255, 50, 70), Color3.fromRGB(60, 140, 255), Color3.fromRGB(60, 220, 120) }
	for i = 0, 4 do
		local a = math.rad(i * 72)
		local out = CFrame.Angles(0, -a, 0)
		-- a point leaning slightly outward with a pearl tip
		local point = out * CFrame.new(0, 0.95, 1.55) * CFrame.Angles(math.rad(12), 0, 0)
		piece(m, "Point", Vector3.new(0.42, 1.3, 0.42), point * CFrame.Angles(0, math.rad(45), 0), GOLD, Enum.Material.Metal)
		ball(m, "Pearl", 0.42, point * CFrame.new(0, 0.78, 0), Color3.fromRGB(250, 248, 240), Enum.Material.SmoothPlastic)
		-- a jewel between points
		ball(m, "Jewel", 0.42, CFrame.Angles(0, -a - math.rad(36), 0) * CFrame.new(0, -0.05, 1.72), jewels[i % 3 + 1], Enum.Material.Neon)
	end
	ball(m, "Orb", 0.62, CFrame.new(0, 1.85, 0), GOLD, Enum.Material.Metal)
	piece(m, "Cross", Vector3.new(0.18, 0.85, 0.18), CFrame.new(0, 2.5, 0), GOLD, Enum.Material.Metal)
	piece(m, "Cross", Vector3.new(0.55, 0.18, 0.18), CFrame.new(0, 2.6, 0), GOLD, Enum.Material.Metal)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		ball(m, "Orbit", 0.32, CFrame.new(math.cos(a) * 2.4, 0.6, math.sin(a) * 2.4), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	end
	return finish(m, core, at, parent)
end

-- God Priority: a purple energy orb in a glass shell, caged by two gold rings, with
-- curling gold horns and sparks circling.
local function orbIcon(parent: Instance, at: CFrame): Model
	local m = icon("OrbIcon")
	local purple = Color3.fromRGB(170, 90, 255)
	local core = ball(m, "Energy", 2.3, CFrame.new(), purple, Enum.Material.Neon)
	local shell = ball(m, "Shell", 3, CFrame.new(), Color3.fromRGB(210, 180, 255), Enum.Material.Glass)
	shell.Transparency = 0.55
	band(m, "Cage", CFrame.new(), 1.62, 10, 0.26, 0.22, GOLD, Enum.Material.Metal)
	band(m, "Cage", CFrame.Angles(math.rad(90), 0, 0), 1.62, 10, 0.26, 0.22, GOLD, Enum.Material.Metal)
	-- horns: three tapering segments curling up and back in
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * 1.25, 0.9, 0) * CFrame.Angles(0, 0, math.rad(-side * 35))
		local sizes = { 0.7, 0.52, 0.34 }
		for i, w in sizes do
			local len = 1.1 - i * 0.12
			cf = cf * CFrame.new(0, len / 2, 0)
			piece(m, "Horn", Vector3.new(w, len, w), cf, if i == 3 then purple else GOLD, if i == 3 then Enum.Material.Neon else Enum.Material.Foil)
			cf = cf * CFrame.new(0, len / 2, 0) * CFrame.Angles(0, 0, math.rad(side * 28))
		end
	end
	disc(m, "Socket", 0.36, 1.5, CFrame.new(0, -1.62, 0), GOLD, Enum.Material.Metal)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		piece(m, "Orbit", Vector3.new(0.3, 0.7, 0.3), CFrame.new(math.cos(a) * 2.5, -0.3 + i * 0.4, math.sin(a) * 2.5) * CFrame.Angles(0, math.rad(45), math.rad(20)), Color3.fromRGB(225, 190, 255), Enum.Material.Neon)
	end
	return finish(m, core, at, parent)
end

-- Quick Dash: a winged running boot with a neon lightning bolt down the side.
local function bootIcon(parent: Instance, at: CFrame): Model
	local m = icon("BootIcon")
	local cyan = Color3.fromRGB(60, 230, 230)
	local white = Color3.fromRGB(240, 244, 250)
	local core = piece(m, "Foot", Vector3.new(2.2, 0.95, 1.25), CFrame.new(0.1, -0.6, 0), white, Enum.Material.SmoothPlastic)
	piece(m, "Sole", Vector3.new(3.1, 0.36, 1.35), CFrame.new(0.15, -1.22, 0), Color3.fromRGB(40, 42, 52), Enum.Material.SmoothPlastic)
	piece(m, "Toe", Vector3.new(1.25, 0.95, 0.95), CFrame.new(1.65, -0.6, 0) * CFrame.Angles(0, math.rad(90), 0), white, Enum.Material.SmoothPlastic, { Class = "WedgePart" })
	piece(m, "Shaft", Vector3.new(1.25, 1.9, 1.25), CFrame.new(-0.55, 0.55, 0), white, Enum.Material.SmoothPlastic)
	piece(m, "Cuff", Vector3.new(1.5, 0.4, 1.5), CFrame.new(-0.55, 1.6, 0), cyan, Enum.Material.Neon)
	for i = 0, 2 do
		piece(m, "Lace", Vector3.new(0.14, 0.12, 1.0), CFrame.new(0.15 + i * 0.4, -0.1 + i * 0.02, 0), Color3.fromRGB(40, 42, 52), Enum.Material.SmoothPlastic)
	end
	for _, side in { -1, 1 } do
		local z = side * 0.66
		-- lightning bolt down the side
		piece(m, "Bolt", Vector3.new(0.22, 1.0, 0.06), CFrame.new(-0.5, 0.75, z) * CFrame.Angles(0, 0, math.rad(-25)), cyan, Enum.Material.Neon)
		piece(m, "Bolt", Vector3.new(0.75, 0.2, 0.06), CFrame.new(-0.25, 0.25, z), cyan, Enum.Material.Neon)
		piece(m, "Bolt", Vector3.new(0.22, 0.9, 0.06), CFrame.new(0.05, -0.2, z) * CFrame.Angles(0, 0, math.rad(-25)), cyan, Enum.Material.Neon)
		-- three feathers fanned up and back from the ankle
		for i, len in { 2.2, 1.8, 1.35 } do
			local feather = CFrame.new(-0.9, 1.0, side * 0.78) * CFrame.Angles(math.rad(side * -12), 0, math.rad(20 + i * 18)) * CFrame.new(-len / 2, 0, 0)
			piece(m, "Feather", Vector3.new(len, 0.42, 0.1), feather, if i == 2 then cyan else white, if i == 2 then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		end
	end
	for i = 0, 2 do
		piece(m, "Streak", Vector3.new(1.6 - i * 0.3, 0.1, 0.1), CFrame.new(-2.4 - i * 0.2, -0.9 + i * 0.45, 0), cyan, Enum.Material.Neon, { Transparency = 0.3 })
	end
	return finish(m, core, at, parent)
end

local PASS_ICONS: { [string]: (Instance, CFrame) -> Model } = {
	DoubleCoins = coinIcon,
	VIP = crownIcon,
	GodPriority = orbIcon,
	QuickDash = bootIcon,
}

-- The 3D icon for pass `key` at `at` (animated: turntable + bob).
function LodgeProps.passIcon(parent: Instance, key: string, at: CFrame): Model?
	local build = PASS_ICONS[key]
	if not build then
		return nil
	end
	local m = build(parent, at)
	LodgeProps.animate(m, 1, true)
	return m
end

---------------------------------------------------------------------------
-- gear stall props

-- Speed Soda: a can with rims, a label band, a pull tab, a striped straw and bubbles.
local function sodaProp(parent: Instance, at: CFrame): Model
	local m = icon("SpeedSoda")
	local core = disc(m, "Can", 1.6, 1.0, CFrame.new(), Color3.fromRGB(230, 50, 60), Enum.Material.Metal)
	disc(m, "Label", 0.62, 1.04, CFrame.new(0, 0.05, 0), Color3.fromRGB(70, 230, 255), Enum.Material.SmoothPlastic)
	for _, y in { -0.82, 0.82 } do
		disc(m, "Rim", 0.1, 0.9, CFrame.new(0, y, 0), Color3.fromRGB(205, 210, 220), Enum.Material.Metal)
	end
	piece(m, "Tab", Vector3.new(0.28, 0.06, 0.16), CFrame.new(0.15, 0.88, 0), Color3.fromRGB(205, 210, 220), Enum.Material.Metal)
	local straw = CFrame.new(-0.12, 1.35, 0.05) * CFrame.Angles(0, 0, math.rad(14))
	disc(m, "Straw", 0.7, 0.14, straw * CFrame.new(0, -0.3, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	disc(m, "Straw", 0.5, 0.14, straw * CFrame.new(0, 0.3, 0), Color3.fromRGB(255, 70, 80), Enum.Material.SmoothPlastic)
	for i = 0, 3 do
		local a = math.rad(i * 90 + 20)
		local b = ball(m, "Orbit", 0.16 + (i % 2) * 0.1, CFrame.new(math.cos(a) * 0.75, 0.9 + i * 0.25, math.sin(a) * 0.75), Color3.fromRGB(200, 245, 255), Enum.Material.Glass)
		b.Transparency = 0.3
	end
	return finish(m, core, at, parent)
end

-- Balloon Glider: an eight-gore striped balloon over a harness.
local function gliderProp(parent: Instance, at: CFrame): Model
	local m = icon("BalloonGlider")
	local core = ball(m, "Envelope", 1.9, CFrame.new(0, 0.7, 0), Color3.fromRGB(255, 225, 70), Enum.Material.SmoothPlastic)
	for i = 0, 7 do
		local a = i * math.pi / 4
		piece(m, "Gore", Vector3.new(0.75, 2.1, 0.35), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, 0.86), if i % 2 == 0 then Color3.fromRGB(240, 60, 70) else Color3.fromRGB(255, 225, 70), Enum.Material.SmoothPlastic)
	end
	ball(m, "Crown", 0.8, CFrame.new(0, 1.75, 0), Color3.fromRGB(240, 60, 70), Enum.Material.SmoothPlastic)
	piece(m, "Mouth", Vector3.new(0.8, 0.25, 0.8), CFrame.new(0, -0.38, 0), Color3.fromRGB(70, 60, 55), Enum.Material.Fabric)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			piece(m, "Strap", Vector3.new(0.07, 1.1, 0.07), CFrame.new(x * 0.3, -0.95, z * 0.2) * CFrame.Angles(math.rad(-z * 8), 0, math.rad(x * 10)), Color3.fromRGB(60, 50, 45), Enum.Material.Fabric)
		end
	end
	piece(m, "Harness", Vector3.new(0.9, 0.18, 0.55), CFrame.new(0, -1.55, 0), Color3.fromRGB(70, 160, 255), Enum.Material.Fabric)
	piece(m, "Buckle", Vector3.new(0.25, 0.22, 0.1), CFrame.new(0, -1.55, 0.3), BRASS, Enum.Material.Metal)
	return finish(m, core, at, parent)
end

-- Shockwave Shield: a hex-grid shield face over a generator with a glowing core.
local function shieldProp(parent: Instance, at: CFrame): Model
	local m = icon("ShockwaveShield")
	local cyan = Color3.fromRGB(80, 220, 255)
	local core = ball(m, "PowerCore", 0.55, CFrame.new(0, -0.7, 0), cyan, Enum.Material.Neon)
	-- generator: hex base, column and two collars
	local base = CFrame.new(0, -1.35, 0) * CFrame.Angles(math.rad(90), 0, 0)
	hexTile(m, "Base", base, 1.5, 0.3, Color3.fromRGB(55, 60, 75), Enum.Material.DiamondPlate)
	disc(m, "Column", 0.8, 0.5, CFrame.new(0, -0.9, 0), Color3.fromRGB(80, 86, 104), Enum.Material.Metal)
	for _, y in { -1.05, -0.35 } do
		disc(m, "Collar", 0.14, 0.75, CFrame.new(0, y, 0), BRASS, Enum.Material.Metal)
	end
	-- hex-grid face: seven translucent tiles
	local faceCf = CFrame.new(0, 0.55, 0)
	local spacing = 0.78
	hexTile(m, "Hex", faceCf, 0.72, 0.1, cyan, Enum.Material.Neon, 0.35)
	for i = 0, 5 do
		local a = math.rad(30 + i * 60)
		hexTile(m, "Hex", faceCf * CFrame.new(math.cos(a) * spacing, math.sin(a) * spacing, 0), 0.72, 0.1, cyan, Enum.Material.Neon, 0.55)
	end
	local bubble = ball(m, "Bubble", 2.7, faceCf, cyan, Enum.Material.ForceField)
	bubble.Transparency = 0.2
	return finish(m, core, at, parent)
end

---------------------------------------------------------------------------
-- the gear stall

-- Timber-and-brass gear stall with its counter on the floor point `c`, facing +Z.
-- Returns the counter (carries the ShopPrompt).
function LodgeProps.gearStall(parent: Instance, c: Vector3): BasePart
	local s = Instance.new("Model")
	s.Name = "ShopStall"
	s.Parent = parent
	local at = CFrame.new(c)
	piece(s, "Deck", Vector3.new(21, 0.4, 13), at * CFrame.new(0, 0.2, 0.5), WOOD, Enum.Material.WoodPlanks, { Collide = true })

	-- counter: planked front with timber stiles, brass kick plate and a dark top
	local counter = piece(s, "Counter", Vector3.new(18, 3.6, 3.6), at * CFrame.new(0, 2.2, 4), Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks, { Collide = true })
	for i = 0, 4 do
		piece(s, "Stile", Vector3.new(0.7, 3.6, 0.3), at * CFrame.new(-8.6 + i * 4.3, 2.2, 5.9), TIMBER_DARK, Enum.Material.Wood)
	end
	piece(s, "KickPlate", Vector3.new(18.2, 0.45, 3.8), at * CFrame.new(0, 0.62, 4), BRASS, Enum.Material.Metal)
	piece(s, "CounterTop", Vector3.new(19, 0.45, 4.6), at * CFrame.new(0, 4.22, 4), TIMBER_DARK, Enum.Material.Wood, { Collide = true })
	piece(s, "TopEdge", Vector3.new(19.2, 0.22, 0.22), at * CFrame.new(0, 4.22, 6.35), BRASS, Enum.Material.Metal)

	-- back wall: planks with battens, two shelves on brass brackets
	piece(s, "BackWall", Vector3.new(18, 12.6, 0.8), at * CFrame.new(0, 6.9, -4), Color3.fromRGB(176, 128, 82), Enum.Material.WoodPlanks, { Collide = true })
	for _, y in { 1.2, 12.6 } do
		piece(s, "Batten", Vector3.new(18, 0.5, 0.3), at * CFrame.new(0, y, -3.5), TIMBER_DARK, Enum.Material.Wood)
	end
	local bottleColors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 225, 60), Color3.fromRGB(90, 220, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(170, 100, 255) }
	for shelf, y in { 5.6, 8.3 } do
		piece(s, "Shelf", Vector3.new(16, 0.35, 1.6), at * CFrame.new(0, y, -2.9), TIMBER, Enum.Material.Wood)
		for _, x in { -6.5, 0, 6.5 } do
			piece(s, "Bracket", Vector3.new(0.3, 0.7, 1.2), at * CFrame.new(x, y - 0.5, -3.1), BRASS, Enum.Material.Metal)
		end
		for i = 0, 5 do
			local x = -6.25 + i * 2.5
			if shelf == 1 then
				disc(s, "Bottle", 1.5, 0.9, at * CFrame.new(x, y + 0.92, -2.9), bottleColors[i + 1], Enum.Material.Glass)
				disc(s, "Cork", 0.3, 0.4, at * CFrame.new(x, y + 1.82, -2.9), Color3.fromRGB(180, 140, 90), Enum.Material.Wood)
			else
				disc(s, "Can", 1.1, 0.75, at * CFrame.new(x, y + 0.72, -2.9), bottleColors[6 - i], Enum.Material.Metal)
			end
		end
	end

	-- timber posts with brass feet; the back pair is taller so the awning rests on all four
	for _, x in { -8.5, 8.5 } do
		for _, z in { -4, 6 } do
			local top = if z < 0 then 13.6 else 11.4
			piece(s, "Post", Vector3.new(1, top - 0.4, 1), at * CFrame.new(x, (top + 0.4) / 2, z), TIMBER, Enum.Material.Wood, { Collide = true })
			piece(s, "PostFoot", Vector3.new(1.3, 0.5, 1.3), at * CFrame.new(x, 0.65, z), BRASS, Enum.Material.Metal)
		end
	end

	-- striped awning sloping down to the front, with a scalloped valance
	local blue = Color3.fromRGB(60, 140, 240)
	local white = Color3.fromRGB(250, 250, 252)
	local slope = math.rad(12)
	for i = 0, 9 do
		local x = -9 + i * 2
		piece(s, "Awning", Vector3.new(2, 0.3, 12.5), at * CFrame.new(x, 12.6, 1.2) * CFrame.Angles(slope, 0, 0), if i % 2 == 0 then blue else white, Enum.Material.Fabric)
		piece(s, "Valance", Vector3.new(2, 1, 0.15), at * CFrame.new(x, 10.75, 7.35), if i % 2 == 0 then blue else white, Enum.Material.Fabric)
		ball(s, "Scallop", 1, at * CFrame.new(x, 10.25, 7.35), if i % 2 == 0 then blue else white, Enum.Material.Fabric)
	end

	-- hanging lanterns on the front posts (the only lights here; they flicker softly)
	for _, x in { -8.5, 8.5 } do
		local hook = at * CFrame.new(x, 9.2, 6.9)
		piece(s, "LanternArm", Vector3.new(0.18, 0.18, 0.9), hook * CFrame.new(0, 0.6, -0.45), IRON, Enum.Material.Metal)
		piece(s, "LanternFrame", Vector3.new(0.9, 1.2, 0.9), hook * CFrame.new(0, -0.3, 0), BRASS, Enum.Material.Metal, { Transparency = 0.55 })
		local flame = piece(s, "LanternGlow", Vector3.new(0.5, 0.8, 0.5), hook * CFrame.new(0, -0.3, 0), WARM, Enum.Material.Neon)
		piece(s, "LanternCap", Vector3.new(1.1, 0.25, 1.1), hook * CFrame.new(0, 0.38, 0), IRON, Enum.Material.Metal)
		LodgeProps.light(flame, 16, 0.9, WARM, true)
	end

	-- crates and a barrel beside the counter
	for _, spec in { { -11.4, 0, 3.6 }, { -11.6, 0, 0.8 }, { -11.4, 2.5, 2.2 } } do
		local pos = at * CFrame.new(spec[1], 1.25 + spec[2], spec[3])
		piece(s, "Crate", Vector3.new(2.4, 2.4, 2.4), pos, Color3.fromRGB(176, 128, 82), Enum.Material.WoodPlanks, { Collide = true })
		piece(s, "CrateBand", Vector3.new(2.5, 0.3, 2.5), pos, TIMBER_DARK, Enum.Material.Wood)
	end
	local barrel = at * CFrame.new(11.4, 1.6, 3.4)
	disc(s, "Barrel", 3.2, 2.4, barrel, Color3.fromRGB(150, 100, 60), Enum.Material.Wood, { Collide = true })
	for _, y in { -1, 1 } do
		disc(s, "Hoop", 0.25, 2.5, barrel * CFrame.new(0, y, 0), IRON, Enum.Material.Metal)
	end

	-- the three gear props on brass display stands along the counter
	local makers: { (Instance, CFrame) -> Model } = { sodaProp, gliderProp, shieldProp }
	for i, make in makers do
		local x = (i - 2) * 5.5
		disc(s, "PropStand", 0.3, 2.2, at * CFrame.new(x, 4.6, 4), BRASS, Enum.Material.Metal)
		disc(s, "PropStandGlow", 0.08, 2.3, at * CFrame.new(x, 4.48, 4), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
		local prop = make(s, at * CFrame.new(x, 6.6, 4))
		LodgeProps.animate(prop, 1.2, true)
	end

	Signage.board(s, at * CFrame.new(0, 13.5, 7.2) * CFrame.Angles(0, math.pi, 0), 15, 3.6, {
		Name = "ShopSign",
		Title = "GEAR SHOP",
		Subtitle = "Speed Soda · Glider · Shield",
		Icon = "🛒",
		Accent = Color3.fromRGB(70, 170, 255),
		DoubleSided = true,
	})
	return counter
end

---------------------------------------------------------------------------
-- architecture

-- Roof trusses: a lower chord under each tie beam, knee braces down to the side posts,
-- iron end brackets and straps. `beams` are the Z offsets of the beams.
function LodgeProps.trusses(parent: Instance, L: Vector3, halfX: number, beamY: number, beams: { number })
	local f = Instance.new("Model")
	f.Name = "Trusses"
	f.Parent = parent
	for _, z in beams do
		piece(f, "LowerChord", Vector3.new(halfX * 2 - 6, 0.7, 1.4), CFrame.new(L + Vector3.new(0, beamY - 1.35, z)), TIMBER, Enum.Material.Wood)
		for _, side in { -1, 1 } do
			-- a 45° knee brace from the wall to the beam
			local a = L + Vector3.new(side * (halfX - 0.2), beamY - 6.5, z)
			local b = L + Vector3.new(side * (halfX - 5.2), beamY - 1.2, z)
			local d = b - a
			piece(f, "KneeBrace", Vector3.new(0.9, d.Magnitude, 1.1), CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(-d.X, d.Y)), TIMBER_DARK, Enum.Material.Wood)
			piece(f, "Bracket", Vector3.new(2.2, 2.4, 2.4), CFrame.new(L + Vector3.new(side * (halfX - 1.4), beamY, z)), IRON, Enum.Material.Metal)
			piece(f, "Strap", Vector3.new(0.5, 2.3, 2.3), CFrame.new(L + Vector3.new(side * 40, beamY, z)), IRON, Enum.Material.Metal)
			for _, bz in { -0.7, 0.7 } do
				ball(f, "Bolt", 0.45, CFrame.new(L + Vector3.new(side * (halfX - 1.4), beamY - 0.5, z + bz * 1.8)), Color3.fromRGB(70, 68, 70), Enum.Material.Metal)
			end
		end
		piece(f, "RidgePlate", Vector3.new(3, 0.5, 2.6), CFrame.new(L + Vector3.new(0, beamY - 1.8, z)), IRON, Enum.Material.Metal)
	end
end

-- Wainscot on the side walls: a dark baseboard, stone below, framed raised wood panels in
-- each bay and a cap rail. `bays` are the Z centres of the bays.
function LodgeProps.wainscot(parent: Instance, L: Vector3, halfX: number, length: number, bays: { number }, skip: (number, number) -> boolean)
	local f = Instance.new("Model")
	f.Name = "Wainscot"
	f.Parent = parent
	for _, side in { -1, 1 } do
		local x = side * (halfX - 0.3)
		piece(f, "Baseboard", Vector3.new(0.6, 0.8, length), CFrame.new(L + Vector3.new(x, 0.4, 0)), TIMBER_DARK, Enum.Material.Wood)
		piece(f, "CapRail", Vector3.new(0.9, 0.45, length), CFrame.new(L + Vector3.new(side * (halfX - 0.45), 6.25, 0)), TIMBER, Enum.Material.Wood)
		for _, z in bays do
			if skip(side, z) then
				continue
			end
			piece(f, "PanelFrame", Vector3.new(0.3, 3.4, 16), CFrame.new(L + Vector3.new(side * (halfX - 0.15), 3.8, z)), TIMBER, Enum.Material.Wood)
			piece(f, "Panel", Vector3.new(0.25, 2.5, 14.6), CFrame.new(L + Vector3.new(side * (halfX - 0.4), 3.8, z)), Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks)
		end
	end
end

-- Pointed-arch dressing for a window in a side wall at x = `x` (inner face direction
-- `inward`), centred at z `zc`, spanning y0..y1 and `width` wide: plaster spandrels,
-- a mullion, two transoms, a keystone and a stone sill.
function LodgeProps.archWindow(parent: Instance, L: Vector3, x: number, inward: number, zc: number, y0: number, y1: number, width: number)
	local plane = x + inward * 0.6
	local rise = 5
	for _, dz in { -1, 1 } do
		-- right angle in the top corner: local -Y faces up (Y = world down), +Z toward the post
		local pos = L + Vector3.new(plane, y1 - rise / 2, zc + dz * width / 4)
		piece(parent, "Spandrel", Vector3.new(0.6, rise, width / 2), CFrame.fromMatrix(pos, Vector3.new(-dz, 0, 0), Vector3.new(0, -1, 0), Vector3.new(0, 0, dz)), PLASTER, Enum.Material.Plaster, { Class = "WedgePart" })
	end
	piece(parent, "Keystone", Vector3.new(0.9, 1.8, 1.3), CFrame.new(L + Vector3.new(plane + inward * 0.2, y1 - 0.7, zc)), STONE_LIGHT, Enum.Material.Slate)
	piece(parent, "Mullion", Vector3.new(0.5, y1 - y0 - 1, 0.6), CFrame.new(L + Vector3.new(plane, (y0 + y1) / 2 - 0.5, zc)), TIMBER_DARK, Enum.Material.Wood)
	for _, y in { y0 + (y1 - y0) * 0.33, y0 + (y1 - y0) * 0.62 } do
		piece(parent, "Transom", Vector3.new(0.5, 0.45, width), CFrame.new(L + Vector3.new(plane, y, zc)), TIMBER_DARK, Enum.Material.Wood)
	end
	piece(parent, "Sill", Vector3.new(1.6, 0.6, width + 1.2), CFrame.new(L + Vector3.new(x + inward * 0.9, y0 + 0.55, zc)), STONE_LIGHT, Enum.Material.Slate)
end

-- A heraldic round shield on the inner face of a wall post (facing `inward` along X).
function LodgeProps.shield(parent: Instance, pos: Vector3, inward: number, color: Color3)
	local face = CFrame.new(pos) * CFrame.Angles(0, if inward > 0 then 0 else math.pi, 0)
	disc(parent, "ShieldRim", 0.3, 4, face * CFrame.Angles(0, 0, math.rad(-90)), GOLD_DARK, Enum.Material.Metal)
	disc(parent, "ShieldFace", 0.4, 3.5, face * CFrame.new(0.06, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)), color, Enum.Material.Wood)
	piece(parent, "ShieldBand", Vector3.new(0.5, 3.3, 0.5), face * CFrame.new(0.15, 0, 0), GOLD, Enum.Material.Metal)
	piece(parent, "ShieldBand", Vector3.new(0.5, 0.5, 3.3), face * CFrame.new(0.15, 0, 0), GOLD, Enum.Material.Metal)
	ball(parent, "ShieldBoss", 1, face * CFrame.new(0.3, 0, 0), GOLD, Enum.Material.Metal)
end

-- A framed hanging banner on a wall facing `facing`, its rod centred at `top`.
function LodgeProps.banner(parent: Instance, top: Vector3, facing: Vector3, color: Color3, emblem: Color3)
	local cf = CFrame.lookAt(top, top + facing)
	local w, h = 5, 11
	disc(parent, "BannerRod", 6.2, 0.35, cf * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal)
	for _, x in { -3.2, 3.2 } do
		ball(parent, "Finial", 0.6, cf * CFrame.new(x, 0, 0), GOLD, Enum.Material.Metal)
	end
	piece(parent, "Cloth", Vector3.new(w, h, 0.15), cf * CFrame.new(0, -h / 2 - 0.2, 0), color, Enum.Material.Fabric)
	-- a V-notched tail: two wedges hanging under the cloth, points down at the sides
	for _, dx in { -1, 1 } do
		piece(parent, "Tail", Vector3.new(0.15, 1.6, w / 2), cf * CFrame.new(dx * w / 4, -h - 1, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, -1, 0), Vector3.new(dx, 0, 0)), color, Enum.Material.Fabric, { Class = "WedgePart" })
	end
	for _, dx in { -1, 1 } do
		piece(parent, "Border", Vector3.new(0.3, h, 0.2), cf * CFrame.new(dx * (w / 2 - 0.2), -h / 2 - 0.2, -0.05), GOLD, Enum.Material.Fabric)
	end
	piece(parent, "Emblem", Vector3.new(2.2, 2.2, 0.2), cf * CFrame.new(0, -h * 0.42, -0.08) * CFrame.Angles(0, 0, math.rad(45)), emblem, Enum.Material.Fabric)
	ball(parent, "EmblemGem", 0.8, cf * CFrame.new(0, -h * 0.42, -0.15), GOLD, Enum.Material.Metal)
end

-- The fireside hearth on the west wall, centred at z `z0`: a stone chimney breast with
-- quoins, an arched firebox with jambs, a raised slate hearth, andirons, crossed logs on an
-- ember bed (with rising embers), a mantel on corbels with candles, and a shield above.
-- Returns the log pile (the Fire and the flickering light go there).
function LodgeProps.hearth(parent: Instance, L: Vector3, z0: number): BasePart
	local f = Instance.new("Model")
	f.Name = "Hearth"
	f.Parent = parent
	local wall = -80
	piece(f, "Breast", Vector3.new(5, 14, 16), CFrame.new(L + Vector3.new(wall + 2.5, 7, z0)), STONE, Enum.Material.Cobblestone, { Collide = true })
	piece(f, "Chimney", Vector3.new(3.2, 20, 9), CFrame.new(L + Vector3.new(wall + 1.6, 24, z0)), STONE, Enum.Material.Cobblestone, { Collide = true })
	for _, dz in { -1, 1 } do
		piece(f, "Shoulder", Vector3.new(3.2, 2.4, 3.5), CFrame.fromMatrix(L + Vector3.new(wall + 1.6, 15.2, z0 + dz * 6.25), Vector3.new(-dz, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, -dz)), STONE, Enum.Material.Cobblestone, { Class = "WedgePart" })
		-- quoins: alternating long and short dressed stones up the front corners
		for i = 0, 4 do
			local long = i % 2 == 0
			piece(f, "Quoin", Vector3.new(0.5, 2.4, if long then 3 else 1.8), CFrame.new(L + Vector3.new(wall + 5.15, 1.4 + i * 2.6, z0 + dz * (8 - (if long then 1.5 else 0.9)))), if i % 2 == 0 then STONE_LIGHT else STONE_DARK, Enum.Material.Slate)
		end
		piece(f, "Jamb", Vector3.new(0.8, 5.4, 1.4), CFrame.new(L + Vector3.new(wall + 5.3, 2.7, z0 + dz * 4.7)), STONE_LIGHT, Enum.Material.Slate)
		piece(f, "Voussoir", Vector3.new(0.8, 1.3, 3.2), CFrame.new(L + Vector3.new(wall + 5.3, 5.9, z0 + dz * 2.6)) * CFrame.Angles(math.rad(dz * 18), 0, 0), STONE_LIGHT, Enum.Material.Slate)
		piece(f, "Corbel", Vector3.new(1.4, 1.4, 1), CFrame.new(L + Vector3.new(wall + 5.6, 9.6, z0 + dz * 6.5)), TIMBER_DARK, Enum.Material.Wood)
		disc(f, "Candle", 1, 0.45, CFrame.new(L + Vector3.new(wall + 5.8, 11.6, z0 + dz * 6)), Color3.fromRGB(250, 240, 220), Enum.Material.SmoothPlastic)
		ball(f, "CandleFlame", 0.35, CFrame.new(L + Vector3.new(wall + 5.8, 12.25, z0 + dz * 6)), WARM, Enum.Material.Neon)
		-- andiron
		piece(f, "Andiron", Vector3.new(1.8, 0.3, 0.3), CFrame.new(L + Vector3.new(wall + 5.8, 0.9, z0 + dz * 2.4)), IRON, Enum.Material.Metal)
		ball(f, "AndironKnob", 0.55, CFrame.new(L + Vector3.new(wall + 6.6, 1.2, z0 + dz * 2.4)), BRASS, Enum.Material.Metal)
	end
	piece(f, "Keystone", Vector3.new(0.9, 1.6, 1.4), CFrame.new(L + Vector3.new(wall + 5.35, 6.3, z0)), STONE_LIGHT, Enum.Material.Slate)
	piece(f, "Firebox", Vector3.new(0.4, 5, 8), CFrame.new(L + Vector3.new(wall + 4.9, 2.9, z0)), Color3.fromRGB(30, 24, 22), Enum.Material.Slate)
	piece(f, "HearthSlab", Vector3.new(4, 0.5, 12), CFrame.new(L + Vector3.new(wall + 7, 0.25, z0)), Color3.fromRGB(70, 68, 72), Enum.Material.Slate, { Collide = true })
	piece(f, "Mantel", Vector3.new(1.8, 1, 18), CFrame.new(L + Vector3.new(wall + 5.4, 10.7, z0)), WOOD, Enum.Material.Wood, { Collide = true })
	piece(f, "EmberBed", Vector3.new(2.2, 0.25, 5), CFrame.new(L + Vector3.new(wall + 5.9, 0.62, z0)), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
	local logs: BasePart? = nil
	for i, angle in { -20, 20, 0 } do
		local log = disc(f, "FireLog", 4.6, 0.75, CFrame.new(L + Vector3.new(wall + 5.9, 0.95 + (if i == 3 then 0.55 else 0), z0)) * CFrame.Angles(math.rad(90), math.rad(angle), 0), TIMBER_DARK, Enum.Material.Wood)
		logs = logs or log
	end
	-- embers drifting up the chimney
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 80, 20))
	embers.LightEmission = 1
	embers.Rate = 6
	embers.Lifetime = NumberRange.new(1.5, 2.6)
	embers.Speed = NumberRange.new(2, 4)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.Size = NumberSequence.new(0.18, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = logs
	CollectionService:AddTag(embers, LC.AuraTag)
	LodgeProps.shield(f, L + Vector3.new(wall + 3.35, 17, z0), 1, Color3.fromRGB(150, 40, 45))
	for _, dz in { -1, 1 } do
		-- crossed swords behind the shield
		local cf = CFrame.new(L + Vector3.new(wall + 3.3, 17, z0)) * CFrame.Angles(math.rad(dz * 40), 0, 0)
		piece(f, "SwordBlade", Vector3.new(0.15, 7, 0.45), cf, Color3.fromRGB(215, 220, 230), Enum.Material.Metal)
		piece(f, "SwordGuard", Vector3.new(0.3, 0.3, 1.6), cf * CFrame.new(0, -2.6, 0), GOLD, Enum.Material.Metal)
	end
	return logs :: BasePart
end

return LodgeProps
