--!strict
-- SurvivorController: expressive mobility (dash + ledge mantle) and the gear bar.
-- On touch devices the dash button sits beside the jump button, sized to match it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local ClientRoot = script.Parent.Parent
local Theme = require(ClientRoot:WaitForChild("UI"):WaitForChild("Theme") :: ModuleScript)
local Components = require(ClientRoot:WaitForChild("UI"):WaitForChild("Components") :: ModuleScript)
local OrbitCamera = require(ClientRoot:WaitForChild("Util"):WaitForChild("OrbitCamera") :: ModuleScript)

local Attributes = Config.Attributes
local Mobility = Config.Mobility
local C = Theme.Colors
local player = Players.LocalPlayer

local SurvivorController = {}

local started = false
local dashReadyAt = 0
local lastMantle = 0
local gui: ScreenGui
local layer: Frame -- viewport-scaled root for all UI content
local dashButton: TextButton
local dashCooldown: Frame
local gearBar: Frame
local gearButtons: { [string]: TextButton } = {}

local GEAR_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

local function parts(): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, character:FindFirstChildOfClass("Humanoid")
end

local function canMove(): boolean
	-- no dashing while flying an orbit camera (God view or spectating)
	return player:GetAttribute(Attributes.Role) ~= "DisasterGod" and not OrbitCamera.IsEnabled()
end

---------------------------------------------------------------------------
-- dash

local function dash()
	if not canMove() then
		return
	end
	local now = os.clock()
	if now < dashReadyAt then
		return
	end
	local hrp, humanoid = parts()
	if not (hrp and humanoid) or humanoid.Health <= 0 or hrp.Anchored then
		return
	end
	if player:GetAttribute(Attributes.Ragdolled) == true then
		return -- tumbling from a hit
	end
	local cooldown = Mobility.DashCooldown
	if player:GetAttribute(Attributes.PassPrefix .. "QuickDash") == true then
		cooldown *= Config.Monetization.QuickDashCooldownMultiplier
	end
	if player:GetAttribute(Attributes.LastStander) == true then
		cooldown *= Config.Showdown.DashCooldownScale -- Last Stand: dash recharges twice as fast
	end
	if ReplicatedStorage:GetAttribute(Attributes.Mutator) == "Hyperdrive" then
		cooldown /= Config.Mutators.HyperdriveScale -- Chaos Twist: dash recharges 25% faster
	end
	dashReadyAt = now + cooldown
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = hrp.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit

	local camera = workspace.CurrentCamera
	if camera then
		local fov = camera.FieldOfView
		TweenService:Create(camera, TweenInfo.new(0.08), { FieldOfView = fov + Mobility.DashFovKick }):Play()
		task.delay(Mobility.DashDuration, function()
			TweenService:Create(camera, TweenInfo.new(0.3), { FieldOfView = fov }):Play()
		end)
	end

	local trailA = Instance.new("Attachment")
	trailA.Position = Vector3.new(0, 1, 0)
	trailA.Parent = hrp
	local trailB = Instance.new("Attachment")
	trailB.Position = Vector3.new(0, -1, 0)
	trailB.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Attachment0 = trailA
	trail.Attachment1 = trailB
	trail.Lifetime = 0.25
	trail.Color = if player:GetAttribute(Attributes.GoldenTrail) == true and player:GetAttribute(Attributes.PassPrefix .. "VIP") ~= true
		then ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 30)) -- day-7 streak reward
		elseif player:GetAttribute(Attributes.PassPrefix .. "VIP") == true
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
		})
		else ColorSequence.new(C.Cyan)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = hrp

	local elapsed = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= Mobility.DashDuration or not hrp.Parent then
			conn:Disconnect()
			return
		end
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = dir * Mobility.DashSpeed + Vector3.new(0, math.max(v.Y, 2), 0)
	end)
	task.delay(0.5, function()
		trail:Destroy()
		trailA:Destroy()
		trailB:Destroy()
	end)
	dashCooldown.Size = UDim2.fromScale(1, 1)
	Components.tween(dashCooldown, TweenInfo.new(cooldown, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) })
