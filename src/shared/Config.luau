--!strict
-- Central gameplay constants. All tunable numbers live here.

local Types = require(script.Parent.Types)

local Abilities: { Types.AbilityDefinition } = {
	{
		Id = "Lightning",
		DisplayName = "Lightning",
		Icon = "⚡",
		Tier = "Minor",
		Cost = 12,
		Cooldown = 2.5,
		WarningTime = 1.5,
		Radius = 10,
		PlayerDamage = 55,
		StructureDamage = 170,
	},
	{
		Id = "Gust",
		DisplayName = "Gust",
		Icon = "🌬️",
		Tier = "Minor",
		Cost = 10,
		Cooldown = 4,
		WarningTime = 1.5,
		Radius = 30,
		PlayerDamage = 5,
		StructureDamage = 45,
		Knockback = 85,
	},
	{
		Id = "Meteor",
		DisplayName = "Meteors",
		Icon = "☄️",
		Tier = "Major",
		Cost = 40,
		Cooldown = 10,
		WarningTime = 2,
		Radius = 28,
		PlayerDamage = 45,
		StructureDamage = 260,
		Count = 6,
		ImpactRadius = 12,
	},
	{
		Id = "Tornado",
		DisplayName = "Tornado",
		Icon = "🌪️",
		Tier = "Major",
		Cost = 55,
		Cooldown = 16,
		WarningTime = 2,
		Radius = 17,
		PlayerDamage = 0,
		StructureDamage = 90, -- per second
		Duration = 8,
		Speed = 16,
		TickDamage = 8,
		Knockback = 60,
	},
	{
		Id = "FaultCleave",
		DisplayName = "Fault Cleave",
		Icon = "💥",
		Tier = "Major",
		Cost = 65,
		Cooldown = 18,
		WarningTime = 2.5,
		Radius = 8, -- half-width used for the reticle
		PlayerDamage = 40,
		StructureDamage = 999,
		Length = 120,
		Width = 10,
	},
	-- kit-exclusive disasters (see Kits below)
	{
		Id = "ChainLightning",
		DisplayName = "Chain Bolt",
		Icon = "🌩️",
		Tier = "Major",
		Cost = 35,
		Cooldown = 9,
		WarningTime = 1.2,
		Radius = 9,
		PlayerDamage = 40,
		StructureDamage = 150,
		Count = 4, -- strikes in the chain
		Length = 45, -- max hop distance to the next target
		Duration = 0.6, -- telegraph time of each hop
	},
	{
		Id = "Eruption",
		DisplayName = "Eruption",
		Icon = "🌋",
		Tier = "Major",
		Cost = 45,
		Cooldown = 14,
		WarningTime = 2,
		Radius = 14,
		PlayerDamage = 30,
		StructureDamage = 200,
		Knockback = 60,
		Duration = 6, -- lava pool lifetime
		TickDamage = 12, -- per half second in the pool
	},
	{
		Id = "Glitch",
		DisplayName = "Glitch",
		Icon = "👾",
		Tier = "Minor",
		Cost = 18,
		Cooldown = 6,
		WarningTime = 1.3,
		Radius = 16,
		PlayerDamage = 15,
		StructureDamage = 115,
		Knockback = 70,
	},
	-- every kit also gets this one (Disasters.UniversalAbilities)
	{
		Id = "SeismicPing",
		DisplayName = "Seismic Ping",
		Icon = "📡",
		Tier = "Utility",
		Cost = 15,
		Cooldown = 14,
		WarningTime = 0.5,
		Radius = 70, -- survivors inside are revealed through walls
		PlayerDamage = 0,
		StructureDamage = 0,
		Duration = 2, -- reveal seconds
	},
}

-- God loadouts. Each kit is five ability ids; bought with coins, equipped in the shop.
local Kits: { Types.KitDefinition } = {
	{ Id = "Architect", Name = "The Architect", Icon = "🏛️", Description = "The balanced classic", Price = 0, Color = Color3.fromRGB(140, 60, 255), Abilities = { "Lightning", "Gust", "Meteor", "Tornado", "FaultCleave" } },
	{ Id = "Storm", Name = "Storm Deity", Icon = "⛈️", Description = "Chain bolts and hurricanes", Price = 1500, Color = Color3.fromRGB(40, 140, 255), Abilities = { "Lightning", "ChainLightning", "Gust", "Tornado", "Meteor" } },
	{ Id = "Magma", Name = "Magma Titan", Icon = "🔥", Description = "Eruptions, meteors, fissures", Price = 2500, Color = Color3.fromRGB(255, 110, 30), Abilities = { "Eruption", "Meteor", "FaultCleave", "Lightning", "Gust" } },
	{ Id = "Glitch", Name = "Cyber Glitch", Icon = "👾", Description = "Glitch pulses and chain bolts", Price = 4000, Color = Color3.fromRGB(255, 60, 200), Abilities = { "Glitch", "ChainLightning", "Lightning", "Tornado", "FaultCleave" } },
}

