--!strict
-- Reusable UI builders that apply Theme tokens consistently: studded glossy buttons,
-- tiles, panels and windows, plus the viewport-scaled root every screen parents to.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme") :: ModuleScript)
local Sound = require(script.Parent:WaitForChild("Sound") :: ModuleScript)

local C = Theme.Colors

local Components = {}

-- Touch-first device (phone / tablet): bigger UI, thumb-friendly placement.
-- Studio testing: set the workspace attribute ForceTouchUI = true before Play to preview
-- the touch layout with a mouse.
function Components.isTouch(): boolean
	if RunService:IsStudio() and workspace:GetAttribute("ForceTouchUI") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Components.corner(parent: GuiObject, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Radius.Medium
	corner.Parent = parent
	return corner
end

function Components.stroke(parent: Instance, thickness: number?, color: Color3?, contextual: boolean?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or Theme.Stroke.Thick
	stroke.Color = color or C.Outline
	stroke.ApplyStrokeMode = if contextual then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

-- Colour ramp for a glossy surface. `lip` adds the darker band along the bottom edge.
function Components.gloss(top: Color3, bottom: Color3, lip: boolean?): ColorSequence
	if not lip then
		return ColorSequence.new(top, bottom)
	end
	local dark = bottom:Lerp(Color3.new(0, 0, 0), Theme.Gloss.LipDarken)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(Theme.Gloss.LipStart, bottom),
		ColorSequenceKeypoint.new(Theme.Gloss.LipStart + 0.01, dark),
		ColorSequenceKeypoint.new(1, dark),
	})
end

function Components.gradient(parent: GuiObject, top: Color3, bottom: Color3, rotation: number?, lip: boolean?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = Components.gloss(top, bottom, lip)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

-- Tiled stud texture over a surface (sits under the element's other children).
function Components.studs(parent: GuiObject, transparency: number?, radius: UDim?): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "Studs"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = Theme.Textures.Studs
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(Theme.Textures.StudSize, Theme.Textures.StudSize)
	image.ImageTransparency = transparency or Theme.Textures.StudTransparency
	image.ZIndex = 0
	Components.corner(image, radius)
	image.Parent = parent
	return image
end

function Components.padding(parent: GuiObject, px: number)
	local padding = Instance.new("UIPadding")
	local u = UDim.new(0, px)
	padding.PaddingTop = u
	padding.PaddingBottom = u
	padding.PaddingLeft = u
	padding.PaddingRight = u
	padding.Parent = parent
end

function Components.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

export type LabelProps = {
	Name: string?,
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Color: Color3?,
	StrokeThickness: number?,
	XAlign: Enum.TextXAlignment?,
	Parent: Instance?,
	ZIndex: number?,
}

-- Bold outlined text, the signature look of the references.
function Components.label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.Text = props.Text
	label.TextColor3 = props.Color or C.Text
	label.TextSize = props.TextSize or Theme.TextSize.Body
	label.Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.TextSize.Body) + 6)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Center
	label.ZIndex = props.ZIndex or 1
	Components.stroke(label, props.StrokeThickness or Theme.Stroke.Thick, C.Outline, true)
	label.Parent = props.Parent
	return label
end

export type PanelProps = {
	Name: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Transparency: number?,
	Radius: UDim?,
	Studs: boolean?, -- stud texture over the panel (off for tiny pills)
	Parent: Instance?,
}

function Components.panel(props: PanelProps): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.Size = props.Size
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.BackgroundColor3 = props.Color or C.Panel
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	Components.corner(frame, props.Radius)
	Components.stroke(frame, Theme.Stroke.Heavy)
	if props.Studs then
		Components.studs(frame, Theme.Textures.StudTransparencyPanel, props.Radius)
	end
	frame.Parent = props.Parent
	return frame
end

-- Hover / press scale juice shared by every clickable surface.
function Components.pressable(button: GuiButton, hover: number?): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local over = hover or 1.06
	button.MouseEnter:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = over })
	end)
	button.MouseLeave:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
	end)
	return scale
end

export type ButtonProps = {
	Name: string?,
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	ColorLight: Color3?,
	TextSize: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
}

-- Studded glossy button with a bottom lip and press/hover juice.
function Components.button(props: ButtonProps): TextButton
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.AutoButtonColor = false
	button.Size = props.Size
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BorderSizePixel = 0
	button.Text = ""
	Components.corner(button)
	Components.stroke(button, Theme.Stroke.Heavy)
	Components.gradient(button, props.ColorLight or C.GreenLight, props.Color or C.Green, 90, true)
	Components.studs(button)
	-- text (with its own outline) lives on a child label so the border stroke stays on the frame
	Components.label({
		Name = "Text",
		Text = props.Text,
		TextSize = props.TextSize or Theme.TextSize.Body,
		Size = UDim2.new(1, 0, 1, -4),
		Parent = button,
	})
	Components.pressable(button)
	button.Activated:Connect(function()
		Sound.play("Click", 0.8, 0.95 + math.random() * 0.1)
	end)
	if props.OnClick then
		button.Activated:Connect(props.OnClick)
	end
	button.Parent = props.Parent
	return button
end

function Components.setText(button: GuiObject, text: string)
	local label = button:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Recolour a button / card built with Components.gradient.
function Components.setColors(surface: GuiObject, top: Color3, bottom: Color3, lip: boolean?)
	local gradient = surface:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = Components.gloss(top, bottom, lip)
	end
end

