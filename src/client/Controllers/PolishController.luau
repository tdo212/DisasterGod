--!strict
-- PolishController: presentation juice that sits on top of the game.
--   * Round intro: a 2.5 s swooping fly-by of the arena as the round starts, with the
--     God's sky avatar materialising overhead. Round outro: the camera sweeps up to the
--     Hall of Legends in the lodge.
--   * Danger edges: a disaster telegraph that lands outside your view pulses a red glow on
--     that edge of the screen.
--   * Stress cues (ClientEffect "Stress"): dust sifts out of a building about to give way
--     and nearby cameras tremble. Cheers (ClientEffect "Cheer"): fireworks over a survivor.
--   * Arena Cam: a holographic screen in the Sky Lodge shows a live miniature of the match
--     (big parts only, refreshed once a second) so the lobby can watch buildings fall.
--   * The lodge streak chest shows your own day count.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local GodSkins = require(Shared:WaitForChild("GodSkins") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)
local Theme = require(UI:WaitForChild("Theme") :: ModuleScript)
local EffectsController = require(script.Parent:WaitForChild("EffectsController") :: ModuleScript)

local PR = Config.Presentation
local Attributes = Config.Attributes
local player = Players.LocalPlayer

local PolishController = {}

local INTRO_BIND = "DisasterGodIntro"
local OUTRO_BIND = "DisasterGodOutro"

local layer: Frame
local edges: { [string]: Frame } = {}
local fxFolder: Folder

local function lowFx(): boolean
	return player:GetAttribute(Attributes.SettingPrefix .. "LowFx") == true
end

---------------------------------------------------------------------------
-- intro / outro cameras

local function arenaFocus(): (Vector3, number)
	local arena = workspace:FindFirstChild("Arena")
	local model = arena and arena:FindFirstChildOfClass("Model")
	if model then
		local cf, size = model:GetBoundingBox()
		return Vector3.new(cf.Position.X, 10, cf.Position.Z), math.clamp(math.max(size.X, size.Z) * 0.4, 80, 140)
	end
	return Config.World.ArenaCenter, 150
end

local function playIntro()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local center, radius = arenaFocus()
	local a0 = math.random() * math.pi * 2
	local t = 0
	-- the God's avatar fades in over the arena (or the Storm Eye for the AI Director)
	local skinId = ReplicatedStorage:GetAttribute(Attributes.GodSkin)
	local skin = GodSkins.build(if typeof(skinId) == "string" and skinId ~= "" then skinId else "StormEye", 2.2)
	skin:PivotTo(CFrame.new(center + Vector3.new(0, 120, 0)) * CFrame.Angles(0, a0, 0))
	for _, d in skin:GetDescendants() do
		if d:IsA("BasePart") then
			local target = d.Transparency
			d.Transparency = 1
			TweenService:Create(d, TweenInfo.new(PR.IntroSeconds * 0.8), { Transparency = target }):Play()
		end
	end
	skin.Parent = fxFolder
	RunService:BindToRenderStep(INTRO_BIND, Enum.RenderPriority.Camera.Value + 2, function(dt)
		t += dt
		local a = math.min(1, t / PR.IntroSeconds)
		local e = 1 - (1 - a) ^ 2
		local angle = a0 + e * math.rad(70)
		-- high above the decor skyline, sweeping down and in
		local height = 140 - e * 70
		local r = radius * (1 - e * 0.3)
		local pos = center + Vector3.new(math.cos(angle) * r, height, math.sin(angle) * r)
		camera.CFrame = CFrame.lookAt(pos, center + Vector3.new(0, 18 + e * 10, 0))
		if a >= 1 then
			RunService:UnbindFromRenderStep(INTRO_BIND)
			for _, d in skin:GetDescendants() do
				if d:IsA("BasePart") then
					TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
				end
			end
			Debris:AddItem(skin, 0.7)
		end
	end)
end

local function playOutro()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local hall = Config.World.LobbyOrigin + Vector3.new(0, 9, -51)
	local from = camera.CFrame
	local goal = CFrame.lookAt(hall + Vector3.new(0, 4, 26), hall)
	local t = 0
	RunService:BindToRenderStep(OUTRO_BIND, Enum.RenderPriority.Camera.Value + 2, function(dt)
		t += dt
		local a = math.min(1, t / PR.OutroSeconds)
		camera.CFrame = from:Lerp(goal, 1 - (1 - a) ^ 3)
		if a >= 1 then
			RunService:UnbindFromRenderStep(OUTRO_BIND)
		end
	end)
end

---------------------------------------------------------------------------
-- danger edges

local function edge(name: string, size: UDim2, position: UDim2, rotation: number)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	f.ZIndex = 1
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	f.Parent = layer
	edges[name] = f
end

