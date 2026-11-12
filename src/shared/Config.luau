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
		Radius = 8,
		PlayerDamage = 55,
		StructureDamage = 140,
	},
	{
		Id = "Gust",
		DisplayName = "Gust",
		Icon = "🌬️",
		Tier = "Minor",
		Cost = 10,
		Cooldown = 4,
		WarningTime = 1.5,
		Radius = 26,
		PlayerDamage = 5,
		StructureDamage = 35,
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
		Radius = 24,
		PlayerDamage = 45,
		StructureDamage = 220,
		Count = 5,
		ImpactRadius = 10,
	},
	{
		Id = "Tornado",
		DisplayName = "Tornado",
		Icon = "🌪️",
		Tier = "Major",
		Cost = 55,
		Cooldown = 16,
		WarningTime = 2,
		Radius = 14,
		PlayerDamage = 0,
		StructureDamage = 70, -- per second
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
		Radius = 7, -- half-width used for the reticle
		PlayerDamage = 40,
		StructureDamage = 999,
		Length = 100,
		Width = 8,
	},
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

local Config = {
	Match = {
		MinPlayers = 1, -- 1 keeps Play Solo fully playable
		IntermissionDuration = 12,
		RoundDuration = 85,
		PrepDuration = 10, -- survivors scatter, God charges energy
		SuddenDeathDuration = 20, -- final seconds: rising fluid + double regen
		RoundEndDuration = 8,
		RespawnDelay = 2,
		AllowSoloRoleToggle = true, -- 1 player: toggle Survivor <-> God on the fly
		MaxSpawnSpread = 4,
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
		RegenPerSecond = 7,
		SuddenDeathRegenMultiplier = 2,
	},

	Director = {
		MinInterval = 3,
		MaxInterval = 6,
		SuddenDeathIntervalScale = 0.6,
		TargetJitter = 10,
		MajorChance = 0.35,
	},

	AntiCamp = {
		CheckInterval = 1,
		StationaryTime = 8,
		StationaryRadius = 6,
		RevealDuration = 3,
	},

	SuddenDeath = {
		FluidDamagePerSecond = 30,
	},

	Disasters = {
		Abilities = Abilities,
		PostImpactLinger = 0.6,
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
		} :: { [string]: number },
		CollapseSupportFraction = 0.7, -- level collapses when intact supports drop below this
		BreakImpulse = 45,
		BuckleImpulse = 30, -- sideways kick for a failing level's last supports
		BuckleNoCollideTime = 1, -- seconds those supports pass through the falling floors
		DebrisLifetime = 14,
		MaxDebris = 700,
		VolatileRadius = 16,
		VolatileStructureDamage = 300,
		VolatilePlayerDamage = 45,
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

	GearTuning = {
		SpeedSodaWalkSpeed = 34,
		GliderGravityScale = 0.3,
		ShieldShockwaveRadius = 14,
	},

	World = {
		ArenaCenter = Vector3.new(0, 0, 0),
		ArenaRadius = 175,
		LobbyOrigin = Vector3.new(0, 260, -340),
		GodPerch = Vector3.new(0, 150, 0),
		MapRotation = { "FractureBay", "MagmaCore" },
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
	},
}

return table.freeze(Config)
