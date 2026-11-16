--!strict
-- Signage: stud-UI style signboards for the Sky Lodge (shared, so the server's zone signs
-- and the client-built Arena Cam header look the same).
--
-- board(): a physical sign. A dark slate (or timber) backing, a raised face panel, a
-- metallic trim frame with corner studs and a thin neon underline; the face carries a
-- SurfaceGui with heavy Montserrat text (thick black outline, light-to-accent gradient),
-- an optional round icon badge and a subtitle line. The front is the LookVector of `cf`.
-- billboard(): a floating name tag in the same type style, for the showcase displays.
--
-- The type style mirrors client/UI/Theme (Montserrat Heavy / Bold, black outlines).

local Config = require(script.Parent:WaitForChild("Config") :: ModuleScript)

local Signage = {}

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local FONT_BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(16, 16, 24)
local SLATE = Color3.fromRGB(34, 38, 54)
local SLATE_FACE = Color3.fromRGB(46, 51, 72)
local GOLD = Color3.fromRGB(255, 196, 60)

Signage.Gold = GOLD
Signage.Slate = SLATE

export type BoardSpec = {
	Title: string,
	Subtitle: string?,
	Icon: string?, -- emoji in a round badge left of the title
	Accent: Color3, -- badge, gradient end and neon underline
	Trim: Color3?, -- frame colour (gold by default)
	TrimMaterial: Enum.Material?,
	Backing: Color3?,
	BackingMaterial: Enum.Material?,
	Face: Color3?,
	DoubleSided: boolean?,
	Name: string?,
}