local function pulse(name: string)
	local f = edges[name]
	if not f then
		return
	end
	f.BackgroundTransparency = 0.35
	TweenService:Create(f, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
end

local function onTelegraph(part: Instance)
	if part.Name ~= "Telegraph" or not part:IsA("BasePart") then
		return
	end
	local role = player:GetAttribute(Attributes.Role)
	if role ~= "Survivor" or player:GetAttribute(Attributes.Alive) ~= true then
		return
	end
	local camera = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (camera and root) then
		return
	end
	local offset = part.Position - root.Position
	if offset.Magnitude > PR.DangerRange then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1 then
		return
	end
	local dir = flat.Unit
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	if dir:Dot(forward) > PR.DangerDot then
		return -- you can see it
	end
	local right = camera.CFrame.RightVector
	local side = dir:Dot(Vector3.new(right.X, 0, right.Z).Unit)
	if dir:Dot(forward) < -0.6 then
		pulse("Bottom")
	elseif side > 0 then
		pulse("Right")
	else
		pulse("Left")
	end
end

---------------------------------------------------------------------------
-- world effects

local function burst(position: Vector3, colors: { Color3 }, count: number, speed: number)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Size = Vector3.one * 0.6
		p.Color = colors[(i % #colors) + 1]
		p.CFrame = CFrame.new(position)
		p.Parent = fxFolder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6 + 0.2, math.random() - 0.5).Unit
		TweenService:Create(p, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(position + dir * speed), Transparency = 1 }):Play()
		Debris:AddItem(p, 1.2)
	end
end

local FIREWORK = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 220, 120), Color3.fromRGB(90, 170, 255), Color3.fromRGB(220, 110, 255) }

local function onCheer(kind: string, position: Vector3)
	if lowFx() then
		return
	end
	if kind == "Cheer" then
		for k = 0, 2 do
			task.delay(k * 0.25, function()
				burst(position + Vector3.new(math.random(-4, 4), 14 + k * 3, math.random(-4, 4)), FIREWORK, 18, 9)
			end)
		end
	else
		burst(position + Vector3.new(0, 3, 0), if kind == "Berry" then { Color3.fromRGB(230, 60, 120) } else { Color3.fromRGB(255, 240, 230) }, 10, 4)
	end
end

local function onStress(center: Vector3, size: Vector3, radius: number, shake: number)
	local camera = workspace.CurrentCamera
	if camera and (camera.Focus.Position - center).Magnitude <= radius + size.Magnitude / 2 then
		EffectsController.Shake(shake, 0.3, center)
	end
	if lowFx() then
		return
	end
	local dust = Instance.new("Part")
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.CanTouch = false
	dust.Transparency = 1
	dust.Size = Vector3.new(math.min(size.X, 40), 1, math.min(size.Z, 40))
	dust.CFrame = CFrame.new(center + Vector3.new(0, size.Y / 2 - 1, 0))
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/smoke_main.dds"
	p.Color = ColorSequence.new(Color3.fromRGB(200, 185, 160))
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	p.Lifetime = NumberRange.new(1.2, 2)
	p.Speed = NumberRange.new(2, 5)
	p.EmissionDirection = Enum.NormalId.Bottom
	p.Acceleration = Vector3.new(0, -6, 0)
	p.Rate = 0
	p.Parent = dust
	dust.Parent = fxFolder
	p:Emit(if Components.isTouch() then 14 else 30)
	Debris:AddItem(dust, 2.2)
end

---------------------------------------------------------------------------
-- Arena Cam (lodge hologram)

local camScreen: Part? = nil
local viewport: ViewportFrame? = nil
local camWorld: Model? = nil
local mirrors: { [BasePart]: BasePart } = {}
local dots: { [Player]: BasePart } = {}
local camAngle = 0

local function buildScreen()
	local origin = Config.World.LobbyOrigin
	local screen = Instance.new("Part")
	screen.Name = "ArenaCam"
	screen.Anchored = true
	screen.CanCollide = false
	screen.CanQuery = false
	screen.Size = Vector3.new(26, 14, 0.4)
	screen.CFrame = CFrame.new(origin + Vector3.new(-48, 14, -48)) * CFrame.Angles(0, math.rad(35), 0)
	screen.Color = Color3.fromRGB(20, 30, 45)
	screen.Material = Enum.Material.SmoothPlastic
	screen.Parent = fxFolder
	local frame = Instance.new("Part")
	frame.Name = "ArenaCamFrame"
	frame.Anchored = true
	frame.CanCollide = false
	frame.CanQuery = false
	frame.Size = Vector3.new(27, 15, 0.3)
	frame.CFrame = screen.CFrame * CFrame.new(0, 0, 0.25)
	frame.Color = Color3.fromRGB(70, 210, 255)
	frame.Material = Enum.Material.Neon
	frame.Transparency = 0.4
	frame.Parent = fxFolder
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.PixelsPerStud = 24
	surface.LightInfluence = 0
	surface.Parent = screen
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundColor3 = Color3.fromRGB(10, 16, 26)
	vp.Ambient = Color3.fromRGB(170, 180, 200)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.Parent = surface
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 40)
	title.FontFace = Theme.FontFace
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(120, 230, 255)
	title.Text = "🔴 ARENA CAM · LIVE"
	title.ZIndex = 2
	title.Parent = vp
	camScreen = screen
	viewport = vp
