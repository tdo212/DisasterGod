--!strict
-- Design tokens: chunky, high-contrast "simulator" style (bold rounded font,
-- thick dark outlines, glossy gradients, bright accent colours).

local Theme = {
	Font = Enum.Font.FredokaOne,

	Colors = {
		Text = Color3.fromRGB(255, 255, 255),
		TextDim = Color3.fromRGB(200, 205, 220),
		Outline = Color3.fromRGB(22, 22, 32),
		Panel = Color3.fromRGB(40, 42, 54),
		PanelLight = Color3.fromRGB(62, 66, 84),
		Slot = Color3.fromRGB(30, 32, 42),

		Orange = Color3.fromRGB(255, 150, 20),
		OrangeLight = Color3.fromRGB(255, 205, 60),
		Green = Color3.fromRGB(70, 210, 50),
		GreenLight = Color3.fromRGB(150, 245, 90),
		Blue = Color3.fromRGB(40, 140, 255),
		BlueLight = Color3.fromRGB(110, 200, 255),
		Red = Color3.fromRGB(230, 45, 55),
		RedLight = Color3.fromRGB(255, 110, 100),
		Purple = Color3.fromRGB(140, 60, 255),
		PurpleLight = Color3.fromRGB(205, 130, 255),
		Pink = Color3.fromRGB(255, 60, 150),
		Gold = Color3.fromRGB(255, 200, 40),
		Cyan = Color3.fromRGB(60, 230, 230),
	},

	Radius = {
		Small = UDim.new(0, 8),
		Medium = UDim.new(0, 12),
		Large = UDim.new(0, 18),
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

	Tweens = {
		Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		Slow = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		Float = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

return table.freeze(Theme)
