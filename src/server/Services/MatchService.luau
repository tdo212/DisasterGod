--!strict
-- MatchService: the round loop.
--   Intermission (lobby map vote, then the map builds) -> Active (Prep -> Escalation ->
--   Sudden Death) -> RoundEnd (payouts, podium) -> back to Intermission.
-- Also owns character setup, eliminations, hazard floors and the solo role toggle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local AudioService = require(script.Parent.AudioService)
local DestructionService = require(script.Parent.DestructionService)
local DisasterService = require(script.Parent.DisasterService)
local EnvironmentService = require(script.Parent.EnvironmentService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LobbyService = require(script.Parent.LobbyService)
local MapService = require(script.Parent.MapService)
local CosmeticService = require(script.Parent.CosmeticService)
local PropService = require(script.Parent.PropService)
local SaveService = require(script.Parent.SaveService)
local ShowdownService = require(script.Parent.ShowdownService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RagdollService = require(script.Parent.RagdollService)
local RoleService = require(script.Parent.RoleService)
local ScoringService = require(script.Parent.ScoringService)
local ShopService = require(script.Parent.ShopService)
local VoteService = require(script.Parent.VoteService)
local MutatorService = require(script.Parent.MutatorService)
local AnalyticsService = require(script.Parent.AnalyticsService)

type RoundPhase = Types.RoundPhase
type SubPhase = Types.SubPhase

local Attributes = Config.Attributes
local M = Config.Match

local MatchService = {}

local state = {
	Phase = "Intermission" :: RoundPhase,
	SubPhase = "None" :: SubPhase,
	TimeRemaining = 0,
	RoundNumber = 0,
}
local participants: { [Player]: boolean } = {}
local survivorsAssigned = false
local started = false
local siren: Sound? = nil
local finalKill = false -- the last survivor just died: hold the round end for the camera

local GOD_HINT = "Pick a disaster, then {tap} the arena to unleash it" -- {tap} is swapped per device on the client

local phaseChanged = Instance.new("BindableEvent")
MatchService.PhaseChanged = phaseChanged.Event -- (phase, duration)

local banner = Remotes.get("Banner")

local GOD_PURPLE = Color3.fromRGB(170, 90, 255)
local SURVIVOR_GREEN = Color3.fromRGB(90, 230, 110)
local RED = Color3.fromRGB(255, 70, 70)

---------------------------------------------------------------------------
-- replication

local function setPhase(phase: RoundPhase, duration: number)
	state.Phase = phase
	state.TimeRemaining = duration
	ReplicatedStorage:SetAttribute(Attributes.RoundPhase, phase)
	ReplicatedStorage:SetAttribute(Attributes.PhaseDuration, duration)
	ReplicatedStorage:SetAttribute(Attributes.TimeRemaining, duration)
	ReplicatedStorage:SetAttribute(Attributes.RoundNumber, state.RoundNumber)
	phaseChanged:Fire(phase, duration)
end

local function setSubPhase(sub: SubPhase)
	state.SubPhase = sub
	ReplicatedStorage:SetAttribute(Attributes.SubPhase, sub)
end

local function updateAlive()
	ReplicatedStorage:SetAttribute(Attributes.AliveCount, #RoleService.GetAliveSurvivors())
end

local function tick()
	task.wait(1)
	state.TimeRemaining = math.max(0, state.TimeRemaining - 1)
	ReplicatedStorage:SetAttribute(Attributes.TimeRemaining, state.TimeRemaining)
end

---------------------------------------------------------------------------
-- characters

local function hrpOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function waitForCharacter(player: Player, timeout: number): Model?
	local deadline = os.clock() + timeout
	while player.Parent and os.clock() < deadline do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
			return character
		end
		task.wait(0.1)
	end
	return nil
end

local function perch(player: Player)
	local character = waitForCharacter(player, 5)
	if not character then
		return
	end
	character:PivotTo(LobbyService.GetGodPerchCFrame())
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = true
	end
	if not character:FindFirstChild("GodShield") then
		local field = Instance.new("ForceField")
		field.Name = "GodShield"
		field.Visible = false
		field.Parent = character
	end
end

local function unperch(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.Anchored = false
	end
	local field = character:FindFirstChild("GodShield")
	if field then
		field:Destroy()
	end
end

local function sendToArena(player: Player, index: number)
	local info = MapService.GetCurrent()
	local character = waitForCharacter(player, 5)
	if not (info and character) then
		return
	end
	local points = info.SpawnPoints
	local base = points[(index - 1) % #points + 1]
	local s = M.MaxSpawnSpread
	character:PivotTo(base * CFrame.new(math.random(-s, s), 3, math.random(-s, s)))
end

local function onDied(player: Player, character: Model)
	if RoleService.MarkEliminated(player) then
		CosmeticService.Finisher(player, character)
		-- the round's last survivor: everyone's camera plays the final-kill moment
		local final = state.Phase == "Active" and survivorsAssigned and #RoleService.GetAliveSurvivors() == 0
		local cause = ScoringService.GetLastCause(player)
		AnalyticsService.SurvivorEliminated(player, cause or "Fall/Void", if cause then RoleService.GetGod() else nil)
		ScoringService.OnEliminated(player, final)
		SaveService.OfferAfterDeath(player, cause)
		if final then
			finalKill = true
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				Remotes.get("ClientEffect"):FireAllClients("FinalKill", hrp.Position, Config.Feed.FinalKillHold)
			end
		end
		updateAlive()
		banner:FireClient(player, "ELIMINATED", "Watch from the Sky Lodge deck, run the obby, or Spectate & haunt!", RED)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Player.JumpPower
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	-- bodies stay in one piece and flop as ragdolls instead of falling apart
	humanoid.BreakJointsOnDeath = false
	local function group(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = DestructionService.CharacterGroup
		end
	end
	for _, d in character:GetDescendants() do
		group(d)
	end
	character.DescendantAdded:Connect(group)
	humanoid.Died:Connect(function()
		RagdollService.OnDeath(player, character)
		onDied(player, character)
	end)
	-- respawned mid-round in a role that lives outside the lobby
	if state.Phase == "Active" then
		local role = RoleService.GetRole(player)
		if role == "DisasterGod" then
			task.defer(perch, player)
		elseif RoleService.IsAliveSurvivor(player) then
			task.defer(sendToArena, player, math.random(1, 12))
		end
	end
end

---------------------------------------------------------------------------
-- solo toggle (1 player): swap Survivor <-> God mid-round

local function onSoloSwap(player: Player, role: Types.PlayerRole)
	if state.Phase ~= "Active" then
		return -- applies when roles are picked next intermission
	end
	participants[player] = true
	if role == "DisasterGod" then
		-- no survivors left is expected here; don't let it end the round early
		survivorsAssigned = #RoleService.GetAliveSurvivors() > 1
		RoleService.SetRole(player, "DisasterGod")
		DisasterService.SetGod(player)
		ReplicatedStorage:SetAttribute(Attributes.GodName, player.DisplayName)
		task.spawn(perch, player)
		banner:FireClient(player, "YOU ARE THE DISASTER GOD", GOD_HINT, GOD_PURPLE)
	else
		unperch(player)
		RoleService.SetRole(player, "Survivor")
		DisasterService.SetGod(nil)
		ReplicatedStorage:SetAttribute(Attributes.GodName, "The Storm")
		survivorsAssigned = true
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			task.spawn(sendToArena, player, 1)
		else
			player:LoadCharacter()
		end
		banner:FireClient(player, "SURVIVE!", "The Storm Director controls the disasters", SURVIVOR_GREEN)
	end
	updateAlive()
end

---------------------------------------------------------------------------
-- hazard floors: kill plane, rising fluid, lava floor

local footParams = RaycastParams.new()
footParams.FilterType = Enum.RaycastFilterType.Include

local function setSlowed(player: Player, humanoid: Humanoid, walkSpeed: number?)
	if walkSpeed then
		if player:GetAttribute(Attributes.Slowed) ~= true then
			player:SetAttribute(Attributes.Slowed, true)
			humanoid.WalkSpeed = walkSpeed
		end
	elseif player:GetAttribute(Attributes.Slowed) == true then
		player:SetAttribute(Attributes.Slowed, false)
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
end

local function hazardStep(dt: number)
	if state.Phase ~= "Active" then
		return
	end
	local info = MapService.GetCurrent()
	local fluidTop = MapService.GetFluidTop()
	footParams.FilterDescendantsInstances = { MapService.GetArenaFolder() }
	for _, player in RoleService.GetAliveSurvivors() do
		local hrp = hrpOf(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (hrp and humanoid) or humanoid.Health <= 0 then
			continue
		end
		-- hazard zones under the feet (quicksand, vents)
		local floor = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), footParams)
		local zone = floor and floor.Instance
		local dps = zone and zone:GetAttribute("HazardDPS")
		if typeof(dps) == "number" and zone then
			ScoringService.NoteHit(player, nil, zone.Name)
			humanoid:TakeDamage(dps * dt)
		end
		local slow = zone and zone:GetAttribute("HazardWalkSpeed")
		setSlowed(player, humanoid, if typeof(slow) == "number" then slow else nil)

		local y = hrp.Position.Y
		-- an Emergency Glider charge catches the fall / pulls you out of the water
		if SaveService.TryGlider(player, hrp, fluidTop) then
			continue
		end
		if y < Config.Player.KillPlaneY then
			ScoringService.NoteHit(player, nil, "Void")
			humanoid.Health = 0
		elseif fluidTop and y < fluidTop - 1 then
			ScoringService.NoteHit(player, nil, "Fluid:" .. (if info then info.FluidName else "WATER"))
			humanoid:TakeDamage(Config.SuddenDeath.FluidDamagePerSecond * dt)
		elseif info and info.HazardFloorY and y < info.HazardFloorY then
			ScoringService.NoteHit(player, nil, "HazardFloor")
			humanoid:TakeDamage(Config.Player.HazardFloorDamagePerSecond * dt)
		end
	end
end

---------------------------------------------------------------------------
-- the loop

local function intermission(): (boolean, string)
	setPhase("Intermission", M.IntermissionDuration)
	setSubPhase("None")
	EnvironmentService.ApplyPreset("Lodge", 2) -- warm, soft light for the lobby (avatars no longer blow out)
	ReplicatedStorage:SetAttribute(Attributes.GodName, "")
	updateAlive()

	-- players vote on the lobby pads first; the winner is built for the rest of the countdown
	local mapName: string
	if VoteService.Begin() then
		ReplicatedStorage:SetAttribute(Attributes.MapName, "Vote for the next map!")
		local voteEnds = M.IntermissionDuration - Config.Voting.Duration
		while state.TimeRemaining > voteEnds do
			tick()
		end
		mapName = VoteService.Finish()
	else
		mapName = MapService.NextMapName()
	end
	-- Chaos Twist: rolled right after the vote (the client shows it once the winner flashes)
	MutatorService.Roll()
	ReplicatedStorage:SetAttribute(Attributes.MapName, "Building…")

	local info = MapService.Build(mapName)
	PropService.Setup(info)
	ReplicatedStorage:SetAttribute(Attributes.MapName, info.DisplayName)
	ReplicatedStorage:SetAttribute(Attributes.MapKey, info.Name)
	EnvironmentService.ApplyPreset(info.Lighting, 3)
	RoleService.UpdateChances()

	while state.TimeRemaining > 0 do
		tick()
	end
	return #Players:GetPlayers() >= M.MinPlayers, info.DisplayName
end

local function assignRoles(): Player?
	local players = Players:GetPlayers()
	local god = RoleService.PickGod(players)
	table.clear(participants)
	survivorsAssigned = false
	local index = 0
	for _, p in players do
		participants[p] = true
		if p == god then
			RoleService.SetRole(p, "DisasterGod")
			task.spawn(perch, p)
			banner:FireClient(p, "YOU ARE THE DISASTER GOD", GOD_HINT, GOD_PURPLE)
		else
			index += 1
			survivorsAssigned = true
			RoleService.SetRole(p, "Survivor")
			task.spawn(sendToArena, p, index)
			local godText = if god then god.DisplayName .. " is the Disaster God" else "The Storm Director controls the disasters"
			banner:FireClient(p, "SURVIVE!", godText, SURVIVOR_GREEN)
		end
	end
	ReplicatedStorage:SetAttribute(Attributes.GodName, if god then god.DisplayName else "The Storm")
	AnalyticsService.RoundStarted(players, god)
	return god
end

local function active(god: Player?)
	ScoringService.ResetRound()
	ShowdownService.Reset()
	finalKill = false
	DisasterService.BeginRound(god)
	MutatorService.BeginRound()
	ShopService.SetRoundActive(true)
	PropService.SetRoundActive(true)
	setPhase("Active", M.RoundDuration)
	setSubPhase("Prep")
	updateAlive()

	local castingOpen = false
	local suddenDeath = false
	while state.TimeRemaining > 0 do
		tick()
		local elapsed = M.RoundDuration - state.TimeRemaining
		if not castingOpen and elapsed >= M.PrepDuration then
			castingOpen = true
			DisasterService.SetCastingOpen(true)
			LobbyService.SetGhostPingsOpen(true)
			setSubPhase("Escalation")
		end
		if not suddenDeath and state.TimeRemaining <= M.SuddenDeathDuration then
			suddenDeath = true
			setSubPhase("SuddenDeath")
			DisasterService.SetSuddenDeath(true)
			MapService.StartFluid(M.SuddenDeathDuration)
			local reached = RoleService.GetAliveSurvivors()
			local godNow = RoleService.GetGod()
			if godNow then
				table.insert(reached, godNow)
			end
			AnalyticsService.SuddenDeath(reached)
			EnvironmentService.SetMood("SuddenDeath", 3)
			siren = AudioService.playGlobal("Siren", Config.Audio.SirenVolume, true)
			local info = MapService.GetCurrent()
			local fluidName = if info then info.FluidName else "WATER"
			banner:FireAllClients("SUDDEN DEATH", fluidName .. " IS RISING — GET TO HIGH GROUND!", RED)
		end
		updateAlive()
		local aliveCount = #RoleService.GetAliveSurvivors()
		if survivorsAssigned and aliveCount == 0 then
			break -- everyone is out: skip straight to the podium
		end
		DisasterService.SetHunterPulse(aliveCount == 1 and state.TimeRemaining <= Config.HunterPulse.LastSeconds)
		MutatorService.Update(state.TimeRemaining, M.RoundDuration, 1)
		ShowdownService.Update(RoleService.GetAliveSurvivors(), state.TimeRemaining)
	end
end

local function roundEnd(mapName: string)
	if finalKill then
		-- let the final-kill camera play before everyone is pulled back to the lodge
		task.wait(Config.Feed.FinalKillHold)
		finalKill = false
	end
	ShowdownService.Reset()
	local god = RoleService.GetGod()
	DisasterService.EndRound()
	ShopService.SetRoundActive(false)
	PropService.SetRoundActive(false)
	LobbyService.SetGhostPingsOpen(false)
	if siren then
		siren:Destroy()
		siren = nil
	end

	local list = {}
	local survivedSet: { [Player]: boolean } = {}
	for p in participants do
		if p.Parent then
			table.insert(list, p)
			survivedSet[p] = RoleService.IsAliveSurvivor(p)
		end
	end

	local survivorCount = 0
	for _, alive in survivedSet do
		if alive then
			survivorCount += 1
		end
	end
	AnalyticsService.RoundEnded(list, survivorCount, if god then "Human" else "Director")
	local summaries = ScoringService.FinishRound(mapName, god, list)
	MutatorService.EndRound() -- after payouts (Gold Rush reads the twist)
	for p, summary in summaries do
		Remotes.get("RoundSummary"):FireClient(p, summary)
	end
	RoleService.AdvancePity(list, god, survivedSet)
	LeaderboardService.RecordAll(list)

	setPhase("RoundEnd", M.RoundEndDuration)
	setSubPhase("None")
	EnvironmentService.SetMood("Calm", 2)

	-- everyone back to the Sky Lodge
	for _, p in list do
		if RoleService.GetRole(p) == "DisasterGod" then
			unperch(p)
		end
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			setSlowed(p, humanoid, nil)
			LobbyService.TeleportToLobby(p)
		end
	end
	RoleService.ResetAll()
	updateAlive()

	while state.TimeRemaining > 0 do
		tick()
	end
end

local function runCycle()
	local enough, mapName = intermission()
	if not enough then
		return
	end
	state.RoundNumber += 1
	local god = assignRoles()
	active(god)
	roundEnd(mapName)
end

-- Second Chance: put an eliminated survivor back into the live round. False if not possible.
function MatchService.Revive(player: Player): boolean
	if state.Phase ~= "Active" or not RoleService.Revive(player) then
		return false
	end
	updateAlive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		task.spawn(sendToArena, player, math.random(1, 12))
	else
		player:LoadCharacter() -- CharacterAdded sends alive survivors to the arena
	end
	banner:FireClient(player, "SECOND CHANCE!", "Back into the arena — survive!", SURVIVOR_GREEN)
	return true
end

function MatchService.GetState()
	return table.clone(state)
end

function MatchService.Init()
	Players.RespawnTime = M.RespawnDelay
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		task.defer(updateAlive)
	end)
	RoleService.SoloSwapRequested:Connect(onSoloSwap)
	Remotes.get("TutorialSeen").OnServerEvent:Connect(function(player, kind)
		if typeof(kind) ~= "string" then
			return
		end
		local known = kind == "God" or kind == "Survivor"
		for _, step in Config.Tutorial.Steps do
			known = known or step.Id == kind
		end
		if known then
			PlayerDataService.MarkTutorial(player, kind)
		end
	end)

	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum >= 0.25 then
			hazardStep(accum)
			accum = 0
		end
	end)
end

function MatchService.Start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local ok, err = pcall(runCycle)
			if not ok then
				warn("[MatchService] round cycle error:", err)
				DisasterService.EndRound()
				MutatorService.EndRound()
				RoleService.ResetAll()
				task.wait(2)
			end
		end
	end)
end

return MatchService