-- Spin wheel segments. Odds shown to players are Weight / total weight.
local SpinRewards: { Types.SpinReward } = {
	{ Id = "God", Label = "GOD", Icon = "😈", Kind = "God", Amount = 1, Weight = 8, Color = Color3.fromRGB(255, 70, 20) },
	{ Id = "Jackpot", Label = "1,500", Icon = "🏆", Kind = "Coins", Amount = 1500, Weight = 12, Color = Color3.fromRGB(140, 240, 20) },
	{ Id = "Coins400", Label = "400", Icon = "💰", Kind = "Coins", Amount = 400, Weight = 25, Color = Color3.fromRGB(95, 205, 20) },
	{ Id = "Kit", Label = "KIT", Icon = "🎒", Kind = "Kit", Amount = 1, Weight = 20, Color = Color3.fromRGB(140, 240, 20) },
	{ Id = "Coins150", Label = "150", Icon = "🪙", Kind = "Coins", Amount = 150, Weight = 35, Color = Color3.fromRGB(95, 205, 20) },
}

-- Daily quest pool. Two are drawn per day, plus a "survive on the map of the day" quest.
local QuestPool: { Types.QuestDefinition } = {
	{ Id = "Survive3", Text = "Survive 3 rounds", Stat = "Survive", Goal = 3, Reward = 150 },
	{ Id = "NearMiss5", Text = "Get 5 near misses", Stat = "NearMiss", Goal = 5, Reward = 120 },
	{ Id = "Play5", Text = "Play 5 rounds", Stat = "Play", Goal = 5, Reward = 100 },
	{ Id = "Obby2", Text = "Clear the lobby obby twice", Stat = "Obby", Goal = 2, Reward = 60 },
	{ Id = "Escape2", Text = "Escape 2 collapsing buildings", Stat = "Escape", Goal = 2, Reward = 150 },
	{ Id = "Gear3", Text = "Use 3 gear items", Stat = "Gear", Goal = 3, Reward = 90 },
	{ Id = "GodKill5", Text = "Eliminate 5 survivors as God", Stat = "GodKill", Goal = 5, Reward = 200 },
	{ Id = "Destroy200", Text = "Destroy 200 parts as God", Stat = "Destroy", Goal = 200, Reward = 150 },
	{ Id = "Vote3", Text = "Vote for a map 3 times", Stat = "Vote", Goal = 3, Reward = 60 },
	{ Id = "Spin1", Text = "Spin the wheel", Stat = "Spin", Goal = 1, Reward = 50 },
}

local Gear: { Types.GearDefinition } = {
	{
		Id = "SpeedSoda",
		DisplayName = "Speed Soda",
		Icon = "🥤",
		Description = "Huge speed burst",
		Price = 60,
		Duration = 6,
		Key = "1",
		Color = Color3.fromRGB(70, 200, 255),
	},
	{
		Id = "Glider",
		DisplayName = "Balloon Glider",
		Icon = "🎈",
		Description = "Low gravity floaty jumps",
		Price = 80,
		Duration = 7,
		Key = "2",
		Color = Color3.fromRGB(255, 80, 110),
	},
	{
		Id = "Shield",
		DisplayName = "Shockwave Shield",
		Icon = "🛡️",
		Description = "Brief invulnerability",
		Price = 120,
		Duration = 4,
		Key = "3",
		Color = Color3.fromRGB(255, 200, 40),
	},
}

