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
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)
local C = Theme.Colors
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

---------------------------------------------------------------------------
-- first-round cinematic (show, don't tell): the first time you play each role, the
-- intro fly-by continues into a short letterboxed sequence instead of a text card.
--   Survivor: the God's hand in the sky ("a player controls the disasters"), a harmless
--   demo red zone + meteor right in front of you ("red = get out"), then you ("survive").
--   God: the survivors, highlighted ("real players hiding from you"), then the arena from
--   your hand while a demo strike lands ("you control the disasters").
-- Everything here is client-only and happens during the prep phase, before casting opens.

local CINE_BIND = "DisasterGodCinematic"
local cineGui: ScreenGui? = nil
local cineTitle: TextLabel? = nil
local cineSub: TextLabel? = nil

local function cinematicGui()
	if cineGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CinematicHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.Name = if top then "TopBar" else "BottomBar"
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, PR.CinematicBar)
		bar.Position = if top then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1 - PR.CinematicBar)
		bar.Parent = gui
	end
	local layer2 = Components.scaledRoot(gui)
	local title = Components.label({ Name = "Title", Text = "", TextSize = 40, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -96), Parent = layer2 })
	local sub = Components.label({ Name = "Sub", Text = "", TextSize = 21, Color = C.TextDim, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 1, -46), Parent = layer2 })
	cineGui, cineTitle, cineSub = gui, title, sub
end

local function caption(title: string, sub: string, color: Color3)
	local t, s = cineTitle, cineSub
	if not (t and s) then
		return
	end
	t.Text = title
	t.TextColor3 = color
	s.Text = sub
	local scale = t:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = t
	Components.tween(scale, Theme.Tweens.Pop, { Scale = 1 })
	Sound.play("Banner", 0.6)
end

-- a client-only demo disaster: a pulsing red zone, then a meteor slams into it
local function demoStrike(at: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "DemoZone"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.3, 16, 16)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fxFolder
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.7 }):Play()
	Sound.play("Warning", 0.5)
	task.delay(PR.DemoImpactDelay, function()
		local rock = Instance.new("Part")
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.one * 5
		rock.Material = Enum.Material.Basalt
		rock.Color = Color3.fromRGB(70, 50, 45)
		rock.CFrame = CFrame.new(at + Vector3.new(14, 70, 6))
		rock.Parent = fxFolder
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Parent = rock
		local fall = TweenService:Create(rock, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) })
		fall:Play()
		fall.Completed:Once(function()
			rock:Destroy()
			ring:Destroy()
			local boom = Instance.new("Part")
			boom.Anchored = true
			boom.CanCollide = false
			boom.CanQuery = false
			boom.Shape = Enum.PartType.Ball
			boom.Material = Enum.Material.Neon
			boom.Color = Color3.fromRGB(255, 150, 50)
			boom.Size = Vector3.one * 2
			boom.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
			boom.Parent = fxFolder
			TweenService:Create(boom, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 18, Transparency = 1 }):Play()
			Debris:AddItem(boom, 0.55)
			Sound.play("Smash", 0.8)
			EffectsController.Shake(0.6, 0.4, at)
		end)
	end)
end

