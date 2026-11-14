--!strict
-- Design tokens matching StarterGui.UIReference: heavy Montserrat with a thick black
-- outline, square-cut studded blocks (cyan headers, green buy buttons, red close), a
-- darker lip along every bottom edge, black-outlined translucent dark windows, and
-- sticker icons (UI/Icons).

local Theme = {
	Font = Enum.Font.Montserrat, -- legacy property; labels use FontFace below
	FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy),
	FontFaceBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),

	Colors = {
		Text = Color3.fromRGB(255, 255, 255),
		TextDim = Color3.fromRGB(214, 220, 234),
		Outline = Color3.fromRGB(0, 0, 0),
		Panel = Color3.fromRGB(26, 30, 40),
		PanelLight = Color3.fromRGB(62, 66, 84),
		Slot = Color3.fromRGB(18, 20, 28),
		Window = Color3.fromRGB(22, 25, 34), -- window body: near-opaque dark (UIReference MainFrame), high contrast under white text
		WindowLight = Color3.fromRGB(40, 46, 60),
		Header = Color3.fromRGB(40, 190, 225), -- cyan studded header
		HeaderLight = Color3.fromRGB(80, 225, 250),

		Orange = Color3.fromRGB(255, 140, 20),
		OrangeLight = Color3.fromRGB(255, 205, 60),
		Green = Color3.fromRGB(40, 190, 70),
		GreenLight = Color3.fromRGB(90, 240, 120),
		Blue = Color3.fromRGB(30, 130, 250),
		BlueLight = Color3.fromRGB(100, 200, 255),
		Red = Color3.fromRGB(215, 45, 50),
		RedLight = Color3.fromRGB(250, 95, 95),
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

	-- square-cut blocks like the reference (just enough rounding to soften pixels)
	Radius = {
		Small = UDim.new(0, 3),
		Medium = UDim.new(0, 4),
		Large = UDim.new(0, 5),
		Pill = UDim.new(1, 0),
	},

	Stroke = {
		-- bold black outlines everywhere (the reference's defining feature)
		Thin = 2.5,
		Thick = 3.5,
		Heavy = 4.5,
		Window = 5,
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
		StudTransparency = 0.7, -- on bright buttons / tiles (subtle: clean, not noisy)
		StudTransparencyPanel = 0.92, -- on dark panels
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
		Spring = TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0),
		Slow = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		Float = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	},
}

return table.freeze(Theme)
