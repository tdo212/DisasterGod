--!strict
-- SpectateController: eliminated / waiting players watch the live round.
--   * Follow cam (default): the camera follows one player at a time. ◀ / ▶ (A / D or the
--     arrow keys on PC) cycle through the God and every living survivor, AI survivor
--     bots included; when the one you watch goes down, the view moves on by itself.
--   * Free cam: fly the orbit camera over the arena and drop ghost bolts on it
--     (Config.Ghost: a small telegraphed zap that pays coins per survivor hit).
--   * One bar at the bottom holds all of it: who you're watching, the next-round timer,
--     FREE CAM / FOLLOW and LODGE.
-- Anyone not in the live round (joined mid-round, or eliminated) also gets the Waiting
-- card: when the next round starts, plus SPECTATE and SHOP buttons. A mid-round joiner
-- drops into spectate on their own after a few seconds.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local OrbitCamera = require(ClientRoot:WaitForChild("Util"):WaitForChild("OrbitCamera") :: ModuleScript)

local Attributes = Config.Attributes
local SP = Config.Spectate
local C = Theme.Colors
local player = Players.LocalPlayer

local SpectateController = {}

local CYCLE_ACTION = "SpectateCycle"
local SINK_ACTION = "SpectateSink"

type Target = { Key: Instance, Name: string, God: boolean, Humanoid: Humanoid }

local started = false
local active = false
local freeCam = false
local touch = false
local gui: ScreenGui
local layer: Frame -- viewport-scaled root for all UI content
local bar: Frame
local roleLabel: TextLabel
local nameLabel: TextLabel
local timerLabel: TextLabel
local modeText: TextLabel? = nil
local hint: TextLabel
local inputConn: RBXScriptConnection? = nil
local nextPing = 0
local waitingCard: Frame
local waitingTitle: TextLabel
local waitingTimer: TextLabel
local toggleText: TextLabel? = nil
local openShop: ((string?) -> ())? = nil

local current: Instance? = nil -- the Player (or bot Model) being followed
local lostAt = 0 -- when the followed target went down (moves on after a short beat)

-- MenuController hands over its shop opener (it requires this module, not the reverse)
function SpectateController.SetShopOpener(fn: (string?) -> ())
	openShop = fn
end

local function allowed(): boolean
	local role = player:GetAttribute(Attributes.Role)
	if role == "DisasterGod" then
		return false
	end
	if role == "Survivor" and player:GetAttribute(Attributes.Alive) == true then
		return false
	end
	return true
end

function SpectateController.IsActive(): boolean
	return active
end

local function nextRoundSeconds(): number
	local t = ReplicatedStorage:GetAttribute(Attributes.TimeRemaining) :: number? or 0
	return t + Config.Match.RoundEndDuration + Config.Match.IntermissionDuration
end

---------------------------------------------------------------------------
-- who can be watched: the God first, then living survivors, then AI survivor bots

local function aliveHumanoid(model: Model?): Humanoid?
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

local function targets(): { Target }
	local list: { Target } = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute(Attributes.Role) == "DisasterGod" then
			local humanoid = aliveHumanoid(p.Character)
			if humanoid then
				table.insert(list, { Key = p, Name = p.DisplayName, God = true, Humanoid = humanoid })
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute(Attributes.Role) == "Survivor" and p:GetAttribute(Attributes.Alive) == true then
			local humanoid = aliveHumanoid(p.Character)
			if humanoid then
				table.insert(list, { Key = p, Name = p.DisplayName, God = false, Humanoid = humanoid })
			end
		end
	end
	local bots = workspace:FindFirstChild("SurvivorBots")
	if bots then
		for _, model in bots:GetChildren() do
			if model:IsA("Model") then
				local humanoid = aliveHumanoid(model)
				if humanoid then
					table.insert(list, { Key = model, Name = model.Name, God = false, Humanoid = humanoid })
				end
			end
		end
	end
	return list
end

local function indexOf(list: { Target }, key: Instance?): number?
	for i, t in list do
		if t.Key == key then
			return i
		end
	end
	return nil
end

-- the first survivor (more fun to watch than the sky perch), else whoever is there
local function defaultTarget(list: { Target }): Target?
	for _, t in list do
		if not t.God then
			return t
		end
	end
	return list[1]
end

---------------------------------------------------------------------------
-- camera

local function ownHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function followCamera(target: Target?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local subject: Humanoid? = if target then target.Humanoid else ownHumanoid()
	if subject and camera.CameraSubject ~= subject then
		camera.CameraSubject = subject
	end
	if target then
		local root = target.Humanoid.Parent and target.Humanoid.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(root.Position)
				end)
			end)
		end
	end
end