end

local function clearMirror()
	if camWorld then
		camWorld:Destroy()
		camWorld = nil
	end
	table.clear(mirrors)
	for _, dot in dots do
		dot:Destroy()
	end
	table.clear(dots)
end

local function mirrorArena()
	clearMirror()
	local vp = viewport
	local arena = workspace:FindFirstChild("Arena")
	if not (vp and arena) then
		return
	end
	local world = Instance.new("Model")
	world.Name = "Mirror"
	local minSize = if Components.isTouch() then PR.ArenaCamMinSize * 1.6 else PR.ArenaCamMinSize
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d.Transparency < 0.9 and math.max(d.Size.X, d.Size.Y, d.Size.Z) >= minSize and d.Name ~= "Sea" then
			local copy = d:Clone()
			copy:ClearAllChildren()
			copy.Parent = world
			mirrors[d] = copy
		end
	end
	world.Parent = vp
	camWorld = world
end

local function refreshMirror()
	local vp = viewport
	if not (vp and camWorld) then
		return
	end
	for original, copy in mirrors do
		if not original.Parent or not original.Anchored or original:GetAttribute("Broken") == true then
			copy:Destroy()
			mirrors[original] = nil
		elseif copy.CFrame ~= original.CFrame then
			copy.CFrame = original.CFrame -- listing ships, toppling towers
		end
	end
	-- survivors as bright dots
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local alive = p:GetAttribute(Attributes.Role) == "Survivor" and p:GetAttribute(Attributes.Alive) == true
		local dot = dots[p]
		if root and alive then
			if not dot then
				local d = Instance.new("Part")
				d.Shape = Enum.PartType.Ball
				d.Size = Vector3.one * 5
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromRGB(90, 255, 140)
				d.Anchored = true
				d.Parent = camWorld
				dots[p] = d
				dot = d
			end
			(dot :: BasePart).CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0))
		elseif dot then
			dot:Destroy()
			dots[p] = nil
		end
	end
	local center, radius = arenaFocus()
	camAngle += 0.12
	local cam = vp.CurrentCamera
	if cam then
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(camAngle) * radius * 1.5, radius * 0.9, math.sin(camAngle) * radius * 1.5), center)
	end
end

local function updateChest()
	local lodge = workspace:FindFirstChild("SkyLodge")
	local chest = lodge and lodge:FindFirstChild("StreakChest")
	local label = chest and chest:FindFirstChild("StreakLabel", true)
	local text = label and label:FindFirstChildOfClass("TextLabel")
	if text then
		local streak = player:GetAttribute(Attributes.LoginStreak) :: number? or 0
		local ready = player:GetAttribute(Attributes.StreakReady) == true
		local day = (math.max(1, streak) - 1) % #Config.Daily.Rewards + 1
		text.Text = if ready then string.format("🎁 DAY %d CHEST · READY!", day) else string.format("🔥 %d-DAY STREAK", streak)
	end
end

---------------------------------------------------------------------------

function PolishController.Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "PolishFX"
	fxFolder.Parent = workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "DangerHUD"
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 0
	gui.Parent = player:WaitForChild("PlayerGui")
	layer = Components.scaledRoot(gui)
	edge("Left", UDim2.fromScale(0.12, 1), UDim2.fromScale(0, 0), 0)
	edge("Right", UDim2.fromScale(0.12, 1), UDim2.fromScale(0.88, 0), 180)
	edge("Bottom", UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0.84), 270)

	local hazards = workspace:WaitForChild("Hazards", 10)
	if hazards then
		hazards.ChildAdded:Connect(onTelegraph)
	end

	local previous = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.RoundPhase):Connect(function()
		local phase = ReplicatedStorage:GetAttribute(Attributes.RoundPhase)
		if phase == "Active" and previous ~= "Active" then
			task.delay(0.6, playIntro) -- after the teleport into the arena
			task.delay(1.2, mirrorArena)
		elseif phase == "RoundEnd" and previous == "Active" then
			task.delay(Config.Feed.FinalKillHold + 0.4, playOutro)
		elseif phase == "Intermission" then
			clearMirror()
		end
		previous = phase
	end)

	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any)
		if kind == "Cheer" and typeof(a) == "string" and typeof(b) == "Vector3" then
			onCheer(a, b)
		elseif kind == "Stress" and typeof(a) == "Vector3" and typeof(b) == "Vector3" then
			onStress(a, b, if typeof(c) == "number" then c else 45, if typeof(d) == "number" then d else 0.25)
		end
	end)

	buildScreen()
	task.spawn(function()
		while true do
			task.wait(PR.ArenaCamInterval)
			local camera = workspace.CurrentCamera
			-- only worth drawing while you are up in the lodge
			if camScreen and camera and camera.CFrame.Position.Y > Config.Weather.MaxCameraHeight and not lowFx() then
				if not camWorld and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active" then
					mirrorArena()
				end
				refreshMirror()
			end
			updateChest()
		end
	end)
end

return PolishController