local function groundAhead(distance: number): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, fxFolder }
	local hit = workspace:Raycast(root.Position + look * distance + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else root.Position + look * distance - Vector3.new(0, 3, 0)
end

-- a list of camera shots, each { Seconds, Shot(t 0..1) -> CFrame, Start() }
type Shot = { Seconds: number, Camera: (number) -> CFrame, Start: () -> () }

local cinematicRunning = false

local function runShots(shots: { Shot }, done: () -> ())
	local camera = workspace.CurrentCamera
	if not camera or cinematicRunning then
		return -- one at a time: a second bind with the same name would orphan the first
	end
	cinematicRunning = true
	cinematicGui()
	local gui = cineGui :: ScreenGui
	gui.Enabled = true
	player:SetAttribute("Cinematic", true)
	-- a clean frame: every other HUD hides for the cinematic and comes back after
	local hidden: { ScreenGui } = {}
	for _, other in player:WaitForChild("PlayerGui"):GetChildren() do
		if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
			other.Enabled = false
			table.insert(hidden, other)
		end
	end
	local index, elapsed = 0, 0
	local current: Shot? = nil
	local from = camera.CFrame
	local function nextShot()
		index += 1
		elapsed = 0
		current = shots[index]
		from = camera.CFrame
		if current then
			current.Start()
		end
	end
	-- ends exactly once: from the last shot, or from the safety timer if anything stalls
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(CINE_BIND)
		gui.Enabled = false
		for _, other in hidden do
			if other.Parent then
				other.Enabled = true
			end
		end
		player:SetAttribute("Cinematic", false)
		cinematicRunning = false
		done()
	end
	local total = 0
	for _, shot in shots do
		total += shot.Seconds
	end
	task.delay(total + 1.5, finish)
	nextShot()
	RunService:BindToRenderStep(CINE_BIND, Enum.RenderPriority.Camera.Value + 3, function(dt)
		local shot = current
		if not shot then
			finish()
			return
		end
		elapsed += dt
		local a = math.min(1, elapsed / shot.Seconds)
		-- ease from wherever the camera was into the shot over its first 35%
		local blend = math.min(1, a / 0.35)
		blend = 1 - (1 - blend) ^ 3
		camera.CFrame = from:Lerp(shot.Camera(a), blend)
		if a >= 1 then
			nextShot()
		end
	end)
end

local function godRigPosition(center: Vector3): Vector3
	local cfx = workspace:FindFirstChild("CosmeticFX")
	local rig = cfx and cfx:FindFirstChildWhichIsA("Model")
	if rig and string.sub(rig.Name, 1, 8) == "GodSkin_" then
		return rig:GetPivot().Position
	end
	return center + Vector3.new(0, Config.Cosmetics.SkyHeight + 10, 0)
end

local function markSeen(id: string)
	Remotes.get("TutorialSeen"):FireServer(id)
	player:SetAttribute(Attributes.TutorialPrefix .. id, true) -- locally at once; the profile follows
end

-- one intro per player, ever: whichever role they get first. The round-start GOD vs
-- SURVIVORS reveal (RoleRevealController) covers the other role every round.
local function introSeen(): boolean
	for _, id in Config.Tutorial.Cinematics do
		if player:GetAttribute(Attributes.TutorialPrefix .. id) == true then
			return true
		end
	end
	return false
end

local function markIntroSeen()
	for _, id in Config.Tutorial.Cinematics do
		markSeen(id)
	end
end

local function survivorCinematic()
	local center = arenaFocus()
	local godName = ReplicatedStorage:GetAttribute(Attributes.GodName)
	local who = if typeof(godName) == "string" and godName ~= "" then godName else "The Storm"
	local strikeAt: Vector3? = nil
	runShots({
		{
			Seconds = PR.CinematicGodShot,
			Start = function()
				caption("😈 THIS IS THE GOD", who .. " controls every disaster, and is hunting you", C.PurpleLight)
			end,
			Camera = function(a)
				local rig = godRigPosition(center)
				local eye = rig + Vector3.new(math.cos(a * 0.6) * 46, -34, math.sin(a * 0.6) * 46)
				return CFrame.lookAt(eye, rig)
			end,
		},
		{
			Seconds = PR.CinematicDemoShot,
			Start = function()
				strikeAt = groundAhead(22)
				if strikeAt then
					demoStrike(strikeAt)
				end
				caption("🔴 RED ZONE = INCOMING DISASTER", "Get out of the red before it lands", C.RedLight)
			end,
			Camera = function(a)
				local at = strikeAt or center
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local from = if root then root.Position else at + Vector3.new(0, 0, 30)
				local flat = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
				local back = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
				return CFrame.lookAt(from - back * 14 + Vector3.new(0, 12 + a * 2, 0), at)
			end,
		},
		{
			Seconds = PR.CinematicYouShot,
			Start = function()
				caption("🏃 YOU ARE A SURVIVOR", "Dodge, hide and outlast the God", C.GreenLight)
			end,
			Camera = function(a)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local p = if root then root.Position else center
				local look = if root then root.CFrame.LookVector else Vector3.zAxis
				return CFrame.lookAt(p - look * (9 + a * 3) + Vector3.new(0, 4.5, 0), p + Vector3.new(0, 2, 0))
			end,
		},
	}, function()
		markIntroSeen()
	end)
end

local function godCinematic()
	local center, radius = arenaFocus()
	local targets: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute(Attributes.Role) == "Survivor" and p.Character then
			table.insert(targets, p.Character)
		end
	end
	local marks: { Highlight } = {}
	runShots({
		{
			Seconds = PR.CinematicSurvivorsShot,
			Start = function()
				for i, character in targets do
					if i > 4 then
						break
					end
					local h = Instance.new("Highlight")
					h.FillColor = C.GreenLight
					h.FillTransparency = 0.4
					h.OutlineColor = Color3.new(1, 1, 1)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = character
					table.insert(marks, h)
				end
				caption(if #targets > 0 then "🏃 THESE ARE THE SURVIVORS" else "🏃 SURVIVORS HIDE IN HERE", "Real players, scattering and hiding from you", C.GreenLight)
			end,
			Camera = function(a)
				local focus = center
				if #targets > 0 then
					local i = math.clamp(math.floor(a * #targets) + 1, 1, #targets)
					local root = targets[i]:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						focus = root.Position
					end
				end
				return CFrame.lookAt(focus + Vector3.new(26, 30, 26), focus)
			end,
		},
		{
			Seconds = PR.CinematicGodShot,
			Start = function()
				for _, h in marks do
					h:Destroy()
				end
				demoStrike(center)
				caption("😈 YOU ARE THE GOD", "You control the disasters. Wipe them out!", C.PurpleLight)
			end,
			Camera = function(a)
				local eye = center + Vector3.new(math.cos(a * 0.8) * radius * 0.5, 80 - a * 10, math.sin(a * 0.8) * radius * 0.5)
				return CFrame.lookAt(eye, center)
			end,
		},
	}, function()
		markIntroSeen()
	end)
end

-- after the fly-by of a player's very first round: the cinematic for the role they got
local function firstTimeCinematic()
	if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" or introSeen() then
		return
	end
	local role = player:GetAttribute(Attributes.Role)
	if role == "Survivor" then
		survivorCinematic()
	elseif role == "DisasterGod" then
		godCinematic()
	end
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
			firstTimeCinematic()
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
-- Arena Cam (lodge hologram): a live broadcast of the match, separate from the God view.
-- The arena's big parts are mirrored into a ViewportFrame once per round and kept in
-- sync (collapses fall, debris tumbles); disasters (Hazards), survivors (little figures
-- with beacons) and the God's sky rig are mirrored every few frames. A director camera
-- cuts between an orbit, the latest disaster and a survivor close-up. Only runs while
-- you are up in the lodge and near the screen; off in Low-FX.

local camScreen: Part? = nil
local viewport: ViewportFrame? = nil
local camWorld: Model? = nil
local camFx: Model? = nil
local mirrors: { [BasePart]: BasePart } = {}
local fxMirrors: { [BasePart]: BasePart } = {}
local figures: { [Player]: Model } = {}
local godMirror: Model? = nil
local camAngle = 0
local camCf: CFrame? = nil
local shot = "Orbit"
local shotUntil = 0
local shotTarget: Vector3? = nil
local lastAction: Vector3? = nil
local lastActionAt = 0
local shotLabel: TextLabel? = nil
local fxAccum = 0

local function buildScreen()
	local origin = Config.World.LobbyOrigin
	local screen = Instance.new("Part")
	screen.Name = "ArenaCam"
	screen.Anchored = true
	screen.CanCollide = false
	screen.CanQuery = false
	screen.Size = Vector3.new(26, 14, 0.4)
	-- mounted high on the back wall above the boards, tilted down at the room like a bar TV
	screen.CFrame = CFrame.new(origin + PR.ArenaCamOffset) * CFrame.Angles(0, math.rad(PR.ArenaCamYaw), 0) * CFrame.Angles(-math.rad(PR.ArenaCamPitch), 0, 0)
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
	-- a dark mounting arm from the back of the screen into the wall
	local mount = screen.Position + screen.CFrame.LookVector * -0.4
	local wallZ = origin.Z + PR.ArenaCamWallZ
	local reach = math.abs(mount.Z - wallZ)
	if reach > 0.2 then
		local arm = Instance.new("Part")
		arm.Name = "ArenaCamMount"
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.Size = Vector3.new(4, 2, reach)
		arm.CFrame = CFrame.new(mount.X, mount.Y, (mount.Z + wallZ) / 2)
		arm.Color = Color3.fromRGB(35, 38, 45)
		arm.Material = Enum.Material.Metal
		arm.Parent = fxFolder
	end
	-- a ViewportFrame only renders when its SurfaceGui lives in PlayerGui (adorned to the
	-- part); parented to the part itself it draws nothing
	local surface = Instance.new("SurfaceGui")
	surface.Name = "ArenaCamGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 32
	surface.LightInfluence = 0
	surface.ResetOnSpawn = false
	surface.Adornee = screen
	surface.Parent = player:WaitForChild("PlayerGui")
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundColor3 = Color3.fromRGB(120, 170, 220)
	vp.Ambient = Color3.fromRGB(170, 180, 200)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.3)
	vp.Parent = surface
	vp.BackgroundColor3 = Color3.fromRGB(110, 160, 215) -- plain sky (a UIGradient would tint the whole render)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 45
	cam.Parent = vp
	vp.CurrentCamera = cam
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.fromOffset(10, 6)
	title.FontFace = Theme.FontFace
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "🔴 ARENA CAM · LIVE"
	title.ZIndex = 2
	title.Parent = vp
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = title
	local label = title:Clone()
	label.Name = "Shot"
	label.Position = UDim2.new(0, 10, 1, -40)
	label.Size = UDim2.new(1, -20, 0, 32)
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.Parent = vp
	shotLabel = label
	-- between rounds: a title card instead of an empty feed
	local idle = title:Clone()
	idle.Name = "Idle"
	idle.Position = UDim2.fromScale(0.5, 0.5)
	idle.AnchorPoint = Vector2.new(0.5, 0.5)
	idle.Size = UDim2.new(0.8, 0, 0, 56)
	idle.TextXAlignment = Enum.TextXAlignment.Center
	idle.Text = "NEXT ROUND SOON · WATCH IT LIVE HERE"
	idle.TextColor3 = Color3.fromRGB(120, 230, 255)
	idle.Parent = vp
	camScreen = screen
	viewport = vp
end

local function clearMirror()
	for _, m in { camWorld, camFx } do
		if m then
			m:Destroy()
		end
	end
	camWorld = nil
	camFx = nil
	godMirror = nil
	table.clear(mirrors)
	table.clear(fxMirrors)
	table.clear(figures)
	camCf = nil
end

local function copyOf(part: BasePart): BasePart
	local copy = part:Clone()
	for _, c in copy:GetChildren() do
		if not (c:IsA("SpecialMesh") or c:IsA("Decal") or c:IsA("Texture")) then
			c:Destroy()
		end
	end
	copy.Anchored = true
	return copy
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
	camWorld = world -- claimed now so the sync loop doesn't start a second copy
	local minSize = if Components.isTouch() then PR.ArenaCamMinSize * 1.6 else PR.ArenaCamMinSize
	-- copied in chunks across frames (a whole arena in one frame was a visible hitch)
	local copied = 0
	for _, d in arena:GetDescendants() do
		if d:IsA("BasePart") and d.Parent and d.Transparency < 0.9 and math.max(d.Size.X, d.Size.Y, d.Size.Z) >= minSize and d.Name ~= "Sea" then
			local copy = copyOf(d)
			copy.Parent = world
			mirrors[d] = copy
			copied += 1
			if copied % PR.ArenaCamCopyChunk == 0 then
				task.wait()
				if camWorld ~= world then
					world:Destroy() -- the round ended while copying
					return
				end
			end
		end
	end
	-- the sea / lava plane as a flat colour sheet
	local sea = arena:FindFirstChild("Sea", true)
	if sea and sea:IsA("BasePart") then
		local s = copyOf(sea)
		s.Size = Vector3.new(900, 1, 900)
		s.Parent = world
		mirrors[sea] = s
	end
	world.Parent = vp
	camWorld = world
	local fx = Instance.new("Model")
	fx.Name = "Live"
	fx.Parent = vp
	camFx = fx
end

-- structure: collapses fall and tumble on the screen, destroyed parts vanish
local function syncStructure()
	for original, copy in mirrors do
		if not original.Parent then
			copy:Destroy()
			mirrors[original] = nil
		elseif copy.CFrame ~= original.CFrame or copy.Size ~= original.Size then
			copy.CFrame = original.CFrame
			copy.Size = original.Size
			copy.Transparency = original.Transparency
		end
	end
end

local function figure(color: Color3): Model
	local m = Instance.new("Model")
	local function bit(size: Vector3, offset: Vector3, c: Color3, shape: Enum.PartType?, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Anchored = true
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p:SetAttribute("Offset", offset)
		p.Parent = m
	end
	bit(Vector3.new(2.4, 3, 1.4), Vector3.new(0, 0, 0), color)
	bit(Vector3.one * 2, Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 220, 180), Enum.PartType.Ball)
	bit(Vector3.new(2.4, 2.6, 1.4), Vector3.new(0, -2.8, 0), Color3.fromRGB(50, 60, 90))
	bit(Vector3.new(0.6, 30, 0.6), Vector3.new(0, 18, 0), color, nil, Enum.Material.Neon) -- beacon
	return m
end

-- disasters, survivors and the God rig (several times a second)
local function syncLive()
	local fx = camFx
	if not fx then
		return
	end
	local hazards = workspace:FindFirstChild("Hazards")
	local seen: { [BasePart]: boolean } = {}
	if hazards then
		local count = 0
		for _, d in hazards:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.98 and count < PR.ArenaCamMaxFx then
				count += 1
				seen[d] = true
				local copy = fxMirrors[d]
				if not copy then
					copy = copyOf(d)
					copy.Parent = fx
					fxMirrors[d] = copy
					if d.Name == "Telegraph" or d.Name == "Ring" then
						lastAction = d.Position
						lastActionAt = os.clock()
					end
				end
				local c = copy :: BasePart
				c.CFrame = d.CFrame
				c.Size = d.Size
				c.Transparency = d.Transparency
				c.Color = d.Color
			end
		end
	end
	for original, copy in fxMirrors do
		if not seen[original] then
			copy:Destroy()
			fxMirrors[original] = nil
		end
	end
	-- survivors
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local alive = p:GetAttribute(Attributes.Role) == "Survivor" and p:GetAttribute(Attributes.Alive) == true
		local fig = figures[p]
		if root and alive then
			if not fig then
				fig = figure(if p == player then Color3.fromRGB(255, 220, 60) else Color3.fromRGB(90, 255, 140))
				fig.Parent = fx
				figures[p] = fig
			end
			local base = CFrame.new(root.Position) * (root.CFrame - root.CFrame.Position)
			for _, part in (fig :: Model):GetChildren() do
				if part:IsA("BasePart") then
					part.CFrame = base * CFrame.new(part:GetAttribute("Offset") :: Vector3)
				end
			end
		elseif fig then
			fig:Destroy()
			figures[p] = nil
		end
	end
	for p, fig in figures do
		if not p.Parent then
			fig:Destroy()
			figures[p] = nil
		end
	end
	-- the God's hand in the sky
	local skyRig = workspace:FindFirstChild("CosmeticFX")
	local rig = skyRig and skyRig:FindFirstChildWhichIsA("Model")
	if rig and rig.Name:sub(1, 8) == "GodSkin_" then
		if not godMirror or godMirror.Name ~= rig.Name then
			if godMirror then
				godMirror:Destroy()
			end
			local m = Instance.new("Model")
			m.Name = rig.Name
			for _, part in rig:GetDescendants() do
				if part:IsA("BasePart") then
					local c = copyOf(part)
					local base = part:GetAttribute("BaseTransparency")
					c.Transparency = if typeof(base) == "number" then base else 0
					c:SetAttribute("Source", part.Name)
					c.Parent = m
				end
			end
			m.Parent = fx
			godMirror = m
		end
		local gm = godMirror :: Model
		gm:PivotTo(rig:GetPivot())
	elseif godMirror then
		godMirror:Destroy()
		godMirror = nil
	end
end

-- director camera: orbit, the latest disaster, a survivor close-up
local function pickShot(center: Vector3)
	local now = os.clock()
	local survivors: { Vector3 } = {}
	for p in figures do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(survivors, root.Position)
		end
	end
	local roll = math.random()
	if lastAction and now - lastActionAt < PR.ArenaCamActionMemory and roll < 0.55 then
		shot, shotTarget = "Action", lastAction
	elseif #survivors > 0 and roll < 0.8 then
		shot, shotTarget = "Survivor", survivors[math.random(#survivors)]
	else
		shot, shotTarget = "Orbit", center
	end
	shotUntil = now + PR.ArenaCamShotSeconds
	if shotLabel then
		shotLabel.Text = if shot == "Action" then "⚡ DISASTER CAM" elseif shot == "Survivor" then "🏃 SURVIVOR CAM" else "🛰️ OVERVIEW"
	end
end

local function stepCamera(dt: number)
	local vp = viewport
	local cam = vp and vp.CurrentCamera
	if not cam then
		return
	end
	local center, radius = arenaFocus()
	if os.clock() > shotUntil then
		pickShot(center)
	end
	camAngle += dt * 0.15
	local goal: CFrame
	if shot == "Orbit" or not shotTarget then
		goal = CFrame.lookAt(center + Vector3.new(math.cos(camAngle) * radius * 1.2, radius * 0.95, math.sin(camAngle) * radius * 1.2), center)
	else
		-- close-ups look down from well above so walls and roofs never block the shot
		local t = shotTarget :: Vector3
		local dist = if shot == "Action" then 55 else 34
		local height = if shot == "Action" then 70 else 52
		goal = CFrame.lookAt(t + Vector3.new(math.cos(camAngle * 2) * dist, height, math.sin(camAngle * 2) * dist), t)
	end
	local prev = camCf
	camCf = if prev then prev:Lerp(goal, math.min(1, dt * 2.5)) else goal
	cam.CFrame = camCf :: CFrame
end

local function setIdle(on: boolean)
	local vp = viewport
	local idle = vp and vp:FindFirstChild("Idle")
	if idle and idle:IsA("TextLabel") then
		idle.Visible = on
	end
	if shotLabel then
		shotLabel.Visible = not on
	end
end

local function camVisible(): boolean
	local camera = workspace.CurrentCamera
	local screen = camScreen
	if not (camera and screen) or lowFx() then
		return false
	end
	local pos = camera.CFrame.Position
	return pos.Y > Config.Weather.MaxCameraHeight and (pos - screen.Position).Magnitude < PR.ArenaCamViewDistance
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
			-- the Arena Cam copies the arena lazily, only once someone in the lodge can see it
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
	-- structure sync (cheap-ish, a few times a second) + the lodge chest label
	task.spawn(function()
		while true do
			task.wait(PR.ArenaCamInterval)
			if camVisible() then
				if not camWorld and ReplicatedStorage:GetAttribute(Attributes.RoundPhase) == "Active" then
					mirrorArena()
				end
				syncStructure()
			end
			setIdle(camWorld == nil)
			updateChest()
		end
	end)
	-- live layer + director camera, only while someone in the lodge can see the screen
	RunService.RenderStepped:Connect(function(dt)
		if not camWorld or not camFx or not camVisible() then
			return
		end
		fxAccum += dt
		if fxAccum >= 1 / PR.ArenaCamLiveRate then
			fxAccum = 0
			syncLive()
		end
		stepCamera(dt)
	end)
end

return PolishController