-- Robux catalog. Ids were created through Open Cloud for universe 10776039268.
local Products: { [string]: Types.ProductDefinition } = {
	CoinsSmall = { Id = 3730591954, Name = "Pouch of Coins", Price = 25, Icon = "💰", Coins = 500, Badge = "" },
	CoinsMedium = { Id = 3730591956, Name = "Bag of Coins", Price = 60, Icon = "💰💰", Coins = 1500, Badge = "Good Value" },
	CoinsLarge = { Id = 3730591959, Name = "Chest of Coins", Price = 140, Icon = "🧰", Coins = 4000, Badge = "Great Value" },
	CoinsHuge = { Id = 3730591960, Name = "Vault of Coins", Price = 349, Icon = "🏦", Coins = 12000, Badge = "Most Value" },
	GodNextRound = { Id = 3730591965, Name = "Be the God Next Round", Price = 49, Icon = "😈", Badge = "" },
	SurvivalKit = { Id = 3730591969, Name = "Survival Kit", Price = 35, Icon = "🎒", Badge = "" },
	WelcomePack = { Id = 3730591973, Name = "Welcome Pack", Price = 15, Icon = "🎁", Coins = 1000, Badge = "Starter Deal" },
	Revive = { Id = 3730591976, Name = "Second Chance", Price = 19, Icon = "💖", Badge = "" },
	Spin1 = { Id = 3730754273, Name = "1 Wheel Spin", Price = 34, Icon = "🎡", Spins = 1, Badge = "" },
	Spin10 = { Id = 3730754283, Name = "10 Wheel Spins", Price = 149, Icon = "🎡", Spins = 10, Badge = "Best Value" },
	-- PLACEHOLDERS (Id = 0): create these in the Creator Dashboard and paste the ids here.
	-- Items with Id 0 are hidden from purchase ("coming soon") and skipped by ProcessReceipt.
	SkinMagmaClaw = { Id = 0, Name = "Magma Claw God Skin", Price = 149, Icon = "🔥", Cosmetic = "MagmaClaw", Badge = "" },
	SkinCyberGauntlet = { Id = 0, Name = "Cyber Gauntlet God Skin", Price = 149, Icon = "🤖", Cosmetic = "CyberGauntlet", Badge = "" },
	SkinCelestialMask = { Id = 0, Name = "Celestial Mask God Skin", Price = 199, Icon = "🌟", Cosmetic = "CelestialMask", Badge = "Legendary" },
	FxNeonVoid = { Id = 0, Name = "Neon Void Disaster FX", Price = 99, Icon = "🟣", Cosmetic = "NeonVoid", Badge = "" },
	FxPixelChaos = { Id = 0, Name = "Pixel Chaos Disaster FX", Price = 129, Icon = "👾", Cosmetic = "PixelChaos", Badge = "" },
	FinConfettiPop = { Id = 0, Name = "Confetti Pop Finisher", Price = 99, Icon = "🎉", Cosmetic = "ConfettiPop", Badge = "" },
	FinCartoonBoing = { Id = 0, Name = "Cartoon Boing Finisher", Price = 99, Icon = "🌀", Cosmetic = "CartoonBoing", Badge = "" },
	SaveGlider = { Id = 0, Name = "Emergency Glider", Price = 9, Icon = "🪂", Save = "Glider", Badge = "" },
	SaveAegis = { Id = 0, Name = "Aegis Bubble", Price = 15, Icon = "🛡️", Save = "Aegis", Badge = "" },
}

-- Cosmetics: one free starter, one coin item and Robux items per category.
local Cosmetics: { Types.CosmeticDefinition } = {
	-- God Skins: a giant sky avatar that hovers over the God's reticle for everyone to see
	{ Id = "StormEye", Category = "GodSkin", Name = "Storm Eye", Icon = "👁️", Description = "The all-seeing storm", Color = Color3.fromRGB(90, 170, 255) },
	{ Id = "StoneFist", Category = "GodSkin", Name = "Stone Fist", Icon = "✊", Description = "A mountain comes down", Color = Color3.fromRGB(150, 140, 130), Coins = 3000 },
	{ Id = "MagmaClaw", Category = "GodSkin", Name = "Magma Claw", Icon = "🔥", Description = "Molten talons", Color = Color3.fromRGB(255, 110, 30), Product = "SkinMagmaClaw" },
	{ Id = "CyberGauntlet", Category = "GodSkin", Name = "Cyber Gauntlet", Icon = "🤖", Description = "Neon steel fist", Color = Color3.fromRGB(60, 230, 255), Product = "SkinCyberGauntlet" },
	{ Id = "CelestialMask", Category = "GodSkin", Name = "Celestial Mask", Icon = "🌟", Description = "A golden deity watches", Color = Color3.fromRGB(255, 205, 60), Product = "SkinCelestialMask" },
	-- Disaster FX: recolours / reshapes your disasters as God
	{ Id = "ClassicFx", Category = "Vfx", Name = "Classic", Icon = "⚡", Description = "Storm blue and fire", Color = Color3.fromRGB(120, 200, 255) },
	{ Id = "GoldenWrath", Category = "Vfx", Name = "Golden Wrath", Icon = "✨", Description = "Everything in gold", Color = Color3.fromRGB(255, 200, 40), Coins = 2500 },
	{ Id = "NeonVoid", Category = "Vfx", Name = "Neon Void", Icon = "🟣", Description = "Void bolts, black meteors", Color = Color3.fromRGB(150, 60, 255), Product = "FxNeonVoid" },
	{ Id = "PixelChaos", Category = "Vfx", Name = "Pixel Chaos", Icon = "👾", Description = "Voxel meteors, arcade bolts", Color = Color3.fromRGB(120, 255, 90), Product = "FxPixelChaos" },
	-- Finishers: plays where you are eliminated
	{ Id = "Poof", Category = "Finisher", Name = "Poof", Icon = "💨", Description = "A puff of smoke", Color = Color3.fromRGB(190, 190, 200) },
	{ Id = "GhostRise", Category = "Finisher", Name = "Ghost Rise", Icon = "👻", Description = "Your ghost floats away", Color = Color3.fromRGB(220, 230, 255), Coins = 2000 },
	{ Id = "ConfettiPop", Category = "Finisher", Name = "Confetti Pop", Icon = "🎉", Description = "Go out with a party", Color = Color3.fromRGB(255, 120, 200), Product = "FinConfettiPop" },
	{ Id = "CartoonBoing", Category = "Finisher", Name = "Cartoon Boing", Icon = "🌀", Description = "Boing! Float off like a toon", Color = Color3.fromRGB(255, 220, 60), Product = "FinCartoonBoing" },
}

