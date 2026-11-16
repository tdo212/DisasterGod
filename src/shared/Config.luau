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
		Cooldown = 3,
		WarningTime = 1.5,
		Radius = 10,
		PlayerDamage = 42, -- three hits to kill, not two
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
		StructureDamage = 70,
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
		PlayerDamage = 40,
		StructureDamage = 260,
		Count = 6,
		ImpactRadius = 12,
	},
	{
		Id = "Tornado",
		DisplayName = "Tornado",
		Icon = "🌪️",
		Tier = "Major",
		Cost = 50,
		Cooldown = 15,
		WarningTime = 2,
		Radius = 20,
		PlayerDamage = 0,
		StructureDamage = 170, -- per second
		Duration = 9,
		Speed = 19,
		TickDamage = 11,
		Knockback = 70,
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
		Cooldown = 7,
		WarningTime = 1.3,
		Radius = 16,
		PlayerDamage = 15,
		StructureDamage = 115,
		Knockback = 70,
	},
	-- big-map disasters (the Cataclysm kit; the AI Director uses them too)
	{
		Id = "GravitySingularity",
		DisplayName = "Singularity",
		Icon = "🕳️",
		Tier = "Major",
		Cost = 50,
		Cooldown = 15,
		WarningTime = 1,
		Radius = 28, -- pull radius
		PlayerDamage = 35,
		StructureDamage = 230,
		Knockback = 75, -- outward blast at the end
		Duration = 2.5, -- seconds of pull before it detonates
		ImpactRadius = 16, -- detonation radius
		Pull = 38, -- inward speed (studs / s) at the rim
	},
	{
		Id = "TectonicSpire",
		DisplayName = "Tectonic Spire",
		Icon = "🗻",
		Tier = "Major",
		Cost = 45,
		Cooldown = 15,
		WarningTime = 1.4,
		Radius = 14,
		PlayerDamage = 30,
		StructureDamage = 320, -- smashes up through floors
		Knockback = 95, -- straight up
		Count = 5, -- pillars
		Length = 46, -- pillar height
	},
	{
		Id = "ChainArc",
		DisplayName = "Chain Arc",
		Icon = "🔗",
		Tier = "Major",
		Cost = 35,
		Cooldown = 10,
		WarningTime = 0.8,
		Radius = 10,
		PlayerDamage = 30,
		StructureDamage = 110,
		Count = 4, -- jumps after the first hit
		Length = 32, -- max jump distance (through walls: punishes groups hiding together)
		Duration = 0.25, -- seconds per jump
	},
	{
		Id = "MeteorBarrage",
		DisplayName = "Meteor Barrage",
		Icon = "🎯",
		Tier = "Major",
		Cost = 40,
		Cooldown = 13,
		WarningTime = 1.6,
		Radius = 9,
		PlayerDamage = 30,
		StructureDamage = 230,
		Count = 7, -- impacts rolling along the line
		ImpactRadius = 9,
		Length = 80, -- the line runs along your camera's facing
		Width = 12,
		Duration = 0.18, -- seconds between impacts
	},
	-- God Pack signatures (Config.GodPacks): each one costs and cools down exactly like the
	-- ability it replaces, so a pack changes the playstyle, never the power.
	{
		Id = "PyroclastSurge",
		DisplayName = "Pyroclast Surge",
		Icon = "🌊",
		Tier = "Major",
		Signature = true,
		Cost = 65,
		Cooldown = 18,
		WarningTime = 2.5,
		Radius = 8,
		PlayerDamage = 40,
		StructureDamage = 300, -- wood takes double
		Length = 100,
		Width = 12,
		Speed = 22, -- the lava wave rolls forward at this speed
	},
	{
		Id = "SystemOverride",
		DisplayName = "System Override",
		Icon = "📵",
		Tier = "Minor",
		Signature = true,
		Cost = 12,
		Cooldown = 2.5,
		WarningTime = 1.5,
		Radius = 14,
		PlayerDamage = 25,
		StructureDamage = 140,
		Duration = 3, -- dash jammed + screen scrambled
	},
	{
		Id = "AstralCollapse",
		DisplayName = "Astral Collapse",
		Icon = "🌌",
		Tier = "Major",
		Signature = true,
		Cost = 40,
		Cooldown = 10,
		WarningTime = 2,
		Radius = 26,
		PlayerDamage = 40,
		StructureDamage = 240,
		Knockback = 110, -- mostly upward
		Duration = 2,
		ImpactRadius = 15,
		Pull = 34,
	},
	{
		Id = "MaelstromVortex",
		DisplayName = "Maelstrom Vortex",
		Icon = "🌀",
		Tier = "Major",
		Signature = true,
		Cost = 50,
		Cooldown = 15,
		WarningTime = 2,
		Radius = 20,
		PlayerDamage = 0,
		StructureDamage = 170,
		Duration = 9,
		Speed = 23, -- follows your reticle instead of chasing survivors
		TickDamage = 11,
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
	{ Id = "Cataclysm", Name = "Cataclysm", Icon = "🕳️", Description = "Singularities, spires, barrages", Price = 3500, Color = Color3.fromRGB(120, 80, 255), Abilities = { "MeteorBarrage", "TectonicSpire", "ChainArc", "GravitySingularity", "Gust" } },
	{ Id = "Glitch", Name = "Cyber Glitch", Icon = "👾", Description = "Glitch pulses and chain bolts", Price = 4000, Color = Color3.fromRGB(255, 60, 200), Abilities = { "Glitch", "ChainLightning", "Lightning", "Tornado", "FaultCleave" } },
}

-- God Packs: a GodSkin cosmetic that also swaps one ability for its signature version
-- (shared/Loadout) and brings a matching elimination finisher. Same cost, same cooldown.
local GodPacks: { [string]: Types.GodPack } = {
	MagmaClaw = { Replaces = "FaultCleave", Signature = "PyroclastSurge", Finisher = "LavaBurst", Synergy = "Fires burn twice as long", FireDurationScale = 2 },
	CyberGauntlet = { Replaces = "Lightning", Signature = "SystemOverride", Finisher = "VoxelDissolve", Synergy = "Jams survivors' dash" },
	CelestialMask = { Replaces = "Meteor", Signature = "AstralCollapse", Finisher = "SkyBeam", Synergy = "Huge vertical launches" },
	StormSovereign = { Replaces = "Tornado", Signature = "MaelstromVortex", Finisher = "StormBolt", Synergy = "Puts out fires, flings rubble" },
}

