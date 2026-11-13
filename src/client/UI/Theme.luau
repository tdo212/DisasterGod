--!strict
-- Design tokens: chunky "simulator" style — bold rounded font, thick dark outlines,
-- glossy gradients with a darker bottom lip, and a stud texture over every surface.

local Theme = {
	Font = Enum.Font.FredokaOne,

	Colors = {
		Text = Color3.fromRGB(255, 255, 255),
		TextDim = Color3.fromRGB(200, 205, 220),
		Outline = Color3.fromRGB(16, 16, 24),
		Panel = Color3.fromRGB(30, 34, 48),
		PanelLight = Color3.fromRGB(62, 66, 84),
		Slot = Color3.fromRGB(22, 24, 34),
		Window = Color3.fromRGB(24, 52, 68), -- window body (dark teal, like the references)
		WindowLight = Color3.fromRGB(34, 72, 92),

		Orange = Color3.fromRGB(255, 140, 20),
		OrangeLight = Color3.fromRGB(255, 205, 60),
		Green = Color3.fromRGB(60, 200, 40),
		GreenLight = Color3.fromRGB(150, 245, 90),
		Blue = Color3.fromRGB(30, 130, 250),
		BlueLight = Color3.fromRGB(100, 200, 255),
		Red = Color3.fromRGB(225, 40, 50),
		RedLight = Color3.fromRGB(255, 110, 100),
		Purple = Color3.fromRGB(135, 55, 250),
		PurpleLight = Color3.fromRGB(205, 130, 255),
		Pink = Color3.fromRGB(255, 60, 150),
		PinkLight = Color3.fromRGB(255, 150, 190),
		Gold = Color3.fromRGB(255, 200, 40),
		GoldLight = Color3.fromRGB(255, 235, 120),
		Cyan = Color3.fromRGB(60, 230, 230),
		Grey = Color3.fromRGB(120, 126, 145),
		GreyLight = Color3.fromRGB(190, 195, 210),
	},

	Radius = {
		Small = UDim.new(0, 6),
		Medium = UDim.new(0, 9),
		Large = UDim.new(0, 12),
		Pill = UDim.new(1, 0),
	},

	Stroke = {
		Thin = 2,
		Thick = 3,
		Heavy = 4,
	},

	TextSize = {
		Small = 16,
		Body = 20,
		Title = 28,
		Huge = 46,
	},

	Textures = {
		Studs = "rbxassetid://7447638591",
		StudSize = 30, -- px per stud tile
		StudTransparency = 0.55, -- on bright buttons / tiles
		StudTransparencyPanel = 0.86, -- on dark panels
	},

	-- Glossy gradient: light top, base colour, then a darker lip along the bottom edge.
	Gloss = {
		LipStart = 0.84,
		LipDarken = 0.3,
	},

	-- UI is authored for these canvas sizes and scaled to fit the screen.
	Layout = {
		DesktopReference = Vector2.new(1280, 720),
		TouchReference = Vector2.new(1040, 540), -- bigger relative UI for thumbs
		MinScale = 0.45,
		MaxScale = 1.25,
	},

	Tweens = {
		Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Slow = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		Float = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

return table.freeze(Theme)