local VfxPacks: { [string]: Types.VfxPack } = {
	ClassicFx = {},
	GoldenWrath = { Bolt = Color3.fromRGB(255, 225, 120), Telegraph = Color3.fromRGB(255, 200, 40), Meteor = Color3.fromRGB(255, 190, 40), Tornado = Color3.fromRGB(230, 190, 90), Lava = Color3.fromRGB(255, 200, 60) },
	NeonVoid = { Bolt = Color3.fromRGB(170, 60, 255), Telegraph = Color3.fromRGB(200, 60, 255), Meteor = Color3.fromRGB(40, 10, 60), Tornado = Color3.fromRGB(70, 30, 110), Lava = Color3.fromRGB(150, 40, 255) },
	PixelChaos = { Bolt = Color3.fromRGB(120, 255, 90), Telegraph = Color3.fromRGB(255, 70, 200), Meteor = Color3.fromRGB(120, 255, 90), MeteorShape = Enum.PartType.Block, Tornado = Color3.fromRGB(255, 90, 210), Lava = Color3.fromRGB(120, 255, 90) },
}

local Passes: { [string]: Types.PassDefinition } = {
	DoubleCoins = { Id = 2083112404, Name = "2x Coins", Price = 199, Icon = "💸", Description = "Double coins from every source" },
	VIP = { Id = 2081360408, Name = "VIP", Price = 249, Icon = "👑", Description = "VIP tag, rainbow dash, +15 coins a round" },
	GodPriority = { Id = 2082224405, Name = "God Priority", Price = 299, Icon = "⚜️", Description = "God Chance grows twice as fast" },
	QuickDash = { Id = 2082770401, Name = "Quick Dash", Price = 99, Icon = "💨", Description = "Dash cooldown cut in half" },
}

