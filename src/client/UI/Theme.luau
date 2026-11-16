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
		Window = Color3.fromRGB(56, 61, 71), -- window body: translucent slate (stud shop reference), the scene shows through
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

	-- square-cut blocks like the reference (mitred outlines, no rounding)
	Radius = {
		Small = UDim.new(0, 0),
		Medium = UDim.new(0, 0),
		Large = UDim.new(0, 0),
		Pill = UDim.new(1, 0),
	},

	-- Stud block construction (Figma "Survive The God" stud UI): a darker depth edge under
	-- the face, a light inner rim, and translucent sheen stripes on buy buttons.
	Block = {
		Depth = 6, -- px of darker extrusion below the face
		DepthCard = 8, -- cards, window headers and hero banners
		DepthDarken = 0.55, -- depth = base colour this far toward black
		Rim = 2, -- inner light rim thickness
		RimLighten = 0.55, -- rim = base colour this far toward white
		RimTransparency = 0.2,
		SheenTransparency = 0.8, -- the white diagonal stripes on buy buttons
		WindowTransparency = 0.3, -- translucent window body
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

	-- Currency bar (HUDController): coin balance, "+" top-up, Friend Boost pill.
	Wallet = {
		Width = 190,
		Height = 50,
		Gap = 10, -- between the bar and the "+" button
		FriendWidth = 200,
	},

	-- Shop window layout (MenuController), from the Figma stud UI at 2/3 scale.
	Shop = {
		Width = 840,
		Height = 612,
		TabWidth = 124,
		TabHeight = 46,
		PageTop = 56, -- below the tab row
		HeroHeight = 150, -- featured offer banner (Gear, Coins, Specials)
		HeroTitleSize = 36,
		HeroBulletTop = 50,
		HeroBullets = 2, -- bullet lines shown (phones show one)
		HeroButtonHeight = 42,
		StyleHeroHeight = 104, -- the featured God Skin under Style's category row
		HeroGap = 10,
		HeroButtonWidth = 170,
		HeroTitleColor = Color3.fromRGB(255, 226, 31),
		HeroStripeTransparency = 0.82,
		StripHeight = 52, -- God Kits loadout / Passes title strip
		CategoryHeight = 36, -- Style's category row
		FooterHeight = 34, -- wallet + hint line
		CardWidth = 150,
		CardHeight = 236,
		KitCardHeight = 250, -- room for the five-disaster row
		CardGap = 10,
		AbilityIcon = 25,
		FeaturedSkin = "CelestialMask",
	},
	-- Phones: a shorter shop so the window fits a 540-unit-tall touch canvas at ~0.95
	-- scale (one hero bullet, no featured skin banner on Style).
	ShopTouch = {
		Height = 540,
		HeroHeight = 112,
		HeroTitleSize = 30,
		HeroBulletTop = 42,
		HeroBullets = 1,
		HeroButtonHeight = 38,
		StripHeight = 48,
		FooterHeight = 28,
		CardHeight = 214,
		KitCardHeight = 242,
		StyleHeroHeight = 0,
	},

	-- UI is authored for these canvas sizes and scaled to fit the screen.
	Layout = {
		DesktopReference = Vector2.new(1280, 720),
		TouchReference = Vector2.new(1040, 540), -- bigger relative UI for thumbs
		MinScale = 0.45,
		MaxScale = 1.25,
		PhoneMaxSide = 600, -- a touch screen this short (points) gets the touch layout even with a keyboard
		FitMargin = 0.94, -- windows shrink to fit this share of the screen
		TouchModalMargin = 0.76, -- the map vote on phones leaves the round bar and side menu visible
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
