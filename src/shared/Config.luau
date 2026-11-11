--!strict
-- Central gameplay constants. All tunable numbers live here.

local Config = {
	Match = {
		MinPlayers = 1, -- raise for live servers; 1 allows Play Solo testing
		IntermissionDuration = 10,
		RoundDurationMin = 60,
		RoundDurationMax = 90,
		RoundEndDuration = 8,
		RespawnDelay = 2,
	},

	Player = {
		MaxHealth = 100,
		WalkSpeed = 16,
		JumpPower = 50,
	},

	Disasters = {
		DefaultWarningTime = 3,
		FirstSpawnDelay = 3,
		MinSpawnInterval = 6,
		MaxSpawnInterval = 12,
		MaxConcurrent = 2,
	},

	Rewards = {
		SurvivalCoins = 25,
		PodiumCoins = { 50, 30, 15 },
	},

	-- Attribute names used to replicate match state to clients.
	Attributes = {
		RoundPhase = "RoundPhase", -- on ReplicatedStorage
		TimeRemaining = "RoundTimeRemaining", -- on ReplicatedStorage
		RoundNumber = "RoundNumber", -- on ReplicatedStorage
		Role = "Role", -- on each Player
	},
}

return table.freeze(Config)
