--!strict
-- CosmeticController: renders cosmetics everyone sees.
--   * God sky rig: the God's skin (GodSkin attribute; the AI Director has one too) floats
--     high over the God's aim (GodAimRelay at ~10 Hz, the GodAim attribute as a
--     fallback), glides and banks after it, idles with a bob and orbiting parts, and
--     slams + flashes on every cast (ClientEffect "GodCast"). Always-on-top outline so it
--     reads through glass roofs and storm haze. The God sees it faint, or not at all when
--     their camera is close. No particles on phones or in Low-FX.
--   * Finishers: the effect at an eliminated survivor's body (ClientEffect "Finisher").

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript)
local GodSkins = require(Shared:WaitForChild("GodSkins") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components") :: ModuleScript)

local CO = Config.Cosmetics
local Attributes = Config.Attributes
local player = Players.LocalPlayer

local CosmeticController = {}

local fxFolder: Folder
local sky: Model? = nil
local skyId = ""
local skyPos: Vector3? = nil
local spin = 0
local touch = false

local function setTransparency(model: Model, alpha: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local base = d:GetAttribute("BaseTransparency")
			if typeof(base) ~= "number" then
				base = d.Transparency
				d:SetAttribute("BaseTransparency", base)
			end
			d.Transparency = 1 - (1 - (base :: number)) * (1 - alpha)
		end
	end
end

-- latest relayed aim (GodAimRelay, ~10 Hz); the throttled GodAim attribute covers joins
local liveAim: Vector3? = nil
local gestureLeft = 0
local bank = CFrame.identity
local outlineRef: Highlight? = nil
local lightRef: PointLight? = nil
local orbit: { { Part: BasePart, Offset: CFrame } } = {}
local godAlpha = -1

local function lowFx(): boolean
	return player:GetAttribute(Attributes.SettingPrefix .. "LowFx") == true
end

local function targetAim(): Vector3?
	if liveAim then
		return liveAim
	end
	local a = ReplicatedStorage:GetAttribute(Attributes.GodAim)
	return if typeof(a) == "Vector3" then a else nil
end

local function clearSky()
	if sky then
		sky:Destroy()
		sky = nil
	end
	skyId = ""
	skyPos = nil
	outlineRef = nil
	lightRef = nil
	table.clear(orbit)
	godAlpha = -1
end

local function isGod(): boolean
	return player:GetAttribute(Attributes.Role) == "DisasterGod"
end

local function buildSky(id: string)
	local model = GodSkins.build(id, CO.SkyScale)
	local tint = Color3.fromRGB(255, 255, 255)
	for _, def in CO.Items do
		if def.Id == id and def.Color then
			tint = def.Color
		end
	end
	-- render / physics hygiene: moving it across the sky must never wake physics or
	-- recompute shadows
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
			if d.Material == Enum.Material.SmoothPlastic then
				d.Reflectance = 0.08
			end
			if d.Name == "Orbit" then
				table.insert(orbit, { Part = d, Offset = pivot:ToObjectSpace(d.CFrame) })
			end
		end
	end
	-- emissive rim + faint glow fill, drawn on top so it reads through the Bio-Dome glass
	-- and the Armada's storm haze
	local outline = Instance.new("Highlight")
	outline.FillColor = tint
	outline.FillTransparency = 0.85
	outline.OutlineColor = tint
	outline.OutlineTransparency = CO.SkyOutline
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Parent = model
	outlineRef = outline
	local core = model.PrimaryPart
	if core then
		local light = Instance.new("PointLight")
		light.Color = tint
		light.Range = CO.SkyLightRange
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = core
		lightRef = light
		if not touch and not lowFx() then
			local aura = Instance.new("ParticleEmitter")
			aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			aura.Color = ColorSequence.new(tint)
			aura.LightEmission = 1
			aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
			aura.Transparency = NumberSequence.new(0.3)
			aura.Lifetime = NumberRange.new(1, 1.8)
			aura.Rate = 14
			aura.Speed = NumberRange.new(2, 5)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.Parent = core
		end
	end
	model.Parent = fxFolder
	sky = model
end

local function refreshSky()
	local id = ReplicatedStorage:GetAttribute(Attributes.GodSkin)
	if typeof(id) ~= "string" or id == "" then
		liveAim = nil
		clearSky()
		return
	end
	if not targetAim() then
		return -- spawns on the first aim update
	end
	if id ~= skyId then
		clearSky()
		skyId = id
		buildSky(id)
	end
	godAlpha = -1 -- re-evaluate the God's own fade next frame
end

-- The God sees their own rig faintly, and not at all once the camera is close to it.
local function godFade(model: Model)
	local alpha = 0
	if isGod() then
		local camera = workspace.CurrentCamera
		local near = camera and skyPos and (camera.CFrame.Position - (skyPos :: Vector3)).Magnitude < CO.GodHideDistance
		alpha = if near then 1 else CO.GodSkyTransparency
	end
	if alpha ~= godAlpha then
		godAlpha = alpha
		setTransparency(model, alpha)
		if outlineRef then
			outlineRef.Enabled = alpha < 0.5
		end
	end
end

local function stepSky(dt: number)
	local model = sky
	local aim = targetAim()
	if not model or not aim then
		return
	end
	local goal = aim + Vector3.new(0, CO.SkyHeight, 0)
	local prev = skyPos
	local pos = if prev then prev:Lerp(goal, math.min(1, dt * CO.SkyFollow)) else goal
	skyPos = pos
	-- bank / tilt toward the direction of travel
	local vel = if prev then (pos - prev) / math.max(dt, 1 / 240) else Vector3.zero
	local maxBank = math.rad(CO.BankDegrees)
	local goalBank = CFrame.Angles(math.clamp(vel.Z * 0.012, -maxBank, maxBank), 0, math.clamp(-vel.X * 0.012, -maxBank, maxBank))
	bank = bank:Lerp(goalBank, math.min(1, dt * 5))
	spin += dt * 0.4
	local bob = math.sin(spin * 2) * 1.5
	-- cast gesture: a quick slam toward the target and an emissive flash
	local dip, flash = 0, 0
	if gestureLeft > 0 then
		gestureLeft = math.max(0, gestureLeft - dt)
		local t = 1 - gestureLeft / CO.GestureSeconds
		dip = math.sin(t * math.pi) * CO.GestureDrop
		flash = 1 - t
	end
	local cf = CFrame.new(pos + Vector3.new(0, bob - dip, 0)) * bank * CFrame.Angles(0, spin * 0.5, 0)
	model:PivotTo(cf)
	-- orbiting rings / clouds / gems circle the core
	for i, o in orbit do
		o.Part.CFrame = cf * CFrame.Angles(0, spin * (1.6 + (i % 3) * 0.4), 0) * o.Offset
	end
	if outlineRef then
		outlineRef.FillTransparency = 0.85 - flash * 0.6
	end
	if lightRef then
		lightRef.Brightness = 1.4 + flash * 5
	end
	godFade(model)
end

-- the God (human or AI) cast: swoop to the target and gesture
local function onGodCast(at: Vector3)
	liveAim = at
	if not sky then
		refreshSky()
	end
	gestureLeft = CO.GestureSeconds
end

---------------------------------------------------------------------------
-- finishers

local function burst(position: Vector3, count: number, colors: { Color3 }, size: number, speed: number, life: number, material: Enum.Material?)
	for i = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material or Enum.Material.Neon
		p.Color = colors[(i % #colors) + 1]
		p.Size = Vector3.one * size
		p.CFrame = CFrame.new(position)
		p.Parent = fxFolder
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + dir * speed) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(p, life + 0.05)
	end
end

local CONFETTI = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 200, 40), Color3.fromRGB(90, 220, 90), Color3.fromRGB(70, 160, 255), Color3.fromRGB(200, 100, 255), Color3.fromRGB(255, 120, 200) }

local function finisher(id: string, position: Vector3)
	local scale = if touch then 0.5 else 1 -- fewer pieces on phones
	if id == "GhostRise" then
		local ghost = Instance.new("Part")
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.CanQuery = false
		ghost.CanTouch = false
		ghost.CastShadow = false
		ghost.Shape = Enum.PartType.Ball
		ghost.Size = Vector3.new(3.4, 4.2, 3.4)
		ghost.Material = Enum.Material.Neon
		ghost.Color = Color3.fromRGB(225, 235, 255)
		ghost.Transparency = 0.3
		ghost.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
		ghost.Parent = fxFolder
		local face = Instance.new("BillboardGui")
		face.Size = UDim2.fromScale(3, 3)
		face.AlwaysOnTop = false
		face.Parent = ghost
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = "👻"
		label.Parent = face
		TweenService:Create(ghost, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = ghost.CFrame + Vector3.new(0, 26, 0), Transparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(2.4), { TextTransparency = 1 }):Play()
		Debris:AddItem(ghost, 2.5)
	elseif id == "ConfettiPop" then
		burst(position + Vector3.new(0, 2, 0), math.floor(40 * scale), CONFETTI, 0.6, 16, 1.6, Enum.Material.SmoothPlastic)
	elseif id == "CartoonBoing" then
		burst(position + Vector3.new(0, 3, 0), math.floor(10 * scale), { Color3.fromRGB(255, 230, 80) }, 1, 8, 1.2)
	-- God Pack finishers (the God's pack decides when the survivor has the starter Poof)
	elseif id == "LavaBurst" then
		burst(position + Vector3.new(0, 1, 0), math.floor(18 * scale), { Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 200, 60), Color3.fromRGB(60, 40, 35) }, 1.2, 12, 1.2)
	elseif id == "VoxelDissolve" then
		-- the body breaks into floating cyan voxels that drift up and fade
		burst(position + Vector3.new(0, 2.5, 0), math.floor(28 * scale), { Color3.fromRGB(60, 230, 255), Color3.fromRGB(120, 255, 200), Color3.fromRGB(40, 90, 160) }, 0.8, 7, 2.2)
	elseif id == "SkyBeam" then
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 230, 150)
		beam.Transparency = 0.35
		beam.Size = Vector3.new(220, 5, 5)
		beam.CFrame = CFrame.new(position + Vector3.new(0, 108, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = fxFolder
		TweenService:Create(beam, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { Size = Vector3.new(220, 0.5, 0.5), Transparency = 1 }):Play()
		Debris:AddItem(beam, 1.7)
		burst(position + Vector3.new(0, 2, 0), math.floor(14 * scale), { Color3.fromRGB(255, 240, 180) }, 0.7, 10, 1.4)
	elseif id == "StormBolt" then
		local top = position + Vector3.new(0, 90, 0)
		local prev = top
		for i = 1, 6 do
			local nextPoint = if i == 6 then position else top:Lerp(position, i / 6) + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
			local seg = Instance.new("Part")
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CastShadow = false
			seg.Material = Enum.Material.Neon
			seg.Color = Color3.fromRGB(190, 225, 255)
			seg.Size = Vector3.new(0.9, 0.9, (nextPoint - prev).Magnitude)
			seg.CFrame = CFrame.lookAt((prev + nextPoint) / 2, nextPoint)
			seg.Parent = fxFolder
			Debris:AddItem(seg, 0.35)
			prev = nextPoint
		end
		burst(position + Vector3.new(0, 1, 0), math.floor(12 * scale), { Color3.fromRGB(150, 210, 255), Color3.fromRGB(80, 90, 120) }, 1, 9, 1)
	else
		-- Poof (starter)
		burst(position + Vector3.new(0, 1.5, 0), math.floor(12 * scale), { Color3.fromRGB(200, 200, 210), Color3.fromRGB(160, 160, 170) }, 2.4, 6, 0.9, Enum.Material.SmoothPlastic)
	end
end

function CosmeticController.Start()
	touch = Components.isTouch()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "CosmeticFX"
	fxFolder.Parent = workspace
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.GodSkin):Connect(refreshSky)
	ReplicatedStorage:GetAttributeChangedSignal(Attributes.GodAim):Connect(function()
		if typeof(ReplicatedStorage:GetAttribute(Attributes.GodAim)) ~= "Vector3" then
			liveAim = nil -- a new God / round: wait for their first aim
			skyPos = nil
		elseif not sky then
			refreshSky()
		end
	end)
	Remotes.unreliable("GodAimRelay").OnClientEvent:Connect(function(aim: any)
		if typeof(aim) == "Vector3" then
			liveAim = aim
			if not sky then
				refreshSky()
			end
		end
	end)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshSky)
	RunService.RenderStepped:Connect(stepSky)
	refreshSky()
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "Finisher" and typeof(a) == "string" and typeof(b) == "Vector3" then
			finisher(a, b)
		elseif kind == "GodCast" and typeof(a) == "Vector3" then
			onGodCast(a)
		end
	end)
end

return CosmeticController
