--!strict
-- BotService: AI survivor bots for low-population servers (Config.LowPop).
--   * With 1-3 real players, each round spawns 4-6 bots into the arena: classic blocky
--     avatars with player-style names that wander between cover, dash away from disasters
--     that land near them, jump around and yell when hit.
--   * Disasters hit them through HitSphere / HitBox (called from DisasterService next to
--     its survivor checks); the God gets the usual kill credit when one goes down.
--   * Real players always come first: bots are only spawned at round start, and are
--     removed mid-round once the server is no longer low-pop.
--   * It also owns the low-pop coin bonus flag (ReplicatedStorage LowPopBonus).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DestructionService = require(script.Parent.DestructionService)
local MapService = require(script.Parent.MapService)
local ScoringService = require(script.Parent.ScoringService)

local LP = Config.LowPop
local Attributes = Config.Attributes

local BotService = {}

type Bot = {
	Name: string,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Alive: boolean,
	Home: Vector3, -- the spawn point it wanders around
	NextGoalAt: number,
	DashReadyAt: number,
	DashUntil: number,
	HitAt: number,
	LastBy: Player?,
	LastByAt: number,
	LastCause: string?,
	StuckPos: Vector3,
	StuckAt: number,
}

local bots: { Bot } = {}
local folder: Folder? = nil
local thinking = false
local rng = Random.new()

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

---------------------------------------------------------------------------
-- server population

local function realPlayers(): number
	return #Players:GetPlayers()
end

local function isLowPop(): boolean
	local n = realPlayers()
	return n >= 1 and n <= LP.MaxRealPlayers
end

-- How many bots a round with `humans` real players gets (0 when the server is busy).
function BotService.CountFor(humans: number): number
	if humans < 1 or humans > LP.MaxRealPlayers then
		return 0
	end
	return math.clamp(LP.BotsBase - humans, LP.MinBots, LP.MaxBots)
end

function BotService.IsLowPop(): boolean
	return isLowPop()
end

local function refreshBonus()
	ReplicatedStorage:SetAttribute(Attributes.LowPopBonus, if isLowPop() then LP.CoinMultiplier else 1)
end

---------------------------------------------------------------------------
-- looks

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function botName(taken: { [string]: boolean }): string
	for _ = 1, 10 do
		local name = pick(LP.NameFirst) .. pick(LP.NameSecond) .. tostring(rng:NextInteger(1, LP.NameNumberMax))
		if not taken[name] then
			return name
		end
	end
	return "Survivor" .. tostring(rng:NextInteger(1000, 9999))
end

local function describe(): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local skin = pick(LP.SkinTones)
	local shirt = pick(LP.ShirtColors)
	desc.HeadColor = skin
	desc.LeftArmColor = if rng:NextNumber() < 0.5 then skin else shirt
	desc.RightArmColor = desc.LeftArmColor
	desc.TorsoColor = shirt
	local pants = pick(LP.PantsColors)
	desc.LeftLegColor = pants
	desc.RightLegColor = pants
	return desc
end

---------------------------------------------------------------------------
-- movement

local function groundAt(at: Vector3): Vector3?
	groundParams.FilterDescendantsInstances = { MapService.GetArenaFolder() }
	local hit = workspace:Raycast(at + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), groundParams)
	return if hit then hit.Position else nil
end

-- Is walking straight from `from` to `goal` safe? Solid ground all the way (no gap or
-- ledge drop bigger than BotMaxDrop) and the goal inside the arena.
local function safeWalk(from: Vector3, goal: Vector3): boolean
	if not MapService.InBounds(goal) then
		return false
	end
	local info = MapService.GetCurrent()
	if info then
		local flat = Vector3.new(goal.X - info.Center.X, 0, goal.Z - info.Center.Z)
		if flat.Magnitude > info.Radius * LP.BotEdgeShare then
			return false
		end
	end
	local feet = from.Y - 3
	for i = 1, LP.BotPathSamples do
		local point = from:Lerp(goal, i / LP.BotPathSamples)
		groundParams.FilterDescendantsInstances = { MapService.GetArenaFolder() }
		local hit = workspace:Raycast(Vector3.new(point.X, from.Y + 6, point.Z), Vector3.new(0, -(LP.BotMaxDrop + 9), 0), groundParams)
		if not hit or hit.Position.Y < feet - LP.BotMaxDrop then
			return false
		end
	end
	return true
