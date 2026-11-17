--!strict
-- TutorialController: a light, show-don't-tell onboarding. One step at a time, each shown
-- once (saved on the profile as Tut_<id>), never while a role card or banner holds the
-- middle of the screen, and skippable:
--   * UI steps point at the exact button: a bouncing yellow arrow + a pulsing ring around
--     it, with one line of text at the bottom (device-aware: "Press Q" vs "Tap DASH").
--   * World steps draw an animated chevron beam on the ground from you to the goal (the
--     nearest hideout), like a sat-nav arrow.
-- Steps (Config.Tutorial.Steps), only what the first minute needs: dash -> follow the
-- arrows to hide -> (as God) pick a disaster and cast. They start after the first-round
-- cinematic (PolishController), which shows who the God is and what a red zone means.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local Analytics = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Analytics") :: ModuleScript)

local TU = Config.Tutorial
local Attributes = Config.Attributes
local C = Theme.Colors
local player = Players.LocalPlayer

local TutorialController = {}

type Step = { Id: string, Text: string, TextTouch: string? }

local gui: ScreenGui
local hint: Frame
local hintLabel: TextLabel
local ring: Frame
local arrow: ImageLabel
local callout: TextLabel -- "[3] TRY METEORS!" over the slot a God step points at
local beamFolder: Folder? = nil
local beamTarget: Part? = nil
local touch = false
local active: Step? = nil
local activeSince = 0
local doneLocal: { [string]: boolean } = {}
local flags: { [string]: boolean } = {} -- events seen this session (dashed, cast, voted...)
local castIds: { [string]: boolean } = {} -- disasters you've cast as the God this session
local castKinds = 0
local lastCastId: string? = nil
local sameStreak = 0
local nudgedRound = -1 -- the round the "mix it up" nudge last showed in
local nudgeSince = 0
local castsSinceNudge = 0
local skipped = false
local paused = false

local function isDone(id: string): boolean
	return doneLocal[id] == true or player:GetAttribute(Attributes.TutorialPrefix .. id) == true
end

local function phase(): any
	return ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
end

local function role(): any
	return player:GetAttribute(Attributes.Role)
end

local function inRound(): boolean
	return phase() == "Active" and (role() == "DisasterGod" or (role() == "Survivor" and player:GetAttribute(Attributes.Alive) == true))
end

local function playerGui(): PlayerGui
	return player:WaitForChild("PlayerGui") :: PlayerGui
end

-- Something else holds the player's attention (a role card, a banner, the round summary,
-- the shop or any other window): the tutorial waits, so nothing ever stacks. Windows are
-- the direct children of each HUD's scaled layer (Components.window names them "...Window").
local IGNORE = { TutorialHUD = true, VoteHUD = true, CinematicHUD = true }
local function busy(): boolean
	if player:GetAttribute("Cinematic") == true or player:GetAttribute("RoleReveal") == true then
		return true
	end
	for _, sg in playerGui():GetChildren() do
		if sg:IsA("ScreenGui") and sg.Enabled and not IGNORE[sg.Name] then
			for _, layer in sg:GetChildren() do
				for _, w in layer:GetChildren() do
					if w:IsA("GuiObject") and w.Visible and (w.Name == "RoleCard" or w.Name == "Banner" or string.sub(w.Name, -6) == "Window") then
						return true
					end
				end
			end
		end
	end
	return false
end

local function findGui(guiName: string, childName: string): GuiObject?
	local root = playerGui():FindFirstChild(guiName)
	if not root then
		return nil
	end
	local found = root:FindFirstChild(childName, true)
	if found and found:IsA("GuiObject") and found.Visible and found.AbsoluteSize.X > 4 then
		return found
	end
	return nil
end

local function godSlot(): GuiObject?
	local root = playerGui():FindFirstChild("GodHUD")
	local slots = root and root:FindFirstChild("Slots", true)
	if not slots then
		return nil
	end
	local best: GuiObject? = nil
	for _, c in slots:GetChildren() do
		if c:IsA("GuiObject") and c.Visible and (not best or c.AbsolutePosition.X < (best :: GuiObject).AbsolutePosition.X) then
			best = c
		end
	end
	return best
end

-- The first hotbar disaster you haven't cast yet (Seismic Ping is a utility, skipped),
-- with its key number, display name and tip.
local function untriedSlot(): (GuiObject?, number, string, string)
	local root = playerGui():FindFirstChild("GodHUD")
	local holder = root and root:FindFirstChild("Slots", true)
	if not holder then
		return nil, 0, "", ""
	end
	local list: { GuiObject } = {}
	for _, c in holder:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return a.AbsolutePosition.X < b.AbsolutePosition.X
	end)
	for i, slot in list do
		local id = slot.Name
		if not castIds[id] and id ~= "SeismicPing" then
			local name = id
			for _, def in Config.Disasters.Abilities do
				if def.Id == id then
					name = def.DisplayName
				end
			end
			return slot, i, name, TU.GodTips[id] or "a different disaster"
		end
	end
	return nil, 0, "", ""
