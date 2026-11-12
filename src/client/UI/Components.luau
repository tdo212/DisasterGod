--!strict
-- Reusable UI builders that apply Theme tokens consistently.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme") :: ModuleScript)
local Sound = require(script.Parent:WaitForChild("Sound") :: ModuleScript)

local C = Theme.Colors

local Components = {}

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

function Components.gradient(parent: GuiObject, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
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
	frame.Parent = props.Parent
	return frame
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

-- Glossy gradient button with press/hover juice.
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
	Components.gradient(button, props.ColorLight or C.GreenLight, props.Color or C.Green)
	-- text (with its own outline) lives on a child label so the border stroke stays on the frame
	Components.label({
		Name = "Text",
		Text = props.Text,
		TextSize = props.TextSize or Theme.TextSize.Body,
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	})

	local scale = Instance.new("UIScale")
	scale.Parent = button

	button.MouseEnter:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 1.06 })
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

export type WindowHandle = {
	Root: Frame,
	Content: Frame,
	Open: () -> (),
	Close: () -> (),
	IsOpen: () -> boolean,
}

-- Modal window: orange glossy header, bold title, red X close (matches the shop references).
function Components.window(parent: Instance, title: string, size: UDim2): WindowHandle
	local root = Components.panel({
		Name = title .. "Window",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Panel,
		Radius = Theme.Radius.Large,
		Parent = parent,
	})
	root.Visible = false
	root.ZIndex = 10
	local scale = Instance.new("UIScale")
	scale.Parent = root

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ZIndex = 11
	Components.corner(header, Theme.Radius.Large)
	Components.gradient(header, C.OrangeLight, C.Orange, 0)
	header.Parent = root

	-- square off the header's bottom corners
	local filler = Instance.new("Frame")
	filler.Size = UDim2.new(1, 0, 0, 18)
	filler.Position = UDim2.new(0, 0, 1, -18)
	filler.BackgroundColor3 = Color3.new(1, 1, 1)
	filler.BorderSizePixel = 0
	filler.ZIndex = 11
	Components.gradient(filler, C.OrangeLight, C.Orange, 0)
	filler.Parent = header

	local titleLabel = Components.label({
		Name = "Title",
		Text = title,
		TextSize = 38,
		Size = UDim2.new(0.6, 0, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = Theme.Stroke.Heavy,
		Parent = header,
	})
	titleLabel.ZIndex = 12

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -24, 1, -84)
	content.Position = UDim2.fromOffset(12, 74)
	content.ZIndex = 11
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

	local closeButton = Components.button({
		Name = "Close",
		Text = "X",
		TextSize = 30,
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, -10, 0, 7),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Red,
		ColorLight = C.RedLight,
		Parent = header,
		OnClick = close,
	})
	closeButton.ZIndex = 12

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

-- Square sidebar tile with a big icon and outlined caption (left menu in the references).
function Components.tile(parent: Instance, icon: string, caption: string, color: Color3, order: number): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = caption
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = order
	tile.Size = UDim2.fromOffset(78, 78)
	tile.BackgroundColor3 = Color3.new(1, 1, 1)
	Components.corner(tile, Theme.Radius.Medium)
	Components.stroke(tile, Theme.Stroke.Heavy)
	Components.gradient(tile, color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	tile.Parent = parent

	Components.label({
		Name = "Icon",
		Text = icon,
		TextSize = 38,
		Size = UDim2.new(1, 0, 0.72, 0),
		StrokeThickness = 0,
		Parent = tile,
	})
	local cap = Components.label({
		Name = "Caption",
		Text = caption,
		TextSize = 17,
		Size = UDim2.new(1, 8, 0, 20),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = tile,
	})
	cap.ZIndex = 2

	local scale = Instance.new("UIScale")
	scale.Parent = tile
	tile.Activated:Connect(function()
		Sound.play("Tab", 0.8)
	end)
	tile.MouseEnter:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 1.08 })
	end)
	tile.MouseLeave:Connect(function()
		Components.tween(scale, Theme.Tweens.Fast, { Scale = 1 })
	end)
	return tile
end

-- Full-screen layer that scales all HUD content to the viewport (phones / small windows).
-- Parent UI to the returned frame instead of the ScreenGui.
function Components.scaledRoot(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "ScaledRoot"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Active = false
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function update()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 760)
		local s = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.5, 1.15)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return root
end

return Components
