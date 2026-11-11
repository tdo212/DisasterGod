--!strict
-- Shared type definitions for DisasterGod.

export type RoundPhase = "Intermission" | "Active" | "RoundEnd"

export type PlayerRole = "Survivor" | "DisasterGod" | "Spectator"

export type PlayerState = {
	UserId: number,
	Role: PlayerRole,
	Alive: boolean,
	RoundsSurvived: number,
}

export type RoundState = {
	Phase: RoundPhase,
	TimeRemaining: number,
	RoundNumber: number,
}

export type HazardDefinition = {
	Id: string,
	DisplayName: string,
	WarningTime: number, -- seconds of telegraph before the hazard hits
	Duration: number, -- seconds the hazard stays active
	Damage: number, -- damage per hit/tick
	Cooldown: number, -- seconds before this hazard can be triggered again
}

return {}