end

---------------------------------------------------------------------------
-- ledge mantle: jump while airborne next to a ledge to haul yourself up

local function tryMantle()
	if not canMove() or os.clock() - lastMantle < 0.5 then
		return
	end
	local hrp, humanoid = parts()
	if not (hrp and humanoid) then
		return
	end
	local stateType = humanoid:GetState()
	if stateType ~= Enum.HumanoidStateType.Freefall and stateType ~= Enum.HumanoidStateType.Jumping then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local forward = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
	local wall = workspace:Raycast(hrp.Position, forward * Mobility.MantleReach, params)
	if not wall then
		return
	end
	local high = workspace:Raycast(hrp.Position + Vector3.new(0, Mobility.MantleHeight, 0), forward * Mobility.MantleReach, params)
	if high then
		return -- wall is too tall: no ledge in reach
	end
	lastMantle = os.clock()
	hrp.AssemblyLinearVelocity = Vector3.new(0, Mobility.MantleBoost, 0) + forward * 12
end

---------------------------------------------------------------------------
-- UI

local TOUCH_DASH_SIZE = 76
local TOUCH_DASH_GAP = 10

-- Touch: the dash sits up and to the left of Roblox's jump button (never on top of it),
-- at 80% of its size. TouchGui is rebuilt on some respawns / rotations, so re-find it.
local function followJumpButton()
	local playerGui = player:WaitForChild("PlayerGui")
	local bound: Instance? = nil
	local conns: { RBXScriptConnection } = {}
	local function bind()
		local touchGui = playerGui:FindFirstChild("TouchGui")
		local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
		local jump = frame and frame:FindFirstChild("JumpButton")
		if not (jump and jump:IsA("GuiObject")) or jump == bound then
			return
		end
		bound = jump
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		local function apply()
			if jump.AbsoluteSize.X < 1 then
				return
			end
			local size = math.max(60, jump.AbsoluteSize.X * 0.8)
			dashButton.Size = UDim2.fromOffset(size, size)
			dashButton.AnchorPoint = Vector2.new(1, 1)
			dashButton.Position = UDim2.fromOffset(jump.AbsolutePosition.X + jump.AbsoluteSize.X * 0.2, jump.AbsolutePosition.Y - TOUCH_DASH_GAP)
		end
		apply()
		table.insert(conns, jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(apply))
		table.insert(conns, jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply))
	end
	bind()
	playerGui.DescendantAdded:Connect(function(d)
		if d.Name == "JumpButton" then
			task.defer(bind)
		end
	end)
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "SurvivorHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)

	local touch = Components.isTouch()
	dashButton = Components.button({
		Name = "Dash",
		Text = "DASH",
		TextSize = if touch then 18 else 24,
		-- touch: real pixels above-left of the jump button (not in the scaled layer);
		-- fallback spot (no TouchGui yet) is clear of where the jump button sits
		Size = if touch then UDim2.fromOffset(TOUCH_DASH_SIZE, TOUCH_DASH_SIZE) else UDim2.fromOffset(150, 66),
		Position = if touch then UDim2.new(1, -40, 1, -150) else UDim2.new(1, -24, 1, -24),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Blue,
		ColorLight = C.BlueLight,
		Parent = if touch then gui else layer,
		OnClick = dash,
	})
	if touch then
		task.spawn(followJumpButton)
	else
		Components.keyChip(dashButton, "Q")
	end
	dashCooldown = Instance.new("Frame")
	dashCooldown.Name = "Cooldown"
	dashCooldown.BackgroundColor3 = Color3.new(0, 0, 0)
	dashCooldown.BackgroundTransparency = 0.45
	dashCooldown.BorderSizePixel = 0
	dashCooldown.AnchorPoint = Vector2.new(0, 1)
	dashCooldown.Position = UDim2.fromScale(0, 1)
	dashCooldown.Size = UDim2.fromScale(1, 0)
	dashCooldown.ZIndex = 2
	Components.corner(dashCooldown)
	dashCooldown.Parent = dashButton

	gearBar = Instance.new("Frame")
	gearBar.Name = "GearBar"
	gearBar.BackgroundTransparency = 1
	gearBar.Size = UDim2.fromOffset(#Config.Gear * 84, 84)
	gearBar.Position = UDim2.new(0.5, 0, 1, -16)
	gearBar.AnchorPoint = Vector2.new(0.5, 1)
	gearBar.Parent = layer
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gearBar

	for i, def in Config.Gear do
		local b = Instance.new("TextButton")
		b.Name = def.Id
		b.Text = ""
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(72, 72)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		Components.corner(b, Theme.Radius.Medium)
		Components.stroke(b, Theme.Stroke.Heavy)
		Components.gradient(b, def.Color:Lerp(Color3.new(1, 1, 1), 0.35), def.Color)
		b.Parent = gearBar
		Components.icon({ Name = "Icon", Icon = def.Id, TextSize = 34, Size = UDim2.fromScale(0.78, 0.78), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = b })
		if not Components.isTouch() then
			Components.keyChip(b, def.Key)
		end
		local count = Components.label({ Name = "Count", Text = "x0", TextSize = 18, Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -4, 1, -2), AnchorPoint = Vector2.new(1, 1), XAlign = Enum.TextXAlignment.Right, Parent = b })
		local function refresh()
			local n = player:GetAttribute(Attributes.GearPrefix .. def.Id) :: number? or 0
			count.Text = "x" .. tostring(n)
			b.BackgroundTransparency = if n > 0 then 0 else 0.5
		end
		player:GetAttributeChangedSignal(Attributes.GearPrefix .. def.Id):Connect(refresh)
		refresh()
		b.Activated:Connect(function()
			Remotes.get("UseGear"):FireServer(def.Id)
		end)
		gearButtons[def.Id] = b
	end