local Config = {
	Match = {
		MinPlayers = 1, -- 1 keeps Play Solo fully playable
		IntermissionDuration = 20, -- map vote, then the build + countdown
		RoundDuration = 85,
		PrepDuration = 10, -- survivors scatter, God charges energy
		SuddenDeathDuration = 20, -- final seconds: rising fluid + double regen
		RoundEndDuration = 8,
		RespawnDelay = 2,
		AllowSoloRoleToggle = true, -- 1 player: toggle Survivor <-> God on the fly
		MaxSpawnSpread = 4,
	},

	-- lobby map vote at the start of every intermission
	Voting = {
		Duration = 9,
		Candidates = 3,
		PadRadius = 6,
		CountInterval = 0.3,
	},

	Pity = {
		BaseWeight = 1,
		PerRoundParticipated = 1,
		SurvivedBonus = 0.5,
	},

	Player = {
		MaxHealth = 100,
		WalkSpeed = 18,
		JumpPower = 50,
		KillPlaneY = -14,
		HazardFloorDamagePerSecond = 40,
		LobbyFallResetDepth = 60,
	},

	Mobility = {
		DashSpeed = 75,
		DashDuration = 0.18,
		DashCooldown = 2.5,
		DashFovKick = 14,
		MantleReach = 4,
		MantleHeight = 6,
		MantleBoost = 42,
	},

	Chaos = {
		Max = 100,
		StartEnergy = 25,
		RegenPerSecond = 8, -- raised with the bigger, more numerous buildings
		SuddenDeathRegenMultiplier = 2,
	},

	Director = {
		MinInterval = 3,
		MaxInterval = 6,
		SuddenDeathIntervalScale = 0.6,
		TargetJitter = 10,
		MajorChance = 0.35,
	},

	-- Hide-and-seek. A survivor standing still under an intact roof (or inside a jammed
	-- zone) is Hidden: the God loses their through-wall name tag and the anti-camp radar
	-- ignores them. Jumping, dashing, gear, emotes and launch pads make a noise ripple
	-- that only the God sees.
	Stealth = {
		CheckInterval = 0.25,
		StillSpeed = 3, -- studs/s; slower than this counts as still
		HideDelay = 1, -- seconds still (and indoors) before hidden
		RoofCheckHeight = 45, -- an intact structural part this far overhead = indoors
		JumpNoiseSpeed = 22, -- upward speed that counts as a jump
		RunNoiseSpeed = 30, -- horizontal speed that counts as a dash
		NoiseCooldown = 1.2,
		NoiseRippleRadius = 22, -- God-side ripple size for strength 1
		GlassNoiseRadius = 10, -- survivors this close to a shattering window make noise
	},

	-- Interactive map props (positions in World/Props.luau).
	Props = {
		JamRadius = 30,
		JamDuration = 12,
		BreakerHold = 1.2,
		BreakerCooldown = 35,
		LaunchUp = 95,
		LaunchForward = 32,
		LaunchCooldown = 2.5,
		VaultHealth = 450, -- per part: survives one Meteor or Lightning hit, caves on the second
	},

	-- Disasters reacting to the world and to each other.
	Combos = {
		MetalReach = 1.6, -- x the strike radius: metal parts this close conduct the bolt
		MetalMaxArcs = 8,
		MetalShockRadius = 7, -- survivors this close to a charged metal part
		ShockDamage = 25,
		WaterShockRadius = 45, -- a bolt at the rising water line shocks swimmers this close
		WaterShockMargin = 4, -- strike within this many studs of the fluid surface
		WaterShockDamage = 30,
		FireRadius = 6, -- burning patches dropped by a firenado
		FireDuration = 5,
		FireDamage = 6, -- per FireTick
		FireTick = 0.5,
		FireDropInterval = 0.5,
		PuddleRadius = 16,
		PuddleDuration = 14,
		WetKnockback = 1.6, -- knockback multiplier while standing in a puddle
		PuddleSources = { "WaterTower", "PipeGantry" } :: { string },
	},

	Cosmetics = {
		Items = Cosmetics,
		VfxPacks = VfxPacks,
		Defaults = { GodSkin = "StormEye", Vfx = "ClassicFx", Finisher = "Poof" } :: { [string]: string },
		SkyHeight = 70, -- studs above the reticle the God skin hovers
		SkyFollow = 6, -- lerp speed toward the reticle
		SkyScale = 1, -- skin size multiplier in the sky
		GodSkyTransparency = 0.8, -- how see-through the God sees their own skin
		AimSendRate = 6, -- reticle updates per second sent to the server
		DisplayScale = 0.16, -- lodge display statues
		BoingUpSpeed = 70, -- Cartoon Boing: the body is flung up and floats
		BoingFloatSeconds = 3,
	},

	-- Panic saves: cheap single-use charges that fire automatically.
	Saves = {
		GliderDropBelow = 14, -- trigger when this close above the kill plane and falling...
		GliderFallSpeed = -25, -- ...faster than this, or when sinking into the rising fluid
		GliderLaunchUp = 110,
		GliderLaunchForward = 35, -- toward the map centre
		GliderFloatSeconds = 4,
		GliderGravityScale = 0.35,
		AegisShieldSeconds = 2.5,
		AegisHealth = 30, -- health left after the bubble absorbs a fatal hit
		Cooldown = 4, -- a charge can't fire twice inside this window
		OfferSeconds = 8, -- "this would have saved you" card after a preventable death
	},

	-- Last Stand: the final survivor of a round that started with 2+ gets a showdown.
	Showdown = {
		MinSecondsLeft = 15, -- only triggers with at least this much of the round left
		ZoneInterval = 5, -- the God is shown the survivor's general zone this often
		ZoneRadius = 40,
		ZoneJitter = 22, -- the zone centre is offset up to this far from the survivor
		DashCooldownScale = 0.5, -- dash recharges twice as fast
		NearMissMultiplier = 2,
		HeartbeatVolume = 0.7,
	},

	-- Daredevil taunts: emoting while Hidden pings you to the God for a coin multiplier.
	Emotes = {
		Cooldown = 8,
		BubbleSeconds = 2.5,
		DaredevilSeconds = 10,
		DaredevilMultiplier = 1.5, -- on every coin award during the window
		RevealSeconds = 1.5, -- the God sees a daredevil's silhouette this long
		List = {
			{ Id = "Wave", Icon = "👋", Label = "Wave", Emote = "wave" },
			{ Id = "Whistle", Icon = "😗", Label = "Whistle", Emote = "point", Sound = "Whistle" },
			{ Id = "Scream", Icon = "😱", Label = "Scream", Sound = "Scream" },
			{ Id = "Dance", Icon = "🕺", Label = "Dance", Emote = "dance2" },
		} :: { { Id: string, Icon: string, Label: string, Emote: string?, Sound: string? } },
	},

	-- Kill feed and clutch callouts.
	Feed = {
		MaxLines = 5,
		LineSeconds = 6,
		CauseWindow = 6, -- a hit this recent names the cause of death
		CrushWindow = 4, -- dying this soon after a building collapsed on you = flattened
		ClutchMargin = 3, -- near misses within this many studs are announced
		ClutchCooldown = 4, -- per player
		FinalKillHold = 2.4, -- seconds the final-kill camera plays before the round ends
		Phrases = {
			Lightning = "was struck by Lightning",
			["Chain Bolt"] = "was fried by a Chain Bolt",
			Gust = "was blown away",
			Meteors = "was crushed by Meteors",
			Tornado = "was swept up by a Tornado",
			["Fault Cleave"] = "fell into the Fault Cleave",
			Eruption = "was launched by an Eruption",
			Lava = "melted in the lava",
			Glitch = "was glitched out of existence",
			Firenado = "was torched by a Firenado",
			["Conducted Lightning"] = "was electrocuted",
			["Electrified Water"] = "was electrocuted in the water",
			Explosion = "was blown up",
			Void = "fell into the void",
			Quicksand = "sank in the quicksand",
			HazardFloor = "touched the burning floor",
		} :: { [string]: string },
	},

	AntiCamp = {
		CheckInterval = 1,
		StationaryTime = 8,
		StationaryRadius = 6,
		RevealDuration = 3,
	},

	-- last survivor standing in the final seconds gets pinged for the God
	HunterPulse = {
		LastSeconds = 20,
		Interval = 4,
		Duration = 2.5,
	},

	SuddenDeath = {
		FluidDamagePerSecond = 30,
	},

	-- hard knockback turns survivors into ragdolls for a moment
	Ragdoll = {
		MinKnockback = 55,
		Duration = 1.6,
		Spin = 6,
	},

	Juice = {
		CollapseShakeBase = 0.35,
		CollapseShakePerStud = 0.012,
		CollapseShakeMax = 1.3,
		ImpactFovKick = 7,
		ImpactThreshold = 0.75, -- shake intensity that also triggers the FOV punch
	},

	Disasters = {
		Abilities = Abilities,
		UniversalAbilities = { "SeismicPing" }, -- added to every kit as hotbar slot 6
		PostImpactLinger = 0.6,
	},

	Kits = Kits,
	DefaultKit = "Architect",

	Spin = {
		Rewards = SpinRewards,
		FreeIntervalSeconds = 600,
		VipIntervalMultiplier = 0.5, -- VIP earns free spins twice as fast
		MaxBankedFree = 3, -- free spins stop accruing at this many banked
		StarterSpins = 1,
		SpinSeconds = 4.2,
		ExtraTurns = 5,
	},

	Quests = {
		Pool = QuestPool,
		RandomPerDay = 2,
		MapQuestReward = 120,
		AllDoneSpins = 1,
		DaySeconds = 86400,
	},

	Leaderboards = {
		RefreshSeconds = 60,
		Template = "TimePlayedLeaderboard", -- workspace model the extra boards are cloned from
		-- Hall of Legends podium in the lodge: the all-time top three of this stat stand on it
		Hall = { Stat = "RoundsSurvived", Unit = "rounds", Subtitle = "Most rounds survived · all time" },
		Boards = {
			{ Stat = "RoundsSurvived", Title = "TOP SURVIVORS", Unit = "rounds" },
			{ Stat = "GodKills", Title = "DEADLIEST GODS", Unit = "kills" },
			{ Stat = "BestStreak", Title = "LONGEST STREAKS", Unit = "in a row" },
		},
	},

	Onboarding = {
		CardDelay = 3, -- shown after the round-start banner clears
		CardSeconds = 15,
	},

	Destruction = {
		DefaultHealth = 100,
		MaterialHealth = {
			Glass = 25,
			Neon = 30,
			Grass = 40,
			Wood = 60,
			WoodPlanks = 60,
			SmoothPlastic = 90,
			Plastic = 90,
			Brick = 140,
			Concrete = 160,
			Metal = 200,
			DiamondPlate = 200,
			CorrodedMetal = 180,
			Ice = 70,
			Snow = 40,
			Sandstone = 150,
			Basalt = 300,
			Marble = 180,
			Fabric = 35,
			Slate = 220,
		} :: { [string]: number },
		CollapseSupportFraction = 0.7, -- level collapses when intact supports drop below this
		BreakImpulse = 45,
		BuckleImpulse = 30, -- sideways kick for a failing level's last supports
		BuckleNoCollideTime = 1, -- seconds those supports pass through the falling floors
		DirectedFallSpeed = 16, -- push for buildings with a FallDirection (obelisks, billboards, wheel)
		DirectedTipSpin = 1.6, -- rad/s tip-over spin for directed falls
		DebrisLifetime = 9, -- seconds debris stays solid
		DebrisLifetimeJitter = 3,
		DebrisFadeTime = 2.5, -- then it ghosts through players, shrinks and fades
		DebrisFadeScale = 0.35,
		MaxDebris = 600,
		CreakCooldown = 2.5,
		VolatileRadius = 16,
		VolatileStructureDamage = 300,
		VolatilePlayerDamage = 45,
	},

	-- Debris performance. Small non-load-bearing pieces (wall panels, glass, trim) become
	-- client-only rubble; floors, supports and collapsing slabs stay on the server so
	-- collisions stay fair. Settled server debris goes to sleep (anchored, no queries).
	Debris = {
		ClientMaxVolume = 60, -- non-support parts up to this many cubic studs shatter client-side
		ClientMaterials = { Glass = true, Neon = true, Fabric = true, Grass = true } :: { [string]: boolean },
		ClientLifetime = 7, -- seconds before a client rubble piece fades (desktop)
		TouchClientLifetime = 4.5, -- phones / tablets
		ClientFadeTime = 1.5,
		ClientCap = 220, -- active client rubble pieces (desktop)
		TouchClientCap = 80,
		SleepSpeed = 1.5, -- studs/s (and rad/s) below which server debris counts as resting
		SleepSeconds = 2, -- resting this long -> anchored, CanTouch/CanQuery off
		TouchParticleRate = 0.5, -- particle emitter rate multiplier on touch devices
		TouchParticleLifetime = 0.6,
		TouchTrailLifetime = 0.5,
		TouchFireSize = 0.7,
	},

	Scoring = {
		NearMissMargin = 7,
		NearMissCoins = 25,
		StructuralEscapeCoins = 50,
		StructuralEscapeWindow = 3,
		SurvivalCoins = 40,
		StreakBonusPerRound = 10,
		ParticipationCoins = 10,
		GodKillCoins = 30,
		GodDestructionCoinsPerPart = 0.25,
		ObbyCoins = 15,
		ObbyCooldown = 20,
		GhostPingCooldown = 5,
		KillCreditWindow = 4,
	},

	Gear = Gear,

	Monetization = {
		Products = Products,
		Passes = Passes,
		DoubleCoinsMultiplier = 2,
		VipBonusCoinsPerRound = 15,
		GodPriorityPityMultiplier = 2,
		QuickDashCooldownMultiplier = 0.5,
		ReviveFallbackCoins = 250,
		ReviveOfferSeconds = 10,
		WelcomePackListPrice = 40, -- shown struck-through next to the real price
		ReceiptHistory = 50, -- purchase ids remembered per profile for idempotency
	},

	-- Licensed audio (APM Music / Pro Sound Effects / Distrokid + verified-loading community SFX).
	-- Numbers are asset ids; strings are built-in rbxasset paths.
	Audio = {
		Music = {
			Lobby = 9045802707, -- "Some Happy for Ya" (APM)
			Round = 9045941481, -- "Mission Danger" (APM)
			SuddenDeath = 9044584220, -- "Evil Overlord (B)" (APM)
		},
		Stings = {
			RoundStart = 9043151109, -- "Get Up And Go - Hit" (APM)
			GodChosen = 9045702179, -- "Roll With The Punches" (APM)
			Win = 1840076509, -- "Through the Roof (sting)" (APM)
			Lose = 1841391669, -- "Wipsy La La Sting 3" (APM)
		},
		Ambience = {
			Lobby = 9112749076, -- Birds Park (PSE)
			FractureBay = 9120621792, -- Waves Rolling (PSE)
			NeoShibuya = 9112757705, -- City Ambience night (PSE)
			MagmaCore = 9112823552, -- Lava Rumble (PSE)
			SunscorchedMirage = 9125742262, -- airy desert wind (PSE)
			OutpostZero = 81404060588532, -- Howling Wind
			StarlightBoardwalk = 9118695887, -- Roller Coaster crowd (PSE)
		} :: { [string]: number },
		AmbienceLayer = {
			StarlightBoardwalk = 9117143228, -- Ocean Surf (PSE)
			OutpostZero = 9120621792, -- Waves Rolling (PSE)
		} :: { [string]: number },
		Ui = {
			Click = "rbxasset://sounds/clickfast.wav",
			Tab = "rbxasset://sounds/button.wav",
			Open = 9119467553, -- short whoosh (PSE)
			Coin = 93529351909119,
			Purchase = 91609406292294,
			Tick = 93396079703045,
			Tock = 71549972318782,
			Banner = 9119468100, -- spirit pass-by whoosh (PSE)
			Error = "rbxasset://sounds/electronicpingshort.wav",
		} :: { [string]: number | string },
		Disaster = {
			Warning = 125227661736774,
			Lightning = 93403424380357,
			Thunder = 95410087861011,
			MeteorFall = 9119467553,
			MeteorImpact = 7157159568,
			Explosion = 125127520917980,
			Tornado = 9125443744, -- swirling rumble loop (PSE)
			Gust = 9119468100,
			Rumble = 9113221477, -- avalanche rumble (PSE)
			Collapse = 9120479801, -- wall crash (PSE)
			Debris = 9114221795, -- earthquake debris (PSE)
			Glass = 132535085898211,
			SuddenDeathAlarm = 125227661736774,
			Siren = 9113073742, -- air raid siren (PSE)
			Creak = 9116638731, -- metal groans (PSE)
			Heartbeat = 9043365842, -- "HEARTBEAT 02 96BPM" (APM), Last Stand loop
			Whistle = 9120675895, -- "Whistle Calling 4" (PSE), taunt
			Scream = 9125652432, -- "Male Scream Short Yelling Bursts" (PSE), taunt
			Boing = 2772396665, -- cartoon boing (short public clip), Cartoon Boing finisher
		} :: { [string]: number },
		-- distinct telegraph cue per disaster so survivors can react by ear
		AbilityCue = {
			Lightning = { Key = "Thunder", Volume = 0.7, Speed = 1.6 },
			ChainLightning = { Key = "Thunder", Volume = 0.8, Speed = 2 },
			Gust = { Key = "Gust", Volume = 1.2, Speed = 1.4 },
			Meteor = { Key = "MeteorFall", Volume = 1.6, Speed = 0.5 },
			Tornado = { Key = "Gust", Volume = 1.6, Speed = 0.6 },
			FaultCleave = { Key = "Rumble", Volume = 1.2, Speed = 1.3 },
			Eruption = { Key = "Rumble", Volume = 1.6, Speed = 0.8 },
			Glitch = { Key = "Glass", Volume = 1.2, Speed = 0.6 },
		} :: { [string]: { Key: string, Volume: number, Speed: number } },
		SirenVolume = 0.35,
		Volume = {
			Music = 0.3,
			Ambience = 0.45,
			Ui = 0.6,
			Disaster = 1,
		},
		CrossfadeSeconds = 2.5,
		CountdownTicks = 5, -- intermission seconds that tick
		CollapseSoundCooldown = 0.4,
		GlassSoundCooldown = 0.25,
		RollOffMaxDistance = 700,
	},

	Hazards = {
		QuicksandDamagePerSecond = 8,
		QuicksandWalkSpeed = 7,
		VentDamagePerSecond = 25,
	},

	GearTuning = {
		SpeedSodaWalkSpeed = 34,
		GliderGravityScale = 0.3,
		ShieldShockwaveRadius = 14,
	},

	World = {
		ArenaCenter = Vector3.new(0, 0, 0),
		ArenaRadius = 175,
		LobbyOrigin = Vector3.new(0, 150, -232), -- close + low enough that the balcony overlooks the arena
		GodPerch = Vector3.new(0, 150, 0),
		MapRotation = { "FractureBay", "NeoShibuya", "MagmaCore", "SunscorchedMirage", "OutpostZero", "StarlightBoardwalk" },
		MapDisplayNames = {
			FractureBay = "Fracture Bay",
			NeoShibuya = "Neo-Shibuya Skyline",
			MagmaCore = "Magma Core Station",
			SunscorchedMirage = "Sunscorched Mirage",
			OutpostZero = "Outpost Zero",
			StarlightBoardwalk = "Starlight Boardwalk",
		} :: { [string]: string },
		BuildYieldEvery = 150, -- parts created before yielding a frame
	},

	Camera = {
		GodPitch = math.rad(58),
		GodStartZoom = 150,
		GodMinZoom = 50,
		GodMaxZoom = 260,
		GodPanSpeed = 110,
		GodRotateSpeed = 1.8,
		ShakeDecay = 4,
	},

	-- Attribute names used to replicate state to clients.
	Attributes = {
		RoundPhase = "RoundPhase", -- ReplicatedStorage
		SubPhase = "SubPhase", -- ReplicatedStorage
		TimeRemaining = "RoundTimeRemaining", -- ReplicatedStorage
		PhaseDuration = "PhaseDuration", -- ReplicatedStorage
		RoundNumber = "RoundNumber", -- ReplicatedStorage
		MapName = "MapName", -- ReplicatedStorage
		MapKey = "MapKey", -- ReplicatedStorage (builder name, drives ambience)
		AliveCount = "AliveCount", -- ReplicatedStorage
		GodName = "GodName", -- ReplicatedStorage
		CastingOpen = "CastingOpen", -- ReplicatedStorage
		Role = "Role", -- Player
		Alive = "Alive", -- Player
		GodChance = "GodChance", -- Player (0-100)
		PreferredRole = "PreferredRole", -- Player (solo toggle)
		Coins = "Coins", -- Player
		Streak = "Streak", -- Player
		ChaosEnergy = "ChaosEnergy", -- Player (God)
		CooldownPrefix = "CD_", -- Player (God): server time when ability is ready
		GearPrefix = "Gear_", -- Player: owned count
		PassPrefix = "Pass_", -- Player: owns game pass (bool)
		WelcomeClaimed = "WelcomeClaimed", -- Player
		GodQueued = "GodQueued", -- Player: bought "God next round"
		Spins = "Spins", -- Player: wheel spins banked
		FreeSpinAt = "FreeSpinAt", -- Player: server time the next free spin lands
		QuestState = "QuestState", -- Player: JSON of today's quests
		Kit = "Kit", -- Player: equipped God kit id
		KitPrefix = "Kit_", -- Player: owns kit (bool)
		RoundsPlayed = "RoundsPlayed", -- Player
		TutorialPrefix = "Tut_", -- Player: has seen the role card (bool)
		Ragdolled = "Ragdolled", -- Player
		VoteOpen = "VoteOpen", -- ReplicatedStorage: map vote in progress
		Slowed = "Slowed", -- Player: standing in quicksand
		Hidden = "Hidden", -- Player: hidden from the God (still indoors, or jammed)
		LastStand = "LastStand", -- ReplicatedStorage: display name of the last survivor ("" = none)
		LastStander = "LastStander", -- Player: is the Last Stand survivor (dash + near-miss buffs)
		DaredevilUntil = "DaredevilUntil", -- Player: server time the taunt coin bonus ends
		CosmeticPrefix = "Cos_", -- Player: owns cosmetic (bool)
		EquipPrefix = "Equip_", -- Player: equipped cosmetic id per category
		SavePrefix = "Save_", -- Player: panic save charges
		GodAim = "GodAim", -- ReplicatedStorage: the human God's reticle (Vector3), nil when none
		GodSkin = "GodSkin", -- ReplicatedStorage: the human God's equipped skin id ("" = none)
	},
}

return table.freeze(Config)