end

local function newGoal(bot: Bot, away: Vector3?)
	local from = bot.Root.Position
	local awayDir: Vector3? = nil
	if away then
		local flat = Vector3.new(from.X - away.X, 0, from.Z - away.Z)
		awayDir = if flat.Magnitude > 0.1 then flat.Unit else nil
	end
	for attempt = 1, LP.BotGoalTries do
		local target: Vector3
		if awayDir then
			-- run away from the danger, fanning out to the sides if straight back is unsafe
			local angle = (attempt - 1) * 0.6 * (if attempt % 2 == 0 then 1 else -1)
			local dir = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(awayDir)
			target = from + dir * LP.BotFleeRange * 1.5
		else
			local r = LP.BotWanderRange
			target = bot.Home + Vector3.new(rng:NextNumber(-r, r), 0, rng:NextNumber(-r, r))
		end
		local ground = groundAt(target)
		if ground and safeWalk(from, ground) then
			bot.Humanoid:MoveTo(ground)
			bot.NextGoalAt = os.clock() + rng:NextNumber(LP.BotRetargetMin, LP.BotRetargetMax)
			return
		end
	end
	-- nowhere safe to go: hold still and try again soon
	bot.Humanoid:MoveTo(from)
	bot.NextGoalAt = os.clock() + LP.BotRetargetMin
end

local function dash(bot: Bot)
	local now = os.clock()
	if now < bot.DashReadyAt then
		return
	end
	bot.DashReadyAt = now + LP.BotDashCooldown
	bot.DashUntil = now + LP.BotDashTime
	bot.Humanoid.WalkSpeed = LP.BotDashSpeed
end

local function scream(bot: Bot)
	local head = bot.Model:FindFirstChild("Head") :: BasePart?
	if not head or head:FindFirstChild("Scream") then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "Scream"
	board.Size = UDim2.fromOffset(120, 40)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = pick(LP.Screams)
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = board
	board.Parent = head
	Debris:AddItem(board, LP.ScreamTime)
end

---------------------------------------------------------------------------
-- damage

local function aliveCount(): number
	local n = 0
	for _, bot in bots do
		if bot.Alive then
			n += 1
		end
	end
	return n
end

local aliveChanged = Instance.new("BindableEvent")
-- Fired whenever a bot goes down or the bots are cleared (MatchService refreshes its counts).
BotService.AliveChanged = aliveChanged.Event

local function onBotDied(bot: Bot)
	if not bot.Alive then
		return
	end
	bot.Alive = false
	local credit = if bot.LastBy and os.clock() - bot.LastByAt <= Config.Scoring.KillCreditWindow then bot.LastBy else nil
	local final = aliveCount() == 0 and #Players:GetPlayers() > 0
	ScoringService.OnBotEliminated(bot.Name, bot.LastCause, credit, bot.Root.Position, final)
	Debris:AddItem(bot.Model, LP.BotCorpseTime)
	aliveChanged:Fire()
end

local function hit(bot: Bot, damage: number, caster: Player?, cause: string?, push: Vector3?)
	local now = os.clock()
	if not bot.Alive or now - bot.HitAt < LP.BotHitCooldown then
		return
	end
	bot.HitAt = now
	if caster then
		bot.LastBy = caster
		bot.LastByAt = now
	end
	if cause then
		bot.LastCause = cause
	end
	scream(bot)
	if push then
		bot.Root.AssemblyLinearVelocity += push
	end
	bot.Humanoid:TakeDamage(damage)
end

