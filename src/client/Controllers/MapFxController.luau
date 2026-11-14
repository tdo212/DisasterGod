--!strict
-- MapFxController: the living details of the current arena, all client-side.
--   * Weather (Config.Weather[MapKey]): rain, snow, pollen, embers or dust that follows
--     the camera while it is down in the arena; storm maps flash lightning with thunder.
--   * Spinning parts (Builder.spin): clock hands, gear spokes, radar dishes, propellers.
--   * Launch pads (Builder.launchPad): steam vents throw you up to the catwalks.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local UI = script.Parent.Parent:WaitForChild("UI")
local Sound = require(UI:WaitForChild("Sound") :: ModuleScript)

local W = Config.Weather
local Attributes = Config.Attributes
local player = Players.LocalPlayer

local MapFxController = {}

type Spinner = { Part: BasePart, Rate: Vector3, Base: CFrame, Last: CFrame }

local spinners: { [BasePart]: Spinner } = {}
local weatherPart: Part
local emitter: ParticleEmitter
local flash: ColorCorrectionEffect
local currentKind = ""
local nextFlashAt = math.huge
local lastLaunch = 0
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local PRESETS: { [string]: (ParticleEmitter, number) -> () } = {
	Rain = function(p, rate)
		p.Texture = ""
		p.Color = ColorSequence.new(Color3.fromRGB(190, 205, 220))
		p.Size = NumberSequence.new(0.12)
		p.Squash = NumberSequence.new(4)
		p.Transparency = NumberSequence.new(0.45)
		p.Lifetime = NumberRange.new(0.9, 1.1)
		p.Speed = NumberRange.new(90, 110)
		p.EmissionDirection = Enum.NormalId.Bottom
		p.Acceleration = Vector3.new(6, 0, 0)
		p.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		p.LightEmission = 0
		p.Rate = rate
	end,
	Snow = function(p, rate)
		p.Texture = ""
		p.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		p.Size = NumberSequence.new(0.35)
		p.Squash = NumberSequence.new(0)
		p.Transparency = NumberSequence.new(0.15)
		p.Lifetime = NumberRange.new(7, 9)
		p.Speed = NumberRange.new(8, 12)
		p.EmissionDirection = Enum.NormalId.Bottom
		p.Acceleration = Vector3.new(3, 0, 1)
		p.SpreadAngle = Vector2.new(20, 20)
		p.Orientation = Enum.ParticleOrientation.FacingCamera
		p.Rate = rate
	end,
	Pollen = function(p, rate)
		p.Texture = ""
		p.Color = ColorSequence.new(Color3.fromRGB(255, 245, 170))
		p.Size = NumberSequence.new(0.2)
		p.Squash = NumberSequence.new(0)
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1) })
		p.Lifetime = NumberRange.new(8, 12)
		p.Speed = NumberRange.new(1, 3)
		p.EmissionDirection = Enum.NormalId.Bottom
		p.Acceleration = Vector3.new(0.6, -0.2, 0.4)
		p.SpreadAngle = Vector2.new(80, 80)
		p.LightEmission = 0.4
		p.Rate = rate
	end,
	Embers = function(p, rate)
		p.Texture = ""
		p.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 80, 30))
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		p.Squash = NumberSequence.new(0)
		p.Transparency = NumberSequence.new(0.1)
		p.Lifetime = NumberRange.new(5, 7)
		p.Speed = NumberRange.new(3, 6)
		p.EmissionDirection = Enum.NormalId.Bottom
		p.Acceleration = Vector3.new(1.5, 1.6, 0.5)
		p.SpreadAngle = Vector2.new(60, 60)
		p.LightEmission = 0.6
		p.Rate = rate
	end,
	Dust = function(p, rate)
		p.Texture = "rbxasset://textures/particles/smoke_main.dds"
		p.Color = ColorSequence.new(Color3.fromRGB(230, 200, 150))
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
		p.Squash = NumberSequence.new(0)
		p.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.85), NumberSequenceKeypoint.new(1, 1) })
		p.Lifetime = NumberRange.new(5, 7)
		p.Speed = NumberRange.new(2, 4)
		p.EmissionDirection = Enum.NormalId.Bottom
		p.Acceleration = Vector3.new(12, 0, 3)
		p.SpreadAngle = Vector2.new(60, 60)
		p.LightEmission = 0
		p.Rate = rate
	end,
}

