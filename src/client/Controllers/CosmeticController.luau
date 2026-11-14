--!strict
-- CosmeticController: renders cosmetics everyone sees.
--   * God skin: while a human God plays, their equipped skin (GodSkin attribute) floats
--     high over their reticle (GodAim attribute) and glides after it. The God sees their
--     own skin almost transparent so it never blocks the view.
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

local function clearSky()
	if sky then
		sky:Destroy()
		sky = nil
	end
	skyId = ""
	skyPos = nil
end

local function refreshSky()
	local id = ReplicatedStorage:GetAttribute(Attributes.GodSkin)
	local aim = ReplicatedStorage:GetAttribute(Attributes.GodAim)
	if typeof(id) ~= "string" or id == "" or typeof(aim) ~= "Vector3" then
		clearSky()
		return
	end
	if id ~= skyId then
		clearSky()
		skyId = id
		local model = GodSkins.build(id, CO.SkyScale)
		-- high quality from below: crisp edges, a coloured outline and a glow that lights
		-- the arena under the hand, plus a slow sparkle aura
		local tint = Color3.fromRGB(255, 255, 255)
		for _, def in CO.Items do
			if def.Id == id and def.Color then
				tint = def.Color
			end
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
				if d.Material == Enum.Material.SmoothPlastic then
					d.Reflectance = 0.08
				end
			end
		end
		local outline = Instance.new("Highlight")
		outline.FillTransparency = 1
		outline.OutlineColor = tint
		outline.OutlineTransparency = CO.SkyOutline
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
		local core = model.PrimaryPart
		if core then
			local light = Instance.new("PointLight")
			light.Color = tint
			light.Range = CO.SkyLightRange
			light.Brightness = 1.4
			light.Shadows = false
			light.Parent = core
			if not touch then
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
	local model = sky
	if model then
		local isGod = player:GetAttribute(Attributes.Role) == "DisasterGod"
		setTransparency(model, if isGod then CO.GodSkyTransparency else 0)
		local outline = model:FindFirstChildOfClass("Highlight")
		if outline then
			outline.OutlineTransparency = if isGod then 0.9 else CO.SkyOutline
		end
	end
end

local function stepSky(dt: number)
	local model = sky
	local aim = ReplicatedStorage:GetAttribute(Attributes.GodAim)
	if not model or typeof(aim) ~= "Vector3" then
		return
	end
	local goal = aim + Vector3.new(0, CO.SkyHeight, 0)
	skyPos = if skyPos then skyPos:Lerp(goal, math.min(1, dt * CO.SkyFollow)) else goal
	spin += dt * 0.4
	local bob = math.sin(spin * 2) * 1.5
	model:PivotTo(CFrame.new((skyPos :: Vector3) + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, 0))
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
			clearSky() -- round over / the God left
		elseif not sky then
			refreshSky()
		end
	end)
	player:GetAttributeChangedSignal(Attributes.Role):Connect(refreshSky)
	RunService.RenderStepped:Connect(stepSky)
	refreshSky()
	Remotes.get("ClientEffect").OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "Finisher" and typeof(a) == "string" and typeof(b) == "Vector3" then
			finisher(a, b)
		end
	end)
end

return CosmeticController
