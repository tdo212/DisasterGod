--!strict
-- MatchService: drives the round state machine (Intermission -> Active -> RoundEnd)
-- and replicates phase/timer to clients via ReplicatedStorage attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Types = require(Shared:WaitForChild("Types") :: ModuleScript)

type RoundPhase = Types.RoundPhase
type RoundState = Types.RoundState

local Attributes = Config.Attributes

local MatchService = {}

local state: RoundState = {
	Phase = "Intermission",
	TimeRemaining = 0,
	RoundNumber = 0,
}

local phaseChanged = Instance.new("BindableEvent")
MatchService.PhaseChanged = phaseChanged.Event -- (phase: RoundPhase, duration: number)

local started = false

local function replicate()
	ReplicatedStorage:SetAttribute(Attributes.RoundPhase, state.Phase)
	ReplicatedStorage:SetAttribute(Attributes.TimeRemaining, state.TimeRemaining)
	ReplicatedStorage:SetAttribute(Attributes.RoundNumber, state.RoundNumber)
end

local function setPhase(phase: RoundPhase, duration: number)
	state.Phase = phase
	state.TimeRemaining = duration
	replicate()
	phaseChanged:Fire(phase, duration)
end

local function countdown()
	while state.TimeRemaining > 0 do
		task.wait(1)
		state.TimeRemaining -= 1
		ReplicatedStorage:SetAttribute(Attributes.TimeRemaining, state.TimeRemaining)
	end
end

local function assignRoles(role: Types.PlayerRole)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(Attributes.Role, role)
	end
end

local function runCycle()
	setPhase("Intermission", Config.Match.IntermissionDuration)
	assignRoles("Spectator")
	countdown()

	if #Players:GetPlayers() < Config.Match.MinPlayers then
		return
	end

	state.RoundNumber += 1
	assignRoles("Survivor") -- TODO: pick a DisasterGod player once hazards exist
	setPhase("Active", math.random(Config.Match.RoundDurationMin, Config.Match.RoundDurationMax))
	countdown()

	setPhase("RoundEnd", Config.Match.RoundEndDuration)
	countdown()
end

function MatchService.GetState(): RoundState
	return table.clone(state)
end

function MatchService.Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(function(player: Player)
		player:SetAttribute(Attributes.Role, "Spectator")
	end)

	task.spawn(function()
		while true do
			runCycle()
		end
	end)
end

return MatchService