-- Spin wheel segments. Odds shown to players are Weight / total weight.
local SpinRewards: { Types.SpinReward } = {
	{ Id = "God", Label = "GOD", Icon = "😈", Kind = "God", Amount = 1, Weight = 8, Color = Color3.fromRGB(125, 45, 215) },
	{ Id = "Jackpot", Label = "1,500", Icon = "🏆", Kind = "Coins", Amount = 1500, Weight = 12, Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "Coins400", Label = "400", Icon = "💰", Kind = "Coins", Amount = 400, Weight = 25, Color = Color3.fromRGB(150, 65, 235) },
	{ Id = "Kit", Label = "KIT", Icon = "🎒", Kind = "Kit", Amount = 1, Weight = 20, Color = Color3.fromRGB(255, 210, 60) },
	{ Id = "Coins150", Label = "150", Icon = "🪙", Kind = "Coins", Amount = 150, Weight = 35, Color = Color3.fromRGB(185, 120, 255) },
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
	{ Id = "Survive2", Text = "Survive 2 rounds", Stat = "Survive", Goal = 2, Reward = 120 },
	{ Id = "Dash12", Text = "Use Dash 12 times", Stat = "Dash", Goal = 12, Reward = 80 },
	{ Id = "Smash25", Text = "Smash 25 parts as God", Stat = "Destroy", Goal = 25, Reward = 90 },
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
	-- cosmetics and panic saves (created through Open Cloud). A new product can start with
	-- Id = 0: it shows as SOON in the shop and is skipped by ProcessReceipt until set.
	SkinMagmaClaw = { Id = 3730856189, Name = "Magma Claw God Skin", Price = 149, Icon = "🔥", Cosmetic = "MagmaClaw", Badge = "" },
	SkinCyberGauntlet = { Id = 3730856191, Name = "Cyber Gauntlet God Skin", Price = 149, Icon = "🤖", Cosmetic = "CyberGauntlet", Badge = "" },
	SkinCelestialMask = { Id = 3730856195, Name = "Celestial Mask God Skin", Price = 199, Icon = "🌟", Cosmetic = "CelestialMask", Badge = "Legendary" },
	FxNeonVoid = { Id = 3730856203, Name = "Neon Void Disaster FX", Price = 99, Icon = "🟣", Cosmetic = "NeonVoid", Badge = "" },
	FxPixelChaos = { Id = 3730856205, Name = "Pixel Chaos Disaster FX", Price = 129, Icon = "👾", Cosmetic = "PixelChaos", Badge = "" },
	FinConfettiPop = { Id = 3730856210, Name = "Confetti Pop Finisher", Price = 99, Icon = "🎉", Cosmetic = "ConfettiPop", Badge = "" },
	FinCartoonBoing = { Id = 3730856215, Name = "Cartoon Boing Finisher", Price = 99, Icon = "🌀", Cosmetic = "CartoonBoing", Badge = "" },
	SaveGlider = { Id = 3730856220, Name = "Emergency Glider", Price = 9, Icon = "🪂", Save = "Glider", Badge = "" },
	SaveAegis = { Id = 3730856223, Name = "Aegis Bubble", Price = 15, Icon = "🛡️", Save = "Aegis", Badge = "" },
}