end

local function fill(template: string): string
	local _, key, name, tip = untriedSlot()
	local text = template:gsub("{key}", tostring(key))
	text = text:gsub("{name}", name)
	text = text:gsub("{tip}", tip)
	return text
end

local function godMixWhen(): boolean
	return inRound() and role() == "DisasterGod" and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) == true and (untriedSlot()) ~= nil
end

local function nearestHideout(): Vector3?
	local arena = workspace:FindFirstChild("Arena")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (arena and root) then
		return nil
	end
	local best: Vector3? = nil
	local bestDist = math.huge
	for _, m in arena:GetChildren() do
		if m:IsA("Model") and string.sub(m.Name, 1, 7) == "Hideout" then
			local cf, size = m:GetBoundingBox()
			-- the doorway is in the middle of the south wall (Builder.highrise)
			local door = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z - size.Z / 2 - 2)
			local d = (door - root.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = door
			end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- step table: when it applies, what it points at, when it's done

type Rule = {
	When: () -> boolean,
	Target: (() -> GuiObject?)?,
	World: (() -> Vector3?)?,
	Done: () -> boolean,
	Dynamic: boolean?, -- the hint text has {key} / {name} / {tip} filled in live
	Callout: (() -> string?)?, -- a short shout over the pointed-at button
}

-- "[3] TRY METEORS!" (PC) / "TRY METEORS!" (touch) for the untried hotbar slot
local function tryCallout(): string?
	local slot, key, name = untriedSlot()
	if not slot then
		return nil
	end
	local shout = "TRY " .. string.upper(name) .. "!"
	return if touch then shout else string.format("[%d] %s", key, shout)
end

local function untriedTarget(): GuiObject?
	return (untriedSlot())
end

local RULES: { [string]: Rule } = {
	Dash = {
		When = function()
			return inRound() and role() == "Survivor" and findGui("SurvivorHUD", "Dash") ~= nil
		end,
		Target = function()
			return findGui("SurvivorHUD", "Dash")
		end,
		Done = function()
			return flags.Dashed == true
		end,
	},
	Hide = {
		When = function()
			return inRound() and role() == "Survivor" and isDone("Dash") and nearestHideout() ~= nil
		end,
		World = nearestHideout,
		Done = function()
			if player:GetAttribute(Attributes.Hidden) == true then
				return true
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local goal = beamTarget
			return root ~= nil and goal ~= nil and (root.Position - goal.Position).Magnitude < TU.ArriveDistance
		end,
	},
	GodCast = {
		When = function()
			return inRound() and role() == "DisasterGod" and ReplicatedStorage:GetAttribute(Attributes.CastingOpen) == true and godSlot() ~= nil
		end,
		Target = godSlot,
		Done = function()
			return flags.Cast == true
		end,
	},
	GodMix = {
		When = function()
			return isDone("GodCast") and godMixWhen()
		end,
		Target = untriedTarget,
		Dynamic = true,
		Callout = tryCallout,
		Done = function()
			return castKinds >= 2
		end,
	},
	GodMix2 = {
		When = function()
			return isDone("GodMix") and godMixWhen()
		end,
		Target = untriedTarget,
		Dynamic = true,
		Callout = tryCallout,
		Done = function()
			return castKinds >= 3
		end,
	},
	-- not a saved step: the "mix it up" nudge after casting one disaster over and over
	GodNudge = {
		When = godMixWhen,
		Target = untriedTarget,
		Dynamic = true,
		Callout = tryCallout,
		Done = function()
			return (castsSinceNudge > 0 and sameStreak == 1) or os.clock() - nudgeSince > TU.NudgeSeconds
		end,
	},
}
local NUDGE: Step = { Id = "GodNudge", Text = TU.NudgeText, TextTouch = TU.NudgeTextTouch }

---------------------------------------------------------------------------
-- visuals

local function clearBeam()
	if beamFolder then
		beamFolder:Destroy()
		beamFolder = nil
	end
	beamTarget = nil
end

local function showBeam(goal: Vector3)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if beamTarget and (beamTarget.Position - goal).Magnitude < 1 then
		return
	end
	clearBeam()
	local folder = Instance.new("Folder")
	folder.Name = "TutorialBeam"
	local target = Instance.new("Part")
	target.Name = "Goal"
	target.Anchored = true
	target.CanCollide = false
	target.CanQuery = false
	target.CanTouch = false
	target.Transparency = 1
	target.Size = Vector3.one
	target.CFrame = CFrame.new(goal + Vector3.new(0, 0.6, 0))
	target.Parent = folder
	local a1 = Instance.new("Attachment")
	a1.Parent = target
	local a0 = Instance.new("Attachment")
	a0.Name = "TutorialFrom"
	a0.Position = Vector3.new(0, -2.6, 0) -- at your feet
	a0.Parent = root
	-- white 3D-looking arrows plus a wider yellow chevron trail under them
	for i, spec in { { Width = TU.BeamWidth, Color = Color3.new(1, 1, 1), Transparency = 0 }, { Width = TU.BeamWidth * 1.8, Color = Color3.fromRGB(255, 210, 40), Transparency = 0.45 } } do
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Texture = TU.BeamTexture
		beam.TextureLength = TU.BeamTileLength
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureSpeed = TU.BeamSpeed
		beam.Width0 = spec.Width
		beam.Width1 = spec.Width
		beam.Color = ColorSequence.new(spec.Color)
		beam.Transparency = NumberSequence.new(spec.Transparency)
		beam.LightEmission = if i == 1 then 0.3 else 0.8
		beam.FaceCamera = true
		beam.Segments = 20
		beam.CurveSize0 = 3
		beam.CurveSize1 = -3
		beam.Parent = target
	end
	-- a bouncing arrow over the goal
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(70, 70)
	board.StudsOffset = Vector3.new(0, 7, 0)
	board.AlwaysOnTop = true
	board.Parent = target
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TU.ArrowImage
	img.Parent = board
	folder.Parent = workspace
	beamFolder = folder
	beamTarget = target
	-- the from-attachment lives on your character; clean it with the beam
	folder.Destroying:Connect(function()
		a0:Destroy()
	end)
end

local function hidePointer()
	ring.Visible = false
	arrow.Visible = false
	callout.Visible = false
end

local function pointAt(target: GuiObject)
	local inset = GuiService:GetGuiInset()
	local sg = target:FindFirstAncestorOfClass("ScreenGui")
	local offset = if sg and sg.IgnoreGuiInset then Vector2.zero else inset
	local pos = target.AbsolutePosition + offset
	local size = target.AbsoluteSize
	local pad = 8
	ring.Position = UDim2.fromOffset(pos.X - pad, pos.Y - pad)
	ring.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	ring.Visible = true
	local t = os.clock()
	local bob = math.sin(t * 6) * 8
	local s = TU.ArrowSize
	if pos.Y - s - 12 < 0 then
		-- no room above: point up from below
		arrow.Rotation = 180
		arrow.Position = UDim2.fromOffset(pos.X + size.X / 2 - s / 2, pos.Y + size.Y + pad + 6 - bob)
	else
		arrow.Rotation = 0
		arrow.Position = UDim2.fromOffset(pos.X + size.X / 2 - s / 2, pos.Y - s - pad - 6 + bob)
	end
	arrow.Visible = true
	-- the callout rides just above the arrow (below it when the arrow points up)
	local rule = active and RULES[active.Id]
	local shout = rule and rule.Callout and rule.Callout()
	if shout then
		callout.Text = shout
		local above = arrow.Rotation == 0
		callout.Position = UDim2.fromOffset(pos.X + size.X / 2, if above then pos.Y - s - pad - 10 + bob else pos.Y + size.Y + pad + s + 10 - bob)
		callout.AnchorPoint = Vector2.new(0.5, if above then 1 else 0)
		callout.Rotation = math.sin(t * 7) * 3
		callout.Visible = true
	else
		callout.Visible = false
	end
	local pulse = (math.sin(t * 5) + 1) / 2
	local stroke = ring:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = pulse * 0.5
		stroke.Thickness = 4 + pulse * 3
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "TutorialHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui()

	ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Visible = false
	Components.corner(ring, Theme.Radius.Medium)
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Gold
	stroke.Thickness = 5
	stroke.Parent = ring
	ring.Parent = gui

	arrow = Instance.new("ImageLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromOffset(TU.ArrowSize, TU.ArrowSize)
	arrow.Image = TU.ArrowImage
	arrow.Visible = false
	arrow.Parent = gui

	callout = Components.label({ Name = "Callout", Text = "", TextSize = if touch then 24 else 28, Color = C.GoldLight, Size = UDim2.fromOffset(320, 36), Parent = gui })
	callout.Visible = false

	-- the hint line sits low and centred (above the hotbars), never over the middle
	local layer = Components.scaledRoot(gui)
	hint = Components.panel({ Name = "Hint", Size = UDim2.fromOffset(if touch then 520 else 600, 54), Color = C.Window, Transparency = 0.08, Parent = layer })
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -(if touch then TU.HintLiftTouch else TU.HintLift))
	hint.Visible = false
	hintLabel = Components.label({ Name = "Text", Text = "", TextSize = if touch then 19 else 21, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(14, 0), XAlign = Enum.TextXAlignment.Left, Parent = hint })
	Components.button({
		Name = "Skip",
		Text = "SKIP",
		TextSize = 15,
		Size = UDim2.fromOffset(80, 34),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Grey,
		ColorLight = C.GreyLight,
		Parent = hint,
		OnClick = function()
			-- skip ends the whole tutorial (it never comes back)
			skipped = true
			for _, step in TU.Steps do
				doneLocal[step.Id] = true
				Remotes.get("TutorialSeen"):FireServer(step.Id)
			end
			Analytics.track("TutorialStep", "Skipped")
			active = nil
			hint.Visible = false
			hidePointer()
			clearBeam()
		end,
	})
end

---------------------------------------------------------------------------

local function stepText(step: Step): string
	local text = if touch and step.TextTouch then step.TextTouch else step.Text
	local rule = RULES[step.Id]
	return "👉 " .. (if rule and rule.Dynamic then fill(text) else text)
end

local function finish(step: Step)
	if step.Id ~= NUDGE.Id then
		doneLocal[step.Id] = true
		Remotes.get("TutorialSeen"):FireServer(step.Id)
	end
	Analytics.track("TutorialStep", step.Id .. ":done")
	active = nil
	hint.Visible = false
	hidePointer()
	clearBeam()
end

local function start(step: Step)
	active = step
	activeSince = os.clock()
	hintLabel.Text = stepText(step)
	-- the God's hotbar is taller: lift the card clear of it
	local god = string.sub(step.Id, 1, 3) == "God"
	local lift = if god then (if touch then TU.GodHintLiftTouch else TU.GodHintLift) else (if touch then TU.HintLiftTouch else TU.HintLift)
	hint.Position = UDim2.new(0.5, 0, 1, -lift)
	hint.Visible = true
	Analytics.track("TutorialStep", step.Id .. ":shown")
end

local function tick()
	if skipped then
		return
	end
	local step = active
	if step then
		local rule = RULES[step.Id]
		if rule.Done() then
			finish(step)
			return
		end
		if rule.Dynamic then
			hintLabel.Text = stepText(step) -- the slot it points at can change as you cast
		end
		-- pause (hide, don't time out) while a card / banner / window is up
		if busy() then
			paused = true
			hint.Visible = false
			hidePointer()
			activeSince += TU.TickSeconds
			return
		elseif paused then
			paused = false
			hint.Visible = true
		end
		-- the situation passed (round ended, vote closed): put it away, retry later
		if not rule.When() or os.clock() - activeSince > TU.StepTimeout then
			active = nil
			hint.Visible = false
			hidePointer()
			clearBeam()
			if os.clock() - activeSince > TU.StepTimeout then
				finish(step) -- shown long enough; don't nag
			end
		end
		return
	end
	if busy() then
		return
	end
	-- one disaster cast over and over: point at another (once a round)
	local round = ReplicatedStorage:GetAttribute(Attributes.RoundNumber)
	if sameStreak >= TU.NudgeRepeat and nudgedRound ~= round and RULES.GodNudge.When() then
		nudgedRound = if typeof(round) == "number" then round else 0
		nudgeSince = os.clock()
		castsSinceNudge = 0
		start(NUDGE)
		return
	end
	for _, s in TU.Steps do
		local rule = RULES[s.Id]
		if rule and not isDone(s.Id) and rule.When() then
			if rule.Done() then
				finish(s)
			else
				start(s)
			end
			return
		end
	end
end

local function render()
	local step = active
	if not step or paused then
		return
	end
	local rule = RULES[step.Id]
	local target = rule.Target and rule.Target()
	if target then
		pointAt(target)
	else
		hidePointer()
	end
	if rule.World then
		local goal = rule.World()
		if goal then
			showBeam(goal)
		end
	end
end

function TutorialController.Start()
	touch = Components.isTouch()
	buildGui()
	Analytics.watchMovement()

	-- events the steps wait for
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonX) then
			flags.Dashed = true
		end
	end)
	task.spawn(function()
		local hud = playerGui():WaitForChild("SurvivorHUD", 20)
		local dash = hud and hud:FindFirstChild("Dash", true)
		if dash and dash:IsA("GuiButton") then
			dash.Activated:Connect(function()
				flags.Dashed = true
			end)
		end
	end)
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, _at: any, abilityId: any)
		if kind == "GodCast" and role() == "DisasterGod" then
			flags.Cast = true
			if typeof(abilityId) == "string" then
				if not castIds[abilityId] then
					castIds[abilityId] = true
					castKinds += 1
				end
				sameStreak = if abilityId == lastCastId then sameStreak + 1 else 1
				lastCastId = abilityId
				castsSinceNudge += 1
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(TU.TickSeconds)
			tick()
		end
	end)
	RunService.RenderStepped:Connect(render)
end

return TutorialController