-- Danger landed near `center`: bots close by (but not hit) dash away from it.
local function threat(center: Vector3, radius: number)
	for _, bot in bots do
		if bot.Alive then
			local d = (bot.Root.Position - center).Magnitude
			if d <= radius + LP.BotFleeRange then
				dash(bot)
				newGoal(bot, center)
				if rng:NextNumber() < 0.5 then
					bot.Humanoid.Jump = true
				end
			end
		end
	end
end

-- Hurt every bot within `radius` of `center` (with an optional outward + upward shove).
function BotService.HitSphere(center: Vector3, radius: number, damage: number, caster: Player?, cause: string?, knockback: number?)
	for _, bot in bots do
		if bot.Alive then
			local offset = bot.Root.Position - center
			if offset.Magnitude <= radius + 1.5 then
				local push: Vector3? = nil
				if knockback then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis
					push = dir * knockback + Vector3.new(0, knockback * 0.5, 0)
				end
				hit(bot, damage, caster, cause, push)
			end
		end
	end
	threat(center, radius)
end

-- Hurt every bot inside the box `cf` / `size` (fissures, waves, spires).
function BotService.HitBox(cf: CFrame, size: Vector3, damage: number, caster: Player?, cause: string?, knockback: number?)
	local half = size / 2
	for _, bot in bots do
		if bot.Alive then
			local p = cf:PointToObjectSpace(bot.Root.Position)
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				hit(bot, damage, caster, cause, if knockback then Vector3.new(0, knockback, 0) else nil)
			end
		end
	end
	threat(cf.Position, math.max(half.X, half.Z))
end

-- A random living bot's position (the Director aims at bots too), or nil.
function BotService.RandomTarget(): Vector3?
	local alive = {}
	for _, bot in bots do
		if bot.Alive then
			table.insert(alive, bot)
		end
	end
	if #alive == 0 then
		return nil
	end
	return pick(alive).Root.Position
end

function BotService.AliveCount(): number
	return aliveCount()
end

---------------------------------------------------------------------------
-- the brain

local function think(bot: Bot)
	local now = os.clock()
	local pos = bot.Root.Position
	-- the arena's own hazards
	local info = MapService.GetCurrent()
	local fluidTop = MapService.GetFluidTop()
	if pos.Y < Config.Player.KillPlaneY then
		bot.LastCause = "Void"
		bot.Humanoid.Health = 0
		return
	elseif fluidTop and pos.Y < fluidTop - 1 then
		bot.LastCause = "Fluid:" .. (if info then info.FluidName else "WATER")
		bot.Humanoid:TakeDamage(Config.SuddenDeath.FluidDamagePerSecond * LP.BotThinkInterval)
	elseif info and info.HazardFloorY and pos.Y < info.HazardFloorY then
		bot.LastCause = "HazardFloor"
		bot.Humanoid:TakeDamage(Config.Player.HazardFloorDamagePerSecond * LP.BotThinkInterval)
	end
	if bot.DashUntil > 0 and now >= bot.DashUntil then
		bot.DashUntil = 0
		bot.Humanoid.WalkSpeed = LP.BotWalkSpeed
	end
	-- stuck against a wall: hop and pick somewhere else
	if (pos - bot.StuckPos).Magnitude > 2 then
		bot.StuckPos = pos
		bot.StuckAt = now
	elseif now - bot.StuckAt > 1.5 then
		bot.StuckAt = now
		bot.Humanoid.Jump = true
		newGoal(bot)
	end
	if now >= bot.NextGoalAt then
		newGoal(bot)
		if rng:NextNumber() < 0.25 then
			dash(bot)
		end
	end
	if rng:NextNumber() < LP.BotJumpChance then
		bot.Humanoid.Jump = true
	end
end

local function thinkLoop()
	if thinking then
		return
	end
	thinking = true
	task.spawn(function()
		while #bots > 0 do
			for _, bot in bots do
				if bot.Alive and bot.Model.Parent then
					think(bot)
				end
			end
			task.wait(LP.BotThinkInterval)
		end
		thinking = false
	end)
