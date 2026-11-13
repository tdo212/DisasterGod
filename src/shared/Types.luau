--!strict
-- Shared type definitions for DisasterGod.

export type RoundPhase = "Intermission" | "Active" | "RoundEnd"

-- Sub-phase of the Active phase (drives pacing and UI).
export type SubPhase = "None" | "Prep" | "Escalation" | "SuddenDeath"

export type PlayerRole = "Survivor" | "DisasterGod" | "Spectator"

export type AbilityTier = "Minor" | "Major"

export type AbilityDefinition = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Tier: AbilityTier,
	Cost: number, -- Chaos Energy
	Cooldown: number, -- seconds
	WarningTime: number, -- telegraph seconds before impact
	Radius: number, -- reticle / effect radius
	PlayerDamage: number,
	StructureDamage: number,
	Knockback: number?,
	Count: number?, -- meteors
	ImpactRadius: number?, -- per-meteor blast
	Duration: number?, -- tornado lifetime
	Speed: number?, -- tornado travel speed
	TickDamage: number?, -- tornado damage per tick
	Length: number?, -- fault line length
	Width: number?, -- fault line width
}

export type GearDefinition = {
	Id: string,
	DisplayName: string,
	Icon: string,
	Description: string,
	Price: number,
	Duration: number,
	Key: string, -- keyboard shortcut label
	Color: Color3,
}

export type ProductDefinition = {
	Id: number,
	Name: string,
	Price: number, -- Robux
	Icon: string,
	Coins: number?,
	Spins: number?,
	Badge: string, -- "Good Value" etc., "" for none
}

export type KitDefinition = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	Price: number, -- coins; 0 = free
	Color: Color3,
	Abilities: { string },
}

export type SpinReward = {
	Id: string,
	Label: string,
	Icon: string,
	Kind: "Coins" | "Kit" | "God",
	Amount: number,
	Weight: number,
	Color: Color3,
}

export type QuestDefinition = {
	Id: string,
	Text: string,
	Stat: string, -- progress counter this quest listens to
	Goal: number,
	Reward: number, -- coins
}

export type QuestProfile = {
	Day: number,
	Progress: { [string]: number }, -- by stat
	Claimed: { [string]: boolean }, -- by quest id
	Streak: number,
	LastAllDoneDay: number,
}

export type PassDefinition = {
	Id: number,
	Name: string,
	Price: number, -- Robux
	Icon: string,
	Description: string,
}

export type MapInfo = {
	Name: string,
	DisplayName: string,
	Model: Model,
	SpawnPoints: { CFrame },
	FluidStartY: number,
	FluidEndY: number,
	FluidColor: Color3,
	FluidMaterial: Enum.Material,
	HazardFloorY: number?, -- standing below this Y hurts (lava floors)
	FluidName: string, -- shown in the sudden-death banner ("WATER", "LAVA", ...)
	Lighting: string, -- EnvironmentService preset: Day | Night | Desert | Arctic | Sunset | Volcanic
	KnockbackMultiplier: number?, -- slippery maps make knockback stronger
	Center: Vector3,
	Radius: number,
}

export type PlayerProfile = {
	Coins: number,
	Wins: number,
	Streak: number,
	BestStreak: number,
	RoundsSurvived: number,
	RoundsPlayed: number,
	GodKills: number,
	Spins: number,
	FreeSpinAt: number, -- unix time the next free spin lands (0 = not started)
	Kit: string, -- equipped God kit
	Kits: { [string]: boolean }, -- owned kits
	Tutorials: { [string]: boolean }, -- role cards already shown
	Quests: QuestProfile,
	Gear: { [string]: number },
	WelcomeClaimed: boolean,
	Receipts: { string }, -- recent purchase ids (idempotent ProcessReceipt)
}

export type RoundRecord = {
	Role: PlayerRole,
	Survived: boolean,
	Earned: number,
	NearMisses: number,
	Escapes: number,
	Kills: number,
	Destroyed: number,
}

export type SummaryLine = { Text: string, Amount: number }

export type RoundSummary = {
	MapName: string,
	GodName: string,
	SurvivorCount: number,
	Podium: { { Name: string, Earned: number } },
	Role: PlayerRole,
	Survived: boolean,
	Lines: { SummaryLine },
	Total: number,
}

export type PlayerState = {
	UserId: number,
	Role: PlayerRole,
	Alive: boolean,
	RoundsSurvived: number,
}

return {}