local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function stroke(parent: GuiObject, thickness: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or INK
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Parent = parent
end

local function gradient(parent: GuiObject, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

local function label(parent: Instance, text: string, font: Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = parent
	return l
end

-- Fill the face of a sign. `px` is the face size in pixels.
local function face(part: BasePart, normal: Enum.NormalId, spec: BoardSpec, px: Vector2)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignFace"
	gui.Face = normal
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Config.Lodge.SignPixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = 1.15
	gui.Parent = part

	local pad = math.floor(px.Y * 0.08)
	local hasSub = spec.Subtitle ~= nil and spec.Subtitle ~= ""
	local badge = if spec.Icon then math.floor(px.Y * (if hasSub then 0.78 else 0.8)) else 0
	local left = if spec.Icon then badge + pad * 2 else pad
	local textW = px.X - left - pad
	local titleH = math.floor((px.Y - pad * 2) * (if hasSub then 0.64 else 0.92))
	local outline = math.clamp(math.floor(titleH * 0.075), 3, 12)

	if spec.Icon then
		local disc = Instance.new("Frame")
		disc.Name = "Badge"
		disc.Size = UDim2.fromOffset(badge, badge)
		disc.Position = UDim2.fromOffset(pad, math.floor((px.Y - badge) / 2))
		disc.BackgroundColor3 = spec.Accent
		disc.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = disc
		stroke(disc, math.max(3, math.floor(badge * 0.06)))
		gradient(disc, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165))
		local icon = label(disc, spec.Icon, FONT, Color3.new(1, 1, 1))
		icon.Size = UDim2.fromScale(0.72, 0.72)
		icon.Position = UDim2.fromScale(0.14, 0.14)
	end

	local title = label(gui, spec.Title, FONT, Color3.new(1, 1, 1))
	title.Name = "Title"
	title.Size = UDim2.fromOffset(textW, titleH)
	title.Position = UDim2.fromOffset(left, pad + (if hasSub then 0 else math.floor((px.Y - pad * 2 - titleH) / 2)))
	title.TextXAlignment = if spec.Icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	stroke(title, outline)
	gradient(title, Color3.fromRGB(255, 255, 245), spec.Accent:Lerp(Color3.new(1, 1, 1), 0.25))

	local subtitle = spec.Subtitle
	if subtitle and hasSub then
		local subH = px.Y - pad * 2 - titleH
		local sub = label(gui, subtitle, FONT_BOLD, Color3.fromRGB(235, 240, 255))
		sub.Name = "Subtitle"
		sub.Size = UDim2.fromOffset(textW, math.floor(subH * 0.86))
		sub.Position = UDim2.fromOffset(left, pad + titleH)
		sub.TextXAlignment = title.TextXAlignment
		stroke(sub, math.clamp(math.floor(subH * 0.08), 2, 6))
	end
end

-- A physical signboard `width` x `height` studs centred on `cf`, facing cf.LookVector.
-- Every part is anchored, non-colliding, non-touchable and shadowless.
function Signage.board(parent: Instance, cf: CFrame, width: number, height: number, spec: BoardSpec): Model
	local model = Instance.new("Model")
	model.Name = spec.Name or "Sign"
	local trim = spec.Trim or GOLD
	local trimMat = spec.TrimMaterial or Enum.Material.Metal
	local double = spec.DoubleSided == true

	-- backing slab and a slightly darker bevel step behind the face
	piece(model, "Backing", Vector3.new(width, height, 0.6), cf, spec.Backing or SLATE, spec.BackingMaterial or Enum.Material.Slate)
	local faceSize = Vector3.new(width - 0.9, height - 0.9, 0.16)
	local front = piece(model, "Face", faceSize, cf * CFrame.new(0, 0, -0.38), spec.Face or SLATE_FACE, Enum.Material.SmoothPlastic)
	local px = Vector2.new(faceSize.X, faceSize.Y) * Config.Lodge.SignPixelsPerStud
	face(front, Enum.NormalId.Front, spec, px)
	if double then
		local back = piece(model, "FaceBack", faceSize, cf * CFrame.new(0, 0, 0.38), spec.Face or SLATE_FACE, Enum.Material.SmoothPlastic)
		face(back, Enum.NormalId.Back, spec, px)
	end

	-- trim frame (proud of the face on both sides, so nothing is coplanar) + corner studs
	local depth = 1.12
	for _, y in { -1, 1 } do
		piece(model, "Trim", Vector3.new(width + 0.4, 0.42, depth), cf * CFrame.new(0, y * (height / 2), 0), trim, trimMat)
	end
	for _, x in { -1, 1 } do
		piece(model, "Trim", Vector3.new(0.42, height, depth), cf * CFrame.new(x * (width / 2), 0, 0), trim, trimMat)
	end
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in (if double then { -1, 1 } else { -1 }) do
				piece(model, "Stud", Vector3.new(0.3, 0.75, 0.75), cf * CFrame.new(x * (width / 2), y * (height / 2), z * 0.62) * CFrame.Angles(0, math.rad(90), 0), trim:Lerp(Color3.new(1, 1, 1), 0.25), trimMat, Enum.PartType.Cylinder)
			end
		end
	end
	-- neon underline just inside the bottom of the frame
	for _, z in (if double then { -1, 1 } else { -1 }) do
		piece(model, "Underline", Vector3.new(width - 1.6, 0.14, 0.08), cf * CFrame.new(0, -height / 2 + 0.55, z * 0.49), spec.Accent, Enum.Material.Neon)
	end
	model.Parent = parent
	return model
end

-- Two dark chains from `top` (a point under a beam) down to the sign's top corners.
function Signage.hang(parent: Instance, sign: Model, ceilingY: number)
	local cf, size = sign:GetBoundingBox()
	for _, x in { -0.35, 0.35 } do
		local anchor = cf * CFrame.new(x * size.X, size.Y / 2, 0)
		local length = ceilingY - anchor.Position.Y
		if length > 0.2 then
			piece(parent, "SignChain", Vector3.new(0.22, length, 0.22), CFrame.new(anchor.Position + Vector3.new(0, length / 2, 0)), Color3.fromRGB(40, 38, 40), Enum.Material.Metal)
			piece(parent, "SignHook", Vector3.new(0.7, 0.35, 0.7), CFrame.new(anchor.Position + Vector3.new(0, 0.1, 0)), GOLD, Enum.Material.Metal)
		end
	end
end

export type TagSpec = {
	Title: string,
	Subtitle: string?,
	Accent: Color3,
	Offset: Vector3,
	Width: number, -- studs
	Height: number,
	MaxDistance: number?,
}

-- A floating name tag over a display: a translucent slate pill with an accent outline,
-- the name in heavy outlined type and an optional gold subtitle (price, "TAP TO VIEW").
function Signage.billboard(adornee: BasePart, spec: TagSpec): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "DisplayTag"
	gui.Size = UDim2.new(spec.Width, 0, spec.Height, 0)
	gui.StudsOffset = spec.Offset
	gui.MaxDistance = spec.MaxDistance or Config.Lodge.HeaderDistance
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
	pill.BackgroundTransparency = 0.2
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = pill
	local rim = Instance.new("UIStroke")
	rim.Thickness = 2.5
	rim.Color = spec.Accent
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = pill

	local hasSub = spec.Subtitle ~= nil and spec.Subtitle ~= ""
	local title = label(pill, spec.Title, FONT, Color3.new(1, 1, 1))
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.92, if hasSub then 0.56 else 0.8)
	title.Position = UDim2.fromScale(0.04, if hasSub then 0.06 else 0.1)
	stroke(title, 2.5)
	gradient(title, Color3.fromRGB(255, 255, 245), spec.Accent:Lerp(Color3.new(1, 1, 1), 0.3))
	local subtitle = spec.Subtitle
	if subtitle and hasSub then
		local sub = label(pill, subtitle, FONT_BOLD, Color3.fromRGB(255, 214, 70))
		sub.Name = "Subtitle"
		sub.Size = UDim2.fromScale(0.86, 0.32)
		sub.Position = UDim2.fromScale(0.07, 0.62)
		sub.RichText = true
		stroke(sub, 2)
	end
	return gui
end

return Signage