local function mapKey(): string
	local key = ReplicatedStorage:GetAttribute(Attributes.MapKey)
	return if typeof(key) == "string" then key else ""
end

-- Weather only falls while the camera is down in the arena (not up at the Sky Lodge).
local function weatherFor(camera: Camera): any
	if ReplicatedStorage:GetAttribute(Attributes.RoundPhase) ~= "Active" then
		return nil
	end
	if camera.CFrame.Position.Y > W.MaxCameraHeight then
		return nil
	end
	return W.Maps[mapKey()]
end

local function setWeather(spec: any)
	local kind = if spec then spec.Kind else ""
	if kind == currentKind then
		return
	end
	currentKind = kind
	local apply = PRESETS[kind]
	if apply and spec then
		apply(emitter, spec.Rate)
		emitter.Enabled = true
	else
		emitter.Enabled = false
		emitter:Clear()
	end
	nextFlashAt = if spec and spec.Lightning then os.clock() + rng:NextNumber(W.FlashMin * 0.4, W.FlashMin) else math.huge
end

local function lightningFlash()
	flash.Brightness = W.FlashBrightness
	TweenService:Create(flash, TweenInfo.new(0.08), { Brightness = 0 }):Play()
	task.delay(0.16, function()
		flash.Brightness = W.FlashBrightness * 0.6
		TweenService:Create(flash, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	end)
	task.delay(rng:NextNumber(0.4, 1.4), function()
		Sound.play("Thunder", W.ThunderVolume, rng:NextNumber(0.8, 1))
	end)
end

local function track(d: Instance)
	if not d:IsA("BasePart") then
		return
	end
	local rate = d:GetAttribute("Spin")
	if typeof(rate) == "Vector3" then
		spinners[d] = { Part = d, Rate = rate, Base = d.CFrame, Last = d.CFrame }
	end
end

local function onArena(arena: Instance)
	for _, d in arena:GetDescendants() do
		track(d)
	end
	arena.DescendantAdded:Connect(track)
	arena.DescendantRemoving:Connect(function(d)
		if d:IsA("BasePart") then
			spinners[d] = nil
		end
	end)
end

local function spin()
	local t = os.clock()
	for part, s in spinners do
		if not part.Anchored or not part.Parent then
			spinners[part] = nil
			continue
		end
		-- the server moved it (a ship listing over): spin around its new place
		if (part.CFrame.Position - s.Last.Position).Magnitude > 0.05 then
			s.Base = part.CFrame
		end
		local r = s.Rate * t
		local cf = s.Base * CFrame.Angles(r.X, r.Y, r.Z)
		part.CFrame = cf
		s.Last = cf
	end
end

local function launchCheck()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) or humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local now = os.clock()
	if now - lastLaunch < W.LaunchCooldown then
		return
	end
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return
	end
	rayParams.FilterDescendantsInstances = { arena }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), rayParams)
	local power = hit and hit.Instance:GetAttribute("LaunchPower")
	if typeof(power) == "number" then
		lastLaunch = now
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, power, v.Z)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		Sound.play("Gust", 0.7, 1.3)
	end
end

function MapFxController.Start()
	weatherPart = Instance.new("Part")
	weatherPart.Name = "WeatherEmitter"
	weatherPart.Anchored = true
	weatherPart.CanCollide = false
	weatherPart.CanQuery = false
	weatherPart.CanTouch = false
	weatherPart.Transparency = 1
	weatherPart.Size = Vector3.new(W.Area, 1, W.Area)
	weatherPart.Parent = workspace.CurrentCamera
	emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Parent = weatherPart
	flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "LightningFlash"
	flash.Brightness = 0
	flash.Parent = Lighting

	local arena = workspace:FindFirstChild("Arena")
	if arena then
		onArena(arena)
	end
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Arena" then
			onArena(child)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		if weatherPart.Parent ~= camera then
			weatherPart.Parent = camera
		end
		local spec = weatherFor(camera)
		setWeather(spec)
		if spec then
			local p = camera.CFrame.Position
			weatherPart.CFrame = CFrame.new(p.X, p.Y + W.Height, p.Z)
			if os.clock() >= nextFlashAt then
				nextFlashAt = os.clock() + rng:NextNumber(W.FlashMin, W.FlashMax)
				lightningFlash()
			end
		end
		spin()
	end)
	RunService.Heartbeat:Connect(launchCheck)
end

return MapFxController