local function refreshBar(list: { Target }, target: Target?)
	if target then
		local i = indexOf(list, target.Key) or 1
		roleLabel.Text = string.format("%s · %d / %d", if target.God then "😈 THE GOD" else "🏃 SURVIVOR", i, #list)
		roleLabel.TextColor3 = if target.God then C.PurpleLight else C.GreenLight
		nameLabel.Text = target.Name
	else
		roleLabel.Text = "SPECTATING"
		roleLabel.TextColor3 = C.TextDim
		nameLabel.Text = "No one left to watch"
	end
	if freeCam then
		roleLabel.Text = "🎥 FREE CAM"
		roleLabel.TextColor3 = C.BlueLight
	end
	local s = nextRoundSeconds()
	timerLabel.Text = string.format("Next round ~%d:%02d", s // 60, s % 60)
	if modeText then
		modeText.Text = if freeCam then "👤 FOLLOW" else "🎥 FREE CAM"
	end
end

-- Keep the camera on the current target; move on when it goes down.
local function update()
	if not active then
		return
	end
	local list = targets()
	local i = indexOf(list, current)
	local target: Target? = if i then list[i] else nil
	if not target then
		local now = os.clock()
		if lostAt == 0 then
			lostAt = now
		end
		-- a short beat on the spot it happened, then the next player
		if now - lostAt >= SP.LostHold or current == nil then
			lostAt = 0
			target = defaultTarget(list)
			current = if target then target.Key else nil
		end
	else
		lostAt = 0
	end
	if not freeCam and target then
		followCamera(target)
	end
	refreshBar(list, target)
end

local function cycle(step: number)
	if freeCam then
		return
	end
	local list = targets()
	if #list == 0 then
		return
	end
	local i = indexOf(list, current) or 0
	i = (i - 1 + step) % #list + 1
	current = list[i].Key
	lostAt = 0
	update()
end

local function bindKeys()
	ContextActionService:UnbindAction(CYCLE_ACTION)
	ContextActionService:UnbindAction(SINK_ACTION)
	if not active or freeCam then
		return -- the orbit camera owns WASD / arrows in free cam
	end
	ContextActionService:BindActionAtPriority(CYCLE_ACTION, function(_, state, input)
		if state == Enum.UserInputState.Begin then
			local back = input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left
			cycle(if back then -1 else 1)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Left, Enum.KeyCode.Right)
	-- don't walk your own (lodge) character around while watching someone
	ContextActionService:BindActionAtPriority(SINK_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W, Enum.KeyCode.S, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Space)
end

local function ghostInput(on: boolean)
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	if not on then
		return
	end
	inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if ReplicatedStorage:GetAttribute(Attributes.CastingOpen) ~= true then
				return
			end
			local now = os.clock()
			if now < nextPing then
				return
			end
			local point = if input.UserInputType == Enum.UserInputType.Touch
				then OrbitCamera.ScreenToWorld(Vector2.new(input.Position.X, input.Position.Y), true)
				else OrbitCamera.ScreenToWorld(UserInputService:GetMouseLocation())
			if point then
				nextPing = now + Config.Ghost.Cooldown
				Remotes.get("GhostPing"):FireServer(point)
			end
		end
	end)
end

local function setFreeCam(on: boolean)
	freeCam = on
	hint.Visible = on
	if on then
		-- start the free camera over whoever you were watching
		local list = targets()
		local i = indexOf(list, current)
		local root = if i then list[i].Humanoid.Parent and list[i].Humanoid.Parent:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		OrbitCamera.Enable(if root then root.Position else Config.World.ArenaCenter)
	else
		OrbitCamera.Disable()
	end
	ghostInput(on)
	bindKeys()
	update()
end

---------------------------------------------------------------------------
-- enter / exit

local function refreshToggle()
	if toggleText then
		toggleText.Text = if active then "🏠 LODGE" else "👁 SPECTATE"
	end
end

function SpectateController.Exit()
	if not active then
		return
	end
	active = false
	gui.Enabled = false
	player:SetAttribute(Attributes.Spectating, false)
	refreshToggle()
	ghostInput(false)
	ContextActionService:UnbindAction(CYCLE_ACTION)
	ContextActionService:UnbindAction(SINK_ACTION)
	if OrbitCamera.IsEnabled() then
		OrbitCamera.Disable()
	end
	freeCam = false
	current = nil
	followCamera(nil) -- back to your own character
end

function SpectateController.Enter()
	if active or not allowed() or OrbitCamera.IsEnabled() then
		return
	end
	active = true
	gui.Enabled = true
	player:SetAttribute(Attributes.Spectating, true)
	refreshToggle()
	local list = targets()
	local first = defaultTarget(list)
	current = if first then first.Key else nil
	lostAt = 0
	-- nobody to follow: start in free cam
	setFreeCam(first == nil)
end

function SpectateController.Toggle()
	if active then
		SpectateController.Exit()
	else
		SpectateController.Enter()
	end
end

---------------------------------------------------------------------------
-- UI

local function buildBar()
	local W = SP.BarWidth
	bar = Components.panel({
		Name = "SpectateBar",
		Size = UDim2.fromOffset(W, SP.BarHeight),
		Position = UDim2.new(0.5, 0, 1, -SP.BarLift),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Window,
		Transparency = 0.06,
		Studs = true,
		Parent = layer,
	})
	Components.block(bar, C.Window)
	-- ◀ name ▶
	for _, spec in { { "Prev", "◀", -1, "A" }, { "Next", "▶", 1, "D" } } do
		local back = (spec[3] :: number) < 0
		local b = Components.button({
			Name = spec[1] :: string,
			Text = spec[2] :: string,
			TextSize = 26,
			Size = UDim2.fromOffset(SP.ArrowSize, SP.ArrowSize),
			Position = if back then UDim2.fromOffset(SP.Pad, SP.Pad) else UDim2.new(1, -SP.Pad, 0, SP.Pad),
			AnchorPoint = if back then Vector2.zero else Vector2.new(1, 0),
			Color = C.Header,
			ColorLight = C.HeaderLight,
			Parent = bar,
			OnClick = function()
				cycle(spec[3] :: number)
			end,
		})
		if not touch then
			Components.keyChip(b, spec[4] :: string)
		end
	end
	local inner = W - (SP.ArrowSize + SP.Pad * 2) * 2
	roleLabel = Components.label({ Name = "Role", Text = "", TextSize = 16, Size = UDim2.fromOffset(inner, 20), Position = UDim2.new(0.5, 0, 0, SP.Pad), AnchorPoint = Vector2.new(0.5, 0), Parent = bar })
	nameLabel = Components.label({ Name = "Name", Text = "", TextSize = 28, Size = UDim2.fromOffset(inner, 34), Position = UDim2.new(0.5, 0, 0, SP.Pad + 22), AnchorPoint = Vector2.new(0.5, 0), Parent = bar })
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	-- bottom row: timer on the left, FREE CAM / LODGE on the right
	local rowY = SP.BarHeight - SP.Pad - SP.RowHeight
	timerLabel = Components.label({ Name = "Timer", Text = "", TextSize = 16, Color = C.TextDim, XAlign = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(W / 2 - SP.Pad, SP.RowHeight), Position = UDim2.fromOffset(SP.Pad + 4, rowY), Parent = bar })
	Components.button({
		Name = "Lodge",
		Text = "🏠 LODGE",
		TextSize = 15,
		Size = UDim2.fromOffset(SP.LodgeWidth, SP.RowHeight),
		Position = UDim2.new(1, -SP.Pad, 0, rowY),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Purple,
		ColorLight = C.PurpleLight,
		Parent = bar,
		OnClick = SpectateController.Exit,
	})
	local mode = Components.button({
		Name = "FreeCam",
		Text = "🎥 FREE CAM",
		TextSize = 15,
		Size = UDim2.fromOffset(SP.ModeWidth, SP.RowHeight),
		Position = UDim2.new(1, -SP.Pad - SP.LodgeWidth - SP.Gap, 0, rowY),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Blue,
		ColorLight = C.BlueLight,
		Parent = bar,
		OnClick = function()
			setFreeCam(not freeCam)
		end,
	})
	modeText = mode:FindFirstChild("Text") :: TextLabel?

	-- free cam: the ghost-bolt hint rides just above the bar
	local baseHint = if touch
		then "👻 Tap the arena to drop a ghost bolt (+coins per zap) · drag to fly, pinch to zoom"
		else "👻 Click the arena to drop a ghost bolt (+coins per zap) · WASD / QE / scroll to fly"
	hint = Components.label({
		Name = "Hint",
		Text = baseHint,
		TextSize = 18,
		Color = C.PurpleLight,
		Size = UDim2.fromOffset(W + 200, 24),
		Position = UDim2.new(0.5, 0, 1, -SP.BarLift - SP.BarHeight - Theme.Block.Depth - 10),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer,
	})
	hint.Visible = false
	task.spawn(function()
		while true do
			task.wait(SP.TickSeconds)
			if active then
				update()
				if freeCam then
					-- the ghost bolt's own cooldown, so a click never feels ignored
					local readyAt = player:GetAttribute(Attributes.GhostReadyAt)
					local wait = if typeof(readyAt) == "number" then math.ceil(readyAt - workspace:GetServerTimeNow()) else 0
					hint.Text = if ReplicatedStorage:GetAttribute(Attributes.CastingOpen) ~= true
						then "👻 Ghost bolts open when the disasters start"
						elseif wait > 0 then string.format("👻 Ghost bolt recharging · %ds", wait)
						else baseHint
				end
			end
		end
	end)
end

function SpectateController.Start()
	if started then
		return
	end
	started = true
	touch = Components.isTouch()
	gui = Instance.new("ScreenGui")
	gui.Name = "SpectateHUD"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)
	buildBar()

	-- the Waiting card: shown while a round runs without you (and you're not spectating)
	local waitingGui = Instance.new("ScreenGui")
	waitingGui.Name = "WaitingHUD"
	waitingGui.ResetOnSpawn = false
	waitingGui.Enabled = true
	waitingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	waitingGui.Parent = player:WaitForChild("PlayerGui")
	local waitingLayer = Components.scaledRoot(waitingGui)
	waitingCard = Components.panel({
		Name = "Waiting",
		Size = UDim2.fromOffset(SP.WaitingWidth, 84),
		Position = UDim2.new(0.5, 0, 1, -SP.WaitingLift),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Window,
		Transparency = 0.06,
		Studs = true,
		Parent = waitingLayer,
	})
	Components.block(waitingCard, C.Window)
	waitingCard.Visible = false
	local textWidth = SP.WaitingWidth - 112 - 104 - 12 * 3 - 14
	waitingTitle = Components.label({ Name = "Title", Text = "", TextSize = 22, Color = C.GoldLight, XAlign = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(textWidth, 28), Position = UDim2.fromOffset(14, 12), Parent = waitingCard })
	waitingTimer = Components.label({ Name = "Timer", Text = "", TextSize = 17, Color = C.Text, XAlign = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(textWidth, 24), Position = UDim2.fromOffset(14, 46), Parent = waitingCard })
	waitingTimer.TextTruncate = Enum.TextTruncate.AtEnd
	local toggle = Components.button({
		Name = "SpectateToggle",
		Text = "👁 SPECTATE",
		TextSize = 16,
		Size = UDim2.fromOffset(112, 56),
		Position = UDim2.new(1, -128, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Purple,
		ColorLight = C.PurpleLight,
		Parent = waitingCard,
		OnClick = SpectateController.Toggle,
	})
	toggleText = toggle:FindFirstChild("Text") :: TextLabel?
	Components.button({
		Name = "Shop",
		Text = "🛒 SHOP",
		TextSize = 16,
		Size = UDim2.fromOffset(104, 56),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Blue,
		ColorLight = C.BlueLight,
		Parent = waitingCard,
		OnClick = function()
			if active then
				SpectateController.Exit() -- the shop is a lodge thing
			end
			if openShop then
				openShop(nil)
			end
		end,
	})

	local joinedMid = false -- this player arrived while a round was running
	local autoAt = 0
	local function inRound(): boolean
		local role = player:GetAttribute(Attributes.Role)
		return role == "DisasterGod" or (role == "Survivor" and player:GetAttribute(Attributes.Alive) == true)
	end
	local function refreshWaiting()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		local waiting = phase == "Active" and not inRound() and player:GetAttribute("Cinematic") ~= true
		-- the spectate bar has its own timer and LODGE button: one card at a time
		waitingCard.Visible = waiting and not active
		if not waiting then
			if phase ~= "Active" then
				joinedMid = false
			end
			return
		end
		local s = nextRoundSeconds()
		waitingTitle.Text = if player:GetAttribute(Attributes.Role) == "Survivor" then "💀 ELIMINATED" else "⏳ ROUND IN PROGRESS"
		waitingTimer.Text = string.format("Next round ~%d:%02d · watch the match", s // 60, s % 60)
		if joinedMid and autoAt > 0 and os.clock() >= autoAt then
			autoAt = 0
			SpectateController.Enter()
		end
	end
	if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active" and not inRound() then
		joinedMid = true
		autoAt = os.clock() + Config.Presentation.WaitingAutoSpectate
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.TimeRemaining):Connect(refreshWaiting)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(function()
		if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" and active then
			SpectateController.Exit() -- round over: back to the lodge view
		end
		refreshWaiting()
	end)
	player:GetAttributeChangedSignal(Attributes.Spectating):Connect(refreshWaiting)

	local function evaluate()
		if active and not allowed() then
			SpectateController.Exit()
		end
		refreshWaiting()
	end
	player:GetAttributeChangedSignal(Attributes.Role):Connect(evaluate)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(evaluate)
	-- respawning resets the camera to your own character: put it back on the target
	player.CharacterAdded:Connect(function()
		if active and not freeCam then
			task.defer(update)
		end
	end)
	refreshWaiting()
end

return SpectateController