end

local function refreshVisibility()
	local role = player:GetAttribute(Attributes.Role)
	local alive = player:GetAttribute(Attributes.Alive) == true
	local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	dashButton.Visible = role ~= "DisasterGod"
	gearBar.Visible = role == "Survivor" and alive and phase == "Active"
end

-- System Override (Cyber Gauntlet God Pack): the dash is jammed and the screen
-- scrambles for a few seconds.
local function emp(seconds: number)
	dashReadyAt = math.max(dashReadyAt, os.clock() + seconds)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EmpScramble"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	local layer = Components.scaledRoot(gui)
	local bars: { Frame } = {}
	for i = 1, 7 do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(60, 230, 255) else Color3.fromRGB(255, 60, 200)
		bar.BackgroundTransparency = 0.75
		bar.Size = UDim2.new(1, 0, 0, 10)
		bar.Parent = gui
		table.insert(bars, bar)
	end
	Components.label({ Name = "Warning", Text = "📵 SYSTEM OVERRIDE · DASH JAMMED", TextSize = 26, Color = Color3.fromRGB(120, 255, 255), Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromScale(0, 0.28), Parent = layer })
	task.spawn(function()
		local t = 0
		while t < seconds and gui.Parent do
			for _, bar in bars do
				bar.Position = UDim2.fromScale(0, math.random())
				bar.Size = UDim2.new(1, 0, 0, math.random(4, 26))
			end
			t += task.wait(0.06)
		end
		gui:Destroy()
	end)
end

function SurvivorController.Start()
	if started then
		return
	end
	started = true
	buildGui()
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "Emp" and typeof(a) == "number" then
			emp(a)
		end
	end)

	ContextActionService:BindAction("DisasterGodDash", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	UserInputService.JumpRequest:Connect(tryMantle)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not gearBar.Visible then
			return
		end
		for i, key in GEAR_KEYS do
			local def = Config.Gear[i]
			if def and input.KeyCode == key then
				Remotes.get("UseGear"):FireServer(def.Id)
			end
		end
	end)

	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshVisibility)
	player:GetAttributeChangedSignal(Attributes.Alive):Connect(refreshVisibility)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(refreshVisibility)
	refreshVisibility()
end

return SurvivorController