-- Cosmetics: one free starter, one coin item and Robux items per category.
local Cosmetics: { Types.CosmeticDefinition } = {
	-- God Skins: a giant sky avatar that hovers over the God's reticle for everyone to see
	{ Id = "StormEye", Category = "GodSkin", Name = "Storm Eye", Icon = "👁️", Description = "The all-seeing storm", Color = Color3.fromRGB(90, 170, 255) },
	{ Id = "StoneFist", Category = "GodSkin", Name = "Stone Fist", Icon = "✊", Description = "A mountain comes down", Color = Color3.fromRGB(150, 140, 130), Coins = 3000 },
	{ Id = "MagmaClaw", Category = "GodSkin", Name = "Magma Claw", Icon = "🔥", Description = "Signature: Pyroclast Surge", Color = Color3.fromRGB(255, 110, 30), Product = "SkinMagmaClaw" },
	{ Id = "CyberGauntlet", Category = "GodSkin", Name = "Cyber Gauntlet", Icon = "🤖", Description = "Signature: System Override", Color = Color3.fromRGB(60, 230, 255), Product = "SkinCyberGauntlet" },
	{ Id = "CelestialMask", Category = "GodSkin", Name = "Celestial Mask", Icon = "🌟", Description = "Signature: Astral Collapse", Color = Color3.fromRGB(255, 205, 60), Product = "SkinCelestialMask" },
	{ Id = "StormSovereign", Category = "GodSkin", Name = "Storm Sovereign", Icon = "🌩️", Description = "Signature: Maelstrom Vortex", Color = Color3.fromRGB(90, 150, 255), Coins = 7500 },
	{ Id = "Sunforged", Category = "GodSkin", Name = "Sunforged Hand", Icon = "☀️", Description = "Day-7 login streak exclusive", Color = Color3.fromRGB(255, 170, 40), Exclusive = true },
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
		IntermissionDuration = 30, -- lobby break, map vote, then the build + countdown
		LobbyBreak = 10, -- first seconds of intermission: free time to shop, spin and explore before the vote
		-- Final Rush: once only this share of the round's survivors is left (at least 1), the
		-- clock jumps to sudden death + FinalRushLead seconds, so the eliminated don't wait long
		FinalRushShare = 0.25,
		FinalRushLead = 10,
		RoundDuration = 85,
		PrepDuration = 10, -- survivors scatter, God charges energy
		SuddenDeathDuration = 20, -- final seconds: God Overdrive (double regen, siren); fluid only on a Flash Flood twist
		RoundEndDuration = 9,
		RespawnDelay = 2,
		AllowSoloRoleToggle = true, -- 1 player: toggle Survivor <-> God on the fly
		MaxSpawnSpread = 4,
	},

	-- lobby map vote at the start of every intermission
	Voting = {
		Duration = 9,
		Candidates = 3,
	},

	Pity = {
		NewPlayerRounds = 3, -- players with fewer rounds than this who have never been the God ...
		NewPlayerMultiplier = 6, -- ... get their God weight multiplied (+500%) so they get a God round early
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
		RegenDelay = 5, -- seconds without taking damage before a survivor starts healing
		RegenPerSecond = 4,
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

	-- Ghost bolts: eliminated players (and mid-round joiners) in spectate click the arena to
	-- drop a small purple bolt after a short telegraph. It zaps survivors for a little damage
	-- and pays the ghost coins per survivor hit; it never credits kills or breaks buildings.
	Ghost = {
		Radius = 6,
		WarningTime = 1.2,
		Damage = 8,
		Cooldown = 8, -- per ghost
		GlobalGap = 1.2, -- seconds between any two ghost bolts (a crowd of ghosts can't swarm)
		HitCoins = 6,
	},

	-- God vs survivors balance (DisasterService / MatchService). The God should get some or
	-- most survivors, not always all of them: casts are spaced out, the God's Chaos Energy
	-- regen falls as the survivors thin out, and the last few take a little less damage.
	Balance = {
		CastGap = 0.6, -- seconds between any two casts (cooldowns are per ability)
		RegenFloor = 0.55, -- regen multiplier with 1 survivor left of many (1 = all still alive)
		GritAlive = 2, -- this many survivors or fewer left (of 3+) ...
		GritDamage = 0.8, -- ... take this share of disaster damage
		MaxHit = 48, -- no single disaster hit does more than this (fluid / void still kill)
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
		SkyHeight = 84, -- studs above the reticle the God skin hovers
		SkyFollow = 6, -- lerp speed toward the reticle
		SkyScale = 1.7, -- skin size multiplier in the sky (big enough to read from the ground)
		SkyOutline = 0.2, -- outline highlight transparency so the silhouette reads against any sky
		SkyLightRange = 60,
		GodSkyTransparency = 0.8, -- how see-through the God sees their own skin
		AimSendRate = 10, -- max reticle updates per second (UnreliableRemoteEvent GodAim)
		AimMinMove = 1.5, -- studs the reticle must move before another update is sent
		AimAttributeInterval = 0.5, -- the GodAim attribute (late joiners, Maelstrom steering) updates at most this often
		DirectorSkin = "StormEye", -- the AI Director's sky avatar, so solo rounds show a moving hand too
		DirectorDriftSeconds = 2.5, -- between casts the AI's hand drifts to a new random spot this often
		GestureSeconds = 0.45, -- cast gesture: slam down, flash, spring back
		GestureDrop = 14, -- studs the rig dips toward the target on a cast
		GodHideDistance = 70, -- the God's own skin hides when their camera is this close to it
		BankDegrees = 18, -- max tilt toward the direction of travel
		DisplayScale = 0.16, -- lodge display statues
		BoingUpSpeed = 70, -- Cartoon Boing: the body is flung up and floats
		BoingFloatSeconds = 3,
	},

	-- Nintendo-style game feel: forgiving inputs and clear feedback.
	Feel = {
		CoyoteTime = 0.12, -- a jump pressed this soon after walking off a ledge still jumps
		JumpBuffer = 0.15, -- a jump pressed this soon before landing fires on touchdown
		MercySeconds = 0.4, -- after a disaster hit, overlapping hits can't chain (character flickers)
		HardLandingSpeed = 55, -- falling faster than this gives a small camera thump
		LandingShake = 0.22,
		Countdown = 3, -- 3-2-1-GO! before disasters unlock
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
		TopOffset = 70, -- PC: feed right under the top-right currency bar
		TopOffsetTouch = 84, -- phones: just under the top-right wallet and streak line
		Dodge = Vector2.new(196, 112), -- phones, lobby: feed shifts this far left / sits this low beside the God card
		MaxLines = 5,
		LineSeconds = 6,
		CauseWindow = 6, -- a hit this recent names the cause of death
		CrushWindow = 4, -- dying this soon after a building collapsed on you = flattened
		ClutchMargin = 3, -- near misses within this many studs are announced
		ClutchCooldown = 4, -- per player
		FinalKillHold = 2.4, -- seconds the final-kill camera plays before the round ends
		EscapeCooldown = 5, -- one "escaped the collapsing X" per player per building in this window (multi-floor collapses)
		-- the God's kill confirm (KillConfirmController): hitmarker on the victim, sound, kill chip
		HitmarkerSeconds = 0.55,
		KillStreakWindow = 4, -- kills this close together count up DOUBLE / TRIPLE / MULTI KILL
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

	-- Chaos Twist: a free, server-rolled round mutator on some rounds (MutatorService).
	Mutators = {
		Chance = 0.2, -- of rounds, rolled right after the map vote
		Pool = {
			{ Id = "BouncyRubble", Name = "Bouncy Rubble", Icon = "🎲", Description = "Rubble bounces like rubber", Color = Color3.fromRGB(255, 120, 200) },
			{ Id = "GoldRush", Name = "Gold Rush", Icon = "🪙", Description = "Coins rain down and payouts are x1.5", Color = Color3.fromRGB(255, 210, 60) },
			{ Id = "BrittleTimber", Name = "Brittle Timber", Icon = "💥", Description = "Wood and glass break twice as fast", Color = Color3.fromRGB(230, 150, 80) },
			{ Id = "TwilightStorm", Name = "Twilight Storm", Icon = "⛈️", Description = "Darker skies, same bright warnings", Color = Color3.fromRGB(130, 140, 255) },
			{ Id = "Hyperdrive", Name = "Hyperdrive", Icon = "💨", Description = "Dash and Chaos Energy recharge 25% faster", Color = Color3.fromRGB(90, 230, 255) },
			{ Id = "AirDrops", Name = "Air Drops", Icon = "📦", Description = "Supply crates land mid-round", Color = Color3.fromRGB(120, 240, 120) },
			{ Id = "FlashFlood", Name = "Flash Flood", Icon = "🌊", Description = "The arena floods in sudden death: keep some high ground standing", Color = Color3.fromRGB(70, 170, 255) },
		} :: { { Id: string, Name: string, Icon: string, Description: string, Color: Color3 } },
		BouncyRestitution = 0.85,
		BrittleScale = 2, -- wood and glass structure damage
		BrittleMaterials = { "Wood", "WoodPlanks", "Glass" } :: { string },
		HyperdriveScale = 1.25, -- dash recharge and Chaos Energy regen speed
		GoldRushPayout = 1.5,
		GoldRushInterval = 4, -- seconds between falling coins
		GoldRushCoins = 6, -- per coin picked up
		GoldRushPerWave = 3,
		AirDropCount = { 2, 3 },
		AirDropSpeedSeconds = 6,
		AirDropSpeed = 30,
		AirDropCoins = 40,
		PickupLifetime = 20,
		BannerSeconds = 4,
	},

	-- God combos: chaining different disasters that each break things, or dropping a
	-- whole floor at once, pays bonus Chaos Energy and coins (DisasterService).
	GodCombo = {
		Window = 5, -- seconds between destructive casts to keep the chain alive
		MinParts = 3, -- a cast must break this many parts to count as a link
		EnergyPerLink = 6,
		CoinsPerLink = 8,
		MaxLinks = 5,
		CollapseEnergy = 10, -- a whole building / floor coming down
		CollapseCoins = 12,
		CollapseMinSize = 24, -- bounding-box diagonal: crates and lamps don't count
	},

	-- Late-round Emergency Flare on an exposed rooftop (MutatorService).
	Beacon = {
		StartAt = 30, -- seconds left in the round
		HoldSeconds = 4,
		Radius = 9,
		Coins = 150,
		Samples = 24, -- rooftop candidates tried
	},

	-- Stress cues before a weakened building gives way (DestructionService).
	Stress = {
		Margin = 0.15, -- within this much of the collapse fraction counts as "about to go"
		ShakeRadius = 45,
		Shake = 0.25,
		Cooldown = 1.2,
	},

	-- Spectator cheers / aid: eliminated or waiting players spend coins (ProgressionService).
	Cheers = {
		Cheer = { Cost = 10, Icon = "🎆", Name = "Cheer" },
		Berry = { Cost = 25, Icon = "🫐", Name = "Speed Berry", Speed = 26, Seconds = 5 },
		Bandage = { Cost = 25, Icon = "🩹", Name = "Bandage", Heal = 30 },
		Cooldown = 6,
	},

	-- Mastery tracks: counters on the profile unlock tiered titles shown over your head.
	Mastery = {
		Tracks = {
			{ Id = "Runner", Stat = "Survive", Name = "Runner", Tiers = { 1, 5, 15, 40, 100 }, Color = Color3.fromRGB(120, 240, 120) },
			{ Id = "Ghost", Stat = "Ghost", Name = "Ghost Walker", Tiers = { 1, 5, 20 }, Color = Color3.fromRGB(190, 220, 255) },
			{ Id = "Daredevil", Stat = "Taunts", Name = "Daredevil", Tiers = { 10, 50, 200 }, Color = Color3.fromRGB(255, 90, 160) },
			{ Id = "Demolisher", Stat = "Destroy", Name = "Demolisher", Tiers = { 500, 2500, 10000 }, Color = Color3.fromRGB(255, 150, 60) },
			{ Id = "Architect", Stat = "GodWin:Architect", Name = "Architect", Tiers = { 1, 3, 10, 25, 50 }, Color = Color3.fromRGB(170, 120, 255) },
			{ Id = "Storm", Stat = "GodWin:Storm", Name = "Storm Herald", Tiers = { 1, 3, 10, 25, 50 }, Color = Color3.fromRGB(90, 170, 255) },
			{ Id = "Magma", Stat = "GodWin:Magma", Name = "Magma Lord", Tiers = { 1, 3, 10, 25, 50 }, Color = Color3.fromRGB(255, 120, 50) },
			{ Id = "Glitch", Stat = "GodWin:Glitch", Name = "Glitch King", Tiers = { 1, 3, 10, 25, 50 }, Color = Color3.fromRGB(255, 80, 210) },
			{ Id = "Cataclysm", Stat = "GodWin:Cataclysm", Name = "World Ender", Tiers = { 1, 3, 10, 25, 50 }, Color = Color3.fromRGB(150, 90, 255) },
		} :: { { Id: string, Stat: string, Name: string, Tiers: { number }, Color: Color3 } },
		Numerals = { "I", "II", "III", "IV", "V" } :: { string },
	},

	-- 7-day play streak chest in the lodge, and the first-win-of-the-day bonus.
	Daily = {
		OpenMinBreak = 6, -- the reward window opens only with at least this many lobby-break seconds left
		-- 7-day login streak (the Daily Reward window on arrival, or the lodge chest). Day 2 is
		-- the Solar Flare dash trail (300 coins + a spin if already owned); day 7 the
		-- exclusive Sunforged God skin (1,500 coins if already owned).
		Rewards = {
			{ Coins = 150, Spins = 1 },
			{ Coins = 0, SolarFlare = true, Fallback = { Coins = 300, Spins = 1 } },
			{ Coins = 250 },
			{ Coins = 300, Spins = 1 },
			{ Coins = 400 },
			{ Coins = 500, Spins = 2 },
			{ Coins = 750, Cosmetic = "Sunforged", Fallback = { Coins = 1500 } },
		} :: { { Coins: number, Spins: number?, SolarFlare: boolean?, Cosmetic: string?, Fallback: { Coins: number, Spins: number? }? } },
		FirstWinMultiplier = 2, -- first survived round and first God win each day
		ChestOffset = Vector3.new(-12, 0, -31), -- in the lodge, from LobbyOrigin (clear of the God skin plinths' prompts)
	},

	-- Round-end superlatives on the summary screen.
	Awards = {
		{ Id = "Demolitionist", Name = "Demolitionist", Icon = "💥", Stat = "Destroyed", Text = "most parts broken" },
		{ Id = "ClosestCall", Name = "Closest Call", Icon = "💨", Stat = "NearMisses", Text = "most near misses" },
		{ Id = "Phantom", Name = "Phantom", Icon = "👁️", Stat = "HiddenBest", Text = "longest stealth streak" },
		{ Id = "Menace", Name = "Menace", Icon = "😜", Stat = "Taunts", Text = "most Daredevil taunts" },
	} :: { { Id: string, Name: string, Icon: string, Stat: string, Text: string } },

	-- Hand-made prop models kept in the place file (Workspace.Models, moved to ServerStorage
	-- at runtime) scattered onto the arenas where they make sense. Every part becomes
	-- anchored, destructible structure; scripts, seats, sounds and emitters are stripped.
	PropModels = {
		Folder = "Models",
		Cars = {
			-- Surface "Terrain" = open ground; "Top" = the highest surface (ship decks)
			NeoShibuya = { Count = 8, Surface = "Terrain" },
			FractureBay = { Count = 4, Surface = "Terrain" },
			MagmaCore = { Count = 3, Surface = "Top" },
			IroncladArmada = { Count = 4, Surface = "Top" },
			OutpostZero = { Count = 2, Surface = "Terrain" },
			StarlightBoardwalk = { Count = 2, Surface = "Top" },
			CasinoRoyale = { Count = 4, Surface = "Terrain" }, -- the plaza, and a prize car on the floor
			OasisBazaar = { Count = 1, Surface = "Terrain" },
		} :: { [string]: { Count: number, Surface: string } },
		CarModel = "Car",
		CarHealth = 140, -- per part
		Tries = 60,
	},

	Performance = {
		ShadowMinVolume = 24, -- structural parts smaller than this (studs^3) cast no shadow
	},

	-- Map dressing pass (World/Details.luau) after each builder.
	Details = {
		MaxLights = 10, -- PointLights per map from dressing (lamps, holo boards)
		FurniturePerFloor = 2, -- furnished pieces per floor of each highrise
		FurnitureMax = 50, -- per map (part budget)
	},

	-- Sky Lodge showcase (World/Lobby.luau + World/LodgeProps.luau build it; the client's
	-- LodgeController animates it). Decorative lodge lights (pedestals, lanterns, signs)
	-- share the Details.MaxLights budget; the chandeliers, hearth and podium are extra.
	Lodge = {
		DisplayTag = "LodgeDisplay", -- CollectionService tag on showcase models the client animates
		FlickerTag = "LodgeFlicker", -- lights that flicker (hearth, lanterns)
		AuraTag = "LodgeAura", -- display particle auras (off in Low-FX)
		AnimateDistance = 170, -- displays only idle-animate while the camera is this close to them
		AnimateRate = 30, -- animation updates per second
		DisplaySpin = 22, -- degrees per second, turntable spin of a showcased item
		OrbitSpin = 75, -- degrees per second, orbiting shards / coins / runes
		BobHeight = 0.35, -- studs up and down
		BobSpeed = 1.6, -- radians per second
		AuraRate = 5, -- particles per second per display aura (none in Low-FX)
		FlickerAmount = 0.3, -- hearth and lantern lights wobble by this fraction
		FlickerSpeed = 7,
		SignPixelsPerStud = 50, -- SurfaceGui resolution on the signboards
		HeaderDistance = 140, -- billboard name tags over the displays hide past this
		-- per God skin display: particle aura style
		Auras = {
			StormEye = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(140, 200, 255), Size = 0.5, Speed = 1.2 },
			StoneFist = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(190, 175, 160), Size = 1.1, Speed = 0.6 },
			MagmaClaw = { Texture = "rbxasset://textures/particles/fire_main.dds", Color = Color3.fromRGB(255, 120, 40), Size = 0.45, Speed = 2.2 },
			CyberGauntlet = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(70, 240, 255), Size = 0.35, Speed = 1.6 },
			CelestialMask = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = Color3.fromRGB(255, 225, 120), Size = 0.55, Speed = 0.8 },
			StormSovereign = { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = Color3.fromRGB(120, 135, 170), Size = 1.2, Speed = 0.7 },
		} :: { [string]: { Texture: string, Color: Color3, Size: number, Speed: number } },
	},

	-- Enterable interiors dropped onto empty ground on every arena (MapService). Each is a
	-- normal destructible building: walls break, the God can see in through doorways and
	-- windows, so hiding inside buys time but is never a safe room.
	-- Interior seal (MapService): after a map builds, any hole or deep pit inside the island
	-- (a channel, the sea between ships, the water under a pier) gets a shallow floor just
	-- under the waterline, with ladders up any high edge. Only the outer rim stays a drop
	-- into the sea / lava / void.
	Seal = {
		Cell = 8, -- sample grid (studs)
		Bearings = 72, -- directions used to find how far the island reaches
		ChannelCells = 6, -- a hole with ground on both sides within this many cells is a channel
		Margin = 16, -- studs inside the island's reach before a hole is filled (the rim stays a drop)
		FloorLift = 0.6, -- the shallows' floor sits just above the dark outer sea, so it stays visible
		WaterDepth = 1.5, -- the translucent turquoise water layer over that floor (no damage)
		WaterColor = Color3.fromRGB(70, 215, 205),
		WaterTransparency = 0.45,
		SandColor = Color3.fromRGB(236, 214, 160),
		LavaDepth = 1.5, -- lava maps: basalt crust top this far under the hazard line (safe to walk)
		CrustColor = Color3.fromRGB(46, 40, 40),
		SeamColor = Color3.fromRGB(255, 110, 30),
		-- the outer sea reads as the lethal edge: dark opaque navy (water maps), glowing magma (lava)
		SeaShade = Color3.fromRGB(12, 30, 70),
		SeaShadeAmount = 0.55,
		-- warning buoys float just past the island rim where the lethal drop begins
		BuoyEvery = 3, -- one buoy per this many bearings
		BuoyOffset = 12, -- studs past the rim
		BuoyColor = Color3.fromRGB(235, 60, 50),
		BuoyLight = Color3.fromRGB(255, 220, 90),
		LadderMinClimb = 5, -- edges higher than this above the shallows get a ladder
		LadderSpacing = 28,
		MaxLadders = 28,
	},

	Hideouts = {
		PerMap = 8,
		-- maps that are mostly interior already get fewer
		PerMapOverride = { CasinoRoyale = 2, AbyssalAquaDome = 4, OasisBazaar = 2, ClockworkSpire = 3 } :: { [string]: number },
		Tries = 90,
		Variants = {
			-- Floors / FloorHeight follow Builder.highrise; Weight picks how often
			{ Name = "Shed", Width = 14, Depth = 12, Floors = 1, FloorHeight = 11, Weight = 3, Crates = 2 },
			{ Name = "House", Width = 20, Depth = 16, Floors = 2, FloorHeight = 10, Weight = 2, Windows = true, Stairwell = true, Crates = 3 },
			{ Name = "Bunker", Width = 18, Depth = 14, Floors = 1, FloorHeight = 8, Weight = 2, Health = 260, Crates = 2 },
			{ Name = "Lookout", Width = 12, Depth = 12, Floors = 2, FloorHeight = 9, Weight = 1, Windows = true, Stairwell = true, Crates = 1 },
		},
	},

	-- Client presentation: round intro fly-by, end-of-round pan, danger edge pulse.
	Presentation = {
		IntroSeconds = 2.5,
		-- first round in a role: the fly-by continues into a short letterboxed cinematic
		-- (PolishController) that shows the God / the survivors / a demo strike
		CinematicBar = 0.15, -- letterbox bar height (screen fraction)
		CinematicGodShot = 2.4,
		CinematicDemoShot = 2.6,
		CinematicYouShot = 1.8,
		CinematicSurvivorsShot = 3,
		DemoImpactDelay = 1.3, -- demo red zone -> meteor impact
		OutroSeconds = 2.2,
		DangerDot = 0.35, -- telegraphs outside this view cone pulse the screen edge
		DangerRange = 90,
		ArenaCamInterval = 0.4, -- seconds between Arena Cam structure syncs (collapses, debris)
		ArenaCamCopyChunk = 150, -- arena parts copied into the Arena Cam per frame
		ArenaCamLiveRate = 15, -- disasters / survivors / God rig mirror updates per second
		ArenaCamMinSize = 4, -- arena parts smaller than this (largest axis) are skipped
		ArenaCamMaxFx = 150, -- disaster parts mirrored at once
		ArenaCamShotSeconds = 6, -- director camera cuts this often
		ArenaCamActionMemory = 8, -- a disaster this recent can get the "Action" shot
		ArenaCamViewDistance = 200, -- only rendered while your camera is this close to the screen
		ArenaCamOffset = Vector3.new(0, 24.5, -57.4), -- from Config.World.LobbyOrigin: high on the back wall, above the podium and boards
		ArenaCamYaw = 180, -- the SurfaceGui (Front face) looks into the hall, away from the back wall
		ArenaCamPitch = 14, -- tilted down at the room like a TV over a bar
		ArenaCamWallZ = -60, -- back wall (from LobbyOrigin), for the mounting arm
		-- round start: who is the God, who are the survivors (RoleRevealController)
		RevealRoulette = 1.1, -- portraits flick through everyone before landing on the God
		RevealHold = 2.4, -- the GOD vs SURVIVORS card stays up this long after landing
		RevealMaxFaces = 6, -- survivor portraits shown (+N for the rest)
		-- mid-round joiners / eliminated players (SpectateController)
		WaitingAutoSpectate = 4, -- a mid-round joiner drops into spectate after this many seconds
	},

	Disasters = {
		Abilities = Abilities,
		UniversalAbilities = { "SeismicPing" }, -- added to every kit as hotbar slot 6
		PostImpactLinger = 0.6,
	},

	Kits = Kits,
	GodPacks = GodPacks,
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
		Dancer = "dancinggirl", -- workspace model that dances on each board's pedestal (moved to ServerStorage at runtime)
		DancerFallbackOffset = Vector3.new(-9, 1, 0), -- board-local spot if a board has no pedestal
		DancerLight = 1.6, -- board spotlight brightness on the dancer (template ships 10)
		-- Hall of Legends podium in the lodge: the all-time top three of this stat stand on it
		Hall = { Stat = "RoundsSurvived", Unit = "rounds", Subtitle = "Most rounds survived · all time" },
		-- empty boards / podium places: the game's owner stands in (game.CreatorId for a
		-- user-owned place; this id when group-owned), then metallic mannequins hold the rest
		PlaceholderUserId = 7892599940,
		HallPlaceholderColors = { Color3.fromRGB(255, 205, 70), Color3.fromRGB(200, 206, 218), Color3.fromRGB(205, 128, 60) },
		Boards = {
			{ Stat = "RoundsSurvived", Title = "TOP SURVIVORS", Unit = "rounds" },
			{ Stat = "GodKills", Title = "DEADLIEST GODS", Unit = "kills" },
			{ Stat = "BestStreak", Title = "LONGEST STREAKS", Unit = "in a row" },
		},
	},

	-- Creator Dashboard funnels + balance events (AnalyticsService). Step names are what
	-- the dashboard shows; keep the order stable once live or funnels split.
	Analytics = {
		OnboardingSteps = { "Joined Lobby", "Dismissed Role Card / Moved", "Entered First Match", "Used Dash or Ability", "Completed First Round", "Opened Shop or Spin Wheel" },
		MatchSteps = { "Map Vote Cast", "Role Assigned", "First Action", "Survived 60s / First Elimination", "Sudden Death Reached", "Round Completed" },
		ShopSteps = { "Shop or Spin Opened", "Item Previewed", "Robux Prompt Shown", "Purchase Completed" },
		-- UI-only steps clients may report on the Analytics remote
		ClientEvents = { Moved = true, CardDismissed = true, Dash = true, Gear = true, HideoutEntered = true, ShopOpened = true, SpinOpened = true, ItemPreviewed = true, PromptShown = true, TutorialStep = true } :: { [string]: boolean },
		ClientBurst = 6, -- client events: burst size, then ClientRate per second
		ClientRate = 1,
		SurviveMarkSeconds = 60,
		CoinBuckets = { 100, 500, 2000, 10000 },
		Debug = false, -- warn on analytics call failures
	},

	-- Guided tutorial (TutorialController): one step at a time, once per player, skippable.
	Tutorial = {
		-- only what a brand-new player needs in their first minute (the cinematic shows the
		-- rest); menus like the shop and the wheel are left to discover
		Steps = {
			{ Id = "Dash", Text = "Press Q (or click DASH) to dash out of danger", TextTouch = "Tap DASH to dash out of danger" },
			{ Id = "Hide", Text = "Follow the arrows: hide indoors and stand still", TextTouch = "Follow the arrows: hide indoors and stand still" },
			{ Id = "GodCast", Text = "Pick a disaster (1-5), then click to cast", TextTouch = "Pick a disaster, then tap the arena to cast" },
		} :: { { Id: string, Text: string, TextTouch: string? } },
		Cinematics = { "IntroSurvivor", "IntroGod" }, -- first-round cinematic (saved like steps); a player sees only one of them, once
		ArrowImage = "rbxassetid://136636775487081", -- yellow pointer arrow (tools/icons/gen_tutorial.py)
		BeamTexture = "rbxassetid://130409304561613", -- white chevron strip for the ground beam
		ArrowSize = 64,
		BeamWidth = 2.6,
		BeamTileLength = 3.2, -- studs per chevron
		BeamSpeed = 1.2,
		ArriveDistance = 9, -- the Hide step completes this close to the doorway (or when Hidden)
		StepTimeout = 40, -- a step left unfinished this long counts as shown
		TickSeconds = 0.3,
		-- hint card bottom, in canvas units above the screen bottom (survivor: over the gear
		-- hotbar; God: over the taller ability hotbar and its controls line)
		HintLift = 118,
		HintLiftTouch = 150,
		GodHintLift = 214,
		GodHintLiftTouch = 236,
	},

	Onboarding = {
		RoleCards = false, -- the old three-bullet text cards (replaced by the first-round cinematic)
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
		CrashDelay = 0.9, -- seconds after a heavy hull starts falling that its impact lands (CrashDamage)
		TiltSeconds = 2.2, -- a ship section listing over when its bulkheads fail (Builder.tilt)
		CanopyCrackRadius = 12, -- impacts under a glass canopy crack the panels overhead
		CanopyCrackScale = 0.6, -- x the ability's structure damage
		DebrisLifetime = 9, -- seconds debris stays solid
		DebrisLifetimeJitter = 3,
		DebrisFadeTime = 2.5, -- then it ghosts through players, shrinks and fades
		DebrisFadeScale = 0.35,
		InvisibleCollideCutoff = 0.85, -- broken pieces at least this transparent stop colliding
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
		SurvivalCoins = 60, -- a 1,500-4,000 coin kit is ~15-25 survived rounds away
		StreakBonusPerRound = 10,
		ParticipationCoins = 10,
		GodKillCoins = 30,
		GodDestructionCoinsPerPart = 0.25,
		ObbyCoins = 15,
		ObbyCooldown = 15,
		FirstRoundBonus = 100, -- one-time "First Round Completed!" coins
		FriendBoost = 0.2, -- +20% round coins while a Roblox friend is in the server
		GhostPingCooldown = 5, -- (old harmless pings; ghost bolts use Config.Ghost)
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
			-- playlists: each track plays through, then the next one (shuffled start)
			Lobby = { 114376757380093, 126637212383840, 9045802707 }, -- 9045802707: "Some Happy for Ya" (APM)
			Round = { 9045941481, 1842286824 }, -- 9045941481: "Mission Danger" (APM)
			SuddenDeath = { 9044584220 }, -- "Evil Overlord (B)" (APM)
		} :: { [string]: { number } },
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
			ChronoSpire = 9112839913, -- Oil Refinery: burners, pump clatter, machine hiss (PSE)
			VerdantDome = 9112803829, -- Jungle Birds, exotic calls (PSE)
			IroncladArmada = 82247046952844, -- Thunder & Rain (TooLost)
			AbyssalAquaDome = 9120621792, -- Waves Rolling (PSE), deep in the trench
			CasinoRoyale = 82247046952844, -- Thunder & Rain (TooLost) on the neon strip
			OasisBazaar = 9125742262, -- airy desert wind (PSE)
			ClockworkSpire = 81404060588532, -- Howling Wind over the foundry walls
		} :: { [string]: number },
		AmbienceLayer = {
			StarlightBoardwalk = 9117143228, -- Ocean Surf (PSE)
			OutpostZero = 9120621792, -- Waves Rolling (PSE)
			FractureBay = 9118858002, -- Seagulls flock overhead (PSE)
			VerdantDome = 9120552550, -- Waterfall steady stream (PSE)
			IroncladArmada = 9126201551, -- heavy rolling surf (PSE)
			ChronoSpire = 9112838943, -- refinery fan whir and metal groans (PSE)
			AbyssalAquaDome = 9112838943, -- station machinery hum and metal groans (PSE)
			CasinoRoyale = 9112757705, -- City Ambience night (PSE)
			OasisBazaar = 9120552550, -- the river: steady stream (PSE)
			ClockworkSpire = 9112839913, -- clockwork: burners, pump clatter, machine hiss (PSE)
		} :: { [string]: number },
		Ui = {
			Click = 124993589864467, -- UI click (every Components button)
			Pop = 72264591133889, -- UI pop: centre-screen popups
			Hover = 131677038997771, -- pointer over a button (mouse only, throttled)
			Achievement = 8486683243, -- quest / daily reward claimed
			Countdown = 117649901456711, -- "3, 2, 1" voice/beeps, played once at 3 seconds
			SpinWhirl = 9126278342, -- wooden ratchet clicking (PSE): the wheel spinning
			SpinWin = 9043151109, -- the wheel lands
			Hitmarker = 75881627871349, -- "heavy hitmarker": the God's kill confirm
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
			Thunder2 = 139319051979882, -- extra thunder clap (a variant of Thunder)
			Thunder3 = 136217358874957, -- secondary rolling thunder (a variant of Thunder)
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
			Smash = 106506164911023, -- satisfying destruction smash: collapses and big hits
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
			GravitySingularity = { Key = "Rumble", Volume = 1.4, Speed = 0.5 },
			TectonicSpire = { Key = "Rumble", Volume = 1.5, Speed = 1.1 },
			ChainArc = { Key = "Thunder", Volume = 0.8, Speed = 2.4 },
			MeteorBarrage = { Key = "MeteorFall", Volume = 1.6, Speed = 0.7 },
			PyroclastSurge = { Key = "Rumble", Volume = 1.6, Speed = 0.7 },
			SystemOverride = { Key = "Glass", Volume = 1.2, Speed = 1.4 },
			AstralCollapse = { Key = "Rumble", Volume = 1.6, Speed = 0.4 },
			MaelstromVortex = { Key = "Gust", Volume = 1.6, Speed = 0.5 },
		} :: { [string]: { Key: string, Volume: number, Speed: number } },
		-- material break one-shots (AudioService.playBreak): a random pick per break, so a
		-- collapsing wooden pier sounds different from a steel deck or a glass dome
		Break = {
			Wood = { 9120805690, 9120805470, 9120805478, 9120963881, 9113581598, 9120861709 },
			Metal = { 9125819197, 9116771817, 9116537007, 9118064969, 9117180300, 9116536883 },
			Stone = { 9118588165, 9118692384, 9118690959, 9118691272, 9114221795 },
			Glass = { 132535085898211, 139826391278483, 118987440163311, 74769245504800, 132457128699700 },
			Ice = { 9114858583, 1571353871 },
			Foliage = { 9114514958, 9114519078, 9113581598 },
			Plastic = { 9117624703, 9116146300, 9125819216 },
			Sand = { 9118770617, 9118690959 },
		} :: { [string]: { number } },
		BreakMaterials = {
			Wood = "Wood", WoodPlanks = "Wood", Fabric = "Foliage",
			Metal = "Metal", DiamondPlate = "Metal", CorrodedMetal = "Metal", Foil = "Metal",
			Concrete = "Stone", Brick = "Stone", Slate = "Stone", Rock = "Stone", Cobblestone = "Stone", Granite = "Stone", Marble = "Stone", Basalt = "Stone", Pavement = "Stone", Limestone = "Stone", Asphalt = "Stone", CrackedLava = "Stone", Pebble = "Stone",
			Sandstone = "Sand", Sand = "Sand", Ground = "Sand", Mud = "Sand", Salt = "Sand",
			Glass = "Glass", Neon = "Glass", ForceField = "Glass",
			Ice = "Ice", Glacier = "Ice", Snow = "Ice",
			Grass = "Foliage", LeafyGrass = "Foliage",
			Plastic = "Plastic", SmoothPlastic = "Plastic",
		} :: { [string]: string },
		BreakVolume = 0.55,
		SmashMinParts = 4, -- a single hit breaking at least this many parts plays the Smash
		SmashCooldown = 0.35,
		BreakCooldown = 0.09, -- per material family, so a collapse is a rumble of distinct cracks, not a wall of noise
		SirenVolume = 0.3,
		-- a key listed here plays one of its variants at random (AudioService / UI Sound)
		Variants = {
			Thunder = { "Thunder", "Thunder2", "Thunder3" },
		} :: { [string]: { string } },
		HoverCooldown = 0.08, -- seconds between two hover sounds
		Volume = {
			Music = 0.3,
			Ambience = 0.45,
			Ui = 0.6,
			Disaster = 0.55, -- the DisasterSounds group (was 1: impacts drowned out everything)
		},
		-- every world one-shot is scaled by Scale and clamped to Max before the group volume,
		-- and at most MaxVoices play at once (extra ones are dropped, never queued)
		Mix = { Scale = 0.6, Max = 1.1, MaxVoices = 14, RollOffMin = 14, RollOffMax = 420 },
		CrossfadeSeconds = 2.5,
		MusicLoadTimeout = 8, -- a playlist track still not loaded after this is skipped
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
		BoundsMargin = 55, -- casts are allowed this far past a map's own Radius
		LobbyOrigin = Vector3.new(0, 150, -232), -- close + low enough that the balcony overlooks the arena
		GodPerch = Vector3.new(0, 150, 0),
		MapRotation = { "AbyssalAquaDome", "ChronoSpire", "CasinoRoyale", "FractureBay", "NeoShibuya", "OasisBazaar", "VerdantDome", "MagmaCore", "ClockworkSpire", "SunscorchedMirage", "IroncladArmada", "OutpostZero", "StarlightBoardwalk" },
		MapDisplayNames = {
			FractureBay = "Fracture Bay",
			NeoShibuya = "Neo-Shibuya Skyline",
			MagmaCore = "Magma Core Station",
			SunscorchedMirage = "Sunscorched Mirage",
			OutpostZero = "Outpost Zero",
			StarlightBoardwalk = "Starlight Boardwalk",
			ChronoSpire = "Chrono-Spire Citadel",
			VerdantDome = "Verdant Bio-Dome",
			IroncladArmada = "Ironclad Armada",
			AbyssalAquaDome = "Abyssal Aqua-Dome",
			CasinoRoyale = "Casino Royale",
			OasisBazaar = "Oasis Bazaar",
			ClockworkSpire = "Clockwork Spire",
		} :: { [string]: string },
		MapIcons = {
			FractureBay = "🏖️",
			NeoShibuya = "🌃",
			MagmaCore = "🌋",
			SunscorchedMirage = "🏜️",
			OutpostZero = "🧊",
			StarlightBoardwalk = "🎡",
			ChronoSpire = "⚙️",
			VerdantDome = "🌿",
			IroncladArmada = "⚓",
			AbyssalAquaDome = "🐠",
			CasinoRoyale = "🎰",
			OasisBazaar = "🐪",
			ClockworkSpire = "🔭",
		} :: { [string]: string },
		-- cinematic shots of each arena for the map vote cards (captured in Studio, 384x512)
		MapThumbnails = {
			ChronoSpire = "rbxassetid://140325150916621",
			VerdantDome = "rbxassetid://113155266025422",
			IroncladArmada = "rbxassetid://84718600640535",
			FractureBay = "rbxassetid://106157294494912",
			NeoShibuya = "rbxassetid://127124903661791",
			MagmaCore = "rbxassetid://85217236615159",
			SunscorchedMirage = "rbxassetid://109383400239121",
			OutpostZero = "rbxassetid://89934695715065",
			StarlightBoardwalk = "rbxassetid://110223167570976",
			AbyssalAquaDome = "rbxassetid://101435533797228",
			CasinoRoyale = "rbxassetid://71195517455664",
			OasisBazaar = "rbxassetid://127909441616793",
			ClockworkSpire = "rbxassetid://104746382014309",
		} :: { [string]: string },
		NewMaps = { AbyssalAquaDome = true, CasinoRoyale = true, OasisBazaar = true, ClockworkSpire = true } :: { [string]: boolean },
		BuildYieldEvery = 150, -- parts created before yielding a frame
		MinWalkWidth = 12, -- bridges, catwalks and stairs are at least this wide (dashable on a phone)
	},

	-- Hand-picked Sky objects kept in the place file (Workspace.Skyboxes, moved to
	-- ServerStorage at runtime), per lighting preset. Presets without one use Skies below.
	Skyboxes = {
		Folder = "Skyboxes",
		ByPreset = {
			Lodge = "CartoonSky",
			Day = "CartoonSky", -- Fracture Bay: bright tropical
			Night = "NightSky", -- Neo-Shibuya: dark night skyline
			Desert = "Sky", -- Sunscorched Mirage: clear blue
			Arctic = "Snow", -- Outpost Zero
			Sunset = "Skybox_Sunset", -- Starlight Boardwalk
			Foundry = "Skybox_Sunset", -- Chrono-Spire and the Clockwork foundry yard: golden hour
			Conservatory = "Sky", -- Verdant Bio-Dome: clear sky through the glass
			Tempest = "NightSky2", -- Ironclad Armada: dark stormy night
			Abyss = "NightSky2", -- Abyssal Aqua-Dome: the dark ocean over the open trench
			Casino = "NightSky", -- Casino Royale: rainy twilight city
			Canyon = "Skybox_Sunset", -- Oasis Bazaar: golden dusk
			Nebula = "NorthernLightsNight", -- (spare: Clockwork Spire now uses Foundry)
			-- Volcanic (Magma Core) keeps the burning sky from Skies; NorthernLightsNight is spare
		} :: { [string]: string },
	},

	-- stylised skyboxes per lighting preset (Bk, Dn, Ft, Lf, Rt, Up), applied by EnvironmentService
	Skies = {
		Day = { 13523725319, 13523743919, 13523725319, 13523725319, 13523725319, 13523746141 }, -- cartoon blue sky, puffy clouds
		Night = { 119731751, 50282196, 119731771, 119731809, 119731823, 119731844 }, -- purple skyline
		Desert = { 161319957, 161319965, 161319970, 161319983, 161319989, 161319996 }, -- dusty desert horizon
		Arctic = { 122076196453002, 129469057577973, 139156344241065, 122849389458893, 92579064446840, 96364407339806 }, -- stylized snowy mountain range
		Sunset = { 600830446, 600831635, 600832720, 600886090, 600833862, 600835177 }, -- orange sunset with sun
		Foundry = { 600830446, 600831635, 600832720, 600886090, 600833862, 600835177 }, -- golden sunset
		Conservatory = { 13588936210, 13588937487, 13588939141, 13588942813, 13588945061, 13588947580 }, -- stylized green hills
		Tempest = { 4498828382, 4498828812, 4498829917, 4498830911, 4498830417, 4498831746 }, -- dark storm clouds
		Volcanic = { 157785163, 157785059, 157785081, 157785128, 157785104, 157785145 }, -- burning red apocalypse
		Lodge = { 13523725319, 13523743919, 13523725319, 13523725319, 13523725319, 13523746141 }, -- cartoon blue sky
		Abyss = { 4498828382, 4498828812, 4498829917, 4498830911, 4498830417, 4498831746 }, -- dark clouds (fallback)
		Casino = { 119731751, 50282196, 119731771, 119731809, 119731823, 119731844 }, -- purple skyline (fallback)
		Canyon = { 600830446, 600831635, 600832720, 600886090, 600833862, 600835177 }, -- sunset (fallback)
		Nebula = { 119731751, 50282196, 119731771, 119731809, 119731823, 119731844 }, -- night (fallback)
	} :: { [string]: { number } },

	-- Client weather per map (MapFxController). Kinds: Rain | Snow | Pollen | Embers | Dust.
	Weather = {
		Maps = {
			IroncladArmada = { Kind = "Rain", Rate = 450, Lightning = true },
			NeoShibuya = { Kind = "Rain", Rate = 140 },
			OutpostZero = { Kind = "Snow", Rate = 160 },
			VerdantDome = { Kind = "Pollen", Rate = 40 },
			ChronoSpire = { Kind = "Embers", Rate = 30 },
			MagmaCore = { Kind = "Embers", Rate = 60 },
			SunscorchedMirage = { Kind = "Dust", Rate = 14 },
			AbyssalAquaDome = { Kind = "Plankton", Rate = 60 },
			CasinoRoyale = { Kind = "Rain", Rate = 160, Lightning = true },
			OasisBazaar = { Kind = "Dust", Rate = 45 }, -- a dusty sandstorm wind
			ClockworkSpire = { Kind = "Embers", Rate = 22 },
		} :: { [string]: { Kind: string, Rate: number, Lightning: boolean? } },
		-- Ambient set dressing per map (MapFxController, client-only, skipped in Low-FX):
		-- "Roof" emitters sit on the tallest buildings (chimneys, smokestacks, vents),
		-- "Ground" ones on open ground (mist, steam vents, fireflies, sea spray).
		Ambient = {
			FractureBay = { { Kind = "Smoke", Count = 2, On = "Roof" }, { Kind = "Spray", Count = 4, On = "Ground" } },
			NeoShibuya = { { Kind = "Steam", Count = 5, On = "Ground" }, { Kind = "Sparks", Count = 3, On = "Roof" } },
			MagmaCore = { { Kind = "Ash", Count = 4, On = "Roof" }, { Kind = "Steam", Count = 4, On = "Ground" } },
			SunscorchedMirage = { { Kind = "DustDevil", Count = 3, On = "Ground" }, { Kind = "Smoke", Count = 1, On = "Roof" } },
			OutpostZero = { { Kind = "Steam", Count = 3, On = "Roof" }, { Kind = "Mist", Count = 3, On = "Ground" } },
			StarlightBoardwalk = { { Kind = "Fireflies", Count = 5, On = "Ground" }, { Kind = "Smoke", Count = 1, On = "Roof" } },
			ChronoSpire = { { Kind = "Smoke", Count = 5, On = "Roof" }, { Kind = "Steam", Count = 3, On = "Ground" } },
			VerdantDome = { { Kind = "Mist", Count = 5, On = "Ground" }, { Kind = "Fireflies", Count = 3, On = "Ground" } },
			IroncladArmada = { { Kind = "Ash", Count = 4, On = "Roof" }, { Kind = "Mist", Count = 3, On = "Ground" } },
			AbyssalAquaDome = { { Kind = "Bubbles", Count = 7, On = "Ground" }, { Kind = "Mist", Count = 4, On = "Ground" } },
			CasinoRoyale = { { Kind = "Steam", Count = 3, On = "Ground" }, { Kind = "Sparks", Count = 2, On = "Roof" } },
			OasisBazaar = { { Kind = "DustDevil", Count = 4, On = "Ground" }, { Kind = "Smoke", Count = 2, On = "Roof" } },
			ClockworkSpire = { { Kind = "Mist", Count = 6, On = "Ground" }, { Kind = "Steam", Count = 3, On = "Roof" }, { Kind = "Fireflies", Count = 3, On = "Ground" } },
		} :: { [string]: { { Kind: string, Count: number, On: string } } },
		AmbientDelay = 1.5, -- seconds after the map key changes before emitters are placed
		Area = 140, -- emitter footprint over the camera
		Height = 45, -- studs above the camera
		MaxCameraHeight = 130, -- above this the camera is at the Sky Lodge: no weather
		FlashMin = 7, -- seconds between lightning flashes
		FlashMax = 15,
		FlashBrightness = 0.45,
		ThunderVolume = 0.5,
		LaunchCooldown = 0.6, -- steam vents (Builder.launchPad)
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
		Spectating = "Spectating", -- local player, client-only: the spectate view (cheer bar) is open
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
		VoteCandidates = "VoteCandidates", -- ReplicatedStorage: "MapA,MapB,MapC"
		VoteCounts = "VoteCounts", -- ReplicatedStorage: "2,0,1"
		VoteEndsAt = "VoteEndsAt", -- ReplicatedStorage: server time the vote closes
		VoteWinner = "VoteWinner", -- ReplicatedStorage: winning candidate index (0 = none yet)
		Slowed = "Slowed", -- Player: standing in quicksand
		Hidden = "Hidden", -- Player: hidden from the God (still indoors, or jammed)
		LastStand = "LastStand", -- ReplicatedStorage: display name of the last survivor ("" = none)
		LastStander = "LastStander", -- Player: is the Last Stand survivor (dash + near-miss buffs)
		DaredevilUntil = "DaredevilUntil", -- Player: server time the taunt coin bonus ends
		CosmeticPrefix = "Cos_", -- Player: owns cosmetic (bool)
		EquipPrefix = "Equip_", -- Player: equipped cosmetic id per category
		SavePrefix = "Save_", -- Player: panic save charges
		GodAim = "GodAim", -- ReplicatedStorage: the human God's reticle (Vector3), nil when none
		Mutator = "Mutator", -- ReplicatedStorage: active Chaos Twist id ("" = none)
		BeaconAt = "BeaconAt", -- ReplicatedStorage: Emergency Flare position (Vector3), nil when none
		Title = "Title", -- Player: best mastery title ("" = none)
		TitleColor = "TitleColor", -- Player: Color3 of that title
		LoginStreak = "LoginStreak", -- Player: current daily play streak (days)
		StreakReady = "StreakReady", -- Player: today's streak chest can be claimed
		GoldenTrail = "GoldenTrail", -- Player: owns the old day-7 Golden Trail dash
		SolarFlare = "SolarFlare", -- Player: owns the day-2 Solar Flare dash trail
		GodRounds = "GodRounds", -- Player: rounds played as the God
		FriendBoost = "FriendBoost", -- Player: a Roblox friend is in the server (+20% round coins)
		PaidRandomRestricted = "PaidRandomRestricted", -- Player: PolicyService forbids paid random items (no Robux spins)
		GhostReadyAt = "GhostReadyAt", -- Player: server time their next ghost bolt is ready
		FinalRush = "FinalRush", -- ReplicatedStorage: the Final Rush has started this round
		SpeedUntil = "SpeedUntil", -- Player: server time a speed pickup ends
		ShieldCharges = "ShieldCharges", -- Player: one-hit shields from air drops
		SettingPrefix = "Set_", -- Player: saved quick settings (LowFx, Shake, Music, Sfx)
		GodSkin = "GodSkin", -- ReplicatedStorage: the human God's equipped skin id ("" = none)
	},
}

return table.freeze(Config)