-- Small corner tag such as "x10" or a spin count.
function Components.tag(parent: GuiObject, text: string, position: UDim2, anchor: Vector2): TextLabel
	local tag = Components.label({
		Name = "Tag",
		Text = text,
		TextSize = 20,
		Size = UDim2.fromOffset(60, 24),
		Position = position,
		AnchorPoint = anchor,
		Parent = parent,
	})
	tag.ZIndex = 3
	return tag
end

export type WindowHandle = {
	Root: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
}

-- Modal window: blue studded header, bold title, red X, dark teal studded body.
function Components.window(parent: Instance, title: string, size: UDim2): WindowHandle
	local root = Components.panel({
		Name = title .. "Window",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Window,
		Transparency = 0.06,
		Radius = Theme.Radius.Large,
		Studs = true,
		Parent = parent,
	})
	root.Visible = false
	root.ZIndex = 10
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ZIndex = 2
	Components.corner(header, Theme.Radius.Large)
	Components.stroke(header, Theme.Stroke.Heavy)
	Components.gradient(header, C.BlueLight, C.Blue, 90, true)
	Components.studs(header, nil, Theme.Radius.Large)
	header.Parent = root

	Components.label({
		Name = "Title",
		Text = title,
		TextSize = 36,
		Size = UDim2.new(1, -90, 1, -6),
		Position = UDim2.fromOffset(20, 0),
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = Theme.Stroke.Heavy,
		Parent = header,
	})

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -24, 1, -80)
	content.Position = UDim2.fromOffset(12, 70)
	content.Parent = root

	local open = false
	local handle: WindowHandle

	local function close()
		if not open then
			return
		end
		open = false
		Sound.play("Click", 0.6, 0.8)
		local t = Components.tween(scale, Theme.Tweens.Fast, { Scale = 0.85 })
		t.Completed:Once(function()
			if not open then
				root.Visible = false
			end
		end)
	end

	Components.button({
		Name = "Close",
		Text = "X",
		TextSize = 30,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -6, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Red,
		ColorLight = C.RedLight,
		Parent = header,
		OnClick = close,
	})

	handle = {
		Root = root,
		Content = content,
		Open = function()
			open = true
			Sound.play("Open", 0.5, 1.2)
			root.Visible = true
			scale.Scale = 0.7
			Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
		end,
		Close = close,
		IsOpen = function()
			return open
		end,
	}
	return handle
end

-- Square menu tile with a big icon and outlined caption (left menu in the references).
function Components.tile(parent: Instance, icon: string, caption: string, color: Color3, order: number): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = caption
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = order
	tile.Size = UDim2.fromOffset(74, 74)
	tile.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(tile, Theme.Radius.Medium)
	Components.stroke(tile, Theme.Stroke.Heavy)
	Components.gradient(tile, color:Lerp(Color3.new(1, 1, 1), 0.4), color, 90, true)
	Components.studs(tile)
	tile.Parent = parent

	Components.label({
		Name = "Icon",
		Text = icon,
		TextSize = 36,
		Size = UDim2.new(1, 0, 0.7, 0),
		StrokeThickness = 0,
		Parent = tile,
	})
	local cap = Components.label({
		Name = "Caption",
		Text = caption,
		TextSize = 16,
		Size = UDim2.new(1, 8, 0, 20),
		Position = UDim2.new(0.5, 0, 1, -13),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = tile,
	})
	cap.ZIndex = 2

	-- red "!" / count bubble in the top-right corner (hidden until set)
	local badge = Components.label({
		Name = "Badge",
		Text = "",
		TextSize = 16,
		Size = UDim2.fromOffset(26, 22),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		Parent = tile,
	})
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = C.Red
	badge.ZIndex = 3
	badge.Visible = false
	Components.corner(badge, Theme.Radius.Small)

	Components.pressable(tile, 1.08)
	tile.Activated:Connect(function()
		Sound.play("Tab", 0.8)
	end)
	return tile
end

function Components.setBadge(tile: GuiObject, text: string?)
	local badge = tile:FindFirstChild("Badge")
	if badge and badge:IsA("TextLabel") then
		badge.Visible = text ~= nil and text ~= ""
		badge.Text = text or ""
	end
end

-- Horizontal progress bar. Returns the track and a setter taking 0..1.
function Components.progress(parent: Instance, size: UDim2, position: UDim2, top: Color3, bottom: Color3): (Frame, (number) -> (), UIGradient)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = size
	track.Position = position
	track.BackgroundColor3 = C.Slot
	track.BorderSizePixel = 0
	Components.corner(track, Theme.Radius.Small)
	Components.stroke(track, Theme.Stroke.Thin)
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	Components.corner(fill, Theme.Radius.Small)
	local gradient = Components.gradient(fill, top, bottom, 90, true)
	fill.Parent = track
	return track, function(alpha: number)
		Components.tween(fill, Theme.Tweens.Fade, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
	end, gradient
end

-- Full-screen layer that scales all content to the screen. UI is authored against
-- Theme.Layout's reference canvas (a smaller one on touch devices, so everything is
-- bigger under a thumb). Parent UI to the returned frame instead of the ScreenGui.
function Components.scaledRoot(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "ScaledRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Active = false
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local layout = Theme.Layout
	local function update()
		local size = gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local reference = if Components.isTouch() then layout.TouchReference else layout.DesktopReference
		local s = math.clamp(math.min(size.X / reference.X, size.Y / reference.Y), layout.MinScale, layout.MaxScale)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	return root
end

-- Current scale of a root made by scaledRoot (to convert screen pixels to layer units).
function Components.rootScale(root: Frame): number
	local scale = root:FindFirstChildOfClass("UIScale")
	return if scale then scale.Scale else 1
end

return Components