end

---------------------------------------------------------------------------
-- lifecycle

local function animate(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks: { [string]: AnimationTrack } = {}
	for key, id in LP.Anims do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = key == "Idle" or key == "Run"
			tracks[key] = track
		end
	end
	local current: AnimationTrack? = nil
	local function play(key: string)
		local track = tracks[key]
		if track and track ~= current then
			if current then
				current:Stop(0.15)
			end
			current = track
			track:Play(0.15)
		end
	end
	humanoid.Running:Connect(function(speed)
		play(if speed > LP.AnimRunSpeed then "Run" else "Idle")
	end)
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			play("Jump")
		elseif new == Enum.HumanoidStateType.Freefall then
			play("Fall")
		elseif new == Enum.HumanoidStateType.Dead and current then
			current:Stop(0.1)
		end
	end)
	play("Idle")
end

local function spawnBot(index: number, taken: { [string]: boolean }): Bot?
	local info = MapService.GetCurrent()
	if not info or #info.SpawnPoints == 0 then
		return nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[BotService] could not build a bot rig:", model)
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root) then
		model:Destroy()
		return nil
	end
	local name = botName(taken)
	taken[name] = true
	model.Name = name
	humanoid.DisplayName = name
	humanoid.MaxHealth = LP.BotHealth
	humanoid.Health = LP.BotHealth
	humanoid.WalkSpeed = LP.BotWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Player.JumpPower
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = DestructionService.CharacterGroup
		end
	end
	local base = info.SpawnPoints[(index - 1) % #info.SpawnPoints + 1]
	local s = Config.Match.MaxSpawnSpread
	model:PivotTo(base * CFrame.new(rng:NextNumber(-s, s), 3, rng:NextNumber(-s, s)))
	local localAnimate = model:FindFirstChild("Animate")
	if localAnimate then
		localAnimate:Destroy() -- a LocalScript that never runs here; the server plays the anims
	end
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	animate(humanoid)
	local now = os.clock()
	local bot: Bot = {
		Name = name,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Alive = true,
		Home = base.Position,
		NextGoalAt = now + rng:NextNumber(0, 1),
		DashReadyAt = now,
		DashUntil = 0,
		HitAt = 0,
		LastBy = nil,
		LastByAt = 0,
		LastCause = nil,
		StuckPos = root.Position,
		StuckAt = now,
	}
	humanoid.Died:Connect(function()
		onBotDied(bot)
	end)
	return bot
end

-- Round start: fill the arena with bots if the server is low-pop. Returns how many spawned.
function BotService.SpawnForRound(): number
	BotService.Clear()
	local count = BotService.CountFor(realPlayers())
	if count == 0 then
		return 0
	end
	local f = Instance.new("Folder")
	f.Name = "SurvivorBots"
	f.Parent = workspace
	folder = f
	local taken: { [string]: boolean } = {}
	for _, p in Players:GetPlayers() do
		taken[p.DisplayName] = true
	end
	for i = 1, count do
		local bot = spawnBot(i + 1, taken) -- index 1 is the first real survivor's spawn
		if bot then
			table.insert(bots, bot)
		end
	end
	thinkLoop()
	aliveChanged:Fire()
	return #bots
end

function BotService.Clear()
	for _, bot in bots do
		bot.Alive = false -- destroying a rig can fire Died: no feed lines for a cleanup
	end
	table.clear(bots)
	if folder then
		folder:Destroy()
		folder = nil
	end
	aliveChanged:Fire()
end

-- The server filled up mid-round: real players come first, the bots leave.
local function trim()
	if #bots > 0 and BotService.CountFor(realPlayers()) == 0 then
		BotService.Clear()
	end
end

function BotService.Init()
	Players.PlayerAdded:Connect(function()
		refreshBonus()
		trim()
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshBonus)
	end)
	refreshBonus()
end

return BotService
