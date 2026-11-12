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
	Center: Vector3,
	Radius: number,
}

export type PlayerProfile = {
	Coins: number,
	Wins: number,
	Streak: number,
	BestStreak: number,
	RoundsSurvived: number,
	Gear: { [string]: number },
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
